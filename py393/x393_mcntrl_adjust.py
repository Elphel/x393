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
#import sys
#import x393_mem
#x393_pio_sequences
from import_verilog_parameters import VerilogParameters
from x393_mem                import X393Mem
from x393_axi_control_status import X393AxiControlStatus
from x393_pio_sequences      import X393PIOSequences
from x393_mcntrl_timing      import X393McntrlTiming
from x393_mcntrl_buffers     import X393McntrlBuffers
#from verilog_utils import * # concat, bits 
#from verilog_utils import hx, concat, bits, getParWidth 
#from verilog_utils import concat #, getParWidth
#from x393_axi_control_status import concat, bits
#from time import sleep

NUM_FINE_STEPS=    5

class X393McntrlAdjust(object):
    DRY_MODE= True # True
    DEBUG_MODE=1
    x393_mem=None
    x393_axi_tasks=None #x393X393AxiControlStatus
    x393_pio_sequences=None
    x393_mcntrl_timing=None
    x393_mcntrl_buffers=None
    verbose=1
    def __init__(self, debug_mode=1,dry_mode=True):
        self.DEBUG_MODE=  debug_mode
        self.DRY_MODE=    dry_mode
        self.x393_mem=            X393Mem(debug_mode,dry_mode)
        self.x393_axi_tasks=      X393AxiControlStatus(debug_mode,dry_mode)
        self.x393_pio_sequences=  X393PIOSequences(debug_mode,dry_mode)
        self.x393_mcntrl_timing=  X393McntrlTiming(debug_mode,dry_mode)
        self.x393_mcntrl_buffers= X393McntrlBuffers(debug_mode,dry_mode)
        self.__dict__.update(VerilogParameters.__dict__["_VerilogParameters__shared_state"]) # Add verilog parameters to the class namespace
        try:
            self.verbose=self.VERBOSE
        except:
            pass
        
    def split_delay(self,dly):
        """
        Convert hardware composite delay into continuous one
        <dly> 8-bit (5+3) hardware delay value
        Returns continuous delay value
        """
        global NUM_FINE_STEPS
        dly_int=dly>>3
        dly_fine=dly & 0x7
        if dly_fine > (NUM_FINE_STEPS-1):
            dly_fine= NUM_FINE_STEPS-1
        return dly_int*NUM_FINE_STEPS+dly_fine    

    def combine_delay(self,dly):
        """
        Convert continuous delay value to the 5+3 bit encoded one
        <dly> continuous (0..159) delay
        Returns  8-bit (5+3) hardware delay value
        """
        return ((dly/NUM_FINE_STEPS)<<3)+(dly%NUM_FINE_STEPS)

    def bad_data(self,buf):
        """
        The whole block contains only "bad data" - nothing was read
        It can happen if command was not decoded correctly
        <buf> - list of the data read
        Returns True if the data is bad, False otherwise
        """
        for w in buf:
            if (w!=0xffffffff): return False
        return True            

    def convert_mem16_to_w32(self,mem16):
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
    
    def convert_w32_to_mem16(self,w32):
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



    def scan_dqs(self,
                 low_delay,
                 high_delay,
                 num ):
        """
        Scan DQS input delay values
        <low_delay>   low delay value
        <high_delay>  high delay value
        <num>         number of 64-bit words to process
        """
        self.x393_pio_sequences.set_read_pattern(num+1) # do not use first/last pair of the 32 bit words
        low = self.split_delay(low_delay)
        high = self.split_delay(high_delay)
        results = []
        for dly in range (low, high+1):
            enc_dly=self.combine_delay(dly)
            self.x393_mcntrl_timing.axi_set_dqs_idelay(enc_dly)
            buf= self.x393_pio_sequences.read_pattern(self,
                     (4*num+2),     # num,
                     0,             # show_rslt,
                     1) # Wait for operation to complete
            if self.bad_data(buf):
                results.append([])
            else:    
                data=[0]*32 # for each bit - even, then for all - odd
                for w in range (4*num):
                    lane=w%2
                    for wb in range(32):
                        g=(wb/8)%2
                        b=wb%8+lane*8+16*g
                        if (buf[w+2] & (1<<wb) != 0):
                            data[b]+=1
                results.append(data)
                print ("%3d (0x%02x): "%(dly,enc_dly),end="")
                for i in range(32):
                    print("%5x"%data[i],end="")
                print()    
        for index in range (len(results)):
            dly=index+low
            enc_dly=self.combine_delay(dly)
            if (len (results[index])>0):
                print ("%3d (0x%02x): "%(dly,enc_dly),end="")
                for i in range(32):
                    print("%5x"%results[index][i],end="")
                print()    
        print()
        print()
        print ("Delay",end=" ")
        for i in range(16):
            print ("Bit%dP"%i,end=" ")
        for i in range(16):
            print ("Bit%dM"%i,end=" ")
        print()
        for index in range (len(results)):
            dly=index+low
            enc_dly=self.combine_delay(dly)
            if (len (results[index])>0):
                print ("%d"%(dly),end=" ")
                for i in range(32):
                    print("%d"%results[index][i],end=" ")
                print()    
        return results                                  
