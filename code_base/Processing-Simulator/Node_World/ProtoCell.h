#pragma once

#include "Actuator.h"
#include "DInt.h"


#define MAX_PC 255

class ProtoCell : public Actuator {
  public:
    DInt cur_values;
    DInt ir_follower;

    ProtoCell();
    ~ProtoCell();
    void update();
    void setValue(int v);
    void fade(int v, long fade_millis);
    void follow_ir(float pct, long time);
    void fade_out(int time);
    boolean parse_config_string(String str);
    void go();
};
