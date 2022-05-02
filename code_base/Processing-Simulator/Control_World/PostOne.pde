/////////////////////////////
//
// PBAI/LASG
// PostOne Class
// Created: December 12 2019 for Meander
// Author(s): Adam Francey's descendants MG and FM
// Description: Subclass of node, manages a MiniUnit

class PostOne extends Node {

  PostOne(int nid, DeviceLocatorNode dl, String type, String group) {
    super(nid, dl, type, group);
    println("I am a PostOne with ID: " + nid + " in group " + group);
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
