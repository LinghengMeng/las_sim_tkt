/*

FLOWFIELD

This behaviour creates a set of vectors in space that influence particles that flow based on them


\Author: Poul Holleman & Matt Gorbet ©2019-2020


TODO
- Experiment with Vectors being coupled to Sculpture Structure

*/


///   GENERAL VARIABLES FOR ALL FLOW FIELDS (used by RiverHeads and River FlowFields)

class FlowFieldVars extends BehaviourEngineVars {

  int edgeRange, respawnRange, particleCount, ff_update_rate, sculptmode;
  float flowInfluenceScalar, maxSpeed, threshold, core_size, perlinOffsetInc, randomForceAmount, masterIntensity;
  boolean display, displayVecs, displayBorders, showNearestVecLines, showParticleOrientation, use_grid_vectors, influenceActive;


  FlowFieldVars() {

      super("FlowField", false);
  }

  void init() {

    /*
    Particle Count is the amount of Particles that flow through the field - not used any more Aug 2020
    */
    particleCount = 0;

    /*
    Multiplies the force of the flowfield onto this particle
    */
    //flowInfluenceScalar = 5;
    flowInfluenceScalar = 5;

    /*
    Set the Max Speed a Particle can have
    */ 
    maxSpeed = 1;
    edgeRange = 1000;
    respawnRange = 500;

    /*
    The threshold sets at which distance between 
    Particle and Actuator the Actuator gets influenced,
    it's a distance based algorithm that defines the sphere of influence
    */
    threshold = 275;
    core_size = 0.5;

    perlinOffsetInc = 0.005;

    randomForceAmount = 0.5;
    
    masterIntensity =  1.0;

    display = true;
    influenceActive = false;

    showParticleOrientation = true;

    showNearestVecLines = true;

    displayVecs = false;
    displayBorders = false;
    sculptmode = 2;  // 1 is magnetic, 2 is path

    use_grid_vectors = true;
    neverSave = true;
  }
}




class FlowField extends Thread{

  RiverFlowVectorSystem riverFlowField;

  HashMap<String, PVector> relevantActuators = new HashMap<String, PVector>();      // determined at startup by using name filtering - eg. only DRs, or just part of the sculpture
  HashMap<String, Float>   actuatorInfluences = new HashMap<String, Float>();       // this will have the same keys as relevantActuators:  <node_id>:<device> eg: 322345:MO3


  FlowField(DeviceLocator dl, String actuator_mask) {

    // name thread:
    super("FlowField_" + actuator_mask + "_thread");

    /*
    Get the relevant actuator hashmap (name and PVec of location)
    */
    relevantActuators.putAll(dl.get_actuator_coordinates_by_name(actuator_mask));
    riverFlowField = new RiverFlowVectorSystem( new ArrayList<PVector>(relevantActuators.values()), actuator_mask );

  }

  void run() {         // flowField
   while(true) {

    try{
      Thread.sleep(flowFieldVars.thread_update_rate + time_lapse_pause);
    } catch (Exception e) {
      println(e);
    }

    riverFlowField.update();
  
   }
  }

  synchronized public void clearActuatorInfluences() {

    try {
      for(Map.Entry<String, PVector> e : relevantActuators.entrySet()) {
                actuatorInfluences.put(e.getKey(), 0.0);
      }
    } catch (Exception x) {
      println(x);
    }
  }

  synchronized public void display() {         // flowField

//    if(flowFieldVars.display) {
      riverFlowField.display();
 //   }

  }

  synchronized public void save(String scene) {
    riverFlowField.save_vectors_json(scene);
  }

  synchronized public void load(String scene) {
    riverFlowField.load_vectors_json(scene);
  }

}


/////////   RIVER FLOW VECTOR SYSTEM

class RiverFlowVectorSystem {

  PVector loc;
  ArrayList<FlowVector> flowVectors;
  float dim, spacing;

  // PShape allVectors;

  PVector sCorner, eCorner;  // startcorner and endcorner

