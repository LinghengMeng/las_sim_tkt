/*!  
 <h1> Node </h1>
 Node object
 
 \author Matt Gorbet et al
 
 */
import java.util.concurrent.TimeUnit;

class Node extends Thread {
  int node_id;
  boolean output_raw_osc_to_console = false;     // outputs a raw OSC message to concole
  boolean output_raw_osc_to_external = true;     // outputs a raw OSC message of format [<int> <float> ...] for each pin
  int osc_out_port_for_las_unity_simulator;                         // personalized OSC port for this node to send to
  NetAddress osc_out_address_for_las_unity_simulator;                         // personalized OSC address for this node to send to
  int osc_out_port_for_las_ai_agent;              // 
  NetAddress osc_out_address_for_las_ai_agent;           // 
  String node_group;
  String type;

  public static final int NUM_UIDS = 48;
  DeviceIdentifier[] uid_to_type = new DeviceIdentifier[NUM_UIDS];

  public static final int ACTUATOR_ARR_SIZE = 20; // max number actuators (for softpwm) - increased from 12 (HU specific) to allow for larger actuator arrays
  public static final int DR_ARR_SIZE = 10; 
  public static final int WT_ARR_SIZE = 2;
  public static final int SD_ARR_SIZE = 2;
  public static final int IR_ARR_SIZE = 1;
  public static final int GE_ARR_SIZE = 1;

  SMA[] my_smas = new SMA[ACTUATOR_ARR_SIZE];
  Moth[] my_moths = new Moth[ACTUATOR_ARR_SIZE];
  RebelStar[] my_rebel_stars = new RebelStar[ACTUATOR_ARR_SIZE];
  ProtoCell[] my_protocells = new ProtoCell[ACTUATOR_ARR_SIZE];
  DoubleRebelStar[] my_double_rebel_stars = new DoubleRebelStar[DR_ARR_SIZE];
  WAV_Trigger[] my_wav_triggers = new WAV_Trigger[WT_ARR_SIZE];
  SoundDetector[] my_sound_detectors = new SoundDetector[SD_ARR_SIZE];
  IR[] my_ir_detectors = new IR[IR_ARR_SIZE];
  GridEye[] my_grideyes = new GridEye[GE_ARR_SIZE];

  boolean sound_trigger_ok = true;

  DeviceLocatorNode dl;
  boolean debug = false;

  /*! Node constructor
   \param nid the node id of this node
   \param dl device_locator for the nodes  */
  Node(int nid, DeviceLocatorNode dl, String type, String group) {


    // name thread:
    super("Node thread: " + nid + " ("+ type +")");

    this.node_id = nid;

    // create a destination to output OSC messages for eg: Unity
    this.osc_out_port_for_las_unity_simulator = 50000 + nid % 10000;
    this.osc_out_address_for_las_unity_simulator = new NetAddress(las_unity_simulator_ip, osc_out_port_for_las_unity_simulator);
    // create a destination to output OSC message to LAS-AI-Agent
    this.osc_out_port_for_las_ai_agent = las_ai_agent_port;
    this.osc_out_address_for_las_ai_agent = new NetAddress(las_ai_agent_ip, osc_out_port_for_las_ai_agent);
    
    this.node_group = group;
    this.dl = dl;
    this.type = type;
    println("I am a node with node_id: " + node_id + " in group " + node_group + " (raw osc port "+ osc_out_port_for_las_unity_simulator + ")");

    // println("raw multi? " + this.osc_out_address_for_las_unity_simulator.inetaddress().isMulticastAddress());
    // println("multi Global? " + this.osc_out_address_for_las_unity_simulator.inetaddress().isMCGlobal());
    // println("multi LinkLocal? " + this.osc_out_address_for_las_unity_simulator.inetaddress().isMCLinkLocal());
    // println("multi NodeLocal? " + this.osc_out_address_for_las_unity_simulator.inetaddress().isMCNodeLocal());
    // println("multi OrgLocal? " + this.osc_out_address_for_las_unity_simulator.inetaddress().isMCOrgLocal());
    // println("multi SiteLocal? " + this.osc_out_address_for_las_unity_simulator.inetaddress().isMCSiteLocal());

    // to emulate C++'s automatic creation of objects when arrays are declared
    for (int i = 0; i < ACTUATOR_ARR_SIZE; i++)
    {
      my_smas[i] = new SMA();
      my_moths[i] = new Moth();
      my_rebel_stars[i] = new RebelStar();
      my_protocells[i] = new ProtoCell();

      if (i < DR_ARR_SIZE)
      {
        my_double_rebel_stars[i] = new DoubleRebelStar();
      }
      if (i < WT_ARR_SIZE)
      {
        my_wav_triggers[i] = new WAV_Trigger();
      }
      if (i < SD_ARR_SIZE)
      {
        my_sound_detectors[i] = new SoundDetector();
      }
      if (i < IR_ARR_SIZE)
      {
        my_ir_detectors[i] = new IR();
      }
      if (i < GE_ARR_SIZE)
      {
        my_grideyes[i] = new GridEye();
      }
    }
  }

