// ============================================================
// コースを作る。
//
// 【エリアごとに作る】沖縄・本州西・本州東・北海道を1つずつ組み立てる。
// 食べ物の間隔も、密集地帯を置くかどうかも、エリアが自分で持っている
// (Regions.pde の表)。このファイルは「どう並べるか」だけを決める。
//
// 【配置の原則】1列に置く食べ物は最大2個。必ず1レーンは空けておく。
// 3個並べて絶対に避けられない場所を作ると、プレイヤーは理不尽に感じて面白くなくなる。
//
// 【廃止】以前は終盤に「3レーン全部を塞ぐ壁」を置き、マンジャロでしか抜けられない
// 区間を作っていた。しかしそれは、乱用を問題として描くゲームが乱用を強制している
// ことになり矛盾していた(2026-07-31 先生の指摘)。
// 強制だけを廃止し、打つ / 打たないの選択はプレイヤーに残している。
// Config.pde の USE_FOOD_WALL を true にすれば復活する。
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

// 岩。血糖とは無関係の、純粋な障害物。ぶつかると減速する。
class Rock {
  float z;
  int lane;
  boolean hit = false;
  Rock(float z, int lane) { this.z = z; this.lane = lane; }
}

// 食べ物が密集する区間。
// 位置は Regions.pde の .dense(from, to) で指定する。後半のエリアにだけ置いてある。
class DenseZone {
  float zFrom, zTo;     // 密集の開始・終了(コース上の実際の位置)

  DenseZone(float zFrom, float zTo) {
    this.zFrom = zFrom;
    this.zTo = zTo;
  }
}

// ============================================================

class Course {
  ArrayList<Food> foods = new ArrayList<Food>();
  ArrayList<Woman> women = new ArrayList<Woman>();
  ArrayList<Sign> signs = new ArrayList<Sign>();
  ArrayList<Rock> rocks = new ArrayList<Rock>();

  float wallStart = -1;        // 3個並びの壁の範囲
  float wallEnd = -1;
  float challengeStart = -1;   // 終盤チャレンジ(女性の列 → 壁)の入口

  Rng rng;

  // 密集区間を作っている途中の状態。weaveOpenLane() が書き換える。
  int openLane = 1;        // いま空けているレーン
  int sameLaneCount = 0;   // 同じレーンを空け続けている列数

  void build() {
    foods.clear();
    women.clear();
    signs.clear();
    rocks.clear();
    wallStart = -1;
    wallEnd = -1;
    challengeStart = -1;

    rng = new Rng(COURSE_SEED);

    // エリアごとに独立して作る。エリアの間の海には何も置かない。
    for (Region r : regions) buildRegion(r);

    buildWallSigns();
  }

  // ============================================================
  // 1エリアぶんのコース。
  //
  // 難易度の数値(食べ物の間隔・密集地帯の有無)はエリアが持っている。
  // ここは「どう並べるか」だけを決め、「どれくらい詰めるか」は Regions.pde に任せる。
  // ============================================================
  void buildRegion(Region r) {
    DenseZone d = r.denseZone();   // 密集地帯を設定していないエリアでは null
    buildSparseSection(r, d);
    if (d != null) buildDenseZone(r, d);
    buildRocks(r, d);
  }

  // ============================================================
  // 岩(障害物)
  //
  // 【回避できることを必ず保証する】
  // 密集地帯には置かない。そこは2レーンが食べ物で埋まっているので、
  // 残り1レーンに岩を置くと3レーン全部が塞がり、避けようがなくなる。
  // まばら区間でも、近くに食べ物があればそれとは違うレーンに置く。
  //
  // 間隔は距離(units)のまま。速いエリアほど同じ距離を短い時間で通るので、
  // 後半ほど岩が次々に来る。これは意図した難易度上昇。
  // ============================================================
  void buildRocks(Region r, DenseZone d) {
    float z = r.startZ + COURSE_START_CLEAR + ROCK_GAP_MIN;

    while (z < r.endZ - COURSE_END_CLEAR) {
      if (!isInsideDenseZone(z, d)) {
        int lane = pickRockLane(z);
        if (lane >= 0) rocks.add(new Rock(z, lane));
      }
      z += ROCK_GAP_MIN + rng.next() * (ROCK_GAP_MAX - ROCK_GAP_MIN);
    }
  }

