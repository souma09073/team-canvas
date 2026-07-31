// ============================================================
// 調整する数値は全部ここ。
// ゲームバランスを変えたいときは、このファイルだけ触ればいい。
// 変えたら Run し直すだけで反映される。
//
// ┌─ よく使う早見表 ────────────────────────────────┐
// │ コースを短くしたい      → COURSE_LENGTH_SEC を下げる       │
// │ 速くしたい              → BASE_SPEED / RAMP_END_MULT       │
// │ メーターの動きを穏やかに→ FOOD_GAIN と DRAIN_PER_SEC を    │
// │                           同じ倍率で下げる                 │
// │ 低血糖で死にやすく      → DRAIN_PER_SEC を上げる           │
// │ 高血糖で死にやすく      → DRAIN_PER_SEC_HIGH を下げる      │
// │ 全体を易しく            → HYPER_GRACE_SEC を上げる         │
// │ 食べ物を減らしたい      → SPARSE_GAP_MIN / MAX を上げる    │
// └────────────────────────────────────────────────┘
//
// 【注意1】FOOD_GAIN と DRAIN_PER_SEC はセットで考える。
//   必要ペース = FOOD_GAIN ÷ DRAIN_PER_SEC 秒に1個(今は 20÷10 = 2.0秒)。
//   両方を同じ倍率で変えれば、忙しさを変えずに跳ね方だけ調整できる。
//
// 【注意2】STABLE_MAX を変えるときは、HYPER_THRESHOLD と HYPER_RESET_BELOW も
//   同じ数字にする(3ヶ所セット)。
//
// 【注意3】高血糖で死ぬ条件:
//   (100 - STABLE_MAX) ÷ DRAIN_PER_SEC_HIGH が HYPER_GRACE_SEC を超えると
//   「振り切ったら確定死」になる。今は 35÷15 = 2.33秒 対 3秒 で、余裕0.67秒。
// ============================================================

// ---- 画面 ----
final int SCREEN_W = 1280;   // 設計上の画面サイズ。実画面へは拡大縮小して表示する
final int SCREEN_H = 720;

// 画面いっぱいで起動するか。
//   true  … どのPCでも必ず収まる。提出・発表はこちら(終了は ESC キー)
//   false … ウィンドウで起動する。コードを直しながら試すときはこちら
//
// ウィンドウ表示だと、Windowsの表示倍率(125%/150%)やマルチモニタの環境で
// 画面からはみ出すことがある。指定した大きさより実際の表示が大きくなるため。
// フルスクリーンならその心配がない。
final boolean FULLSCREEN = true;

// ---- 見た目 ----
// イラストを使うか。false にすると、画像があっても全部が球と箱の表示に戻る。
// 何かおかしくなったら、まずここを false にして切り分ける。
final boolean USE_IMAGES = true;

// 主人公の絵の高さ(ワールド単位)。球で描いていたときの体格に合わせてある。
// 大きすぎ・小さすぎを感じたらここを変える。
final float PLAYER_IMG_HEIGHT = 3.4;

// 絵を貼った板をカメラ側へ倒す角度(度)。
// カメラは少し見下ろしているので、0のままだと「地面に立てたシール」に見えることがある。
// その場合は 10〜20 くらいを試す。0 で真っ直ぐ立つ。
final float BILLBOARD_TILT = 0;

// ---- 血糖 ----
// 必要ペース = FOOD_GAIN / DRAIN_PER_SEC 秒に1個(今は 20/10 = 2.0秒に1個)
final float DRAIN_PER_SEC      = 10;    // 血糖の毎秒自然減少・通常時
final float DRAIN_PER_SEC_HIGH = 15;    // 高血糖時の下がり方。小さいほど高血糖で死にやすい
final float STABLE_MIN         = 35;    // 安定域(緑)の下限 = ゾーンが溜まる範囲の下限
final float STABLE_MAX         = 65;    // 安定域(緑)の上限
final float HYPER_THRESHOLD    = 65;    // これを超えると高血糖カウントダウン開始
final float HYPER_GRACE_SEC    = 3;     // 猶予(秒)
final float HYPER_RESET_BELOW  = 65;    // ここまで下げれば解除
final float FOOD_GAIN          = 20;    // 食べ物1つの血糖上昇
final float DANGER_ZONE        = 15;    // これ未満で低血糖の警告(青)

