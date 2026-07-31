// ============================================================
// HUD。1280x720 の設計座標で書き、実ウィンドウへ拡大縮小して表示する。
// 3Dの上に重ねるので、奥行き判定を切ってカメラを既定へ戻してから描く。
// ============================================================

float designScale = 1;
float designOffsetX = 0;
float designOffsetY = 0;

void computeDesignTransform() {
  designScale = min(width / float(SCREEN_W), height / float(SCREEN_H));
  designOffsetX = (width - SCREEN_W * designScale) * 0.5;
  designOffsetY = (height - SCREEN_H * designScale) * 0.5;
  println("画面: " + width + "x" + height + " / 表示倍率 " + nf(designScale, 1, 3));
}

class Hud {
  PFont fontBig, fontMid, fontSmall;

  void loadFonts() {
    // 環境によって入っているフォントが違う。上から順に試す。
    String[] candidates = { "Meiryo UI", "Meiryo", "Yu Gothic UI", "Yu Gothic", "MS Gothic", "MS PGothic" };
    String found = null;
    String[] installed = PFont.list();
    for (String c : candidates) {
      for (String s : installed) {
        if (s.equalsIgnoreCase(c)) { found = c; break; }
      }
      if (found != null) break;
    }
    if (found == null) {
      println("!! 日本語フォントが見つからない。文字が豆腐(□)になります。");
      return;
    }
    println("使用フォント: " + found);
    // サイズごとに作る。1つを縮小すると小さい文字が滲む。
    fontBig   = createFont(found, 30);
    fontMid   = createFont(found, 20);
    fontSmall = createFont(found, 14);
  }

  void begin() {
    hint(DISABLE_DEPTH_TEST);
    camera();
    ortho();
    noLights();
    translate(designOffsetX, designOffsetY);
    scale(designScale);
  }

  void end() {
    hint(ENABLE_DEPTH_TEST);
  }

  void draw(Game g) {
    begin();
    noStroke();

    drawProgress(g);
    drawGlucose(g);
    drawZone(g);
    drawShot(g);
    drawTime(g);
    drawFinalHint(g);
    drawWarnings(g);
    drawOverlays(g);

    end();
  }

  // ---- 画面最上部の進捗バー ----
  void drawProgress(Game g) {
    fill(0, 130);
    rect(0, 0, SCREEN_W, 7);
    float p = constrain(g.z / COURSE_LENGTH, 0, 1);
    fill(80, 230, 150);
    rect(0, 0, SCREEN_W * p, 7);
  }

  // ---- 血糖ゲージ ----
  // 緑 = 安定域 = ゾーンが溜まる範囲。低血糖側は青、高血糖側は赤で分ける
  // (同じ赤にすると、上に振り切ったのか下に振り切ったのか一瞬で判断できない)。
  void drawGlucose(Game g) {
    float px = 24, py = 22, pw = 300, ph = 86;
    fill(0, 150);
    rect(px, py, pw, ph, 12);

    if (fontSmall != null) textFont(fontSmall);
    textAlign(LEFT, TOP);
    fill(255, 220);
    textSize(13);
    text("血糖値", px + 14, py + 8);

    float bx = px + 14, by = py + 30, bw = pw - 28, bh = 18;
    float d = DANGER_ZONE, sMin = STABLE_MIN, sMax = STABLE_MAX;
    fill(16, 29, 140);  rect(bx,                       by, bw * (d * 0.35f / 100), bh);
    fill(43, 92, 255);  rect(bx + bw * (d * 0.35f / 100), by, bw * ((d - d * 0.35f) / 100), bh);
    fill(221, 204, 51); rect(bx + bw * (d / 100),      by, bw * ((sMin - d) / 100), bh);
    fill(68, 255, 153); rect(bx + bw * (sMin / 100),   by, bw * ((sMax - sMin) / 100), bh);
    fill(221, 51, 51);  rect(bx + bw * (sMax / 100),   by, bw * ((100 - sMax) / 100), bh);

    // 針
    float gv = constrain(g.glucose, 0, 100);
    fill(255);
    rect(bx + bw * (gv / 100) - 2, by - 3, 4, bh + 6);

    // 数字。低血糖=青 / 高血糖=赤 / 食べた瞬間=オレンジ
    if (fontMid != null) textFont(fontMid);
    textSize(22);
    if (g.foodPop > 0)             fill(255, 176, 46);
    else if (gv < DANGER_ZONE)     fill(91, 131, 255);
    else if (g.hyperTimer > 0)     fill(255, 85, 85);
    else                           fill(255);
    text(int(gv) + "", bx, by + bh + 6);

    // 食べた瞬間、何が起きたかを言葉でも出す。
    // マンジャロ効果中は「食べたのに上がらない」ことが分からないと、薬の作用が伝わらない。
    if (g.foodPop > 0) {
      if (fontSmall != null) textFont(fontSmall);
      textSize(14);
      if (g.foodBlocked) {
        fill(120, 220, 255);
        text("血糖上昇なし", bx + 44, by + bh + 12);
      } else {
        fill(255, 176, 46);
        text("+" + int(FOOD_GAIN), bx + 44, by + bh + 12);
      }
    }
  }

