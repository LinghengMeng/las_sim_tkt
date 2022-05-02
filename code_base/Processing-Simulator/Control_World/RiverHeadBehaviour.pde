/*

RiverHead

This behaviour creates a specific ring-shaped 'river head' that holds (flow) 
particles in place and spins them on 3 axes

\Author: Poul Holleman & Matt Gorbet ©2019-2020

*/


///   GENERAL VARIABLES FOR RiverHeads

class RiverHeadVars extends BehaviourEngineVars {

  int particleCount, rhRingSize, rh_update_rate;
  float threshold, rhVertexAngleSpeed, masterIntensity;
  boolean  display, displayRings, influenceActive;

  RiverHeadVars() {
    super("RiverHead", false);
  }

  void init() {
        
    neverSave = true;

    /*
    Particle Count is the amount of Particles that flow through the field
    */
    particleCount = 12;

    /*
    The threshold sets at which distance between 
    Particle and Actuator the Actuator gets influenced,
    it's a distance based algorithm that defines the sphere of influence
    */
    threshold = 275;

    /*
    rhVertexAngleSpeed is the speed at which the rings spin (normalized to 0-1)
    */
    rhVertexAngleSpeed = 0.1;

    /*
    rhRingSize is the size in vertices (particles) of the River Head rings
    */
    rhRingSize = 12;
    masterIntensity =  1.0;
    display = false;
    displayRings = true;
  }

}


///////////////////////////// RIVER HEAD (trapped particles that move in unison around a specified origin)

class RiverHeadSystem extends Thread {

  ArrayList<RhParticle> vertices;
  float lfoAxisX, lfoAxisY, lfoAxisZ, axisX, axisY, axisZ;
  int vertexCount;
  Vec3D axis, offset;

  HashMap<String, PVector> relevantActuators = new HashMap<String, PVector>();      // determined at startup by using name filtering - eg. only DRs, or just part of the sculpture
  HashMap<String, Float>   actuatorInfluences = new HashMap<String, Float>();       // this will have the same keys as relevantActuators:  <node_id>:<device> eg: 322345:MO3

  RiverHeadSystem(String name, int _vertexCount, Vec3D _offset) {

    // name this thread
    super("RiverHead_thread_" + name);

    vertexCount = _vertexCount;
    vertices = new ArrayList<RhParticle>();
    offset = _offset;
    axis = (new Vec3D(0, 1, 0));

     lfoAxisX = 0.1;
     lfoAxisY = 0.12;
     lfoAxisZ = 0.001;

    buildParticleRing(350);  // diameter of riverhead
    relevantActuators.putAll(dl.get_actuator_coordinates_by_name("RH", name + "R"));
  
  }

  public void buildParticleRing(int radius) {

    for(int i = 0; i < vertexCount ; i++) {
        Vec3D locV3D = new Vec3D(sin(i*(TWO_PI/vertexCount)), cos(i*(TWO_PI/vertexCount)), 0); // Generate points on circle, 6 to create a hexagon
        RhParticle p = new RhParticle(i, this);
        p.locV3D = (locV3D.scale(radius));
        p.loc    = new PVector(p.locV3D.x(),p.locV3D.y(),p.locV3D.z());
        p.offset = new PVector(offset.x(), offset.y(), offset.z());

        vertices.add(p);
    }
  }


