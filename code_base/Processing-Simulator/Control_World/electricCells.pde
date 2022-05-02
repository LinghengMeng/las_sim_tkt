/*

ELECTRIC CELLS

This behaviour creates fast patterns by jumping between actuators within
a given Range (nearest neighbours), at a given Rate (ms).

The purpose is to generate semi-random paths that look like electric shocks are moving
through the Scultpture

Author: Matt Gorbet, based on concept by Poul Holleman


*/

class  ElectricCellVars extends BehaviourEngineVars {

    /* 
    This class holds the dynamic parameters of Electric Cells
    */

  int neighbourRange, cellCount, rate, ec_update_rate, trigger_length;
  float trigger_chance, trigger_length_random, masterIntensity;
  boolean display;
  boolean active;
  
  transient boolean triggerNow = false;
  

  ElectricCellVars() {
          super("ElectricCells", false);
  }

  void init() {
        
    cellCount = 5;          //  The amount of electric cells flowing from actuator to actuator
    neighbourRange = 3;     // Every time a next actuator is selected, it selects based on the nearest ones, neighbourRange sets out of how many nieghbours chosen
    rate = 33;             // The rate at which the cells jump between actuators
    masterIntensity = 1.0;   // Master intensity
    trigger_chance = 0.01;  
    trigger_length = 300;
    trigger_length_random = 0.5;  // will be at least this x length long
    display = false;        // for this one, we'll see its action in the actuators, so no need for a real display except in debugging
    
  }

   // overloaded for excitor-specific functions.  Also calls super() to catch generic ones like revealPatcher.
  
   void executeDatCommand(String command, String value) {
      super.executeDatCommand(command, value);

      println(behaviourName + " Got a command: " +command+ " | " + value);

      switch(command) {
        case "triggerElectricCell":
            triggerNow = true;
        break;
      }
   }

}

////////////////

class ElectricCellSystem extends Thread {

  ArrayList<ElectricCell> electricCells;
  ArrayList<Integer> curActiveCells;
  int delta, prevDelta; //to calculate the clock rate
  int numDoublerebelstars;
  int maxActiveCells;
  long trigger_time;
  float curIntensity = 0.0;
  boolean triggered = false;
  int trig_len;
  ArrayList<PVector> doubleRSlocations;
  // ArrayList<DRmapper> drMapper; //to link the DR-list-indeces with all-actuator-indeces
  //ArrayList<Float> actuatorInfluences;
  HashMap<String, PVector> relevantActuators = new HashMap<String, PVector>();  // determined at startup by using name filtering - eg. only DRs, or just part of the sculpture
  HashMap<String, Float>   actuatorInfluences = new HashMap<String, Float>();       // this will have the same keys as relevantActuators:  <node_id>:<device> eg: 322345:MO3

  Patchable ecPatchable;

  ElectricCellSystem() {

    trigger_time = tl_millis();
    /*
    Get the relevant actuator hashmap (name and PVec of location)
    */

    relevantActuators.putAll(dl.get_actuator_coordinates_by_name("TG", "DR"));
    relevantActuators.putAll(dl.get_actuator_coordinates_by_name("SM"));

    curActiveCells = new ArrayList<Integer>();
    maxActiveCells = 17;
    numDoublerebelstars = relevantActuators.size();

    trig_len = electricCellVars.trigger_length;

    /*
    Create an Electric Cell for every Double Rebel Star
    */
    
    electricCells = new ArrayList<ElectricCell>();
    
    for(PVector ec_location : relevantActuators.values()) {
      electricCells.add(new ElectricCell(ec_location));
    }

    /*
    Select random RS to start sequence
    */
    for (int i=0; i<maxActiveCells; i++) {
      curActiveCells.add(int(random(numDoublerebelstars)));
    }



    ecPatchable = new Patchable(this);
    ecPatchable.realName = "ElectricCells";
    ecPatchable.displayName = "ElectricCells";

    setPatchable();


  }


  void setPatchable() {

    // behaviour:
    ecPatchable.behaviour = "ElectricCells";

    // input ports:
    ecPatchable.dataPorts.add(new DataPort("triggerNow", "false",  0.2));

    // output ports:

    // add my Patchable to the Electric Cells Engine's patchables hashmap.
    electricCellVars.patchables.put("ElectricCells", ecPatchable);   

    patcher.addPatchable(ecPatchable);    
    
  }


