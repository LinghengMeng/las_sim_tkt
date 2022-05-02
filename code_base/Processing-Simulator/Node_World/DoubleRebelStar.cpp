#include <SoftPWM.h>
#include "DoubleRebelStar.h"

DoubleRebelStar::DoubleRebelStar()
{
  top_value = 0;
  bottom_value = 0;
  top_values.max_value = MAX_RS;
  bottom_values.max_value = MAX_RS;
  top_pin = uid;
  mode = BOTH;
  last_follower_millis = millis();
  follower_update_rate = 50;
}

DoubleRebelStar::~DoubleRebelStar()
{

}

void DoubleRebelStar::update(Comms_Manager network) {
  Actuator::update();
  Actuator::update_DInt(top_values);      // update any fades that are going on for top
  Actuator::update_DInt(bottom_values);   // update any fades that are going on for bottom
  Actuator::update_DInt(discharge);       // update the discharge DInt for discharge mode.
 // Actuator::update_DInt(follower);        // update the follower for follow mode.

  // superposition of the fade_acutator_groups messages and the calculated excitement value.
  top_value    = min(top_values.max_value,    (top_values.state    + int(top_values.max_value    * excitement_value)) );          // add excitement here.

  switch(mode) {

  
    case TIP_ONLY:  // tip only
       bottom_value = 0;
    break;

    case DoubleRebelStar::BULB_ONLY:  // bulb only
       bottom_value = top_value;
       top_value = 0;
    break;

    case DoubleRebelStar::TIP_HALF_BULB:  // tip half bulb
        bottom_value = top_value/2;
    break;

    case DoubleRebelStar::BULB_HALF_TIP:  // bulb half tip
        bottom_value = top_value;
        top_value = top_value / 2;
    break;

    case DoubleRebelStar::CHARGE_DISCHARGE:  // charge discharge
      charge = ((charge + top_values.max_value * excitement_value * 0.01) * excitement_attenuation);
      bottom_value = int(charge);
      top_value = discharge.state;

      if(charge >= float(top_values.max_value)) {   // discharge
          charge = 0;
          Actuator::fade(top_values.max_value, 0, discharge);
          update_DInt(discharge);
          Actuator::fade(0, 350, discharge);
      }

    break;


    case DoubleRebelStar::OSCILLATE:  // oscillate
    case DoubleRebelStar::BOTH: // both
    default:

      if( abs(offset) < 20 ) {
        bottom_value = top_value;
        break;
      }

      if( (millis()-last_follower_millis > follower_update_rate) ) {
        //
          long int message_echo_time = offset;    // delay millis (will be stripped when message comes back)
          uint8_t delay_payload[4];               // payload will be: delay time (2 bytes), UID (1 byte), value (1 byte)
        // shift delay time
          delay_payload[0] = byte((message_echo_time >> 8) & 0xff);
          delay_payload[1] = byte((message_echo_time) & 0xff);    
        // uid
          delay_payload[2] = uid; // my UID 
        // value to set -- follow the top value.
          delay_payload[3] = top_value;
        
          network.write_message(CODE__DELAY_MESSAGE,  delay_payload, 4);
          last_follower_millis = millis();
        }

        bottom_value = int(bottom_values.state * excitement_attenuation);
      break;

    }  
}


void DoubleRebelStar::follow_to(int target) {

      Actuator::fade(target, follower_update_rate, bottom_values);
     
}

void DoubleRebelStar::set_mode(int mode_code) {
  mode = mode_code;
}

void DoubleRebelStar::setValue(int v) {
  DoubleRebelStar::fade(min(v, MAX_RS), 0);
}

void DoubleRebelStar::fade(int v, long fade_millis)
{
  Actuator::fade(v, fade_millis, top_values);
}

void DoubleRebelStar::fade_extra(int v, long fade_millis, int which) 
{
  DInt which_values;
  
  if (which == 1) which_values = top_values;
  if (which == 2) which_values = bottom_values;
    
  Actuator::fade(v, fade_millis, which_values);
}


void DoubleRebelStar::fade_out(int time)
{

    for (int i = 0; i < NUM_INFLUENCES; i++) {
       current_influence[i] = 0;
    }

    mode = DoubleRebelStar::BOTH;

    top_values.state = top_value;
    Actuator::update_DInt(top_values);
    bottom_values.state = bottom_value;
    Actuator::update_DInt(bottom_values);
    excitement_value = 0;

    fade(0, time);

}

bool DoubleRebelStar::parse_config_string(String str)
{
  int num_commands = get_num_commands(str);
  bool success = true;
  for (int i = 0; i < num_commands; i++)
  {
    String command_ = get_command(str, i);
    if (command_.length() != 0)
    {

      success = configure_dr(command_);

    }

    // parse the command
  }
  return success;
}

bool DoubleRebelStar::configure_dr(String params) {

      String keyword   = get_keyword(params);
      String arguments = get_arguments(params);
      bool success = true;

      if (keyword.equals("BOTTOMPIN"))
      {
        int pin = (arguments.substring(0, arguments.length())).toInt();
        pinMode(pin, OUTPUT);
        bottom_pin = pin;
      } else if (keyword.equals("INVERT"))
      {
        if (arguments.substring(0, arguments.length()).toInt() == 1) {
          invert = true;
        } else {
          invert = false;
        }
      } else if (keyword.equals("MODE"))
      {
        mode = arguments.substring(0, arguments.length()).toInt();
      } else if (keyword.equals("OFFSET"))
      {
        offset = arguments.substring(0, arguments.length()).toInt();
      } else
      {
        success = false;
      }
    

  
  return success;


}


void DoubleRebelStar::go() {
//  actuate(top_pin, Curve::exponential(top_value.state));
//  actuate(bottom_pin, Curve::exponential(bottom_value.state)); 

   if(invert==1) {
      int temp_value = bottom_value;
      bottom_value   = top_value;
      top_value      = temp_value;
   }

  actuate(top_pin, top_value);
  actuate(bottom_pin, bottom_value);
}

void DoubleRebelStar::install(String name_, uint8_t pin, DeviceIdentifier des, String config_t) {
  Actuator::install(name_, pin, des);
  top_pin = pin;
  parse_config_string(config_t);

}
