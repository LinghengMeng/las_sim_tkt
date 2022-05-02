#include <SoftwareSerial.h>
#include <Arduino.h>
#include "HardwareSerial.h"
#ifndef __WAV__
#define __WAV__

class WAVTrigger{
    public:   

        WAVTrigger(int rx_pin, int tx_pin);
        WAVTrigger(int hardware_serial);
        ~WAVTrigger();
        void begin(int baudrate = 57600);
        void trackControl(int trk, int code);
        void masterGain(int gain);
        void trackFade(int trk, int gain, int time, bool stopFlag);
        void trackGain(int trk, int gain);

        SoftwareSerial ser_soft_;
        HardwareSerial ser_hard_;
        
        // CONSTANTS
        // to be moved into config if not already there
        // WAV Trigger commands
        const int TRK_PLAY_SOLO = 0;
        const int TRK_PLAY_POLY = 1;
        const int TRK_STOP = 4;
        
        const int CMD_TRACK_CONTROL = 3;
        const int CMD_GET_VERSION = 1;
        const int CMD_GET_SYS_INFO = 2;
        const int CMD_MASTER_VOLUME = 5;
        const int CMD_TRACK_VOLUME = 8;
        const int CMD_TRACK_FADE = 10;
    private:

        int ser_type_;
        void sendByteArray(uint8_t bytes[], int len);
        const uint8_t SOM1 = 0xf0;
        const uint8_t SOM2 = 0xaa;
        const uint8_t EOM = 0x55;
        
              
};

#endif
