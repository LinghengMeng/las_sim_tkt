import processing.sound.*;
import controlP5.*;


VisGui vgui;

class VisGui {

  String prefix;

  GridEye_Analyzer ge;
  
  Accordion panels;
  color c = color(0, 160, 100);
  ControlP5 ge_gui;

  boolean initialized = false;

  Textarea myConsole;
  Println console; 
  ButtonBar bar;
  Chart actuatorChart;
  Chart irChart;
  Chart sdChart;
  Chart presenceChart;
  Chart maxSdChart;
  Accordion actuator_settings;
  Textfield codeinput;
  Textfield datainput;
  Textfield saveinput;

//  int NUM_SDS = 5;             // hack - should use DL to determine how many SDs before constructing visGui.
//  int NUM_IRS = 5;
  LinkedHashMap<Integer, Amplitude> sd_levels  = new LinkedHashMap<Integer, Amplitude>();  // store levels by node_ID key
  LinkedHashMap<Integer, AudioIn>   sd_streams = new LinkedHashMap<Integer, AudioIn>();    // store levels by node_ID key
  LinkedHashMap<Integer, Float>     ir_levels  = new LinkedHashMap<Integer, Float>();      // store levels by node_ID key
//  Amplitude[] sd_levels = new Amplitude[num_SD];
//  AudioIn[]   sd_streams = new AudioIn[num_SD];
//  float[]     ir_levels = new float[num_IR];

  Client gridEyeClient_live;
  Client gridEyeClient_local;

  ControlFont my_gill_12;
  PApplet appl;
  
  RadioButton which_smas;
  RadioButton which_moths;
  RadioButton which_drs;
  RadioButton which_wts;
  RadioButton which_actuators;
  RadioButton drs_mode;
  Slider      drs_offset;
  Button      drs_reset_offset;
  Group moth_settings;
  Group drs_settings;
  Group sma_settings;
  Group wt_settings;
  Group  influence_settings;
  // Textlabel influence_message;
  Toggle subscribe_influence;
  controlP5.Range  influence_range;

  Toggle isolate_group;
  Toggle coord_average;
  Textlabel coord_display;
  ArrayList<PVector> coords_to_average = new ArrayList<PVector>();

  ScrollableList which_influence;

  ScrollableList which_scene;
  
  int  show_control_ypos = height;
  boolean show_control_hiding = true;
  boolean show_control_test_1_running = false;
  boolean show_control_test_2_running = false;
  boolean show_control_test_3_running = false;


  RadioButton which_sds;
  Group sd_settings;
  Group ge_settings;
  Group  grp_prerec;
  Group  grp_analysis;
  Group  grp_simulation;
  Group  grp_vizbg;


  RadioButton which_irs;
  Group ir_settings;

  Numberbox cam_lookat_x;
  Numberbox cam_lookat_y;
  Numberbox cam_lookat_z;
  Numberbox cam_rot_x;
  Numberbox cam_rot_y;
  Numberbox cam_rot_z;
  Numberbox cam_distance;

  Toggle sd_live_or_local;
  Toggle sd_polling;
  Button sd_reveal_patchable;
  Toggle sd_hide_patchable;
  Slider sd_freq_slider;
  Slider sd_thresh_slider;

  Toggle ir_live_or_local;
  Toggle ir_polling;
  Slider ir_freq_slider;
  Slider ir_thresh_slider;

  Slider ge_frameskip;
  Slider ge_frequency;
  Slider ge_interest_thresh;
  Slider ge_noise_thresh;
  Slider ge_overall_relax;
  Slider ge_presence_threshold;
  Slider ge_motion_threshold;
  Knob   ge_angle_adjust;
  Toggle ge_stream;
  Bang   ge_printout;
  ScrollableList ge_prerec_file;
  RadioButton ge_prerec_rot;


  Group show_control;
  Slider show_control_vol1;
  Slider show_control_vol2;
  Slider show_control_presence;
  Slider show_control_sd;
  Button show_control_save;
  Button show_control_sleep;
  Button show_control_mute;
  Button show_control_launch_tests;
  Toggle show_control_timer;
  Numberbox show_control_hour_from;
  Numberbox show_control_min_from;
  Numberbox show_control_hour_to;
  Numberbox show_control_min_to;
  Textlabel  show_control_awake_state_label;


  Textlabel  awake_state_label;
  Textlabel  data_dir_label;

  Group show_control_test_panel;
  Button show_control_gui;
  Button show_control_test_1;
  Button show_control_test_2;
  Button show_control_test_3;
  Button show_control_test_4;
  
  ControlP5 vgui;
  
  

 
     int fontheight = height/25;
     int xspace = width/50;
     int yspace = height/50;
     int bwidth = width/5;
     int bheight = height/10;
     int xpos = xspace;
     int ypos = yspace;

     PFont pfont = createFont("GillSans-48", fontheight, true); // use true/false for smooth/no-smooth
     ControlFont GUIfont = new ControlFont(pfont, fontheight);
  
  VisGui(PApplet applet) {
    appl = applet;
    vgui = new ControlP5(applet);
    vgui.setAutoDraw(false);

    // for (int i = 0; i < num_SD; i++) {
    //   sd_levels[i] = new Amplitude(applet);
    //   sd_streams[i] = new AudioIn(applet, 0);
    //   sd_streams[i].start();
    //   sd_levels[i].input(sd_streams[i]);
    // }


    my_gill_12 = new ControlFont(gill, 12);
  }

