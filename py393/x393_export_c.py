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
import os
import errno
import datetime
import vrlg
class X393ExportC(object):
    DRY_MODE =    True # True
    DEBUG_MODE =  1
    MAXI0_BASE =  0x40000000
    MAXI0_RANGE = 0x00003000
    verbose =     1
    func_decl =   None
    func_def =    None
    typedefs =    None
    gen_dir =       "generated"
    typdefs_file =  "x393_types.h" # typdef for hardware registers
    header_file =   "x393.h"       # constant definitions and function declarations
    func_def_file = "x393.c"       # functions definitions
    defs_file =     "x393_defs.h"  # alternative - constants and address definitions
    map_file =      "x393_map.h"   # address map as  defines
    
    dflt_frmt_spcs={'ftype':        'u32',
                    'showBits':     True,
                    'showDefaults': True,
                    'showReserved': False,
                    'nameLength':   15,
                    'lastPad':      False,
                    'macroNameLen': 48,
                    'showType':     True,
                    'showRange':    True,
                    'nameMembers':  False, # True, #name each struct in a union
                    'data32':       'd32', #union branch that is always u32 ("" to disable)
#                    'declare':(26,48,0, 80),  #function name, arguments, (body), comments
#                    'define': (26,48,72,106), #function name, arguments, body, comments
#                    'declare':(29,59,0, 91),  #function name, arguments, (body), comments
#                    'define': (29,59,83,117), #function name, arguments, body, comments
#                    'declare':(29,59,0, 103),  #function name, arguments, (body), comments
#                    'define': (29,59,83,127), #function name, arguments, body, comments
                    'declare':(29,65,0, 113),  #function name, arguments, (body), comments
                    'define': (29,65,85,130), #function name, arguments, body, comments
                    'body_prefix':'\n    '    #insert before function body {}
                    
                    } 

    def __init__(self, debug_mode=1,dry_mode=True, saveFileName=None):
        self.DEBUG_MODE=  debug_mode
        self.DRY_MODE=    dry_mode
        try:
            self.verbose=vrlg.VERBOSE
        except:
            pass
        
    def export_all(self):
        self.func_decl=[]
        self.func_def= []
        self.save_typedefs(self.gen_dir, self.typdefs_file)
        
        
        self.save_header_file      (self.gen_dir, self.header_file)
        self.save_func_def_file    (self.gen_dir, self.func_def_file)
        self.save_defines_file     (self.gen_dir, self.defs_file)
        self.save_harware_map_file (self.gen_dir, self.map_file)
        return "OK"
    
    def make_generated(self, path):
        try:
            os.makedirs(path)
        except OSError as exception:
            if exception.errno != errno.EEXIST:
                raise
            
    def generated_fileHeader(self, filename, description):
        header_template="""/*******************************************************************************
 * @file %s
 * @date %s  
 * @author auto-generated file, see %s
 * @brief %s
 *******************************************************************************/"""
        script_name = os.path.basename(__file__)
        if script_name[-1] == "c":
            script_name = script_name[:-1] 
        return header_template%(filename, datetime.date.today().isoformat(), script_name, description)
    def gen_ifdef(self,filename):
        macro= filename.upper().replace('.','_')
        return """#ifndef %s
#define %s        
"""%(macro,macro)
        return
        
    def save_typedefs(self, directory, filename):
        description = 'typedef definitions for the x393 hardware registers'
        header = self.generated_fileHeader(filename,description)
        txt=self.get_typedefs(frmt_spcs = None)
        self.make_generated(os.path.abspath(os.path.join(os.path.dirname(__file__), directory)))
        with open(os.path.abspath(os.path.join(os.path.dirname(__file__), directory, filename)),"w") as out_file:
            print(header,file=out_file)
            print(self.gen_ifdef(filename),file=out_file)
            print(txt,file=out_file)
            print("#endif",file=out_file)
        print ("%s are written to  to %s"%(description, os.path.abspath(os.path.join(os.path.dirname(__file__), directory, filename))))
        
    def save_header_file(self, directory, filename):
        description = 'Constants definitions and functions declarations to access x393 hardware registers'
        header = self.generated_fileHeader(filename,description)
        ld= self.define_macros()
        ld+=self.define_other_macros()
        # Includes section
        txt = '\n#include "x393_types.h"\n'
        txt +='//#include "elphel/x393_defs.h // alternative variant"\n\n'
        txt +='// See elphel/x393_map.h for the ordered list of all I/O register addresses used\n'
        txt +=  '// init_mmio_ptr() should be called once before using any of the other declared functions\n\n'
        txt +=  'int init_mmio_ptr(void);\n'
        txt += '#ifndef PARS_FRAMES\n'
        txt += '    #define PARS_FRAMES       16             ///< Number of frames in a sequencer     TODO:// move it here from <uapi/elphel/c313a.h>\n'
        txt += '    #define PARS_FRAMES_MASK (PARS_FRAMES-1) ///< Maximal frame number (15 for NC393) TODO:// move it here from <uapi/elphel/c313a.h>\n'
        txt += '#endif\n'
        txt += 'typedef enum {TABLE_TYPE_QUANT,TABLE_TYPE_CORING,TABLE_TYPE_FOCUS,TABLE_TYPE_HUFFMAN} x393cmprs_tables_t; ///< compressor table type\n'
        txt += 'typedef enum {DIRECT,ABSOLUTE,RELATIVE,ASAP} x393cmd_t; ///< How to apply command - directly or through the command sequencer\n'
        txt += """// IRQ commands applicable to several targets
#define X393_IRQ_NOP     0 
#define X393_IRQ_RESET   1
#define X393_IRQ_DISABLE 2
#define X393_IRQ_ENABLE  3
"""        
        for d in ld:
            fd=self.expand_define_maxi0(d, mode = "func_decl",frmt_spcs = None)
            if fd:
                txt += fd + "\n"
        self.make_generated(os.path.abspath(os.path.join(os.path.dirname(__file__), directory)))
        with open(os.path.abspath(os.path.join(os.path.dirname(__file__), directory, filename)),"w") as out_file:
            print(header,file=out_file)
            print(self.gen_ifdef(filename),file=out_file)
            print(txt,file=out_file)
            print("#endif",file=out_file)
            
        print ("%s are written to  to %s"%(description, os.path.abspath(os.path.join(os.path.dirname(__file__), directory, filename))))
        
    def save_func_def_file(self, directory, filename):
        description = 'Functions definitions to access x393 hardware registers'
        header = self.generated_fileHeader(filename,description)
        ld= self.define_macros()
        ld+=self.define_other_macros()
        # Includes section
        txt  = '\n#include <linux/io.h>\n'
        txt += '#include <linux/spinlock.h>\n'
        txt +=  '#include "x393.h"\n\n'
        txt +=  'static void __iomem* mmio_ptr;\n\n'
        txt +=  'static DEFINE_SPINLOCK(lock);\n\n'
        txt +=  '// init_mmio_ptr() should be called once before using any of the other defined functions\n\n'
        txt +=  'int init_mmio_ptr(void) {mmio_ptr = ioremap(0x%08x, 0x%08x); if (!mmio_ptr) return -1; else return 0;}\n'%(self.MAXI0_BASE,self.MAXI0_RANGE)

        for d in ld:
            fd=self.expand_define_maxi0(d, mode = "func_def",frmt_spcs = None)
            if fd:
                txt += fd + "\n"
        self.make_generated(os.path.abspath(os.path.join(os.path.dirname(__file__), directory)))
        with open(os.path.abspath(os.path.join(os.path.dirname(__file__), directory, filename)),"w") as out_file:
            print(header,file=out_file)
            print(txt,file=out_file)
        print ("%s are written to  to %s"%(description, os.path.abspath(os.path.join(os.path.dirname(__file__), directory, filename))))

    def save_defines_file(self, directory, filename):
        description = 'Constants and hardware addresses definitions to access x393 hardware registers'
        header = self.generated_fileHeader(filename,description)
        ld= self.define_macros()
        ld+=self.define_other_macros()
        txt = ""
        for d in ld:
            fd=self.expand_define_maxi0(d, mode = "defines",frmt_spcs = None)
            if fd:
                txt += fd + "\n"
        self.make_generated(os.path.abspath(os.path.join(os.path.dirname(__file__), directory)))
        with open(os.path.abspath(os.path.join(os.path.dirname(__file__), directory, filename)),"w") as out_file:
            print(header,file=out_file)
            print(self.gen_ifdef(filename),file=out_file)
            print(txt,file=out_file)
            print("#endif",file=out_file)
            
        print ("%s are written to  to %s"%(description, os.path.abspath(os.path.join(os.path.dirname(__file__), directory, filename))))
 
    def save_harware_map_file(self, directory, filename):
        description = 'Sorted hardware addresses map'
        header = self.generated_fileHeader(filename,description)
        ld= self.define_macros()
        ld+=self.define_other_macros()
        sam = self.expand_define_parameters(ld)
        txt = ""
        for d in sam:
#            print(self.expand_define_maxi0(d, mode = "defines", frmt_spcs = None))
            fd=self.expand_define_maxi0(d, mode = "defines",frmt_spcs = None)
            if fd:
                txt += fd + "\n"
        self.make_generated(os.path.abspath(os.path.join(os.path.dirname(__file__), directory)))
        with open(os.path.abspath(os.path.join(os.path.dirname(__file__), directory, filename)),"w") as out_file:
            print(header,file=out_file)
            print(self.gen_ifdef(filename),file=out_file)
            print(txt,file=out_file)
            print("#endif",file=out_file)
            
        print ("%s is written to  to %s"%(description, os.path.abspath(os.path.join(os.path.dirname(__file__), directory, filename))))
 
    def get_typedefs(self, frmt_spcs = None):
