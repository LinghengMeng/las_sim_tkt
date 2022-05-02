/*!
 <h1> Sensor </h1>
 Sensor class
 
 \author Farhan Monower, Matt Gorbet
 */

/*!
 *  \class Sensor
 *  \brief Processing sensor class to create virtual sensors. Abstract so the specific sensors can expand on base class.
 *  \author Farhan Monower
 */
abstract class Sensor {

  /*!
   *  \var CONFIG_DELIMITER
   *  used to parse the configuration string to initialize the specific device
   */
  static final char CONFIG_DELIMITER = ';';
  /*!
   *  \var name
   *  the name of the sensor
   */
  String name;
  /*!
   *  \var cur_value
   *  The current stored value of the sensor
   */
  float cur_value;
  /*!
   *  \var position
   *  PVector used for visualizing the sensor
   */
  PVector position;
  /*!
   *  \var uid
   *  The unique identifier of the sensor. It has the value of one of it's pins.
   */
  int uid;

  /*!
   *  \var installed
   *  Is the sensor actually installed. Derived and set from device locator.
   */
  boolean installed;
  /*!
   *  \var parent
   *  Sensor's parent node
   */
  Node parent = null;
  /*!
   *  \var designator
   *  Used to store the designated type-number identifier of the device e.g. SD1
   */
  DeviceIdentifier designator;

  /*!
   *  width
   */
  int   virtual_width;
  /*!
   *  height
   */
  int   virtual_height;
  /*!
   *  depth
   */
  int   virtual_depth;


  Patchable patchable;

  /*!
   *  \fn Sensor()
   *  \brief Constructor for the sensor class
   *  \return none
   */
  Sensor() {
    name = "";
    position = new PVector(0.0, 0.0, 0.0);
    uid = 0;
    parent = null;

    installed = false;
  }

  /*!
   *  \fn install(String n, PVector pos, int p, Node parent_, DeviceIdentifier des)
   *  \brief function called to initialize and virtually "install" the sensor
   *  \param n the name of the sensor
   *  \param pos PVector of the position of the sensor in the sculpture
   *  \param p the pin number, or UID of the sensor
   *  \param  parent_ the parent node of this sensor
   *  \param des the DeviceIdentifier of this sensor to store the name and number
   *  \return none
   */
  void install(String n, PVector pos, int p, Node parent_, DeviceIdentifier des) {
    name = n;
    uid = p;
    parent = parent_;
    cur_value = 0;
    position = pos;
    designator = des;
    installed = true;

    virtual_width = 50;
    virtual_depth = 50;
    virtual_height = 20;  // unused for now

    // debug 
    print("I'm a SENSOR named " + name + " and my uid is: " + uid);
    println();
  }

  /*!
   *  \fn read_value()
   *  \brief Get this sensor's reading. Abstracted so other classes an expand upon it.
   *  \return the float value
   */
  abstract float read_value();

  /*!
   *  \fn prase_config_string(String config)
   *  \brief Abstract configuration string parsing function.
   *  \param config the configuration string to parse
   *  \return boolean true or false to indicate if it was successful in reading the string
   */
  abstract boolean parse_config_string(String config);

  /*!
   *  \fn update()
   *  \brief used to do any regular action for the device
   *  \return none
   */
  void update() {

    // any update functions to happen each frame happen here.
  }

  /*!
   *  \fn go()
   *  \brief In processing, used for visualization of the device
   *  \return none
   */
  void go() {

    // Teensy Code
    // value = analogRead(uid);

    // Processing Code------------------

    draw_to_screen();
  }

