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
def create_gamma(curves_data, half):
    pass
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
with open(sys.argv[1]) as file:
    tokens=file.read().split()
#    print(lines)
#print (lines.split())
values=[]
for w in tokens:
    values.append(int(w,16))
#print (values)
#print (len(values))

#gamma tables
#print (create_gamma(values,1))
print_params(create_gamma(values,0),sys.argv[1]+"0.vh")            
print_params(create_gamma(values,1),sys.argv[1]+"1.vh")            
            
            
'''
// INIT_00 to I.INIT_00(256'h0
task program_curves;
    input   [1:0] num_sensor;
    input   [1:0] sub_channel;
    reg   [9:0]   curves_data[0:1027];  // SuppressThisWarning VEditor : assigned in $readmem() system task
    integer n,i,base,diff,diff1;
//    reg [10:0] curv_diff;
    reg    [17:0] data18;
    begin
        $readmemh("input_data/linear1028rgb.dat",curves_data);
         set_sensor_gamma_table_addr (
            num_sensor,
            sub_channel,
            2'b0,         //input   [1:0] color;
            1'b0);        //input         page; // only used if SENS_GAMMA_BUFFER != 0
        
        for (n=0;n<4;n=n+1) begin
          for (i=0;i<256;i=i+1) begin
            base =curves_data[257*n+i];
            diff =curves_data[257*n+i+1]-curves_data[257*n+i];
            diff1=curves_data[257*n+i+1]-curves_data[257*n+i]+8;
    //        $display ("%x %x %x %x %x %x",n,i,curves_data[257*n+i], base, diff, diff1);
            #1;
            if ((diff>63) || (diff < -64)) data18 = {1'b1,diff1[10:4],base[9:0]};
            else                           data18 = {1'b0,diff [ 6:0],base[9:0]};
            set_sensor_gamma_table_data ( // need 256 for a single color data
                num_sensor,
                data18); // 18-bit table data
            
          end
        end  
    end
endtask

'''
