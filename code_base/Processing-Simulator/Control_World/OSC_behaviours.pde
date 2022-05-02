



//// July 2020 slowly replacing all the custom messaging with the OSC + JSON + GSON system
//// to automatically create hooks for ANY variable in an influence engine.

  
// communication over OSC, and file/disk/JSON/GSON access  
  


void oscIn_datGuiSetting(OscMessage oscMsg) {   // assumes 3 Strings: behaviour, param, value
  

    Object newdata = null;
    Object toset;
    // parse out the strings (for some reason normal OSC parsing isn't working here -- typetags?) -mg
  
    String behav = (oscMsg.toString()).split(" ")[2].substring((oscMsg.toString()).split(" ")[2].lastIndexOf('/')+1);
    String param = (oscMsg.toString()).split(" ")[3];
    String value = (oscMsg.toString()).split(" ")[4];
    
    // set up the gson to set the value
    
    toset = behaviourEngineSettings.get(behav);   // retrieve the instance matching this behaviour
    
    // println("got object from behav name (" + behav + ").");

    if(toset == null) {  // try the child list if i didn't find it in the parent one

      toset = childBehaviourSettings.get(behav);

    }

    if(toset == null) return;

    // special case if the entire preset has changed:
    if(param.equals("presetName")) {

       BehaviourEngineVars b = (BehaviourEngineVars)(behaviourEngineSettings.get(behav));

       if(b == null) return;

       if(b.load(value)) {
        println(" Successfuly changed " + behav + " settings to "+ value); 
        b.presetchanged = true;
        b.needToSave = true;
       } else {

        println(" Trouble changing "+ behav + " settings to " + value);

       }
       return;
       
    }


    try {
    newdata = gson.fromJson("{"+param+" : "+value+"}", toset.getClass() );  // this handles objects but not arrays
    } catch(Exception x) {
      println("* Exception when trying to set " + param + " to " + value);
      println("* Exception is: " + x);
      println("* Failed message: " + oscMsg.toString());
    }

    

    if (((BehaviourEngineVars)toset).mergeSettings(newdata, toset, param)) {
      //  println("In " + behav + ", set " + param + " to " + value); 
    } else {
        println("Couldn't set " + param + " in " + behav);
        println("   Failed message: " + oscMsg.toString());
    }
    
    ((BehaviourEngineVars)toset).needToSave = true;

}



void oscIn_datGuiCommand(OscMessage oscMsg) {   // assumes 3 Strings: behaviour, command, value
  
    Object newdata = null;
    Object toset;
    // parse out the strings (for some reason normal OSC parsing isn't working here -- typetags?) -mg
  
    String behav   = (oscMsg.toString()).split(" ")[2].substring((oscMsg.toString()).split(" ")[2].lastIndexOf('/')+1);
    String command = (oscMsg.toString()).split(" ")[3];
    String value   = (oscMsg.toString()).split(" ")[4];
   
    // find the target behaviour variables object
    
    toset = behaviourEngineSettings.get(behav);   // retrieve the instance matching this behaviour

    if (toset == null) {  // try the child list
        toset = childBehaviourSettings.get(behav);
    }

    
    ((BehaviourEngineVars)toset).executeDatCommand(command, value);
}


// OSC output to node.js gui server:
synchronized void send_gui_OSC(String behaviour, String param, String value) {

    send_gui_OSC(behaviour, param, value, "");

}



synchronized void send_gui_OSC(String behaviour, String param, String value, String target) {
    OscMessage oscMsg = new OscMessage("/setDatParameter");
    oscMsg.add(behaviour);    // this is the behaviour name
    oscMsg.add(param);        // this is the parameter to set
    oscMsg.add(value);        // this is the value to set it to
    if(!target.equals(behaviour)) {  // if there is a different name for this patchable than the behaviour (ie it is nested?)
      oscMsg.add(target);       // this is (optionally) the target (ie the source, the name of the patchable)
    }
    external_osc.send(oscMsg, guiServerLocation);
}