  String name;

 
  RiverFlowVectorSystem(List<PVector> coords, String _name) {

    //this constructor receives an arrayList of coordinates of relevant actuators to us as seeds for the vector field

    flowVectors = new ArrayList<FlowVector>();

    // allVectors = createShape(GROUP);

    name = _name;

    sCorner = new PVector();   
    eCorner = new PVector();   // set the bounds to the very first position
    sCorner = coords.get(0).copy();   
    eCorner = coords.get(0).copy();   // set the bounds to the very first position

    int v_index = 0;

    for (PVector vpos : coords) {

      sCorner.x = min(vpos.x, sCorner.x);
      sCorner.y = min(vpos.y, sCorner.y);
      sCorner.z = min(vpos.z, sCorner.z);

      eCorner.x = max(vpos.x, eCorner.x);
      eCorner.y = max(vpos.y, eCorner.y);
      eCorner.z = max(vpos.z, eCorner.z);

      FlowVector v = new FlowVector(vpos, v_index);

      flowVectors.add(v);
      // v.vecShape.setVisible(true);
      // allVectors.addChild(v.vecShape);
      // allVectors.setVisible(true);

      v_index++;
   
    }

    if( flowFieldVars.use_grid_vectors ) {
       flowVectors.clear();
       createRegularVectorGrid( new PVector(15, 8, 3), sCorner, eCorner);
    }



  }

  void createRegularVectorGrid( PVector dimXYZ, PVector startCorner, PVector endCorner) {
    
    // divide the bounding range by dim of each axis and space vectors accordingly

    float[] spacing = {0.0,0.0,0.0};

    //Get spacing on each axis
    for(int i=0;i<3;i++){
      float dist = endCorner.array()[i]- startCorner.array()[i];
      float axisSpacing = dist / dimXYZ.array()[i]-1;
      spacing[i] = axisSpacing;
    }

    int v_index = 0;

    for (int i=-1; i<dimXYZ.array()[0]+1;i++){
      for (int j=-1; j<dimXYZ.array()[1]+1; j++){
        for (int k=-1; k<dimXYZ.array()[2]+1; k++){
          PVector newFlowVecLoc = new PVector(spacing[0]*i, spacing[1]*j, spacing[2]*k).add(startCorner);
          
          flowVectors.add(new FlowVector(newFlowVecLoc, v_index));
          v_index++;
        }
      }
    }


  }


  synchronized void update() {
    try{
      for (FlowVector flowVec : flowVectors) {
        flowVec.update();
      }
    } catch(Exception e) {
      println(e);
    }
  }

  synchronized void display(){

    if(flowFieldVars.displayBorders) {
    // draw bounding box:
    pushStyle();
    stroke(255, 30);
    strokeWeight(2);
    line(sCorner.x, sCorner.y, sCorner.z, eCorner.x, sCorner.y, sCorner.z);
    line(sCorner.x, sCorner.y, sCorner.z, sCorner.x, eCorner.y, sCorner.z);
    line(sCorner.x, sCorner.y, sCorner.z, sCorner.x, sCorner.y, eCorner.z);
    line(sCorner.x, eCorner.y, eCorner.z, eCorner.x, eCorner.y, eCorner.z);
    line(eCorner.x, sCorner.y, eCorner.z, eCorner.x, eCorner.y, eCorner.z);
    line(eCorner.x, eCorner.y, sCorner.z, eCorner.x, eCorner.y, eCorner.z);
    popStyle();
    }

    try{
      for (FlowVector flowVec : flowVectors){
        flowVec.vecDisplay();
      }
    }
    catch(Exception e) {
      println(e);
    }

    //shape(allVectors);

  }

  void save_vectors_json(String scene_name) {

   println("Saving current river flow vector settings as " + scene_name);

   JSONObject vf_settings = new JSONObject();

    try{
      for (FlowVector flowVec : flowVectors){
        JSONObject vec_json = flowVec.get_vec_settings_json();
        vf_settings.setJSONObject(str(flowVec.index), vec_json);
      }
    }
    catch(Exception e) {
      println(e);
    }

   String fn = new String("data/" + file_name + "/vf_settings_"+ name + "_" +  scene_name + ".json");
   saveJSONObject(vf_settings, fn);

  }

  void load_vectors_json(String scene_name) {

    println("Loading current river flow vector settings from "+ scene_name);

    JSONObject vf_settings = new JSONObject();
    String fn = new String("data/" + file_name + "/vf_settings_" + name + "_" + scene_name+".json");

    try {
      vf_settings = loadJSONObject(fn);
    } catch(Exception e) {
      println("Exception loading vector settings: " + e);
    }

    if(vf_settings == null) return;

    try{
      for (FlowVector flowVec : flowVectors){
          JSONObject vector_settings = vf_settings.getJSONObject(str(flowVec.index));

          flowVec.loc.x = vector_settings.getFloat("locx");
          flowVec.loc.y = vector_settings.getFloat("locy");
          flowVec.loc.z = vector_settings.getFloat("locz");

          flowVec.rot.x = vector_settings.getFloat("rotx");
          flowVec.rot.y = vector_settings.getFloat("roty");
          flowVec.rot.z = vector_settings.getFloat("rotz");
        }
    } catch(Exception e) {
      println("Exception assigning vector settings: " + e);
    }

    println(" Done loading " + fn);
  }
}

