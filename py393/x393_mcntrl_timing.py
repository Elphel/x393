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
#x393_pio_sequences
#from import_verilog_parameters import VerilogParameters
from x393_mem import X393Mem
#from x393_axi_control_status import X393AxiControlStatus
import x393_axi_control_status
#from verilog_utils import * # concat, bits 
#from verilog_utils import hx, concat, bits, getParWidth 
from verilog_utils import concat, getParWidth,hexMultiple
#from x393_axi_control_status import concat, bits
import vrlg # global parameters
#from x393_utils import X393Utils
class X393McntrlTiming(object):
    DRY_MODE= True # True
    DEBUG_MODE=1
    x393_mem=None
    x393_axi_tasks=None #x393X393AxiControlStatus
    x393_utils=None
    def __init__(self, debug_mode=1,dry_mode=True):
        self.DEBUG_MODE=debug_mode
        self.DRY_MODE=dry_mode
        self.x393_mem=X393Mem(debug_mode,dry_mode)
        self.x393_axi_tasks=x393_axi_control_status.X393AxiControlStatus(debug_mode,dry_mode)
#        self.__dict__.update(VerilogParameters.__dict__["_VerilogParameters__shared_state"]) # Add verilog parameters to the class namespace

    def get_dly_steps(self):
        #hardwired in phy_top.v 
#        CLKOUT0_DIVIDE_F= 2.000
        CLKOUT1_DIVIDE  = 2
#        CLKOUT2_DIVIDE  = 4
        fCLK_IN=1000.0/vrlg.CLKIN_PERIOD
        fVCO=fCLK_IN*vrlg.CLKFBOUT_MULT
        fSDCLK=fVCO/CLKOUT1_DIVIDE
        tSDCLK=1000.0/fSDCLK # in ns
        phaseStep=1000.0/(fVCO*56.0) # 1 unit of phase shift (now 112 for the full period
        fREF=fCLK_IN*vrlg.CLKFBOUT_MULT_REF/vrlg.CLKFBOUT_DIV_REF
        dlyStep=1000.0/fREF/32/2 # Approximate, depending on calibration
        dlyFStep=0.01 # fine step 
        return{"SDCLK_PERIOD":tSDCLK,
               "PHASE_STEP":phaseStep,
               "DLY_STEP":dlyStep,
               "DLY_FINE_STEP":dlyFStep}
        
    def axi_set_phase(self,
                      phase=None,      # input [PHASE_WIDTH-1:0] phase;
                      wait_phase_en=True,
                      wait_seq=False,
                      quiet=1):
        """
        Set clock phase TODO: Add refresh off/on for changing phase
        <phase>    8-bit clock phase value (None will use default)
        <wait_phase_en> compare phase shift to programmed (will not work if the program was restarted)
        <wait_seq> read and re-send status request to make sure status reflects new data (just for testing, too fast for Python)
        @param quiet reduce output
        Returns 1 if success, 0 if timeout (or no wait was performed)
        """
        if phase is None:
            phase= vrlg.get_default("DLY_PHASE") 
        vrlg.DLY_PHASE=phase & ((1<<vrlg.PHASE_WIDTH)-1)
        if quiet<2:
            print("SET CLOCK PHASE=0x%x"%(vrlg.DLY_PHASE))
        self.x393_axi_tasks.write_control_register(vrlg.LD_DLY_PHASE,vrlg.DLY_PHASE) # {{(32-PHASE_WIDTH){1'b0}},phase}); // control register address
        self.x393_axi_tasks.write_control_register(vrlg.DLY_SET,0)
