import oscP5.*;
import netP5.*;
import peasy.*;
import java.util.Iterator;

PeasyCam cam;

OscP5 oscar;
NetAddress FOUR_D_ENGINE;
NetAddress MASTER_LAPTOP;
NetAddress MAX_PATCH;

boolean use_processing_control = true;

int symposiumUnitVertexCount = 4;
int sphereUnitVertexCount = 6;
int sphereRSUnitVertexCount = 6;
int actuatorCount = 0;
int excitorCount = 0;
int attractorCount = 3;
int sensorCount = 7;

float attractorForce = 0.001;
boolean showExcitors = true;
boolean showAttractors = true;
boolean showActuators = true;
boolean showAttractorShape = true;


float masterIntensity = 1;

PVector origin = new PVector(0, 0);

boolean gate = true;

// Symposium Unit Info: {   }
float symposiumUnitInfo[][] = {
     { 1, 1, -2.5,  1, 0 },
     { 2, 1, -1.5,  1, 0 },
     { 3, 1, -0.5,  1, 0 },
     { 4, 1,  0.5,  1, 0 }    //,
//   { 5, 1,  1.5,  1, 0 },
 //  { 5, 2,  1.5,  1, 0 },
  // { 5, 3,  1,5,  1, 0 } 
};

//Sphere Unit Info: { Triad, Unit, posX, posY, posZ }
float sphereUnitInfo[][] = { // };
  {  5, 3, 2.25, 2.2, 0.2  }, 
  {  5, 2, 2.45, 2.4,  1  }, 
  {  5, 1, 2.25, 2.2,  1.8  }
};

//Sphere Rebel Star Unit Info: { Triad, Unit, posX, posY, posZ }
float sphereRSUnitInfo[][] = { // };
  {  5, 3, 2.25, 2.2, 0.2  }, 
  {  5, 2, 2.45, 2.4,  1  }, 
  {  5, 1, 2.25, 2.2,  1.8  }
};



SymposiumUnit[] symposiumUnit = new SymposiumUnit[symposiumUnitInfo.length];
SphereUnit[] sphereUnit = new SphereUnit[sphereUnitInfo.length];
SphereRSUnit[] sphereRSUnit = new SphereRSUnit[sphereRSUnitInfo.length];
Excitor[] excitor = new Excitor[excitorCount];
Attractor[] attractor = new Attractor[attractorCount];
ExcitorSystem excitorSystem;
Sensor[] sensor = new Sensor[sensorCount];
SensorSystem sensorSystem;
SphereUnitSystem sphereUnitSystem;
SymposiumUnitSystem symposiumUnitSystem;
SphereRSUnitSystem sphereRSUnitSystem;
AttractorSystem attractorSystem;
ActuatorSystem actuatorSystem;


void setup() {
  //fullScreen(P3D);
  size(1200, 600, P3D);

  frameRate(60);

  // cam = new PeasyCam(this, width/2, height/2, 0, 800);

  oscar = new OscP5(this, 3000); //listen port
  FOUR_D_ENGINE = new NetAddress("127.0.0.1", 2000);
  MASTER_LAPTOP = new NetAddress("172.23.0.62", 3001);  //   ("192.168.2.79", 3001);
  MAX_PATCH = new NetAddress("127.0.0.1", 4000);
  //FOUR_D_ENGINE = new NetAddress("10.14.4.134", 2000);
  //MASTER_LAPTOP = new NetAddress("10.14.4.163", 3001);

  actuatorSystem = new ActuatorSystem();
  excitorSystem = new ExcitorSystem();
  sensorSystem = new SensorSystem(new PVector(1, 1), sensorCount, 4, 2);
  symposiumUnitSystem = new SymposiumUnitSystem();
  sphereUnitSystem = new SphereUnitSystem();
  sphereRSUnitSystem = new SphereRSUnitSystem();
  attractorSystem = new AttractorSystem();

  //for (int i=0; i<21; i++) {
  //  actuatorSystem.addActuator(actuatorSystem.actuators.size(), new PVector(random(16)-8, random(8)-4));
  //}

  initOscIn();
}


void draw() {
  background(25);

  pushMatrix();
  translate(width/2, height/2);

  sensorSystem.display();
  attractorSystem.display();

  for (int i=0; i<attractor.length; i++) {
    attractor[i].run();
  }

  excitorSystem.run();
  actuatorSystem.run();

  for (int i=0; i<sphereUnit.length; i++) {
    sphereUnit[i].run();
  }
  
  for (int i=0; i<symposiumUnit.length; i++) {
    symposiumUnit[i].run();
  }
  
  for (int i=0; i<sphereRSUnit.length; i++)  {
     sphereRSUnit[i].run(); 
  }
  
  if (use_processing_control) {
    oscOut_processing();  //  < ---- for Farhan's new Processing control code
  } else {
    oscOut_python();        // < ----- for Adam's python code
  }
  display();
}
