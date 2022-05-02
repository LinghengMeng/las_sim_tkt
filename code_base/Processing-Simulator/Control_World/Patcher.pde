class PatcherVars extends BehaviourEngineVars {


    HashMap<String, Patchable>      currentPatchables;  // patchables for this preset - I'll hide the rest - along with their display settings.  These get rebuilt and need to be reattached to their owners in allPatchables.
    ArrayList<Connector>            currentConnectors;
    transient HashSet<DataPort>                  portsToReset;  // remember dataports that have offered new data whose flags need to be cleared.

    transient int lastPatcherScan;
    transient int lastPatcherSync;
    transient int lastPatcherUpdate;

    int patcherUpdateFrequency = 70;
    int patcherSyncFrequency = 1000;
    int patcherScanFrequency = 5000;
    boolean autoScanPatchables = false;
    boolean showHidden = true;
    int gridSize = 20;
    boolean defaultSnap = true;
    float zoom = 1.0;

    // variables for patcher's owned patchables (like Random)

    transient boolean newRandomPatchable;
    transient float   randomValue;
    transient boolean randomPulse;



  PatcherVars() {
      super("Patcher", false);
      currentPatchables = new HashMap<String, Patchable>();
      currentConnectors = new ArrayList<Connector>();
      portsToReset      = new HashSet<DataPort>();

      newRandomPatchable = false;
      randomValue = 0.0;
      randomPulse = false;

  }

  void init() {
      patcherScanFrequency = 5000;
      patcherSyncFrequency = 1000;
      lastPatcherScan = millis() - patcherScanFrequency;
      lastPatcherSync = millis() - patcherSyncFrequency;
      lastPatcherUpdate = millis() - patcherUpdateFrequency;

      defaultSnap = true;
      showHidden = false;
      gridSize = 20;
      zoom = 1.0;
      autoScanPatchables = false;
      
  }

  void refreshBehaviourAfterSave(String preset_name) {   // callback executed once saved.
     //    sendPatcherCommandOSC("xxx", "refreshPatcher");
  }


   // overloaded for patcher-specific functions.  Also calls super() to catch generic ones like revealPatcher.
  
   void executeDatCommand(String command, String value) {
     
      super.executeDatCommand(command, value);
      println(behaviourName + " Got a command: " +command+ " | " + value);

      switch(command) {
        case "newRandomPatchable":
            newRandomPatchable = true;
        break;
      }
   }


}


class Patcher extends Thread {

 HashMap<String, Patchable> allPatchables;  // all the patchables I've ever had registered with me.  not recorded in the JSON.
 
