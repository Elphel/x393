#!/usr/bin/env python
# -*- coding: utf-8 -*-
from __future__ import print_function
from __future__ import division
# Copyright (C) 2017, Elphel.inc.
# Helper module create AHCI registers type/default data
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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
'''
Calculate ROM for half-sine 2d window for lapped transform.
Only one quadrant is stored.
created for 8x8 (16x16 overlapped) with 4:1 super resolution, so instead of :
   sin(1*pi/32), sin(3*pi/32),..., sin(15*pi/32) for each of the rows and columns
there are:   
   sin(1*pi/64), sin(2*pi/64),..., sin(32*pi/64) for each of the rows and columns
that requires 32x32x18bits ROM. no need to have sin(0*pi/64) as it is 0

     
'''

  
__author__ = "Andrey Filippov"
__copyright__ = "Copyright 2017, Elphel, Inc."
__license__ = "GPL"
__version__ = "3.0+"
__maintainer__ = "Andrey Filippov"
__email__ = "andrey@elphel.com"
__status__ = "Development"
import sys
import math
import os
import datetime
mclt_wnd_rom_path=  '../includes/mclt_wnd_sres4.vh'

def create_with_parity (init_data,   # numeric data (may be less than full array
                        num_bits,    # number of bits in item, valid:  1,2,4,8,9,16,18,32,36,64,72
                        full_bram):  # true if ramb36, false - ramb18
    d = num_bits
    num_bits8 = 1;
    while d > 1:
        d >>= 1
        num_bits8 <<= 1
    bsize = (0x4000,0x8000)[full_bram]
    bdata = [0  for i in range(bsize)]
    sb = 0
    for item in init_data:
        for bt in range (num_bits8):
            bdata[sb+bt] = (item >> bt) & 1;
        sb += num_bits8
    data = []
    for i in range (len(bdata)//256):
        d = 0;
        for b in range(255, -1,-1):
            d = (d<<1) +  bdata[256*i+b]
        data.append(d)
    data_p = []
    num_bits_p = num_bits8 >> 3
    sb = 0
    print ("num_bits=",num_bits)
    print ("num_bits8=",num_bits8)
    print ("num_bits_p=",num_bits_p)
    if num_bits_p:    
        pbsize = bsize >> 3    
        pbdata = [0  for i in range(pbsize)]
        for item in init_data:
            for bt in range (num_bits_p):
                pbdata[sb+bt] = (item >> (bt+num_bits8)) & 1;
            sb += num_bits_p
        for i in range (len(pbdata)//256):
            d = 0;
            for b in range(255, -1,-1):
                d = (d<<1) +  pbdata[256*i+b]
            data_p.append(d)
    return {'data':data,'data_p':data_p}


def print_params(data,
                 out_file_name,
                 comment=""): # text to add to the file header
    with open(out_file_name,"w") as out_file:
        print ("// Created with "+sys.argv[0], file=out_file)
        if comment:
            print (comment, file=out_file)
        for i, v in enumerate(data['data']):
            if v:
                print (", .INIT_%02X (256'h%064X)"%(i,v), file=out_file)
    #    if (include_parity):
        for i, v in enumerate(data['data_p']):
            if v:
                print (", .INITP_%02X (256'h%064X)"%(i,v), file=out_file)
                        
def create_wnd_2d (N=32, bits=18): # N=32, bits=18, all data is positive
    rom = []
    sin = []
    for i in range(N):
        sin.append(math.sin(math.pi*(i+1)/(2*N)))
    for i in range(N):
        for j in range(N):
            rom.append(int(round(sin[i] * sin[j] * ((1 << bits) - 1)))) # loosing 1 count
    return rom                        
                        
print_params(
    create_with_parity(create_wnd_2d (N=32, bits=18), 18, False),
    os.path.abspath(os.path.join(os.path.dirname(__file__), mclt_wnd_rom_path)),
    "// MCLT 16x16  window with 4:1 super resolution data")
print ("MCLT 16x16  window with 4:1 super resolution data is written to %s"%(os.path.abspath(os.path.join(os.path.dirname(__file__), mclt_wnd_rom_path))))
                 
