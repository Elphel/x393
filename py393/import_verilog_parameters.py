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
import re
import os
import string
from verilog_utils import getParWidth 
class VerilogParameters(object): #this is Borg
    __shared_state = {}
    def __init__(self, parameters=None):
        self.__dict__ = self.__shared_state
        if (parameters):
            adict={}
            for parName in parameters:
                adict[parName]=         parameters[parName][0]
                adict[parName+"__TYPE"]=parameters[parName][1]
                adict[parName+"__RAW"]= parameters[parName][2]
            self.__dict__.update(adict)

class ImportVerilogParameters(object):
    '''
    classdocs
    '''
    defines={}
    parameters={}
    conditions=[True]
    rootPath=None
    verbose=3
    '''
    parameters - dictionalry of already known parameters, defines - defined macros
    '''
    def __init__(self, parameters=None,defines=None,rootPath=None):
        print("parameters=%s"%str(parameters))
        '''
        Constructor
        '''
        if parameters:
            self.parameters=parameters.copy()
            self.parseRawParameters()
        if defines:
            self.defines=defines.copy()
        if rootPath:    
            self.rootPath=rootPath.rstrip(os.sep)
    '''
    http://stackoverflow.com/questions/241327/python-snippet-to-remove-c-and-c-comments
    '''
    def _verilog_comment_remover(self,text):
        def replacer(match):
            s = match.group(0)
            if s.startswith('/'):
                return " " # note: a space and not an empty string
            else:
                return s
        pattern = re.compile(
            r'//.*?$|/\*.*?\*/|"(?:\\.|[^\\"])*"',
#           r'//.*?$|/\*.*?\*/|\'(?:\\.|[^\\\'])*\'|"(?:\\.|[^\\"])*"', # C/CPP remover
            re.DOTALL | re.MULTILINE
        )
        return re.sub(pattern, replacer, text)
    '''
    Parse expression, currently just simple constants
    Returns (value,type,character_pointer) or None
    '''
    def parseExpression(self, line):
        cp=[0]
        def getNextChar():
            try:
                c=line[cp[0]]
                cp[0]+=1
                return c
            except:
                return None
        def skipWS(start=0):
            cp[0]=start
            while (cp[0]<len(line)) and (line[cp[0]] in string.whitespace):
                cp[0]+=1
            return cp[0]    
                    
        def useBest(first, second):
            if first is None:
                return second
            elif second is None:
                return first
            elif first[2]>second[2]:
                return first
            else:
                return second

        def parseString(start=0):
            if line[start]!="\"":
                return None
            endPointer=line[start+1:].find("\"")
            if (endPointer<0):
                endPointer=len(line)
            else:
                endPointer+=2
            return (line[1:endPointer],"STRING",endPointer)

        def parseUnsignedNumber(start=0):
            dChars=string.digits+"_"
            cp[0]=start;
            d=0
            while True:
                c=getNextChar()
                if c is None:
                    break
                if not c in dChars:
                    cp[0]-=1
                    break
                if c != "_":
                    d*=10
                    d+=dChars.index(c)
            if cp[0] <= start:
                return None
            return (d,"INTEGER",cp[0])
        
        def parseUnsignedFraction(start=0):
            dChars=string.digits+"_"
            cp[0]=start;
            c=getNextChar()
            if c != ".":
                cp[0]-=1
                return None
            d=0
            k=1.0
            while True:
                c=getNextChar()
                if c is None:
                    break
                if not c in dChars:
                    cp[0]-=1
                    break
                if c != "_":
                    k*10
                    d*=10
                    d+=dChars.index(c)
            if cp[0] <= start+1:
                return None
            return (d/k,"REAL",cp[0])
        
        def parseSign(start=0):
            sign=1
            cp[0]=start;
            c=getNextChar()
            if c is None:
                return None
            if c == "+":
                sign = 1
            elif c == "-":
                sign =-1
            else: 
                cp[0]-=1
            return sign
        
        def parseBase(start=0):
            cp[0]=start
            c=getNextChar()
            if c != "'":
                return None
            c=getNextChar()
            if c is None:
                return None
            c=string.lower(c)
            if not (c in "bodh"):
                return None
            if c=="b":
                return 2
            elif c == "o":
                return 8
            elif c == "d":
                return 10
            elif c == "h":
                return 16
            return None
             
        def parseDecimalNumber(start=0):
            sign=parseSign(start)
            un= parseUnsignedNumber(cp[0])
            if un is None:
                return None
            return (un[0]*sign,un[1],un[2])

        def parseRealNumber(start=0):
            sign=parseSign(start)
            un= parseUnsignedNumber(cp[0])
            if un is None:
                return None
            fp=parseUnsignedFraction(un[2])
            if fp is None:
                return (un[0]*sign,un[1],un[2])
            else:
                return ((un[0]+fp[0])*sign,fp[1],fp[2])
        
        def parseNumber(start=0):
            #try number of bits prefix
            sign=1
