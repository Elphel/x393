#!/usr/bin/env python
# -*- coding: utf-8 -*-
from __future__ import print_function
from __future__ import division
# Copyright (C) 2017, Elphel.inc.
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
 Signed subpixel shifts in the range [-0.5,0.5) are converted to sign and [0,0.5] and both limits are fit to the same slot as
 the shift -0.5 :  cos((i+0.5)/16*pi), -sin((i+0.5)/16*pi) for i=0..7 is symmetrical around the center (odd for sine, even - cosine)
 ROM input MSB - 0- cos, 1 - sin,  3 LSB s - index (0..7). Signs for cos and sin are passed to DSPs
 shift               i    sin  ROM[9]     ROM A[8:3]   ROM A[2:0]   sign cos   sign sin
 1000000 (-0.5)     nnn    0     1         0           ~nnn          0         1
                    nnn    1     1         0            nnn          0         1

 1xxxxxx (<0)       nnn    s     s   -xxxxxx            nnn          0         1

 0000000 (==0)      nnn    0     0          0             0          0         0
                    nnn    1     0          0             1          0         0

 0xxxxxx (>0)       nnn    s     s    xxxxxx            nnn          0         0
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
mclt_wnd_rom_path=  '../includes/mclt_rotator_rom.vh'

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
#        print(item)
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


def create_rotator(addr=10): # n - DCT and window size
    rom = []
    maxv=(1 << 17) - 1
    sin_a = 1 << (addr-1) # 512
    shft_offs = 3
    for _ in range(1 << addr):
        rom.append(0)
    for shft in range(1 <<(addr-4)):
        ashift = 1.0 * shft/(1 <<(addr-3))
        if shft == 0:
            ashift = 0.5
        for i in range(8):
            a = (i+0.5) * math.pi * ashift / 8
            rom[ i + (shft << shft_offs) + sin_a] = int(round(maxv*math.sin(a)))
            if shft > 0:
                rom[ i + (shft << shft_offs) + 0 * sin_a] = int(round(maxv*math.cos(a)))
            elif i == 0:
                rom[ i + (shft << shft_offs) + 0 * sin_a] = maxv
            elif i == 1:
                rom[ i + (shft << shft_offs) + 0 * sin_a] = 0 # not needed, just for clarity
    return rom

'''
Calculate ROM for MCLT fold indices:
A0..A1 - variant, folding to the same 8x8 sample
A2..A4 - sample column in folded 8x8 tile
A5..A7 - sample row in folded 8x8 tile
D0..D4 - pixel column in 16x16 tile
D5..D7 - pixel row in 16x16 tile
D8 -  negate for mode 0 (CC)
D9 -  negate for mode 1 (SC)
D10 - negate for mode 2 (CS)      
D11 - negate for mode 3 (SS)
'''
                        
print_params(
    create_with_parity(create_rotator (), 18, False),
    os.path.abspath(os.path.join(os.path.dirname(__file__), mclt_wnd_rom_path)),
    "// MCLT rotator cos/sin values")
print ("MCLT rotator cos/sin data is written to %s"%(os.path.abspath(os.path.join(os.path.dirname(__file__), mclt_wnd_rom_path))))
                 
