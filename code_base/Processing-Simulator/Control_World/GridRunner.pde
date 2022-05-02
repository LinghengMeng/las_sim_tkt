
//  ALL THE DYNAMIC VARIABLES 

class GridRunnerVars extends BehaviourEngineVars {
  
  int     totalParticles = 2000;
  int     nParticles, lifespan, burstFreq, burstQty, sourceRotation, totalActiveSources, influenceSize;
  float   maxspeed, randomspeed, yvelocity, gravity, burstFreqRandom, burstLength, coreSize, influenceIntensity;
  float   gridScale;
  float   gridWaveX, gridWaveZ;
  float   spread, heading;
  float   onGridFriction, onGridSteering, offGridFriction, offGridSteering;
  float   partScale, randomScale, sourceCadence, debugOpacity, vertexOpacity;
  int     segradius, lookahead;
  boolean mouseSource, sourceStep, allSources, linkedSources, debug, displayModel, displaySegments, displayParticles, displayVertices, displaySources, displayCore;
  boolean influenceActive;
  boolean legacySteering; // discovered a bug in September that changed the way steering was done, unfortunately lots had been done before that, so this lets us preserve that.
//  String  modelName = "meander_for_GridRunner.obj";
  String  modelName = "meander_for_GridRunner.obj";
  ArrayList<ParticleSourceVars> particleSourceVars;


  GridRunnerVars() {
    super("GridRunner", false);  // send the name of the behaviour (used in many places)
  }
  
  void init() {     // load from file if present, if not set to these values (should never really need to edit these after first run
    
      neverSave = false;

      nParticles = 1000;
      maxspeed = 6.0;

      randomspeed = 0.4;

      gravity = 0.00;
      
      lookahead = 30;
      segradius = 2;

      gridWaveX = 0;
      gridWaveZ = 0;
      gridScale = 3.0;
    
      onGridFriction = 1.0;
      onGridSteering = 1.0;
      offGridFriction = 1.0; // 0.995;
      offGridSteering = 0.3;
    
      partScale = 1.0;
      lifespan  = 4000;

      debug = false;
      debugOpacity = .05;
      vertexOpacity = 1.0;
      displayModel = true;
      displaySegments = true;
      displayParticles = true;
      displayVertices = true;
      displaySources = true;

      influenceActive = true;
      displayCore   = true;
      influenceSize = 500;
      influenceIntensity = 0.1;  // per-particle, cumulative! 
      coreSize      = 1.0;

      legacySteering = true;

      // source stuff:

      mouseSource = false;
      sourceStep = true;
      allSources = false;    // edit all sources or just dynamic one?
      linkedSources = false;    // edit all sources or just dynamic one?
 
      sourceRotation = 0;      
      spread = TWO_PI;
      heading = 0.0;
      sourceCadence = 400;  // how often does it change source?
      burstFreq = 50;
      burstFreqRandom = 0.0; // no randomness- always the same burst (pulse) time.
      burstLength = 1.0;
      burstQty  = 50;
      yvelocity = 0.00;

      randomScale = 0.2;

      particleSourceVars = new ArrayList<ParticleSourceVars>();

    
  }
}


////////////////   GRIDRUNNER

