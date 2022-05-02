

class Particle extends Thread {
  
  PImage sprite;  
  PShape shape;

  PMatrix3D shapeMatrix;

  int partSize = 20;
  float myScale = 1.0;
  int bornAt;
  int age;

  boolean boxfilter = true;
  int winXsize = 900;
  int winYsize = 900;
  int winZsize = 900;

  boolean active;
  boolean deactivate_me = false;
  boolean online = false;

  ParticleSourceVars mysrc;

  // All the usual stuff
  
  PVector position;
  PVector force;
  PVector srcposition;
  PVector predictpos;
  PVector velocity;      // velocity for this frame based on curspeed
  PVector acceleration;
  PVector[] nearVerts;
  PVector normalPoint;
  PVector dir;
  PVector target;
  PVector desired;
  PVector steer;
  float friction;
  float pathdistance;  // actually, the square of the pathdistance... to avoid sqrt

// from excitor - see if used
  float mass;
  float presence;
  float displaySize;
  float influenceThreshold;

  // velocity control
  int    lastframetime;
  float  curspeed;      // scalar; speed in units per 10 millisecond

  Segment nearSeg;
  float segdist = 0;
  float segdistSq = 0; // more efficient to use squares for dist calcs
  
  int debugalpha = 10;
  
  float opacity;
  float maxsteer;    // Maximum steering force

  boolean exit = false;

  boolean hidden = true;  // extra flag so we don't waste resources hiding particles


  // Constructor initialize all values
  Particle(PImage particlesprite) {

    super("particle thread");

    shapeMatrix = new PMatrix3D();   // stores the rotate/translate/scale for this particle so it can be applied directly in one move to the shape, for efficiency and avoid thread conflicts

    sprite = particlesprite;

    // sprite = loadImage("excitor_sprite.png");

    mysrc = new ParticleSourceVars("");

    active = false;

    srcposition = new PVector(mysrc.position_x, mysrc.position_y, mysrc.position_z);
    position = srcposition.copy(); // new PVector(0,0,0);
    predictpos = position.copy();
    normalPoint = position.copy();
    target = position.copy();
    dir = position.copy();
    desired = position.copy();

    lastframetime = millis()-10;  // anticipated time of last frame in millis
    
    maxsteer = mysrc.offGridSteering;
    friction = mysrc.offGridFriction;
    
    acceleration = new PVector(0, 0, 0);      // set to zero 
    velocity = new PVector(mysrc.maxspeed, 0, 0);
    opacity = 1.0;
    
    nearVerts = new PVector[2];
    nearVerts[0] = new PVector(0,0,0);
    nearVerts[1] = new PVector(0,0,0);
    
    nearSeg = new Segment();


    shape = createShape();    
    shape.beginShape(QUAD);
    shape.noStroke();
    shape.texture(sprite);
    shape.normal(0, 0, 1);
    shape.vertex(-partSize/2, -partSize/2, 0, 0, 0);
    shape.vertex(+partSize/2, -partSize/2, 0, sprite.width, 0);
    shape.vertex(+partSize/2, +partSize/2, 0, sprite.width, sprite.height);
    shape.vertex(-partSize/2, +partSize/2, 0, 0, sprite.height);
    shape.endShape();    
    shape.setTint(color(0, 0, 255, 0));
    shape.setVisible(false);

  }

