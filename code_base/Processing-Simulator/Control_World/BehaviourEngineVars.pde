
// generic class for storing behaviour engine variables that can be saved, loaded, merged
// abstract class to be extended by specific behaviours.

abstract class BehaviourEngineVars {

   transient int     thread_update_rate = 15;
   transient int     last_behaviour_save;
   transient boolean needToSave = true;
   transient String  currentPreset = "none";
   transient boolean presetchanged = false;         // flag set automatically when new preset is loaded
   transient HashMap<String, Patchable> patchables;
     
   boolean neverSave = false;  // used to determine if it is a child behaviour and should be in the separate hashmap
   String  behaviourName;   

   BehaviourEngineVars(String name, boolean isChild) {
       behaviourName = name;
       last_behaviour_save = millis();
       currentPreset = "none";

       patchables = new HashMap<String, Patchable>();

       // masterIntensity = 1.0;

       neverSave = isChild;

       registerBehaviour(isChild);
   }

   void init() {  // to be overridden with initial values for behaviour, in case saved values don't exist
   }

    void load() {
       if(!load("default")) {
        println(behaviourName + " Settings not found.  Initializing from defaults and saving.");
        init();
        save(); 
       };
    }

    boolean load(String preset_name) {

      /// old way to do it - now going to do it via the server except on first time.

    if(currentPreset.equals(preset_name)) {

      println(behaviourName + ":  Current preset is already " + preset_name + " so ignoring request to load." );
      return(false);

    }
 
    FileReader fr;
    JsonReader jr;
    
    Object newdata;
    Object toset = behaviourEngineSettings.get(behaviourName);
    // if object is null, try the child list:
    if(toset == null) {
       toset = childBehaviourSettings.get(behaviourName);
    }

    String fn = new String("data/" + file_name + "/" + behaviourName + "_settings_" + preset_name + ".json");
    
    try {
    fr = new FileReader(sketchPath() + "/" + fn);
    jr = new JsonReader(fr);

    println("loading " + fn + " settings");

    newdata = gson.fromJson(jr, toset.getClass() );
    jr.close(); fr.close();
    } 
    catch(Exception e) {
      
      println(" Exception loading values from JSON: " + e);
      return(false);
    }
    
    if(mergeSettings(newdata, toset)) {
      currentPreset = preset_name;
      return(true);
    } else {
      return(false);
    }
    
}

void registerBehaviour(boolean isChild) { 

    if(!isChild) {

      // register this object in the behavioursettings list
      if(behaviourName != null && !behaviourName.equals("")) {
      println(" Registering " + behaviourName + " in behaviourEngineSettings");
      behaviourEngineSettings.put(behaviourName, this);
    }

    } else {

      // register this child object in the childbehavioursettings list
      if(behaviourName != null && !behaviourName.equals("")) {
      println(" Registering child: " + behaviourName + " in childBehaviourSettings");
      childBehaviourSettings.put(behaviourName, this);
    }
    }

}

synchronized void deregisterBehaviour(boolean isChild) {

    if (!isChild) {

    if(behaviourName != null && !behaviourName.equals("")) {
      println(" Deregistering " + behaviourName + " from behaviourEngineSettings");
      behaviourEngineSettings.remove(behaviourName);
    }

    } else {

    if(behaviourName != null && !behaviourName.equals("")) {
      println(" Deregistering child: " + behaviourName + " from childBehaviourSettings");
      childBehaviourSettings.remove(behaviourName);
    }

    }

}

/// special set master behaviour intensity

/// generic merger for merging some settings with existing class instance

boolean mergeSettings(Object newObject, Object toset) {
   return(mergeSettings(newObject, toset, "***"));  // merge all
}


boolean mergeSettings(Object newObject, Object toset, String whichparam) {

  try {

  if(!toset.getClass().getName().equals(newObject.getClass().getName())) {
   println(" Problem merging - classes aren't the same.");
   return false; 
  }

  for (Field field : toset.getClass().getDeclaredFields()) {

    if (field.getName().contains("this")) continue;
    if (!whichparam.equals("***") && !whichparam.equals(field.getName())) continue;  // only change this param   
    
    for (Field newField : newObject.getClass().getDeclaredFields()) {
 
      if (field.getName().equals(newField.getName())) {
        // println(" ** " + field.getName() + " == " + newField.getName() + " <- great! ");
        try {

          field.set(toset, newField.get(newObject) == null ? field.get(toset) : newField.get(newObject));

        } catch (IllegalAccessException e) {
          // Field update exception on final modifier and other cases.
          println(" Problem merging... : " + e);
          return false;
        }
      } else {
        // println(" ** " + field.getName() + " != " + newField.getName());
      }
    }
  }
  } catch(Exception x) {

     println(" Exception in merging:  " + x);
     return false;

  }
  
  // // special case for setting values in linked folders :  
  //    if(whichparam != "***" && newObject.linkedSources != null && newObject.linkedSources == true && toset.linked != null && toset.linked == true) {
  //      send_gui_OSC(toset.behaviourName, whichparam, String value, String target)
  //    }
  //          doesn't work and i'm too tired now to finish this "nice-to-have".


  // Set 'changed' indicator so that if we revert or reload, it does not ignore:
  if(!currentPreset.contains("*")) {
      currentPreset = (currentPreset + " *");
      println(behaviourName + ": changed " + currentPreset);
  }

  return true;
  
}


void save() {   
    save("default");
}

void save(String preset_name) {
    FileWriter fw;

    Object tosave = behaviourEngineSettings.get(behaviourName);

    println("Saving " + behaviourName + " " + preset_name + " values");
    
    if(!preset_name.equals("current")) {
       currentPreset = preset_name;        // if we aren't just saving the current one, but we are saving a new version of a named preset, we want to 
                                           // reset the currently-selected preset name to this - remove any change indicator *s - so we can skip loads if it will be identical.
    }

    try {
        fw = new FileWriter(sketchPath() + "/data/" + file_name + "/" + behaviourName + "_settings_" + preset_name + ".json");
        gson.toJson(tosave, fw);  
        fw.flush(); fw.close(); 
        }
    catch(Exception e) {
        println("Exception writing files: " + e);
    }  

    // now saved, send a callback to the behaviour so it can eg. refresh gui, etc.
    refreshBehaviourAfterSave(preset_name);
}

void refreshBehaviourAfterSave(String preset_name) { 

     // override this method within your behaviour engine if you need to eg: refreh a gui or whatnot.

}

void executeDatCommand(String command, String value) {
    // can also override this method within your behaviour engine if you've put function buttons in your GUI. (see Excitors)

      println(" BehaviourEngineVars: " + behaviourName + " Got a command: " +command+ " | " + value);

      switch(command) {
        case "revealPatchable":
              for (Patchable p : patchables.values()) {
                 patcher.addPatchable(p);   
              }
        break;
      }
   }
}