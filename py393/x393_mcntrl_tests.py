from __future__ import division
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
from x393_mem                import X393Mem
import x393_axi_control_status
from x393_pio_sequences      import X393PIOSequences
from x393_mcntrl_timing      import X393McntrlTiming
from x393_mcntrl_buffers     import X393McntrlBuffers
from verilog_utils import concat,convert_w32_to_mem16 #, getParWidth
import vrlg
import x393_mcntrl
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
        self.x393_axi_tasks=x393_axi_control_status.X393AxiControlStatus(debug_mode,dry_mode)
        self.x393_pio_sequences=  X393PIOSequences(debug_mode,dry_mode)
        self.x393_mcntrl_timing=  X393McntrlTiming(debug_mode,dry_mode)
        self.x393_mcntrl_buffers= X393McntrlBuffers(debug_mode,dry_mode)
#        self.x393_mcntrl_adjust=  X393McntrlAdjust(debug_mode,dry_mode)
        try:
            self.verbose=vrlg.VERBOSE
        except:
            pass
    '''
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
                       ((1,0)[chn_reset],1)))[0]# ~chn_reset};

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
        return concat ((
                       (extra_pages,     2), # extra_pages,
                       ((0,1)[write_mem],1), # write_mem,
                       ((0,1)[enable],   1), #enable,
                       ((1,0)[chn_reset],1)))[0] # ~chn_reset};
    '''    
    def test_write_levelling(self,
                            dqs_odly= None,
                            wbuf_dly = None,
                            wait_complete=1, # Wait for operation to complete
                            quiet=0):       
        """
        Test write levelling mode 
        <dqs_dly>  DQS output delay for write levelling mode. If it is not None,
                   the default DQS output delay will be restored in the end
        <wbuf_dly> Write buffer latency (currently 9)  If it is not None,
                   the default wbuf delay will be restored in the end
        <wait_complete> wait write levelling operation to complete (0 - may initiate multiple PS PIO operations)
        <quiet>    reduce output
        returns a pair of ratios for getting "1" for 2 lanes and problem marker (should be 0)
        """
        self.x393_pio_sequences.set_write_lev(16) # write leveling, 16 times   (full buffer - 128) 

        if not dqs_odly is None:
            self.x393_mcntrl_timing.axi_set_dqs_odelay(dqs_odly)
# Set write buffer (from DDR3) WE signal delay for write leveling mode
        if not wbuf_dly is None:
            self.x393_mcntrl_timing.axi_set_wbuf_delay(wbuf_dly)
            
        rslt= self.x393_pio_sequences.write_levelling(
                     wait_complete,
                     16, # number of 8-bursts
                     quiet)
        #restore values to defaults (only if changed)
        if not dqs_odly is None:
            self.x393_mcntrl_timing.axi_set_dqs_odelay()
# Set write buffer (from DDR3) WE signal delay for write leveling mode
        if not wbuf_dly is None:
            self.x393_mcntrl_timing.axi_set_wbuf_delay()
