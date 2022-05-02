/** \class GridEye_Controls GridEye_Controls.pde
 * \ControlP5-based controls for GridEye Analayzer and Sim
 * \author PBAI/LASG
 * \author Matt Gorbet
 * \date Feb 4, 2019
 * \todo create GUI for tweaking all variables!
 */
 
 
class GEControl {

  Accordion panels;
  color c = color(0, 160, 100);
  ControlP5 ge_gui;
  GridEye ge_sim;

  Slider ge_frameskip;
  Slider ge_interest_thresh;
  Slider ge_noise_thresh;
  Slider ge_overall_relax;
  Knob   ge_angle_adjust;
  ScrollableList ge_prerec_file;
  RadioButton ge_prerec_rot;

  GEControl(ControlP5 mygui, GridEye ge) {
  
  ge_sim = ge;
  ge_gui = mygui;
  
  ge_gui.setAutoDraw(true);
    
  // group number 1, contains recorded data controls
  Group g1 = ge_gui.addGroup("Pre-Recorded")
                .setBackgroundColor(color(0, 64))
                .setBackgroundHeight(150)
                ;
  
  ge_gui.addToggle("togglepre")
     .setPosition(10,20)
     .setHeight(20)
     .setWidth(20)
     .setLabel("use recording")
     .moveTo(g1)
     ;
  
  List l = Arrays.asList("leftArmWaving.txt", 
                         "rightArmWaving.txt", 
                         "sideToSide1.txt", 
                         "sideToSide2.txt", 
                         "frontBack1.txt", 
                         "frontBack2.txt", 
                         "bothArms.txt");

  ge_prerec_file = ge_gui.addScrollableList("pickfile")
     .setPosition(40, 20)
     .setSize(200, 100)
     .setBarHeight(20)
     .setItemHeight(20)
     .setOpen(false)
     .addItems(l)
     .setValue(1)
     .moveTo(g1)
    ;
  
  ge_prerec_rot = ge_gui.addRadioButton("setRotation")
     .setPosition(10,60)
     .setItemWidth(5)
     .setItemHeight(10)
     .addItem("CCW",  0)    // 'L'
     .addItem("NONE", 1)    // '0'
     .addItem("CW",   2)    // 'R'
     .addItem("180",  3)    // 'F'
     .setColorLabel(color(255))
     .activate(0)
     .moveTo(g1)
     ;
     
  /*   
  ge_gui.addSlider("rec_x_offset")
     .setPosition(100,70)
     .setSize(80,10)
     .setRange(-4,4)
     .setValue(0)
     .setNumberOfTickMarks(9)
     .setSliderMode(Slider.FLEXIBLE)
     .showTickMarks(false)
     .moveTo(g1)
     ;
     
  ge_gui.addSlider("rec_y_offset")
     .setPosition(140,50)
     .setSize(10,80)
     .setRange(-4,4)
     .setValue(0)
     .setNumberOfTickMarks(9)
     .setSliderMode(Slider.FLEXIBLE)
     .showTickMarks(false)
     .moveTo(g1)
     ;
    */
    
    
  // group number 2, contains simulation controls
  Group g2 = ge_gui.addGroup("Simulation")
                .setBackgroundColor(color(0, 64))
                .setBackgroundHeight(150)
                ;
                
         

                

     
  // group number 3, contains runtime analysis controls
  Group g3 = ge_gui.addGroup("Analysis")
                .setBackgroundColor(color(0, 64))
                .setBackgroundHeight(150)
                ;
     
  ge_frameskip = ge_gui.addSlider("frameskip")
     .setPosition(100,20)
     .setSize(100,20)
     .setRange(1,10)
     .setValue(1)
     .setNumberOfTickMarks(10)
     .setSliderMode(Slider.FLEXIBLE)
     .moveTo(g3)
     ;
     
  ge_interest_thresh = ge_gui.addSlider("interestThreshold")
     .setPosition(100,50)
     .setSize(100,20)
     .setRange(500f,1500f)
     .setValue(1000.0)
     .setNumberOfTickMarks(10)
     .setSliderMode(Slider.FLEXIBLE)
     .moveTo(g3)
     ;       
      
  ge_noise_thresh = ge_gui.addSlider("noiseThreshold")
     .setPosition(100,80)
     .setSize(100,20)
     .setRange(0f,1f)
     .setValue(0.3)
     .setNumberOfTickMarks(10)
     .setSliderMode(Slider.FLEXIBLE)
     .moveTo(g3)
     ;       
     
  ge_overall_relax = ge_gui.addSlider("overall_relax")
     .setPosition(100,120)
     .setSize(100,20)
     .setRange(0f,0.99f)
     .setValue(0.75)
     .setNumberOfTickMarks(10)
     .setSliderMode(Slider.FLEXIBLE)
     .moveTo(g3)
     ;       
  
 ge_angle_adjust = ge_gui.addKnob("angle_adjust")
               .setRange(0,360)
               .setValue(0)
               .setPosition(10,100)
               .setRadius(30)
               .setNumberOfTickMarks(8)
               .setTickMarkLength(2)
               .snapToTickMarks(false)
               .setAngleRange(TWO_PI)
               .setStartAngle(PI+PI/2)
               .setShowAngleRange(true)
               .setViewStyle(2)
               .setDragDirection(Knob.HORIZONTAL)
               .moveTo(g3)
               ;
     
  ge_gui.addBang("setBackground")
     .setPosition(10,20)
     .setSize(20 , 20)
     .moveTo(g3)
     ;
    
  
  ge_gui.addToggle("gesim")
     .setPosition(10,60)
     .setHeight(10)
     .setWidth(40)
     .setLabel("SIM --- LIVE")
     .setMode(ControlP5.SWITCH)
     .moveTo(g3)
     ;

  // create a new accordion
  // add g1, g2 and g3 to the accordion.
  panels = ge_gui.addAccordion("accordion_panels")
                 .setPosition(canvasw/2,20)
                 .setWidth(canvasw/2 - 10)
                 .addItem(g1)
                 .addItem(g2)
                 .addItem(g3)
                 ;
                 
  ge_gui.mapKeyFor(new ControlKey() {public void keyEvent() {panels.open(0,1,2);}}, 'o');
  ge_gui.mapKeyFor(new ControlKey() {public void keyEvent() {panels.close(0,1,2);}}, 'c');
  ge_gui.mapKeyFor(new ControlKey() {public void keyEvent() {panels.setWidth(300);}}, '1');
  ge_gui.mapKeyFor(new ControlKey() {public void keyEvent() {panels.setPosition(mouseX,mouseY);panels.setItemHeight(190);}}, '2'); 
  ge_gui.mapKeyFor(new ControlKey() {public void keyEvent() {panels.setCollapseMode(ControlP5.ALL);}}, '3');
  ge_gui.mapKeyFor(new ControlKey() {public void keyEvent() {panels.setCollapseMode(ControlP5.SINGLE);}}, '4');
  ge_gui.mapKeyFor(new ControlKey() {public void keyEvent() {ge_gui.remove("Pre-Recorded");}}, '0');
  
  
  panels.open(2);
  
  // use Accordion.MULTI to allow multiple group 
  // to be open at a time.
  panels.setCollapseMode(Accordion.MULTI);
  
  // when in SINGLE mode, only 1 accordion  
  // group can be open at a time.  
  // panels.setCollapseMode(Accordion.SINGLE);
}
  
  
 
}
