from __future__ import division
from __future__ import print_function

'''
# Copyright (C) 2015, Elphel.inc.
# Class to control image acquisition and compression functionality  
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
SI5338_PATH =   "/sys/devices/amba.0/e0004000.ps7-i2c/i2c-0/0-0070"
POWER393_PATH = "/sys/devices/elphel393-pwr.1"
class X393SensCmprs(object):
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
    def setSensorClock(self, freq_MHz = 24.0):
        """
        Set up external clock for sensor-synchronous circuitry (and sensor(s) themselves. 
        Currently required clock frequency is 1/4 of the sensor clock, so it is 24MHz for 96MHz sensor
        @param freq_MHz - input clock frequency (MHz). Currently for 96MHZ sensor clock it should be 24.0 
        """
        with open ( SI5338_PATH + "/output_drivers/2V5_LVDS",      "w") as f:
            print("1", file = f)
        with open ( SI5338_PATH + "/output_clocks/out1_freq_fract","w") as f:
            print("%d"%(round(1000000*freq_MHz)), file = f )
    def setSensorPower(self, sub_pair=0, power_on=0):
        """
        @param sub_pair - pair of the sensors: 0 - sensors 1 and 2, 1 - sensors 3 and 4 
        @param power_on - 1 - power on, 0 - power off (both sensor power and interface/FPGA bank voltage) 
        """
        with open (POWER393_PATH + "/channels_"+ ("dis","en")[power_on],"w") as f:
            print(("vcc_sens01 vp33sens01", "vcc_sens23 vp33sens23")[sub_pair], file = f)
        
