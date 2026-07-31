class AssetStore {
  PImage runner;
  PImage[] runCycleSheets = new PImage[5];
  PImage okinawaFar;
  PImage okinawaBlocks;

  void load() {
    runner = loadImage("images/player/runner.png");
    for (int i = 0; i < runCycleSheets.length; i++) {
      runCycleSheets[i] = loadImage("images/player/run30_0" + (i + 1) + ".png");
    }
    okinawaFar = loadImage("images/backgrounds/okinawa_far.png");
    okinawaBlocks = loadImage("images/backgrounds/okinawa_blocks.png");

    if (runner == null) {
      println("ERROR: images/player/runner.png を読み込めません。");
    }
    for (int i = 0; i < runCycleSheets.length; i++) {
      if (runCycleSheets[i] == null) {
        println("ERROR: images/player/run30_0" + (i + 1) + ".png を読み込めません。");
      }
    }
    if (okinawaFar == null) {
      println("ERROR: images/backgrounds/okinawa_far.png を読み込めません。");
    }
    if (okinawaBlocks == null) {
      println("ERROR: images/backgrounds/okinawa_blocks.png を読み込めません。");
    }
  }
}
