// TODO: Impliment functionality for the following

// for processing
// message format /GUI/Sleep
// with potential expansion to trigger behaviour modes


var express = require('express');
var socket = require('socket.io');
var osc = require('node-osc');
var fs = require('fs');
var glob = require('glob');
var gaslightdata = {};
var opn = require('opn');
const { Hmac } = require('crypto');
const { exitCode, kill } = require('process');
var active_cues = {};
var cue_step_interval = 250;

const puppeteer = require('puppeteer');

const { exec } = require('child_process');

var watchdog_timeout_id = null;
var watchdog_warning_id = null;
var watchdog_timeout_time = 120000; // 2 minute timeout with no 'ping' from Processing triggers a killswitch which restarts Control


// directory for storing and looking for behaviours -- this should be a simlink (ln -s command in terminal) to the data folder
// const behaviourdir = "./behaviour_settings_gridrunner/";
 const behaviourdir = "./behaviour_settings_simulator/";
//const behaviourdir = "./behaviour_settings_amatria/";

// shell commands to launch ** Note relies on relative paths between server and processing-simulator directories
const killControlScript = "../../KILL_MEANDER.command";
const launchControlScript = "../../LAUNCH_MEANDER.command";

// Client Ip & Port for Lighting Control board
var lightClientIp = '10.30.64.137';
var lightClientPort = 8005;

//credentials for client log in
//Note: this should probably obfuscated/ encrypted and not just sitting here in plain text... 
// credentials are stored ['username','password','destination']
var credentials = [
    ['meanderadmin','controlMeander','control2.html?'],
    ['control','trycontrol','control.html?'],
    ['meanderinterpretive','controlInterp', 'interpretive.html?' ],
    ['behaviour', 'behaviour', 'behaviours.html?'],
    ['dat', 'trydat', 'dat_behaviours_2.html?'],
    ['patcher', 'dopatcher', 'patcher.html?'],
    ['sample', 'sample', 'sample_gui.html?'],
    ['lights', 'trylights', 'lighting_engine.html?'],
    ['sceneswitcher', 'tryswitcher', 'scene_switcher.html?'],
    ['soundsliders', 'trysound', 'sound_sliders.html?'],
    ['performance', 'tryperformance', 'performance.html?'],
    ['guestpaint','trypainting', 'paintbrush.html?' ],
    ['launcher', 'trylauncher', 'launcher.html?']
]

// Client Ip for Control Computer
// var masterClientIp = '172.23.1.99';
var masterClientIp = '127.0.0.1';

// Port for Max audio control
var audioClientPort = 6666;

// Port for gui server
var guiServerPort = 3002;

// Port for Behaviour control
var behaviourClientPort = 3001;

// Client Ip for Interpretive Display Pi 1
var piIp1 = '172.23.1.41';
var piIp2 = '172.23.1.42';
var piIp3 = '172.23.1.43';
var piClientPort = 9001;

var interpOscClient1 = new osc.Client(piIp1, piClientPort);
var interpOscClient2 = new osc.Client(piIp2, piClientPort);
var interpOscClient3 = new osc.Client(piIp3, piClientPort);

lightOscClient = new osc.Client(lightClientIp, lightClientPort);
audioOscClient = new osc.Client(masterClientIp, audioClientPort);

behaviourOscClient = new osc.Client(masterClientIp, behaviourClientPort);
oscServer = new osc.Server(3006, '172.23.1.99'); /// 3006 b/c 3000 potentially conflicts with Max/Ableton

//Initialize server, socket and osc client
var app = express();
var server = app.listen(guiServerPort);

var io = socket(server);
var oscClient;
var numConnections = 1; // used temporarily to toggle lights
var muteState = false;
var gestureState = true;
var piMonitorState1 = true; // keep track of interpretive display monitor state.
var piMonitorState2 = true; // keep track of interpretive display monitor state.
var piMonitorState3 = true; // keep track of interpretive display monitor state.
var rhState = false;
var awState = true;
var tlState = false;
var loginId = "";
var currentSocket = "";
var sleepTimer = "";
var wakeTimer = "";

// identify hosted public folder
app.use(express.static('public'));
io.sockets.on('connection',newConnection);


// Call update functions on a 10 second (10000ms) interval
// this needs to live outside of the socket connection
// so it happens regardless of a client connection
// This just sends the current mute state to max
setInterval(sendMuteState,10000);     // <-- commenting this out for now to avoid continuously resetting Max volume.
setInterval(checkTimers, 30*60*1000) // every half hour


// launch browser window:
// opens the url in the default browser 
if(process.platform!='linux'){
    console.log( Date(Date.now()) + 'launching gui page... ');
    opn("http://" + masterClientIp + ":" + guiServerPort);
}else{
    async function brower_run(){
        console.log("Running puppeteer...");
        const browser = await puppeteer.launch();
        const page = await browser.newPage();
        await page.goto("Http://" + masterClientIp + ":" + guiServerPort);
        await page.screenshot({path: 'screenshot.png'});
        await page.waitFor(50000);
        browser.close();
    }
    brower_run();
}

    
/////////////////////////////////////////////////////////
////       Receive OSC / Recieve Socket / Send OSC   ////
/////////////////////////////////////////////////////////

// Set up OSC receiving functions 

oscServer.on('/PING', sendPing);
oscServer.on('/useWatchdog', function(msg) {
    setUseWatchdog(msg);
});
oscServer.on('/setDatParameter', function(msg) {
    setDatParameter(msg);
});
oscServer.on('/addPatchable', function(msg) {
    addPatchable(msg);
});
oscServer.on('/patchableCommand', function(msg) {
    patchableCommand(msg);
});
oscServer.on('/swapPreset', function(msg) {
    loadDatPresetOSC(msg);
});


