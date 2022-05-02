var grid;
var patchables;
var nextID;
var objToKill = [];

var testmode = false;

var dragginggrid = false;
var multiselecting = false;
var multibox = {x1: 0, x2: 0, y1: 0, y2: 0};
var anymulti = false;

var anyover = false;
var anydragging = false;
var overanyport = false;
var selected = null;
var activeConnector = null;
var countConnectors = 0;
var shifted = false;
var spaced = false;
var alted = false;
var commanded = false;
var dragOffset = 0;
var availablepresets = [];
var floatingpicker = null;

var copies = {};
var connectorsToCopy = [];

var dying = false;  // use this to know I'm in the process of killing a patcher, will update asynchronously once the JSON is saved.

var canvaswidth  = 800;
var canvasheight = 800;

var displaytext = false;  /// this toggles the old way of doing text rendering, which is MUCH slower than using images

const labelheight = 20;
const padding = 5;
const minzoom = 0.4;
const maxzoom = 3.5;
const gridSize = 20;

function setup() {

  canvaswidth = min(1000, windowWidth *0.85);
  canvasheight = min(1000, windowHeight *0.85);

  let cnv = createCanvas(canvaswidth, canvasheight).parent("container-pchr").style('border-radius: '+ (2*padding) +'px; border-style: solid');
  cnv.parent().oncontextmenu = function() { mousePressed(); return false; };   // suppress right-click context menus on mapper

  nextID = 101;
  
  
  grid = new Grid();

  patchables = [];
  overanyport = false;
  objToKill = []; // used for culling object list;

  floatingpicker = new ContextMenu();
  
  setTimeout(() => { sync_saved_settings(); }, 1500 );   // wait 1500 milliseconds, then update Patcher from pchr.

  
}

async function showFloatingPicker(curp) {

  console.log(" Context menu! ");

  // let context = (curp == null) ? 'mapper' : 'designer';

  // await getPresetList(context);
  // floatingpicker.parent = curp;
  // floatingpicker.build(availablepresets);
  //   // console.log(" putting picker with " + curp.data.name + " selected at " + mouseX.toFixed(2) + ", " + mouseY.toFixed(2) + ":");
  // console.log(JSON.stringify(availablepresets));
  // floatingpicker.show(mouseX, mouseY);

}

async function getPresetList(appname) {
  // make a profile selector we'll use for context-dependent profile assignments:


  // await sai.database.ref(mapper.subfolder + '/' + appname + '/presets/').once('value', function(snapshot) {
  //   availablepresets = [... new Set(snapshot.val())];
  // });

  // console.log("available: " + availablepresets);
}

function windowResized() {
  canvaswidth = min(1000, windowWidth *0.95);
  canvasheight = min(1000, windowHeight *0.85);
  resizeCanvas(canvaswidth, canvasheight);
}

function draw() {

  cursor(ARROW);

  background(250);
  grid.draw();

  anyover = false;
  overanyport = false;

  // objects.forEach(o => o.over());
  for(let i in patchables) {
    if(patchables[i].over()) {
        overanyport = true;
    }
  }

  // console.log("overanyport " + overanyport);

  for(let i in patchables) {
    if(!patchables[i].update()) {
        objToKill.push(i);
    }
  }

  // cullPatchables();  
  
  patchables.sort( function(a, b) { if(a.dragging && !b.dragging) return 1; if(b.dragging && !a.dragging) return -1; return 0;});  // sorts by whether or not they are dragging - dragged items draw last
  
  patchables.forEach(o => o.draw());

  if(selected != null) {
    if(selected.inport) {
        if(activeConnector == null) {  
          activeConnector = new Connector(null, selected);  
        }
      } else {
        if(activeConnector == null) {  
          activeConnector = new Connector(selected, null); 
      }
    }
    if(activeConnector.update()) { 
        activeConnector.show(); 
      }
    else {    // connector being drawn was killed (update returned false)
      selected.deselect();
      activeConnector = null;
    }
  } else {  
    activeConnector = null;
  }

  

  if(spaced && !anyover && mouseInCanvas()) {
    cursor('grab');
  } 

  // console.log(" activeconnector: " + activeConnector);

  if(activeConnector == null) {
    if (keyIsDown(LEFT_ARROW)) {
      grid.xofftarg += .5* grid.step * pchr.settings.zoom;
      cursor('grab');
    }
    if (keyIsDown(RIGHT_ARROW)) {
      grid.xofftarg -= .5* grid.step * pchr.settings.zoom;    
      cursor('grab');
    }
    if (keyIsDown(UP_ARROW)) {
      grid.yofftarg += .5* grid.step * pchr.settings.zoom;    
      cursor('grab');
    }
    if (keyIsDown(DOWN_ARROW)) {
      grid.yofftarg -= .5* grid.step * pchr.settings.zoom;  
      cursor('grab');  
    }
}





  if(multiselecting) {

    push();
    multibox.x2 = mouseX;
    multibox.y2 = mouseY;
    strokeWeight(1);
    stroke(128);
    fill(0, 10);
    rectMode(CORNER);
    rect(multibox.x1, multibox.y1, multibox.x2-multibox.x1, multibox.y2-multibox.y1);
    // text("1", multibox.x1, multibox.y1);
    // text("2", multibox.x2, multibox.y2);
    pop();

  }

  floatingpicker.update();

  if(floatingpicker.visible) {
    floatingpicker.over();
    floatingpicker.draw();
  }



}

