class Patchable {

  // vars for operation
  transient Object      owner;
  ArrayList<DataPort>   dataPorts;
  String                realName;
  transient boolean     orphan; // this means the Patcher knows about it, but its object doesn't yet exist.
  String                behaviour;  // this is the behaviourName of the associated behaviourEngineVar - outputs don't need one, so just leave blank.
  

  // vars for display
  String                displayName;
  int                   screenX;
  int                   screenY;
  int                   screenW;
  int                   screenH;
  boolean               hidden;  // hide if not part of the current preset
  boolean               killMe;


  Patchable() {

      owner = null;
      behaviour = "";
      dataPorts = new ArrayList<DataPort>();
      orphan = true;
      killMe = false;

  }

  Patchable(Object o) {

      owner = o;
      behaviour = "";
      dataPorts = new ArrayList<DataPort>();
      orphan = false;
      killMe = false;

  }

}



class DataPort {

  final private static int BOOL  = 10;
  final private static int INT   = 20;
  final private static int FLOAT = 30;

  boolean inport = false;  // default to out port
  String param;
  String val;
  float min;
  float max;
  float trigger;
  float newDataPrecision = 0.00001; // detectable change on an outPort
  boolean latching = false;  // set to true if you want booleans to stick true once they pass threshold
  transient int  type = FLOAT;
  transient boolean newDataFlag = true;
  transient float lastRequestedData = 0.0;  // outports check new requests for data against this, and only reply if it is significant.
  transient String lastMappedData = "";   // inports check new requests for data against this, and use newdataflag to say if it is new

  //   constructor for inPorts that want floats:
  DataPort(String _param, String _val, float _min, float _max) {
    inport = true;
    param = _param;
    val = _val;
    min = _min;
    max = _max;

    type = DataPort.FLOAT;

  }

  //   constructor for inPorts that want ints:
  DataPort(String _param, String _val, int _min, int _max) {
    inport = true;
    param = _param;
    val = _val;
    min = _min;
    max = _max;

    type = DataPort.INT;

    newDataFlag = true;
   
  }


  //   constructor for inPorts that want bools:
  DataPort(String _param, String _val, float _trigger) {
    inport = true;
    param = _param;
    val = _val;
    trigger = _trigger;

    type = DataPort.BOOL;

    newDataFlag = true;
   
  }



  //  constructor for outPorts:
  DataPort(String _param) {      

  // connectors = new ArrayList<Connector>();
   inport = false;
   param  = _param;

  }

  // used by inPorts: takes in a float between 0.0 and 1.0 and maps it to a string representation of the desired value.
  String mappedValue(float v) {

    String toSend = "";

    if(type == DataPort.BOOL) {
      toSend = str( v > trigger );
    }

    String newVal = "0";
    float newfloat = map(v, 0.0, 1.0, min, max);

    if(type == DataPort.INT) {
      int newint = int(newfloat);
      toSend = (str(newint));
    } 
    
    if(type == DataPort.FLOAT) {
      toSend = (nf(newfloat, 0, 5));  // cap at 5 points of precision.
    }

    if(toSend.equals(lastMappedData)) {
      toSend = ("no change");
    } else {
      lastMappedData = toSend;
    }

    return(toSend);  
  }

  // used by outPorts:  takes in a float between 0.0 and 1.0 and evaluates if it has changed enough since last check
  // to warrant sending it on -- the acceptable delta precision can be adjusted
  // uses a flag to maintain the same response until the flag is externally reset - this is so that multiple connectors
  // can draw the same data.

  boolean isNewData(float v) {

    if(newDataFlag || abs(lastRequestedData-v) > newDataPrecision) {
      lastRequestedData = v;
      newDataFlag = true;
    }

    return newDataFlag;

  }
}