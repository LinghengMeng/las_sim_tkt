

/** \class GridEye_Analyzer.pde
 * \Processing code to visualize and analyze GridEye output
 * \author PBAI/LASG
 * \author Matt Gorbet
 * \date December 14 2018 - Feb 2 2019
 * \todo create GUI for tweaking all variables!
 */


import processing.serial.*;
import processing.net.*;
import java.net.InetAddress;
import controlP5.*;
import java.util.*;



class GridEye_Analyzer {

  Serial uart;
  String theBuf;

  InetAddress inet;
  String myIP;

  int           local_sim_port = 5444;
  int           live_server_port = 5445;

  GridEye_Sim   grideye_sim;
  Server        gridEyeServer_live;   // to serve live stream to Control 

  //ControlP5     gridEyeGUI;

  //PGraphics     g;

  ArrayList<PVector> motionVectors = new ArrayList<PVector>();


  boolean serialbusy = false;

  int state = 9;


  //MATT-GRIDEYE

  float x_comp = 0;
  float y_comp = 0;


  int     frame = 0;
  int     memorycount = 10;
  float   maxIncoming = 30f;
  float   minIncoming = 10f;
  float   average;

  float   maxMotion = 0f;
  float   minMotion = 0f;

  float   topMax = 0f;
  float   avgDP = 0f;
  float   maxDP = 0f;
  float   minDP = 0f;
  float   maxDPVariance = 100f;
  float   topMaxDP = 0f;
  float   avgMotion = 0f;
  float   avgMax = 0f;
  float   avgMin = 0f;
  float   maxFore = 0f;
  float   minFore = 0f;
  float   avgFore = 0f;
  float   maxDelta = 0f;
  float   avgDelta = 0f;
  float   topMaxDelta = 4.0f;
  float   topMaxFore = 7.0f;
  float[] maxMemory;
  float[] minMemory;

  float[]     incomingValues = new float[65];
  float[]     backgroundValues = new float[64];
  float[]     pixelValues = new float[64];
  float[]     foreValues = new float[64];
  float[]     dpValues = new float[64];
  float[]     outputMV = new float[64];
  float[]     outputDP = new float[64];
  float[]     motionValues = new float[64];
  float[]     lastFrame   = new float[64];


  int     motionPixelsCount = 0;

  boolean debug                     = false;        // debug flag
 // boolean setBackground             = false; 
  boolean goodFrame                 = false;
 // boolean forward_stream_to_control = false;
 // boolean streaming_from_pi         = false;


  float  overall_presence = 0f;
  float  overall_X = 0.0;
  float  overall_Y = 0.0;

  //float  output_angle = 0f;
  float[]   overall_Avg_X = new float[6];
  float[]   overall_Avg_Y = new float[6];

  int rec_x_offset = 0;
  int rec_y_offset = 0;

  PApplet parent;
  GridEye cur_ge;

  GridEye_Analyzer(PApplet _parent) {
    // size(600, 600); // must use numbers.  draw-canvas is determined by canvasw and canvash

    parent = _parent;
    motionPixelsCount = 0;
    goodFrame = false;

    //g = createGraphics(600, 600, P2D);
    // g = parent.P


    // CLEAR ALL MATRICES

    for (int i = 0; i < 64; i++) {
      incomingValues[i] = 0f;
      pixelValues[i] = 0f;
      backgroundValues[i] = 0f;
      motionValues[i] = 0f;
      lastFrame[i] = 0f;
    }

    textSize(8);
    rectMode(CORNER);

    /// set up GUI controls
    //  gridEyeGUI = new ControlP5(parent);
    //  gridEyeControl = new GEControl(gridEyeGUI, gridEye);



    /// open Sim Client
    /*
    try {
     inet = inet.getLocalHost();
     myIP = inet.getHostAddress();
     }
     catch (Exception e) {
     e.printStackTrace();
     myIP = "couldnt get IP";
     }
     */


    grideye_sim = new GridEye_Sim(parent, local_sim_port);  // <-- send this object the port to use for serving sim data locally
    delay(500);
    //  println("Created GridEyeClient for local sim with IP " + control.my_address + " on port " + local_sim_port);




    println();
    rectMode(CENTER);
  }



