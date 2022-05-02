/////////////////////////////
//
// PBAI/LASG
// BreathingPore Class
// Created: December 07 2018
// Author(s): Adam Francey
// Description: Subclass of node, manages a HexUnit

class BreathingPore extends Node {

  BreathingPore(int nid, DeviceLocatorNode dl, String type, String group) {
    super(nid, dl, type, group);
    println("I am a BreathingPore with ID: " + nid + " in group " + group);
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
