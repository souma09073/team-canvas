// ============================================================
// 3D描画。
//
// 【要点】遠近感の計算は一切していない。
// カメラを主人公の後ろに置き、物を (横, 高さ, 前後) の座標に置くだけ。
// 遠くのものが小さく見えるのは Processing が勝手にやってくれる。
//
// 座標の決まり:
//   X … 横。+が画面の右
//   Y … 高さ。+が上(camera() の up を (0,-1,0) にして上向きに揃えている)
//   Z … 前後。+が進行方向
//
// 3Dモデルは1つも使っていない。球(sphere)と箱(box)だけで作っている。
// ============================================================

class View3D {

  // ミニ血糖バーを出す画面座標(実ウィンドウのピクセル)。
  // screenX()/screenY() は 3Dのカメラが有効な間しか正しい値を返さないので、
  // HUD が camera() でリセットする前に計算して覚えておく。
  float miniSX = 0, miniSY = 0;

  void computeMiniGaugePos(Game g) {
    float wx = g.x + MINI_GAUGE_SIDE;
    miniSX = screenX(wx, MINI_GAUGE_BODY_Y, g.z);
    miniSY = screenY(wx, MINI_GAUGE_BODY_Y, g.z);
  }

  // ============================================================
  // カメラと光
  // ============================================================

  void apply(Game g) {
    float speedRatio = speedAtZ(g.z) / baseSpeedRef();   // 序盤1.0 → ゴール2.8

    // 速度が上がるほど画角を広げる。視界の端が流れてスピード感が出る。
    float fov = FOV_BASE + (speedRatio - 1) * 10 + (g.zoneActive > 0 ? 12 : 0);
    perspective(radians(fov), float(width) / float(height), 1, DRAW_DIST * 1.6);

    // 主人公の真後ろ上空から、少し前方を見る
    camera(
      g.x, CAM_HEIGHT, g.z - CAM_BACK,          // カメラの位置
      g.x, CAM_LOOK_Y, g.z + CAM_LOOK_AHEAD,    // 見る先
      0, -1, 0                                  // 上の向き(+Yを上にするため)
    );

    applySceneLights();
  }

  // 球や箱に立体感を出すための光。
  // ビルボード(絵)には掛けない。イラストは陰影が描き込まれているので、
  // さらに光を掛けると色が濁って暗くなる。
  void applySceneLights() {
    ambientLight(150, 150, 155);
    directionalLight(120, 120, 115, -0.3, 0.8, 0.5);
  }

  // 遠くのものを薄くする。
  // P3D には霧(フォグ)が無いので、これが無いと描画限界でいきなり物が現れる。
  float fadeAlpha(float distance) {
    if (distance > DRAW_DIST) return 0;
    if (distance < DRAW_DIST - FADE_DIST) return 255;
    return map(distance, DRAW_DIST - FADE_DIST, DRAW_DIST, 255, 0);
  }

  // 描く必要があるか。手前を過ぎたもの、遠すぎるものは描かない。
  boolean isVisible(float objZ, float playerZ) {
    float d = objZ - playerZ;
    return d >= -5 && d <= DRAW_DIST;
  }

  // ============================================================
  // 世界を描く。手前に来るものほど後に描く必要はない(3Dが奥行きを判定する)。
  // ============================================================

  void drawWorld(Game g) {
    drawGround(g);
    drawLaneLines(g);
    drawSigns(g);
    drawFoods(g);
    drawWomen(g);
    drawGoal(g);
    drawPlayer(g);
  }

  // ---- 地面 ----
  // 主人公の周りだけを板で描く。コース全体を描くと無駄が大きい。
  //
  // 陸と海は、日本を縦断するにつれて色が変わる。
  // 1枚の板で塗ると色を変えられないので、奥行き方向に細かく切って
  // 1枚ずつその地点の色で塗っている。
  void drawGround(Game g) {
    float half = LANE_WIDTH * 1.5 + 1;
    float zNear = g.z - CAM_BACK - 10;
    float zFar  = g.z + DRAW_DIST;

    noStroke();

    // 道路はどこでも同じ色なので1枚でいい
    fill(C_ROAD);
    flatQuad(-half, half, zNear, zFar, 0);

    // 陸と海は区間ごとに色が変わるので、細かく切って塗る。
    // わずかに下げて道路と重ならないようにしている。
    for (float z = zNear; z < zFar; z += GROUND_SLICE) {
      float z2 = min(z + GROUND_SLICE, zFar);
      float mid = (z + z2) * 0.5;   // その断片の代表点で色を決める

      fill(landColorAt(mid));
      flatQuad(-half - 60, -half, z, z2, -0.02);

      fill(seaColorAt(mid));
      flatQuad(half, half + 60, z, z2, -0.02);
    }
  }

