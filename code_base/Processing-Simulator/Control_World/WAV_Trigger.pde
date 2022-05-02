/*!
 <h1> WAV_Trigger </h1>
 Processing class for the virtual wav triggers
 
 \author Matt Gorbet, et al.
 
 */
import javax.sound.sampled.AudioInputStream;
import javax.sound.sampled.AudioSystem;
import javax.sound.sampled.AudioFormat;

/*!
 *  \class WAV_Trigger
 *  \brief The virtual wav trigger class
 */
class WAV_Trigger extends Actuator {  
  /*!
   *  \var MAX_TRACKS
   *  constant value, spec'd to the WAV Trigger's physical channel limitation
   */
  public static final int MAX_TRACKS = 14;
  /*!
   *  \var MAX_VOL
   *  constant value, spec'd to the WAV Trigger's physical gain limitation. The actual values it takes is from 10 to -70dB, we translate this on the node level.
   */
  public static final int MAX_VOL = 80;

  /*!
   *  \var tracks
   *  array that keeps track of the playing tracks
   */
  String[] tracks = new String[MAX_TRACKS];
  /*!
   *  \var volumes
   *  array that keeps track of the playing track volumes
   */
  DInt[] volumes = new DInt[MAX_TRACKS];
  /*!
   *  \var stop_tracks
   *  array that keeps track of the which tracks to stop
   */
  boolean[] stop_tracks = new boolean[MAX_TRACKS];
  /*!
   *  \var default_volume
   *  70, translates to 0dB unity gain on the node level
   */
  int default_volume = 70;
  /*!
   *  \var master_volume
   *  the main gain of the wav trigger, scales the other volumes by this value. Similar to a computer's volume mixer.
   */
  DInt master_volume = new DInt(MAX_VOL);

  /*!
   *  \var runtime
   *  the default run time, 2s. Gets set automatically to track length using a java file search.
   */
  int runtime = 2000;
  /*!
   *  \var txpin
   *  one of the pins of the wav trigger
   */

  /*!
   *  \var rxpin
   *  one of the pins of the wav trigger
   */
  int txpin, rxpin;

  /*!
   *  \var playing
   *  boolean to let control know if wav trigger is actively playing audio
   */
  boolean playing = false;

  /*!
   *  \fn install(String n, PVector pos, int pin, Node parent_, DeviceIdentifier des, String config)
   *  \brief installs the wav trigger actuator into the visualzation
   *  \param n name of the wav trigger
   *  \param pos the position of the wav trigger
   *  \param pin the pin/uid of the wav trigger
   *  \param des the device identifier for the 2 character 1 number identifier e.g. WV1
   *  \param config the configuration string for the wav trigger
   *  \return none
   */
  void install(String n, PVector pos, int pin, Node parent_, DeviceIdentifier des) {
    super.install(n, pos, pin, parent_, des);
    txpin = pin; // verify this is right!
    rxpin = 0;
    virtual_width  = 40;
    virtual_height = 40;
    virtual_depth  = 2; 
    parse_config_string(des.config);
  }

  /*!
   *  \fn WAV_Trigger()
   *  \brief constructor for the wav trigger
   *  \return none
   */
  WAV_Trigger()
  {
    super();
  }

  /*!
   *  \fn prase_config_string(String config_string)
   *  \brief Used to parse the config string
   *  \param config_string the configuration string to parse
   *  \return true if the string was processed correct, else false
   */
  boolean parse_config_string(String config)
  {
    int num_commands = get_num_commands(config);
    boolean success = true;
    for (int i = 0; i < num_commands; i++)
    {
      String[] command = get_command(config, i);
      if (command[0].length() != 0)
      {
        String keyword = command[0];
        String arguments = command[1];

        if (keyword.equals("TXPIN"))
        {
          int pin = Integer.parseInt(arguments.substring(0, arguments.length()));
          txpin = pin;
        } else if (keyword.equals("INVERT"))
        {
          int temp_pin = txpin;
          txpin = rxpin;
          rxpin = temp_pin;
        } else if (keyword.equals("RUNTIME"))
        {
          int rtime = Integer.parseInt(arguments.substring(0, arguments.length()));
          runtime = rtime;
        } else 
        {
          success = false;
        }
      }

      // parse the command
    }
    return success;
  }