function cullPatchables() {
  for (let i in objToKill) {
    patchables.splice([objToKill[i]-i], 1);

  }
  objToKill = [];
}


function addPatchable(pdata) {

  p = null;

  // check to see if we already have it:
  for(let i in patchables) {
    if(patchables[i].name == pdata.title) {

      if(patchables[i].orphan) {
        console.log("  Oh - I have that one already as an orphan.  I'll replace it with this one.")
        patchables[i] = new Patchable(pdata.title, pdata.in, pdata.out);
        patchables[i].orphan = false;
        return patchables[i];
      }

      console.log("  Oh - that one already exists. (Returning the old one and updating current position)");
      patchables[i].hidden = false;
      patchables[i].dying = false;

      return patchables[i];
    }
  }

  p = new Patchable(pdata.title, pdata.in, pdata.out); 
  console.log(" ... adding new patchable " + p.name);
  patchables.push(p);

  return p;
}

function orphanPatchable(title, o) {

  for(let i in patchables) {
    if(patchables[i].name == title) {

      // console.log("OrphanPatchable: Set " + title + " to " + o + " and orphan is currently " + patchables[i].orphan);

      if(patchables[i].orphan == (o == 'true')) {
         return;
       }
       patchables[i].orphan = (o=='true');
       patchables[i].textImage = patchables[i].createTextImage(( patchables[i].orphan ? (title + " X") : title), padding, patchables[i].w, patchables[i].labelheight, CENTER, true);
       break;
    }
  }
}

function setPatchableHidden(title, h) {

  for(let i in patchables) {
    if(patchables[i].name == title) {
       if(patchables[i].hidden != (h=='true'))  patchables[i].hidden = (h=='true');
       break;
    }
  }
}

function highlightPatchable(title) {

  for(let i in patchables) {
    if(patchables[i].hidden && !pchr.settings.showHidden) continue;
    if(patchables[i].name == title) {
       patchables[i].highlight = true;
       break;
    }
  }
}

function removePatchable(title) {

  for(let i in patchables) {
    if(patchables[i].toKill || patchables[i].dying) continue;

    if(patchables[i].name == title) {
       patchables[i].toKill = true;
       break;
    }
  }
}



function screenMouse() {
  return({x: ((mouseX - canvaswidth/2)/pchr.settings.zoom), y: ((mouseY - canvasheight/2)/pchr.settings.zoom)});
}

