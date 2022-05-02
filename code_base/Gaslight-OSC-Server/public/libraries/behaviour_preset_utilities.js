

    // Define Socket Messages and their Corresponding function (for updating on-page sliders)
    socket.on('syncClients', syncMyClient);
    socket.on('updateSettings', updateSettings);
    socket.on('populatePresets', populatePresets);


    // callback function to tell server to send OSC message -- the first __gui is for folder, the parent is the gui instance.
    function sendDatOSC(v) {

         // for nested GUIs, I need to climb up the tree...
        var topgui = this.__gui.parent;
        var i = 5;  // iterate up to 5 times
        var nested = false;

        while(objectList[topgui.name] == null && i > 0) {
          topgui = topgui.parent;
          nested = true;
          i--;
        }
        if(objectList[topgui.name] == null) {
            console.log("  COULDN'T FIND TOP LEVEL BEHAVIOUR (tried 5 times).  aborting");
            return;
        }

        // ... done - should be at the top
        var beh = topgui.name;
        var targ = null;

         // was this nested?
         if(nested) {  // from our check above
            targ = this.__gui.name;   // this should be the name of our nested behaviour/(source)
         }

         socket.emit('sendDatOSC', { behaviour: beh, name: this.property, value: v, target: targ });
         setChanged(beh, true);
    }

    function outgoingDatCommand(beh, command, v) {

       // var beh = this.__gui.parent.name;
        socket.emit('sendDatCommand', {behaviour: beh, name: command, value: v});
       
    }

    function sendDatCommand(v) {

        console.println(" v is "+ v.cmd + " and " + v.param);

    }


    



    // receive realtime sync data from server
    function syncMyClient(ndata) {

        // return if ndata behaviour is undefined (i.e. not used on this page)
        if(objectList[ndata.beh] == null) {
            // console.log(" No such behaviour (" + ndata.beh + ") on this page.  Ignoring.");
            return;
        }

        // debugging booleans:
        // console.log(" ndata.val is " + ndata.val);
        // console.log("1.  this is  true: " + (ndata.val == true));
        // console.log("2.  this is  \"true\": " + (ndata.val == "true"));
        // console.log("3.  this is  \'true\': " + (ndata.val == 'true'));
        // console.log("1.  this === true: " + (ndata.val === true));
        // console.log("2.  this === \"true\": " + (ndata.val === "true"));
        // console.log("3.  this === \'true\': " + (ndata.val === 'true')); 

        // fix loose typing of string -> boolean conversions downstream.
        if(ndata.val == "true") {
            ndata.val = true;
        }
        if(ndata.val == "false") {
            ndata.val = false;
        }


        // first check for special sync functions instead of value updates

        if(ndata.param == "reloadPresetList") {
             console.log(date + " Received request to refresh " + ndata.beh + " preset list because of " + ndata.val);
             requestPresets(ndata.beh);
             setTimeout(() => {
                switchSelectorToPresetNamed(ndata); }, 1500);  // wait 1.5 seconds to load the new preset list
             return;
        }

        if(ndata.param == "changeToNewPreset") {
            console.log(date + " Received request to change " + ndata.beh +  " selector to preset " + ndata.val);
                switchSelectorToPresetNamed(ndata);
            return;
        }

         // check if there is a secondary 'target' - ie. a specific source to update.  if so, create the object, the folder and populate it.
          ///  TO DO!
          if(ndata.targ != null) {
              console.log("... Hey, this was specifically meant for " + ndata.targ + " (ndata.param is " + ndata.param + ")");
              manageNestedSettings(ndata);
              
              return;
          }

        // update value

        console.log("setting " + ndata.beh + "->" + ndata.param + " to " + ndata.val);
        objectList[ndata.beh].settings[ndata.param] = ndata.val;
        // setChanged(ndata.beh, true);
    }

    // request the entire set of current settings and presets for all behaviours
    function requestCurrentSettings() {

    for(const b in objectList) {
            var data = {};
            data.beh = b;
            data.preset = 'current';
            data.sendosc = false;
            socket.emit('requestPresets', data.beh); // populate preset lists first
            requestSettings(data); 
           
        }
    }

    function requestSettings(data) {
        
        console.log(date + 'requesting settings for ' + data.beh);
        socket.emit('requestSettings', { behaviour: data.beh, preset: data.preset, sendosc: data.sendosc});

    }

    // receive full settings update from server
    function updateSettings(data) {
        console.log("received " + data.behaviour + " settings (" + data.presetname + ").  Updating: \n\n\n\n\n" );
        //console.log("data: " + JSON.stringify(data.settings));

        if(objectList[data.behaviour] == null) {
            console.log(" I don't have any " + data.behaviour + " on this page.  Ignoring.");
            return;
        }

        var oldsettings = objectList[data.behaviour].settings;  // make a copy so we can merge later
        // console.log("my oldsettings length was " + Object.keys(oldsettings).length);

        // REPLACE THE OLD SETTINGS WITH THE NEW ONES - including any new nested folders, etc.
        objectList[data.behaviour].settings = data.settings;

        for(var s in oldsettings) { 
            if(data.settings[s] == undefined) {
                console.log(" adding " + s + " to my object " + data.presetname + " so I can create the gui, but warning - it won't be saved unless it is adjusted...");
                objectList[data.behaviour].settings[s] = oldsettings[s];  //  <- so any new params that weren't in this preset when it was created get added.
            }
        }

        // recreate the guis every time, but first check which folders are open (nested folders don't get recreated here. behaviour-specific calls for that, see gridrunner html page)
        if(objectList[data.behaviour].guiObj != null) {         
            for(var f in objectList[data.behaviour].guiObj.__folders) {   
                objectList[data.behaviour].folderstates[f] = objectList[data.behaviour].guiObj.__folders[f].closed;
                console.log(" folder " + f+ " is closed? : " + objectList[data.behaviour].folderstates[f]);
            }
        }

        rememberNestedFolders(data.behaviour);

        createGUIs(data.behaviour);  

        // now create subfolders for any saved sources:
        createNestedFolders(data.behaviour);

        /// now open any folders that were closed before.
        for(var f in objectList[data.behaviour].folderstates){
            if(objectList[data.behaviour].guiObj != null) {   
                if(objectList[data.behaviour].guiObj.__folders[f] == null) continue;  // ignore subfolders
                objectList[data.behaviour].guiObj.__folders[f].closed = objectList[data.behaviour].folderstates[f];
            }
        }

           


        // } 
        // otherwise, iterate through and set each value --- doesn't work for nested/arrays (jul 22, 2020)
       // else {


            //  for (var s in data.settings) {
            //      if(objectList[data.behaviour].settings[s] != undefined ) {  // if we already know it...
            //   //      && !(Array.isArray(objecList[data.behaviour].settings[s]))) { // ... and it is not an array...
            //         objectList[data.behaviour].settings[s] = data.settings[s]; 
            //         console.log(" updated " + s + " to " + data.settings[s]);   
            //       console.log(s + ": " + oldsettings[s] + " -> " + data.settings[s]);
            //     }
            //  } 

            // // for(var s in oldsettings) {  // go through the old ones and if they aren't in the new one, add them.

            // //  if(Array.isArray(oldsettings[s])) {
            // //      console.log(s +" is an Array!");
            // //      continue;
            // //  }

            
            //       if(oldsettings[s] != data.settings[s] && data.settings[s] != undefined) {
            //          objectList[data.behaviour].settings[s] = data.settings[s];
            //           // socket.emit('sendDatOSC', { behaviour: data.behaviour, name: s, value: data.settings[s] });
            //  //     }
            //  //}
         //        }

        // instead of changing each one, send signal to tell behaviourengine to load new preset
        // but don't send if it is 'current'
 
        // new preset, so set the '*' value to false - will be taken care of by next call (switchselector...)
        // setChanged(data.behaviour, false);

        if(data.presetname != 'current') {
        // change the selector to reflect that we've updated the data (this should not triger a loop!)
            switchSelectorToPresetNamed({beh: data.behaviour, val: data.presetname});
        }



     // server will do this directly now, so this is the end of the road for updating presets. -mg Aug 15 2020

     //   if(data.presetname != 'current') {
     //       socket.emit('sendDatOSC', { behaviour: data.behaviour, name: 'presetName', value: data.presetname });
     //   }

      
    }

    // request preset list for a behaviour
    function requestPresets(behaviour) {
        console.log(date + 'requesting preset list for ' + behaviour);
        socket.emit('requestPresets', behaviour);
    }

    // receive preset list update from server
    function populatePresets(data) {
        console.log("received " + data.behaviour + " preset list.  Updating..." + JSON.stringify(data.presetlist));
        objectList[data.behaviour].presets = data.presetlist;
      
        for(p of data.presetlist) {
             addPresetToList(data.behaviour, p, false);
        }

    }


    function addPresetToList(behaviour, presetname, setSelected) {
        
        var presetselector = document.getElementById("presets-" + behaviour);

        const opt = document.createElement('option');
        opt.innerHTML = presetname;
        opt.value = presetname;

        var exist_index = 0;

        var presets = presetselector.children;
        var exists = false;
    
        for(var p of presets) {
            if (p.value == presetname) {
                exists = true;
                console.log("found preset " + presetname + " at index " + exist_index);
                break;
            }
            exist_index ++;
        }

        if (!exists) {
            presetselector.appendChild(opt);

            if (setSelected) {
                presetselector.selectedIndex = presetselector.length - 1;
            }
        } else {
            if (setSelected) {
                presetselector.selectedIndex = exist_index;
            }
        }
    }

    function loadPreset(beh) {

        var presetselector =  document.getElementById("presets-" + beh);

        var abandon    = objectList[beh].ischanged;
        var lastindex  = objectList[beh].curpresetindex;
        var lastpreset = presetselector[lastindex].value;

        if(abandon) {

            if (confirm("Do you want to save changes to " + lastpreset + "?")) {
                savePresetNamed(beh, lastpreset);
            }
            
            presetselector[lastindex].innerHTML = presetselector[lastindex].value;  // remove the star from last preset
        }

        const currentpreset = presetselector[presetselector.selectedIndex];
        objectList[beh].curpresetindex = presetselector.selectedIndex;

        console.log(date + 'requesting settings for ' + beh + ' -> ' + currentpreset.value + ' and send osc request also, please');
        socket.emit('requestSettings', { behaviour: beh, preset: currentpreset.value, sendosc: true});

    }

    function getCurrentPresetName(beh) {

        var presetselector =  document.getElementById("presets-" + beh);
        var index  = objectList[beh].curpresetindex;
        var preset = presetselector[index].value;
        return preset;

    }

    function switchSelectorToPresetNamed(data) {
        // special format from syncmyclient: data.beh and data.presetname are packed in here

        console.log("going to change preset for " + data.beh + " to " + data.val);

        // since this is a remote call, first unset 'changed' flags to current option -- discard changes
        setChanged(data.beh, false);

        var presetselector = document.getElementById("presets-" + data.beh);
        var presets = presetselector.children;
        var presetindex = -1;
    
        for(presetindex = 0 ; presetindex < presets.length ; presetindex++) {
            if (presets[presetindex].value == data.val) {
                presetselector.selectedIndex = presetindex;
                return;
            }
        }

        // if nothing matched (because we haven't updated yet?), set it to "current" and turn off saving
        presetselector.selectedIndex = 0;
        setChanged(data.beh, false);

    }

    function revertPreset(beh) {

        var presetselector =  document.getElementById("presets-" + beh);
        const currentpreset = presetselector[presetselector.selectedIndex];

        console.log(date + 'reverting settings for ' + beh + ' -> ' + currentpreset.value);
        socket.emit('requestSettings', { behaviour: beh, preset: currentpreset.value , sendosc: true});

    }

    function savePreset(beh) {
        var presetselector =  document.getElementById("presets-" + beh);
        var curpreset = presetselector[presetselector.selectedIndex];
        console.log("trying to save " + curpreset.value)
        savePresetNamed(beh, curpreset.value);
    }

    function savePresetNamed(beh, presetname) {
            console.log(date + 'requesting save of ' + presetname + ' for ' + beh);
            socket.emit('saveSettings', {behaviour: beh, preset: presetname});
            setChanged(beh, false);
    }

    function savePresetAs(beh) {
        const presetName = prompt('Enter a new preset name.');

        if (presetName) {
            if(presetName == 'current') {

                alert("Can't use the word 'current' for a preset name. Pick anything else. (Except 'new')");
                return;

            }

            if(presetName == 'new') {

                alert("Can't use the word 'new' for a preset name. Pick anything else. (Except 'current')");
                return;

            }
            
            savePresetNamed(beh, presetName);
            addPresetToList(beh, presetName, true);
        }
    }

    function setChanged(behaviour, isChanged) {

        var presetselector =   document.getElementById("presets-" + behaviour);
        var savebutton =       document.getElementById("save-" + behaviour);
        var revertbutton =     document.getElementById("revert-" + behaviour);
        const currentpreset = presetselector[presetselector.selectedIndex];

        if(currentpreset.value == "" || currentpreset.value == "new") return; // if it is default ("Current") or "new"
        
        if(isChanged) {
            objectList[behaviour].ischanged = true;
            savebutton.disabled = false;
            revertbutton.disabled = false;
            currentpreset.innerHTML = currentpreset.value + ' *';
      
        } else {
            objectList[behaviour].ischanged = false;
            savebutton.disabled = true;
            revertbutton.disabled = true;
            currentpreset.innerHTML = currentpreset.value;
        }
        
    }


