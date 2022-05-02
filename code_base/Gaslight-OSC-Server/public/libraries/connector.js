
class Connector {

    constructor(from, to) {
  
      this.from = from;
      this.to = to;
      this.isSelected = true;
      this.first = null;  
      this.fv = createVector(screenMouse().x, screenMouse().y);
      this.tv = createVector(screenMouse().x, screenMouse().y);

      this.name = "";
      this.triggeredAt = 0;

      this.toKill = false;
  
      // console.log("fv is ("+ this.fv.x + ", "+ this.fv.y+")");
  
    }
  
    completeConnection(p) {

      if(this.to == null) {
         this.first = this.from;
      } else {
         this.first = this.to;
      }

      if(p.connectors.length >= p.maxconnections) {
            // already full, so select the existing connector(s):
            console.log(" ** too many connectors ("+ p.maxconnections +") there already!");
            return false;
        }
  
      if( (this.to != null && p.myParent == this.to.myParent) ||
          (this.from != null && p.myParent == this.from.myParent) ) {
  
            console.log("Can't connect a parameter from an object to itself.");
            return false;
      }
        
  
      if(p.inport) {   // if an inport is selected
        if(this.to != null) {
          console.log("Can't connect inport to inport... ");
          return false;
        } else {
  
          this.to = p;
  
          if(this.from == null) {
            console.log("Odd.  Didn't have a FROM to connect to.");  // this should never happen
            return false; 
          }
        }
      } else { // if an outport is selected...
        if(this.from != null) {
          console.log("Can't connect outport to outport... ");
          return false;
        } else {
          
          this.from = p;
  
          if(this.to == null) {
            console.log("Odd.  Didn't have a TO to connect to.");  // this should never happen
            return false; 
          }
        }
      }
  
      let exists = false;
      for(let i in this.from.connectors) {
        if(this.from.connectors[i].from === this.from && this.from.connectors[i].to === this.to) {
          exists = true;
          break;
        }
      }
      if(!exists) {
        //  console.log("Connection completed between " + this.from.param + " and " + this.to.param);

        console.log("Connection completed between " + this.from.param + " and " + this.to.param);

        console.log("Adding to " + this.from.param + "'s & " + this.to.param +"'s list of connectors.");	          

        console.log("Sending to Patcher via OSC");
        
        this.name = (this.from.myParent.name + "@" + this.from.param + "--" + this.to.myParent.name + "@" + this.to.param);  // may not use this.
        outgoingPatchableUpdate("addConnector", {fromPatchable: this.from.myParent.name, fromPort: this.from.param, toPatchable: this.to.myParent.name, toPort: this.to.param});

        
          if(!shifted) {          
          this.from.connectors.push(this);
          this.to.connectors.push(this);    // add this connector to both arrays, but only 'from' will manage, redraw etc.
          this.isSelected = false;
          this.from.deselect();
          this.to.deselect();
        } else {
            
            var toadd = new Connector(this.from, this.to);     // make a duplicate of active, and add it.
            this.from.connectors.push(toadd);
            this.to.connectors.push(toadd);

            if(this.first == this.to) {
                this.from.deselect();
                this.from = null;
            } else {
                this.to.deselect();
                this.to = null;
            }

          }


        //   this.from.isSelected = false;
        //   this.to.isSelected = false;
    
      } else {
        console.log(" -- oops, that exists already.");
        
        if(this.first == this.to) {
            this.from.deselect();
            this.from = null;
        } else {
            this.to.deselect();
            this.to = null;
        }

        return false;
      }
  
      return true;
    }
  
