class Actuator {

  PVector location, locationPix;
  int index;
  float intensity, intensityRelease;
  boolean showText = true;

  Actuator(int _index, PVector _location) {
    index = _index+1;
    location = _location;
    intensityRelease = 0.01;
  }

  void run() {
    applyIntensity();
    display();
  }

  void applyIntensity() {
    if (intensity>1) intensity = 1;
    locationPix = convertVectorToPixelSpace(location);
    intensity *= masterIntensity;
    intensity -= intensityRelease;
    if (intensity<0) intensity = 0;
  }

  void display() {
    if (showActuators) {
      noStroke();
      fill(intensity*200+55, 150);
      ellipse(locationPix.x, locationPix.y, 25, 25);
    }

    if (showText) {
      fill(255);
      textAlign(CENTER, CENTER);
      textSize(10);
      text(index, locationPix.x, locationPix.y);
    }
  }
}


class ActuatorSystem {

  ArrayList<Actuator> actuators;

  ActuatorSystem() {
    actuators = new ArrayList<Actuator>();
  }

  void addActuator(int _index, PVector _location) {
    actuators.add(new Actuator(_index, _location));
    actuatorCount += 1;
  }

  void run() {
    Iterator<Actuator> it = actuators.iterator();
    while (it.hasNext()) {
      Actuator a = it.next();
      a.run();
    }
  }
}
