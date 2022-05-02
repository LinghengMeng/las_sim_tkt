/*TODO
 - Lifespans
 - Coherent (modelled?) vector fields
 - OSC
 
 */

import peasy.*;
import oscP5.*;
import netP5.*;

PeasyCam cam;

OscP5 oscar;
NetAddress myRemoteLocation;

FlowVectorSystem flowVectorSystem;
FlowParticleSystem flowParticleSystem;

//Show Particles
Boolean showFlowParticles = true;
Boolean showParticleOrientation = true;

//Show Vector Field
Boolean showVectorField = true;
Boolean showNearestVecLines = true;

void setup() {
  size(800, 800, P3D);

  cam = new PeasyCam(this, width/2, height/2, 0, 700);

  oscar = new OscP5(this, 4000);
  myRemoteLocation = new NetAddress("127.0.0.1", 4001);

  background(200);
  sphereDetail(3);

  flowVectorSystem = new FlowVectorSystem();
  flowParticleSystem = new FlowParticleSystem();
}

void draw() {  
  background(200);

  pushMatrix();
  translate(width/2, height/2); 
  flowVectorSystem.run();
  flowParticleSystem.run();
  popMatrix();

  //cam.reset();

  //fill(0);
  //text(frameRate, 20, 20);
}
