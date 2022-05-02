// to run this server, run 'node server.js full/path/to/devicelocator.csv'

// if the path is not specified in the CLI args, throw error and exit:
if (!process.argv[2]){
  console.log('error: path to device locator file not set in command args\n\nexample: \'node DL.js /Users/mp/remote-programming-tools/devicelocator.csv\'')
  process.exit()
} // path provided, run server script:
  else {
  // load dependencies
  const WebSocket = require('ws');
  const fs = require('fs')
  const papa = require('papaparse')

  // set filepath
  let path = process.argv[2]
  // container for our csv
  let DL;
  
  // read the devicelocator CSV
  fs.readFile(path, 'utf8', (err, data) => {
    if (err) throw err;
    console.log(data);

    // parse the csv, convert to JSON
    papa.parse(data, {
      complete: function(results) {
        DL = results.data
        console.log("converted:", DL);
      }
    });
  });

  // start our websocket server
  const wss = new WebSocket.Server({ port: 8080 });
  
  // when a client connects (i.e. a raspberry pi, another machine, etc...)
  wss.on('connection', function connection(ws) {
    ws.on('message', function incoming(message) {
      // print client connection message
      console.log('received: %s', message);
    });
    // send the devicelocator csv to the client
    ws.send("csv " + JSON.stringify(DL));
  });

}


