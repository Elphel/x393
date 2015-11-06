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
                                  4: auto, inc sequence number 
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
                                 focus_mode =  None):
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
                     
        if not bayer is None:
            data |= (1 << vrlg.CMPRS_CBIT_BAYER)
            data |= (bayer & ((1 << vrlg.CMPRS_CBIT_BAYER_BITS) - 1)) << (vrlg.CMPRS_CBIT_BAYER - vrlg.CMPRS_CBIT_BAYER_BITS)
                     
        if not focus_mode is None:
            data |= (1 << vrlg.CMPRS_CBIT_FOCUS)
            data |= (focus_mode & ((1 << vrlg.CMPRS_CBIT_FOCUS_BITS) - 1)) << (vrlg.CMPRS_CBIT_FOCUS - vrlg.CMPRS_CBIT_FOCUS_BITS)
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
                            focus_mode =  None):
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
                                             focus_mode =  focus_mode)
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
                            focus_mode =  focus_mode)
        self.x393_axi_tasks.write_control_register(vrlg.CMPRS_GROUP_ADDR +  chn * vrlg.CMPRS_BASE_INC + vrlg.CMPRS_CONTROL_REG,
                                                  data)
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
                                 tile_width,
                                 extra_pages,
                                 disable_need):
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
        @param tile_width         tile width,
        @param extra_pages        extra pages needed (1)
        @param disable_need       disable need (preference to sensor channels - they can not wait
        """
        tile_vstep = 16
        tile_height= 18
        base_addr = vrlg.MCONTR_CMPRS_BASE + vrlg.MCONTR_CMPRS_INC * num_sensor;
        mode=   x393_mcntrl.func_encode_mode_scan_tiled(
                                   disable_need = disable_need,
                                   repetitive=    True,
                                   single =       False,
                                   reset_frame =  False,
                                   byte32 =       byte32,
                                   keep_open =    False,
                                   extra_pages =  extra_pages,
                                   write_mem =    False,
                                   enable =       True,
                                   chn_reset =    False)
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
                                  num_sensor,
                                  qbank,
                                  dc_sub,
                                  cmode,
                                  multi_frame,
                                  bayer,
                                  focus_mode,
                                  num_macro_cols_m1,
                                  num_macro_rows_m1,
                                  left_margin,
                                  colorsat_blue,
                                  colorsat_red,
                                  coring,
                                  verbose=0):
        """
        @param num_sensor -       sensor port number (0..3)
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
        @param num_macro_cols_m1 - number of macroblock colums minus 1
        @param num_macro_rows_m1 - number of macroblock rows minus 1
        @param left_margin - left margin of the first pixel (0..31) for 32-pixel wide colums in memory access
        @param colorsat_blue - color saturation for blue (10 bits), 0x90 for 100%
        @param colorsat_red -  color saturation for red (10 bits), 0xb6 for 100%
        @param coring - coring value
        @param verbose - verbose level
        """
        if verbose > 0:
            print("COMPRESSOR_SETUP")
            print (   "num_sensor = ",num_sensor)
            print (   "qbank = ",qbank)
            print (   "dc_sub = ",dc_sub)
            print (   "cmode = ",cmode)
            print (   "multi_frame = ",multi_frame)
            print (   "bayer = ",bayer)
            print (   "focus_mode = ",focus_mode)
        self.compressor_control(
            chn =         num_sensor,  # sensor channel number (0..3)
            qbank =       qbank,       # [6:3] quantization table page
            dc_sub =      dc_sub,      # [8:7] subtract DC
            cmode =       cmode,       #  [13:9] color mode:
            multi_frame = multi_frame, # [15:14] 0 - single-frame buffer, 1 - multiframe video memory buffer
            bayer =       bayer,       # [20:18] # Bayer shift
            focus_mode =  focus_mode) # [23:21] Set focus mode
            
        self.compressor_format(
            chn =               num_sensor,        # sensor channel number (0..3)
            num_macro_cols_m1 = num_macro_cols_m1, # number of macroblock colums minus 1
            num_macro_rows_m1 = num_macro_rows_m1, # number of macroblock rows minus 1
            left_margin =       left_margin)      # left margin of the first pixel (0..31) for 32-pixel wide colums in memory access
    
        self.compressor_color_saturation(
            chn =          num_sensor,    # sensor channel number (0..3)
            colorsat_blue = colorsat_blue, # color saturation for blue (10 bits) #'h90 for 100%
            colorsat_red =  colorsat_red) # color saturation for red (10 bits)   # 'b6 for 100%

        self.compressor_coring(
            chn =        num_sensor,    # sensor channel number (0..3)
            coring =     coring);       # coring value


