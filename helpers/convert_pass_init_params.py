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
__copyright__ = "Copyright 2015, Elphel, Inc."
__license__ = "GPL"
__version__ = "3.0+"
__maintainer__ = "Andrey Filippov"
__email__ = "andrey@elphel.com"
__status__ = "Development"
import sys
for i in range (16):
    print (", .INITP_%02X (INITP_%02X)"%(i,i))
for i in range (128):
    print (", .INIT_%02X  (INIT_%02X)"%(i,i))
