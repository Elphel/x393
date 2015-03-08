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
from verilog_utils import concat, getParWidth
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
    def get_target_phase(self):
        return self.target_phase
    def axi_set_same_delays(self,         #
                            dq_idelay,    # input [7:0] dq_idelay;
                            dq_odelay,    # input [7:0] dq_odelay;
                            dqs_idelay,   # input [7:0] dqs_idelay;
                            dqs_odelay,   # input [7:0] dqs_odelay;
                            dm_odelay,    # input [7:0] dm_odelay;
                            cmda_odelay): # input [7:0] cmda_odelay;
        print("SET DELAYS(0x%x,0x%x,0x%x,0x%x,0x%x,0x%x)"%(dq_idelay,dq_odelay,dqs_idelay,dqs_odelay,dm_odelay,cmda_odelay))
        self.axi_set_dq_idelay(dq_idelay)
        self.axi_set_dq_odelay(dq_odelay)
        self.axi_set_dqs_idelay(dqs_idelay)
        self.axi_set_dqs_odelay(dqs_odelay)
        self.axi_set_dm_odelay(dm_odelay)
        self.axi_set_cmda_odelay(cmda_odelay)
    
    def axi_set_dqs_odelay_nominal(self):
        self.x393_axi_tasks.write_contol_register(self.LD_DLY_LANE0_ODELAY + 8,      (self.DLY_LANE0_ODELAY >> (8<<3)) & 0xff) # 32'hff);
        self.x393_axi_tasks.write_contol_register(self.LD_DLY_LANE1_ODELAY + 8,      (self.DLY_LANE1_ODELAY >> (8<<3)) & 0xff) # 32'hff);
        self.x393_axi_tasks.write_contol_register(self.DLY_SET,0);

    def axi_set_dqs_idelay_nominal(self):
        self.x393_axi_tasks.write_contol_register(self.LD_DLY_LANE0_IDELAY + 8,      (self.DLY_LANE0_IDELAY >> (8<<3)) & 0xff) # 32'hff);
        self.x393_axi_tasks.write_contol_register(self.LD_DLY_LANE1_IDELAY + 8,      (self.DLY_LANE1_IDELAY >> (8<<3)) & 0xff) # 32'hff);
        self.x393_axi_tasks.write_contol_register(self.DLY_SET,0);

    def axi_set_dqs_idelay_wlv(self):
        self.x393_axi_tasks.write_contol_register(self.LD_DLY_LANE0_IDELAY + 8,      self.DLY_LANE0_DQS_WLV_IDELAY)
        self.x393_axi_tasks.write_contol_register(self.LD_DLY_LANE1_IDELAY + 8,      self.DLY_LANE1_DQS_WLV_IDELAY)
        self.x393_axi_tasks.write_contol_register(self.DLY_SET,0)

    def axi_set_delays(self): #  set all individual delays
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
        print("SET DQ IDELAY=0x%x"%delay)
        self.x393_axi_tasks.axi_set_multiple_delays(self.LD_DLY_LANE0_IDELAY, 8, delay)
        self.x393_axi_tasks.axi_set_multiple_delays(self.LD_DLY_LANE1_IDELAY, 8, delay)
        self.x393_axi_tasks.write_contol_register  (self.DLY_SET,0);# // set all delays
        
    def axi_set_dq_odelay(self,
                          delay): # input [7:0] delay;
        print("SET DQ ODELAY=0x%x"%delay)
        self.x393_axi_tasks.axi_set_multiple_delays(self.LD_DLY_LANE0_ODELAY, 8, delay);
        self.x393_axi_tasks.axi_set_multiple_delays(self.LD_DLY_LANE1_ODELAY, 8, delay);
        self.x393_axi_tasks.write_contol_register(self.DLY_SET,0); # set all delays
        
    def axi_set_dqs_idelay(self,
                           delay): # input [7:0] delay;
        print("SET DQS IDELAY=0x%x"%delay)
        self.x393_axi_tasks.axi_set_multiple_delays(self.LD_DLY_LANE0_IDELAY + 8, 1, delay)
        self.x393_axi_tasks.axi_set_multiple_delays(self.LD_DLY_LANE1_IDELAY + 8, 1, delay)
        self.x393_axi_tasks.write_contol_register(self.DLY_SET,0); # set all delays

    def axi_set_dqs_odelay(self,
                           delay): # input [7:0] delay;
        print("SET DQS ODELAY=0x%x"%delay)
        self.x393_axi_tasks.axi_set_multiple_delays(self.LD_DLY_LANE0_ODELAY + 8, 1, delay)
        self.x393_axi_tasks.axi_set_multiple_delays(self.LD_DLY_LANE1_ODELAY + 8, 1, delay)
        self.x393_axi_tasks.write_contol_register(self.DLY_SET,0); # set all delays

    def axi_set_dm_odelay (self,
                           delay): # input [7:0] delay;
        print("SET DQM IDELAY=0x%x"%delay)
        self.x393_axi_tasks.axi_set_multiple_delays(self.LD_DLY_LANE0_ODELAY + 9, 1, delay)
        self.x393_axi_tasks.axi_set_multiple_delays(self.LD_DLY_LANE1_ODELAY + 9, 1, delay)
        self.x393_axi_tasks.write_contol_register(self.DLY_SET,0) #  set all delays

    def axi_set_cmda_odelay(self,
                           delay): # input [7:0] delay;
        print("SET COMMAND and ADDRESS ODELAY=0x%x"%delay)
        self.x393_axi_tasks.axi_set_multiple_delays(self.LD_DLY_CMDA, 32, delay);
        self.x393_axi_tasks.write_contol_register(self.DLY_SET,0)  # set all delays
        
    def axi_set_multiple_delays(self,
                                reg_addr, #input [29:0] reg_addr;
                                number,   # input integer number;
                                delay):   # input [7:0]  delay;
        for i in range(0,number): # (i=0;i<number;i=i+1) begin
            self.x393_axi_tasks.write_contol_register(reg_addr + i, delay) # {24'b0,delay}); // control regiter address

    def axi_set_phase(self,
                      phase): # input [PHASE_WIDTH-1:0] phase;
        print("SET CLOCK PHASE=0x%x"%phase)
        self.x393_axi_tasks.write_contol_register(self.LD_DLY_PHASE, phase & ((1<<self.PHASE_WIDTH)-1)) # {{(32-PHASE_WIDTH){1'b0}},phase}); // control regiter address
        self.x393_axi_tasks.write_contol_register(self.DLY_SET,0)
        self.target_phase = phase
            
    def wait_phase_shifter_ready(self):
        data=self.x393_axi_tasks.read_and_wait_status(self.MCONTR_PHY_STATUS_REG_ADDR)
        while (((data & self.STATUS_PSHIFTER_RDY_MASK) == 0) or (((data ^ self.target_phase) & 0xff) != 0)):
            data=self.x393_axi_tasks.read_and_wait_status(self.MCONTR_PHY_STATUS_REG_ADDR)
            if self.DRY_MODE: break

    def axi_set_wbuf_delay(self,
                            delay): # input [3:0] delay;
        print("SET WBUF DELAY=0x%x"%delay)
        self.x393_axi_tasks.write_contol_register(self.MCONTR_PHY_16BIT_ADDR+self.MCONTR_PHY_16BIT_WBUF_DELAY, delay & 0xf) # {28'h0, delay});
