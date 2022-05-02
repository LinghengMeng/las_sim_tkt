/*!
 <h1> Control </h1>
 Control object that creates and sends messages as a control laptop
 
 \author Matt Gorbet, Et al.
 
 */

/*! \class Control
 *  \brief Control thread on computer
 */
class Control extends Thread
{
  /*!
   *  \var my_address
   *  stores the address of the control object
   */
  String my_address = "";

  /*!
   *  \var frame
   *  Used in rendering graphics
   */
  int frame = 0;

  /*!
   *  \var control_frame_render_time
   *  how many milliseconds inbetween sending full frame messages, at least needs to be 1 to prevent buffer overflow
   */
  int control_frame_render_time = 20;
  int flipflop = 1;

  /*!
   *
   * \var influence_update_times
   * how many millisectonds to wait between sending full influence update times - need to throttle for stability.
   */
  ConcurrentHashMap<String, Long> influence_update_times;
  long influence_frame_time = 25;       // how often to allow influences to update?

  /*!
   *  \var last_millis
   *  used for timekeeping in control main loop
   */
  long last_millis;

  /*!
   *  \var current_millis
   *  used for timekeeping in control main loop
   */
  long current_millis;  

  int     delay_message_test = 0;
  boolean trigger_wav_test = false;
  boolean fade_wav_test = false;
  boolean message_send_ramp_up = false;
  boolean message_send_ramp_down = false;
  boolean sound_sensor_poll = false;
  boolean turn_off_auto_sample = false;
  boolean snapper = false;
  boolean set_sampling_freq = false;
  boolean influence_tester = false;
  
  boolean killing_actuators = false;
  boolean random_actuator_on = true;
  boolean grideye_presence_on = false;   // dirct mapping of presence to influence 
  boolean ambient_wave_on = true;
  boolean begin_grideye_presence = false;   // trigger grideyes to send presence values  // deprecated
  boolean initialize_sensors = true;  // flag to load all sensor config strings, including Grideyes.

  boolean mo_test = false;
  boolean dr_test = false;
  boolean wt_test = false;

  boolean nodes_control_influence   = true;
  boolean nodes_control_intensities = true;  // excitements just get rendered, any fading is superposited

  boolean update_sd_polling = false;
  boolean update_sd_frequency = false;
  boolean update_sd_threshold = false;

  float moth_attenuation_timeout = 20000.0;
  float moth_attenuation_time;
  float moth_attenuation;
  
  float resend_omni_frequency = 2000;  // re-send the omni master valume every 2 seconds.
  float resend_omni_counter = 0;
  float resend_omni_toggle = -0.01;     // tiny difference to make sure sliders move.


  /*!
   *  \var trigger_wav_test_track
   *  testing tracks for WAV trigger
   */
  int trigger_wav_test_track = 1;/*!
   *  \var trigger_wav_test_solo
   *  testing tracks for WAV trigger
   */
  int trigger_wav_test_solo = 32;

  /*! \fn Control()
   *  \brief Constructor for control
   *  \return none.
   */
  Control() {

    // name thread:
    super("Control_thread");

    this.my_address = network.my_address;
    
    last_millis = tl_millis();
    resend_omni_counter = tl_millis();
    influence_update_times = new ConcurrentHashMap<String, Long>();
    reset_moth_attenuation();    
    // subscribe_actuators(true);         // need to call this after they are all initialized - call in Control_World for now.

 }

  void subscribe_actuators(boolean state) 
  {
 // hack:  subscribe all moths to GE
 //   subscribe_actuators_by_type("MO", "GE", state);

  // THIS SHOULD BE DEPRECATED SOON AND REPLACED WITH LOADING APPROPRIATE (or default) SUBSCRIPTION SETS  -mg, feb 2020


 // standard influence sets (from Poul originally)
  //  subscribe_actuators_by_type("DR", "EC", state);  // Electric cells
    subscribe_actuators_by_type("DR", "EXP", state); // presence excitors
    subscribe_actuators_by_type("MO", "EXP", state); // presence excitors
    subscribe_actuators_by_type("RS", "EXP", state);  
    subscribe_actuators_by_type("PC", "EXP", state);  
    subscribe_actuators_by_type("DR", "GR", state);  // flow field  (also repurposed as GridRunner)
    subscribe_actuators_by_type("RS", "GR", state); 
    subscribe_actuators_by_type("PC", "GR", state); 
  //  subscribe_actuators_by_type("RS", "RH", state); 
    subscribe_actuators_by_type("PC", "IR", true);   // always keep local behaviour subscribed ?
    subscribe_actuators_by_type("SM", "IR", true);   // always keep local behaviour subscribed ?
    subscribe_actuators_by_type("MO", "WV", state);  
    
  //  subscribe_actuators_by_type("RS", "WV", state); // ambient waves
  //  subscribe_actuators_by_type("PC", "WV", state); // ambient waves
  //  subscribe_actuators_by_type("DR", "RN", state); // noise
  }

