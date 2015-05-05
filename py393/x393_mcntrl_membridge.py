from __future__ import print_function
'''
# Copyright (C) 2015, Elphel.inc.
# Class to measure and adjust I/O delays  
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
Created on May 2, 2015

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
import vrlg
#import x393_utils
import x393_mem
import x393_axi_control_status
import x393_pio_sequences
import x393_mcntrl_timing
import x393_mcntrl_buffers 
import verilog_utils 

MEM_PATH='/sys/devices/elphel393-mem.2/'
BUFFER_ASSRESS_NAME='buffer_address'
BUFFER_PAGES_NAME='buffer_pages'
BUFFER_ADDRESS=None
BUFFER_LEN=None

#BUFFER_ADDRESS=0x27900000
#BUFFER_LEN=    0x6400000

PAGE_SIZE=4096
AFI_BASE_ADDR= 0xf8008000

'''
root@elphel393:/sys/devices/elphel393-mem.2# cat buffer_address 
0x27900000
root@elphel393:/sys/devices/elphel393-mem.2# cat buffer_pages
25600
BUFFER_ADDRESS= 663748608
BUFFER_LEN= 104857600
BUFFER_ADDRESS=0x27900000
BUFFER_LEN=0x6400000

'''
def func_encode_mode_scanline(extra_pages,  # input [1:0] extra_pages; # number of extra pages that need to stay (not to be overwritten) in the buffer
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
    return verilog_utils.concat (((extra_pages,     2), # extra_pages,
                                 ((0,1)[write_mem],1), # write_mem,
                                 ((0,1)[enable],   1), #enable,
                                 ((1,0)[chn_reset],1)))[0] # ~chn_reset};

class X393McntrlMembridge(object):
    DRY_MODE= True # True
    DEBUG_MODE=1
    x393_mem=None
    x393_axi_tasks=None #x393X393AxiControlStatus
    x393_pio_sequences=None
    x393_mcntrl_timing=None
    x393_mcntrl_buffers=None
    x393_utils=None
    verbose=1
    adjustment_state={}
    def __init__(self, debug_mode=1,dry_mode=True): #, saveFileName=None):
        global BUFFER_ADDRESS, BUFFER_LEN
        self.DEBUG_MODE=  debug_mode
        self.DRY_MODE=    dry_mode
        self.x393_mem=            x393_mem.X393Mem(debug_mode,dry_mode)
        self.x393_axi_tasks=      x393_axi_control_status.X393AxiControlStatus(debug_mode,dry_mode)
        self.x393_pio_sequences=  x393_pio_sequences.X393PIOSequences(debug_mode,dry_mode)
        self.x393_mcntrl_timing=  x393_mcntrl_timing.X393McntrlTiming(debug_mode,dry_mode)
        self.x393_mcntrl_buffers= x393_mcntrl_buffers.X393McntrlBuffers(debug_mode,dry_mode)
        
#        self.x393_utils=          x393_utils.X393Utils(debug_mode,dry_mode, saveFileName) # should not overwrite save file path
        try:
            self.verbose=vrlg.VERBOSE
        except:
            pass
        if dry_mode:
            BUFFER_ADDRESS=0x27900000
            BUFFER_LEN=    0x6400000
            print ("Running in simulated mode, using hard-coded addresses:")
        else:
            try:
                with open(MEM_PATH+BUFFER_ASSRESS_NAME) as sysfile:
                    BUFFER_ADDRESS=int(sysfile.read(),0)
                with open(MEM_PATH+BUFFER_PAGES_NAME) as sysfile:
                    BUFFER_LEN=PAGE_SIZE*int(sysfile.read(),0)
            except:
                print("Failed to get resderved physical memory range")
                print('BUFFER_ADDRESS=',BUFFER_ADDRESS)    
                print('BUFFER_LEN=',BUFFER_LEN)    
                return
        print('BUFFER_ADDRESS=0x%x'%(BUFFER_ADDRESS))    
        print('BUFFER_LEN=0x%x'%(BUFFER_LEN))
        
    def afi_write_reg(self,
                     port_num, # input   [1:0] port_num;
                     rel_baddr, # input integer rel_baddr; # relative byte address
                     data, # input  [31:0] data
                     quiet=1): #input  verbose;
        '''
        Write data to AXI_HP (AFI) register
        @param port - AXI_HP port number (0..3)
        @param rel_baddr relative register byte address (0, 4, 8, 0xc, ...)
        @param data data to write to the AFI_nn register
        @param quiet - reduce output (>=1 - silent)
        '''
        self.x393_mem.write_mem(AFI_BASE_ADDR+ (port_num << 12) + (rel_baddr & 0xfffffffc),
                                data & 0xffffffff,
                                quiet)
    def afi_read_reg(self,
                     port_num,       # input   [1:0] port_num;
                     rel_baddr=None, # input integer rel_baddr; # relative byte address
                     quiet=1):       #input  verbose;
        '''
        Read data from the AXI_HP (AFI) register
        @param port - AXI_HP port number (0..3)
        @param rel_baddr relative register byte address (0, 4, 8, 0xc, ...)
        @param quiet - reduce output (>=1 - silent)
        @return register data
        '''
        
        if rel_baddr is None:
            rslt=[]
            for baddr in (0,4,8,0xc,0x10,0x14,0x18,0x1c,0x20,0x24):
                rslt.append(self.afi_read_reg(port_num,baddr,quiet-1))
            return rslt    
                
        return self.x393_mem.read_mem(AFI_BASE_ADDR+ (port_num << 12) + (rel_baddr & 0xfffffffc),
                                quiet)

    def afi_setup (self,
                   port_num,
                   quiet=1):
        '''
        Write defualt parameters to AFI port registers
        @param port_num - AXI_HP port number (0..3)
        @param quiet - reduce output (>=1 - silent)
        '''
        self.afi_write_reg(port_num, 0x0,      0) # AFI_RDCHAN_CTRL
        self.afi_write_reg(port_num, 0x04,   0x7) # AFI_RDCHAN_ISSUINGCAP
        self.afi_write_reg(port_num, 0x08,     0) # AFI_RDQOS
        #self.afi_write_reg(port_num,0x0c,     0) # AFI_RDDATAFIFO_LEVEL
        #self.afi_write_reg(port_num,0x10,     0) # AFI_RDDEBUG
        self.afi_write_reg(port_num, 0x14, 0xf00) # AFI_WRCHAN_CTRL
        self.afi_write_reg(port_num, 0x18,   0x7) # AFI_WRCHAN_ISSUINGCAP
        self.afi_write_reg(port_num, 0x1c,     0) # AFI_WRQOS
        #self.afi_write_reg(port_num,0x20,     0) # AFI_WRDATAFIFO_LEVEL
        #self.afi_write_reg(port_num,0x24,     0) # AFI_WRDEBUG

    def membridge_setup (self,
                         len64,                         # input [28:0] len64;    # number of 64-bit words to transfer
                         width64,                       # input [28:0] width64;  # frame width in 64-bit words
                         start64,                       # input [28:0] start64;  # relative start adderss of the transfer (set to 0 when writing lo_addr64)
                         lo_addr64 =       None,        # input [28:0] lo_addr64; # low address of the system memory range, in 64-bit words 
                         size64 =          None,        # input [28:0] size64;    # size of the system memory range in 64-bit words
                         quiet=1):
        '''
        Set up membridge parameters for data transfer
        @param len64   number of 64-bit words to transfer
        @param width64 frame width in 64-bit words
        @param start64 relative start address of the transfer (normally 0)
        @param lo_addr64 low address of the system memory range, in 64-bit words 
        @param size64  size of the system memory range in 64-bit words
        @quiet - reduce output (>=1 - silent)
        '''
        if lo_addr64 is None:
            lo_addr64 =         BUFFER_ADDRESS//8        # input [28:0] lo_addr64;        # low address of the system memory range, in 64-bit words 
        if size64 is None:
            size64 =            BUFFER_LEN//8            # input [28:0] size64;           # size of the system memory range in 64-bit words
        
        if quiet <2:
            print("membridge_setup(0x%08x,0x%0xx,0x%08x,0x%0xx,0x%08x,%d)"%(len64, width64, start64, lo_addr64, size64, quiet))
        self.x393_axi_tasks.write_contol_register(vrlg.MEMBRIDGE_ADDR + vrlg.MEMBRIDGE_LO_ADDR64,  lo_addr64);    
        self.x393_axi_tasks.write_contol_register(vrlg.MEMBRIDGE_ADDR + vrlg.MEMBRIDGE_SIZE64,     size64);    
        self.x393_axi_tasks.write_contol_register(vrlg.MEMBRIDGE_ADDR + vrlg.MEMBRIDGE_START64,    start64);    
        self.x393_axi_tasks.write_contol_register(vrlg.MEMBRIDGE_ADDR + vrlg.MEMBRIDGE_LEN64,      len64);    
        self.x393_axi_tasks.write_contol_register(vrlg.MEMBRIDGE_ADDR + vrlg.MEMBRIDGE_WIDTH64,    width64);    

    def membridge_start(self,
                        cont=False,
                        quiet=1):
        '''
        Set up membridge parameters for data transfer
        @param cont - continue with the current system memory pointer, False - start with lo_addr64+start64
        @quiet reduce output (>=1 - silent)
        '''
        self.x393_axi_tasks.write_contol_register(vrlg.MEMBRIDGE_ADDR + vrlg.MEMBRIDGE_CTRL,  (0x3,0x7)[cont]);    
#        write_contol_register(MEMBRIDGE_ADDR + MEMBRIDGE_CTRL,         {29'b0,continue,2'b11});    

    def membridge_en(self,
                     en=True,
                     quiet=1):
        '''
        Enable/disable AXI transfers, when it is running. When stopped - reset "Done"
        @param en True - enable, False - disable AXI transfers (reset "Done" if AFI is idle
        @quiet reduce output (>=1 - silent)
        '''
        self.x393_axi_tasks.write_contol_register(vrlg.MEMBRIDGE_ADDR + vrlg.MEMBRIDGE_CTRL,  (0,1)[en]);    
#       write_contol_register(MEMBRIDGE_ADDR + MEMBRIDGE_CTRL,         {31'b0,en});

    def membridge_rw (self,
                      write_ddr3,                                   # input        write_ddr3;
#                      extra_pages,                                 # input  [1:0] extra_pages;
                      frame_start_addr =  None,                     # input [21:0] frame_start_addr;
                      window_full_width = None,                     # input [15:0] window_full_width;# 13 bit - in 8*16=128 bit bursts
                      window_width =      None,                     # input [15:0] window_width;     # 13 bit - in 8*16=128 bit bursts
                      window_height =     None,                     # input [15:0] window_height;    # 16 bit (only 14 are used here)
                      window_left =       None,                     # input [15:0] window_left;
                      window_top =        None,                     # input [15:0] window_top;
                      start64 =           0,                        # input [28:0] start64;          # relative start address of the transfer (set to 0 when writing lo_addr64)
                      lo_addr64 =         None,                     # input [28:0] lo_addr64;        # low address of the system memory range, in 64-bit words 
                      size64 =            None,                     # input [28:0] size64;           # size of the system memory range in 64-bit words
                      cont =              False,                    # input        continue;         # 0 start from start64, 1 - continue from where it was
                      wait_ready =        False,
                      quiet=1):
        '''
        Set up and run data transfer between the system and videobuffer memory
        @param write_ddr3 True: from system memory to ddr3, False - from ddr3 to system memory
        @param frame_start_addr [21:0] Frame start address in video buffer  RA=80, CA=0, BA=0 22-bit frame start address (3 CA LSBs==0. BA==0)
        @param window_full_width  padded frame width in 8-word (16 byte) bursts - increment to the next line (after bank), currently 13 bits
        @param window_width window width in 16-byte bursts to be transferred, currently 13 bits (0 - maximal width 0f 2<<13)
        @param window_height window height to be transferred, 14 bits
        @param window_left window to be transferred left margin (relative to frame) in 16-byte bursts (13 bits)
        @param window_top window to be transferred top margin (relative to frame) 16-bit
        @param start64 start of transfer address in system memory, relative to the start of region (in 8-bytes)
        @param lo_addr64 start of the system memory buffer, in 8-bytes (byte_address >>3), 29 bits 
        @param size64 size of the transfer buffer in the system memory, in 8-bytes. Transfers will roll over to lo_addr64. 29 bits.
        @param cont True: continue from  the same address in the system memory, where the previous transfer stopped. False - start from lo_addr64+start64
        @param wait_ready poll status to see if the command finished
        @param quiet Reduce output
        '''
        if frame_start_addr is None:
            frame_start_addr =  vrlg.FRAME_START_ADDRESS # input [21:0] frame_start_addr;
        if window_full_width is None:
            window_full_width = vrlg.FRAME_FULL_WIDTH    # input [15:0] window_full_width;# 13 bit - in 8*16=128 bit bursts
        if window_width is None:
            window_width =      vrlg.WINDOW_WIDTH        # input [15:0] window_width;     # 13 bit - in 8*16=128 bit bursts
        if window_height is None:
            window_height =     vrlg.WINDOW_HEIGHT       # input [15:0] window_height;    # 16 bit (only 14 are used here)
        if window_left is None:
            window_left =       vrlg.WINDOW_X0           # input [15:0] window_left;
        if window_top is None:
            window_top =        vrlg.WINDOW_Y0           # input [15:0] window_top;
        if lo_addr64 is None:
            lo_addr64 =         BUFFER_ADDRESS//8        # input [28:0] lo_addr64;        # low address of the system memory range, in 64-bit words 
        if size64 is None:
            size64 =            BUFFER_LEN//8            # input [28:0] size64;           # size of the system memory range in 64-bit words
        
        window_height &= 0x3fff
        if window_height == 0:
            window_height = 0x4000
        window_width &= 0x1fff
        if window_width == 0:
            window_width = 0x2000
            
        if quiet <2:
            print("====== test_afi_rw: write=%s, frame_start=0x%x, window_full_width=%d, window_width=%d, window_height=%d, window_left=%d, window_top=%d"%(
                                      str(write_ddr3),  frame_start_addr, window_full_width,   window_width, window_height, window_left, window_top));
            print("len64=0x%x,  width64=0x%x, start64=0x%x, lo_addr64=0x%x, size64=0x%x"%(
                  (window_width << 1)*window_height,
                  (window_width << 1),
                  start64, lo_addr64, size64))
        mode=   func_encode_mode_scanline(
                    0, # extra_pages,
                    write_ddr3, # write_mem,
                    1, # enable
                    0)  # chn_reset
#        self.x393_axi_tasks.write_contol_register(vrlg.MEMBRIDGE_ADDR + vrlg.MEMBRIDGE_WIDTH64,    width64);    
#        self.x393_axi_tasks.write_contol_register(vrlg.MCNTRL_SCANLINE_CHN1_ADDR + vrlg.MCNTRL_SCANLINE_MODE,             0); # reset channel, including page address
        self.x393_axi_tasks.write_contol_register(vrlg.MCNTRL_SCANLINE_CHN1_ADDR + vrlg.MCNTRL_SCANLINE_STARTADDR,        frame_start_addr) # RA=80, CA=0, BA=0 22-bit frame start address (3 CA LSBs==0. BA==0) 
        self.x393_axi_tasks.write_contol_register(vrlg.MCNTRL_SCANLINE_CHN1_ADDR + vrlg.MCNTRL_SCANLINE_FRAME_FULL_WIDTH, window_full_width);
        self.x393_axi_tasks.write_contol_register(vrlg.MCNTRL_SCANLINE_CHN1_ADDR + vrlg.MCNTRL_SCANLINE_WINDOW_WH,        (window_height << 16) | window_width) # WINDOW_WIDTH + (WINDOW_HEIGHT<<16));
        self.x393_axi_tasks.write_contol_register(vrlg.MCNTRL_SCANLINE_CHN1_ADDR + vrlg.MCNTRL_SCANLINE_WINDOW_X0Y0,      (window_top << 16) | window_left)     # WINDOW_X0+ (WINDOW_Y0<<16));
        self.x393_axi_tasks.write_contol_register(vrlg.MCNTRL_SCANLINE_CHN1_ADDR + vrlg.MCNTRL_SCANLINE_WINDOW_STARTXY,   0)
        self.x393_axi_tasks.write_contol_register(vrlg.MCNTRL_SCANLINE_CHN1_ADDR + vrlg.MCNTRL_SCANLINE_MODE,             mode) 
        self.x393_axi_tasks.configure_channel_priority(1,0);    # lowest priority channel 1
        self.x393_axi_tasks.enable_memcntrl_en_dis(1,1);
#        write_contol_register(test_mode_address,            TEST01_START_FRAME);
        self.afi_setup(0)
        self.membridge_setup(
            (window_width << 1)*window_height, # ((window_width[12:0]==0)? 15'h4000 : {1'b0,window_width[12:0],1'b0})*window_height[13:0], #len64,
            (window_width << 1),               # (window_width[12:0]==0)? 29'h4000 : {15'b0,window_width[12:0],1'b0}, # width64,
            start64,
            lo_addr64,
            size64)
        self.membridge_start (cont)         
# just wait done (default timeout = 10 sec)
        if wait_ready:
            self.x393_axi_tasks.wait_status_condition ( # may also be read directly from the same bit of mctrl_linear_rw (address=5) status
                vrlg.MEMBRIDGE_STATUS_REG, # MCNTRL_TEST01_STATUS_REG_CHN3_ADDR,
                vrlg.MEMBRIDGE_ADDR +vrlg.MEMBRIDGE_STATUS_CNTRL, # MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN3_STATUS_CNTRL,
                vrlg.DEFAULT_STATUS_MODE,
                2 << vrlg.STATUS_2LSB_SHFT, # bit 24 - busy, bit 25 - frame done
                2 << vrlg.STATUS_2LSB_SHFT,  # mask for the 4-bit page number
                0, # equal to
                1); # synchronize sequence number

