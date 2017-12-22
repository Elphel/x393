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
Calculate ROM for MCLT fold indices with Bahyer pattern on the input
Source tile is expanded to accommodate small lateral chromatic aberrations (up to +/- 3 pixels for 22x22 pixel tiles):
A0..A2 - sample column in folded 8x8 tile
A3..A5 - sample row in folded 8x8 tile
A6 -     variant, folding to the same 8x8 sample (with checker board there are only 2 of 4)
A7 -     invert checker: 0 - pixels on main diagonal, 1 - zeros on main diagonal
A8..A9 - source tile size: 0 - 16x16, 1 - 18x18, 2 - 20x20, 3 - 22x22 (all < 512)
D0..D4 - pixel column in 16x16 tile (for window)
D5..D7 - pixel row in 16x16 tile (for window)
D8..D15 - pixel offset in full tile, MSB omitted - it will be restored from bits 7 and 15
D16 - negate for mode 0 (CC)
D17 - negate for mode 1 (SC) other modes (CS and SS are reversed SC and CC, negated for inverted checker
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
mclt_wnd_rom_path=  '../includes/mclt_bayer_fold_rom.vh'

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

def  get_fold_indices(x, n = 8):
    n1 = n >> 1
#    ind = [[0,0,0,0,0,0],[0,0,0,0,0,0]]# new int[2][6];
    ind = [[0,0,0,0],[0,0,0,0]]# new int[2][6];
    if x < n1:
        ind[0][0] = n + n1 - x - 1 #// C: -cR, S: +cR
        ind[0][1] = n1     + x
        ind[0][2] = -1
        ind[0][3] =  1
#        ind[0][4] = n1     - x -1
#        ind[0][5] =  -1 #// c - window derivative over shift is negative
        
        ind[1][0] = n + n1 + x#;     // C: -d,  S: -d
        ind[1][1] = n1     - x - 1
        ind[1][2] = -1
        ind[1][3] = -1

#        ind[1][4] = n1     + x;
#        ind[1][5] =  -1# // d - window derivative over shift is negative
    else:
        x-=n1;
        ind[0][0] =          x#     // C: +a, S: +a
        ind[0][1] =          x
        ind[0][2] =  1
        ind[0][3] =  1
#        ind[0][4] =  n     - x - 1
#        ind[0][5] =  1#   // a - window derivative over shift is positive
        
        ind[1][0] = n      - x - 1# // C: -bR, S: +bR
        ind[1][1] = n      - x - 1
        ind[1][2] = -1
        ind[1][3] =  1
#        ind[1][4] =          x
#        ind[1][5] =  1#   // b - window derivative over shift is positive
    return ind

def create_fold(n = 8): # n - DCT and window size
#    fold_index = (n*n) * [4*[0]] # new int[n*n][4];
    fold_index = []
    for _ in range(n*n):
        fold_index.append([0,0,0,0])
#    fold_k =     new double[4][n*n][4];
#    fold_signs = 4 * [(n*n) * [4*[0]]] 
#    fold_signs = 4 * [(n*n) * [4*[0]]]
    fold_signs = []
    for _ in range(4):
        a = []
        for _a in range(n*n):
            a.append([0,0,0,0])
        fold_signs.append(a)            
    print("fold_signs=",fold_signs) 
    
    vert_ind = [0,0]        # new int[2];
    vert_k =   [[0,0],[0,0]] #new double[2][2];
    hor_ind =  [0,0]        # new int[2];
    hor_k =    [[0,0],[0,0]] #new double[2][2];
    #int [][] fi;
    n2 = 2 * n;
    for i in range(n): # (int i = 0; i < n; i++ ){
        fi = get_fold_indices(i,n)
        vert_ind[0] = fi[0][0];
        vert_ind[1] = fi[1][0];
        vert_k[0][0] =   fi[0][2]# * hwindow[fi[0][1]]; // use cosine sign
        vert_k[0][1] =   fi[1][2]# * hwindow[fi[1][1]]; // use cosine sign
        vert_k[1][0] =   fi[0][3]# * hwindow[fi[0][1]]; // use sine sign
        vert_k[1][1] =   fi[1][3]# * hwindow[fi[1][1]]; // use sine sign
        for j in range(n): # (int j = 0; j < n; j++ ){
            fi = get_fold_indices(j,n)
            hor_ind[0] = fi[0][0];
            hor_ind[1] = fi[1][0];
            hor_k[0][0] =   fi[0][2]# * hwindow[fi[0][1]]; // use cosine sign
            hor_k[0][1] =   fi[1][2]# * hwindow[fi[1][1]]; // use cosine sign
            hor_k[1][0] =   fi[0][3]# * hwindow[fi[0][1]]; // use sine sign
            hor_k[1][1] =   fi[1][3]# * hwindow[fi[1][1]]; // use sine sign
            indx = n * i + j
            for k in range(4): #(int k = 0; k<4;k++) {
                fold_index[indx][k] = n2 * vert_ind[(k>>1) & 1] + hor_ind[k & 1]
            for mode in range(4): # (int mode = 0; mode<4; mode++){
                for k in range(4): #(int k = 0; k<4;k++) {
                    fold_signs[mode][indx][k]=     vert_k[(mode>>1) &1][(k>>1) & 1] * hor_k[mode &1][k & 1]
                    #fold_k[mode][indx][k] =     vert_k[(mode>>1) &1][(k>>1) & 1] * hor_k[mode &1][k & 1]; 
#        for (int i = 0; i < n; i++ ){
#            fi = get_fold_indices(i,n);
#            System.out.println(i+"->"+String.format("?[%2d %2d %2d %2d] [%2d %2d %2d %2d] %f %f",
#                    fi[0][0],fi[0][1],fi[0][2],fi[0][3],
#                    fi[1][0],fi[1][1],fi[1][2],fi[1][3], hwindow[fi[0][1]], hwindow[fi[1][1]]));
#        }
    print("fold_index=",fold_index)
    print("fold_signs=",fold_signs)
    for  i in range(n * n): #(int i = 0; i < n*n; i++){
        print("%3x:   %6x   %6x   %6x   %6x"%(i,fold_index[i][0],fold_index[i][1],fold_index[i][2],fold_index[i][3]))
        print("   :   %2d   %2d   %2d   %2d"%(fold_signs[0][i][0],  fold_signs[0][i][1], fold_signs[0][i][2], fold_signs[0][i][3]))
        print("   :   %2d   %2d   %2d   %2d"%(fold_signs[1][i][0],  fold_signs[1][i][1], fold_signs[1][i][2], fold_signs[1][i][3]))
        print("   :   %2d   %2d   %2d   %2d"%(fold_signs[2][i][0],  fold_signs[2][i][1], fold_signs[2][i][2], fold_signs[2][i][3]))
        print("   :   %2d   %2d   %2d   %2d"%(fold_signs[3][i][0],  fold_signs[3][i][1], fold_signs[3][i][2], fold_signs[3][i][3]))
    """
    fold = (4*n*n)*[0]    
    for var in range(4):
        for i in range(n * n):
            fold[var * 64 + i] = (fold_index[i][var]
                                  + (((0,1)[fold_signs[0][i][var] < 0]) <<  8) +
                                  + (((0,1)[fold_signs[1][i][var] < 0]) <<  9) +
                                  + (((0,1)[fold_signs[2][i][var] < 0]) << 10) +
                                  + (((0,1)[fold_signs[3][i][var] < 0]) << 11))
    """
    fold = (4*2*2*n*n)*[0] # sizes (16-18-20-22) * invert_checker (0,1) * variant(0,1) * index (0..63)
    for inv_checker in range(2):    
        for i in range(n * n):
            addresses=[]
            signs = []
            for var4 in range(4):
                row = (fold_index[i][var4] >> 4) & 0xf
                col = (fold_index[i][var4] >> 0) & 0xf
                blank = (row ^ col ^ inv_checker) & 1
                if not blank:
                    addresses.append (fold_index[i][var4])
                    signs.append ([((0,1)[fold_signs[0][i][var4] < 0]),((0,1)[fold_signs[1][i][var4] < 0])])
            for size_bits, size_val in enumerate ([16,18,20,22]):
                for var2 in range(2):
                    row = (addresses[var2] >> 4) & 0xf
                    col = (addresses[var2] >> 0) & 0xf
                    full_addr = (row * size_val + col) & 0xff # saving one address bit
                    fold[(size_bits << 8) + (inv_checker << 7) + (var2 << 6) + i] = (
                        (addresses[var2]  & 0xff) +
                        ((full_addr & 0xff) << 8) +
                        (signs[var2][0] << 16) +
                        (signs[var2][1] << 17))         
            
#      wire                        [7:0] wnd_a_w =   fold_rom_out[7:0];
#    wire         [PIX_ADDR_WIDTH-1:0] pix_a_w =   {~fold_rom_out[15] & fold_rom_out[7],fold_rom_out[15:8]};
#    reg          [PIX_ADDR_WIDTH-1:0] pix_a_r;
#    wire                       [ 1:0] sgn_w =     fold_rom_out[16 +: 2];
            
    return fold

'''
Calculate ROM for MCLT fold indices with Bahyer pattern on the input
Source tile is expanded to accommodate small lateral chromatic aberrations (up to +/- 3 pixels for 22x22 pixel tiles):
A0..A2 - sample column in folded 8x8 tile
A3..A5 - sample row in folded 8x8 tile
A6 -     variant, folding to the same 8x8 sample (with checker board there are only 2 of 4)
A7 -     invert checker: 0 - pixels on main diagonal, 1 - zeros on main diagonal
A8..A9 - source tile size: 0 - 16x16, 1 - 18x18, 2 - 20x20, 3 - 22x22 (all < 512)
D0..D4 - pixel column in 16x16 tile (for window)
D5..D7 - pixel row in 16x16 tile (for window)
D8..D15 - pixel offset in full tile, MSB omitted - it will be restored from bits 7 and 15
D16 - negate for mode 0 (CC)
D17 - negate for mode 1 (SC) other modes (CS and SS are reversed SC and CC, negated for inverted checker
'''
                        
print_params(
    create_with_parity(create_fold (), 18, False),
    os.path.abspath(os.path.join(os.path.dirname(__file__), mclt_wnd_rom_path)),
    "// MCLT 16x16...22x22 Bayer -> 8x8 fold indices")
print ("MCLT 16x16...22x22 Bayer -> 8x8 fold indices data is written to %s"%(os.path.abspath(os.path.join(os.path.dirname(__file__), mclt_wnd_rom_path))))
                 