  /*! \fn run()
   *  \brief main loop for control, sends and receives messages and does parsing logic
   *  \return none.
   */
  public void run() {
    while (true) {

      long elapsed_millis = tl_millis()-last_millis;
      this.frame = get_frame();

      // work around Ableton bug that doesn't always "catch" volume slider changes:

      if(tl_millis() - resend_omni_counter > resend_omni_frequency) {  // every so often, resend the omni volume 
           if(excitorBehaviour == null) continue;                   // make sure excitorBehaviour (and OmniVolume) has started

           resend_omni_toggle *= -1;                                  // alternate adding, then subtracting a
           excitorBehaviour.omniMasterVolume += resend_omni_toggle;   // tiny difference to make sure sliders move
           if(excitorBehaviour.omniMasterVolume < 0) {                // this just catches case where it goes negative
              excitorBehaviour.omniMasterVolume *= -1;
              resend_omni_toggle *= -1;
           }
           excitorBehaviour.prevOmniMasterVolume = -1;                // -1 forces a re-send of omniMasterVolume

           resend_omni_counter = tl_millis();

      }

      
      if( show_control_use_timer && show_control_awake ) 
      {  // if we are using timer and the sleep button hasn't been manually pushed
        if ( (hour() > show_control_stop_hour /* 23 > 20 */ || (hour() == show_control_stop_hour && minute() > show_control_stop_minute)) || 
             (hour() < show_control_start_hour || (hour() == show_control_start_hour && minute() < show_control_start_minute)) )
        {
          if (!sleepmode)
          {  
                go_to_sleep();
           //     show_control_awake = !sleepmode;
           //     gui.show_control_sleep.setCaptionLabel((show_control_awake==true) ? " SLEEP ":" WAKE ");
          }
        } else 
          {
            if (sleepmode)
            { 
                wake_up();
            //    show_control_awake = !sleepmode;
            //    gui.show_control_sleep.setCaptionLabel((show_control_awake==true) ? " SLEEP ":" WAKE ");
            }
          }
      }

      // if(!show_control_use_timer) {

      //    sleepmode = !show_control_awake;

      // }



      //READ MESSAGES FROM External Systems ======================================
      message_OSC external_msg = external_comms.get_message();
      if (external_msg != null) {

        //DO SOMETHING WITH EXTERNAL MESSAGES
        println("** Received External message to Control: " + external_msg.get_code() + " --- " + external_msg.get_uncut_data());
      }

      // READ MESSAGES =============================================

      message_OSC virtual_message = network.get_message_virtual(this.my_address);
      message_OSC real_message = null;

      if (network.is_live||sync_unity_sensor_reading)
        real_message = network.get_message_real();

      if (virtual_message != null) {
        //do something with virtual messages
        //println("** Received Virtual message to Control: " + virtual_message.get_code() + " --- " + virtual_message.get_uncut_data());
      
        if(virtual_message.get_code().contains("GE_PRESENCE")) {
           update_ge_presence(virtual_message);
        }
        else if (virtual_message.get_code().contains("GE_MOTION")) {
          //do something
           update_ge_motion(virtual_message);

         }
        else if(virtual_message.get_code().contains("SD_PT_SAMPLING_CONTROL")) {
           update_sd_value(virtual_message);
        }        
        else if(virtual_message.get_code().contains("IR_PT_SAMPLING_CONTROL")) {
           update_ir_value(virtual_message);
        }       

      
      }

      if (real_message != null) {
        //do something when you receive a message from a real pi
        //println("** Received Real message to Control: " + real_message.get_code() + " --- " + real_message.get_uncut_data());

        if (real_message.get_code().contains("GE_PRESENCE")) {
           update_ge_presence(real_message);
        }
        else if (real_message.get_code().contains("GE_MOTION")) {
          //do something
           update_ge_motion(real_message);
         }
         else if(real_message.get_code().contains("SD_PT_SAMPLING_CONTROL")) {
           update_sd_value(real_message);
         }       
        else if(real_message.get_code().contains("IR_PT_SAMPLING_CONTROL")) {
           update_ir_value(real_message);
         }        
         else if(real_message.get_code().contains("NODE_LOST")) {
             String sender = real_message.get_code().split("/")[3];
             monitor.node_lost(sender, real_message.get_data()[0]);
         }
         else if(real_message.get_code().contains("NODE_FOUND")) {
             String sender = real_message.get_code().split("/")[3];
             monitor.node_found(sender, real_message.get_data()[0]);
         } 
         else if(real_message.get_code().contains("4D")) {
             network.write_message(real_message);
         }
         else if(real_message.get_code().contains("PING")) {
             println("PING from " + real_message.get_code().split("/")[3]);

         }

        // real message, so record last time I saw a pi

        String sender = real_message.get_code().split("/")[3];
        monitor.record_pi_seen(sender);

      }


        // add check for if it's a grideye motion vector:
        
        // for(all nodes)
        //  {
        //  for(all actuators)
        //  {
        //  float inf = get_grideye_motion_influence(motion vector, actuator.position, received_node_id); // node id is the GE node
        //  actuator.set_grideye_influence(inf);  // send a message to the actuator setting it's current grideye motion influence
        //  }
        //  }
         
      

      //exit if the stop messaging is active
      if (stop_messaging)
        return;


      // GUI Response settings

      if (update_sd_polling) {
          
      }

      if (test_current_actuator || paintbrush_osc)
      {

        if(actuator_test_type.equals("VECTORS")) {   // adjusting vectors - no test right now
           /*
            FlowVector v = null;

            if(!vectors_to_adjust.isEmpty()) {
                Iterator<FlowVector> iter = vectors_to_adjust.iterator();
            
                while(iter.hasNext()) {
                  v = iter.next();  
                  
                  //[ adjust vector here! ]

                  // NOTE removal test happens here to avoid concurrent modification (will this work?)
                  if(!v.near) {
                    iter.remove();
                    continue;
                  } 
                }
            }

            */
        } else {

          // run a quick test of the actuators you are hovering over using TAB.  Useful for confirming that the geometry of the piece is same as on screen
          Actuator a_to_test = null;
          try{

              // clear the average coord value, if we are averaging
              if(gui.coord_average.getValue()==1) {
                gui.coords_to_average.clear();
              }

            if(!actuators_to_test.isEmpty()) {
                //println("==" + actuators_to_test.toString());
                Iterator<Actuator> iter = actuators_to_test.iterator();
            
                while(iter.hasNext()) {
                  a_to_test = iter.next();  
                  
                  trigger(a_to_test);
                  
                  // also add it to average, if we are doing that
                  if(gui.coord_average.getValue()==1) gui.coords_to_average.add(a_to_test.position);
          
                  // NOTE removal test happens here to avoid concurrent modification (will this work?)
                  if(!a_to_test.near) {
                    iter.remove();
                    continue;
                  } 
                }
            }
            if(gui.coord_average.getValue()==1) gui.display_coords();
            else gui.display_coords(selected_actuator.position); 
          }  catch (Exception e) {
            // println(e);
          }
        }
        // paintbrush_osc = false;
      }


      //everything above this line is actual code that will remain in the code, below is temporary testing
      //==================================MESSAGE TESTS===========================================

      //// MESSAGE OUTPUTS =============================================

      //Sound sensor test==============================================
      //String[] sense = {""};
      //m = new message_OSC("/CONTROL/SD_PT_SAMPLING_CONTROL/" + this.my_address + "/435166", sense);
      //network.write_message(this.my_address, 435166, m);

      ////Button Press Message Sending============================================
      
      message_OSC m;
      if (trigger_wav_test) {

        trigger_wav_test = false;
      }

      if (fade_wav_test) {

        fade_wav_test = false;
      }

      if (delay_message_test > 0) {   // in 3.5s, set all DRs to 255 over 2s.  Then in 6s fade them out over 1s.
  
        int counter = 0;
        int target = 255;
        int ftime = 2000;
        int delay = 3000;

        if(delay_message_test == 2) {
           target = 0;
           ftime = 1000;      
           delay = 6000;
           delay_message_test = 0;
        } else {
           delay_message_test = 2;
        }
              
        for (Node node : dl.nodes.values())
          {
            ArrayList<String> temp_msg_storage = new ArrayList<String>();
            int dr_counter = 0;

            //if(node.node_id != 362340) continue;

            for (int i = 0; i < node.ACTUATOR_ARR_SIZE; i++)
            {
              if (node.my_double_rebel_stars[i].installed)
              {
                temp_msg_storage.add("DR" + Integer.toString(node.my_double_rebel_stars[i].designator.device_number + 1));
                temp_msg_storage.add(str(target));
                temp_msg_storage.add(str(ftime));
                dr_counter++;
                counter++;
              }
            }

            String data = "";
            for (int i = 0; i < temp_msg_storage.size(); i++)
            {
              data += temp_msg_storage.get(i);
              if (i != temp_msg_storage.size()-1)
                data += " ";
            }

            if (data.length() == 0)
              continue;
            network.write_message("/CONTROL/FADE_ACTUATOR_GROUPS/" + this.my_address + "/" + node.node_id + "/T" + delay + " " + data);  // simple, 1-byte value style.
        
          }
      }

      if (gui.show_control_test_1_running && !dr_test)
      {
        dr_test = true;
        run_dr_test();
      } 

      if (gui.show_control_test_2_running && !mo_test)
      {
        mo_test = true;
        run_moth_test();
      }

      if (gui.show_control_test_3_running && !wt_test)
      {
        wt_test = true;
        run_wt_test();
      }

 
      // if (begin_grideye_presence) {  /// deprecated in favour of load_sensor_config_strings from JSON

      //   ArrayList<Integer> GNs = dl.get_node_type_ids("GN");
      //     for (int i = 0; i < GNs.size(); i++ ) {

      //         String ge_pi_addr = dl.find_nodes_parent_rpi(GNs.get(i)).my_address;
      //         println(" enabling grideye presence for GE " + i + " at " + ge_pi_addr);
            
      //         network.write_message("/CONTROL/GE_CONFIG/" + this.my_address + "/" + ge_pi_addr + " THRESHOLD_PRESENCE 0.1" );
      //         network.write_message("/CONTROL/GE_CONFIG/" + this.my_address + "/" + ge_pi_addr + " FREQUENCY 5");
      //         network.write_message("/CONTROL/GE_SET_BACKGROUND/" + this.my_address + "/" + ge_pi_addr + " ");
            
      //     }


      //   begin_grideye_presence = false;
      // } 


      // load all default sensor configs
      if (initialize_sensors) {

        // load grideye values
        load_grideye_settings(); 

        // load IR values
        load_ir_settings(); 

        // load SD values
        load_sd_settings(); 

        initialize_sensors = false;
      }
      

      



      // ==== handle moth attenuation (run moths at lower power if nobody is there )  -- ONLY USED IN FUTURIUM, 2019

      if (tl_millis()-moth_attenuation_time > moth_attenuation_timeout) {

         moth_attenuation = ((tl_millis()-moth_attenuation_timeout)-moth_attenuation_time)/50000.0;  // +.1 every 5s after timeout
         moth_attenuation = min(moth_attenuation, 0.00);  // set max moth attenuation here.  (0.8 in Futurium)
//         println("moth attenuation: " + moth_attenuation);

      }



      //=======================END MESSAGE TESTS===================================



      //==========  // RENDER FRAME used for rendering ambient waves and random noise ;

       if (elapsed_millis > control_frame_render_time && !time_lapse_changed)   //  this is now used for throttling ambient waves
       {  
         
         

      /// set all actuators to random at 25% influence
      if (random_actuator_on && !time_lapse)
      {
        ArrayList<Float> test_arr = new ArrayList<Float>();
        Random r = new Random();
        for (int i = 0; i < dl.get_total_num_actuators(); i++)
        {
          test_arr.add(r.nextFloat()* (0.25 * masterBehaviourIntensity));
        }
        set_actuator_excitor_influences(test_arr, "RN");
      } else {
        if(time_lapse) {
          if(random_actuator_on) {
             kill_all_actuators("RN");
             random_actuator_on = false;
          }
        }
      }



      //       /// set all actuators to wave pattern
      // if (ambient_wave_on)
      // {
      //   ArrayList<Float> test_arr = new ArrayList<Float>();
      //   ArrayList<PVector> coords = dl.get_all_actuator_coordinates();
       
      //   for (int i = 0; i < coords.size(); i++)
      //   {
      //     //float val = 0.5 + 0.5*(sin(coords.get(i).x/400. + frame/5.) );
      //     float val = 0.5 + 0.5*(sin(coords.get(i).x/400. + frame/15.));
      //     val *=0.15;
      //     test_arr.add( val );

      //   }
      //   set_actuator_excitor_influences(test_arr, "WV");
       
      // }
      // else kill_all_actuators("WV");

            /// set all actuators to wave pattern
      if (grideye_presence_on)
      {
        ArrayList<Float> test_arr = new ArrayList<Float>();
        ArrayList<PVector> coords = dl.get_all_actuator_coordinates();
       
          float val = 0.0;
          for (int ge = 0; ge < gridEyePresences.length ; ge++) {
           val = max(gridEyePresences[ge], val);
          }

        for (int i = 0; i < coords.size(); i++)
        {
          float v;
          v = val * (0.7 + 0.5*(sin(coords.get(i).x/400. + frame/(40.) )));
        
          //val *=.7;
          test_arr.add( v );

        }
        set_actuator_excitor_influences(test_arr, "GE");
       
      }
      // else kill_all_actuators("GE");



         last_millis = tl_millis();
         if(time_lapse_changed) {
            time_lapse_changed = false;
         }
       }


      monitor.update();
      
      try {
        Thread.sleep(0, 200);
      }
      catch (Exception e) {
        e.printStackTrace();
      }
    }
  }

