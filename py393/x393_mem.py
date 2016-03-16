from __future__ import print_function
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
import mmap
#import sys
import struct
import os
class X393Mem(object):
    '''
    classdocs
    '''
    DRY_MODE= True # True
    PAGE_SIZE=4096
    DEBUG_MODE=1
    ENDIAN="<" # little, ">" for big
    MAXI0_BASE=0x40000000
    MAXI1_BASE=0x80000000
    MAXI_BASE = MAXI0_BASE
    USE_NEGATIVE = True # Old versions of Python (2.7.3) required mmap offset to fit into 32 bits, so upper half had to be negative
                        # 2.7.11 does not need subtraction(and reports error if negative)

    def __init__(self, debug_mode=1,dry_mode=False, maxi_port=0):
        if maxi_port:
            self.MAXI_BASE=self.MAXI1_BASE
        else:    
            self.MAXI_BASE=self.MAXI0_BASE;
        self.DEBUG_MODE=debug_mode
        if not dry_mode:
            if not os.path.exists("/dev/xdevcfg"):
                dry_mode=True
                print("Program is forced to run in SIMULATED mode as '/dev/xdevcfg' does not exist (not a camera)")
        self.DRY_MODE=dry_mode
    def maxi_base(self, maxi_port=None):
        if not maxi_port is None:
            if maxi_port:
                self.MAXI_BASE=self.MAXI1_BASE
            else:    
                self.MAXI_BASE=self.MAXI0_BASE;
        else:
            maxi_port = (0,1)[self.MAXI_BASE == self.MAXI1_BASE]
        print ("MAXI port = %d (0x%08x)"%(maxi_port, self.MAXI_BASE))       

    def wrap_mm (self, f, page_addr):
        if page_addr>=0x80000000:
            if (self.USE_NEGATIVE):
                try:
                    return mmap.mmap(f.fileno(), self.PAGE_SIZE, offset = page_addr - (1<<32))
                except:
                    self.USE_NEGATIVE = False
                    if self.DEBUG_MODE:
                        print ("Turning OFF use of negative offsets in mmap")
                    return mmap.mmap(f.fileno(), self.PAGE_SIZE, offset = page_addr)
            else:
                try:
                    return mmap.mmap(f.fileno(), self.PAGE_SIZE, offset = page_addr)
                except:
                    print ("Turning ON use of negative offsets in mmap")
                    self.USE_NEGATIVE = True
                    return mmap.mmap(f.fileno(), self.PAGE_SIZE, offset = page_addr - (1<<32))
        else:
             return mmap.mmap(f.fileno(), self.PAGE_SIZE, offset = page_addr)
         
                        
    def write_mem (self,addr, data,quiet=1):
        """
        Write 32-bit word to physical memory
        @param addr - physical byte address
        @param data - 32-bit data to write
        @param quiet - reduce output
        """
        if self.DRY_MODE:
            print ("simulated: write_mem(0x%x,0x%x)"%(addr,data))
            return
        with open("/dev/mem", "r+b") as f:
            page_addr=addr & (~(self.PAGE_SIZE-1))
            page_offs=addr-page_addr
            mm = self.wrap_mm(f, page_addr)
#            if (page_addr>=0x80000000):
#                page_addr-= (1<<32)
#            mm = mmap.mmap(f.fileno(), self.PAGE_SIZE, offset=page_addr)
            packedData=struct.pack(self.ENDIAN+"L",data)
            d=struct.unpack(self.ENDIAN+"L",packedData)[0]
            mm[page_offs:page_offs+4]=packedData
            if quiet <1:
                print ("0x%08x <== 0x%08x (%d)"%(addr,d,d))
        '''    
        if MONITOR_EMIO and VEBOSE:
            gpio0=read_mem (0xe000a068)
            gpio1=read_mem (0xe000a06c)
            print("GPIO: %04x %04x %04x %04x"%(gpio1>>16, gpio1 & 0xffff, gpio0>>16, gpio0 & 0xffff))
            if ((gpio0 & 0xc) != 0xc) or ((gpio0 & 0xff00) != 0):
                print("******** AXI STUCK ************")
                exit (0)
        '''    

    def read_mem (self,addr,quiet=1):
        '''
        Read 32-bit word from physical memory
        @param addr  physical byte address
        @param quiet - reduce output
        '''    
        if self.DRY_MODE:
            print ("simulated: read_mem(0x%x)"%(addr))
            return addr # just some data
        with open("/dev/mem", "r+b") as f:
            page_addr=addr & (~(self.PAGE_SIZE-1))
            page_offs=addr-page_addr
            mm = self.wrap_mm(f, page_addr)
