/*!
 <h1> Moth </h1>
 Moth object for visualization
 
 \author Matt Gorbet, Et al.
 
 */


class Moth extends Actuator {  

  DInt cur_values = new DInt(200);

  Moth()
  {
    super();
  }

  synchronized void install(String n, PVector pos, int p, Node parent, DeviceIdentifier des)
  {
    des.device_friendly_type = "Moth";
    super.install(n, pos, p, parent, des);

    virtual_width = 60;
    virtual_height = 220;
    virtual_depth = 2;   // not used yet
  }

  synchronized void update() {
    super.update();
    cur_values = update_DInt(cur_values);
    cur_value = min(cur_values.max_value, (cur_values.state + int(cur_values.max_value * excitement_value)) );          // add excitement here.
  }


  void setValue(int v) {
    cur_values = fade((min(v, cur_values.max_value)), 0, cur_values);
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

    draw_to_screen();
  }

  
  void update_info() {

    super.update_info();

    if (selected_actuator != null && selected_actuator == this) {
    //  if(gui.actuator_settings != null && !gui.actuator_settings.isVisible()) {
    //     gui.actuator_settings.show();
    //     gui.influence_settings.show();
    //     gui.influence_settings.open();
    //     apply_actuator_settings_to( int(gui.which_actuators.getValue()) );
    //     set_which_influence(int(gui.which_influence.getValue()));
    //     gui.which_actuators.getItem(0).setCaptionLabel(" This Moth");
    //     gui.which_actuators.getItem(1).setCaptionLabel(" This Moth Group");
    //     gui.which_actuators.getItem(2).setCaptionLabel(" All Moths");
    //    // apply_moth_settings_to( int(gui.which_moths.getValue()) );
    //  }

          if (gui.actuatorChart.getDataSet("actuator_values") == null) {
          gui.actuatorChart.addDataSet("actuator_values");
           for (int i = 0; i < gui.actuatorChart.getWidth() ; i++) {
            gui.actuatorChart.push("actuator_values", 0);
          }
      }
      gui.actuatorChart.push("actuator_values", min(cur_value, 255)); 


        int queuesize = -1;
        if (network.virtual_message_map.get(str(this.parent.node_id)) != null) {
          queuesize = network.virtual_message_map.get(str(this.parent.node_id)).size();
        }
        gui.actuatorChart.setCaptionLabel(name + "  NODE ID: " + this.parent.node_id + " QUEUE: " + queuesize + " InfRate: " + control.influence_frame_time);

    }
  } 

  void draw_me(boolean mouseover) {

  int lostalpha = 255;
  RPi parent_pi = dl.find_nodes_parent_rpi(this.parent.node_id);

  if( monitor.lost_devices.contains(parent_pi.my_address) || monitor.lost_devices.contains(str(this.parent.node_id)) ) {

   lostalpha = 70;

  }

    fill(map(cur_value, 0, 200, 128, 200),  // red
         map(cur_value, 0, 200, 128, 200),  // green
         map(cur_value, 0, 200, 128, 255), // blue (slightly higher, to simulate LED)
         lostalpha);
    stroke(map(cur_value, 0, 200, 128, 200),  // red
         map(cur_value, 0, 200, 128, 200),  // green
         map(cur_value, 0, 200, 128, 255), // blue (slightly higher, to simulate LED)
         lostalpha);
    
    if (mouseover || (selected_actuator != null && selected_actuator.designator.device_type.equals("MO") && (selected_actuator == this || this.parent.node_id == selected_node || selected_node == ALL_NODES_SELECTED ) && drawgui) ) { 
      stroke(255, 200, 0, min(100, lostalpha)); 
      
      if(selected_actuator == this) 
      stroke(255, 200, 0, lostalpha);

      if (mouseover) {
        fill(255, 200, 0, lostalpha);
      }
    }

    rotateZ((PI/6f*(0.01+(-0.5+noise(get_frame()*uid)) * cur_value/255f)));     // rotate it up to +/- 9 degrees 
    moth_star(0, 0, virtual_width/2, virtual_height/2, 28);
  }


  // === helper to draw the moth shape

  void moth_star(float x, float y, float radius1, float radius2, int npoints) {
    float angle = TWO_PI / npoints;
    float halfAngle = angle/2.0;
    float lasta = 0;

    float vibrate = 0; 

    beginShape();
    for (float a = -PI/4; a <= PI+PI/4; a += angle) {
      if (a > -PI/4) vibrate = PI/10f*((-0.5+noise(get_frame()*a)) * cur_value/255f);  // up to +/- 9 degrees, but don't vibrate first point
      float sx = (x + cos(a+vibrate) * radius2) * (radius1/radius2);
      float sy =  y + sin(a+vibrate) * radius2;
      vertex(sx, sy);
      sx = (x + cos(a+halfAngle) * radius1) * (radius1/radius2);
      sy =  y + sin(a+halfAngle) * radius1;
      vertex(sx, sy);

      lasta = a;
    }
    // last inside point
    lasta += angle;
    float sx = (x + cos(lasta) * radius2) * (radius1/radius2);
    float sy = y + sin(lasta) * radius2;
    vertex(sx, sy);

    endShape(CLOSE);
  }
}