  /*!
   *  \fn update()
   *  \brief used to keep track of playing audio simulation
   *  \return none
   */
  void update() {
    super.update();
    for (int i = 0; i < MAX_TRACKS; i++) {
      if (tracks[i] == null)
        continue;

      if (volumes[i].run_time >= volumes[i].run_length || (volumes[i].fade_percent_done >= 1.0 && stop_tracks[i])) {
        volumes[i] = null;
        tracks[i] = null;
        stop_tracks[i] = false;
        continue;
      }

      volumes[i] = update_DInt(volumes[i]);
      playing = true;

      //println("Index " + i + " Track " + (tracks[i]) + ": Volume =" + volumes[i].state + "  Runtime: " + volumes[i].run_time + " fade_percent_done: " + volumes[i].run_length);
    }
  }

  /*!
   *  \fn setValue()
   *  \brief Vestigial function from the actuator class. Needed to be overloaded. NOT TO BE CALLED, currently just does a master gain fade
   *  \return none
   */
  void setValue(int v) {
    fade(v, 0);
  }

  /*!
   *  \fn fade(int v, long fade_millis)
   *  \brief used to fade the audio dints
   *  \param v the volume to set it to
   *  \param fade_millis the milliseconds to fade it
   *  \return none
   */
  void fade(int v, long fade_millis) {
    for (int i = 0; i < MAX_TRACKS; i++) {
      if (volumes[i] == null) continue;
      volumes[i] = fade(v, fade_millis, volumes[i]);
    }
  }

  /*!
   *  \fn play_track(int track_num, long solo)
   *  \brief play a track solo or poly
   *  \param track_num the track to play. Should be a numerical value.
   *  \param solo if true play the track solo (turn off other tracks playing), if false play the track poly (do not turn off other tracks playing)
   *  \return none
   */
  void play_track(String track_num, boolean solo) {
    if (solo) {
      for (int i = 0; i < MAX_TRACKS; i++) {
        volumes[i] = null;
        tracks[i] = null;
        stop_tracks[i] = false;
      }
    }

    for (int i = 0; i < MAX_TRACKS; i++) {
      if (tracks[i] == null) {
        tracks[i] = track_num;
        long track_length = find_track_length(track_num);
        volumes[i] = new DInt(MAX_VOL, track_length);
        volumes[i] = setValue(default_volume, volumes[i]);
        break;
      }
    }
  }

  /*!
   *  \fn master_volume_set(int vol)
   *  \brief used to set the master volume
   *  \param vol the volume
   *  \return none
   */
  void master_volume_set(int vol) {
    setValue(vol);
  }

  /*!
   *  \fn track_volume_set(String trk, int vol)
   *  \brief used to set the volume of a track alone
   *  \param trk the track to adjust
   *  \param vol the volume to set it to
   *  \return none
   */
  void track_volume_set(String trk, int vol) {
    for (int i = 0; i < MAX_TRACKS; i++) {
      if (tracks[i] == null ) continue;
      if (tracks[i].equals(trk)) {
        volumes[i] = setValue(vol, volumes[i]);
      }
    }
  }

  /*!
   *  \fn track_fade(String trk, int vol, long time, boolean stop)
   *  \brief used to fade the volume of a track alone, and stop it if required
   *  \param trk the track to adjust
   *  \param vol the volume to set it to
   *  \param time the milliseconds to keep fading it
   *  \param stop true if you want to stop the track, false otherwise
   *  \return none
   */
  void track_fade(String trk, int vol, long time, boolean stop) {
    for (int i = 0; i < MAX_TRACKS; i++) {
      if (tracks[i] == null ) continue;
      if (tracks[i].equals(trk)) {
        volumes[i] = fade(vol, time, volumes[i]);

        //still not sure what stop does, but we can still pass it to the c++ function
        //for now, implement as a stopper after fade complete
        stop_tracks[i] = stop;
      }
    }
  }

