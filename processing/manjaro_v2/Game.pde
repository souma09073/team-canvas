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
//
// 走る前には必ずカウントダウンが入る。エリアの境目ではフェリーで移動する。
//   タイトル → カウントダウン → 走行 → フェリー → カウントダウン → 走行 → … → ゴール
//
// 「倒れた」という状態は無い。血糖が振り切れても一定時間止まるだけで、そのまま続く。
final int STATE_TITLE     = 0;   // タイトル画面
final int STATE_READY     = 1;   // 説明画面
final int STATE_COUNTDOWN = 2;   // 3・2・1。世界は見えているが動かない
final int STATE_RUNNING   = 3;   // 走行中
final int STATE_FERRY     = 4;   // フェリーで移動中
final int STATE_GOAL      = 5;   // ゴールした
final int STATE_GAME_OVER = 6;   // 区間の制限時間を超えた

class Game {
  Course course = new Course();

  int state = STATE_TITLE;

  // ---- 走行 ----
  float z = 0;          // スタートからの距離
  int   lane = 1;       // 目標のレーン(0=左 1=中 2=右)
  float x = 0;          // 実際の横位置。lane へ向かって少しずつ動く
  float elapsed = 0;    // 経過タイム

  // ---- 血糖 ----
  float glucose = 50;
  float hyperTimer = 0;         // 高血糖カウントダウンの残り。0なら発動していない

  // ---- 停止中 ----
  // 血糖で倒れた場合と、岩にぶつかった場合の両方をここで扱う。
  // 止まっている間は前進も血糖も当たり判定も全部止まり、経過タイムだけが進む。
  // 止まった秒数が、そのまま失う時間になる。
  float stopTimer = 0;          // 止まっている残り時間。0なら通常走行
  String stopReason = "";       // 画面に出す理由
  boolean stopIsCollapse = false;  // 血糖で倒れたのか(表示を変えるため)
  int collapseCount = 0;        // 血糖で倒れた回数
  int rockHitCount = 0;         // 岩にぶつかった回数

  // ---- フェリーとカウントダウン ----
  float ferryTimer = 0;         // 自動で流れるフェリーの残り時間
  float countdownTimer = 0;     // 走り出すまでの残り時間

  // ---- マンジャロ ----
  // 1エリア(=1週間)につき1回だけ打てる。打ったエリアを覚えておく。
  boolean[] shotUsedInRegion;
  float shotEffect = 0;         // 薬が効いている残り。この間は食べ物が無効になる
  float lock = 0;               // 女性に奪われて打てない残り

  // ---- 加速アイテム ----
  boolean speedItemHeld = false;  // 取得したら使用可能な状態になる
  float speedItemActive = 0;      // 発動中の残り時間

  // ---- ゾーン ----
  // コメントアウト: ゾーン機能を無効化
  // float zoneGauge = 0;          // 0〜100
  // float zoneActive = 0;         // 発動中の残り
  // boolean zoneReady = false;    // 満タン。Zキー待ち

  // ---- エリア(日本縦断の区間) ----
  int regionIndex = 0;          // いま何番目の区間にいるか
  float regionBanner = 0;       // 地名を表示しておく残り時間

  // ---- フェリー(エリアの区切りで入る休憩) ----
  // 先生から「なんでもいいからユーザーの休みをちょうだい」と2回言われた点への対応。
  // エリアの境目で一度手を止め、そこまでの成績を見せる。
  int ferryFromRegion = 0;      // どのエリアを走り終えたか
  float stageStartTime = 0;     // そのエリアに入った時刻(区間タイムを出すため)
  int stageFoodCount = 0;       // そのエリアで食べた数
  int checkpointRegionIndex = 0;  // R で戻す区間の開始地点
  float checkpointElapsed = 0;    // そのチェックポイントでの経過時間

  // ---- 演出用のタイマー(ルールには影響しない) ----
  float shotFlash = 0;          // 打った瞬間の表示
  float foodPop = 0;            // 食べた瞬間の表示

  // ---- 記録 ----
  int shotCount = 0;            // マンジャロを打った回数
  int robbedCount = 0;          // 奪われた回数
  // コメントアウト: ゾーン機能を無効化
  // float zoneTotal = 0;          // ゾーンの合計時間
  float bestTime = 0;           // ベストタイム。0 なら記録なし
  boolean newRecord = false;

  // ============================================================
  // 開始・入力
  // ============================================================

