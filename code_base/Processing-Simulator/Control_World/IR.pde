/////////////////////////////
//
// PBAI/LASG
// IR Class
// Created: December 07 2018
// Author(s): Michael Lancaster
// Description: Subclass of Sensor, manages an IR sensor.

// TODO - Implement

class IR extends Sensor {

/*!
   *  \var DEFAULT_THRESHOLD
   *  The default threshold to send back data if passed
   */
  int DEFAULT_THRESHOLD = 300;
  /*!
   *  \var DEFAULT_FREQ
   *  The default polling frequency in hertz
   */
  int DEFAULT_FREQ = 15; //HZ

  /*!
   *  \var p_ir
   *  the input pin of an ir detector
   */
  int p_ir = 0; 

/*!
   *  \var threshold
   *  the active threshold of the IR
   */
  int threshold = DEFAULT_THRESHOLD;

   /*!
   *  \var threshold
   *  the normalized value (above threshold) of the IR
   */
  int norm_value = 0;
  float pct_value = 0.0;

  int IR_MY_MAX = 750;  // ceiling for IR detectors?  should be adjustable, (not 1024)

  /*!
   *  \var frequency
   *  the active frequency of the IR for sending back data
   */
  int frequency = DEFAULT_FREQ;

  /*!
   *  \var readme
   *  tells the timing loop if its time to read the IR and send back data
   */
  boolean readme = false;

  /*!
   *  \var last_millis
   *  Used for timing to send back messages to control
   */
  int last_millis = millis();

  /*!
   *  \var elapsed_millis
   *  Used for timing to send back messages to control
   */
  int elapsed_millis = 0;

  /*!
   *  \var autosample
   *  Boolean to control if autosampling is on. True to turn on autosampling, false to turn it off
   */
  boolean autosample = true;

  /*!
   *  \var use_local
   *  TODO
   */
  boolean use_local = false;

  float test_ir = 0.0;

  /*!
   *  \var push_value
   *  TODO
   */
  boolean push_value = false;

  /*!
   *  \var my_level
   *  TODO
   */
  float my_level;


/*!
   *  \fn IR()
   *  \brief default constructor for the IR sensor
   *  \return none
   */
  IR() {

    super();
  }
  
/*!
   *  \fn install(String n, PVector pos, int p, Node parent_, DeviceIdentifier des, String config_string)
   *  \brief Used to install the sound detector into the visualization
   *  \param n the name of the sound detector
   *  \param pos the PVector position of the sound detector in the sculpture
   *  \param p the pin, UID identifier
   *  \param parent_ the parent Node of this sound detector
   *  \param des the DeviceIdentifier that stores the 2 char and 1 num identifier for this device e.g. SD1
   *  \param config_string the configuration string that configures this device
   *  \return none
   */
  void install(String n, PVector pos, int p, Node parent_, DeviceIdentifier des) {
    if (des.config.equals("")) {
      System.out.println("Warning - An empty config string was passed to IR " + des.device_number + " on Node " + parent_.node_id);
    //  installed = false;
    //  return;
    }

    super.install(n, pos, p, parent_, des);
    p_ir = p;

    last_millis = millis();
    elapsed_millis = 0;

    // for virtual sensor

    virtual_width = 80;
    virtual_height = 40;
    virtual_depth = 2;   // not used yet

    my_level = gui.add_ir_level(parent_.node_id);

    // my_level = gui.ir_levels[des.device_number];

    //// set up the patchable

    println("  Setting up IR patcher ..." );


    patchable = new Patchable(this);
    patchable.realName = n;
    patchable.displayName = n;
    patchable.behaviour = "Sensors";  // not using this yet, just might be useful someday?

    // input ports:
  
    // output ports:
    patchable.dataPorts.add(new DataPort("pct_value"));


    // add my Patchable to the BehaviourEngine's patchables hashmap.
    // sensors(???) .patchables.put(n, patchable);   

    patcher.addPatchable(patchable);    

  }

  /*!
   *  \fn read_value()
   *  \brief returns the sound reading from your computer's mic
   *  \return a float of the sound reading, on the conputer it reads your mic level
   */
  float read_value() {

     //return( 1024.0 * my_level ) ;
     test_ir += 0.02;
     if(test_ir > 1.0) test_ir = 0;
 
     return (test_ir);
  }

