

/*

 if (gridEyePresence>x) generate excitor in center that flies away
 > Amount of presence determines lifespan
 
 */

 class ExcBehavVars extends BehaviourEngineVars {

  float excitorSpeedLimit, fadeAt, attractorAngleSpeed, forceScalar, attractorOpacity, coreSize, triggerTimeLimit, masterIntensity;
  int bgHowOften;
  float bgHowRandom;
  boolean excitorsInfluenceActive;
  boolean showExcitors;
  boolean backgroundBehaviourEnabled;
  boolean showAttractors, showCore;
  int attractorCount;
  int maxExcitorAmount, excitor_update_rate, lifespan, size;
  int sizeLimit = 2000;

  transient Patchable excPatchable;
  transient boolean triggerExcitorNow = false;

   ExcBehavVars() {
     super("Excitors", false);
   }

   void init() {  
    neverSave = false;

    attractorAngleSpeed = 0.2;
    excitorSpeedLimit = .6;
    masterIntensity = 1f;
    forceScalar = 1;
    excitorsInfluenceActive = true;      
    backgroundBehaviourEnabled = true;
    maxExcitorAmount = 25;
    triggerTimeLimit = 500;

    bgHowOften = 5000;
    bgHowRandom = 0.0;


    lifespan = 20000;
    fadeAt = 0.75;
    size = 500;
    coreSize = 0.80;
    showCore = false;

    showExcitors = true;
    showAttractors = true;
    attractorCount = 6;
    attractorOpacity = 0.5;

    triggerExcitorNow = false;

    

   }


   // overloaded for excitor-specific functions.  Also calls super() to catch generic ones like revealPatcher.
  
   void executeDatCommand(String command, String value) {
     
      super.executeDatCommand(command, value);

      println(behaviourName + " Got a command: " +command+ " | " + value);

      switch(command) {
        case "triggerExcitor":
            triggerExcitorNow = true;
        break;
      }
   }


        

}




class ExcitorBehaviour extends Thread {

  //Functionality & Visualization bools
  boolean showAttractors = false;
  boolean wavTriggerEnabled = true;


  //Internal Comms ArrayLists
  // ArrayList<Float> actuatorInfluences = new ArrayList<Float>(numActuators);

  HashMap<String, PVector> relevantActuators = new HashMap<String, PVector>();  // determined at startup by using name filtering - eg. only DRs, or just part of the sculpture
  HashMap<String, Float>   actuatorInfluences = new HashMap<String, Float>();       // this will have the same keys as relevantActuators:  <node_id>:<device> eg: 322345:MO3


  //Grid Eye Interaction
  boolean grideyesProduceExcitors = false;
  boolean grideyesProduceWAV = true;
  boolean excitorTriggerGateOpen = true;
  float excitorTriggerThreshold = 0.8;
  boolean wavTriggerGateOpen = true;
  float wavTriggerThreshold = 0.3;
  float gridEyePresenceMax;          //Variable for GE presence value that represents general presence in stead of per GE

  //Excitor Macro Variables
  ExcitorSystem excitorSystem;
  int totalExcitorCount = 0;
  int initialExcitorCount = 0;

  //Attractor Macro Variables
  AttractorSystem attractorSystem;
  AttractorSystem dm2Attractorsys;
  AttractorSystem dm3Attractorsys;
  AttractorSystem dm5Attractorsys;
  AttractorSystem north_river_Attractorsys_1;
  AttractorSystem north_river_Attractorsys_2;
  AttractorSystem south_river_Attractorsys_1;
  AttractorSystem south_river_Attractorsys_2;
  
  PVector north_river_attractor_pos_1 = new PVector(800, -5000, 1581.75);
  PVector north_river_attractor_pos_2 = new PVector(-2500, -6000, 1581.75);
  PVector south_river_attractor_pos_1 = new PVector(-5177, 100, 2249);
  PVector south_river_attractor_pos_2 = new PVector(-5000, 2100, 2249);

  int attractorCount = 6;
  float attractorForce = 0.2;
  float attractorSpeedLimit = 3;

  //Center Macro Variables
  float centerForce = -0.1;  //A negative value results in a repelling origin

