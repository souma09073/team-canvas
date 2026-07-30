// ============================================================
// Phase 0: 環境確認スケッチ
//
// 本体の移植に入る前に、この環境で以下3点が動くことを確かめる。
//   ① P3D(3D描画)が動くか
//   ② 日本語フォントが表示できるか
//   ③ 3Dの手前に2D(HUD)を重ねられるか
//
// ここで通ったフォント名と HUD の重ね方は、そのまま Phase 3 で使う。
// 捨てるコードではない。
// ============================================================

PFont jpFont;
String usedFontName = "(見つからなかった)";
float angle = 0;

// 日本語が出るフォントの候補。上から順に試し、実際に入っているものを使う。
String[] FONT_CANDIDATES = {
  "Meiryo", "Meiryo UI", "Yu Gothic", "Yu Gothic UI",
  "MS Gothic", "MS PGothic", "Noto Sans JP", "Hiragino Sans"
};

void setup() {
  size(800, 600, P3D);

  println("---- 環境確認 ----");
  println("Java  : " + System.getProperty("java.version"));
  println("OS    : " + System.getProperty("os.name"));
  println("描画系 : " + g.getClass().getName());   // processing.opengl.PGraphics3D と出れば P3D が有効

  // --- 確認②の準備: 日本語フォント ---
  // createFont() は存在しない名前を渡しても黙って代替フォントに落ちる。
  // そのため先に PFont.list() に含まれているかを調べてから作る。
  String[] installed = PFont.list();
  for (String cand : FONT_CANDIDATES) {
    if (hasFont(installed, cand)) {
      jpFont = createFont(cand, 24);
      usedFontName = cand;
      break;
    }
  }

  if (jpFont == null) {
    println("!! 候補のフォントが1つも見つからなかった。");
    println("   下の一覧から日本語フォントを探し、FONT_CANDIDATES に足して再実行すること:");
    printArray(installed);
  } else {
    println("使用フォント: " + usedFontName);
  }
  println("------------------");
}

boolean hasFont(String[] list, String name) {
  for (String s : list) {
    if (s.equalsIgnoreCase(name)) return true;
  }
  return false;
}

void draw() {
  background(30, 34, 44);

  // ---------- 確認①: P3D ----------
  // 箱を奥、球を手前に置く。箱が球に隠れていれば深度テストも効いている。
  lights();
  pushMatrix();
  translate(width / 2, height / 2 - 30, 0);
  rotateY(angle);

  pushMatrix();
  translate(70, 0, -60);
  fill(220, 90, 70);
  box(90);
  popMatrix();

  fill(90, 190, 130);
  sphere(60);
  popMatrix();

  angle += 0.01;

  // ---------- 確認③: 3Dの手前に2Dを描く ----------
  drawHUD();
}

void drawHUD() {
  hint(DISABLE_DEPTH_TEST);  // 奥行き判定を切る = 3Dの手前に必ず描かれる
  camera();                  // カメラを既定に戻す(以降は画面のピクセル座標で描ける)
  perspective();             // 投影も既定に戻す(本体では FOV を動かすので作法として入れておく)
  noLights();                // 3Dのライトが2Dの色に混ざらないよう切る

  noStroke();
  fill(0, 150);
  rect(20, 20, 300, 82, 8);

  // 血糖ゲージの3色ゾーン。
  // CSSのグラデーションでやっていたことは、矩形を並べるだけで済む(むしろ簡単)。
  float bx = 32, by = 58, bw = 276, bh = 18;
  fill(200,  60,  60);  rect(bx,              by, bw * 0.15, bh);  // 危険域
  fill(210, 190,  60);  rect(bx + bw * 0.15,  by, bw * 0.25, bh);  // 中間
  fill( 70, 200, 120);  rect(bx + bw * 0.40,  by, bw * 0.20, bh);  // 安定域
  fill(210, 190,  60);  rect(bx + bw * 0.60,  by, bw * 0.25, bh);
  fill(200,  60,  60);  rect(bx + bw * 0.85,  by, bw * 0.15, bh);
  fill(255);            rect(bx + bw * 0.5 - 2, by - 3, 4, bh + 6);  // 針

  // ---------- 確認②: 日本語 ----------
  if (jpFont != null) textFont(jpFont);
  textAlign(LEFT, TOP);
  fill(255);
  textSize(19);
  text("血糖値 50 — 日本語が読めれば OK", 32, 28);
  textSize(13);
  text("フォント: " + usedFontName, 32, 82);

  // 画面上のチェックリスト
  fill(255, 220);
  textSize(13);
  text("① 球と箱が立体に見え、箱が球の奥に隠れているか", 20, height - 82);
  text("② 上の日本語が □(豆腐)になっていないか", 20, height - 60);
  text("③ このHUDが常に3Dモデルの手前に見えているか", 20, height - 38);

  hint(ENABLE_DEPTH_TEST);   // 戻し忘れると次フレームの3Dが壊れる
}
