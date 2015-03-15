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
import random
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
        <dly> 8-bit (5+3) hardware delay value (or a list of delays)
        Returns continuous delay value (or a list of delays)
        """
        if isinstance(dly,list) or isinstance(dly,tuple):
            rslt=[]
            for d in dly:
                rslt.append(self.split_delay(d))
            return rslt
        try:    
            dly_int=dly>>3
            dly_fine=dly & 0x7
            if dly_fine > (NUM_FINE_STEPS-1):
                dly_fine= NUM_FINE_STEPS-1
            return dly_int*NUM_FINE_STEPS+dly_fine
        except:
            return None    

    def combine_delay(self,dly):
        """
        Convert continuous delay value to the 5+3 bit encoded one
        <dly> continuous (0..159) delay (or a list of delays)
        Returns  8-bit (5+3) hardware delay value (or a list of delays)
        """
        if isinstance(dly,list) or isinstance(dly,tuple):
            rslt=[]
            for d in dly:
                rslt.append(self.split_delay(d))
            return rslt
        try:
            return ((dly/NUM_FINE_STEPS)<<3)+(dly%NUM_FINE_STEPS)
        except:
            return None

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
        Scan DQS input delay values using pattern read mode
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

    def scan_dq_idelay(self,
                       low_delay,
                       high_delay,
                       num ):
        """
        Scan DQ input delay values using pattern read mode
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
            self.x393_mcntrl_timing.axi_set_dq_idelay(enc_dly) # same value to all DQ lines
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
        print()
        return results                                  

    def adjust_dq_idelay(self,
                         low_delay,
                         high_delay,
                         num,
                         falling ): # 0 - use rising as delay increases, 1 - use falling
        """
        Adjust individual per-line DQ delays using read pattern mode
        <low_delay>   low delay value
        <high_delay>  high delay value
        <num>         number of 64-bit words to process
        <falling>     0 - use rising edge as delay increases, 1 - use falling one
        Returns:      list of 16 per-line delay values
        """
        low = self.split_delay(low_delay)
        data_raw=self.scan_dq_idelay(low_delay,high_delay,num)
        data=[]
        delays=[]
        for i,d in enumerate(data_raw):
            if len(d)>0:
                data.append(d)
                delays.append(i+low)
        print(delays)
        
        best_dlys=[0]*16
        best_diffs=[num*8.0]*16
        for i in range (1,len(data)-1):
            for j in range (16):
                delta=abs(data[i][j] -data[i][j+16] + 0.5*(data[i-1][j] -data[i-1][j+16]+data[i+1][j] -data[i+1][j+16]))
                sign=(data[i-1][j] -data[i-1][j+16]-data[i+1][j]+data[i+1][j+16])
                if falling > 0: sign=-sign;
                if (sign>0) and (delta < best_diffs[j]):
                    best_diffs[j]=delta
                    best_dlys[j]=delays[i]
        for i in range (16):
            print("%2d: %3d (0x%02x)"%(i,best_dlys[i],self.combine_delay(best_dlys[i])))
        self.x393_mcntrl_timing.axi_set_dq_idelay((best_dlys[0:8],best_dlys[8:16]))
        return best_dlys       
    """
        for i in range (8):
        axi_set_dly_single(1,i,combine_delay(best_dlys[i]))    
    for i in range (8):
        axi_set_dly_single(3,i,combine_delay(best_dlys[i+8]))    

    """

    def corr_delays(self,
                    low,         # absolute delay value of start scan
                    avg_types,   # weights of each of the 8  bit sequences
                    res_bits,    # individual per-bit results
                    res_avg,     # averaged eye data table, each line has 8 elements, or [] for bad measurements
                    corr_fine,   # fine delay correction
                    ends_dist,   # do not process if one of the primary interval ends is within this from 0.0 or 1.0
                    verbose
                    ):
        """
        Correct delays
        <low>         absolute delay value of start scan
        <avg_types>   weights of each of the 8  bit sequences
        <res_bits>    individual per-bit results
        <res_avg>     averaged eye data table, each line has 8 elements, or [] for bad measurements
        <corr_fine>   fine delay correction
        <ends_dist>   do not process if one of the primary interval ends is within this from 0.0 or 1.0
        <verbose>
        Returns list of corrected delays
        """
        # coarse adjustments - decimate arrays to use the same (0) value of the fine delay
        usable_types=[]
        for i,w in enumerate(avg_types):
            if (w>0) and not i in (0,7) :
                usable_types.append(i)
        if (verbose): print ("usable_types=",usable_types)            
        def thr_sign(bit,typ,limit,data):
