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
from verilog_utils import concat #, getParWidth
#from x393_axi_control_status import concat, bits
#from time import sleep 
class X393McntrlTests(object):
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

    def func_encode_mode_tiled(self,         # function [6:0] 
                               byte32,       # input       byte32; # 32-byte columns (0 - 16-byte columns)
                               keep_open,    # input       keep_open; # for 8 or less rows - do not close page between accesses
                               extra_pages,  # input [1:0] extra_pages; # number of extra pages that need to stay (not to be overwritten) in the buffer
                                             # can be used for overlapping tile read access
                               write_mem,    # input       write_mem;   # write to memory mode (0 - read from memory)
                               enable,       # input       enable;      # enable requests from this channel ( 0 will let current to finish, but not raise want/need)
                               chn_reset):   # input       chn_reset;       # immediately reset all the internal circuitry
        """
        Combines arguments to create a 7-bit encoded data for tiled mode memory R/W
        <byte32>        use 32-byte wide columns (0 - use 16-byte ones)
        <keep_open>,    do not close page between accesses (for 8 or less rows only)
        <extra_pages>,  2-bit number of extra pages that need to stay (not to be overwritten) in the buffer
                        This argument can be used for  read access with horizontal overlapping tiles
        <write_mem>,    write to memory mode (0 - read from memory)
        <enable>,       enable requests from this channel ( 0 will let current to finish, but not raise want/need)
        <chn_reset>):   immediately reset all the internal circuitry
        
        """
        return concat ((
                       ((0,1)[byte32],   1), # byte32,
                       ((0,1)[keep_open],1), # keep_open,
                       (extra_pages,     2), # extra_pages,
                       ((0,1)[write_mem],1), # write_mem,
                       ((0,1)[enable],   1), #enable,
                       ((1,0)[chn_reset],1)))# ~chn_reset};

    def func_encode_mode_scanline(self,      # function [4:0] 
                               extra_pages,  # input [1:0] extra_pages; # number of extra pages that need to stay (not to be overwritten) in the buffer
                                             # can be used for overlapping tile read access
                               write_mem,    # input       write_mem;   # write to memory mode (0 - read from memory)
                               enable,       # input       enable;      # enable requests from this channel ( 0 will let current to finish, but not raise want/need)
                               chn_reset):   # input       chn_reset;       # immediately reset all the internal circuitry
        """
        Combines arguments to create a 5-bit encoded data for scanline mode memory R/W
        <extra_pages>,  2-bit number of extra pages that need to stay (not to be overwritten) in the buffer
                        This argument can be used for  read access with horizontal overlapping tiles
        <write_mem>,    write to memory mode (0 - read from memory)
        <enable>,       enable requests from this channel ( 0 will let current to finish, but not raise want/need)
        <chn_reset>):   immediately reset all the internal circuitry
        
        """
        return concat (
                       (extra_pages,     2), # extra_pages,
                       ((0,1)[write_mem],1), # write_mem,
                       ((0,1)[enable],   1), #enable,
                       ((1,0)[chn_reset],1)) # ~chn_reset};
    def task_set_up(self,
                    set_per_pin_delays=0):
        """
        Initial setup of the memory controller, including:
            tristate patterns
            DQS/DQM patterns
            all sequences
            channel 0 buffer data
            I/O delays
            clock phase
            status generation
        <set_per_pin_delays> - 1 - set individual (per-pin) I/O delays, 0 - use common for the whole class         
        """

# set dq /dqs tristate on/off patterns
        self.x393_mcntrl_timing.axi_set_tristate_patterns()
# set patterns for DM (always 0) and DQS - always the same (may try different for write lev.)
        self.x393_mcntrl_timing.axi_set_dqs_dqm_patterns()
# prepare all sequences
        self.set_all_sequences;
# prepare write buffer    
        self.x393_mcntrl_buffers.write_block_buf_chn(0,0,256); # fill block memory (channel, page, number)
# set all delays
##axi_set_delays - from tables, per-pin
        if set_per_pin_delays:
            self.x393_mcntrl_timing.axi_set_delays() # set all individual delays, aslo runs axi_set_phase()
        else:
            self.x393_mcntrl_timing.axi_set_same_delays(
                                                        self.DLY_DQ_IDELAY,
                                                        self.DLY_DQ_ODELAY,
                                                        self.DLY_DQS_IDELAY,
                                                        self.DLY_DQS_ODELAY,
                                                        self.DLY_DM_ODELAY,
                                                        self.DLY_CMDA_ODELAY)
# set clock phase relative to DDR clk
#        print("Debugging: sleeping for 1 second")
#        sleep(1)
        self.x393_mcntrl_timing.axi_set_phase(self.DLY_PHASE);
#        self.x393_axi_tasks.read_all_status()
        
