
import java.util.PriorityQueue;

class SAI {

  static final boolean SAI_REPEAT = true;
  static final boolean SAI_ONCE   = false;
  static final int     MAX_PLAYBACKS = 10;  // reuse these ten playbacks (to simulate memory issues)
  static final float   MIN_DAMPEN = 0.01;

  int      base_duration = 1000;  // default length in ms

  String   profile_name;

  Playback cur_playback;

  float    trigger_level;

  Actuator my_actuator;
  ArrayList<String>  next_actuators;         // names of next actuators in this SAI chain -- up to two -- use as keys to find thier SAIs.
  
  ArrayList<Playback>  available_playbacks;
  ArrayList<Playback>  active_playbacks;
  
  Profile              prof;


  SAI(Actuator a) {
       this(a, "default", new ArrayList<String>());  
  }

  SAI(Actuator a, String _profile_name) {
       this(a, _profile_name, new ArrayList<String>());
  }

  SAI(Actuator a, String _profile_name, ArrayList<String> next) {

      my_actuator = a;
      println(" setting up SAI for " + a.name + " with profile " + _profile_name + " and children: " );
      for (String s : next) { println(" \t" + s);}

      prof = null;

      trigger_level = 0.0;

      next_actuators = next;
      active_playbacks = new ArrayList<Playback>();
      available_playbacks = new ArrayList<Playback>();

      profile_name = _profile_name;
      prof = loadProfile();

      cur_playback = new Playback(this);

      for(int i = 0 ; i < MAX_PLAYBACKS ; i++) {
          available_playbacks.add(new Playback(this));
      }

  }

  void reloadProfile() {
    
    if(!this.prof.can_reload) return; // avoid infinite loops (unset by a trigger)

    this.prof.can_reload = false;

    this.prof = loadProfile();

    cur_playback.prof = this.prof;
    for(Playback p : available_playbacks) {
        p.prof = this.prof;
    }
    for(Playback p : active_playbacks) {
        p.prof = this.prof;
    }

    for(String child : next_actuators) {
        all_sais.get(child).reloadProfile();
    }

  }

  Profile loadProfile() {
      return(loadProfile(profile_name));
  }

  Profile loadProfile(String fn) {

    JSONObject json;
    Profile p;

    String profile_fn = new String("data/" + file_name + "/" + "SAI_profile_" + fn + ".json");

    println("loading SAI profile: " + fn );
    try {
        json = loadJSONObject(sketchPath() + "/" + profile_fn);
    } catch(Exception e) {
        println(" Problem loading SAI profile " + profile_fn + "... defaulting to default");
        json = loadJSONObject(sketchPath() + "/data/" + file_name + "/SAI_profile_default.json");
    }

    p = new Profile();

    p.name = fn;
  
    if(json.getJSONArray("sequence") != null)  p.sequence = json.getJSONArray( "sequence" ).getFloatArray();
    println(" ... sequence length is " + p.sequence.length);

    p.x_attenuation           = json.getFloat("x_attenuation",            1.0);  // default to 1.0 if it doesn't exist
    p.y_attenuation           = json.getFloat("y_attenuation",            1.0);  
    p.propagation_dampening   = json.getFloat("propagation_dampening",    1.0);
    p.propagation_delay       = json.getInt("propagation_delay",            0);
    p.trigger_threshold       = json.getFloat("trigger_threshold",        0.5);
    p.trigger_mode            = json.getString("trigger_mode", "SAI_REPEAT").equals("SAI_REPEAT"); // boolean where SAI_REPEAT is true, so default to true.
    p.trigger_cooldown        = json.getInt("trigger_cooldown",           250);

    p.step_duration           = int((base_duration * p.x_attenuation) / p.sequence.length);

    return(p);

  }

  void trigger() {
       trigger(1.0);
  }

  void trigger(float dampen) {

       if( (prof.trigger_mode == SAI_REPEAT && (tl_millis() - cur_playback.trigger_time < prof.trigger_cooldown)) || 
           (prof.trigger_mode == SAI_ONCE && cur_playback.active) ||
           (available_playbacks.size() == 0) ||
           (dampen < MIN_DAMPEN) ) {
           return;  // ignore this attempt to trigger
       }
    //    println(" ** triggering SAI on " + my_actuator.name + ":");
    //    println("\tNext actuators size is " + next_actuators.size() + "\n\tDampen is " + dampen + "\n\tTrigger_mode is " + prof.trigger_mode);
    //    println("\tavailable_playbacks:" + available_playbacks.size());
    //    println("\tactive_playbacks:" + active_playbacks.size());
    //    println("\tcur_playback active?: " + cur_playback.active);

       trigger_level = dampen;
  }

