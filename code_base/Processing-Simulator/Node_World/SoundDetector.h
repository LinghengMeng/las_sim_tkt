/*!
* <h1> SoundDetector </h1>
*  C++ Sound Detector Object
*
*  \author Farhan Monower et al
*/
#pragma once

#include "Sensor.h"
#include <Arduino.h>
#include "DeviceIdentifier.h"
#define DEFAULT_THRESHOLD  10
#define DEFAULT_FREQ  5 //HZ

/*!
* \class SoundDetector
* \brief the sound detector class, extends Sensor
*/
class SoundDetector : public Sensor{

  public:

    /*!
    * \var p_envelope
    * the envelope pin of the sound detector
    */
    int p_envelope = 30; 
    /*!
    * \var p_audio
    * the audio pin of the sound detector
    */
    int p_audio = 0;
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
    /*!
    * \var sound_data
    * 2-byte array used to store byte-shifted long int so we can send values up to 1024.
    */    
    uint8_t sound_data[2];
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
    * \fn SoundDetector()
    * \brief constructor for the sound detector
    * \return none
    */
    SoundDetector();
    /*!
    * \fn ~SoundDetector()
    * \brief destructor for the sound detector
    * \return none
    */
    ~SoundDetector();
    /*!
    * \fn install(String n, int p, DeviceIdentifier des, String config_string)
    * \brief used for installing the sound detector
    * \param n the name of the sound detector
    * \param p the uid of the device
    * \param des the designator of the device
    * \param config_string the configuration string for the device
    * \return none
    */
    void install(String n, int p, DeviceIdentifier des, String config_string);
    /*!
    * \fn read_value()
    * \brief read the level of the sound detector (envelope)
    * \return int value of envelope reading (0-1024)
    */
    int read_value();
    /*!
    * \fn read_envelope()
    * \brief read the level of the sound detector (envelope)
    * \return int value of envelope reading
    */
    int read_envelope();
    /*!
    * \fn read_audio()
    * \brief read the level of the sound detector (audio)
    * \return int value of audio reading
    */
    int read_audio();

    /*!
    * \fn is_triggered()
    * \brief check if the sound detector is reading a value above the threshold
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
    * \brief read the configuration string and setup sound detector
    * \param config_string the configuration string
    * \return true if the string was read correctly, else false
    */
    bool parse_config_string(String config_string);

    /*!
    * \fn configure_sd(String params)
    * \brief helper to help configure the SD
    * \param params the configuration string
    * \return true if the string was read correctly, else false
    */
    bool configure_sd(String params);
};
