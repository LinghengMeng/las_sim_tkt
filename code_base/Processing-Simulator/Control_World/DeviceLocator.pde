/*!
 <h1> Device Locator </h1>
 The Device Locator class reads the CSV file to store information about the devices in the sculpture in an easily-accessible format. 
 It also kick starts the device creation process by making Raspberry Pi and Node instances, and provides information to the nodes to help them create actuator/sensor instances.
 
 
 \author Niel Mistry et al
 
 */


boolean debug = false;

import java.text.DecimalFormat;
import java.math.RoundingMode;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.regex.*;
import com.google.common.collect.ListMultimap;
import com.google.common.collect.ArrayListMultimap;

//TODO - hack fields to generate # of GE and SD on the c++ level
int num_GE = 0;
int num_SD = 0;
int num_IR = 0;

// Empty arrays for ease-of-passing-back
private static final String[] NO_STRINGS = {};
private static final PVector[] NO_POINTS = {};

DeviceLocatorNode dlnode;
DeviceLocatorNodeStorage dlnodestorage = new DeviceLocatorNodeStorage();

public class DeviceLocator {

  HashSet<String> unique_device_types = new HashSet<String>(Arrays.asList("MO","RS","GE","IR","SD","DR","WT","SM","PC"));

  /*! A data structure that stores all the Raspberry Pis in the sculpture.
   Guaranteed order (order will be same no matter how many times it's called, important for some of the functionality) */
  LinkedHashMap<String, RPi> rpis = new LinkedHashMap<String, RPi>();

  /*! A data structure that stores all the Nodes in the sculpture.
   Guaranteed order (order will be same no matter how many times it's called, important for some of the functionality) */
  LinkedHashMap<Integer, Node> nodes = new LinkedHashMap<Integer, Node>(); 

  /*! Maintains a list of the unique node types (this one just makes sense!) */
  ArrayList<String> unique_node_types = new ArrayList<String>();
  
  /*! Maintains a list of the unique groups (first two characters of the name) */
  ArrayList<String> unique_groups = new ArrayList<String>();

  /*! Maintains a set [no repeating values] of unique control ip's found - for expandability (possiblity of multiple control computers) */
  ArrayList<String> control_ips = new ArrayList<String>();

  /*! Number of actuators */
  int num_actuators = 0;

  processing.data.Table csv;

  // TODO - Matt made these, figure out what they are. 
  float[] x_range = new float[2];
  float[] y_range = new float[2];
  float[] z_range = new float[2];

  /*!
   DeviceLocator constructor 
   \param file_name the name of the CSV file. 
   */


  DeviceLocator(String file_name) 
  {
    dlnode = new DeviceLocatorNode(this); // Create one dlnode object to pass to all the nodes. 
    csv = loadTable(file_name, "header");
    createDevices(); 

    if(!split_dot_h_file) 
    {
     generate_dot_h();          //  generates a single device locator .h file with every node type in it
    } else {
      for (int i = 0; i < unique_groups.size(); i++)   
      {      
        generate_dot_h(unique_groups.get(i));   // generates a different .h file for each node type
      }
    }

    generate_dot_hexmap(split_dot_h_file);
    generate_master_hexlist();
    generate_master_pilist();
  }

  /*!
   This function reads the table row-by-row to store data about the various devices in the system. It also kick-starts the 
   device creation process. 
   */
  void createDevices()
  {
    for (int i = 0; i < csv.getRowCount(); i++) 
    {
      TableRow row = csv.getRow(i);
      if (row.getString("NODE ID") == null || row.getString("NODE ID").equals(""))
      {
        println("Empty nodeID in row " + Integer.toString(i) + ", continuing...");
        csv.removeRow(i);
        i--;
        continue;
      }

      String control_ip = row.getString("CONTROL IP");
      if(!control_ips.contains(control_ip)) {
        if(override_control_ip.equals("")) {
        control_ips.add(control_ip); // since control_ips is a set, it only gets added if the value isn't in it already. No need to do a check
        } else if (!control_ips.contains(override_control_ip)) {
            println("OVERRIDING CONTROL IPs in the .csv WITH " + override_control_ip);
            control_ips.add(override_control_ip);
        }
      }
      
//      String pi_name = row.getString("GROUP").substring(0, row.getString("GROUP").indexOf(':',4));
      String pi_ip = row.getString("PI IP");  
      String pi_name = pi_ip.substring(pi_ip.lastIndexOf('.'));
      if (!pi_present(pi_ip))
      {
        add_pi(pi_name, pi_ip);
      }

      int node_id = Integer.parseInt(row.getString("NODE ID"));

      String node_group = row.getString("GROUP").substring(0, 2);
      if (!unique_groups.contains(node_group))
      {
        unique_groups.add(node_group);
      }

      String node_type = row.getString("NODE_TYPE");
      if (!unique_node_types.contains(node_type))
      {
        unique_node_types.add(node_type);
      }
      if (!node_present(node_id))
      {
        add_node(node_id, node_type, pi_ip, node_group);
      }

      String device_type = row.getString("DEVICE_TYPE");
      String config = row.getString("CONFIG");

      boolean valid_device = !row.getString("UID").equals("--"); // if UID doesn't equal --, this is a valid device. 
      
      if (valid_device)
      {
        String device_name = row.getString("GROUP") + "_" + row.getString("DEVICE") + row.getString("NUM");
        int uid = convert_uid(row.getString("UID"));
        String device_code = row.getString("DEVICE").substring(0, 2);
        if(device_code.equals("GE")) num_GE++;
        if(device_code.equals("SD")) num_SD++;
        if(device_code.equals("IR")) num_IR++;
        
        if(device_type.equals("actuator") || device_type.equals("sensor"))
          add_device(device_name, device_code, row.getInt("NUM"), uid, row.getFloat("X"), row.getFloat("Y"), row.getFloat("Z"), node_id, (row.getString("INSTALLED").equals("yes")), config);
        else
        {
          System.out.println("Device Type " + device_type + " is invalid, please correct. Skipping...");
        }
      } else
      {
        // System.out.println("Device " + row.getString("GROUP") + "_" + row.getString("DEVICE") + row.getString("NUM") + " is not a valid device. This may be okay, depending on the device. Double check the csv!");
      }

      // SET 3D extents of the model, @matt do we use this?
      if (row.getFloat("X") < x_range[0]) x_range[0] = row.getFloat("X");
      if (row.getFloat("Y") < y_range[0]) y_range[0] = row.getFloat("Y");
      if (row.getFloat("Z") < z_range[0]) z_range[0] = row.getFloat("Z");
      if (row.getFloat("X") > x_range[1]) x_range[1] = row.getFloat("X");
      if (row.getFloat("Y") > y_range[1]) y_range[1] = row.getFloat("Y");
      if (row.getFloat("Z") > z_range[1]) z_range[1] = row.getFloat("Z");
    }  

    for (Node node : nodes.values())  
    {
      node.read_dl(); // Tell the nodes to read dl and generate actuators/sensor instances. 
    }
  }

