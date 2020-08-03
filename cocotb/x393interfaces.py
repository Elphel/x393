from __future__ import print_function
from __future__ import division


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
@brief      I/O Interfaces of the x393 project for simulation using cocotb 
@author     Andrey Filippov
@copyright  2016 Elphel, Inc.
@license    GPLv3.0+
@contact    andrey@elphel.coml

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
from cocotb.triggers import Timer, RisingEdge, FallingEdge, Edge, ReadOnly, Lock
from cocotb.drivers import BusDriver
from cocotb.result import ReturnValue
from cocotb.binary import BinaryValue

import re
import binascii
import array
import struct
#import logging

#channels
AR_CHN="AR"
AW_CHN="AW"
R_CHN="R"
W_CHN="W"
B_CHN="B"

def _float_signals(signals):
    if not isinstance (signals,(list,tuple)):
        signals = (signals,)
    for signal in signals:    
        v = signal.value
        v.binstr = "z" * len(signal)
        signal <= v
        
        

class MAXIGPReadError(Exception):
#    print ("MAXIGPReadError")
    pass

class PSBus(BusDriver):
    """
    Small subset of Zynq registers, used to access SAXI_HP* registers
    """
    _signals=[ # i/o from the DUT side
        "clk",    # output    
        "addr",   # input [31:0]
        "wr",     # input
        "rd",     # input
        "din",    # input [31:0]
        "dout"]   #output [31:0]
    def __init__(self, entity, name, clock):
        BusDriver.__init__(self, entity, name, clock)
        self.busy_channel = Lock("%s_busy"%(name))
        self.bus.wr.setimmediatevalue(0)
        self.bus.rd.setimmediatevalue(0)
        _float_signals((self.bus.addr, self.bus.din))
        self.name = name

    @cocotb.coroutine
    def write_reg(self,addr,data):
        yield self.busy_channel.acquire()
        #Only wait if it is too late (<1/2 cycle)
        if not int(self.clock):
            yield RisingEdge(self.clock)
        self.bus.addr <= addr
        self.bus.din <= data
        self.bus.wr <= 1
        yield RisingEdge(self.clock)
        self.bus.wr <= 0
        _float_signals((self.bus.addr, self.bus.din))
        self.busy_channel.release()

    @cocotb.coroutine
    def read_reg(self,addr):
        yield self.busy_channel.acquire()
        #Only wait if it is too late (<1/2 cycle)
        if not int(self.clock):
            yield RisingEdge(self.clock)
        self.bus.addr <= addr
        self.bus.rd <= 1
        yield RisingEdge(self.clock)
        try:
            data = self.bus.dout.value.integer
        except:
            bv = self.bus.dout.value
            bv.binstr = re.sub("[^1]","0",bv.binstr)
            data = bv.integer
        self.bus.rd <= 0
        _float_signals((self.bus.addr, ))
        self.busy_channel.release()
        raise ReturnValue(data)

class SAXIWrSim(BusDriver):
    """
    Connects to host side of simul_axi_wr (just writes to system memory) (both GP and HP)
    No locks are used, single instance should be connected to a particular port
    """
    _signals=[ # i/o from the DUT side
        # read address channel
        "wr_address",    # output[31:0] 
        "wid",           # output[5:0] 
        "wr_valid",      # output
        "wr_ready",      # input
        "wr_data",       # output[63:0] 
        "wr_stb",        # output[7:0] 
        "bresp_latency"] # input[3:0]  // just constant
#        "wr_cap",       # output[2:0]
#        "wr_qos"]       # output[3:0]
    _fmt=None
    _memfile = None
    _data_bytes = 8
    _address_lsb = 3 
    def __init__(self, entity, name, clock, mempath, memhigh=0x40000000, data_bytes=8, autoflush=True, blatency=5):
        """
        @param entity Device under test
        @param name port names prefix (DUT has I/O ports <name>_<signal>
        @clock clock that drives this interface
        @param mempath operation system path of the memory image (1GB now - 0..0x3fffffff) 
        @param memhigh memory high address
        @param data_bytes data width, in bytes
        @param autoflush flush file after each write
        @param blatency  number of cycles to delay write response (b) channel
        """
        BusDriver.__init__(self, entity, name, clock)
        self.name = name
        self.log.debug ("SAXIWrSim: name='%s', mempath='%s', memhigh=0x%08x, data_bytes=%d, autoflush=%s, blatency=%d"%
                       (name,mempath,memhigh,data_bytes, str(autoflush), blatency))
