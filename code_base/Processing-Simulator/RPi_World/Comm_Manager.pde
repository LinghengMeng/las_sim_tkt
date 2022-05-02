/*! 
 <h1> Comm_Manager </h1>
  messaging object on the control level and associated variables 
  \author Farhan Monower et al
 */

import java.util.concurrent.*;
import java.util.*;
import java.net.*;
import hypermedia.net.*;
import processing.net.*;
import java.util.AbstractMap.*;
import java.lang.Long;
import java.nio.*;

/*!
 * \brief message codes for message building 
 */
int NUM_SOM = 2;
int NUM_EOM = 2;
int NUM_ID = 3;
int SOM1 = int(0xff);
int EOM1 = int(0xfe);

int CODE__PING = int(0x01);
int CODE__LOST_CONTROL = int(0x02);

/*! 
 * used by FADE_ACTUATOR_VALUES to set actuator levels
 */
int CODE__FADE_ACTUATOR_GROUPS = int(0x1a);
int CODE__FADE_ACTUATOR_GROUPS_DR_X = int(0x1f);
/*! 
 * used by UPDATE ACTUATOR_INFLUENCES 
 */
int CODE__UPDATE_ACTUATOR_INFLUENCES = int(0x1b);
/*! 
 * used by DR_SET_MODEto set actuator mode
 */
int CODE__DR_CONFIG                = int(0x30);
int CODE__DR_SET_MODE              = int(0x3a);
int CODE__DR_MODE_BOTH             = int(0x3b);
int CODE__DR_MODE_TIP_ONLY         = int(0x3c);
int CODE__DR_MODE_BULB_ONLY        = int(0x3d);
int CODE__DR_MODE_TIP_HALF_BULB    = int(0x3e);
int CODE__DR_MODE_BULB_HALF_TIP    = int(0x3f);
int CODE__DR_MODE_CHARGE_DISCHARGE = int(0x40);
int CODE__DR_MODE_OSCILLATE        = int(0x41);
int CODE__DR_BOTTOM_PIN            = int(0x4c);
int CODE__DR_INVERT                = int(0x4d);
int CODE__DR_OFFSET                = int(0x4e);

/*! 
 * Sound sensor codes
 */
int CODE__SD_CONFIG = int(0x20);
int CODE__SD_ENVELOPE_PIN = int(0x29);
int CODE__SD_INVERT = int(0x28);
int CODE__SD_PT_SAMPLING_CONTROL = int(0x2a);
int CODE__SD_PT_SAMPLING_RPI = int(0x2b);
int CODE__SD_AUTO_SAMPLING = int(0x2c);
int CODE__SD_SET_THRESHOLD = int(0x2d);
int CODE__SD_SET_FREQUENCY = int(0x2e);
int CODE__SD_LIVE_OR_LOCAL = int(0x2f);

/*! 
 * IR sensor codes
 */
int CODE__IR_CONFIG = int(0x80);
int CODE__IR_PT_SAMPLING_CONTROL = int(0x8a);
int CODE__IR_PT_SAMPLING_RPI = int(0x8b);
int CODE__IR_AUTO_SAMPLING = int(0x8c);
int CODE__IR_SET_THRESHOLD = int(0x8d);
int CODE__IR_SET_FREQUENCY = int(0x8e);
int CODE__IR_LIVE_OR_LOCAL = int(0x8f);

/*!
 * INFLUENCE TYPE codes
 */
int CODE__INFLUENCE_TYPE_WV  = int(0x50);
int CODE__INFLUENCE_TYPE_RN  = int(0x51);
int CODE__INFLUENCE_TYPE_IR  = int(0x52);
int CODE__INFLUENCE_TYPE_SD  = int(0x53);
int CODE__INFLUENCE_TYPE_GE  = int(0x54);
int CODE__INFLUENCE_TYPE_EXP = int(0x55);
int CODE__INFLUENCE_TYPE_GR  = int(0x56);
int CODE__INFLUENCE_TYPE_EC  = int(0x57);
int CODE__INFLUENCE_TYPE_RH  = int(0x58);


/*! 
 * WAV Trigger codes
 */
int CODE__WAV_PLAY_SOUND = int(0x6b);   // note these changed after futurium
int CODE__WAV_MASTER_GAIN = int(0x6c);
int CODE__WAV_TRACK_GAIN = int(0x6d);
int CODE__WAV_TRACK_FADE = int(0x6e);
// int CODE__WAV_MASTER_STOP = int(0x1f);

/*! 
 * Influence map and range codes
 */
int CODE__INFLUENCE_MAP    = int(0xc2);
int CODE__INFLUENCE_RANGE  = int(0xc1);

/*! 
 * password used in hanshaking
 */
int CODE__PASSWORD = int(0xaa);
int CODE__DEBUG_MESSAGE = int(0xdd);

/*!
 *  code used for delay
 */
 int CODE__DELAY_MESSAGE = int(0x70);
/*! 
 * \var password_array
 * array written to nodes during handshaking
 */
byte[] password_array = {byte(0xff), byte(0xff), byte(0x00), byte(0x00), byte(0x00), byte(0x02), byte(0xaa), byte(0x04), byte(0x05), byte(0xfe), byte(0xfe)};

/*! 
 * \var INDEX_OF_CODE
 * The array index where the message code for CODE__PASSWORD is contained from the message sent from the node
 */
int INDEX_OF_CODE = 6;

/*! 
 * \var node_not_found_sentinel
 * sentinel value returned when a node is not found in handshaking
 */
int node_not_found_sentinel = -99;

/*! 
 * \var message_count_this_frame
 * 
 */
int message_count_this_frame;

/*! 
 * \var SIM
 * initialized to false, used by the Control World
 */
public static boolean SIM = false;
/*! 
 * \var LIVE
 * initialized to true, used by the Control World
 */
public static boolean LIVE = true;

/*! \class Comm_Manager
 *  \brief Handles internal communication between Control, RPi and Nodes
 *  \author Farhan Monower
 */
public class Comm_Manager {


  /*! 
   * \var map_built
   * state variable used to know if the map is done, not used manually
   */
  boolean map_built = false;


  /*! 
   * used to do printlns
   */
  boolean debug = false;

  /*! 
   * tells comm manager to use the ethernet or the wifi ip address
   */
  boolean use_wifi = false;
  /*! 
   * port allocation
   */
  int osc_port = 4000; 
  int grideye_live_port = 5445;

  /*! 
   * variables used in handshaking
   */
  int password_reply_length = 12;
  int poll_length = 100;
  int ports_timeout_time = 10000;
  int serial_port_limit = 64;



  /*! 
   * \var my_address
   * used by objects to get the current instance's ip address
   */
  String my_address = "";


  /*! 
   * \var real_received_message_queue
   * PriorityBlockingQueue object that stores osc messages going to and coming from internal devices (pis and nodes)
   */
  PriorityBlockingQueue<message_OSC> real_received_message_queue = new PriorityBlockingQueue<message_OSC>();

  /*!
   * /par Logic of real, live, and sim
   * if(this.is_a_Pi) then this.is_real and this.is_live
   * else if (this.is_a_Control && this.is_a_Visualization) then !this.is_real and !this.is_live
   * else if (this.is_a_Control && this.is_live) then !this.is_real and this.is_live
   */
  boolean is_live =  true;
  boolean is_real =  true;


  /*! 
   * \var virtual_message_map
   * Hashmap that stores LinkedBlockingQueues corresponding to each virtual instance of a pi and a node. Stores the virtual messages going to them.
   */
  ConcurrentHashMap<String, PriorityBlockingQueue<message_OSC>> virtual_message_map;

  /*! 
   * \var my_pis_node_port
   * Used on the pi only, maps a node id to a serial port.
   */
  ConcurrentHashMap<Integer, Serial> my_pis_node_port;

  /*! 
   * \var device_locator
   * Device locator instance for comm_manager to use
   */
  DeviceLocator device_locator;

  /*! \fn Comm_Manager(boolean state, DeviceLocator dev_loc)
   *  \brief Constructor to be used by PI
   *  note: the ip address finding code might require editing based on applcation e.g. which_network_type might = "eth1" or = "en0" based on application
   *  \param state boolean stating if LIVE or SIM
   *  \param dev_loc active device locator instance
   *  \return none.
   */
  Comm_Manager(boolean state, DeviceLocator dev_loc) {

    this.is_live = state;

    if (this.is_live) {
      initialize_osc(osc_port);
    }

    this.is_real = false;
    this.device_locator = dev_loc;

    try {
      Enumeration<NetworkInterface> nets = NetworkInterface.getNetworkInterfaces();
      for (NetworkInterface netint : Collections.list(nets)) {
        Enumeration<InetAddress> inetAddresses = netint.getInetAddresses();
        for(InetAddress inetAddress : Collections.list(inetAddresses))
        {
          String current_ip = inetAddress.toString().substring(1);
          if(dl.is_control_ip(current_ip))
          {
            this.my_address = current_ip;
            break;
          }
        }

        if(!this.my_address.equals(""))
          break;
      }

      if(this.my_address.equals(""))
      {
        println("No interfaces found with control IP... This is the network interface info: ");
        for(NetworkInterface netint : Collections.list(nets))
          displayInterfaceInformation(netint);
        println("Aborting...");
        exit();
      }
    }
    catch (SocketException e) {
      println("socket exception " + e);
    }

    print("STATUS: ");
    if (this.is_live)
      println("LIVE");
    else
      println("SIM");


    message_count_this_frame = 0;

    // pi_times = new ConcurrentHashMap<String, Long>();
  }

  /*! \fn Comm_Manager(DeviceLocator dev_loc)
   *  \brief Constructor to be used by RPI
   *  note: the ip address finding code might require editing based on applcation e.g. which_network_type might = "eth1" or = "en0" based on application
   *  \param dev_loc active device locator instance
   *  \return none.
   */
  Comm_Manager(DeviceLocator dev_loc) {
    initialize_osc(osc_port);

    this.my_pis_node_port = new ConcurrentHashMap<Integer, Serial>();
    this.is_live = LIVE;
    this.is_real = true;
    this.device_locator = dev_loc;


    try {
      Enumeration<NetworkInterface> nets = NetworkInterface.getNetworkInterfaces();
      for (NetworkInterface netint : Collections.list(nets)) {
        Enumeration<InetAddress> inetAddresses = netint.getInetAddresses();
        for(InetAddress inetAddress : Collections.list(inetAddresses))
        {
          String current_ip = inetAddress.toString().substring(1);
          if(device_locator.is_raspberry_pi_ip(current_ip) || (use_wifi && device_locator.get_network_prefix().length() > 0 && current_ip.contains(device_locator.get_network_prefix())))
          {
            this.my_address = current_ip;
            break;
          }
        }

        if(!this.my_address.equals(""))
          break;
      }

      if(this.my_address.equals(""))
      {
        println("No interfaces found with raspberry pi IP... This is the network interface info: ");
        for(NetworkInterface netint : Collections.list(nets))
          displayInterfaceInformation(netint);
        println("Aborting...");
        exit();
      }
    }
    catch (SocketException e) {
      println("socket exception " + e);
    }

    println("My address: " + this.my_address);

    println("REAL");

    message_count_this_frame = 0;
    // node_times = new ConcurrentHashMap<String, Long>();
  }

  /*! \fn control_build_virtual_map(PApplet p)
   *  \brief function used to build the virtual_message_map, called automatically. Comment out on RPi comms manager.
   *  \param p current instance
   *  \return none.
   */
  //void control_build_virtual_map(PApplet p) {
  //  virtual_message_map= new ConcurrentHashMap<String, LinkedBlockingQueue<message_OSC>>();
  //  LinkedBlockingQueue<message_OSC> new_queue = new LinkedBlockingQueue<message_OSC>();
  //  this.virtual_message_map.put(this.my_address, new_queue);

  //  for (Map.Entry<String, RPi> entry : device_locator.get_RPis().entrySet()) {
  //    String id = entry.getKey();
  //    RPi current_rpi = entry.getValue();
  //    LinkedBlockingQueue rpi_queue = new LinkedBlockingQueue<message_OSC>();
  //    this.virtual_message_map.put(current_rpi.my_address, rpi_queue);
  //    this.pi_times.put(current_rpi.my_address, new Long(millis())); //build rpi time list for control
  //  }

  //  for (Map.Entry<Integer, Node> entry : device_locator.get_nodes().entrySet()) {
  //    Integer id = entry.getKey();
  //    Node current_node = entry.getValue();
  //    LinkedBlockingQueue node_queue = new LinkedBlockingQueue<message_OSC>();
  //    this.virtual_message_map.put(Integer.toString(current_node.node_id), node_queue);
  //  }
  //}

  /*! \fn rpi_build_real_node_map()
   *  \brief function used to build the node's serial ports map and do handshaking on the rpis
   *  \return none.
   */
  void rpi_build_real_node_map() {
    print("Ports (zero-based): ");
    println(Serial.list());

    handshake();

    this.map_built = true;
  }

