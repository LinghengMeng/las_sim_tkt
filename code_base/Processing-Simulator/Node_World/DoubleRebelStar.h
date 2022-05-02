#pragma once

#include "Actuator.h"
#include "DInt.h"
#include "Comms_Manager.h"

/*! 
 * \brief A subclass of Actuator, implements DoubleRebelStar specific behaviour. 
 */
class DoubleRebelStar : public Actuator {
  public:
    /*! A DInt corresponding to the value of the tip of the DR */
    DInt top_values;  // akin to cur_values
    int  top_value;  // akin to cur_value

    /*! What pin the tip is connected to */
    int top_pin = 0;

    /*! A DInt corresponding to the value of the bulb of the DR */
    DInt bottom_values;
    int bottom_value;    

    /*! A DInt for the discharge */
    DInt discharge;

    /*! What pin the bulb is connected to */
    int bottom_pin = 0;
    
    /*! invert the pins? */
    int invert = false;

    /*! MODE CONSTANTS  */

    static const int BOTH             = 0x3b;
    static const int TIP_ONLY         = 0x3c;
    static const int BULB_ONLY        = 0x3d;
    static const int TIP_HALF_BULB    = 0x3e;
    static const int BULB_HALF_TIP    = 0x3f;
    static const int CHARGE_DISCHARGE = 0x40;
    static const int OSCILLATE        = 0x41;

    /* follower values */
    long last_follower_millis;
    int  follower_update_rate = 25;

    /*! What mode we are in */
    int mode;

    /*! offset the bottom bulb by __ ms */
    long int offset = 0;

    /*! Used for Charge mode */
    float charge = 0.0;
    
    DoubleRebelStar();
    ~DoubleRebelStar();
    
    /*! See Actuator::install. The DR function is special because it takes a config string and sends it to parse_config_string(); */
    void install(String name_, uint8_t pin, DeviceIdentifier des, String config_t);

    /*! Called every iteration to update the internal variables of this DR */
    void update(Comms_Manager network);

    /*! Sets the value of BOTH the DInts to a specific value */
    void setValue(int v);

    /*! Fades BOTH the DInts to a specific value in some time, depending on mode */
    void fade(int v, long fade_millis);
    void fade_out(int time);

    /*! triggers a fade of just the 'following' pin */
    void follow_to(int value);

    /*! Fades ONE of the DInts to a specific value in some time (for 'which', 1 is top (tip), 2 is bottom (bulb)) */
    void fade_extra(int v, long fade_millis, int which);

    /*! Act on the config string by setting internal variables */
    bool parse_config_string(String str);

    /*! Then configure it */
    bool configure_dr(String str);

    /*! Set the behaviour mode */
    void set_mode(int mode_code);

    /*! Called every iteration to physically turn on pins. */
    void go();
};
