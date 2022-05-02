/*

< SAMPLE BEHAVIOUR >

< ... description - this is a simple sample code to illustrate how to make behaviours that integrate with the PBSI Simulator and control system >
< ... credits - Matt Gorbet, August 2020 >

*/

////////////////   THE BEHAVIOUR ENGINE VARIABLES - automatically get registered, saved, loaded, and ready for UI stuff.

class  SampleBehaviourVars extends BehaviourEngineVars {

    /* 
    This class holds any gui-adjustable elements as well as any state variables that need to persist across scenes.
    Use the "transient" keyword to avoid saving unnecessary variables. (see BehaviourEngineVars.pde for examples)
    */

  // need to define the variables up here so that they save properly.  Assign initial values in init();
  // the names of these are what will appear in the gui, also.
  int int_1, int_2, int_3, etc_ints;            // name these - will become sliders in gui
  float float_1, float_2, float_3, etc_floats;  // name these - will become sliders in gui
  boolean display, bool_1, bool_2, etc_bools;   // will become checkboxes in gui - useful for flags.
  HashMap<String, Sample>  samples;             // this will store a set of instances of 'Sample' class.  Some behaviours want this.

  boolean influenceActive;   // common variables used by many behaviours
  float   masterIntensity;   // common variables used by many behaviours

  transient int int_t;  // this won't get saved or loaded.
  

  SampleBehaviourVars() {
          super("SampleBehaviour", false);   // <-  SUPER IMPORTANT to pick a name for this behaviour and use it consistently incl caps.
                                      //     Don't use spaces.  This will get used for naming presets, in finding gui elements, messaging, etc.
  }

  void init() {
        
    int_1 = 3;                 //  The amount of electric cells flowing from actuator to actuator
    float_1 = 0.3;             // Every time a next actuator is selected, it selects based on the nearest ones, neighbourRange sets out of how many nieghbours chosen
    bool_1 = true;             // The rate at which the cells jump between actuators

    display = false; 

    masterIntensity = 1.0;
    influenceActive = true;
    
    samples = new HashMap<String, Sample>();
  }
}

////////////////   THE ACTUAL BEHAVIOUR ENGINE

class SampleBehaviour extends Thread {

  // needed for thread
  boolean exit = false;

  // your custom internal variables for this behaviour:

  ArrayList<Sample> activeSamples;
  int my_important_int;
  float curIntensity = 0.0;
  boolean etc = false;


  //  THESE TWO HASHMAPS define what actuators in the sculpture are relevant to this influence, 
  //  and store their positions.  This is used in method setActuatorInfluences() to provide them 
  //  with an influence from this behaviour.
  HashMap<String, PVector> relevantActuators = new HashMap<String, PVector>();  // determined at startup by using name filtering - eg. only DRs, or just part of the sculpture
  HashMap<String, Float>   actuatorInfluences = new HashMap<String, Float>();       // this will have the same keys as relevantActuators:  <node_id>:<device> eg: 322345:MO3


  SampleBehaviour() {

    //  Get the relevant actuator hashmap (name and PVec of location)
    relevantActuators.putAll(dl.get_actuator_coordinates_by_name("NR"));        //  this uses a mask to choose actuators based on thier names
    relevantActuators.putAll(dl.get_actuator_coordinates_by_name("TG", "DR"));  //  up to two strings can be used to narrow the choice, and it
    relevantActuators.putAll(dl.get_actuator_coordinates_by_name("MO"));        //  can be run multiple times if necessary to filter for the actuators you need


    //  DO CUSTOM CONSTRUCTOR STUFF HERE:





    /////  ** NOTE: we don't create our sampleBehaviourVars object here - it is owned globally and created in control_world.
  }

