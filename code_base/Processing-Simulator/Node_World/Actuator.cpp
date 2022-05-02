#include "Actuator.h"
#include "SoftPWM.h"

Actuator::Actuator()
{
  name = "";
  uid = -1;
  installed = false;

  for(int i = 0 ; i < NUM_INFLUENCES ; i++) {

    influence_subscriptions[i] = false;
    inf_map_lower[i] = 0.0;
    inf_map_upper[i] = 1.0;

  }
}

Actuator::~Actuator()
{

}

/*! An "instantiation" of this actuator. It needs to be done this way because we want statically assigned actuators. The maximum number of actuators are created at boot time. 
When the dl is read, the node runs this function to enable the actuators that it needs. */
void Actuator::install(String name_, uint8_t pin_) {
  pinMode(pin_, OUTPUT);
  name = name_;
  uid = pin_;
  installed = true;
  curve = (curve_function)Curve::exponential;
}

void Actuator::install(String name_, uint8_t pin, DeviceIdentifier des) {
  install(name_, pin);
  designator.device_number = des.device_number;
  designator.device_type = des.device_type;
}

// Set curve to transform output
void Actuator::set_curve(curve_function c) {
 curve = c;
}

// Get the current curve function pointer
Actuator::curve_function Actuator::get_curve() {
 return curve;
}


void Actuator::setValue(int v, DInt& cur_values)
{
  fade(v, 0, cur_values);
}


void Actuator::fade(int v, long int fade_millis, DInt& cur_values) {


  last_excitement_change = millis();

  // only reset fade percentage done if v has changed  - to avoid asymptotic race that never gets there:
  if (v != cur_values.fade_target) {
    cur_values.fade_percent_done = 0.0;
  }

  cur_values.fade_start    = cur_values.state;
  cur_values.fade_target   = v;
  cur_values.fade_duration = fade_millis;
  
  if ( cur_values.state > cur_values.fade_target ) {

    cur_values.fade_delta = cur_values.state - cur_values.fade_target;
    cur_values.fade_direction = -1;
  } else {

    cur_values.fade_delta = cur_values.fade_target - cur_values.state;
    cur_values.fade_direction = 1;
  }

  is_fading = true;
}


void Actuator::fade_out(int time, DInt& cur_values)
{

    for (int i = 0; i < NUM_INFLUENCES; i++) {
       current_influence[i] = 0;
    }

    cur_values.state = cur_value;
    update_DInt(cur_values);
    excitement_value = 0;

    fade(0, time);

}


  /*!
   * A utility class to update a DInt's internal variables. This gets called every iteration. 
   * \param & cur_values address of The DInt to update. 
   */

void Actuator::update_DInt(DInt& cur_values) {

  cur_values.elapsed_millis = millis() - cur_values.last_millis;
  if (cur_values.elapsed_millis < 0) {
    cur_values.last_millis = millis();
    cur_values.elapsed_millis = 0;
  }

  if (cur_values.fade_duration != 0) {

    if (cur_values.elapsed_millis > cur_values.fade_minimum_interval) {

      float percent  = (float) cur_values.elapsed_millis / (float) cur_values.fade_duration;
      cur_values.fade_percent_done += percent;

      cur_values.last_millis = millis();
    }
    
  } else {

    cur_values.fade_percent_done = 1.0;
    cur_values.last_millis = millis();
    is_fading = false;
  }

  if (cur_values.fade_percent_done > 1.0)  {
    cur_values.fade_percent_done = 1.0;
    is_fading = false;
  }

  cur_values.state = cur_values.fade_start + (int)(cur_values.fade_delta * cur_values.fade_percent_done) * cur_values.fade_direction;

  //  some limits, just in case:
  if (cur_values.state < 0)           { cur_values.state = 0;  is_fading = false; }
  if (cur_values.state > cur_values.max_value)   { cur_values.state = cur_values.max_value;  is_fading = false;  }

  cur_values.run_time = millis() - cur_values.start_time;

  // println("... is " + cur_values.state);

}

  /*!
   * An update function that gets called every iteration. Manages influence superposition and updates Excitement values. 
     This is called by subclasses, but also specific updates are written for each actuator's unique behaviours
   */
  
