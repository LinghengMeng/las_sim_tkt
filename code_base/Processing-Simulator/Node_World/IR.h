/*!
* <h1> IR </h1>
*  C++ IR Object
*
*  \author Farhan Monower, Matt Gorbet et al
*/
#pragma once

#include "Sensor.h"
#include <Arduino.h>
#include "DeviceIdentifier.h"
#define DEFAULT_THRESHOLD  300
#define DEFAULT_FREQ  15 //HZ

/*!
* \class IR
* \brief the IR class, extends Sensor
*/
class IRDetector : public Sensor{

  public:

    /*!
    * \var p_ir
    * the input pin of the IR
    */
    int p_ir = 0; //the input pin of a IR

    int test_ir = 0;
    
    /*!
    * \var cur_value
    * store current value
    */
    int cur_value = 0;
    int test_v = 600;
    /*!
    * \var norm_value
    * the normalized value (above threshold) of the SD
    */
    int norm_value = 0;
    float pct_value = 0.0;
    int IR_MY_MAX = 750;

    /*!
    * \var ir_data
    * 2-byte array used to store byte-shifted long int so we can send values up to 1024.
    */    
    byte ir_data[2];
    /*!
    * \var threshold
    * the threshold to send a message back if passed
    */
    int threshold = DEFAULT_THRESHOLD;    
    /*!
    * \var frequency
    * the frequency of sending messages back
    */
    int frequency = DEFAULT_FREQ;
    /*!
    * \var readme
    * boolean to tell the timing loop to check against the threshold
    */
    bool readme = false;
    /*!
    * \var autosample
    * turn on autosampling to send data back to control periodically
    */
    bool autosample = true;
    /*!
    * \var using_local
    * if using_local is true, don't send any messages because control is using the local (mic) input
    */
    bool using_local = false;
    /*!
    * \var last_millis
    * time checking for autosampling
    */
    int last_millis = millis();
    /*!
    * \var elapsed_millis
    * time checking for autosampling
    */
    int elapsed_millis = 0;

    /*!
    * \fn IR()
    * \brief constructor for the IR
    * \return none
    */
    IRDetector();
    /*!
    * \fn ~IR()
    * \brief destructor for the IR
    * \return none
    */
    ~IRDetector();
    /*!
    * \fn install(String n, int p, DeviceIdentifier des, String config_string)
    * \brief used for installing the IR
    * \param n the name of the IR
    * \param p the uid of the device
    * \param des the designator of the device
    * \param config_string the configuration string for the device
    * \return none
    */
    void install(String n, int p, DeviceIdentifier des, String config_string);
    /*!
    * \fn read_value()
    * \brief read the level of the IR (envelope)
    * \return int value of IR reading (0-1024)
    */
    int read_value();

    /*!
    * \fn is_triggered()
    * \brief check if the IR is reading a value above the threshold
    * \return true if yes, false if no
    */
    bool is_triggered();
    /*!
    * \fn update()
    * \brief used for time sensitive actions such as autosampling
    * \return none
    */
    void update();
    /*!
    * \fn go()
    * \brief checks if we're over the threshold, if so tells node to send message.  If not but we were, tells node to send zero.
    * \return true if node shoud send a message
    */
    bool go();
    /*!
    * \fn parse_config_string(String config_string)
    * \brief read the configuration string and setup IR
    * \param config_string the configuration string
    * \return true if the string was read correctly, else false
    */
    bool parse_config_string(String config_string);

    /*!
    * \fn configure_ir(String params)
    * \brief helper to help configure the IR
    * \param params the configuration string
    * \return true if the string was read correctly, else false
    */
    bool configure_ir(String params);
};
