
class Selectable {
    constructor(parent) {

      this.isSelected = false;     // Is the object currently selected?  
      this.rollover = false;       // Is the mouse over the selected bounding box?
      this.showConnection = false; // is the thing I'm connected to rolled over?

      this.myParent = parent;
  
      this.x = parent.x;
      this.y = parent.y;
      // Dimensions
      this.w = parent.w;
      this.h = parent.h;

    //  console.log(" * setting x, y, w, h to " + this.x + ", " + this.y + ", " +this.w + ", " +this.h);

    }
  
    update() {
      // set the active boxes for the selector

        this.x = this.myParent.x;
        this.y = this.myParent.y + this.textY - 2*(this.textH)/3;
        this.h = this.textH;
        this.w = this.myParent.w;
    
    }
  
  
    over() {

      let scrp = scrv({x: this.x-padding/2, y: this.y, w: this.w+padding*2, h: this.h, p: this.p});
      // Is mouse over object label?
      // if(this == this.myParent.dataports[0]) console.log("mx: "+ mouseX +", tx: "+ scrp.x + ", tx+tw: " + (scrp.x + scrp.w) + ", my: " + mouseY + ", ty: " + scrp.y + ", ty+th: "+ (scrp.y + scrp.h));

      //  TEST red hitbox
      // stroke(255,0,0);
      // noFill();
      // rect(scrp.x, scrp.y, scrp.w, scrp.h);

      if (mouseX > scrp.x && mouseX < scrp.x + scrp.w && mouseY > scrp.y && mouseY < scrp.y + scrp.h) {
        this.rollover = true;
        anyover = true;
        this.myParent.rollover = false;
      //  console.log("Over " + this.myParent.data.name + " port");
      } else {
        this.rollover = false;
      }
    } 
  
    show() {

      if(this.rollover || this.showConnected) {
        noStroke();
        fill(255, 255, 0, 100); 
        rect(this.x, this.y, this.w, this.h);

        if(this.showConnected) this.showConnected = false;
      }    

    }
  
    pressed() {
      // Did I click on the object label?
      if (this.rollover) {

        // console.log(" ** pressed " + this.param + " of " + this.myParent.data.name);

        if(activeConnector == null) {
          this.isSelected = true;
          selected = this;
          anydragging = true;
          console.log("Selected " + this.param);
        } else {
          
        }
        
      } else {
        if(!overanyport) {
          this.deselect();
        }
      }
    }
  
    released() { 
      if(selected != null && !selected.rollover) {
        if(this.rollover) {
          if(activeConnector != null) {

           // console.log("Trying to complete connection...");

           if(activeConnector.completeConnection(this)) {

            // this.deselect();
            if(!shifted) {
              activeConnector = null; // use shift to connect serially
              this.isSelected = false;
              selected = null;
            }

            // updateMapperLists();
             
           } else {
             // was an invalid connection
             console.log("Invalid connection :(  Try again.");
           }
        } else {
         // this.deselect();
        }
      }
    }
  }

    deselect() {

      if(this.isSelected) {
        this.isSelected = false;
        selected = null;
      //  console.log("Deselected " + this.param);
     }

    }
  }


  ////////  for floating context menu

  class ContextMenu {

    constructor() {
      this.parent = null;
      this.visible = false;
      this.x = 0;
      this.y = 0;
      this.w = 75;
      this.h = padding * 2;
      this.textH = 20;
      this.options = [];
      this.choice = null;
    }

    build(names) {
      this.options = [];
      this.h = padding * 2;
      for(let n in names) {           
        if(names[n] === undefined) continue;
        this.options.push(new PickerOption(this, names[n]));
        textSize(16);
        this.w = max(this.w, textWidth(names[n])+(padding*2));
        textSize(12);
        this.h += this.textH;
      }      
      
      // set current
      for(let n in this.options) {
        if(this.options[n].item == ((this.parent != null)? this.parent.data.name : 'current_mapper_preset')) {  /// to manage mapper context menu - need to put current preset name here.
           this.options[n].current = true;
           this.yoff = (n * this.textH) + 2*padding;
        }
      }
    }

    show(mx, my) {
      this.x = mx;
      this.y = my - this.yoff;
      this.visible = true;
    }

    hide() {
      this.visible = false;
      this.yoff = 0;
      this.choice = null;
    }

    update() {
      for(let n in this.options) {
        this.options[n].update();
      }
    }

    over() {
      for(let n in this.options) {
        this.options[n].over();
      }
    }

    pressed() {
      for(let n in this.options) {
        this.options[n].pressed();
      }
    }

    released() {
      this.choice = null;
      for(let n in this.options) {
        this.choice = this.options[n].released();
        if(this.choice != null) return;
      }
    }

    draw() {
      fill(220, 200);
      rect(this.x-1, this.y-3, this.w+2, this.h, padding);
      for(let n in this.options) {
        this.options[n].show();
      } 
    }

  }

  class PickerOption extends Selectable {

    constructor(parent, name) {

      super(parent);

      this.parent = parent;
      this.item = name;
      this.textH = parent.textH;
      this.h = parent.textH;
      this.textY = (parent.options.length * this.textH) -1;
      this.current = false;

    }

    over() {

      //let scrp = scrv({x: this.x, y: this.y, w: this.w, h: this.h, p: this.p});
      // Is mouse over object label?
      // if(this == this.myParent.dataports[0]) console.log("mx: "+ mouseX +", tx: "+ scrp.x + ", tx+tw: " + (scrp.x + scrp.w) + ", my: " + mouseY + ", ty: " + scrp.y + ", ty+th: "+ (scrp.y + scrp.h));

      //  TEST red hitbox
      // stroke(255,0,0);
      // noFill();
      // rect(scrp.x, scrp.y, scrp.w, scrp.h);

      if (mouseX > this.x && mouseX < this.x + this.w && mouseY > this.y && mouseY < this.y + this.h) {
        this.rollover = true;
        anyover = true;
        this.parent.choosing = this.item;
        // console.log("Over " + this.item );
        anyover = true;
      } else {
        this.rollover = false;
      }
    }

    released() {
      if(!this.rollover) return null;
      if(this.current) return null;
      return this.item;
    }

    show() {

      this.y = this.parent.y + this.textY;
      this.w = this.parent.w;
      // console.log(" putting " + this.item + " at " + this.x.toFixed(2) + ", " + this.y.toFixed(2));
      super.show();
      noStroke();
      if(this.current) {
        fill(255, 255, 0, 60); 
        rect(this.x, this.y, this.w, this.h);
        stroke(0);
        strokeWeight(1);
      }
      if(displaytext) {
        fill(0);
        textSize(16);
        text(this.item, this.x+2, this.y+this.h-padding);
        textSize(12);
      }
    //      image(this.textImage, this.x, this.y);
      strokeWeight(0.5);

    }
  }