  void init(String file_prefix) {

    prefix = file_prefix;
    String cam_settings_file = file_prefix + "/cam_settings";
    String show_control_settings_file = file_prefix + "/show_control_settings";


    // ==============================  E L E M E N T S  =======================

    // show_control_gui = vgui.addButton("showcontrols")
    //   .setPosition(0,0)
    //   .setSize(95,20)
    //   ;

    bar = vgui.addButtonBar("views")
      .setPosition(0, 0)
      .setSize(width, 20)
      //  .setColorBackground(color(50, 50, 100, 100))
      //  .setColorForeground(color(50, 50, 200, 100))
      //  .setColorActive(color(50, 50, 200, 255))
      .addItems(split("a b c d e f g h i j", " "))
      ;

  

  
    // scene control panel ();

    Group scene_settings = vgui.addGroup("Scenes")
      .setBackgroundColor(color(0, 64))
      .setBackgroundHeight(380)
      ;


    List scenelist = get_scene_list();


    which_scene = vgui.addScrollableList("pick_scene_gui")
      .setPosition(10, 30)
      .setSize(250, 100)
      .setHeight(200)
      .setBarHeight(20)
      .setItemHeight(20)
      .setOpen(false)
      .addItems(scenelist)
      .setValue(0)
      .moveTo(scene_settings)
      ;

    data_dir_label = vgui.addTextlabel("[ " + file_prefix + " ]")
     .setPosition(10, 10)
     .setValue("[ " + file_prefix + " ]")
     .moveTo(scene_settings)
     ;

    awake_state_label = vgui.addTextlabel("[ AWAKE ]")
     .setPosition(10, 300)
//     .setFont(new ControlFont(pfont, fontheight/3))
     .setValue((sleepmode==false) ? "[ AWAKE ]":"[ SLEEPING ]")
     .moveTo(scene_settings)
     ;

    vgui.addButton("new_scene_gui")
      .setLabel("NEW SCENE")
      .setPosition(120, 240)
      .setSize(120, 20)
      .moveTo(scene_settings)
      ;

    vgui.addButton("save_scene_gui")
      .setLabel("SAVE SCENE")
      .setPosition(120, 270)
      .setSize(120, 20)
      .moveTo(scene_settings)
      ;

    vgui.addButton("save_scene_as_gui")
      .setLabel("SAVE AS")
      .setPosition(120, 300)
      .setSize(120, 20)
      .moveTo(scene_settings)
      ;


    saveinput = vgui.addTextfield("save_scene_input_gui")
       .setPosition(10, 330)
       .setSize(230, 20)
       .setLabelVisible(false)
       .setVisible(false)
       .setFocus(false)
       .setAutoClear(true)
       .setLabel("Input scene name")
       .setText("")
       .moveTo(scene_settings)
     ;
  

  
    // camera control panel (will hide, but use to save camera states);

    Group cam_controls = vgui.addGroup("Camera Settings")
      .setBackgroundColor(color(0, 64))
      .setBackgroundHeight(130)
      ;

    cam_lookat_x = vgui.addNumberbox("cam_lookat_x")
      .setPosition(10, 10)
      .setSize(60, 20)
      .setRange(-50000, 50000)
      .setMultiplier(10) // set the sensitifity of the numberbox
      .setDirection(Controller.HORIZONTAL) // change the control direction to left/right
      .setValue(centerpoint.x)
      .setLabel("Look X")
      .moveTo(cam_controls)
      ;      

    cam_lookat_y = vgui.addNumberbox("cam_lookat_y")
      .setPosition(80, 10)
      .setSize(60, 20)
      .setRange(-50000, 50000)
      .setMultiplier(10) // set the sensitifity of the numberbox
      .setDirection(Controller.HORIZONTAL) // change the control direction to left/right
      .setValue(centerpoint.y)
      .setLabel("Look Y")
      .moveTo(cam_controls)
      ;      

    cam_lookat_z = vgui.addNumberbox("cam_lookat_z")
      .setPosition(150, 10)
      .setSize(60, 20)
      .setRange(-50000, 50000)
      .setMultiplier(10) // set the sensitifity of the numberbox
      .setDirection(Controller.HORIZONTAL) // change the control direction to left/right
      .setValue(centerpoint.z)
      .setLabel("Look Z")
      .moveTo(cam_controls)
      ;      

    cam_rot_x = vgui.addNumberbox("cam_rotate_x")
      .setPosition(10, 50)
      .setSize(60, 20)
      .setRange(-8, 8)
      .setMultiplier(.01) // set the sensitifity of the numberbox
      .setDirection(Controller.HORIZONTAL) // change the control direction to left/right
      .setValue(-2.32)
      .setLabel("Yaw (X)")
      .moveTo(cam_controls)
      ;      

    cam_rot_y = vgui.addNumberbox("cam_rotate_y")
      .setPosition(80, 50)
      .setSize(60, 20)
      .setRange(-8, 8)
      .setMultiplier(.01) // set the sensitifity of the numberbox
      .setDirection(Controller.HORIZONTAL) // change the control direction to left/right
      .setValue(1.35)
      .setLabel("Pitch (Y)")
      .moveTo(cam_controls)
      ;      

    cam_rot_z = vgui.addNumberbox("cam_rotate_z")
      .setPosition(150, 50)
      .setSize(60, 20)
      .setRange(-8, 8)
      .setMultiplier(.01) // set the sensitifity of the numberbox
      .setDirection(Controller.HORIZONTAL) // change the control direction to left/right
      .setValue(0.70)
      .setLabel("Roll (Z)")
      .moveTo(cam_controls)
      ;      

    cam_distance = vgui.addNumberbox("cam_distance")
      .setPosition(10, 90)
      .setSize(60, 20)
      .setRange(-60000, 60000)
      .setMultiplier(10) // set the sensitifity of the numberbox
      .setDirection(Controller.HORIZONTAL) // change the control direction to left/right
      .setValue(2874.81)   // (abs(dl.z_range[1] * 2))
      .setLabel("Distance")
      .moveTo(cam_controls)
      ;      

    vgui.addButton("save_cam_settings")
      .setPosition(80, 90)
      .setSize(120, 20)
      .moveTo(cam_controls)
      ;

    // new property set to save camera settings:
    vgui.getProperties().addSet("cam_set");
    vgui.getProperties().move(cam_lookat_x, "default", "cam_set");
    vgui.getProperties().move(cam_lookat_y, "default", "cam_set");
    vgui.getProperties().move(cam_lookat_z, "default", "cam_set");
    vgui.getProperties().move(cam_rot_x, "default", "cam_set");
    vgui.getProperties().move(cam_rot_y, "default", "cam_set");
    vgui.getProperties().move(cam_rot_z, "default", "cam_set");
    vgui.getProperties().move(cam_distance, "default", "cam_set");

    // vgui.getProperties().print();

    ///   ==========   TEST MESSAGE INPUT BOXES   ==========

    String test_msg_code = new String("/CONTROL/FADE_ACTUATOR_GROUPS/" + network.my_address + "/" + dl.get_node_addresses().get(0) );

    codeinput = vgui.addTextfield("message_input_code")
      .setPosition(450, 700)
      .setSize(280, 20)
      .setLabelVisible(false)
      .setFocus(false)
      .setAutoClear(true)
      .setLabel("Input Msg Code (OSC format)")
      .setText(test_msg_code);
    ;

    datainput = vgui.addTextfield("message_input_data")
      .setPosition(740, 700)
      .setSize(230, 20)
      .setLabelVisible(false)
      .setFocus(false)
      .setAutoClear(true)
      .setLabel("Input Msg Data (space-separated strings)")
//      .setText("MO1 200 2500 MO3 200 1500 MO5 200 4000");
      .setText("SM1 200 1000");
    ;

    vgui.addButton("send_test_message")
      .setPosition(980, 700)
      .setSize(30, 20)
      .setLabel("Send");
    ;

    // =========================   KEYBOARD SHORTCUTS 

    vgui.enableShortcuts();


    //  =========================  ACTUATOR MONITORING


    actuatorChart = vgui.addChart("Actuator Listener")
      .setPosition(width - 450, 50)
      .setSize(200, 50)
      .setRange(0, 255)
      .setView(Chart.LINE) // use Chart.LINE, Chart.PIE, Chart.AREA, Chart.BAR_CENTERED
      .setStrokeWeight(1.5)
      .setColorBackground(color(0, 100))
      .setColorForeground(color(255, 100))
      ;

    actuatorChart.hide();

    //  =========================  SENSOR MONITORING

    ge_settings = vgui.addGroup(" GridEye Settings ")
      .setWidth(400)
      .setBackgroundColor(color(0, 100))
      .setBackgroundHeight(400)
      .setVisible(false)
      .disableCollapse()
      .hideArrow()
      ;


    //  =========================  SIMULATION AND PARAMETER SETTINGS 


    // GENERAL ACTUATOR INFLUENCE SETTINGS 

    influence_settings = vgui.addGroup("Actuator Influence Settings")
      .setPosition(0, 0)
      .setSize(200, 600)
      .setBackgroundColor(color(0, 64))
      .open()
      .setVisible(false)
      .hideArrow()
      ;

    
    which_actuators = vgui.addRadioButton("apply_actuator_settings_to")
      .setPosition(10, 10)
      .setSize(25, 15)
      .addItem(" This Actuator", 0)
      .addItem(" This Actuator Group", 1)
      .addItem(" All Actuators Like This", 2)
      .activate(0)
      .setNoneSelectedAllowed(false)
      .setGroup(influence_settings) 
      ;
    
    
    influence_range = vgui.addRange("set_influence_map_range")
      .setPosition(10, 95)
      .setSize(180, 10)
      .setRangeValues(0, 100)
      .setLabel("")
      .setLabelVisible(true)
      .moveTo(influence_settings)
      ;


    subscribe_influence = vgui.addToggle("subscribe_to_this_influence")
      .setPosition(10, 115)
      .setSize(25, 15)
      .setLabel(" Subscribed")
      .moveTo(influence_settings)
      ;

    // to include the ability to subscribe, put behaviours in this list and the following nickname list (in the same order)

    List inf_names = Arrays.asList("GridRunner",
                                   "Excitors",
                                   "Ambient Waves",
                                   "Random Noise",
                                   "IR Sensor",          // <- these are used only by local nodes, for global stuff use patcher
                                   "Sound Detector",     // <- only used by local nodes
                                   "Grideye Presence",   // <- only local      
                                   "Electric Cells",
                                   "Sample Behaviour"    //  <- SampleBehaviour to illustrate
                                   ); 

    List inf_nicks = Arrays.asList("GR",
                                   "EXP",
                                   "WV", 
                                   "RN",
                                   "IR",
                                   "SD",
                                   "GE",
                                   "EC",
                                   "SB"                  // <- SampleBehaviour is shortened to "SB"
                                   );
 
    which_influence = vgui.addScrollableList("set_which_influence")
     .setPosition(10, 65)
     .setSize(180, 100)
     .setHeight(660)
     .setBarHeight(20)
     .setItemHeight(20)
     .setOpen(false)
     .addItems(inf_names)
     .setValue(0)
     .moveTo(influence_settings)
    ;

    // influence_message = vgui.addLabel("test message goes here")
    //    .setPosition(10, 175)
    //    .moveTo(influence_settings)
    //    ;

    // populate the nicknames of the list, if we have them.
    for (int i = 0 ; i < inf_nicks.size() ; i++) {
       which_influence.getItem(i).put("value", inf_nicks.get(i));      
    }    


    drs_mode = vgui.addRadioButton("set_drs_mode")
      .setPosition(10, 180)
      .setSize(25, 15)
      .setCaptionLabel("DRS Mode")
      .addItem("BOTH (with offset)", 0)
      .addItem("TIP_ONLY         ", 1)
      .addItem("BULB_ONLY        ", 2)
      .addItem("TIP_HALF_BULB    ", 3)
      .addItem("BULB_HALF_TIP    ", 4)
      .addItem("CHARGE_DISCHARGE ", 5)
      .addItem("OSCILLATE        ", 6)
      .activate("BOTH (with offset)")
      .setNoneSelectedAllowed(false)
      .moveTo(influence_settings)
      .setVisible(false)
      ;

    drs_offset = vgui.addSlider("set_drs_offset")
      .setCaptionLabel(" DRS Offset")
      .setPosition(10, 310)
      .setSize(130, 15)
      .setRange(-1, 1)
      .setValue(0.0)
      .setSliderMode(Slider.FLEXIBLE)
      .setGroup(influence_settings)
      .setVisible(false)
      ;

    drs_reset_offset = vgui.addButton("reset_drs_offset")
      .setCaptionLabel(" Reset ")
      .setPosition(60, 330)
      .setSize(30, 15)
      .setGroup(influence_settings)
      .setVisible(false)
      ;


    isolate_group = vgui.addToggle("isolate_grp")
      .setPosition(10, 500)
      .setSize(120, 15)
      .setCaptionLabel("Isolate Group")
      .moveTo(influence_settings)
      .setVisible(true)
      ;

    coord_display = vgui.addTextlabel("Coords:")
       .setPosition(10, 550)
     //  .setFont(GUIfont)
       .setValue("(0, 0, 0)")
       .moveTo(influence_settings)
     ;

    coord_average = vgui.addToggle("average_coords")
       .setCaptionLabel("AVG")
       .setPosition(160, 550)
       .setSize(30, 15)
       .setValue(1)
       .moveTo(influence_settings)
     ;

    // MOTHS 

    // moth_settings = vgui.addGroup("Moth Settings")
    //   .setPosition(0, 0)
    //   .setSize(200, 600)
    //   .setBackgroundColor(color(0, 64))
    //   .open()
    //   .setVisible(false)
    //   .hideArrow()
    //   ;

    // which_moths = vgui.addRadioButton("apply_moth_settings_to")
    //   .setPosition(10, 10)
    //   .setSize(25, 15)
    //   .addItem(" This Moth", 0)
    //   .addItem(" This Moth Group", 1)
    //   .addItem(" All Moths", 2)
    //   .activate(0)
    //   .setNoneSelectedAllowed(false)
    //   .setGroup(moth_settings) 
    //   ;

    // build_settings_group("MO PRESENCE RESPONSE (GE)", "P-", 65, 5, moth_settings);
    // build_settings_group("MO MOTION RESPONSE (GE)", "M-", 135, 5, moth_settings);
    // build_settings_group("MO SOUND RESPONSE", "S-", 205, 5, moth_settings);
    // build_settings_group("MO Excitors -", " MO PRESENCE Excitors ", 280, 1, moth_settings);
    // build_settings_group(" - -", " MO MOTION excitors", 350, 1, moth_settings);
    // build_settings_group("- -", " MO SOUND excitors", 420, 1, moth_settings);

    // // DOUBLE REBEL STARS 

    // drs_settings = vgui.addGroup("Double Rebel Star Settings")
    //   .setPosition(0, 0)
    //   .setSize(200, 600)
    //   .setBackgroundColor(color(0, 64))
    //   .setVisible(false)
    //   .hideArrow()
    //   ;

    // which_drs = vgui.addRadioButton("apply_drs_settings_to")
    //   .setPosition(10, 10)
    //   .setSize(25, 15)
    //   .addItem(" This Double Rebel Star", 0)
    //   .addItem(" This DRS Group", 1)
    //   .addItem(" All Double Rebel Stars", 2)
    //   .activate(0)
    //   .setNoneSelectedAllowed(false)
    //   .setGroup(drs_settings) 
    //   ;

    // build_settings_group("DR PRESENCE RESPONSE (GE)", "P:", 65, 5, drs_settings);
    // build_settings_group("DR MOTION RESPONSE (GE)", "M:", 135, 5, drs_settings);
    // build_settings_group("DR SOUND RESPONSE", "S:", 205, 5, drs_settings);
    // build_settings_group("DR Excitors -", " DR PRESENCE Excitors ", 280, 1, drs_settings);
    // build_settings_group(" - - -", " DR MOTION excitors", 350, 1, drs_settings);
    // build_settings_group("- - -", " DR SOUND excitors", 420, 1, drs_settings);



//  -========================== S O U N D    D E T E C T O R S  ===============================

    sd_settings = vgui.addGroup(" Sound Detector Settings")
      .setWidth(270)
      .setBackgroundColor(color(0, 100))
      .setBackgroundHeight(148)
      .setVisible(false)
      .disableCollapse()
      .hideArrow()
      ;


    sdChart = vgui.addChart("SD Listener")
      .setPosition(0, 150)
      .setSize(sd_settings.getWidth(), 50)
      .setRange(0, 1024)
      .setView(Chart.LINE) // use Chart.LINE, Chart.PIE, Chart.AREA, Chart.BAR_CENTERED
      .setStrokeWeight(1.5)
      .moveTo(sd_settings)
      .setColorBackground(color(0, 100))
      .setColorForeground(color(255, 100))
      ;

    which_sds = vgui.addRadioButton("apply_sd_settings_to")
      .setPosition(10, 10)
      .setSize(25, 15)
      .addItem(" This Sound Detector", 0)
      .addItem(" All Sound Detectors", 1)
      .activate(0)
      .setNoneSelectedAllowed(false)
      .setGroup(sd_settings) 
      ;

    sd_live_or_local = vgui.addToggle("sd_set_live_or_local")
      .setPosition(10, 50)
      .setSize(30, 10)
      .setCaptionLabel("LOCAL   LIVE")
      .setMode(ControlP5.SWITCH)
      .setGroup(sd_settings)
      ;

    sd_polling = vgui.addToggle("sd_set_polling")
      .setCaptionLabel("Polling")
      .setPosition(60, 50)
      .setSize(20, 10)
      .setGroup(sd_settings)
      ;

    sd_reveal_patchable = vgui.addButton("sd_reveal_patchable")
      .setCaptionLabel("Reveal Patchable(s)")
      .setPosition(120, 50)
      .setSize(20, 10)
      .setGroup(sd_settings)
      ;

    // sd_hide_patchable = vgui.addToggle("sd_hide_patchable")
    //   .setCaptionLabel("SHOW    HIDE\nPatchable")
    //   .setPosition(170, 50)
    //   .setSize(20, 10)
    //   .setMode(ControlP5.SWITCH)
    //   .setGroup(sd_settings)
    //   ;

    sd_freq_slider = vgui.addSlider("sd_set_freq")
      .setCaptionLabel("Polling Frequency (Hz)")
      .setPosition(10, 100)
      .setSize(sd_settings.getWidth()/2-20, 15)
      .setRange(1, 30)
      .setValue(10)
      .setNumberOfTickMarks(31)
      .setGroup(sd_settings)
      ;

    sd_thresh_slider = vgui.addSlider("sd_set_threshold")
      .setCaptionLabel("Threshold")
      .setPosition(10, 130)
      .setSize(sd_settings.getWidth()/2-20, 15)
      .setRange(0, 1023)
      .setValue(200)

      .setGroup(sd_settings)
      ;
//  -========================== I R   S E N S O R S  ===============================

    ir_settings = vgui.addGroup(" IR Detector Settings")
      .setWidth(270)
      .setBackgroundColor(color(0, 100))
      .setBackgroundHeight(148)
      .setVisible(false)
      .disableCollapse()
      .hideArrow()
      ;


    irChart = vgui.addChart("IR Listener")
      .setPosition(0, 150)
      .setSize(ir_settings.getWidth(), 50)
      .setRange(0, 1024)
      .setView(Chart.LINE) // use Chart.LINE, Chart.PIE, Chart.AREA, Chart.BAR_CENTERED
      .setStrokeWeight(1.5)
      .moveTo(ir_settings)
      .setColorBackground(color(0, 100))
      .setColorForeground(color(255, 100))
      ;

    which_irs = vgui.addRadioButton("apply_ir_settings_to")
      .setPosition(10, 10)
      .setSize(25, 15)
      .addItem(" This IR Detector", 0)
      .addItem(" All IR Detectors", 1)
      .activate(0)
      .setNoneSelectedAllowed(false)
      .setGroup(ir_settings) 
      ;

    ir_live_or_local = vgui.addToggle("ir_set_live_or_local")
      .setPosition(10, 50)
      .setSize(30, 10)
      .setCaptionLabel("LOCAL   LIVE")
      .setMode(ControlP5.SWITCH)
      .setGroup(ir_settings)
      ;

    ir_polling = vgui.addToggle("ir_set_polling")
      .setCaptionLabel("Polling")
      .setPosition(60, 50)
      .setSize(20, 10)
      .setGroup(ir_settings)
      ;

    ir_freq_slider = vgui.addSlider("ir_set_freq")
      .setCaptionLabel("Polling Frequency (Hz)")
      .setPosition(10, 100)
      .setSize(ir_settings.getWidth()/2-20, 15)
      .setRange(1, 30)
      .setValue(10)
      .setNumberOfTickMarks(31)
      .setGroup(ir_settings)
      ;

    ir_thresh_slider = vgui.addSlider("ir_set_threshold")
      .setCaptionLabel("Threshold")
      .setPosition(10, 130)
      .setSize(ir_settings.getWidth()/2-20, 15)
      .setRange(0, 1023)
      .setValue(300)

      .setGroup(ir_settings)
      ;

 //  -========================== G R I D    E Y E ===============================

  
  
  

  // group number 1, contains recorded data controls
  grp_prerec = vgui.addGroup("GridEye: Pre-Recorded")
                .setBackgroundColor(color(0, 64))
                .setBackgroundHeight(150)
                .setVisible(false)
                ;
  
  // vgui.addToggle("togglepre")
  //    .setPosition(10,20)
  //    .setHeight(20)
  //    .setWidth(20)
  //    .setLabel("use recording")
  //    .moveTo(grp_prerec)
  //    ;
  
  List l = Arrays.asList("leftArmWaving.txt", 
                         "rightArmWaving.txt", 
                         "sideToSide1.txt", 
                         "sideToSide2.txt", 
                         "frontBack1.txt", 
                         "frontBack2.txt", 
                         "bothArms.txt");

  ge_prerec_file = vgui.addScrollableList("pickfile")
     .setPosition(40, 20)
     .setSize(200, 100)
     .setBarHeight(20)
     .setItemHeight(20)
     .setOpen(false)
     .addItems(l)
     .setValue(1)
     .moveTo(grp_prerec)
    ;
  
  ge_prerec_rot = vgui.addRadioButton("setRotation")
     .setPosition(10,60)
     .setItemWidth(5)
     .setItemHeight(10)
     .addItem("CCW",  0)    // 'L'
     .addItem("NONE", 1)    // '0'
     .addItem("CW",   2)    // 'R'
     .addItem("180",  3)    // 'F'
     .setColorLabel(color(255))
     .activate(0)
     .moveTo(grp_prerec)
     ;
     

    
  // group  contains simulation controls
  grp_simulation = vgui.addGroup("GridEye: Simulation")
                .setBackgroundColor(color(0, 64))
                .setBackgroundHeight(canvash/2)
                .setVisible(false)
                ;

  
  // group  has no controls but makes background for viz.
  grp_vizbg = vgui.addGroup("GridEye: Visualization")
                .setBackgroundColor(color(0, 64))
                .setBackgroundHeight(canvash/2)
                .setVisible(false)
                .hideArrow()
                ;


  // group contains runtime analysis controls
  grp_analysis = vgui.addGroup("GridEye: Analysis")
                .setBackgroundColor(color(0, 64))
                .setBackgroundHeight(200)
                .setVisible(false)
                ;
     
  ge_frequency = vgui.addSlider("ge_set_frequency")
     .setPosition(90, 5)
     .setSize(100, 10)
     .setRange(1, 30)
     .setValue(20)
     .setNumberOfTickMarks(30)
     .setCaptionLabel("Frequency Hz")
     .setSliderMode(Slider.FLEXIBLE)
     .moveTo(grp_analysis)
     ;

  ge_frameskip = vgui.addSlider("ge_set_frameskip")
     .setPosition(90,30)
     .setSize(100,15)
     .setRange(1,10)
     .setValue(1)
     .setNumberOfTickMarks(10)
    .setCaptionLabel("Frame Skip")
     .setSliderMode(Slider.FLEXIBLE)
     .moveTo(grp_analysis)
     ;
     
  ge_interest_thresh = vgui.addSlider("ge_set_interest_thresh")
     .setPosition(90,55)
     .setSize(100,15)
     .setRange(500f,1500f)
     .setValue(1000.0)
     .setCaptionLabel("Interest Threshold")
     .setSliderMode(Slider.FLEXIBLE)
     .moveTo(grp_analysis)
     ;       
      
  ge_noise_thresh = vgui.addSlider("ge_set_noise_thresh")
     .setPosition(90,80)
     .setSize(100,15)
     .setRange(0f,1f)
     .setValue(0.3)
     .setCaptionLabel("Noise Threshold")
     .setSliderMode(Slider.FLEXIBLE)
     .moveTo(grp_analysis)
     ;       
     
  ge_overall_relax = vgui.addSlider("ge_set_overall_relax")
     .setPosition(90,105)
     .setSize(100,15)
     .setRange(0f,0.99f)
     .setValue(0.75)
     .setSliderMode(Slider.FLEXIBLE)
     .setCaptionLabel("Overall Relax")
     .moveTo(grp_analysis)
     ;       

  ge_presence_threshold = vgui.addSlider("ge_set_presence_threshold")
     .setPosition(90,130)
     .setSize(100,15)
     .setRange(0f,0.99f)
     .setValue(0.15)
     .setSliderMode(Slider.FLEXIBLE)
     .setCaptionLabel("Presence Theshold")
     .moveTo(grp_analysis)
     ;       
  
  ge_motion_threshold = vgui.addSlider("ge_set_motion_threshold")
     .setPosition(90,155)
     .setSize(100,15)
     .setRange(0f,0.99f)
     .setValue(0.24)
     .setSliderMode(Slider.FLEXIBLE)
     .setCaptionLabel("Motion Theshold")
     .moveTo(grp_analysis)
     ;       
  
 ge_angle_adjust = vgui.addKnob("ge_set_angle_adjust")
               .setRange(0,360)
               .setValue(0)
               .setPosition(10,90)
               .setRadius(30)
               .setNumberOfTickMarks(8)
               .setTickMarkLength(2)
               .snapToTickMarks(false)
               .setAngleRange(TWO_PI)
               .setStartAngle(PI+PI/2)
               .setShowAngleRange(true)
               .setViewStyle(2)
               .setCaptionLabel("Angle Adjust")
               .setDragDirection(Knob.HORIZONTAL)
               .moveTo(grp_analysis)
               ;
     
  /// FARHAN GRIDEYE //// next two elements.   
     
  vgui.addBang("setBackground")
     .setPosition(10,20)
     .setSize(20 , 20)
     .moveTo(grp_vizbg)
     .setCaptionLabel("BG")
     ; 

  vgui.addBang("ge_reveal_patchable")
     .setPosition(233,20)
     .setSize(20, 20)
     .moveTo(grp_vizbg)
     .setCaptionLabel("PATCHABLE")
     ;

  ge_printout = vgui.addBang("geprint")
     .setPosition(10, 20)
     .setSize(40, 10)
     .setLabel("PRINT & SAVE")
     .moveTo(grp_analysis) 
     ;

  ge_stream = vgui.addToggle("gefwd")
     .setPosition(10,60)
     .setSize(40, 10)
     .setLabel("STREAM")
     .setMode(ControlP5.SWITCH)
     .moveTo(grp_analysis)
     ;
  
  // vgui.addToggle("gesim")
  //    .setPosition(10,90)
  //    .setHeight(10)
  //    .setWidth(40)
  //    .setLabel("SIM --- LIVE")
  //    .setMode(ControlP5.SWITCH)
  //    .moveTo(grp_analysis)
  //    ;


///   =========   COLLAPSABLE PANELS  (CAMERA, ETC.) ==========

    panels = vgui.addAccordion("control panels")
      .setPosition(25, 30)
      .setWidth(270)
      .setBackgroundHeight(200)
      .addItem(cam_controls)
      .addItem(scene_settings)
      .addItem(sd_settings)
      .addItem(ir_settings)
      .addItem(grp_analysis)
      .addItem(grp_prerec)
      .addItem(grp_simulation)
      .addItem(grp_vizbg)
      .setCollapseMode(Accordion.MULTI)
      ;

    //  ===============  ACCORDION PANEL TO HOLD ACTUATOR SETTINGS

    actuator_settings = vgui.addAccordion("SETTINGS")
      .setPosition(width-240, 50)
      .setSize(200, 800)
      .setBackgroundHeight(600)
      //.addItem(moth_settings)
      //.addItem(drs_settings)
      .addItem(influence_settings)
      .setVisible(false)
      ;


    //  =========================  PRESENCE MONITORING


    presenceChart = vgui.addChart("Queue Listener")
      .setPosition(25, 700)
      .setSize(200, 50)
      .setRange(0, 1.0)
      .setView(Chart.LINE) // use Chart.LINE, Chart.PIE, Chart.AREA, Chart.BAR_CENTERED
      .setStrokeWeight(1.5)
      .setColorBackground(color(0, 100))
      .setColorForeground(color(255, 100))
      ;

    presenceChart.addDataSet("presence_values");
    presenceChart.setData("presence_values", new float[100]);

//  =========================  SD MONITORING

    maxSdChart = vgui.addChart("MAX SD Listener")
      .setPosition(235, 700)
      .setSize(200, 50)
      .setRange(0, 1.0)
      .setView(Chart.LINE) // use Chart.LINE, Chart.PIE, Chart.AREA, Chart.BAR_CENTERED
      .setStrokeWeight(1.5)
      .setColorBackground(color(0, 100))
      .setColorForeground(color(255, 100))
      ;

    maxSdChart.addDataSet("max_sound_values");
    maxSdChart.setData("max_sound_values", new float[100]);

    vgui.addFrameRate().setInterval(10).setPosition(width-20, height - 10);  

      
      


  // panels.addItem(grp_prerec)
  //       .addItem(grp_simulation)
  //       .addItem(grp_analysis)
  //       ;
  
  
 // panels.open(2);
  
  // use Accordion.MULTI to allow multiple group 
  // to be open at a time.
  panels.setCollapseMode(Accordion.MULTI);
  
  // when in SINGLE mode, only 1 accordion  
  // group can be open at a time.  
  // panels.setCollapseMode(Accordion.SINGLE);




  

   // ==============================  SHOW CONTROL GUI  ============================

   /// ====== NOTE: AS OF FEB2020 THESE SHOW-CONTROL GUI ELEMENTS ARE BEING DEPRECATED
   ///              IN FAVOUR OF THE NODE.JS SERVER BROWSER-BASED GUI.
   ///              FOR NOW, TIMER IS BEING PRESERVED BUT WILL BE MOVED AS WELL.


    show_control = vgui.addGroup("GASLIGHT MEANDER CONTROL")
       .setPosition(0, 0)
       .setBarHeight(30)
       .setSize(width, height)
       .setBackgroundColor(color(0, 0, 0, 200))
       .setVisible(show_control_panel_on_startup) 
       ;
       
       


       
     vgui.addLabel("GASLIGHT Meander 2.0")
       .setPosition(xpos, ypos)
       .setFont(GUIfont)
       .moveTo(show_control)
       ;
       
     vgui.addLabel("Philip Beesley, 2019")
       .setPosition(xpos, ypos + 1.2*fontheight)
       .setFont(new ControlFont(pfont, 2*fontheight/3))
       .moveTo(show_control)
       ;
       
     ypos += bheight; // + yspace;
       
     show_control_save = vgui.addButton("save_show_control_settings")
       .setPosition(xpos, ypos)
       .setCaptionLabel("")
       .setSize(bwidth, bheight)
       .setFont(GUIfont)
       .setId(101)
       .moveTo(show_control)
       ;
       
    xpos += bwidth+xspace;   
       
    // show_control_sleep = vgui.addButton("SLEEP")
    //    .setPosition(xpos, ypos)
    //    .setSize(bwidth,bheight)
    //    .setCaptionLabel((sleepmode==false) ? " SLEEP ":" WAKE ")
    //    .setFont(GUIfont)
    //    .setId(102)
    //    .moveTo(show_control)
    //    ;
       
    xpos += bwidth+xspace;   
       
    // show_control_mute = vgui.addButton("MUTE")
    //    .setPosition(xpos, ypos)
    //    .setSize(bwidth,bheight)
    //    .setCaptionLabel((show_control_muted==true) ? " UNMUTE ":" MUTE ")
    //    .setFont(GUIfont)
    //    .setId(103)
    //    .moveTo(show_control)
    //    ;
       
    xpos += bwidth+xspace;
    
//     show_control_awake_state_label = vgui.addTextlabel("[ AWAKE ]")
//      .setPosition(xpos, ypos)
//      .setFont(GUIfont)
//      .setValue((sleepmode==false) ? "[ AWAKE ]":"[ SLEEPING ]")
//      .setId(131)
//      .moveTo(show_control)
//      ;
       
//    xpos += bwidth+xspace;   
       
    vgui.addButton("SYNC ABLETON")
       .setPosition(xpos, ypos)
       .setSize(bwidth/2+10,bheight)
       .setFont(new ControlFont(pfont, fontheight/2))
       .setId(199)
       .moveTo(show_control)
       ;

    xpos = xspace;
    ypos += bheight + yspace;
    
    // show_control_vol1 = vgui.addSlider("  Vol External")
    //     .setPosition(xpos, ypos)
    //     .setSize(width- 2*(bwidth-xspace), bheight)
    //     .setRange(0, 100)
    //     .setDecimalPrecision(0)
    //     .setFont(GUIfont)
    //     .setValue(show_control_vol_omni)
    //     .setId(104)
    //    .moveTo(show_control)
    //     ;

    ypos += bheight + yspace;

    // show_control_vol2 = vgui.addSlider("  Vol Internal")
    //     .setPosition(xpos, ypos)
    //     .setSize(width- 2*(bwidth-xspace), bheight)
    //     .setRange(0, 100)
    //     .setDecimalPrecision(0)
    //     .setFont(GUIfont)
    //     .setValue(show_control_vol_wt)
    //     .setId(105)
    //     .moveTo(show_control)
    //     ;
        
    ypos += bheight + yspace;

    // show_control_presence = vgui.addSlider("  Presence")
    //     .setPosition(xpos, ypos)
    //     .setSize(width- 2*(bwidth-xspace), bheight)
    //     .setRange(0, 100)
    //     .setDecimalPrecision(0)
    //     .setFont(GUIfont)
    //     .setValue(show_control_presence_sensitivity)
    //     .setId(135)
    //     .moveTo(show_control)
    //     ;
        
    ypos += bheight + yspace;

    // show_control_sd = vgui.addSlider("  Hearing")
    //     .setPosition(xpos, ypos)
    //     .setSize(width- 2*(bwidth-xspace), bheight)
    //     .setRange(0, 100)
    //     .setDecimalPrecision(0)
    //     .setFont(GUIfont)
    //     .setValue(show_control_sd_sensitivity)
    //     .setId(136)
    //     .moveTo(show_control)
    //     ;
        
    ypos += bheight + yspace;

    show_control_timer = vgui.addToggle("Timer")
        .setPosition(xpos, ypos)
        .setSize(bwidth/2, bheight)
        .setFont(GUIfont)
        .setValue((show_control_use_timer==false) ? 0.0 : 1.0)
        .setId(106)
        .moveTo(show_control)
        ;

       
       

      // gui.show_control_hour_from.setColorBackground((show_control_use_timer==false) ? color(9, 42, 92) : color(90));
      // gui.show_control_min_from.setColorBackground((show_control_use_timer==false) ? color(9, 42, 92) : color(90));
      // gui.show_control_hour_to.setColorBackground((show_control_use_timer==false) ? color(9, 42, 92) : color(90));
      // gui.show_control_min_to.setColorBackground((show_control_use_timer==false) ? color(9, 42, 92) : color(90));


        
    xpos += bwidth/2 + xspace;
    
    show_control_hour_from = vgui.addNumberbox("Hour From")
        .setCaptionLabel("Hour:")
        .setPosition(xpos, ypos)
        .setSize(int(.5*bwidth), bheight)
        .setColorBackground((show_control_use_timer) ? color(9, 42, 92) : color(90))
        .setMultiplier(1)
        .setDecimalPrecision(0)
        .setScrollSensitivity(0.000)
        .setDirection(Controller.HORIZONTAL)
        .setRange(6, 24)
        .setValue(show_control_start_hour)
        .setFont(GUIfont)
        .setId(107)
        .moveTo(show_control)
        ;
        
    show_control_min_from = vgui.addNumberbox("Min From")
        .setCaptionLabel("Min")
        .setPosition(xpos+(.5*bwidth), ypos)
        .setSize(int(.5*bwidth), bheight)
        .setColorBackground((show_control_use_timer) ? color(9, 42, 92) : color(90))
        .setRange(0, 45)
        .setDecimalPrecision(0)
        .setScrollSensitivity(0.000)
        .setDirection(Controller.HORIZONTAL)
        .setMultiplier(15)
        .setValue(show_control_start_minute)
        .setFont(GUIfont)
        .setId(108)
        .moveTo(show_control)
        ;
    
    vgui.addLabel(" to ")
        .setPosition(xpos + int(1.1*bwidth), ypos+bheight)
        .setFont(GUIfont)
        .moveTo(show_control)
        ;
    
    xpos += 1.5*bwidth;
        
    show_control_hour_to = vgui.addNumberbox("Hour To")
        .setCaptionLabel("Hour:")
        .setPosition(xpos, ypos)
        .setSize(int(.5*bwidth), bheight)
        .setColorBackground((show_control_use_timer) ? color(9, 42, 92) : color(90))
        .setMultiplier(1)
        .setDecimalPrecision(0)
        .setScrollSensitivity(0.000)
        .setDirection(Controller.HORIZONTAL)
        .setValue(show_control_stop_hour)
        .setRange(6, 24)
        .setFont(GUIfont)
        .setId(109)
        .moveTo(show_control)
        ;
        
    show_control_min_to = vgui.addNumberbox("Min To")
        .setCaptionLabel("Min")
        .setPosition(xpos+(.5*bwidth), ypos)
        .setSize(int(.5*bwidth), bheight)
        .setColorBackground((show_control_use_timer) ? color(9, 42, 92) : color(90))
        .setRange(0, 45)
        .setValue(show_control_stop_minute)
        .setDecimalPrecision(0)
        .setScrollSensitivity(0.000)
        .setDirection(Controller.HORIZONTAL)
        .setMultiplier(15)
        .setFont(GUIfont)
        .setId(110)
        .moveTo(show_control)
        ;


    xpos += bwidth + xspace;
   
    show_control_launch_tests = vgui.addButton("TESTS")
       .setPosition(xpos, ypos)
       .setSize(bwidth,bheight)
       .setCaptionLabel("TEST")
       .setFont(GUIfont)
       .setId(111)
       .moveTo(show_control)
       ;
       

    show_control_test_panel = vgui.addGroup("GASLIGHT MEANDER TESTS")
       .setPosition(0, 0)
       .setBarHeight(30)
       .setSize(width, height)
       .setBackgroundColor(color(0, 0, 0, 200))
       .setVisible(false)
       ;
       
     xpos = xspace;
     ypos = yspace;
       
     show_control_test_1 = vgui.addButton("TEST RS LEDs")
       .setPosition(xpos, ypos)
       .setCaptionLabel((show_control_test_1_running==true) ? " TESTING RS LEDs ":" RS LEDs ")
       .setSize(bwidth, bheight)
       .setFont(GUIfont)
       .setId(112)
       .moveTo(show_control_test_panel)
       ;
       
    xpos += bwidth+xspace;   
       
    show_control_test_2 = vgui.addButton("TEST MOTHS")
       .setPosition(xpos, ypos)
       .setSize(bwidth,bheight)
       .setCaptionLabel((show_control_test_2_running) ? " TESTING MOTHS ":" MOTHS ")
       .setFont(GUIfont)
       .setId(113)
       .moveTo(show_control_test_panel)
       ;
    show_control_test_2 = vgui.addButton("TEST SMAs")
       .setPosition(xpos, ypos)
       .setSize(bwidth,bheight)
       .setCaptionLabel((show_control_test_2_running) ? " TESTING SMAs ":" SMAs ")
       .setFont(GUIfont)
       .setId(113)
       .moveTo(show_control_test_panel)
       ;
       
    xpos += bwidth+xspace;   
       
    show_control_test_3 = vgui.addButton("TEST INNER SOUND")
       .setPosition(xpos, ypos)
       .setSize(bwidth,bheight)
       .setCaptionLabel((show_control_test_3_running==true) ? " TESTING ":" INNER SOUND ")
       .setFont(GUIfont)
       .setId(114)
       .moveTo(show_control_test_panel)
       ;
       
       
    xpos = width - bwidth - xspace;
    ypos = height - bheight - yspace; 
    
    show_control_launch_tests = vgui.addButton("CLOSE TESTS")
       .setPosition(xpos, ypos)
       .setSize(bwidth,bheight)
       .setCaptionLabel("CLOSE")
       .setFont(GUIfont)
       .setId(120)
       .moveTo(show_control_test_panel)
       ;

     // new property set to save SHOW CONTROL settings:
    vgui.getProperties().addSet("show_control_set");
    // vgui.getProperties().move(show_control_vol1,  "default", "show_control_set");
    // vgui.getProperties().move(show_control_vol2,  "default", "show_control_set");
    // vgui.getProperties().move(show_control_presence,  "default", "show_control_set");
    // vgui.getProperties().move(show_control_sd,  "default", "show_control_set");
    vgui.getProperties().move(show_control_timer,  "default", "show_control_set");
    vgui.getProperties().move(show_control_hour_from,  "default", "show_control_set");
    vgui.getProperties().move(show_control_min_from,  "default", "show_control_set");
    vgui.getProperties().move(show_control_hour_to,  "default", "show_control_set");
    vgui.getProperties().move(show_control_min_to,  "default", "show_control_set");
  
 
   // at very end, load properties:
    
    println(" GOING TO TRY TO LOAD " + cam_settings_file + " for GUI CAM settings");

    try {
     vgui.loadProperties(cam_settings_file);
    } catch (Exception e) {
      println("Exception: " + e + " loading cam_set gui properties");
      e.printStackTrace();
    }

    println(" GOING TO TRY TO LOAD " + show_control_settings_file + " for SHOW CONTROL settings");

    try {
     vgui.loadProperties(show_control_settings_file);
    } catch (Exception e) {
      println("Exception: " + e + " loading cam_set gui properties");
      e.printStackTrace();
    }

    save_show_control_settings();

    initialized = true;

  }