#        print("Will list bitfields typedef and comments")
        self.typedefs={}
        self.typedefs['u32']= {'comment':'unsigned 32-bit', 'code':'', 'size':32, 'type':''}
        stypedefs = ""
        
        stypedefs += self.get_typedef32(comment =   "Status generation control ",
                                 data =      self._enc_status_control(),
                                 name =      "x393_status_ctrl",  typ="rw",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Memory channel operation mode",
                                 data =      self._enc_func_encode_mode_scan_tiled(),
                                 name =      "x393_mcntrl_mode_scan",  typ="wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Memory channel window tile size/step (tiled only)",
                                 data =      self._enc_window_tile_whs(),
                                 name =      "x393_mcntrl_window_tile_whs",  typ="wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Memory channel window size",
                                 data =      self._enc_window_wh(),
                                 name =      "x393_mcntrl_window_width_height",  typ="wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Memory channel window position",
                                 data =      self._enc_window_lt(),
                                 name =      "x393_mcntrl_window_left_top",  typ="wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Memory channel scan start (debug feature)",
                                 data =      self._enc_window_sxy(),
                                 name =      "x393_mcntrl_window_startx_starty",  typ="wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Memory channel window full (padded) width",
                                 data =      self._enc_window_fw(),
                                 name =      "x393_mcntrl_window_full_width",  typ="wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Memory channel last frame number in a buffer (number of frames minus 1)",
                                 data =      self._enc_window_last_frame_number(),
                                 name =      "x393_mcntrl_window_last_frame_num",  typ="wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Memory channel frame start address increment (for next frame in a buffer)",
                                 data =      self._enc_window_frame_sa_inc(),
                                 name =      "x393_mcntrl_window_frame_sa_inc",  typ="wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Memory channel frame start address for the first frame in a buffer",
                                 data =      self._enc_window_frame_sa(),
                                 name =      "x393_mcntrl_window_frame_sa",  typ="wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Delay start of the channel from sensor frame sync (to allow frame sequencer issue commands)",
                                 data =      self._enc_frame_start_dly(),
                                 name =      "x393_mcntrl_frame_start_dly",  typ="wo",
                                 frmt_spcs = frmt_spcs)
        
        stypedefs += self.get_typedef32(comment =   "PS PIO (software-programmed DDR3) access sequences enable and reset",
                                 data =      self._enc_ps_pio_en_rst(),
                                 name =      "x393_ps_pio_en_rst",  typ="wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "PS PIO (software-programmed DDR3) access sequences control",
                                 data =      self._enc_ps_pio_cmd(),
                                 name =      "x393_ps_pio_cmd",  typ="wo",
                                 frmt_spcs = frmt_spcs)

        stypedefs += self.get_typedef32(comment =   "x393 generic status register",
                                 data =      self._enc_status(),
                                 name =      "x393_status",  typ="ro",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Memory PHY status",
                                 data =      self._enc_status_mcntrl_phy(),
                                 name =      "x393_status_mcntrl_phy",  typ="ro",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Memory controller requests status",
                                 data =      self._enc_status_mcntrl_top(),
                                 name =      "x393_status_mcntrl_top",  typ="ro",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Memory software access status",
                                 data =      self._enc_status_mcntrl_ps(),
                                 name =      "x393_status_mcntrl_ps",  typ="ro",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Memory test channels access status",
                                 data =      self._enc_status_lintile(),
                                 name =      "x393_status_mcntrl_lintile",  typ="ro",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Memory test channels status",
                                 data =      self._enc_status_testchn(),
                                 name =      "x393_status_mcntrl_testchn",  typ="ro",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Membridge channel status",
                                 data =      self._enc_status_membridge(),
                                 name =      "x393_status_membridge",  typ="ro",
                                 frmt_spcs = frmt_spcs)
        
        stypedefs += self.get_typedef32(comment =   "Sensor/multiplexer I/O pins status",
                                 data =      self._enc_status_sens_io(),
                                 name =      "x393_status_sens_io",  typ="ro",
                                 frmt_spcs = frmt_spcs)

        stypedefs += self.get_typedef32(comment =   "Sensor/multiplexer i2c status",
                                 data =      self._enc_status_sens_i2c(),
                                 name =      "x393_status_sens_i2c",  typ="ro",
                                 frmt_spcs = frmt_spcs)

        stypedefs += self.get_typedef32(comment =   "Command bits for test01 module (test frame memory accesses)",
                                 data =      self._enc_test01_mode(),
                                 name =      "x393_test01_mode",  typ="wo",
                                 frmt_spcs = frmt_spcs)

        stypedefs += self.get_typedef32(comment =   "Command for membridge",
                                 data =      self._enc_membridge_cmd(),
                                 name =      "x393_membridge_cmd",  typ="wo",
                                 frmt_spcs = frmt_spcs)
        """
        stypedefs += self.get_typedef32(comment =   "Cache mode for membridge",
                                 data =      self._enc_membridge_mode(),
                                 name =      "x393_membridge_mode",  typ="wo",
                                 frmt_spcs = frmt_spcs)
        """                                 
        stypedefs += self.get_typedef32(comment =   "Interrupt handling commands for Membridge module",
                                 data =      self._enc_membridge_ctrl_irq(),
                                 name =      "x393_membridge_ctrl_irq",  typ="wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Address in 64-bit words",
                                 data =      self._enc_u29(),
                                 name =      "u29",  typ="wo",
                                 frmt_spcs = frmt_spcs)
        
        stypedefs += self.get_typedef32(comment =   "I2C contol/table data",
                                 data =      [self._enc_i2c_tbl_addr(), # generate typedef union
                                              self._enc_i2c_tbl_wmode(),
                                              self._enc_i2c_tbl_rmode(),
                                              self._enc_i2c_ctrl()],
                                 name =      "x393_i2c_ctltbl",  typ="wo",
                                 frmt_spcs = frmt_spcs)
        
        stypedefs += self.get_typedef32(comment =   "Write sensor channel mode register",
                                 data =      self._enc_sens_mode(),
                                 name =      "x393_sens_mode",  typ="wo",
                                 frmt_spcs = frmt_spcs)

        stypedefs += self.get_typedef32(comment =   "Write number of sensor frames to combine into one virtual (linescan mode)",
                                 data =      self._enc_sens_sync_mult(),
                                 name =      "x393_sens_sync_mult",  typ="wo",
                                 frmt_spcs = frmt_spcs)

        stypedefs += self.get_typedef32(comment =   "Write sensor number of lines to delay frame sync",
                                 data =      self._enc_sens_sync_late(),
                                 name =      "x393_sens_sync_late",  typ="wo",
                                 frmt_spcs = frmt_spcs)

        stypedefs += self.get_typedef32(comment =   "Configure memory controller priorities",
                                 data =      self._enc_mcntrl_priorities(),
                                 name =      "x393_arbiter_pri",  typ="rw",
                                 frmt_spcs = frmt_spcs)

        stypedefs += self.get_typedef32(comment =   "Enable/disable memory controller channels",
                                 data =      self._enc_mcntrl_chnen(),
                                 name =      "x393_mcntr_chn_en",  typ="rw",
                                 frmt_spcs = frmt_spcs)
        
        stypedefs += self.get_typedef32(comment =   "DQS and DQM patterns (DQM - 0, DQS 0xaa or 0x55)",
                                 data =      self._enc_mcntrl_dqs_dqm_patterns(),
                                 name =      "x393_mcntr_dqs_dqm_patt",  typ="rw",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "DQ and DQS tristate control when turning on and off",
                                 data =      self._enc_mcntrl_dqs_dq_tri(),
                                 name =      "x393_mcntr_dqs_dqm_tri",  typ="rw",
                                 frmt_spcs = frmt_spcs)
        
        stypedefs += self.get_typedef32(comment =   "DDR3 memory controller I/O delay",
                                 data =      self._enc_mcntrl_dly(),
                                 name =      "x393_dly",  typ="rw",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Extra delay in mclk (fDDR/2) cycles) to data write buffer",
                                 data =      self._enc_wbuf_dly(),
                                 name =      "x393_wbuf_dly",  typ="rw",
                                 frmt_spcs = frmt_spcs)
        
        stypedefs += self.get_typedef32(comment =   "Control for the gamma-conversion module",
                                 data =      self._enc_gamma_ctl(),
                                 name =      "x393_gamma_ctl",  typ="rw",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Write gamma table address/data",
                                 data =      [self._enc_gamma_tbl_addr(), # generate typedef union
                                              self._enc_gamma_tbl_data()],
                                 name =      "x393_gamma_tbl",  typ="wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Heights of the first two subchannels frames",
                                 data =      self._enc_gamma_height01(),
                                 name =      "x393_gamma_height01m1",  typ="rw",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Height of the third subchannel frame",
                                 data =      self._enc_gamma_height2(),
                                 name =      "x393_gamma_height2m1",  typ="rw",
                                 frmt_spcs = frmt_spcs)
        
        stypedefs += self.get_typedef32(comment =   "Sensor port I/O control",
                                 data =      [self._enc_sensio_ctrl_par12(),
                                              self._enc_sensio_ctrl_hispi()],
                                 name =      "x393_sensio_ctl",  typ="wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Programming interface for multiplexer FPGA",
                                 data =      self._enc_sensio_jtag(),
                                 name =      "x393_sensio_jtag",  typ="wo",
                                 frmt_spcs = frmt_spcs)
        """
        stypedefs += self.get_typedef32(comment =   "Sensor delays (uses 4 DWORDs)",
                                 data =      [self._enc_sensio_dly_par12(),
                                              self._enc_sensio_dly_hispi()],
                                 name =      "x393_sensio_dly",  typ="rw",
                                 frmt_spcs = frmt_spcs)
        """                                 
        stypedefs += self.get_typedef32(comment =   "Sensor i/o timing register 0 (different meanings for different sensor types)",
                                 data =      [self._enc_sensio_par12_tim0(),
                                              self._enc_sensio_hispi_tim0()],
                                 name =      "x393_sensio_tim0",  typ="rw",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Sensor i/o timing register 1 (different meanings for different sensor types)",
                                 data =      [self._enc_sensio_par12_tim1(),
                                              self._enc_sensio_hispi_tim1()],
                                 name =      "x393_sensio_tim1",  typ="rw",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Sensor i/o timing register 2 (different meanings for different sensor types)",
                                 data =      [self._enc_sensio_par12_tim2(),
                                              self._enc_sensio_hispi_tim2()],
                                 name =      "x393_sensio_tim2",  typ="rw",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Sensor i/o timing register 3 (different meanings for different sensor types)",
                                 data =      [self._enc_sensio_par12_tim3(),
                                              self._enc_sensio_hispi_tim3()],
                                 name =      "x393_sensio_tim3",  typ="rw",
                                 frmt_spcs = frmt_spcs)

        stypedefs += self.get_typedef32(comment =   "Set sensor frame width (0 - use received)",
                                 data =      self._enc_sensio_width(),
                                 name =      "x393_sensio_width",  typ="rw",
                                 frmt_spcs = frmt_spcs)

        stypedefs += self.get_typedef32(comment =   "Lens vignetting parameter (write address first, then data that may overlap som address bits)",
                                 data =      [self._enc_lens_addr(),
                                              self._enc_lens_ax(),
                                              self._enc_lens_ay(),
                                              self._enc_lens_bx(),
                                              self._enc_lens_by(),
                                              self._enc_lens_c(),
                                              self._enc_lens_scale(),
                                              self._enc_lens_fatzero_in(),
                                              self._enc_lens_fatzero_out(),
                                              self._enc_lens_post_scale()],
                                 name =      "x393_lens_corr",  typ="wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Height of the subchannel frame for vignetting correction",
                                 data =      self._enc_lens_height_m1(),
                                 name =      "x393_lens_height_m1",  typ="rw",
                                 frmt_spcs = frmt_spcs)

        stypedefs += self.get_typedef32(comment =   "Histogram window left/top margins",
                                 data =      self._enc_histogram_lt(),
                                 name =      "x393_hist_left_top",  typ="rw",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Histogram window width and height minus 1 (0 use full)",
                                 data =      self._enc_histogram_wh_m1(),
                                 name =      "x393_hist_width_height_m1",  typ="rw",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Histograms DMA mode",
                                 data =      self._enc_hist_saxi_mode(),
                                 name =      "x393_hist_saxi_mode",  typ="rw",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Histograms DMA addresses",
                                 data =      self._enc_hist_saxi_page_addr(),
                                 name =      "x393_hist_saxi_addr",  typ="rw",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Compressor mode control",
                                 data =      self._enc_cmprs_mode(),
                                 name =      "x393_cmprs_mode",  typ="rw", # to read back last written
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Compressor coring mode (table number)",
                                 data =      self._enc_cmprs_coring_sel(),
                                 name =      "x393_cmprs_coring_mode",  typ="rw",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Compressor color saturation",
                                 data =      self._enc_cmprs_color_sat(),
                                 name =      "x393_cmprs_colorsat",  typ="rw",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Compressor frame format",
                                 data =      self._enc_cmprs_format(),
                                 name =      "x393_cmprs_frame_format",  typ="rw",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Compressor interrupts control",
                                 data =      self._enc_cmprs_interrupts(),
                                 name =      "x393_cmprs_interrupts",  typ="wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Compressor tables load control",
                                 data =      self._enc_cmprs_table_addr(),
                                 name =      "x393_cmprs_table_addr",  typ="wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Compressor channel status",
                                 data =      self._enc_cmprs_status(),
                                 name =      "x393_cmprs_status",  typ="ro",
                                 frmt_spcs = frmt_spcs)

        stypedefs += self.get_typedef32(comment =   "Compressor DMA buffer address (in 32-byte blocks)",
                                 data =      self._enc_cmprs_afimux_sa(),
                                 name =      "x393_afimux_sa",  typ="rw",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Compressor DMA buffer length (in 32-byte blocks)",
                                 data =      self._enc_cmprs_afimux_len(),
                                 name =      "x393_afimux_len", typ="rw",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Compressor DMA channels reset",
                                 data =      self._enc_cmprs_afimux_rst(),
                                 name =      "x393_afimux_rst", typ="rw",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Compressor DMA enable (global and channels)",
                                 data =      self._enc_cmprs_afimux_en(),
                                 name =      "x393_afimux_en", typ="wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Compressor DMA report mode",
                                 data =      self._enc_cmprs_afimux_report(),
                                 name =      "x393_afimux_report", typ="wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Compressor DMA status",
                                 data =      self._enc_cmprs_afimux_status(),
                                 name =      "x393_afimux_status", typ="ro",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "GPIO output control",
                                 data =      self._enc_cmprs_gpio_out(),
                                 name =      "x393_gpio_set_pins", typ="wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "GPIO pins status",
                                 data =      self._enc_cmprs_gpio_status(),
                                 name =      "x393_gpio_status", typ="ro",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "RTC seconds",
                                 data =      self._enc_rtc_sec(),
                                 name =      "x393_rtc_sec", typ="rw",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "RTC microseconds",
                                 data =      self._enc_rtc_usec(),
                                 name =      "x393_rtc_usec", typ="rw",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "RTC correction",
                                 data =      self._enc_rtc_corr(),
                                 name =      "x393_rtc_corr", typ="rw",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "RTC status",
                                 data =      self._enc_rtc_status(),
                                 name =      "x393_rtc_status", typ="ro",
                                 frmt_spcs = frmt_spcs)

        stypedefs += self.get_typedef32(comment =   "CAMSYNC I/O configuration",
                                 data =      self._enc_camsync_lines(),
                                 name =      "x393_camsync_io", typ="wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "CAMSYNC mode",
                                 data =      self._enc_camsync_mode(),
                                 name =      "x393_camsync_mode", typ="wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "CMDFRAMESEQ mode",
                                 data =      self._enc_cmdframeseq_mode(),
                                 name =      "x393_cmdframeseq_mode", typ="wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "CMDFRAMESEQ mode",
                                 data =      self._enc_cmdseqmux_status(),
                                 name =      "x393_cmdseqmux_status", typ="ro",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Event logger status",
                                 data =      self._enc_logger_status(),
                                 name =      "x393_logger_status", typ="ro",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Event logger register address",
                                 data =      self._enc_logger_reg_addr(),
                                 name =      "x393_logger_address", typ="wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "Event logger register data",
                                 data =      [self._enc_logger_conf(),
                                              self._enc_logger_data()],
                                 name =      "x393_logger_data", typ="wo",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "MULT_SAXI DMA addresses/lengths in 32-bit DWORDS",
                                 data =      self._enc_mult_saxi_addr(),
                                 name =      "x393_mult_saxi_al", typ="rw", # some - wo, others - ro
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "MULT_SAXI DMA DW address bit to change for interrupt to be generated",
                                 data =      self._enc_mult_saxi_irqlen(),
                                 name =      "x393_mult_saxi_irqlen", typ="rw", # some - wo, others - ro
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "MULT_SAXI DMA mode register (per channel enable/run)",
                                 data =      self._enc_mult_saxi_mode(),
                                 name =      "x393_mult_saxi_mode", typ="rw", # some - wo, others - ro
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "MULT_SAXI per-channel interrupt control",
                                 data =      self._enc_mult_saxi_interrupts(),
                                 name =      "x393_mult_saxi_interrupts", typ="wo", # some - wo, others - ro
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "MULT_SAXI interrupt status",
                                 data =      self._enc_mult_saxi_status(),
                                 name =      "x393_mult_saxi_status", typ="ro",
                                 frmt_spcs = frmt_spcs)

        stypedefs += self.get_typedef32(comment =   "MULTICLK reset/power down controls",
                                 data =      self._enc_multiclk_ctl(),
                                 name =      "x393_multiclk_ctl", typ="rw",
                                 frmt_spcs = frmt_spcs)
        stypedefs += self.get_typedef32(comment =   "MULTICLK status",
                                 data =      self._enc_multiclk_status(),
                                 name =      "x393_multiclk_status", typ="ro",
                                 frmt_spcs = frmt_spcs)

        stypedefs += self.get_typedef32(comment =   "DEBUG status",
                                 data =      self._enc_debug_status(),
                                 name =      "x393_debug_status", typ="ro",
                                 frmt_spcs = frmt_spcs)
        
        return stypedefs
    
    def define_macros(self):
        #memory arbiter priorities
        ba = vrlg.CONTROL_ADDR
        z3= (0,3)
        z7 = (0,7)
        z14= (0,14)
        z15= (0,15)
        z31= (0,31)
        ia = 1
        c = "chn"
        sdefines = []
        sdefines +=[
            (('R/W addresses to set up memory arbiter priorities. For sensors  (chn = 8..11), for compressors - 12..15',)),
            (("X393_MCNTRL_ARBITER_PRIORITY",              c, vrlg.MCONTR_ARBIT_ADDR +             ba, ia, z15, "x393_arbiter_pri", "rw",                "Set memory arbiter priority (currently r/w, may become just wo)"))]        

        sdefines +=[
            (('Enable/disable memory channels (bits in a 16-bit word). For sensors  (chn = 8..11), for compressors - 12..15',)),
            (("X393_MCNTRL_CHN_EN",     c, vrlg.MCONTR_TOP_16BIT_ADDR +  vrlg.MCONTR_TOP_16BIT_CHN_EN +    ba,     0, None, "x393_mcntr_chn_en", "rw",   "Enable/disable memory channels (currently r/w, may become just wo)")),
            (("X393_MCNTRL_DQS_DQM_PATT",c, vrlg.MCONTR_PHY_16BIT_ADDR+  vrlg.MCONTR_PHY_16BIT_PATTERNS +  ba,     0, None, "x393_mcntr_dqs_dqm_patt", "rw",     "Setup DQS and DQM patterns")),
            (("X393_MCNTRL_DQ_DQS_TRI", c, vrlg.MCONTR_PHY_16BIT_ADDR +  vrlg.MCONTR_PHY_16BIT_PATTERNS_TRI+ ba,   0, None, "x393_mcntr_dqs_dqm_tri", "rw",      "Setup DQS and DQ on/off sequence")),
            (("Following enable/disable addresses can be written with any data, only addresses matter",)),
            (("X393_MCNTRL_DIS",        c, vrlg.MCONTR_TOP_0BIT_ADDR +   vrlg.MCONTR_TOP_0BIT_MCONTR_EN +  ba + 0, 0, None, "","",                       "Disable DDR3 memory controller")),        
            (("X393_MCNTRL_EN",         c, vrlg.MCONTR_TOP_0BIT_ADDR +   vrlg.MCONTR_TOP_0BIT_MCONTR_EN +  ba + 1, 0, None, "","",                       "Enable DDR3 memory controller")),        
            (("X393_MCNTRL_REFRESH_DIS",c, vrlg.MCONTR_TOP_0BIT_ADDR +   vrlg.MCONTR_TOP_0BIT_REFRESH_EN + ba + 0, 0, None, "","",                       "Disable DDR3 memory refresh")),        
            (("X393_MCNTRL_REFRESH_EN", c, vrlg.MCONTR_TOP_0BIT_ADDR +   vrlg.MCONTR_TOP_0BIT_REFRESH_EN + ba + 1, 0, None, "","",                       "Enable DDR3 memory refresh")),        
            (("X393_MCNTRL_SDRST_DIS",  c, vrlg.MCONTR_PHY_0BIT_ADDR +   vrlg.MCONTR_PHY_0BIT_SDRST_ACT +  ba + 0, 0, None, "","",                       "Disable DDR3 memory reset")),        
            (("X393_MCNTRL_SDRST_EN",   c, vrlg.MCONTR_PHY_0BIT_ADDR +   vrlg.MCONTR_PHY_0BIT_SDRST_ACT +  ba + 1, 0, None, "","",                       "Enable DDR3 memory reset")),        
            (("X393_MCNTRL_CKE_DIS",    c, vrlg.MCONTR_PHY_0BIT_ADDR +   vrlg.MCONTR_PHY_0BIT_CKE_EN +     ba + 0, 0, None, "","",                       "Disable DDR3 memory CKE")),        
            (("X393_MCNTRL_CKE_EN",     c, vrlg.MCONTR_PHY_0BIT_ADDR +   vrlg.MCONTR_PHY_0BIT_CKE_EN +     ba + 1, 0, None, "","",                       "Enable DDR3 memory CKE")),        
            (("X393_MCNTRL_CMDA_DIS",   c, vrlg.MCONTR_PHY_0BIT_ADDR +   vrlg.MCONTR_PHY_0BIT_CMDA_EN +    ba + 0, 0, None, "","",                       "Disable DDR3 memory command/address lines")),        
            (("X393_MCNTRL_CMDA_EN",    c, vrlg.MCONTR_PHY_0BIT_ADDR +   vrlg.MCONTR_PHY_0BIT_CMDA_EN +    ba + 1, 0, None, "","",                       "Enable DDR3 memory command/address lines")),        
            ]        
        ba = vrlg.CONTROL_ADDR
        #"x393_dly_rw"
        sdefines +=[
            (('Set DDR3 memory controller I/O delays and other timing parameters (should use individually calibrated values)',)),
            (("X393_MCNTRL_DQ_ODLY0",   c, vrlg.LD_DLY_LANE0_ODELAY +    ba,     1, z7,   "x393_dly", "rw",    "Lane0 DQ output delays ")),
            (("X393_MCNTRL_DQ_ODLY1",   c, vrlg.LD_DLY_LANE1_ODELAY +    ba,     1, z7,   "x393_dly", "rw",    "Lane1 DQ output delays ")),
            (("X393_MCNTRL_DQ_IDLY0",   c, vrlg.LD_DLY_LANE0_IDELAY +    ba,     1, z7,   "x393_dly", "rw",    "Lane0 DQ input delays ")),
            (("X393_MCNTRL_DQ_IDLY1",   c, vrlg.LD_DLY_LANE1_IDELAY +    ba,     1, z7,   "x393_dly", "rw",    "Lane1 DQ input delays ")),
            (("X393_MCNTRL_DQS_ODLY0",  c, vrlg.LD_DLY_LANE0_ODELAY +    ba + 8, 0, None, "x393_dly", "rw",    "Lane0 DQS output delay ")),
            (("X393_MCNTRL_DQS_ODLY1",  c, vrlg.LD_DLY_LANE1_ODELAY +    ba + 8, 0, None, "x393_dly", "rw",    "Lane1 DQS output delay ")),
            (("X393_MCNTRL_DQS_IDLY0",  c, vrlg.LD_DLY_LANE0_IDELAY +    ba + 8, 0, None, "x393_dly", "rw",    "Lane0 DQS input delay ")),
            (("X393_MCNTRL_DQS_IDLY1",  c, vrlg.LD_DLY_LANE1_IDELAY +    ba + 8, 0, None, "x393_dly", "rw",    "Lane1 DQS input delay ")),
            (("X393_MCNTRL_DM_ODLY0",   c, vrlg.LD_DLY_LANE0_ODELAY +    ba + 9, 0, None, "x393_dly", "rw",    "Lane0 DM output delay ")),
            (("X393_MCNTRL_DM_ODLY1",   c, vrlg.LD_DLY_LANE1_ODELAY +    ba + 9, 0, None, "x393_dly", "rw",    "Lane1 DM output delay ")),
            (("X393_MCNTRL_CMDA_ODLY",  c, vrlg.LD_DLY_CMDA +            ba,     1, z31,  "x393_dly", "rw",    "Address, bank and commands delays")),
            (("X393_MCNTRL_PHASE",      c, vrlg.LD_DLY_PHASE +           ba,     0, None, "x393_dly", "rw",    "Clock phase")),
            (("X393_MCNTRL_DLY_SET",    c, vrlg.MCONTR_PHY_0BIT_ADDR +   vrlg.MCONTR_PHY_0BIT_DLY_SET +      ba, 0, None, "", "",             "Set all pre-programmed delays")),
            (("X393_MCNTRL_WBUF_DLY",   c, vrlg.MCONTR_PHY_16BIT_ADDR +  vrlg.MCONTR_PHY_16BIT_WBUF_DELAY +  ba, 0, None, "x393_wbuf_dly", "rw", "Set write buffer delay")),
            ]        
        ba = vrlg.MCONTR_SENS_BASE
        ia = vrlg.MCONTR_SENS_INC
        c = "chn"
        sdefines +=[
            (('Write-only addresses to program memory channels for sensors  (chn = 0..3), memory channels 8..11',)),
            (("X393_SENS_MCNTRL_SCANLINE_MODE",            c, vrlg.MCNTRL_SCANLINE_MODE +             ba, ia, z3, "x393_mcntrl_mode_scan", "wo",             "Set mode register (write last after other channel registers are set)")),
            (("X393_SENS_MCNTRL_SCANLINE_STATUS_CNTRL",    c, vrlg.MCNTRL_SCANLINE_STATUS_CNTRL +     ba, ia, z3, "x393_status_ctrl", "rw",                  "Set status control register (status update mode)")),
            (("X393_SENS_MCNTRL_SCANLINE_STARTADDR",       c, vrlg.MCNTRL_SCANLINE_STARTADDR +        ba, ia, z3, "x393_mcntrl_window_frame_sa", "wo",       "Set frame start address")),
            (("X393_SENS_MCNTRL_SCANLINE_FRAME_SIZE",      c, vrlg.MCNTRL_SCANLINE_FRAME_SIZE +       ba, ia, z3, "x393_mcntrl_window_frame_sa_inc", "wo",   "Set frame size (address increment)")),
            (("X393_SENS_MCNTRL_SCANLINE_FRAME_LAST",      c, vrlg.MCNTRL_SCANLINE_FRAME_LAST +       ba, ia, z3, "x393_mcntrl_window_last_frame_num", "wo", "Set last frame number (number of frames in buffer minus 1)")),
            (("X393_SENS_MCNTRL_SCANLINE_FRAME_FULL_WIDTH",c, vrlg.MCNTRL_SCANLINE_FRAME_FULL_WIDTH + ba, ia, z3, "x393_mcntrl_window_full_width", "wo",     "Set frame full(padded) width")),
            (("X393_SENS_MCNTRL_SCANLINE_WINDOW_WH",       c, vrlg.MCNTRL_SCANLINE_WINDOW_WH +        ba, ia, z3, "x393_mcntrl_window_width_height", "wo",   "Set frame window size")),
            (("X393_SENS_MCNTRL_SCANLINE_WINDOW_X0Y0",     c, vrlg.MCNTRL_SCANLINE_WINDOW_X0Y0 +      ba, ia, z3, "x393_mcntrl_window_left_top", "wo",       "Set frame position")),
            (("X393_SENS_MCNTRL_SCANLINE_STARTXY",         c, vrlg.MCNTRL_SCANLINE_WINDOW_STARTXY +   ba, ia, z3, "x393_mcntrl_window_startx_starty", "wo",  "Set startXY register")),
            (("X393_SENS_MCNTRL_SCANLINE_START_DELAY",     c, vrlg.MCNTRL_SCANLINE_START_DELAY +      ba, ia, z3, "x393_mcntrl_frame_start_dly", "wo",       "Set dDelay start of the channel from sensor frame sync"))]
        ba = vrlg.MCONTR_CMPRS_BASE
        ia = vrlg.MCONTR_CMPRS_INC
        sdefines +=[
            (('Write-only addresses to program memory channels for compressors (chn = 0..3), memory channels 12..15',)),
            (("X393_SENS_MCNTRL_TILED_MODE",               c, vrlg.MCNTRL_TILED_MODE +                ba, ia, z3, "x393_mcntrl_mode_scan", "wo",             "Set mode register (write last after other channel registers are set)")),
            (("X393_SENS_MCNTRL_TILED_STATUS_CNTRL",       c, vrlg.MCNTRL_TILED_STATUS_CNTRL +        ba, ia, z3, "x393_status_ctrl", "rw",                  "Set status control register (status update mode)")),
            (("X393_SENS_MCNTRL_TILED_STARTADDR",          c, vrlg.MCNTRL_TILED_STARTADDR +           ba, ia, z3, "x393_mcntrl_window_frame_sa", "wo",       "Set frame start address")),
            (("X393_SENS_MCNTRL_TILED_FRAME_SIZE",         c, vrlg.MCNTRL_TILED_FRAME_SIZE +          ba, ia, z3, "x393_mcntrl_window_frame_sa_inc", "wo",   "Set frame size (address increment)")),
            (("X393_SENS_MCNTRL_TILED_FRAME_LAST",         c, vrlg.MCNTRL_TILED_FRAME_LAST +          ba, ia, z3, "x393_mcntrl_window_last_frame_num", "wo", "Set last frame number (number of frames in buffer minus 1)")),
            (("X393_SENS_MCNTRL_TILED_FRAME_FULL_WIDTH",   c, vrlg.MCNTRL_TILED_FRAME_FULL_WIDTH +    ba, ia, z3, "x393_mcntrl_window_full_width", "wo",     "Set frame full(padded) width")),
            (("X393_SENS_MCNTRL_TILED_WINDOW_WH",          c, vrlg.MCNTRL_TILED_WINDOW_WH +           ba, ia, z3, "x393_mcntrl_window_width_height", "wo",   "Set frame window size")),
            (("X393_SENS_MCNTRL_TILED_WINDOW_X0Y0",        c, vrlg.MCNTRL_TILED_WINDOW_X0Y0 +         ba, ia, z3, "x393_mcntrl_window_left_top", "wo",       "Set frame position")),
            (("X393_SENS_MCNTRL_TILED_STARTXY",            c, vrlg.MCNTRL_TILED_WINDOW_STARTXY +      ba, ia, z3, "x393_mcntrl_window_startx_starty", "wo",  "Set startXY register")),
            (("X393_SENS_MCNTRL_TILED_TILE_WHS",           c, vrlg.MCNTRL_TILED_TILE_WHS +            ba, ia, z3, "x393_mcntrl_window_tile_whs", "wo",       "Set tile size/step (tiled mode only)"))]

        ba = vrlg.MCNTRL_SCANLINE_CHN1_ADDR
        ia = 0
        c =  ""
        sdefines +=[
            (('Write-only addresses to program memory channel for membridge, memory channel 1',)),
            (("X393_MEMBRIDGE_SCANLINE_MODE",            c, vrlg.MCNTRL_SCANLINE_MODE +             ba, 0, None, "x393_mcntrl_mode_scan", "wo",             "Set mode register (write last after other channel registers are set)")),
            (("X393_MEMBRIDGE_SCANLINE_STATUS_CNTRL",    c, vrlg.MCNTRL_SCANLINE_STATUS_CNTRL +     ba, 0, None, "x393_status_ctrl", "rw",                  "Set status control register (status update mode)")),
            (("X393_MEMBRIDGE_SCANLINE_STARTADDR",       c, vrlg.MCNTRL_SCANLINE_STARTADDR +        ba, 0, None, "x393_mcntrl_window_frame_sa", "wo",       "Set frame start address")),
            (("X393_MEMBRIDGE_SCANLINE_FRAME_SIZE",      c, vrlg.MCNTRL_SCANLINE_FRAME_SIZE +       ba, 0, None, "x393_mcntrl_window_frame_sa_inc", "wo",   "Set frame size (address increment)")),
            (("X393_MEMBRIDGE_SCANLINE_FRAME_LAST",      c, vrlg.MCNTRL_SCANLINE_FRAME_LAST +       ba, 0, None, "x393_mcntrl_window_last_frame_num", "wo", "Set last frame number (number of frames in buffer minus 1)")),
            (("X393_MEMBRIDGE_SCANLINE_FRAME_FULL_WIDTH",c, vrlg.MCNTRL_SCANLINE_FRAME_FULL_WIDTH + ba, 0, None, "x393_mcntrl_window_full_width", "wo",     "Set frame full(padded) width")),
            (("X393_MEMBRIDGE_SCANLINE_WINDOW_WH",       c, vrlg.MCNTRL_SCANLINE_WINDOW_WH +        ba, 0, None, "x393_mcntrl_window_width_height", "wo",   "Set frame window size")),
            (("X393_MEMBRIDGE_SCANLINE_WINDOW_X0Y0",     c, vrlg.MCNTRL_SCANLINE_WINDOW_X0Y0 +      ba, 0, None, "x393_mcntrl_window_left_top", "wo",       "Set frame position")),
            (("X393_MEMBRIDGE_SCANLINE_STARTXY",         c, vrlg.MCNTRL_SCANLINE_WINDOW_STARTXY +   ba, 0, None, "x393_mcntrl_window_startx_starty", "wo",  "Set startXY register"))]
        
        ba = vrlg.MEMBRIDGE_ADDR
        ia = 0
        c =  ""
        sdefines +=[
            (("X393_MEMBRIDGE_CTRL",                     c, vrlg.MEMBRIDGE_CTRL +                  ba, 0, None, "x393_membridge_cmd", "wo",                "Issue membridge command")),
            (("X393_MEMBRIDGE_STATUS_CNTRL",             c, vrlg.MEMBRIDGE_STATUS_CNTRL +          ba, 0, None, "x393_status_ctrl", "rw",                  "Set membridge status control register")),
            (("X393_MEMBRIDGE_LO_ADDR64",                c, vrlg.MEMBRIDGE_LO_ADDR64 +             ba, 0, None, "u29", "wo",                               "start address of the system memory range in QWORDs (4 LSBs==0)")),
            (("X393_MEMBRIDGE_SIZE64",                   c, vrlg.MEMBRIDGE_SIZE64 +                ba, 0, None, "u29", "wo",                               "size of the system memory range in QWORDs (4 LSBs==0), rolls over")),
            (("X393_MEMBRIDGE_START64",                  c, vrlg.MEMBRIDGE_START64 +               ba, 0, None, "u29", "wo",                               "start of transfer offset to system memory range in QWORDs (4 LSBs==0)")),
            (("X393_MEMBRIDGE_LEN64",                    c, vrlg.MEMBRIDGE_LEN64 +                 ba, 0, None, "u29", "wo",                               "Full length of transfer in QWORDs")),
            (("X393_MEMBRIDGE_WIDTH64",                  c, vrlg.MEMBRIDGE_WIDTH64 +               ba, 0, None, "u29", "wo",                               "Frame width in QWORDs (last xfer in each line may be partial)")),
            (("X393_MEMBRIDGE_CTRL_IRQ",                 c, vrlg.MEMBRIDGE_CTRL_IRQ +              ba, 0, None, "x393_membridge_ctrl_irq", "wo",           "Membridge IRQ control"))]

        ba = vrlg.MCNTRL_PS_ADDR
        ia = 0
        c =  ""
        sdefines +=[
            (('Write-only addresses to PS PIO (Software generated DDR3 memory access sequences)',)),
            (("X393_MCNTRL_PS_EN_RST",                   c, vrlg.MCNTRL_PS_EN_RST +                ba, 0, None, "x393_ps_pio_en_rst", "wo",                 "Set PS PIO enable and reset")),
            (("X393_MCNTRL_PS_CMD",                      c, vrlg.MCNTRL_PS_CMD +                   ba, 0, None, "x393_ps_pio_cmd", "wo",                    "Set PS PIO commands")),
            (("X393_MCNTRL_PS_STATUS_CNTRL",             c, vrlg.MCNTRL_PS_STATUS_CNTRL +          ba, 0, None, "x393_status_ctrl", "rw",                   "Set PS PIO status control register (status update mode)"))]

        #other program status (move to other places?)
        ba = vrlg.MCONTR_PHY_16BIT_ADDR
        ia = 0
        c =  ""
        sdefines +=[
            (('Write-only addresses to to program status report mode for memory controller',)),
            (("X393_MCONTR_PHY_STATUS_CNTRL",            c, vrlg.MCONTR_PHY_STATUS_CNTRL +         ba, 0, None, "x393_status_ctrl", "rw",                    "Set status control register (status update mode)")),
            (("X393_MCONTR_TOP_16BIT_STATUS_CNTRL",      c, vrlg.MCONTR_TOP_16BIT_STATUS_CNTRL +   ba, 0, None, "x393_status_ctrl", "rw",                    "Set status control register (status update mode)")),
        ]
        ba = vrlg.MCNTRL_TEST01_ADDR
        ia = 0
        c =  ""
        sdefines +=[
            (('Write-only addresses to to program status report mode for test channels',)),
            (("X393_MCNTRL_TEST01_CHN2_STATUS_CNTRL",    c, vrlg.MCNTRL_TEST01_CHN2_STATUS_CNTRL + ba, 0, None, "x393_status_ctrl", "rw",                    "Set status control register (status update mode)")),
            (("X393_MCNTRL_TEST01_CHN3_STATUS_CNTRL",    c, vrlg.MCNTRL_TEST01_CHN3_STATUS_CNTRL + ba, 0, None, "x393_status_ctrl", "rw",                    "Set status control register (status update mode)")),
            (("X393_MCNTRL_TEST01_CHN4_STATUS_CNTRL",    c, vrlg.MCNTRL_TEST01_CHN4_STATUS_CNTRL + ba, 0, None, "x393_status_ctrl", "rw",                    "Set status control register (status update mode)")),
            (('Write-only addresses for test channels commands',)),
            (("X393_MCNTRL_TEST01_CHN2_MODE",            c, vrlg.MCNTRL_TEST01_CHN2_MODE +         ba, 0, None, "x393_test01_mode", "wo",                    "Set command for test01 channel 2")),
            (("X393_MCNTRL_TEST01_CHN3_MODE",            c, vrlg.MCNTRL_TEST01_CHN3_MODE +         ba, 0, None, "x393_test01_mode", "wo",                    "Set command for test01 channel 3")),
            (("X393_MCNTRL_TEST01_CHN4_MODE",            c, vrlg.MCNTRL_TEST01_CHN4_MODE +         ba, 0, None, "x393_test01_mode", "wo",                    "Set command for test01 channel 4")),
            
]
        #read_all_status
        ba = vrlg.STATUS_ADDR
        ia = 0
        c =  ""
        fpga_ver=   (1 << vrlg.STATUS_DEPTH) - 1;
        sens_iface= (1 << vrlg.STATUS_DEPTH) - 2;
        sdefines +=[
            (('Read-only addresses for status information',)),
            (("X393_MCONTR_PHY_STATUS",                  c, vrlg.MCONTR_PHY_STATUS_REG_ADDR + ba, 0, None, "x393_status_mcntrl_phy", "ro",                   "Status register for MCNTRL PHY")),
            (("X393_MCONTR_TOP_STATUS",                  c, vrlg.MCONTR_TOP_STATUS_REG_ADDR + ba, 0, None, "x393_status_mcntrl_top", "ro",                   "Status register for MCNTRL requests")),
            (("X393_MCNTRL_PS_STATUS",                   c, vrlg.MCNTRL_PS_STATUS_REG_ADDR +  ba, 0, None, "x393_status_mcntrl_ps", "ro",                    "Status register for MCNTRL software R/W")),
            (("X393_MCNTRL_CHN1_STATUS",                 c, vrlg.MCNTRL_SCANLINE_STATUS_REG_CHN1_ADDR+ba,0,None, "x393_status_mcntrl_lintile", "ro",         "Status register for MCNTRL CHN1 (membridge)")),
            (("X393_MCNTRL_CHN3_STATUS",                 c, vrlg.MCNTRL_SCANLINE_STATUS_REG_CHN3_ADDR+ba,0,None, "x393_status_mcntrl_lintile", "ro",         "Status register for MCNTRL CHN3 (scanline)")),
            (("X393_MCNTRL_CHN2_STATUS",                 c, vrlg.MCNTRL_TILED_STATUS_REG_CHN2_ADDR+ba,0,None,    "x393_status_mcntrl_lintile", "ro",         "Status register for MCNTRL CHN2 (tiled)")),
            (("X393_MCNTRL_CHN4_STATUS",                 c, vrlg.MCNTRL_TILED_STATUS_REG_CHN4_ADDR+ba,0,None,    "x393_status_mcntrl_lintile", "ro",         "Status register for MCNTRL CHN4 (tiled)")),
            
            (("X393_TEST01_CHN2_STATUS",                 c, vrlg.MCNTRL_TEST01_STATUS_REG_CHN2_ADDR+ba,0,None,   "x393_status_mcntrl_testchn", "ro",         "Status register for test channel 2")),
            (("X393_TEST01_CHN3_STATUS",                 c, vrlg.MCNTRL_TEST01_STATUS_REG_CHN3_ADDR+ba,0,None,   "x393_status_mcntrl_testchn", "ro",         "Status register for test channel 3")),
            (("X393_TEST01_CHN4_STATUS",                 c, vrlg.MCNTRL_TEST01_STATUS_REG_CHN4_ADDR+ba,0,None,   "x393_status_mcntrl_testchn", "ro",         "Status register for test channel 4")),
            (("X393_MEMBRIDGE_STATUS",                   c, vrlg.MEMBRIDGE_STATUS_REG+ba, 0, None,         "x393_status_membridge", "ro",                    "Status register for membridge")),
            (("X393_FPGA_VERSION",                       c, fpga_ver + ba, 0, None,                         "u32*", "ro",                                    "FPGA bitstream version")),
            (("X393_SENSOR_INTERFACE",                   c, sens_iface + ba, 0, None,                       "u32*", "ro",                                    "Sensor interface 0-parallel 12, 1 - HiSPI 4 lanes")),
            ]
        #Sensor memory status (frame number)        
        ba = vrlg.STATUS_ADDR
        ia = vrlg.MCONTR_SENS_STATUS_INC
        c =  "chn"
        sdefines +=[
            (('Sensor memory channel status)',)),
            (("X393_SENS_MEM_STATUS",                    c, vrlg.MCONTR_SENS_STATUS_BASE + ba, ia, z3, "x393_status_mcntrl_lintile", "ro",  "Status register for sensor memory channel"))]

        #Compressor memory status (frame number)        
        ba = vrlg.STATUS_ADDR
        ia = vrlg.MCONTR_CMPRS_STATUS_INC
        c =  "chn"
        sdefines +=[
            (('Sensor memory channel status)',)),
            (("X393_CMPRS_MEM_STATUS",                   c, vrlg.MCONTR_CMPRS_STATUS_BASE + ba, ia, z3, "x393_status_mcntrl_lintile", "ro",  "Status register for compressor memory channel"))]


        #Registers to control sensor channels        
        ba = vrlg.SENSOR_GROUP_ADDR
        ia = vrlg.SENSOR_BASE_INC
        c =  "sens_num"
        sdefines +=[
            (('Write-only control of the sensor channels',)),
            (("X393_SENS_MODE",                         c, vrlg.SENSOR_CTRL_RADDR +                        ba, ia, z3, "x393_sens_mode", "wo",               "Write sensor channel mode")),
            (("X393_SENSI2C_CTRL",                      c, vrlg.SENSI2C_CTRL_RADDR + vrlg.SENSI2C_CTRL +   ba, ia, z3, "x393_i2c_ctltbl", "wo",              "Control sensor i2c, write i2c LUT")),
            (("X393_SENSI2C_STATUS_CTRL",               c, vrlg.SENSI2C_CTRL_RADDR + vrlg.SENSI2C_STATUS + ba, ia, z3, "x393_status_ctrl", "rw",             "Setup sensor i2c status report mode")),
            (("X393_SENS_SYNC_MULT",                    c, vrlg.SENS_SYNC_RADDR + vrlg.SENS_SYNC_MULT +    ba, ia, z3, "x393_sens_sync_mult", "wo",          "Configure frames combining")),
            (("X393_SENS_SYNC_LATE",                    c, vrlg.SENS_SYNC_RADDR + vrlg.SENS_SYNC_LATE +    ba, ia, z3, "x393_sens_sync_late", "wo",          "Configure frame sync delay")),
            (("X393_SENSIO_CTRL",                       c, vrlg.SENSIO_RADDR + vrlg.SENSIO_CTRL +          ba, ia, z3, "x393_sensio_ctl", "wo",              "Configure sensor I/O port")),
            (("X393_SENSIO_STATUS_CNTRL",               c, vrlg.SENSIO_RADDR + vrlg.SENSIO_STATUS +        ba, ia, z3, "x393_status_ctrl", "rw",             "Set status control for SENSIO module")),
            (("X393_SENSIO_JTAG",                       c, vrlg.SENSIO_RADDR + vrlg.SENSIO_JTAG +          ba, ia, z3, "x393_sensio_jtag", "wo",             "Programming interface for multiplexer FPGA (with X393_SENSIO_STATUS)")),
            (("X393_SENSIO_WIDTH",                      c, vrlg.SENSIO_RADDR + vrlg.SENSIO_WIDTH +         ba, ia, z3, "x393_sensio_width", "rw",            "Set sensor line in pixels (0 - use line sync from the sensor)")),
#            (("X393_SENSIO_DELAYS",                     c, vrlg.SENSIO_RADDR + vrlg.SENSIO_DELAYS +       ba, ia, z3, "x393_sensio_dly", "rw",              "Sensor port input delays (uses 4 DWORDs)")),
            (("X393_SENSIO_TIM0",                       c, vrlg.SENSIO_RADDR + vrlg.SENSIO_DELAYS + 0 +    ba, ia, z3, "x393_sensio_tim0", "rw",             "Sensor port i/o timing configuration, register 0")),
            (("X393_SENSIO_TIM1",                       c, vrlg.SENSIO_RADDR + vrlg.SENSIO_DELAYS + 1 +    ba, ia, z3, "x393_sensio_tim1", "rw",             "Sensor port i/o timing configuration, register 1")),
            (("X393_SENSIO_TIM2",                       c, vrlg.SENSIO_RADDR + vrlg.SENSIO_DELAYS + 2 +    ba, ia, z3, "x393_sensio_tim2", "rw",             "Sensor port i/o timing configuration, register 2")),
            (("X393_SENSIO_TIM3",                       c, vrlg.SENSIO_RADDR + vrlg.SENSIO_DELAYS + 3 +    ba, ia, z3, "x393_sensio_tim3", "rw",             "Sensor port i/o timing configuration, register 3")),
            ]
        #Registers to control sensor channels        
        ba = vrlg.SENSOR_GROUP_ADDR
        ia = vrlg.SENSOR_BASE_INC
        c =  "sens_num"
        sdefines +=[
            (('''I2C command sequencer, block of 16 DWORD slots for absolute frame numbers (modulo 16) and 15 slots for relative ones
// 0 - ASAP, 1 next frame, 14 -14-th next.
// Data written depends on context:
// 1 - I2C register write: index page (MSB), 3 payload bytes. Payload bytes are used according to table and sent
//     after the slave address and optional high address byte. Other bytes are sent in descending order (LSB- last).
//     If less than 4 bytes are programmed in the table the high bytes (starting with the one from the table) are
//     skipped.
//     If more than 4 bytes are programmed in the table for the page (high byte), one or two next 32-bit words 
//     bypass the index table and all 4 bytes are considered payload ones. If less than 4 extra bytes are to be
//     sent for such extra word, only the lower bytes are sent.
//
// 2 - I2C register read: index page, slave address (8-bit, with lower bit 0) and one or 2 address bytes (as programmed
//     in the table. Slave address is always in byte 2 (bits 23:16), byte1 (high register address) is skipped if
//     read address in the table is programmed to be a single-byte one''',)),
            (("X393_SENSI2C_ABS",            (c,"offset"), vrlg.SENSI2C_ABS_RADDR +                      ba, (ia,1), (z3,z15), "u32*", "wo",                 "Write sensor i2c sequencer")),
            (("X393_SENSI2C_REL",            (c,"offset"), vrlg.SENSI2C_REL_RADDR +                      ba, (ia,1), (z3,z15), "u32*", "wo",                 "Write sensor i2c sequencer"))]
        
        #Lens vignetting correction
        ba = vrlg.SENSOR_GROUP_ADDR + vrlg.SENS_LENS_RADDR
        ia = vrlg.SENSOR_BASE_INC
        c =  "sens_num"
        sdefines +=[
            (('Lens vignetting correction (for each sub-frame separately)',)),
            (("X393_LENS_HEIGHT0_M1",                   c, 0 +                                            ba, ia, z3, "x393_lens_height_m1", "rw",           "Subframe 0 height minus 1")),
            (("X393_LENS_HEIGHT1_M1",                   c, 1 +                                            ba, ia, z3, "x393_lens_height_m1", "rw",           "Subframe 1 height minus 1")),
            (("X393_LENS_HEIGHT2_M1",                   c, 2 +                                            ba, ia, z3, "x393_lens_height_m1", "rw",           "Subframe 2 height minus 1")),
            (("X393_LENS_CORR_CNH_ADDR_DATA",           c, vrlg.SENS_LENS_COEFF +                         ba, ia, z3, "x393_lens_corr", "wo",                "Combined address/data to write lens vignetting correction coefficients")),
            (('Lens vignetting coefficient addresses - use with x393_lens_corr_wo_t (X393_LENS_CORR_CNH_ADDR_DATA)',)),
            (("X393_LENS_AX",             "", vrlg.SENS_LENS_AX ,             0, None, None, "",    "Address of correction parameter Ax")),
            (("X393_LENS_AX_MASK",        "", vrlg.SENS_LENS_AX_MASK ,        0, None, None, "",    "Correction parameter Ax mask")),
            (("X393_LENS_AY",             "", vrlg.SENS_LENS_AY ,             0, None, None, "",    "Address of correction parameter Ay")),
            (("X393_LENS_AY_MASK",        "", vrlg.SENS_LENS_AY_MASK ,        0, None, None, "",    "Correction parameter Ay mask")),
            (("X393_LENS_C",              "", vrlg.SENS_LENS_C ,              0, None, None, "",    "Address of correction parameter C")),
            (("X393_LENS_C_MASK",         "", vrlg.SENS_LENS_C_MASK ,         0, None, None, "",    "Correction parameter C mask")),
            (("X393_LENS_BX",             "", vrlg.SENS_LENS_BX ,             0, None, None, "",    "Address of correction parameter Bx")),
            (("X393_LENS_BX_MASK",        "", vrlg.SENS_LENS_BX_MASK ,        0, None, None, "",    "Correction parameter Bx mask")),
            (("X393_LENS_BY",             "", vrlg.SENS_LENS_BY ,             0, None, None, "",    "Address of correction parameter By")),
            (("X393_LENS_BY_MASK",        "", vrlg.SENS_LENS_BY_MASK ,        0, None, None, "",    "Correction parameter By mask")),
            (("X393_LENS_SCALE0",         "", vrlg.SENS_LENS_SCALES ,         0, None, None, "",    "Address of correction parameter scale0")),
            (("X393_LENS_SCALE1",         "", vrlg.SENS_LENS_SCALES + 2 ,     0, None, None, "",    "Address of correction parameter scale1")),
            (("X393_LENS_SCALE2",         "", vrlg.SENS_LENS_SCALES + 4 ,     0, None, None, "",    "Address of correction parameter scale2")),
            (("X393_LENS_SCALE3",         "", vrlg.SENS_LENS_SCALES + 6 ,     0, None, None, "",    "Address of correction parameter scale3")),
            (("X393_LENS_SCALES_MASK",    "", vrlg.SENS_LENS_SCALES_MASK ,    0, None, None, "",    "Common mask for scales")),
            (("X393_LENS_FAT0_IN",        "", vrlg.SENS_LENS_FAT0_IN ,        0, None, None, "",    "Address of input fat zero parameter (to subtract from input)")),
            (("X393_LENS_FAT0_IN_MASK",   "", vrlg.SENS_LENS_FAT0_IN_MASK ,   0, None, None, "",    "Mask for fat zero input parameter")),
            (("X393_LENS_FAT0_OUT",       "", vrlg.SENS_LENS_FAT0_OUT,        0, None, None, "",    "Address of output fat zero parameter (to add to output)")),
            (("X393_LENS_FAT0_OUT_MASK",  "", vrlg.SENS_LENS_FAT0_OUT_MASK ,  0, None, None, "",    "Mask for fat zero output  parameters")),
            (("X393_LENS_POST_SCALE",     "", vrlg.SENS_LENS_POST_SCALE ,     0, None, None, "",    "Address of post scale (shift output) parameter")),
            (("X393_LENS_POST_SCALE_MASK","", vrlg.SENS_LENS_POST_SCALE_MASK, 0, None, None, "",    "Mask for post scale parameter"))]
        #Gamma tables (See Python code for examples of the table data generation)
        ba = vrlg.SENSOR_GROUP_ADDR + vrlg.SENS_GAMMA_RADDR
        ia = vrlg.SENSOR_BASE_INC
        c =  "sens_num"
        sdefines +=[
            (('Sensor gamma conversion control (See Python code for examples of the table data generation)',)),
            (("X393_SENS_GAMMA_CTRL",                   c, vrlg.SENS_GAMMA_CTRL +                          ba, ia, z3, "x393_gamma_ctl", "rw",               "Gamma module control")),
            (("X393_SENS_GAMMA_TBL",                    c, vrlg.SENS_GAMMA_ADDR_DATA +                     ba, ia, z3, "x393_gamma_tbl", "wo",               "Write sensor gamma table address/data (with autoincrement)")),
            (("X393_SENS_GAMMA_HEIGHT01M1",             c, vrlg.SENS_GAMMA_HEIGHT01 +                      ba, ia, z3, "x393_gamma_height01m1", "rw",        "Gamma module subframes 0,1 heights minus 1")),
            (("X393_SENS_GAMMA_HEIGHT2M1",              c, vrlg.SENS_GAMMA_HEIGHT2 +                       ba, ia, z3, "x393_gamma_height2m1", "rw",         "Gamma module subframe  2 height minus 1"))]

        #Histogram window controls
        ba = vrlg.SENSOR_GROUP_ADDR
        ia = vrlg.SENSOR_BASE_INC
        c =  "sens_num"
        cs = ("sens_num","sub_chn")
        iam=(vrlg.SENSOR_BASE_INC,vrlg.HISTOGRAM_RADDR_INC)
        z3z3=(z3,z3)
        sdefines +=[
            (('Windows for histogram subchannels',)),
            (("X393_HISTOGRAM_LT",                      cs, vrlg.HISTOGRAM_RADDR0 + vrlg.HISTOGRAM_LEFT_TOP +     ba, iam, z3z3, "x393_hist_left_top", "rw",          "Specify histograms left/top")),
            (("X393_HISTOGRAM_WH",                      cs, vrlg.HISTOGRAM_RADDR0 + vrlg.HISTOGRAM_WIDTH_HEIGHT + ba, iam, z3z3, "x393_hist_width_height_m1", "rw",   "Specify histograms width/height")),
]
        ba = vrlg.SENSOR_GROUP_ADDR
        ia = vrlg.SENSOR_BASE_INC
        c =  "subchannel"
        sdefines +=[
            (('DMA control for the histograms. Subchannel here is 4*sensor_port+ histogram_subchannel',)),
            (("X393_HIST_SAXI_MODE",                    c, vrlg.HIST_SAXI_MODE_ADDR_REL +                  ba,  0, None, "x393_hist_saxi_mode", "rw",       "Histogram DMA operation mode")),
            (("X393_HIST_SAXI_ADDR",                    c, vrlg.HIST_SAXI_ADDR_REL +                       ba,  1, z15,  "x393_hist_saxi_addr", "rw",       "Histogram DMA addresses (in 4096 byte pages)"))]
        #sensors status        
        ba = vrlg.STATUS_ADDR + vrlg.SENSI2C_STATUS_REG_BASE
        ia = vrlg.SENSI2C_STATUS_REG_INC
        c =  "sens_num"
        sdefines +=[
            (('Read-only addresses for sensors status information',)),
            (("X393_SENSI2C_STATUS",                    c, vrlg.SENSI2C_STATUS_REG_REL +      ba, ia, z3, "x393_status_sens_i2c", "ro",                       "Status of the sensors i2c")),
            (("X393_SENSIO_STATUS",                     c, vrlg.SENSIO_STATUS_REG_REL +       ba, ia, z3, "x393_status_sens_io", "ro",                        "Status of the sensor ports I/O pins")),
            ]

        #Compressor control
        sdefines +=[
            (('Compressor bitfields values',)),
            (("X393_CMPRS_CBIT_RUN_RST",            "", vrlg.CMPRS_CBIT_RUN_RST ,           0, None, None, "", "Reset compressor, stop immediately")),
            (("X393_CMPRS_CBIT_RUN_DISABLE",        "", 1 ,                                 0, None, None, "", "Disable compression of the new frames, finish any already started")),
            (("X393_CMPRS_CBIT_RUN_STANDALONE",     "", vrlg.CMPRS_CBIT_RUN_STANDALONE ,    0, None, None, "", "Enable compressor, compress single frame from memory (async)")),
            (("X393_CMPRS_CBIT_RUN_ENABLE",         "", vrlg.CMPRS_CBIT_RUN_ENABLE ,        0, None, None, "", "Enable synchronous compression mode")),

            (("X393_CMPRS_CBIT_CMODE_JPEG18",       "", vrlg.CMPRS_CBIT_CMODE_JPEG18 ,      0, None, None, "", "Color 4:2:0 3x3 de-bayer core")),
            (("X393_CMPRS_CBIT_CMODE_MONO6",        "", vrlg.CMPRS_CBIT_CMODE_MONO6 ,       0, None, None, "", "Mono 4:2:0 (6 blocks)")),
            (("X393_CMPRS_CBIT_CMODE_JP46",         "", vrlg.CMPRS_CBIT_CMODE_JP46 ,        0, None, None, "", "jp4, 6 blocks, original")),
            (("X393_CMPRS_CBIT_CMODE_JP46DC",       "", vrlg.CMPRS_CBIT_CMODE_JP46DC ,      0, None, None, "", "jp4, 6 blocks, DC-improved")),
            (("X393_CMPRS_CBIT_CMODE_JPEG20",       "", vrlg.CMPRS_CBIT_CMODE_JPEG20 ,      0, None, None, "", "Color 4:2:0 with 5x5 de-bayer (not implemented)")),
            (("X393_CMPRS_CBIT_CMODE_JP4",          "", vrlg.CMPRS_CBIT_CMODE_JP4 ,         0, None, None, "", "jp4,  4 blocks")),
            (("X393_CMPRS_CBIT_CMODE_JP4DC",        "", vrlg.CMPRS_CBIT_CMODE_JP4DC ,       0, None, None, "", "jp4,  4 blocks, DC-improved")),
            (("X393_CMPRS_CBIT_CMODE_JP4DIFF",      "", vrlg.CMPRS_CBIT_CMODE_JP4DIFF ,     0, None, None, "", "jp4,  4 blocks, differential")),
            (("X393_CMPRS_CBIT_CMODE_JP4DIFFHDR",   "", vrlg.CMPRS_CBIT_CMODE_JP4DIFFHDR,   0, None, None, "", "jp4,  4 blocks, differential, hdr")),
            (("X393_CMPRS_CBIT_CMODE_JP4DIFFDIV2",  "", vrlg.CMPRS_CBIT_CMODE_JP4DIFFDIV2,  0, None, None, "", "jp4,  4 blocks, differential, divide by 2")),
            (("X393_CMPRS_CBIT_CMODE_JP4DIFFHDRDIV2","",vrlg.CMPRS_CBIT_CMODE_JP4DIFFHDRDIV2,0,None, None, "", "jp4,  4 blocks, differential, hdr,divide by 2")),
            (("X393_CMPRS_CBIT_CMODE_MONO1",        "", vrlg.CMPRS_CBIT_CMODE_MONO1 ,       0, None, None, "", "Mono JPEG (not yet implemented)")),
            (("X393_CMPRS_CBIT_CMODE_MONO4",        "", vrlg.CMPRS_CBIT_CMODE_MONO4 ,       0, None, None, "", "Mono, 4 blocks (2x2 macroblocks)")),

            (("X393_CMPRS_CBIT_FRAMES_SINGLE",      "", vrlg.CMPRS_CBIT_FRAMES_SINGLE ,     0, None, None, "", "Use single-frame buffer")),
            (("X393_CMPRS_CBIT_FRAMES_MULTI",       "", 1 ,                                 0, None, None, "", "Use multi-frame buffer"))]        
        ba = vrlg.CMPRS_GROUP_ADDR
        ia = vrlg.CMPRS_BASE_INC
        c =  "cmprs_chn"
        sdefines +=[
            (('Compressor control',)),
            (("X393_CMPRS_CONTROL_REG",                  c, vrlg.CMPRS_CONTROL_REG +                  ba, ia, z3, "x393_cmprs_mode", "rw",                    "Program compressor channel operation mode")),
            (("X393_CMPRS_STATUS",                       c, vrlg.CMPRS_STATUS_CNTRL +                 ba, ia, z3, "x393_status_ctrl", "rw",                   "Setup compressor status report mode")),
            (("X393_CMPRS_FORMAT",                       c, vrlg.CMPRS_FORMAT +                       ba, ia, z3, "x393_cmprs_frame_format", "rw",            "Compressor frame format")),
            (("X393_CMPRS_COLOR_SATURATION",             c, vrlg.CMPRS_COLOR_SATURATION +             ba, ia, z3, "x393_cmprs_colorsat", "rw",                "Compressor color saturation")),
            (("X393_CMPRS_CORING_MODE",                  c, vrlg.CMPRS_CORING_MODE +                  ba, ia, z3, "x393_cmprs_coring_mode", "rw",             "Select coring mode")),
            (("X393_CMPRS_INTERRUPTS",                   c, vrlg.CMPRS_INTERRUPTS +                   ba, ia, z3, "x393_cmprs_interrupts", "wo",              "Compressor interrupts control (1 - clear, 2 - disable, 3 - enable)")),
            (('_Compressor tables load control',)),
            (('_Several tables can be loaded to the compressor, there are 4 types of them:',)),
            (('_    0:quantization tables - 8 pairs can be loaded and switched at run time,',)),
            (('_    1:coring tables -       8 pairs can be loaded and switched at run time,',)),
            (('_    2:focusing tables -    15 tables can be loaded and switched at run time (16-th table address space',)),
            (('_      is used to program other focusing mode parameters,',)),
            (('_    3:Huffman tables -     1 pair tables can be loaded',)),
            (('_Default tables are loaded with the bitstream file (100% quality for quantization table 0',)),
            (('_Loading a table requires to load address of the beginning of data, it includes table type and optional offset',)),
            (('_when multiple tables of the same type are used. Next the data should be written to the same register address,',)),
            (('_the table address is auto-incremented,',)),
            (('_Data for the tables 0..2 should be combined: two items into a single 32-bit DWORD (little endian), treating',)),
            (('_each item as a 16-bit word. The Huffman table is one item per DWORD. Address offset is calculated in DWORDs',)),
            (('Compressor table types',)),
            (("X393_TABLE_QUANTIZATION_TYPE",            "", vrlg.TABLE_QUANTIZATION_INDEX ,        0, None, None, "", "Quantization table type")),
            (("X393_TABLE_CORING_TYPE",                  "", vrlg.TABLE_CORING_INDEX ,              0, None, None, "", "Coring table type")),
            (("X393_TABLE_FOCUS_TYPE",                   "", vrlg.TABLE_FOCUS_INDEX ,               0, None, None, "", "Focus table type")),
            (("X393_TABLE_HUFFMAN_TYPE",                 "", vrlg.TABLE_HUFFMAN_INDEX ,             0, None, None, "", "Huffman table type")),
            (('Compressor tables control',)),
            (("X393_CMPRS_TABLES_DATA",                   c, vrlg.CMPRS_TABLES + 0 +                 ba, ia, z3, "u32*", "wo",                               "Compressor tables data")),
            (("X393_CMPRS_TABLES_ADDRESS",                c, vrlg.CMPRS_TABLES + 1 +                 ba, ia, z3, "x393_cmprs_table_addr", "wo",              "Compressor tables type/address")),
             ]
        ba = vrlg.STATUS_ADDR
        ia = vrlg.CMPRS_STATUS_REG_INC
        c =  "chn"
        sdefines +=[
            (('Compressor channel status)',)),
            (("X393_CMPRS_STATUS",             c, vrlg.CMPRS_STATUS_REG_BASE + ba, vrlg.CMPRS_STATUS_REG_INC, z3, "x393_cmprs_status", "ro",          "Status of the compressor channel (incl. interrupt")),
            (("X393_CMPRS_HIFREQ",             c, vrlg.CMPRS_HIFREQ_REG_BASE + ba, vrlg.CMPRS_HIFREQ_REG_INC, z3, "u32*", "ro",                       "Focus helper high-frequency amount"))]
        
        ba = vrlg.CMPRS_GROUP_ADDR + vrlg.CMPRS_AFIMUX_RADDR0
        ia = 0
        c =  "afi_port"
        sdefines +=[
            (('Compressor DMA control:',)),
            (('_Camera can be configured to use either 2 AXI HP channels (with 2 compressors served by each one) or to use a single AXI HP channel',)),
            (('_serving all 4 compressor channels through its input ports. Below afi_port (0..3) references to one of the 4 ports of each. Control',)),
            (('_for two AXI HP channels is implemented as separate functions. Currently only the first channel is used',)),
            (("X393_AFIMUX0_EN",                          c, vrlg.CMPRS_AFIMUX_EN +                  ba, 0, None, "x393_afimux_en", "wo",             "AFI MUX 0 global/port run/pause control")),
            (("X393_AFIMUX0_RST",                         c, vrlg.CMPRS_AFIMUX_RST +                 ba, 0, None, "x393_afimux_rst", "rw",            "AFI MUX 0 per-port resets")),
            (("X393_AFIMUX0_REPORT_MODE",                 c, vrlg.CMPRS_AFIMUX_MODE +                ba, 0, None, "x393_afimux_report", "wo",         "AFI MUX 0 readout pointer report mode")),
            (("X393_AFIMUX0_STATUS_CONTROL",              c, vrlg.CMPRS_AFIMUX_STATUS_CNTRL +        ba, 1, z3,   "x393_status_ctrl", "rw",           "AFI MUX 0 status report mode")),
            (("X393_AFIMUX0_SA",                          c, vrlg.CMPRS_AFIMUX_SA_LEN +              ba, 1, z3,   "x393_afimux_sa", "rw",             "AFI MUX 0 DMA buffer start address in 32-byte blocks")),
            (("X393_AFIMUX0_LEN",                         c, vrlg.CMPRS_AFIMUX_SA_LEN + 4 +          ba, 1, z3,   "x393_afimux_len", "rw",            "AFI MUX 0 DMA buffer length in 32-byte blocks"))]
        ba = vrlg.CMPRS_GROUP_ADDR + vrlg.CMPRS_AFIMUX_RADDR1
        sdefines +=[
            (('_Same for the second AXI HP channel (not currently used)',)),
            (("X393_AFIMUX1_EN",                          c, vrlg.CMPRS_AFIMUX_EN +                  ba, 0, None, "x393_afimux_en", "wo",             "AFI MUX 1 global/port run/pause control")),
            (("X393_AFIMUX1_RST",                         c, vrlg.CMPRS_AFIMUX_RST +                 ba, 0, None, "x393_afimux_rst", "rw",            "AFI MUX 1 per-port resets")),
            (("X393_AFIMUX1_REPORT_MODE",                 c, vrlg.CMPRS_AFIMUX_MODE +                ba, 0, None, "x393_afimux_report", "wo",         "AFI MUX 1 readout pointer report mode")),
            (("X393_AFIMUX1_STATUS_CONTROL",              c, vrlg.CMPRS_AFIMUX_STATUS_CNTRL +        ba, 1, z3,   "x393_status_ctrl", "rw",           "AFI MUX 1 status report mode")),
            (("X393_AFIMUX1_SA",                          c, vrlg.CMPRS_AFIMUX_SA_LEN +              ba, 1, z3,   "x393_afimux_sa", "rw",             "AFI MUX 1 DMA buffer start address in 32-byte blocks")),
            (("X393_AFIMUX1_LEN",                         c, vrlg.CMPRS_AFIMUX_SA_LEN + 4 +          ba, 1, z3,   "x393_afimux_len", "rw",            "AFI MUX 1 DMA buffer length in 32-byte blocks"))]        

        #compressor DMA status        
        ba = vrlg.STATUS_ADDR
        ia = 1
        c =  "afi_port"
        sdefines +=[
            (('Read-only sensors status information (pointer offset and last sequence number)',)),
            (("X393_AFIMUX0_STATUS",                    c, vrlg.CMPRS_AFIMUX_REG_ADDR0 +             ba, ia, z3, "x393_afimux_status", "ro",          "Status of the AFI MUX 0 (including image pointer)")),
            (("X393_AFIMUX1_STATUS",                    c, vrlg.CMPRS_AFIMUX_REG_ADDR1 +             ba, ia, z3, "x393_afimux_status", "ro",          "Status of the AFI MUX 1 (including image pointer)")),
            ]

        #GPIO control - modified to use sequencer so any channel can control it
        ba = vrlg.GPIO_ADDR
        ia = 0
        c =  "sens_chn"
        sdefines +=[
            (('_',)),
            (('_GPIO contol. Each of the 10 pins can be controlled by the software - individually or simultaneously or from any of the 3 masters (other FPGA modules)',)),
            (('_Currently these modules are;',)),
            (('_     A - camsync (intercamera synchronization), uses up to 4 pins ',)),
            (('_     B - reserved (not yet used) and ',)),
            (('_     C - logger (IMU, GPS, images), uses 6 pins, including separate i2c available on extension boards',)),
            (('_If several enabled ports try to contol the same bit, highest priority has port C, lowest - software controlled',)),
            (("X393_GPIO_SET_PINS",                       c,  vrlg.GPIO_SET_PINS +                   ba, 0, z3,   "x393_gpio_set_pins", "wo",       "State of the GPIO pins and seq. number")),
            (("X393_GPIO_STATUS_CONTROL",                 "", vrlg.GPIO_SET_STATUS +                 ba, 0, None, "x393_status_ctrl", "rw",         "GPIO status control mode"))]
        
        ba = vrlg.STATUS_ADDR
        sdefines +=[
            (('Read-only GPIO pins state',)),
            (("X393_GPIO_STATUS",                         "", vrlg.GPIO_STATUS_REG_ADDR +            ba, 0, None, "x393_gpio_status", "ro",         "State of the GPIO pins and seq. number"))]

        #RTC control
        ba = vrlg.RTC_ADDR
        ia = 0
        c =  ""
        sdefines +=[
            (('RTC control',)),
            (("X393_RTC_USEC",                            "", vrlg.RTC_SET_USEC +                    ba, 0, None, "x393_rtc_usec", "rw",            "RTC microseconds")),
            (("X393_RTC_SEC_SET",                         "", vrlg.RTC_SET_SEC +                     ba, 0, None, "x393_rtc_sec", "rw",             "RTC seconds and set clock")),
            (("X393_RTC_CORR",                            "", vrlg.RTC_SET_CORR +                    ba, 0, None, "x393_rtc_corr", "rw",            "RTC correction (+/- 1/256 full scale)")),
            (("X393_RTC_SET_STATUS",                      "", vrlg.RTC_SET_STATUS +                  ba, 0, None, "x393_status_ctrl", "rw",         "RTC status control mode, write makes a snapshot to be read out"))]
        ba = vrlg.STATUS_ADDR
        sdefines +=[
            (('Read-only RTC state',)),
            (("X393_RTC_STATUS",                         "", vrlg.RTC_STATUS_REG_ADDR +              ba, 0, None, "x393_rtc_status", "ro",          "RTC status reg")),
            (("X393_RTC_STATUS_SEC",                     "", vrlg.RTC_SEC_USEC_ADDR + 0 +            ba, 0, None, "x393_rtc_sec", "ro",             "RTC snapshot seconds")),
            (("X393_RTC_STATUS_USEC",                    "", vrlg.RTC_SEC_USEC_ADDR + 1 +            ba, 0, None, "x393_rtc_usec", "ro",            "RTC snapshot microseconds"))]
        
        #CAMSYNC control
        ba = vrlg.CAMSYNC_ADDR
        ia = 0
        c =  "sens_chn"
        sdefines +=[
            (('CAMSYNC control',)),
            (("X393_CAMSYNC_MODE",                        c, vrlg.CAMSYNC_MODE +                     ba, 0, z3,   "x393_camsync_mode", "wo",        "CAMSYNC mode")),
            (("X393_CAMSYNC_TRIG_SRC",                    c, vrlg.CAMSYNC_TRIG_SRC +                 ba, 0, z3,   "x393_camsync_io",   "wo",        "CAMSYNC trigger source")),
            (("X393_CAMSYNC_TRIG_DST",                    c, vrlg.CAMSYNC_TRIG_DST +                 ba, 0, z3,   "x393_camsync_io",   "wo",        "CAMSYNC trigger destination")),
            (('_Trigger period has special value for small (<255) values written to this register',)),
            (('_    d == 0 - disable (stop periodic mode)',)),
            (('_    d == 1 - single trigger',)),
            (('_    d == 2..255 - set output pulse / input-output serial bit duration (no start generated)',)),
            (('_    d >= 256 - repetitive trigger',)),
            (("X393_CAMSYNC_TRIG_PERIOD",                 c,  vrlg.CAMSYNC_TRIG_PERIOD +             ba, 0, z3,   "u32*", "rw",                     "CAMSYNC trigger period")),
            (("X393_CAMSYNC_TRIG_DELAY",                  c,  vrlg.CAMSYNC_TRIG_DELAY0 +             ba, 1, z3,   "u32*", "rw",                     "CAMSYNC trigger delay"))]
        
        ba = vrlg.CMDFRAMESEQ_ADDR_BASE
        ia = vrlg.CMDFRAMESEQ_ADDR_INC
        c =  "sens_chn"
        sdefines +=[
            (('Command sequencer control',)),
            (('_Controller is programmed through 32 locations. Each register but the control requires two writes:',)),
            (('_First write - register address (AXI_WR_ADDR_BITS bits), second - register data (32 bits)',)),
            (('_Writing to the contol register (0x1f) resets the first/second counter so the next write will be "first"',)),
            (('_0x0..0xf write directly to the frame number [3:0] modulo 16, except if you write to the frame',)),
            (('_          "just missed" - in that case data will go to the current frame.',)),
            (('_ 0x10 - write seq commands to be sent ASAP',)),
            (('_ 0x11 - write seq commands to be sent after the next frame starts',)), 
            (('_',)),
            (('_ 0x1e - write seq commands to be sent after the next 14 frame start pulses',)),
            (('_ 0x1f - control register:',)),
            (('_     [14] -   reset all FIFO (takes 32 clock pulses), also - stops seq until run command',)),
            (('_     [13:12] - 3 - run seq, 2 - stop seq , 1,0 - no change to run state',)),
            (('_       [1:0] - 0: NOP, 1: clear IRQ, 2 - Clear IE, 3: set IE',)),
            (("X393_CMDFRAMESEQ_CTRL",                    c,  vrlg.CMDFRAMESEQ_CTRL +                ba, ia, z3, "x393_cmdframeseq_mode", "wo",     "CMDFRAMESEQ control register")),
            (("X393_CMDFRAMESEQ_ABS",          (c,"offset"),  vrlg.CMDFRAMESEQ_ABS +                 ba, (ia,1), (z3,z15), "u32*", "wo",            "CMDFRAMESEQ absolute frame address/command")),
            (("X393_CMDFRAMESEQ_REL",          (c,"offset"),  vrlg.CMDFRAMESEQ_REL +                 ba, (ia,1), (z3,z14), "u32*", "wo",            "CMDFRAMESEQ relative frame address/command"))]
        
        ba = 0
        ia = 0
        c =  ""
        sdefines +=[
            (('_Command sequencer multiplexer, provides current frame number for each sensor channel and interrupt status/interrupt masks for them.',)),
            (('_Interrupts and interrupt masks are controlled through channel CMDFRAMESEQ module',)),
            (("X393_CMDSEQMUX_STATUS_CTRL",               "",  vrlg.CMDSEQMUX_ADDR,                      0, None, "x393_status_ctrl", "rw",           "CMDSEQMUX status control mode (status provides current frame numbers)")),
            (("X393_CMDSEQMUX_STATUS",                    "",  vrlg.STATUS_ADDR + vrlg.CMDSEQMUX_STATUS, 0, None, "x393_cmdseqmux_status", "ro",      "CMDSEQMUX status data (frame numbers and interrupts"))]

        sdefines +=[
            (('Event logger',)),
            (('_Event logger configuration/data is written to the module using two 32-bit register locations : data and address.',)),
            (('_Address consists of 2 parts - 2-bit page (configuration, imu, gps, message) and a 5-bit sub-address autoincremented when writing data.',)),
            (('_Register pages:',)),
            (("X393_LOGGER_PAGE_CONF",                    "", 0 ,                                0, None, None, "",    "Logger configuration page")),
            (("X393_LOGGER_PAGE_IMU",                     "", vrlg.LOGGER_PAGE_IMU ,             0, None, None, "",    "Logger IMU parameters page (fist 4 DWORDs are not used)")),
            (("X393_LOGGER_PAGE_GPS",                     "", vrlg.LOGGER_PAGE_GPS ,             0, None, None, "",    "Logger GPS parameters page")),
            (("X393_LOGGER_PAGE_MSG",                     "", vrlg.LOGGER_PAGE_MSG ,             0, None, None, "",    "Logger MSG (odometer) parameters page")),
            (('_Register configuration addresses (with X393_LOGGER_PAGE_CONF):',)),
            (("X393_LOGGER_PERIOD",                       "", vrlg.LOGGER_PERIOD ,               0, None, None, "",    "IMU period (in SPI clocks, high word 0xffff - use IMU ready)")),
            (("X393_LOGGER_BIT_DURATION",                 "", vrlg.LOGGER_BIT_DURATION ,         0, None, None, "",    "IMU SPI bit duration (in mclk == 50 ns periods?)")),
            (("X393_LOGGER_BIT_HALF_PERIOD",              "", vrlg.LOGGER_BIT_HALF_PERIOD,       0, None, None, "",    "Logger rs232 half bit period (in mclk == 50 ns periods?)")),
            (("X393_LOGGER_CONFIG",                       "", vrlg.LOGGER_CONFIG ,               0, None, None, "",    "Logger IMU parameters page")),
            
            (("X393_LOGGER_STATUS_CTRL",                  "",  vrlg.LOGGER_STATUS,                       0, None,       "x393_status_ctrl", "rw",     "Logger status configuration (to report sample number)")),
            (("X393_LOGGER_DATA",                         "",  vrlg.LOGGER_ADDR + 0,                     0, None,       "x393_logger_data", "wo",     "Logger register write data")),
            (("X393_LOGGER_ADDRESS",                      "",  vrlg.LOGGER_ADDR + 1,                     0, None,       "x393_logger_address", "wo",  "Logger register write page/address")),
            (("X393_LOGGER_STATUS",                       "",  vrlg.STATUS_ADDR + vrlg.LOGGER_STATUS_REG_ADDR, 0, None, "x393_logger_status", "ro",   "Logger status data (sequence number)"))]