    update() {
  
      // if it is being created 
      if(activeConnector === this) { this.isSelected = true}; //  else { this.isSelected = false};
  

      if(this.toKill == true) {  // only one can be killed at a time  (not true any more);
        if(this.from != null && this.to != null) {
            outgoingPatchableUpdate("removeConnector", {fromPatchable: this.from.myParent.name, fromPort: this.from.param, toPatchable: this.to.myParent.name, toPort: this.to.param});
        }
        return false;
      }
  

      // the gymnastics below handles drawing of active connectors as they are being created
      // because they are not drawn within the loop with the scale and zoom transform, so we need to do it manually
      // for the part that is connected but not at all for the part attached to the mouse.

  
      if(this.from != null) {
        var scrf = scrv({x: this.from.myParent.x + this.from.portX, y: this.from.y + padding/3 , w: this.from.w, h: this.from.h, p: 0 });
        if(this.isSelected && this.to == null) {
        this.fv.x = scrf.x  ; //this.from.myParent.x + this.from.portX;
        this.fv.y = scrf.y + 1.5*padding * pchr.settings.zoom; //this.from.myParent.y + this.from.textY-padding/2;
        } else {
          this.fv.x = this.from.myParent.x + this.from.portX;
          this.fv.y = this.from.myParent.y + this.from.textY-padding/2;
        }
      } else {
        this.fv.x = mouseX;
        this.fv.y = mouseY;
      }
  
      if(this.to != null) {
        var scrt = scrv({x: this.to.myParent.x + this.to.portX, y: this.to.y + padding/3, w: this.to.w, h: this.to.h, p: 0 });
     
        if(this.isSelected && this.from == null) {
        this.tv.x = scrt.x ; //this.to.myParent.x + this.to.portX;
        this.tv.y = scrt.y + 1.5*padding * pchr.settings.zoom; //this.to.myParent.y + this.to.textY-padding/2;
        } else {
          this.tv.x = this.to.myParent.x + this.to.portX;
          this.tv.y = this.to.myParent.y + this.to.textY-padding/2;
        }
      } else {
        this.tv.x = mouseX;
        this.tv.y = mouseY;
      }
  
      if(activeConnector === this && this.from != null && this.to != null) {
        return false;  // it will be also drawn by its owner with transforms, so just return false here.
      }


      // if it is being selected as part of multiselect
      if(multiselecting) {

        var scrf = scrv({x: this.from.myParent.x + this.from.portX, y: this.from.y + padding/3 , w: this.from.w, h: this.from.h, p: 0 });
        var scrt = scrv({x: this.to.myParent.x + this.to.portX, y: this.to.y + padding/3, w: this.to.w, h: this.to.h, p: 0 });

        let mb = {x1:(multibox.x1 < multibox.x2) ? multibox.x1 : multibox.x2, 
                  x2:(multibox.x1 < multibox.x2) ? multibox.x2 : multibox.x1, 
                  y1:(multibox.y1 < multibox.y2) ? multibox.y1 : multibox.y2, 
                  y2:(multibox.y1 < multibox.y2) ? multibox.y2 : multibox.y1  }
  

        /// check intersection of box by checking the 'X' of the box intersecting with straight lines representing the connectors
        /// uses algorithm from here: https://stackoverflow.com/questions/563198/how-do-you-detect-where-two-line-segments-intersect
                  
        let s1_1 = {x: mb.x2 - mb.x1, y: mb.y2 - mb.y1};  // this is '\'
        let s1_2 = {x: mb.x1 - mb.x2, y: mb.y1 - mb.y2};  // this is '/'

        let s2 = {x: scrt.x - scrf.x, y: scrt.y - scrf.y}; // and this is the connector straight-line vector

        let sa = (-s1_1.y * (mb.x1 - scrf.x) + s1_1.x * (mb.y1 - scrf.y)) / (-s2.x * s1_1.y + s1_1.x * s2.y);
        let sb = (-s1_2.y * (mb.x2 - scrf.x) + s1_2.x * (mb.y2 - scrf.y)) / (-s2.x * s1_2.y + s1_2.x * s2.y);
        let t = (    s2.x * (mb.y1 - scrf.y) -   s2.y * (mb.x1 - scrf.x)) / (-s2.x * s1_1.y + s1_1.x * s2.y);

        if( ( (sa >= 0 && sa <= 1 || sb >= 0 && sb <= 1) && t >=0 && t <= 1) ||             // check the box's 'X' OR
              (mb.x2 > scrf.x && mb.y2 > scrf.y && mb.x1 < scrf.x &&  mb.y1 < scrf.y) ||    // the from point in the box OR
              (mb.x2 > scrt.x && mb.y2 > scrt.y && mb.x1 < scrt.x &&  mb.y1 < scrt.y) ) {   // the to   point in the box
            this.isSelected = true;
          } else {
            if(!shifted) {
            //this.rollover = false;
            this.isSelected = false;
            }
          }
        

      }


      return true;
    }
  