  /*!
   *  \fn is_triggered()
   *  \brief checks if the current reading is above the specified threshold
   *  \return If the reading > threshold, return true. If reading < threshold return false.
   */
  boolean is_triggered() {
    if (read_value() > threshold){
      // print("is triggered");
      return true;
    }
      
    return false;
  }

   /*!
   *  \fn update()
   *  \brief called to update the detector and check if its time for polling
   *  \return none
   */
  void update() {

    //calculate normalized value 
    norm_value  = max(0, int(cur_value - threshold)); // no negatives;
    pct_value   = float(norm_value)/float(IR_MY_MAX-threshold);

                 

    elapsed_millis = millis() - last_millis;

    if (autosample && (elapsed_millis >= (1000/frequency)) ) {
      readme = true;   // set a flag so that 'go' loop will read and message from this
      last_millis = millis();
    }
  }



  /*!
  *  \fn get_config_string()
  *  \brief MATT - TODO
  *  \param return a full config string
  *  \return none
  */
  String get_config_string() {

    String conf_string = new String("THRESHOLD " + threshold + ";" + 
                              "FREQUENCY " + frequency + ";" +
                              "POLLING " + (autosample ? "ON" : "OFF")+ ";" +
                              "USE_LOCAL " + (use_local ? "LOCAL" : "LIVE") + ";");

    return conf_string;

  }



/*!
   *  \fn prase_config_string(String config_string)
   *  \brief Used to parse the config string
   *  \param config_string the configuration string to parse
   *  \return true if the string was processed correct, else false
   */
 boolean parse_config_string(String config_string)
  {
    int num_commands = get_num_commands(config_string);
    boolean success = true;
 
    for (int i = 0; i < num_commands; i++)
    {
      String[] command = get_command(config_string, i);
      if (command[0].length() != 0)
      {
        success = configure_ir(command);
      }
      // otherwise, parse the command
    }
    return success;
  }

  /*! 
   *  \fn configure_ir(String[] params)
   *  \param params
   *  \return none
   */
  synchronized boolean configure_ir(String[] params) {
    String argument = params[0];
    if (argument.equals("FREQUENCY")) {
      frequency = int(params[1]);
      return true;
    } else if (argument.equals("THRESHOLD")) {
      threshold = int(params[1]);
      if(threshold >= IR_MY_MAX) threshold = IR_MY_MAX-1;
      return true;
    } else if (argument.equals("POLLING")) {
      autosample = (params[1].equals("ON"));
      return true;
    } else if (argument.equals("USE_LOCAL")) {
      use_local = (params[1].equals("LOCAL"));
      return true;
    } 
    return false;
  }

/*!
   *  \fn go()
   *  \brief on Processing, sends messages back to control and updates visualization
   *  \return none
   */
  synchronized void go() {

    // Teensy Code ---------------------


    // Processing Code------------------

    // messaging:

    if (use_local && readme) {

      int v = int(IR_MY_MAX * read_value());
      
      // int v = read_envelope();

      cur_value = v;

      // send message  -  send cur_value even though we calculated norm_value 
      network.write_message("/NODE/IR_PT_SAMPLING_CONTROL/" + str(parent.node_id) + " " + str(cur_value));
      readme = false;
    }

    draw_to_screen();
  }

