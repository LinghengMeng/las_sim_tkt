/////////////////////////////
//
// PBAI/LASG
// MiniUnit Class
// Created: December 10 2019 for Meander
// Author(s): Adam Francey's descendants MG and FM
// Description: Subclass of node, manages a MiniUnit

class MiniUnit extends Node {

  MiniUnit(int nid, DeviceLocatorNode dl, String type, String group) {
    super(nid, dl, type, group);
    println("I am a MiniUnit with ID: " + nid + " in group " + group);
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