function sendPing(){
    behaviourOscClient.send('/serverMessage/ping')
    //   console.log('...ping!')

    if(gaslightdata.useControlWatchdog == true) {
        if(watchdog_timeout_id) {
            clearTimeout(watchdog_timeout_id);
            clearTimeout(watchdog_warning_id);
        }
        watchdog_warning_id = setTimeout(warnRestartControl, watchdog_timeout_time-30000);
        watchdog_timeout_id = setTimeout(restartControl, watchdog_timeout_time);
    }
}

/// watchdog functions to manage restarting the Control system

function setUseWatchdog(params) {
    gaslightdata.useControlWatchdog = false;
    gaslightdata.useControlWatchdog = (params[1] == 'true' || params[1] == 'TRUE');
    if(gaslightdata.useControlWatchdog == true) {
        console.log(Date(Date.now()) + " Activated control watchdog via OSC");
    } else { 
        console.log(Date(Date.now()) + " Deactivated control watchdog via OSC");
        if(watchdog_timeout_id) {
            clearTimeout(watchdog_timeout_id);
            clearTimeout(watchdog_warning_id);
        }
    }
    rewriteData(gaslightdata);
}

function warnRestartControl() {
    console.log(Date(Date.now()) + " *** Warning - no pings received recently, will restart control in 30s");
}

function restartControl() {

    console.log(Date(Date.now()) + " *** RESTARTING CONTROL");
        killControl();
        setTimeout(launchControl, 2000);

}

function launchControl() {
    console.log(Date(Date.now()) + " *** LAUNCHING CONTROL PROCESS");   
    exec('open ' + launchControlScript, (err, stdout, stderr) => {   // use "open" because we want a new shell
        if (err) {
          //some err occurred
          console.error(err)
        } else {
         // the *entire* stdout and stderr (buffered)
         console.log(`stdout: ${stdout}`);
         console.log(`stderr: ${stderr}`);
        }
    });
}

function killControl() {

    console.log(Date(Date.now()) + " *** KILLING CONTROL PROCESS");   

    // first disarm the watchdog if we are killling it
    setUseWatchdog("false");

    exec(killControlScript, (err, stdout, stderr) => {
        if (err) {
          //some err occurred
          console.error(err)
        } else {
         // the *entire* stdout and stderr (buffered)
         console.log(`stdout: ${stdout}`);
         console.log(`stderr: ${stderr}`);
        }
    });
}

/// send the paintbrush coords via OSC 
function paintBrush(coords) {
    behaviourOscClient.send("/serverMessage/paintbrush", coords.x, coords.y, coords.d);
}



/// receive dat parameters via OSC (ie from ML agent or Processing)

function setDatParameter(params){

   // console.log( Date(Date.now()) + " [via OSC] " + params[1] + "->" + params[2] + ": " + params[3] + " (for " + params[4] +")");
    var data = { behaviour: params[1], name: params[2], value: params[3], target: params[4] };
    sendDatOSC(data);
    
}

/// receive command to change to a new preset via osc

function loadDatPresetOSC(params) {

    // console.log( Date(Date.now()) + " [via OSC]  Switch to preset: " + params[1] + "->" + params[2] + "...");
    var data = { behaviour: params[1], preset: params[2], sendosc: true};  // include a callback to processing to load the behaviour
    loadDatPreset(data);

}

/// one generic OSC function to rule them all!

function sendDatOSC(data) {

    if(data.target != null) {  // there is a nested behaviour here (like a ParticleSource)
        // special case: want to just highlight that folder:
        if(data.name=="highlightFolder") {
            // don't send via OSC back to Processing, skip this and just emit.
        } else {
            behaviourOscClient.send('/serverMessageDatSetting/' +data.target +" " + data.name + " " + data.value);
        }
    } else {   // normal 
    // console.log( Date(Date.now()) + " " + data.behaviour + "->" + data.name + ": " + data.value);
        behaviourOscClient.send('/serverMessageDatSetting/' +data.behaviour +" " + data.name + " " + data.value);
    }

    socket.broadcast.emit('syncClients', { beh: data.behaviour, param: data.name, val: data.value, targ: data.target });

    if (currentSocket != ""){          // this is in case the incoming values are from OSC, not from an existing socket
        socket = currentSocket;
        socket.emit('syncClients', { beh: data.behaviour, param: data.name, val: data.value, targ: data.target });
    }
}

/// (okay, two - this one for functions -- triggered by buttons in the DAT Gui)

 function sendDatCommand(data) {
    console.log( Date(Date.now()) + "  Sending command:  /serverMessageDatCommand/" + data.behaviour + "->" + data.name + ": " + data.value);
    behaviourOscClient.send('/serverMessageDatCommand/' +data.behaviour +" " + data.name + " " + data.value);

    // don't need to sync clients b/c this was a function call, not an update.
 }


/////////////// PATCHER AND PATCHABLES    

/// receive patchables via OSC (ie from ML agent or Processing)

function addPatchable(params){

    // console.log("Message was " + params);
    console.log(" Adding Patchable " + params[1]);

    var patchable = { title: params[1], in: JSON.parse(params[2]), out: JSON.parse(params[3]) };

    if (currentSocket != ""){          // this is in case the incoming values are from OSC, not from an existing socket
        socket = currentSocket;
        socket.emit('addPatchable', patchable);
    }
    
    socket.broadcast.emit('addPatchable', patchable);
}

