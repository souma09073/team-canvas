class RoadsideBlock {
  float progress;
  int side;
  int spriteIndex;
  float sizeVariation;
  float edgeDistance;

  RoadsideBlock(float startProgress, int objectSide, int index) {
    progress = startProgress;
    side = objectSide;
    spriteIndex = index;
    randomizeAppearance();
  }

  void randomizeAppearance() {
    sizeVariation = random(0.92, 1.12);
    edgeDistance = random(116, 172);
  }

  void recycle() {
    progress -= 1.0;
    spriteIndex = int(random(6));
    randomizeAppearance();
  }
}

class RoadsideScenery {
  PImage atlas;
  RoadsideBlock[] blocks;

  RoadsideScenery(PImage blockAtlas) {
    atlas = blockAtlas;
    blocks = new RoadsideBlock[12];

    // 左右それぞれに6街区。片側ずつ連続して通過する間隔にする。
    for (int i = 0; i < blocks.length; i++) {
      int side = i % 2 == 0 ? -1 : 1;
      int orderOnSide = i / 2;
      float stagger = (orderOnSide + (side < 0 ? 0.0 : 0.48)) / 6.0;
      blocks[i] = new RoadsideBlock(stagger, side, i % 6);
    }
  }

  void update(float dt, float speed) {
    for (RoadsideBlock block : blocks) {
      // 道路と同じ走行速度を基準に、近づくほど画面上の移動を速める。
      float approach = 0.090 + block.progress * 0.135;
      block.progress += dt * speed * approach;
      if (block.progress >= 1.0) block.recycle();
    }
  }

  void draw() {
    if (atlas == null) return;

    beginDesignSpace();

    for (int band = 0; band < 30; band++) {
      float low = band / 30.0;
      float high = (band + 1) / 30.0;
      for (RoadsideBlock block : blocks) {
        if (block.progress >= low && block.progress < high) drawBlock(block);
      }
    }

    endDesignSpace();
  }

  void drawBlock(RoadsideBlock block) {
    float t = constrain(block.progress, 0, 1);
    float perspective = t * t;
    float roadHalf = lerp(ROAD_TOP_HALF, ROAD_BOTTOM_HALF, perspective);
    float outward = lerp(22, block.edgeDistance, perspective);
    float x = SCREEN_W * 0.5 + block.side * (roadHalf + outward);
    float y = lerp(HORIZON_Y + 8, SCREEN_H + 60, perspective);

    // 近景では街区が画面の左右を大きく占める。
    float drawH = lerp(70, 650, perspective) * block.sizeVariation;

    int cellW = atlas.width / 3;
    int cellH = atlas.height / 2;
    int col = block.spriteIndex % 3;
    int row = block.spriteIndex / 3;
    float drawW = drawH * (float(cellW) / float(cellH));
    int inset = 4;

    tint(255, lerp(160, 255, t));
    imageMode(CENTER);
    image(
      atlas,
      x, y - drawH * 0.5, drawW, drawH,
      col * cellW + inset, row * cellH + inset,
      (col + 1) * cellW - inset, (row + 1) * cellH - inset
    );
    imageMode(CORNER);
    noTint();
  }
}
