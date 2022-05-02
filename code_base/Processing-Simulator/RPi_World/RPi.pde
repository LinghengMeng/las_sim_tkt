/*!
 <h1> RPi </h1>
 Real RPi object
 
 \author Farhan Monower et al

 */


/*! \class RPi
 *  \brief RPi object
 */
class RPi extends Thread {

  /*! \var pi_id
   *  the name of the pi
   */
  String pi_id;

  /*! \var my_address
   *  the ip of the Pi
   */
  String my_address;

  /*! \var debug
   *  choose whether or not to generate printlns for testing
   */
  boolean debug = false;

  /*!
   *  \var CONFIG_DELIMITER
   *  used to parse the configuration string to initialize the specific device
   */
  static final char CONFIG_DELIMITER = ';';

  /*! 
   *  \fn RPi(String ip, String name)
   *  \brief constructor for the RPi
   *  \param ip the ip address of the RPi
   *  \param name the name of the RPi
   *  \return none
   */
  RPi(String ip, String name) {


    my_address = ip;
    pi_id = name;
    print("I am an RPi with ID " + pi_id + " and my IP address is: " + my_address);
    println();
  }

  /*! 
   *  \fn run()
   *  \brief the main loop for the RPi thread
   *  \return none
   */
  public void run() {
    while (true) {
      message_OSC message = network.get_message(this.my_address);
      if (message != null) {
         String[] code_parts = message.get_code().split("/");
      //   if(code_parts[(code_parts.length)].contains(this.my_address)) {
        //do something
        if (message.get_code().contains(this.my_address)) {  // could contain pi's address as sender, fixed above -mg
          //This message was meant for me
          if (this.debug) {
            print("For me: " + message.get_code() + "\t");
            println(message.get_data());
          }

          if (message.get_code().contains("/CONTROL/PING")) {
            String control_ip = dl.get_control_ip(this.my_address);
            network.write_message("/RPI/PING/" + this.my_address + "/" + control_ip + " ");
            // println(" --->  PING " + "/RPI/PING/" + this.my_address + "/" + control_ip + " ");
            monitor.record_ping_from_control();
          }


          //MATT-GRIDEYE 
          if (message.get_code().contains("GE_CONFIG")) {

              int num_fields = message.get_data().length;
              if(message.get_data()[ num_fields -1 ].contains(str(CONFIG_DELIMITER)) ) {  // this is full config string, get uncut
                parse_grideye_config_string(message.get_uncut_data()); 
              } else {
                configure_grideye(message.get_data());   // this is an already parsed pair in String[] format.
              }

          } else if (message.get_code().contains("GE_SET_BACKGROUND")) {
            ge.setBackground = true;
          } else if (message.get_code().contains("GE_SET_FORWARDING")) {
            ge.stream = (message.get_data()[0].equals("ON"));
          }
        } else {
          //message meant for node or control
          if (debug) {
            print("Not for me: " + message.get_code() + "\t");
            println(message.get_data());
          }

          if (message.get_code().contains("/CONTROL/")) {
            forward_message_to_node(message);
          } else if (message.get_code().contains("/NODE/")) {
            if (message.get_code().contains("SD_PT_SAMPLING_CONTROL")) {
              String control_ip = dl.get_control_ip(this.my_address);        
              message.set_code(message.get_code() + "/" + control_ip);   
              network.write_message(message);
            } else if (message.get_code().contains("SD_PT_SAMPLING_RPI")) {
              //do something on the RPI with an SD level...
            } else if (message.get_code().contains("IR_PT_SAMPLING_CONTROL")) {
              String control_ip = dl.get_control_ip(this.my_address);        
              message.set_code(message.get_code() + "/" + control_ip);   
              network.write_message(message);
            } else if (message.get_code().contains("IR_PT_SAMPLING_RPI")) {
              //do something on the RPI with an IR level...
            } else if (message.get_code().contains("DELAY_MESSAGE")) {  // delivering on a real message
              message.set_code("/RPI/DELAY_MESSAGE/" + my_address + "/" + message.get_code().split("/")[3]);
              message.delay(0);
               // print(" forwarding delayed message back to "+ message.get_code().split("/")[4] + " | ");
               // println(message.get_data());
              forward_message_to_node(message);
            }
          }
        }
      }

      // tell monitor to check times for pings
      monitor.update(this);

      try {
        Thread.sleep(0, 100);
      }
      catch (Exception e) {
        e.printStackTrace();
      }
    }
  }

