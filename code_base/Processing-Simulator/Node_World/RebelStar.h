#pragma once

#include "Actuator.h"
#include "DInt.h"


#define MAX_RS 255

class RebelStar : public Actuator {
  public:
    DInt cur_values;

    RebelStar();
    ~RebelStar();
    void update();
    void setValue(int v);
    void fade(int v, long fade_millis);
    void fade_out(int time);
    boolean parse_config_string(String str);
    void go();
};
