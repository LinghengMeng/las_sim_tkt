/*

OSC out port: 9001

*/



/*
Calls all continuous Osc Outs, for ongoing data like sensor values
*/
public void outputAllContinuousOsc() {
  //  oscOut_omniMasterVolume();
    oscOut_soundDetectorLevels();
    oscOut_gridEyePresences();
    oscOut_gridEyeVectors();
    oscOut_MFLdashboardExcitorBrightnessMaster();
    oscOut_MFLdashboardElectricCellsBrightnessMaster();
    oscOut_MFLdashboardPresenceSensitivityMaster();
    oscOut_MFLdashboardSdSensitivityMaster();
    oscOut_DemoExtLightAndSound();
}


//////////// List of continuous OSC out funtions, called in 'outputAllContinuousOsc()' on top if this file

public void oscOut_soundDetectorLevels() {
    OscMessage oscMsg = new OscMessage("/soundDetectorLevels");
    oscMsg.add(soundDetectorLevels);
    external_osc.send(oscMsg, myRemoteLocation);
}

public void oscOut_gridEyePresences() {
    OscMessage oscMsg = new OscMessage("/gridEyePresences");
    oscMsg.add(gridEyePresences);
    external_osc.send(oscMsg, myRemoteLocation);
}

public void oscOut_gridEyeVectors() {
    OscMessage oscMsg = new OscMessage("/gridEyeVectors");
    
    /*
    Convert PVectors to FLoats
    */
    float[] gridEyeVectorsFloats = new float[gridEyeVectors.length*2];
    for (int i=0; i<gridEyeVectors.length; i++) {
        gridEyeVectorsFloats[i*2] = gridEyeVectors[i].x;
        gridEyeVectorsFloats[i*2+1] = gridEyeVectors[i].y;
    }

    oscMsg.add(gridEyeVectorsFloats);
    external_osc.send(oscMsg, myRemoteLocation);
}



//////////// List of to specifically call OSC out functions

public void oscOut_omniMasterVolume() {
if (excitorBehaviour.omniMasterVolume!=excitorBehaviour.prevOmniMasterVolume) { // TODO: this if statement should not be necessary
    OscMessage oscMsg = new OscMessage("/soundMasterVolume");
    oscMsg.add(excitorBehaviour.omniMasterVolume);
    external_osc.send(oscMsg, myRemoteLocation);  // need to hook this to new vol/mute capability for Meander
    excitorBehaviour.prevOmniMasterVolume = excitorBehaviour.omniMasterVolume;
  }
}

public void newExcitorSpawned() {
    OscMessage oscMsg = new OscMessage("/newExcitorSpawned");
    oscMsg.add(1);
    external_osc.send(oscMsg, myRemoteLocation);
}

public void requestAllValuesFromAbleton() {
    OscMessage oscMsg = new OscMessage("/requestAllValues");
    oscMsg.add(1);
    external_osc.send(oscMsg, myRemoteLocation);
    println("Requesting Values from Ableton");
}


/*
    TODO
*/

public void oscOut_MFLdashboardExcitorBrightnessMaster() {
    OscMessage oscMsg = new OscMessage("/excitorBrightnessMaster");
    //oscMsg.add(VALUE_X);
    //external_osc.send(oscMsg, myRemoteLocation);
}

public void oscOut_MFLdashboardElectricCellsBrightnessMaster() {
    OscMessage oscMsg = new OscMessage("/electricCellsBrightnessMaster");
    //oscMsg.add(VALUE_X);
    //external_osc.send(oscMsg, myRemoteLocation);
}

public void oscOut_MFLdashboardPresenceSensitivityMaster() {
    if (excitorBehaviour.presenceSensitivity!=excitorBehaviour.prevPresenceSensitivity) { // this if statement limits the OSC messages and makes it so that the LIVE controls work as well.
      OscMessage oscMsg = new OscMessage("/sensorSensitivityMaster");
      oscMsg.add(excitorBehaviour.presenceSensitivity);
      external_osc.send(oscMsg, myRemoteLocation);
      excitorBehaviour.prevPresenceSensitivity = excitorBehaviour.presenceSensitivity;
    }
}

public void oscOut_MFLdashboardSdSensitivityMaster() {
    if (excitorBehaviour.sdSensitivity!=excitorBehaviour.prevSdSensitivity) { // this if statement limits the OSC messages and makes it so that the LIVE controls work as well.
      OscMessage oscMsg = new OscMessage("/soundSensitivityMaster");
      oscMsg.add(excitorBehaviour.sdSensitivity);
      external_osc.send(oscMsg, myRemoteLocation);
      excitorBehaviour.prevSdSensitivity = excitorBehaviour.sdSensitivity;
    }
}

public void oscOut_DemoExtLightAndSound() {
    if (triggerDemoMessage) {
      println("Triggering light and sound demo from IR");        

      // Light
      OscMessage oscMsg = new OscMessage("/triggerLightDemo");
      external_osc.send(oscMsg, lightingControlLocation);      

      // Sound
      oscMsg =  new OscMessage("/triggerSoundDemo");
      external_osc.send(oscMsg, soundControlLocation); 

      triggerDemoMessage = false;
    }
    
    
}