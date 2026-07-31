// ============================================================
// コース生成。シード固定なので、リトライしても毎回まったく同じ配置になる。
// HTMLプロトタイプの buildLayout() をそのまま移植したもの。
// ============================================================

// プロトと同じ乱数(mulberry32)。Javaのintも32bitなので同じ結果になる。
class Rng {
  int a;
  Rng(int seed) { a = seed; }
  float next() {
    a = a + 0x6D2B79F5;
    int t = (a ^ (a >>> 15)) * (1 | a);
    t = (t + ((t ^ (t >>> 7)) * (61 | t))) ^ t;
    // & 0xFFFFFFFFL で符号なし32bitとして扱う。long/double になるので float へ明示的に戻す。
    return (float)(((t ^ (t >>> 14)) & 0xFFFFFFFFL) / 4294967296.0);
  }
  int nextInt(int n) { return min(n - 1, (int)(next() * n)); }
}

class Food {
  float z;
  int lane;
  boolean eaten = false;
  Food(float fz, int fl) { z = fz; lane = fl; }
}

class Woman {
  float z;
  int lane;
  boolean hit = false;
  float revealT = 0;   // 0=地中 1=完全に出た
  Woman(float wz, int wl) { z = wz; lane = wl; }
}

class Sign {
  float z;
  int side;   // -1=左 1=右
  Sign(float sz, int ss) { z = sz; side = ss; }
}

// 密集区間の定義。中盤と終盤で役割を分けている。
// 同じ区間に女性と壁を混ぜると、ロック(7秒)中に壁へ到達して回避不能になるため。
class DenseZone {
  float zFrom, zTo, rowSpacing, womanChance;
  boolean hasWall;
  DenseZone(float f, float t, float rs, float wc, boolean hw) {
    zFrom = f; zTo = t; rowSpacing = rs; womanChance = wc; hasWall = hw;
  }
}

class Course {
  ArrayList<Food> foods = new ArrayList<Food>();
  ArrayList<Woman> women = new ArrayList<Woman>();
  ArrayList<Sign> signs = new ArrayList<Sign>();
  float wallStart = -1, wallEnd = -1;   // 3個並びの壁の範囲
  float challengeStart = -1;            // 終盤チャレンジ(女性列→壁)の入口

