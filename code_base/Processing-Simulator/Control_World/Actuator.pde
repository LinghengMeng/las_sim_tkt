/** \class Actuator Actuator.pde
 * \brief superclass for actuators, all actuators inherit from this. 
 * \author PBAI/LASG
 * \author Adam Francey
 * \author Matt Gorbet
 * \author Niel Mistry
 * \date February 20 2019
 * \todo { stop passing pin_mode - all actuator pins should be outputs anyway; change initialization to match C++ class }
 */


abstract class Actuator {
  static final char CONFIG_DELIMITER = ';';

  // keep these protected to control access!
  protected HashMap<String,InfluenceStorage> current_influences = new HashMap<String,InfluenceStorage>();
  

  String name;
  String config_string;
  DeviceIdentifier designator;
  int uid;
  int cur_value; 
  float excitement_value;
  float last_excitement_value;
  long last_excitement_change;
  float excitement_attenuation;

  boolean installed = false;
  boolean near = false;
  boolean attenuating = false;
  boolean new_influence_update = false;   // used to help determine if we should attenuate
  boolean use_sai = false; // treat this actuator as SAI-enabled? (Smart Actuator Interface)
  SAI my_sai = null;  
  float sai_in_value = 0.0;  // maps to excitement value if we are using SAI, so we can trigger on excitement
  
  long last_test_message;

  int   virtual_width;
  int   virtual_height;
  int   virtual_depth;
  float   pitch;
  float   yaw;
  float   roll;

  PVector    position;
  PVector    target;
  PVector    direction;
  Vec3D      posvec;
  Vec3D      targvec;
  Quaternion alignment;

  boolean is_fading = false; 
  boolean selected = false;



  Node parent; 
  
  /*! 
   * Default constructor, used to instantiate empty Actuator instances
   */
  Actuator()
  {
    name = "";
    position = new PVector(0.0, 0.0, 0.0);
    target   = new PVector(0.0, 0.0, 0.0);
   
    uid = 0;
    parent = null;
    designator = null;
    use_sai = false;
    my_sai = null;

    installed = false;

    last_excitement_change = tl_millis();
    last_test_message = tl_millis();
    excitement_attenuation = 1.0;
    attenuating = false;
  }

  /*!
   * Install function, used to initialize actuators. 
   * \param n Name of actuator
   * \param pos A vector describing this actuator's position
   * \param pin One of the pins on this actuator, this acts as a unique identifier for the actuator (a way to address it)
   * \param parent_ A node object that is this actuator's parent (what it's connected to)
   * \param des A DeviceIdentifier object that stores the two letter identifier and what # this actuator is. For example "MO" and 2
   */
  void install(String n, PVector pos, int pin, Node parent_, DeviceIdentifier des)
  {
    name = n;
    position = pos;

    //  GOING TO NEED TO USE QUATERNIONS HERE I THINK - to get the angles right.
     // target   =  ; //  stays 0, 0, 0 centerpoint for now -- later we'll read individual targets
     direction= PVector.sub(pos, target);
     pitch =  asin(direction.y / direction.mag());
     yaw   = -asin(direction.x / (cos(pitch)*direction.mag()) );
  
    uid = pin;
    parent = parent_;
    designator = des; 

    virtual_width = 100;
    virtual_depth = 100;
    virtual_height = 20;  // unused for now

    use_sai = des.use_sai;

    if(use_sai) {
      des.init_sai(this);
      if(des.actuator_sai != null) {
        my_sai = des.actuator_sai;
      }
    }

    installed = true;
  }

  /*! Required function that lets software set this actuator's value to something. Needs to be written for each actuator. 
   * \param v The target value to set to. 
   */
  abstract void setValue(int v);

  /*! Required function that lets software fade the value over time. Needs to be written for every actuator. 
   * \param v The value to fade to.
   * \param fade_millis The amount of time (ms) to reach value v.
   */
  abstract void fade(int v, long fade_millis);

  /*! 
   * A utility class that sets the value of a DInt (see DInt page for more information)
   * \param v The value to set to. 
   * \param cur_values The DInt to edit. 
   */
  DInt setValue(int v, DInt cur_values)
  {
    return fade(v, 0, cur_values);
  }

