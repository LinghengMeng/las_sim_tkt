#include <SoftPWM.h>
#include "RebelStar.h"

RebelStar::RebelStar()
{
  cur_values.max_value = MAX_RS;
}

RebelStar::~RebelStar()
{

}

void RebelStar::update() {
  Actuator::update();
  Actuator::update_DInt(cur_values);
 // cur_value = cur_values.state;

   cur_value = min(cur_values.max_value, (cur_values.state + int(cur_values.max_value * excitement_value)) ); 
   
   // cur_value = int(cur_values.max_value * excitement_value);

  // add excitement here.
  //   cur_value = int(255*inf_map_lower[0]);
}

void RebelStar::setValue(int v) {
  Actuator::fade((min(v, MAX_RS)), long(0), cur_values);
}

void RebelStar::fade(int v, long fade_millis)
{
  Actuator::fade(v, fade_millis, cur_values);
}

void RebelStar::fade_out(int time)
{

    for (int i = 0; i < NUM_INFLUENCES; i++) {
       current_influence[i] = 0;
    }

    cur_values.state = cur_value;
    excitement_value = 0;

    fade(0, time);

}

boolean RebelStar::parse_config_string(String str)
{
  return true;
}

void RebelStar::go() {
   actuate(uid, cur_value);
  // actuate(uid, Curve::exponential(cur_value));
}