  int lastTimeTriggered, backBehaviourLastTimeTriggered, wavTriggerLastTimeTriggered;
  
  boolean omniMasterMute;                         // (Futurium) - This overrides the volume setting to keep it off if it is true (set by GUI)
  float   omniMasterVolume, prevOmniMasterVolume; //This is a variable, controlled through the GUI, it's here to manage further OSC
  float   presenceSensitivity, prevPresenceSensitivity;
  float   sdSensitivity, prevSdSensitivity;

  PVector   offset = new PVector(0, 0, 0);

  int nextExcitorIn;

  ExcitorBehaviour() {


    // name thread:
    super("Excitor_thread");

    excitorSystem = new ExcitorSystem();

    nextExcitorIn = 5000;

    

    for (int i=0; i<initialExcitorCount; i++) {
      PVector loc = new PVector();
      loc = PVector.random3D();
      loc.mult(0); //mult 0 to start in center, mult 2000 to start outside large sphere
      // loc.mult(8000).add(nr_attractor_pos); //mult 0 to start in center, mult 2000 to start outside large sphere
      // PVector loc = new PVector(778, -5628.83, 1581.75);
      excitorSystem.addExcitor(loc, excBehavVars.size - int(random(excBehavVars.size/3)));
    }

    attractorSystem = new AttractorSystem(attractorCount, offset, 700);
    dm2Attractorsys = new AttractorSystem(attractorCount, new PVector(-690.36, -1665.32, 630.05), 300);
    dm3Attractorsys = new AttractorSystem(attractorCount, new PVector(-1735.62, -5.87, 1204.17), 300);
    dm5Attractorsys = new AttractorSystem(attractorCount, new PVector(1710.36, -491.35, 622.68), 300);
    // North River attractor
    north_river_Attractorsys_1 = new AttractorSystem(attractorCount, north_river_attractor_pos_1, 700);
    north_river_Attractorsys_2 = new AttractorSystem(attractorCount, north_river_attractor_pos_2, 700);
    // South River attractor
    south_river_Attractorsys_1 = new AttractorSystem(attractorCount, south_river_attractor_pos_1, 700);
    south_river_Attractorsys_2 = new AttractorSystem(attractorCount, south_river_attractor_pos_2, 700);

    for (int i=0; i<attractorCount; i++) {
      attractorSystem.addAttractor();
      dm2Attractorsys.addAttractor();
      dm3Attractorsys.addAttractor();
      dm5Attractorsys.addAttractor();
      north_river_Attractorsys_1.addAttractor();
      north_river_Attractorsys_2.addAttractor();
      south_river_Attractorsys_1.addAttractor();
      south_river_Attractorsys_2.addAttractor();
    }

    // only deal with relevant actuators (grotto and minis)

    relevantActuators.putAll(dl.get_actuator_coordinates_by_name("TG"));
    relevantActuators.putAll(dl.get_actuator_coordinates_by_name("MG"));
    relevantActuators.putAll(dl.get_actuator_coordinates_by_name("NR"));
    relevantActuators.putAll(dl.get_actuator_coordinates_by_name("SR"));

    // for (int i=0; i<actuatorLocations.size(); i++) {
    //   actuatorInfluences.add(0.);
    // }

    prevOmniMasterVolume = -1;

    if(sleepmode) {
      omniMasterVolume = 0.0;
    } else {
      omniMasterVolume = show_control_vol_omni;
    }

    prevPresenceSensitivity = -1;
    presenceSensitivity = show_control_presence_sensitivity;

    prevSdSensitivity = -1;
    sdSensitivity = show_control_sd_sensitivity;

    /*
    Subscribe this behaviour to all Double Rebelstars and Moths
        (done in Control now - centralized for sleep/wake) --mg
    */
    //    subscribe_actuators_by_type("DR", "EXP", true);
    //   subscribe_actuators_by_type("MO", "EXP", true);
  }

