#!/usr/bin/env python
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
import sys
import os
import inspect
import re
#import os.path
from argparse import ArgumentParser
#import argparse
from argparse import RawDescriptionHelpFormatter

from import_verilog_parameters import ImportVerilogParameters
from import_verilog_parameters import VerilogParameters
import x393_mem
import x393_utils
import x393_axi_control_status
import x393_pio_sequences
import x393_mcntrl_timing
import x393_mcntrl_buffers
import x393_mcntrl_tests
__all__ = []
__version__ = 0.1
__date__ = '2015-03-01'
__updated__ = '2015-03-01'

DEBUG = 1
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
'''
    for name in x393_mem.X393Mem.__dict__:
        if hasattr((x393_mem.X393Mem.__dict__[name]), '__call__') and not (name[0]=='_'):
            func_args=x393_mem.X393Mem.__dict__[name].func_code.co_varnames[1:x393_mem.X393Mem.__dict__[name].func_code.co_argcount]
#            print (name+": "+str(x393_mem.X393Mem.__dict__[name]))
#            print ("args="+str(func_args))
            print (name+": "+str(func_args))

'''
def extractTasks(obj,inst):
    for name in obj.__dict__:
        if hasattr((obj.__dict__[name]), '__call__') and not (name[0]=='_'):
#            print (name+" -->"+str(obj.__dict__[name]))
#            print (obj.__dict__[name].func_code)
#            print ("COMMENTS:"+str(inspect.getcomments(obj.__dict__[name])))
#            print ("DOCS:"+str(inspect.getdoc(obj.__dict__[name])))
            func_args=obj.__dict__[name].func_code.co_varnames[1:obj.__dict__[name].func_code.co_argcount]
            callableTasks[name]={'func':obj.__dict__[name],'args':func_args,'inst':inst,'docs':inspect.getdoc(obj.__dict__[name])}
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
    else:
        result = callableTasks[funcName]['func'](callableTasks[funcName]['inst'],*funcArgs)
    return result
def hx(obj):
    try:
        return "0x%x"%obj
    except:
        return str(obj)

def getFuncArgsString(name):
    funcFArgs=callableTasks[name]['args']
    sFuncArgs=""
    if funcFArgs:
        sFuncArgs+='<'+str(funcFArgs[0])+'>'
        for a in funcFArgs[1:]:
            sFuncArgs+=' <'+str(a)+'>'
    return sFuncArgs

    
def main(argv=None): # IGNORE:C0111
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
    preDefines={}
    preParameters={}
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
        parser.add_argument("-s", "--simulated", dest="simulated", action="store_true", help="Simulated mode (no real hardware I/O) [default: %(default)s]")
        parser.add_argument("-x", "--exceptions", dest="exceptions", action="count", help="Exit on more exceptions [default: %(default)s]")

        # Process arguments
        args = parser.parse_args()
        if not args.exceptions:
            args.exceptions=0
    
        QUIET = (1,0)[args.exceptions]
#        print ("args.exception=%d, QUIET=%d"%(args.exceptions,QUIET))
        if not args.simulated:
            if not os.path.exists("/dev/xdevcfg"):
                args.simulated=True
                print("Program is forced to run in SIMULATED mode as '/dev/xdevcfg' does not exist (not a camera)")
        #print("--- defines=%s"%    str(args.defines))
        #print("--- paths=%s"%      str(args.paths))
        #print("--- parameters=%s"% str(args.parameters))
        #print("--- commands=%s"%   str(args.commands))
            #        paths = args.paths
        verbose = args.verbose
        paths=[]
        if (args.paths):
            for group in args.paths:
                for item in group:
                    paths+=item.split()
        #print("+++ paths=%s"%      str(paths))
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

        if verbose > 0:
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
    except Exception, e:
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
    vpars=VerilogParameters(parameters)
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
        print("vpars.VERBOSE="+str(vpars.VERBOSE))
        print("vpars.VERBOSE__TYPE="+str(vpars.VERBOSE__TYPE))
        print("vpars.VERBOSE__RAW="+str(vpars.VERBOSE__RAW))
    
    if verbose > 3: print (VerilogParameters.__dict__)
    vpars1=VerilogParameters()
    if verbose > 3: print("vpars1.VERBOSE="+str(vpars1.VERBOSE))
    if verbose > 3: print("vpars1.VERBOSE__TYPE="+str(vpars1.VERBOSE__TYPE))
    if verbose > 3: print("vpars1.VERBOSE__RAW="+str(vpars1.VERBOSE__RAW))
    
    x393mem=    x393_mem.X393Mem(verbose,args.simulated) #add dry run parameter
    x393utils=  x393_utils.X393Utils(verbose,args.simulated)
    x393tasks=  x393_axi_control_status.X393AxiControlStatus(verbose,args.simulated)
    x393Pio=    x393_pio_sequences.X393PIOSequences(verbose,args.simulated)
    x393Timing= x393_mcntrl_timing.X393McntrlTiming(verbose,args.simulated)
    x393Buffers=x393_mcntrl_buffers.X393McntrlBuffers(verbose,args.simulated)
    x393Tests=  x393_mcntrl_tests.X393McntrlTests(verbose,args.simulated)
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
                func_args=x393_mem.X393Mem.__dict__[name].func_code.co_varnames[1:x393_mem.X393Mem.__dict__[name].func_code.co_argcount]
                print (name+": "+str(func_args))
    extractTasks(x393_mem.X393Mem,x393mem)
    extractTasks(x393_utils.X393Utils,x393utils)
    extractTasks(x393_axi_control_status.X393AxiControlStatus,x393tasks)
    extractTasks(x393_pio_sequences.X393PIOSequences,x393Pio)
    extractTasks(x393_mcntrl_timing.X393McntrlTiming,x393Timing)
    extractTasks(x393_mcntrl_buffers.X393McntrlBuffers,x393Buffers)
    extractTasks(x393_mcntrl_tests.X393McntrlTests,x393Tests)