 boolean exit = false;
 
Patcher() {

  super("Patcher Thread");

  allPatchables = new HashMap<String, Patchable>();

  


}

void run() {

    println(" Patcher is resending initial patches ... " );  // because I couldn't send before OSC was set up

    sendCurrent();

    println(" Patcher is running.");

    while(!exit) {
        try{
        Thread.sleep(patcherVars.thread_update_rate + time_lapse_pause);                        // prevents high CPU usage
        } catch (Exception e) {
        println(e);
        }

    //////////////  generate new Patcher-parented patchables?

    if(patcherVars.newRandomPatchable) {

            int n = patcherVars.patchables.size();
            Patchable rPatchable = new Patchable(this);
            rPatchable.realName = ("Random_" + n);
            rPatchable.displayName = ("Random_" + n);

            // behaviour:
            rPatchable.behaviour = "Patcher";

            // input ports:

            // output ports:
            rPatchable.dataPorts.add(new DataPort("randomValue"));
            rPatchable.dataPorts.add(new DataPort("randomPulse"));

            // add my Patchable to the Patcher engine's own patchables hashmap.
            patcherVars.patchables.put("Patcher", rPatchable);   

            patcher.addPatchable(rPatchable);   


        patcherVars.newRandomPatchable = false;
    }


    //////////////  periodically scan all engines for new Patchables ?

    if(patcherVars.autoScanPatchables) {
        if(millis() - patcherVars.lastPatcherScan > patcherVars.patcherScanFrequency) {

        try {
            for(HashMap.Entry<String, Object> beh : behaviourEngineSettings.entrySet()) {
            BehaviourEngineVars b = (BehaviourEngineVars)beh.getValue();

                for(Patchable p : b.patchables.values()) {
                  addPatchable(p);
                }
            }

            } catch(ConcurrentModificationException x) {
                println(" Autosyncing Patcher: " + x);
            }
        }
        patcherVars.lastPatcherScan = millis();
    }

    ////////////// if preset changes, or periodically ? need to reconnect any that are here with their owners.
    if(patcherVars.presetchanged || millis()-patcherVars.lastPatcherSync > patcherVars.patcherSyncFrequency) {
        // first cull any Patchables marked for removal from currentPatchables:
        cullPatchables();

        Patchable ap = null;

        // go through current and make sure all are accessible (ie in the allPatchables) and set their visibility to true;
        // if they aren't accessible, orphan them.

     try {

        for(Patchable cp : patcherVars.currentPatchables.values()) {

            ap = null;
            /// commenting out the two next lines could cause issues - trying to reduce number of times i redo things
            cp.hidden = false;
            cp.orphan = true;

            ap = allPatchables.get(cp.realName);
            if(ap != null) { 
                cp.orphan = false;        // exists in allpatchables
                sendPatcherCommandOSC(cp.realName, "isAdopted");
     
                ap.hidden = false;
                ap.screenX = cp.screenX;
                ap.screenY = cp.screenY;
                ap.screenH = cp.screenH;
                ap.screenW = cp.screenW;
                ap.displayName = cp.displayName;

            } else {
                cp.orphan = true;
                sendPatcherCommandOSC(cp.realName, "isOrphan");
              //  println(cp.realName + " is orphan - create it or remove it from patcher & save");
            }

        }

      // now go through allPatchers and hide any that are not in current set;

        for(Patchable p : allPatchables.values()) {
            if(patcherVars.currentPatchables.get(p.realName) == null) {
               p.hidden = true;
               hide(p.realName);
            } else {
               show(p.realName);
            }
        }

     } catch(Exception x) {
         println(" Exception in patcher - probably concurrent mod:  " + x);
     }

      // finally, rebuild my Connector list  (can't use an iterator because I'll be replacing elements)

        //for(Connector c : patcherVars.currentConnectors) {
        for (int i = 0 ; i < patcherVars.currentConnectors.size() ; i++) {
            Connector c =  patcherVars.currentConnectors.get(i);

        /// Check if I have actual objects for fromPatch and toPatch
        // print(" connector: "  + c.fromPort + " on " + c.fromPatchable + " --> " + c.toPort + ", on " + c.toPatchable );

        if(c.fromPatch       == null || c.toPatch       == null) { 
            // println("\t[ not present ... building ]"); 

            // need to rebuild it with the constructor because this data structure won't even have methods like connect()
            Connector nc = new Connector(c.fromPatchable, c.fromPort, c.toPatchable, c.toPort);
              // println(" Calling connect() on " + c.fromPatchable + ":" + c.fromPort + "->" + c.toPatchable + ":"+c.toPort);
              try{
                if(nc.connect()) {
                    // connection successful.
                    patcherVars.currentConnectors.set(i, nc);
                }
              } catch(Exception x) {
                println("  Hmm... " + x);
                println("   Maybe we'll try again later? " );
              }
            }
        }



     patcherVars.lastPatcherSync = millis();

     if(patcherVars.presetchanged) {
         sendPatcherCommandOSC("xxx", "refreshPatcher");
         patcherVars.presetchanged = false;
     }

    }

    //////////////  do all the data exchange between patchables. ( throttled using updateFrequency, and only send if patcher changes enough );

    // if it's time to check:
    if(millis()-patcherVars.lastPatcherUpdate > patcherVars.patcherUpdateFrequency) {
    // for each connector
        for(Connector c : patcherVars.currentConnectors) {

        /// before we start, make sure fromPatch and toPatch both have owners.
        //  print(" connector: "  + c.fromPort + " on " + c.fromPatchable + " --> " + c.toPort + ", on " + c.toPatchable );

        if(c.fromPatch       == null || c.toPatch       == null) { 
        //    println("\t[ not present ]"); 
            continue;
        }

        /// 1.  Get the object owner of the 'from' patchable

        Object fromObj = c.fromPatch.owner;

        //  2.   Now grab the data - it is assumed it will be a float btw 0.0 and 1.0

        float value = 0.0;

        try {
        Field field = fromObj.getClass().getDeclaredField(c.fromPt.param);  
        value = (float)field.get(fromObj); // this should put the current value from that field here.

           //  println("\t[" + c.fromPort + ": " + value + "]");
        } catch(Exception x) {
            println(" Ooops: " + x);
        }
        
        /// 3.  Chek with the from port to see if it has raised a 'new data' flag - this lets ports determine
        //      how significant a change warrants an update - can be settable in their world

        if(!c.fromPt.isNewData(value)) {
        //    println("\t[ no new data " + c.fromPort + " ]");
            continue;
        }

        /// 3.   If there is new data, add the port to a set I'm keeping that I'll clear once I'm done this loop - this lets
        //       other connectors attached to this port also access the new data.

        patcherVars.portsToReset.add(c.fromPt);

        /// 5.  send a string representation of the remapped value (provided by the to-port) to the datGUI to be set:
        String toSend = c.toPt.mappedValue(value);
        if(!toSend.equals("no change")) {   // only send if it has changed from last mapping.
            send_gui_OSC(c.toPatch.behaviour, c.toPort, toSend, c.toPatchable);
            if(c.toPt.param.equals("coreSize")) println("coreSize value: " + value + " -> " + toSend);
        }
        
        }
        // now that we're done iterating, clear the set of port 'new data' flags:
        for (DataPort dp : patcherVars.portsToReset) {
            dp.newDataFlag = false;
        }
        patcherVars.portsToReset.clear();
    
        patcherVars.lastPatcherUpdate = millis();
    }


     






    }

    println(" Patcher is closing.");
}

synchronized void addPatchable(Patchable p) {
    if(allPatchables == null || p.owner == null)  {  // don't add if there's no owner.
        return;
    }

    allPatchables.put(p.realName, p);  // add it (or replace the existing one) - this is the robust permanent store.
    p.hidden = true;      // hidden by default.
    // println(" Added " + p.realName + " to allPatchables ");
    
    if(patcherVars.currentPatchables.containsKey(p.realName)) {  // if current config includes this one
    Patchable curp = patcherVars.currentPatchables.get(p.realName);

        p.displayName = curp.displayName; // this may vary from preset to preset
        p.hidden = false;

        if(external_comms != null) {
     //    println("sending existing curp");
            sendPatchable(curp);
        }

    } else {

        // add it to curp, but hidden (is this the right thing to do?)
    //    println(" adding patchable " + p.realName + " to currentPatchables");
        patcherVars.currentPatchables.put(p.realName, p);
        if(external_comms != null) {
    //        println("sending new curp");
            sendPatchable(p);
        }

    }

    patcherVars.needToSave = true;

}

synchronized void revealByName(String name) {  // can use mask like "SD" or "NR"  for everything with part of that name.

    for(Patchable p : allPatchables.values()) {
       if(p.realName.contains(name)) {
           println(" adding " + p.displayName + " to patcher");
           addPatchable(p);
       }
    }
    
}

synchronized void sendCurrent() {
    for(Patchable p : patcherVars.currentPatchables.values()) {
        println(" sending patchable for " + p.displayName);
           sendPatchable(p);
    }
}

synchronized void sendPatchable(Patchable p) {

    JSONArray inPorts = new JSONArray();
    JSONArray outPorts = new JSONArray();
    
    for(DataPort dp : p.dataPorts) {
        JSONObject jo = new JSONObject();
        jo.setString("param", dp.param);
        jo.setString("value", dp.val);
        if(dp.inport) inPorts.append(jo);
        else         outPorts.append(jo);
    }

    // println("My Patchable parameters are:");
    send_patchable_OSC(p.realName, inPorts, outPorts);

}

synchronized void addConnector(JSONObject conn) {

    Connector c = new Connector(conn.getString("fromPatchable"),
                                conn.getString("fromPort"),
                                conn.getString("toPatchable"),
                                conn.getString("toPort"));
    println("  Patcher:  adding connector between " + c.fromPatchable + "/" + c.fromPort + "->" + c.toPatchable + "/" + c.toPort);
    if (c.connect() && c.findMatch() == null) patcherVars.currentConnectors.add(c);

}

synchronized void removeConnector(JSONObject conn) {

    Connector c = new Connector(conn.getString("fromPatchable"),
                                conn.getString("fromPort"),
                                conn.getString("toPatchable"),
                                conn.getString("toPort"));

    println("  Patcher:  removing connector between " + c.fromPatchable + "/" + c.fromPort + "->" + c.toPatchable + "/" + c.toPort);
    Connector toRemove = c.findMatch();        // find a matching connector and return it
    if(toRemove != null) patcherVars.currentConnectors.remove(toRemove);

}

synchronized void highlight(String name) {

    sendPatcherCommandOSC(name, "highlight");

}

synchronized void hide(String name) {
    sendPatcherCommandOSC(name, "hide");
}

synchronized void show(String name) {
    sendPatcherCommandOSC(name, "show");
}

synchronized void cullPatchables() {   // remove any patchables marked for deletion

    ArrayList<String> toRemove = new ArrayList<String>();

    for(Patchable p : patcherVars.currentPatchables.values()) {
        if(p.killMe) toRemove.add(p.realName);
    }

    for(String k : toRemove) {
        remove(k);
    }
}

synchronized void remove(String name) {

    Patchable p = patcherVars.currentPatchables.get(name);
    remove(p);

}

synchronized void remove(Patchable p) {

    if(p == null) {
        return;
    }

    hide(p.realName);
    
    patcherVars.currentPatchables.remove(p.realName);  // remove from current
    p.killMe = false;
    patcherVars.needToSave = true;
    sendPatcherCommandOSC(p.realName, "remove");

    }

}


