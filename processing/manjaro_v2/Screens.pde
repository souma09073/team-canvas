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
    text("スペースで目の前の食べ物を消せる。ただし次に打てるまで "
       + int(SHOT_COOLDOWN) + " 秒(=1週間)かかる。", SCREEN_W * 0.5, 356);
    text("緑をキープするとゾーンが溜まり、Zキーで超加速。"
       + "終盤には消さないと抜けられない壁がある。", SCREEN_W * 0.5, 392);

    setText(fontBig, 20);
    fill(C_ACCENT);
    text("Enter または クリックでスタート", SCREEN_W * 0.5, 470);

    setText(fontSmall, 13);
    fill(255, 150);
    text("ESC キーで終了", SCREEN_W * 0.5, 520);
  }

  void drawGoal(Game g) {
    setText(fontBig, 36);
    fill(255, 204, 0);
    text("GOAL!", SCREEN_W * 0.5, 190);
    text(nf(g.elapsed, 1, 2) + " 秒", SCREEN_W * 0.5, 250);

    if (g.newRecord) {
      setText(fontBig, 24);
      fill(255, 230, 90);
      text("ハイスコア更新!", SCREEN_W * 0.5, 305);
    }

    setText(fontSmall, 15);
    fill(255);
    text("マンジャロ " + g.shotCount + " 回"
       + "　倒れた " + g.collapseCount + " 回"
       + "　奪われ " + g.robbedCount + " 回"
       + "　ゾーン合計 " + nf(g.zoneTotal, 1, 1) + " 秒", SCREEN_W * 0.5, 360);

    // このゲームの主題。タイムを競った直後に問い返すことで効かせている。
    textSize(17);
    fill(255, 220);
    text("あなたはこの薬を、何のために使いましたか。", SCREEN_W * 0.5, 410);

    textSize(15);
    fill(255, 200);
    text("R キーでリトライ", SCREEN_W * 0.5, 460);
  }
}
