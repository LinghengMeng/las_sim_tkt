
class DataPort extends Selectable {

    constructor(p, v, parent, inport) {
   
     super(parent);
   
     // max number of connections per port -- attempting to add more will select existing (for deletion)
     // only one connection per port if it is an SAI, otherwise... 30?
     this.maxconnections = (parent.issaiunit) ? 1 : 30;   
     this.param = p;
     this.value = v;
     this.myParent = parent;
     this.inport = inport;  // true if it is input, false if out
     this.connectors = [];
   
    }

    makeLabelImage() {
        this.textImage = this.myParent.createTextImage(this.param, padding, this.myParent.w, this.myParent.textHeight, (this.inport ? LEFT : RIGHT), false);
    }
   
    show() {
       super.show();
   
       // text label
       if(displaytext) {
        noStroke();
        fill(0);
        text(this.param, this.myParent.x+this.textX, this.myParent.y+this.textY);
       }
       image(this.textImage, this.myParent.x, this.myParent.y+this.textY-this.myParent.textHeight+padding/2, this.myParent.w, this.myParent.textHeight);
   
       // port
       stroke(0);
       fill(255);
       if(this.rollover || this.showConnected) fill(200, 200, 0);
       if(this.isSelected) fill(255, 0, 0);
       rect(this.myParent.x+this.portX-(padding-2), this.myParent.y+this.textY - (padding), padding*2-4, padding);
   
      }
   
      update() {
        super.update();
      }
   
      over() {
        super.over();

        for(let i in this.connectors) {
           if(this.inport) {
               if (this.connectors[i].from.rollover) this.showConnected = true;
           } else {
               if (this.connectors[i].to.rollover) this.showConnected = true;
           }
        }
      }
   
}
   
   
   
class InPort extends DataPort {
    constructor(p, v, parent) {

    super(p, v, parent, true);
    this.textX = padding;
    this.portX = 0;

    }

    show() {
        textAlign(LEFT);
        super.show();

        var tokill = [];
        // cull the connectors - outports are responsible for updating them but inports still need to cull connectors that have been set to null.
        for (let i in this.connectors) {
            if(this.connectors[i] == null || this.connectors[i].toKill) {
                tokill.push(i);
            }
        }
        // remove any connectors that are null or need to die from my list
        for (let i in tokill) {
            activeConnector = null;
            this.connectors.splice([tokill[i]-i], 1);  // toKill is an array of indices to remove.
        }
    }
}



class OutPort extends DataPort {
    constructor(p, v, parent) {

    console.log("Crating new outport with " + p + ": " + v);

    super(p, v, parent, false);
    this.textX = parent.w-padding;
    this.portX = parent.w;

    }

    show() {
        textAlign(RIGHT);
        super.show();

        // update (and set up for killing) the connectors - 
        var tokill = [];
        for (let i in this.connectors) {

            this.connectors[i].update();  //   outports are responsible for updating them.

            if(this.connectors[i] == null || this.connectors[i].toKill) {
                this.connectors[i] = null;
                tokill.push(i);  // at this point only pushing one at a time b/c only one active connector possible at a time
            }
        }
        // remove any connectors that are null from my list
        for (let i in tokill) {
           activeConnector = null;
            this.connectors.splice([tokill[i]-i], 1);  // toKill is an array of indices to remove.
        }

        this.connectors.forEach(c => c.show());
    }


}
   
   