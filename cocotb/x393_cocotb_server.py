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
import socket
import select
#import json
from socket_command import SocketCommand

from cocotb.triggers import Timer
from x393interfaces import MAXIGPMaster, PSBus, SAXIRdSim, SAXIWrSim
from cocotb.drivers import BitDriver
from cocotb.triggers import Timer, RisingEdge, ReadOnly
from cocotb.result import ReturnValue, TestFailure, TestError, TestSuccess
import logging
import re
import struct
def hex_list(lst, max_items=0, frmt="0x%08x"):
    if (max_items == 0) or (len(lst) <= max_items):
        hs="["
        for d in lst:
            hs+=frmt%(d)+", "
        return hs[:-2]+"]"    
    hs = "%d ["%len(lst)
    fi = max_items-1 if max_items > 1 else max_items
    for d in lst[:fi]:
        hs+=frmt%(d)+", "
    hs += "..."
    if fi < max_items:
        hs += " "+frmt%(d)
    return hs+"]"    
    
class X393_cocotb_server(object):
    INTR_ADDRESS = 0xfffffff0 #temporary address
    INTM_ADDRESS = 0xfffffff4 #temporary address
    RESERVED = (INTR_ADDRESS,INTM_ADDRESS)
    writeIDMask = (1 <<12) -1
    readIDMask = (1 <<12) -1
    started=False
    int_mask = 0 # all disabled
    def __init__(self, dut, port, host, mempath=None, autoflush=True): # , debug=False):
        self.ACLK_FREQ=50000000 # 50 MHz
        debug = os.getenv('COCOTB_DEBUG') # None/1
        if mempath is None:
            mempath =    os.getenv('SIMULATION_PATH')+"/"+"memfile"
        self.mempath =   mempath
        self.memlow =    0
        self.memhigh =   0x40000000
        self.autoflush = autoflush
        self.cmd=        SocketCommand()
        self.dut =       dut
        #Open file to use as system memory
        try:
            self._memfile=open(mempath, 'r+') #keep old file if it exists already
        except:    
            self._memfile=open(mempath, 'w+') #create a new file if it does not exist
            self.dut._log.info ("Created a new 'memory' file %s"%(mempath)) #
        #Extend to full size
        self._memfile.seek(self.memhigh-1)
        readOK=False
        try:
            readOK = len(self._memfile.read(1))>0
            self.dut._log.info ("Read from 0x%08x"%(self.memhigh-1)) #
            
        except:
            pass
        if not readOK:
            self._memfile.seek(self.memhigh-1)
            self._memfile.write(chr(0))
            self._memfile.flush()
            self.dut._log.info("Wrote to 0x%08x to extend file to full size"%(self.memhigh-1)) #
        
        #initialize MAXIGP0 interface (main control/status registers, TODO: add MAXIGP1 for SATA)
        self.maxigp0 = MAXIGPMaster(entity =   dut,
                                    name =     "dutm0",
                                    clock =    dut.dutm0_aclk,
                                    rdlag =    0,
                                    blag=0)
        self.writeID=0
        self.readID=0
        #initialize Zynq register access, has methods write_reg(a,d) and read_reg(a)
        self.ps_sbus = PSBus       (entity =     dut,
                                    name =       "ps_sbus",
                                    clock =      dut.ps_sbus_clk)
        #Bus masters (communicated over mempath file
        #Membridge to FPGA
        self.saxihp0r = SAXIRdSim  (entity =     dut,
                                    name =       "saxihp0",
                                    clock =      dut.axi_hclk,
                                    mempath =    self.mempath,
                                    memhigh =    self.memhigh,
                                    data_bytes = 8)
        #Membridge from FPGA
        self.saxihp0w = SAXIWrSim  (entity =     dut,
                                    name =       "saxihp0",
                                    clock =      dut.axi_hclk,
                                    mempath =    self.mempath,
                                    memhigh =    self.memhigh,
                                    data_bytes = 8,
                                    autoflush =  self.autoflush,
                                    blatency =   5)
        #Compressors from FPGA
        self.saxihp1w = SAXIWrSim  (entity =     dut,
                                    name =       "saxihp1",
                                    clock =      dut.axi_hclk,
                                    mempath =    self.mempath,
                                    memhigh =    self.memhigh,
                                    data_bytes = 8,
                                    autoflush =  self.autoflush,
                                    blatency =   5)
        #histograms from FPGA
        self.saxigp0 =   SAXIWrSim (entity =     dut,
                                    name =       "saxigp0",
                                    clock =      dut.saxi0_aclk,
                                    mempath =    self.mempath,
                                    memhigh =    self.memhigh,
                                    data_bytes = 4,
                                    autoflush =  self.autoflush,
                                    blatency =   5)
        
        level = logging.DEBUG if debug else logging.WARNING
        self.dut._log.info('Set debug level '+str(level)+", debug="+str(debug))
        
        self.maxigp0.log.setLevel(level)
        self.ps_sbus.log.setLevel(level)
        self.saxihp0r.log.setLevel(level)
        self.saxihp0w.log.setLevel(level)
        self.saxihp1w.log.setLevel(level)
        self.saxigp0.log.setLevel(level)
        
        #Initialize socket
        self.PORT = port
        self.HOST = host   # Symbolic name meaning all available interfaces
        self.socket_conn = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.socket_conn.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1) # Otherwise restarting program will need 2 minutes
        try:
            self.socket_conn.bind((self.HOST, self.PORT))
            self.dut._log.debug('Socket bind complete, HOST=%s, PORT=%d'%(self.HOST,self.PORT))
            self.socket_conn.listen(1) # just a single request (may increase to 5 (backlog)
            self.dut._log.info ('Socket now listening to a single request on port %d: send command, receive response, close'%(self.PORT))
        except socket.error as msg:
            self.dut._log.info ("Maybe you need to run 'killall vvp' to close previously opened socket?" )
            self.logErrorTerminate('Bind failed. Error Code : %s Message %s'%( str(msg[0]),msg[1]))
            
        
    def logErrorTerminate(self, msg):
        self.dut._log.error(msg)
        cocotb.regression.tear_down()
        raise TestFailure(msg)
    
    @cocotb.coroutine
    def receiveCommandFromSocket(self):
        line = None
        try:
            self.soc_conn, soc_addr = self.socket_conn.accept()
            self.dut._log.debug ("Connected with %s"%(soc_addr[0] + ':' + str(soc_addr[1])))
            #Sending message to connected client
            line = self.soc_conn.recv(4096) # or make it unlimited?
            self.dut._log.debug("Received from socket: %s"%(line))
        except:
            self.logErrorTerminate("Socket seems to have died :-(")
        self.dut._log.debug("1.Received from socket: %s"%(line))
        yield self.executeCommand(line)
        self.dut._log.debug("3.Received from socket: %s"%(line))
    
    @cocotb.coroutine
    def executeCommand(self,line):
        self.dut._log.debug("1.executeCommand: %s"%(line))
        if not line:
            raise ReturnValue(None)
        self.dut._log.debug("2.executeCommand: %s"%(line))
        self.cmd.fromJSON(line)
        
        #TODO: add interrupt related commands (including wait IRQ with timeout
        if self.cmd.getStart():
            self.dut._log.info('Received START, waiting reset to be over')
            yield Timer(10000)

            while self.dut.reset_out.value.get_binstr() != "1":
                yield Timer(10000)
            while self.dut.reset_out.value:
                yield Timer(10000)

            self.saxihp0r_thread = cocotb.fork(self.saxihp0r.saxi_rd_run())    
            self.saxihp0w_thread = cocotb.fork(self.saxihp0w.saxi_wr_run())    
            self.saxihp1w_thread = cocotb.fork(self.saxihp1w.saxi_wr_run())    
            self.saxigp0_thread =  cocotb.fork(self.saxigp0.saxi_wr_run())    
            self.soc_conn.send(self.cmd.toJSON(0)+"\n")
            self.dut._log.debug('Sent 0 to the socket')
            started=True

        elif self.cmd.getStop():
            self.dut._log.info('Received STOP, closing...')
            self.soc_conn.send(self.cmd.toJSON(0)+"\n")
            self.soc_conn.close()
            yield Timer(10000) # small pause for the wave output

            self.socket_conn.shutdown(socket.SHUT_RDWR)
            self.socket_conn.close()
            cocotb.regression.tear_down()
            started=False
            raise TestSuccess('Terminating as received STOP command')
        #For now write - one at a time, TODO: a) consolidate, b) decode address (some will be just a disk file)
        elif self.cmd.getWrite():
            ad = self.cmd.getWrite()
            self.dut._log.debug('Received WRITE, 0x%0x: %s'%(ad[0],hex_list(ad[1])))
            if ad[0]in self.RESERVED:
                if ad[0] == self.INTM_ADDRESS:
                    self.int_mask = ad[1][0]
                rslt = 0 
            elif (ad[0] >= self.memlow) and  (ad[0] < self.memhigh):
                addr = ad[0]
                self._memfile.seek(addr)
                for data in ad[1]: # currently only single word is supported
                    sdata=struct.pack("<L",data) # little-endian, u32
                    self._memfile.write(sdata)
                    self.dut._log.debug("Written 'system memory': 0x%08x => 0x%08x"%(data,addr))
                    addr += 4
                rslt = 0 
            elif(ad[0] >= 0x40000000) and (ad[0] < 0x80000000):
                rslt = yield self.maxigp0.axi_write(address =     ad[0],
                                                value =           ad[1],
                                                byte_enable =     None,
                                                id =              self.writeID,
                                                dsize =           2,
                                                burst =           1,
                                                address_latency = 0,
                                                data_latency =    0)
                self.dut._log.debug('maxigp0.axi_write yielded %s'%(str(rslt)))
                self.writeID = (self.writeID+1) & self.writeIDMask
            elif (ad[0] >= 0xc0000000) and (ad[0] < 0xfffffffc):
                self.ps_sbus.write_reg(ad[0],ad[1][0])
                rslt = 0 
            else:
                self.dut._log.info('Write address 0x%08x is outside of maxgp0, not yet supported'%(ad[0]))
                rslt = 0
            self.dut._log.info('WRITE 0x%08x <= %s'%(ad[0],hex_list(ad[1], max_items = 4)))
            self.soc_conn.send(self.cmd.toJSON(rslt)+"\n")
            self.dut._log.debug('Sent rslt to the socket')
        elif self.cmd.getRead():
            ad = self.cmd.getRead()
            self.dut._log.debug(str(ad))
            if not isinstance(ad,(list,tuple)):
                ad=(ad,1)
            elif len(ad) < 2:
                ad=(ad[0],1)
            self.dut._log.debug(str(ad))
            if ad[0]in self.RESERVED:
                if ad[0] == self.INTR_ADDRESS:
                    try:
                        dval=[self.dut.irq_r.value.integer]
                    except:
                        bv = self.dut.irq_r.value
                        bv.binstr = re.sub("[^1]","0",bv.binstr)
                        dval=[bv.integer]
                elif ad[0] == self.INTM_ADDRESS:
                    dval = [self.int_mask]
                else:
                    dval = [0]    
            elif (ad[0] >= self.memlow) and  (ad[0] < self.memhigh):
                addr = ad[0]
                self._memfile.seek(addr)
                self.dut._log.debug("read length="+str(len(self._memfile.read(4*ad[1]))))
                
                self._memfile.seek(addr)
                self.dut._log.debug(str(ad))
                dval = list(struct.unpack("<"+"L"*ad[1],self._memfile.read(4*ad[1])))
                msg="'Written 'system memory: 0x%08x => "%(addr)
                for d in dval:
                    msg += "0x%08x "%(d)
                self.dut._log.debug(msg)
                
            elif(ad[0] >= 0x40000000) and (ad[0] < 0x80000000):
                dval = yield  self.maxigp0.axi_read(address =     ad[0],
                                               id =               self.readID,
                                                dlen =            ad[1],
                                                dsize =           2,
                                                address_latency = 0,
                                                data_latency =    0 )
                self.dut._log.debug("axi_read returned 0x%08x => %s"%(ad[0],hex_list(dval, max_items = 4)))
                self.readID = (self.readID+1) & self.readIDMask
            elif (ad[0]>= 0xc0000000) and (ad[0] < 0xfffffffc):
                dval = yield  self.ps_sbus.read_reg(ad[0])
            else:
                self.dut._log.info('Read address 0x%08x is outside of maxgp0, not yet supported'%(ad[0]))
                dval = [0]    
            self.soc_conn.send(self.cmd.toJSON(dval)+"\n")
            self.dut._log.debug('Sent dval to the socket')
            self.dut._log.info("READ 0x%08x =>%s"%(ad[0],hex_list(dval, max_items = 4)))
        elif self.cmd.getFlush():
            self.dut._log.info('Received flush')
            self.flush_all()
            self.soc_conn.send(self.cmd.toJSON(0)+"\n")
            self.dut._log.debug('Sent 0 to the socket')
            
        elif self.cmd.getWait():
