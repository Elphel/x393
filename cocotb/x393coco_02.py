from __future__ import print_function
"""
# Copyright (C) 2016, Elphel.inc.
# Simulation code for cocotb simulation for x393 project
#   
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
@copyright:  2016 Elphel, Inc.
@license:    GPLv3.0+
@contact:    andrey@elphel.coml
"""
import os
import cocotb
from cocotb.triggers import Timer
from x393buses import MAXIGPMaster
from cocotb.drivers import BitDriver
from cocotb.triggers import Timer, RisingEdge, ReadOnly
from cocotb.result import ReturnValue, TestFailure, TestError, TestSuccess

import logging

class X393_cocotb_02(object):
    def __init__(self, dut): # , debug=False):
        """
        print("os.getenv('SIM_ROOT'",os.getenv('SIM_ROOT'))
        print("os.getenv('COCOTB_DEBUG'",os.getenv('COCOTB_DEBUG'))
        print("os.getenv('RANDOM_SEED'",os.getenv('RANDOM_SEED'))
        print("os.getenv('MODULE'",os.getenv('MODULE'))
        print("os.getenv('TESTCASE'",os.getenv('TESTCASE'))
        print("os.getenv('COCOTB_ANSI_OUTPUT'",os.getenv('COCOTB_ANSI_OUTPUT'))
        """
        debug = os.getenv('COCOTB_DEBUG') # None/1
        
        self.dut = dut
        self.axiwr = MAXIGPMaster(entity=dut, name="dutm0", clock=dut.dutm0_aclk, rdlag=0, blag=0)
#        self.clock = dut.dutm0_aclk
        
        level = logging.DEBUG if debug else logging.WARNING
        self.axiwr.log.setLevel(level)
def convert_string(txt):
    number=0
    for c in txt:
        number = (number << 8) + ord(c)
    return number   
@cocotb.coroutine
def run_test(dut):
    tb = X393_cocotb_02(dut)
    yield Timer(10000)

    while dut.reset_out.value.get_binstr() != "1":
        yield Timer(10000)

    while dut.reset_out.value:
        yield Timer(10000)
#    dut.TEST_TITLE.buff = "WRITE"
    dut.TEST_TITLE = convert_string("WRITE")    
    val = yield tb.axiwr.axi_write(address =         0x1234,
                                   value =           [8,7,6,5,4,3,2,1,0],
                                   byte_enable =     None,
                                   id =              0,
                                   dsize =           2,
                                   burst =           1,
                                   address_latency = 0,
                                   data_latency =    0)
#    dut.TEST_TITLE.buff = "---"    
    dut.TEST_TITLE = 0    
    dut._log.info("axi_write returned => " +str(val))
#    yield Timer(1000)
    print("*******************************************")
    yield Timer(11000)
    dut.TEST_TITLE = convert_string("WRITE1")    
    val = yield tb.axiwr.axi_write(address =         0x5678,
                                   value =           [1,2,3,4],
                                   byte_enable =     None,
                                   id =              0,
                                   dsize =           2,
                                   burst =           1,
                                   address_latency = 0,
                                   data_latency =    0)
#    dut.TEST_TITLE.buff = "---"    
    dut.TEST_TITLE = 0    
    dut._log.info("axi_write returned => " +str(val))
#    yield Timer(1000)
    print("*******************************************")
    yield Timer(10000)
#    dval = yield  tb.axiwr.axi_read(0x1234, 0, 4, 2, 0, 0 )
#    dut.TEST_TITLE.buff = "READ"    
    dut.TEST_TITLE <= convert_string("READ")    
    dval = yield  tb.axiwr.axi_read(address =         0x1234,
                                    id =              0,
                                    dlen =            4,
                                    dsize =           2,
                                    address_latency = 0,
                                    data_latency =    0 )

    dut._log.info("axi_read returned => " +str(dval))
#    dut.TEST_TITLE.buff = "---"
    dut.TEST_TITLE <= 0
    yield Timer(100000)
    print("*******************************************")
    cocotb.regression.tear_down()

