/*!
 <h1> message_OSC </h1>
 wrapper class to access osc messages
 
 \author Farhan Monower
 
 */
import java.util.Arrays;


/*! \class message_OSC
 *  \brief Osc wrapper class to OscP5's OscMessage
 *  \author Farhan Monower
 */
class message_OSC implements Comparable<message_OSC> {

  /*! 
   * \var message
   * osc message contained in the class
   */
  protected OscMessage message;

  /*!
   * \var deliver_time
   * time (can be in future) to deliver this message
   */
  long deliver_time = 0;

  /*! \fn message_OSC(String code_in, String data_in)
   *  \brief build message using code and data strings
   *  \param code_in the code string
   *  \param data_in the data string
   *  \return none.
   */
  message_OSC(String code_in, String data_in) {
    this.message = new OscMessage(code_in);
    this.message.add(data_in);
    this.deliver_time = millis();
  }
  
  /*! \fn message_OSC(String code_in, String data_in, int delay_time)
   *  \brief build message using code and data strings
   *  \param code_in the code string
   *  \param data_in the data string
   *  \return none.
   */
  message_OSC(String code_in, String data_in, int delay_time) {
    this.message = new OscMessage(code_in);
    this.message.add(data_in);
    this.deliver_time = millis() + delay_time;
    println("created new message_OSC with delay_time of " + delay_time);
  }

  /*! \fn message_OSC(OscMessage received) 
   *  \brief build message using an OscMessage
   *  \param received the OscMessage 
   *  \return none.
   */
  message_OSC(OscMessage received) {
    this.message = received;
    deliver_time = millis();
  }

  public int compareTo(message_OSC m) {
        Long my_t   = new Long(this.deliver_time);
        Long your_t = new Long(   m.deliver_time);

     //   if(this.get_code().contains("FADE_ACT") && this.get_code().contains("379776")) {
     //   println("comparing " + my_t + " to " + your_t + ": " + my_t.compareTo(your_t));
     //   }

        return my_t.compareTo(your_t);
    }

  /*! \fn delay()
   *  \brief set the deliver time to now + delay
   *  \return none.
   */
  //synchronized public void delay(int delay_time) {
  //  this.deliver_time = millis() + delay_time;
 // }

  synchronized public void delay(long delay_time) {
    this.deliver_time = millis() + delay_time;
  }



  /*! \fn get_code()
   *  \brief get the code field of the message
   *  \return String code.
   */
  synchronized public String get_code() {
    return this.message.addrPattern();
  }


  /*! \fn get_data()
   *  \brief get the data field as an array of strings
   *  \return string array data
   */
  synchronized public String[] get_data() {
    return this.message.get(0).stringValue().split(" ");
  }

  /*! \fn get_uncut_data()
   *  \brief get the data field as a string
   *  \return string data
   */
  synchronized public String get_uncut_data() {
    return this.message.get(0).stringValue();
  }


  /*! \fn set_code(String code)
   *  \brief sets the code field
   *  \param code the string to set the code to
   *  \return none
   */
  synchronized public void set_code(String code) {
    this.message.setAddrPattern(code);
  }


  /*! \fn set_data(String data)
   *  \brief sets the data field
   *  \param data the string to set the data to
   *  \return none
   */
  synchronized public void set_data(String data) {
    message.set(0, data);
  }

  /*! \fn get_OSC()
   *  \brief gives the contained OscMessage
   *  \return an OscMessage
   */
  synchronized public OscMessage get_OSC() {
    return this.message;
  }
}
