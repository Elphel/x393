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
import sys
#import x393_mem
#x393_pio_sequences
import random
#from import_verilog_parameters import VerilogParameters
from x393_mem                import X393Mem
#from x393_axi_control_status import X393AxiControlStatus
import x393_axi_control_status
from x393_pio_sequences      import X393PIOSequences
from x393_mcntrl_timing      import X393McntrlTiming
from x393_mcntrl_buffers     import X393McntrlBuffers
#from verilog_utils import * # concat, bits 
#from verilog_utils import hx, concat, bits, getParWidth 
#from verilog_utils import concat #, getParWidth
#from x393_axi_control_status import concat, bits
#from time import sleep
from verilog_utils import checkIntArgs,smooth2d

import get_test_dq_dqs_data # temporary to test processing            
import x393_lma
import time
#import vrlg
NUM_FINE_STEPS=    5
NUM_DLY_STEPS =NUM_FINE_STEPS * 32 # =160 

class X393McntrlAdjust(object):
    DRY_MODE= True # True
    DEBUG_MODE=1
    x393_mem=None
    x393_axi_tasks=None #x393X393AxiControlStatus
    x393_pio_sequences=None
    x393_mcntrl_timing=None
    x393_mcntrl_buffers=None
    verbose=1
    adjustment_state={}
    def __init__(self, debug_mode=1,dry_mode=True):
        self.DEBUG_MODE=  debug_mode
        self.DRY_MODE=    dry_mode
        self.x393_mem=            X393Mem(debug_mode,dry_mode)
#        self.x393_axi_tasks=      X393AxiControlStatus(debug_mode,dry_mode)
        self.x393_axi_tasks=      x393_axi_control_status.X393AxiControlStatus(debug_mode,dry_mode)
        self.x393_pio_sequences=  X393PIOSequences(debug_mode,dry_mode)
        self.x393_mcntrl_timing=  X393McntrlTiming(debug_mode,dry_mode)
        self.x393_mcntrl_buffers= X393McntrlBuffers(debug_mode,dry_mode)
#        self.__dict__.update(VerilogParameters.__dict__["_VerilogParameters__shared_state"]) # Add verilog parameters to the class namespace
        try:
            self.verbose=vrlg.VERBOSE
        except:
            pass
    #//SET DQ ODELAY=[['0xd9', '0xdb', '0xdc', '0xd4', '0xe0', '0xda', '0xd4', '0xd8'], ['0xdc', '0xe0', '0xf1', '0xdc', '0xe0', '0xdc', '0xdc', '0xdc']]
    def format_dq_to_verilog(self,
                             estr):
        """
        Convert dq delays list to the form to paste to the Verilog parameters code
        <estr> quoted string, such as:
         "[['0xd9', '0xdb', '0xdc', '0xd4', '0xe0', '0xda', '0xd4', '0xd8'], ['0xdc', '0xe0', '0xf1', '0xdc', '0xe0', '0xdc', '0xdc', '0xdc']]"
        Returns a pair of strings to paste
        """
        se=eval(estr) # now a list of list of strings
        for l in se:
            for i,v in enumerate(l):
                l[i]=int(v,16)
        for lane in range(2):
            print("lane%d = 64'h"%lane,end="")
            for i in range(len(se[lane])):
                print("%02x"%se[lane][-i-1],end="")
            print()
        

        
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
            if isinstance(dly,float):
                dly=int(dly+0.5)
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
                rslt.append(self.combine_delay(d))
            return rslt
        try:
            if isinstance(dly,float):
                dly=int(dly+0.5)
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
    def missing_dqs(self,
                     rd_blk,
                     quiet=False):
        """
        Suspect missing final DQS puls(es) during write if last written burst matches previous one
        <rd_blk> - block of 32-bit data read from DDR3 device
        <quiet>  - no output
        Returns True if missing DQS pulse is suspected
        """
        if (not rd_blk) or (len(rd_blk) <8 ):
            return False
        for i in range(-4,0):
            if rd_blk[i] != rd_blk[i-4]:
                break
        else:
            if not quiet:
                print ("End of the block repeats 2 last 8-bursts, insufficient number of trailing DQS pulses is suspected:")
                print("\n%03x:"%(len(rd_blk)-8),end=" ")
                for i in range(len(rd_blk)-8,len(rd_blk)):
                    print("%08x"%rd_blk[i],end=" ")
                print("\n")
            return True
        return False            
                   

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

    def set_phase_with_refresh(self, # check result for not None
                               phase,
                               quiet=1):
        """
        Set specified phase and matching cmda_odelay while temporarily turning off refresh
        @param phase phase to set, signed short
        @param quiet reduce output 
        @return cmda_odelay linear value or None if there is no valid cmda output delay for this phase
        """
        if not "cmda_bspe" in self.adjustment_state:
            raise Exception ("No cmda_odelay data is available. 'adjust_cmda_odelay 0 1 0.1 3' command should run first.")
        dly_steps=self.x393_mcntrl_timing.get_dly_steps()
        numPhaseSteps= int(dly_steps['SDCLK_PERIOD']/dly_steps['PHASE_STEP']+0.5)
        cmda_odly_data=self.adjustment_state['cmda_bspe'][phase % numPhaseSteps]
        if (not cmda_odly_data): # phase is invalid for CMDA
            return None
        cmda_odly_lin=cmda_odly_data['ldly']
        self.x393_axi_tasks.enable_refresh(0)
        self.x393_mcntrl_timing.axi_set_phase(phase,quiet=quiet)
        self.x393_mcntrl_timing.axi_set_cmda_odelay(self.combine_delay(cmda_odly_lin),quiet=quiet)
        self.x393_axi_tasks.enable_refresh(1)
        return cmda_odly_lin
    
    def set_phase_delays(self,
                         phase,
                         inp_period='A',
                         out_period='A',
                         refresh=True,
                         quiet=1):
        """
        Set clock phase and all I/O delays optimal for this phase
        @param phase value to set
        @param inp_period - period branch for DQ inputs: E<arly>, N<ominal>, L<ate> or A<ny>    
        @param out_period - period branch for DQ outputs: E<arly>, N<ominal>, L<ate> or A<ny>
        @param refresh - turn refresh OFF before and ON after changing the delays and phase
        @param quiet - reduce output
        @return True on success, False on invalid phase    
        """
        rslt_names=("early","nominal","late")
        enl_in=None
        enl_out=None
        enl_in_used=None
        enl_out_used=None
        try:
            inp=str(inp_period)[0].upper()
        except:
            print ("Invalid parameter <inp_period>=%s"%(str(inp_period)))
            return False
        try:
            outp=str(out_period)[0].upper()
        except:
            print ("Invalid parameter <out_period>=%s"%(str(out_period)))
            return False
        
        if inp == 'A':
            enl_in=rslt_names
        else:
            for k in rslt_names:
                if inp == k[0].upper():
                    enl_in=(k,)
                    break
            else:
                print ("Unrecognized parameter <inp_period>=%s"%(str(inp_period)))
                return False

        if outp == 'A':
            enl_out=rslt_names
        else:
            for k in rslt_names:
                if outp == k[0].upper():
                    enl_out=(k,)
                    break
            else:
                print ("Unrecognized parameter <out_period>=%s"%(str(out_period)))
                return False
                    
                    
        dly_steps=self.x393_mcntrl_timing.get_dly_steps()
        numPhaseSteps= int(dly_steps['SDCLK_PERIOD']/dly_steps['PHASE_STEP']+0.5)
        phase= phase % numPhaseSteps # valid for negative also, numPhaseSteps should be <=128 (now it is 112)
        try:
            delays_phase=self.adjustment_state['delays_phase']
        except:
            print("Delays for phases (self.adjustment_state['delays_phase']) are not set, running 'get_delays_vs_phase' command ")
            try:
                delays_phase=self.get_delays_vs_phase(filter_dqo=2,
                                         filter_dqi=2,
                                         filter_dqso=2,
                                         filter_dqsi=2,
                                         filter_cmda=2,
                                         keep_all=False,
                                         set_table=True,
                                         quiet=quiet+2)
                self.adjustment_state['delays_phase']=delays_phase
            except:
                print ("Failed to execute get_'delays_vs_phase' command")
                return False
        try:
            delays=delays_phase[phase]
        except:
            print("No valid delay data for phase %d is available"%(phase))
            return False

        try:
            cmda_odly=delays['cmda']
        except:
            print("No valid CMDA output delay data for phase %d is available, it is required"%(phase))
            return False

        try:
            dqs_idelays=delays['dqsi']
        except:
            dqs_idelays=None
            if quiet < 2:
                print ("No valid DQS input delay data for phase %d is available, it will not be set"%(phase))

        try:
            dqs_odelays=delays['dqso']
        except:
            dqs_odelays=None
            if quiet < 2:
                print ("No valid DQS output delay data for phase %d is available, it will not be set"%(phase))
                
        for k in enl_in:
            try:
                dq_idelays=delays['dqi'][k]
                enl_in_used=k
                break
            except:
                pass
        else:
            dq_idelays=None
            if quiet < 2:
                print ("No valid DQ input delay data for phase %d (period(s)=%s) is available, it will not be set"%(phase,str(enl_in)))
                
        for k in enl_out:
            try:
                dq_odelays=delays['dqo'][k]
                enl_out_used=k
                break
            except:
                pass
        else:
            dq_odelays=None
            if quiet < 2:
                print ("No valid DQ output delay data for phase %d (period(s)=%s) is available, it will not be set"%(phase,str(enl_out)))
                
        if quiet < 2:
            print ("Going to set:")
            print ("phase=",phase)
            print ('cmda_odly=',cmda_odly)
            print ('dqs_idelays=',dqs_idelays)
            print ('dqs_odelays=',dqs_odelays)
            print ('dq_idelays=',dq_idelays,' (',enl_in_used,')')
            print ('dq_odelays=',dq_odelays,' (',enl_out_used,')')
            print ('Memory refresh will %sbe controlled'%(('NOT ','')[refresh]))
        if refresh:
            self.x393_axi_tasks.enable_refresh(0)
        self.x393_mcntrl_timing.axi_set_phase(phase,quiet=quiet)
        self.x393_mcntrl_timing.axi_set_cmda_odelay(self.combine_delay(cmda_odly),quiet=quiet)
        if refresh:
            self.x393_axi_tasks.enable_refresh(1)
        if not dqs_idelays is None:
            self.x393_mcntrl_timing.axi_set_dqs_idelay(self.combine_delay(dqs_idelays),quiet=quiet)
        if not dq_idelays is None:
            self.x393_mcntrl_timing.axi_set_dq_idelay(self.combine_delay(dq_idelays),quiet=quiet)
        if not dqs_odelays is None:
            self.x393_mcntrl_timing.axi_set_dqs_odelay(self.combine_delay(dqs_odelays),quiet=quiet)
        if not dq_odelays is None:
            self.x393_mcntrl_timing.axi_set_dq_odelay(self.combine_delay(dq_odelays),quiet=quiet)
        if refresh:
            self.x393_axi_tasks.enable_refresh(1)
        return True
            
        """
    {
     'dqsi':[110, 100]
     'dqo':{'nominal': [95, 94, 99, 93, 99, 95, 94, 94, 93, 94, 100, 94, 93, 93, 90, 92]}
     'dqi':{'early': [1, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0]}
     'cmda':48
     'dqso':[57, 52]
    },
        
        """
        
        pass
    def scan_dqs(self,
                 low_delay, 
                 high_delay,
                 num=8,
                 sel=1,     # 0 - early, 1 - late read command (shift by a SDCLK period) 
                 quiet=2  ):
        """
        Scan DQS input delay values using pattern read mode
        <low_delay>   low delay value (in 'hardware' format, sparse)
        <high_delay>  high delay value (in 'hardware' format, sparse)
        <num>         number of 64-bit words to process
        <sel>        0 - early, 1 - late read command (shift by a SDCLK period) 
        <quiet>       less output
        """
        checkIntArgs(('low_delay','high_delay','num'),locals())
        self.x393_pio_sequences.set_read_pattern(num+1,sel) # do not use first/last pair of the 32 bit words
        low = self.split_delay(low_delay)
        high = self.split_delay(high_delay)
        results = []
        for dly in range (low, high+1):
            enc_dly=self.combine_delay(dly)
            self.x393_mcntrl_timing.axi_set_dqs_idelay(enc_dly)
            buf= self.x393_pio_sequences.read_pattern(
                     (4*num+2),     # num,
                     0,             # show_rslt,
                     1) # Wait for operation to complete
            if quiet <1:
                hbuf=[]
                for dd in buf:
                    hbuf.append(hex(dd))
                print(hbuf)
            # with "good" data each word in buf should be 0xff00ff00
            
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
                if quiet < 2:
                    print ("%3d (0x%02x): "%(dly,enc_dly),end="")
                    for i in range(32):
                        print("%5x"%data[i],end="")
                    print()
        if quiet<3:
            for index in range (len(results)):
                dly=index+low
                enc_dly=self.combine_delay(dly)
                if (len (results[index])>0):
                    print ("%3d (0x%02x): "%(dly,enc_dly),end="")
                    for i in range(32):
                        print("%5x"%results[index][i],end="")
                    print()    
            print()
        if quiet < 4:    
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
                       num=8,
                       sel=1,#  0 - early, 1 - late read command (shift by a SDCLK period) 
                       quiet=2 ):
        """
        Scan DQ input delay values using pattern read mode
        <low_delay>   low delay value (in 'hardware' format, sparse)
        <high_delay>  high delay value (in 'hardware' format, sparse)
        <num>         number of 64-bit words to process
        <sel>         0 - early, 1 - late read command (shift by a SDCLK period) 
        <quiet>       less output
        """
        checkIntArgs(('low_delay','high_delay','num'),locals())
        self.x393_pio_sequences.set_read_pattern(num+1,sel) # do not use first/last pair of the 32 bit words
        low = self.split_delay(low_delay)
        high = self.split_delay(high_delay)
        results = []
        for dly in range (low, high+1):
            enc_dly=self.combine_delay(dly)
            self.x393_mcntrl_timing.axi_set_dq_idelay(enc_dly) # same value to all DQ lines
            buf= self.x393_pio_sequences.read_pattern(
                     (4*num+2),     # num,
                     0,             # show_rslt,
                     1) # Wait for operation to complete
            if not quiet:
                hbuf=[]
                for dd in buf:
                    hbuf.append(hex(dd))
                print(hbuf)
            # with "good" data each word in buf should be 0xff00ff00
            if self.bad_data(buf):
                results.append([])
            else:    
                data=[0]*32 # for each bit - even, then for all - odd
                for w in range (4*num):    # read 32-bit word number
                    lane=w%2               # even words - lane 0, odd - lane 1
                    for wb in range(32):
                        g=(wb/8)%2
                        b=wb%8+lane*8+16*g
                        if (buf[w+2] & (1<<wb) != 0):# buf[w+2] - skip first 2 words
                            data[b]+=1
                results.append(data)
                #When all correct, data[:16] should be all 0, data[16:] - maximal, (with num=8  - 32)
                if not quiet: 
                    print ("%3d (0x%02x): "%(dly,enc_dly),end="")
                    for i in range(32):
                        print("%5x"%data[i],end="")
                    print()
        if quiet <2:                
            for index in range (len(results)):
                dly=index+low
                enc_dly=self.combine_delay(dly)
                if (len (results[index])>0):
                    print ("%3d (0x%02x): "%(dly,enc_dly),end="")
                    for i in range(32):
                        print("%5x"%results[index][i],end="")
                    print()    
            print()
        if quiet <3:                
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
                         num=8,
                         sel=1, # 0 - early, 1 - late read command (shift by a SDCLK period) 
                         falling=0, # 0 - use rising as delay increases, 1 - use falling
                         smooth=10,
                         quiet=2):
        """
        Adjust individual per-line DQ delays using read pattern mode
        DQS idelay(s) should be set 90-degrees from the final values
        <low_delay>   low delay value (in 'hardware' format, sparse)
        <high_delay>  high delay value (in 'hardware' format, sparse)
        <num>         number of 64-bit words to process
        <sel>         0 - early, 1 - late read command (shift by a SDCLK period) 
        <falling>     0 - use rising edge as delay increases, 1 - use falling one
                      In 'falling' mode results are the longest DQ idelay
                      when bits switch from correct to incorrect,
                      In 'rising' mode (falling==0) - the shortest one
        <smooth>      number of times to run LPF
        <quiet>       less output
        Returns:      list of 16 per-line delay values (sequential, not 'hardware')
        """
        checkIntArgs(('low_delay','high_delay','num'),locals())
        low = self.split_delay(low_delay)
        data_raw=self.scan_dq_idelay(low_delay,high_delay,num,sel,quiet)
        data=[]
        delays=[]
        for i,d in enumerate(data_raw):
            if len(d)>0:
                data.append(d)
                delays.append(i+low)
        if (quiet<2):
            print(delays)
        
        centerRaw=num*2.0# center value
        uncert=[] #"uncertanty of read for each bit and even/odd words. list of 32-element lists, each positive in the [0,1] interval
        rate=[]   # data change rate
        lm1=len(data)-1
        for i in range (0,len(data)):
            im1=(0,  i-1)[i>0]
            ip1=(lm1,i+1)[i<lm1]
            r_uncert=[]
            r_rate=[]
            for j in range (32):
                d=0.5*data[i][j]+0.25*(data[ip1][j]+data[im1][j])
                r=data[im1][j]-data[ip1][j]
                if (j>=16):
                    r=-r
                r_uncert.append(1.0-((d-centerRaw)/centerRaw)**2) #0 and max -> 0, center ->1.0
                r_rate.append(r/(2.0*centerRaw))
            uncert.append(r_uncert)
            rate.append(r_rate)
#            print ("%d %s"%(i,str(r_uncert)))
        for _ in range(smooth):
            uncert=smooth2d(uncert)
        for _ in range(smooth):
            rate= smooth2d(rate)
        val=[] # list of 16-element rows of composite uncert*rate values, multiplied for odd/even values, hoping not to have
        #         any bumps causes by asymmetry 0->1 and 1-->0
        for i in range (0,len(data)):
            r_val=[]
            for j in range(16):
                sign=(-1,1)[rate[i][j]>0]
                rr=rate[i][j]*rate[i][j+16]