  void setSource(ParticleSourceVars src) {
    mysrc = src;
    srcposition = new PVector(mysrc.position_x, mysrc.position_y, mysrc.position_z);
    position = srcposition.copy(); // new PVector(0,0,0);
    predictpos = position.copy();
    normalPoint = position.copy();
    target = position.copy();
    dir = position.copy();
    desired = position.copy();
 }

  
  void update() {

    if(!active || deactivate_me) {
        // if(!shape.isVisible()) {
        //   shape.setTint(color(200, 0, 200, 0)); // should be hidden already but there's a bug, so set opacity to zero
        //   nearSeg.update(0, 0); // also make sure segment updates / hides
        // }
      return;
    }

    age = millis()-bornAt;    
    if(age > mysrc.lifespan) { deactivate_me = true; return; }

    opacity = float(mysrc.lifespan - age) / mysrc.lifespan;
    // if(gridRunnerVars.debug) {
    //   shape.setTint((online ? color(200, 255, 200, opacity*255) : color(255, 200, 200, opacity*255)));
    // } else {
    //   shape.setTint(color(255, opacity * 255));
    // }

    // active but invisible - first frame, so need to respawn, then turn on.

    if (!shape.isVisible()) {
      
        shape.setVisible(true);
        nearSeg.show();
      
        acceleration.mult(0);           // not used yet
        position = srcposition.copy();
        predictpos = position.copy();
        normalPoint = position.copy();
        target = position.copy();
        desired.mult(0);
        dir.mult(0);
        nearSeg.start = srcposition.copy();
        nearSeg.end   = srcposition.copy();
        nearSeg.update(opacity, 0.0);
        
        maxsteer = mysrc.offGridSteering;

        // reset scale
        myScale = random(max(0.01, (1.0-gridRunnerVars.randomScale) * gridRunnerVars.partScale), gridRunnerVars.partScale);
        myScale *= abs(gridRunnerVars.gridScale); // sync with Meander;

        // set initial trajectory and speed
 
        int lastframedur = millis()-lastframetime; 

        float angle = random(0, mysrc.spread);
        angle += mysrc.heading-mysrc.spread;
        curspeed = random(max(0.5, (1.0-mysrc.randomspeed) * mysrc.maxspeed), mysrc.maxspeed);  // random from floor to max speed
        curspeed *= abs(gridRunnerVars.gridScale);  // sync with Meander;
       
        velocity.x = curspeed/10f * cos(angle) * lastframedur;
        velocity.y = mysrc.yvelocity * curspeed/10f * tan(angle) * lastframedur;
        velocity.z = curspeed/10f * sin(angle) * lastframedur;

        if(mysrc.sourceRotation == 1) {
           float t = velocity.y;
           velocity.y = velocity.z;
           velocity.z = velocity.x;
           velocity.x = t;
        }

        if(mysrc.sourceRotation == 2) {
           float t = velocity.y;
           velocity.y = velocity.x;
           velocity.x = velocity.z;
           velocity.z = t;
        }
        
      } else {
        
      // currently active particle - needs updating
        
        velocity.add(acceleration);  /// used in steering
        acceleration.mult(0);        /// - no intertia between frames

        curspeed *= friction;

        velocity.setMag(curspeed/10f * (millis()-lastframetime)); // units per 10 millis

//        velocity.limit(mysrc.maxspeed);
        velocity.limit(mysrc.maxspeed * abs(gridRunnerVars.gridScale));  // sync with Meander
//        velocity.mult(friction);
        position.add(velocity);

      // also update segment
        nearSeg.update(opacity, sqrt(segdistSq));


      }

      lastframetime = millis();

      // update_shape();      // <- doing this here causes artifacts, but is much faster drawing frame rate.
   
  }  // end update

  void update_shape() {
      
      // shapeMatrix.reset();
      // shapeMatrix.scale(myScale > 0 ? myScale : 0.01);  // avoid disappearing bug;
      // float r[] = cam.getRotations();
      // shapeMatrix.rotate(r[2], 0, 0, 1); // to fix bug with rotateZ()?
      // shapeMatrix.rotate(r[1], 0, 1, 0);
      // shapeMatrix.rotate(r[0], 1, 0, 0);
      // shapeMatrix.translate(position.x, position.y, position.z);



      shape.resetMatrix();
      shape.scale(myScale > 0 ? myScale : 0.01);  // avoid disappearing bug
      float rr[] = cam.getRotations();
      shape.rotate(rr[2], 0, 0, 1); // to fix bug with rotateZ()?
      shape.rotate(rr[1], 0, 1, 0);
      shape.rotate(rr[0], 1, 0, 0);
      shape.translate(position.x, position.y, position.z);

           
  }   

  void activate() {
      active = true;
      hidden = false;
      bornAt = millis();
      nearSeg.show();
  }
    
