#!/usr/bin/env ruby

# KX2 Utility
# 
# Copyright 2016, by Jeff Francis, N0GQ
# 
# This program is free for any/all use (including re-using the code or
# concepts in your own code), provided attribution is given.
#
# This code will eventually allow for various manipulations of the
# KX2, including backing up and restoring memory channels. While no
# effort is being made to exclude other Elecraft models (like the
# KX3), I don't have one to test with, so your mileage may vary.

# -=-=-=-=-=-=-=- Required Libraries -=-=-=-=-=-=-=- 

require 'trollop'
require 'rubyserial'
require 'thread'
require 'time'

# -=-=-=-=-=-=-=- Constants -=-=-=-=-=-=-=-

MODE_LSB=1
MODE_USB=2
MODE_CW=3
MODE_FM=4
MODE_AM=5
MODE_DATA=6
MODE_CW_REV=7
MODE_DATA_REV=8

BAND_160M=0
BAND_80M=1
BAND_60M=2
BAND_40M=3
BAND_30M=4
BAND_20M=5
BAND_17M=6
BAND_15M=7
BAND_12M=8
BAND_10M=9
BAND_6M=10

AGC_FAST=2
AGC_SLOW=4

# -=-=-=-=-=-=-=- Defaults -=-=-=-=-=-=-=- 

$verbose=nil
$ser_dev='/dev/cu.usbserial-A105HW5O'
$ser_speed=38400
$kx=0

# -=-=-=-=-=-=-=- Command Line Processing -=-=-=-=-=-=-=- 

# Get the various user options.
opts=Trollop::options do
  opt :kx, "Specify your radio. 2 for KX2 and 3 for KX3", :type => :string
  opt :dev, "Serial device", :type => :string
  opt :speed, "Serial speed (default 38400)", :type => :string
  opt :verbose, "Verbose"
end

# Check whether this is a KX2 or KX3 (it matters for certain
# functions).
if opts[:kx_given]
  $kx=opts[:kx].to_i
else
  puts "--kx is mandatory"
  exit
end

# If the user wants verbosity, give it to them.
if opts[:verbose_given]
  $verbose=true
end

# The user needs to specify a serial port dev (unless they're using
# the default).
if opts[:dev_given]
  $ser_dev=opts[:dev]
end

# Serial speed defaults to 38400, but can be changed.
if opts[:speed_given]
  $ser_speed=opts[:speed].to_i
end

# -=-=-=-=-=-=-=- Vars and Structures -=-=-=-=-=-=-=- 

$all_done=nil
$serial_port=Mutex.new()
$queue=Mutex.new()
$rx_messages=Queue.new()

# -=-=-=-=-=-=-=- Functions -=-=-=-=-=-=-=- 

# Listener thread.
def listener()
  puts "listener() thread starting."
  stuff=''
  while(not($all_done))
    $serial_port.synchronize do
      stuff=stuff+$serialport.read(999)
    end
    (thing,stuff)=stuff.split(';',2)
    if(not(stuff))
      stuff=''
    end
    if(thing) 
      $queue.synchronize do
        thing=thing+';'
        puts "Adding to queue: #{thing}" if $verbose
        $rx_messages.push(thing)
      end
    end
    sleep(0.1)
  end
  puts "listener() thread exiting."
end

# Send a command. 'command' is the command you want
# executed. 'check_command' is the command to execute to ensure that
# the previous command worked (or nil if there's no
# check). check_value is the value that should be matched by the
# check_command (ignored if check_command is nil). 'sleep_time' is the
# amount of seconds to sleep between command and check_command (or the
# amount of time to sleep before returning if check_command is
# nil). 'timeout' is the number of seconds to wait for a valid result
# before failing.
def send_cmd(command,check_command,check_value,sleep_time,timeout,tries)
  ret=tries
  success=nil
  if(not(ret))
    ret=1
  end
  while(ret>0 and (not(success)))
    ret=ret-1
    $serial_port.synchronize do
      $serialport.write(command)
    end
    sleep(sleep_time)
    if(check_command)
      $serial_port.synchronize do
        $serialport.write(check_command)
      end
      msg=''
      now=Time.now().to_f
      while((not(success)) and Time.now().to_f-now<=timeout)
        $queue.synchronize do
          if($rx_messages.length>0)
            msg=$rx_messages.pop()
            if(msg==check_value)
              success=true
            end
          end
        end
        sleep(0.1)
      end
    else
      return(true)
    end
  end
  if(success)
    return(msg)
  else
    return(nil)
  end
end

