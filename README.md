# kx-util
A tool for manipulating the KX2 and KX3 from the command line via the serial interface.

A brief note before we start:  This code is in development. Do not expect it work well (or even necessarily work at all) until this notice goes away. You're welcome to experiment, but no results are guaranteed in any way at this point.

Elecraft offers a nice utility for managing the memories in a KX2/KX3, but it only runs on Windows. The primary goal of this project is to provide a command line tool to provide the same functionality for Linux and Mac users (though supporting libraries have been chosen that will allow this code to work on Windows, as well).

A secondary goal is to be able to manipulate other features of the radio, possible including auto-tuning based on external events (for example, automatically tuning in each new SOTA report).

At this point, this code is still very much in the "testing and exploring" phase, but is being shared for anyone who would like to follow along and/or help.  Expect regular and radical changes as different approaches are tested.

The code as it sits at the moment sets the radio to 14.347mhz, USB, slow AGC, with a 2.7khz filter, then programs this into memory 2 (note, if you don't want your memory 2 location overwritten, edit the code before you run it.)

You'll need two extra gems to run this code: trollop and rubyserial. On Linux and Mac systems, this is accomplished with the following command:

````
sudo gem install trollop rubyserial
````

There are three possible flags. --dev specifies the name of your serial device. --speed specifies the speed of the serial interface on your KX2/3. --dev defaults to '/dev/cu.usbserial-A105HW50', which is what my serial cable shows up as on my Mac. The --speed defaults to 38000. Additionally, there is a --verbose flag that spews a lot of extra information as the code runs. This is not normally used, but is useful while developing code. Once the supporting gems are installed, you can run the sample code:

````
jfrancis@hoss ~ $ ./kx-util --verbose --dev /dev/cu.usbserial-A105HW5O --speed 38400 --kx 2
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

# Available Functions

## listener()
This is not a user-called function. Rather, it's a thread that constantly runs in the background that watches for incoming serial data and makes it available to the system via a queue called $rx_messages. This queue is protected by a lock called $queue.

## send_cmd()
This is not a user-called function. It is used by the functions below to send serial commands to the radio, then attempts to validate that they were successful. It is called with a command to be run, a command to check that the first command was successful, a string to compare with the result to determine success, a time to sleep between running the command and the validation (which sometimes need to be longer than usual, for example when changing bands), a maximum amount of time to wait for a result, and a number of tries before returning failure. For commands that cannot be checked (such as button presses), nil can be passed as the second argument. This function returns the result of the result of the validation string (or true, in the case of a nil validation function) if successful, or nil if it times out or otherwise fails.

## get_cmd()
This is a simpler version of send_cmd() designed mostly for doing GET functions on the serial API. It takes the same parameters as send_cmd(), except no validating function or test value. Returns the string provided by the serial API.

## set_channel()
This function changes the radio to the specified channel (0 to 99). If the specified channel has not been configured, then it sets the channel to be written to if the store_button() function is called. Returns the new channel value.

## set_agc()
Set the AGC to the specified value. Constants have been defined for AGC_SLOW and AGC_FAST. Returns the new AGC value.

## set_band()
Set VFO-A to the specified band. Constants have been defined for BAND_160M, BAND_80M, etc. up through BAND_6M. BAND_6M does not work on the KX2, but should on the KX3. Returns the new band value. Note that this function will take a minimum of 500ms to complete.

## set_bandwidth()
Set the filter bandwidth to a value specified in Hz. Returns the new filter bandwidth in Hz.

## set_frequency()
Set VFO-A to the frequency specified in Hz. Returns the new freqency in Hz. Note that this command will take a minimum of 500ms to complete.

## set_mode()
Set VFO-A to the specified mode. Constants have been defined for MODE_LSB, MODE_USB, MODE_CW, MODE_FM, MODE_AM, MODE_DATA, MODE_CW_REV, MODE_DATA_REV. Returns the new mode.

## set_data_mode()
Sets the data mode once the mode has been set to MODE_DATA or MODE_DATA_REV. Constants have been defined for DATA_A, DATA_AFSK_A, DATA_FSK_D, and DATA_PSK_D. There is an omission in the Elecraft docs, and I've yet been unable to guess how to select between PSK31 and PSK63.

## button_tap()
Emulate a tap of the specified button (specified as a number). Returns true or nil. Note that button numbers are different on the KX2 and KX3.

## button_hold()
Emulate a hold of the specified button (specified as a number). Returns true or nil. Note that button numbers are different on the KX2 and KX3.

## store_button()
Emulate use of the STORE button.

## atu_button()
Emulate use of the ATU button.

## detect_radio()
Detects which model radio (KX2 or KX3) is attached, as well as what options are installed and configured. Sets various variables (all start with $kx_) as listed in the source.

## show_radio_info()
Shows what model radio is connected, as well as the installed and configured options.
