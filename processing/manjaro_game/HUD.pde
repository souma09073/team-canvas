class PrototypeHUD {
  PFont font;

  PrototypeHUD() {
    font = createFont("Meiryo UI", 20);
  }

  void draw(Runner runner) {
    hint(DISABLE_DEPTH_TEST);
    camera();
    ortho();

    noStroke();
    fill(27, 22, 25, 205);
    rect(24, 22, 284, 76, 16);

    if (font != null) textFont(font);
    textAlign(LEFT, TOP);
    fill(255, 211, 72);
    textSize(14);
    text("VISUAL PROTOTYPE 01", 43, 38);
    fill(255);
    textSize(22);
    text("沖縄　日本縦断スタート", 43, 59);

    fill(20, 18, 20, 170);
    rect(width - 312, 24, 288, 58, 14);
    textAlign(CENTER, CENTER);
    fill(255);
    textSize(15);
    text("← → / A・D：レーン移動　R：中央へ", width - 168, 53);

    hint(ENABLE_DEPTH_TEST);
  }
}
