// ============================================================
// 走っていないとき(タイトル・ゲームオーバー・ゴール)に出す全画面表示。
//
// ゴール画面の最後の一文が、このゲームの目的そのもの。
// タイムを競わせたうえで「何のために使ったのか」を問い返す構成にしている。
// ============================================================

class Screens {

  void draw(Game g) {
    if (g.state == STATE_RUNNING) return;
    textAlign(CENTER, CENTER);

    // カウントダウンだけは画面を覆わない。
    // これから来る食べ物や岩が見えていないと、構える意味が無いため。
    if (g.state == STATE_COUNTDOWN) { drawCountdown(g); return; }

    // 「倒れた」画面は無い。血糖が振り切れても止まるだけで、そのまま続く。
    if      (g.state == STATE_TITLE) { drawTitle(); }
    else if (g.state == STATE_READY) { dim(); drawReady(); }
    else if (g.state == STATE_FERRY) { drawFerry(g); }        // 海の背景で覆うので dim は不要
    else if (g.state == STATE_GOAL)  { dim(); drawGoal(g); }
  }

  // 3Dの世界を暗く沈めて、文字を読みやすくする
  void dim() {
    fill(0, 170);
    rect(0, 0, SCREEN_W, SCREEN_H);
  }

  void drawTitle(){

    image(assets.title,0,0,SCREEN_W,SCREEN_H);

  }

  void drawReady() {
    setText(fontBig, 34);
    fill(255);
    text("マンジャロ日本縦断", SCREEN_W * 0.5, 200);

    setText(fontSmall, 16);
    fill(255, 230);
    text("←→ / A・D:レーン移動　スペース:マンジャロ　Z:ゾーン　R:リトライ", SCREEN_W * 0.5, 280);
    // ルールの数値は CONFIG から組み立てる。数値を変えたとき説明文が古いまま残らないように。
    text("血糖値を " + int(STABLE_MIN) + "〜" + int(STABLE_MAX) + "(緑)に保て。"
       + "0で低血糖、" + int(HYPER_THRESHOLD) + "超で高血糖。どちらも倒れる。", SCREEN_W * 0.5, 320);
    text("スペースでマンジャロを打つと、" + int(SHOT_EFFECT_SEC) + "秒間 食べても血糖が上がらない。"
       + "ただし週1回の薬なので、エリアごとに1回しか打てない。", SCREEN_W * 0.5, 356);
    text("緑をキープするとゾーンが溜まり、Zキーで超加速。"
       + "終盤には消さないと抜けられない壁がある。", SCREEN_W * 0.5, 392);

    setText(fontBig, 20);
    fill(C_ACCENT);
    text("Enter または クリックでスタート", SCREEN_W * 0.5, 470);

    setText(fontSmall, 13);
    fill(255, 150);
    text("ESC キーで終了", SCREEN_W * 0.5, 520);
  }

  // ============================================================
  // フェリー
  //
  // 企画書の「ステージ間はフェリー移動」をそのまま使っている。
  // 3回あるうち、真ん中の1回だけ止まって途中経過を見せる。
  // 全部止めるとテンポが悪く、全部流すと休む間が無いため。
  // ============================================================
  void drawFerry(Game g) {
    Region done = regions[g.ferryFromRegion];
    Region next = regions[g.regionIndex];

    drawSea();
    drawFerryRoute(g, done, next);

    if (g.ferryIsRest()) drawFerryRest(g);      // 中間地点。止まって成績を見せる
    else                 drawFerryAuto(g);      // 自動で流れる回
  }

  // 海。フェリーで渡っていることを背景で示す。
  void drawSea() {
    fill(18, 52, 84);
    rect(0, 0, SCREEN_W, SCREEN_H);

    // 波。ゆっくり流れて、移動している感じを出す
    fill(255, 22);
    for (int i = 0; i < 7; i++) {
      float y = 300 + i * 55;
      float offset = (millis() * 0.03 + i * 90) % (SCREEN_W + 300) - 150;
      rect(offset, y, 180, 5, 3);
      rect(offset - 420, y, 120, 5, 3);
    }
  }

