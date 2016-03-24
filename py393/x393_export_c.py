from __future__ import division
from __future__ import print_function

'''
# Copyright (C) 2015, Elphel.inc.
# Class to export hardware definitions from Verilog parameters  
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
import vrlg
class X393ExportC(object):
    DRY_MODE =   True # True
    DEBUG_MODE = 1
    MAXI0_BASE = 0x40000000
    verbose=1
    dflt_frmt_spcs={'ftype':        'u32',
                    'showBits':     True,
                    'showDefaults': True,
                    'showReserved': False,
                    'nameLength':   15,
                    'lastPad':      False,
                    'macroNameLen': 48,
                    'showType':     True,
                    'showRange':    True,
                    'nameMembers':  True} #name each struct in a union 

    def __init__(self, debug_mode=1,dry_mode=True, saveFileName=None):
        self.DEBUG_MODE=  debug_mode
        self.DRY_MODE=    dry_mode
        try:
            self.verbose=vrlg.VERBOSE
        except:
            pass
    def export_all(self):
        print(self.typedefs(frmt_spcs = None))
        ld= self.define_macros()
        ld+=self.define_other_macros()
        for d in ld:
            print(self.expand_define_maxi0(d, frmt_spcs = None))
        print("\n\n// ===== Sorted address map =====\n")
        sam = self.expand_define_parameters(ld)
#        print("sam=",sam)
        for d in sam:
            print(self.expand_define_maxi0(d, frmt_spcs = None))
            
    def typedefs(self, frmt_spcs = None):
#        print("Will list bitfields typedef and comments")
        stypedefs = ""
        
        stypedefs += self.get_typedef32(comment =   "Status generation control ",
                                 data =      self._enc_status_control(),
                                 name =      "x393_status_ctrl_wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Memory channel operation mode",
                                 data =      self._enc_func_encode_mode_scan_tiled(),
                                 name =      "x393_mcntrl_mode_scan_wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Memory channel window tile size/step (tiled only)",
                                 data =      self._enc_window_tile_whs(),
                                 name =      "x393_mcntrl_window_tile_whs_wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Memory channel window size",
                                 data =      self._enc_window_wh(),
                                 name =      "x393_mcntrl_window_width_height_wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Memory channel window position",
                                 data =      self._enc_window_lt(),
                                 name =      "x393_mcntrl_window_left_top_wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Memory channel scan start (debug feature)",
                                 data =      self._enc_window_sxy(),
                                 name =      "x393_mcntrl_window_startx_starty_wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Memory channel window full (padded) width",
                                 data =      self._enc_window_fw(),
                                 name =      "x393_mcntrl_window_full_width_wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Memory channel last frame number in a buffer (number of frames minus 1)",
                                 data =      self._enc_window_last_frame_number(),
                                 name =      "x393_mcntrl_window_last_frame_num_wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Memory channel frame start address increment (for next frame in a buffer)",
                                 data =      self._enc_window_frame_sa_inc(),
                                 name =      "x393_mcntrl_window_frame_sa_inc_wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Memory channel frame start address for the first frame in a buffer",
                                 data =      self._enc_window_frame_sa(),
                                 name =      "x393_mcntrl_window_frame_sa_wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "PS PIO (software-programmed DDR3) access sequences enable and reset",
                                 data =      self._enc_ps_pio_en_rst(),
                                 name =      "x393_ps_pio_en_rst_wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "PS PIO (software-programmed DDR3) access sequences control",
                                 data =      self._enc_ps_pio_cmd(),
                                 name =      "x393_ps_pio_cmd_wo",
                                 frmt_spcs = frmt_spcs)

        stypedefs += self.get_typedef32(comment =   "x393 generic status register",
                                 data =      self._enc_status(),
                                 name =      "x393_status_ro",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Memory PHY status",
                                 data =      self._enc_status_mcntrl_phy(),
                                 name =      "x393_status_mcntrl_phy_ro",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Memory controller requests status",
                                 data =      self._enc_status_mcntrl_top(),
                                 name =      "x393_status_mcntrl_top_ro",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Memory software access status",
                                 data =      self._enc_status_mcntrl_ps(),
                                 name =      "x393_status_mcntrl_ps_ro",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Memory test channels access status",
                                 data =      self._enc_status_lintile(),
                                 name =      "x393_status_mcntrl_lintile_ro",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Memory test channels status",
                                 data =      self._enc_status_testchn(),
                                 name =      "x393_status_mcntrl_testchn_ro",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Membridge channel status",
                                 data =      self._enc_status_membridge(),
                                 name =      "x393_status_membridge_ro",
                                 frmt_spcs = frmt_spcs)
        
        stypedefs += self.get_typedef32(comment =   "Sensor/multiplexer I/O pins status",
                                 data =      self._enc_status_sens_io(),
                                 name =      "x393_status_sens_io_ro",
                                 frmt_spcs = frmt_spcs)

        stypedefs += self.get_typedef32(comment =   "Sensor/multiplexer i2c status",
                                 data =      self._enc_status_sens_i2c(),
                                 name =      "x393_status_sens_i2c_ro",
                                 frmt_spcs = frmt_spcs)

        stypedefs += self.get_typedef32(comment =   "Command bits for test01 module (test frame memory accesses)",
                                 data =      self._enc_test01_mode(),
                                 name =      "x393_test01_mode_wo",
                                 frmt_spcs = frmt_spcs)

        stypedefs += self.get_typedef32(comment =   "Command for membridge",
                                 data =      self._enc_membridge_cmd(),
                                 name =      "x393_membridge_cmd_wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Cache mode for membridge",
                                 data =      self._enc_membridge_mode(),
                                 name =      "x393_membridge_mode_wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Address in 64-bit words",
                                 data =      self._enc_u29(),
                                 name =      "u29_wo",
                                 frmt_spcs = frmt_spcs)
        
        stypedefs += self.get_typedef32(comment =   "I2C contol/table data",
                                 data =      [self._enc_i2c_tbl_addr(), # generate typedef union
                                              self._enc_i2c_tbl_wmode(),
                                              self._enc_i2c_tbl_rmode(),
                                              self._enc_i2c_ctrl()],
                                 name =      "x393_i2c_ctltbl_wo",
                                 frmt_spcs = frmt_spcs)
        
        stypedefs += self.get_typedef32(comment =   "Write sensor channel mode register",
                                 data =      self._enc_sens_mode(),
                                 name =      "x393_sens_mode_wo",
                                 frmt_spcs = frmt_spcs)

        stypedefs += self.get_typedef32(comment =   "Write number of sensor frames to combine into one virtual (linescan mode)",
                                 data =      self._enc_sens_sync_mult(),
                                 name =      "x393_sens_sync_mult_wo",
                                 frmt_spcs = frmt_spcs)

        stypedefs += self.get_typedef32(comment =   "Write sensor number of lines to delay frame sync",
                                 data =      self._enc_sens_sync_late(),
                                 name =      "x393_sens_sync_late_wo",
                                 frmt_spcs = frmt_spcs)

        stypedefs += self.get_typedef32(comment =   "Configure memory controller priorities",
                                 data =      self._enc_mcntrl_priorities(),
                                 name =      "x393_arbite_pri_rw",
                                 frmt_spcs = frmt_spcs)

        stypedefs += self.get_typedef32(comment =   "Enable/disable memory controller channels",
                                 data =      self._enc_mcntrl_chnen(),
                                 name =      "x393_mcntr_chn_en_rw",
                                 frmt_spcs = frmt_spcs)
        
        stypedefs += self.get_typedef32(comment =   "DQS and DQM patterns (DQM - 0, DQS 0xaa or 0x55)",
                                 data =      self._enc_mcntrl_dqs_dqm_patterns(),
                                 name =      "x393_mcntr_dqs_dqm_patt_rw",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "DQ and DQS tristate control when turning on and off",
                                 data =      self._enc_mcntrl_dqs_dq_tri(),
                                 name =      "x393_mcntr_dqs_dqm_tri_rw",
                                 frmt_spcs = frmt_spcs)

        return stypedefs
    
    def define_macros(self):
        #memory arbiter priorities
        ba = vrlg.CONTROL_ADDR
        z3= (0,3)
        z15= (0,15)
        ia = 1
        c = "chn"
        sdefines = []
        sdefines +=[
            (('R/W addresses to set up memory arbiter priorities. For sensors  (chn = 8..11), for compressors - 12..15',)),
            (("X393_MCNTRL_ARBITER_PRIORITY",              c, vrlg.MCONTR_ARBIT_ADDR +             ba, ia, z15, "x393_arbite_pri_rw",                     "Set memory arbiter priority (currently r/w, may become just wo)"))]        

        sdefines +=[
            (('Enable/disable memory channels (bits in a 16-bit word). For sensors  (chn = 8..11), for compressors - 12..15',)),
            (("X393_MCNTRL_CHN_EN",     c, vrlg.MCONTR_TOP_16BIT_ADDR +  vrlg.MCONTR_TOP_16BIT_CHN_EN +    ba,     0, None, "x393_mcntr_chn_en_rw",   "Enable/disable memory channels (currently r/w, may become just wo)")),
            (("X393_MCNTRL_DQS_DQM_PATT",c, vrlg.MCONTR_PHY_16BIT_ADDR+  vrlg.MCONTR_PHY_16BIT_PATTERNS +  ba,     0, None, "x393_mcntr_dqs_dqm_patt_rw",     "Setup DQS and DQM patterns")),
            (("X393_MCNTRL_DQ_DQS_TRI", c, vrlg.MCONTR_PHY_16BIT_ADDR +  vrlg.MCONTR_PHY_16BIT_PATTERNS_TRI+ ba,   0, None, "x393_mcntr_dqs_dqm_tri_rw",      "Setup DQS and DQ on/off sequence")),
            (("Following enable/disable addresses can be written with any data,only addresses matter",)),
            (("X393_MCNTRL_DIS",        c, vrlg.MCONTR_TOP_0BIT_ADDR +   vrlg.MCONTR_TOP_0BIT_MCONTR_EN +  ba + 0, 0, None, "",                       "Disable DDR3 memory controller")),        
            (("X393_MCNTRL_EN",         c, vrlg.MCONTR_TOP_0BIT_ADDR +   vrlg.MCONTR_TOP_0BIT_MCONTR_EN +  ba + 1, 0, None, "",                       "Enable DDR3 memory controller")),        
            (("X393_MCNTRL_REFRESH_DIS",c, vrlg.MCONTR_TOP_0BIT_ADDR +   vrlg.MCONTR_TOP_0BIT_REFRESH_EN + ba + 0, 0, None, "",                       "Disable DDR3 memory refresh")),        
            (("X393_MCNTRL_REFRESH_EN", c, vrlg.MCONTR_TOP_0BIT_ADDR +   vrlg.MCONTR_TOP_0BIT_REFRESH_EN + ba + 1, 0, None, "",                       "Enable DDR3 memory refresh")),        
            (("X393_MCNTRL_SDRST_DIS",  c, vrlg.MCONTR_TOP_0BIT_ADDR +   vrlg.MCONTR_PHY_0BIT_SDRST_ACT +  ba + 0, 0, None, "",                       "Disable DDR3 memory reset")),        
            (("X393_MCNTRL_SDRST_EN",   c, vrlg.MCONTR_TOP_0BIT_ADDR +   vrlg.MCONTR_PHY_0BIT_SDRST_ACT +  ba + 1, 0, None, "",                       "Enable DDR3 memory reset")),        
            (("X393_MCNTRL_CKE_DIS",    c, vrlg.MCONTR_TOP_0BIT_ADDR +   vrlg.MCONTR_PHY_0BIT_CKE_EN +     ba + 0, 0, None, "",                       "Disable DDR3 memory CKE")),        
            (("X393_MCNTRL_CKE_EN",     c, vrlg.MCONTR_TOP_0BIT_ADDR +   vrlg.MCONTR_PHY_0BIT_CKE_EN +     ba + 1, 0, None, "",                       "Enable DDR3 memory CKE")),        
            (("X393_MCNTRL_CMDA_DIS",   c, vrlg.MCONTR_TOP_0BIT_ADDR +   vrlg.MCONTR_PHY_0BIT_CMDA_EN +    ba + 0, 0, None, "",                       "Disable DDR3 memory command/address lines")),        
            (("X393_MCNTRL_CMDA_EN",    c, vrlg.MCONTR_TOP_0BIT_ADDR +   vrlg.MCONTR_PHY_0BIT_CMDA_EN +    ba + 1, 0, None, "",                       "Enable DDR3 memory command/address lines")),        
            ]        
        
        ba = vrlg.MCONTR_SENS_BASE
        ia = vrlg.MCONTR_SENS_INC
        c = "chn"
        sdefines +=[
            (('Write-only addresses to program memory channels for sensors  (chn = 0..3), memory channels 8..11',)),
            (("X393_SENS_MCNTRL_SCANLINE_MODE",            c, vrlg.MCNTRL_SCANLINE_MODE +             ba, ia, z3, "x393_mcntrl_mode_scan_wo",             "Set mode register (write last after other channel registers are set)")),
            (("X393_SENS_MCNTRL_SCANLINE_STATUS_CNTRL",    c, vrlg.MCNTRL_SCANLINE_STATUS_CNTRL +     ba, ia, z3, "x393_status_ctrl_wo",                  "Set status control register (status update mode)")),
            (("X393_SENS_MCNTRL_SCANLINE_STARTADDR",       c, vrlg.MCNTRL_SCANLINE_STARTADDR +        ba, ia, z3, "x393_mcntrl_window_frame_sa_wo",       "Set frame start address")),
            (("X393_SENS_MCNTRL_SCANLINE_FRAME_SIZE",      c, vrlg.MCNTRL_SCANLINE_FRAME_SIZE +       ba, ia, z3, "x393_mcntrl_window_frame_sa_inc_wo",   "Set frame size (address increment)")),
            (("X393_SENS_MCNTRL_SCANLINE_FRAME_LAST",      c, vrlg.MCNTRL_SCANLINE_FRAME_LAST +       ba, ia, z3, "x393_mcntrl_window_last_frame_num_wo", "Set last frame number (number of frames in buffer minus 1)")),
            (("X393_SENS_MCNTRL_SCANLINE_FRAME_FULL_WIDTH",c, vrlg.MCNTRL_SCANLINE_FRAME_FULL_WIDTH + ba, ia, z3, "x393_mcntrl_window_full_width_wo",     "Set frame full(padded) width")),
            (("X393_SENS_MCNTRL_SCANLINE_WINDOW_WH",       c, vrlg.MCNTRL_SCANLINE_WINDOW_WH +        ba, ia, z3, "x393_mcntrl_window_width_height_wo",   "Set frame window size")),
            (("X393_SENS_MCNTRL_SCANLINE_WINDOW_X0Y0",     c, vrlg.MCNTRL_SCANLINE_WINDOW_X0Y0 +      ba, ia, z3, "x393_mcntrl_window_left_top_wo",       "Set frame position")),
            (("X393_SENS_MCNTRL_SCANLINE_STARTXY",         c, vrlg.MCNTRL_SCANLINE_WINDOW_STARTXY +   ba, ia, z3, "x393_mcntrl_window_startx_starty_wo",  "Set startXY register"))]
        ba = vrlg.MCONTR_CMPRS_BASE
        ia = vrlg.MCONTR_CMPRS_INC
        sdefines +=[
            (('Write-only addresses to program memory channels for compressors (chn = 0..3), memory channels 12..15',)),
            (("X393_SENS_MCNTRL_TILED_MODE",               c, vrlg.MCNTRL_TILED_MODE +                ba, ia, z3, "x393_mcntrl_mode_scan_wo",             "Set mode register (write last after other channel registers are set)")),
            (("X393_SENS_MCNTRL_TILED_STATUS_CNTRL",       c, vrlg.MCNTRL_TILED_STATUS_CNTRL +        ba, ia, z3, "x393_status_ctrl_wo",                  "Set status control register (status update mode)")),
            (("X393_SENS_MCNTRL_TILED_STARTADDR",          c, vrlg.MCNTRL_TILED_STARTADDR +           ba, ia, z3, "x393_mcntrl_window_frame_sa_wo",       "Set frame start address")),
            (("X393_SENS_MCNTRL_TILED_FRAME_SIZE",         c, vrlg.MCNTRL_TILED_FRAME_SIZE +          ba, ia, z3, "x393_mcntrl_window_frame_sa_inc_wo",   "Set frame size (address increment)")),
            (("X393_SENS_MCNTRL_TILED_FRAME_LAST",         c, vrlg.MCNTRL_TILED_FRAME_LAST +          ba, ia, z3, "x393_mcntrl_window_last_frame_num_wo", "Set last frame number (number of frames in buffer minus 1)")),
            (("X393_SENS_MCNTRL_TILED_FRAME_FULL_WIDTH",   c, vrlg.MCNTRL_TILED_FRAME_FULL_WIDTH +    ba, ia, z3, "x393_mcntrl_window_full_width_wo",     "Set frame full(padded) width")),
            (("X393_SENS_MCNTRL_TILED_WINDOW_WH",          c, vrlg.MCNTRL_TILED_WINDOW_WH +           ba, ia, z3, "x393_mcntrl_window_width_height_wo",   "Set frame window size")),
            (("X393_SENS_MCNTRL_TILED_WINDOW_X0Y0",        c, vrlg.MCNTRL_TILED_WINDOW_X0Y0 +         ba, ia, z3, "x393_mcntrl_window_left_top_wo",       "Set frame position")),
            (("X393_SENS_MCNTRL_TILED_STARTXY",            c, vrlg.MCNTRL_TILED_WINDOW_STARTXY +      ba, ia, z3, "x393_mcntrl_window_startx_starty_wo",  "Set startXY register")),
            (("X393_SENS_MCNTRL_TILED_TILE_WHS",           c, vrlg.MCNTRL_TILED_TILE_WHS +            ba, ia, z3, "x393_mcntrl_window_tile_whs_wo",       "Set tile size/step (tiled mode only)"))]

        ba = vrlg.MCNTRL_SCANLINE_CHN1_ADDR
        ia = 0
        c =  ""
        sdefines +=[
            (('Write-only addresses to program memory channel for membridge, memory channel 1',)),
            (("X393_MEMBRIDGE_SCANLINE_MODE",            c, vrlg.MCNTRL_SCANLINE_MODE +             ba, 0, None, "x393_mcntrl_mode_scan_wo",             "Set mode register (write last after other channel registers are set)")),
            (("X393_MEMBRIDGE_SCANLINE_STATUS_CNTRL",    c, vrlg.MCNTRL_SCANLINE_STATUS_CNTRL +     ba, 0, None, "x393_status_ctrl_wo",                  "Set status control register (status update mode)")),
            (("X393_MEMBRIDGE_SCANLINE_STARTADDR",       c, vrlg.MCNTRL_SCANLINE_STARTADDR +        ba, 0, None, "x393_mcntrl_window_frame_sa_wo",       "Set frame start address")),
            (("X393_MEMBRIDGE_SCANLINE_FRAME_SIZE",      c, vrlg.MCNTRL_SCANLINE_FRAME_SIZE +       ba, 0, None, "x393_mcntrl_window_frame_sa_inc_wo",   "Set frame size (address increment)")),
            (("X393_MEMBRIDGE_SCANLINE_FRAME_LAST",      c, vrlg.MCNTRL_SCANLINE_FRAME_LAST +       ba, 0, None, "x393_mcntrl_window_last_frame_num_wo", "Set last frame number (number of frames in buffer minus 1)")),
            (("X393_MEMBRIDGE_SCANLINE_FRAME_FULL_WIDTH",c, vrlg.MCNTRL_SCANLINE_FRAME_FULL_WIDTH + ba, 0, None, "x393_mcntrl_window_full_width_wo",     "Set frame full(padded) width")),
            (("X393_MEMBRIDGE_SCANLINE_WINDOW_WH",       c, vrlg.MCNTRL_SCANLINE_WINDOW_WH +        ba, 0, None, "x393_mcntrl_window_width_height_wo",   "Set frame window size")),
            (("X393_MEMBRIDGE_SCANLINE_WINDOW_X0Y0",     c, vrlg.MCNTRL_SCANLINE_WINDOW_X0Y0 +      ba, 0, None, "x393_mcntrl_window_left_top_wo",       "Set frame position")),
            (("X393_MEMBRIDGE_SCANLINE_STARTXY",         c, vrlg.MCNTRL_SCANLINE_WINDOW_STARTXY +   ba, 0, None, "x393_mcntrl_window_startx_starty_wo",  "Set startXY register"))]
        
        ba = vrlg.MEMBRIDGE_ADDR
        ia = 0
        c =  ""
        sdefines +=[
            (("X393_MEMBRIDGE_CTRL",                     c, vrlg.MEMBRIDGE_CTRL +                  ba, 0, None, "x393_membridge_cmd_wo",                "Issue membridge command")),
            (("X393_MEMBRIDGE_STATUS_CNTRL",             c, vrlg.MEMBRIDGE_STATUS_CNTRL +          ba, 0, None, "x393_status_ctrl_wo",                  "Set membridge status control register")),
            (("X393_MEMBRIDGE_LO_ADDR64",                c, vrlg.MEMBRIDGE_LO_ADDR64 +             ba, 0, None, "u29_wo",                               "start address of the system memory range in QWORDs (4 LSBs==0)")),
            (("X393_MEMBRIDGE_SIZE64",                   c, vrlg.MEMBRIDGE_SIZE64 +                ba, 0, None, "u29_wo",                               "size of the system memory range in QWORDs (4 LSBs==0), rolls over")),
            (("X393_MEMBRIDGE_START64",                  c, vrlg.MEMBRIDGE_START64 +               ba, 0, None, "u29_wo",                               "start of transfer offset to system memory range in QWORDs (4 LSBs==0)")),
            (("X393_MEMBRIDGE_LEN64",                    c, vrlg.MEMBRIDGE_LEN64 +                 ba, 0, None, "u29_wo",                               "Full length of transfer in QWORDs")),
            (("X393_MEMBRIDGE_WIDTH64",                  c, vrlg.MEMBRIDGE_WIDTH64 +               ba, 0, None, "u29_wo",                               "Frame width in QWORDs (last xfer in each line may be partial)")),
            (("X393_MEMBRIDGE_MODE",                     c, vrlg.MEMBRIDGE_MODE +                  ba, 0, None, "x393_membridge_mode_wo",               "AXI cache mode"))]

        ba = vrlg.MCNTRL_PS_ADDR
        ia = 0
        c =  ""
        sdefines +=[
            (('Write-only addresses to PS PIO (Software generated DDR3 memory access sequences)',)),
            (("X393_MCNTRL_PS_EN_RST",                   c, vrlg.MCNTRL_PS_EN_RST +                ba, 0, None, "x393_ps_pio_en_rst_wo",                 "Set PS PIO enable and reset")),
            (("X393_MCNTRL_PS_CMD",                      c, vrlg.MCNTRL_PS_CMD +                   ba, 0, None, "x393_ps_pio_cmd_wo",                    "Set PS PIO commands")),
            (("X393_MCNTRL_PS_STATUS_CNTRL",             c, vrlg.MCNTRL_PS_STATUS_CNTRL +          ba, 0, None, "x393_status_ctrl_wo",                   "Set PS PIO status control register (status update mode)"))]

        #other program status (move to other places?)
        ba = vrlg.MCONTR_PHY_16BIT_ADDR
        ia = 0
        c =  ""
        sdefines +=[
            (('Write-only addresses to to program status report mode For memory controller',)),
            (("X393_MCONTR_PHY_STATUS_CNTRL",            c, vrlg.MCONTR_PHY_STATUS_CNTRL +         ba, 0, None, "x393_status_ctrl_wo",                    "Set status control register (status update mode)")),
            (("X393_MCONTR_TOP_16BIT_STATUS_CNTRL",      c, vrlg.MCONTR_TOP_16BIT_STATUS_CNTRL +   ba, 0, None, "x393_status_ctrl_wo",                    "Set status control register (status update mode)")),
        ]
        ba = vrlg.MCNTRL_TEST01_ADDR
        ia = 0
        c =  ""
        sdefines +=[
            (('Write-only addresses to to program status report mode for test channels',)),
            (("X393_MCNTRL_TEST01_CHN2_STATUS_CNTRL",    c, vrlg.MCNTRL_TEST01_CHN2_STATUS_CNTRL + ba, 0, None, "x393_status_ctrl_wo",                    "Set status control register (status update mode)")),
            (("X393_MCNTRL_TEST01_CHN3_STATUS_CNTRL",    c, vrlg.MCNTRL_TEST01_CHN3_STATUS_CNTRL + ba, 0, None, "x393_status_ctrl_wo",                    "Set status control register (status update mode)")),
            (("X393_MCNTRL_TEST01_CHN4_STATUS_CNTRL",    c, vrlg.MCNTRL_TEST01_CHN4_STATUS_CNTRL + ba, 0, None, "x393_status_ctrl_wo",                    "Set status control register (status update mode)")),
            (('Write-only addresses for test channels commands',)),
            (("X393_MCNTRL_TEST01_CHN2_MODE",            c, vrlg.MCNTRL_TEST01_CHN2_MODE +         ba, 0, None, "x393_test01_mode_wo",                    "Set command for test01 channel 2")),
            (("X393_MCNTRL_TEST01_CHN3_MODE",            c, vrlg.MCNTRL_TEST01_CHN3_MODE +         ba, 0, None, "x393_test01_mode_wo",                    "Set command for test01 channel 3")),
            (("X393_MCNTRL_TEST01_CHN4_MODE",            c, vrlg.MCNTRL_TEST01_CHN4_MODE +         ba, 0, None, "x393_test01_mode_wo",                    "Set command for test01 channel 4")),
            
]
        #read_all_status
        ba = vrlg.STATUS_ADDR
        ia = 0
        c =  ""
        sdefines +=[
            (('Read-only addresses for status information',)),
            (("X393_MCONTR_PHY_STATUS",                  c, vrlg.MCONTR_PHY_STATUS_REG_ADDR + ba, 0, None, "x393_status_mcntrl_phy_ro",                   "Status register for MCNTRL PHY")),
            (("X393_MCONTR_TOP_STATUS",                  c, vrlg.MCONTR_TOP_STATUS_REG_ADDR + ba, 0, None, "x393_status_mcntrl_top_ro",                   "Status register for MCNTRL requests")),
            (("X393_MCNTRL_PS_STATUS",                   c, vrlg.MCNTRL_PS_STATUS_REG_ADDR +  ba, 0, None, "x393_status_mcntrl_ps_ro",                    "Status register for MCNTRL software R/W")),
            (("X393_MCNTRL_CHN1_STATUS",                 c, vrlg.MCNTRL_SCANLINE_STATUS_REG_CHN1_ADDR+ba,0,None, "x393_status_mcntrl_lintile_ro",         "Status register for MCNTRL CHN1 (membridge)")),
            (("X393_MCNTRL_CHN3_STATUS",                 c, vrlg.MCNTRL_SCANLINE_STATUS_REG_CHN3_ADDR+ba,0,None, "x393_status_mcntrl_lintile_ro",         "Status register for MCNTRL CHN3 (scanline)")),
            (("X393_MCNTRL_CHN2_STATUS",                 c, vrlg.MCNTRL_TILED_STATUS_REG_CHN2_ADDR+ba,0,None,    "x393_status_mcntrl_lintile_ro",         "Status register for MCNTRL CHN2 (tiled)")),
            (("X393_MCNTRL_CHN4_STATUS",                 c, vrlg.MCNTRL_TILED_STATUS_REG_CHN4_ADDR+ba,0,None,    "x393_status_mcntrl_lintile_ro",         "Status register for MCNTRL CHN4 (tiled)")),
            (("X393_TEST01_CHN2_STATUS",                 c, vrlg.MCNTRL_TEST01_STATUS_REG_CHN2_ADDR+ba,0,None,   "x393_status_mcntrl_testchn_ro",         "Status register for test channel 2")),
            (("X393_TEST01_CHN3_STATUS",                 c, vrlg.MCNTRL_TEST01_STATUS_REG_CHN3_ADDR+ba,0,None,   "x393_status_mcntrl_testchn_ro",         "Status register for test channel 3")),
            (("X393_TEST01_CHN4_STATUS",                 c, vrlg.MCNTRL_TEST01_STATUS_REG_CHN4_ADDR+ba,0,None,   "x393_status_mcntrl_testchn_ro",         "Status register for test channel 4")),
            (("X393_MEMBRIDGE_STATUS",                   c, vrlg.MEMBRIDGE_STATUS_REG+ba, 0, None,         "x393_status_membridge_ro",                    "Status register for membridge")),
            ]

        #Registers to control sensor channels        
        ba = vrlg.SENSOR_GROUP_ADDR
        ia = vrlg.SENSOR_BASE_INC
        c =  "sens_num"
        sdefines +=[
            (('Write-only control of the sensor channels',)),
            (("X393_SENS_MODE",                         c, vrlg.SENSOR_CTRL_RADDR +                        ba, ia, z3, "x393_sens_mode_wo",               "Write sensor channel mode")),
            (("X393_SENSI2C_CTRL",                      c, vrlg.SENSI2C_CTRL_RADDR + vrlg.SENSI2C_CTRL +   ba, ia, z3, "x393_i2c_ctltbl_wo",              "Control sensor i2c, write i2c LUT")),
            (("X393_SENSI2C_STATUS",                    c, vrlg.SENSI2C_CTRL_RADDR + vrlg.SENSI2C_STATUS + ba, ia, z3, "x393_status_ctrl_wo",             "Setup sensor i2c status report mode")),
            (("X393_SENS_SYNC_MULT",                    c, vrlg.SENS_SYNC_RADDR + vrlg.SENS_SYNC_MULT+     ba, ia, z3, "x393_sens_sync_mult_wo",          "Configure frames combining")),
            (("X393_SENS_SYNC_LATE",                    c, vrlg.SENS_SYNC_RADDR + vrlg.SENS_SYNC_LATE+     ba, ia, z3, "x393_sens_sync_late_wo",          "Configure frame sync delay")),
            ]

        #sensors status        
        ba = vrlg.STATUS_ADDR + vrlg.SENSI2C_STATUS_REG_BASE
        ia = vrlg.SENSI2C_STATUS_REG_INC
        c =  "sens_num"
        sdefines +=[
            (('Read-only addresses for sensors status information',)),
            (("X393_SENSI2C_STATUS",                     c, vrlg.SENSI2C_STATUS_REG_REL +      ba, ia, z3, "x393_status_sens_i2c_ro",                     "Status of the sensors i2c")),
            (("X393_SENSIO_STATUS",                      c, vrlg.SENSIO_STATUS_REG_REL +       ba, ia, z3, "x393_status_sens_io_ro",                      "Status of the sensor ports I/O pins")),
            ]
        
        """
        
        """
        return sdefines
    
    def define_other_macros(self): # Used mostly for development/testing, not needed for normal camera operation
        ba = vrlg.MCNTRL_SCANLINE_CHN3_ADDR
        c =  ""
        sdefines = []
        sdefines +=[
            (('Write-only addresses to program memory channel 3 (test channel)',)),
            (("X393_MCNTRL_CHN3_SCANLINE_MODE",            c, vrlg.MCNTRL_SCANLINE_MODE +             ba, 0, None, "x393_mcntrl_mode_scan_wo",             "Set mode register (write last after other channel registers are set)")),
            (("X393_MCNTRL_CHN3_SCANLINE_STATUS_CNTRL",    c, vrlg.MCNTRL_SCANLINE_STATUS_CNTRL +     ba, 0, None, "x393_status_ctrl_wo",                  "Set status control register (status update mode)")),
            (("X393_MCNTRL_CHN3_SCANLINE_STARTADDR",       c, vrlg.MCNTRL_SCANLINE_STARTADDR +        ba, 0, None, "x393_mcntrl_window_frame_sa_wo",       "Set frame start address")),
            (("X393_MCNTRL_CHN3_SCANLINE_FRAME_SIZE",      c, vrlg.MCNTRL_SCANLINE_FRAME_SIZE +       ba, 0, None, "x393_mcntrl_window_frame_sa_inc_wo",   "Set frame size (address increment)")),
            (("X393_MCNTRL_CHN3_SCANLINE_FRAME_LAST",      c, vrlg.MCNTRL_SCANLINE_FRAME_LAST +       ba, 0, None, "x393_mcntrl_window_last_frame_num_wo", "Set last frame number (number of frames in buffer minus 1)")),
            (("X393_MCNTRL_CHN3_SCANLINE_FRAME_FULL_WIDTH",c, vrlg.MCNTRL_SCANLINE_FRAME_FULL_WIDTH + ba, 0, None, "x393_mcntrl_window_full_width_wo",     "Set frame full(padded) width")),
            (("X393_MCNTRL_CHN3_SCANLINE_WINDOW_WH",       c, vrlg.MCNTRL_SCANLINE_WINDOW_WH +        ba, 0, None, "x393_mcntrl_window_width_height_wo",   "Set frame window size")),
            (("X393_MCNTRL_CHN3_SCANLINE_WINDOW_X0Y0",     c, vrlg.MCNTRL_SCANLINE_WINDOW_X0Y0 +      ba, 0, None, "x393_mcntrl_window_left_top_wo",       "Set frame position")),
            (("X393_MCNTRL_CHN3_SCANLINE_STARTXY",         c, vrlg.MCNTRL_SCANLINE_WINDOW_STARTXY +   ba, 0, None, "x393_mcntrl_window_startx_starty_wo",  "Set startXY register"))]
        ba = vrlg.MCNTRL_TILED_CHN2_ADDR
        c =  ""
        sdefines +=[
            (('Write-only addresses to program memory channel 2 (test channel)',)),
            (("X393_MCNTRL_CHN2_TILED_MODE",               c, vrlg.MCNTRL_TILED_MODE +                ba, 0, None, "x393_mcntrl_mode_scan_wo",             "Set mode register (write last after other channel registers are set)")),
            (("X393_MCNTRL_CHN2_TILED_STATUS_CNTRL",       c, vrlg.MCNTRL_TILED_STATUS_CNTRL +        ba, 0, None, "x393_status_ctrl_wo",                  "Set status control register (status update mode)")),
            (("X393_MCNTRL_CHN2_TILED_STARTADDR",          c, vrlg.MCNTRL_TILED_STARTADDR +           ba, 0, None, "x393_mcntrl_window_frame_sa_wo",       "Set frame start address")),
            (("X393_MCNTRL_CHN2_TILED_FRAME_SIZE",         c, vrlg.MCNTRL_TILED_FRAME_SIZE +          ba, 0, None, "x393_mcntrl_window_frame_sa_inc_wo",   "Set frame size (address increment)")),
            (("X393_MCNTRL_CHN2_TILED_FRAME_LAST",         c, vrlg.MCNTRL_TILED_FRAME_LAST +          ba, 0, None, "x393_mcntrl_window_last_frame_num_wo", "Set last frame number (number of frames in buffer minus 1)")),
            (("X393_MCNTRL_CHN2_TILED_FRAME_FULL_WIDTH",   c, vrlg.MCNTRL_TILED_FRAME_FULL_WIDTH +    ba, 0, None, "x393_mcntrl_window_full_width_wo",     "Set frame full(padded) width")),
            (("X393_MCNTRL_CHN2_TILED_WINDOW_WH",          c, vrlg.MCNTRL_TILED_WINDOW_WH +           ba, 0, None, "x393_mcntrl_window_width_height_wo",   "Set frame window size")),
            (("X393_MCNTRL_CHN2_TILED_WINDOW_X0Y0",        c, vrlg.MCNTRL_TILED_WINDOW_X0Y0 +         ba, 0, None, "x393_mcntrl_window_left_top_wo",       "Set frame position")),
            (("X393_MCNTRL_CHN2_TILED_STARTXY",            c, vrlg.MCNTRL_TILED_WINDOW_STARTXY +      ba, 0, None, "x393_mcntrl_window_startx_starty_wo",  "Set startXY register")),
            (("X393_MCNTRL_CHN2_TILED_TILE_WHS",           c, vrlg.MCNTRL_TILED_TILE_WHS +            ba, 0, None, "x393_mcntrl_window_tile_whs_wo",       "Set tile size/step (tiled mode only)"))]
        ba = vrlg.MCNTRL_TILED_CHN4_ADDR
        c =  ""
        sdefines +=[
            (('Write-only addresses to program memory channel 4 (test channel)',)),
            (("X393_MCNTRL_CHN4_TILED_MODE",               c, vrlg.MCNTRL_TILED_MODE +                ba, 0, None, "x393_mcntrl_mode_scan_wo",             "Set mode register (write last after other channel registers are set)")),
            (("X393_MCNTRL_CHN4_TILED_STATUS_CNTRL",       c, vrlg.MCNTRL_TILED_STATUS_CNTRL +        ba, 0, None, "x393_status_ctrl_wo",                  "Set status control register (status update mode)")),
            (("X393_MCNTRL_CHN4_TILED_STARTADDR",          c, vrlg.MCNTRL_TILED_STARTADDR +           ba, 0, None, "x393_mcntrl_window_frame_sa_wo",       "Set frame start address")),
            (("X393_MCNTRL_CHN4_TILED_FRAME_SIZE",         c, vrlg.MCNTRL_TILED_FRAME_SIZE +          ba, 0, None, "x393_mcntrl_window_frame_sa_inc_wo",   "Set frame size (address increment)")),
            (("X393_MCNTRL_CHN4_TILED_FRAME_LAST",         c, vrlg.MCNTRL_TILED_FRAME_LAST +          ba, 0, None, "x393_mcntrl_window_last_frame_num_wo", "Set last frame number (number of frames in buffer minus 1)")),
            (("X393_MCNTRL_CHN4_TILED_FRAME_FULL_WIDTH",   c, vrlg.MCNTRL_TILED_FRAME_FULL_WIDTH +    ba, 0, None, "x393_mcntrl_window_full_width_wo",     "Set frame full(padded) width")),
            (("X393_MCNTRL_CHN4_TILED_WINDOW_WH",          c, vrlg.MCNTRL_TILED_WINDOW_WH +           ba, 0, None, "x393_mcntrl_window_width_height_wo",   "Set frame window size")),
            (("X393_MCNTRL_CHN4_TILED_WINDOW_X0Y0",        c, vrlg.MCNTRL_TILED_WINDOW_X0Y0 +         ba, 0, None, "x393_mcntrl_window_left_top_wo",       "Set frame position")),
            (("X393_MCNTRL_CHN4_TILED_STARTXY",            c, vrlg.MCNTRL_TILED_WINDOW_STARTXY +      ba, 0, None, "x393_mcntrl_window_startx_starty_wo",  "Set startXY register")),
            (("X393_MCNTRL_CHN4_TILED_TILE_WHS",           c, vrlg.MCNTRL_TILED_TILE_WHS +            ba, 0, None, "x393_mcntrl_window_tile_whs_wo",       "Set tile size/step (tiled mode only)"))]
        


        
        return sdefines
    
    def expand_define_maxi0(self, define_tuple, frmt_spcs = None):
        if len(define_tuple)  ==1 :
            return self.expand_define(define_tuple = define_tuple, frmt_spcs = frmt_spcs)
        else:
            return self.expand_define(define_tuple = (define_tuple[0],
                                                      define_tuple[1],
                                                      define_tuple[2] * 4 + self.MAXI0_BASE,
                                                      define_tuple[3] * 4,
                                                      define_tuple[4],
                                                      define_tuple[5],
                                                      define_tuple[6]),
                                      frmt_spcs = frmt_spcs)
            
    def expand_define(self, define_tuple, frmt_spcs = None):
        frmt_spcs=self.fix_frmt_spcs(frmt_spcs)
        s=""
        if len(define_tuple)  ==1 :
            comment = define_tuple[0]
            if comment:
                s += "\n// %s\n"%(comment)
        else:
            name, var_name, address, address_inc, var_range, data_type, comment = define_tuple
            if var_range and frmt_spcs['showRange']:
                if comment:
                    comment += ', '
                comment += "%s = %d..%d"%(var_name, var_range[0], var_range[1])
            if data_type and frmt_spcs['showType']:
                if comment:
                    comment += ', '
                if data_type[-1] == "*": # skip adding '_t": som_type -> some_type_t, u32* -> u32
                    comment += "data type: %s"%(data_type[0:-1])
                else:    
                    comment += "data type: %s_t"%(data_type)
            name_len = len(name)
            if address_inc:
                name_len += 2 + len(var_name)
            ins_spaces = max(0,frmt_spcs['macroNameLen'] - name_len)
            if address_inc:
                s = "#define %s(%s) %s(0x%08x + 0x%x * (%s))"%(name, var_name, ' ' * ins_spaces, address, address_inc, var_name)
            else:
                s = "#define %s %s0x%08x"%(name,' ' * ins_spaces, address)
            if comment:
                s += " // %s"%(comment)
        return s

    def expand_define_parameters(self, in_defs, showGaps = True):
        exp_defs=[]
        for define_tuple in in_defs:
            if len(define_tuple) == 7:
                name, var_name, address, address_inc, var_range, data_type, comment = define_tuple
                if address_inc == 0:
                    exp_defs.append(define_tuple)
                    nextAddr = address + 4
                else:
                    for x in range(var_range[0], var_range[1] + 1):
                        exp_defs.append(("%s__%d"%(name,x),var_name,address+x*address_inc,0,None,data_type,comment))
                    nextAddr = address + var_range[1] * address_inc + 4
        #now sort address map
        sorted_defs= sorted(exp_defs,key=lambda item: item[2])
        if showGaps:
            nextAddr = None
            gapped_defs=[]
            for define_tuple in sorted_defs:
                address = define_tuple[2] 
                if not nextAddr is None:
                    if address > nextAddr:
                        gapped_defs.append(("Skipped 0x%x DWORDs"%(address - nextAddr),))
                    elif not address == nextAddr:
                        print("**************** Error? address = 0x%x (0x%08x), expected address = 0x%x (0x%08x)"%(address, 4*address, nextAddr,4*nextAddr))    
                gapped_defs.append(define_tuple)
                nextAddr = address + 1    
            return gapped_defs
        else:
            return sorted_defs
        
             
    def _enc_func_encode_mode_scan_tiled(self):
        dw=[]
        dw.append(("chn_nreset",   vrlg.MCONTR_LINTILE_EN,1,1,        "0: immediately reset all the internal circuitry"))
        dw.append(("enable",       vrlg.MCONTR_LINTILE_NRESET,1,1,    "enable requests from this channel ( 0 will let current to finish, but not raise want/need)"))
        dw.append(("write_mem",    vrlg.MCONTR_LINTILE_WRITE,1,0,     "0 - read from memory, 1 - write to memory"))
        dw.append(("extra_pages",  vrlg.MCONTR_LINTILE_EXTRAPG, vrlg.MCONTR_LINTILE_EXTRAPG_BITS,0, "2-bit number of extra pages that need to stay (not to be overwritten) in the buffer"))
        dw.append(("keep_open",    vrlg.MCONTR_LINTILE_KEEP_OPEN,1,0, "for 8 or less rows - do not close page between accesses (not used in scanline mode)"))
        dw.append(("byte32",       vrlg.MCONTR_LINTILE_BYTE32,1,1,    "32-byte columns (0 - 16-byte), not used in scanline mode"))
        dw.append(("reset_frame",  vrlg.MCONTR_LINTILE_RST_FRAME,1,0, "reset frame number"))
        dw.append(("single",       vrlg.MCONTR_LINTILE_SINGLE,1,0,    "run single frame"))
        dw.append(("repetitive",   vrlg.MCONTR_LINTILE_REPEAT,1,1,    "run repetitive frames"))
        dw.append(("disable_need", vrlg.MCONTR_LINTILE_DIS_NEED,1,0,  "disable 'need' generation, only 'want' (compressor channels)"))
        dw.append(("skip_too_late",vrlg.MCONTR_LINTILE_SKIP_LATE,1,0, "Skip over missed blocks to preserve frame structure (increment pointers)"))
        return dw
    """
        self.x393_axi_tasks.write_control_register(
                                    base_addr + vrlg.MCNTRL_TILED_TILE_WHS,
                                    ((tile_vstep & 0xff) <<16) | ((tile_height & 0xff) <<8) | (tile_width & 0xff)) #//(tile_height<<8)+(tile_vstep<<16));
    """
    def _enc_window_tile_whs(self):
        dw=[]
        dw.append(("tile_width",   0,6, 2,   "tile width in 8-bursts (16 bytes)"))
        dw.append(("tile_height",  8,6,18,   "tile height in lines (0 means 64 lines)"))
        dw.append(("vert_step",   16,8,16,   "Tile vertical step to control tile overlap"))
        return dw
    
    def _enc_window_wh(self):
        dw=[]
        dw.append(("width",   0,13,0,        "13-bit window width - in 8*16=128 bit bursts"))
        dw.append(("height", 16,16,0,        "16-bit window height in scan lines"))
        return dw

    def _enc_window_lt(self):
        dw=[]
        dw.append(("left",   0,13,0,        "13-bit window left margin in 8-bursts (16 bytes)"))
        dw.append(("top",   16,16,0,        "16-bit window top margin in scan lines"))
        return dw

    def _enc_window_sxy(self):
        dw=[]
        dw.append(("start_x",   0,13,0,        "13-bit window start X relative to window left margin (debug feature, set = 0)"))
        dw.append(("start_y",   16,16,0,       "16-bit window start Y relative to window top margin (debug feature, set = 0)"))
        return dw

    def _enc_window_fw(self):
        dw=[]
        dw.append(("full_width",  0,13,0,        "13-bit Padded line length (8-row increment), in 8-bursts (16 bytes)"))
        return dw
    
    def _enc_window_last_frame_number(self):
        dw=[]
        dw.append(("last_frame_num",  0,16,0,        "16-bit number of the last frame in a buffer (1 for a 2-frame ping-pong one)"))
        return dw

    def _enc_window_frame_sa_inc(self):
        dw=[]
        dw.append(("frame_sa_inc",  0,22,0,        "22-bit frame start address increment  (3 CA LSBs==0. BA==0)"))
        return dw

    def _enc_window_frame_sa(self):
        dw=[]
        dw.append(("frame_sa",      0,22,0,        "22-bit frame start address (3 CA LSBs==0. BA==0)"))
        return dw
    
    def _enc_status_control(self):
        dw=[]
        dw.append(("seq_num",      0,6,0,        "6-bit sequence number to be used with the next status response"))
        dw.append(("mode",         6,2,3,        "Status report mode: 0 - disable, 1 - single, 2 - auto, keep sequence number, 3 - auto, inc. seq. number "))
        return dw

    def _enc_ps_pio_en_rst(self):
        dw=[]
        dw.append(("nrst",         0,1,1,        "Active-low reset for programmed DDR3 memory sequences"))
        dw.append(("en",           1,1,1,        "Enable PS_PIO channel. Only influences request for arbitration, started transactions will finish if disabled"))
        return dw

    def _enc_ps_pio_cmd(self):
        dw=[]
        dw.append(("seq_addr",     0, 10,0,      "Sequence start address"))
        dw.append(("page",         10,2, 0,      "Buffer page number"))
        dw.append(("urgent",       12,1, 0,      "high priority request (only for competition with other channels, will not pass in this FIFO)"))
        dw.append(("chn",          13,1, 0,      "channel buffer to use: 0 - memory read, 1 - memory write"))
        dw.append(("wait_complete",14,1, 0,      "Do not request a new transaction from the scheduler until previous memory transaction is finished"))
        return dw
    
    def _enc_status(self): #Generic status register
        dw=[]
        dw.append(("status24",     0, 24,0,      "24-bit status payload ([25:2] in Verilog"))
        dw.append(("status2",     24,  2,0,      "2-bit status payload (2 LSB in Verilog)"))
        dw.append(("seq_num",     26,  6,0,      "Sequence number"))
        return dw

    def _enc_status_mcntrl_phy(self):
        dw=[]
        dw.append(("ps_out",       0,  8,0,      "Current MMCM phase shift"))
        dw.append(("run_busy",     8,  1,0,      "Controller sequence in progress"))
        dw.append(("locked_pll",   9,  1,0,      "PLL is locked"))
        dw.append(("locked_mmcm", 10,  1,0,      "MMCM is locked"))
        dw.append(("dci_ready",   11,  1,0,      "DCI calibration is ready"))
        dw.append(("dly_ready",   12,  1,0,      "I/O delays calibration is ready"))
        dw.append(("ps_rdy",      24,  1,0,      "Phase change is done"))
        dw.append(("locked",      25,  1,0,      "Both PLL and MMCM are locked"))
        dw.append(("seq_num",     26,  6,0,      "Sequence number"))
        return dw

    def _enc_status_mcntrl_top(self):
        dw=[]
        dw.append(("chn_want",     0, 16,0,      "Bit mask of the channels that request memory access"))
        dw.append(("want_some",   24,  1,0,      "At least one channel requests memory access (normal priority)"))
        dw.append(("need_some",   25,  1,0,      "At least one channel requests urgent memory access (high priority)"))
        dw.append(("seq_num",     26,  6,0,      "Sequence number"))
        return dw

    def _enc_status_mcntrl_ps(self):
        dw=[]
        dw.append(("cmd_half_full",   24,  1,0,  "MCNTRL software access pending commands FIFO is half full"))
        dw.append(("cmd_nempty_busy", 25,  1,0,  "MCNTRL software access pending commands FIFO is not empty or command is running"))
        dw.append(("seq_num",         26,  6,0,  "Sequence number"))
        return dw

    def _enc_status_lintile(self): #status for memory accesses of the test channels (2,3,4)
        dw=[]
        dw.append(("busy",           24,  1,0,  "Channel is busy (started and some memory accesses are pending)"))
        dw.append(("frame_finished", 25,  1,0,  "Channel completed all memory accesses"))
        dw.append(("seq_num",        26,  6,0,  "Sequence number"))
        return dw

    def _enc_status_testchn(self): #status for the test channels (2,3,4)
        dw=[]
        dw.append(("line_unfinished", 0, 16,0,  "Current unfinished frame line"))
        dw.append(("page",           16,  4,0,  "Current page number read/written through a channel (low bits)"))
        dw.append(("frame_busy",     24,  1,0,  "Channel is busy (started and some memory accesses are pending)"))
        dw.append(("frame_finished", 25,  1,0,  "Channel completed all memory accesses"))
        dw.append(("seq_num",        26,  6,0,  "Sequence number"))
        return dw

    def _enc_status_membridge(self):
        dw=[]
        dw.append(("wresp_conf",       0, 8,0,  "Number of 64-bit words confirmed through axi b channel (low bits)"))
        dw.append(("axi_arw_requested",8, 8,0,  "Number of 64-bit words to be read/written over axi queued to AR/AW channels (low bits)"))
        dw.append(("busy",           24,  1,0,  "Membridge operation in progress"))
        dw.append(("done",           25,  1,0,  "Membridge operation finished"))
        dw.append(("seq_num",        26,  6,0,  "Sequence number"))
        return dw


    def _enc_status_sens_io(self):
        dw=[]
        dw.append(("ps_out",                 0, 8,0,  "Sensor MMCM current phase"))
        dw.append(("ps_rdy",                 8, 1,0,  "Sensor MMCM phase ready"))
        dw.append(("xfpgadone",              9, 1,0,  "Multiplexer FPGA DONE output"))
        dw.append(("clkfb_pxd_stopped_mmcm",10, 1,0,  "Sensor MMCM feedback clock stopped"))
        dw.append(("clkin_pxd_stopped_mmcm",11, 1,0,  "Sensor MMCM input clock stopped"))
        dw.append(("locked_pxd_mmcm",       12, 1,0,  "Sensor MMCM locked"))
        dw.append(("hact_alive",            13, 1,0,  "HACT signal from the sensor (or internal) is toggling (N/A for HiSPI"))
        dw.append(("hact_ext_alive",        14, 1,0,  "HACT signal from the sensor is toggling (N/A for HiSPI)"))
        dw.append(("vact_alive",            15, 1,0,  "VACT signal from the sensor is toggling (N/A for HiSPI)"))
        dw.append(("senspgmin",             24, 1,0,  "senspgm pin state"))
        dw.append(("xfpgatdo",              25, 1,0,  "Multiplexer FPGA TDO output"))
        dw.append(("seq_num",               26, 6,0,  "Sequence number"))
        return dw

    def _enc_status_sens_i2c(self):
        dw=[]
        dw.append(("i2c_fifo_dout",          0, 8,0,  "I2c byte read from the device through FIFO"))
        dw.append(("i2c_fifo_nempty",        8, 1,0,  "I2C read FIFO has data"))
        dw.append(("i2c_fifo_cntrl",         9, 1,0,  "I2C FIFO byte counter (odd/even bytes)"))
        dw.append(("busy",                  10, 1,0,  "I2C sequencer busy"))
        dw.append(("alive_fs",              11, 1,0,  "Sensor generated frame sync since last status update"))
        dw.append(("frame_num",             12, 4,0,  "I2C sequencer frame number"))
        dw.append(("req_clr",               16, 1,0,  "Request for clearing fifo_wp (delay frame sync if previous is not yet sent out)"))
        dw.append(("reset_on",              17, 1,0,  "Reset in progress"))
        dw.append(("scl_in",                24, 1,0,  "SCL pin state"))
        dw.append(("sda_in",                25, 1,0,  "SDA pin state"))
        dw.append(("seq_num",               26, 6,0,  "Sequence number"))
        return dw


    def _enc_test01_mode(self): # command for test01 module (test frame memory accesses)
        dw=[]
        dw.append(("frame_start",      0, 1,0,  "start frame command"))
        dw.append(("next_page",        1, 1,0,  "Next page command"))
        dw.append(("suspend",          2, 1,0,  "Suspend command"))
        return dw

    def _enc_membridge_cmd(self):
        dw=[]
        dw.append(("enable",           0, 1,0,  "enable membridge"))
        dw.append(("start_reset",      1, 2,0,  "1 - start (from current address), 3 - start from reset address"))
        return dw
    def _enc_membridge_mode(self):
        dw=[]
        dw.append(("axi_cache",        0, 4,3,  "AXI CACHE value (ignored by Zynq)"))
        dw.append(("debug_cache",      4, 1,0,  "0 - normal operation, 1 debug (replace data)"))
        return dw
    def _enc_u29(self):
        dw=[]
        dw.append(("addr64",           0,29,0,  "Address/length in 64-bit words (<<3 to get byte address"))
        return dw

    def _enc_i2c_tbl_addr(self):
        dw=[]
        dw.append(("tbl_addr",         0, 8,0,  "Address/length in 64-bit words (<<3 to get byte address"))
        dw.append(("tbl_mode",         vrlg.SENSI2C_CMD_TAND, 2,3,  "Should be 3 to select table address write mode"))
        return dw

    def _enc_i2c_tbl_wmode(self):
        dw=[]
        dw.append(("rah",              vrlg.SENSI2C_TBL_RAH, vrlg.SENSI2C_TBL_RAH_BITS,  0, "High byte of the i2c register address"))
        dw.append(("rnw",              vrlg.SENSI2C_TBL_RNWREG,                       1, 0, "Read/not write i2c register, should be 0 here"))
        dw.append(("sa",               vrlg.SENSI2C_TBL_SA,   vrlg.SENSI2C_TBL_SA_BITS,  0, "Slave address in write mode"))
        dw.append(("nbwr",             vrlg.SENSI2C_TBL_NBWR, vrlg.SENSI2C_TBL_NBWR_BITS,0, "Number of bytes to write (1..10)"))
        dw.append(("dly",              vrlg.SENSI2C_TBL_DLY,  vrlg.SENSI2C_TBL_DLY_BITS, 0, "Bit delay - number of mclk periods in 1/4 of the SCL period"))
        dw.append(("tbl_mode",         vrlg.SENSI2C_CMD_TAND,                         2, 2,  "Should be 2 to select table data write mode"))
        return dw

    def _enc_i2c_tbl_rmode(self):
        dw=[]
        dw.append(("rah",              vrlg.SENSI2C_TBL_RAH, vrlg.SENSI2C_TBL_RAH_BITS,  0, "High byte of the i2c register address"))
        dw.append(("rnw",              vrlg.SENSI2C_TBL_RNWREG,                       1, 0, "Read/not write i2c register, should be 1 here"))
        dw.append(("nbrd",             vrlg.SENSI2C_TBL_NBRD, vrlg.SENSI2C_TBL_NBRD_BITS,0, "Number of bytes to read (1..18, 0 means '8')"))
        dw.append(("nabrd",            vrlg.SENSI2C_TBL_NABRD,                        1, 0, "Number of address bytes for read (0 - one byte, 1 - two bytes)"))
        dw.append(("dly",              vrlg.SENSI2C_TBL_DLY,  vrlg.SENSI2C_TBL_DLY_BITS, 0, "Bit delay - number of mclk periods in 1/4 of the SCL period"))
        dw.append(("tbl_mode",         vrlg.SENSI2C_CMD_TAND,                         2, 2, "Should be 2 to select table data write mode"))
        return dw

    def _enc_i2c_ctrl(self):
        dw=[]
        dw.append(("sda_drive_high",   vrlg.SENSI2C_CMD_ACIVE_SDA,    1,0,  "Actively drive SDA high during second half of SCL==1 (valid with drive_ctl)"))
        dw.append(("sda_release",      vrlg.SENSI2C_CMD_ACIVE_EARLY0, 1,0,  "Release SDA early if next bit ==1 (valid with drive_ctl)"))
        dw.append(("drive_ctl",        vrlg.SENSI2C_CMD_ACIVE,        1,0,  "0 - nop, 1 - set sda_release and sda_drive_high"))
        dw.append(("next_fifo_rd",     vrlg.SENSI2C_CMD_FIFO_RD,      1,0,  "Advance I2C read FIFO pointer"))
        dw.append(("cmd_run",          vrlg.SENSI2C_CMD_RUN-1,        2,0,  "Sequencer run/stop control: 0,1 - nop, 2 - stop, 3 - run "))
        dw.append(("reset",            vrlg.SENSI2C_CMD_RESET,        1,0,  "Sequencer reset all FIFO (takes 16 clock pulses), also - stops i2c until run command"))
        dw.append(("tbl_mode",         vrlg.SENSI2C_CMD_TAND,         2,0,  "Should be 0 to select controls"))
        return dw

    def _enc_sens_mode(self):
        dw=[]
        dw.append(("hist_en",          vrlg.SENSOR_HIST_EN_BITS,    4,15,  "Enable subchannel histogram modules (may be less than 4)"))
        dw.append(("hist_nrst",        vrlg.SENSOR_HIST_NRST_BITS,  4,15,  "Reset off for histograms subchannels (may be less than 4)"))
        dw.append(("chn_en",           vrlg.SENSOR_CHN_EN_BIT,      1, 1,  "Enable this sensor channel"))
        dw.append(("bit16",            vrlg.SENSOR_16BIT_BIT,       1, 0,  "0 - 8 bpp mode, 1 - 16 bpp (bypass gamma). Gamma-processed data is still used for histograms"))
        return dw

    def _enc_sens_sync_mult(self):
        dw=[]
        dw.append(("mult_frames",      0, vrlg.SENS_SYNC_FBITS,   0,  "Number of frames to combine into one minus 1 (0 - single,1 - two frames...)"))
        return dw

    def _enc_sens_sync_late(self):
        dw=[]
        dw.append(("mult_frames",      0, vrlg.SENS_SYNC_LBITS,   0,  "Number of lines to delay late frame sync"))
        return dw

    def _enc_mcntrl_priorities(self):
        dw=[]
        dw.append(("priority",         0, 16,   0,  "Channel priority (the larger the higher)"))
        return dw

    def _enc_mcntrl_chnen(self):
        dw=[]
        dw.append(("chn_en",           0, 16,   0,  "Enabled memory channels"))
        return dw
    
    def _enc_mcntrl_dqs_dqm_patterns(self):
        dw=[]
        dw.append(("dqs_patt",        0,  8,   0xaa,  "DQS pattern: 0xaa/0x55"))
        dw.append(("dqm_patt",        8,  8,   0,     "DQM pattern: 0x0"))
        return dw

    def _enc_mcntrl_dqs_dq_tri(self):
        dw=[]
        dw.append(("dq_tri_first",        0,  4, 0x3,  "DQ tristate  start (0x3,0x7,0xf); early, nominal, late"))
        dw.append(("dq_tri_last",         4,  4, 0xe,  "DQ tristate  end   (0xf,0xe,0xc); early, nominal, late"))
        dw.append(("dqs_tri_first",       8,  4, 0x1,  "DQS tristate start (0x1,0x3,0x7); early, nominal, late"))
        dw.append(("dqs_tri_last",       12,  4, 0xc,  "DQS tristate end   (0xe,0xc,0x8); early, nominal, late"))
        return dw

    """
DQSTRI_LAST, DQSTRI_FIRST, DQTRI_LAST, DQTRI_FIRST    
    """

    def get_pad32(self, data, wlen=32, name="unnamed", padLast=False):
        sorted_data=sorted(data,key=lambda sbit: sbit[1])
        padded_data=[]
        next_bit = 0
        for item in sorted_data:
            lsb = item[1]
            if lsb > next_bit:
                padded_data.append(("", next_bit, lsb-next_bit, 0, ""))
            elif lsb < next_bit:
                raise Exception("Overlapping bit fields in %s, %s and %s"%(name, str(padded_data[-1]), str(item)))
            padded_data.append(item)
            next_bit = item[1]+item[2]
        if padLast and (next_bit < wlen):
            padded_data.append(("", next_bit, wlen-next_bit, 0,""))
        return padded_data        
            
            
    def get_typedef32(self, comment, data, name, frmt_spcs):
        
        """
        TODO: add alternative to bit fields 
        """
        isUnion = isinstance(data[0],list)
        frmt_spcs=self.fix_frmt_spcs(frmt_spcs)
        s = "\n"
        if comment:
            s += "// %s\n\n"%(comment)
        if isUnion:
            frmt_spcs['lastPad'] = True
            s += "typedef union {\n"
        else:
            data = [data]
        for ns,struct in enumerate(data):    
            lines=self.get_pad32(struct, wlen=32, name=name, padLast=frmt_spcs['lastPad'])
            lines.reverse()
            #nameMembers
            if isUnion:
                s += "    struct {\n"
            else:
                s += "typedef struct {\n"
            frmt= "%s    %%s %%%ds:%%2d;"%(("","    ")[isUnion], max([len(i[0]) for i in lines]+[ frmt_spcs['nameLength']]))
            for line in lines:
                s += frmt%( frmt_spcs['ftype'], line[0], line[2])
                if line[0] or  frmt_spcs['showReserved']:
                    hasComment = (len(line) > 4) and line[4]
                    if  frmt_spcs['showBits'] or  frmt_spcs['showDefaults']:
                        s+= " //"
                        if  frmt_spcs['showBits']:
                            if line[2] > 1:
                                s+= " [%2d:%2d]"%(line[1]+line[2]-1,line[1])
                            else:    
                                s+= " [   %2d]"%(line[1])
                        if  frmt_spcs['showDefaults']:
                            if line[3] < 10:
                                s += " (%d)"%(line[3])
                            else:    
                                s += " (0x%x)"%(line[3])
                        if hasComment:
                            s+=" "+line[4]
                    elif hasComment:
                        s+=" // "+line[4]
                s+="\n"
            if isUnion:
                if frmt_spcs['nameMembers']:
                    s += "    } struct_%d;\n"%(ns)
                else:
                    s += "    }; \n"
        s += "} %s_t; \n"%(name)
        return s

    def fix_frmt_spcs(self,frmt_spcs):
        specs= frmt_spcs;    
        if not specs:
            specs = {}
        for k in self.dflt_frmt_spcs:
            if not k in specs:
                specs[k] =  self.dflt_frmt_spcs[k]
        return specs         
        
            
                
        