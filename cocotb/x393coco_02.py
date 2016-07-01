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

import cocotb
from cocotb.triggers import Timer
from x393buses import MAXIGPMaster
from cocotb.drivers import BitDriver
from cocotb.triggers import Timer, RisingEdge, ReadOnly
from cocotb.result import ReturnValue, TestFailure, TestError, TestSuccess

import logging

class X393_cocotb_02(object):
    def __init__(self, dut, debug=True):
        self.dut = dut
        self.axiwr = MAXIGPMaster(entity=dut, name="dutm0", clock=dut.dutm0_aclk, rdlag=0, blag=0)
#        self.clock = dut.dutm0_aclk
        
        level = logging.DEBUG if debug else logging.WARNING
        self.axiwr.log.setLevel(level)

@cocotb.coroutine
def run_test(dut, data_in=None, config_coroutine=None, idle_inserter=None,
             backpressure_inserter=None):
#    self.log.info ("MAXIGPMaster._send_write_data(): released lock %s"%(W_CHN))

#    self.log.info  ("run_test(): starting X393_cocotb_02(dut) init")
    tb = X393_cocotb_02(dut)
#    self.log.info  ("run_test(): X393_cocotb_02(dut) done")
    yield Timer(10000)
#    yield RisingEdge(dut.dutm0_aclk)
#    yield ReadOnly()
#    raise TestSuccess("All done for now")


    while dut.reset_out.value.get_binstr() != "1":
        yield Timer(10000)

    while dut.reset_out.value:
        yield Timer(10000)
    yield tb.axiwr.axi_write(address = 0x1234,
                     value = [0,1,2,3,4,5,6,7,8],
                     byte_enable=None,
                     address_latency=0,
                     data_latency=0,
                     id=0,
                     dsize=2,
                     burst=1)
    dut._log.info("Almost there")
    yield Timer(1000)
    dut._log.info("Ok!")
#    raise TestSuccess()
    
#    raise TestSuccess("All done for now")
    print("*******************************************")
    cocotb.regression.tear_down()

#print("Main done")    

"""
MODULE=test_endian_swapper

class EndianSwapperTB(object):

def convert_string(txt):
    number=0
    for c in txt:
        number = (number << 8) + ord(c)
    return number     
    
@cocotb.test()
def hello_test(dut):
    yield Timer(100)
    for i in range (1000):
        if i == 200:
            dut.TEST_TITLE=convert_string("passed 200")
        elif i == 400:
            dut.TEST_TITLE=convert_string("passed 400")
        dut.maxigp0arvalid=0
        yield Timer(10000)
        dut.maxigp0arvalid=1
        yield Timer(10000)
"""