  void run() {       // ExcitorBehaviour
    while(true) {

    try{
    Thread.sleep(excBehavVars.thread_update_rate + time_lapse_pause);
    } catch (Exception e) {
      println(e);
    }

    clearActuatorInfluences();    //clears actuatorInfluences since they are cumulative (similar to backround(color))

    attractorSystem.run();
    dm2Attractorsys.run();
    dm3Attractorsys.run();
    dm5Attractorsys.run();
    north_river_Attractorsys_1.run();
    north_river_Attractorsys_2.run();
    south_river_Attractorsys_1.run();
    south_river_Attractorsys_2.run();

    excitorSystem.run();

    if(excBehavVars.excitorsInfluenceActive) {
      control.set_actuator_excitor_influences(actuatorInfluences, "EXP");
    }

    ///  trigger an excitor right away from gui (could also take some params, like x, y, z, size, etc?) -mg
    if (excBehavVars.triggerExcitorNow && (tl_millis()-lastTimeTriggered)>excBehavVars.triggerTimeLimit) {
        PVector randLoc = PVector.random3D().mult(2500);
        excitorBehaviour.excitorSystem.addExcitor(randLoc, excBehavVars.size - int(random(excBehavVars.size/3)));
        excBehavVars.triggerExcitorNow = false;
        lastTimeTriggered = tl_millis();
    }

    ////////// BACKGROUND BEHAVIOUR ///////////////
    // Spawn Excitor at random location every X milliseconds

    if (excBehavVars.backgroundBehaviourEnabled) {
      if ((tl_millis()-backBehaviourLastTimeTriggered)>nextExcitorIn) {
        PVector randLoc = PVector.random3D().mult(2500);
        PVector north_river_randLoc_1 = PVector.random3D().mult(2500).add(north_river_attractor_pos_1);
        PVector north_river_randLoc_2 = PVector.random3D().mult(2500).add(north_river_attractor_pos_2);
        PVector south_river_randLoc_1 = PVector.random3D().mult(2500).add(south_river_attractor_pos_1);
        PVector south_river_randLoc_2 = PVector.random3D().mult(2500).add(south_river_attractor_pos_2);
        // int randSize = int(random(300)+200);
        excitorBehaviour.excitorSystem.addExcitor(randLoc, excBehavVars.size - int(random(excBehavVars.size/3)));
        excitorBehaviour.excitorSystem.addExcitor(north_river_randLoc_1, excBehavVars.size - int(random(excBehavVars.size/3)));
        excitorBehaviour.excitorSystem.addExcitor(north_river_randLoc_2, excBehavVars.size - int(random(excBehavVars.size/3)));
        excitorBehaviour.excitorSystem.addExcitor(south_river_randLoc_1, excBehavVars.size - int(random(excBehavVars.size/3)));
        excitorBehaviour.excitorSystem.addExcitor(south_river_randLoc_2, excBehavVars.size - int(random(excBehavVars.size/3)));

        backBehaviourLastTimeTriggered = tl_millis();
        nextExcitorIn = int(random(max(0.5, (1.0-excBehavVars.bgHowRandom) * excBehavVars.bgHowOften), excBehavVars.bgHowOften));
        // println("Next excitor will be in " + nf((nextExcitorIn / 1000f), 0,2) + " seconds.");
      }
    }
  
    }
  }

  synchronized public void clearActuatorInfluences() {
    try {
      for(Map.Entry<String, PVector> e : relevantActuators.entrySet()) {
                actuatorInfluences.put(e.getKey(), 0.0);
      }
    } catch (Exception x) {
      println(x);
    }
  } 

  synchronized public void display() {         // ExcitorBehaviour

    attractorSystem.display();
    dm2Attractorsys.display();
    dm3Attractorsys.display();
    dm5Attractorsys.display();
    north_river_Attractorsys_1.display();
    north_river_Attractorsys_2.display();
    south_river_Attractorsys_1.display();
    south_river_Attractorsys_2.display();

    excitorSystem.display();

  }


}




//////////////////////// EXCITOR SYSTEM ///////////////////////

class ExcitorSystem {

  ArrayList<Excitor> excitors;
  PShape excitorshapes;
  PImage excitor_sprite;

  Patchable excPatchable;

