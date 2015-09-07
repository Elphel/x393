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

import x393_utils

#import time
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
                                  4: auto, inc sequence number 
        @param seq_number - 6-bit sequence number of the status message to be sent
        
        """
        self.x393_axi_tasks.program_status (
                        vrlg.CMPRS_GROUP_ADDR + (vrlg.CMPRS_AFIMUX_RADDR0,vrlg.CMPRS_AFIMUX_RADDR1)[port_afi] + chn_afi,
                        vrlg.CMPRS_AFIMUX_STATUS_CNTRL,
                        mode,
                        seq_num)

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

