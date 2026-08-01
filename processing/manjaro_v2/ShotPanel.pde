// ============================================================
// 画面右下のマンジャロのパネル。
//
// このゲームでマンジャロが連続で打てないのは、ゲーム上の都合ではなく
// 現実の投与間隔(週1回)を再現しているから。
// 1エリア = 1週間 とみなし、エリアごとに1回だけ打てる。
//
// そのため表示は「補充中」ではなく「今週分は投与済み」とし、
// 待たされている理由が薬のルールだと伝わる言い方にしている。
//
// 【レイアウト】左に注射ペンの絵、右に文字。下に週の使用状況。
//
//   ┌──────────────────────────┐
//   │  ╭──╮   マンジャロ        │
//   │  │ペ│   投与できます      │
//   │  │ン│   スペースで注射    │
//   │  ╰──╯                    │
//   │  ▬▬▬ ▬▬▬ ▬▬▬ ▬▬▬          │
//   │     週1回しか打てない薬    │
//   └──────────────────────────┘
//
// ペンは打てないときだけ暗くする。文字を読まなくても、絵の明るさだけで
// 「いま打てるか」が視界の端で分かるようにするため。
// ============================================================

class ShotPanel {

  // パネルの位置と大きさ(設計座標)
  final float PANEL_W = 300;
  final float PANEL_H = 132;

  // 中の配置。ここを変えれば全体が動く
  final float PEN_BOX_W  = 76;    // 左のペン置き場の幅
  final float TEXT_LEFT  = 92;    // 文字の左端(パネル左からの距離)

  void draw(Game g) {
    float px = SCREEN_W - PANEL_W - 24;
    float py = SCREEN_H - PANEL_H - 24;

    int frameColor = stateColor(g);

    drawFrame(px, py, frameColor);
    drawPen(g, px, py);
    drawLabels(g, px, py, frameColor);
    drawWeekMarks(g, px, py, frameColor);
    drawFooter(px, py);
    drawSpeedItemIcon(g);
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

  // 2行目:その補足。
  // 枠の中に収まる長さにしてある。長くすると右へはみ出す。
  String subtitle(Game g) {
    if (g.lock > 0)       return "取り返すまで " + nf(g.lock, 1, 1) + " 秒";
    if (g.shotEffect > 0) return "血糖が上がらない " + nf(g.shotEffect, 1, 1) + " 秒";
    if (g.canShoot())     return "スペースで注射";
    return "次のエリアまで待つ";
  }

  // ============================================================
  // 各部品
  // ============================================================

  void drawFrame(float px, float py, int frameColor) {
    fill(0, 175);
    stroke(frameColor);
    strokeWeight(3);
    rect(px, py, PANEL_W, PANEL_H, 14);
    noStroke();
  }

  // 注射ペンの絵。枠の左側に立てて置く。
  // 画像が無ければ何も描かない(文字だけのパネルとして成立する)。
  void drawPen(Game g, float px, float py) {
    if (!USE_IMAGES || assets.manjaroPen == null) return;

    float cx = px + 14 + PEN_BOX_W * 0.5;
    sprites.drawCenteredByHeight(assets.manjaroPen, cx, py + 14, 74,
                                 g.canShoot() ? 255 : 85);
  }

  void drawLabels(Game g, float px, float py, int frameColor) {
    float tx = px + TEXT_LEFT;
    textAlign(LEFT, TOP);

    // 見出しは fontBig を使う。fontMid だと「ロ」が □ になることがあったため
    setText(fontBig, 19);
    fill(frameColor);
    text("マンジャロ", tx, py + 14);

    setText(fontSmall, 15);
    fill(255);
    text(title(g), tx, py + 42);

    textSize(11);
    fill(255, 205);
    text(subtitle(g), tx, py + 64);
  }

  // 一番下の一言。ゲームの都合ではなく薬のルールだと伝えるための行。
  void drawFooter(float px, float py) {
    setText(fontSmall, 11);
    textAlign(CENTER, TOP);
    fill(255, 145);
    text("週1回しか打てない薬", px + PANEL_W * 0.5, py + PANEL_H - 22);
  }

  // エリアごとの使用権を、週の数だけ並べて見せる。
  // 「あと何回打てるか」が数字を読まなくても分かる。
  void drawWeekMarks(Game g, float px, float py, int frameColor) {
    if (g.shotUsedInRegion == null) return;

    int weeks = g.shotUsedInRegion.length;
    float gap = 6;
    float left = px + 14;
    float total = PANEL_W - 28;
    float w = (total - gap * (weeks - 1)) / weeks;
    float y = py + PANEL_H - 40;

    for (int i = 0; i < weeks; i++) {
      float x = left + i * (w + gap);

      if (g.shotUsedInRegion[i])   fill(255, 45);      // 使用済み
      else if (i == g.regionIndex) fill(frameColor);   // 今週。打てる
      else                         fill(255, 110);     // まだ先の週

      rect(x, y, w, 8, 4);
    }
  }

  // ============================================================
  // エナジードリンク(パネルの外。持っているときだけ出る)
  // ============================================================

  void drawSpeedItemIcon(Game g) {
    if (!g.speedItemHeld) return;

    float ix = SCREEN_W - 64;
    float iy = SCREEN_H * 0.7;
    fill(0, 180);
    rect(ix - 32, iy - 16, 64, 64, 8);

    if (assets.energy != null) {
      imageMode(CORNER);
      tint(255);
      image(assets.energy, ix - 30, iy - 20, 60, 60);
      noTint();
    } else {
      fill(C_ACCENT);
      setText(fontMid, 16);
      textAlign(CENTER, CENTER);
      text("⚡", ix, iy + 1);
    }

    // 代償を数字で出しておく。使ってから「なぜ倒れたのか」を悩ませないため。
    setText(fontSmall, 12);
    textAlign(CENTER, TOP);
    fill(C_GLU_HIGH);
    text("血糖 +" + int(ENERGY_GAIN), ix, iy + 50);
  }
}