  void drawZone(Game g) {
    float px = 24, py = 118, pw = 300, ph = 46;
    fill(0, 150);
    rect(px, py, pw, ph, 10);

    if (fontSmall != null) textFont(fontSmall);
    textAlign(LEFT, TOP);
    textSize(13);
    if (g.zoneActive > 0) {
      fill(255, 204, 0);
      text("ゾーン発動中! 残り " + nf(g.zoneActive, 1, 1) + " 秒", px + 14, py + 7);
    } else if (g.zoneReady) {
      fill(255, 204, 0);
      text("ゾーン準備完了! Z キーで発動", px + 14, py + 7);
    } else {
      fill(255, 200);
      text("ゾーン(緑をキープで蓄積)", px + 14, py + 7);
    }

    float bx = px + 14, by = py + 26, bw = pw - 28, bh = 10;
    fill(60);
    rect(bx, by, bw, bh, 5);
    fill(255, 190, 40);
    rect(bx, by, bw * (g.zoneGauge / 100), bh, 5);
  }

  // ---- マンジャロ ----
  // 「補充中」ではなく、現実の投与間隔を再現していることが伝わる表示にする。
  void drawShot(Game g) {
    float pw = 250, ph = 128;
    float px = SCREEN_W - pw - 24, py = SCREEN_H - ph - 24;

    int bc;   // 枠の色
    String title, sub;
    if (g.lock > 0) {
      bc = color(255, 68, 170);
      title = "奪われた";
      sub = "取り返すまで " + nf(g.lock, 1, 1) + " 秒";
    } else if (g.shotFlash > 0) {
      bc = color(255);
      title = "投与!";
      sub = g.lastCleared > 0 ? ("食べ物 " + g.lastCleared + " 個を消した") : "前方に食べ物なし";
    } else if (g.shotCooldown > 0) {
      bc = color(122, 122, 134);
      if (g.shotEffect > 0) {
        title = "作用中:血糖上昇なし";
        sub = "低下はゆっくり継続";
      } else {
        // 現実の週1回投与を、ゲーム内では7秒=7日として圧縮表現している。
        // 「補充中」ではなく「次の投与日まで待つ」ことが伝わる言い方にする。
        int daysLeft = max(1, ceil(g.shotCooldown / SHOT_COOLDOWN * 7));
        title = "今週分を投与済み";
        sub = "次回投与まで あと" + daysLeft + "日";
      }
    } else {
      bc = color(102, 255, 102);
      title = "投与日:使用できます";
      sub = "スペースで注射";
    }

    fill(0, 165);
    stroke(bc);
    strokeWeight(3);
    rect(px, py, pw, ph, 14);
    noStroke();

    textAlign(CENTER, TOP);
    if (fontMid != null) textFont(fontMid);
    textSize(19);
    fill(bc);
    text("マンジャロ", px + pw * 0.5, py + 10);

    if (fontSmall != null) textFont(fontSmall);
    textSize(15);
    fill(255);
    text(title, px + pw * 0.5, py + 38);
    textSize(13);
    fill(255, 210);
    text(sub, px + pw * 0.5, py + 60);

    // 投与間隔のゲージ。満タン = 打てる。
    // 「1週間に1度しか打てない薬」であることを、溜まっていく時間そのもので示す。
    float bx = px + 16, by = py + 88, bw = pw - 32, bh = 10;
    float ratio;
    if (g.lock > 0)              ratio = 1 - g.lock / LOCK_DURATION;
    else if (g.shotCooldown > 0) ratio = 1 - g.shotCooldown / SHOT_COOLDOWN;
    else                         ratio = 1;
    fill(255, 40);
    rect(bx, by, bw, bh, 5);
    fill(bc);
    rect(bx, by, bw * constrain(ratio, 0, 1), bh, 5);

    if (fontSmall != null) textFont(fontSmall);
    textSize(11);
    fill(255, 150);
    textAlign(CENTER, TOP);
    text("週1回しか打てない薬", px + pw * 0.5, py + 103);
  }

