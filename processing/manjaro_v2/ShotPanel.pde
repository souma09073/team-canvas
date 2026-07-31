// ============================================================
// 画面右下のマンジャロのパネル。
//
// このゲームでマンジャロが連続で打てないのは、ゲーム上の都合ではなく
// 現実の投与間隔(週1回)を再現しているから。
// 1エリア = 1週間 とみなし、エリアごとに1回だけ打てる。
//
// そのため表示は「補充中」ではなく「今週分は投与済み」とし、
// 待たされている理由が薬のルールだと伝わる言い方にしている。
// ============================================================

class ShotPanel {

  // パネルの位置と大きさ(設計座標)
  final float PANEL_W = 250;
  final float PANEL_H = 128;

  void draw(Game g) {
    float px = SCREEN_W - PANEL_W - 24;
    float py = SCREEN_H - PANEL_H - 24;

    int frameColor = stateColor(g);

    drawFrame(px, py, frameColor);
    drawLabels(g, px, py, frameColor);
    drawWeekMarks(g, px, py, frameColor);
  }

  // 状態を色で表す。緑=打てる / 白=効いている / ピンク=奪われた / 灰=今週分は使用済み
  int stateColor(Game g) {
    if (g.lock > 0)       return C_SHOT_ROBBED;
    if (g.shotEffect > 0) return C_SHOT_FIRED;
    if (g.canShoot())     return C_SHOT_READY;
    return C_SHOT_WAIT;
  }

  // 1行目:いまどういう状態か
  String title(Game g) {
    if (g.lock > 0)       return "奪われた";
    if (g.shotEffect > 0) return "作用中";
    if (g.canShoot())     return "投与できます";
    return "今週分は投与済み";
  }

  // 2行目:その補足
  String subtitle(Game g) {
    if (g.lock > 0)       return "取り返すまで " + nf(g.lock, 1, 1) + " 秒";
    if (g.shotEffect > 0) return "食べても血糖は上がらない  " + nf(g.shotEffect, 1, 1) + " 秒";
    if (g.canShoot())     return "スペースで注射";
    return "次のエリアまで打てません";
  }

  void drawFrame(float px, float py, int frameColor) {
    fill(0, 165);
    stroke(frameColor);
    strokeWeight(3);
    rect(px, py, PANEL_W, PANEL_H, 14);
    noStroke();
  }

  void drawLabels(Game g, float px, float py, int frameColor) {
    float cx = px + PANEL_W * 0.5;
    textAlign(CENTER, TOP);

    setText(fontMid, 19);
    fill(frameColor);
    text("マンジャロ", cx, py + 10);

    setText(fontSmall, 15);
    fill(255);
    text(title(g), cx, py + 38);

    textSize(12);
    fill(255, 210);
    text(subtitle(g), cx, py + 60);

    textSize(11);
    fill(255, 150);
    text("週1回しか打てない薬", cx, py + 105);
  }

  // エリアごとの使用権を、週の数だけ並べて見せる。
  // 「あと何回打てるか」が数字を読まなくても分かる。
  void drawWeekMarks(Game g, float px, float py, int frameColor) {
    if (g.shotUsedInRegion == null) return;

    int weeks = g.shotUsedInRegion.length;
    float gap = 6;
    float w = (PANEL_W - 32 - gap * (weeks - 1)) / weeks;
    float y = py + 84;

    for (int i = 0; i < weeks; i++) {
      float x = px + 16 + i * (w + gap);

      if (g.shotUsedInRegion[i])   fill(255, 45);      // 使用済み
      else if (i == g.regionIndex) fill(frameColor);   // 今週。打てる
      else                         fill(255, 110);     // まだ先の週

      rect(x, y, w, 8, 4);
    }
  }
}