  // 「どの港から、どの港へ」を線と船で示す。
  // 地名ではなく港の名前を大きく出す。走っていたのは陸で、いま渡っているのは海だと
  // はっきりさせるため。
  void drawFerryRoute(Game g, Region done, Region next) {
    float y = 210;
    float x1 = SCREEN_W * 0.5 - 300, x2 = SCREEN_W * 0.5 + 300;

    setText(fontMid, 24);
    textAlign(CENTER, CENTER);
    fill(255, 200);
    text(done.goalPort, x1, y - 58);
    fill(255);
    text(next.startPort, x2, y - 58);

    // その港がどのエリアのものかを、小さく添える
    setText(fontSmall, 14);
    fill(255, 150);
    text(done.name, x1, y - 32);
    text(next.name, x2, y - 32);

    // 航路
    stroke(255, 70);
    strokeWeight(2);
    line(x1, y, x2, y);
    noStroke();

    // 船。フェリーの残り時間に合わせて左から右へ進む。
    // 中間地点(止まる回)では真ん中に留めておく。
    float t = g.ferryIsRest() ? 0.5 : 1 - constrain(g.ferryTimer / FERRY_SEC, 0, 1);
    float bx = lerp(x1, x2, t);

    fill(C_ACCENT);
    pushMatrix();
    translate(bx, y - 14);
    triangle(-22, 10, 22, 10, 0, -14);   // 船体
    rect(-3, -30, 6, 18);                // マスト
    popMatrix();
  }

  // 自動で流れる回。文字だけ出して、あとは待たせる。
  void drawFerryAuto(Game g) {
    setText(fontBig, 30);
    textAlign(CENTER, CENTER);
    fill(255);
    text("⛴  フェリーで移動中", SCREEN_W * 0.5, 400);

    // 残り時間のバー。あとどれくらいで走り出すか分かるように
    float w = 320, h = 6;
    float x = SCREEN_W * 0.5 - w * 0.5, y = 460;
    fill(255, 50);
    rect(x, y, w, h, 3);
    fill(C_ACCENT);
    rect(x, y, w * (1 - constrain(g.ferryTimer / FERRY_SEC, 0, 1)), h, 3);
  }

  // 中間地点。ここだけ止まって、そこまでの経過を見せる。
  void drawFerryRest(Game g) {
    setText(fontBig, 26);
    textAlign(CENTER, CENTER);
    fill(C_ACCENT);
    text("中間地点", SCREEN_W * 0.5, 330);

    setText(fontBig, 40);
    fill(255);
    text(nf(g.stageTime(), 1, 2) + " 秒", SCREEN_W * 0.5, 390);

    setText(fontSmall, 16);
    fill(255, 220);
    text("食べた " + g.stageFoodCount + " 回"
       + "　　マンジャロ " + (g.shotUsedInRegion[g.ferryFromRegion] ? "使用した" : "使わなかった"),
       SCREEN_W * 0.5, 440);

    drawArrivalGlucose(g);

    setText(fontBig, 22);
    fill(C_ACCENT);
    text("Enter で出港", SCREEN_W * 0.5, 590);
  }

  // 到着時の血糖が安定域に入っていたか。
  // 「血糖を安定させ続けること」が医師との約束なので、そこを都度突きつける。
  void drawArrivalGlucose(Game g) {
    boolean stable = (g.glucose >= STABLE_MIN && g.glucose <= STABLE_MAX);

    setText(fontMid, 19);
    fill(stable ? C_GLU_STABLE : C_GLU_HIGH);
    text(stable ? "到着時の血糖 " + int(g.glucose) + " … 安定域を保てた"
                : "到着時の血糖 " + int(g.glucose) + " … 安定域を外れている",
         SCREEN_W * 0.5, 495);
  }