#TODO: Add interrupt for the logger?

        #MULT SAXI DMA engine control
        ba = 0
        ia = 0
        c =  "chn"
        sdefines +=[
            (('MULT SAXI DMA engine control. Of 4 channels only one (number 0) is currently used - for the event logger',)),
            (("X393_MULT_SAXI_MODE",                "",  vrlg.MULT_SAXI_CNTRL_ADDR+vrlg.MULT_SAXI_CNTRL_MODE,   0, None, "x393_mult_saxi_mode",       "rw","MULT_SAXI mode register (per-channel enable and run bits)")),
            (("X393_MULT_SAXI_STATUS_CTRL",         "",  vrlg.MULT_SAXI_CNTRL_ADDR+vrlg.MULT_SAXI_CNTRL_STATUS, 0, None, "x393_status_ctrl",          "rw","MULT_SAXI status control mode (status provides current DWORD pointers)")),
            (("X393_MULT_SAXI_INTERRUPTS",          "",  vrlg.MULT_SAXI_CNTRL_ADDR+vrlg.MULT_SAXI_CNTRL_IRQ,    0, None, "x393_mult_saxi_interrupts", "wo","MULT_SAXI per-channel interrupts control (each dibit:nop/reset/disable/enable)")),
            (("X393_MULT_SAXI_BUF_ADDRESS",         c,   vrlg.MULT_SAXI_ADDR + 0,                        2, z3,    "x393_mult_saxi_al",               "wo","MULT_SAXI buffer start address in DWORDS")),
            (("X393_MULT_SAXI_BUF_LEN",             c,   vrlg.MULT_SAXI_ADDR + 1,                        2, z3,    "x393_mult_saxi_al",               "wo","MULT_SAXI buffer length in DWORDS")),
            (("X393_MULT_SAXI_IRQLEN",              c,   vrlg.MULT_SAXI_IRQLEN_ADDR,                     1, z3,    "x393_mult_saxi_irqlen",           "wo","MULT_SAXI lower DWORD address bit to change to generate interrupt")),
            (("X393_MULT_SAXI_POINTERS",            c,   vrlg.STATUS_ADDR + vrlg.MULT_SAXI_POINTERS_REG, 1, z3,    "x393_mult_saxi_al",               "ro","MULT_SAXI current DWORD pointer")),
            (("X393_MULT_SAXI_STATUS",              "",  vrlg.STATUS_ADDR + vrlg.MULT_SAXI_STATUS_REG,   0, None,  "x393_mult_saxi_status",           "ro","MULT_SAXI status with interrupt status"))]

        #MULTI_CLK global clock generation PLLs
        ba = 0
        ia = 0
        c =  "chn"
        sdefines +=[
            (('MULTI_CLK - global clock generation PLLs. Interface provided for debugging, no interaction is needed for normal operation',)),
            (("X393_MULTICLK_STATUS_CTRL",          "",  vrlg.CLK_ADDR + vrlg.CLK_STATUS,                0, None, "x393_status_ctrl", "rw",           "MULTI_CLK status generation (do not use or do not set auto)")),
            (("X393_MULTICLK_CTRL",                 "",  vrlg.CLK_ADDR + vrlg.CLK_CNTRL,                 0, None, "x393_multiclk_ctl", "rw",          "MULTI_CLK reset and power down control")),
            (("X393_MULTICLK_STATUS",               "",  vrlg.STATUS_ADDR + vrlg.CLK_STATUS_REG_ADDR,    0, None, "x393_multiclk_status", "ro",       "MULTI_CLK lock and toggle state"))]

        #DEBUG ring module
        ba = 0
        ia = 0
        c =  "chn"
        sdefines +=[
            (('Debug ring module',)),
            (('_Debug ring module (when enabled with DEBUG_RING in system_defines.vh) provides low-overhead read/write access to internal test points',)),
            (('_To write data you need to write 32-bit data with x393_debug_shift(u32) multiple times to fill the ring register (length depends on',)),
            (('_implementation), skip this step if only reading from the modules under test is required.',)),
            (('_Exchange data with x393_debug_load(), the data from the ring shift register.',)),
            (('_Write 0xffffffff (or other "magic" data) if the ring length is unknown - this DWORD will appear on the output after the useful data',)),
            (('_Read all data, waiting for status sequence number to be incremented,status mode should be set to auto (3) wor each DWORD certain',)),
            (('_number of times or until the "magic" DWORD appears, writing "magic" to shift out next 32 bits.',)),
            (("X393_DEBUG_STATUS_CTRL",             "",  vrlg.DEBUG_ADDR + vrlg.DEBUG_SET_STATUS,        0, None, "x393_status_ctrl", "rw",           "Debug ring status generation - set to auto(3) if used")),
            (("X393_DEBUG_LOAD",                    "",  vrlg.DEBUG_ADDR + vrlg.DEBUG_LOAD,              0, None, "", "",                             "Debug ring copy shift register to/from tested modules")),
            (("X393_DEBUG_SHIFT",                   "",  vrlg.DEBUG_ADDR + vrlg.DEBUG_SHIFT_DATA,        0, None, "u32*", "wo",                       "Debug ring shift ring by 32 bits")),
            (("X393_DEBUG_STATUS",                  "",  vrlg.STATUS_ADDR + vrlg.DEBUG_STATUS_REG_ADDR,  0, None, "x393_debug_status", "ro",          "Debug read status (watch sequence number)")),
            (("X393_DEBUG_READ",                    "",  vrlg.STATUS_ADDR + vrlg.DEBUG_READ_REG_ADDR,    0, None, "u32*", "ro",                       "Debug read DWORD form ring register"))]

        return sdefines
    
    def define_other_macros(self): # Used mostly for development/testing, not needed for normal camera operation
        ba = vrlg.MCNTRL_SCANLINE_CHN3_ADDR
        c =  ""
        sdefines = []
        sdefines +=[
            (('Write-only addresses to program memory channel 3 (test channel)',)),
            (("X393_MCNTRL_CHN3_SCANLINE_MODE",            c, vrlg.MCNTRL_SCANLINE_MODE +             ba, 0, None, "x393_mcntrl_mode_scan", "wo",             "Set mode register (write last after other channel registers are set)")),
            (("X393_MCNTRL_CHN3_SCANLINE_STATUS_CNTRL",    c, vrlg.MCNTRL_SCANLINE_STATUS_CNTRL +     ba, 0, None, "x393_status_ctrl", "rw",                  "Set status control register (status update mode)")),
            (("X393_MCNTRL_CHN3_SCANLINE_STARTADDR",       c, vrlg.MCNTRL_SCANLINE_STARTADDR +        ba, 0, None, "x393_mcntrl_window_frame_sa", "wo",       "Set frame start address")),
            (("X393_MCNTRL_CHN3_SCANLINE_FRAME_SIZE",      c, vrlg.MCNTRL_SCANLINE_FRAME_SIZE +       ba, 0, None, "x393_mcntrl_window_frame_sa_inc", "wo",   "Set frame size (address increment)")),
            (("X393_MCNTRL_CHN3_SCANLINE_FRAME_LAST",      c, vrlg.MCNTRL_SCANLINE_FRAME_LAST +       ba, 0, None, "x393_mcntrl_window_last_frame_num", "wo", "Set last frame number (number of frames in buffer minus 1)")),
            (("X393_MCNTRL_CHN3_SCANLINE_FRAME_FULL_WIDTH",c, vrlg.MCNTRL_SCANLINE_FRAME_FULL_WIDTH + ba, 0, None, "x393_mcntrl_window_full_width", "wo",     "Set frame full(padded) width")),
            (("X393_MCNTRL_CHN3_SCANLINE_WINDOW_WH",       c, vrlg.MCNTRL_SCANLINE_WINDOW_WH +        ba, 0, None, "x393_mcntrl_window_width_height", "wo",   "Set frame window size")),
            (("X393_MCNTRL_CHN3_SCANLINE_WINDOW_X0Y0",     c, vrlg.MCNTRL_SCANLINE_WINDOW_X0Y0 +      ba, 0, None, "x393_mcntrl_window_left_top", "wo",       "Set frame position")),
            (("X393_MCNTRL_CHN3_SCANLINE_STARTXY",         c, vrlg.MCNTRL_SCANLINE_WINDOW_STARTXY +   ba, 0, None, "x393_mcntrl_window_startx_starty", "wo",  "Set startXY register"))]
        ba = vrlg.MCNTRL_TILED_CHN2_ADDR
        c =  ""
        sdefines +=[
            (('Write-only addresses to program memory channel 2 (test channel)',)),
            (("X393_MCNTRL_CHN2_TILED_MODE",               c, vrlg.MCNTRL_TILED_MODE +                ba, 0, None, "x393_mcntrl_mode_scan", "wo",             "Set mode register (write last after other channel registers are set)")),
            (("X393_MCNTRL_CHN2_TILED_STATUS_CNTRL",       c, vrlg.MCNTRL_TILED_STATUS_CNTRL +        ba, 0, None, "x393_status_ctrl", "rw",                  "Set status control register (status update mode)")),
            (("X393_MCNTRL_CHN2_TILED_STARTADDR",          c, vrlg.MCNTRL_TILED_STARTADDR +           ba, 0, None, "x393_mcntrl_window_frame_sa", "wo",       "Set frame start address")),
            (("X393_MCNTRL_CHN2_TILED_FRAME_SIZE",         c, vrlg.MCNTRL_TILED_FRAME_SIZE +          ba, 0, None, "x393_mcntrl_window_frame_sa_inc", "wo",   "Set frame size (address increment)")),
            (("X393_MCNTRL_CHN2_TILED_FRAME_LAST",         c, vrlg.MCNTRL_TILED_FRAME_LAST +          ba, 0, None, "x393_mcntrl_window_last_frame_num", "wo", "Set last frame number (number of frames in buffer minus 1)")),
            (("X393_MCNTRL_CHN2_TILED_FRAME_FULL_WIDTH",   c, vrlg.MCNTRL_TILED_FRAME_FULL_WIDTH +    ba, 0, None, "x393_mcntrl_window_full_width", "wo",     "Set frame full(padded) width")),
            (("X393_MCNTRL_CHN2_TILED_WINDOW_WH",          c, vrlg.MCNTRL_TILED_WINDOW_WH +           ba, 0, None, "x393_mcntrl_window_width_height", "wo",   "Set frame window size")),
            (("X393_MCNTRL_CHN2_TILED_WINDOW_X0Y0",        c, vrlg.MCNTRL_TILED_WINDOW_X0Y0 +         ba, 0, None, "x393_mcntrl_window_left_top", "wo",       "Set frame position")),
            (("X393_MCNTRL_CHN2_TILED_STARTXY",            c, vrlg.MCNTRL_TILED_WINDOW_STARTXY +      ba, 0, None, "x393_mcntrl_window_startx_starty", "wo",  "Set startXY register")),
            (("X393_MCNTRL_CHN2_TILED_TILE_WHS",           c, vrlg.MCNTRL_TILED_TILE_WHS +            ba, 0, None, "x393_mcntrl_window_tile_whs", "wo",       "Set tile size/step (tiled mode only)"))]
        ba = vrlg.MCNTRL_TILED_CHN4_ADDR
        c =  ""
        sdefines +=[
            (('Write-only addresses to program memory channel 4 (test channel)',)),
            (("X393_MCNTRL_CHN4_TILED_MODE",               c, vrlg.MCNTRL_TILED_MODE +                ba, 0, None, "x393_mcntrl_mode_scan", "wo",             "Set mode register (write last after other channel registers are set)")),
            (("X393_MCNTRL_CHN4_TILED_STATUS_CNTRL",       c, vrlg.MCNTRL_TILED_STATUS_CNTRL +        ba, 0, None, "x393_status_ctrl", "rw",                  "Set status control register (status update mode)")),
            (("X393_MCNTRL_CHN4_TILED_STARTADDR",          c, vrlg.MCNTRL_TILED_STARTADDR +           ba, 0, None, "x393_mcntrl_window_frame_sa", "wo",       "Set frame start address")),
            (("X393_MCNTRL_CHN4_TILED_FRAME_SIZE",         c, vrlg.MCNTRL_TILED_FRAME_SIZE +          ba, 0, None, "x393_mcntrl_window_frame_sa_inc", "wo",   "Set frame size (address increment)")),
            (("X393_MCNTRL_CHN4_TILED_FRAME_LAST",         c, vrlg.MCNTRL_TILED_FRAME_LAST +          ba, 0, None, "x393_mcntrl_window_last_frame_num", "wo", "Set last frame number (number of frames in buffer minus 1)")),
            (("X393_MCNTRL_CHN4_TILED_FRAME_FULL_WIDTH",   c, vrlg.MCNTRL_TILED_FRAME_FULL_WIDTH +    ba, 0, None, "x393_mcntrl_window_full_width", "wo",     "Set frame full(padded) width")),
            (("X393_MCNTRL_CHN4_TILED_WINDOW_WH",          c, vrlg.MCNTRL_TILED_WINDOW_WH +           ba, 0, None, "x393_mcntrl_window_width_height", "wo",   "Set frame window size")),
            (("X393_MCNTRL_CHN4_TILED_WINDOW_X0Y0",        c, vrlg.MCNTRL_TILED_WINDOW_X0Y0 +         ba, 0, None, "x393_mcntrl_window_left_top", "wo",       "Set frame position")),
            (("X393_MCNTRL_CHN4_TILED_STARTXY",            c, vrlg.MCNTRL_TILED_WINDOW_STARTXY +      ba, 0, None, "x393_mcntrl_window_startx_starty", "wo",  "Set startXY register")),
            (("X393_MCNTRL_CHN4_TILED_TILE_WHS",           c, vrlg.MCNTRL_TILED_TILE_WHS +            ba, 0, None, "x393_mcntrl_window_tile_whs", "wo",       "Set tile size/step (tiled mode only)"))]
        return sdefines
    
    def expand_define_maxi0(self, define_tuple, mode, frmt_spcs = None):
        if len(define_tuple)  == 1 :
            return self.expand_define(define_tuple = define_tuple, frmt_spcs = frmt_spcs)
        elif len(define_tuple)  == 8:
            name, var_name, address, address_inc, var_range, data_type, rw, comment = define_tuple
            if data_type is None:  #just constants, no offset and multiplication
                if (mode == 'defines') or (mode =='func_decl') :
                    return self.expand_define(define_tuple = (name,
                                                              var_name,
                                                              address,
                                                              address_inc,
                                                              var_range,
                                                              data_type,
                                                              rw,
                                                              comment),
                                              frmt_spcs = frmt_spcs)
                else:
                    return ""
            else:
                if isinstance(address_inc,(list,tuple)): # var_name, var_range are also lists/tuples of the same length
                    address_inc = [4 * d for d in address_inc]
                else:
                    address_inc = 4 * address_inc
                #processing sequencer command (have "w" and var_name and var_range = 0..3
                #TODO: Add special character to rw meaning channel applicable
                channelCmd=False
