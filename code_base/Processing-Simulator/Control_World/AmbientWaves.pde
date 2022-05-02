



 class AmbientWavesVars extends BehaviourEngineVars {

//   float   velocity, amplitude, period, angle;
   int     num_waves;
   boolean display;
   boolean influenceActive;
   float   masterIntensity;

   ArrayList<WaveFront> waves;

   AmbientWavesVars() {
      super("AmbientWaves", false);

      waves = new ArrayList<WaveFront>();    
   }

   void init() {   // load from file if present, if not set to these values (should never really need to edit these after first run

      neverSave = false;

      num_waves = 15;                       // (max) number of waves in this system
      thread_update_rate = 20;             // how long in ms this thread should sleep per cycle (min should be about 10)
      display = true;
  
      influenceActive = true;
      masterIntensity = 1.0;

   }

 }

//////////////// 

class AmbientWaves extends Thread {
    
  HashMap<String, Float>   actuatorInfluences = new HashMap<String, Float>();     // this will have the same keys as relevantActuators:  <node_id>:<device> eg: 322345:MO3

  int wavecount = 0;

  AmbientWaves() {                                                                // constructor for this influence engine

    super("Ambient_Waves_Thread");                                                // name the thread for debugging purposes - jvisualVM can display this if we are sampling the process
                                   
  }

  void run() {                     
    
    println("Ambient Waves is running.");
    ambientWavesVars.presetchanged = true; // be sure I initialize the waves at start.


                                                   // main thread loop for this influence engine
    while(true) {

      try{
        Thread.sleep(ambientWavesVars.thread_update_rate + time_lapse_pause);                        // prevents high CPU usage
      } catch (Exception e) {
        println(e);
      }

    // check if we should rebuild sources (ie preset changed)
    if(ambientWavesVars.presetchanged) {

      ambientWavesVars.presetchanged = false;
      println("New Ambient Waves preset, setting up waves");
      
      initWaves();

    }


      if(ambientWavesVars.influenceActive) {

        for (WaveFront w : ambientWavesVars.waves) {
          w.clearActuatorInfluences();                                                // clears actuatorInfluences since they are cumulative (similar to backround(color))
        }                 
        for (WaveFront w : ambientWavesVars.waves) {
          // println(" ... about to update wave " + w.sourceName + " after clearing vars.");
          w.update();                                                             // update each wavefront
        }                 

        control.set_actuator_excitor_influences(actuatorInfluences, "WV");        // send influences to the system

      }
    }
  }
  
  synchronized public void addWave(String waveName) {

    wavecount = ambientWavesVars.waves.size() + 1;

    if(ambientWavesVars.waves.size() < ambientWavesVars.num_waves) {

     WaveFront w = new WaveFront(waveName, wavecount);
     ambientWavesVars.waves.add(w);
     w.needToSave = true;
     ambientWavesVars.needToSave = true;
     w.addToGUI();

    }

  }

  synchronized void initWaves() {

  // make new waves for each saved wave in ambientWavesVars, if any - this is a bit convoluted because we need to rebuild them completely.
  // it happnes because they were loaded by GSON and set up a nested array of data structures but not full classes.  We do this with 
  // gridrunner particle sources also.  

    if(ambientWavesVars.waves != null) {

      ArrayList<WaveFront> temp_waves = new ArrayList<WaveFront>();  // create an empty temporary array list.

      println(" AmbientWavesVars now has " + ambientWavesVars.waves.size() + " waves.");

      for(WaveFront w : ambientWavesVars.waves) {
          // since these are loaded by GSON, we need to explicitly make new ones (run the constructor) so that they can be 
          // properly registered as BehaviourEngineVars (and ultimately Patchable, etc)  
          // So we create new ones, then transfer the existing info over.  -mg Aug 5 2020 (GR) & Aug 16, 2020 (WV)

          WaveFront temp_w = new WaveFront(w.actuatorMask, w.wavenum);
          temp_w.copy(w);
          temp_waves.add(temp_w);
      } 
      
      if( temp_waves.size() == 0 ){ 
        println(" Whoops, where did all my waves go? " );  // debugging
      }

      // now replace the ambientWavesVars version:
      ambientWavesVars.waves = temp_waves;
    }
  }


  synchronized public void display() {                                            // This does any displaying on screen of influence engine data

    if(!ambientWavesVars.display || !ambientWavesVars.influenceActive) return;

    // display overall info for ambientwaves system first


    // display each wavefront
    for (WaveFront w : ambientWavesVars.waves) {
      w.display();
    }

  }


}

////////////////////////////   WAVEFRONT - each wave is an instance of these

class WaveFront extends BehaviourEngineVars{

  float velocity, amplitude, period, angle;
  String sourceName;
  String actuatorMask;
  int wavenum;
  transient float distance_travelled;
  transient long  last_millis;
  transient int   elapsed_millis;
  boolean waveActive;

  int delay = 1000;         // not used.

  transient HashMap<String, PVector> myRelevantActuators  = new HashMap<String, PVector>();   // determined at startup by using name filtering - eg. only DRs, or just part of the sculpture

