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

def test_data(meas_delays,
              quiet=1):
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
                            print ("%d"%pData[typ],end=" ")
                        else:
                            print ("x",end=" ")
            print()
            
PARAMETER_TYPES=(
                     {"name":"tSDQS",  "size":1, "units":"ps","description":"DQS input delay per step (1/5 of the datasheet value)","en":1},
                     {"name":"tSDQ",   "size":8, "units":"ps","description":"DQ input delay per step (1/5 of the datasheet value)","en":1},
                     {"name":"tDQSHL", "size":1, "units":"ps","description":"DQS HIGH minus LOW difference","en":1},
                     {"name":"tDQHL",  "size":8, "units":"ps","description":"DQi HIGH minus LOW difference","en":1},
                     {"name":"tDQS",   "size":1, "units":"ps","description":"DQS delay (not adjusted)","en":0},
                     {"name":"tDQ",    "size":8, "units":"ps","description":"DQi delay","en":1},
                     {"name":"tFDQS",  "size":4, "units":"ps","description":"DQS fine delays (mod 5)","en":1}, #only 4 are independent, 5-th is -sum of 4 
                     {"name":"tFDQ",   "size":32,"units":"ps","description":"DQ  fine delays (mod 5)","en":1})
FINE_STEPS=5
DLY_STEPS =FINE_STEPS * 32 # =160 
def make_repeat(value,nRep):
    if isinstance(value,(list,tuple)):
        return value
    else:
        return (value,)*nRep
           
class X393LMA(object):
    parameters=None
    parameterMask=None
    parameterVector=None
#    hist_estimated=None # DQ/DQS delay period,
#                        # DQ-DQS shift (and number of periods later) for averaged and individual bits,
#                        # for each of 4 edge types
    def __init__(self):
        pass
    
    def createYandWvectors(self,
                           lane,
                           data_set,
                           periods=None):
        n=len(data_set)*32
        y=[0]*n
        w=[0]*n
        if not periods is None:
            p=[0]*n 
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
                                y[i]=tData
                                w[i]=1
                                if not periods is None:
                                    p[i]=periods[dly][b][t] 
        vectors={'y':y,'w':w}
        if not periods is None:
            vectors['p']=p                        
        return vectors 

    def showYOrVector(self,
                      ywp,
                      vector=None):
        pass
        # If vector is None - print y vector (skipping zero mask),
        # otherwise print vector (should be the same length, using the same 'w' weight mask
        v=vector
        if v is None:
            v= ywp['y']
        w=ywp['w']
        print("DQS_dly", end= " ")
        for f in ('ir','if','or','of'):
            for b in range (8):
                print ("%s_%d"%(f,b),end=" ")
        print()
        n=len(v)/32
        for dly in range(n):
            print("%d"%dly,end=" ")
            for t in range(4):
                for b in range(8):
                    i=32*dly+8*t+b
                    if w[i]:
                        print("%s"%(str(v[i])),end=" ")
                    else:
                        print("?",end=" ")      
            print()
        

    def createParameterVector(self,
                              parameters=None,
                              parameterMask=None):
        global PARAMETER_TYPES
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
        return vector
        
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
     
    def estimate_from_histograms(self,
                                 lane, # byte lane
                                 bin_size,
                                 clk_period,
                                 dly_step_ds,
                                 primary_set,
                                 data_set,
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
        @lane          byte lane to process 
        @bin_size     bin size for the histograms (should be 5/10/20/40)
        @clk_period   SDCLK period in ps
        @dly_step_ds  IDELAY step (from the datasheet)
        @primary_set  which of the data edge series to use as leading (other will be trailing by 180) 
        @data_set     measured data set
        @quiet        reduce output   
        """
        num_hist_steps=2*((DLY_STEPS+bin_size-1)//bin_size)
        
        est_step_period=(clk_period/dly_step_ds)*FINE_STEPS
        est_bin_period=est_step_period/bin_size
        
        
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
                                binNum=(tData-dly+DLY_STEPS+1) // bin_size
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
        corr_low=max(corr_low,xmx-span)
        corr_high=min(corr_high,xmx+span)
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
        corr_low=max(corr_low,xmx-span)
        corr_high=min(corr_high,xmx+span)
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
                corr_high=min(int(b_start/bin_size+xSpan), (num_hist_steps//2))
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
                corr_high=min(int(b_start/bin_size+xSpan), (num_hist_steps//2))
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
                corr_low=max(corr_low,xmx-span)
                corr_high=min(corr_high,xmx+span)
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
                         hist_estimated,
                         quiet=1):                       
        #assign most likely period shift for each data sample
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
                                pm[b][t]=int(round((tData-dly-he[0])/period))+he[1]
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
                                print ("%d"%(bData[typ]),end=" ")
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
                                print ("%f"%(bData[typ]-period*data_periods_map[dly][b][typ]),end=" ")
                            else:
                                print ("x",end=" ")
                print()
        
        return data_periods_map
    def init_parameters(self,
                        lane, # byte lane
                        bin_size,
                        clk_period,
                        dly_step_ds,
                        primary_set,
                        data_set,
                        quiet=1):        
        """
        Initialize parameters and y-vector
        using datasheet delay/step (without fine step delay)
        and the data set (for each DQS delay - list of 16 bits,
        each of 2x2 elements (DQ delay values) or null
        Create data set template - for each DQS delay and inPhase
         - branch - number of full periods to add
        @lane          byte lane to process 
        @bin_size     bin size for the histograms (should be 5/10/20/40)
        @clk_period   SDCLK period in ps
        @dly_step_ds  IDELAY step (from the datasheet)
        @primary_set  which of the data edge series to use as leading (other will be trailing by 180) 
        @data_set     measured data set
        @quiet        reduce output   
        """
        hist_estimated=self.estimate_from_histograms(lane, # byte lane
                                                     bin_size,
                                                     clk_period,
                                                     dly_step_ds,
                                                     primary_set,
                                                     data_set,
                                                     quiet)
        print ("hist_estimated=%s"%(str(hist_estimated)))
        data_periods_map=self.get_periods_map(lane,
                                              data_set,
                                              hist_estimated,
                                              quiet)  #+1)

        ywp=    self.createYandWvectors(lane,
                                       data_set,
                                       data_periods_map)
#        print("ywp=%s"%(str(ywp)))
        print("\nY-vector:")
        self.showYOrVector(ywp)
        print("\nperiods map:")
        self.showYOrVector(ywp,ywp['p'])
        
        
        

        step_ps=clk_period/hist_estimated['period'] #~15.6
        tDQSHL=0;
        tDQHL=[None]*8
        for b, d in enumerate(hist_estimated['b_indiv']):
            tDQSHL  += (d[1][0]-d[0][0] +d[3][0]-d[2][0])*step_ps
            tDQHL[b] = (d[0][0]-d[1][0] +d[3][0]-d[2][0])*step_ps
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
                    "tDQSHL": tDQSHL, # 0.0,    # improve
                    "tDQHL":  tDQHL, # (0.0)*8, # improve
                    "tDQS":   0.0,
                    "tDQ":    tDQ,
                    "tFDQS":  (0.0,)*4, 
                    "tFDQ":   (0.0,)*32
                    }
        print ("parameters=%s"%(str(parameters)))
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