  void trigger(Actuator trigger_actuator)  {
       if(trigger_actuator != null) {

            Actuator a_to_test = trigger_actuator;
            int test_millis = 200;
            // if(!a_to_test.is_fading && tl_millis()-a_to_test.last_test_message > test_millis)  {
            if(tl_millis()-a_to_test.last_test_message > test_millis || time_lapse_changed)  {
            a_to_test.last_test_message = tl_millis();

            switch(a_to_test.designator.device_type) {

               case("DR"):

                  //println("Testing Double Rebel Star " + a_to_test.name + " (" + a_to_test.designator.get_identifier_string() + " on node " + a_to_test.parent.node_id  +  ")");
                  network.write_message("/CONTROL/FADE_ACTUATOR_GROUPS/" + this.my_address + "/" + a_to_test.parent.node_id +  " " + a_to_test.designator.get_identifier_string() + " 255 " + test_millis);
                  //delay(test_millis + test_millis/2);
                  network.write_message("/CONTROL/FADE_ACTUATOR_GROUPS/" + this.my_address + "/" + a_to_test.parent.node_id +  "/T" + (test_millis + test_millis/2) + " " + a_to_test.designator.get_identifier_string() + " 0 " + (test_millis*3) );
                  //delay(test_millis);

               break;

               case("MO"):

                  //println("Testing Moth " + a_to_test.name + " (" + a_to_test.designator.get_identifier_string() + " on node " + a_to_test.parent.node_id  +  ")");
                  network.write_message("/CONTROL/FADE_ACTUATOR_GROUPS/" + this.my_address + "/" + a_to_test.parent.node_id +  " " + a_to_test.designator.get_identifier_string() + " 255 " + test_millis);
                  //delay(test_millis + test_millis/2);
                  network.write_message("/CONTROL/FADE_ACTUATOR_GROUPS/" + this.my_address + "/" + a_to_test.parent.node_id +  "/T" + (test_millis + test_millis/2) + " " + a_to_test.designator.get_identifier_string() + " 0 " + (test_millis*3) );

               case("RS"):

                  //println("Testing Rebel Star " + a_to_test.name + " (" + a_to_test.designator.get_identifier_string() + " on node " + a_to_test.parent.node_id  +  ")");
                  network.write_message("/CONTROL/FADE_ACTUATOR_GROUPS/" + this.my_address + "/" + a_to_test.parent.node_id +  " " + a_to_test.designator.get_identifier_string() + " 255 " + test_millis);
                  //delay(test_millis + test_millis/2);
                  network.write_message("/CONTROL/FADE_ACTUATOR_GROUPS/" + this.my_address + "/" + a_to_test.parent.node_id +  "/T" + (test_millis + test_millis/2) + " " + a_to_test.designator.get_identifier_string() + " 0 " + (test_millis*3) );

               break;

               case("PC"):

                  //println("Testing ProtoCell " + a_to_test.name + " (" + a_to_test.designator.get_identifier_string() + " on node " + a_to_test.parent.node_id  +  ")");
                  network.write_message("/CONTROL/FADE_ACTUATOR_GROUPS/" + this.my_address + "/" + a_to_test.parent.node_id +  " " + a_to_test.designator.get_identifier_string() + " 255 " + test_millis);
                  //delay(test_millis + test_millis/2);
                  network.write_message("/CONTROL/FADE_ACTUATOR_GROUPS/" + this.my_address + "/" + a_to_test.parent.node_id +  "/T" + (test_millis + test_millis/2) + " " + a_to_test.designator.get_identifier_string() + " 0 " + (test_millis*3) );

               break;

               case("SM"):

                  //println("Testing SMA " + a_to_test.name + " (" + a_to_test.designator.get_identifier_string() + " on node " + a_to_test.parent.node_id  +  ")");
                  network.write_message("/CONTROL/FADE_ACTUATOR_GROUPS/" + this.my_address + "/" + a_to_test.parent.node_id +  " " + a_to_test.designator.get_identifier_string() + " 255 0");
                  //delay(test_millis + test_millis/2);
                  network.write_message("/CONTROL/FADE_ACTUATOR_GROUPS/" + this.my_address + "/" + a_to_test.parent.node_id +  "/T250 " + a_to_test.designator.get_identifier_string() + " 0 0");


               break;

               case("WT"):
               // TO DO - implement WT test
                  println("Should test WT here " + a_to_test.name);
               break;
               default:
                   println("ERROR in test:  Over an actuator whose type is unknown?");
               break;



            }
            
         }
        }
         // test_current_actuator = false;
   }

   
   void go_to_sleep() {


        // sometimes this gets called on startup before the excitor engine
        // has had a chance to initialize.  In that case, return without doing anthing because 
        // we need the excitor engine in order to kill the volume.   It will keep trying until 
        // it works.

        if(excitorBehaviour == null) return;

            kill_all_actuators();

        // going to sleep - kill sound
            excitorBehaviour.omniMasterVolume = 0;
            set_wt_master_gain(int(0));

            //excitorEngineState(false);
            subscribe_actuators(false);
            sleepmode = true;

   }