async function mousePressed() {

// anyover = false;

//console.log("going to check sai list now: " + saiList);

// mapper.loadingPreset = false;  

if(!anyover) {
  if(floatingpicker.visible) {
    console.log(" hiding picker ");
    floatingpicker.hide();
  }

  if(mouseButton === RIGHT) {
    showFloatingPicker(null);
    return;
  }


  if(!shifted) {
    console.log(" clearing multiselect...");
    await patchables.forEach(o => o.clearMulti());  
    anymulti = false;    
  }

} else {



}

  // Handle dragging and selection
  await patchables.forEach(o => o.pressed());

  // ok, now some might have been copied, if there are connectors to copy we do that here:

  for(let id in copies) {
      console.log(" ---> " + id + " : " + copies[id].data.id); 
  }
  
  for(let i in connectorsToCopy) {
      let c = connectorsToCopy[i];

      let fromIndex = c.from.myParent.dataports.indexOf(c.from);
      let toIndex   = c.to.myParent.dataports.indexOf(c.to);
      let newFrom   = copies[c.from.myParent.data.id];
      let newTo     = copies[c.to.myParent.data.id];

      console.log(" ** newFrom id is " + newFrom.data.id + " and newTo id is " + newTo.data.id + 
            " \n\n ** copying connector that goes from " + c.from.myParent.data.id + " port " + fromIndex + " -> " + 
                                                               c.to.myParent.data.id + " port " + toIndex + "  \n \n");

      let new_c = new Connector(newFrom.dataports[fromIndex], newTo.dataports[toIndex]);
      newFrom.dataports[fromIndex].connectors.push(new_c);
      newTo.dataports[toIndex].connectors.push(new_c);

      pchr.settings.currentConnectors.push({fromSaiId: new_c.from.myParent.data.id, toSaiId: new_c.to.myParent.data.id, fromPort: new_c.from.param, toPort: new_c.to.param});

      console.log(" ** new connector goes from " + new_c.from.myParent.data.id + " port " + fromIndex + " -> " + new_c.to.myParent.data.id + " port " + toIndex + "  \n \n");

    }

  connectorsToCopy = [];
  copies = {};


  if(!anyover && dragginggrid == false && mouseInCanvas()) {

    if(!spaced && !testmode) {

        console.log(" multiselect!  " + mouseX + ", " + mouseY);
        multiselecting = true;
        multibox.x1 = mouseX;
        multibox.y1 = mouseY;
        multibox.x2 = mouseX;
        multibox.y2 = mouseY;

    } else {
      if(spaced) {
        dragginggrid = true;
        draggridoffset = {x: mouseX, y: mouseY};
      }
    }
  }

}


// function mousePressed() {
//   // Handle dragging and selection
//   patchables.forEach(o => o.pressed());
// }

// function mouseReleased() {
//   // Handle dragging and selection
//   patchables.forEach(o => o.released());
//   anydragging = false;
// }

async function mouseReleased() {
  // Handle dragging and selection
  patchables.forEach(o => o.released());

  if(anydragging) {
 //     updateMapperLists();
    }

  anydragging = false;
  if(dragginggrid) {
      dragginggrid = false;
      grid.xoff += grid.dx; 
      grid.yoff += grid.dy; 

      grid.xofftarg = grid.xoff;
      grid.yofftarg = grid.yoff;


      pchr.settings.gridoffset = {x: grid.xoff, y: grid.yoff};
      // noteChange( {behaviour: 'MAP', 
      //     name     : 'gridoffset',
      //     value    : {x: grid.xoff, y: grid.yoff},
      //     target   : null
      // });
  } 

  if(floatingpicker.visible) {
    floatingpicker.released();
    if(floatingpicker.choice != null) {
      if(floatingpicker.parent != null) { // loading a designer preset
       floatingpicker.parent.loadProfile(floatingpicker.choice);
       patchables.forEach(s => {
         if(s == floatingpicker.parent) return;
         if(s.multi) s.loadProfile(floatingpicker.choice);
       });
       floatingpicker.hide();
      } else {                            // loading a mapper preset to place
        console.log("Going to load " + floatingpicker.choice + ".");

        // let s = {};

        // var data = {};
        //         data.beh = 'MAP';
        //         data.preset = floatingpicker.choice;
        //         data.source = 'firestore';
        //         data.sendosc = false;
        //         data.merge = true;
        //         s = await requestSettings(data);
        
        // mergeMap(s);
        
        floatingpicker.hide();
      }
    }
  }

  if(multiselecting) {
     multiselecting = false;
     console.log(" ... end Multiselect!");
  }

}

