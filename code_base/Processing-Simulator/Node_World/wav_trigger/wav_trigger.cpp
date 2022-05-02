#include "wav_trigger.h"
// #include "pindefs.h"
#include <SoftwareSerial.h>
#include <Arduino.h>

WAVTrigger::WAVTrigger(int rx_pin, int tx_pin){
    // for use with software serial
    ser_type_ = 0; // softwareserial
    ser_soft_.setPins(rx_pin,tx_pin);
}

WAVTrigger::WAVTrigger(int hardware_serial){
    ser_type_ = hardware_serial;
    if (ser_type_ == 1){
        ser_hard_ = Serial1;
    } else if (ser_type_ == 2){
        ser_hard_ = Serial2;
    } else if (ser_type_ == 3){
        ser_hard_ = Serial3;
    }
}

// Begin track
void WAVTrigger::begin(int baudrate){
    if (ser_type_ == 0){
        ser_soft_.begin(baudrate);
    } else {
        ser_hard_.begin(baudrate);
    }  
}


WAVTrigger::~WAVTrigger(){
     //wavtools.flashLed(13,30,20);
}

// For serial communication (see documentation in docs folder)
void WAVTrigger::sendByteArray(uint8_t bytes[], int len){

    if (ser_type_ == 0){
        ser_soft_.write(bytes, len);
    } else {
        ser_hard_.write(bytes, len);
    }
}

// play a track
// trk: track number
// code: arguments like TRK_PLAY_POLY as defined in pindefs.h
void WAVTrigger::trackControl(int trk, int code){
    uint8_t txbuf[8];
    txbuf[0] = SOM1;
    txbuf[1] = SOM2;
    txbuf[2] = 0x08;
    txbuf[3] = CMD_TRACK_CONTROL;
    txbuf[4] = (uint8_t)code;
    txbuf[5] = (uint8_t)trk;
    txbuf[6] = (uint8_t)(trk>>8);
    txbuf[7] = EOM;
    
    sendByteArray(txbuf,8);
    //Serial.print("play sound track: ");
    //Serial.println(trk);


}

// sets the volume of the track
// TO DO: find bounds of gain
// may be -10 to 10
void WAVTrigger::masterGain(int gain) {
    uint8_t txbuf[7];
    unsigned short vol;
    
    txbuf[0] = SOM1;
    txbuf[1] = SOM2;
    txbuf[2] = 0x07;
    txbuf[3] = CMD_MASTER_VOLUME;
    vol = (unsigned short)gain;
    txbuf[4] = (uint8_t)vol;
    txbuf[5] = (uint8_t)(vol >> 8);
    txbuf[6] = EOM;
    
    sendByteArray(txbuf,7);
}

void WAVTrigger::trackGain(int trk, int gain) {
    uint8_t txbuf[9];
    unsigned short vol;
    
    txbuf[0] = SOM1;
    txbuf[1] = SOM2;
    txbuf[2] = 0x09;
    txbuf[3] = CMD_TRACK_VOLUME;
    txbuf[4] = (uint8_t)trk;
    txbuf[5] = (uint8_t)(trk >> 8);
    vol = (unsigned short)gain;
    txbuf[6] = (uint8_t)vol;
    txbuf[7] = (uint8_t)(vol >> 8);
    txbuf[8] = EOM;
    
    sendByteArray(txbuf,9);
}

void WAVTrigger::trackFade(int trk, int gain, int time, bool stopFlag) {
    uint8_t txbuf[12];
    unsigned short vol;
    
    txbuf[0] = SOM1;
    txbuf[1] = SOM2;
    txbuf[2] = 0x0c;
    txbuf[3] = CMD_TRACK_FADE;
    txbuf[4] = (uint8_t)trk;
    txbuf[5] = (uint8_t)(trk >> 8);
    vol = (unsigned short)gain;
    txbuf[6] = (uint8_t)vol;
    txbuf[7] = (uint8_t)(vol >> 8);
    txbuf[8] = (uint8_t)time;
    txbuf[9] = (uint8_t)(time >> 8);
    txbuf[10] = stopFlag;
    txbuf[11] = EOM;
    
    sendByteArray(txbuf,12);
}
