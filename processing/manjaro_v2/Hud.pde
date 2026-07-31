// ============================================================
// 画面表示(HUD)。
//
// 描画は常に 1280x720 の座標で書き、実際のウィンドウの大きさに合わせて拡大縮小する。
// こうしておかないと、解像度や表示倍率の違うPCでレイアウトが崩れる。
//
// 大きな部品は別ファイルに分けてある:
//   ShotPanel.pde … 右下のマンジャロのパネル
//   Screens.pde   … タイトル / ゲームオーバー / ゴールの全画面表示
//   Fonts.pde     … フォントの読み込みと setText()
// ============================================================

float designScale = 1;      // 設計座標 -> 実ウィンドウ の倍率
float designOffsetX = 0;    // 画面比が合わないぶんの余白(左右)
float designOffsetY = 0;    // 同(上下)

void computeDesignTransform() {
  designScale = min(width / float(SCREEN_W), height / float(SCREEN_H));
  designOffsetX = (width - SCREEN_W * designScale) * 0.5;
  designOffsetY = (height - SCREEN_H * designScale) * 0.5;
  println("画面: " + width + "x" + height + " / 表示倍率 " + nf(designScale, 1, 3));
}

class Hud {
  ShotPanel shotPanel = new ShotPanel();
  Screens screens = new Screens();

  void draw(Game g) {
    begin();
    noStroke();

    drawProgress(g);
    drawGlucose(g);
    drawMiniGauge(g);
    drawZone(g);
    shotPanel.draw(g);
    drawTime(g);
    drawRegionBanner(g);
    drawFinalHint(g);
    drawWarnings(g);
    drawCollapse(g);
    screens.draw(g);

    end();
  }

  // 3Dの上に2Dを重ねるための準備。
  // camera() が行列を戻すので、拡大縮小は必ずその後にかける。
  void begin() {
    hint(DISABLE_DEPTH_TEST);
    camera();
    ortho();
    noLights();
    translate(designOffsetX, designOffsetY);
    scale(designScale);
  }

  void end() {
    hint(ENABLE_DEPTH_TEST);   // 戻し忘れると次のフレームの3Dが壊れる
  }

  // ---- 画面最上部の進捗バー ----
  void drawProgress(Game g) {
    fill(0, 130);
    rect(0, 0, SCREEN_W, 7);
    fill(80, 230, 150);
    rect(0, 0, SCREEN_W * constrain(g.z / COURSE_LENGTH, 0, 1), 7);
  }

  // ---- 左上の血糖ゲージ ----
  // 緑 = 安定域 = ゾーンが溜まる範囲。この3つをわざと同じ範囲にして、
  // 「緑にいる」の意味を1つに絞っている。
  // 低血糖側は青、高血糖側は赤。同じ赤にすると、上に振り切ったのか
  // 下に振り切ったのかが一瞬で判断できない。
  void drawGlucose(Game g) {
    float px = 24, py = 22, pw = 300, ph = 86;
    fill(0, 150);
    rect(px, py, pw, ph, 12);

    setText(fontSmall, 13);
    textAlign(LEFT, TOP);
    fill(255, 220);
    text("血糖値", px + 14, py + 8);

    float bx = px + 14, by = py + 30, bw = pw - 28, bh = 18;
    drawGlucoseBands(bx, by, bw, bh);

    float gv = constrain(g.glucose, 0, 100);
    fill(255);
    rect(bx + bw * (gv / 100) - 2, by - 3, 4, bh + 6);   // 針

    setText(fontMid, 22);
    fill(glucoseTextColor(g, gv));
    text(int(gv) + "", bx, by + bh + 6);

    // 食べた瞬間、何が起きたかを言葉でも出す。
    // マンジャロ効果中は「食べたのに上がらない」ことが分からないと薬の作用が伝わらない。
    if (g.foodPop > 0) {
      setText(fontSmall, 14);
      if (g.foodBlocked) { fill(C_BLOCKED); text("血糖上昇なし", bx + 44, by + bh + 12); }
      else               { fill(C_NUM_FOOD);  text("+" + int(FOOD_GAIN), bx + 44, by + bh + 12); }
    }
  }

  // ゲージの色分け。横向きに 0〜100 を割り当てる。
  void drawGlucoseBands(float bx, float by, float bw, float bh) {
    band(bx, by, bw, bh, 0,                  DANGER_ZONE * 0.35f, C_GLU_CRITICAL);   // いよいよ危ない
    band(bx, by, bw, bh, DANGER_ZONE * 0.35f, DANGER_ZONE,        C_GLU_LOW);   // 低血糖
    band(bx, by, bw, bh, DANGER_ZONE,         STABLE_MIN,         C_GLU_MID);  // 中間
    band(bx, by, bw, bh, STABLE_MIN,          STABLE_MAX,         C_GLU_STABLE);  // 安定=ゾーンが溜まる
    band(bx, by, bw, bh, STABLE_MAX,          100,                C_GLU_HIGH);   // 高血糖
  }

