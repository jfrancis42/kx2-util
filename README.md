# kx2-util
A tool for manipulating the KX2 (and potentially KX3) from the command line via the serial interface.

A brief note before we start:  This code is in development. Do not expect it work well (or even necessarily work at all) until this notice goes away. You're welcome to experiment, but no results are guaranteed in any way at this point.

Elecraft offers a nice utility for managing the memories in a KX2/KX3, but it only runs on Windows. The primary goal of this project is to provide a command line tool to provide the same functionality for Linux and Mac users (though supporting libraries have been chosen that will allow this code to work on Windows, as well).

A secondary goal is to be able to manipulate other features of the radio, possible including auto-tuning based on external events (for example, automatically tuning in each new SOTA report).

At this point, this code is still very much in the "testing and exploring" phase, but is being shared for anyone who would like to follow along and/or help.  Expect regular and radical changes as different approaches are tested.

The code as it sits at the moment sets the radio to 14.347mhz, USB, with a 2.7khz filter, then programs this into memory 2 (note, if you don't want your memory 2 location overwritten, edit the code before you run it.)

You'll need two extra gems to run this code: trollop and rubyserial. On Linux and Mac systems, this is accomplished with the following command:

````
sudo gem install trollop rubyserial
````

There are two flags required. --dev specifies the name of your serial device. --speed specifies the speed of the serial interface on your KX2/3. --dev defaults to '/dev/cu.usbserial-A105HW50', which is what my serial cable shows up as on my Mac. The --speed defaults to 38000. Additionally, there is a --verbose flag that spews a lot of extra information as the code runs. This is not normally used, but is useful while developing code. Once the supporting gems are installed, you can run the sample code:

````
jfrancis@hoss ~ $ ./kx2-util --verbose --dev /dev/cu.usbserial-A105HW5O --speed 38400
Opening serial port...
listener() thread starting.
Sending commands...
Setting channel to 3
MC003;
Adding to queue: MC003;
channel: 3
Setting mode to 2
MD2;
Adding to queue: MD2;
mode: 2
Setting frequency to 14277000
FA00014277000;
Adding to queue: FA00014277000;
freq: 14277000
Setting filter bandwidth to 1800
BW0180;
Adding to queue: BW0180;
bw: 180
Holding button 14
SWH14;
store: true
Holding button 14
SWH14;
store: true
Stopping thread(s)...
listener() thread exiting.
Closing serial port...
jfrancis@hoss ~ $
````

Additional rapid development is expected, and contributions are welcome.

Note that I don't own (or have easy access to) a KX3, so while I'm doing everything I can to make sure the code is portable to both devices, there's no guarantee unless somebody else with a KX3 wants to do some testing. In theory, this might even work with a K2/K3, but again, somebody will have to test it.