  // ============================================================
  // カウントダウン
  //
  // 3Dの世界は見えたまま止まっているので、これから来る食べ物や岩を見て構えられる。
  // 全画面を覆わず、数字だけを重ねているのはそのため。
  // ============================================================
  void drawCountdown(Game g) {
    int n = ceil(g.countdownTimer);
    if (n <= 0) return;

    // 数字が切り替わるたびに大きく出て縮む。残り時間から進み具合を出す。
    float within = 1 - (g.countdownTimer - floor(g.countdownTimer));   // 0→1
    float scale = 1.6 - 0.6 * within;
    float fade = 255 * (1 - within * 0.35);

    textAlign(CENTER, CENTER);
    setText(fontBig, 90 * scale);
    fill(0, 120);
    text(n + "", SCREEN_W * 0.5 + 4, SCREEN_H * 0.42 + 4);   // 影。背景に紛れないように
    fill(C_ACCENT, fade);
    text(n + "", SCREEN_W * 0.5, SCREEN_H * 0.42);

    setText(fontMid, 20);
    fill(255, 220);
    text(regions[g.regionIndex].name, SCREEN_W * 0.5, SCREEN_H * 0.56);
  }

  void drawGoal(Game g) {
    setText(fontBig, 34);
    fill(C_ACCENT);
    text("日本縦断 達成", SCREEN_W * 0.5, 120);

    setText(fontBig, 46);
    fill(255);
    text(nf(g.elapsed, 1, 2) + " 秒", SCREEN_W * 0.5, 180);

    if (g.newRecord) {
      setText(fontBig, 22);
      fill(255, 230, 90);
      text("ハイスコア更新!", SCREEN_W * 0.5, 228);
    }

    drawStats(g);
    drawClosing(g);

    setText(fontSmall, 14);
    fill(255, 170);
    text("R キーでもう一度", SCREEN_W * 0.5, 640);
  }

  void drawStats(Game g) {
    int weeks = (g.shotUsedInRegion == null) ? 0 : g.shotUsedInRegion.length;

    setText(fontSmall, 15);
    fill(255, 230);
    text("マンジャロ " + g.shotCount + " / " + weeks + " 回"
       + "　　倒れた " + g.collapseCount + " 回"
       + "　　岩 " + g.rockHitCount + " 回"
       + "　　ゾーン " + nf(g.zoneTotal, 1, 1) + " 秒", SCREEN_W * 0.5, 285);
  }

  // ---- このゲームの主題 ----
  // タイムを競わせた直後に問い返すことで効かせている。
  // 返ってくる言葉は、プレイヤーが薬を何回使ったかで変わる。
  // 説教にせず、事実を差し出して考えさせるのが狙い。
  void drawClosing(Game g) {
    // 区切り線。ここから先が問いかけであることを、見た目で分ける
    stroke(255, 60);
    strokeWeight(1);
    line(SCREEN_W * 0.5 - 240, 340, SCREEN_W * 0.5 + 240, 340);
    noStroke();

    setText(fontMid, 20);
    fill(255, 230);
    text("あなたはこの薬を、何のために使いましたか。", SCREEN_W * 0.5, 400);

    setText(fontBig, 26);
    fill(C_ACCENT);
    text(closingLine(g), SCREEN_W * 0.5, 480);

    stroke(255, 60);
    line(SCREEN_W * 0.5 - 240, 545, SCREEN_W * 0.5 + 240, 545);
    noStroke();
  }

  // 使った回数で結びが変わる。
  // 割合で判定しているので、エリアの数を変えてもそのまま動く。
  String closingLine(Game g) {
    int weeks = (g.shotUsedInRegion == null) ? 4 : g.shotUsedInRegion.length;
    int used = g.shotCount;

    if (used == 0)              return "あなたは、最後まで自分の足で走りきった。";
    if (used <= weeks / 2)      return "必要なときだけ、頼った。";
    if (used < weeks)           return "気づけば、手が伸びていた。";
    return "速く走るために、何を差し出しましたか。";
  }
}
