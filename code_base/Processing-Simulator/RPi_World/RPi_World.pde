/*! 
 <h1> RPi_World </h1>
 Setup class that runs the main loop for the rpis
 
 \author Matt Gorbet, et al.
 
 */

/*!  \var frame
 *  the current frame
 */
int frame = 0;

/*!  \var scale
 */
int scale = 10;


import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Arrays;
import processing.serial.*;
import controlP5.*;
import oscP5.*;
import netP5.*;

/*!  \var internal_comms
 *  the internal comms osc messager
 */
OscP5 internal_comms;

ControlP5 pigui;
JSONObject json;

//Chart queueChart;

// grideye variables that need to be here to be set directly with GUI
GridEye_Analyzer ge;
boolean gesim = false;
boolean firstpick     = true;
int     frameskip = 3;
float   interestThreshold = 1000.0;
float   noiseThreshold = 0.3;
float   overall_relax = 0.8;
boolean prerecorded = false;                                 // don't set it here - use the GUI


/*!  \var elapsed_millis
 *  time keeping variable
 */
long elapsed_millis = 0;
/*!  \var last_millis
 *  time keeping variable
 */
long last_millis = 0;

PFont gill; 
int textheight = 18;
int textoffset = 35;

// int message_count_this_frame = 0;


int canvasw = 600;
int canvash = 600;

/*!
 * set framerate of the sketch
 */
int framerate = 1000000000;
/*!
 * is hacked field, displays message at run time if it is hacked
 */
boolean hacked = true;

/*!
 * description of the hack
 */
String hacked_description = "Control has the if statement in get_message_real commented out";

/*!
 * Tells the world builder if this is a rpi or a computer pretending to be an rpi. Used for debugging mainly. True means this is a pi, false means it isn't.
 */
boolean is_a_pi = true; // set to false if the code is being run on a computer

/*!
 * Use the grideye, true for yes, false for no
 */
boolean use_grideye = true;

Integer grideye_ID = 999999;  // <-- hack to see which one is the GridEye

/*!
 * teensy port designator on rpis
 */
String teensy_port_code = "/dev/ttyACM";

/*!
 * default setting of csv, but its now set in the options.json
 */
String file_name = "default";
/*!
 * selects the csv
 */
String csv_select = "../Device_Locator_CSVs/" + file_name + ".csv"; // set in options.json now


/*!
 *  \var network
 *  The internal comms network
 */
public Comm_Manager network;

/*! \var monitor
 *  monitor class for RPis - deals with pings and heartbeats
  */
public Monitor monitor;

/*!
 *  \var setup_ports
 *  The serial port array, used by comms manager to setup hashmap
 */
// public Serial[] setup_ports = new Serial[Serial.list().length];
public ArrayList<Serial> setup_ports = new ArrayList<Serial>();

/*!
 *  \var my_rpi
 *  The rpi object instance for this real rpi
 */
RPi my_rpi;

/*!
 *  \var dl
 *  The device locator instance
 */
DeviceLocator dl;

/*!
 *  \var baud_rate
 *  Baud rate to communicate over Serial, default to 57600. Needs to be the same here as on the Node
 */
int baud_rate = 57600;

/*!
 *  \fn setup()
 *  \brief setup function that initializes the sketch. Loads json configurations, communication ports and kicks off threads
 *  \return none
 */