  // 血糖 lo〜hi の範囲を横バーの該当位置に塗る
  void band(float bx, float by, float bw, float bh, float lo, float hi, int c) {
    fill(c);
    rect(bx + bw * (lo / 100), by, bw * (hi - lo) / 100, bh);
  }

  // 数字の色。点滅を見なくても、上下どちらに振れているかが分かるようにする。
  int glucoseTextColor(Game g, float gv) {
    if (g.foodPop > 0)         return C_NUM_FOOD;
    if (gv < DANGER_ZONE)      return C_NUM_LOW;
    if (g.hyperTimer > 0)      return C_NUM_HIGH;
    return C_NUM_NORMAL;
  }

  // ---- 主人公の右横に追従する縦向きの血糖バー ----
  // 左上のメーターから目を離さずに済むよう、視線の近くにもう1つ置いている。
  // 3Dで求めた画面座標は「実ウィンドウのピクセル」なので、設計座標へ戻してから描く。
  void drawMiniGauge(Game g) {
    if (g.state != STATE_RUNNING) return;

    float dx = (view.miniSX - designOffsetX) / designScale;
    float dy = (view.miniSY - designOffsetY) / designScale;
    // カメラの後ろに回ったときなどの誤描画を防ぐ
    if (dx < -100 || dx > SCREEN_W + 100 || dy < -200 || dy > SCREEN_H + 200) return;

    float bw = MINI_GAUGE_W, bh = MINI_GAUGE_H;
    float x0 = dx, y0 = dy - bh * 0.5;   // 左端・上下中央を投影点に合わせる

    fill(0, 120);
    rect(x0 - 2, y0 - 2, bw + 4, bh + 4, 8);

    // 下が0、上が100。左上のメーターと同じ配色にして読み替えを不要にする。
    vBand(x0, y0, bw, bh, 0,                  DANGER_ZONE * 0.35f, C_GLU_CRITICAL);
    vBand(x0, y0, bw, bh, DANGER_ZONE * 0.35f, DANGER_ZONE,        C_GLU_LOW);
    vBand(x0, y0, bw, bh, DANGER_ZONE,         STABLE_MIN,         C_GLU_MID);
    vBand(x0, y0, bw, bh, STABLE_MIN,          STABLE_MAX,         C_GLU_STABLE);
    vBand(x0, y0, bw, bh, STABLE_MAX,          100,                C_GLU_HIGH);

    drawMiniDangerRing(g, x0, y0, bw, bh);

    float gv = constrain(g.glucose, 0, 100);
    fill(255);
    rect(x0 - 4, y0 + bh * (1 - gv / 100) - 2, bw + 8, 4, 2);   // 針
  }

  // 血糖 lo〜hi の範囲を縦バーの該当位置に塗る
  void vBand(float x0, float y0, float bw, float bh, float lo, float hi, int c) {
    fill(c);
    rect(x0, y0 + bh * (1 - hi / 100), bw, bh * (hi - lo) / 100);
  }

  // 危険なとき枠を光らせる。高血糖=赤の等間隔、低血糖=青の鼓動。
  // 色だけでなく点滅のリズムも変えることで、視界の端でも区別できる。
  void drawMiniDangerRing(Game g, float x0, float y0, float bw, float bh) {
    float gv = constrain(g.glucose, 0, 100);
    int c;
    float a;
    if (g.hyperTimer > 0)      { c = C_RING_HIGH; a = 120 + 135 * abs(sin(millis() * 0.012)); }
    else if (gv < DANGER_ZONE) { c = C_GLU_LOW; a = 110 + 145 * abs(sin(millis() * 0.008)); }
    else return;

    stroke(red(c), green(c), blue(c), a);
    strokeWeight(3);
    noFill();
    rect(x0 - 2, y0 - 2, bw + 4, bh + 4, 8);
    noStroke();
  }