#            lim_l=limit
#            lim_u=1.0-limit
            if data[bit][typ] <= limit: return -1
            if data[bit][typ] >= (1.0- limit): return 1
            return 0
        def thr_signs(typ,limit,data):
            signs=""
            for bit in range(15,-1,-1):
                signs+=("-","0","+")[thr_sign(bit,typ,limit,data)+1]
        def full_state(types,limit,data): #will NOT return None if any is undefined
            state=""
            for t in types:
                for bit in range(15,-1,-1):
                    state+=("-","0","+")[thr_sign(bit,t,limit,data)+1]
            return state                    
        def full_same_state(types,limit,data): #will return None if any is undefined
            state=""
            for t in types:
                s0=thr_sign(15,t,limit,data)
                state+=("-","0","+")[s0+1]
                for bit in range(15,-1,-1):
                    s=thr_sign(bit,t,limit,data)
                    if (not s) or (s != s0) :
                        return None
            return state                    
                
                        
        def diff_state(state1,state2):
            for i,s in enumerate(state1):
                if s != state2[i]:
                    return True
            return False    
#       start_index=0;
#       if (low % NUM_FINE_STEPS) != 0:
#           start_index=NUM_FINE_STEPS-(low % NUM_FINE_STEPS)
        #find the first index where all bits are either above 1.0 -ends_dist or below ends_dist
        for index in range(len(res_avg)):
            print (" index=%d: %s"%(index,full_state(usable_types,ends_dist,res_bits[index])))
            initial_state=full_same_state(usable_types,ends_dist,res_bits[index])
            if initial_state:
                break
        else:
            print ("Could not find delay value where all bits/types are outside of undefined area (%f thershold)"%ends_dist)
            return None
        if (verbose): print ("start index=%d, start state=%s"%(index,initial_state))
        #find end of that state
        for index in range(index+1,len(res_avg)):
            state=full_same_state(usable_types,ends_dist,res_bits[index])
            if state != initial_state:
                break
        else:
            print ("Could not find delay value where initial state changes  (%f thershold)"%ends_dist)
            return None
        last_initial_index=index-1
        if (verbose): print ("last start state index=%d, new state=%s"%(last_initial_index,state))
        #find new defined state for all bits
        for index in range(last_initial_index+1,len(res_avg)): #here repeat last delay
            new_state=full_same_state(usable_types,ends_dist,res_bits[index])
            if new_state and (new_state != initial_state):
                break
        else:
            print ("Could not find delay value whith the new defined state (%f thershold)"%ends_dist)
            return None
        new_state_index=index
        if (verbose): print ("new defined state index=%d, new state=%s"%(new_state_index,new_state))
    # remove states that do not have a transition    
        filtered_types=[]
        for i,t in enumerate(usable_types):
            if (new_state[i]!=initial_state[i]):
                filtered_types.append(t)
        if (verbose): print ("filtered_types=",filtered_types)            
        second_trans= 1 in filtered_types # use second transition, false - use first transition
        if (verbose): print("second_trans=",second_trans)
    #    signs=((1,1,-1,-1),(1,-1,1,-1))[1 in filtered_types]
        signs=((0,0,1,1,-1,-1,0,0),(0,1,-1,0,0,1,-1,0))[1 in filtered_types]
        if (verbose): print("signs=",signs)
            
        for index in range(last_initial_index,new_state_index+1):
            if (verbose): print ("index=%3d, delay=%3d, state=%s"%(index,index+low,full_state(filtered_types,ends_dist,res_bits[index])))  
    
    #extend range, combine each bit and averages
        ext_low_index=last_initial_index-(new_state_index-last_initial_index)
        if ext_low_index<0:
            ext_low_index=0
        ext_high_index=new_state_index+(new_state_index-last_initial_index)
        if ext_high_index>=len(res_bits):
            ext_high_index=res_bits-1
        if (verbose): print("ext_low_index=%d ext_high_index=%d"%(ext_low_index,ext_high_index))
        bit_data=[]
        for i in range(16):
            bit_data.append([]) # [[]]*16 does not work! (shallow copy)
        avg_data=[]
        for index0 in range(ext_high_index-ext_low_index+1):
            index=index0+ext_low_index
    #        if (verbose): print(res_bits[index])
            bit_samples=[0.0]*16
            avg_sample=0.0
            weight=0.0
            for t in filtered_types:
                w=avg_types[t]
                weight+=w
                sw=signs[t]*w
                avg_sample += sw * (2.0*res_avg[index][t]-1.0)
    #            if (verbose): print ("%3d %d:"%(index,t),end=" ")
                for bit in range(16):
                    bit_samples[bit] += sw*(2.0*res_bits[index][bit][t]-1.0)
    #                if (verbose): print ("%.3f"%(res_bits[index][bit][t]),end=" ")
    #            if (verbose): print()    
            
            avg_sample /= weight
            avg_data.append(avg_sample)    
            for bit in range(16):
                bit_samples[bit] /= weight
    #            if (verbose): print ("bit_samples[%d]=%f"%(bit,bit_samples[bit]))
                bit_data[bit].append(bit_samples[bit])
    #        if (verbose): print ("bit_samples=",bit_samples)
    #       if index0 <3:
    #            if (verbose): print ("bit_data=",bit_data)
                        
    #    if (verbose): print ("\n\nbit_data=",bit_data)
        period_fine=len(corr_fine)
        for index in range(ext_high_index-ext_low_index+1):
            dly=low+index+ext_low_index
            corr_dly=dly+corr_fine[dly%period_fine]
            if (verbose): print ("%d %d %.2f %.3f"%(index,dly,corr_dly,avg_data[index]),end=" ")
            for bit in range(16):
                if (verbose): print ("%.3f"%(bit_data[bit][index]),end=" ")
            if (verbose): print()            
    # Seems all above was an overkill, just find bit delays that result in  most close to 0
        delays=[]
        for bit in range(16):
            best_dist=1.0
            best_index=None
            for index in range(ext_high_index-ext_low_index+1):
                if (abs(bit_data[bit][index])<best_dist):
                    best_dist=abs(bit_data[bit][index])
                    best_index=index
            delays.append(best_index+low+ext_low_index)
        if (verbose): print (delays)
        return delays

    def calibrate_finedelay(self,
                            low,         # absolute delay value of start scan
                            avg_types,   # weights of each of the 8  bit sequences
                            res_avg,     # averaged eye data tablle, each line has 8 elements, or [] for bad measurements
                            ends_dist,   # do not process if one of the primary interval ends is within this from 0.0 or 1.0
                            min_diff):   # minimal difference between primary delay steps to process
        """
        Calibrate fine delay taps
        <low>         absolute delay value of start scan
        <avg_types>   weights of each of the 8  bit sequences
        <res_avg>     averaged eye data tablle, each line has 8 elements, or [] for bad measurements
        <ends_dist>   do not process if one of the primary interval ends is within this from 0.0 or 1.0
        <min_diff>:   minimal difference between primary delay steps to process

        """
        start_index=0;
        if (low % NUM_FINE_STEPS) != 0:
            start_index=NUM_FINE_STEPS-(low % NUM_FINE_STEPS)
        weights=[0.0]*( NUM_FINE_STEPS)
        corr=[0.0]*( NUM_FINE_STEPS) #[0] will stay 0
        for index in range(start_index, len(res_avg)-NUM_FINE_STEPS,NUM_FINE_STEPS):
            if (len(res_avg[index])>0) and (len(res_avg[index+NUM_FINE_STEPS])>0):
                for t,w in enumerate(avg_types):
                    if (w>0):
                        f=res_avg[index][t];
                        s=res_avg[index+NUM_FINE_STEPS][t];
