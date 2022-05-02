class SphereRSUnit {

  PVector location, locationPix;
  int index;
  String id;
  PVector[] vertexLocations, vertexLocationsPix;
  float radius;
  float rs_radius;

  SphereRSUnit(int _index, String _id, PVector _location) {
    index = _index;
    id = _id;
    location = _location;
    radius = 0.2;
    rs_radius = 0.4;
    vertexLocations = new PVector[sphereRSUnitVertexCount];

    for (int i=0; i<sphereRSUnitVertexCount; i++) { 
      vertexLocations[i] = new PVector();
      vertexLocations[i] = polygonRSVertexPoint(sphereRSUnitVertexCount, rs_radius, rs_radius, i);
      vertexLocations[i].add(location);
      actuatorSystem.addActuator(actuatorSystem.actuators.size(), vertexLocations[i]);
    }

    locationPix = convertVectorToPixelSpace(location);
    vertexLocationsPix = convertVectorToPixelSpaceArray(vertexLocations);
  }

  void run() {
    display();
  }

  void display() {
    noFill();
    stroke(100);
    beginShape();
    for (int i=0; i<sphereRSUnitVertexCount; i++) {
      vertex(vertexLocationsPix[i].x, vertexLocationsPix[i].y);
    }
    endShape(CLOSE);
    fill(255);
    textAlign(CENTER, CENTER);
    text(id, locationPix.x, locationPix.y);
  }
}


class SphereRSUnitSystem {

  PVector[] sphereRSUnitLocations;

  SphereRSUnitSystem() {
    sphereRSUnitLocations = new PVector[sphereRSUnitInfo.length];
    for (int i=0; i<sphereRSUnitInfo.length; i++) {
      String id = str(int(sphereRSUnitInfo[i][0]))+"-"+str(int(sphereRSUnitInfo[i][1]));
      PVector location = new PVector(sphereRSUnitInfo[i][2], sphereRSUnitInfo[i][4]);
      sphereRSUnit[i] = new SphereRSUnit(i, id, location);
    }
  }
}
