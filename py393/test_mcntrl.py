#!/usr/bin/env python3
# encoding: utf-8
'''
# Copyright (C) 2015, Elphel.inc.
# test for import_verilog_parameters.py
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
from __future__ import print_function
from __future__ import division
#from __builtin__ import str
__author__ = "Andrey Filippov"
__copyright__ = "Copyright 2015, Elphel, Inc."
__license__ = "GPL"
__version__ = "3.0+"
__maintainer__ = "Andrey Filippov"
__email__ = "andrey@elphel.com"
__status__ = "Development"

'''
./test_mcntrl.py -v -f../system_defines.vh -f ../includes/x393_parameters.vh  ../includes/x393_localparams.vh -pNEWPAR=\'h3ff -c write_mem 0x377 25 -c read_mem 0x3ff -i -d aaa=bbb -d ccc=ddd

'''

#import readline
import sys
import os
import inspect
import re
#import os.path
from argparse import ArgumentParser
#import argparse
from argparse import RawDescriptionHelpFormatter
import time
#import shutil
import socket
import select
import traceback

from import_verilog_parameters import ImportVerilogParameters
#from import_verilog_parameters import VerilogParameters
from verilog_utils             import hx 

import x393_mem
import x393_utils
import x393_axi_control_status
import x393_pio_sequences
import x393_mcntrl_timing
import x393_mcntrl_buffers
import x393_mcntrl_tests
import x393_mcntrl_eyepatterns
import x393_mcntrl_adjust
import x393_mcntrl_membridge
import x393_sens_cmprs
import x393_camsync
import x393_gpio
import x393_cmprs_afi
import x393_cmprs
import x393_frame_sequencer
import x393_sensor
import x393_rtc
import x393_jpeg
import vrlg
import x393_export_c
import x393_logger
__all__ = []
__version__ = 0.1
__date__ = '2015-03-01'
__updated__ = '2015-03-01'

DEBUG = 0 # 1
TESTRUN = 0
PROFILE = 0
QUIET=1 # more try/excepts
callableTasks={}

class CLIError(Exception):
    #Generic exception to raise and log different fatal errors.
    def __init__(self, msg):
        super(CLIError).__init__(type(self))
        self.msg = "E: %s" % msg
    def __str__(self):
        return self.msg
    def __unicode__(self):
        return self.msg

def extractTasks(obj,inst):
    for name in obj.__dict__:
        if hasattr((obj.__dict__[name]), '__call__') and not (name[0]=='_'):
            func_args=obj.__dict__[name].__code__.co_varnames[1:obj.__dict__[name].__code__.co_argcount]
            callableTasks[name]={'func':obj.__dict__[name],
                                 'args':func_args,
                                 'dflts':obj.__dict__[name].__defaults__,
                                 'inst':inst,
                                 'docs':inspect.getdoc(obj.__dict__[name])}
def execTask(commandLine):
    result=None
    cmdList=commandLine #.split()
    try:
        funcName=cmdList[0]
        funcArgs=cmdList[1:]
    except:
        return None
    for i,arg in enumerate(funcArgs):
        try:
            funcArgs[i]=eval(arg) # Try parsing parameters as numbers, if possible
        except:
            pass
    if QUIET:
        try:
            result = callableTasks[funcName]['func'](callableTasks[funcName]['inst'],*funcArgs)
        except Exception as e:
            print ('Error while executing %s %s'%(funcName,str(funcArgs)))
            print ("QUIET=%d"%QUIET)
            try:
                funcFArgs= callableTasks[funcName]['args']
            except:
                print ("Unknown task: %s"%(funcName))
                return None
            sFuncArgs=""
            if funcFArgs:
                sFuncArgs+='<'+str(funcFArgs[0])+'>'
            for a in funcFArgs[1:]:
                sFuncArgs+=' <'+str(a)+'>'
            print ("Usage:\n%s %s"%(funcName,sFuncArgs))
            print ("exception message:"+str(e))
            print (traceback.format_exc())
    else:
        result = callableTasks[funcName]['func'](callableTasks[funcName]['inst'],*funcArgs)
    return result


def getFuncArgsString(name):
    funcFArgs=callableTasks[name]['args'] # () if none
    funcDflts=callableTasks[name]['dflts'] # None if no parameters, not empty tuple
#    print ("<<< %s : %s"%(funcFArgs,funcDflts))
    sFuncArgs=""
    if funcFArgs:
        offs=len(funcFArgs)
        if not funcDflts is None:
            offs-=len(funcDflts)
#        sFuncArgs+='<'+str(funcFArgs[0])+'>'
        for i,a in enumerate(funcFArgs):
            sFuncArgs+=' <'+str(a)
            if i>=offs:
                sFuncArgs+='='+str(funcDflts[i-offs])
            sFuncArgs+='> '
    return sFuncArgs
#dflts
    
def main(argv=None): # IGNORE:C0111
    tim=time.time()
    '''Command line options.'''
    global QUIET
    if argv is None:
        argv = sys.argv
    else:
        sys.argv.extend(argv)
        
    program_name = os.path.basename(sys.argv[0])
    program_version = "v%s" % __version__
    program_build_date = str(__updated__)
    program_version_message = '%%(prog)s %s (%s)' % (program_version, program_build_date)
    program_shortdesc = __import__('__main__').__doc__.split("\n")[1]
    program_license = '''%s

  Created by %s on %s.
  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.