    show() {

      if(!pchr.settings.showHidden) {
        if( (this.from != null && this.to != null)) {
          if( (this.to.myParent.hidden || this.from.myParent.hidden) ) {
              return;
         }
        }
      }
      
      // push();
      // translate( canvaswidth/2 + grid.xoff + grid.dx,  canvasheight/2 + grid.yoff + grid.dy);
      // scale(pchr.settings.zoom);
      
      noFill();
      if(activeConnector === this || this.from.rollover || this.to.rollover) {
        strokeWeight(1.5 * (activeConnector === this ? (2*pchr.settings.zoom) : 2));  // scale stroke if we are currently making it
      } else {
        strokeWeight(this.isSelected ? 2 : 1);
      }    
      if(this.isSelected) {
          stroke(200, 100, 0);
      } else {
          stroke(50, 50, 50, 100);
      }
      
        // for SAIs, if parent of this connector is triggered, want to thicken and redden:
        // let t = millis() - this.to.myParent.lastTrigger;
        // let intensity = 400 * this.to.myParent.lastTriggerLevel;   // intensity
        // if(t < intensity) {
        //   stroke(50 + ((intensity-t)/4), 50, 50, 100);
        //   strokeWeight((intensity-t)/200 + 2);
        // }


      
      if((this.from != null && this.from.myParent.issaiunit) || (this.to != null && this.to.myParent.issaiunit)) {
        // if SAI unit, math to make pretty beziers -- control points should go out orthogonally and try not to cross the draggables.

      let cp1x;
      if(this.from != null) {
        if(this.from.param == 'out1') {
          cp1x = (this.fv.x + grid.step > this.tv.x) ? this.fv.x + grid.step - ((this.tv.x - this.fv.x) / 3) : (this.fv.x + this.tv.x) / 2;
        } else {
          cp1x = (this.fv.x - grid.step < this.tv.x) ? this.fv.x - grid.step - ((this.tv.x - this.fv.x) / 3) : (this.fv.x + this.tv.x) / 2;
        }
      } else {
        cp1x = (this.fv.x + this.tv.x) / 2;
      }

      let cp2y = (this.tv.y - grid.step < this.fv.y) ? this.tv.y - grid.step - ((this.fv.y - this.tv.y) / 2) : (this.fv.y + this.tv.y) / 2;

        bezier(this.fv.x, this.fv.y, cp1x, this.fv.y, this.tv.x, cp2y, this.tv.x, this.tv.y);

    } else {
        bezier(this.fv.x, this.fv.y, (this.fv.x + this.tv.x)/2, this.fv.y, (this.fv.x + this.tv.x)/2, this.tv.y, this.tv.x, this.tv.y);
       // line(this.fv.x, this.fv.y, (this.fv.x + this.tv.x)/2, this.fv.y);
       // line((this.fv.x + this.tv.x)/2, this.fv.y, (this.fv.x + this.tv.x)/2, this.tv.y);
       // line((this.fv.x + this.tv.x)/2, this.tv.y, this.tv.x, this.tv.y);
       // line(this.fv.x, this.fv.y, this.tv.x, this.tv.y);
        
        
    }

      // if(this.fv.y  < this.tv.y) {
      //   bezier(this.fv.x, this.fv.y, this.fv.x-((this.tv.x - this.fv.x)/2), this.fv.y, this.tv.x, this.fv.y-((this.tv.y - this.fv.y)/2), this.tv.x, this.tv.y);
      // } else {
      //   bezier(this.fv.x, this.fv.y, (this.fv.x + this.tv.x)/2, this.fv.y, this.tv.x, (this.fv.y + this.tv.y)/2, this.tv.x, this.tv.y);
      // }

      strokeWeight(1);
    
    //  pop();
  
    }
  
  
  
  }