void setup() {
  json = loadJSONObject("../options.json");
  if (json.getString("file_name") != null)
    file_name = json.getString("file_name");
  csv_select = "../Device_Locator_CSVs/" + file_name + ".csv";

  if (!is_a_pi)
    teensy_port_code = "/dev/tty.usbmodem"; //"COM64", windows has COM, mac has another format;

  //cam  = new PeasyCam(this, 0, 0, 0, 1200);

  pigui = new ControlP5(this);

  dl = new DeviceLocator(csv_select);
  network = new Comm_Manager(dl);
  my_rpi = new RPi(network.my_address, network.my_address);
  monitor = new Monitor();

  // register nodes with monitor (skip Grideyes)
  Integer[] all_node_ids = dl.get_node_ids();
  for (int i = 0 ; i < all_node_ids.length ; i++) {
    Integer id = all_node_ids[i];
    if(!dl.get_node_type(id).equals("GN") && dl.get_node_parent_pi(id).equals(network.my_address)) {
      monitor.add_node_to_map(str(id));
    }   
  }


  if (use_grideye) {
    ge = new GridEye_Analyzer(this);
  }

  serial_node_setup();
  network.rpi_build_real_node_map();

  // now that map is built, send config strings to nodes:
  if(network.map_built) {

    for(int id : network.my_pis_node_port.keySet()) { 
      my_rpi.send_device_configs(id); 
    }

  }


  ////// make chart and other gui elements

  //USED FOR TESTING
  //queueChart = pigui.addChart("Queue Listener")
  //  .setPosition(50, 25)
  //  .setSize(200, 50)
  //  .setRange(0, 300)
  //  .setView(Chart.LINE) // use Chart.LINE, Chart.PIE, Chart.AREA, Chart.BAR_CENTERED
  //  .setStrokeWeight(1.5)
  //  .setColorBackground(color(0, 100))
  //  .setColorForeground(color(255, 100))
  //  ;

  //queueChart.addDataSet("queue_values");
  //queueChart.setData("queue_values", new float[100]);

  println("=============CONFIG===================");
  println("MAKE SURE TO DOUBLE CHECK CSV IS UPDATED AND CORRECT");
  println("PLEASE MAKE SURE TO TAG THE HACKED FIELD TO TRUE IF YOu HAVE HACKED ANY PART OF THIS BRANCH");
  println("Hacked? " + hacked);
  if (hacked)
    println("Description of hack: " + hacked_description);
  println("Framerate: " + framerate);
  println("CSV: " + csv_select);
  println("Is this actually a pi? " + is_a_pi);
  println("using Wifi? " + network.use_wifi);
  println("Perceived Control IP: " + "not used for now"); // dl.get_control_ip("172.23.0.85"));
  println("\n\n\n");

  frameRate(framerate);
  size(600, 600);


  // if(use_grideye) ge.start();
  my_rpi.start();

  elapsed_millis = 0;
  last_millis = millis();
}



/*!
 *  \fn draw()
 *  \brief main drawing loop
 *  \return none
 */
