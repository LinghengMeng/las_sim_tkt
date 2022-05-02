class SymposiumUnit {

  PVector location, locationPix;
  int index;
  String id;
  PVector[] vertexLocations, vertexLocationsPix;
  float radius;
  float rowlength;
  float spacing;

  SymposiumUnit(int _index, String _id, PVector _location) {
    index = _index;
    id = _id;
    location = _location;
    radius = 0.3;
    rowlength = 2.0;
    spacing = 1.0;
    vertexLocations = new PVector[symposiumUnitVertexCount];

    for (int i=0; i<symposiumUnitVertexCount; i++) { 
      vertexLocations[i] = new PVector();
      vertexLocations[i] = symposiumVertexPoint(symposiumUnitVertexCount, rowlength, spacing, i);
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
    for (int i=0; i<symposiumUnitVertexCount; i++) {
      vertex(vertexLocationsPix[i].x, vertexLocationsPix[i].y);
    }
    endShape(CLOSE);
    fill(255);
    textAlign(CENTER, CENTER);
    text(id, locationPix.x, locationPix.y);
  }
}


class SymposiumUnitSystem {

  PVector[] symposiumUnitLocations;

  SymposiumUnitSystem() {
    symposiumUnitLocations = new PVector[symposiumUnitInfo.length];
    for (int i=0; i<symposiumUnitInfo.length; i++) {
      String id = str(int(symposiumUnitInfo[i][0]))+"-"+str(int(symposiumUnitInfo[i][1]));
      PVector location = new PVector(symposiumUnitInfo[i][2], symposiumUnitInfo[i][4]);
      symposiumUnit[i] = new SymposiumUnit(i, id, location);
    }
  }
}