  // ==============================  F U N C T I O N S =======================

  void go() {

  //  show_control_awake_state_label.setValue((sleepmode==false) ? "[ AWAKE ]":"[ SLEEPING ]");
    awake_state_label.setValue((sleepmode==false) ? "[ AWAKE ]":"[ SLEEPING ]");

    // if(time_lapse) {
    // time_lapse_label.setValue("Timelapse: " + nf(time_lapse_speed, 0, 2) + "% (" + time_lapse_pause + "ms)");
    // } else {
    //   time_lapse_label.setValue("Timelapse: OFF");
    // }

    vgui.draw();
  
    // vgui.getController("  Timer").setRangeValues(6, 24);
    
  }
  
  // return a list of scenes (from disk)

  List get_scene_list() {

    /*

1. Quiet
2. Tidal state, sleeping and breathing
3. Awake: trigger
4. River showers
5. River heads to grotto
6. Awake centre
7. Grotto and river
8. Surrounding lights intense and sound intense
9. Climax
10. Recapitulation
11. Quiet, end
12. Background
13. Default exploration
    */  

    // List scenelist = Arrays.asList("01_quiet_wip", "01_quiet_v1", "01_quiet_v2", "01_quiet_final", 
    //                                "02_tidal_wip", "02_tidal_v1", "02_tidal_v2", "02_tidal_final",
    //                                "03_awake_wip", "03_awake_v1", "03_awake_v2", "03_awake_final",
    //                                "04_showers_wip", "04_showers_v1", "04_showers_v2", "04_showers_final",
    //                                "05_rh_grotto_wip", "05_rh_grotto_v1", "05_rh_grotto_v2", "05_rh_grotto_final",
    //                                "06_wake_centre_wip", "06_wake_centre_v1", "06_wake_centre_v2", "06_wake_centre_final",
    //                                "07_grotto_river_wip", "07_grotto_river_v1", "07_grotto_river_v2", "07_grotto_river_final",
    //                                "08_surround_wip", "08_surround_v1", "08_surround_v2", "08_surround_final",
    //                                "09_climax_wip", "09_climax_v1", "09_climax_v2", "09_climax_final",
    //                                "10_recapit_wip", "10_recapit_v1", "10_recapit_v2", "10_recapit_final",
    //                                "11_quiet_end_wip", "11_quiet_end_v1", "11_quiet_end_v2", "11_quiet_end_final",
    //                                "12_background_wip", "12_background_v1", "12_background_v2", "12_background_final",

    //                        "default", 
    //                        "calm", 
    //                        "active",
    //                        "timelapse");

    List scenelist = Arrays.asList("01_quiet_wip", 
                                   "02_tidal_wip", 
                                   "03_awake_wip", 
                                   "04_showers_wip", 
                                   "05_rh_grotto_wip", 
                                   "06_wake_centre_wip", 
                                   "07_grotto_river_wip", 
                                   "08_surround_wip", 
                                   "09_climax_wip", 
                                   "10_recapit_wip", 
                                   "11_quiet_end_wip", 
                                   "12_background_wip", 

                           "default", 
                           "calm", 
                           "active",
                           "hyperActive",
                           "timelapse");


    /// going to try to load scenelist dynamically from disk each time(?) otherwise use default from above -mg Nov 2020

    TreeSet sceneset = new TreeSet();  // using treeset so it's in alphabetical order;
    sceneset.add(" == New == ");

    File file = new File(sketchPath() + "/" + prefix);
    println("GOING TO TRY TO SCAN " + (sketchPath() + "/" + prefix) + " to find scene names");
    if (file.isDirectory()) {
      String names[] = file.list();

      for(String sc : names) {
        int pFrom = sc.indexOf("actuator_influence_map_") + "actuator_influence_map_".length();
        int pTo =   sc.lastIndexOf(".json");

        if(pFrom >= "actuator_influence_map_".length() && pTo != -1) {        
          // println(" sc is " + sc + " and pFrom is " + pFrom + " and pTo is " + pTo + " (sc.indexOf() is " + sc.indexOf("actuator_influence_map_") + 
          //         " and length is " + ("actuator_influence_map_".length()));
          println("\t found " + sc.substring(pFrom, pTo));
          if(!sc.substring(pFrom, pTo).equals("new")) {  // don't add 'new' - it is reserved for making new scenes.
            sceneset.add(sc.substring(pFrom, pTo));
          }
        }
      }

      List sl = new ArrayList();
      sl.addAll(sceneset);
      return(sl);

    } else {
      println(" ** Error scanning working directory for scene settings files. -- using default" );
    }

    return(scenelist);

  }