  // 地面に平らな四角を1枚置く
  void flatQuad(float x1, float x2, float z1, float z2, float y) {
    beginShape(QUADS);
    vertex(x1, y, z1);
    vertex(x2, y, z1);
    vertex(x2, y, z2);
    vertex(x1, y, z2);
    endShape();
  }

  // ---- レーンの区切り線 ----
  // 白線が手前へ流れることで、止まっていないことが伝わる。
  void drawLaneLines(Game g) {
    noStroke();
    float spacing = 8;
    float startZ = floor((g.z - 20) / spacing) * spacing;

    for (float lx = -LANE_WIDTH * 0.5; lx <= LANE_WIDTH * 0.5 + 0.01; lx += LANE_WIDTH) {
      for (float lz = startZ; lz < g.z + DRAW_DIST; lz += spacing) {
        float a = fadeAlpha(lz - g.z);
        if (a <= 0) continue;
        fill(C_LANE_LINE, a);
        beginShape(QUADS);
        vertex(lx - 0.12, 0.01, lz);
        vertex(lx + 0.12, 0.01, lz);
        vertex(lx + 0.12, 0.01, lz + 4);
        vertex(lx - 0.12, 0.01, lz + 4);
        endShape();
      }
    }
  }

  // ---- 食べ物 ----
  // マンジャロが効いている間は灰色になる。「そこにあるのに、食べたいと思わない」の表現。
  // 食べ物は消えず、素通りするだけなので、色でしか効いていることが分からない。
  // だから、はっきり見分けがつく色にしてある。
  void drawFoods(Game g) {
    noStroke();
    boolean blocked = (g.shotEffect > 0);

    for (Food f : g.course.foods) {
      if (f.eaten || !isVisible(f.z, g.z)) continue;
      float a = fadeAlpha(f.z - g.z);
      if (a <= 0) continue;

      pushMatrix();
      translate(laneToX(f.lane), 1.0, f.z);
      fill(blocked ? C_FOOD_BLOCKED : C_FOOD, blocked ? a * 0.55 : a);
      sphere(0.8);
      popMatrix();
    }
  }

  // ---- 女性キャラ ----
  // 普段は地面の下に隠れていて、直前になるとせり上がってくる。
  void drawWomen(Game g) {
    noStroke();
    for (Woman w : g.course.women) {
      if (w.revealT <= 0 || !isVisible(w.z, g.z)) continue;   // まだ地中なら描かない
      float a = fadeAlpha(w.z - g.z);
      if (a <= 0) continue;

      // 最後に減速するイージング。「ズドン」と出る感じになる
      float ease = 1 - pow(1 - w.revealT, 3);
      float y = WOMAN_HIDE_Y * (1 - ease);

      pushMatrix();
      translate(laneToX(w.lane), y, w.z);

      fill(w.hit ? C_WOMAN_HIT : C_WOMAN, a);
      pushMatrix();
      translate(0, 1.0, 0);
      box(1.3, 2.0, 1.0);
      popMatrix();

      fill(C_PLAYER_SKIN, a);
      pushMatrix();
      translate(0, 2.35, 0);
      sphere(0.45);
      popMatrix();

      popMatrix();
    }
  }

  // ---- 壁の予告看板 ----
  // 壁が見えてから撃つのでは投与間隔が間に合わないので、かなり手前に立っている。
  void drawSigns(Game g) {
    noStroke();
    for (Sign s : g.course.signs) {
      if (!isVisible(s.z, g.z)) continue;
      float a = fadeAlpha(s.z - g.z);
      if (a <= 0) continue;

      pushMatrix();
      translate(s.side * (LANE_WIDTH * 1.5 + 2.5), 0, s.z);
      drawSignPost(a);
      drawSignBoard(a);
      popMatrix();
    }
  }

  void drawSignPost(float a) {
    fill(C_SIGN_POST, a);
    pushMatrix();
    translate(0, 2.75, 0);
    box(0.4, 5.5, 0.4);
    popMatrix();
  }

  void drawSignBoard(float a) {
    fill(C_SIGN_BOARD, a);
    pushMatrix();
    translate(0, 6.2, 0);
    box(6.2, 3.4, 0.3);
    popMatrix();

    // 「3レーン全部ふさがっている」ことを絵で示す赤いブロック3つ。
    // 板の手前側(-Z)に少し出して、正面から見えるようにしている。
    fill(C_SIGN_MARK, a);
    for (int i = -1; i <= 1; i++) {
      pushMatrix();
      translate(i * 1.7, 6.2, -0.25);
      box(1.3, 1.3, 0.12);
      popMatrix();
    }
  }

