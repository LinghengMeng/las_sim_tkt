/// NOTE
// Keeping this file for archival sake, but it was simpler to run monitor control commands through pipresents OSC interface
// rather than running a seperate node socket client running on the pi...




var express = require('express');
var socket = require('socket.io');
var osc = require('node-osc');



//Initialize server, socket and osc client
var app = express();
var server = app.listen(3000);
var io = socket(server);


var serverIp = '192.168.2.25';
var serverPort = '3000';
var piIdx = 1; // this pi's index
var hdmiState = true 

var socket;
socket = io.connect(serverIp+":"+serverPort);

socket.on('toggleInterpDisplay', toggleHDMI);

function toggleHDMI(value){
    if (value == piIdx){
        if (hdmiState){
            exec('tvservice -o');
        }
        else if (!hdmiState){
            exec('tvservice -p')
        }

    }
}