  ExcitorSystem() {
    excitor_sprite = loadImage("excitor_sprite.png");
    excitors = new ArrayList<Excitor>();
    excitorshapes = createShape(PShape.GROUP);

    excPatchable = new Patchable(this);
    excPatchable.realName = "Excitors";
    excPatchable.displayName = "Excitors";

    setPatchable();

  }

  void setPatchable() {

    // behaviour:
    excPatchable.behaviour = "Excitors";

    // input ports:
    excPatchable.dataPorts.add(new DataPort("triggerExcitorNow", "false",  0.2));
    excPatchable.dataPorts.add(new DataPort("size", str(excBehavVars.size),  0, excBehavVars.sizeLimit));
    excPatchable.dataPorts.add(new DataPort("coreSize", str(excBehavVars.coreSize),  0.0, 1.0));

    // output ports:

    // add my Patchable to the Excitor Engine's patchables hashmap.
    excBehavVars.patchables.put("Excitors", excPatchable);   

    patcher.addPatchable(excPatchable);    
    
  }

  synchronized public Excitor addExcitor(PVector _location, int _size) {
    if (excitors.size()<excBehavVars.maxExcitorAmount) {
      PVector location = _location.copy();
      
      Excitor e = new Excitor( excitorBehaviour.totalExcitorCount++ % excBehavVars.maxExcitorAmount, location, _size, excitor_sprite);
      excitorshapes.addChild(e.shape);
      excitors.add(e);
      return(e);
    } else {
      println("Excitor Behaviour: Max amount of excitors reached ("+excBehavVars.maxExcitorAmount+"), wait untill one fades out!");
      return(null);
    }
  }

  synchronized public void run() {
    Iterator<Excitor> it = excitors.iterator();
    while (it.hasNext()) {
    try {
      Excitor e = it.next();
      e.run();
      if (e.isDead()) {
        excitorshapes.removeChild(excitorshapes.getChildIndex(e.shape));
        it.remove();
      } else {
      }
      } catch(Exception e) {
          println("***");
          break;   // problem iterating -- leave while loop
      }
    }
  } 

  synchronized public void display() {
    if (excBehavVars.showExcitors) shape(excitorshapes);

    try{
      for(Excitor e : excitors) {
        e.display();
      }

    } catch(Exception x) {
        println(x);
    }

  }


}


//////////////////////// EXCITOR ///////////////////////

class Excitor extends Particle{

//  PVector location, velocity, acceleration, force;
//  float mass, size, displaySize, lifespan, presence, threshold, myBirthTime, maxBrightness;  // presence is age
  int index;
  int max_excitor_velocity = 500;    // maximum velocity for an excitor

  Excitor(int _index, PVector _position, int _size, PImage sprite) {

    super(sprite);
    shape.setVisible(true);

    index = _index;
    position = _position.copy();

    velocity = new PVector();
    acceleration = new PVector();
    mass = _size/1000;               // Random mass for diversified interaction and behaviour
    presence = 1;
    displaySize = _size/2;           // display size is the radius of the sphere
    myScale =  _size / partSize;     // radius * spritesize
   
    bornAt = tl_millis();

  }

  public void run() {
    update();        // updates the particle position (overloaded so doesn't call the more complex Particle class update for now)
    update_shape();  // updates the particle sprite
    Attractor followme = findClosestAttractor();
    if(followme != null) applyAttractorForceSingle(followme);
    applyCenterForce();

    setActuatorDistanceInfluences();  // update the influence on actuators from this excitor.
 //   oscOut();                       // broadcast this excitor's position via OSC
  }

  public void update() {
    velocity.add(acceleration);
    velocity.limit(excBehavVars.excitorSpeedLimit*max_excitor_velocity);
    position.add(velocity);
    acceleration.mult(0);
    // after (fadeAt * lifespan), spend the rest of lifespan fading linearly to 0.

    presence = excBehavVars.masterIntensity;

    int age = tl_millis()-bornAt;
    int fadeAge = int(0.99 * excBehavVars.fadeAt * excBehavVars.lifespan);   // fadeAge shouldn't ever be same as lifespan to avoid dividing by zero
    if (age >= fadeAge) {
      presence *= max(0.0, (1.0-(float(age-fadeAge) / (excBehavVars.lifespan-fadeAge))) );   //calculate decreasing presence based on lifespan in milliseconds and fadeAge
    }
    shape.setTint(color(255, 220, 150, presence * 255));
  }

