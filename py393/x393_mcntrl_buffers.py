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
#import sys
#import x393_mem
#x393_pio_sequences
#from import_verilog_parameters import VerilogParameters
from x393_mem import X393Mem
#from x393_axi_control_status import X393AxiControlStatus
import x393_axi_control_status
from verilog_utils import convert_w32_to_mem16 #,convert_mem16_to_w32

import vrlg 
class X393McntrlBuffers(object):
    DRY_MODE= True # True
    DEBUG_MODE=1
#    vpars=None
    x393_mem=None
    x393_axi_tasks=None #x393X393AxiControlStatus
    verbose=1
    def __init__(self, debug_mode=1,dry_mode=True):
        self.DEBUG_MODE=debug_mode
        self.DRY_MODE=dry_mode
        self.x393_mem=X393Mem(debug_mode,dry_mode)
#        self.x393_axi_tasks=X393AxiControlStatus(debug_mode,dry_mode)
        self.x393_axi_tasks=x393_axi_control_status.X393AxiControlStatus(debug_mode,dry_mode)
#        self.__dict__.update(VerilogParameters.__dict__["_VerilogParameters__shared_state"]) # Add verilog parameters to the class namespace
        try:
            self.verbose=vrlg.VERBOSE
        except:
            pass
    def write_block_scanline_chn(self,       #
                                 chn,        # input   [3:0] chn; // buffer channel
                                 page,       # input   [1:0] page;
                                 num_bursts, # input [NUM_XFER_BITS:0] num_bursts; // number of 8-bursts to write (will be rounded up to multiple of 16)
                                 startX,     # input integer startX;
                                 startY):    #input integer startY;
        """
        Fill buffer with the generated data in scanline mode
        <chn>        4-bit channel number (0,1,2,3,4 are valid) to use
        <page>       2-bit page number in the buffer to write to
        <num_bursts> number of 8-word (16 bytes) bursts to write
        <startX>     horizontal shift of the left of the data line to write, in bytes
        <startY>     line number to encode in the data
        """
        if self.DEBUG_MODE > 1:
            print("====== write_block_scanline_chn:%d page: %x X=0x%x Y=0x%x num=%dt"%(chn, page, startX, startY,num_bursts))
        if   chn == 0:  start_addr=vrlg.MCONTR_BUF0_WR_ADDR + (page << 8)
#        elif chn == 1:  start_addr=vrlg.MCONTR_BUF1_WR_ADDR + (page << 8)
        elif chn == 2:  start_addr=vrlg.MCONTR_BUF2_WR_ADDR + (page << 8)
        elif chn == 3:  start_addr=vrlg.MCONTR_BUF3_WR_ADDR + (page << 8)
        elif chn == 4:  start_addr=vrlg.MCONTR_BUF4_WR_ADDR + (page << 8)
        else:
            print("**** ERROR: Invalid channel for write_block_scanline_chn = %d"% chn)
            start_addr = vrlg.MCONTR_BUF0_WR_ADDR+ (page << 8);
        num_words=num_bursts << 2;
        self.write_block_incremtal (start_addr, num_words, (startX<<2) + (startY<<16));# 1 of startX is 8x16 bit, 16 bytes or 4 32-bit words

    def write_block_buf(self,
                              start_word_address, # input [29:0] start_word_address;
                              num_words_or_data_list):          # input integer num_words; # number of words to write (will be rounded up to multiple of 16)
        """
        Fill buffer the pattern data
        <start_word_address>     full register address in AXI space (in 32-bit words, not bytes)
        <num_words_or_data_list> number of 32-bit words to generate/write or a list with integer data
        """
        xor=0
        if (isinstance (num_words_or_data_list,list) or isinstance (num_words_or_data_list,tuple)) and (len(num_words_or_data_list) == 2):
            xor=num_words_or_data_list[1]
            num_words_or_data_list=num_words_or_data_list[0]
                    
        if isinstance (num_words_or_data_list,(int,)):
            data=[]
            for i in range(num_words_or_data_list):
                data.append(xor ^(i | (((i + 7) & 0xff) << 8)  | (((i + 23) & 0xff) << 16) | (((i + 31) & 0xff) << 24)))
        else:
            data=num_words_or_data_list
        if self.verbose>0:
            print("**** write_block_buf, start_word_address=0x%x, num+words=0x%x"%(start_word_address,len(data)))
        for i,d in enumerate(data):