#self.MAXIGP0_CLK_FREQ            
            int_dly = self.cmd.getWait()
            self.int_mask = int_dly[0]
            num_clk= (int_dly[1] * self.ACLK_FREQ) // 1000000000
            self.dut._log.info('Received WAIT, interrupt mask = 0x%0x, timeout = %d ns, %d clocks'%(self.int_mask,int_dly[1], num_clk))
            n = 0
            for _ in range(num_clk):
                yield RisingEdge(self.dut.dutm0_aclk)
                try:
                    irq_r=self.dut.irq_r.value.integer
                except:
                    bv = self.dut.irq_r.value
                    bv.binstr = re.sub("[^1]","0",bv.binstr)
                    irq_r=bv.integer
                if (self.int_mask & irq_r):
                    break
                n += 1
            self.soc_conn.send(self.cmd.toJSON(n)+"\n")
            self.dut._log.debug('Sent %d to the socket'%(n))
            self.dut._log.info(' WAIT over, passed %d ns'%((n * 1000000000)//self.ACLK_FREQ))
        else:
            self.dut._log.warning('Received unknown command: '+str(self.cmd))
            self.soc_conn.send(self.cmd.toJSON(1)+"\n")
            self.dut._log.debug('Sent 1 to the socket')
            
def convert_string(txt):
    number=0
    for c in txt:
        number = (number << 8) + ord(c)
    return number   

@cocotb.coroutine
def run_test(dut, port=7777):
    tb = X393_cocotb_server(dut=dut, host = "", port=7777)
    dut._log.warn("Waiting for commnad on socket port %s"%(port))
    while True:
        try:
            rslt= yield tb.receiveCommandFromSocket()
            dut._log.debug("rslt = %s"%(str(rslt)))
        except ReturnValue as rv:
            line = rv.retval;
            dut._log.info("rv = %s"%(str(rv)))
            dut._log.info("line = %s"%(str(line)))
    tb.socket_conn.close()
    cocotb.regression.tear_down()
    
