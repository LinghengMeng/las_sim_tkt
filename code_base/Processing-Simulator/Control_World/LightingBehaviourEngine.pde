/*

< SAMPLE BEHAVIOUR >

< ... description - this is a simple sample code to illustrate how to make behaviours that integrate with the PBSI Simulator and control system >
< ... credits - Matt Gorbet, August 2020 >

*/

////////////////   THE BEHAVIOUR ENGINE VARIABLES - automatically get registered, saved, loaded, and ready for UI stuff.

class  LightingBehaviourVars extends BehaviourEngineVars {

    /* 
    This class holds any gui-adjustable elements as well as any state variables that need to persist across scenes.
    Use the "transient" keyword to avoid saving unnecessary variables. (see BehaviourEngineVars.pde for examples)
    */

  // need to define the variables up here so that they save properly.  Assign initial values in init();
  // the names of these are what will appear in the gui, also.

  //HashMap<String, Sample>  samples;             // this will store a set of instances of 'Sample' class.  Some behaviours want this.
     // Enum of available playbacks for River
  
  // CLOUD VARS
  String cloud_active_playback;  
  float cloud_level;                              // Max Brightness to fade active playback to
  int cloud_fade_in;                              // Fade in time
  int cloud_fade_out;                             // Fade out time

  // RIVER VARS
  String river_active_playback;  
  float river_level;                               // Max Brightness to fade active playback to
  int river_fade_in;                              // Fade in time
  int river_fade_out;                             // Fade out time

  // GROTTO VARS
  String grotto_active_playback;  
  float grotto_level;                               // Max Brightness to fade active playback to
  int grotto_fade_in;                              // Fade in time
  int grotto_fade_out;                             // Fade out time

  // TRANSIENT VARS
  transient String grotto_last_playback;  // this won't get saved or loaded.
  transient float grotto_last_level;

  transient String river_last_playback;
  transient float river_last_level;

  transient String cloud_last_playback;  
  transient float cloud_last_level;
  
  

  LightingBehaviourVars() {
          super("LightingBehaviourEngine", false);   // <-  SUPER IMPORTANT to pick a name for this behaviour and use it consistently incl caps.
                                      //     Don't use spaces.  This will get used for naming presets, in finding gui elements, messaging, etc.
  }

  void init() {




    //display = false; 
    
    //samples = new HashMap<String, Sample>();
  }
}

////////////////   THE ACTUAL BEHAVIOUR ENGINE

class LightingBehaviour extends Thread {

  // needed for thread
  boolean exit = false;

  // your custom internal variables for this behaviour:
  int lastPlaybackVal;
  int playbackVal;


    // Client Ip & Port for Lighting Control board
  String lightClientIp = "10.30.64.180";
  int lightClientPort = 8005;

  OscP5 lighting_osc = new OscP5(this, lightClientPort);
  NetAddress lightingLocation;
  OscMessage oscMsg;
  
  HashMap<String, Integer> grottoPlaybacks = new HashMap<String, Integer>();
  HashMap<String, Integer> riverPlaybacks = new HashMap<String, Integer>();
  HashMap<String, Integer> cloudPlaybacks = new HashMap<String, Integer>();




  //  THESE TWO HASHMAPS define what actuators in the sculpture are relevant to this influence, 
  //  and store their positions.  This is used in method setActuatorInfluences() to provide them 
  //  with an influence from this behaviour.

  //HashMap<String, PVector> relevantActuators = new HashMap<String, PVector>();  // determined at startup by using name filtering - eg. only DRs, or just part of the sculpture
  //HashMap<String, Float>   actuatorInfluences = new HashMap<String, Float>();       // this will have the same keys as relevantActuators:  <node_id>:<device> eg: 322345:MO3

  void fade_loop(float startValue, float fadeAmount, int fadeTime, int playback, boolean inOut){
    float increment = fadeAmount/fadeTime;
    for (int i = 0; i < fadeTime; i++){
        if (inOut){startValue += increment;}
        else{startValue -= increment;}

        println(startValue);
        oscMsg = new OscMessage("/cs/playback/" + lastPlaybackVal + "/level/" + Float.toString(startValue));
        lighting_osc.send(oscMsg, lightingLocation);
    }
  }

