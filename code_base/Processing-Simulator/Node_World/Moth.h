#pragma once

#include "Actuator.h"
#include "DInt.h"


class Moth : public Actuator {
  public:
   /*! A DInt representing the current value of the moth */
    DInt cur_values;

    Moth();
    ~Moth();
    /*! Called every iteration to update the internal variables inside the Moth object */
    void update();

    /*! Set the value of the DInt to a specific value v */
    void setValue(int v);

    /*! Fade the DInt to a value v over a time fade_millis */
    void fade(int v, long fade_millis);
    void fade_out(int time);


    /*! Parse the conifg strings and update internal variables (doesn't really do anything on a moth, but function is there) */
    bool parse_config_string(String str);

    /*! Set pin value to internal state */
    void go();
};
