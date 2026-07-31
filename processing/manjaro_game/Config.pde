// 画面とビジュアル試作の調整値。
// 本編の血糖・コース配置などは、HTML版から移植する段階でここへ追加する。

// 設計上の画面サイズ。描画は常にこの座標で書き、実際のウィンドウへ拡大縮小して表示する。
// こうしないと、解像度や表示倍率の違うPCでウィンドウがはみ出して全体が見えなくなる。
final int SCREEN_W = 1280;
final int SCREEN_H = 720;

float designScale = 1;      // 設計座標 -> 実ウィンドウ の倍率
float designOffsetX = 0;    // 余った分を左右に振り分ける(レターボックス)
float designOffsetY = 0;

void computeDesignTransform() {
  designScale = min(width / float(SCREEN_W), height / float(SCREEN_H));
  designOffsetX = (width - SCREEN_W * designScale) * 0.5;
  designOffsetY = (height - SCREEN_H * designScale) * 0.5;
  println("画面: " + width + "x" + height + " / 表示倍率 " + nf(designScale, 1, 3));
}

// 2D(設計座標)で描き始める。3Dの奥行き判定を切り、カメラを既定に戻してから
// 1280x720 の座標系に合わせる。camera() が行列を戻すので、必ずその後に変換をかける。
void beginDesignSpace() {
  hint(DISABLE_DEPTH_TEST);
  camera();
  ortho();
  translate(designOffsetX, designOffsetY);
  scale(designScale);
}

void endDesignSpace() {
  hint(ENABLE_DEPTH_TEST);
}

// 背景画像 okinawa_far.png の地平線(海と陸の境目)は画像の高さの 54.2% にある。
// 1280x720 に引き伸ばすと画面上の y=390。道路の消失点をここに合わせないと、
// 道路が地面ではなく空へ向かって伸び、背景から浮いて見える(以前は 286 で 104px ずれていた)。
final float HORIZON_Y = 390;
final float ROAD_TOP_HALF = 46;
final float ROAD_BOTTOM_HALF = 575;

final float[] LANE_SCREEN_X = {
  SCREEN_W * 0.5 - 285,
  SCREEN_W * 0.5,
  SCREEN_W * 0.5 + 285
};

final float PLAYER_BASE_Y = 668;
final float PLAYER_HEIGHT = 350;
final float PLAYER_LANE_SMOOTH = 10.0;
final float RUN_CYCLE_SPEED = 9.5;