#        if quiet <2:
#            print ("WLEV lanes ratios: %f %f, non 0x00/0x01 bytes: %f"%(rslt[0],rslt[1],rslt[2]))   
        return rslt
   
    def test_read_pattern(self,
                          dq_idelay=None,
                          dqs_idelay=None,
                          wait_complete=1): # Wait for operation to complete
        """
        Test read pattern mode
        <dq_idelay>  set DQ input delays if provided ([] - skip, single number - both lanes, 2 element list - per/lane)
        <dqs_idelay> set DQS input delays if provided ([] - skip, single number - both lanes, 2 element list - per/lane)
        <wait_complete> wait read pattern operation to complete (0 - may initiate multiple PS PIO operations)
        returns list of the read data
        """
        if (not dq_idelay is None) and (dq_idelay != []):
            self.x393_mcntrl_timing.axi_set_dq_idelay(dq_idelay)
        if (not dqs_idelay is None) and (dqs_idelay != []):
            self.x393_mcntrl_timing.axi_set_dqs_idelay(dqs_idelay)
        return self.x393_pio_sequences.read_pattern(
                     32, # num
                     1, # show_rslt,
                     wait_complete) #  # Wait for operation to complete
    def test_write_block(self,
                         dq_odelay=None,
                         dqs_odelay=None,
                         wait_complete=1): # Wait for operation to complete
        """
        Test write block in PS PIO mode 
        <dq_odelay>  set DQ output delays if provided ([] - skip, single number - both lanes, 2 element list - per/lane)
        <dqs odelay> set DQS output delays if provided ([] - skip, single number - both lanes, 2 element list - per/lane)
        <wait_complete> wait write block operation to complete (0 - may initiate multiple PS PIO operations)
        """
        if (not dq_odelay is None) and (dq_odelay != []):
            self.x393_mcntrl_timing.axi_set_dq_odelay(dq_odelay)
        if (not dqs_odelay is None) and (dqs_odelay != []):
            self.x393_mcntrl_timing.axi_set_dqs_odelay(dqs_odelay)
        return self.x393_pio_sequences.write_block(0,wait_complete) # Wait for operation to complete

    def test_read_block(self,
                        dq_idelay=None,
                        dqs_idelay=None,
                        wait_complete=1): # Wait for operation to complete
        """
        Test read block in PS PIO mode 
        <dq_idelay>  set DQ input delays if provided ([] - skip, single number - both lanes, 2 element list - per/lane)
        <dqs_idelay> set DQS input delays if provided ([] - skip, single number - both lanes, 2 element list - per/lane)
        <wait_complete> wait read block operation to complete (0 - may initiate multiple PS PIO operations)
        returns list of the read data
        """
        if (not dq_idelay is None) and (dq_idelay != []):
            self.x393_mcntrl_timing.axi_set_dq_idelay(dq_idelay)
        if (not dqs_idelay is None) and (dqs_idelay != []):
            self.x393_mcntrl_timing.axi_set_dqs_idelay(dqs_idelay)
        rd_buf = self.x393_pio_sequences.read_block(
                     256,           # num,
                     0,             # show_rslt,
                     wait_complete) # Wait for operation to complete
        sum_rd_buf=0
        for d in rd_buf:
            sum_rd_buf+=d
        print("read buffer: (0x%x):"%sum_rd_buf)
        for i in range(len(rd_buf)):
            if (i & 0xf) == 0:
                print("\n%03x:"%i,end=" ")
            print("%08x"%rd_buf[i],end=" ")
        print("\n")        
        return rd_buf
        
    def test_read_block16(self,
                        dq_idelay=None,
                        dqs_idelay=None,
                        wait_complete=1): # Wait for operation to complete
        """
        Test read block in PS PIO mode, convert data to match DDR3 16-bit output words  
        <dq_idelay>  set DQ input delays if provided ([] - skip, single number - both lanes, 2 element list - per/lane)
        <dqs_idelay> set DQS input delays if provided ([] - skip, single number - both lanes, 2 element list - per/lane)
        <wait_complete> wait read block operation to complete (0 - may initiate multiple PS PIO operations)
        returns list of the read data
        """
        if (not dq_idelay is None) and (dq_idelay != []):
            self.x393_mcntrl_timing.axi_set_dq_idelay(dq_idelay)
        if (not dqs_idelay is None) and (dqs_idelay != []):
            self.x393_mcntrl_timing.axi_set_dqs_idelay(dqs_idelay)
        rd_buf = self.x393_pio_sequences.read_block(
                     256,           # num,
                     0,             # show_rslt,
                     wait_complete) # Wait for operation to complete
        read16=convert_w32_to_mem16(rd_buf) # 512x16 bit, same as DDR3 DQ over time
        sum_read16=0
        for d in read16:
            sum_read16+=d
        print("read16 (0x%x):"%sum_read16)
        for i in range(len(read16)):
            if (i & 0x1f) == 0:
                print("\n%03x:"%i,end=" ")
            print("%04x"%read16[i],end=" ")
        print("\n")
        return read16
        
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
        pages_per_row= (window_width>>vrlg.NUM_XFER_BITS)+(1,0)[(window_width & ((1<<vrlg.NUM_XFER_BITS))-1)==0] # (window_width>>NUM_XFER_BITS)+((window_width[NUM_XFER_BITS-1:0]==0)?0:1);
        print("====== test_scanline_write: channel=%d, extra_pages=%d,  wait_done=%d"%
                                                (channel,    extra_pages,     wait_done))
        '''
        if   channel == 1:
            start_addr=             vrlg.MCNTRL_SCANLINE_CHN1_ADDR
            status_address=         vrlg.MCNTRL_TEST01_STATUS_REG_CHN1_ADDR
            status_control_address= vrlg.MCNTRL_TEST01_ADDR + vrlg.MCNTRL_TEST01_CHN1_STATUS_CNTRL
            test_mode_address=      vrlg.MCNTRL_TEST01_ADDR + vrlg.MCNTRL_TEST01_CHN1_MODE
        '''            
        if channel ==  3:
            start_addr=             vrlg.MCNTRL_SCANLINE_CHN3_ADDR
            status_address=         vrlg.MCNTRL_TEST01_STATUS_REG_CHN3_ADDR
            status_control_address= vrlg.MCNTRL_TEST01_ADDR + vrlg.MCNTRL_TEST01_CHN3_STATUS_CNTRL
            test_mode_address=      vrlg.MCNTRL_TEST01_ADDR + vrlg.MCNTRL_TEST01_CHN3_MODE
        else:
            print("**** ERROR: Invalid channel, only 3 is valid")
            start_addr=             vrlg.MCNTRL_SCANLINE_CHN1_ADDR
            status_address=         vrlg.MCNTRL_TEST01_STATUS_REG_CHN3_ADDR
            status_control_address= vrlg.MCNTRL_TEST01_ADDR + vrlg.MCNTRL_TEST01_CHN3_STATUS_CNTRL
            test_mode_address=      vrlg.MCNTRL_TEST01_ADDR + vrlg.MCNTRL_TEST01_CHN3_MODE

        '''
        mode=   self.func_encode_mode_scanline(
                    extra_pages,
                    1,  # write_mem,
                    1,  # enable
                    0)  # chn_reset
        '''
        mode=   x393_mcntrl.func_encode_mode_scan_tiled(
                                   skip_too_late = False,
                                   disable_need = False,
                                   repetitive=    True,
                                   single =       False,
                                   reset_frame =  True, # False,
                                   extra_pages =  extra_pages,
                                   write_mem =    True,
                                   enable =       True,
                                   chn_reset =    False,
                                   abort_late =   False)
            
                                
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_SCANLINE_MODE, 0); # reset channel, including page address
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_SCANLINE_STARTADDR,        vrlg.FRAME_START_ADDRESS); # RA=80, CA=0, BA=0 22-bit frame start address (3 CA LSBs==0. BA==0) 
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_SCANLINE_FRAME_FULL_WIDTH, vrlg.FRAME_FULL_WIDTH);
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_SCANLINE_WINDOW_WH,        (window_height<<16) | window_width); #WINDOW_WIDTH + (WINDOW_HEIGHT<<16));
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_SCANLINE_WINDOW_X0Y0,      (window_top<<16) | window_left); #WINDOW_X0+ (WINDOW_Y0<<16));
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_SCANLINE_WINDOW_STARTXY,   vrlg.SCANLINE_STARTX+(vrlg.SCANLINE_STARTY<<16));
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_SCANLINE_MODE,             mode); 
        self.x393_axi_tasks.configure_channel_priority(channel,0);    # lowest priority channel 3