  /*! Setup function */
  synchronized void startup() {
    read_dl();
  }

  synchronized boolean isValid(String act_type, int act_num)
  {
    act_num--;
    if (act_num < 0)
      return false;

    switch(act_type)
    {
    case "SM":
      return act_num < ACTUATOR_ARR_SIZE;
    case "RS":
      return act_num < ACTUATOR_ARR_SIZE;
    case "PC":
      return act_num < ACTUATOR_ARR_SIZE;
    case "MO":
      return act_num < ACTUATOR_ARR_SIZE;
    case "DR":
      return act_num < DR_ARR_SIZE;
    case "WT":
      return act_num < WT_ARR_SIZE;
    case "SD":
      return act_num < SD_ARR_SIZE;
    case "IR":
      return act_num < IR_ARR_SIZE;
    case "GE":
      return act_num < GE_ARR_SIZE;
    default:
      return false;
    }
  }

  /*! Update function to be called in each iteration */
  public void run() {
    while (true) {
      //==========  START OF MESSAGING FUNCTIONALITY 

      message_OSC message = network.get_message(Integer.toString(this.node_id));

      if (message != null)
      {
        String message_keyword = split(message.get_code(), '/')[2];

        // ====== UPDATE INFLUENCE OF eg: EXCITORS
        if (message_keyword.contains("UPDATE_ACTUATOR_INFLUENCES"))
        {
          if (this.debug) 
          {
            print(message.get_code() + " ");
            println(message.get_uncut_data());
          }  

          String inf_type = message.get_data()[0];     

          for (int i = 1; i < message.get_data().length; i+=2) 
          {
            String act_type = message.get_data()[i].substring(0, 2);
            int act_num = Integer.parseInt(message.get_data()[i].substring(2)); 
            float inf = (Integer.parseInt(message.get_data()[i + 1]))/255.0;    // convert byte back to float here.

            if (isValid(act_type, act_num))
            {
              switch(act_type)
              {
              case "RS":
                if (my_rebel_stars[act_num - 1].installed)
                  my_rebel_stars[act_num - 1].add_influence(inf_type, inf);
                break;
              case "PC":
                if (my_protocells[act_num - 1].installed)
                  my_protocells[act_num - 1].add_influence(inf_type, inf);
                break;
              case "MO":
                if (my_moths[act_num - 1].installed)
                  my_moths[act_num - 1].add_influence(inf_type, inf);
                break;
              case "DR":
                if (my_double_rebel_stars[act_num - 1].installed) {
                    my_double_rebel_stars[act_num - 1].add_influence(inf_type, inf);
                }
                break;
              case "SM":
                if (my_smas[act_num - 1].installed) {
                    my_smas[act_num - 1].add_influence(inf_type, inf);
                }
                break;
              default:
                println("Update Influences called with unknown actuator type");
                break;
              }
            } else 
            {
              println("Invalid actuator " + act_type + Integer.toString(act_num));
            }
          }
          /// =========  FADE ACTUATOR GROUPS MESSAGING 
      } else if (message_keyword.contains("FADE_ACTUATOR_GROUPS"))
        {
          if (this.debug) 
          {
            print(message.get_code() + " ");
            println(message.get_uncut_data());
          }  
          // fade action
          
          boolean extra = (message_keyword.contains("_DR+")); 

          for (int i = 0; i < message.get_data().length; i+=3) 
          {
            String act_type = message.get_data()[i].substring(0, 2);
            int act_num = Integer.parseInt(message.get_data()[i].substring(2)); 
            int target_value = Integer.parseInt(message.get_data()[i + 1]);
            int target_value2 = 0;

            if (extra && isValid(act_type, act_num) && act_type.equals("DR")) {
              // it is a special _DR+ message
              i++;
              target_value2 = Integer.parseInt(message.get_data()[i + 1]);
            }

            int fade_time = Integer.parseInt(message.get_data()[i + 2]);


            if (isValid(act_type, act_num))
            {
              switch(act_type)
              {
              case "SM":
               if (my_smas[act_num - 1].installed)
                   my_smas[act_num - 1].fade(target_value, fade_time);
                break;
              case "RS":
               if (my_rebel_stars[act_num - 1].installed)
                  my_rebel_stars[act_num - 1].fade(target_value, fade_time);
                break;
              case "PC":
                if (my_protocells[act_num - 1].installed)
                  my_protocells[act_num - 1].fade(target_value, fade_time);
                break;
              case "MO":
                if (my_moths[act_num - 1].installed)
                  my_moths[act_num - 1].fade(target_value, fade_time);
                break;
              case "DR":
                if (my_double_rebel_stars[act_num - 1].installed) {
                if (extra) {
                  my_double_rebel_stars[act_num - 1].fade_extra(target_value,  fade_time, 1);
                  my_double_rebel_stars[act_num - 1].fade_extra(target_value2, fade_time, 2);
                } else {
                  my_double_rebel_stars[act_num - 1].fade(target_value, fade_time);
                }
              }
                break;
              case "WT":
                if (my_wav_triggers[act_num - 1].installed)
                  my_wav_triggers[act_num - 1].fade(target_value, fade_time);
                break;
              default:
                println("Fade called with unknown actuator type");
                break;
              }
            } else 
            {
              println("Invalid actuator " + act_type + Integer.toString(act_num));
            }
          }
          // ======= SETTING WAV CONFIGURATION
      } else if (message_keyword.indexOf("WAV") >= 0)
        {
          int act_num = Integer.parseInt(message.get_data()[0].substring(2));
          if (debug)
          {
            // print(message.get_code() + "\t");
            // println(message.get_data());
          }
          if (isValid("WT", act_num) && my_wav_triggers[act_num - 1].installed)
          {
            if (message_keyword.equals("WAV_PLAY_SOUND")) // play a sound
              my_wav_triggers[act_num - 1].play_track(message.get_data()[1], message.get_data()[2].equals("SOLO"));
            else if (message_keyword.equals("WAV_MASTER_GAIN")) // set master volume
              my_wav_triggers[act_num - 1].master_volume_set(Integer.parseInt(message.get_data()[1]));
            else if (message_keyword.equals("WAV_TRACK_GAIN")) // set track volume
              my_wav_triggers[act_num - 1].track_volume_set(message.get_data()[1], Integer.parseInt(message.get_data()[2]));
            else if (message_keyword.equals("WAV_TRACK_FADE")) // fade track --- UNTESTED!!  Do we need to send two bytes for time and bit-shift them?  How does third parameter work?  -mg
              my_wav_triggers[act_num - 1].track_fade(message.get_data()[1], Integer.parseInt(message.get_data()[2]), Integer.parseInt(message.get_data()[3]), ("TRUE").equals(message.get_data()[4]));
          } else
          {
            println("Invalid WAV Trigger WT " + Integer.toString(act_num));
          }
        } 
        else if (message_keyword.equals("DR_CONFIG"))
        {

          String dr    = message.get_data()[0];
          String param = message.get_data()[1];
          String value = message.get_data()[2];

          int dr_num = Integer.parseInt(dr.substring(2));

           // println(node_id + " received message to set " + dr + " param " + param + " to " + value);

          String[] args = {param, value};

          if(my_double_rebel_stars[dr_num-1].installed) {
             my_double_rebel_stars[dr_num-1].configure_dr(args);
          }

        } else if (message_keyword.equals("IR_CONFIG"))   // 
        {

          String ir    = message.get_data()[0];
          String param = message.get_data()[1];
          String value = message.get_data()[2];

          int ir_num = Integer.parseInt(ir.substring(2));

          // println(node_id + " received message to set " + ir + " param " + param + " to " + value);

          String[] args = {param, value};

          if(my_ir_detectors[ir_num-1].installed) {
             my_ir_detectors[ir_num-1].configure_ir(args);
          }

        } else if (message_keyword.equals("SD_CONFIG"))   // 
        {

          String sd    = message.get_data()[0];
          String param = message.get_data()[1];
          String value = message.get_data()[2];

          int sd_num = Integer.parseInt(sd.substring(2));

          // println(node_id + " received message to set " + sd + " param " + param + " to " + value);

          String[] args = {param, value};

          if(my_sound_detectors[sd_num-1].installed) {
             my_sound_detectors[sd_num-1].configure_sd(args);
          }

        }  else if (message_keyword.indexOf("INFLUENCE") >= 0)
        {
          if (debug)
          {
            print(message.get_code() + "\t");
            println(message.get_data());
          }
          if (message_keyword.equals("INFLUENCE_MAP"))
          {
            // println(node_id + " received message to set " + message.get_data()[1] + " subscription for " + message.get_data()[0] + " to " + message.get_data()[2]);
            
            String inf_type = message.get_data()[0];
            String act_type = message.get_data()[1].substring(0, 2);
            int act_num = Integer.parseInt(message.get_data()[1].substring(2)); 
            boolean sub = (message.get_data()[2].equals("TRUE") || message.get_data()[2].equals("true")); 
  
            if (isValid(act_type, act_num))
            {
              switch(act_type)
              {
                case "MO":
                if (my_moths[act_num - 1].installed) 
                    if(sub) my_moths[act_num - 1].enable_influence(inf_type);
                    else    my_moths[act_num - 1].disable_influence(inf_type);
                
                break;
                case "RS":
                if (my_rebel_stars[act_num - 1].installed)
                    if(sub) my_rebel_stars[act_num - 1].enable_influence(inf_type);
                    else    my_rebel_stars[act_num - 1].disable_influence(inf_type);
                break;
                case "PC":
                if (my_protocells[act_num - 1].installed)
                    if(sub) my_protocells[act_num - 1].enable_influence(inf_type);
                    else    my_protocells[act_num - 1].disable_influence(inf_type);
                break;
                    case "DR":
                if (my_double_rebel_stars[act_num - 1].installed) 
                    if(sub) my_double_rebel_stars[act_num - 1].enable_influence(inf_type);
                    else    my_double_rebel_stars[act_num - 1].disable_influence(inf_type);
                break;
                    case "SM":
                if (my_smas[act_num - 1].installed) {
                    if(sub) my_smas[act_num - 1].enable_influence(inf_type);
                    else    my_smas[act_num - 1].disable_influence(inf_type);
                }
                break;

  
              default:
                println("Subscribe (" + sub + ") to " + inf_type + " called with unknown actuator type:" + act_type);
                break;
              }
            } else 
            {
              println("Invalid actuator " + act_type + Integer.toString(act_num) + " for subscribing (" + sub + ") to " + inf_type );
            }
            
        } else if (message_keyword.equals("INFLUENCE_RANGE"))
          {
            // println(node_id + " received message to set " + message.get_data()[1] + " range for " + message.get_data()[0] + " to " + message.get_data()[2]+"-" + message.get_data()[3]);
            
            String inf_type = message.get_data()[0];
            String act_type = message.get_data()[1].substring(0, 2);
            int act_num = Integer.parseInt(message.get_data()[1].substring(2)); 
            float bot = Float.parseFloat(message.get_data()[2]);
            float top = Float.parseFloat(message.get_data()[3]);
  
            if (isValid(act_type, act_num))
            {
              switch(act_type)
              {
                case "MO":
                if (my_moths[act_num - 1].installed) {
                    my_moths[act_num - 1].set_low_range(inf_type, bot);
                    my_moths[act_num - 1].set_high_range(inf_type, top); }
                break;
                case "RS":
                if (my_rebel_stars[act_num - 1].installed) {
                    my_rebel_stars[act_num - 1].set_low_range(inf_type, bot);
                    my_rebel_stars[act_num - 1].set_high_range(inf_type, top); }
                break;
                case "PC":
                if (my_protocells[act_num - 1].installed) {
                    my_protocells[act_num - 1].set_low_range(inf_type, bot);
                    my_protocells[act_num - 1].set_high_range(inf_type, top); }
                break;
                    case "DR":
                if (my_double_rebel_stars[act_num - 1].installed)  {
                    my_double_rebel_stars[act_num - 1].set_low_range(inf_type, bot);
                    my_double_rebel_stars[act_num - 1].set_high_range(inf_type, top); }
                break;
                    case "SM":
                if (my_smas[act_num - 1].installed) {
                    my_smas[act_num - 1].set_low_range(inf_type, bot);
                    my_smas[act_num - 1].set_high_range(inf_type, top); }
                break;

  
              default:
                println("Range (" + bot + "-" + top + ") for " + inf_type + " called with unknown actuator type:" + act_type);
                break;
              }
            } else 
            {
              println("Invalid actuator " + act_type + Integer.toString(act_num) + " for range (" + bot + "-" + top + ") for " + inf_type);
            }
          
        }
      } else if (message_keyword.contains("DELAY_MESSAGE"))
        {
        // a message coming back to the node after being delayed - needs to be parsed.
        String act_type = message.get_data()[0].substring(0, 2);
        int    act_num  = Integer.parseInt(message.get_data()[0].substring(2)); 

        //  println("virtual node " + node_id + " received a delay_message message");

        if (isValid(act_type, act_num))
        {
          switch(act_type)
          {
            case "DR":
                if (my_double_rebel_stars[act_num - 1].installed) {
                   my_double_rebel_stars[act_num-1].follow_to(Integer.parseInt(message.get_data()[1]));
                }
      
            break;

            case "SM":
                if (my_smas[act_num - 1].installed) {
                    my_smas[act_num - 1].fade(Integer.parseInt(message.get_data()[1]), 0);
                }
          }
        } else 
         {
            println("Invalid actuator " + act_type + Integer.toString(act_num) + " for delay message");
          }
        }
      }  /// if message != null;
      //============  END OF MESSAGING FUNCTIONALITY  =================

      //=================  UPDATE ACTUATORS - this lets them do calculations to interpolate, cap, etc.

      for (int i = 0; i < ACTUATOR_ARR_SIZE; i++)
      {
        if (my_smas[i].installed)
          my_smas[i].update();
        if (my_moths[i].installed)
          my_moths[i].update();
        if (my_rebel_stars[i].installed)
          my_rebel_stars[i].update();
        if (my_protocells[i].installed)
          my_protocells[i].update();
      }

      for (int i = 0; i < DR_ARR_SIZE; i++)
      {
        if (my_double_rebel_stars[i].installed)
          my_double_rebel_stars[i].update();
      }

      for (int i = 0; i < WT_ARR_SIZE; i++)
      {
        if (my_wav_triggers[i].installed)
          my_wav_triggers[i].update();
      }

      //=================  UPDATE SENSORS - this lets them do calculations to interpolate, cap, etc.


      for (int i = 0; i < SD_ARR_SIZE; i++)
      {
        if (my_sound_detectors[i].installed)
          my_sound_detectors[i].update();
      }

      for (int i = 0; i < IR_ARR_SIZE; i++)
      {
        if (my_ir_detectors[i].installed)
          my_ir_detectors[i].update();
      }

      for (int i = 0; i < GE_ARR_SIZE; i++)
      {
        // update ges
        if (my_grideyes[i].installed)
          my_grideyes[i].update();
      }     

      try {
        Thread.sleep(0, 30);
      }
      catch (Exception e) {
        e.printStackTrace();
      }
    
    } // while true
  }

