class Excitor {

  PVector location, locationPix, velocity, acceleration, force;
  float threshold, curvature, speedLimit, mass, lifespan;

  Excitor(PVector _location) {
    location = _location.copy();
    velocity = new PVector();
    acceleration = new PVector();
    mass = random(1);
    threshold = 1;
    curvature = 1;
    speedLimit = 3;
    lifespan = 255;
  }

  void run() {   
    update();
    applyAtrractorForce();
    excite();
    checkEdges();
    if (showExcitors) display();
  }

  void update() {   
    velocity.add(acceleration);
    velocity.limit(speedLimit);
    location.add(velocity);
    locationPix = convertVectorToPixelSpace(location);
    acceleration.mult(0);
    lifespan -= 0.5;
  }

  void applyAtrractorForce() {
    for (int i=0; i<attractor.length; i++) {
      PVector force = attractor[i].location.copy();
      force.sub(location);
      force.normalize();
      force.mult(attractorForce);
      applyForce(force);
    }
  }

  void display() {
    stroke(lifespan, 50);
    noFill();
    ellipse(locationPix.x, locationPix.y, threshold*200, threshold*200);

    textAlign(CENTER, CENTER);
    textSize(14);
    fill(255);
  }

  void excite() {
    for (int i=0; i<actuatorSystem.actuators.size(); i++) {
      float distance = location.dist(actuatorSystem.actuators.get(i).location);
      if (distance <= threshold) actuatorSystem.actuators.get(i).intensity += pow(1 - (distance/threshold), curvature) * 0.1;// (lifespan/255);
    }
  }

  void applyForce(PVector _force) {
    PVector force = _force.copy();
    force.mult(mass+0.5);
    acceleration.add(force);
  }  
  void checkEdges() {
    if (locationPix.x < -(width/2)) locationPix.x = width/2;
    if (locationPix.x > width/2) locationPix.x = -(width/2);
    if (locationPix.y < -(height/2)) locationPix.y = height/2;
    if (locationPix.y > height/2) locationPix.y = -(height/2);
  }

  boolean isDead() {
    if (lifespan < 0.0) {
      return true;
    } else {
      return false;
    }
  }
}



class ExcitorSystem {

  ArrayList<Excitor> excitors;
  PVector origin;

  ExcitorSystem() {
    excitors = new ArrayList<Excitor>();
  }

  void addExcitor(PVector _location) {
    excitors.add(new Excitor(_location));
    excitorCount += 1;
  }

  void run() {
    Iterator<Excitor> it = excitors.iterator();
    while (it.hasNext()) {
      Excitor e = it.next();
      e.run();
      if (e.isDead()) {
        it.remove();
        excitorCount -= 1;
      }
    }
  }
}
