/*
  Comms_Manager.cpp - Library for Communication Protocol between Raspberry Pi and Node
  Created By Adam Francey, Kevin Lam, July 5, 2017
  Modified by Farhan Monower and Niel Mistry 04/30/2019
  Philip Beesley Architect Inc. / Living Architecture Systems Group
*/

/*!
* <h1> Comms_Manager </h1>
*  messaging object on the node level and associated variables 
*
*  \author Farhan Monower et al
*/
#pragma once


#ifndef COMMS_MANAGER_H_
#define COMMS_MANAGER_H_
//Codes
#define SOM1 0xff
#define EOM1 0xfe
#define SOM2 0xff
#define EOM2 0xfe
#define NUM_SOM 2
#define NUM_EOM 2
#define NUM_ID 3

#define CODE__PING 0x01
#define CODE__LOST_CONTROL 0x02

#define CODE__SD_CONFIG 0x20
#define CODE__SD_ENVELOPE_PIN 0x29
#define CODE__SD_INVERT 0x28
#define CODE__SD_PT_SAMPLING_CONTROL 0x2a
#define CODE__SD_PT_SAMPLING_RPI 0x2b
#define CODE__SD_AUTO_SAMPLING 0x2c
#define CODE__SD_SET_THRESHOLD 0x2d
#define CODE__SD_SET_FREQUENCY 0x2e
#define CODE__SD_LIVE_OR_LOCAL 0x2f

#define CODE__IR_CONFIG 0x80
#define CODE__IR_PT_SAMPLING_CONTROL 0x8a
#define CODE__IR_PT_SAMPLING_RPI 0x8b
#define CODE__IR_AUTO_SAMPLING 0x8c
#define CODE__IR_SET_THRESHOLD 0x8d
#define CODE__IR_SET_FREQUENCY 0x8e
#define CODE__IR_LIVE_OR_LOCAL 0x8f

#define CODE__FADE_ACTUATOR_GROUPS 0x1a
#define CODE__FADE_ACTUATOR_GROUPS_DR_X 0x1f
#define CODE__UPDATE_ACTUATOR_INFLUENCES 0x1b

#define CODE__WAV_PLAY_SOUND 0x6b                
#define CODE__WAV_MASTER_GAIN 0x6c
#define CODE__WAV_TRACK_GAIN 0x6d
#define CODE__WAV_TRACK_FADE 0x6e

#define  CODE__DR_CONFIG                0x30
#define  CODE__DR_SET_MODE              0x3a
#define  CODE__DR_MODE_BOTH             0x3b
#define  CODE__DR_MODE_TIP_ONLY         0x3c
#define  CODE__DR_MODE_BULB_ONLY        0x3d
#define  CODE__DR_MODE_TIP_HALF_BULB    0x3e
#define  CODE__DR_MODE_BULB_HALF_TIP    0x3f
#define  CODE__DR_MODE_CHARGE_DISCHARGE 0x40
#define  CODE__DR_MODE_OSCILLATE        0x41
#define  CODE__DR_BOTTOM_PIN            0x4c
#define  CODE__DR_INVERT                0x4d
#define  CODE__DR_OFFSET                0x4e

//INFLUENCE codes
#define CODE__INFLUENCE_MAP 0xc2
#define CODE__INFLUENCE_RANGE 0xc1

#define CODE__INFLUENCE_TYPE_WV  0x50
#define CODE__INFLUENCE_TYPE_RN  0x51
#define CODE__INFLUENCE_TYPE_IR  0x52
#define CODE__INFLUENCE_TYPE_SD  0x53
#define CODE__INFLUENCE_TYPE_GE  0x54
#define CODE__INFLUENCE_TYPE_EXP 0x55
#define CODE__INFLUENCE_TYPE_GR  0x56
#define CODE__INFLUENCE_TYPE_EC  0x57
#define CODE__INFLUENCE_TYPE_RH  0x58

#define CODE__DELAY_MESSAGE      0x70

#define CODE__PASSWORD 0xaa
#define CODE__DEBUG_MESSAGE 0xdd

#define MAX_DATA_LENGTH 255

/*!
* \class Comms_Manager
* \author Adam Francey, Farhan Monower
* \brief used to communicate over serial with the rpi 
*/
class Comms_Manager {

  public:
    /*!
    * \fn Comms_Manager()
    * \brief constructor for the Comms_Manager, sets the baud rate to 57600 by default
    * \return none
    */
    Comms_Manager();
    /*!
    * \fn Comms_Manager(int baud_rate)
    * \brief constructor for the Comms_Manager, sets the baud rate to the parameter
    * \param baud_rate the baud rate to set it to
    * \return none
    */
    Comms_Manager(int baud_rate);
    /*!
    * \fn ~Comms_Manager()
    * \brief destructor
    * \return none
    */
    ~Comms_Manager();

    /*!
    * \fn clear_serial()
    * \brief clears the serial input buffer
    * \return none
    */
    void clear_serial();
    /*!
    * \fn write_message(uint8_t code)
    * \brief write an empty message with only the code to the rpi over serial
    * \param code the message code to send
    * \return none
    */
    void write_message(uint8_t code);
    /*!
    * \fn write_message(uint8_t msg, uint8_t data[], uint8_t data_length)
    * \brief write a serial message to the rpi over serial
    * \param msg the message code to send
    * \param data the array of data values to send
    * \param data_length the length of the data array parameter
    * \return none
    */
    void write_message(uint8_t msg, uint8_t data[], uint8_t data_length);
    /*!
    * \fn get_message()
    * \brief gets the message in the input buffer
    * \return true if a message if present, false if not
    */
    bool get_message();


    ////   FOR TESTING --mg
    void my_blink_out(int num, int delay_time, uint8_t pin);
    void my_blink_out(int num, int delay_time);

    ////

    /*!
    * \var last_data_received
    * data array that stores the last data received
    */
    uint8_t last_data_received[MAX_DATA_LENGTH] = { 0 };
    /*!
    * \var last_data_length
    * array that stores the length of the last_data_received
    */
    int last_data_length;
    /*!
    * \var last_code_received
    * the code of the last message received
    */
    uint8_t last_code_received;

    /*!
    * \var SOM
    * array of SOM codes
    */
    uint8_t SOM[2] = {SOM1, SOM2};
    /*!
    * \var EOM
    * array of EOM codes
    */
    uint8_t EOM[2] = {EOM1, EOM2};
    /*!
    * \var ID
    * array of the node ID
    */
    uint8_t ID[3] = {0x00, 0x00, 0x00}; //placeholder
    /*!
    * \var message_waiting
    * is there a message stored and ready to be taken, true if yes, false if no
    */
    bool message_waiting = 0;

};

#endif
