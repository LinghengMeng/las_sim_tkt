class FlowParticleSystem {

  PVector loc, dir;
  ArrayList<FlowParticle> flowParticles;
  int particleCount;

  FlowParticleSystem() {

    flowParticles = new ArrayList<FlowParticle>();  
    particleCount = 522;

    for (int i=0; i<particleCount; i++) {
      flowParticles.add(new FlowParticle());
    }
  }

  void run() {
    for (int i=0; i<particleCount; i++) {
      flowParticles.get(i).run();
    }
  }
}



class FlowParticle {

  PVector loc, vel, acc;
  float maxSpeed;
  int nearestFlowVec;

  FlowParticle() {

    loc = PVector.random3D().mult(300);
    vel = PVector.random3D().mult(0);
    acc = new PVector();    
    maxSpeed = 2;
    nearestFlowVec = 0;
  }

  void run() {
    update();
    edges();
    findNearestFlowVector();
    followFlow();
    snapToEdge();
    if (showFlowParticles) display();
  }

  void update() {
    vel.add(acc);
    vel.limit(maxSpeed);
    loc.add(vel);
    acc.mult(0);
  }

  void edges() {
    //if (loc.mag() > 250) loc = PVector.random3D().mult(250);
    if (loc.mag() > 350) loc.mult(-0.4);
  }

  void findNearestFlowVector() {
    float dist = 0;
    float shortestDist = 99999;
    for (int i=0; i<flowVectorSystem.flowVectors.size(); i++) {
      dist = loc.dist(flowVectorSystem.flowVectors.get(i).loc);
      if (dist<shortestDist) {
        nearestFlowVec = i;
        shortestDist = dist;
      }
    }
  }

  void followFlow() {
    applyForce(flowVectorSystem.flowVectors.get(nearestFlowVec).rot);
  }

  void applyForce(PVector _force) {
    float frict = random(0.4);
    acc.add(_force.mult(1.0 - frict));
  }

  void snapToEdge() {
    loc = loc.normalize().mult(300);
  }

  void display() {
    pushMatrix();
    translate(loc.x, loc.y, loc.z);

    stroke(0);
    strokeWeight(1);
    fill(200);
    sphere(3);

    if (showParticleOrientation) {
      PVector end = vel.copy().normalize().mult(5);
      stroke(100);
      strokeWeight(1);
      line(0, 0, 0, end.x, end.y, end.z);
    }
    popMatrix();

    if (showNearestVecLines) {
      stroke(100, 100, 255, 50);
      strokeWeight(1);
      line(loc.x, loc.y, loc.z, 
        flowVectorSystem.flowVectors.get(nearestFlowVec).loc.x, 
        flowVectorSystem.flowVectors.get(nearestFlowVec).loc.y, 
        flowVectorSystem.flowVectors.get(nearestFlowVec).loc.z);
    }
  }
}