  void deactivate() {
      shape.setVisible(false);  // this doesn't seem to turn off deeply nested shapes, but we are using it as a flag
      hidden = true;      
      nearSeg.hide();
      active = false;
      deactivate_me = false;   // just did.
  }
      
  synchronized void findSeg(ArrayList<PVector> verts) {           // send the particle a set of vertices without offsets, and we'll create an empty set of offsets to send along

    ArrayList<PVector> vertoffs = new ArrayList<PVector>();
    findSeg(verts, vertoffs);

  }  

  synchronized void findSeg(ArrayList<PVector>  verts, ArrayList<PVector>  vertoffs) {   // send the particle class a set of vertices and their offsets and it will find the closest one.

    /*
    Init distance
    */
    float[] shortestDistsSq = { 999999999, 999999999 };

    for (PVector v : verts) {      // edit this to only look at closest?  Need to speed this up for large models. 
      
      if(boxfilter) {
       if(abs(v.x-predictpos.x) > winXsize || abs(v.y-predictpos.y) > winYsize || abs(v.z-predictpos.z) > winZsize) continue;  // filter anyting outside window box
      }
      
      if(predictpos == null) predictpos = position.copy();
        
      PVector vt = v.copy();

      if(vertoffs.size() == verts.size()) {          // if the offset list is empty or otherwise not the same as the vertex list, just ignore it.
       vt.add(vertoffs.get(verts.indexOf(v)));
      }

//      old: replaced with distSq to avoid so many sqrts
//      segdist = predictpos.dist(vt);
//      segdist = position.dist(vt);
      
      // segdistSq = distSq(predictpos, vt);
      segdistSq = distSq(position, vt);

      if (segdistSq < shortestDistsSq[0]) {
        shortestDistsSq[1] = shortestDistsSq[0];
        shortestDistsSq[0] = segdistSq;
        nearSeg.end   = nearSeg.start.copy();
        nearSeg.start = vt.copy();
      } else {
       if (segdistSq < shortestDistsSq[1]) {
         shortestDistsSq[1] = segdistSq;
         nearSeg.end = vt.copy();
       }
      }
    }

  }



  // This function implements Craig Reynolds' path following algorithm
  // http://www.red3d.com/cwr/steer/PathFollow.html
  
  synchronized void follow() {
       follow(nearSeg); 
  }
  
  synchronized void follow(Segment p) {

    // Predict position 50 (arbitrary choice) frames ahead
    // predict position 1-100 ms ahead 
    PVector predict = velocity.copy();
    // predict.normalize();
    predict.mult((mysrc.lookahead/10) * abs(gridRunnerVars.gridScale) / 1+(millis()-lastframetime) );  // should be in ms terms no longer frames
    predictpos = PVector.add(position, predict);

    // Look at the line segment
    PVector a = p.start;
    PVector b = p.end;

    // Get the normal point to that line
    normalPoint = getNormalPoint(predictpos, a, b);

    // Find target point a little further "ahead" of normal -- to do this, dot the seg with velocity
    dir = PVector.sub(b, a);

    if(velocity.dot(dir) < 0) dir = PVector.sub(a, b); // make sure it is based on our heading, not the order of segment vertices

    dir.normalize();
    dir.mult(velocity.mag() * (mysrc.lookahead/10) * abs(gridRunnerVars.gridScale) / 1+(millis()-lastframetime));  // This is now based on velocity instead of just an arbitrary 10 pixels
    target = PVector.add(normalPoint, dir);

    // How far away are we from the path?
    pathdistance = distSq(predictpos, normalPoint);
    // Only if the distance is greater than the path's radius do we bother to steer
    if (pathdistance > sq(mysrc.segradius * abs(gridRunnerVars.gridScale))) {
      online = false;
      maxsteer = mysrc.offGridSteering; 
      friction = mysrc.offGridFriction; // 0.995;
      seek(target);
    } else { 
      online = true;
      maxsteer = mysrc.onGridSteering; // 1.0;  
      friction = mysrc.onGridFriction; // 1.0;
      seek(target);
    }

  }


