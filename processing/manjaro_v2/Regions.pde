// ============================================================
// エリア(ステージ)。沖縄 → 本州西 → 本州東 → 北海道。
//
// 【エリアは離れて置かれている】
// エリアとエリアの間には REGION_GAP ぶんの空白がある。ここは海で、走らない。
// ゴールの港で船に乗り、次のエリアの港へ運ばれる(leaveFerry() が z を飛ばす)。
//
//   沖縄 [startZ ... endZ] ~~~ 海 ~~~ 本州西 [startZ ... endZ] ~~~ 海 ~~~ ...
//
// 空白は描画距離(DRAW_DIST)より長くしてある。だから港に立っても次のエリアは
// 見えない。「同じ道の続き」ではなく「別の土地」として届く。
//
// 【速度】エリア内では少しずつ加速し、次のエリアでは開始速度に戻る。
// 開始速度はエリアが進むほど上がるので全体としては速くなるが、
// 港でいったんリセットされるため、いきなり手に負えなくならない。
//
// 【長さ】速いエリアほど長くする。そうすればどのエリアも同じ秒数で走り終わる。
// 長さは targetSec と速度から自動計算するので、手で調整しなくていい。
//
// 【難易度】エリアが進むほど、食べ物の間隔が詰まり、血糖の振れ幅も大きくなる。
// 間隔を「秒」で指定しているのがポイント。距離で指定すると、速いエリアほど
// 食べ物が高速で流れてきて、難しさが速度に引きずられてしまう。
// ============================================================

class Region {
  String name;         // 画面に出す地名
  String startPort;    // このエリアの出発地(船で着いた港)
  String goalPort;     // このエリアのゴール(次の船に乗る港)

  float baseSpeed;     // 開始速度
  float rampMult;      // 終わりまでに何倍まで加速するか
  float targetSec;     // 無停止で走り抜けたときの目安タイム。ここから長さが決まる
  float limitSec;      // その区間で到着しなければならない制限時間

  color land;          // 道の左側(陸)の色
  color sea;           // 道の右側(海)の色
  String foodImage;    // その土地の食べ物の画像名。無ければ仮の球で描く
  String skyImage;     // その土地の背景の画像名。無ければ空色で塗る

  // 走り終えたあと、港で止まって途中経過を見せるか。
  // true  … Enter 待ち(中間地点)  false … 演出が流れて自動で次へ(テンポ優先)
  boolean restAfter = false;

  // ---- 難易度 ----
  float foodGapSecMin = 0.5;   // 食べ物の間隔(秒)。狭いほど忙しい
  float foodGapSecMax = 0.8;
  float foodGain      = 20;    // 食べ物1つの血糖上昇
  float drainPerSec   = 10;    // 血糖の毎秒自然減少
  // 必要ペース = foodGain / drainPerSec 秒に1個。
  // 上の表は全エリアで 2.0 秒になるよう組んである。忙しさは変えず、
  // 「1回のミスがどれだけ響くか」だけがエリアごとに大きくなる。

  float denseFrom = -1;        // 密集地帯の範囲(エリア内の割合 0〜1)。負なら密集なし
  float denseTo   = -1;

  // buildRegions() が計算して入れる
  float startZ, endZ;

  Region(String name) { this.name = name; }

  // ---- 設定用。つなげて書ける(Regions の表を読みやすくするため)----
  Region ports(String startPort, String goalPort) {
    this.startPort = startPort;  this.goalPort = goalPort;  return this;
  }
  Region speed(float baseSpeed, float rampMult, float targetSec) {
    this.baseSpeed = baseSpeed;  this.rampMult = rampMult;  this.targetSec = targetSec;  this.limitSec = targetSec;  return this;
  }
  Region limit(float limitSec) {
    this.limitSec = limitSec;  return this;
  }
  Region look(color land, color sea, String foodImage, String skyImage) {
    this.land = land;  this.sea = sea;
    this.foodImage = foodImage;  this.skyImage = skyImage;  return this;
  }
  Region food(float gapSecMin, float gapSecMax, float gain, float drain) {
    this.foodGapSecMin = gapSecMin;  this.foodGapSecMax = gapSecMax;
    this.foodGain = gain;  this.drainPerSec = drain;  return this;
  }
  // 引数名を from / to にしないこと。Processing のパーサーが to を予約語として扱い、
  // 「Syntax Error - Error on parameter or method declaration」で止まる。
  Region dense(float fromRatio, float toRatio) {
    this.denseFrom = fromRatio;  this.denseTo = toRatio;  return this;
  }
  Region rest() { this.restAfter = true; return this; }

