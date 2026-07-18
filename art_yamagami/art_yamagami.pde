void setup() {
  size(600, 600);
  frameRate(20);
}
void draw() {
  int r=50;
  ellipse(mouseX, mouseY, r, r);
}
void mousePressed() {
  if (mouseButton==LEFT) {
    fill(random(255), random(255), random(255));
  }
}