function patchableCommand(params) {
    var cmd = { name: params[1], command: params[2] };
    // console.log("Received command " + cmd.command + " for " + cmd.name)
    if (currentSocket != ""){          // this is in case the incoming values are from OSC, not from an existing socket
        socket = currentSocket;
        socket.emit('patchableCommand', cmd);
    }   try { 
    socket.broadcast.emit('patchableCommand', cmd);
    } catch(err) {
        console.log("  Hm... seems like someone is sending a patchable command but doesn't exist yet?: " + cmd.name + "-> " + cmd.command);
    }
}

function sendPatchableUpdate(data) {

    cmd = ("updatePatchable" + " " + data.patchable);  // by default

    // special case: if I want to add or remove a Connector -- we'll send it twice, but that's OK.
    if(data.patchable.includes("Connector")) {
        cmd = data.patchable;
    }

    /// here is where we put the commands from the P5 patcher to the Processing patcher engine.
    behaviourOscClient.send('/serverMessagePatcher/' + cmd + " " + JSON.stringify(data.params));
    console.log("Sending via OSC: " + '/serverMessagePatcher/' + cmd +" " + JSON.stringify(data.params));

//    socket.broadcast.emit('syncClients', { obj: data.patchable, param: data.name, val: data.value });

//    if (currentSocket != ""){          // this is in case the incoming values are from OSC, not from an existing socket
//        socket = currentSocket;
//        socket.emit('syncClients', { obj: data.patchable, param: data.name, val: data.value });
//    } 

}

//////    --- add the cues?

function loadDatPreset(data) {  // { behaviour: ___, preset: ____ , sendosc: _____ }

console.log( Date(Date.now()) + " Requesting: " + data.behaviour + "_settings_" + data.preset + " with sendosc as " + data.sendosc);

let raw = {};
let s = {};

try {
raw = fs.readFileSync(behaviourdir + data.behaviour + "_settings_" + data.preset + ".json");
s = JSON.parse(raw);
} catch(err) {
    console.log(" Uh, oh, problem reading " + data.behaviour + "_settings_" + data.preset + ":  " + err);
    return;
}

if(socket == null) { 
    console.log(" ... not ready yet.  Stray calls from open windows? ");
    return; 
}

console.log( Date(Date.now()) + "<--- Sending data to GUIs... ");

// 1. tell EVERYONE to update their internals.
// first to the socket person who called me.
socket.emit('updateSettings', { behaviour: data.behaviour, settings: s, presetname: data.preset});

// next to everyone else
if (currentSocket != ""){          // this is in case the incoming values are from OSC, not from an existing socket
    socket = currentSocket;
    socket.broadcast.emit('updateSettings', { behaviour: data.behaviour, settings: s, presetname: data.preset});
    // beh: data.behaviour, param: 'changeToNewPreset', val: data.preset });
    }

// 2.  tell Processing to load the behaviour object's new preset'
   if(data.sendosc == true) {
    console.log( Date(Date.now()) + "     ... and telling Processing to update --->");
    behaviourOscClient.send('/serverMessageDatSetting/' +data.behaviour +" presetName " + data.preset);
   } else {
       console.log( Date(Date.now()) + "       ... ommitting the call back to Processing this time -----||   ");
   }

}





/// OSC COMMANDS FOR TESTS AND SLEEP/WAKE

oscServer.on('/putMeanderToSleep', processingSleep);
oscServer.on('/wakeMeanderUp', processingWake);


function processingSleep(){
    behaviourOscClient.send('/serverMessage/sleep')
    audioOscClient.send('/masterMute', 0);  
    gaslightdata.muteState = true; // With periodic updates we need to update the mute state, or it will get unmuted after 10 seconds
    gaslightdata.manualMute = false; // track manual vs sleep/wake mutes with a property
    gaslightdata.sleepState = true;
    console.log(Date(Date.now())+ 'sleeping Meander')
    rewriteData(gaslightdata);
}

function processingWake(){
    behaviourOscClient.send('/serverMessage/wake')
    if (!gaslightdata.manualMute) {   // this means NOT manually muted... 
        audioOscClient.send('/masterMute', 1);  // wasn't manually muted, so unmute when we wake up
    }
    gaslightdata.sleepState = false;
    console.log(Date(Date.now())+ 'Waking Meander')
    rewriteData(gaslightdata);
}




function sendMuteState(){
    // 1 is the unmute signal 
    // 0 is the mute signal
    var muteValue = 0;
    var volume = gaslightdata.masterVolume
    if (!gaslightdata.muteState){muteValue=1} // if mutestate is false, send unmute
    audioOscClient.send('/masterMute', muteValue);  //send the current mute state
    audioOscClient.send('/masterVolume', parseFloat(volume));
    //console.log(Date(Date.now()) + 'updateing max mute state: ' + gaslightdata.muteState)
    //console.log(Date(Date.now()) + 'updateing max volume: ' + volume)
}


// Run Set Timers once a day to make sure that the timers are refreshed 
function checkTimers(){
    createTimerCallback(gaslightdata.sleepTimes)
    console.log( Date(Date.now()) + 'Checking Timers')
}