function mouseWheel(event) {

  // mapper.loadingPreset = false;  

  if(mouseInCanvas()) {

    if(floatingpicker.visible) floatingpicker.hide();

    pchr.settings.zoom -= (event.delta)/500;
    pchr.settings.zoom = min(max(pchr.settings.zoom, minzoom), maxzoom);
    
    // noteChange({ behaviour: 'MAP', 
    // name     : 'zoom',
    // value    : pchr.settings.zoom,
    // target   : null
    //             });

    return false;
  };
}

function mouseInCanvas() {

  if(mouseX < 0 || mouseX > canvaswidth || mouseY < 0 || mouseY > canvasheight) {
    return false;
  }

  return true;
}

function keyPressed() {

  
  if(keyCode === RIGHT_ARROW) {
    return false;
  }

  if(keyCode === LEFT_ARROW) {
    return false;
  }

  if(keyCode === UP_ARROW) {
    return false;
  }

  if(keyCode === DOWN_ARROW) {
    return false;
  }


  if(key == '`') {

     console.log(" pushed Tilde, grabbing current settings then looking in pchr.settings.currentPatchables... ");
     sync_saved_settings();

  }
  
  if(key == 't') {
     displaytext = !displaytext;
     console.log(" text: " + displaytext);
  }


  if(keyCode === BACKSPACE || keyCode === DELETE) {
    // if there is an active connector
    if(activeConnector != null) activeConnector.toKill = true;

    // if we are rolled over an object title
    for(let i in patchables) {
      if(patchables[i].rollover || patchables[i].multi ) {
         patchables[i].toKill = true;
      }

      // check & kill connectors
      for(let p in patchables[i].dataports) {
        for(let c in patchables[i].dataports[p].connectors) {
          let conn = patchables[i].dataports[p].connectors[c];
          if(conn.isSelected || conn.to.rollover || conn.from.rollover || patchables[i].toKill) {
            conn.toKill = true;
         }
        }
      }   

    }
  }

  if(keyCode === 32) {
    spaced = true;
    console.log("Spaced " + spaced);
  }

  if(keyCode === SHIFT) {
    shifted = true;
   // console.log("Shifted " + shifted);
  }

  if(keyCode === ALT) {
    alted = true;
   // console.log("Alted " + alted);
  }
  
  if(keyCode === 91) {
    commanded = true;
    console.log("Commanded " + commanded);
  }

  return false;  // prevent default
}

function keyReleased() {

  if(keyCode === SHIFT) {
    shifted = false;
    //console.log("Shifted " + shifted);
  }
  if(keyCode === 32) {
    spaced = false;
    console.log("Spaced " + spaced);
  }

  if(keyCode === ALT) {
    alted = false;
   // console.log("Alted " + alted);
  }
  if(keyCode === 91) {
    commanded = false;
  }

}

// convert absolute coordinates to screen coordinates
function scrv(inv) {
  return({x: (inv.x*pchr.settings.zoom)+grid.xoff+grid.dx+(canvaswidth/2), 
          y: (inv.y*pchr.settings.zoom)+grid.yoff+grid.dy+(canvasheight/2), 
          w:  inv.w*pchr.settings.zoom, 
          h:  inv.h*pchr.settings.zoom, 
          p:  inv.p*pchr.settings.zoom});
}