synchronized void swap_preset_OSC(String behaviour, String preset) {

    // println(" ... going to switch now I think using /swapPreset");

    OscMessage oscMsg = new OscMessage("/swapPreset");
//    OscMessage oscMsg = new OscMessage("/setDatParameter");
    oscMsg.add(behaviour);    // this is the behaviour name
    oscMsg.add(preset);        // this is the parameter to set

    external_osc.send(oscMsg, guiServerLocation);
}

// synchronized void refresh_presets_OSC(String behaviour) {

//   println("  sending request to refresh presets for " + behaviour);

//   OscMessage oscMsg = new OscMessage("/requestPreset");

// }

// OSC input from node.js patching server, assumes 1 string: patcher realName, followed by a JSON object of all the params to change.
synchronized void oscIn_patcherCommand(OscMessage oscMsg) { 

    // parse out the strings  
    String command = (oscMsg.toString()).split(" ")[2].substring((oscMsg.toString()).split(" ")[2].lastIndexOf('/')+1);

    JSONObject params;

    switch(command) {

      case("updatePatchable"):
        // println(" update patchable got " + oscMsg.toString());
        String pname = (oscMsg.toString()).split(" ")[3];
        params = parseJSONObject( (oscMsg.toString()).split(" ")[4] );  // create a JSON object we can use to get key values

        // println(" ... params is " + params.toString());

        // now use GSON to merge the parameters sent with the existing Patchable object's parameters:
        Patchable newp = gson.fromJson(params.toString(), Patchable.class);  // creates a new Patchable that has the sent parameters
     
        // println("newp named " + newp.realName + " has screenX of " + newp.screenX);
     
        // try current first - if doesn't work, try all
        Patchable myp = patcherVars.currentPatchables.get(pname);

        if(myp == null) {
          myp = patcher.allPatchables.get(pname);
        }

        if(myp == null) { 
          println(" Hmm. Couldn't find " + pname + " in either current or all patchable sets.  Ignoring. ");
          return;
        }

        for(String key : (Set<String>)(params.keys())) {                                       // for each parameter we were sent
         if(!patcherVars.mergeSettings(newp, myp, key)) {                             // merge it with existing Patchable object.
             println(" ** trouble merging " + key + " in " + pname);
         }
        }

        patcherVars.needToSave = true;
        
      break;

      case("addConnector"):
        params = parseJSONObject( (oscMsg.toString()).split(" ")[3] );  // create a JSON object we can use to get key values

        patcher.addConnector(params);
        patcherVars.needToSave = true;
        
      break;

      case("removeConnector"):
        params = parseJSONObject( (oscMsg.toString()).split(" ")[3] );  // create a JSON object we can use to get key values

        patcher.removeConnector(params);
        patcherVars.needToSave = true;
        
      break;

      default:
        
         println(" Unknown command received by patcher:" + command);
         return;
    }

}



// OSC output to node.js patching server:
synchronized void send_patchable_OSC(String name, JSONArray in, JSONArray out) {
    OscMessage oscMsg = new OscMessage("/addPatchable");
    oscMsg.add(name);       // this is the entire string, properly formatted
    oscMsg.add(in.toString());         // this is the parameter to set
    oscMsg.add(out.toString());        // this is the value to set it to
    external_osc.send(oscMsg, guiServerLocation);
}

synchronized void sendPatcherCommandOSC(String name, String command) {
    OscMessage oscMsg = new OscMessage("/patchableCommand");
    oscMsg.add(name);       // this is the entire string, properly formatted
    oscMsg.add(command);         // this is the parameter to set
    external_osc.send(oscMsg, guiServerLocation);
}





/////////  OLD (pre-July 2020) functions below, still work.  






// OSC IN AMBINT WAVES

