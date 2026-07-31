// ============================================================
// マンジャロ日本縦断ゲーム
// HTMLプロトタイプ(prototype/prototype.html)の完全移植版。
//
// 見た目はプリミティブ(球と箱)の仮。まずゲームとして成立させ、
// そのあとイラストを差し替えていく方針。
//
//   Config.pde … 調整する数値。全部ここ
//   Course.pde … コース生成(シード固定)
//   Game.pde   … ゲームのルール。描画には触れない
//   View3D.pde … 3D描画
//   Hud.pde    … 画面表示
// ============================================================

Game game;
View3D view;
Hud hud;
Assets assets;

void settings() {
  if (FULLSCREEN) {
    // 画面いっぱいに開く。どんな解像度・表示倍率のPCでも必ず収まる。
    fullScreen(P3D);
  } else {
    // ウィンドウ表示。ディスプレイに収まる最大の16:9を選ぶ。
    // ただし表示倍率が効いている環境では、指定より大きく表示されてはみ出すことがある。
    int w = min(SCREEN_W, int(displayWidth * 0.85));
    int h = w * SCREEN_H / SCREEN_W;
    if (h > displayHeight * 0.80) {
      h = int(displayHeight * 0.80);
      w = h * SCREEN_W / SCREEN_H;
    }
    size(w, h, P3D);
  }
  smooth(4);
}

void setup() {
  surface.setTitle("マンジャロ日本縦断");
  frameRate(60);
  if (!FULLSCREEN) surface.setResizable(true);   // 収まらないとき手で直せるように
  computeDesignTransform();

  game = new Game();
  view = new View3D();
  hud  = new Hud();

  buildRegions();  // エリア(沖縄→西日本→東日本→北海道)の定義を作る

  assets = new Assets();
  assets.load();   // 画像が無ければ null のまま。描画側が仮の図形に切り替わる

  loadFonts();
  game.loadBest();
  game.course.build();
  lastMillis = millis();   // 1フレーム目に起動時間ぶんの dt が入らないようにする

  // HTMLプロトタイプと同じコースが生成できているかを、起動時に照合できるようにする。
  // 期待値(prototype.html から算出):
  //   コース長 7315 / 食べ物 153 個 / 女性 7 体 / 壁 z=5917-6112 / 終盤 z=5722
  // ここがずれていたら、乱数か配置ロジックの移植を間違えている。
  println("--- コース照合 ---");
  println("コース長  " + int(COURSE_LENGTH) + " units   (期待 7315)");
  println("速度      " + int(BASE_SPEED) + " -> " + int(BASE_SPEED * RAMP_END_MULT) + " units/s");
  println("食べ物    " + game.course.foods.size() + " 個   (期待 153)");
  println("女性      " + game.course.women.size() + " 体   (期待 7)");
  println("壁        z=" + int(game.course.wallStart) + "-" + int(game.course.wallEnd) + "   (期待 5917-6112)");
  println("終盤入口  z=" + int(game.course.challengeStart) + "   (期待 5722)");
}

int lastMillis = 0;
int lastW = 0, lastH = 0;   // ウィンドウの大きさ。変わったら表示倍率を計算し直す

void draw() {
  // ウィンドウをドラッグで広げたときにもレイアウトを追従させる
  if (width != lastW || height != lastH) {
    computeDesignTransform();
    lastW = width;
    lastH = height;
  }

  // 経過時間は実測する。1.0/frameRate は「平均フレームレートからの推定値」なので、
  // 実際のフレーム間隔とずれると、血糖の増減やタイマーの進み方が本来より速くも遅くもなる。
  // (Processing は起動直後 frameRate を 10 として返すため、開始直後ほどずれが大きい)
  // HTML版と同じく、実際に経過したミリ秒から求める。
  int now = millis();
  float dt = (now - lastMillis) / 1000.0;
  lastMillis = now;
  dt = min(0.05, dt);   // タブ切替などで巨大な dt が入るのを防ぐ

  game.update(dt);

  background(135, 206, 235);
  view.apply(game);
  view.drawWorld(game);
  view.computeMiniGaugePos(game);   // HUD がカメラを戻す前に投影しておく
  hud.draw(game);
}

void keyPressed() {
  if (game.state == STATE_READY) {
    if (key == ENTER || key == RETURN) game.reset();
    return;
  }
  if (game.state == STATE_FERRY) {
    if (key == ENTER || key == RETURN) game.leaveFerry();
    if (key == 'r' || key == 'R') game.reset();
    return;
  }
  if (keyCode == LEFT || key == 'a' || key == 'A') {
    game.moveLeft();
  } else if (keyCode == RIGHT || key == 'd' || key == 'D') {
    game.moveRight();
  } else if (key == ' ') {
    game.tryShot();
  } else if (key == 'z' || key == 'Z') {
    game.tryZone();
  } else if (key == 'r' || key == 'R') {
    game.reset();
  }
}

void mousePressed() {
  if (game.state == STATE_READY) game.reset();
  else if (game.state == STATE_FERRY) game.leaveFerry();
}
