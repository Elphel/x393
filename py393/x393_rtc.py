from __future__ import division
from __future__ import print_function

'''
# Copyright (C) 2015, Elphel.inc.
# Class to control 10393 FPGA-based real time clock 
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

import time
import vrlg
class X393Rtc(object):
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
        
    def program_status_rtc(self,
                            mode,     # input [1:0] mode;
                            seq_num): # input [5:0] seq_num;
        """
        Set status generation mode for RTC. It also takes a snapshot that will
        be available before status is read back (so use non-auto mode)
        @param mode -       status generation mode:
                                  0: disable status generation,
                                  1: single status request,
                                  2: auto status, keep specified seq number,
                                  3: auto, inc sequence number 
        @param seq_number - 6-bit sequence number of the status message to be sent
        """

        self.x393_axi_tasks.program_status (vrlg.RTC_ADDR,
                                            vrlg.RTC_SET_STATUS,
                                            mode,
                                            seq_num)
    def set_rtc(self,    
                    sec =  None,
                    usec = 0,
                    corr = 0):
        """
        Set RTC time and correction
        @param sec -  number of seconds (usually epoch)
        @param usec - number of microseconds
        @parame corr signed 16-bit correction (full range is +/- 1/256
        """
#>>> time.time()
#1440958713.117321
        if sec is None:
            t =  time.time()
            sec = int (t)
            usec = int (1000 * (t - sec))
        self.x393_axi_tasks.write_control_register(vrlg.RTC_ADDR + vrlg.RTC_SET_CORR, corr);
        self.x393_axi_tasks.write_control_register(vrlg.RTC_ADDR + vrlg.RTC_SET_USEC, usec);
        self.x393_axi_tasks.write_control_register(vrlg.RTC_ADDR + vrlg.RTC_SET_SEC,  sec);

 