void oscIn_ambientWaves(OscMessage oscMsg) {

  if (oscMsg.checkAddrPattern("/ambientWaves/velocity")==true) {
//    if (oscMsg.checkTypetag("f")) {
      float in_var= oscMsg.get(0).floatValue();
   //   ambientWavesVars.default_velocity = in_var;
      return;
//    }
  }

  if (oscMsg.checkAddrPattern("/ambientWaves/period")==true) {
//    if (oscMsg.checkTypetag("f")) {
      float in_var= oscMsg.get(0).floatValue();
   //   ambientWavesVars.default_period = in_var;
      return;
//    }
  }

  if (oscMsg.checkAddrPattern("/ambientWaves/amplitude")==true) {
    if (oscMsg.checkTypetag("f")) {
      float in_var= oscMsg.get(0).floatValue();
   //   ambientWavesVars.default_amplitude = in_var;
      return;
    }
  }

  if (oscMsg.checkAddrPattern("/ambientWaves/angle")==true) {
//    if (oscMsg.checkTypetag("f") ) {
      float in_var= oscMsg.get(0).floatValue();
   //   ambientWavesVars.default_angle = in_var;
      return;
//   }
  }

  if (oscMsg.checkAddrPattern("/ambientWaves/display")==true) {
//    if (oscMsg.checkTypetag("i")) {
      int in_var= oscMsg.get(0).intValue();

      if (in_var==1) {
        ambientWavesVars.display = true;
        return;
      } else {
        ambientWavesVars.display = false;
        return;
      }
 //   }
 //   return;
  }  

  println(" Hm... didn't match anything." );

}

// OSC IN TIME LAPSE

void oscIn_timeLapse(OscMessage oscMsg) {

    time_lapse_changed = true;  // flag to let millis calls reset


    if (oscMsg.checkAddrPattern("/timelapse/tlon")==true) {
      
      int in_var= oscMsg.get(0).intValue();


      println("Got message to set timelapse: " + in_var);

      if (in_var==1) {
        time_lapse = true;
        return;
      } else {
        time_lapse = false;
        return;
      }
  }  


  if (oscMsg.checkAddrPattern("/timelapse/scalefactor")==true) {
      float in_var= 1.00;

      if (oscMsg.checkTypetag("i")) {
          in_var= float(oscMsg.get(0).intValue());
      } else {
          in_var= oscMsg.get(0).floatValue();
      }

       println("Got message timelapse speed: " + in_var);

      time_lapse_speed = in_var* 100.0;    // change 0.0 - 1.0 float range to a percentage


      return;
  }

  println(" Hm... didn't match anything." );

}


// OSC IN ELECTRIC CELLS

void oscIn_electricCells(OscMessage oscMsg) {

  /*
  DUMMY for CPOY PASTE
  if (oscMsg.checkAddrPattern("/electricCells/var")==true) {
    if (oscMsg.checkTypetag("if")) {
      int varInt = oscMsg.get(0).intValue();
      float varFloat = oscMsg.get(1).floatValue();
      return;
    }
  }
  */

  if (oscMsg.checkAddrPattern("/electricCells/display")==true) {
    if (oscMsg.checkTypetag("i")) {
      int in_var= oscMsg.get(0).intValue(); 
      if (in_var==1) {
        electricCellVars.display = true;
        return;
      } else {
        electricCellVars.display = false;
        return;
      }
    }
    return;
  }

  if (oscMsg.checkAddrPattern("/electricCells/influenceList")==true) {
    if (oscMsg.checkTypetag("fffffffffffffffffffffffffffffffffffffffffffff")) {
      for (int i=0; i<45; i++) {
      float in_var= oscMsg.get(i).floatValue();
//      electricCellSystem.actuatorInfluences.set(electricCellSystem.drMapper.get(i).index_in_allActuators, in_var);
    }
//    control.set_actuator_excitor_influences(electricCellSystem.actuatorInfluences, "EC");
    return;
    }
  }
  
  if (oscMsg.checkAddrPattern("/electricCells/amount")==true) {
    if (oscMsg.checkTypetag("i")) {
      int in_var= oscMsg.get(0).intValue();
      electricCellVars.cellCount = in_var;
      return;
    }
  }

  if (oscMsg.checkAddrPattern("/electricCells/range")==true) {
    if (oscMsg.checkTypetag("i")) {
      int in_var= oscMsg.get(0).intValue();
      electricCellVars.neighbourRange = in_var;
      return;
    }
  }

  if (oscMsg.checkAddrPattern("/electricCells/rate")==true) {
    if (oscMsg.checkTypetag("i")) {
      int in_var= oscMsg.get(0).intValue();
      electricCellVars.rate = in_var;
      return;
    }
  }

  if (oscMsg.checkAddrPattern("/electricCells/intensity")==true) {
    if (oscMsg.checkTypetag("f")) {
      float in_var= oscMsg.get(0).floatValue();
      electricCellVars.masterIntensity = in_var;
      return;
    }
  }

  if (oscMsg.checkAddrPattern("/electricCells/enable")==true) {
    if (oscMsg.checkTypetag("i")) {
      int enable = oscMsg.get(0).intValue();
      if (enable == 1) { 
        run_electricCells = true;
        return;
      } else {
        // for (int i=0; i<numActuators; i++) {
        //   electricCellSystem.actuatorInfluences.set(i, 0.);
        // }
        // control.set_actuator_excitor_influences(flowField.actuatorInfluences, "EC");
 
        electricCellSystem.clearActuatorInfluences();
        control.set_actuator_excitor_influences(electricCellSystem.actuatorInfluences, "EC");
        run_electricCells = false;
        return;
      }
    }
  }

  println("OSC Message not recognised by electricCells: " + oscMsg);
}