#                if var_name and address_inc and ('w' in rw) and var_range:
                if var_name and ('w' in rw) and var_range:
                    multivar = isinstance(address_inc,(list,tuple))
                    if multivar:
                        if isinstance(var_range[0],(list,tuple)) and (var_range[0][0] == 0) and (var_range[0][1] == 3):
                            channelCmd = True
                    else:
                        if (var_range[0] == 0) and (var_range[1] == 3):
                            channelCmd = True
                if (mode == 'defines') :
                    return self.expand_define(define_tuple = (name,
                                                              var_name,
                                                              address * 4 + self.MAXI0_BASE,
                                                              address_inc, # * 4,
                                                              var_range,
                                                              data_type,
                                                              rw,
                                                              comment),
                                              frmt_spcs = frmt_spcs)
                elif (mode =='func_decl'):
#                    if channelCmd:
#                        print (name,data_type,rw)
                    return self.func_declare (define_tuple = (name,
                                                              var_name,
                                                              address * 4 + self.MAXI0_BASE,
                                                              address_inc, # * 4,
                                                              var_range,
                                                              data_type,
                                                              rw,
                                                              comment),
                                              frmt_spcs = frmt_spcs,
                                              genSeqCmd = channelCmd)
                elif (mode =='func_def'):
                    return self.func_define  (define_tuple = (name,
                                                              var_name,
                                                              address * 4, #  + self.MAXI0_BASE,
                                                              address_inc, # * 4,
                                                              var_range,
                                                              data_type,
                                                              rw,
                                                              comment),
                                              frmt_spcs = frmt_spcs,
                                              genSeqCmd = channelCmd)
                else:
                    print ("Unknown mode:", mode)    
                        
        else:
            print ("****** wrong tuple length: ",define_tuple)

    def  func_declare(self,
                      define_tuple,
                      frmt_spcs,
                      genSeqCmd = False):
        frmt_spcs=self.fix_frmt_spcs(frmt_spcs)
        
