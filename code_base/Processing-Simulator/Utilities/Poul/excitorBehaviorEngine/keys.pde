boolean rGate = false;

void keyReleased() {
  rGate = false;
}

void keyPressed() {
  if (!rGate && key=='r') {
    rGate = true;
    for (int i=0; i<attractor.length; i++) {
      attractor[i].location.x = random(width)-width/2;
      attractor[i].location.y = random(height)-height/2;
    }
  }

  if (key=='e') {
    if (showExcitors) {
      showExcitors = false;
    } else { 
      showExcitors = true;
    }
  }

  if (key=='a') {
    if (showAttractors) {
      showAttractors = false;
    } else { 
      showAttractors = true;
    }
  }

  if (key=='A') {
    if (showActuators) {
      showActuators = false;
    } else { 
      showActuators = true;
    }
  }

  if (key=='s') {
    if (showAttractorShape) {
      showAttractorShape = false;
    } else { 
      showAttractorShape = true;
    }
  }

  switch(key) {
  case '1':
    sensor[0].trigger();
    break;
  case '2':
    sensor[1].trigger();
    break;
  case '3':
    sensor[2].trigger();
    break;
  case '4':
    sensor[3].trigger();
    break;
  case '5':
    sensor[4].trigger();
    break;
  case '6':
    sensor[5].trigger();
    break;
  case '7':
    sensor[6].trigger();
    break;
  }
}