#        self.target_phase = phase
        if wait_phase_en:
            return self.wait_phase(True, wait_seq)
        return 0    

    def wait_phase(self,
                   check_phase_value=True,
                   wait_seq=False):
        """
        Wait for the phase shifter
        <check_phase_value> compare phase shift to programmed (will not work if the program was restarted)
        <wait_seq> read and re-send status request to make sure status reflects new data (just for testing, too fast for Python)
        Returns 1 if success, 0 if timeout
        """
        patt = 0x3000000 | vrlg.DLY_PHASE
        mask = 0x3000100
        if check_phase_value:
            mask |= 0xff
        return self.x393_axi_tasks.wait_status_condition(
                              vrlg.MCONTR_PHY_STATUS_REG_ADDR,                                # status_address,
                              vrlg.MCONTR_PHY_16BIT_ADDR + vrlg.MCONTR_PHY_STATUS_CNTRL,      # status_control_address,
                              3,                                                              # status_mode,
                              patt,                                                           # pattern,
                              mask,                                                           # mask
                              0,                                                              # invert_match
                              wait_seq,                                                       # wait_seq;
                              1.0)                                                            # maximal timeout (0 - no timeout)
       
        
    def get_target_phase(self):
        """
        Returns previously set clock phase value
        """
        return vrlg.DLY_PHASE
    def axi_set_same_delays(self,         #
                            dq_idelay,    # input [7:0] dq_idelay;
                            dq_odelay,    # input [7:0] dq_odelay;
                            dqs_idelay,   # input [7:0] dqs_idelay;
                            dqs_odelay,   # input [7:0] dqs_odelay;
                            dm_odelay,    # input [7:0] dm_odelay;
                            cmda_odelay): # input [7:0] cmda_odelay;
        """
        Set I/O delays for the DDR3 memory, same delay for all signals in the same class
        Each delay value is 8-bit, 5 MSB program in equal steps (=360/32 degrees each),
        and 3 LSB (valid values are 0..4) add additional non-calibrated 10ps delay 
        <dq_idelay>    input delay for DQ lines
        <dq_odelay>    output delay for DQ lines
        <dqs_idelay>   input delay for DQS lines
        <dqs_odelay>   output delay for DQS lines
        <dm_odelay>     input delay for DM lines
        <cmda_odelay>  output delay for DM lines
        """
        
        if self.DEBUG_MODE > 1:
            print("SET DELAYS(0x%x,0x%x,0x%x,0x%x,0x%x,0x%x)"%(dq_idelay,dq_odelay,dqs_idelay,dqs_odelay,dm_odelay,cmda_odelay))
        self.axi_set_dq_idelay(dq_idelay)
        self.axi_set_dq_odelay(dq_odelay)
        self.axi_set_dqs_idelay(dqs_idelay)
        self.axi_set_dqs_odelay(dqs_odelay)
        self.axi_set_dm_odelay(dm_odelay)
        self.axi_set_cmda_odelay(cmda_odelay)

    def axi_set_dqs_idelay_wlv(self):
        """
        Set DQS input delays to values defined for the write levelling mode (parameter-defined)
        """
        self.axi_set_multiple_delays(vrlg.LD_DLY_LANE0_IDELAY, 8, 1, vrlg.DLY_LANE0_DQS_WLV_IDELAY, "DLY_LANE0_IDELAY")
        self.axi_set_multiple_delays(vrlg.LD_DLY_LANE1_IDELAY, 8, 1, vrlg.DLY_LANE1_DQS_WLV_IDELAY, "DLY_LANE1_IDELAY")
#        self.x393_axi_tasks.write_control_register(vrlg.LD_DLY_LANE0_IDELAY + 8,      vrlg.DLY_LANE0_DQS_WLV_IDELAY)
#        self.x393_axi_tasks.write_control_register(vrlg.LD_DLY_LANE1_IDELAY + 8,      vrlg.DLY_LANE1_DQS_WLV_IDELAY)
        self.x393_axi_tasks.write_control_register(vrlg.DLY_SET,0)

    def axi_set_delays(self,quiet=1): #  set all individual delays
        """
        Set all DDR3 I/O delays to individual parameter-defined values (using default values,
        current ones are supposed to be synchronized)
        """
        self.axi_set_dq_idelay(quiet=quiet)
        self.axi_set_dqs_idelay(quiet=quiet)
        self.axi_set_dq_odelay(quiet=quiet)
        self.axi_set_dqs_odelay(quiet=quiet)
        self.axi_set_dm_odelay(quiet=quiet)
        self.axi_set_cmda_odelay(quiet=quiet)
        self.axi_set_phase(quiet=quiet)
        
    def axi_set_dq_idelay(self,   #  sets same delay to all dq idelay
                          delay=None, # input [7:0] delay;
                          quiet=1):
        """
        Set all DQ input delays to the same value
        @param delay 8-bit (5+3) delay value to use or a tuple/list with a pair for (lane0, lane1)
                Each of the two elements in the delay tuple/list may be a a common integer or a list/tuple itself
                if delay is None will restore default values
                Alternatively it can be a one-level list/tuple covering all (16) delays
        @param quiet reduce output                  
        """