void draw() {


  //  gui.queueChart.setData("queue_values", new int[100]);
  //queueChart.setCaptionLabel("*** Queue size: " + message_count_this_frame + "  ***");
  //queueChart.push("queue_values", message_count_this_frame);

  //MATT-GRIDEYE
  elapsed_millis = millis() - last_millis;
  message_count_this_frame = 0;
  
  

  background(0);

  if (!use_grideye) return;

  ///////////  G R I D E Y E 

  if (gesim) {
    ge.gridEye.update();
    ge.read_grideye_port(null);
    //    serialEvent(null);
  }

  if (!ge.goodFrame) return;

  if (ge.stream) {
    //    print("-->");

    ge.goodFrame = false;  // block calculations until a new frame is delivered.
    return;
  }
  if (ge.debug) println("frame " + frame + " - incoming size is " + ge.incomingValues.length);

  if (frame % frameskip != 0) { 
    if (gesim)   ge.gridEye.go();    // draw gridEye simulation anyway...
    return;                     // ... but skip frames to emphasize motion differencing
  }

  //  println("here");

  if (gesim && prerecorded) {

    if (ge.debug) {
      println(" Input: ");
      ge.printMatrix(ge.incomingValues);
    }

    ge.incomingValues = ge.rotateMatrix(ge.incomingValues, ge.gridEye.recording_rotation);

    if (ge.debug) {
      println(" rotated by " + ge.gridEye.recording_rotation);
      ge.printMatrix(ge.incomingValues);
    }
  }



   frame++;

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
  if (frame == 5 || frame == 30) {  
    ge.setBackground = true;
  }

  if (ge.setBackground) {
    println("SETTING BACKGROUND");
    arrayCopy(ge.incomingValues, ge.backgroundValues);
    ge.topMax = 0f;
    ge.topMaxFore = 5.0f;
    ge.maxDPVariance = 100f;  // can't initialize to zero or we get a divbyzero error
    ge.setBackground = false;
  }

  // SUBTRACT BACKGROUND  (subt, from)
  ge.foreValues = ge.subtractMatrix(ge.backgroundValues, ge.incomingValues, noiseThreshold);     // noise threshold

  if (ge.debug) {
    println("fV: ");
    ge.printMatrix(ge.foreValues);
  }

  // average the matrix
  ge.avgFore = ge.avgMatrix(ge.foreValues);
  ge.maxFore = max(ge.foreValues);
  ge.minFore = min(ge.foreValues);
  ge.topMaxFore = max(ge.topMaxFore, ge.maxFore);

  for (int i=0; i< ge.foreValues.length; i++) {
    //// Normalize the foreground pixels

    ge.foreValues[i] = map(ge.foreValues[i]/ge.topMaxFore, ge.avgFore/ge.topMaxFore, 1f, 0f, 255f) ;
    ge.foreValues[i] = max(0, ge.foreValues[i]);
  }



  //beginDraw();

  //// DRAW to screen 

  if (gesim) {    // start by drawing the simulation
    ge.gridEye.go();
  }


  arrayCopy(ge.motionValues, ge.outputMV);
  arrayCopy(ge.dpValues, ge.outputDP);

  ge.overall_presence = 0f;

  for (int i=0; i<8; i++) {
    for (int j=0; j<8; j++) {
      int index = (8*i)+j;

      //  draw the box - motion

      int pval = int(ge.pixelValues[index]);

      fill(pval);    
      rect((canvasw/20)*(j+1), (canvash/2)/10*(i+1), canvasw/20, (canvash/2)/10);

      // text:
      fill(128);
      text(round(ge.outputMV[index]), (canvasw/20)*(j+1), canvash/20*(i+1));
      //   text(nf(outputDP[index], 2, 3), (canvasw/20)*(j+1), canvash/20*(i+1)+10);

      arrayCopy(new float[64], ge.dpValues);  // clear dpvalues


      //  draw the presence pixels
      fill(ge.foreValues[index]);
      rect((canvasw/20)*(j+1), (0*canvash/2)+(canvash/2)/10*(i+1), canvasw/20, (canvash/2)/10);

      ge.overall_presence += ge.foreValues[index];
    }
    if (ge.debug) {
      println();
    }
  }

  // draw the presence indicator

  float p = map(ge.overall_presence, 200f, 2000f, 0.0, 1.0);
  if (p < 0 ) p = 0f;
  if (p > 1 ) p = 1f;

  float p_relative =  max(0f, p-ge.presence_threshold) / (1.0-ge.presence_threshold);

  stroke(p*255);
  fill(p_relative * 255);

  rect(canvasw/20, canvash/2 - canvash/20, canvasw/2-canvasw/10, canvash/40);

  noStroke();
  // println("overall presence: " + overall_presence);



  // draw the rec_x and rex_y offsets, if it is prerecorded

  if (gesim && prerecorded) {

    int ii = (ge.rec_y_offset) % (8);  
    if (ii < 0) ii = (8) + ii;  //  rolling offset 
    int jj = (ge.rec_x_offset) % (8);  
    if (jj < 0) jj = (8) + jj;  //  rolling offset

    stroke(255);
    line((canvasw/20)*(jj+1), canvash/2 + canvash/20, (canvasw/20)*(jj+1), canvash/2 + 9*canvash/20); 
    line((canvasw/20), canvash/2+ canvash/20*(ii+1), (canvasw/20)*9, canvash/2+ canvash/20*(ii+1));
  }

  ge.calcVectors(); 


  //MATT-GRIDEYE
  if ( (p >= ge.presence_threshold || p < 0.02 ) && elapsed_millis >= (1000/ge.polling_frequency)) {
    network.write_message("/RPI/GE_PRESENCE/" + my_rpi.my_address + "/" + dl.get_control_ip(network.my_address) + " " + Float.toString(p_relative));
    last_millis = millis();
  }

  PVector m_vector  = new PVector(ge.x_comp, ge.y_comp);

    m_vector.x *= 0.01;
    m_vector.y *= 0.01;

    m_vector.x = constrain(m_vector.x, -1.0, 1.0);
    m_vector.y = constrain(m_vector.y, -1.0, 1.0);

  float   m_vec_mag = m_vector.mag() ;

  //MATT-GRIDEYE
  if ((m_vec_mag >= ge.motion_threshold) &&  elapsed_millis >= (1000/ge.polling_frequency)) {
    network.write_message("/RPI/GE_MOTION/" + my_rpi.my_address + "/" + dl.get_control_ip(network.my_address) + " " + 
      Float.toString(m_vector.x) + " " + Float.toString(m_vector.y));
    last_millis = millis();
  }

  try { 
    arrayCopy(ge.incomingValues, ge.lastFrame);
  } 
  catch (ArrayIndexOutOfBoundsException e) {
    println(" ---- Array Index Out of Bounds, but that's all right. ----- ");
  }

  //endDraw();

  ge.goodFrame = false;  // block calculations until a new frame is delivered.

  ////////
}

/*!
 *  \fn serial_node_setup()
 *  \brief Creates a list of ports and passes to comms manager to setup serial communication with teensies
 *  \return none
 *  TODO:  MG - need to figure out how to call this again dynamically to keep port list current and check for new handshakes
*               .... does a port know its name?  Can I rely on the name to stay consistant?
 */
