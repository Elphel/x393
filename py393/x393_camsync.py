from __future__ import division
from __future__ import print_function

'''
# Copyright (C) 2015, Elphel.inc.
# Class to control camsync (inter-camera synchronization) module  
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
import x393_gpio

import x393_utils

#import time
import vrlg

#  parameter SYNC_BIT_LENGTH=8-1; /// 7 pixel clock pulses
SYNC_BIT_LENGTH=8-1 # 7 pixel clock pulses

class X393Camsync(object):
    DRY_MODE= True # True
    DEBUG_MODE=1
    x393_mem=None
    x393_axi_tasks=None #x393X393AxiControlStatus
    X393_gpio=None
    x393_utils=None
    verbose=1
    def __init__(self, debug_mode=1,dry_mode=True, saveFileName=None):
        self.DEBUG_MODE=  debug_mode
        self.DRY_MODE=    dry_mode
        self.x393_mem=            X393Mem(debug_mode,dry_mode)
        self.x393_axi_tasks=      x393_axi_control_status.X393AxiControlStatus(debug_mode,dry_mode)
        self.x393_utils=          x393_utils.X393Utils(debug_mode,dry_mode, saveFileName) # should not overwrite save file path
        self.X393_gpio =          x393_gpio.X393GPIO(debug_mode,dry_mode, saveFileName)
        try:
            self.verbose=vrlg.VERBOSE
        except:
            pass
    def set_camsync_mode (self,
                          en =             None,
                          en_snd =         None,
                          en_ts_external = None,
                          triggered_mode = None,
                          master_chn =     None,
                          chn_en =         None):
        """
        Control camsync operational mode (None means "keep current value")
        set_camsync_mode (0) 
        @param en True - enable, False - reset module
        @param en_snd  - enable sending timestamp with the sync pulse
        @param en_ts_external - True - use received timestamp in the image file, False - use local timestamp 
        @param triggered_mode - False - async (free running) sensor mode, True - triggered (global reset) sensor mode
        @param master_chn -     sensor channel used as a synchronization source (delay used for flash in internal triggered mode)
        @param chn_en -         bitmask of enabled channels
        """
        data = 0
        if not en is None:
            data |= (2,3)[en] << (vrlg.CAMSYNC_EN_BIT - 1)
#        if en:
#            data |= 1 << vrlg.CAMSYNC_EN_BIT     
        if not en_snd is None:
            data |= (2,3)[en_snd] << (vrlg.CAMSYNC_SNDEN_BIT - 1)
        if not en_ts_external is None:
            data |= (2,3)[en_ts_external] << (vrlg.CAMSYNC_EXTERNAL_BIT - 1)
        if not triggered_mode is None:
            data |= (2,3)[triggered_mode] << (vrlg.CAMSYNC_TRIGGERED_BIT - 1)
        if not master_chn is None:
            data |=  (4 | (master_chn & 3)) << (vrlg.CAMSYNC_MASTER_BIT - 2)
        if not chn_en is None:
#            data |=  (0x10 | (chn_en & 0xf)) << (vrlg.CAMSYNC_CHN_EN_BIT - 4)
            data |=  (0xf0 | (chn_en & 0xf)) << (vrlg.CAMSYNC_CHN_EN_BIT - 7)
        self.x393_axi_tasks.write_control_register(vrlg.CAMSYNC_ADDR + vrlg.CAMSYNC_MODE, data);
        
    def set_camsync_inout(self,
                          is_out,
                          bit_number,
                          active_positive):
        """
        Setup camsync input or output
        @param is_out - True for outputs, False for inputs
        @param bit_number - number ogf GPIO (ext)
        @param active_positive - True for active-high signals, False for active low ones. None - inactive I/O
        """
        data = 0x55555
        db = 0
        if not active_positive is None:
            db=(2,3)[active_positive]
        data &= ~(3 << (2 * bit_number))
        data |=  (db << (2 * bit_number))   
        self.x393_axi_tasks.write_control_register(vrlg.CAMSYNC_ADDR +
                                                 (vrlg.CAMSYNC_TRIG_SRC,vrlg.CAMSYNC_TRIG_DST)[is_out], data)
            
    def reset_camsync_inout(self,
                          is_out):
        """
        Reset camsync inputs or outputs to inactive/don't care state
        @param is_out - True for outputs, False for inputs
        """
        self.x393_axi_tasks.write_control_register(vrlg.CAMSYNC_ADDR +
                                                 (vrlg.CAMSYNC_TRIG_SRC,vrlg.CAMSYNC_TRIG_DST)[is_out], 0)

    def set_camsync_period(self,
                          period):
        """
        Set camsync period
        @param period - period value in 10 ns steps - max 42.95 sec
        """
        self.x393_axi_tasks.write_control_register(vrlg.CAMSYNC_ADDR + vrlg.CAMSYNC_TRIG_PERIOD, period)
            
    def set_camsync_delay(self,
                          sub_chn,
                          delay):
        """
        Set camsync delay for selected channel (in internal mode master channel is used for flash delay)
        @param sub_chn - sensor channel (0..3)
        @param delay -   delay value in 10 ns steps - max 42.95 sec
        """
        self.x393_axi_tasks.write_control_register(vrlg.CAMSYNC_ADDR + vrlg.CAMSYNC_TRIG_DELAY0+sub_chn, delay)
    
    def camsync_setup(self,
                      sensor_mask =        None,
                      trigger_mode =       None,
                      ext_trigger_mode =   None,
                      external_timestamp = None,
                      camsync_period =     None,
                      camsync_delay =      None):
        """
        @param sensor_mask -        bitmask of enabled channels
        @param triggered_mode -     False - async (free running) sensor mode, True - triggered (global reset) sensor mode
        @param ext_trigger_mode -   True - external trigger source, 0 - local FPGA trigger source
        @param external_timestamp - True - use received timestamp in the image file, False - use local timestamp 
        @param period -             period value in 10 ns steps - max 42.95 sec
        @param delay -              delay value in 10 ns steps - max 42.95 sec (or list/tuple if different for channels)
        """
        self.set_camsync_period  (0) # reset circuitry
        self.X393_gpio.set_gpio_ports (port_a = True)
        self.set_camsync_mode (
                               en = True,
                               en_snd = True,
                               en_ts_external = external_timestamp,
                               triggered_mode = trigger_mode,
                               master_chn =     0,
                               chn_en = sensor_mask)
        
        # setting I/Os after camsync is enabled
        self.reset_camsync_inout (is_out = 0)        # reset input selection
        if ext_trigger_mode :
            self.set_camsync_inout(is_out = 0,
                                   bit_number = 7,
                                   active_positive = 1) # set input selection - ext[7], active high
            
        self.reset_camsync_inout (is_out = 1)        # reset output selection
        self.set_camsync_inout   (is_out = 1,
                                  bit_number = 6,
                                  active_positive = 1) # set output selection - ext[6], active high
        self.set_camsync_period  (SYNC_BIT_LENGTH) #set (bit_length -1) (should be 2..255), not the period
        if not isinstance(camsync_delay,list) or isinstance(camsync_delay,tuple):
            camsync_delay = (camsync_delay, camsync_delay, camsync_delay, camsync_delay)
        for i, dly in enumerate (camsync_delay): 
            if not dly is None:
                self.set_camsync_delay(sub_chn = i, delay = dly)

        if not camsync_period is None:
            self.set_camsync_period  (period = camsync_period) # set period (start generating) - in 353 was after everything else was set