#program status for all used modules to refresh at any bit change        
        self.x393_axi_tasks.program_status_all(3, 0)
        
    def set_all_sequences(self):
        """
        Set all sequences:  MRS, REFRESH, WRITE LEVELLING, READ PATTERN, WRITE BLOCK, READ BLOCK 
        """
        if self.verbose>0: print("SET MRS")    
        self.x393_pio_sequences.set_mrs(1) # reset DLL
        if self.verbose>0: print("SET REFRESH")    
        self.x393_pio_sequences.set_refresh(
                                            50, # input [ 9:0] t_rfc; # =50 for tCK=2.5ns
                                            16) #input [ 7:0] t_refi; # 48/97 for normal, 8 - for simulation
        if self.verbose>0: print("SET WRITE LEVELING")    
        self.x393_pio_sequences.set_write_lev(16) # write leveling, 16 times   (full buffer - 128) 
        if self.verbose>0: print("SET READ PATTERNt")    
        self.x393_pio_sequences.set_read_pattern(8) # 8x2*64 bits, 32x32 bits to read
        if self.verbose>0: print("SET WRITE BLOCK")    
        self.x393_pio_sequences.set_write_block(
                                                5,        # 3'h5,     # bank
                                                0x1234,   # 15'h1234, # row address
                                                0x100     # 10'h100   # column address
        )
           
        if self.verbose>0: print("SET READ BLOCK");    
        self.x393_pio_sequences.set_read_block (
                                                5,      #  3'h5,    # bank
                                                0x1234, # 15'h1234, # row address
                                                0x100   # 10'h100   # column address
        )

    def test_write_levelling(self,
                            wait_complete, # Wait for operation to complete
                            wlev_dqs_dly= 0x80,
                            norm_dqs_odly=0x78):
        """
        Test write levelling mode 
        <wait_complete> wait write levelling operation to complete (0 - may initiate multiple PS PIO operations)
        <wlev_dqs_dly>  DQS output delay for write levelling mode (default 0x80)
        <norm_dqs_odly> DQS output delay for normal (not write levelling) mode (default 0x78)
        returns list of the read data
        """
# Set special values for DQS idelay for write leveling
        self.x393_pio_sequences.wait_ps_pio_done(self.DEFAULT_STATUS_MODE,1); # not no interrupt running cycle - delays are changed immediately
        self.x393_mcntrl_timing.axi_set_dqs_idelay_wlv()
# Set write buffer (from DDR3) WE signal delay for write leveling mode
        self.x393_mcntrl_timing.axi_set_wbuf_delay(self.WBUF_DLY_WLV)
# TODO: Set configurable delay time instead of #80
        self.x393_mcntrl_timing.axi_set_dqs_odelay(wlev_dqs_dly) # 'h80); # 'h80 - inverted, 'h60 - not - 'h80 will cause warnings during simulation
        self.x393_pio_sequences.schedule_ps_pio (# schedule software-control memory operation (may need to check FIFO status first)
                                                  self.WRITELEV_OFFSET,   # input [9:0] seq_addr; # sequence start address
                                                  0,                 # input [1:0] page;     # buffer page number
                                                  0,                 # input       urgent;   # high priority request (only for competion with other channels, will not pass in this FIFO)
                                                  0,                 # input       chn;      # channel buffer to use: 0 - memory read, 1 - memory write
                                                  wait_complete)     # `PS_PIO_WAIT_COMPLETE );#  wait_complete; # Do not request a newe transaction from the scheduler until previous memory transaction is finished
                        
        self.x393_pio_sequences.wait_ps_pio_done(self.DEFAULT_STATUS_MODE,1); # wait previous memory transaction finished before changing delays (effective immediately)
        self.x393_mcntrl_buffers.read_block_buf_chn (0, 0, 32, 1, 1); # chn=0, page=0, number of 32-bit words=32, wait_done
        self.x393_mcntrl_timing.axi_set_dqs_odelay(self.DLY_DQS_ODELAY)
        self.x393_pio_sequences.schedule_ps_pio ( # schedule software-control memory operation (may need to check FIFO status first)
                                                  self.WRITELEV_OFFSET, # input [9:0] seq_addr; # sequence start address
                                                  1,                 # input [1:0] page;     # buffer page number
                                                  0,                 # input       urgent;   # high priority request (only for competion with other channels, will not pass in this FIFO)
                                                  0,                 # input       chn;      # channel buffer to use: 0 - memory read, 1 - memory write
                                                  wait_complete)     # `PS_PIO_WAIT_COMPLETE );#  wait_complete; # Do not request a newe transaction from the scheduler until previous memory transaction is finished
        self.x393_pio_sequences.wait_ps_pio_done(self.DEFAULT_STATUS_MODE,1); # wait previous memory transaction finished before changing delays (effective immediately)
        rslt=self.x393_mcntrl_buffers.read_block_buf_chn (0, 1, 32, 1, 1 ); # chn=0, page=1, number of 32-bit words=32, wait_done
        self.x393_mcntrl_timing.axi_set_dqs_idelay_nominal()
        self.x393_mcntrl_timing.axi_set_dqs_odelay(norm_dqs_odly) # 'h78);
        self.x393_mcntrl_timing.axi_set_wbuf_delay(self.WBUF_DLY_DFLT); #DFLT_WBUF_DELAY
        return rslt
   
    def test_read_pattern(self,
                          wait_complete): # Wait for operation to complete
        """
        Test read pattern mode 
        <wait_complete> wait read pattern operation to complete (0 - may initiate multiple PS PIO operations)
        returns list of the read data
        """

        self.x393_pio_sequences.schedule_ps_pio ( # schedule software-control memory operation (may need to check FIFO status first)
                        self.READ_PATTERN_OFFSET,   # input [9:0] seq_addr; # sequence start address
                        2,                          # input [1:0] page;     # buffer page number
                        0,                          # input       urgent;   # high priority request (only for competion with other channels, will not pass in this FIFO)
                        0,                          # input       chn;      # channel buffer to use: 0 - memory read, 1 - memory write
                        wait_complete) # `PS_PIO_WAIT_COMPLETE ) #  wait_complete; # Do not request a newe transaction from the scheduler until previous memory transaction is finished
        self.x393_pio_sequences.wait_ps_pio_done(self.DEFAULT_STATUS_MODE,1) # wait previous memory transaction finished before changing delays (effective immediately)
        return self.x393_mcntrl_buffers.read_block_buf_chn (0, 2, 32, 1, 1 )    # chn=0, page=2, number of 32-bit words=32, wait_done
    
    def test_write_block(self,
                         wait_complete): # Wait for operation to complete
        """
        Test write block in PS PIO mode 
        <wait_complete> wait write block operation to complete (0 - may initiate multiple PS PIO operations)
        """
