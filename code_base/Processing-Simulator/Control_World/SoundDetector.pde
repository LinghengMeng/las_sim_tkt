/*!
 <h1> SoundDetector </h1>
 Sound Detector class
 
 \author Farhan Monower, Matt Gorbet
 */

/*!
 *  \class SoundDetector
 *  \brief Processing sensor class to create virtual Sound Detector extending Sensor
 *  \author Farhan Monower
 */
class SoundDetector extends Sensor {
  /*!
   *  \var DEFAULT_THRESHOLD
   *  The default threshold to send back data if passed
   */
  int DEFAULT_THRESHOLD = 5;
  /*!
   *  \var DEFAULT_FREQ
   *  The default polling frequency in hertz
   */
  int DEFAULT_FREQ = 10; //HZ

  /*!
   *  \var p_envelope
   *  the envelope pin of the sound detector
   */
  int p_envelope = 0; //the two pins of a sound detector
  /*!
   *  \var p_audio
   *  the audio pin of the sound detector
   */
  int p_audio = 0;

  /*!
   *  \var threshold
   *  the active threshold of the sound detector
   */
  int threshold = DEFAULT_THRESHOLD;

   /*!
   *  \var threshold
   *  the normalized value (above threshold) of the SD
   */
  int norm_value = 0;
  float norm_value_f = 0; // float to expose to patchable dataport

  /*!
   *  \var frequency
   *  the active frequency of the sound detector for sending back data
   */
  int frequency = DEFAULT_FREQ;

  /*!
   *  \var readme
   *  tells the timing loop if its time to read the detector and send back data
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
  float test_sd = 0.0;

  /*!
   *  \var push_value
   *  TODO
   */
  boolean push_value = false;

  /*!
   *  \var my_level
   *  TODO
   */
  Amplitude my_level;


  /*!
   *  \fn SoundDetector()
   *  \brief default constructor for the Sound Detector
   *  \return none
   */
  SoundDetector() {

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
      System.out.println("An empty config string was passed to SD " + des.device_number + " on Node " + parent_.node_id);
      installed = false;
      return;
    }

    super.install(n, pos, p, parent_, des);
    p_audio = uid;
    p_envelope = p;

    parse_config_string(des.config);
    last_millis = millis();
    elapsed_millis = 0;

    // for virtual sensor

    virtual_width = 40;
    virtual_height = 90;
    virtual_depth = 2;   // not used yet

    if(Sound.list().length==0){
      println("Warning: no sound device is detected!");
    }else{
      my_level = gui.add_sd_level(parent_.node_id);
    }
    
//    my_level = gui.sd_levels[des.device_number];

    //// set up the patchable, same as IR sensor

    println("  Setting up SD patcher ..." );


    patchable = new Patchable(this);
    patchable.realName = n;
    patchable.displayName = n;
    patchable.behaviour = "Sensors";  // not using this yet, just might be useful someday?

    // input ports:
  
    // output ports:
    patchable.dataPorts.add(new DataPort("norm_value_f"));

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

