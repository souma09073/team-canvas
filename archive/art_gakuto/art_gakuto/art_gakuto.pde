void setup(){
  size(600,400);
  background(255);
}

void draw(){
  fill(random(255),random(255),random(255),100);
  noStroke();
  ellipse(mouseX,mouseY,40,30);
}
