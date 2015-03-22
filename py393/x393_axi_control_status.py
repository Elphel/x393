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
#from import_verilog_parameters import VerilogParameters
from x393_mem import X393Mem
#from verilog_utils import hx,concat, bits 
from verilog_utils import hx
from time import time
import vrlg

enabled_channels=0 # currently enable channels
cke_en=0
cmda_en=0
sdrst_on=1
mcntrl_en=0
refresh_en=0
channel_priority=[None]*16
sequences_set=0
class X393AxiControlStatus(object):
    DRY_MODE= True # True
    DEBUG_MODE=1
#    vpars=None
    x393_mem=None
    FPGA_RST_CTRL=0xf8000240
    verbose=1
    def __init__(self, debug_mode=1,dry_mode=True):
        self.DEBUG_MODE=debug_mode
        self.DRY_MODE=dry_mode
        self.x393_mem=X393Mem(debug_mode,dry_mode)
        try:
            self.verbose=vrlg.VERBOSE
        except:
            pass
        
#        self.__dict__.update(VerilogParameters.__dict__["_VerilogParameters__shared_state"]) # Add verilog parameters to the class namespace
        '''
        Maybe import parameters into the module, not class namespace to use directly, w/o self. ?
#        __dict__.update(VerilogParameters.__dict__) # Add verilog parameters to the class namespace
        '''
        
        # Use 'import pickle' (exists in the camera) to save/restore state
    def init_state(self):
        global  enabled_channels, cke_en, cmda_en, sdrst_on, mcntrl_en, channel_priority, refresh_en, sequences_set
        """
        reset state (as after bitstream load)
        """
        enabled_channels=0 # currently enable channels
        cke_en=0
        cmda_en=0
        sdrst_on=1
        mcntrl_en=0
        channel_priority=[None]*16
        refresh_en=0
        sequences_set=0
        if self.verbose>0:
            print ("*** System state reset ****")
        # TODO: Add state save/restore in tmpfs file (like /var/state/...) (/var/state does not exist initially)
    def get_sequences_set(self,quiet=1):
        global  sequences_set
        if quiet<2 :
            print ("SEQUENCES SET =  %d"%sequences_set)
        return sequences_set

    def set_sequences_set(self,val,quiet=1):
        global  sequences_set
        val= (0,1)[val]
        sequences_set=val
        if quiet<2 :
            print ("SEQUENCES SET =  %d"%sequences_set)

    def get_cke_en(self,quiet=1):
        global  cke_en
        if quiet<2 :
            print ("CKE EN =  %d"%cke_en)
        return cke_en
    def get_cmda_en(self,quiet=1):
        global  cmda_en
        if quiet<2 :
            print ("CMDA EN =  %d"%cmda_en)
        return cmda_en
    def get_sdrst_on(self,quiet=1):
        global  sdrst_on
        if quiet<2 :
            print ("SDRST ON =  %d"%sdrst_on)
        return sdrst_on
    def get_mcntrl_en(self,quiet=1):
        global  mcntrl_en
        if quiet<2 :
            print ("MCNTRL ON =  %d"%mcntrl_en)
        return mcntrl_en
    def get_refresh_en(self,quiet=1):
        global refresh_en
        if quiet<2 :
            print ("REFRESH EN =  %d"%refresh_en)
        return refresh_en
    def get_enabled_channels(self,quiet=1):
        global  enabled_channels
        if quiet<2 :
            print ("ENABLED_CHANNELS =  0x%x"%enabled_channels)
        return enabled_channels

    def get_channel_priorities(self,quiet=1):
        global channel_priority
        if quiet<2 :
            print ("CHANNEL PRIORITIES:",end=" ")
            for v in channel_priority:
                if v is None:
                    print (" - ",end=" ")
                else:
                    print ("%d"%v,end=" ")
            print()        
        return channel_priority
    
    def get_state(self,quiet=1):
        return {
        'cke_en':             self.get_cke_en(quiet),
        'cmda_en':            self.get_cmda_en(quiet),
        'sdrst_on':           self.get_sdrst_on(quiet),
        'mcntrl_en':          self.get_mcntrl_en(quiet),
        'enabled_channels':   self.get_enabled_channels(quiet),
        'channel_priorities': self.get_channel_priorities(quiet),
        'refresh_en':         self.get_refresh_en(quiet),
        'sequences_set':      self.get_sequences_set(quiet)
        }
        
    def write_contol_register(self, reg_addr, data):
        """
        Write 32-bit word to the control register
        <addr> - register address relative to the control register address space
        <data> - 32-bit data to write
        """
        self.x393_mem.axi_write_single_w(vrlg.CONTROL_ADDR+reg_addr, data)
    def test_read_status(self, rpt): # was read_and_wait_status
        """
        Read word from the status register 0 and calculate part of the run busy
        <rpt> - number of times to repeat
        """
        num_busy=0
        for _ in range(rpt):
            num_busy+=(self.x393_mem.axi_read_addr_w(vrlg.STATUS_ADDR + 0)>>8) & 1
        ratio=(1.0* num_busy)/rpt
        print (("num_busy=%d, rpt=%d, ratio=%f"%(num_busy,rpt,100*ratio))+"%")
        return ratio
    def read_status(self, address): # was read_and_wait_status
        """
        Read word from the status register (up to 26 bits payload and 6-bit sequence number)
        <addr> - status register address (currently 0..255)
        """
        return self.x393_mem.axi_read_addr_w(vrlg.STATUS_ADDR + address )
    def wait_status_condition(self,
                              status_address,         # input [STATUS_DEPTH-1:0] status_address;
                              status_control_address, # input [29:0] status_control_address;
                              status_mode,            # input  [1:0] status_mode;
                              pattern,                # input [25:0] pattern;        // bits as in read registers
                              mask,                   # input [25:0] mask;           // which bits to compare
                              invert_match,           # input        invert_match;   // 0 - wait until match to pattern (all bits), 1 - wait until no match (any of bits differ)
                              wait_seq,               # input        wait_seq; // Wait for the correct sequence number, False assume correct
                              timeout=10.0):          # maximal timeout (0 - no timeout)
        """
        Poll specified status register until some condition is matched
        <status_address> -         status register address (currently 0..255)
        <status_control_address> - control register address (to control status generation)
        <status_mode>            - status generation mode:
                                  0: disable status generation,
                                  1: single status request,
                                  2: auto status, keep specified seq number,
                                  4: auto, inc sequence number 
        <pattern> -                26-bit pattern to match
        <mask> -                   26-bit mask to enable pattern matching (0-s - ignore)
        <invert_match> -           invert match (wait until matching condition becomes false)
        <wait_seq>-                wait for the correct sequence number, if False - assume always correct
        <timeout>                  maximal time to wait for condition
        Return 1 if success, 0 - if timeout
        """
        match=False
        endTime=None
        if timeout>0:
            endTime=time()+timeout
        while not match:
            data=self.read_status(status_address)
            if wait_seq:
                seq_num = ((data >> vrlg.STATUS_SEQ_SHFT) ^ 0x20) & 0x30
                self.write_contol_register(status_control_address, ((status_mode & 3) <<6) | (seq_num & 0x3f))
                data=self.read_status(status_address)
                while (((data >> vrlg.STATUS_SEQ_SHFT) ^ seq_num) & 0x30) !=0:
                    data=self.read_status(status_address)
                    if self.DRY_MODE: break
                    if timeout and (time()>endTime):
                        print("TIMEOUT in wait_status_condition(status_address=0x%x,status_control_address=0x%x,pattern=0x%x,mask=0x%x,timeout=%f)"%
                               (status_address,status_control_address,pattern,mask,timeout))
                        print ("last read status data is 0x%x, written seq number is 0x%x"%(data,seq_num))
                        return 0
            match = (((data ^ pattern) & mask & 0x3ffffff)==0)
            if invert_match:
                match = not match
            if self.DRY_MODE: break
            if timeout and (time()>endTime):
                print("TIMEOUT1 in wait_status_condition(status_address=0x%x,status_control_address=0x%x,pattern=0x%x,mask=0x%x,timeout=%f)"%
                    (status_address,status_control_address,pattern,mask,timeout))
                print ("last read status data is 0x%x"%(data))
                return 0
        return 1

    def read_all_status(self):
        """
        Read and print contents of all defined status registers
        """