void oscIn_sensorGestures(OscMessage oscMsg) {


  if (oscMsg.checkAddrPattern("/sensorGestures/toggle")==true) {
    if (oscMsg.checkTypetag("i")) {
      int in_var= oscMsg.get(0).intValue();

      println("Got message to set sensor sound gestures: " + (in_var==1));

      ir_trigger_sounds = (in_var==1);
        return;
    }
  }

}





// OSC IN riverHead

void oscIn_riverHead(OscMessage oscMsg) {


  if (oscMsg.checkAddrPattern("/riverHead/rhRingSpeed")==true) {
    if (oscMsg.checkTypetag("f")) {
      float in_var= oscMsg.get(0).floatValue();
   //   riverHeadVars.rhVertexAngleSpeed = in_var;
      return;
    }
  }

  if (oscMsg.checkAddrPattern("/riverHead/rhDisplayRings")==true) {
    if (oscMsg.checkTypetag("i")) {
      int in_var= oscMsg.get(0).intValue();

      println("Got message to display rings: " + in_var);

      if (in_var==1) {
  //      riverHeadVars.displayRings = true;
        return;
      } else {
  //      riverHeadVars.displayRings = false;
        return;
      }
    }
  }

}

// OSC IN flowField

void oscIn_flowField(OscMessage oscMsg) {


//println(oscMsg);

  /*
  DUMMY for CPOY PASTE
  if (oscMsg.checkAddrPattern("/flowField/var")==true) {
    if (oscMsg.checkTypetag("if")) {
      int varInt = oscMsg.get(0).intValue();
      float varFloat = oscMsg.get(1).floatValue();
      return;
    }
  }
  */


/// SKIPPING THIS!
  if (flowFieldVars.display == true) return;


  if (oscMsg.checkAddrPattern("/flowField/display")==true) {
    if (oscMsg.checkTypetag("i")) {
      int in_var= oscMsg.get(0).intValue(); 
      if (in_var==1) {
        flowFieldVars.display = true;
        return;
      } else {
        flowFieldVars.display = false;
        return;
      }
    }
    return;
  }


  if (oscMsg.checkAddrPattern("/flowField/intensity")==true) {
    if (oscMsg.checkTypetag("f")) {
      float in_var= oscMsg.get(0).floatValue();
      flowFieldVars.masterIntensity = in_var;
      return;
    }
  }

  if (oscMsg.checkAddrPattern("/flowField/randomness")==true) {
    if (oscMsg.checkTypetag("f")) {
      float in_var= oscMsg.get(0).floatValue();
      flowFieldVars.randomForceAmount = in_var;
      return;
    }
  }

  if (oscMsg.checkAddrPattern("/flowField/respawnRange")==true) {
    if (oscMsg.checkTypetag("i")) {
      int in_var= oscMsg.get(0).intValue();
      flowFieldVars.respawnRange = in_var;
      return;
    }
  }

  if (oscMsg.checkAddrPattern("/flowField/edgeRange")==true) {
    if (oscMsg.checkTypetag("i")) {
      int in_var= oscMsg.get(0).intValue();
      flowFieldVars.edgeRange = in_var;
      return;
    }
  }

  if (oscMsg.checkAddrPattern("/flowField/maxSpeed")==true) {
    if (oscMsg.checkTypetag("f")) {
      float in_var= oscMsg.get(0).floatValue();
      flowFieldVars.maxSpeed = in_var;
      return;
    }
  }

  if (oscMsg.checkAddrPattern("/flowField/amount")==true) {
    if (oscMsg.checkTypetag("i")) {
      int in_var= oscMsg.get(0).intValue();
      flowFieldVars.particleCount = in_var;
      return;
    }
  }

  if (oscMsg.checkAddrPattern("/flowField/size")==true) {
    if (oscMsg.checkTypetag("f")) {
      float in_var= oscMsg.get(0).floatValue();
      flowFieldVars.threshold = in_var;
      return;
    }
  }

  if (oscMsg.checkAddrPattern("/flowField/perlinInc")==true) {
    if (oscMsg.checkTypetag("f")) {
      float in_var= oscMsg.get(0).floatValue();
   //   flowFieldVars.perlinOffsetInc = in_var;
      return;
    }
  }

  if (oscMsg.checkAddrPattern("/flowField/setPerlinNoiseOffsets")==true) {
    if (oscMsg.checkTypetag("ffffff")) {
      float _offX = oscMsg.get(0).floatValue();
      float _offY = oscMsg.get(1).floatValue();
      float _offZ = oscMsg.get(2).floatValue();
      float _multX = oscMsg.get(3).floatValue();
      float _multY = oscMsg.get(4).floatValue();
      float _multZ = oscMsg.get(5).floatValue();

      // for (int i=0; i<flowField_NR.riverFlowField.flowVectors.size(); i++){
      //     flowField_NR.riverFlowField.flowVectors.get(i).setNoiseOffsets(_offX, _offY, _offZ, _multX, _multY, _multZ);
      // }
      // for (int i=0; i<flowField_SR.riverFlowField.flowVectors.size(); i++){
      //     flowField_SR.riverFlowField.flowVectors.get(i).setNoiseOffsets(_offX, _offY, _offZ, _multX, _multY, _multZ);
      // }
     return;
    }
  }

  // if (oscMsg.checkAddrPattern("/flowField/createVecCube")==true) {
  //   if (oscMsg.checkTypetag("ii")) {
  //     int dim = oscMsg.get(0).intValue();
  //     int size = oscMsg.get(1).intValue();
  //     flowField.flowVectorSystem.createVecCube(dim, size);
  //     return;
  //   }
  // }
  
  if (oscMsg.checkAddrPattern("/flowField/enable")==true) {
    if (oscMsg.checkTypetag("i")) {
      int enable = oscMsg.get(0).intValue();
      if (enable == 1) { 
        run_flowField = true;
        return;
      } else {
     //   flowField_NR.clearActuatorInfluences();
     //   flowField_SR.clearActuatorInfluences();

     //   control.set_actuator_excitor_influences(flowField_NR.actuatorInfluences, "GR");
     //   control.set_actuator_excitor_influences(flowField_SR.actuatorInfluences, "GR");
        run_flowField = false;
        return;
      }
    }
  }

  println("OSC Message not recognised by FlowField: " + oscMsg);
}


