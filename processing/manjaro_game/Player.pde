class SweatDrop {
  float x;
  float y;
  float vx;
  float vy;
  float life;
  float maxLife;
  float size;

  SweatDrop(float startX, float startY, int side) {
    x = startX + side * random(30, 48);
    y = startY + random(-7, 14);
    vx = side * random(50, 84);
    vy = random(-78, -42);
    maxLife = random(0.40, 0.62);
    life = maxLife;
    size = random(7, 12);
  }

  void update(float dt) {
    x += vx * dt;
    y += vy * dt;
    vy += 110 * dt;
    life -= dt;
  }

  void draw() {
    float alpha = 255 * constrain(life / maxLife, 0, 1);
    noStroke();
    fill(188, 237, 255, alpha);
    stroke(255, alpha * 0.8);
    strokeWeight(1.2);
    pushMatrix();
    translate(x, y);
    rotate(atan2(vy, vx) + HALF_PI);
    ellipse(0, 0, size * 0.72, size * 1.45);
    popMatrix();
    noStroke();
  }
}

class Runner {
  PImage[] cycleSheets;
  PImage sprite;
  ArrayList<SweatDrop> sweat = new ArrayList<SweatDrop>();

  int lane = 1;
  float screenX = LANE_SCREEN_X[1];
  float strideDistance = 0;
  float runSpeed = 1.0;
  float sweatTimer = 0;
  int sweatSide = -1;

  // 30コマそれぞれの「実際に絵が描かれている範囲」。
  // 生成した絵はコマごとに位置も大きさもバラバラで(実測: 体の中心が最大113px、
  // 足元が37pxもずれている)、固定の切り出しでは左右にガタつき、地面に沈んだり浮いたりする。
  // 起動時に1回だけ実測し、足元と体の中心を揃えて描くことでカクつきを消す。
  int[] frameX = new int[30];
  int[] frameY = new int[30];
  int[] frameW = new int[30];
  int[] frameH = new int[30];
  float frameScale = 1;      // 全コマ共通の倍率。コマごとに変えるとサイズが揺れる
  boolean framesMeasured = false;

  Runner(PImage[] sheetImages, PImage spriteImage) {
    cycleSheets = sheetImages;
    sprite = spriteImage;
    measureFrames();
  }