  /*! 
   * A utility class to fade a DInt over some time (see DInt page for more information about DInts)
   * \param v The value to fade to.
   * \param fade_millis The amount of time (ms) to reach value v. 
   * \param cur_values The DInt to edit. 
   */
  DInt fade(int v, long fade_millis, DInt cur_values) {

    last_excitement_change = tl_millis();

    // only reset percent_done if target has changed - to prevent asymptotic never getting to target;
    if(v != cur_values.fade_target) {
      cur_values.fade_percent_done = 0.0;
    }
      
    cur_values.fade_start    = cur_values.state;
    cur_values.fade_target   = v;
    cur_values.fade_duration = fade_millis;
    cur_values.last_millis   = tl_millis();

    if ( cur_values.state > cur_values.fade_target ) {

      cur_values.fade_delta = cur_values.state - cur_values.fade_target;
      cur_values.fade_direction = -1;
    } else {

      cur_values.fade_delta = cur_values.fade_target - cur_values.state;
      cur_values.fade_direction = 1;
    }

    is_fading = true;
    return cur_values;
  }

  /*!
   * A utility class to update a DInt's internal variables. This gets called every iteration. 
   * \param cur_values The DInt to update. 
   */
  DInt update_DInt(DInt cur_values) {

    cur_values.elapsed_millis = tl_millis() - cur_values.last_millis;
    if (cur_values.elapsed_millis < 0) { 
      cur_values.last_millis = tl_millis();
    }

    if (cur_values.fade_duration != 0) {

      if (cur_values.elapsed_millis > cur_values.fade_minimum_interval) {

        float percent  = (float) cur_values.elapsed_millis / (float) cur_values.fade_duration;
        cur_values.fade_percent_done += percent;

        cur_values.last_millis = tl_millis();
      }
    } else {   

      cur_values.fade_percent_done = 1.0;
      cur_values.last_millis = tl_millis();
      is_fading = false;
    }

    if (cur_values.fade_percent_done > 1.0)  {
      cur_values.fade_percent_done = 1.0;
      is_fading = false;
    }

    cur_values.state = cur_values.fade_start + (int)(cur_values.fade_delta * cur_values.fade_percent_done) * cur_values.fade_direction;

    //  some limits, just in case:
    if (cur_values.state < 0)           cur_values.state = 0;
    if (cur_values.state > cur_values.max_value)   cur_values.state = cur_values.max_value;

    cur_values.run_time = tl_millis() - cur_values.start_time;

    return cur_values;

    // println("... is " + cur_values.state);
  }

  synchronized JSONObject get_influence_map_json() {

    JSONObject inf_map = new JSONObject();
    String inf_name = "";

    try {
      for(Map.Entry<String, InfluenceStorage> e : current_influences.entrySet()) {
        inf_name = e.getKey();
        JSONObject inf_settings = e.getValue().get_inf_settings_json();

        inf_map.setJSONObject(inf_name, inf_settings);
      }
    } 
    catch(Exception e) {
      println(e);
    }

    return inf_map;
  }


  synchronized void set_influence_map_json(JSONObject act_inf_map) {

    // go through all the influences (n)
    String this_influence = "";

    for(int n = 0; n < gui.which_influence.getItems().size(); n++) {
      String nickname = String.valueOf(gui.which_influence.getItem(n).get("value"));
      if(!nickname.equals(str(n))) {   // if we have set a specific nickname for this
          this_influence = nickname;
      } else {
          this_influence = String.valueOf(gui.which_influence.getItem(n).get("text"));
      }

      if(this_influence.equals("SB")) continue; // sample behaviour - don't bother with it
      if(this_influence.equals("FF")) { this_influence.equals("GR"); }  // replace any errant FF with GR.

      JSONObject inf_settings = act_inf_map.getJSONObject(this_influence);  // get the settings for this inf

      if(inf_settings != null ) {   // if this influence is being set

         set_high_range(this_influence, inf_settings.getFloat("range_top"));
         set_low_range(this_influence, inf_settings.getFloat("range_bot"));
         if(inf_settings.getBoolean("active")) { enable_influence(this_influence);  }
         else                                  { disable_influence(this_influence); }

      } else {  
         // subscription not explicitly set in this file one way or the other, so leave as is (no action)
         // ... other option would be to remove, or disable, but that doesn't allow for additive sets.
         
      }   
    }
  }


