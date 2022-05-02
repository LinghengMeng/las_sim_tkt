#include <SoftwareSerial.h>
#include "WAV_Trigger.h"
#include <Arduino.h>

WAV_Trigger::WAV_Trigger() {
}

WAV_Trigger::~WAV_Trigger() {
  //wavtools.flashLed(13,30,20);
}

void WAV_Trigger::WAVStart(int baudrate) {

  WAVSerial = new SoftwareSerial(pin_tx, pin_rx);
  uint8_t txbuf[5];

  WAVSerial->begin(baudrate);

  // request version string
  txbuf[0] = WAV_SOM1;
  txbuf[1] = WAV_SOM2;
  txbuf[2] = 0x05;
  txbuf[3] = WAV_CMD_GET_VERSION;
  txbuf[4] = WAV_EOM;
  WAVSerial->write(txbuf, 5);

  // request system info

  txbuf[0] = WAV_SOM1;
  txbuf[1] = WAV_SOM2;
  txbuf[2] = 0x05;
  txbuf[3] = WAV_CMD_GET_SYS_INFO;
  txbuf[4] = WAV_EOM;
  WAVSerial->write(txbuf, 5);

}

void WAV_Trigger::sendByteArray(uint8_t bytes[], int len) {

  WAVSerial->write(bytes, len);

}

void WAV_Trigger::install(String name_, uint8_t pin, DeviceIdentifier des, String config_t) {
  if (config_t.equals("")) {
    installed = false;
    return;
  }

  Actuator::install(name_, pin, des);
  pin_rx = pin;
  parse_config_string(config_t);

  WAVStart();
}

bool WAV_Trigger::parse_config_string(String str)
{
  int num_commands = get_num_commands(str);
  bool success = true;
  for (int i = 0; i < num_commands; i++)
  {
    String command_ = get_command(str, i);
    if (command_.length() != 0)
    {
      String keyword = get_keyword(command_);
      String arguments = get_arguments(command_);
      if (keyword.equals("TXPIN"))
      {
        int pin = (arguments.substring(0, arguments.length())).toInt();
        pinMode(pin, OUTPUT);
        pin_tx = pin;
      } else if (keyword.equals("INVERT"))
      {
        int temp_pin = pin_tx;
        pin_tx = pin_rx;
        pin_rx = temp_pin;
      } else
      {
        success = false;
      }
    }

    // parse the command
  }
  return success;
}


// play a track
// trk: track number
// code: arguments like TRK_PLAY_POLY as defined in pindefs.h
void WAV_Trigger::play_track(int trk, int code) {
  uint8_t txbuf[8];
  txbuf[0] = WAV_SOM1;
  txbuf[1] = WAV_SOM2;
  txbuf[2] = 0x08;
  txbuf[3] = WAV_CMD_TRACK_CONTROL;
  txbuf[4] = (uint8_t)code;
  txbuf[5] = (uint8_t)trk;
  txbuf[6] = (uint8_t)(trk >> 8);
  txbuf[7] = WAV_EOM;

  sendByteArray(txbuf, 8);
  //  Serial.print("play sound track: ");
  //  Serial.println(trk);


}

// sets the volume of the track
// TO DO: find bounds of gain
// may be -10 to 10
void WAV_Trigger::master_volume_set(int gain) {
  if (gain < 0)
    gain = 0;
  else if (gain > 80)
    gain = 80;

  uint8_t txbuf[7];
  unsigned short vol;

  txbuf[0] = WAV_SOM1;
  txbuf[1] = WAV_SOM2;
  txbuf[2] = 0x07;
  txbuf[3] = WAV_CMD_MASTER_VOLUME;
  vol = (unsigned short) (gain - 70); // kind of sketchy
  txbuf[4] = (uint8_t)vol;
  txbuf[5] = (uint8_t)(vol >> 8);
  txbuf[6] = WAV_EOM;

  sendByteArray(txbuf, 7);
}

void WAV_Trigger::track_volume_set(int trk, int gain) {
  if (gain < 0)
    gain = 0;
  else if (gain > 80)
    gain = 80;
  
  uint8_t txbuf[9];
  unsigned short vol;

  txbuf[0] = WAV_SOM1;
  txbuf[1] = WAV_SOM2;
  txbuf[2] = 0x09;
  txbuf[3] = WAV_CMD_TRACK_VOLUME;
  txbuf[4] = (uint8_t)trk;
  txbuf[5] = (uint8_t)(trk >> 8);
  vol = (unsigned short) (gain - 70);
  txbuf[6] = (uint8_t)vol;
  txbuf[7] = (uint8_t)(vol >> 8);
  txbuf[8] = WAV_EOM;

  sendByteArray(txbuf, 9);
}

void WAV_Trigger::track_fade(int trk, int gain, int time, bool stopFlag) {
  if (gain < 0)
    gain = 0;
  else if (gain > 80)
    gain = 80;
  
  uint8_t txbuf[12];
  unsigned short vol;

  txbuf[0] = WAV_SOM1;
  txbuf[1] = WAV_SOM2;
  txbuf[2] = 0x0c;
  txbuf[3] = WAV_CMD_TRACK_FADE;
  txbuf[4] = (uint8_t)trk;
  txbuf[5] = (uint8_t)(trk >> 8);
  vol = (unsigned short) (gain - 70);
  txbuf[6] = (uint8_t)vol;
  txbuf[7] = (uint8_t)(vol >> 8);
  txbuf[8] = (uint8_t)time;
  txbuf[9] = (uint8_t)(time >> 8);
  txbuf[10] = stopFlag;
  txbuf[11] = WAV_EOM;

  sendByteArray(txbuf, 12);
}



void WAV_Trigger::update() {};
void WAV_Trigger::setValue(int v) {};
void WAV_Trigger::fade(int v, long fade_millis) {};
