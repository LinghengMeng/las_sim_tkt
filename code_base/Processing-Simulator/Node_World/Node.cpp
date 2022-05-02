#include "Node.h"
#include "DeviceLocator.h"



Node::Node()
{

}

void Node::update()
{

}

void Node::go()
{
    
}

int Node::get_type(uint8_t pin) 
{
    return 0;
}

bool Node::isValid(int act_type, int act_num) {
    if (act_num < 0)
        return false;

    switch(act_type)
    {
        case type_SM:
            return act_num < ACTUATOR_ARR_SIZE;
        case type_RS:
            return act_num < ACTUATOR_ARR_SIZE;
        case type_PC:
            return act_num < ACTUATOR_ARR_SIZE;
        case type_MO:
            return act_num < ACTUATOR_ARR_SIZE;
        case type_DR:
            return act_num < DR_ARR_SIZE;
        case type_WT:
            return act_num < WT_ARR_SIZE;
        case type_SD:
            return act_num < SD_ARR_SIZE;
        case type_IR:
            return act_num < IR_ARR_SIZE;
        case type_GE:
            return act_num < GE_ARR_SIZE;
        default:
            return false;
    }

}