  /*! Draws the actuator with new values */
  synchronized void go() {

    if(!isolated_group.equals("") && !isolated_group.equals(node_group.substring(0,2))) return;

    // create raw OSC message (for e.g. Unity) to send pin output levels
    // OSC message address format: "/{source}/{purpose}/{device_type}/{node_id}"
    OscMessage actuator_raw_output_levels = new OscMessage("/Pro_Sim/Observation/Actuators/" + node_id);
    OscMessage sensor_raw_output_levels = new OscMessage("/Pro_Sim/Observation/Sensors/" + node_id);

    for (int i = 0; i < ACTUATOR_ARR_SIZE; i++)
    {
      if (my_smas[i].installed) {
        my_smas[i].go();
        my_smas[i].add_raw_output(actuator_raw_output_levels);
      }
      if (my_moths[i].installed) {
        my_moths[i].go();
        my_moths[i].add_raw_output(actuator_raw_output_levels);
      }
      if (my_rebel_stars[i].installed) {
        my_rebel_stars[i].go();
        my_rebel_stars[i].add_raw_output(actuator_raw_output_levels);
      }
      if (my_protocells[i].installed) {
        my_protocells[i].go();
        my_protocells[i].add_raw_output(actuator_raw_output_levels);
      }
    }

    for (int i = 0; i < DR_ARR_SIZE; i++)
    {
      if (my_double_rebel_stars[i].installed) {
        my_double_rebel_stars[i].go();
        my_double_rebel_stars[i].add_raw_output(actuator_raw_output_levels);
      }
    }

    for (int i = 0; i < WT_ARR_SIZE; i++)
    {
      if (my_wav_triggers[i].installed)
        my_wav_triggers[i].go();
        // we don't add wav_triggers to raw output OSC messages (yet.... -mg April 21, 2020)
    }

    //  SENSORS

    for (int i = 0; i < SD_ARR_SIZE; i++)
    {
      if (my_sound_detectors[i].installed)
        my_sound_detectors[i].go();
        my_sound_detectors[i].add_raw_output(sensor_raw_output_levels);
    }

    for (int i = 0; i < IR_ARR_SIZE; i++)
    {
      if (my_ir_detectors[i].installed) {
          my_ir_detectors[i].go();
          my_ir_detectors[i].add_raw_output(sensor_raw_output_levels);

            // LOCAL BEHAVIOUR:  directly connect any proto_cells to my IR sensor

            float IRval = float(my_ir_detectors[i].norm_value)/float(my_ir_detectors[i].IR_MY_MAX-my_ir_detectors[i].threshold); 
 
            for (int j = 0; j < ACTUATOR_ARR_SIZE; j++)
            {
              if (my_protocells[j].installed) {
//                  my_protocells[j].fade(int(my_protocells[j].cur_values.max_value * IRval), 1000);
                  my_protocells[j].follow_ir(IRval, 200);
              }
            }

            // LOCAL BEHAVIOUR:  trigger SMAs at high presence. also *** HACK: this virtual node will send a (real) OSC command for an audio gesture! ***


            for (int s = 0; s < ACTUATOR_ARR_SIZE; s++)
            {
              if (my_smas[s].installed && my_smas[s].current_influences.get("IR") != null) 
              {  
                my_smas[s].current_influences.get("IR").current_influence = IRval;
                if(s == 0) { // just dealing with the first SMA
                  //if(my_smas[s].SM_state == SMA.READY) sound_trigger_ok = true; 
                  // if(my_smas[s].SM_state == SMA.READY) sound_trigger_ok = true; 

                  if(current_scene.contains("02_tidal")) sound_trigger_ok = false; //  hack for meander preview launch: no gestures if we are in opening sequence

                  if(IRval > (my_smas[s].get_low_range("IR") + my_smas[s].get_high_range("IR"))/2.0) {  // IRval has passed the high range for triggering SMA, so it's definitely triggered now
                    if(ir_trigger_sounds && sound_trigger_ok) {

                      // println(" *** "+ my_ir_detectors[i].name + " on Node " + node_id + " (in "+ node_group + ") triggered audio gesture!");
                      int gnum = which_sound_gesture(my_ir_detectors[i].name);
                      if(gnum != -1) {

                        int soundOrNoise = ((random(1f) < 0.90f) ? 1 : 2);  // 10 percent chance it is noise.

                        println("/gesture/trigger "+gnum+" " + soundOrNoise + " (" + current_scene + ")");
                        
                        OscMessage trigger = new OscMessage("/gesture/trigger");
                        trigger.add(gnum);
                        trigger.add(soundOrNoise);
                        external_osc.send(trigger, maxOSCAddress); 
                        
                      }
                     // sound_trigger_ok = false;   // to wait for SMA cooldown
                     //last_sound_trigger = millis();

                    }
                     sound_trigger_ok = true;  // going to continuously slam these.  will suppress if specific scene (above)
                  }
                }
              }
            }
      }

    }

    for (int i = 0; i < GE_ARR_SIZE; i++)
    {
      // update ges
      if (my_grideyes[i].installed)
          my_grideyes[i].go();
          my_grideyes[i].add_raw_output(sensor_raw_output_levels);
    }

    // Actuators
    if(output_raw_osc_to_external && actuator_raw_output_levels.typetag().length() > 1) {
      // If output osc message to console, the simulator will be very lagging.
      if(output_raw_osc_to_console){
        actuator_raw_output_levels.print();
      }
      OscP5.flush(actuator_raw_output_levels, osc_out_address_for_las_unity_simulator);  // send the message to my personalized OSC port - note this uses 'flush' to avoid creating receiver threads and interrupts for every node.
      OscP5.flush(actuator_raw_output_levels, osc_out_address_for_las_ai_agent); 
    }

    // Sensors
    if(output_raw_osc_to_external && sensor_raw_output_levels.typetag().length() > 1) {
      // If output osc message to console, the simulator will be very lagging.
      if(output_raw_osc_to_console){
        sensor_raw_output_levels.print();
      }
      OscP5.flush(sensor_raw_output_levels, osc_out_address_for_las_ai_agent);
    }

  }