  public Attractor findClosestAttractor() {

    Attractor closest = null;

    for (Attractor a : excitorBehaviour.attractorSystem.attractors) {
      a.abs_location = PVector.add(a.location, excitorBehaviour.attractorSystem.offset);
//      if(closest == null || closest.abs_location.dist(position) > a.abs_location.dist(position)) {
      if(closest == null || distSq(closest.abs_location, position) > distSq(a.abs_location, position)) {
           closest = a;
        }
    }
        
    for (Attractor a : excitorBehaviour.dm2Attractorsys.attractors) {
      a.abs_location = PVector.add(a.location, excitorBehaviour.dm2Attractorsys.offset);
      if(closest == null || distSq(closest.abs_location, position) > distSq(a.abs_location, position)) {
           closest = a;
        }
    }    
    
    for (Attractor a : excitorBehaviour.dm3Attractorsys.attractors) {
      a.abs_location = PVector.add(a.location, excitorBehaviour.dm3Attractorsys.offset);
      if(closest == null || distSq(closest.abs_location, position) > distSq(a.abs_location, position)) {
           closest = a;
        }
    }

    for (Attractor a : excitorBehaviour.dm5Attractorsys.attractors) {
      a.abs_location = PVector.add(a.location, excitorBehaviour.dm5Attractorsys.offset);
      if(closest == null || distSq(closest.abs_location, position) > distSq(a.abs_location, position)) {
           closest = a;
        }
    }

    for (Attractor a : excitorBehaviour.north_river_Attractorsys_1.attractors) {
      a.abs_location = PVector.add(a.location, excitorBehaviour.north_river_Attractorsys_1.offset);
      if(closest == null || distSq(closest.abs_location, position) > distSq(a.abs_location, position)) {
           closest = a;
        }
    }

    for (Attractor a : excitorBehaviour.north_river_Attractorsys_2.attractors) {
      a.abs_location = PVector.add(a.location, excitorBehaviour.north_river_Attractorsys_2.offset);
      if(closest == null || distSq(closest.abs_location, position) > distSq(a.abs_location, position)) {
           closest = a;
        }
    }

    for (Attractor a : excitorBehaviour.south_river_Attractorsys_1.attractors) {
      a.abs_location = PVector.add(a.location, excitorBehaviour.south_river_Attractorsys_2.offset);
      if(closest == null || distSq(closest.abs_location, position) > distSq(a.abs_location, position)) {
           closest = a;
        }
    }

    for (Attractor a : excitorBehaviour.south_river_Attractorsys_2.attractors) {
      a.abs_location = PVector.add(a.location, excitorBehaviour.south_river_Attractorsys_2.offset);
      if(closest == null || distSq(closest.abs_location, position) > distSq(a.abs_location, position)) {
           closest = a;
        }
    }

    return closest;
  }


  public void applyAttractorForceSingle(Attractor a) {
    //apply single attractor force per excitor to create a deversified interaction
    // Attractor a = s.attractors.get(index%excitorBehaviour.attractorCount);
    PVector force = a.abs_location.copy();
//    force.add(new PVector(s.offset.x(), s.offset.y(), s.offset.z()));
    force.sub(position);
    force.normalize();
    force.mult(excitorBehaviour.attractorForce);
    applyForce(force);
  }

  public void applyCenterForce() {
    //apply single attractor force per excitor to create a deversified interaction
    PVector force = new PVector(0, 0, 0);
    force.sub(position);
    force.normalize();
    force.mult(excitorBehaviour.centerForce);
    applyForce(force);
  }

  ////////////////////// SET ACTUATOR INFLUENCES /////////////////////////////////////////////////

