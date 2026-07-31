// ============================================================
// マンジャロ日本縦断ゲーム
// Visual Prototype 01: 主人公・道路・沖縄背景
// ============================================================

AssetStore assets;
Runner player;
RoadRenderer road;
RoadsideScenery scenery;
PrototypeHUD hud;

void settings() {
  // ディスプレイに収まる最大の16:9サイズを選ぶ。1280x720 を決め打ちにすると、
  // 画面の小さいPCや表示倍率(125%/150%)の設定でウィンドウがはみ出してしまう。
  int w = min(SCREEN_W, int(displayWidth * 0.92));
  int h = w * SCREEN_H / SCREEN_W;
  if (h > displayHeight * 0.88) {
    h = int(displayHeight * 0.88);
    w = h * SCREEN_W / SCREEN_H;
  }
  size(w, h, P3D);
  smooth(8);
}

void setup() {
  surface.setTitle("マンジャロ日本縦断ゲーム - Visual Prototype");
  frameRate(60);
  computeDesignTransform();

  assets = new AssetStore();
  assets.load();

  player = new Runner(assets.runCycleSheets, assets.runner);
  road = new RoadRenderer(assets.okinawaFar);
  scenery = new RoadsideScenery(assets.okinawaBlocks);
  hud = new PrototypeHUD();
}

void draw() {
  float dt = min(0.05, 1.0 / max(frameRate, 1));

  player.update(dt);
  road.update(dt, player.runSpeed);
  scenery.update(dt, player.runSpeed);

  road.drawBackground();
  road.drawRoad();
  scenery.draw();
  player.draw();
  hud.draw(player);
}

void keyPressed() {
  if (keyCode == LEFT || key == 'a' || key == 'A') {
    player.moveLeft();
  } else if (keyCode == RIGHT || key == 'd' || key == 'D') {
    player.moveRight();
  } else if (key == 'r' || key == 'R') {
    player.reset();
  }
}