  // synchronized int which_sound_gesture(String irname) {      // map which IR trigger goes to which gesture

  //   String river = split(irname, ":")[0];
  //   int num      = Integer.parseInt(split(irname, ":")[1]);
  //   int gest     = 0;

  //   switch(river) {

  //   case("NR"):
  //      if(num < 4) return(1);
  //      if(num < 7) return(2);
  //      return(3);      

  //   case("SR"):
  //      if(num < 4) return(4);
  //      return(5);

  //   }
  //   return(-1);

  // }

synchronized int which_sound_gesture(String irname) {      // map which IR trigger goes to which gesture

    String river = split(irname, ":")[0];
    int num      = Integer.parseInt(split(irname, ":")[1]);
    int gest     = 0;

    switch(river) {

    case("NR"):
       return(num);

    case("SR"):
       return(num+8);
    }
    return(-1);

  }


  synchronized JSONObject get_grideye_settings_json() {

    JSONObject ge_settings = new JSONObject();
    boolean has_ge = false;

    for (int i = 0; i < GE_ARR_SIZE; i++)
    {
      // update ges
      if (my_grideyes[i].installed) {
          has_ge = true;
          ge_settings.setString(my_grideyes[i].name, my_grideyes[i].get_config_string());
      }
    }

    if(!has_ge) return null;
    return ge_settings;
  }


