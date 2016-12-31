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

DATA_A=0
DATA_AFSK_A=1
DATA_FSK_D=2
DATA_PSK_D=3

# -=-=-=-=-=-=-=- Defaults -=-=-=-=-=-=-=- 

$verbose=nil
$ser_dev='/dev/cu.usbserial-A105HW5O'
$ser_speed=38400

# -=-=-=-=-=-=-=- Command Line Processing -=-=-=-=-=-=-=- 

# Get the various user options.
opts=Trollop::options do
  opt :dev, "Serial device", :type => :string
  opt :speed, "Serial speed (default 38400)", :type => :string
  opt :verbose, "Verbose"
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

$kx_model=nil
$kx_atu=nil
$kx_pa=nil
$kx_filter=nil
$kx_extatu=nil
$kx_charger=nil
$kx_transverter=nil
$kx_rtcio=nil

# This class holds the data for a single memory location.
class Memory
  attr_accessor :channel, :label, :description, :vfoa, :mode, :data_mode

  def initialize(channel, label, description, vfoa, mode, data_mode)
    @channel=channel.to_i
    @label=label
    @description=description
    @vfoa=vfoa
    @mode=mode
    @data_mode=data_mode
  end

  def to_s
    "Channel: #{channel}\nVFO-A: #{vfoa}\nMode: #{mode}\nData Mode: #{data_mode}"
  end
end

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
  msg=''
  ret=tries
  success=nil
  if(not(ret))
    ret=1
  end
  $queue.synchronize do
    $rx_messages.clear()
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

# A simpler version of send_cmd() mostly used for doing a GET.
def get_cmd(command,sleep_time,timeout,tries)
  msg=''
  ret=tries
  success=nil
  if(not(ret))
    ret=1
  end
  $queue.synchronize do
    $rx_messages.clear()
  end
  while(ret>0 and (not(success)))
    ret=ret-1
    $serial_port.synchronize do
      $serialport.write(command)
    end
    now=Time.now().to_f
    while((not(success)) and Time.now().to_f-now<=timeout)
      $queue.synchronize do
        if($rx_messages.length>0)
          msg=$rx_messages.pop()
          success=true
        end
      end
      sleep(0.1)
    end
  end
  if(success)
    sleep(sleep_time)
    return(msg)
  else
    return(nil)
  end
end

# Detects the model of radio.
def detect_radio()
  ret=get_cmd('OM;',0.1,1.0,5)
  if(ret)
    if(ret.include?('A'))
      $kx_atu=true
    end
    if(ret.include?('P'))
      $kx_pa=true
    end
    if(ret.include?('F'))
      $kx_filter=true
    end
    if(ret.include?('T'))
      $kx_extatu=true
    end
    if(ret.include?('B'))
      $kx_charger=true
    end
    if(ret.include?('X'))
      $kx_transverter=true
    end
    if(ret.include?('I'))
      $kx_rtcio=true
    end
    if(ret=~/01;$/)
      $kx_model=2
    end
    if(ret=~/02;$/)
      $kx_model=3
    end
    return(true)
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

# Return the current channel.
def get_channel()
  return(get_cmd('MC;',0.1,0.5,3).gsub(/^MC/,'').gsub(/;$/,'').to_i)
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

# Return the current AGC setting.
def get_agc()
  return(get_cmd('GT;',0.1,0.5,3).gsub(/^GT/,'').gsub(/;$/,'').to_i)
end

# Set the data mode. Returns the mode.
def set_data_mode(data)
  puts "Setting Data Mode to #{data}" if $verbose
  d='DT'+(('000'+data.to_s)[-3..-1])+';'
  puts d if $verbose
  ret=send_cmd(d,'DT;',d,0.25,1.0,3)
  if(ret)
    return(ret.gsub(/^DT/,'').gsub(/;$/,'').to_i)
  else
    return(nil)
  end
end

# Return the current data mode.
def get_data_mode()
  return(get_cmd('DT;',0.1,0.5,3).gsub(/^DT/,'').gsub(/;$/,'').to_i)
end