#        enable_memcntrl_channels(16'h000b); # channels 0,1,3 are enabled
        self.x393_axi_tasks.enable_memcntrl_en_dis(channel,1);
        self.x393_axi_tasks.write_control_register(test_mode_address,            vrlg.TEST01_START_FRAME);
        for ii in range(0,vrlg.TEST_INITIAL_BURST): # for (ii=0;ii<TEST_INITIAL_BURST;ii=ii+1) begin
# VDT bugs: 1:does not propagate undefined width through ?:, 2: - does not allow to connect it to task integer input, 3: shows integer input width as 1
            if   pages_per_row > 1:
                if (ii % pages_per_row) < (pages_per_row-1):
                    xfer_size= 1 << vrlg.NUM_XFER_BITS
                else:
                    xfer_size= window_width % (1<<vrlg.NUM_XFER_BITS)
            else:
                xfer_size= window_width & 0xffff
                
            print("########### test_scanline_write block %d: channel=%d"%(ii, channel));
            startx=window_left + ((ii % pages_per_row) << vrlg.NUM_XFER_BITS)
            starty=window_top + (ii // pages_per_row);
            self.x393_mcntrl_buffers.write_block_scanline_chn(
                                                              channel,
                                                              (ii & 3),
                                                              xfer_size,
                                                              startx,    #window_left + ((ii % pages_per_row)<<NUM_XFER_BITS),  # SCANLINE_CUR_X,
                                                              starty)    # window_top + (ii / pages_per_row)); # SCANLINE_CUR_Y);\
            
        for ii in range(window_height * pages_per_row): # for (ii=0;ii< (window_height * pages_per_row) ;ii = ii+1) begin # here assuming 1 page per line
            if (ii >= vrlg.TEST_INITIAL_BURST):         #  begin # wait page ready and fill page after first 4 are filled
                self.x393_axi_tasks.wait_status_condition (
                                                           status_address,                   # MCNTRL_TEST01_STATUS_REG_CHN3_ADDR,
                                                           status_control_address,           # MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN3_STATUS_CNTRL,
                                                           vrlg.DEFAULT_STATUS_MODE,
                                                           (ii-vrlg.TEST_INITIAL_BURST)<<16, # 4-bit page number
                                                           0xf << 16,                        #'hf << 16,  # mask for the 4-bit page number
                                                           1,                                # not equal to
                                                           (0,1)[ii == vrlg.TEST_INITIAL_BURST]) # synchronize sequence number - only first time, next just wait fro auto update
                if   pages_per_row > 1:
                    if (ii % pages_per_row) < (pages_per_row-1):
                        xfer_size= 1 << vrlg.NUM_XFER_BITS
                    else:
                        xfer_size= window_width % (1<<vrlg.NUM_XFER_BITS)
                else:
                    xfer_size= window_width & 0xffff
                    
                print("########### test_scanline_write block %d: channel=%d"%(ii, channel));
                startx=window_left + ((ii % pages_per_row) << vrlg.NUM_XFER_BITS);
                starty=window_top + (ii // pages_per_row);
                self.x393_mcntrl_buffers.write_block_scanline_chn(
                                                                  channel,
                                                                  (ii & 3),
                                                                  xfer_size,
                                                                  startx,  # window_left + ((ii % pages_per_row)<<NUM_XFER_BITS),  # SCANLINE_CUR_X,
                                                                  starty) # window_top + (ii / pages_per_row)); # SCANLINE_CUR_Y);
            self.x393_axi_tasks.write_control_register(test_mode_address,            vrlg.TEST01_NEXT_PAGE)
        if wait_done:
            self.x393_axi_tasks.wait_status_condition ( # may also be read directly from the same bit of mctrl_linear_rw (address=5) status
                                                        status_address, # MCNTRL_TEST01_STATUS_REG_CHN3_ADDR,
                                                        status_control_address, # MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN3_STATUS_CNTRL,
                                                        vrlg.DEFAULT_STATUS_MODE,
                                                        2 << vrlg.STATUS_2LSB_SHFT, # bit 24 - busy, bit 25 - frame done
                                                        2 << vrlg.STATUS_2LSB_SHFT,  # mask for the 4-bit page number
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
                            window_top,    # input [15:0]           window_top;
                            frame_start_addr = 0x0, # 1000,
                            frame_full_width = 0xc0):
        """
        Test scanline read (frame size/row increment is set in parameters) 
        @param channel channel number to use. Valid values: 1, 3
        @param extra_pages    2-bit number of extra pages that need to stay (not to be overwritten) in the buffer
        @param show_data      print read data 
        @param window_width   13-bit window width in 8-bursts (16 bytes)
        @param window_height  16 bit window height
        @param window_left,   13-bit window left margin in 8-bursts (16 bytes)
        @param window_top     16-bit window top margin
        @param frame_start_addr - frame start address (was 0x1000)
        @param frame_full_width - frame full width in bursts (16 bytes) - was 0xc0
        @return read data as list
        """
        if show_data==2:
            result=self.test_scanline_read (channel = channel,       # input            [3:0] channel;
                                            extra_pages = extra_pages,   # input            [1:0] extra_pages;
                                            show_data = 0,     # input                  extra_pages;
                                            window_width = window_width,  # input [15:0]           window_width;
                                            window_height = window_height, # input [15:0]           window_height;
                                            window_left = window_left,   # input [15:0]           window_left;
                                            window_top = window_top)
            for line_no,line in enumerate(result):
                print("%03x:"%(line_no),end=" ")
                for i in range(len(line)//2):
                    d = line[2*i] + (line[2*i+1] << 32)
                    print("%16x"%(d),end=" ")
                print()    
            return result
        
        result=[] # will be a 2-d array
    
#        pages_per_row= (window_width>>NUM_XFER_BITS)+((window_width[NUM_XFER_BITS-1:0]==0)?0:1);
        pages_per_row= (window_width>>vrlg.NUM_XFER_BITS)+(1,0)[(window_width & ((1<<vrlg.NUM_XFER_BITS))-1)==0] # (window_width>>NUM_XFER_BITS)+((window_width[NUM_XFER_BITS-1:0]==0)?0:1);

        print("====== test_scanline_read: channel=%d, extra_pages=%d,  show_data=%d"%
                                             (channel,    extra_pages,     show_data))
        '''
        if   channel == 1:
            start_addr=             vrlg.MCNTRL_SCANLINE_CHN1_ADDR
            status_address=         vrlg.MCNTRL_TEST01_STATUS_REG_CHN1_ADDR
            status_control_address= vrlg.MCNTRL_TEST01_ADDR + vrlg.MCNTRL_TEST01_CHN1_STATUS_CNTRL
            test_mode_address=      vrlg.MCNTRL_TEST01_ADDR + vrlg.MCNTRL_TEST01_CHN1_MODE
        '''
        if channel == 3:
            start_addr=             vrlg.MCNTRL_SCANLINE_CHN3_ADDR
            status_address=         vrlg.MCNTRL_TEST01_STATUS_REG_CHN3_ADDR
            status_control_address= vrlg.MCNTRL_TEST01_ADDR + vrlg.MCNTRL_TEST01_CHN3_STATUS_CNTRL
            test_mode_address=      vrlg.MCNTRL_TEST01_ADDR + vrlg.MCNTRL_TEST01_CHN3_MODE
        else:
            print("**** ERROR: Invalid channel, only 3 is valid")
            start_addr=             vrlg.MCNTRL_SCANLINE_CHN3_ADDR
            status_address=         vrlg.MCNTRL_TEST01_STATUS_REG_CHN3_ADDR
            status_control_address= vrlg.MCNTRL_TEST01_ADDR + vrlg.MCNTRL_TEST01_CHN3_STATUS_CNTRL
            test_mode_address=      vrlg.MCNTRL_TEST01_ADDR + vrlg.MCNTRL_TEST01_CHN3_MODE
        '''    
        mode=   self.func_encode_mode_scanline(
                                               extra_pages,
                                               0, # write_mem,
                                               1, # enable
                                               0)  # chn_reset
        '''
        mode=   x393_mcntrl.func_encode_mode_scan_tiled(
                                   skip_too_late = False,
                                   disable_need = False,
                                   repetitive=    True,
                                   single =       False,
                                   reset_frame =  True, # False,
                                   extra_pages =  extra_pages,
                                   write_mem =    False,
                                   enable =       True,
                                   chn_reset =    False,
                                   abort_late =   False)
            
# program to the
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_SCANLINE_MODE, 0); # reset channel, including page address
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_SCANLINE_STARTADDR,        frame_start_addr); # RA=80, CA=0, BA=0 22-bit frame start address (3 CA LSBs==0. BA==0) 
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_SCANLINE_FRAME_FULL_WIDTH, frame_full_width);
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_SCANLINE_WINDOW_WH,        (window_height << 16) | window_width); #WINDOW_WIDTH + (WINDOW_HEIGHT<<16));
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_SCANLINE_WINDOW_X0Y0,      (window_top    << 16) | window_left); #WINDOW_X0+ (WINDOW_Y0<<16));
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_SCANLINE_WINDOW_STARTXY,   vrlg.SCANLINE_STARTX+(vrlg.SCANLINE_STARTY<<16));
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_SCANLINE_MODE,             mode);# set mode register: {extra_pages[1:0],enable,!reset}
        self.x393_axi_tasks.configure_channel_priority(channel,0);    # lowest priority channel 3
        self.x393_axi_tasks.enable_memcntrl_en_dis(channel,1);
        self.x393_axi_tasks.write_control_register(test_mode_address,            vrlg.TEST01_START_FRAME);
        for ii in range(window_height * pages_per_row): # for (ii=0;ii<(window_height * pages_per_row);ii = ii+1) begin
            if   pages_per_row > 1:
                if (ii % pages_per_row) < (pages_per_row-1):
                    xfer_size= 1 << vrlg.NUM_XFER_BITS
                else:
                    xfer_size= window_width % (1<<vrlg.NUM_XFER_BITS)
            else:
                xfer_size= window_width & 0xffff
            self.x393_axi_tasks.wait_status_condition (
                                                       status_address, #MCNTRL_TEST01_STATUS_REG_CHN2_ADDR,
                                                       status_control_address, # MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN2_STATUS_CNTRL,
                                                       vrlg.DEFAULT_STATUS_MODE,
                                                       (ii) << 16, # -TEST_INITIAL_BURST)<<16, # 4-bit page number
                                                       0xf << 16, #'hf << 16,  # mask for the 4-bit page number
                                                       1, # not equal to
                                                       (0,1)[ii == 0]) # synchronize sequence number - only first time, next just wait for auto update
            # read block (if needed), for now just skip  
            if (show_data): 
                print("########### test_scanline_read block %d: channel=%d"%(ii, channel));
            result.append(self.x393_mcntrl_buffers.read_block_buf_chn (
                                                                       channel,
                                                                       (ii & 3),
                                                                       xfer_size <<2,
#                                                                       1, # chn=0, page=3, number of 32-bit words=256, show_rslt
                                                                       show_data))
            self.x393_axi_tasks.write_control_register(test_mode_address,            vrlg.TEST01_NEXT_PAGE)
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
        tiles_per_row= (window_width//tile_width)+  (0,1)[(window_width % tile_width)==0]
        tile_rows_per_window= ((window_height-1)//tile_vstep) + 1
        tile_size= tile_width*tile_height;
        channel=   (0,1)[channel]
        keep_open= (0,1)[keep_open]
        wait_done= (0,1)[wait_done]
        
        print("====== test_tiled_write: channel=%d, byte32=%d, keep_open=%d, extra_pages=%d,  wait_done=%d"%
                                           (channel,    byte32,    keep_open,    extra_pages,     wait_done))
        if   channel == 2:
            start_addr=             vrlg.MCNTRL_TILED_CHN2_ADDR
            status_address=         vrlg.MCNTRL_TEST01_STATUS_REG_CHN2_ADDR
            status_control_address= vrlg.MCNTRL_TEST01_ADDR + vrlg.MCNTRL_TEST01_CHN2_STATUS_CNTRL
            test_mode_address=      vrlg.MCNTRL_TEST01_ADDR + vrlg.MCNTRL_TEST01_CHN2_MODE
        elif channel == 4:
            start_addr=             vrlg.MCNTRL_TILED_CHN4_ADDR;
            status_address=         vrlg.MCNTRL_TEST01_STATUS_REG_CHN4_ADDR;
            status_control_address= vrlg.MCNTRL_TEST01_ADDR + vrlg.MCNTRL_TEST01_CHN4_STATUS_CNTRL;
            test_mode_address=      vrlg.MCNTRL_TEST01_ADDR + vrlg.MCNTRL_TEST01_CHN4_MODE;
        else:
            print("**** ERROR: Invalid channel, only 2 and 4 are valid");
            start_addr=             vrlg.MCNTRL_TILED_CHN2_ADDR;
            status_address=         vrlg.MCNTRL_TEST01_STATUS_REG_CHN2_ADDR;
            status_control_address= vrlg.MCNTRL_TEST01_ADDR + vrlg.MCNTRL_TEST01_CHN2_STATUS_CNTRL;
            test_mode_address=      vrlg.MCNTRL_TEST01_ADDR + vrlg.MCNTRL_TEST01_CHN2_MODE;
        '''    
        mode=   self.func_encode_mode_tiled(
                                            byte32,
                                            keep_open,
                                            extra_pages,
                                            1,           # write_mem,
                                            1,           # enable
                                            0)           # chn_reset
        '''
        mode=   x393_mcntrl.func_encode_mode_scan_tiled(
                                   skip_too_late = False,
                                   disable_need = False,
                                   repetitive=    True,
                                   single =       False,
                                   reset_frame =  True, # False,
                                   byte32 =       byte32,
                                   keep_open =    keep_open,
                                   extra_pages =  extra_pages,
                                   write_mem =    True,
                                   enable =       True,
                                   chn_reset =    False,
                                   abort_late =   False)
                                                        
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_TILED_MODE, 0); # reset channel, including page address
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_TILED_STARTADDR,
                                                  vrlg.FRAME_START_ADDRESS) # RA=80, CA=0, BA=0 22-bit frame start address (3 CA LSBs==0. BA==0) 
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_TILED_FRAME_FULL_WIDTH,
                                                  vrlg.FRAME_FULL_WIDTH)
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_TILED_WINDOW_WH,
                                                  concat(((window_height,16),
                                                          (window_width, 16)))[0]) # {window_height,window_width});
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_TILED_WINDOW_X0Y0,
                                                  concat(((window_top,  16),
                                                          (window_left, 16)))[0])  #  {window_top,window_left});
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_TILED_WINDOW_STARTXY,
                                                  concat(((vrlg.TILED_STARTY, 16),
                                                          (vrlg.TILED_STARTX, 16)))[0])  #  TILED_STARTX+(TILED_STARTY<<16));
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_TILED_TILE_WHS,
                                                  concat(((tile_vstep, 8),
                                                          (tile_height, 8),
                                                          (tile_width, 8)))[0]) # {8'b0,tile_vstep,tile_height,tile_width});#tile_width+(tile_height<<8)+(tile_vstep<<16));
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_TILED_MODE, mode);# set mode register: {extra_pages[1:0],enable,!reset}
        self.x393_axi_tasks.configure_channel_priority(channel,0)    # lowest priority channel 3
        self.x393_axi_tasks.enable_memcntrl_en_dis(channel,1);
        self.x393_axi_tasks.write_control_register(test_mode_address,            vrlg.TEST01_START_FRAME);
    
        for ii in range(vrlg.TEST_INITIAL_BURST): # for (ii=0;ii<TEST_INITIAL_BURST;ii=ii+1) begin
            print("########### test_tiled_write block %d: channel=%d"%( ii, channel))
            startx = window_left + ((ii % tiles_per_row) * tile_width)
            starty = window_top + (ii // tile_rows_per_window)         # SCANLINE_CUR_Y);
            self.x393_mcntrl_buffers.write_block_scanline_chn( # TODO: Make a different tile buffer data, matching the order
                                                               channel, # channel
                                                               (ii & 3),
                                                               tile_size,
                                                               startx, #window_left + ((ii % tiles_per_row) * tile_width),
                                                               starty); #window_top + (ii / tile_rows_per_window)); # SCANLINE_CUR_Y);\
    
        for ii in range(tiles_per_row * tile_rows_per_window): # for (ii=0;ii<(tiles_per_row * tile_rows_per_window);ii = ii+1) begin
            if ii >= vrlg.TEST_INITIAL_BURST: # ) begin # wait page ready and fill page after first 4 are filled
                self.x393_axi_tasks.wait_status_condition (
                                                           status_address,                   # MCNTRL_TEST01_STATUS_REG_CHN5_ADDR,
                                                           status_control_address,           # MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN5_STATUS_CNTRL,
                                                           vrlg.DEFAULT_STATUS_MODE,
                                                           (ii-vrlg.TEST_INITIAL_BURST)<<16, # 4-bit page number
                                                           0xf << 16,                        # 'hf << 16,  # mask for the 4-bit page number
                                                           1,                                # not equal to
                                                           (0,1)[ii == vrlg.TEST_INITIAL_BURST]); # synchronize sequence number - only first time, next just wait fro auto update
                print("########### test_tiled_write block %d: channel=%d"%(ii, channel))
                startx = window_left + ((ii % tiles_per_row) * tile_width);
                starty = window_top + (ii // tile_rows_per_window);
                self.x393_mcntrl_buffers.write_block_scanline_chn( # TODO: Make a different tile buffer data, matching the order
                                                                   channel,  # channel
                                                                   (ii & 3),
                                                                   tile_size,
                                                                   startx,   # window_left + ((ii % tiles_per_row) * tile_width),
                                                                   starty)   # window_top + (ii / tile_rows_per_window)); # SCANLINE_CUR_Y);\
            self.x393_axi_tasks.write_control_register(test_mode_address, vrlg.TEST01_NEXT_PAGE);
        if wait_done:
            self.x393_axi_tasks.wait_status_condition( # may also be read directly from the same bit of mctrl_linear_rw (address=5) status
                                                       status_address,             # MCNTRL_TEST01_STATUS_REG_CHN3_ADDR,
                                                       status_control_address,     # MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN3_STATUS_CNTRL,
                                                       vrlg.DEFAULT_STATUS_MODE,
                                                       2 << vrlg.STATUS_2LSB_SHFT, # bit 24 - busy, bit 25 - frame done
                                                       2 << vrlg.STATUS_2LSB_SHFT, # mask for the 4-bit page number
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
        tiles_per_row= (window_width//tile_width)+  (0,1)[(window_width % tile_width)==0]
        tile_rows_per_window= ((window_height-1)//tile_vstep) + 1
        tile_size= tile_width*tile_height;
        channel=   (0,1)[channel]
        keep_open= (0,1)[keep_open]
        show_data= (0,1)[show_data]
        print("====== test_tiled_read: channel=%d, byte32=%d, keep_open=%d, extra_pages=%d,  show_data=%d"%
                                          (channel,      byte32,  keep_open,    extra_pages,     show_data))
        if   channel == 2:
            start_addr=             vrlg.MCNTRL_TILED_CHN2_ADDR;
            status_address=         vrlg.MCNTRL_TEST01_STATUS_REG_CHN2_ADDR;
            status_control_address= vrlg.MCNTRL_TEST01_ADDR + vrlg.MCNTRL_TEST01_CHN2_STATUS_CNTRL;
            test_mode_address=      vrlg.MCNTRL_TEST01_ADDR + vrlg.MCNTRL_TEST01_CHN2_MODE;
        elif channel == 4:
            start_addr=             vrlg.MCNTRL_TILED_CHN4_ADDR;
            status_address=         vrlg.MCNTRL_TEST01_STATUS_REG_CHN4_ADDR;
            status_control_address= vrlg.MCNTRL_TEST01_ADDR + vrlg.MCNTRL_TEST01_CHN4_STATUS_CNTRL;
            test_mode_address=      vrlg.MCNTRL_TEST01_ADDR + vrlg.MCNTRL_TEST01_CHN4_MODE;
        else:
            print("**** ERROR: Invalid channel, only 2 and 4 are valid");
            start_addr=             vrlg.MCNTRL_TILED_CHN2_ADDR;
            status_address=         vrlg.MCNTRL_TEST01_STATUS_REG_CHN2_ADDR;
            status_control_address= vrlg.MCNTRL_TEST01_ADDR + vrlg.MCNTRL_TEST01_CHN2_STATUS_CNTRL;
            test_mode_address=      vrlg.MCNTRL_TEST01_ADDR + vrlg.MCNTRL_TEST01_CHN2_MODE;

        '''
        mode=   self.func_encode_mode_tiled(
                                            byte32,
                                            keep_open,
                                            extra_pages,
                                            0, # write_mem,
                                            1, # enable
                                            0)  # chn_reset
        '''
        mode=   x393_mcntrl.func_encode_mode_scan_tiled(
                                   skip_too_late = False,                     
                                   disable_need = False,
                                   repetitive=    True,
                                   single =       False,
                                   reset_frame =  True, # False,
                                   byte32 =       byte32,
                                   keep_open =    keep_open,
                                   extra_pages =  extra_pages,
                                   write_mem =    False,
                                   enable =       True,
                                   chn_reset =    False,
                                   abort_late =   False)
            
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_TILED_MODE, 0); # reset channel, including page address
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_TILED_STARTADDR,
                                                  vrlg.FRAME_START_ADDRESS) # RA=80, CA=0, BA=0 22-bit frame start address (3 CA LSBs==0. BA==0) 
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_TILED_FRAME_FULL_WIDTH,
                                                  vrlg.FRAME_FULL_WIDTH)
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_TILED_WINDOW_WH,
                                                  concat(((window_height,16),
                                                          (window_width, 16)))[0]) # {window_height,window_width});
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_TILED_WINDOW_X0Y0,
                                                  concat(((window_top,  16),
                                                          (window_left, 16)))[0])  #  {window_top,window_left});
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_TILED_WINDOW_STARTXY,
                                                  concat(((vrlg.TILED_STARTY, 16),
                                                          (vrlg.TILED_STARTX, 16)))[0])  #  TILED_STARTX+(TILED_STARTY<<16));
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_TILED_TILE_WHS,
                                                  concat(((tile_vstep, 8),
                                                          (tile_height, 8),
                                                          (tile_width, 8)))[0]) # {8'b0,tile_vstep,tile_height,tile_width});#tile_width+(tile_height<<8)+(tile_vstep<<16));
        self.x393_axi_tasks.write_control_register(start_addr + vrlg.MCNTRL_TILED_MODE, mode);# set mode register: {extra_pages[1:0],enable,!reset}
        self.x393_axi_tasks.configure_channel_priority(channel,0)    # lowest priority channel 3
        self.x393_axi_tasks.enable_memcntrl_en_dis(channel,1);
        self.x393_axi_tasks.write_control_register(test_mode_address,            vrlg.TEST01_START_FRAME);
        for ii in range(tiles_per_row * tile_rows_per_window): # (ii=0;ii<(tiles_per_row * tile_rows_per_window);ii = ii+1) begin
            self.x393_axi_tasks.wait_status_condition (
                                                       status_address, # MCNTRL_TEST01_STATUS_REG_CHN4_ADDR,
                                                       status_control_address, # MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN4_STATUS_CNTRL,
                                                       vrlg.DEFAULT_STATUS_MODE,
                                                       ii << 16, # -TEST_INITIAL_BURST)<<16, # 4-bit page number
                                                       0xf<< 16, #'hf << 16,  # mask for the 4-bit page number
                                                       1, # not equal to
                                                       (0,1)[ii == 0]) # synchronize sequence number - only first time, next just wait fro auto update
            if (show_data): 
                print("########### test_tiled_read block %d: channel=%d"%(ii, channel))
                    
            result.append(self.x393_mcntrl_buffers.read_block_buf_chn (channel,
                                                                       (ii & 3),
                                                                       tile_size <<2,
#                                                                       1, # chn=0, page=3, number of 32-bit words=256, show_rslt
                                                                       show_data))
            self.x393_axi_tasks.write_control_register(test_mode_address, vrlg.TEST01_NEXT_PAGE);
#     enable_memcntrl_en_dis(channel,0); # disable channel
        return result    
