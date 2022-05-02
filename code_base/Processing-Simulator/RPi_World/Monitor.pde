/*!
 <h1> Monitor </h1>
 Class for monitoring health - heartbeats, pings, alerts
 
 \author Matt Gorbet and Farhan Monower
 
 */

 /*! \class Monitor
 *  \brief Holds data and methods for heartbeats, pings, and alerts
 *  \author Matt Gorbet and Farhan Monower
 */
class Monitor {

  /*!
   *  how often to ping, milliseconds
   */
  long ping_time = 15000;
  /*!
   *  used to track pinging time
   */
  long cur_ping_time = 0;

  /*!
   *  how often to check the heartbeat, milliseconds
   */
  long check_time = 30000;
  /*!
   *  used to track checking time
   */
  long cur_check_time = 0;

  /*!
   *  the time threshold after a device is declared dead if the heartbeat is not detected
   */
  long timeout_val = 30000;

  /*!
   *  used to track presence of Control
   */
  long last_ping_from_control = 0;


  /*! 
   * \var node_times
   * Used on rpi only, keeps track of times for the nodes heartbeats
   */
  ConcurrentHashMap<String, Long> node_times;

  /*!
   * \var lost_nodes
   * Used on PI only, keeps track of which nodes are missing
   * 
   */
  ArrayList<String> lost_nodes;


  /*!
   * \var control_lost
   * Keep track of pings from Control
   * 
   */
  Boolean control_lost = false;


    /*! \fn Monitor()
   *  \brief Constructor to be used by PI
   *  \return none.
   */
  Monitor() {

    cur_ping_time = millis();
    cur_check_time = millis();
    last_ping_from_control = millis();

    lost_nodes = new ArrayList<String>();

    node_times = new ConcurrentHashMap<String, Long>();
  }



/*! \fn record_ping_from_control()
   *  \brief note that I just got a ping from Control
   *  \return none.
   */
  void record_ping_from_control() {
          last_ping_from_control = millis();
  }


/*! \fn record_node_seen()
   *  \brief note that I just got a message from a node
   *  \return none.
   */
  void record_node_seen(String sender) {
        if (node_times.containsKey(sender)) { 
            node_times.put(sender, new Long(millis()));
        }
  }

  /*! \fn add_node_to_map(String node_addr)
   *  \brief function to add a pi address to the list of pis being monitored
   *  \return none.
   */
  void add_node_to_map(String node_addr) {
      println("  ... monitor:  will be monitoring " + node_addr + " now.");
      node_times.put(node_addr, new Long(millis()));
      if(!lost_nodes.contains(node_addr)) {   // initially, add it to lost_nodes so that we generate a 'found' message when it comes online.
          lost_nodes.add(node_addr);
      }
  }

  /*! \fn update()
   *  \brief main function of the heartbeat flow, periodically gets called to check if devices are alive
   *  \return none.
   */
  void update(RPi parent_pi) {
      //Periodic ping check
      if (millis() - cur_ping_time > ping_time) {
        ping_devices();
        cur_ping_time = millis();
      }

      //Dead device check
      if (millis() - cur_check_time > check_time) {
        update_heartbeats(timeout_val, parent_pi);
        cur_check_time = millis();
      }
  }


/*! \fn ping_devices()
   *  \brief part of the heartbeat flow, periodically gets called to ping all attached devices to check if they are alive
   *  \return none.
   */
  void ping_devices() {
    if (network.is_real) {
      //pi to node
      Iterator<String> i = node_times.keySet().iterator();

      while (i.hasNext()) {
        String node_id = i.next();
     //   if (network.my_pis_node_port.containsKey(node_id)) {
           // println("... pinging node "  + node_id);
           network.write_message("/RPI/PING/"+network.my_address+"/"+node_id + " ");
      //  } else {
          // tracking a node that seems lost - ie we don't have a serial port for it.  Try handshaking...
      //    println(" ... monitor:  Going to try to handshake to see if I can recover node " + node_id);

          // before I can call handshake() I first need to update the 'setup_ports' list with latest available 
          // teensy-type serial ports.  Not sure how to do this -- check out serial_node_setup() in rpi_world... -mg

          // serial_node_setup();
          // network.handshake();
     //   }
      }
    } 
  }

  /*! \fn update_heartbeats(long timeout)
   *  \brief part of the heartbeat flow, periodically gets called to check if heartbeats are detected
   *  \param timeout a long threshold that if passed, device is declared dead
   *  \return none
   */
  void update_heartbeats(long timeout, RPi parent) {
    if (network.is_real) {
      Iterator<String> i = node_times.keySet().iterator();

      while (i.hasNext()) {
        String node_id = i.next();
        if (node_times.containsKey(node_id)) {

          // println("checking node " + node_id + " heartbeat: last seen " + ( (millis() - node_times.get(node_id))/1000.) + "s ago");

          if (new Long(millis()) - node_times.get(node_id) >= new Long(timeout)) {
            // Node has been lost

            println(" ... monitor: node " + node_id + " lost... sending message to Control");

            String control_ip = network.device_locator.get_control_ip(network.my_address);
            network.write_message("/RPI/NODE_LOST/" + network.my_address + "/" + control_ip + " " + node_id);

            //  add to lost_nodes list
            if(!lost_nodes.contains(node_id)) {
                lost_nodes.add(node_id);
            }

            // EXPERIMENTAL:

            // if(network.my_pis_node_port.get(node_id) != null) {
            //    Serial lost_node_port = network.my_pis_node_port.get(node_id);
            //    network.my_pis_node_port.remove(lost_node_port);  // remove association to this port
            //    setup_ports.remove(lost_node_port);  // remove port from active ports
            //    lost_node_port.clear();
            //    lost_node_port.stop();
            //    lost_node_port.dispose();
            // }

          } else {

            if(lost_nodes.contains(node_id)) {
                
               println("Node " + node_id + " recovered.  Letting Control know");
               lost_nodes.remove(lost_nodes.indexOf(node_id));
               String control_ip = network.device_locator.get_control_ip(network.my_address);
               network.write_message("/RPI/NODE_FOUND/" + network.my_address + "/" + control_ip + " " + node_id);

               // send config info to node:
               parent.send_device_configs(Integer.parseInt(node_id));

            }
          }
        }
      }

      // make sure Control is still sending pings ... if not, let PI know so it can do some local behaviour or tell actuators to turn off, etc.

      if(new Long(millis() - last_ping_from_control) > new Long(timeout)) {

          if(!control_lost) {
            println(" ... monitor:  Control lost?  Calling pi_lost_control()");
            control_lost = true;
            parent.pi_lost_control();
          }

      } else {   // control is here.

         if(control_lost) {   // if we thought it was lost

           last_ping_from_control = millis();
           control_lost = false;

           println(" ... monitor:  Control recovered!  Sending NODE_FOUND messages and also config strings for my nodes so they'll get sync'd");

              Iterator<String> n = node_times.keySet().iterator();

              while (n.hasNext()) {
                String node_id = n.next();
                if (node_times.containsKey(node_id)) {
                    if(!lost_nodes.contains(node_id)) {  // if it isn't on the lost list      
                      String control_ip = network.device_locator.get_control_ip(network.my_address);
                      network.write_message("/RPI/NODE_FOUND/" + network.my_address + "/" + control_ip + " " + node_id);
                    }
      //          parent.send_device_configs(Integer.parseInt(node_id));
                }
              }
            
         }
      }
    } 
  }
}
