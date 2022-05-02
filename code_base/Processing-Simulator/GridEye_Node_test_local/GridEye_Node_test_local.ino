//
// Code written by Parichit Kumar Fall 2018
// updated by Matt Gorbet Dec 5 2018 to convert centroid deviations to floating point for greater sensitivity
// updated by Matt Gorbet Mar 27 2019 to integrate with Nodes for handshaking etc.
//
//  updated to use Adafruit library, but the Grideye brekout firmware format from Pure Engineering
//
// configuration: NC_PS/LCDM_PB/GridEye
//

#include "Adafruit_AMG88xx.h"
#include "Comms_Manager.h"

Adafruit_AMG88xx amg;

long int read_teensyID();
void blink_out(int num, int delay_time);

static uint8_t teensyID[8];
long int my_id = 0;
uint8_t my_id_bytes[3] = {0x00, 0x00, 0x00};
bool serial_registered = true;  // this is the only difference between the production version and the "local" version
bool debug = true;

Comms_Manager network;

float pixels[AMG88xx_PIXEL_ARRAY_SIZE];

byte pixelTempL;
byte pixelTempH;

float aveTemp;

//Variable definition
int row = 8;
int col = 8;
int threshold_time = 200;  // ms
/*float Current_Pixel_Measurement[8][8];
  float Average_Pixel_Measurement[8][8];
  float Sum_Pixel_Measurement[8][8];
  float Previous_Pixel_Measurement[8][8];
  int frame_count = 0;
  int Active_Pixel[8][8];
  float threshold_temperature_difference = 1;
  int threshold_temperature = 25;
  int current_max_row=0;
  int current_max_col=0;
  int previous_max_row=0;
  int previous_max_col =0;
  int direction_x=0;
  int direction_y=0;
  int detected = 0;*/


float current_millis;
float elapsed_millis;

// for debugging:
bool printing = false;

void setup() {

  my_id = read_teensyID();
  pinMode(13, OUTPUT);

  current_millis = millis();

  bool status;

  status = amg.begin();

  if (!status) {
    Serial.println("Could not find a valid AMG88xx sensor, check wiring!");
    while (1);
  }

  delay(100); // let sensor boot up


  int timeout = 5;

  while (!serial_registered ) // && timeout > 0)
  {
    if (network.get_message() == 1)
    {
      handshake();
    }
    else
    {
      blink_out(1, 1500);
      timeout -= 1;
    }
  }
  if (timeout == 0)
  {
    blink_out(10, 30);
    delay(500);
  }
  
}




//==================   LOOP

void loop() {
  if (network.get_message() == 1)
  {
    if (network.last_code_received == CODE__PASSWORD)
    {
      for (int i = 0; i < 3; i++)
      {
        network.ID[i] = my_id_bytes[i];
      }

      network.write_message(CODE__PASSWORD, my_id_bytes, 3);
      serial_registered = true;
      blink_out(3, 300);
      network.clear_serial();
    }
  }




  elapsed_millis = millis() - current_millis;

  amg.readPixels(pixels);

  for (int pixel = 0; pixel < 64; pixel++) {

    Serial.print(pixels[pixel]);
    Serial.print(" ");

    pixelTempL = pixelTempL + 2;

  }

  Serial.print("@");


  if(network.get_message() == 1) {

    blink_out(10, 30);
    delay(500);

    handshake();
    
  }

  delay(100);
  Serial.clear();


}


void handshake() {


      if (network.last_code_received == CODE__PASSWORD)
      {
        for (int i = 0; i < 3; i++)
        {
          network.ID[i] = my_id_bytes[i];
        }

        network.write_message(CODE__PASSWORD, my_id_bytes, 3);
        serial_registered = true;
        blink_out(3, 300);
        network.clear_serial();
      }
    


}


//-------------  FROM NODE

void blink_out(int num, int delay_time, uint8_t pin)
{
  if (debug)
  {
    pinMode(pin, OUTPUT);
    for (int i = 0; i < num; i++)
    {
      digitalWrite(pin, HIGH);
      delay(delay_time);
      digitalWrite(pin, LOW);
      delay(delay_time);
    }
  }
}
void blink_out(int num, int delay_time)
{
  blink_out(num, delay_time, 13);
}

void read_EE(uint8_t word, uint8_t *buf, uint8_t offset)
{
  noInterrupts();
  FTFL_FCCOB0 = 0x41; // Selects the READONCE command
  FTFL_FCCOB1 = word; // read the given word of read once area

  // launch command and wait until complete
  FTFL_FSTAT = FTFL_FSTAT_CCIF;
  while (!(FTFL_FSTAT & FTFL_FSTAT_CCIF))
    ;
  *(buf + offset + 0) = FTFL_FCCOB4;
  *(buf + offset + 1) = FTFL_FCCOB5;
  *(buf + offset + 2) = FTFL_FCCOB6;
  *(buf + offset + 3) = FTFL_FCCOB7;
  interrupts();
}

long int read_teensyID()
{
  read_EE(0xe, teensyID, 0); // should be 04 E9 E5 xx, this being PJRC's registered OUI
  read_EE(0xf, teensyID, 4); // xx xx xx xx
  long int my_id = (teensyID[5] << 16) | (teensyID[6] << 8) | (teensyID[7]);
  my_id_bytes[0] = teensyID[5];
  my_id_bytes[1] = teensyID[6];
  my_id_bytes[2] = teensyID[7];
  return my_id;
}
