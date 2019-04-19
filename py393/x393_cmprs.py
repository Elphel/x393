from __future__ import division
from __future__ import print_function

'''
# Copyright (C) 2015, Elphel.inc.
# Class to control JPEG/JP4 compressor  
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

import x393_utils

#import time
import vrlg
import x393_mcntrl
class X393Cmprs(object):
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
    
    def program_status_compressor(self,
                                  cmprs_chn,
                                  mode,     # input [1:0] mode;
                                  seq_num): # input [5:0] seq_num;
        """
        Set status generation mode for selected compressor channel
        @param cmprs_chn - number of the compressor channel (0..3)
        @param mode -       status generation mode:
                                  0: disable status generation,
                                  1: single status request,
                                  2: auto status, keep specified seq number,
                                  3: auto, inc sequence number 
        @param seq_number - 6-bit sequence number of the status message to be sent
        """

        self.x393_axi_tasks.program_status (
                             vrlg.CMPRS_GROUP_ADDR  + cmprs_chn * vrlg.CMPRS_BASE_INC,
                             vrlg.CMPRS_STATUS_CNTRL,
                             mode,
                             seq_num)# //MCONTR_PHY_STATUS_REG_ADDR=          'h0,
    def func_compressor_format (self,
                                num_macro_cols_m1,
                                num_macro_rows_m1,
                                left_margin):
        """
        @param num_macro_cols_m1 - number of macroblock colums minus 1
        @param num_macro_rows_m1 - number of macroblock rows minus 1
        @param left_margin - left margin of the first pixel (0..31) for 32-pixel wide colums in memory access
        @return combined compressor format data word
        """
        data = 0;
        data |=(num_macro_cols_m1 & ((1 << vrlg.CMPRS_FRMT_MBCM1_BITS) - 1))  << vrlg.CMPRS_FRMT_MBCM1
        data |=(num_macro_rows_m1 & ((1 << vrlg.CMPRS_FRMT_MBRM1_BITS) - 1))  << vrlg.CMPRS_FRMT_MBRM1
        data |=(left_margin &       ((1 << vrlg.CMPRS_FRMT_LMARG_BITS) - 1))  << vrlg.CMPRS_FRMT_LMARG
        return data
        
    def func_compressor_color_saturation (self,
                                colorsat_blue,
                                colorsat_red):
        """
        @param colorsat_blue - color saturation for blue (10 bits), 0x90 for 100%
        @param colorsat_red -  color saturation for red (10 bits), 0xb6 for 100%
        @return combined compressor format data word
        """
        data = 0;
        data |=(colorsat_blue & ((1 << vrlg.CMPRS_CSAT_CB_BITS) - 1))  << vrlg.CMPRS_CSAT_CB
        data |=(colorsat_red &  ((1 << vrlg.CMPRS_CSAT_CR_BITS) - 1))  << vrlg.CMPRS_CSAT_CR
        return data
    def func_compressor_control (self,
                                 run_mode =    None,
                                 qbank =       None,
                                 dc_sub =      None,
                                 cmode =       None,
                                 multi_frame = None,
                                 bayer =       None,
                                 focus_mode =  None,
                                 row_lsb_raw = None,
                                 be16 =        None):
        """
        Combine compressor control parameters into a single word. None value preserves old setting for the parameter
        @param run_mode -    0 - reset, 2 - run single from memory, 3 - run repetitive
        @param qbank -       quantization table page (0..15)
        @param dc_sub -      True - subtract DC before running DCT, False - no subtraction, convert as is,
        @param cmode -       color mode:
                                CMPRS_CBIT_CMODE_JPEG18 =          0 - color 4:2:0
                                CMPRS_CBIT_CMODE_MONO6 =           1 - mono 4:2:0 (6 blocks)
                                CMPRS_CBIT_CMODE_JP46 =            2 - jp4, 6 blocks, original
                                CMPRS_CBIT_CMODE_JP46DC =          3 - jp4, 6 blocks, dc -improved
                                CMPRS_CBIT_CMODE_JPEG20 =          4 - mono, 4 blocks (but still not actual monochrome JPEG as the blocks are scanned in 2x2 macroblocks)
                                CMPRS_CBIT_CMODE_JP4 =             5 - jp4,  4 blocks, dc-improved
                                CMPRS_CBIT_CMODE_JP4DC =           6 - jp4,  4 blocks, dc-improved
                                CMPRS_CBIT_CMODE_JP4DIFF =         7 - jp4,  4 blocks, differential
                                CMPRS_CBIT_CMODE_JP4DIFFHDR =      8 - jp4,  4 blocks, differential, hdr
                                CMPRS_CBIT_CMODE_JP4DIFFDIV2 =     9 - jp4,  4 blocks, differential, divide by 2
                                CMPRS_CBIT_CMODE_JP4DIFFHDRDIV2 = 10 - jp4,  4 blocks, differential, hdr,divide by 2
                                CMPRS_CBIT_CMODE_MONO1 =          11 -  mono JPEG (not yet implemented)
                                CMPRS_CBIT_CMODE_MONO4 =          14 -  mono 4 blocks
        @param multi_frame -  False - single-frame buffer, True - multi-frame video memory buffer,
        @param bayer -        Bayer shift (0..3)
        @param focus_mode -   focus mode - how to combine image with "focus quality" in the result image
        @param row_lsb_raw -  four LSBs of the window height - used in raw mode
        @param be16 -         big endian 16-bit mode (1 for 16-bit raw) 
        @return               combined data word
        """
        data = 0;
        if not run_mode is None:
            data |= (1 << vrlg.CMPRS_CBIT_RUN)
            data |= (run_mode & ((1 << vrlg.CMPRS_CBIT_RUN_BITS) - 1)) << (vrlg.CMPRS_CBIT_RUN - vrlg.CMPRS_CBIT_RUN_BITS)
                     
        if not qbank is None:
            data |= (1 << vrlg.CMPRS_CBIT_QBANK)
            data |= (qbank & ((1 << vrlg.CMPRS_CBIT_QBANK_BITS) - 1)) << (vrlg.CMPRS_CBIT_QBANK - vrlg.CMPRS_CBIT_QBANK_BITS)

        if not dc_sub is None:
            data |= (1 << vrlg.CMPRS_CBIT_DCSUB)
            data |= (dc_sub & ((1 << vrlg.CMPRS_CBIT_DCSUB_BITS) - 1)) << (vrlg.CMPRS_CBIT_DCSUB - vrlg.CMPRS_CBIT_DCSUB_BITS)

        if not cmode is None:
            data |= (1 << vrlg.CMPRS_CBIT_CMODE)
            data |= (cmode & ((1 << vrlg.CMPRS_CBIT_CMODE_BITS) - 1)) << (vrlg.CMPRS_CBIT_CMODE - vrlg.CMPRS_CBIT_CMODE_BITS)
                     
        if not multi_frame is None:
            data |= (1 << vrlg.CMPRS_CBIT_FRAMES)
            data |= (multi_frame & ((1 << vrlg.CMPRS_CBIT_FRAMES_BITS) - 1)) << (vrlg.CMPRS_CBIT_FRAMES - vrlg.CMPRS_CBIT_FRAMES_BITS)
                     
        if not be16 is None:
            data |= (1 << vrlg.CMPRS_CBIT_BE16)
            data |= (bayer & ((1 << vrlg.CMPRS_CBIT_BE16_BITS) - 1)) << (vrlg.CMPRS_CBIT_BE16 - vrlg.CMPRS_CBIT_BE16_BITS)

        if not bayer is None:
            data |= (1 << vrlg.CMPRS_CBIT_BAYER)
            data |= (bayer & ((1 << vrlg.CMPRS_CBIT_BAYER_BITS) - 1)) << (vrlg.CMPRS_CBIT_BAYER - vrlg.CMPRS_CBIT_BAYER_BITS)
                     
        if not focus_mode is None:
            data |= (1 << vrlg.CMPRS_CBIT_FOCUS)
            data |= (focus_mode & ((1 << vrlg.CMPRS_CBIT_FOCUS_BITS) - 1)) << (vrlg.CMPRS_CBIT_FOCUS - vrlg.CMPRS_CBIT_FOCUS_BITS)
        if not row_lsb_raw is None:
            data |= (1 << vrlg.CMPRS_CBIT_ROWS_LSB)
            data |= (row_lsb_raw & ((1 << vrlg.CMPRS_CBIT_ROWS_LSB_BITS) - 1)) << (vrlg.CMPRS_CBIT_ROWS_LSB - vrlg.CMPRS_CBIT_ROWS_LSB_BITS)
        return data
    
    def compressor_format (self,
                           chn,
                           num_macro_cols_m1,
                           num_macro_rows_m1,
                           left_margin):
        """
        @param chn -               compressor channel number
        @param num_macro_cols_m1 - number of macroblock colums minus 1
        @param num_macro_rows_m1 - number of macroblock rows minus 1
        @param left_margin - left margin of the first pixel (0..31) for 32-pixel wide colums in memory access
        """
        data = self.func_compressor_format (num_macro_cols_m1 = num_macro_cols_m1,
                                            num_macro_rows_m1 = num_macro_rows_m1,
                                            left_margin =       left_margin)
        self.x393_axi_tasks.write_control_register(vrlg.CMPRS_GROUP_ADDR +  chn * vrlg.CMPRS_BASE_INC + vrlg.CMPRS_FORMAT,
                                                  data)

    def compressor_color_saturation (self,
                                     chn,
                                     colorsat_blue,
                                     colorsat_red):
        """
        @param chn -           compressor channel number
        @param colorsat_blue - color saturation for blue (10 bits), 0x90 for 100%
        @param colorsat_red -  color saturation for red (10 bits), 0xb6 for 100%
        """
        data = self.func_compressor_color_saturation (colorsat_blue = colorsat_blue,
                                                      colorsat_red = colorsat_red)
        self.x393_axi_tasks.write_control_register(vrlg.CMPRS_GROUP_ADDR +  chn * vrlg.CMPRS_BASE_INC + vrlg.CMPRS_COLOR_SATURATION,
                                                  data)

    def compressor_coring (self,
                           chn,
                           coring):
        """
        @param chn -    compressor channel number
        @param coring - coring value
        """
        data = coring & ((1 << vrlg.CMPRS_CORING_BITS) - 1)
        self.x393_axi_tasks.write_control_register(vrlg.CMPRS_GROUP_ADDR +  chn * vrlg.CMPRS_BASE_INC + vrlg.CMPRS_CORING_MODE,
                                                  data)

    def compressor_control (self,
                            chn,
                            run_mode =    None,
                            qbank =       None,
                            dc_sub =      None,
                            cmode =       None,
                            multi_frame = None,
                            bayer =       None,
                            row_lsb_raw = None,
                            be16 =        None):
        """
        Combine compressor control parameters into a single word. None value preserves old setting for the parameter
        @param chn -         compressor channel number, "a" or "all" - same for all 4 channels
        @param run_mode -    0 - reset, 2 - run single from memory, 3 - run repetitive
        @param qbank -       quantization table page (0..15)
        @param dc_sub -      True - subtract DC before running DCT, False - no subtraction, convert as is,
        @param cmode -       color mode:
                                CMPRS_CBIT_CMODE_JPEG18 =          0 - color 4:2:0
                                CMPRS_CBIT_CMODE_MONO6 =           1 - mono 4:2:0 (6 blocks)
                                CMPRS_CBIT_CMODE_JP46 =            2 - jp4, 6 blocks, original
                                CMPRS_CBIT_CMODE_JP46DC =          3 - jp4, 6 blocks, dc -improved
                                CMPRS_CBIT_CMODE_JPEG20 =          4 - mono, 4 blocks (but still not actual monochrome JPEG as the blocks are scanned in 2x2 macroblocks)
                                CMPRS_CBIT_CMODE_JP4 =             5 - jp4,  4 blocks, dc-improved
                                CMPRS_CBIT_CMODE_JP4DC =           6 - jp4,  4 blocks, dc-improved
                                CMPRS_CBIT_CMODE_JP4DIFF =         7 - jp4,  4 blocks, differential
                                CMPRS_CBIT_CMODE_JP4DIFFHDR =      8 - jp4,  4 blocks, differential, hdr
                                CMPRS_CBIT_CMODE_JP4DIFFDIV2 =     9 - jp4,  4 blocks, differential, divide by 2
                                CMPRS_CBIT_CMODE_JP4DIFFHDRDIV2 = 10 - jp4,  4 blocks, differential, hdr,divide by 2
                                CMPRS_CBIT_CMODE_MONO1 =          11 -  mono JPEG (not yet implemented)
                                CMPRS_CBIT_CMODE_MONO4 =          14 -  mono 4 blocks
        @param multi_frame -  False - single-frame buffer, True - multi-frame video memory buffer,
        @param bayer -        Bayer shift (0..3)
        @param focus_mode -   focus mode - how to combine image with "focus quality" in the result image 
        @param row_lsb_raw - four LSBs of the window height - used in raw mode
        @param be16 -         big endian 16-bit mode (1 for 16-bit raw) 
        """
        try:
            if (chn == all) or (chn[0].upper() == "A"): #all is a built-in function
                for chn in range(4):
                    self.compressor_control (chn =         chn,
                                             run_mode =    run_mode,
                                             qbank =       qbank,
                                             dc_sub =      dc_sub,
                                             cmode =       cmode,
                                             multi_frame = multi_frame,
                                             bayer =       bayer,
                                             focus_mode =  focus_mode,
                                             row_lsb_raw = row_lsb_raw,
                                             be16 =        be16)
                return
        except:
            pass
        data = self.func_compressor_control(
                            run_mode =    run_mode,
                            qbank =       qbank,
                            dc_sub =      dc_sub,
                            cmode =       cmode,
                            multi_frame = multi_frame,
                            bayer =       bayer,
                            focus_mode =  focus_mode,
                            row_lsb_raw = row_lsb_raw,
                            be16 =        be16)
        
        self.x393_axi_tasks.write_control_register(vrlg.CMPRS_GROUP_ADDR +  chn * vrlg.CMPRS_BASE_INC + vrlg.CMPRS_CONTROL_REG,
                                                  data)
        
    def compressor_interrupt_control (self,
                                      chn,
                                      cntrl = "clr"):
        """
        Control compressor interrupts
        @param chn -      compressor channel number, "a" or "all" - same for all 4 channels
        @param cntrl -    "clr" - clear, "en" - enable, "dis" - disable
        """
#        print("compressor_interrupt_control(",chn,", ",cntrl,")")
        try:
            if (chn == all) or (chn[0].upper() == "A"): #all is a built-in function
                for chn in range(4):
                    self.compressor_interrupt_control (chn =      chn,
                                                     cntrl =    cntrl)
                return
        except:
            pass
        if cntrl.lower() == "clr":
            data = 1
        elif cntrl.lower() == "dis":
            data = 2
        elif cntrl.lower() == "en":
            data = 3
        else:
            print ("compressor_interrupts(): invalid control mode: %s, only 'clr', 'en' and 'dis' are accepted"%(str(cntrl)))
            return
        self.x393_axi_tasks.write_control_register(vrlg.CMPRS_GROUP_ADDR +  chn * vrlg.CMPRS_BASE_INC + vrlg.CMPRS_INTERRUPTS,
                                                  data)        
    def compressor_interrupt_acknowledge (self, enabledOnly=True):
        """
        Clear (one of) raised compressor interrupts
        @param enabledOnly consider only channels with interrupts enabled
        @return number of cleared interrupt, None if none was set 
        """
        d = 0 if enabledOnly else 2
        for chn in range(4):
            if ((self.get_status_compressor(chn) | d) & 3) == 3: # both request and mask are set
                self.compressor_interrupt_control(chn, "clr")
                return chn
        return None    
        
    def get_status_compressor ( self,
                                chn="All"):
        """
        Read compressor status word
        @param chn - compressor port (0..3)
        @return status word
        """
        try:
            if (chn == all) or (chn[0].upper() == "A"): #all is a built-in function
                rslt = []
                for chn in range(4):
                    rslt.append(self.get_status_compressor (chn = chn))
                return rslt
        except:
            pass
        return self.x393_axi_tasks.read_status(
                    address=(vrlg.CMPRS_STATUS_REG_BASE + chn * vrlg.CMPRS_STATUS_REG_INC))       

    def get_highfreq_compressor ( self,
                                chn="All"):
        """
        Read total high frequency amount from the compressor
        @param chn - compressor port (0..3)
        @return status word
        """
        try:
            if (chn == all) or (chn[0].upper() == "A"): #all is a built-in function
                rslt = []
                for chn in range(4):
                    rslt.append(self.get_highfreq_compressor (chn = chn))
                return rslt
        except:
            pass
        return self.x393_axi_tasks.read_status(
                    address=(vrlg.CMPRS_HIFREQ_REG_BASE + num_sensor * vrlg.CMPRS_STATUS_REG_INC))       


    def control_compressor_memory(self,
                              num_sensor,
                              command,
                              reset_frame = False,
                              copy_frame = False,
                              abort_late = False,
                              linear =     False,
                              verbose = 1):
        """
        Control memory access (write) of a sensor channel
        @param num_sensor - memory sensor channel (or all)
        @param command -    one of (case insensitive):
               reset       - reset channel, channel pointers immediately,
               stop        - stop at the end of the frame (if repetitive),
               single      - acquire single frame ,
               repetitive  - repetitive mode
        @param reset_frame - reset frame number
        @param copy_frame  - copy frame number from the master channel (non-persistent)
        @param abort_late  -  abort frame r/w at the next frame sync, if not finished. Wait for pending memory transfers
        @param vebose -      verbose level       
        """
        try:
            if (num_sensor == all) or (num_sensor[0].upper() == "A"): #all is a built-in function
                for num_sensor in range(4):
                    print ('num_sensor = ',num_sensor)
                    self.control_compressor_memory(num_sensor = num_sensor,
                                                   command =    command,
                                                   reset_frame = reset_frame,
                                                   copy_frame = copy_frame,
                                                   abort_late = abort_late,
                                                   linear =     linear,
                                                   verbose =    verbose)
                return
        except:
            pass
        
        
        rpt =    False
        sngl =   False
        en =     False
        rst =    False
        byte32 = True
        if command[:3].upper() ==   'RES':
            rst = True
        elif command[:2].upper() == 'ST':
            pass
        elif command[:2].upper() == 'SI':
            sngl = True
            en =   True
        elif command[:3].upper() == 'REP':
            rpt =  True
            en =   True
        else:
            print ("Unrecognized command %s. Valid commands are RESET, STOP, SINGLE, REPETITIVE"%(command))
            return    
                                
        base_addr = vrlg.MCONTR_CMPRS_BASE + vrlg.MCONTR_CMPRS_INC * num_sensor;
        mode=   x393_mcntrl.func_encode_mode_scan_tiled(
                                   skip_too_late = True,                     
                                   disable_need = False,
                                   repetitive=    rpt,
                                   single =       sngl,
                                   reset_frame =  reset_frame,
                                   byte32 =       byte32,
                                   linear =       linear,
                                   keep_open =    False,
                                   extra_pages =  0,
                                   write_mem =    False,
                                   enable =       en,
                                   chn_reset =    rst,
                                   copy_frame = copy_frame,
                                   abort_late =   abort_late)
        
        self.x393_axi_tasks.write_control_register(base_addr + vrlg.MCNTRL_TILED_MODE,  mode) 
        if verbose > 0 :
            print ("write_control_register(0x%08x, 0x%08x)"%(base_addr + vrlg.MCNTRL_TILED_MODE,  mode))



        
    def setup_compressor_memory (self,
                                 num_sensor,
                                 frame_sa,
                                 frame_sa_inc,
                                 last_frame_num,
                                 frame_full_width,
                                 window_width,
                                 window_height,
                                 window_left,
                                 window_top,
                                 byte32,
                                 linear,
                                 tile_width,
                                 tile_vstep, # = 16
                                 tile_height, #= 18
                                 extra_pages,
                                 disable_need,
                                 abort_late = False):
        """
        Setup memory controller for a compressor channel
        @param num_sensor -       sensor port number (0..3)
        @param frame_sa -         22-bit frame start address ((3 CA LSBs==0. BA==0)
        @param frame_sa_inc -     22-bit frame start address increment  ((3 CA LSBs==0. BA==0)
        @param last_frame_num -   16-bit number of the last frame in a buffer
        @param frame_full_width - 13-bit Padded line length (8-row increment), in 8-bursts (16 bytes)
        @param window_width -     13-bit - in 8*16=128 bit bursts
        @param window_height -    16-bit window height (in scan lines)
        @param window_left -      13-bit window left margin in 8-bursts (16 bytes)
        @param window_top -       16-bit window top margin (in scan lines
        @param byte32 -           32-byte columns
        @param linear -           linear mode instead of tiled (for raw images)
        @param tile_width         tile width,
        @param tile_vstep         tile vertical step in pixel rows (JPEG18/jp4 = 16)
        @param tile_height        tile height: 18 for color JPEG, 16 fore JP$ flavors,
        @param extra_pages        extra pages needed (1)
        @param disable_need       disable need (preference to sensor channels - they can not wait
        @param abort_late         abort frame r/w at the next frame sync, if not finished. Wait for pending memory transfers
        """
#        tile_vstep = 16
#        tile_height= 18
        base_addr = vrlg.MCONTR_CMPRS_BASE + vrlg.MCONTR_CMPRS_INC * num_sensor;
        mode=   x393_mcntrl.func_encode_mode_scan_tiled(
                                   skip_too_late = False,
                                   disable_need = disable_need,
                                   repetitive=    True,
                                   single =       False,
                                   reset_frame =  True, # Now needed to propagate start address False,
                                   byte32 =       byte32,
                                   linear =       linear,
                                   keep_open =    False,
                                   extra_pages =  extra_pages,
                                   write_mem =    False,
                                   enable =       True,
                                   chn_reset =    False,
                                   abort_late =   abort_late)
        self.x393_axi_tasks.write_control_register(
                                    base_addr + vrlg.MCNTRL_TILED_STARTADDR,
                                    frame_sa) # RA=80, CA=0, BA=0 22-bit frame start address (3 CA LSBs==0. BA==0)
        self.x393_axi_tasks.write_control_register(
                                    base_addr + vrlg.MCNTRL_TILED_FRAME_SIZE,
                                    frame_sa_inc)
        self.x393_axi_tasks.write_control_register(
                                    base_addr + vrlg.MCNTRL_TILED_FRAME_LAST,
                                    last_frame_num)
        self.x393_axi_tasks.write_control_register(
                                    base_addr + vrlg.MCNTRL_TILED_FRAME_FULL_WIDTH,
                                    frame_full_width)
        self.x393_axi_tasks.write_control_register(
                                    base_addr + vrlg.MCNTRL_TILED_WINDOW_WH,
                                    ((window_height & 0xffff) << 16) | (window_width & 0xffff)) #/WINDOW_WIDTH + (WINDOW_HEIGHT<<16));
        self.x393_axi_tasks.write_control_register(
                                    base_addr + vrlg.MCNTRL_TILED_WINDOW_X0Y0,
                                    ((window_top & 0xffff) << 16) | (window_left & 0xffff)) #WINDOW_X0+ (WINDOW_Y0<<16));
        self.x393_axi_tasks.write_control_register(
                                    base_addr + vrlg.MCNTRL_TILED_WINDOW_STARTXY,
                                    0)
        self.x393_axi_tasks.write_control_register(
                                    base_addr + vrlg.MCNTRL_TILED_TILE_WHS,
                                    ((tile_vstep & 0xff) <<16) | ((tile_height & 0xff) <<8) | (tile_width & 0xff)) #//(tile_height<<8)+(tile_vstep<<16));
        self.x393_axi_tasks.write_control_register(
                                    base_addr + vrlg.MCNTRL_TILED_MODE,
                                    mode); 
#    def compressor_run(self, # may use compressor_control with the same arguments
#                       num_sensor,
#                       run_mode):
#        """
#        Compressor reset.run/single (alias of compressor_control) 
#        @param num_sensor -       sensor port number (0..3)
#        @param run_mode -    0 - reset, 2 - run single from memory, 3 - run repetitive
#        """
#        self.compressor_control(
#            num_sensor = num_sensor,  # sensor channel number (0..3)
#            run_mode = run_mode)      #0 - reset, 2 - run single from memory, 3 - run repetitive
        
    def setup_compressor_channel (self,
                                  chn,
                                  qbank,
                                  dc_sub,
                                  cmode,
                                  bits16,
                                  multi_frame,
                                  bayer,
                                  focus_mode,
                                  num_macro_cols_m1,
                                  num_macro_rows_m1,
                                  row_lsb_raw,
                                  left_margin,
                                  colorsat_blue,
                                  colorsat_red,
                                  coring,
                                  verbose=0):
        """
        @param chn -        compressor channel (0..3)
        @param qbank -       quantization table page (0..15)
        @param dc_sub -      True - subtract DC before running DCT, False - no subtraction, convert as is,
        @param cmode -       color mode:
                                CMPRS_CBIT_CMODE_JPEG18 =          0 - color 4:2:0
                                CMPRS_CBIT_CMODE_MONO6 =           1 - mono 4:2:0 (6 blocks)
                                CMPRS_CBIT_CMODE_JP46 =            2 - jp4, 6 blocks, original
                                CMPRS_CBIT_CMODE_JP46DC =          3 - jp4, 6 blocks, dc -improved
                                CMPRS_CBIT_CMODE_JPEG20 =          4 - mono, 4 blocks (but still not actual monochrome JPEG as the blocks are scanned in 2x2 macroblocks)
                                CMPRS_CBIT_CMODE_JP4 =             5 - jp4,  4 blocks, dc-improved
                                CMPRS_CBIT_CMODE_JP4DC =           6 - jp4,  4 blocks, dc-improved
                                CMPRS_CBIT_CMODE_JP4DIFF =         7 - jp4,  4 blocks, differential
                                CMPRS_CBIT_CMODE_JP4DIFFHDR =      8 - jp4,  4 blocks, differential, hdr
                                CMPRS_CBIT_CMODE_JP4DIFFDIV2 =     9 - jp4,  4 blocks, differential, divide by 2
                                CMPRS_CBIT_CMODE_JP4DIFFHDRDIV2 = 10 - jp4,  4 blocks, differential, hdr,divide by 2
                                CMPRS_CBIT_CMODE_MONO1 =          11 -  mono JPEG (not yet implemented)
                                CMPRS_CBIT_CMODE_MONO4 =          14 -  mono 4 blocks
                                CMPRS_CBIT_CMODE_RAW =            15 -  raw (uncompressed) mode
        @param bits16 -       16-bit (2 bytes per pixel) mode                                
        @param multi_frame -  False - single-frame buffer, True - multi-frame video memory buffer,
        @param bayer -        Bayer shift (0..3)
        @param focus_mode -   focus mode - how to combine image with "focus quality" in the result image 
        @param num_macro_cols_m1 - number of macroblock colums minus 1
        @param num_macro_rows_m1 - number of macroblock rows minus 1
        @param row_lsb_raw - four LSBs of the window height - used in raw mode
        @param left_margin - left margin of the first pixel (0..31) for 32-pixel wide colums in memory access
        @param colorsat_blue - color saturation for blue (10 bits), 0x90 for 100%
        @param colorsat_red -  color saturation for red (10 bits), 0xb6 for 100%
        @param coring - coring value
        @param verbose - verbose level
        """
        if verbose > 0:
            print("COMPRESSOR_SETUP")
            print (   "num_sensor = ",chn)
            print (   "qbank = ",qbank)
            print (   "dc_sub = ",dc_sub)
            print (   "cmode = ",cmode)
            print (   "multi_frame = ",multi_frame)
            print (   "bayer = ",bayer)
            print (   "focus_mode = ",focus_mode)
            print (   "row_lsb_raw = ", row_lsb_raw)
        self.compressor_control(
            chn =         chn,         # compressor channel number (0..3)
            run_mode =    None,        # no change
            qbank =       qbank,       # [6:3] quantization table page
            dc_sub =      dc_sub,      # [8:7] subtract DC
            cmode =       cmode,       #  [13:9] color mode:
            multi_frame = multi_frame, # [15:14] 0 - single-frame buffer, 1 - multiframe video memory buffer
            bayer =       bayer,       # [20:18] # Bayer shift
            focus_mode =  focus_mode,  # [23:21] Set focus mode
            row_lsb_raw = row_lsb_raw, # [3:0] LSBs of the window height that do not fit into compressor format
            be16 =        bits16)      # swap bytes in compressor channel
        
        self.compressor_format(
            chn =               chn,        # compressor channel number (0..3)
            num_macro_cols_m1 = num_macro_cols_m1, # number of macroblock colums minus 1
            num_macro_rows_m1 = num_macro_rows_m1, # number of macroblock rows minus 1
            left_margin =       left_margin)      # left margin of the first pixel (0..31) for 32-pixel wide colums in memory access
    
        self.compressor_color_saturation(
            chn =           chn,           # compressor channel number (0..3)
            colorsat_blue = colorsat_blue, # color saturation for blue (10 bits) #'h90 for 100%
            colorsat_red =  colorsat_red)  # color saturation for red (10 bits)   # 'b6 for 100%

        self.compressor_coring(
            chn =        chn,           # compressor channel number (0..3)
            coring =     coring);       # coring value