   void wake_up() {

        // sometimes this gets called on startup before the excitor engine
        // has had a chance to initialize.  In that case, return without doing anthing because 
        // we need the excitor engine in order to kill the volume.   It will keep trying until 
        // it works.

        if(excitorBehaviour == null) return;

            load_scene(current_scene); 

            if(!show_control_muted) {
                excitorBehaviour.omniMasterVolume = show_control_vol_omni;          
                set_wt_master_gain(int(show_control_vol_wt * 80));
            }

            sleepmode = false;
   }

   void update_ge_presence(message_OSC message) {

           // println(" address sending presence is " + message.get_code().split("/")[3] );  // node ID of sender

           ArrayList<Integer> GNs = dl.get_node_type_ids("GN");  // get all grideye node addresses

           cur_max_grideye_presence = 0;

           for (int i = 0; i < GNs.size(); i++ ) {
            try {

              // first check and see if thie GE is from a lost pi.  if so, average the other sensor values
              if (monitor.lost_devices.contains(dl.find_nodes_parent_rpi(GNs.get(i)).my_address) ) {
                float ge_avg = 0.0;
                for (int j = 0; j < GNs.size(); j++ ) {
                  if(j == i) continue;
                  ge_avg += ( gridEyePresences[ j ] / (GNs.size() - 1) );
                }

                gridEyePresences[ i ] = ge_avg;
                // println("PI " + dl.find_nodes_parent_rpi(GNs.get(i)).my_address + " is lost so setting its GE val to avg " + ge_avg);

                continue;
              }

              if (dl.find_nodes_parent_rpi(GNs.get(i)).my_address.equals(message.get_code().split("/")[3]) ) {

          // 1. update the corresponding virtual GE's PRESENCE value 
                GridEye g = dl.nodes.get(GNs.get(i)).my_grideyes[0];  // assumes only one GE per GN
                if(g != null && g.installed) {
                  g.current_presence = float(message.get_data()[0]);
                }
                
          // 2 update presence values in an array for influence behaviours to use (use index values from source pi's IP in DL index )
                gridEyePresences[ i ] = g.current_presence; 
              }
              // update the overall current max grideye presence
              cur_max_grideye_presence = max(cur_max_grideye_presence, gridEyePresences[i]);

              if(cur_max_grideye_presence >= 1.01-show_control_presence_sensitivity) {
                 reset_moth_attenuation();    // if people there, let moths move.
              } 

            }

            catch(NullPointerException e)
            {
              println("No excitorBehaviour");
            }
          }
   }