USAGE
''' % (program_shortdesc, __author__,str(__date__))
    try:
        # Setup argument parser
        parser = ArgumentParser(description=program_license, formatter_class=RawDescriptionHelpFormatter,fromfile_prefix_chars='@')
        parser.add_argument("-v", "--verbose", dest="verbose", action="count", help="set verbosity level [default: %(default)s]")
        parser.add_argument('-V', '--version', action='version', version=program_version_message)
#        parser.add_argument(                   dest="paths", help="Verilog include files with parameter definitions [default: %(default)s]", metavar="path", nargs='*')
        parser.add_argument("-f", "--icludeFile",  dest="paths", action="append", default=[],
                             help="Verilog include files with parameter definitions [default: %(default)s]", metavar="path", nargs='*')
        parser.add_argument("-d", "--define",  dest="defines", action="append", default=[], help="Define macro(s)" , nargs='*' )
        parser.add_argument("-p", "--parameter",  dest="parameters", action="append", default=[], help="Define parameter(s) as name=value" , nargs='*' )
        parser.add_argument("-c", "--command",  dest="commands", action="append", default=[], help="execute command" , nargs='*')
        parser.add_argument("-i", "--interactive", dest="interactive", action="store_true", help="enter interactive mode [default: %(default)s]")
        parser.add_argument("-s", "--simulated", dest="simulated", action="store", help="Simulated mode (no real hardware I/O) [default: %(default)s]")
        parser.add_argument("-x", "--exceptions", dest="exceptions", action="count", help="Exit on more exceptions [default: %(default)s]")
        parser.add_argument("-l", "--localparams",  dest="localparams", action="store", default="",
                             help="path were modified parameters are saved [default: %(default)s]", metavar="path")
        parser.add_argument("-P", "--socket-port",  dest="socket_port", action="store", default="",
                             help="port to use for socket connection [default: %(default)s]")

        # Process arguments
        args = parser.parse_args()
        if not args.exceptions:
            args.exceptions=0
          
            
        QUIET = (1,0)[args.exceptions]
#        print ("args.exception=%d, QUIET=%d"%(args.exceptions,QUIET))
        print("args.simulated = ",args.simulated)
        print("args = ",args)
        if not args.simulated:
            if not os.path.exists("/dev/xdevcfg"):
                args.simulated="simulated"
                print("Program is forced to run in SIMULATED mode as '/dev/xdevcfg' does not exist (not a camera)")
        #print("--- defines=%s"%    str(args.defines))
        #print("--- paths=%s"%      str(args.paths))
        #print("--- parameters=%s"% str(args.parameters))
        #print("--- commands=%s"%   str(args.commands))
            #        paths = args.paths
        verbose = args.verbose
        if not verbose:
            verbose=0
#        print("args=%s"%(str(args)))  
#        print("sys.argv=%s"%(str(sys.argv))) 
#        print("DEBUG=%s"%(str(DEBUG))) 
#        print ("verbose=%d"%verbose)
        
        
        paths=[]
        if (args.paths):
            for group in args.paths:
                for item in group:
                    paths+=item.split()
        print("+++ paths=%s"%      str(paths))
        print("localparams=%s"%str(args.localparams))
        
        preDefines={}
        preParameters={}
        showResult=False

        if (args.defines):
            defines=[]
            for group in args.defines:
                for item in group:
                    defines+=item.split()
            for predef in defines:
                kv=predef.split("=")
                if len(kv)<2:
                    kv.append("")
                preDefines[kv[0].strip("`")]=kv[1]
        #print("+++ defines=%s"%      str(preDefines))

        if verbose > -1: # always
#            print("Verbose mode on "+hex(verbose))
            args.parameters.append(['VERBOSE=%d'%verbose]) # add as verilog parameter
        
        if (args.parameters):
            parameters=[]
            for group in args.parameters:
                for item in group:
                    parameters+=item.split()
            for prePars in parameters:
                kv=prePars.split("=")
                if len(kv)>1:
                    preParameters[kv[0]]=(kv[1],"RAW",kv[1])
        #print("+++ parameters=%s"%      str(preParameters))
        commands=[]
        if (args.commands):
            for group in args.commands:
                cmd=[]
                for item in group:
                    cmd+=item.split()
                commands.append(cmd)    
        #print("+++ commands=%s"%      str(commands))
    except KeyboardInterrupt:
        ### handle keyboard interrupt ###
        return 0
    except Exception as e:
        if DEBUG or TESTRUN: 
            raise(e)
        indent = len(program_name) * " "
        sys.stderr.write(program_name + ": " + repr(e) + "\n")
        sys.stderr.write(indent + "  for help use --help")
        return 2
# Take out from the try/except for debugging
    ivp= ImportVerilogParameters(preParameters,preDefines)
    if verbose > 3: print ('paths='+str(paths))   
    if verbose > 3: print ('defines='+str(args.defines))   
    if verbose > 3: print ('parameters='+str(args.parameters)) 
    if verbose > 3: print ('comamnds='+str(commands)) 
    for path in paths:
        if verbose > 2: print ('path='+str(path))
        ### do something with inpath ###
        ivp.readParameterPortList(path)
    parameters=ivp.getParameters()
    #set all verilog parameters as module-level ones in vrlg (each parameter creates 3 names)
    if (parameters):
        vrlg.init_vars(ivp.parsToDict(parameters))
#    vpars=VerilogParameters(parameters)
    
    if verbose > 3:
        defines= ivp.getDefines()
        print ("======= Extracted defines =======")
        for macro in defines:
            print ("`"+macro+": "+defines[macro])        
        print ("======= Parameters =======")
        for par in parameters:
            try:
                print (par+" = "+hex(parameters[par][0])+" (type = "+parameters[par][1]+" raw = "+parameters[par][2]+")")        
            except:
                print (par+" = "+str(parameters[par][0])+" (type = "+parameters[par][1]+" raw = "+parameters[par][2]+")")
        print("vrlg.VERBOSE="+str(vrlg.VERBOSE))
        print("vrlg.VERBOSE__TYPE="+str(vrlg.VERBOSE__TYPE))
        print("vrlg.VERBOSE__RAW="+str(vrlg.VERBOSE__RAW))
    
    x393mem =            x393_mem.X393Mem(verbose,args.simulated) #add dry run parameter
    x393utils =          x393_utils.X393Utils(verbose,args.simulated,args.localparams)
    x393tasks =          x393_axi_control_status.X393AxiControlStatus(verbose,args.simulated)
    x393Pio =            x393_pio_sequences.X393PIOSequences(verbose,args.simulated)
    x393Timing =         x393_mcntrl_timing.X393McntrlTiming(verbose,args.simulated)
    x393Buffers =        x393_mcntrl_buffers.X393McntrlBuffers(verbose,args.simulated)
    x393Tests =          x393_mcntrl_tests.X393McntrlTests(verbose,args.simulated)
    x393Eyepatterns =    x393_mcntrl_eyepatterns.X393McntrlEyepattern(verbose,args.simulated)
    x393Adjust =         x393_mcntrl_adjust.X393McntrlAdjust(verbose,args.simulated,args.localparams)
    X393Membridge =      x393_mcntrl_membridge.X393McntrlMembridge(verbose,args.simulated)
    x393SensCmprs =      x393_sens_cmprs.X393SensCmprs(verbose,args.simulated,args.localparams)
    x393Camsync =        x393_camsync.X393Camsync(verbose,args.simulated,args.localparams)
    x393GPIO =           x393_gpio.X393GPIO(verbose,args.simulated,args.localparams)
    x393CmprsAfi =       x393_cmprs_afi.X393CmprsAfi(verbose,args.simulated,args.localparams)
    x393Cmprs =          x393_cmprs.X393Cmprs(verbose,args.simulated,args.localparams)
    x393FrameSequencer = x393_frame_sequencer.X393FrameSequencer(verbose,args.simulated,args.localparams)
    x393Sensor =         x393_sensor.X393Sensor(verbose,args.simulated,args.localparams)
    x393Rtc =            x393_rtc.X393Rtc(verbose,args.simulated,args.localparams)
    x393Jpeg =           x393_jpeg.X393Jpeg(verbose,args.simulated,args.localparams)
    x393ExportC=         x393_export_c.X393ExportC(verbose,args.simulated,args.localparams)
    x393Logger =         x393_logger.X393Logger(verbose,args.simulated,args.localparams)
    #X393Logger
    '''
    print ("----------------------")
    print("x393_mem.__dict__="+str(x393_mem.__dict__))
    print ("----------------------")
    print("x393mem.__dict__="+str(x393mem.__dict__))
    print ("----------------------")
    print("x393_mem.X393Mem.__dict__="+str(x393_mem.X393Mem.__dict__))
    '''
    if verbose > 3: 
        print ("----------------------")
        for name in x393_mem.X393Mem.__dict__:
            if hasattr((x393_mem.X393Mem.__dict__[name]), '__call__') and not (name[0]=='_'):
                func_args=x393_mem.X393Mem.__dict__[name].__code__.co_varnames[1:x393_mem.X393Mem.__dict__[name].__code__.co_argcount]
                print (name+": "+str(func_args))
    extractTasks(x393_mem.X393Mem,x393mem)
    extractTasks(x393_utils.X393Utils,                         x393utils)
    extractTasks(x393_axi_control_status.X393AxiControlStatus, x393tasks)
    extractTasks(x393_pio_sequences.X393PIOSequences,          x393Pio)
    extractTasks(x393_mcntrl_timing.X393McntrlTiming,          x393Timing)
    extractTasks(x393_mcntrl_buffers.X393McntrlBuffers,        x393Buffers)
    extractTasks(x393_mcntrl_tests.X393McntrlTests,            x393Tests)
    extractTasks(x393_mcntrl_eyepatterns.X393McntrlEyepattern, x393Eyepatterns)
    extractTasks(x393_mcntrl_adjust.X393McntrlAdjust,          x393Adjust)
    extractTasks(x393_mcntrl_membridge.X393McntrlMembridge,    X393Membridge)
    extractTasks(x393_sens_cmprs.X393SensCmprs,                x393SensCmprs)
    extractTasks(x393_camsync.X393Camsync,                     x393Camsync)
    extractTasks(x393_gpio.X393GPIO,                           x393GPIO)
    extractTasks(x393_cmprs_afi.X393CmprsAfi,                  x393CmprsAfi)
    extractTasks(x393_cmprs.X393Cmprs,                         x393Cmprs)
    extractTasks(x393_frame_sequencer.X393FrameSequencer,      x393FrameSequencer)
    extractTasks(x393_sensor.X393Sensor,                       x393Sensor)
    extractTasks(x393_rtc.X393Rtc,                             x393Rtc)
    extractTasks(x393_jpeg.X393Jpeg,                           x393Jpeg)
    extractTasks(x393_export_c.X393ExportC,                    x393ExportC)
    extractTasks(x393_logger.X393Logger,                       x393Logger)

    for cmdLine in commands:
        print ('Running task: '+str(cmdLine))
        rslt= execTask(cmdLine)
        print ('    Result: '+str(rslt))
    '''       