  // A function to get the normal point from a point (p) to a line segment (a-b)
  // This function could be optimized to make fewer new Vector objects
  synchronized PVector getNormalPoint(PVector p, PVector a, PVector b) {
    // Vector from a to p
    PVector ap = PVector.sub(p, a);
    // Vector from a to b
    PVector ab = PVector.sub(b, a);
    ab.normalize(); // Normalize the line
    // Project vector "diff" onto line by using the dot product
    ab.mult(ap.dot(ab));
    PVector normalPoint = PVector.add(a, ab);
    return normalPoint;
  }


  void applyForce(PVector force) {
    // We could add mass here if we want A = F / M
    acceleration.add(force);
  }


  // A method that calculates and applies a steering force towards a target
  // STEER = DESIRED MINUS VELOCITY
  void seek(PVector target) {
    desired = PVector.sub(target, position);  // A vector pointing from the position to the target

    // If the magnitude of desired equals 0, skip out of here
    // (We could optimize this to check if x and y are 0 to avoid mag() square root
    //if (desired.mag() == 0) return;
    // if(desired.x == 0 && desired.y == 0) {
    //   desired = velocity.copy();
    //   return;
    // }

    // Normalize desired and scale to maximum speed
    desired.normalize();
    desired.mult(PVector.sub(predictpos, position).mag());
    // Steering = Desired minus Velocity
    steer = PVector.sub(desired, velocity);
//    steer.limit(maxsteer);  // Limit to maximum steering force
    if(gridRunnerVars.legacySteering) {
      steer.limit(maxsteer * abs(gridRunnerVars.gridScale));  // Limit to maximum steering force -- sync with meander scale
    } else {
      steer.mult(pow(maxsteer,3));   // bias towards low values, so use maxsteer^3;  limit, used above, was WRONG - it is absolute, we need to limit to a fraction of the required force
    }
    applyForce(steer);
  }

  



 /////////   CALLED  BY  MAIN  DISPLAY  THREAD

  synchronized void display() {

    if(!active || deactivate_me) {
        if(!shape.isVisible() && !hidden) {
          shape.setTint(color(200, 0, 200, 0)); // should be hidden already but there's a bug, so set opacity to zero
          nearSeg.update(0, 0); // also make sure segment updates / hides
          nearSeg.display();
          hidden = true;
        }
      return;
    }

    update_shape();  // <- doing this here avoids flickering sprites at origin by keeping it in animation thread, but is slower

    nearSeg.display();

    if(gridRunnerVars.debug) {
      shape.setTint((online ? color(200, 255, 200, opacity*255) : color(255, 200, 200, opacity*255)));
    } else {
      shape.setTint(color(255, opacity * 255));
    }

    // draw debug 
    if(gridRunnerVars.debug && age > 300 && gridRunnerVars.displayParticles) {
      debugalpha = int(gridRunnerVars.debugOpacity*255*opacity);
      // radius
      PVector rad = PVector.sub(predictpos, normalPoint);
      stroke(100,200,100,debugalpha);
      strokeWeight(8);
      rad.normalize().mult(gridRunnerVars.segradius * abs(gridRunnerVars.gridScale));
      rad.add(normalPoint);
      line(normalPoint.x,normalPoint.y,normalPoint.z, rad.x, rad.y, rad.z);
      stroke(100,100,200,debugalpha);
      strokeWeight(2);
      line(normalPoint.x,normalPoint.y,normalPoint.z, predictpos.x, predictpos.y, predictpos.z);
      line(position.x,position.y,position.z, predictpos.x, predictpos.y, predictpos.z);
      stroke(200, 200, 50, debugalpha);
      strokeWeight(2);
      line(position.x, position.y, position.z, position.x+desired.x, position.y+desired.y, position.z+desired.z);
      fill(220, 50, 50, debugalpha);
      noStroke();
      pushMatrix();
      translate(target.x, target.y, target.z);
      rectMode(CENTER);
      rotateX(PI/2);
      rotateZ(PI/4);
      rect(0,0, 3, 3);
      popMatrix();

      if(boxfilter) {

        pushMatrix();
        translate(position.x, position.y, position.z);
        stroke(100, 100, 255, debugalpha*0.7);
        noFill();
        box(winXsize, winYsize, winZsize);
        popMatrix();

      }
    }

    //// draw influence and core

    if(gridRunnerVars.displayCore) {

        pushMatrix();
        translate(position.x, position.y, position.z);
        rotateX(cam.getRotations()[0]);                  // drawing billboarded circles instead of spheres
        rotateY(cam.getRotations()[1]);
        rotateZ(cam.getRotations()[2]);
        noStroke();
        fill(255, 200, 200, 10 * opacity);
        ellipse(0, 0, 2 * mysrc.coreSize * mysrc.influenceSize, 2 * mysrc.coreSize * mysrc.influenceSize);
        noFill();
        strokeWeight(3);
        stroke(255, 200, 200, 10 * opacity);
        ellipse(0, 0, 2 * mysrc.influenceSize, 2 * mysrc.influenceSize);
        popMatrix();
 
     }


  }

}