  // ---- 計算 ----
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

  // 地点 fromZ からこのエリアのゴールまで、無停止で何秒かかるか。
  // 速度が場所によって変わるので、細かく区切って足し上げている。
  float secondsFrom(float fromZ) {
    float remain = endZ - max(fromZ, startZ);
    if (remain <= 0) return 0;

    int steps = 12;
    float total = 0;
    for (int i = 0; i < steps; i++) {
      float sampleZ = max(fromZ, startZ) + remain * (i + 0.5) / steps;
      total += (remain / steps) / speedAt(sampleZ);
    }
    return total;
  }

  // 密集地帯。設定していなければ null。
  DenseZone denseZone() {
    if (denseFrom < 0) return null;
    return new DenseZone(startZ + length() * denseFrom,
                         startZ + length() * denseTo);
  }
}

Region[] regions;
float COURSE_LENGTH = 0;   // 最後のエリアのゴール地点(= ゲーム全体の終わり)
float RUN_LENGTH    = 0;   // 実際に走る距離の合計。海の空白は含まない

// setup() から呼ぶ。COURSE_LENGTH を使う処理より先に呼ぶこと。
//
// 【エリアを増やす / 順番を変える】この配列に行を足すだけでいい。
// マンジャロの使用回数(1エリア1回)も、ゴール画面の文言も、
// エリアの数から自動で決まるので、他は何も直さなくていい。
//
// 【港の名前】3回の船旅は、すべて実在する定期フェリー航路に合わせてある。
//   那覇港 → 鹿児島港   マルエーフェリー / マリックスライン
//   名古屋港 → 仙台港   太平洋フェリー
//   八戸港 → 苫小牧港   シルバーフェリー(川崎近海汽船)
// 南から北へ、実際に船で行ける順番になっている。
// 変えたいときはここの文字列を書き換えるだけでいい。
//
// 【難易度の設計】食べ物の間隔だけで難易度を作っている。
//
// 血糖を保つには「上昇÷減少 = 2.0秒」に1個食べる必要がある。
// 一方、1レーンに立ったまま動かないと「間隔×3」秒に1個当たる。
// この比を【過剰率】と呼ぶと、1.0なら動かなくてもちょうど良く、
// 大きいほど「意識して避けないと高血糖になる」。
//
//   沖縄 1.39 → 西日本 1.60 → 東日本 1.80 → 北海道 2.05
//
// 以前は 1.39 → 1.71 → 1.39 → 1.63 で、2ステージ目が山になり
// 3ステージ目で入門レベルに戻っていた。北海道が簡単に感じる原因はこれだった。
//
// 速度・岩の数・密集地帯の長さ・血糖の振れ幅は元から順に上がっているので、
// この表では食べ物の間隔だけを直している。
void buildRegions() {
  regions = new Region[] {

    region("沖縄")
      .ports("沖縄 糸満", "那覇港")
      .speed(95, 1.5, 25)
      .limit(30)
      .look(C_OKINAWA_LAND, C_OKINAWA_SEA, "food_okinawa.png", "sky_okinawa.png")
      .food(0.36, 0.60, 16, 8),                 // 導入。密集なし。食べ物を増やす

    // 鹿児島に上陸してから名古屋まで。九州を含むので「本州」とは呼べない
    region("西日本")
      .ports("鹿児島港", "名古屋港")
      .speed(115, 1.5, 25)
      .limit(30)
      .look(C_WEST_LAND, C_WEST_SEA, "food_west.png", "sky_west.png")
      .food(0.32, 0.52, 20, 10)                 // 少し多め。まだ密集なし
      .rest(),                                  // ← 中間地点。ここだけ止まる

    region("東日本")
      .ports("仙台港", "八戸港")
      .speed(135, 1.5, 25)
      .limit(30)
      .look(C_EAST_LAND, C_EAST_SEA, "food_east.png", "sky_east.png")
      .food(0.29, 0.45, 24, 12)                 // ここから避け続けないと保たない
      .dense(0.45, 0.62),                       // 密集地帯がひとつ

    region("北海道")
      .ports("苫小牧港", "宗谷岬")
      .speed(160, 1.5, 25)
      .limit(30)
      .look(C_HOKKAIDO_LAND, C_HOKKAIDO_SEA, "food_hokkaido.png", "sky_hokkaido.png")
      .food(0.25, 0.40, 28, 14)                 // 最難関。半分以上を避けないと高血糖になる
      .dense(0.45, 0.90)                        // ゴール直前まで密集。最後まで気を抜かせない
  };

  // 全体の速さをまとめて掛ける。Config.pde の SPEED_SCALE で調整する。
  for (Region r : regions) r.baseSpeed *= SPEED_SCALE;

  // 各エリアの長さを目標秒数から求め、REGION_GAP の海を挟みながら並べる。
  float z = 0;
  RUN_LENGTH = 0;
  for (Region r : regions) {
    r.startZ = z;
    z += r.requiredLength();
    r.endZ = z;
    RUN_LENGTH += r.length();
    z += REGION_GAP;        // 次のエリアまでの海。ここは走らない
  }
  COURSE_LENGTH = regions[regions.length - 1].endZ;

  println("--- エリア構成 ---");
  for (Region r : regions) {
    println(r.name + "  " + r.startPort + " → " + r.goalPort
          + "  速度 " + int(r.baseSpeed) + "→" + int(r.endSpeed())
          + "  長さ " + int(r.length()) + "  目安 " + int(r.targetSec) + "秒"
          + "  食べ物 " + nf(r.foodGapSecMin, 1, 2) + "〜" + nf(r.foodGapSecMax, 1, 2) + "秒間隔"
          + "  +" + int(r.foodGain) + "/-" + int(r.drainPerSec)
          + (r.denseZone() != null ? "  密集あり" : ""));
  }
  println("走行距離 " + int(RUN_LENGTH) + " units / 走行 "
        + int(regions.length * regions[0].targetSec) + "秒");
}