      void update_ge_motion(message_OSC message) {

           // println(" address sending presence is " + message.get_code().split("/")[3] );  // node ID of sender

           ArrayList<Integer> GNs = dl.get_node_type_ids("GN");  // get all grideye node addresses

           for (int i = 0; i < GNs.size(); i++ ) {
            try {

              if (dl.find_nodes_parent_rpi(GNs.get(i)).my_address.equals(message.get_code().split("/")[3]) ) {

          // 1. update the corresponding virtual GE's MOTION vector
                GridEye g = dl.nodes.get(GNs.get(i)).my_grideyes[0];  // assumes only one GE per GN
                if (g != null && g.installed) {
                  g.current_vector = new PVector(float(message.get_data()[0]), float(message.get_data()[1]));
                  g.current_vector_x = ((g.current_vector.x > 0) ? g.current_vector.x : (-1) * g.current_vector.x);
                  g.current_vector_y = ((g.current_vector.y > 0) ? g.current_vector.y : (-1) * g.current_vector.y);
                  PVector real_vector = new PVector(g.current_vector.x, g.current_vector.y);
                  g.motion_heading   = real_vector.heading();
                  g.motion_magnitude = real_vector.mag(); //  should already be normalized to 0.0 - 1.0  b/c using "constrain(-1.0, 1.0)" before sending message
                 // g.current_presence = float(message.get_data()[0]);
                }
                
          // 2 update presence values in an array for Influence behaviours to use (use index values from source pi's IP in DL index )
                gridEyeVectors[ i ] = g.current_vector; 
              }
            }

            catch(NullPointerException e)
            {
              println("No excitorBehaviour");
            }
          }
   }
   
     void update_sd_value(message_OSC message) {

           // println(" address sending SD value is " + message.get_code().split("/")[3] );  // node ID of sender
           Node sd_node = dl.nodes.get(int(message.get_code().split("/")[3]));

           cur_max_sd = 0;

           if(sd_node != null) {
           SoundDetector sd = sd_node.my_sound_detectors[0]; // assumes only one SD on this Node

                if(sd != null && sd.installed) {
                  sd.norm_value = int(message.get_data()[0]);
                  sd.norm_value_f = (sd.norm_value / 1024.0);
                  sd.cur_value  = sd.norm_value + sd.threshold;
                  if( sd.norm_value == 0 )   sd.cur_value = 0;   // special case - zero it truly if it drops below threshold
                  sd.push_value = true;
                }
                
          // 2 update sd values (normalized) in an array for influence behaviours to use (use index values TG: name -1)
                soundDetectorLevels[ sd.designator.device_number] = float(message.get_data()[0]) / ( 1024.0 - sd.threshold ) ;

                for(int i = 0 ; i < soundDetectorLevels.length ; i++) {

                 cur_max_sd = max(cur_max_sd, soundDetectorLevels[i]);

                }
           }
     }

