// to run this client, run 'node client.js /full/path/to/deviceLocator.csv'
if (!process.argv[2]){
  console.log('error: device locator CSV write path not specified\n\n example \'node getDL.js /full/path/to/deviceLocator.csv\'')
  process.exit()
} else {

  // gather dependencies
  const WebSocket = require('ws');
  const papa = require('papaparse')
  const fs = require('fs')


  // set server url
  csvFilePath = process.argv[2]
  // setup websocket
  const ws = new WebSocket('ws:/controlComputer:8080');
  
  // when this client successfully connects with server, send a message
  ws.on('open', function open() {
    ws.send('requestCSV');
  });
  
  // receive messages
  ws.on('message', function incoming(data) {
    console.log(data)

    let message = data.substr(0, data.indexOf(" "));

    let arg = data.substr(data.indexOf(' ') + 1);
    switch(arg) {

      case "csv":

      let deviceLocator = papa.unparse(message)
      console.log(deviceLocator)

      fs.writeFile(csvFilePath, deviceLocator, 'utf8', function (err) {
        if (err) {
          
          console.log('Some error occured - file either not saved or corrupted file saved.');
        } else{
          console.log('It\'s saved!');
        }
      });
    }
  });
}