  void handshake() {

    for (int i = 0; i < setup_ports.size(); i ++) {  // iterate through ArrayList  -mg
    Serial handshake_port = setup_ports.get(i);
       if (handshake_port != null && !(my_pis_node_port.contains(handshake_port)) ) {  // if we don't already have this one registered
        int received_node_id = write_password_to_port(handshake_port);
        if (received_node_id != node_not_found_sentinel) {
          println("Node ID received: " + received_node_id);
          this.my_pis_node_port.put(received_node_id, handshake_port); //port registered

          if (use_grideye) {
            if (dl.get_node_type(received_node_id).equals("GN")) {            
              //     if(received_node_id == grideye_ID) {   // <== HACK stop using the hardcoded grideye, use Niel's DL code instead
              println("...found my grideye!");
              grideye_ID = received_node_id;
              //  delay(5000);
              handshake_port.bufferUntil('@');
            }
          } 

          if(received_node_id != grideye_ID) { 
            monitor.record_node_seen(str(received_node_id));
          }
        }
      }
    }
  }

  /*! \fn write_password_to_port(Serial port)
   *  \brief helper function used to do handshaking in rpi_build_real_node_map
   *  \param port the Serial port instance to do handshaking with
   *  \return an integer node id, or a sentinel value of -99 to show that nothing was found
   */
  int write_password_to_port(Serial port) {
    boolean id_received = false;
    int[] incoming_bytes = new int[password_reply_length];
    boolean timeout = false;
    int start_time = millis();
    while (!id_received && !timeout) {
      println("Writing password to port...");
      port.write(password_array);
      port.clear();

      delay(500);
      boolean SOM_received = false;
      boolean timeout_SOM_received = false;
      incoming_bytes = new int[password_reply_length];
      int start_SOM_received = millis();


      while (!SOM_received && !timeout_SOM_received && port.available() >= incoming_bytes.length) {
        print("Reading port ("+port.available()+" bytes available): ");

        for (int k = 0; k < incoming_bytes.length; k++) {
          incoming_bytes[k] = port.read();
          delay(30);
          print("0b"+ hex(incoming_bytes[k])+ " " );
        }
        println("---" + incoming_bytes);

        if (incoming_bytes[INDEX_OF_CODE] == CODE__PASSWORD) {
          SOM_received = true;
          id_received = true;
          println(" Received SOM");
        }


        if (millis() - start_SOM_received > poll_length && !SOM_received) {
          timeout_SOM_received = true;
          println("SOM not received");
        }
      }

      if (millis() - start_time > ports_timeout_time) {
        timeout = true;
        println("Timeout!");
      }
    }

    if (id_received)
      return (incoming_bytes[7] << 16) | (incoming_bytes[8] << 8) | (incoming_bytes[9]);

    return node_not_found_sentinel;
  }



  /*! \fn write_message(String message)
   *  \brief used to communicate with rpis and nodes. Final elseif needs to be commented out on RPi comm manager
   *  \param message a string with a code and multiple data entries that are space separated
   *  \return none
   */
  synchronized void write_message(String message) {
    message = message.toUpperCase();
    String[] temp = message.split(" ");
    String data = "";
    for (int i = 1; i < temp.length; i++) {
      data += temp[i];
      if (i != temp.length - 1)
        data += " ";
    }

    message_OSC m = new message_OSC(temp[0], data);

    write_message(m);

  }

  /*! \fn write_message(message_OSC m)
   *  \brief used to communicate with rpis and nodes
   *  \param m message_OSC to send
   *  \return none
   */
  synchronized void write_message(message_OSC m) {

    int code_length = m.get_code().split("/").length;

    boolean valid = message_check(m);
    if (!valid) return;

    long delay_time = 0;

    String[] contents = Arrays.copyOfRange(m.get_code().split("/"), 1, m.get_code().split("/").length);
    String source = contents[0];
    String code = contents[1];
    String src_addr = contents[2];
    String dest_addr = "";


    if(contents.length > 3) {                       // 4th part of code is either dest address or delay time
           if(contents[3].charAt(0) != 'T') {  // if it's not delay time
             dest_addr = contents[3];
             if(contents.length > 4) {  // if there was a dest address AND a delay time
               delay_time = Long.parseLong(contents[4].substring(1));  // grab millis to delay 
             }
           }
           else {
             delay_time = Long.parseLong(contents[3].substring(1));   // grab millis to delay
           }
    }
         
    if(delay_time > 0 || m.deliver_time > millis()) {
       println("setting delay time to " + delay_time + " for message. delay time is alrady " + (m.deliver_time - millis()) + "ms from now.");
       println("Code: " + m.get_code());
       m.delay(delay_time);
    }         

    if (source.equals("CONTROL") && dest_addr.contains(".")) {
      //control to pi
      write_message(src_addr, dest_addr, m);
    } else if (source.equals("CONTROL") && !dest_addr.contains(".")) {
      //control to node
      write_message(src_addr, Integer.parseInt(dest_addr), m);
    } else if ( source.equals("RPI") && dest_addr.contains(".")) {
      //rpi to control  (eg grideye)
      write_message(src_addr, dest_addr, m);
    } else if (source.equals("RPI") && !dest_addr.contains(".")) {
      //rpi to node
      write_message(src_addr, Integer.parseInt(dest_addr), m);
    }
     else if (source.equals("NODE") && dest_addr.contains(".")) {
    //  node forwarding to control via rpi (eg SD)
        write_message(this.my_address, dest_addr, m);
    }
  }


  /*! \fn write_message(String source_address, String destination_address, message_OSC message_in)
   *  \brief used to communicate with rpis and nodes, helper function but can be called publically
   *  \param source_address the source of the message
   *  \param destination_address the destination of the message
   *  \param message_in the osc message to send
   *  \return none
   */
  synchronized void write_message(String source_address, String destination_address, message_OSC message_in) {

    //comment out on RPi

    //if (mute_messages) {

    //  return;
    //}

    if (!this.is_real)
      this.virtual_message_map.get(destination_address).offer(message_in);

    //Send the OSC message if LIVE or REAL
    if ((this.is_live || this.is_real) && source_address.equals(this.my_address) && destination_address.contains(".")) {
      NetAddress destination_remote = new NetAddress(destination_address, this.osc_port);
      internal_comms.send(message_in.get_OSC(), destination_remote);
    }
  }


  /*! \fn write_message(int source_address, message_OSC message_in)
   *  \brief used to send message from the virtual node to its Pi, helper function but can be called publically. comment out on RPi comms_manager.
   *  \param source_address the source node id of the Node
   *  \param message_in the osc message to send
   *  \return none
   */
  //synchronized void write_message(int source_address, message_OSC message_in) {
  //  RPi target_rpi = device_locator.find_nodes_parent_rpi(source_address);
  //  write_message(Integer.toString(source_address), target_rpi.my_address, message_in);
  //}