function createTimerCallback(values){
   
    sleepHour = parseInt(values[0]) 
    sleepMin = parseInt(values[1])
    wakeHour = parseInt(values[2])
    wakeMin = parseInt(values[3])


    currentDate = new Date(Date.now())

    
    currentHour = parseInt(currentDate.getHours())
    currentMinute = parseInt(currentDate.getMinutes())

    sleepDate = currentDate
    wakeDate = currentDate
    
    // set sleep date
    if (currentHour > sleepHour){
        sleepDate = addDays(sleepDate,1)
    }
    else if (currentHour == sleepHour && currentMinute >= sleepMin){
        sleepDate = addDays(sleepDate,1)
    }

    // set sleep date
    if (currentHour > wakeHour){
        wakeDate = addDays(wakeDate,1)
    }
    else if (currentHour == wakeHour && currentMinute >= wakeMin){
        wakeDate = addDays(wakeDate,1)
    }

    // timezone is hardcoded as +5 right now... should fix that 
    sleepDate = new Date(sleepDate.getFullYear(),sleepDate.getMonth(),sleepDate.getDate(),sleepHour, sleepMin)
    wakeDate = new Date(wakeDate.getFullYear(),wakeDate.getMonth(),wakeDate.getDate(),wakeHour, wakeMin)
    console.log("current date: " + currentDate)
    console.log("sleep date: " + sleepDate)
    console.log("wake date: " + wakeDate)

    timeTillSleep = sleepDate - currentDate
    timeTillWake = wakeDate - currentDate

    console.log('time till sleep ' + timeTillSleep)
    console.log('time till wake ' + timeTillWake)

    if(sleepTimer!=""){clearTimeout(sleepTimer)}
    if(wakeTimer!=""){clearTimeout(wakeTimer)}
    
    sleepTimer = setTimeout(function(){
        console.log(Date(Date.now())+ 'Sleep Timer Triggered, Timer enabled?: ' + gaslightdata.timerActive)
        if (gaslightdata.timerActive){
            processingSleep()
        }},timeTillSleep)

    wakeTimer = setTimeout(function(){
        console.log(Date(Date.now())+ 'Wake Timer Triggered, Timer enabled?: ' + gaslightdata.timerActive)
        if (gaslightdata.timerActive){
            processingWake()
        }},timeTillWake)   
}

function addDays(date, days) {
    var result = new Date(date);
    result.setDate(result.getDate() + days);
    return result;
}

if (!fs.existsSync('gaslightdata.json')){
    var emptyJson = {};
    fs.appendFile('gaslightdata.json',JSON.stringify(emptyJson,null,2),callback)
}
else{
    callback();
}

// Startup Callback
function callback(){
    var data = fs.readFileSync('gaslightdata.json');
    gaslightdata = JSON.parse(data);
    console.log(gaslightdata);
    checkTimers();
    
}

/////////////////////////////////////////  S O C K E T - S P E C I F I C

