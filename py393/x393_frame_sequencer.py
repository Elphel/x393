from __future__ import division
from __future__ import print_function

'''
# Copyright (C) 2015, Elphel.inc.
# Class to control 10393 Frame sequencer that allows storing and applying
# register writes synchronized by the sensors frame sync  
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
class X393FrameSequencer(object):
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

    def ctrl_cmd_frame_sequencer (self,
                                  num_sensor,
                                  reset = False,
                                  start = False,
                                  stop = False):
        """
        Control frame sequence
        @param num_sensor -  sensor channel number
        @param reset -       reset sequencer (also stops)
        @param start -       start sequencer
        @param stop -        stop sequencer
        """
        data = 0;
        if reset:
            data |= 1 <<  vrlg.CMDFRAMESEQ_RST_BIT
        if start:
            data |= 1 << (vrlg.CMDFRAMESEQ_RUN_BIT -1)
        if start or stop:
            data |= 1 <<  vrlg.CMDFRAMESEQ_RUN_BIT
        self.x393_axi_tasks.write_contol_register(
                vrlg.CMDFRAMESEQ_ADDR_BASE + num_sensor * vrlg.CMDFRAMESEQ_ADDR_INC + vrlg.CMDFRAMESEQ_CTRL,
                data)

    def write_cmd_frame_sequencer (self,
                                  num_sensor,
                                  relative,
                                  frame_addr,
                                  addr,
                                  data):
        """
        Schedule/execute frame sequence command (register write)
        @param num_sensor -  sensor channel number
        @param relative -    False - use absolute address (0..15), True - use relative (to current frame) address - 0..14
                             writes to relative address 0 are considered ASAP and do not wait for the frame sync
        @param frame_addr -  4-bit frame address (relative or absolute), relative must be < 15
        @param addr;         // command address (register to which command should be applied), 32 word (not byte) address, relative to maxi0 space
        @param data;         // command data to write
        """
        frame_addr &= 0xf
        if relative and (frame_addr == 0xf):
            raise Exception ("task write_cmd_frame_sequencer(): relative address 0xf is invalid, it is reserved for module control")
        reg_addr = vrlg.CMDFRAMESEQ_ADDR_BASE + num_sensor * vrlg.CMDFRAMESEQ_ADDR_INC + (vrlg.CMDFRAMESEQ_ABS,vrlg.CMDFRAMESEQ_REL)[relative] + frame_addr
        self.x393_axi_tasks.write_contol_register( reg_addr,  addr) # two writes to the same location - first is the register address
        self.x393_axi_tasks.write_contol_register( reg_addr,  data) # second is data to write to that register

