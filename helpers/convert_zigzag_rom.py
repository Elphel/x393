#!/usr/bin/env python
# -*- coding: utf-8 -*-
from __future__ import print_function
# Copyright (C) 2015, Elphel.inc.
# Helper module to convert zigzag ROM for JPEG quantizer
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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#  
__author__ = "Andrey Filippov"
__copyright__ = "Copyright 2014, Elphel, Inc."
__license__ = "GPL"
__version__ = "3.0+"
__maintainer__ = "Andrey Filippov"
__email__ = "andrey@elphel.com"
__status__ = "Development"
'''
Created on Jun 16, 2015

@author: andrey
'''
'''
    defparam i_z0.INIT = 32'hC67319CC;
    defparam i_z1.INIT = 32'h611A7896;
    defparam i_z2.INIT = 32'h6357A260;
    defparam i_z3.INIT = 32'h4A040C18;
    defparam i_z4.INIT = 32'h8C983060;
    defparam i_z5.INIT = 32'hF0E0C080;
'''
old_rom=    [0xC67319CC,
             0x611A7896,
             0x6357A260,
             0x4A040C18,
             0x8C983060,
             0xF0E0C080]
print ("    case (rom_a)")
for b in range (32):
    d= ((((old_rom[0]>>b) & 1) << 0) |
        (((old_rom[1]>>b) & 1) << 1) |
        (((old_rom[2]>>b) & 1) << 2) |       
        (((old_rom[3]>>b) & 1) << 3) |
        (((old_rom[4]>>b) & 1) << 4) |
        (((old_rom[5]>>b) & 1) << 5))
    print("        5'h%02x: rom_q <= 6'h%02x;"%(b,d))
print ("    endcase")
    