  /*! 
   *  \fn forward_message_to_node(message_OSC message_to_forward)
   *  \brief forwards message if the message is not meant for the pi, helper function
   *  \param message_to_forward the message to forward
   *  \return none
   */
  synchronized void forward_message_to_node(message_OSC message_to_forward) {
    if (network.is_real) {
      // should it be delayed?
      // debgging:
      //if(message_to_forward.get_code().contains("FADE_")) {
      //   println(" forwarding message with deliver time " + (message_to_forward.deliver_time - millis()) + "ms from now") ;
      //}
      if(message_to_forward.deliver_time > millis()) {
        // println(" queuing it");
        network.real_received_message_queue.offer(message_to_forward);  // put it in the prioritized queue
      } else {
        // println(" sending ");
        network.write_message(message_to_forward.get_code().split("/")[3], int(message_to_forward.get_code().split("/")[4]), message_to_forward);
      }
    }
    else  
    network.write_message(message_to_forward.get_code().split("/")[3], message_to_forward.get_code().split("/")[4], message_to_forward);
  }


  /*!
     *  \fn parse_grideye_config_string(String[] params)
   *  \brief MATT - TODO
   *  \param params
   *  \return none
   */

  boolean parse_grideye_config_string(String config_string)
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
    println("configuring grideye: " + params[0] + ": " + params[1]);
    String argument = params[0];
    if (argument.equals("FREQUENCY")) {
      ge.polling_frequency = int(params[1]);
    } else if (argument.equals("THRESHOLD_MOTION")) {
      ge.motion_threshold = float(params[1]);
    } else if (argument.equals("THRESHOLD_PRESENCE")) {
      ge.presence_threshold = float(params[1]);
    } else if (argument.equals("INTEREST_THRESHOLD")) {
      interestThreshold = float(params[1]);
      ge.gridEyeControl.ge_interest_thresh.setValue(interestThreshold);
    } else if (argument.equals("NOISE_THRESHOLD")) {
      noiseThreshold = float(params[1]);
      ge.gridEyeControl.ge_noise_thresh.setValue(noiseThreshold);
    } else if (argument.equals("OVERALL_RELAX")) {
      overall_relax = float(params[1]);
      ge.gridEyeControl.ge_overall_relax.setValue(overall_relax);
    } else if (argument.equals("FRAMESKIP")) {
      frameskip = int(params[1]);
      ge.gridEyeControl.ge_frameskip.setValue(frameskip);
    }
  }
  