#    write_block_buf_chn; # fill block memory - already set in set_up task
        self.x393_pio_sequences.schedule_ps_pio ( # schedule software-control memory operation (may need to check FIFO status first)
                        self.WRITE_BLOCK_OFFSET,    # input [9:0] seq_addr; # sequence start address
                        0,                     # input [1:0] page;     # buffer page number
                        0,                     # input       urgent;   # high priority request (only for competion with other channels, will not pass in this FIFO)
                        1,                     # input       chn;      # channel buffer to use: 0 - memory read, 1 - memory write
                        wait_complete)         # `PS_PIO_WAIT_COMPLETE )#  wait_complete; # Do not request a newe transaction from the scheduler until previous memory transaction is finished
# temporary - for debugging:
#        self.x393_pio_sequences.wait_ps_pio_done(self.DEFAULT_STATUS_MODE,1) # wait previous memory transaction finished before changing delays (effective immediately)

    def test_read_block(self,
                        wait_complete): # Wait for operation to complete
        """
        Test read block in PS PIO mode 
        <wait_complete> wait read block operation to complete (0 - may initiate multiple PS PIO operations)
        returns list of the read data
        """
        self.x393_pio_sequences.schedule_ps_pio ( # schedule software-control memory operation (may need to check FIFO status first)
                        self.READ_BLOCK_OFFSET,   # input [9:0] seq_addr; # sequence start address
                        3,                     # input [1:0] page;     # buffer page number
                        0,                     # input       urgent;   # high priority request (only for competion with other channels, will not pass in this FIFO)
                        0,                     # input       chn;      # channel buffer to use: 0 - memory read, 1 - memory write
                        wait_complete)         #  wait_complete; # Do not request a newe transaction from the scheduler until previous memory transaction is finished
        self.x393_pio_sequences.schedule_ps_pio ( # schedule software-control memory operation (may need to check FIFO status first)
                        self.READ_BLOCK_OFFSET,   # input [9:0] seq_addr; # sequence start address
                        2,                     # input [1:0] page;     # buffer page number
                        0,                     # input       urgent;   # high priority request (only for competion with other channels, will not pass in this FIFO)
                        0,                     # input       chn;      # channel buffer to use: 0 - memory read, 1 - memory write
                        wait_complete)         #  wait_complete; # Do not request a newe transaction from the scheduler until previous memory transaction is finished
        self.x393_pio_sequences.schedule_ps_pio ( # schedule software-control memory operation (may need to check FIFO status first)
                        self.READ_BLOCK_OFFSET,   # input [9:0] seq_addr; # sequence start address
                        1,                     # input [1:0] page;     # buffer page number
                        0,                     # input       urgent;   # high priority request (only for competion with other channels, will not pass in this FIFO)
                        0,                     # input       chn;      # channel buffer to use: 0 - memory read, 1 - memory write
                        wait_complete)         #  wait_complete; # Do not request a newe transaction from the scheduler until previous memory transaction is finished
        self.x393_pio_sequences.wait_ps_pio_done(self.DEFAULT_STATUS_MODE,1); # wait previous memory transaction finished before changing delays (effective immediately)
        return self.x393_mcntrl_buffers.read_block_buf_chn (0, 3, 256, 1, 1 ) # chn=0, page=3, number of 32-bit words=256, wait_done

    def test_scanline_write(self, #
                            channel,       # input            [3:0] channel;
                            extra_pages,   # input            [1:0] extra_pages;
                            wait_done,     # input                  wait_done;
                            window_width,  # input [15:0]           window_width;
                            window_height, # input [15:0]           window_height;
                            window_left,   # input [15:0]           window_left;
                            window_top):   # input [15:0]           window_top;
        """
        Test scanline write (frame size/row increment is set in parameters) 
        <channel> channel number to use. Valid values: 1, 3
        <extra_pages>    2-bit number of extra pages that need to stay (not to be overwritten) in the buffer
        <wait_done>      for operation finished
        <window_width>   13-bit window width in 8-bursts (16 bytes)
        <window_height>  16 bit window height
        <window_left>,   13-bit window left margin in 8-bursts (16 bytes)
        <window_top>     16-bit window top margin
        """