#        self.log.debug ("SAXIWrSim.__init__(): super done")
        #Open file to use as system memory
        try:
            self._memfile=open(mempath, 'r+') #keep old file if it exists already
        except:    
            self._memfile=open(mempath, 'w+') #create a new file if it does not exist
            self.log.info ("SAXIWrSim(%s): created a new 'memory' file %s"%(name,mempath)) #
        #Extend to full size
        self._memfile.seek(memhigh-1)
        readOK=False
        try:
            readOK = len(self._memfile.read(1))>0
            self.log.debug ("Read from 0x%08x"%(memhigh-1)) #
            
        except:
            pass
        if not readOK:
            self._memfile.seek(memhigh-1)
            self._memfile.write(chr(0))
            self._memfile.flush()
            self.log.info("Wrote to 0x%08x to extend file to full size"%(memhigh-1)) #

        self.autoflush=autoflush
        self.bus.wr_ready.setimmediatevalue(1) # always ready
        self.bus.bresp_latency.setimmediatevalue(blatency)
        if data_bytes > 4:
            self._data_bytes = 8
            self._address_lsb = 3
            self._fmt= "<Q"
        elif data_bytes > 2:
            self._data_bytes = 4
            self._address_lsb = 2
            self._fmt= "<L"
        elif data_bytes > 1:
            self._data_bytes = 2
            self._address_lsb = 1
            self._fmt= "<H"
        else:
            self._data_bytes = 1
            self._address_lsb = 0
            self._fmt= "<B"
        self.log.debug ("SAXIWrSim(%s) init done"%(self.name))

    def flush(self):
        self._memfile.flush()
            
    @cocotb.coroutine
    def saxi_wr_run(self):
        self.log.debug ("SAXIWrSim(%s).saxi_wr_run"%(self.name))
        while True:
            if not self.bus.wr_ready.value:
                break #exit
            while True:
                yield ReadOnly()
                if self.bus.wr_valid.value:
                    break
                yield RisingEdge(self.clock)
#            yield RisingEdge(self.clock)
            #Here write data
            try:
                address = self.bus.wr_address.value.integer
            except:
                self.log.warning ("SAXIWrSim() tried to write to unknown memory address")
                adress = None
                yield RisingEdge(self.clock)
                continue
            if address & ((1 << self._address_lsb) - 1):
                self.log.warning ("SAXIWrSim() Write memory address is not aligned to %d-byte words"%(self._data_bytes))
                address = (address >> self._address_lsb) << self._address_lsb;
            self._memfile.seek(address)

            try:
                data = self.bus.wr_data.value.integer
            except:
                self.log.warning ("SAXIWrSim(%s:%d) writing undefined data"%(self.name,self._data_bytes))
                bv = self.bus.wr_data.value
                bv.binstr = re.sub("[^1]","0",bv.binstr)
                data = bv.integer
            sdata=struct.pack(self._fmt,data).decode('iso-8859-1')
            bv = self.bus.wr_data.value    
            bv.binstr= re.sub("[^0]","1",bv.binstr) # only 0 suppresses write to this byte
            while len(bv.binstr) < self._data_bytes: # very unlikely
                bv.binstr = "1"+bv.binstr
            if bv.integer == self._data_bytes:
                self._memfile.write(sdata)
            else:
                for i in range (self._data_bytes):
                    if bv.binstr[-1-i] != 0:
                       self._memfile.write(sdata[i])
                    else:
                       self._memfile.seek(1,1)
            if self.autoflush:
                self._memfile.flush()
            self.log.info ("SAXIWrSim(%s:%d) 0x%x <- 0x%x"%(self.name,self._data_bytes,address,data))
            yield RisingEdge(self.clock)
            
            
