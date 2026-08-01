// ============================================================
// エリアごとの背景(空と遠景)。
//
// これまで空は単色で塗るだけだったので、どのエリアも同じ場所に見えていた。
// 沖縄なら南国の海、北海道なら雪山、というように
// 「いまどこを走っているか」を背景で伝えるための層。
//
// 【固定背景】プレイヤーから一定の距離に置いて追従させる。
// つまり近づかないし、横にも流れない。遠くの景色はそう見えるのが自然。
//
// 【なぜ2Dで貼らずに3D空間へ置くのか】
// 画面に直接貼ると、地平線の位置を自分で計算して合わせる必要がある。
// しかもこのゲームは速度とエナジードリンクで画角が変わるので、
// そのたびに地平線の位置がずれて、合わせ直しが要る。
//
// 3Dの世界に「地平線が y=0 に来るように」板を1枚置けば、
// あとは Processing が勝手に正しい位置へ描いてくれる。画角が変わっても合う。
//
// 【水平線の位置は画像ごとに違う】
// 沖縄は画像の53%が空、北海道は86%が空、というように構図がバラバラ。
// Regions.pde の .skyAt(...) でその割合を指定している。
// ============================================================

class Sky {

  void draw(Game g) {
    if (!USE_IMAGES || assets.skies == null) return;

    PImage img = assets.skies[g.regionIndex];
    if (img == null) return;   // 背景が無いエリアは単色の空のまま。落とさない

    float f = regions[g.regionIndex].skyHorizon;   // 画像の上端から水平線までの割合

    // 水平線が地面(y=0)に重なるように、板の上下位置を決める。
    // 上に f、下に (1-f) の割合で伸ばせば、水平線がちょうど 0 に来る。
    float yTop    =  f * SKY_HEIGHT;
    float yBottom = -(1 - f) * SKY_HEIGHT;
    float halfW   = SKY_HEIGHT * img.width / img.height * 0.5;

    float z = g.z + SKY_DIST;

    noLights();     // 照明を掛けると背景の色が濁る
    noStroke();
    tint(255);

    beginShape(QUAD);
    texture(img);
    // UV は既定の IMAGE モードなのでピクセル単位。画像の上端が板の上に来る
    vertex(g.x - halfW, yTop,    z, 0,         0);
    vertex(g.x + halfW, yTop,    z, img.width, 0);
    vertex(g.x + halfW, yBottom, z, img.width, img.height);
    vertex(g.x - halfW, yBottom, z, 0,         img.height);
    endShape();

    noTint();
    // 照明を戻す。戻し忘れると、この後に描く地面や食べ物が真っ黒になる。
    view.applySceneLights();
  }
}