  /*! Send message to a node from control or RPi (real and virtual)
   \param source_address the source address of the message
   \param destination_address the node id to send message to
   \param message_in message to send */
  synchronized void write_message(String source_address, int destination_address, message_OSC message_in) 
  {
    if (destination_address == grideye_ID) return;

    if (this.is_real && this.my_pis_node_port.get(destination_address) != null) {

      byte[] temp = new byte[serial_port_limit];
      boolean skip_sending = false;


      int index = 0;
      //Two bytes for start of message
      for (int i = 0; i < NUM_SOM; i++) {
        temp[index] = byte(SOM1);
        index++;
      }


      //Integer Node ID, 3 bytes
      for (int i = NUM_ID-1; i >= 0; i--) {
        temp[index] = byte((destination_address >> 8*i) & 0xFF);
        index++;
      }


      //============EDIT TO ADD NEW BEHAVIOUR MESSAGES================

      if (message_in.get_code().contains("FADE_ACTUATOR_GROUPS")) {

        int extra_pins = 0;
        //array length
        temp[index] = byte(message_in.get_data().length / 3 * 4); //calculation for fade_actuators length
 
        // check to see if this message is special - includes an extra byte for each DR for second pin.  If so, add to data length here and flag it.
        //  note - assumption is that if it has the _DR+ code, ALL DRs have 2 value bytes.
        if(message_in.get_code().contains("_DR+")) {
           extra_pins = Integer.parseInt(message_in.get_code().substring(message_in.get_code().indexOf("+") + 1, message_in.get_code().length()-19));   // parse the _DR+<n>     
           println ("found " + extra_pins + " extra DR pins and added them to node message");
           temp[index] = byte(int(temp[index]) + extra_pins);
        }
        index++;

        //send code, convert to a 1 byte value. Definitions mapped in the node

        // println(" sending F_A_G: " + message_in.get_code() + " | " + message_in.get_uncut_data());


        temp[index] = byte(CODE__FADE_ACTUATOR_GROUPS);
        if(message_in.get_code().contains("_DR+")) {
          temp[index] = byte(CODE__FADE_ACTUATOR_GROUPS_DR_X);
        }

        index++;

        //send data as bytes, format changes depending on message code
        for (int i = 0; i < message_in.get_data().length; i+=3) {
          //UID
          temp[index] = byte(device_locator.get_actuator_uid(message_in.get_data()[i].substring(0, 2), Integer.parseInt(message_in.get_data()[i].substring(2)), destination_address));
          index++;

          //VALUE
          temp[index] = byte(Integer.parseInt(message_in.get_data()[i+1]));
          index++;

          // VALUE 2, if applicable: if it is special and a DR, add an extra byte for the second pin value.
          //  note - assumption is that if it has the _DR+ code, ALL DRs have 2 value bytes.
          if (extra_pins > 0 && message_in.get_data()[i].substring(0, 2).equals("DR")) {
           // bump up i by one in the middle here, because we added an extra string to parse (ugly, but works?)
           i++;
           temp[index] = byte(Integer.parseInt(message_in.get_data()[i+1]));
           index++;
          }

          //TIME BYTE 1
          temp[index] = byte(Integer.parseInt(message_in.get_data()[i+2]) >> 8);  // BIGEndian ordering -- most significant byte first
          index++;

          //TIME BYTE 2
          temp[index] = byte(Integer.parseInt(message_in.get_data()[i+2]));
          index++;
        }
      } else if (message_in.get_code().contains("UPDATE_ACTUATOR_INFLUENCES")) {
          //DEBUGGING
          if(destination_address == 432840) {
       //     println(" P1 received " + message_in.get_code() + " | " + message_in.get_uncut_data());
          }

        //array length
        temp[index] = byte(message_in.get_data().length); //calculation for update_influences length (using 1 byte)
        index++;

        //send code, convert to a 1 byte value. Definitions mapped in the node

        temp[index] = byte(CODE__UPDATE_ACTUATOR_INFLUENCES);
        index++;

        //send data as bytes, format changes depending on message code

        //first send the influence type
        switch(message_in.get_data()[0]) {
          case("WV"):
          temp[index] = byte(CODE__INFLUENCE_TYPE_WV);
          break;
          case("RN"):
          temp[index] = byte(CODE__INFLUENCE_TYPE_RN);
          break;
          case("IR"):
          temp[index] = byte(CODE__INFLUENCE_TYPE_IR);
          break;
          case("SD"):
          temp[index] = byte(CODE__INFLUENCE_TYPE_SD);
          break;
          case("GE"):
          temp[index] = byte(CODE__INFLUENCE_TYPE_GE);
          break;
          case("EXP"):
          temp[index] = byte(CODE__INFLUENCE_TYPE_EXP);
          break;
          case("GR"):
          temp[index] = byte(CODE__INFLUENCE_TYPE_GR);
          break;
          case("RH"):
          temp[index] = byte(CODE__INFLUENCE_TYPE_RH);
          break;
          case("EC"):
          temp[index] = byte(CODE__INFLUENCE_TYPE_EC);
          break;
        }
        index++;

        // now send the influence values for each actuator
        for (int i = 1; i < message_in.get_data().length; i+=2) {
          //if(message_in.get_data()[i].substring(0,2).equals("MO")) {
          //  println("PI building WV influence message for MO" + message_in.get_data()[i].substring(2) + ": " + message_in.get_data()[i+1]);
          //}

          //UID
          temp[index] = byte(device_locator.get_actuator_uid(message_in.get_data()[i].substring(0, 2), Integer.parseInt(message_in.get_data()[i].substring(2)), destination_address));
          
          //DEBUGGING
          if(destination_address == 432840) {
        //    println(" adding UID " + byte(device_locator.get_actuator_uid(message_in.get_data()[i].substring(0, 2), Integer.parseInt(message_in.get_data()[i].substring(2)), destination_address)) + " to message");
          }
          index++;

          //VALUE
          temp[index] = byte(Integer.parseInt(message_in.get_data()[i+1]));
          index++;
        }
      }  else if (message_in.get_code().contains("INTENSITIES")) {   // deprecated - no longer being used
        //DO SOMETHING WITH CODE__SLAVE_MODE
        //Split the message into 2 FADE_ACTUATOR_GROUPS messages by recursively calling this function
        build_slave_message(source_address, destination_address, message_in);

        skip_sending = true; //ensures it doesn't send bytes this iteration
      } else if (message_in.get_code().contains("WAV_PLAY_SOUND")) {
        //array length
        temp[index] = byte(3); //calculation for fade_actuators length
        index++;

        //send code, convert to a 1 byte value. Definitions mapped in the node
        temp[index] = byte(CODE__WAV_PLAY_SOUND);
        index++;

        //UID
        temp[index] = byte(device_locator.get_actuator_uid(message_in.get_data()[0].substring(0, 2), Integer.parseInt(message_in.get_data()[0].substring(2)), destination_address));
        index++;

        //Track #
        temp[index] = byte(Integer.parseInt(message_in.get_data()[1]));
        index++;

        //Solo or Poly
        if (message_in.get_data()[2].equals("SOLO") || message_in.get_data()[2].equals("solo")) {
          temp[index] = byte(1);
        } else {
          temp[index] = byte(0); //switch to poly by default
        }
        index++;
      } else if (message_in.get_code().contains("WAV_MASTER_GAIN")) {
        //array length
        temp[index] = byte(2); //calculation for fade_actuators length
        index++;

        //send code, convert to a 1 byte value. Definitions mapped in the node
        temp[index] = byte(CODE__WAV_MASTER_GAIN);
        index++;

        //UID
        temp[index] = byte(device_locator.get_actuator_uid(message_in.get_data()[0].substring(0, 2), Integer.parseInt(message_in.get_data()[0].substring(2)), destination_address));
        index++;

        //Volume
        temp[index] = byte(Integer.parseInt(message_in.get_data()[1]));
        index++;
      } else if (message_in.get_code().contains("WAV_TRACK_GAIN")) {
        //array length
        temp[index] = byte(3); //calculation for fade_actuators length
        index++;

        //send code, convert to a 1 byte value. Definitions mapped in the node
        temp[index] = byte(CODE__WAV_TRACK_GAIN);
        index++;

        //UID
        temp[index] = byte(device_locator.get_actuator_uid(message_in.get_data()[0].substring(0, 2), Integer.parseInt(message_in.get_data()[0].substring(2)), destination_address));
        index++;

        //Track #
        temp[index] = byte(Integer.parseInt(message_in.get_data()[1]));
        index++;

        //Volume
        temp[index] = byte(Integer.parseInt(message_in.get_data()[2]));
        index++;
      } else if (message_in.get_code().contains("WAV_TRACK_FADE")) {
        //array length
        temp[index] = byte(6); //calculation for fade_actuators length
        index++;

        //send code, convert to a 1 byte value. Definitions mapped in the node
        temp[index] = byte(CODE__WAV_TRACK_FADE);
        index++;

        //UID
        temp[index] = byte(device_locator.get_actuator_uid(message_in.get_data()[0].substring(0, 2), Integer.parseInt(message_in.get_data()[0].substring(2)), destination_address));
        index++;

        //Track #
        temp[index] = byte(Integer.parseInt(message_in.get_data()[1]));
        index++;

        //Volume
        temp[index] = byte(Integer.parseInt(message_in.get_data()[2]));
        index++;

        //TIME BYTE 1
        temp[index] = byte(Integer.parseInt(message_in.get_data()[3]) >> 8);  // BIGEndian ordering -- most significant byte first
        index++;

        //TIME BYTE 2
        temp[index] = byte(Integer.parseInt(message_in.get_data()[3]));
        index++;

        //stop flag
        if (message_in.get_data()[4].equals("TRUE") || message_in.get_data()[4].equals("true")) {
          temp[index] = byte(1);
        } else {
          temp[index] = byte(0); //switch to false by default
        }
        index++;
      } else if (message_in.get_code().contains("SD_PT_SAMPLING_CONTROL")) {        
        //array length
        temp[index] = byte(1);
        index++;

        //send code, convert to a 1 byte value. Definitions mapped in the node
        temp[index] = byte(CODE__SD_PT_SAMPLING_CONTROL);
        index++;

        //UID
        temp[index] = byte(device_locator.get_actuator_uid(message_in.get_data()[0].substring(0, 2), Integer.parseInt(message_in.get_data()[0].substring(2)), destination_address));
        index++;
      } else if (message_in.get_code().contains("SD_PT_SAMPLING_RPI")) {        
        //array length
        temp[index] = byte(1);
        index++;

        //send code, convert to a 1 byte value. Definitions mapped in the node
        temp[index] = byte(CODE__SD_PT_SAMPLING_RPI);
        index++;

        //UID
        temp[index] = byte(device_locator.get_actuator_uid(message_in.get_data()[0].substring(0, 2), Integer.parseInt(message_in.get_data()[0].substring(2)), destination_address));
        index++;
      } else if (message_in.get_code().contains("SD_AUTO_SAMPLING")) {        
        //array length
        temp[index] = byte(2);
        index++;


        //send code, convert to a 1 byte value. Definitions mapped in the node
        temp[index] = byte(CODE__SD_AUTO_SAMPLING);
        index++;

        //UID
        temp[index] = byte(device_locator.get_actuator_uid(message_in.get_data()[0].substring(0, 2), Integer.parseInt(message_in.get_data()[0].substring(2)), destination_address));
        index++;

        //send data as bytes, format changes depending on message code
        //ON is 1, default to 0, OFF
        if (message_in.get_data()[1].equals("ON") || message_in.get_data()[1].equals("on")) {
          temp[index] = byte(1);
        } else {
          temp[index] = byte(0); //switch to off by default
        }
        index++;
      } else if (message_in.get_code().contains("SD_LIVE_OR_LOCAL")) {  
        //array length
        temp[index] = byte(2);
        index++;

        //send code, convert to a 1 byte value. Definitions mapped in the node
        temp[index] = byte(CODE__SD_LIVE_OR_LOCAL);
        index++;

        //UID
        temp[index] = byte(device_locator.get_actuator_uid(message_in.get_data()[0].substring(0, 2), Integer.parseInt(message_in.get_data()[0].substring(2)), destination_address));
        index++;

        //send data as bytes, format changes depending on message code
        //LOCAL is 1, default to 0, LIVE
        if (message_in.get_data()[1].equals("LOCAL") || message_in.get_data()[1].equals("local")) {
          temp[index] = byte(1);
        } else {
          temp[index] = byte(0); //switch to live by default
        }
        index++;
      } else if (message_in.get_code().contains("SD_SET_THRESHOLD")) {       
        //array length
        temp[index] = byte(3);
        index++;

        //send code, convert to a 1 byte value. Definitions mapped in the node
        temp[index] = byte(CODE__SD_SET_THRESHOLD);
        index++;

        //UID
        temp[index] = byte(device_locator.get_actuator_uid(message_in.get_data()[0].substring(0, 2), Integer.parseInt(message_in.get_data()[0].substring(2)), destination_address));
        index++;

        //send data as bytes, format changes depending on message code
        //0-1024 threshold value
        temp[index] = byte((int(message_in.get_data()[1]) >> 8)& 0xff); //MSB - Big Endian
        index++;
        temp[index] = byte(int(message_in.get_data()[1]) & 0xff); //LSB
        index++;
      } else if (message_in.get_code().contains("SD_SET_FREQUENCY")) {        
        //array length
        temp[index] = byte(3);
        index++;

        //send code, convert to a 1 byte value. Definitions mapped in the node
        temp[index] = byte(CODE__SD_SET_FREQUENCY);
        index++;

        //UID
        temp[index] = byte(device_locator.get_actuator_uid(message_in.get_data()[0].substring(0, 2), Integer.parseInt(message_in.get_data()[0].substring(2)), destination_address));
        index++;

        //send data as bytes, format changes depending on message code
        //2 byte Big Endian time value
        temp[index] = byte((int(message_in.get_data()[1]) >> 8) & 0xff);;
        index++;
        temp[index] = byte(int(message_in.get_data()[1]) & 0xff);
        index++;
      } else if (message_in.get_code().contains("IR_CONFIG")) {        
        //array length
        temp[index] = byte(4);  // most messages are 3, but thrshold takes 2 bytes.
        index++;

        //send code, convert to a 1 byte value. Definitions mapped in the node
        temp[index] = byte(CODE__IR_CONFIG);
        index++;

        //UID
        temp[index] = byte(device_locator.get_actuator_uid(message_in.get_data()[0].substring(0, 2), Integer.parseInt(message_in.get_data()[0].substring(2)), destination_address));
        index++;

            println(" Going to send IR " + message_in.get_data()[1] + " message: " + message_in.get_data()[2]);


        //send config string code, convert to a 1 byte value. 
        switch(message_in.get_data()[1]) {

          case "THRESHOLD":      // threshold is 2 bytes - 0-1024.
          temp[index]   = byte(CODE__IR_SET_THRESHOLD);
          index++;
          temp[index] = byte((int(message_in.get_data()[2]) >> 8)& 0xff); //MSB - Big Endian 
          index++;
          temp[index] = byte(int(message_in.get_data()[2]) & 0xff);       //LSB

            
          break;
          case "POLLING":
          temp[index] = byte(CODE__IR_AUTO_SAMPLING);
          index++;
          if (message_in.get_data()[2].equals("ON") || message_in.get_data()[2].equals("on")) {
            temp[index] = byte(1);
          } else {
            temp[index] = byte(0); //switch to off by default
          }
          index++;
          temp[index] = byte(0);  // pad with a zero

          break;
          case "FREQUENCY":
          temp[index] = byte(CODE__IR_SET_FREQUENCY);
          index++;
          temp[index] = byte(int(Integer.parseInt(message_in.get_data()[2])));
          index++;
          temp[index] = byte(0);  // pad with a zero

          break;
          case "USE_LOCAL":
          temp[index] = byte(CODE__IR_LIVE_OR_LOCAL);
           index++;
          if (message_in.get_data()[2].equals("LOCAL") || message_in.get_data()[2].equals("local")) {
            temp[index] = byte(1);
          } else {
            temp[index] = byte(0); //switch to live by default
          }
          index++;
          temp[index] = byte(0);  // pad with a zero

          break;
          default:
           println(" Unsure of what to set for IR, returning...");
          return;
           
          }

          index++;
  
      } else if(message_in.get_code().contains("DR_CONFIG")) {        
        //array length
        temp[index] = byte(4);  // max length of config (for offset, which uses a float)
        index++;

        //send code, convert to a 1 byte value. Definitions mapped in the node
        temp[index] = byte(CODE__DR_CONFIG);
        index++;

        //UID
        temp[index] = byte(device_locator.get_actuator_uid(message_in.get_data()[0].substring(0, 2), Integer.parseInt(message_in.get_data()[0].substring(2)), destination_address));
        index++;

        println(" Going to send " + destination_address + " DR " + message_in.get_data()[1] + " message: " + message_in.get_data()[2]);

        //send config string code, convert to a 1 byte value. 
        if(message_in.get_data()[1].contains("BOTTOMPIN")) {

          temp[index] = byte(CODE__DR_BOTTOM_PIN);
          index++;
          temp[index] = byte(int(message_in.get_data()[2]));
          index++;
          temp[index] = byte(0);  //  pad last byte


        } else if(message_in.get_data()[1].contains("INVERT")) {
          
          temp[index] = byte(CODE__DR_INVERT);
          index++;
                  // on or off?
          temp[index] = byte(message_in.get_data()[2].contains("TRUE") || message_in.get_data()[2].equals("true")); //if true, 1, else 0
          index++;

          temp[index] = byte(0);  //  pad last byte
          
        } else if(message_in.get_data()[1].contains("MODE")) {
          
          temp[index] = byte(CODE__DR_SET_MODE);
          index++;

          switch(message_in.get_data()[2]) {

          case "BOTH":
          temp[index] = byte(CODE__DR_MODE_BOTH);
            
          break;
          case "TIP_ONLY":
          temp[index] = byte(CODE__DR_MODE_TIP_ONLY);

          break;
          case "BULB_ONLY":
          temp[index] = byte(CODE__DR_MODE_BULB_ONLY);

          break;
          case "TIP_HALF_BULB":
          temp[index] = byte(CODE__DR_MODE_TIP_HALF_BULB);

          break;
          case "BULB_HALF_TIP":
          temp[index] = byte(CODE__DR_MODE_BULB_HALF_TIP);

          break;
          case "CHARGE_DISCHARGE":
          temp[index] = byte(CODE__DR_MODE_CHARGE_DISCHARGE);

          break;
          case "OSCILLATE":
          temp[index] = byte(CODE__DR_MODE_OSCILLATE);

          break;

          default:
          temp[index] = byte(CODE__DR_MODE_BOTH);

          }
          index++;
          temp[index] = byte(0);  //  pad last byte

      } else if(message_in.get_data()[1].equals("OFFSET")) { 

          temp[index] = byte(CODE__DR_OFFSET);  // offset is 2 bytes: milliseconds
          index++;
          temp[index] = byte(int(message_in.get_data()[2]) >> 8); //MSB - Big Endian 
          index++;
          temp[index] = byte(int(message_in.get_data()[2]));      //LSB

      }
      index++;
  
      } else if(message_in.get_code().contains("SD_CONFIG")) {        
        //array length
        temp[index] = byte(4);  // max length of config (for threshold, which uses a float)
        index++;

        //send code, convert to a 1 byte value. Definitions mapped in the node
        temp[index] = byte(CODE__SD_CONFIG);
        index++;

        //UID
        temp[index] = byte(device_locator.get_actuator_uid(message_in.get_data()[0].substring(0, 2), Integer.parseInt(message_in.get_data()[0].substring(2)), destination_address));
        index++;

        println(" Going to send SD " + message_in.get_data()[1] + " message: " + message_in.get_data()[2]);


        //send config string code, convert to a 1 byte value. 
        switch(message_in.get_data()[1]) {
          
          case "ENVELOPEPIN":

          temp[index] = byte(CODE__SD_ENVELOPE_PIN);
          index++;
          temp[index] = byte(int(message_in.get_data()[2]));
          index++;
          temp[index] = byte(0);  //  pad last byte

          break;

          case "INVERT":

          temp[index] = byte(CODE__SD_INVERT);
          index++;
          if (message_in.get_data()[2].equals("TRUE") || message_in.get_data()[2].equals("true")) {
            temp[index] = byte(1);
          } else {
            temp[index] = byte(0); // default to false
          }
          index++;
          temp[index] = byte(0);  //  pad last byte

          break;

          case "THRESHOLD":      // threshold is 2 bytes - 0-1024.
          temp[index]   = byte(CODE__SD_SET_THRESHOLD);
          index++;
          temp[index] = byte(int(message_in.get_data()[2]) >> 8); //MSB - Big Endian 
          index++;
          temp[index] = byte(int(message_in.get_data()[2]));      //LSB
            
          break;
          case "POLLING":
          temp[index] = byte(CODE__SD_AUTO_SAMPLING);
          index++;
          if (message_in.get_data()[2].equals("ON") || message_in.get_data()[2].equals("on")) {
            temp[index] = byte(1);
          } else {
            temp[index] = byte(0); //switch to off by default
          }
          index++;
          temp[index] = byte(0);  // pad with a zero

          break;
          case "FREQUENCY":
          temp[index] = byte(CODE__SD_SET_FREQUENCY);
          index++;
          temp[index] = byte(int(Integer.parseInt(message_in.get_data()[2])));
          index++;
          temp[index] = byte(0);  // pad with a zero

          break;
          case "USE_LOCAL":
          temp[index] = byte(CODE__SD_LIVE_OR_LOCAL);
           index++;
          if (message_in.get_data()[2].equals("LOCAL") || message_in.get_data()[2].equals("local")) {
            temp[index] = byte(1);
          } else {
            temp[index] = byte(0); //switch to live by default
          }
          index++;
          temp[index] = byte(0);  // pad with a zero

          break;

          default:
           println(" Unsure of what to set for SD, returning...");
          return;

        } 
      index++;
  
      } else if (message_in.get_code().contains("PING")) {
        //array length
        temp[index] = byte(1);
        index++;

        //send code, convert to a 1 byte value. Definitions mapped in the node
        temp[index] = byte(CODE__PING);
        index++;

        //Placeholder byte
        temp[index] = byte(0);
        index++;

      } else if (message_in.get_code().contains("LOST_CONTROL")) {
        //array length
        temp[index] = byte(1);
        index++;

        //send code, convert to a 1 byte value. Definitions mapped in the node
        temp[index] = byte(CODE__LOST_CONTROL);
        index++;

        //Placeholder byte
        temp[index] = byte(0);
        index++;

      } else if (message_in.get_code().contains("INFLUENCE_MAP")) {

        println("** PI setting " + message_in.get_data()[0] + " influence map for " + message_in.get_data()[1] + " to " + message_in.get_data()[2]);

        //array length
        temp[index] = byte(3);
        index++;

        //send code
        temp[index] = byte(CODE__INFLUENCE_MAP);
        index++;

        //send influence type
        switch(message_in.get_data()[0]) {
          case("WV"):
          temp[index] = byte(CODE__INFLUENCE_TYPE_WV);
          break;
          case("RN"):
          temp[index] = byte(CODE__INFLUENCE_TYPE_RN);
          break;
          case("IR"):
          temp[index] = byte(CODE__INFLUENCE_TYPE_IR);
          break;
          case("SD"):
          temp[index] = byte(CODE__INFLUENCE_TYPE_SD);
          break;
          case("GE"):
          temp[index] = byte(CODE__INFLUENCE_TYPE_GE);
          break;
          case("EXP"):
          temp[index] = byte(CODE__INFLUENCE_TYPE_EXP);
          break;
          case("GR"):
          temp[index] = byte(CODE__INFLUENCE_TYPE_GR);
          break;
          case("RH"):
          temp[index] = byte(CODE__INFLUENCE_TYPE_RH);
          break;
          case("EC"):
          temp[index] = byte(CODE__INFLUENCE_TYPE_EC);
          break;
        }
        index++;

        //actuator uid
        temp[index] = byte(device_locator.get_actuator_uid(message_in.get_data()[1].substring(0, 2), Integer.parseInt(message_in.get_data()[1].substring(2)), destination_address));
        index++;

        // on or off?
        temp[index] = byte(message_in.get_data()[2].equals("TRUE") || message_in.get_data()[2].equals("true")); //if true, 1, else 0
        index++;
     
      } 
      else if (message_in.get_code().contains("INFLUENCE_RANGE")) {

                println("** PI setting " + message_in.get_data()[0] + " influence range for " + message_in.get_data()[1] + " to " + message_in.get_data()[2] + "-" + message_in.get_data()[3]);

        //array length
        temp[index] = byte(6);
        index++;

        //send code
        temp[index] = byte(CODE__INFLUENCE_RANGE);
        index++;



        //send influence type
        switch(message_in.get_data()[0]) {
          case("WV"):
          temp[index] = byte(CODE__INFLUENCE_TYPE_WV);
          break;
          case("RN"):
          temp[index] = byte(CODE__INFLUENCE_TYPE_RN);
          break;
          case("IR"):
          temp[index] = byte(CODE__INFLUENCE_TYPE_IR);
          break;
          case("SD"):
          temp[index] = byte(CODE__INFLUENCE_TYPE_SD);
          break;
          case("GE"):
          temp[index] = byte(CODE__INFLUENCE_TYPE_GE);
          break;
          case("EXP"):
          temp[index] = byte(CODE__INFLUENCE_TYPE_EXP);
          break;
          case("GR"):
          temp[index] = byte(CODE__INFLUENCE_TYPE_GR);
          break;
          case("RH"):
          temp[index] = byte(CODE__INFLUENCE_TYPE_RH);
          break;
          case("EC"):
          temp[index] = byte(CODE__INFLUENCE_TYPE_EC);
          break;
        }
        index++;

        //actuator uid
        temp[index] = byte(device_locator.get_actuator_uid(message_in.get_data()[1].substring(0, 2), Integer.parseInt(message_in.get_data()[1].substring(2)), destination_address));
        index++;

        //lower bound
        // ByteBuffer bb1 = ByteBuffer.allocate(4);
        // bb1.order(ByteOrder.BIG_ENDIAN);
        // //byte[] b1 = bb1.putFloat(Float.parseFloat(message_in.get_data()[2])).array();
        // byte[] b1 = bb1.putFloat(Float.parseFloat(message_in.get_data()[2])).array();

        // print("Sending " + message_in.get_data()[2] + " as [");

        // for (int i = 0; i < b1.length; i++) {
        //   temp[index] = b1[i];
        //   print(b1[i] + " ");
        //   index++;
        // }
        // println("]");

        int float_as_int = int(Float.parseFloat(message_in.get_data()[2]) * 1000.);
        
          //lower_bound BYTE 1
          temp[index] = byte(float_as_int >> 8);  // BIGEndian ordering -- most significant byte first
          index++;

          //lower_bound BYTE 2
          temp[index] = byte(float_as_int);
          index++;


        //upper bound
        // ByteBuffer bb2 = ByteBuffer.allocate(4);
        // bb2.order(ByteOrder.BIG_ENDIAN);
        // byte[] b2 = bb2.putFloat(Float.parseFloat(message_in.get_data()[3])).array();

        // for (int i = 0; i < b2.length; i++) {
        //   temp[index] = b2[i];
        //   index++;
        // }

          float_as_int = int(Float.parseFloat(message_in.get_data()[3]) * 1000.);
        
          //upper_bound BYTE 1
          temp[index] = byte(float_as_int >> 8);  // BIGEndian ordering -- most significant byte first
          index++;

          //upper_bound BYTE 2
          temp[index] = byte(float_as_int);
          index++;
 
      } else if (message_in.get_code().contains("DELAY_MESSAGE")) {  // sending back a payload from node that was delayed
          //DEBUGGING
          // if(destination_address == 336641) {
          //   println("-> Pi received delayed message: " + message_in.get_code() + " | " + message_in.get_uncut_data());
          // }

        //array length
        temp[index] = byte(message_in.get_data().length); //data length will be as long as the stored payload was.
        index++;

        //send code, convert to a 1 byte value. Definitions mapped in the node
        temp[index] = byte(CODE__DELAY_MESSAGE);
        index++;

        // NOW SEND THE DATA THAT WAS DELAYED:
        for (int i = 0 ; i < message_in.get_data().length ; i++) {
          temp[index] = byte(unhex(message_in.get_data()[i]));   // inefficient?? is there a faster array copy?
          index++;
        }
      }
      //Create message to send on to Teensy:

      //Two bytes for end of message
      for (int i = 0; i < NUM_EOM; i++) {
        temp[index] = byte(EOM1);
        index++;
      }

      byte[] array_to_send = Arrays.copyOfRange(temp, 0, index);

      if (!skip_sending) {
        // send it to Teensy
        this.my_pis_node_port.get(destination_address).write(array_to_send);
      }
    } else if (!this.is_real && message_in.get_code().contains("INTENSITIES")) {
      //Called by control to send the slave messages

      build_slave_message(source_address, destination_address, message_in);
    }
    /*! THE BELOW ELSE STATEMENT IS TO BE COMMENTED OUT ON THE RPI COMMS_MANAGER */
    //else {
    //  RPi rpi_to_send_to = device_locator.find_nodes_parent_rpi(destination_address);

    //  if (rpi_to_send_to != null) {
    //    if (rpi_to_send_to.my_address.equals(source_address))      //I am the Pi sending a message to the node
    //      write_message(source_address, Integer.toString(destination_address), message_in);
    //    else   //I am a computer writing to the node, so send to its pi
    //    write_message(source_address, device_locator.find_nodes_parent_rpi(destination_address).my_address, message_in);
    //  }
    //}
  }

