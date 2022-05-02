class SphereUnit {

  PVector location, locationPix;
  int index;
  String id;
  PVector[] vertexLocations, vertexLocationsPix;
  float radius;

  SphereUnit(int _index, String _id, PVector _location) {
    index = _index;
    id = _id;
    location = _location;
    radius = 0.3;
    vertexLocations = new PVector[sphereUnitVertexCount];

    for (int i=0; i<sphereUnitVertexCount; i++) { 
      vertexLocations[i] = new PVector();
      vertexLocations[i] = polygonVertexPoint(sphereUnitVertexCount, radius, radius, i);
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
    for (int i=0; i<sphereUnitVertexCount; i++) {
      vertex(vertexLocationsPix[i].x, vertexLocationsPix[i].y);
    }
    endShape(CLOSE);
    fill(255);
    textAlign(CENTER, CENTER);
    text(id, locationPix.x, locationPix.y);
  }
}


class SphereUnitSystem {

  PVector[] sphereUnitLocations;

  SphereUnitSystem() {
    sphereUnitLocations = new PVector[sphereUnitInfo.length];
    for (int i=0; i<sphereUnitInfo.length; i++) {
      String id = str(int(sphereUnitInfo[i][0]))+"-"+str(int(sphereUnitInfo[i][1]));
      PVector location = new PVector(sphereUnitInfo[i][2], sphereUnitInfo[i][4]);
      sphereUnit[i] = new SphereUnit(i, id, location);
    }
  }
}