#            if (page_addr>=0x80000000):
#                page_addr-= (1<<32)
#            mm = mmap.mmap(f.fileno(), self.PAGE_SIZE, offset=page_addr)
            data=struct.unpack(self.ENDIAN+"L",mm[page_offs:page_offs+4])
            d=data[0]
            if quiet < 1:
                print ("0x%08x ==> 0x%08x (%d)"%(addr,d,d))
            return d

    def mem_dump (self, start_addr, end_addr=1, byte_mode=4):
        '''
         Read and print memory range from physical memory
         @param start_addr physical byte start address
         @param end_addr  physical byte end address (inclusive), if negative/less than start_addr - number of items
         @param byte_mode number of bytes per item (1,2,4,8)
         @return list of read values
        '''
        frmt_bytes={1:'B',2:'H',4:'L',8:'Q'}
        bytes_per_line_mask={1:0x1f,2:0x1f,4:0x3f,8:0x3f}
        default_byte_mode=4
        if not byte_mode in frmt_bytes.keys():
            print ("Invalid byte mode: '%s'. Only %s are supported. Using %d"%(str(byte_mode),str(frmt_bytes.keys()),default_byte_mode))
            byte_mode=default_byte_mode
        data_frmt=  "%%0%dx"%(2*byte_mode)
        simul_mask= (1 << (8*byte_mode)) -1
        addr_mask=0xffffffff ^ (byte_mode-1)
        start_addr &= addr_mask
        if end_addr < start_addr:
            end_addr=start_addr + abs(end_addr*byte_mode) -1
        end_addr  &= addr_mask
