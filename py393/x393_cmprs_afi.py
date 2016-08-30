from __future__ import division
from __future__ import print_function

'''
# Copyright (C) 2015, Elphel.inc.
# Class to control 10353 GPIO port  
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
#import pickle
from x393_mem                import X393Mem
import x393_axi_control_status
import x393_sens_cmprs
import x393_utils

import time
import vrlg
class X393CmprsAfi(object):
    DRY_MODE= True # True
    DEBUG_MODE=1
    x393_mem=None
    x393_axi_tasks=None #x393X393AxiControlStatus
    x393_utils=None
    verbose=1
    def __init__(self, debug_mode=1,dry_mode=True, saveFileName=None):
        self.DEBUG_MODE=  debug_mode
        self.DRY_MODE=    dry_mode
        self.x393_mem=            X393Mem(debug_mode,dry_mode)
        self.x393_axi_tasks=      x393_axi_control_status.X393AxiControlStatus(debug_mode,dry_mode)
        self.x393_utils=          x393_utils.X393Utils(debug_mode,dry_mode, saveFileName) # should not overwrite save file path
        try:
            self.verbose=vrlg.VERBOSE
        except:
            pass
    def afi_mux_program_status (self,
                                port_afi,
                                chn_afi,
                                mode,     # input [1:0] mode;
                                seq_num): # input [5:0] seq_num;
        """
        Set status generation mode for AXI HP multiplexer for compressed data
        @param port_afi - number of AFI port (0 - afi 1, 1 - afi2)
                          configuration controlled by the code. currently both AFI are used: ch0 - cmprs_afi_mux_1.0, ch1 - cmprs_afi_mux_1.1,
                          ch2 - cmprs_afi_mux_2.0, ch3 - cmprs_afi_mux_2.
                          May be changed to (actually already done) ch0 - cmprs_afi_mux_1.0, ch1 -cmprs_afi_mux_1.1,
                          ch2 - cmprs_afi_mux_1.2, ch3 - cmprs_afi_mux_1.3
        @param chn_afi - numer of the afi_mux input port (0..3)
        @param mode -       status generation mode:
                                  0: disable status generation,
                                  1: single status request,
                                  2: auto status, keep specified seq number,
                                  3: auto, inc sequence number 
        @param seq_number - 6-bit sequence number of the status message to be sent
        
        """
        self.x393_axi_tasks.program_status (
                        vrlg.CMPRS_GROUP_ADDR + (vrlg.CMPRS_AFIMUX_RADDR0,vrlg.CMPRS_AFIMUX_RADDR1)[port_afi] + chn_afi,
                        vrlg.CMPRS_AFIMUX_STATUS_CNTRL,
                        mode,
                        seq_num)
    def afi_mux_get_image_pointer(self,
                          port_afi,
                          channel):
        """
        Returns image pointer in bytes inside the circbuf. Status autoupdate should be already set up, mode = 0
        @param port_afi - AFI port (0/1), currently only 0
        @param channel - AFI input channel (0..3) - with 2 AFIs - 0..1 only
        @return - displacement to current image pointer in bytes
        """
#        print ("status reg =      0x%x"%(((vrlg.CMPRS_AFIMUX_REG_ADDR0, vrlg.CMPRS_AFIMUX_REG_ADDR1)[port_afi]+channel) ))
#        print ("status reg data = 0x%x"%(self.x393_axi_tasks.read_status((vrlg.CMPRS_AFIMUX_REG_ADDR0, vrlg.CMPRS_AFIMUX_REG_ADDR1)[port_afi]+channel) ))
        if self.DRY_MODE == True:
            return None
        return 32*(self.x393_axi_tasks.read_status((vrlg.CMPRS_AFIMUX_REG_ADDR0, vrlg.CMPRS_AFIMUX_REG_ADDR1)[port_afi]+channel) & 0x3ffffff)
    
    def afi_mux_get_image_meta(self,
                          port_afi,
                          channel,
                          cirbuf_start = 0x27a00000,
                          circbuf_len =  0x1000000,
                          verbose = 1,
                          num_lines_print = 20):
        """
        Returns image metadata (start, length,timestamp) or null
        @param port_afi - AFI port (0/1), currently only 0, or file path template for simulated mode
        @param channel - AFI input channel (0..3) - with 2 AFIs - 0..1 only
        @return - memory segments (1 or two) with image data, timestamp in numeric and string format
        """
        def read_mem(addr):
            if ba_data:
                return ba_data[addr + 0] + (ba_data[addr + 1] << 8)  + (ba_data[addr + 2] << 16)  + (ba_data[addr + 3] << 24)
            else:
                return self.x393_mem.read_mem(addr)

        if isinstance(port_afi, (unicode,str)):
            data_file = port_afi%channel # for simulated mode
            ba_data=bytearray()
            try:
                with open(data_file) as f:
                    for l in f:
                        line = l.strip()
                        if line:
                            dl = []
                            for item in line.split():
                                dl.append(int(item,16))
                            ba_data += bytearray(dl)    
                            
                if verbose > 0:
                    print ("Read simulated sensor JPEG data from %s data file"%(data_file))
            except:
                print("Failed to read data from ", data_file)
                return
            cirbuf_start = 0
            circbuf_len = len(ba_data)
            print ("len(ba) = %d"%(len(ba_data)))
            if verbose > 1:            
                for i in range(len(ba_data)):
                    if not (i%16):
                        print("\n%04x:"%(i),end="")
                    print ("%02x "%(ba_data[i]),end="")        
            
        else:
            ba_data = None
                
        if verbose > 0:
            print ("\n------------ channel %d --------------"%(channel))
            print ("x393_sens_cmprs.GLBL_WINDOW = ", x393_sens_cmprs.GLBL_WINDOW)
#        if (self.DRY_MODE):
#            return None
        CCAM_MMAP_META        = 12 # extra bytes included at the end of each frame (last aligned to 32 bytes)
        CCAM_MMAP_META_LENGTH =  4 # displacement to length frame length data from the end of the 32-byte aligned frame slot
        CCAM_MMAP_META_USEC   =  8 # // (negative) displacement to USEC data - 20 bits (frame timestamp)
        CCAM_MMAP_META_SEC    = 12 # // (negative) displacement to SEC data - 32 bits (frame timestamp)
        
        
#        offs_len32 = 0x20 - CCAM_MMAP_META_LENGTH # 0x1c #from last image 32-byte chunk to lower of 3-byte image length (MSB == 0xff)
        if ba_data:
            next_image = len(ba_data)
        else:    
            next_image = self.afi_mux_get_image_pointer(port_afi = port_afi,
                                                    channel = channel)
        # Bug - got 0x20 more than start of the new image
        last_image_chunk = next_image - 0x40
        if last_image_chunk < 0:
            last_image_chunk += circbuf_len
##        len32 = self.x393_mem.read_mem(cirbuf_start + last_image_chunk + (0x20 - CCAM_MMAP_META_LENGTH))
        len32 = read_mem(cirbuf_start + last_image_chunk + (0x20 - CCAM_MMAP_META_LENGTH))
        markerFF = len32 >> 24
        if (markerFF != 0xff):
            print ("Failed to get 0xff marker at offset 0x%08x - length word = 0x%08x, next_image = 0x%08x)"%
                    (cirbuf_start + last_image_chunk + (0x20 - CCAM_MMAP_META_LENGTH) + 3,len32,next_image))
            if verbose >0:
                for a in range ( next_image - (0x10 * num_lines_print),  next_image + (0x10 * num_lines_print), 4):
##                    d = self.x393_mem.read_mem(cirbuf_start + a)
                    d = read_mem(cirbuf_start + a)
                    if (a % 16) == 0:
                        print ("\n%08x: "%(a),end ="" )
                    print("%02x %02x %02x %02x "%(d & 0xff, (d >> 8) & 0xff, (d >> 16) & 0xff, (d >> 24) & 0xff), end = "")
#Try noticed (but not yet identified) bug - reduce afi_mux_get_image_pointer result by 1
            next_image -= 0x20
            if next_image < 0:
                next_image += circbuf_len
            last_image_chunk = next_image - 0x40
            if last_image_chunk < 0:
                last_image_chunk += circbuf_len
##            len32 = self.x393_mem.read_mem(cirbuf_start + last_image_chunk + (0x20 - CCAM_MMAP_META_LENGTH))
            len32 = read_mem(cirbuf_start + last_image_chunk + (0x20 - CCAM_MMAP_META_LENGTH))
            markerFF = len32 >> 24
            if (markerFF != 0xff):
                print ("**** Failed to get 0xff marker at CORRECTED offset 0x%08x - length word = 0x%08x, next_image = 0x%08x)"%
                        (cirbuf_start + last_image_chunk + (0x20 - CCAM_MMAP_META_LENGTH) + 3,len32,next_image))
                return None
            if verbose >0:
                print ("\n-----------reduced next frame byte pointer by 0x20 -------------")
            
        len32 &= 0xffffff
#        inserted_bytes = (32 - (((len32 % 32) + CCAM_MMAP_META) % 32)) % 32
        #adjusting to actual...
#        ADJUSTMENT = 2
        ADJUSTMENT = 4 # ???
        inserted_bytes = ((32 - (((len32 % 32) + CCAM_MMAP_META) % 32) - ADJUSTMENT) % 32 ) + ADJUSTMENT
        img_start = last_image_chunk + 32 - CCAM_MMAP_META  - inserted_bytes - len32
        if img_start < 0:
            img_start += circbuf_len
        if verbose >0:
            for a in range ( img_start,  img_start + (0x10 * num_lines_print), 4):
##                d = self.x393_mem.read_mem(cirbuf_start + a)
                d = read_mem(cirbuf_start + a)
                if (a % 16) == 0:
                    print ("\n%08x: "%(a),end ="" )
                print("%02x %02x %02x %02x "%(d & 0xff, (d >> 8) & 0xff, (d >> 16) & 0xff, (d >> 24) & 0xff), end = "")
            print("\n...",end="")
            for a0 in range ( last_image_chunk - (0x10 * num_lines_print),  last_image_chunk + 0x20, 4):
                a = a0
                if (a < 0):
                    a -=circbuf_len
##                d = self.x393_mem.read_mem(cirbuf_start + a)
                d = read_mem(cirbuf_start + a)
                if (a % 16) == 0:
                    print ("\n%08x: "%(a),end ="" )
                print("%02x %02x %02x %02x "%(d & 0xff, (d >> 8) & 0xff, (d >> 16) & 0xff, (d >> 24) & 0xff), end = "")
            print()    

##        sec  = self.x393_mem.read_mem(cirbuf_start + last_image_chunk + (0x20 - CCAM_MMAP_META_SEC))
        sec  = read_mem(cirbuf_start + last_image_chunk + (0x20 - CCAM_MMAP_META_SEC))
##        usec = self.x393_mem.read_mem(cirbuf_start + last_image_chunk + (0x20 - CCAM_MMAP_META_USEC))
        usec = read_mem(cirbuf_start + last_image_chunk + (0x20 - CCAM_MMAP_META_USEC))
        fsec=sec + usec/1000000.0
        try:
            tstr = time.strftime("%b %d %Y %H:%M:%S", time.gmtime(fsec))
        except:
            tstr = "%f (0x%x, 0x%x)"%(fsec, sec,usec)
            print ("**** Bad timestamp = ",tstr)
        segments = ((cirbuf_start + img_start, len32 ),)    
        if (img_start + len32) > circbuf_len: # split in two segments
            segments = ((cirbuf_start + img_start, circbuf_len - img_start),
                        (cirbuf_start, len32 - (circbuf_len - img_start)))
        result = {"timestamp": fsec,
                  "timestring": tstr,
                  "segments":segments}
        if ba_data:
            result["bindata"] = ba_data
        if verbose >0 :
            print ("Inserted bytes after image before meta = 0x%x"%(inserted_bytes))
            print ("Image start (relative to cirbuf) = 0x%x, image length = 0x%x"%(img_start, len32 ))
            print ("Image time stamp = %s (%f)"%(tstr, fsec))
            for i,s in enumerate(segments):
                print ("segment %d: start_address = 0x%x, length = 0x%x"%(i, s[0],s[1]))
        return result    
        
        
    """
>>> hex (0x3dacb * 32)
'0x7b5960'
>>> hex (0x3dacb * 32 + 0x27a00000)
'0x281b5960'
    
    
print time.strftime("%b %d %Y %H:%M:%S", time.gmtime(1442344402.605793))

#define CCAM_MMAP_META 12 // extra bytes included at the end of each frame (last aligned to 32 bytes)
#define CCAM_MMAP_META_LENGTH 4 // displacement to length frame length data from the end of the 32-byte aligned frame slot
#define CCAM_MMAP_META_USEC 8 // (negative) displacement to USEC data - 20 bits (frame timestamp)
#define CCAM_MMAP_META_SEC 12 // (negative) displacement to SEC data - 32 bits (frame timestamp)

**
 * @brief Locate area between frames in the circular buffer
 * @return pointer to interframe parameters structure
 */
inline struct interframe_params_t* updateIRQ_interframe(void) {
   int circbuf_size=get_globalParam (G_CIRCBUFSIZE)>>2;
   int alen = JPEG_wp-9; if (alen<0) alen+=circbuf_size;
   int jpeg_len=ccam_dma_buf_ptr[alen] & 0xffffff;
   set_globalParam(G_FRAME_SIZE,jpeg_len);
   int aframe_params=(alen & 0xfffffff8)-
                     (((jpeg_len + CCAM_MMAP_META + 3) & 0xffffffe0)>>2) /// multiple of 32-byte chunks to subtract
                     -8; /// size of the storage area to be filled before the frame
   if(aframe_params < 0) aframe_params += circbuf_size;
   struct interframe_params_t* interframe= (struct interframe_params_t*) &ccam_dma_buf_ptr[aframe_params];
/// should we use memcpy as before here?
   interframe->frame_length=jpeg_len;
   interframe->signffff=0xffff;
#if ELPHEL_DEBUG_THIS
    set_globalParam          (0x306,get_globalParam (0x306)+1);
#endif

   return interframe;
}

/**
 * @brief Fill exif data with the current frame data, save pointer to Exif page in the interframe area

    """

#    def read_mem (self,addr,quiet=1):
#        '''
#        Read 32-bit word from physical memory
#        @param addr  physical byte address
#        @param quiet - reduce output
#self.x393_mem