 void run() {
    while(true) {

      try{
        Thread.sleep(riverHeadVars.thread_update_rate + time_lapse_pause);
      } catch (Exception e) {
        println(e);
      }

      /*
      Clear influences at start of cycle
      so that actuators reset before the influences cumulate
      */
      clearActuatorInfluences();

      Iterator<RhParticle> it = vertices.iterator();

      setRotation();
      while (it.hasNext()) {
        RhParticle a = it.next(); 
        a.update_ring(axis);
        a.setActuatorDistanceInfluences();
      }

   //   control.set_actuator_excitor_influences(actuatorInfluences, "RH");
      control.set_actuator_excitor_influences(actuatorInfluences, "EXP");  // <- due to apparent July2020 riverhead bug, we are using EXP here instead

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

  synchronized public void setRotation() {
    //excBehavVars.attractorAngleSpeed = sin(((tl_millis()%30000)/30000f)*TWO_PI)*0.01;            //excBehavVars.attractorAngleSpeed is 'the amount af angle' that is added every Rotation (per frame)
    axisX = sin(((tl_millis()% (1000/lfoAxisX)) / (1000/lfoAxisX)) * PI)*0.05*riverHeadVars.rhVertexAngleSpeed;   //the Rotation Axis modulates over time using sinoids
    axisY = sin(((tl_millis()% (1000/lfoAxisY)) / (1000/lfoAxisY)) * PI)*0.05*riverHeadVars.rhVertexAngleSpeed;
    axisZ = sin(((tl_millis()% (1000/lfoAxisZ)) / (1000/lfoAxisZ)) * PI)*0.05*riverHeadVars.rhVertexAngleSpeed;

    axis = new Vec3D(axisX, axisY, axisZ);
    axis = axis.getNormalized();                                        //the Rotation Axis needs to be normalized, otherwise the positions will scale with it
  }

  synchronized public void display() {         // riverhead system
    if (!riverHeadVars.displayRings) return;

    pushMatrix();
    translate(offset.x, offset.y, offset.z);
    noFill();
    stroke(200, 130, 130, 100);
    beginShape();
    for (RhParticle v : vertices) {
      vertex(
        v.loc.x, 
        v.loc.y, 
        v.loc.z
      );
    }
    endShape(CLOSE);

    if(riverHeadVars.display) {
    for (RhParticle v : vertices) {
        v.display();
      }
    }

    popMatrix();
  }
}



///////////////////////////// PARTICLE 


class RhParticle {

  RiverHeadSystem parent;
  PVector loc;
  Vec3D locV3D, axis;
  PVector offset;
  float angle, radius;
  int index;


  RhParticle(int i, RiverHeadSystem p) {
    
    /*
    Spawn Particles at random Positions
    */
    loc      = new PVector(0,0,0);
    locV3D   = new Vec3D(loc.x, loc.y, loc.z);
    offset   = new PVector(0,0,0);

    index = i;
    parent = p;

  }

  synchronized void update_ring(Vec3D ax) {

    axis = ax;

    angle = riverHeadVars.rhVertexAngleSpeed * 0.05;
    axis = ax;
    locV3D = rotate3D(locV3D, angle, axis);
    loc    = new PVector(locV3D.x(), locV3D.y(), locV3D.z());
      
  }


  ///  set acutator influences

  synchronized public void setActuatorDistanceInfluences() {
    
    if (riverHeadVars.influenceActive) {

      /*
      Iterate through actuators to analyse the Distances between them and This Particle  
      */
      float dist;
      float thisInfluence;
      float newInfluence;

      for(Map.Entry<String, PVector> e : parent.relevantActuators.entrySet()) {

          PVector abs_loc = PVector.add(loc, offset);
          dist  = abs_loc.dist(e.getValue());
          // dist = loc.dist(e.getValue());

          try {
            if (dist<riverHeadVars.threshold) {
                thisInfluence = 1 - dist/riverHeadVars.threshold;
                newInfluence = min(parent.actuatorInfluences.get(e.getKey()) + thisInfluence, riverHeadVars.masterIntensity);
                parent.actuatorInfluences.put(e.getKey(), newInfluence);
            } else {
               ///////
            }
          } catch (Exception x) {
            println(x);
          }
      }
    }
  }

  synchronized void display() {          // rhParticle

    if (!riverHeadVars.display) return;

    pushMatrix(); 
    PVector displayLoc;
    displayLoc = loc.copy();
    
    translate(displayLoc.x, displayLoc.y, displayLoc.z);

    stroke(50, 100);
    strokeWeight(1);
    //fill(200, 100);
    sphere(riverHeadVars.threshold);
    
    popMatrix();

  }
}

