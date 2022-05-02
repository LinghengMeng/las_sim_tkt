

static uint8_t teensyID[8];
uint8_t my_id_bytes[3] = {0x00,0x00,0x00};
long int my_id;
uint8_t my_type = 99; // default value
int my_index;


void setup() {
  // put your setup code here, to run once:

Serial.begin(9600);



   Serial.print("My ID is: "); 

}

void loop() {
  // put your main code here, to run repeatedly:
   Serial.println(read_teensyID());

}

// Code to read the Teensy ID
void read_EE(uint8_t word, uint8_t *buf, uint8_t offset) {
  noInterrupts();
  FTFL_FCCOB0 = 0x41;             // Selects the READONCE command
  FTFL_FCCOB1 = word;             // read the given word of read once area

  // launch command and wait until complete
  FTFL_FSTAT = FTFL_FSTAT_CCIF;
  while (!(FTFL_FSTAT & FTFL_FSTAT_CCIF));
  *(buf + offset + 0) = FTFL_FCCOB4;
  *(buf + offset + 1) = FTFL_FCCOB5;
  *(buf + offset + 2) = FTFL_FCCOB6;
  *(buf + offset + 3) = FTFL_FCCOB7;
  interrupts();
}

long int read_teensyID() {
  read_EE(0xe, teensyID, 0); // should be 04 E9 E5 xx, this being PJRC's registered OUI
  read_EE(0xf, teensyID, 4); // xx xx xx xx
  my_id = (teensyID[5] << 16) | (teensyID[6] << 8) | (teensyID[7]);
  my_id_bytes[0] = teensyID[5];
  my_id_bytes[1] = teensyID[6];
  my_id_bytes[2] = teensyID[7];
  return my_id;
}

