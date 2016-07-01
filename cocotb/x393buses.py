from __future__ import print_function


"""
# Copyright (C) 2016, Elphel.inc.
# Implementation of AXI4-based buses used in Elpphel x393 camera project
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

Uses code from https://github.com/potentialventures/cocotb/blob/master/cocotb/drivers/amba.py
Below are the copyright/license notices of the amba.py
------------------------------------------------------

Copyright (c) 2014 Potential Ventures Ltd
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Potential Ventures Ltd,
      SolarFlare Communications Inc nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL POTENTIAL VENTURES LTD BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. '''
"""


import cocotb
from cocotb.triggers import Timer, RisingEdge, ReadOnly, Lock
from cocotb.drivers import BusDriver
from cocotb.result import ReturnValue
from cocotb.binary import BinaryValue

import binascii
import array
#channels
AR_CHN="AR"
AW_CHN="AW"
R_CHN="R"
W_CHN="W"
B_CHN="B"

class MAXIGPReadError(Exception):
#    print ("MAXIGPReadError")
    pass
class MAXIGPMaster(BusDriver):
    """
    Implements subset of AXI4 used in x393 project for Xilinx Zynq MAXIGP*
    """
    _signals=[ # i/o from the DUT side
        # read address channel
            "araddr",  # input [31:0]
            "arready", # output
            "arvalid", # input
            "arid",    # input [11:0]
            "arlock",  # input [1:0]
            "arcache", # input [3:0]
            "arprot",  # input [2:0]
            "arlen",   # input [3:0]
            "arsize",  # input [1:0]
            "arburst", # input [1:0],
            "arqos",   # input [3:0]
        # axi ps master gp0: read data
            "rdata",   # output [31:0]
            "rvalid",  # output
            "rready",  # output (normally input, but temporarily in passive ready mode)
            "rid",     # output [11:0]
            "rlast",   # output 
            "rresp",   # output [1:0]
        # axi ps master gp0: write address
            "awaddr",  # input [31:0]
            "awvalid", # input
            "awready", # output
            "awid",    # input [11:0]
            "awlock",  # input [1:0]
            "awcache", # input [3:0]
            "awprot",  # input [2:0]
            "awlen",   # input [3:0]
            "awsize",  # input [1:0]
            "awburst", # input [1:0]
            "awqos",   # input [3:0]
        # axi ps master gp0: write data
            "wdata",   # input [31:0]
            "wvalid",  # input
            "wready",  # output
            "wid",     # input [11:0]
            "wlast",   # input
            "wstb",    # input [3:0]
        # axi ps master gp0: write response
            "bvalid",  # output
            "bready",  # output (normally input, but temporarily in passive ready mode)
            "bid",     # output [11:0]
            "bresp",    # output [1:0]
        # x393 specific signals (controls AXI latencies
            "xtra_rdlag", #input [3:0]
            "xtra_blag" #input [3:0]
            ]
    _channels = [AR_CHN,AW_CHN,R_CHN,W_CHN,B_CHN]
    def __init__(self, entity, name, clock, rdlag=None, blag=None):
        BusDriver.__init__(self, entity, name, clock)
        # set read and write back channels simulation lag between AXI sets valid and host responds with
        # ready. If None - drive these signals  
        self.log.debug ("MAXIGPMaster.__init__(): super done")

        if rdlag is None:
            self.bus.rready.setimmediatevalue(1)
        else:    
            self.bus.xtra_rdlag.setimmediatevalue(rdlag)
        if blag is None:
            self.bus.bready.setimmediatevalue(1)
        else:    
            self.bus.xtra_blag.setimmediatevalue(blag)
        self.bus.awvalid.setimmediatevalue(0)
        self.bus.wvalid.setimmediatevalue(0)
        self.bus.arvalid.setimmediatevalue(0)
        #just in case - set unimplemented in Zynq
        self.bus.arlock.setimmediatevalue(0)
        self.bus.arcache.setimmediatevalue(0)
        self.bus.arprot.setimmediatevalue(0)
        self.bus.arqos.setimmediatevalue(0)
        self.bus.awlock.setimmediatevalue(0)
        self.bus.awcache.setimmediatevalue(0)
        self.bus.awprot.setimmediatevalue(0)
        self.bus.awqos.setimmediatevalue(0)
        self.busy_channels = {}
        self.log.debug ("MAXIGPMaster.__init__(): pre-lcok done")

        #Locks on each subchannel
        for chn in self._channels:
            self.log.debug ("MAXIGPMaster.__init__(): chn = %s"%(chn))
            self.busy_channels[chn]=Lock("%s_%s_busy"%(name,chn))
    def _float_signals(self,signals):
        if not isinstance (signals,(list,tuple)):
            signals = (signals,)
        for signal in signals:    
            v = signal.value
            v.binstr = "z" * len(signal)
            signal <= v

    @cocotb.coroutine
    def _send_write_address(self, address, delay, id, dlen, dsize, burst):
        """
        Send write address with parameters
        @param address binary byte address for burst start
        @param delay Latency sending address in clock cycles
        @param id transaction ID 
        @param dlen burst length (1..16)
        @param dsize - data width - (1 << dsize) bytes (MAXIGP has only 2 bits while AXI specifies 3) 2 means 32 bits
        @param burst burst type (0 - fixed, 1 - increment, 2 - wrap, 3 - reserved)
        """
