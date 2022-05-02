/////////////////////////////
//
// PBAI/LASG
// HexUnit Class
// Created: December 07 2018
// Author(s): Adam Francey
// Description: Subclass of node, manages a HexUnit

class HexUnit extends Node {

  HexUnit(int nid, DeviceLocatorNode dl, String type, String group) {
    super(nid, dl, type, group);
    println("I am a HexUnit with ID: " + nid + " in group " + group);
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
