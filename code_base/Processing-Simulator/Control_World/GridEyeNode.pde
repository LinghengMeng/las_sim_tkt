class GridEyeNode extends Node
{
  GridEyeNode(int nid, DeviceLocatorNode dl, String type, String group) {
    super(nid, dl, type, group);
    println("I am a GridEyeNode with ID: " + nid + " in group " + group);
  }

  void startup() {
    super.startup();
  }

  void run() {
    // perhaps override this 
    super.run();
  }

  void go() {
    super.go();
  }
}
