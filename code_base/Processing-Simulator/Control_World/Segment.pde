// The Nature of Code
// Daniel Shiffman
// http://natureofcode.com

// Path Following

class Segment {

  // A Path Segment is line between two points (PVector objects)
  PVector start;
  PVector end;
  color mycolor;
  float opacity;
  float dist;
  PShape myline;

  boolean showline   = true;

  Segment() {
    
    start = new PVector(0,height/3, 0.0);
    end = new PVector(width,2*height/3, 0.0);
    
    mycolor = color(0, 0);
    
    myline = createShape();
    myline.beginShape(LINES);
    myline.vertex(start.x, start.y, start.z);
    myline.vertex(end.x  , end.y,   end.z  );
    myline.endShape();
    myline.setStroke(mycolor);
    
  }

  // update segment start and end points and opacity (based on opacity and distance of particle), as well as radius lines
  synchronized void update(float op, float d) {
    
        opacity = op;
        dist = d;
        
        myline.setVertex(0, start);
        myline.setVertex(1, end);

  }

  synchronized void display() {

   // println("updating segment with op: " + opacity + " and dist: " + dist);

      try{
        if(!showline) {
          opacity = 0;
        }
          
        mycolor = color(200, 100, 0, opacity*255-(dist/1000)); 
        myline.setStroke(mycolor);

      } catch(Exception e) {

        println("E: " + e);

      }

  }
  
  void show() {

    showline = true;

  }

  void hide() {

    showline = false;

  }

}