class SAXIRdSim(BusDriver):
    """
    Connects to host side of simul_axi_rd (just writes to system memory) (both GP and HP)
    No locks are used, single instance should be connected to a particular port
    """
    _signals=[ # i/o from the DUT side
        # read address channel
        "rd_address",    # output[31:0] 
        "rid",           # output[5:0] 
        "rd_valid",      # input
        "rd_ready",      # output
        "rd_data",       # input[63:0] 
        "rd_resp"]       # input[1:0] 
    _fmt=None
    _memfile = None
    _data_bytes =  8
    _address_lsb = 3 
    def __init__(self, entity, name, clock, mempath, memhigh=0x40000000, data_bytes=8):
        """
        @param entity Device under test
        @param name port names prefix (DUT has I/O ports <name>_<signal>
        @clock clock that drives this interface
        @param mempath operation system path of the memory image (1GB now - 0..0x3fffffff) 
        @param memhigh memory high address
        @param data_bytes data width, in bytes
        
        """
        
        BusDriver.__init__(self, entity, name, clock)
        self.name = name
        self.log.debug ("SAXIRdSim: name='%s', mempath='%s', memhigh=0x%08x, data_bytes=%d"%
                       (name,mempath,memhigh,data_bytes))
#        self._memfile=open(mempath, 'r+')
        #Open file to use as system memory
        try:
            self._memfile=open(mempath, 'r+') #keep old file if it exists already
        except:    
            self._memfile=open(mempath, 'w+') #create a new file if it does not exist
            self.log.info ("SAXIRdSim(%s): created a new 'memory' file %s"%(name,mempath)) #
        #Extend to full size
        self._memfile.seek(memhigh-1)
        readOK=False
        try:
            readOK = len(self._memfile.read(1))>0
            self.log.debug ("Read from 0x%08x"%(memhigh-1)) #
            
        except:
            pass
        if not readOK:
            self._memfile.seek(memhigh-1)
            self._memfile.write(chr(0))
            self._memfile.flush()
            self.log.info("Wrote to 0x%08x to extend file to full size"%(memhigh-1)) #
        
        self.bus.rd_valid.setimmediatevalue(0)

        if data_bytes > 4:
            self._data_bytes = 8
            self._address_lsb = 3
            self._fmt= "<Q"
        elif data_bytes > 2:
            self._data_bytes = 4
            self._address_lsb = 2
            self._fmt= "<L"
        elif data_bytes > 1:
            self._data_bytes = 2
            self._address_lsb = 1
            self._fmt= "<H"
        else:
            self._data_bytes = 1
            self._address_lsb = 0
            self._fmt= "<B"
        self.log.debug("SAXIRdSim(%s) init done"%(self.name))
        
    @cocotb.coroutine
    def saxi_test(self):
        self.log.info ("SAXIRdSim(%s).saxi_test"%(self.name))
        yield Timer(1000)
        
    @cocotb.coroutine
    def saxi_rd_run(self):
        self.log.info ("SAXIRdSim(%s).saxi_wr_run"%(self.name))
        while True:
#            if not self.bus.rd_valid.value:
#                break #exit
            while True:
                yield FallingEdge(self.clock)
                if self.bus.rd_ready.value:
                    break
            self.bus.rd_valid  <= 1
