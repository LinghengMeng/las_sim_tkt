#include "Arduino.h" // just for vscode
#include "Comms_Manager.h"
#include "Node.h"
#include "DeviceLocator.h"
#include "SoftPWM.h"
#include "EEPROM.h"
#include "DeviceIdentifier.h"


union {
  float f;
  uint8_t b[4];
} u; // marries these two data types together. They access the same spot in memory, but uses a different interpretive type to get it. 

static uint8_t teensyID[8];
byte debug_bytes[10] = {0x00, 0x01, 0x02,0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09};
uint8_t my_id_bytes[3] = {0x00, 0x00, 0x00};
bool serial_registered = false;
int  debug = 0; // 0 = off; 1 = output all messages ;  negative = blink ; abs(<XXXXXX>) debug messages only from this node id || IMPORTANT - if this sculpture is live, please keep debug off. Otherwise, some actuators can randomly blink as the C++ tries to tell you something. 
bool hacked = true; // Set to true if there's something hacked here, because you'll hack something & forget about it otherwise. 

long int last_ping_time;
long int ping_timeout = 30000;  // timeout after 30s of no messages

long int last_debug_time;
long int debug_timeout = 1500;  // send debug message every 3s.


/*
* WHAT'S HACKED: ______
*/

Comms_Manager network;
Node node;
DeviceLocator dl;

DeviceIdentifier uid_to_type[NUM_UIDS]; // An array that stores device identifiers. Acts like a hashmap, uid -> DeviceIdentifier. 

