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

path="/www/pages/img.jpeg"
PORT=8888
try:
    qs=urlparse.parse_qs(os.environ['QUERY_STRING'])
except:
    print("failed  in os.environ['QUERY_STRING']")
    qs={}


acquisition_parameters={
        "file_path":    "img.jpeg",
        "channel":      "0",
        "cmode":        "0",
        "bayer":        "None",
        "y_quality":    "None",
        "c_quality":    "None",
        "portrait":     "None",
        "gamma":        "None",
        "black":        "None",
        "colorsat_blue":"None",
        "colorsat_red": "None",
        "server_root":  "/www/pages/",
        "verbose":      "0"}
for k in qs:
    if k == "cmode":
        if qs[k][0].upper() == "JP4":
            acquisition_parameters[k] = "5"
        else:
            acquisition_parameters[k] = "0"
    else:
        acquisition_parameters[k] = qs[k][0]
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

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.connect(('localhost', PORT))
sock.send(cmd_str)
reply = sock.recv(16384)  # limit reply to 16K
sock.close()

if (acquisition_parameters["cmode"] =="5"):
    path = path.replace("jpeg","jp4")

timestamp =str(time.time()).replace(".","_") # later use image timestamp
print("Content-Type: image/jpeg")
print("Content-Disposition: inline; filename=\"elphelimg_%s.jpeg\""%(timestamp))
print("Content-Length: %d\n"%(os.path.getsize(path))) # extra \n
with open(path, "r") as f:
    shutil.copyfileobj(f, sys.stdout)

