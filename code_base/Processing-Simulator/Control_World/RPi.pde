/*!
 <h1> RPi </h1>
 Virtual RPi object
 
 \author Matt Gorbet et al
 
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
  
 
  GridEye my_ge = null;


  ArrayList<Integer> children_nodes = new ArrayList<Integer>();

  /*! 
   *  \fn RPi(String ip, String name)
   *  \brief constructor for the RPi
   *  \param ip the ip address of the RPi
   *  \param name the name of the RPi
   *  \return none
   */
  RPi(String ip, String name) {

    // name thread:
    super("Virtual Pi ("+ip+") thread");
    
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

        //do something
        if (message.get_code().contains(this.my_address)) {  // could contain pi's address as sender, fixed above -mg
          //This message was meant for me
          if (this.debug) {
            print("For me: " + message.get_code() + "\t");
            println(message.get_data());
          }

          if (message.get_code().contains("PING")) {
            String control_ip = dl.get_control_ip(this.my_address);
            network.write_message("/RPI/PING/" + this.my_address + "/" + control_ip + " ");
          }


          //MATT-GRIDEYE 

          if (message.get_code().contains("GE_")) {
               
           ArrayList<Integer> GNs = dl.get_node_type_ids("GN");  // get all grideye node addresses, let's try to find this PI's GE

           for (int i = 0; i < GNs.size(); i++ ) {
            try {
              if (dl.find_nodes_parent_rpi(GNs.get(i)).my_address.equals(my_address) ) {
               my_ge = dl.nodes.get(GNs.get(i)).my_grideyes[0]; // assumes only one GE per GN
              }
            }
            catch(NullPointerException e)
            {
              println("Warning: Virtual RPI at " + this.my_address + " received a message for its GridEye, null pointer looking for it.");
            }
           }

            if(my_ge != null && my_ge.installed) {
            if (message.get_code().contains("GE_CONFIG")) {
              int num_fields = message.get_data().length;
              if(message.get_data()[ num_fields -1 ].contains( str(GridEye.CONFIG_DELIMITER) )) {  // this is full config string, get uncut
                //println(" ... received a ge_config in full config string format: " + message.get_uncut_data());
                my_ge.parse_config_string(message.get_uncut_data()); 
              } else {
                //println(" ... received a ge_config in [][] format: ["+ message.get_data()[0] + "][" + message.get_data()[1] + "]");
                my_ge.configure_grideye(message.get_data());   // this is an already parsed pair in String[] format.
              }
            } else if (message.get_code().contains("GE_SET_BACKGROUND")) {
              my_ge.setBackground = true;
            } else if (message.get_code().contains("GE_SET_FORWARDING")) {
              my_ge.stream = (message.get_data()[0].equals("ON"));
            }
            } else {
              println("Warning: Virtual RPI at " + this.my_address + " received a message for its GridEye, but doesn't have one or it's not installed.");
            }
          }
        } else {
          //message meant for node or control
          if (debug) {
            print("Not for me: " + message.get_code() + "\t");
            println(message.get_data());
          }

          if (message.get_code().contains("/CONTROL/")) {
            forward_message_to_node(message);
          } 
          else if (message.get_code().contains("/NODE/")) {
            if (message.get_code().contains("SD_PT_SAMPLING_CONTROL")) {
              String control_ip = dl.get_control_ip(this.my_address);      
              if(!override_control_ip.equals("")) control_ip = override_control_ip;  
              message.set_code(message.get_code() + "/" + control_ip);     
              if (debug) println("... forwarding to Control");
              network.write_message(message);
            } 
            else if (message.get_code().contains("SD_PT_SAMPLING_RPI")) {
               //do something on the RPI with an SD level...
            } 
            else if (message.get_code().contains("IR_PT_SAMPLING_CONTROL")) {
              String control_ip = dl.get_control_ip(this.my_address);        
              if(!override_control_ip.equals("")) control_ip = override_control_ip;  
              message.set_code(message.get_code() + "/" + control_ip);     
              if (debug) println("... forwarding to Control");
              network.write_message(message);
            } 
            else if (message.get_code().contains("IR_PT_SAMPLING_RPI")) {
              //do something on the RPI with an IR level...
            } else if (message.get_code().contains("DELAY_MESSAGE")) {
              message.set_code("/RPI/DELAY_MESSAGE/" + my_address + "/" + message.get_code().split("/")[3]);
              message.delay(0);
              forward_message_to_node(message);
            }
          }
        }
      }


      // tell monitor to check times for pings  (we don't do this for virtual pis - yet?)
      // monitor.update();

      try {
        Thread.sleep(0, 5);
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

    //if(message_to_forward.get_code().contains("DELAY")) {
    //println("PI is forwarding: " + message_to_forward.get_code() + " || ");
    //println(message_to_forward.get_data());
    //}

    if (network.is_real)
      network.write_message(message_to_forward.get_code().split("/")[3], int(message_to_forward.get_code().split("/")[4]), message_to_forward);
    else  
      network.write_message(message_to_forward.get_code().split("/")[3],     message_to_forward.get_code().split("/")[4],  message_to_forward);
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

              //println("   RPI -> sending myself (" + this.my_address + ") config message:  " + 
              //                      "/RPI/" + node_devices[i].substring(0,2) + "_CONFIG/" + this.my_address + "/" + this.my_address + " " + trim(commands[j].split(" ")[0]) + " " + trim(commands[j].split(" ")[1]));
              network.write_message("/RPI/" + node_devices[i].substring(0,2) + "_CONFIG/" + this.my_address + "/" + this.my_address + " " + trim(commands[j].split(" ")[0]) + " " + trim(commands[j].split(" ")[1]));

              break;

              default:
      
              // need to skip SAI config strings for now because they crash live mode:
              if(node_configs[i].contains("USE_SAI")) {
                println("  **** Skipping SAI config:  [" + node_configs[i] + "]  ");
                continue;
              }


              //println("   RPI -> sending " + node_id + " config message:  " + 
              //                      "/RPI/" + node_devices[i].substring(0,2) + "_CONFIG/" + this.my_address + "/" + node_id + " " + node_devices[i] + " " + trim(commands[j].split(" ")[0]) + " " + trim(commands[j].split(" ")[1]));
              network.write_message("/RPI/" + node_devices[i].substring(0,2) + "_CONFIG/" + this.my_address + "/" + node_id + " " + node_devices[i] + " " + trim(commands[j].split(" ")[0]) + " " + trim(commands[j].split(" ")[1]));
              break;
            }
          }
        }
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
