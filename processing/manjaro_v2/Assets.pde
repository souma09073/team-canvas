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
  PImage fens;
  PImage foodSatar;
  PImage foodTako;
  PImage foodOkonomi;
  PImage foodTendon;
  PImage foodMonja;
  PImage foodKiri;
  PImage foodIce;
  PImage foodIkura;
  PImage foodZin;

  // ---- UI の画像 ----
  // 読めなければ null のまま。描画側が今までの図形・文字表示に戻る。
  PImage btnStart;      // 「Enterキーでスタート」のボタン
  PImage gaugeVert;     // 主人公の横に出る縦の血糖ゲージ
  PImage ferrySide;     // フェリー画面の船(横から見た図)
  PImage manjaroPen;    // マンジャロの注射ペン

  void loadUI() {
    btnStart   = tryLoad("images/generated/button_enter_start.png");
    gaugeVert  = tryLoad("images/generated/glucose_gauge_vertical.png");
    ferrySide  = tryLoad("images/generated/ferry_side.png");
    manjaroPen = tryLoad("images/generated/mounjaro_pen.png");
  }

  // ---- 道の脇の景色(Roadside.pde が使う)----
  // エリア名 + 種類 で引く。例: roadside("okinawa", "tree")
  // 読めなければ null。景色が出ないだけで、ゲームは動く。
  HashMap<String, PImage> roadsideImages = new HashMap<String, PImage>();

  // ---- エリアごとの背景(Sky.pde が使う)----
  // 添字はエリアの番号。読めなければ null で、空は単色のままになる。
  PImage[] skies;

  void loadSkies() {
    skies = new PImage[regions.length];
    for (int i = 0; i < regions.length; i++) {
      if (regions[i].skyImage == null) continue;
      skies[i] = tryLoad("images/generated/" + regions[i].skyImage);
    }
  }

  void loadRoadside() {
    if (!USE_ROADSIDE) return;   // 使わない設定なら読み込まない
    // Regions.pde で .area(...) を書いたエリアだけ読む。
    // 全エリアぶん先に読むと、使わない画像でメモリを食うため。
    for (Region r : regions) {
      if (r.areaKey == null) continue;
      loadRoadsideSet(r.areaKey);
    }
  }

  void loadRoadsideSet(String area) {
    String[] kinds = { "bld_a", "bld_b", "tree", "post" };
    // ファイル名は bld_okinawa_a.png / tree_okinawa.png のように種類と位置が違う
    String[] files = { "bld_" + area + "_a", "bld_" + area + "_b",
                       "tree_" + area,       "post_" + area };

    for (int i = 0; i < kinds.length; i++) {
      roadsideImages.put(area + "/" + kinds[i],
                         tryLoad("images/generated/" + files[i] + ".png"));
    }
  }

  PImage roadside(String area, String kind) {
    return roadsideImages.get(area + "/" + kind);
  }

  void load() {
    loadUI();
    loadSkies();
    loadRoadside();
    player = tryLoad("images/player.png");
    food   = tryLoad("images/food.png");
    woman  = tryLoad("images/woman.png");
    sky    = tryLoad("images/sky.png");
    title  = tryLoad("images/title.png");
    energy = tryLoad("images/energy.png");
    if (energy == null) energy = tryLoad(dataPath("images/energy.png"));

    fens = tryLoad("images/fens.png");

    foodSatar = tryLoad("images/foodSatar.png");
    foodTako = tryLoad("images/foodTako.png");
    foodOkonomi = tryLoad("images/foodOkonomi.png");
    foodTendon = tryLoad("images/foodTendon.png");
    foodMonja = tryLoad("images/foodMonja.png");
    foodKiri = tryLoad("images/foodKiri.png");
    foodIce = tryLoad("images/foodIce.png");
    foodIkura = tryLoad("images/foodIkura.png");
    foodZin = tryLoad("images/foodZin.png");
  }

  PImage foodImageFor(String imageName) {
    if (imageName == null) return food;
    if (imageName.equals("foodSatar")) return foodSatar;
    if (imageName.equals("foodTako")) return foodTako;
    if (imageName.equals("foodOkonomi")) return foodOkonomi;
    if (imageName.equals("foodTendon")) return foodTendon;
    if (imageName.equals("foodMonja")) return foodMonja;
    if (imageName.equals("foodKiri")) return foodKiri;
    if (imageName.equals("foodIce")) return foodIce;
    if (imageName.equals("foodIkura")) return foodIkura;
    if (imageName.equals("foodZin")) return foodZin;
    return food;
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