//////////////////////////////////////////////// 
////////////////////////   PARTICLE SOURCE CLASSES
//////////////////////////////////////////////// 



class ParticleSourceVars extends BehaviourEngineVars {

     String sourceName;
     int sourceRotation, burstFreq, burstQty;
     float sourceCadence, spread, heading, burstFreqRandom, burstLength, yvelocity;
     float position_x, position_y, position_z;
     boolean active;
     boolean linked = false;

     // moved here from GridRunnerVars -mg Aug 12 2020
     int lifespan, influenceSize, segradius, lookahead;
     float maxspeed, randomspeed, coreSize, influenceIntensity;
     float   onGridFriction, onGridSteering, offGridFriction, offGridSteering;

     transient Patchable sourcePatchable;

     ParticleSourceVars(String name) {

       super(name, true);

       active = true;
       linked = false;
  
       neverSave = true;

       sourceName = name;
       position_x = 200;
       position_y = 200;
       position_z = 200;

       sourcePatchable = new Patchable(this);
       sourcePatchable.realName = name;
       sourcePatchable.displayName = name;

     }

     void init(GridRunnerVars gv) {  // initialize by copying from current GridRunner settings

      sourceRotation = gv.sourceRotation;      
      spread = gv.spread;
      heading = gv.heading;
      sourceCadence = gv.sourceCadence;  // how often does it change source?
      burstFreq = gv.burstFreq;
      burstFreqRandom = gv.burstFreqRandom;
      burstLength = gv.burstLength;
      burstQty  = gv.burstQty;
      yvelocity = gv.yvelocity;

      lifespan = gv.lifespan;
      influenceSize = gv.influenceSize;
      segradius = gv.segradius;
      lookahead = gv.lookahead;

      maxspeed = gv.maxspeed;
      randomspeed = gv.randomspeed;
      coreSize = gv.coreSize;
      influenceIntensity = gv.influenceIntensity;

      onGridFriction = gv.onGridFriction;
      onGridSteering = gv.onGridSteering;
      offGridFriction = gv.offGridFriction;
      offGridSteering = gv.offGridSteering;


     }

     void copy(ParticleSourceVars s) {    //  copy all relevant settings from another source.


      position_x =      s.position_x;
      position_y =      s.position_y;
      position_z =      s.position_z;
      sourceRotation =  s.sourceRotation;      
      spread =          s.spread;
      heading =         s.heading;
      sourceCadence =   s.sourceCadence;  
      burstFreq =       s.burstFreq;
      burstFreqRandom = s.burstFreqRandom;
      burstLength =     s.burstLength;
      burstQty  =       s.burstQty;
      yvelocity =       s.yvelocity;

      active    =       s.active;
      linked    =       s.linked;


      lifespan = s.lifespan;
      influenceSize = s.influenceSize;
      segradius = s.segradius;
      lookahead = s.lookahead;

      maxspeed = s.maxspeed;
      randomspeed = s.randomspeed;
      coreSize = s.coreSize;
      influenceIntensity = s.influenceIntensity;

      onGridFriction = s.onGridFriction;
      onGridSteering = s.onGridSteering;
      offGridFriction = s.offGridFriction;
      offGridSteering = s.offGridSteering;

     }