#        name, var_name, address, address_inc, var_range, data_type, rw, comment = define_tuple
        rw= define_tuple[6]
        s=""
        if 'w' in rw:
            s += self.func_set(isDefine=False,define_tuple=define_tuple, frmt_spcs = frmt_spcs)
            if (genSeqCmd):
                s += "\n"+self.func_set(isDefine=False,define_tuple=define_tuple, frmt_spcs = frmt_spcs, isGenRel = True)
                s += "\n"+self.func_set(isDefine=False,define_tuple=define_tuple, frmt_spcs = frmt_spcs, isGenAbs = True)
                
        if 'r' in rw:
            if s:
                s += '\n'
            s += self.func_get(isDefine=False, define_tuple=define_tuple, frmt_spcs = frmt_spcs)
        if (not 'r' in rw) and (not 'w' in rw):     
            s += self.func_touch(isDefine=False,define_tuple=define_tuple, frmt_spcs = frmt_spcs)
        return s    

    def func_define(self,
                      define_tuple,
                      frmt_spcs,
                      genSeqCmd = False):
        frmt_spcs=self.fix_frmt_spcs(frmt_spcs)
#        name, var_name, address, address_inc, var_range, data_type, rw, comment = define_tuple
        rw= define_tuple[6]
        s=""
        if 'w' in rw:
            s += self.func_set(isDefine=True, define_tuple=define_tuple, frmt_spcs = frmt_spcs)
            if (genSeqCmd):
                s += "\n"+self.func_set(isDefine=True, define_tuple=define_tuple, frmt_spcs = frmt_spcs, isGenRel = True)
                s += "\n"+self.func_set(isDefine=True, define_tuple=define_tuple, frmt_spcs = frmt_spcs, isGenAbs = True)
        if 'r' in rw:
            if s:
                s += '\n'
            s += self.func_get(isDefine=True, define_tuple=define_tuple, frmt_spcs = frmt_spcs)
        if (not 'r' in rw) and (not 'w' in rw):     
            s += self.func_touch(isDefine=True, define_tuple=define_tuple, frmt_spcs = frmt_spcs)
        return s    
    def str_tab_stop(self,s,l):
        if len(s)>= l:
            return s
        else:
            return s + (" "*(l - len(s)))  
    
    def func_get(self,
                  isDefine,
                  define_tuple,
                  frmt_spcs):
#        name, var_name, address, address_inc, var_range, data_type, rw, comment = define_tuple
        name, var_name, address, address_inc, _, data_type, rw, comment = define_tuple
        multivar = isinstance(address_inc,(list,tuple)) # var_name, var_range are also lists/tuples of the same length
        
        stops=frmt_spcs[('declare','define')[isDefine]]
        #TODO: add optional argument range check?
        data_type = self.fix_data_type(data_type)
        sz=self.typedefs[data_type]['size'] # check it exists
        if (sz > 32):
            print ("***** Only 32-bit data is supported, %s used for %s is %d bit"%(data_type, name, sz))
        fname = name.lower()
        if ('r' in rw) and ('w' in rw):
            fname = 'get_'+fname
            comment = "" # set is supposed to go first, if both - only set has comment
        if multivar:
            args = "int %s"%(var_name[0].lower())
            for vn in var_name[1:]:
                args += ", int %s"%(vn.lower())
        else:       
            arg = var_name.lower()   
            args = 'void'
            if arg and address_inc:
                args = 'int '+ arg    
        s = "%s "%(data_type)
        s = self.str_tab_stop(s,stops[0])
        s += "%s"%(fname)
        s = self.str_tab_stop(s,stops[1])
        s += "(%s)"%(args)
        s = self.str_tab_stop(s,stops[2])
        if isDefine:
            if self.typedefs[data_type]['code']: # not just u32
                td = 'd.%s'%(frmt_spcs['data32'])
            else:
                td='d'
            s+=frmt_spcs['body_prefix']    
            s+='{ %s d; %s = readl(mmio_ptr + '%(data_type, td)
            if address_inc:
                s+='(0x%04x'%(address)
                if multivar:
                    for vn, vi in zip (var_name, address_inc):
                        s+=' + 0x%x * %s'%(vi, vn.lower())
                else:
                    s+=' + 0x%x * %s'%(address_inc, arg)
                s += ')'
            else:
                s+='0x%04x'%(address)
            s+='); return d; }'
        else:
            s += ';'
        if comment:
            s = self.str_tab_stop(s,stops[3])
            s += ' // %s'%(comment) 
        return s

    def  func_set(self,
                  isDefine,
                  define_tuple,
                  frmt_spcs,
                  isGenRel = False,
                  isGenAbs = False):
