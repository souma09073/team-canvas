// ============================================================
// ゲームのルール。
//
// このファイルには描画のコードが1行も無い。
// 「このゲームはどういう仕組みか」を知りたいときは、ここだけ読めばいい。
//
// 中心にあるのは血糖値。
//   ・何もしないと減り続ける      → 食べないと死ぬ
//   ・食べ物を取ると大きく上がる  → 食べすぎても死ぬ
// この2つに挟まれた状態を保つのがこのゲームの中身。
// ============================================================

// ゲームの状態。
// 「倒れた」状態は無い。血糖が振り切れても走り続け、減速するだけ(collapse)。
final int STATE_READY   = 0;   // タイトル画面
final int STATE_RUNNING = 1;   // 走行中
final int STATE_GOAL    = 2;   // ゴールした

class Game {
  Course course = new Course();

  int state = STATE_READY;

  // ---- 走行 ----
  float z = 0;          // スタートからの距離
  int   lane = 1;       // 目標のレーン(0=左 1=中 2=右)
  float x = 0;          // 実際の横位置。lane へ向かって少しずつ動く
  float elapsed = 0;    // 経過タイム

  // ---- 血糖 ----
  float glucose = 50;
  float hyperTimer = 0;         // 高血糖カウントダウンの残り。0なら発動していない

  // ---- 倒れた(減速中) ----
  float collapse = 0;           // 減速している残り時間。0なら通常走行
  String collapseReason = "";   // 「高血糖」か「低血糖」か
  int collapseCount = 0;        // 倒れた回数(成績に出す)

  // ---- マンジャロ ----
  // 1エリア(=1週間)につき1回だけ打てる。打ったエリアを覚えておく。
  boolean[] shotUsedInRegion;
  float shotEffect = 0;         // 薬が効いている残り。この間は食べ物が無効になる
  float lock = 0;               // 女性に奪われて打てない残り

  // ---- ゾーン ----
  float zoneGauge = 0;          // 0〜100
  float zoneActive = 0;         // 発動中の残り
  boolean zoneReady = false;    // 満タン。Zキー待ち

  // ---- エリア(日本縦断の区間) ----
  int regionIndex = 0;          // いま何番目の区間にいるか
  float regionBanner = 0;       // 地名を表示しておく残り時間

  // ---- 演出用のタイマー(ルールには影響しない) ----
  float shotFlash = 0;          // 打った瞬間の表示
  float foodPop = 0;            // 食べた瞬間の表示

  // ---- 記録 ----
  int shotCount = 0;            // マンジャロを打った回数
  int robbedCount = 0;          // 奪われた回数
  float zoneTotal = 0;          // ゾーンの合計時間
  float bestTime = 0;           // ベストタイム。0 なら記録なし
  boolean newRecord = false;

  // ============================================================
  // 開始・入力
  // ============================================================

  void reset() {
    state = STATE_RUNNING;
    z = 0;  lane = 1;  x = laneToX(1);  elapsed = 0;
    glucose = 50;  hyperTimer = 0;
    collapse = 0;  collapseReason = "";  collapseCount = 0;
    shotUsedInRegion = new boolean[regions.length];   // エリアごとの使用権をリセット
    shotEffect = 0;  lock = 0;
    zoneGauge = 0;  zoneActive = 0;  zoneReady = false;
    shotFlash = 0;  foodPop = 0;
    regionIndex = 0;
    regionBanner = REGION_BANNER_SEC;   // 出発地(沖縄)の名前を最初に出す
    shotCount = 0;  robbedCount = 0;  zoneTotal = 0;  newRecord = false;
    course.build();
  }

  void moveLeft()  { if (state == STATE_RUNNING) lane = max(0, lane - 1); }
  void moveRight() { if (state == STATE_RUNNING) lane = min(2, lane + 1); }

  // いま打てるか。1エリアにつき1回だけ。
  boolean canShoot() {
    if (state != STATE_RUNNING) return false;
    if (lock > 0) return false;                       // 女性に奪われている
    if (shotUsedInRegion == null) return false;
    return !shotUsedInRegion[regionIndex];            // このエリアで未使用なら打てる
  }

  // マンジャロ = 食べ物を無効にする。
  //
  // 食べ物を「消す」のではない。そこに残ったまま、食べたいと思わなくなる。
  // 血糖にも直接影響しない。上がらなくなるだけ。
  // だから効果中は血糖が下がる一方で、早く打ちすぎると低血糖に落ちる。
  void tryShot() {
    if (!canShoot()) return;

    shotUsedInRegion[regionIndex] = true;   // このエリアの分を使い切った
    shotEffect = SHOT_EFFECT_SEC;
    shotFlash = 0.35;
    shotCount++;
  }

  // ゾーンは満タンになっても勝手には発動しない。切るタイミングは自分で決める。
  void tryZone() {
    if (state != STATE_RUNNING || !zoneReady) return;
    zoneReady = false;
    zoneGauge = 100;
    zoneActive = ZONE_DURATION;
  }

