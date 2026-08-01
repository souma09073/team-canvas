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

import processing.sound.*;

SoundFile soundPlayMusic1, soundPlayMusic2, soundPlayMusic3,soundPlayMusic4, soundPlayMusic5, soundRunning, soundBoost, soundRetry, soundGameOver, soundClear, soundScreenTransition, soundMovingSea, soundGetManjaro, soundHealthMax, soundEat1, soundEat2, soundeat3 ,soundgoal;

Game game;
View3D view;
Hud hud;
Assets assets;

String currentBgMusic = "";
boolean footstepsPlaying = false;
boolean seaPlaying = false;

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

  soundPlayMusic1= new SoundFile(this, "sounds/afternoon.mp3");//おしゃれな曲　タイトルの曲によさそう
  soundPlayMusic2 = new SoundFile(this, "sounds/glory60s.mp3");//平和最初　初めのほうのステージ沖縄とか
  soundPlayMusic3 = new SoundFile(this, "sounds/last-war.mp3");//ボスっぽい　最後のほうのステージ北海道とか
  soundPlayMusic4 = new SoundFile(this, "sounds/arabianjewel.mp3");//アラビアンな曲　西日本によさそう
  soundPlayMusic5 = new SoundFile(this, "sounds/valley.mp3");//ボス戦に近そうな曲第一形態みたいな　東日本によさそう　
  soundGetManjaro = new SoundFile(this, "sounds/決定ボタンを押す49.mp3");//マンジャロ使用音
  soundGameOver = new SoundFile(this, "sounds/チーン1.mp3");//ゲームオーバー音源
  soundEat1 = new SoundFile(this, "sounds/リンゴをかじる.mp3");//食べ物食べる音1
  soundEat2 = new SoundFile(this, "sounds/お菓子を食べる1.mp3");//食べ物食べる音2
  soundHealthMax = new SoundFile(this, "sounds/ゲージ回復2.mp3");//マンジャロ使用可能になったとき　あるいは何かのゲージがたまったとき
  soundClear = new SoundFile(this, "sounds/成功音.mp3");//チェックポイント到達音
  soundMovingSea = new SoundFile(this, "sounds/海岸1.mp3");// 船の移動
  soundScreenTransition = new SoundFile(this, "sounds/土の上を走る.mp3");//画面切り替えの、走るような音
  soundRunning = new SoundFile(this, "sounds/アスファルトの上を走る1.mp3");//人が走る音
  soundBoost = new SoundFile(this, "sounds/超高速ダッシュ.mp3");//加速する
  soundRetry = new SoundFile(this, "sounds/決定ボタンを押す33.mp3");//リトライ音
  soundeat3 = new SoundFile(this, "sounds/スイッチ（ピロリーン）.mp3");//食べる音
  soundgoal= new SoundFile(this, "sounds/ゲームクリア(壮大).mp3");//ゲームクリア音

  float masterVol = 0.25;
  soundPlayMusic1.amp(masterVol);
  soundPlayMusic2.amp(masterVol);
  soundPlayMusic3.amp(masterVol);
  soundPlayMusic4.amp(masterVol);
  soundPlayMusic5.amp(masterVol);
  soundRunning.amp(masterVol);
  soundBoost.amp(masterVol);
  soundRetry.amp(masterVol);
  soundGameOver.amp(masterVol);
  soundClear.amp(masterVol);
  soundMovingSea.amp(masterVol);
  soundGetManjaro.amp(masterVol);
  soundHealthMax.amp(masterVol);
  soundEat1.amp(masterVol);
  soundEat2.amp(masterVol);
  soundeat3.amp(masterVol);
  soundgoal.amp(masterVol);
  soundScreenTransition.amp(masterVol);

}

int lastMillis = 0;
int lastW = 0, lastH = 0;   // ウィンドウの大きさ。変わったら表示倍率を計算し直す

