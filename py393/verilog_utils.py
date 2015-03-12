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
def hx(obj):
    try:
        return "0x%x"%obj
    except:
        return str(obj)
'''
Simulate Verilog concatenation. Input list tuple of items, each being a pair of (value, width)
'''    
def concat(items):
    val=0
    width=0
    for vw in reversed(items):
        v=vw[0]
        if vw[1]==1:
            v=(0,1)[v] # So True/False will also work, not juet o/1
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
                    
            