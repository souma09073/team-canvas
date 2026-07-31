// ============================================================
// コースを作る。
//
// 【配置の原則】1列に置く食べ物は最大2個。必ず1レーンは空けておく。
// 3個並べて絶対に避けられない場所を作ると、プレイヤーは理不尽に感じて面白くなくなる。
//
// 【例外】終盤の「壁」だけは3レーン全部を塞ぐ。
// ただしマンジャロで消せるので、回避手段が無いわけではない。
// 「レーン移動では抜けられないが、道具を使えば抜けられる」という判断を作っている。
//
// 【毎回同じコース】乱数の種を固定しているので、何度遊んでも配置は同じ。
// タイムを競うために必要。
// ============================================================

// HTMLプロトタイプと同じ乱数(mulberry32)。
// Java の int も 32bit なので、同じ種から同じ数列が出る。
//
// 【重要】乱数を引く回数を変えてはいけない。1回でもずれると、
// それ以降の抽選が全部ずれてコース全体が別物になる。
class Rng {
  int a;

  Rng(int seed) { a = seed; }

  // 0.0以上 1.0未満
  float next() {
    a = a + 0x6D2B79F5;
    int t = (a ^ (a >>> 15)) * (1 | a);
    t = (t + ((t ^ (t >>> 7)) * (61 | t))) ^ t;
    // & 0xFFFFFFFFL で符号なし32bitとして扱う。long/double になるので float へ戻す。
    return (float)(((t ^ (t >>> 14)) & 0xFFFFFFFFL) / 4294967296.0);
  }

  // 0以上 n未満の整数
  int nextInt(int n) { return min(n - 1, (int)(next() * n)); }
}

// ---- コース上に置くもの ----

class Food {
  float z;              // スタートからの距離
  int lane;             // 0=左 1=中 2=右
  boolean eaten = false;
  Food(float z, int lane) { this.z = z; this.lane = lane; }
}

class Woman {
  float z;
  int lane;
  boolean hit = false;
  float revealT = 0;    // 地面からの出方。0=まだ地中 1=完全に出た
  Woman(float z, int lane) { this.z = z; this.lane = lane; }
}

class Sign {
  float z;
  int side;             // -1=道の左 1=道の右
  Sign(float z, int side) { this.z = z; this.side = side; }
}

// 食べ物が密集する区間。中盤と終盤で役割を分けている。
class DenseZone {
  float zFrom, zTo;     // コース全体に対する割合(0〜1)
  float rowSpacing;     // 列の間隔。小さいほど密
  float womanChance;    // 空きレーンに女性を置く確率
  boolean hasWall;      // 3個並びの壁を置くか

  DenseZone(float zFrom, float zTo, float rowSpacing, float womanChance, boolean hasWall) {
    this.zFrom = zFrom;
    this.zTo = zTo;
    this.rowSpacing = rowSpacing;
    this.womanChance = womanChance;
    this.hasWall = hasWall;
  }

  float startZ() { return COURSE_LENGTH * zFrom; }
  float endZ()   { return COURSE_LENGTH * zTo; }
}

// ============================================================

class Course {
  ArrayList<Food> foods = new ArrayList<Food>();
  ArrayList<Woman> women = new ArrayList<Woman>();
  ArrayList<Sign> signs = new ArrayList<Sign>();

  float wallStart = -1;        // 3個並びの壁の範囲
  float wallEnd = -1;
  float challengeStart = -1;   // 終盤チャレンジ(女性の列 → 壁)の入口

  Rng rng;

  // 密集区間を作っている途中の状態。weaveOpenLane() が書き換える。
  int openLane = 1;        // いま空けているレーン
  int sameLaneCount = 0;   // 同じレーンを空け続けている列数

  // 密集区間の定義。ここに行を足せば3ヶ所目・4ヶ所目が作れる。
  DenseZone[] zones() {
    return new DenseZone[] {
      // 中盤:誘惑バースト。空きレーンに女性を置いて
      // 「食べる / ぶつかる / 事前に消す」の三択を作る
      new DenseZone(0.40f, 0.47f, DENSE_ROW_SPACING, DENSE_WOMAN_CHANCE, false),

      // 終盤:最終ガントレット。マンジャロで消さないと抜けられない壁を1ヶ所だけ置く
      new DenseZone(0.72f, 0.96f, FINAL_ROW_SPACING, 0f, true)
    };
  }

  void build() {
    foods.clear();
    women.clear();
    signs.clear();
    wallStart = -1;
    wallEnd = -1;
    challengeStart = -1;

    rng = new Rng(COURSE_SEED);
    DenseZone[] zs = zones();

    buildSparseSection(zs);
    for (DenseZone d : zs) buildDenseZone(d);
    buildWallSigns();
  }

  // ============================================================
  // まばら区間:コースの大半。一定間隔で1個ずつ置く。
  // ============================================================
  void buildSparseSection(DenseZone[] zs) {
    float z = COURSE_START_CLEAR;
    int lastLane = -1;

    while (z < COURSE_LENGTH - COURSE_END_CLEAR) {
      if (!isInsideDenseZone(z, zs)) {
        int lane = pickLaneAvoiding(lastLane);
        foods.add(new Food(z, lane));
        lastLane = lane;
      }
      z += SPARSE_GAP_MIN + rng.next() * (SPARSE_GAP_MAX - SPARSE_GAP_MIN);
    }
  }

  boolean isInsideDenseZone(float z, DenseZone[] zs) {
    for (DenseZone d : zs) {
      if (z >= d.startZ() - DENSE_EDGE_BUFFER && z <= d.endZ() + DENSE_EDGE_BUFFER) return true;
    }
    return false;
  }