/////  SENSOR MESSAGING FOR GRIDEYE CONFIG ==========================


  /*!
   *  \fn get_num_commands(String str)
   *  \brief MATT - TODO
   *  \param str
   *  \return int number of commands
   */
  protected int get_num_commands(String str)
  {
    int num_commands = 0;
    for (int i = 0; i < str.length(); i++)
    {
      if (str.charAt(i) == CONFIG_DELIMITER)
        num_commands++;
    }
    return num_commands;
  }

  /*!
   *  \fn get_full_command(String str, int num)
   *  \brief MATT - TODO
   *  \param str
   *  \param num
   *  \return the full string command
   */
  protected String get_full_command(String str, int num)
  {
    int num_delimiters = 0;
    int last_delimiter_index = 0;
    for (int i = 0; i < str.length(); i++)
    {
      if (str.charAt(i) == CONFIG_DELIMITER)
      {
        num_delimiters++;
      }

      if (num_delimiters == num + 1)
      {
        if (num == 0)
          return str.substring(last_delimiter_index, i);
        return str.substring(last_delimiter_index + 1, i);
      }

      if (str.charAt(i) == CONFIG_DELIMITER)
      {
        last_delimiter_index = i;
      }
    }

    return "";
  }

  // maybe we don't want to return a String array because of pointer restrictions in C++. 
  // not a big deal to seperate these out in two commands; get_command_keyword(), get_command_arguments()
  // even though it may not be as efficient. 
  /*!
   *  \fn get_command(String str, int num)
   *  \brief MATT - TODO
   *  \param str
   *  \param num
   *  \return the string array command
   */
  protected String[] get_command(String str, int num)
  {
    String[] seperated_command = new String[2];
    String full_command = get_full_command(str, num);

    if (full_command.equals(""))
    {
      seperated_command[0] = "";
      seperated_command[1] = "";
      return seperated_command;
    }

    int keyword_end_index = 0; 
    boolean argument = true;

    if (full_command.indexOf(" ") > 0)
      keyword_end_index = full_command.indexOf(" ");
    else if (full_command.indexOf(";") > 0) {
      keyword_end_index = full_command.indexOf(";");
      argument = false;
    } else if (full_command.charAt(full_command.length() - 1) != ' ' && full_command.charAt(full_command.length() - 1) != ';') {
      keyword_end_index = full_command.length();
      argument = false;
    }

    String keyword = full_command.substring(0, keyword_end_index);

    String arguments = "";
    if (argument)
      arguments = full_command.substring(full_command.indexOf(" ") + 1, full_command.length());

    seperated_command[0] = keyword;
    seperated_command[1] = arguments;

    return seperated_command;
  }
  



  /*! 
   *  \fn send_device_configs(int node_id)
   *  \brief Sends the config string info to the node for all appropriate devices.
   *  \ call this whenever a node is found (even at first handshake)
   *  \param node id
   *  \return none
   */
  synchronized void send_device_configs(int node_id)  
  {
     send_device_configs(node_id, "ALL");
  }

  synchronized void send_device_configs(int node_id, String device_type)
  {
    // grab the configs for this node
    String[] node_configs = dl.get_configs(node_id);
    // grab the designators for this (type from node_id)
    String[] node_devices = dl.get_devs(dl.get_node_type(node_id));

    int n = node_devices.length;
    if(node_configs.length < n) n = node_configs.length;  // some nodes types may have fewer node_configs than devices in that type;

    // println("Configuring devices on node " + node_id + ":");
    // print("   names are: [ ");
    // for(int i = 0; i < node_devices.length; i++) { print(node_devices[i] + ", ");}
    // println(" ]");

    // for each device
    for (int i = 0; i < n; i++) 
    {        
      if(!node_configs[i].equals("")) {
        if(device_type.equals(node_devices[i].substring(0,2)) || device_type.equals("ALL")) {
          String[] commands = node_configs[i].split(";");
          for (int j = 0 ; j < commands.length ; j++) { 

            switch(node_devices[i].substring(0,2)) {

              case("GE"):     // grideyes are slightly different - rpi sends to itself instead of node, and don't need device identifier

              //println("   RPI -> sending myself (" + network.my_address + ") config message:  " + 
              //                      "/RPI/" + node_devices[i].substring(0,2) + "_CONFIG/" + network.my_address + "/" + network.my_address + " " + trim(commands[j].split(" ")[0]) + " " + trim(commands[j].split(" ")[1]));
              network.write_message("/RPI/" + node_devices[i].substring(0,2) + "_CONFIG/" + network.my_address + "/" + network.my_address + " " + trim(commands[j].split(" ")[0]) + " " + trim(commands[j].split(" ")[1]));

              break;

              default:
              //println("   RPI -> sending " + node_id + " config message:  " + 
              //                      "/RPI/" + node_devices[i].substring(0,2) + "_CONFIG/" + network.my_address + "/" + node_id + " " + node_devices[i] + " " + trim(commands[j].split(" ")[0]) + " " + trim(commands[j].split(" ")[1]));
              network.write_message("/RPI/" + node_devices[i].substring(0,2) + "_CONFIG/" + network.my_address + "/" + node_id + " " + node_devices[i] + " " + trim(commands[j].split(" ")[0]) + " " + trim(commands[j].split(" ")[1]));
              break;
            }
          }
        }
      }
    }
  }

/*! 
   *  \fn pi_lost_control()
   *  \brief Pi has lost contact with control so should tell actuators to fade out or go local.
   *  \param none
   *  \return none
   */
  synchronized void pi_lost_control()  
  {
    // for each node
    if(network.map_built) {
      for(int node_id : network.my_pis_node_port.keySet()) { 
        network.write_message("/RPI/LOST_CONTROL/" + network.my_address + "/" + node_id + " TRUE");
      }
    }
  }


  /*! 
   *  \fn go()
   *  \brief does nothing at the moment, abstracted
   *  \return none
   */
  void go() {
  }
}
