#!/usr/bin/env python

'''
  Generates window settings for driverless mode

  For:
      * mt9f002
      * disabled sensor driver
      * vact_delay=2, compressor_margin=0

  Instructions:
  * disable sensor driver (to enable back, remove 'disable_driver' file):
    root@elphel393~# touch /etc/elphel393/disable_driver
    reboot
  * run python
    root@elphel393~# cd /usr/local/verilog/; test_mcntrl.py @hargs-after
  * from test_mcntrl.py session run
  ** enable sensor, remove reset, adjust cable phases

    setup_all_sensors True None 0x1 False 4384 3280

    write_sensor_i2c 0 1 0 0x31c08000 # hispi timing
    write_sensor_i2c 0 1 0 0x030600b4 # pll multiplier
    write_sensor_i2c 0 1 0 0x31c68400 # hispi control status
    write_sensor_i2c 0 1 0 0x306e9280 # datapath select
    write_sensor_i2c 0 1 0 0x301a001c # reset and start streaming

    hispi_phases_adjust 0

    write_sensor_i2c 0 1 0 0x301a001c # reset and start streaming

    setup_all_sensors True None 0x1 False 4384 3280
    compressor_control all None None None None None 2
    program_gamma all 0 0.57 0.04

    write_sensor_i2c 0 1 0 0x3028000a # global gain
    write_sensor_i2c 0 1 0 0x302c000d # some gain
    write_sensor_i2c 0 1 0 0x302e0010 # some gain
    write_sensor_i2c 0 1 0 0x30120080 # coarse exposure

    jpeg_acquire_write

    #write_sensor_i2c 0 1 0 0x301a0018 # put to standby

  ** run this script and copy paste its output

'''

__copyright__ = "Copyright 2018, Elphel, Inc."
__license__ = "GPL-3.0+"
__maintainer__ = "Oleg Dzhimiev"
__email__ = "oleg@elphel.com"

import sys

try:
  w = int(sys.argv[1])
except IndexError:
  w = 4384

try:
  h = int(sys.argv[2])
except IndexError:
  h = 3280

# 16x
w = (w>>4)*16
h = (h>>4)*16

# Some regs
P_REG_MT9F002_X_ADDR_START       = 0x3004
P_REG_MT9F002_X_ADDR_END         = 0x3008
P_REG_MT9F002_SMIA_X_OUTPUT_SIZE = 0x034c
P_REG_MT9F002_LINE_LENGTH_PCK    = 0x300c

P_REG_MT9F002_Y_ADDR_START       = 0x3002
P_REG_MT9F002_Y_ADDR_END         = 0x3006
P_REG_MT9F002_SMIA_Y_OUTPUT_SIZE = 0x034e
P_REG_MT9F002_FRAME_LENGTH_LINES = 0x300a

# Some constants
compressor_margin = 0
vact_delay = 2
extra_height = 40

x_start = 144
y_start = 32 - vact_delay

min_frame_blanking_lines = 0x092
min_line_blanking_pck = 0x138
min_line_length_pck = 0x4c8
#min_line_length_pck = 0x930

# Calculations
x_output_size = w
y_output_size = h + extra_height

x_start = x_start - compressor_margin
x_end  =  x_start + x_output_size - 1 + compressor_margin

y_start = y_start - compressor_margin
y_end   = y_start + y_output_size - 1 + compressor_margin

frame_length_lines = y_output_size + min_frame_blanking_lines

llp0 = min_line_length_pck
llp1 = x_output_size/2+min_line_blanking_pck/2
llp2 = x_output_size/2+0x5e

line_length_pck = max(llp0,llp1,llp2)

def printline(reg,val,comment=""):
  print("write_sensor_i2c 0 1 0 0x"+"{:04x}".format(reg)+"{:04x}".format(val)+" # "+comment)

printline(P_REG_MT9F002_Y_ADDR_START      ,y_start,"y_addr_start")
printline(P_REG_MT9F002_Y_ADDR_END        ,y_end,  "y_addr_end")
printline(P_REG_MT9F002_SMIA_Y_OUTPUT_SIZE,y_output_size,"y_output_size")
printline(P_REG_MT9F002_FRAME_LENGTH_LINES,frame_length_lines,"frame_length_lines")

printline(P_REG_MT9F002_X_ADDR_START      ,x_start,"x_addr_start")
printline(P_REG_MT9F002_X_ADDR_END        ,x_end,  "x_addr_end")
printline(P_REG_MT9F002_SMIA_X_OUTPUT_SIZE,x_output_size,"x_output_size")
printline(P_REG_MT9F002_LINE_LENGTH_PCK   ,line_length_pck,"line_length_pck")

print("write_sensor_i2c 0 1 0 0x301a001c # reset and start streaming")
print("# wait")
print("write_sensor_i2c 0 1 0 0x301a0018 # standby")

print("setup_all_sensors True None 0x1 False "+str(w)+" "+str(h))
print("compressor_control all None None None None None 2")
print("jpeg_acquire_write")