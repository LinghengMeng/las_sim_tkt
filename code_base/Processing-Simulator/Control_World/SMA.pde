/*!
 <h1> SMA </h1>
 SMA object for visualization
 
 \author Sophia Rahn, Et al.
 
 */


class SMA extends Actuator {  

  final int MIN_SM = 127;
  DInt cur_values = new DInt(200);
  int cur_sma_time;
  
  static final int READY = 0;
  static final int HEATING = 1;
  static final int COOLING = 2;
  int SM_state = READY;
  int time_at_phase_shift = 0;
  int heat_time = 1800;
  int cool_time = 15000;

  SMA()
  {
    super();
  }

  synchronized void install(String n, PVector pos, int p, Node parent_, DeviceIdentifier des)
  {
    des.device_friendly_type = "SMA";
    super.install(n, pos, p, parent_, des); // not sure on any of these settings
    
    virtual_width = 15;
    virtual_height = 100;
    virtual_depth = 2;   // not used yet

    Random r = new Random();
    float lr = r.nextFloat()*0.15 + .6;

    enable_influence("IR");
    set_low_range("IR", lr);
    set_high_range("IR", lr+0.1);
  }

  synchronized void update() {
    super.update();
    cur_values = update_DInt(cur_values);
    cur_value = min(cur_values.max_value, (cur_values.state + int(cur_values.max_value * excitement_value)) );          // add excitement here.
    
    //SMA will only be given values of 255 or 0 (best to mitigate fatigue failure) based on passing the threshold given
    if (cur_value >= MIN_SM){
      if (SM_state == READY) {  
          cur_value = 255;
          SM_state = HEATING;
          time_at_phase_shift = millis();
      }
      else {
       cur_value = 0;   // force to zero because not ready
//     setValue(0);
      }
    }
      else {
        cur_value = 0;  // lower than threshold
    }
  
    State_and_Target_setting(); //setting states based on time 
  }


  void setValue(int v) {
    fade(v, 0);
  }

  void fade(int v, long fade_millis)
  {
    cur_values = fade(v, fade_millis, cur_values);
  }

  void trigger(int delay_time) 
  {

    if(SM_state != READY) return;

    // send trigger pulse
     network.write_message("/NODE/DELAY_MESSAGE/" + str(parent.node_id) + "/" + "T" + delay_time + " SM" + (designator.device_number+1) + " 255");
    // turn off pulse 500ms after (SMA will do its own profile, but we need to make sure fade is off so it doesn't retrigger)
     network.write_message("/NODE/DELAY_MESSAGE/" + str(parent.node_id) + "/" + "T" + (delay_time+200) + " SM" + (designator.device_number+1) + " 0");


  }


  void State_and_Target_setting(){
    // notes the current elapsed time
    cur_sma_time = millis();
  
    if (SM_state == HEATING && cur_sma_time < (time_at_phase_shift + heat_time)){
      // keep heating
      cur_value = 255;
    }
     
    else if (SM_state == HEATING && cur_sma_time >= (time_at_phase_shift + heat_time)){
      // stop heating, then enter "cooldown" mode so it cannot be turned back on until the cooldown is complete
      cur_value = 0;
      SM_state = COOLING;
      time_at_phase_shift = millis();
    }
      
    //If the SMA has been in "cooldown" mode for long enough, it is now available to actuate once again
    else if (SM_state == COOLING && cur_sma_time >= (time_at_phase_shift + cool_time)){
      SM_state = READY;
    }
 
    //If the SMA has not been in cool down for long enough, cur_value is set to 0
    //In the case of SM_state being recently set to "cooldown" by completing it's heat cycle this is technically redundant
    //However this function is still neccessary for continued cool down. Switching to else if might fix redundancy
    else if (SM_state == COOLING && cur_sma_time < (time_at_phase_shift + cool_time)){
    cur_value = 0;
    }
  }


  boolean parse_config_string(String str)
  {
    return true;
  }


  synchronized void go() {
    draw_to_screen();
  }

  
  void update_info() {

    super.update_info();
    if (selected_actuator != null && selected_actuator == this) {
      if (gui.actuatorChart.getDataSet(name+"actuator_influences") == null) {
          gui.actuatorChart.addDataSet(name+"actuator_influences");
          gui.actuatorChart.setColors(name+"actuator_influences", color(70, 70, 160));  
      }


      if (gui.actuatorChart.getDataSet("actuator_values") == null) {
          gui.actuatorChart.addDataSet("actuator_values");
          for (int i = 0; i < gui.actuatorChart.getWidth() ; i++) {
            gui.actuatorChart.push("actuator_values", 0);
            gui.actuatorChart.push(name+"actuator_influences", 0);
          }
      }
      gui.actuatorChart.push("actuator_values", min(cur_value, 255)); // this used to be min(cur_value, max_value), but we dont have access to max_value anymore
      gui.actuatorChart.push(name+"actuator_influences", min(cur_values.max_value, (cur_values.state + int(cur_values.max_value * excitement_value)) ));
     gui.actuatorChart.setCaptionLabel(name + "  NODE ID: " + this.parent.node_id + " State: " + SM_state);
   
    } else {
      gui.actuatorChart.removeDataSet(name+"actuator_influences");  
    }

  } 

  void draw_me(boolean mouseover) {

    fill(map(cur_value, 0, 255, 0, 255),  // red   (slightly higher, to simulate LED)
           map(cur_value, 0, 255, 0, 255),  // green (slightly higher, to simulate LED)
           map(cur_value, 0, 255, 0, 210)); // blue
    stroke(map(cur_value, 0, 255, 0, 255),  // red   (slightly higher, to simulate LED)
           map(cur_value, 0, 255, 0, 255),  // green (slightly higher, to simulate LED)
           map(cur_value, 0, 255, 0, 210)); // blue 
//    ellipse(0, -virtual_height/4, virtual_width/2, virtual_height); 

    if (mouseover || (selected_actuator != null && selected_actuator.designator.device_type.equals("SM") && (selected_actuator == this || this.parent.node_id == selected_node || selected_node == ALL_NODES_SELECTED ) && drawgui) ) { 
      stroke(128, 100, 0);
      
      if(selected_actuator == this) 
      stroke(255, 200, 0);
 
      if (mouseover && selected_actuator != this) {
        fill(255, 200, 0);
      }              
    }
        rect(0, 0, virtual_width, virtual_height); 

  }
}