  ////////////////////////////
  ///
  ///   DRAW LOOP
  ///
  ////////////////////////////


  


  /////////  CALCULATE  VECTORS

  void calcVectors() {

    getInterestAreas(foreValues);

    // println("There are " + motionVectors.size() + " interest areas...");

    detectMotion();


    for (int m = 0; m < motionVectors.size(); m++) {
      PVector mV = motionVectors.get(m);
      int hi = int( mV.x / 8 );  // I've used a PVector to encode the x and y both as the index into the full array;
      int hj = int( mV.x % 8 );

      int ti = int( mV.y / 8); // tails
      int tj = int( mV.y % 8); 

      if (debug) println(m + ": " + ti + ", " +tj + " -> " + hi + ", " +hj);

      int cHX = ( (canvasw/20)*(hj+1) );  
      int cHY = ( (canvash/20)*(hi+1) );  

      int cTX = ( (canvasw/20)*(tj+1) ); 
      int cTY = ( (canvash/20)*(ti+1) );

      // confidence has been mapped as a variance to mV.z, then recorded into dpValues

      if (debug) {
        println("Normalized DPValues (variance):");
        printMatrix(dpValues);
      }

      noStroke();
      fill(255, 255, 0, int(255 * dpValues[int(mV.x)]) );           
      ellipse(canvas_xo + cTX, canvas_yo + cTY, 5, 5);    // mark tail
      stroke(255, 255, 0, int(255 * dpValues[int(mV.x)]) );
      strokeWeight(3); 
      line(canvas_xo + cTX, canvas_yo + cTY, canvas_xo + cHX, canvas_yo + cHY);   // draw line
    }


    // draw overall or max

    overall_X *= cur_ge.overall_relax;  // 0.8
    overall_Y *= cur_ge.overall_relax;  // 0.8

    overall_Avg_X[0] = overall_X;
    overall_Avg_Y[0] = overall_Y;

    float ox = avgMatrix(overall_Avg_X);
    float oy = avgMatrix(overall_Avg_Y);

    // draw current in yellow
    stroke (255, 255, 0);
    strokeWeight(1);

    int length_multiplier = canvasw/12;

    line( canvas_xo + canvasw/4, canvas_yo + canvash/4, canvas_xo + canvasw/4 + overall_X * length_multiplier, canvas_yo + canvash /4 + overall_Y * length_multiplier );

    // draw cumulative in grey
    stroke (255, 100);
    strokeWeight(5);
    line( canvas_xo + canvasw/4, canvas_yo + canvash/4, canvas_xo + canvasw/4 + ox * length_multiplier, canvas_yo + canvash /4 + oy * length_multiplier );

    // draw rotated cumulative in red
    stroke (255, 0, 0);
    strokeWeight(5);
    float oa_rad = radians(cur_ge.output_angle);
    x_comp = ox * cos(oa_rad) - oy * sin(oa_rad);
    y_comp = ox * sin(oa_rad) + oy * cos(oa_rad);

    x_comp *= length_multiplier;
    y_comp *= length_multiplier;
    
    line( canvas_xo + canvasw/4, canvas_yo + canvash/4, canvas_xo + canvasw/4 + ( x_comp ), canvas_yo + canvash /4 + ( y_comp ) );

    for (int i = overall_Avg_X.length-2; i >= 0; i--) {    
      overall_Avg_X[i+1] = overall_Avg_X[i]; 
      overall_Avg_Y[i+1] = overall_Avg_Y[i];
    }

    strokeWeight(1);
    stroke(0);

    motionPixelsCount = 0;

    rectMode(CENTER);
  }



  /////////////////   comms  (from PI, not used on Control)

