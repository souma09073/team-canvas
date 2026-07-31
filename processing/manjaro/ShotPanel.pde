// ============================================================
// 画面右下のマンジャロのパネル。
//
// このゲームでマンジャロが連続で打てないのは、ゲーム上の都合ではなく
// 現実の投与間隔(週1回)を再現しているから。
// そのため表示は「補充中」ではなく「今週分を投与済み / 次回投与まであと○日」とし、
// 待たされている理由が薬のルールだと伝わる言い方にしている。
// ゲーム内の 7秒 = 現実の 7日 として圧縮している。
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
    drawIntervalBar(g, px, py, frameColor);
  }

  // 状態を色で表す。緑=打てる / 白=いま打った / ピンク=奪われた / 灰=投与待ち
  int stateColor(Game g) {
    if (g.lock > 0)          return C_SHOT_ROBBED;
    if (g.shotFlash > 0)     return C_SHOT_FIRED;
    if (g.shotCooldown > 0)  return C_SHOT_WAIT;
    return C_SHOT_READY;
  }

  // 1行目:いまどういう状態か
  String title(Game g) {
    if (g.lock > 0)         return "奪われた";
    if (g.shotFlash > 0)    return "投与!";
    if (g.shotCooldown > 0) return g.shotEffect > 0 ? "作用中:血糖上昇なし" : "今週分を投与済み";
    return "投与日:使用できます";
  }

  // 2行目:その補足
  String subtitle(Game g) {
    if (g.lock > 0) return "取り返すまで " + nf(g.lock, 1, 1) + " 秒";
    if (g.shotFlash > 0) {
      return g.lastCleared > 0 ? "食べ物 " + g.lastCleared + " 個を消した" : "前方に食べ物なし";
    }
    if (g.shotCooldown > 0) {
      if (g.shotEffect > 0) return "低下はゆっくり継続";
      int daysLeft = max(1, ceil(g.shotCooldown / SHOT_COOLDOWN * 7));
      return "次回投与まで あと" + daysLeft + "日";
    }
    return "スペースで注射";
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

    textSize(13);
    fill(255, 210);
    text(subtitle(g), cx, py + 60);

    textSize(11);
    fill(255, 150);
    text("週1回しか打てない薬", cx, py + 103);
  }

  // 投与間隔のゲージ。満タン = 打てる。
  // 数字を読まなくても、溜まっていく様子で「あとどれくらい待つか」が分かる。
  void drawIntervalBar(Game g, float px, float py, int frameColor) {
    float bx = px + 16, by = py + 88;
    float bw = PANEL_W - 32, bh = 10;

    float ratio = 1;
    if (g.lock > 0)              ratio = 1 - g.lock / LOCK_DURATION;
    else if (g.shotCooldown > 0) ratio = 1 - g.shotCooldown / SHOT_COOLDOWN;

    fill(255, 40);
    rect(bx, by, bw, bh, 5);
    fill(frameColor);
    rect(bx, by, bw * constrain(ratio, 0, 1), bh, 5);
  }
}
