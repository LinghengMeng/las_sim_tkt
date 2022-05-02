/*!  //<>// //<>// //<>// //<>//
 <h1> Control_World </h1>
 Setup class that runs the main loop for the control laptop
 
 \author Matt Gorbet, et al....
 
 */


import peasy.*;
import controlP5.*;
import java.io.*;
import java.lang.reflect.*;
import java.util.LinkedHashMap;
import java.util.Map;
import processing.serial.*;
import oscP5.*;
import netP5.*;
import toxi.geom.*;
import com.google.gson.*;


OscP5 internal_comms;
OscP5 external_osc;
OscP5 lighting_osc;

NetAddress myRemoteLocation;  //  set this properly to the control IP  ??
NetAddress maxOSCAddress;
NetAddress guiServerLocation; //  set this properly to the control IP  ??
NetAddress lightingControlLocation; 
NetAddress soundControlLocation;


PeasyCam cam;
CameraState[] views;
PShape   fsphere;
PShape   meander;

/*!
 *  Realtime storage for sensor values
 */
float[]   soundDetectorLevels; 
float[]   irDetectorLevels;
float[]   gridEyePresences; 
float     cur_max_grideye_presence;
float     cur_max_sd;
float     cur_max_ir;
PVector[] gridEyeVectors;

float masterBehaviourIntensity = 1.0;  // trying to use this last-minute on meander launch
float lastMasterBehaviourIntensity = 1.0;  // remember this.

// variables made for external sound and light integration demo
float triggerThreshold = 0.8;
int irDemoWaitTime = 60000;
int soundAndLightDemo_lastTriggerTime = 0;
boolean triggerDemoMessage = false;

int      behaviour_save_frequency = 8000;

int[]    nodeWTids = {0, 0, 0, 0, 0};

VisGui   gui;
Actuator over_actuator;
Actuator selected_actuator;
int      selected_node;
boolean  all_actuators_selected = false;
boolean  all_sensors_selected = false;


Gson     gson;

Sensor   over_sensor;
Sensor   selected_sensor;
String   isolated_group = "";

boolean  drs_offset_snapped = true;

static int ALL_NODES_SELECTED = 9999;
static int NO_NODES_SELECTED  = 0;



// OSC flags:
boolean osc_sleep_pushed = false;
boolean osc_wake_pushed = false;
String  osc_new_scene = "default";
String  current_scene = "none";    // <-- this will force a load of 'default', becauseosc_new_scene is different from "current";


/*!
 *  Used to select LIVE or SIM -- overridden by options.json if present
 */
boolean run_mode = LIVE;

/*!
 * used to enable reception of real messages while in sim mode
 */
boolean sync_unity_sensor_reading = false;

/*!
 *  Used to turn log on or off. NOTE: Also solves the unusual console overflow error. Turn to true if experiencing that problem.
 */
boolean use_log  = false;

/*!
 *  Used to set the framerate of the sketch
 */
// int framerate = 60;
int framerate = 60;

/*!
 *  set to true if anything inside the code is hacked
 */
boolean hacked = false;

/*!
 *  Prints out the hack that you have implemented so people can see it when they compile
 */
String hacked_description = "...";

/*!
 *  Basepath of the file folder where the WAV Trigger files are stored so the simulation can also play them. Will change from computer to computer.
 */
String base_path = "~/Documents/Processing-Simulator"; // this changes per device

/*!
 *  generate alerts -- flag to tell Monitor class whether to actually trigger GitHub 'Issues', resulting in alerts
 */
 boolean generate_alerts = false;

/*!
 *  split dot h file -- flag create multiple .h files - one per Node type - to save space on Teensies -mg Nov 26 2019
 */
 boolean split_dot_h_file = false;

/*!
 *  used to enable excitors
 */
boolean run_excitorBehaviour = true;

/*!
 *  used to enable flowfield
 */
boolean run_flowField = true;

/*!
 * used to show/hide flowfield elements
 */
boolean show_flowField = true;

/*!
 *  used to enable electric cells
 */
boolean run_electricCells = true;

/*!
 *  used prevent messages from being sent out. Only use in special debugging cases. If you want to just run the simulation, switch the SIM or LIVE variable, not this.
 */
boolean stop_messaging = false;

/*!
 *  use a key (tab) to run a test of the actuators you are hovering over.  (uses actuator_test_distance to define which are being tested) 
 */
boolean test_current_actuator = false;
int      actuator_test_distance = 80;  // diameter of TAB test circle in screen pixels
String   actuator_test_type = "ALL";
Set<Actuator>       actuators_to_test;
Set<FlowVector>     vectors_to_adjust;
boolean  paintbrush_osc = false;    // flag for whether to 'test' the actuators described by OSC paintbrush messages
PVector  paintbrush_osc_params;     // vector storing 3 incoming paintbrush params: x, y, and diameter as 0.0-1.0 floats.
PVector  paintbrush_osc_offsets;    // vector encoding x offset, y offset, and scale to use to map to real-world coordinates.

/*!
 *  make actuators face the camera irrespective of position
 */
int billboard_mode = 1 ;   // actuators always face camera, or center of sphere?

/*!
 *  Grideye analyzer object
 */
GridEye_Analyzer ge;

/*!
 *  whether or not to use simulated grideye data
 */
boolean gesim = false;

/*!
 *  MATT - TODO (add something for each :) )
 */
boolean firstpick_scene = true;
boolean firstpick_ge  = true;
boolean firstpick_inf = true;
//int     frameskip = 3;
//float   interestThreshold = 1000.0;
//float   noiseThreshold = 0.3;
//float   overall_relax = 0.8;
boolean prerecorded = false;                                 // don't set it here - use the GUI



/*!
 *  default setting, csv is now changed in options.json in the root directory
 */
String file_name = "default"; // set in options.json now
String csv_select = "../Device_Locator_CSVs/" + file_name + ".csv";
String override_control_ip = "";
String las_unity_simulator_ip = "127.0.0.1";
boolean output_raw_osc = false;     // outputs a raw OSC message of format [<int> <float> ...] for each pin
String las_ai_agent_ip = "127.0.0.1"; 
int las_ai_agent_port = 4010;


/*!
 *  Run full screen or in a window?
 */
 boolean fill_screen = true;

/*!
 *  MATT - TODO (add something for each :) )
 */
float[] cam_targ = {0.0, 0.0, 0.0};
PVector centerpoint;
int grid_extent = 12000;
int grid_spacing = 100;
int floor_height = 5000;
int model_offset_X = 300;
int model_offset_Y = 0;
int model_offset_Z = -800;
float model_rot_X = -0.08726647;
float model_rot_Y = -0.34906584;
float model_rot_Z = 0.0;

PFont gill;
int textheight = 18;
int textoffset = 35;
int frame = 0;
int geframe = 0;
int scale = 10;

int canvasw = 400;
int canvash = 400;
int canvas_xo = 0;
int canvas_yo = 0;

boolean mute_messages = false;
boolean drawgui = true;
int     drawmodel = 0;
boolean drawaxes = true;
boolean draw_bounding_boxes = false;
boolean keyshift = false;
boolean keyalt   = false;
boolean wasMouseOverGui = false;
boolean select_item = false;

int mouse_millis = 0;

boolean show_control_panel_on_startup = false;

boolean show_control_running     = true;
boolean show_control_awake       = true;
boolean show_control_muted       = false;

boolean sleepmode = false;

boolean simulate_crash = false;

float   show_control_vol_omni     = 84;     // to send master volume for OMNIs we will simply change the omni_master_volume float in the excitor class
float   show_control_vol_wt       = 70;
boolean show_control_use_timer    = true;
int     show_control_start_hour   = 6;
int     show_control_start_minute = 0;
int     show_control_stop_hour    = 21;
int     show_control_stop_minute  = 0;
float   show_control_presence_sensitivity = 90;
float   show_control_sd_sensitivity = 90;

int default_wt_gain = int(0.75*80);
int cur_wt_master_gain = int(0);



PrintStream      ps;             // used to redirect the standard output (global variable)

/*!
 *  \var dl
 *  the device locator instance
 */
public DeviceLocator dl;

/*!
 *  \var setup_ports
 *  The serial ports, sent to Comm_manager from the World builder
 */
public Serial[] setup_ports = new Serial[Serial.list().length];

/*!
 *  \var network
 *  Comm Manager instance for intersculptural communication
 */
public Comm_Manager network;

/*! \var monitor
 *  monitor class for Control - deals with pings and heartbeats
  */
public Monitor monitor;

/*!
 *  \var external_comms
 *  External Comm Manager instance for external communication
 */
public External_Comms external_comms;

/*!
 *  \var control
 *  Control object
 */
public Control control;

/*!
 *  \var cur_influence
 *  Name of the influence type currently being set (for influence maps)
 */
String cur_influence = "";


/*!
 *  \var actuatorTypes
 *  TODO
 */
ArrayList<String> actuatorTypes;

/*!
 *  \var actuatorLocations
 *  TODO
 */
ArrayList<PVector> actuatorLocations;

/*!
 *  \var numActuators
 *  TODO
 */
int numActuators;

/*!
 *  \var behaviours
 */


HashMap<String, Object> behaviourEngineSettings;  // holds the behaviourengine instance, keyed by name of behaviour
HashMap<String, Object> childBehaviourSettings;  // holds 'minor' sub-behaviours, like waves or particle sources that don't get explicitly saved - they are saved by their parent behaviour

PatcherVars patcherVars;
Patcher     patcher;

ExcBehavVars excBehavVars;
ExcitorBehaviour excitorBehaviour;
FlowFieldVars flowFieldVars;         // legacy but keep for now-  set to 'neversave'
RiverHeadVars riverHeadVars;         // legacy but keep for now-  set to 'neversave'
//RiverHeadSystem northRiverHead;
//RiverHeadSystem southRiverHead;
//FlowField flowField_NR;
//FlowField flowField_SR;
ElectricCellVars electricCellVars;
ElectricCellSystem electricCellSystem;
AmbientWavesVars ambientWavesVars;
AmbientWaves ambientWaves;
GridRunnerVars gridRunnerVars;
GridRunner gridRunner;

//  DEMO variables for integrating any other behaviour - these aren't used, but this is where you'll put yours.
SampleBehaviourVars sampleBehaviourVars;
SampleBehaviour     sampleBehaviour;

LightingBehaviourVars lightingBehaviourVars;
//LightingBehaviour lightingBehaviour;


/*! Store all the SAIs in the sculpture, indexed by the name of their actuator */
HashMap<String, SAI>  all_sais = new HashMap<String, SAI>();



/*!
 *  \var timelapse stuff
 */

boolean time_lapse = false;
boolean time_lapse_changed = false;  // flag that time-lapse functions just changed
float time_lapse_speed = 100.0;   // percentage of 'realtime'
int time_lapse_pause = 0;         // how long to pause between 'frames'
int max_time_lapse_pause = 4000;  // max pause between 'frames' = ~100x slower

boolean ir_trigger_sounds = false;

PVector mouse_down;



/*!
 *  \fn setup()
 *  \brief setup function that initializes the sketch. Loads json configurations, communication ports and kicks off threads
 *  \return none
 */