class GridRunner extends Thread {

HashMap<String, PVector> relevantActuators  = new HashMap<String, PVector>();   // determined at startup by using name filtering - eg. only DRs, or just part of the sculpture
HashMap<String, Float>   actuatorInfluences = new HashMap<String, Float>();     // this will have the same keys as relevantActuators:  <node_id>:<device> eg: 322345:MO3

PShape allpoints;

PShape allparticles;
PShape allsegments;

int    totalActiveParticles = 0;
int    totalExcessParticles = 0;

int    fcount, lastframe, lastsrc;
float  frate;
int    fint = 5;

String model;
int model_offset_X = 300;
int model_offset_Y = 0;
int model_offset_Z = -800;
float model_rot_X = -0.08726647;
float model_rot_Y = -0.34906584;
float model_rot_Z = 0.0;

PImage gridRunnerSprite;
PShape hexgrid;
int vertexCount;
int curVertexIndex;
boolean curVertexChanged = true;
PVector curVertex;

ArrayList<PVector>  vertices;
ArrayList<PVector> vertexoffsets;
ArrayList<PShape>  vertexpoints;

boolean boxfilter = false;
boolean overSource = false;

ParticleSource ps;
ArrayList<ParticleSource> particleSources;
ArrayList<ParticleSource> deadSources;
  
  
GridRunner() {
    
  super("GridRunner_Thread");  


  /// gridrunners should affect all the moths, protocells and rbelstars in the North River and South River (not the SMA)

  relevantActuators.putAll(dl.get_actuator_coordinates_by_name("NR", "MO"));
  relevantActuators.putAll(dl.get_actuator_coordinates_by_name("NR", "PC"));
  relevantActuators.putAll(dl.get_actuator_coordinates_by_name("NR", "RS"));
  relevantActuators.putAll(dl.get_actuator_coordinates_by_name("SR", "MO"));
  relevantActuators.putAll(dl.get_actuator_coordinates_by_name("SR", "PC"));
  relevantActuators.putAll(dl.get_actuator_coordinates_by_name("SR", "RS"));
  relevantActuators.putAll(dl.get_actuator_coordinates_by_name("TG"));
  relevantActuators.putAll(dl.get_actuator_coordinates_by_name("MU"));


  allparticles = createShape(PShape.GROUP);
  allsegments  = createShape(PShape.GROUP);

  gridRunnerSprite = loadImage("sprite.png");

  particleSources = new ArrayList<ParticleSource>();  
  deadSources = new ArrayList<ParticleSource>();  

  loadModel(gridRunnerVars.modelName);
  initSources();            // create sources
 
}


synchronized void initSources() {

  // make new sources for each saved particlesource, if any - this is a bit convoluted because we need to rebuild them completely.
  if(gridRunnerVars.particleSourceVars != null) {

    ArrayList<ParticleSourceVars> temp_particleSourceVars = new ArrayList<ParticleSourceVars>();  // create an empty temporary array list.

    println(" ParticleSourceVars now has " + gridRunnerVars.particleSourceVars.size() + " elements.");

    for(ParticleSourceVars s : gridRunnerVars.particleSourceVars) {
        // since these are loaded by GSON, we need to explicitly make new ones (run the constructor) so that they can be 
        // properly registered as BehaviourEngineVars and ultimately, Patchable.  
        // So we create new ones, then transfer the existing info over.  -mg Aug 5 2020

        ParticleSourceVars temp_s = new ParticleSourceVars(s.sourceName);
        temp_s.copy(s);
        temp_particleSourceVars.add(temp_s);
        makeNewSource(temp_s);
        // makeNewSource(s);
    } 
    
    if( temp_particleSourceVars.size() == 0 ){ 

      println(" Whoops, where did all my particlesources go? " );
    }

    // now replace the gridRunnerVars version:
    gridRunnerVars.particleSourceVars = temp_particleSourceVars;
  }

  // if we still don't have a PS, make one
  if(ps == null) { 
     ps = makeNewSource("Source_PS");
  }

}

synchronized ParticleSource makeNewSource(String name) {

      ParticleSourceVars s = new ParticleSourceVars(name);
      s.position_x = curVertex.x;
      s.position_y = curVertex.y;
      s.position_z = curVertex.z;
      s.init(gridRunnerVars);       // shortcut to copy rest of current GV source settings

      try{
      gridRunnerVars.particleSourceVars.add(s);
      } catch(Exception e) {

       println(" odd . exception creating a particle sourceVars when it used to work. " + e);
        return(null);
      }

      gridRunnerVars.needToSave = true;

      return(makeNewSource(s));

}

synchronized ParticleSource makeNewSource(ParticleSourceVars s) {
  
    ParticleSource src = new ParticleSource();
    allparticles.addChild(src.myparticles);
    allsegments.addChild(src.mysegments);

    src.vertices = vertices;
    src.vertexoffsets = vertexoffsets;

    src.initSource(s); 

    particleSources.add(src);
    src.initParticles(gridRunnerSprite);
    src.start();  

    if(s.sourceName.equals("Source_PS")) {
      ps = src;  // if we are creating PS, assign it here
    } else {
      s.setPatchable();  // we want to make a patchable that will get registered with the Patcher
      s.addToGUI();      // we want to add a GUI folder for this source.
    }

    return(src);   

}


  
/// DRAW LOOP  
  
void run() {
     
  while(true) {

    try{
      Thread.sleep(gridRunnerVars.thread_update_rate + time_lapse_pause);                        // prevents high CPU usage
    } catch (Exception e) {
      println(e);
    }

  // Clear influences at start of cycle so that actuators reset before the influences cumulate
  clearActuatorInfluences();


  // check for new grid model to load:
//  if(!model.equals(gridRunnerVars.modelName)) {           // a new model has been selected
//    println("New gridrunner model: " + gridRunnerVars.modelName);
//    loadModel(gridRunnerVars.modelName);
//  }

  // check if we should rebuild sources (ie preset changed)
  if(gridRunnerVars.presetchanged) {

    gridRunnerVars.presetchanged = false;

    println("New gridrunner preset, setting up particle sources");
    
    for(ParticleSource s : particleSources) {
      endSource(s);
    }
    particleSources.clear();
    ps = null;  
    // reset shapes
    allparticles = createShape(PShape.GROUP);
    allsegments  = createShape(PShape.GROUP);
    initSources();

  }

  
  // vertex transformations

  for (PVector v : vertices) {
    float xwave = gridRunnerVars.gridWaveX*sin(v.x);
    float zwave = gridRunnerVars.gridWaveZ*sin(v.z); 
    PVector vo = new PVector(0, xwave + zwave, 0);
    vertexoffsets.set(vertices.indexOf(v), vo);
 
    //PShape p   = vertexpoints.get(vertices.indexOf(v));

    try {
//      p.resetMatrix();
//      p.rotateX(PI/2);
//      p.translate(v.x + vo.x, v.y + vo.y, v.z + vo.z);
    } catch(Exception e) {

      println("Exception " + e + " trying to use vertexpoints...? ");

    }
  }


  // update 

  gridRunnerVars.totalActiveSources = 0;
  totalActiveParticles = 0;
  totalExcessParticles = 0;

  try {
    for(ParticleSource src : particleSources) {
  
      if(src==ps) {             // update with current gv data
        src.settings.init(gridRunnerVars);
      } else {
        if(gridRunnerVars.allSources || 
          (gridRunnerVars.linkedSources && src.settings.linked)) {     // sync all sources to interface (a bit of a hack)
           src.settings.init(gridRunnerVars);
        }
      }

      for (Particle p : src.particles) {
        if(p.deactivate_me) {
          src.hideParticle(p);
        }
        p.update();                              // <- update the particle's position, velocity, trajectory, etc.
        update_actuator_influences(p);           // <- set the influece this particle has on the actuators               
      }

    gridRunnerVars.totalActiveSources += ( (src.settings.active && src.active) ? 1 : 0);    // put this in gv so sources can access it.
    totalActiveParticles  += src.activeParticles;
    totalExcessParticles  += src.excessParticles;   

    if(src.dying && src.activeParticles == 0) {
        deadSources.add(src);
    }
   } 

  } catch(Exception x) {

    println("Exception: " + x);

  }

  cullDeadSources();


  /// send actuator influences to Control_World
  control.set_actuator_excitor_influences(actuatorInfluences, "GR");



  /// update FPS & save current settings
  fcount += 1;
  int m = millis();
  if (m - lastframe > 1000 * fint) {  
    frate = float(fcount) / fint;
    fcount = 0;
    lastframe = m;
    println("GridRunner - FPS: " + frate + " | numSources: " + gridRunnerVars.totalActiveSources + " | numparticles: " + totalActiveParticles + " (" + totalExcessParticles + " culled)"); 
  }  


  /// update special particle source / cursor

  if(gridRunnerVars.sourceStep) {      /// step through the vertices as sources
      ps.active = true;
      if (m - lastsrc > gridRunnerVars.sourceCadence) {     
      // increment vertex number
        curVertexIndex = (curVertexIndex + 1) % vertices.size();
        curVertex = vertices.get(curVertexIndex).copy();
        ps.position = curVertex.copy();
        lastsrc = m;
      }
    } 
  }
} /// end run();
  





/// other gridrunner-specific functions

synchronized void toggleSource() {   // if there is already a source, remove it, otherwise add it

ParticleSource thisSource = null;


  for(ParticleSource s : particleSources) {
    if(s==ps) { 
      continue; // so we don't remove the main one.
    }
    if(ps.position.equals(s.position)) {
       thisSource = s;
       break;        
    }
  }

  if(thisSource != null) {
    println("removing fixed source");
    thisSource.active = false; // stop it from doing anything
    thisSource.dying = true;   // don't draw it and tag it for culling once its particles are dead.
    thisSource.settings.removeFromGUI(); // immediately remove it form the gui.

  } else {
    makeNewSource("Source_" + curVertexIndex);
    println("added source #" + particleSources.size() + ": (Source_" + curVertexIndex + ")");
  }

  gridRunnerVars.needToSave = true;


}

synchronized void fetchNearestSource() {

  ParticleSource closest = null;
  float mindist = 1000000;

  println(" Looking for closest...");

  for(ParticleSource s : particleSources) {
    if(s==ps) { 
      continue; // so we don't toggle the main one
    }
    float d = ps.position.dist(s.position);
    if(d < mindist) {
       mindist = d;
       closest = s; 
    }
  }

  if(closest != null) {
     println(" found source " + closest.settings.sourceName);
     println(" deregistering...");
     closest.settings.removeFromGUI(); // immediately remove it form the gui.
     closest.settings.deregisterBehaviour(true);  // boolean isChild (to make sure we deregister from the right place)
     gridRunnerVars.particleSourceVars.remove(closest.settings);
     println(" changing name to " + "Source_" + curVertexIndex);
     closest.settings.sourceName = ("Source_" + curVertexIndex);
     closest.settings.behaviourName = ("Source_" + curVertexIndex);
     closest.settings.position_x = ps.position.x;
     closest.settings.position_y = ps.position.y;
     closest.settings.position_z = ps.position.z;
     closest.position = ps.position.copy();
     for(Particle p : closest.particles) {
        p.setSource(closest.settings);
     }
     println(" registering ....");
     gridRunnerVars.particleSourceVars.add(closest.settings);
     closest.settings.registerBehaviour(true);

     gridRunnerVars.needToSave = true;

  }
}


synchronized void toggleSourceActive() {   // if there is already a source, remove it, otherwise add it

ParticleSource thisSource = null;

  for(ParticleSource s : particleSources) {
    if(s==ps) { 
      continue; // so we don't toggle the main one
    }
    if(ps.position.equals(s.position)) {
       thisSource = s;
       break;        
    }
  }

  if(thisSource != null) {
    println("toggling fixed source");
    send_gui_OSC("GridRunner", "active", str(!(thisSource.settings.active)), thisSource.settings.sourceName);
  }
}

/// hack: ask gridrunner to generate and Excitor via one of its particle sources
synchronized void requestExcitor() {

ParticleSource thisSource = null;

  for(ParticleSource s : particleSources) {
    if(s==ps) { 
     // continue; // maybe for now leave this so we can test; skip PS?
    }
    if(ps.position.equals(s.position)) {
       thisSource = s;
       break;        
    }
  }

  thisSource.generateExcitor();

}




synchronized void cullDeadSources() {
  for (ParticleSource src : deadSources) {
      particleSources.remove(src);
      endSource(src);
  }
  deadSources.clear();
}

synchronized void endSource(ParticleSource s) {
  allparticles.removeChild(allparticles.getChildIndex(s.myparticles));
  allsegments.removeChild(allsegments.getChildIndex(s.mysegments));
  gridRunnerVars.particleSourceVars.remove(s.settings);  // won't do anything if already changed
  gridRunnerVars.patchables.remove(s.settings.sourcePatchable);
  patcher.remove(s.settings.sourceName);

   if(childBehaviourSettings.containsValue(s.settings)) {  // if this specific settings instance is still registered, remove them by name (this prevents removing new ones with the same name)
     s.settings.deregisterBehaviour(true);     // boolean ischild - this is a child behaviour, look for it in the right place
   }
   
  s.endme();

  gridRunnerVars.needToSave = true;
}


synchronized void pauseParticles(boolean p) {

  for(ParticleSource s : particleSources) {
      s.paused = p;
  }
}

void loadModel(String fn) {

  // first, pause particle behaviour
  pauseParticles(true);

  delay(100);     
  float hexModelScale = gridRunnerVars.gridScale;// to sync with Meander Model - keep this constant it is used throuhgout the particle physics

  // this worked, so carry on:

  allpoints    = createShape(PShape.GROUP);

  LinkedHashSet<PVector> vertexset = new LinkedHashSet<PVector>();         // using this to easily remove duplicates
  vertices  = new ArrayList<PVector>();
  vertexoffsets = new ArrayList<PVector>();
  vertexpoints  = new ArrayList<PShape>();


    JSONObject vertexfile = loadJSONObject(sketchPath() + "/data/" + file_name + "/gridrunner_meander_json_vertices6.json");

    for(String section : (Set<String>)vertexfile.keys()) {

      if(section.equals("Hex Grid NR 2")) continue;  // for now, exclude this layer.
      if(section.equals("Hex Grid SR 2")) continue;  // for now, exclude this layer.
      if(section.equals("Actuators")) continue;      // for now, exclude this layer.

      JSONArray points = vertexfile.getJSONArray(section);

      for(int i = 0; i < points.size(); i++) {

            JSONObject jo = points.getJSONObject(i);
            PVector v = new PVector(jo.getFloat("x"), 0-jo.getFloat("y"), jo.getFloat("z"));  // flipping y
            vertexset.add(v);
        }
        println(" Added " + points.size() + " vertices in section: " + section);
       }

    

  vertices.addAll(vertexset); // putting them into an ArrayList so I can get indices.
  

  // lets add the sound detectors, IR detectors, and Grideyes

  // HashMap<String, PVector> actuatorsToAdd = new HashMap<String, PVector>();
  // actuatorsToAdd.putAll(dl.get_actuator_coordinates_by_name("NR", "SD"));
  // actuatorsToAdd.putAll(dl.get_actuator_coordinates_by_name("NR", "IR"));
  // actuatorsToAdd.putAll(dl.get_actuator_coordinates_by_name("NR", "GE"));
  // actuatorsToAdd.putAll(dl.get_actuator_coordinates_by_name("SR", "SD"));
  // actuatorsToAdd.putAll(dl.get_actuator_coordinates_by_name("SR", "IR"));
  // actuatorsToAdd.putAll(dl.get_actuator_coordinates_by_name("SR", "GE"));
  
  // for(PVector v : actuatorsToAdd.values()) {
  //   vertices.add(v);
  // }

  int numv = 0;

  fill(255); // for some reason need this to make sure the point shapes get initialized correctly
  
  for (PVector v : vertices) {

    // vertex transformations
    float xwave = gridRunnerVars.gridWaveX*sin(v.x);
    float zwave = gridRunnerVars.gridWaveZ*sin(v.z);
    PVector vo = new PVector(0, xwave + zwave, 0);
    vertexoffsets.add(vo);
  
    PShape px = createShape(ELLIPSE, 0, 0, 10*(abs(hexModelScale)), 10*(abs(hexModelScale)));
    px.rotateX(PI/2);

    PShape py = createShape(ELLIPSE, 0, 0, 10*(abs(hexModelScale)), 10*(abs(hexModelScale)));
    py.rotateY(PI/2);

    PShape pz = createShape(ELLIPSE, 0, 0, 10*(abs(hexModelScale)), 10*(abs(hexModelScale)));
    pz.rotate(PI/2, 0, 0, 1);

    PShape p = createShape(GROUP);
    p.addChild(px);
    p.addChild(py);
    p.addChild(pz);      
    p.setStrokeWeight(0);
    p.translate(v.x + vo.x, v.y + vo.y, v.z + vo.z);

    vertexpoints.add(p);
    allpoints.addChild(p);

  }

  curVertex =  vertices.get(0).copy();
  PVector midvertex = vertices.get(vertices.size()/2);

  // cam.lookAt(midvertex.x, midvertex.y, midvertex.z);

  // now, let particle behaviour run again
  pauseParticles(false);
}


/////  display

synchronized void display() {


  // first, do the math to find closest point to the cursor (this is in display because it uses screenX, which is erratic if used outside animation thread)

  if (!gridRunnerVars.sourceStep ) {
    if(gridRunnerVars.mouseSource) {
      ps.active = true;
    } else {
      ps.active = false;
    }
    
    float mousedistsq = sq(9999);
    int closestIndex = 0;
    PVector closest = new PVector(0,0,0);
    
    for(int i = 0; i < vertices.size(); i++) {

      PVector v = vertices.get(i);
      PVector vt = PVector.add(v, vertexoffsets.get(i));
      vt = v.copy();

      float dsq = distSq(mouseX, mouseY, screenX(vt.x, vt.y, vt.z), screenY(vt.x, vt.y, vt.z));

      if(dsq < mousedistsq) {
        mousedistsq = dsq;
        closest = vt.copy();
        closestIndex = i;
      }
    }
        
    curVertex = closest.copy();
    if(closestIndex != curVertexIndex) {
      curVertexIndex = closestIndex;
      curVertexChanged = true;
    } else {
      curVertexChanged = false;
    }
    ps.position = closest.copy();

  }


  // if(gridRunnerVars.displayModel) {
  //   pushMatrix();
  //   translate(0,0, -10);
  //   hexgrid.tint(color(150, 150, 200, 150));
  //   shape(hexgrid);
  //   popMatrix();
  // }

  if(gridRunnerVars.displayVertices) {
    noStroke();
    allpoints.setFill(color(150, 200, 150, int(100*gridRunnerVars.vertexOpacity)));
    shape(allpoints);
  }

  overSource = false;
  for(ParticleSource src : particleSources) {

      if(!src.dying) {
        // draw source circles
      if(src==ps) {             // special case orange for ps
        stroke(200,100,0, 100);
        noFill();
      } else {
       if(src.position.equals(ps.position) && gridRunnerVars.displaySources) {
          // I am hovering over an existing source, so show its name
          overSource = true;
          PVector labelpos = new PVector(screenX(src.settings.position_x, src.settings.position_y, src.settings.position_z), 
                                         screenY(src.settings.position_x, src.settings.position_y, src.settings.position_z)-(textoffset/2));
          cam.beginHUD();
          noStroke();
          fill(150, 200, 150);
          String label = src.settings.sourceName;
          textSize(textheight);
          text(label, labelpos.x, labelpos.y); 
          cam.endHUD();
          hint(DISABLE_DEPTH_TEST);

          // also, tell patcher to highlight this one
          patcher.highlight(label);

          if(curVertexChanged) {
            // and tell datGUI to point to this one in the folder list
            send_gui_OSC("GridRunner", "highlightFolder", "true", label);
          }
          


        }
        noFill();
        stroke(150,200,150, 100);
      }
      drawSource(src);
      }

      // now src should update all its particles
      src.display(); 

  }
  

  try {
    if(gridRunnerVars.displaySegments)  shape(allsegments);
    if(gridRunnerVars.displayParticles) shape(allparticles);
  } catch(Exception e) {

    println(" *** Exception drawing GR particles: " + e);

  }

  // if(gridRunnerVars.needToSave) {     // moved to main control-world thread
  //  cam.beginHUD();
  //  stroke(255, 100);
  //  fill(100, 100, 255, 100);
  //  ellipse(width-10, 10, 10, 10);
  //  cam.endHUD();    
  // }
}

void drawSource(ParticleSource src) {
  if(gridRunnerVars.displaySources) {
    // draw a circle and arc around source
    pushMatrix();
    translate(src.position.x, src.position.y, src.position.z);
    if(src.settings.sourceRotation == 0) rotateX(PI/2);
    if(src.settings.sourceRotation == 1) rotateY(-PI/2);
    if(src.settings.sourceRotation == 2) {rotateX(PI); rotateZ(-PI/2);}
    noFill();
    strokeWeight(2);
    ellipseMode(CENTER);
    ellipse(0, 0, 50, 50);
    if(src.settings.active) strokeWeight(3.5-(src.burstPctDone * 3.0));
    rotateZ(src.settings.heading);
    arc(0, 0, 58, 58, TWO_PI-src.settings.spread, TWO_PI);
    popMatrix();
  }

}


//////////////////////// INFLUENCE FUNCTIONS ////////////////////////////////////

synchronized public void update_actuator_influences(Particle p) {


     if (gridRunnerVars.influenceActive && p.active && !p.deactivate_me) {           // don't do this unless we have to - it's expensive.

      /*
      Iterate through actuators to analyse the Distances between them and This Excitor  
      */
      float distSq;
      float thisInfluence;
      float newInfluence;

      for(Map.Entry<String, PVector> e : relevantActuators.entrySet()) {

          PVector abs_loc = p.position;
          distSq  = distSq(abs_loc, e.getValue());


          try {
            if (distSq < sq(p.mysrc.influenceSize)) { 
                int core = int(0.999 * (p.mysrc.influenceSize * p.mysrc.coreSize));       // core in pixels -- will ramp from edge of core to edgeof infSize
                distSq -= sq(core);

                thisInfluence = p.mysrc.influenceIntensity * p.opacity * max(0, masterBehaviourIntensity - (distSq/sq(p.mysrc.influenceSize-core)) * masterBehaviourIntensity );  // ramp to coreSize
                newInfluence = min(actuatorInfluences.get(e.getKey()) + thisInfluence, masterBehaviourIntensity);            // these are cumulative for each particle's influence
                actuatorInfluences.put(e.getKey(), newInfluence);
            } else {
                // 
            }
          } catch (Exception x) {
            println(x);
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



//////////////////////// EXTRA GEOMETRY FUNCTIONS ////////////////////////////////////

Vec3D rotate3D(Vec3D location, float angle, Vec3D axis) {
  Matrix4x4 mat = new Matrix4x4(); 
  mat.rotateAroundAxis(axis, angle); 
  Vec3D clone = new Vec3D(); 
  clone = mat.applyTo(location); 
  return clone;
}

}