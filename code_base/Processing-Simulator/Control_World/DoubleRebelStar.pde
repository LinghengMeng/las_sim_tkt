
/*!
 <h1> DoubleRebelStar </h1>
 Double Rebel Star object for visualization
 
 \author Matt Gorbet, Et al.
 
 */

 
class DoubleRebelStar extends Actuator   

{

// MODE definitions

  final int BOTH             = (int)0x3b;
  final int TIP_ONLY         = (int)0x3c;
  final int BULB_ONLY        = (int)0x3d;
  final int TIP_HALF_BULB    = (int)0x3e;
  final int BULB_HALF_TIP    = (int)0x3f;
  final int CHARGE_DISCHARGE = (int)0x40;
  final int OSCILLATE        = (int)0x41;


  float charge = 0f;

  int top_pin = 0;
  DInt top_values = new DInt();

  int bottom_pin = 0;
  DInt bottom_values = new DInt();

  DInt discharge = new DInt();

  int top_value = 0;
  int bottom_value = 0;

  int mode = BOTH;
  
  long elapsed_millis = 0;
  long last_millis;
  int  bottom_lag = 500;

  long last_follower_millis;
  long follower_update_rate = 25;

  long offset = 0;
  boolean invert = false;


  DoubleRebelStar()
  {
    super();
  } 

  void install(String n, PVector pos, int pin, Node parent_, DeviceIdentifier des)
  {
    des.device_friendly_type = "Double Rebel Star";
    super.install(n, pos, pin, parent_, des);
    top_pin = pin;

    top_values.state = 0;
    top_values.fade_target = 0;
    bottom_values.state = 0;
    bottom_values.fade_target = 0;

    parse_config_string(des.config);
    virtual_width  = 50;
    virtual_height = 200;
    virtual_depth  = 2;

    last_millis = millis();
    last_follower_millis = millis();

  }


  void setValue(int v)
  {
    fade(v, 0);
  }

  void fade(int v, long fade_millis)
  {
    top_values    = fade(v, fade_millis, top_values);
  }

  void fade_extra(int v, long fade_millis, int which) 
  {
   DInt which_values = top_values;

   if (which == 2) which_values = bottom_values;

   fade(v, fade_millis, which_values);   

  }

  synchronized void update()
  {
    super.update();  // update excitement levels, etc.

    elapsed_millis = millis() - last_millis;

    top_values =    update_DInt(top_values);       // update any fades that are going on for top
    bottom_values = update_DInt(bottom_values);    // update any fades that are going on for bottom
    discharge = update_DInt(discharge); // update the discharge DInt for discharge mode.
   
    // superposition of the fade_acutator_groups messages and the calculated excitement value.
    top_value    = min(top_values.max_value,    (top_values.state    + int(top_values.max_value    * excitement_value)) );          // add excitement here.

    switch(mode) {
  
      case TIP_ONLY:  // tip only
        bottom_value = 0;
      break;

      case BULB_ONLY:  // bulb only
        bottom_value = top_value;
        top_value = 0;
      break;

      case TIP_HALF_BULB:  // tip half bulb
        bottom_value = top_value/2;
      break;

      case BULB_HALF_TIP:  // bulb half tip
        bottom_value = top_value;
        top_value = top_value / 2;
      break;

      case CHARGE_DISCHARGE:  // charge discharge
//      charge = ((charge + top_values.max_value * excitement_value * 0.01) *= excitement_attenuation);
      charge = (charge + (top_value * 0.01)) * excitement_attenuation;
      bottom_value = int(charge);
      top_value = discharge.state;

      if(charge >= float(top_values.max_value)) {   // discharge
          charge = 0;
          discharge = fade(top_values.max_value, 0, discharge);
          discharge = update_DInt(discharge);
          discharge = fade(0, 350, discharge);
      }

      break;


      case OSCILLATE: //oscillate
      case BOTH:  // with offset;
      if( abs(offset) < 20 ) {
        bottom_value = top_value;
        break;
      }

      if( (millis()-last_follower_millis > follower_update_rate) ) {
        network.write_message("/NODE/DELAY_MESSAGE/" + str(parent.node_id) + "/" + "T" + offset + " " + designator.device_type + (designator.device_number+1) + " " + top_value);
        last_follower_millis = millis();
      }

      bottom_value = int(bottom_values.state * excitement_attenuation);
      break;
    }

  }

