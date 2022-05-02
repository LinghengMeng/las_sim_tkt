/////////////////////////////
//
// PBAI/LASG
// Sound Sensor Scout Class
// Created: July 17th 2019
// Author(s): Sophia Rahn
// Description: Subclass of node, manages a breathing pore containing the components of a Sound Sensor Scout

class SoundSensorScout extends Node {

  SoundSensorScout(int nid, DeviceLocatorNode dl, String type, String group) {
    super(nid, dl, type, group);
    println("I am a SoundSensorScout with ID: " + nid + " in group " + group);
  }

  void startup() {
    super.startup();
  }

  void run() {
    super.run();
  }

  void go() {
    super.go();
  }
}