  void run() {

    findNearestCells();

    while(true) {

    try{
      Thread.sleep(electricCellVars.thread_update_rate + time_lapse_pause);
    } catch (Exception e) {
      println(e);
    }

    /* 
    Show cells if currently triggered
    */


    if(triggered) {

      curIntensity = electricCellVars.masterIntensity;

      if(tl_millis()-trigger_time > trig_len) {
        triggered = false;
      }

    } else {
      curIntensity = 0.0;

      if(random(1) < electricCellVars.trigger_chance || electricCellVars.triggerNow) {
        trigger_time = tl_millis();
        trig_len = electricCellVars.trigger_length - int( (random(electricCellVars.trigger_length_random)) * electricCellVars.trigger_length );
        triggered = true;
        electricCellVars.triggerNow = false;
      }
    }


    clearActuatorInfluences();
    
    /*
    Update cell positions every X milliseconds (rate)
    */
    delta = tl_millis()%electricCellVars.rate;
    if (delta-prevDelta<0) {

        /*
        Clear influences at start of cycle
        so that actuators reset before the influences cumulate
        */
        //  clearActuatorInfluences();

        if(electricCellVars.active) {
         
        selectNextNearCell();
        setActives();
        setActuatorInfluences(); 

        };

        /*
        Set actuator influences
        */
        control.set_actuator_excitor_influences(actuatorInfluences, "EC");

    }
    prevDelta = delta;
    
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


  synchronized void setActives() {
    /*
    Set cells to active according to array of current active cell indeces
    */
    for (int c=0; c<electricCellVars.cellCount; c++) {  
        electricCells.get(curActiveCells.get(c)).active = triggered; // set them to true if triggered
    }   

    /*
    Set other cells to non-active
    */
    for (int a=0; a<electricCellSystem.numDoublerebelstars; a++) {
      if (!curActiveCells.subList(0, electricCellVars.cellCount).contains(a)) electricCells.get(a).active = false;
    }
  }

  /*
  Select next near cell to activate based on neighbourRange
  */
  synchronized void selectNextNearCell() {
    for (int i=0; i<electricCellVars.cellCount; i++) {
      curActiveCells.set(i, electricCellSystem.electricCells.get(curActiveCells.get(i)).nearestCells.get(int(random(electricCellVars.neighbourRange))));
    }
  }

  /*
  List all distances for every Cell, between every Cell
  */
  synchronized void findNearestCells() {
    for (int i=0; i<numDoublerebelstars; i++) {
      electricCells.get(i).findNearestCells();
    }
  }

  /*
  Set actuator influences based on whether Cells are active or not
  */
  synchronized void setActuatorInfluences() {

      for(Map.Entry<String, PVector> e : relevantActuators.entrySet()) {
        for (ElectricCell ec : electricCells) {
          if (ec.loc.equals(e.getValue())) {
            float inf = (ec.active ? 1.0 : 0.0);
            inf *= electricCellVars.masterIntensity;
            actuatorInfluences.put(e.getKey(), inf);
          }
        }  
      }

  }

  synchronized public void display() {
    if(!electricCellVars.display) return;


    for (ElectricCell ec : electricCells) {
      ec.display();
    }

  }

}



class ElectricCell {

  PVector loc;
  FloatList allCellDistances;
  IntList nearestCells;
  boolean active;

  ElectricCell(PVector _loc) {

    loc = _loc;
    allCellDistances = new FloatList();
  }


  /*
  Display to be used for debug purposes, as the actuators show behaviour
  */
  void display() {
    if(!electricCellVars.display) return;

    pushMatrix();
    translate(loc.x, loc.y, loc.z);

    if (active) {
      stroke(200);
      fill(200);
      sphere(20);
    }
    popMatrix();
  }

  void findNearestCells() {

    /* 
    List and sort Cell indeces based on distances from near to far
    */

    nearestCells = new IntList(electricCellSystem.numDoublerebelstars);

    /*
    List all Cell distances
    */
    for (int cellIndex=0; cellIndex<  electricCellSystem.numDoublerebelstars; cellIndex++) {
      allCellDistances.set(cellIndex, loc.dist( electricCellSystem.electricCells.get(cellIndex).loc));
    }

    /*
    Sort Cell distances
    */
    FloatList allCellDistancesSorted = allCellDistances.copy();
    allCellDistancesSorted.sort();


    int nextSlot = 0;
    for (int i=1; i<electricCellSystem.numDoublerebelstars; i++) {
      /*
      Start loop at 1 to ignore distance to self (=0.)
      */  
      for (int cellIndex=1; cellIndex<electricCellSystem.numDoublerebelstars; cellIndex++) {
        /*
        by matching the values of the sorted and not-sorted distance array
        */
        if (allCellDistancesSorted.get(i)==allCellDistances.get(cellIndex)) { 
          nearestCells.set(nextSlot, cellIndex);
          nextSlot += 1;
        }
      }
    }

  }
}