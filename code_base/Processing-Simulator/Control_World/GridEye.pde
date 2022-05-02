class GridEye extends Sensor {
 

  float motion_threshold = 2.00;  // never send motion for now
  float presence_threshold = 0.15;

  int polling_frequency = 20;

  boolean setBackground = false;

  int frameskip = 1;
  float interest_thresh = 1000.0;
  float noise_thresh = 0.3f; 
  float overall_relax = 0.75;
  float output_angle = 0f;
  boolean stream = false;
  float current_presence;
  PVector current_vector;
  float current_vector_x;
  float current_vector_y;
  float motion_heading;
  float motion_magnitude;

  boolean readme = false;
  int last_millis = millis();
  int elapsed_millis = 0;

  boolean reading_live_data = true;

  Client gridEyeClient_live;

  GridEye() {
    super();
    current_vector = new PVector(0f, 0f);
    current_presence = 0f;
    motion_heading = 0f;
    motion_magnitude = 0f;
  }

  void install(String n, PVector pos, int p, Node parent_, DeviceIdentifier des) {
    //if (config_string.equals("")) {
    // System.out.println("An empty config string was passed to GE " + des.device_number + " on Node " + parent_.node_id);
    // installed = false;
    // return;
    //}

    super.install(n, pos, p, parent_, des);
    

     parse_config_string(des.config);

    last_millis = millis();
    elapsed_millis = 0;
        
    // for virtual sensor icon
    
    virtual_width = 45;
    virtual_height = 45;
    virtual_depth = 2;   // not used yet

    //// set up the patchable, same as IR sensor

    println("  Setting up GE patcher ..." );


    patchable = new Patchable(this);
    patchable.realName = n;
    patchable.displayName = n;
    patchable.behaviour = "Sensors";  // not using this yet, just might be useful someday?

    // input ports:
  
    // output ports:
    patchable.dataPorts.add(new DataPort("current_presence"));
    patchable.dataPorts.add(new DataPort("motion_heading"));
    patchable.dataPorts.add(new DataPort("motion_magnitude"));

    // add my Patchable to the BehaviourEngine's patchables hashmap.
    // sensors(???) .patchables.put(n, patchable);   

    patcher.addPatchable(patchable);
    
  }

  float read_value() {
    
    println(" GridEye doesn't know how to read_value...  (returning 0.0)");
    
    return(0.0);
    
  }

/*!
 *  \fn get_config_string()
 *  \brief MATT - TODO
 *  \param return a full config string
 *  \return none
 */
String get_config_string() {

   String conf_string = new String("FREQUENCY " + polling_frequency + ";" +
                            "THRESHOLD_MOTION " + motion_threshold + ";" + 
                            "THRESHOLD_PRESENCE " + presence_threshold + ";" +
                            "INTEREST_THRESHOLD " + interest_thresh + ";" +
                            "NOISE_THRESHOLD " + noise_thresh + ";" +
                            "OVERALL_RELAX " + overall_relax + ";" + 
                            "FRAMESKIP " + frameskip + ";" +
                            "ANGLE_ADJUST " + output_angle + ";");

   return conf_string;

}



  void update() {
   
 

    elapsed_millis = millis() - last_millis;
  }

  boolean parse_config_string(String config_string)
  {
    int num_commands = get_num_commands(config_string);
    boolean success = true;
 
    for (int i = 0; i < num_commands; i++)
    {
      String[] command = get_command(config_string, i);
      if (command[0].length() != 0)
      {
        configure_grideye(command);

       // String keyword = command[0];
       // String arguments = command[1];

      }
      // otherwise, parse the command
    }
    return success;
  }

  /*! 
   *  \fn configure_grideye(String[] params)
   *  \brief MATT - TODO
   *  \param params
   *  \return none
   */
  synchronized void configure_grideye(String[] params) {
    String argument = params[0];
    if (argument.equals("FREQUENCY")) {
      polling_frequency = int(params[1]);
    } else if (argument.equals("THRESHOLD_MOTION")) {
      motion_threshold = float(params[1]);
    } else if (argument.equals("THRESHOLD_PRESENCE")) {
      presence_threshold = float(params[1]);
    } else if (argument.equals("INTEREST_THRESHOLD")) {
      interest_thresh = float(params[1]);
    } else if (argument.equals("NOISE_THRESHOLD")) {
      noise_thresh = float(params[1]);
    } else if (argument.equals("OVERALL_RELAX")) {
      overall_relax = float(params[1]);
    } else if (argument.equals("FRAMESKIP")) {
      frameskip = int(params[1]);
    } else if (argument.equals("ANGLE_ADJUST")) {
      output_angle = float(params[1]);
    }
  }

  synchronized void go() {

    // Teensy Code ---------------------
    

    // Processing Code------------------

    draw_to_screen();
  }

  /////  SENSOR MESSAGING ==========================
  // overriding for Grideye to include preprocessed sensory data:
  OscMessage add_raw_output(OscMessage m) { 
    if(uid!=0){
        m.add(uid);                // add int for pin number
        float cur_pre = current_presence;
        float cur_vec_x = current_vector_x;
        float cur_vec_y = current_vector_y;
        float mot_heading = motion_heading;
        float mot_magnitude = motion_magnitude;
        m.add(cur_pre);
        m.add(cur_vec_x);
        m.add(cur_vec_y);
        m.add(mot_heading);
        m.add(mot_magnitude);
    }
    return(m);
  }

  //whatever else frontend visualization is required
  
  void update_info() {
      
  if (selected_sensor != null && selected_sensor == this) {
  
  // show the settings panels IF they aren't showing already...
  // Open GE settings since we are looking at a GE

    ge.cur_ge = this;

      if (gui.grp_vizbg != null && !gui.grp_vizbg.isVisible() ) {
    gui.grp_prerec.show();
    gui.grp_analysis.show();
    gui.grp_simulation.show();
    gui.grp_vizbg.show();
    gui.grp_vizbg.open();
    all_sensors_selected = false;  // can't adjust all grideyes at the same time, no matter what control_world.pde says :)

    // autostream grideye on open
    gui.ge_stream.setState(true);
   
    // Set the GUI values to current GE - should only happen on open.
          println("setting gui values to current values from this GE \n frequency: " + polling_frequency + " frameskip: " + frameskip + " interest_thresh: " + interest_thresh + 
                  " noisethresh: " + noise_thresh + " overall_relax: " + overall_relax +
                  " angle_adjust: " + output_angle + " motion_threshold" + motion_threshold + " stream: " + stream);

          gui.ge_frequency.setValue(polling_frequency);
          gui.ge_frameskip.setValue(frameskip);
          gui.ge_interest_thresh.setValue(interest_thresh); 
          gui.ge_noise_thresh.setValue(noise_thresh);
          gui.ge_angle_adjust.setValue(output_angle);
          gui.ge_overall_relax.setValue(overall_relax);
          gui.ge_presence_threshold.setValue(presence_threshold);
          gui.ge_motion_threshold.setValue(motion_threshold);
          gui.ge_stream.setValue(stream);


      }

    // set the visualization position on-screen, based on the settings panels
    canvas_xo = int(gui.grp_vizbg.getAbsolutePosition()[0] + (270 - (9 * (canvasw/20)) ) /2 );
    canvas_yo = int(gui.grp_vizbg.getAbsolutePosition()[1] );
      
    if (drawgui) {   
     // draw indicator line  
     float sx = screenX(0, 0, 0);  // we have already translated to position
     float sy = screenY(0, 0, 0);
       
     cam.beginHUD();
     stroke(0, 100);
     line( sx, sy, gui.grp_vizbg.getAbsolutePosition()[0] + gui.grp_vizbg.getWidth() , canvas_yo + gui.grp_vizbg.getBackgroundHeight() ); 
     cam.endHUD();   
    }


    String parent_pi_address = dl.find_nodes_parent_rpi(this.parent.node_id).my_address;

    if(gesim && gui.gridEyeClient_local == null) {
      try {       
           gui.open_ge_client( parent_pi_address, network.grideye_local_port, false );
           //gui.update_ge_panel(ge);
           } catch(Exception e) {
             println(" EXCEPTION opening stream from grideye (want local) " + name);
             return;
           }

    }
    
    if(!gesim && run_mode==LIVE && gui.gridEyeClient_live == null && !(monitor.lost_devices.contains(parent_pi_address)) ) {
      try {       
           gui.open_ge_client( parent_pi_address, network.grideye_live_port, true );
           //gui.update_ge_panel(ge);
           } catch(Exception e) {
            
             println(" EXCEPTION opening live stream from grideye " + name);
             return;
           }
    } 
    
    gui.update_ge_panel(ge);
  }           
}
   
  void draw_me(boolean mouseover) {
   

  int lostalpha = 255;
  RPi parent_pi = dl.find_nodes_parent_rpi(this.parent.node_id);

  if( monitor.lost_devices.contains(parent_pi.my_address) || monitor.lost_devices.contains(str(this.parent.node_id)) ) {
   lostalpha = 70;
  }

    stroke(0, lostalpha);

  if (mouseover || (selected_sensor != null && (selected_sensor.designator.device_type.equals("GE") && (selected_sensor == this || all_sensors_selected) && drawgui) )) { 
        stroke(255, 200, 0, lostalpha); 
   }
      
       if(mouseover ) {
       fill(255, 200, 0, lostalpha);  
       } else {
       fill(80, 70, 70, lostalpha);
       }
       
       //println("    current presence: " + current_presence);
       
       //rotate(PVector.angleBetween(new PVector(100, 0), current_vector));
       //line(0, 0, current_vector.x * 100, current_vector.y * 100);
       rotate(motion_heading);
       line(0f, 0f, motion_magnitude * 2 * virtual_height* (1+current_presence), 0f);

       rect(0, 0, virtual_width * (1+current_presence), virtual_height* (1+current_presence));

       if(!mouseover) {
       fill(80 +  current_presence * 175,
            70 +  current_presence * 185,
            70 +  current_presence * 185,
            lostalpha);
       }

       ellipse(0, 0, virtual_width* (1+current_presence), virtual_height* (1+current_presence));
       
    }
          
}   
  