  synchronized public void setActuatorDistanceInfluences() {

     if (excBehavVars.excitorsInfluenceActive) {

      /*
      Iterate through actuators to analyse the Distances between them and This Excitor  
      */
      float distSq;
      float thisInfluence;
      float newInfluence;

      for(Map.Entry<String, PVector> e : excitorBehaviour.relevantActuators.entrySet()) {

          PVector abs_loc = position; // PVector.add(loc, offset);
          distSq  = distSq(abs_loc, e.getValue());

          try {
            if (distSq < sq(displaySize)) {
                int core = int(0.999 * (displaySize * excBehavVars.coreSize));  // core in pixels
                distSq -= sq(core);

                thisInfluence = presence * max(0, masterBehaviourIntensity - (distSq/sq(displaySize-core)) * masterBehaviourIntensity ); // ramp to coreSize -- NEED TO VALIDATE THIS
                // thisInfluence = presence * (1 - dist/excBehavVars.influenceThreshold);   // presence already includes masterintensity
                newInfluence = min(excitorBehaviour.actuatorInfluences.get(e.getKey()) + thisInfluence, masterBehaviourIntensity);
                excitorBehaviour.actuatorInfluences.put(e.getKey(), newInfluence);
            } else {
                // 
            }
          } catch (Exception x) {
            println(x);
          }
      }

     }
  
  
  }

  public void display() {   // just used for debug : drawing core.

    if (!excBehavVars.showCore) return;
    
    pushMatrix();
    translate(position.x, position.y, position.z);
    rotateX(cam.getRotations()[0]);                  // drawing billboarded circles instead of spheres
    rotateY(cam.getRotations()[1]);
    rotateZ(cam.getRotations()[2]);
    noStroke();
    fill(255, 200, 200, 100 * presence);
    ellipse(0, 0, 2 * excBehavVars.coreSize * displaySize, 2 * excBehavVars.coreSize * displaySize);
    popMatrix();

  }

  public void applyForce(PVector _force) {
    PVector force = _force.copy();
    force.mult(mass + 0.5f);
    acceleration.add(force).mult(excBehavVars.forceScalar);
  }

  // public void oscOut() {
  //   OscMessage myMessage = new OscMessage("/excitorLocation");
  //   myMessage.add(index);
  //   myMessage.add(location.x);
  //   myMessage.add(location.y);
  //   myMessage.add(location.z);
  //   external_osc.send(myMessage, myRemoteLocation);
  // }

  public boolean isDead() {
    if (presence <= 0.0f) {
      return true;
    } else {
      return false;
    }
  }
}



//////////////////////// ATTRACTOR SYSTEM ///////////////////////

class AttractorSystem {

  ArrayList<Attractor> attractors;
  float lfoAxisX, lfoAxisY, lfoAxisZ, axisX, axisY, axisZ, rotationOffset;
  int attractorCount, radius;
  Vec3D axis;
  PVector offset;

  AttractorSystem(int _attractorCount, PVector _offset, int _radius) {
    rotationOffset = random(PI);
    attractorCount = _attractorCount;
    attractors = new ArrayList<Attractor>();
    axis = new Vec3D(0, 1, 0);
    offset = _offset;
    radius = _radius;

    //excBehavVars.attractorAngleSpeed = 0.01;  //excBehavVars.attractorAngleSpeed and LFO settings are very delicate and inter-dependent in getting good settings
    lfoAxisX = 0.1;
    lfoAxisY = 0.12;
    lfoAxisZ = 0.17;
  }

  synchronized public void addAttractor() {
    attractors.add(new Attractor(attractors.size(), attractorCount, excBehavVars.attractorAngleSpeed, axis, radius));
  }

  synchronized public void run() {
    setRotation();

    Iterator<Attractor> it = attractors.iterator();
    while (it.hasNext()) {
      Attractor a = it.next();
      a.angle = excBehavVars.attractorAngleSpeed * 0.05;
      a.axis = axis;
      a.run();
    }
  }

