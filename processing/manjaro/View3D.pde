// ============================================================
// 3D描画。プロトタイプ(Three.js)と同じカメラ・同じ座標系にしてある。
//   ・主人公は原点(x, 0, z)、進行方向は +Z
//   ・カメラは真後ろ上空 (x, CAM_HEIGHT, z - CAM_BACK)
//   ・+Y を上にするため、camera() の up ベクトルを (0,-1,0) にしている
//     (Processing の 3D は既定で +Y が下向きのため)
// 手計算の遠近は一切していない。物を置けば奥行きは自動で付く。
// ============================================================

class View3D {

  void apply(Game g) {
    float vm = speedAtZ(g.z) / BASE_SPEED;

    // 速度が上がるほど画角を広げてスピード感を出す(プロトと同じ演出)
    float fov = FOV_BASE + (vm - 1) * 10 + (g.zoneActive > 0 ? 12 : 0);
    perspective(radians(fov), float(width) / float(height), 1, DRAW_DIST * 1.6);

    camera(
      g.x, CAM_HEIGHT, g.z - CAM_BACK,
      g.x, CAM_LOOK_Y, g.z + CAM_LOOK_AHEAD,
      0, -1, 0
    );

    ambientLight(150, 150, 155);
    directionalLight(120, 120, 115, -0.3, 0.8, 0.5);
  }

  // 遠くのものを薄くする。P3Dにはフォグが無いので、これが無いと
  // 描画限界でいきなり物が現れて反応できない。
  float fadeAlpha(float dz) {
    if (dz > DRAW_DIST) return 0;
    if (dz < DRAW_DIST - FADE_DIST) return 255;
    return map(dz, DRAW_DIST - FADE_DIST, DRAW_DIST, 255, 0);
  }

  void drawWorld(Game g) {
    drawGround(g);
    drawLaneLines(g);
    drawSigns(g);
    drawFoods(g);
    drawWomen(g);
    drawGoal(g);
    drawPlayer(g);
  }

  void drawGround(Game g) {
    float half = LANE_WIDTH * 1.5 + 1;
    float z0 = g.z - CAM_BACK - 10;
    float z1 = g.z + DRAW_DIST;

    noStroke();
    // 道路
    fill(85, 85, 95);
    beginShape(QUADS);
    vertex(-half, 0, z0); vertex(half, 0, z0);
    vertex(half, 0, z1);  vertex(-half, 0, z1);
    endShape();

    // 左右の路肩。左=緑地、右=海
    fill(63, 155, 79);
    beginShape(QUADS);
    vertex(-half - 60, -0.02, z0); vertex(-half, -0.02, z0);
    vertex(-half, -0.02, z1);      vertex(-half - 60, -0.02, z1);
    endShape();

    fill(46, 134, 171);
    beginShape(QUADS);
    vertex(half, -0.02, z0);      vertex(half + 60, -0.02, z0);
    vertex(half + 60, -0.02, z1); vertex(half, -0.02, z1);
    endShape();
  }

  // レーンの区切り線。手前から DRAW_DIST までの分だけ描く。
  void drawLaneLines(Game g) {
    noStroke();
    float step = 8;
    float startZ = floor((g.z - 20) / step) * step;
    for (float lx = -LANE_WIDTH * 0.5; lx <= LANE_WIDTH * 0.5 + 0.01; lx += LANE_WIDTH) {
      for (float lz = startZ; lz < g.z + DRAW_DIST; lz += step) {
        float a = fadeAlpha(lz - g.z);
        if (a <= 0) continue;
        fill(255, a);
        beginShape(QUADS);
        vertex(lx - 0.12, 0.01, lz);     vertex(lx + 0.12, 0.01, lz);
        vertex(lx + 0.12, 0.01, lz + 4); vertex(lx - 0.12, 0.01, lz + 4);
        endShape();
      }
    }
  }