  /*!
   *  \fn draw_to_screen()
   *  \brief used to draw the device onto visualization
   *  \return none
   */
  synchronized void draw_to_screen() {

    // use value to set screen colour
    stroke(0);

    // update this so instead of actutors it works for sensors and all generic devices.

    if (selected_sensor != null && selected_sensor == this && drawgui) {
      // set highlight
      stroke(255, 200, 0);
    }


    // fill(cur_value);

    pushMatrix();
    translate(position.x, position.y, position.z);

  if (billboard_mode > 0) {          // face camera
      rotateX(cam.getRotations()[0]);
      rotateY(cam.getRotations()[1]);
      rotateZ(cam.getRotations()[2]);
  }
  
    if (is_mouse_over()) {
      over_sensor = this;

      patcher.highlight(name);

      if (select_item == true) {

        

        selected_sensor = this;
        select_item = false;

        if (keyshift) cam.lookAt(this.position.x, this.position.y, this.position.z);
      }

      fill(255, 200, 0);
      draw_me(true);          // <-- overridden to be specific for each sensor / actuator type

      cam.beginHUD();

      RPi parent_pi = dl.find_nodes_parent_rpi(this.parent.node_id);
      String label = name;
       if( monitor.lost_devices.contains(parent_pi.my_address) || 
           monitor.lost_devices.contains(str(this.parent.node_id)) ) {
           label = (name + "  LOST!");
       }

      fill(255, 200, 0);
      text(label, mouseX, mouseY+textoffset);
      textoffset += textheight+2;

      cam.endHUD();

      fill(cur_value);
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
   *  \fn draw_box()
   *  \brief MATT - TODO
   *  \return none
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
   *  \fn getBox()
   *  \brief MATT - TODO
   *  \return PVector
   */
  PVector[] getBox() {

    PVector[] box = new PVector[4];

    // handle box for rollover
    box[0] = new PVector(screenX(  virtual_width/2, virtual_height/2, 0), screenY(  virtual_width/2, virtual_height/2, 0));
    box[1] = new PVector(screenX(0-virtual_width/2, virtual_height/2, 0), screenY(0-virtual_width/2, virtual_height/2, 0));
    box[2] = new PVector(screenX(0-virtual_width/2, 0-virtual_height/2, 0), screenY(0-virtual_width/2, 0-virtual_height/2, 0));
    box[3] = new PVector(screenX(  virtual_width/2, 0-virtual_height/2, 0), screenY(  virtual_width/2, 0-virtual_height/2, 0));




    return(box);
  }


  /*!
   *  \fn is_mouse_over()
   *  \brief MATT - TODO
   *  \return boolean true or false
   */
  boolean is_mouse_over() {

    return(containsPoint(getBox(), mouseX, mouseY));
  }

  /*!
   *  \fn containsPoint(PVector[] verts, float px, float py)
   *  \brief used for picking inside a bounding box -- taken from:
   *   http://hg.postspectacular.com/toxiclibs/src/tip/src.core/toxi/geom/Polygon2D.java
   *  \param verts MATT - TODO
   *  \param px
   *  \param py
   *  \return boolean true or false
   */
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



  // ====== override these functions for different types of actuators
  /*!
   *  \fn draw_me(boolean mouseover)
   *  \brief MATT - TODO
   *  \param mouseover 
   *  \return none
   */
  void draw_me(boolean mouseover) {
    if (mouseover) {
      fill(255, 200, 0);
      stroke(255, 200, 0);
    } else {
      fill(128);
    }
    rect(0, 0, virtual_width, virtual_height);
  }

  /*!
   *  \fn update_info()
   *  \brief MATT - TODO
   *  \return none
   */
  void update_info() {
    if (selected_sensor != null && selected_sensor == this) {
      if (gui.sdChart.getDataSet("sensor_values") == null) {
          gui.sdChart.addDataSet("sensor_values");
      }
      gui.sdChart.push("sensor_values", cur_value);
    }
  }

  /////  SENSOR MESSAGING ==========================
  OscMessage add_raw_output(OscMessage m) { 
    if(uid!=0){
        float output = cur_value;
        m.add(uid);                // add int for pin number
        m.add(output);             // 
    }
    return(m);
  }

  /*!
   *  \fn get_num_commands(String str)
   *  \brief MATT - TODO
   *  \param str
   *  \return int number of commands
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
   *  \fn get_full_command(String str, int num)
   *  \brief MATT - TODO
   *  \param str
   *  \param num
   *  \return the full string command
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
   *  \fn get_command(String str, int num)
   *  \brief MATT - TODO
   *  \param str
   *  \param num
   *  \return the string array command
   */
  protected String[] get_command(String str, int num)
  {
    String[] seperated_command = new String[2];
    String full_command = get_full_command(str, num);

    if (full_command.equals(""))
    {
      seperated_command[0] = "";
      seperated_command[1] = "";
      return seperated_command;
    }

    int keyword_end_index = 0; 
    boolean argument = true;

    if (full_command.indexOf(" ") > 0)
      keyword_end_index = full_command.indexOf(" ");
    else if (full_command.indexOf(";") > 0) {
      keyword_end_index = full_command.indexOf(";");
      argument = false;
    } else if (full_command.charAt(full_command.length() - 1) != ' ' && full_command.charAt(full_command.length() - 1) != ';') {
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
}