  /*! \fn get_message_real()
   *  \brief used to get a real message in the queue. If called on a real rpi, it reads serial ports. Helper function but gets called directly by control only. Skipping over grideye is commented out on the control level.
   *  \return a message_OSC
   */
  synchronized message_OSC get_message_real() {
    //Checks if I'm a Pi, then does serial reads
    if (this.is_real) {
      for (Map.Entry<Integer, Serial> entry : this.my_pis_node_port.entrySet()) {
        Integer id = entry.getKey();
        Serial current_port = entry.getValue();

        //  println("checking is this my grideye: " +  id + " vs. " + grideye_ID);
        // check if it's a GridEye - totally different message structure and read elsewhere (via serialEvent())
        if (id.equals(grideye_ID)) { //  && current_port.available() > 65) {
          if (debug) println(" skipping GridEye port");
          continue;
        }


        boolean message_found = true;
        int t1, t2, t3;
        int data_length = 0;
        int code = 0;
        byte[] data_in = new byte[0];

        if (current_port.available() > NUM_SOM + 4) {
          for (int s = 0; s < NUM_SOM; s++) {
            if (current_port.read() != SOM1)
              message_found = false;
          }

          t1 = current_port.read();
          t2 = current_port.read();
          t3 = current_port.read();

          data_length = current_port.read();
          code = current_port.read();
          data_in = new byte[data_length];

          // println("new message with length " + data_length + " and code " + code);
          // println("debug message code is " + CODE__DEBUG_MESSAGE);

          if (current_port.available() > data_length+1) {
            for (int i = 0; i < data_length; i++) {
              data_in[i] = byte(current_port.read());
            }

            for (int e = 0; e < NUM_EOM; e++) {
              if (current_port.read() != EOM1)
                message_found = false;
            }
          }
        }

        if (message_found) {
          //do some kind of behaviour and encode the bytes into an array as required using Niel's pin mapping

          // monitor.record_node_seen(str(id));
          
          
          if (code == CODE__PING) {

           //  println("PING back from node " + id );
             monitor.record_node_seen(str(id));

          }


          if (code == CODE__SD_PT_SAMPLING_CONTROL || code == CODE__SD_PT_SAMPLING_RPI) {
            //encode the bytes into the proper form
            String code_found = "SD_PT_SAMPLING_";
            if (code == CODE__SD_PT_SAMPLING_CONTROL)
              code_found += "CONTROL";
            else
              code_found += "RPI";


            String msg_code = "/NODE/" + code_found + "/" + id;

            int ub1 = int(data_in[0] << 8) & 0x03ff;
            int ub2 = int(data_in[1] & 0xff);

            String val = Integer.toString(ub1 | ub2);

            message_OSC m = new message_OSC(msg_code, val);
            
            this.real_received_message_queue.offer(m);

          } else if (code == CODE__IR_PT_SAMPLING_CONTROL || code == CODE__IR_PT_SAMPLING_RPI) {
            //encode the bytes into the proper form
            String code_found = "IR_PT_SAMPLING_";
            if (code == CODE__IR_PT_SAMPLING_CONTROL)
              code_found += "CONTROL";
            else
              code_found += "RPI";

            String msg_code = "/NODE/" + code_found + "/" + id;

            // gnarly stuff to strip off sign bits as we shift!  -mg Dec 2019
            int ub1 = int(data_in[0] << 8) & 0x03ff;
            int ub2 = int(data_in[1] & 0xff);

            String val = Integer.toString(ub1 | ub2);

            message_OSC m = new message_OSC(msg_code, val);

            // println(" ... IR value received, shifting it back, data was {" + hex(data_in[0])+ ", " + hex(data_in[1]) +"} check: " + 
            //         Integer.toString(ub1 | ub2) + " is " + binary(ub1 | ub2) );

            this.real_received_message_queue.offer(m);

          }
           else if(code == CODE__DELAY_MESSAGE) {
            // I'm a (virtual) pi that just received a message from the Node that I need to cache and send back.

            //String msg_code = "/NODE/DELAY_MESSAGE/"+ this.my_address + "/" + id;
            String msg_code = "/NODE/DELAY_MESSAGE/"+ id;

          //TIME BYTE 1 + TIME BYTE 2
            int ub1 = int(data_in[0] << 8) & 0x03ff;
            int ub2 = int(data_in[1] & 0xff);

            int d_time = (ub1 | ub2); // first byte is most significant (BIGEndian)
            byte[] stored_data = (byte[])subset(data_in, 2);

            String msg_data = hex(stored_data[0]);

            for (int i = 1; i < stored_data.length ; i++) {
              msg_data = (msg_data + " " + hex(stored_data[i]));
            }

            // println("Sending " + id + " a message delayed (by " + d_time + "ms) message of data length " + stored_data.length + " (as string/hex): " + msg_data);
            // println("Delay is " + d_time);

            message_OSC m = new message_OSC(msg_code, msg_data);
            m.delay(d_time);

            this.real_received_message_queue.offer(m);
            
          }

          if (code == CODE__DEBUG_MESSAGE) {

            print("Received debug message from " + id + ": [");
            for (int j = 0 ; j < 10 ; j++) {
              print(int(data_in[j]) + " ");
             // print(hex(data_in[j]) + " ");
            }
            println("]");

            String msg_code = "/NODE/DEBUG_MESSAGE/" + id;

            String debug_bytes = "";
            for (int i = 0; i < data_length; i++) {
               debug_bytes += (Integer.toString(data_in[i]) + " ");
            }

            message_OSC m = new message_OSC(msg_code, debug_bytes);
            this.real_received_message_queue.offer(m);

          }

        }
      }
    }


    if (this.real_received_message_queue.size() > 0) {
      try {
        message_OSC m = this.real_received_message_queue.peek();
        if(m.deliver_time > millis()) {
          return null;
        } else {
          return this.real_received_message_queue.poll();
        }
      }
      catch(Exception e) {
        System.out.println("Exception polling: " + e);
      }
    }

    return null;
  }