#        self.log.debug ("MAXIGPMaster._send_write_address(",address,", ",delay,", ",id,", ",dlen ,", ",dsize, ", ", burst)
        yield self.busy_channels[AW_CHN].acquire()
        self.log.debug ("MAXIGPMaster._send_write_address(): acquired lock")
        for _ in range(delay):
            yield RisingEdge(self.clock)
        self.log.debug ("MAXIGPMaster._send_write_address(): delay over")
        self.bus.awvalid <= 1
        self.bus.awid   <= id
        self.bus.awsize <= dsize
        self.bus.awburst <= burst
        while dlen > 16:
            self.bus.awaddr <= address
            address += 16*(1 << dsize)
            dlen -= 16
            self.bus.awlen  <= 15
            while True:
                yield ReadOnly()
                if self.bus.awready.value:
                    break
                yield RisingEdge(self.clock)
            yield RisingEdge(self.clock)
        self.bus.awaddr <= address
        self.bus.awlen  <= dlen -1
        self.log.debug ("1.MAXIGPMaster._send_write_address(), address=0x%08x, dlen = 0x%x"%(address, dlen))
        while True:
            yield ReadOnly()
            if self.bus.awready.value:
                break
            yield RisingEdge(self.clock)
        yield RisingEdge(self.clock)
        self.bus.awvalid <= 0
        # FLoat all assigned bus signals but awvalid
        self._float_signals((self.bus.awaddr,self.bus.awid, self.bus.awlen, self.bus.awsize,self.bus.awburst))
        self.busy_channels[AW_CHN].release()
        self.log.debug  ("MAXIGPMaster._send_write_address(): released lock %s"%(AW_CHN))

    @cocotb.coroutine
    def _send_write_data(self, data, wrstb,  delay, id, dsize):
        """
        Send a data word or a list of data words (supports multi-burst)
        @param data a list/tuple of words to send
        @param wrstb - write mask list (same size as data)
        @param delay latency in clock cycles
        @param id transaction ID 
        @param dsize - data width - (1 << dsize) bytes (MAXIGP has only 2 bits while AXI specifies 3) 2 means 32 bits
        """
#        self.log.debug ("MAXIGPMaster._send_write_data(",data,", ",wrstb,", ", delay,", ",id,", ",dsize)
        yield self.busy_channels[W_CHN].acquire()
        self.log.debug ("MAXIGPMaster._send_write_data(): acquired lock")
        for cycle in range(delay):
            yield RisingEdge(self.clock)

        self.bus.wvalid <= 1
        self.bus.wid <= id
        for i,val_wstb in enumerate(zip(data,wrstb)):