// ---- 倒れたときの減速 ----
// 血糖が振り切れても、以前のように即ゲームオーバーにはしない。
// 一定時間だけ大きく減速し、治療を受けて走り続ける。
//
// 【この変更の理由】
// ・やり直しを無くすと、失敗しても最後まで通しで遊べる(人に見せるときに効く)
// ・タイムアタックなので「遅くなる」ことが十分な罰になる
// ・先生から「休みをちょうだい」と言われており、即死の緊張を下げたい
//
// 失う時間 = COLLAPSE_SEC × (1 - COLLAPSE_SPEED_MULT)
//          = 3.0 × 0.6 = 約1.8秒
final float COLLAPSE_SEC        = 3.0;   // 減速している時間
final float COLLAPSE_SPEED_MULT = 0.4;   // その間の速度(1.0で通常)
final float COLLAPSE_GLUCOSE    = 50;    // 治療を受けて戻る血糖値

// ---- マンジャロ(注射) ----
final float SHOT_CLEAR_SEC  = 2.5;   // 前方「走行速度×この秒数」の食べ物を全レーン消去
final float SHOT_COOLDOWN   = 7;     // 使用間隔(秒)。現実の投与間隔を再現している
final float SHOT_EFFECT_SEC = 2.0;   // 使用後、食べ物を取っても血糖が上昇しない時間
// 効いている間は「血糖が上がらない」。食べても吸収されない(これが薬の作用そのもの)。
// 下降は止めず 80% に緩めるだけ。完全に止めると低血糖のリスクが消えてしまい、
// マンジャロの危険性が表現できなくなるため。
final float SHOT_DRAIN_MULT = 0.8;   // 効果中の血糖降下の倍率(1.0=通常どおり / 0=止まる)
final float LOCK_DURATION   = 7;     // 女性に接触したとき撃てなくなる秒数

// ---- ゾーン ----
final float ZONE_CHARGE_PER_SEC = 8;     // 緑の帯に居る間の蓄積(%/秒)
final float ZONE_DECAY_PER_SEC  = 0;     // 帯を外れた時の減少(%/秒)。0=貯金は消えない
final float FOOD_POP_SEC        = 0.5;   // 食べた演出の長さ(秒)
final float ZONE_DURATION       = 1.5;   // 発動時間(秒)
final float ZONE_SPEED_MULT     = 1.8;   // 発動中の速度倍率
// ゾーンの効果は「加速」と「女性すり抜け」だけ。食べ物はすり抜けず血糖も普通に動く

// ---- 速度とコース ----
final float COURSE_LENGTH_SEC = 55;    // 想定プレイ時間(70→55 間延びしていた中盤以降を圧縮)
final float BASE_SPEED        = 70;    // 序盤の速度(units/秒)
final float RAMP_END_MULT     = 2.8;   // ゴール時の倍率(終速 196 units/秒)
final float LANE_WIDTH        = 4;
final float LANE_CHANGE_SPEED = 18;    // レーン移動の速さ(units/秒)
final float COLLECT_DIST      = 2.0;   // 当たり判定(前後方向)

// ---- 食べ物の配置 ----
// 原則、1列は最大2個(必ず逃げ道が1レーン残る)。例外は終盤の壁だけ。
final float SPARSE_GAP_MIN   = 52;
final float SPARSE_GAP_MAX   = 85;
final float DENSE_ROW_SPACING = 50;    // 中盤の密集
final float FINAL_ROW_SPACING = 65;    // 終盤のガントレット
final float DENSE_WEAVE_CHANCE = 0.7;  // 空きレーンが隣へ動く確率
final int   DENSE_MAX_SAME_LANE = 2;   // 同じレーンが空き続けられる最大列数
final float DENSE_WOMAN_CHANCE = 0.15; // 【中盤のみ】空きレーンに女性を置く確率
// 終盤の「3個並びの壁」を置くか。
//
// 【false にした理由】
// この壁はマンジャロでしか抜けられないため、プレイヤーに薬の使用を強制していた。
// しかしこのゲームは「乱用を問題として描く」ことが目的なので、
// ゲーム側が乱用を要求しているのは矛盾している(2026-07-31 先生の指摘)。
//
// 解決として「選択を無くす」案もあったが、それだと薬がプレイヤーの手から消えて
// ただの演出になってしまう。そこで【強制だけを廃止し、選択は残す】ことにした。
// 打つか打たないかは、常にプレイヤーが決める。
//
// 壁を作るコードは消していない。true に戻せば復活する。
final boolean USE_FOOD_WALL  = false;