    //  update from the computer mic (returning as an int between 0 and 1024 for consistency w SD)    
    //return( (255.0) * my_level.analyze()  );
    // println("my_level: " + my_level.analyze() + " - returning: " + 1024 * my_level.analyze());
    // return( 1024.0 * my_level.analyze()) ;
    test_sd += 20;
    if(test_sd > 1024) test_sd = 0;
    // print("test_sd:"+test_sd);
    return (test_sd);
  }

  /*!
   *  \fn read_envelope()
   *  \brief supposed to read the envelope pin, currently just calls the read_value() function
   *  \return an integer version of the read_value()
   */
   int read_envelope() {
    readme = false;
    // norm_value_f = my_level.analyze();  // this gets set by Control.
    return  int(read_value());
  }

  /*!
   *  \fn read_audio()
   *  \brief supposed to read the audio pin, currently just calls the read_value() function. Not really implemented yet.
   *  \return an integer version of the read_value()
   */
   int read_audio() {       // not really implemented
    readme = false;
    return  int(read_value());
  }

  /*!
   *  \fn is_triggered()
   *  \brief checks if the current reading is above the specified threshold
   *  \return If the reading > threshold, return true. If reading < threshold return false.
   */
  boolean is_triggered() {
    if (read_envelope() > threshold){
      print("is triggered");
      return true;
    }else{
      print("not triggered");
      return false;
    }
  }

  /*!
   *  \fn update()
   *  \brief called to update the detector and check if its time for polling
   *  \return none
   */
  void update() {

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

   String conf_string = new String("ENVELOPEPIN " + p_envelope + ";" +
                            "THRESHOLD " + threshold + ";" + 
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
         success = configure_sd(command);
      }
      // parse the command
    }
    return success;
  }

   /*! 
   *  \fn configure_sd(String[] params)
   *  \param params
   *  \return none
   */
  synchronized boolean configure_sd(String[] params) {
    String argument = params[0];

    if (argument.equals("ENVELOPEPIN"))
    {
      p_envelope = int(params[1]);
      return true;
    } else if (argument.equals("INVERT"))
    {
      if(params[1].equals("TRUE")) {
        int temp_pin = p_audio;
        p_audio = p_envelope;
        p_envelope = temp_pin;
      }
      return true;
    } else if (argument.equals("THRESHOLD")) {
      threshold = int(params[1]);
      return true;
    } if (argument.equals("FREQUENCY")) {
      frequency = int(params[1]);
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

      int v = read_envelope();
      cur_value = v;
       //print("." + v + ".");

      if (v > threshold) {
      
        // send message  - note we are sending difference (above threshold)   
        network.write_message("/NODE/SD_PT_SAMPLING_CONTROL/" + str(parent.node_id) + " " + str(int(v-threshold)));
      
      } else {

        // zero it with one more message if it falls below thresh. 
        if(cur_value > threshold) {
           network.write_message("/NODE/SD_PT_SAMPLING_CONTROL/" + str(parent.node_id) + " " + 0);   
        }
      }
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
    if (selected_sensor != null && selected_sensor == this) {

      if (gui.sdChart.getDataSet("sensor_values") == null) {
          gui.sdChart.addDataSet("sensor_values");
      }
      if (gui.sdChart.getDataSet("thresh_values") == null) {
          gui.sdChart.addDataSet("thresh_values");
      }

      for (int t = 0; t < gui.sdChart.getWidth() ; t++) {
        gui.sdChart.push("thresh_values", threshold);
      }

      // update the waveform here

      if (push_value) {
        gui.sdChart.push("sensor_values", cur_value);
      }


      // Open SD settings since we are looking at an SD
      if (gui.sd_settings != null && !gui.sd_settings.isVisible() ) {
          gui.sd_settings.show();
          gui.sd_settings.open();

          apply_sd_settings_to( int(gui.which_sds.getValue()) );

       // Set the GUI values to current SD
       println("setting gui values to current values from this SD \n threshold: " + threshold + " auto: " + autosample + " local: " + use_local + " freq: " + frequency);
          gui.sd_thresh_slider.setValue(threshold);
          gui.sd_polling.setValue(autosample); 
          gui.sd_live_or_local.setValue(use_local);
          gui.sd_freq_slider.setValue(frequency);
       

        // test pattern if not live
        for (int i = 0; i < gui.sdChart.getWidth() ; i++ ) {
          gui.sdChart.push("sensor_values", 0);
          gui.sdChart.push("thresh_values", threshold);
        }



        gui.sdChart.show();     
        println("setting name to " + name + "  NODE ID: " + this.parent.node_id);
        gui.sdChart.setCaptionLabel( name + "  NODE ID: " + this.parent.node_id + " aud: " + p_audio + " env: " + p_envelope);

      }

        if(drawgui) {
        // draw indicator line:
        float sx = screenX(0, 0, 0);  // we have already translated to position
        float sy = screenY(0, 0, 0);
   
        stroke(0, 100);     
          
        cam.beginHUD();
        stroke(0, 100);
        line( sx, sy, gui.sdChart.getWidth() + gui.sd_settings.getAbsolutePosition()[0] + gui.sdChart.getPosition()[0], gui.sd_settings.getAbsolutePosition()[1] + gui.sdChart.getPosition()[1]+gui.sdChart.getHeight() );
        cam.endHUD();
        }
    }  else {
      gui.sdChart.removeDataSet(name+"_sensor_values");
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

    if (mouseover || (selected_sensor != null && (selected_sensor.designator.device_type.equals("SD") && (selected_sensor == this || all_sensors_selected) && drawgui) )) { 
      stroke(255, 200, 0, lostalpha);
    }

    if (mouseover ) {
      fill(255, 200, 0, lostalpha);
    } else {
      fill(map(max(cur_value, threshold), threshold, 1024, 70, 255), 70, 90, lostalpha);
      // fill(70, 70, 90);
    }

    arc(0, 0-virtual_height/4, virtual_width, virtual_width, PI, TWO_PI);
    rect(0, 0, virtual_width, virtual_height/2);
    arc(0, virtual_height/4, virtual_width, virtual_width, 0, PI);
  }
}
