from __future__ import print_function
'''
# Copyright (C) 2015, Elphel.inc.
# Methods that mimic Verilog tasks used for simulation  
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
#import sys
#import x393_mem
#MCNTRL_TEST01_CHN4_STATUS_CNTRL=0
NUM_FINE_STEPS=    5
def hx(obj,length=None):
    frmt="0x%x"
    if (length):
        frmt="0x%0"+str(length)+"x"
    s=""        
    try:
        s=frmt%obj
        s1=s[0:2]
        for i in range(2,len(s)):
            if s[i] != '0':
                break
            s1+="o"
        s=s1+s[len(s1):]    
    except:
        s=str(obj)
    return s
'''
Simulate Verilog concatenation. Input list tuple of items, each being a pair of (value, width)
'''    
def concat(items):
#    print(items)
    val=0
    width=0
    for vw in reversed(items):
        v=vw[0]
        if not isinstance(v,(int,long)):
            if v:
                v=1 # So True/False will also work, not just 0/1
            else:
                v=0
        val |= (v & ((1 << vw[1])-1))<<width
        width += vw[1]
    return (val,width)

def bits(val,field):
    try:
        high=field[0]
        low=field[1]
        if low > high:
            low,high=high,low
    except:
        low=field+0 # will be error if not a number
        high=low
    return (val >> low) & ((1 << (high-low+1))-1)    
def getParWidthLo(bitRange):
        if bitRange=='INTEGER':
            return (32,0)
        else:
            try:
#                print(">>bitRange=%s"%bitRange,end=" ")
                if bitRange[0] != '[':
#                    print("\nbitRange[0]=%s"%(bitRange[0]))
                    return None # may also fail through except if bitRange=""
                startPosHi=1
                endPosHi=bitRange.index(':')
                startPosLo=endPosHi+1
                endPosLo=bitRange.index(']')
#                print("startPosHi=%d, endPosHi=%d, startPosLo=%d, endPosLo=%d"%(startPosHi,endPosHi,startPosLo,endPosLo))
                
                if endPosHi<0:
                    endPosHi=endPosLo
                    startPosLo=-1
            except:
                return None
#            print("1: startPosHi=%d, endPosHi=%d, startPosLo=%d, endPosLo=%d"%(startPosHi,endPosHi,startPosLo,endPosLo))
            if endPosHi <0:
                return None # no ":" or terminating "]"
            loBit=0
            try:
                if startPosLo > 0:
#                    print("2. startPosHi=%d, endPosHi=%d, startPosLo=%d, endPosLo=%d"%(startPosHi,endPosHi,startPosLo,endPosLo))
#                    print("bitRange[startPosLo,endPosLo]=%s"%(bitRange[startPosLo:endPosLo]))
#                    print("bitRange[startPosHi,endPosHi]=%s"%(bitRange[startPosHi:endPosHi]))
                    loBit=int(bitRange[startPosLo:endPosLo])
                    width=int(bitRange[startPosHi:endPosHi])-loBit+1
                return (width,loBit)
            except:
                return None # could not parse: undefined width
                    
def getParWidth(bitRange):
    wl=getParWidthLo(bitRange)
#    print("\n***wl=%s, bitRange=%s"%(str(wl),str(bitRange)))
#    print("bitRange=%s wl=%s"%(bitRange,str(wl)))
    if not wl:
        return None
    else:
        return wl[0]
                    
def hexMultiple(data):
    if isinstance(data,list) or isinstance(data,tuple):
        rslt=[]
        for item in data:
            if isinstance(item,list) or isinstance(item,tuple):
                subResult=[]
                for subItem in item:
                    try:
                        subResult.append("0x%x"%subItem)
                    except:
                        subResult.append(str(subItem))
                rslt.append(subResult)
            else:
                try:
                    rslt.append("0x%x"%item)
                except:
                    rslt.append(str(item))
        rslt=str(rslt)
    else:
        try:
            rslt = "0x%x"%item
        except:
            rslt = str(item)
    return rslt
        
def checkIntArgs(names,var_dict):
    for name in names:
        try:
            v=var_dict[name]
        except:
            raise Exception("ERROR: '%s' is not among %s"%(name,str(var_dict.keys())))    
        if not isinstance(v,(int,long)):
            print ("Expected an integer for '%s', got '%s"%(name,v))
            try:
                d=int(v,16)
                print ("Did you mean 0x%x ?"%d)
            except:
                pass
            raise Exception("Not a number for '%s' : '%s'"%(name,v))
def smooth2d(arr2d):
    smooth=[]
    l=len(arr2d)-1
    for i in range(l+1):
        im=(0,i-1)[i>0]
        ip=(l,i+1)[i<l]
        row=[]
        for j in range(len(arr2d[i])):
            row.append(0.5*arr2d[i][j]+0.25*(arr2d[ip][j]+arr2d[im][j]))
        smooth.append(row)
    return smooth                      
   
def split_delay(dly):
    """
    Convert hardware composite delay into continuous one
    <dly> 8-bit (5+3) hardware delay value (or a list of delays)
    Returns continuous delay value (or a list of delays)
    """
    if isinstance(dly,list) or isinstance(dly,tuple):
        rslt=[]
        for d in dly:
            rslt.append(split_delay(d))
        return rslt
    try:
        if isinstance(dly,float):
            dly=int(dly+0.5)
        dly_int=dly>>3
        dly_fine=dly & 0x7
        if dly_fine > (NUM_FINE_STEPS-1):
            dly_fine= NUM_FINE_STEPS-1
        return dly_int*NUM_FINE_STEPS+dly_fine
    except:
        return None    

def combine_delay(dly):
    """
    Convert continuous delay value to the 5+3 bit encoded one
    <dly> continuous (0..159) delay (or a list of delays)
    Returns  8-bit (5+3) hardware delay value (or a list of delays)
    """
    if isinstance(dly,list) or isinstance(dly,tuple):
        rslt=[]
        for d in dly:
            rslt.append(combine_delay(d))
        return rslt
    try:
        if isinstance(dly,float):
            dly=int(dly+0.5)
        return ((dly/NUM_FINE_STEPS)<<3)+(dly%NUM_FINE_STEPS)
    except:
        return None

def convert_mem16_to_w32(mem16):
    """
    Convert a list of 16-bit memory words
    into a list of 32-bit data as encoded in the buffer memory
    Each 4 of the input words provide 2 of the output elements
    <mem16> - a list of the memory data
    Returns a list of 32-bit buffer data
    """
    res32=[]
    for i in range(0,len(mem16),4):
        res32.append(((mem16[i+3] & 0xff) << 24) |
                     ((mem16[i+2] & 0xff) << 16) |
                     ((mem16[i+1] & 0xff) << 8) |
                     ((mem16[i+0] & 0xff) << 0))
        res32.append((((mem16[i+3]>>8) & 0xff) << 24) |
                     (((mem16[i+2]>>8) & 0xff) << 16) |
                     (((mem16[i+1]>>8) & 0xff) << 8) |
                     (((mem16[i+0]>>8) & 0xff) << 0))
    return res32

def convert_w32_to_mem16(w32):
    """
    Convert a list of 32-bit data as encoded in the buffer memory
    into a list of 16-bit memory words (so each bit corresponds to DQ line
    Each 2 of the input words provide 4 of the output elements
    <w32> - a list of the 32-bit buffer data
    Returns a list of 16-bit memory data
    """
    mem16=[]
    for i in range(0,len(w32),2):
        mem16.append(((w32[i]>> 0) & 0xff) | (((w32[i+1] >>  0) & 0xff) << 8)) 
        mem16.append(((w32[i]>> 8) & 0xff) | (((w32[i+1] >>  8) & 0xff) << 8)) 
        mem16.append(((w32[i]>>16) & 0xff) | (((w32[i+1] >> 16) & 0xff) << 8)) 
        mem16.append(((w32[i]>>24) & 0xff) | (((w32[i+1] >> 24) & 0xff) << 8)) 
    return mem16

