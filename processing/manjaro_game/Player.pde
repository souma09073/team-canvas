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

  Runner(PImage[] sheetImages, PImage spriteImage) {
    cycleSheets = sheetImages;
    sprite = spriteImage;
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

    if (cycleSheets != null && cycleSheets.length == 5 && cycleSheets[0] != null) {
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
    int sheetIndex = frame30 / 6;
    int localFrame = frame30 % 6;
    PImage sheet = cycleSheets[sheetIndex];
    int col = localFrame % 3;
    int row = localFrame / 3;
    int cellW = sheet.width / 3;
    int cellH = sheet.height / 2;

    // 各セルの余白だけを除き、30枚すべてを同じ大きさで描く。
    int sideInset = 54;
    int verticalInset = 6;
    int cropX = col * cellW + sideInset;
    int cropY = row * cellH + verticalInset;
    int cropW = cellW - sideInset * 2;
    int cropH = cellH - verticalInset * 2;

    float drawH = PLAYER_HEIGHT * squashY;
    float drawW = drawH * (float(cropW) / float(cropH)) * squashX;

    noTint();
    imageMode(CENTER);
    image(
      sheet,
      0, -drawH * 0.5, drawW, drawH,
      cropX, cropY,
      cropX + cropW, cropY + cropH
    );
    imageMode(CORNER);
  }
}