  // 直前と同じレーンを候補から外して1つ選ぶ。
  // 同じレーンに置き続けると、走る側は動かずに拾えてしまい、
  // 「レーンを選ぶ」という判断そのものが消えてしまう。
  int pickLaneAvoiding(int avoid) {
    int[] choices = new int[3];
    int n = 0;
    for (int lane = 0; lane < 3; lane++) {
      if (lane != avoid) choices[n++] = lane;
    }
    return choices[min(n - 1, (int)(rng.next() * n))];
  }

  // ============================================================
  // 密集区間:一定間隔で「列」を作る。各列は1レーンだけ空ける。
  // ============================================================
  void buildDenseZone(DenseZone d) {
    // 列の位置を先に全部並べる。壁は「何列目から何列目」で指定したいため。
    // 割合から距離で直接計算すると列の刻みと揃わず、指定した列数どおりにならない。
    ArrayList<Float> rowZs = new ArrayList<Float>();
    for (float rz = d.startZ(); rz <= d.endZ(); rz += d.rowSpacing) rowZs.add(rz);

    int wallFrom = -1, wallTo = -2;   // 壁が無い区間では、どの列にも当たらない値
    if (d.hasWall && rowZs.size() > 0) {
      wallFrom = findWallStartRow(rowZs);
      wallTo   = min(rowZs.size() - 1, wallFrom + FINAL_WALL_ROWS - 1);
      wallStart = rowZs.get(wallFrom);
      wallEnd   = rowZs.get(wallTo);

      // 壁の直前は「食べ物2個+空きレーンの女性」が続く区間。
      // ゾーンで女性側を抜け、マンジャロは壁へ温存する——という攻略を成立させるため、
      // その入口を覚えておいて手前で予告する。
      challengeStart = rowZs.get(max(0, wallFrom - FINAL_WOMAN_ROWS));
    }

    openLane = rng.nextInt(3);
    sameLaneCount = 0;

    for (int i = 0; i < rowZs.size(); i++) {
      float rowZ = rowZs.get(i);
      weaveOpenLane();

      boolean isWall = (i >= wallFrom && i <= wallTo);
      placeRow(rowZ, openLane, isWall);
      placeRowWoman(d, rowZ, openLane, i, wallFrom, isWall);
    }

    // 密集区間の手前に1体。「よけてから撃つか、撃ってから突っ込むか」の判断用。
    // 壁のある区間には置かない。ぶつかると7秒撃てず、ロック中に壁へ到達して
    // 回避不能になってしまうため。
    if (!d.hasWall) {
      women.add(new Woman(d.startZ() - WOMAN_LEAD_DIST, rng.nextInt(3)));
    }
  }

  // 壁を始める列を探す。見つからなければ先頭から。
  int findWallStartRow(ArrayList<Float> rowZs) {
    for (int i = 0; i < rowZs.size(); i++) {
      if (rowZs.get(i) >= COURSE_LENGTH * FINAL_WALL_AT) return i;
    }
    return 0;
  }

  // 空きレーンを隣へ動かす。左右に振ることで、追従する操作が必要になる。
  // 端では折り返す。ここで動かさないと、1レーンだけ延々ガラ空きのコースになる。
  //
  // 【重要】この関数は1つの列につき必ず1回だけ呼ぶこと。
  // 呼ぶ回数が変わると乱数の消費がずれ、コース全体が別物になる。
  // mustMove が true のときは rng.next() が呼ばれない(短絡評価)点も、
  // そのままにしておく必要がある。
  void weaveOpenLane() {
    boolean mustMove = sameLaneCount >= DENSE_MAX_SAME_LANE;
    if (mustMove || rng.next() < DENSE_WEAVE_CHANCE) {
      int dir = rng.next() < 0.5 ? -1 : 1;
      if (openLane + dir < 0 || openLane + dir > 2) dir = -dir;
      openLane += dir;
      sameLaneCount = 0;
    } else {
      sameLaneCount++;
    }
  }

  // 1列ぶんの食べ物を置く。壁の列だけは3レーン全部を埋める。
  void placeRow(float rowZ, int openLane, boolean isWall) {
    for (int lane = 0; lane < 3; lane++) {
      if (isWall || lane != openLane) foods.add(new Food(rowZ, lane));
    }
  }

  // 空きレーンに立つ女性。
  // 食べ物2個 + 空きレーンに女性 = 「食べる / ぶつかる / 事前に消す」の三択になる。
  // 終盤では壁の直前 FINAL_WOMAN_ROWS 列に必ず置く。
  void placeRowWoman(DenseZone d, float rowZ, int openLane, int i, int wallFrom, boolean isWall) {
    boolean isFinalWomanRow = d.hasWall && i >= wallFrom - FINAL_WOMAN_ROWS && i < wallFrom;
    boolean isRandomWoman = !isWall && d.womanChance > 0 && rng.next() < d.womanChance;
    if (isFinalWomanRow || isRandomWoman) women.add(new Woman(rowZ, openLane));
  }

  // ============================================================
  // 壁の予告看板
  //
  // 壁が目で見えてから撃つのでは、マンジャロの投与間隔(7秒)が間に合わない。
  // そこで、看板をかなり手前に立てて先に知らせる。
  // 看板自体も描画限界の手前から見え始めるので、実際に気付けるのは
  // 「SIGN_LEAD_SEC + 数秒」前になる。
  // ============================================================
  void buildWallSigns() {
    if (wallStart < 0) return;

    float speed = speedAtZ(wallStart);
    float[] leadSeconds = { SIGN_LEAD_SEC, SIGN_NEAR_SEC };

    for (float lead : leadSeconds) {
      float signZ = wallStart - speed * lead;
      if (signZ < 0) continue;
      signs.add(new Sign(signZ, -1));   // 道の両脇に立てる
      signs.add(new Sign(signZ, 1));
    }
  }
}