  // 壁の直前には「食べ物2個+女性」の列が続く。ゾーンで女性側を抜け、
  // その後の壁に備えてマンジャロを温存する攻略を、初見でも判断できるよう予告する。
  void drawFinalHint(Game g) {
    if (g.state != STATE_RUNNING) return;
    if (g.course.challengeStart < 0 || g.z >= g.course.wallStart) return;

    float sec = (g.course.challengeStart - g.z) / g.runSpeed();
    if (sec > FINAL_WARN_SEC) return;

    String msg = sec > 0
      ? "終盤まで " + max(1, ceil(sec)) + "秒　Zを準備・マンジャロを温存"
      : "Zで女性をすり抜けろ!　マンジャロは次の壁へ温存";

    if (fontMid != null) textFont(fontMid);
    textAlign(CENTER, TOP);
    textSize(19);
    fill(0, 170);
    rect(SCREEN_W * 0.5 - 260, 120, 520, 40, 10);
    fill(255, 220, 90);
    text(msg, SCREEN_W * 0.5, 129);
  }

  void drawTime(Game g) {
    if (fontBig != null) textFont(fontBig);
    textAlign(CENTER, TOP);
    fill(255);
    textSize(30);
    text(nf(g.elapsed, 1, 2), SCREEN_W * 0.5, 16);

    if (fontSmall != null) textFont(fontSmall);
    textSize(13);
    fill(255, 220);
    String sub = "ゴールまで 約" + int(g.secondsToGoal()) + "秒";
    if (g.bestTime > 0) sub += "　ベスト " + nf(g.bestTime, 1, 2) + "秒";
    else                sub += "　ベスト --";
    text(sub, SCREEN_W * 0.5, 56);
  }

  void drawWarnings(Game g) {
    if (g.state != STATE_RUNNING) return;
    float gv = constrain(g.glucose, 0, 100);

    // 画面のフチ。高血糖=赤、低血糖=青。青が安全に見えないよう暗く沈める。
    if (g.hyperTimer > 0) {
      float a = 120 + 100 * abs(sin(millis() * 0.012));
      drawVignette(color(255, 0, 0), a);
      if (fontBig != null) textFont(fontBig);
      textAlign(CENTER, TOP);
      fill(255, 60, 60);
      textSize(28);
      text("⚠ 高血糖! あと " + nf(g.hyperTimer, 1, 1) + " 秒", SCREEN_W * 0.5, 88);
    } else if (gv < DANGER_ZONE) {
      float a = 90 + 110 * abs(sin(millis() * 0.008));
      drawVignette(color(43, 92, 255), a);
      fill(0, 60);
      rect(0, 0, SCREEN_W, SCREEN_H);   // 意識が遠のく感じの暗転
      if (fontBig != null) textFont(fontBig);
      textAlign(CENTER, TOP);
      fill(140, 180, 255);
      textSize(28);
      text("⚠ 低血糖! 食べろ", SCREEN_W * 0.5, 88);
    }
  }

