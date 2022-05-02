/*!
* <h1> DInt </h1>
*  Dynamic Integer used to control actuation levels
*
*  \author Farhan Monower, Niel Mistry et al
*/
#pragma once
/*!
* \class DInt
* \brief Dynamic Integer to control actuation levels. The different variables are required in tandem to fade a value well. 
*/
class DInt
{
  public:
    int max_value = 255;
    int state;

    int   fade_start;
    int   fade_target;
    long  fade_duration;
    int   fade_delta;
    int   fade_direction;
    float fade_percent_done;
    int   fade_minimum_interval = 5;  // smallest step interval in millis
    long  last_millis;
    long  elapsed_millis;
    long start_time;
    long run_time;

    DInt();

    DInt(int max_value);
};