#   integer startx,starty; # temporary - because of the vdt bug with integer ports
#        pages_per_row= (window_width>>NUM_XFER_BITS)+((window_width[NUM_XFER_BITS-1:0]==0)?0:1);
        pages_per_row= (window_width>>self.NUM_XFER_BITS)+(0,1)[(window_width & ((1<<self.NUM_XFER_BITS))-1)==0] # (window_width>>NUM_XFER_BITS)+((window_width[NUM_XFER_BITS-1:0]==0)?0:1);
        print("====== test_scanline_write: channel=%d, extra_pages=%d,  wait_done=%d"%
                                                (channel,    extra_pages,     wait_done))
        if   channel == 1:
            start_addr=             self.MCNTRL_SCANLINE_CHN1_ADDR
            status_address=         self.MCNTRL_TEST01_STATUS_REG_CHN1_ADDR
            status_control_address= self.MCNTRL_TEST01_ADDR + self.MCNTRL_TEST01_CHN1_STATUS_CNTRL
            test_mode_address=      self.MCNTRL_TEST01_ADDR + self.MCNTRL_TEST01_CHN1_MODE
        elif channel ==  3:
            start_addr=             self.MCNTRL_SCANLINE_CHN3_ADDR
            status_address=         self.MCNTRL_TEST01_STATUS_REG_CHN3_ADDR
            status_control_address= self.MCNTRL_TEST01_ADDR + self.MCNTRL_TEST01_CHN3_STATUS_CNTRL
            test_mode_address=      self.MCNTRL_TEST01_ADDR + self.MCNTRL_TEST01_CHN3_MODE
        else:
            print("**** ERROR: Invalid channel, only 1 and 3 are valid")
            start_addr=             self.MCNTRL_SCANLINE_CHN1_ADDR
            status_address=         self.MCNTRL_TEST01_STATUS_REG_CHN1_ADDR
            status_control_address= self.MCNTRL_TEST01_ADDR + self.MCNTRL_TEST01_CHN1_STATUS_CNTRL
            test_mode_address=      self.MCNTRL_TEST01_ADDR + self.MCNTRL_TEST01_CHN1_MODE

        mode=   self.func_encode_mode_scanline(
                    extra_pages,
                    1,  # write_mem,
                    1,  # enable
                    0)  # chn_reset
                
        self.x393_axi_tasks.write_contol_register(start_addr + self.MCNTRL_SCANLINE_STARTADDR,        self.FRAME_START_ADDRESS); # RA=80, CA=0, BA=0 22-bit frame start address (3 CA LSBs==0. BA==0) 
        self.x393_axi_tasks.write_contol_register(start_addr + self.MCNTRL_SCANLINE_FRAME_FULL_WIDTH, self.FRAME_FULL_WIDTH);
        self.x393_axi_tasks.write_contol_register(start_addr + self.MCNTRL_SCANLINE_WINDOW_WH,        {window_height,window_width}); #WINDOW_WIDTH + (WINDOW_HEIGHT<<16));
        self.x393_axi_tasks.write_contol_register(start_addr + self.MCNTRL_SCANLINE_WINDOW_X0Y0,      {window_top,window_left}); #WINDOW_X0+ (WINDOW_Y0<<16));
        self.x393_axi_tasks.write_contol_register(start_addr + self.MCNTRL_SCANLINE_WINDOW_STARTXY,   self.SCANLINE_STARTX+(self.SCANLINE_STARTY<<16));
        self.x393_axi_tasks.write_contol_register(start_addr + self.MCNTRL_SCANLINE_MODE,             mode); 
        self.x393_axi_tasks.configure_channel_priority(channel,0);    # lowest priority channel 3
#        enable_memcntrl_channels(16'h000b); # channels 0,1,3 are enabled
        self.x393_axi_tasks.enable_memcntrl_en_dis(channel,1);
        self.x393_axi_tasks.write_contol_register(test_mode_address,            self.TEST01_START_FRAME);
        for ii in range(0,self.TEST_INITIAL_BURST): # for (ii=0;ii<TEST_INITIAL_BURST;ii=ii+1) begin
# VDT bugs: 1:does not propagate undefined width through ?:, 2: - does not allow to connect it to task integer input, 3: shows integer input width as 1
            if   pages_per_row > 1:
                if (ii % pages_per_row) < (pages_per_row-1):
                    xfer_size= 1 << self.NUM_XFER_BITS
                else:
                    xfer_size= window_width % (1<<self.NUM_XFER_BITS)
            else:
                xfer_size= window_width & 0xffff
                
            print("########### test_scanline_write block %d: channel=%d"%(ii, channel));
            startx=window_left + ((ii % pages_per_row) << self.NUM_XFER_BITS)
            starty=window_top + (ii / pages_per_row);
            self.x393_mcntrl_buffers.write_block_scanline_chn(
                                                              channel,
                                                              (ii & 3),
                                                              xfer_size,
                                                              startx,    #window_left + ((ii % pages_per_row)<<NUM_XFER_BITS),  # SCANLINE_CUR_X,
                                                              starty)    # window_top + (ii / pages_per_row)); # SCANLINE_CUR_Y);\
            
        for ii in range(window_height * pages_per_row): # for (ii=0;ii< (window_height * pages_per_row) ;ii = ii+1) begin # here assuming 1 page per line
            if (ii >= self.TEST_INITIAL_BURST):         #  begin # wait page ready and fill page after first 4 are filled
                self.x393_axi_tasks.wait_status_condition (
                                                           status_address,                   # MCNTRL_TEST01_STATUS_REG_CHN3_ADDR,
                                                           status_control_address,           # MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN3_STATUS_CNTRL,
                                                           self.DEFAULT_STATUS_MODE,
                                                           (ii-self.TEST_INITIAL_BURST)<<16, # 4-bit page number
                                                           0xf << 16,                        #'hf << 16,  # mask for the 4-bit page number
                                                           1,                                # not equal to
                                                           (0,1)[ii == self.TEST_INITIAL_BURST]) # synchronize sequence number - only first time, next just wait fro auto update
                if   pages_per_row > 1:
                    if (ii % pages_per_row) < (pages_per_row-1):
                        xfer_size= 1 << self.NUM_XFER_BITS
                    else:
                        xfer_size= window_width % (1<<self.NUM_XFER_BITS)
                else:
                    xfer_size= window_width & 0xffff
                    
                print("########### test_scanline_write block %d: channel=%d"%(ii, channel));
                startx=window_left + ((ii % pages_per_row) << self.NUM_XFER_BITS);
                starty=window_top + (ii / pages_per_row);
                self.x393_mcntrl_buffers.write_block_scanline_chn(
                                                                  channel,
                                                                  (ii & 3),
                                                                  xfer_size,
                                                                  startx,  # window_left + ((ii % pages_per_row)<<NUM_XFER_BITS),  # SCANLINE_CUR_X,
                                                                  starty) # window_top + (ii / pages_per_row)); # SCANLINE_CUR_Y);
            self.x393_axi_tasks.write_contol_register(test_mode_address,            self.TEST01_NEXT_PAGE)
        if wait_done:
            self.x393_axi_tasks.wait_status_condition ( # may also be read directly from the same bit of mctrl_linear_rw (address=5) status
                                                        status_address, # MCNTRL_TEST01_STATUS_REG_CHN3_ADDR,
                                                        status_control_address, # MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN3_STATUS_CNTRL,
                                                        self.DEFAULT_STATUS_MODE,
                                                        2 << self.STATUS_2LSB_SHFT, # bit 24 - busy, bit 25 - frame done
                                                        2 << self.STATUS_2LSB_SHFT,  # mask for the 4-bit page number
                                                        0, # equal to
                                                        0); # no need to synchronize sequence number