#            self.log.debug ("MAXIGPMaster._send_write_data(), i= ",i,", val_wstb=",val_wstb)
            if (i == (len(data) - 1)) or ((i % 16) == 15):
                self.bus.wlast <= 1
            else:
                self.bus.wlast <= 0
            self.bus.wdata <= val_wstb[0]
            self.bus.wstb <= val_wstb[1]
            while True:
                yield ReadOnly()
                if self.bus.wready.value:
                    break
                yield RisingEdge(self.clock)
            yield RisingEdge(self.clock)
        self.bus.wvalid <= 0
        # FLoat all assigned bus signals but wvalid
        self._float_signals((self.bus.wdata,self.bus.wstb,self.bus.wlast))
        self.busy_channels[W_CHN].release()
        self.log.debug ("MAXIGPMaster._send_write_data(): released lock %s"%(W_CHN))
    """
    @cocotb.coroutine    
    def print_test(self):
        print ("test2, clock=",self.clock);
        yield Timer(10)
#        yield RisingEdge(self.clock)
        print ("test2, pass2, clock=",self.clock);
   """
    @cocotb.coroutine    
    def axi_write(self, address, value, byte_enable=None, address_latency=0,
              data_latency=0,
              id=0, dsize=2, burst=1):
        self.log.debug("axi_write")
        """
        Write a data burst.
        @param address binary byte address for burst start
        @param value - a value or a list of values (supports multi-burst, but no interrupts between bursts)
        @param byte_enable - byte enable mask. Should be None (all enabled) or have the same number of items as data 
        @param address_latency latency sending address in clock cycles
        @param data_latency latency sending data in clock cycles
        @param id transaction ID 
        @param dsize - data width - (1 << dsize) bytes (MAXIGP has only 2 bits while AXI specifies 3) 2 means 32 bits
        @param burst burst type (0 - fixed, 1 - increment, 2 - wrap, 3 - reserved)
        """
#        self.log.debug ("1.MAXIGPMaster.write(",address,", ",value, ",", byte_enable,", ",address_latency,",",
#                                     data_latency,", ",id,", ",dsize,", ", burst)
        if not isinstance(value, (list,tuple)):
            value = (value,)    
        if not isinstance(byte_enable, (list,tuple)):
            if byte_enable is None:
                byte_enable = (1 << (1 << dsize)) - 1 
            byte_enable = [byte_enable]*len(value)
        if None in  byte_enable:
            for i in range(len(byte_enable)):
                if byte_enable[i] is None:
                    byte_enable[i] = (1 << (1 << dsize)) - 1
        #assert len(value) == len(byte_enable), ("values and byte enable arrays have different lengths: %d and %d"%
        #                                        (len(value),len(byte_enable)))
                    
#        self.log.debug ("2.MAXIGPMaster.write(",address,", ",value, ",", byte_enable,", ",address_latency,",",
#                                     data_latency,", ",id,", ",dsize,", ", burst)
        
        c_addr = cocotb.fork(self._send_write_address(address= address,
                                                      delay=   address_latency,
                                                      id =     id,
                                                      dlen =   len(value),
                                                      dsize =  dsize,
                                                      burst =  burst))
        
        c_data = cocotb.fork(self._send_write_data(data =        value,
                                                   wrstb =       byte_enable,
                                                   delay=        data_latency,
                                                   id =          id,
                                                   dsize =       dsize))
#(self, data, wrstb,  delay, id, dsize)        
        if c_addr:
            self.log.debug ("c_addr.join()")
            yield c_addr.join()
        if c_data:
            self.log.debug ("c_data.join()")
            yield c_data.join()
        yield RisingEdge(self.clock)
#        result = self.bus.bresp.value
#        raise ReturnValue(0) #result)
        """    

            
        # It will be to slow if to wait for response after each word sent, need to put a separate monitor on B-channel
        # Wait for the response
        while True:
            yield ReadOnly()
            if self.bus.BVALID.value and self.bus.BREADY.value:
                result = self.bus.BRESP.value
                break
            yield RisingEdge(self.clock)

        yield RisingEdge(self.clock)

        if int(result):
            raise AXIReadError("Write to address 0x%08x failed with BRESP: %d"
                               % (address, int(result)))
        raise ReturnValue(result)
        """
