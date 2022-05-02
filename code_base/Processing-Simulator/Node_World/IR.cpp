#include "IR.h"
#include <Arduino.h>

IRDetector::IRDetector() : Sensor() {

}

IRDetector::~IRDetector() {

}

void IRDetector::install(String n, int p, DeviceIdentifier des, String config_string) {
  // if (config_string.equals("")) {
  //   installed = false;
  //   return;
  // }

  Sensor::install(n, p, des);
  p_ir = p;
  parse_config_string(config_string);
  pinMode(p_ir, INPUT);

  last_millis = millis();
  elapsed_millis = 0;
}


int IRDetector::read_value() {
  readme = false;
  // test_ir += 16;
  // if(test_ir > 1023) test_ir = 0;
  // return (test_ir);
  //parent_debug_bytes[0] = p_ir;
  int value = analogRead(p_ir);
  //parent_debug_bytes[1] = byte(value >> 8) & 0xff;
  //parent_debug_bytes[2] = byte(value) & 0xff;
  return value;
}

bool IRDetector::is_triggered() {
  if (read_value() > threshold)
    return true;
  return false;
}



void IRDetector::update() {


  norm_value = max(0, cur_value-threshold);
  pct_value =  float(norm_value)/float(IR_MY_MAX-threshold);
  

  if (elapsed_millis >= (1000 / frequency)) {
     readme = (true && autosample);
     last_millis = millis();
  }
  elapsed_millis = millis() - last_millis;
}

bool IRDetector::go() {

    if (readme && !using_local) {
   
       int v = read_value();
       
           cur_value  = v;
        
           ir_data[0] = byte((cur_value >> 8) & 0xff);  // but send raw value.
           ir_data[1] = byte((cur_value) & 0xff);

           return(true);  // zero, no change
       
          
    }
    return(false);

}


bool IRDetector::parse_config_string(String config_string)  {

  int num_commands = get_num_commands(config_string);
  bool success = true;
  
  for (int i = 0; i < num_commands; i++)
  {
    String command_ = get_command(config_string, i);
    if (command_.length() != 0)
    {

      success = configure_ir(command_);

    }

    // parse the command
  }
  return success;
}

bool IRDetector::configure_ir(String params) {
  
      String keyword   = get_keyword(params);
      String arguments = get_arguments(params);
      bool success = true;

      if (keyword.equals("THRESHOLD"))
      {
        long int incoming_threshold = (arguments.substring(0, arguments.length())).toInt();
        threshold = incoming_threshold;
        if(threshold >= IR_MY_MAX) threshold = IR_MY_MAX-1;
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
