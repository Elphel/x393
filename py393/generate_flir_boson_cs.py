#!/usr/bin/env python3
# encoding: utf-8
'''
# Copyright (C) 2020, Elphel.inc.
# test for import_verilog_parameters.py
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

@author:     Andrey Filippov
@copyright:  2020 Elphel, Inc.
@license:    GPLv3.0+
@contact:    andrey@elphel.coml
@deffield    updated: Updated
'''
CRC16_XMODEM_TABLE =[
    0x0000, 0x1021, 0x2042, 0x3063, 0x4084, 0x50a5, 0x60c6, 0x70e7,
    0x8108, 0x9129, 0xa14a, 0xb16b, 0xc18c, 0xd1ad, 0xe1ce, 0xf1ef,
    0x1231, 0x0210, 0x3273, 0x2252, 0x52b5, 0x4294, 0x72f7, 0x62d6,
    0x9339, 0x8318, 0xb37b, 0xa35a, 0xd3bd, 0xc39c, 0xf3ff, 0xe3de,
    0x2462, 0x3443, 0x0420, 0x1401, 0x64e6, 0x74c7, 0x44a4, 0x5485,
    0xa56a, 0xb54b, 0x8528, 0x9509, 0xe5ee, 0xf5cf, 0xc5ac, 0xd58d,
    0x3653, 0x2672, 0x1611, 0x0630, 0x76d7, 0x66f6, 0x5695, 0x46b4,
    0xb75b, 0xa77a, 0x9719, 0x8738, 0xf7df, 0xe7fe, 0xd79d, 0xc7bc,
    0x48c4, 0x58e5, 0x6886, 0x78a7, 0x0840, 0x1861, 0x2802, 0x3823,
    0xc9cc, 0xd9ed, 0xe98e, 0xf9af, 0x8948, 0x9969, 0xa90a, 0xb92b,
    0x5af5, 0x4ad4, 0x7ab7, 0x6a96, 0x1a71, 0x0a50, 0x3a33, 0x2a12,
    0xdbfd, 0xcbdc, 0xfbbf, 0xeb9e, 0x9b79, 0x8b58, 0xbb3b, 0xab1a,
    0x6ca6, 0x7c87, 0x4ce4, 0x5cc5, 0x2c22, 0x3c03, 0x0c60, 0x1c41,
    0xedae, 0xfd8f, 0xcdec, 0xddcd, 0xad2a, 0xbd0b, 0x8d68, 0x9d49,
    0x7e97, 0x6eb6, 0x5ed5, 0x4ef4, 0x3e13, 0x2e32, 0x1e51, 0x0e70,
    0xff9f, 0xefbe, 0xdfdd, 0xcffc, 0xbf1b, 0xaf3a, 0x9f59, 0x8f78,
    0x9188, 0x81a9, 0xb1ca, 0xa1eb, 0xd10c, 0xc12d, 0xf14e, 0xe16f,
    0x1080, 0x00a1, 0x30c2, 0x20e3, 0x5004, 0x4025, 0x7046, 0x6067,
    0x83b9, 0x9398, 0xa3fb, 0xb3da, 0xc33d, 0xd31c, 0xe37f, 0xf35e,
    0x02b1, 0x1290, 0x22f3, 0x32d2, 0x4235, 0x5214, 0x6277, 0x7256,
    0xb5ea, 0xa5cb, 0x95a8, 0x8589, 0xf56e, 0xe54f, 0xd52c, 0xc50d,
    0x34e2, 0x24c3, 0x14a0, 0x0481, 0x7466, 0x6447, 0x5424, 0x4405,
    0xa7db, 0xb7fa, 0x8799, 0x97b8, 0xe75f, 0xf77e, 0xc71d, 0xd73c,
    0x26d3, 0x36f2, 0x0691, 0x16b0, 0x6657, 0x7676, 0x4615, 0x5634,
    0xd94c, 0xc96d, 0xf90e, 0xe92f, 0x99c8, 0x89e9, 0xb98a, 0xa9ab,
    0x5844, 0x4865, 0x7806, 0x6827, 0x18c0, 0x08e1, 0x3882, 0x28a3,
    0xcb7d, 0xdb5c, 0xeb3f, 0xfb1e, 0x8bf9, 0x9bd8, 0xabbb, 0xbb9a,
    0x4a75, 0x5a54, 0x6a37, 0x7a16, 0x0af1, 0x1ad0, 0x2ab3, 0x3a92,
    0xfd2e, 0xed0f, 0xdd6c, 0xcd4d, 0xbdaa, 0xad8b, 0x9de8, 0x8dc9,
    0x7c26, 0x6c07, 0x5c64, 0x4c45, 0x3ca2, 0x2c83, 0x1ce0, 0x0cc1,
    0xef1f, 0xff3e, 0xcf5d, 0xdf7c, 0xaf9b, 0xbfba, 0x8fd9, 0x9ff8,
    0x6e17, 0x7e36, 0x4e55, 0x5e74, 0x2e93, 0x3eb2, 0x0ed1, 0x1ef0] 



def create_with_parity (init_data,   # numeric data (may be less than full array
                        num_bits,    # number of bits in item, valid:  1,2,4,8,9,16,18,32,36,64,72
#                        start_bit,   # bit number to start filling from 
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
#            print ("item = 0x%x, p = 0x%x"%(item,item >> num_bits8))
            for bt in range (num_bits_p):
                pbdata[sb+bt] = (item >> (bt+num_bits8)) & 1;
#                print ("pbdata[%d] = 0x%x"%(sb+bt, pbdata[sb+bt]))
            sb += num_bits_p
        for i in range (len(pbdata)//256):
            d = 0;
            for b in range(255, -1,-1):
                d = (d<<1) +  pbdata[256*i+b]
            data_p.append(d)
#    print(bdata)  
#    print(data)  
#    print(pbdata)  
#    print(data_p)  
    return {'data':data,'data_p':data_p}

def print_params(data,out_file_name):
    with open(out_file_name,"w") as out_file:
        for i, v in enumerate(data['data']):
            if v:
                print (", .INIT_%02X (256'h%064X)"%(i,v), file=out_file)
        for i, v in enumerate(data['data_p']):
            if v:
                print (", .INITP_%02X (256'h%064X)"%(i,v), file=out_file)

def print_params(data):
    print("Paste following to memory parameters in Verilog source file:")
    for i, v in enumerate(data['data']):
        if v:
            print (", .INIT_%02X (256'h%064X)"%(i,v))
    for i, v in enumerate(data['data_p']):
        if v:
            print (", .INITP_%02X (256'h%064X)"%(i,v))

rslt = create_with_parity (CRC16_XMODEM_TABLE,   # init_data,   # numeric data (may be less than full array
                           16, # num_bits,    # number of bits in item, valid:  1,2,4,8,9,16,18,32,36,64,72
                           False) #full_bram):  # true if ramb36, false - ramb18
print_params(rslt)#,"test.vh")

# from FLIR docs:
def crc16(data, crc=0x1d0f): #Note the new initial condition is 0x1d0f instead of 0.
# in C:return(USHORT)((crcin << 8) ^ ccitt_16Table[((crcin >> 8)^(data))&255]);
    for byte in data:
        crc = ((crc << 8) & 0xff00) ^ CRC16_XMODEM_TABLE[((crc >> 8) & 0xff) ^ byte]
    return crc & 0xffff

