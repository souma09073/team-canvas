// ============================================================
// 文字まわり。
//
// Processing の標準フォントは日本語を表示できない(□ になる)。
// さらに、入っているフォント名はPCごとに違う。そこで候補を上から順に試し、
// 実際に入っているものを1つ選んで使う。
//
// 大きさごとに PFont を作り分けているのは、1つを拡大縮小すると小さい字が滲むため。
// ============================================================

PFont fontBig;     // 見出し・タイム
PFont fontMid;     // パネルの見出し
PFont fontSmall;   // 説明文

// 見つかったフォント名。見つからなければ null。
String usedFontName = null;

void loadFonts() {
  String[] candidates = {
    "Meiryo UI", "Meiryo", "Yu Gothic UI", "Yu Gothic", "MS Gothic", "MS PGothic"
  };
  String[] installed = PFont.list();

  for (String want : candidates) {
    for (String have : installed) {
      if (have.equalsIgnoreCase(want)) { usedFontName = want; break; }
    }
    if (usedFontName != null) break;
  }

  if (usedFontName == null) {
    println("!! 日本語フォントが見つかりません。文字が □ になります。");
    println("   candidates に、このPCに入っているフォント名を足してください。");
    return;
  }

  println("使用フォント: " + usedFontName);

  // 実際に使う文字サイズより大きめに作る。
  // 20px で作った fontMid で「マンジャロ」の「ロ」だけが □ になる現象が出たため。
  // 小さいサイズで作ると一部の字が作られないことがあるので、余裕を持たせている。
  // 表示サイズは setText() の第2引数で決まるので、ここを変えてもレイアウトは変わらない。
  fontBig   = createFont(usedFontName, 48);
  fontMid   = createFont(usedFontName, 32);
  fontSmall = createFont(usedFontName, 24);
}

// フォントと文字サイズをまとめて指定する。
// フォントが読めなかったPCでも落ちないよう、null を確認してから渡している。
// (これが無いと、描画のたびに同じ2行を書くことになる)
void setText(PFont f, float size) {
  if (f != null) textFont(f);
  textSize(size);
}
