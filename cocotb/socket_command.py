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
import json
import socket

class SocketCommand():
    command=None
    arguments=None
    def __init__(self, command=None, arguments=None): # , debug=False):
        self.command = command
        self.arguments=arguments
    def getCommand(self):
        return self.command
    def getArgs(self):
        return self.arguments
    def getStart(self):
        return self.command == "start" 
    def getStop(self):
        return self.command == "stop" 
    def getWrite(self):
        return self.arguments if self.command == "write" else None
    def getWait(self):
        return self.arguments if self.command == "wait" else None
    def getFlush(self):
        return self.command == "flush"
    def getRead(self):
        return self.arguments if self.command == "read" else None
    def setStart(self):
        self.command = "start"
    def setStop(self):
        self.command = "stop"
    def setWrite(self,arguments):
        self.command = "write"
        self.arguments=arguments
    def setWait(self,arguments): # wait irq mask, timeout (ns)
        self.command = "wait"
        self.arguments=arguments
    def setFlush(self):         #flush memory file (use when sync_for_*
        self.command = "flush"
    def setRead(self,arguments):
        self.command = "read"
        self.arguments=arguments
    def toJSON(self,val=None):
        if val is None:
            return json.dumps({"cmd":self.command,"args":self.arguments})
        else:
            return json.dumps(val)    
    def fromJSON(self,jstr):
        d=json.loads(jstr)
        try:
            self.command=d['cmd']
        except:
            self.command=None
        try:
            self.arguments=d['args']
        except:
            self.arguments=None
        
class x393Client():
    def __init__(self, host='localhost', port=7777):
        self.PORT = port
        self.HOST = host   # Symbolic name meaning all available interfaces
        self.cmd= SocketCommand()
    def communicate(self, snd_str):
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect((self.HOST, self.PORT))
        sock.send(snd_str)
        reply = sock.recv(16384)  # limit reply to 16K
        sock.close()
        return reply
    def start(self):
        self.cmd.setStart()
        print("start->",self.communicate(self.cmd.toJSON()))
    def stop(self):
        self.cmd.setStop()
        print("stop->",self.communicate(self.cmd.toJSON()))
    def write(self, address, data):
        self.cmd.setWrite([address,data])
        rslt = self.communicate(self.cmd.toJSON())
#        print("write->",rslt)
    def waitIrq(self, irqMask,wait_ns):
        self.cmd.setWait([irqMask,wait_ns])
        rslt = self.communicate(self.cmd.toJSON())
#        print("waitIrq->",rslt)
    def flush(self):
        self.cmd.setFlush()
#        print("flush->",self.communicate(self.cmd.toJSON()))

    def read(self, address):
        self.cmd.setRead(address)
#        print("read->args",self.cmd.getArgs())
        rslt = self.communicate(self.cmd.toJSON())
        #print("read->",rslt)
        return json.loads(rslt)
        