#0x27a00000
#    parameter CMPRS_AFIMUX_REG_ADDR0=     'h18,  // Uses 4 locations
#    parameter CMPRS_AFIMUX_REG_ADDR1=     'h1c,  // Uses 4 locations

    def afi_mux_reset (self,
                       port_afi,
                       rst_chn):
        """
        Reset selected input channels of selected AFI multiplexer               
        @param port_afi - number of AFI port (0 - afi 1, 1 - afi2)
        @param rst_chn  - bit mask of channels to reset (persistent, needs release)
        """
        self.x393_axi_tasks.write_control_register(
                    vrlg.CMPRS_GROUP_ADDR + (vrlg.CMPRS_AFIMUX_RADDR0,vrlg.CMPRS_AFIMUX_RADDR1)[port_afi] + vrlg.CMPRS_AFIMUX_RST,
                    rst_chn)
    def  afi_mux_enable_chn (self,
                             port_afi,
                             en_chn,
                             en):
        """
        Enable/disable selected input channel of the selecte AFI multiplexer 
        @param port_afi - number of AFI port (0 - afi 1, 1 - afi2)
        @param en_chn  -  number of afi input channel to enable/disable (0..3)
        @param en  -      number enable (True) or disable (False) selected AFI input
        """ 
        self.x393_axi_tasks.write_control_register(
                    vrlg.CMPRS_GROUP_ADDR + (vrlg.CMPRS_AFIMUX_RADDR0,vrlg.CMPRS_AFIMUX_RADDR1)[port_afi] + vrlg.CMPRS_AFIMUX_EN,
                    (2,3)[en] << (2 * en_chn))
              
    def  afi_mux_enable (self,
                         port_afi,
                         en):
        """
        Enable/disable selected AFI multiplexer
        @param port_afi - number of AFI port (0 - afi 1, 1 - afi2)
        @param en_chn  -  number of afi input channel to enable/disable (0..3)
        @param en  -      number enable (True) or disable (False) selected AFI input
        """ 
        self.x393_axi_tasks.write_control_register(
                    vrlg.CMPRS_GROUP_ADDR + (vrlg.CMPRS_AFIMUX_RADDR0,vrlg.CMPRS_AFIMUX_RADDR1)[port_afi] + vrlg.CMPRS_AFIMUX_EN,
                    (2,3)[en] << (2 * 4))

    def afi_mux_mode_chn (self,
                          port_afi,
                          chn,
                          mode):
        """
        Set mode of selected input channel of the selected AFI multiplexer
        @param port_afi - number of AFI port (0 - afi 1, 1 - afi2)
        @param chn  -     number of afi input channel to program
        @param mode  -    readback mode:
                            mode == 0 - show EOF pointer, internal
                            mode == 1 - show EOF pointer, confirmed written to the system memory
                            mode == 2 - show current pointer, internal
                            mode == 3 - show current pointer, confirmed written to the system memory
        """ 
        self.x393_axi_tasks.write_control_register(
                    vrlg.CMPRS_GROUP_ADDR + (vrlg.CMPRS_AFIMUX_RADDR0,vrlg.CMPRS_AFIMUX_RADDR1)[port_afi] + vrlg.CMPRS_AFIMUX_MODE,
                    (4 + (mode & 3)) << (4 * chn))

    def afi_mux_chn_start_length(self,
                                 port_afi,
                                 chn,
                                 sa,
                                 length):
        """
        Set mode of selected input channel of the selected AFI multiplexer
        @param port_afi - number of AFI port (0 - afi 1, 1 - afi2)
        @param chn  -     number of afi input channel to program
        @param sa  -      start address in 32-byte chunks
        @param length  -  channel buffer length in 32-byte chunks
        """
        reg_addr =  vrlg.CMPRS_GROUP_ADDR + (vrlg.CMPRS_AFIMUX_RADDR0,vrlg.CMPRS_AFIMUX_RADDR1)[port_afi] + vrlg.CMPRS_AFIMUX_SA_LEN + chn
        self.x393_axi_tasks.write_control_register(
                    reg_addr,
                    sa)
        self.x393_axi_tasks.write_control_register(
                    reg_addr + 4,
                    length)
        
    def afi_mux_setup (self,
                       port_afi,
                       chn_mask,
                       status_mode, # = 3,
                       report_mode, # = 0,
                       afi_cmprs0_sa,
                       afi_cmprs0_len,
                       afi_cmprs1_sa,
                       afi_cmprs1_len,
                       afi_cmprs2_sa,
                       afi_cmprs2_len,
                       afi_cmprs3_sa,
                       afi_cmprs3_len,
                       reset = False,
                       verbose = 1):    

        """
        Set mode of selected input channel of the selected AFI multiplexer
        @param port_afi -       number of AFI port (0 - afi 1, 1 - afi2)
        @param chn  -           number of afi input channel to program
        @param status_mode -    status mode (3 for auto)
        @param report_mode  -    readback mode:
                            mode == 0 - show EOF pointer, internal
                            mode == 1 - show EOF pointer, confirmed written to the system memory
                            mode == 2 - show current pointer, internal
                            mode == 3 - show current pointer, confirmed written to the system memory
        @param afi_cmprs0_sa -  input channel 0 start address in 32-byte chunks
        @param afi_cmprs0_len - input channel 0 buffer length in 32-byte chunks
        @param afi_cmprs1_sa -  input channel 0 start address in 32-byte chunks
        @param afi_cmprs1_len - input channel 0 buffer length in 32-byte chunks
        @param afi_cmprs2_sa -  input channel 0 start address in 32-byte chunks
        @param afi_cmprs2_len - input channel 0 buffer length in 32-byte chunks
        @param afi_cmprs3_sa -  input channel 0 start address in 32-byte chunks
        @param afi_cmprs3_len - input channel 0 buffer length in 32-byte chunks
        @param reset - reset all channles
        @param verbose - verbose level
        """
        if verbose >0 :
            print ("afi_mux_setup:")
            print ("AFI port (0/1) =   ",port_afi)
            print ("AFI channel mask = 0x%x"%(chn_mask))
            print ("status mode =      ",status_mode)
            print ("report mode =      ",report_mode)
            
            print ("channel 0 :        0x%08x/0x%08x"%(afi_cmprs0_sa * 32, afi_cmprs0_len * 32))
            print ("channel 1 :        0x%08x/0x%08x"%(afi_cmprs1_sa * 32, afi_cmprs1_len * 32))
            print ("channel 2 :        0x%08x/0x%08x"%(afi_cmprs2_sa * 32, afi_cmprs2_len * 32))
            print ("channel 3 :        0x%08x/0x%08x"%(afi_cmprs3_sa * 32, afi_cmprs3_len * 32))
        
        sa =     (afi_cmprs0_sa,  afi_cmprs1_sa,  afi_cmprs2_sa,  afi_cmprs3_sa)
        length = (afi_cmprs0_len, afi_cmprs1_len, afi_cmprs2_len, afi_cmprs3_len)
        for i in range(4):
            if (chn_mask >> i) & 1 :
                self.afi_mux_program_status (port_afi = port_afi,
                                             chn_afi = i,
                                             mode =status_mode,
                                             seq_num = 0)
        if reset:        
        # reset all channels    
            self.afi_mux_reset( port_afi = port_afi,
                                rst_chn = 0xf) # reset all channels
            # release resets
            self.afi_mux_reset( port_afi = port_afi,
                                rst_chn =  0) # release reset on all channels
            
        # set report mode (pointer type) - per status    
        for i in range(4):
            if (chn_mask >> i) & 1 :
                self.afi_mux_mode_chn (port_afi = port_afi,
                                       chn = i,
                                       mode = report_mode)
        for i in range(4):
            if (not sa[i] is None) and (not length[i] is None):
                self.afi_mux_chn_start_length (port_afi = port_afi,
                                               chn =      i,
                                               sa =       sa[i],
                                               length =   length[i])

        # enable selected channels        
        for i in range(4):
            if (chn_mask >> i) & 1 :
                self.afi_mux_enable_chn (port_afi = port_afi,
                                         en_chn =   i,
                                         en =       True)

        # enable the whole afi_mux module
    
        self.afi_mux_enable (port_afi = port_afi,
                             en =       True)