  void reset() {
    z = 0;  lane = 1;  x = laneToX(1);  elapsed = 0;
    checkpointRegionIndex = 0;  checkpointElapsed = 0;
    hyperTimer = 0;
    stopTimer = 0;  stopReason = "";  stopIsCollapse = false;
    collapseCount = 0;  rockHitCount = 0;
    shotUsedInRegion = new boolean[regions.length];   // エリアごとの使用権をリセット
    shotEffect = 0;  lock = 0;
    // コメントアウト: ゾーン機能を無効化
    // zoneGauge = 0;  zoneActive = 0;  zoneReady = false;
    shotFlash = 0;  foodPop = 0;
    regionIndex = 0;  ferryFromRegion = 0;
    ferryTimer = 0;
    shotCount = 0;  robbedCount = 0;  // zoneTotal = 0;  newRecord = false;
    newRecord = false;
    course.build();

    startCountdown();   // いきなり走り出さず、必ず構える時間を置く
  }

  // ---- 走り出す前のカウントダウン ----
  // タイトルからも、フェリーからも、必ずここを通る。
  // 血糖を整えるのもここ(港で食事をとった、という扱い)。
  void startCountdown() {
    checkpointRegionIndex = regionIndex;
    checkpointElapsed = elapsed;
    state = STATE_COUNTDOWN;
    countdownTimer = COUNTDOWN_SEC;
    glucose = GLUCOSE_RESET;
    hyperTimer = 0;
    stopTimer = 0;
    stageStartTime = elapsed;
    stageFoodCount = 0;
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

  void trySpeedItem() {
    if (state != STATE_RUNNING || !speedItemHeld || speedItemActive > 0) return;
    speedItemHeld = false;
    speedItemActive = ZONE_DURATION;
  }

  // ============================================================
  // 毎フレームの更新
  //
  // 下の呼び出しの並びが、そのまま処理の流れになっている。
  // 中身を知りたい処理だけ、その関数へ飛べばいい。
  // ============================================================

  void update(float dt) {
    if (state == STATE_COUNTDOWN) { updateCountdown(dt); return; }
    if (state == STATE_FERRY)     { updateFerry(dt);     return; }
    if (state != STATE_RUNNING) return;

    // 止まっている間は、経過タイムだけが進む。
    // 前進も血糖も当たり判定も全部飛ばすので、世界は完全に静止する。
    if (isStopped()) {
      elapsed += dt;
      stopTimer = max(0, stopTimer - dt);
      return;
    }

    updateGlucoseDrain(dt);   // 血糖が自然に減る
    updateTimers(dt);         // 各種タイマーを進める
    // コメントアウト: ゾーン機能を無効化
    // updateZoneGauge(dt);      // ゾーンを溜める / 発動中なら減らす
    moveForward(dt);          // 前へ進む

    // 港に着いたら、この先の当たり判定や血糖の判定はしない。
    // ゴールした後で岩に当たった判定が出る、といったことを防ぐ。
    if (updateRegion(dt)) return;

    revealWomen(dt);          // 女性が地面からせり上がる
    moveLane(dt);             // レーンの間を横に動く

    checkFoodPickup();        // 食べ物に当たったか
    checkSpeedItemPickup();   // 加速アイテムを拾ったか
    checkRockHit();           // 岩に当たったか
    checkWomanHit();          // 女性に当たったか

    checkHyperglycemia(dt);   // 高血糖のカウントダウン
    checkHypoglycemia();      // 低血糖
    checkGoal();              // ゴール判定
    checkRegionTimeLimit();  // 区間の制限時間を超えたらゲームオーバー
  }

  // ---- カウントダウン ----
  void updateCountdown(float dt) {
    countdownTimer = max(0, countdownTimer - dt);
    if (countdownTimer > 0) return;

    state = STATE_RUNNING;
    regionBanner = REGION_BANNER_SEC;   // 走り出すと同時に地名を出す
  }

  // ---- フェリー ----
  // 中間地点(restAfter が true のエリアのあと)だけは Enter 待ちで止まる。
  // それ以外は演出が流れて自動で次へ進む。テンポを優先するため。
  void updateFerry(float dt) {
    if (ferryIsRest()) return;   // 止まる回。プレイヤーの Enter を待つ

    ferryTimer = max(0, ferryTimer - dt);
    if (ferryTimer <= 0) leaveFerry();
  }

  boolean ferryIsRest() { return regions[ferryFromRegion].restAfter; }

  // 港を出発して次のエリアへ。自動の場合も Enter の場合もここを通る。
  //
  // ここで z を次のエリアの先頭へ飛ばす。エリアの間には海が空いていて、
  // そこは走らないため。船に運ばれた、という扱い。
  // レーンも真ん中に戻す(港に着いて、あらためて走り出すので)。
  void leaveFerry() {
    if (state != STATE_FERRY) return;

    z = regions[regionIndex].startZ;
    lane = 1;
    x = laneToX(1);

    startCountdown();
  }

  // ---- 停止の共通処理 ----
  // すでに止まっているなら、長いほうを残す(岩の直後に倒れても短くならないように)。
  void startStop(String reason, float sec, boolean isCollapse) {
    if (sec < stopTimer) return;
    stopTimer = sec;
    stopReason = reason;
    stopIsCollapse = isCollapse;
  }

  // ---- 血糖で倒れる ----
  // 以前は即ゲームオーバーだったが、一定時間止まるだけに変えた。
  // 治療を受けて血糖が戻り、そのまま走り続ける。失うのは時間だけ。
  void doCollapse(String reason) {
    startStop(reason, COLLAPSE_STOP_SEC, true);
    collapseCount++;
    glucose = GLUCOSE_RESET;   // 治療を受けた
    hyperTimer = 0;
  }

  // ---- 岩にぶつかる ----
  // 血糖とは無関係。見て避けるだけの障害物なので、止まる時間は短い。
  void doRockHit() {
    startStop("岩にぶつかった", ROCK_STOP_SEC, false);
    rockHitCount++;
  }

  boolean isStopped()   { return stopTimer > 0; }
  boolean isCollapsed() { return stopTimer > 0 && stopIsCollapse; }

  // ---- 血糖の自然減少 ----
  // ゾーン中も普通に減る。ゾーンを安全地帯にすると、マンジャロを使う理由が消えるため。
  // マンジャロ効果中も止まらない。80%に緩めるだけ。
  // 完全に止めてしまうと「打てば安全」になり、薬の危険性が表現できなくなる。
  void updateGlucoseDrain(float dt) {
    if (isCollapsed()) return;   // 治療を受けている間は減らない

    float base = drainPerSec() * (glucose > STABLE_MAX ? DRAIN_HIGH_MULT : 1);
    float rate = base * (shotEffect > 0 ? SHOT_DRAIN_MULT : 1);
    glucose -= rate * dt;
  }

  // ---- エリアごとの血糖の数値 ----
  // 沖縄 +16/-8 から北海道 +28/-14 まで、エリアが進むほど振れ幅が大きくなる。
  // 必要ペース(gain ÷ drain)はどのエリアも 2.0秒に1個で変わらない。
  // 忙しさは同じまま、1回のミスの重さだけが増していく。
  float foodGain()    { return regions[regionIndex].foodGain; }
  float drainPerSec() { return regions[regionIndex].drainPerSec; }

  void updateTimers(float dt) {
    elapsed      += dt;
    shotEffect    = max(0, shotEffect - dt);
    shotFlash     = max(0, shotFlash - dt);
    lock          = max(0, lock - dt);
    foodPop       = max(0, foodPop - dt);
    speedItemActive = max(0, speedItemActive - dt);
  }

  // ---- ゾーンゲージ ----
  // コメントアウト: ゾーン機能を無効化
  // void updateZoneGauge(float dt) {
  //   if (zoneActive > 0) {
  //     zoneActive = max(0, zoneActive - dt);
  //     zoneTotal += dt;
  //     zoneGauge = (zoneActive / ZONE_DURATION) * 100;   // 発動中は残り時間を表す
  //     return;
  //   }
  //   if (zoneReady) return;   // 満タン。発動待ちなので何もしない
  //
  //   boolean inBand = (glucose >= STABLE_MIN && glucose <= STABLE_MAX);
  //   if (inBand) zoneGauge += ZONE_CHARGE_PER_SEC * dt;
  //   else        zoneGauge -= ZONE_DECAY_PER_SEC * dt;   // 今は0。帯を外れても減らない
  //   zoneGauge = constrain(zoneGauge, 0, 100);
  //
  //   if (zoneGauge >= 100) zoneReady = true;
  // }

  // ---- 前進 ----
  // 速度を変える要素はゾーンだけ(食べた瞬間の加速はコントロールを失うので廃止)。
  // 止まっているときは update の冒頭で抜けるので、ここには来ない。
  void moveForward(float dt) {
    float mult = speedItemActive > 0 ? ZONE_SPEED_MULT : 1;
    z += runSpeed() * mult * dt;
  }

  // ---- エリア ----
  // ゴール(港)に着いたら、そこで走るのをやめて船に乗る。
  // 最後のエリアだけは船が無く、そのままゲームのゴール(checkGoal が拾う)。
  //
  // 港に着いたら true を返す。呼び出し側はそこで残りの判定を打ち切る。
  boolean updateRegion(float dt) {
    regionBanner = max(0, regionBanner - dt);

    if (regionIndex >= regions.length - 1) return false;   // 最終エリア。この先に港は無い
    if (z < regions[regionIndex].endZ)     return false;   // まだ港に着いていない

    ferryFromRegion = regionIndex;   // 走り終えたエリア
    regionIndex++;
    state = STATE_FERRY;
    ferryTimer = FERRY_SEC;          // 自動で流れる回だけ使われる
    return true;
  }

  // いま走っているエリアに入ってからの経過時間
  float stageTime() { return elapsed - stageStartTime; }

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
    float step = laneChangeSpeed() * dt;
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
      glucose += foodGain();
      foodPop = FOOD_POP_SEC;
      stageFoodCount++;
    }
  }

  // ---- 加速アイテム ----
  void checkSpeedItemPickup() {
    if (speedItemHeld) return;

    for (SpeedItem item : course.speedItems) {
      if (item.picked || !isTouching(item.z, item.lane)) continue;
      item.picked = true;
      speedItemHeld = true;
      break;
    }
  }

  // ---- 岩 ----
  // ゾーン中はすり抜ける(ゾーンの数少ない利点)。
  // 一度ぶつかった岩は二度は当たらない。
  void checkRockHit() {
    // コメントアウト: ゾーン機能を無効化
    // if (zoneActive > 0) return;
    for (Rock r : course.rocks) {
      if (r.hit || !isTouching(r.z, r.lane)) continue;
      r.hit = true;
      doRockHit();
    }
  }

  // ---- 女性 ----
  // ぶつかると次の1本を奪われる。すでに消した食べ物は戻らない。
  // ゾーン中だけはすり抜けられる(ゾーンに残した唯一の無敵)。
  void checkWomanHit() {
    // コメントアウト: ゾーン機能を無効化
    // if (zoneActive > 0) return;
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

  void checkRegionTimeLimit() {
    if (state != STATE_RUNNING) return;
    if (regions == null || regionIndex < 0 || regionIndex >= regions.length) return;
    if (stageTime() > regions[regionIndex].limitSec) gameOver();
  }

  void restartFromCheckpoint() {
    if (regions == null || regions.length == 0) { reset(); return; }

    if (checkpointRegionIndex < 0 || checkpointRegionIndex >= regions.length) {
      checkpointRegionIndex = 0;
    }

    z = regions[checkpointRegionIndex].startZ;
    regionIndex = checkpointRegionIndex;
    lane = 1;
    x = laneToX(1);
    elapsed = checkpointElapsed;

    hyperTimer = 0;
    stopTimer = 0;  stopReason = "";  stopIsCollapse = false;
    collapseCount = 0;  rockHitCount = 0;

    if (shotUsedInRegion == null) {
      shotUsedInRegion = new boolean[regions.length];
    } else {
      boolean[] next = new boolean[regions.length];
      for (int i = 0; i < checkpointRegionIndex; i++) {
        next[i] = shotUsedInRegion[i];
      }
      shotUsedInRegion = next;
    }

    shotEffect = 0;  lock = 0;
    // コメントアウト: ゾーン機能を無効化
    // zoneGauge = 0;  zoneActive = 0;  zoneReady = false;
    shotFlash = 0;  foodPop = 0;
    regionBanner = 0;
    ferryFromRegion = checkpointRegionIndex;
    stageStartTime = elapsed;
    stageFoodCount = 0;
    countdownTimer = COUNTDOWN_SEC;
    glucose = GLUCOSE_RESET;
    state = STATE_COUNTDOWN;
    newRecord = false;
  }

  void gameOver() {
    state = STATE_GAME_OVER;
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

  // 最終ゴールまでの残り秒数。
  // いま走っているエリアの残り + この先のエリア全部、を足す。
  // エリアの間の海は走らないので数えない(船の時間もタイムに入らない)。
  float secondsToGoal() {
    float total = 0;
    for (int i = regionIndex; i < regions.length; i++) {
      total += regions[i].secondsFrom(i == regionIndex ? z : regions[i].startZ);
    }
    return total;
  }

  float sectionTimeLimitRemaining() {
    if (regions == null || regionIndex < 0 || regionIndex >= regions.length) return 0;
    return max(0, regions[regionIndex].limitSec - stageTime());
  }

  // ---- ハイスコア ----
  // ファイル名に走行距離を入れている。コースの長さを変えると記録が別枠になるので、
  // 旧コースの短いタイムが「二度と更新できないベスト」として残ることがない。
  String bestPath() { return "best_" + int(RUN_LENGTH) + ".txt"; }

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