#     enable_memcntrl_en_dis(channel,0); # disable channel

    def test_scanline_read(self, # SuppressThisWarning VEditor - may be unused
                            channel,       # input            [3:0] channel;
                            extra_pages,   # input            [1:0] extra_pages;
                            show_data,     # input                  extra_pages;
                            window_width,  # input [15:0]           window_width;
                            window_height, # input [15:0]           window_height;
                            window_left,   # input [15:0]           window_left;
                            window_top):   # input [15:0]           window_top;
        """
        Test scanline read (frame size/row increment is set in parameters) 
        <channel> channel number to use. Valid values: 1, 3
        <extra_pages>    2-bit number of extra pages that need to stay (not to be overwritten) in the buffer
        <show_data>      print read data
        <window_width>   13-bit window width in 8-bursts (16 bytes)
        <window_height>  16 bit window height
        <window_left>,   13-bit window left margin in 8-bursts (16 bytes)
        <window_top>     16-bit window top margin
        Returns read data as list
        """
        
        result=[] # will be a 2-d array
    
#        pages_per_row= (window_width>>NUM_XFER_BITS)+((window_width[NUM_XFER_BITS-1:0]==0)?0:1);
        pages_per_row= (window_width>>self.NUM_XFER_BITS)+(0,1)[(window_width & ((1<<self.NUM_XFER_BITS))-1)==0] # (window_width>>NUM_XFER_BITS)+((window_width[NUM_XFER_BITS-1:0]==0)?0:1);

        print("====== test_scanline_read: channel=%d, extra_pages=%d,  show_data=%d"%
                                             (channel,    extra_pages,     show_data))
        if   channel == 1:
            start_addr=             self.MCNTRL_SCANLINE_CHN1_ADDR
            status_address=         self.MCNTRL_TEST01_STATUS_REG_CHN1_ADDR
            status_control_address= self.MCNTRL_TEST01_ADDR + self.MCNTRL_TEST01_CHN1_STATUS_CNTRL
            test_mode_address=      self.MCNTRL_TEST01_ADDR + self.MCNTRL_TEST01_CHN1_MODE
        elif channel == 3:
            start_addr=             self.MCNTRL_SCANLINE_CHN3_ADDR
            status_address=         self.MCNTRL_TEST01_STATUS_REG_CHN3_ADDR
            status_control_address= self.MCNTRL_TEST01_ADDR + self.MCNTRL_TEST01_CHN3_STATUS_CNTRL
            test_mode_address=      self.MCNTRL_TEST01_ADDR + self.MCNTRL_TEST01_CHN3_MODE
        else:
            print("**** ERROR: Invalid channel, only 1 and 3 are valid")
            start_addr=             self.MCNTRL_SCANLINE_CHN1_ADDR
            status_address=         self.MCNTRL_TEST01_STATUS_REG_CHN1_ADDR
            status_control_address= self.MCNTRL_TEST01_ADDR + self.MCNTRL_TEST01_CHN1_STATUS_CNTRL
            test_mode_address=      self.MCNTRL_TEST01_ADDR + self.MCNTRL_TEST01_CHN1_MODE
        mode=   self.func_encode_mode_scanline(
                                               extra_pages,
                                               0, # write_mem,
                                               1, # enable
                                               0)  # chn_reset
