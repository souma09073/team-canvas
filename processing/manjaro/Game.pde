// ============================================================
// ゲームの状態と進行。HTMLプロトタイプの update() をそのまま移植している。
// 描画には一切触れないので、ここだけ読めばルールが分かる。
// ============================================================

final int STATE_READY   = 0;
final int STATE_RUNNING = 1;
final int STATE_OVER    = 2;
final int STATE_GOAL    = 3;

class Game {
  Course course = new Course();

  int state = STATE_READY;
  float glucose = 50;
  float z = 0;          // 進んだ距離
  int lane = 1;         // 0=左 1=中 2=右
  float x = 0;          // 実際の横位置(レーン間を補間する)
  float elapsed = 0;

  float shotCooldown = 0;   // 次に撃てるまで
  float shotEffect = 0;     // 薬が効いている残り時間(食べても血糖が上がらない)
  boolean foodBlocked = false;  // 直近の食べ物が効果で血糖上昇しなかったか(表示用)
  float shotFlash = 0;      // 撃った演出の残り時間
  float lock = 0;           // 女性に奪われて撃てない残り時間
  float zoneGauge = 0;      // 0〜100
  float zoneActive = 0;     // 発動中の残り時間
  boolean zoneReady = false;
  float hyperTimer = 0;     // 高血糖カウントダウンの残り。0なら非発動
  float foodPop = 0;        // 食べた演出の残り時間

  int shotCount = 0;
  int clearedCount = 0;
  int lastCleared = 0;
  int robbedCount = 0;
  float zoneTotal = 0;

  String overTitle = "";
  String overReason = "";

  float bestTime = 0;       // 0 なら記録なし
  boolean newRecord = false;

  void reset() {
    state = STATE_RUNNING;
    glucose = 50;
    z = 0;
    lane = 1;
    x = laneToX(1);
    elapsed = 0;
    shotCooldown = 0;
    shotEffect = 0;
    shotFlash = 0;
    lock = 0;
    zoneGauge = 0;
    zoneActive = 0;
    zoneReady = false;
    hyperTimer = 0;
    foodPop = 0;
    foodBlocked = false;
    shotCount = 0;
    clearedCount = 0;
    lastCleared = 0;
    robbedCount = 0;
    zoneTotal = 0;
    newRecord = false;
    course.build();
  }

  float runSpeed() { return speedAtZ(z); }

  void moveLeft()  { if (state == STATE_RUNNING) lane = max(0, lane - 1); }
  void moveRight() { if (state == STATE_RUNNING) lane = min(2, lane + 1); }

  // マンジャロ = 目の前の食べ物をまとめて消す。効果は一瞬で持続しない。
  // 消せば血糖は上がらないが、その分そのまま落ち続ける。
  void tryShot() {
    if (state != STATE_RUNNING) return;
    if (lock > 0 || shotCooldown > 0) return;   // 不発

    shotCooldown = SHOT_COOLDOWN;
    shotCount++;

    float range = runSpeed() * SHOT_CLEAR_SEC;
    int cleared = 0;
    for (Food f : course.foods) {
      if (f.eaten || f.z < z || f.z - z > range) continue;
      f.eaten = true;
      cleared++;
    }
    clearedCount += cleared;
    lastCleared = cleared;
    shotFlash = 0.35;
    shotEffect = SHOT_EFFECT_SEC;
  }

  void tryZone() {
    if (state == STATE_RUNNING && zoneReady) {
      zoneReady = false;
      zoneGauge = 100;
      zoneActive = ZONE_DURATION;
    }
  }