  synchronized JSONObject get_sd_settings_json() {

    JSONObject sd_settings = new JSONObject();
    boolean has_sd = false;

    for (int i = 0; i < SD_ARR_SIZE; i++)
    {
      // update ges
      if (my_sound_detectors[i].installed) {
          has_sd = true;
          sd_settings.setString(my_sound_detectors[i].name, my_sound_detectors[i].get_config_string());
      }
    }

    if(!has_sd) return null;
    return sd_settings;
  }


  synchronized JSONObject get_ir_settings_json() {

    JSONObject ir_settings = new JSONObject();
    boolean has_ir = false;

    for (int i = 0; i < IR_ARR_SIZE; i++)
    {
      // update ges
      if (my_ir_detectors[i].installed) {
          has_ir = true;
          ir_settings.setString(my_ir_detectors[i].name, my_ir_detectors[i].get_config_string());
      }
    }

    if(!has_ir) return null;
    return ir_settings;
  }



  //  These three overloaded functions return JSON-formatted versions of the actuator influence maps for all actuators of a certain type.
  //  if nothing is passed or if "ALL" is passed as the type, recursion is used to populate the JSON object with all actuators.

  synchronized JSONObject get_actuator_inf_map_json() {

    return get_actuator_inf_map_json("ALL");

  }

