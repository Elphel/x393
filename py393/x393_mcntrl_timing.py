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
from import_verilog_parameters import VerilogParameters
from x393_mem import X393Mem
from x393_axi_control_status import X393AxiControlStatus
#from verilog_utils import * # concat, bits 
#from verilog_utils import hx, concat, bits, getParWidth 
from verilog_utils import concat, getParWidth,hexMultiple
#from x393_axi_control_status import concat, bits
class X393McntrlTiming(object):
    DRY_MODE= True # True
    DEBUG_MODE=1
#    vpars=None
    x393_mem=None
    x393_axi_tasks=None #x393X393AxiControlStatus
    target_phase=0 # TODO: set!
    def __init__(self, debug_mode=1,dry_mode=True):
        self.DEBUG_MODE=debug_mode
        self.DRY_MODE=dry_mode
        self.x393_mem=X393Mem(debug_mode,dry_mode)
        self.x393_axi_tasks=X393AxiControlStatus(debug_mode,dry_mode)
        self.__dict__.update(VerilogParameters.__dict__["_VerilogParameters__shared_state"]) # Add verilog parameters to the class namespace

    def axi_set_phase(self,
                      phase,      # input [PHASE_WIDTH-1:0] phase;
                      wait_phase_en=True,
                      wait_seq=False):
        """
        Set clock phase
        <phase>    8-bit clock phase value
        <wait_phase_en> compare phase shift to programmed (will not work if the program was restarted)
        <wait_seq> read and re-send status request to make sure status reflects new data (just for testing, too fast for Python)
        Returns 1 if success, 0 if timeout (or no wait was performed)
        """
        if self.DEBUG_MODE > 1:
            print("SET CLOCK PHASE=0x%x"%phase)
        self.x393_axi_tasks.write_contol_register(self.LD_DLY_PHASE, phase & ((1<<self.PHASE_WIDTH)-1)) # {{(32-PHASE_WIDTH){1'b0}},phase}); // control regiter address
        self.x393_axi_tasks.write_contol_register(self.DLY_SET,0)
        self.target_phase = phase
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
        patt = 0x3000000 | self.target_phase
        mask = 0x3000100
        if check_phase_value:
            mask |= 0xff
        return self.x393_axi_tasks.wait_status_condition(
                              self.MCONTR_PHY_STATUS_REG_ADDR,                                # status_address,
                              self.MCONTR_PHY_16BIT_ADDR + self.MCONTR_PHY_STATUS_CNTRL,      # status_control_address,
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
        return self.target_phase
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
    
    def axi_set_dqs_odelay_nominal(self):
        """
        Set DQS output delays to nominal values (parameter-defined)
        """
        self.x393_axi_tasks.write_contol_register(self.LD_DLY_LANE0_ODELAY + 8,      (self.DLY_LANE0_ODELAY >> (8<<3)) & 0xff) # 32'hff);
        self.x393_axi_tasks.write_contol_register(self.LD_DLY_LANE1_ODELAY + 8,      (self.DLY_LANE1_ODELAY >> (8<<3)) & 0xff) # 32'hff);
        self.x393_axi_tasks.write_contol_register(self.DLY_SET,0);

    def axi_set_dqs_idelay_nominal(self):
        """
        Set DQS input delays to nominal values (parameter-defined)
        """
        self.x393_axi_tasks.write_contol_register(self.LD_DLY_LANE0_IDELAY + 8,      (self.DLY_LANE0_IDELAY >> (8<<3)) & 0xff) # 32'hff);
        self.x393_axi_tasks.write_contol_register(self.LD_DLY_LANE1_IDELAY + 8,      (self.DLY_LANE1_IDELAY >> (8<<3)) & 0xff) # 32'hff);
        self.x393_axi_tasks.write_contol_register(self.DLY_SET,0);

    def axi_set_dqs_idelay_wlv(self):
        """
        Set DQS input delays to values defined for the write levelling mode (parameter-defined)
        """
        
        self.x393_axi_tasks.write_contol_register(self.LD_DLY_LANE0_IDELAY + 8,      self.DLY_LANE0_DQS_WLV_IDELAY)
        self.x393_axi_tasks.write_contol_register(self.LD_DLY_LANE1_IDELAY + 8,      self.DLY_LANE1_DQS_WLV_IDELAY)
        self.x393_axi_tasks.write_contol_register(self.DLY_SET,0)

    def axi_set_delays(self): #  set all individual delays
        """
        Set all DDR3 I/O delays to individual parameter-defined values
        """
        for i in range(0,10): # (i=0;i<10;i=i+1) begin
            self.x393_axi_tasks.write_contol_register(self.LD_DLY_LANE0_ODELAY + i,     (self.DLY_LANE0_ODELAY >> (i<<3)) & 0xff) # 32'hff);
        for i in range(0,9): # (i=0;i<9;i=i+1) begin
            self.x393_axi_tasks.write_contol_register(self.LD_DLY_LANE0_IDELAY + i,      (self.DLY_LANE0_IDELAY >> (i<<3)) & 0xff) # 32'hff);
        for i in range(0,10): # (i=0;i<10;i=i+1) begin
            self.x393_axi_tasks.write_contol_register(self.LD_DLY_LANE1_ODELAY + i,      (self.DLY_LANE1_ODELAY >> (i<<3)) & 0xff) # 32'hff);
        for i in range(0,9): # (i=0;i<9;i=i+1) begin
            self.x393_axi_tasks.write_contol_register(self.LD_DLY_LANE1_IDELAY + i,      (self.DLY_LANE1_IDELAY >> (i<<3)) & 0xff) # 32'hff);
        for i in range(0,32): # (i=0;i<32;i=i+1) begin
            self.x393_axi_tasks.write_contol_register(self.LD_DLY_CMDA + i,      (self.DLY_CMDA >> (i<<3)) & 0xff) # 32'hff);
        self.x393_axi_tasks.axi_set_phase(self.DLY_PHASE); # also sets all delays
        
    def axi_set_dq_idelay(self,   #  sets same delay to all dq idelay
                          delay): # input [7:0] delay;
        """
        Set all DQ input delays to the same value
        <delay> 8-bit (5+3) delay value to use or a tuple/list with a pair for (lane0, lane1)
                Each of the two elements in the delay tuple/list may be a a common integer or a list/tuple itself
        """
        if delay is None: return # Do nothing, that's OK
        if isinstance(delay,int):
            delay=(delay,delay)
        if self.DEBUG_MODE > 1:
            print("SET DQ IDELAY="+hexMultiple(delay)) # hexMultiple
        self.axi_set_multiple_delays(self.LD_DLY_LANE0_IDELAY, 8, delay[0])
        self.axi_set_multiple_delays(self.LD_DLY_LANE1_IDELAY, 8, delay[1])
        self.x393_axi_tasks.write_contol_register  (self.DLY_SET,0);# // set all delays
        
    def axi_set_dq_odelay(self,
                          delay): # input [7:0] delay;
        """
        Set all DQ OUTput delays to the same value
        <delay> 8-bit (5+3) delay value to use or a tuple/list with a pair for (lane0, lane1)
                Each of the two elements in the delay tuple/list may be a a common integer or a list/tuple itself
        """
        if delay is None: return # Do nothing, that's OK
        if isinstance(delay,int):
            delay=(delay,delay)
        if self.DEBUG_MODE > 1:
            print("SET DQ ODELAY="+hexMultiple(delay)) # hexMultiple
        self.axi_set_multiple_delays(self.LD_DLY_LANE0_ODELAY, 8, delay[0]);
        self.axi_set_multiple_delays(self.LD_DLY_LANE1_ODELAY, 8, delay[1]);
        self.x393_axi_tasks.write_contol_register(self.DLY_SET,0); # set all delays
        
    def axi_set_dqs_idelay(self,
                           delay): # input [7:0] delay;
        """
        Set all DQs input delays to the same value
        <delay> 8-bit (5+3) delay value to use or a tuple/list with a pair for (lane0, lane1)
        """
        if delay is None: return # Do nothing, that's OK
        if isinstance(delay,int):
            delay=(delay,delay)
        if self.DEBUG_MODE > 1:
            print("SET DQS IDELAY="+hexMultiple(delay)) # hexMultiple
        self.axi_set_multiple_delays(self.LD_DLY_LANE0_IDELAY + 8, 1, delay[0])
        self.axi_set_multiple_delays(self.LD_DLY_LANE1_IDELAY + 8, 1, delay[1])
        self.x393_axi_tasks.write_contol_register(self.DLY_SET,0); # set all delays

    def axi_set_dqs_odelay(self,
                           delay): # input [7:0] delay;
        """
        Set all DQs OUTput delays to the same value
        <delay> 8-bit (5+3) delay value to use or a tuple/list with a pair for (lane0, lane1)
        """
        if delay is None: return # Do nothing, that's OK
        if isinstance(delay,int):
            delay=(delay,delay)
        if self.DEBUG_MODE > 1:
            print("SET DQS ODELAY="+hexMultiple(delay)) # hexMultiple
        self.axi_set_multiple_delays(self.LD_DLY_LANE0_ODELAY + 8, 1, delay[0])
        self.axi_set_multiple_delays(self.LD_DLY_LANE1_ODELAY + 8, 1, delay[1])
        self.x393_axi_tasks.write_contol_register(self.DLY_SET,0); # set all delays

    def axi_set_dm_odelay (self,
                           delay): # input [7:0] delay;
        """
        Set all DM output delays to the same value
        <delay> 8-bit (5+3) delay value to use or a tuple/list with a pair for (lane0, lane1)
        """
        if delay is None: return # Do nothing, that's OK
        if isinstance(delay,int):
            delay=(delay,delay)
        if self.DEBUG_MODE > 1:
            print("SET DQM IDELAY="+hexMultiple(delay)) # hexMultiple
        self.axi_set_multiple_delays(self.LD_DLY_LANE0_ODELAY + 9, 1, delay[0])
        self.axi_set_multiple_delays(self.LD_DLY_LANE1_ODELAY + 9, 1, delay[1])
        self.x393_axi_tasks.write_contol_register(self.DLY_SET,0) #  set all delays

    def axi_set_cmda_odelay(self,
                           delay): # input [7:0] delay;
        """
        Set all command/address output delays to the same value (or a list/tuple of the individual ones)
        <delay>    8-bit (5+3) delay value to use or list/tuple containing individual values
                   List elements may be None, those values will not be overwritten
        """
        if delay is None: return # Do nothing, that's OK
        if isinstance(delay,int):
            delay=(delay,)*32 # all address/commands
        if self.DEBUG_MODE > 1:
            print("SET COMMAND and ADDRESS ODELAY"+hexMultiple(delay))
        self.axi_set_multiple_delays(self.LD_DLY_CMDA, 32, delay);
        self.x393_axi_tasks.write_contol_register(self.DLY_SET,0)  # set all delays

    def axi_set_address_odelay(self,
                               delay): # input [7:0] delay;
        """
        Set output delays for address lines only
        <delay>    8-bit (5+3) delay value to use or list/tuple containing individual values
                   List elements may be None, those values will not be overwritten
        """
        if delay is None: return # Do nothing, that's OK
        if isinstance(delay,int):
            delay=(delay,)*self.ADDRESS_NUMBER
        if self.DEBUG_MODE > 1:
            print("SET ADDRESS ODELAY="+hexMultiple(delay))
        self.axi_set_multiple_delays(self.LD_DLY_CMDA, 0,delay)  # 32, delay); length will be determined by len(delay)
        self.x393_axi_tasks.write_contol_register(self.DLY_SET,0)  # set all delays
        
    def axi_set_bank_odelay(self,
                               delay): # input [7:0] delay;
        """
        Set output delays for bank lines only
        <delay>    8-bit (5+3) delay value to use or list/tuple containing individual values
                   List elements may be None, those values will not be overwritten
        """
        bank_offset=24
        if delay is None: return # Do nothing, that's OK
        if isinstance(delay,int):
            delay=(delay,)*3
        if self.DEBUG_MODE > 1:
            print("SET BANK ODELAY="+hexMultiple(delay))
        self.axi_set_multiple_delays(self.LD_DLY_CMDA+bank_offset, 0,delay)  # length will be determined by len(delay)
        self.x393_axi_tasks.write_contol_register(self.DLY_SET,0)  # set all delays

    def axi_set_cmd_odelay(self,
                               delay): # input [7:0] delay;
        """
        Set output delays for command lines only. command=(we,ras,cas,cke,odt)
        <delay>    8-bit (5+3) delay value to use or list/tuple containing individual values
                   List elements may be None, those values will not be overwritten
        """
        command_offset=24+3
        if delay is None: return # Do nothing, that's OK
        if isinstance(delay,int):
            delay=(delay,)*3
        if self.DEBUG_MODE > 1:
            print("SET COMMAND ODELAY="+hexMultiple(delay))
        self.axi_set_multiple_delays(self.LD_DLY_CMDA+command_offset, 0,delay)  # length will be determined by len(delay)
        self.x393_axi_tasks.write_contol_register(self.DLY_SET,0)  # set all delays
        
        
    def axi_set_multiple_delays(self,
                                reg_addr, #input [29:0] reg_addr;
                                number,   # input integer number;
                                delay):   # input [7:0]  delay;
        """
        Set same delay to a range of I/O delay registers
        <reg_addr> control register address of the first register in the range
        <number>   number of registers to write
        <delay>    8-bit (5+3) delay value to use or list/tuple containing individual values
                   List elements may be None, those values will not be overwritten
        """
        if delay is None: return # Do nothing, that's OK
        if isinstance(delay,int):
            delay=(delay,)*number
        if len(delay) < number:
            delay= delay + (None,)*(number-len(delay)) #
        for i, d in enumerate(delay):
            if not d is None:
                self.x393_axi_tasks.write_contol_register(reg_addr + i, d) # {24'b0,delay}); // control register address

    def wait_phase_shifter_ready(self):
        """
        Wait until clock phase shifter is ready
        """
        data=self.x393_axi_tasks.read_status(self.MCONTR_PHY_STATUS_REG_ADDR)
        while (((data & self.STATUS_PSHIFTER_RDY_MASK) == 0) or (((data ^ self.target_phase) & 0xff) != 0)):
            data=self.x393_axi_tasks.read_status(self.MCONTR_PHY_STATUS_REG_ADDR)
            if self.DRY_MODE: break

    def axi_set_wbuf_delay(self,
                            delay): # input [3:0] delay;
        """
        Set write to buffer latency
        <delay>    4-bit write to buffer signal delay (in mclk clock cycles)
        """
        if self.DEBUG_MODE > 1:
            print("SET WBUF DELAY=0x%x"%delay)
        self.x393_axi_tasks.write_contol_register(self.MCONTR_PHY_16BIT_ADDR+self.MCONTR_PHY_16BIT_WBUF_DELAY, delay & 0xf) # {28'h0, delay});
#set dq /dqs tristate on/off patterns
    def axi_set_tristate_patterns(self):
        """
        Set sequencer patterns for the tristate ON/OFF (defined by parameters)
        """
        # may fail if some of the parameters used have undefined width
        print("DQTRI_FIRST=%s, DQTRI_FIRST__TYPE=%s"%(str(self.DQTRI_FIRST),str(self.DQTRI_FIRST__TYPE)))
        print("DQTRI_LAST=%s, DQTRI_LAST__TYPE=%s"%(str(self.DQTRI_LAST),str(self.DQTRI_LAST__TYPE)))
        delays=concat(((0,16), #  {16'h0, 
                       (self.DQSTRI_LAST, getParWidth(self.DQSTRI_LAST__TYPE)),      #  DQSTRI_LAST,
                       (self.DQSTRI_FIRST,getParWidth(self.DQSTRI_FIRST__TYPE)),     #  DQSTRI_FIRST,
                       (self.DQTRI_LAST,  getParWidth(self.DQTRI_LAST__TYPE)), #   DQTRI_LAST,
                       (self.DQTRI_FIRST, getParWidth(self.DQTRI_FIRST__TYPE)))       #   DQTRI_FIRST});
                      )[0]
        if self.DEBUG_MODE > 1:
            print("SET TRISTATE PATTERNS, combined delays=%s"%str(delays))    
            print("SET TRISTATE PATTERNS, combined delays=0x%x"%delays)    
        self.x393_axi_tasks.write_contol_register(self.MCONTR_PHY_16BIT_ADDR +self.MCONTR_PHY_16BIT_PATTERNS_TRI, delays) #  DQSTRI_LAST, DQSTRI_FIRST, DQTRI_LAST, DQTRI_FIRST});

    def axi_set_dqs_dqm_patterns(self):
        """
        Set sequencer patterns for the DQ lines ON/OFF (defined by parameters)
        """
        if self.DEBUG_MODE > 1:
            print("SET DQS+DQM PATTERNS")
# set patterns for DM (always 0) and DQS - always the same (may try different for write lev.)        
        self.x393_axi_tasks.write_contol_register(self.MCONTR_PHY_16BIT_ADDR + self.MCONTR_PHY_16BIT_PATTERNS, 0x55) # 32'h0055);