  void follow_to(int target) {

     bottom_values = fade(target, follower_update_rate, bottom_values);

  }

  void go()
  {
    super.go();
  }

  void set_mode(int mode_code) {

     mode = mode_code;
     
   
  }


  // override set_influence_map to save mode, offset and invert values as well:



  synchronized void set_influence_map_json(JSONObject act_inf_map) {

    super.set_influence_map_json(act_inf_map);

    // since it is a double rebel star, also set the mode and offset:
    try {
      set_a_drs_mode(this, (act_inf_map.getInt("mode") - (int)0x3b)); // radio buttons are a zero-index list, mode codes start at 0x3b 
      set_a_drs_offset(this, (int)(act_inf_map.getLong("offset")) * (act_inf_map.getBoolean("invert") ? -1 : 1));
    } catch (Exception e) {
      println(" Exception getting DRS mode and offset values: " + e);
    }


  }

  // override get_influence_map to save mode, offset and invert values as well:

  synchronized JSONObject get_influence_map_json() {

    JSONObject inf_map = new JSONObject();
    String inf_name = "";

    try {
      for(Map.Entry<String, InfluenceStorage> e : current_influences.entrySet()) {
        inf_name = e.getKey();
        JSONObject inf_settings = e.getValue().get_inf_settings_json();

        inf_map.setJSONObject(inf_name, inf_settings);
      }
 
      // for DRS, add mode and offset info:
      
      inf_map.setInt("mode", mode);
      inf_map.setLong("offset", offset);
      inf_map.setBoolean("invert", invert);

    } 
    catch(Exception e) {
      println(e);
    }

    return inf_map;
  }


  boolean parse_config_string(String config)
  {
    // println(" DR " + name + " got config string " + config);
    int num_commands = get_num_commands(config);
    boolean success = true;
    for (int i = 0; i < num_commands; i++)
    {
      String[] command = get_command(config, i);
      if (command[0].length() != 0)
      {

        success = configure_dr(command);

      }

    }
    return success;
  }


  boolean configure_dr(String[] params) {

      String argument = params[0];

      boolean success = true;

        if (argument.equals("BOTTOMPIN"))
        {
          int pin = int(params[1]);
          bottom_pin = pin;
        } else if (argument.equals("INVERT"))
        {
          invert = (params[1].equals("TRUE") || params[1].equals("true"));
          // println("Setting invert to " + invert + " for " + name);
        } else if (argument.equals("MODE")) {

          int mode_code = CODE__DR_MODE_BOTH;

          switch(params[1]) {
  
               case "BOTH":
               mode_code = int(CODE__DR_MODE_BOTH);
                 
               break;
               case "TIP_ONLY":
               mode_code = int(CODE__DR_MODE_TIP_ONLY);
     
               break;
               case "BULB_ONLY":
               mode_code = int(CODE__DR_MODE_BULB_ONLY);
     
               break;
               case "TIP_HALF_BULB":
               mode_code = int(CODE__DR_MODE_TIP_HALF_BULB);
     
               break;
               case "BULB_HALF_TIP":
               mode_code = int(CODE__DR_MODE_BULB_HALF_TIP);
     
               break;
               case "CHARGE_DISCHARGE":
               mode_code = int(CODE__DR_MODE_CHARGE_DISCHARGE);
     
               break;
               case "OSCILLATE":
               mode_code = int(CODE__DR_MODE_OSCILLATE);
               break;
     
               default:
               mode_code = int(CODE__DR_MODE_BOTH);
     
            }

            set_mode(mode_code);

        } else if (argument.equals("OFFSET")) {
          offset = int(params[1]);
        } else  
        {
          success = false;
        }


    return success;
  }

