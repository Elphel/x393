#!/usr/bin/python
from __future__ import division
from __future__ import print_function
'''
# Copyright (C) 2015, Elphel.inc.
#   
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http:#www.gnu.org/licenses/>.

@author:     Andrey Filippov
@copyright:  2015 Elphel, Inc.
@license:    GPLv3.0+
@contact:    andrey@elphel.coml
@deffield    updated: Updated
'''
__author__ = "Andrey Filippov"
__copyright__ = "Copyright 2015, Elphel, Inc."
__license__ = "GPL"
__version__ = "3.0+"
__maintainer__ = "Andrey Filippov"
__email__ = "andrey@elphel.com"
__status__ = "Development"

import os
import urlparse
import time
import socket
import shutil
import sys
import subprocess

path="/tmp/img.jpeg"
PORT=8888
def communicate(port,snd_str):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect(('localhost', port))
    sock.send(snd_str)
    reply = sock.recv(16384)  # limit reply to 16K
    sock.close()
    return reply
try:
    qs=urlparse.parse_qs(os.environ['QUERY_STRING'])
except:
    print("failed  in os.environ['QUERY_STRING']")
    qs={}


acquisition_parameters={
        "file_path":    "img.jpeg",
        "channel":      "0",
        "cmode":        "0",
        "bayer":        None,
        "y_quality":    None,
        "c_quality":    None,
        "portrait":     None,
        "gamma":        None,
        "black":        None,
        "colorsat_blue":None,
        "colorsat_red": None,
        "server_root":  "/tmp/",
        "gain_r":       None,
        "gain_gr":      None,
        "gain_gb":      None,
        "gain_b":       None,
        "expos":        None,
        "flip_x":       None,
        "flip_y":       None,
        "verbose":      "0"}
for k in qs:
    if k == "cmode":
        if qs[k][0].upper() == "JP4":
            acquisition_parameters[k] = "5"
        else:
            acquisition_parameters[k] = "0"
    else:
        acquisition_parameters[k] = qs[k][0]
#correct bayer (if specified) for flips
if ((not acquisition_parameters["bayer"] is None) and
    ((not acquisition_parameters["flip_x"] is None) or
     (not acquisition_parameters["flip_y"] is None))):
    ibayer= int (acquisition_parameters["bayer"])
    if acquisition_parameters["flip_x"]:
        if int (acquisition_parameters["flip_x"]):
            ibayer ^= 1
    if int (acquisition_parameters["flip_y"]):
        ibayer ^= 2
    acquisition_parameters["bayer"] = str(ibayer)    
        
#restart compressor
communicate(PORT, "compressor_control all 1 None None None None None")
        
cmd_str = "jpeg_acquire_write %s %s %s %s %s %s %s %s %s %s %s %s %s"%(
           str(acquisition_parameters["file_path"]),
           str(acquisition_parameters["channel"]),
           str(acquisition_parameters["cmode"]),
           str(acquisition_parameters["bayer"]),
           str(acquisition_parameters["y_quality"]),
           str(acquisition_parameters["c_quality"]),
           str(acquisition_parameters["portrait"]),
           str(acquisition_parameters["gamma"]),
           str(acquisition_parameters["black"]),
           str(acquisition_parameters["colorsat_blue"]),
           str(acquisition_parameters["colorsat_red"]),
           str(acquisition_parameters["server_root"]),
           str(acquisition_parameters["verbose"]))
gains_exp_changed = False
geometry_changed = False
#change gains/exposure if needed
if ((not acquisition_parameters["gain_r"]  is None) or 
    (not acquisition_parameters["gain_gr"] is None) or
    (not acquisition_parameters["gain_gb"] is None) or
    (not acquisition_parameters["gain_b"]  is None) or
    (not acquisition_parameters["expos"]   is None)):
    gains_exp_changed = True
    gstr = "set_sensor_gains_exposure %s %s %s %s %s %s %s"%(
            str(acquisition_parameters["channel"]),
            str(acquisition_parameters["gain_r"]),
            str(acquisition_parameters["gain_gr"]),
            str(acquisition_parameters["gain_gb"]),
            str(acquisition_parameters["gain_b"]),
            str(acquisition_parameters["expos"]),
            str(acquisition_parameters["verbose"]))
    communicate(PORT, gstr)

#change flips if needed
if ((not acquisition_parameters["flip_x"]  is None) or 
    (not acquisition_parameters["flip_yr"] is None)):
    geometry_changed = True
    fstr = "set_sensor_flipXY %s %s %s %s"%(
            str(acquisition_parameters["channel"]),
            str(acquisition_parameters["flip_x"]),
            str(acquisition_parameters["flip_y"]),
            str(acquisition_parameters["verbose"]))
    communicate(PORT, fstr)
#How many bad/non modified frames are to be skipped (just a guess)    
skip_frames = 0
if geometry_changed:
    skip_frames = 2
elif gains_exp_changed:
    skip_frames = 1
if (str(acquisition_parameters["channel"])[0].upper() == 'A'):
    channel_mask = 0x0f
else:
    channel_mask = 1 << int(acquisition_parameters["channel"])
skip_str= "skip_frame %d"%(channel_mask)    
for i in range(skip_frames):
    communicate(PORT, skip_str)
# Now - get that image                      

reply = communicate(PORT,cmd_str)
if (acquisition_parameters["cmode"] =="5"):
    path = path.replace("jpeg","jp4")

circbufcmd = "echo \"3 "+str(acquisition_parameters["y_quality"])+"\" > /dev/circbuf0"
subprocess.check_output(circbufcmd,stderr=subprocess.STDOUT,shell=True)

communicate(PORT, "compressor_control all 0 None None None None None")
communicate(PORT, "compressor_control all 3 None None None None None")

timestamp =str(time.time()).replace(".","_") # later use image timestamp
print("Content-Type: image/jpeg")
print("Content-Disposition: inline; filename=\"elphelimg_%s.jpeg\""%(timestamp))
print("Content-Length: %d\n"%(os.path.getsize(path))) # extra \n
with open(path, "r") as f:
    shutil.copyfileobj(f, sys.stdout)