  synchronized void read_grideye_port() {
    /**
     Client gridEyeClient;
     
     if (gesim) {
     gridEyeClient = vgui.gridEyeClient_local; 
     } else {
     gridEyeClient = vgui.gridEyeClient_live;
     }
     
     
     if(debug) println("available: " + gridEyeClient.available());
     
     if (gridEyeClient.available() > 130 ) {                    // hack: will have to change if threaded so we don't get half a transmission
     String gd = gridEyeClient.readStringUntil('@');
     //   println("available: " + gridEyeClient.available());
     //     println (" gd is            " + gd);
     //     println (" full bufffer is: " + gridEyeClient.readStringUntil('@'));
     getGeData( gd );
     // gridEyeClient.clear();
     }
     **/
  }



  synchronized void getGeData(String theBuf) {

    float[] iv = new float[65];

    if (goodFrame) {
       return;  // sync with frame processing so we only read new frames when ready.
    }
      // println(" Got: " + theBuf); 

    try {
      iv = float(split(theBuf, ' '));
    }
    catch(NullPointerException e) {
      iv = null; // for some reason, the incoming values array is coming in as a null pointer sometimes
    }

    if (iv == null || iv.length < 65 || iv.length > 65 ) {
      println(" +++ dropped frame +++ ");
    } else {

      goodFrame = true;
      incomingValues = shorten(iv);  // get rid of the '@'

      // printMatrix(incomingValues);
    }
  }





  //////////  implement "interest operator" to fill motionvectors

  void getInterestAreas(float[] pix) {

    motionVectors.clear();

    float pDiffs[] = new float[4];  /// these are the horizontal, vertical, and two diagonal diff values

    for (int i = 1; i < 7; i++) {
      for (int j = 1; j < 7; j++) {
        int index = (i*8)+j;
        pDiffs[0] = variance3(pix[index-1], pix[index], pix[index+1]);   // -  west to east
        pDiffs[1] = variance3(pix[index-8], pix[index], pix[index+8]);   // |  north to south
        pDiffs[2] = variance3(pix[index-9], pix[index], pix[index+9]);   // \  nw to se   
        pDiffs[3] = variance3(pix[index-7], pix[index], pix[index+7]);   // /  ne to sw  

        motionValues[index] = min(pDiffs);

        //       println(" MotionValues : ");
        //       printMatrix(motionValues);

        if (motionValues[index] > cur_ge.interest_thresh) {
          motionVectors.add(new PVector((i*8+j), (i*8+j), motionValues[index]-cur_ge.interest_thresh));
        }
      }
    }
  }

  float variance(float[] m) {
    float mean;
    float sum = 0.0;

    for (int i = 0; i < m.length; i++) {
      sum += m[i];
    }

    mean = sum / m.length;

    for (int i = 0; i < m.length; i++) {
      m[i] -= mean;  

      sum += ( m[i]*m[i] );
    }

    return (sum / m.length);
  }

  float variance3(float v0, float v1, float v2) {

    float[] v = new float[3];

    v[0] = v0;
    v[1] = v1;
    v[2] = v2;

    return variance(v);
  }


  //////  detect motion from 2 matrices and areas of interest 

