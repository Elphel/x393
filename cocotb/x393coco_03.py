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
from x393buses import MAXIGPMaster
from cocotb.drivers import BitDriver
from cocotb.triggers import Timer, RisingEdge, ReadOnly
from cocotb.result import ReturnValue, TestFailure, TestError, TestSuccess

import logging

class X393_cocotb(object):
    writeIDMask = (1 <<12) -1
    readIDMask = (1 <<12) -1
    def __init__(self, dut, port, host): # , debug=False):
        """
        print("os.getenv('SIM_ROOT'",os.getenv('SIM_ROOT'))
        print("os.getenv('COCOTB_DEBUG'",os.getenv('COCOTB_DEBUG'))
        print("os.getenv('RANDOM_SEED'",os.getenv('RANDOM_SEED'))
        print("os.getenv('MODULE'",os.getenv('MODULE'))
        print("os.getenv('TESTCASE'",os.getenv('TESTCASE'))
        print("os.getenv('COCOTB_ANSI_OUTPUT'",os.getenv('COCOTB_ANSI_OUTPUT'))
        """
        debug = os.getenv('COCOTB_DEBUG') # None/1
        self.cmd= SocketCommand()
        self.dut = dut
        self.maxigp0 = MAXIGPMaster(entity=dut, name="dutm0", clock=dut.dutm0_aclk, rdlag=0, blag=0)
        self.writeID=0
        self.readID=0
        
#        self.clock = dut.dutm0_aclk
        
        level = logging.DEBUG if debug else logging.WARNING
        self.maxigp0.log.setLevel(level)
        #Initialize socket
        self.PORT = port
        self.HOST = host   # Symbolic name meaning all available interfaces
        self.socket_conn = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            self.socket_conn.bind((self.HOST, self.PORT))
            self.dut._log.debug('Socket bind complete, HOST=%s, PORT=%d'%(self.HOST,self.PORT))
            self.socket_conn.listen(1) # just a single request (may increase to 5 (backlog)
            self.dut._log.info ('Socket now listening to a single request on port %d: send command, receive response, close'%(self.PORT))
        except socket.error as msg:
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
            #self.soc_conn.send('Welcome to the server. Type something and hit enter\n') #send only takes string
            line = self.soc_conn.recv(4096) # or make it unlimited?
            self.dut._log.info("Received from socket: %s"%(line))
        except:
            self.logErrorTerminate("Socket seems to have died :-(")
        self.dut._log.info("1.Received from socket: %s"%(line))
#        yield Timer(10000)
#        self.dut._log.debug("2.Received from socket: %s"%(line))
        yield self.executeCommand(line)
        self.dut._log.debug("3.Received from socket: %s"%(line))
    
    @cocotb.coroutine
    def executeCommand(self,line):
        self.dut._log.info("1.executeCommand: %s"%(line))
        if not line:
            raise ReturnValue(None)
        self.dut._log.info("2.executeCommand: %s"%(line))
        self.cmd.fromJSON(line)
        if self.cmd.getStart():
            self.dut._log.info('Received START, waiting reset to be over')
            yield Timer(10000)
        
            while self.dut.reset_out.value.get_binstr() != "1":
                yield Timer(10000)
        
            while self.dut.reset_out.value:
                yield Timer(10000)
                
            self.soc_conn.send(self.cmd.toJSON(0)+"\n")
            self.dut._log.debug('Sent 0 to the socket')

        elif self.cmd.getStop():
            self.dut._log.debug('Received STOP, closing...')
            self.soc_conn.send(self.cmd.toJSON(0)+"\n")
            self.soc_conn.close()
            yield Timer(10000) # small pause for the wave output

            self.socket_conn.shutdown(socket.SHUT_RDWR)
            self.socket_conn.close()
            cocotb.regression.tear_down()
            raise TestSuccess('Terminating as received STOP command')
        #For now write - one at a time, TODO: a) consolidate, b) decode address (some will be just a disk file)
        elif self.cmd.getWrite():
            ad = self.cmd.getWrite()
            self.dut._log.info('Received WRITE, 0x%0x: %s'%(ad[0],str(ad[1])))
            rslt = yield self.maxigp0.axi_write(address =     ad[0],
                                            value =           ad[1],
                                            byte_enable =     None,
                                            id =              self.writeID,
                                            dsize =           2,
                                            burst =           1,
                                            address_latency = 0,
                                            data_latency =    0)
            self.dut._log.info('maxigp0.axi_write yielded %s'%(str(rslt)))
            self.writeID = (self.writeID+1) & self.writeIDMask
            self.soc_conn.send(self.cmd.toJSON(rslt)+"\n")
            self.dut._log.debug('Sent rslt to the socket')
        elif self.cmd.getRead():
            a = self.cmd.getRead()
            dval = yield  self.maxigp0.axi_read(address =     a,
                                           id =               self.readID,
                                            dlen =            1,
                                            dsize =           2,
                                            address_latency = 0,
                                            data_latency =    0 )
            self.dut._log.info("axi_read returned => " +str(dval))
            self.readID = (self.readID+1) & self.readIDMask
            self.soc_conn.send(self.cmd.toJSON(dval)+"\n")
            self.dut._log.debug('Sent dval to the socket')
            
def convert_string(txt):
    number=0
    for c in txt:
        number = (number << 8) + ord(c)
    return number   

@cocotb.coroutine
def run_test(dut, port=7777):
    tb = X393_cocotb(dut=dut, host = "", port=7777)
    dut._log.info("Waiting for commnad on socket port %s"%(port))
    while True:
        try:
            rslt= yield tb.receiveCommandFromSocket()
            dut._log.info("rslt = %s"%(str(rslt)))
        except ReturnValue as rv:
            line = rv.retval;
            dut._log.info("rv = %s"%(str(rv)))
            dut._log.info("line = %s"%(str(line)))
#        try:        
#            rslt = yield tb.executeCommand(command_line)
#        except:
#            break;
    tb.socket_conn.close()
    cocotb.regression.tear_down()
    
def run_test_0(dut):
    
    tb = X393_cocotb(dut=dut, host = "", port=7777)
#    tb.logErrorTerminate('Test error terminate')
    yield Timer(10000)

    while dut.reset_out.value.get_binstr() != "1":
        yield Timer(10000)

    while dut.reset_out.value:
        yield Timer(10000)
#    dut.TEST_TITLE.buff = "WRITE"
    dut.TEST_TITLE = convert_string("WRITE")    
    val = yield tb.maxigp0.axi_write(address =         0x1234,
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
    val = yield tb.maxigp0.axi_write(address =         0x5678,
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
#    dval = yield  tb.maxigp0.axi_read(0x1234, 0, 4, 2, 0, 0 )
#    dut.TEST_TITLE.buff = "READ"    
    dut.TEST_TITLE <= convert_string("READ")    
    dval = yield  tb.maxigp0.axi_read(address =         0x1234,
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