class Connector {

  String fromPatchable;
  String toPatchable;
  String fromPort;
  String toPort;

  transient Patchable fromPatch;
  transient Patchable toPatch;
  transient DataPort  fromPt;
  transient DataPort  toPt;

  Connector(String _fromPatchable, String _fromPort, String _toPatchable, String _toPort) {

    fromPatchable = _fromPatchable;
    toPatchable   = _toPatchable;
    fromPort      = _fromPort;
    toPort        = _toPort;    

  }

  synchronized boolean connect() {

      if(patcher               == null) return false; // we will try again later.      
      if(patcher.allPatchables == null) return false; // we will try again later.

      fromPatch = null;
      toPatch = null;
      fromPt = null;
      toPt = null;

      for(Patchable p : patcher.allPatchables.values()) {
          if(p.realName.equals(fromPatchable)) {
              fromPatch = p;
          }
          if(p.realName.equals(toPatchable)) {
              toPatch = p;
          }
      }

      if(fromPatch == null || toPatch == null) {
          println(" fromPatchable: " + fromPatchable + " or toPatchable: " + toPatchable + " not found.  Aborting.");
          return false;
      }

      for(DataPort dp : fromPatch.dataPorts) {
          if(dp.param.equals(fromPort)) fromPt = dp;
      }

      for(DataPort dp : toPatch.dataPorts) {
          if(dp.param.equals(toPort)) toPt = dp;
      }

      if(fromPt == null || toPt == null) {
          println("fromPort: " + fromPort + " on " + fromPatchable + ", or toPort: " + toPort + ", on " + toPatchable + " not found.  Aborting.");
          return false;
      }

    // println(" Connected " + fromPort + " on " + fromPatchable + " --> " + toPort + ", on " + toPatchable );

    return true;
  }


  synchronized Connector findMatch() {

    for(Connector c : patcherVars.currentConnectors) {
        if(c.fromPatchable.equals(fromPatchable) &&
           c.fromPort.equals(fromPort)           &&
           c.toPatchable.equals(toPatchable)     &&
           c.toPort.equals(toPort)               ){

               // found it!  return this one.
               return(c);
        }
    }

    println("  Matching connector not found.");
    return(null);

  }

}