void setup() {
  JSONObject json = null;
  // fullScreen(P3D);

   size(1200, 800, P3D);
  //size(1500, 1000, P3D);
  surface.setTitle("LAS Processing-Simulator!");

/* JSON format for options.json (don't override control_ip if live and deployed):

{
    "file_name":"Meander_FULL_JAN22",
    "run_mode":"SIM",
    "override_control_ip":"127.0.0.1",
    "las_unity_simulator_ip":"127.0.0.1",
    "split_dot_h_file":"true",
    "generate_alerts":"false"
}

*/ 
 
  // Google class for making and reading GSON -- used to save and load state of behaviours.
  //  gson = new GsonBuilder().setPrettyPrinting().excludeFieldsWithoutExposeAnnotation().create(); // do we want to tag all things with @expose?  Trying 'transient' keyword for now.
  gson = new GsonBuilder().setPrettyPrinting().create();

   try {
      json = loadJSONObject("../options.json");
   } catch(Exception e) {

    println("Exception loading OPTIONS: " + e);

   }
  if (json.getString("file_name") != null)
    file_name = json.getString("file_name");

  //override .csv control IP, if present in options.json
  if (json.getString("override_control_ip") != null) {
    println("OVERRIDING control_ip WITH " + json.getString("override_control_ip"));
    override_control_ip = json.getString("override_control_ip"); 
    }
  //set unity IP, if present in options.json
  if (json.getString("las_unity_simulator_ip") != null) {
    println("Setting Raw OSC IP to " + json.getString("las_unity_simulator_ip"));
    las_unity_simulator_ip = json.getString("las_unity_simulator_ip"); 
    }
  // synchronize unity sensor reading with Processing-Simulator
  if (json.getString("sync_unity_sensor_reading") != null){
    sync_unity_sensor_reading = (json.getString("sync_unity_sensor_reading").equals("true"));
  }
  //set LAS-AI-Agent IP, if present in options.json
  if (json.getString("las_ai_agent_ip") != null) {
    println("Setting LAS-AI-Agent IP to " + json.getString("las_ai_agent_ip"));
    las_ai_agent_ip = json.getString("las_ai_agent_ip"); 
  }
  //set LAS-AI-Agent IP, if present in options.json
  if (json.getString("las_ai_agent_port") != null) {
    println("Setting LAS-AI-Agent Port to " + json.getString("las_ai_agent_port"));
    las_ai_agent_port = Integer.parseInt(json.getString("las_ai_agent_port"));
  }
  //override hardcoded LIVE or SIM
  if (json.getString("run_mode") != null) {
    println("OVERRIDING run_mode WITH " + json.getString("run_mode"));
    run_mode = (json.getString("run_mode").equals("LIVE"));
  }
  // generate single or separate .h files?
  if(json.getString("split_dot_h_file") != null ){
    split_dot_h_file = (json.getString("split_dot_h_file").equals("true"));
  }
  if (json.getString("generate_alerts") != null ){
    generate_alerts = (json.getString("generate_alerts").equals("true"));
  }
  if (json.getString("output_raw_osc") != null ){
    output_raw_osc = (json.getString("output_raw_osc").equals("true"));
  }
  if (json.getString("ir_trigger_sounds") != null ){
    ir_trigger_sounds = (json.getString("ir_trigger_sounds").equals("true"));
  }
  

  csv_select = "../Device_Locator_CSVs/" + file_name + ".csv";

  paintbrush_osc_params = new PVector(0,0,0);
  paintbrush_osc_offsets = new PVector(-9488, -9696 * 1.337, 16000); // 16000 is the x scale. y is 1.337x that (aspect ratio of image)

  rectMode(CENTER);       // for consistency
  ellipseMode(CENTER);    // for consistency

  /*! NOTE: Processing runs its draw function as fast as the framerate. E.g. 1000fps has 1ms per loop of draw. (max is 1000fps) */
  //frameRate(framerate);

  // REDIRECT CONSOLE OUTPUT

  if (use_log) {
    //re-direct standard output to a logfile

    try {
      redirectStdOut("Control_World_Logfile.txt");
    }
    catch(Exception e) {

      println("exception: " + e);
    }
  }

  // load meander model
  println("loading model... ");
//  meander = loadShape("Meander.obj");
 // meander = loadShape("meander_building.obj");
  meander = loadShape("meander_building.obj");
  // align imported Meander model with world coordinates
  meander.scale(-610, -610, -610);
  meander.translate(000, 000, 000);

  // load sphere model
//  fsphere = loadShape("Futurium.obj");
  // align imported sphere model with world coordinates
//  fsphere.scale(1, -1, 1);
//  fsphere.translate(-87880, 2640, -4420);


  // load font

  gill = loadFont("GillSans-48.vlw");
  textFont(gill, textheight);

  
  behaviourEngineSettings = new HashMap<String, Object>();  // using generic objects because they will all be different
  childBehaviourSettings = new HashMap<String, Object>();  // using generic objects because they will all be different

  // main classes

  patcherVars = new PatcherVars();
  patcher = new Patcher();   // thread that manages sensors and patching, via web-based interface

  gui = new VisGui(this);
  dl = new DeviceLocator(csv_select);
  ge = new GridEye_Analyzer(this);
  network = new Comm_Manager(run_mode, dl);
  external_comms = new External_Comms(network.my_address);
  guiServerLocation = new NetAddress("127.0.0.1", 3006); 
  monitor = new Monitor();

  // CLEAN THESE UP - what is being used and how is it set?

  myRemoteLocation = new NetAddress("127.0.0.1", 9001);      //send to Ableton / Max -- old, still used??
  maxOSCAddress    = new NetAddress("127.0.0.1", 6666);   /// MAX

  // setup for external light and sound integration demo
  lightingControlLocation = new NetAddress("172.23.1.99", 3006);
  soundControlLocation = new NetAddress("172.23.1.99", 3006);

  network.control_build_virtual_map(this);
  centerpoint = dl.get_all_actuator_centerpoint();
  String settings_prefix = new String("data/" + file_name );


  // create directory for saving settings:
  File f = new File(settings_prefix);
  f.mkdir();

  soundDetectorLevels = new   float[num_SD];  //  dl.get_node_type_ids("SD").size()]; // need a call to count the num SDs.  
  irDetectorLevels    = new   float[num_IR];
  gridEyePresences    = new   float[dl.get_node_type_ids("GN").size()]; //Updates in RT
  gridEyeVectors      = new PVector[dl.get_node_type_ids("GN").size()]; //Updates in RT

  for (int i=0; i<gridEyeVectors.length; i++) {
    gridEyeVectors[i] = new PVector(0,0,0);
  }
  
  actuators_to_test = Collections.synchronizedSet(new LinkedHashSet());   
  vectors_to_adjust = Collections.synchronizedSet(new LinkedHashSet());

  gui.init(settings_prefix);
  

  delay(500);
  //cam = new PeasyCam(this, gui.cam_lookat_x.getValue(), gui.cam_lookat_y.getValue(), gui.cam_lookat_z.getValue(), gui.cam_distance.getValue());
  cam = new PeasyCam(this, gui.cam_lookat_x.getValue(),gui.cam_lookat_y.getValue(),gui.cam_lookat_z.getValue(), gui.cam_distance.getValue());
  cam.setRotations(gui.cam_rot_x.getValue(), gui.cam_rot_y.getValue(), gui.cam_rot_z.getValue());
  cam.setResetOnDoubleClick(false);
  cam.setYawRotationMode();
  cam.setSuppressRollRotationMode();

  views = new CameraState[10];
  for (int i = 0; i < 10; i++) {
    views[i] = cam.getState();      // save all views as the origin to start.
  }


  println("GOING TO TRY TO LOAD SAVED CAMERA VIEWS FROM:  /data/" + file_name + "/view_settings.json");

  try {
  FileReader fr = new FileReader(sketchPath() + "/data/" + file_name + "/view_settings.json");
  JsonReader jr = new JsonReader(fr);
  views = gson.fromJson(jr, CameraState[].class);
  jr.close(); fr.close();
  } catch(Exception e) {
    println(" Exception reading views: " +e );
  }



  //Threads
  control = new Control();
  control.start();

  // PIs --------

  for (Map.Entry<String, RPi> entry : dl.get_RPis().entrySet()) {
    String id = entry.getKey();
    RPi current_rpi = entry.getValue();
    current_rpi.start();
  }

  // NODES --------


  for (Map.Entry<Integer, Node> entry : dl.get_nodes().entrySet()) {
    Integer id = entry.getKey();
    Node current_node = entry.getValue();
    current_node.start();
  }



  actuatorTypes = dl.get_all_actuator_types();
  actuatorLocations = dl.get_all_actuator_coordinates();   // all actuator locations, in order: MO, RS, DR, SM, WT
  numActuators = actuatorLocations.size();




  // CREATE BEHAVIOURS
  excBehavVars = new ExcBehavVars();
  flowFieldVars = new FlowFieldVars();        // legacy for now
  riverHeadVars = new RiverHeadVars();        // legacy for now
  electricCellVars = new ElectricCellVars();
  ambientWavesVars = new AmbientWavesVars();
  gridRunnerVars = new GridRunnerVars();

  ///  register sample behaviour here:
  sampleBehaviourVars = new SampleBehaviourVars();  
  //lightingBehaviourVars = new LightingBehaviourVars();


  for(HashMap.Entry<String, Object> beh : behaviourEngineSettings.entrySet()) {
     ((BehaviourEngineVars)beh.getValue()).load();
  }

  excitorBehaviour = new ExcitorBehaviour();
  electricCellSystem = new ElectricCellSystem();
//  southRiverHead = new RiverHeadSystem("S", 12, new Vec3D(-3620.83, -1881.04, 2590.26));
//  northRiverHead = new RiverHeadSystem("N", 12, new Vec3D(1875.24,  -3922.10, 1941.97));
//  flowField_NR = new FlowField(dl, "NR");
//  flowField_SR = new FlowField(dl, "SR");
  gridRunner = new GridRunner();
  ambientWaves = new AmbientWaves();  // happens after init of vars now.

  // create your SampleBehaviour here:
  sampleBehaviour = new SampleBehaviour();
  //lightingBehaviour = new LightingBehaviour();


  // this will get trigggered automatically because we set "osc_new_scene" to "default" will change on first run.
  //  load_scene();   // this will load all new values into behaviour engines (if exist) as well as actuator subscriptions
  
  int wt = 0;


  mouse_millis = millis();
  mouse_down = new PVector(0,0,0);

  // set camera parameters

  float fov = PI/2.5;
  float cameraZ = (height/2.0) / tan(fov/2.0);
  perspective(fov, float(width)/float(height), cameraZ/100.0, cameraZ*1000.0);

  cam.setWheelScale(0.1);

  set_wt_master_gain(default_wt_gain);




  for (Node node : dl.nodes.values())
      {
        for (int i = 0; i < Node.WT_ARR_SIZE; i++)
        {
          if (node.my_wav_triggers[i].installed)
          {
           nodeWTids[wt] = node.node_id;
           println("Wave Trigger Node " + wt + ": " + node.node_id);
           wt++;
           if(wt > 4) wt = 4;
          }
        }
      }



 // request sync from Ableton (not sure if it will be up yet)
 //  requestAllValuesFromAbleton();
 // start patcher thread;
  patcher.start();
 // start behaviour threads:
  ambientWaves.start();
//  northRiverHead.start();
//  southRiverHead.start();
//  flowField_NR.start();
//  flowField_SR.start();
  excitorBehaviour.start();
  electricCellSystem.start();
  gridRunner.start();

  // start your SampleBehaviour here:
  //sampleBehaviour.start();
  //lightingBehaviour.start();

  println("\n\n");
  println("=============  MAIN SETUP COMPLETE  ==================");
  println("\n\n");
  /*****
  println("MAKE SURE TO DOUBLE CHECK CSV IS UPDATED AND CORRECT");
  println("PLEASE MAKE SURE TO TAG THE HACKED FIELD TO TRUE IF YOu HAVE HACKED ANY PART OF THIS BRANCH");
  println("Hacked? " + hacked);
  if (hacked)
    println("Description of hack: " + hacked_description);
  println("Framerate: " + framerate);
  println("CSV: " + csv_select);
  println("Cam Settings: " + settings_prefix + "_cam_settings");
  println("Show Control Settings: " + settings_prefix + "_show_control_settings");
  println("Running Excitors? " + run_excitorBehaviour);
  println("Stop messages? " + stop_messaging);
  println("Num Actuator Slots defined: " + numActuators);
  println("using Wifi? " + network.use_wifi);
  println("Filepath being used: " + base_path);
  println("\n\n\n");
  *****/



  /*! NOTE: Processing runs its draw function as fast as the framerate. E.g. 1000fps has 1ms per loop of draw. (max is 1000fps) */
  frameRate(float(json.getString("framerate")));
  /////  temp testing
}

/*!
 *  \fn redirectStdOut(String filename)
 *  \brief writes to a file
 *  \exception IOException
 *  \param filename the name of the file to write to
 *  \return none
 */
void redirectStdOut(String filename) throws IOException {
  FileOutputStream fos =
    new FileOutputStream(filename, true);
  BufferedOutputStream bos =
    new BufferedOutputStream(fos, 1024);
  ps =
    new PrintStream(bos, false);

  System.setOut(ps);
}


/*!
 *  \fn draw()
 *  \brief main drawing loop
 *  \return none
 */
void draw() {


  // for testing -- to simulate a crash
  while(simulate_crash) {};


  // MANAGE INPUT FROM OSC FLAGS
  if(osc_sleep_pushed) {
     osc_sleep_pushed = false;
    // check the state  
     if(show_control_awake == false) return;  // do nothing - already asleep.
    // hack (?) -- tell the gui I pressed the 'sleep/wake' button.
    //gui.show_control_sleep.update();

      show_control_awake = false;
      control.go_to_sleep();
    
  }

  if(osc_wake_pushed) {
     osc_wake_pushed = false;
    // check the state  
     if(show_control_awake == true) return;  // do nothing - already asleep.
    // hack (?) -- tell the gui I pressed the 'sleep/wake' button.
    // gui.show_control_sleep.update();


      show_control_awake = true;
      control.wake_up();

  }

  if(!osc_new_scene.equals(current_scene)) {

    println(" *** Scene switch because OSC_new_scene " + osc_new_scene + " is different from current scene " + current_scene);

    pick_scene_from_picker(osc_new_scene);
    osc_new_scene = current_scene;  // be sure it is set back to current scene (if it failed it might not be) to avoid infinite calls

  }




  increment_frame();
//  background(65, 65, 95);
  background(67, 60, 53);

  draw_axes();
  draw_grid();
  draw_model();



  /*! shows the grideye presence graph */
  
  // gui.presenceChart.setData("queue_values", new float[100]);
  gui.presenceChart.setCaptionLabel("*** Max Presence: " + nf(cur_max_grideye_presence,0,2) + "  Sens: " + nf(show_control_presence_sensitivity,0,2) + " Ma: " + nf(control.moth_attenuation,0,2) + " ***");
  gui.maxSdChart.setCaptionLabel("*** Max Sound: " + nf(cur_max_sd,0,2) + "  Sensitivity: " + nf(show_control_sd_sensitivity,0,2) + " ***");
  
  if(frame % 5 == 0) {

    gui.presenceChart.setColors("presence_values", color(150, 150, 255));
    gui.maxSdChart.setColors("max_sound_values", color(150, 150, 255));
    
    if(cur_max_grideye_presence >= 1.01-show_control_presence_sensitivity) {
      gui.presenceChart.setColors("presence_values", color(255, 150, 150));
    } 
    
    if(cur_max_sd >= 1.01-show_control_sd_sensitivity) {
      gui.maxSdChart.setColors("max_sound_values", color(255, 150, 150));
    } 

    gui.presenceChart.push("presence_values", (cur_max_grideye_presence / (1.01-show_control_presence_sensitivity)));
    gui.maxSdChart.push("max_sound_values", (cur_max_sd / (1.01-show_control_sd_sensitivity)));
  }
  // message_count_this_frame = 0;



  // PIs EXECUTE --------  // for drawing to the screen


  for (Map.Entry<String, RPi> entry : dl.get_RPis().entrySet()) {
    String id = entry.getKey();
    RPi current_rpi = entry.getValue();

    current_rpi.go();

  }

  // NODES EXECUTE --------  // for drawing to the screen

  over_sensor = null;    // will be set by nodes if any are being overed over
  over_actuator = null;  // will be set by nodes if any are being hovered over
  

  for (Map.Entry<Integer, Node> entry : dl.get_nodes().entrySet()) {
    Integer id = entry.getKey();
    Node current_node = entry.getValue();

      current_node.go();

  }


  // GUI functions
  do_gui();


  // timelapse:
  if(time_lapse) {

    if(time_lapse_speed == 0.0) time_lapse_speed = 0.001;
    time_lapse_pause = int((100.0 - time_lapse_speed) * max_time_lapse_pause/100.0);

  } else {
    time_lapse_pause = 0;
    
  }
  
  hint(DISABLE_DEPTH_TEST);    // to show sprites without weird alpha layering issues.
    excitorBehaviour.display();
    gridRunner.display();
  hint(ENABLE_DEPTH_TEST);
//    northRiverHead.display();
//    southRiverHead.display();
//    flowField_NR.display();
//    flowField_SR.display();
    electricCellSystem.display();
    ambientWaves.display();

  // display your sampleBehaviour here, if used
  sampleBehaviour.display();
  //lightingBehaviour.display();

  ////// manage saving of the behavoiurs.
  try {
  for(HashMap.Entry<String, Object> beh : behaviourEngineSettings.entrySet()) {
     BehaviourEngineVars b = (BehaviourEngineVars)beh.getValue();

     // first, if it doesn't already need to save, special check for behaviours that have children that might need to save.
     if (b.behaviourName.equals("GridRunner"  ) && !b.needToSave) b.needToSave = set_ps_needtosave(b, true);
     if (b.behaviourName.equals("AmbientWaves") && !b.needToSave) b.needToSave = set_wv_needtosave(b, true);

     if(b.needToSave && !b.neverSave) {  // neversave should no longer be used here - moving those to childbehavioursettings hashmap to avoid concurrentmod
       if(millis() - b.last_behaviour_save > behaviour_save_frequency) {
         b.save("current");
         b.needToSave = false;
         if (b.behaviourName.equals("GridRunner"))   set_ps_needtosave(b, false);      // now set all children to false
         if (b.behaviourName.equals("AmbientWaves")) set_wv_needtosave(b, false);      // now set all children to false
         b.last_behaviour_save = millis();
       } else {
          cam.beginHUD();
          stroke(255, 100);
          fill(100, 100, 255, 50);
          ellipse(width-10, 10, 10, 10);
          cam.endHUD();
       }
     }
  }
  } catch(ConcurrentModificationException x) {
    println(" Checking and saving behaviours: " + x);
  }

  outputAllContinuousOsc();
  println("FrameRate=", frameRate);
}

//// end of main loop.

boolean set_ps_needtosave(BehaviourEngineVars b, boolean s) {

        for(ParticleSourceVars ps : ((GridRunnerVars)b).particleSourceVars) {
          if(ps.needToSave) { // checking these and return if so
            if(s == true) {              
              println(" a ps needs to save");
              return(true);
            } else {
              ps.needToSave = false;
            }
          }
        }
        return false;  // we checked (or set), and no children need to save now.

}


boolean set_wv_needtosave(BehaviourEngineVars b, boolean s) {

        for(WaveFront wv : ((AmbientWavesVars)b).waves) {
          if(wv.needToSave) { // checking these and return if so
            if(s == true) {              
              println(" a wv needs to save");
              return(true);
            } else {
              wv.needToSave = false;
            }
          }
        }
        return false;  // we checked (or set), and no children need to save now.

}


/*!
 *  \fn views(int n) 
 *  \brief MATT - TODO
 *  \param n
 *  \return none
 */
void views(int n) {

  if (keyshift) {  // set the cam view
    views[n] = cam.getState();
    println("Saved cam state into slot " + char('A' + gui.get_current_nav_button()));
    save_view_settings();  // autosave to disk.
  } else {
    if (views[n] != null) {
      cam.setState(views[n]);
      float fov = PI/2.5;
      perspective(fov, float(width)/float(height), (float)cam.getDistance()/100.0, (float)cam.getDistance()*1000.0);   // Hack to fix clipping hwen changing screens
    } else {
      println("view " + n + " not initialized  yet...");
    }
  }
}


/*!
 *  \fn do_gui()
 *  \brief MATT - TODO
 *  \return none
 */
void do_gui() {

  // reset textoffsets and rollovers
  // current_mouseovers.clear();
  textoffset = 35;

  // cp5 GUI elements handled by different thread

  if (drawgui) {
    hint(DISABLE_DEPTH_TEST);
    cam.beginHUD();

    

    if(test_current_actuator) {
      stroke(255, 100);
      if(actuator_test_type.equals("VECTORS")) {
        cam.setMouseControlled(false);
        wasMouseOverGui = true;    // flag to make sure mouse control is restored properly without affecting non-vector gui.
        stroke(0, 200, 0, 100);
      }
      noFill();
      ellipse(mouseX, mouseY, actuator_test_distance*2+3, actuator_test_distance*2+3);
      ellipse(mouseX, mouseY, actuator_test_distance*2-3, actuator_test_distance*2-3);
      line(mouseX-10, mouseY, mouseX+10, mouseY);
      line(mouseX, mouseY-10, mouseX, mouseY+10);
      int test_text_height = actuator_test_distance / 10;
      if (test_text_height < textheight*0.8) test_text_height = int(textheight*0.8);
      if (test_text_height > textheight*2) test_text_height = int(textheight*2);
      textSize(test_text_height);
      noStroke();
      fill(255, 200, 0);
      text(actuator_test_type, mouseX+actuator_test_distance*.95, mouseY+actuator_test_distance*.98); 
      textSize(textheight);
      noCursor();
    } else {
      cursor();
      //cam.setMouseControlled(true);
    }

    gui.go();

    
    if (gui.my_isMouseOver() && !actuator_test_type.equals("VECTORS")) {
      if (!wasMouseOverGui) {                // so we don't call this every frame, just on transitions
        cam.setMouseControlled(false);
        wasMouseOverGui = true;
      }
    } else {
      if (wasMouseOverGui && !actuator_test_type.equals("VECTORS")) {                 // so we don't call this every frame, just on transitions
        cam.setMouseControlled(true);
        wasMouseOverGui = false;
      }
    }

    if (selected_sensor != null && selected_sensor.parent.type.equals("GN")) {
      
      prerecorded = gui.grp_prerec.isOpen();
      gesim = (prerecorded || gui.grp_simulation.isOpen());   // launch simulation if sim panel is open, live if closed
      draw_grideye_panel();

    }




    // grey the paused button if paused
    /* if (!gui.show_control_hiding) {
     if(show_control_awake) {
     
     //   if(frame % 200 > 100) {
     //            gui.show_control_pause.setColorBackground(color(9, 42, 92));
     //   } else {
     gui.show_control_pause.setColorBackground(color(90));
     //   }
     
     
     }
     }
     */
    cam.endHUD();

    //// TESTINBG 

      // if(ambientWavesVars.display) {
      // cam.beginHUD();
      // stroke(255, 100);
      // fill(100, 100, 255, 100);
      // ellipse(width/2, height/2, 300, 300);
      // cam.endHUD();    
      // }
  


    hint(ENABLE_DEPTH_TEST);
  }
}




