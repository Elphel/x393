from __future__ import division
from __future__ import print_function

'''
# Copyright (C) 2015, Elphel.inc.
# Class to control 10393 GPIO port  
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
class X393GPIO(object):
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
        
    def program_status_gpio(self,
                            mode,     # input [1:0] mode;
                            seq_num): # input [5:0] seq_num;
        """
        Set status generation mode for GPIO port
        @param mode -       status generation mode:
                                  0: disable status generation,
                                  1: single status request,
                                  2: auto status, keep specified seq number,
                                  4: auto, inc sequence number 
        @param seq_number - 6-bit sequence number of the status message to be sent
        """

        self.x393_axi_tasks.program_status (vrlg.GPIO_ADDR,
                                            vrlg.GPIO_SET_STATUS,
                                            mode,
                                            seq_num)
    def set_gpio_ports(self,
                       port_soft = None,
                       port_a =    None,
                       port_b =    None,
                       port_c =    None):
        """
        Set status GPIO ports (None - no change, False - disable, True - enable)
        @param port_soft - software-controlled port
        @param port_a -    port A : camsync
        @param port_b -    port B : motors on 10353, unused on 10393
        @param port_c -    port C : logger (IMU/GPS, external)
        """
        data = 0
        if not port_soft is None:
            data |= (2,3)[port_soft]
        if not port_a is None:
            data |= (2,3)[port_a] << 2
        if not port_b is None:
            data |= (2,3)[port_a] << 4
        if not port_c is None:
            data |= (2,3)[port_a] << 6
        self.x393_axi_tasks.write_contol_register(vrlg.GPIO_ADDR +  vrlg.GPIO_SET_PINS, data << vrlg.GPIO_PORTEN)
        
    def set_gpio_pins(self,
                       ext0 = None,
                       ext1 = None,
                       ext2 = None,
                       ext3 = None,
                       ext4 = None,
                       ext5 = None,
                       ext6 = None,
                       ext7 = None,
                       ext8 = None,
                       ext9 = None):
        """
        Set GPIO pins : None - no change, "H" high level output, "L" - low level output "I" - input
        @param ext0 -  GPIO pin 0
        @param ext1 -  GPIO pin 1
        @param ext2 -  GPIO pin 2
        @param ext3 -  GPIO pin 3
        @param ext4 -  GPIO pin 4
        @param ext5 -  GPIO pin 5
        @param ext6 -  GPIO pin 6
        @param ext7 -  GPIO pin 7
        @param ext8 -  GPIO pin 8
        @param ext9 -  GPIO pin 9
        """
        ext= (ext0, ext1, ext2, ext3, ext4, ext5, ext6, ext7, ext8, ext9)
        data = 0
        for i, e in enumerate (ext):
            if not e is None:
                if   (e == 0) or (e.upper() == "0") or (e.upper() == "L"):
                    data |= 1 << (2*i)
                elif (e == 1) or (e.upper() == "1")  or (e.upper() == "H"):
                    data |= 2 << (2*i)
                elif e.upper() == "I":
                    data |= 3 << (2*i)
                else:
                    raise Exception ("Expecting one of 'L', 'H', 'I', got "+str(e)+" for ext"+str(i))
        self.x393_axi_tasks.write_contol_register(vrlg.GPIO_ADDR +  vrlg.GPIO_SET_PINS, data)