#            yield RisingEdge(self.clock)
            #Here write data
            try:
                address = self.bus.rd_address.value.integer
            except:
                self.log.warning ("SAXIRdSim() tried to write to unknown memory address")
                adress = None
            if address & ((1 << self._address_lsb) - 1):
                self.log.warning ("SAXIRdSim() Write memory address is not aligned to %d-byte words"%(self._data_bytes))
                address = (address >> self._address_lsb) << self._address_lsb;
            self._memfile.seek(address)
            rresp=0
            try:
                rs = self._memfile.read(self._data_bytes)
            except:
                self.log.warning ("SAXIRdSim() failed reading %d bytes form 0x%08x"%(self._data_bytes, address))
                rs = None
            if not rs is None:
                try:
                    data = struct.unpack(self._fmt,rs)
                except:
                    self.log.warning ("SAXIRdSim():Can not unpack memory data @ address 0x%08x"%(address))
                    data=None
            if (not address is None) and (not data is None):
                self.bus.rd_resp <= 0
                self.bus.rd_data <= data
            else:
                self.bus.rd_resp <= 2 # error
                _float_signals((self.bus.rd_data,))
                
            self.bus.rd_valid <= 1
            yield RisingEdge(self.clock)
            self.bus.rd_valid <= 0
            _float_signals((self.bus.rd_data,self.bus.rd_resp))




    
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
        self.name = name
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
        self.log.debug ("MAXIGPMaster.__init__(): pre-lock done")

        #Locks on each subchannel
        for chn in self._channels:
            self.log.debug ("MAXIGPMaster.__init__(): chn = %s"%(chn))
            self.busy_channels[chn]=Lock("%s_%s_busy"%(name,chn))

    @cocotb.coroutine
    def _send_write_address(self, address, delay, id, dlen, dsize, burst):
        """
        Send write address with parameters
        @param address binary byte address for (first) burst start
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
        _float_signals((self.bus.awaddr,self.bus.awid, self.bus.awlen, self.bus.awsize,self.bus.awburst))
        self.busy_channels[AW_CHN].release()
        self.log.debug  ("MAXIGPMaster._send_write_address(): released lock %s"%(AW_CHN))

    @cocotb.coroutine
    def _send_read_address(self, address, delay, id, dlen, dsize, burst):
        """
        Send write address with parameters
        @param address binary byte address for (first) burst start
        @param delay Latency sending address in clock cycles
        @param id transaction ID 
        @param dlen burst length (1..16)
        @param dsize - data width - (1 << dsize) bytes (MAXIGP has only 2 bits while AXI specifies 3) 2 means 32 bits
        @param burst burst type (0 - fixed, 1 - increment, 2 - wrap, 3 - reserved)
        """
#        self.log.debug ("MAXIGPMaster._send_write_address(",address,", ",delay,", ",id,", ",dlen ,", ",dsize, ", ", burst)
        yield self.busy_channels[AR_CHN].acquire()
        self.log.debug ("MAXIGPMaster._send_write_address(): acquired lock")
        for _ in range(delay):
            yield RisingEdge(self.clock)
        self.log.debug ("MAXIGPMaster._send_read_address(): delay over")
        self.bus.arvalid <= 1
        self.bus.arid   <= id
        self.bus.arsize <= dsize
        self.bus.arburst <= burst
        while dlen > 16:
            self.bus.araddr <= address
            address += 16*(1 << dsize)
            dlen -= 16
            self.bus.arlen  <= 15
            while True:
                yield ReadOnly()
                if self.bus.arready.value:
                    break
                yield RisingEdge(self.clock)
            yield RisingEdge(self.clock)
        self.bus.araddr <= address
        self.bus.arlen  <= dlen -1
        self.log.debug ("1.MAXIGPMaster._send_read_address(), address=0x%08x, dlen = 0x%x"%(address, dlen))
        while True:
            yield ReadOnly()
            if self.bus.arready.value:
                break
            yield RisingEdge(self.clock)
        yield RisingEdge(self.clock)
        self.bus.arvalid <= 0
        # FLoat all assigned bus signals but awvalid
        _float_signals((self.bus.araddr,self.bus.arid, self.bus.arlen, self.bus.arsize,self.bus.arburst))
        self.busy_channels[AR_CHN].release()
        self.log.debug  ("MAXIGPMaster._send_read_address(): released lock %s"%(AR_CHN))

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
        self.log.debug ("MAXIGPMaster._send_write_data("+str(data)+", "+str(wrstb)+", "+str(delay)+", "+str(id)+", "+str(dsize))
        yield self.busy_channels[W_CHN].acquire()
        self.log.debug ("MAXIGPMaster._send_write_data(): acquired lock")
        for cycle in range(delay):
            yield RisingEdge(self.clock)
        self.log.debug ("MAXIGPMaster._send_write_data(): delay over")
        self.bus.wvalid <= 1
        self.bus.wid <= id
        for i,val_wstb in enumerate(zip(data,wrstb)):
            self.log.debug ("MAXIGPMaster._send_write_data(), i= %d, val_stb=%s "%(i,str(val_wstb)))
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
        _float_signals((self.bus.wdata,self.bus.wstb,self.bus.wlast))
        self.busy_channels[W_CHN].release()
        self.log.debug ("MAXIGPMaster._send_write_data(): released lock %s"%(W_CHN))
        raise ReturnValue(dsize)


    @cocotb.coroutine
    def _get_read_data(self, address, id, dlen, dsize, delay):
        """
        Send a data word or a list of data words (supports multi-burst)
        @param address start address to read data from (just for logging)
        @param id expected receive data ID 
        @param dlen number of words to read 
        @param dsize - data width - (1 << dsize) bytes (MAXIGP has only 2 bits while AXI specifies 3) 2 means 32 bits
        @param delay latency in clock cycles
        """
        self.log.debug ("MAXIGPMaster._get_read_data("+str(address)+", "+str(id)+", "+str(dlen)+", "+str(dsize)+", "+str(delay))
        yield self.busy_channels[R_CHN].acquire()
        self.log.debug ("MAXIGPMaster._get_read_data(): acquired lock")
        for cycle in range(delay):
            yield RisingEdge(self.clock)
        self.log.debug ("MAXIGPMaster._get_read_data(): delay over")
        self.bus.rready <= 1
        data=[]
        for i in range(dlen):
            self.log.debug ("MAXIGPMaster._get_read_data(), i= %d"%(i))
            while True:
                yield ReadOnly()
                if self.bus.rvalid.value:
                    try:
                        data.append(self.bus.rdata.value.integer)
                    except:
                        bv = self.bus.rdata.value
                        bv.binstr = re.sub("[^1]","0",bv.binstr)
                        data.append(bv.integer)
                    rid = int(self.bus.rid.value)  
                    if rid != id:
                        self.log.error("Read data 0x%x ID mismatch - expected: 0x%x, got 0x%x"%(address+i,id, rid))
                    break
                yield RisingEdge(self.clock)
            yield RisingEdge(self.clock)
        self.bus.rready <= 0
        # FLoat all assigned bus signals but wvalid
#        _float_signals((self.bus.wdata,self.bus.wstb,self.bus.wlast))
        self.busy_channels[R_CHN].release()
        self.log.debug ("MAXIGPMaster._get_read_data(): released lock %s"%(R_CHN))
        raise ReturnValue(data)


    
    @cocotb.coroutine    
    def axi_write(self, address, value, byte_enable=None, 
              id=0, dsize=2, burst=1,address_latency=0,
              data_latency=0):
        self.log.debug("axi_write")
        """
        Write a data burst.
        @param address binary byte address for burst start
        @param value - a value or a list of values (supports multi-burst, but no interrupts between bursts)
        @param byte_enable - byte enable mask. Should be None (all enabled) or have the same number of items as data 
        @param id transaction ID 
        @param dsize - data width - (1 << dsize) bytes (MAXIGP has only 2 bits while AXI specifies 3) 2 means 32 bits
        @param burst burst type (0 - fixed, 1 - increment, 2 - wrap, 3 - reserved)
        @param address_latency latency sending address in clock cycles
        @param data_latency latency sending data in clock cycles
        """
        #Only wait if it is too late (<1/2 cycle)
        if not int(self.clock):
            yield RisingEdge(self.clock)

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
        
        if c_addr:
            self.log.debug ("c_addr.join()")
            yield c_addr.join()
        if c_data:
            self.log.debug ("c_data.join()")
            yield c_data.join()
#        yield RisingEdge(self.clock)
        self.log.debug ("axi_write:All done")
        raise ReturnValue(0)
  
    @cocotb.coroutine
    def axi_read(self, address, id = 0, dlen = 1, dsize = 2, burst = 1, address_latency = 0, data_latency= 0 ):
        """
        Receive data form AXI port
        @param address start address to read data from
        @param id expected receive data ID 
        @param dlen number of words to read 
        @param dsize - data width - (1 << dsize) bytes (MAXIGP has only 2 bits while AXI specifies 3) 2 means 32 bits
        @param burst burst type (0 - fixed, 1 - increment, 2 - wrap, 3 - reserved)
        @param address_latency latency sending address in clock cycles
        @param data_latency latency sending data in clock cycles
        @return A list of BinaryValue objects
        """
        #Only wait if it is too late (<1/2 cycle)
        if not int(self.clock):
            yield RisingEdge(self.clock)
            
        c_addr = cocotb.fork(self._send_read_address(address=    address,
                                                      delay=     address_latency,
                                                      id =       id,
                                                      dlen =     dlen,
                                                      dsize =    dsize,
                                                      burst =    burst))
        
        c_data = cocotb.fork(self._get_read_data     (address=   address,
                                                      id =       id,
                                                      dlen =     dlen,
                                                      dsize =    dsize,
                                                      delay =    data_latency))
        if c_addr:
            self.log.debug ("c_addr.join()")
            yield c_addr.join()
        if c_data:
            self.log.debug ("c_data.join()")
            data_rv=yield c_data.join()
#        yield RisingEdge(self.clock)
        self.log.debug ("axi_read:All done, returning, data_rv="+str(data_rv))
        raise ReturnValue(data_rv)