  // 各コマの不透明ピクセルの外接矩形を求める。
  void measureFrames() {
    if (cycleSheets == null || cycleSheets.length != 5) return;

    int tallest = 1;
    for (int f = 0; f < 30; f++) {
      PImage sheet = cycleSheets[f / 6];
      if (sheet == null) return;
      sheet.loadPixels();

      int cellW = sheet.width / 3;
      int cellH = sheet.height / 2;
      int local = f % 6;
      int ox = (local % 3) * cellW;
      int oy = (local / 3) * cellH;

      int minX = cellW, maxX = -1, minY = cellH, maxY = -1;
      for (int y = 0; y < cellH; y++) {
        int rowBase = (oy + y) * sheet.width + ox;
        for (int x = 0; x < cellW; x++) {
          if (((sheet.pixels[rowBase + x] >> 24) & 0xFF) > 40) {
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }
      if (maxX < 0) {   // 透明だけのコマ。念のためセル全体を使う
        minX = 0; minY = 0; maxX = cellW - 1; maxY = cellH - 1;
      }

      frameX[f] = ox + minX;
      frameY[f] = oy + minY;
      frameW[f] = maxX - minX + 1;
      frameH[f] = maxY - minY + 1;
      if (frameH[f] > tallest) tallest = frameH[f];
    }

    // 一番背の高いコマが PLAYER_HEIGHT になるよう、全コマを同じ倍率で描く。
    // コマごとに高さを揃えると、走行中の縮み(接地時のスクワッシュ)まで潰れて不自然になる。
    frameScale = PLAYER_HEIGHT / float(tallest);
    framesMeasured = true;
    println("走行コマの自動整列: 完了(基準の高さ " + tallest + "px, 倍率 " + nf(frameScale, 1, 3) + ")");
  }

  void reset() {
    lane = 1;
    screenX = LANE_SCREEN_X[1];
    strideDistance = 0;
    sweat.clear();
    sweatTimer = 0;
  }

  void moveLeft() {
    lane = max(0, lane - 1);
  }

  void moveRight() {
    lane = min(2, lane + 1);
  }

  void update(float dt) {
    float targetX = LANE_SCREEN_X[lane];
    float follow = 1.0 - exp(-PLAYER_LANE_SMOOTH * dt);
    screenX = lerp(screenX, targetX, follow);

    // 走行距離に同期した1周期30コマ。
    strideDistance += dt * runSpeed * 1.48;

    sweatTimer -= dt;
    if (sweatTimer <= 0) {
      float headY = PLAYER_BASE_Y - 285 - abs(sin(runPhase())) * 8;
      sweat.add(new SweatDrop(screenX, headY, sweatSide));
      sweatSide *= -1;
      sweatTimer = random(0.10, 0.16);
    }

    for (int i = sweat.size() - 1; i >= 0; i--) {
      SweatDrop drop = sweat.get(i);
      drop.update(dt);
      if (drop.life <= 0) sweat.remove(i);
    }
  }

  int animationFrame() {
    return floor(strideDistance * 30.0) % 30;
  }

  float runPhase() {
    return TWO_PI * animationFrame() / 30.0;
  }

  void draw() {
    hint(DISABLE_DEPTH_TEST);
    camera();
    ortho();

    for (SweatDrop drop : sweat) drop.draw();

    float phase = runPhase();
    float bob = -abs(sin(phase)) * 9;
    float landing = pow(abs(cos(phase)), 8);
    float targetX = LANE_SCREEN_X[lane];
    float laneLean = constrain((targetX - screenX) * 0.0017, -0.10, 0.10);
    float squashX = 1.0 + landing * 0.025;
    float squashY = 1.0 - landing * 0.032;

    noStroke();
    fill(49, 25, 15, 92);
    ellipse(screenX, PLAYER_BASE_Y + 4, 154 + landing * 18, 24 - landing * 3);

    if (framesMeasured) {
      drawThirtyFrameCycle(bob, laneLean, squashX, squashY);
    } else if (sprite != null) {
      float aspect = float(sprite.width) / float(sprite.height);
      imageMode(CENTER);
      image(sprite, screenX, PLAYER_BASE_Y - PLAYER_HEIGHT * 0.5 + bob,
            PLAYER_HEIGHT * aspect * squashX, PLAYER_HEIGHT * squashY);
      imageMode(CORNER);
    }

    hint(ENABLE_DEPTH_TEST);
  }

  void drawThirtyFrameCycle(
    float bob,
    float lean,
    float squashX,
    float squashY
  ) {
    int frame30 = animationFrame();

    pushMatrix();
    translate(screenX, PLAYER_BASE_Y + bob);
    rotate(lean);

    // 30枚を直接表示するため、補間による二重像は発生しない。
    drawPose(frame30, squashX, squashY);

    popMatrix();
  }

  void drawPose(int frame30, float squashX, float squashY) {
    PImage sheet = cycleSheets[frame30 / 6];

    // 実測した外接矩形をそのまま切り出す。固定の余白(旧 sideInset=54)だと、
    // セルの左端から絵が始まっているコマで体の左側が切り落とされていた。
    float drawW = frameW[frame30] * frameScale * squashX;
    float drawH = frameH[frame30] * frameScale * squashY;

    noTint();
    imageMode(CENTER);
    // 呼び出し元が原点を「足元」に移してあるので、中心を上へ半分ずらせば足が接地する。
    // 切り出しが外接矩形ぴったりなので、これで全コマの足元と中心が完全に揃う。
    image(
      sheet,
      0, -drawH * 0.5, drawW, drawH,
      frameX[frame30], frameY[frame30],
      frameX[frame30] + frameW[frame30], frameY[frame30] + frameH[frame30]
    );
    imageMode(CORNER);
  }
}