# Change to a specified integer channel (0-99 for the KX2, but not
# checked). Returns the channel.
def set_channel(channel)
  puts "Setting channel to #{channel}" if $verbose
  c='MC'+(('000'+channel.to_s)[-3..-1])+';'
  puts c if $verbose
  ret=send_cmd(c,'MC;',c,0.5,1.5,3)
  if(ret)
    return(ret.gsub(/^MC/,'').gsub(/;$/,'').to_i)
  else
    return(nil)
  end
end

# Set the AGC speed. Returns the speed.
def set_agc(agc)
  puts "Setting AGC to #{agc}" if $verbose
  a='GT'+(('000'+agc.to_s)[-3..-1])+';'
  puts a if $verbose
  ret=send_cmd(a,'GT;',a,0.5,1.5,3)
  if(ret)
    return(ret.gsub(/^GT/,'').gsub(/;$/,'').to_i)
  else
    return(nil)
  end
end

# Change VFO-A to the specified band. Returns the band number.
def set_band(band)
  puts "Setting band to #{band}" if $verbose
  b='BN'+(('00'+band.to_s)[-2..-1])+';'
  puts b if $verbose
  ret=send_cmd(b,'BN;',b,0.5,1.5,3)
  if(ret)
    return(ret.gsub(/^BN/,'').gsub(/;$/,'').to_i)
  else
    return(nil)
  end
end

# Set the filter bandwidth to a specified number of hertz (note, not
# tens of hertz like the raw API).
def set_bandwidth(hertz)
  puts "Setting filter bandwidth to #{hertz}" if $verbose
  b='BW'+(('0000'+(hertz/10).to_i.to_s)[-4..-1])+';'
  puts b if $verbose
  ret=send_cmd(b,'BW;',b,0.25,0.75,3)
  if(ret)
    return(ret.gsub(/^BW/,'').gsub(/;$/,'').to_i)
  else
    return(nil)
  end
end

# Set VFO-A to the specified integer frequency in hz (input not
# checked).
def set_frequency(hertz)
  puts "Setting frequency to #{hertz}" if $verbose
  f='FA'+(('00000000000'+hertz.to_s)[-11..-1])+';'
  puts f if $verbose
  ret=send_cmd(f,'FA;',f,0.5,1.5,3)
  if(ret)
    return(ret.gsub(/^FA/,'').gsub(/;$/,'').to_i)
  else
    return(nil)
  end
end

# Set the mode for VFO-A.
def set_mode(mode)
  puts "Setting mode to #{mode}" if $verbose
  m='MD'+mode.to_s+';'
  puts m if $verbose
  ret=send_cmd(m,'MD;',m,0.1,0.5,3)
  if(ret)
    return(ret.gsub(/^MD/,'').gsub(/;$/,'').to_i)
  else
    return(nil)
  end
end

# Tap a button.
def button_tap(button)
  puts "Pressing button #{button}" if $verbose
  b='SWT'+button.to_s+';'
  puts b if $verbose
  return(send_cmd(b,nil,nil,0.25,0.5,1))
end

# Hold a button.
def button_hold(button)
  puts "Holding button #{button}" if $verbose
  b='SWH'+button.to_s+';'
  puts b if $verbose
  return(send_cmd(b,nil,nil,0.25,0.5,1))
end

# Hit the STORE button.
def store_button()
  if $kx==2
    button_hold(14)
  elsif $kx==3
    button_hold(41)
  else
    return(nil)
  end
  return(true)
end

# Hit the ATU button.
def atu_button()
  if $kx==2
    button_tap(20)
  elsif $kx==3
    button_tap(44)
  else
    return(nil)
  end
  return(true)
end

# -=-=-=-=-=-=-=- Main Program -=-=-=-=-=-=-=- 

# Open the serial device.
puts "Opening serial port..."
$serialport=Serial.new($ser_dev,$ser_speed)
sleep(1)

# Start the listener thread.
listen=Thread.new { listener() }
listen.abort_on_exception=true
sleep(1)

puts "Sending commands..."
puts "channel: #{set_channel(3)}"
puts "mode: #{set_mode(MODE_USB)}"
puts "freq: #{set_frequency(14347000)}"
puts "agc: #{set_agc(AGC_SLOW)}"
puts "bw: #{set_bandwidth(2200)}"
puts "store: #{store_button()}"
puts "store: #{store_button()}"
#puts "band: #{set_band(BAND_80M)}"

# Tell the thread(s) to shut down.
puts "Stopping thread(s)..."
$all_done=true
sleep(1)

# Close the serial device.
puts "Closing serial port..."
$serialport.close()