  synchronized LinkedHashMap<Integer, Node> get_nodes()
  {
    return nodes;
  }

  synchronized LinkedHashMap<String, RPi> get_RPis()
  {
    return rpis;
  }

  /*! 
   Handles string to int conversion for pins so that pins like A5 can be used in CSV along with pins like 3. 
   Source of translation for An -> #: https://github.com/PaulStoffregen/cores/blob/master/teensy3/pins_arduino.h 
   */

  synchronized private int convert_uid(String pin)
  {
    if (pin.length() > 0)
    {
      if (Character.isDigit(pin.charAt(0)))
      {
        return Integer.parseInt(pin);
      } else
      {
        int offset = Integer.parseInt(pin.substring(1, pin.length()));
        return 14 + offset;
      }
    } else 
    {
      return -1;
    }
  }

  synchronized String get_control_ip(String rpi_address)
  {
    TableRow row = csv.findRow(rpi_address, "PI IP");
    if (row != null)
      return row.getString("CONTROL IP");                           // is this out of date?
    System.out.println("Error, control IP wasn't found");

    return "";
  }

  synchronized boolean is_control_ip(String control_ip) {
    return control_ips.contains(control_ip);
  }

  synchronized boolean is_raspberry_pi_ip(String rpi_address)
  {
    TableRow row  = csv.findRow(rpi_address, "PI IP");
    if(row == null)
      return false;
    return true;
  }

  synchronized String get_network_prefix()
  {
    if(control_ips.size() == 0)
      return "";
    
    String ip = control_ips.get(0);
    Pattern p = Pattern.compile("[\\d]{1,3}\\.[\\d]{1,3}\\.[\\d]{1,3}\\.");
    Matcher m = p.matcher(ip);
    if(m.find())
    {
      MatchResult mr = m.toMatchResult();
      return ip.substring(mr.start(), mr.end());
    }
    else
    {
      return "";
    }
  }


  synchronized RPi find_nodes_parent_rpi(int address) {
    Node target_node = dl.nodes.get(address);
    for (Map.Entry<String, RPi> entry : dl.rpis.entrySet()) {
      String id = entry.getKey();
      RPi current_rpi = entry.getValue();      
      ArrayList<Node> children = find_children_of_RPi(current_rpi);
      if(children != null)
      {
        if(children.contains(target_node))
        {
          return current_rpi;
        }
      }
    }
    println("returning NULL - no rpi found for this node address");
    return null;    

  }

  synchronized ArrayList<Node> find_children_of_RPi(RPi rpi) {
    ArrayList<Node> n = new ArrayList<Node>();
    for(int i = 0; i < rpi.children_nodes.size(); i++)
    {
      n.add(nodes.get(rpi.children_nodes.get(i)));
    }

    if(n.size() == 0)
      return null;

    return n;
  }

  synchronized boolean pi_present(String pi_ip)
  {
    return rpis.containsKey(pi_ip);
  }

  synchronized private boolean add_pi(String name, String pi_ip)
  {
    rpis.put(pi_ip, new RPi(pi_ip, name)); // TODO - name for pis should be in csv/autogened based on last portion of IP?
    return true;
  }

  synchronized boolean node_present(int node_id)
  {
    return dlnodestorage.node_ids.contains(node_id);
  }