  WaveFront(String mask, int num) {

      super("Wave_" + mask + "_" + str(num), true);

      actuatorMask = mask;
      wavenum = num;     
      
      sourceName = ("Wave_" + actuatorMask + "_" + str(wavenum));

      velocity = 0.1;              // speed of travel in units of a wave front (per second)
      amplitude = 0.25;            // master gain for this influence engine (height of wave)
      period   = 0.2;
      angle    = HALF_PI; 
      elapsed_millis = 0;
      last_millis = tl_millis();

      waveActive = true;

      myRelevantActuators.putAll(dl.get_actuator_coordinates_by_name(actuatorMask));      

      neverSave = true;  // this is a sub-behaviour-engine-var.
      needToSave = true; // need this to signal parent to save though.
  }


void copy(WaveFront w) {    //  copy all relevant settings from another source.


      velocity    = w.velocity;      
      amplitude   = w.amplitude;         
      period      = w.period;
      angle       = w.angle;

      waveActive  = w.waveActive;

     }



  // special case for Ambient Waves - putting the clearing actuators and the setting relevant as "per wave" so that we cna have different waves do different htings.

  synchronized public void clearActuatorInfluences() {
    try {
      for(Map.Entry<String, PVector> e : myRelevantActuators.entrySet()) {
                ambientWaves.actuatorInfluences.put(e.getKey(), 0.0);
      }
    } catch (Exception x) {
      println(x);
    }
  } 

  synchronized public void update() {
    if(!waveActive) return;
    try{
      elapsed_millis = int(tl_millis() - last_millis);
      setActuatorInfluences();
      last_millis = tl_millis();
    } catch(Exception x) {
      println(" *** Exception updating AW " + sourceName + ": " + x );
    }
  }


  synchronized public void setActuatorInfluences() {  

        float this_influence;
        float new_influence;

//        distance_travelled += elapsed_millis * velocity/100.;
        distance_travelled += elapsed_millis * velocity/100.;

//        println(sourceName + ": updating " + myRelevantActuators.size() + " actuators.");

        for(Map.Entry<String, PVector> e : myRelevantActuators.entrySet()) {

            PVector act_coords = e.getValue();
            PVector flatcoord = new PVector(act_coords.x, act_coords.y);
            flatcoord.rotate(angle);

            try {

            //  float wave_val = 0.5 + 0.5*(sin((flatcoord.x*(1-period)/80. + distance_travelled)));
              float wave_val = 0.5 + 0.5 * (sin( (PI * flatcoord.x/(5000*period) + distance_travelled) ));
                   
              this_influence = wave_val * amplitude * ambientWavesVars.masterIntensity * masterBehaviourIntensity;             
              new_influence  = min(ambientWaves.actuatorInfluences.get(e.getKey()) + this_influence, masterBehaviourIntensity);           // cap the cumulative influence at 1.0
              ambientWaves.actuatorInfluences.put(e.getKey(), new_influence);       

            } catch (Exception x) {
              println(x);
            }
        }
  }

      void addToGUI() {

       // add this source as a folder in the Behaviours gui, by sending an update command with param: folder and val: add;
       // uses a special version of "send_gui_OSC that has 4 parameters instead of 3, to name the target.
       send_gui_OSC("AmbientWaves", "folder", "add", sourceName);
       
     }
     
     void removeFromGUI() {

       // remove source as a folder in the Behaviours gui, by sending an update command with param: folder and val: remove;
       // uses a special version of send_gui_OSC that has 4 parameters instead of 3, to name the target.
       send_gui_OSC("AmbientWaves", "folder", "remove", sourceName);
       
     }


  synchronized public void display() {                                                                  // influence representation on screen

      if(!waveActive) return;
      // display info for this wavefront (maybe an arrow?)  

      //println(" About to display: " + sourceName );

      pushMatrix();
      pushStyle();
      rotateZ(PI - angle);
      translate(0, 0, 50-floor_height);

      float bound = 5000;
      float step  = bound/100.;

      // patch disc

      for(float x = bound ; x > -bound; x -= step) {

        float val = 0.5 + 0.5 * (sin( (PI * x/(bound*period) - distance_travelled) ));
        strokeWeight(1);
        stroke(255, int(150*amplitude*ambientWavesVars.masterIntensity*val));
        float chordedge = sqrt(bound*bound-(x*x));

        line(x, -chordedge, x, chordedge);

      }

      // wave circle outline
      strokeWeight(2);
      stroke(255, int(150*amplitude*ambientWavesVars.masterIntensity));
      ellipse(0, 0, (period * 2 * bound), (period * 2 * bound));

      // arrow
      strokeWeight(3);
      stroke(255, int(150*amplitude*ambientWavesVars.masterIntensity));
      line(0, 0, 0, (period) * 5000, 0, 0);
      line(period*bound, 0, 0, period*bound - period*bound/20., period*bound/20., 0);
      line(period*bound, 0, 0, period*bound - period*bound/20., 0-period*bound/20., 0);

      // arrow label
      noStroke();
      fill(255, int(150*amplitude*ambientWavesVars.masterIntensity));
      textSize(200);
      text(sourceName, (period) * bound + bound/50, -bound/50, 0);

      // overall disc outline and center dot
      fill(100, int(255*ambientWavesVars.masterIntensity));
      ellipse(0, 0, bound/50, bound/50);

      noFill();
      strokeWeight(4);
      stroke(100, int(255*ambientWavesVars.masterIntensity));
      ellipse(0, 0, 2*bound, 2*bound);

      popStyle();
      popMatrix();                                 

  }

}
