FEB 17 2020: a lot of this information relates to older tools and Amatria/ROM-era code processes that are now found in the 'deprecated' folder


Unix/Linux utilities for managing and reprogramming a network comprising
 - client laptop
 - a number of Raspberry PIs on network 172.23.0.X
 - a bunch of Teenys connected to these Raspberry PIs

Assumed client environment:
 - laptop able to open a unix/linux terminal and run bash shell commands (a Mac using Terminal, or a Windows machine with Cygwin installed)

Assumed directory structures:

client laptop:
 ~/system
 ~/system/pi_code - local copies of the tools that run on the PI
 ~/system/code    - local unzipped copy of the code library from github
 ~/system/tools   - local tools for interacting with the PIs

PIs:
 /home/pi/Code  - remote copy of the code library (in particular, LuddyPiSlave.py and LuddyNode.py)
 /home/pi/Tools - the tandem set of tools on the PI end; copies stored on the client laptop in ~/system/pi_code

The files in this directory work in tandem with a set of files located on the PIs.

Setting up the PIs initially:

1. establish remote login capabilities using ssh between the client laptop and the PIs (hosts)

notes to be added, but look up (all run on the client):
 - ssh-keygen -t ecdsa -b 256 to generate public & private keys on the client 
 - ssh-copy-id to copy public key to the host machines (once for each PI)
 - establish the SSH agent on your machine: eval $(ssh-agent)
 - ssh-add to make it so you don't need to use your passphrase to log in using ssh: ssh-add <key_path>

2. create the directory structure above on the PIs, and while you're there
 - set the date/time: e.g., sudo date -s '2018-12-05 14:45:02'
 - change the default password if it's still 'raspberry', using passwd

3. on the client:
 - zip the pi_code directory into pi_code.zip
 - upload the pi_code.zip file: bash ~/system/tools/upload_file pi_code.zip
 - unzip (remotely): bash ~/system/tools/run_pi_cmd 'unzip -o ~/Tools/pi_code.zip -d ~/Tools'
 - upload the rc.local file to each of the PIs: bash ~/system/tools/upload_rclocal

4. to test whether everything is working:
 - bash ~/system/tools/reboot_pis

Doing that should cause all PIs to reboot and create a file called ~/Tools/initlog on each PI.  At this point initlog may have errors in it because you haven't uploaded any actual hex files for the teensys yet, but if the file doesn't get created, then something's wrong.

Copying the entire codebase to the PIs:

1. Go to github https://github.com/pbarch and the most recent project (at time of writing, https://github.com/pbarch/17540-Luddy-Hall)
2. download the zip file of the code base using the "clone or download" button on the right
3. save that zipfile in ~/system/tools on the client
4. cd ~/system/tools
5. bash do_it <zipfilename>

This will 
 - unzip the zipfile into ~/system/code
 - remotely delete any code on the PIs
 - copy the new code base into ~/Code on the PIs
 - tell the PIs to reboot

On boot-up, the PIs will
 - identify their Teensys
 - program each Teensy with the hex file (at time of writing, ~/Code/Teensy/LuddyNode.ino.hex)
 - reboot each Teensy
 - run the PI python script to communicate between the Teensys and the master (at time of writing, ~/Code/Raspberry Pi/LuddyPISlave.py)

Updating just the hex file on the Teensys (or a single Teensy)

1. cd ~/system/tools
2. bash do_hex <hexfilename> <PI ID>

This will copy the hex file into ~/Code/Teensy/LuddyNode.ino.hex on the PI, and reboot the PI which will cause it to reprogram its associated Teensys

<PI ID> is the last three digits of the PI on the 172.23.0.X network.  E.g., 101, 102, ...

If <PI ID> is not specified, it will upload to all the PIs in the network (at time of writing, that is 101, 102, 103, 104, 105, and these values are hard-coded into a number of different tools...not great, but that's what it is).