  /*! This function adds the node id and type to the dlnodestorage arrays and then creates a new node object to store in nodes hashmap. */
  synchronized private void add_node(int node_id, String node_type, String rpi_address, String node_group)
  {
    // Don't comment the next two lines out in RPi DL!!
    dlnodestorage.node_ids.add(node_id);
    dlnodestorage.node_types.add(node_type);
    
    // commment rest of function out in RPi DL
    switch(node_type)
    {
    case "HU":
      nodes.put(node_id, new HexUnit(node_id, dlnode, node_type, node_group));
    //  println("Add HU with id " + node_id);
      break;   
    case "MU":
      nodes.put(node_id, new MiniUnit(node_id, dlnode, node_type, node_group));
    //  println("Add MU with id " + node_id);
      break;   
    case "F1":   // Meander:  Finial One
      nodes.put(node_id, new FinialOne(node_id, dlnode, node_type, node_group));
    //  println("Add F1 with id " + node_id);
      break;   
    case "F2":   // Meander:  Finial Two
      nodes.put(node_id, new FinialTwo(node_id, dlnode, node_type, node_group));
    //  println("Add F2 with id " + node_id);
      break;   
    case "P1":   // Meander:  Post One
      nodes.put(node_id, new PostOne(node_id, dlnode, node_type, node_group));
    //  println("Add P1 with id " + node_id);
      break;   
    case "P2":   // Meander:  Post Two
      nodes.put(node_id, new PostTwo(node_id, dlnode, node_type, node_group));
    //  println("Add P2 with id " + node_id);
      break;   
    case "PF":   // Meander:  Post One and Finial Two
      nodes.put(node_id, new PostOneFinialTwo(node_id, dlnode, node_type, node_group));
    //  println("Add PF with id " + node_id);
      break;   
    case "RH":   // Meander:  River Head
      nodes.put(node_id, new RiverHead(node_id, dlnode, node_type, node_group));
    //  println("Add RH with id " + node_id);
      break;   
    case "SU":
      nodes.put(node_id, new SSSUnit(node_id, dlnode, node_type, node_group));
    //  println("Add SU with id " + node_id);
      break;
    case "BP":
      nodes.put(node_id, new BreathingPore(node_id, dlnode, node_type, node_group));
    //  println("Add BP with id " + node_id);
      break;
    case "GN":
      nodes.put(node_id, new GridEyeNode(node_id, dlnode, node_type, node_group));
    //  println("Add GN with id " + node_id);
      break;
    default:
        println("Unknown node type " + node_type + " with id " + node_id + ", using RH instead for now.");
        nodes.put(node_id, new RiverHead(node_id, dlnode, "RH", node_group));
        println("Add RH with id " + node_id);
   
      break;
    }
    if(!rpis.get(rpi_address).children_nodes.contains(node_id))
      rpis.get(rpi_address).children_nodes.add(node_id);
  }

  synchronized public ArrayList<Integer> get_node_type_ids(String node_type)
  {
    ArrayList<Integer> list_of_nodes = new ArrayList<Integer>();
    for (Node node : nodes.values())
    {
      if (node.type.equals(node_type))
        list_of_nodes.add(node.node_id);
    }

    return list_of_nodes;
  }

  synchronized public ArrayList<Integer> get_node_group_ids(String ngroup)
  {
    ArrayList<Integer> list_of_nodes = new ArrayList<Integer>();
    for (Node node : nodes.values())
    {
      if (node.node_group.equals(ngroup))
        list_of_nodes.add(node.node_id);
    }

    return list_of_nodes;
  }

  /*!
   Adds either an actuator or sensor to the device data structures.
   */
  synchronized private boolean add_device(String name, String type, int number, int uid, float x, float y, float z, int node_id, boolean inst, String config)
  {

    String node_type = get_node_type(node_id);
    int index = add_device_to_node_type(type, number, node_type);

    // HACK to treat some device types as others eg: PC as RS or MM as MO
    switch(type)
    {
            case "MM":
              type = "MO";
            default:
            break;
    }

    if(uid < 0)
    {
      println("ERROR: device " + name + " has a negative UID. Please fix in csv. Continuing...");
      return false;
    }

    List uids = dlnodestorage.all_uids.get(node_type);
    List uid_types = dlnodestorage.all_uid_types.get(node_type);
    List devs = dlnodestorage.all_devs.get(node_type);
    List coordinates = dlnodestorage.all_coordinates.get(node_id);
    List names = dlnodestorage.all_names.get(node_id);
    List configs = dlnodestorage.all_configs.get(node_id);
    List installed = dlnodestorage.all_installed.get(node_id);

    // if(debug)    
      // println(" adding device (" + type + ") to " + node_id + " ("+ node_type + ") index: " + index + " uid: " + uid);
 
      while (uids.size() < (index + 1))
      {
      // set the list to size
        uids.add(-1);
      }
  
      while (uid_types.size() < uids.size())
      {
        uid_types.add("");
      }   


      while (coordinates.size() < uids.size())
      {
        coordinates.add(null);
      }

      while (names.size() < uids.size())
      {
        names.add("");
      }


      while (configs.size() < uids.size())
      {
        configs.add("");
      }


      while (installed.size() < uids.size())
      {
        installed.add(false);
      }

      if (!uids.contains(uid))
      {
        uids.set(index, uid);
        uid_types.set(index, type);
      }
      coordinates.set(index, new PVector(x, -y, z));   // flip coordinates to sync with real world 
      names.set(index, name);
      configs.set(index, config);
      installed.set(index, inst);
      num_actuators++;
      return true;
  }

  synchronized public boolean set_device_config(int node_id, String dev_name, String config) {

    List configs = dlnodestorage.all_configs.get(node_id);
    List names = dlnodestorage.all_names.get(node_id);

    int index = names.indexOf(dev_name);

    if(index > -1) {

//      println("Setting config for " + dev_name + " on " + node_id + " to " + config);
      configs.set(index, config);
      return true;

    } else {

      println("ERROR: device named " + dev_name + " not found on node " + node_id + " while setting config.");

      return false;

    }

  }


  synchronized public boolean node_exists(int node_id)
  {
    return dlnodestorage.node_ids.contains(node_id);
  }


  synchronized public Integer[] get_node_ids()
  {
    List<Integer> node_ids = dlnodestorage.node_ids;

    Integer[] to_return = new Integer[node_ids.size()];
    for (int i = 0; i < node_ids.size(); i++)
    {
      to_return[i] = node_ids.get(i);
    }

    return to_return;
  }


  synchronized public int get_num_nodes()
  {
    return dlnodestorage.node_ids.size();
  }


  /*!
   \returns A string array of the types of actuators/sensors connected to node_type. The order is the same as the other get_[] functions that return arrays
   */
  synchronized public String[] get_types(String node_type)
  {
    List<String> types = dlnodestorage.all_uid_types.get(node_type);

    String[] to_return = new String[types.size()];
    for (int i = 0; i < types.size(); i++)
    {
      to_return[i] = types.get(i);
    }
    return to_return;
  }