function sync_saved_settings() {

  console.log("  Syncing saved settings... ");

  ///

  newp = null;

  let recenter = true; // flag to recenter old patchers that used the non-zoomable canvas - they will be in bottom right quadrant, all positive x/y positions.

  for(let i in pchr.settings.currentPatchables) {
   p = pchr.settings.currentPatchables[i];

   console.log("  Building " + p.displayName +" from pchr info.");
   ip = [];
   op = [];
   for(let d in p.dataPorts) {
     dp = p.dataPorts[d];
     if(dp.inport) { 
       // console.log(" found an inport with " + dp.param + " of " + dp.val);
       ip.push({param:dp.param, value:dp.val});
     }
     else { 
       // console.log(" found an outport with " + dp.param + " of " + dp.val);
       op.push({param:dp.param, value:dp.val});
     }
   }

   newp = addPatchable({ title: p.displayName, in: ip, out: op});

   p = pchr.settings.currentPatchables[i];  // don't know why I need to define this again, but i do.

   if(newp != null) {
   //  console.log(" adjusting " + p.displayName + "'s position: (" + p.screenX + ", " + p.screenY +")");
     newp.x = Number(p.screenX);
     newp.y = Number(p.screenY);
    //     newp.hidden = (p.show == 'false');

    if(p.screenX < 0 || p.screenY < 0) recenter = false;  // if any patchers are already in negative territory, don't recenter.

   }
  }

  if(recenter) {  // this is a hack to recenter old patcher layouts to use the new zoomable canvas

      for (let patch in patchables) {
        patchables[patch].x -= grid.grid_extent/2;
        patchables[patch].y -= grid.grid_extent/2;

        patchables[patch].x = min(max(-grid.grid_extent, patchables[patch].x), grid.grid_extent);
        patchables[patch].y = min(max(-grid.grid_extent, patchables[patch].y), grid.grid_extent);
      }

  }


  /////// now do connectors!

  currentConnectors = [];

  for(let i in pchr.settings.currentConnectors) {
    c = pchr.settings.currentConnectors[i];

    fromPatch = null;
    fromPt = null;
    toPatch = null;
    toPt = null;

    for(let p in patchables) {
      if(patchables[p].name == c.fromPatchable) {
        fromPatch = patchables[p];
        for(let dp in fromPatch.dataports) {
          if(fromPatch.dataports[dp].param == c.fromPort) {
            fromPt = fromPatch.dataports[dp];
          }
        }
      }
    }

    if(fromPatch == null || fromPt == null) {
      console.log("  Couldn't find a fromPatchable (" + c.fromPatchable + ") or fromPort (" + c.fromPort + ") for this connector");
      continue;
    }
     
    for(let p in patchables) {
      if(patchables[p].name == c.toPatchable) {
        toPatch = patchables[p];
        for(let dp in toPatch.dataports) {
          if(toPatch.dataports[dp].param == c.toPort) {
            toPt = toPatch.dataports[dp];
          }
        }
      }
    }
      
    if(toPatch == null || toPt == null) {
      console.log("  Couldn't find a toPatchable (" + c.toPatchable + ") or toPort (" + c.toPort + ") for this connector");
      continue;
    }

    console.log("Adding connector: " + fromPt.param + " -> " + toPt.param);


    toAdd = new Connector(fromPt, null);
    toAdd.completeConnection(toPt);

  }

}


// ======


class Grid {

  zoom = 1.0;
  xoff = 0.0;
  yoff = 0.0;
  xofftarg = 0.0;
  yofftarg = 0.0;
  step = 25;

  grid_extent = width/2;

  constructor(params) {

    
  }