#            baseStart=start
            width=0 # undefined
            sdn=parseDecimalNumber(start)
            if sdn is None:
                sign=parseSign(start)
            else:
                width=sdn[0]
                if sdn[0]<0:
                    sign=-1
                    width=-width
            baseStart=cp[0]
            b= parseBase(baseStart)
            if b is None:
                if sdn is None:
                    return None
                else:
                    return sdn
            else: # parse actual number
                if b == 2:
                    nChars="01_"
                elif b == 8:
                    nChars="01234567_"
                elif b == 10:
                    nChars="0123456789_"
                elif b == 16:
                    nChars="0123456789abcdef_"
                else:
                    return None
                d=0
                while True:
                    c=getNextChar()
                    if c is None:
                        break
                    c=string.lower(c)
                    if not c in nChars:
                        cp[0]-=1
                        break
                    if c != "_":
                        d*=b
                        d+=nChars.index(c)
                if cp[0] <= start+1:
                    return None
                et="INTEGER"
                if width > 0:
                    et="[%d:0]"%(width-1)
                return (sign*d,et,cp[0])


        def parseParameter(start=0):
            l=0
            par=None
            if (self.verbose>2) and(start !=0):
                print ("parseParameter(start=%d)"%(start))

            for parName in self.parameters:
                if (line[start:start+len(parName)] == parName) and (len(parName)>l) :
                    par=parName
                    l=len(parName)
                    
            if l==0:
                return None
            end=start+l
            try:
                pass
                if (line[end] in string.ascii_letters) or (line[end] in string.digits) or (line[end] == '_'):
                    return None # Real parameter name is longer
            except:
                pass #Ok if it is the end of line
            if (self.verbose>2) and (start !=0):
                print ("parseParameter(start=%d), end=%d, line=%s, parName=%s, par=%s"%(start,end,line,parName,str(self.parameters[par])))

            return (self.parameters[par][0],self.parameters[par][1],end)
        def binop_add(exp1,exp2):
            return (exp1[0] + exp2[0],max(exp1[1],exp2[1]))
        def binop_sub(exp1,exp2):
            return (exp1[0] - exp2[0],max(exp1[1],exp2[1]))
        def binop_bitor(exp1,exp2):
            return (exp1[0] | exp2[0],max(exp1[1],exp2[1]))
        def binop_bitand(exp1,exp2):
            return (exp1[0] & exp2[0],max(exp1[1],exp2[1]))
        def binop_bitxor(exp1,exp2):
            return (exp1[0] ^ exp2[0],max(exp1[1],exp2[1]))
        def binop_mult(exp1,exp2):
            return (exp1[0] * exp2[0],exp1[1]+exp2[1])
        def binop_div(exp1,exp2):
            return (exp1[0] / exp2[0],exp1[1])
        def binop_mod(exp1,exp2):
            return (exp1[0] % exp2[0],exp2[1])
        def binop_lshift(exp1,exp2):
            return (exp1[0] << exp2[0],exp1[1]+exp2[0])
        def binop_rshift(exp1,exp2):
            return (exp1[0] >> exp2[0],exp1[1])
        
        binops=(
                ('+',binop_add),
                ('-',binop_sub),
                ('|',binop_bitor),
                ('&',binop_bitand),
                ('^',binop_bitxor),
                ('*',binop_mult),
                ('/',binop_div),
                ('%',binop_mod),
                ('<<',binop_lshift),
                ('>>',binop_rshift)
                )
        def getBinOp(start):
            l=0
            op=None
            for opTuple in binops:
                opName=opTuple[0]
                if (line[start:start+len(opName)] == opName) and (len(opName)>l) :
                    op=opTuple
                    l=len(opName)
            return op
            
            pass
        def parsePrimary(start=0):
            return useBest(useBest(useBest(parseString(start),parseNumber(start)),parseRealNumber(start)),parseParameter(start))
        def parsePrimaryOrBinary(start=0):
            operand1=parsePrimary(start)
            if (self.verbose>2) and (start !=0):
                print ("parsePrimaryOrBinary(start=%d), line=%s, result=%s"%(start,line,str(operand1)))
            if not operand1: print (line)    
            opStart=skipWS(operand1[2])
            if opStart == len(line): # just primary
                return operand1
        # Try binary operation    
            op=getBinOp(opStart)
            if not op:
                print("ERROR: Next token in '%s' (starting from %s) is not a binary operation"%(line,line[opStart:]))
                return None
            start2=skipWS(opStart+len(op[0]))
            if (self.verbose>2):
                print ("line=%s"%line)
                print ("start=%d, opStart=%d, start2=%d"%(start,opStart, start2))
            operand2=parseExp(start2)
            if not operand2:
                print("ERROR: Could not get the second operand for '%s' in '%s'"%(op[0],line))
                return None
            width1=getParWidth(operand1[1])  
            width2=getParWidth(operand2[1])
            if (self.verbose>2):
                print("operand1=%s"%str(operand1))
                print("operand2=%s"%str(operand2))
            exp=op[1]((operand1[0],width1),(operand2[0],width2))
            if (self.verbose>2):
                print("exp=%s"%str(exp))
            if not exp:
                print("ERROR: Failed '%s' in '%s'"%(op[0],line))
                return None
            #Try limiting to 32 bits
            width=exp[1]
            if (width1==32) and (exp[1]>32) and ((width >> 32) == 0):
                width=32
            return (exp[0],"[%d:0]"%(width-1),operand2[2])

        def parseExp(start=0):
            start=skipWS(start)
            if start>=len(line):
                print ("ERROR: EOL reached when expression was expected in '%s'"%line)
                return None
            if line[start]=='(':
                exp=parseExp(start+1)
                if not exp:
                    print ("ERROR: failed to evaluate expression in '%s' (starting from '%s'"%(line,line[start:]))
                    return None
                endPos=skipWS(exp[2])
                if endPos >= len(line):
                    print ("ERROR: EOL reached when closing ')' was expected in '%s'"%line)
                    return None
                if line[endPos] != ")":
                    print ("ERROR: Found '%s'when closing ')' was expected in '%s'"%(line[endPos],line))
                    return None
                endPos=skipWS(endPos+1)
                return (exp[0],"[%d:0]"%(exp[1]-1),endPos)
            return parsePrimaryOrBinary(start)
        '''
        parseExpression top level code
        no support for bit select, &&, ||, ~ ! ? and more... 
        '''
        return parseExp(0)

    '''
    Read parameters defined in parameter port list (inside #(,,,), comma separated (last may have no comma)
    Adds parsed parameters to the dictionary
    '''
    def readParameterPortList(self,path,portMode=True):
        if (self.verbose>2):
            print ("readParameterPortList:Processing %s"%(path))
        with open (path, "r") as myfile: #with will close file when done
            text=myfile.read()