#                if falling:
#                    sign=-sign
                if rr<0:
                    sign=0 # different slope direction - ignore                
                r_val.append(sign * rr * uncert[i][j] * uncert[i][j+16])
            val.append(r_val)
        best_dlys=[None]*16
        best_diffs=[None]*16
        for i in range (len(val)):
            for j in range (16):
                v=val[i][j]
                if falling:
                    v=-v
                if (best_dlys[j] is None) or (v>best_diffs[j]):
                    best_dlys[j]=  i+1
                    best_diffs[j]= v
        if quiet <2:
            for i in range (len(data)):
                print("%d "%(i),end="")
                for j in range (32):
                    print("%f "%uncert[i][j],end="")
                for j in range (32):
                    print("%f "%rate[i][j],end="")
                for j in range (16):
                    print("%f "%(val[i][j]),end="")
                print()
        
        for i in range (16):
            print("%2d: %3d (0x%02x)"%(i,best_dlys[i],self.combine_delay(best_dlys[i])))
        comb_delays=self.combine_delay(best_dlys)
        self.x393_mcntrl_timing.axi_set_dq_idelay((comb_delays[0:8],comb_delays[8:16]))
        return best_dlys       

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
            ext_high_index=len(res_bits)-1
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
                                    #correction to the initial step==1
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
        checkIntArgs(('low_delay','high_delay'),locals())
        brc=(5,        # 3'h5,     # bank
             0x1234,   # 15'h1234, # row address
             0x100)     # 10'h100   # column address
           
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

        self.x393_pio_sequences.set_write_block(*brc) #64 8-bursts, 1 extra DQ/DQS/ active cycle
        self.x393_pio_sequences.set_read_block(*brc)
        
        if (use_odelay==0) :
            self.x393_pio_sequences.write_block(0,1) # Wait for operation to complete
            if verbose: print("++++++++ block written once")
    #now scanning - first DQS, then try with DQ (post-adjustment - best fit) 
        results = []
        if verbose: print("******** use_odelay=%d use_dq=%d"%(use_odelay,use_dq))
        alreadyWarned=False
        for dly in range (low, high+1):
            enc_dly=self.combine_delay(dly)
            if (use_odelay!=0):
                if (use_dq!=0):
                    if verbose: print("******** axi_set_dq_odelay(0x%x)"%enc_dly)
                    self.x393_mcntrl_timing.axi_set_dq_odelay(enc_dly) #  set the same odelay for all DQ bits
                else:
                    if verbose: print("******** axi_set_dqs_odelay(0x%x)"%enc_dly)
                    self.x393_mcntrl_timing.axi_set_dqs_odelay(enc_dly)
                self.x393_pio_sequences.write_block(0,1) # Wait for operation to complete
                if verbose: print("-------- block written AGAIN")
            else:
                if (use_dq!=0):
                    if verbose: print("******** axi_set_dq_idelay(0x%x)"%enc_dly)
                    self.x393_mcntrl_timing.axi_set_dq_idelay(enc_dly)#  set the same idelay for all DQ bits
                else:
                    if verbose: print("******** axi_set_dqs_idelay(0x%x)"%enc_dly)
                    self.x393_mcntrl_timing.axi_set_dqs_idelay(enc_dly)
            buf32=self.x393_pio_sequences.read_block(
                                                     256,    # num,
                                                     0,      # show_rslt,
                                                     1)      # Wait for operation to complete
            if self.bad_data(buf32):
                results.append([])
            else:
                # Warn about possible missing DQS pulses during writes
                alreadyWarned |= self.missing_dqs(buf32, alreadyWarned) 
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
                            try:
                                print("%.4f"%(results[dly][i][t]),end=" ") #IndexError: list index out of range
                            except:
                                print(".????",end="")
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
                        try:
                            print("%.4f"%(res_avg[dly][t]),end=" ")
                        except:
                            print(".????",end=" ")
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
                          min_diff,   # minimal difference between primary delay steps to process
                          verbose):
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
        checkIntArgs(('low_delay','high_delay'),locals())
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
        checkIntArgs(('low_delay','high_delay'),locals())
        return self.scan_or_adjust_delay_random(
                                                low_delay,
                                                high_delay,
                                                1, #use_dq, # 0 - scan dqs, 1 - scan dq (common valuwe, post-adjustment)
                                                use_odelay,
                                                ends_dist,   # do not process if one of the primary interval ends is within this from 0.0 or 1.0
                                                min_diff,    # minimal difference between primary delay steps to process
                                                True,        #adjust, not scan
                                                verbose)   
           
    # if it will fail, re-try with phase shifted by 180 degrees (half SDCLK period)
    # Consider "hinted" scan when initial estimation for cmd_odelay is known from previous incomplete measurement
    # Then use this knowledge to keep delay in safe region (not too close to clock edge) during second scanning         
    def adjust_cmda_odelay(self,
                           start_phase=0,
                           reinits=1, #higher the number - more re-inits are used (0 - only where absolutely necessary
                           max_phase_err=0.1,
                           quiet=1
                           ):
        """
        Find CMDA output delay for each phase value using linear interpolation for available results
        Use write levelling mode (refresh off) and A7 (that makes it write levelling or not).
        Only A7 is subject to marginal timing, other signals are kept safe. But accidentally it still can hit
        wrong timing - in that case memory is reset and re-initialized
        Sets global parameters, including self.adjustment_state['cmda_bspe']
        @param start_phase initial phase to start measuremts (non-0 only for debugging dependencies)
        @param reinits higher the number - more re-inits are used (0 - only where absolutely necessary)
        @param max_phase_err maximal phase error for command and address line as a fraction of SDCLK period to consider
        @param quiet reduce output
        """
        start_phase &= 0xff
        if start_phase >=128:
            start_phase -= 256 # -128..+127
        recover_cmda_dly_step=0x20 # subtract/add from cmda_odelay (hardware!!!) and retry (same as 20 decimal)
        max_lin_dly=NUM_DLY_STEPS-1
        wlev_address_bit=7
        wlev_max_bad=0.01 # <= OK, > bad
        def phase_step(phase,cmda_dly):
            """
            Find marginal delay for address/comand lines for particular
            clock pahse
            Raises exception if failed to get write levelling data even after
            changing cmda delay and restarting memory device
            Returns a tuple of the current cmda_odelay (hardware) and a marginal one for a7
            """
            cmda_dly_lin=self.split_delay(cmda_dly)
            self.x393_mcntrl_timing.axi_set_phase(phase,quiet=quiet)
            self.x393_mcntrl_timing.axi_set_cmda_odelay(cmda_dly,quiet=quiet)
            wlev_rslt=self.x393_pio_sequences.write_levelling(1, quiet+1)
            if wlev_rslt[2]>wlev_max_bad: # should be 0, if not - Try to recover
                if quiet <4:
                    print("*** FAILED to read data in write levelling mode, restarting memory device")
                    print("    Retrying with the same cmda_odelay value = 0x%x"%cmda_dly)
                self.x393_pio_sequences.restart_ddr3()
                wlev_rslt=self.x393_pio_sequences.write_levelling(1, quiet)
                if wlev_rslt[2]>wlev_max_bad: # should be 0, if not - change delay and restart memory
                    cmda_dly_old=cmda_dly
                    if cmda_dly >=recover_cmda_dly_step:
                        cmda_dly -= recover_cmda_dly_step
                    else:
                        cmda_dly += recover_cmda_dly_step
                    if quiet <4:
                        print("*** FAILED to read data in write levelling mode, restarting memory device")
                        print("    old cmda_odelay= 0x%x, new cmda_odelay =0x%x"%(cmda_dly_old,cmda_dly))
                    self.x393_mcntrl_timing.axi_set_cmda_odelay(cmda_dly,quiet=quiet)
                    self.x393_pio_sequences.restart_ddr3()
                    wlev_rslt=self.x393_pio_sequences.write_levelling(1, quiet)
                    if wlev_rslt[2]>wlev_max_bad: # should be 0, if not - change delay and restart memory
                        raise Exception("Failed to read in write levelling mode after modifying cmda_odelay, aborting")
                    
# Try twice step before giving up (was not needed so far)                    
            d_high=max_lin_dly
            self.x393_mcntrl_timing.axi_set_address_odelay(
                                                           self.combine_delay(d_high),
                                                           wlev_address_bit,
                                                           quiet=quiet)
            wlev_rslt=self.x393_pio_sequences.write_levelling(1, quiet+1)
            if not wlev_rslt[2]>wlev_max_bad:
                return  (self.split_delay(cmda_dly),-1) # even maximal delay is not enough to make rising sdclk separate command from A7
            # find marginal value of a7 delay to spoil write levelling mode
            d_high=max_lin_dly
            d_low=cmda_dly_lin
            while d_high > d_low:
                dly= (d_high + d_low)//2
                self.x393_mcntrl_timing.axi_set_address_odelay(self.combine_delay(dly),wlev_address_bit,quiet=quiet)
                wlev_rslt=self.x393_pio_sequences.write_levelling(1, quiet+1)
                if wlev_rslt[2] > wlev_max_bad:
                    d_high=dly
                else:
                    if d_low == dly:
                        break
                    d_low=dly
            self.x393_mcntrl_timing.axi_set_cmda_odelay(cmda_dly,quiet=quiet)
            return (self.split_delay(cmda_dly),d_low)
               
        dly_steps=self.x393_mcntrl_timing.get_dly_steps()
        if quiet<1:
            print (dly_steps)
        numPhaseSteps= int(dly_steps['SDCLK_PERIOD']/dly_steps['PHASE_STEP']+0.5)
        if (start_phase+numPhaseSteps)>128:
            old_start_phase=start_phase
            while (start_phase+numPhaseSteps)>128:
                start_phase -= numPhaseSteps
            print("Selected scan phase range (%d..%d) does not fit into -128..+127, changing it to %d..%d)"%
                  (old_start_phase,old_start_phase+numPhaseSteps-1,start_phase,start_phase+numPhaseSteps-1))
#start_phase
        cmda_marg_dly=[None]*numPhaseSteps
        cmda_dly=0
        safe_early=self.split_delay(recover_cmda_dly_step)/2
#        print ("safe_early=%d(0x%x), recover_cmda_dly_step=%d(0x%x)"%(safe_early,safe_early,recover_cmda_dly_step,recover_cmda_dly_step))
        if reinits>0:
            self.x393_pio_sequences.restart_ddr3()

        for phase in range(start_phase,start_phase+numPhaseSteps):
            if quiet <3:
                print ("%d:"%(phase),end=" ")
                sys.stdout.flush()
            elif quiet < 5:
                print (".",end="")
                sys.stdout.flush()
            phase_mod=phase % numPhaseSteps
            dlys= phase_step(phase,cmda_dly)
            cmda_marg_dly[phase_mod]=dlys # [1] # Marginal delay or -1
            cmda_dly = self.combine_delay(dlys[0]) # update if it was modified during recover
            # See if cmda_odelay is dangerously close - increase it (and re-init?)
            if dlys[1]<0:
                if quiet <3:
                    print ("X",end=" ")
                    sys.stdout.flush()
                elif quiet < 5:
                    print (".",end="")
                    sys.stdout.flush()
                if reinits > 1: #re-init each time failed to find delay
                    if quiet <3:
                        print ("\nFailed to find marginal odelay for A7 - re-initializing DDR3 with odelay=0x%x",cmda_dly)
                    self.x393_mcntrl_timing.axi_set_cmda_odelay(cmda_dly,quiet=quiet)
                    self.x393_pio_sequences.restart_ddr3()
            else:
                if quiet <3:
                    print ("%d"%dlys[1],end=" ")
                    sys.stdout.flush()
                elif quiet < 5:
                    print (".",end="")
                    sys.stdout.flush()
                lin_dly=self.split_delay(cmda_dly)
                if (dlys[1]-lin_dly) < safe_early:
                    if (lin_dly > 0):
                        lin_dly=max(0,lin_dly-2*safe_early)
                if (dlys[1]-lin_dly) < safe_early:
                    lin_dly=min(max_lin_dly,lin_dly+2*safe_early) # or just add safe_early to dlys[1]?
                
                if lin_dly != self.split_delay(cmda_dly):   
                    cmda_dly=self.combine_delay(lin_dly)
                    self.x393_mcntrl_timing.axi_set_cmda_odelay(cmda_dly,quiet=quiet)
                    if reinits > 0: #re-init each time failed to find delay
                        if quiet <3:
                            print ("\nMeasured marginal delay for A7 is too close to cmda_odelay,re-initializing DDR3 with odelay=0x%x"%cmda_dly)
                        self.x393_pio_sequences.restart_ddr3()
            

        if quiet <2:
            for i,d in enumerate(cmda_marg_dly):
                print ("%d %d %d"%(i, d[0], d[1]))
        elif quiet < 5:
                print ()
        #find the largest positive step of cmda_marg_dly while cyclically increasing phase
        numValid=0
        for i,d in enumerate(cmda_marg_dly):
            if d[1]>0:
                numValid += 1
        if numValid < 2:
            raise Exception("Too few points with measured marginal CMDA odelay: %d"%numValid)
        maxPosSep=0
        firstIndex=None
        for i,d in enumerate(cmda_marg_dly):
            if d[1]>0:
                for j in range(1,numPhaseSteps):
                    d1=cmda_marg_dly[(i + j) % numPhaseSteps][1]
                    if d1 >= 0: # valid data
                        if (d1 - d[1]) > maxPosSep:
                            maxPosSep = d1 - d[1]
                            firstIndex=(i + j) % numPhaseSteps
                        break;
        #now data from  firstIndex to (firstIndex+numPhaseSteps)%numPhaseSteps is ~monotonic - apply linear approximation
        if quiet <2:
            print ("firstIndex=%d"%(firstIndex))
        
        S0=0
        SX=0
        SY=0
        SX2=0
        SXY=0
        for x in range(numPhaseSteps):
            y=cmda_marg_dly[(x+firstIndex) % numPhaseSteps][1]
            if y>=0:
                y+=0.5
                S0+=1
                SX+=x
                SY+=y
                SX2+=x*x
                SXY+=x*y
#            print("x=%f, index=%d, y=%f, S0=%f, SX=%f, SY=%f, SX2=%f, SXY=%f"%(x, (x+firstIndex) % numPhaseSteps, y, S0, SX, SY, SX2, SXY))
        a = (SXY*S0 - SY*SX) / (SX2*S0 - SX*SX)
        b = (SY*SX2 - SXY*SX) / (SX2*S0 - SX*SX)
        if quiet < 2:
            print ("a=%f, b=%f"%(a,b))
        # fine delay corrections
        fineCorr= [0.0]*5
        fineCorrN=[0]*5
        for x in range(numPhaseSteps):
            y=cmda_marg_dly[(x+firstIndex) % numPhaseSteps][1]
            if (y>0):
                i=y % 5
                y+=0.5
                diff=y- (a * x + b)
                fineCorr[i]  += diff
                fineCorrN[i] += 1
        for i in range(5):
            if fineCorrN[i]>0:
                fineCorr[i]/=fineCorrN[i]
        if (quiet <2):
            print ("fineCorr = %s"%str(fineCorr))
            
        variantStep=-a*numPhaseSteps #how much b changes when moving over the full SDCLK period
        if (quiet <2):
            print ("Delay matching the full SDCLK period = %f"%(variantStep))
        b-=a*firstIndex # recalculate b for phase=0
        b_period=0
        if (quiet <2):
            print ("a=%f, b=%f"%(a,b))
        #Make b fit into 0..max_lin_dly range
        while (b>max_lin_dly):
            b-=variantStep
            b_period-=1
        while (b<0):
            b+=variantStep # can end up having b>max_lin_dly - if the phase adjust by delay is lower than full period
            b_period+=1
        if (quiet <2):
            print ("a=%f, b=%f, b_period=%d"%(a,b,b_period))

        # Find best minimal delay (with higher SDCLK frequency delay range can exceed the period and there could
        # be more than one solution
        bestSolPerErr=[] #list ot tuples, each containing(best cmda_odelay,number of added periods,error)  
        max_dly_err=abs(a)*max_phase_err*numPhaseSteps # maximal allowed delay error (in 160-step scale)
        if (quiet <2):
            print("Max dly error=%f"%(max_dly_err))
        for phase in range (numPhaseSteps):
            periods=0 # b_period
            y=a*phase+b
            y0=y
            #find the lowest approximate solution to consider
            if y0 > (-max_dly_err):
                while (y0 >= (variantStep-max_dly_err)):
                    y0 -= variantStep
                    periods -= 1
            else:
                while (y0<(-max_dly_err)):
                    y0 += variantStep
                    periods += 1
            dly_min= max(0,int(y0-4.5))
            dly_max= min(max_lin_dly,int(y0+5.5))
            dly_to_try=[]
            for d in range(dly_min,dly_max+1):
                dly_to_try.append((d,periods))
            if (y0<0): # add a second range to try (higher delay values
                y0+=variantStep
                periods += 1
                dly_min= max(0,int(y0-4.5))
                dly_max= min(max_lin_dly,int(y0+5.5))
                for d in range(dly_min,dly_max+1):
                    dly_to_try.append((d,periods))
            bestDly=None
            bestDiff=None
            bestPeriods=None
            for dp in dly_to_try:
                actualDelay=dp[0]-fineCorr[dp[0] % 5] # delay corrected for the non-uniform 160-scale
                diff=actualDelay-(y+variantStep*dp[1]) # dp[1] - number of added/removed full periods
                if (bestDiff is None) or (abs(bestDiff) > abs(diff)):
                    bestDiff = diff
                    bestDly =  dp[0]
                    bestPeriods= dp[1]
            phase_rslt=() #Default, if nothing was found
            if not bestDiff is None:
                phase_rslt=(bestDly,bestPeriods,bestDiff)
            if (quiet <2):
                print ("%d: %s %s"%(phase, str(dly_to_try), str(phase_rslt)) )
            
            bestSolPerErr.append(phase_rslt)
        if (quiet <2):
            for i in range(numPhaseSteps): # enumerate(cmda_marg_dly):
                d=cmda_marg_dly[i]
                print ("%d %d %d"%(i, d[0], d[1]),end=" ")
                if (bestSolPerErr[i]):
                    print("%d %d %f"%(bestSolPerErr[i][0],bestSolPerErr[i][1],bestSolPerErr[i][2]))
                else:
                    print()

