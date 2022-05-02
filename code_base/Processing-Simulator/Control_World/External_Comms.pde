/*! 
 <h1> External_Comms </h1>
 messaging object for external communication
 
 \author Farhan Monower
 
 */

/*!
 *  \class External_Comms
 *  \brief used for external communication
 */
class External_Comms {
  /*!
   *  \var addr_control
   *  address of control, gets set automatically
   */
  String addr_control = "";

  /*!
   *  \var addr_ext
   *  address of the external agent, currently needs to get set manually in the World Builder
   */
  String addr_ext = "";

  /*!
   *  \var port_ext
   *  the port of the external agent, also needs to get set manually or standardized and hard-coded
   */
  int port_ext = 3001;

  /*!
   *  \var real_received_message
   *  holds the last received real message from the external agent
   */
  message_OSC real_received_message = null;

  /*! 
   *  \fn External_Comms(String ip_control)
   *  \brief Constructor for the external comms manager
   *  \param ip_control the ip address of the control device
   *  \return none
   */
  External_Comms(String ip_control) {
    initialize_external_osc(port_ext);
    this.addr_control = ip_control;
  }

  /*! 
   *  \fn write_message(message_OSC message_in)
   *  \brief write an OSC message to the external comms agent
   *  \param message_in the message to send
   *  \return none
   */
  synchronized void write_message(message_OSC message_in) {
    NetAddress destination_remote = new NetAddress(addr_ext, port_ext);
    external_osc.send(message_in.get_OSC(), destination_remote);
  } 


  /*! 
   *  \fn osc_received(OscMessage received_message)
   *  \brief helped function called by the listener in Control_World.pde to store the incoming message
   *  \param received_message the received message
   *  \return none
   */
  synchronized void osc_received(OscMessage received_message) { 

    message_OSC m = new message_OSC(received_message.addrPattern(), received_message.get(0).stringValue());
    this.real_received_message = m;
    println(m.get_data());
  }
  
  /*! 
   *  \fn get_message() 
   *  \brief get the message
   *  \return message_OSC of the message contained in external comms
   */
  synchronized message_OSC get_message() {
    return this.real_received_message;
  }
}
