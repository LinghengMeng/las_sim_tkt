

void initOscIn() {


  //From Max Patch
  oscar.plug(this, "setExcitorCurvature", "/setExcitorCurvature");
  oscar.plug(this, "setExcitorThresholds", "/setExcitorThresholds");
  oscar.plug(this, "setExcitorMasterIntensity", "/setExcitorMasterIntensity");
  oscar.plug(this, "setAttractorForce", "/setAttractorForce");
  oscar.plug(this, "setAttractorLocations", "/setAttractorLocations");

  //From Sensors
  oscar.plug(this, "IRvalueCentre", "/4D/SENSOR/CENTRE");
  oscar.plug(this, "IRvalueCorner", "/4D/SENSOR/CORNER");
}

void setExcitorCurvature(float v) {
  for (int i=0; i<excitor.length; i++) {
    excitor[i].curvature = v;
  }
}

void setExcitorThresholds(int[] thresholds) {
  for (int i=0; i<excitor.length; i++) {
    excitor[i].threshold = thresholds[i];
  }
}

void setExcitorMasterIntensity(float v) {
  masterIntensity = v;
}

void setAttractorForce(float v) {
  attractorForce = v;
}

void setAttractorLocations(int[] locations) {
  for (int i=0; i<attractor.length; i++) {
    attractor[i].location.x = locations[i*2]*100;
    attractor[i].location.y = (locations[i*2]+1)*100;
  }
}

void IRvalueCorner(int v) {
  println("IRvalueCorner: "+v);
  if (v>400) {
    if (gate) sensor[2].trigger();
    gate = false;
  } else { 
    gate = true;
  }
}