#       align start address to 32-bit word even if the mode is byte/short        
        start_addr &= 0xfffffffc
        print_mask=bytes_per_line_mask[byte_mode]
        rslt=[]
        if self.DRY_MODE:
            rslt=[d & simul_mask for d in range(start_addr,end_addr+byte_mode,byte_mode)]
        else:
            with open("/dev/mem", "r+b") as f:
                for addr in range (start_addr,end_addr+byte_mode,byte_mode):
                    page_addr=addr & (~(self.PAGE_SIZE-1))
                    page_offs=addr-page_addr
                    mm = self.wrap_mm(f, page_addr)
        #            if (page_addr>=0x80000000):
        #                page_addr-= (1<<32)
        #            mm = mmap.mmap(f.fileno(), self.PAGE_SIZE, offset=page_addr)
                    data=struct.unpack_from(self.ENDIAN+frmt_bytes[byte_mode],mm, page_offs)
                    rslt.append(data[0])
                    
        for addr in range (start_addr,end_addr+byte_mode,byte_mode):
            if (addr == start_addr) or ((addr & print_mask) == 0):
                if self.DRY_MODE:
                    print ("\nsimulated: 0x%08x:"%addr,end="")
                else:     
                    print ("\n0x%08x:"%addr,end="")
            d=rslt[(addr-start_addr) // byte_mode]
            print (data_frmt%(d),end=" ")
        print("")
        return rslt    

    def mem_save (self, filename, start_addr, length):
        '''
         Save physical memory content to a file
         @param filename - path to a file
         @param start_addr physical byte start address
         @param length - number of bytes to save
        '''
        if self.DRY_MODE:
            print ("Write memory to file is not implemented in non-target mode")
            return
        with open(filename, "w+b") as bf:
            self._mem_write_to_file (bf =         bf,
                                     start_addr = start_addr,
                                     length =     length)

    def _mem_write_to_file (self, bf, start_addr, length):
        '''
         Save physical memory content to a file
         @param bf - file open in write mode
         @param start_addr physical byte start address
         @param length - number of bytes to save
        '''
        if self.DRY_MODE:
            print ("Write memory to file is not implemented in non-target mode")
            return
        with open("/dev/mem", "r+b") as f:
            first_page = start_addr // self.PAGE_SIZE
            last_page = (start_addr + length - 1) // self.PAGE_SIZE
            for page_num in range(first_page, last_page+1):
                start_offset = 0
                if page_num == first_page:
                    start_offset = start_addr - self.PAGE_SIZE * page_num
                end_offset =  self.PAGE_SIZE
                if page_num == last_page:
                    end_offset = start_addr + length - self.PAGE_SIZE * page_num
                page_addr = page_num * self.PAGE_SIZE 
                mm = self.wrap_mm(f, page_addr)
    #            if (page_addr>=0x80000000):
    #                page_addr-= (1<<32)
    #            mm = mmap.mmap(f.fileno(), self.PAGE_SIZE, offset=page_addr)
                bf.write(mm[start_offset:end_offset])

    def mem_clear (self, start_addr, length, word32):
        '''
         Fill physical memory range with a repetitive 32-bit word
         @param start_addr physical byte start address
         @param length - number of bytes to save
         @param word32 - 32-bit pattern
        '''
        if self.DRY_MODE:
            print ("Write memory to file is not implemented in non-target mode")
            return
        patt=str(bytearray(((word32 & 0xff), ((word32 >> 8) & 0xff), ((word32 >> 16) & 0xff), ((word32 >> 24) & 0xff)))*(self.PAGE_SIZE/4))
        with open("/dev/mem", "r+b") as f:
            first_page = start_addr // self.PAGE_SIZE
            last_page = (start_addr + length - 1) // self.PAGE_SIZE
            for page_num in range(first_page, last_page+1):
                start_offset = 0
                if page_num == first_page:
                    start_offset = start_addr - self.PAGE_SIZE * page_num
                end_offset =  self.PAGE_SIZE
                if page_num == last_page:
                    end_offset = start_addr + length - self.PAGE_SIZE * page_num
                page_addr = page_num * self.PAGE_SIZE 
                mm = self.wrap_mm(f, page_addr)
    #            if (page_addr>=0x80000000):
    #                page_addr-= (1<<32)
    #            mm = mmap.mmap(f.fileno(), self.PAGE_SIZE, offset=page_addr)
                mm[start_offset:end_offset] = patt[start_offset:end_offset]


    def mem_fill (self, start_addr, start_data=0, end_addr=1, inc_data=0, byte_mode=4):
        '''
         Read and print memory range from physical memory
         @param start_addr physical byte start address
         @param start_data data/start data to write
         @param end_addr  physical byte end address (inclusive), if negative/less than start_addr - number of items
         @param inc_data increment each next item by this value
         @param byte_mode number of bytes per item (1,2,4,8)
        '''
        frmt_bytes={1:'B',2:'H',4:'L',8:'Q'}
        default_byte_mode=4
        if not byte_mode in frmt_bytes.keys():
            print ("Invalid byte mode: '%s'. Only %s are supported. Using %d"%(str(byte_mode),str(frmt_bytes.keys()),default_byte_mode))
            byte_mode=default_byte_mode
        data_mask= (1 << (8*byte_mode)) -1
        addr_mask=0xffffffff ^ (byte_mode-1)
        start_addr &= addr_mask
        if end_addr < start_addr:
            end_addr=start_addr + abs(end_addr*byte_mode) -1
        end_addr  &= addr_mask
#       align start address to 32-bit word even if the mode is byte/short        
        start_addr &= 0xfffffffc
        if self.DRY_MODE:
            print ("Simulated mem_fill(0x%x, 0x%x, 0x%x, 0x%x, %d)"%(start_addr, start_data, end_addr, inc_data, byte_mode))
            data_frmt=  "%%0%dx"%(2*byte_mode)
            for addr in range (start_addr,end_addr+byte_mode,byte_mode):
                data = (start_data + ((addr-start_addr) // byte_mode)*inc_data) & data_mask
                page_addr=addr & (~(self.PAGE_SIZE-1))
                page_offs=addr-page_addr
                if (page_addr>=0x80000000):
                    page_addr-= (1<<32)
                print (("0x%08x: "+ data_frmt)%(addr,data))
        else:
            with open("/dev/mem", "r+b") as f:
                for addr in range (start_addr,end_addr+byte_mode,byte_mode):
                    data = (start_data + ((addr-start_addr) // byte_mode)*inc_data) & data_mask
                    page_addr=addr & (~(self.PAGE_SIZE-1))
                    page_offs=addr-page_addr
                    mm = self.wrap_mm(f, page_addr)
        #            if (page_addr>=0x80000000):
        #                page_addr-= (1<<32)
        #            mm = mmap.mmap(f.fileno(), self.PAGE_SIZE, offset=page_addr)
                    struct.pack_into(self.ENDIAN+frmt_bytes[byte_mode],mm, page_offs, data)
    
    '''
    Read/write slave AXI using byte addresses relative to the AXI memory region
    '''
    def axi_write_single(self,addr,data):
        """
        Write 32-bit word to the slave AXI address range
        <addr> - physical byte address relative to the slave AXI memory region
        <data> - 32-bit data to write
        """
        self.write_mem(self.MAXI_BASE+addr,data)

    def axi_read_addr(self,addr):
        """
        Read 32-bit word from the  slave AXI address range
        <addr> - physical byte address relative to slave AXI AXI memory region
        """
        return self.read_mem(self.MAXI_BASE+addr)
    '''
    Read/write slave AXI using 32-bit word addresses (same as in Verilog code)
    '''
    def axi_write_single_w(self,addr,data,verbose=0):
        """
        Write 32-bit word to the slave AXI address range, using 32-word address
        <addr> - 32-bit word (register) address relative to the slave AXI memory region
        <data> - 32-bit data to write
        <verbose> print data being written (default: 0)
        """
        if verbose or self.DEBUG_MODE:
            print("axi_write_single_w(0x%x,0x%08x)"%(addr,data))
        self.axi_write_single(addr<<2,data)

    def axi_read_addr_w(self,addr):
        """
        Read 32-bit word from the slave AXI address range, using 32-word address
        <addr> - 32-bit word (register) address relative to the slave AXI memory region
        """
        return self.axi_read_addr(addr<<2)
