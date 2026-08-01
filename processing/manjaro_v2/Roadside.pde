// ============================================================
// 道の脇に並ぶ景色。建物・木・柱を置いて、走ると横を流れていくようにする。
//
// 【遠景との違い】
// 遠くの景色はプレイヤーに追従するので近づいてこない。
// ここで置くものは【世界の座標に固定】する。だから走れば近づき、大きくなり、
// 横を通り過ぎる。「進んでいる」という感覚は、この層が作る。
//
// 【左右で置くものが違う】
// このゲームは道の左が陸、右が海になっている(View3D の drawGround)。
// だから建物と木は左だけ。右は海なので、防波堤に立つ柱だけを置く。
//
// 【カメラは回らない】
// カメラは主人公の真後ろに固定なので、板を立てるだけで常に正面を向く。
// View3D の billboard() をそのまま使えばいい。
//
// 【まだ沖縄だけ】
// Regions.pde で .area("okinawa") を書いたエリアにだけ景色が出る。
// 他のエリアは素材の確認が済んでから1行ずつ足していく。
// ============================================================

class Roadside {

  void draw(Game g) {
    if (!USE_ROADSIDE || !USE_IMAGES) return;

    Region r = regions[g.regionIndex];
    if (r.areaKey == null) return;          // 景色を設定していないエリアは何も出さない

    // 陸があるのはエリアの中だけ。その外に置くと海の上に建ってしまう。
    // 港とスタート地点の周りも空ける。ゴールゲートや船を隠さないため。
    float landFrom = r.startZ + ROADSIDE_EDGE_CLEAR;
    float landTo   = r.endZ   - ROADSIDE_EDGE_CLEAR;

    drawLeftSide(g, r, landFrom, landTo);
    drawRightSide(g, r, landFrom, landTo);
  }

  // ---- 左(陸側):建物と木 ----
  void drawLeftSide(Game g, Region r, float landFrom, float landTo) {
    PImage bldA = assets.roadside(r.areaKey, "bld_a");
    PImage bldB = assets.roadside(r.areaKey, "bld_b");
    PImage tree = assets.roadside(r.areaKey, "tree");

    // 変数名に to / from を使わないこと。Processing のパーサーが予約語として扱い、
    // 「Syntax Error - Error on variable assignment」で止まる。
    int firstIndex = floor((max(g.z - 30, landFrom)) / ROADSIDE_SPACING);
    int lastIndex  = ceil((min(g.z + DRAW_DIST, landTo)) / ROADSIDE_SPACING);

    for (int i = firstIndex; i <= lastIndex; i++) {
      float z = i * ROADSIDE_SPACING;
      if (z < landFrom || z > landTo) continue;

      float a = view.fadeAlpha(z - g.z);
      if (a <= 0) continue;

      // 大きい建物と小さい建物を交互に。1種類だと同じ形が延々続いて書き割りに見える
      boolean big = (i % 2 == 0);
      PImage img = big ? bldA : bldB;
      float h = big ? ROADSIDE_BLD_H_A : ROADSIDE_BLD_H_B;

      // 大きさと奥行きを少しずつ散らす。等間隔・同一サイズだと並びが目立つ
      h *= 0.88 + 0.24 * noise01(i * 3);
      float x = -(ROADSIDE_BLD_X + 3.0 * noise01(i * 7));

      view.billboard(img, x, 0, z, h, a);

      // 木は建物の間、道に近い側に置く。手前に一段あることで奥行きが出る
      float tz = z + ROADSIDE_SPACING * 0.5;
      if (tz < landFrom || tz > landTo) continue;

      float ta = view.fadeAlpha(tz - g.z);
      if (ta <= 0) continue;

      view.billboard(tree, -(ROADSIDE_TREE_X + 1.5 * noise01(i * 11)), 0, tz,
                     ROADSIDE_TREE_H * (0.85 + 0.3 * noise01(i * 13)), ta);
    }
  }

  // ---- 右(海側):柱だけ ----
  // 海の上に建物は建てられないので、防波堤に立つ街灯や電柱に見立てた柱を置く。
  // 片側だけ景色があると画面が左に偏るので、右にも縦のリズムを作る狙いもある。
  void drawRightSide(Game g, Region r, float landFrom, float landTo) {
    PImage post = assets.roadside(r.areaKey, "post");

    int firstIndex = floor((max(g.z - 30, landFrom)) / ROADSIDE_POST_SPACING);
    int lastIndex  = ceil((min(g.z + DRAW_DIST, landTo)) / ROADSIDE_POST_SPACING);

    for (int i = firstIndex; i <= lastIndex; i++) {
      float z = i * ROADSIDE_POST_SPACING;
      if (z < landFrom || z > landTo) continue;

      float a = view.fadeAlpha(z - g.z);
      if (a <= 0) continue;

      view.billboard(post, ROADSIDE_POST_X, 0, z, ROADSIDE_POST_H, a);
    }
  }

  // 番号から 0〜1 のばらつきを作る。
  // 乱数オブジェクトを使わないのは、Course.pde の乱数を1回でも余計に引くと
  // 食べ物と岩の配置が全部ずれてしまうため。ここは番号だけで決まる値にしている。
  float noise01(int i) {
    float v = sin(i * 12.9898) * 43758.5453;
    return v - floor(v);
  }
}