  /*!
   * An update function that gets called every iteration. Manages influence superposition and updates Excitement values. 
     This is called by subclasses, but also specific updates are written for each actuator's unique behaviours
   */
   
  synchronized void update()
  {
    // update excitement values via superposition
    excitement_value = 0;

    try {
      for(InfluenceStorage infstor : current_influences.values())
      {
        if(infstor.active)  
        {
  //        excitement_value += infstor.current_influence;
            excitement_value += max(0f, map(infstor.current_influence, infstor.range_bot, infstor.range_top, 0.0, 1.0));
        }

        if(excitement_value > 1)
          excitement_value = 1.0;
      }
    } 
    catch(Exception e) {

      println(e);

    }

    // here is where we acclimatize if our excitement value stays constant for more than 5s:
    if(excitement_value != last_excitement_value || new_influence_update) {  // is the newly calculated value different from before? if not, have we been receiving updates?
       last_excitement_change = tl_millis();                                 // if yes to either, remember it's changed now
       new_influence_update = false;
    }

    if(tl_millis() - last_excitement_change > 5000) {                         // has it been over 5 seconds since it changed?
       attenuating = true;
       excitement_attenuation = 1.5-((tl_millis()-last_excitement_change)/10000.0);                                     // if so, change attenuation 99%
       if(excitement_attenuation < 0 ) { excitement_attenuation = 0.0; last_excitement_change = tl_millis()-15000;}
    } else {
       attenuating = false;
       excitement_attenuation = 1.0;                  
    }

    last_excitement_value = excitement_value;                              // remember this excitement value.
    excitement_value *= excitement_attenuation;                            // attenuate if necessary.


    if(use_sai && my_sai != null) {
      sai_in_value = excitement_value;
      my_sai.update();
    }
  }


  /*! 
   * The go function gets called every iteration to update the drawing on the screen. This also needs to be written for every Actuator sub-class to provide 
   * Actuator specific behaviour. 
   */

  synchronized void go() {

    draw_to_screen();
  }