void Actuator::update() 
{
    // update excitement value via superposition
    excitement_value = 0;

    for(int i = 0; i < NUM_INFLUENCES; i++) {
     if(influence_subscriptions[i]) {
      excitement_value += map_influence_effect(float(current_influence[i]) / 255.0, inf_map_lower[i], inf_map_upper[i], 0.0, 1.0);
      // excitement_value += (float(current_influence[i]) / 255.0) ;
      // excitement_value = inf_map_upper[0]; 
     }
    }

    // debugging hack:
    // excitement_value = float(current_influence[INF_WV]) / 255.0;

    if(excitement_value > 1)
       excitement_value = 1.0;

// here is where we acclimatize if our excitement value stays constant for more than 2s:
    if(excitement_value != last_excitement_value) {                        // is the newly calculated value the same as before?
       last_excitement_change = millis();                                  // if not, remember it's changed now
    }

    if(millis() - last_excitement_change > 2000) {                         // has it been over a second since it changed?
       excitement_attenuation = 1.2-((millis()-last_excitement_change)/10000.0);                                     // if so, change attenuation 99%
       if(excitement_attenuation < 0 ) { excitement_attenuation = 0.0; last_excitement_change = millis()-12000;}
    } else {
       excitement_attenuation = 1.0;                  
    }

    last_excitement_value = excitement_value;                              // remember this excitement value.
    excitement_value *= excitement_attenuation;                            // attenuate if necessary.

    if(designator.device_type==type_SM) {
      parent_debug_bytes[4] = byte(int(excitement_attenuation * 100.0));
    }
}



// mapping function for influence map

float Actuator::map_influence_effect(float incoming_value, float lower_limit1, float upper_limit1, float lower_limit2, float upper_limit2){
  // check for div by zero - no crashing!  
  if((upper_limit1-lower_limit1) < 0.001) lower_limit1-=0.001;

  float temp = (incoming_value - lower_limit1) / (upper_limit1 - lower_limit1);  // incoming value should be a float
  if(temp < 0) temp = 0.0;
  if(designator.device_type==type_SM) {
   parent_debug_bytes[designator.device_number] = byte(int(100.0 * (lower_limit2 + (upper_limit2 - lower_limit2) * temp)));
  }
  return lower_limit2 + (upper_limit2 - lower_limit2) * temp;
}


void Actuator::go() {

  //  SoftPWMSet(pin, cur_value);
  //have to be more complex here
}

uint8_t Actuator::get_pin() {
  return uid;
}


void Actuator::set_debug_bytes(uint8_t * db) {

  parent_debug_bytes = db;

}


/* ---- CONFIG STRING PARSING ---- */

/*!
  Gets the number of commands from the incoming config string
  \param str Incoming config string 
*/
int Actuator::get_num_commands(String str)
{
  int num_commands = 0;
  for (int i = 0; i < str.length(); i++)
  {
    if (str.charAt(i) == CONFIG_DELIMITER)
      num_commands++;
  }
  return num_commands;
}

/*!
  Determines if there are any arguments in the incoming config string. 
  \param command Incoming config string
  \returns true if there are arguments
*/
bool Actuator::are_arguments(String command) {
  if (command.indexOf(" ") < 0)
    return false;
  return true;
}

/*!
  Extract the command from the incoming config string
  \param str Incoming config string
  \param num Which command you want to extract from the config string (0 based). 
  \returns The command part of the config string 

  Example: get_command("TXPIN 5;INVERT;",0); will return "TXPIN 5".
*/
String Actuator::get_command(String str, int num)
{
  int num_delimiters = 0;
  int last_delimiter_index = 0;
  for (int i = 0; i < str.length(); i++)
  {
    if (str.charAt(i) == CONFIG_DELIMITER)
    {
      num_delimiters++;
    }

    if (num_delimiters == num + 1)
    {
      if (num == 0)
        return str.substring(last_delimiter_index, i);
      return str.substring(last_delimiter_index + 1, i);
    }

    if (str.charAt(i) == CONFIG_DELIMITER)
    {
      last_delimiter_index = i;
    }
  }

  return "";
}

/*! 
  Extract the keyword from one command.
  \param command_ the command. 
  \returns The keyword. 
  For example get_keyword("TXPIN 5;") will return TXPIN.
*/ 
String Actuator::get_keyword(String command_) {
  int keyword_end_index = 0;
  //  bool argument = true;

  if (command_.indexOf(" ") > 0)
    keyword_end_index = command_.indexOf(" ");
  else if (command_.indexOf(";") > 0) {
    keyword_end_index = command_.indexOf(";");
  }
  else if (command_.charAt(command_.length() - 1) != ' ' && command_.charAt(command_.length() - 1) != ';') {
    keyword_end_index = command_.length();
  }

  return command_.substring(0, keyword_end_index);
}

/*! 
  Get arguments from a command
  \param command_ The whole command
  \returns Only the arguments

  Example: get_arugments("TESTCMD 2 3 5 6;") will return 2 3 5 6.
*/
String Actuator::get_arguments(String command_) {
  if (are_arguments(command_))
    return command_.substring(command_.indexOf(" ") + 1, command_.length());
  return "";
}

void Actuator::actuate(int pin, int val){                         // makse sure we are using SW vs HW PWM on right pins
  if(std::binary_search(PWM_pins.begin(), PWM_pins.end(), pin))
    analogWrite(pin, val);
  else
    SoftPWMSet(pin, val);
}

///// need this at compile time because of refs from the STL vector library:

namespace std {
  void __throw_bad_alloc()
  {
    Serial.println("Unable to allocate memory");
  }

  void __throw_length_error( char const*e )
  {
    Serial.print("Length Error :");
    Serial.println(e);
  }
}

