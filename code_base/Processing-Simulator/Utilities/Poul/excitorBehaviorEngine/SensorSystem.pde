class Sensor {

  PVector location;
  float intensity;
  int index, fillAlpha, t;

  Sensor(int _index, PVector _location) {
    index = _index;
    location = _location.copy();
    intensity = 1;
    fillAlpha = 0;
  }

  void run() {
    if ((millis()-t) < 100) {
      fillAlpha = 255;
    } else {
      fillAlpha = 0;
    }

    fill(255, 0, 0, fillAlpha);
    stroke(intensity*200+50, 0, 0);
    PVector locationPix = convertVectorToPixelSpace(location);
    ellipse(locationPix.x, locationPix.y, 30, 30);
    textAlign(CENTER, CENTER);
    fill(255);
    textSize(14);
    text(index+1, locationPix.x, locationPix.y);
  }

  void trigger() {
    excitorSystem.addExcitor(sensorSystem.sensorLocations[index]);
    t = millis();
  }
}



class SensorSystem {

  PVector[] sensorLocations;

  SensorSystem(PVector _location, int _sensorCount, int _dimX, int _dimY) {
    sensorLocations = polygon(_sensorCount, _dimX, _dimY);
    for (int i=0; i<sensorCount; i++) {
      sensorLocations[i] = sensorLocations[i].add(_location);
      sensor[i] = new Sensor(i, sensorLocations[i]);
    }
  }

  void display() {
    for (int i=0; i<sensorCount; i++) {
      sensor[i].run();
    }
  }
}
