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

class X393Mem(object):
    '''
    classdocs
    '''
    DRY_MODE= True # True
    PAGE_SIZE=4096
    DEBUG_MODE=1
    ENDIAN="<" # little, ">" for big
    AXI_SLAVE0_BASE=0x40000000

    def __init__(self, debug_mode=1,dry_mode=True):
        self.DEBUG_MODE=debug_mode
        self.DRY_MODE=dry_mode
    def write_mem (self,addr, data):
        """
        Write 32-bit word to physical memory
        <addr> - physical byte address
        <data> - 32-bit data to write
        """
        if self.DRY_MODE:
            print ("simulated: write_mem(0x%x,0x%x)"%(addr,data))
            return
        with open("/dev/mem", "r+b") as f:
            page_addr=addr & (~(self.PAGE_SIZE-1))
            page_offs=addr-page_addr
            if (page_addr>=0x80000000):
                page_addr-= (1<<32)
            mm = mmap.mmap(f.fileno(), self.PAGE_SIZE, offset=page_addr)
            packedData=struct.pack(self.ENDIAN+"L",data)
            d=struct.unpack(self.ENDIAN+"L",packedData)[0]
            mm[page_offs:page_offs+4]=packedData
            if self.DEBUG_MODE > 2:
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

    def read_mem (self,addr):
        '''
         Read 32-bit word from physical memory
         <addr> - physical byte address
        '''    
        if self.DRY_MODE:
            print ("simulated: read_mem(0x%x)"%(addr))
            return addr # just some data
        with open("/dev/mem", "r+b") as f:
            page_addr=addr & (~(self.PAGE_SIZE-1))
            page_offs=addr-page_addr
            if (page_addr>=0x80000000):
                page_addr-= (1<<32)
            mm = mmap.mmap(f.fileno(), self.PAGE_SIZE, offset=page_addr)
            data=struct.unpack(self.ENDIAN+"L",mm[page_offs:page_offs+4])
            d=data[0]
            if self.DEBUG_MODE > 2:
                print ("0x%08x ==> 0x%08x (%d)"%(addr,d,d))
            return d
#        mm.close() #probably not needed with "with"
    def mem_dump (self,start_addr,end_addr=0):
        '''
         Read and print memory range from physical memory
         <start_addr> - physical byte start address
         <end_addr> - physical byte end address (inclusive)
         Returns list of read values
        '''
        start_addr &= 0xfffffffc
        end_addr &=   0xfffffffc
        if end_addr<start_addr:
            end_addr = start_addr
        rslt=[]
        if self.DRY_MODE:
            rslt=range(start_addr,end_addr+1,4)
        else:
            with open("/dev/mem", "r+b") as f:
                for addr in range (start_addr,end_addr+4,4):
                    page_addr=addr & (~(self.PAGE_SIZE-1))
                    page_offs=addr-page_addr
                    if (page_addr>=0x80000000):
                        page_addr-= (1<<32)
                    mm = mmap.mmap(f.fileno(), self.PAGE_SIZE, offset=page_addr)
                    data=struct.unpack(self.ENDIAN+"L",mm[page_offs:page_offs+4])
                    rslt.append(data[0])
                    
        for addr in range (start_addr,end_addr+4,4):
            if (addr == start_addr) or ((addr & 0x3f) == 0):
                if self.DRY_MODE:
                    print ("\nsimulated: 0x%08x:"%addr,end="")
                else:     
                    print ("\n0x%08x:"%addr,end="")
            d=rslt[(addr-start_addr) >> 2]
            print ("%08x "%d,end=""),
        print("")
        return rslt    
    '''
    Read/write slave AXI using byte addresses relative to the AXI memory region
    '''
    def axi_write_single(self,addr,data):
        """
        Write 32-bit word to the slave AXI address range
        <addr> - physical byte address relative to the slave AXI memory region
        <data> - 32-bit data to write
        """
        self.write_mem(self.AXI_SLAVE0_BASE+addr,data)

    def axi_read_addr(self,addr):
        """
        Read 32-bit word from the  slave AXI address range
        <addr> - physical byte address relative to slave AXI AXI memory region
        """
        return self.read_mem(self.AXI_SLAVE0_BASE+addr)
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
        if verbose:
            print("axi_write_single_w(0x%x,0x%08x)"%(addr,data))
        self.axi_write_single(addr<<2,data)

    def axi_read_addr_w(self,addr):
        """
        Read 32-bit word from the slave AXI address range, using 32-word address
        <addr> - 32-bit word (register) address relative to the slave AXI memory region
        """
        return self.axi_read_addr(addr<<2)