  // 画面の四辺を帯で覆う簡易ヴィネット
  void drawVignette(int c, float a) {
    noStroke();
    fill(red(c), green(c), blue(c), a);
    float t = 70;
    rect(0, 0, SCREEN_W, t);
    rect(0, SCREEN_H - t, SCREEN_W, t);
    rect(0, 0, t, SCREEN_H);
    rect(SCREEN_W - t, 0, t, SCREEN_H);
  }

  void drawOverlays(Game g) {
    if (g.state == STATE_RUNNING) return;

    fill(0, 170);
    rect(0, 0, SCREEN_W, SCREEN_H);
    textAlign(CENTER, CENTER);

    if (g.state == STATE_READY) {
      if (fontBig != null) textFont(fontBig);
      fill(255); textSize(34);
      text("マンジャロ日本縦断", SCREEN_W * 0.5, 200);
      if (fontSmall != null) textFont(fontSmall);
      textSize(16); fill(255, 230);
      text("←→ / A・D:レーン移動　スペース:マンジャロ　Z:ゾーン　R:リトライ", SCREEN_W * 0.5, 280);
      text("血糖値を " + int(STABLE_MIN) + "〜" + int(STABLE_MAX) + "(緑)に保て。0で低血糖、" + int(HYPER_THRESHOLD) + "超で高血糖。どちらも倒れる。", SCREEN_W * 0.5, 320);
      text("スペースで目の前の食べ物を消せる。ただし次に打てるまで " + int(SHOT_COOLDOWN) + " 秒かかる。", SCREEN_W * 0.5, 356);
      text("緑をキープするとゾーンが溜まり、Zキーで超加速。終盤には消さないと抜けられない壁がある。", SCREEN_W * 0.5, 392);
      textSize(20); fill(255, 204, 0);
      text("Enter または クリックでスタート", SCREEN_W * 0.5, 470);

    } else if (g.state == STATE_OVER) {
      if (fontBig != null) textFont(fontBig);
      fill(255, 90, 90); textSize(34);
      text(g.overTitle, SCREEN_W * 0.5, 240);
      if (fontSmall != null) textFont(fontSmall);
      fill(255); textSize(16);
      text(g.overReason, SCREEN_W * 0.5, 300);
      text("R キーでリトライ", SCREEN_W * 0.5, 360);

    } else if (g.state == STATE_GOAL) {
      if (fontBig != null) textFont(fontBig);
      fill(255, 204, 0); textSize(36);
      text("GOAL!", SCREEN_W * 0.5, 190);
      text(nf(g.elapsed, 1, 2) + " 秒", SCREEN_W * 0.5, 250);
      if (g.newRecord) {
        fill(255, 230, 90); textSize(24);
        text("ハイスコア更新!", SCREEN_W * 0.5, 305);
      }
      if (fontSmall != null) textFont(fontSmall);
      fill(255); textSize(15);
      text("マンジャロ " + g.shotCount + " 回(食べ物 " + g.clearedCount + " 個を消去)　奪われ " + g.robbedCount + " 回　ゾーン合計 " + nf(g.zoneTotal, 1, 1) + " 秒",
           SCREEN_W * 0.5, 360);
      textSize(17); fill(255, 220);
      text("あなたはこの薬を、何のために使いましたか。", SCREEN_W * 0.5, 410);
      textSize(15); fill(255, 200);
      text("R キーでリトライ", SCREEN_W * 0.5, 460);
    }
  }
}