  /*! \fn get_message_virtual(String address)
   *  \brief used to get a virtual message in the queue. Helper function but gets called directly by control only.
   *  \param address the address of the virtual device to check
   *  \return a message_OSC
   */
   // SHOULD NEVER GET CALLED BY PHYSICAL PI
  synchronized message_OSC get_message_virtual(String address) {
    if (this.virtual_message_map.get(address).size() > 0) {
      try {
        message_OSC m = this.virtual_message_map.get(address).peek();
        if(m.deliver_time > millis()) {
          return null;
        } else {
          return this.virtual_message_map.get(address).poll();
        }
      }
      catch(Exception e) {
        System.out.println("Exception polling: " + e);
      }
    }


    return null;
  }

  /*! \fn get_message(String address)
   *  \brief only called by Pis or Nodes to get messages, if its real it will return a real message
   *  \param address the address of the device to check
   *  \return a message_OSC
   */
  synchronized message_OSC get_message(String address) {
    if (this.is_real)
      return get_message_real();

    return get_message_virtual(address);  // should never get called by physical pi
  }


  /*! \fn osc_received(OscMessage received_message)
   *  \brief helper function called by the osc listener in Control or RPi World.pde
   *  \param received_message the Osc message received
   *  \return none
   */
  synchronized void osc_received(OscMessage received_message) {

    message_OSC temp_message = new message_OSC(received_message);

    // add a delay if there's a delay code
    if(temp_message.get_code().split("/")[temp_message.get_code().split("/").length-1].charAt(0) == 'T') {
      temp_message.delay(Integer.parseInt(temp_message.get_code().split("/")[temp_message.get_code().split("/").length-1].substring(1)));
    }

    //store the message in the real receive queue
    this.real_received_message_queue.offer(temp_message);
  }




  /*! \fn displayInterfaceInformation(NetworkInterface netint)
   *  \brief helper function used for getting ip addresses
   *  \author Matt Gorbet
   *  \param netint Network Interface
   *  \exception SocketException
   *  \return none
   */
  void displayInterfaceInformation(NetworkInterface netint) throws SocketException {
    println("Display name: " + netint.getDisplayName());
    println("Name: " + netint.getName());
    Enumeration<InetAddress> inetAddresses = netint.getInetAddresses();
    for (InetAddress inetAddress : Collections.list(inetAddresses)) {
      println("InetAddress: " + inetAddress);
    }
    println("");
  }

  /*! \fn build_slave_message(String source_address, int destination_address, message_OSC message_in)
   *  \brief Helper function to build slave mode messages (INTENSITIES) [LEGACY, NOT IN USE]
   *  \param source_address the source of the message
   *  \param destination_address the destination address of the message
   *  \param message_in the osc message to send
   *  \return none
   */
  void build_slave_message(String source_address, int destination_address, message_OSC message_in) {
    //First message, moths
    String data_moths = "";
    for (int i = 0; i < message_in.get_data().length/2; i++) {
      data_moths += ("MO" + Integer.toString(i+1) + " ");
      data_moths += (message_in.get_data()[i] + " ");

      if (i == message_in.get_data().length/2 -1)
        data_moths += ("0"); // 0 time
      else
        data_moths += ("0 "); // 0 time
    }

    message_OSC moth_message = new message_OSC("/CONTROL/FADE_ACTUATOR_GROUPS/" + this.my_address + "/" + Integer.toString(destination_address), data_moths);

    this.write_message(source_address, destination_address, moth_message);

    //Second message, rebel stars
    String data_stars = "";
    for (int i = 0; i < message_in.get_data().length/2; i++) {
      data_stars += ("DR" + Integer.toString(i+1) + " ");
      data_stars += (message_in.get_data()[i+message_in.get_data().length/2] + " ");
      if (i == message_in.get_data().length/2 -1)
        data_stars += ("0"); // 0 time
      else
        data_stars += ("0 "); // 0 time
    }

    message_OSC star_message = new message_OSC("/CONTROL/FADE_ACTUATOR_GROUPS/" + this.my_address + "/" + Integer.toString(destination_address), data_stars);

    this.write_message(source_address, destination_address, star_message);
    
    //Third message, SMA
     String data_SMA = "";
    for (int i = 0; i < message_in.get_data().length/2; i++) {
      data_SMA += ("SM" + Integer.toString(i+1) + " ");
      data_SMA += (message_in.get_data()[i] + " ");

      if (i == message_in.get_data().length/2 -1)
        data_SMA += ("0"); // 0 time
      else
        data_SMA += ("0 "); // 0 time
    }

    message_OSC SMA_message = new message_OSC("/CONTROL/FADE_ACTUATOR_GROUPS/" + this.my_address + "/" + Integer.toString(destination_address), data_SMA);

    this.write_message(source_address, destination_address, SMA_message);
  }

