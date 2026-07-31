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
  size(1280, 720, P3D);
  smooth(8);
}

void setup() {
  surface.setTitle("マンジャロ日本縦断ゲーム - Visual Prototype");
  frameRate(60);

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