  void detectMotion() {

    float[] hood  = new float[9];
    float[] check = new float[9];

    for (int m = 0; m < motionVectors.size(); m++) {

      PVector mV = motionVectors.get(m);
      int x = int( mV.x / 8 );  // Using a PVector to encode the x and y both as the index into the full array -- mV.x is the head and mv.y will become the index into the array of the tail of the vector if there was motion.
      int y = int( mV.x % 8 );  

      // println(m + ": " + x + ", " +y + " (" + foreValues[int(mV.x)] + ")");

      if ( x == 0 || x == 7 || y == 0 || y == 7) {
        continue;
      }

      /// now convolve the 3x3 neighbourhood of pixels around this one with a 5x5 window of pixels 
      /// from the previous frame centered at this point, looking for best match

      // first build the 'hood:
      hood = getWindow(foreValues, int(mV.x), 8, 3);  /// matrix, index of point of interest, width of source matrix, height of window, width of window

      //   println(m + ":  Hood: ");
      //   printMatrix(hood, 3, 3);

      // now slide it over the window, taking dot products
      float maxDP = 0;
      float[] allDPs = new float[25];
      int dpi = 0;

      for (int xo = -2; xo <= 2; xo++) {         // xoffset
        for (int yo = -1; yo <= 2; yo++) {       // yoffset

          int poi = int(mV.x) + (8*yo) + xo;
          check = getWindow( lastFrame, poi, 8, 3 );

          dpValues[int(mV.x)] = 0.0;

          for (int i = 0; i < hood.length; i++) {
            allDPs[dpi] += check[i] * hood[i];
          }


          if (allDPs[dpi] > maxDP) {
            maxDP = allDPs[dpi];
            dpValues[int(mV.x)] = allDPs[dpi];        // best match -- confidence???
            mV.y = poi;        // update vector tail (since we are comparing to previous frame)
          }

          dpi++;
        }
      } 

      mV.z = variance(allDPs);  // confidence that this DP is significant (not normalized yet)

      maxDPVariance = max(mV.z, maxDPVariance);  // keep track of the largest variance I've seen (ever)
      mV.z = mV.z/maxDPVariance;  // normalize current variance.

      dpValues[int(mV.x)] = mV.z;  // remember the confidence level in the "dpValues" grid (to draw it)

      // mV.x is location in linear matrix of vector head
      // mV.y is location in linear matrix of vector tail
      // mV.z is normalized 'confidence'  (variance of DP values used to determine this motion)

      if (debug) println("scaling: " + int( mV.x % 8 ) + " - " + int( mV.y % 8 ) + " by " + mV.z);

      overall_X = overall_X + ( float((int( mV.x % 8 ) - int( mV.y % 8))) * mV.z ) ;    
      overall_Y = overall_Y + ( float((int( mV.x / 8 ) - int( mV.y / 8))) * mV.z ) ;

      if (debug) println("overall_X is " + overall_X + " overall_Y is " + overall_Y);
    }
  }


  float[] getWindow(float[] m, int pIndex, int msize, int wsize) {  //  matrix, index of point of interest, width of source matrix, size(eg 3x3 window, or 5x5)

    float[] window = new float[wsize * wsize];

    int masktop = 0;
    int maskleft = 0;
    int maskright = 0;
    int maskbot = 0;

    int px = pIndex % msize;
    int py = pIndex / msize;

    int cornerdist = wsize-1 / 2;  // distance to edge of window

    //   println("cornerdist is " + cornerdist); 
    //   println(" pIndex % msize " + pIndex % msize );
    //   println(" pIndex / msize " + pIndex / msize );

    // bounds checking 
    maskleft  = 0 - ( min(0, px-cornerdist ));
    masktop   = 0 - ( min(0, py-cornerdist ));
    maskright = 0 - ( min(0, ((msize-1)-px)-cornerdist ));
    maskbot   = 0 - ( min(0, ((msize-1)-py)-cornerdist ));


    for (int windex = 0; windex < wsize * wsize; windex++) {

      if (windex % wsize >= maskleft && (windex % wsize) < (wsize-maskright) &&
        windex / wsize >= masktop  && (windex / wsize) < (wsize-maskbot)      ) {
        int wVal = int(pIndex) - (msize+1) + int(windex % wsize) + (int(windex / wsize) * msize );        
        window[windex] = m[ wVal ];
      } else {

        //   println( "edge..");
        window[windex] = 0.0;
      }
    }

    return(window);
  }



  ///// all kinds of matrix helper functions


  void printMatrix(float[] m) {
    printMatrix(m, 8, 8);
  }

  void printMatrix(float[] m, int w, int h) {

    for (int i=0; i<h; i++) {
      for (int j=0; j<w; j++) {
        print(nf(m[(i*w)+j], 3, 2));
        print(" ");
      }
      println();
    }
    println();
  }