     void setPatchable() {

       // behaviour:
       sourcePatchable.behaviour = "GridRunner";

       // input ports:
       sourcePatchable.dataPorts.add(new DataPort("active",       "false",          0.7));     // boolean takes a threshold val
       sourcePatchable.dataPorts.add(new DataPort("heading",      "0.0",            0.0, TWO_PI));
       sourcePatchable.dataPorts.add(new DataPort("sourceRotation", "0",            0, 2));
       sourcePatchable.dataPorts.add(new DataPort("burstQty",     str(burstQty),    1, 250));
       sourcePatchable.dataPorts.add(new DataPort("burstFreq",    str(burstFreq),   10, 5000));

       // output ports:


       // add my Patchable to the BehaviourEngine's patchables hashmap.
       gridRunnerVars.patchables.put(this.sourceName, sourcePatchable);   

       patcher.addPatchable(sourcePatchable);    
       
     }

     void addToGUI() {

       // add this source as a folder in the Behaviours gui, by sending an update command with param: folder and val: add;
       // uses a special version of "send_gui_OSC that has 4 parameters instead of 3, to name the target.
       send_gui_OSC("GridRunner", "folder", "add", sourceName);
       
     }
     
     void removeFromGUI() {

       // remove source as a folder in the Behaviours gui, by sending an update command with param: folder and val: remove;
       // uses a special version of send_gui_OSC that has 4 parameters instead of 3, to name the target.
       send_gui_OSC("GridRunner", "folder", "remove", sourceName);
       
     }

} 


class ParticleSource extends Thread {

    ArrayList<Particle> particles;

    ParticleSourceVars settings;

    ArrayList<PVector> vertices;
    ArrayList<PVector> vertexoffsets;

    PVector position;

    PShape myparticles;
    PShape mysegments;

    int    activeParticles = 0;    
    int    excessParticles = 0;
    int    maxParticles = 0;

    // burst control
    int    lastburst;
    int    toactivate = 0;
    int    alreadyactivated = 0;
    int    curBurstFreq = 1000;
    float  burstPctDone = 0;


    // to pause and end execution
    boolean active = true;
    boolean paused = false;
    boolean exit = false;
    boolean dying = false;

    ParticleSource() {

      super("particle_source_thread");

      particles = new ArrayList<Particle>();
      lastburst = millis(); 

      myparticles = createShape(PShape.GROUP);
      mysegments  = createShape(PShape.GROUP);

    }


    void initSource(ParticleSourceVars s) {             // source from gridrunnervars or elsewhere

      settings = s;
      position = new PVector(s.position_x, s.position_y, s.position_z);
      toactivate = settings.burstQty;

    }

    void initParticles(PImage sprite) {

      for (int n = 0; n < gridRunnerVars.totalParticles; n++) {

      Particle part = new Particle(sprite);

      if(settings != null) {
        part.setSource(settings);
      }
      
      myparticles.addChild(part.shape);          
      mysegments.addChild(part.nearSeg.myline);  
      particles.add(part);  

      part.start();
    
      }
    }

    void showParticle(Particle p) {
      p.activate();
      activeParticles++;  
    }

    void hideParticle(Particle p) {
      p.deactivate();
      activeParticles--;
    }

    /// total hack :  What if a particleSource could occasionally be asked to spit out an Excitor?  No need to
    /// manage it or anything, just instatiate it in an XYZ position, with vector determined by your heading and spread... let's see