/*!
 *  \fn draw_grideye_panel() 
 *  \brief MATT - TODO
 *  \return none
 */
void draw_grideye_panel() {
  ////  GRIDEYE PANEL DRAWING

  ///////////  G R I D E Y E

  ge.cur_ge = ((GridEye)(selected_sensor));  // currently selected grideye

  if (gesim) {
    ge.grideye_sim.update();
  //   ge.read_grideye_port();
  //   serialEvent(null);
  }

  if (!ge.goodFrame) {
    ge_draw();
    return;
  }

  geframe++;
  
  if (ge.debug) println(" checking incoming ... ");

  if (ge.incomingValues == null || ge.incomingValues.length  < 64 ) return;

  if (ge.debug) println("frame " + geframe + " - incoming size is " + ge.incomingValues.length);

  if (geframe % ge.cur_ge.frameskip != 0) {
    if (gesim || ge.cur_ge.stream)   ge_draw();    // draw gridEye simulation anyway...
    return;                              // ... but skip frames to emphasize motion differencing
  }

  //  println("here");

  if (gesim && prerecorded) {

    if (ge.debug) {
      println(" Input: ");
      ge.printMatrix(ge.incomingValues);
    }

    ge.incomingValues = ge.rotateMatrix(ge.incomingValues, ge.grideye_sim.recording_rotation);

    if (ge.debug) {
      println(" rotated by " + ge.grideye_sim.recording_rotation);
      ge.printMatrix(ge.incomingValues);
    }
  }





  // background(0);

  if (ge.debug) {
    println(" Incoming (rotated): ");
    ge.printMatrix(ge.incomingValues);


    /** used to test rotation code **
     println(" /// flipped:");
     printMatrix(rotateMatrix(incomingValues, 'F'));
     println(" /// rotated CW (right):");
     printMatrix(rotateMatrix(incomingValues, 'R'));
     println(" /// rotated CCW (left):");
     printMatrix(rotateMatrix(incomingValues, 'L'));
     **/
    //while (true);  // hang
    // **/
  }

  // average the matrix
  ge.average = ge.avgMatrix(ge.incomingValues);
  ge.maxIncoming = max(ge.incomingValues);
  ge.minIncoming = min(ge.incomingValues);





  if (ge.debug) {
    println ("average: " + ge.average );
  }

  // SET BACKGROUND if now is a good time (frame 5 for starters)
  if (geframe == 5) {
    ge.cur_ge.setBackground = true;
  }

  if (ge.cur_ge.setBackground) {
    println("SETTING BACKGROUND");
    arrayCopy(ge.incomingValues, ge.backgroundValues);
    ge.topMax = 0f;
    ge.topMaxFore = 5.0f;
    ge.maxDPVariance = 100f;  // can't initialize to zero or we get a divbyzero error
    ge.cur_ge.setBackground = false;
  }

  // SUBTRACT BACKGROUND  (subt, from)
  ge.foreValues = ge.subtractMatrix(ge.backgroundValues, ge.incomingValues, ge.cur_ge.noise_thresh);     // noise threshold

  if (ge.debug) {
    println("fV: ");
    ge.printMatrix(ge.foreValues);
  }

  // average the matrix
  ge.avgFore = ge.avgMatrix(ge.foreValues);
  ge.maxFore = max(ge.foreValues);
  ge.minFore = min(ge.foreValues);
  ge.topMaxFore = max(ge.topMaxFore, ge.maxFore);

  //println("topmaxfore: " + ge.topMaxFore);

  for (int i=0; i< ge.foreValues.length; i++) {
    //// Normalize the foreground pixels

    ge.foreValues[i] = map(ge.foreValues[i]/ge.topMaxFore, ge.avgFore/ge.topMaxFore, 1f, 0f, 255f) ;
    ge.foreValues[i] = max(0, ge.foreValues[i]);
  }


  ge_draw();

  ge.goodFrame = false;  // block calculations until a new frame is delivered.
}

/*!
 *  \fn ge_draw()
 *  \brief MATT - TODO
 *  \return none
 */
void ge_draw() {

  if (gesim) {    // start by drawing the simulation
    ge.grideye_sim.go();
  }

  arrayCopy(ge.motionValues, ge.outputMV);
  arrayCopy(ge.dpValues, ge.outputDP);

  ge.overall_presence = 0f;

  for (int i=0; i<8; i++) {
    for (int j=0; j<8; j++) {
      int index = (8*i)+j;

      //  draw the box - motion

      int pval = int(ge.pixelValues[index]);

      noStroke();
      // what is this?  -mg
      fill(pval, 180);
      rect(canvas_xo + (canvasw/20)*(j+1), canvas_yo+(canvash/2)/10*(i+1), canvasw/20, (canvash/2)/10);

      // text:
      fill(128);
      text(round(ge.outputMV[index]), canvas_xo + (canvasw/20)*(j+1), canvas_yo + canvash/20*(i+1));
      //   text(nf(outputDP[index], 2, 3), (canvasw/20)*(j+1), canvash/20*(i+1)+10);

      arrayCopy(new float[64], ge.dpValues);  // clear dpvalues


      //  draw the presence pixels 
      fill(ge.foreValues[index]);
      rect(canvas_xo + (canvasw/20)*(j+1), canvas_yo + (0*canvash/2)+(canvash/2)/10*(i+1), canvasw/20, (canvash/2)/10);

      ge.overall_presence += ge.foreValues[index];
    }
    if (ge.debug) {
     // println(" -- " );
    }
  }

  // draw the presence indicator - border is raw presence, fill is percent presence over threshold - this is what gets sent and recorded

  float p = map(ge.overall_presence, 200f, 2000f, 0.0, 1.0);
  if (p < 0 ) p = 0f;
  if (p > 1 ) p = 1f;

  float p_relative =  max(0f, p-ge.cur_ge.presence_threshold) / (1.0-ge.cur_ge.presence_threshold);

  stroke(p*255);
  fill(p_relative * 255);
  rect(canvas_xo + (canvasw/4) - canvasw/40, canvas_yo + canvash/2 - canvash/20, canvasw/2-canvasw/10, canvash/40);

  noStroke();

    // println("overall presence: " + overall_presence);


    // draw the rec_x and rex_y offsets, if it is prerecorded

  if (gesim && prerecorded) {

    int ii = (ge.rec_y_offset) % (8);
    if (ii < 0) ii = (8) + ii;  //  rolling offset
    int jj = (ge.rec_x_offset) % (8);
    if (jj < 0) jj = (8) + jj;  //  rolling offset

    stroke(255);
    line(canvas_xo - (canvasw/40) + (canvasw/20)*(jj+1), canvas_yo - (canvash/40) + canvash/20, 
         canvas_xo - (canvasw/40) + (canvasw/20)*(jj+1), canvas_yo - (canvash/40) + 9*canvash/20);
    line(canvas_xo - (canvasw/40) + (canvasw/20),   canvas_yo - (canvash/40) + canvash/20*(ii+1), 
         canvas_xo - (canvasw/40) + (canvasw/20)*9, canvas_yo - (canvash/40) + canvash/20*(ii+1));
  }

  ge.calcVectors();


    // send control a presence message (relative presence value - percent presence is over threshold):
    if( gesim || ge.cur_ge.stream ) { 
      String pi_addr = dl.find_nodes_parent_rpi(ge.cur_ge.parent.node_id).my_address;
      String control_addr = dl.get_control_ip(pi_addr);

      if(!override_control_ip.equals("")) control_addr = override_control_ip;

      if ((p >= ge.cur_ge.presence_threshold || p < 0.02) &&                     // above threshold OR close to zero.
         ge.cur_ge.elapsed_millis >= (1000/ge.cur_ge.polling_frequency)) {
         network.write_message("/RPI/GE_PRESENCE/" + pi_addr + "/" + control_addr + " " + Float.toString(p_relative));
         ge.cur_ge.last_millis = millis(); // mark last time a message was sent
      }

      PVector m_vector  = new PVector(ge.x_comp, ge.y_comp);

       m_vector.x *= 0.01;
       m_vector.y *= 0.01;

       m_vector.x = constrain(m_vector.x, -1.0, 1.0);
       m_vector.y = constrain(m_vector.y, -1.0, 1.0);

      float   m_vec_mag = m_vector.mag() ;
 
      
      if ((m_vec_mag >= ge.cur_ge.motion_threshold) && 
         ge.cur_ge.elapsed_millis >= (1000/ge.cur_ge.polling_frequency)) {
         network.write_message("/RPI/GE_MOTION/" + pi_addr + "/" + control_addr + " " + Float.toString(m_vector.x) + " " + Float.toString(m_vector.y));
         ge.cur_ge.last_millis = millis(); // mark last time a message was sent
      }
    }


  if (ge.goodFrame) {
    try {
      arrayCopy(ge.incomingValues, ge.lastFrame);
    }
    catch (ArrayIndexOutOfBoundsException e) {
      println(" ---- Array Index Out of Bounds, but that's all right. ----- ");
    }
  }

  //endDraw();


  ////////
}


//////////   GRIDEYE UI PANEL FUNCTIONS

/*!
 *  \fn setBackground()
 *  \brief MATT - TODO
 *  \return none
 */
void setBackground() {

  if (selected_sensor == null) return;
 
  println("SET BACKGROUND PUSHED");
  
  println("Telling grideye " + selected_sensor.name + " to set background");
  String pi_address = dl.find_nodes_parent_rpi(selected_sensor.parent.node_id).my_address;
  network.write_message("/CONTROL/GE_SET_BACKGROUND/" + control.my_address + "/" + pi_address);

}


/*!
 *  \fn geprintout()
 *  \brief MATT - TODO
 *  \param print out grideye info in a format that can be copied into CSV
 *  \return none
 */
void geprint() {

   println("");   
   println("");
   println("=== GRIDEYE CALIBRATION INFO ===");
   println("Copy the following line into the " + file_name + ".csv CONFIG column for " + selected_sensor.name);
   println("");
   println("FREQUENCY " + ge.cur_ge.polling_frequency + ";" +
           "THRESHOLD_MOTION " + ge.cur_ge.motion_threshold + ";" + 
           "THRESHOLD_PRESENCE " + ge.cur_ge.presence_threshold + ";" +
           "INTEREST_THRESHOLD " + ge.cur_ge.interest_thresh + ";" +
           "NOISE_THRESHOLD " + ge.cur_ge.noise_thresh + ";" +
           "OVERALL_RELAX " + ge.cur_ge.overall_relax + ";" + 
           "FRAMESKIP " + ge.cur_ge.frameskip + ";" +
           "ANGLE_ADJUST " + ge.cur_ge.output_angle + ";" );


  // ALSO - here is where we will save all the grideye settings to a .json file
  save_grideye_settings();
}

/*!
 *  \fn gefwd(boolean stream)
 *  \brief MATT - TODO
 *  \param stream tell the Grideye whether to stream data to control or not
 *  \return none
 */
void gefwd(boolean stream_mode) {

  if (selected_sensor == null) return;

  println("telling remote grideye " + selected_sensor.name + " it should stream: " + stream_mode);

  ge.cur_ge.stream = stream_mode;

  Sensor thisge = selected_sensor;    
  String pi_address = dl.find_nodes_parent_rpi(thisge.parent.node_id).my_address;
  String setting = "ON";
  if (!stream_mode) {
    setting = "OFF";
  } 

  network.write_message("/CONTROL/GE_SET_FORWARDING/" + control.my_address + "/" + pi_address + " " + setting);

}



/*!
 *  \fn togglepre(boolean pre)
 *  \brief MATT - TODO
 *  \param pre
 *  \return none
//  */
// void togglepre(boolean pre) {

//   println("setting prerecorded to " + pre);
//   prerecorded = pre;

//   if (pre==true) {
//     ge.grideye_sim.setup_prerecorded();
//   } else {
//     setBackground();
//   }
// }


/*!
 *  \fn pickfile(int n)
 *  \brief MATT - TODO
 *  \param n
 *  \return none
 */
void pickfile(int n) {

  if ( firstpick_ge ) {     // hack to prevent a null pointer on setup of pickfile dropdown.
    firstpick_ge = false;
    return;
  }

  /* request the selected item based on index n */

  ge.grideye_sim.recording_filename = String.valueOf(gui.vgui.get(ScrollableList.class, "pickfile").getItem(n).get("text"));
  //  println(n, gridEyeGUI.get(ScrollableList.class, "pickfile").getItem(n).get("text"));

  if (prerecorded == true) {
    ge.grideye_sim.setup_prerecorded();
  }
}

/*!
 *  \fn setOffset(float[] vals)
 *  \brief UNUSED
 *  \param vals
 *  \return none
 */
void setOffset(float[] vals) {

  println("setting offset to " + vals[0] + ", " + vals[1]);
}

/*!
 *  \fn setRotation(int n)
 *  \brief MATT - TODO
 *  \param n
 *  \return none
 */
void setRotation(int n) {

  String radiostring = gui.vgui.get(RadioButton.class, "setRotation").getItem(n).getLabel();

  switch(n) {
  case 0:
    ge.grideye_sim.recording_rotation = 'L';
    break;
  case 1:
    ge.grideye_sim.recording_rotation = '0';
    break;
  case 2:
    ge.grideye_sim.recording_rotation = 'R';
    break;
  case 3:
    ge.grideye_sim.recording_rotation = 'F';
    break;
  }

  println("set rotation to " + ge.grideye_sim.recording_rotation + "  -- " + radiostring);
}

/*!
 *  \fn angle_adjust(float a)
 *  \brief MATT - TODO
 *  \param a
 *  \return none
 */
// void angle_adjust(float a) {

//   //print ("Output angle is " + a );

//   ge.output_angle = radians(a);

//   //println(" , or " + output_angle + " radians");
// }


void ge_set_angle_adjust(float a) {

   if (ge.cur_ge == null) {
     return;
   }

   println("Setting GE " + ge.cur_ge.name + " output angle to " + a);
   String pi_address = dl.find_nodes_parent_rpi(ge.cur_ge.parent.node_id).my_address;
   network.write_message("/CONTROL/GE_CONFIG/"+ control.my_address + "/" + pi_address + " ANGLE_ADJUST " + a);
}

void ge_set_noise_thresh(float t) {

   if (ge.cur_ge == null) {
     return;
   }

   println("Setting GE " + ge.cur_ge.name + " noise threshold to " + t);
   String pi_address = dl.find_nodes_parent_rpi(ge.cur_ge.parent.node_id).my_address;
   network.write_message("/CONTROL/GE_CONFIG/"+ control.my_address + "/" + pi_address + " NOISE_THRESHOLD " + t);
}

void ge_set_interest_thresh(float t) {

   if (ge.cur_ge == null) {
     return;
   }

   println("Setting GE " + ge.cur_ge.name + " interest threshold to " + t);
   String pi_address = dl.find_nodes_parent_rpi(ge.cur_ge.parent.node_id).my_address;
   network.write_message("/CONTROL/GE_CONFIG/"+ control.my_address + "/" + pi_address + " INTEREST_THRESHOLD " + t);
}

void ge_set_overall_relax(float r) {

   if (ge.cur_ge == null) {
     return;
   }

   println("Setting GE " + ge.cur_ge.name + " overall_relax to " + r);
   String pi_address = dl.find_nodes_parent_rpi(ge.cur_ge.parent.node_id).my_address;
   network.write_message("/CONTROL/GE_CONFIG/"+ control.my_address + "/" + pi_address + " OVERALL_RELAX " + r);
}

