// 画面とビジュアル試作の調整値。
// 本編の血糖・コース配置などは、HTML版から移植する段階でここへ追加する。

final int SCREEN_W = 1280;
final int SCREEN_H = 720;

final float HORIZON_Y = 286;
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