#        print("====axi_set_dq_idelay %s"%str(delay))
        
        if delay is None:
            delay=[[],[]]
            for i in range(8):
                delay[0].append(vrlg.get_default_field("DLY_LANE0_IDELAY",i))
                delay[1].append(vrlg.get_default_field("DLY_LANE1_IDELAY",i))
        if isinstance(delay,(int,long)):
            delay=(delay,delay)
        elif len(delay) % 8 == 0 :
            delay2=[]
            for lane in range(len(delay)//8):
                delay2.append(delay[8*lane:8*(lane+1)])
            delay=delay2
        if quiet < 2:
            print("SET DQ IDELAY="+hexMultiple(delay)) # hexMultiple
        self.axi_set_multiple_delays(vrlg.LD_DLY_LANE0_IDELAY, 0, 8, delay[0], "DLY_LANE0_IDELAY")
        self.axi_set_multiple_delays(vrlg.LD_DLY_LANE1_IDELAY, 0, 8, delay[1], "DLY_LANE1_IDELAY")
        self.x393_axi_tasks.write_control_register  (vrlg.DLY_SET,0);# // set all delays
        
    def axi_set_dq_odelay(self,
                          delay=None, # input [7:0] delay;
                          quiet=1):

        """
        Set all DQ OUTput delays to the same value
        @param delay 8-bit (5+3) delay value to use or a tuple/list with a pair for (lane0, lane1)
                Each of the two elements in the delay tuple/list may be a a common integer or a list/tuple itself
                if delay is None will restore default values
                Alternatively it can be a one-level list/tuple covering all (16) delays
        @param quiet reduce output                  
        """
        if delay is None:
            delay=[[],[]]
            for i in range(8):
                delay[0].append(vrlg.get_default_field("DLY_LANE0_ODELAY",i))
                delay[1].append(vrlg.get_default_field("DLY_LANE1_ODELAY",i))
        if isinstance(delay,(int,long)):
            delay=(delay,delay)
        elif len(delay) % 8 == 0 :
            delay2=[]
            for lane in range(len(delay)//8):
                delay2.append(delay[8*lane:8*(lane+1)])
            delay=delay2
        if quiet < 2:
            print("SET DQ ODELAY="+hexMultiple(delay)) # hexMultiple
        self.axi_set_multiple_delays(vrlg.LD_DLY_LANE0_ODELAY, 0, 8, delay[0], "DLY_LANE0_ODELAY");
        self.axi_set_multiple_delays(vrlg.LD_DLY_LANE1_ODELAY, 0, 8, delay[1], "DLY_LANE1_ODELAY");
        self.x393_axi_tasks.write_control_register(vrlg.DLY_SET,0); # set all delays
        
    def axi_set_dqs_idelay(self,
                           delay=None, # input [7:0] delay;
                           quiet=1):
        """
        Set all DQs input delays to the same value
        @param delay 8-bit (5+3) delay value to use or a tuple/list with a pair for (lane0, lane1)
                if delay is None will restore default values
        @param quiet reduce output                  
        """
        if delay is None:
            delay=(vrlg.get_default_field("DLY_LANE0_IDELAY",8),vrlg.get_default_field("DLY_LANE1_IDELAY",8))
        if isinstance(delay,(int,long)):
            delay=(delay,delay)
        if quiet < 2:
            print("SET DQS IDELAY="+hexMultiple(delay)) # hexMultiple
        self.axi_set_multiple_delays(vrlg.LD_DLY_LANE0_IDELAY, 8, 1, delay[0], "DLY_LANE0_IDELAY")
        self.axi_set_multiple_delays(vrlg.LD_DLY_LANE1_IDELAY, 8, 1, delay[1], "DLY_LANE1_IDELAY")
        self.x393_axi_tasks.write_control_register(vrlg.DLY_SET,0); # set all delays

    def axi_set_dqs_odelay(self,
                           delay=None, # input [7:0] delay;
                           quiet=1):
        """
        Set all DQs OUTput delays to the same value
        @param delay 8-bit (5+3) delay value to use or a tuple/list with a pair for (lane0, lane1)
                if delay is None will restore default values
        @param quiet reduce output                  
                
        """
        if delay is None:
            delay=(vrlg.get_default_field("DLY_LANE0_ODELAY",8),vrlg.get_default_field("DLY_LANE1_ODELAY",8))
        if isinstance(delay,(int,long)):
            delay=(delay,delay)
        if quiet < 2:
            print("SET DQS ODELAY="+hexMultiple(delay)) # hexMultiple
        self.axi_set_multiple_delays(vrlg.LD_DLY_LANE0_ODELAY, 8, 1, delay[0], "DLY_LANE0_ODELAY")
        self.axi_set_multiple_delays(vrlg.LD_DLY_LANE1_ODELAY, 8, 1, delay[1], "DLY_LANE1_ODELAY")
        self.x393_axi_tasks.write_control_register(vrlg.DLY_SET,0); # set all delays

    def axi_set_dm_odelay (self,
                           delay=None, # input [7:0] delay;
                           quiet=1):
        """
        Set all DM output delays to the same value
        @param delay 8-bit (5+3) delay value to use or a tuple/list with a pair for (lane0, lane1)
                if delay is None will restore default values
        @param quiet reduce output                  
        """
        if delay is None:
            delay=(vrlg.get_default_field("DLY_LANE0_ODELAY",9),vrlg.get_default_field("DLY_LANE1_ODELAY",9))
        if isinstance(delay,(int,long)):
            delay=(delay,delay)
        if quiet < 2:
            print("SET DQM IDELAY="+hexMultiple(delay)) # hexMultiple
        self.axi_set_multiple_delays(vrlg.LD_DLY_LANE0_ODELAY, 9, 1, delay[0], "DLY_LANE0_ODELAY")
        self.axi_set_multiple_delays(vrlg.LD_DLY_LANE1_ODELAY, 9, 1, delay[1], "DLY_LANE1_ODELAY")
        self.x393_axi_tasks.write_control_register(vrlg.DLY_SET,0) #  set all delays

    def axi_set_cmda_odelay(self,
                               delay=None, # input [7:0] delay;
                               indx=None, # address index
                               quiet=1):
        """
        Set all command/address output delays to the same value (or a list/tuple of the individual ones)
        @param delay 8-bit (5+3) delay value to use or list/tuple containing individual values
                List elements may be None, those values will not be overwritten
                if delay is None will restore default values
        @param indx  if present, delay only applies to the specified index (delay should be int/long)
        @param quiet reduce output                  
        """
        if delay is None:
            delay=[]
            for i in range(0,32):
                if (indx is None) or (i == indx) :
                    delay.append(vrlg.get_default_field("DLY_CMDA",i))
                else:
                    delay.append(None)
        if isinstance(delay,(int,long)):
            delay=[delay]*32 # all address/commands
            if not indx is None:
                for i in range(len(delay)):
                    if (i != indx):
                        delay[i]=None
        if quiet < 2:
            print("SET COMMAND and ADDRESS ODELAY"+hexMultiple(delay))
        self.axi_set_multiple_delays(vrlg.LD_DLY_CMDA, 0, 32, delay, "DLY_CMDA");
        self.x393_axi_tasks.write_control_register(vrlg.DLY_SET,0)  # set all delays

    def axi_set_address_odelay(self,
                               delay=None, # input [7:0] delay;
                               indx=None, # address index
                               quiet=1):
        """
        Set output delays for address lines only
        @param delay 8-bit (5+3) delay value to use or list/tuple containing individual values
                List elements may be None, those values will not be overwritten
                if delay is None will restore default values
        @param indx  if present, delay only applies to the specified index (delay should be int/long)                  
        @param quiet reduce output                  
        """
        if delay is None:
            delay=[]
            for i in range(0,vrlg.ADDRESS_NUMBER):
                if (indx is None) or (i == indx) :
                    delay.append(vrlg.get_default_field("DLY_CMDA",i))
                else:
                    delay.append(None)
        if isinstance(delay,(int,long)):
            delay=[delay]*vrlg.ADDRESS_NUMBER
            if not indx is None:
                for i in range(len(delay)):
                    if (i != indx):
                        delay[i]=None
        if quiet < 2:
            print("SET ADDRESS ODELAY="+hexMultiple(delay))
        self.axi_set_multiple_delays(vrlg.LD_DLY_CMDA, 0, 0, delay, "DLY_CMDA") 
        self.x393_axi_tasks.write_control_register(vrlg.DLY_SET,0)  # set all delays
        
    def axi_set_bank_odelay(self,
                            delay=None, # input [7:0] delay;
                            indx=None, # address index
                            quiet=1):
                            
        """
        Set output delays for bank lines only
        @param delay    8-bit (5+3) delay value to use or list/tuple containing individual values
                   List elements may be None, those values will not be overwritten
                if delay is None will restore default values
        @param indx  if present, delay only applies to the specified index (delay should be int/long)                  
        @param quiet reduce output                  
        """
        bank_offset=24
        if delay is None:
            delay=[]
            for i in range(3):
                if (indx is None) or (i == indx) :
                    delay.append(vrlg.get_default_field("DLY_CMDA",i+bank_offset))
                else:
                    delay.append(None)
        if isinstance(delay,(int,long)):
            delay=[delay]*3
            if not indx is None:
                for i in range(len(delay)):
                    if (i != indx):
                        delay[i]=None
        if quiet < 2:
            print("SET BANK ODELAY="+hexMultiple(delay))
        self.axi_set_multiple_delays(vrlg.LD_DLY_CMDA, bank_offset, 0,delay, "DLY_CMDA")  # length will be determined by len(delay)
        self.x393_axi_tasks.write_control_register(vrlg.DLY_SET,0)  # set all delays

    def axi_set_cmd_odelay(self,
                           delay=None, # input [7:0] delay;
                           indx=None, # address index
                           quiet=1):
        """
        Set output delays for command lines only. command=(we,ras,cas,cke,odt)
        @param delay    8-bit (5+3) delay value to use or list/tuple containing individual values
                   List elements may be None, those values will not be overwritten
                   if delay is None will restore default values
        @param indx  if present, delay only applies to the specified index (delay should be int/long)
        @param quiet reduce output                  
        """
        command_offset=24+3
        if delay is None:
            delay=[]
            for i in range(5):
                if (indx is None) or (i == indx) :
                    delay.append(vrlg.get_default_field("DLY_CMDA",i+command_offset))
                else:
                    delay.append(None)
        if isinstance(delay,(int,long)):
            delay=[delay]*5
            if not indx is None:
                for i in range(len(delay)):
                    if (i != indx):
                        delay[i]=None
        if quiet < 2:
            print("SET COMMAND ODELAY="+hexMultiple(delay))
        self.axi_set_multiple_delays(vrlg.LD_DLY_CMDA, command_offset, 0,delay, "DLY_CMDA")  # length will be determined by len(delay)
        self.x393_axi_tasks.write_control_register(vrlg.DLY_SET,0)  # set all delays
        
        
    def axi_set_multiple_delays(self,
                                reg_addr, #input [29:0] reg_addr;
                                offset,   # add this offset to address
                                number,   # input integer number;
                                delay,    # input [7:0]  delay;
                                vname):   # Verilog parameter name (if None - do not update Verilog parameter value (it is already it)
        """
        Set same delay to a range of I/O delay registers
        <reg_addr> control register address of the first register in the range
        <offset>   add this offset to address
        <number>   number of registers to write
        @param delay    8-bit (5+3) delay value to use or list/tuple containing individual values
                   List elements may be None, those values will not be overwritten
        <vname>    Verilog parameter name
        """
#        print ("===axi_set_multiple_delays(0x%x,%d,%s"%(reg_addr,number,delay))
        if delay is None: return # Do nothing, that's OK
        if isinstance(delay,(int,long)):
            delay=[delay]*number
        if len(delay) < number:
            delay= delay + [None]*(number-len(delay)) #
        for i, d in enumerate(delay):
            if not d is None:
                self.x393_axi_tasks.write_control_register(reg_addr + (offset + i), d)
                if vname:
                    vrlg.set_name_field(vname, offset + i, d)

    def wait_phase_shifter_ready(self):
        """
        Wait until clock phase shifter is ready
        """
        data=self.x393_axi_tasks.read_status(vrlg.MCONTR_PHY_STATUS_REG_ADDR)
        while (((data & vrlg.STATUS_PSHIFTER_RDY_MASK) == 0) or (((data ^ vrlg.DLY_PHASE) & 0xff) != 0)):
            data=self.x393_axi_tasks.read_status(vrlg.MCONTR_PHY_STATUS_REG_ADDR)
            if self.DRY_MODE: break

    def axi_set_wbuf_delay(self,
                            delay=None): # input [3:0] delay;
        """
        Set write to buffer latency
        @param delay    4-bit write to buffer signal delay (in mclk clock cycles)
                   if delay is None will restore default values
        """
        if delay is None:
            delay= vrlg.get_default("DFLT_WBUF_DELAY")
             
        vrlg.DFLT_WBUF_DELAY=delay
        if self.DEBUG_MODE > 1:
            print("SET WBUF DELAY=0x%x"%delay)
        self.x393_axi_tasks.write_control_register(vrlg.MCONTR_PHY_16BIT_ADDR+vrlg.MCONTR_PHY_16BIT_WBUF_DELAY, delay & 0xf) # {28'h0, delay});
#set dq /dqs tristate on/off patterns

    def axi_set_tristate_patterns(self,
                                  strPattern=None):
        """
        Set sequencer patterns for the tristate ON/OFF (defined by parameters)
        <strPattern> - optional up to 4-letter pattern. Each letter is one of 3:
                       'E'- early, "N" - nominal and 'L' - late, first for DQ start,
                       second - for DQS start, then DQ end and DQS end. If no pattern
                       is provided, all will be set to Verilog parameter values (DQ*TRI_*),
                       if only 1 - it will be applied to all, if 2 - it will be
                       repeated twice, 3 will use  the same value for DQS end as for DQS start
        """
        modes={'E':0,'N':1,'L':2}
        evNames=('DQ_FIRST', 'DQS_FIRST', 'DQ_LAST','DQS_LAST')
        
        patVals={evNames[0]: (0x3,0x7,0xf), # DQ_FIRST:  early, nominal, late
                 evNames[1]: (0x1,0x3,0x7), # DQS_FIRST: early, nominal, late
                 evNames[2]: (0xf,0xe,0xc), # DQ_LAST:   early, nominal, late
                 evNames[3]: (0xe,0xc,0x8)} # DQS_LAST:  early, nominal, late
        
        if not strPattern:
            delays=concat(((0,16), #  {16'h0, 
                           (vrlg.DQSTRI_LAST, getParWidth(vrlg.DQSTRI_LAST__TYPE)),      #  DQSTRI_LAST,
                           (vrlg.DQSTRI_FIRST,getParWidth(vrlg.DQSTRI_FIRST__TYPE)),     #  DQSTRI_FIRST,
                           (vrlg.DQTRI_LAST,  getParWidth(vrlg.DQTRI_LAST__TYPE)),       #   DQTRI_LAST,
                           (vrlg.DQTRI_FIRST, getParWidth(vrlg.DQTRI_FIRST__TYPE)))      #   DQTRI_FIRST});
                          )[0]
        else:
            strPattern=strPattern.upper()
            if len(strPattern) == 1:
                strPattern*=4
            elif len(strPattern) == 2:
                strPattern*=2
            elif len(strPattern) == 3:
                strPattern+=strPattern[1]
            strPattern=strPattern[:4]
            vals={}
            for i,n in enumerate(evNames):
                try:
                    vals[n]=patVals[n][modes[strPattern[i]]]
                except:
                    msg="axi_set_tristate_patterns(%s): Failed to determine delay mode for %s, got %s"%(strPattern,n,strPattern[i])
                    print (msg)
                    Exception(msg)              
            print ("axi_set_tristate_patterns(%s) : %s"%(strPattern,str(vals)))
            delays=concat(((0,16), #  {16'h0, 
                           (vals['DQS_LAST'],4),  # vrlg.DQSTRI_LAST, getParWidth(vrlg.DQSTRI_LAST__TYPE)),      #  DQSTRI_LAST,
                           (vals['DQS_FIRST'],4), # vrlg.DQSTRI_FIRST,getParWidth(vrlg.DQSTRI_FIRST__TYPE)),     #  DQSTRI_FIRST,
                           (vals['DQ_LAST'],4),   # vrlg.DQTRI_LAST,  getParWidth(vrlg.DQTRI_LAST__TYPE)), #   DQTRI_LAST,
                           (vals['DQ_FIRST'],4))  # vrlg.DQTRI_FIRST, getParWidth(vrlg.DQTRI_FIRST__TYPE)))       #   DQTRI_FIRST});
                          )[0]
                 
        # may fail if some of the parameters used have undefined width
        print("DQTRI_FIRST=%s, DQTRI_FIRST__TYPE=%s"%(str(vrlg.DQTRI_FIRST),str(vrlg.DQTRI_FIRST__TYPE)))
        print("DQTRI_LAST=%s, DQTRI_LAST__TYPE=%s"%(str(vrlg.DQTRI_LAST),str(vrlg.DQTRI_LAST__TYPE)))
        if self.DEBUG_MODE > 1:
            print("SET TRISTATE PATTERNS, combined delays=%s"%str(delays))    
            print("SET TRISTATE PATTERNS, combined delays=0x%x"%delays)    
        self.x393_axi_tasks.write_control_register(vrlg.MCONTR_PHY_16BIT_ADDR +vrlg.MCONTR_PHY_16BIT_PATTERNS_TRI, delays) #  DQSTRI_LAST, DQSTRI_FIRST, DQTRI_LAST, DQTRI_FIRST});

    def axi_set_dqs_dqm_patterns(self,
                                 dqs_patt=None,
                                 dqm_patt=None,
                                 quiet=1):
        """
        Set sequencer patterns for the DQ lines ON/OFF (defined by parameters)
        @param dqs_patt DQS toggle pattern (if None - use DFLT_DQS_PATTERN (currently 0xaa)
        @param dm_patt  DM pattern (if None - use DFLT_DQM_PATTERN (currently 0x00) should be 0 for now
        @param quiet reduce output
        """
        if dqs_patt is None:
            dqs_patt=vrlg.DFLT_DQS_PATTERN
        if dqm_patt is None:
            dqm_patt=vrlg.DFLT_DQM_PATTERN
        patt = (dqs_patt & 0xff) | ((dqm_patt & 0xff) << 8)
        vrlg.dqs_dqm_patt=patt
        if quiet < 2 :
            print("axi_set_dqs_dqm_patterns(): SET DQS+DQM PATTERNS, patt= 0x%08x (TODO:reduce quiet threshold)"%patt)
# set patterns for DM (always 0) and DQS - always the same (may try different for write lev.)        
        self.x393_axi_tasks.write_control_register(vrlg.MCONTR_PHY_16BIT_ADDR + vrlg.MCONTR_PHY_16BIT_PATTERNS, patt) # 32'h0055);
        
    def get_dqs_dqm_patterns(self):
        #print ('vrlg.dqs_dqm_patt=',vrlg.dqs_dqm_patt)
        try:
            return (vrlg.dqs_dqm_patt & 0xff,(vrlg.dqs_dqm_patt >> 8) & 0xff)
        except:
            return None    
    def util_test4(self):
#        print("vrlg.globals():")
#        print(vrlg.globals())
#        print("vrlg.__dict__")
#        print(vrlg.__dict__)
        print ("DLY_PHASE = 0x%x"%vrlg.DLY_PHASE)
        for k,v in vrlg.__dict__.items():
            print ("%s = %s"%(k,str(v)))        