  synchronized JSONObject get_actuator_inf_map_json(String act_type) {

    JSONObject act_inf_map = new JSONObject();
    return get_actuator_inf_map_json(act_type, act_inf_map);

  }

  synchronized JSONObject get_actuator_inf_map_json(String act_type, JSONObject act_inf_map) {

    // recursion!!

    if(act_type.equals("ALL")) {

       get_actuator_inf_map_json("MO", act_inf_map);
       get_actuator_inf_map_json("RS", act_inf_map);
       get_actuator_inf_map_json("PC", act_inf_map);
       get_actuator_inf_map_json("DR", act_inf_map);
       get_actuator_inf_map_json("SM", act_inf_map);

    } else {

      switch(act_type) 
      {
        case "MO":
        
        for(Actuator a : my_moths) {
          if(a != null && a.installed) {
            act_inf_map.setJSONObject(a.name, a.get_influence_map_json());
          }
        }

        break;
        case "RS":
        for(Actuator a : my_rebel_stars) {
          if(a != null && a.installed) {
            act_inf_map.setJSONObject(a.name, a.get_influence_map_json());
          }
        }

        break;
        case "PC":
        for(Actuator a : my_protocells) {
          if(a != null && a.installed) {
            act_inf_map.setJSONObject(a.name, a.get_influence_map_json());
          }
        }

        break;
        case "DR":
        for(Actuator a : my_double_rebel_stars) {
          if(a != null && a.installed) {
            act_inf_map.setJSONObject(a.name, a.get_influence_map_json());
          }
        }

        break;
        case "SM":
        for(Actuator a : my_smas) {
          if(a != null && a.installed) {
            act_inf_map.setJSONObject(a.name, a.get_influence_map_json());
          }
        }

        break;


        default:
          println("Unknown act_type " + act_type + " in call for JSON influence map");
        break;
      }

    }

    return act_inf_map;

  }