#                       print ("index=%d t=%d f=%f s=%s"%(index,t,f,s))
                        if ((f>ends_dist) and (s>ends_dist) and
                             (f< (1-ends_dist)) and (s < (1-ends_dist)) and
                             (abs(s-f)>min_diff)):
                            diff=s-f
                            wd=w* diff*diff # squared? or use abs?
                            for j in range (1,NUM_FINE_STEPS):
                                if ( (len(res_avg[index+j])>0)):
                                    v=res_avg[index+j][t];
                                    #correction to the initila step==1
                                    d=(v-f)/(s-f)*NUM_FINE_STEPS-j
                                    #average
                                    corr[j]+=wd*d
                                    weights[j]+=wd
#       print ("\n weights:")
#       print(weights)
#       print ("\n corr:")
#       print(corr)
        for i,w in enumerate(weights):
            if (w>0) : corr[i]/=w # will skip 0
        print ("\ncorr:")
#       print(corr)
        for i,c in enumerate(corr):
            print ("%i %f"%(i,c))
        return corr

    def scan_or_adjust_delay_random(self,
                                    low_delay,
                                    high_delay,
                                    use_dq,
                                    use_odelay,
                                    ends_dist,
                                    min_diff,
                                    adjust,
                                    verbose):
        """
        Scan or adjust delays using random data write+read
        <low_delay>   Low delay value to tru
        <high_delay>  high delay value to try
        <use_dq>      0 - scan dqs, 1 - scan dq (common value, post-adjustment)
        <use_odelay>  0 - use input delays, 1 - use output delays
        <ends_dist>   do not process if one of the primary interval ends is within this from 0.0 or 1.0
        <min_diff>    minimal difference between primary delay steps to process 
        <adjust>      0 - scan, 1 - adjust
        <verbose>:    verbose mode (more prints) 
        Returns list of calculated delay values
        """
           