  void LightingBehaviour() {

    //  Get the relevant actuator hashmap (name and PVec of location)
    //relevantActuators.putAll(dl.get_actuator_coordinates_by_name("NR"));        //  this uses a mask to choose actuators based on thier names
    //relevantActuators.putAll(dl.get_actuator_coordinates_by_name("TG", "DR"));  //  up to two strings can be used to narrow the choice, and it
    //relevantActuators.putAll(dl.get_actuator_coordinates_by_name("MO"));        //  can be run multiple times if necessary to filter for the actuators you need
    

    //  DO CUSTOM CONSTRUCTOR STUFF HERE:



  
    /////  ** NOTE: we don't create our sampleBehaviourVars object here - it is owned globally and created in control_world.
  }

  void run() {                  // behaviours are threaded.  This starts it. 

    println("LightingBehaviour is running... " );

    // This really isnt the right place
    // to define these variables
    // but everywhere else is giving me NullPointerExceptions
    // and I am tired 
    // - KC

    grottoPlaybacks.put("off", -1);
    grottoPlaybacks.put("dim", 11);
    grottoPlaybacks.put("bright",12);


    riverPlaybacks.put("off", -1);
    riverPlaybacks.put("narrow", 13);
    riverPlaybacks.put("wide",14);
    

    cloudPlaybacks.put("off", -1);
    cloudPlaybacks.put("narrow", 15);
    cloudPlaybacks.put("wide",16);

    lightingBehaviourVars.river_last_playback = "off";
    lightingBehaviourVars.grotto_last_playback = "off";
    lightingBehaviourVars.cloud_last_playback = "off";

    lightingBehaviourVars.river_active_playback = "off";
    lightingBehaviourVars.river_level = 1.0;
    lightingBehaviourVars.river_fade_in = 5;
    lightingBehaviourVars.river_fade_out = 5;
    
    lightingBehaviourVars.grotto_active_playback = "off";
    lightingBehaviourVars.grotto_level = 1.0;
    lightingBehaviourVars.grotto_fade_in = 5;
    lightingBehaviourVars.grotto_fade_out = 5;

    lightingBehaviourVars.cloud_active_playback = "off";
    lightingBehaviourVars.cloud_level = 1.0;
    lightingBehaviourVars.cloud_fade_in = 5;
    lightingBehaviourVars.cloud_fade_out = 5;


    lightingLocation = new NetAddress(lightClientIp,lightClientPort);

    while(!exit) {

      try{
        Thread.sleep(lightingBehaviourVars.thread_update_rate + time_lapse_pause);   // necessary for performance.  Adjustable.
      } catch (Exception e) {
        println(e);
      }


      //// MAIN LOOP.

      //// Typically something like 
      //       1. clear actuator influences
      //       2. manage any behaviour-system-wide things, like creating or destroying new 'samples'
      //       3. update all the 'samples' in sampleBehaviourVars.samples, responding to new input or parameters
      //       4. set actuator influences
      //       5. send the actuator influences to control_world


      // Since we're not controlling the sculpture we don't do any of the above,
      // Instead we wait for a change in the active playback
      // and when one is detected we fade out the old playback
      // and fade in the new 
      
      // Grotto Logic
      if (lightingBehaviourVars.grotto_active_playback != lightingBehaviourVars.grotto_last_playback){
  
        println("Grotto: " + lightingBehaviourVars.grotto_active_playback);

        playbackVal = grottoPlaybacks.get(lightingBehaviourVars.grotto_active_playback);
        lastPlaybackVal = grottoPlaybacks.get(lightingBehaviourVars.grotto_last_playback);
        float fadeLevel = lightingBehaviourVars.grotto_level;

        if (playbackVal == -1){
          playbackVal = lastPlaybackVal;
          fadeLevel = 0.0;
        }
        
        //fade out
        fade_loop(lightingBehaviourVars.grotto_last_level, lightingBehaviourVars.grotto_last_level, lightingBehaviourVars.grotto_fade_out, lastPlaybackVal,false);

        // Fade in new playback
        fade_loop(0.0, fadeLevel, lightingBehaviourVars.grotto_fade_in, playbackVal,true);

        lightingBehaviourVars.grotto_last_level = lightingBehaviourVars.grotto_level;
        lightingBehaviourVars.grotto_last_playback = lightingBehaviourVars.grotto_active_playback;

      }
  
      // River Logic
      if (lightingBehaviourVars.river_active_playback != lightingBehaviourVars.river_last_playback){
        
        println("River: " + lightingBehaviourVars.river_active_playback);

        playbackVal = riverPlaybacks.get(lightingBehaviourVars.river_active_playback);
        lastPlaybackVal = riverPlaybacks.get(lightingBehaviourVars.river_last_playback);
        float fadeLevel = lightingBehaviourVars.river_level;

        if (playbackVal == -1){
          playbackVal = lastPlaybackVal;
          fadeLevel = 0.0;
        }
        
        //fade out
        fade_loop(lightingBehaviourVars.river_last_level, lightingBehaviourVars.river_last_level, lightingBehaviourVars.river_fade_out, lastPlaybackVal,false);

        // Fade in new playback
        fade_loop(0.0, fadeLevel, lightingBehaviourVars.river_fade_in, playbackVal,true);

        lightingBehaviourVars.river_last_level = lightingBehaviourVars.river_level;
        lightingBehaviourVars.river_last_playback = lightingBehaviourVars.river_active_playback;
      }

      // Cloud Logic
      if (lightingBehaviourVars.cloud_active_playback != lightingBehaviourVars.cloud_last_playback){

        println("cloud: " + lightingBehaviourVars.cloud_active_playback);

        playbackVal = cloudPlaybacks.get(lightingBehaviourVars.cloud_active_playback);
        lastPlaybackVal = cloudPlaybacks.get(lightingBehaviourVars.cloud_last_playback);
        float fadeLevel = lightingBehaviourVars.cloud_level;

        if (playbackVal == -1){
          playbackVal = lastPlaybackVal;
          fadeLevel = 0.0;
        }
        
        //fade out
        fade_loop(lightingBehaviourVars.cloud_last_level, lightingBehaviourVars.cloud_last_level, lightingBehaviourVars.cloud_fade_out, lastPlaybackVal,false);

        // Fade in new playback
        fade_loop(0.0, fadeLevel, lightingBehaviourVars.cloud_fade_in, playbackVal,true);

        lightingBehaviourVars.cloud_last_level = lightingBehaviourVars.cloud_level;
        lightingBehaviourVars.cloud_last_playback = lightingBehaviourVars.cloud_active_playback;
      }




      // 1.
      //clearActuatorInfluences();

      // 2. 

      // 3.
      //for(Sample s : sampleBehaviourVars.samples.values()) {

        // do stuff with each 's'
      //   s.update();

      //}

      // 4.
      //setActuatorInfluences(); 

      // 5.
      // send the influences to control_world (the naming is legacy, shouldn't include _excitor_ here but does -mg Aug 2020)
      //control.set_actuator_excitor_influences(actuatorInfluences, "SB");  // <- this two-letter capital tag is a unique ID that gets used in all messaging


    }
    // any cleanup stuff can be put here.  (end this behaviour by setting 'exit' to 'true')

    println(" LightingBehaviour exited cleanly... " );
  }

  ///////  PUT ALL YOUR BEHAVIOUR-SPECIFIC FUNCTIONS HERE.  use the 'synchronized' tag to be safe because this is threaded.
  //synchronized void doSampleBehaviourCalculationsEtc() {  // <- this is just a demo, make your own functions.

      // another example 

  //}

  //synchronized void findNearestSamples() {

      // another example 

  //}



  //  display function - do any drawing, screen calls, setting colors, etc. for the display here.
  //  Note this is NOT in the behaviour thread, because all displaying has to be in the 
  //  main processing thread to avoid visual glitches and unpredictable behaviour.  
  //  This gets called in sequence with other behaviours within control_world's draw loop.
  synchronized public void display() {

      // Just going to draw a textbox to display the lighting preset currently active
      

      // typically iterate through each of the child 'samples' and ask them to display themselves.
  
  }
}