  /*!
   \returns An integer array of the uids of actuators/sensors connected to node_type. The order is the same as the other get_[] functions that return arrays
   */

  synchronized public int[] get_uids(String node_type)
  {

    List<Integer> uids = dlnodestorage.all_uids.get(node_type);

    int[] to_return = new int[uids.size()];

    for (int i = 0; i < uids.size(); i++)
    {
      to_return[i] = uids.get(i);
    }
    return to_return;
  }

  /*!
   \returns A PVector (coordinate) array of the coordinates of the actuators/sensors connected to <i>node_id</i>. The order is the same as the other get_[] functions that return arrays
   */

  synchronized public PVector[] get_coordinates(int node_id)
  {
    List<PVector> coordinates = dlnodestorage.all_coordinates.get(node_id);
    PVector[] to_return = new PVector[coordinates.size()];

    for (int i = 0; i < coordinates.size(); i++)
    {
      to_return[i] = coordinates.get(i);
    }

    return to_return;
  }

  /*!
   \returns A String array of the names the actuators/sensors connected to <i>node_id</i>. The order is the same as the other get_[] functions that return arrays
   */

  synchronized public String[] get_names(int node_id)
  {
    List<String> names = dlnodestorage.all_names.get(node_id);
    Iterator<String> iter = names.iterator();    
    String[] to_return = new String[names.size()];

    for (int i = 0; i < names.size(); i++)
    {
      to_return[i] = names.get(i);
    }
    return to_return;
  }

  synchronized public String[] get_configs(int node_id)
  {
    List<String> configs = dlnodestorage.all_configs.get(node_id);
    String[] to_return = new String[configs.size()];
    for (int i = 0; i < configs.size(); i++)
    {
      to_return[i] = configs.get(i);
    }

    return to_return;
  }


  synchronized public boolean[] get_installed(int node_id)
  {
    List<Boolean> installed = dlnodestorage.all_installed.get(node_id);
    boolean[] to_return = new boolean[installed.size()];
    for (int i = 0; i < installed.size(); i++)
    {
      to_return[i] = installed.get(i);
    }

    return to_return;
  }




  synchronized public ArrayList<String> get_rpi_addresses()
  {
    ArrayList<String> ip_addresses = new ArrayList<String>();
    for (String key : rpis.keySet())
    {
      ip_addresses.add(key);
    }
    return ip_addresses;
  }

  synchronized public ArrayList<String> get_node_addresses()
  {
    ArrayList<String> addresses = new ArrayList<String>();
    for (Integer key : nodes.keySet())
    {
      addresses.add(Integer.toString(key));
    }

    return addresses;
  }


  synchronized public String[] get_devs(String node_type)
  {
    List<String> devices = dlnodestorage.all_devs.get(node_type);
    String[] to_return = new String[devices.size()];
    for (int i = 0; i < devices.size(); i++)
    {
      to_return[i] = devices.get(i);
    }

    return to_return;
  }


  synchronized public int get_moth_index(int moth_number, String node_type)
  {
    // helper for getting indices of certain types of actuator

    return( get_device_index("MO", moth_number, node_type));
  }

  synchronized public int get_SMA_index(int SMA_number, String node_type)
  {
    // helper for getting indices of certain types of actuator

    return( get_device_index("SM", SMA_number, node_type));
  }
  
  synchronized public int get_rs_index(int rs_number, String node_type)
  {
    // helper for getting indices of certain types of actuator

    return( get_device_index("RS", rs_number, node_type));
  }

  synchronized public int get_pc_index(int pc_number, String node_type)
  {
    // helper for getting indices of certain types of actuator

    return( get_device_index("PC", pc_number, node_type));
  }

  synchronized public int get_wt_index(int wt_number, String node_type)
  {
    // helper for getting indices of certain types of actuator

    return( get_device_index("WT", wt_number, node_type));
  }

  /*!
   \returns The physical uid number that the actuator is connected to for a particular node_id 
   */
  synchronized public int get_actuator_uid(String actuator_type, int actuator_number, int node_id)
  {
    int act_index = get_device_index(actuator_type, actuator_number, dlnodestorage.get_node_type(node_id));
    int uid = dlnodestorage.all_uids.get(dlnodestorage.get_node_type(node_id)).get(act_index);
    return uid;
  }

  synchronized public int add_device_to_node_type(String device_type, int number, String node_type) {

      if (number < 0) return -1;

      // if it already exists, return its index
      int index = get_device_index(device_type, number, node_type);
//      println("index is showing " + index + " for " + device_type + number + " on " + node_type);
      if(index >= 0) return index;

      // if not, add it.
      String designator = device_type + Integer.toString(number);
      dlnodestorage.all_devs.get(node_type).add(designator);
      return(dlnodestorage.all_devs.get(node_type).indexOf(designator));

  }

  synchronized private int get_device_index(String device_type, int number, String node_type)
  {
    if (number < 0) return -1;

    String designator = device_type + Integer.toString(number);
    return get_device_index(designator, node_type);
  }

  synchronized private int get_device_index(String designator, String node_type) 
  {
     return(dlnodestorage.all_devs.get(node_type).indexOf(designator));
  }

  synchronized public int get_sensor_uid(String sensor_type, int sensor_number, int node_id)
  {
    int sen_index = get_device_index(sensor_type, sensor_number, get_node_type(node_id));
    int uid = dlnodestorage.all_uids.get(dlnodestorage.get_node_type(node_id)).get(sen_index);
    return uid;
  }

  // this is really confusing, these three functions do the same thing but in different ways. 

