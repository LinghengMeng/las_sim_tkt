
/* 
 * File:   Curve.h
 * Based on code from https://github.com/jgillick/arduino-LEDFader
 * Author: cameron
 * 
 * Created by him on October 22, 2013, 1:07 AM
 * ... adapted for LASG by Matt Gorbet, July 9, 2019
 */

#ifndef CURVE_H
#define	CURVE_H

#if (defined(__AVR__))
#include <avr/pgmspace.h>
#else
#include <pgmspace.h>
#endif

class Curve {
 static const uint8_t etable[] PROGMEM;
public:
 static uint8_t exponential(uint8_t);
 static uint8_t linear(uint8_t);
 static uint8_t reverse(uint8_t);
};

#endif	/* CURVE_H */