  void toggle_show_control() {
   
       show_control.setVisible(!show_control.isVisible());
       
       if(show_control.isVisible()) {
        //noCursor(); 
       }
       else {
        cursor(); 
       }
       
    /*
       if(show_control_hiding) {
          show_control.setPosition(0, 0);
          show_control_hiding = false;
       } else {
          show_control.setPosition(0, -30);
          show_control_hiding = true;
       }         
      */   
         
  }

  boolean my_isMouseOver() {

    if (actuator_settings.isVisible() && (mouseX > actuator_settings.getPosition()[0] && 
      mouseX < actuator_settings.getPosition()[0] + actuator_settings.getWidth() &&
      mouseY > actuator_settings.getPosition()[1] &&
      mouseY < (actuator_settings.getPosition()[1] + actuator_settings.getBackgroundHeight()) )) {

      return(true);
    }

    if (sd_settings.isVisible() && (mouseX > sd_settings.getAbsolutePosition()[0] && 
      mouseX < sd_settings.getAbsolutePosition()[0] + sd_settings.getWidth() &&
      mouseY > sd_settings.getAbsolutePosition()[1] &&
      mouseY < (sd_settings.getAbsolutePosition()[1] + sd_settings.getBackgroundHeight() + sdChart.getHeight() + 20) )) {

      return(true);
    }


    if (panels.isVisible() && (mouseX > panels.getAbsolutePosition()[0] && 
      mouseX < panels.getAbsolutePosition()[0] + panels.getWidth() &&
      mouseY > panels.getAbsolutePosition()[1] &&
      mouseY < (panels.getAbsolutePosition()[1] + panels.getItemHeight() + 20) )) {

      return(true);
    }

    return(vgui.isMouseOver());
  }