  /*! \fn message_check(message_OSC message)
   *  \brief Helper function to check if messages are formatted correctly and have correct information
   *  Made according to specs in https://docs.google.com/document/d/1hsEqfDze0vfhwBPVnvVJtoajGdOOtPznUVdY9ZjVoDI/edit
   *  RPi comm manager version uses different rpi address checking commands than control
   *  \param message the osc message to send
   *  \return true if the message is OK, false if it isn't
   */
  boolean message_check(message_OSC message) {
    try {
      String[] contents = Arrays.copyOfRange(message.get_code().split("/"), 1, message.get_code().split("/").length);

      if (contents.length != 4) {
        print_msg_error("The Code is not formatted properly", message);
        return false;
      }

      String source = contents[0];
      String code = contents[1];
      String src_addr = contents[2];
      String dest_addr = contents[3];

      if (code.contains("FADE_ACTUATOR_GROUPS")) {

        //Code errors
        if (!source.equals("CONTROL") && !source.equals("RPI")) {
          print_msg_error("The source type does not match the code specification", message);
          return false;
        }

        if (source.equals("CONTROL") && !device_locator.is_control_ip(src_addr)) {
          print_msg_error("The control address in message does not exist", message);
          return false;
        }

        if (source.equals("RPI") && !(this.my_address.equals(src_addr))) {
          print_msg_error("The rpi address in message does not exist", message);
          return false;
        }

        if (!this.my_pis_node_port.containsKey(Integer.parseInt(dest_addr))) {
          print_msg_error("The node destination address in message does not exist", message);
          return false;
        }

        //Data errors         
        String[] act_names = device_locator.get_names(Integer.parseInt(dest_addr));
        Hashtable<String, String> searcher = new Hashtable<String, String>();

        for (int i = 0; i < act_names.length; i++) {
          //println(act_names[i].substring(act_names[i].length()-3));
          if (act_names[i].length() > 4)
            searcher.put(act_names[i].substring(act_names[i].indexOf('_')+1), dest_addr);
        }

        if (message.get_data().length == 0) {
          print_msg_error("The data cannot be empty", message);
          return false;
        }
        
        for (int i = 0; i < message.get_data().length; i+=3) {

          int extra_byte = 0;

          //is the actuator on the node

          if (!(message.get_data()[i].contains("MO") || message.get_data()[i].contains("PC") || message.get_data()[i].contains("SM") || message.get_data()[i].contains("RS") || message.get_data()[i].contains("DR"))) {
            print_msg_error("The actuator " + message.get_data()[i].substring(0, 2) + " is not recognized as a valid fadable actuator type", message);
            return false;
          } else if(message.get_code().contains("_DR+") && message.get_data()[i].contains("DR")) {
            extra_byte = 1;  // accommodate the extra byte for DRs using the 'special' _DR+ code.
          }

          if (!searcher.containsKey(message.get_data()[i])) {
            print_msg_error("The actuator " + message.get_data()[i] + " does not exist on node " + dest_addr, message);
            return false;
          }

          //are value(s) (1) in limit 
          while(extra_byte >= 0) {
          if (Integer.parseInt(message.get_data()[i+1]) < 0 || Integer.parseInt(message.get_data()[i+1]) > 255) {
            print_msg_error("The value " + message.get_data()[i+1] + " is not between 0-255", message);
            return false;
          }
           i+=extra_byte;                // jump i forward to accommodate extra byte
           extra_byte -= 1;
          }
      
          //is time correct
          if (Integer.parseInt(message.get_data()[i+2]) < 0) {
            print_msg_error("The time " + message.get_data()[i+2] + " is not above 0", message);
            return false;
          }
        }
      }   else if (code.equals("UPDATE_ACTUATOR_INFLUENCES")) {   
        //Code errors
        if (!source.equals("CONTROL") && !source.equals("RPI")) {
          print_msg_error("The source type does not match the code specification", message);
          return false;
        }

        if (source.equals("CONTROL") && !device_locator.is_control_ip(src_addr)) {
          print_msg_error("The control address in message does not exist", message);
          return false;
        }

        if (source.equals("RPI") && !(this.my_address.equals(src_addr))) {
          print_msg_error("The rpi address in message does not exist", message);
          return false;
        }

        if (!this.my_pis_node_port.containsKey(Integer.parseInt(dest_addr))) {
          print_msg_error("The node destination address in message does not exist", message);
          return false;
        }

        //Data errors         
        String[] act_names = device_locator.get_names(Integer.parseInt(dest_addr));
        Hashtable<String, String> searcher = new Hashtable<String, String>();

        for (int i = 0; i < act_names.length; i++) {
          //println(act_names[i].substring(act_names[i].length()-3));
          if (act_names[i].length() > 4) {
            searcher.put(act_names[i].substring(act_names[i].indexOf('_')+1), dest_addr);
          }
        }

        if (message.get_data().length == 0) {
          print_msg_error("The data cannot be empty", message);
          return false;
        }
 
        // is the influence type recognized?
          if (!message.get_data()[0].equals("GR") && 
              !message.get_data()[0].equals("WV") &&
              !message.get_data()[0].equals("RN") &&
              !message.get_data()[0].equals("IR") && 
              !message.get_data()[0].equals("SD") && 
              !message.get_data()[0].equals("GE") && 
              !message.get_data()[0].equals("EXP") && 
              !message.get_data()[0].equals("GR") && 
              !message.get_data()[0].equals("RH") && 
              !message.get_data()[0].equals("EC") ) {
             print_msg_error("The value " + message.get_data()[0] + " is not recognized as a valid influence type", message);
            return false;
          }

        for (int i = 1; i < message.get_data().length; i+=2) {  // SKIP THE VERY FIRST MESSAGE DATA CODE which was the influence type.

          //is the actuator on the node

          if (!(message.get_data()[i].contains("MO") || message.get_data()[i].contains("PC") || message.get_data()[i].contains("SM") || message.get_data()[i].contains("RS") || message.get_data()[i].contains("DR"))) {
            print_msg_error("The actuator " + message.get_data()[i].substring(0, 2) + " is not recognized as a valid influencable actuator type", message);
            return false;
          }

          if (!searcher.containsKey(message.get_data()[i])) {
            print_msg_error("The actuator " + message.get_data()[i] + " does not exist on node " + dest_addr, message);
            return false;
          }

          //are value(s) (1) in limit 
          if (Integer.parseInt(message.get_data()[i+1]) < 0 || Integer.parseInt(message.get_data()[i+1]) > 255) {
            print_msg_error("The value " + message.get_data()[i+1] + " is not between 0-255", message);
            return false;
          }  
        }
      } else if (code.contains("DR_CONFIG")) {

        //Code errors
        if (!source.equals("CONTROL") && !source.equals("RPI")) {
          print_msg_error("The source type does not match the code specification", message);
          return false;
        }

        if (source.equals("CONTROL") && !device_locator.is_control_ip(src_addr)) {
          print_msg_error("The control address in message does not exist", message);
          return false;
        }

        if (source.equals("RPI") && !(this.my_address.equals(src_addr))) {
          print_msg_error("The rpi address in message does not exist", message);
          return false;
        }

        if (!this.my_pis_node_port.containsKey(Integer.parseInt(dest_addr))) {
          print_msg_error("The node destination address in message does not exist", message);
          return false;
        }


        //Data errors         
        String[] act_names = device_locator.get_names(Integer.parseInt(dest_addr));
        Hashtable<String, String> searcher = new Hashtable<String, String>();

        for (int i = 0; i < act_names.length; i++) {
          //println(act_names[i].substring(act_names[i].length()-3));
          if (act_names[i].length() > 4)
            searcher.put(act_names[i].substring(act_names[i].indexOf('_')+1), dest_addr);
        }


        //is the actuator on the node

        if (!(message.get_data()[0].contains("DR"))) {
          print_msg_error("The actuator " + message.get_data()[0].substring(0, 2) + " is not a DR.", message);
          return false;
        }

        if (!searcher.containsKey(message.get_data()[0])) {
          print_msg_error("The actuator " + message.get_data()[0] + " does not exist on node " + dest_addr, message);
          return false;
        }

        if (message.get_data()[1].equals("MODE")) {
          //is value a recognized mode?
          if (  !message.get_data()[2].equals("BOTH") && 
                !message.get_data()[2].equals("TIP_ONLY") && 
                !message.get_data()[2].equals("BULB_ONLY") && 
                !message.get_data()[2].equals("TIP_HALF_BULB") && 
                !message.get_data()[2].equals("BULB_HALF_TIP") && 
                !message.get_data()[2].equals("CHARGE_DISCHARGE") && 
                !message.get_data()[2].equals("OSCILLATE") ) {
              print_msg_error("The value " + message.get_data()[2] + " is not recognized as a mode for DRs", message);
              return false;
            }
        } else if(message.get_data()[1].equals("BOTTOMPIN")) {

          //is value a recognized pin?
          // let's just assume it is, for now.... 

        } else if(message.get_data()[1].equals("INVERT")) {

          if (!message.get_data()[2].equals("TRUE") && !message.get_data()[2].equals("true") && !message.get_data()[2].equals("FALSE") && !message.get_data()[2].equals("false")) {
            print_msg_error("Needs to be TRUE or FALSE, field is invalid", message);
            return false;
          }

        } else if(message.get_data()[1].equals("OFFSET")) {

          if (Integer.parseInt(message.get_data()[2]) < 0) {
            print_msg_error("The offset needs to be positive (use INVERT) first to go negative.", message);
            return false;
          }

        }
      } else if (code.equals("INTENSITIES")) {

        //Code errors
        if (!source.equals("CONTROL")) {
          print_msg_error("The source type does not match the code specification", message);
          return false;
        }

        if (source.equals("CONTROL") && !device_locator.is_control_ip(src_addr)) {
          print_msg_error("The control address in message does not exist", message);
          return false;
        }

        if (!this.my_pis_node_port.containsKey(Integer.parseInt(dest_addr))) {
          print_msg_error("The node destination address in message does not exist", message);
          return false;
        }

        //Data errors
        if (message.get_data().length > 28) {
          print_msg_error("The length of the data is too long, 28 numbers is maximum", message);
          return false;
        }

        for (int i = 0; i < message.get_data().length; i++) {
          //is value in limit
          if (Integer.parseInt(message.get_data()[i]) < 0 || Integer.parseInt(message.get_data()[i]) > 255) {
            print_msg_error("The value " + message.get_data()[i] + " is not between 0-255", message);
            return false;
          }
        }
      } else if (code.equals("WAV_PLAY_SOUND")) {

        //Code errors
        if (!source.equals("CONTROL") && !source.equals("RPI")) {
          print_msg_error("The source type does not match the code specification", message);
          return false;
        }

        if (source.equals("CONTROL") && !device_locator.is_control_ip(src_addr)) {
          print_msg_error("The control address in message does not exist", message);
          return false;
        }

        if (source.equals("RPI") && !(this.my_address.equals(src_addr))) {
          print_msg_error("The rpi address in message does not exist", message);
          return false;
        }

        if (!this.my_pis_node_port.containsKey(Integer.parseInt(dest_addr))) {
          print_msg_error("The node destination address in message does not exist", message);
          return false;
        }

        //Data errors
        if (!message.get_data()[0].contains("WT")) {
          print_msg_error("The data field " + message.get_data()[0] + " is not a valid wav trigger identifier", message);
          return false;
        }

        boolean found = false;
        String[] act_names = device_locator.get_names(Integer.parseInt(dest_addr));
        for (int i = 0; i < act_names.length; i++) {
          if (act_names[i].length() > 4 && act_names[i].substring(act_names[i].indexOf('_')+1).equals(message.get_data()[0])) {
            found = true;
          }
        }

        if (!found) {
          print_msg_error("The wav trigger " + message.get_data()[0] + " does not exist on node " + dest_addr, message);
          return false;
        }

        if (Integer.parseInt(message.get_data()[1]) < 0) {
          print_msg_error("Track value is below 0", message);
          return false;
        }

        if (!(message.get_data()[2].equals("SOLO") || message.get_data()[2].equals("solo") || message.get_data()[2].equals("POLY") || message.get_data()[2].equals("poly"))) {
          print_msg_error("The track type must be SOLO or POLY", message);
          return false;
        }
      } else if (code.equals("WAV_MASTER_GAIN")) {

        //Code errors
        if (!source.equals("CONTROL") && !source.equals("RPI")) {
          print_msg_error("The source type does not match the code specification", message);
          return false;
        }

        if (source.equals("CONTROL") && !device_locator.is_control_ip(src_addr)) {
          print_msg_error("The control address in message does not exist", message);
          return false;
        }

        if (source.equals("RPI") && !(this.my_address.equals(src_addr))) {
          print_msg_error("The rpi address in message does not exist", message);
          return false;
        }

        if (!this.my_pis_node_port.containsKey(Integer.parseInt(dest_addr))) {
          print_msg_error("The node destination address in message does not exist", message);
          return false;
        }

        //Data errors
        if (!message.get_data()[0].contains("WT")) {
          print_msg_error("The data field " + message.get_data()[0] + " is not a valid wav trigger identifier", message);
          return false;
        }

        boolean found = false;
        String[] act_names = device_locator.get_names(Integer.parseInt(dest_addr));
        for (int i = 0; i < act_names.length; i++) {
          if (act_names[i].length() > 4 && act_names[i].substring(act_names[i].indexOf('_')+1).equals(message.get_data()[0])) {
            found = true;
          }
        }

        if (!found) {
          print_msg_error("The wav trigger " + message.get_data()[0] + " does not exist on node " + dest_addr, message);
          return false;
        }

        if (Integer.parseInt(message.get_data()[1]) < 0 || Integer.parseInt(message.get_data()[1]) > 80) {
          print_msg_error("The gain is out of the 0-80 limit", message);
          return false;
        }
      } else if (code.equals("WAV_TRACK_GAIN")) {

        //Code errors
        if (!source.equals("CONTROL") && !source.equals("RPI")) {
          print_msg_error("The source type does not match the code specification", message);
          return false;
        }

        if (source.equals("CONTROL") && !device_locator.is_control_ip(src_addr)) {
          print_msg_error("The control address in message does not exist", message);
          return false;
        }

        if (source.equals("RPI") && !(this.my_address.equals(src_addr))) {
          print_msg_error("The rpi address in message does not exist", message);
          return false;
        }

        if (!this.my_pis_node_port.containsKey(Integer.parseInt(dest_addr))) {
          print_msg_error("The node destination address in message does not exist", message);
          return false;
        }

        //Data errors
        if (!message.get_data()[0].contains("WT")) {
          print_msg_error("The data field " + message.get_data()[0] + " is not a valid wav trigger identifier", message);
          return false;
        }

        boolean found = false;
        String[] act_names = device_locator.get_names(Integer.parseInt(dest_addr));
        for (int i = 0; i < act_names.length; i++) {
          if (act_names[i].length() > 4 && act_names[i].substring(act_names[i].indexOf('_')+1).equals(message.get_data()[0])) {
            found = true;
          }
        }

        if (!found) {
          print_msg_error("The wav trigger " + message.get_data()[0] + " does not exist on node " + dest_addr, message);
          return false;
        }

        if (Integer.parseInt(message.get_data()[1]) < 0) {
          print_msg_error("Track value is below 0", message);
          return false;
        }

        if (Integer.parseInt(message.get_data()[2]) < 0 || Integer.parseInt(message.get_data()[2]) > 80) {
          print_msg_error("The gain is out of the 0-80 limit", message);
          return false;
        }
      } else if (code.equals("WAV_TRACK_FADE")) {

        //Code errors
        if (!source.equals("CONTROL") && !source.equals("RPI")) {
          print_msg_error("The source type does not match the code specification", message);
          return false;
        }

        if (source.equals("CONTROL") && !device_locator.is_control_ip(src_addr)) {
          print_msg_error("The control address in message does not exist", message);
          return false;
        }

        if (source.equals("RPI") && !(this.my_address.equals(src_addr))) {
          print_msg_error("The rpi address in message does not exist", message);
          return false;
        }

        if (!this.my_pis_node_port.containsKey(Integer.parseInt(dest_addr))) {
          print_msg_error("The node destination address in message does not exist", message);
          return false;
        }

        //Data errors
        if (!message.get_data()[0].contains("WT")) {
          print_msg_error("The data field " + message.get_data()[0] + " is not a valid wav trigger identifier", message);
          return false;
        }

        boolean found = false;
        String[] act_names = device_locator.get_names(Integer.parseInt(dest_addr));
        for (int i = 0; i < act_names.length; i++) {
          if (act_names[i].length() > 4 && act_names[i].substring(act_names[i].indexOf('_')+1).equals(message.get_data()[0])) {
            found = true;
          }
        }

        if (!found) {
          print_msg_error("The wav trigger " + message.get_data()[0] + " does not exist on node " + dest_addr, message);
          return false;
        }

        if (Integer.parseInt(message.get_data()[1]) < 0) {
          print_msg_error("Track value is below 0", message);
          return false;
        }

        if (Integer.parseInt(message.get_data()[2]) < 0 || Integer.parseInt(message.get_data()[2]) > 80) {
          print_msg_error("The gain is out of the 0-80 limit", message);
          return false;
        }

        if (Integer.parseInt(message.get_data()[3]) < 0) {
          print_msg_error("The time is below 0", message);
          return false;
        }

        if (!message.get_data()[4].equals("TRUE") && !message.get_data()[4].equals("true") && !message.get_data()[4].equals("FALSE") && !message.get_data()[4].equals("false")) {
          print_msg_error("Needs to be TRUE or FALSE, field is invalid", message);
          return false;
        }
      } else if (code.equals("SD_PT_SAMPLING_CONTROL") || code.equals("IR_PT_SAMPLING_CONTROL")) {

        //Code errors
        if (!source.equals("CONTROL") && !source.equals("NODE")) {
          print_msg_error("The source type does not match the code specification", message);
          return false;
        }

        if (source.equals("CONTROL") && !device_locator.is_control_ip(src_addr)) {
          print_msg_error("The source control address in message does not exist", message);
          return false;
        }

        if (source.equals("NODE") && !this.my_pis_node_port.containsKey(Integer.parseInt(src_addr))) {
          print_msg_error("The source node address in message does not exist", message);
          return false;
        }

        if (source.equals("CONTROL") && !this.my_pis_node_port.containsKey(Integer.parseInt(dest_addr))) {
          print_msg_error("The destination node address in message does not exist", message);
          return false; 
        }

        if (source.equals("NODE") && !device_locator.is_control_ip(dest_addr)) {
          print_msg_error("The destination control address in message does not exist", message);
          return false;
        }

        //Data errors
        if (source.equals("CONTROL")) {
          if (!message.get_data()[0].contains("SD") && !message.get_data()[0].contains("IR")) {
            print_msg_error("The data field does not include a valid sound detector or IR sensor", message);
            return false;
          }

          String[] act_names = device_locator.get_names(Integer.parseInt(dest_addr));

          boolean found = false;
          for (int i = 0; i < act_names.length; i++) {
            if (act_names[i].length() > 4 && act_names[i].substring(act_names[i].indexOf('_')+1).equals(message.get_data()[0])) {
              found = true;
            }
          }

          if (!found) {
            print_msg_error("The sensor (IR or SD) " + message.get_data()[0] + " does not exist on node " + dest_addr, message);
            return false;
          }
        }

        if (source.equals("NODE")) {
          if (Integer.parseInt(message.get_data()[0]) < 0) {
            print_msg_error("The data coming back from the sound detector or IR sensor is invalid, check connection", message);
          }
        }
      } else if (code.equals("SD_PT_SAMPLING_RPI") || code.equals("IR_PT_SAMPLING_RPI") ) {

        //Code errors
        if (!source.equals("RPI") && !source.equals("NODE")) {
          print_msg_error("The source type does not match the code specification", message);
          return false;
        }

        if (source.equals("RPI") && !(this.my_address.equals(src_addr))) {
          print_msg_error("The source rpi address in message does not exist", message);
          return false;
        }

        if (source.equals("NODE") && !this.my_pis_node_port.containsKey(Integer.parseInt(src_addr))) {
          print_msg_error("The source node address in message does not exist", message);
          return false;
        }

        if (source.equals("RPI") && !this.my_pis_node_port.containsKey(Integer.parseInt(dest_addr))) {
          print_msg_error("The destination node address in message does not exist (was not found at startup)", message);
          return false;
        }

        if (source.equals("NODE") && !(this.my_address.equals(src_addr))) {
          print_msg_error("The destination rpi address in message does not exist", message);
          return false;
        }

        //Data errors
        if (source.equals("RPI")) {
          if (!message.get_data()[0].contains("SD") && !message.get_data()[0].contains("IR")) {
            print_msg_error("The data field does not include a valid sound detector or IR sensor", message);
            return false;
          }

          String[] act_names = device_locator.get_names(Integer.parseInt(dest_addr));

          boolean found = false;
          for (int i = 0; i < act_names.length; i++) {
            if (act_names[i].length() > 4 && act_names[i].substring(act_names[i].indexOf('_')+1).equals(message.get_data()[0])) {
              found = true;
            }
          }

          if (!found) {
            print_msg_error("The sensor (IR or SD) " + message.get_data()[0] + " does not exist on node " + dest_addr, message);
            return false;
          }
        }

        if (source.equals("NODE")) {
          if (Integer.parseInt(message.get_data()[0]) < 0) {
            print_msg_error("The data coming back from the sound detector is invalid, check connection", message);
          }
        }
      } 
      /* else if (code.equals("SD_AUTO_SAMPLING")) {

        //Code errors
        if (!source.equals("CONTROL") && !source.equals("RPI")) {
          print_msg_error("The source type does not match the code specification", message);
          return false;
        }

        if (source.equals("CONTROL") && !device_locator.is_control_ip(src_addr)) {
          print_msg_error("The control address in message does not exist", message);
          return false;
        }

        if (source.equals("RPI") && !(this.my_address.equals(src_addr))) {
          print_msg_error("The rpi address in message does not exist", message);
          return false;
        }

        if (!this.my_pis_node_port.containsKey(Integer.parseInt(dest_addr))) {
          print_msg_error("The node destination address in message does not exist", message);
          return false;
        }

        //Data errors
        if (!message.get_data()[0].contains("SD")) {
          print_msg_error("The data field does not include a valid sound detector", message);
          return false;
        }

        String[] act_names = device_locator.get_names(Integer.parseInt(dest_addr));

        boolean found = false;
        for (int i = 0; i < act_names.length; i++) {
          if (act_names[i].length() > 4 && act_names[i].substring(act_names[i].indexOf('_')+1).equals(message.get_data()[0])) {
            found = true;
          }
        }

        if (!found) {
          print_msg_error("The sound detector " + message.get_data()[0] + " does not exist on node " + dest_addr, message);
          return false;
        }

        if (!message.get_data()[1].equals("ON") && !message.get_data()[1].equals("on") && !message.get_data()[1].equals("OFF") && !message.get_data()[1].equals("off")) {
          print_msg_error("Should be ON or OFF", message);
          return false;
        }
      } else if (code.equals("SD_LIVE_OR_LOCAL")) {

        //Code errors
        if (!source.equals("CONTROL") && !source.equals("RPI")) {
          print_msg_error("The source type does not match the code specification", message);
          return false;
        }

        if (source.equals("CONTROL") && !device_locator.is_control_ip(src_addr)) {
          print_msg_error("The control address in message does not exist", message);
          return false;
        }

        if (source.equals("RPI") && !(device_locator.rpis.containsKey(src_addr))) {
          print_msg_error("The rpi address in message does not exist", message);
          return false;
        }
        
        if (!this.my_pis_node_port.containsKey(Integer.parseInt(dest_addr))) {
          print_msg_error("The node destination address in message does not exist", message);
          return false;
        }

        //Data errors
        if (!message.get_data()[0].contains("SD")) {
          print_msg_error("The data field does not include a valid sound detector", message);
          return false;
        }

        String[] act_names = device_locator.get_names(Integer.parseInt(dest_addr));

        boolean found = false;
        for (int i = 0; i < act_names.length; i++) {
          if (act_names[i].length() > 4 && act_names[i].substring(act_names[i].indexOf('_')+1).equals(message.get_data()[0])) {
            found = true;
          }
        }

        if (!found) {
          print_msg_error("The sound detector " + message.get_data()[0] + " does not exist on node " + dest_addr, message);
          return false;
        }

        if (!message.get_data()[1].equals("LIVE") && !message.get_data()[1].equals("live") && !message.get_data()[1].equals("LOCAL") && !message.get_data()[1].equals("local")) {
          print_msg_error("Should be LIVE or LOCAL", message);
          return false;
        }
      } else if (code.equals("SD_SET_THRESHOLD")) {


        //Code errors
        if (!source.equals("CONTROL") && !source.equals("RPI")) {
          print_msg_error("The source type does not match the code specification", message);
          return false;
        }

        if (source.equals("CONTROL") && !device_locator.is_control_ip(src_addr)) {
          print_msg_error("The control address in message does not exist", message);
          return false;
        }

        if (source.equals("RPI") && !(this.my_address.equals(src_addr))) {
          print_msg_error("The rpi address in message does not exist", message);
          return false;
        }

        if (!this.my_pis_node_port.containsKey(Integer.parseInt(dest_addr))) {
          print_msg_error("The node destination address in message does not exist", message);
          return false;
        }

        //Data errors
        if (!message.get_data()[0].contains("SD")) {
          print_msg_error("The data field does not include a valid sound detector", message);
          return false;
        }

        String[] act_names = device_locator.get_names(Integer.parseInt(dest_addr));

        boolean found = false;
        for (int i = 0; i < act_names.length; i++) {
          if (act_names[i].length() > 4 && act_names[i].substring(act_names[i].indexOf('_')+1).equals(message.get_data()[0])) {
            found = true;
          }
        }

        if (!found) {
          print_msg_error("The sound detector " + message.get_data()[0] + " does not exist on node " + dest_addr, message);
          return false;
        }

        if (Integer.parseInt(message.get_data()[1]) < 0) {
          print_msg_error("The treshold has to be above 0", message);
          return false;
        }
      } else if (code.equals("SD_SET_FREQUENCY")) {

        //Code errors
        if (!source.equals("CONTROL") && !source.equals("RPI")) {
          print_msg_error("The source type does not match the code specification", message);
          return false;
        }

        if (source.equals("CONTROL") && !device_locator.is_control_ip(src_addr)) {
          print_msg_error("The control address in message does not exist", message);
          return false;
        }

        if (source.equals("RPI") && !(this.my_address.equals(src_addr))) {
          print_msg_error("The rpi address in message does not exist", message);
          return false;
        }

        if (!this.my_pis_node_port.containsKey(Integer.parseInt(dest_addr))) {
          print_msg_error("The node destination address in message does not exist", message);
          return false;
        }

        //Data errors
        if (!message.get_data()[0].contains("SD")) {
          print_msg_error("The data field does not include a valid sound detector", message);
          return false;
        }

        String[] act_names = device_locator.get_names(Integer.parseInt(dest_addr));

        boolean found = false;
        for (int i = 0; i < act_names.length; i++) {
          if (act_names[i].length() > 4 && act_names[i].substring(act_names[i].indexOf('_')+1).equals(message.get_data()[0])) {
            found = true;
          }
        }

        if (!found) {
          print_msg_error("The sound detector " + message.get_data()[0] + " does not exist on node " + dest_addr, message);
          return false;
        }

        if (Integer.parseInt(message.get_data()[1]) < 0) {
          print_msg_error("The frequency has to be above 0", message);
          return false;
        }
      } 
      */
      else if (code.equals("PING")) {

        if (!source.equals("CONTROL") && !source.equals("RPI") && !source.equals("NODE")) {
          print_msg_error("The source type does not match the code specification", message);
          return false;
        }

        if (source.equals("RPI") && !(this.my_address.equals(src_addr))) {
          print_msg_error("The source rpi address in message does not exist", message);
          return false;
        }

        if (source.equals("CONTROL") && !device_locator.is_control_ip(src_addr)) {
          print_msg_error("The source control address in message does not exist", message);
          return false;
        }

        if (source.equals("NODE") && !this.my_pis_node_port.containsKey(Integer.parseInt(src_addr))) {
          print_msg_error("The source node address in message does not exist", message);
          return false;
        }

        if (source.equals("NODE") && !(device_locator.rpis.containsKey(dest_addr))) {
          print_msg_error("The destination rpi address in message does not exist", message);
          return false;
        }

        if (source.equals("RPI") && dest_addr.contains(".") && !device_locator.is_control_ip(dest_addr)) {
          print_msg_error("The destination control address in message does not exist", message);
          return false;
        }

        if (source.equals("RPI") && !dest_addr.contains(".") && !dl.get_node_parent_pi( Integer.parseInt(dest_addr) ).equals(my_address) ) {
          print_msg_error("The destination node address in message does not match a child of this pi", message);
          return false;
        }

        if (source.equals("CONTROL") && !(device_locator.rpis.containsKey(dest_addr))) {
          print_msg_error("The destination rpi address in message does not exist", message);
          return false;
        }
      } else if (code.equals("LOST_CONTROL")) {
        if (!dl.get_node_parent_pi( Integer.parseInt(dest_addr) ).equals(my_address)) {
          print_msg_error("The node id in message is not the child of this pi", message);
          return false;
        }
      } else if (code.equals("NODE_LOST") || code.equals("NODE_FOUND")) {
        if (!dl.get_node_parent_pi( Integer.parseInt(message.get_data()[0]) ).equals(my_address)) {
          print_msg_error("The node id in message is not the child of this pi", message);
          return false;
        }
      } else if (code.equals("INFLUENCE_MAP")) {

        //Code errors
        if (!source.equals("CONTROL") && !source.equals("RPI")) {
          print_msg_error("The source type does not match the code specification", message);
          return false;
        }

        if (source.equals("CONTROL") && !device_locator.is_control_ip(src_addr)) {
          print_msg_error("The control address in message does not exist", message);
          return false;
        }

        if (source.equals("RPI") && !(this.my_address.equals(src_addr))) {
          print_msg_error("The rpi address in message does not exist", message);
          return false;
        }

        //Data Errors


        // is the influence type recognized?
          if (!message.get_data()[0].equals("GR") && 
              !message.get_data()[0].equals("WV") &&
              !message.get_data()[0].equals("RN") &&
              !message.get_data()[0].equals("IR") && 
              !message.get_data()[0].equals("SD") && 
              !message.get_data()[0].equals("GE") && 
              !message.get_data()[0].equals("EXP") && 
              !message.get_data()[0].equals("GR") && 
              !message.get_data()[0].equals("RH") && 
              !message.get_data()[0].equals("EC") ) {
             print_msg_error("The value " + message.get_data()[0] + " is not recognized as a valid influence type", message);
            return false;
          }


        if (!(message.get_data()[1].contains("MO") || message.get_data()[1].contains("PC") || message.get_data()[1].contains("RS") || message.get_data()[1].contains("SM") || message.get_data()[1].contains("PC") ||message.get_data()[1].contains("DR") )) {
          print_msg_error("The actuator " + message.get_data()[1].substring(0, 2) + " is not recognized as a valid actuator type", message);
          return false;
        }

        boolean found = false;
        String[] act_names = device_locator.get_names(Integer.parseInt(dest_addr));
        for (int i = 0; i < act_names.length; i++) {
          if (act_names[i].length() > 4 && act_names[i].substring(act_names[i].indexOf('_')+1).equals(message.get_data()[1])) {
            found = true;
          }
        }

        if (!found) {
          print_msg_error("The actuator " + message.get_data()[1] + " does not exist on node " + dest_addr, message);
          return false;
        }


          if (!message.get_data()[2].equals("FALSE") && !message.get_data()[2].equals("false") && !message.get_data()[2].equals("TRUE") && !message.get_data()[2].equals("true")) {
            print_msg_error("The data must be FALSE, false, TRUE or true, incorrect data", message);
            return false;
          }
        
      } else if (code.equals("INFLUENCE_RANGE") ) {

        //Code errors
        if (!source.equals("CONTROL") && !source.equals("RPI")) {
          print_msg_error("The source type does not match the code specification", message);
          return false;
        }

        if (source.equals("CONTROL") && !device_locator.is_control_ip(src_addr)) {
          print_msg_error("The control address in message does not exist", message);
          return false;
        }

        if (source.equals("RPI") && !(this.my_address.equals(src_addr))) {
          print_msg_error("The rpi address in message does not exist", message);
          return false;
        }


        //Data Errors

        // is the influence type recognized?
          if (!message.get_data()[0].equals("GR") && 
              !message.get_data()[0].equals("WV") &&
              !message.get_data()[0].equals("RN") &&
              !message.get_data()[0].equals("IR") && 
              !message.get_data()[0].equals("SD") &&  
              !message.get_data()[0].equals("GE") && 
              !message.get_data()[0].equals("EXP") && 
              !message.get_data()[0].equals("GR") && 
              !message.get_data()[0].equals("RH") && 
              !message.get_data()[0].equals("EC") ) {
             print_msg_error("The value " + message.get_data()[0] + " is not recognized as a valid influence type", message);
            return false;
          }

        if (!(message.get_data()[1].contains("MO") || message.get_data()[1].contains("PC") || message.get_data()[1].contains("RS") || message.get_data()[1].contains("SM") || message.get_data()[1].contains("PC") || message.get_data()[1].contains("DR") )) {
          print_msg_error("The actuator " + message.get_data()[1].substring(0, 2) + " is not recognized as a valid actuator type", message);
          return false;
        }

        boolean found = false;
        String[] act_names = device_locator.get_names(Integer.parseInt(dest_addr));
        for (int i = 0; i < act_names.length; i++) {
          if (act_names[i].length() > 4 && act_names[i].substring(act_names[i].indexOf('_')+1).equals(message.get_data()[1])) {
            found = true;
          }
        }

        if (!found) {
          print_msg_error("The actuator " + message.get_data()[1] + " does not exist on node " + dest_addr, message);
          return false;
        }

        if (float(message.get_data()[2]) > 1.0 || float(message.get_data()[2]) < 0.0) {
          print_msg_error("The value " + message.get_data()[2] + " is not within 0-1 range", message);
          return false;
        }

        if (float(message.get_data()[3]) > 1.0 || float(message.get_data()[3]) < 0.0) {
          print_msg_error("The value " + message.get_data()[3] + " is not within 0-1 range", message);
          return false;
        }

      } else if (code.equals("GE_PRESENCE")) {

        if (!source.equals("RPI")) {
          print_msg_error("The source type does not match the message type", message);
          return false;
        }

        if (!this.my_address.equals(src_addr)) {
          print_msg_error("The source rpi address does not exist", message);
          return false;
        }

        if (!device_locator.is_control_ip(dest_addr)) {
          print_msg_error("The destination control address does not exist", message);
          return false;
        }

        //Data Errors
        if (float(message.get_data()[0]) > 1.0 || float(message.get_data()[0]) < 0.0) {
          print_msg_error("The value " + message.get_data()[0] + " is not within 0-1 range", message);
          return false;
        }
      } else if (code.equals("GE_MOTION")) {

        if (!source.equals("RPI")) {
          print_msg_error("The source type does not match the message type", message);
          return false;
        }

        if (!this.my_address.equals(src_addr)) {
          print_msg_error("The source rpi address does not exist", message);
          return false;
        }

        if (!device_locator.is_control_ip(dest_addr)) {
          print_msg_error("The destination control address does not exist", message);
          return false;
        }

        //Data Errors
        if (float(message.get_data()[0]) > 1.0 || float(message.get_data()[0]) < -1.0) {
          print_msg_error("The value " + message.get_data()[0] + " is not within -1 to 1 range", message);
          return false;
        }

        if (float(message.get_data()[1]) > 1.0 || float(message.get_data()[1]) < -1.0) {
          print_msg_error("The value " + message.get_data()[1] + " is not within -1 to 1 range", message);
          return false;
        }
      } else if (code.equals("GE_SET_BACKGROUND")) {

        if (!source.equals("CONTROL")) {
          print_msg_error("The source type does not match the message type", message);
          return false;
        }

        if (!device_locator.is_control_ip(src_addr)) {
          print_msg_error("The source control address does not exist", message);
          return false;
        }

        if (!device_locator.rpis.containsKey(dest_addr)) {
          print_msg_error("The destination rpi address does not exist", message);
          return false;
        }
      } else if (code.equals("GE_SET_FORWARDING")) {

        if (!source.equals("CONTROL") && !source.equals("RPI")) {
          print_msg_error("The source type does not match the message type", message);
          return false;
        }

        if (!device_locator.is_control_ip(src_addr)) {
          print_msg_error("The source control address does not exist", message);
          return false;
        }

        if (!device_locator.rpis.containsKey(dest_addr)) {
          print_msg_error("The destination rpi address does not exist", message);
          return false;
        }

        //Data error
        if (!message.get_data()[0].equals("ON") && !message.get_data()[0].equals("on") && !message.get_data()[0].equals("OFF") && !message.get_data()[0].equals("off")) {
          print_msg_error("The data must be ON or OFF, invalid data format", message);
          return false;
        }
      } else if (code.equals("GE_CONFIG")) {

        if (!source.equals("CONTROL") && !source.equals("RPI")) {
          print_msg_error("The source type does not match the message type", message);
          return false;
        }

        if (!device_locator.is_control_ip(src_addr) && !device_locator.rpis.containsKey(src_addr)) {
          print_msg_error("The source control or RPI address does not exist", message);
          return false;
        }

        if (!device_locator.rpis.containsKey(dest_addr) && !this.my_pis_node_port.containsKey(Integer.parseInt(dest_addr))) {
          print_msg_error("The destination rpi or node address does not exist", message);
          return false;
        }

        //Data Error: Multiple possibilities for this message type
        String name = message.get_data()[0];
        String value = message.get_data()[1];
        if (name.equals("FREQUENCY") || name.equals("FRAMESKIP")) {
          if (value.contains(".") || value.contains("-")) {
            print_msg_error("The value for " + name + " must be a positive integer", message);
            return false;
          }
          //throw an exception if incorrect
          if (Integer.parseInt(value) == 0 && name.equals("FREQUENCY")) {
            print_msg_error("The frequency cannot be 0", message);
            return false;
          }
        } else if (name.equals("THRESHOLD_MOTION") || name.equals("THRESHOLD_PRESENCE") || name.equals("INTEREST_THRESHOLD") 
          || name.equals("NOISE_THRESHOLD") || name.equals("OVERALL_RELAX") || name.equals("ANGLE_ADJUST")) {
          if (value.contains("-")) {
            print_msg_error("The value for " + name + " must be a positive float", message);
            return false;
          }
          //throw an exception if incorrect
          Float.parseFloat(value);
        } else {
          print_msg_error("The field " + name + " is not a valid configuration parameter", message);
          return false;
        }
      } else if (code.equals("SD_CONFIG")) {

        if (!source.equals("CONTROL") && !source.equals("RPI")) {
          print_msg_error("The source type does not match the message type", message);
          return false;
        }

        if (!device_locator.is_control_ip(src_addr) && !device_locator.rpis.containsKey(src_addr)) {
          print_msg_error("The source control or RPI address does not exist", message);
          return false;
        }

        if (!device_locator.rpis.containsKey(dest_addr) && !this.my_pis_node_port.containsKey(Integer.parseInt(dest_addr))) {
          print_msg_error("The destination rpi or node address does not exist", message);
          return false;
        }

        String[] act_names = device_locator.get_names(Integer.parseInt(dest_addr));

        boolean found = false;
        for (int i = 0; i < act_names.length; i++) {
          if (act_names[i].length() > 4 && act_names[i].substring(act_names[i].indexOf('_')+1).equals(message.get_data()[0])) {
            found = true; 
          }
        }

        if (!found) {
          print_msg_error("The sound detector " + message.get_data()[0] + " does not exist on node " + dest_addr, message);
          return false;
        }

        //Data Error: Multiple possibilities for this message type
        String name = message.get_data()[1];
        String value = message.get_data()[2];

        if (name.equals("ENVELOPEPIN")) {

           // assume it's ok. -- hard to check value of a pin?

        } else if (name.equals("INVERT")) {

          if(!value.equals("TRUE") && !value.equals("FALSE")) {
            print_msg_error("Invert has to be either TRUE or FALSE", message);
            return false;
          }

        } else if (name.equals("FREQUENCY")) {
          if (value.contains(".") || value.contains("-")) {
            print_msg_error("The value for " + name + " must be a positive integer", message);
            return false;
          }
          //throw an exception if incorrect
          if (Integer.parseInt(value) == 0 && name.equals("FREQUENCY")) {
            print_msg_error("The frequency cannot be 0", message);
            return false;
          }
        } else if (name.equals("THRESHOLD")) {

          if (Integer.parseInt(value) < 0) {
            print_msg_error("The threshold has to be above 0", message);
            return false;
          } 
        
        } else if (name.equals("POLLING")) {

          if(!value.equals("ON") && !value.equals("OFF")) {
            print_msg_error("Polling has to be either ON or OFF", message);
            return false;
          }

        } else if (name.equals("USE_LOCAL")) {

          if(!value.equals("LOCAL") && !value.equals("LIVE")) {
            print_msg_error("Live_or_local has to be either LIVE or LOCAL", message);
            return false;
          }

        } else {
            print_msg_error("The field " + name + " is not a valid configuration parameter", message);
            return false;
        }
      } else if (code.equals("IR_CONFIG")) {

        if (!source.equals("CONTROL") && !source.equals("RPI")) {
          print_msg_error("The source type does not match the message type", message);
          return false;
        }

        if (!device_locator.is_control_ip(src_addr) && !device_locator.rpis.containsKey(src_addr)) {
          print_msg_error("The source control or RPI address (" + src_addr + ") does not exist", message);
          return false;
        }

        if (!device_locator.rpis.containsKey(dest_addr) && !this.my_pis_node_port.containsKey(Integer.parseInt(dest_addr))) {
          print_msg_error("The destination rpi or node address does not exist", message);
          return false;
        }

        String[] act_names = device_locator.get_names(Integer.parseInt(dest_addr));

        boolean found = false;
        for (int i = 0; i < act_names.length; i++) {
          if (act_names[i].length() > 4 && act_names[i].substring(act_names[i].indexOf('_')+1).equals(message.get_data()[0])) {
            found = true; 
          }
        }

        if (!found) {
          print_msg_error("The IR detector " + message.get_data()[0] + " does not exist on node " + dest_addr, message);
          return false;
        }

        //Data Error: Multiple possibilities for this message type
        String name = message.get_data()[1];
        String value = message.get_data()[2];
        if (name.equals("FREQUENCY")) {
          if (value.contains(".") || value.contains("-")) {
            print_msg_error("The value for " + name + " must be a positive integer", message);
            return false;
          }
          //throw an exception if incorrect
          if (Integer.parseInt(value) == 0 && name.equals("FREQUENCY")) {
            print_msg_error("The frequency cannot be 0", message);
            return false;
          }
        } else if (name.equals("THRESHOLD")) {

          if (Integer.parseInt(value) < 0) {
            print_msg_error("The threshold has to be above 0", message);
            return false;
          } 
        
        } else if (name.equals("POLLING")) {

          if(!value.equals("ON") && !value.equals("OFF")) {
            print_msg_error("Polling has to be either ON or OFF", message);
            return false;
          }

        } else if (name.equals("USE_LOCAL")) {

          if(!value.equals("LOCAL") && !value.equals("LIVE")) {
            print_msg_error("Live_or_local has to be either LIVE or LOCAL", message);
            return false;
          }

        } else {
            print_msg_error("The field " + name + " is not a valid configuration parameter", message);
            return false;
        }
      } else {
        print_msg_error("The code does not exist", message);
        return false;
      }
    }
    catch(Exception e) {
      print_msg_error("Some unexpected exception, check format of message and values", message);
      e.printStackTrace();
      return false;
    }
    return true;
  }

  /*! \fn print_msg_error(String error, message_OSC message)
   *  \brief Helper function to print an osc message
   *  \param error the message to display along with the osc message contents
   *  \param message the osc message to display
   *  \return none
   */
  void print_msg_error(String error, message_OSC message) {
    println("\nMESSAGE ERROR: " + error);
    println("Code: " + message.get_code());
    print("Data: ");
    println(message.get_data());
  }
}
