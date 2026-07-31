// ============================================================
// マンジャロ日本縦断ゲーム(新版)
//
// 沖縄から北海道まで、4つのエリアを走り抜ける。
// 各エリアのゴールは港。そこに停泊している船で次の土地へ渡る。
//
//   タイトル → カウントダウン → 沖縄(→ 那覇港)→ 船 → カウントダウン
//   → 本州西(→ 大阪港)→ 中間地点 → カウントダウン
//   → 本州東(→ 仙台港)→ 船 → カウントダウン → 北海道 → ゴール
//
// エリアとエリアの間は海で隔てられていて、そこは走らない(Regions.pde の REGION_GAP)。
// だから港に立っても次のエリアは見えない。「別の土地へ渡った」ことが絵で伝わる。
//
// 見た目はまだプリミティブ(球と箱)が中心。画像は置けば自動で差し替わる。
//
//   Config.pde  … 調整する数値。全部ここ
//   Regions.pde … エリアの定義(速度・長さ・色)
//   Course.pde  … コース生成(シード固定)
//   Game.pde    … ゲームのルール。描画には触れない
//   View3D.pde  … 3D描画
//   Hud.pde     … 走行中の画面表示
//   Screens.pde … タイトル / フェリー / カウントダウン / ゴール
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

  // 生成されたコースの中身。数値を振ったあと、意図どおりになっているか確認する用。
  println("--- コース ---");
  println("食べ物 " + game.course.foods.size() + " 個"
        + " / 岩 " + game.course.rocks.size() + " 個"
        + " / 女性 " + game.course.women.size() + " 体");
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
  if (game.state == STATE_TITLE) {
    if (key == ENTER || key == RETURN) game.state = STATE_READY;
    return;
  }

  if (game.state == STATE_READY) {
    if (key == ENTER || key == RETURN) game.reset();
    return;
  }
  // フェリーは、中間地点の回だけ Enter を待つ。
  // 自動で流れる回は入力を受けない(押しても飛ばせない)。
  if (game.state == STATE_FERRY) {
    if ((key == ENTER || key == RETURN) && game.ferryIsRest()) game.leaveFerry();
    if (key == 'r' || key == 'R') game.reset();
    return;
  }

  // カウントダウン中はレーンだけ動かせる。構える時間なので。
  if (game.state == STATE_COUNTDOWN) {
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
  else if (game.state == STATE_FERRY && game.ferryIsRest()) game.leaveFerry();
}