  synchronized public String get_node_type(int node_id)
  {
    int node_index = dlnodestorage.node_ids.indexOf(node_id);
    if (node_index >= 0)
    {
      return dlnodestorage.node_types.get(node_index);
    } 

    return "";
  }


  synchronized ArrayList<String> get_all_actuator_types()
  {
    ArrayList<String> act_types = new ArrayList<String>();

    for (Node node : nodes.values())
    {
      for (int i = 0; i < node.ACTUATOR_ARR_SIZE; i++)
      {
        if (node.my_moths[i].installed)
          act_types.add("MO");
      }
      
      for (int i = 0; i < node.ACTUATOR_ARR_SIZE; i++)
      {
        if (node.my_smas[i].installed)
          act_types.add("SM");
      }

      for (int i = 0; i < node.DR_ARR_SIZE; i++)
      {
        if (node.my_double_rebel_stars[i].installed)
          act_types.add("DR");
      }      

      for (int i = 0; i < node.ACTUATOR_ARR_SIZE; i++)
      {
        if (node.my_rebel_stars[i].installed)
          act_types.add("RS");
      } 

      for (int i = 0; i < node.ACTUATOR_ARR_SIZE; i++)
      {
        if (node.my_protocells[i].installed)
          act_types.add("PC");
      } 

      for (int i = 0; i < node.WT_ARR_SIZE; i++)
      {
        if (node.my_wav_triggers[i].installed)
            act_types.add("WT");
      }
    }

    return act_types;
  }
  // TODO - @Matt, why's this commented out?
  synchronized PVector get_all_actuator_centerpoint() 
  {
    //PVector centerpoint = new PVector( x_range[0] + x_range[1] / 2, 
    //  y_range[0] + y_range[1] / 2, 
    //  z_range[0] + z_range[1] / 2 );
    //    act_coords.add(node.my_double_rebel_stars[i].position);

    return new PVector(0, 0, 0);
  }

/*!
  Returns a hashmap of keys  <nodeid>:<device> (eg 324521:MO2 ) and values: PVector coordinates.  
  Matches up to two things - eg. "TG" and "DR" is only the DRs from TG.  
 */
  synchronized HashMap<String, PVector> get_actuator_coordinates_by_name(String match) {

    return(get_actuator_coordinates_by_name(match, ":")); // if only one string provided, use ":" as "everything" since all names have ':' in them.

  }

  synchronized HashMap<String, PVector> get_actuator_coordinates_by_name(String match1, String match2) {
     HashMap<String, PVector> act_coords = new HashMap<String, PVector>();

    for (Node node : nodes.values())
    {
      for (int i = 0; i < node.ACTUATOR_ARR_SIZE; i++)
      {
        if (node.my_moths[i].installed && (node.my_moths[i].name.contains(match1) && node.my_moths[i].name.contains(match2)))
        act_coords.put(str(node.node_id)+":"+node.my_moths[i].designator.get_identifier_string(), node.my_moths[i].position);
      }
      
      for (int i = 0; i < node.ACTUATOR_ARR_SIZE; i++)
      {
        if (node.my_smas[i].installed && (node.my_smas[i].name.contains(match1) && node.my_smas[i].name.contains(match2)))
        act_coords.put(str(node.node_id)+":"+node.my_smas[i].designator.get_identifier_string(), node.my_smas[i].position);
      }

      for (int i = 0; i < node.DR_ARR_SIZE; i++)
      {
        if (node.my_double_rebel_stars[i].installed && (node.my_double_rebel_stars[i].name.contains(match1) && node.my_double_rebel_stars[i].name.contains(match2)))
        act_coords.put(str(node.node_id)+":"+node.my_double_rebel_stars[i].designator.get_identifier_string(), node.my_double_rebel_stars[i].position);
      }      

      for (int i = 0; i < node.ACTUATOR_ARR_SIZE; i++)
      {
         if (node.my_rebel_stars[i].installed && (node.my_rebel_stars[i].name.contains(match1) && node.my_rebel_stars[i].name.contains(match2)))
        act_coords.put(str(node.node_id)+":"+node.my_rebel_stars[i].designator.get_identifier_string(), node.my_rebel_stars[i].position);
     }

      for (int i = 0; i < node.ACTUATOR_ARR_SIZE; i++)
      {
        if (node.my_protocells[i].installed && (node.my_protocells[i].name.contains(match1) && node.my_protocells[i].name.contains(match2)))
        act_coords.put(str(node.node_id)+":"+node.my_protocells[i].designator.get_identifier_string(), node.my_protocells[i].position);

      }

      for (int i = 0; i < node.WT_ARR_SIZE; i++)
      {
        if (node.my_wav_triggers[i].installed && (node.my_wav_triggers[i].name.contains(match1) && node.my_wav_triggers[i].name.contains(match2)))
        act_coords.put(str(node.node_id)+":"+node.my_wav_triggers[i].designator.get_identifier_string(), node.my_wav_triggers[i].position);
     }
    }

    return(act_coords);

  }


  synchronized ArrayList<PVector> get_all_actuator_coordinates()
  {
    ArrayList<PVector> act_coords = new ArrayList<PVector>();

    // Ensure that this order is consistent!

    for (Node node : nodes.values())
    {
      for (int i = 0; i < node.ACTUATOR_ARR_SIZE; i++)
      {
        if (node.my_moths[i].installed)
          act_coords.add(node.my_moths[i].position);
      }
      
      for (int i = 0; i < node.ACTUATOR_ARR_SIZE; i++)
      {
        if (node.my_smas[i].installed)
          act_coords.add(node.my_smas[i].position);
      }

      for (int i = 0; i < node.DR_ARR_SIZE; i++)
      {
        if (node.my_double_rebel_stars[i].installed)
          act_coords.add(node.my_double_rebel_stars[i].position);
      }      

      for (int i = 0; i < node.ACTUATOR_ARR_SIZE; i++)
      {
        if (node.my_rebel_stars[i].installed)
          act_coords.add(node.my_rebel_stars[i].position);
      }

      for (int i = 0; i < node.ACTUATOR_ARR_SIZE; i++)
      {
        if (node.my_protocells[i].installed)
          act_coords.add(node.my_protocells[i].position);
      }

      for (int i = 0; i < node.WT_ARR_SIZE; i++)
      {
        if (node.my_wav_triggers[i].installed)
          act_coords.add(node.my_wav_triggers[i].position);
      }
    }

    return act_coords;
  }
  
