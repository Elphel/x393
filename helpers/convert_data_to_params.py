#!/usr/bin/env python
# -*- coding: utf-8 -*-
from __future__ import print_function
# Copyright (C) 2015, Elphel.inc.
# Helper module to convert zigzag ROM for JPEG quantizer
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
__copyright__ = "Copyright 2015, Elphel, Inc."
__license__ = "GPL"
__version__ = "3.0+"
__maintainer__ = "Andrey Filippov"
__email__ = "andrey@elphel.com"
__status__ = "Development"
import sys
def create_no_parity (init_data, # numeric data
                      num_bits,    # number of bits in item
                      start_bit,   # bit number to start filling from 
                      full_bram):  # true if raamb36, false - ramb18
    bsize = (0x4000,0x8000)[full_bram]
    bdata = [0  for i in range(bsize)]
    for item in init_data:
        for bt in range (num_bits):
            bdata[start_bit+bt] = (item >> bt) & 1;
        start_bit += num_bits
    data = []
    for i in range (len(bdata)/256):
        d = 0;
        for b in range(255, -1,-1):
            d = (d<<1) +  bdata[256*i+b]
        data.append(d)
#    print(bdata)  
#    print(data)  
    return {'data':data,'data_p':[]}
        
            
def create_gamma(curves_data, half):
    mdata = [0 for i in range(2048)]
    index = half * 1024;
    for n in range(4):
        for i in range (256):
            base =curves_data[257*n+i]
            diff =curves_data[257*n+i+1]-curves_data[257*n+i];
            diff1=curves_data[257*n+i+1]-curves_data[257*n+i]+8;
            if ((diff > 63) or (diff < -64)):
                data18 = (base & 0x3ff) | (((diff1 >> 4) & 0x7f) << 10) | 0x20000 # {1'b1,diff1[10:4],base[9:0]};
            else:
                data18 = (base & 0x3ff) | ((diff & 0x7f) <<10) # {1'b0,diff [ 6:0],base[9:0]};
            mdata[index] = data18
#            print ('%03x: %05x (%03x %02x %02x)'%(index,data18, base,diff,diff1))
            index +=1
            
    data=[]
    for a in range(128):
        d=0
        for w in range(16):
            d |= (mdata[16 * a + w] & 0xffff) << (16 * w);
        data.append(d)
    data_p=[]
    for a in range(16):
        d=0
        for w in range(128):
            d |= (mdata[128 * a + w] & 0x3) << (2 * w);
        data_p.append(d)
    return {'data':data,'data_p':data_p}
def print_params(data,out_file_name):
    with open(out_file_name,"w") as out_file:
        for i, v in enumerate(data['data']):
            if v:
                print (", .INIT_%02X (256'h%064X)"%(i,v), file=out_file)
    #    if (include_parity):
        for i, v in enumerate(data['data_p']):
            if v:
                print (", .INITP_%02X (256'h%064X)"%(i,v), file=out_file)
#print ('Number of arguments: %d'%(len(sys.argv)))
#print ('Argument List:%s'%(str(sys.argv)))
with open(sys.argv[1]) as f:
    tokens=f.read().split()
#    print(lines)
#print (lines.split())
values=[]
for w in tokens:
    values.append(int(w,16))
#print (values)
#print (len(values))

#gamma tables
#print (create_gamma(values,1))
if sys.argv[1].find("1028") >= 0:
    print_params(create_gamma(values,0),sys.argv[1]+"0.vh")            
    print_params(create_gamma(values,1),sys.argv[1]+"1.vh")            
elif sys.argv[1].find("huffman") >= 0:
    print_params(create_no_parity(values,32,0,False),sys.argv[1]+".vh")
else:
    print_params(create_no_parity(values,16,0,False),sys.argv[1]+".vh")
            
'''
 create_no_parity (init_data, # numeric data
                      num_bits,    # number of bits in item
                      start_bit,   # bit number to start filling from 
                      full_bram):  # true if raamb36, false - ramb18

// INIT_00 to I.INIT_00(256'h0
task program_huffman;
// huffman tables data
  reg   [23:0]   huff_data[0:511];
  integer i;
  begin
    $readmemh("huffman.dat",huff_data);
    cpu_wr ('he,'h200);   // start address of huffman tables
    for (i=0;i<512;i=i+1) begin
      cpu_wr('hf,huff_data[i]);
    end
  end
endtask

task program_quantization;
// quantization tables data
//  reg   [11:0]   quant_data[0:255];
  reg   [15:0]   quant_data[0:255];
  integer i;
  begin
//    $readmemh("quantization.dat",quant_data);
    $readmemh("quantization_100.dat",quant_data);
    cpu_wr ('he,'h0);   // start address of quantization tables
    for (i=0;i<256;i=i+2) begin
      cpu_wr('hf,{quant_data[i+1],quant_data[i]});
    end
  end
endtask

task program_coring;
// coring tables data
  reg   [15:0]   coring_data[0:1023];
  integer i;
  begin
//    $readmemh("quantization.dat",quant_data);
    $readmemh("coring.dat",coring_data);
    cpu_wr ('he,'hc00);   // start address of coring tables
    for (i=0;i<1024;i=i+2) begin
      cpu_wr('hf,{coring_data[i+1],coring_data[i]});
    end
  end
endtask


'''
