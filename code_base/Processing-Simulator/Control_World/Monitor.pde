/*!
 <h1> Monitor </h1>
 Class for monitoring health - heartbeats, pings, alerts
 
 \author Matt Gorbet and Farhan Monower
 
 */

 /*! \class Monitor
 *  \brief (Control version) Holds data and methods for heartbeats, pings, and alerts
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
  long check_time = 15000;
  /*!
   *  used to track checking time
   */
  long cur_check_time = 0;

  /*!
   *  the time threshold after a device is declared dead if the heartbeat is not detected
   */
  long timeout_val = 30000;

  /*! 
   * \var pi_times
   * Used on control only, keeps track of times for the rpis heartbeats
   */
  ConcurrentHashMap<String, Long> pi_times;

  /*!
   * \var lost_pis
   * Used on control only, keeps track of which nodes and PIs are missing
   * 
   */
  ArrayList<String> lost_devices;


  /*! \fn Monitor()
   *  \brief Constructor to be used by Control
   *  \return none.
   */
  Monitor() {
      
    cur_ping_time = millis();
    cur_check_time = millis();

    lost_devices   = new ArrayList<String>();

    pi_times = new ConcurrentHashMap<String, Long>();

    // initial recording of server:
    record_server_seen();

    // set up external gui server watchdog timer
    // which will kill and restart control if pings end
    if (network.is_live) setWatchdog("true");
  }

  void setWatchdog(String state) {

    OscMessage oscMsg = new OscMessage("/useWatchdog");
    oscMsg.add(state);
    external_osc.send(oscMsg, guiServerLocation);  

  }

  /*! \fn record_pi_seen()
   *  \brief note that I just got a message from a pi
   *  \return none.
   */
  void record_pi_seen(String sender) {

    if (pi_times.containsKey(sender)) { 

        pi_times.put(sender, new Long(millis()));

    }

  }

  void record_server_seen() {
     println("PING from gui_server");
     if(pi_times.containsKey("gui_server")) {
         pi_times.put("gui_server", new Long(millis()));
     } else  {
         add_pi_to_map("gui_server");
     }
  }

  /*! \fn add_pi_to_map(String pi_addr)
   *  \brief function to add a pi address to the list of pis being monitored
   *  \return none.
   */
  void add_pi_to_map(String pi_addr) {
      println(" ... monitor:  will be monitoring " + pi_addr + " now.");
      pi_times.put(pi_addr, new Long(millis())); //build rpi time list for control
  }

  /*! \fn update()
   *  \brief main function of the heartbeat flow, periodically gets called to check if devices are alive
   *  \return none.
   */
  void update() {
      //Periodic ping check
      if (millis() - cur_ping_time > ping_time) {
        ping_devices();
        cur_ping_time = millis();
      }

      //Dead device check
      if (millis() - cur_check_time > check_time) {
        update_heartbeats(timeout_val);
        cur_check_time = millis();
      }
  }


/*! \fn ping_devices()
   *  \brief part of the heartbeat flow, periodically gets called to ping all attached devices to check if they are alive
   *  \return none.
   */
  void ping_devices() {
    if (network.is_live) { //control to pi
      Iterator<String> i = pi_times.keySet().iterator();

      while (i.hasNext()) {
        String pi_id = i.next();
          // printout if this pi is already lost, just to be sure we are looking for it
          if(lost_devices.contains(pi_id)) println("Pinging lost PI " + pi_id + " ...");
          // ping all pis (and gui_server)
          if(pi_id.contains("gui_server")) {
            OscMessage oscMsg = new OscMessage("/PING");
            //println(" ... monitor:  ping to gui server");
            external_osc.send(oscMsg, guiServerLocation);  
          } else {
            network.write_message(network.my_address, pi_id, new message_OSC("/CONTROL/PING/"+network.my_address+"/"+pi_id, ""));
          }
      }
    }
  }

  /*! \fn update_heartbeats(long timeout)
   *  \brief part of the heartbeat flow, periodically gets called to check if heartbeats are detected
   *  \param timeout a long threshold that if passed, device is declared dead
   *  \return none
   */
  void update_heartbeats(long timeout) {
   
    if (network.is_live) {
      Iterator<String> i = pi_times.keySet().iterator();

      while (i.hasNext()) {
        String pi_id = i.next();

        if (pi_times.containsKey(pi_id)) {
          if (new Long(millis()) - pi_times.get(pi_id) >= new Long(timeout)) {
            if(!lost_devices.contains(pi_id)) {  
            lost_devices.add(pi_id);
            println("  ... monitor: PI " + pi_id + " LOST?! ...  need to tell someone. (" + hour() +":"+ minute() + " on  " + day() + "/" + month() + "/" + year() + ")");
            // create the PI alert here

            } else {
                println("  ... monitor: PI " + pi_id + " is still lost... ");
                // maybe update the PI alert here
            }
          } else {

            if(lost_devices.contains(pi_id)) {

            println("PI " + pi_id + " found.");
            lost_devices.remove(lost_devices.indexOf(pi_id));
            // cancel the PI alert here.

            }
          }
        }
      }
    }
  }

  /*! \fn node_lost(String pi, String node)
   *  \brief called when a node is detected as lost
   *  \param pi - the IP of a pi, string format
   *  \param node - the node_id of a node, string format
   *  \return none
   */  
  void node_lost(String pi, String node)
  {
    if(!lost_devices.contains(node)) {

    println(" ... monitor:  PI "+ pi + " has lost contact with node " + node);
    lost_devices.add(node);

    // generate a node alert here...

    } else {
    println(" ... monitor:  Node " + node + " (pi " + pi + ") still lost...");

    // update the node alert here (maybe)...

    }

  }


  /*! \fn node_found(String pi, String node)
   *  \brief called when a node that was detected as lost is found again
   *  \param pi - the IP of a pi, string format
   *  \param node - the node_id of a node, string format
   *  \return none
   */  
  void node_found(String pi, String node)
  {


    if(lost_devices.contains(node)) { 

      println(" ... monitor:  PI "+ pi + " has regained contact with " + node);
      lost_devices.remove(lost_devices.indexOf(node));



      // cancel the node alert here

    } else {

      println(" ... monitor:  That's odd, should never get a 'node found' without it being lost first.");
      println(" ... monitor:  PI: " + pi + "   Node: " + node);

    }

    // re-subscribe live nodes based on virtual nodes when they are 'found' again
     sync_actuator_influence_maps(node);
     dl.find_nodes_parent_rpi(Integer.parseInt(node)).send_device_configs(Integer.parseInt(node));

  }



}

class Alert {

// TODO:  build alert class to generate, track and close alerts using GitHub.






}