/*!
* <h1> WAV Trigger </h1>
*  C++ WAV Trigger Object
*
*  \author Farhan Monower et al
*/
#include <SoftwareSerial.h>
#include <Arduino.h>
#include "Actuator.h"

#define MAX_VOLUME 80

/*!
* \class WAV_Trigger
* \brief the wav trigger object
*/
class WAV_Trigger : public Actuator {
  public:
  /*!
  * \var pin_rx
  * the rx pin of the wav trigger
  */

  /*!
  * \var pin_tx
  * the tx pin of the wav trigger
  */
    int pin_rx = 0, pin_tx = 0;

    /*!
    * \fn WAV_Trigger()
    * \brief constructor for the WAV Trigger object
    * \return none
    */
    WAV_Trigger();
    /*!
    * \fn ~WAV_Trigger()
    * \brief destructor for the WAV Trigger object
    * \return none
    */
    ~WAV_Trigger();
    /*!
    * \fn WAVStart(int baudrate = 57600)
    * \brief called to start the software serial communication with the WAV Trigger at set baud rate
    * \param baudrate the bits per second speed of the port, 57600 by default
    * \return none
    */
    void WAVStart(int baudrate = 57600);
    /*!
    * \fn play_track(int trk, int code)
    * \brief play a selected track on its own or overlapped with existing audio
    * \param trk the track number to play
    * \param code use the defined TRK_PLAY_SOLO (0) or TRK_PLAY_POlY (1). If 0, ends all other audio playing and plays the track. If 1, plays current audio over existing audio.
    * \return none
    */
    void play_track(int trk, int code);
    /*!
    * \fn master_volume_set(int gain)
    * \brief set the master gain
    * \param gain the gain to set it to, pass in 0-80, the function shifts it between 10 to -70
    * \return none
    */
    void master_volume_set(int gain);
    /*!
    * \fn track_fade(int trk, int gain, int time, bool stopFlag)
    * \brief fade the track to a certain volume over a time, then stop it or keep it playing at that volume
    * \param trk the track number
    * \param gain the volume to set the track to
    * \param time the time to fade the track to the volume
    * \param stopFlag true to stop the flag, false to keep it playing
    * \return none
    */
    void track_fade(int trk, int gain, int time, bool stopFlag);
    /*!
    * \fn track_volume_set(int trk, int gain)
    * \brief set the gain for a single track
    * \param trk the track to adjust
    * \param gain the volume to set the track too
    * \return none
    */
    void track_volume_set(int trk, int gain);
    /*!
    * \fn install(String n, int p, DeviceIdentifier des, String config_string)
    * \brief used for installing the wav trigger
    * \param n the name of the wav trigger
    * \param p the uid of the device
    * \param des the designator of the device
    * \param config_string the configuration string for the device
    * \return none
    */
    void install(String name_, uint8_t pin, DeviceIdentifier des, String config_t);

    /*!
    * \fn update()
    * \brief currently does nothing
    * \return none
    */
    void update();
    /*!
    * \fn setValue(int v)
    * \brief currently does nothing
    * \param v
    * \return none
    */
    void setValue(int v);
    /*!
    * \fn fade(int v, long fade_millis)
    * \brief currently does nothing
    * \param v
    * \param fade_millis
    * \return none
    */
    void fade(int v, long fade_millis);
    /*!
    * \fn parse_config_string(String config_string)
    * \brief read the configuration string and setup wav trigger
    * \param config_string the configuration string
    * \return true if the string was read correctly, else false
    */
    bool parse_config_string(String str);

    
    //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    //Works, but beware of pointers!
    /*!
    * \var WAVSerial
    * the software serial object used to communicate with the WAV Trigger
    */
    SoftwareSerial* WAVSerial;

    // CONSTANTS
    // to be moved into config if not already there
    // WAV Trigger commands
    const int TRK_PLAY_SOLO = 0;
    const int TRK_PLAY_POLY = 1;
    const int TRK_STOP = 4;

    const int WAV_CMD_TRACK_CONTROL = 3;
    const int WAV_CMD_GET_VERSION = 1;
    const int WAV_CMD_GET_SYS_INFO = 2;
    const int WAV_CMD_MASTER_VOLUME = 5;
    const int WAV_CMD_TRACK_VOLUME = 8;
    const int WAV_CMD_TRACK_FADE = 10;
    
    
  private:

    int ser_type_;
    /*!
    * \fn sendByteArray(uint8_t bytes[], int len)
    * \brief write byte array to the wav trigger
    * \param bytes the bytes to send
    * \param len the length of the byte array
    * \return none
    */
    void sendByteArray(uint8_t bytes[], int len);
    const uint8_t WAV_SOM1 = 0xf0;
    const uint8_t WAV_SOM2 = 0xaa;
    const uint8_t WAV_EOM = 0x55;


};