  // ---- ゾーンゲージ ----
  void drawZone(Game g) {
    float px = 24, py = 118, pw = 300, ph = 46;
    fill(0, 150);
    rect(px, py, pw, ph, 10);

    setText(fontSmall, 13);
    textAlign(LEFT, TOP);
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

  // ---- タイム・残り・ベスト ----
  void drawTime(Game g) {
    setText(fontBig, 30);
    textAlign(CENTER, TOP);
    fill(255);
    text(nf(g.elapsed, 1, 2), SCREEN_W * 0.5, 16);

    setText(fontSmall, 13);
    fill(255, 220);
    String sub = "ゴールまで 約" + int(g.secondsToGoal()) + "秒";
    sub += g.bestTime > 0 ? "　ベスト " + nf(g.bestTime, 1, 2) + "秒" : "　ベスト --";
    text(sub, SCREEN_W * 0.5, 56);
  }

  // ---- エリアの地名 ----
  // 区間に入った瞬間だけ大きく出す。日本を縦断していることを伝える表示。
  // 最後の0.6秒はすっと消して、走行の邪魔をしないようにする。
  void drawRegionBanner(Game g) {
    if (g.state != STATE_RUNNING || g.regionBanner <= 0) return;

    float fade = constrain(g.regionBanner / 0.6, 0, 1);
    Region r = regions[g.regionIndex];

    // 「1つ目の区間か、乗り継いで来たか」で言い方を変える
    String label = (g.regionIndex == 0) ? r.name : r.name + " へ";

    setText(fontBig, 44);
    textAlign(CENTER, CENTER);
    fill(0, 150 * fade);
    rect(SCREEN_W * 0.5 - 230, 190, 460, 78, 14);
    fill(255, 255 * fade);
    text(label, SCREEN_W * 0.5, 222);

    setText(fontSmall, 14);
    fill(C_ACCENT, 220 * fade);
    text((g.regionIndex + 1) + " / " + regions.length, SCREEN_W * 0.5, 256);
  }

  // ---- 終盤チャレンジの予告 ----
  // 壁の直前には「食べ物2個+女性」の列が続く。
  // ゾーンで女性側を抜け、壁に備えてマンジャロを温存する——という攻略を、
  // 初見でも判断できるよう手前で知らせる。
  void drawFinalHint(Game g) {
    if (g.state != STATE_RUNNING) return;
    if (g.course.challengeStart < 0 || g.z >= g.course.wallStart) return;

    float sec = (g.course.challengeStart - g.z) / g.runSpeed();
    if (sec > FINAL_WARN_SEC) return;

    String msg = sec > 0
      ? "終盤まで " + max(1, ceil(sec)) + "秒　Zを準備・マンジャロを温存"
      : "Zで女性をすり抜けろ!　マンジャロは次の壁へ温存";

    setText(fontMid, 19);
    textAlign(CENTER, TOP);
    fill(0, 170);
    rect(SCREEN_W * 0.5 - 260, 120, 520, 40, 10);
    fill(255, 220, 90);
    text(msg, SCREEN_W * 0.5, 129);
  }

  // ---- 倒れている間の表示 ----
  // 何が起きたのか分からないまま遅くなるのが一番よくないので、
  // 「倒れた」「治療を受けている」「だから遅い」を言葉で出す。
  void drawCollapse(Game g) {
    if (g.state != STATE_RUNNING || !g.isCollapsed()) return;

    // 画面全体を沈める。倒れている実感と、警告の点滅を隠す役目も兼ねる。
    fill(0, 120);
    rect(0, 0, SCREEN_W, SCREEN_H);

    setText(fontBig, 40);
    textAlign(CENTER, CENTER);
    fill(255, 90, 90);
    text(g.collapseReason + "で倒れた", SCREEN_W * 0.5, SCREEN_H * 0.42);

    setText(fontSmall, 17);
    fill(255, 220);
    text("治療を受けています…  " + nf(g.collapse, 1, 1) + " 秒", SCREEN_W * 0.5, SCREEN_H * 0.52);
  }

  // ---- 血糖の危険警告 ----
  void drawWarnings(Game g) {
    if (g.state != STATE_RUNNING || g.isCollapsed()) return;   // 倒れている間は出さない
    float gv = constrain(g.glucose, 0, 100);

    if (g.hyperTimer > 0) {
      vignette(C_WARN_HIGH, 120 + 100 * abs(sin(millis() * 0.012)));
      setText(fontBig, 28);
      textAlign(CENTER, TOP);
      fill(255, 60, 60);
      text("⚠ 高血糖! あと " + nf(g.hyperTimer, 1, 1) + " 秒", SCREEN_W * 0.5, 88);

    } else if (gv < DANGER_ZONE) {
      vignette(C_GLU_LOW, 90 + 110 * abs(sin(millis() * 0.008)));
      // 青は放っておくと「安全・涼しい」に見える。画面を暗く沈めて、
      // 意識が遠のく感じを出すことで危険さを伝えている。
      fill(0, 60);
      rect(0, 0, SCREEN_W, SCREEN_H);
      setText(fontBig, 28);
      textAlign(CENTER, TOP);
      fill(140, 180, 255);
      text("⚠ 低血糖! 食べろ", SCREEN_W * 0.5, 88);
    }
  }

  // 画面の四辺を帯で覆う簡易ヴィネット
  void vignette(int c, float a) {
    noStroke();
    fill(red(c), green(c), blue(c), a);
    float t = 70;
    rect(0, 0, SCREEN_W, t);
    rect(0, SCREEN_H - t, SCREEN_W, t);
    rect(0, 0, t, SCREEN_H);
    rect(SCREEN_W - t, 0, t, SCREEN_H);
  }
}