void serial_node_setup() {
//  for (int i = 0; i < setup_ports.length; i++) {
  for (int i = 0; i < Serial.list().length; i++) {
    if (Serial.list()[i].contains(teensy_port_code)) {
      setup_ports.add(new Serial(this, Serial.list()[i], baud_rate));
    }
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
}

/*!
 *  \fn oscEvent(OscMessage received_message)
 *  \brief oscEvent triggered whenever an osc message reaches this rpi
 *  \param received_message the message received
 *  \return none
 */
void oscEvent(OscMessage received_message) { 
  network.osc_received(received_message);
}

/*!
 *  \fn serialEvent(Serial p)
 *  \brief Triggered by serial events, used exclusively by Grideye's. Trick used to close other serial port events by purposely doing an index out of bounds.
 *  \param p the Serial port triggered
 *  \return none
 */
synchronized void serialEvent(Serial p) {

  // check if it's a GridEye - totally different message structure
  if (network.map_built)
  {
    if (network.my_pis_node_port.get(grideye_ID).equals(p)) {
      //println("reading grideye buffer");
      ge.read_grideye_port(p);
    } else
    { // create a failure to disable serial events on this port
      int[] outOfBoundsArr = new int[1];
      println(outOfBoundsArr[2]);
    }
  }
}



///  GUI functions (for some reason get called here, from Grideye_Controls) ... not sure why

/*!
 *  \fn setBackground()
 *  \brief sets the background for the grideye data
 *  \return none
 */
void setBackground() {

  ge.setBackground = true;
}

/*!
 *  \fn togglepre(boolean pre)
 *  \brief MATT - TODO
 *  \param pre
 *  \return none
 */
void togglepre(boolean pre) {

  println("setting prerecorded to " + pre);
  prerecorded = pre;

  if (pre==true) {
    ge.gridEye.setup_prerecorded();
  } else {
    setBackground();
  }
}

/*!
 *  \fn pickfile(int n)
 *  \brief MATT - TODO
 *  \param n
 *  \return none
 */
void pickfile(int n) {

  if ( firstpick ) {     // hack to prevent a null pointer on setup of pickfile dropdown.
    firstpick = false; 
    return;
  }

  /* request the selected item based on index n */


  ge.gridEye.recording_filename = String.valueOf(ge.gridEyeGUI.get(ScrollableList.class, "pickfile").getItem(n).get("text"));
  //  println(n, gridEyeGUI.get(ScrollableList.class, "pickfile").getItem(n).get("text"));


  if (prerecorded == true) {
    ge.gridEye.setup_prerecorded();
  }
}

/*!
 *  \fn setOffset(float[] vals)
 *  \brief MATT - TODO
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

  String radiostring = ge.gridEyeGUI.get(RadioButton.class, "setRotation").getItem(n).getLabel();

  switch(n) {
  case 0:
    ge.gridEye.recording_rotation = 'L';
    break;
  case 1:
    ge.gridEye.recording_rotation = '0';
    break;
  case 2:
    ge.gridEye.recording_rotation = 'R';  
    break;
  case 3:
    ge.gridEye.recording_rotation = 'F';     
    break;
  }

  println("set rotation to " + ge.gridEye.recording_rotation + "  -- " + radiostring);
}

/*!
 *  \fn angle_adjust(float a)
 *  \brief MATT - TODO
 *  \param a
 *  \return none
 */
void angle_adjust(float a) {

  //print ("Output angle is " + a );

  ge.output_angle = a;

  //println(" , or " + radians(a) + " radians");
}





////   non-GUI keypress functions  -- to deprecate once added to GridEye_Controls? 
/*!
 *  \fn keyPressed()
 *  \brief do something if a key is pressed, used for debugging and some GUI functions
 *  \return none
 */
void keyPressed() {
  if (key == ' ') {
    setBackground();
  } else if (key == 'f') {
    ge.stream = !ge.stream;
  }

  if (key == CODED) {
    if (keyCode == RIGHT) {
      ge.rec_x_offset++;
      ge.setBackground = true;
    } else if (keyCode == LEFT) {
      ge.rec_x_offset--;
      ge.setBackground = true;
    } else if (keyCode == UP) {
      ge.rec_y_offset--;
      ge.setBackground = true;
    } else if (keyCode == DOWN) {
      ge.rec_y_offset++;
      ge.setBackground = true;
    } 

    println("X offset:" + ge.rec_x_offset + " y offset: " + ge.rec_y_offset);
  }

  if (key == 'r') {
  }
}