///////////////////////////// VECTOR 


class FlowVector {

  PVector loc, rot, clr, scrpos;
  float nxoff, nyoff, nzoff, length, max_length;
  float mouseH, mouseD, mouse_force;
  int index, displayAlpha;
  boolean near = false;
  // PShape vecShape;
  // PShape vecCircle;
  // PShape vecLine;

  FlowVector(PVector _loc, int i) {

    /*
    Color is defined as a PVector in order to apply Vector Transformations for color shifts
    */

    clr = new PVector(0, 0, 0);
    displayAlpha = 50;

//     vecShape = createShape(GROUP);
//     vecCircle = createShape(ELLIPSE, 0, 0, 5, 5);

//     vecLine = createShape();
//     vecLine.beginShape(LINES);
//     vecLine.vertex(0, 0, 0);
//     vecLine.vertex(0, 0, 0);
//     vecLine.endShape();
// //    vecCircle.setVisible(true);
// //    vecLine.setVisible(true);

//     vecShape.addChild(vecCircle);
//     vecShape.addChild(vecLine);

    loc = _loc.copy();

    max_length = 300.;
    length = max_length/3. + random(2.*max_length/3.);
    rot = PVector.random3D().mult(length);
    scrpos = new PVector(0, 0, 0);

    index = i;  // used for saving these vectors
    near = false;

    /*
    3 perlin Noise offsets based on the xyz locations of a vector, that way in every
    dimension the Vector Agles follow the slope of the Perlin Noise. Multiplying with a scalar
    ensures that the offsets are close enough to create a typical perlin noise pattern,
    instead of too random noise
    */
    // nxoff = loc.x * 0.01;
    // nyoff = loc.y * 0.01;
    // nzoff = loc.z * 0.01;

    setNoiseOffsets(0, 10, 20, 0.0001, 0.0001, 0.0001);
  }

  synchronized void setNoiseOffsets(float _offX, float _offY, float _offZ, float _multX, float _multY, float _multZ) {
    nxoff = loc.x*_multX + _offX;
    nyoff = loc.y*_multY + _offY;
    nzoff = loc.z*_multZ + _offZ;
  }

  synchronized void update() {

    // orient();

    // apply any vector field changes for turbulence, flow, etc.


    // sculpt the vector field:

    if (test_current_actuator && is_mouse_near(actuator_test_distance) && actuator_test_type.equals("VECTORS") ) {  // piggybacking on vector test 'paintbrush'
      //vectors_to_adjust.add(this);
      this.near = true;
    } else {
      this.near = false;
    }// NOTE removal happens with same check, in the test code to avoid concurrent modification (will this work?)

//     // update the shape:

//     PVector clr = rot.copy().normalize();
//     clr.add(new PVector(1,1,1));
//     clr.mult(128);    
    
//     vecShape.resetMatrix();

//     float rr[] = cam.getRotations();
//     vecShape.rotate(rr[2], 0, 0, 1); // to fix bug with rotateZ()?
//     vecShape.rotate(rr[1], 0, 1, 0);
//     vecShape.rotate(rr[0], 1, 0, 0);
//     vecShape.translate(loc.x, loc.y, loc.z);
    
//    // vecCircle.setFill(color(clr.x, clr.y, clr.z, displayAlpha));
// //    vecCircle.setStroke(clr.x, clr.y, clr.z, displayAlpha);
// //    vecCircle.noStroke();

//     PVector end = rot.copy().normalize().mult(length);
//     scrpos = new PVector(screenX(end.x,end.y,end.z), screenY(end.x,end.y,end.z), 0);

//     vecLine.setVertex(0, loc);
//     vecLine.setVertex(1, end);
//    // vecLine.setStroke(color(clr.x, clr.y, clr.z, displayAlpha));
//     vecLine.setStrokeWeight(2);
// //    strokeWeight(2);

    // shape(vecLine);
  }

  boolean is_mouse_near(int mouse_test_distance) {
    if(dist(scrpos.x, scrpos.y, mouseX, mouseY) < mouse_test_distance) {
      mouse_force = 70 * ( 1.0-(dist(scrpos.x, scrpos.y, mouseX, mouseY)/mouse_test_distance) ) ;
      return(true);
    }
    mouse_force = 0.0;
    return(false);
  }