# program to the
        self.x393_axi_tasks.write_contol_register(start_addr + self.MCNTRL_SCANLINE_STARTADDR,        self.FRAME_START_ADDRESS); # RA=80, CA=0, BA=0 22-bit frame start address (3 CA LSBs==0. BA==0) 
        self.x393_axi_tasks.write_contol_register(start_addr + self.MCNTRL_SCANLINE_FRAME_FULL_WIDTH, self.FRAME_FULL_WIDTH);
        self.x393_axi_tasks.write_contol_register(start_addr + self.MCNTRL_SCANLINE_WINDOW_WH,        {window_height,window_width}); #WINDOW_WIDTH + (WINDOW_HEIGHT<<16));
        self.x393_axi_tasks.write_contol_register(start_addr + self.MCNTRL_SCANLINE_WINDOW_X0Y0,      {window_top,window_left}); #WINDOW_X0+ (WINDOW_Y0<<16));
        self.x393_axi_tasks.write_contol_register(start_addr + self.MCNTRL_SCANLINE_WINDOW_STARTXY,   self.SCANLINE_STARTX+(self.SCANLINE_STARTY<<16));
        self.x393_axi_tasks.write_contol_register(start_addr + self.MCNTRL_SCANLINE_MODE,             mode);# set mode register: {extra_pages[1:0],enable,!reset}
        self.x393_axi_tasks.configure_channel_priority(channel,0);    # lowest priority channel 3
        self.x393_axi_tasks.enable_memcntrl_en_dis(channel,1);
        self.x393_axi_tasks.write_contol_register(test_mode_address,            self.TEST01_START_FRAME);
        for ii in range(window_height * pages_per_row): # for (ii=0;ii<(window_height * pages_per_row);ii = ii+1) begin
            if   pages_per_row > 1:
                if (ii % pages_per_row) < (pages_per_row-1):
                    xfer_size= 1 << self.NUM_XFER_BITS
                else:
                    xfer_size= window_width % (1<<self.NUM_XFER_BITS)
            else:
                xfer_size= window_width & 0xffff
            self.x393_axi_tasks.wait_status_condition (
                                                       status_address, #MCNTRL_TEST01_STATUS_REG_CHN2_ADDR,
                                                       status_control_address, # MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN2_STATUS_CNTRL,
                                                       self.DEFAULT_STATUS_MODE,
                                                       (ii) << 16, # -TEST_INITIAL_BURST)<<16, # 4-bit page number
                                                       0xf << 16, #'hf << 16,  # mask for the 4-bit page number
                                                       1, # not equal to
                                                       (0,1)[ii == 0]) # synchronize sequence number - only first time, next just wait fro auto update
            # read block (if needed), for now just sikip  
            if (show_data): 
                print("########### test_scanline_read block %d: channel=%d"%(ii, channel));
            result.append(self.x393_mcntrl_buffers.read_block_buf_chn (
                                                                       channel,
                                                                       (ii & 3),
                                                                       xfer_size <<2,
                                                                       1, # chn=0, page=3, number of 32-bit words=256, wait_done
                                                                       show_data))
            self.x393_axi_tasks.write_contol_register(test_mode_address,            self.TEST01_NEXT_PAGE)
        return result    

    def test_tiled_write(self,          #
                         channel,       # input            [3:0] channel;
                         byte32,        # input                  byte32;
                         keep_open,     # input                  keep_open;
                         extra_pages,   # input            [1:0] extra_pages;
                         wait_done,     # input                  wait_done;
                         window_width,  # input [15:0]           window_width;
                         window_height, # input [15:0]           window_height;
                         window_left,   # input [15:0]           window_left;
                         window_top,    # input [15:0]           window_top;
                         tile_width,    # input [ 7:0]           tile_width;
                         tile_height,   # input [ 7:0]           tile_height;
                         tile_vstep):   # input [ 7:0]           tile_vstep;
        """
        Test tiled mode write (frame size/row increment is set in parameters) 
        <channel> channel number to use. Valid values: 2, 4
        <byte32>        use 32-byte wide columns (0 - use 16-byte ones)
        <keep_open>,    do not close page between accesses (for 8 or less rows only)
        <extra_pages>    2-bit number of extra pages that need to stay (not to be overwritten) in the buffer
        <wait_done>      wait for operation finished
        <window_width>   13-bit window width in 8-bursts (16 bytes)
        <window_height>  16 bit window height
        <window_left>,   13-bit window left margin in 8-bursts (16 bytes)
        <window_top>     16-bit window top margin
        <tile_width>     6-bit tile width in 8-bursts (16 bytes) (0 -> 64)
        <tile_height>    6-bit tile_height (0->64)
        <tile_vstep>     6-bit tile vertical step (0->64) to control tole vertical overlap
        """
        