void ge_set_frequency(int f) {

   if (ge.cur_ge == null) {
     return;
   }

   println("Setting GE " + ge.cur_ge.name + " freq " + f);
   String pi_address = dl.find_nodes_parent_rpi(ge.cur_ge.parent.node_id).my_address;
   network.write_message("/CONTROL/GE_CONFIG/"+ control.my_address + "/" + pi_address + " FREQUENCY " + f);

}

void ge_set_frameskip(int fs) {

   if (ge.cur_ge == null) {
     return;
   }

   println("Setting GE " + ge.cur_ge.name + " frame skip to " + fs);
   String pi_address = dl.find_nodes_parent_rpi(ge.cur_ge.parent.node_id).my_address;
   network.write_message("/CONTROL/GE_CONFIG/"+ control.my_address + "/" + pi_address + " FRAMESKIP " + fs);
}

void ge_set_presence_threshold(float a) {

   if (ge.cur_ge == null) {
     return;
   }

   println("Setting GE " + ge.cur_ge.name + " presence threshold: " + a);
   String pi_address = dl.find_nodes_parent_rpi(ge.cur_ge.parent.node_id).my_address;
   network.write_message("/CONTROL/GE_CONFIG/"+ control.my_address + "/" + pi_address + " THRESHOLD_PRESENCE " + a);
}

void ge_set_motion_threshold(float a) {

   if (ge.cur_ge == null) {
     return;
   }

   println("Setting GE " + ge.cur_ge.name + " motion threshold: " + a);
   String pi_address = dl.find_nodes_parent_rpi(ge.cur_ge.parent.node_id).my_address;
   network.write_message("/CONTROL/GE_CONFIG/"+ control.my_address + "/" + pi_address + " THRESHOLD_MOTION " + a);
}


void ge_reveal_patchable() {

   if (ge.cur_ge == null) {
     return;
   }
   patcher.revealByName(ge.cur_ge.name);

}







///// GUI MAPPING FUNCTIONS FOR IR DETECTORS
/*!
 *  \fn IR_set_live_or_local(int l) 
 *  \brief MATT - TODO
 *  \param l
 *  \return none
 */
void ir_set_live_or_local(int l) {           // set whether GUI and comms messaging use local (computer mic) or live (actual SD)
                                             // TO DO: DO WE NEED TO MUTE THE ACTUAL SD WHEN WE USE LOCAL?
  if (selected_sensor == null) {
    return;
  }

  if (!all_sensors_selected) {

      ir_set_a_live_or_local(selected_sensor, l);

  } else {
    for (Node n : dl.nodes.values()) {
      for (int i = 0; i < n.my_ir_detectors.length; i++ ) {
        if (n.my_ir_detectors[i].installed) {
          ir_set_a_live_or_local(n.my_ir_detectors[i], l);
        }
      }
    }
  }
}

/*!
 *  \fn ir_set_live_or_local(int l) 
 *  \brief MATT - TODO
 *  \param l
 *  \return none
 */
void ir_set_a_live_or_local(Sensor ir, int l) {    // set whether GUI and comms messaging use local (computer mic) or live (actual SD)
                                             
  String node_address = str(ir.parent.node_id);
  String num = str(ir.designator.device_number+1);  // note device number is zero-based, not the number in the .csv
  String setting;

  if (l==1) setting = "LOCAL";
  else      setting = "LIVE";

   println("Setting " + node_address + " IR" + num +" use_local to " + setting);
   network.write_message("/CONTROL/IR_CONFIG/"+ control.my_address + "/" + node_address + " IR" + num + " USE_LOCAL " + setting);
}



/*!
 *  \fn ir_set_polling(int p)
 *  \brief MATT - TODO
 *  \param p
 *  \return none
 */
void ir_set_polling(int p) {

  // println(" set polling ");

  if (selected_sensor == null) {
    return;
  }

  if (!all_sensors_selected) {

    ir_set_a_polling(selected_sensor, p);
  } else {
    for (Node n : dl.nodes.values()) {
      for (int i = 0; i < n.my_ir_detectors.length; i++ ) {
        if (n.my_ir_detectors[i].installed) {
          ir_set_a_polling(n.my_ir_detectors[i], p);
        }
      }
    }
  }
}

/*!
 *  \fn ir_set_polling(Sensor sd, int p)
 *  \brief MATT - TODO
 *  \param sd
 *  \param p
 *  \return none
 */
void ir_set_a_polling(Sensor ir, int p) {

  String node_address = str(ir.parent.node_id);
  String num = str(ir.designator.device_number+1);  // note device number is zero-based, not the number in the .csv
  String setting;

  if (p==1) setting = "ON";
  else      setting = "OFF";

   println("Setting " + node_address + " IR" + num + " polling to " + setting);
   network.write_message("/CONTROL/IR_CONFIG/"+ control.my_address + "/" + node_address + " IR" + num + " POLLING " + setting);

}

/*!
 *  \fn ir_set_threshold(int t)
 *  \brief MATT - TODO
 *  \param t
 *  \return none
 */
void ir_set_threshold(int t) {

  // println(" set thresh ");

  if (selected_sensor == null) {
    return;
  }

  if (!all_sensors_selected) {

    ir_set_a_threshold(selected_sensor, t);

  } else {
    for (Node n : dl.nodes.values()) {
      for (int i = 0; i < n.my_ir_detectors.length; i++ ) {
        if (n.my_ir_detectors[i].installed) {
          ir_set_a_threshold(n.my_ir_detectors[i], t);
        }
      }
    }
  }
}

/*!
 *  \fn ir_set_a_threshold(Sensor sd, int t)
 *  \brief MATT - TODO
 *  \param sd
 *  \param t
 *  \return none
 */
void ir_set_a_threshold(Sensor ir, int t) {

  String node_address = str(ir.parent.node_id);
  String num = str(ir.designator.device_number+1);  // note device number is zero-based, not the number in the .csv
  String setting = str(t);

   println("Setting " + node_address + " IR" + num + " threshold to " + setting);
   network.write_message("/CONTROL/IR_CONFIG/"+ control.my_address + "/" + node_address + " IR" + num + " THRESHOLD " + setting);
}

/*!
 *  \fn ir_set_freq(int f) 
 *  \brief MATT - TODO
 *  \param f
 *  \return none
 */
void ir_set_freq(int f) {

  // println(" set freq ");

  if (selected_sensor == null) {
    return;
  }

  if (!all_sensors_selected) {

    ir_set_a_freq(selected_sensor, f);
  } else {
    for (Node n : dl.nodes.values()) {
      for (int i = 0; i < n.my_ir_detectors.length; i++ ) {
        if (n.my_ir_detectors[i].installed) {
          ir_set_a_freq(n.my_ir_detectors[i], f);
        }
      }
    }
  }
}

/*!
 *  \fn ir_set_a_freq(Sensor ir, int f) 
 *  \brief MATT - TODO
 *  \param ir
 *  \param f
 *  \return none
 */
void ir_set_a_freq(Sensor ir, int f) {

  String node_address = str(ir.parent.node_id);
  String num = str(ir.designator.device_number+1);  // note device number is zero-based, not the number in the .csv
  String setting = str(f);

   println("Setting " + node_address + " IR" + num + " frequency to " + setting);
   network.write_message("/CONTROL/IR_CONFIG/"+ control.my_address + "/" + node_address + " IR" + num + " FREQUENCY " + setting);
}




///// GUI MAPPING FUNCTIONS FOR SOUND DETECTORS
/*!
 *  \fn sd_set_live_or_local(int l) 
 *  \brief MATT - TODO
 *  \param l
 *  \return none
 */
void sd_set_live_or_local(int l) {           // set whether GUI and comms messaging use local (computer mic) or live (actual SD)
                                             // TO DO: DO WE NEED TO MUTE THE ACTUAL SD WHEN WE USE LOCAL?
  if (selected_sensor == null) {
    return;
  }

  if (!all_sensors_selected) {

      sd_set_a_live_or_local(selected_sensor, l);

  } else {
    for (Node n : dl.nodes.values()) {
      for (int i = 0; i < n.my_sound_detectors.length; i++ ) {
        if (n.my_sound_detectors[i].installed) {
          sd_set_a_live_or_local(n.my_sound_detectors[i], l);
        }
      }
    }
  }
}

/*!
 *  \fn sd_set_live_or_local(int l) 
 *  \brief MATT - TODO
 *  \param l
 *  \return none
 */
void sd_set_a_live_or_local(Sensor sd, int l) {    // set whether GUI and comms messaging use local (computer mic) or live (actual SD)
                                             
  String node_address = str(sd.parent.node_id);
  String num = str(sd.designator.device_number+1);  // note device number is zero-based, not the number in the .csv
  String setting;

  if (l==1) setting = "LOCAL";
  else      setting = "LIVE";

//  network.write_message("/CONTROL/SD_LIVE_OR_LOCAL/"+ control.my_address + "/" + node_address + " SD" + num + " " + setting);
  network.write_message("/CONTROL/SD_CONFIG/"+ control.my_address + "/" + node_address + " SD" + num + " USE_LOCAL " + setting);

}


 
/*!
 *  \fn sd_set_polling(int p)
 *  \brief MATT - TODO
 *  \param p
 *  \return none
 */
void sd_set_polling(int p) {

  // println(" set polling ");

  if (selected_sensor == null) {
    return;
  }

  if (!all_sensors_selected) {

    sd_set_a_polling(selected_sensor, p);
  } else {
    for (Node n : dl.nodes.values()) {
      for (int i = 0; i < n.my_sound_detectors.length; i++ ) {
        if (n.my_sound_detectors[i].installed) {
          sd_set_a_polling(n.my_sound_detectors[i], p);
        }
      }
    }
  }
}

/*!
 *  \fn sd_set_polling(Sensor sd, int p)
 *  \brief MATT - TODO
 *  \param sd
 *  \param p
 *  \return none
 */
void sd_set_a_polling(Sensor sd, int p) {

  String node_address = str(sd.parent.node_id);
  String num = str(sd.designator.device_number+1);  // note device number is zero-based, not the number in the .csv
  String setting;

  if (p==1) setting = "ON";
  else      setting = "OFF";

//  network.write_message("/CONTROL/SD_AUTO_SAMPLING/"+ control.my_address + "/" + node_address + " SD" + num + " " + setting);
    network.write_message("/CONTROL/SD_CONFIG/"+ control.my_address + "/" + node_address + " SD" + num + " POLLING " + setting);
}

 
/*!
 *  \fn sd_reveal_patchable(int p)
 *  \brief MATT - TODO
 *  \param p
 *  \return none
 */
void sd_reveal_patchable(int p) {

  // println(" set polling ");

  if (selected_sensor == null) {
    return;
  }

  if (!all_sensors_selected) {

    sd_reveal_a_patchable(selected_sensor, p);
  } else {
    for (Node n : dl.nodes.values()) {
      for (int i = 0; i < n.my_sound_detectors.length; i++ ) {
        if (n.my_sound_detectors[i].installed) {
          sd_reveal_a_patchable(n.my_sound_detectors[i], p);
        }
      }
    }
  }
}

/*!
 *  \fn sd_reveal_a_patchable(Sensor sd, int p)
 *  \brief MATT - TODO
 *  \param sd
 *  \param p
 *  \return none
 */
void sd_reveal_a_patchable(Sensor sd, int p) {

  String node_address = str(sd.parent.node_id);
  String num = str(sd.designator.device_number+1);  // note device number is zero-based, not the number in the .csv
  String setting;

  if (p==1) {   // show patchable
      patcher.revealByName(sd.name);
  } else {      // remove patchable
      patcher.remove(sd.name);
  } 
}


/*!
 *  \fn sd_hide_patchable(int p)
 *  \brief MATT - TODO
 *  \param p
 *  \return none
 */
void sd_hide_patchable(int p) {

  // println(" set polling ");

  if (selected_sensor == null) {
    return;
  }

  if (!all_sensors_selected) {

    sd_hide_a_patchable(selected_sensor, p);
  } else {
    for (Node n : dl.nodes.values()) {
      for (int i = 0; i < n.my_sound_detectors.length; i++ ) {
        if (n.my_sound_detectors[i].installed) {
          sd_hide_a_patchable(n.my_sound_detectors[i], p);
        }
      }
    }
  }
}

/*!
 *  \fn sd_reveal_a_patchable(Sensor sd, int p)
 *  \brief MATT - TODO
 *  \param sd
 *  \param p
 *  \return none
 */
void sd_hide_a_patchable(Sensor sd, int p) {

  String node_address = str(sd.parent.node_id);
  String num = str(sd.designator.device_number+1);  // note device number is zero-based, not the number in the .csv
  String setting;

  if (p==1) {   // show patchable
      patcher.show(sd.name);
  } else {      // remove patchable
      patcher.hide(sd.name);
  } 
}


/*!
 *  \fn sd_set_threshold(int t)
 *  \brief MATT - TODO
 *  \param t
 *  \return none
 */
void sd_set_threshold(int t) {

  // println(" set thresh ");

  if (selected_sensor == null) {
    return;
  }

  if (!all_sensors_selected) {

    sd_set_a_threshold(selected_sensor, t);

  } else {
    for (Node n : dl.nodes.values()) {
      for (int i = 0; i < n.my_sound_detectors.length; i++ ) {
        if (n.my_sound_detectors[i].installed) {
          sd_set_a_threshold(n.my_sound_detectors[i], t);
        }
      }
    }
  }
}

/*!
 *  \fn sd_set_a_threshold(Sensor sd, int t)
 *  \brief MATT - TODO
 *  \param sd
 *  \param t
 *  \return none
 */
void sd_set_a_threshold(Sensor sd, int t) {

  String node_address = str(sd.parent.node_id);
  String num = str(sd.designator.device_number+1);  // note device number is zero-based, not the number in the .csv
  String setting = str(t);

//  network.write_message("/CONTROL/SD_SET_THRESHOLD/"+ control.my_address + "/" + node_address + " SD" + num + " " + setting);
  network.write_message("/CONTROL/SD_CONFIG/"+ control.my_address + "/" + node_address + " SD" + num + " THRESHOLD " + setting);}

/*!
 *  \fn sd_set_freq(int f) 
 *  \brief MATT - TODO
 *  \param f
 *  \return none
 */
void sd_set_freq(int f) {

  // println(" set freq ");

  if (selected_sensor == null) {
    return;
  }

  if (!all_sensors_selected) {

    sd_set_a_freq(selected_sensor, f);
  } else {
    for (Node n : dl.nodes.values()) {
      for (int i = 0; i < n.my_sound_detectors.length; i++ ) {
        if (n.my_sound_detectors[i].installed) {
          sd_set_a_freq(n.my_sound_detectors[i], f);
        }
      }
    }
  }
}

/*!
 *  \fn sd_set_a_freq(Sensor sd, int f) 
 *  \brief MATT - TODO
 *  \param sd
 *  \param f
 *  \return none
 */
void sd_set_a_freq(Sensor sd, int f) {

  String node_address = str(sd.parent.node_id);
  String num = str(sd.designator.device_number+1);  // note device number is zero-based, not the number in the .csv
  String setting = str(f);

//  network.write_message("/CONTROL/SD_SET_FREQUENCY/"+ control.my_address + "/" + node_address + " SD" + num + " " + setting);
  network.write_message("/CONTROL/SD_CONFIG/"+ control.my_address + "/" + node_address + " SD" + num + " FREQUENCY " + setting);
  
}



/*!
 *  \fn apply_sensor_settings_to(int which) 
 *  \brief MATT - TODO
 *  \param which
 *  \return none
 */
void apply_sensor_settings_to(int which) {


  switch(which) {
  case 0: // this SD or GE
    all_sensors_selected = false;
    break;

  case 1: // all SD or GEs
    all_sensors_selected = true;
    break;
  }
}


//////////   INFLUENCE UI PANEL FUNCTIONS




/*!
 *  \fn isolate_grp
 *  \brief MATT - TODO
 *  \param which
 *  \return none
 */
void isolate_grp(boolean active) {

    if(active) {
      isolated_group = selected_actuator.name.substring(0,2);
    } else {
      isolated_group = "";
    }
    println("Isolated Group is: " + isolated_group);

}


/*!
 *  \fn apply_ir_settings_to(int which)
 *  \brief MATT - TODO
 *  \param which
 *  \return none
 */
void apply_ir_settings_to(int which) {
  apply_sensor_settings_to(which);
}

/*!
 *  \fn apply_sd_settings_to(int which)
 *  \brief MATT - TODO
 *  \param which
 *  \return none
 */
void apply_sd_settings_to(int which) {
  apply_sensor_settings_to(which);
}

/*!
 *  \fn apply_moth_settings_to(int which)
 *  \brief MATT - TODO
 *  \param which
 *  \return none
 */
