#include <SoftPWM.h>
#include "SMA.h"

//Note possible phase progressions: "ready" to "heat", "heat" to "cooldown", and "cooldown" to "ready"   
//From the perspective of control, the SMA can only be triggered, and the SMA will govern itself until it is available to be triggered again
//After being triggered, the SMA stays on for the preset heat_time
//After heat_time is completed, the SMA switches off and cannot be triggered until the cool_time has completed
//Once cool_time has been completed, the SMA is available to be turned on

//Constructor, defines max value for the SMA
SMA::SMA()
{
  cur_values.max_value = MAX_SM; 
  SM_state = READY;
}

//Destructor
SMA::~SMA()
{

}

void SMA::install(String name_, uint8_t pin_, DeviceIdentifier des_) {

  Actuator::install(name_, pin_, des_);
   
  long r = random(1, 100);
  float lr = float(r/100.)*0.15 + .6;

  influence_subscriptions[INF_IR]=true;

//  inf_map_lower[INF_IR] = lr;
//  inf_map_upper[INF_IR] = lr+0.1;

}

void SMA::update(){ 
  Actuator::update();
  Actuator::update_DInt(cur_values); 
  
  cur_value = min(cur_values.max_value, (cur_values.state + int(cur_values.max_value * excitement_value)) );          // add excitement here. 
 
  if (cur_value >= MIN_SM){
      if (SM_state == READY) {  
          cur_value = MAX_SM;
          SM_state = HEATING;
          time_at_phase_shift = millis();
      }
      else {
       cur_value = 0;   // force to zero because not ready
      }
    }
      else {
        cur_value = 0;  // lower than threshold
    }
   State_and_Target_setting();    
}


void SMA::setValue(int v){ //keep middle value of fade() at 0 so there is no ramp up/down time
  Actuator::fade((min(v,MAX_SM)), long(0), cur_values); 
}

void SMA::fade(int v, long fade_millis)
{
  Actuator::fade(v, fade_millis, cur_values);
}
  
void SMA::trigger(int delay_time, Comms_Manager network) {

    if(SM_state != READY) return;

    long int message_echo_time = delay_time;    // delay millis (will be stripped when message comes back)
    uint8_t delay_payload[4];                   // payload will be: delay time (2 bytes), UID (1 byte), value (1 byte)

  // send trigger pulse:
  // shift delay time
    delay_payload[0] = byte((message_echo_time >> 8) & 0xff);
    delay_payload[1] = byte((message_echo_time) & 0xff);    
  // uid
    delay_payload[2] = uid; // my UID 
  // value to set -- max so it triggers.
    delay_payload[3] = MAX_SM;

    network.write_message(CODE__DELAY_MESSAGE,  delay_payload, 4);
  
  // turn off pulse 500ms after (SMA will do its own profile, but we need to make sure fade is off so it doesn't retrigger)
    message_echo_time += 500;
  // shift delay time
    delay_payload[0] = byte((message_echo_time >> 8) & 0xff);
    delay_payload[1] = byte((message_echo_time) & 0xff);    
  // value to set -- turn influence off.
    delay_payload[3] = 0;

    network.write_message(CODE__DELAY_MESSAGE,  delay_payload, 4);


}


void SMA::State_and_Target_setting() {
  
  // Set state and update cur_value to suit
  cur_sma_time = millis();
  
  if (SM_state == HEATING && cur_sma_time < (time_at_phase_shift + heat_time)){
        // keep heating
        cur_value = MAX_SM;
  }  
  
  else if (SM_state == HEATING && cur_sma_time >= (time_at_phase_shift + heat_time)){
    // stop heating, then enter "cooldown" mode so it cannot be turned back on until the cooldown is complete
    cur_value = 0;
    SM_state = COOLING;
    time_at_phase_shift = millis();
  }
      
  //If the SMA has been in "cooldown" mode for long enough, it is now available to actuate once again
  else if (SM_state == COOLING && cur_sma_time >= (time_at_phase_shift + cool_time)){
    SM_state = READY;
  }

  //If the SMA has not been in cool down for long enough, cur_value is set to 0
  //In the case of SM_state being recently set to "cooldown" by completing it's heat cycle this is technically redundant
  //However this function is still neccessary for continued cool down. Switching to else if might fix redundancy
  if (SM_state == COOLING && cur_sma_time < (time_at_phase_shift + cool_time)){
    cur_value = 0;
  }

  // parent_debug_bytes[7 + (designator.device_number)] = SM_state;

}


bool SMA::parse_config_string(String str){ 
  return true;
}

//Used in switching SMA on or off
void SMA::go(){
  //cur_value has been set in State_and_Target_setting to whatever is needed based on state and time elapsed
  //Either 255 or 0
  actuate(uid, cur_value);
  // parent_debug_bytes[4 + (designator.device_number)] = cur_value;
  if(cur_value > 100) {
//    parent_debug_bytes[9] = -4;
  }
}