  void build() {
    foods.clear();
    women.clear();
    signs.clear();
    wallStart = -1;
    wallEnd = -1;
    challengeStart = -1;

    Rng rng = new Rng(COURSE_SEED);

    DenseZone[] zones = {
      // 中盤:誘惑バースト。空きレーンに女性を置いて「食べる/ぶつかる/事前に消す」の三択を作る
      new DenseZone(0.40f, 0.47f, DENSE_ROW_SPACING, DENSE_WOMAN_CHANCE, false),
      // 終盤:中盤後の休憩を短くし、最終ガントレットを早めに始める。
      // マンジャロで消さないと抜けられない壁を1ヶ所だけ置く
      new DenseZone(0.72f, 0.96f, FINAL_ROW_SPACING, 0f, true)
    };

    // ---- まばら区間 ----
    // 直前と同じレーンは選ばない。同じレーンに置き続けると走る側は動かずに拾えてしまい、
    // 「レーンを選ぶ」という判断そのものが消えるため。
    float z = COURSE_START_CLEAR;
    int lastLane = -1;
    while (z < COURSE_LENGTH - COURSE_END_CLEAR) {
      boolean inDense = false;
      for (DenseZone d : zones) {
        float s = COURSE_LENGTH * d.zFrom - DENSE_EDGE_BUFFER;
        float e = COURSE_LENGTH * d.zTo + DENSE_EDGE_BUFFER;
        if (z >= s && z <= e) inDense = true;
      }
      if (!inDense) {
        int lane = rng.nextInt(3);
        if (lane == lastLane) lane = (lane + 1 + rng.nextInt(2)) % 3;
        foods.add(new Food(z, lane));
        lastLane = lane;
      }
      z += SPARSE_GAP_MIN + rng.next() * (SPARSE_GAP_MAX - SPARSE_GAP_MIN);
    }

    // ---- 密集区間 ----
    for (DenseZone d : zones) {
      float start = COURSE_LENGTH * d.zFrom;
      float end   = COURSE_LENGTH * d.zTo;

      // 列の位置を先に並べる。壁は「何列目から何列目」で指定する。
      // 割合から距離で直接計算すると行の刻みと揃わず、指定した列数どおりにならない。
      ArrayList<Float> rowZs = new ArrayList<Float>();
      for (float rz = start; rz <= end; rz += d.rowSpacing) rowZs.add(rz);

      int wallFrom = -1, wallTo = -2;
      if (d.hasWall && rowZs.size() > 0) {
        wallFrom = 0;
        for (int i = 0; i < rowZs.size(); i++) {
          if (rowZs.get(i) >= COURSE_LENGTH * FINAL_WALL_AT) { wallFrom = i; break; }
        }
        wallTo = min(rowZs.size() - 1, wallFrom + FINAL_WALL_ROWS - 1);
        wallStart = rowZs.get(wallFrom);
        wallEnd   = rowZs.get(wallTo);
        // 壁の直前は「食べ物2個+空きレーンの女性」が続く区間。
        // ゾーンで女性側を抜け、マンジャロは壁へ温存する——という攻略を成立させるため、
        // その入口を覚えておいて手前で予告する。
        int womanFrom = max(0, wallFrom - FINAL_WOMAN_ROWS);
        challengeStart = rowZs.get(womanFrom);
      }

      int openLane = rng.nextInt(3);
      int sameCount = 0;
      for (int i = 0; i < rowZs.size(); i++) {
        float rowZ = rowZs.get(i);

        // 同じレーンが続きすぎると1レーンだけ延々ガラ空きになる。上限で強制的に動かす。
        boolean mustMove = sameCount >= DENSE_MAX_SAME_LANE;
        if (mustMove || rng.next() < DENSE_WEAVE_CHANCE) {
          int dir = rng.next() < 0.5 ? -1 : 1;
          if (openLane + dir < 0 || openLane + dir > 2) dir = -dir;  // 端では折り返す
          openLane += dir;
          sameCount = 0;
        } else {
          sameCount++;
        }

        boolean isWall = (i >= wallFrom && i <= wallTo);
        for (int lane = 0; lane < 3; lane++) {
          if (isWall || lane != openLane) foods.add(new Food(rowZ, lane));
        }

        // 空きレーンに立つ女性。終盤では壁の直前 FINAL_WOMAN_ROWS 列に必ず置く。
        // 食べ物2個 + 空きレーンに女性 = 「食べる / ぶつかる / 事前に消す」の三択。
        boolean isFinalWomanRow = d.hasWall && i >= wallFrom - FINAL_WOMAN_ROWS && i < wallFrom;
        if (isFinalWomanRow || (!isWall && d.womanChance > 0 && rng.next() < d.womanChance)) {
          women.add(new Woman(rowZ, openLane));
        }
      }

      // 密集区間の手前の1体。壁のある区間には置かない
      // (ぶつかると7秒撃てず、ロック中に壁へ到達して回避不能になるため)
      if (!d.hasWall) {
        women.add(new Woman(start - WOMAN_LEAD_DIST, rng.nextInt(3)));
      }
    }

    // ---- 壁の予告看板 ----
    // 看板は約 DRAW_DIST 手前から見えるので、気付けるのは「SIGN_LEAD_SEC + 数秒」前になる。
    // これがクールタイム(7秒)より長くないと、見た時点で撃てず抜けられなくなる。
    if (wallStart > 0) {
      float sp = speedAtZ(wallStart);
      float[] leads = { SIGN_LEAD_SEC, SIGN_NEAR_SEC };
      for (int i = 0; i < leads.length; i++) {
        float sz = wallStart - sp * leads[i];
        if (sz < 0) continue;
        signs.add(new Sign(sz, -1));
        signs.add(new Sign(sz, 1));
      }
    }
  }
}