     void update_ir_value(message_OSC message) {

           // println(" address sending IR value is " + message.get_code().split("/")[3] );  // node ID of sender
           Node ir_node = dl.nodes.get(int(message.get_code().split("/")[3]));

           cur_max_ir = 0;

           if(ir_node != null) {
           IR ir = ir_node.my_ir_detectors[0]; // assumes only one IR on this Node - this could be a problem

                if(ir != null && ir.installed) {
                  ir.cur_value   = int(message.get_data()[0]);
                  ir.push_value = true;
                }
                
          // 2 update ir values (normalized) in an array for influence behaviours to use (use index values TG: name -1)
                irDetectorLevels[ir.designator.device_number] = ir.pct_value ;

                for(int i = 0 ; i < irDetectorLevels.length ; i++) {

                 cur_max_ir = max(cur_max_ir, irDetectorLevels[i]);

                }
           }
     }

   void update_node_subscription() {

     
   }

   void reset_moth_attenuation() {

        moth_attenuation = 0.0;
        moth_attenuation_time = tl_millis();
   //     println("moth attenuation: " + moth_attenuation);

   }

  // /*! \fn threed_to_twod(PVector vec)
  //  *  \brief grideye vector math
  //  *  \param vec a position vector
  //  *  \return a position vector.
  //  */
  // PVector threed_to_twod(PVector vec)
  // {
  //   // TODO - assuming we just ignore the y axis (don't think this is right but coding anyways)
  //   float new_x = exp(vec.x/1000);
  //   float new_y = exp(vec.z/1000);

  //   return new PVector(new_x, new_y);
  // }

  // /*! \fn get_grideye_motion_influence(PVector motion, PVector actuator_location, int from_node_id)
  //  *  \brief MATT -TODO
  //  *  \param vec a position vector
  //  *  \return a position vector.
  //  */
  // float get_grideye_motion_influence(PVector motion, PVector actuator_location, int from_node_id)
  // {
  //   float DISTANCE_COEFFICIENT = 0.3;
  //   float ANGLE_COEFFICIENT = 0.5;
  //   PVector new_actuator_location = threed_to_twod(actuator_location);

  //   PVector grideye_location = dl.get_coordinates_for_type("GE", from_node_id).get(0);

  //   PVector grideye_to_actuator = grideye_location.sub(new_actuator_location);

  //   float distance_influence = 1 / grideye_to_actuator.mag();
  //   float angle_influence = ((motion.dot(grideye_to_actuator))/(motion.mag() * grideye_to_actuator.mag()) + 1) / 2;

  //   float total_influence = motion.mag() * (DISTANCE_COEFFICIENT * distance_influence + ANGLE_COEFFICIENT * angle_influence);

  //   return total_influence;
  // }


  /*! \fn send_actuator_excitor_influences(ArrayList<Float> actuator_influences, String influence_type)
   *  \brief SENDS the excitor influences to the nodes; builds a message using all actuators, regardless of type, as long as they are "installed"
   *  \return none
   */

  synchronized void send_actuator_excitor_influences(ArrayList<Float> actuator_influences, String influence_type)
  {

    // just a catch - replace old FF flowfield influenes with GR ones - should never happen.
    if(influence_type.equals("FF")) { influence_type = "GR"; }

    // actuator_influences uses following order:  MO, RS, DR, SM, WT  ...  (not hardcoded anymore as of Feb 2020 - mg)

    int counter = 0;
    int msg_arr_itr = 0;

    for (Node node : dl.nodes.values())               // step through the nodes
    {
      ArrayList<String> temp_msg_storage = new ArrayList<String>();

      for (int i = 0; i < node.ACTUATOR_ARR_SIZE; i++)
      {
        if (node.my_moths[i].installed && node.my_moths[i].subscribed_to_influence(influence_type))           // moths   ||| CHCK THAT THESE ALIGN WTIH ACT ARRAYS -mg Jan 18 2020
        {
          temp_msg_storage.add("MO" + Integer.toString(node.my_moths[i].designator.device_number + 1));
          temp_msg_storage.add(Integer.toString(Math.round(255*actuator_influences.get(counter))));
          counter++;
        }
      

        if (node.my_rebel_stars[i].installed && node.my_rebel_stars[i].subscribed_to_influence(influence_type))          // rebel stars
        {
          // rebel_stars message building
          temp_msg_storage.add("RS" + Integer.toString(node.my_rebel_stars[i].designator.device_number + 1));
          temp_msg_storage.add(Integer.toString(Math.round(255*actuator_influences.get(counter))));
          counter++;
        }
      

        if (node.my_protocells[i].installed && node.my_protocells[i].subscribed_to_influence(influence_type))          // protocells
        {
          // protocells message building
          temp_msg_storage.add("PC" + Integer.toString(node.my_protocells[i].designator.device_number + 1));
          temp_msg_storage.add(Integer.toString(Math.round(255*actuator_influences.get(counter))));
          counter++;
        }

        if (node.my_smas[i].installed && node.my_smas[i].subscribed_to_influence(influence_type))          // SMAs
        {
          // sma message building
          temp_msg_storage.add("SM" + Integer.toString(node.my_smas[i].designator.device_number + 1));
          temp_msg_storage.add(Integer.toString(Math.round(255*actuator_influences.get(counter))));
          counter++;
        }
      
      }

      for (int i = 0; i < node.DR_ARR_SIZE; i++)
      {
        if (node.my_double_rebel_stars[i].installed && node.my_double_rebel_stars[i].subscribed_to_influence(influence_type)) 
        {
          // double_rebel_stars message building
          temp_msg_storage.add("DR" + Integer.toString(node.my_double_rebel_stars[i].designator.device_number + 1));
          temp_msg_storage.add(Integer.toString(Math.round(255*actuator_influences.get(counter))));
          counter++;
        }
      }


      ////  WE DON'T YET BUILD INFLUENCES FOR WT.... SHOULD WE?

      String data = "";
      for (int i = 0; i < temp_msg_storage.size(); i++)
      {
        data  += temp_msg_storage.get(i);
        if (i != temp_msg_storage.size()-1)
          data += " ";
      }

      if (data.length() == 0)
        continue;

      // THIS IS THE MAIN WRITE MESSAGE - SENDS ACTUATOR_INFLUENCES CONSTANTLY TO THE WHOLE SCULPTURE
           network.write_message("/CONTROL/UPDATE_ACTUATOR_INFLUENCES/" + this.my_address + "/" + node.node_id + " " +  influence_type + " " + data); 
   
    }
  }