  // ============================================================
  // 毎フレームの更新
  //
  // 下の呼び出しの並びが、そのまま処理の流れになっている。
  // 中身を知りたい処理だけ、その関数へ飛べばいい。
  // ============================================================

  void update(float dt) {
    if (state != STATE_RUNNING) return;

    updateGlucoseDrain(dt);   // 血糖が自然に減る
    updateTimers(dt);         // 各種タイマーを進める
    updateZoneGauge(dt);      // ゾーンを溜める / 発動中なら減らす
    moveForward(dt);          // 前へ進む
    updateRegion(dt);         // 次のエリアへ入ったか
    revealWomen(dt);          // 女性が地面からせり上がる
    moveLane(dt);             // レーンの間を横に動く

    checkFoodPickup();        // 食べ物に当たったか
    checkWomanHit();          // 女性に当たったか

    checkHyperglycemia(dt);   // 高血糖のカウントダウン
    checkHypoglycemia();      // 低血糖
    checkGoal();              // ゴール判定
  }

  // ---- 倒れる ----
  // 以前は即ゲームオーバーだったが、減速に変えた。
  // 治療を受けて血糖が戻り、そのまま走り続ける。失うのは時間だけ。
  void doCollapse(String reason) {
    collapse = COLLAPSE_SEC;
    collapseReason = reason;
    collapseCount++;
    glucose = COLLAPSE_GLUCOSE;   // 治療を受けた
    hyperTimer = 0;
  }

  boolean isCollapsed() { return collapse > 0; }

  // ---- 血糖の自然減少 ----
  // ゾーン中も普通に減る。ゾーンを安全地帯にすると、マンジャロを使う理由が消えるため。
  // マンジャロ効果中も止まらない。80%に緩めるだけ。
  // 完全に止めてしまうと「打てば安全」になり、薬の危険性が表現できなくなる。
  void updateGlucoseDrain(float dt) {
    if (isCollapsed()) return;   // 治療を受けている間は減らない

    float base = (glucose > STABLE_MAX) ? DRAIN_PER_SEC_HIGH : DRAIN_PER_SEC;
    float rate = base * (shotEffect > 0 ? SHOT_DRAIN_MULT : 1);
    glucose -= rate * dt;
  }

  void updateTimers(float dt) {
    elapsed      += dt;
    collapse      = max(0, collapse - dt);
    shotEffect    = max(0, shotEffect - dt);
    shotFlash     = max(0, shotFlash - dt);
    lock          = max(0, lock - dt);
    foodPop       = max(0, foodPop - dt);
  }

  // ---- ゾーンゲージ ----
  // 緑の帯(=安定域)に居る間だけ溜まる。「安定を保った巧さ」への報酬なので、
  // 高血糖や低血糖では溜まらない。
  void updateZoneGauge(float dt) {
    if (zoneActive > 0) {
      zoneActive = max(0, zoneActive - dt);
      zoneTotal += dt;
      zoneGauge = (zoneActive / ZONE_DURATION) * 100;   // 発動中は残り時間を表す
      return;
    }
    if (zoneReady) return;   // 満タン。発動待ちなので何もしない

    boolean inBand = (glucose >= STABLE_MIN && glucose <= STABLE_MAX);
    if (inBand) zoneGauge += ZONE_CHARGE_PER_SEC * dt;
    else        zoneGauge -= ZONE_DECAY_PER_SEC * dt;   // 今は0。帯を外れても減らない
    zoneGauge = constrain(zoneGauge, 0, 100);

    if (zoneGauge >= 100) zoneReady = true;
  }

  // ---- 前進 ----
  // 速度を変える要素は、ゾーン(速くなる)と 倒れた状態(遅くなる)の2つ。
  // 食べた瞬間の加速はコントロールを失うので廃止した。
  void moveForward(float dt) {
    float mult = 1;
    if (isCollapsed())      mult = COLLAPSE_SPEED_MULT;   // 倒れている間は大きく減速
    else if (zoneActive > 0) mult = ZONE_SPEED_MULT;
    z += runSpeed() * mult * dt;
  }

  // ---- エリア ----
  // 区間が変わったら地名を出す。「いま日本のどこを走っているか」を伝えるため。
  void updateRegion(float dt) {
    regionBanner = max(0, regionBanner - dt);

    int now = regionIndexAt(z);
    if (now != regionIndex) {
      regionIndex = now;
      regionBanner = REGION_BANNER_SEC;
    }
  }