  // 岩を置けるレーンを選ぶ。近くの食べ物と同じレーンは避ける。
  // 置ける場所が無ければ -1 を返して、その地点は諦める。
  int pickRockLane(float z) {
    boolean[] blocked = new boolean[3];
    float near = COLLECT_DIST * 4;   // これくらい近いと「同じ場所」とみなす

    for (Food f : foods) {
      if (abs(f.z - z) < near) blocked[f.lane] = true;
    }

    int[] free = new int[3];
    int n = 0;
    for (int lane = 0; lane < 3; lane++) {
      if (!blocked[lane]) free[n++] = lane;
    }
    if (n == 0) return -1;
    return free[min(n - 1, (int)(rng.next() * n))];
  }

  // ============================================================
  // まばら区間:エリアの大半。一定間隔で1個ずつ置く。
  //
  // 【間隔は「秒」で決める】Region が持っている foodGapSec を、その地点の速度に
  // 掛けて距離へ直している。距離で決めてしまうと、速いエリアほど食べ物が高速で
  // 流れてきて、難しさが速度に引きずられる。秒で持てば「何秒に1個来るか」を
  // 設計どおりに保てる。
  // ============================================================
  void buildSparseSection(Region r, DenseZone d) {
    float z = r.startZ + COURSE_START_CLEAR;
    int lastLane = -1;

    while (z < r.endZ - COURSE_END_CLEAR) {
      if (!isInsideDenseZone(z, d)) {
        int lane = pickLaneAvoiding(lastLane);
        foods.add(new Food(z, lane));
        lastLane = lane;
      }
      float gapSec = r.foodGapSecMin + rng.next() * (r.foodGapSecMax - r.foodGapSecMin);
      z += gapSec * r.speedAt(z);
    }
  }

  boolean isInsideDenseZone(float z, DenseZone d) {
    if (d == null) return false;
    return z >= d.zFrom - DENSE_EDGE_BUFFER && z <= d.zTo + DENSE_EDGE_BUFFER;
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
  // 密集地帯:一定間隔で「列」を作る。各列は1レーンだけ空ける。
  //
  // まばら区間が「拾いに行く」場所なのに対し、ここは「よけ続ける」場所。
  // 空きレーンが左右に振れるので、追従できないと食べ物に突っ込んで高血糖になる。
  // 後半のエリアにだけ置いてある(Regions.pde の .dense(...))。
  // ============================================================
  void buildDenseZone(Region r, DenseZone d) {
    // 列の位置を先に全部並べる。壁は「何列目から何列目」で指定したいため。
    // 列の間隔も秒で決める。まばら区間と同じ理由。
    ArrayList<Float> rowZs = new ArrayList<Float>();
    for (float rz = d.zFrom; rz <= d.zTo; rz += DENSE_ROW_SEC * r.speedAt(rz)) rowZs.add(rz);

    // 壁を作らない場合、wallFrom/wallTo はどの列にも当たらない値のまま残る。
    // その結果、壁の列も・壁の直前の女性も・予告看板も、まとめて発生しなくなる。
    int wallFrom = -1, wallTo = -2;
    if (USE_FOOD_WALL && rowZs.size() > FINAL_WALL_ROWS) {
      wallFrom = rowZs.size() - FINAL_WALL_ROWS;   // 密集地帯の最後に置く
      wallTo   = rowZs.size() - 1;
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
      placeRowWoman(rowZ, openLane, i, wallFrom, isWall);
    }

    // 密集地帯の手前に1体。「よけてから撃つか、撃ってから突っ込むか」の判断用。
    // 壁のある区間には置かない。ぶつかると7秒撃てず、ロック中に壁へ到達して
    // 回避不能になってしまうため。
    if (wallFrom < 0) {
      women.add(new Woman(d.zFrom - WOMAN_LEAD_DIST, rng.nextInt(3)));
    }
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
  void placeRowWoman(float rowZ, int openLane, int i, int wallFrom, boolean isWall) {
    boolean isFinalWomanRow = wallFrom >= 0 && i >= wallFrom - FINAL_WOMAN_ROWS && i < wallFrom;
    boolean isRandomWoman = !isWall && rng.next() < DENSE_WOMAN_CHANCE;
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
