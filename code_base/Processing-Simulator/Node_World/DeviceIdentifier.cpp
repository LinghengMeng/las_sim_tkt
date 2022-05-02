//
// Created by PBAIC24 on 3/20/2019.
//

#include "DeviceIdentifier.h"
#include "DeviceLocator.h"

DeviceIdentifier::DeviceIdentifier() {
  device_type = type_UNKNOWN;
  device_number = 0;
}

DeviceIdentifier::DeviceIdentifier(int device_type_, int device_number_) {
  device_type = device_type_;
  device_number = device_number_;
}
