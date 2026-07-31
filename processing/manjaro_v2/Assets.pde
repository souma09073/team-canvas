// ============================================================
// 画像の読み込み。
//
// 【安全装置】画像が無ければ null のままにして、描画側は球と箱で描く。
// そのため、素材が1つ揃うたびにその部分だけ絵に差し替えられる。
// 途中で力尽きても、絵の無い部分は今までどおり動く。
//
// 画像は processing/manjaro/data/images/ に、下の名前で置く。
//   player.png … 主人公(後ろ姿・透過PNG)
//   food.png   … 食べ物(あとで)
//   woman.png  … 女性キャラ(全身・足先まで)(あとで)
//   sky.png    … 背景(あとで)
// ============================================================

class Assets {
  PImage player;
  PImage food;
  PImage woman;
  PImage sky;
  PImage title;
  PImage energy;

  void load() {
    player = tryLoad("images/player.png");
    food   = tryLoad("images/food.png");
    woman  = tryLoad("images/woman.png");
    sky    = tryLoad("images/sky.png");
    title  = tryLoad("images/title.png");
    energy = tryLoad("images/energy.png");
    if (energy == null) energy = tryLoad(dataPath("images/energy.png"));
  }

  // 読めなければ null を返す。エラーで止めない。
  // Processing の loadImage() は、ファイルが無いとコンソールに警告を出して null を返す。
  PImage tryLoad(String path) {
    PImage img = loadImage(path);
    if (img == null) {
      println("画像なし: " + path + "(この部分は仮の図形で描きます)");
    } else {
      println("画像あり: " + path + "  " + img.width + "x" + img.height);
    }
    return img;
  }
}
