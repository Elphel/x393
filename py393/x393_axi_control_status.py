'''
# Copyright (C) 2015, Elphel.inc.
# Memory read/write functions 
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
from __future__ import print_function
#import sys
#import x393_mem
from import_verilog_parameters import VerilogParameters
from x393_mem import X393Mem
#MCNTRL_TEST01_CHN4_STATUS_CNTRL=0
class X393AxiControlStatus(object):
    DRY_MODE= False # True
    DEBUG_MODE=1
#    vpars=None
    x393_mem=None
    target_phase=0 # TODO: set!
    def __init__(self, debug_mode=1,dry_mode=False):
        self.DEBUG_MODE=debug_mode
        self.DRY_MODE=dry_mode
#        self.vpars=VerilogParameters()
        self.x393_mem=X393Mem(debug_mode,dry_mode)
        self.__dict__.update(VerilogParameters.__dict__) # Add verilog parameters to the class namespace
        '''
        Maybe import parameters into the module, not class namespace to use directly, w/o self. ?
#        __dict__.update(VerilogParameters.__dict__) # Add verilog parameters to the class namespace
        '''
        
    def write_contol_register(self, reg_addr, data):
        self.x393_mem.axi_write_single_w(self.CONTROL_ADDR+reg_addr, data)
    def read_and_wait_status(self, address):
        return self.x393_mem.axi_read_addr_w(self.STATUS_ADDR + address )
    
    def wait_status_condition(self,
                              status_address,         # input [STATUS_DEPTH-1:0] status_address;
                              status_control_address, # input [29:0] status_control_address;
                              status_mode,            # input  [1:0] status_mode;
                              pattern,                # input [25:0] pattern;        // bits as in read registers
                              mask,                   # input [25:0] mask;           // which bits to compare
                              invert_match,           # input        invert_match;   // 0 - wait until match to pattern (all bits), 1 - wait until no match (any of bits differ)
                              wait_seq):              # input        wait_seq; // Wait for the correct sequence number, False assume correct
        match=False
        while not match:
            data=self.read_and_wait_status(status_address)
            if wait_seq:
                seq_num = ((data >> self.STATUS_SEQ_SHFT) ^ 0x20) & 0x30
                data=self.read_and_wait_status(status_address)
                while (((data >> self.STATUS_SEQ_SHFT) ^ seq_num) & 0x30) !=0:
                    data=self.read_and_wait_status(status_address)
            match = (((data ^ pattern) & mask & 0x3ffffff)==0)
            if invert_match:
                match = not match
    def wait_phase_shifter_ready(self):
        data=self.read_and_wait_status(self.MCONTR_PHY_STATUS_REG_ADDR)
        while (((data & self.STATUS_PSHIFTER_RDY_MASK) == 0) or (((data ^ self.target_phase) & 0xff) != 0)):
            data=self.read_and_wait_status(self.MCONTR_PHY_STATUS_REG_ADDR)

    def read_all_status(self):
        print ("MCONTR_PHY_STATUS_REG_ADDR:          0x%x"%(self.read_and_wait_status(self.MCONTR_PHY_STATUS_REG_ADDR)))
        print ("MCONTR_TOP_STATUS_REG_ADDR:          0x%x"%(self.read_and_wait_status(self.MCONTR_TOP_STATUS_REG_ADDR)))
        print ("MCNTRL_PS_STATUS_REG_ADDR:           0x%x"%(self.read_and_wait_status(self.MCNTRL_PS_STATUS_REG_ADDR)))
        print ("MCNTRL_SCANLINE_STATUS_REG_CHN1_ADDR:0x%x"%(self.read_and_wait_status(self.MCNTRL_SCANLINE_STATUS_REG_CHN1_ADDR)))
        print ("MCNTRL_SCANLINE_STATUS_REG_CHN3_ADDR:0x%x"%(self.read_and_wait_status(self.MCNTRL_SCANLINE_STATUS_REG_CHN3_ADDR)))
        print ("MCNTRL_TILED_STATUS_REG_CHN2_ADDR:   0x%x"%(self.read_and_wait_status(self.MCNTRL_TILED_STATUS_REG_CHN2_ADDR)))
        print ("MCNTRL_TILED_STATUS_REG_CHN4_ADDR:   0x%x"%(self.read_and_wait_status(self.MCNTRL_TILED_STATUS_REG_CHN4_ADDR)))
        print ("MCNTRL_TEST01_STATUS_REG_CHN1_ADDR:  0x%x"%(self.read_and_wait_status(self.MCNTRL_TEST01_STATUS_REG_CHN1_ADDR)))
        print ("MCNTRL_TEST01_STATUS_REG_CHN2_ADDR:  0x%x"%(self.read_and_wait_status(self.MCNTRL_TEST01_STATUS_REG_CHN2_ADDR)))
        print ("MCNTRL_TEST01_STATUS_REG_CHN3_ADDR:  0x%x"%(self.read_and_wait_status(self.MCNTRL_TEST01_STATUS_REG_CHN3_ADDR)))
        print ("MCNTRL_TEST01_STATUS_REG_CHN4_ADDR:  0x%x"%(self.read_and_wait_status(self.MCNTRL_TEST01_STATUS_REG_CHN4_ADDR)))

    def program_status(self,
                       base_addr,   # input [29:0] base_addr;
                       reg_addr,    # input  [7:0] reg_addr;
                       mode,        # input  [1:0] mode;
                       seq_number): # input  [5:0] seq_number;
        '''
 // mode bits:
 // 0 disable status generation,
 // 1 single status request,
 // 2 - auto status, keep specified seq number,
 // 3 - auto, inc sequence number
         '''
        self.write_contol_register(base_addr + reg_addr, ((mode & 3)<< 6) | (seq_number * 0x3f))


    def program_status_all( self,
                            mode,     # input [1:0] mode;
                            seq_num): # input [5:0] seq_num;
        self.program_status (self.MCONTR_PHY_16BIT_ADDR,     self.MCONTR_PHY_STATUS_CNTRL,        mode,seq_num)# //MCONTR_PHY_STATUS_REG_ADDR=          'h0,
        self.program_status (self.MCONTR_TOP_16BIT_ADDR,     self.MCONTR_TOP_16BIT_STATUS_CNTRL,  mode,seq_num)# //MCONTR_TOP_STATUS_REG_ADDR=          'h1,
        self.program_status (self.MCNTRL_PS_ADDR,            self.MCNTRL_PS_STATUS_CNTRL,         mode,seq_num)# //MCNTRL_PS_STATUS_REG_ADDR=           'h2,
        self.program_status (self.MCNTRL_SCANLINE_CHN1_ADDR, self.MCNTRL_SCANLINE_STATUS_CNTRL,   mode,seq_num)#; //MCNTRL_SCANLINE_STATUS_REG_CHN2_ADDR='h4,
        self.program_status (self.MCNTRL_SCANLINE_CHN3_ADDR, self.MCNTRL_SCANLINE_STATUS_CNTRL,   mode,seq_num)# //MCNTRL_SCANLINE_STATUS_REG_CHN3_ADDR='h5,
        self.program_status (self.MCNTRL_TILED_CHN2_ADDR,    self.MCNTRL_TILED_STATUS_CNTRL,      mode,seq_num)# //MCNTRL_TILED_STATUS_REG_CHN4_ADDR=   'h6,
        self.program_status (self.MCNTRL_TILED_CHN4_ADDR,    self.MCNTRL_TILED_STATUS_CNTRL,      mode,seq_num)#; //MCNTRL_TILED_STATUS_REG_CHN4_ADDR=   'h6,
        self.program_status (self.MCNTRL_TEST01_ADDR,        self.MCNTRL_TEST01_CHN1_STATUS_CNTRL,mode,seq_num)#; //MCNTRL_TEST01_STATUS_REG_CHN2_ADDR=  'h3c,
        self.program_status (self.MCNTRL_TEST01_ADDR,        self.MCNTRL_TEST01_CHN2_STATUS_CNTRL,mode,seq_num)#; //MCNTRL_TEST01_STATUS_REG_CHN2_ADDR=  'h3c,
        self.program_status (self.MCNTRL_TEST01_ADDR,        self.MCNTRL_TEST01_CHN3_STATUS_CNTRL,mode,seq_num)#; //MCNTRL_TEST01_STATUS_REG_CHN3_ADDR=  'h3d,
        self.program_status (self.MCNTRL_TEST01_ADDR,        self.MCNTRL_TEST01_CHN4_STATUS_CNTRL,mode,seq_num)#; //MCNTRL_TEST01_STATUS_REG_CHN4_ADDR=  'h3e,
        '''
        x393_tasks_ps_pio
        '''
    def schedule_ps_pio(self,          #; // shedule software-control memory operation (may need to check FIFO status first)
                        seq_addr,      # input [9:0] seq_addr; // sequence start address
                        page,          # input [1:0] page;     // buffer page number
                        urgent,        # input       urgent;   // high priority request (only for competion wityh other channels, wiil not pass in this FIFO)
                        chn,           # input       chn;      // channel buffer to use: 0 - memory read, 1 - memory write
                        wait_complete): # input       wait_complete; // Do not request a newe transaction from the scheduler until previous memory transaction is finished
        self.write_contol_register(self.MCNTRL_PS_ADDR + self.MCNTRL_PS_CMD,
                                    # {17'b0,
                                    ((0,1)[wait_complete]<<14) |
                                    ((0,1)[chn]<<13) |
                                    ((0,1)[urgent]<<12) |
                                    ((page & 3) << 10) |
                                    (seq_addr & 0x3ff))
 
    def wait_ps_pio_ready(self,      #; // wait PS PIO module can accept comamnds (fifo half empty)
                          mode,      # input [1:0] mode;
                          sync_seq): # input       sync_seq; //  synchronize sequences
        self.wait_status_condition (
            self.MCNTRL_PS_STATUS_REG_ADDR,
            self.MCNTRL_PS_ADDR + self.MCNTRL_PS_STATUS_CNTRL,
            mode & 3,
            0,
            2 << self.STATUS_2LSB_SHFT,
            0,
            sync_seq)

    def wait_ps_pio_done(self,      # // wait PS PIO module has no pending/running memory transaction
                         mode,      # input [1:0] mode;
                         sync_seq): # input       sync_seq; //  synchronize sequences
        self.wait_status_condition (
            self.MCNTRL_PS_STATUS_REG_ADDR,
            self.MCNTRL_PS_ADDR + self.MCNTRL_PS_STATUS_CNTRL,
            mode & 3,
            0,
            3 << self.STATUS_2LSB_SHFT,
            0,
            sync_seq)
    '''
    x393_mcontr_encode_cmd
    '''
    def func_encode_cmd(self,      # function [31:0] 
                        addr,      # input               [14:0] addr;       // 15-bit row/column adderss
                        bank,      # input                [2:0] bank;       // bank (here OK to be any)
                        rcw,       # input                [2:0] rcw;        // RAS/CAS/WE, positive logic
                        odt_en,    # input                      odt_en;     // enable ODT
                        cke,       # input                      cke;        // disable CKE
                        sel,       # input                      sel;        // first/second half-cycle, other will be nop (cke+odt applicable to both)
                        dq_en,     # input                      dq_en;      // enable (not tristate) DQ  lines (internal timing sequencer for 0->1 and 1->0)
                        dqs_en,    # input                      dqs_en;     // enable (not tristate) DQS lines (internal timing sequencer for 0->1 and 1->0)
                        dqs_toggle,# input                      dqs_toggle; // enable toggle DQS according to the pattern
                        dci,       # input                      dci;        // DCI disable, both DQ and DQS lines (internal logic and timing sequencer for 0->1 and 1->0)
                        buf_wr,    # input                      buf_wr;     // connect to external buffer (but only if not paused)
                        buf_rd,    # input                      buf_rd;     // connect to external buffer (but only if not paused)
                        nop,       # input                      nop;        // add NOP after the current command, keep other data
                        buf_rst):  # input                      buf_rst;    // connect to external buffer (but only if not paused)
        return (
            ((addr & 0x7fff) << 17) | # addr[14:0], // 15-bit row/column adderss
            ((bank & 0x7)    << 14) | # bank [2:0], // bank
            ((rcw  & 0x7)    << 11) | # rcw[2:0],   // RAS/CAS/WE
            ((0,1)[odt_en]   << 10) | # odt_en,     // enable ODT
            ((0,1)[cke]      <<  9) | # cke,        // may be optimized (removed from here)?
            ((0,1)[sel]      <<  8) | # sel,        // first/second half-cycle, other will be nop (cke+odt applicable to both)
            ((0,1)[dq_en]    <<  7) | # dq_en,      // enable (not tristate) DQ  lines (internal timing sequencer for 0->1 and 1->0)
            ((0,1)[dqs_en]   <<  6) | # dqs_en,     // enable (not tristate) DQS  lines (internal timing sequencer for 0->1 and 1->0)
            ((0,1)[dqs_toggle]<< 5) | # dqs_toggle, // enable toggle DQS according to the pattern
            ((0,1)[dci]      <<  4) | # dci,        // DCI disable, both DQ and DQS lines (internal logic and timing sequencer for 0->1 and 1->0)
            ((0,1)[buf_wr]   <<  3) | # buf_wr,     // phy_buf_wr,   // connect to external buffer (but only if not paused)
            ((0,1)[buf_rd]   <<  2) | # buf_rd,     // phy_buf_rd,    // connect to external buffer (but only if not paused)
            ((0,1)[nop]      <<  1) | # nop,        // add NOP after the current command, keep other data
            ((0,1)[buf_rst]  <<  0)   # buf_rst     // Reset buffer address/ increase buffer page
           )

    def func_encode_skip(self,       # function [31:0]
                          skip,       # input [CMD_PAUSE_BITS-1:0] skip;       // number of extra cycles to skip (and keep all the other outputs)
                          done,       # input                      done;       // end of sequence 
                          bank,       # input [2:0]                bank;       // bank (here OK to be any)
                          odt_en,     # input                      odt_en;     // enable ODT
                          cke,        # input                      cke;        // disable CKE
                          sel,        # input                      sel;        // first/second half-cycle, other will be nop (cke+odt applicable to both)
                          dq_en,      # input                      dq_en;      // enable (not tristate) DQ  lines (internal timing sequencer for 0->1 and 1->0)
                          dqs_en,     # input                      dqs_en;     // enable (not tristate) DQS lines (internal timing sequencer for 0->1 and 1->0)
                          dqs_toggle, # input                      dqs_toggle; // enable toggle DQS according to the pattern
                          dci,        # input                      dci;        // DCI disable, both DQ and DQS lines (internal logic and timing sequencer for 0->1 and 1->0)
                          buf_wr,     # input                      buf_wr;     // connect to external buffer (but only if not paused)
                          buf_rd,     # input                      buf_rd;     // connect to external buffer (but only if not paused)
                          buf_rst):   #input                      buf_rst;    // connect to external buffer (but only if not paused)
        return self.func_encode_cmd (
                ((0,1)[done] << self.CMD_PAUSE_BITS) |    # {{14-CMD_DONE_BIT{1'b0}}, done, 
                (skip & ((1 << self.CMD_PAUSE_BITS)-1)), # skip[CMD_PAUSE_BITS-1:0]},       // 15-bit row/column address
                bank & 7,   # bank[2:0],  // bank (here OK to be any)
                0,          # 3'b0,       // RAS/CAS/WE, positive logic
                odt_en,     #// enable ODT
                cke,        #// disable CKE
                sel,        #// first/second half-cycle, other will be nop (cke+odt applicable to both)
                dq_en,      #// enable (not tristate) DQ  lines (internal timing sequencer for 0->1 and 1->0)
                dqs_en,     #// enable (not tristate) DQS lines (internal timing sequencer for 0->1 and 1->0)
                dqs_toggle, #// enable toggle DQS according to the pattern
                dci,        #// DCI disable, both DQ and DQS lines (internal logic and timing sequencer for 0->1 and 1->0)
                buf_wr,     #// connect to external buffer (but only if not paused)
                buf_rd,     #// connect to external buffer (but only if not paused)
                0,          # 1'b0,       // nop
                buf_rst)    #
        
        
        
    '''
    x393_tasks_pio_sequences
    '''
        
    '''


        
   vpars1=VerilogParameters()
    print("vpars1.VERBOSE="+str(vpars1.VERBOSE))
    print("vpars1.VERBOSE__TYPE="+str(vpars1.VERBOSE__TYPE))
    print("vpars1.VERBOSE__RAW="+str(vpars1.VERBOSE__RAW))
        '''