    void generateExcitor() {
      println( settings.sourceName + " is going to try to birth an Excitor... " );
      Excitor e = excitorBehaviour.excitorSystem.addExcitor(position, excBehavVars.size - int(random(excBehavVars.size/3)));
      if(e != null) {  // it was generated successfully, now let's manipulate it!!

          // aim it to an orbit tangent to our sphere ... use SOHCAHTOA to figure out angle from here because I know my 
          // position relative to center and I know the distance 
          // out to the orbit (~2500).

          // float angle_from_origin = arctan(2500 / position.mag());

          PVector v = new PVector(0f,0f,0f);  // origin
          v.sub(position);                    // set course for the center of the sun!
          e.applyForce(v);
          // v.normalize();
          // v.mult(excBehavVars.excitorSpeedLimit);

          // e.velocity = v;

      }

    }

    public void run() {

     while(!exit) {


     maxParticles = gridRunnerVars.nParticles / max(1, gridRunnerVars.totalActiveSources);
    // particle spawning
    
    curBurstFreq = settings.burstFreq;  // for now just make these equal - won't vary except by patcher.  mg Aug 14 2020

    // ... todo: add randomness to the burstFrequency, using settings.burstFreqRandom - recalculate curBurstFreq each burst, after a burst has been fully achieved.
    //           note - don't confuse burstLength with the time - that is burstFreq.  burstLength is a float stating over how long within a burst to spread the particles.

    int checkBurst = max(millis()-lastburst-curBurstFreq, 0);   // zero if waiting, +ve if past burst trigger  
    burstPctDone = min((float(checkBurst) / (settings.burstLength * curBurstFreq)), 1.0);   // cap at 1.0

    toactivate = int(burstPctDone * settings.burstQty) - alreadyactivated;
    toactivate = max(0, toactivate); // floor at zero
    alreadyactivated += toactivate;   // remember for next time;
        
        
    if(burstPctDone == 1.0) {
      // println("burst " + alreadyactivated + " more, over " + (checkBurst) + " millis");
      lastburst = millis() - int(settings.burstLength * curBurstFreq);   // last burst was triggered in the past
      alreadyactivated = 0;
    }
     
     /// having done all that, if the source is not active, hard-set these to zero

    if(!settings.active) {
      toactivate = 0;
      alreadyactivated = 0;  
    }    

    // if we have too many particles, need to cull so that we can activate more
    if(toactivate > 0) {
      excessParticles = max((activeParticles + toactivate - maxParticles), 0);
      
      if (excessParticles > 0) {  
         cullOldestParticles( excessParticles ); // recursive function that will cull the number it is given.
      }
    }            

    
    int pcount = 0;  
    
        for (Particle part : particles) { 
        part.srcposition = position.copy();  // tell each particle where i (the source) am located

        pcount ++;
        
        // particle spawning
        
        if(!part.active) {      // this particle is not active
         
          
            if(toactivate == 0) { 
            continue; 
            }
    
            showParticle(part);
            toactivate--;
        }
        
        // we have gotten this far so this particle should exist!

        // if too many, deactivate the rest
        if(pcount > maxParticles ) {
           // println("particle is active and pcount is higher than max");
            hideParticle(part); 
            continue;
        }

        // if this is a gridrunner and we have the vertices:
        if(vertices != null && vertexoffsets != null) {
          part.findSeg(vertices, vertexoffsets);
          part.follow();
        }
        
      }

      try {
        Thread.sleep(gridRunnerVars.particleSourceVars.size() * 7);  // the more sources are going, the longer we sleep for consistent frameerate
        } catch (Exception e) {
        println("Exception sleeping: " + e);
      }

    while(paused || !active || dying) {try{Thread.sleep(100);} catch(Exception e){ }};
    
    }
    println("Source " + settings.sourceName + " has been nicely stopped.");
  }

  void endme() {
    exit = true;
  }


  void cullOldestParticles(int n) {
    
    if (n == 0) return;
    Particle oldest = null;
    int age = 0;
    
    for (Particle p : particles) {
        if (!p.active) continue;
        
        if(p.age > age) {
        age = p.age;
        oldest = p;
        }
        
    }
    if (oldest != null) {
        hideParticle(oldest);
    }
    n--;
    cullOldestParticles(n);
    
  }




  synchronized void display() {

    for (Particle p : particles) {
         // if (!p.active) continue;
        p.display();

    }

  }
    
}