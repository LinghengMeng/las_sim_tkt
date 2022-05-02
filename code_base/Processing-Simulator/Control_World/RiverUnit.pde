/////////////////////////////
//
// PBAI/LASG
// RiverUnit Class
// Created: July 26 2019
// Author(s): Michael Lancaster
// Description: Subclass of node, manages a River Unit (node that may have MOs, DRs, RSs, or SMs connected)

class RiverUnit extends Node {

  RiverUnit(int nid, DeviceLocatorNode dl, String type, String group) {
    super(nid, dl, type, group);
    println("I am a RiverUnit with ID: " + nid + " in group " + group);
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