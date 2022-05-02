#pragma once

#include "Actuator.h"
#include "DInt.h"
#include "Comms_Manager.h"

#define READY 0
#define HEATING 1
#define COOLING 2

class SMA : public Actuator{
	public:
	// A DInt representing the current value of the sma
	DInt cur_values;

	const int heat_time = 1200;
	const int cool_time = 15000;
	long int time_at_phase_shift = 0;
	int SM_state = READY;
	int cur_value = 0;
	const int MIN_SM = 127;
	long int cur_sma_time = millis();
		
	SMA();
	~SMA();
	
    
    void install(String name_, uint8_t pin, DeviceIdentifier des);
	
	// Manage the transitions for SMA cooling and heating phases
    void State_and_Target_setting();

	//Called every iteration to update the internal variables inside the sma object
	void update();
	
	//Set the value of the DInt to a specific value v
	void setValue(int v);

	/*! Fade the DInt to a value v over a time fade_millis */
    void fade(int v, long fade_millis);

    // trigger the sma by sending it an influence followed by a stop
	void trigger(int delay_time, Comms_Manager network);

	//Parse the config strings and update internal variables (doesn't do much here, but fine)
	bool parse_config_string(String str);
	
	/*! Set pin value to internal state */
	void go();
};
