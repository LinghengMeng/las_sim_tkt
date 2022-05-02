#include <SoftPWM.h>
#include "ProtoCell.h"

ProtoCell::ProtoCell()
{
  cur_values.max_value = MAX_PC;
  ir_follower.max_value = MAX_PC;

  influence_subscriptions[INF_IR] = true;
}

ProtoCell::~ProtoCell()
{

}

void ProtoCell::update() {
  Actuator::update_DInt(cur_values);
  Actuator::update_DInt(ir_follower);

  // assign the fading follower value (as int) to this influence
  if(influence_subscriptions[INF_IR]) {
           current_influence[INF_IR] = ir_follower.state;
  }
  
  Actuator::update();  // superposition to calculate excitement value happens after DInts are updated.
      
   cur_value = min(cur_values.max_value, (cur_values.state + int(cur_values.max_value * excitement_value)) ); 
   
}

void ProtoCell::setValue(int v) {
  Actuator::fade((min(v, MAX_PC)), long(0), cur_values);
}

void ProtoCell::fade(int v, long fade_millis)
{
  Actuator::fade(v, fade_millis, cur_values);
}


void ProtoCell::follow_ir(float ir_pct, long time)    
{
  Actuator::fade(MAX_PC * ir_pct, time, ir_follower);
}


void ProtoCell::fade_out(int time)
{

    for (int i = 0; i < NUM_INFLUENCES; i++) {
       current_influence[i] = 0;
    }

    cur_values.state = cur_value;
    ir_follower.state = cur_value;
    excitement_value = 0;

    fade(0, time);
    Actuator::fade(0, time, ir_follower);

}

boolean ProtoCell::parse_config_string(String str)
{
  return true;
}

void ProtoCell::go() {
  actuate(uid, cur_value);
}