  synchronized int get_total_num_actuators() 
  {
    return num_actuators;
  }

  synchronized ArrayList<PVector> get_coordinates_for_type(String type, int node_id)
  {

    List<PVector> coordinates = dlnodestorage.all_coordinates.get(node_id);
    List<String> types = dlnodestorage.all_uid_types.get(dlnodestorage.get_node_type(node_id));
    ArrayList<PVector> types_to_return = new ArrayList<PVector>();

    for (int i = 0; i < coordinates.size(); i++)
    {
      if (types.get(i).equals(type))
      {
        types_to_return.add(coordinates.get(i));
      }
    }

    return types_to_return;
  }


  void generate_dot_h() 
  {
    generate_dot_h("ALL"); 
  }

  void generate_dot_h(String ngroup) 
  {
    String fn = "../Node_World/DeviceLocator.h";
    if(!ngroup.equals("ALL")) fn = "../Node_World_DLs/DeviceLocator_"+ ngroup +".h";
    PrintWriter output = createWriter(fn);
    DecimalFormat df = new DecimalFormat("#.##");
    DateFormat dateFormat = new SimpleDateFormat("MM/dd HH:mm:ss");
    Date date = new Date();
    df.setRoundingMode(RoundingMode.UP);

    output.print("/* "+ ngroup + " DOT H FILE AUTOGENERATED FROM CSV FILE: " + file_name + " at " + dateFormat.format(date) + "*/\n\n");

    // headers and class definition
    output.print("#include <Arduino.h>\n#include <stdint.h>\n#ifndef DEVICE_LOCATOR_H_\n#define DEVICE_LOCATOR_H_\n");

    //TODO- hack to generate GE and SD boolean and float arrays on the C++
    output.print("#define NUM_GE " + num_GE + "\n");
    output.print("#define NUM_SD " + num_SD + "\n");
    output.print("#define NUM_IR " + num_IR + "\n");

    //section types
    output.print("\n     //Node types\n ");

    Iterator<String> itr = unique_node_types.iterator();
    int num_track = 0;
    while(itr.hasNext())
    {
      String node_short_code = itr.next();
      if(!node_short_code.equals("")) //  && (ngroup.equals(node_short_code) || ngroup.equals("ALL")) )
        output.print("#define type_" + node_short_code + " " + num_track++ + "\n");
    }

    // output.print("#define type_SU 0\n#define type_HU 1\n#define type_GN 2\n#define type_RU 3\n#define type_UNKNOWN 98\n#define type_test 99\n");

    output.print("\n// UIDs for each type of node. Assumes that actuators on nodes of the same type have identical uid locations (pinouts)\n\n");  // uid locations == pinouts

    itr = unique_device_types.iterator();
    num_track = 0;
    while(itr.hasNext())
    {
      String act_short_code = itr.next();
      if(!act_short_code.equals(""))
        output.print("#define type_" + act_short_code + " " + num_track++ + "\n");
    }
    output.print("#define type_UNKNOWN " + num_track++ + "\n");

    output.print("class DeviceLocator{\n");
    output.print("  public:\n DeviceLocator();\n    ~DeviceLocator();\n");

    List  node_group_ids = new ArrayList<Integer>();

    // generate the subset list for this node type (or all if it's generic)
    if(ngroup.equals("ALL")) node_group_ids = dlnodestorage.node_ids;
    else                     node_group_ids = get_node_group_ids(ngroup);  // this needs to change to a list of all node_IDs in the given GROUP not type. (stop using ngroups and use groups)

    int num_nodes = node_group_ids.size();

    output.print("int num_nodes = " + num_nodes + ";\n");
    output.print("long node_ids[" + num_nodes + "] = {\n\t\t\t\t");

    for (int i = 0; i < num_nodes; i++)
    {
       output.print(node_group_ids.get(i));
      if (i < num_nodes - 1)
      {
        output.print(",\t\t\t//  "+ i + "\n");
        output.print("\t\t\t\t");
      }
    }

    output.print("\n\t\t\t\t};\n");

    output.print("int node_types[" + num_nodes +  "] = {\n\t\t\t\t");
    for (int i = 0; i < num_nodes; i++)
    {
      if(ngroup.equals("ALL"))
      output.print("type_" + dlnodestorage.node_types.get(i));
      else
      output.print("type_" + dlnodestorage.get_node_type((int)node_group_ids.get(i)));

      if (i < num_nodes - 1)
      {
        output.print(",\t\t\t//  "+ i + "\n");
        output.print("\t\t\t\t");
      }
    }
    output.print("\n\t\t\t\t};\n");

    int max_uids = 0;

    for (int j = 0; j < unique_node_types.size(); j++)
    {
      String node_type = unique_node_types.get(j);

      String[] types = get_types(node_type);
      int[] uids = get_uids(node_type);
      if (uids.length != types.length)
      {
        println("uids and type length mismatch");
        println(uids);
        println(types);
        // return;
      }

      if(uids.length > max_uids) max_uids = uids.length;

      output.print("int " + node_type + "_uids_num = " + types.length + ";\n");

      output.print("int " + node_type + "_uids[" + types.length + "] = {");
      for (int k = 0; k < uids.length; k++)
      {
        output.print(uids[k]);
        if (k < uids.length - 1)
        {
          output.print(", ");
        }
      }
      output.print("};\n");

      output.print("int " + node_type + "_uids_types[" + types.length + "] = {");
      for (int k = 0; k < types.length; k++)
      {
        if (types[k] != "") 
          output.print("type_" + types[k]);
        else
          output.print("type_UNKNOWN");
        if (k < types.length - 1)  
        {        
          output.print(", ");
        }
      }
      output.print("};\n");  
    }        

    output.print("int max_uids = " + max_uids + ";\n");

    ///  DON'T USE COORDS FOR NOW TO SAVE ROOM AND TIME
    // coordinates 
  //   output.print("float coordinates[" + num_nodes + "][" + max_uids + "][3] = {");        
  //   for (int i = 0; i < node_group_ids.size(); i++) 
  //   {
  //     output.print("{");
  // //    println("node_group_ids.get("+i+") is " + node_group_ids.get(i) );
  //     List<PVector> coordinates = dlnodestorage.all_coordinates.get((int)(node_group_ids.get(i))); 
  //     // println(coordinates.size());        
  //     for (int j = 0; j < coordinates.size(); j++)
  //     {
  //       if (coordinates.get(j) != null)
  //       {
  //         output.print("{" + df.format(coordinates.get(j).x) + "," + df.format(coordinates.get(j).y) + "," + df.format(coordinates.get(j).z) + "}");
  //       } else 
  //       {
  //         output.print("{0,0,0}");
  //       }
  //       if (j < max_uids - 1)
  //       {
  //         output.print(", ");
  //       }
  //     }

  //     for (int j = coordinates.size(); j < max_uids; j++)
  //     {
  //       output.print("{0,0,0}");
  //       if (j < max_uids - 1)
  //       {
  //         output.print(", ");
  //       }
  //     }

  //     output.print("}");
  //     if (i < node_group_ids.size() - 1)
  //     {
  //       output.print(",\n");
  //     }
  //   }
  //   output.print("\n};");


    output.print("\n // PROGMEM array of Actuator Numbers (my_XXX index + 1 eg. MO3 will become my_moths[2].  This stores the '3' as a PROGMEM int)");
    output.print("\n // if they are not in that type [_] or not installed [x], they get '0', so it's important not to use zero as a device number.");
    output.print("\n // stored as a single array of ints that is num_nodes x max_uids (max number of UIDs in a node - called arr_size in Teensy code) large.");
    output.print("\n // These are read by looking at the one at (node.my_index x act_index))");

    output.print("\n const uint8_t device_numbers[" + (node_group_ids.size() * max_uids) + "] PROGMEM = {");
    
    for (int i = 0; i < node_group_ids.size(); i++)
    {
      output.print("\n // " + node_group_ids.get(i) + " \t " + dlnodestorage.get_node_type((int)node_group_ids.get(i)));
      output.print("\n //" );
      List<String> names = dlnodestorage.all_names.get((int)(node_group_ids.get(i)));

      // print commented out labels;
      for (int j = 0; j < names.size(); j++)
      {
        String des = "[x]";
        if(names.get(j).lastIndexOf("_") > 0) des = names.get(j).substring(names.get(j).lastIndexOf("_")+1);
        output.print(" " + des);
        if (j < max_uids - 1)
        {
          output.print(", ");
        }
      }
      for (int j = names.size(); j < max_uids; j++)
      {
        output.print(" [_]");
        if (j < max_uids - 1)
        {
          output.print(", ");
        }
      }

      output.print("\n    ");

      // print actual values

      for (int j = 0; j < names.size(); j++)
      {
        String des = "0";
        if(names.get(j).lastIndexOf("_") > 0) des = names.get(j).substring(names.get(j).lastIndexOf("_")+3);
        output.print(" " + des);
        if (j < max_uids - 1)
        {
          output.print(", ");
        }
      }
      for (int j = names.size(); j < max_uids; j++)
      {
        output.print("0");
        if (j < max_uids - 1)
        {
          output.print(", ");
        }
      }

      if (i < node_group_ids.size() - 1)
      {
        output.print(",\n");
      }
    }
    output.print("\n  };");


    //  DON'T USE CONFIG STRINGS FOR NOW IN .H (INCLUDING SECONDARY PINS) - SEND THEM AS MESSAGES ONCE THE OBJECT IS SET UP

    // output.print("\nString configs[" + num_nodes + "][" + max_uids + "] = {");
    // for (int i = 0; i < node_group_ids.size(); i++)
    // {
    //   output.print("{");
    //   List<String> configs = dlnodestorage.all_configs.get((int)(node_group_ids.get(i)));

    //   for (int j = 0; j < configs.size(); j++)
    //   {
    //     output.print("\"" + configs.get(j) + "\"");
    //     if (j < max_uids - 1)
    //     {
    //       output.print(", ");
    //     }
    //   }
    //   for (int j = configs.size(); j < max_uids; j++)
    //   {
    //     output.print("\"\"");
    //     if (j < max_uids - 1)
    //     {
    //       output.print(", ");
    //     }
    //   }

    //   output.print("}");
    //   if (i < node_group_ids.size() - 1)
    //   {
    //     output.print(",\n");
    //   }
    // }
    // output.print("\n};");

    output.print("\n};");
    output.print("\n#endif DEVICE_LOCATOR_H_");

    output.flush();
    output.close();
  }