  draw() {
    if(pchr.settings === undefined) {
      console.log("no patcher?");
      return;
    }

    this.zoom = pchr.settings.zoom;
    this.grid_extent = (canvaswidth / 2) / (minzoom); // 50 * this.step;
    this.dx = 0;
    this.dy = 0;
    
    push();

    if(dragginggrid) {
      this.dx = mouseX - draggridoffset.x;
      this.dy = mouseY - draggridoffset.y;
    }

        // pan with arrow keys

        if(abs(this.xoff - this.xofftarg) > (this.step/4)*pchr.settings.zoom) { 
          this.xoff = lerp(this.xoff, this.xofftarg, 0.3);
        } else { this.xofftarg = this.xoff };
        if(abs(this.yoff - this.yofftarg) > (this.step/4)*pchr.settings.zoom) {
          this.yoff = lerp(this.yoff, this.yofftarg, 0.3);
        } else { this.yofftarg = this.yoff };


    // keep zooming or drgging grid in bounds (TBD - sync pan with zoom? -mg):

    this.dx = max(min( this.dx , (( this.grid_extent*pchr.settings.zoom)-this.xoff)-canvaswidth/2),
                                -(((this.grid_extent*pchr.settings.zoom)+this.xoff)-canvaswidth/2));
    this.dy = max(min( this.dy , (( this.grid_extent*pchr.settings.zoom)-this.yoff)-canvasheight/2),
                                -(((this.grid_extent*pchr.settings.zoom)+this.yoff)-canvasheight/2));


    // console.log("ytrans: [" + canvasheight/2 + " + " + this.yoff + " + " + this.dy + "] -- " + (canvasheight/2 + this.yoff + this.dy));
    translate(canvaswidth/2 + this.xoff + this.dx, canvasheight/2 + this.yoff + this.dy);
    scale(pchr.settings.zoom);

    for (let i = 0; i < this.grid_extent; i += this.step) {

      strokeWeight(.4);
      stroke(0, 20);
      if (i % (5*this.step) == 0) stroke(0, 50);

       if(i == 0 ) {
         strokeWeight(2);
         //stroke(255, 0 ,0);
       }
  
      line (0-this.grid_extent, i, 
            this.grid_extent, i);
      line (i, 0-this.grid_extent, 
        i, this.grid_extent);

      if (i == 0) continue;

      line (0-this.grid_extent, -i, 
            this.grid_extent, -i);
      line (-i, 0-this.grid_extent, 
            -i, this.grid_extent);
    }
    
    pop();
    strokeWeight(2);
    stroke(0, 50);
    noFill();
    rect(1, 1, canvaswidth-2, canvasheight-2, padding*2);

    stroke(0, 20);
    strokeWeight(1);
    line(mouseX, 0, mouseX, canvasheight);
    line(0, mouseY, canvaswidth, mouseY);

  }

}


///============
///============
///============


////////  Patchable

class Patchable extends Draggable {

    constructor(name, invals, outvals) {

      let thish = 50+(invals.length*15)+(outvals.length*15);
      let thisw = max(75, textWidth(name)+(padding*2));

      super(random(width-75), random(height-thish), thisw, thish, padding, labelheight);

      this.dataports = [];

      this.name = name;
      this.invals = invals;
      this.outvals = outvals;

      this.multi = false;
      this.highlight = false;
      this.highlightfade = 0;

      this.toKill = false;
      this.orphan = true;    // see what happens if we start as orphans by default
      this.hidden = false;

      this.textHeight = (this.h-25) / (invals.length + outvals.length + 1);
      this.textHeight = textSize() + padding;

      // console.log(" Making new patcher with invals: "+ invals);

      for(let i in invals) {
        var p = new InPort(invals[i].param, invals[i].value, this);
        p.textH = this.textHeight;
        p.textY = 45 + (i)*(p.textH);
        this.dataports.push(p);

        thisw = max(thisw, max(75, textWidth(invals[i].param)+(padding*2)));

      }  

      for(let i in outvals) {
        var p = new OutPort(outvals[i].param, outvals[i].value, this);
        p.textH = this.textHeight;
        p.textY = 45 + (i)*(p.textH) + (invals.length * p.textH);
        this.dataports.push(p);

        thisw = max(thisw, max(75, textWidth(outvals[i].param)+(padding*2)));
      }

      if(thisw > this.w) this.w = thisw;

      for(let p in this.dataports) {
        this.dataports[p].makeLabelImage();
      }

      this.textImage = this.createTextImage((this.orphan? (this.name + " X") : this.name), padding, this.w, this.labelheight, CENTER, true);
  }

  createTextImage(t, p, w, h, a, b) {

    console.log(" Creating textImage [" + t + "] with w: " + w + " and h: " + h);  
    
    if(w === undefined || h === undefined) return;
    
    let ti = createGraphics(w * maxzoom, h * maxzoom);
    ti.fill(0);
    ti.stroke(0);
    ti.strokeWeight(b ? maxzoom : 0);
    ti.textAlign(a);
    var oldtextSize = textSize();
    ti.textSize((oldtextSize * maxzoom));
    ti.text(t, p * maxzoom, p * maxzoom, (w-(1.5)*p) * maxzoom, (h) * maxzoom);
    textSize(oldtextSize);

    return(ti);
  }

  update() {
    super.update();

    if(this.toKill) {
      outgoingPatchableUpdate(this.name, {killMe:'true'});
//      this.killMyConnectors();
      this.dying = true;
      this.toKill = false;
      return false;
    }

    if(this.highlightfade > 200) {
      this.highlightfade = 0;
      this.highlight = false;
    }

    // update ports
    for(let i in this.dataports) {
      let p = this.dataports[i];
      p.update();
    }
 
    return true;
  }