  /*! \fn set_actuator_excitor_influences(ArrayList<Float> actuator_influences, String influence_type)
   *  \brief sets the actuator influences with excitors
   *  \param actuator_influences a list of actuator values to set
   *  \param influence_type describes the type of influnce (eg. excitor) used
   *  \return none
   */

  synchronized void set_actuator_excitor_influences(ArrayList<Float> actuator_influences, String influence_type)
  {

    // just a catch - replace old FF flowfield influenes with GR ones - should never happen.
    if(influence_type.equals("FF")) { influence_type = "GR"; }


    // this version, and the function it calls below (send_actuator_excitor_influences) are being slowly deprecated as we switch
    // to threaded behaviour engines (EXP and FF so far) and more efficient messaging that sends only to specific
    // sets of actuators using a HashMap instead of an ArrayList -- see the overloaded version of this function below.
    // for now the test patterns like RN and WV are still using arrays so we will keep this around.
    //  -mg Feb 2020

    // throttle by influence type 
    if(influence_update_times.containsKey(influence_type)) 
    {
       if(new Long(tl_millis()) - (long)influence_update_times.get(influence_type) < influence_frame_time && !time_lapse_changed) 
       {
         return;  // ignore this if it was recently sent.
       }
    }
         
        // send influnces by message, rather than setting them directly, so that nodes can adjust their own influences.
        send_actuator_excitor_influences(actuator_influences, influence_type);
        influence_update_times.put(influence_type, new Long(tl_millis()));

  }

  /*  new way uses a hashmap to only send to specific, relevant actuators */

  synchronized void set_actuator_excitor_influences(HashMap<String, Float> actuator_influences, String influence_type)
  {
    // throttle by influence type 
    if(influence_update_times.containsKey(influence_type)) 
    {
       if(new Long(tl_millis()) - (long)influence_update_times.get(influence_type) < influence_frame_time && !time_lapse_changed) 
       {
         return;  // ignore this if it was recently sent.
       }
    }
         
    influence_update_times.put(influence_type, new Long(tl_millis()));

    int counter = 0;
    int msg_arr_itr = 0;
    Node n = null;
    String this_node = "";
    String this_dev  = "";

      ArrayList<String> temp_msg_storage = new ArrayList<String>();

      for(Map.Entry<String, Float> e : actuator_influences.entrySet()) 
      {
         String key = e.getKey();
         if(!this_node.equals(key.split(":")[0])) {
             this_node = key.split(":")[0];
             temp_msg_storage.add(this_node);
             n = dl.nodes.get(Integer.parseInt(this_node));
         }
         this_dev    = key.split(":")[1];
         int dev_index = Integer.parseInt(this_dev.substring(2))-1;

         if(n==null) continue;

         float cur_val = 0.0;

         switch(this_dev.substring(0,2)) {

            case("MO"):
            if(!(n.my_moths[dev_index].installed && n.my_moths[dev_index].subscribed_to_influence(influence_type))) {
                continue;
            } else cur_val = n.my_moths[dev_index].get_current_influence(influence_type);
            break;

            case("PC"):
            if(!(n.my_protocells[dev_index].installed && n.my_protocells[dev_index].subscribed_to_influence(influence_type)) ) {
                continue;
            } else cur_val = n.my_protocells[dev_index].get_current_influence(influence_type);
            break;

            case("RS"):
            if(!(n.my_rebel_stars[dev_index].installed && n.my_rebel_stars[dev_index].subscribed_to_influence(influence_type)) ) {
                continue;
            } else cur_val = n.my_rebel_stars[dev_index].get_current_influence(influence_type);
            break;

            case("DR"):
            if(!(n.my_double_rebel_stars[dev_index].installed && n.my_double_rebel_stars[dev_index].subscribed_to_influence(influence_type)) ) {
                continue;
            } else cur_val = n.my_double_rebel_stars[dev_index].get_current_influence(influence_type);
            break;

            case("SM"):
            if(!(n.my_smas[dev_index].installed && n.my_smas[dev_index].subscribed_to_influence(influence_type)) ) {
                continue;
            } else cur_val = n.my_smas[dev_index].get_current_influence(influence_type);
            break;

            case("WT"):
            if(!(n.my_wav_triggers[dev_index].installed && n.my_wav_triggers[dev_index].subscribed_to_influence(influence_type)) ) {
                continue;
            } else cur_val = n.my_wav_triggers[dev_index].get_current_influence(influence_type);
            break;

         }

        int new_val = max(0, Math.round(255*e.getValue()));

        if(new_val == max(0, Math.round(255*cur_val))) continue; // don't send a message if influence value is unchanged.

        temp_msg_storage.add(this_dev);
        temp_msg_storage.add( Integer.toString(max(0, Math.round(255*e.getValue()))) ); // use max to avoid negatives

      }

      String data = "";

      for(String s : temp_msg_storage) {

        if(s.length()==6)    // new node, start with ID
        { 
          if(data.length() > 10)  // if we've previously built a valid message, send it.
          {
            network.write_message("/CONTROL/UPDATE_ACTUATOR_INFLUENCES/" + this.my_address + "/" + data); 
           }
          data = (s + " " + influence_type);
        } else {
          data += " " + s;
        }
      }
      if(data.length() > 10)  // last one - if we've previously built a valid message, send it.
      {
        network.write_message("/CONTROL/UPDATE_ACTUATOR_INFLUENCES/" + this.my_address + "/" + data); 
      }

  }