#        name, var_name, address, address_inc, var_range, data_type, rw, comment = define_tuple
        name, var_name, address, address_inc, _, data_type, rw, comment = define_tuple
        use_address_inc = address_inc or isGenRel or isGenAbs # so address_inc ==0 will work for TRIG_ parameters
        multivar = isinstance(address_inc,(list,tuple)) # var_name, var_range are also lists/tuples of the same length
        stops=frmt_spcs[('declare','define')[isDefine]]
        #TODO: add optional argument range check?
        data_type = self.fix_data_type(data_type)
        #        self.typedefs['u32']= {'comment':'unsigned 32-bit', 'code':'', 'size':32, 'type':''}
        sz=self.typedefs[data_type]['size'] # check it exists
        if (sz > 32):
            print ("***** Only 32-bit data is supported, %s used for %s is %d bit"%(data_type, name, sz))
        fname = name.lower()
        if isGenRel:
            fname = 'seqr_'+fname
        elif isGenAbs:
            fname = 'seqa_'+fname
        else:       
            if ('r' in rw) and ('w' in rw):
                fname = 'set_'+fname
        args = '%s d'%(data_type)
        if multivar:
            for vn in var_name:
                args += ', int '+ vn.lower()
        else:
            arg = var_name.lower()   
            if arg and use_address_inc:
                args += ', int '+ arg    
        s = "void "
        s = self.str_tab_stop(s,stops[0])
        s += "%s"%(fname)
        s = self.str_tab_stop(s,stops[1])
        if isGenRel or isGenAbs: #can not be void - it is write command
            s += "(int frame, %s)"%(args)
        else:
            s += "(%s)"%(args)
        s = self.str_tab_stop(s,stops[2])
        if isDefine:
            if self.typedefs[data_type]['code']: # not just u32
                td = 'd.%s'%(frmt_spcs['data32'])
            else:
                td='d'
            s+=frmt_spcs['body_prefix']
            if isGenRel or isGenAbs:
                address32 = '0x%04x'%(address>>2)
                if multivar:
                    for vn, vi in zip (var_name, address_inc):
                        address32 += ' + 0x%x * %s'%(vi>>2, vn.lower())
                    first_index_name= var_name[0]   
                else:
                    address32 += ' + 0x%x * %s'%(address_inc>>2, arg)
                    first_index_name= var_name   
                if isGenRel: # TODO: Calculate!
#                    reg_addr = '0x1e40 + 0x80 * %s + 0x4 * frame'%(first_index_name)
                    reg_addr = '0x%x + 0x%x * %s + 0x4 * frame'%(
                                4 * (vrlg.CMDFRAMESEQ_ADDR_BASE + vrlg.CMDFRAMESEQ_REL), 4*vrlg.CMDFRAMESEQ_ADDR_INC, first_index_name)    
                else:
#                    reg_addr = '0x1e00 + 0x80 * %s + 0x4 * frame'%(first_index_name)    
                    reg_addr = '0x%x + 0x%x * %s + 0x4 * frame'%(
                                4 * (vrlg.CMDFRAMESEQ_ADDR_BASE + vrlg.CMDFRAMESEQ_ABS), 4*vrlg.CMDFRAMESEQ_ADDR_INC, first_index_name)    
                    
                s+= '{frame &= PARS_FRAMES_MASK; spin_lock(&lock); '
                s+= 'writel(%s, mmio_ptr + %s); '%(address32,reg_addr)
                if data_type == "u32":
                    s+= 'writel(d, mmio_ptr + %s); '%(reg_addr)
                else:    
                    s+= 'writel(d.d32, mmio_ptr + %s); '%(reg_addr)
                s+= 'spin_unlock(&lock);}'
                
            else:   
                s+='{writel(%s, mmio_ptr + '%(td)
                if use_address_inc:
                    s+='(0x%04x'%(address)
                    if multivar:
                        for vn, vi in zip (var_name, address_inc):
                            s+=' + 0x%x * %s'%(vi, vn.lower())
                    else:
                        s+=' + 0x%x * %s'%(address_inc, arg)
                    s += ')'
                else:
                    s+='0x%04x'%(address)
                s+=');}'
            
        else:
            s += ';'
        if comment:
            s = self.str_tab_stop(s,stops[3])
            s += ' // %s'%(comment) 
        return s

    def  func_touch(self,
                  isDefine,
                  define_tuple,
                  frmt_spcs):
#       name, var_name, address, address_inc, var_range, data_type, rw, comment = define_tuple
        name, var_name, address, address_inc, _,            _,       _,  comment = define_tuple
        multivar = isinstance(address_inc,(list,tuple)) # var_name, var_range are also lists/tuples of the same length
        stops=frmt_spcs[('declare','define')[isDefine]]
        #TODO: add optional argument range check?
        fname = name.lower()
        if multivar:
            args = "int %s"%(var_name[0].lower())
            for vn in var_name[1:]:
                args += ", int %s"%(vn.lower())
        else:       
            arg = var_name.lower()   
            args = 'void'
            if arg and address_inc:
                args = 'int '+ arg    
        s = "void "
        s = self.str_tab_stop(s,stops[0])
        s += "%s"%(fname)
        s = self.str_tab_stop(s,stops[1])
        s += "(%s)"%(args)
        s = self.str_tab_stop(s,stops[2])
        if isDefine:
