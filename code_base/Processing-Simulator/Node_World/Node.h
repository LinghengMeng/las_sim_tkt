#pragma once

#include "Arduino.h"
#include "RebelStar.h"
#include "Moth.h"
#include "SMA.h"
#include "DoubleRebelStar.h"
#include "ProtoCell.h"
#include "SoundDetector.h"
#include "WAV_Trigger.h"
#include "IR.h"

const int ACTUATOR_ARR_SIZE = 20; //Was 12, does this need to be increased?
const int DR_ARR_SIZE = 6;
const int WT_ARR_SIZE = 2;
const int SD_ARR_SIZE = 2;
const int IR_ARR_SIZE = 1;
const int GE_ARR_SIZE = 1;
const int NUM_UIDS = 48;


/*! Node class in C++ only stores actuators and it's index. It <i>should</i> contain the update() and go() functions but doesn't 
 *  do anything because of pointers. */
class Node
{
    public:
        /*! What type of Node am I? */
        int type = -1;

        /*! What's my index in the .h file? */
        int my_index = -1;

        /*! What's my physical node ID? */
        long int my_id = 0;
        
        /*! Node ID as array of uint8_t bytes */
        uint8_t my_id_bytes[3] = {0x00, 0x00, 0x00};

        // Statically assigned arrays for each type of actuator with a total counter
        Moth my_moths[ACTUATOR_ARR_SIZE];
        int total_moths;
        
        RebelStar my_rebel_stars[ACTUATOR_ARR_SIZE];
        int total_rebel_stars;
    
        ProtoCell my_protocells[ACTUATOR_ARR_SIZE];
        int total_protocells;
    
        SMA my_smas[ACTUATOR_ARR_SIZE];
        int total_smas;

        DoubleRebelStar my_double_rebel_stars[DR_ARR_SIZE];
        int total_double_rebel_stars;

        SoundDetector my_sound_detectors[SD_ARR_SIZE];
        int total_sound_detectors;

        IRDetector my_ir_detectors[IR_ARR_SIZE];
        int total_ir_detectors;

        WAV_Trigger my_wav_triggers[WT_ARR_SIZE];
        int total_wav_triggers;

        // more actuators

        Node();

        /*! Not called. node_update() in Node_World.ino performs the job that this function is supposed to. */
        void update();

        /*! Not called. node_go() in Node_World.ino performs the job that this function is supposed to. */
        void go();

        /*! Given a pin, returns the type of device that's attached to it. */
        int get_type(uint8_t pin);

        /*! Given an actuator type and number, makes sure that there is a space statically assigned for it (i.e. the number is < arr_size for that device) */
        bool isValid(int act_type, int act_num);

};
