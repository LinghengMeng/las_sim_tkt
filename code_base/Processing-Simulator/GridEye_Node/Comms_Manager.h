/*
  Comms_Manager.cpp - Library for Communication Protocol between Raspberry Pi and Node
  Created By Adam Francey, Kevin Lam, July 5, 2017
  Released for Desktop Kit
  Philip Beesley Architect Inc. / Living Architecture Systems Group
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

#define CODE__SOUND_PT_SAMPLING_CONTROL 0x2a
#define CODE__SOUND_PT_SAMPLING_RPI 0x2b
#define CODE__SOUND_AUTO_SAMPLING 0x2c
#define CODE__SOUND_SET_THRESHOLD 0x2d
#define CODE__SOUND_SET_SAMPLE_FREQUENCY 0x2e

#define CODE__FADE_ACTUATOR_GROUPS 0x1a
#define CODE__WAV_PLAY_SOUND 0x1b
#define CODE__WAV_MASTER_GAIN 0x1c
#define CODE__WAV_TRACK_GAIN 0x1d
#define CODE__WAV_TRACK_FADE 0x1e

#define  CODE__SET_ACTUATOR_MODE              0x3a
#define  CODE__ACTUATOR_MODE_BOTH             0x3b
#define  CODE__ACTUATOR_MODE_TIP_ONLY         0x3c
#define  CODE__ACTUATOR_MODE_BULB_ONLY        0x3d
#define  CODE__ACTUATOR_MODE_TIP_HALF_BULB    0x3e
#define  CODE__ACTUATOR_MODE_BULB_HALF_TIP    0x3f
#define  CODE__ACTUATOR_MODE_CHARGE_DISCHARGE 0x4a
#define  CODE__ACTUATOR_MODE_OSCILLATE        0x4b

#define CODE__PASSWORD 0xaa

#define MAX_DATA_LENGTH 255

class Comms_Manager {

  public:
    Comms_Manager();
    Comms_Manager(int baud_rate);
    ~Comms_Manager();

    void clear_serial();
    void write_message(uint8_t code);
    void write_message(uint8_t msg, uint8_t data[], uint8_t data_length);
    bool get_message();

    uint8_t last_data_received[MAX_DATA_LENGTH] = { 0 };
    int last_data_length;
    uint8_t last_code_received;

    uint8_t SOM[2] = {SOM1, SOM2};
    uint8_t EOM[2] = {EOM1, EOM2};
    uint8_t ID[3] = {0x00, 0x00, 0x00}; //placeholder
    bool message_waiting = 0;

};

#endif