void apply_moth_settings_to(int which) {
  apply_actuator_settings_to(which);
}

/*!
 *  \fn apply_SMA_settings_to(int which)
 *  \brief MATT - TODO
 *  \param which
 *  \return none
 */
void apply_SMA_settings_to(int which) {
  apply_actuator_settings_to(which);
}

/*!
 *  \fn apply_drs_settings_to(int which)
 *  \brief MATT - TODO
 *  \param which
 *  \return none
 */
void apply_drs_settings_to(int which) {
  apply_actuator_settings_to(which);
}

/*!
 *  \fn apply_actuator_settings_to(int which)
 *  \brief MATT - TODO
 *  \param which
 *  \return none
 */
void apply_actuator_settings_to(int which) {

  switch(which) {

  case 0:  // this moth or DRS or SMA
    selected_node  = NO_NODES_SELECTED;
    break;
  case 1:  // this group
    selected_node = selected_actuator.parent.node_id;
    break;
  case 2:  // all actuators
    selected_node = ALL_NODES_SELECTED;
    break;
  }
}

/*!
 *  \fn subscribe_to_this_influence(boolean s)
 *  \brief MATT - TODO
 *  \param s
 *  \return none
 */
void subscribe_to_this_influence(boolean s) {

  if (selected_actuator == null) {
    return;
  }

  if (selected_node == NO_NODES_SELECTED) {

    // subscribe_to_cur_influence(selected_actuator, s);
    subscribe_to_cur_influence(selected_actuator.parent, selected_actuator, s);

  } else {
    for (Node n : dl.nodes.values()) {

        if(selected_actuator.designator.device_type.equals("MO") && ( (selected_node == n.node_id) || (selected_node == ALL_NODES_SELECTED &&  (isolated_group.equals("") || isolated_group.equals(n.node_group.substring(0,2))) ))) {
          for (int i = 0; i < n.my_moths.length; i++ ) {
            if (n.my_moths[i].installed) {
               // subscribe_to_cur_influence(n.my_moths[i], s);
               subscribe_to_cur_influence(n, n.my_moths[i], s);
            }
          }
        } 
        else if(selected_actuator.designator.device_type.equals("DR") && ( (selected_node == n.node_id) || (selected_node == ALL_NODES_SELECTED &&  (isolated_group.equals("") || isolated_group.equals(n.node_group.substring(0,2))) ))) {
          for (int i = 0; i < n.my_double_rebel_stars.length; i++ ) {
            if (n.my_double_rebel_stars[i].installed) {
               // subscribe_to_cur_influence(n.my_double_rebel_stars[i], s);
               subscribe_to_cur_influence(n, n.my_double_rebel_stars[i], s);
            }
          }
        } 
        else if(selected_actuator.designator.device_type.equals("RS") && ( (selected_node == n.node_id) || (selected_node == ALL_NODES_SELECTED &&  (isolated_group.equals("") || isolated_group.equals(n.node_group.substring(0,2))) ))) {
          for (int i = 0; i < n.my_rebel_stars.length; i++ ) {
            if (n.my_rebel_stars[i].installed) {
               // subscribe_to_cur_influence(n.my_rebel_stars[i], s);
               subscribe_to_cur_influence(n, n.my_rebel_stars[i], s);
            }
          }
        }
        else if(selected_actuator.designator.device_type.equals("PC") && ( (selected_node == n.node_id) || (selected_node == ALL_NODES_SELECTED &&  (isolated_group.equals("") || isolated_group.equals(n.node_group.substring(0,2))) ))) {
          for (int i = 0; i < n.my_protocells.length; i++ ) {
            if (n.my_protocells[i].installed) {
                subscribe_to_cur_influence(n, n.my_protocells[i], s);
            }
          }
        } 
        else if(selected_actuator.designator.device_type.equals("SM") && ( (selected_node == n.node_id) || (selected_node == ALL_NODES_SELECTED &&  (isolated_group.equals("") || isolated_group.equals(n.node_group.substring(0,2))) ))) {
          for (int i = 0; i < n.my_smas.length; i++ ) {
            if (n.my_smas[i].installed) {
                subscribe_to_cur_influence(n, n.my_smas[i], s);
            }
          }
        } 
    }
  }
}


void subscribe_to_cur_influence(Node n, Actuator a, boolean s) {

     subscribe_to_any_influence(cur_influence, n, a, s);

}

void subscribe_to_any_influence(String inf, Node n, Actuator a, boolean s) {

 if(inf.equals("") || inf.equals("GE") || inf.equals("FF") || inf.equals("SD")) return;

 String sub = "FALSE";
 if(s)  sub = "TRUE";

 String act_name = a.designator.get_identifier_string();
 network.write_message("/CONTROL/INFLUENCE_MAP/"+ control.my_address + "/" + n.node_id + " " + inf + " " + act_name + " " + sub);
 // println(" ... sub_to_any is sending:    /CONTROL/INFLUENCE_MAP/"+ control.my_address + "/" + n.node_id + " " + inf + " " + act_name + " " + sub);

}

/// OLD way of setting influence map range directly by passing the actuator, instead of with messages to the node
//void subscribe_to_cur_influence(Actuator a, boolean s) {
//
//  if(s)  a.enable_influence(cur_influence);
//  else   a.disable_influence(cur_influence);
//
// }

void subscribe_actuators_by_type(String type, String influence, boolean subscribe) {

    println("Going to try to set actuators of type " + type + " to " + subscribe + " for " + influence);

    for (Node n : dl.nodes.values()) {

        if(type.equals("MO") || type.equals("ALL")) {
          for (int i = 0; i < n.my_moths.length; i++ ) {
            if (n.my_moths[i].installed) {
               subscribe_to_any_influence(influence, n, n.my_moths[i], subscribe);
            }
          }
        } 
        
        if(type.equals("DR") || type.equals("ALL")) {
          for (int i = 0; i < n.my_double_rebel_stars.length; i++ ) {
            if (n.my_double_rebel_stars[i].installed) {
               subscribe_to_any_influence(influence, n, n.my_double_rebel_stars[i], subscribe);
            }
          }
        } 
        
        if(type.equals("RS") || type.equals("ALL")) {
          for (int i = 0; i < n.my_rebel_stars.length; i++ ) {
            if (n.my_rebel_stars[i].installed) {
               subscribe_to_any_influence(influence, n, n.my_rebel_stars[i], subscribe);
            }
          }
        } 
        
        if(type.equals("PC") || type.equals("ALL")) {
          for (int i = 0; i < n.my_protocells.length; i++ ) {
            if (n.my_protocells[i].installed) {
               subscribe_to_any_influence(influence, n, n.my_protocells[i], subscribe);
            }
          }
        } 
        
        if(type.equals("SM") || type.equals("ALL")) {
          for (int i = 0; i < n.my_smas.length; i++ ) {
            if (n.my_smas[i].installed) {
               subscribe_to_any_influence(influence, n, n.my_smas[i], subscribe);
            }
          }
        } 
    }
}



/*!
 *  \fn set_influence_map_range(float r)
 *  \brief MATT - TODO
 *  \param r
 *  \return none
 */
void set_influence_map_range() {

  if (!gui.initialized) return;

  float bot = gui.influence_range.getArrayValue(0) / 100.0;
  float top = gui.influence_range.getArrayValue(1) / 100.0;

  // println("sending bot = " + bot);

  if (selected_actuator == null) {
    return;
  }

  if (selected_node == NO_NODES_SELECTED) {

    // set_cur_influence_map_range(selected_actuator, bot, top);
    set_cur_influence_map_range(selected_actuator.parent, selected_actuator, bot, top);

  } else {
    for (Node n : dl.nodes.values()) {

        if(selected_actuator.designator.device_type.equals("MO") && ( (selected_node == n.node_id) || (selected_node == ALL_NODES_SELECTED) )) {
          for (int i = 0; i < n.my_moths.length; i++ ) {
            if (n.my_moths[i].installed) {
               // set_cur_influence_map_range(n.my_moths[i], bot, top);
               set_cur_influence_map_range(n, n.my_moths[i], bot, top);
            }
          }
        } 
        else if(selected_actuator.designator.device_type.equals("DR") && ( (selected_node == n.node_id) || (selected_node == ALL_NODES_SELECTED) )) {
          for (int i = 0; i < n.my_double_rebel_stars.length; i++ ) {
            if (n.my_double_rebel_stars[i].installed) {
               // set_cur_influence_map_range(n.my_double_rebel_stars[i], bot, top);
               set_cur_influence_map_range(n, n.my_double_rebel_stars[i], bot, top);
            }
          }
        } 
        else if(selected_actuator.designator.device_type.equals("RS") && ( (selected_node == n.node_id) || (selected_node == ALL_NODES_SELECTED) )) {
          for (int i = 0; i < n.my_rebel_stars.length; i++ ) {
            if (n.my_rebel_stars[i].installed) {
               // set_cur_influence_map_range(n.my_rebel_stars[i], bot, top);
               set_cur_influence_map_range(n, n.my_rebel_stars[i], bot, top);
            }
          }
        } 
        else if(selected_actuator.designator.device_type.equals("PC") && ( (selected_node == n.node_id) || (selected_node == ALL_NODES_SELECTED) )) {
          for (int i = 0; i < n.my_protocells.length; i++ ) {
            if (n.my_protocells[i].installed) {
               set_cur_influence_map_range(n, n.my_protocells[i], bot, top);
            }
          }
        } 
        else if(selected_actuator.designator.device_type.equals("SM") && ( (selected_node == n.node_id) || (selected_node == ALL_NODES_SELECTED) )) {
          for (int i = 0; i < n.my_smas.length; i++ ) {
            if (n.my_smas[i].installed) {
               set_cur_influence_map_range(n, n.my_smas[i], bot, top);
            }
          }
        } 
    }
  }
}

void set_cur_influence_map_range(Node n, Actuator a, float bot, float top) {
     set_any_influence_map_range(cur_influence, n, a, bot, top);
}

void set_any_influence_map_range(String inf, Node n, Actuator a, float bot, float top) {

////////  KILLER BUG July 28 2020 - if an "RH" influence is sent with mapping, it crashes PIs
////////   when they try to write the influence range to the Teensy.  (0x57 <uid> <lowbound1> <lowbound2> <upbound1><upbound2>) 
////////    to be safe, don't send GE, FF, or SD for now either becasue they aren't really relevant.
///////  workaround - remove RH entirely, and call them excitors for now.
if(inf.equals("RH") || inf.equals("GE") || inf.equals("FF") || inf.equals("SD")) return;

 String act_name = a.designator.get_identifier_string();




 // println(" ... set_any_range is sending:    /CONTROL/INFLUENCE_RANGE/"+ control.my_address + "/" + n.node_id + " " + inf + " " + act_name + " " + bot + " " + top);
 network.write_message("/CONTROL/INFLUENCE_RANGE/"+ control.my_address + "/" + n.node_id + " " + inf + " " + act_name + " " + bot + " " + top);

}

/*!
 *  \fn set_influence_map_range(float r)
 *  \brief goes through all actuators in a given node and syncs them with their virtual counterpart values.
 *  \param r
 *  \return none
 */
void sync_actuator_influence_maps(String node_id) {

   // println(" WILL sync node " + node_id + "'s actuators to their virtual counterpart influence maps...  ");

   Node target_node = dl.nodes.get(Integer.parseInt(node_id));

   // for each actuator on this node type
    String[] node_devices = dl.get_devs(dl.get_node_type(Integer.parseInt(node_id)));

    String this_influence = "";

    int nd = node_devices.length;

    // println("Configuring devices on node " + node_id + ":");
    // print("   names are: [ ");
    // for(int i = 0; i < node_devices.length; i++) { print(node_devices[i] + ", ");}
    // println(" ]");

    Actuator act = null;

    // for each device
    for (int i = nd-1; i >= 0; i--) 
    {        


         switch(node_devices[i].substring(0,2)) {

         case "MO":
         act = (Actuator)(target_node.my_moths[Integer.parseInt(node_devices[i].substring(2))-1]);
         break;
         case "DR":
         act = (Actuator)(target_node.my_double_rebel_stars[Integer.parseInt(node_devices[i].substring(2))-1]);
          if(act != null && act.installed) {  // set DRS mode and offset here
            set_a_drs_mode(act, ((DoubleRebelStar)(act)).mode - (int)0x3b); // radio buttons are a zero-index list, mode codes start at 0x3b
            set_a_drs_offset(act, (int)((DoubleRebelStar)(act)).offset);
          }
         break;
         case "RS":
         act = (Actuator)(target_node.my_rebel_stars[Integer.parseInt(node_devices[i].substring(2))-1]);
         break;
         case "PC":
         act = (Actuator)(target_node.my_protocells[Integer.parseInt(node_devices[i].substring(2))-1]);
         break;
         case "SM":
         act = (Actuator)(target_node.my_smas[Integer.parseInt(node_devices[i].substring(2))-1]);
         break;

         default:
         continue;

        }

        // println("Setting inf on node " + node_id + ", device " + node_devices[i] + "(" + act.name + "):");

        if(act == null)    continue;
        if(!act.installed) continue;

        // go through all the influences (n)

        for(int n = 0; n < gui.which_influence.getItems().size(); n++) {

    
          String nickname = String.valueOf(gui.which_influence.getItem(n).get("value"));

          if(nickname.equals("SB")) continue;  //  these are behaviours to skip -- ie the "sample behaviour" that does nothing.
          if(nickname.equals("FF")) continue;  // this is a catch to replace old FF with GRs.
          if(nickname.equals("RH")) continue; 

          if(!nickname.equals(str(n))) {   // if we have set a specific nickname for this
              this_influence = nickname;
          } else {
              this_influence = String.valueOf(gui.which_influence.getItem(n).get("text"));
          }
    
          // println("    For " + this_influence + ": " + act.subscribed_to_influence(this_influence));

          //println("Setting inf levels on node " + node_id + ", device " + node_devices[i] + "(" + act.name + ")" + " for " + this_influence);

          //// now send the message subscribing it to whatever the virtual node has.
          subscribe_to_any_influence(this_influence, target_node, act, act.subscribed_to_influence(this_influence));

          // println("setting "+ act.name + " range to " + 100*act.get_low_range(this_influence) + ", " + 100*act.get_high_range(this_influence) + " for " + this_influence);          
          set_any_influence_map_range(this_influence, target_node, act, act.get_low_range(this_influence), act.get_high_range(this_influence));
          
        }
    }
}


/*!
 *  \fn set_drs_mode()
 *  \brief gui trigger functions for setting DRS modes
 *  \return none
 */
void set_drs_mode(int mode_code) {
  // println(" set polling ");

  if (selected_actuator == null) {
    return;
  }

 if (selected_node == NO_NODES_SELECTED) {

    set_a_drs_mode(selected_actuator, mode_code);

  } else {
    for (Node n : dl.nodes.values()) {

        if(selected_actuator.designator.device_type.equals("DR") && ( (selected_node == n.node_id) || (selected_node == ALL_NODES_SELECTED) )) {
          for (int i = 0; i < n.my_double_rebel_stars.length; i++ ) {
            if (n.my_double_rebel_stars[i].installed) {
               set_a_drs_mode(n.my_double_rebel_stars[i], mode_code);
            }
          }
        } 
    }
  }
}

void set_a_drs_mode(Actuator drs, int index) {

  String node_address = str(drs.parent.node_id);
  String num = str(drs.designator.device_number+1);  // note device number is zero-based, not the number in the .csv
  String setting = gui.drs_mode.getItem(index).getName();
  
  int space_index = setting.indexOf(" ");
  if(space_index == -1) { space_index = setting.length()-1; }

  String mode_name = setting.substring(0, space_index);
  // println("selected is " + mode_name);
  set_a_drs_mode(drs, mode_name); 

}

void set_a_drs_mode(Actuator drs, String mode) {

  String node_address = str(drs.parent.node_id);
  String num = str(drs.designator.device_number+1);  // note device number is zero-based, not the number in the .csv
   
  network.write_message("/CONTROL/DR_CONFIG/"+ control.my_address   + "/" + node_address + " DR" + num + " MODE " + mode);

  if(mode.contains("BOTH") && (selected_actuator != null) && (drs==selected_actuator) ) { // if this was selected by the gui
    set_drs_offset(gui.drs_offset.getValue());
  } else if(!mode.contains("BOTH")){  // turn off invert if we are switching away from BOTH mode.
    network.write_message("/CONTROL/DR_CONFIG/"+ control.my_address + "/" + node_address + " DR" + num + " INVERT false");
  } 
}


/*!
 *  \fn set_drs_offset()
 *  \brief gui trigger functions for setting DRS offset values
 *  \return none
 */

