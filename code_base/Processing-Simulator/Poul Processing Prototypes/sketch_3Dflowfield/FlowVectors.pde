class FlowVectorSystem {

  PVector loc;
  ArrayList<FlowVector> flowVectors;
  float dim, spacing;

  FlowVectorSystem() {

    flowVectors = new ArrayList<FlowVector>();
    
    //dim = 4;
    //spacing = 1/(dim-1);
    //if (dim==1) spacing = 1; 

    //for (int x=0; x<dim; x++) {
    //  for (int y=0; y<dim; y++) {
    //    for (int z=0; z<dim; z++) {
    //      PVector newFlowVecLoc = new PVector(spacing*x, spacing*y, spacing*z);
    //      if (dim!=1) {
    //        newFlowVecLoc.sub(0.5, 0.5, 0.5);
    //        newFlowVecLoc.mult(400);
    //      }

    //      flowVectors.add(new FlowVector(newFlowVecLoc));
    //    }
    //  }
    //}
    
    for (int i=0; i<100; i++) {
      flowVectors.add(new FlowVector(PVector.random3D().mult(300)));
    }
  }

  void run() {
    for (int i=0; i<flowVectors.size(); i++) {
      flowVectors.get(i).run();
    }
  }
}


class FlowVector {

  PVector loc, rot, clr;
  float nxoff, nyoff, nzoff, inc;
  int displayAlpha;
  

  FlowVector(PVector _loc) {
    
    clr = new PVector(0,0,0);
    displayAlpha = 150;

    loc = _loc.copy();
    rot = new PVector(0, 0, 0);

    nxoff = loc.x * 0.05;
    nyoff = loc.y * 0.05;
    nzoff = loc.z * 0.05;
    inc = 0.01;
  }

  void run() {
    orientate();
    if (showVectorField) display();
  }

  void orientate() {
    rot = new PVector(noise(nxoff), noise(nyoff), noise(nzoff));
    rot.sub(0.5, 0.5, 0.5).mult(2);
    //rot = new loc.copy().mult(-1); // ALL INWARDS
    //rot = new loc.copy(); // ALL OUTWARDS
    
    float squareIntensity = 0.1;

    if (loc.x<=0 && loc.z<=0) {
      rot.add(new PVector(1, 0, 0).mult(squareIntensity));
      //clr = new PVector(255,0,0);
    }
    if (loc.x>0 && loc.z<=0) {
      rot.add(new PVector(0, 0, 1).mult(squareIntensity));
      //clr = new PVector(0,255,0);
    }
    if (loc.x<=0 && loc.z>0) {
      rot.add(new PVector(0, 0, -1).mult(squareIntensity));
      //clr = new PVector(0,0,255);
    }
    if (loc.x>0 && loc.z>0) {
      rot.add(new PVector(-1, 0, 0).mult(squareIntensity));
      //clr = new PVector(255,0,255);
    }

    nxoff += inc;
    nyoff += inc;
    nzoff += inc;
  }

  void display() {
    pushMatrix();
    translate(loc.x, loc.y, loc.z);

    PVector clr = rot.copy().normalize().mult(255);
    stroke(clr.x, clr.y, clr.z, displayAlpha);
    strokeWeight(1);
    fill(clr.x, clr.y, clr.z, displayAlpha);
    //sphere(2);

    stroke(clr.x, clr.y, clr.z, displayAlpha);
    strokeWeight(1);

    PVector end = rot.copy().normalize().mult(10);
    line(0, 0, 0, end.x, end.y, end.z);
    popMatrix();
  }
}