  // ---- ゴールゲート ----
  void drawGoal(Game g) {
    if (!isVisible(COURSE_LENGTH, g.z) && COURSE_LENGTH - g.z > 0) return;
    float a = fadeAlpha(COURSE_LENGTH - g.z);
    if (a <= 0) return;

    noStroke();
    fill(C_GOAL, a);
    for (int side = -1; side <= 1; side += 2) {
      pushMatrix();
      translate(side * (LANE_WIDTH * 1.5 + 1), 4, COURSE_LENGTH);
      box(0.6, 8, 0.6);
      popMatrix();
    }
    pushMatrix();
    translate(0, 8, COURSE_LENGTH);
    box(LANE_WIDTH * 3 + 4, 1, 0.6);
    popMatrix();
  }

  // ============================================================
  // ビルボード(板に絵を貼る)
  //
  // このゲームはカメラが主人公の真後ろに固定で、一度も回転しない。
  // だから板は常に正面を向いていて、向きを合わせる計算が要らない。
  // 板を立てて絵を貼るだけでいい。
  //
  // 原点は「足元」。そこから上へ h の高さに立てる。
  // ============================================================
  void billboard(PImage img, float x, float y, float z, float h, float alpha) {
    float w = h * img.width / float(img.height);   // 縦横比は元画像のまま

    pushMatrix();
    translate(x, y, z);
    if (BILLBOARD_TILT != 0) rotateX(radians(BILLBOARD_TILT));

    // 光を切って、絵の色をそのまま出す。
    // 切らないと 3Dの照明が掛かって、鮮やかな緑が暗いオリーブ色に濁る。
    noLights();

    tint(255, alpha);
    noStroke();
    beginShape(QUAD);
    texture(img);
    // UV は既定の IMAGE モードなのでピクセル単位で指定する。
    // 画像の上端(v=0)が板の上(y=h)に来る。
    vertex(-w * 0.5, h, 0, 0,         0);
    vertex( w * 0.5, h, 0, img.width, 0);
    vertex( w * 0.5, 0, 0, img.width, img.height);
    vertex(-w * 0.5, 0, 0, 0,         img.height);
    endShape();
    noTint();

    popMatrix();
    applySceneLights();   // 次に描く球や箱のために光を戻す
  }

  // 地面に落とす楕円の影。地面すれすれ(y=0.02)に寝かせて置く。
  void drawGroundShadow(float x, float z, float size) {
    noLights();
    noStroke();
    fill(0, 70);
    pushMatrix();
    translate(x, 0.02, z);
    rotateX(HALF_PI);      // 縦の円を寝かせて地面に貼る
    ellipse(0, 0, size, size * 0.5);
    popMatrix();
    applySceneLights();
  }

  // ---- 主人公 ----
  // 画像があれば板に貼って描き、無ければ球と箱で描く。
  void drawPlayer(Game g) {
    // 走りの上下ゆれ。周期を走行速度に比例させないと、速いときに足が滑って見える。
    float bobRate = 6 + 8 * (speedAtZ(g.z) / baseSpeedRef());
    float bob = abs(sin(g.elapsed * bobRate)) * 0.18;
    float pop = max(0, g.foodPop / FOOD_POP_SEC);   // 食べた瞬間に一瞬ふくらむ

    if (USE_IMAGES && assets.player != null) {
      // 影は必ず地面(y=0)に置く。主人公は跳ねるので、影が離れるほど跳んで見える。
      // 影が無いと、地面に立っているのか浮いているのか分からない。
      drawGroundShadow(g.x, g.z, 1.5 - bob * 0.8);

      // 絵の縦横を少しだけ変えて、着地の重みと食べた瞬間の反応を出す
      float squash = 1 - abs(sin(g.elapsed * bobRate)) * 0.04;
      billboard(assets.player, g.x, bob, g.z,
                PLAYER_IMG_HEIGHT * squash * (1 + pop * 0.15), 255);
      return;
    }

    drawPlayerShapes(g, bob, pop);
  }

  // 画像が無いときの主人公。球(胴体)+ 球(頭)+ 箱(帽子)。
  void drawPlayerShapes(Game g, float bob, float pop) {
    noStroke();
    pushMatrix();
    translate(g.x, bob, g.z);
    scale(1 + pop * 0.3, 1 + pop * 0.15, 1 + pop * 0.3);

    fill(C_PLAYER_BODY);
    pushMatrix();
    translate(0, 1.1, 0);
    scale(1, 1.15, 0.9);      // 縦長・薄めにして体型を出す
    sphere(1.0);
    popMatrix();

    fill(C_PLAYER_SKIN);
    pushMatrix();
    translate(0, 2.45, 0);
    sphere(0.55);
    popMatrix();

    fill(C_PLAYER_CAP);
    pushMatrix();
    translate(0, 2.75, 0);
    box(1.15, 0.35, 1.15);
    popMatrix();

    popMatrix();
  }
}