final float FINAL_WALL_AT    = 0.80;   // 【終盤のみ】3個並びの壁の位置(コース長に対する割合)
final int   FINAL_WALL_ROWS  = 4;      // 壁の列数
final int   FINAL_WOMAN_ROWS = 3;      // 壁の直前に置く「食べ物2個+空きレーンの女性」の列数
final float FINAL_WARN_SEC   = 5;      // 終盤チャレンジの操作ヒントを何秒手前から出すか
final float COURSE_START_CLEAR = 40;
final float COURSE_END_CLEAR   = 40;
final float DENSE_EDGE_BUFFER  = 10;
final float WOMAN_LEAD_DIST    = 18;

// ---- 女性キャラと看板 ----
final float WOMAN_REVEAL_SEC = 1.2;   // 走行速度×この秒数の手前で地面から現れる
final float WOMAN_RISE_SEC   = 0.15;  // せり上がりきるまでの時間
final float WOMAN_HIDE_Y     = -3.2;  // 地面下の隠し位置
final float SIGN_LEAD_SEC    = 8;     // 壁の何秒手前に看板を立てるか(SHOT_COOLDOWN より大きく)
final float SIGN_NEAR_SEC    = 2;

final int   COURSE_SEED = 12345;      // 同じ数字なら毎回同じコース

// ---- エリア(日本縦断の区間) ----
// 区間の区切り位置と地名は Regions.pde の buildRegions() にある。
final float REGION_BLEND_DIST = 260;   // 区間の境目で色を混ぜる距離。長いほどなだらかに変わる
final float REGION_BANNER_SEC = 2.6;   // 区間に入ったとき地名を出しておく秒数
final float GROUND_SLICE = 24;         // 地面を何units刻みで塗り分けるか。小さいほど色の変化が滑らか

// ---- 描画 ----
final float DRAW_DIST = 420;   // これより遠いものは描かない(P3Dにフォグが無いので手前で消す)
final float FADE_DIST = 160;   // 遠方でこの距離ぶんかけて薄くする(唐突な出現を防ぐ)
final float CAM_HEIGHT = 5;    // カメラの高さ
final float CAM_BACK   = 11;   // 主人公の後ろへの距離
final float CAM_LOOK_Y = 1.5;  // 注視点の高さ
final float CAM_LOOK_AHEAD = 12;
final float FOV_BASE = 60;     // 画角(度)。速度が上がるほど広がる

// 主人公の右横に追従する縦向きの血糖バー(下=0 上=100)。
// 左上のメーターから目を離さずに済むよう、視線の近くにもう1つ置いている。
final float MINI_GAUGE_SIDE = 2.4;   // 主人公から右へ何units離すか
final float MINI_GAUGE_BODY_Y = 1.6; // 体のどの高さに合わせるか
final float MINI_GAUGE_W = 14;       // 設計座標での幅
final float MINI_GAUGE_H = 150;      // 設計座標での高さ

// 画面の左右とワールドのX符号の対応。
// camera() の up ベクトルを (0,-1,0) にしている都合で、+X が画面のどちら側に出るかは
// 実際に動かさないと分からない。実機で確認した結果 +1 が正しかった(-1 だと左右が逆になる)。
final float LANE_X_SIGN = 1;

// コース長は「想定プレイ時間 × 平均速度」で決める
final float COURSE_LENGTH = BASE_SPEED * COURSE_LENGTH_SEC * (1 + RAMP_END_MULT) / 2;

// 地点 z における走行速度
float speedAtZ(float z) {
  float p = constrain(z / COURSE_LENGTH, 0, 1);
  return BASE_SPEED * (1 + (RAMP_END_MULT - 1) * p);
}

// レーン番号(0=左 1=中 2=右)を ワールドX に変換する
float laneToX(int lane) {
  return LANE_X_SIGN * (lane - 1) * LANE_WIDTH;
}
