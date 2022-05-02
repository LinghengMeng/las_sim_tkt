class Attractor {

  PVector location, locationPix, mouse;
  int size;
  Boolean dragged, show;

  Attractor(PVector _location) {
    location = _location;
    size = 20;
    dragged = false;
  }

  void run() {
    mouse = new PVector(mouseX-width/2, mouseY-height/2);
    dragged();
    if (showAttractors) display();
  }

  void display() {
    if (dragged) {
      location = mouse.copy().mult(0.01);
    }
    locationPix = convertVectorToPixelSpace(location);
    stroke(0, 255, 0);
    noFill();
    if (dragged) fill(0, 255, 0);
    ellipse(locationPix.x, locationPix.y, size, size);
  }

  // void dragged() {   
  //   if (!dragged && mousePressed && locationPix.dist(mouse)<=size/2) {
  //     dragged = true;
  //   } else { 
  //     if (!mousePressed) dragged = false;
  //   }
  // }
}


class AttractorSystem {

  AttractorSystem() {
    for (int i=0; i<attractorCount; i++) {
      attractor[i] = new Attractor(new PVector(random(8)-4, random(4)-2));
    }
  }

  void display() {
    if (showAttractorShape) {
      for (int i=0; i<attractorCount; i++) {
        attractor[i].run();
      }
      noStroke();
      fill(255, 50);
      beginShape();
      for (int i=0; i<attractor.length; i++) {
        vertex(attractor[i].locationPix.x, attractor[i].locationPix.y);
      }
      endShape(OPEN);
    }
  }
}