  /*!
   *  \fn find_track_length(String track_num)
   *  \brief java code that finds the length of the .wav file in the local directory
   *  \param track_num the track to find the length of
   *  \return long time in milliseconds of the track length
   */
  long find_track_length(String track_num) {
    File file = new File(base_path + "/Node_World/wav_trigger/audio/" + ("000" + track_num).substring(track_num.length()) +".wav"); //audio file name format: "001.wav" or "034.wav"
    AudioInputStream audioInputStream = null;
    try {
      audioInputStream = AudioSystem.getAudioInputStream(file);
    }
    catch(Exception e) {
     // println("Error: " + e.fillInStackTrace());
    }

    if (audioInputStream == null)
      return 0;

    AudioFormat format = audioInputStream.getFormat();
    long frames = audioInputStream.getFrameLength();
    long durationInMSeconds = int(1000*((frames+0.0) / format.getFrameRate()));
    return durationInMSeconds;
  }

  /*!
   *  \fn go()
   *  \brief used to draw the wav trigger in the visualization
   *  \return none
   */
  synchronized void go() {

    // Teensy Code ---------------------
    // Write to wav trigger, offset by -70

    // Processing Code------------------

    draw_to_screen();
  }

  /*!
   *  \fn draw_me(boolean mouseover)
   *  \brief draw to visualization if the mouse is over this actuator
   *  \param mouseover boolean that says if the mouse is over the actuator
   *  \return none
   */
  void draw_me(boolean mouseover) {


  int lostalpha = 255;
  RPi parent_pi = dl.find_nodes_parent_rpi(this.parent.node_id);

  if( monitor.lost_devices.contains(parent_pi.my_address) || monitor.lost_devices.contains(str(this.parent.node_id)) ) {

   lostalpha = 70;

  }

    stroke(0, lostalpha);
    float dia = virtual_width;
    if (playing) {
      stroke(190, 0, 0, lostalpha);
      float some_noise = noise(float(get_frame()));
      strokeWeight(5.0 * some_noise);
      dia = int(virtual_width * (0.3 * some_noise));
      cur_value = int(some_noise*255f);  // set this as the hacked 'soundwave' to display
    }

    if (mouseover) {
      fill(255, 200, 0, lostalpha);
      stroke(255, 200, 0, lostalpha);
    } else {
      fill(120, 120, 100, 100);
    }


    ellipse(0, 0, dia, dia);
    ellipse(0, 0, 2*dia/3, 2*dia/3);
    ellipse(0, 0, dia/3, dia/3);

    //rect(0, 0, virtual_width, virtual_height);

    strokeWeight(1);
  }

  /*!
   *  \fn update_info()
   *  \brief send data to visualization
   *  \return none
   */
  synchronized void update_info() {

    if (selected_actuator != null && selected_actuator == this) {



      if (!playing) return;

      for (int i = 0; i < MAX_TRACKS; i++) {
        if (tracks[i] == null)   continue;
        if (gui.actuatorChart.getDataSet(name+tracks[i]) == null) {
          gui.actuatorChart.addDataSet(name+tracks[i]); 
          gui.actuatorChart.setColors(name+tracks[i], color((50*i)%255, (130+20*i)%255, 200));
        }

        gui.actuatorChart.push(name+tracks[i], 255 * (noise(float(get_frame()+(i*120))) * (volumes[i].state/80f) ) );
      }

      gui.actuatorChart.setCaptionLabel(name + " - " + tracks.toString());
    } else {
      if (playing) {
        for (int i = 0; i < MAX_TRACKS; i++) {
          gui.actuatorChart.removeDataSet(name+tracks[i]);
        }
      }
    }
  }
}
