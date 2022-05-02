void display() {
  //display framerate when beneath a threshold
  popMatrix();
  textAlign(LEFT);
  textSize(14);
  if (frameRate<55) {
    fill(255, 0, 0);
    text(int(frameRate), 30, 20);
  }

  fill(255);
  text("actuator count: "+actuatorCount, 30, 50);
  text("excitor count: "+excitorCount, 30, 80);
}