/*! 
    A simple debug routine that helps debug what's happening in the code without having access to printlns. 
    
      Usage: 
      Put known amount of num, time, pin blink_outs in different places in the code & watch carefully to see what happens. 

      Hint: Some pins (e.g. 9, 10, among others) are visible on LEDs on the bottom of the Node Controller, so you don't need the full setup to see what's happening. 
      Pin 13 is the on-board LED.  
    \param num number of times to blink out
    \param delay_time ms to delay between blinks
    \param pin pin number to blink on 
*/
void blink_out(int num, int delay_time, uint8_t pin)
{
  if (debug < 0)
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

/*! Low-level function to help get teensy hardware ID */
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

/*! 
  Reads the information located in DeviceLocator.h. It's out here instead of being in the DeviceLocator class itself because there were issues with pointers.
  To avoid using pointers, this function was put out here but eventually, it should be moved into the dl class. 

  Warning: if the node id isn't found in the DeviceLocator.h, the program will get stuck in this function and start flashing pin 13 with short-short-short-long flashes repeatedly if debug = 2.
  */
void read_dl()
{
  int max_uids = dl.max_uids;

  for (int i = 0; i < dl.num_nodes; i++)
  {
    if (node.my_id == dl.node_ids[i])
    {
      node.my_index = i;
    }
  }

  if (node.my_index == -1)
  {
    debug = -1;
    while (true)
    {
      blink_out(3, 100);
      blink_out(1, 1000);
      // get stuck in this loop so we don't waste time not knowing whats going on
    }
  }

  // blink_out(node.my_index, 250);

  // populate actuators
  int arr_size = 0;
  int* uids;
  int* types;
  
  //only check for defined types to prevent compile errors
  #ifdef type_HU
    if (dl.node_types[node.my_index] == type_HU) {
      arr_size = dl.HU_uids_num;
      uids = dl.HU_uids;
      types = dl.HU_uids_types;
    }
  #endif

  #ifdef type_MU
    if (dl.node_types[node.my_index] == type_MU) {
      arr_size = dl.MU_uids_num;
      uids = dl.MU_uids;
      types = dl.MU_uids_types;
    }
  #endif

  #ifdef type_RH
    if (dl.node_types[node.my_index] == type_RH) {
      arr_size = dl.RH_uids_num;
      uids = dl.RH_uids;
      types = dl.RH_uids_types;
    }
  #endif

  #ifdef type_P1
    if (dl.node_types[node.my_index] == type_P1) {
      arr_size = dl.P1_uids_num;
      uids = dl.P1_uids;
      types = dl.P1_uids_types;
    }
  #endif

  #ifdef type_P2
    if (dl.node_types[node.my_index] == type_P2) {
      arr_size = dl.P2_uids_num;
      uids = dl.P2_uids;
      types = dl.P2_uids_types;
    }
  #endif

  #ifdef type_PF
    if (dl.node_types[node.my_index] == type_PF) {
      arr_size = dl.PF_uids_num;
      uids = dl.PF_uids;
      types = dl.PF_uids_types;

    }
  #endif

  #ifdef type_F1
    if (dl.node_types[node.my_index] == type_F1) {
      arr_size = dl.F1_uids_num;
      uids = dl.F1_uids;
      types = dl.F1_uids_types;
    }
  #endif

  #ifdef type_F2
    if (dl.node_types[node.my_index] == type_F2) {
      arr_size = dl.F2_uids_num;
      uids = dl.F2_uids;
      types = dl.F2_uids_types;
    }
  #endif

  // #ifdef type_GN
  //    if (dl.node_types[node.my_index] == type_GN) {  // should never happen.
  //      // I'm supposed to be running GridEye software!  Wrong hexfile.
  //      debug = -1;
  //      while (true)
  //       {
  //         blink_out(3, 100);
  //         blink_out(1, 1000);
  //         blink_out(6, 50);
  //         blink_out(1, 1000);
  //         // get stuck in this loop so we don't waste time not knowing whats going on
  //       }
  //    }
  // #endif



      // blink_out(2, 1000);
      // blink_out(arr_size, 200);


  for (int i = 0; i < arr_size; i++)
  {

    uint8_t uid = uids[i];
    int type = types[i];

    int device_number = 0;

    device_number = pgm_read_byte(&dl.device_numbers[(node.my_index * max_uids) + i]);
    if(device_number == 0) continue;

    int act_index = device_number - 1;  // actuator indices are zero-based

    if (act_index >= ACTUATOR_ARR_SIZE) {
      continue;       // skip to next itr if out of bounds
    }

    if (uid >= 0 && uid < NUM_UIDS) {
      uid_to_type[uid].device_type = type;
      uid_to_type[uid].device_number = act_index;
    }

    DeviceIdentifier designator = uid_to_type[uid];
    String name_act = type + String(device_number);
    String config_act = "";

    //    blink_out(act_index, 200);
    //    blink_out(2, 50);

    if (uid != -1 && type != type_UNKNOWN) {
      if (type == type_MO) {
        if (act_index >= ACTUATOR_ARR_SIZE)
          continue;  

        node.my_moths[act_index].install(name_act, uid, designator);
        node.total_moths += 1;
      }
      else if (type == type_RS) {
        if (act_index >= ACTUATOR_ARR_SIZE)
          continue;
        node.my_rebel_stars[act_index].install(name_act, uid, designator);
        node.total_rebel_stars += 1;
      }
      else if (type == type_PC) {
        if (act_index >= ACTUATOR_ARR_SIZE)
          continue;
        node.my_protocells[act_index].install(name_act, uid, designator);
        node.total_protocells += 1;
      }
      else if (type == type_DR) {
        if (act_index >= DR_ARR_SIZE)
          continue;
        node.my_double_rebel_stars[act_index].install(name_act, uid, designator, config_act);
        node.total_double_rebel_stars++;
      }
      else if (type == type_SM) {
        if (act_index >= ACTUATOR_ARR_SIZE)
          continue;
        node.my_smas[act_index].install(name_act, uid, designator);
        node.total_smas += 1;
        node.my_smas[act_index].set_debug_bytes(debug_bytes);
      }
      else if (type == type_WT) {
        if (act_index >= WT_ARR_SIZE)
          continue;
        node.my_wav_triggers[act_index].install(name_act, uid, designator, config_act);
        node.total_wav_triggers++;
      }
      else if (type == type_SD) {
        if (act_index >= SD_ARR_SIZE)
          continue;
        node.my_sound_detectors[act_index].install(name_act, uid, designator, config_act);
        node.total_sound_detectors++;
        node.my_sound_detectors[act_index].set_debug_bytes(debug_bytes);
      }
      else if (type == type_IR) {
        if (act_index >=IR_ARR_SIZE)
          continue;
        node.my_ir_detectors[act_index].install(name_act, uid, designator, config_act);
        node.total_ir_detectors++;
        node.my_ir_detectors[act_index].set_debug_bytes(debug_bytes);
      }
      else if (type == type_GE) {
        if (act_index >= GE_ARR_SIZE)
          continue;
        //add grideye stuff ??
      }
      else {
        // do nothing
      }
    }
    uid_to_type[uid].device_type   = designator.device_type;
    uid_to_type[uid].device_number = designator.device_number;

  }

  uids = NULL;
  types = NULL;

}


/*!
\fn setup()
The default Arduino setup function, called once at boot. 
*/
void setup()
{

  last_ping_time = millis();
  randomSeed(millis());  

  if (hacked)
  {
    blink_out(1, 2000);
  }
  SoftPWMBegin();
  node.my_id = read_teensyID();
  pinMode(13, OUTPUT);
  read_dl();

//  debug_bytes[0] = node.total_smas;

//  debug_bytes[1] = node.my_smas[0].uid;
//  debug_bytes[2] = node.my_smas[1].uid;
//  debug_bytes[3] = node.my_smas[2].uid;
  


  /// handhsake futurium-style;  attempt to integrate re-handshaking below are only semi-successful.  Keeping this for Meander for now (-mg Dec 10 2019)

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

/*! Mocks node.update() because we didn't want to pass around Comm_Manager as a pointer. 
Runs every loop to check for mesasges, and act on them based on what the msg code is. At the end of the loop, it clears it's incoming serial buffer so it doesn't fill up and cause a restart. 

See Messaging Standards Document for more information about what each message type looks like & does. 
*/
void node_update()
{
  if (network.get_message() > 0)
  {

      //  last_ping_time = millis();

    if(!serial_registered) {

      blink_out(2, 100);   // if we are handshaking (and debug is set to blink)..

    }

    if (network.last_code_received == CODE__PASSWORD)   // someone is handshaking with us
    {
      for (int i = 0; i < 3; i++)
      {
        network.ID[i] = my_id_bytes[i];
      }

      network.write_message(CODE__PASSWORD, my_id_bytes, 3);
      serial_registered = true;
      blink_out(3, 300);
      network.clear_serial();
      return;
    }
    
    if (network.last_code_received == CODE__PING ) {
        last_ping_time = millis();
        network.write_message(CODE__PING, my_id_bytes, 3);
    }
    
    if (network.last_code_received == CODE__LOST_CONTROL ) {
        fade_out_actuators();
    }

    if (network.last_code_received == CODE__FADE_ACTUATOR_GROUPS || network.last_code_received == CODE__FADE_ACTUATOR_GROUPS_DR_X)
    {
      bool extra = (network.last_code_received==CODE__FADE_ACTUATOR_GROUPS_DR_X);  // ARE THERE TWO BYTES PER DR?

      for (int i = 0; i < network.last_data_length; i += 4)
      {
        uint8_t uid = network.last_data_received[i + 0];

        int type = uid_to_type[uid].device_type;
        int act_index = uid_to_type[uid].device_number;

        uint8_t value = network.last_data_received[i + 1];
        uint8_t value2 = 0;

        if (extra && node.isValid(type, act_index) && type == type_DR) {
         // it is a special _DR+ message
         i++;
         value2 = network.last_data_received[i + 1];
        }

        uint16_t time_ = (network.last_data_received[i + 2] << 8) | network.last_data_received[i + 3]; // big endian bit shifting

        
        if (node.isValid(type, act_index))
        {
          switch (type)
          {
            case type_RS:
              if (node.my_rebel_stars[act_index].installed)
                node.my_rebel_stars[act_index].fade(value, time_);
              break;
            case type_PC:
              if (node.my_protocells[act_index].installed)
                node.my_protocells[act_index].fade(value, time_);
              break;
            case type_MO:
              if (node.my_moths[act_index].installed)
                node.my_moths[act_index].fade(value, time_);
              break;
            case type_DR:
              if (node.my_double_rebel_stars[act_index].installed) {
              if (extra) {
                node.my_double_rebel_stars[act_index].fade_extra(value, time_, 1);
                node.my_double_rebel_stars[act_index].fade_extra(value2, time_, 2);
              } else {
                node.my_double_rebel_stars[act_index].fade(value, time_);
              }
              }
              break;
            case type_SM:
              if (node.my_smas[act_index].installed) {
                  node.my_smas[act_index].fade(value, time_);
              }
              break;
            default:
              break;
          }
        }
      }
    } 
    
    if (network.last_code_received == CODE__UPDATE_ACTUATOR_INFLUENCES)
    {
      int which_inf;

      // switch(network.last_data_received[0])
      // {
        which_inf = int(network.last_data_received[0] - int(0x50));  // INF_XX is in the same order as the CODE_INFLUENCE_TYPE_XX list, just offset by 0x50.

      for (int i = 1; i < network.last_data_length; i += 2)
      {
        uint8_t uid = network.last_data_received[i + 0];
        int type = uid_to_type[uid].device_type;   
        int act_index = uid_to_type[uid].device_number;
        uint8_t value = network.last_data_received[i + 1];
        
        if (node.isValid(type, act_index))
        {
          switch (type)
          {
            case type_RS:
              if (node.my_rebel_stars[act_index].installed)
                  node.my_rebel_stars[act_index].current_influence[which_inf]=value;
              break;
            case type_PC:
              if (node.my_protocells[act_index].installed)
                  node.my_protocells[act_index].current_influence[which_inf]=value;
              break;
            case type_MO:
              if (node.my_moths[act_index].installed) 
                  node.my_moths[act_index].current_influence[which_inf]=value;
              break;
            case type_DR:
              if (node.my_double_rebel_stars[act_index].installed)
                  node.my_double_rebel_stars[act_index].current_influence[which_inf]=value;
              break;
            case type_SM:
              if (node.my_smas[act_index].installed) {
                  node.my_smas[act_index].current_influence[which_inf]=value;
              }
              break;
            default:
              break;
          }
         } else {
        //    debug_bytes[act_index] = -1;
        //    debug_bytes[act_index+1] = uid;
        //    debug_bytes[act_index+2] = type;
        //    debug_bytes[act_index+3] = which_inf;
        //    debug_bytes[act_index+4] = value;
        }
      }
    } 
    
    if (network.last_code_received == CODE__DR_CONFIG)
    {

      // blink_out(4, 50);

        uint8_t uid = network.last_data_received[0];

        int type = uid_to_type[uid].device_type;
        int act_index = uid_to_type[uid].device_number;

      if (node.isValid(type, act_index)) {
        if (node.my_double_rebel_stars[act_index].installed) {
          String config_string = "";
 
          switch(network.last_data_received[1]) {
            case CODE__DR_OFFSET:
            config_string = "OFFSET " + String(int((network.last_data_received[2] << 8) | network.last_data_received[3]));
            break;
    
            case CODE__DR_INVERT:
            config_string = "INVERT " + String(int(network.last_data_received[2]));
            break;
    
            case CODE__DR_SET_MODE:
            config_string = "MODE " + String(int(network.last_data_received[2]));
            break;
    
            case CODE__DR_BOTTOM_PIN:
            config_string = "BOTTOMPIN " + String(int(network.last_data_received[2]));
            break;
           
            default:
            // debug_bytes[0] = byte(-1);  // error in code
            return;
          }
          node.my_double_rebel_stars[act_index].configure_dr(config_string);

        }
      }   
    } 
    
    if (network.last_code_received == CODE__WAV_PLAY_SOUND) 
    {
      uint8_t uid = network.last_data_received[0];

      int type = uid_to_type[uid].device_type;
      int act_index = uid_to_type[uid].device_number;

      if (node.isValid(type, act_index)) {
        if (node.my_wav_triggers[act_index].installed) {
          node.my_wav_triggers[act_index].play_track(network.last_data_received[1], !(network.last_data_received[2]));
        }
      }

    }
    if (network.last_code_received == CODE__WAV_MASTER_GAIN) {
      uint8_t uid = network.last_data_received[0];

      int type = uid_to_type[uid].device_type;
      int act_index = uid_to_type[uid].device_number;

      if (node.isValid(type, act_index)) {
        if (node.my_wav_triggers[act_index].installed) {
          node.my_wav_triggers[act_index].master_volume_set(network.last_data_received[1]);
        }
      }
    }
    if (network.last_code_received == CODE__WAV_TRACK_GAIN) {
      uint8_t uid = network.last_data_received[0];

      int type = uid_to_type[uid].device_type;
      int act_index = uid_to_type[uid].device_number;

      if (node.isValid(type, act_index)) {
        if (node.my_wav_triggers[act_index].installed) {
          node.my_wav_triggers[act_index].track_volume_set(network.last_data_received[1], network.last_data_received[2]);
        }
      }
    }
    if (network.last_code_received == CODE__WAV_TRACK_FADE) {
      uint8_t uid = network.last_data_received[0];

      int type = uid_to_type[uid].device_type;
      int act_index = uid_to_type[uid].device_number;

      if (node.isValid(type, act_index)) {
        if (node.my_wav_triggers[act_index].installed) {
          node.my_wav_triggers[act_index].track_fade(network.last_data_received[1], network.last_data_received[2], (network.last_data_received[3] << 8) | network.last_data_received[4], network.last_data_received[5]);
        }
      }
    }
    if (network.last_code_received == CODE__SD_PT_SAMPLING_CONTROL || network.last_code_received == CODE__SD_PT_SAMPLING_RPI) {
      uint8_t uid = network.last_data_received[0];

      int type = uid_to_type[uid].device_type;
      int act_index = uid_to_type[uid].device_number;

      if (node.isValid(type, act_index)) {
        if (node.my_sound_detectors[act_index].installed) {
          node.my_sound_detectors[act_index].readme = true;
        }
      }
    }
    if (network.last_code_received == CODE__SD_AUTO_SAMPLING) {
      uint8_t uid = network.last_data_received[0];

      int type =      uid_to_type[uid].device_type;
      int act_index = uid_to_type[uid].device_number;

      if (node.isValid(type, act_index)) {
        if (node.my_sound_detectors[act_index].installed) {
          bool autosample_ = network.last_data_received[1];
          node.my_sound_detectors[act_index].autosample = autosample_; // 1 is on, 0 is off
        }
      }
    }
    if (network.last_code_received == CODE__SD_LIVE_OR_LOCAL) {
      uint8_t uid = network.last_data_received[0];

      int type =      uid_to_type[uid].device_type;
      int act_index = uid_to_type[uid].device_number;

      if (node.isValid(type, act_index)) {
        if (node.my_sound_detectors[act_index].installed) {
          bool using_local_ = network.last_data_received[1];
          node.my_sound_detectors[act_index].using_local = using_local_; // 1 is on, 0 is off
        }
      }
    }
    if (network.last_code_received == CODE__SD_SET_THRESHOLD) {
      uint8_t uid = network.last_data_received[0];

      int type = uid_to_type[uid].device_type;
      int act_index = uid_to_type[uid].device_number;

      if (node.isValid(type, act_index)) {
        if (node.my_sound_detectors[act_index].installed) {
          uint16_t threshold_ = (network.last_data_received[1] << 8) | network.last_data_received[2];
          node.my_sound_detectors[act_index].threshold = threshold_;
        }
      }
    }
    if (network.last_code_received == CODE__SD_SET_FREQUENCY) {
      uint8_t uid = network.last_data_received[0];

      int type = uid_to_type[uid].device_type;
      int act_index = uid_to_type[uid].device_number;

      if (node.isValid(type, act_index)) {
        if (node.my_sound_detectors[act_index].installed) {
          uint16_t frequency_ = (network.last_data_received[1] << 8) | network.last_data_received[2];
          node.my_sound_detectors[act_index].frequency = frequency_;
        }
      }
    }


    if (network.last_code_received == CODE__IR_CONFIG) {
      uint8_t uid = network.last_data_received[0];

      int type = uid_to_type[uid].device_type;
      int act_index = uid_to_type[uid].device_number;

      if (node.isValid(type, act_index)) {
        if (node.my_ir_detectors[act_index].installed) {
          String config_string = "";
 
          switch(network.last_data_received[1]) {
            case CODE__IR_SET_THRESHOLD:
            config_string = "THRESHOLD " + String(int((network.last_data_received[2] << 8) | network.last_data_received[3]));
            break;
    
            case CODE__IR_SET_FREQUENCY:
            config_string = "FREQUENCY " + String(int(network.last_data_received[2]));
            break;
    
            case CODE__IR_AUTO_SAMPLING:
            config_string = "POLLING " + String(int(network.last_data_received[2]));
            break;
    
            case CODE__IR_LIVE_OR_LOCAL:
            config_string = "USE_LOCAL " + String(int(network.last_data_received[2]));
            break;
           
            default:
            // debug_bytes[0] = byte(-1);  // error in code
            return;
          }
          node.my_ir_detectors[act_index].configure_ir(config_string);
        } else {
        } 
      } else {
      }
    }

    if (network.last_code_received == CODE__SD_CONFIG) {
      uint8_t uid = network.last_data_received[0];

      int type = uid_to_type[uid].device_type;
      int act_index = uid_to_type[uid].device_number;

      if (node.isValid(type, act_index)) {
        if (node.my_sound_detectors[act_index].installed) {
          String config_string = "";
 
          switch(network.last_data_received[1]) {

            case CODE__SD_ENVELOPE_PIN:
            config_string = "ENVELOPEPIN " + String(int((network.last_data_received[2])));
            break;

            case CODE__SD_INVERT:
            config_string = "INVERT " + String(int((network.last_data_received[2])));
            break;

            case CODE__SD_SET_THRESHOLD:
            config_string = "THRESHOLD " + String(int((network.last_data_received[2] << 8) | network.last_data_received[3]));
            break;
    
            case CODE__SD_SET_FREQUENCY:
            config_string = "FREQUENCY " + String(int(network.last_data_received[2]));
            break;
    
            case CODE__SD_AUTO_SAMPLING:
            config_string = "POLLING " + String(int(network.last_data_received[2]));
            break;
    
            case CODE__SD_LIVE_OR_LOCAL:
            config_string = "USE_LOCAL " + String(int(network.last_data_received[2]));
            break;
           
            default:
            // debug_bytes[0] = byte(-1);  // error in code
            return;
          }
          node.my_sound_detectors[act_index].configure_sd(config_string);
        } else {
        } 
      } else {
      }
    }
    // NOTE: the following 'Influence' messages are now used for Meander !! :)   -mg Dec 1 2019
    
    if (network.last_code_received == CODE__INFLUENCE_MAP) {
      
      // blink_out(2, 50);

      // send_debug_message();
      // network.write_message(CODE__PING, my_id_bytes, 3);

      uint8_t uid = network.last_data_received[1];
      int type = uid_to_type[uid].device_type;
      int act_index = uid_to_type[uid].device_number;
      int which_inf = int(network.last_data_received[0] - int(0x50));  // INF_XX is in the same order as the CODE_INFLUENCE_TYPE_XX list, just offset by 0x50.

      if (node.isValid(type, act_index)) {
        switch (type)
        {
          case type_RS:
            if (node.my_rebel_stars[act_index].installed) {
                node.my_rebel_stars[act_index].influence_subscriptions[which_inf] = network.last_data_received[2];
            }
            break;
          case type_PC:
            if (node.my_protocells[act_index].installed) {
                node.my_protocells[act_index].influence_subscriptions[which_inf] = network.last_data_received[2];
            }
            break;
          case type_MO:
            if (node.my_moths[act_index].installed) {
                node.my_moths[act_index].influence_subscriptions[which_inf] = network.last_data_received[2];
            }
            break;
          case type_DR:
            if (node.my_double_rebel_stars[act_index].installed) {
                node.my_double_rebel_stars[act_index].influence_subscriptions[which_inf] = network.last_data_received[2];
            }
            break;
          case type_SM:
               for (int i = 0; i < network.last_data_length - 1; i++) {
                 node.my_smas[act_index].influence_subscriptions[which_inf] = network.last_data_received[2];
             }
             break;
          default:
            break;
        }
      }
    }
 
    if (network.last_code_received == CODE__INFLUENCE_RANGE) {
      uint8_t uid = network.last_data_received[1];
      int type = uid_to_type[uid].device_type;
      int act_index = uid_to_type[uid].device_number;
      int which_inf = int(network.last_data_received[0] - int(0x50));  // INF_XX is in the same order as the CODE_INFLUENCE_TYPE_XX list, just offset by 0x50.

      // for (int i = 0; i < 4; i++) {
      //   u.b[i] = byte(network.last_data_received[i + 2]);

      //   // debugging float:
      //   if(uid == 20) { 
      //     debug_bytes[6+i] = u.b[i];
      //   }
      // }

      // float lower_limit = u.f;

      uint16_t float_as_int = ((network.last_data_received[2] << 8) | network.last_data_received[3]); // big endian bit shifting

      float lower_limit = float(float_as_int / 1000.0);

      // for (int i = 0; i < 4; i++) {
      //   u.b[i] = byte(network.last_data_received[i + 4]);
      // }
      // float upper_limit = u.f;

      float_as_int = ((network.last_data_received[4] << 8) | network.last_data_received[5]); // big endian bit shifting
      float upper_limit = float(float_as_int / 1000.0);


      if (node.isValid(type, act_index)) {
        switch (type)
        {
          case type_RS:
            if (node.my_rebel_stars[act_index].installed) {
              node.my_rebel_stars[act_index].inf_map_lower[which_inf] = lower_limit;
              node.my_rebel_stars[act_index].inf_map_upper[which_inf] = upper_limit;
            }
            break;
          case type_PC:
            if (node.my_protocells[act_index].installed) {
                node.my_protocells[act_index].inf_map_lower[which_inf] = lower_limit;
                node.my_protocells[act_index].inf_map_upper[which_inf] = upper_limit;
            }
            break;
          case type_MO:
            if (node.my_moths[act_index].installed) {
              node.my_moths[act_index].inf_map_lower[which_inf] = lower_limit;
              node.my_moths[act_index].inf_map_upper[which_inf] = upper_limit;
            }
            break;
          case type_DR:
            if (node.my_double_rebel_stars[act_index].installed) {
              node.my_double_rebel_stars[act_index].inf_map_lower[which_inf] = lower_limit;
              node.my_double_rebel_stars[act_index].inf_map_upper[which_inf] = upper_limit;
            }
            break;
           case type_SM:
             if (node.my_smas[act_index].installed) {
               node.my_smas[act_index].inf_map_lower[which_inf] = lower_limit;
               node.my_smas[act_index].inf_map_upper[which_inf] = upper_limit;
             }
             break;
          default:
            break;
        }
      }
    }  
    
    if (network.last_code_received == CODE__DELAY_MESSAGE)
        {
        // a message coming back to the node after being delayed - needs to be parsed:  UID then a byte value (for DRS)

        uint8_t uid = network.last_data_received[0];
        int type = uid_to_type[uid].device_type;
        int act_index = uid_to_type[uid].device_number;

        // debug:  virtual acutator UID receieved a delayed payload

        if (node.isValid(type, act_index))
        {
          switch(type)
          {
            case type_DR:
                if (node.my_double_rebel_stars[act_index].installed) {
                    node.my_double_rebel_stars[act_index].follow_to(network.last_data_received[1]);
                }
      
            break;

            case type_SM:
                if (node.my_smas[act_index].installed) {
                    node.my_smas[act_index].fade(network.last_data_received[1], 0);
                }

            break;

          }
        }  /// not valid
      }


    
    ///  NOTE - BUFFER WAS BUILDING UP AND WE WERE SKIPPING MESSAGES SO I COMMENTED THIS OUT -mg dec 9 2019.  ??
   //  network.clear_serial(); // If there's a build up of messages on the node, we will skip messages!! This is something to change if it becomes an issue!
  }

  // check that we're still receiving messages to make sure we're not orphaned
  if(((millis() - last_ping_time) > ping_timeout) && (serial_registered == true)) {


        serial_registered = false;
        randomSeed(millis());       // seed the random number generator using the currently elapsed millis();
        fade_out_actuators();
  }

  // if we are orphaned (ie no messages in last n seconds)
  if(!serial_registered) {
  
    // generate_local_behaviour();   // set up some fades, based on random probabilities?  (vs. fade_out_actuators below)
    
    // actually, need to shut off any actuators here to avoid them becoming 'stuck' like in Futurium -mg Nov 20 2019.

    //   fade_out_actuators();
 


  }

  if( (abs(debug) > 0) && (millis() - last_debug_time > debug_timeout) ) {
    if(abs(debug) > 1000 && abs(debug) == node.my_id) {
      send_debug_message();
      last_debug_time = millis();
    }
  }

  // Call the update function on all installed actuators so that internal variables are updated. 
  for (int i = 0; i < ACTUATOR_ARR_SIZE; i++)
  {
    if (node.my_moths[i].installed) {
      node.my_moths[i].update();
    }
    if (node.my_rebel_stars[i].installed) {
      node.my_rebel_stars[i].update();
    }
    if (node.my_protocells[i].installed) {
        node.my_protocells[i].update();
    }

    if (node.my_smas[i].installed)
         node.my_smas[i].update();
  }

  for (int i = 0; i < DR_ARR_SIZE; i++)
  {
    if (node.my_double_rebel_stars[i].installed)
        node.my_double_rebel_stars[i].update(network);
  }

  for (int i = 0; i < WT_ARR_SIZE; i++)
  {
    //    if (node.my_wav_triggers[i].installed)
    //      node.my_wav_triggers[i].update();
  }

  for (int i = 0; i < SD_ARR_SIZE; i++)
  {
    if (node.my_sound_detectors[i].installed)
        node.my_sound_detectors[i].update();
  }

  for (int i = 0; i < IR_ARR_SIZE; i++)
  {
    if (node.my_ir_detectors[i].installed)
        node.my_ir_detectors[i].update();
  }

  for (int i = 0; i < GE_ARR_SIZE; i++)
  {
    // update ges
  }

}

/*! Emulates node.go() in Processing. This isn't inside the Node class to mirror node_update, which can't be in the Node class to avoid sending Comm_manager as a pointer. */
void node_go()
{
  for (int i = 0; i < ACTUATOR_ARR_SIZE; i++)
  {
    if (node.my_moths[i].installed)
    {
      node.my_moths[i].go();
    }
    if (node.my_rebel_stars[i].installed) {
        node.my_rebel_stars[i].go();
    }
    if (node.my_protocells[i].installed) {
        node.my_protocells[i].go();
    }
    if (node.my_smas[i].installed) {
        node.my_smas[i].go();
    }
  }


  for (int i = 0; i < DR_ARR_SIZE; i++)
  {
    if (node.my_double_rebel_stars[i].installed)
      node.my_double_rebel_stars[i].go();
  }

  for (int i = 0; i < WT_ARR_SIZE; i++)
  {
    //    if (node.my_wav_triggers[i].installed)
    //      node.my_wav_triggers[i].go();
  }

  for (int i = 0; i < SD_ARR_SIZE; i++)
  {
    if (node.isValid(type_SD, i) && node.my_sound_detectors[i].installed) {     
         if(node.my_sound_detectors[i].go()) {
            network.write_message(CODE__SD_PT_SAMPLING_CONTROL, node.my_sound_detectors[i].sound_data, 2);
         } 
     
    }
  }

  for (int i = 0; i < IR_ARR_SIZE; i++)
  {
    if (node.isValid(type_IR, i) && node.my_ir_detectors[i].installed) {     

         if(node.my_ir_detectors[i].go()) {
            network.write_message(CODE__IR_PT_SAMPLING_CONTROL, node.my_ir_detectors[i].ir_data, 2);

            float IRval = node.my_ir_detectors[i].pct_value;

            // LOCAL BEHAVIOUR:  directly connect any ProtoCells to my IR sensor
            for (int j = 0; j < ACTUATOR_ARR_SIZE; j++)
            {
              if (node.my_protocells[j].installed) {
    //            node.my_protocells[j].fade(node.my_protocells[j].cur_values.max_value * IRval, 1000);
                  node.my_protocells[j].follow_ir(IRval, 200);
              }
            }

            debug_bytes[8] = byte(int(100.0 * IRval));
            debug_bytes[9] = byte(255 * 0.8);
            
            // LOCAL BEHAVIOUR:  trigger SMAs at high presence.
            if(IRval > 0.8 ) {
         //      trigger_smas();
            }

            for (int j = 0; j < ACTUATOR_ARR_SIZE; j++)
            {
              if (node.my_smas[j].installed && node.my_smas[j].influence_subscriptions[INF_IR]) {  
                  node.my_smas[j].current_influence[INF_IR] = int( IRval * float(255.0));
              }
            }  

         } else {
         //  debug_bytes[4] = -1;
         }
    } else {
        // debug_bytes[4] = -2;
        // if(!node.my_ir_detectors[i].installed) debug_bytes[4] = -3;
    }
  }

  for (int i = 0; i < GE_ARR_SIZE; i++)
  {
    // Note:  updates to the GridEyes happen in the PI... GE_ARR_SIZE should always be zero in the NC.  -mg, July 2019
  }
}

void trigger_smas() 
{
    for (int i = 0; i < ACTUATOR_ARR_SIZE; i++)
      {
        if (node.isValid(type_SM, i) && node.my_smas[i].installed) {  
        // trigger in random amount of time up to 800ms.
        long int message_echo_time = random(1, 500);    // delay millis (will be stripped when message comes back)
        node.my_smas[i].trigger(message_echo_time, network); // my UID 
        }
      }  
}

/*
 *\fn send_debug_message
 *
 * \
 * 
 */

void send_debug_message() 
{
      network.write_message(CODE__DEBUG_MESSAGE, debug_bytes, 10);
     
}



/* 
 *\fn generate_local_behaviour()
 *
 * if we are orphaned from our PI, generate semi-random background behaviours while waiting for reconnection
 */

void generate_local_behaviour() {

 int probability_mo   = 0;  // moths off for Futurium
 int probability_rs   = 12;
 int probability_pc   = 8;
 int probability_drs  = 5; 

 int moth_low_range   = 50;
 int moth_high_range  = 120;

 int rs_low_range     = 60;
 int rs_high_range    = 130;

 int pc_low_range     = 60;
 int pc_high_range    = 130;

 int drs_low_range    = 100;
 int drs_high_range   = 200;
 
 for (int i = 0; i < ACTUATOR_ARR_SIZE; i++)
  {
    if (node.my_moths[i].installed) {
        if(random(1, 100) <= probability_mo && !node.my_moths[i].is_fading) {
        node.my_moths[i].fade(random(moth_low_range, moth_high_range), random(250, 4000));  // trigger a random fade
        } else {
        if(!node.my_moths[i].is_fading) node.my_moths[i].fade(0, 1500);   // fade out effect if not already fading.
        }
    }
    if (node.my_rebel_stars[i].installed)
        if(random(1, 100) <= probability_rs && !node.my_rebel_stars[i].is_fading) {
        node.my_rebel_stars[i].fade(random(rs_low_range, rs_high_range), random(250, 4000));  // trigger a random fade btw 1/4s and 4s
        } else {
        if(!node.my_rebel_stars[i].is_fading) node.my_rebel_stars[i].fade(0, 1500);   // fade out effect if not already fading.
        }

    if (node.my_protocells[i].installed)
        if(random(1, 100) <= probability_pc && !node.my_protocells[i].is_fading) {
        node.my_protocells[i].fade(random(pc_low_range, pc_high_range), random(250, 4000));  // trigger a random fade btw 1/4s and 4s
        } else {
        if(!node.my_protocells[i].is_fading) node.my_protocells[i].fade(0, 1500);   // fade out effect if not already fading.
        }
  }

  for (int i = 0; i < DR_ARR_SIZE; i++)
  {
    if (node.my_double_rebel_stars[i].installed)
        if(random(1, 100) <= probability_drs && !node.my_double_rebel_stars[i].is_fading) {
        node.my_double_rebel_stars[i].fade_extra(random(drs_low_range, drs_high_range), random(250, 4000), random(1,2));  // trigger a random fade btw 1/4s and 4s, randomly on tip or bulb
        } else {
          if(!node.my_double_rebel_stars[i].is_fading) {
            node.my_double_rebel_stars[i].fade_extra(0, 1500, 1);   // fade out effect if not already fading.
            node.my_double_rebel_stars[i].fade_extra(0, 1500, 2);   // fade out effect if not already fading.
          }
        }
  }

}

/*  *\fn fade_out_actuators()
 * 
 * if we are orphaned from our PI, shut down the actuators I can still control 
 */

void fade_out_actuators() { 
  
    for (int i = 0; i < ACTUATOR_ARR_SIZE; i++)  {   
    
    if (node.my_moths[i].installed && !node.my_moths[i].is_fading) {   
        node.my_moths[i].fade_out(4000);
      }    
    if (node.my_rebel_stars[i].installed && !node.my_rebel_stars[i].is_fading) {        
        node.my_rebel_stars[i].fade_out(4000);
      }  
    if (node.my_protocells[i].installed && !node.my_protocells[i].is_fading) {        
        node.my_protocells[i].fade_out(4000);
      }  
    }  
        
  for (int i = 0; i < DR_ARR_SIZE; i++)  {
    
      if (node.my_double_rebel_stars[i].installed  && !node.my_double_rebel_stars[i].is_fading )   {  
        node.my_double_rebel_stars[i].fade_out(4000);  // fade out over 4s    

      }
  }
}


void loop()
{
// in order to avoid having to pass Comms_Manager as a pointer, these functions mock node.update() and node.go()
  node_update();
  node_go();
}
