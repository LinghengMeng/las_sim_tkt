/////////////////////////////
//
// PBAI/LASG
// SSSUnit Class
// Created: July 25 2019
// Author(s): Michael Lancaster
// Description: Subclass of node, manages a Sound Sensor Scout (SSS)

class SSSUnit extends Node {

  SSSUnit(int nid, DeviceLocatorNode dl, String type, String group) {
    super(nid, dl, type, group);
    println("I am a SSSUnit with ID: " + nid + " in group " + group);
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