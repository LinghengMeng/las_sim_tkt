#include <SoftPWM.h>
#include "Moth.h"
Moth::Moth()
{
  cur_values.max_value = MAX_MOTH;
}

Moth::~Moth()
{

}

void Moth::update() {
  Actuator::update();
  Actuator::update_DInt(cur_values);
  cur_value = min(cur_values.max_value, (cur_values.state + int(float(cur_values.max_value) * excitement_value)) );          // add excitement here.
 
}

void Moth::setValue(int v) {
  Actuator::fade((min(v, MAX_MOTH)), long(0), cur_values);
}

void Moth::fade(int v, long fade_millis)
{
  Actuator::fade(v, fade_millis, cur_values);
}

void Moth::fade_out(int time)
 {

     Actuator::fade_out(time, cur_values);

//     for (int i = 0; i < NUM_INFLUENCES; i++) {
//        current_influence[i] = 0;
//     }

//     cur_values.state = cur_value;
//     excitement_value = 0;

//     fade(0, time);

}

bool Moth::parse_config_string(String str)
{
  return true;
}

void Moth::go() {
  actuate(uid, Curve::linear(cur_value));  // (for a moth, this is linear);
//  actuate(uid, cur_value);
 // actuate(uid, Curve::exponential(cur_value));  // (for a moth, this curve yields 127 at input of 224)
}
