#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Copyright (C) 2023, Elphel.inc.
# Helper module to generate IMX5 DID_INS_1
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
__author__ = "Andrey Filippov"
__copyright__ = "Copyright 2023, Elphel, Inc."
__license__ = "GPL"
__version__ = "3.0+"
__maintainer__ = "Andrey Filippov"
__email__ = "andrey@elphel.com"
__status__ = "Development"
'''
Created on February 8, 2023
@author: Andrey Filippov
'''
import os
import sys
import struct
import datetime
import random
import math
import sys
try:
    outname = sys.argv[1]
except IndexError:
    outname = "../input_data/imx5_did_ins_1.dat"

abs_script = os.path.abspath(__file__)
SAMPLE_STEP = datetime.timedelta(microseconds = 16000)
NUM_STEPS = 10
DATETIME0 = datetime.datetime(1980, 1, 6,tzinfo=datetime.timezone.utc)
#page 89
#40.77730906709462, -111.9328777496785
#1288 m
VELOCITY = [20.0, 15.0, 1.0] #U,V,W  m/s
#Bytes 0x0A , 0x24 , 0xB5 , 0xD3 , 0xFD , 0xFE and 0xFF are reserved bytes, with 0xFD being a reserved byte prefix.
INS_STAT = 0x12345678 # add escaped here
HDW_STAT = 0x0a2400fd # 0x0a, 0x24, 0xfd
LLA = [40.77730906709462, -111.9328777496785, 1288]
LLA_VAR = [0.1, 0.1, 20.0] # random LLA defiations
ENDIAN = "<" # "I" - unsigned int (4), "d" - double (8), "f" - float (4) 
now = datetime.datetime.now(datetime.timezone.utc)
now_date = now.date()
now_time = now.time();
#b = a + datetime.timedelta(0,3) # days, seconds, then other fields.
#timedelta(days=0, seconds=0, microseconds=0, milliseconds=0, minutes=0, hours=0, weeks=0)
dt = now
ned = 3 * [0]
bin = []
for ns in range(NUM_STEPS):
    rec = b''
    theta = [math.pi * (2*random.random()-1),math.pi * (2*random.random()-1), math.pi * (2*random.random()-1)]
    uvw = list(VELOCITY)
    lla = list(LLA)
    uvw = list(VELOCITY)
    for i in range(len(LLA)):
        lla[i] += LLA_VAR[i] * (2 *random.random() - 1)
        ned[i] += SAMPLE_STEP.total_seconds() * VELOCITY[i]
    dt += SAMPLE_STEP
    #print(dt)
    week = (dt-DATETIME0).days//7
    #print (week)
    diff = dt - (DATETIME0 + datetime.timedelta(days=7*week))
    rec += struct.pack(ENDIAN+"I",week)
    rec += struct.pack(ENDIAN+"d",diff.total_seconds())
    rec += struct.pack(ENDIAN+"I",INS_STAT)
    rec += struct.pack(ENDIAN+"I",HDW_STAT)
    rec += struct.pack(ENDIAN+"fff",theta[0],theta[1],theta[2])
    rec += struct.pack(ENDIAN+"fff",uvw[0],uvw[1],uvw[2])
    rec += struct.pack(ENDIAN+"ddd",lla[0],lla[1],lla[2])
    rec += struct.pack(ENDIAN+"fff",ned[0],ned[1],ned[2])
    bin.append(rec)
'''
with open("../input_data/imx5_did_ins_1.bin", "wb") as f:
    for rec in bin:
        f.write(rec)
'''
with open(outname,"w") as outfile:
    print("//",file=outfile)
    print("// Simulated data for IMX5 INS DID_INS_1, %d (0x%x) bytes per record"%(len(bin[0]),len(bin[0])), file=outfile)
    print("// GENERATOR = %s"%(abs_script),file=outfile)
    print("//",file=outfile)
    for rec in bin:
        for b in rec:
            print("%02x"%(b), file=outfile, end = " ")
        print(file=outfile)

        
