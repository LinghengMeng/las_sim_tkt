/*!
* <h1> Sensor </h1>
*  C++ Sensor Object
*
*  \author Farhan Monower et al
*/
#pragma once

#include <Arduino.h>
#include "DeviceIdentifier.h"

/*!
* \class Sensor
* \brief the C++ Sensor object
*/
class Sensor {

protected:
    /*!
    * \var CONFIG_DELIMITER
    * delimiter used in configuration strings
    */
    const char CONFIG_DELIMITER = ';';
    /*!
    * \fn get_num_commands(String str)
    * \brief gets the number of commands in the config string
    * \param str the config string
    * \return the number of commands
    */
    int get_num_commands(String str);
    /*!
    * \fn are_arguments(String command_)
    * \brief checks if the provided command has any arguments
    * \param command_ the command to check
    * \return true if argument is present, false if not
    */
    bool are_arguments(String command_);
    /*!
    * \fn get_command(String str, int num)
    * \brief get the command from the provided config string at a certain index
    * \param str the config string
    * \param num the index of the command to get back
    * \return the command string
    */
    String get_command(String str, int num);
    /*!
    * \fn get_keyword(String command_)
    * \brief gets the keyword from a command_
    * \param command_ the command string
    * \return the keyword string
    */
    String get_keyword(String command_);
    /*!
    * \fn get_arguments(String command_)
    * \brief gets the arguments from a command string
    * \param command_ the command string
    * \return the argument string
    */
    String get_arguments(String command_);

  public:
    /*!
    * \var name
    * the name of this sensor
    */
    String name;
    /*!
    * \var cur_value
    * current value stored in sensor
    */
    float cur_value;
    /*!
    * \var uid
    * the unique identifier of the sensor
    */
    int uid;

    /*!
    * \var installed
    * is the sensor installed? true if yes, false if no
    */
    bool installed = false;
    /*!
    * \var designator
    * Used to store the 2 character and 1 integer identifier for the sensor e.g. SD1
    */
    DeviceIdentifier designator;


    byte * parent_debug_bytes ; // pointer to dbug bytes array
    void set_debug_bytes(uint8_t * db);

    /*!
    * \fn Sensor()
    * \brief the sensor constructor
    * \return none
    */
    Sensor();
    /*!
    * \fn ~Sensor()
    * \brief the sensor destructor
    * \return none
    */
    ~Sensor();
    /*!
    * \fn read_value()
    * \brief reads the sensor. Virtual is the C++ equivalent of abstract
    * \return the int value of the sensor (typically 0-1024)
    */
    virtual int read_value() = 0;
    /*!
    * \fn parse_config_string(String config_string)
    * \brief parses the configuration string, virtual and must be elaborated in children classes
    * \param config_string the config string
    * \return true or false if the string was parsed
    */
    virtual bool parse_config_string(String config_string) = 0;
    /*!
    * \fn install(String n, int p, DeviceIdentifier des)
    * \brief used to install the constructor and initialize it
    * \param n the name of the actuator
    * \param p the uid
    * \param des the designator
    * \return none
    */
    void install(String n, int p, DeviceIdentifier des);
    /*!
    * \fn update()
    * \brief the update loop, used for time sensitive activities
    * \return none
    */
    void update();
    
};