  void run() {                  // behaviours are threaded.  This starts it. 

    println(" SampleBehaviour is running... " );

    while(!exit) {

    try{
      Thread.sleep(sampleBehaviourVars.thread_update_rate + time_lapse_pause);   // necessary for performance.  Adjustable.
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


    // 1.
    clearActuatorInfluences();

    // 2. 

    // 3.
    for(Sample s : sampleBehaviourVars.samples.values()) {

       // do stuff with each 's'
       s.update();

    }

    // 4.
    setActuatorInfluences(); 

    // 5.
    // send the influences to control_world (the naming is legacy, shouldn't include _excitor_ here but does -mg Aug 2020)
   
   // turned off for now - possible bug to chase down later: "/CONTROL/INFLUENCE_MAP/127.0.0.1/432838 SAMPLE BEHAVIOUR DR3 FALSE"
   //                      should not be sending "SAMPLE BEHAVIOUR" BUT RATHER "SB".  ODD. -mg aug 12 2020
   //   control.set_actuator_excitor_influences(actuatorInfluences, "SB");  // <- this two-letter capital tag is a unique ID that gets used in all messaging


    }
    // any cleanup stuff can be put here.  (end this behaviour by setting 'exit' to 'true')

    println(" SampleBehaviour exited cleanly... " );
  }

  ///////  PUT ALL YOUR BEHAVIOUR-SPECIFIC FUNCTIONS HERE.  use the 'synchronized' tag to be safe because this is threaded.
  synchronized void doSampleBehaviourCalculationsEtc() {  // <- this is just a demo, make your own functions.

      // another example 

  }

  synchronized void findNearestSamples() {

      // another example 

  }


  //////  KEEP THESE FUNCTIONS 
  // generic function to clear actuator influences at the start of each cycle so they don't build up.
  synchronized public void clearActuatorInfluences() {

    try {
      for(Map.Entry<String, PVector> e : relevantActuators.entrySet()) {
                actuatorInfluences.put(e.getKey(), 0.0);
      }
    } catch (Exception x) {
      println(x);
    }
  }

  // use your own logic to determine how the actuators are influenced by this behaviour engine
  synchronized void setActuatorInfluences() {

    if(sampleBehaviourVars.influenceActive) {
      for(Map.Entry<String, PVector> e : relevantActuators.entrySet()) {

        // for example, for each of my 'samples' I'll get an actuator's position as a PVector with 'e.getValue()'
        for (Sample s : sampleBehaviourVars.samples.values()) {
          PVector actuatorPosition = e.getValue();

          float inf = s.figureOutValue(actuatorPosition);     // <- replace this with your calculations

          inf *= sampleBehaviourVars.masterIntensity;             // <- limit the influence to current MasterIntensity 
          actuatorInfluences.put(e.getKey(), inf);            // <- this is where we set the specific influence value
          
        }  
      }
    }

  }

  //  display function - do any drawing, screen calls, setting colors, etc. for the display here.
  //  Note this is NOT in the behaviour thread, because all displaying has to be in the 
  //  main processing thread to avoid visual glitches and unpredictable behaviour.  
  //  This gets called in sequence with other behaviours within control_world's draw loop.
  synchronized public void display() {

      
      // typically iterate through each of the child 'samples' and ask them to display themselves.
  
  }
}



////////////////   ELEMENTS USED BY THE BEHAVIOUR - not all behaviour uses these, some are simpler

class Sample {   
  
  // local variables for this element
  int int_1, etc; //   use your own.

  // constructor
  Sample() {             

  }

  // update - typically called once per main loop of the behaviour thread, but can do whatever makes sense here.
  void update() {

  }

  // display - this is where individual elements can draw themselves - will be called as part of the main draw() thread
  //  (be sure to use pushMatrix() and popMatrix() at start and end, and reset any styles like strokeWidth to avoid impacting subsequent calls
  void display() {
    if(!sampleBehaviourVars.display) return;

    pushMatrix();

    // do some visual stuff here

    popMatrix();
  }
  
  ///// any other helper methods that elements of this behaviour need go under here....
  float figureOutValue(PVector v) {

    float result = 0.0;

    // ... for example

    return(result);
  }


}