  void select() {
    select_item = true;

      drs_mode.hide();
      drs_offset.hide();
      drs_reset_offset.hide();

      saveinput.setVisible(false);  /// 
      saveinput.setLabelVisible(false);  /// 



    /// if not over a sensor or an actuator (ie, close everything):
    if (over_sensor == null && over_actuator == null) {


    if (selected_sensor != null && selected_sensor.parent.type.equals("GN")) {
      ge_stream.setState(false);
      // println("turn GE streaming off and hide");
    }


      selected_actuator = null;
      actuatorChart.setCaptionLabel("----");
      actuatorChart.removeDataSet("actuator_values");
      actuatorChart.hide();

      // actuator_settings.close();
      actuator_settings.hide();
   //   moth_settings.hide();
   //   drs_settings.hide();
      influence_settings.hide();

      selected_sensor = null;
      sdChart.setCaptionLabel("------");
      sdChart.removeDataSet("sensor_values");
      sdChart.removeDataSet("thresh_values");
      sdChart.hide();

      sd_settings.close();
      sd_settings.hide();

      irChart.setCaptionLabel("------");
      irChart.removeDataSet("sensor_values");
      irChart.removeDataSet("thresh_values");
      irChart.hide();

      ir_settings.close();
      ir_settings.hide();

      // close grideye panels (and set stream to false)

      grp_analysis.hide();
      grp_simulation.hide();
      grp_prerec.hide();
      grp_vizbg.hide();
      close_ge_client();
  

      selected_node = NO_NODES_SELECTED;
    }

    if (over_actuator != null) {



      // clear existing actuator data so new actuator can set its data up
      selected_actuator = null;
      actuatorChart.setCaptionLabel("----");
      actuatorChart.removeDataSet("actuator_values");
      actuatorChart.hide();

      // settings.close();
      actuator_settings.hide();
      //moth_settings.hide();
      //drs_settings.hide();
      influence_settings.hide();
    }

    if (over_sensor != null) {

      ge_stream.setState(false);
      println("turn streaming off if I'm going to hide");
      // clear existing sensor data so new sensor can set its data up

      selected_sensor = null;
      sdChart.setCaptionLabel("------");
      sdChart.removeDataSet("sensor_values");
      sdChart.removeDataSet("thresh_values");
      sdChart.hide();      

      sd_settings.close();
      sd_settings.hide();


      irChart.setCaptionLabel("------");
      irChart.removeDataSet("sensor_values");
      irChart.removeDataSet("thresh_values");
      irChart.hide();

      ir_settings.close();
      ir_settings.hide();

     // if(!over_sensor.parent.type.equals("GN")) {   // close the grideye if clicking on something else


      grp_analysis.hide();
      grp_simulation.hide();
      grp_prerec.hide();
      grp_vizbg.hide();
      close_ge_client();
     // }
    }

    if (keyshift) {
          
     // if (gridRunner.overSource) {
        cam.lookAt(gridRunner.curVertex.x, gridRunner.curVertex.y, gridRunner.curVertex.z);
        println(" Looking at " + gridRunner.curVertex.x + "," + gridRunner.curVertex.y+ "," + gridRunner.curVertex.z);
    //  } else {
        // cam.lookAt(centerpoint.x, centerpoint.y, centerpoint.z);
    //  }
    }
  }