void set_drs_offset(float offset) {
    if(gui.drs_offset == null) return;
    if (selected_actuator == null) return;
  
    //float offset = gui.drs_offset.getValue();

    if(abs(offset) < 0.05 && !drs_offset_snapped) {

      offset = 0.0;
      if(gui.drs_offset != null)
      drs_offset_snapped = true;
      gui.drs_offset.setValue(0);

    } else {
      if(abs(offset) > 0.05) drs_offset_snapped = false;     // this is to avoid an infinite loop
    }

    int offset_millis = 0;
      
    offset_millis = int(1000 * offset);

    if (selected_node == NO_NODES_SELECTED) {

    set_a_drs_offset(selected_actuator, offset_millis);

    } else {
        for (Node n : dl.nodes.values()) {
            if(selected_actuator.designator.device_type.equals("DR") && ( (selected_node == n.node_id) || (selected_node == ALL_NODES_SELECTED) )) {
              for (int i = 0; i < n.my_double_rebel_stars.length; i++ ) {
                if (n.my_double_rebel_stars[i].installed) {
                  set_a_drs_offset(n.my_double_rebel_stars[i], offset_millis);
                }
              }
            } 
        }
      }
}

void set_a_drs_offset(Actuator drs, int offset_millis) {

  String node_address = str(drs.parent.node_id);
  String num = str(drs.designator.device_number+1);  // note device number is zero-based, not the number in the .csv

  // println("offset is " + offset_millis);
  
  if(offset_millis < 0) {
    network.write_message("/CONTROL/DR_CONFIG/"+ control.my_address + "/" + node_address + " DR" + num + " INVERT true");
  } else {
    network.write_message("/CONTROL/DR_CONFIG/"+ control.my_address + "/" + node_address + " DR" + num + " INVERT false");
  }

  network.write_message("/CONTROL/DR_CONFIG/"+ control.my_address + "/" + node_address + " DR" + num + " OFFSET " + abs(offset_millis));
}

void reset_drs_offset() {

   set_drs_offset(0.0);

}

void average_coords(int a) {

   if(selected_actuator != null) {
     gui.display_coords(selected_actuator.position);
   }
}

/*!
 *  \fn set_which_influence()
 *  \brief MATT - TODO
 *  \return none
 */
void set_which_influence(int n) {
 
   if ( firstpick_inf ) {     // hack to prevent a null pointer on setup of pickfile dropdown.
    firstpick_inf = false;
    return;
  }

  //   cur_influence = String.valueOf(gui.vgui.get(ScrollableList.class, "set_which_influence").getItem(n).get("text"));

     String nickname = String.valueOf(gui.which_influence.getItem(n).get("value"));
     if(!nickname.equals(str(n))) {   // if we have set a specific nickname for this
         cur_influence = nickname;
     } else {
         cur_influence = String.valueOf(gui.which_influence.getItem(n).get("text"));
     }

     println("Setting current influence for " + cur_influence);

     //// now adjusting the GUI to match current values
     if (selected_actuator != null) {
      gui.subscribe_influence.setValue(selected_actuator.subscribed_to_influence(cur_influence));
      // println("setting "+ selected_actuator.name + " gui range to " + 100*selected_actuator.get_low_range(cur_influence) + ", " + 100*selected_actuator.get_high_range(cur_influence) + " for " + cur_influence);
      
      float[] r_array = new float[2];
      r_array[0] = 100*selected_actuator.get_low_range(cur_influence);
      r_array[1] = 100*selected_actuator.get_high_range(cur_influence);
      gui.influence_range.setArrayValue(r_array); 

      // also do the mode and the offset, if it's a DR
      if (selected_actuator.designator.device_type.equals("DR")) {

          gui.drs_mode.activate(((DoubleRebelStar)selected_actuator).mode - (int)0x3b); // radio buttons are a zero-index list, mode codes start at 0x3b
          int neg = 1;
          if(((DoubleRebelStar)selected_actuator).invert) neg = -1;
          gui.drs_offset.setValue(neg * abs(((DoubleRebelStar)selected_actuator).offset / 1000f));
     
      }

     }  
}



void pick_scene_gui(int n) {

  String new_scene = "";

  try {
    if ( firstpick_scene ) {     // hack to prevent a null pointer on setup of pickfile dropdown. switching to try block
      firstpick_scene = false;
      return;
    }

  /* request the selected item based on index n */
    new_scene = String.valueOf(gui.vgui.get(ScrollableList.class, "pick_scene_gui").getItem(n).get("text"));

  } catch(Exception e) {
    println(" ** exception triggered by setup of scene picker dropdown - as expected: " + e);
    return;
  }

  if(new_scene.equals(" == New == ")) {
    // opting to make a new scene by picking this, rather than clicking the 'new' button.
      new_scene = "new";
  }

  if(current_scene.equals(new_scene)) {

    println("No change in current scene.  Not loading.");
    return;

  }

  current_scene = new_scene;
  osc_new_scene = new_scene;

  // do not load scene if Meander is asleep:
  if(!sleepmode) load_scene(current_scene);
}


void pick_scene_from_picker(String new_scene) {

    List scenelist = gui.which_scene.getItems();

    int picked = -1;

    for (int i = 0; i < scenelist.size() ; i++) {
        if(gui.which_scene.getItem(i).get("text").equals(new_scene)) picked = i;
    }

    if(picked != -1) {
       gui.which_scene.setValue(picked);  // this will trigger the callback and change scenes.
    } else {
      // a scene name was sent that I don't recognize...
       println("Trying to pick scene " + new_scene + " but I don't know it... ");
    }

}


/*!
 *  \fn save_cam_settings()
 *  \brief saves the default camera view and view sets for this .csv
 *  \return none
 */
void save_cam_settings() {

  println("Saving current view as default");

 // first save current view settings as default (using cam fields from vgui - defined as a 'property set')
  String fn = new String(( "data/" + file_name  + "/cam_settings"));
  println("Saving camera settings to " + fn );
  gui.vgui.saveProperties(fn, "cam_set");

  save_view_settings();

}

void save_view_settings() {

 // now save the array of views using serialized array object in java

  println("Saving stored views to file");

  try {

  FileWriter fw = new FileWriter(sketchPath() + "/data/" + file_name + "/view_settings.json");
  gson.toJson(views, fw);  
  fw.flush(); fw.close();

 } catch(IOException e) {
   println(" Exception saving camera views: " + e);
 }

}

/*!
 *  \fn save_show_control_settings()
 *  \brief saves the default camera view and view sets for this .csv
 *  \return none
 */
void save_show_control_settings() {

  println("Saving current show_control settings as default");

  String fn = new String("data/" + file_name + "/show_control_settings");
  println("Saving show_control settings to " + fn );
  gui.vgui.saveProperties(fn, "show_control_set");

  gui.show_control_save.setCaptionLabel("");
  gui.show_control_save.setColorBackground(color(9, 42, 92));


}

void save_scene_gui(int n) {
  save_scene();
}

void save_scene_as_gui() {
  save_scene_as();
}

void new_scene_gui() {

  /// make a new scene by directly setting the scene selector to 'new'.
  pick_scene_from_picker(" == New == ");

}

void save_scene() {

  if(sleepmode) {
   println("Shouldn't save a scene while asleep!  Not saved.");
   return;
  }

  if(current_scene == "new") {
    println(" Need a new filename for this scene... ");
    save_scene_as();
    return;
  }

  save_scene(current_scene);

}

void save_scene_as() {

  // here we ask for input then we save as that.
  // String fn = "new";

   gui.saveinput.setVisible(true);
   gui.saveinput.setLabelVisible(true);
   gui.saveinput.setFocus(true);

  // save_scene(fn);

}

void save_scene_input_gui(String name) {

  gui.saveinput.setVisible(false);
  gui.saveinput.setLabelVisible(false);
  gui.saveinput.setFocus(false);

  println(" Did I get a: " + name + "?");

  if(name.equals("new")) {
    println(" Can't name your new scene 'new' - try again.");
    return;
  }

  // current_scene = name;
  // osc_new_scene = name;
  save_scene(name);
  // need to rebuild picker here?
  println(" Clearing picker... ");
  gui.which_scene.clear();
   // firstpick_scene = true;
  println(" Refreshing picker list from disk... ");
  List l = gui.get_scene_list();
  println(" Building picker... ");
  gui.which_scene.addItems(l);

  println(" Telling DAT to refresh presets");
  for(HashMap.Entry<String, Object> beh : behaviourEngineSettings.entrySet()) {
    if(((BehaviourEngineVars)beh.getValue()).neverSave) continue;
     println("Requesting refresh of presets for " + ((BehaviourEngineVars)beh.getValue()).behaviourName + " via OSC then switch to " + name);
     send_gui_OSC(((BehaviourEngineVars)beh.getValue()).behaviourName, "reloadPresetList", name, "");
  }

   println(" picking scene... " + name);
   pick_scene_from_picker(name);

}

void save_scene(String scene_name) {

  // Save acutator maps 
  save_actuator_influence_maps(scene_name);

  // Save sensor settings
  // TBD

  save_grideye_settings(scene_name);
  save_sd_settings(scene_name);
  save_ir_settings(scene_name);

  // Save behaviour settings

  for(HashMap.Entry<String, Object> beh : behaviourEngineSettings.entrySet()) {
    if(((BehaviourEngineVars)beh.getValue()).neverSave) continue;
       ((BehaviourEngineVars)beh.getValue()).save(scene_name);
  }


  // also save vector field:
  // flowField_NR.save(scene_name);
  // flowField_SR.save(scene_name);
}

void load_scene() {
  load_scene("default");
}
void load_scene(String scene_name) {


  // Load Actuator Maps
  load_actuator_influence_maps(scene_name);

  // Load Sensor Settings
  load_grideye_settings(scene_name);
  load_ir_settings(scene_name);
  load_sd_settings(scene_name);

  // Load behaviour settings
  for(HashMap.Entry<String, Object> beh : behaviourEngineSettings.entrySet()) {
    if(((BehaviourEngineVars)beh.getValue()).neverSave) continue;

  //  if(!scene_name.equals("default")) {   // ping the server to tell it to switch, it will call "load" on its own.
       
     println("Switching " + ((BehaviourEngineVars)beh.getValue()).behaviourName + " to " + scene_name + " via OSC");
     swap_preset_OSC(((BehaviourEngineVars)beh.getValue()).behaviourName, scene_name);

   // } else { /// first time?  let's do it this way
   //    if( ((BehaviourEngineVars)beh.getValue()).load(scene_name) ) {
   //        ((BehaviourEngineVars)beh.getValue()).presetchanged = true;
   //    }
   // } 
  }

  // also load baseline vector field:
  // flowField_NR.load(scene_name);
  // flowField_SR.load(scene_name);

}



/*!
 *  \fn save_sd_settings()
 *  \brief saves all sd settings in JSON format
 *  \return none
 */
void save_sd_settings() {

     save_sd_settings("default");

}

void save_sd_settings(String scene_name) {

   println("Saving current sd settings as " + scene_name);

   JSONObject sd_settings = new JSONObject();

   for(Node n : dl.nodes.values()) {
     if(n != null) {
       JSONObject node_sds = n.get_sd_settings_json();
       if(node_sds != null) {                                   // skip nodes with no sds
        sd_settings.setJSONObject(str(n.node_id), node_sds);
       }
     }
   }

   String fn = new String("data/" + file_name + "/sd_settings_"+ scene_name + ".json");
   saveJSONObject(sd_settings, fn);

}



/*!
 *  \fn save_ir_settings()
 *  \brief saves all ir settings in JSON format
 *  \return none
 */
void save_ir_settings() {

     save_ir_settings("default");

}

void save_ir_settings(String scene_name) {

   println("Saving current ir settings as " + scene_name);

   JSONObject ir_settings = new JSONObject();

   for(Node n : dl.nodes.values()) {
     if(n != null) {
       JSONObject node_irs = n.get_ir_settings_json();
       if(node_irs != null) {                                   // skip nodes with no irs
        ir_settings.setJSONObject(str(n.node_id), node_irs);
       }
     }
   }

   String fn = new String("data/" + file_name + "/ir_settings_"+ scene_name + ".json");
   saveJSONObject(ir_settings, fn);

}


/*!
 *  \fn save_grideye_settings()
 *  \brief saves all grideye settings in JSON format
 *  \return none
 */
void save_grideye_settings() {

     save_grideye_settings("default");

}

void save_grideye_settings(String scene_name) {

   println("Saving current grideye settings as " + scene_name);

   JSONObject ge_settings = new JSONObject();

   for(Node n : dl.nodes.values()) {
     if(n != null) {
       JSONObject node_ges = n.get_grideye_settings_json();
       if(node_ges != null) {                                   // skip nodes with no grideyes
        ge_settings.setJSONObject(str(n.node_id), node_ges);
       }
     }
   }

   String fn = new String("data/" + file_name + "/grideye_settings_"+ scene_name + ".json");
   saveJSONObject(ge_settings, fn);

}



/*!
 *  \fn load_sd_settings()
 *  \brief loads all sd settings in JSON format
 *  \return none
 */
void load_sd_settings() {

     load_sd_settings("default");

}

void load_sd_settings(String scene_name) {

   JSONObject sd_settings = new JSONObject();

   String fn = new String("data/" + file_name + "/sd_settings_"+scene_name+".json");
   println("Loading current sd settings from "+ fn +" into DL config strings");



   try {
      sd_settings = loadJSONObject(fn);
   } catch(Exception e) {

    println("Exception loading sd settings: " + e);

   }

   if(sd_settings == null) return;

   for(Node n : dl.nodes.values()) {
     if(n != null) {
       JSONObject node_sd_set = sd_settings.getJSONObject(str(n.node_id));

       if(node_sd_set != null) {

        for (int i = 0 ; i < n.my_sound_detectors.length ; i++ ) {
          if(n.my_sound_detectors[i] == null || !n.my_sound_detectors[i].installed) continue;

          String sd_name   = n.my_sound_detectors[i].name;
          String sd_config = node_sd_set.getString(sd_name);
          
          // INSTEAD, loading into the DL config string list, so that they are persistent if nodes lost and found.
          dl.set_device_config(n.node_id, sd_name, sd_config);

          // now, tell the SD's PI to send config messages for all SDs:
          dl.find_nodes_parent_rpi(n.node_id).send_device_configs(n.node_id, "SD");
        }
       }
     }
   }
}


/*!
 *  \fn load_ir_settings()
 *  \brief loads all sd settings in JSON format
 *  \return none
 */
void load_ir_settings() {

     load_ir_settings("default");

}

void load_ir_settings(String scene_name) {

   JSONObject ir_settings = new JSONObject();

   String fn = new String("data/" + file_name + "/ir_settings_"+scene_name+".json");
   println("Loading current ir settings from "+ fn +" into DL config strings");


   try {
      ir_settings = loadJSONObject(fn);
   } catch(Exception e) {

    println("Exception loading ir settings: " + e);

   }

   if(ir_settings == null) return;

   for(Node n : dl.nodes.values()) {
     if(n != null) {
       JSONObject node_ir_set = ir_settings.getJSONObject(str(n.node_id));

       if(node_ir_set != null) {

        for (int i = 0 ; i < n.my_ir_detectors.length; i++) {
          if(n.my_ir_detectors[i] == null || !n.my_ir_detectors[i].installed) continue;

          String ir_name   = n.my_ir_detectors[i].name;
          String ir_config = node_ir_set.getString(ir_name);
          
          // INSTEAD, loading into the DL config string list, so that they are persistent if nodes lost and found.
          dl.set_device_config(n.node_id, ir_name, ir_config);

          // now, tell the IR's PI to send config messages for all IRs:
          dl.find_nodes_parent_rpi(n.node_id).send_device_configs(n.node_id, "IR");
        }
       }
     }
   }
}



/*!
 *  \fn load_grideye_settings()
 *  \brief loads all grideye settings in JSON format
 *  \return none
 */
void load_grideye_settings() {

     load_grideye_settings("default");

}