// 表を読みやすくするための入口。new Region(...) と書くより意図が出る。
Region region(String name) { return new Region(name); }

// 地点 z が何番目のエリアにあたるか。
// 海の空白にいる間は、直前のエリアを返す(通常そこは走らない)。
int regionIndexAt(float z) {
  for (int i = regions.length - 1; i >= 0; i--) {
    if (z >= regions[i].startZ) return i;
  }
  return 0;
}

Region regionAt(float z) { return regions[regionIndexAt(z)]; }

// 地点 z における走行速度。エリアが変わると開始速度へ戻る。
float speedAtZ(float z) { return regions[regionIndexAt(z)].speedAt(z); }

// 演出の基準にする速度(最初のエリアの開始速度)。
// 画角の広がりや走りの上下動を、これとの比で決めている。
float baseSpeedRef() { return regions[0].baseSpeed; }

// スタートからここまでに実際に走った距離。海の空白を飛ばして数える。
// 進捗バーはこれを使う。z をそのまま使うと、船に乗った瞬間にバーが飛んでしまう。
float runDistanceAt(float z) {
  int i = regionIndexAt(z);
  float d = 0;
  for (int k = 0; k < i; k++) d += regions[k].length();
  return d + constrain(z - regions[i].startZ, 0, regions[i].length());
}
