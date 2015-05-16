'''
Created on May 12, 2015

@author: yuri
'''
#!/usr/bin/env python
# encoding: utf-8

import hashlib
import random
import sys
import os
import mmap
import struct
import x393_mcntrl_membridge

class X393McntrlDmatest(object):
    '''
    classdocs
    '''
    PAGE_SIZE = 4096
    ENDIAN = "<"
    MEM_PATH = '/sys/devices/elphel393-mem.2/'
    BUFFER_ADDRESS_NAME = 'buffer_address'
    BUFFER_PAGES_NAME = 'buffer_pages'
    BUFFER_FLUSH_NAME = 'buffer_flush'
    BYTEMODE = 4
    FORMAT = 'L'

    def __init__(self, debug_mode=1, dry_mode=True):
        self.dest_offset = 0                           
        self.dest_size = 0                                
        self.buffer_start = 0                                 
        self.buffer_end = 0                                   
        self.membridge = x393_mcntrl_membridge.X393McntrlMembridge(
                         debug_mode, dry_mode)
                                                                  

    def _flush_mem(self):                                           
        '''                                                             
        This will flush all cache contents into memory        
        @return None                                                    
        '''
        try:
            with open(self.MEM_PATH + self.BUFFER_FLUSH_NAME,'w') as sysfile:
                sysfile.write("1")
        except:
            print("Failed to flush cache")

    def _invalidate_mem(self):                                           
        '''                                                             
        This will invalidate cache content and 
        allow direct reads from memory
        @return None                                                    
        '''
        try:
            with open(self.MEM_PATH + self.BUFFER_FLUSH_NAME,'w') as sysfile:
                sysfile.write("1")
        except:
            print("Failed to flush cache")
    def _set_buffer(self, addr, pages):
        '''
        Set memory region to test DMA operations in
        @param addr Start address of the buffer
        @param pages Buffer size in memory pages
        @return None
        '''
        self.buffer_startaddr = addr
        self.buffer_size = pages*self.PAGE_SIZE
        self.buffer_endaddr = self.buffer_startaddr + self.buffer_size

    def dmatest_set_buffer_from_sysfs(self):
        '''
        Set memory buffer for DMA operations
        based on sysfs-provided parameters
        @return None
        '''
        try:
            with open(self.MEM_PATH + self.BUFFER_ADDRESS_NAME) as sysfile:
                self.buffer_startaddr = int(sysfile.read(),0)
            with open(self.MEM_PATH + self.BUFFER_PAGES_NAME) as sysfile:
                self.buffer_size = self.PAGE_SIZE*int(sysfile.read(),0)
            self.buffer_endaddr = self.buffer_startaddr + self.buffer_size
        except:
            print("Failed to get reserved physical memory range")

    def _set_source_region(self,offset,pages):
        '''
        Set DMA region to be transfered into
        framebuffer memory. Page-aligned. Memory buffer
        for DMA operations has to be allocated.
        @param offset Position in the allocated memory buffer
        @param pages Data region size (in pages)
        @return None
        '''
        pagealigned = offset & (~(self.PAGE_SIZE-1))
        self.source_offset = pagealigned
        self.source_size = self.PAGE_SIZE*pages
        self.source_pages = pages
        self.source_startaddr = self.buffer_startaddr + self.source_offset
        self.source_endaddr = self.source_startaddr + self.source_size
        if (    self.source_offset + self.source_size > self.buffer_endaddr or
                self.source_offset < 0 or self.source_size < 0  ):
            raise MemoryError("Region is outside of the buffer")

    def _set_dest_region(self,offset,pages):
        '''
        Set DMA region to transfer data from
        framebuffer memory. Page-aligned. Memory buffer
        for DMA operations has to be allocated.
        @param offset Position in the allocated memory buffer
        @param pages Data region size (in pages)
        @return None
        '''
        pagealigned = offset & (~(self.PAGE_SIZE-1))
        self.dest_offset = pagealigned
        self.dest_size = self.PAGE_SIZE*pages
        self.dest_pages = pages
        self.dest_startaddr = self.buffer_startaddr + self.dest_offset
        self.dest_endaddr = self.dest_startaddr + self.dest_size
        if (    self.dest_offset + self.dest_size > self.buffer_endaddr or
                self.dest_offset < 0 or self.dest_size < 0      ):
            raise MemoryError("Region is outside of the buffer")

    def _fill_source_region(self):
        '''
        Fill defined DMA test region with random data
        @return None
        '''
        datactr = 0
        self.tag = random.randint(0,0xFF) << 24
        print("Tag = "+hex(int(self.tag>>24)))
        with open("/dev/mem", "r+b") as f:
            for addr in range(self.source_startaddr,self.source_endaddr,self.BYTEMODE):
                data = datactr*0x400//self.PAGE_SIZE | self.tag # random.randint(0,(1<<self.BYTEMODE*8)-1) & (1<<self.BYTEMODE*8)-1
                page_addr = addr & (~(self.PAGE_SIZE-1))
                page_offs = addr - page_addr
                if (page_addr >= 0x80000000):
                    page_addr -= (1<<32)
                mm = mmap.mmap(f.fileno(), self.PAGE_SIZE, offset=page_addr)
                packed_data = struct.pack(self.ENDIAN+"L", data)
                mm[page_offs:page_offs+4] = packed_data
                datactr += 1

    def _get_dest_region(self):
        '''
        Calculate checksum of destination data
        @return None
        '''
        errors = 0
        dataref = 0
        with open("/dev/mem", "r+b") as f:
            for addr in range(self.dest_startaddr,self.dest_endaddr,self.BYTEMODE):
                page_addr = addr & (~(self.PAGE_SIZE-1))
                page_offs = addr - page_addr
                if (page_addr >= 0x80000000):
                    page_addr -= (1<<32)
                mm = mmap.mmap(f.fileno(),self.PAGE_SIZE, offset=page_addr)
                data = struct.unpack(self.ENDIAN+"L",mm[page_offs:page_offs+4])
                if (hex(int(data[0])) != hex(int(dataref*0x400//self.PAGE_SIZE | self.tag))):
                    errors += 1
                dataref = dataref + 1
        print(str(errors)+" errors found")
        self.result = True if errors == 0 else False

    def _set_fb_region(self, startaddr=0x1000, fullwidth=128, width=32, leftoffset=0, topoffset=0, linemultiplier=8):
        '''
        Set framebuffer memory region 
        to transfer data from system memory
        Default values allow to read framebuffer at
        0x20, 0x21... lines, 0th column, 0..7 memory banks 
        with 32x32 region showing 1 recorded line
        Example: set_and_read 32 32 0 0x20 0 1 1
        @startaddr Starting address of data array in framebuffer
        @fullwidth Period of lines in memory
        @width Length of line
        @leftoffset Data offset from beginning of line
        @topoffset Data offset from zeroth line
        @linemultiplier set this value to a number of lines
                        which form 1 memory page (to sync
                        allocated memory size in sysmem and fb)
        @return None
        '''
        self.fb_startaddr = startaddr
        self.fb_fullwidth = fullwidth
        self.fb_width = width
        self.fb_left = leftoffset
        self.fb_top = topoffset
        self.fb_linemul = linemultiplier

    def _transfer_source_to_fb(self):
        '''
        Transfer source region content
        from system memory to framebuffer
        @return None
        '''
        print("Source: start = "+hex(self.source_offset)+", size = "+str(self.source_size))
        self.membridge.membridge_rw(    True, 
                        self.fb_startaddr, self.fb_fullwidth, self.fb_width, 
                        self.source_size/self.PAGE_SIZE*self.fb_linemul, 
                        self.fb_left, self.fb_top, 
                        self.source_offset>>3, self.buffer_startaddr>>3, 
                        self.source_size>>3, False, 0x3, True, True )

    def _transfer_fb_to_dest(self):
        '''
        Transfer framebuffer memory content 
        to dest region in system memory
        @return None
        '''
        print("Dest:   start = "+hex(self.dest_offset)+", size = "+str(self.dest_size))
        self.membridge.membridge_rw(    False, 
                        self.fb_startaddr, self.fb_fullwidth, self.fb_width, 
                        self.dest_size/self.PAGE_SIZE*self.fb_linemul, 
                        self.fb_left, self.fb_top, 
                        self.dest_offset>>3, self.buffer_startaddr>>3, 
                        self.dest_size>>3, False, 0x3, True, True )

    def _result(self):
        '''
        Report if data checksums are equal
        @return True/False
        '''
        return self.result

    def dmatest_prepare(self, pages=1, source=0, startaddr=0x1000, fullwidth=128, width=32, leftoffset=0, topoffset=0, linemultiplier=8):
        '''
        Set source memory region
        and transfer data to fb
        @pages Number of data memory pages
        @source Source offset in buffer (pages)
        @startaddr,@fullwidth,@width,@leftoffset,@topoffset,@linemultiplier - 
            see _set_fb_region()
        '''
        self._set_source_region(source,pages)
        self._set_fb_region(startaddr,fullwidth,width,leftoffset,topoffset,linemultiplier)
        self._fill_source_region()
        self._flush_mem()
        self._transfer_source_to_fb()

    def dmatest_run(self, pages=1, dest=0):
        '''
        Set destination memory region
        and transfer data from fb
        @pages Number of data memory pages
        @dest Destination offset in buffer (pages)
        @return True if no data corruption was detected
        '''
        self._set_dest_region(dest,pages)
        self._transfer_fb_to_dest()
        self._invalidate_mem()
        self._get_dest_region()
        return self._result()

    def dmatest(self,pages=1,source=None,dest=None,startaddr=0x1000, fullwidth=128, width=32, leftoffset=0, topoffset=0, linemultiplier=8):
        '''
        Randomly set source and destination regions,
        fill source with random data and run test.
        @pages Test region size (in memory pages)
        @source Source offset (in pages) left 'None' to
                generate randomly
        @dest Destination offset (in pages) left 'None' to
                generate randomly
        @startaddr,@fullwidth,@width,@leftoffset,@topoffset,@linemultiplier - 
            see _set_fb_region()
        @return True if successful
        '''
        self.dmatest_set_buffer_from_sysfs()
        if source == None:
            source = random.randint(0,self.buffer_size-pages*self.PAGE_SIZE)
        if dest == None:
            dest = random.randint(0,self.buffer_size-pages*self.PAGE_SIZE)
        self.dmatest_prepare(pages,source,startaddr,fullwidth,width,leftoffset,topoffset,linemultiplier)
        transfer_str = ( str(pages)+" pages starting from page "+
                         hex(int(source))+" -> page "+hex(int(dest)))
        result = self.dmatest_run(pages,dest)
        if (result):
            print(transfer_str+" PASSED")
        else:
            print(transfer_str+" FAILED")
        return result

    def dmatest_until_fail(self,sizerange=10, source=None, dest=None, startaddr=0x1000, fullwidth=128, width=32, leftoffset=0, topoffset=0, linemultiplier=8):
        '''
        randomly perform DMA testing until it fails
        @sizerange Maximum number of pages to be transfered at single test
        @source Source offset (in pages) left 'None' to
                generate randomly
        @dest Destination offset (in pages) left 'None' to
                generate randomly
        @startaddr,@fullwidth,@width,@leftoffset,@topoffset,@linemultiplier - 
            see _set_fb_region()
        @return None
        '''
        while True:
            if not self.dmatest(random.randint(1,sizerange),source,dest,startaddr,fullwidth,width,leftoffset,topoffset,linemultiplier):
                break

