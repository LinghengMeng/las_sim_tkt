// Click and Drag an object
// Daniel Shiffman <http://www.shiffman.net>

class Draggable {
    constructor(x, y, w, h, p, l) {
  
      this.dragging = false; // Is the object being dragged?
      this.autodrag = false; // is the object 'stuck' to the mouse (ie no mousepressed but being dragged)
      this.rollover = false; // Is the mouse over the ellipse?
  
      this.opacity = 1.0;

      this.x = x;
      this.y = y;
      // Dimensions
      this.w = w;
      this.h = h;
      this.r = p;
      this.labelheight = l;

      this.issaiunit = false;

      this.justborn = false;  // if copied, don't want to act until dropped
      this.pendingcopy = false;
      this.copycoords = {x: x, y: y};

    }
    
    over() {
      // Is mouse over object label?

      let scrp = scrv({x: this.x, y: this.y, w: this.w, h: this.h, p: this.p});

      let mb = {x1:(multibox.x1 < multibox.x2) ? multibox.x1 : multibox.x2, 
                x2:(multibox.x1 < multibox.x2) ? multibox.x2 : multibox.x1, 
                y1:(multibox.y1 < multibox.y2) ? multibox.y1 : multibox.y2, 
                y2:(multibox.y1 < multibox.y2) ? multibox.y2 : multibox.y1  }

      if (multiselecting) {
        if (mb.x2 > scrp.x && mb.y2 > scrp.y && mb.x1 < scrp.x + scrp.w &&  mb.y1 < scrp.y + (this.labelheight * pchr.settings.zoom)) {
          //this.rollover = true;
          this.multi = true;
          anyover = true;
        } else {
          if(!shifted) {
          //this.rollover = false;
          this.multi = false;
          }
        }
      }
      else {
        if (mouseX  > scrp.x && mouseX  < scrp.x + scrp.w && mouseY > scrp.y && mouseY < scrp.y + this.labelheight * pchr.settings.zoom) {
          this.rollover = true;
          anyover = true;
        } else {
          this.rollover = false;
        }
      }
  
    }
  
    update() {
  
      // Adjust location if being dragged
      if (this.dragging || this.autodrag) {

        let scrm = screenMouse();
        // fill(0, 0, 200);
        // ellipse (scrm.x, scrm.y, 5, 5);
  
        this.x = (scrm.x + this.offsetX);
        this.y = (scrm.y + this.offsetY);

        if(this.pendingcopy && dist(this.x, this.y, this.copycoords.x, this.copycoords.y) > grid.step) {
          copySai(this);
          this.pendingcopy = false;
        }

        var snap = pchr.settings.defaultSnap;
        if(commanded) snap = !snap;

        // snap
        if(snap) {
          this.x = round(this.x/grid.step) * grid.step;
          this.y = round(this.y/grid.step) * grid.step;
        }
      }  
    }
  
    show() {
  
      stroke(0);

      push();

      translate( canvaswidth/2 + grid.xoff + grid.dx,  canvasheight/2 + grid.yoff + grid.dy);
      scale(pchr.settings.zoom);
      
      this.drawme();

      pop();

    }
  
    drawme() {  // for patcher -- but can override for different shapes (like SAI instead of patcher)

      if(this.dragging) { // shadow bling

        fill(0, 30 * this.opacity);
        noStroke();
        rect(this.x+10, this.y+10, this.w-5, this.h-5, this.r);

      }

      stroke(0, 255 * this.opacity);
      fill(175, 200 * this.opacity); 
      rect(this.x, this.y, this.w, this.h, this.r);

      // Different label fill based on state
      // header blue color is :  #6494E4;
      fill(unhex("64"), unhex("94"), unhex("E4"), 100 * this.opacity);
      if (this.dragging) {
        fill(155, 100, 0, 100 * this.opacity);
      } else if (this.rollover) {
        fill(255, 200, 0, 100 * this.opacity);
      } else if (this.multi) {
        fill(225, 170, 0, 100 * this.opacity);
      }
      rect(this.x, this.y, this.w, this.labelheight, this.r, this.r, 0, 0);

    }

    pressed() {
      if(this.hidden && !pchr.settings.showHidden) return;
      // Did I click on the object label?
//      if (mouseX > this.x && mouseX < this.x + this.w && mouseY > this.y && mouseY < this.y + this.labelheight) {

      // console.log(this.data.name+": checking rollover - " + this.rollover);


      if((this.rollover || this.multi) && !shifted) {
        
        if(alted && !this.justborn && this.issaiunit) {  // ignore freshly copied ones
          this.pendingcopy = true;
          this.copycoords = {x: this.x, y: this.y};

//          copySai(this);               // going to make a copy
//          console.log(this.data.name+ ": copying");
        }
        
        if(overanyport || (this.issaiunit && overanyactuator)) return;  // don't drag SAI units if I'm making a connector or dragging an actuator

        this.dragging = true;
        anydragging = true;

        // console.log(this.data.name+ ": setting to drag");
        let scrm = screenMouse();

        // If so, keep track of relative location of click to corner of rectangle
        this.offsetX = this.x - scrm.x + dragOffset;
        this.offsetY = this.y - scrm.y;
 
        if(commanded) dragOffset += grid.step*2; // to fan out
        
      }
    }
  
    released() {
      // Quit dragging
      this.autodrag = false;
      this.dragging = false;
      this.justborn = false;
      this.pendingcopy = false;
      dragOffset = 0;
    }
  }