# Set the output power. Returns the setting.
def set_power(watts)
  puts "Setting Watts to #{watts.to_i} watts" if $verbose
  w='PC'+(('000'+watts.to_i.to_s)[-3..-1])+';'
  puts w if $verbose
  ret=send_cmd(w,'PC;',w,0.25,1.0,3)
  if(ret)
    return(ret.gsub(/^PC/,'').gsub(/;$/,'').to_i)
  else
    return(nil)
  end
end

# Return the current power setting.
def get_power()
  return(get_cmd('PC;',0.1,0.5,3).gsub(/^PC/,'').gsub(/;$/,'').to_i)
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

# Return the current band.
def get_band()
  return(get_cmd('BN;',0.1,0.5,3).gsub(/^BN/,'').gsub(/;$/,'').to_i)
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

# Return the current filter bandwidth.
def get_bandwidth()
  return(get_cmd('BW;',0.1,0.5,3).gsub(/^BW/,'').gsub(/;$/,'').to_i)
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

# Return the current frequency of VFO-A.
def get_frequency()
  return(get_cmd('FA;',0.1,0.5,3).gsub(/^FA/,'').gsub(/;$/,'').to_i)
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

# Return the current mode.
def get_mode()
  return(get_cmd('MD;',0.1,0.5,3).gsub(/^MD/,'').gsub(/;$/,'').to_i)
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
  if $kx_model==2
    button_hold(14)
  elsif $kx_model==3
    button_hold(41)
  else
    return(nil)
  end
  return(true)
end

# Writes the current info to the previously selected channel (you must
# call set_channel() *PRIOR* to setting freq, mode, etc).
def write_to_channel()
  store_button()
  sleep(0.5)
  store_button()
  sleep(0.5)
end

# Hit the ATU button. Automatically fails if no ATU was previously
# detected by detect_radio().
def atu_button()
  if $kx_model==2 and ($kx_atu or $kx_extatu)
    button_tap(20)
  elsif $kx_model==3 and ($kx_atu or $kx_extatu)
    button_tap(44)
  else
    return(nil)
  end
  return(true)
end

# Display what is known about the attached radio.
def show_radio_info()
  if $kx_model==2
    puts "KX2 Detected"
  elsif $kx_model==3
    puts "KX3 Detected"
  else
    puts "Unsupported radio model."
    $all_done=true
  end
  if $kx_atu
    puts "KXAT2/KXAT3 Internal ATU Detected"
  end
  if $kx_pa
    puts "KXPA100 External PA Detected"
  end
  if $kx_filter
    puts "KXFL3 Roofing Filter Detected"
  end
  if $kx_extatu
    puts "KXAT100 External ATU Detected"
  end
  if $kx_charger
    puts "XKBC3 Charger/RTC Detected"
  end
  if $kx_transverter
    puts "KX3-2M/KX3-4M Transverter Detected"
  end
  if $kx_rtcio
    puts "KXIO2 RTC I/O Module Detected"
  end
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

detect_radio()
show_radio_info()

if (not($all_done))
  puts "Sending commands..."

#  puts "channel: #{set_channel(3)}"
#  puts "mode: #{set_mode(MODE_USB)}"
#  puts "freq: #{set_frequency(14347000)}"
#  puts "agc: #{set_agc(AGC_SLOW)}"
#  puts "bw: #{set_bandwidth(2200)}"
#  puts "write: #{write_to_channel()}"

#  #puts "band: #{set_band(BAND_80M)}"
#  puts "freq: #{set_frequency(14070000)}"
#  puts "mode: #{set_mode(MODE_USB)}"
#  puts "bw: #{set_bandwidth(3000)}"
#  puts "power: #{set_power(5)}"
#  puts "atu: #{atu_button()}"

  (0..9).each do |n|
    puts "Getting data for channel: #{set_channel(n)}"
    m=Memory.new(get_channel(),'','',get_frequency(),get_mode(),get_data_mode())
    puts m
  end
  
  # Tell the thread(s) to shut down.
  puts "Stopping thread(s)..."
  $all_done=true
end
sleep(1)

# Close the serial device.
puts "Closing serial port..."
$serialport.close()
