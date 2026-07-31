class RoadRenderer {
  PImage backgroundImage;
  float scroll = 0;

  RoadRenderer(PImage bg) {
    backgroundImage = bg;
  }

  void update(float dt, float speed) {
    scroll = (scroll + dt * 0.42 * speed) % 1.0;
  }

  void drawBackground() {
    beginDesignSpace();
    background(0);              // 画面比が合わないPCで余る帯は黒で埋める

    noStroke();
    fill(94, 190, 225);
    rect(0, 0, SCREEN_W, SCREEN_H);   // 画像が無いときの空色

    if (backgroundImage != null) {
      imageMode(CORNER);
      image(backgroundImage, 0, 0, SCREEN_W, SCREEN_H);
    }
    endDesignSpace();
  }

  void drawRoad() {
    beginDesignSpace();
    noStroke();

    float cx = SCREEN_W * 0.5;

    // 路肩の明るい縁。背景の砂色と道路を自然につなぐ。
    fill(246, 199, 119);
    quad(
      cx - ROAD_TOP_HALF - 12, HORIZON_Y,
      cx + ROAD_TOP_HALF + 12, HORIZON_Y,
      cx + ROAD_BOTTOM_HALF + 34, SCREEN_H,
      cx - ROAD_BOTTOM_HALF - 34, SCREEN_H
    );

    // アスファルト。上下で色を変え、奥行きと夕方の光を出す。
    beginShape(QUADS);
    fill(112, 91, 78);
    vertex(cx - ROAD_TOP_HALF, HORIZON_Y);
    vertex(cx + ROAD_TOP_HALF, HORIZON_Y);
    fill(73, 61, 58);
    vertex(cx + ROAD_BOTTOM_HALF, SCREEN_H);
    vertex(cx - ROAD_BOTTOM_HALF, SCREEN_H);
    endShape();

    drawRoadEdges(cx);
    drawLaneMarkers(cx);
    drawMovingHighlights(cx);

    endDesignSpace();
  }

  void drawRoadEdges(float cx) {
    strokeWeight(5);
    stroke(255, 245, 214, 235);
    line(cx - ROAD_TOP_HALF, HORIZON_Y, cx - ROAD_BOTTOM_HALF, SCREEN_H);
    line(cx + ROAD_TOP_HALF, HORIZON_Y, cx + ROAD_BOTTOM_HALF, SCREEN_H);

    strokeWeight(2);
    stroke(91, 50, 38, 140);
    line(cx - ROAD_TOP_HALF - 9, HORIZON_Y, cx - ROAD_BOTTOM_HALF - 25, SCREEN_H);
    line(cx + ROAD_TOP_HALF + 9, HORIZON_Y, cx + ROAD_BOTTOM_HALF + 25, SCREEN_H);
    noStroke();
  }

  void drawLaneMarkers(float cx) {
    for (int divider = 1; divider <= 2; divider++) {
      float laneRatio = divider / 3.0;

      for (int i = 0; i < 14; i++) {
        float t0 = (i / 14.0 + scroll) % 1.0;
        float t1 = min(1.0, t0 + 0.045 + t0 * 0.028);
        if (t1 <= t0) continue;

        float y0 = perspectiveY(t0);
        float y1 = perspectiveY(t1);
        float x0 = laneDividerX(cx, laneRatio, t0);
        float x1 = laneDividerX(cx, laneRatio, t1);
        float w0 = lerp(1.5, 6.0, t0);
        float w1 = lerp(1.5, 10.0, t1);

        fill(255, 249, 225, 230);
        quad(x0 - w0, y0, x0 + w0, y0, x1 + w1, y1, x1 - w1, y1);
      }
    }
  }

  void drawMovingHighlights(float cx) {
    // 道路の色むらを薄く流し、静止した台形に見えるのを防ぐ。
    for (int i = 0; i < 7; i++) {
      float t = (i / 7.0 + scroll * 0.7) % 1.0;
      float y = perspectiveY(t);
      float half = lerp(ROAD_TOP_HALF, ROAD_BOTTOM_HALF, easePerspective(t));
      fill(255, 184, 105, 7 + int(t * 12));
      quad(SCREEN_W * 0.5 - half, y, SCREEN_W * 0.5 + half, y,
           SCREEN_W * 0.5 + half * 1.035, y + 3 + t * 8,
           SCREEN_W * 0.5 - half * 1.035, y + 3 + t * 8);
    }
  }

  float perspectiveY(float t) {
    return lerp(HORIZON_Y, SCREEN_H, easePerspective(t));
  }

  float laneDividerX(float cx, float laneRatio, float t) {
    float topX = lerp(cx - ROAD_TOP_HALF, cx + ROAD_TOP_HALF, laneRatio);
    float bottomX = lerp(cx - ROAD_BOTTOM_HALF, cx + ROAD_BOTTOM_HALF, laneRatio);
    return lerp(topX, bottomX, easePerspective(t));
  }

  float easePerspective(float t) {
    return t * t;
  }
}
