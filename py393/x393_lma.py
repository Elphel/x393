from __future__ import print_function
'''
# Copyright (C) 2015, Elphel.inc.
# Fit DQ/DQS timing parameters using Levenberg-Marquardt algorithm 
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
import math
import numpy as np
"""
For each byte lane:
tSDQS delay ps/step (~1/5 of datasheet value) - 1
tSDQi  delay ps/step (~1/5 of datasheet value) - 8
tDQSHL=tDQSH-tDQSL (ps) - 1
tDQiHL=tDQiH-tDQiL (ps) - 8
tDQS=0 (not adjusted here) - 0
tDQi - DQi routing delay with respect to DQS - 8
tFDQS - array of 5 fine delay steps (here in ps) - 5
tFDQi - array of 5 fine delay steps (here in ps)  for each bit - 5*8=40

error**2 here  (y-tFDQi-fXi)**2
"""

            
PARAMETER_TYPES=(
                     {"name":"tSDQS",   "size":1,            "units":"ps","description":"DQS input delay per step (1/5 of the datasheet value)","en":1},
                     {"name":"tSDQ",    "size":8,            "units":"ps","description":"DQ input delay per step (1/5 of the datasheet value)","en":1},
                     {"name":"tDQSHL",  "size":1,            "units":"ps","description":"DQS HIGH minus LOW difference","en":1},
                     {"name":"tDQHL",   "size":8,            "units":"ps","description":"DQi HIGH minus LOW difference","en":1},
                     {"name":"tDQS",    "size":1,            "units":"ps","description":"DQS delay (not adjusted)","en":0},
                     {"name":"tDQ",     "size":8,            "units":"ps","description":"DQi delay","en":1},
                     {"name":"tFDQS",   "size":4,            "units":"ps","description":"DQS fine delays (mod 5)","en":1}, #only 4 are independent, 5-th is -sum of 4 
                     {"name":"tFDQ",    "size":32,           "units":"ps","description":"DQ  fine delays (mod 5)","en":1},
                     {"name":"anaScale","size":1, "dflt":20, "units":"ps","description":"Scale for non-binary measured results","en":1}, #should not be 0 - singular matrix
                     {"name":"tCDQS",   "size":30,           "units":"ps","description":"DQS primary delays (all but 8 and 24","en":1}, #only 4 are independent, 5-th is -sum of 4 
                     )
FINE_STEPS=5
DLY_STEPS =FINE_STEPS * 32 # =160 
def test_data(meas_delays,
              compare_prim_steps,
              quiet=1):
    halfStep=0.5
    if compare_prim_steps:
        halfStep*=FINE_STEPS
        
    if quiet < 2:
        print ("DQS",end=" ")
        for f in ('ir','if','or','of'):
            for b in range (16):
                print ("%s_%d"%(f,b),end=" ")
        print() 
               
        for ldly, data in enumerate(meas_delays):
            print("%d"%ldly,end=" ")
            if data:
                """
                for typ in ((0,0),(0,1),(1,0),(1,1)):
                    for pData in data: # 16 DQs, each None nor a pair of lists for inPhase in (0,1), each a pair of edges, each a pair of (dly,diff)
                        if pData and (not pData[typ[0]][typ[1]] is None):
                            print ("%d"%pData[typ[0]][typ[1]],end=" ")
                        else:
                            print ("x",end=" ")
                """            
                for typ in range(4):
                    for pData in data: # 16 DQs, each None nor a pair of lists for inPhase in (0,1), each a pair of edges, each a pair of (dly,diff)
                        if pData and (not pData[typ] is None):
                            if pData[typ][1] is None:
                                print ("%d"%(pData[typ][0]+halfStep),end=" ")
                            else:
                                print ("%d"%(pData[typ][0]),end=" ")
                        else:
                            print ("x",end=" ")
            print()

def make_repeat(value,nRep):
    if isinstance(value,(list,tuple)):
        return value
    else:
        return (value,)*nRep
           
class X393LMA(object):
    lambdas={"initial":0.1,"current":0.1,"max":100.0}
    maxNumSteps=25
    finalDiffRMS=0.001
    parameters=None
#    parameterMask={}
    parameterMask={'tSDQS':    True,
                   'tSDQ':     [True, True, True, True, True, True, True, True],
                   'tDQSHL':   True,
                   'tDQHL':    [True, True, True, True, True, True, True, True],# 23.523465ps -> 23.315524 - too little difference?
                   'tDQS':     False,
                   'tDQ':      [True, True, True, True, True, True, True, True],
                   'tFDQS':    [True, True, True, True],
                   'tFDQ':     [True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True],
                   'anaScale': True, # False,# True, # False # Broke?
#                   'tCDQS':    False # True #False #True # list of 30
                   'tCDQS':    [True,  True,  True,  True,  True,  True,  True,  True, # 8
                               True,  True,  True,  True,  True,  True,  True,  True,  True,  True,  True,  True,  True,  True,  True,
#                                False, False, False, False, False, False, False, False, False, False, False, False, False, False, False, #15
                                True,  True,  True,  True,  True,  True,  True]
#                                False, False, False, False, False, False, False] #7
                   }
    """
    parameterMask={'tSDQS':    True,
                   'tSDQ':     [True, True, True, True, True, True, True, True],
                   'tDQSHL':   True, # False, # True,
                   'tDQHL':    [True, True, True, True, True, True, True, True], # False, # [True, True, True, True, True, True, True, True], #OK
                   'tDQS':     False,
                   'tDQ':      [True, True, True, True, True, True, True, True], #BAD - without it 0 in JTbyJ for tFDQ
                   'tFDQS':    [True, True, True, True], # False, # [True, True, True, True], # OK
                   'tFDQ':     True, # False, # [True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True],
                   'anaScale': False
                   }
    """
    parameterVector=None
    clk_period=None
    analog_scale=20 # ps when there is analog result -0.5...+0.5, multiply it by analog_scale and add to result
#    hist_estimated=None # DQ/DQS delay period,
#                        # DQ-DQS shift (and number of periods later) for averaged and individual bits,
#                        # for each of 4 edge types
    def __init__(self):
        pass
    
    def createYandWvectors(self,
                           lane,
                           data_set,
                           compare_prim_steps,
                           scale_w=0.2, # multiply weight by this if fractions are undefined
                           periods=None,
                           quiet=1):
        
        if quiet < 3:
            print ("createYandWvectors(): scale_w=%f"%(scale_w))
        def pythIsNone(obj):
            return obj is None
        isNone=pythIsNone
        if isinstance(data_set,np.ndarray):
            isNone=np.isnan
        
        n=len(data_set)*32
#        fx=np.zeros((DLY_STEPS*32,))
        """
        use np.nan instead of the None data
        np.isnan() test
        , dtype=np.float
        @param compare_prim_steps while scanning, compare this delay with 1 less by primary(not fine) step,
                            save None for fraction in unknown (previous -0.5, next +0.5)
        """
        halfStep=0.5
        if compare_prim_steps:
            halfStep*=FINE_STEPS
#        extra_Y=(0.0,halfStep)    

        y=np.zeros((n,), dtype=np.int) #[0]*n
        
        w=np.zeros((n,)) #[0]*n
#        f=np.full((n,),np.nan) # fractions
        f=np.empty((n,)) # fractions
        f[:]=np.nan
        yf=np.zeros((n,)) # y with added fractions
        if not periods is None:
            p=np.zeros((n), dtype=np.int)#[0]*n 
        for dly,data in enumerate(data_set):
            if data:
                data_lane=data[lane*8:(lane+1)*8]
                pm=[None]*8
                for b,bData in enumerate(data_lane): # bdata for each bit is either None or has 4 (maybe None) DQ integer delay values
                    if bData:
                        pm[b]=[None]*4
                        for t,tData in enumerate(bData):
                            if not tData is None: #[dly],[b],[t] tData - int value
                                i=32*dly+8*t+b
                                y[i]=tData[0]
                                if not isNone(tData[1]):
                                    f[i] = tData[1]
                                    yf[i]=tData[0]
                                    w[i]=1
                                else:
                                    w[i]=scale_w
                                    yf[i]=tData[0]+halfStep
                                if not periods is None:
                                    p[i]=periods[dly][b][t]
        #Normalize weights
        S0=np.sum(w)
        w*=1.0/S0                            
        vectors={'y':y,'yf':yf,'w':w,'f':f} # yf - use for actual float value, y - integer
        if not periods is None:
            vectors['p']=p                        
        return vectors 

    def showYOrVector(self,
                      ywp,
                      filtered=False,
                      vector=None,
                      showMode="IA"):
        def pythIsNone(obj):
            return obj is None
        isNone=pythIsNone
        # If vector is None - print y vector (skipping zero mask),
        # otherwise print vector (should be the same length, using the same 'w' weight mask
        v=vector
        if v is None:
            v= ywp['yf']
        w=ywp['w']
        try:
            f=ywp['f']
            noF=False
        except:
            f=None
            noF=True
        if not noF:
            if isinstance(f,np.ndarray):
                isNone=np.isnan
#                print ("using np.isnan")
#        print("filtered=",filtered)
        n=len(v)/32
        if 'A' in showMode.upper():
            av=[]
            for dly in range(n):
                avd=[]
                SAX=0.0
                SA0=0.0
                for t in range(4):
                    SX=0.0
                    S0=0.0
                    for b in range(8):
                        i=32*dly+8*t+b
                        if w[i] and ((not filtered) or noF or (not isNone(f[i]))):
                            SX+=w[i]*v[i]
                            S0+=w[i]
                    SAX+=SX
                    SA0+=S0        
                    if S0>0:
                        SX/=S0
                    else:
                        SX=None
                    avd.append(SX)
                if SA0>0:
                    SAX/=SA0
                else:
                    SAX=None
                avd.append(SAX)
                av.append(avd)
              
        print("DQS_dly", end= " ")
        if "I" in  showMode.upper():
            for ft in ('ir','if','or','of'):
                for b in range (8):
                    print ("%s_%d"%(ft,b),end=" ")
        if "A" in  showMode.upper():
            for ft in ('ir','if','or','of','all'):
                    print ("%s"%(ft),end=" ")
        print()
        
        for dly in range(n):
            print("%d"%dly,end=" ")
            if "I" in  showMode.upper():
                for t in range(4):
                    for b in range(8):
                        i=32*dly+8*t+b
                        if w[i] and ((not filtered) or noF or (not isNone(f[i]))):
                            print("%s"%(str(v[i])),end=" ")
                        else:
                            print("?",end=" ")
            if "A" in  showMode.upper():
                for a in av[dly]:
                    if not a is None:
                        print("%f"%(a),end=" ")
                    else:
                        print("?",end=" ")
                                  
            print()
    def showENLresults(self,
                       DQvDQS):
        rslt_names=("early","nominal","late")
        err_name='maxErrDqs'
        numBits=0
        for n in DQvDQS:
            try:
                for d in DQvDQS[n]:
                    try:
                        numBits=len(d)
#                        print ("d=",d)
                        break
                    except:
                        pass
                break        
            except:
                pass
        if not numBits:
#            print("showENLresults(): No no-None data provided")
#            print("DQvDQS=",DQvDQS)
#            return
            raise Exception("showENLresults(): No no-None data provided")
        numLanes=numBits//8
#        print ("****numBits=%d"%(numBits))            
        enl_list=[]
        for k in rslt_names:
            if DQvDQS[k]:
                enl_list.append(k)
                
        print("DQS", end=" ")
        for enl in enl_list:
            for b in range(numBits):
                print("%s%d"%(enl[0].upper(),b),end=" ")
        for enl in enl_list:
            for lane in range(numLanes):
                    if numLanes > 1:
                        print("%s%d_err"%(enl[0].upper(),lane),end=" ")
                    else:    
                        print("%s_err"%(enl[0].upper()),end=" ")
        print()
        for dly in range(len(DQvDQS[enl_list[0]])):
            print ("%d"%(dly),end=" ")
            for enl in enl_list:
                if DQvDQS[enl][dly] is None:
                    print ("? "*numBits,end="")
                else:
                    for b in range(numBits):
                        if DQvDQS[enl][dly][b] is None:
                            print("?",end=" ")
                        else:
                            print("%d"%(DQvDQS[enl][dly][b]),end=" ")
            for enl in enl_list:
#                if numLanes>1:
#                    print ("DQvDQS[err_name]=",DQvDQS[err_name])
#                    print ("DQvDQS[err_name][enl]=",DQvDQS[err_name][enl])
#                    print ("DQvDQS[err_name][enl][dly]=",DQvDQS[err_name][enl][dly])
                if DQvDQS[err_name][enl][dly] is None:
                    print ("? "*numLanes,end="")
                else:
                    for lane in range(numLanes):
                        if DQvDQS[err_name][enl][dly] is None:
                            print("?",end=" ")
                        else:
                            if numLanes > 1:
                                if DQvDQS[err_name][enl][dly][lane] is None:
                                    print("?",end=" ")
                                else:
                                    print("%.1f"%(DQvDQS[err_name][enl][dly][lane]),end=" ")
                            else:
                                print("%.1f"%(DQvDQS[err_name][enl][dly]),end=" ")
            print()
        
    
    def normalizeParameters(self,
                            parameters,
                            isMask=False):
        """
        Convert single/lists as needed
        """
        if parameters is None:
            parameters = self.parameters
        for par in PARAMETER_TYPES:
            name=par['name']
            size=par["size"]
            try:
                v=parameters[name]
            except:
                if isMask:
                    v=par['en']
                else:
                    try:
                        v=par['dflt']
                    except:
                        raise Exception("parameter['%s'] is not defined and PARAMETER_TYPES['%s'] does not provide default value"%(name,name))
            if size == 1:
                if isinstance(v,(list,tuple)):
                    v=v[0]
                if isMask:
                    if v:
                        v=True
                    else:
                        v=False
            else:
                if isinstance(v,tuple):
                    v=list(v)
                elif not isinstance(v,list):
                    v=[v]*size
                if isMask:
                    for i in range(size):
                        if v[i]:
                            v[i]=True
                        else:
                            v[i]=False
                
            parameters[name]=v 
        return parameters        
    def copyParameters(self,
                       parameters):
        newPars={}
        for k,v in parameters.items():
            if isinstance(v,(list,tuple)):
                newPars[k]=list(v)
            else:
                newPars[k]=v
        return newPars
            

    def createParameterVector(self,
                              parameters=None,
                              parameterMask=None):
#        global PARAMETER_TYPES
        if parameters is None:
            parameters = self.parameters
        if parameterMask is None:
            parameterMask = self.parameterMask
        vector=[]
        for par in PARAMETER_TYPES:
            name=par['name']
            size=par["size"]
            if par['en']:
                try:
                    mask=parameterMask[name]
                except:
                    mask=True
                try:
                    parVal=parameters[name]
                except:
                    parVal=None
                    # mask=False
                if mask:
                    mask=  make_repeat(mask,size)
                    parVal=make_repeat(parVal,size)
                    for m,p in zip(mask, parVal):
                        if m:
                            vector.append(p)
        return np.array(vector)

    def createParameterIndex(self,
                             parameters=None,
                             parameterMask=None):
        """
        create dict as parameters, but instead of values - index in the parameter vector, or -1
        """
        if parameters is None:
            parameters = self.parameters
        if parameterMask is None:
            parameterMask = self.parameterMask
        indices={}
        parIndex=0
        for par in PARAMETER_TYPES:
            name=par['name']
            size=par["size"]
            if par['en']:
                try:
                    mask=parameterMask[name]
                except:
                    mask=True
                if mask:
                    if size==1:
                        indices[name]=parIndex
                        parIndex += 1
                    else:
                        if not isinstance(mask,(list,tuple)):
                            mask=[mask]*size
                        indices[name]=[]
                        for m in mask:
                            if m:
                                indices[name].append(parIndex)
                                parIndex += 1
                            else:
                                indices[name].append(-1)
            if not name in indices:    
                if size==1:
                    indices[name]=-1
                else:
                    indices[name]=[-1]*size
        indices['numPars']=parIndex # extra key with total number of parameters            
        return indices
        
    def getParametersFromVector(self,
                                vector=None,
                                parameterMask=None,
                                parameters=None):# if not None, will be updated 
#        global PARAMETER_TYPES
        if vector is None:
            vector=self.parameterVector
        if parameterMask is None:
            parameterMask=self.parameterMask
        if parameters is None:
            parameters={}
        index=0
        for par in PARAMETER_TYPES:
            name=par['name']
            size=par["size"]
            if par['en']:
                try:
                    mask=parameterMask[name]
                except:
                    mask=True
                if mask:
                    mask=  make_repeat(mask,size)
                    if size==1:
                        if mask[0]:
                            parameters[name]=vector[index]
                            index += 1
                    else:
                        if not name in parameters:
                            parameters[name]=[None]*size
                        for i,m in enumerate(mask):
                            if m:
                                parameters[name][i]=vector[index]
                                index += 1
        return parameters
     
    def dqi_dqsi_estimate_from_histograms(self,
                                 lane, # byte lane
                                 bin_size,
                                 clk_period,
                                 dly_step_ds,
                                 primary_set,
                                 data_set,
                                 compare_prim_steps, 
                                 quiet=1):        
        """
        Prepare data by building and processing histograms to find
        DQ/DQS period (in fine delay steps),
        and for each data bit (and averaged) DQ-DQS shift (in fine steps) and
        full periods - for primary set (and same phase) - starting from
        closest to 0 (both signs) at DQS==0, for non-primary -\
        from DQ 180 degrees later tha primary
        
        using datasheet delay/step (without fine step delay)
        and the data set (for each DQS delay - list of 16 bits,
        each of 2x2 elements (DQ delay values) or null
        Create data set template - for each DQS delay and inPhase
         - branch - number of full periods to add
        @param lane          byte lane to process 
        @param bin_size     bin size for the histograms (should be 5/10/20/40)
        @param clk_period   SDCLK period in ps
        @param dly_step_ds  IDELAY step (from the datasheet)
        @param primary_set  which of the data edge series to use as leading (other will be trailing by 180) 
        @param data_set     measured data set
        @param compare_prim_steps while scanning, compare this delay with 1 less by primary(not fine) step,
                            save None for fraction in unknown (previous -0.5, next +0.5)
        @param quiet        reduce output   
        """
        num_hist_steps=2*((DLY_STEPS+bin_size-1)//bin_size)
        
        est_step_period=(clk_period/dly_step_ds)*FINE_STEPS
        est_bin_period=est_step_period/bin_size
        halfStep=0.5
        if compare_prim_steps:
            halfStep*=FINE_STEPS
        extra_Y=(0.0,halfStep)    
        hist=[0.0]* num_hist_steps
        hist4=[]
        for _ in range(4):
            hist4.append(list(hist))
        hist8x4=[] # [8][4][num_hist_steps]
        for _i in range(8):
            l=[]
            for _j in range(4):
                l.append(list(hist))
            hist8x4.append(l)
        for dly,data in enumerate(data_set):
            if data:
                data_lane=data[lane*8:(lane+1)*8]
                for b,bData in enumerate(data_lane):
                    if bData:
                        for t,tData in enumerate(bData):
                            if not tData is None:
                                binNum=int((tData[0]+extra_Y[tData[1] is None]-dly+DLY_STEPS+1) / bin_size)
                                hist8x4[b][t][binNum] += 1 # lowest bin will be 1 count shy
                                if binNum == 0:
                                    hist8x4[b][t][binNum] += 1.0/(bin_size-1.0)
                                    
        for t in range(4):
            for i in range(num_hist_steps):
                for b in range(8):
                    hist4[t][i]+=hist8x4[b][t][i]
                hist4[t][i] /= 8.0
        if quiet <1:
            for i in range(num_hist_steps):
                print ("%d"%i, end=" ")
                for t in range(4):
                    for b in range(8):
                        print ("%f"%(hist8x4[b][t][i]), end=" ")
                    print ("%f"%(hist4[t][i]), end=" ")
                print()    
        #Correlate
        corr=[0.0]* num_hist_steps
        for shft in range(num_hist_steps):
            for x in range(0,num_hist_steps-shft):
                for t in range(4):
                    corr[shft]+=hist4[t][x]*hist4[t][x+shft]
        if quiet <1:
            for i, c in enumerate(corr):
                print("%d %f"%(i,c))            
        if quiet <2:
            print ("est_step_period=%f\nest_bin_period=%f"%(est_step_period,est_bin_period))
        # find actual period  using correlation
        if est_bin_period > (0.8*len(corr)):
            raise Exception("Estimated DQS period %f is too high to measure with this data set correlation (%d)"%
                            (est_bin_period, len(corr)))
        corr_low=int(0.5*est_bin_period)
        corr_high=min(int(1.5*est_bin_period),len(corr))
        if quiet <1:
            print ("corr_low=%d, corr_high=%d"%(corr_low, corr_high))
        xmx=corr_low
        for x in range (corr_low,corr_high+1):
            if corr[x] > corr[xmx]:
                xmx=x
        span=max(int(round(est_bin_period/8)),4)
        corr_low=max(corr_low,xmx-span,-num_hist_steps//2)
        corr_high=min(corr_high,xmx+span,num_hist_steps//2-1)
        if quiet <1:
            print ("corrected corr_low=%d, corr_high=%d, xmx=%d"%(corr_low, corr_high, xmx))
        S0=0
        SX=0
        for x in range (corr_low,corr_high+1):
            S0+=corr[x]
            SX+=corr[x]*x
        corr_bin_period=SX/S0
        corr_period= corr_bin_period*bin_size # in finedelay steps
        if quiet <2:
            print ("Period by correlation=%f, (in bin steps: %f)"%(corr_period,corr_bin_period))
        xSpan=min(int(corr_bin_period/2)+1,num_hist_steps//2)
        corr_low= -xSpan
        corr_high= xSpan
        xmx=None
        mx=0
        if quiet <1:
            print ("corr_low=%d, corr_high=%d"%(corr_low, corr_high))
        for x in range(corr_low,corr_high+1):
            y=hist4[primary_set][num_hist_steps//2 + x]
            if y > mx:
                mx=y
                xmx=x
        span=max(int(round(corr_bin_period/8)),4)
        corr_low=max(corr_low,xmx-span,-num_hist_steps//2)
        corr_high=min(corr_high,xmx+span,num_hist_steps//2-1)
        if quiet < 1:
            print ("corrected corr_low=%d, corr_high=%d, xmx=%d"%(corr_low, corr_high, xmx))
        S0=0
        SX=0
        for x in range (corr_low,corr_high+1):
            y=hist4[primary_set][num_hist_steps//2 + x]
            S0+=y
            SX+=y*x
        primary_dly_shift= (SX/S0)* bin_size 
        if quiet < 1:
            print ("tDQ-tDQS difference for primary set =%f (dly fine steps) (in bin steps %f)"%(primary_dly_shift,primary_dly_shift/bin_size))
                        
        # now for each of the other series find maximum closest to either primary or primary +-180 (sign here - opposite to the primary sign)
        # do not forget to apply that sign later, so primary is always leading
        b_series=[None]*4
        for t in range(4):
            if t==primary_set:
                b_series[t]=(primary_dly_shift,0)
            else:
                b_start=primary_dly_shift # will search around b_start
                periods=0
                if ((t ^ primary_set) & 2):
                    if primary_dly_shift > 0:
                        b_start -= corr_period/2
                        periods=-1
                    else:
                        b_start += corr_period/2
                        periods=0 # as expected - primary is supposed to have lower DQ delay, than secondary
                xSpan= corr_bin_period/2
                #scanning in bin, not dly steps
                corr_low= max(int(b_start/bin_size-xSpan),-(num_hist_steps//2))
                corr_high=min(int(b_start/bin_size+xSpan), (num_hist_steps//2)-1)
                xmx=None
                mx=0
                if quiet < 1:
                    print ("series=%d, b_start=%f, corr_low=%d, corr_high=%d, xSpan=%f"%(t, b_start, corr_low, corr_high,xSpan))
                for x in range(corr_low,corr_high+1):
                    y=hist4[t][num_hist_steps//2 + x]
                    if y > mx:
                        mx=y
                        xmx=x
                span=max(int(round(corr_bin_period/8)),4)
                corr_low=max(corr_low,xmx-span)
                corr_high=min(corr_high,xmx+span)
                if quiet < 1:
                    print ("series=%d corrected corr_low=%d, corr_high=%d, xmx=%d"%(t, corr_low, corr_high, xmx))
                S0=0
                SX=0
                for x in range (corr_low,corr_high+1):
                    y=hist4[t][num_hist_steps//2 + x]
                    S0+=y
                    SX+=y*x
                b_series[t]= ((SX/S0)* bin_size,periods) 
                if quiet < 1:
                    print ("tDQ-tDQS difference for set%d =%s (dly fine steps) (in bin steps %d)"%(t,  str(b_series[t]), b_series[t][0]))
        if quiet < 2:
            print ("b_series=%s"%(str(b_series)))                
        #Now find per-bit maximums closest to the average ones                            
        b_indiv=[]
        for b, hst in enumerate(hist8x4):
            b_iseries=[None]*4
            for t in range(4):
                periods=b_series[t][1] # period shift of the averaged series
                b_start=b_series[t][0] # will search around b_start
                xSpan= corr_bin_period/2
                #scanning in bin, not dly steps
                corr_low= max(int(b_start/bin_size-xSpan),-(num_hist_steps//2))
                corr_high=min(int(b_start/bin_size+xSpan), (num_hist_steps//2)-1)
                xmx=None
                mx=0
                if quiet < 1:
                    print ("DQ[%d], series=%d, b_start=%f, corr_low=%d, corr_high=%d, xSpan=%f"%(b, t, b_start, corr_low, corr_high,xSpan))
                for x in range(corr_low,corr_high+1):
                    y=hst[t][num_hist_steps//2 + x]
                    if y > mx:
                        mx=y
                        xmx=x
                span=max(int(round(corr_bin_period/8)),4)
                corr_low=max(corr_low,xmx-span,-num_hist_steps//2)
                corr_high=min(corr_high,xmx+span,num_hist_steps//2-1)
                if quiet < 1:
                    print ("DQ[%d], series=%d corrected corr_low=%d, corr_high=%d, xmx=%d"%(b, t, corr_low, corr_high, xmx))
                S0=0
                SX=0
                for x in range (corr_low,corr_high+1):
                    y=hst[t][num_hist_steps//2 + x]
                    S0+=y
                    SX+=y*x
                b_iseries[t]= ((SX/S0)* bin_size,periods) 
                if quiet < 1:
                    print ("DQ[%d], tDQ-tDQS difference for set%d =%s (dly fine steps) (in bin steps %d)"%(b, t,  str(b_iseries[t]), b_iseries[t][0]))
            b_indiv.append(b_iseries)
        if quiet < 2:
            print ("b_indiv=%s"%(str(b_indiv)))
        return {'period':corr_period,
                'b_series':b_series,
                'b_indiv':b_indiv}
    
    def  get_periods_map(self,
                         lane,
                         data_set,
                         compare_prim_steps,
                         hist_estimated,
                         quiet=1): 
        """
        @param compare_prim_steps while scanning, compare this delay with 1 less by primary(not fine) step,
                            save None for fraction in unknown (previous -0.5, next +0.5)
        
        """                      
        #assign most likely period shift for each data sample
        halfStep=0.5
        if compare_prim_steps:
            halfStep*=FINE_STEPS
        extra_Y=(0.0,halfStep)    
        period=hist_estimated['period']
        data_periods_map=[]
        for dly,data in enumerate(data_set):
            if data:
                data_lane=data[lane*8:(lane+1)*8]
                pm=[None]*8
                for b,bData in enumerate(data_lane): # bdata for each bit is either None or has 4 (maybe None) DQ integer delay values
                    if bData:
                        pm[b]=[None]*4
                        for t,tData in enumerate(bData):
                            if not tData is None: #[dly],[b],[t] tData - int value
                                he=hist_estimated['b_indiv'][b][t] # tuple (b, periods)
                                #find most likely period shift
                                pm[b][t]=int(round((tData[0]+extra_Y[tData[1] is None]-dly-he[0])/period))+he[1]
                data_periods_map.append(pm)
            else:
                data_periods_map.append(None)
        if quiet < 1:       
            print ("\nDQS%d measured data"%lane)
            print ("DQS%d"%lane,end=" ")
            for f in ('ir','if','or','of'):
                for b in range (8):
                    print ("%s_%d"%(f,b),end=" ")
            print()        
                    
            for dly, data in enumerate(data_set):
                print("%d"%dly,end=" ")
                if data:
                    data_lane=data[lane*8:(lane+1)*8]
                    for typ in range(4):
                        for b, bData in enumerate(data_lane): # 8 DQs, each ... 
                            if bData and (not bData[typ] is None):
                                d=bData[typ][0]+extra_Y[bData[typ][1] is None]
                                print ("%d"%(d),end=" ")
                            else:
                                print ("x",end=" ")
                print()
    
        if quiet < 1:       
            print ("\nDQS%d periods data"%lane)
            print ("DQS%d"%lane,end=" ")
            for f in ('ir','if','or','of'):
                for b in range (8):
                    print ("%s_%d"%(f,b),end=" ")
            print()        
                    
            for dly, data in enumerate(data_set):
                print("%d"%dly,end=" ")
                if data:
                    data_lane=data[lane*8:(lane+1)*8]
                    for typ in range(4):
                        for b, bData in enumerate(data_lane): # 8 DQs, each ... 
                            if bData and (not bData[typ] is None):
                                print ("%d"%(data_periods_map[dly][b][typ]),end=" ")
                            else:
                                print ("x",end=" ")
                print()
        if quiet < 2:       
            print ("\nDQS%d combined data"%lane)
            print ("DQS%d"%lane,end=" ")
            for f in ('ir','if','or','of'):
                for b in range (8):
                    print ("%s_%d"%(f,b),end=" ")
            print()        
                    
            for dly, data in enumerate(data_set):
                print("%d"%dly,end=" ")
                if data:
                    data_lane=data[lane*8:(lane+1)*8]
                    for typ in range(4):
                        for b, bData in enumerate(data_lane): # 8 DQs, each ... 
                            if bData and (not bData[typ] is None):
                                d=bData[typ][0]+extra_Y[bData[typ][1] is None]
                                print ("%f"%(d-period*data_periods_map[dly][b][typ]),end=" ")
                            else:
                                print ("x",end=" ")
                print()
        
        return data_periods_map
    def lma_fit_dq_dqs(self,
                       lane, # byte lane
                       bin_size,
                       clk_period,
                       dly_step_ds,
                       primary_set,
                       data_set,
                       compare_prim_steps,
                       scale_w, 
                       quiet=1):        
        """
        Initialize parameters and y-vector
        using datasheet delay/step (without fine step delay)
        and the data set (for each DQS delay - list of 16 bits,
        each of 2x2 elements (DQ delay values) or null
        Create data set template - for each DQS delay and inPhase
         - branch - number of full periods to add
        After initial parametersn are created - run LMA to find optimal ones,
        then return up to 3 varints (early, nominal, late) providing the best
        DQ input delay for each DQS one
        @param lane         byte lane to process (or non-number - process all byte lanes of the device) 
        @param bin_size     bin size for the histograms (should be 5/10/20/40)
        @param clk_period   SDCLK period in ps
        @param dly_step_ds  IDELAY step (from the datasheet)
        @param primary_set  which of the data edge series to use as leading (other will be trailing by 180) 
        @param data_set     measured data set
        @param compare_prim_steps while scanning, compare this delay with 1 less by primary(not fine) step,
                            save None for fraction in unknown (previous -0.5, next +0.5)
        @param scale_w        weight for "uncertain" values (where samples chane from all 0 to all 1 in one step)
        @param quiet        reduce output
        @return 3-element dictionary of ('early','nominal','late'), each being None or a 160-element list,
                each element being either None, or a list of 3 best DQ delay values for the DQS delay (some mey be None too) 
        """
        if not isinstance(lane,(int, long)): # ignore content, process both lanes
            lane_rslt=[]
            numLanes=2
            parametersKey='parameters'
            errorKey='maxErrDqs'
            tDQKey='tDQ'
            earlyKey,nominalKey,lateKey=('early','nominal','late')
#            periods={earlyKey:-1,nominalKey:0,lateKey:1} #t0~= +1216 t1~=-1245
            for lane in range(numLanes):
                lane_rslt.append(self.lma_fit_dq_dqs(lane, # byte lane
                                        bin_size,
                                        clk_period,
                                        dly_step_ds,
                                        primary_set,
                                        data_set,
                                        compare_prim_steps,
                                        scale_w, 
                                        quiet))
            #fix parameters if they have average tDQ different by +/- period(s)
            tDQ_avg=[]
            for lane in range(numLanes):
                tDQ_avg.append(sum(lane_rslt[lane][parametersKey][tDQKey])/len(lane_rslt[lane][parametersKey][tDQKey]))
            per1_0=int(round((tDQ_avg[1]-tDQ_avg[0])/clk_period))
            if abs(tDQ_avg[1]-tDQ_avg[0]) > clk_period/2:
                if quiet <5:
                    print ("lma_fit_dq_dqs: Data lanes tDQ average differs by %.1fps (%d clocks), shifting to match"%(abs(tDQ_avg[1]-tDQ_avg[0]),per1_0))
                if abs(per1_0) > 1:
                    raise Exception ("BUG: lma_fit_dq_dqs: dta lanes differ by more than a period (per1_0=%d periods) - should not happen"%(per1_0))
                #see number of valid items in early,nominal,late branches of each lane
                numInVar=[{},{}]
                for lane in range(numLanes):    
                    for k in lane_rslt[lane].keys():
                        if (k != parametersKey) and (k != errorKey):
                            numValid=0
                            try:
                                for ph in lane_rslt[lane][k]:
                                    if not ph is None:
                                        numValid+=1
                            except:
                                pass
                            numInVar[lane][k]=numValid
                if quiet < 2:
                    print ("numInVar=",numInVar)
                late_lane=(0,1)[per1_0<0] # for late_lane E,N,L -> x, E, N, for not late_lane: E,N,L -> N, L, x
                move_late_lane= (0,1)[numInVar[late_lane][earlyKey] <= numInVar[1-late_lane][lateKey]] # currently both are 0 - nothing is lost
                tDQ_delta=clk_period*(-1,1)[move_late_lane]
                lane_to_change=(1,0)[late_lane ^ move_late_lane]
                if quiet < 2:
                    print ("late_lane=     ",late_lane)
                    print ("move_late_lane=",move_late_lane)
                    print ("lane_to_change=",lane_to_change)
                    print ("tDQ_delta=     ",tDQ_delta)
                # modify tDQ:
                for b in range(len(lane_rslt[lane_to_change][parametersKey][tDQKey])):
                    lane_rslt[lane_to_change][parametersKey][tDQKey][b]+=tDQ_delta
                if quiet < 2:
                    print ("lane_rslt[%d]['%s']['%s']=%s"%(lane_to_change,parametersKey,tDQKey, str(lane_rslt[lane_to_change][parametersKey][tDQKey])))
                # modify variants:
                if move_late_lane:
                    lane_rslt[lane_to_change][earlyKey],  lane_rslt[lane_to_change][nominalKey], lane_rslt[lane_to_change][lateKey]= (
                    lane_rslt[lane_to_change][nominalKey],lane_rslt[lane_to_change][lateKey],    None)
                else:     
                    lane_rslt[lane_to_change][lateKey],   lane_rslt[lane_to_change][nominalKey], lane_rslt[lane_to_change][earlyKey]= (
                    lane_rslt[lane_to_change][nominalKey],lane_rslt[lane_to_change][earlyKey],    None)
                
            # If there are only 2 ENL variants, make 'Nominal' - the largest
            
            rslt={}
            for k in lane_rslt[0].keys():
                if (k != parametersKey) and (k != errorKey):
                    for r in lane_rslt: # lane_rslt is list of two dictionaries
                        try:
                            l=len(r[k])
                            break
                        except:
                            pass
                    else:
                        rslt[k]=None
                        continue
                    rslt[k]=[]
                    for dly in range(l):
                        w=[]
                        for lane in range(numLanes):
                            if (lane_rslt[lane][k] is None) or (lane_rslt[lane][k][dly] is None):
                                w += [None]*8
                            else:
                                w+=lane_rslt[lane][k][dly]
                        for b in w:
                            if not b is None:
                                rslt[k].append(w)
                                break
                        else:
                            rslt[k].append(None)
            rslt[parametersKey] = []             
            for lane in range(numLanes):
                rslt[parametersKey].append(lane_rslt[lane][parametersKey])
#per1_0
#print parameters?
            if quiet <4:
                print ("'%s' = ["%(parametersKey))
                for lane_params in rslt[parametersKey]:
                    print("{")
                    for k,v in lane_params.items():
                        print('%s:%s'%(k,str(v)))  
                    print("},") 
                print ("]")    
            rslt[errorKey]={}
            for k in lane_rslt[0][errorKey].keys():
                for r in lane_rslt: # lane_rslt is list of two dictionaries
                    try:
                        l=len(r[errorKey][k])
                        break
                    except:
                        pass
                else:
                    rslt[errorKey][k]=None
                    continue
                rslt[errorKey][k]=[]
                for dly in range(l):
                    w=[]
                    for lane in range(numLanes):
                        if (lane_rslt[lane][errorKey][k] is None) or (lane_rslt[lane][errorKey][k][dly] is None):
                            w.append(None)
                        else:
                            w.append(lane_rslt[lane][errorKey][k][dly])
                    for lane in w:
                        if not lane is None:
                            rslt[errorKey][k].append(w)
                            break
                    else:
                        rslt[errorKey][k].append(None)
                        
            return rslt # byte lanes combined        
                
                
                
        if quiet < 3:
            print ("init_parameters(): scale_w=%f"%(scale_w))
        self.clk_period=clk_period
        
        hist_estimated=self.dqi_dqsi_estimate_from_histograms(lane, # byte lane
                                                     bin_size,
                                                     clk_period,
                                                     dly_step_ds,
                                                     primary_set,
                                                     data_set,
                                                     compare_prim_steps, 
                                                     quiet)
        if quiet < 3:
            print ("hist_estimated=%s"%(str(hist_estimated)))
        data_periods_map=self.get_periods_map(lane,
                                              data_set,
                                              compare_prim_steps, 
                                              hist_estimated,
                                              quiet)  #+1)

        ywp=    self.createYandWvectors(lane,
                                       data_set,
                                       compare_prim_steps,
                                       scale_w, 
                                       data_periods_map,
                                       quiet)
#        print("ywp=%s"%(str(ywp)))
        if quiet < 2:
            print("\nY-vector:")
            self.showYOrVector(ywp,False,None)
            print("\nY-vector(filtered):")
            self.showYOrVector(ywp,True,None)
        if quiet < 2:
            print("\nperiods_map:")
            self.showYOrVector(ywp,False,ywp['p'])
        if quiet < 2:
            print("\nweights_map:")
            self.showYOrVector(ywp,False,ywp['w'])
        
        
        

        step_ps=clk_period/hist_estimated['period'] #~15.6
        tDQSHL=0;
        tDQHL=[None]*8
        for b, d in enumerate(hist_estimated['b_indiv']):
            tDQSHL  += (d[1][0]-d[0][0] +d[3][0]-d[2][0])*step_ps
            tDQHL[b] = (d[0][0]-d[1][0] +d[3][0]-d[2][0])*step_ps
            if quiet < 3:
                print ("%d: S=%f, D=%f"%(b, d[1][0]-d[0][0] +d[3][0]-d[2][0], d[0][0]-d[1][0] +d[3][0]-d[2][0])) 
        tDQSHL  /= 8.0
        # calculate primary tDQ delays (primary - for the edges selected by 'primary_set'
        tDQ=[0.0]*8
        for b, d in enumerate(hist_estimated['b_indiv']):
            for dp in d:
                tDQ[b] += dp[0]-dp[1] * hist_estimated['period']
            tDQ[b] = step_ps*0.25*(tDQ[b] - hist_estimated['period'])    
         
        parameters={
                    "tSDQS":  step_ps,
                    "tSDQ":   (step_ps,)*8,
                    "tDQSHL": tDQSHL, # 0.0,    # improve Seems that initial value does not match final by sign!
                    "tDQHL":  tDQHL, # (0.0)*8, # improve
                    "tDQS":   0.0,
                    "tDQ":    tDQ,
                    "tFDQS":  (0.0,)*4, 
                    "tFDQ":   (0.0,)*32,
                    "tCDQS":  (0.0,)*30
#                    "anaScale":self.analog_scale
                    }
        """
        Returns # best (early,nominal,late) for each bit for each delay ([3][160][8])
        Outer list each has 160-element list, some of which are None, others hove 8 elements (including None ones)
        """
        if quiet < 2:
            print ("parameters=%s"%(str(parameters)))
        self.normalizeParameters(parameters) #isMask=False)
        if quiet < 3:
            print ("normalized parameters=%s"%(str(parameters)))
        """
            both ways work:
        self.parameterMask={}
        self.normalizeParameters(self.parameterMask,isMask=True)
            and
        """
#        self.parameterMask=self.normalizeParameters({},isMask=True)
        self.parameterMask=self.normalizeParameters(self.parameterMask,isMask=True)
        
        if quiet < 4:
            print ("parameters mask=%s"%(str(self.parameterMask)))
        create_jacobian=True

        fxj= self.createFxAndJacobian(parameters,
                                     ywp,   # keep in self.variable?
                                     primary_set,
                                     create_jacobian,
                                     None, #parMask
                                     quiet)
        
        if create_jacobian:
            fx=fxj['fx']
        else:
            fx=fxj
            
        if quiet < 2:
            print("\nfx:")
            self.showYOrVector(ywp,False,fx)
            print("\nfx (filtered):")
            self.showYOrVector(ywp,True,fx)
            
        if quiet < 5:
            arms = self.getParAvgRMS(parameters,
                                     ywp,
                                     primary_set, # prima
                                     quiet+1)
            print ("Before LMA (DQ lane %d): average(fx)= %fps, rms(fx)=%fps"%(lane,arms['avg'],arms['rms']))
            
        if quiet < 3:
            jByJT=np.dot(fxj['jacob'],np.transpose(fxj['jacob']))
            print("\njByJT:")
            for i,l in enumerate(jByJT):
                print ("%d"%(i),end=" ")
                for d in l: 
                    print ("%f"%(d),end=" ")
                print()
        self.lambdas ['current']=self.lambdas ['initial']       
        for n_iter in range(self.maxNumSteps):
            OK,finished=self.LMA_step(parameters,
                            ywp, # keep in self.variable?
                            primary_set, # prima
                            None, # parMask=    None,
                            self.lambdas,
                            self.finalDiffRMS,
                            quiet)
            if (quiet < 5) or ((quiet < 6) and finished):
                arms = self.getParAvgRMS(parameters,
                                         ywp,
                                         primary_set, # prima
                                         quiet+1)

                print ("%d: LMA_step %s average(fx)= %fps, rms(fx)=%fps"%(n_iter,("FAILURE","SUCCESS")[OK],arms['avg'],arms['rms']))
            if OK and quiet < 2:
                print ("updated parameters=%s"%(str(parameters)))
            if finished:
                if quiet < 4:
                    print ("final parameters=%s"%(str(parameters)))
                break    
                
        fx= self.createFxAndJacobian(parameters,
                                     ywp,   # keep in self.variable?
                                     primary_set,
                                     False,
                                     None,
                                     quiet)
        
        if quiet < 3:
            print("\nfx-postLMA:")
            self.showYOrVector(ywp,False,fx)
            print("\nfx-postLMA (filtered):")
            self.showYOrVector(ywp,True,fx)
            
        # calculate DQ[i] vs. DQS for -1, 0 and +1 period
        DQvDQS_withErr=self.getBestDQforDQS(parameters,
                                            primary_set,
                                            quiet)

        DQvDQS=    DQvDQS_withErr['dqForDqs']
        DQvDQS_ERR=DQvDQS_withErr['maxErrDqs']
        rslt={}
        rslt_names=("early","nominal","late")
        for i, d in enumerate(DQvDQS):
            rslt[rslt_names[i]] = d
        rslt['parameters']=parameters
        
        rslt['maxErrDqs']={} # {enl}[dly]
        for i, d in enumerate(DQvDQS_ERR):
            rslt['maxErrDqs'][rslt_names[i]] = d
        if quiet < 3:
            self.showDQDQSValues(parameters)
        if quiet < 3:
            print ("*** quiet=",quiet)
            self.showENLresults(rslt) # here DQvDQS already contain the needed data 
        
        return rslt


    def getBestDQforDQS(self,
                        parameters,
                        primary_set, # prima
                        quiet=1):
        period=self.clk_period
        tFDQS5=list(parameters['tFDQS'])
        tFDQS5.append(-tFDQS5[0]-tFDQS5[1]-tFDQS5[2]-tFDQS5[3])
        tSDQS=parameters['tSDQS']
        tSDQ= parameters['tSDQ'] # list
        
        tDQS =parameters['tDQS']#single value
        tDQ=  parameters['tDQ'] # list
        
        tCDQS32=list(parameters['tCDQS'][0:8])+[0]+list(parameters['tCDQS'][8:23])+[0]+list(parameters['tCDQS'][23:30])
        
        tDQSHL =parameters['tDQSHL']#single value
        tDQHL=  parameters['tDQHL'] # list

        tFDQs=[] #corrections in steps?
        for b in range(8):
            tFDQi=list(parameters['tFDQ'][4*b:4*(b+1)])
            tFDQi.append(-tFDQi[0]-tFDQi[1]-tFDQi[2]-tFDQi[3])
            tFDQs.append(tFDQi)
        #calculate worst bit error caused by duty cycles (asymmetry) of DQS and DQ lines
        #bit delay error just adds to the  0.25*(abs(tDQSHL)+abs(tDQHL))
        asym_err=[]
        for i in range(8):
            asym_err.append(0.25*(abs(tDQSHL)+abs(tDQHL[i])))
        if quiet < 3:
            print("asym_err=",asym_err) 
        dqForDqs=[]
        maxErrDqs=[]
        for enl in (0,1,2):
            vDQ=[]
            vErr=[]
            someData=False
            for dly in range(DLY_STEPS):
                tdqs=dly * tSDQS - tDQS - tFDQS5[dly % FINE_STEPS] # t - time from DQS pad to internal DQS clock with zero setup/hold times to DQ FFs
                tdqs-=tCDQS32[dly // FINE_STEPS]
                tdqs3=tdqs +(-0.75+enl)*period # (early, nominal, late) in ps, centered in the middle
                bDQ=[]
                errDQ=None
#                dbg_worstBit=None
#                dbg_errs=[None]*8
                for b in range(8): # use all 4 variants
                    tdq=(tdqs3+tDQ[b])/tSDQ[b]
                    itdq=int((tdqs3+tDQ[b])/tSDQ[b]) # in delay steps, approximate (not including tFDQ
                    bestDQ=None
                    if (itdq >= 0) and (itdq < DLY_STEPS):
                        bestDiff=None
                        for idq in range (max(itdq-FINE_STEPS,0),min(itdq+FINE_STEPS,DLY_STEPS-1)+1):
                            tdq=idq * tSDQ[b] - tDQ[b] - tFDQs[b][idq % FINE_STEPS]
                            diff=tdq - tdqs3 # idq-tFDQs[b][idq % FINE_STEPS]
                            if (bestDQ is None) or (abs(diff) < abs(bestDiff)):
                                bestDQ=idq
                                bestDiff=diff
                    if bestDQ is None:            
                        bDQ=None
                        break
                    bDQ.append(bestDQ) #tuple(delay,signed error in ps)
                    fullBitErr=abs(bestDiff) +asym_err[b] #TODO: Restore the full error!
                    if (errDQ is None) or (fullBitErr > errDQ):
                        errDQ= fullBitErr
                    
                    someData=True
                vDQ.append(bDQ)
                vErr.append(errDQ)
            if someData:    
                dqForDqs.append(vDQ)
                maxErrDqs.append(vErr)
            else:
                dqForDqs.append(None)
                maxErrDqs.append(None)
        return {'dqForDqs':dqForDqs,'maxErrDqs':maxErrDqs}
        
    """
    ir = ir0 - s/4 + d/4 # ir - convert to ps from steps
    if = if0 + s/4 - d/4
    or = or0 - s/4 - d/4 # ir - convert to ps from steps
    of = of0 + s/4 + d/4
    (s-d)/2=if-ir
    (s+d)/2=of-or
    s=if-ir+of-or
    d=ir-if+of-or
    """
    def showDQDQSValues(self,
                        parameters):
        tFDQS5=list(parameters['tFDQS'])
        tFDQS5.append(-tFDQS5[0]-tFDQS5[1]-tFDQS5[2]-tFDQS5[3])
        tSDQS=parameters['tSDQS']
        tSDQ= parameters['tSDQ'] # list
        tCDQS32=list(parameters['tCDQS'][0:8])+[0]+list(parameters['tCDQS'][8:23])+[0]+list(parameters['tCDQS'][23:30])
        tFDQs=[] #corrections in steps?
        for b in range(8):
            tFDQi=list(parameters['tFDQ'][4*b:4*(b+1)])
            tFDQi.append(-tFDQi[0]-tFDQi[1]-tFDQi[2]-tFDQi[3])
            tFDQs.append(tFDQi)
        print("\nRelative delay vs delay value")
        print ("dly DSQS", end=" ")
        for b in range(8):
            print ("DQ%d"%(b),end=" ")
        print ()
        for dly in range(DLY_STEPS): # no constant delay - just scale and corrections
            print ("%d"%(dly),end=" ")
            tdqs=dly * tSDQS  - tFDQS5[dly % FINE_STEPS] # t - time from DQS pad to internal DQS clock with zero setup/hold times to DQ FFs
            tdqs-=tCDQS32[dly // FINE_STEPS]
            print("%.3f"%(tdqs),end=" ")
            for b in range(8):
                tdq=dly * tSDQ[b] - tFDQs[b][dly % FINE_STEPS]
                print("%.3f"%(tdq),end=" ")
            print()    

    
    def createFxAndJacobian(self,
                            parameters,
                            y_data, # keep in self.variable?
                            primary_set, # prima
                            jacobian=False, # create jacobian, False - only fx
                            parMask=None,
                            quiet=1):
        def pythIsNone(obj):
            return obj is None
        isNone=pythIsNone # swithch to np.isnan
        y_vector = y_data['y']
        yf_vector = y_data['yf'] # when no fractions available - half interval (0.5 or 2.5) is added, if available - nothing is added
        periods_vector=y_data['p']
        period=self.clk_period
        try:
            y_fractions = y_data['f']
        except:
            y_fractions = None
        try:
            w_vector = y_data['w']
        except:
            w_vector = None
        
        anaScale = parameters['anaScale']
        if y_fractions is None:
            anaScale = 0
        elif isinstance(y_fractions,np.ndarray):
            isNone=np.isnan
#        fx=[0.0]*DLY_STEPS*32
        fx=np.zeros((DLY_STEPS*32,))
        #self.clk_period
        tFDQS5=list(parameters['tFDQS'])
        tFDQS5.append(-tFDQS5[0]-tFDQS5[1]-tFDQS5[2]-tFDQS5[3])
        tCDQS32=list(parameters['tCDQS'][0:8])+[0]+list(parameters['tCDQS'][8:23])+[0]+list(parameters['tCDQS'][23:30])
#        print("*****tCDQS32=",tCDQS32)            
        
        tFDQ=[]
        for b in range(8):
            tFDQi=list(parameters['tFDQ'][4*b:4*(b+1)])
            tFDQi.append(-tFDQi[0]-tFDQi[1]-tFDQi[2]-tFDQi[3])
            tFDQ.append(tFDQi)
        tSDQS=parameters['tSDQS']
        tSDQ= parameters['tSDQ'] # list
        
        tDQS =parameters['tDQS']#single value
        tDQ=  parameters['tDQ'] # list
        
        tDQSHL =parameters['tDQSHL']#single value
        tDQHL=  parameters['tDQHL'] # list
        for dly in range(DLY_STEPS):
            tdqs=dly * tSDQS - tDQS - tFDQS5[dly % FINE_STEPS] # t - time from DQS pad to internal DQS clock with zero setup/hold times to DQ FFs
            tdqs-=tCDQS32[dly // FINE_STEPS]
            tdqs_r = tdqs - 0.25 * tDQSHL # sign opposite from: ir = ir0 - s/4 + d/4; or = or0 - s/4 - d/4 - NOT, but maybe other is wrong
            tdqs_f = tdqs + 0.25 * tDQSHL # sign opposite from: if = if0 + s/4 - d/4; of = of0 + s/4 + d/4
            tdqs_rf=(tdqs_r, tdqs_f)
            #correct for DQS edge type
            for b in range(8): # use all 4 variants
                for t in range(4):
                    indx=32*dly+t*8+b
                    if (w_vector is None) or (w_vector[indx] > 0):
                        tdq=yf_vector[indx] * tSDQ[b] - tDQ[b] - tFDQ[b][y_vector[indx] % FINE_STEPS]
                        # correct for periods
                        tdq -= period*periods_vector[indx] # or should it be minus here?
                        # correct for edge types
                        if (t == 0) or (t == 3):
                            tdq -= 0.25*tDQHL[b]
                        else: 
                            tdq += 0.25*tDQHL[b]
                        if anaScale:
                            if not isNone(y_fractions[indx]):
                                tdq-=anaScale*y_fractions[indx] # negative values mean that actual zero-point is not yet reached
                        if (t ^ primary_set) & 2:
                            tdq -= 0.5*period
                        fx[indx] = tdq - tdqs_rf[t & 1] # odd are falling DQS, even are rising DQS
        if not jacobian:
            return fx
        if parMask is None:
            parMask=self.normalizeParameters(self.parameterMask,isMask=True)
#        pv= self.createParameterVector(parameters,parMask)
#        numPars=len(pv)
#        print("pv=%s"%(str(pv)))
        parInd=self.createParameterIndex(parameters,parMask)
        if quiet <2:
            print("parInd=%s"%(str(parInd)))
        numPars=parInd['numPars']    
        jacob=np.zeros((numPars,DLY_STEPS*32))
        """
        fineM5=((1.0, 0.0, 0.0, 0.0, -0.25),
                (0.0, 1.0, 0.0, 0.0, -0.25),
                (0.0, 0.0, 1.0, 0.0, -0.25),
                (0.0, 0.0, 0.0, 1.0, -0.25))
        """
        fineM5=((1.0, 0.0, 0.0, 0.0, -1.0),
                (0.0, 1.0, 0.0, 0.0, -1.0),
                (0.0, 0.0, 1.0, 0.0, -1.0),
                (0.0, 0.0, 0.0, 1.0, -1.0))
        
        dqs_finedelay_en=parInd['tFDQS']
        for e in dqs_finedelay_en:
            if e>=0:
                break
        else:
            dqs_finedelay_en=None
            
        dqs_delay32_en=parInd['tCDQS']
        for e in dqs_delay32_en:
            if e>=0:
                break
        else:
            dqs_delay32_en=None
#        tCDQS32=list(parameters['tCDQS'][0:8])+[0]+list(parameters['tCDQS'][8:23])+[0]+list(parameters['tCDQS'][23:30])
        if not dqs_delay32_en is None:
            dqs_delay32_index=range(0,8)+[-1]+range(8,23)+[-1]+range(23,30)
            for i,d in enumerate(dqs_delay32_index):
                if d >= 0:
                    dqs_delay32_index[i] = dqs_delay32_en[d]
                    
#            print("*****dqs_delay32_index=",dqs_delay32_index)            
            
        dq_finedelay_en=[None]*8
        for b in range(8):
            dq_finedelay_en[b]=parInd['tFDQ'][4*b:4*(b+1)]
            for e in dq_finedelay_en[b]:
                if e>=0:
                    break
            else:
                dq_finedelay_en[b]=None
            
        for dly in range(DLY_STEPS):
            dlyMod5=dly % FINE_STEPS
            dlyDiv5=dly // FINE_STEPS
            dtdqs_dtSDQS = dly
            dtdqs_dtDQS = -1.0
            dtdqs_dtFDQS = (-fineM5[0][dlyMod5],-fineM5[1][dlyMod5],-fineM5[2][dlyMod5],-fineM5[3][dlyMod5])
            dtdqs_dtDQSHL_rf=(-0.25,+0.25) #  ign opposite from: ir = ir0 - s/4 + d/4; or = or0 - s/4 - d/4, ... - NOT, but maybe other is wrong
            #correct for DQS edge type
#            dbg=[0.0]*32
            for b in range(8): # use all 4 variants
                for t in range(4):
                    indx=32*dly+t*8+b
                    if (w_vector is None) or (w_vector[indx] > 0):
                        #dependencies of DQS delays
                        if parInd['tSDQS'] >= 0:
                            jacob[parInd['tSDQS'],indx]=-dtdqs_dtSDQS
                        if parInd['tDQS'] >= 0:
                            jacob[parInd['tDQS'],indx]=-dtdqs_dtDQS
                        if dqs_finedelay_en:
                            for i,pIndx in enumerate (dqs_finedelay_en):
                                if pIndx >= 0:
                                    jacob[pIndx,indx]=-dtdqs_dtFDQS[i]
                                    
                        if dqs_delay32_en:
                            for i,pIndx in enumerate (dqs_delay32_index):
                                if pIndx >= 0:
                                    jacob[pIndx,indx]=(0,1.0)[i==dlyDiv5]
#                                    dbg[i]+=jacob[pIndx,indx]
                                    
                        if parInd['tDQSHL'] >= 0:
                            jacob[parInd['tDQSHL'],indx]=-dtdqs_dtDQSHL_rf[t & 1]
                        #dependencies of DQ delays
                        # tdq=y_vector[indx] * tSDQ[b] - tDQ[b] - tFDQ[b][y_vector[indx] % FINE_STEPS]
                        if parInd['tSDQ'][b] >= 0:
                            jacob[parInd['tSDQ'][b],indx]=y_vector[indx]
                        if parInd['tDQ'][b] >= 0:
                            jacob[parInd['tDQ'][b],indx] = -1
                        if dq_finedelay_en[b]:
                            yMod5=y_vector[indx] % FINE_STEPS
                            dtdq_dtFDQ = (-fineM5[0][yMod5],-fineM5[1][yMod5],-fineM5[2][yMod5],-fineM5[3][yMod5])
                            for i,pIndx in enumerate (dq_finedelay_en[b]):
                                if pIndx >= 0:
                                    jacob[pIndx,indx]=dtdq_dtFDQ[i]
                        if parInd['tDQHL'][b] >= 0:
                            if (t == 0) or (t == 3):
                                jacob[parInd['tDQHL'][b],indx]=-0.25
                            else:
                                jacob[parInd['tDQHL'][b],indx]=+0.25
                        if parInd['anaScale'] >= 0:
                            if anaScale and not isNone(y_fractions[indx]):
                                jacob[parInd['anaScale'],indx]=-y_fractions[indx]
#            print("dbg: %d: "%(dly),dbg)                            
        return {'fx':fx,'jacob':jacob}
    def getParAvgRMS(self,
                  parameters,
                  ywp,
                  primary_set, # prima
                  quiet=1):
        fx= self.createFxAndJacobian(parameters,
                                     ywp,   # keep in self.variable?
                                     primary_set,
                                     False, # jacobian
                                     None,
                                     quiet)
        """
        SX=0.0
        SX2=0.0
        S0=0.0
        for d,w in zip(fx,ywp['w']):
            if w>0:
                S0+=w
                SX+=w*d
                SX2+=w*d*d
        """
        S0=np.sum(ywp['w'])
        SX=np.sum(fx*ywp['w'])
        SX2=np.sum(fx*fx*ywp['w'])
        avg= SX/S0
        rms= math.sqrt(SX2/S0)
        return {"avg":avg,"rms":rms}
        


    def LMA_step(self,
                parameters,
                ywp, # keep in self.variable?
                primary_set, # prima
                parMask,
                lambdas, #single-element list to update value
                finalDiffRMS,
                quiet=      1):
        parVector0=self.createParameterVector(parameters, parMask) # initial parameter vector
        arms0 = self.getParAvgRMS(parameters,
                                  ywp,
                                  primary_set, # prima
                                  quiet+1)
        if quiet < 2:
                print ("LMA_step <start>: average(fx)= %fps, rms(fx)=%fps"%(arms0['avg'],arms0['rms']))

        delta=self.LMA_solve(parameters,
                             ywp, # keep in self.variable?
                             primary_set, # prima
                             parMask,
                             lambdas["current"],
                             quiet)
        parVector= parVector0+delta
#        print ("\nparVector0=%s"%(str(parVector0)))
#        print ("\ndelta=%s"%(str(delta)))
#        print ("\nparVector=%s"%(str(parVector)))
#        newPars = {}.update(parameters) # so fixed parameters will appear in the newPars
        newPars = self.copyParameters(parameters) # so fixed parameters will appear in the newPars
#        newPars = self.getParametersFromVector(parVector,
        if quiet < 2:
            print ("\nparameters=%s"%(str(parameters)))
#        print ("\n1: newPars=%s"%(str(newPars)))
        self.getParametersFromVector(parVector,
                                               parMask,
                                               newPars) # parameters=None):# if not None, will be updated 
        if quiet < 2:
            print ("\n2: newPars=%s"%(str(newPars)))
#            print ("\nparameters=%s"%(str(parameters)))
        arms1 = self.getParAvgRMS(newPars,
                                  ywp,
                                  primary_set, # prima
                                  quiet+1)
        finished=False
        if arms1['rms'] <= arms0['rms']:
            parameters.update(newPars) 
            lambdas["current"]*=.5
            success=True
            if (arms0['rms'] - arms1['rms']) < finalDiffRMS:
                finished=True
        else:
            lambdas["current"]*=8.0
            success=False
            if lambdas["current"] > lambdas["max"]:
                finished=True
        if (quiet < 2) or ((quiet < 4) and (not success)):
                print ("LMA_step %s: average(fx)= %fps, rms(fx)=%fps, lambda=%f"%(('FAILURE','SUCCESS')[success],arms1['avg'],arms1['rms'],lambdas["current"]))
        return (success,finished)    
            
            

    
    def LMA_solve(self,
                parameters,
                ywp, # keep in self.variable?
                primary_set, # prima
                parMask=    None,
                lmbda=      0.001,
                quiet=      1):
        fxj= self.createFxAndJacobian(parameters,
                                      ywp,   # keep in self.variable?
                                      primary_set,
                                      True, # jacobian
                                      parMask,
                                      quiet)
        try:
            w_vector = ywp['w']
        except:
            w_vector = np.full((len(fxj['fx']),),1.0)
        wJ=fxj['jacob'] *w_vector
        JT=np.transpose(fxj['jacob'])
        #np.fill_diagonal(z3,np.diag(z3)*0.1)
        jByJT=np.dot(wJ,JT)
        for i,_ in enumerate(jByJT):
            jByJT[i,i] += lmbda*jByJT[i,i]
        jByDiff= -np.dot(wJ,fxj['fx'])
        delta=np.linalg.solve(jByJT,jByDiff)
        return delta
                
    """
    
    ir = ir0 - s/4 + d/4 # ir - convert to ps from steps
    if = if0 + s/4 - d/4
    or = or0 - s/4 - d/4 # ir - convert to ps from steps
    of = of0 + s/4 + d/4
    (s-d)/2=if-ir
    (s+d)/2=of-or
    s=if-ir+of-or
    d=ir-if+of-or
    """
    def lma_fit_dqs_phase(self,
                           lane, # byte lane
                           bin_size_ps,
                           clk_period,
                           dqs_dq_parameters,
                           tSDQS, # use if dqs_dq_parameters are not available
                           data_set,
                           compare_prim_steps,
                           scale_w,
                           numPhaseSteps,
                           maxDlyErr=200.0, # ps - trying multiple overlapping branches
                           fallingPhase=False, # output mode - delays decrease when phase increases
                           shiftFracPeriod=0.5, # measured data is marginal, shift optimal by half period 
                           quiet=1):
        """
        Calculate linear approximation for DQS-in or DQS-out vs. phase, crossing periods
        @param lane byte          lane to use (0,1 or 'all')
        @param bin_size_ps        histogram bin size in ps
        @param clk_period         clock period, in ps
        @param dqs_dq_parameters  dq{i,0} vs dqs[i,o} parameters or Null if not yet available (after write levelling)
                                  used to get initial delay scale and fine delay correction
        @param tSDQS              delay in ps for one finedelay step - used only if dqs_dq_parameters are not available 
        @param data_set           data set number for hard-coded debug data or -1 to use actual just measured results
        @param compare_prim_steps if True input data was calibrated with primary delay steps, False - if with fine delay
                                  That means that delay data is on average is either 2.5 or 0.5 lower than unbiased average  
        @param scale_w            weight for samples that have "binary" data with full uncertainty of +/-2.5 or +/-0.5 steps
        @param numPhaseSteps      Total number of delay steps (currently 5*32 = 160)
        @param maxDlyErr          Made for testing multiple overlapping branches, maximal error in ps to keep the result branch
        @param fallingPhase       input data is decreasing with phase increasing (command/addresses, data output), False - increasing
                                  as for DQS in /DQ in
        @param shiftFracPeriod    When measured data is marginal, not optimal, result needs to be shifted by this fraction of the period
                                  Currently it should be 0.5 for input, 0.0 - for output
        @param quiet=1):
        """
        
#       print("++++++lma_fit_dqs_phase(), quiet=",quiet)
        phase_sign=(1,-1)[fallingPhase]
        phase_add=(0,numPhaseSteps)[fallingPhase]
        def show_input_data(filtered):
            print(('unfiltered','filtered')[filtered])
            for phase,d in enumerate(data_set):
                print ("%d"%(phase),end=" ")
                if not d is None:
                    for lane,dl in enumerate(d):
                        if (not dl is None) and (not dl[0] is None) and ((not filtered) or (not dl[1] is None)):
                            dly = dl[0]
                            if dl[1] is None:
                                dly+=halfStep
#                            print ("%f %f"%(dly, dly-phase*phase_step/dbg_tSDQS[lane]), end=" ")
#                            print ("%f %f"%(dly*dbg_tSDQS[lane]/phase_step, dly*dbg_tSDQS[lane]/phase_step-phase), end=" ")
                            print ("%f %f"%(dly*dbg_tSDQS[lane], dly*dbg_tSDQS[lane]+(phase_add-phase)*phase_step), end=" ")
                        else:
                            print ("? ?", end=" ")
                print()
        def get_shift_by_hist(span=5):
            for phase,d in enumerate(data_set):
                if not d is None:
                    dl=d[lane]
                    if (not dl is None) and (not dl[0] is None):
                        dly = dl[0]
                        if dl[1] is None:
                            dly+=halfStep
                        diff_ps=dly*tSDQS+(phase_add-phase)*phase_step
                        binArr[int((diff_ps-minVal)/bin_size_ps)]+=1
            if quiet < 3:
                for i,h in enumerate(binArr):
                    print ("%d %d"%(i,h))
            indx=0
            for i,h in enumerate(binArr):
                if h > binArr[indx]:
                    indx=i
            low = max(0,indx-span)
            high = min(len(binArr)-1,indx+span)
            S0=0
            SX=0.0
            for i in range (low, high+1):
                S0+=binArr[i]
                SX+=binArr[i]*i
            if S0>0:
                SX/=S0
            if quiet < 3:
                print ("SX=",SX)
            return minVal+bin_size_ps*(SX+0.5) # ps
        
        if not isinstance(lane,(int, long)): # ignore content, process both lanes
            rslt_names=("dqs_optimal_ps","dqs_phase","dqs_phase_multi","dqs_phase_err","dqs_min_max_periods")
            rslt= {}
            for name in rslt_names:
                rslt[name] = []
                 
            for lane in range(2):
                rslt_lane=self.lma_fit_dqs_phase(lane=               lane, # byte lane
                                                 bin_size_ps=        bin_size_ps,
                                                 clk_period=         clk_period,
                                                 dqs_dq_parameters=  dqs_dq_parameters,
                                                 tSDQS=              tSDQS,
                                                 data_set=           data_set,
                                                 compare_prim_steps= compare_prim_steps,
                                                 scale_w=            scale_w,
                                                 numPhaseSteps=      numPhaseSteps,
                                                 maxDlyErr=          maxDlyErr,
                                                 fallingPhase=       fallingPhase,
                                                 shiftFracPeriod=    shiftFracPeriod, 
                                                 quiet=              quiet)
                
                for name in rslt_names:
                    rslt[name].append(rslt_lane[name])
            if quiet<3:
                print ('dqs_optimal_ps=%s'%(str(rslt['dqs_optimal_ps'])))
                print ('dqs_phase=[')
                for lane in rslt['dqs_phase']:
                    print("    [",end=" ")
                    for i,d in enumerate(lane):
                        last= i == (len(lane)-1)
                        print("%s"%(str(d)), end=" ")
                        if not last:
                            print(",",end=" ")
                            if ((i+1) % 16) ==0:
                                print("\n     ",end="")
                        else:
                            print('],')
                print(']')
                print ('dqs_phase_multi=[')
                for lane in rslt['dqs_phase_multi']:
                    print("    [",end=" ")
                    for i,d in enumerate(lane):
                        last= i == (len(lane)-1)
                        print("%s"%(str(d)), end=" ")
                        if not last:
                            print(",",end=" ")
                            if ((i+1) % 16) ==0:
                                print("\n     ",end="")
                        else:
                            print('],')
                print(']')
                print ('dqs_phase_err=[')
                for lane in rslt['dqs_phase_err']:
                    print("    [",end=" ")
                    for i,d in enumerate(lane):
                        last= i == (len(lane)-1)
                        print("%s"%(str(d)), end=" ")
                        if not last:
                            print(",",end=" ")
                            if ((i+1) % 16) ==0:
                                print("\n     ",end="")
                        else:
                            print('],')
                print(']')
                
#                print(rslt)
            
            return rslt
               
            
        phase_step= phase_sign*clk_period/ numPhaseSteps
        try:      
            tSDQS=dqs_dq_parameters[lane]['tSDQS'] # ~16.081739769147354
        except:
            if quiet < 2:
                print("dqs_dq_parameters are not available, using datasheet value for tSDQS=%f ps"%(tSDQS))
        
        try:
            dbg_tSDQS=(dqs_dq_parameters[0]['tSDQS'],dqs_dq_parameters[1]['tSDQS'])
        except:
            dbg_tSDQS=(tSDQS,tSDQS)

        halfStep=0.5*(1,compare_prim_steps)[compare_prim_steps]
            
        #phase_step/tSDQS
#        print("lma_fit_dqs_phase(): quiet=",quiet)
        if quiet < 2:
            print (phase_step,dbg_tSDQS)
            for filtered in range(2):
                show_input_data(filtered)    

        # all preliminary tests above
        #phase_add
        if fallingPhase:
            maxVal= clk_period
            minVal= -DLY_STEPS*abs(tSDQS)
        else:
            maxVal= DLY_STEPS*abs(tSDQS)
            minVal= -clk_period
        num_bins=int((maxVal-minVal)/bin_size_ps)+1
        binArr=[0]*num_bins
        if quiet < 2:
            print("minVal=",minVal)
            print("maxVal=",maxVal)
            print("num_bins=",num_bins)
        #find main max
        dly_max0=get_shift_by_hist() # delay in ps, corresponding to largest maximum
        if quiet < 2:
            print("max0=%f, (%f)"%(dly_max0,dly_max0/tSDQS))
        periods=[None]*len(data_set)
        for phase,d in enumerate(data_set):
            if not d is None:
                dl=d[lane]
                if (not dl is None) and (not dl[0] is None):
                    dly = dl[0]
                    if dl[1] is None:
                        dly+=halfStep
                    periods[phase]=int(round((dly*tSDQS+(phase_add-phase)*phase_step)/clk_period)) #############################
        w=[0.0]*len(data_set)
        if quiet < 2:
            for i,p in enumerate(periods):
                print ("%d %s"%(i,str(p)))
        try:
            tFDQS=dqs_dq_parameters[lane]['tFDQS'] # [-21.824409224001187, -10.830180678770162, 1.5698858542328959, 11.267851084349177]
            tFDQS.append(-tFDQS[0]-tFDQS[1]-tFDQS[2]-tFDQS[3])
        except:
            tFDQS=[0.0]*FINE_STEPS
        SY=0.0
        S0=0.0
        for phase,d in enumerate(data_set):
            if not d is None:
                dl=d[lane]
                if (not dl is None) and (not dl[0] is None):
                    dly = dl[0]
                    w[phase]=1.0
                    if dl[1] is None:
                        dly+=halfStep
                        w[phase]=scale_w
                    d=dly*tSDQS-periods[phase]*clk_period-tFDQS[dl[0] % FINE_STEPS] ############################
                    y=d+(phase_add-phase)*phase_step
                    S0+=w[phase]
                    SY+=w[phase]*y
        if S0 > 0.0:
            SY /= S0

        if quiet < 2:
            print ("shift=",SY," ps")
            for phase,d in enumerate(data_set):
                print ("%d"%(phase),end=" ")
                if not d is None:
                    dl=d[lane]
                    if (not dl is None) and (not dl[0] is None):
                        dly = dl[0]
                        if dl[1] is None:
                            dly+=halfStep
                        d=dly*tSDQS-periods[phase]*clk_period-tFDQS[dl[0] % FINE_STEPS] ############################
                        print ("%f %f"%(d, w[i]), end=" ")
                        if not dl[1] is None:
                            print(d,end=" ")
                        else:
                            print("?",end=" ")
                    else:
                        print ("? ?", end=" ")
                    print("%f"%(SY-(phase_add-phase)*phase_step),end=" ")
                print()
        # Now shift SY by half clk_period for each phase find the closest DQSI match (None if does not exist)
        # Shift should only be for DQSI (middle between the errors), for WLEV - no shift
        #shiftFracPeriod
        dqsi_range=abs(tSDQS)*DLY_STEPS# full range of the DQSI delay for this lane
#        dqsi_middle_in_ps = SY-clk_period*(round(SY/clk_period -0.5)+0.5)
        dqsi_middle_in_ps = SY-clk_period*(round(SY/clk_period -shiftFracPeriod)+shiftFracPeriod)
        if quiet < 3:
            print("SY=",SY)
            print("dqsi_middle_in_ps=",dqsi_middle_in_ps)
            print("phase_add=",phase_add)
            print("phase_step=",phase_step)
            print("shiftFracPeriod=",shiftFracPeriod)
            print("clk_period*shiftFracPeriod=",(clk_period*shiftFracPeriod))
        dqs_phase=[None]*numPhaseSteps
        for phase in range(numPhaseSteps):
            dly_ps=-phase_step*(phase_add-phase)+dqsi_middle_in_ps
            dly_ps-=clk_period*round(dly_ps/clk_period - 0.5) # positive, <clk_period
            #Using lowest delay branch if multiple are possible
            if dly_ps > dqsi_range:
                continue # no valid dqs_idelay for this phase
            idly = int (round(dly_ps/tSDQS))  ###############?
            low= max(0,idly-FINE_STEPS)
            high=min(DLY_STEPS-1,idly+FINE_STEPS)
            idly=low
            for i in range(low,high+1):
                if abs(i*tSDQS-tFDQS[i % FINE_STEPS]-dly_ps) < abs(idly*tSDQS-tFDQS[idly % FINE_STEPS]-dly_ps): ############################
                    idly=i
            dqs_phase[phase]=idly
        if quiet < 3:
            for phase,d in enumerate(data_set):
                print ("%d"%(phase),end=" ")
                if (not d is None) and (not d[lane] is None) and (not d[lane][0] is None):
                    dly = d[lane][0]
                    if d[lane][1] is None:
                        dly+=halfStep
                    print ("%f"%(dly), end=" ")
                else:
                    print ("?", end=" ")
                if not dqs_phase[phase] is None:
                    print("%f"%(dqs_phase[phase]),end=" ")
                else:
                    print ("?", end=" ")
                print()
        # maxDlyErr (ps)
        dqsi_phase_multi=[None]*numPhaseSteps
        dqsi_phase_err=  [None]*numPhaseSteps
        min_max_periods=None
        for phase in range(numPhaseSteps):
            dly_ps=phase_step*(phase-phase_add)+dqsi_middle_in_ps
            periods=int(round((dly_ps+ +maxDlyErr)/clk_period - 0.5))
            dly_ps-=clk_period*periods # positive, <clk_period
            #Using lowest delay branch if multiple are possible - now all branches
            if dly_ps <= (dqsi_range+maxDlyErr):
                dqsi_phase_multi[phase]={}
                dqsi_phase_err[phase]={}
                while dly_ps <= (dqsi_range+maxDlyErr):
                    try:
                        min_max_periods[0]=min(min_max_periods[0],periods)
                        min_max_periods[1]=max(min_max_periods[1],periods)
                    except:
                        min_max_periods=[periods,periods]
                    idly = int (round(dly_ps/tSDQS))   ##########################################
                    low= max(0,idly-FINE_STEPS)
#                    high=min(DLY_STEPS-1,idly+FINE_STEPS)
                    high=idly+FINE_STEPS
                    if  high >= DLY_STEPS:
                        high=DLY_STEPS - 1
                        low= DLY_STEPS - FINE_STEPS
                    idly=low
                    for i in range(low,high+1):
                        if abs(i*tSDQS-tFDQS[i % FINE_STEPS]-dly_ps) < abs(idly*tSDQS-tFDQS[idly % FINE_STEPS]-dly_ps):   ###################
                            idly=i
                    dqsi_phase_multi[phase][periods]=idly
                    dqsi_phase_err[phase][periods]=idly*tSDQS-tFDQS[idly % FINE_STEPS]-dly_ps    ######################
                    periods-=1
                    dly_ps+=clk_period
                    
        if quiet < 3:
            print ("maxDlyErr=",maxDlyErr)
            print ("min_max_periods=",min_max_periods)
            print ("dqsi_phase_multi=",dqsi_phase_multi)
            print ("dqsi_phase_err=",dqsi_phase_err)
            for phase,d in enumerate(data_set):
                print ("%d"%(phase),end=" ")
                if (not d is None) and (not d[lane] is None) and (not d[lane][0] is None):
                    dly = d[lane][0]
                    if d[lane][1] is None:
                        dly+=halfStep
                    print ("%f"%(dly), end=" ")
                else:
                    print ("?", end=" ")
                if not dqsi_phase_multi[phase] is None:
                    for periods in range (min_max_periods[0],min_max_periods[1]+1):
                        try:
                            print("%f"%(dqsi_phase_multi[phase][periods]),end=" ")
                        except:
                            print ("?", end=" ")
                    for periods in range (min_max_periods[0],min_max_periods[1]+1):
                        try:
                            print("%.1f"%(dqsi_phase_err[phase][periods]),end=" ")
                        except:
                            print ("?", end=" ")
                else:
                    print ("?", end=" ")
                print()
                
        return {"dqs_optimal_ps":dqsi_middle_in_ps,
                "dqs_phase":dqs_phase,
                "dqs_phase_multi":dqsi_phase_multi,
                "dqs_phase_err":dqsi_phase_err,
                "dqs_min_max_periods":min_max_periods
                }        
        
            
                        
                    

        
        
        