  /*! 
   * @MATT - TODO
   */
  synchronized void draw_to_screen() {

    // use value to set screen colour
    stroke(0);
    if (selected_actuator != null && selected_actuator == this && drawgui) { 
      // draw indicator line  

      float sx = screenX((position.x), (position.y), position.z) + 0;
      float sy = screenY((position.x), (position.y), position.z) - 0;

      cam.beginHUD();
      stroke(0, 100);
      line( sx, sy, gui.actuatorChart.getPosition()[0], gui.actuatorChart.getPosition()[1]+gui.actuatorChart.getHeight() + 10 ); 
      cam.endHUD();

      // set highlight  

      stroke(255, 200, 0);
    }

    // fill(cur_value);

    // if SAI, draw a link between it and any children
    if (use_sai) {
          noFill();
      stroke(255, 100, 100, 60);
      strokeWeight(3);
      for(String n : my_sai.next_actuators) {
         for(PVector child_coords : (dl.get_actuator_coordinates_by_name(n)).values()) {  // should only return one set of coords - not the most efficient way to do this!
         // line(0, 0, 0, child_coords.x-this.position.x, child_coords.y-this.position.y, child_coords.z-this.position.z);
         // line(0, 0, 0, child_coords.x, child_coords.y, child_coords.z);
         // line(this.position.x, this.position.y, this.position.z, child_coords.x, child_coords.y, child_coords.z);
         // bezier(this.fv.x, this.fv.y, (this.fv.x + this.tv.x)/2, this.fv.y, (this.fv.x + this.tv.x)/2, this.tv.y, this.tv.x, this.tv.y);
         bezier(  this.position.x, this.position.y, this.position.z, 
                  (this.position.x + child_coords.x) / 2, this.position.y, this.position.z,
                  (this.position.x + child_coords.x) / 2, child_coords.y, child_coords.z,
                  child_coords.x, child_coords.y, child_coords.z  );
 
         }
      }
      strokeWeight(1);
    }

    pushMatrix();

    // line(position.x, position.y, position.z, target.x, target.y, target.z);

    translate(position.x, position.y, position.z);

    // rotateZ(frame/200.);  // test to watch how it behaves around its axes
  
    if (billboard_mode == 1) {          // face camera
      rotateX(cam.getRotations()[0]);
      rotateY(cam.getRotations()[1]);
      rotateZ(cam.getRotations()[2]);
    } else if (billboard_mode == 2) {   // face center of sphere
      // GOING TO NEED TO IMPLEMENT QUATERNIONS TO GET THESE
      rotateX(this.pitch);
      rotateY(this.yaw);
      rotateZ(this.roll);
    }
     
    if (test_current_actuator && is_mouse_near(actuator_test_distance) && (this.designator.device_type.equals(actuator_test_type) || actuator_test_type.equals("ALL")) ) {
      actuators_to_test.add(this);
      this.near = true;
    } else {
      this.near = false;
    }// NOTE removal happens with same check, in the test code to avoid concurrent modification (will this work?)

    // also add actuators_to_test from paintbrush.
    if (paintbrush_osc && is_paintbrush_near() && (this.designator.device_type.equals(actuator_test_type) || actuator_test_type.equals("ALL")) ) {
      actuators_to_test.add(this);
    }

 
    // if using SAI, draw a red highlight
    if (use_sai) {
      fill (255, 100, 100, 30);
      noStroke();
      ellipse(0, 0, virtual_width*1.2, virtual_width*1.2);
    }


    if (is_mouse_over()) {
      over_actuator = this;
      
      if (select_item == true) {
        selected_actuator = this;
        select_item = false;

        if (keyshift) cam.lookAt(this.position.x, this.position.y, this.position.z);

        gui.actuatorChart.show();

        // initial label (may be overridden)
        gui.actuatorChart.setCaptionLabel(name + (use_sai? " (SAI)" : "") + "  NODE ID: " + this.parent.node_id);
        
      }

      // hack to select but not draw names etc if we are in test mode:
      if(test_current_actuator) {

        draw_me(false); 

      } else {

        fill(255, 200, 0);
        draw_me(true);          // <-- overridden to be specific for each actuator type

        cam.beginHUD();

        fill(255, 200, 0);
        RPi parent_pi = dl.find_nodes_parent_rpi(this.parent.node_id);
        String label = name;

        if(use_sai) label = (label + " (SAI) ");

        if( monitor.lost_devices.contains(parent_pi.my_address) || 
            monitor.lost_devices.contains(str(this.parent.node_id)) ) {
            label = (label + "  LOST!");
        }
        if(attenuating) label = (label + " _ _ _ ");
        text(label, mouseX, mouseY+textoffset); 
        textoffset += textheight+2;

        cam.endHUD();
      }
      //fill(cur_value); // is this necessary? it's not affecting anything on the viz side and we can't do it anymore
    } else {

      draw_me(false);
    }

    update_info();


    if (draw_bounding_boxes) {
      draw_box();
    }

    popMatrix();
  }
  /*!
   * @ MATT - TODO 
   */
  void draw_box() {

    PVector[] box = getBox();

    cam.beginHUD();
    stroke(0);

    line( box[0].x, box[0].y, box[1].x, box[1].y);
    line( box[1].x, box[1].y, box[2].x, box[2].y);
    line( box[2].x, box[2].y, box[3].x, box[3].y);
    line( box[3].x, box[3].y, box[0].x, box[0].y);

    cam.endHUD();
  }
  /*!
   * @ MATT - TODO 
   * Gets the bounding box for rollovers?
   */
  PVector[] getBox() {

    PVector[] box = new PVector[4];

    box[0] = new PVector(screenX(  virtual_width/2, virtual_height/2, 0), screenY(  virtual_width/2, virtual_height/2, 0));
    box[1] = new PVector(screenX(0-virtual_width/2, virtual_height/2, 0), screenY(0-virtual_width/2, virtual_height/2, 0));
    box[2] = new PVector(screenX(0-virtual_width/2, 0-virtual_height/2, 0), screenY(0-virtual_width/2, 0-virtual_height/2, 0));
    box[3] = new PVector(screenX(  virtual_width/2, 0-virtual_height/2, 0), screenY(  virtual_width/2, 0-virtual_height/2, 0));

    return(box);
  }


  boolean is_mouse_over() {
    return(containsPoint(getBox(), mouseX, mouseY));
  }