#numPhaseSteps            
        #Add 180 dwegree shift (move cmda_odelay to EARLY of the marginal
        period_shift=0
        b_center= b- 0.5*variantStep
        if b_center < 0: # have to move late
            b_center+=variantStep
            period_shift+=1
        cmda_dly_per_err=[]
        for phase in range (numPhaseSteps):
            marg_phase=(phase+numPhaseSteps//2) % numPhaseSteps
            extra_periods=(phase+numPhaseSteps//2) // numPhaseSteps
            bspe= bestSolPerErr[marg_phase]
            if bspe:
                cmda_dly_per_err.append({'ldly':bspe[0],
                                         'period':bspe[1]+period_shift+extra_periods+b_period, # b_period - shift from the branch
                                                                  # where phase starts from the longest cmda_odelay and goes down
                                         'err':bspe[2]})
            else:
                cmda_dly_per_err.append({}) # No solution for this phase value
        rdict={"cmda_odly_a":a,
               "cmda_odly_b":b_center,
               "cmda_odly_period":period_shift+b_period, # 
               "cmda_fine_corr":fineCorr,
               "cmda_bspe":cmda_dly_per_err}
        if (quiet <3):
            print("\ncmda_odelay adjustmet results:")
            print('cmda_odly_a:      %f'%(rdict['cmda_odly_a']))
            print('cmda_odly_b:      %f'%(rdict['cmda_odly_b']))
            print('cmda_odly_period: %d'%(rdict['cmda_odly_period']))
            print('cmda_fine_corr:   %s'%(rdict['cmda_fine_corr']))
            print("\nPhase DLY0 MARG_A7 CMDA PERIODS*10 ERR*10")
            for i in range(numPhaseSteps): # enumerate(cmda_marg_dly):
                d=cmda_marg_dly[i]
                print ("%d %d %d"%(i, d[0], d[1]),end=" ")
                if (rdict['cmda_bspe'][i]):
                    print("%d %d %f"%(rdict['cmda_bspe'][i]['ldly'],10*rdict['cmda_bspe'][i]['period'],10*rdict['cmda_bspe'][i]['err']))
                else:
                    print()
#TODO: Add 180 shift to get center, not marginal cmda_odelay        
        self.adjustment_state.update(rdict)
        if (quiet <3):
            print ("rdict={")
            for k,v in rdict.items():
                print("'%s':%s,"%(k,str(v)))
            print ("}")
        return rdict
        
    def adjust_write_levelling(self,
                               start_phase=0,
                               reinits=1, #higher the number - more re-inits are used (0 - only where absolutely necessary
                               invert=0, # anti-align DQS (should be 180 degrees off from the normal one)
                               max_phase_err=0.1,
                               quiet=1
                               ):
        """
        Find DQS output delay for each phase value
        Depends on adjust_cmda_odelay results
        """
        try:
            self.adjustment_state['cmda_bspe']
        except:
            raise Exception("Command/Address delay calibration data is not found - please run 'adjust_cmda_odelay' command first")
        start_phase &= 0xff
        if start_phase >=128:
            start_phase -= 256 # -128..+127
        max_lin_dly=NUM_DLY_STEPS-1
        wlev_max_bad=0.01 # <= OK, > bad
        numPhaseSteps=len(self.adjustment_state['cmda_bspe'])
        if quiet < 2:
            print("cmda_bspe = %s"%str(self.adjustment_state['cmda_bspe']))
            print ("numPhaseSteps=%d"%(numPhaseSteps))
        def wlev_phase_step (phase):
            def norm_wlev(wlev): #change results to invert wlev data
                if invert:
                    return [1.0-wlev[0],1.0-wlev[1],wlev[2]]
                else:
                    return wlev
            dly90=int(0.25*numPhaseSteps*abs(self.adjustment_state['cmda_odly_a']) + 0.5) # linear delay step ~ SDCLK period/4
            cmda_odly_data=self.adjustment_state['cmda_bspe'][phase % numPhaseSteps]
            if (not cmda_odly_data): # phase is invalid for CMDA
                return None
            cmda_odly_lin=cmda_odly_data['ldly']
            self.x393_mcntrl_timing.axi_set_phase(phase,quiet=quiet)
            self.x393_mcntrl_timing.axi_set_cmda_odelay(self.combine_delay(cmda_odly_lin),quiet=quiet)
            d_low=0
            while d_low <= max_lin_dly:
                self.x393_mcntrl_timing.axi_set_dqs_odelay(self.combine_delay(d_low),quiet=quiet)
                wlev_rslt=norm_wlev(self.x393_pio_sequences.write_levelling(1, quiet+1))
                if wlev_rslt[2]>wlev_max_bad: # should be 0 - otherwise wlev did not work (CMDA?)
                    raise Exception("Write levelling gave unespected data, aborting (may be wrong command/address delay, incorrectly initializaed")
                if (wlev_rslt[0] <= wlev_max_bad) and (wlev_rslt[1] <= wlev_max_bad):
                    break
                d_low+=dly90
            else:
                if quiet < 3:
                    print ("Failed to find d_low during initial quadrant search for phase=%d (0x%x)"%(phase,phase))
                return None
            # Now find d_high>d_low to get both bytes result above
            d_high= d_low+dly90   
            while d_high <= max_lin_dly:
                self.x393_mcntrl_timing.axi_set_dqs_odelay(self.combine_delay(d_high),quiet=quiet)
                wlev_rslt=norm_wlev(self.x393_pio_sequences.write_levelling(1, quiet+1))
                if wlev_rslt[2]>wlev_max_bad: # should be 0 - otherwise wlev did not work (CMDA?)
                    raise Exception("Write levelling gave unespected data, aborting (may be wrong command/address delay, incorrectly initializaed")
                if (wlev_rslt[0] >= (1.0 -wlev_max_bad)) and (wlev_rslt[1] >= (1.0-wlev_max_bad)):
                    break
                d_high+=dly90
            else:
                if quiet < 3:
                    print ("Failed to find d_high during initial quadrant search for phase=%d (0x%x)"%(phase,phase))
                return None
            # Narrow range while both bytes fit
            if quiet < 2:
                print ("After quadrant adjust d_low=%d, d_high=%d"%(d_low,d_high))
            
            while d_high > d_low:
                dly= (d_high + d_low)//2
                self.x393_mcntrl_timing.axi_set_dqs_odelay(self.combine_delay(dly),quiet=quiet)
                wlev_rslt=norm_wlev(self.x393_pio_sequences.write_levelling(1, quiet+1))
                if wlev_rslt[2]>wlev_max_bad: # should be 0 - otherwise wlev did not work (CMDA?)
                    raise Exception("Write levelling gave unespected data, aborting (may be wrong command/address delay, incorrectly initializaed")
                if (wlev_rslt[0] <= wlev_max_bad) and (wlev_rslt[1] <= wlev_max_bad):
                    if d_low == dly:
                        break
                    d_low=dly
                elif (wlev_rslt[0] >= (1.0 -wlev_max_bad)) and (wlev_rslt[1] >= (1.0-wlev_max_bad)):
                    d_high=dly
                else:
                    break #mixed results
            # Now process each byte separately
            if quiet < 2:
                print ("After common adjust d_low=%d, d_high=%d"%(d_low,d_high))
            d_low=[d_low,d_low]
            d_high=[d_high,d_high]
            for i in range(2):
                while d_high[i] > d_low[i]: 
                    dly= (d_high[i] + d_low[i])//2
                    if quiet < 1:
                        print ("i=%d, d_low=%d, d_high=%d, dly=%d"%(i,d_low[i],d_high[i],dly))
                    dly01=[d_low[0],d_low[1]]
                    dly01[i]=dly
                    self.x393_mcntrl_timing.axi_set_dqs_odelay(self.combine_delay(dly01),quiet=quiet)
                    wlev_rslt=norm_wlev(self.x393_pio_sequences.write_levelling(1, quiet+1))
                    if wlev_rslt[2]>wlev_max_bad: # should be 0 - otherwise wlev did not work (CMDA?)
                        raise Exception("Write levelling gave unespected data, aborting (may be wrong command/address delay, incorrectly initializaed")
                    if wlev_rslt[i] <= wlev_max_bad:
                        if d_low[i] == dly:
                            break
                        d_low[i]=dly
                    else:
                        d_high[i]=dly
            return d_low

        if (start_phase+numPhaseSteps)>128:
            old_start_phase=start_phase
            while (start_phase+numPhaseSteps)>128:
                start_phase -= numPhaseSteps
            print("Selected scan phase range (%d..%d) does not fit into -128..+127, changing it to %d..%d)"%
                  (old_start_phase,old_start_phase+numPhaseSteps-1,start_phase,start_phase+numPhaseSteps-1))
#start_phase
        if reinits > 1: # Normally not needed (When started after adjust_cmda_odelay, but refresh should be off (init will do that)
            self.x393_pio_sequences.restart_ddr3()
        wlev_dqs_delays=[None]*numPhaseSteps
        
        for phase in range(start_phase,start_phase+numPhaseSteps):
            phase_mod=phase % numPhaseSteps
            if quiet <3:
                print ("%d(%d):"%(phase,phase_mod),end=" ")
                sys.stdout.flush()
            elif quiet < 5:
                print (".",end="")
                sys.stdout.flush()
            dlys=wlev_phase_step(phase)
            wlev_dqs_delays[phase_mod]=dlys
            if quiet <3:
                print ("%s"%str(dlys),end=" ")
                sys.stdout.flush()
            elif quiet < 5:
                print (".",end="")
                sys.stdout.flush()
            if quiet< 2:
                print()
                
        if quiet <2:
            for i,d in enumerate(wlev_dqs_delays):
                if d:
                    print ("%d %d %d"%(i, d[0], d[1]))
                else:
                    print ("%d"%(i))
        elif quiet < 5:
            print ()
            
        #find the largest positive step of cmda_marg_dly while cyclically increasing phase
        numValid=0
        for i,d in enumerate(wlev_dqs_delays):
            if d:
                numValid += 1
        if numValid < 2:
            raise Exception("Too few points with DQS output delay in write levelling mode: %d"%numValid)

        firstIndex=[None]*2
        for lane in range(2):
            maxPosSep=0
            for i,d in enumerate(wlev_dqs_delays):
                if d>0:
                    for j in range(1,numPhaseSteps):
                        d1=wlev_dqs_delays[(i + j) % numPhaseSteps]
                        if d1: # valid data
                            if (d1[lane] - d[lane]) > maxPosSep:
                                maxPosSep = d1[lane] - d[lane]
                                firstIndex[lane]=(i + j) % numPhaseSteps
                            break;
        #now data from  firstIndex to (firstIndex+numPhaseSteps)%numPhaseSteps is ~monotonic - apply linear approximation
        if quiet <2:
            print ("firstIndices=[%d,%d]"%(firstIndex[0],firstIndex[1]))
        #Linear approximate each lane
        a=[None]*2
        b=[None]*2
        for lane in range(2):
            S0=0
            SX=0
            SY=0
            SX2=0
            SXY=0
            for x in range(numPhaseSteps):
                dlys=wlev_dqs_delays[(x+firstIndex[lane]) % numPhaseSteps]
                if dlys:
                    y=dlys[lane]+0.5
                    S0+=1
                    SX+=x
                    SY+=y
                    SX2+=x*x
                    SXY+=x*y
    #            print("x=%f, index=%d, y=%f, S0=%f, SX=%f, SY=%f, SX2=%f, SXY=%f"%(x, (x+firstIndex) % numPhaseSteps, y, S0, SX, SY, SX2, SXY))
            a[lane] = (SXY*S0 - SY*SX) / (SX2*S0 - SX*SX)
            b[lane] = (SY*SX2 - SXY*SX) / (SX2*S0 - SX*SX)
        if quiet < 2:
            print ("a=[%f, %f], b=[%f, %f]"%(a[0],a[1],b[0],b[1]))

        # fine delay corrections
        fineCorr= [[0.0]*5,[0.0]*5] # not [[0.0]*5]*2 ! - they will poin to the same top element 
        fineCorrN=[[0]*5,[0]*5]     # not [[0]*5]*2 !
        for lane in range(2):
            for x in range(numPhaseSteps):
                dlys=wlev_dqs_delays[(x+firstIndex[lane]) % numPhaseSteps]
                if dlys:
                    y=dlys[lane]
                    i=y % 5
                    y+=0.5
                    diff=y- (a[lane] * x + b[lane])
                    fineCorr[lane][i]  += diff
                    fineCorrN[lane][i] += 1
#                    print("lane,x,y,i,diff,fc,fcn= %d, %d, %f, %d, %f, %f, %d"%(lane,x,y,i,diff,fineCorr[lane][i],fineCorrN[lane][i]))
#            print ("lane=%d, fineCorr=%s, fineCorrN=%s"%(lane, fineCorr[lane], fineCorrN[lane]))
            for i in range(5):
                if fineCorrN[lane][i]>0:
                    fineCorr[lane][i]/=fineCorrN[lane][i]
#            print ("lane=%d, fineCorr=%s, fineCorrN=%s"%(lane, fineCorr[lane], fineCorrN[lane]))
                    
        if (quiet <2):
            print ("fineCorr lane0 = %s"%str(fineCorr[0])) # Why ar they both the same?
            print ("fineCorr lane1 = %s"%str(fineCorr[1]))
        variantStep=[-a[0]*numPhaseSteps,-a[1]*numPhaseSteps] #how much b changes when moving over the full SDCLK period
        if (quiet <2):
            print ("Delay matching the full SDCLK period = [%f, %f]"%(variantStep[0],variantStep[1]))
        b_period=[None]*2
        for lane in range(2):
            b[lane]-=a[lane]*firstIndex[lane] # recalculate b for phase=0
            b_period[lane]=0
            if (quiet <2):
                print ("a[%d]=%f, b[%d]=%f"%(lane,a[lane],lane,b[lane]))
            #Make b fit into 0..max_lin_dly range
            while (b[lane] > max_lin_dly):
                b[lane]-=variantStep[lane]
                b_period[lane]-=1
            while (b[lane] < 0):
                b[lane] += variantStep[lane] # can end up having b>max_lin_dly - if the phase adjust by delay is lower than full period
                b_period[lane] += 1
        if (quiet <2):
            print ("a[0]=%f, b[0]=%f, b_period[0]=%d"%(a[0],b[0],b_period[0]))
            print ("a[1]=%f, b[1]=%f, b_period[1]=%d"%(a[1],b[1],b_period[1]))
            
        # Find best minimal delay (with higher SDCLK frequency delay range can exceed the period and there could
        # be more than one solution
        bestSolPerErr=[[],[]] # pair (for two lanes) of lists ot tuples, each containing(best cmda_odelay,number of added periods,error)
        max_dly_err=[abs(a[0])*max_phase_err*numPhaseSteps, # maximal allowed delay error (in 160-step scale)
                     abs(a[1])*max_phase_err*numPhaseSteps]
        if (quiet <2):
            print("Max dly error=%s"%(str(max_dly_err)))
        for lane in range(2):
            for phase in range (numPhaseSteps):
                periods=0 # b_period[lane]
                y=a[lane]*phase+b[lane]
                y0=y
                #find the lowest approximate solution to consider
                if y0 > (-max_dly_err[lane]):
                    while (y0 >= (variantStep[lane]-max_dly_err[lane])):
                        y0 -= variantStep[lane]
                        periods -= 1
                else:
                    while (y0<(-max_dly_err[lane])):
                        y0 += variantStep[lane]
                        periods += 1
                dly_min= max(0,int(y0-4.5))
                dly_max= min(max_lin_dly,int(y0+5.5))
                dly_to_try=[]
                for d in range(dly_min,dly_max+1):
                    dly_to_try.append((d,periods))
                if (y0<0): # add a second range to try (higher delay values
                    y0+=variantStep[lane]
                    periods += 1
                    dly_min= max(0,int(y0-4.5))
                    dly_max= min(max_lin_dly,int(y0+5.5))
                    for d in range(dly_min,dly_max+1):
                        dly_to_try.append((d,periods))
                bestDly=None
                bestDiff=None
                bestPeriods=None
                for dp in dly_to_try:
                    actualDelay=dp[0]-fineCorr[lane][dp[0] % 5] # delay corrected for the non-uniform 160-scale
                    diff=actualDelay-(y+variantStep[lane]*dp[1]) # dp[1] - number of added/removed full periods
                    if (bestDiff is None) or (abs(bestDiff) > abs(diff)):
                        bestDiff = diff
                        bestDly =  dp[0]
                        bestPeriods= dp[1]
                phase_rslt=() #Default, if nothing was found
                if not bestDiff is None:
                    phase_rslt=(bestDly,bestPeriods,bestDiff)
                if (quiet <2):
                    print ("%d:%d: %s %s"%(lane, phase, str(dly_to_try), str(phase_rslt)) )
                
                bestSolPerErr[lane].append(phase_rslt)
        if (quiet <2):
            for i in range(numPhaseSteps): # enumerate(cmda_marg_dly):
                d=wlev_dqs_delays[i]
                if d:
                    print ("%d %d %d"%(i, d[0], d[1]),end=" ")
                else:
                    print ("%d X X"%(i),end=" ")
                for lane in range(2):
                    bspe=bestSolPerErr[lane][i]
                    if bspe:
                        print("%d %d %f"%(bspe[0], bspe[1], bspe[2]),end=" ")
                    else:
                        print("X X X",end=" ")
                print()
        wlev_bspe=[[],[]]
        for lane in range (2):
            for phase in range (numPhaseSteps):
                bspe=bestSolPerErr[lane][phase]
                if bspe:
                    wlev_bspe[lane].append({'ldly':bspe[0],
                                             'period':bspe[1]+b_period[lane], # b_period - shift from the branch
                                                                        # where phase starts from the longest cmda_odelay and goes down
                                             'err':bspe[2]})
                else:
                    wlev_bspe[lane].append({})
                
        rdict={"wlev_dqs_odly_a":    a, #[,]
               "wlev_dqs_odly_b":    b,#[,]
               "wlev_dqs_period":    b_period, # 
               "wlev_dqs_fine_corr": fineCorr,
               "wlev_dqs_bspe":      wlev_bspe}
        if (quiet <3):
            print("\nwrite levelling DQS output delay adjustmet results:")
            print('wlev_dqs0_odly_a:    %f'%(rdict['wlev_dqs_odly_a'][0]))
            print('wlev_dqs1_odly_a:    %f'%(rdict['wlev_dqs_odly_a'][1]))
            print('wlev_dqs0_odly_b:    %f'%(rdict['wlev_dqs_odly_b'][0]))
            print('wlev_dqs1_odly_b:    %f'%(rdict['wlev_dqs_odly_b'][1]))
            print('wlev_dqs0_period:    %d'%(rdict['wlev_dqs_period'][0]))
            print('wlev_dqs1_period:    %d'%(rdict['wlev_dqs_period'][1]))
            print('wlev_dqs0_fine_corr: %s'%(rdict['wlev_dqs_fine_corr'][0]))
            print('wlev_dqs1_fine_corr: %s'%(rdict['wlev_dqs_fine_corr'][1]))
            print("\nPhase Measured_DQS0 Measured_DQS1 DQS0 PERIODS0*10 ERR0*10 DQS1 PERIODS1*10 ERR1*10")
            for i in range(numPhaseSteps): # enumerate(cmda_marg_dly):
                d=wlev_dqs_delays[i]
                if d:
                    print ("%d %d %d"%(i, d[0], d[1]),end=" ")
                else:
                    print ("%d X X"%(i),end=" ")
                for lane in range(2):
                    bspe=rdict['wlev_dqs_bspe'][lane][i] # bestSolPerErr[lane][i]
                    if bspe:
                        print("%d %d %f"%(bspe['ldly'], 10*bspe['period'], 10*bspe['err']),end=" ")
                    else:
                        print("X X X",end=" ")
                print()
                            
        self.adjustment_state.update(rdict)
        if (quiet <3):
            print ("rdict={")
            for k,v in rdict.items():
                print("'%s':%s,"%(k,str(v)))
            print ("}")
        return rdict
          
    def measure_pattern(self,
                       compare_prim_steps=True, # while scanning, compare this delay with 1 less by primary(not fine) step,
                                                # save None for fraction in unknown (previous -0.5, next +0.5) 
                       limit_step=0.125, # initial delay step as a fraction of the period
                       max_phase_err=0.1,
                       quiet=1,
                       start_dly=0): #just to check dependence
        """
        for each DQS input delay find 4 DQ transitions for each DQ bit,
        then use them to find finedelay for each of the DQS and DQ,
        linear coefficients (a,b) for each DQ vs DQS and asymmetry
        (late 0->1, early 1->0) for each of the DQ and DQS
        @param quiet reduce output

        """
        nrep=8
        max_lin_dly=NUM_DLY_STEPS-1#159
        timing=self.x393_mcntrl_timing.get_dly_steps()
        #steps={'DLY_FINE_STEP': 0.01, 'DLY_STEP': 0.078125, 'PHASE_STEP': 0.022321428571428572, 'SDCLK_PERIOD': 2.5}
        dly_step=int(NUM_FINE_STEPS*limit_step*timing['SDCLK_PERIOD']/timing['DLY_STEP']+0.5)
        step180= int(NUM_FINE_STEPS*0.5* timing['SDCLK_PERIOD'] / timing['DLY_STEP'] +0.5)                                                                                                                                                                                                                 
        if quiet<2:
            print ("timing)=%s, dly_step=%d step180=%d"%(str(timing),dly_step,step180))
        self.x393_pio_sequences.set_read_pattern(nrep+3) # set sequence once
        
        def patt_dqs_step(dqs_lin):
            patt_cache=[None]*(max_lin_dly+1) # cache for holding already measured delays
            def measure_patt(dly,force_meas=False):
                if (patt_cache[dly] is None) or force_meas:
                    self.x393_mcntrl_timing.axi_set_dq_idelay(self.combine_delay(dly),quiet=quiet)
                    patt= self.x393_pio_sequences.read_levelling(nrep,
                                                                 -1, # sel=1, # 0 - early, 1 - late read command (shift by a SDCLK period), -1 - use current sequence 
                                                                 quiet+1)
                    patt_cache[dly]=patt
                    if quiet < 1:
                        print ('measure_patt(%d,%s) - new measurement'%(dly,str(force_meas)))
                else:
                    patt=patt_cache[dly]
                    if quiet < 1:
                        print ('measure_patt(%d,%s) - using cache'%(dly,str(force_meas)))
                return patt
            def get_sign(data,edge=None):
                """
                edge: 0 - first 16, 1 - second 16
                return -1 if  all <0.5
                return +1 if all >0.5
                return 0 otherwise
                """
                if edge == 0:
                    return get_sign(data[:16])
                if edge == 1:
#                    return -get_sign(data[16:])
                    return get_sign(data[16:])
                m1=True
                p1=True
                for d in data:
                    m1 &= (d < 0.5)
                    p1 &= (d > 0.5)
                    if not (m1 or p1):
                        break
                else:
                    if m1:
                        return -1
                    elif p1:
                        return 1
                return 0
            
            rslt=[None]*16 # each bit will have [inphase][dqs_falling]
            self.x393_mcntrl_timing.axi_set_dqs_idelay(self.combine_delay(dqs_lin),quiet=quiet)
            d_low=[None]*2  # first - lowest when all are -+, second - when all are +-  
            d_high=[None]*2 # first - when all are +- after -+, second - when all are -+ after +-
            dly=0
            notLast=True
            needSigns=None
            lowGot=None
            highGot=None
            while (dly <= max_lin_dly) and notLast:
                notLast= dly < max_lin_dly
                patt=measure_patt(dly) # ,force_meas=False)
                signs=(get_sign(patt,0),get_sign(patt,1))
                if quiet < 1:
                    print ('dly=%d lowGot=%s, highGot=%s, signs=%s'%(dly,str(lowGot),str(highGot),str(signs)))
                if lowGot is None : # looking for the first good sample
                    if (signs==(-1,1)) or  (signs==(1,-1)) :
                        if signs[0] == -1: #  == (-1,1):
                            lowGot=0
                        else:
                            lowGot=1
                        d_low[lowGot] = dly
                        needSigns=((1,-1),(-1,1))[lowGot]
                        dly += step180-dly_step # almost 180 degrees
                    else: # at least one is 0
                        dly += dly_step # small step
                    if quiet < 1:
                        print ('lowGot was None : dly=%d, lowGot=%s, needSigns=%s'%(dly,str(lowGot),str(needSigns)))
                elif highGot is None : # only one good sample is available so far
                    if signs == needSigns:
                        highGot=lowGot
                        d_high[highGot] = dly
                        d_low[1-lowGot] = dly
                        needSigns=((-1,1),(1,-1))[lowGot]
                        dly += step180-dly_step # almost 180 degrees
                    else:
                        dly += dly_step # small step
                    if quiet < 1:
                        print ('highGot was None : dly=%d, lowGot=%s, highGot=%s, needSigns=%s'%(dly,str(lowGot),str(lowGot),str(needSigns)))
                else: # looking for the 3-rd sample 
                    if signs == needSigns:
                        highGot=1-highGot
                        d_high[highGot] = dly
                        break
                    else:
                        dly += dly_step # small step
                dly = min (dly,max_lin_dly)
            if highGot is None:
                if quiet < 3:
                    print ("Could not find initial bounds for DQS input delay = %d d_low=%s, d_high=%s"%(dqs_lin,str(d_low),str(d_high)))
                return None
            if quiet < 2:
                    print ("DQS input delay = %d , preliminary bounds: d_low=%s, d_high=%s"%(dqs_lin,str(d_low),str(d_high)))
            for inPhase in range(2):
                if not d_high[inPhase] is None:
                    # Try to squeeze d_low, d_high closer to reduce scan range
                    while d_high[inPhase]>d_low[inPhase]:
                        dly=(d_high[inPhase] + d_low[inPhase])//2
                        patt=measure_patt(dly) # ,force_meas=False)
                        signs=(get_sign(patt,0),get_sign(patt,1))
                        if signs==(-1,1):
                            if inPhase:
                                d_high[inPhase]=dly 
                            else:
                                if d_low[inPhase]==dly:
                                    break
                                d_low[inPhase]=dly 
                        elif signs==(1,-1):     
                            if inPhase:
                                if d_low[inPhase]==dly:
                                    break
                                d_low[inPhase]=dly 
                            else:
                                d_high[inPhase]=dly 
                        else: # uncertain result 
                            break
            if quiet < 2:
                    print ("DQS input delay = %d , squeezed bounds: d_low=%s, d_high=%s"%(dqs_lin,str(d_low),str(d_high)))
#Improve squeezing - each limit to the last

            for inPhase in range(2):
                if not d_high[inPhase] is None:
                    # Try to squeeze d_low first
                    d_uncertain=d_high[inPhase]
                    while d_uncertain > d_low[inPhase]:
                        dly=(d_uncertain + d_low[inPhase])//2
                        patt=measure_patt(dly) # ,force_meas=False)
                        signs=(get_sign(patt,0),get_sign(patt,1))
                        if signs==(-1,1):
                            if inPhase:
                                d_uncertain=dly 
                            else:
                                if d_low[inPhase]==dly:
                                    break
                                d_low[inPhase]=dly 
                        elif signs==(1,-1):     
                            if inPhase:
                                if d_low[inPhase]==dly:
                                    break
                                d_low[inPhase]=dly 
                            else:
                                d_uncertain=dly 
                        else: # uncertain result
                            d_uncertain=dly
                    #now udjust upper limit
                    while d_high[inPhase] > d_uncertain:
                        dly=(d_high[inPhase] + d_uncertain)//2
                        patt=measure_patt(dly) # ,force_meas=False)
                        signs=(get_sign(patt,0),get_sign(patt,1))
                        if signs==(-1,1):
                            if inPhase:
                                d_high[inPhase]=dly 
                            else:
                                if d_uncertain==dly:
                                    break
                                d_uncertain=dly 
                        elif signs==(1,-1):     
                            if inPhase:
                                if d_uncertain==dly:
                                    break
                                d_uncertain=dly 
                            else:
                                d_high[inPhase]=dly 
                        else: # uncertain result 
                            if d_uncertain==dly:
                                break
                            d_uncertain=dly
            if quiet < 2:
                    print ("DQS input delay = %d , tight squeezed bounds: d_low=%s, d_high=%s"%(dqs_lin,str(d_low),str(d_high)))

                    
            # scan ranges, find closest solutions
            #compare_prim_steps
            best_dly= [[],[]]
            best_diff=[[],[]]
            for inPhase in range(2):
                if not d_high[inPhase] is None:
#                    patt=None
                    best_dly[inPhase]=[d_low[inPhase]]*32
                    best_diff[inPhase]=[None]*32
#                    for b,p in enumerate(patt):
#                        positiveJump=((not inPhase) and (b<16)) or (inPhase and (b >= 16)) # may be 0, False, True
#                        if positiveJump:
#                            best_diff[inPhase].append(p-0.5)
#                        else:
#                            best_diff[inPhase].append(0.5-p)
                    for dly in range(d_low[inPhase]+1,d_high[inPhase]+1):
#                        patt_prev=patt
                        #as measured data is cached, there is no need to specially maintain patt_prev from earlier measurement
                        dly_prev= max(0,dly-(1,NUM_FINE_STEPS)[compare_prim_steps])
                        patt_prev=measure_patt(dly_prev) # ,force_meas=False) - will be stored in cache
                        patt=     measure_patt(dly) # ,force_meas=False) - will be stored in cache
                        for b in range(32):
                            positiveJump=((not inPhase) and (b<16)) or (inPhase and (b >= 16)) # may be 0, False, True       
                            signs=((-1,1)[patt_prev[b]>0.5],(-1,1)[patt[b]>0.5])
                            if (positiveJump and (signs==(-1,1))) or (not positiveJump and (signs==(1,-1))):
                                if positiveJump:
                                    diffs_prev_this=(patt_prev[b]-0.5,patt[b]-0.5)
                                else:
                                    diffs_prev_this=(0.5-patt_prev[b],0.5-patt[b])
                                if abs(diffs_prev_this[0]) <= abs(diffs_prev_this[1]): # store previos sample
                                    if (best_diff[inPhase][b] is None) or (abs (diffs_prev_this[0])<abs(best_diff[inPhase][b])):
                                        best_dly[inPhase][b]=dly_prev # dly-1
                                        best_diff[inPhase][b]=diffs_prev_this[0]
                                        if quiet < 1:
                                            print ("*%d:%0.3f:%0.3f%s"%(b,diffs_prev_this[0],diffs_prev_this[1],str(signs)),end="")
                                else:
                                    if (best_diff[inPhase][b] is None) or (abs (diffs_prev_this[1])<abs(best_diff[inPhase][b])):
                                        best_dly[inPhase][b]=dly # dly-1
                                        best_diff[inPhase][b]=diffs_prev_this[1]
                                        if quiet < 1:
                                            print ("?%d:%0.3f:%0.3f%s"%(b,diffs_prev_this[0],diffs_prev_this[1],str(signs)),end="")
                        if quiet < 1:
                            print("\n dly=%d dly_prev=%d:"%(dly,dly_prev),end=" ")
                    for b in range(32):
                        if  best_diff[inPhase][b] == -0.5:
                            best_diff[inPhase][b] = None # will have to add half-interval (0.5 or 2.5) 
                # rslt=[None]*16 # each bit will have [inphase][dqs_falling], each - a pair of (delay,diff)
            for b in range(16):
                rslt[b]=[[None]*2,[None]*2] # [inphase][dqs_falling]
                for inPhase in range(2):
                    if not d_high[inPhase] is None:
                        rslt[b][inPhase]= [(best_dly[inPhase][b],best_diff[inPhase][b]),(best_dly[inPhase][b+16],best_diff[inPhase][b+16])]
            if quiet < 2:
                    print ("%d: rslt=%s"%(dqs_lin,str(rslt)))
            return rslt
#        meas_data=[]
#        for ldly in range(max_lin_dly+1):
#            if quiet <3:
#                print ("%d(0x%x):"%(ldly,self.combine_delay(ldly)),end=" ")
#                sys.stdout.flush()
#            meas_data.append(patt_dqs_step(ldly))
#        if quiet <3:
#            print ()
        # main method code
        meas_data=[None]*(max_lin_dly+1)
        #start_dly
        for sdly in range(max_lin_dly+1):
            ldly = (start_dly+sdly)%(max_lin_dly+1)
#        for ldly in range(max_lin_dly+1):
            if quiet <3:
                print ("%d(0x%x):"%(ldly,self.combine_delay(ldly)),end=" ")
                sys.stdout.flush()
            elif quiet < 5:
                print (".",end="")
                sys.stdout.flush()
            meas_data[ldly] = patt_dqs_step(ldly)
        if quiet < 5:
            print ()

        if quiet < 3:
            print("\n\nMeasured data, integer portion, measured with %s steps"%(("fine","primary")[compare_prim_steps]))
            print ("DQS",end=" ")
            for f in ('ir','if','or','of'):
                for b in range (16):
                    print ("%s_%d"%(f,b),end=" ")
            print()        
            for ldly, data in enumerate(meas_data):
                print("%d"%ldly,end=" ")
                if data:
                    for typ in ((0,0),(0,1),(1,0),(1,1)):
                        for pData in data: # 16 DQs, each None nor a pair of lists for inPhase in (0,1), each a pair of edges, each a pair of (dly,diff)
                            if pData:
                                if pData[typ[0]] and pData[typ[0]][typ[1]]:
                                    print ("%d"%pData[typ[0]][typ[1]][0],end=" ")
                                    '''
                                    try:
                                        print ("%d"%pData[typ[0]][typ[1]][0],end=" ")
                                    except:
                                        print (".", end=" ")
                                    '''
                                else:
                                    print ("?", end=" ")
                            else:
                                print ("x",end=" ")
                        
                print()
        if quiet < 2:
            print("\n\nMasked measured data, integer portion, measured with %s steps"%(("fine","primary")[compare_prim_steps]))
            for f in ('ir','if','or','of'):
                for b in range (16):
                    print ("%s_%d"%(f,b),end=" ")
            print()        
            for ldly, data in enumerate(meas_data):
                print("%d"%ldly,end=" ")
                if data:
                    for typ in ((0,0),(0,1),(1,0),(1,1)):
                        for pData in data: # 16 DQs, each None nor a pair of lists for inPhase in (0,1), each a pair of edges, each a pair of (dly,diff)
                            if pData:
                                if pData[typ[0]] and pData[typ[0]][typ[1]] and (not pData[typ[0]][typ[1]][1] is None):
                                    print ("%d"%pData[typ[0]][typ[1]][0],end=" ")
                                    '''
                                    try:
                                        print ("%d"%pData[typ[0]][typ[1]][0],end=" ")
                                    except:
                                        print (".", end=" ")
                                    '''
                                else:
                                    print ("?", end=" ")
                            else:
                                print ("x",end=" ")
                        
                print()
                    
        if quiet < 2:
            print ("\nDifferences from 0.5:")

            print ("DQS",end=" ")
            for f in ('ir','if','or','of'):
                for b in range (16):
                    print ("%s_%d"%(f,b),end=" ")
            print()        
            for ldly, data in enumerate(meas_data):
                print("%d"%ldly,end=" ")
                if data:
                    for typ in ((0,0),(0,1),(1,0),(1,1)):
                        for pData in data: # 16 DQs, each None nor a pair of lists for inPhase in (0,1), each a pair of edges, each a pair of (dly,diff)
                            if pData:
                                if pData[typ[0]] and pData[typ[0]][typ[1]] and (not pData[typ[0]][typ[1]][1] is None):
                                    print ("%.2f"%pData[typ[0]][typ[1]][1],end=" ")
                                    '''
                                    try:
                                        print ("%d"%pData[typ[0]][typ[1]][0],end=" ")
                                    except:
                                        print (".", end=" ")
                                    '''
                                else:
                                    print ("?", end=" ")
                            else:
                                print ("x",end=" ")
                        
                print()
        if quiet < 3:
            print("\n\nMeasured data, comparing current data with the earlier by one %s step"%(("fine","primary")[compare_prim_steps]))
            print("When the fractional (second in the tuple) data is exactly -0.5, the actual result is in the range %s from the integer delay"%
                  (("+0.0..+1.0","+0.0..+%d"%NUM_FINE_STEPS)[compare_prim_steps]))
            print ("meas_data=[")
            for d in meas_data:
                print("%s,"%(str(d)))
            print("]")
        rdict={"patt_prim_steps":    compare_prim_steps,
               "patt_meas_data":     meas_data} # TODO: May delete after LMA fitting
        self.adjustment_state.update(rdict)

    def measure_dqs_idly_phase(self,
                               compare_prim_steps = True, # while scanning, compare this delay with 1 less by primary(not fine) step,
                                                # save None for fraction in unknown (previous -0.5, next +0.5) 
                               frac_step=0.125,
                               sel=1,
                               quiet=1):
        """
        Scan phase and find DQS input delay value to find when
        the result changes (it is caused by crossing clock boundarty from extrenal memory device derived
        to system-synchronous one
        cmda_odelay should be already calibrated, refresh will be turned on.
        Uses random/previously written pattern in one memory block (should have some varying data
        @param quiet reduce output
        """
        
        try:
            dqi_dqsi=self.adjustment_state['dqi_dqsi']
        except:
            print ("No DQ IDELAY vs. DQS IDELAY data available, exiting")
            return
        # Mark DQS idelay values that have all DQ delays valid 
        dqsi_valid={} #[None]*NUM_DLY_STEPS
        for k,v in dqi_dqsi.items():
            if v:
                dqsi_valid[k]=[False]*NUM_DLY_STEPS
                for dly in range(NUM_DLY_STEPS):
                    if v[dly]:
                        for d in v[dly]:
                            if d is None:
                                break
                        else: # All values are not None
                            dqsi_valid[k][dly]=True
        if not dqsi_valid:
            print ("No Valid DQ IDELAY vs. DQS IDELAY data is available, exiting")
            return
        if quiet <1:
            print ('dqi_dqsi=%s'%(str(dqi_dqsi)))
            print("\n\n")
        if quiet <2:
            print ('dqsi_valid=%s'%(str(dqsi_valid)))
        dqsi_lohi={}
        for k,vdly in dqsi_valid.items():
            if quiet <2:
                print ("k='%s', vdly=%s"%(k,str(vdly)))
            for i,v in enumerate(vdly):
                if v:
                    low=i
                    break
            else:
                print ("Could not find valid data in dqsi_valid[%s]=%s"%(k,str(vdly)))
                continue
            for i in range(low+1,NUM_DLY_STEPS):
                if not vdly[i]:
                    high=i
                    break
            else:
                high= NUM_DLY_STEPS-1
            dqsi_lohi[k]=(low,high)       
        if quiet <2:
            print ('dqsi_valid=%s'%(str(dqsi_valid)))
        if quiet <3:
            print ('dqsi_lohi=%s'%(str(dqsi_lohi)))
         

        brc=(5,        # 3'h5,     # bank
             0x1234,   # 15'h1234, # row address
             0x100)     # 10'h100   # column address
        nrep=8 # number of 8-bursts to compare (actual will have 3 more, first/last will be discarded
        timing=self.x393_mcntrl_timing.get_dly_steps()
        #steps={'DLY_FINE_STEP': 0.01, 'DLY_STEP': 0.078125, 'PHASE_STEP': 0.022321428571428572, 'SDCLK_PERIOD': 2.5}
        dly_step=int(NUM_FINE_STEPS*frac_step*timing['SDCLK_PERIOD']/timing['DLY_STEP']+0.5)
        numPhaseSteps= int(timing['SDCLK_PERIOD']/timing['PHASE_STEP']+0.5)
        step180= int(NUM_FINE_STEPS*0.5* timing['SDCLK_PERIOD'] / timing['DLY_STEP'] +0.5)                                                                                                                                                                                                                 
        if quiet<2:
            print ("timing)=%s, dly_step=%d step180=%d"%(str(timing),dly_step,step180))
        self.x393_pio_sequences.set_read_block(*(brc+(nrep+3,sel))) # set sequence once
        #prepare writing block:
        wdata16=(0,0,0xffff,0xffff)*(2*(nrep+3)) # Data will have o/1 transitions in every bit, even if DQ_OPDELAY to DQS_OPDELAY is not yet adjusted
        wdata32=self.convert_mem16_to_w32(wdata16)
        self.x393_mcntrl_buffers.write_block_buf_chn(0,0,wdata32,quiet) # fill block memory (channel, page, number)
        self.x393_pio_sequences.set_write_block(*(brc+(nrep+3,0,sel))) # set sequence once
        cmda_bspe=self.adjustment_state['cmda_bspe']
        wlev_dqs_bspe=self.adjustment_state['wlev_dqs_bspe']
        for phase in range(numPhaseSteps):
            try:
                dqs_odelay=[wlev_dqs_bspe[lane][phase]['ldly'] for lane in range(len(wlev_dqs_bspe))]
                cmda_odelay=cmda_bspe[phase]['ldly']
                if (not None in dqs_odelay) and (not cmda_odelay is None):
                    break
            except:
                pass    
        else:
            raise Exception("BUG: could not find phase that has valid cmda_odelay and dqs_odelay")
        phase_ok=self.set_phase_with_refresh( # check result for not None
                           phase,
                           quiet)
        if not phase_ok:
            raise Exception("BUG: Failed set_phase_with_refresh(%s)"%(str(phase)))
        self.x393_mcntrl_timing.axi_set_dqs_odelay(self.combine_delay(dqs_odelay),quiet=quiet)
        self.x393_pio_sequences.write_block() #page= 0, wait_complete=1)

        
       
        
        
        def dqsi_phase_step (phase):
            dqsi_cache=[None]*NUM_DLY_STEPS # cache for holding already measured delays. None - not measured, 0 - no data, [[]..[]]
            def measure_dqsi(dqs_idly,branch,force_meas=False):
                if not dqsi_valid[branch]:
                    return None
                if (dqs_idly > len(dqsi_cache)) or (dqs_idly <0 ):
                    print ("dqs_idly=%d, dqsi_cache=%s"%(dqs_idly,str(dqsi_cache)))
                try:
                    dqsi_cache[dqs_idly] 
                except:
                    print ("dqs_idly=%d, dqsi_cache=%s"%(dqs_idly,str(dqsi_cache)))
                       
                if (dqsi_cache[dqs_idly] is None) or force_meas:
                    self.x393_mcntrl_timing.axi_set_dqs_idelay(self.combine_delay(dqs_idly),quiet=quiet)
                    self.x393_mcntrl_timing.axi_set_dq_idelay(self.combine_delay(dqi_dqsi[branch][dqs_idly]),quiet=quiet)
                    buf=self.x393_pio_sequences.read_block(4 * (nrep+1) +2,
                                                           (0,1)[quiet<1], #show_rslt,
                                                           1) # wait_complete=1)
                    buf= buf[4:(nrep*4)+4] # discard first 4*32-bit words and the "tail" after nrep*4 words32
                    patt=self.convert_w32_to_mem16(buf)# will be nrep*8 items
                    dqsi_cache[dqs_idly]=patt
                    if quiet < 1:
                        print ('measure_phase(%d,%s) - new measurement'%(phase,str(force_meas)))
                else:
                    patt=dqsi_cache[dqs_idly]
                    if quiet < 1:
                        print ('measure_patt(%d,%s) - using cache'%(phase,str(force_meas)))
                return patt
            def get_bit_diffs(dqs_idly0,dqs_idly1,branch):
                patt0=measure_dqsi(dqs_idly0,branch)
                patt1=measure_dqsi(dqs_idly1,branch)
                if (patt0 is None) or (patt1 is None):
                    raise Exception("Tried to compare invalid(s): dqs_idly0=%d, dqs_idly1=%d, branch=%s"%(dqs_idly0, dqs_idly1, branch))
                rslt=[0]*16
                for i in range (nrep*8): # with 8 nursts - 64 x16-bit words
                    diffs=patt0[i] ^ patt1[i]
                    for b in range(len(rslt)):
                        rslt[b]+= (diffs >> b) & 1
                return rslt        
            def get_lane_diffs(dqs_idly0,dqs_idly1,branch):
                diffs= get_bit_diffs(dqs_idly0,dqs_idly1,branch)
#                lane_diffs=[0]*(len(diffs)//8)
                lane_diffs=[]
                for lane in range(len(diffs)//8):
                    num_diffs=0   
                    for b in range(8):
                        num_diffs += (0,1)[diffs[8*lane+b] != 0]
                    lane_diffs.append(num_diffs)
                if quiet <3:
                    print ("%d ? %d : %s"%(dqs_idly0,dqs_idly1,lane_diffs))

                return lane_diffs
            def get_lane_adiffs(dqs_idly0,dqs_idly1,branch): # Assuming all 8 bits differ in the read data - check it in a single block? Write pattern?
                diffs=get_lane_diffs(dqs_idly0,dqs_idly1,branch)
                    
                return ((diffs[0]-4)/4.0,(diffs[1]-4)/4.0)
            # Set phase
            phase_ok=self.set_phase_with_refresh( # check result for not None
                               phase,
                               quiet)
            if not phase_ok:
                return None # no valid CMDA ODELAY exists for this phase 
            # try branches (will exit on first match)
            for branch in dqsi_lohi.keys():
                low=dqsi_lohi[branch][0]
                high=dqsi_lohi[branch][1]
                # start with low dqs idelay and increase it by 1 primary step until getting 2 results with no bit differences
                # (using both byte lanes now)
                for idly1 in range(low+NUM_FINE_STEPS,high,NUM_FINE_STEPS):
                    diffs=get_lane_diffs(idly1-NUM_FINE_STEPS,idly1,branch)
                    if diffs == [0,0]: # no bit diffs in both byte lanes
                        low=idly1
                        break
                else: #failed to find two delays to get the same read results (no bit differences in both lanes)
                    continue
                # got both byte lanes with no difference, now try to find dqs_idelay delay where both bytes differ
                for idly in range(low,high,dly_step):
                    idly1=min(idly+dly_step,high)
                    diffs=get_lane_diffs(low,idly1,branch)
                    if (diffs[0] != 0) and (diffs[1] != 0):
                        high=idly1
                        break
                    elif (diffs[0] == 0) and (diffs[1] == 0):
                        low=idly1 # move low higher
                else: #failed to find another delay to get different read results (both myte lanes have bit differences
                    continue
                if quiet <3:
                    print ("0: low=%d, high=%d"%(low,high))
                low_safe=low # safe low
                # now find marginal dqs idelay for each byte lane by dividing (low,high) interval
                #reduce low,high range for combined lanes
                dly = high
                while low < dly: # first adjust low
                    dly_next = (low+dly) // 2
                    diffs=get_lane_diffs(low,dly_next,branch)
                    if (diffs[0] != 0) and (diffs[1] != 0):
                        dly = dly_next
                        high= dly
                    elif (diffs[0] == 0) and (diffs[1] == 0):
                        if low == dly_next:
                            break
                        low = dly_next # move low higher
                    else: # one byte matches, other - not (uncertain)
                        dly = dly_next
                dly = low
                while dly < high: # now adjust high
                    dly_next = (high+dly) // 2
                    diffs=get_lane_diffs(low_safe,dly_next,branch)
                    if (diffs[0] != 0) and (diffs[1] != 0):
                        high= dly_next
                    else: 
                        if dly == dly_next:
                            break
                        dly = dly_next # move low higher
                #low, high are now closer, now scan and store (delay,num_bits) for each lane
                #May be check maximal number of bits that mismatch for each lane? Now assuming that it can be up to all 8
#                low -= NUM_FINE_STEPS
#                low =  max(dqsi_lohi[branch][0], low - NUM_FINE_STEPS ) # try to move lower by the fine steps interval, if possible
#                high = min(dqsi_lohi[branch][1], high+ NUM_FINE_STEPS ) # try to move higher by the fine steps interval, if possible
                if quiet <3:
                    print ("1: low=%d(%d), high=%d"%(low,low_safe,high))
                high = min(dqsi_lohi[branch][1], high+ NUM_FINE_STEPS ) # try to move higher by the fine steps interval, if possible
                if quiet <3:
                    print ("2: low=%d(%d), high=%d"%(low,low_safe,high))
                rslt=[]
                bestDly=[None]*2 # [low_safe]*2 # otherwise may fail - check it?
                bestDiffs=[None]*2
                comp_step=(1,NUM_FINE_STEPS)[compare_prim_steps]
                for dly in range (low, high+1):
                    ref_dly= dly-comp_step
                    if ref_dly < low_safe:
                        continue
                    if quiet <2:
                        print ("dly=%d, ref_dly=%d"%(dly, ref_dly),end=" ")
                    adiffs= get_lane_adiffs(low_safe,dly,branch)
                    adiffs_ref=get_lane_adiffs(low_safe,ref_dly,branch)
                    
                    for lane in range(len(adiffs)):
                        diffs_prev_this=(adiffs_ref[lane],adiffs[lane])
                        if (diffs_prev_this[0] <= 0) and (diffs_prev_this[1] >= 0): 
                            if abs(diffs_prev_this[0]) <= abs(diffs_prev_this[1]): # store previos sample
                                if (bestDiffs[lane] is None) or (abs (diffs_prev_this[0]) < abs(bestDiffs[lane])):
                                    bestDly[lane]=ref_dly # dly-1/dly-NUM_FINE_STEPS
                                    bestDiffs[lane]=diffs_prev_this[0]
                            else:
                                if (bestDiffs[lane] is None) or (abs (diffs_prev_this[1])<abs(bestDiffs[lane])):
                                    bestDly[lane]=dly # dly-1
                                    bestDiffs[lane]=diffs_prev_this[1]
                    if (adiffs[0] > 0) and (adiffs[1] > 0):
                        break # no need to continue, data got already 
                for lane in range(len(adiffs)):
                    if bestDiffs[lane] == -1.0:
                        bestDiffs[lane] = None # single step jumps from none to all            
                    rslt.append((bestDly[lane],bestDiffs[lane],branch[0])) # adding first letter of branch name
                    if quiet <3:
                        print ("bestDly[%d]=%s, bestDiffs[%d]=%s, branch=%s"%(lane,str(bestDly[lane]),lane,str(bestDiffs[lane]),branch))
                if quiet <3:
                    print ('dly=%d rslt=%s'%(dly,str(rslt)))                    
                        
                if quiet < 2:
                    for i,d in enumerate(dqsi_cache):
                        if d:
                            print ("%d %s  %d: %s"%(phase,branch,i,str(d)))
                return rslt
            return None # All Early/Nominal/Late variants were exhausted, did not find critical DQS inoput delay for this phase value 
        # body of the  measure_dqs_idly_phase()
        dqsi_vs_phase=[]
        for phase in range (numPhaseSteps):
            if quiet <2:
                print ("====== PHASE=%d ======"%(phase))

            elif quiet < 3:
                print ("%d:"%(phase),end=" ")
                sys.stdout.flush()
            elif quiet < 5:
                print (".",end="")
                sys.stdout.flush()
            dqsi_vs_phase.append(dqsi_phase_step (phase))
                    
        if quiet < 3 :
            print ("dqsi_vs_phase=%s"%(str(dqsi_vs_phase)))
            print("Phase DQSI0 DQSI1 diff0 diff1 branch0 branch1")
            for phase,v in enumerate(dqsi_vs_phase):
                print("%d"%(phase), end=" ")
                if v:
                    print ("%s %s %s %s %s %s"%(str(v[0][0]),str(v[1][0]),str(v[0][1]),str(v[1][1]), v[0][2], v[1][2]))
                else:
                    print()
        elif quiet < 5:
            print ()
        self.adjustment_state['dqsi_vs_phase']=      dqsi_vs_phase
        self.adjustment_state['dqsi_vs_phase_steps']=compare_prim_steps            
        return dqsi_vs_phase        
                
                    
    def measure_dqo_dqso(self,
                               compare_prim_steps = True, # while scanning, compare this delay with 1 less by primary(not fine) step,
                                                # save None for fraction in unknown (previous -0.5, next +0.5) 
                               frac_step=0.125,
                               sel=1,
                               quiet=1,
                               start_dly=0): #just to check dependence
        """
        Scan dqs odelay (setting phase appropriately), write
        0x0000/0xffff/0x0000/0xffff (same as fixed pattern) data and read it with known dqsi/dqi
        values (maybe even set different phase for read?), discarding first and last 1.5 8-bursts
        Measure 4 different transitions for each data bit (rising DQS/rising DQ, falling DQS/falling DQ,
        rising DQS/falling DQ and falling DQS/rising DQ (that allows to measure duty cycles fro both
        DQS and DQ lines
        @param quiet reduce output
        """
#        self.load_hardcoded_data() # TODO: REMOVE LATER
        try:
            dqi_dqsi=self.adjustment_state['dqi_dqsi']
        except:
            print ("No DQ IDELAY vs. DQS IDELAY data available, exiting")
            return
        dqsi_phase=self.adjustment_state['dqsi_phase']
        num_lanes=len(dqsi_phase)
        cmda_bspe=self.adjustment_state['cmda_bspe']
        wlev_dqs_bspe=self.adjustment_state['wlev_dqs_bspe']
        brc=(5,        # 3'h5,     # bank
             0x1234,   # 15'h1234, # row address
             0x100)     # 10'h100   # column address
        nrep=8 # number of 8-bursts to compare (actual will have 3 more, first/last will be discarded
        extraTgl=0 # data is repetitive,so extra toggle is not needed (an there is an extra 8-burst anyway)
        timing=self.x393_mcntrl_timing.get_dly_steps()
        dly_step=int(NUM_FINE_STEPS*frac_step*timing['SDCLK_PERIOD']/timing['DLY_STEP']+0.5)
        numPhaseSteps= int(timing['SDCLK_PERIOD']/timing['PHASE_STEP']+0.5)
        step180= int(NUM_FINE_STEPS*0.5* timing['SDCLK_PERIOD'] / timing['DLY_STEP'] +0.5)                                                                                                                                                                                                                 
        
        
        #Calculate phase for the best match for the DQS output delay (for both lanes - use average). If
        # solution for different lanes point to the opposite ends of the phase range - keep previous
        # do not look outside of +/- frac_step 
        def get_phase_for_dqso():
            phase_dqso=[]
            last_phase=0
            for dly in range(NUM_DLY_STEPS):
                best_phases= []
                for lane in range(num_lanes):
                    best_diff= frac_step*NUM_DLY_STEPS
                    best_phase=None
                    for phase in range(numPhaseSteps):
                        try:
                            dly_phase=wlev_dqs_bspe[lane][phase]['ldly']
                        except:
                            dly_phase=None
                        if (not dly_phase is None) and (cmda_bspe[phase % numPhaseSteps] is None): # check that CMDA odelay exists for this phase
                            dly_phase=None
                        """    
                        # Make sure that dqsi and dqi exist for the phase
                        if dqsi_dqi_for_phase[phase] is None:
                            dly_phase=None
                        if dly==65:
                            print("lane=%d dly=%d, dqsi_dqi_for_phase[%d]=%s (%s)"%(lane, dly,phase,str(dqsi_dqi_for_phase[phase]),str(dly_phase)))
                        """                            
                        if not dly_phase is None:
                            adiff=abs(dly_phase-dly)
                            if adiff < best_diff:
                                best_diff = adiff
                                best_phase = phase
                    if best_phase is None:
                        best_phases=None # At least one of the lanes does not have an acceptable solution (should not normally happen)
                        break
#                    print("lane=%d dly=%d, best_phase=%s best_diff=%s"%(lane, dly,str(best_phase),str(best_diff)))                        
                    best_phases.append(best_phase)
                if best_phases is None:
                    phase_dqso.append(None)
                    continue
                else:
                    diff_per= max(best_phases)-min(best_phases) > numPhaseSteps/2 # different ends
                        #find which one is closer to last_phase, modify the other one by +/- period
                    sp=0.0
                    for lane in range(num_lanes):
                        if diff_per and (best_phases[lane] >= numPhaseSteps/2):
                            best_phases[lane] -= numPhaseSteps
                        sp+=best_phases[lane]
                    sp /= num_lanes # average phase for all lanes
                    sp=int(round(sp))
                    # only if results for lanes are on the different ends - if they agree - just take an average
                    if diff_per and (abs(sp-last_phase) > abs(sp+numPhaseSteps-last_phase)):
                        sp += numPhaseSteps 
                    sp=max(sp,0)
                    # May be that both best phases were OK, but their average falls into the gap - find closest
                    if dqsi_dqi_for_phase[sp] is None:
                        best_dist=numPhaseSteps
                        best_phase=None
                        for phase in range(numPhaseSteps):
                            if not dqsi_dqi_for_phase[phase] is None:
                                dist = min(abs(phase-sp),abs(phase+numPhaseSteps-sp),abs(phase-numPhaseSteps-sp))
                                if dist < best_dist:
                                    best_dist=dist
                                    best_phase=phase
                        if best_dist >= frac_step*numPhaseSteps:
#                            print("Could not find phase substitute for %d, %s is too far "%(sp, str(best_phase)))
                            best_phase=None
#                        else:
#                            print("Using substitute %d for %d"%(best_phase,sp))
                        sp=  best_phase 

                    sp=min(sp,numPhaseSteps-1)
#                    print("dly=%d best_phases=%s"%(dly, str(best_phases)))    
                    phase_dqso.append(sp)
            return phase_dqso
        def get_dqsi_dqi_for_phase():
            # Mark DQS idelay values that have all DQ delays valid
            # for each phase check that DQS input delay value exists and store DQi varinat (early/nominal/late
            dqsi_dqi_phase=[None]*numPhaseSteps
            inv_vars=('early','late') 
            for phase in range (numPhaseSteps):
#                print (phase, end=" ")
                dqsi=[]
                for lane_data in dqsi_phase:
                    dqsi.append(lane_data[phase])
                if None in dqsi:
                    continue # Keep False
                for k, dqi_dqsi_v in dqi_dqsi.items():
#                    print (" k=%s"%(k), end=" ")
                    if not dqi_dqsi_v:
                        continue # need to continue with next phase
                    dqi=[]
                    for lane, dqsi_lane in enumerate(dqsi):
#                        print (" lane=%d"%(lane), end=" ")
                        dq_lane=dqi_dqsi_v[dqsi_lane] #list of 16 DQ values for dqsi_lane or None 
                        if (dq_lane is None) or (None in dq_lane[8*lane:8*(lane+1)]):
                            break
                        dqi += dq_lane[8*lane:8*(lane+1)]
                    else:
                        dqsi_dqi_phase[phase]={'dqsi':dqsi,
                                               'dqi':dqi,
                                               'invert':k in inv_vars,
                                               'variant':k } # dqsi - a pair of dqs input delays, dqi - dq delays for the same phase
                        break
#                print()
            return dqsi_dqi_phase
            
        def dqs_step(dqs_lin):
            patt_cache=[None]*NUM_DLY_STEPS # cache for holding already measured delays
            def measure_block(dly,invert_patt, force_meas=False):
                if (patt_cache[dly] is None) or force_meas:
                    self.x393_mcntrl_timing.axi_set_dq_odelay(self.combine_delay(dly),quiet=quiet)
                    self.x393_pio_sequences.write_block() #page= 0, wait_complete=1)
                    patt= self.x393_pio_sequences.read_levelling(nrep,
                                                                 -2, # Actually read block, but pre-process as a pattern  
                                                                 quiet+1)
                    
                    #invert pattern if using early/late (not nominal) variants
#                    if (invert_patt):
#                        for i in range(len(patt)):
#                            patt[i]=1.0-patt[i]
                    patt_cache[dly]=patt
                    if quiet < 1:
                        print ('measure_block(%d,%s) - new measurement'%(dly,str(force_meas)))
                else:
                    patt=patt_cache[dly]
                    if quiet < 1:
                        print ('measure_block(%d,%s) - using cache'%(dly,str(force_meas)))
                return patt
            def get_sign(data,edge=None):
                """
                edge: 0 - first 16, 1 - second 16
                return -1 if  all <0.5
                return +1 if all >0.5
                return 0 otherwise
                """
                if edge == 0:
                    return get_sign(data[:16])
                if edge == 1:
#                    return -get_sign(data[16:])
                    return get_sign(data[16:])
                m1=True
                p1=True
                for d in data:
                    m1 &= (d < 0.5)
                    p1 &= (d > 0.5)
                    if not (m1 or p1):
                        break
                else:
                    if m1:
                        return -1
                    elif p1:
                        return 1
                return 0
            
            rslt=[None]*16 # each bit will have [inphase][dqs_falling]
            self.x393_mcntrl_timing.axi_set_dqs_odelay(self.combine_delay(dqs_lin),quiet=quiet)
            #set phase, cmda_odelay, dqsi, dqi to match this delay
            phase=phase_dqso[dqs_lin]
            if phase is None: # no good phase exist for the specified dqs_odelay
                if quiet <2:
                    print("No dood phase for DQS odelay = %d"%(dqs_lin))
                return None
            # set phase
            # TODO: maybe keep last phase set and do not change it if required is not too far from the last set
            # Set phase (and cmda_odelay as needed)
            if quiet < 2:
                print ("set_phase_with_refresh(%d), dqs_odelay=%d"%(phase,dqs_lin))
            phase_ok=self.set_phase_with_refresh( # check result for not None
                               phase,
                               quiet)
            if not phase_ok:
                print ("Failed to set phase=%d for dly=%d- that should not happen (phase_dqso)- "%(phase,dqs_lin))
                return None # no valid CMDA ODELAY exists for this phase
            #set DQS IDELAY and DQ IDELAY matching phase 
            dqs_idelay=dqsi_dqi_for_phase[phase]['dqsi'] # 2-element list
            dq_idelay= dqsi_dqi_for_phase[phase]['dqi']  # 16-element list
            invert_patt= dqsi_dqi_for_phase[phase]['invert']  # 16-element list
            self.x393_mcntrl_timing.axi_set_dqs_idelay(self.combine_delay(dqs_idelay),quiet=quiet)
            self.x393_mcntrl_timing.axi_set_dq_idelay(self.combine_delay(dq_idelay),quiet=quiet)

            
            
            d_low=[None]*2  # first - lowest when all are -+, second - when all are +-  
            d_high=[None]*2 # first - when all are +- after -+, second - when all are -+ after +-
            dly=0
            notLast=True
            needSigns=None
            lowGot=None
            highGot=None
            while (dly < NUM_DLY_STEPS) and notLast:
                notLast= dly < NUM_DLY_STEPS-1
                patt=measure_block(dly,invert_patt) # ,force_meas=False)
                signs=(get_sign(patt,0),get_sign(patt,1))
                if quiet < 1:
                    print ('dly=%d lowGot=%s, highGot=%s, signs=%s'%(dly,str(lowGot),str(highGot),str(signs)))
                if lowGot is None : # looking for the first good sample
                    if (signs==(-1,1)) or  (signs==(1,-1)) :
                        if signs[0] == -1: #  == (-1,1):
                            lowGot=0
                        else:
                            lowGot=1
                        d_low[lowGot] = dly
                        needSigns=((1,-1),(-1,1))[lowGot]
                        dly += step180-dly_step # almost 180 degrees
                    else: # at least one is 0
                        dly += dly_step # small step
                    if quiet < 1:
                        print ('lowGot was None : dly=%d, lowGot=%s, needSigns=%s'%(dly,str(lowGot),str(needSigns)))
                elif highGot is None : # only one good sample is available so far
                    if signs == needSigns:
                        highGot=lowGot
                        d_high[highGot] = dly
                        d_low[1-lowGot] = dly
                        needSigns=((-1,1),(1,-1))[lowGot]
                        dly += step180-dly_step # almost 180 degrees
                    else:
                        dly += dly_step # small step
                    if quiet < 1:
                        print ('highGot was None : dly=%d, lowGot=%s, highGot=%s, needSigns=%s'%(dly,str(lowGot),str(lowGot),str(needSigns)))
                else: # looking for the 3-rd sample 
                    if signs == needSigns:
                        highGot=1-highGot
                        d_high[highGot] = dly
                        break
                    else:
                        dly += dly_step # small step
                dly = min (dly,NUM_DLY_STEPS-1)
            if highGot is None:
                if quiet < 3:
                    print ("Could not find initial bounds for DQS output delay = %d d_low=%s, d_high=%s"%(dqs_lin,str(d_low),str(d_high)))
                return None
            if quiet < 2:
                    print ("DQS input delay = %d , preliminary bounds: d_low=%s, d_high=%s"%(dqs_lin,str(d_low),str(d_high)))
            for inPhase in range(2):
                if not d_high[inPhase] is None:
                    # Try to squeeze d_low, d_high closer to reduce scan range
                    while d_high[inPhase]>d_low[inPhase]:
                        dly=(d_high[inPhase] + d_low[inPhase])//2
                        patt=measure_block(dly,invert_patt) # ,force_meas=False)
                        signs=(get_sign(patt,0),get_sign(patt,1))
                        if signs==(-1,1):
                            if inPhase:
                                d_high[inPhase]=dly 
                            else:
                                if d_low[inPhase]==dly:
                                    break
                                d_low[inPhase]=dly 
                        elif signs==(1,-1):     
                            if inPhase:
                                if d_low[inPhase]==dly:
                                    break
                                d_low[inPhase]=dly 
                            else:
                                d_high[inPhase]=dly 
                        else: # uncertain result 
                            break
            if quiet < 2:
                    print ("DQS output delay = %d , squeezed bounds: d_low=%s, d_high=%s"%(dqs_lin,str(d_low),str(d_high)))
#Improve squeezing - each limit to the last
            for inPhase in range(2):
                if not d_high[inPhase] is None:
                    # Try to squeeze d_low first
                    d_uncertain=d_high[inPhase]
                    while d_uncertain > d_low[inPhase]:
                        dly=(d_uncertain + d_low[inPhase])//2
                        patt=measure_block(dly,invert_patt) # ,force_meas=False)
                        signs=(get_sign(patt,0),get_sign(patt,1))
                        if signs==(-1,1):
                            if inPhase:
                                d_uncertain=dly 
                            else:
                                if d_low[inPhase]==dly:
                                    break
                                d_low[inPhase]=dly 
                        elif signs==(1,-1):     
                            if inPhase:
                                if d_low[inPhase]==dly:
                                    break
                                d_low[inPhase]=dly 
                            else:
                                d_uncertain=dly 
                        else: # uncertain result
                            d_uncertain=dly
                    #now udjust upper limit
                    while d_high[inPhase] > d_uncertain:
                        dly=(d_high[inPhase] + d_uncertain)//2
                        patt=measure_block(dly,invert_patt) # ,force_meas=False)
                        signs=(get_sign(patt,0),get_sign(patt,1))
                        if signs==(-1,1):
                            if inPhase:
                                d_high[inPhase]=dly 
                            else:
                                if d_uncertain==dly:
                                    break
                                d_uncertain=dly 
                        elif signs==(1,-1):     
                            if inPhase:
                                if d_uncertain==dly:
                                    break
                                d_uncertain=dly 
                            else:
                                d_high[inPhase]=dly 
                        else: # uncertain result 
                            if d_uncertain==dly:
                                break
                            d_uncertain=dly
            if quiet < 2:
                    print ("DQS output delay = %d , tight squeezed bounds: d_low=%s, d_high=%s"%(dqs_lin,str(d_low),str(d_high)))

                    
            # scan ranges, find closest solutions
            #compare_prim_steps
            best_dly= [[],[]]
            best_diff=[[],[]]
            for inPhase in range(2):
                if not d_high[inPhase] is None:
#                    patt=None
                    best_dly[inPhase]=[d_low[inPhase]]*32
                    best_diff[inPhase]=[None]*32
#                    for b,p in enumerate(patt):
#                        positiveJump=((not inPhase) and (b<16)) or (inPhase and (b >= 16)) # may be 0, False, True
#                        if positiveJump:
#                            best_diff[inPhase].append(p-0.5)
#                        else:
#                            best_diff[inPhase].append(0.5-p)
                    for dly in range(d_low[inPhase]+1,d_high[inPhase]+1):
#                        patt_prev=patt
                        #as measured data is cached, there is no need to specially maintain patt_prev from earlier measurement
                        dly_prev= max(0,dly-(1,NUM_FINE_STEPS)[compare_prim_steps])
                        patt_prev=measure_block(dly_prev,invert_patt) # ,force_meas=False) - will be stored in cache
                        patt=     measure_block(dly,invert_patt) # ,force_meas=False) - will be stored in cache
                        for b in range(32):
                            positiveJump=((not inPhase) and (b<16)) or (inPhase and (b >= 16)) # may be 0, False, True       
                            signs=((-1,1)[patt_prev[b]>0.5],(-1,1)[patt[b]>0.5])
                            if (positiveJump and (signs==(-1,1))) or (not positiveJump and (signs==(1,-1))):
                                if positiveJump:
                                    diffs_prev_this=(patt_prev[b]-0.5,patt[b]-0.5)
                                else:
                                    diffs_prev_this=(0.5-patt_prev[b],0.5-patt[b])
                                if abs(diffs_prev_this[0]) <= abs(diffs_prev_this[1]): # store previos sample
                                    if (best_diff[inPhase][b] is None) or (abs (diffs_prev_this[0])<abs(best_diff[inPhase][b])):
                                        best_dly[inPhase][b]=dly_prev # dly-1
                                        best_diff[inPhase][b]=diffs_prev_this[0]
                                        if quiet < 1:
                                            print ("*%d:%0.3f:%0.3f%s"%(b,diffs_prev_this[0],diffs_prev_this[1],str(signs)),end="")
                                else:
                                    if (best_diff[inPhase][b] is None) or (abs (diffs_prev_this[1])<abs(best_diff[inPhase][b])):
                                        best_dly[inPhase][b]=dly # dly-1
                                        best_diff[inPhase][b]=diffs_prev_this[1]
                                        if quiet < 1:
                                            print ("?%d:%0.3f:%0.3f%s"%(b,diffs_prev_this[0],diffs_prev_this[1],str(signs)),end="")
                        if quiet < 1:
                            print("\n dly=%d dly_prev=%d:"%(dly,dly_prev),end=" ")
                    for b in range(32):
                        if  best_diff[inPhase][b] == -0.5:
                            best_diff[inPhase][b] = None # will have to add half-interval (0.5 or 2.5) 
                # rslt=[None]*16 # each bit will have [inphase][dqs_falling], each - a pair of (delay,diff)
            for b in range(16):
                rslt[b]=[[None]*2,[None]*2] # [inphase][dqs_falling]
                for inPhase in range(2):
                    if not d_high[inPhase] is None:
                        rslt[b][inPhase]= [(best_dly[inPhase][b],best_diff[inPhase][b]),(best_dly[inPhase][b+16],best_diff[inPhase][b+16])]
            if quiet < 2:
                    print ("%d: rslt=%s"%(dqs_lin,str(rslt)))
            return rslt
        # main method code               
                                 
                            
#(wlev_dqs_bspe[lane][phase]['ldly']                        
#                if (not wlev_dqs_bspe[lane][phase] is None) and (not wlev_dqs_bspe[lane][phase]['ldly'] is None):
                        
        
        if quiet<2:
            print ("timing=%s, dly_step=%d step180=%d"%(str(timing),dly_step,step180))
        wdata16=(0,0xffff)*(4*(nrep+3))
        wdata32=self.convert_mem16_to_w32(wdata16)
        dqsi_dqi_for_phase=get_dqsi_dqi_for_phase()
        phase_dqso=get_phase_for_dqso() # uses dqsi_dqi_for_phase
        if quiet < 2:
            for i, v in enumerate(phase_dqso):
                print("%d %s"%(i,str(v)))
            for p, v in enumerate(dqsi_dqi_for_phase):
                print("%d"%(p),end=" ")
                if v:
                    for dqsi in v['dqsi']:
                        print(dqsi,end=" ") 
                    for dqi in v['dqi']:
                        print(dqi,end=" ") 
                    print(v['invert'],end=" ")
                    print(v['variant'],end=" ")
                print()
        if self.DRY_MODE:        
            return
        
        self.x393_mcntrl_buffers.write_block_buf_chn(0,0,wdata32,quiet); # fill block memory (channel, page, number)
        self.x393_pio_sequences.set_write_block(*(brc+(nrep+3,extraTgl,sel))) # set sequence once
        self.x393_pio_sequences.set_read_block(*(brc+(nrep+3,sel))) # set sequence once
        #With the data to write being the same as pattern data, try using the same measurements as for the pattern
 
        meas_data=[None]*(NUM_DLY_STEPS)
        #start_dly
        for sdly in range(NUM_DLY_STEPS):
            ldly = (start_dly+sdly)%(NUM_DLY_STEPS)
#        for ldly in range(max_lin_dly+1):
            if quiet <3:
                print ("%d(0x%x):"%(ldly,self.combine_delay(ldly)),end=" ")
                sys.stdout.flush()
            elif quiet < 5:
                print (".",end="")
                sys.stdout.flush()
            meas_data[ldly] = dqs_step(ldly)
        if quiet < 5:
            print ()

        if quiet < 3:
            print("\n\nMeasured data, integer portion, measured with %s steps"%(("fine","primary")[compare_prim_steps]))
            print ("DQS",end=" ")
            for f in ('ir','if','or','of'):
                for b in range (16):
                    print ("%s_%d"%(f,b),end=" ")
            print()        
            for ldly, data in enumerate(meas_data):
                print("%d"%ldly,end=" ")
                if data:
                    for typ in ((0,0),(0,1),(1,0),(1,1)):
                        for pData in data: # 16 DQs, each None nor a pair of lists for inPhase in (0,1), each a pair of edges, each a pair of (dly,diff)
                            if pData:
                                if pData[typ[0]] and pData[typ[0]][typ[1]]:
                                    print ("%d"%pData[typ[0]][typ[1]][0],end=" ")
                                    '''
                                    try:
                                        print ("%d"%pData[typ[0]][typ[1]][0],end=" ")
                                    except:
                                        print (".", end=" ")
                                    '''
                                else:
                                    print ("?", end=" ")
                            else:
                                print ("x",end=" ")
                        
                print()
        if quiet < 2:
            print("\n\nMasked measured data, integer portion, measured with %s steps"%(("fine","primary")[compare_prim_steps]))
            for f in ('ir','if','or','of'):
                for b in range (16):
                    print ("%s_%d"%(f,b),end=" ")
            print()        
            for ldly, data in enumerate(meas_data):
                print("%d"%ldly,end=" ")
                if data:
                    for typ in ((0,0),(0,1),(1,0),(1,1)):
                        for pData in data: # 16 DQs, each None nor a pair of lists for inPhase in (0,1), each a pair of edges, each a pair of (dly,diff)
                            if pData:
                                if pData[typ[0]] and pData[typ[0]][typ[1]] and (not pData[typ[0]][typ[1]][1] is None):
                                    print ("%d"%pData[typ[0]][typ[1]][0],end=" ")
                                    '''
                                    try:
                                        print ("%d"%pData[typ[0]][typ[1]][0],end=" ")
                                    except:
                                        print (".", end=" ")
                                    '''
                                else:
                                    print ("?", end=" ")
                            else:
                                print ("x",end=" ")
                        
                print()
                    
        if quiet < 2:
            print ("\nDifferences from 0.5:")

            print ("DQS",end=" ")
            for f in ('ir','if','or','of'):
                for b in range (16):
                    print ("%s_%d"%(f,b),end=" ")
            print()        
            for ldly, data in enumerate(meas_data):
                print("%d"%ldly,end=" ")
                if data:
                    for typ in ((0,0),(0,1),(1,0),(1,1)):
                        for pData in data: # 16 DQs, each None nor a pair of lists for inPhase in (0,1), each a pair of edges, each a pair of (dly,diff)
                            if pData:
                                if pData[typ[0]] and pData[typ[0]][typ[1]] and (not pData[typ[0]][typ[1]][1] is None):
                                    print ("%.2f"%pData[typ[0]][typ[1]][1],end=" ")
                                    '''
                                    try:
                                        print ("%d"%pData[typ[0]][typ[1]][0],end=" ")
                                    except:
                                        print (".", end=" ")
                                    '''
                                else:
                                    print ("?", end=" ")
                            else:
                                print ("x",end=" ")
                        
                print()
        if quiet < 3:
            print("\n\nMeasured data, comparing current data with the earlier by one %s step"%(("fine","primary")[compare_prim_steps]))
            print("When the fractional (second in the tuple) data is exactly -0.5, the actual result is in the range %s from the integer delay"%
                  (("+0.0..+1.0","+0.0..+%d"%NUM_FINE_STEPS)[compare_prim_steps]))
            print ("meas_data=[")
            for d in meas_data:
                print("%s,"%(str(d)))
            print("]")
        rdict={"write_prim_steps":    compare_prim_steps,
               "write_meas_data":     meas_data} # TODO: May delete after LMA fitting
        self.adjustment_state.update(rdict)
                    
                    
                      
    '''
    adjust_cmda_odelay 0 1 0.1 3
    adjust_write_levelling 0 1 0 .1 3
    adjust_pattern 0.125 0.1 1
    '''
    def measure_all(self,
                    tasks="CWRPOZ",
                    prim_steps=1,
                    primary_set_in=2,
                    primary_set_out=2,
                    quiet=3):
        """
        @param tasks - "C" cmda, "W' - write levelling, "R" - read levelling (DQI-DQSI), "P" -  dqs input phase (DQSI-PHASE),
                       "O" - output timing (DQ odelay vs  DQS odelay) "Z" - print results
        @param prim_steps -  compare measurement with current delay with one lower by 1 primary step (5 fine delay steps), 0 -
                             compare with one fine step lower
        @param quiet reduce output
        """
        max_phase_err=0.1
        frac_step=0.125
#        read_sel=1 # set DDR3 command in the second cycle of two (0 - during the first omne)
        read_bin_size=5 # dealy counts
        write_bin_size=5 # dealy counts
        read_scale_w=0.0 # weight of the "binary" results relative to "analog"
        write_scale_w=0.0 # weight of the "binary" results relative to "analog"
        
        idly_phase_sel=1
        bin_size_ps=50.0
        read_phase_scale_w=0.0
        prim_steps_in=prim_steps
        prim_steps_out=prim_steps
#        primary_set_in=2
#        primary_set_out=2
        write_sel=1 # set DDR3 command in the second cycle of two (0 - during the first omne)

        task_data=[{'key':'C',
                    'func':self.adjust_cmda_odelay,
                    'comment':'Measuring CMDA output delay for each clock phase',
                    'params':{'start_phase':0,
                              'reinits':1,
                              'max_phase_err':max_phase_err,
                              'quiet':quiet+1}},
                   {'key':'W',
                    'func':self.adjust_write_levelling,
                    'comment':'Write levelling - measuring optimal DQS output delay for each phase',
                    'params':{'start_phase':0,
                              'reinits':1,
                              'invert':0,
                              'max_phase_err':max_phase_err,
                              'quiet':quiet+1}},
                   {'key':'R',
                    'func':self.measure_pattern,
                    'comment':'Read levelling - measuring predefined pattern to determine DQ input delays relative to DQS ones',
                    'params':{'compare_prim_steps':prim_steps_in,
                              'limit_step':frac_step,
                              'max_phase_err':max_phase_err,
                              'quiet':quiet+1}},
                   {'key':'R',
                    'func':self.proc_dqi_dqsi,
                    'comment':'Processing read levelling results using Levenberg-Marquardt algorithm to determine delay model parameters and optimal delay values',
                    'params':{'lane':'All',
                              'bin_size':read_bin_size,
                              'primary_set':primary_set_in,
                              'data_set_number':-1, # use measured data
                              'scale_w':read_scale_w,
                              'quiet':quiet+1}},
                   {'key':'P',
                    'func':self.measure_dqs_idly_phase,
                    'comment':'Measure optimal DQS input delays for clock phases (clock boundary crossing from DQS in to internal)',
                    'params':{'compare_prim_steps':prim_steps_in,
                              'frac_step':frac_step,
                              'sel':idly_phase_sel,
                              'quiet':quiet+1}},
                   {'key':'P',
                    'func':self.proc_dqsi_phase, # compare_prim_steps???
                    'comment':'Calculate optimal DQS input delays vs. clock phase',
                    'params':{'lane':'All',
                              'bin_size_ps':bin_size_ps,
                              'data_set_number':-1, # use measured data
                              'scale_w':read_phase_scale_w,
                              'quiet':quiet+1}},
                   {'key':'O',
                    'func':self.measure_dqo_dqso,
                    'comment':'Measure write mode output delays on DQ lines relative to DQS output delays',
                    'params':{'compare_prim_steps':prim_steps_out,
                              'frac_step':frac_step,
                              'sel': write_sel,
                              'quiet':quiet+1}},
                   
                    {'key':'O',
                    'func':self.proc_dqo_dqso,
                    'comment':'Processing DQ output delays to DQS output data results using Levenberg-Marquardt algorithm to determine optimal delays',
                    'params':{'lane':'All',
                              'bin_size':write_bin_size,
                              'primary_set':primary_set_out,
                              'data_set_number':-1, # use measured data
                              'scale_w':write_scale_w,
                              'quiet':quiet+1}},
                    {'key':'Z',
                    'func':self.show_all_vs_phase,
                    'comment':'Printing results table (delays and errors vs. phase)- all, including invalid phases',
                    'params':{'keep_all':True,
                              'load_hardcoded':False}},
                    {'key':'Z',
                    'func':self.show_all_vs_phase,
                    'comment':'Printing results table (delays and errors vs. phase)- only for valid clock phase values',
                    'params':{'keep_all':False,
                              'load_hardcoded':False}},
                  ]
        start_time=time.time()
        last_task_start_time=start_time
        for task_item in task_data: # execute tasks in predefined sequence, if their keys are enabled through arguments (several tasks may be needed for 1 key)
            
            if task_item['key'] in tasks.upper():
                tim=time.time()
                if quiet < 5:
                    print ("[%.3f/+%.3f] %s"%(tim-start_time,tim-last_task_start_time,task_item['comment']))
                    print ("     %s("%(task_item['func'].__name__),end="")
#                    print ("task_item=",task_item)
#                    print ("task_item['params']=",task_item['params'])
                    for k,v in task_item['params'].items():
                        print ("%s=%s, "%(k,str(v)),end="")
                    print(")")    
                # TODO: print function name and used arguments
                task_item['func'](**task_item['params'])
                last_task_start_time=tim
        tim=time.time()
        if quiet < 5:
            print ("[%.3f/+%.3f] %s"%(tim-start_time,tim-last_task_start_time,"All Done"))
        
    def load_hardcoded_data(self):
        """
        Debug feature - load hard-coded previously acquired/processed data
        to reduce debugging time for nest stages
        """
        self.adjustment_state["dqi_dqsi"]=            get_test_dq_dqs_data.get_dqi_dqsi()
        self.adjustment_state["maxErrDqsi"]=          get_test_dq_dqs_data.get_maxErrDqsi() 
        self.adjustment_state["dqi_dqsi_parameters"]= get_test_dq_dqs_data.get_dqi_dqsi_parameters()
        self.adjustment_state["dqo_dqso"]=            get_test_dq_dqs_data.get_dqo_dqso()
        self.adjustment_state["maxErrDqso"]=          get_test_dq_dqs_data.get_maxErrDqso() 
        self.adjustment_state["dqo_dqso_parameters"]= get_test_dq_dqs_data.get_dqo_dqso_parameters()
        self.adjustment_state.update(get_test_dq_dqs_data.get_adjust_cmda_odelay())
        self.adjustment_state.update(get_test_dq_dqs_data.get_wlev_data())
        self.adjustment_state.update(get_test_dq_dqs_data.get_dqsi_phase())
    
    def proc_dqi_dqsi(self,
                       lane="all",
                       bin_size=5,
                       primary_set=2,
#                       compare_prim_steps=True, # while scanning, compare this delay with 1 less by primary(not fine) step,
#                                                # save None for fraction in unknown (previous -0.5, next +0.5)
                       data_set_number=2,        # not number - use measured data
                       scale_w=0.0,              # weight for "uncertain" values (where samples chane from all 0 to all 1 in one step)
 
                       quiet=1):
        """
        Run DQ vs DQS fitting for one data lane (0 or 1) using earlier acquired hard-coded data
        @param lane             byte lane to process (or non-number - process all byte lanes of the device) 
        @param bin_size         bin size for the histograms (should be 5/10/20/40)
        @param primary_set      which of the data edge series to use as leading (other will be trailing by 180) 
        @param data_set_number  select one of the hard-coded data sets (sets 0 and 1 use comparing with the data 1 fine step below
                          set #2 (default) used measurement with previous primary step measurement (will not suffer from
                          fine range wider than on primary step)
                          If not number or <0 - use measured data
        @param quiet reduce output
        @param scale_w        weight for "uncertain" values (where samples change from all 0 to all 1 in one step)
                        For sufficient data 0.0 is OK (and seems to work better)- only "analog" samples are considered   
        @return 3-element dictionary of ('early','nominal','late'), each being None or a 160-element list,
                each element being either None, or a list of 3 best DQ delay values for the DQS delay (some mey be None too) 
        """
        if quiet < 3:
            print ("proc_dqi_dqsi(): scale_w=%f"%(scale_w))
        if isinstance (data_set_number,(int,long)) and (data_set_number>=0) :
            if quiet < 4:
                print("Using hard-coded data set #%d"%data_set_number)
            compare_prim_steps=get_test_dq_dqs_data.get_compare_prim_steps_in(data_set_number)
            meas_data=get_test_dq_dqs_data.get_data_in(data_set_number)
        else:
            if quiet < 4:
                print("Using measured data set")
            try:
                compare_prim_steps=self.adjustment_state["patt_prim_steps"]
                meas_data=         self.adjustment_state["patt_meas_data"]
            except:
                print ("Pattern-measured data is not available, exiting")
                return
        meas_delays=[]
        for data in meas_data:
            if data:
                bits=[None]*16
                for b,pData in enumerate(data):
                    if pData:
                        bits[b]=[None]*4
                        for inPhase in (0,1):
                            if pData[inPhase]:
                                for e in (0,1):
                                    if pData[inPhase][e]:
                                        bits[b][inPhase*2+e]=pData[inPhase][e]# [0]
                meas_delays.append(bits)
        if quiet<1:
            x393_lma.test_data(meas_delays,compare_prim_steps,quiet)
        lma=x393_lma.X393LMA()
        rslt = lma.lma_fit_dqi_dqsi(lane,
                                    bin_size,
                                    1000.0*self.x393_mcntrl_timing.get_dly_steps()['SDCLK_PERIOD'], # 2500.0, # clk_period,
                                    78.0,   # dly_step_ds,
                                    primary_set,
                                    meas_delays,
                                    compare_prim_steps,
                                    scale_w,
                                    quiet)
        if quiet < 4:
            lma.showENLresults(rslt)

        self.adjustment_state["dqi_dqsi_parameters"]=rslt.pop('parameters')
        try:
            self.adjustment_state["maxErrDqsi"]=rslt.pop('maxErrDqs')
            if quiet < 4:
                print("maxErrDqsi={")
                for k,v in self.adjustment_state["maxErrDqsi"].items():
                    print ("'%s':%s,"%(k,str(v)))
                print ("}")
        except:
            print ("maxErrDqs does not exist")
            
        if quiet < 4:
            print ("dqi_dqsi={")
            for k,v in rslt.items():
                print ("'%s':%s,"%(k,str(v)))
            print ("}")
            
        self.adjustment_state["dqi_dqsi"]=rslt         
        return rslt

    def proc_dqsi_phase(self,
                       lane=0, # "all",
                       bin_size_ps=50,
                       data_set_number=0,        # not number - use measured data
                       scale_w=0.1,              # weight for "uncertain" values (where samples chane from all 0 to all 1 in one step)
                       quiet=1):
        """
        Run DQSI vs PHASE fitting for one data lane (0 or 1) using earlier acquired hard-coded data
        @param lane             byte lane to process (or non-number - process all byte lanes of the device) 
        @param bin_size_ps      histogram bin size (in ps)
        @param data_set_number  select one of the hard-coded data sets (sets 0 and 1 use comparing with the data 1 fine step below
                          set #0 (default) used measurement with previous primary step measurement (will not suffer from
                          fine range wider than on primary step)
                          If not number or <0 - use measured data
        @param scale_w        weight for "uncertain" values (where samples change from all 0 to all 1 in one step)
                        For sufficient data 0.0 is OK (and seems to work better)- only "analog" samples are considered   
        @param quiet reduce output
        @return 3-element dictionary of ('early','nominal','late'), each being None or a 160-element list,
                each element being either None, or a list of 3 best DQ delay values for the DQS delay (some mey be None too) 
        """
        if quiet < 3:
            print ("proc_dqsi_phase(): scale_w=%f"%(scale_w))
        if isinstance (data_set_number,(int,long)) and (data_set_number>=0) :
            self.load_hardcoded_data()
            if quiet < 4:
                print("Using hard-coded data set #%d"%data_set_number)
            compare_prim_steps= get_test_dq_dqs_data.get_dqsi_vs_phase_prim_steps(data_set_number)
            dqsi_phase_data=    get_test_dq_dqs_data.get_dqsi_vs_phase(data_set_number)
            dqsi_dqi_parameters=get_test_dq_dqs_data.get_dqi_dqsi_parameters()
        else:
            if quiet < 4:
                print("Using measured data set")
            try:
                compare_prim_steps=     self.adjustment_state["dqsi_vs_phase_steps"]
                dqsi_phase_data=         self.adjustment_state["dqsi_vs_phase"]
                dqsi_dqi_parameters=     self.adjustment_state["dqi_dqsi_parameters"]
            except:
                print ("DQS input delay vs. phase measured data is not available, exiting")
                return
        timing=self.x393_mcntrl_timing.get_dly_steps()
        numPhaseSteps= int(timing['SDCLK_PERIOD']/timing['PHASE_STEP']+0.5)
        lma=x393_lma.X393LMA() # use persistent one?
        
#        print("++++++proc_dqsi_phase(), quiet=",quiet)
            
        dqsi_phase=lma.lma_fit_dqsi_phase(lane, # byte lane
                                    bin_size_ps,
                                    1000.0*self.x393_mcntrl_timing.get_dly_steps()['SDCLK_PERIOD'], # 2500.0, # clk_period,
                                    dqsi_dqi_parameters,
                                    dqsi_phase_data, # data_set,
                                    compare_prim_steps,
                                    scale_w,
                                    numPhaseSteps,
                                    quiet)
        self.adjustment_state.update(dqsi_phase)
        return dqsi_phase

    def proc_dqo_dqso(self,
                       lane="all",
                       bin_size=5,
                       primary_set=2,
#                       compare_prim_steps=True, # while scanning, compare this delay with 1 less by primary(not fine) step,
#                                                # save None for fraction in unknown (previous -0.5, next +0.5)
                       data_set_number=0,        # not number - use measured data
                       scale_w=0.0,              # weight for "uncertain" values (where samples chane from all 0 to all 1 in one step)
 
                       quiet=1):
        """
        Run DQ vs DQS fitting for one data lane (0 or 1) using earlier acquired hard-coded data
        @param lane             byte lane to process (or non-number - process all byte lanes of the device) 
        @param bin_size         bin size for the histograms (should be 5/10/20/40)
        @param primary_set      which of the data edge series to use as leading (other will be trailing by 180) 
        @param data_set_number  select one of the hard-coded data sets (sets 0 and 1 use comparing with the data 1 fine step below
                          set #2 (default) used measurement with previous primary step measurement (will not suffer from
                          fine range wider than on primary step)
                          If not number or <0 - use measured data
        @param scale_w        weight for "uncertain" values (where samples change from all 0 to all 1 in one step)
                        For sufficient data 0.0 is OK (and seems to work better)- only "analog" samples are considered   
        @param quiet reduce output
        @return 3-element dictionary of ('early','nominal','late'), each being None or a 160-element list,
                each element being either None, or a list of 3 best DQ delay values for the DQS delay (some mey be None too) 
        """
        if quiet < 3:
            print ("proc_dqi_dqsi(): scale_w=%f"%(scale_w))
        if isinstance (data_set_number,(int,long)) and (data_set_number>=0) :
            if quiet < 4:
                print("Using hard-coded data set #%d"%data_set_number)
            compare_prim_steps=get_test_dq_dqs_data.get_compare_prim_steps_out(data_set_number)
            meas_data=get_test_dq_dqs_data.get_data_out(data_set_number)
        else:
            if quiet < 4:
                print("Using measured data set")
            try:
                compare_prim_steps=self.adjustment_state["write_prim_steps"]
                meas_data=         self.adjustment_state["write_meas_data"]
            except:
                print ("Pattern-measured data is not available, exiting")
                return
        meas_delays=[]
        for data in meas_data:
            if data:
                bits=[None]*16
                for b,pData in enumerate(data):
                    if pData:
                        bits[b]=[None]*4
                        for inPhase in (0,1):
                            if pData[inPhase]:
                                for e in (0,1):
                                    if pData[inPhase][e]:
                                        bits[b][inPhase*2+e]=pData[inPhase][e]# [0]
                meas_delays.append(bits)
        if quiet<1:
            x393_lma.test_data(meas_delays,compare_prim_steps,quiet)
        lma=x393_lma.X393LMA()
        rslt = lma.lma_fit_dqi_dqsi(lane,
                                    bin_size,
                                    1000.0*self.x393_mcntrl_timing.get_dly_steps()['SDCLK_PERIOD'], # 2500.0, # clk_period,
                                    78.0,   # dly_step_ds,
                                    primary_set,
                                    meas_delays,
                                    compare_prim_steps,
                                    scale_w,
                                    quiet)
        if quiet < 4:
            lma.showENLresults(rslt)

        self.adjustment_state["dqi_dqsi_parameters"]=rslt.pop('parameters')
        try:
            self.adjustment_state["maxErrDqso"]=rslt.pop('maxErrDqs')
            if quiet < 4:
                print("maxErrDqso={")
                for k,v in self.adjustment_state["maxErrDqso"].items():
                    print ("'%s':%s,"%(k,str(v)))
                print ("}")
        except:
            print ("maxErrDqs does not exist")
            
        if quiet < 4:
            print ("dqi_dqsi={")
            for k,v in rslt.items():
                print ("'%s':%s,"%(k,str(v)))
            print ("}")
        self.adjustment_state["dqo_dqso"]=rslt         

        return rslt
    
    def get_delays_vs_phase(self,
                            filter_dqo=2,
                            filter_dqi=2,
                            filter_dqso=2,
                            filter_dqsi=2,
                            filter_cmda=2,
                            keep_all=False,
                            set_table=True,
                            quiet=2):
        """
        Create list of valid "phases", after applying several filters. Each filter parameter can be
        one of 3 values: 0 - do not apply filter, 1 - OK if each of multiple bits fit for at least one
        early/nominal/late branch and 2 - all of the bits should fit the same branch
        @param filter_dqo   for DQ  output delays
        @param filter_dqi  for DQ  input delays
        @param filter_dqso  for DQS output delays
        @param filter_dqsi for DQS input delays
        @param filter_cmda for command and address output delays
        @param keep_all Keep phases where some delays do not have valid values, just mark them as None
               remove just items that do not have any non-None elements
        @param set_table store results to the global table (used to simultaneously set all pahse-derived
               delays in hardware
        @param quiet reduce output
        @return per-phase value list, each being none or a dictionary with optional fields "in" and "out"
                having values early/nominal/late
        
        """
#        self.load_hardcoded_data() # TODO: REMOVE LATER
        
        rslt_names=("early","nominal","late")
        timing=self.x393_mcntrl_timing.get_dly_steps()
        numPhaseSteps= int(timing['SDCLK_PERIOD']/timing['PHASE_STEP']+0.5)
        step180= int(NUM_FINE_STEPS*0.5* timing['SDCLK_PERIOD'] / timing['DLY_STEP'] +0.5)                                                                                                                                                                                                                 
        halfDlyRange=min(NUM_DLY_STEPS//2, step180) # minimum of half adjustment range of the delay and half SDCLK period
        if quiet <1:
            print ("halfDlyRange=",halfDlyRange)
        delays_phase=[]
        if filter_dqo:
            try:
                DQOvDQSO=self.adjustment_state["dqo_dqso"]
            except:
                print ('Data for filter_dqo is not available (self.adjustment_state["dqo_dqso"]')
                filter_dqo=0
            try:
                wlev_dqs_bspe=self.adjustment_state['wlev_dqs_bspe']
            except:
                print ('Data for filter_dqo requires data for filter_dqso and it is not available (self.adjustment_state["wlev_dqs_bspe"]')
                filter_dqo=0
        if filter_dqi:
            try:
                DQIvDQSI=self.adjustment_state["dqi_dqsi"]
            except:
                print ('Data for filter_dqi is not available (self.adjustment_state["dqi_dqsi"]')
                filter_dqi=0
            try:
                dqsi_phase=self.adjustment_state['dqsi_phase']
            except:
                print ('Data for filter_dqi requires data for filter_dqsi and it is not available (self.adjustment_state["dqsi_phase"]')
                filter_dqi=0
        if filter_dqso:
            try:
                wlev_dqs_bspe=self.adjustment_state['wlev_dqs_bspe']
            except:
                print ('Data for filter_dqso is not available (self.adjustment_state["wlev_dqs_bspe"]')
                filter_dqso=0
        if filter_dqsi:
            try:
                dqsi_phase=self.adjustment_state['dqsi_phase']
            except:
                print ('Data for filter_dqsi is not available (self.adjustment_state["dqsi_phase"]')
                filter_dqsi=0
        if filter_cmda:
            try:
                cmda_bspe=self.adjustment_state['cmda_bspe']
            except:
                print ('Data for filter_cmda is not available (self.adjustment_state["cmda_bspe"]')
                filter_cmda=0
        for phase in range(numPhaseSteps):
            delays_phase.append({})
            if filter_cmda:
                if (cmda_bspe[phase]['ldly'] is None) and (not keep_all):
                    delays_phase[phase]=None
                    continue # next phase
                else:
                    if not cmda_bspe[phase]['ldly'] is None:
                        delays_phase[phase]['cmda']=cmda_bspe[phase]['ldly']
                    #all(v is None for v in l)
            if filter_dqsi:
                dqsi=[dqsi_lane[phase] for dqsi_lane in dqsi_phase]
                if None in dqsi:
                    if keep_all:
                        if not all(v is None for v in dqsi):
                            delays_phase[phase]['dqsi']=dqsi
                    else:        
                        delays_phase[phase]=None
                        continue # next phase
                elif (filter_dqsi == 2) and ((max(dqsi) - min(dqsi)) > halfDlyRange):
                    delays_phase[phase]=None
                    continue # next phase
                else:
                    delays_phase[phase]['dqsi']=dqsi
            if filter_dqso:
                dqso=[None if wlev_lane[phase] is None else wlev_lane[phase]['ldly'] for wlev_lane in wlev_dqs_bspe]
                if None in dqso:
                    if keep_all:
                        if not all(v is None for v in dqso):
                            delays_phase[phase]['dqso']=dqso
                    else:        
                        delays_phase[phase]=None
                        continue # next phase
                elif (filter_dqsi == 2) and ((max(dqso) - min(dqso)) > halfDlyRange):
                    delays_phase[phase]=None
                    continue # next phase
                else:
                    delays_phase[phase]['dqso']=dqso
            if filter_dqi:
                dqsi=[dqsi_lane[phase] for dqsi_lane in dqsi_phase]
                if (None in dqsi) and (not keep_all):
                    delays_phase[phase]=None # phase for at least one of the DQSI is invalid
                    continue # next phase 
                else:
                    dqi_options={}
                    for k in rslt_names:
                        if (k in DQIvDQSI) and (not DQIvDQSI[k] is None):
                            dqi= sum([[None]*8 if (dqs is None) or (DQIvDQSI[k][dqs] is None) else DQIvDQSI[k][dqs][8*lane:8*(lane+1)] for lane,dqs in enumerate(dqsi)], [])
                            if keep_all:
                                if not all(v is None for v in dqi):
                                    dqi_options[k]=dqi
                            else:        
                                if None in dqi:
                                    continue # not this branch
                                elif (filter_dqi == 2) and ((max(dqi) - min(dqi)) > halfDlyRange):
                                    continue # failed filter, continue to the next branch
                                dqi_options[k]=dqi
                    if dqi_options:
                        delays_phase[phase]['dqi']=dqi_options
                    elif not keep_all:            
                        delays_phase[phase]=None
                        continue # next phase
                    """
                        
                            delays_phase[phase]['in']=k # found solution
                            delays_phase[phase]['dqi']=dqi
                            break
                    else:
                        delays_phase[phase]=None # phase for at least one of the DQSI is invalid
                        continue # next phase
                    """       
            if filter_dqo:
                dqso=[None if wlev_lane[phase] is None else wlev_lane[phase]['ldly'] for wlev_lane in wlev_dqs_bspe]
                if (None in dqso) and (not keep_all):
                    delays_phase[phase]=None # phase for at least one of the DQSI is invalid
                    continue # next phase 
                else:
                    dqo_options={}
                    for k in rslt_names:
                        if (k in DQOvDQSO) and (not DQOvDQSO[k] is None):
                            dqo= sum([[None]*8 if (dqs is None) or (DQOvDQSO[k][dqs] is None) else DQOvDQSO[k][dqs][8*lane:8*(lane+1)] for lane,dqs in enumerate(dqso)], [])
                            if keep_all:
                                if not all(v is None for v in dqo):
                                    dqo_options[k]=dqo
                            else:        
                                if None in dqo:
                                    continue # not this branch
                                elif (filter_dqi == 2) and ((max(dqo) - min(dqo)) > halfDlyRange):
                                    continue # failed filter, continue to the next branch
                                dqo_options[k]=dqo
                    if dqo_options:
                        delays_phase[phase]['dqo']=dqo_options
                    elif not keep_all:            
                        delays_phase[phase]=None
                        continue # next phase
                    """
                            delays_phase[phase]['out']=k # found solution
                            delays_phase[phase]['dqo']=dqo
                            break
                    else:
                        delays_phase[phase]=None # phase for at least one of the DQSI is invalid
                        continue # next phase
                    """
        if quiet <1:
            print("delays_phase=",delays_phase)
        if quiet < 2:
            print ("delays_phase=[")
            prev_none=False
            for phase_data in delays_phase:
                if phase_data is None:
                    if not prev_none:
                        print("\n    ",end="")
                    print ("None,",end=" ")
                    prev_none=True
                else:
                    if prev_none:
                        print()
                    print("    {")
                    for k,v in phase_data.items():
                        if isinstance(v,str):
                            v="'"+v+"'"
                        print ("     '%s':%s"%(k, str(v)))
                    print ("    },")
                    prev_none=False
            print("]")
            
        if quiet < 3:
            enl_list_in=[]
            enl_list_out=[]
            numBits=None
            for k in rslt_names:
                for phase_data in delays_phase:
                    try:
                        if k in phase_data["dqi"]:
                            enl_list_in.append(k)
                            break
                    except:
                        pass
                for phase_data in delays_phase:
                    try:
                        if k in phase_data["dqo"]:
                            enl_list_out.append(k)
                            break
                    except:
                        pass
                for phase_data in delays_phase:
                    try:
                        numBits=len(phase_data["dqi"].values()[0])
                        break
                    except:
                        pass
                    try:
                        numBits=len(phase_data["dqo"].values()[0])
                        break
                    except:
                        pass
            numLanes=numBits//8
            try:
                maxErrDqsi=self.adjustment_state["maxErrDqsi"]
            except:
                maxErrDqsi=None  
            try:
                maxErrDqso=self.adjustment_state["maxErrDqso"] 
            except:
                maxErrDqso=None  
            
            #print header
            print("Phase CMDA",end=" ")
            for lane in range(numLanes):
                print("DQS%di"%(lane),end=" ")
            for k in enl_list_in:
                for b in range(numBits):
                    print("%s-DQ%di"%(k.upper()[0], b),end=" ")
            for lane in range(numLanes):
                print("DQS%d0"%(lane),end=" ")
            #TODO: add DQ%do 
            for k in enl_list_out:
                for b in range(numBits):
                    print("%s-DQ%do"%(k.upper()[0], b),end=" ")
            for k in enl_list_in:
                print("%s-in-err"%(k.upper()[0]),end=" ")
            for k in enl_list_out:
                print("%s-out-err"%(k.upper()[0]),end=" ")
            print()    
            #print table rows
            for phase, phase_data in enumerate(delays_phase):
                print ("%d"%(phase),end=" ")
                if not phase_data is None:
                    try:
                        print ("%d"%(phase_data['cmda']),end=" ")
                    except:
                        print ("?",end=" ")
                    for lane in range(numLanes):
                        try:
                            print ("%d"%(phase_data['dqsi'][lane]),end=" ")
                        except:
                            print ("?",end=" ")
                    for k in enl_list_in: 
                        for b in range(numBits):
                            try:
                                print ("%d"%(phase_data['dqi'][k][b]),end=" ")
                            except:
                                print ("?",end=" ")
                    for lane in range(numLanes):
                        try:
                            print ("%d"%(phase_data['dqso'][lane]),end=" ")
                        except:
                            print ("?",end=" ")
                    for k in enl_list_out: 
                        for b in range(numBits):
                            try:
                                print ("%d"%(phase_data['dqo'][k][b]),end=" ")
                            except:
                                print ("?",end=" ")
                    for k in enl_list_in:
                        try:
                            if not None in phase_data['dqsi']:
                                max_err=max(maxErrDqsi[k][dly][lane] for lane,dly in enumerate(phase_data['dqsi']))
#                                for dly in phase_data['dqsi']:
#                                   err=maxErrDqsi[k][dly]
#                                    print("%.1f"%(err),end=" ")
                                print("%.1f"%(max_err),end=" ")
                            else:
                                print ("X",end=" ")
                        except:
                            print ("?",end=" ")
                    for k in enl_list_out:
                        try:
                            if not None in phase_data['dqso']:
                                max_err=max(maxErrDqso[k][dly][lane] for lane,dly in enumerate(phase_data['dqso']))
                                print("%.1f"%(max_err),end=" ")
                            else:
                                print ("x",end=" ")
                        except:
                            print ("?",end=" ")
                                
                print()

            if set_table:
                self.adjustment_state['delays_phase'] = delays_phase
        return delays_phase   
    
    def show_all_vs_phase(self,
                          keep_all=False,
                          load_hardcoded=False):
        '''
        Show table (to be copied to a spreadsheet) with all delay settings for each
        DDR3 memory clock phase value
        @param keep_all - show incomplete data (some of the delays may not have valid values
                          for selected clock phase, false - show only data for valid phases
        @param load_hardcoded - get hard-coded data (false - use current)
        '''
        if load_hardcoded:
            self.load_hardcoded_data()
            
        self.get_delays_vs_phase(
                            filter_dqo=2,
                            filter_dqi=2,
                            filter_dqso=2,
                            filter_dqsi=2,
                            filter_cmda=2,
                            keep_all=keep_all,
                            set_table=False,
                            quiet=2)    