  float[] rotateMatrix(float[] orig, char dir) {

    // assumes matrix is SQUARE & 8 x 8

    int w = 8;
    int h = 8;

    float[] returnMatrix= new float[orig.length];

    switch(dir) {

    case '0':     // no rotation - but still offset

      for (int i=0; i<h; i++) {
        for (int j=0; j<w; j++) {

          int ii = (i + rec_y_offset) % (h);  
          if (ii < 0) ii = (h) + ii;  // rolling offset
          int jj = (j - rec_x_offset) % (w);  
          if (jj < 0) jj = (w) + jj;  // rolling offset

          returnMatrix[(i*w)+j] = orig[(ii*w)+jj];
        }
      }
      break;

    case 'R':
      // rotate matrix CW  (right)

      for (int i=0; i<h; i++) {
        for (int j=0; j<w; j++) {

          int ii = (i + rec_y_offset) % (h);  
          if (ii < 0) ii = (h) + ii;  // rolling offset
          int jj = (j + rec_x_offset) % (w);  
          if (jj < 0) jj = (w) + jj;  // rolling offset

          returnMatrix[(j*w)+(w-1)-i] = orig[(ii*w)+jj];
        }
      }
      break;

    case 'L':
      // rotate matrix ccw  (left) 

      for (int i=0; i<h; i++) {
        for (int j=0; j<w; j++) {

          int ii = (i + rec_y_offset) % (h);  
          if (ii < 0) ii = (h) + ii;  //  rolling offset 
          int jj = (j + rec_x_offset) % (w);  
          if (jj < 0) jj = (w) + jj;  //  rolling offset

          // returnMatrix[(w-1-j)*w+(w-1-i)] = orig[(ii*w)+jj];
          returnMatrix[(w-1-j)*w+i] = orig[(ii*w)+jj];
        }
      }
      break;

    case 'F':
      // flip matrix (flip) 

      for (int i=0; i<h; i++) {
        for (int j=0; j<w; j++) {


          int ii = (i + rec_y_offset) % (h);  
          if (ii < 0) ii = (h) + ii;  //  rolling offset 
          int jj = (j + rec_x_offset) % (w);  
          if (jj < 0) jj = (w) + jj;  //  rolling offset



          returnMatrix[(h-1-i)*w+(w-1-j)] = orig[(ii*w)+jj];
        }
      }
      break;

    default:
      println("Rotation Direction " + dir + " not recognized; returning original");
      returnMatrix = orig;
      break;
    }


    return(returnMatrix);
  }


  float[] subtractMatrix(float[] subt, float[] from) {

    float[] returnMatrix= new float[subt.length];

    for (int i = 0; i < subt.length; i++) {
      returnMatrix[i] = abs(from[i]-subt[i]);
    }

    return(returnMatrix);
  }


  float[] subtractMatrix(float[] subt, float[] from, float thresh) {

    float[] returnMatrix= new float[subt.length];

    for (int i = 0; i < subt.length; i++) {
      returnMatrix[i] = abs(from[i]-subt[i]);
      if (returnMatrix[i] < thresh) returnMatrix[i] = 0f;  // remove noise
    }

    return(returnMatrix);
  }



  float avgMatrix(float[] m) {

    return( avgMatrix(m, true) );
  }


  float avgMatrix(float[] m, boolean includeZero) {

    int divisor = m.length;
    float returnAvg = 0f;

    for (int i = 0; i < m.length; i++) {
      returnAvg += m[i];
      if (!includeZero && m[i] == 0 && divisor > 0) {
        divisor --;
      }
    }
    returnAvg = returnAvg / divisor;

    return(returnAvg);
  }

  void clearMatrix(float[] m) { 
    for (int i = 0; i < m.length; i++) {
      m[i] = 0f;
    }
  }

  float[] deNoise(float[] m, float threshold) { 
    for (int i = 0; i < m.length; i++) {
      if (m[i] < threshold) {
        m[i] = 0f;
      }
    }
    return(m);
  }

/////////   GRIDEYE UI PANEL FUNCTIONS (FORWARDED FROM CONTROL_WORLD)

  void setBackground() {
  
    cur_ge.setBackground = true;
  
    if (cur_ge.stream) {
      
      String pi_address = dl.find_nodes_parent_rpi(cur_ge.parent.node_id).my_address;
      network.write_message("/CONTROL/GE_SET_BACKGROUND/"+ control.my_address + "/" + pi_address + " ");
   
   }
  }





}