  boolean is_mouse_near(int mouse_test_distance) {
    PVector scrpos = new PVector(screenX(0,0,0), screenY(0,0,0), 0);
    if(distSq(scrpos.x, scrpos.y, mouseX, mouseY) < sq(mouse_test_distance)) {
      return(true);
    }
    return(false);
  }

  boolean is_paintbrush_near() {
    // encoding incoming paintbrush position in PVector paintbrush_osc_params 0.0-1.0 in x and y, and 0.0-1.0 in z as diameter.
    // encoding offsets to map to actual model in PVecotr paintbursh_osc_offsets as x offset, y offset, and z will be scale to convert _params to world coords.
    if(distSq(position.x, position.y, 
            paintbrush_osc_offsets.x+(paintbrush_osc_params.x*paintbrush_osc_offsets.z), 
                paintbrush_osc_offsets.y+(paintbrush_osc_params.y*paintbrush_osc_offsets.z*1.337)) < sq(0.25*paintbrush_osc_offsets.z * paintbrush_osc_params.z)) {  // extra 1.337 in y to make up for aspect ratio of image
              return(true);
            }
            return(false);
  }

  // used for picking inside a bounding box -- taken from:
  // http://hg.postspectacular.com/toxiclibs/src/tip/src.core/toxi/geom/Polygon2D.java
  boolean containsPoint(PVector[] verts, float px, float py) {
    int num = verts.length;
    int i, j = num - 1;
    boolean oddNodes = false;
    for (i = 0; i < num; i++) {
      PVector vi = verts[i];
      PVector vj = verts[j];
      if (vi.y < py && vj.y >= py || vj.y < py && vi.y >= py) {
        if (vi.x + (py - vi.y) / (vj.y - vi.y) * (vj.x - vi.x) < px) {
          oddNodes = !oddNodes;
        }
      }
      j = i;
    }
    return oddNodes;
  }



  // ====== override these functions for different types of actuators, make these abstract functions?

  /*!
   * @ MATT - TODO 
   */
  void draw_me(boolean mouseover) {
    ellipse(0, 0, virtual_width, virtual_height);
  }

  /*!
   * @ MATT - TODO 
   */
  void update_info() {
    if (selected_actuator != null && selected_actuator == this) {

     if(gui.actuator_settings != null && !gui.actuator_settings.isVisible()) {
        gui.actuator_settings.show();
        gui.influence_settings.show();
        gui.influence_settings.open();
        apply_actuator_settings_to( int(gui.which_actuators.getValue()) );
        set_which_influence(int(gui.which_influence.getValue()));
        gui.which_actuators.getItem(0).setCaptionLabel(" This " + this.designator.device_friendly_type);
        gui.which_actuators.getItem(1).setCaptionLabel(" This " + this.designator.device_friendly_type + " Group");
        gui.which_actuators.getItem(2).setCaptionLabel(" All "  + this.designator.device_friendly_type + "s");

        gui.display_coords(position);
      }
    }
  } 

  OscMessage add_raw_output(OscMessage m) {

         float output = cur_value/255.0;
         m.add(uid);           // add int for pin number
         m.add(output);        // add float 0.0 - 1.0 for current level

    return(m);
  }

  // config string helper functions
  /*! 
   * Gets the number of commands from a config string. 
   * \param str Incoming config string
   */
  protected int get_num_commands(String str)
  {
    int num_commands = 0;
    for (int i = 0; i < str.length(); i++)
    {
      if (str.charAt(i) == CONFIG_DELIMITER)
        num_commands++;
    }
    return num_commands;
  }