  void display_coords(PVector position) 
  {
        if(coord_average.getValue()==0) {
          coords_to_average.clear();
          coords_to_average.add(position);
        } else {
          if(!test_current_actuator) 
          coords_to_average.add(position);
        }

        display_coords();
  }

  void display_coords()
  {
        PVector coord_to_display = new PVector(0,0,0);
        for(PVector p : coords_to_average) {coord_to_display.add(p);}
        coord_to_display.div(coords_to_average.size());

        String coords = "("+nf((coord_to_display.x),0,2)+", "+nf((coord_to_display.y),0,2)+", "+nf((coord_to_display.z),0,2)+")";

        gui.coord_display.setValue(coords);
  }

  int get_current_nav_button() {
    if (this.bar.isMouseOver()) {
      return (this.bar.hover());
    } else {
      return (-1);
    }
  }

  void build_settings_group(String label_text, String sensor_name, int ypos, int num_selections, Group master_group) {

    // builds a settings group consisting of checkboxes to associate with and a range slider for setting value threshold/mapping


    vgui.addTextlabel(label_text + "_label")
      .setPosition(10, ypos)
      .setText(label_text)
      .setGroup(master_group)
      ;

    CheckBox cb = vgui.addCheckBox("which_" + label_text)
      .setPosition(10, ypos+15)
      .setSize(10, 10)
      .setItemsPerRow(num_selections)
      .setSpacingColumn(20)
      .setGroup(master_group)
      ;

    for (int i = 0; i < num_selections; i++) {
      cb.addItem( sensor_name + str((i+1)), i);
    }


    vgui.addRange(label_text + "_range")
      .setPosition(10, ypos+35)
      .setSize(180, 10)
      .setRangeValues(0, 100)
      .setLabel("")
      .setLabelVisible(true)
      .setGroup(master_group)
      ;
  }