void load_grideye_settings(String scene_name) {

   JSONObject ge_settings = new JSONObject();

   String fn = new String("data/" + file_name + "/grideye_settings_"+scene_name+".json");
   println("Loading current grideye settings from "+ fn +" into DL config strings");

   try {
      ge_settings = loadJSONObject(fn);
   } catch(Exception e) {

      println("Exception loading grideye settings: " + e);
      return;

   }

   if(ge_settings == null) return;

   for(Node n : dl.nodes.values()) {
     if(n != null) {
       JSONObject node_ge_set = ge_settings.getJSONObject(str(n.node_id));

       if(node_ge_set != null) {

        //  [ only one Grideye per node, so no need to iterate here, like we will for SDs and IRs]
        if(n.my_grideyes[0] == null || !n.my_grideyes[0].installed) continue;

        String ge_name   = n.my_grideyes[0].name;
        String ge_config = node_ge_set.getString(ge_name);
         
        // to set directly -- not doing this:
        // String ge_pi_addr = dl.find_nodes_parent_rpi(n.node_id).my_address;
        // network.write_message("/CONTROL/GE_CONFIG/" + control.my_address + "/" + ge_pi_addr + " " + ge_config );

        // INSTEAD, loading into the DL config string list, so that they are persistent if nodes lost and found.
        dl.set_device_config(n.node_id, ge_name, ge_config);

        // now, tell the GE's PI to send config messages for 'all' GEs:
        dl.find_nodes_parent_rpi(n.node_id).send_device_configs(n.node_id, "GE");

        // finally, set the GE background, because now is likely a good time.
        String ge_pi_addr = dl.find_nodes_parent_rpi(n.node_id).my_address;
        network.write_message("/CONTROL/GE_SET_BACKGROUND/" + control.my_address + "/" + ge_pi_addr + " ");

       }
     }
   }
}


/*!
 *  \fn save_actuator_influence_maps()
 *  \brief saves the current actuator_influence_maps in JSON format
 *  \return none
 */
void save_actuator_influence_maps() {

     save_actuator_influence_maps("default");

}


void save_actuator_influence_maps(String scene_name) {

   if(sleepmode) {

   println("Not saving influence maps because sleeping!");
   return;

   }

   println("Saving current actuator influence maps as " + scene_name);

   JSONObject actuator_inf_map = new JSONObject();

   for(Node n : dl.nodes.values()) {
     if(n != null) {
       actuator_inf_map.setJSONObject(str(n.node_id), n.get_actuator_inf_map_json());
     }
   }

   String fn = new String("data/" + file_name + "/actuator_influence_map_"+ scene_name + ".json");
   saveJSONObject(actuator_inf_map, fn);

}


/*!
 *  \fn load_actuator_influence_maps()
 *  \brief loads the actuator_influence_maps in JSON format
 *  \return none
 */

void load_actuator_influence_maps() {

     load_actuator_influence_maps("default");

}

void load_actuator_influence_maps(String scene_name) {

   JSONObject full_inf_map = new JSONObject();

   String fn = new String("data/" + file_name + "/actuator_influence_map_"+scene_name+".json");
   println("Loading current actuator influence maps from "+ fn);

   try {
   full_inf_map = loadJSONObject(fn);
   } catch(Exception e) {

    println("Exception loading inf map: " + e);

   }
   if(full_inf_map == null) return;

   for(Node n : dl.nodes.values()) {
     if(n != null) {
       JSONObject node_inf_map = full_inf_map.getJSONObject(str(n.node_id));

       if(node_inf_map != null) {
         n.set_actuator_inf_map_json(node_inf_map);

         // println("Simulating timeout situation here: ..." + n.node_id);
         // delay(4000);

         if(run_mode == LIVE) {
           sync_actuator_influence_maps(str(n.node_id));
         } 
       }
     }
   }

   println(" Done loading " + fn);
}


/*!
 *  \fn showcontrols()
 *  \brief MATT - TODO
 *  \return none
 */
void showcontrols() {

  gui.show_control.setVisible(true);
}

/*!
 *  \fn message_input_data(String t)
 *  \brief MATT - TODO
 *  \param t
 *  \return none
 */
void message_input_data(String t) {
  send_test_message();
}

/*!
 *  \fn message_input_code(String t)
 *  \brief MATT - TODO
 *  \param t
 *  \return none
 */
void message_input_code(String t) {
  send_test_message();
}

/*!
 *  \fn send_test_message()
 *  \brief MATT - TODO
 *  \return none
 */
void send_test_message() {

  message_OSC m = new message_OSC(gui.codeinput.getText().toUpperCase(), gui.datainput.getText().toUpperCase());

  String[] code_params = split(gui.codeinput.getText().toUpperCase(), '/');
  String   node_address = code_params[code_params.length-1];
  int      dest_address = Integer.parseInt(node_address);

  print("Sending -> ");
  print(m.get_code() + " ::: ");
  println(m.get_data());

  network.write_message(gui.codeinput.getText().toUpperCase() + " " + gui.datainput.getText().toUpperCase());
}



void launchGUI() {

  try {
  // exec("cd /Users/borogove2/Dropbox/PBAI/code/Browser_UI/Gaslight-OSC-Server");
  launch("node /Users/borogove2/Dropbox/PBAI/code/Browser_UI/Gaslight-OSC-Server/server.js");
  } catch(Exception e) {
    println("Exception: " +e );
  }

}


/*!
 *  \fn mouseMoved()
 *  \brief do something if the mouse is moved
 *  \return none
 */
void mouseMoved() {
  select_item = false;  // cancel a click that was not on an actuator
}

/*!
 *  \fn mouseDragged()
 *  \brief do something if the mouse is dragged
 *  \return none
 */
void mouseDragged() {
  if (!gui.vgui.isMouseOver()) {
    gui.update_cam_panel();
  }
  mouse_millis = millis();
}

/*!
 *  \fn mouseClicked()
 *  \brief do something if the mouse is clicked
 *  \return none
 */
void mouseClicked() {

  //  println("mouseover: " + gui.vgui.getWindow().getMouseOverList());

  if (!gui.my_isMouseOver())  gui.select();
}

/*!
 *  \fn mouseWheel()
 *  \brief do something if the mousewheel is moved
 *  \return none
 */
void mouseWheel() {
  gui.update_cam_panel();
}

/*!
 *  \fn mouseReleased()
 *  \brief do something if the mouse is released
 *  \return none
 */
void mouseReleased() {
  if (!gui.vgui.isMouseOver()) {
    gui.update_cam_panel();
  }

}



void mousePressed() {

    mouse_down.x = mouseX;
    mouse_down.y = mouseY;

    if(mouseButton == RIGHT) {
       gridRunner.toggleSource();
    }
}



/*!
 *  \fn initialize_osc(int port)
 *  \brief create the internal osc port and setup, called from comm manager
 *  \param port the port number to create the internal osc on
 *  \return none
 */
void initialize_osc(int port) {
  internal_comms = new OscP5(this, port);
  //println("internal OSC Listener @: " + this + " On Port: " + port);
}

/*!
 *  \fn initialize_external_osc(int port)
 *  \brief create the external osc port and setup, called from external comm manager
 *  \param port the port number to create the external osc on
 *  \return none
 */
void initialize_external_osc(int port) {
  external_osc = new OscP5(this, port);
  //println("external OSC Listener @: " + this + " On Port: " + port);
}

/*!
 *  \fn oscEvent(OscMessage received_message)
 *  \brief oscEvent triggered whenever an osc message reaches this computer. This function sorts the messages according to content and forwards it to the appropriate class.
 *  \param received_message the message received
 *  \return none
 */
synchronized void oscEvent(OscMessage received_message) {

//// July 2020 slowly replacing all the custom messaging with the OSC + JSON + GSON system
//// to automatically create hooks for ANY variable in an influence engine.


  if (received_message.addrPattern().contains("serverMessageDatSetting")) {
    oscIn_datGuiSetting(received_message);
    return;
  }

  if (received_message.addrPattern().contains("serverMessageDatCommand")) {
    oscIn_datGuiCommand(received_message);
    return;
  }

  if (received_message.addrPattern().contains("serverMessagePatcher")) {
    oscIn_patcherCommand(received_message);
    return;
  }




/////////  OLD (pre-July 2020) functions below, still work.




  //If statements here would be important to redirect to the correct external comms object

  /*
  If the Osc addresses contain a behaviour name, then these messages are forwarded
  to OSC_behaviours.pde, and split across osc functions for each behaviour
  */
  // println("osc Message Recieved: " + received_message.addrPattern());

  if (received_message.addrPattern().contains("excitorBehaviour")) {
    oscIn_excitorBehaviour(received_message);
    return;
  } else if (received_message.addrPattern().contains("flowField")) {
  //  oscIn_flowField(received_message);
    return;
  } else if (received_message.addrPattern().contains("riverHead")) {
    oscIn_riverHead(received_message);
    return;
  } else if (received_message.addrPattern().contains("electricCells")) {
    oscIn_electricCells(received_message);
    return;
  } else if (received_message.addrPattern().contains("ambientWaves")) {
    oscIn_ambientWaves(received_message);
    return;
  } else if (received_message.addrPattern().contains("actuator")) {
    oscIn_actuators(received_message);
    return;
  } else if (received_message.addrPattern().contains("behaviourDebug")) {
    oscIn_behaviourDebug(received_message);
    return;
  } else if (received_message.addrPattern().contains("serverMessage")){
    oscIn_serverMessage(received_message);
    return;
  } else if (received_message.addrPattern().contains("sensorGestures")){
    oscIn_sensorGestures(received_message);
    return;
  } else if (received_message.addrPattern().contains("timelapse")){
    println("Time lapse message: " + received_message.addrPattern());
    oscIn_timeLapse(received_message);
    return;
  } else {
    network.osc_received(received_message);
    return;
  }
}


void dump_behaviour_settings_map() {

  println("REGISTERED BEHAVIOUR ENGINE SETTINGS:" );
  println("");

  for(HashMap.Entry<String, Object> beh : behaviourEngineSettings.entrySet()) {
    println(" * " + beh.getKey());
  }
  println("CHILD BEHAVIOURS:" );

  for(HashMap.Entry<String, Object> child : childBehaviourSettings.entrySet()) {
    println("   * " + child.getKey());
  }

}


/*!
 *  \fn keyPressed()
 *  \brief do something if a key is pressed, used for debugging and some GUI functions
 *  \return none
 */
void keyPressed() {


  
    if (key == TAB) {
      if ( gui.codeinput.isFocus() || gui.datainput.isFocus() ) {
      gui.codeinput.setFocus(!gui.codeinput.isFocus());
      gui.datainput.setFocus(!gui.datainput.isFocus());
      }
      else {
        // quick test of currenly selected actuator
        test_current_actuator = !test_current_actuator;
      }
    return;
  }

  if( gui.saveinput.isFocus() ) {  // prevent typing in name from affecting other shortcuts
    return;
  }


  if (key == '`') {
    println("Camera position: " + cam.getRotations()[0] + ", " + cam.getRotations()[1] + ", " + cam.getRotations()[2] + " ; distance: " + cam.getDistance() );
  } else if (key == '#') {
    // special key to freeze execution
    simulate_crash = !simulate_crash;
  }
    if (key == '~') {
    drawaxes = !drawaxes;
    // mouseClicked();
  } else if (key == '+') {
    gui.toggle_show_control();
  } else if (key == BACKSPACE) {
    control.kill_all_actuators();
//    control.subscribe_actuators(false);
  } else if ( key == 'G') {
    drawgui = !drawgui;
  } else if ( key == 't') {
    if(selected_actuator != null && selected_actuator.use_sai) {
       selected_actuator.my_sai.trigger();
    }
  } else if ( key == 'T') {
    if(selected_actuator != null && selected_actuator.use_sai) {
       selected_actuator.my_sai.reloadProfile();
    }
  } else if ( key == 'g') {
    control.grideye_presence_on = !control.grideye_presence_on;
  } else if (key == 'm' ) {
    drawmodel = (drawmodel+1)%3;
  } else if (key == 'b') {
    draw_bounding_boxes = !draw_bounding_boxes;
  } else if (key == 'B') {
    dump_behaviour_settings_map();
  } else if (key == 'f' || key == 'F') {
    billboard_mode = (billboard_mode+1)%3;
  } else if (key == 'w' || key == 'W') {
    if(selected_actuator != null) {
      ambientWaves.addWave(selected_actuator.name.substring(0,2));
    }
  } else if (key == 'a' || key == 'A') {
    // control.fade_wav_test = true;
  } else if (key == 'r' || key == 'R') {
    control.random_actuator_on = !control.random_actuator_on;
  } else if (key == 'p' || key == 'P') {
     gridRunner.pauseParticles(!gridRunner.ps.paused);
     println("Particles paused: " + gridRunner.ps.paused);
  } else if (key == '1') {
    control.message_send_ramp_up = true;
  } else if (key == '2') {
    control.message_send_ramp_down = true;
  } else if (key == '3') {
    control.sound_sensor_poll = true;
  } else if (key == '4') {
    control.turn_off_auto_sample = true;
  } else if (key == '5') {
    control.set_sampling_freq = true;
  } else if (key == '6') {
    control.influence_tester = true;
  } else if (key == '0') {
    control.kill_all_actuators();
  } else if (key == 's' || key == 'S') {
//    if (keyshift)    save_scene(current_scene); 
  } else if (key == 'l' || key == 'L') {
//    if (keyshift)    load_scene(current_scene); 
  } else if (key == 'M') {

     send_gui_OSC("GridRunner", "mouseSource", str(!gridRunnerVars.mouseSource));

  } else if (key == 'X' ) {   // move source

    gridRunner.fetchNearestSource();

  } else if (key == 'x' ) {   // clone or remove source

    gridRunner.toggleSource();
    
  } else if (key == 'z' ) {   // activate or deactivate source

     gridRunner.toggleSourceActive();

    
  } else if (key == 'd' || key == 'D') {
    network.debug = !network.debug;
  } else if (key == ' ') {
    mute_messages = !mute_messages;
    if(mute_messages) println("MESSAGES OFF"); else println("MESSAGES ON");
  } 

  float roll_adj = PI/40;
  if (keyshift) roll_adj *=0.25;

  if (key == CODED) {
    if (keyCode == SHIFT) {
      keyshift = true;
    }
    if (keyCode == ALT) {
      keyalt = true;
    }

    if (gesim && prerecorded) {

    if (keyCode == RIGHT) {
      ge.rec_x_offset++;
      ge.cur_ge.setBackground = true;
    } else if (keyCode == LEFT) {
      ge.rec_x_offset--;
      ge.cur_ge.setBackground = true;
    } else if (keyCode == UP) {
      ge.rec_y_offset--;
      ge.cur_ge.setBackground = true;
    } else if (keyCode == DOWN) {
      ge.rec_y_offset++;
      ge.cur_ge.setBackground = true;
    } 
     
      return;
    }

    if (drawmodel == 2) {
      if(!keyalt) {
   if (keyCode == RIGHT) {
      model_offset_X+=100;
      println("Model Offset X: " + model_offset_X);
    } else if (keyCode == LEFT) {
      model_offset_X-=100;
      println("Model Offset X: " + model_offset_X);
    } else if (keyCode == UP) {
      if(!keyshift) {
      model_offset_Y+=100;
      println("Model Offset Y: " + model_offset_Y);
      } else {
      model_offset_Z+=100;
      println("Model Offset Z: " + model_offset_Z);
      }
    } else if (keyCode == DOWN) {
      if(!keyshift) {
      model_offset_Y-=100;
      println("Model Offset Y: " + model_offset_Y);
      } else {
      model_offset_Z-=100;
      println("Model Offset Z: " + model_offset_Z);
      }
    } 
      } else {  // alt is pressed:
   if (keyCode == RIGHT) {
      model_rot_X+=PI/36;
      println("Model Rotate X: " + model_rot_X);
    } else if (keyCode == LEFT) {
      model_rot_X-=PI/36;
      println("Model Rotate X: " + model_rot_X);
    } else if (keyCode == UP) {
      if(!keyshift) {
      model_rot_Y+=PI/36;
      println("Model Rotate Y: " + model_rot_Y);
      } else {
      model_rot_Z+=PI/36;
      println("Model Rotate Z: " + model_rot_Z);
      }
    } else if (keyCode == DOWN) {
      if(!keyshift) {
      model_rot_Y-=PI/36;
      println("Model Rotate Y: " + model_rot_Y);
      } else {
      model_rot_Z-=PI/36;
      println("Model Rotate Z: " + model_rot_Z);
      }
    }
      }
      return;
    }

    if (keyCode == UP) {
          control.influence_frame_time+=5;

      // cam.setRotations(cam.getRotations()[0]-roll_adj, 
      //   cam.getRotations()[1], 
      //   cam.getRotations()[2]);
    }
    if (keyCode == DOWN) {
         control.influence_frame_time-=5;
         if (control.influence_frame_time <= 15)
           control.influence_frame_time = 15;
      // cam.setRotations(cam.getRotations()[0]+roll_adj, 
      //   cam.getRotations()[1], 
      //   cam.getRotations()[2]);
    }
    if (keyCode == LEFT) {
      //    control.burst_size-=10;


        cam.setRotations(cam.getRotations()[0], 
        cam.getRotations()[1], 
        cam.getRotations()[2]-roll_adj);
    
    }
    if (keyCode == RIGHT) {
      //    control.burst_size+=10;
            if(keyshift) {
            gridRunnerVars.sourceRotation++;
            gridRunnerVars.sourceRotation%=3;
            send_gui_OSC("GridRunner", "sourceRotation", str(gridRunnerVars.sourceRotation));
            println("Source Rotation: " + gridRunnerVars.sourceRotation);
          } else {
      cam.setRotations(cam.getRotations()[0], 
        cam.getRotations()[1], 
        cam.getRotations()[2]+roll_adj);
          }
    }
  }

  if (key==']') { 
    actuator_test_distance += 15; 
    if(actuator_test_distance > 250) actuator_test_distance = 250; 
    }
  if (key=='[') { 
    actuator_test_distance -= 15; 
    if(actuator_test_distance < 20 ) actuator_test_distance = 20;  
    }
  if (key=='|') {
    actuator_test_type = "VECTORS";
  } else
  if (key=='\\') {
    Set<String> types = new HashSet<String>(dl.get_all_actuator_types());  // put unique types into a set
    ArrayList<String> t = new ArrayList<String>(types);                    // convert the set back to a list
    String old_act_type = actuator_test_type;
    int cur = t.indexOf(actuator_test_type);
    cur++;
    if(cur == t.size()) {
      actuator_test_type = "ALL";
    } else {
      actuator_test_type = t.get(cur);
    }
//    println(" cur is " + cur + " and t is " + t.toString());
    println(" testing " + actuator_test_type + "");
    cam.setMouseControlled(true);  // turn this back on in case it was off for adjusting vectors
  }
/*
  if (key=='!') excitorBehaviour.attractorForce = 0.1;
  if (key=='@') excitorBehaviour.attractorForce = 1;
  if (key=='#') excitorBehaviour.attractorForce = 5;
  if (key=='$') excitorBehaviour.attractorForce = 10;
  if (key==')') excitorBehaviour.attractorForce = 0;
*/
  if (key=='e') {
    excBehavVars.showExcitors   = !excBehavVars.showExcitors;
  }
  if (key=='a') excBehavVars.showAttractors = !excBehavVars.showAttractors;
  if (key=='E') {
    /// ask the gridRunner behaviour to kindly see if one of its
    //  particleSources might be willing to spit out an Excitor for me.
    gridRunner.requestExcitor();

  }
  if (key=='Q') excitorBehaviour.excitorSystem.addExcitor(new PVector(0, 0, 0), excBehavVars.size*2);   // generate Excitor at Origin
}