  void update() {

      if(my_actuator.sai_in_value > prof.trigger_threshold) {
          trigger(my_actuator.sai_in_value);  // (my_actuator.sai_in_value-trigger_threshold) / (1.0-trigger_threshold);
      }

      if(trigger_level != 0.0) {

        if(cur_playback.active) pushPlayback();  // push current one down in stack to create new current one.
        cur_playback.set(tl_millis(), trigger_level);

        trigger_level = 0.0;
      }

      // check if we have crossed to next fade step     
      if( (tl_millis() - cur_playback.trigger_time) > (cur_playback.profile_step * prof.step_duration)) {

        // if so, build the fade level from current + any other active playbacks
        float target = cur_playback.getLevel();

        for (Playback p : active_playbacks) {
            target = min(1.0, target+p.getLevel());  // superposition of current with other active playbacks - quantized so we can have only one fade() at a time
        }
        
        // trigger the fade
        my_actuator.fade(min(255, int(target * 255)), prof.step_duration);
      }

      // check for propagation triggers

      if(next_actuators.size() > 0) {
          if(cur_playback.active) cur_playback.checkPropagation();

          for (Playback p : active_playbacks) {
              p.checkPropagation();
          }
      }

      // by now we may have some finished playbacks that have been put back in to 'available' - cull them from active
      for (Playback p : available_playbacks) {
          active_playbacks.remove(p);
      }

  }

  void pushPlayback() {
    active_playbacks.add(cur_playback);                        // send current playback into stack
    cur_playback = available_playbacks.remove(0);              // replace it with a new one
  }

}

class Playback {

    SAI parent;
    Profile prof;
    int trigger_time;
    int propagate_time;
    float attenuation;
    boolean done = false;
    boolean active = false;
    int profile_step = 0;


    Playback(SAI p) {
        parent = p;
        prof = parent.prof;
        trigger_time = -1;
        propagate_time = -1;
        attenuation = 0.0;
    }

    void set(int trig_time, float dampen) {

        prof.can_reload = true;

        trigger_time = trig_time;
        attenuation  = dampen;
        profile_step = 0;

        // set propagation time for this playback
        if(parent.next_actuators.size() > 0) {
            propagate_time = int(trigger_time + (parent.base_duration * prof.x_attenuation) + prof.propagation_delay);
        }
        active = true;

      //  println(" Set up a playback for " + parent.my_actuator.name + " with attenuation: " + attenuation);
    }

    float getLevel() {
          profile_step++;

          if(profile_step >= prof.sequence.length) {
              if(propagate_time == -1) { // done sequence and nothing left to propagate, so we are done
                 active = false;
                 if(this != parent.cur_playback) parent.available_playbacks.add(this);  // put it back in available bucket.
              }
              return(0.0);
          }

          return( prof.sequence[profile_step] * prof.y_attenuation * attenuation );
    }

    void checkPropagation() {

        if(propagate_time == -1) {                 // none to do
            return;
        }

        if(propagate_time > tl_millis()) {         // not yet
            return;
        }
    
        for(String s : parent.next_actuators ) {
          //  println(" propagating from " + parent.my_actuator.name + " -> " + s);

            try {
                all_sais.get(s).trigger(attenuation * prof.propagation_dampening);  // compound the attenuation
            } catch(Exception e) {
           //     println(s + " is (null)...   ignoring");
            }
        }

        propagate_time = -1;

    }

}

class Profile {

  float[] sequence;
  String  name;
  int     step_duration;
  float   x_attenuation;
  float   y_attenuation;
  int     propagation_delay;
  float   propagation_dampening;
  float   trigger_threshold;
  boolean trigger_mode;        // once (latching) or repeat?
  int     trigger_cooldown;    // how many ms before new trigger allowed?
  boolean can_reload = false;  // flag to prevent infinite reloading loops.
 
  Profile() {

  }

}