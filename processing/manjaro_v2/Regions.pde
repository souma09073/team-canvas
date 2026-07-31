// ============================================================
// エリア(区間)。
//
// 企画書では「沖縄 → 本州西 → 本州東 → 北海道」の全4ステージ構成だが、
// ステージを分けるのではなく、1本のコースを4つの区間に区切って表現している。
// 走り続けたまま土地が移り変わるので、「日本縦断」が体感として出る。
//
// 企画書に書かれている「背景差し替えと出現テーブルで拡張する」という方針を、
// そのまま実装したもの。
//
// エリアを増やしたい / 順番を変えたいときは、buildRegions() の中身をいじるだけ。
// ============================================================

class Region {
  float from;         // コース全体に対する開始位置(0〜1)
  String name;        // 区間に入ったときに画面へ出す地名
  color land;         // 道の左側(陸)の色
  color sea;          // 道の右側(海)の色
  String foodImage;   // その土地の食べ物の画像名。無ければ仮の球で描く
  String skyImage;    // その土地の背景の画像名。無ければ空色で塗る

  Region(float from, String name, color land, color sea, String foodImage, String skyImage) {
    this.from = from;
    this.name = name;
    this.land = land;
    this.sea = sea;
    this.foodImage = foodImage;
    this.skyImage = skyImage;
  }
}

Region[] regions;

// setup() から呼ぶ。
// 配列の初期化を宣言と同時に書くと、色の定数より先に作られる恐れがあるため関数にしている。
void buildRegions() {
  regions = new Region[] {
    new Region(0.00, "沖縄",        C_OKINAWA_LAND,  C_OKINAWA_SEA,  "food_okinawa.png",  "sky_okinawa.png"),
    new Region(0.25, "本州 西日本", C_WEST_LAND,     C_WEST_SEA,     "food_west.png",     "sky_west.png"),
    new Region(0.50, "本州 東日本", C_EAST_LAND,     C_EAST_SEA,     "food_east.png",     "sky_east.png"),
    new Region(0.75, "北海道",      C_HOKKAIDO_LAND, C_HOKKAIDO_SEA, "food_hokkaido.png", "sky_hokkaido.png")
  };
}

// 地点 z が何番目の区間にあたるか
int regionIndexAt(float z) {
  float p = constrain(z / COURSE_LENGTH, 0, 1);
  int found = 0;
  for (int i = 0; i < regions.length; i++) {
    if (p >= regions[i].from) found = i;
  }
  return found;
}

Region regionAt(float z) { return regions[regionIndexAt(z)]; }

// 地点 z の陸・海の色。
// 区間の境目でいきなり色が変わると線が見えてしまうので、
// REGION_BLEND_DIST の距離をかけて次の色へ混ぜる。
color landColorAt(float z) { return blendRegionColor(z, true); }
color seaColorAt(float z)  { return blendRegionColor(z, false); }

color blendRegionColor(float z, boolean isLand) {
  int i = regionIndexAt(z);
  Region cur = regions[i];
  color c = isLand ? cur.land : cur.sea;

  // 次の区間が無ければ混ぜる相手がいない
  if (i + 1 >= regions.length) return c;

  Region next = regions[i + 1];
  float boundary = COURSE_LENGTH * next.from;
  float toBoundary = boundary - z;
  if (toBoundary > REGION_BLEND_DIST) return c;   // まだ遠い

  float t = 1 - constrain(toBoundary / REGION_BLEND_DIST, 0, 1);
  return lerpColor(c, isLand ? next.land : next.sea, t);
}