  // sets the influence map using a JSON object specific to this node.

  synchronized void set_actuator_inf_map_json(JSONObject node_inf_map) {

      for(Actuator a : my_moths) {
        set_inf_map_json(node_inf_map, a);
      }

      for(Actuator a : my_rebel_stars) {
        set_inf_map_json(node_inf_map, a);
      }

      for(Actuator a : my_protocells) {
        set_inf_map_json(node_inf_map, a);
      }

      for(Actuator a : my_double_rebel_stars) {
        set_inf_map_json(node_inf_map, a);
      }

      for(Actuator a : my_smas)  {
        set_inf_map_json(node_inf_map, a);
      }

  }

  synchronized void set_inf_map_json(JSONObject node_inf_map, Actuator a) {
        if(a != null && a.installed) {
          JSONObject act_inf_map = node_inf_map.getJSONObject(a.name);
          if(act_inf_map != null) {
            a.set_influence_map_json(act_inf_map);
          }        
        }
  }


  // trigger all my SMAs with random delay between them.

  void trigger_smas() {

    for (int i = 0; i < ACTUATOR_ARR_SIZE; i++)
      {
        if (my_smas[i].installed) 
        {  
          // trigger in random amount of time up to 800ms.
          int delay_time = int(random(1, 500));    // delay millis (will be stripped when message comes back)
          my_smas[i].trigger(delay_time);
        }
      } 
  }



