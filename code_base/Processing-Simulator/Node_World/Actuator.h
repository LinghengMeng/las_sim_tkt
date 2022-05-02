#pragma once

#include <Arduino.h>
#include "DInt.h"
#include "DeviceIdentifier.h"
#include "DeviceLocator.h"
#include "Curve.h"


#include <algorithm>
#include <vector>

//  THESE ARE FOR CREATING ARRAYS OF INFLUENCE SUBSCRIPTIONS AND RANGE MAPS -- 
//  THESE ARE IN ACTUATOR.H BUT NEED CONSISTENCY WITH INFLUENCE CODES in COMMS_MANAGER.H  
//  MAYBE GENERATE THIS DYNAMICALLY IN THE FUTURE WITHIN DEVICELOCATOR.H?     -mg Dec 1 2019
//  ... they are 0x50 less than the INFLUENCE_TYPE codes, so as long as they are in the 
//  same order a simple subtraction works.  -mg Jan 18 2020

#define NUM_INFLUENCES 9
#define INF_WV  0 
#define INF_RN  1
#define INF_IR  2
#define INF_SD  3
#define INF_GE  4
#define INF_EXP 5
#define INF_GR  6
#define INF_EC  7
#define INF_RH  8

#define MAX_RS 255
#define MAX_PC 255
#define MAX_MOTH 127 // 224 // using exponential curve, this yields 127 max.
#define MAX_SM 250

class Actuator
{    

public:
  // Who likes dealing with function pointers? (Ok, I do, but no one else does)
  typedef uint8_t (*curve_function)(uint8_t);
  
  private:

  protected:
    const char CONFIG_DELIMITER  = ';';
    int get_num_commands(String str);
    bool are_arguments(String command);
    String get_command(String str, int num);
    String get_keyword(String command);
    String get_arguments(String command);
    void install(String name_, uint8_t pin);
    curve_function curve;


public:
    bool is_fading = false;
    int   current_influence[NUM_INFLUENCES];       // set with messages -- maybe should be a float.
    bool  influence_subscriptions[NUM_INFLUENCES]; 
    float inf_map_lower[NUM_INFLUENCES];
    float inf_map_upper[NUM_INFLUENCES];
    std::vector<int> PWM_pins {3,4,5,6,9,10,20,21,22,23,25,32};  // used in binary search to make sure we are using hard vs. soft pwm
    
    
    String name;
    DeviceIdentifier designator;
    int uid;
    int cur_value;
    float excitement_value = 0.0; //used for behaviours
    float excitement_attenuation = 1.0;
    float last_excitement_value = 0.0; //used for behaviours
    long last_excitement_change;

    bool installed;
    byte * parent_debug_bytes ; // pointer to dbug bytes array
    void set_debug_bytes(uint8_t * db);


    Actuator();
    ~Actuator();

    void install(String name_, uint8_t pin, DeviceIdentifier des);
    virtual void setValue(int v) = 0;
    void setValue(int v, DInt& cur_values);
    virtual void fade(int v, long int fade_millis) = 0;
    void fade(int v, long int fade_millis, DInt& cur_values);
    void fade_out(int time, DInt& cur_values);
    void update();
    void update_DInt(DInt& cur_values);
    virtual boolean parse_config_string(String config) = 0;
    uint8_t get_pin();
   
    void go();
    float map_influence_effect(float incoming_value, float lower_limit1, float upper_limit1, float lower_limit2, float upper_limit2);
    void actuate(int pin, int val);
     // Set curve to transform output
    void set_curve(curve_function);
    
    // Get the current curve function pointer
    curve_function get_curve();

};