  // ---- 女性のせり上がり ----
  // 「何units手前」ではなく「何秒手前」で出す。
  // 距離を固定にすると、序盤(速度70)と終盤(速度196)で反応時間が3倍違ってしまい、
  // 終盤が運任せになる。
  void revealWomen(float dt) {
    float revealDist = runSpeed() * WOMAN_REVEAL_SEC;
    for (Woman w : course.women) {
      if (w.revealT >= 1) continue;
      if (w.z - z <= revealDist) w.revealT = min(1, w.revealT + dt / WOMAN_RISE_SEC);
    }
  }

  // ---- レーン移動 ----
  // 瞬間移動ではなく、目標レーンへ少しずつ寄せる。移動中に当たり判定が起きるので、
  // 「間に合うかどうか」がゲームになる。
  void moveLane(float dt) {
    float targetX = laneToX(lane);
    float dx = targetX - x;
    float step = LANE_CHANGE_SPEED * dt;
    x += (abs(dx) <= step) ? dx : (dx > 0 ? step : -step);
  }

  // ---- 食べ物 ----
  // ゾーン中もすり抜けない。速度1.8倍で食べ物地帯に突っ込むと血糖が急騰する。
  //
  // マンジャロの効果中は、食べ物にまったく反応しない。
  // 消費もされないので、その場に残ったまま素通りする(食欲が失せた状態)。
  void checkFoodPickup() {
    if (shotEffect > 0) return;

    for (Food f : course.foods) {
      if (f.eaten || !isTouching(f.z, f.lane)) continue;
      f.eaten = true;
      glucose += FOOD_GAIN;
      foodPop = FOOD_POP_SEC;
    }
  }

  // ---- 女性 ----
  // ぶつかると次の1本を奪われる。すでに消した食べ物は戻らない。
  // ゾーン中だけはすり抜けられる(ゾーンに残した唯一の無敵)。
  void checkWomanHit() {
    if (zoneActive > 0) return;
    for (Woman w : course.women) {
      if (w.hit || !isTouching(w.z, w.lane)) continue;
      w.hit = true;
      lock = LOCK_DURATION;
      robbedCount++;
    }
  }

  // 自機がその位置に触れているか。前後の距離とレーンの近さで判定する。
  boolean isTouching(float objZ, int objLane) {
    return abs(objZ - z) < COLLECT_DIST
        && abs(laneToX(objLane) - x) < LANE_WIDTH * 0.45;
  }

  // ---- 高血糖 ----
  // 上限を超えても即座には倒れない。猶予の間に下げれば助かる。
  // 「自分で下げる行動を取れば助かる / 取らなければ倒れる」形にするための仕組み。
  void checkHyperglycemia(float dt) {
    glucose = min(100, glucose);   // 上限は100で止める
    if (isCollapsed()) return;     // 倒れている最中は数えない

    if (hyperTimer > 0) {
      if (glucose <= HYPER_RESET_BELOW) {
        hyperTimer = 0;            // 戻せた
        return;
      }
      hyperTimer -= dt;
      if (hyperTimer <= 0) doCollapse("高血糖");
      return;
    }

    if (glucose > HYPER_THRESHOLD) hyperTimer = HYPER_GRACE_SEC;   // カウントダウン開始
  }

  // ---- 低血糖 ----
  void checkHypoglycemia() {
    if (isCollapsed()) return;
    if (glucose <= 0) doCollapse("低血糖");
  }

  void checkGoal() {
    if (z >= COURSE_LENGTH) goal();
  }

  // ============================================================
  // 終了処理
  // ============================================================

  void goal() {
    state = STATE_GOAL;
    newRecord = (bestTime <= 0 || elapsed < bestTime);
    if (newRecord) {
      bestTime = elapsed;
      saveBest();
    }
  }

  // ============================================================
  // 補助
  // ============================================================

  float runSpeed() { return speedAtZ(z); }

  // ゴールまでの残り秒数。速度は場所によって変わるので、
  // コースを細かく区切って「その区間を何秒で走るか」を足し上げている。
  float secondsToGoal() {
    float remain = COURSE_LENGTH - z;
    if (remain <= 0) return 0;

    int steps = 24;
    float total = 0;
    for (int i = 0; i < steps; i++) {
      float sampleZ = z + remain * (i + 0.5f) / steps;
      total += (remain / steps) / speedAtZ(sampleZ);
    }
    return total;
  }

  // ---- ハイスコア ----
  // ファイル名にコース長を入れている。コース長を変えると記録が別枠になるので、
  // 旧コースの短いタイムが「二度と更新できないベスト」として残ることがない。
  String bestPath() { return "best_" + int(COURSE_LENGTH) + ".txt"; }

  void loadBest() {
    bestTime = 0;
    String[] lines = loadStrings(bestPath());
    if (lines == null || lines.length == 0) return;

    bestTime = float(trim(lines[0]));
    if (Float.isNaN(bestTime) || bestTime <= 0) bestTime = 0;   // 壊れていたら記録なし扱い
  }

  void saveBest() {
    saveStrings(dataPath(bestPath()), new String[] { nf(bestTime, 1, 2) });
  }
}