  /*! Reads the device locator and instantiates the different actuators 
   Has to be in Node not dlnode/dlnodestorage because of C++ compatibility. 
   */
  synchronized void read_dl()
  {
    if (dl.node_exists(node_id))
    {
      int[] uids = dl.get_uids(node_id);
      String[] types = dl.get_types(node_id);
      String[] names = dl.get_names(node_id);
      String[] configs = dl.get_configs(node_id);
      PVector[] coordinates = dl.get_coordinates(node_id);

      int num_devices = dl.get_arr_len(node_id);

      // println(" for node " + node_id + " dl.get_arr_len is returning: " + num_devices + " and names.length is "+  names.length + " and types.length is " + types.length);

      for (int i = 0; i < num_devices; i++)
      {
        if (!names[i].equals("") && !types[i].equals(""))
        {
          int array_index_location = Integer.parseInt(names[i].substring(names[i].indexOf("_") + 3, names[i].length())) - 1;  
          if (array_index_location < 0)
            continue;
          if (uids[i] >= NUM_UIDS || uids[i] < 0)
            continue;

          if(configs[i].contains("USE_SAI")) {

            println(" ** SAI detected on " + node_id + ": " + names[i] + " config is: " + configs[i]);

          }

          DeviceIdentifier designator = new DeviceIdentifier(names[i].substring(names[i].indexOf("_") + 1, names[i].indexOf("_") + 3), array_index_location, configs[i]); // send configs to check for and configure SAIs.
          uid_to_type[uids[i]] = designator;

          switch(types[i])
          {
          case "SM":
          case "PL":
          case "CL":
            if (array_index_location >= ACTUATOR_ARR_SIZE)
            {
              uid_to_type[uids[i]] = null;
              continue;
            }
            my_smas[array_index_location].install(names[i], coordinates[i], uids[i], this, designator);
            break;
          case "MO":
            if (array_index_location >= ACTUATOR_ARR_SIZE)
            {
              uid_to_type[uids[i]] = null;
              continue;
            }
            my_moths[array_index_location].install(names[i], coordinates[i], uids[i], this, designator);
            break;
          case "RS":
            if (array_index_location >= ACTUATOR_ARR_SIZE)
            {
              uid_to_type[uids[i]] = null;
              continue;
            }
            my_rebel_stars[array_index_location].install(names[i], coordinates[i], uids[i], this, designator);
            break;
          case "PC":
            if (array_index_location >= ACTUATOR_ARR_SIZE)
            {
              uid_to_type[uids[i]] = null;
              continue;
            }
            my_protocells[array_index_location].install(names[i], coordinates[i], uids[i], this, designator);
            break;
          case "DR":
            if (array_index_location >= DR_ARR_SIZE)
            {
              uid_to_type[uids[i]] = null;
              continue;
            }
            my_double_rebel_stars[array_index_location].install(names[i], coordinates[i], uids[i], this, designator);
            break;
          case "WT":
            if (array_index_location >= WT_ARR_SIZE)
            {
              uid_to_type[uids[i]] = null;
              continue;
            }
            my_wav_triggers[array_index_location].install(names[i], coordinates[i], uids[i], this, designator);
            break;
          case "SD":
            if (array_index_location >= SD_ARR_SIZE)
            {
              uid_to_type[uids[i]] = null;
              continue;
            }
            my_sound_detectors[array_index_location].install(names[i], coordinates[i], uids[i], this, designator);
            break;
          case "IR":
            if (array_index_location >= IR_ARR_SIZE)
            {
              uid_to_type[uids[i]] = null;
              continue;
            }
            my_ir_detectors[array_index_location].install(names[i], coordinates[i], uids[i], this, designator);
            break;
          case "GE":
            if (array_index_location >= GE_ARR_SIZE)
            {
              uid_to_type[uids[i]] = null;
              continue;
            }
            my_grideyes[array_index_location].install(names[i], coordinates[i], uids[i], this, designator); 
            break;
          }
        } else if (names[i].equals(""))
        {
          System.out.println("Node " + Integer.toString(node_id) + " is missing a device, check the csv");
        }
      }
    }
  }
}