  void update_info() {

    super.update_info();

    if (selected_actuator != null && selected_actuator == this) {
      if (gui.actuatorChart.getDataSet(name+"_value_top") == null) {
          gui.actuatorChart.addDataSet(name+"_value_top");
          for (int i = 0; i < gui.actuatorChart.getWidth() ; i++) {
            gui.actuatorChart.push(name+"_value_top", 0);
          }
      }
      if (gui.actuatorChart.getDataSet(name+"_value_bot") == null) {
          gui.actuatorChart.addDataSet(name+"_value_bot");
          for (int i = 0; i < gui.actuatorChart.getWidth() ; i++) {
            gui.actuatorChart.push(name+"_value_bot", 0);
          }
      }
      gui.actuatorChart.push(name+"_value_top", top_value); 
      gui.actuatorChart.push(name+"_value_bot", bottom_value); 

        int queuesize = -1;
        if (network.virtual_message_map.get(str(this.parent.node_id)) != null) {
          queuesize = network.virtual_message_map.get(str(this.parent.node_id)).size();
        }
        gui.actuatorChart.setCaptionLabel(name + (use_sai? " (SAI)" : "") +  "  NODE ID: " + this.parent.node_id + " QUEUE: " + queuesize);



      if(!gui.drs_mode.isVisible()) {

          gui.drs_mode.show();
          gui.drs_mode.setValue(mode);

          gui.drs_offset.show();
          gui.drs_reset_offset.show();
          int neg = 1;
          if(invert) neg = -1;
          gui.drs_offset.setValue(abs(offset/1000.) * neg);

      }
      
    }
    else {
      gui.actuatorChart.removeDataSet(name+"_value_top"); 
      gui.actuatorChart.removeDataSet(name+"_value_bot");       
    }
  } 


  void draw_me(boolean mouseover) {

  int lostalpha = 255;
  RPi parent_pi = dl.find_nodes_parent_rpi(this.parent.node_id);

  if( monitor.lost_devices.contains(parent_pi.my_address) || monitor.lost_devices.contains(str(this.parent.node_id)) ) {

   lostalpha = 70;

  }

   if(invert) {
      int temp_value = bottom_value;
      bottom_value   = top_value;
      top_value      = temp_value;
   }

    
    fill(map(top_value, 0, 255, 0, 255),  // red   (slightly higher, to simulate LED)
         map(top_value, 0, 255, 0, 255),  // green (slightly higher, to simulate LED)
         map(top_value, 0, 255, 0, 210),  // blue
         lostalpha); 

    stroke(map(top_value, 0, 255, 0, 255),  // red   (slightly higher, to simulate LED)
           map(top_value, 0, 255, 0, 255),  // green (slightly higher, to simulate LED)
           map(top_value, 0, 255, 0, 210),  // blue
           lostalpha); 
    //fill(top_value);
    //stroke(top_value);
    ellipse(0, -virtual_height/4, virtual_width/2, virtual_height*.75); 

    fill(map(bottom_value, 0, 255, 0, 255),  // red   (slightly higher, to simulate LED)
         map(bottom_value, 0, 255, 0, 255),  // green (slightly higher, to simulate LED)
         map(bottom_value, 0, 255, 0, 210),  // blue
         lostalpha); 
    stroke(map(bottom_value, 0, 255, 0, 255),  // red   (slightly higher, to simulate LED)
           map(bottom_value, 0, 255, 0, 255),  // green (slightly higher, to simulate LED)
           map(bottom_value, 0, 255, 0, 210),  // blue
           lostalpha); 
    //fill(bottom_value);
    //stroke(bottom_value);
    ellipse(0, virtual_height/4, virtual_width, virtual_width);

    if (mouseover || (selected_actuator != null && selected_actuator.designator.device_type.equals("DR") && (selected_actuator == this || this.parent.node_id == selected_node || selected_node == ALL_NODES_SELECTED ) && drawgui) ) { 
      stroke(255, 200, 0, min(100, lostalpha)); 
      
      if(selected_actuator == this) 
      stroke(255, 200, 0, lostalpha);
 
      if (mouseover) {
        fill(255, 200, 0, lostalpha);
      } else { 
        noFill(); 
      }
      
        ellipse(0, -virtual_height/4, virtual_width/2, virtual_height*.75); 
        ellipse(0, virtual_height/4, virtual_width, virtual_width);
        
    }

  }

  // overriding for double rebel stars to accommodate both pins:
  OscMessage add_raw_output(OscMessage m) {

         float top_output =  top_value/255.0;
         float bottom_output =  bottom_value/255.0;
         m.add(top_pin);           // add int for pin number
         m.add(top_output);        // add float 0.0 - 1.0 for current level
         m.add(bottom_pin);           // add int for pin number
         m.add(bottom_output);        // add float 0.0 - 1.0 for current level

    return(m);
  }
}