  /*! \fn kill_all_actuators()
   *  \brief sets the actuator levels to 0
   *  \return none
   */
  void kill_all_actuators()
  {
    // go through all the influences (n) and unsubscribe from them.

    String this_influence = "";

    for(int n = 0; n < gui.which_influence.getItems().size(); n++) {

      String nickname = String.valueOf(gui.which_influence.getItem(n).get("value"));

      if(nickname.equals("FF")) nickname = "GR";  /// this should never happen, but just in case.

      if(nickname.equals("SB")) continue;  // this is just the sample - don't generate tons of error messages!
      if(nickname.equals("IR")) continue;  // for now, don't kill IR local responsiveness
       
      if(!nickname.equals(str(n))) {   // if we have set a specific nickname for this
          this_influence = nickname;
      } else {
          this_influence = String.valueOf(gui.which_influence.getItem(n).get("text"));
      }

      kill_all_actuators(this_influence);
      // slight sleep to let the messages go through?
      // try {
      //   Thread.sleep(100);
      // } catch(Exception e) {
      //   println(e);
      // }
    }
    


  }

  void kill_all_actuators(String influence_name)
  {
    // this now kills actuators by unsubscribing them all -- they can be re-subscribed by loading appropriate sets.  -mg

    killing_actuators = true;
    subscribe_actuators_by_type("ALL", influence_name, false); 

  }

  /*! \fn run_moth_test()
   *  \brief runs a test sequence for the moths
   *  \return none
   */
  void run_moth_test()
  {
    if (mo_test)
    {
      save_actuator_influence_maps("temp");
      kill_all_actuators();
      for (Node node : dl.nodes.values())
      {
        for (int i = 0; i < Node.ACTUATOR_ARR_SIZE; i++)
        {
          if (node.my_moths[i].installed)
          {
            network.write_message("/CONTROL/FADE_ACTUATOR_GROUPS/" + this.my_address + "/" + node.node_id + 
              " MO" + Integer.toString(i + 1) + " 200 100");

            delay(500);
            network.write_message("/CONTROL/FADE_ACTUATOR_GROUPS/" + this.my_address + "/" + node.node_id + 
              " MO" + Integer.toString(i + 1) + " 0 100");

            if (!gui.show_control_test_2_running)
            {
              mo_test = false;
              load_actuator_influence_maps("temp");
              return;
            }
          }
        }
      }
      gui.show_control_test_2_running = false;
      mo_test = false;
      load_actuator_influence_maps("temp");
    }
  }

  /*! \fn run_dr_test()
   *  \brief runs a test sequence for the double rebel stars
   *  \return none
   */
  void run_dr_test()
  {
    if (dr_test)
    {
      save_actuator_influence_maps("temp");
      kill_all_actuators();
//      excitorEngineState(false);
      for (Node node : dl.nodes.values())
      {
        for (int i = 0; i < Node.DR_ARR_SIZE; i++)
        {
          String[] msg_arr = new String[3];
          if (node.my_double_rebel_stars[i].installed)
          {
            network.write_message("/CONTROL/FADE_ACTUATOR_GROUPS/" + this.my_address + "/" + node.node_id + 
              " DR" + Integer.toString(i + 1) + " 255 100");

            delay(500);

            network.write_message("/CONTROL/FADE_ACTUATOR_GROUPS/" + this.my_address + "/" + node.node_id + 
              " DR" + Integer.toString(i + 1) + " 0 100");

            if (!gui.show_control_test_1_running)
            {
              dr_test = false;
              load_actuator_influence_maps("temp");
//              excitorEngineState(true);
              return;
            }
          }
        }
      }
      gui.show_control_test_1_running = false;
      dr_test = false;
      load_actuator_influence_maps("temp");
//      excitorEngineState(true);
    }
  }

  /*! \fn run_wt_test()
   *  \brief runs a test sequence for the wav triggers  // ONLY USED IN FUTURIUM 2019
   *  \return none
   */
  void run_wt_test()
  {
    if (wt_test)
    {
      save_actuator_influence_maps("temp");
      kill_all_actuators();
 //     excitorEngineState(false);

      int sound = 2;
      for (Node node : dl.nodes.values())
      {
        for (int i = 0; i < Node.WT_ARR_SIZE; i++)
        {
          String[] msg_arr = new String[3];
          if (node.my_wav_triggers[i].installed)
          {
            
            network.write_message("/CONTROL/WAV_PLAY_SOUND/" + this.my_address + "/" + node.node_id + 
              " WT" + Integer.toString(i + 1) + " " + Integer.toString(sound % 31 + 1) + " POLY");

             println("/CONTROL/WAV_PLAY_SOUND/" + this.my_address + "/" + node.node_id + 
              " WT" + Integer.toString(i + 1) + " " + Integer.toString(sound % 31 + 1) + " POLY");
            delay(500);

            if (!gui.show_control_test_3_running)
            {
              wt_test = false;
              load_actuator_influence_maps("temp");
//              excitorEngineState(true);
              return;
            }
            sound++;
          }
        }
      }
      wt_test = false;
      gui.show_control_test_3_running = false;
      load_actuator_influence_maps("temp");
//      excitorEngineState(true);
    }
  }

  /*! \fn excitorEngineState(boolean state)
   *  \brief MATT - TODO
   *  \param state
   *  \return none
   */ 

/// deprecated --- we'll let the excitor engine run, but unsubscribe things instead.

  // void excitorEngineState(boolean state)  // TODO - this should be pushstate, pop state so we can preserve changes
  // {
  //   // show_control_awake = state;

  //  try {

  //   excitorBehaviour.wavTriggerEnabled = state;
  //   excBehavVars.excitorsInfluenceActive = state;

  //  } catch(NullPointerException e) {

  //    println("Exception: " + e + " setting excitorBehaviour -- probably not assigned yet");

  //  }
  // }
}