#        tiles_per_row= (window_width/tile_width)+  ((window_width % tile_width==0)?0:1);
        tiles_per_row= (window_width/tile_width)+  (0,1)[(window_width % tile_width)==0]
        tile_rows_per_window= ((window_height-1)/tile_vstep) + 1
        tile_size= tile_width*tile_height;
        channel=   (0,1)[channel]
        keep_open= (0,1)[keep_open]
        wait_done= (0,1)[wait_done]
        
        print("====== test_tiled_write: channel=%d, byte32=%d, keep_open=%d, extra_pages=%d,  wait_done=%d"%
                                           (channel,    byte32,    keep_open,    extra_pages,     wait_done))
        if   channel == 2:
            start_addr=             self.MCNTRL_TILED_CHN2_ADDR
            status_address=         self.MCNTRL_TEST01_STATUS_REG_CHN2_ADDR
            status_control_address= self.MCNTRL_TEST01_ADDR + self.MCNTRL_TEST01_CHN2_STATUS_CNTRL
            test_mode_address=      self.MCNTRL_TEST01_ADDR + self.MCNTRL_TEST01_CHN2_MODE
        elif channel == 4:
            start_addr=             self.MCNTRL_TILED_CHN4_ADDR;
            status_address=         self.MCNTRL_TEST01_STATUS_REG_CHN4_ADDR;
            status_control_address= self.MCNTRL_TEST01_ADDR + self.MCNTRL_TEST01_CHN4_STATUS_CNTRL;
            test_mode_address=      self.MCNTRL_TEST01_ADDR + self.MCNTRL_TEST01_CHN4_MODE;
        else:
            print("**** ERROR: Invalid channel, only 2 and 4 are valid");
            start_addr=             self.MCNTRL_TILED_CHN2_ADDR;
            status_address=         self.MCNTRL_TEST01_STATUS_REG_CHN2_ADDR;
            status_control_address= self.MCNTRL_TEST01_ADDR + self.MCNTRL_TEST01_CHN2_STATUS_CNTRL;
            test_mode_address=      self.MCNTRL_TEST01_ADDR + self.MCNTRL_TEST01_CHN2_MODE;
        mode=   self.func_encode_mode_tiled(
                                            byte32,
                                            keep_open,
                                            extra_pages,
                                            1,           # write_mem,
                                            1,           # enable
                                            0)           # chn_reset
        self.x393_axi_tasks.write_contol_register(start_addr + self.MCNTRL_TILED_STARTADDR,
                                                  self.FRAME_START_ADDRESS) # RA=80, CA=0, BA=0 22-bit frame start address (3 CA LSBs==0. BA==0) 
        self.x393_axi_tasks.write_contol_register(start_addr + self.MCNTRL_TILED_FRAME_FULL_WIDTH,
                                                  self.FRAME_FULL_WIDTH)
        self.x393_axi_tasks.write_contol_register(start_addr + self.MCNTRL_TILED_WINDOW_WH,
                                                  concat(((window_height,16),
                                                          (window_width, 16)))) # {window_height,window_width});
        self.x393_axi_tasks.write_contol_register(start_addr + self.MCNTRL_TILED_WINDOW_X0Y0,
                                                  concat(((window_top,  16),
                                                          (window_left, 16))))  #  {window_top,window_left});
        self.x393_axi_tasks.write_contol_register(start_addr + self.MCNTRL_TILED_WINDOW_STARTXY,
                                                  concat(((self.TILED_STARTY, 16),
                                                          (self.TILED_STARTX, 16))))  #  TILED_STARTX+(TILED_STARTY<<16));
        self.x393_axi_tasks.write_contol_register(start_addr + self.MCNTRL_TILED_TILE_WHS,
                                                  concat(((tile_vstep, 8),
                                                          (tile_height, 8),
                                                          (tile_width, 8)))) # {8'b0,tile_vstep,tile_height,tile_width});#tile_width+(tile_height<<8)+(tile_vstep<<16));
        self.x393_axi_tasks.write_contol_register(start_addr + self.MCNTRL_TILED_MODE, mode);# set mode register: {extra_pages[1:0],enable,!reset}
        self.x393_axi_tasks.configure_channel_priority(channel,0)    # lowest priority channel 3
        self.x393_axi_tasks.enable_memcntrl_en_dis(channel,1);
        self.x393_axi_tasks.write_contol_register(test_mode_address,            self.TEST01_START_FRAME);
    
        for ii in range(self.TEST_INITIAL_BURST): # for (ii=0;ii<TEST_INITIAL_BURST;ii=ii+1) begin
            print("########### test_tiled_write block %d: channel=%d"%( ii, channel))
            startx = window_left + ((ii % tiles_per_row) * tile_width)
            starty = window_top + (ii / tile_rows_per_window)         # SCANLINE_CUR_Y);
            self.x393_mcntrl_buffers.write_block_scanline_chn( # TODO: Make a different tile buffer data, matching the order
                                                               channel, # channel
                                                               (ii & 3),
                                                               tile_size,
                                                               startx, #window_left + ((ii % tiles_per_row) * tile_width),
                                                               starty); #window_top + (ii / tile_rows_per_window)); # SCANLINE_CUR_Y);\
    
        for ii in range(tiles_per_row * tile_rows_per_window): # for (ii=0;ii<(tiles_per_row * tile_rows_per_window);ii = ii+1) begin
            if ii >= self.TEST_INITIAL_BURST: # ) begin # wait page ready and fill page after first 4 are filled
                self.x393_axi_tasks.wait_status_condition (
                                                           status_address,                   # MCNTRL_TEST01_STATUS_REG_CHN5_ADDR,
                                                           status_control_address,           # MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN5_STATUS_CNTRL,
                                                           self.DEFAULT_STATUS_MODE,
                                                           (ii-self.TEST_INITIAL_BURST)<<16, # 4-bit page number
                                                           0xf << 16,                        # 'hf << 16,  # mask for the 4-bit page number
                                                           1,                                # not equal to
                                                           (0,1)[ii == self.TEST_INITIAL_BURST]); # synchronize sequence number - only first time, next just wait fro auto update
                print("########### test_tiled_write block %d: channel=%d"%(ii, channel))
                startx = window_left + ((ii % tiles_per_row) * tile_width);
                starty = window_top + (ii / tile_rows_per_window);
                self.x393_mcntrl_buffers.write_block_scanline_chn( # TODO: Make a different tile buffer data, matching the order
                                                                   channel,  # channel
                                                                   (ii & 3),
                                                                   tile_size,
                                                                   startx,   # window_left + ((ii % tiles_per_row) * tile_width),
                                                                   starty)   # window_top + (ii / tile_rows_per_window)); # SCANLINE_CUR_Y);\
            self.x393_axi_tasks.write_contol_register(test_mode_address, self.TEST01_NEXT_PAGE);
        if wait_done:
            self.x393_axi_tasks.wait_status_condition( # may also be read directly from the same bit of mctrl_linear_rw (address=5) status
                                                       status_address,             # MCNTRL_TEST01_STATUS_REG_CHN3_ADDR,
                                                       status_control_address,     # MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN3_STATUS_CNTRL,
                                                       self.DEFAULT_STATUS_MODE,
                                                       2 << self.STATUS_2LSB_SHFT, # bit 24 - busy, bit 25 - frame done
                                                       2 << self.STATUS_2LSB_SHFT, # mask for the 4-bit page number
                                                       0,                          # equal to
                                                       0)                          # no need to synchronize sequence number
#     enable_memcntrl_en_dis(channel,0); # disable channel

    def test_tiled_read(self, #\
                        channel,       # input            [3:0] channel;
                        byte32,        # input                  byte32;
                        keep_open,     # input                  keep_open;
                        extra_pages,   # input            [1:0] extra_pages;
                        show_data,     # input                  show_data;
                        window_width,  # input [15:0]           window_width;
                        window_height, # input [15:0]           window_height;
                        window_left,   # input [15:0]           window_left;
                        window_top,    # input [15:0]           window_top;
                        tile_width,    # input [ 7:0]           tile_width;
                        tile_height,   # input [ 7:0]           tile_height;
                        tile_vstep):   # input [ 7:0]           tile_vstep;
        """
        Test tiled mode write (frame size/row increment is set in parameters) 
        <channel> channel number to use. Valid values: 2, 4
        <byte32>        use 32-byte wide columns (0 - use 16-byte ones)
        <keep_open>,    do not close page between accesses (for 8 or less rows only)
        <extra_pages>    2-bit number of extra pages that need to stay (not to be overwritten) in the buffer
        <show_data>      print read data
        <window_width>   13-bit window width in 8-bursts (16 bytes)
        <window_height>  16 bit window height
        <window_left>,   13-bit window left margin in 8-bursts (16 bytes)
        <window_top>     16-bit window top margin
        <tile_width>     6-bit tile width in 8-bursts (16 bytes) (0 -> 64)
        <tile_height>    6-bit tile_height (0->64)
        <tile_vstep>     6-bit tile vertical step (0->64) to control tole vertical overlap
        Returns read data as a list
        """
        result=[] # will be a 2-d array