function newConnection(socket){
    currentSocket = socket

    console.log( Date(Date.now()) + 'new connection: ' + socket.id);

    // MAJOR FUNCTIONS TO START OR STOP CONTROL
    socket.on('restartControl', callRestartControl);
    socket.on('launchControl', callLaunchControl);
    socket.on('killControl', callKillControl);


    // GENERIC FUNCTIONS for DATGui!   -mg
    socket.on('sendDatOSC', sendDatOSC);            // non-socket specific
    socket.on('sendDatCommand', sendDatCommand);  
    socket.on('requestSettings', loadDatPreset);
    socket.on('requestPresets', loadPresetList);
    socket.on('saveSettings', saveDatSettings);

    //  GENERIC FUNCTIONS FOR Patcher  
    socket.on('sendPatchableUpdate', sendPatchableUpdate);

    // PAINTBRUSH
    socket.on('paintbrush', sendPaintBrushCoords);


    // Define Socket Messages and their Corresponding function
    socket.on('muteToggle',muteToggle);
    socket.on('toggleSoundFile',toggleSoundFile);
    // socket.on('turnOffSoundFiles',turnOffSoundFiles);
    socket.on('gestureToggle',gestureToggle);
    socket.on('setVolume',setVolume);
    socket.on('triggerGesture',triggerGesture);
    socket.on('triggerLightGesture', triggerLightGesture)
    socket.on('toggleInterpDisplay',toggleInterpDisplay);
    socket.on('rhToggle',rhToggle);
    socket.on('setRHSpeed',setRHSpeed);
    socket.on('awToggle',awToggle);
    socket.on('setAwVelocity',setAwVelocity);
    socket.on('setAwAmplitude',setAwAmplitude);
    socket.on('setAwPeriod',setAwPeriod);
    socket.on('setAwAngle',setAwAngle);
    socket.on('tlToggle',tlToggle);
    socket.on('setTlState',setTlState);
    socket.on('setTlScaleFactor',setTlScaleFactor);
    socket.on('checkCredentials',checkCredentials);
    socket.on('verifyLogin', verifyLogin);
    socket.on('sleepButton', callSleep);
    socket.on('wakeButton', callWake);
    socket.on('radioLight', radioLight);
    socket.on('behaviourScene', behaviourScene);
    socket.on('load', emitUpdate);
    socket.on('setTimer', setTimerData);
    socket.on('useTimer',settimerActive);

    socket.on('setVolumeGeneric',setVolumeGeneric);
    socket.on('setBehaviourIntensity',setBehaviourIntensity);
    


    /////////////////////////////////////////
    ////         Login Functions         ////
    /////////////////////////////////////////

    function checkCredentials(uPid){
        // log recieved Username, Password, and Connection ID
        console.log( Date(Date.now()) + uPid)
        var uname = uPid[0];
        var psw = uPid[1];
        var id = uPid[2];
        
        // check password
        for (i=0; i<credentials.length; i++){
            credCheck = credentials[i];
            if (credCheck[0] == uname){
                if (credCheck[1] == psw){
                    loginId = id;
                    boolID = [true,id,credCheck[2]];
                    socket.emit('checkedCredentials',boolID);
                    console.log( Date(Date.now()) + 'all good')
                    return
                }
                else{console.log( Date(Date.now()) + 'incorrect password'); return}
            }
        }
        console.log( Date(Date.now()) + 'username not recognized')
    }

    function verifyLogin(inputId){
        console.log(Date(Date.now())+"input Id: " +inputId)
        console.log(Date(Date.now())+"login Id: " +loginId)
        if (inputId == ('?'+loginId)){
            socket.emit("loginVerified",true)
        }
        else{socket.emit("loginVerified",false)}

    }


    /// load DAT.gui settings from disk for this connection - replaced with a 
     //   non-connection-specific version above, so I can change programmatically via OSC.
/*
    function loadDatSettings(data) {  // { behaviour: ___, preset: ____ , target: (optional) <- am i using}

        console.log( Date(Date.now()) + " Requesting: " + data.behaviour + "_settings_" + data.preset);
        let raw = fs.readFileSync(behaviourdir + data.behaviour + "_settings_" + data.preset + ".json");
        let s = JSON.parse(raw);

        // if(data.target != undefined) { // we are looking for a nested target..
        
        //     var t = data.target;       // string name of source
        //     // for now, hardcode to look in the "particleSources" array

        //     if(s.particleSources[data.target] != undefined) {

        //         console.log( Date(Date.now()) + " Sending subset of data called )
        //     }


            
        // }

        console.log( Date(Date.now()) + " Sending data... ");
        socket.emit('updateSettings', { behaviour: data.behaviour, settings: s, presetname: data.preset});

        // now sync the rest of my clients to this new preset
        socket.broadcast.emit('syncClients', { beh: data.behaviour, param: 'changeToNewPreset', val: data.preset });

    }
*/

    function loadPresetList(beh) {
        console.log( Date(Date.now()) + " Looking for all " + beh + " presets...");
         // do a directory search for presets that aren't called 'current'.

         var presets = [];

         var files = glob.sync(behaviourdir+ beh + "_settings_*.json");
         for(var filename of files) {
             var p = filename.substring((behaviourdir.length + beh.length+10), filename.lastIndexOf('.json'));  // truncate after '_settings_'
             if(p != 'current') {
                 presets.push(p);  // current is special, don't use it.
             }
         }
         console.log(Date(Date.now()) + " ... sending:  " + JSON.stringify(presets));
         socket.emit('populatePresets', { behaviour: beh, presetlist: presets });

    }

    /// save DAT.gui settings to disk (actually, this simply copies the file "XXXXX_current.json" to the new filename (hack, but it works!)

    function saveDatSettings(data) {   // { behaviour: ___, preset: ____ }
       
        console.log( Date(Date.now()) + " Saving: " + data.behaviour + "_settings_" + data.preset + ".json");
        fs.copyFile(behaviourdir + data.behaviour + "_settings_current.json", behaviourdir + data.behaviour + "_settings_" + data.preset + ".json", (err) => {
            if (err) throw err;
            console.log(" Success.");
          });

        // sync all my clients' preset lists...
        socket.broadcast.emit('syncClients', { beh: data.behaviour, param: 'reloadPresetList', val: data.preset });

    }

    //////////
    function callKillControl() {
        killControl();
    }

    function callRestartControl() {
        restartControl();
    }

    function callLaunchControl() {
        launchControl();
    }

    //////////

    function sendPaintBrushCoords(coords) {
        paintBrush(coords);
    }


    //////////

    function settimerActive(bool){
        gaslightdata.timerActive = JSON.parse(bool)
        rewriteData(gaslightdata);
    }

    function callSleep(){
        processingSleep()
    }

    function callWake(){
        processingWake()
    }

    function setTimerData(values){
        
        gaslightdata.sleepHour = values[0]
        gaslightdata.sleepMin = values[1]
        gaslightdata.wakeHour = values[2]
        gaslightdata.wakeMin = values[3]

        console.log ('Sleep Time: ' + gaslightdata.sleepHour + ":" + gaslightdata.sleepMin)
        console.log ('Wake Time: ' + gaslightdata.wakeHour + ":" + gaslightdata.wakeMin)

        rewriteData(gaslightdata);
        createTimerCallback(values);
    }


    function triggerLightGesture(gesture){
        // OSC message reference: https://support.etcconnect.com/ETC/Consoles/ColorSource/ColorSource_20_and_40_AV/OSC_Commands_for_ColorSource_AV_Console
        killPlaybacks(0,81); // Kills all playbacks
        if (gesture.type == 'playback'){
            console.log( Date(Date.now()) + 'triggering playback: ' + gesture.id + ' at level: ' + gesture.level);
            lightOscClient.send(('/cs/playback/' + gesture.id + '/level'), gesture.level);
        }
        else if (gesture.type == 'cue'){
            console.log( Date(Date.now()) + 'triggering lighting cue: ' + gesture.id);
            lightOscClient.send('/cs/playback/gotocue/' + gesture.id);
            // lightOscClient.send('/cs/playback/go');
        }
        else{
            console.log( Date(Date.now()) + 'unknown light gesture type called');
        }
    }

    function killPlaybacks(min,max){
        for(var i = min; i < max; i++){
            lightOscClient.send(('/cs/playback/' + i + '/level'), 0);
        }
    }
    
    function behaviourScene(scene){
        console.log( Date(Date.now()) + "  *** SWITCHING TO SCENE:  " + scene + " [ " + socket.id + " ]");
        gaslightdata.behaviourScene = scene
        behaviourOscClient.send('/serverMessage/scene', scene);
        rewriteData(gaslightdata);
        try {
            loadCues(scene);
        } catch (err) {
            console.log(Date(Date.now()) + err);
            // console.log(Date(Date.now()) + "No cue_settings file for this scene");
        }
        
    }

    function loadCues(scene){
        console.log(Date(Date.now()) + "clearing existing cues for scene change");
        for (let i in active_cues){
            clear_timeouts(i);
        }
        console.log(Date(Date.now()) + "loading cues for scene: " + scene);
        var cue_settings = fs.readFileSync(behaviourdir + 'cue_settings_' + scene + '.json');
        var cue_settings_json = JSON.parse(cue_settings);
        for (let q in cue_settings_json){
            send_timeout_coummands(q, cue_settings_json[q]);
        }
    }

    function send_timeout_coummands(name, cue){
        var timeoutID = setTimeout(console.log, cue.start_time, (Date(Date.now()) + "starting cue for " + cue.behaviour + " , parameter: " + cue.param)); // console log message for each cue
        if (active_cues[name] == null){
            active_cues[name] = [];
        }
        active_cues[name].push(timeoutID);
        // interpolate the parameter values over the duration of the cue
        var linear_interpolation_delta = cue.end_value - cue.start_value;
        
        for(var step = 0; step <= cue.duration; step += cue_step_interval){
            var interpolation_proportion = step/cue.duration; // should be range 0-1, like a percentage
            var datMessage = {};
            datMessage.behaviour = cue.behaviour;
            datMessage.name = cue.param;
            datMessage.value = cue.start_value + (linear_interpolation_delta * interpolation_proportion);
            if(cue.target != null) { // Target is for specifying a nested behaviour, like gridrunner source
                datMessage.target = cue.target;
            }
            if(cue.behaviour == "globalSetting"){
                // can't use sendDatOSC for a global setting
                if(cue.param == "behaviourIntensity"){
                    timeoutID = setTimeout(setBehaviourIntensity, cue.start_time + step, datMessage.value);
                }
            } else {
                timeoutID = setTimeout(sendDatOSC,cue.start_time + step, datMessage);
            }
            active_cues[name].push(timeoutID);
        }
    }

    function clear_timeouts(cue_name){
        for (let i in active_cues[cue_name]) {
            clearTimeout(active_cues[cue_name][i]);
            /// remove [cue name] object from active_cues here.
        }
    }



    function radioLight(value){
        var playback = value[1];
        var destination = value[0];
        var playbackseq = ["11","12","11","13","14","13","15","16","15"];

        if (destination == 'grotto'){ gaslightdata.grottoPlayback = playback;}
        else if (destination == 'river'){gaslightdata.riverPlayback = playback;}
        else if (destination == 'cloud'){gaslightdata.cloudPlayback = playback;}
        rewriteData(gaslightdata);
        killPlaybacks(30,36);
        var idx = playbackseq.indexOf(playback);
        if (idx != -1){
            console.log ('turning on playback: ' + playback + ' turning off playback: ' + playbackseq[idx+1]);

            // until we know how to do a fade without colors, we need to just turn them on:
            // fadeplayback(playback,true,2000);
 
                
            // just set the other playback directly to zero
            // if we had a way to get a playbacks current value from the CS40
            // we could lerp this nicely from current value to zero
            // but untill we figure that out this works - KC
            lightOscClient.send(('/cs/playback/' + playback + '/level'), 1); 
            lightOscClient.send(('/cs/playback/' + playbackseq[idx+1] + '/level'), 0); 
        }
        else{
            console.log ('turning off: ' + destination);
            var p1 = 0;
            var p2 = 0;
            if (destination == 'grotto'){p1=11;p2=12;}
            else if (destination == 'river'){p1=13;p2=14;}
            else if (destination == 'cloud'){p1=15;p2=16;}

            // see above re: lerping values to zero
            lightOscClient.send(('/cs/playback/' + p1 + '/level'), 0);
            lightOscClient.send(('/cs/playback/' + p2 + '/level'), 0);

        }
    }


    function muteToggle(data){
        if (!gaslightdata.muteState) {
            audioOscClient.send('/masterMute', 0);
            console.log( Date(Date.now()) + 'muting audio');
            gaslightdata.muteState = true;
            gaslightdata.manualMute = true; 
        }
        else{
            audioOscClient.send('/masterMute', 1);
            console.log( Date(Date.now()) + 'unmuting audio');
            gaslightdata.muteState = false;
            gaslightdata.manualMute = true; // back to manual 
        }
        rewriteData(gaslightdata);
        socket.broadcast.emit('muteToggle', muteState);

    }

    function toggleSoundFile(file){
        audioOscClient.send('/toggle' + file);
        console.log(Date(Date.now()) + 'playing sound file: ' + file);

    }

    // function toggleSoundFile(file){
    //     switch (file) {
    //         case 'MeanderComp01':
    //             if(!gaslightdata.playingMeanderComp01) {
    //                 audioOscClient.send('/toggle' + file);
    //                 console.log(Date(Date.now()) + 'playing sound file: ' + file);
    //                 gaslightdata.playingMeanderComp01 = true;
    //             }
    //             else {
    //                 audioOscClient.send('/toggle' + file);
    //                 console.log(Date(Date.now()) + 'stopping sound file: ' + file);
    //                 gaslightdata.playingMeanderComp01 = false;
    //             }
    //             rewriteData(gaslightdata);
    //             break;
            
    //         case 'Track8Min':
    //             if(!gaslightdata.playingTrack8Min) {
    //                 if(gaslightdata.playingMeanderComp01)
    //                     audioOscClient.send('/toggleMeanderComp01'); // turn off MeanderComp01
    //                 audioOscClient.send('/toggle' + file);
    //                 console.log(Date(Date.now()) + 'playing sound file: ' + file);
    //                 gaslightdata.playingMeanderComp01 = false;
    //                 gaslightdata.playingTrack8Min = true;
    //             }
    //             else {
    //                 audioOscClient.send('/toggle' + file);
    //                 console.log(Date(Date.now()) + 'stopping sound file: ' + file);
    //                 gaslightdata.playingTrack8Min = false;
    //             }
    //             rewriteData(gaslightdata);
    //             break;
    //         default:
    //             console.log(Date(Date.now()) + 'unrecognized sound file requested: ' + file);
    //             break;
    //     }
    // }

    // function turnOffSoundFiles() {
    //     console.log(Date(Date.now()) + 'stopping any playing sound files');
    //     if(gaslightdata.playingTrack8Min) {
    //         audioOscClient.send('/toggleTrack8Min');
    //         console.log(Date(Date.now()) + 'toggling ------------------------------');
    //         gaslightdata.playingTrack8Min = false;
    //     }
    //     rewriteData(gaslightdata);
    // }

    function gestureToggle(data){
        // Set State Directly
        if (typeof data == 'boolean'){
            if (data){
                behaviourOscClient.send('/sensorGestures/toggle', 1);
                console.log( Date(Date.now()) + 'Directly setting sensor sound gestures on');
                gaslightdata.gestureState = data;
            }
            else {
                behaviourOscClient.send('/sensorGestures/toggle', 0);
                console.log( Date(Date.now()) + 'Directly setting sensor sound gestures off');
                gaslightdata.gestureState = data;
            }
        }
        
        else{
            // Toggle
            if (!gaslightdata.gestureState) {
                behaviourOscClient.send('/sensorGestures/toggle', 1);
                console.log( Date(Date.now()) + 'setting sensor sound gestures on');
                gaslightdata.gestureState = true;
            }
            else{
                behaviourOscClient.send('/sensorGestures/toggle', 0);
                console.log( Date(Date.now()) + 'setting sensor sound gestures off');
                gaslightdata.gestureState = false;
            }
        }
        rewriteData(gaslightdata);
    }

    function setVolume(volume){
        audioOscClient.send('/masterVolume', parseFloat(volume));
        console.log( Date(Date.now()) + 'Volume: ' + volume);
        gaslightdata.masterVolume = volume;
        rewriteData(gaslightdata);
    }

    function toggleInterpDisplay(value){
        //toggle message based on current state
        var  interpOscClient = null
        var  piMonitorState = false
        if (value == 1){
            interpOscClient = interpOscClient1
            piMonitorState = piMonitorState1
            piMonitorState1 = !piMonitorState1
        }
        else if (value == 2){
            interpOscClient = interpOscClient2
            piMonitorState = piMonitorState2
            piMonitorState2 = !piMonitorState2
        }
        else if (value == 3){
            interpOscClient = interpOscClient3
            piMonitorState = piMonitorState3
            piMonitorState3 = !piMonitorState3
        }

        var message = 'on';
        if (piMonitorState){
            message = 'off';
        }

        // use incoming value to specify pi unit number
        interpOscClient1.send('/pipresents/unit01/core/monitor', message);
        console.log( Date(Date.now()) + 'Toggling Pi ' + value + "with state: " + message);
    }

    // Triggers Max Gesture based on button ID
    function triggerGesture(gestureNum){
        var soundOrNoise = ((Math.random() < 0.90) ? 1 : 2);  // 10 percent chance it is noise.
        audioOscClient.send('/gesture/trigger',gestureNum, soundOrNoise);
        console.log( Date(Date.now()) + 'Gesture ' + gestureNum + ' Triggered ' + ((soundOrNoise == 1) ? "(Sound)" : "(Noise)"));
    }

    // Set Riverhead speed from rhSlider
    function setRHSpeed(rhSpeed){
        behaviourOscClient.send('/riverHead/rhRingSpeed', parseFloat(rhSpeed));
        socket.broadcast.emit('setRHSpeed',rhSpeed)
        console.log( Date(Date.now()) + 'RH Speed: ' + rhSpeed);
    }
    
    // Toggles Riverhead
    function rhToggle(data){
        if (rhState) {
            behaviourOscClient.send('/riverHead/rhDisplayRings', 0);
            console.log( Date(Date.now()) + 'turning Riverhead off');
            rhState = false;
        }
        else{
            behaviourOscClient.send('/riverHead/rhDisplayRings', 1);
            console.log( Date(Date.now()) + 'turning Riverhead on');
            rhState = true;
        }
    }


    /////  experimental ambient wave adjustmnts  ======  mg March 10
    // Toggles AW Arrow
    function awToggle(data){
        if (awState) {
            behaviourOscClient.send('/ambientWaves/display', 0);
            console.log( Date(Date.now()) + 'turning aw arrow off');
            awState = false;
        }
        else{
            behaviourOscClient.send('/ambientWaves/display', 1);
            console.log( Date(Date.now()) + 'turning aw arrow on');
            awState = true;
        }

        socket.broadcast.emit('awToggle', awState);
    }

    // Set AW Velocity
    function setAwVelocity(awVelocity){
        behaviourOscClient.send('/ambientWaves/velocity', parseFloat(awVelocity));
        socket.broadcast.emit('setAwVelocity', awVelocity)
        console.log( Date(Date.now()) + 'AW Velocity: ' + awVelocity);
    }

    // Set AW Period
    function setAwPeriod(awPeriod){
        behaviourOscClient.send('/ambientWaves/period', parseFloat(awPeriod));
        socket.broadcast.emit('setAwPeriod', awPeriod)
        console.log( Date(Date.now()) + 'AW Period: ' + awPeriod);
    }

    // Set AW Amplitude
    function setAwAmplitude(awAmplitude){
        behaviourOscClient.send('/ambientWaves/amplitude', parseFloat(awAmplitude));
        socket.broadcast.emit('setAwAmplitude', awAmplitude)
        console.log( Date(Date.now()) + 'AW Amplitude: ' + awAmplitude);
    }

    // Set AW Angle
    function setAwAngle(awAngle){
        behaviourOscClient.send('/ambientWaves/angle', parseFloat(awAngle));
        socket.broadcast.emit('setAwAngle', awAngle)
        console.log( Date(Date.now()) + 'AW Angle: ' + awAngle);
    }

    /////  Timelapse Scale Factor adjustmnt  ======  rg March 26
    // Toggles TL Scale Factor
    function tlToggle(data){       
        if (tlState) {
            behaviourOscClient.send('/timelapse/tlon', 0);  
            console.log( Date(Date.now()) + 'turning timelapse scale factor off');
            socket.emit("behaviourScene",'default');  // switch to timelapse scene
            //socket.broadcast.emit('setSceneButtons','default');
            console.log( Date(Date.now()) + 'switching to Default scene');
            tlState = false;
        }
        else{
            behaviourOscClient.send('/timelapse/tlon', 1);
            console.log( Date(Date.now()) + 'turning timelapse scale factor on');
            socket.emit("behaviourScene",'timelapse');  // switch to timelapse scene
            //socket.broadcast.emit('setSceneButtons','timelapse');
            console.log( Date(Date.now()) + 'switching to Timelapse scene');
            tlState = true;
        }

        socket.broadcast.emit('tlToggle', tlState);
    }

    function setTlState(tlTargetState){       
        if (tlTargetState) {
            behaviourOscClient.send('/timelapse/tlon', 1);
            console.log( Date(Date.now()) + 'turning timelapse scale factor on');
            socket.emit("behaviourScene",'timelapse');  // switch to timelapse scene
            socket.emit('setSceneButtons','timelapse');
            console.log( Date(Date.now()) + 'switching to Timelapse scene');
            tlState = true;
        }
        else{
            behaviourOscClient.send('/timelapse/tlon', 0);
            console.log( Date(Date.now()) + 'turning timelapse scale factor off');
            socket.emit("behaviourScene",'default');  // switch to timelapse scene
            socket.emit('setSceneButtons','default');
            console.log( Date(Date.now()) + 'switching to Default scene');
            tlState = false;
        }

        socket.broadcast.emit('tlToggle', tlState);
    }

    // Set Timelapse Scale Factor
    function setTlScaleFactor(tlScaleFactor){
        behaviourOscClient.send('/timelapse/scalefactor', parseFloat(tlScaleFactor));
        socket.broadcast.emit('setTlScaleFactor', tlScaleFactor)
        console.log( Date(Date.now()) + 'Timelapse Scale Factor: ' + tlScaleFactor);
    }

};