#            s+='{'
            s+=frmt_spcs['body_prefix']    
            s+='{writel(0, mmio_ptr + '
            if address_inc:
                s+='(0x%04x'%(address)
                if multivar:
                    for vn, vi in zip (var_name, address_inc):
                        s+=' + 0x%x * %s'%(vi, vn.lower())
                else:
                    s+=' + 0x%x * %s'%(address_inc, arg)
                s += ')'
            else:
                s+='0x%04x'%(address)
            s+=');}'
        else:
            s += ';'
        if comment:
            s = self.str_tab_stop(s,stops[3])
            s += ' // %s'%(comment) 
        return s

    def fix_data_type(self,data_type):
        if data_type:
            if data_type[-1] == "*": # skip adding '_t": some_type -> some_type_t, u32* -> u32
                data_type=data_type[0:-1]
            else:    
                data_type = data_type +"_t"
        return data_type
            
    def expand_define(self, define_tuple, frmt_spcs = None):
        frmt_spcs=self.fix_frmt_spcs(frmt_spcs)
        s=""
        if len(define_tuple)  ==1 :
            comment = define_tuple[0]
            if comment:
                if comment[0] == "_":
                    s += "// %s"%(comment[1:]) # for multi-line comments
                else:
                    s += "\n// %s\n"%(comment)
        else:
            name, var_name, address, address_inc, var_range, data_type, rw, comment = define_tuple
            multivar = isinstance(address_inc,(list,tuple)) # var_name, var_range are also lists/tuples of the same length
            if var_range and frmt_spcs['showRange']:
                if comment:
                    comment += ', '
                else:
                    comment = ""
                if multivar:
                    first = True
                    for vn,vr in zip(var_name, var_range):
                        if first:
                            first = False
                        else:    
                            comment += ', '
                        comment += "%s = %d..%d"%(vn, vr[0], vr[1])
                else:    
                    comment += "%s = %d..%d"%(var_name, var_range[0], var_range[1])
            if data_type and frmt_spcs['showType']:
                if comment:
                    comment += ', '
                comment += "data type: %s (%s)"%(self.fix_data_type(data_type), rw)
            name_len = len(name)
            if address_inc:
                if multivar:
                    name_len += 2 + len(var_name[0])
                    for vn in var_name[1:]:
                        name_len += 1 + len(vn)
                else:        
                    name_len += 2 + len(var_name)
            ins_spaces = max(0,frmt_spcs['macroNameLen'] - name_len)
            if address_inc:
                if multivar:
                    vname = "%s"%(var_name[0])
                    for vn in var_name[1:]:
                        vname +=",%s"%(vn)
                    s = "#define %s(%s) %s(0x%08x)"%(name, vname, ' ' * ins_spaces, address)
                    for vn, vi in zip(var_name, address_inc):
                        s += "+ 0x%x * (%s)"%(vi,vn)
                    s+=")"                        
                else:    
                    s = "#define %s(%s) %s(0x%08x + 0x%x * (%s))"%(name, var_name, ' ' * ins_spaces, address, address_inc, var_name)
            else:
                s = "#define %s %s0x%08x"%(name,' ' * ins_spaces, address)
            if comment:
                s += " // %s"%(comment)
        return s

    def expand_define_parameters(self, in_defs, showGaps = True):
        def recursive_pairs(increments,ranges):
            if len(increments) == 0:
                return (("",0),)
            else:
                return [("__%d%s"%(i,s),increments[0]*i+d) for i in range(ranges[0][0],ranges[0][1]+1) for s,d in recursive_pairs(increments[1:],ranges[1:])]
        exp_defs=[]
        for define_tuple in in_defs:
            if len(define_tuple) == 8:
                name, var_name, address, address_inc, var_range, data_type, rw, comment = define_tuple
                if not data_type is None:
                    if address_inc == 0:
                        exp_defs.append(define_tuple)
                        nextAddr = address + 4
                    else:
                        if isinstance(address_inc,(list,tuple)):
                            for suffix, offset in recursive_pairs(address_inc,var_range):
                                exp_defs.append(("%s%s"%(name,suffix),var_name,address + offset ,0,None,data_type,rw, comment))
                        else:
                            for x in range(var_range[0], var_range[1] + 1):
                                exp_defs.append(("%s__%d"%(name,x),var_name,address+x*address_inc,0,None,data_type,rw, comment))
                                nextAddr = address + var_range[1] * address_inc + 4
        #now sort address map
        sorted_defs= sorted(exp_defs,key=lambda item: item[2])
        if showGaps:
            nextAddr = None
            prevName = ""
            gapped_defs=[]
            for define_tuple in sorted_defs:
                address = define_tuple[2] 
                if not nextAddr is None:
                    if address > nextAddr:
                        gapped_defs.append(("_RESERVED: 0x%x DWORD%s"%(address - nextAddr, ("","s")[(address - nextAddr) > 1]),))
                    elif not address == nextAddr:
                        print("**************** Error? address = 0x%x (0x%08x), expected address = 0x%x (0x%08x)"%(address, 4*address, nextAddr,4*nextAddr))
                        print("**************** previous name = %s, this name = %s"%(prevName, define_tuple[0]))
                prevName = define_tuple[0]            
                gapped_defs.append(define_tuple)
                nextAddr = address + 1    
            return gapped_defs
        else:
            return sorted_defs
        
             
    def _enc_func_encode_mode_scan_tiled(self):
        dw=[]
        dw.append(("enable",       vrlg.MCONTR_LINTILE_EN,1,1,        "enable requests from this channel ( 0 will let current to finish, but not raise want/need)"))
        dw.append(("chn_nreset",   vrlg.MCONTR_LINTILE_NRESET,1,1,    "0: immediately reset all the internal circuitry"))
        dw.append(("write_mem",    vrlg.MCONTR_LINTILE_WRITE,1,0,     "0 - read from memory, 1 - write to memory"))
        dw.append(("extra_pages",  vrlg.MCONTR_LINTILE_EXTRAPG, vrlg.MCONTR_LINTILE_EXTRAPG_BITS,0, "2-bit number of extra pages that need to stay (not to be overwritten) in the buffer"))
        dw.append(("keep_open",    vrlg.MCONTR_LINTILE_KEEP_OPEN,1,0, "for 8 or less rows - do not close page between accesses (not used in scanline mode)"))
        dw.append(("byte32",       vrlg.MCONTR_LINTILE_BYTE32,1,1,    "32-byte columns (0 - 16-byte), not used in scanline mode"))
        dw.append(("reset_frame",  vrlg.MCONTR_LINTILE_RST_FRAME,1,0, "reset frame number (also resets buffer at next frame start). NEEDED after initial set up to propagate start address!"))
        dw.append(("single",       vrlg.MCONTR_LINTILE_SINGLE,1,0,    "run single frame"))
        dw.append(("repetitive",   vrlg.MCONTR_LINTILE_REPEAT,1,1,    "run repetitive frames"))
        dw.append(("disable_need", vrlg.MCONTR_LINTILE_DIS_NEED,1,0,  "disable 'need' generation, only 'want' (compressor channels)"))
        dw.append(("skip_too_late",vrlg.MCONTR_LINTILE_SKIP_LATE,1,0, "Skip over missed blocks to preserve frame structure (increment pointers)"))
        dw.append(("copy_frame",   vrlg.MCONTR_LINTILE_COPY_FRAME,1,0, "Copy frame number from the master (sensor) channel. Combine with reset_frame to reset bjuffer"))
        dw.append(("abort_late",   vrlg.MCONTR_LINTILE_ABORT_LATE,1,0, "abort frame if not finished by the new frame sync (wait pending memory transfers)"))
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

    def _enc_frame_start_dly(self):
        dw=[]
        dw.append(("start_dly",      0,vrlg.MCNTRL_SCANLINE_DLY_WIDTH,vrlg.MCNTRL_SCANLINE_DLY_DEFAULT, "delay start pulse by mclk"))
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
        dw.append(("frame_number",    0, 16,0,  "Number of the last transferred frame in the buffer"))
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
        dw.append(("irq_r",           16, 1,0,  "Interrupt request (before mask)"))
        dw.append(("irq_m",           17, 1,0,  "Interrupt enable (0 - disable)"))
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
        dw.append(("xfpgatdo_byte",         16, 8,0,  "Multiplexer FPGA TDO output"))
        dw.append(("senspgmin",             24, 1,0,  "senspgm pin state"))
        dw.append(("xfpgatdo",              25, 1,0,  "Multiplexer FPGA TDO output"))
        dw.append(("seq_num",               26, 6,0,  "Sequence number"))
        return dw

    def _enc_status_sens_i2c(self):
        dw=[]
        dw.append(("i2c_fifo_dout",          0, 8,0,  "I2c byte read from the device through FIFO"))
        dw.append(("i2c_fifo_nempty",        8, 1,0,  "I2C read FIFO has data"))
        dw.append(("i2c_fifo_lsb",           9, 1,0,  "I2C FIFO byte counter (odd/even bytes)"))
        dw.append(("busy",                  10, 1,0,  "I2C sequencer busy"))
        dw.append(("wr_full",               11, 1,0,  "Write buffer almost full (1/4..3/4 in ASAP mode)"))
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
    """
    def _enc_membridge_mode(self):
        dw=[]
        dw.append(("axi_cache",        0, 4,3,  "AXI CACHE value (ignored by Zynq)"))
        dw.append(("debug_cache",      4, 1,0,  "0 - normal operation, 1 debug (replace data)"))
        return dw
    """    
    def _enc_membridge_ctrl_irq(self):
        dw=[]
        dw.append(("interrupt_cmd",    0, 2,   0, "IRQ control commands - 0: nop, 1: clear interrupt status, 2: disable interrupt, 3: enable interrupt"))
        return dw
    
    def _enc_u29(self):
        dw=[]
        dw.append(("addr64",           0,29,0,  "Address/length in 64-bit words (<<3 to get byte address"))
        return dw

    def _enc_i2c_tbl_addr(self):
        dw=[]
        dw.append(("tbl_addr",         0, 8,0,  "I2C table index"))
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
        dw.append(("nbrd",             vrlg.SENSI2C_TBL_NBRD, vrlg.SENSI2C_TBL_NBRD_BITS,0, "Number of bytes to read (1..8, 0 means '8')"))
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
        
        dw.append(("soft_scl",         vrlg.SENSI2C_CMD_SOFT_SCL,     2,0,  "Control SCL pin (when stopped): 0 - nop, 1 - low, 2 - high (driven), 3 - float "))
        dw.append(("soft_sda",         vrlg.SENSI2C_CMD_SOFT_SDA,     2,0,  "Control SDA pin (when stopped): 0 - nop, 1 - low, 2 - high (driven), 3 - float "))
        dw.append(("eof_not_sof",      vrlg.SENSI2C_CMD_USE_EOF,      2,0,  "Advance I2C sequencer: 0 - SOF, 1 - EOF"))
        
        dw.append(("cmd_run",          vrlg.SENSI2C_CMD_RUN-1,        2,0,  "Sequencer run/stop control: 0,1 - nop, 2 - stop, 3 - run "))
        dw.append(("reset",            vrlg.SENSI2C_CMD_RESET,        1,0,  "Sequencer reset all FIFO (takes 16 clock pulses), also - stops i2c until run command"))
        dw.append(("tbl_mode",         vrlg.SENSI2C_CMD_TAND,         2,0,  "Should be 0 to select controls"))
        return dw

    def _enc_sens_mode(self):
        dw=[]
        dw.append(("hist_en",          vrlg.SENSOR_HIST_EN_BITS,    4,15,  "Enable subchannel histogram modules (may be less than 4)"))
        dw.append(("hist_nrst",        vrlg.SENSOR_HIST_NRST_BITS,  4,15,  "Reset off for histograms subchannels (may be less than 4)"))
        dw.append(("hist_set",         vrlg.SENSOR_HIST_BITS_SET,   1, 0,  "Apply values in hist_en and hist_nrst fields (0 - ignore)"))
        dw.append(("chn_en",           vrlg.SENSOR_CHN_EN_BIT,      1, 1,  "Enable this sensor channel"))
        dw.append(("chn_en_set",       vrlg.SENSOR_CHN_EN_BIT_SET,  1, 1,  "Apply chn_en value (0 - ignore)"))
        dw.append(("bit16",            vrlg.SENSOR_16BIT_BIT,       1, 0,  "0 - 8 bpp mode, 1 - 16 bpp (bypass gamma). Gamma-processed data is still used for histograms"))
        dw.append(("bit16_set",        vrlg.SENSOR_16BIT_BIT_SET,   1, 0,  "Apply bit16 value (0 - ignore)"))
        return dw

    def _enc_sens_sync_mult(self):
        dw=[]
        dw.append(("mult_frames",      0, vrlg.SENS_SYNC_FBITS,   0,  "Number of frames to combine into one minus 1 (0 - single,1 - two frames...)"))
        return dw

    def _enc_sens_sync_late(self):
        dw=[]
        dw.append(("delay_fsync",      0, vrlg.SENS_SYNC_LBITS,   0,  "Number of lines to delay late frame sync"))
        return dw

    def _enc_mcntrl_priorities(self):
        dw=[]
        dw.append(("priority",         0, 16,   0,  "Channel priority (the larger the higher). Each grant resets this channel to 'priority', increments others. Highest wins (among want/need)"))
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

    def _enc_mcntrl_dly(self):
        dw=[]
        dw.append(("dly",             0,  8,   0,  "8-bit delay value: 5MSBs(0..31) and 3LSBs(0..4)"))
        return dw

    def _enc_wbuf_dly(self):
        dw=[]
        dw.append(("wbuf_dly",        0,  4,   9,  "Extra delay in mclk (fDDR/2) cycles) to data write buffer"))
        return dw

    def _enc_gamma_ctl(self):
        dw=[]
        dw.append(("bayer",           vrlg.SENS_GAMMA_MODE_BAYER,      2,   0,  "Bayer color shift (pixel to gamma table)"))
        dw.append(("bayer_set",       vrlg.SENS_GAMMA_MODE_BAYER_SET,  1,   0,  "Set 'bayer' field"))
        dw.append(("page",            vrlg.SENS_GAMMA_MODE_PAGE,  1,   0,  "Table page (only available if SENS_GAMMA_BUFFER in Verilog)"))
        dw.append(("page_set",        vrlg.SENS_GAMMA_MODE_PAGE_SET,   1,   0,  "Set 'page' field"))
        dw.append(("en",              vrlg.SENS_GAMMA_MODE_EN,         1,   1,  "Enable module"))
        dw.append(("en_set",          vrlg.SENS_GAMMA_MODE_EN_SET,     1,   1,  "Set 'en' field"))
        dw.append(("repet",           vrlg.SENS_GAMMA_MODE_REPET,      1,   1,  "Repetitive (normal) mode. Set 0 for testing of the single-frame mode"))
        dw.append(("repet_set",       vrlg.SENS_GAMMA_MODE_REPET_SET,  1,   1,  "Set 'repet' field"))
        dw.append(("trig",            vrlg.SENS_GAMMA_MODE_TRIG,       1,   0,  "Single trigger used when repetitive mode is off (self clearing bit)"))
        return dw

    def _enc_gamma_tbl_addr(self):
        dw=[]
        dw.append(("addr",            0,  8,   0,  "Start address in a gamma page (normally 0)"))
        dw.append(("color",           8,  2,   0,  "Color channel"))
        if vrlg.SENS_GAMMA_BUFFER:
            dw.append(("page",       10,  1,   0,  "Table page (only available for buffered mode)"))
            sub_chn_bit = 11
        else:
            sub_chn_bit = 10
        dw.append(("sub_chn",sub_chn_bit, 2,   0,  "Sensor sub-channel (multiplexed to the same port)"))
        dw.append(("a_n_d",          20,  1,   1,  "Address/not data, should be set to 1 here"))
        return dw
    def _enc_gamma_tbl_data(self):
        dw=[]
        dw.append(("base",            0, 10,   0,  "Knee point value (to be interpolated between)"))
        dw.append((("diff","char"),  10,  7,   0,  "Difference to next (signed, -64..+63)"))
        dw.append(("diff_scale",     17,  1,   0,  "Difference scale: 0 - keep diff, 1- multiply diff by 16"))
        return dw
    def _enc_gamma_height01(self):
        dw=[]
        dw.append(("height0m1",       0, 16,   0,  "Height of subchannel 0 frame minus 1"))
        dw.append(("height1m1",      16, 16,   0,  "Height of subchannel 1 frame minus 1"))
        return dw
    def _enc_gamma_height2(self):
        dw=[]
        dw.append(("height2m1",       0, 16,   0,  "Height of subchannel 2 frame minus 1"))
        return dw

    def _enc_sensio_ctrl_par12(self):
        dw=[]
        dw.append(("mrst",         vrlg.SENS_CTRL_MRST,         1,   0,  "MRST signal level to the sensor (0 - low(active), 1 - high (inactive)"))
        dw.append(("mrst_set",     vrlg.SENS_CTRL_MRST + 1,     1,   0,  "when set to 1, MRST is set  to the 'mrst' field value"))
        dw.append(("arst",         vrlg.SENS_CTRL_ARST,         1,   0,  "ARST signal to the sensor (0 - low(active), 1 - high (inactive)"))
        dw.append(("arst_set",     vrlg.SENS_CTRL_ARST + 1,     1,   0,  "ARST set  to the 'arst' field"))
        dw.append(("aro",          vrlg.SENS_CTRL_ARO,          1,   0,  "ARO signal to the sensor"))
        dw.append(("aro_set",      vrlg.SENS_CTRL_ARO + 1,      1,   0,  "ARO set to the 'aro' field"))
        dw.append(("mmcm_rst",     vrlg.SENS_CTRL_RST_MMCM,     1,   0,  "MMCM (for sensor clock) reset signal (1 - reset, 0 - normal operation)"))
        dw.append(("mmcm_rst_set", vrlg.SENS_CTRL_RST_MMCM + 1, 1,   0,  "MMCM reset set to  'mmcm_rst' field"))
        dw.append(("ext_clk",      vrlg.SENS_CTRL_EXT_CLK,      1,   0,  "MMCM clock input: 0: clock to the sensor, 1 - clock from the sensor"))
        dw.append(("ext_clk_set",  vrlg.SENS_CTRL_EXT_CLK + 1,  1,   0,  "Set MMCM clock input to 'ext_clk' field"))
        dw.append(("set_dly",      vrlg.SENS_CTRL_LD_DLY,       1,   0,  "Set all pre-programmed delays to the sensor port input delays"))
        dw.append(("quadrants",    vrlg.SENS_CTRL_QUADRANTS,  vrlg. SENS_CTRL_QUADRANTS_WIDTH, 1, "90-degree shifts for data [1:0], hact [3:2] and vact [5:4], [6] - extra period delay for hact"))
        dw.append(("quadrants_set",vrlg.SENS_CTRL_QUADRANTS_EN, 1,   0,  "Set 'quadrants' values"))
        return dw
    def _enc_sensio_ctrl_hispi(self):
        dw=[]
        dw.append(("mrst",         vrlg.SENS_CTRL_MRST,         1,   0,  "MRST signal level to the sensor (0 - low(active), 1 - high (inactive)"))
        dw.append(("mrst_set",     vrlg.SENS_CTRL_MRST + 1,     1,   0,  "when set to 1, MRST is set  to the 'mrst' field value"))
        dw.append(("arst",         vrlg.SENS_CTRL_ARST,         1,   0,  "ARST signal to the sensor"))
        dw.append(("arst_set",     vrlg.SENS_CTRL_ARST + 1,     1,   0,  "ARST set  to the 'arst' field"))
        dw.append(("aro",          vrlg.SENS_CTRL_ARO,          1,   0,  "ARO signal to the sensor"))
        dw.append(("aro_set",      vrlg.SENS_CTRL_ARO + 1,      1,   0,  "ARO set to the 'aro' field"))
        dw.append(("mmcm_rst",     vrlg.SENS_CTRL_RST_MMCM,     1,   0,  "MMCM (for sensor clock) reset signal"))
        dw.append(("mmcm_rst_set", vrlg.SENS_CTRL_RST_MMCM + 1, 1,   0,  "MMCM reset set to  'mmcm_rst' field"))
        dw.append(("ign_embed",    vrlg.SENS_CTRL_IGNORE_EMBED, 1,   0,  "Ignore embedded data (non-image pixel lines"))
        dw.append(("ign_embed_set",vrlg.SENS_CTRL_IGNORE_EMBED + 1,1,0,  "Set mode to 'ign_embed' field"))
        dw.append(("set_dly",      vrlg.SENS_CTRL_LD_DLY,       1,   0,  "Set all pre-programmed delays to the sensor port input delays"))
        dw.append(("gp0",          vrlg.SENS_CTRL_GP0,          1,   0 , "GP0 multipurpose signal to the sensor"))
        dw.append(("gp0_set",      vrlg.SENS_CTRL_GP0 + 1,      1,   0,  "Set GP0 to 'gp0' value"))
        dw.append(("gp1",          vrlg.SENS_CTRL_GP1,          1,   0 , "GP1 multipurpose signal to the sensor"))
        dw.append(("gp1_set",      vrlg.SENS_CTRL_GP1 + 1,      1,   0,  "Set GP1 to 'gp1' value"))
        return dw
    
    def _enc_sensio_jtag(self):
        dw=[]
        dw.append(("tdi",          vrlg.SENS_JTAG_TDI,         1,   0,  "JTAG TDI level"))
        dw.append(("tdi_set",      vrlg.SENS_JTAG_TDI + 1,     1,   0,  "JTAG TDI set to 'tdi' field"))
        dw.append(("tms",          vrlg.SENS_JTAG_TMS,         1,   0,  "JTAG TMS level"))
        dw.append(("tms_set",      vrlg.SENS_JTAG_TMS + 1,     1,   0,  "JTAG TMS set to 'tms' field"))
        dw.append(("tck",          vrlg.SENS_JTAG_TCK,         1,   0,  "JTAG TCK level"))
        dw.append(("tck_set",      vrlg.SENS_JTAG_TCK + 1,     1,   0,  "JTAG TCK set to 'tck' field"))
        dw.append(("prog",         vrlg.SENS_JTAG_PROG,        1,   0,  "Sensor port PROG level"))
        dw.append(("prog_set",     vrlg.SENS_JTAG_PROG + 1,    1,   0,  "Sensor port PROG set to 'prog' field"))
        dw.append(("pgmen",        vrlg.SENS_JTAG_PGMEN,       1,   0 , "Sensor port PGMEN level"))
        dw.append(("pgmen_set",    vrlg.SENS_JTAG_PGMEN + 1,   1,   0,  "Sensor port PGMEN set to 'pgmen' field"))
        return dw
    """    
    def _enc_sensio_dly_par12(self):
        dw=[]
        dw.append(("pxd0",         0,  8,   0,  "PXD0  input delay (3 LSB not used)"))
        dw.append(("pxd1",         8,  8,   0,  "PXD1  input delay (3 LSB not used)"))
        dw.append(("pxd2",        16,  8,   0,  "PXD2  input delay (3 LSB not used)"))
        dw.append(("pxd3",        24,  8,   0,  "PXD3  input delay (3 LSB not used)"))
        
        dw.append(("pxd4",        32,  8,   0,  "PXD4  input delay (3 LSB not used)"))
        dw.append(("pxd5",        40,  8,   0,  "PXD5  input delay (3 LSB not used)"))
        dw.append(("pxd6",        48,  8,   0,  "PXD6  input delay (3 LSB not used)"))
        dw.append(("pxd7",        56,  8,   0,  "PXD7  input delay (3 LSB not used)"))
        
        dw.append(("pxd8",        64,  8,   0,  "PXD8  input delay (3 LSB not used)"))
        dw.append(("pxd9",        72,  8,   0,  "PXD9  input delay (3 LSB not used)"))
        dw.append(("pxd10",       80,  8,   0,  "PXD10 input delay (3 LSB not used)"))
        dw.append(("pxd11",       88,  8,   0,  "PXD11 input delay (3 LSB not used)"))
        
        dw.append(("hact",        96,  8,   0,  "HACT  input delay (3 LSB not used)"))
        dw.append(("vact",       104,  8,   0,  "VACT  input delay (3 LSB not used)"))
        dw.append(("bpf",        112,  8,   0,  "BPF (clock from sensor) input delay (3 LSB not used)"))
        dw.append(("phase_p",    120,  8,   0,  "MMCM phase"))
        return dw
    def _enc_sensio_dly_hispi(self):
        dw=[]
        dw.append(("fifo_lag",     0,  4,   7,  "FIFO delay to start output"))
        
        dw.append(("phys_lane0",  32,  2,   1,  "Physical lane for logical lane 0"))
        dw.append(("phys_lane1",  34,  2,   2,  "Physical lane for logical lane 1"))
        dw.append(("phys_lane2",  36,  2,   3,  "Physical lane for logical lane 2"))
        dw.append(("phys_lane3",  38,  2,   0,  "Physical lane for logical lane 3"))
        
        dw.append(("dly_lane0",   64,  8,   0,  "lane 0 (phys) input delay (3 LSB not used)"))
        dw.append(("dly_lane1",   72,  8,   0,  "lane 1 (phys) input delay (3 LSB not used)"))
        dw.append(("dly_lane2",   80,  8,   0,  "lane 2 (phys) input delay (3 LSB not used)"))
        dw.append(("dly_lane3",   88,  8,   0,  "lane 3 (phys) input delay (3 LSB not used)"))
        dw.append(("phase_h",     96,  8,   0,  "MMCM phase"))
        return dw
    """

        #Splitting into single DWORD structures
    def _enc_sensio_par12_tim0(self):
        dw=[]
        dw.append(("pxd0",         0,  8,   0,  "PXD0  input delay (3 LSB not used)"))
        dw.append(("pxd1",         8,  8,   0,  "PXD1  input delay (3 LSB not used)"))
        dw.append(("pxd2",        16,  8,   0,  "PXD2  input delay (3 LSB not used)"))
        dw.append(("pxd3",        24,  8,   0,  "PXD3  input delay (3 LSB not used)"))
        return dw
    def _enc_sensio_par12_tim1(self):
        dw=[]
        dw.append(("pxd4",         0,  8,   0,  "PXD4  input delay (3 LSB not used)"))
        dw.append(("pxd5",         8,  8,   0,  "PXD5  input delay (3 LSB not used)"))
        dw.append(("pxd6",        16,  8,   0,  "PXD6  input delay (3 LSB not used)"))
        dw.append(("pxd7",        24,  8,   0,  "PXD7  input delay (3 LSB not used)"))
        return dw
    def _enc_sensio_par12_tim2(self):
        dw=[]
        dw.append(("pxd8",         0,  8,   0,  "PXD8  input delay (3 LSB not used)"))
        dw.append(("pxd9",         8,  8,   0,  "PXD9  input delay (3 LSB not used)"))
        dw.append(("pxd10",       16,  8,   0,  "PXD10 input delay (3 LSB not used)"))
        dw.append(("pxd11",       24,  8,   0,  "PXD11 input delay (3 LSB not used)"))
        return dw
    def _enc_sensio_par12_tim3(self):
        dw=[]
        dw.append(("hact",         0,  8,   0,  "HACT  input delay (3 LSB not used)"))
        dw.append(("vact",         8,  8,   0,  "VACT  input delay (3 LSB not used)"))
        dw.append(("bpf",         16,  8,   0,  "BPF (clock from sensor) input delay (3 LSB not used)"))
        dw.append(("phase_p",     24,  8,   0,  "MMCM phase"))
        return dw
    
    def _enc_sensio_hispi_tim0(self):
        dw=[]
        dw.append(("fifo_lag",     0,  4,   7,  "FIFO delay to start output"))
        return dw
    def _enc_sensio_hispi_tim1(self):
        dw=[]
        dw.append(("phys_lane0",   0,  2,   1,  "Physical lane for logical lane 0"))
        dw.append(("phys_lane1",   2,  2,   2,  "Physical lane for logical lane 1"))
        dw.append(("phys_lane2",   4,  2,   3,  "Physical lane for logical lane 2"))
        dw.append(("phys_lane3",   6,  2,   0,  "Physical lane for logical lane 3"))
        return dw
    def _enc_sensio_hispi_tim2(self):
        dw=[]
        dw.append(("dly_lane0",    0,  8,   0,  "lane 0 (phys) input delay (3 LSB not used)"))
        dw.append(("dly_lane1",    8,  8,   0,  "lane 1 (phys) input delay (3 LSB not used)"))
        dw.append(("dly_lane2",   16,  8,   0,  "lane 2 (phys) input delay (3 LSB not used)"))
        dw.append(("dly_lane3",   24,  8,   0,  "lane 3 (phys) input delay (3 LSB not used)"))
        return dw
    def _enc_sensio_hispi_tim3(self):
        dw=[]
        dw.append(("phase_h",      0,  8,   0,  "MMCM phase"))
        return dw

    def _enc_sensio_width(self):
        dw=[]
        dw.append(("sensor_width", 0, 16,   0,  "Sensor frame width (0 - use line sync signals from the sensor)"))
        return dw

    def _enc_lens_addr(self):
        dw=[]
        dw.append(("addr",        16,  8,   0,  "Lens correction address, should be written first (overlaps with data)"))
        dw.append(("sub_chn",     24,  2,   0,  "Sensor subchannel"))
        return dw

    def _enc_lens_ax(self):
        dw=[]
        dw.append(("ax",           0, 19,   0x20000, "Coefficient Ax"))
        return dw

    def _enc_lens_ay(self):
        dw=[]
        dw.append(("ay",           0, 19,   0x20000, "Coefficient Ay"))
        return dw

    def _enc_lens_bx(self):
        dw=[]
        dw.append(("bx",           0, 21,   0x180000, "Coefficient Bx"))
        return dw

    def _enc_lens_by(self):
        dw=[]
        dw.append(("by",           0, 21,   0x180000, "Coefficient By"))
        return dw

    def _enc_lens_c(self):
        dw=[]
        dw.append(("c",            0, 19,   0x8000,   "Coefficient C"))
        return dw

    def _enc_lens_scale(self):
        dw=[]
        dw.append(("scale",        0, 17,   0x8000,   "Scale (4 per-color values)"))
        return dw

    def _enc_lens_fatzero_in(self):
        dw=[]
        dw.append(("fatzero_in",   0, 16,   0,  "'Fat zero' on the input (subtract from the input)"))
        return dw

    def _enc_lens_fatzero_out(self):
        dw=[]
        dw.append(("fatzero_out",  0, 16,   0,  "'Fat zero' on the output (add to the result)"))
        return dw

    def _enc_lens_post_scale(self):
        dw=[]
        dw.append(("post_scale",   0,  4,   1,  "Shift result (bits)"))
        return dw

    def _enc_lens_height_m1(self):
        dw=[]
        dw.append(("height_m1",    0, 16,   0,  "Height of subframe minus 1"))
        return dw

    def _enc_histogram_wh_m1(self):
        dw=[]
        dw.append(("width_m1" ,    0, 16,   0,  "Width of the histogram window minus 1. If 0 - use frame right margin (end of HACT)"))
        dw.append(("height_m1",   16, 16,   0,  "Height of he histogram window minus 1. If 0 - use frame bottom margin (end of VACT)"))
        return dw
    def _enc_histogram_lt(self):
        dw=[]
        dw.append(("left" ,        0, 16,   0,  "Histogram window left margin"))
        dw.append(("top",         16, 16,   0,  "Histogram window top margin"))
        return dw

    def _enc_hist_saxi_mode(self):
        dw=[]
        dw.append(("en" ,          vrlg.HIST_SAXI_EN,        1,   1,  "Enable histograms DMA"))
        dw.append(("nrst" ,        vrlg.HIST_SAXI_NRESET,    1,   1,  "0 - reset histograms DMA"))
        dw.append(("confirm" ,     vrlg.HIST_CONFIRM_WRITE,  1,   1,  "1 - wait for confirmation that histogram was written to the system memory"))
        dw.append(("cache" ,       vrlg.HIST_SAXI_AWCACHE,   4,   3,  "AXI cache mode (normal - 3), ignored by Zynq?"))
        return dw
    def _enc_hist_saxi_page_addr(self):
        dw=[]
        dw.append(("page" ,        0, 20,   0,  "Start address of the subchannel histogram (in pages = 4096 bytes"))
        return dw
    
    def _enc_cmprs_mode(self):
        dw=[]
        dw.append(("run",            vrlg.CMPRS_CBIT_RUN - vrlg.CMPRS_CBIT_RUN_BITS,       vrlg.CMPRS_CBIT_RUN_BITS,    0, "Run mode"))
        dw.append(("run_set",        vrlg.CMPRS_CBIT_RUN,                                                           1,  0, "Set 'run'"))
        dw.append(("qbank",          vrlg.CMPRS_CBIT_QBANK - vrlg.CMPRS_CBIT_QBANK_BITS,   vrlg.CMPRS_CBIT_QBANK_BITS,  0, "Quantization table bank"))
        dw.append(("qbank_set",      vrlg.CMPRS_CBIT_QBANK,                                                         1,  0, "Set 'qbank'"))
        dw.append(("dcsub",          vrlg.CMPRS_CBIT_DCSUB - vrlg.CMPRS_CBIT_DCSUB_BITS,   vrlg.CMPRS_CBIT_DCSUB_BITS,  0, "Subtract DC enable"))
        dw.append(("dcsub_set",      vrlg.CMPRS_CBIT_DCSUB,                                                         1,  0, "Set 'qbank'"))
        dw.append(("cmode",          vrlg.CMPRS_CBIT_CMODE - vrlg.CMPRS_CBIT_CMODE_BITS,   vrlg.CMPRS_CBIT_CMODE_BITS,  0, "Color format"))
        dw.append(("cmode_set" ,     vrlg.CMPRS_CBIT_CMODE,                                                         1,  0, "Set 'cmode'"))
        dw.append(("multiframe",     vrlg.CMPRS_CBIT_FRAMES - vrlg.CMPRS_CBIT_FRAMES_BITS, vrlg.CMPRS_CBIT_FRAMES_BITS, 0, "Multi/single frame mode"))
        dw.append(("multiframe_set", vrlg.CMPRS_CBIT_FRAMES,                                                         1, 0, "Set 'multiframe'"))
        dw.append(("bayer",          vrlg.CMPRS_CBIT_BAYER - vrlg.CMPRS_CBIT_BAYER_BITS,   vrlg.CMPRS_CBIT_BAYER_BITS,  0, "Bayer shift"))
        dw.append(("bayer_set",      vrlg.CMPRS_CBIT_BAYER,                                                          1, 0, "Set 'bayer'"))
        dw.append(("focus",          vrlg.CMPRS_CBIT_FOCUS - vrlg.CMPRS_CBIT_FOCUS_BITS,   vrlg.CMPRS_CBIT_FOCUS_BITS,  0, "Focus mode"))
        dw.append(("focus_set",      vrlg.CMPRS_CBIT_FOCUS,                                                          1, 0, "Set 'focus'"))
        return dw
    def _enc_cmprs_coring_sel(self):
        dw=[]
        dw.append(("coring_table",   0,       vrlg.CMPRS_CORING_BITS,    0, "Select coring table pair number"))
        return dw
    def _enc_cmprs_color_sat(self):
        dw=[]
        dw.append(("colorsat_blue",   vrlg.CMPRS_CSAT_CB,       vrlg.CMPRS_CSAT_CB_BITS,   0x120, "Color saturation for blue (0x90 - 100%)"))
        dw.append(("colorsat_red",    vrlg.CMPRS_CSAT_CR,       vrlg.CMPRS_CSAT_CR_BITS,   0x16c, "Color saturation for red (0xb6 - 100%)"))
        return dw
    def _enc_cmprs_format(self):
        dw=[]
        dw.append(("num_macro_cols_m1", vrlg.CMPRS_FRMT_MBCM1,       vrlg.CMPRS_FRMT_MBCM1_BITS,   0, "Number of macroblock colums minus 1"))
        dw.append(("num_macro_rows_m1", vrlg.CMPRS_FRMT_MBRM1,       vrlg.CMPRS_FRMT_MBRM1_BITS,   0, "Number of macroblock rows minus 1"))
        dw.append(("left_margin",       vrlg.CMPRS_FRMT_LMARG,       vrlg.CMPRS_FRMT_LMARG_BITS,   0, "Left margin of the first pixel (0..31) for 32-pixel wide colums in memory access"))
        return dw
    def _enc_cmprs_interrupts(self):
        dw=[]
        dw.append(("interrupt_cmd",      0, 2,   0, "0: nop, 1: clear interrupt status, 2: disable interrupt, 3: enable interrupt"))
        return dw
    def _enc_cmprs_table_addr(self):
        dw=[]
        dw.append(("addr32",    0, 24,   0, "Table address to start writing to (autoincremented) for DWORDs"))
        dw.append(("type",     24, 2,    0, "0: quantization, 1: coring, 2: focus, 3: huffman"))
        return dw
    
    def _enc_cmprs_status(self):
        dw=[]
        dw.append(("is",              0,   1,   0, "Compressor channel interrupt status"))
        dw.append(("im",              1,   1,   0, "Compressor channel interrupt mask"))
        dw.append(("reading_frame",   2,   1,   0, "Compressor channel is reading frame from memory (debug feature)"))
        dw.append(("stuffer_running", 3,   1,   0, "Compressor channel bit stuffer is running (debug feature)"))
        dw.append(("flushing_fifo",   4,   1,   0, "Compressor channel is flushing FIFO (debug feature)"))
        dw.append(("frame",           8,   vrlg.NUM_FRAME_BITS, 0, "Compressed frame number (mod %d)"%(1 << vrlg.NUM_FRAME_BITS)))
        dw.append(("seq_num",        26,   6,   0, "Status sequence number"))
        return dw
    
    def _enc_cmprs_afimux_sa(self):
        dw=[]
        dw.append(("sa256",     0, 27,   0, "System memory buffer start in multiples of 32 bytes (256 bits)"))
        return dw
    def _enc_cmprs_afimux_len(self):
        dw=[]
        dw.append(("len256",    0, 27,   0, "System memory buffer length in multiples of 32 bytes (256 bits)"))
        return dw
    def _enc_cmprs_afimux_rst(self):
        dw=[]
        dw.append(("rst0",      0,  1,   0, "AXI HPx sub-channel0 reset (0 - normal operation, 1 - reset)"))
        dw.append(("rst1",      1,  1,   0, "AXI HPx sub-channel0 reset (0 - normal operation, 1 - reset)"))
        dw.append(("rst2",      2,  1,   0, "AXI HPx sub-channel0 reset (0 - normal operation, 1 - reset)"))
        dw.append(("rst3",      3,  1,   0, "AXI HPx sub-channel0 reset (0 - normal operation, 1 - reset)"))
        return dw
    def _enc_cmprs_afimux_en(self):
        dw=[]
        dw.append(("en0",       0,  1,   0, "AXI HPx sub-channel0 enable value to set (0 - pause, 1 - run)"))
        dw.append(("en0_set",   1,  1,   0, "0 - nop, 1 - set en0"))
        dw.append(("en1",       2,  1,   0, "AXI HPx sub-channel1 enable value to set (0 - pause, 1 - run)"))
        dw.append(("en1_set",   3,  1,   0, "0 - nop, 1 - set en1"))
        dw.append(("en2",       4,  1,   0, "AXI HPx sub-channel2 enable value to set (0 - pause, 1 - run)"))
        dw.append(("en2_set",   5,  1,   0, "0 - nop, 1 - set en2"))
        dw.append(("en3",       6,  1,   0, "AXI HPx sub-channel3 enable value to set (0 - pause, 1 - run)"))
        dw.append(("en3_set",   7,  1,   0, "0 - nop, 1 - set en3"))
        dw.append(("en",        8,  1,   0, "AXI HPx global enable value to set (0 - pause, 1 - run)"))
        dw.append(("en_set",    9,  1,   0, "0 - nop, 1 - set en"))
        return dw

    def _enc_cmprs_afimux_report(self):
        dw=[]
        dw.append(("mode0",     0,  2,   0, "channel0 report mode: 0 - EOF int, 1 - EOF confirmed, 2 - CP (current), 3 - CP confirmed"))
        dw.append(("mode0_set", 2,  1,   0, "0 - nop, 1 - set mode0"))
        dw.append(("mode1",     4,  2,   0, "channel0 report mode: 0 - EOF int, 1 - EOF confirmed, 2 - CP (current), 3 - CP confirmed"))
        dw.append(("mode1_set", 6,  1,   0, "0 - nop, 1 - set mode0"))
        dw.append(("mode2",     8,  2,   0, "channel0 report mode: 0 - EOF int, 1 - EOF confirmed, 2 - CP (current), 3 - CP confirmed"))
        dw.append(("mode2_set",10,  1,   0, "0 - nop, 1 - set mode0"))
        dw.append(("mode3",    12,  2,   0, "channel0 report mode: 0 - EOF int, 1 - EOF confirmed, 2 - CP (current), 3 - CP confirmed"))
        dw.append(("mode3_set",14,  1,   0, "0 - nop, 1 - set mode0"))
        return dw

    def _enc_cmprs_afimux_status(self):
        dw=[]
        dw.append(("offset256", 0, 26,   0, "AFI MUX current/EOF pointer offset in 32-byte blocks"))
        dw.append(("seq_num",  26,  6,   0, "Status sequence number"))
        return dw

    def _enc_cmprs_gpio_out(self):
        dw=[]
        dw.append(("pin0",      0,  2,   0, "Output control for pin 0: 0 - nop, 1 - set low, 2 - set high, 3 - tristate"))
        dw.append(("pin1",      2,  2,   0, "Output control for pin 1: 0 - nop, 1 - set low, 2 - set high, 3 - tristate"))
        dw.append(("pin2",      4,  2,   0, "Output control for pin 2: 0 - nop, 1 - set low, 2 - set high, 3 - tristate"))
        dw.append(("pin3",      6,  2,   0, "Output control for pin 3: 0 - nop, 1 - set low, 2 - set high, 3 - tristate"))
        dw.append(("pin4",      8,  2,   0, "Output control for pin 4: 0 - nop, 1 - set low, 2 - set high, 3 - tristate"))
        dw.append(("pin5",     10,  2,   0, "Output control for pin 5: 0 - nop, 1 - set low, 2 - set high, 3 - tristate"))
        dw.append(("pin6",     12,  2,   0, "Output control for pin 6: 0 - nop, 1 - set low, 2 - set high, 3 - tristate"))
        dw.append(("pin7",     14,  2,   0, "Output control for pin 7: 0 - nop, 1 - set low, 2 - set high, 3 - tristate"))
        dw.append(("pin8",     16,  2,   0, "Output control for pin 8: 0 - nop, 1 - set low, 2 - set high, 3 - tristate"))
        dw.append(("pin9",     18,  2,   0, "Output control for pin 0: 0 - nop, 1 - set low, 2 - set high, 3 - tristate"))
        dw.append(("soft",     24,  2,   0, "Enable pin software control: 0,1 - nop, 2 - disab;e, 3 - enable"))
        dw.append(("chn_a",    26,  2,   0, "Enable A channel (camsync): 0,1 - nop, 2 - disab;e, 3 - enable"))
        dw.append(("chn_b",    28,  2,   0, "Enable B channel (reserved): 0,1 - nop, 2 - disab;e, 3 - enable"))
        dw.append(("chn_c",    30,  2,   0, "Enable C channel (logger): 0,1 - nop, 2 - disab;e, 3 - enable"))
        return dw

    def _enc_cmprs_gpio_status(self):
        dw=[]
        dw.append(("pin0",      0,  1,   0, "GPIO pin 0 state"))
        dw.append(("pin1",      1,  1,   0, "GPIO pin 0 state"))
        dw.append(("pin2",      2,  1,   0, "GPIO pin 0 state"))
        dw.append(("pin3",      3,  1,   0, "GPIO pin 0 state"))
        dw.append(("pin4",      4,  1,   0, "GPIO pin 0 state"))
        dw.append(("pin5",      5,  1,   0, "GPIO pin 0 state"))
        dw.append(("pin6",      6,  1,   0, "GPIO pin 0 state"))
        dw.append(("pin7",      7,  1,   0, "GPIO pin 0 state"))
        dw.append(("pin8",      8,  1,   0, "GPIO pin 0 state"))
        dw.append(("pin9",      9,  1,   0, "GPIO pin 0 state"))
        dw.append(("seq_num",  26,  6,   0, "Status sequence number"))
        return dw

    def _enc_rtc_sec(self):
        dw=[]
        dw.append(("sec",       0, 32,   0, "RTC seconds"))
        return dw
    def _enc_rtc_usec(self):
        dw=[]
        dw.append(("usec",      0, 20,   0, "RTC microseconds"))
        return dw
    def _enc_rtc_corr(self):
        dw=[]
        dw.append((("corr","short"), 0, 16,   0, "RTC correction, +/1 1/256 full scale"))
        return dw
    def _enc_rtc_status(self):
        dw=[]
        dw.append(("alt_snap", 24,  1,   0, "alternates 0/1 each time RTC timer makes a snapshot"))
        dw.append(("seq_num",  26,  6,   0, "Status sequence number"))
        return dw

    def _enc_camsync_lines(self):
        dw=[]
        dw.append(("line0",    0,   2,   1, "line 0 mode: 0 - inactive, 1 - keep (nop), 2 - active low, 3 - active high"))
        dw.append(("line1",    2,   2,   1, "line 1 mode: 0 - inactive, 1 - keep (nop), 2 - active low, 3 - active high"))
        dw.append(("line2",    4,   2,   1, "line 2 mode: 0 - inactive, 1 - keep (nop), 2 - active low, 3 - active high"))
        dw.append(("line3",    6,   2,   1, "line 3 mode: 0 - inactive, 1 - keep (nop), 2 - active low, 3 - active high"))
        dw.append(("line4",    8,   2,   1, "line 4 mode: 0 - inactive, 1 - keep (nop), 2 - active low, 3 - active high"))
        dw.append(("line5",   10,   2,   1, "line 5 mode: 0 - inactive, 1 - keep (nop), 2 - active low, 3 - active high"))
        dw.append(("line6",   12,   2,   1, "line 6 mode: 0 - inactive, 1 - keep (nop), 2 - active low, 3 - active high"))
        dw.append(("line7",   14,   2,   1, "line 7 mode: 0 - inactive, 1 - keep (nop), 2 - active low, 3 - active high"))
        dw.append(("line8",   16,   2,   1, "line 8 mode: 0 - inactive, 1 - keep (nop), 2 - active low, 3 - active high"))
        dw.append(("line9",   18,   2,   1, "line 9 mode: 0 - inactive, 1 - keep (nop), 2 - active low, 3 - active high"))
        return dw
    def _enc_camsync_mode(self):
        dw=[]
        dw.append(("en",             vrlg.CAMSYNC_EN_BIT-1,             1,   1, "Enable CAMSYNC module"))
        dw.append(("en_set",         vrlg.CAMSYNC_EN_BIT,             1,   1, "Set 'en' bit"))
        dw.append(("en_snd",         vrlg.CAMSYNC_SNDEN_BIT-1,        1,   1, "Enable sending timestamps (valid with 'en_snd_set')"))
        dw.append(("en_snd_set",     vrlg.CAMSYNC_SNDEN_BIT,          1,   0, "Set 'en_snd'"))
        dw.append(("ext",            vrlg.CAMSYNC_EXTERNAL_BIT - 1,   1,   1, "Use external (received) timestamps, if available. O - use local timestamps"))
        dw.append(("ext_set",        vrlg.CAMSYNC_EXTERNAL_BIT,       1,   0, "Set 'ext'"))
        dw.append(("trig",           vrlg.CAMSYNC_TRIGGERED_BIT - 1,  1,   1, "Sensor triggered mode (0 - free running sensor)"))
        dw.append(("trig_set",       vrlg.CAMSYNC_TRIGGERED_BIT,      1,   0, "Set 'trig'"))
        dw.append(("master_chn",     vrlg.CAMSYNC_MASTER_BIT - 2,     2,   0, "master sensor channel (zero delay in internal trigger mode, delay used for flash output)"))
        dw.append(("master_chn_set", vrlg.CAMSYNC_MASTER_BIT,         1,   0, "Set 'master_chn'"))
        dw.append(("ts_chns",        vrlg.CAMSYNC_CHN_EN_BIT - 7,     4,   1, "Channels to generate timestmp messages (bit mask)"))
        dw.append(("ts_chns_set",    vrlg.CAMSYNC_CHN_EN_BIT - 3,     4,   0, "Sets for 'ts_chns' (each bit controls corresponding 'ts_chns' bit)"))
        return dw

    def _enc_cmdframeseq_mode(self):
        dw=[]
        dw.append(("interrupt_cmd",  vrlg.CMDFRAMESEQ_IRQ_BIT,        2,   0, "Interrupt command: 0-nop, 1 - clear is, 2 - disable, 3 - enable"))
        dw.append(("run_cmd",        vrlg.CMDFRAMESEQ_RUN_BIT - 1,    2,   0, "Run command: 0,1 - nop, 2 - stop, 3 - run"))
        dw.append(("reset",          vrlg.CMDFRAMESEQ_RST_BIT,        1,   0, "1 - reset, 0 - normal operation"))
        return dw

    def _enc_cmdseqmux_status(self):
        dw=[]
        dw.append(("frame_num0",  0,  4,   0, "Frame number for sensor 0"))
        dw.append(("frame_num1",  4,  4,   0, "Frame number for sensor 1"))
        dw.append(("frame_num2",  8,  4,   0, "Frame number for sensor 2"))
        dw.append(("frame_num3", 12,  4,   0, "Frame number for sensor 3"))

        dw.append(("is",         16,  4,   0, "Interrupt status: 1 bit per sensor channel"))
        dw.append(("im",         20,  4,   0, "Interrupt enable: 1 bit per sensor channel"))
        
        dw.append(("seq_num",    26,  6,   0, "Status sequence number"))
        return dw

    def _enc_logger_status(self):
        dw=[]
        dw.append(("sample",      0, 24,   0, "Logger sample number"))
        dw.append(("seq_num",    26,  6,   0, "Status sequence number"))
        return dw

    def _enc_logger_reg_addr(self):
        dw=[]
        dw.append(("addr",        0,  5,   0, "Register address (autoincrements in 32 DWORDs (page) range"))
        dw.append(("page",        5,  2,   0, "Register page: configuration: 0, IMU: %d, GPS: %d, MSG: %d"%(vrlg.LOGGER_PAGE_IMU, vrlg.LOGGER_PAGE_GPS, vrlg.LOGGER_PAGE_MSG)))
        return dw

    def _enc_logger_conf(self):
        dw=[]
        dw.append(("imu_slot",   vrlg.LOGGER_CONF_IMU - vrlg.LOGGER_CONF_IMU_BITS,  vrlg.LOGGER_CONF_IMU_BITS,   0, "IMU slot"))
        dw.append(("imu_set",    vrlg.LOGGER_CONF_IMU,                                  1,                       0, "Set 'imu_slot'"))
        dw.append(("gps_slot",   vrlg.LOGGER_CONF_GPS - vrlg.LOGGER_CONF_GPS_BITS,      2,                       0, "GPS slot"))
        dw.append(("gps_invert", vrlg.LOGGER_CONF_GPS - vrlg.LOGGER_CONF_GPS_BITS + 2,  1,                       0, "GPS inpert 1pps signal"))
        dw.append(("gps_ext",    vrlg.LOGGER_CONF_GPS - vrlg.LOGGER_CONF_GPS_BITS + 3,  1,                       0, "GPS sync to 1 pps signal (0 - sync to serial message)"))
        dw.append(("gps_set",    vrlg.LOGGER_CONF_GPS,                                  1,                       0, "Set 'gps_*' fields"))
        dw.append(("msg_input",  vrlg.LOGGER_CONF_MSG - vrlg.LOGGER_CONF_MSG_BITS,      4,                       0, "MSG pin: GPIO pin number to accept external signal (0xf - disable)"))
        dw.append(("msg_invert", vrlg.LOGGER_CONF_MSG - vrlg.LOGGER_CONF_MSG_BITS + 4,  1,                       0, "MSG input polarity - 0 - active high, 1 - active low"))
        dw.append(("msg_set",    vrlg.LOGGER_CONF_MSG,                                  1,                       0, "Set 'msg_*' fields"))
        dw.append(("log_sync",   vrlg.LOGGER_CONF_SYN - vrlg.LOGGER_CONF_SYN_BITS,  vrlg.LOGGER_CONF_SYN_BITS,   0, "Log frame sync events (bit per sensor channel)"))
        dw.append(("log_sync_set",vrlg.LOGGER_CONF_SYN,                                 1,                       0, "Set 'log_sync' fields"))
        return dw
    def _enc_logger_data(self):
        dw=[]
        dw.append(("data",      0, 32,   0, "Other logger register data (context-dependent)"))
        return dw

    def _enc_mult_saxi_addr(self):
        dw=[]
        dw.append(("addr32",    0, 30,   0, "SAXI address/length in DWORDs"))
        return dw
    def _enc_mult_saxi_irqlen(self):
        dw=[]
        dw.append(("irqlen",      0, 5,   0, "lowest DW address bit that has to change to generate interrupt"))
        return dw

    def _enc_mult_saxi_mode(self):
        dw=[]
        dw.append(("en0",          0, 1,   0, "Channel 0 enable (0 - reset)"))
        dw.append(("en1",          1, 1,   0, "Channel 1 enable (0 - reset)"))
        dw.append(("en2",          2, 1,   0, "Channel 2 enable (0 - reset)"))
        dw.append(("en3",          3, 1,   0, "Channel 3 enable (0 - reset)"))
        dw.append(("run0",         4, 1,   0, "Channel 0 run (0 - stop)"))
        dw.append(("run1",         5, 1,   0, "Channel 1 run (0 - stop)"))
        dw.append(("run2",         6, 1,   0, "Channel 2 run (0 - stop)"))
        dw.append(("run3",         7, 1,   0, "Channel 3 run (0 - stop)"))
        return dw

    def _enc_mult_saxi_interrupts(self):
        dw=[]
        dw.append(("interrupt_cmd0", 0, 2,   0, "Channel 0 command - 0: nop, 1: clear interrupt status, 2: disable interrupt, 3: enable interrupt"))
        dw.append(("interrupt_cmd1", 2, 2,   0, "Channel 1 command - 0: nop, 1: clear interrupt status, 2: disable interrupt, 3: enable interrupt"))
        dw.append(("interrupt_cmd2", 4, 2,   0, "Channel 2 command - 0: nop, 1: clear interrupt status, 2: disable interrupt, 3: enable interrupt"))
        dw.append(("interrupt_cmd3", 6, 2,   0, "Channel 3 command - 0: nop, 1: clear interrupt status, 2: disable interrupt, 3: enable interrupt"))
        return dw

    def _enc_mult_saxi_status(self):
        dw=[]
        dw.append(("irq_r0",      0,  1,   0, "Channel 0 interrupt request (not masked)"))
        dw.append(("irq_r1",      1,  1,   0, "Channel 1 interrupt request (not masked)"))
        dw.append(("irq_r2",      2,  1,   0, "Channel 2 interrupt request (not masked)"))
        dw.append(("irq_r3",      3,  1,   0, "Channel 3 interrupt request (not masked)"))
        dw.append(("irq_m0",      4,  1,   0, "Channel 0 interrupt enable"))
        dw.append(("irq_m1",      5,  1,   0, "Channel 1 interrupt enable"))
        dw.append(("irq_m2",      6,  1,   0, "Channel 2 interrupt enable"))
        dw.append(("irq_m3",      7,  1,   0, "Channel 3 interrupt enable"))
        dw.append(("tgl",        24,  1,   0, "toggles at any address change"))
        dw.append(("seq_num",    26,  6,   0, "Status sequence number"))
        return dw

    
    def _enc_multiclk_ctl(self):
        dw=[]
        dw.append(("rst_clk0",    0, 1,   0, "Reset PLL for xclk(240MHz), hclk(150MHz)"))
        dw.append(("rst_clk1",    1, 1,   0, "Reset PLL for pclk (sensors, from ffclk0)"))
        dw.append(("rst_clk2",    2, 1,   0, "reserved"))
        dw.append(("rst_clk3",    3, 1,   0, "reserved"))
        dw.append(("pwrdwnclk0",  4, 1,   0, "Power down PLL for xclk(240MHz), hclk(150MHz)"))
        dw.append(("pwrdwn_clk1", 5, 1,   0, "Power down for pclk (sensors, from ffclk0)"))
        dw.append(("pwrdwn_clk2", 6, 1,   0, "reserved"))
        dw.append(("pwrdwn_clk3", 7, 1,   0, "reserved"))
        dw.append(("rst_memclk",  8, 1,   0, "reset memclk (external in for memory) toggle FF"))
        dw.append(("rst_ffclk0",  9, 1,   0, "reset ffclk0 (external in for sensors) toggle FF"))
        dw.append(("rst_ffclk1", 10, 1,   0, "reset ffclk1 (exteranl in, not yet used) toggle FF"))
        return dw

    def _enc_multiclk_status(self):
        dw=[]
        dw.append(("locked0",     0, 1,   0, "Locked PLL for xclk(240MHz), hclk(150MHz)"))
        dw.append(("locked1",     1, 1,   0, "Locked PLL for pclk (sensors, from ffclk0)"))
        dw.append(("locked2",     2, 1,   0, "==1, reserved"))
        dw.append(("locked3",     3, 1,   0, "==1, reserved"))
        dw.append(("tgl_memclk",  4, 1,   0, "memclk (external in for memory) toggle FF"))
        dw.append(("tgl_ffclk0",  5, 1,   0, "ffclk0 (external in for sensors) toggle FF"))
        dw.append(("tgl_ffclk1",  6, 1,   0, "ffclk1 (exteranl in, not yet used) toggle FF"))
        dw.append(("idelay_rdy", 24, 1,   0, "idelay_ctrl_rdy (juct to prevent from optimization)"))
        dw.append(("seq_num",    26, 6,   0, "Status sequence number"))
        return dw
    
    def _enc_debug_status(self):
        dw=[]
        dw.append(("tgl",        24,  1,   0, "Toggles for each DWORD received"))
        dw.append(("seq_num",    26,  6,   0, "Status sequence number"))
        return dw
    
    
    
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
        if padLast and (next_bit % wlen):
            padded_data.append(("", next_bit, wlen- (next_bit % wlen), 0,""))
        return padded_data        
            
            
            
    
    def get_typedef32(self, comment, data, name, typ, frmt_spcs):
        
        """
        TODO: add alternative to bit fields 
        """
        frmt_spcs=self.fix_frmt_spcs(frmt_spcs)