  void drawFoods(Game g) {
    noStroke();
    for (Food f : g.course.foods) {
      if (f.eaten) continue;
      float dz = f.z - g.z;
      if (dz < -5 || dz > DRAW_DIST) continue;
      float a = fadeAlpha(dz);
      if (a <= 0) continue;

      pushMatrix();
      translate(laneToX(f.lane), 1.0, f.z);
      fill(255, 140, 26, a);
      sphere(0.8);
      popMatrix();
    }
  }

  // 女性キャラ。地面の下に隠れていて、直前になるとせり上がる。
  void drawWomen(Game g) {
    noStroke();
    for (Woman w : g.course.women) {
      float dz = w.z - g.z;
      if (dz < -5 || dz > DRAW_DIST) continue;
      float a = fadeAlpha(dz);
      if (a <= 0) continue;

      // 最後に減速するイージングで「ズドン」と出る感じにする
      float e = 1 - pow(1 - w.revealT, 3);
      float y = WOMAN_HIDE_Y * (1 - e);
      if (w.revealT <= 0) continue;   // まだ地中。描かない

      pushMatrix();
      translate(laneToX(w.lane), y, w.z);
      if (w.hit) fill(136, 68, 102, a); else fill(221, 34, 85, a);
      pushMatrix();
      translate(0, 1.0, 0);
      box(1.3, 2.0, 1.0);
      popMatrix();
      fill(240, 192, 144, a);
      pushMatrix();
      translate(0, 2.35, 0);
      sphere(0.45);
      popMatrix();
      popMatrix();
    }
  }

  // 壁の予告看板。見えてから撃つのでは間に合わないので、かなり手前に立っている。
  void drawSigns(Game g) {
    noStroke();
    for (Sign s : g.course.signs) {
      float dz = s.z - g.z;
      if (dz < -5 || dz > DRAW_DIST) continue;
      float a = fadeAlpha(dz);
      if (a <= 0) continue;

      float sx = s.side * (LANE_WIDTH * 1.5 + 2.5);
      pushMatrix();
      translate(sx, 0, s.z);

      fill(107, 107, 115, a);
      pushMatrix();
      translate(0, 2.75, 0);
      box(0.4, 5.5, 0.4);
      popMatrix();

      fill(255, 204, 0, a);
      pushMatrix();
      translate(0, 6.2, 0);
      box(6.2, 3.4, 0.3);
      popMatrix();

      // 3レーン全部ふさがっていることを絵で示す赤いブロック
      fill(204, 34, 34, a);
      for (int i = -1; i <= 1; i++) {
        pushMatrix();
        translate(i * 1.7, 6.2, -0.25);
        box(1.3, 1.3, 0.12);
        popMatrix();
      }
      popMatrix();
    }
  }

  void drawGoal(Game g) {
    float dz = COURSE_LENGTH - g.z;
    if (dz < -20 || dz > DRAW_DIST) return;
    float a = fadeAlpha(dz);
    if (a <= 0) return;

    noStroke();
    fill(255, 204, 0, a);
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

  // 主人公。プロトと同じく、緑の胴体+頭+赤い帽子。
  void drawPlayer(Game g) {
    noStroke();
    pushMatrix();

    // 走りの上下ゆれ。周期を走行速度に比例させないと、速いときに足が滑って見える。
    float bobRate = 6 + 8 * (speedAtZ(g.z) / BASE_SPEED);
    float bob = abs(sin(g.elapsed * bobRate)) * 0.18;

    // 食べた瞬間に一瞬ふくらむ
    float pop = g.foodPop / 0.5;
    float sx = 1 + max(0, pop) * 0.3;

    translate(g.x, bob, g.z);
    scale(sx, 1 + max(0, pop) * 0.15, sx);

    fill(51, 170, 68);
    pushMatrix();
    translate(0, 1.1, 0);
    scale(1, 1.15, 0.9);
    sphere(1.0);
    popMatrix();

    fill(240, 192, 144);
    pushMatrix();
    translate(0, 2.45, 0);
    sphere(0.55);
    popMatrix();

    fill(221, 51, 51);
    pushMatrix();
    translate(0, 2.75, 0);
    box(1.15, 0.35, 1.15);
    popMatrix();

    popMatrix();
  }
}