#
    """
    if verbose > 3:     
        funcName="read_mem"
        funcArgs=[0x377,123]
        print ('==== testing function : '+funcName+str(funcArgs)+' ====')
#        execTask(commandLine) 

        try:
            callableTasks[funcName]['func'](callableTasks[funcName]['inst'],*funcArgs)
        except Exception as e:
            print ('Error while executing %s'%funcName)
            funcFArgs= callableTasks[funcName]['args']
            sFuncArgs=""
            if funcFArgs:
                sFuncArgs+='<'+str(funcFArgs[0])+'>'
                for a in funcFArgs[1:]:
                    sFuncArgs+=' <'+str(a)+'>'
                    print ("Usage:\n%s %s"%(funcName,sFuncArgs))
                    print ("exception message:"+str(e))
    """ 
    for cmdLine in commands:
        print ('Running task: '+str(cmdLine))
        rslt= execTask(cmdLine)
        print ('    Result: '+str(rslt))
    '''       
#TODO: use readline
    '''
    if (args.interactive):
        line =""
        while True:
            line=raw_input('x393%s--> '%('','(simulated)')[args.simulated]).strip()
            if not line:
                print ('Use "quit" to exit, "help" - for help')
            elif (line == 'quit') or (line == 'exit'):
                break
            elif line== 'help' :
                print ("\nAvailable tasks:")
                for name,val in sorted(callableTasks.items()):
                    sFuncArgs=getFuncArgsString(name)
                    print ("Usage: %s %s"%(name,sFuncArgs))
                print ('\n"parameters" and "defines" list known defined parameters and macros')
                print ("args.exception=%d, QUIET=%d"%(args.exceptions,QUIET))
                
            elif (len(line) > len("help")) and (line[:len("help")]=='help'):
                helpFilter=line[len('help'):].strip()
                try:
                    re.match(helpFilter,"")
                except:
                    print("Invalid search expression: %s"%helpFilter)
                    helpFilter=None    
                if helpFilter:
                    print
                    for name,val in sorted(callableTasks.items()):
#                       if re.findall(helpFilter,name):
                        if re.match(helpFilter,name):
                            print('=== %s ==='%name)
                            sFuncArgs=getFuncArgsString(name)
#                           print ("Usage: %s %s"%(name,sFuncArgs))
                            docs=callableTasks[name]['docs']
                            if docs:
                                docsl=docs.split("\n")
                                for l in docsl:
                                    #print ('    %s'%l)
                                    print ('%s'%l)
                                    #print(docs)
                            print ("     Usage: %s %s\n"%(name,sFuncArgs))
            elif line == 'parameters':
                parameters=ivp.getParameters()
                for par,val in sorted(parameters.items()):
                    try:
                        print (par+" = "+hex(val[0])+" (type = "+val[1]+" raw = "+val[2]+")")        
                    except:
                        print (par+" = "+str(val[0])+" (type = "+val[1]+" raw = "+val[2]+")")
                
                '''
                for par in parameters:
                    try:
                        print (par+" = "+hex(parameters[par][0])+" (type = "+parameters[par][1]+" raw = "+parameters[par][2]+")")        
                    except:
                        print (par+" = "+str(parameters[par][0])+" (type = "+parameters[par][1]+" raw = "+parameters[par][2]+")")
                '''        

            elif (line == 'defines') or (line == 'macros'):
                defines= ivp.getDefines()
                for macro,val in sorted(defines.items()):
                    print ("`"+macro+": "+str(val))        

#                for macro in defines:
#                    print ("`"+macro+": "+defines[macro])        
            else:
                cmdLine=line.split()
                rslt= execTask(cmdLine)
                print ('    Result: '+hx(rslt))   
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