// OSC IN serverMessage 

// *** NOTE **** 
// TO AVOID THREAD DEADLOCK, 
// THESE COMMANDS MUST NOT CALL COMMANDS THAT ACCESS
// NODES OR PIs DIRECTLY (since they need to be accessed by drawing thread) 
// Instad, set a flag here and manage it in main control world.

void oscIn_serverMessage(OscMessage oscMsg){
  
  if (oscMsg.checkAddrPattern("/serverMessage/paintbrush")==true) {

      if (oscMsg.checkTypetag("fff")) {

        if(oscMsg.get(2).floatValue() < 0) {
          paintbrush_osc = false;
          println("paintbrush (float) -- STOP");
          return;
        }

        paintbrush_osc_params.x = oscMsg.get(0).floatValue();
        paintbrush_osc_params.y = oscMsg.get(1).floatValue();
        paintbrush_osc_params.z = oscMsg.get(2).floatValue();
        paintbrush_osc = true;
        println("paintbrush (float) -- x: " + nf(paintbrush_osc_params.x, 0, 3) + " y: " + nf(paintbrush_osc_params.y, 0, 3) + " dia: " + nf(paintbrush_osc_params.z, 0, 3));
        return;
      }

      if (oscMsg.checkTypetag("sss")) {
      String xpos = oscMsg.get(0).stringValue();
      String ypos = oscMsg.get(1).stringValue();
      String dia  = oscMsg.get(2).stringValue();
      paintbrush_osc_params.x = Float.parseFloat(xpos);
      paintbrush_osc_params.y = Float.parseFloat(ypos);
      paintbrush_osc_params.z = Float.parseFloat(dia);
      paintbrush_osc = true;
      println("paintbrush (string) -- x: " + nf(paintbrush_osc_params.x, 0, 3) + " y: " + nf(paintbrush_osc_params.y, 0, 3) + " dia: " + nf(paintbrush_osc_params.z, 0, 3));
      return;
      }
  }

  
  if (oscMsg.checkAddrPattern("/serverMessage/sleep")==true) {
    println("do sleep");
    osc_sleep_pushed = true;
//    show_control_awake = false;
//    control.go_to_sleep();
    return;
  }
  else if (oscMsg.checkAddrPattern("/serverMessage/wake")==true) {
    println("do wake");
    osc_wake_pushed = true;
//    show_control_awake = true;
//    control.wake_up();
    return;
  }

  if (oscMsg.checkAddrPattern("/serverMessage/masterBehaviourIntensity")==true) {

      if (oscMsg.checkTypetag("f")) {
        float in_var= oscMsg.get(0).floatValue();
        masterBehaviourIntensity = in_var;
       // println(" Setting master Behaviour Intensity to " + masterBehaviourIntensity);
        return;
      }

      if (oscMsg.checkTypetag("s")) {
        String intense = oscMsg.get(0).stringValue();
      masterBehaviourIntensity = Float.parseFloat(intense);
     // println(" Setting master Behaviour Intensity to " + masterBehaviourIntensity);
      return;
    }
  }

  if (oscMsg.checkAddrPattern("/serverMessage/scene")==true) {
    if (oscMsg.checkTypetag("s")) {
        String scene = oscMsg.get(0).stringValue();
        
        if(current_scene.equals(scene)) {
          println("No change in current scene.  Not loading.");
          return;
        }

        osc_new_scene = scene;
        return;
    }

  }



  if (oscMsg.checkAddrPattern("/serverMessage/ping")==true) {

     monitor.record_server_seen();
     return;
  }

   println("OSC Message not recognised by serverMessage: " + oscMsg);
}



