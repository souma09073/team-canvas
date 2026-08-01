// ============================================================
// 画像を「指定した枠にぴったり」描くための道具。
//
// 【なぜ要るのか】
// 生成した素材は、絵の周りに透明な余白がついている。しかもその量が素材ごとに違う。
//   ボタン       余白 59%(上下に大きく空いている)
//   縦ゲージ     余白 94%(棒が真ん中に細く1本あるだけ)
//   フェリー     余白 50%
//   マンジャロ   余白 27%
//
// これを image() でそのまま貼ると、余白のぶん絵が小さくなり、
// 素材によって縮み方が違うので大きさも位置も揃わない。
//
// ここでは「絵が実際に描かれている範囲」を1回だけ測って覚えておき、
// その範囲だけを指定の枠へ引き伸ばす。素材を差し替えても位置がズレない。
// ============================================================

class Sprites {

  // 画像 → 絵が描かれている範囲 [x1, y1, x2, y2]
  // 初めて描くときに測って、以降は使い回す。
  HashMap<PImage, int[]> bounds = new HashMap<PImage, int[]>();

  // 絵の部分を (x, y, w, h) の枠いっぱいに描く。
  // 枠と絵の縦横比が違うと引き伸ばされるので、比は呼ぶ側で合わせること。
  void draw(PImage img, float x, float y, float w, float h) {
    draw(img, x, y, w, h, 255);
  }

  void draw(PImage img, float x, float y, float w, float h, float alpha) {
    if (img == null) return;
    int[] b = boundsOf(img);

    imageMode(CORNER);
    tint(255, alpha);
    // 転送元を「絵のある範囲」に限定する。これが余白を無視する仕組み。
    image(img, x, y, w, h, b[0], b[1], b[2], b[3]);
    noTint();
  }

  // 高さだけ決めて、横幅は絵の縦横比から求める。
  // 中央揃えで置きたいときに使う。
  void drawCenteredByHeight(PImage img, float cx, float y, float h) {
    drawCenteredByHeight(img, cx, y, h, 255);
  }

  void drawCenteredByHeight(PImage img, float cx, float y, float h, float alpha) {
    if (img == null) return;
    int[] b = boundsOf(img);
    float w = h * (b[2] - b[0]) / float(b[3] - b[1]);
    draw(img, cx - w * 0.5, y, w, h, alpha);
  }

  // 幅だけ決めて、高さは絵の縦横比から求める。上下中央揃え。
  void drawCenteredByWidth(PImage img, float cx, float cy, float w) {
    if (img == null) return;
    int[] b = boundsOf(img);
    float h = w * (b[3] - b[1]) / float(b[2] - b[0]);
    draw(img, cx - w * 0.5, cy - h * 0.5, w, h);
  }

  // ---- 絵のある範囲を測る ----

  int[] boundsOf(PImage img) {
    int[] cached = bounds.get(img);
    if (cached != null) return cached;

    int[] b = measure(img);
    bounds.put(img, b);
    return b;
  }

  // 透明でない画素の範囲を調べる。
  // 全画素を見ると重いので間引いている。余白の判定に精度は要らない。
  int[] measure(PImage img) {
    img.loadPixels();

    int x1 = img.width, y1 = img.height, x2 = 0, y2 = 0;
    int step = max(1, img.width / 300);   // 大きい画像ほど粗く見る

    for (int y = 0; y < img.height; y += step) {
      for (int x = 0; x < img.width; x += step) {
        if (alpha(img.pixels[y * img.width + x]) <= 8) continue;
        if (x < x1) x1 = x;
        if (x > x2) x2 = x;
        if (y < y1) y1 = y;
        if (y > y2) y2 = y;
      }
    }

    // 全部透明だった場合は画像全体を返す。0除算を防ぐため
    if (x2 <= x1 || y2 <= y1) return new int[] { 0, 0, img.width, img.height };

    // 間引いたぶん端が欠けるので、少しだけ広げておく
    x1 = max(0, x1 - step);
    y1 = max(0, y1 - step);
    x2 = min(img.width,  x2 + step);
    y2 = min(img.height, y2 + step);
    return new int[] { x1, y1, x2, y2 };
  }
}