# remove /* */ comments            
        text=self._verilog_comment_remover(text)
#        text="".join([s for s in text.strip().splitlines(True) if s.strip()])
        text=os.linesep.join([s.strip() for s in text.strip().splitlines(True) if s.strip()])
#        print (text)
# Split into lines
        lines=text.splitlines()
        preprocessedLines=[]
# process ` directives
        for line in lines:
            enabled=not False in self.conditions
# Macro substitution excluding the very first character
            if "`" in line [1:]:
                for define in self.defines:
                    line.replace("`"+define,self.defines[define])
            if line[0]== "`":
                tokens=line[1:].replace("\t"," ").split(" ",1) #second tokens
                for i in (1,2): 
                    if len(tokens)>i:
                        tokens = tokens+tokens.pop().strip().split(" ",1)
#                        ll=tokens.pop().strip().split(" ",1)
#                        tokens = tokens+ll
                    
                if not enabled: # only process ifdef, ifndef, endif, else and elsif (if previous level was enabled 
                    if  (tokens[0] == "ifdef") or (tokens[0] == "ifndef"):
                        self.conditions.append(False)
                        continue
                    elif tokens[0] == "endif":
                        self.conditions.pop()
                        continue
                    elif tokens[0] == "else":
                        self.conditions.append(not self.conditions.pop())
                        continue
                    elif tokens[0] == "elsif":
                        self.conditions.pop
                        self.conditions.append((tokens[1] in self.defines) and ( not False in self.conditions))
                        continue
                else: # enabled, process all directives
                    if   tokens[0] == "ifdef":
                        self.conditions.append(tokens[1] in self.defines)
                        continue
                    elif tokens[0] == "ifndef":
                        self.conditions.append(not (tokens[1] in self.defines))
                        continue
                    elif tokens[0] == "elsif":
                        self.conditions.pop
                        self.conditions.append(tokens[1] in self.defines)
                        continue
                    elif tokens[0] == "else":
                        self.conditions.append(not self.conditions.pop()) #s == elf.conditions.append(False) 
                    elif tokens[0] == "define":
                        subst=""
                        if len(tokens) > 2:
                            subst= tokens[2]
                        self.defines[tokens[1]]=subst
                        continue
                    elif tokens[0] == "undef":
                        try:
                            self.defines.pop(tokens[1])
                        except:
                            pass
                        continue   
                    elif tokens[0] == "include":
                        rpath=tokens[1].strip("\"")
                        curDir=os.path.dirname(path)
                        incPath=None
                        if self.rootPath and os.path.exists(os.path.join(self.rootPath,rpath)):
                            incPath=os.path.join(self.rootPath,rpath)
                        elif   os.path.exists(os.path.join(curDir,rpath)):  
                            incPath=os.path.join(curDir,rpath)
                        if incPath:
                            self.readParameterPortList(incPath)   
                        continue
            elif enabled: # processing non-directive statement
                preprocessedLines.append(line)