// OSC IN excitorBehaviour



void oscIn_excitorBehaviour(OscMessage oscMsg) {

/*
DUMMY for CPOY PASTE
if (oscMsg.checkAddrPattern("/excitorBehaviour/var")==true) {
  if (oscMsg.checkTypetag("if")) {
    int varInt = oscMsg.get(0).intValue();
    float varFloat = oscMsg.get(1).floatValue();
    return;
  }
}
*/

  if (oscMsg.checkAddrPattern("/excitorBehaviour/genExcitor")==true) {
    if (oscMsg.checkTypetag("i")) {
      int in_var= oscMsg.get(0).intValue();
      excitorBehaviour.excitorSystem.addExcitor(PVector.random3D().mult(400), in_var); 
      return;
    }
  }

  if (oscMsg.checkAddrPattern("/excitorBehaviour/excitorsEnable")==true) {
    if (oscMsg.checkTypetag("i")) {
      int in_var= oscMsg.get(0).intValue(); 
      if (in_var==1) {
        run_excitorBehaviour = true;
        return;
      } else {
      //   for (int i=0; i<numActuators; i++) {
      //     electricCellSystem.actuatorInfluences.set(i, 0.);
      //   }
        excitorBehaviour.clearActuatorInfluences();
        control.set_actuator_excitor_influences(excitorBehaviour.actuatorInfluences, "EXP");
        run_excitorBehaviour = false;
        return;
      }
    }
    return;
  }

  if (oscMsg.checkAddrPattern("/excitorBehaviour/backgroundBehaviourEnable")==true) {
    if (oscMsg.checkTypetag("i")) {
      int in_var= oscMsg.get(0).intValue(); 
      if (in_var==1) {
        excBehavVars.backgroundBehaviourEnabled = true;
        return;
      } else {
        excBehavVars.backgroundBehaviourEnabled = false;
        return;
      }
    }
    return;
  }

  if (oscMsg.checkAddrPattern("/excitorBehaviour/display")==true) {
    if (oscMsg.checkTypetag("i")) {
      int in_var= oscMsg.get(0).intValue(); 
      if (in_var==1) {
        excBehavVars.showExcitors = true;
        excBehavVars.showAttractors = true;
        return;
      } else {
        excBehavVars.showExcitors = false;
        excBehavVars.showAttractors = false;
        return;
      }
    }
    return;
  }

  if (oscMsg.checkAddrPattern("/excitorBehaviour/intensity")==true) {
    if (oscMsg.checkTypetag("f")) {
      float in_var= oscMsg.get(0).floatValue(); 
      excBehavVars.masterIntensity = in_var;
      return;
    }
  }

  if (oscMsg.checkAddrPattern("/excitorBehaviour/force")==true) {
    if (oscMsg.checkTypetag("f")) {
      float in_var= oscMsg.get(0).floatValue(); 
      excBehavVars.forceScalar = in_var;
      return;
    }
  }

  if (oscMsg.checkAddrPattern("/excitorBehaviour/attractorRotSpeed")==true) {
    if (oscMsg.checkTypetag("f")) {
      float in_var= oscMsg.get(0).floatValue(); 
      excBehavVars.attractorAngleSpeed = in_var;
      return;
    }
  }

  if (oscMsg.checkAddrPattern("/excitorBehaviour/maxSpeed")==true) {
    if (oscMsg.checkTypetag("f")) {
      float in_var= oscMsg.get(0).floatValue(); 
      excBehavVars.excitorSpeedLimit = in_var;
      return;
    }
  }

  if (oscMsg.checkAddrPattern("/excitorBehaviour/playWavTrigger")==true) {
    if (oscMsg.checkTypetag("iii")) {
      int WTindex = oscMsg.get(0).intValue(); 
      int wavIndex = oscMsg.get(1).intValue(); 
      int wavGain = oscMsg.get(2).intValue(); 
 //     playWavTrigger(WTindex, wavIndex, wavGain); 
      return;
    }
  }

  println("OSC Message not recognised by excitorBehaviour: " + oscMsg);
}


///////// OSC DEBUG

void oscIn_behaviourDebug(OscMessage oscMsg) {

  if (oscMsg.checkAddrPattern("/behaviourDebug/printInfluences")==true) {
    // println("flowField_NR.actuatorInfluences: " + flowField_NR.actuatorInfluences);
    // println("flowField_SR.actuatorInfluences: " + flowField_SR.actuatorInfluences);
    println("electricCellSystem.actuatorInfluences: " + electricCellSystem.actuatorInfluences);
    println("excitorBehaviour.actuatorInfluences: " + excitorBehaviour.actuatorInfluences);
    return;
  }

  println("OSC Message not recognised by behaviourDebug: " + oscMsg);
}


///////// OSC ACTUATORS

void oscIn_actuators(OscMessage oscMsg) {

  if (oscMsg.checkAddrPattern("/actuator/doubleRebelstar/mode")==true) {
    if (oscMsg.checkTypetag("s")) {
      String mode = oscMsg.get(0).stringValue();
      
        //set_actuatorMode(mode);

      return;
    }
  }
}
