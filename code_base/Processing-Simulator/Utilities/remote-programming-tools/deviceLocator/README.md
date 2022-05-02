## server.js

1. install nodejs on control computer
2. configure the control computer's hostname as 'controlcomputer' (no camel case for this please)
3. run the server using
```shell
node server.js /full/path/to/devicelocator.csv
```
**important** the path to the devicelocator.csv that you pass to the node script must the same file that the master script is currently using. 	

## client.js
1. install nodejs on all machines that aren't the control computer. 
2. setup client.js as a linux service. see [issue 3](https://github.com/pbarch/remote-programming-tools/issues/3)
3. for each machine, run:
```shell
node client.js /full/path/to/devicelocator.csv
```
*note* the client-side device locator csv path must be the same as what the client-side processing sketch will read from.

*note for developers* if you want to run the server.js on a machine whose hostname is NOT the *'controlcomputer'* and you don't want to change it, you can run server.js, and then run client.js with the server's IP address as a command line argument. for example, if running both scripts on the same machine, you could simply pass the localhost IP to the client.js script:

```shell
node client.js /full/path/to/devicelocator.csv 127.0.0.1
```
