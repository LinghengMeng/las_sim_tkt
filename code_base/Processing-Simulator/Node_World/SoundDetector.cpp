#include "SoundDetector.h"
#include <Arduino.h>

SoundDetector::SoundDetector() : Sensor() {

}

SoundDetector::~SoundDetector() {

}

void SoundDetector::install(String n, int p, DeviceIdentifier des, String config_string) {
  if (config_string.equals("")) {
    config_string = "ENVELOPEPIN 30;";
   // installed = false;
   // return;
  }

  Sensor::install(n, p, des);
  p_audio = p;
  pinMode(p_audio, INPUT);

  parse_config_string(config_string);
  
  pinMode(p_envelope, INPUT);

     
  last_millis = millis();
  elapsed_millis = 0;
}


int SoundDetector::read_value() {
  readme = false;
  return analogRead(p_envelope);
}

int SoundDetector::read_envelope() {
  readme = false;
  return analogRead(p_envelope);
}

int SoundDetector::read_audio() {
  readme = false;
  return analogRead(p_audio);
}

bool SoundDetector::is_triggered() {
  if (read_envelope() > threshold)
    return true;
  return false;
}



void SoundDetector::update() {
  if (elapsed_millis >= (1000 / frequency)) {
    readme = (true && autosample);
    last_millis = millis();
  }
  elapsed_millis = millis() - last_millis;
}

bool SoundDetector::go() {

    if (readme && !using_local) {
   
       int v = read_envelope();

   
       if (v > threshold) {
           cur_value  = v;
           norm_value = v - threshold;   // normalize to thresholded level
        
           sound_data[0] = uint8_t(norm_value >> 8);
           sound_data[1] = uint8_t(norm_value);
           return(true);
       } 
       else {
           if(cur_value > threshold) {   // if it was above threshold but isn't any more, drop to zero.
              cur_value  = 0;
              norm_value = 0;
              sound_data[0] = uint8_t(cur_value >> 8);
              sound_data[1] = uint8_t(cur_value);
              return(true);
           }
           return(false);
       }
          
    }
    return(false);

}

bool SoundDetector::parse_config_string(String config_string)  {

  int num_commands = get_num_commands(config_string);
  bool success = true;

  for (int i = 0; i < num_commands; i++)
  {
    String command_ = get_command(config_string, i);
    if (command_.length() != 0)
    {

            success = configure_sd(command_);

    }

    // parse the command
  }
  return success;
}

bool SoundDetector::configure_sd(String params) {

      String keyword = get_keyword(params);
      String arguments = get_arguments(params);
      bool success = true;

      if (keyword.equals("ENVELOPEPIN"))
      {
        int pin = (arguments.substring(0, arguments.length())).toInt();
        p_envelope = pin;
        pinMode(p_envelope, INPUT);
      } else if (keyword.equals("INVERT"))
      {
        if(  (arguments.substring(0, arguments.length())).toInt() == 1 ) {
          int temp_pin = p_audio;
          p_audio = p_envelope;
          p_envelope = temp_pin;
        }
      } else if (keyword.equals("THRESHOLD"))
      {
        int incoming_threshold = (arguments.substring(0, arguments.length())).toInt();
        threshold = incoming_threshold;
      }
      else if (keyword.equals("FREQUENCY"))
      {
        int incoming_frequency = (arguments.substring(0, arguments.length())).toInt();
        frequency = incoming_frequency;
      }
      else if (keyword.equals("POLLING"))
      {
        int incoming_polling = (arguments.substring(0, arguments.length())).toInt();
        autosample = (incoming_polling==1);
      } 
      else if (keyword.equals("USE_LOCAL"))
      {
        int incoming_local = (arguments.substring(0, arguments.length())).toInt();
        using_local = (incoming_local==1);
      } 
      else
      {
        success = false;
      }

      return success;
    }