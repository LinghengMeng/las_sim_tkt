class DeviceIdentifier
{
  String device_type;
  String device_friendly_type;
  String config;
  boolean use_sai;       // does this device use the SAI? (Smart Actuator Interface)
  int device_number;     // note!  Device_number is zero-based, so it is one less than 'name' (ie for DR1 it will be zero)
  SAI actuator_sai;

  DeviceIdentifier()
  {
    this("", 0, "");
  }

  DeviceIdentifier(String device_type, int device_number)
  {
    this(device_type, device_number, "");
  }

  DeviceIdentifier(String device_type, int device_number, String device_config)
  {
    this.device_type = device_type;
    this.device_friendly_type = device_type;
    this.device_number = device_number;
    this.config = device_config;

    if(config.contains("USE_SAI")) {
      use_sai = true;
    }
  }


  void init_sai(Actuator a) {

    int num_commands = a.get_num_commands(config);
    String sai_profile = "default";                        // default profile
    ArrayList<String> sai_next = new ArrayList<String>();  // default empty

    // check for profile name and/or child SAIs
    for(int i=0; i<num_commands ; i++) {
      String[] c = a.get_command(config, i);

      if(c[0].contains("SAI_PROFILE")) {
         sai_profile = c[1];
      }

      if(c[0].contains("SAI_CHILD")) {
         sai_next.add(c[1]);
      }
    }

    actuator_sai = new SAI(a, sai_profile, sai_next);
    all_sais.put(a.name, actuator_sai);

    println(" ALL_SAIS: " );
    for(String n : all_sais.keySet()) {
      println("\t"+n);
    }

  }


  String get_identifier_string() {
    return(device_type + (device_number+1));  // note must add one to be consistent with string names
  }
}