#        print (self.__dict__)
#        for name in self.__dict__:
#            print (name+": "+str(name=='MCONTR_PHY_STATUS_REG_ADDR'))
#        print (self.__dict__['MCONTR_PHY_STATUS_REG_ADDR'])
        print ("MCONTR_PHY_STATUS_REG_ADDR:          %s"%(hx(self.read_status(vrlg.MCONTR_PHY_STATUS_REG_ADDR),8)))
        print ("MCONTR_TOP_STATUS_REG_ADDR:          %s"%(hx(self.read_status(vrlg.MCONTR_TOP_STATUS_REG_ADDR),8)))
        print ("MCNTRL_PS_STATUS_REG_ADDR:           %s"%(hx(self.read_status(vrlg.MCNTRL_PS_STATUS_REG_ADDR) ,8)))
        print ("MCNTRL_SCANLINE_STATUS_REG_CHN1_ADDR:%s"%(hx(self.read_status(vrlg.MCNTRL_SCANLINE_STATUS_REG_CHN1_ADDR),8)))
        print ("MCNTRL_SCANLINE_STATUS_REG_CHN3_ADDR:%s"%(hx(self.read_status(vrlg.MCNTRL_SCANLINE_STATUS_REG_CHN3_ADDR),8)))
        print ("MCNTRL_TILED_STATUS_REG_CHN2_ADDR:   %s"%(hx(self.read_status(vrlg.MCNTRL_TILED_STATUS_REG_CHN2_ADDR),8)))
        print ("MCNTRL_TILED_STATUS_REG_CHN4_ADDR:   %s"%(hx(self.read_status(vrlg.MCNTRL_TILED_STATUS_REG_CHN4_ADDR),8)))
        print ("MCNTRL_TEST01_STATUS_REG_CHN1_ADDR:  %s"%(hx(self.read_status(vrlg.MCNTRL_TEST01_STATUS_REG_CHN1_ADDR),8)))
        print ("MCNTRL_TEST01_STATUS_REG_CHN2_ADDR:  %s"%(hx(self.read_status(vrlg.MCNTRL_TEST01_STATUS_REG_CHN2_ADDR),8)))
        print ("MCNTRL_TEST01_STATUS_REG_CHN3_ADDR:  %s"%(hx(self.read_status(vrlg.MCNTRL_TEST01_STATUS_REG_CHN3_ADDR),8)))
        print ("MCNTRL_TEST01_STATUS_REG_CHN4_ADDR:  %s"%(hx(self.read_status(vrlg.MCNTRL_TEST01_STATUS_REG_CHN4_ADDR),8)))

    def program_status(self,
                       base_addr,   # input [29:0] base_addr;
                       reg_addr,    # input  [7:0] reg_addr;
                       mode,        # input  [1:0] mode;
                       seq_number): # input  [5:0] seq_number;
        """
        Program status control for specified module/register
        <base_addr> -  base control address of the selected module
        <reg_addr> -   status control register relative to the module address space
        <mode> -       status generation mode:
                                  0: disable status generation,
                                  1: single status request,
                                  2: auto status, keep specified seq number,
                                  4: auto, inc sequence number 
        <seq_number> - 6-bit sequence number of the status message to be sent
        """
        self.write_contol_register(base_addr + reg_addr, ((mode & 3)<< 6) | (seq_number * 0x3f))


    def program_status_all( self,
                            mode,     # input [1:0] mode;
                            seq_num): # input [5:0] seq_num;
        """
        Set status generation mode for all defined modules
        <mode> -       status generation mode:
                                  0: disable status generation,
                                  1: single status request,
                                  2: auto status, keep specified seq number,
                                  4: auto, inc sequence number 
        <seq_number> - 6-bit sequence number of the status message to be sent
        """

        self.program_status (vrlg.MCONTR_PHY_16BIT_ADDR,     vrlg.MCONTR_PHY_STATUS_CNTRL,        mode,seq_num)# //MCONTR_PHY_STATUS_REG_ADDR=          'h0,
        self.program_status (vrlg.MCONTR_TOP_16BIT_ADDR,     vrlg.MCONTR_TOP_16BIT_STATUS_CNTRL,  mode,seq_num)# //MCONTR_TOP_STATUS_REG_ADDR=          'h1,
        self.program_status (vrlg.MCNTRL_PS_ADDR,            vrlg.MCNTRL_PS_STATUS_CNTRL,         mode,seq_num)# //MCNTRL_PS_STATUS_REG_ADDR=           'h2,
        self.program_status (vrlg.MCNTRL_SCANLINE_CHN1_ADDR, vrlg.MCNTRL_SCANLINE_STATUS_CNTRL,   mode,seq_num)#; //MCNTRL_SCANLINE_STATUS_REG_CHN2_ADDR='h4,
        self.program_status (vrlg.MCNTRL_SCANLINE_CHN3_ADDR, vrlg.MCNTRL_SCANLINE_STATUS_CNTRL,   mode,seq_num)# //MCNTRL_SCANLINE_STATUS_REG_CHN3_ADDR='h5,
        self.program_status (vrlg.MCNTRL_TILED_CHN2_ADDR,    vrlg.MCNTRL_TILED_STATUS_CNTRL,      mode,seq_num)# //MCNTRL_TILED_STATUS_REG_CHN4_ADDR=   'h6,
        self.program_status (vrlg.MCNTRL_TILED_CHN4_ADDR,    vrlg.MCNTRL_TILED_STATUS_CNTRL,      mode,seq_num)#; //MCNTRL_TILED_STATUS_REG_CHN4_ADDR=   'h6,
        self.program_status (vrlg.MCNTRL_TEST01_ADDR,        vrlg.MCNTRL_TEST01_CHN1_STATUS_CNTRL,mode,seq_num)#; //MCNTRL_TEST01_STATUS_REG_CHN2_ADDR=  'h3c,
        self.program_status (vrlg.MCNTRL_TEST01_ADDR,        vrlg.MCNTRL_TEST01_CHN2_STATUS_CNTRL,mode,seq_num)#; //MCNTRL_TEST01_STATUS_REG_CHN2_ADDR=  'h3c,
        self.program_status (vrlg.MCNTRL_TEST01_ADDR,        vrlg.MCNTRL_TEST01_CHN3_STATUS_CNTRL,mode,seq_num)#; //MCNTRL_TEST01_STATUS_REG_CHN3_ADDR=  'h3d,
        self.program_status (vrlg.MCNTRL_TEST01_ADDR,        vrlg.MCNTRL_TEST01_CHN4_STATUS_CNTRL,mode,seq_num)#; //MCNTRL_TEST01_STATUS_REG_CHN4_ADDR=  'h3e,
        
    def enable_cmda(self,
                    en): # input en;
        """
        Enable (disable) address, bank and command lines to the DDR3 memory
        <en> - 1 - enable, 0 - disable
        """
        global cmda_en
        en=(0,1)[en]
        if self.verbose>0:
            print ("ENABLE CMDA %s"%str(en))
        self.write_contol_register(vrlg.MCONTR_PHY_0BIT_ADDR +  vrlg.MCONTR_PHY_0BIT_CMDA_EN + en, 0);
        cmda_en=en
            
    def enable_cke(self,
                    en): # input en;
        """
        Enable (disable) CKE - clock enable to DDR3 memory 
        <en> - 1 - enable, 0 - disable
        """
        global  cke_en
        en=(0,1)[en]
        if self.verbose>0:
            print ("ENABLE CKE %s"%str(en))
        self.write_contol_register(vrlg.MCONTR_PHY_0BIT_ADDR +  vrlg.MCONTR_PHY_0BIT_CKE_EN + en, 0);
        cke_en=en

    def activate_sdrst(self,
                    en): # input en;
        """
        Activate SDRST (reset) to DDR3 memory 
        <en> - 1 - activate (low), 0 - deactivate (high)
        """
        global sdrst_on
        en=(0,1)[en]
        if self.verbose>0:
            print ("ACTIVATE SDRST %s"%str(en))
        self.write_contol_register(vrlg.MCONTR_PHY_0BIT_ADDR +  vrlg.MCONTR_PHY_0BIT_SDRST_ACT + en, 0);
        sdrst_on=en

    def enable_refresh(self,
                       en): # input en;
        """
        Enable (disable) refresh of the DDR3 memory 
        <en> - 1 - enable, 0 - disable
        """
        global  refresh_en
        en=(0,1)[en]
        if self.verbose>0:
            print ("ENABLE REFRESH %s"%str(en))
        self.write_contol_register(vrlg.MCONTR_TOP_0BIT_ADDR +  vrlg.MCONTR_TOP_0BIT_REFRESH_EN + en, 0);
        refresh_en=en
        
    def enable_memcntrl(self,
                        en): # input en;
        """
        Enable memory controller module 
        <en> - 1 - enable, 0 - disable
        """
        global  mcntrl_en
        en=(0,1)[en]
        if self.verbose>0:
            print ("ENABLE MEMCTRL %s"%str(en))
        self.write_contol_register(vrlg.MCONTR_TOP_0BIT_ADDR +  vrlg.MCONTR_TOP_0BIT_MCONTR_EN + en, 0);
        mcntrl_en=en
    def enable_memcntrl_channels(self,
                                 chnen): # input [15:0] chnen; // bit-per-channel, 1 - enable;
        """
        Enable memory controller channels (all at once control) 
        <chnen> - 16-bit control word with per-channel enable bits (bit0 - chn0, ... bit15 - chn15)
        """
        global  enabled_channels
        enabled_channels = chnen # currently enabled memory channels
        self.write_contol_register(vrlg.MCONTR_TOP_16BIT_ADDR +  vrlg.MCONTR_TOP_16BIT_CHN_EN, enabled_channels & 0xffff) # {16'b0,chnen});
        if self.verbose>0:
            print ("ENABLED MEMCTRL CHANNELS 0x%x (word)"%enabled_channels)

    def enable_memcntrl_en_dis(self,
                               chn, # input [3:0] chn;
                               en):# input       en;
        """
        Enable memory controller channels (one at a time) 
        <chn> - 4-bit channel select
        <en> -  1 - enable, 0 - disable of the selected channel
        """
        global  enabled_channels
        if en:
            enabled_channels |=  1<<chn;
        else:
            enabled_channels &= ~(1<<chn);
        self.write_contol_register(vrlg.MCONTR_TOP_16BIT_ADDR + self. MCONTR_TOP_16BIT_CHN_EN, enabled_channels & 0xffff) #  {16'b0,ENABLED_CHANNELS});
        if self.verbose>0:
            print ("ENABLED MEMCTRL CHANNELS 0x%x (en/dis)"%enabled_channels)

    def configure_channel_priority(self,
                                   chn, # input [ 3:0] chn;
                                   priority=0): #input [15:0] priority; // (higher is more important)
        """
        Configure channel priority  
        <chn> -      4-bit channel select
        <priority> - 16-bit priority value (higher value means more important)
        """
        global channel_priority
        self.write_contol_register(vrlg.MCONTR_ARBIT_ADDR + chn, priority  & 0xffff)# {16'b0,priority});
        if self.verbose>0:
            print ("SET CHANNEL %d priority=0x%x"%(chn,priority))
        channel_priority[chn]=priority

