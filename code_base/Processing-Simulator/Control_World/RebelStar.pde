/*!
 <h1> RebelStar </h1>
 RebelStar object for visualization
 
 \author Matt Gorbet, Et al.
 
 */
class RebelStar extends Actuator {

  DInt cur_values = new DInt(); 

  RebelStar()
  {
    super();
  }

  synchronized void install(String n, PVector pos, int p, Node parent, DeviceIdentifier des)
  {
    des.device_friendly_type = "Rebel Star";
    super.install(n, pos, p, parent, des);
    virtual_width  = 50;
    virtual_height = 50;
    virtual_depth  = 2;   // not used yet
  }

  synchronized void update() {
    super.update();
    
    cur_values = update_DInt(cur_values);
    // cur_value = cur_values.state;
      
    cur_value = min(cur_values.max_value, (cur_values.state + int(cur_values.max_value * excitement_value)) );          // add excitement here.
    if(this.name.contains("P1:1_RS1")) {

    //  println("name: " + this.name + " cur_values.state is: " + cur_values.state + "  target value: " + cur_values.fade_target + " fade %: " + cur_values.fade_percent_done + "  excitement: " + excitement_value);

    }
  }

  void setValue(int v) {
     fade(v, 0);
  } 

  void fade(int v, long fade_millis)
  {
    cur_values = fade(v, fade_millis, cur_values);
  }

  boolean parse_config_string(String str)
  {
    return true;
  }

  synchronized void go() {

    super.go();
  }

  void update_info() {

    super.update_info();

    if (selected_actuator != null && selected_actuator == this) {
      if (gui.actuatorChart.getDataSet(name+"_value") == null) {
          gui.actuatorChart.addDataSet(name+"_value");
          for (int i = 0; i < gui.actuatorChart.getWidth() ; i++) {
            gui.actuatorChart.push(name+"_value", 0);
          }
      }
      gui.actuatorChart.push(name+"_value", cur_value); 

        int queuesize = -1;
        if (network.virtual_message_map.get(str(this.parent.node_id)) != null) {
          queuesize = network.virtual_message_map.get(str(this.parent.node_id)).size();
        }
        gui.actuatorChart.setCaptionLabel(name + "  NODE ID: " + this.parent.node_id + " QUEUE: " + queuesize);

      
    }
    else {
      gui.actuatorChart.removeDataSet(name+"_value"); 
    }
  } 

  void draw_me(boolean mouseover) {

  int lostalpha = 255;
  RPi parent_pi = dl.find_nodes_parent_rpi(this.parent.node_id);

  if( monitor.lost_devices.contains(parent_pi.my_address) || monitor.lost_devices.contains(str(this.parent.node_id)) ) {

   lostalpha = 70;

  }

    fill(map(cur_value, 0, 255, 0, 255),  // red   (slightly higher, to simulate LED)
         map(cur_value, 0, 255, 0, 255),  // green (slightly higher, to simulate LED)
         map(cur_value, 0, 255, 0, 210),  // blue
         lostalpha); 

    stroke(map(cur_value, 0, 255, 0, 255),  // red   (slightly higher, to simulate LED)
           map(cur_value, 0, 255, 0, 255),  // green (slightly higher, to simulate LED)
           map(cur_value, 0, 255, 0, 210),  // blue
           lostalpha); 

    
    if (mouseover || (selected_actuator != null && selected_actuator.designator.device_type.equals("RS") && (selected_actuator == this || this.parent.node_id == selected_node || selected_node == ALL_NODES_SELECTED ) && drawgui) ) { 
      stroke(192, 150, 0, lostalpha);
      
      if(selected_actuator == this)      
      stroke(255, 200, 0, lostalpha);

      if (mouseover) {
        fill(255, 200, 0, lostalpha);
      }
    }

    ellipse(0, 0, virtual_width, virtual_height);
  }
}
