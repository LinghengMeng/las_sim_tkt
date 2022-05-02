#include "Sensor.h"

Sensor::Sensor() {
  name = "";
  uid = 0;
  installed = false;
}

Sensor::~Sensor() {

}

void Sensor::install(String n, int p, DeviceIdentifier des) {
  name = n;
  uid = p;
  pinMode(uid, INPUT);
  cur_value = 0;
  designator = des;
  installed = true;
}

void Sensor::update() {
  //do something
}

void Sensor::set_debug_bytes(uint8_t * db) {

  parent_debug_bytes = db;

}

int Sensor::get_num_commands(String str) {
  int num_commands = 0;
  for (int i = 0; i < str.length(); i++)
  {
    if (str.charAt(i) == CONFIG_DELIMITER)
      num_commands++;
  }
  return num_commands;
}


bool Sensor::are_arguments(String command_) {
  if (command_.indexOf(" ") < 0)
    return false;
  return true;
}


String Sensor::get_command(String str, int num) {
  int num_delimiters = 0;
  int last_delimiter_index = 0;
  for (int i = 0; i < str.length(); i++)
  {
    if (str.charAt(i) == CONFIG_DELIMITER)
    {
      num_delimiters++;
    }

    if (num_delimiters == num + 1)
    {
      if (num == 0)
        return str.substring(last_delimiter_index, i);
      return str.substring(last_delimiter_index + 1, i);
    }

    if (str.charAt(i) == CONFIG_DELIMITER)
    {
      last_delimiter_index = i;
    }
  }

  return "";
}

String Sensor::get_keyword(String command_) {
  int keyword_end_index = 0;
  //  bool argument = true;

  if (command_.indexOf(" ") > 0)
    keyword_end_index = command_.indexOf(" ");
  else if (command_.indexOf(";") > 0) {
    keyword_end_index = command_.indexOf(";");
  }
  else if (command_.charAt(command_.length() - 1) != ' ' && command_.charAt(command_.length() - 1) != ';') {
    keyword_end_index = command_.length();
  }

  return command_.substring(0, keyword_end_index);
}

String Sensor::get_arguments(String command_) {
  if (are_arguments(command_))
    return command_.substring(command_.indexOf(" ") + 1, command_.length());
  return "";
}