  //whatever else frontend visualization is required
  /*!
   *  \fn update_info()
   *  \brief helper function to do drawing of visualization
   *  \return none
   */
  void update_info() {

    super.update_info();
    if (selected_sensor != null && selected_sensor == this) {

      if (gui.irChart.getDataSet("sensor_values") == null) {
          gui.irChart.addDataSet("sensor_values");
          for (int t = 0; t < gui.irChart.getWidth() ; t++) {
            gui.irChart.push("sensor_values", 0);
          }
      }
    
      if (gui.irChart.getDataSet(name+"raw_values") == null) {
          gui.irChart.addDataSet(name+"raw_values");
          gui.irChart.setColors(name+"raw_values", color(70, 70, 160));

          for (int t = 0; t < gui.irChart.getWidth() ; t++) {
            gui.irChart.push(name+"raw_values", 0);
          }
      }

      if (gui.irChart.getDataSet("thresh_values") == null) {
          gui.irChart.addDataSet("thresh_values");
      }

      for (int t = 0; t < gui.irChart.getWidth() ; t++) {
        gui.irChart.push("thresh_values", threshold);
      }

      // update the waveform here

      if (push_value) {
        gui.irChart.push("sensor_values", 1024 * pct_value);
        gui.irChart.push(name+"raw_values", cur_value);
        gui.irChart.setCaptionLabel( name + "  NODE ID: " + this.parent.node_id + " env: " + p_ir + " Raw: " + cur_value + " %: " + nf(pct_value, 0,2));
      }


      // Open IR settings since we are looking at an IR
      if (gui.ir_settings != null && !gui.ir_settings.isVisible() ) {
          gui.ir_settings.show();
          gui.ir_settings.open();

          apply_ir_settings_to( int(gui.which_irs.getValue()) );

       // Set the GUI values to current IR
       println("setting gui values to current values from this IR \n threshold: " + threshold + " auto: " + autosample + " local: " + use_local + " freq: " + frequency);
          gui.ir_thresh_slider.setValue(threshold);
          gui.ir_polling.setValue(autosample); 
          gui.ir_live_or_local.setValue(use_local);
          gui.ir_freq_slider.setValue(frequency);
       

        // // test pattern if not live
        // for (int i = 0; i < gui.irChart.getWidth() ; i++ ) {
        //   gui.irChart.push("sensor_values", 0);
        //   gui.irChart.push("thresh_values", threshold);
        // }
 
        gui.irChart.setCaptionLabel( name + "  NODE ID: " + this.parent.node_id + " env: " + p_ir + " Raw: " + cur_value + " Norm: " + nf(pct_value, 0,2));
        gui.irChart.show();     

      }

      if(drawgui) {
        // draw indicator line:
        float sx = screenX(0, 0, 0);  // we have already translated to position
        float sy = screenY(0, 0, 0);
   
        stroke(0, 100);     
          
        cam.beginHUD();
        stroke(0, 100);
        line( sx, sy, gui.irChart.getWidth() + gui.ir_settings.getAbsolutePosition()[0] + gui.irChart.getPosition()[0], gui.ir_settings.getAbsolutePosition()[1] + gui.irChart.getPosition()[1]+gui.irChart.getHeight() );
        cam.endHUD();
        
      }  else {
        gui.irChart.removeDataSet(name+"_sensor_values");
      }
    }
  }
  
  /*!
   *  \fn draw_me(boolean mouseover)
   *  \brief does drawing if the sensor was moused over
   *  \param moseover true if was moused over else false
   *  \return none
   */
  void draw_me(boolean mouseover) {


  int lostalpha = 255;
  RPi parent_pi = dl.find_nodes_parent_rpi(this.parent.node_id);

  if( monitor.lost_devices.contains(parent_pi.my_address) || monitor.lost_devices.contains(str(this.parent.node_id)) ) {

   lostalpha = 70;

  }

    stroke(0, lostalpha);
    fill(0, lostalpha);

    if (mouseover || (selected_sensor != null && (selected_sensor.designator.device_type.equals("IR") && (selected_sensor == this || all_sensors_selected) && drawgui) )) { 
      stroke(255, 200, 0, lostalpha);
    }

    rect(0, 0,    virtual_width* (1+pct_value/2), virtual_height* (1+pct_value/2));

    if (mouseover ) {
      fill(255, 200, 0, lostalpha);
    } else {
      fill(map(pct_value, 0, 1, 70, 255), 70, 90, lostalpha);
      // fill(70, 70, 90);
    }
    
     translate(0,0,5);

     ellipse(0-(virtual_width*(1+pct_value/2))/4, 0, virtual_width/4* (1+pct_value/2), virtual_width/4* (1+pct_value/2));
     ellipse(  (virtual_width*(1+pct_value/2))/4, 0, virtual_width/4* (1+pct_value/2), virtual_width/4* (1+pct_value/2));
     
  }
  }