#        print ("======= Extracted defines =======")
#        for macro in self.defines:
#            print ("`"+macro+": "+self.defines[macro])        
#        print ("======= Preprocessed lines =======")
#        for line in preprocessedLines:
#            print (line)
# Second pass - process parameter and localparam
# in portMode skip starting "," if any
        portMode=True;
        for line in preprocessedLines:
            if line[-1] == ";":
                portMode=False
        if (self.verbose>2):
            print ("portMode is "+str(portMode))
        try:
            if portMode and (preprocessedLines[0][0]==","):
                preprocessedLines.insert(0,preprocessedLines.pop(0)[1:])
        except:
            if (self.verbose>2):
                print("No preprocessed lines left")
        while preprocessedLines:
#            print("A: len(preprocessedLines)=%d, first is %s"%(len(preprocessedLines),preprocessedLines[0]))
            line= preprocessedLines.pop(0)
            tokens=line.replace("\t"," ").split(" ",1)
            if (tokens[0]=="parameter") or (tokens[0]=="localparam"):
                parType=""
                if len(tokens)>1:
                    line=tokens[1].strip()
                else:
                    try:
                        line= preprocessedLines.pop(0)
                    except:
                        break
                # common for comma-separated parameters - real/integer or bit range
                if line[0]=="[": # skip bit range
                    while ((line.find("]")<0) or (line.find("]")==(len(line-1)))) and preprocessedLines: # not found at all or last element in the stting - add next line
                        line+=preprocessedLines.pop(0)
                    parType=line[:line.find("]")+1:]
                    line=line[line.find("]")+1:]
                else:    
                    # skip "integert", "real" or bit range
                    tokens=line.split(" ",1)
                    if (tokens[0]=="integer") or (tokens[0]=="real"):
                        if tokens[0]=="real":
                            parType="real"
                        else:
                            parType="integer"
                        if len(tokens)>1:
                            line=tokens[1].strip()
                        else:
                            try:
                                line= preprocessedLines.pop(0)
                            except:
                                break
                preprocessedLines.insert(0,line)    
                #Read read parameter(s), possibly multi-line until EOF, ";" or comma in portMode
                while True: #more: # processing multiple comma-separated parameters in a single statement (in portMode - only 1)
                    #get parameter name as next token
                    line=""
                    while (not "=" in line) and preprocessedLines: # not found at all or last element in the string - add next line
                        line +=" "+preprocessedLines.pop(0)
                    tokens=line.split("=",1)
                    tokens[0]=tokens[0].strip()
                    parName=tokens[0]
                    if len(tokens)> 1:
                        preprocessedLines.insert(0,tokens[1].strip()) # insert start of expression back to the list
#                    print ("+++++++++++++++++")
#                    if preprocessedLines: print ("preprocessedLines[0]="+preprocessedLines[0])
                    #now preprocessed lines start with expression for parName
                    #extract expression, as a line, considering ",(,),[,],{,} up to outer ",", ";" or EOF
                    mode=[] # will be stack of "(","[","\""
                    textPointer={"char":0,"line":0}
                    termChar=None
                    termPos =None
                    def genNextChar():
#                        print ("++++ textPointer[char]=%d, textPointer[line]=%d"%(textPointer["char"],textPointer["line"]))
                        try:
                            ch=preprocessedLines[textPointer["line"]][textPointer["char"]]
                        except:
#                            print ("*** textPointer[char]=%d, textPointer[line]=%d"%(textPointer["char"],textPointer["line"]))
                            return None
                        textPointer["char"]+=1
                        if textPointer["char"] >= len(preprocessedLines[textPointer["line"]]):
                            textPointer["line"]+=1
                            textPointer["char"]=0
                        return ch

                    def skipToWS(): # all tabs are already replaced with spaces
                        try:
                            indx=preprocessedLines[textPointer["line"]].find(" ",[textPointer["char"]])
                        except:
                            return
                        if (indx<0):
                            textPointer["line"]+=1
                            textPointer["char"]=0
                        else:
                            textPointer["char"]=indx
#                    print ("---- textPointer[char]=%d, textPointer[line]=%d"%(textPointer["char"],textPointer["line"]))
                    if textPointer["line"] >= len(preprocessedLines):
                        break
                    while textPointer["line"] < len(preprocessedLines):
                        termPos=(textPointer["char"],textPointer["line"])
                        c=genNextChar()
                        if c is None:
                            break
                        if c=="\\":
                            skipToWS()
                        elif (c=='(') or (c=='[') or (c=='{'):
                            mode.append(c)
                        elif (c==')') or (c==']') or (c=='}'):
                            try:
                                c1=mode.pop();
                                if ((c == "]") and (c1 != "[")) or ((c == ")") and (c1 != "(")) or ((c == "}") and (c1 != "{")):
                                    print ("ERROR: closing %s does not match opening %s"%(c,c1))
                            except:
                                print ("ERROR: found closing %s , none opening"%(c))    
                        elif c == "\"":
                            if (len(mode) > 0) and (mode[-1] == "\""):
                                mode.pop();
                            else:
                                mode.append(c)
                        elif (len(mode) == 0) and ((c == ",") or (c == ";")):
                            termChar=c
                            break
#                    print ("textPointer[char]=%d, textPointer[line]=%d"%(textPointer["char"],textPointer["line"]))
#                    print ("termPos=(%d,%d)"%termPos)
#                    print ("termChar=%s"%termChar)
                    # combine expression into a single line, update remaining lines
                    # pointer is at the end (after "," or ";" (or at the EOF), termPos - points to termination character
                    expLines=[]
                    for i in range(0,termPos[1]):
                        expLines.append(preprocessedLines[i])
                    expLines.append(preprocessedLines[termPos[1]][0:termPos[0]])
                    expLine=" ".join(expLines).strip()
#                    print(parName+": "+expLine)
#                    print("len(preprocessedLines)=%d"%len(preprocessedLines))
                    #remove processed part
                    if termChar is None:
                        preprocessedLines=[]
                    else:         
#                        print("0: len(preprocessedLines)=%d, first is %s"%(len(preprocessedLines),preprocessedLines[0]))
                        for i in range(textPointer["line"]): # here - including terminating",", ";"
                            preprocessedLines.pop(0) # remove full lines
                        try:    
                            lastLine=preprocessedLines.pop(0)[textPointer["char"]:].strip()
#                            print("1: len(preprocessedLines)=%d"%len(preprocessedLines))
#                            print("lastLine=%s"%lastLine)
                            if lastLine:
                                preprocessedLines.insert(0,lastLine)
                        except:
                            preprocessedLines=[] # Nothing left
                    # process expression here, for now - just use expression string
                    ev= self.parseExpression(expLine)
                    if (self.verbose>2):
                        print (parName+": -> "+expLine)
                        print (ev)
                    if ev is None:
                        self.parameters[parName]= (expLine,parType,expLine)
                    else:
                        if not parType:
                            parType=ev[1]
#                        self.parameters[parName]= (ev[0],parType)
                        self.parameters[parName]= (ev[0],parType,expLine)
#                    if portMode: # while True:
                    if (self.verbose>2):
                        print (parName+": "+str(self.parameters[parName]))
                    if portMode or (termChar == ";"): # while True:
                        break;
#        print ("======= Parameters =======")
#        for par in self.parameters:
#            print (par+": "+self.parameters[par])  
    def parseRawParameters(self):
        for parName in self.parameters:
            valTyp= self.parameters[parName]
            if (not valTyp[1]) or (valTyp[1]=="RAW"):
                ev= self.parseExpression(valTyp[0])
#               print ("valTyp="+str(valTyp))
#               print ("ev="+str(ev))
                if ev:
                    self.parameters[parName]= (ev[0],ev[1],valTyp[0])
                    if parName == "VERBOSE":
                        self.verbose=ev[0]
                         
    '''
    get parameter dictionary
    '''
    def getParameters(self):
        return self.parameters
    def getDefines(self):
        return self.defines
    