  void update(float dt) {
    if (state != STATE_RUNNING) return;

    // ---- 血糖の自然減少 ----
    // ゾーン中も血糖は普通に動く(ゾーンを安全地帯にするとマンジャロの役割が消えるため)。
    // マンジャロ効果中も血糖は下がり続ける。通常の80%に緩めるだけで、
    // 食べ物による上昇がないまま使い続けると低血糖へ近づく。
    float baseDrain = (glucose > STABLE_MAX) ? DRAIN_PER_SEC_HIGH : DRAIN_PER_SEC;
    float drain = baseDrain * (shotEffect > 0 ? SHOT_DRAIN_MULT : 1);
    glucose -= drain * dt;

    // ---- タイマー ----
    elapsed += dt;
    shotCooldown = max(0, shotCooldown - dt);
    shotEffect   = max(0, shotEffect - dt);
    shotFlash    = max(0, shotFlash - dt);
    lock         = max(0, lock - dt);
    foodPop      = max(0, foodPop - dt);

    // ---- ゾーンゲージ ----
    if (zoneActive > 0) {
      zoneActive = max(0, zoneActive - dt);
      zoneTotal += dt;
      zoneGauge = (zoneActive / ZONE_DURATION) * 100;
    } else if (!zoneReady) {
      // 緑の帯に居る間だけ溜まる。満タンで「準備完了」になり、切るタイミングは自分で決める。
      if (glucose >= STABLE_MIN && glucose <= STABLE_MAX) {
        zoneGauge += ZONE_CHARGE_PER_SEC * dt;
      }
      zoneGauge = constrain(zoneGauge, 0, 100);
      if (zoneGauge >= 100) zoneReady = true;
    }

    // ---- 前進 ----
    float speed = runSpeed();
    z += speed * (zoneActive > 0 ? ZONE_SPEED_MULT : 1) * dt;

    // ---- 女性のせり上がり ----
    // 出現を距離で固定にすると、序盤(速度70)と終盤(速度196)で反応時間が3倍違って
    // 終盤が運ゲーになる。だから距離ではなく時間で持つ。
    float revealDist = speed * WOMAN_REVEAL_SEC;
    for (Woman w : course.women) {
      if (w.revealT < 1 && w.z - z <= revealDist) {
        w.revealT = min(1, w.revealT + dt / WOMAN_RISE_SEC);
      }
    }

    // ---- レーン移動 ----
    float targetX = laneToX(lane);
    float dx = targetX - x;
    float step = LANE_CHANGE_SPEED * dt;
    x += (abs(dx) <= step) ? dx : (dx > 0 ? step : -step);

    // ---- 食べ物 ----
    // ゾーン中もすり抜けない。速度1.8倍で食べ物地帯に突っ込むと血糖が急騰する。
    for (Food f : course.foods) {
      if (f.eaten) continue;
      if (abs(f.z - z) < COLLECT_DIST && abs(laneToX(f.lane) - x) < LANE_WIDTH * 0.45) {
        // 効果中は食べても吸収されない = 血糖が上がらない。これが薬の作用そのもの。
        f.eaten = true;
        foodBlocked = (shotEffect > 0);
        if (!foodBlocked) glucose += FOOD_GAIN;
        foodPop = 0.5;
      }
    }

    // ---- 女性(ゾーン中はすり抜ける) ----
    for (Woman w : course.women) {
      if (w.hit || zoneActive > 0) continue;
      if (abs(w.z - z) < COLLECT_DIST && abs(laneToX(w.lane) - x) < LANE_WIDTH * 0.45) {
        // 奪われるのは「次の1本」だけ。すでに消した食べ物は戻らない。
        w.hit = true;
        lock = LOCK_DURATION;
        robbedCount++;
      }
    }

    // ---- 高血糖カウントダウン ----
    glucose = min(100, glucose);   // 上限100。即死はせず、カウントダウンで裁く
    if (hyperTimer > 0) {
      if (glucose <= HYPER_RESET_BELOW) {
        hyperTimer = 0;
      } else {
        hyperTimer -= dt;
        if (hyperTimer <= 0) {
          gameOver("高血糖", "血糖値を " + int(HYPER_GRACE_SEC) + " 秒以内に下げられなかった");
          return;
        }
      }
    } else if (glucose > HYPER_THRESHOLD) {
      hyperTimer = HYPER_GRACE_SEC;
    }

    // ---- 勝敗 ----
    if (glucose <= 0) {
      gameOver("低血糖", "血糖値が 0 になった(食べなさすぎ)");
      return;
    }
    if (z >= COURSE_LENGTH) goal();
  }

  void gameOver(String type, String reason) {
    state = STATE_OVER;
    overTitle = type + "で倒れた!";
    overReason = reason;
  }

  void goal() {
    state = STATE_GOAL;
    newRecord = (bestTime <= 0 || elapsed < bestTime);
    if (newRecord) {
      bestTime = elapsed;
      saveBest();
    }
  }

  // ---- ハイスコア(ファイル保存) ----
  // コース長をファイル名に含める。コース長を変えると記録が別枠になり、
  // 旧コースの短いタイムが「二度と更新できないベスト」として残るのを防ぐ。
  String bestPath() { return "best_" + int(COURSE_LENGTH) + ".txt"; }

  void loadBest() {
    bestTime = 0;
    String[] lines = loadStrings(bestPath());
    if (lines != null && lines.length > 0) {
      try {
        bestTime = float(trim(lines[0]));
      } catch (Exception e) {
        bestTime = 0;
      }
      if (Float.isNaN(bestTime) || bestTime <= 0) bestTime = 0;
    }
  }

  void saveBest() {
    saveStrings(dataPath(bestPath()), new String[] { nf(bestTime, 1, 2) });
  }

  // ゴールまでの残り秒数。速度が場所で変わるので区間に分けて足し上げる。
  float secondsToGoal() {
    float remain = COURSE_LENGTH - z;
    if (remain <= 0) return 0;
    int steps = 24;
    float t = 0;
    for (int i = 0; i < steps; i++) {
      t += (remain / steps) / speedAtZ(z + remain * (i + 0.5f) / steps);
    }
    return t;
  }
}
