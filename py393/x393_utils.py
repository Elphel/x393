from __future__ import print_function
'''
# Copyright (C) 2015, Elphel.inc.
# Parsing Verilog parameters from the header files
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

import os
#from import_verilog_parameters import VerilogParameters
from x393_mem import X393Mem
#from verilog_utils import hx,concat, bits 
#from verilog_utils import hx
#from subprocess import call
from time import sleep
import vrlg # global parameters
import x393_axi_control_status

DEFAULT_BITFILE="/usr/local/verilog/x393.bit"
FPGA_RST_CTRL= 0xf8000240
FPGA0_THR_CTRL=0xf8000178
FPGA_LOAD_BITSTREAM="/dev/xdevcfg"
INT_STS=       0xf800700c
#SAVE_FILE_NAME="Some_name"# None
class X393Utils(object):
#    global SAVE_FILE_NAME
    DRY_MODE= True # True
    DEBUG_MODE=1
#    vpars=None
    x393_mem=None
    enabled_channels=0 # currently enabled channels
    saveFileName=None
    x393_axi_tasks=None
#    verbose=1
    def __init__(self, debug_mode=1,dry_mode=True ,saveFileName=None):
        self.DEBUG_MODE=debug_mode
        self.DRY_MODE=dry_mode
        if saveFileName:
            self.saveFileName=saveFileName.strip()
        self.x393_mem=X393Mem(debug_mode,dry_mode)
#        self.x393_axi_tasks=X393AxiControlStatus(debug_mode,dry_mode)
        self.x393_axi_tasks=x393_axi_control_status.X393AxiControlStatus(debug_mode,dry_mode)
#        self.__dict__.update(VerilogParameters.__dict__["_VerilogParameters__shared_state"]) # Add verilog parameters to the class namespace
    def reset_get(self):
        """
        Get current reset state
        """
        return self.x393_mem.read_mem(FPGA_RST_CTRL)
    def reset_once(self):
        """
        Pulse reset ON, then OFF
        """
        self.reset((0,0xa))
    def reset(self,data):
        """
        Write data to FPGA_RST_CTRL register
        <data> currently data=1 - reset on, data=0 - reset on
               data can also be a list/tuple of integers, then it will be applied
               in sequence (0,0xe) will turn reset on, then off
        """
        if isinstance(data, (int,long)):
            self.x393_mem.write_mem(FPGA_RST_CTRL,data)
        else:
            for d in data:
                self.x393_mem.write_mem(FPGA_RST_CTRL,d)
    def bitstream(self,
                  bitfile=None,
                  quiet=1):
        """
        Turn FPGA clock OFF, reset ON, load bitfile, turn clock ON and reset OFF
        @param bitfile path to bitfile if provided, otherwise default bitfile will be used
        @param quiet Reduce output
        """
        if bitfile is None:
            bitfile=DEFAULT_BITFILE
        print ("FPGA clock OFF")
        self.x393_mem.write_mem(FPGA0_THR_CTRL,1)
        print ("Reset ON")
        self.reset(0)
        print ("cat %s >%s"%(bitfile,FPGA_LOAD_BITSTREAM))
        if not self.DRY_MODE:
            l=0
            with open(bitfile, 'rb') as src, open(FPGA_LOAD_BITSTREAM, 'wb') as dst:
                buffer_size=1024*1024
                while True:
                    copy_buffer=src.read(buffer_size)
                    if not copy_buffer:
                        break
                    dst.write(copy_buffer)
                    l+=len(copy_buffer)
                    if quiet < 4 :
                        print("sent %d bytes to FPGA"%l)                            

            print("Loaded %d bytes to FPGA"%l)                            
#            call(("cat",bitfile,">"+FPGA_LOAD_BITSTREAM))
        if quiet < 4 :
            print("Wait for DONE")
        if not self.DRY_MODE:
            for _ in range(100):
                if (self.x393_mem.read_mem(INT_STS) & 4) != 0:
                    break
                sleep(0.1)
            else:
                print("Timeout waiting for DONE, [0x%x]=0x%x"%(INT_STS,self.x393_mem.read_mem(INT_STS)))
                return
        if quiet < 4 :
            print ("FPGA clock ON")
        self.x393_mem.write_mem(FPGA0_THR_CTRL,0)
        if quiet < 4 :
            print ("Reset OFF")
        self.reset(0xa)
        self.x393_axi_tasks.init_state()
    
    def exp_gpio (self,
                  mode="in",
                  gpio_low=54,
                  gpio_high=None):
        """
        Export GPIO pins connected to PL (full range is 54..117)
        <mode>     GPIO mode: "in" or "out"
        <gpio_low> lowest GPIO to export     
        <gpio_hi>  Highest GPIO to export. Set to <gpio_low> if not provided     
        """
        if gpio_high is None:
            gpio_high=gpio_low
        print ("Exporting as \""+mode+"\":", end=""),    
        for gpio_n in range (gpio_low, gpio_high + 1):
            print (" %d"%gpio_n, end="")
        print() 
        if not self.DRY_MODE:
            for gpio in range (gpio_low, gpio_high + 1):
                try:
                    with open ("/sys/class/gpio/export","w") as f:
                        print (gpio,file=f)
                except:
                    print ("failed \"echo %d > /sys/class/gpio/export"%gpio)
                try:
                    with open ("/sys/class/gpio/gpio%d/direction"%gpio,"w") as f:
                        print (mode,file=f)
                except:
                    print ("failed \"echo %s > /sys/class/gpio/gpio%d/direction"%(mode,gpio))

    def mon_gpio (self,
                  gpio_low=54,
                  gpio_high=None):
        """
        Get state of the GPIO pins connected to PL (full range is 54..117)
        <gpio_low> lowest GPIO to export     
        <gpio_hi>  Highest GPIO to export. Set to <gpio_low> if not provided
        Returns data as list of 0,1 or None    
        """
        if gpio_high is None:
            gpio_high=gpio_low
        print ("gpio %d.%d: "%(gpio_high,gpio_low), end="")
        d=[]
        for gpio in range (gpio_high, gpio_low-1,-1):
            if gpio != gpio_high and ((gpio-gpio_low+1) % 4) == 0:
                print (".",end="")
            if not self.DRY_MODE:
                try:
                    with open ("/sys/class/gpio/gpio%d/value"%gpio,"r") as f:
                        b=int(f.read(1))
                        print ("%d"%b,end="")
                        d.append(b)
                except:
                    print ("X",end="")
                    d.append(None)
            else:
                print ("X",end="")
                d.append(None)
        print()
        return d
    
    def getParTmpl(self):
        return ({"name":"DLY_LANE0_ODELAY", "width": 80, "decl_width":"","disable":False}, # decl_width can be "[7:0]", "integer", etc
                {"name":"DLY_LANE0_IDELAY", "width": 72, "decl_width":"","disable":False},
                {"name":"DLY_LANE1_ODELAY", "width": 80, "decl_width":"","disable":False},
                {"name":"DLY_LANE1_IDELAY", "width": 72, "decl_width":"","disable":False},
                {"name":"DLY_CMDA",         "width":256, "decl_width":"","disable":False},
                {"name":"DLY_PHASE",        "width": 8,  "decl_width":"","disable":False},
                {"name":"DFLT_WBUF_DELAY",  "width": 4,  "decl_width":"","disable":True},
                {"name":"DFLT_WSEL",        "width": 1,  "decl_width":"","disable":True},
                {"name":"DFLT_RSEL",        "width": 1,  "decl_width":"","disable":True},
                )
 
    def localparams(self,
                    quiet=False):
        """
        Generate verilog include file with localparam definitions for the DDR3 timing parameters
        Returns definition as a string
        """
        nameLen=0
        declWidth=0
        for p in self.getParTmpl(): #parTmpl:
            nameLen=max(nameLen,len(p['name']))
            declWidth=max(declWidth,len(p['decl_width']))
        txt=""
        for p in self.getParTmpl(): # parTmpl:
            numDigits = (p["width"]+3)/4
            frmt="localparam %%%ds %%%ds %3d'h%%0%dx;\n"%(declWidth,nameLen+2,p["width"],numDigits)
            try:
                pv=vrlg.__dict__[p['name']]
                if p['disable']:
                    txt += '// '
                txt+=frmt%(p['decl_width'],p['name']+" =",pv)
            except: # parameter does not exist
                pass
        if not quiet:
            print (txt)
        return txt
    
    def save_defaults(self,
                      allPars=False):
        """
        Save current parameter values to defaults (as read at start up)
        <allPars>  use all parameters, if false - only for the ones used in
                   'save' file  
        """
#        global parTmpl
        if allPars:
            vrlg.save_default()
        else:
            for par in self.getParTmpl(): # parTmpl:
                vrlg.save_default(par['name'])
            
    def restore_defaults(self,
                         allPars=False):
        """
        Restore parameter values from defaults (as read at start up)
        <allPars>  use all parameters, if false - only for the ones used in
                   'save' file  
        """
        global parTmpl
        if allPars:
            vrlg.restore_default()
        else:
            for par in parTmpl:
                vrlg.restore_default(par['name'])
    
    def save(self,
                    fileName=None):
        """
        Write Verilog include file with localparam definitions for the DDR3 timing parameters
        Also copies the same parameter values to defaults
        <fileName> - optional path to write, pre-defined name if not specified
        """
        header= """/* This is a generated file with the current DDR3 memory timing parameters */

"""
        self.save_defaults(False) # copy current parameters to defaults
        if not fileName:
            fileName=self.saveFileName
        txt=self.localparams(True) #quiet

        if fileName:
            try:
                with open(fileName, "w") as text_file:
                    text_file.write(header)
                    text_file.write(txt)
                    print ("Verilog parameters are written to  %s"%(os.path.abspath(fileName)))

            except:
                print ("Failed to write to %s"%(os.path.abspath(fileName)))
        else:
            print(txt)   