  void update_cam_panel(int wait) {
    delay(wait);
    update_cam_panel();
  }

  void open_ge_client(String addr, int port, boolean live) {
 
    if(live) {
      println("opening ge client: " + addr + ":"+ port);
      if(!monitor.lost_devices.contains(addr)) {
      if (gridEyeClient_live == null) {
       gridEyeClient_live = new Client(appl, addr, port);
      }
      } else {

       println("Looks like this ge's PI is lost right now...");

      }
    } else {

      println("opening local ge client");   
      if (gridEyeClient_local == null) {
       gridEyeClient_local = new Client(appl, control.my_address, port);
      }
    }
  }
  

  void close_ge_client() {

   //  println("closing GE client...");

     if(gridEyeClient_live != null) {
      gridEyeClient_live.clear();
      gridEyeClient_live.stop();
      gridEyeClient_live = null;
     }

     if(gridEyeClient_local != null) {
        gridEyeClient_local.clear();

     }

  }
  
  void clear_ge_client() {
   
     if(gridEyeClient_live != null) {
      gridEyeClient_live.clear(); 
     }

     if(gridEyeClient_local != null) {
      gridEyeClient_local.clear(); 
     }
  }

  void update_ge_panel(GridEye_Analyzer ge_analyzer) {

    if(gesim) {

    if (gridEyeClient_local == null) return;  
      if (gridEyeClient_local.available() > 130) {
      String theBuf = gridEyeClient_local.readStringUntil('@');

      //   print("FRAME: ");
      //   println(theBuf);
   
      ge_analyzer.getGeData(theBuf);  
      }
    }
    else
    {

    if (gridEyeClient_live == null) return;  
      if (gridEyeClient_live.available() > 130) {
      String theBuf = gridEyeClient_live.readStringUntil('@');

      //   print("FRAME: ");
      //   println(theBuf);
   
      ge_analyzer.getGeData(theBuf); 
      }
    }
  }


    void update_cam_panel() {
      // update cam view settings

      cam_lookat_x.changeValue(cam.getLookAt()[0]);
      cam_lookat_y.changeValue(cam.getLookAt()[1]);
      cam_lookat_z.changeValue(cam.getLookAt()[2]);

      gui.cam_rot_x.changeValue(cam.getRotations()[0]);
      gui.cam_rot_y.changeValue(cam.getRotations()[1]);
      gui.cam_rot_z.changeValue(cam.getRotations()[2]);

      cam_distance.changeValue((float)cam.getDistance());
    }
    
    Amplitude add_sd_level(int node_id) {

      Amplitude    a = new Amplitude(appl);
      AudioIn stream = new AudioIn(appl, 0);

      stream.start();
      a.input(stream);
      sd_levels.put(node_id, a);
      sd_streams.put(node_id, stream); 

      return a;
    }  

    float add_ir_level(int node_id) {

      ir_levels.put(node_id, 0.0);
      return(0.0);

    }

  
}
  
  