#        global BASEADDR_PORT1_WR,VERBOSE;
#        saved_verbose=VERBOSE;
#        VERBOSE=False;
        low = self.split_delay(low_delay)
        high = self.split_delay(high_delay)
        rand16=[]
        for i in range(512):
            rand16.append(random.randint(0,65535))
        wdata=self.convert_mem16_to_w32(rand16)
        if (verbose and not adjust): print("rand16:")
        for i in range(len(rand16)):
            if (i & 0x1f) == 0:
                if (verbose and not adjust): print("\n%03x:"%i,end=" ")
            if (verbose and not adjust): print("%04x"%rand16[i],end=" ")
        if (verbose and not adjust): print("\n")        
        if (verbose and not adjust): print("wdata:")
        for i in range(len(wdata)):
            if (i & 0xf) == 0:
                if (verbose and not adjust): print("\n%03x:"%i,end=" ")
            if (verbose and not adjust): print("%08x"%wdata[i],end=" ")
        if (verbose and not adjust): print("\n")        
        bit_type=[] # does not include first and last elements
        for i in range(1,511):
            types=[]
            for j in range(16):
                types.append((((rand16[i-1]>>j) & 1)<<2) | (((rand16[i  ]>>j) & 1)<<1) |  (((rand16[i+1]>>j) & 1)))
            bit_type.append(types)
    #        if (verbose and not adjust): print ("i=%d",i)
    #        if (verbose and not adjust): print(types)
    #    total_types=[[0]*8]*16 # number of times each type occurred in the block for each DQ bit (separate for DG up/down?)
        total_types=[] # number of times each type occurred in the block for each DQ bit (separate for DG up/down?)
        for i in range(16): total_types.append([0]*8) 
        for typ in bit_type:
    #        if (verbose and not adjust): print(typ)
            for j in range(16):
    #            total_types[j][typ[j]]+=1
                total_types[j][typ[j]]=total_types[j][typ[j]]+1
        if (verbose and not adjust): print("\ntotal_types:")        
        if (verbose and not adjust): print (total_types)
        
        avg_types=[0.0]*8
        N=0
        for t in total_types:
            for j,n in enumerate(t):
                avg_types[j]+=n
                N+=n
        for i in range(len(avg_types)):
            avg_types[i]/=N
        if (verbose and not adjust): print("\avg_types:")        
        if (verbose and not adjust): print (avg_types)
        #write blok buffer with 256x32bit data
                
        self.x393_mcntrl_buffers.write_block_buf_chn(0,0,wdata); # fill block memory (channel, page, number)
        self.x393_pio_sequences.set_write_block(
                                                5,        # 3'h5,     # bank
                                                0x1234,   # 15'h1234, # row address
                                                0x100     # 10'h100   # column address
        )
        if (use_odelay==0) :
            self.x393_pio_sequences.write_block(1) # Wait for operation to complete
            if verbose: print("++++++++ block written once")
    #now scanning - first DQS, then try with DQ (post-adjustment - best fit) 
        results = []
        if verbose: print("******** use_odelay=%d use_dq=%d"%(use_odelay,use_dq))
        for dly in range (low, high+1):
            enc_dly=self.combine_delay(dly)
            if (use_odelay!=0):
                if (use_dq!=0):
                    if verbose: print("******** axi_set_dq_odelay(0x%x)"%enc_dly)
                    self.x393_mcntrl_timing.axi_set_dq_odelay(enc_dly) #  set the same odelay for all DQ bits
                else:
                    if verbose: print("******** axi_set_dqs_odelay(0x%x)"%enc_dly)
                    self.x393_mcntrl_timing.axi_set_dqs_odelay(enc_dly)
                self.x393_pio_sequences.write_block(1) # Wait for operation to complete
                if verbose: print("-------- block written AGAIN")
            else:
                if (use_dq!=0):
                    if verbose: print("******** axi_set_dq_idelay(0x%x)"%enc_dly)
                    self.x393_mcntrl_timing.axi_set_dq_idelay(enc_dly)#  set the same idelay for all DQ bits
                else:
                    if verbose: print("******** axi_set_dqs_idelay(0x%x)"%enc_dly)
                    self.x393_mcntrl_timing.axi_set_dqs_idelay(enc_dly)
            buf32=self.x393_pio_sequences.read_block(self,
                                                     256,    # num,
                                                     0,      # show_rslt,
                                                     1)      # Wait for operation to complete
            if self.bad_data(buf32):
                results.append([])
            else: 
                read16=self.convert_w32_to_mem16(buf32) # 512x16 bit, same as DDR3 DQ over time
                if verbose and (dly==low):   
                    if (verbose and not adjust): print("buf32:")
                    for i in range(len(buf32)):
                        if (i & 0xf) == 0:
                            if (verbose and not adjust): print("\n%03x:"%i,end=" ")
                        if (verbose and not adjust): print("%08x"%buf32[i],end=" ")
                    if (verbose and not adjust): print("\n")        
    
    
                    if (verbose and not adjust): print("read16:")
                    for i in range(len(read16)):
                        if (i & 0x1f) == 0:
                            if (verbose and not adjust): print("\n%03x:"%i,end=" ")
                        if (verbose and not adjust): print("%04x"%read16[i],end=" ")
                    if (verbose and not adjust): print("\n")
                data=[] # number of times each type occurred in the block for each DQ bit (separate for DG up/down?)
                for i in range(16):
                    data.append([0]*8) 
                
                for i in range (1,511):
                    w= read16[i]
                    typ=bit_type[i-1] # first and last words are not used, no type was calculated
                    for j in range(16):
                        if (w & (1<<j)) !=0:
                            data[j][typ[j]]+=1
                for i in range(16):
                    for t in range(8):
                        if (total_types[i][t] >0 ):
                            data[i][t]*=1.0/total_types[i][t]
                results.append(data)
                if (verbose and not adjust): print ("%3d (0x%02x): "%(dly,enc_dly),end="")
                for i in range(16):
                    if (verbose and not adjust): print("[",end="")
                    for j in range(8):
                        if (verbose and not adjust): print("%3d"%(round(100.0*data[i][j])),end=" ")
                    if (verbose and not adjust): print("]",end=" ")
                if (verbose and not adjust): print()    
        titles=["'000","'001","'010", "'011","'100","'101","'110","'111"]
        #calculate weighted averages
        #TODO: for DQ scan shift individual bits for the best match
        if  use_dq:
            if (verbose and not adjust): print("TODO: shift individual bits for the best match before averaging")
    
        res_avg=[]
        for dly in range (len(results)):
            if (len(results[dly])>0):
                data=results[dly]
                avg=[0.0]*8
                for t in range(8):
                    weight=0;
                    d=0.0
                    for i in range(16):
                        weight+=total_types[i][t]
                        d+=total_types[i][t]*data[i][t]
                    if (weight>0):
                        d/=weight
                    avg[t] = d
                res_avg.append(avg)
            else:
                res_avg.append([])
        corr_fine=self.calibrate_finedelay(
                low,         # absolute delay value of start scan
                avg_types,   # weights of weach of the 8  bit sequences
                res_avg,     # averaged eye data tablle, each line has 8 elements, or [] for bad measurements
                ends_dist/256.0, # ends_dist,   # do not process if one of the primary interval ends is within this from 0.0 or 1.0
                min_diff/256.0) #min_diff):   # minimal difference between primary delay steps to process
        period=len(corr_fine)
    
        if (not adjust):
            print("\n\n\n========== Copy below to the spreadsheet,  use columns from corr_delay ==========")
            print("========== First are individual results for each bit, then averaged eye pattern ==========")
            print ("delay corr_delay",end=" ")
            for t in range(8):
                for i in range(16):
                    if (not adjust): print("%02d:%s"%(i,titles[t]),end=" ")
            print()
            for index in range (len(results)):
                if (len(results[index])>0):
                    dly=index+low
                    corr_dly=dly+corr_fine[dly%period]
                    print ("%d %.2f"%(dly,corr_dly),end=" ")
                    for t in range(8):
                        for i in range(16):
                            print("%.4f"%(results[dly][i][t]),end=" ")
                    print()
                            
            print("\n\n\n========== Copy below to the spreadsheet,  use columns from corr_delay ==========")
            print("========== data above can be used for the individual bits eye patterns ==========")            
            print ("delay corr_delay",end=" ")
            for t in range(8):
                print(titles[t],end=" ")
            print()
            for index in range (len(res_avg)):
                if (len(res_avg[index])>0):
                    dly=index+low
                    corr_dly=dly+corr_fine[dly%period]
                    print ("%d %.2f"%(dly,corr_dly),end=" ")
                    for t in range(8):
                        print("%.4f"%(res_avg[dly][t]),end=" ")
                    print()
        dly_corr=None
        if adjust:        
            dly_corr=self.corr_delays(
                low,         # absolute delay value of start scan
                avg_types,   # weights of weach of the 8  bit sequences
                results,    #individual per-bit results
                res_avg,     # averaged eye data tablle, each line has 8 elements, or [] for bad measurements
                corr_fine,    # fine delay correction
                ends_dist/256.0,   # find where all bits are above/below that distance from 0.0/1.0margin
                verbose)