void updateAudioPlayback() {
  if (game == null) return;

  if (game.state == STATE_TITLE) {
    setBackgroundMusic("title");
    stopFootsteps();
    stopSeaSound();
    return;
  }

  if (game.state == STATE_FERRY) {
    stopBackgroundMusic();
    startSeaSound();
    stopFootsteps();
    return;
  }

  if (game.state == STATE_GAME_OVER || game.state == STATE_GOAL) {
    stopBackgroundMusic();
    stopSeaSound();
    stopFootsteps();
    return;
  }

  if (game.state == STATE_COUNTDOWN || game.state == STATE_RUNNING) {
    setBackgroundMusic(regionMusicName(game.regionIndex));
    if (game.state == STATE_RUNNING && !game.isStopped()) {
      startFootsteps();
    } else {
      stopFootsteps();
    }
    stopSeaSound();
    return;
  }

  stopBackgroundMusic();
  stopSeaSound();
  stopFootsteps();
}

void setBackgroundMusic(String name) {
  if (name == null || name.equals(currentBgMusic)) return;
  stopBackgroundMusic();
  currentBgMusic = name;

  if (name.equals("title")) {
    soundPlayMusic1.loop();
  } else if (name.equals("region1")) {
    soundPlayMusic2.loop();
  } else if (name.equals("region2")) {
    soundPlayMusic4.loop();
  } else if (name.equals("region3")) {
    soundPlayMusic5.loop();
  } else if (name.equals("region4")) {
    soundPlayMusic3.loop();
  }
}

String regionMusicName(int regionIndex) {
  switch(regionIndex) {
    case 0: return "region1";
    case 1: return "region2";
    case 2: return "region3";
    case 3: return "region4";
    default: return "region1";
  }
}

void stopBackgroundMusic() {
  if (currentBgMusic.equals("title")) soundPlayMusic1.stop();
  else if (currentBgMusic.equals("region1")) soundPlayMusic2.stop();
  else if (currentBgMusic.equals("region2")) soundPlayMusic4.stop();
  else if (currentBgMusic.equals("region3")) soundPlayMusic5.stop();
  else if (currentBgMusic.equals("region4")) soundPlayMusic3.stop();
  currentBgMusic = "";
}

void startFootsteps() {
  if (footstepsPlaying) return;
  soundRunning.loop();
  footstepsPlaying = true;
}

void stopFootsteps() {
  if (!footstepsPlaying) return;
  soundRunning.stop();
  footstepsPlaying = false;
}

void startSeaSound() {
  if (seaPlaying) return;
  soundMovingSea.loop();
  seaPlaying = true;
}

void stopSeaSound() {
  if (!seaPlaying) return;
  soundMovingSea.stop();
  seaPlaying = false;
}

void playOneShot(SoundFile s) {
  if (s != null) s.play();
}

void playFoodSound() {
  playOneShot(soundeat3);
}

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
  updateAudioPlayback();

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
    // 動作確認用。1〜4 でそのステージから始める(Config の DEBUG_STAGE_SELECT で切る)
    if (DEBUG_STAGE_SELECT && key >= '1' && key <= '4') game.startAtRegion(key - '1');
    return;
  }

  if (game.state == STATE_GAME_OVER) {
    if (key == 'r' || key == 'R') game.restartFromCheckpoint();
    return;
  }

  // フェリーは、中間地点の回だけ Enter を待つ。
  // 自動で流れる回は入力を受けない(押しても飛ばせない)。
  if (game.state == STATE_FERRY) {
    if ((key == ENTER || key == RETURN) && game.ferryIsRest()) game.leaveFerry();
    if (key == 'r' || key == 'R') game.restartFromCheckpoint();
    return;
  }

  // カウントダウン中はレーンだけ動かせる。構える時間なので。
  if (game.state == STATE_COUNTDOWN) {
    if (key == 'r' || key == 'R') game.restartFromCheckpoint();
    return;
  }
  if (keyCode == LEFT || key == 'a' || key == 'A') {
    game.moveLeft();
  } else if (keyCode == RIGHT || key == 'd' || key == 'D') {
    game.moveRight();
  } else if (key == ' ') {
    game.tryShot();
  } else if (key == 'z' || key == 'Z') {
    game.trySpeedItem();
  } else if (key == 'r' || key == 'R') {
    game.restartFromCheckpoint();
  }
}

void mousePressed() {
  if (game.state == STATE_READY) game.reset();
  else if (game.state == STATE_FERRY && game.ferryIsRest()) game.leaveFerry();
}