#set dq /dqs tristate on/off patterns
    def axi_set_tristate_patterns(self):
        # may fail if some of the parameters used have undefined width
        delays=concat((0,16), #  {16'h0, 
                      (self.DQSTRI_LAST, getParWidth(self.DQSTRI_LAST__TYPE)),      #  DQSTRI_LAST,
                      (self.DQSTRI_FIRST,getParWidth(self.DQSTRI_FIRST__TYPE)),     #  DQSTRI_FIRST,
                      (self.DQTRI_LAST,  getParWidth(self.DQTRI_LAST_FIRST__TYPE)), #   DQTRI_LAST,
                      (self.DQTRI_FIRST, getParWidth(self.DQTRI_FIRST__TYPE))       #   DQTRI_FIRST});
                      )
        print("SET TRISTATE PATTERNS, combined delays=0x%x"%delays)    
        self.x393_axi_tasks.write_contol_register(self.MCONTR_PHY_16BIT_ADDR +self.MCONTR_PHY_16BIT_PATTERNS_TRI, delays) #  DQSTRI_LAST, DQSTRI_FIRST, DQTRI_LAST, DQTRI_FIRST});

    def axi_set_dqs_dqm_patterns(self):
        print("SET DQS+DQM PATTERNS")
# set patterns for DM (always 0) and DQS - always the same (may try different for write lev.)        
        self.x393_axi_tasks.write_contol_register(self.MCONTR_PHY_16BIT_ADDR + self.MCONTR_PHY_16BIT_PATTERNS, 0x55) # 32'h0055);