#            VERBOSE=verbose
#            print ("VERBOSE=",VERBOSE)
            print ("dly_corr=",dly_corr)
            print ("use_dq=",use_dq)
            if dly_corr and use_dq: # only adjusting DQ delays, not DQS
                dly_comb=self.combine_delay(dly_corr)
                if use_odelay:
                    self.x393_mcntrl_timing.axi_set_dq_odelay((dly_comb[0:8],dly_comb[8:16]))
                    """
                    for i in range (8):
                        axi_set_dly_single(0,i,combine_delay(dly_corr[i]))    
                    for i in range (8):
                        axi_set_dly_single(2,i,combine_delay(dly_corr[i+8]))
                    """
                else: 
                    self.x393_mcntrl_timing.axi_set_dq_idelay((dly_comb[0:8],dly_comb[8:16]))
                    """
                    for i in range (8):
                        axi_set_dly_single(1,i,combine_delay(dly_corr[i]))    
                    for i in range (8):
                        axi_set_dly_single(3,i,combine_delay(dly_corr[i+8]))
                    """
    #          use_dq, # 0 - scan dqs, 1 - scan dq (common valuwe, post-adjustment)
    #      use_odelay,
            
#        VEBOSE=saved_verbose
        return dly_corr





    def scan_delay_random(self,
                          low_delay,
                          high_delay,
                          use_dq, # 0 - scan dqs, 1 - scan dq (common valuwe, post-adjustment)
                          use_odelay, # 0 - idelay, 1 - odelay
                          ends_dist,   # do not process if one of the primary interval ends is within this from 0.0 or 1.0
                          min_diff,
                          verbose):   # minimal difference between primary delay steps to process
        """
        Scan  delays using random data write+read
        <low_delay>   Low delay value to tru
        <high_delay>  high delay value to try
        <use_dq>      0 - scan dqs, 1 - scan dq (common value, post-adjustment)
        <use_odelay>  0 - use input delays, 1 - use output delays
        <ends_dist>   do not process if one of the primary interval ends is within this from 0.0 or 1.0
        <min_diff>    minimal difference between primary delay steps to process 
        <verbose>:    verbose mode (more prints) 
        """
        self.scan_or_adjust_delay_random(
                                         low_delay,
                                         high_delay,
                                         use_dq, # 0 - scan dqs, 1 - scan dq (common valuwe, post-adjustment)
                                         use_odelay,
                                         ends_dist,   # do not process if one of the primary interval ends is within this from 0.0 or 1.0
                                         min_diff,
                                         False,     #scan, not adjust
                                         verbose)   # minimal difference between primary delay steps to process

    def adjust_dq_delay_random(self,
                               low_delay,
                               high_delay,
                               #use_dq, # 0 - scan dqs, 1 - scan dq (common valuwe, post-adjustment)
                               use_odelay,
                               ends_dist,   # do not process if one of the primary interval ends is within this from 0.0 or 1.0
                               min_diff,   # minimal difference between primary delay steps to process
                               verbose):
        """
        Adjust  delays using random data write+read
        <low_delay>   Low delay value to tru
        <high_delay>  high delay value to try
        <use_odelay>  0 - use input delays, 1 - use output delays
        <ends_dist>   do not process if one of the primary interval ends is within this from 0.0 or 1.0
        <min_diff>    minimal difference between primary delay steps to process 
        <verbose>:    verbose mode (more prints)
        Returns list of delays 
        """
        return self.scan_or_adjust_delay_random(
                                                low_delay,
                                                high_delay,
                                                1, #use_dq, # 0 - scan dqs, 1 - scan dq (common valuwe, post-adjustment)
                                                use_odelay,
                                                ends_dist,   # do not process if one of the primary interval ends is within this from 0.0 or 1.0
                                                min_diff,    # minimal difference between primary delay steps to process
                                                True,        #adjust, not scan
                                                verbose)   
