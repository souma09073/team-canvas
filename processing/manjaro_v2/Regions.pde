// ============================================================
// エリア(区間)。
//
// 企画書では「沖縄 → 本州西 → 本州東 → 北海道」の全4ステージ構成だが、
// ステージを分けるのではなく、1本のコースを4つの区間に区切って表現している。
// 走り続けたまま土地が移り変わるので、「日本縦断」が体感として出る。
//
// 【速度の考え方】
// エリア内では少しずつ加速し、フェリーに着くと次のエリアの開始速度に戻る。
// 開始速度はエリアが進むほど上がるので全体としては速くなっていくが、
// 休憩のたびに一度リセットされるため、いきなり手に負えなくならない。
//
// 【長さの決め方】
// 速いエリアほど長くする。そうすれば、どのエリアも同じくらいの時間で走り終わる。
// 長さは「目標秒数」と「速度」から自動で計算するので、手で調整する必要はない。
//
// エリアを増やしたい / 順番を変えたいときは buildRegions() の中身をいじるだけ。
// ============================================================

class Region {
  String name;        // 区間に入ったときに画面へ出す地名
  float baseSpeed;    // このエリアの開始速度
  float rampMult;     // エリアの終わりまでに何倍まで加速するか
  float targetSec;    // 無減速で走り抜けたときの目安タイム。ここから長さが決まる

  color land;         // 道の左側(陸)の色
  color sea;          // 道の右側(海)の色
  String foodImage;   // その土地の食べ物の画像名。無ければ仮の球で描く
  String skyImage;    // その土地の背景の画像名。無ければ空色で塗る

  // 以下は buildRegions() が計算して入れる
  float startZ;
  float endZ;

  Region(String name, float baseSpeed, float rampMult, float targetSec,
         color land, color sea, String foodImage, String skyImage) {
    this.name = name;
    this.baseSpeed = baseSpeed;
    this.rampMult = rampMult;
    this.targetSec = targetSec;
    this.land = land;
    this.sea = sea;
    this.foodImage = foodImage;
    this.skyImage = skyImage;
  }

  float endSpeed() { return baseSpeed * rampMult; }
  float length()   { return endZ - startZ; }

  // 目標秒数で走り抜けるために必要な長さ。
  // 速度が距離に対して線形に上がるとき、所要時間は L/(v1-v0) × ln(v1/v0) になる。
  // これを L について解いた式。
  float requiredLength() {
    float v0 = baseSpeed, v1 = endSpeed();
    if (v1 <= v0) return targetSec * v0;          // 加速しない設定なら単純な掛け算
    return targetSec * (v1 - v0) / log(v1 / v0);
  }

  // このエリア内の地点 z における速度
  float speedAt(float z) {
    float p = constrain((z - startZ) / max(1, length()), 0, 1);
    return baseSpeed + (endSpeed() - baseSpeed) * p;
  }
}

Region[] regions;
float COURSE_LENGTH = 0;   // 全エリアの合計。buildRegions() が計算する

// setup() から呼ぶ。COURSE_LENGTH を使う処理より先に呼ぶこと。
void buildRegions() {
  regions = new Region[] {
    //         地名          開始 加速 目標秒  陸の色           海の色          食べ物の画像         背景の画像
    new Region("沖縄",        95, 1.5,  25,  C_OKINAWA_LAND,  C_OKINAWA_SEA,  "food_okinawa.png",  "sky_okinawa.png"),
    new Region("本州 西日本", 115, 1.5,  25,  C_WEST_LAND,     C_WEST_SEA,     "food_west.png",     "sky_west.png"),
    new Region("本州 東日本", 135, 1.5,  25,  C_EAST_LAND,     C_EAST_SEA,     "food_east.png",     "sky_east.png"),
    new Region("北海道",      160, 1.5,  25,  C_HOKKAIDO_LAND, C_HOKKAIDO_SEA, "food_hokkaido.png", "sky_hokkaido.png")
  };

  // 全体の速さをまとめて掛ける。Config.pde の SPEED_SCALE で調整する。
  for (Region r : regions) r.baseSpeed *= SPEED_SCALE;

  // 各エリアの長さを目標秒数から求め、先頭から順に並べる。
  // 速度を上げると長さも自動で伸びるので、1エリアのタイムは変わらない。
  float z = 0;
  for (Region r : regions) {
    r.startZ = z;
    z += r.requiredLength();
    r.endZ = z;
  }
  COURSE_LENGTH = z;

  println("--- エリア構成 ---");
  for (Region r : regions) {
    println(r.name + "  速度 " + int(r.baseSpeed) + "→" + int(r.endSpeed())
          + "  長さ " + int(r.length()) + "  目安 " + int(r.targetSec) + "秒");
  }
  println("合計 " + int(COURSE_LENGTH) + " units / 走行 " + int(regions.length * regions[0].targetSec) + "秒");
}

// 地点 z が何番目のエリアにあたるか
int regionIndexAt(float z) {
  for (int i = regions.length - 1; i >= 0; i--) {
    if (z >= regions[i].startZ) return i;
  }
  return 0;
}

Region regionAt(float z) { return regions[regionIndexAt(z)]; }

// 地点 z における走行速度。エリアが変わると開始速度へ戻る。
float speedAtZ(float z) {
  return regions[regionIndexAt(z)].speedAt(z);
}

// 演出の基準にする速度(最初のエリアの開始速度)。
// 画角の広がりや走りの上下動を、これとの比で決めている。
float baseSpeedRef() { return regions[0].baseSpeed; }

// 地点 z の陸・海の色。
// 区間の境目でいきなり色が変わると線が見えてしまうので、
// REGION_BLEND_DIST の距離をかけて次の色へ混ぜる。
color landColorAt(float z) { return blendRegionColor(z, true); }
color seaColorAt(float z)  { return blendRegionColor(z, false); }

color blendRegionColor(float z, boolean isLand) {
  int i = regionIndexAt(z);
  Region cur = regions[i];
  color c = isLand ? cur.land : cur.sea;

  if (i + 1 >= regions.length) return c;   // 次のエリアが無ければ混ぜる相手がいない

  Region next = regions[i + 1];
  float toBoundary = next.startZ - z;
  if (toBoundary > REGION_BLEND_DIST) return c;   // まだ遠い

  float t = 1 - constrain(toBoundary / REGION_BLEND_DIST, 0, 1);
  return lerpColor(c, isLand ? next.land : next.sea, t);
}