#        print("data=",data)
#        print("1.data[0]=",data[0])
        if frmt_spcs['data32']:
            if not isinstance(data[0],list):
                data=[data]
            data.append([(frmt_spcs['data32'],    0,  32,   0, "cast to "+frmt_spcs['ftype'])])
        isUnion = isinstance(data[0],list)
#        print("2.data[0]=",data[0])
        s = ""
#        s = "\n"
#        if comment:
#            s += "// %s\n\n"%(comment)
        if isUnion:
            frmt_spcs['lastPad'] = True
            s += "typedef union {\n"
        else:
            data = [data]
        sz=0
        #check for the same named members, verify they map to the same bit fields, replace with unnamed and move names to comments
        members = {} # name:tuple of (start, len)
        for ns,struct in enumerate(data):    
            lines=self.get_pad32(struct, wlen=32, name=name, padLast=frmt_spcs['lastPad'])
#            lines.reverse()
            #nameMembers
            if isUnion:
                s += "    struct {\n"
            else:
                s += "typedef struct {\n"
            frmt= "%s    %%5s %%%ds:%%2d;"%(("","    ")[isUnion], max([len(i[0]) for i in lines]+[ frmt_spcs['nameLength']]))
            for line in lines:
                start_bit = 0
                n = line[0]
                t = frmt_spcs['ftype']
                if isinstance(n,(list,tuple)):
                    t = n[1]
                    n = n[0]
                if n in members: #same bitfield is already defined, make unnamed, move to comment
                    #Verify it matches the original
                    if not (start_bit,line[2]) == members[n]:
                        print ("*** Error: in typdef for %s bitfield %s had start bit = %d, length = %d and later it has start bit = %d, length %d" %
                                (name+'_t',members[n][0], members[n][1],start_bit, line[2]))
                        print ("It needs to be resolved manually renamed?), for now keeping conflicting members")
                        n += "_CONFLICT"
                    else:    
                        n = "/*%s*/"%(n)
                else:
                    if n:
                        members[n] =  (start_bit,line[2])
                start_bit += line[2]
                s += frmt%( t, n, line[2])
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
            sz=lines[0][1]+lines[0][2]
                   
            if isUnion:
                if frmt_spcs['nameMembers']:
                    s += "    } struct_%d;\n"%(ns)
                else:
                    s += "    }; \n"
        s += "} %s_t; \n"%(name)
        self.typedefs[name+'_t']= {'comment':comment, 'code':s, 'size':sz, 'type':typ} # type - not used ?
        if comment:
            return "\n// %s\n\n"%(comment) + s
        else:
            return "\n"+s 

    def fix_frmt_spcs(self,frmt_spcs):
        specs= frmt_spcs;    
        if not specs:
            specs = {}
        for k in self.dflt_frmt_spcs:
            if not k in specs:
                specs[k] =  self.dflt_frmt_spcs[k]
        return specs         
        
            
                
        