  synchronized void orient() {

    /*
    In this method the Vector Orientation is set by a series of accumulating offsets
    */

    /*
    Use Perlin Noise to modulate the Vector Orientations
    */

      /*
      Scan through the Perlin Noise with the offsets incrementing evry frame
      */
      PVector rotPerlin = new PVector(noise(nxoff), noise(nyoff), noise(nzoff));

      /*
      Scale Perlin from 0 1 to -1 1
      */
      rotPerlin.sub(0.5, 0.5, 0.5).mult(2);

      /*
      Add Perlin offset to Rotation
      */
      rot.add(rotPerlin);

      /*
      Increase the Perlin xyz offsets
      */
      nxoff += flowFieldVars.perlinOffsetInc;
      nyoff += flowFieldVars.perlinOffsetInc;
      nzoff += flowFieldVars.perlinOffsetInc;

    
    /*
    Normalise rotation to avoid it growing infinitely
    */
    rot.normalize().mult(2);
  }

  synchronized void vecDisplay() {           // FlowVector
    if (!flowFieldVars.display) return;
    PVector clr = rot.copy().normalize();
    clr.add(new PVector(1,1,1));
    clr.mult(128);
    stroke(clr.x, clr.y, clr.z, displayAlpha);

    strokeWeight(1);

    fill(clr.x, clr.y, clr.z, displayAlpha);

    pushMatrix();
    translate(loc.x, loc.y, loc.z);
      rotateX(cam.getRotations()[0]);
      rotateY(cam.getRotations()[1]);
      rotateZ(cam.getRotations()[2]);

    ellipse(0, 0, 30, 30);
    popMatrix();

    pushMatrix();
    translate(loc.x, loc.y, loc.z);
    stroke(clr.x, clr.y, clr.z, displayAlpha);
    strokeWeight(2);


    PVector end = rot.copy().normalize().mult(length);
    scrpos = new PVector(screenX(end.x,end.y,end.z), screenY(end.x,end.y,end.z), 0);

    // temporary
    // stroke(200, 100, 0, 100);


    if(near) {
    
      // line(0, 0, 0, end.x, end.y, end.z);

        stroke(0, 100, 200, 100);
      // figure out and represent mouse sculpting 

        PVector mouse_vec = new PVector(0, 0);

        // // magnetic
        if(flowFieldVars.sculptmode == 1) {
        mouse_vec = new PVector(mouseX-scrpos.x, mouseY-scrpos.y);
        mouse_vec.setMag(mouse_force * (3.0 + ((millis()-mouse_millis)/1000.) ));
       }

         // path
         if(flowFieldVars.sculptmode == 2) {
             mouse_vec = new PVector(mouseX-mouse_down.x, mouseY-mouse_down.y);
                 if(mouse_vec.mag() > actuator_test_distance/10) {
                mouse_down.x = mouseX;
                mouse_down.y = mouseY;
              }
             mouse_vec.setMag(mouse_force * (3.0 + ((millis()-mouse_millis)/1000.) ));
  
        }

        mouseH = mouse_vec.heading();
        mouseD = mouse_vec.mag();

        translate(end.x, end.y, end.z);

        rotateX(cam.getRotations()[0]);
        rotateY(cam.getRotations()[1]);
        rotateZ(cam.getRotations()[2]);

        rotateZ(mouseH);
       
        fill(255, 10);
        ellipse(0, 0, mouseD, mouseD);
        noFill();
        line(0, 0, 0, mouseD, 0, 0);

        if(mousePressed) {  // sculpt this vector by drawing it either towards the mouse position in the plane of the screen or in the direction of mouse movement

            end = new PVector(modelX(mouse_force, 0, 0), modelY(mouse_force, 0, 0), modelZ(mouse_force, 0, 0));
            end.sub(loc);
            end.setMag(min(end.mag(), max_length));
            length = end.mag();
            rot = end.copy();

        } else {
            mouse_millis = millis();
            mouse_vec.setMag(0);
            mouse_down.x = mouseX;
            mouse_down.y = mouseY;
        }

        popMatrix();  // now that I know the new end position, pop the matrix.

        pushMatrix(); // push again to return to previous view
        translate(loc.x, loc.y, loc.z);

    } else {


    }

    line(0, 0, 0, end.x, end.y, end.z);


    popMatrix();
  }

  
  synchronized JSONObject get_vec_settings_json() {

     JSONObject vs_settings = new JSONObject();

     vs_settings.setFloat("locx", loc.x);
     vs_settings.setFloat("locy", loc.y);
     vs_settings.setFloat("locz", loc.z);

     vs_settings.setFloat("rotx", rot.x);
     vs_settings.setFloat("roty", rot.y);
     vs_settings.setFloat("rotz", rot.z);

     return vs_settings;

  }

}