    void generate_dot_hexmap(boolean split)
  {
    PrintWriter output = createWriter("../RPi_World/data/" + file_name + ".hexmap");
    PrintWriter dlselect = createWriter("../RPi_World/data/device_locator_select");

    dlselect.write(file_name);  // Used to include + ".hexmap" but now that's done by the script.
    if(split)  dlselect.write(" yes"); else dlselect.write(" no");
    dlselect.flush();
    dlselect.close();

    for (int i = 0; i < unique_groups.size(); i++)
    {
       ArrayList<Integer> nodesingroup = get_node_group_ids(unique_groups.get(i));
       for(int j = 0; j < nodesingroup.size() ; j++)
       {
          String nt = (get_node_type(nodesingroup.get(j)));
          if(!nt.equals("GN")) {
           output.print(Integer.toString(nodesingroup.get(j)) + Integer.toString(0));
           output.print(":");
           output.print(unique_groups.get(i) + ".hex");
           output.print("\n");
          }
       }
    }

    // now add grideye nodes (if any):
    //boolean first_one = true;
    for (int i = 0; i < dlnodestorage.node_ids.size(); i++)
    {
      String nt = (dlnodestorage.node_types.get(i));
      if(nt.equals("GN")) {
      //   if (!first_one)
      //   {
      //    output.print("\n");
      //   }
      output.print(Integer.toString(dlnodestorage.node_ids.get(i)) + Integer.toString(0));
      output.print(":");
      output.print(nt + ".hex");
      output.print("\n");
      // first_one = false;
      }
    }
    
    output.flush();
    output.close();
  }

