// ============================================================
// 走っていないとき(タイトル・ゲームオーバー・ゴール)に出す全画面表示。
//
// ゴール画面の最後の一文が、このゲームの目的そのもの。
// タイムを競わせたうえで「何のために使ったのか」を問い返す構成にしている。
// ============================================================

class Screens {

  void draw(Game g) {
    if (g.state == STATE_RUNNING) return;

    fill(0, 170);
    rect(0, 0, SCREEN_W, SCREEN_H);
    textAlign(CENTER, CENTER);

    // 「倒れた」画面は無い。血糖が振り切れても減速するだけで、走り続ける。
    if      (g.state == STATE_READY) drawTitle();
    else if (g.state == STATE_FERRY) drawFerry(g);
    else if (g.state == STATE_GOAL)  drawGoal(g);
  }

  void drawTitle() {
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

  // ---- フェリー ----
  // エリアの区切りで手を止める休憩画面。
  // 企画書の「ステージ間はフェリー移動」をそのまま使っている。
  // ここで一度緊張を切らないと、走りっぱなしで疲れる(先生の指摘)。
  void drawFerry(Game g) {
    Region done = regions[g.ferryFromRegion];
    Region next = regions[g.regionIndex];

    setText(fontBig, 30);
    fill(C_ACCENT);
    text("⛴  " + done.name + " を走り終えた", SCREEN_W * 0.5, 150);

    // そのエリアの成績
    setText(fontBig, 40);
    fill(255);
    text(nf(g.stageTime(), 1, 2) + " 秒", SCREEN_W * 0.5, 225);

    setText(fontSmall, 16);
    fill(255, 220);
    text("食べた " + g.stageFoodCount + " 回"
       + "　　マンジャロ " + (g.shotUsedInRegion[g.ferryFromRegion] ? "使用した" : "使わなかった"),
       SCREEN_W * 0.5, 285);

    // 到着時の血糖。医師との約束を守れているかが分かる
    drawArrivalGlucose(g);

    // 次の土地
    stroke(255, 60);
    strokeWeight(1);
    line(SCREEN_W * 0.5 - 220, 430, SCREEN_W * 0.5 + 220, 430);
    noStroke();

    setText(fontMid, 22);
    fill(255, 230);
    text("次は  " + next.name, SCREEN_W * 0.5, 480);

    setText(fontSmall, 14);
    fill(255, 180);
    text("マンジャロは新しい週の分が使える", SCREEN_W * 0.5, 520);

    setText(fontBig, 22);
    fill(C_ACCENT);
    text("Enter で出港", SCREEN_W * 0.5, 590);
  }

  // 到着時の血糖が安定域に入っていたか。
  // 「血糖を安定させ続けること」が医師との約束なので、そこを都度突きつける。
  void drawArrivalGlucose(Game g) {
    boolean stable = (g.glucose >= STABLE_MIN && g.glucose <= STABLE_MAX);

    setText(fontMid, 20);
    fill(stable ? C_GLU_STABLE : C_GLU_HIGH);
    text(stable ? "到着時の血糖 " + int(g.glucose) + " … 安定域を保てた"
                : "到着時の血糖 " + int(g.glucose) + " … 安定域を外れている",
         SCREEN_W * 0.5, 350);
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
