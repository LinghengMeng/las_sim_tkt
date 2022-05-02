/** \class GridEye_Sim GridEye_Sim.pde
 * \simple simulator for testing GridEye if we don't have one, or for simulating visitor interaction in the sim 
 * \author PBAI/LASG
 * \author Matt Gorbet
 * \date December 14 2018
 * \todo create GUI for tweaking all variables!
 */

import processing.net.*;

class GridEye_Sim {
  int frame;
  int effectSizeX = 25;
  int effectSizeY = 30;

  float nlevel = 2.0;

  Server gridEyeServer_local;
  float[] valuesMatrix = new float[64];

  String  recording_filename = "rightArmWaving.txt";           // also set the default in the GUI
  char    recording_rotation = '0';  // rotate 90 degrees CW   // also set the default in the GUI.
  String[] recording_lines;
  int      recording_index = 0;

  float xo;
  float yo;

  GridEye_Sim (PApplet p, int port) {

    textSize(height/70);

    gridEyeServer_local = new Server(p, port);   // <- for local sim
    println("Creating GridEyeServer for local sim on port " + port + " ... ");

    if (prerecorded) {
       setup_prerecorded();
    }
  }

  void update() {
    frame++;

     if (prerecorded) {

           if(recording_lines == null) {
             setup_prerecorded();
           }

          recording_index++;
          if (recording_index == recording_lines.length/64) {
            recording_index = 0;                                  // reset index
            ge.cur_ge.setBackground = true;                                 // also reset background image
          }
     }
    //print("GridEye Updating...  ("  + frame + "):  ");
    //println("Writing " + valuesMatrix.length + " floats:");

    int  index;



    for (int i = 0; i < 8; i++) {
      for (int j = 0; j < 8; j++) {
        index = (8*i)+j;

        if (prerecorded) {
          
          // load next pixel  
          String next = recording_lines[ 64*recording_index + index];
   

          if (next.charAt(0) == '@') {
            valuesMatrix[index] = float(next.substring(1));
          } else {
            valuesMatrix[index] = float(next);
          }


        } else {  //  if live via mouse

          /// first do noise

          valuesMatrix[index] = 23.0-nlevel+noise(frame/5.0+index)*nlevel;      
          // print(str(valuesMatrix[index]) + " ");

          //  now do mouse effect
          //  float xpos =   canvasw - (canvasw/20)*(j+2) + canvasw/40;
          float xo = int(gui.grp_simulation.getAbsolutePosition()[0] + (270 - (9 * (canvasw/20)) ) /2);
          float yo = int(gui.grp_simulation.getAbsolutePosition()[1]);

          float xpos =   xo + (canvasw/20)*(j+1) + canvasw/40;
          float ypos =   yo + (canvash/20)*(i+1) + canvash/40;

          float d = dist(xpos, ypos, mouseX, mouseY);
          float dx = abs ((xpos - mouseX) + noise(mouseX)*15);
          float dy = abs ((ypos - mouseY) + noise(mouseY)*15);

          if (dx < effectSizeX && dy < effectSizeY) {
            valuesMatrix[index] += noise(xpos)*(20.0 - d/5.0) ;   // blurred oval
            //   valuesMatrix[index] += (5.0);  // solid circle
          }
          
        }


        // now output the data
        gridEyeServer_local.write(str(valuesMatrix[index]));
         // print(str(valuesMatrix[index]) + " ");
        gridEyeServer_local.write(" ");
      }
       // println(" /");
    }   

     // println("@");
    gridEyeServer_local.write("@");
    
    

    if (prerecorded) {
     delay(0); 
    }
    delay(0);
  }



  void go() {

    if (prerecorded) {
      fill(255);
      text("FRAME "+ recording_index, canvas_xo+(canvasw/20)*6, canvas_yo+canvash/40);
    
    } else {
      
             //  draw the simulated values
   
       int index = 0;
       int pval = 0;
       float xpos = 0;
       float ypos = 0;
   
       for (int i=0; i<8; i++) {
         for (int j=0; j<8; j++) {
           index = (8*i)+j;
           pval = int(valuesMatrix[index]);
   
           stroke(min(pval*3, 100));
           fill(pval);
         //  xpos = canvasw - (canvasw/20)*(j+2);
           float xo = int(gui.grp_simulation.getAbsolutePosition()[0] + (270 - (9 * (canvasw/20)) ) /2);
           float yo = int(gui.grp_simulation.getAbsolutePosition()[1]);
   
           xpos = xo + (canvasw/20)*(j+1);
           ypos = yo + (canvash/2)/10*(i+1);
   
           rect(xpos, ypos, canvasw/20, canvash/20, 14);
   
   
           fill(max(pval, 128));
           text(nf(valuesMatrix[index], 2, 1), xpos+canvasw/80, ypos+canvash/35);
   
           stroke(0);
         }
       }
      /// draw mouse effect:
       if(mouseX > xo-canvasw/20 && mouseY > yo-canvash/20) {
         
      stroke(50, 0, 250);
      fill(50, 50, 50, 200);
      ellipse (mouseX, mouseY, effectSizeX*.9+noise(frame)*(effectSizeX*.4), effectSizeY*.9+noise(frame*6)*(effectSizeY*.4));     
      stroke(0);
       }
    }   
    
    
  }
  
  
  boolean is_prerecorded() {
     return(prerecorded);
  }
  
  void setup_prerecorded() {
  
      println("opening text file: " + recording_filename);
      recording_lines   = loadStrings(recording_filename);
      recording_rotation = 'L';  // rotate 90 degrees CW
      recording_index = 0;
      setBackground();
      update();
    
  }
  
  
}  // class