function setVolumeGeneric(values){
    ids = values[0];
    volume = values[1];
    if (ids[0] == -1){
        audioOscClient.send('/masterVolume', parseFloat(volume));
        console.log( Date(Date.now()) + 'Master Volume: ' + volume);
        gaslightdata.masterVolume = volume;
        rewriteData(gaslightdata)
    }
    else{
        for (var i = ids[0]; i<=ids[1]; i++){
            audioOscClient.send('/speakerVolume', parseInt(i), parseFloat(volume));
            if (ids[0] == 1){gaslightdata.externalVolume = volume;}
            if (ids[0] == 25){gaslightdata.internalVolume = volume;}
        }
        console.log( Date(Date.now()) + 'Index:' + ids[0] + '-' + ids[1] + ' Volume: ' + volume);
    }
    rewriteData(gaslightdata);
}

function setBehaviourIntensity(values){
    behaviourOscClient.send('/serverMessage/masterBehaviourIntensity', values);
   // console.log( Date(Date.now()) + 'BehaviourIntensity: ' + values);
    gaslightdata.behaviourIntensity = values;
    rewriteData(gaslightdata);

}


/////////////////////////////////////
/////     HELPER FUNCTIONS     //////
/////////////////////////////////////


//takes a playback number, boolean value, fade time (miliseconds)
//bool True fades on
//bool False fades off    
async function fadeplayback(playback,bool,time){
    var delayinc = 100 // delay between messages in milliseconds 
    var itr = Math.ceil(time/delayinc);
    for (var i = 0; i<itr+1; i++){
        if (bool){value = i/itr;}
        else{value = 1 - (i/itr);}
        lightOscClient.send(('/cs/playback/' + playback + '/level'), value);
       // await delay(delayinc);  // removing to avoid odd colour cycling -mg
    }
}

function rewriteData(gaslightdata){
    fs.writeFile('gaslightdata.json',JSON.stringify(gaslightdata,null,2),emitUpdate);
}


function emitUpdate(result){
    if (currentSocket != ""){
        socket = currentSocket
    //    console.log( Date(Date.now()) + 'broadcasting')
        socket.broadcast.emit('updateProps',gaslightdata);
        socket.emit('updateProps',gaslightdata);
    }
}

//sleep function
function delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
