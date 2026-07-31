// ============================================================
// 色の名前。
//
// fill(221, 34, 85) と書かれていても、それが何の色か分からない。
// 名前を付けておけば「女性の服の色を変えたい」と思ったときに探せる。
//
// 色を変えたいときは、この数字を書き換えるだけでいい。
// ============================================================

// ---- 3Dの世界 ----
final color C_SKY        = #87CEEB;   // 空
final color C_ROAD       = #55555F;   // 道路
final color C_LANE_LINE  = #FFFFFF;   // レーンの区切り線

// ---- エリアごとの色 ----
// 日本を縦断していくので、進むほど南国から北国の色へ移る。
// 画像が1枚も無くても、この色だけで「土地が変わった」ことが伝わる。
// 左が陸(草地)、右が海。
final color C_OKINAWA_LAND = #3F9B4F;   // 沖縄:明るい緑
final color C_OKINAWA_SEA  = #2ED9C3;   //       エメラルド

final color C_WEST_LAND    = #2F7A3E;   // 西日本:深い緑
final color C_WEST_SEA     = #2E86AB;   //         濃い青

final color C_EAST_LAND    = #4A7A4E;   // 東日本:くすんだ緑
final color C_EAST_SEA     = #3A6E8F;   //         灰青

final color C_HOKKAIDO_LAND = #A8B8A4;  // 北海道:雪混じりの色
final color C_HOKKAIDO_SEA  = #3E5F8A;  //         冷たい青

final color C_FOOD         = #FF8C1A;   // 食べ物
final color C_FOOD_BLOCKED = #8A8A90;   // マンジャロが効いている間の食べ物(食欲が失せた状態)

final color C_PLAYER_BODY = #33AA44;  // 主人公の服
final color C_PLAYER_SKIN = #F0C090;  // 肌
final color C_PLAYER_CAP  = #DD3333;  // 帽子

final color C_WOMAN      = #DD2255;   // 女性キャラ
final color C_WOMAN_HIT  = #884466;   // ぶつかった後(色を落として区別する)

final color C_SIGN_POST  = #6B6B73;   // 看板の支柱
final color C_SIGN_BOARD = #FFCC00;   // 看板の板
final color C_SIGN_MARK  = #CC2222;   // 板に描く「3レーン塞がっている」印

final color C_GOAL       = #FFCC00;   // ゴールゲート

// ---- 港と船 ----
// ステージのゴールは港。ゴールゲートの先に桟橋があり、船が停まっている。
// 船は目立つ色にしてある。遠くからでも「あそこがゴールだ」と分かる目印になるため。
final color C_PIER        = #8A6A45;   // 桟橋の板
final color C_PIER_POST   = #5E4830;   // 桟橋の杭
final color C_SHIP_HULL   = #1F3D6B;   // 船体
final color C_SHIP_DECK   = #E8E8EC;   // 甲板の建屋
final color C_SHIP_CABIN  = #C8CCD4;   // 操舵室
final color C_SHIP_FUNNEL = #C8422F;   // 煙突
final color C_START_LINE  = #FFFFFF;   // スタートラインの白

// ---- 血糖ゲージ ----
// 低いほうから、濃紺 → 青 → 黄 → 緑 → 赤。
// 低血糖側を青にしているのは、高血糖側の赤と一目で区別するため。
// 同じ赤にすると、上に振り切ったのか下に振り切ったのかが分からない。
final color C_GLU_CRITICAL = #101D8C;  // いよいよ危ない(最下端)
final color C_GLU_LOW      = #2B5CFF;  // 低血糖
final color C_GLU_MID      = #DDCC33;  // 中間
final color C_GLU_STABLE   = #44FF99;  // 安定域 = ゾーンが溜まる範囲
final color C_GLU_HIGH     = #DD3333;  // 高血糖

// ---- 警告 ----
final color C_WARN_HIGH = #FF0000;   // 高血糖(赤・等間隔の点滅)
final color C_WARN_LOW  = #2B5CFF;   // 低血糖(青・鼓動のような点滅)

// ---- マンジャロのパネル ----
final color C_SHOT_READY   = #66FF66;  // 打てる
final color C_SHOT_FIRED   = #FFFFFF;  // いま打った
final color C_SHOT_WAIT    = #7A7A86;  // 投与間隔の待ち
final color C_SHOT_ROBBED  = #FF44AA;  // 奪われた

// ---- 文字 ----
final color C_ACCENT = #FFCC00;   // 見出し・強調

// ---- 血糖値の数字の色 ----
// 点滅を見なくても、数字の色だけで上下どちらに振れているか分かるようにしている。
final color C_NUM_FOOD   = #FFB02E;   // 食べた瞬間
final color C_NUM_LOW    = #5B83FF;   // 低血糖
final color C_NUM_HIGH   = #FF5555;   // 高血糖
final color C_NUM_NORMAL = #FFFFFF;   // 通常

final color C_RING_HIGH  = #FF3C3C;   // ミニバーの枠(高血糖)
final color C_BLOCKED    = #78DCFF;   // 「血糖上昇なし」の文字

// ---- 岩(障害物) ----
// 食べ物と間違えないよう、暗く彩度の低い色にしてある。
final color C_ROCK     = #6E6A66;   // 岩
final color C_ROCK_HIT = #4A4744;   // ぶつかった後(もう当たらないことを示す)