  void generate_master_hexlist()
  {
    PrintWriter output = createWriter("../RPi_World/data/" + file_name + ".hexlist");

    for (int i = 0; i < unique_groups.size(); i++)
    {
      
      output.print(unique_groups.get(i) + ".hex");

      if (i < unique_groups.size())
      {
        output.print("\n");
      }
    }
    output.flush();
    output.close();
  }

  void generate_master_pilist()
  {
    PrintWriter output = createWriter("../RPi_World/data/" + file_name + ".pilist");

    ArrayList<String> pi_addrs = get_rpi_addresses();

    for(String addr : pi_addrs)
    {
      
//      output.print(addr.substring(addr.lastIndexOf('.')+1) + " ");  // need to get the last part of IP here.
      output.print(addr);  // need to get full IP here.
      output.print("\n");

    }
    output.flush();
    output.close();
  }
}

/*!
 This class stores information in Arrays similiar to how they are stored in the dot h files. This is to ensure we can make similar function calls in the
 processing and the C++.
 */
private class DeviceLocatorNodeStorage 
{
  // this class is simply here for data organization

  ArrayList<Integer> node_ids = new ArrayList<Integer>();
  ArrayList<String>  node_types = new ArrayList<String>();

  ListMultimap<String, Integer>   all_uids        = ArrayListMultimap.create(1, 1);  // device UIDs (pins) by node type;
  ListMultimap<String, String>    all_uid_types   = ArrayListMultimap.create(1, 1);  // device types by node type;
  ListMultimap<String, String>    all_devs        = ArrayListMultimap.create(1, 1);  // device designators by node type (redundant but useful)
  ListMultimap<Integer, String>   all_names       = ArrayListMultimap.create(1, 1);  // device names by node ID
  ListMultimap<Integer, PVector>  all_coordinates = ArrayListMultimap.create(1, 1);  // device cords by node ID
  ListMultimap<Integer, String>   all_configs     = ArrayListMultimap.create(1, 1);  // device configs by node ID
  ListMultimap<Integer, Boolean>  all_installed   = ArrayListMultimap.create(1, 1);  // device installed? by node ID

  DeviceLocatorNodeStorage()
  {
  }

  synchronized boolean node_type_exists(String node_type)
  {
    if (all_uids.containsKey(node_type) && all_uid_types.containsKey(node_type) && all_devs.containsKey(node_type))
    { 
      return true;
    }  
    return false;
  }
 
  synchronized String get_node_type(int node_id)
  {
    int i = 0;
    while (node_ids.get(i) != node_id && i < node_ids.size())
    {
      i++;
    } 

    if (node_ids.get(i) != node_id)
    {
      // check for invalid state 
      return "";
    }
    return node_types.get(i);
  }

  synchronized String get_uid_type(int uid, int node_id)
  {
    List<Integer> uids = all_uids.get(get_node_type(node_id));
    List<String> uid_types = all_uid_types.get(get_node_type(node_id));
    int index = uids.indexOf(uid);

    if (index != -1)
    {
      return uid_types.get(index);
    } else 
    {
      return "";
    }
  }
}

/*!
 \todo Consider moving ALL control related stuff here, so anything with the word control can be easily commented out in the Pi
 */
private class DeviceLocatorControl 
{
}

/*!
 This is a helper class that helps translate the complicated dl information into arrays that the node can work with
 */

private class DeviceLocatorNode
{
  DeviceLocator dl;

  DeviceLocatorNode(DeviceLocator dl)
  {
    this.dl = dl;
  }

  int get_num_nodes()
  {
    return dl.get_num_nodes();
  }

  int get_arr_len(int node_id)
  {
    String type = dl.get_node_type(node_id);
    if (!type.equals(""))
      return dl.get_names(node_id).length;  
    return -1;
  }

  String[] get_types(int node_id)
  {
    String type = dl.get_node_type(node_id);
    return dl.get_types(type);
  }

  int[] get_uids(int node_id)
  {
    String type = dl.get_node_type(node_id);
    return dl.get_uids(type);
  }

  PVector[] get_coordinates(int node_id)
  {
    return dl.get_coordinates(node_id);
  }

  String[] get_names(int node_id)
  {
    return dl.get_names(node_id);
  }

  String[] get_configs(int node_id)
  {
    return dl.get_configs(node_id);
  }

  boolean node_exists(int node_id)
  {
    return dl.node_exists(node_id);
  }

}