#        tiles_per_row= (window_width/tile_width)+  ((window_width % tile_width==0)?0:1);
        tiles_per_row= (window_width/tile_width)+  (0,1)[(window_width % tile_width)==0]
        tile_rows_per_window= ((window_height-1)/tile_vstep) + 1
        tile_size= tile_width*tile_height;
        channel=   (0,1)[channel]
        keep_open= (0,1)[keep_open]
        show_data= (0,1)[show_data]
        print("====== test_tiled_read: channel=%d, byte32=%d, keep_open=%d, extra_pages=%d,  show_data=%d"%
                                          (channel,      byte32,  keep_open,    extra_pages,     show_data))
        if   channel == 2:
            start_addr=             self.MCNTRL_TILED_CHN2_ADDR;
            status_address=         self.MCNTRL_TEST01_STATUS_REG_CHN2_ADDR;
            status_control_address= self.MCNTRL_TEST01_ADDR + self.MCNTRL_TEST01_CHN2_STATUS_CNTRL;
            test_mode_address=      self.MCNTRL_TEST01_ADDR + self.MCNTRL_TEST01_CHN2_MODE;
        elif channel == 4:
            start_addr=             self.MCNTRL_TILED_CHN4_ADDR;
            status_address=         self.MCNTRL_TEST01_STATUS_REG_CHN4_ADDR;
            status_control_address= self.MCNTRL_TEST01_ADDR + self.MCNTRL_TEST01_CHN4_STATUS_CNTRL;
            test_mode_address=      self.MCNTRL_TEST01_ADDR + self.MCNTRL_TEST01_CHN4_MODE;
        else:
            print("**** ERROR: Invalid channel, only 2 and 4 are valid");
            start_addr=             self.MCNTRL_TILED_CHN2_ADDR;
            status_address=         self.MCNTRL_TEST01_STATUS_REG_CHN2_ADDR;
            status_control_address= self.MCNTRL_TEST01_ADDR + self.MCNTRL_TEST01_CHN2_STATUS_CNTRL;
            test_mode_address=      self.MCNTRL_TEST01_ADDR + self.MCNTRL_TEST01_CHN2_MODE;

        mode=   self.func_encode_mode_tiled(
                                            byte32,
                                            keep_open,
                                            extra_pages,
                                            0, # write_mem,
                                            1, # enable
                                            0)  # chn_reset
        self.x393_axi_tasks.write_contol_register(start_addr + self.MCNTRL_TILED_STARTADDR,
                                                  self.FRAME_START_ADDRESS) # RA=80, CA=0, BA=0 22-bit frame start address (3 CA LSBs==0. BA==0) 
        self.x393_axi_tasks.write_contol_register(start_addr + self.MCNTRL_TILED_FRAME_FULL_WIDTH,
                                                  self.FRAME_FULL_WIDTH)
        self.x393_axi_tasks.write_contol_register(start_addr + self.MCNTRL_TILED_WINDOW_WH,
                                                  concat(((window_height,16),
                                                          (window_width, 16)))) # {window_height,window_width});
        self.x393_axi_tasks.write_contol_register(start_addr + self.MCNTRL_TILED_WINDOW_X0Y0,
                                                  concat(((window_top,  16),
                                                          (window_left, 16))))  #  {window_top,window_left});
        self.x393_axi_tasks.write_contol_register(start_addr + self.MCNTRL_TILED_WINDOW_STARTXY,
                                                  concat(((self.TILED_STARTY, 16),
                                                          (self.TILED_STARTX, 16))))  #  TILED_STARTX+(TILED_STARTY<<16));
        self.x393_axi_tasks.write_contol_register(start_addr + self.MCNTRL_TILED_TILE_WHS,
                                                  concat(((tile_vstep, 8),
                                                          (tile_height, 8),
                                                          (tile_width, 8)))) # {8'b0,tile_vstep,tile_height,tile_width});#tile_width+(tile_height<<8)+(tile_vstep<<16));
        self.x393_axi_tasks.write_contol_register(start_addr + self.MCNTRL_TILED_MODE, mode);# set mode register: {extra_pages[1:0],enable,!reset}
        self.x393_axi_tasks.configure_channel_priority(channel,0)    # lowest priority channel 3
        self.x393_axi_tasks.enable_memcntrl_en_dis(channel,1);
        self.x393_axi_tasks.write_contol_register(test_mode_address,            self.TEST01_START_FRAME);
        for ii in range(tiles_per_row * tile_rows_per_window): # (ii=0;ii<(tiles_per_row * tile_rows_per_window);ii = ii+1) begin
            self.x393_axi_tasks.wait_status_condition (
                                                       status_address, # MCNTRL_TEST01_STATUS_REG_CHN4_ADDR,
                                                       status_control_address, # MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN4_STATUS_CNTRL,
                                                       self.DEFAULT_STATUS_MODE,
                                                       ii << 16, # -TEST_INITIAL_BURST)<<16, # 4-bit page number
                                                       0xf<< 16, #'hf << 16,  # mask for the 4-bit page number
                                                       1, # not equal to
                                                       (0,1)[ii == 0]) # synchronize sequence number - only first time, next just wait fro auto update
            if (show_data): 
                print("########### test_tiled_read block %d: channel=%d"%(ii, channel))
                    
            result.append(self.x393_mcntrl_buffers.read_block_buf_chn (channel,
                                                                       (ii & 3),
                                                                       tile_size <<2,
                                                                       1, # chn=0, page=3, number of 32-bit words=256, wait_done
                                                                       show_data))
            self.x393_axi_tasks.write_contol_register(test_mode_address, self.TEST01_NEXT_PAGE);
#     enable_memcntrl_en_dis(channel,0); # disable channel
        return result    