  sendPosUpdate() {
     outgoingPatchableUpdate(this.name, {screenX:Math.round(this.x), screenY:Math.round(this.y)});

  }


  killMyConnectors() {

     for(let p in this.dataports) {
       for(let c in this.dataports[p].connectors) {
         if(this.inport) this.dataports[p].connectors[c].to   = null;  // be a good citizen and disconnect first
         else            this.dataports[p].connectors[c].from = null;
         this.dataports[p].connectors[c].toKill = true;
       }
       this.dataports[p].connectors = [];
     }   

  }

  over() {
    if(this.hidden && !pchr.settings.showHidden) return false;    
    
    super.over();

    var overport = false;

    if((!anydragging && !dragginggrid) || selected != null || !this.multi) {
      // check ports
      for(let i in this.dataports) {
        let p = this.dataports[i];
        p.over();
        if(p.rollover) overport = true;
      }
    }

    return overport;

  }

   
  clearMulti() {
    console.log(" Clearing multi... ");
    this.multi = false;
    this.rollover = false;
  }

  pressed() {
    if(this.hidden && !pchr.settings.showHidden) return;
    
    if(this.rollover) {
      // console.log("rolled over " + this.data.name + " and clicked...")
      if(mouseButton === RIGHT) {
       showFloatingPicker(this);
       return;
      }
    }
 
    super.pressed();

    if(!anydragging) {
      // check ports
      for(let i in this.dataports) {
       let p = this.dataports[i];
      p.pressed();
     }
   }

  }

  released() {
    if(this.hidden && !pchr.settings.showHidden) return;
      if(!anydragging || selected != null ) {
        // check ports
        for(let i in this.dataports) {
        let p = this.dataports[i];
        p.released();
        } 
      } else {
        
        if(this.dragging || this.autodrag) { 
          // just released a patchable - update its X, Y position via OSC, unless it is an orphan
          if(!this.orphan) {
           this.sendPosUpdate();
          }
        }

      }

      super.released();

      if(shifted && this.rollover && !multiselecting) {
        this.multi = !this.multi;
        if(this.multi) anymulti = true;
      }

  }
  
  draw() {
    if(this.hidden && !pchr.settings.showHidden) return;    
    super.show();
  }

  // overridden from superclass
    drawme = function() {

    if(this.highlight) {

      noStroke();
      fill(150, 200, 150, 255-(this.highlightfade));
      this.highlightfade += 10;
      rect(this.x-padding, this.y-padding, this.w+(2*padding), this.h+(2*padding), this.r);
      strokeWeight(1);
      stroke(0);

    }



    if(this.dragging || this.autodrag) { // shadow bling

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
    } else if (this.rollover || this.multi) {
      fill(255, 200, 0, 100 * this.opacity);
    }
    rect(this.x, this.y, this.w, this.labelheight, this.r, this.r, 0, 0);

    ////

    this.opacity = 1.0; // reset to normal 
    if(this.orphan) this.opacity *= .2;
    if(this.hidden) this.opacity *= .2;

    // show name
    
    if(displaytext) {
      fill(0);
      stroke(0);
      var textlabel = (this.name);
      if(this.orphan) {
        textlabel = (this.name + " X");
      }
    textAlign(CENTER);
      text(textlabel, this.x+padding, this.y+padding, this.w-padding, this.h);
    }
    image(this.textImage, this.x, this.y, this.w, this.labelheight);
    line(this.x, this.y+this.labelheight, this.x+this.w, this.y+this.labelheight);

    if(this.dying && !this.hidden) {
      strokeWeight(3);
      line(this.x+padding, this.y+padding, this.x+this.w-padding, this.y+this.h-padding);
      line(this.x+this.w-padding, this.y+padding, this.x+padding, this.y+this.h-padding);
      strokeWeight(1);
    }

    noStroke();

    // show ports
    for(let i in this.dataports) {
      let p = this.dataports[i];
      p.show();
    }

  }

}