#            d= i | (((i + 7) & 0xff) << 8)  | (((i + 23) & 0xff) << 16) | (((i + 31) & 0xff) << 24)
            if self.verbose>2:
                print("     write_block_buf 0x%x:0x%x"%(start_word_address+i,d))
            self.x393_mem.axi_write_single_w(start_word_address+i, d)

    def write_block_incremtal(self,
                              start_word_address, # input [29:0] start_word_address;
                              num_words,          # input integer num_words; # number of words to write (will be rounded up to multiple of 16)
                              start_value,       # input integer start_value;
                              quiet=1):      
        """
        Fill buffer the incremental data (each next register is written with previous register data + 1
        @param start_word_address  full register address in AXI space (in 32-bit words, not bytes)
        @param num_words           number of 32-bit words to generate/write
        @start_value         value to write to the first register (to start_word_address)
        """
        if quiet < 2:
            print("**** write_block_incremtal, start_word_address=0x%x, num_words=0x%x, start_value=0x%x "%(start_word_address,num_words,start_value))
        for i in range(0,num_words):
            if quiet < 1:
                print("     write_block_buf 0x%x:0x%x"%(start_word_address+i,start_value+i))
            self.x393_mem.axi_write_single_w(start_word_address+i, start_value+i)

    def write_block_buf_chn(self,       #
                            chn,        # input integer chn; # buffer channel
                            page,       # input   [1:0] page;
                            num_words_or_data_list, # input integer num_words; # number of words to write (will be rounded up to multiple of 16)
                            quiet = 1):
        """
        Fill specified buffer with the pattern data
        @param chn                    4-bit buffer channel (0..4) to write data to
        @param page                   2-bit buffer page to write to
        @param num_words_or_data_list> number of 32-bit words to generate/write or a list with integer data
        @param quiet                  reduce output
        """
        if quiet < 2:
            print("===write_block_buf_chn() chn=0x%x, page=0x%x"%(chn,page), end=" ")
            if isinstance (num_words_or_data_list,list):
                try:
                    print("=== [0x%x,0x%x,0x%x,0x%x,0x%x,0x%x,0x%x,0x%x,...]"%tuple(num_words_or_data_list[:8]),end="")
                except:
                    print("=== [%s]"%str(num_words_or_data_list))
            print("===")    
        start_addr=-1
        if   chn==0:start_addr=vrlg.MCONTR_BUF0_WR_ADDR + (page << 8)
#        elif chn==1:start_addr=vrlg.MCONTR_BUF1_WR_ADDR + (page << 8)
        elif chn==2:start_addr=vrlg.MCONTR_BUF2_WR_ADDR + (page << 8)
        elif chn==3:start_addr=vrlg.MCONTR_BUF3_WR_ADDR + (page << 8)
        elif chn==4:start_addr=vrlg.MCONTR_BUF4_WR_ADDR + (page << 8)
        else:
            print("**** ERROR: Invalid channel for write buffer = %d"% chn)
            start_addr = vrlg.MCONTR_BUF0_WR_ADDR+ (page << 8)
            
        self.write_block_buf (start_addr, num_words_or_data_list)
    
    def read_block_buf(self, 
                       start_word_address, # input [29:0] start_word_address;
                       num_read,           # input integer num_read; # number of words to read (will be rounded up to multiple of 16)
                       show_rslt=True):
        """
        Fill buffer the incremental data (each next register is written with previous register data + 1
        @param start_word_address full register address in AXI space (in 32-bit words, not bytes)
        @param num_read           number of 32-bit words to read
        @param show_rslt          print buffer data read 1 - column, 16 - as 16-bit (memory words), 32 - as 32-bit (data words)
        """
        
        if (self.verbose>1) or (show_rslt==1):
            print("**** read_block_buf, start_word_address=0x%x, num_read=0x%x "%(start_word_address,num_read))
        result=[]    
        for i in range(num_read): #for (i = 0; i < num_read; i = i + 16) begin
            d=self.x393_mem.axi_read_addr_w(start_word_address+i)
            if (self.verbose>2) or (show_rslt==1):
                print("     read_block_buf 0x%x:0x%x"%(start_word_address+i,d))
            result.append(d)
        if show_rslt==16:
            rslt16=convert_w32_to_mem16(result)
            sum_read16=0
            for d in rslt16:
                sum_read16+=d
            print("read16 (0x%x):"%(sum_read16),end="")
            for i in range(len(rslt16)):
                if (i & 0x1f) == 0:
                    print("\n%03x:"%i,end=" ")
                print("%04x"%rslt16[i],end=" ")
            print("\n")
        elif show_rslt==32:
            sum_rd_buf=0
            for d in result:
                sum_rd_buf+=d
            print("read buffer: (0x%x):"%(sum_rd_buf),end="")
            for i in range(len(result)):
                if (i & 0xf) == 0:
                    print("\n%03x:"%i,end=" ")
                print("%08x"%result[i],end=" ")
            print("\n")        

        return result

    def read_block_buf_chn(self,  # S uppressThisWarning VEditor : may be unused
                           chn, # input [3:0] chn; # buffer channel
                           page, #input   [1:0] page;
                           num_read, #input integer num_read; # number of words to read (will be rounded up to multiple of 16)
                           show_rslt=True):
        """
        Fill buffer the incremental data (each next register is written with previous register data + 1
        @param chn                4-bit buffer channel (0..4) to read from
        @param page               2-bit buffer page to read from
        @param num_read           number of 32-bit words to read
        @param show_rslt          print buffer data read 1 - column, 16 - as 16-bit (memory words), 32 - as 32-bit (data words)
        """
        start_addr=-1
        if   chn==0:  start_addr=vrlg.MCONTR_BUF0_RD_ADDR + (page << 8)
        elif chn==2:  start_addr=vrlg.MCONTR_BUF2_RD_ADDR + (page << 8)
        elif chn==3:  start_addr=vrlg.MCONTR_BUF3_RD_ADDR + (page << 8)
        elif chn==4:  start_addr=vrlg.MCONTR_BUF4_RD_ADDR + (page << 8)
        else:
            print("**** ERROR: Invalid channel for read buffer = %d"%chn)
            start_addr = vrlg.MCONTR_BUF0_RD_ADDR+ (page << 8)
        result=self.read_block_buf (start_addr, num_read, show_rslt)
        return result