'''
0000000 08c8 0000 3461 ab2b f511 4113 5678 1234
0000010 5555 aaaa 1e32 3f8f d81f 4002 799f c000
0000020 0000 41a0 0000 4170 0000 3f80 ee61 dffa
0000030 5a87 4044 1d43 f155 f644 c05b a8d4 7b1e
0000040 1d5f 4094 d70a 3ea3 c28f 3e75 126f 3c83

0000050 08c8 0000 8234 bb8d f511 4113 5678 1234
0000060 5555 aaaa 19bd 3ddd f6de bedd 0151 c041
0000070 0000 41a0 0000 4170 0000 3f80 baf1 2fbd
0000080 6030 4044 fc7d 5253 fc0a c05b f24d 8001
0000090 28c0 4094 d70a 3f23 c28f 3ef5 126f 3d03

00000a0 08c8 0000 d007 cbef f511 4113 5678 1234
00000b0 5555 aaaa 4385 3f28 a5b0 3fb8 33dd bf9e
00000c0 0000 41a0 0000 4170 0000 3f80 c41b 1591
00000d0 5e90 4044 320b 9e4c fc86 c05b 3018 388b
00000e0 5d17 4094 c28f 3f75 51ec 3f38 9ba6 3d44

00000f0 08c8 0000 1dda dc52 f511 4113 5678 1234
0000100 5555 aaaa 0616 4012 7d64 bfa4 5448 be02
0000110 0000 41a0 0000 4170 0000 3f80 b248 319f
0000120 5bd9 4044 ce50 bfef fac4 c05b cc70 29cc
0000130 5d90 4094 d70a 3fa3 c28f 3f75 126f 3d83

0000140 08c8 0000 6bad ecb4 f511 4113 5678 1234
0000150 5555 aaaa 717a 3e02 265a c045 90a4 be60
0000160 0000 41a0 0000 4170 0000 3f80 4831 f678
0000170 6e35 4044 30f3 2825 f8bc c05b f395 33ac
0000180 2e15 4094 cccd 3fcc 999a 3f99 d70a 3da3
0000190 08c8 0000 b980 fd16 f511 4113 5678 1234
00001a0 5555 aaaa d917 3df5 f943 3f0f f515 bff0
00001b0 0000 41a0 0000 4170 0000 3f80 1a95 86b9
00001c0 5ccf 4044 4ce6 d0c7 ffa7 c05b ea59 6c85
00001d0 f49f 4093 c28f 3ff5 51ec 3fb8 9ba6 3dc4
00001e0 08c8 0000 0753 0d79 f512 4113 5678 1234
00001f0 5555 aaaa b958 bfcc 690e c02b 78f9 bed3
0000200 0000 41a0 0000 4170 0000 3f80 9d6c 2c01
0000210 5c47 4044 e8fc 2bcb fd18 c05b 03fa 1b29
0000220 5168 4094 5c29 400f 0a3d 3fd7 6042 3de5
0000230 08c8 0000 5526 1ddb f512 4113 5678 1234
0000240 5555 aaaa 05a9 bfa0 545f beb7 c5bb bf31
0000250 0000 41a0 0000 4170 0000 3f80 f31a ba91
0000260 5a25 4044 6bf5 6d82 fe15 c05b 0494 6c99
0000270 178a 4094 d70a 4023 c28f 3ff5 126f 3e03
0000280 08c8 0000 a2f9 2e3d f512 4113 5678 1234
0000290 5555 aaaa a667 3f57 4517 4002 8c73 3fc6
00002a0 0000 41a0 0000 4170 0000 3f80 46a2 2884
00002b0 6938 4044 cc2b 0350 00eb c05c 6be2 44c7
00002c0 08b1 4094 51ec 4038 3d71 400a 74bc 3e13
00002d0 08c8 0000 f0cc 3e9f f512 4113 5678 1234
00002e0 5555 aaaa f700 bec3 2170 403a a8ea c004
00002f0 0000 41a0 0000 4170 0000 3f80 4a33 cb7b
0000300 5e8d 4044 9060 1a1a 0213 c05c 54ac c45e
0000310 2191 4094 cccd 404c 999a 4019 d70a 3e23
0000320

'''
#    print (week, diff.total_seconds())
#     len(struct.pack("<d",1.0)) 8
