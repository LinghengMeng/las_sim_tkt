#ifndef CPP_DEVICE_IDENTIFIER_H
#define CPP_DEVICE_IDENTIFIER_H

/*! 
 * DeviceIdentifier class that stores the device type and number in a single package since they're often needed together 
 */
class DeviceIdentifier {
public:
  int device_type;
  int device_number;

  DeviceIdentifier();
  DeviceIdentifier(int device_type, int device_number);
};


#endif //CPP_DeviceIdentifier_H
