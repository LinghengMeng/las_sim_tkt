/*! 
 * A dynamic integer. This class basically acts like a struct - it stores all the information that is needed to fade a value over some time.
 * \author Niel Mistry
 * \author Matt Gorbet
 */
class DInt
{
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
  long  start_time;
  long   run_time;
  long   run_length;
  boolean is_fading;

  DInt()
  {
    state = 0;

    fade_start = 0;
    fade_target = 0;
    fade_duration = 0;
    fade_delta = 0;
    fade_direction = 1;
    fade_percent_done = 0.0;
    last_millis = tl_millis();
    start_time = tl_millis();
    run_time = 0;
    elapsed_millis = 0;
  }

  DInt(int max_value)
  {
    this.max_value = max_value;
    start_time = tl_millis();
  }

  DInt(int max_value, long run_length) {
    this.max_value = max_value;
    this.run_length = run_length;
    start_time = tl_millis();
  }
}