  /*!
   * Gets a full command (keyword + arguments) from a config string
   * \param str The config string
   * \param num The index of command that you want from the config string. 
   */
  protected String get_full_command(String str, int num)
  {
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

  // maybe we don't want to return a String array because of pointer restrictions in C++. 
  // not a big deal to seperate these out in two commands; get_command_keyword(), get_command_arguments()
  // even though it may not be as efficient. 
  /*!
    Gets the combination of keyword and arguments, stored in an array as {keyword, arguments}.
    \param str The config string
    \param num Which index of command you want to get from it
  */
  protected String[] get_command(String str, int num)
  {
    String[] seperated_command = new String[2];
    String full_command = get_full_command(str, num);

    if(full_command.equals(""))
    {
      seperated_command[0] = "";
      seperated_command[1] = "";
      return seperated_command;
    }

    int keyword_end_index = 0; 
    boolean argument = true;

    if(full_command.indexOf(" ") > 0)
      keyword_end_index = full_command.indexOf(" ");
    else if(full_command.indexOf(";") > 0){
      keyword_end_index = full_command.indexOf(";");
      argument = false;
    }
    else if(full_command.charAt(full_command.length() - 1) != ' ' && full_command.charAt(full_command.length() - 1) != ';'){
      keyword_end_index = full_command.length();
      argument = false;
    }

    String keyword = full_command.substring(0, keyword_end_index);

    String arguments = "";
    if (argument)
      arguments = full_command.substring(full_command.indexOf(" ") + 1, full_command.length());

    seperated_command[0] = keyword;
    seperated_command[1] = arguments;
    
    return seperated_command;

  }

  //  Influence map functions

  void add_influence(String influence_name)
  {
    add_influence(influence_name, 0.0);
  }

  void add_influence(String influence_name, float influence_value)
  {
    // check if influence exists in hashmap
    if(current_influences.containsKey(influence_name))
    {
      update_influence(influence_name, influence_value);
      // current_influences.get(influence_name).active = true;
      return;
    }

    current_influences.put(influence_name, new InfluenceStorage(influence_value));    
  }

  void update_influence(String influence_name, float influence_value)
  {

    new_influence_update = true;

    if(!current_influences.containsKey(influence_name)) {
        current_influences.put(influence_name, new InfluenceStorage(influence_value)); 
        return;
    }
    
    InfluenceStorage infstor = current_influences.get(influence_name);
    infstor.current_influence = influence_value;
    current_influences.replace(influence_name, infstor);
  }

  float get_current_influence(String influence_name) {
    if(!current_influences.containsKey(influence_name)) {
      return -1;
    } else {
      return(current_influences.get(influence_name).current_influence);
    }

  }

  boolean subscribed_to_influence(String influence_name) {
     if(!current_influences.containsKey(influence_name))
      return false;
     return(current_influences.get(influence_name).active);
  }

  void set_low_range(String influence_name, float bot) {
     if(!current_influences.containsKey(influence_name))
      return;

     current_influences.get(influence_name).range_bot = bot;
  }
  
  void set_high_range(String influence_name, float top) {
     if(!current_influences.containsKey(influence_name))
      return;

     current_influences.get(influence_name).range_top = top;
  }

  float get_low_range(String influence_name) {
     if(!current_influences.containsKey(influence_name))
      return 0.0;

     return(current_influences.get(influence_name).range_bot);
  }
  
  float get_high_range(String influence_name) {
     if(!current_influences.containsKey(influence_name))
      return 1.0;

     return(current_influences.get(influence_name).range_top);
  }

  boolean remove_influence(String influence_name)
  {
    if(!current_influences.containsKey(influence_name))
      return false;
    
    current_influences.remove(influence_name);
      return true;
  }

  void enable_influence(String influence_name)
  {
    if(!current_influences.containsKey(influence_name)) {
            current_influences.put(influence_name, new InfluenceStorage()); 
            return;
    }
    
    InfluenceStorage infstor = current_influences.get(influence_name);
    infstor.active = true;
    current_influences.replace(influence_name, infstor);
  }

  void disable_influence(String influence_name)
  {
    if(!current_influences.containsKey(influence_name)) {
            current_influences.put(influence_name, new InfluenceStorage()); 
    }
    
    InfluenceStorage infstor = current_influences.get(influence_name);
    infstor.active = false;
    current_influences.replace(influence_name, infstor);
  }
  
}

private class InfluenceStorage 
{
  float current_influence;
  float range_bot = 0.0;
  float range_top = 1.0; 
  boolean active;

  InfluenceStorage()
  {
    current_influence = 0.0;
    active = true;
    range_bot = 0.0;
    range_top = 1.0;
  }

  InfluenceStorage(float current_influence)
  {
    this.current_influence = current_influence;
    active = true;
    range_bot = 0.0;
    range_top = 1.0;
  }

  JSONObject get_inf_settings_json() {

    JSONObject inf = new JSONObject();
    
    inf.setBoolean("active", this.active);
    inf.setFloat("range_bot", this.range_bot);
    inf.setFloat("range_top", this.range_top);

    return inf;

  }
}
