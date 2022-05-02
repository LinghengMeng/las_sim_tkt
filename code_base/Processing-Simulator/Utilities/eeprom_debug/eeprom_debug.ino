#include <Wire.h>


byte pixelTempL;
byte pixelTempH;
char addr = 0x69;
float celsius;
float aveTemp;

void setup() {
  Wire.begin();
  Serial.begin(115200);
}

void loop() {

  pixelTempL = 0x80;
  Serial.print("@");


  for (int pixel = 0; pixel < 64; pixel++) {
    Wire.beginTransmission(addr);
    Wire.write(pixelTempL);
    Wire.endTransmission();
    Wire.requestFrom(addr, 2);
    byte lowerLevel = Wire.read();
    byte upperLevel = Wire.read();

    int temperature = ((upperLevel << 8) | lowerLevel);

    if (temperature > 2047) {
      temperature = temperature - 4096;

    }

    celsius = temperature * 0.25;

    Serial.print(celsius);
    Serial.print("\n");

    pixelTempL = pixelTempL + 2;
  }
  
  delay(25);
}
