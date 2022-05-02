
#include <Arduino.h>
#include "DInt.h"

DInt::DInt()
{
  state = 0;

  fade_start = 0;
  fade_target = 0;
  fade_duration = 0;
  fade_delta = 0;
  fade_direction = 1;
  fade_percent_done = 0.0;
  last_millis = millis();
  start_time = millis();
  run_time = 0;
  elapsed_millis = 0;
}

DInt::DInt(int max_value)
{
  this->max_value = max_value;
  start_time = millis();
}