/*!
 *  \fn keyReleased()
 *  \brief do something if a key is released
 *  \return none
 */
void keyReleased() {

  gui.update_cam_panel();

  if (key == CODED) {
    if (keyCode == SHIFT) {
      keyshift = false;
    }
    if (keyCode == ALT) {
      keyalt = false;
    }
  }
}

/*!
 *  \fn draw_axes()
 *  \brief draw the axes
 *  \return none
 */
void draw_axes() {

  if(!drawaxes) return;

  strokeWeight(2);
  // draw axes
  stroke(255, 0, 0, 30);
  line(-400, 0, 0, 400, 0, 0);  // x is red
  stroke(0, 255, 0, 30);
  line(0, -400, 0, 0, 400, 0);  // y is green
  stroke(0, 0, 255, 30);
  line(0, 0, -400, 0, 0, 400);  // z is blue

  strokeWeight(1);
}

void draw_model() {

   if(drawmodel == 0) return;

   pushMatrix();
     translate(model_offset_X, model_offset_Y, model_offset_Z);
     scale(1.15, 1.15, 1.15);
     rotateX(0);
     rotateY(-PI/2);
     rotateZ(PI/2 );
     rotateX((PI/36)       + model_rot_X);
     rotateY((59 * PI/36)  + model_rot_Y);
     rotateZ(0             + model_rot_Z);
     noFill();

    hint(DISABLE_DEPTH_TEST);
    if(drawmodel == 2) {
      hint(ENABLE_DEPTH_TEST);
      lights();
    } else {
      ambientLight(145, 145, 165);
    }

//    shape(fsphere);
    shape(meander);

    popMatrix();
    noLights();
    hint(ENABLE_DEPTH_TEST);

}

/*!
 *  \fn draw_grid()
 *  \brief draw the grid
 *  \return none
 */
void draw_grid() {
  draw_grid(grid_spacing, floor_height);

  /// overload the grid by drawing any input from paintbrush_osc:
  if(paintbrush_osc) {

      strokeWeight(2);
      stroke(255, 128, 0);
      noFill();

      pushMatrix();
      translate(paintbrush_osc_offsets.x+(paintbrush_osc_params.x*paintbrush_osc_offsets.z), 
                paintbrush_osc_offsets.y+(paintbrush_osc_params.y*paintbrush_osc_offsets.z*1.337), 1600); // extra 1.337 in y to make up for aspect ratio of image
      ellipse(0, 0, 0.5*paintbrush_osc_offsets.z * paintbrush_osc_params.z, 0.5*paintbrush_osc_offsets.z * paintbrush_osc_params.z);
      translate(0, 0, -150);
      stroke(255, 128, 0, 128);
      ellipse(0, 0, 0.5*paintbrush_osc_offsets.z * paintbrush_osc_params.z, 0.5*paintbrush_osc_offsets.z * paintbrush_osc_params.z);
      translate(0, 0, -150);
      stroke(255, 128, 0, 64);
      ellipse(0, 0, 0.5*paintbrush_osc_offsets.z * paintbrush_osc_params.z, 0.5*paintbrush_osc_offsets.z * paintbrush_osc_params.z);
      popMatrix();

      strokeWeight(1);

  }
}

/*!
 *  \fn draw_grid(int spacing, int h)
 *  \brief draw the grid
 *  \param spacing the spacing of the grid
 *  \param h the height
 *  \return none
 */
void draw_grid(int spacing, int h) {

  for (int i = 0-grid_extent; i < grid_extent; i += spacing) {

    strokeWeight(.4);
    stroke(0, 20);
    if (i % (5*spacing) == 0) stroke(0, 20);

    line (0-grid_extent, i, 0-h, 
      grid_extent, i, 0-h);
    line (i, 0-grid_extent, 0-h, 
      i, grid_extent, 0-h);
  }
  strokeWeight(1);
}

/*!
 *  \fn get_frame()
 *  \brief get the current frame
 *  \return an integer of the frame
 */
synchronized int get_frame() {
  return frame;
}

/*!
 *  \fn increment_frame()
 *  \brief increment the frame
 *  \return none
 */
synchronized void increment_frame() {
  frame++;
}





/*!
 *  \fn cam_lookat_x(float _x)
 *  \brief MATT - TODO
 *  \param _x
 *  \return none
 */
synchronized void cam_lookat_x(float _x) {
  if (cam != null)
    cam.lookAt(_x, cam.getLookAt()[1], cam.getLookAt()[2]);
}

/*!
 *  \fn cam_lookat_y(float _y)
 *  \brief MATT - TODO
 *  \param _y
 *  \return none
 */
synchronized void cam_lookat_y(float _y) {
  if (cam != null)
    cam.lookAt(cam.getLookAt()[0], _y, cam.getLookAt()[2]);
}

/*!
 *  \fn cam_lookat_z(float _z) 
 *  \brief MATT - TODO
 *  \param _z
 *  \return none
 */
synchronized void cam_lookat_z(float _z) {
  if (cam != null)
    cam.lookAt(cam.getLookAt()[0], cam.getLookAt()[1], _z);
}


/*!
 *  \fn cam_distance(float _d) 
 *  \brief MATT - TODO
 *  \param _d
 *  \return none
 */
synchronized void cam_distance(float _d) {
  if (cam != null)
    cam.setDistance(_d);
}

// =============== helpful math function for quick distances (no sqrt)

float distSq(float x1, float y1, float x2, float y2) {

  return( sq(x1-x2) + sq(y1-y2) );

}

float distSq(float x1, float y1, float z1, float x2, float y2, float z2) {

  return( sq(x1-x2) + sq(y1-y2) + sq(z1-z2) );

}

float distSq(PVector v1, PVector v2) {

  return( sq(v1.x-v2.x) + sq(v1.y-v2.y) + sq(v1.z-v2.z) );

}




// ================================  show control gui functions
/*!
 *  \fn controlEvent(ControlEvent theEvent)
 *  \brief MATT - TODO
 *  \param theEvent
 *  \return none
 */
void controlEvent(ControlEvent theEvent) {
  try {

    /* events triggered by controllers are automatically forwarded to
     the controlEvent method. by checking the id of a controller one can distinguish
     which of the controllers has been changed.
     */

    // make it so that opening Pre-Recorded or Simulation closes the other.
    if(!theEvent.isController()) {

      if(theEvent.getName().equals("GridEye: Pre-Recorded")) {
        if(gui.grp_prerec.isOpen()) gui.grp_simulation.close();
      }
      if(theEvent.getName().equals("GridEye: Simulation")) {
        if(gui.grp_simulation.isOpen()) gui.grp_prerec.close();
      }
    
//      println(theEvent.getName());
      return;
    }

   
   
    // println(" event:  "+ theEvent.getController().getName() + " id: " + theEvent.getController().getId());

   
   
    if (theEvent.getController().getId() < 100) return;

    //  IPAD GUI CONTROLLER EVENTS ARE ALL NUMBERED OVER 100

    // println("got a control event from controller with id "+theEvent.getController().getId());

    Controller c = theEvent.getController();

    switch(c.getId()) {
      case(101):   // Save

      println(" SAVE button ");
      
    
      break;
      case(102):   // SLEEP / WAKE

      println(" SLEEP / WAKE button ");
      show_control_awake = !show_control_awake;
      c.setCaptionLabel((show_control_awake==true) ? " SLEEP ":" WAKE ");

      if(!show_control_awake)  control.go_to_sleep();
      else                     control.wake_up();
    
      //control.excitorEngineState(show_control_awake);
      
      
      break;
      case(103):   // MUTE / UNMUTE

      println(" MUTE / UNMUTE button ");
      show_control_muted = !show_control_muted;


      c.setCaptionLabel((show_control_muted==true) ? " UNMUTE ":" MUTE ");

      if (show_control_muted) {

        excitorBehaviour.omniMasterVolume = 0.0;
        set_wt_master_gain(0);

        gui.show_control_vol1.setColorBackground(color(90, 90, 90));
        gui.show_control_vol2.setColorBackground(color(90, 90, 90));
      } else {

        excitorBehaviour.omniMasterVolume = show_control_vol_omni;
        set_wt_master_gain(int(show_control_vol_wt * 80));

        gui.show_control_vol1.setColorBackground(color(9, 42, 92));
        gui.show_control_vol2.setColorBackground(color(9, 42, 92));
      }


      break;

      case(199):  // sync with ableton

      requestAllValuesFromAbleton();

      break;

      case(104):   // VOL Omni

      show_control_vol_omni = (c.getValue() / 100.0);

      if (!show_control_muted && !sleepmode) {
        excitorBehaviour.omniMasterVolume = show_control_vol_omni;
      } 

      gui.show_control_save.setCaptionLabel("SAVE");
      gui.show_control_save.setColorBackground(color(92, 42, 9));


      break;
      case(105):   // VOL WT

      show_control_vol_wt   = (c.getValue() / 100.0);

      if (!show_control_muted) {
        set_wt_master_gain(int(show_control_vol_wt * 80));
      }

      gui.show_control_save.setCaptionLabel("SAVE");
      gui.show_control_save.setColorBackground(color(92, 42, 9));


      break;

      case(135):   // presence sensor sensitivity

      show_control_presence_sensitivity = (c.getValue() / 100.0);

      excitorBehaviour.presenceSensitivity = show_control_presence_sensitivity;
      
      gui.show_control_save.setCaptionLabel("SAVE");
      gui.show_control_save.setColorBackground(color(92, 42, 9));


      break;

      case(136):   // sd sensitivity

      show_control_sd_sensitivity = (c.getValue() / 100.0);

      excitorBehaviour.sdSensitivity = show_control_sd_sensitivity;
      
      gui.show_control_save.setCaptionLabel("SAVE");
      gui.show_control_save.setColorBackground(color(92, 42, 9));


      break;


      case(106):   // TIMER

      // println("timer is " + c.getValue() );

      show_control_use_timer = (c.getValue()==1.0);

      if(!show_control_use_timer && show_control_awake && sleepmode) {
          control.wake_up();
      }


      gui.show_control_hour_from.setColorBackground((show_control_use_timer==true) ? color(9, 42, 92) : color(90));
      gui.show_control_min_from.setColorBackground((show_control_use_timer==true) ? color(9, 42, 92) : color(90));
      gui.show_control_hour_to.setColorBackground((show_control_use_timer==true) ? color(9, 42, 92) : color(90));
      gui.show_control_min_to.setColorBackground((show_control_use_timer==true) ? color(9, 42, 92) : color(90));

      gui.show_control_save.setCaptionLabel("SAVE");
      gui.show_control_save.setColorBackground(color(92, 42, 9));

      break;
      case(107):   //  HR from
      show_control_start_hour = (int) gui.show_control_hour_from.getValue();
      gui.show_control_save.setCaptionLabel("SAVE");
      gui.show_control_save.setColorBackground(color(92, 42, 9));

      break;
      case(108):   //  min from
      show_control_start_minute = (int) gui.show_control_min_from.getValue();
      gui.show_control_save.setCaptionLabel("SAVE");
      gui.show_control_save.setColorBackground(color(92, 42, 9));

      break;

      case(109):   //  MMIN from
      show_control_stop_hour = (int) gui.show_control_hour_to.getValue();
      gui.show_control_save.setCaptionLabel("SAVE");
      gui.show_control_save.setColorBackground(color(92, 42, 9));

      break;

      case(110):   //  MMIN to
      show_control_stop_minute = (int) gui.show_control_min_to.getValue();
      gui.show_control_save.setCaptionLabel("SAVE");
      gui.show_control_save.setColorBackground(color(92, 42, 9));

      break;
      case(111):   //  launch test panel

      gui.show_control_test_panel.setVisible(true);

      break;

      case(112):
      gui.show_control_test_1_running = !gui.show_control_test_1_running;
      break;

      case(113):
      gui.show_control_test_2_running = !gui.show_control_test_2_running;
      break;
      case(114):
      gui.show_control_test_3_running = !gui.show_control_test_3_running;
      break;

      case(120):   //  launch test panel

      gui.show_control_test_panel.setVisible(false);

      break;
    }
  }
  catch(Exception e) {

    // println("exception here:  "  + e );
  }
}


/// new helper function to acommodate timelapse on millis() calls
int tl_millis() {

  if(time_lapse && time_lapse_pause > 0.0) {
    return (int(millis() / time_lapse_pause));  // this should slow everything down
  } else {
    return (millis());
  }

}

/*!
 *  \fn set_wt_master_gain(int vol)
 *  \brief Sets the master gain of the wav triggers on boot
 *  \param vol the volume to set the mastergain to
 *  \return none
 */
void set_wt_master_gain(int vol) {
  if(vol==cur_wt_master_gain) return;

  cur_wt_master_gain = vol;

  ArrayList<Integer> nodes = dl.get_node_type_ids("HU");
  for (Node n : dl.nodes.values()) {
    for (int i = 0; i < n.my_wav_triggers.length; i++ ) {

      if (n.my_wav_triggers[i].installed) {
        // println("setting volume for " + n.my_wav_triggers[i].name + " to " + (show_control_vol_wt) );

        message_OSC m = new message_OSC("/CONTROL/WAV_MASTER_GAIN/"+ control.my_address + "/" + n.node_id, "WT" + (n.my_wav_triggers[i].designator.device_number+1) + " " + vol);
        int      dest_address = n.node_id;

        print(" -> ");
        print(m.get_code() + " ::: ");
        println(m.get_data());

        network.write_message("/CONTROL/WAV_MASTER_GAIN/"+ control.my_address + "/" + n.node_id + " WT" + (n.my_wav_triggers[i].designator.device_number+1) + " " + vol);
      }
    }
  }
}

/*!
 *  \fn exit()
 *  \brief Exit sequence, kill all actuators then exit program
 *  \return none
 */
void exit()
{

  println("Exiting - going to try to exit cleanly by killing all actuators.");

  println("Disarming control watchdog timer...");
  monitor.setWatchdog("false");

  println(System.getProperty("java.version"));

  try {
    control.kill_all_actuators();
  } catch (NullPointerException e) {
    println("Control was not initialized, this is probably because Control's IP address is not in the CSV and the program had to quit");
  } catch (Exception e) {
    println("Some exception happened when trying to kill all actuators, no worries, still exiting... ");
  }
  super.exit();
}