#TODO: use readline 
    '''
    if args.socket_port:
        PORT = int(args.socket_port) # 8888
    else:
        PORT = 0
    HOST = ''   # Symbolic name meaning all available interfaces
    socket_conn = None
    if PORT:
        socket_conn = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            socket_conn.bind((HOST, PORT))
            print ('Socket bind complete')
            socket_conn.listen(1) # just a single request
            print ('Socket now listening to a single request on port %d: send command, receive response, close'%(PORT))
        except socket.error as msg:
            print ('Bind failed. Error Code : %s Message %s'%( str(msg[0]),msg[1]))
            socket_conn = None # do not use sockets
        
    if (args.interactive):
        line =""
        while True:
            soc_conn = None
            prompt = 'x393 (%s) +%3.3fs--> '%(args.simulated,(time.time()-tim)) if args.simulated else 'x393 +%3.3fs--> '%(time.time()-tim)
            #prompt = 'x393%s +%3.3fs--> '%(args.simulated,(time.time()-tim))
            if socket_conn:
                print ("***socket_conn***")
                print(prompt , end="")
                sys.stdout.flush()
                if (args.socket_port):
                    ready_to_read, _, _ = select.select( #ready_to_write, in_error
                          #[socket_conn, sys.stdin], # potential_readers,
                          [socket_conn], # potential_readers,
                          [],         # potential_writers,
                          [])         # potential_errs,
                else:
                    ready_to_read, _, _ = select.select( #ready_to_write, in_error
                          [socket_conn, sys.stdin], # potential_readers,
                          [],         # potential_writers,
                          [])         # potential_errs,
                if (not args.socket_port) and (sys.stdin in ready_to_read):
#                   line=raw_input()#python2
                    input()
#                    print ("stdin: ", line)
                elif socket_conn in ready_to_read:
                    try:
                        soc_conn, soc_addr = socket_conn.accept()
                        print ("Connected with %s"%(soc_addr[0] + ':' + str(soc_addr[1])))
                        #Sending message to connected client
                        #soc_conn.send('Welcome to the server. Type something and hit enter\n') #send only takes string
                        line = soc_conn.recv(4096) # or make it unlimited?
                        print ('Received from socket: ', line)
                    except:
                        continue # socket probably died, wait for the next command    
                else:
                    print ("Unexpected result from select: ready_to_read = ",ready_to_read)
                    continue
            else: # No sockets, just command line input
                if (not args.socket_port):
#                   line=raw_input(prompt) #python2
                    line=input(prompt)
                        
            line=line.strip() # maybe also remove comment?

            # Process command, return result to a socket if it was a socket, not stdin


            tim=time.time()
            #remove comment from the input line
            had_comment=False
            if line.find("#") >= 0:
                line=line[:line.find("#")]
                had_comment=True
            lineList=line.split()
            if not line:
                if not had_comment:
                    print ('Use "quit" to exit, "help" - for help')
            elif (line == 'quit') or (line == 'exit'):
                if soc_conn:
                    soc_conn.send('0\n') # OK\n')
                    soc_conn.close()
#                    soc_conn=None
                break
            elif line== 'help' :
                print ("\nAvailable tasks:")
                for name,val in sorted(callableTasks.items()):
                    sFuncArgs=getFuncArgsString(name)
                    print ("Usage: %s %s"%(name,sFuncArgs))
                print ('\n"parameters" and "defines" list known defined parameters and macros')
                print ("args.exception=%d, QUIET=%d"%(args.exceptions,QUIET))
                print ("Enter 'R' to toggle show/hide command results, now it is %s"%(("OFF","ON")[showResult]))
                print ("Use 'socket_port [PORT]' to (re-)open socket on PORT (0 or no PORT - disable socket)")
#               print ("Use 'copy <SRC> <DST> to copy files in file the system")
                print ("Use 'pydev_predefines' to generate a parameter list to paste to vrlg.py, so Pydev will be happy")
            elif lineList[0].upper() == 'R':
                if len(lineList)>1:
                    if (lineList[1].upper() == "ON") or (lineList[1].upper() == "1") or (lineList[1].upper() == "TRUE"):
                        showResult=True
                    elif (lineList[1].upper() == "OFF") or (lineList[1].upper() == "0") or (lineList[1].upper() == "FALSE"):
                        showResult=False
                    else:
                        print ("Unrecognized parameter %s for 'R' command"%lineList[1])
                else:
                    showResult = not showResult
                print ("Show results mode is now %s"%(("OFF","ON")[showResult]))
            elif (lineList[0].upper() == 'SOCKET_PORT') and (not soc_conn): # socket_conn):
                if socket_conn : # close old socket (if open)
                    print ("Closed socket on port %d"%(PORT))
                    socket_conn.close()
                    socket_conn = None
                if len(lineList) > 1: # port specified
                    PORT = int(lineList[1])
                    if PORT:
                        socket_conn = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                        try:
                            socket_conn.bind((HOST, PORT))
                            print ('Socket bind complete')
                            socket_conn.listen(1) # just a single request
                            print ('Socket now listening to a single request on port %d: send command, receive response, close'%(PORT))
                        except socket.error as msg:
                            print ('Bind failed. Error Code : %s Message %s'%( str(msg[0]),msg[1]))
                            socket_conn = None # do not use sockets
                continue            
#            elif lineList[0] == 'copy':
#                shutil.copy2(lineList[1], lineList[2])    
            elif lineList[0] == 'help':
                helpFilter=lineList[1] # should not fail
                try:
                    re.match(helpFilter,"")
                except:
                    print("Invalid search expression: %s"%helpFilter)
                    helpFilter=None    
                if helpFilter:
                    print
                    for name,val in sorted(callableTasks.items()):
                        if re.match(helpFilter,name):
                            #enable_memcntrl enable_memcntr .__class__.__name__
                            print('=== %s ==='%name)
                            print('defined in %s.%s, %s: %d)'%(str(callableTasks[name]['inst'].__class__.__module__),
                                                       callableTasks[name]['inst'].__class__.__name__,
                                                       callableTasks[name]['func'].__code__.co_filename,
                                                       callableTasks[name]['func'].__code__.co_firstlineno
                                  ))
                            sFuncArgs=getFuncArgsString(name)
                            docs=callableTasks[name]['docs']
                            if docs:
                                docsl=docs.split("\n")
                                for l in docsl:
                                    #print ('    %s'%l)
                                    print ('%s'%l)
                                    #print(docs)
                            print ("     Usage: %s %s\n"%(name,sFuncArgs))
            elif lineList[0] == 'parameters':
                nameFilter = None
                if len(lineList)> 1:
                    nameFilter=lineList[1]
                    try:
                        re.match(nameFilter,"")
                    except:
                        print("Invalid search expression: %s"%nameFilter)
                        nameFilter=None    
                parameters=ivp.getParameters()
                for par,val in sorted(parameters.items()):
                    if (not nameFilter) or re.match(nameFilter,par):
                        try:
                            print (par+" = "+hex(val[0])+" (type = "+val[1]+" raw = "+val[2]+")")        
                        except:
                            print (par+" = "+str(val[0])+" (type = "+val[1]+" raw = "+val[2]+")")
                if nameFilter is None:
                    print("    'parameters' command accepts regular expression as a second parameter to filter the list")        
            elif (lineList[0] == 'defines') or (lineList[0] == 'macros'):
                nameFilter = None
                if len(lineList)> 1:
                    nameFilter=lineList[1]
                    try:
                        re.match(nameFilter,"")
                    except:
                        print("Invalid search expression: %s"%nameFilter)
                        nameFilter=None    
                defines= ivp.getDefines()
                for macro,val in sorted(defines.items()):
                    if (not nameFilter) or re.match(nameFilter,macro):
                        print ("`"+macro+": "+str(val))
                if nameFilter is None:
                    print("    'defines' command accepts regular expression as a second parameter to filter the list")
            elif (lineList[0] == 'pydev_predefines'):
                predefines=""
                for k,v in ivp.parsToDict(parameters).items():
                    typ=str(type(v))
                    typ=typ[typ.find("'")+1:typ.rfind("'")]
                    if "None" in typ:
                        typ="None"
                    predefines += "%s = %s\n"%(k,typ)
#                    print ("%s = %s"%(k,typ))
                vrlg_path=vrlg.__dict__["init_vars"].__code__.co_filename
#                print ("vrlg path: %s"%(vrlg_path))
                try:
                    magic="#### PyDev predefines"
                    with open (vrlg_path, "r") as vrlg_file:
                        vrlg_text=vrlg_file.read()
                    index= vrlg_text.index(magic) #will fail if not found
                    index= vrlg_text.index('\n',index)
                    vrlg_text=vrlg_text[:index+1]+"\n"+predefines
                except:
                    print ("Failed to update %s - it is either missing or does not have a '%s'"%(vrlg_path,magic))
                    if soc_conn:
                        soc_conn.send('0\n')
                        soc_conn.close()
#                        soc_conn=None
                    continue
                try:
                    with open (vrlg_path, "w") as vrlg_file:
                        vrlg_file.write(vrlg_text)
                    print ("Updated file %s"%(vrlg_path))
                except:
                    print ("Failed to re-write %s\n"%(vrlg_path))
                    print (vrlg_text)
                    print ("\nFailed to re-write %s"%(vrlg_path))
            else:
#                cmdLine=line.split()
                cmdLine=[lineList[0]]
                l=line[len(lineList[0]):].strip()
                while l:
                    if l[0] == '"':
                        indx=l.find('"',1) # skip opening
                        if  indx > 0:
                            cmdLine.append(l[:indx+1]) # including ""
                            l=l[indx+1:].strip()
                            continue
                    indx=l.find(' ')
                    if indx<0:
                        indx=len(l) # use all the remaining l as next argument
                    cmdLine.append(l[:indx]) # including ""
                    l=l[indx:].strip()
                        
#                strarg=line[len(lineList[0]):].strip()
                rslt= execTask(cmdLine)
                if showResult:
                    print ('    Result: '+hx(rslt))
                if soc_conn:
                    soc_conn.send(str(rslt)+'\n')
                    soc_conn.close()
#                    soc_conn=None
                continue    
            if soc_conn:
                soc_conn.send('0\n')
                soc_conn.close()
#                soc_conn=None
       
#http://stackoverflow.com/questions/11781265/python-using-getattr-to-call-function-with-variable-parameters
#*getattr(foo,bar)(*params)   
    return 0

if __name__ == "__main__":
    if DEBUG:
#        sys.argv.append("-h")
        sys.argv.append("-v")
    if TESTRUN:
        import doctest
        doctest.testmod()
    if PROFILE:
        import cProfile
        import pstats
        profile_filename = 'test1_profile.txt'
        cProfile.run('main()', profile_filename)
        statsfile = open("profile_stats.txt", "wb")
        p = pstats.Stats(profile_filename, stream=statsfile)
        stats = p.strip_dirs().sort_stats('cumulative')
        stats.print_stats()
        statsfile.close()
        sys.exit(0)
    sys.exit(main())