  synchronized public void setRotation() {
    //excBehavVars.attractorAngleSpeed = sin(((tl_millis()%30000)/30000f)*TWO_PI)*0.01;            //excBehavVars.attractorAngleSpeed is 'the amount af angle' that is added every Rotation (per frame)
    axisX = sin(rotationOffset + ((tl_millis()%(1000/lfoAxisX))/(1000/lfoAxisX))*TWO_PI) * 0.05*excBehavVars.attractorAngleSpeed;   //the Rotation Axis modulates over time using sinoids
    axisY = sin(rotationOffset + ((tl_millis()%(1000/lfoAxisY))/(1000/lfoAxisY))*TWO_PI) * 0.05*excBehavVars.attractorAngleSpeed;
    axisZ = sin(rotationOffset + ((tl_millis()%(1000/lfoAxisZ))/(1000/lfoAxisZ))*TWO_PI) * 0.05*excBehavVars.attractorAngleSpeed;

    axis = new Vec3D(axisX, axisY, axisZ);
    axis = axis.getNormalized();                                        //the Rotation Axis needs to be normalized, otherwise the positions will scale with it
  }

  public void display() {

   if (!excBehavVars.showAttractors) return;

   pushMatrix();
   translate(offset.x, offset.y, offset.z);
    noFill();
    stroke(255, 150, 150, excBehavVars.attractorOpacity * 255);
    beginShape();
    for (int i=0; i<attractorCount; i++) {
      vertex(
        attractors.get(i).location.x, 
        attractors.get(i).location.y, 
        attractors.get(i).location.z
        );
    }
    endShape(CLOSE);

    for (int i=0; i<attractorCount; i++) {
      attractors.get(i).display();
    }

   popMatrix();
  }
}




//////////////////////// ATTRACTOR ///////////////////////

class Attractor {

  PVector location, abs_location, velocity, acceleration, force;
  float threshold, curvature, mass, presence, angle, radius;  
  int size, index, attractorCount;
  Vec3D locV3D, axis;

  Attractor(int _index, int _attractorCount, float _angle, Vec3D _axis, int _radius) {
    index = _index;
    attractorCount = _attractorCount;
    angle = _angle;
    axis = _axis;
    radius = _radius;
    locV3D = new Vec3D(sin(index*(TWO_PI/attractorCount)), cos(index*(TWO_PI/attractorCount)), 0).scale(radius); // Generate points on circle, 6 to create a hexagon
    size = 20;
    velocity = new PVector();
    acceleration = new PVector();
    mass = random(1);
    threshold = random(2);
    curvature = 1;
  }

  public void run() {
    update();
  }

  synchronized public void update() {
    if(axis == null || locV3D == null) return;  // avoid null pointers when threads are starting up
    locV3D = rotate3D(locV3D, angle, axis);
    location = new PVector(locV3D.x(), locV3D.y(), locV3D.z());
  }

  public void applyForce(PVector _force) {
    PVector force = _force.copy();
    force.mult(mass + 0.5f);
    acceleration.add(force);
  }

  public void display() {
    stroke(0, 255, 255, excBehavVars.attractorOpacity * 255);
//    fill(150, 255, 255, excBehavVars.attractorOpacity * 255);
    pushMatrix();
    translate(location.x, location.y, location.z);
    rotateX(cam.getRotations()[0]);                  // drawing billboarded circles instead of spheres
    rotateY(cam.getRotations()[1]);
    rotateZ(cam.getRotations()[2]);
    noFill();
    strokeWeight(5);
    stroke(150, 255, 255, excBehavVars.attractorOpacity * 255);
    strokeWeight(1);
    ellipse(0, 0, size, size);
    ellipse(0, 0, size*2, size*2);
    popMatrix();
  }
}




//////////////////////// GRID EYE //////////////////////////////////////////////

float getGridEyePresenceAverage() {
  float val = 0;
  for (int i=0; i < gridEyePresences.length; i++) {
     excitorBehaviour.gridEyePresenceMax += gridEyePresences[i];
  }
  val /= gridEyePresences.length;
  return val;
}



//////////////////////// GEOMETRY FUNCTIONS ////////////////////////////////////

Vec3D rotate3D(Vec3D location, float angle, Vec3D axis) {
  Matrix4x4 mat = new Matrix4x4(); 
  mat.rotateAroundAxis(axis, angle); 
  Vec3D clone = new Vec3D(); 
  clone = mat.applyTo(location); 
  return clone;
}