from __future__ import print_function
'''
# Copyright (C) 2015, Elphel.inc.
# Class to measure and adjust I/O delays  
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
import sys
import pickle
#import x393_mem
#x393_pio_sequences
#from import_verilog_parameters import VerilogParameters
from x393_mem                import X393Mem
#from x393_axi_control_status import X393AxiControlStatus
import x393_axi_control_status
from x393_pio_sequences      import X393PIOSequences
from x393_mcntrl_timing      import X393McntrlTiming
from x393_mcntrl_buffers     import X393McntrlBuffers
from verilog_utils import split_delay,combine_delay,NUM_FINE_STEPS, convert_w32_to_mem16,convert_mem16_to_w32
#from x393_utils              import X393Utils
import x393_utils

import get_test_dq_dqs_data # temporary to test processing            
import x393_lma
import time
import vrlg
#NUM_FINE_STEPS=    5
NUM_DLY_STEPS =NUM_FINE_STEPS * 32 # =160
DQI_KEY='dqi'
DQO_KEY='dqo'
DQSI_KEY='dqsi'
DQSO_KEY='dqso'
CMDA_KEY='cmda'
ODD_KEY='odd'
SIG_LIST=[CMDA_KEY,DQSI_KEY,DQI_KEY,DQSO_KEY,DQO_KEY]
DFLT_DLY_FILT=['Best','Early'] # default non-None filter setting to select a single "best" delay/delay set 

class X393McntrlAdjust(object):
    DRY_MODE= True # True
    DEBUG_MODE=1
    x393_mem=None
    x393_axi_tasks=None #x393X393AxiControlStatus
    x393_pio_sequences=None
    x393_mcntrl_timing=None
    x393_mcntrl_buffers=None
    x393_utils=None
    verbose=1
    adjustment_state={}
    def __init__(self, debug_mode=1,dry_mode=True, saveFileName=None):
        self.DEBUG_MODE=  debug_mode
        self.DRY_MODE=    dry_mode
        self.x393_mem=            X393Mem(debug_mode,dry_mode)
#        self.x393_axi_tasks=      X393AxiControlStatus(debug_mode,dry_mode)
        self.x393_axi_tasks=      x393_axi_control_status.X393AxiControlStatus(debug_mode,dry_mode)
        self.x393_pio_sequences=  X393PIOSequences(debug_mode,dry_mode)
        self.x393_mcntrl_timing=  X393McntrlTiming(debug_mode,dry_mode)
        self.x393_mcntrl_buffers= X393McntrlBuffers(debug_mode,dry_mode)
#        print("x393_utils.SAVE_FILE_NAME=",x393_utils.SAVE_FILE_NAME)
        self.x393_utils=          x393_utils.X393Utils(debug_mode,dry_mode, saveFileName) # should not overwrite save file path
#        self.__dict__.update(VerilogParameters.__dict__["_VerilogParameters__shared_state"]) # Add verilog parameters to the class namespace
        try:
            self.verbose=vrlg.VERBOSE
        except:
            pass
#keep as command        

    def format_dq_to_verilog(self,
                             estr):
        """
        Convert dq delays list to the form to paste to the Verilog parameters code
        <estr> quoted string, such as:
         "[['0xd9', '0xdb', '0xdc', '0xd4', '0xe0', '0xda', '0xd4', '0xd8'], ['0xdc', '0xe0', '0xf1', '0xdc', '0xe0', '0xdc', '0xdc', '0xdc']]"
        Returns a pair of strings to paste
        """
        se=eval(estr) # now a list of list of strings
        for l in se:
            for i,v in enumerate(l):
                l[i]=int(v,16)
        for lane in range(2):
            print("lane%d = 64'h"%lane,end="")
            for i in range(len(se[lane])):
                print("%02x"%se[lane][-i-1],end="")
            print()

    def missing_dqs_notused(self,
                     rd_blk,
                     quiet=False):
        """
        Suspect missing final DQS puls(es) during write if last written burst matches previous one
        <rd_blk> - block of 32-bit data read from DDR3 device
        <quiet>  - no output
        Returns True if missing DQS pulse is suspected
        """
        if (not rd_blk) or (len(rd_blk) <8 ):
            return False
        for i in range(-4,0):
            if rd_blk[i] != rd_blk[i-4]:
                break
        else:
            if not quiet:
                print ("End of the block repeats 2 last 8-bursts, insufficient number of trailing DQS pulses is suspected:")
                print("\n%03x:"%(len(rd_blk)-8),end=" ")
                for i in range(len(rd_blk)-8,len(rd_blk)):
                    print("%08x"%rd_blk[i],end=" ")
                print("\n")
            return True
        return False
    
    def _get_dqs_dly_err(self,
                         phase,
                         delays,
                         errors):
        '''
        extract dqsi/dqso data for a single phase as a dictionary with keys - signed integer period branches,
        values - list of 2 lane delays
        Returns either this dictionary or a tuple of this one and corresponding worst errors. Or None!
        '''
        periods=None # needed just for PyDev?
        for linedata in delays:
            try:
                periods &= set(linedata[phase].keys())
            except:
                try:
                    periods = set(linedata[phase].keys())
                except:
                    pass
        if not periods:
            return None # no branch has all lines
        phaseData={}
        #Errors may be common for the whole 8-bit lane
        if not errors is None:
            phaseErrs={}
            if len(delays)==8*len(errors):
                errors=[errors[i//8] for i in range(len(delays))]
        for branch in periods:
            phaseData[branch]=[]
            if not errors is None:
                phaseErrs[branch]=0.0
                for lineData,lineErr in zip(delays,errors):
                    try:
                        phaseData[branch].append(lineData[phase][branch])
                    except:
                        phaseData[branch].append(None)
                    try:
                        phaseErrs[branch]=max(phaseErrs[branch],abs(lineErr[phase][branch]))
                    except:
                        pass
                        
            else:
                for lineData in delays:
                    phaseData[branch].append(lineData[phase][branch])
        if errors is None:
            return phaseData
        else:
            return (phaseData,phaseErrs)
    '''    
    def combine_dq_dqs(self,
                       outMode=None,
                       quiet=1):
        """
        @param outmode False - dqi/dqsi, True - dgo/dqso, None - both
        """
        if outMode is None:
            self.combine_dq_dqs(False)
            self.combine_dq_dqs(True)
        elif outMode:
            delays, errors= self._combine_dq_dqs(dqs_data=self.adjustment_state['dqso_phase_multi'],
                                                 dq_enl_data=self.adjustment_state["dqo_dqso"],
                                                 dq_enl_err = self.adjustment_state["maxErrDqso"],
                                                 quiet=quiet)
            self.adjustment_state['dqo_phase_multi'] = delays
            self.adjustment_state["dqo_phase_err"] =   errors
        elif outMode:
            delays, errors= self._combine_dq_dqs(dqs_data=self.adjustment_state['dqsi_phase_multi'],
                                                 dq_enl_data=self.adjustment_state["dqi_dqsi"],
                                                 dq_enl_err = self.adjustment_state["maxErrDqsi"],
                                                 quiet=quiet)
            self.adjustment_state['dqi_phase_multi'] = delays
            self.adjustment_state["dqi_phase_err"] =   errors
        else:
            self.combine_dq_dqs(False)
            self.combine_dq_dqs(True)
    '''
                
    def _combine_dq_dqs(self,
                       dqs_data,
                       dq_enl_data,
                       dq_enl_err,
#                       target="dqsi",
                       quiet=1):
        """
        Create possibly overlapping branches of delay/error data vs phase for dqi or dqo
        @param dqs_data     self.adjustment_state['dqs?_phase_multi'] (dqs errors are not used here)
        @param dq_enl_data  self.adjustment_state["dq?_dqs?"]  delay[ENL-branch][dqs_dly][bit] ('None' may be at any level)
        @param dq_enl_err   self.adjustment_state["maxErrDqs?"] errorPS[ENL-branch][dqs_dly][bit] ('None' may be at any level)
#        @param target - one of "dqsi" or "dqso"
        @param quiet reduce output
        @return dqi/dqo object compatible with the input of get_delays_for_phase():
        (data[line][phase]{(p_dqs,p_dq):delay, ...}, err[lane][phase]{(p_dqs,p_dq):delay, ...}
        Errors are per-lane, not per line!
        """
        #
#        if quiet <2:
#            print("dq_enl_data=",dq_enl_data)
#            print("\ndqs_data=",dqs_data)
#           print("\ndqs_data[0]=",dqs_data[0])
#            print("\nlen(dqs_data[0])=",len(dqs_data[0]))
            
        enl_dict={'early':-1,'nominal':0,'late':1}
#        for enl_branch in 
        numPhaseSteps= len(dqs_data[0])
        for v in dq_enl_data.values():
            try: # branch data
                for p in v: # phase data
                    try:
                        numLines=len(p)
                        break
                    except:
                        pass
                break
            except:
                pass
#        numLanes=numLines//8
#                    for enl_branch in dq_enl_data:

        if quiet <2:
#            print ("numLines=",numLines," numLanes=",numLanes," numPhaseSteps=",numPhaseSteps)
            print ("numLines=",numLines," numPhaseSteps=",numPhaseSteps)
        data=[[] for _ in range(numLines)] # each element is a new instance of a list
        errs=[[] for _ in range(numLines//8)] # each element is a new instance of a list
        for phase in range(numPhaseSteps):
            
            line_data=[{} for _ in range(numLines)] # each element is a new instance of a dict
            line_errs=[{} for _ in range(numLines//8)] # each element is a new instance of a dict
            phaseData=self._get_dqs_dly_err(phase,
                                            dqs_data,
                                            None)
            if quiet <2:
                print ("===== phase=%d phaseData=%s"%(phase,str(phaseData)))
            if not phaseData is None:
                periods_dqs=phaseData.keys()
                periods_dqs.sort()

                for period_dqs in periods_dqs: # iterate through all dqs periods
                    dly_dqs=phaseData[period_dqs] # pair of lane delays
                    for enl_branch in dq_enl_data:
                        if not enl_branch is None: 
                            period_dq=enl_dict[enl_branch]
                            period_key=(period_dqs,period_dq)
                            if quiet <2:
                                print ("period_dqs=%d enl_branch=%s period_key=%s, dly_dqs=%s"%(period_dqs,enl_branch,str(period_key),str(dly_dqs)))
                                try:
                                    print ("dq_enl_data['%s][%d]=%s"%(enl_branch,dly_dqs[0], str(dq_enl_data[enl_branch][dly_dqs[0]])))
                                except:
                                    print ("dq_enl_data['%s]=%s"%(enl_branch, str(dq_enl_data[enl_branch])))
                                try:
                                    print ("dq_enl_data['%s][%d]=%s"%(enl_branch,dly_dqs[1], str(dq_enl_data[enl_branch][dly_dqs[0]])))
                                except:
                                    pass
                            for line in range(numLines):
                                try:
                                    line_data[line][period_key]=dq_enl_data[enl_branch][dly_dqs[line//8]][line]
                                except:
                                    pass
                            for lane in range(numLines//8):
                                try:
                                    line_errs[lane][period_key]=dq_enl_err [enl_branch][dly_dqs[lane]][lane]
                                except:
                                    pass
                            if quiet <2:
                                print ("line_data=",line_data)
                                print ("line_errs=",line_errs)
                                
                
            for line,d in zip(data,line_data):
                if d: # not empty dictionary
                    line.append(d)
                else:
                    line.append(None)        
            for line,d in zip(errs,line_errs):
                if d:
                    line.append(d)
                else:
                    line.append(None)
        if quiet <3:
            print ("\ndq_dqs_combined_data=",data)
            print ("\ndq_dqs_combined_errs=",errs)
            print('len(data)=',len(data),'len(data[0])=',len(data[0]))
            print('len(errs)=',len(errs),'len(errs[0])=',len(errs[0]))
            print("")
            for phase in range(len(data[0])):
                print ("%d"%(phase), end=" ")
                for line in range(len(data)):
                    print("%s"%(str(data[line][phase])), end=" ")
                for lane in range(len(errs)):
                    print("%s"%(str(errs[lane][phase])), end=" ")
                print()
        return (data,errs)
    
        
    def get_delays_for_phase(self,
                          phase = None,
                          list_branches=False,
                          target=DQSI_KEY,
                          b_filter=None, # will default to earliest (lowest delay) branch, same as 'e',
                          cost=None, # if None - will default to NUM_FINE_STEPS, if 0 - will keep it 
                          quiet = 1):
        """
        Get list of "optimal" per-bit delays for DQSI,dqso and cmda
        always use the same branch
        @param phase phase value, if None - return a list for all phases
        @parame list_branches - return (ordered) list of available branches, not delays. If it is a string starting with E<rr>,
                                return worst errors in ps instead of the data
        @param target - one of "dqsi","dqso", "dqi", "dqo" or "cmda"
        @param b_filter - filter to limit clock-period 'branches',  item or a list/tuple of items,
             consisting of any (or combination) of:
             a)word starting with 'E','B','L'  (E<arly> - branch with smallest delay,
             L<ate> - largest delay, B<best> (lowest error) - no EBL defaults to "early"
             If both Best and Late/Early are present, extra period adds cost*clk_period/NUM_DLY_STEPS
             a1) word starting with 'A' (A<ll>) - return results even if some lines are None
             b) float number - maximal allowed error in ps and
             c) one or several specific branches (signed integers)
             If b_filter is None, earliest (lowest delay) branch will be used
        @param cost TODO: check with multiple overlapping low-error branches. This parameter allows to select between
                    multiple "good" (low-error) branches that will become availble when clock period will be lower than
                    delay range. When selecting lowest error it adds cost for lower/higher delays, such that delay of the
                    full clock period will add/subtract cost/NUM_DLY_STEPS of the period to effective error. With default
                    cost==5 it will "punish" with 1/32 period for using "wrong" period branch 
        @param quiet  reduce output
        @return - a list of delays for a specific phase or None (if none available/match f_filter) or
                  a list of lists of delays/None-s for all phases (if phase is not specified) or
                  a list of period branches (signed integers) for a specific phase/None if list_branches is True or
                  a list of lists/None-s for all phases if phase is None and list_branches is True
        """
         
        """
        #TODO: REMOVE next temporary lines
        self.load_hardcoded_data()
        self.proc_addr_odelay(True, 200.0, 4)
        self.proc_dqsi_phase ('All', 50, 0, 0.0, 200, 3)
        self.proc_dqso_phase ('All', 50, 0, 0.0, 200, 3)
        """
        if cost is None:
            cost=NUM_FINE_STEPS
        return_error=False
        try:
            if list_branches.upper()[0]=='E':
                return_error=True
                list_branches=False
        except:
            pass

        if quiet < 2:
            print ("processing get_delays_for_phase(phase=%s,list_branches=%s,target='%s',b_filter=%s)"%(str(phase),
                                                                                                         str(list_branches),
                                                                                                         str(target),
                                                                                                         str(b_filter)))
        #parse b-filter
        if not isinstance (b_filter, (list,tuple)):
            b_filter=[b_filter]
        periods_set=set()
        highDelay=False
        lowDelay=False
        minError=False
        maxErrPS=0.0
        allGood=True
        for item in b_filter:
            if not item is None:
                if isinstance(item,float):
                    maxErrPS=item
                elif isinstance(item,(int,long,tuple)):
                    periods_set.add(item)
                elif isinstance(item,str) and (len(item)>0) and (item.upper()[0] in "EBLA"):
                    if item.upper()[0] == "L":
                        highDelay=True
                    elif item.upper()[0] == "B":
                        minError=True
                    elif item.upper()[0] == "E":
                        lowDelay=True
                    elif item.upper()[0] == "A":
                        allGood=False
                    else:
                        raise Exception("Unrecognized filter option %s - first letter should be one of 'EBLA'"%(item))
                else:
                        raise Exception("Unrecognized filter item %s - can be string (starting with E,L,B,A) float (max error in ps) or signed integer - number of clock periods"%(item))
        delay_cost=0
        clk_period=1000.0*self.x393_mcntrl_timing.get_dly_steps()['SDCLK_PERIOD'] # 2500.0, # clk_period,
        #Will add to error(ps) -delay_cost(steps) * delay_cost 
        if  lowDelay:
            delay_cost=clk_period*cost/(NUM_DLY_STEPS**2)
        elif highDelay:
            delay_cost=-clk_period*cost/(NUM_DLY_STEPS**2)
        
        if  target.upper() == 'DQI':
            delays=self.adjustment_state['dqi_phase_multi']
            errors=self.adjustment_state['dqi_phase_err']
            common_branches=False
        elif target.upper() == 'DQO':
            delays=self.adjustment_state['dqo_phase_multi']
            errors=self.adjustment_state['dqo_phase_err']
            common_branches=False
        elif  target.upper() == 'DQSI':
            delays=self.adjustment_state['dqsi_phase_multi']
            errors=self.adjustment_state['dqsi_phase_err']
            common_branches=False
        elif target.upper() == 'DQSO':
            delays=self.adjustment_state['dqso_phase_multi']
            errors=self.adjustment_state['dqso_phase_err']
            common_branches=False
        elif target.upper() == 'CMDA':
            delays=self.adjustment_state['addr_odelay']['dlys']
            errors=self.adjustment_state['addr_odelay']['err']
#            print("delays=",delays)
#            print("errors=",errors)
#            print("2:self.adjustment_state['addr_odelay']=",self.adjustment_state['addr_odelay'])                     
            
            common_branches=True
        else:
            raise Exception("Unrecognized mode option, valid are: 'DQSI','DQSO' and CMDA'")
        if common_branches:
            numPhaseSteps= len(delays)
        else:
            numPhaseSteps= len(delays[0])
        def single_phase(phase):
            if common_branches:
                phaseData=delays[phase]
                phaseErrs=errors[phase]
                if quiet <1:
                    print(phase,"--phaseData=",phaseData," ... highDelay=",highDelay," lowDelay=",lowDelay," list_branches=",list_branches)                

#                print("phaseErrs=",phaseErrs)
            else:
                try:
                    phaseData,phaseErrs=self._get_dqs_dly_err(phase,
                                                              delays,
                                                              errors)
                except: # _get_dqs_dly_err ==> None
                    if quiet <1:
                        print("phaseData=None")
                    
                    return None
                if quiet <1:
                    print(phase,"phaseData=",phaseData," ... highDelay=",highDelay," lowDelay=",lowDelay," list_branches=",list_branches)                
                
            if phaseData is None:
                return None
            
#            print ("target=",target," phaseData=",phaseData )
            """
            periods=phaseData.keys()
            
            periods.sort() # can compare tuples (1-st is "more important")
            if maxErrPS:
                for indx,branch in enumerate(periods):
                    if phaseErrs[branch] > maxErrPS:
                        periods.pop(indx)
            if allGood:
                for indx,branch in enumerate(periods):
                    if None in phaseData[branch]:
                        periods.pop(indx)
                        
            for indx,branch in enumerate(periods):  # if all elements are None
                if all(v is None for v in phaseData[branch]): 
                    periods.pop(indx)
            """    
            periods=set(phaseData.keys())
            if maxErrPS:
                for period in periods.copy():
                    if phaseErrs[period] > maxErrPS:
                        periods.remove(period)
            if allGood:
                for period in periods.copy():
                    if None in phaseData[period]:
                        periods.remove(period)
                        
            for period in periods.copy():  # if all elements are None
                if all(v is None for v in phaseData[period]): 
                    periods.remove(period)
                        
            periods=list(periods)
            periods.sort() # can compare tuples (1-st is "more important")

                       
            # useBranch
            # filter results
            if periods_set:
                periods=[p for p in periods if p in periods_set]
            if not periods:
                return None
            if (len(periods) > 1) and minError:
                if delay_cost == 0:
                    """
                    merr=min(phaseErrs[b] for b in periods)
                    for branch in periods: # , e in phaseErrs.items():
                        if phaseErrs[branch] == merr:
                            periods=[branch]
                            break
                    """
                    #just list errors for the periods list
                    eff_errs=[phaseErrs[b] for b in periods]
                else:
                    #calculate "effective errors" by adding scaled (with +/-) average delay for branches
                    eff_errs=[phaseErrs[b]+(delay_cost*sum(d for d in phaseData[b] if not d is None)/sum(1 for d in phaseData[b] if not d is None)) for b in periods]
                periods=[periods[eff_errs.index(min(eff_errs))]]
            #Filter by low/high delays without minError mode
            if len(periods)>1:
                dl0_per=[phaseData[p][0] for p in periods] # only delay for line 0, but with same branch requirement this should be the same for all lines
                if highDelay or lowDelay or not list_branches or return_error: # in list_branches mode - filter by low/high only if requested, for delays use low if not highDelay
                    periods=[periods[dl0_per.index((min,max)[highDelay](dl0_per))]]
            if list_branches: # move to the almost very end, so filters apply
                return periods
            elif return_error:
                return phaseErrs[periods[0]]
            else:
                return phaseData[periods[0]]
            
        #main method body
        if not phase is None:
            rslt= single_phase(phase)
            if quiet < 3:
                print ("%d %s"%(phase,str(rslt)))
        else:
            rslt=[]
            for phase in range(numPhaseSteps):
                rslt.append(single_phase(phase))
            if quiet < 3:
                for phase, v in enumerate(rslt):
                    print ("%d %s"%(phase,str(v)))
        return rslt    
            
    def set_delays(self,
                   phase,
                   filter_cmda=None, # may be special case: 'S<safe_phase_as_float_number>
                   filter_dqsi=None,
                   filter_dqi= None,
                   filter_dqso=None,
                   filter_dqo= None,
                   cost=None,
                   refresh=True,
                   forgive_missing=False,
                   maxPhaseErrorsPS=None,
                   quiet=3):
        """
        Set phase and all relevant delays (ones with non None filters)
        @param phase value to calculate delays for or None to use globally set optimal_phase
        @param filter_cmda  filter clock period branches for command and addresses. See documentation for
        get_delays_for_phase() - b_filter
        @param filter_dqsi filter for DQS output delays
        @param filter_dqi  filter for DQS output delays
        @param filter_dqso filter for DQS output delays
        @param filter_dqo  filter for DQS output delays,
        @param refresh - turn refresh OFF before and ON after changing the delays and phase
        @param forgive_missing do not raise exceptions on missing data - just skip that delay group
        @param maxPhaseErrorsPS - if present, specifies maximal phase errors (in ps) for cmda, dqsi and dqso (each can be None)
        @param quiet Reduce output
        @return used delays dictionary on success, None on failure
        raises Exception() if any delays with non-None filters miss required data
        """
        if quiet < 2:
            print ("set_delays (",
                   phase,',',
                   filter_cmda,',', 
                   filter_dqsi, ',', 
                   filter_dqi, ',', 
                   filter_dqso, ',', 
                   filter_dqo, ',', 
                   cost, ',', 
                   refresh, ',', 
                   forgive_missing, ',',
                   maxPhaseErrorsPS,',',
                   quiet,")")
        if phase is None:
            try:
                phase= self.adjustment_state['optimal_phase']
            except:
                raise Exception("Phase value is not provided and global optimal phase is not defined")
        num_addr=vrlg.ADDRESS_NUMBER
        num_banks=3
        dly_steps=self.x393_mcntrl_timing.get_dly_steps()
        numPhaseSteps= int(dly_steps['SDCLK_PERIOD']/dly_steps['PHASE_STEP']+0.5)
        phase= phase % numPhaseSteps # valid for negative also, numPhaseSteps should be <=128 (now it is 112)

        delays=self.get_all_delays(phase=phase,
                                   filter_cmda=     filter_cmda, # may be special case: 'S<safe_phase_as_float_number>
                                   filter_dqsi=     filter_dqsi,
                                   filter_dqi=      filter_dqi,
                                   filter_dqso=     filter_dqso,
                                   filter_dqo=      filter_dqo,
                                   cost=            cost,
                                   forgive_missing= forgive_missing,
                                   maxPhaseErrorsPS=maxPhaseErrorsPS,
                                   quiet=           quiet)
        if delays is None: #May also be an empty dictionary? 
            return None
        filters=dict(zip(SIG_LIST,[filter_cmda,filter_dqsi,filter_dqi,filter_dqso,filter_dqo]))
        if quiet < 3:
            print ("Going to set:")
            print ("phase=",phase)
            name_len=max(len(k) for k in SIG_LIST if filters[k] is not None)
            frmt="%%%ds = %%s"%(name_len+3)
            for k in SIG_LIST:
                if not filters[k] is None:
                    print(frmt%(k+" = "+" "*(name_len-len(k)), str(delays[k]))) 
            print ('Memory refresh will %sbe controlled'%(('NOT ','')[refresh]))
            
        if refresh:
            self.x393_axi_tasks.enable_refresh(0)
        self.x393_mcntrl_timing.axi_set_phase(phase,quiet=quiet)
        if CMDA_KEY in delays:
            if isinstance(delays[CMDA_KEY],(list,tuple)):
                self.x393_mcntrl_timing.axi_set_address_odelay(combine_delay(delays[CMDA_KEY][:num_addr]),quiet=quiet)
                self.x393_mcntrl_timing.axi_set_bank_odelay   (combine_delay(delays[CMDA_KEY][num_addr:num_addr+num_banks]),quiet=quiet)
                cmd_dly_data=delays[CMDA_KEY][num_addr+num_banks:]
                while len(cmd_dly_data) < 5:
                    cmd_dly_data.append(cmd_dly_data[-1]) # repeat last element (average address/command delay)
                self.x393_mcntrl_timing.axi_set_cmd_odelay    (combine_delay(cmd_dly_data),quiet=quiet) # for now - same delay TODO: upgrade!
            else: # only data from 'cmda_bspe' is available - use it for all
                self.x393_mcntrl_timing.axi_set_cmda_odelay(combine_delay(delays[CMDA_KEY]),quiet=quiet)
        if refresh:
            self.x393_axi_tasks.enable_refresh(1)
        if DQSI_KEY in delays:
            self.x393_mcntrl_timing.axi_set_dqs_idelay(combine_delay(delays[DQSI_KEY]),quiet=quiet)
        if DQI_KEY in delays:
            self.x393_mcntrl_timing.axi_set_dq_idelay(combine_delay(delays[DQI_KEY]),quiet=quiet)
        if DQSO_KEY in delays:
            self.x393_mcntrl_timing.axi_set_dqs_odelay(combine_delay(delays[DQSO_KEY]),quiet=quiet)
        if DQO_KEY in delays:
            self.x393_mcntrl_timing.axi_set_dq_odelay(combine_delay(delays[DQO_KEY]),quiet=quiet)
        return True
        

    def get_all_delays(self,
                        phase,
                        filter_cmda=None, # may be special case: 'S<safe_phase_as_float_number>
                        filter_dqsi=None,
                        filter_dqi= None,
                        filter_dqso=None,
                        filter_dqo= None,
                        forgive_missing=False,
                        cost=None,
                        maxPhaseErrorsPS=None,
                        quiet=3):
        """
        Calculate dictionary of delays for specific phase. Only Non-None filters will generate items in the dictionary
        @param phase phase value to calculate delays for or None to calculate a list for all phases
        @param filter_cmda  filter clock period branches for command and addresses. See documentation for
        get_delays_for_phase() - b_filter
        @param filter_dqsi filter for DQS output delays
        @param filter_dqi  filter for DQS output delays
        @param filter_dqso filter for DQS output delays
        @param filter_dqo  filter for DQS output delays,
        @param forgive_missing do not raise exceptions on missing data - just skip that delay group
        @param cost - cost of switching to a higher(lower) delay branch as a fraction of a period
        @param maxPhaseErrorsPS - if present, specifies maximal phase errors (in ps) for cmda, dqsi and dqso (each can be None)

        @param quiet Reduce output
        @return None if not possible for at east one non-None filter, otherwise a dictionary of delay to set.
                Each value is either number set to all or a tuple/list (to set individual values)
        raises Exception if required data is missing
        """
        filters=dict(zip(SIG_LIST,[filter_cmda,filter_dqsi,filter_dqi,filter_dqso,filter_dqo]))
        dly_steps=self.x393_mcntrl_timing.get_dly_steps()
        numPhaseSteps= int(dly_steps['SDCLK_PERIOD']/dly_steps['PHASE_STEP']+0.5)
        phaseStep=1000.0*dly_steps['PHASE_STEP']
        if quiet < 3:
            print ("get_all_delays(): maxPhaseErrorsPS=",maxPhaseErrorsPS)
#            assert (not maxPhaseErrorsPS is None)
        if phase is None:
            all_delays=[]
            for phase in range(numPhaseSteps):
                all_delays.append(self.get_all_delays(phase=phase,
                                                      filter_cmda =     filter_cmda,
                                                      filter_dqsi =     filter_dqsi,
                                                      filter_dqi =      filter_dqi,
                                                      filter_dqso =     filter_dqso,
                                                      filter_dqo =      filter_dqo,
                                                      forgive_missing = forgive_missing,
                                                      cost=             cost,
                                                      maxPhaseErrorsPS=maxPhaseErrorsPS,
                                                      quiet=            quiet))
            return all_delays
            
            
        delays={}
        phaseTolerances={}
        if quiet < 2:                     
            print("maxPhaseErrorsPS=",maxPhaseErrorsPS)
        if maxPhaseErrorsPS:
            if isinstance (maxPhaseErrorsPS, (float, int,long)):
                maxPhaseErrorsPS=(maxPhaseErrorsPS,maxPhaseErrorsPS,maxPhaseErrorsPS)
            if maxPhaseErrorsPS[0]:
                phaseTolerances[CMDA_KEY]= int(round(maxPhaseErrorsPS[0]/phaseStep))
            if maxPhaseErrorsPS[1]:
                phaseTolerances[DQSI_KEY]= int(round(maxPhaseErrorsPS[1]/phaseStep))
            if maxPhaseErrorsPS[2]:
                phaseTolerances[DQSO_KEY]= int(round(maxPhaseErrorsPS[2]/phaseStep))
            if (quiet <2):
                print ("phaseTolerances=",phaseTolerances)
        all_good=True    
        for k in SIG_LIST: #CMDA first, DQS before DQ
            if  not filters[k] is None:
                #special case for cmda, and if self.adjustment_state['addr_odelay'] is not available
                if (k == CMDA_KEY) and ((not 'addr_odelay' in self.adjustment_state) or
                                        (isinstance (filter_cmda,str) and (len(filter_cmda)>1) and (filter_cmda.upper()[0]=='S'))):
                    # not processing phaseTolerances in this mode
                    if quiet < 3:                     
                        print ("\n------ processing '%s' using self.adjustment_state['cmda_bspe'], filter= %s"%(k,str(filters[k])))
                    try:
                        cmda_bspe=self.adjustment_state['cmda_bspe']
                    except:
                        raise Exception ('Data for filter_cmda is not available (self.adjustment_state["cmda_bspe"]')
                    try:
                        safe_phase=float(filter_cmda.upper()[1:])
                        if quiet <2:
                            print ("using safe phase=",safe_phase)
                    except:
                        safe_phase=0
                    if safe_phase >=0.5:
                        print ("Invalid 'safe range' (safe_phase). It is measured in clock cycles and should be < 0.5")
                        safe_phase=0
                    if safe_phase and (not cmda_bspe[phase]['zerr'] is None) and (cmda_bspe[phase]['zerr']< 0.5-safe_phase):
                        delays[k]=0 # set to minimal delay (==0)
                    else:
                        delays[k]=cmda_bspe[phase]['ldly']
                else:
                    if quiet < 3:                     
                        print ("\n------ processing '%s', filter= %s"%(k,str(filters[k])))
                    if forgive_missing:
                        try:
                            delays[k]=self.get_delays_for_phase(phase =       phase,
                                                                list_branches=False, # just get one set of filtered delay
                                                                target=       k,
                                                                b_filter=     filters[k],
                                                                cost=         cost,
                                                                quiet =       quiet+2)
                        except:
                            pass
                    else:
                        delays[k]=self.get_delays_for_phase(phase =       phase,
                                                            list_branches=False, # just get one set of filtered delay
                                                            target=       k,
                                                            b_filter=     filters[k],
                                                            cost=         cost,
                                                            quiet =       quiet+2)
                    
                if delays[k] is None:
                    if quiet < 3:                     
                        print ("delays[%s]=%s,phaseTolerances=%s"%(k,str(delays[k]),str(phaseTolerances)))
                    if phaseTolerances:
                        all_good=False
                    else:
                        if quiet < 3:                     
                            print ("%s: return None"%(k))
                        return None
        if not all_good: # try to fix - see if the solutions exist for slightly different phases
            if quiet < 3:                     
                print ("phase= %d, delays= %s"%(phase,str(delays)))

            for pair in ((CMDA_KEY,CMDA_KEY,),(DQSI_KEY,DQI_KEY),(DQSO_KEY,DQO_KEY)): # will do some double work for CMDA_KEY
                if (pair[0] in phaseTolerances) and phaseTolerances[pair[0]] and (pair[0] in delays) and (pair[1] in delays): # so not to process forgive_missing again
                    if quiet < 3:                     
                        print ("pair= ",pair)
                    
                    if (not (delays[pair[0]]) is None) and (not (delays[pair[1]]) is None):
                        continue #nothing to fix for this pair
                    phase_var=1
                    while abs(phase_var) <= phaseTolerances[pair[0]]:
                        other_phase=(phase+phase_var) % numPhaseSteps
                        if quiet < 2:                     
                            print ("phase_var=%d, other_phase=%d"%(phase_var,other_phase))
                        
                        dlys=[]
                        dlys.append(self.get_delays_for_phase(phase =     other_phase,
                                                            list_branches=False, # just get one set of filtered delay
                                                            target=       pair[0],
                                                            b_filter=     filters[pair[0]],
                                                            cost=         cost,
                                                            quiet =       quiet+2))
                        dlys.append(self.get_delays_for_phase(phase =      other_phase,
                                                            list_branches=False, # just get one set of filtered delay
                                                            target=       pair[1],
                                                            b_filter=     filters[pair[1]],
                                                            cost=         cost,
                                                            quiet =       quiet+2))
                        if quiet < 2:                     
                            print ("dlys=",dlys)
                        if not None in dlys:
                            if quiet <3:
                                print ("Found replacement phase=%d (for %d) for the signal pair:%s"%(other_phase,phase,str(pair)))
                            delays[pair[0]]=dlys[0]
                            delays[pair[1]]=dlys[1]
                            break
                        phase_var=-phase_var
                        if phase_var > 0:
                            phase_var += +1
            # See if there are still some None in the delays
            if None in delays:
                if quiet <2:
                    print ("Some delays are still missing for phase %d :%s"%(phase,str(delays)))
        return delays
    
    def show_all_delays(self,
                        filter_variants = None,
                        filter_cmda =    'A',#None,
                        filter_dqsi =    'A',#None,
                        filter_dqi =     'A',#None,
                        filter_dqso =    'A',#None,
                        filter_dqo =     'A',#None,
                        quiet =          3):
        """
        Print all optionally filtered delays, the results can be copied to a spreadsheet program to create graph
        @param filter_variants optional list of 3-tuples (cmda_variant, (dqso_variant,dqo-dqso), (dqsi_variant,dqi-dqsi))
               Alternatively if this parameter is a string (currently any), only phase values that have all signals valid
               will be shown 
        @param filter_cmda  filter clock period branches for command and addresses. See documentation for
        get_delays_for_phase() - b_filter
        @param filter_dqsi filter for DQS output delays
        @param filter_dqi  filter for DQS output delays
        @param filter_dqso filter for DQS output delays
        @param filter_dqo  filter for DQS output delays,
        @param quiet Reduce output
        """
        """
        required_keys=('addr_odelay',
                       'dqi_phase_multi',
                       'dqi_phase_err',
                       'dqo_phase_multi',
                       'dqo_phase_err',
                       'dqsi_phase_multi',
                       'dqsi_phase_err',
                       'dqso_phase_multi',
                       'dqso_phase_err')
        """
        #temporarily:
#        self.load_mcntrl('dbg/x393_mcntrl.pickle')
        if quiet < 5:
            print("\n\nCopy the table below to a spreadsheet program to plot graphs)")
            print("show_all_delays(",
                  filter_variants,",",
                  filter_cmda,",",
                  filter_dqsi,",",
                  filter_dqi,",",
                  filter_dqso,",",
                  filter_dqo ,",",
                  quiet,")")

        all_groups_valid_only=False
        if (isinstance(filter_variants,str)) : # currently - any string means "keep only phases that have all groups valid)
            all_groups_valid_only=True
            filter_variants=None

        tSDQS=1000.0*self.x393_mcntrl_timing.get_dly_steps()['DLY_STEP']/NUM_FINE_STEPS
        filters=dict(zip(SIG_LIST,[filter_cmda,filter_dqsi,filter_dqi,filter_dqso,filter_dqo]))
        periods_phase={}
        periods_all={}
        for k in SIG_LIST:
            if not filters[k] is None:
                if quiet < 2:                     
                    print ("\n===== processing '%s', filter= %s"%(k,str(filters[k])))
                periods_phase[k]=self.get_delays_for_phase(phase =       None,
                                                           list_branches=True,
                                                           target=k,
                                                           b_filter=filters[k],
                                                           #cost=NUM_FINE_STEPS,
                                                           quiet = quiet+1)
    #                                                       quiet = quiet+0)
#        numPhases=len(periods_phase[CMDA_KEY])
        try:
            numPhases=len(periods_phase[periods_phase.keys()[0]])
        except:
            print ("show_all_delays(): Nothing selected, exiting")
            return
        #Remove DQI and DQO branches that are referenced to non-existing (filtered out) DQSI/DQI
        for phase in range (numPhases):# ,cmda,dqso,dqo, in zip(range(numPhases),cmda_vars,dqso_vars,dqo_vars):
            if (DQI_KEY in periods_phase) and (DQSI_KEY in periods_phase):
                fl=[]
                if periods_phase[DQI_KEY][phase] is not None:
                    for variant in periods_phase[DQI_KEY][phase]:
                        if (not periods_phase[DQSI_KEY][phase] is None) and (variant[0] in periods_phase[DQSI_KEY][phase]):
                            fl.append(variant)
                    if fl:
                        periods_phase[DQI_KEY][phase]=fl
                    else:
                        periods_phase[DQI_KEY][phase]=None
                            
            if (DQO_KEY in periods_phase) and (DQSO_KEY in periods_phase):
                if periods_phase[DQO_KEY][phase] is not None:
                    fl=[]
                    for variant in periods_phase[DQO_KEY][phase]:
                        if (not periods_phase[DQSO_KEY][phase] is None) and (variant[0] in periods_phase[DQSO_KEY][phase]):
                            fl.append(variant)
                    if fl:
                        periods_phase[DQO_KEY][phase]=fl
                    else:
                        periods_phase[DQO_KEY][phase]=None
        if quiet < 2:                     
            print ("all_groups_valid_only=",all_groups_valid_only)
        if all_groups_valid_only:
            for phase in range (numPhases):
                for k in periods_phase:
                    if periods_phase[k][phase] is None:
                        for k in periods_phase:
                            periods_phase[k][phase]=None
                        break
                        
                        
        if quiet < 2:
            print("===== Filtered periods: =====")
            for phase in range (numPhases):
                print ("phase=%d"%(phase),end=" ")
                for k in periods_phase:
                    print ("'%s':%s"%(k,str(periods_phase[k][phase])),end=" ")
                print()    
        
        
        if not filter_variants is None:
            strict= not ('all' in filter_variants)
            if quiet < 3:
                print ("filter_variants=",filter_variants)                     

            for phase in range (numPhases):# ,cmda,dqso,dqo, in zip(range(numPhases),cmda_vars,dqso_vars,dqo_vars):
                #build variants for each group that are used in at least one permitted combination of cmda, dqso, dqo, dqsi, dqi
                # 'try' makes sure that all groups are not None (in that case just skip that phase value)
                key_vars={}
                for k in SIG_LIST:
                    key_vars[k]=set()
                try:
                    for cmda in periods_phase[CMDA_KEY][phase]:
                        for dqo in  periods_phase[DQO_KEY][phase]:
                            for dqi in  periods_phase[DQI_KEY][phase]:
                                if quiet < 3:
                                    print("phase=%d, (cmda,dqo,dqi)=%s"%(phase,str((cmda,dqo,dqi))))
                                if (((cmda,dqo,dqi) in filter_variants) and 
                                    (dqo[0] in periods_phase[DQSO_KEY][phase]) and
                                    (dqi[0] in periods_phase[DQSI_KEY][phase])):
                                    for i,k in enumerate(SIG_LIST):
                                        key_vars[k].add((cmda,dqi[0],dqi,dqo[0],dqo)[i]) #careful with the order
                    if quiet < 2:
                        print("phase=%d, key_vars=%s"%(phase,str(key_vars))) # OK
                    for k in SIG_LIST:
                        for variant in periods_phase[k][phase]:
                            if not variant in  key_vars[k]:
                                if quiet < 3:
                                    print ("phase=%d: variant %s is not in %s for %s, key_vars=%s . OK in when filtered by 'filter_variants'"%(phase,
                                                                                                                                               variant,
                                                                                                                                               str(key_vars[k]),
                                                                                                                                               str(k),
                                                                                                                                               str(key_vars)))
                                periods_phase[k][phase].pop(variant) # remove variants that do not fit in one of the combinations in filter_variants
                        if quiet <2:
                            print("periods_phase[%s][phase]=%s, strict=%s"%(str(k),str(periods_phase[k][phase]),str(strict)))
                        assert (periods_phase[k][phase] or (not strict))
                except:
                    for k in SIG_LIST:
                        if quiet <2:
                            print("except %s"%str(k))
                        periods_phase[k][phase]=None
            if quiet <2:
                for phase in range (numPhases):
                    print ("phase= %d"%(phase), end=" ")
                    for k in SIG_LIST:
                        print ("%s"%(periods_phase[k][phase]), end=" ")
                    print()
        for k in SIG_LIST:
            if k in periods_phase:
                periods_all[k]=set()
                for lp in periods_phase[k]:
                    try:
                        for p in lp:
                            periods_all[k].add(p)
                    except:
                        pass # None
                periods_all[k]=list(periods_all[k])
                periods_all[k].sort()    
        if quiet <3:                     
            print ("periods_all=",periods_all)
        # Print the header
        num_addr=15
        num_banks=3
        num_lines=16
        num_cmda=num_addr+num_banks+3+1
        num_lanes=num_lines//8
        positions={CMDA_KEY:num_cmda,DQSI_KEY:num_lanes,DQI_KEY:num_lines,DQSO_KEY:num_lanes,DQO_KEY:num_lines}
        
        print ("phase",end=" ")
        if CMDA_KEY in periods_all:
            for period in periods_all[CMDA_KEY]:
                for i in range(num_addr):
                    print("A%d_%d"%(i,period),end=" ")
                for i in range(num_banks):
                    print("BA%d_%d"%(i,period),end=" ")
                print ("WE_%d RAS_%d CAS_%d AVG_%d"%(period,period,period,period), end=" ") # AVG - average for address,  banks, RCW
        if DQSI_KEY in periods_all:
            for period in periods_all[DQSI_KEY]:
                for lane in range(num_lanes):
                    print("DQSI_%d_%d"%(lane,period),end=" ")
        if DQI_KEY in periods_all:
            for period in periods_all[DQI_KEY]:
                for line in range(num_lines):
                    print("DQI_%d_%d/%d"%(line,period[0],period[1]),end=" ")
        if DQSO_KEY in periods_all:
            for period in periods_all[DQSO_KEY]:
                for lane in range(num_lanes):
                    print("DQSO_%d_%d"%(lane,period),end=" ")
        if DQO_KEY in periods_all:
            for period in periods_all[DQO_KEY]:
                for line in range(num_lines):
                    print("DQO_%d_%d/%d"%(line,period[0],period[1]),end=" ")
                
        #TODO - add errors print
#        """       
        if CMDA_KEY in periods_all:
            for period in periods_all[CMDA_KEY]:
                print("ERR_CMDA_%d"%(period),end=" ")
        if DQSI_KEY in periods_all:
            for period in periods_all[DQSI_KEY]:
                print("ERR_DQSI_%d"%(period),end=" ")
        if DQSO_KEY in periods_all:
            for period in periods_all[DQSO_KEY]:
                print("ERR_DQSO_%d"%(period),end=" ")
#        """
        print()
        #print body
        for phase in range(numPhases):
            print ("%d"%(phase),end=" ")
            for k in SIG_LIST:
                if k in periods_all:               
                    for period in periods_all[k]:
                        if (not periods_phase[k][phase] is None) and (period in periods_phase[k][phase]):
    #                        print("<<",k,"::",periods_phase[k][phase],":",period,">>>")
                            data_group=self.get_delays_for_phase(phase = phase,
                                                            list_branches=False,
                                                            target=k,
                                                            b_filter=[period,"A"],
                                                           #cost=NUM_FINE_STEPS, only used with 'B'
                                                            quiet = quiet+2)
                        else:
                            data_group=None
                        for i in range(positions[k]):
                            try:
                                print("%d"%(data_group[i]), end=" ")
                            except:
                                print("?",end=" ")

            for k in [CMDA_KEY,DQSI_KEY,DQSO_KEY]:               
                if k in periods_all:               
                    for period in periods_all[k]:
                        if (not periods_phase[k][phase] is None) and (period in periods_phase[k][phase]):
                            err_ps=self.get_delays_for_phase(phase = phase,
                                                         list_branches='Err',
                                                         target=k,
                                                         b_filter=[period,"A"],
                                                         #cost=NUM_FINE_STEPS, only used with 'B'
                                                         quiet = quiet+2)
                        else:
                            err_ps=None
                        try:
                            print("%.1f"%(err_ps/tSDQS), end=" ")
                        except:
                            print("?",end=" ")
                            
            print()
            
                
            
            
            
        
        
#numPhaseSteps= len(delays[0])        
                

    def set_phase_with_refresh(self, # check result for not None
                               phase,
                               quiet=1):
        """
        Set specified phase and matching cmda_odelay while temporarily turning off refresh
        @param phase phase to set, signed short
        @param quiet reduce output 
        @return cmda_odelay linear value or None if there is no valid cmda output delay for this phase
        """
        if not "cmda_bspe" in self.adjustment_state:
            raise Exception ("No cmda_odelay data is available. 'adjust_cmda_odelay 0 1 0.1 3' command should run first.")
        dly_steps=self.x393_mcntrl_timing.get_dly_steps()
        numPhaseSteps= int(dly_steps['SDCLK_PERIOD']/dly_steps['PHASE_STEP']+0.5)
        cmda_odly_data=self.adjustment_state['cmda_bspe'][phase % numPhaseSteps]
        if (not cmda_odly_data): # phase is invalid for CMDA
            return None
        cmda_odly_lin=cmda_odly_data['ldly']
        self.x393_axi_tasks.enable_refresh(0)
        self.x393_mcntrl_timing.axi_set_phase(phase,quiet=quiet)
        self.x393_mcntrl_timing.axi_set_cmda_odelay(combine_delay(cmda_odly_lin),quiet=quiet)
        self.x393_axi_tasks.enable_refresh(1)
        return cmda_odly_lin

    def adjust_cmda_odelay(self,
                           start_phase=0,
                           reinits=1, #higher the number - more re-inits are used (0 - only where absolutely necessary
                           max_phase_err=0.1,
                           quiet=1
                           ):
        """
        Find CMDA output delay for each phase value using linear interpolation for available results
        Use write levelling mode (refresh off) and A7 (that makes it write levelling or not).
        Only A7 is subject to marginal timing, other signals are kept safe. But accidentally it still can hit
        wrong timing - in that case memory is reset and re-initialized
        Sets global parameters, including self.adjustment_state['cmda_bspe']
        @param start_phase initial phase to start measuremts (non-0 only for debugging dependencies)
        @param reinits higher the number - more re-inits are used (0 - only where absolutely necessary)
        @param max_phase_err maximal phase error for command and address line as a fraction of SDCLK period to consider
        @param quiet reduce output
        """
        nbursts=16
        start_phase &= 0xff
        if start_phase >=128:
            start_phase -= 256 # -128..+127
        recover_cmda_dly_step=0x20 # subtract/add from cmda_odelay (hardware!!!) and retry (same as 20 decimal)
        max_lin_dly=NUM_DLY_STEPS-1
        wlev_address_bit=7
        wlev_max_bad=0.01 # <= OK, > bad
        def phase_step(phase,cmda_dly):
            """
            Find marginal delay for address/comand lines for particular
            clock pahse
            Raises exception if failed to get write levelling data even after
            changing cmda delay and restarting memory device
            Returns a tuple of the current cmda_odelay (hardware) and a marginal one for a7
            """
            cmda_dly_lin=split_delay(cmda_dly)
            self.x393_mcntrl_timing.axi_set_phase(phase,quiet=quiet)
            self.x393_mcntrl_timing.axi_set_cmda_odelay(cmda_dly,quiet=quiet)
            wlev_rslt=self.x393_pio_sequences.write_levelling(1, nbursts, quiet+1)
            if wlev_rslt[2]>wlev_max_bad: # should be 0, if not - Try to recover
                if quiet <4:
                    print("*** FAILED to read data in write levelling mode, restarting memory device")
                    print("    Retrying with the same cmda_odelay value = 0x%x"%cmda_dly)
                self.x393_pio_sequences.restart_ddr3()
                wlev_rslt=self.x393_pio_sequences.write_levelling(1,nbursts, quiet)
                if wlev_rslt[2]>wlev_max_bad: # should be 0, if not - change delay and restart memory
                    cmda_dly_old=cmda_dly
                    if cmda_dly >=recover_cmda_dly_step:
                        cmda_dly -= recover_cmda_dly_step
                    else:
                        cmda_dly += recover_cmda_dly_step
                    if quiet <4:
                        print("*** FAILED to read data in write levelling mode, restarting memory device")
                        print("    old cmda_odelay= 0x%x, new cmda_odelay =0x%x"%(cmda_dly_old,cmda_dly))
                    self.x393_mcntrl_timing.axi_set_cmda_odelay(cmda_dly,quiet=quiet)
                    self.x393_pio_sequences.restart_ddr3()
                    wlev_rslt=self.x393_pio_sequences.write_levelling(1, nbursts, quiet)
                    if wlev_rslt[2]>wlev_max_bad: # should be 0, if not - change delay and restart memory
                        raise Exception("Failed to read in write levelling mode after modifying cmda_odelay, aborting")
                    
# Try twice step before giving up (was not needed so far)                    
            d_high=max_lin_dly
            self.x393_mcntrl_timing.axi_set_address_odelay(
                                                           combine_delay(d_high),
                                                           wlev_address_bit,
                                                           quiet=quiet)
            wlev_rslt=self.x393_pio_sequences.write_levelling(1, nbursts, quiet+1)
            if not wlev_rslt[2]>wlev_max_bad:
                return  (split_delay(cmda_dly),-1) # even maximal delay is not enough to make rising sdclk separate command from A7
            # find marginal value of a7 delay to spoil write levelling mode
            d_high=max_lin_dly
            d_low=cmda_dly_lin
            while d_high > d_low:
                dly= (d_high + d_low)//2
                self.x393_mcntrl_timing.axi_set_address_odelay(combine_delay(dly),wlev_address_bit,quiet=quiet)
                wlev_rslt=self.x393_pio_sequences.write_levelling(1, nbursts, quiet+1)
                if wlev_rslt[2] > wlev_max_bad:
                    d_high=dly
                else:
                    if d_low == dly:
                        break
                    d_low=dly
            self.x393_mcntrl_timing.axi_set_cmda_odelay(cmda_dly,quiet=quiet)
            return (split_delay(cmda_dly),d_low)
               
        dly_steps=self.x393_mcntrl_timing.get_dly_steps()
        if quiet<1:
            print (dly_steps)
        numPhaseSteps= int(dly_steps['SDCLK_PERIOD']/dly_steps['PHASE_STEP']+0.5)
        if (start_phase+numPhaseSteps)>128:
            old_start_phase=start_phase
            while (start_phase+numPhaseSteps)>128:
                start_phase -= numPhaseSteps
            print("Selected scan phase range (%d..%d) does not fit into -128..+127, changing it to %d..%d)"%
                  (old_start_phase,old_start_phase+numPhaseSteps-1,start_phase,start_phase+numPhaseSteps-1))
#start_phase
        cmda_marg_dly=[None]*numPhaseSteps
        cmda_dly=0
        safe_early=split_delay(recover_cmda_dly_step)/2
#        print ("safe_early=%d(0x%x), recover_cmda_dly_step=%d(0x%x)"%(safe_early,safe_early,recover_cmda_dly_step,recover_cmda_dly_step))
        if reinits>0:
            self.x393_pio_sequences.restart_ddr3()
        else:
            self.x393_axi_tasks.enable_refresh(0) # if not init, at least turn refresh off!

        for phase in range(start_phase,start_phase+numPhaseSteps):
            if quiet <3:
                print ("%d:"%(phase),end=" ")
                sys.stdout.flush()
            elif quiet < 5:
                print (".",end="")
                sys.stdout.flush()
            phase_mod=phase % numPhaseSteps
            dlys= phase_step(phase,cmda_dly)
            cmda_marg_dly[phase_mod]=dlys # [1] # Marginal delay or -1
            cmda_dly = combine_delay(dlys[0]) # update if it was modified during recover
            # See if cmda_odelay is dangerously close - increase it (and re-init?)
            if dlys[1]<0:
                if quiet <3:
                    print ("X",end=" ")
                    sys.stdout.flush()
                elif quiet < 5:
                    print (".",end="")
                    sys.stdout.flush()
                if reinits > 1: #re-init each time failed to find delay
                    if quiet <3:
                        print ("\nFailed to find marginal odelay for A7 - re-initializing DDR3 with odelay=0x%x",cmda_dly)
                    self.x393_mcntrl_timing.axi_set_cmda_odelay(cmda_dly,quiet=quiet)
                    self.x393_pio_sequences.restart_ddr3()
            else:
                if quiet <3:
                    print ("%d"%dlys[1],end=" ")
                    sys.stdout.flush()
                elif quiet < 5:
                    print (".",end="")
                    sys.stdout.flush()
                lin_dly=split_delay(cmda_dly)
                if (dlys[1]-lin_dly) < safe_early:
                    if (lin_dly > 0):
                        lin_dly=max(0,lin_dly-2*safe_early)
                if (dlys[1]-lin_dly) < safe_early:
                    lin_dly=min(max_lin_dly,lin_dly+2*safe_early) # or just add safe_early to dlys[1]?
                
                if lin_dly != split_delay(cmda_dly):   
                    cmda_dly=combine_delay(lin_dly)
                    self.x393_mcntrl_timing.axi_set_cmda_odelay(cmda_dly,quiet=quiet)
                    if reinits > 0: #re-init each time failed to find delay
                        if quiet <3:
                            print ("\nMeasured marginal delay for A7 is too close to cmda_odelay,re-initializing DDR3 with odelay=0x%x"%cmda_dly)
                        self.x393_pio_sequences.restart_ddr3()
            

        if quiet <2:
            for i,d in enumerate(cmda_marg_dly):
                print ("%d %d %d"%(i, d[0], d[1]))
        elif quiet < 5:
                print ()
        #find the largest positive step of cmda_marg_dly while cyclically increasing phase
        numValid=0
        for i,d in enumerate(cmda_marg_dly):
            if d[1]>0:
                numValid += 1
        if numValid < 2:
            raise Exception("Too few points with measured marginal CMDA odelay: %d"%numValid)
        maxPosSep=0
        firstIndex=None
        for i,d in enumerate(cmda_marg_dly):
            if d[1]>0:
                for j in range(1,numPhaseSteps):
                    d1=cmda_marg_dly[(i + j) % numPhaseSteps][1]
                    if d1 >= 0: # valid data
                        if (d1 - d[1]) > maxPosSep:
                            maxPosSep = d1 - d[1]
                            firstIndex=(i + j) % numPhaseSteps
                        break;
        #now data from  firstIndex to (firstIndex+numPhaseSteps)%numPhaseSteps is ~monotonic - apply linear approximation
        if quiet <2:
            print ("firstIndex=%d"%(firstIndex))
        
        S0=0
        SX=0
        SY=0
        SX2=0
        SXY=0
        for x in range(numPhaseSteps):
            y=cmda_marg_dly[(x+firstIndex) % numPhaseSteps][1]
            if y>=0:
                y+=0.5
                S0+=1
                SX+=x
                SY+=y
                SX2+=x*x
                SXY+=x*y
#            print("x=%f, index=%d, y=%f, S0=%f, SX=%f, SY=%f, SX2=%f, SXY=%f"%(x, (x+firstIndex) % numPhaseSteps, y, S0, SX, SY, SX2, SXY))
        a = (SXY*S0 - SY*SX) / (SX2*S0 - SX*SX)
        b = (SY*SX2 - SXY*SX) / (SX2*S0 - SX*SX)
        if quiet < 2:
            print ("a=%f, b=%f"%(a,b))
        # fine delay corrections
        fineCorr= [0.0]*5
        fineCorrN=[0]*5
        for x in range(numPhaseSteps):
            y=cmda_marg_dly[(x+firstIndex) % numPhaseSteps][1]
            if (y>0):
                i=y % 5
                y+=0.5
                diff=y- (a * x + b)
                fineCorr[i]  += diff
                fineCorrN[i] += 1
        for i in range(5):
            if fineCorrN[i]>0:
                fineCorr[i]/=fineCorrN[i]
        if (quiet <2):
            print ("fineCorr = %s"%str(fineCorr))
            
        variantStep=-a*numPhaseSteps #how much b changes when moving over the full SDCLK period
        if (quiet <2):
            print ("Delay matching the full SDCLK period = %f"%(variantStep))
        b-=a*firstIndex # recalculate b for phase=0
        b_period=0
        if (quiet <2):
            print ("a=%f, b=%f"%(a,b))
        #Make b fit into 0..max_lin_dly range
        while (b>max_lin_dly):
            b-=variantStep
            b_period-=1
        while (b<0):
            b+=variantStep # can end up having b>max_lin_dly - if the phase adjust by delay is lower than full period
            b_period+=1
        if (quiet <2):
            print ("a=%f, b=%f, b_period=%d"%(a,b,b_period))

        # Find best minimal delay (with higher SDCLK frequency delay range can exceed the period and there could
        # be more than one solution
        bestSolPerErr=[] #list ot tuples, each containing(best cmda_odelay,number of added periods,error)  
        max_dly_err=abs(a)*max_phase_err*numPhaseSteps # maximal allowed delay error (in 160-step scale)
        if (quiet <2):
            print("Max dly error=%f"%(max_dly_err))
        for phase in range (numPhaseSteps):
            periods=0 # b_period
            y=a*phase+b
            y0=y
            #find the lowest approximate solution to consider
            if y0 > (-max_dly_err):
                while (y0 >= (variantStep-max_dly_err)):
                    y0 -= variantStep
                    periods -= 1
            else:
                while (y0<(-max_dly_err)):
                    y0 += variantStep
                    periods += 1
            dly_min= max(0,int(y0-4.5))
            dly_max= min(max_lin_dly,int(y0+5.5))
            dly_to_try=[]
            for d in range(dly_min,dly_max+1):
                dly_to_try.append((d,periods))
            if (y0<0): # add a second range to try (higher delay values
                y0+=variantStep
                periods += 1
                dly_min= max(0,int(y0-4.5))
                dly_max= min(max_lin_dly,int(y0+5.5))
                for d in range(dly_min,dly_max+1):
                    dly_to_try.append((d,periods))
            bestDly=None
            bestDiff=None
            bestPeriods=None
            for dp in dly_to_try:
                actualDelay=dp[0]-fineCorr[dp[0] % 5] # delay corrected for the non-uniform 160-scale
                diff=actualDelay-(y+variantStep*dp[1]) # dp[1] - number of added/removed full periods
                if (bestDiff is None) or (abs(bestDiff) > abs(diff)):
                    bestDiff = diff
                    bestDly =  dp[0]
                    bestPeriods= dp[1]
            phase_rslt=() #Default, if nothing was found
            if not bestDiff is None:
                phase_rslt=(bestDly,bestPeriods,bestDiff)
            if (quiet <2):
                print ("%d: %s %s"%(phase, str(dly_to_try), str(phase_rslt)) )
            
            bestSolPerErr.append(phase_rslt)
        if (quiet <2):
            for i in range(numPhaseSteps): # enumerate(cmda_marg_dly):
                d=cmda_marg_dly[i]
                print ("%d %d %d"%(i, d[0], d[1]),end=" ")
                if (bestSolPerErr[i]):
                    print("%d %d %f"%(bestSolPerErr[i][0],bestSolPerErr[i][1],bestSolPerErr[i][2]))
                else:
                    print()

#numPhaseSteps            
        #Add 180 dwegree shift (move cmda_odelay to EARLY of the marginal
        period_shift=0
        b_center= b- 0.5*variantStep
        if b_center < 0: # have to move late
            b_center+=variantStep
            period_shift+=1
        cmda_dly_per_err=[]
        for phase in range (numPhaseSteps):
            marg_phase=(phase+numPhaseSteps//2) % numPhaseSteps
            extra_periods=(phase+numPhaseSteps//2) // numPhaseSteps
            bspe= bestSolPerErr[marg_phase]
#            err_for_zero=int(round(-(phase+(b+fineCorr[0])/a))%numPhaseSteps)/(1.0*numPhaseSteps)
            err_for_zero=int(round(-(marg_phase+(b+fineCorr[0])/a))%numPhaseSteps)/(1.0*numPhaseSteps)
            if err_for_zero >0.5:
                err_for_zero=1.0-err_for_zero
            else:
                err_for_zero=None 

            if bspe:
                cmda_dly_per_err.append({'ldly':bspe[0],
                                         'period':bspe[1]+period_shift+extra_periods+b_period, # b_period - shift from the branch
                                                                  # where phase starts from the longest cmda_odelay and goes down
                                         'err':bspe[2],
                                         'zerr':err_for_zero
                                         })
            else:
                cmda_dly_per_err.append({}) # No solution for this phase value
        rdict={"cmda_odly_a":a,
               "cmda_odly_b":b_center,
               "cmda_odly_period":period_shift+b_period, # 
               "cmda_fine_corr":fineCorr,
               "cmda_bspe":cmda_dly_per_err}
        if (quiet <3):
            print("\ncmda_odelay adjustmet results:")
            print('cmda_odly_a:      %f'%(rdict['cmda_odly_a']))
            print('cmda_odly_b:      %f'%(rdict['cmda_odly_b']))
            print('cmda_odly_period: %d'%(rdict['cmda_odly_period']))
            print('cmda_fine_corr:   %s'%(rdict['cmda_fine_corr']))
            print("\nPhase DLY0 MARG_A7 CMDA PERIODS*10 ERR*10 ZERR*100")
            for i in range(numPhaseSteps): # enumerate(cmda_marg_dly):
                d=cmda_marg_dly[i]
                print ("%d %d %d"%(i, d[0], d[1]),end=" ")
                if (rdict['cmda_bspe'][i]):
                    e1=rdict['cmda_bspe'][i]['zerr']
                    if not e1 is None:
                        e1="%.3f"%(100*e1)
                    print("%d %d %f %s"%(rdict['cmda_bspe'][i]['ldly'],
                                           10*rdict['cmda_bspe'][i]['period'],
                                           10*rdict['cmda_bspe'][i]['err'],
                                           e1))
                else:
                    print()
#TODO: Add 180 shift to get center, not marginal cmda_odelay        
        self.adjustment_state.update(rdict)
        if (quiet <3):
            print ("rdict={")
            for k,v in rdict.items():
                print("'%s':%s,"%(k,str(v)))
            print ("}")
        return rdict
        
    def measure_write_levelling(self,
                               compare_prim_steps = True, # while scanning, compare this delay with 1 less by primary(not fine) step,
                               start_phase=0,
                               reinits=1, #higher the number - more re-inits are used (0 - only where absolutely necessary
                               invert=0, # anti-align DQS (should be 180 degrees off from the normal one)
                               dqs_patt=None,
                               quiet=1
                               ):
        """
        Find DQS output delay for each phase value
        Depends on adjust_cmda_odelay results
        @param compare_prim_steps = True, # while scanning, compare this delay with 1 less by primary(not fine) step,
        @param start_phase=0,
        @param reinits=1, #higher the number - more re-inits are used (0 - only where absolutely necessary
        @param invert=0, # anti-align DQS (should be 180 degrees off from the normal one), can be used to find duty cycle of the clock
        @param dqs_patt set and store in global data DQS pattern to use during writes
        @param quiet=1
        """
        nbursts=16
        numLanes=2
        try:
            self.adjustment_state['cmda_bspe']
        except:
            raise Exception("Command/Address delay calibration data is not found - please run 'adjust_cmda_odelay' command first")
        start_phase &= 0xff
        if start_phase >=128:
            start_phase -= 256 # -128..+127
        max_lin_dly=NUM_DLY_STEPS-1
        wlev_max_bad=0.01 # <= OK, > bad
        numPhaseSteps=len(self.adjustment_state['cmda_bspe'])
        if quiet < 2:
            print("cmda_bspe = %s"%str(self.adjustment_state['cmda_bspe']))
            print ("numPhaseSteps=%d"%(numPhaseSteps))
            
        self.x393_pio_sequences.set_write_lev(nbursts) # write leveling, 16 times   (full buffer - 128)
        if dqs_patt is None:
            try:
                dqs_patt=self.adjustment_state["dqs_pattern"]
            except:
                print("Skipping DQS pattern (0x55/0xaa) control as it is not provided and not in gloabal data (dqs_patt=self.adjustment_state['dqs_pattern'])")

        if not dqs_patt is None: # may be just set
            self.x393_mcntrl_timing.axi_set_dqs_dqm_patterns(dqs_patt=dqs_patt,
                                                             dqm_patt=None,
                                                             quiet=quiet+2)
        def wlev_phase_step (phase):
            dqso_cache=[None]*NUM_DLY_STEPS # cache for holding already measured delays. None - not measured, 0 - no data, [[]..[]]
            def measure_dqso(dly,force_meas=False):
                def norm_wlev(wlev): #change results to invert wlev data
                    if invert:
                        return [1.0-wlev[0],1.0-wlev[1],wlev[2]]
                    else:
                        return wlev
                if (dqso_cache[dly] is None) or force_meas:
                    self.x393_mcntrl_timing.axi_set_dqs_odelay(combine_delay(dly),quiet=quiet)
                    wlev_rslt=norm_wlev(self.x393_pio_sequences.write_levelling(1, nbursts, quiet+1))
                    if wlev_rslt[2]>wlev_max_bad: # should be 0 - otherwise wlev did not work (CMDA?)
                        raise Exception("Write levelling gave unexpected data, aborting (may be wrong command/address delay, incorrectly initialized")
                    dqso_cache[dly] = wlev_rslt
                    if quiet < 1:
                        print ('measure_dqso(%d) - new measurement'%(dly))
                else:
                    wlev_rslt = dqso_cache[dly]
                    if quiet < 1:
                        print ('measure_dqso(%d) - using cache'%(dly))
                return wlev_rslt
                     
                
            
            
            #currently looking for the lowest delay, may be multiple with higher frequency (full delay > period)
            dly90=int(0.25*numPhaseSteps*abs(self.adjustment_state['cmda_odly_a']) + 0.5) # linear delay step ~ SDCLK period/4
            cmda_odly_data=self.adjustment_state['cmda_bspe'][phase % numPhaseSteps]
            if (not cmda_odly_data): # phase is invalid for CMDA
                return None
            cmda_odly_lin=cmda_odly_data['ldly']
            self.x393_mcntrl_timing.axi_set_phase(phase,quiet=quiet)
            self.x393_mcntrl_timing.axi_set_cmda_odelay(combine_delay(cmda_odly_lin),quiet=quiet)
            d_low=0
            while d_low <= max_lin_dly:
                wlev_rslt=measure_dqso(d_low)
                if (wlev_rslt[0] <= wlev_max_bad) and (wlev_rslt[1] <= wlev_max_bad):
                    break
                d_low+=dly90
            else:
                if quiet < 3:
                    print ("Failed to find d_low during initial quadrant search for phase=%d (0x%x)"%(phase,phase))
                return None
            # Now find d_high>d_low to get both bytes result above
            d_high= d_low+dly90   
            while d_high <= max_lin_dly:
                wlev_rslt=measure_dqso(d_high)
                if (wlev_rslt[0] >= (1.0 -wlev_max_bad)) and (wlev_rslt[1] >= (1.0-wlev_max_bad)):
                    break
                d_high+=dly90
            else:
                if quiet < 3:
                    print ("Failed to find d_high during initial quadrant search for phase=%d (0x%x)"%(phase,phase))
                return None
            # Narrow range while both bytes fit
            if quiet < 2:
                print ("After quadrant adjust d_low=%d, d_high=%d"%(d_low,d_high))
            
            while d_high > d_low:
                dly= (d_high + d_low)//2
                wlev_rslt=measure_dqso(dly)
                if (wlev_rslt[0] <= wlev_max_bad) and (wlev_rslt[1] <= wlev_max_bad):
                    if d_low == dly:
                        break
                    d_low=dly
                elif (wlev_rslt[0] >= (1.0 -wlev_max_bad)) and (wlev_rslt[1] >= (1.0-wlev_max_bad)):
                    d_high=dly
                else:
                    break #mixed results
            # Now process each byte separately
            if quiet < 2:
                print ("After common adjust d_low=%d, d_high=%d"%(d_low,d_high))
            d_low=[d_low,d_low]
            d_high=[d_high,d_high]
            for i in range(numLanes):
                while d_high[i] > d_low[i]: 
                    dly= (d_high[i] + d_low[i])//2
                    if quiet < 1:
                        print ("i=%d, d_low=%d, d_high=%d, dly=%d"%(i,d_low[i],d_high[i],dly))
                    wlev_rslt=measure_dqso(dly)
                    if wlev_rslt[i] <= wlev_max_bad:
                        if d_low[i] == dly:
                            break
                        d_low[i]=dly
                    else:
                        d_high[i]=dly
            #return d_low

            # now scan in the range +/- NUM_FINE_STEPS for each lane, get (dly, err) for each, err=None if binary 
            rslt=[]
            bestDly=[None]*numLanes # [low_safe]*2 # otherwise may fail - check it?
            bestDiffs=[None]*numLanes
            comp_step=(1,NUM_FINE_STEPS)[compare_prim_steps]
            for lane in range (numLanes):
                lastPositive=0
                for dly in range (max(0,d_low[lane]-NUM_FINE_STEPS), min(NUM_DLY_STEPS,d_low[lane]+2*NUM_FINE_STEPS+1)):
                    ref_dly= dly-comp_step
                    if ref_dly <0:
                        continue
                    wlev_rslt_ref=measure_dqso(ref_dly)    
                    wlev_rslt=    measure_dqso(dly)    
                    diff=    wlev_rslt[lane]-0.5
                    diff_ref=wlev_rslt_ref[lane]-0.5
                    diffs_prev_this=(diff_ref,diff)
                    if diff > 0:
                        lastPositive+=1
                    else:
                        lastPositive=0
                    if quiet <2:
                        print ("lane=%d ref_dly=%d dly=%d, diffs_prev_this=%s"%(lane, ref_dly, dly, str(diffs_prev_this)))
                    if (diffs_prev_this[0] <= 0) and (diffs_prev_this[1] >= 0): 
                        if abs(diffs_prev_this[0]) <= abs(diffs_prev_this[1]): # store previous sample
                            if (bestDiffs[lane] is None) or (abs (diffs_prev_this[0]) < abs(bestDiffs[lane])):
                                bestDly[lane]=ref_dly # dly-1/dly-NUM_FINE_STEPS
                                bestDiffs[lane]=diffs_prev_this[0]
                        else:
                            if (bestDiffs[lane] is None) or (abs (diffs_prev_this[1])<abs(bestDiffs[lane])):
                                bestDly[lane]=dly # dly-1
                                bestDiffs[lane]=diffs_prev_this[1]
#                    if (diff > 0):
                    if lastPositive > NUM_FINE_STEPS:
                        break # no need to continue, data got already - Wrong, better analog may still be ahead
                if bestDiffs[lane] == -0.5:
                    bestDiffs[lane] = None # single step jumps from none to all
                elif not bestDiffs[lane] is None:
                    bestDiffs[lane] *= 2
                rslt.append((bestDly[lane],bestDiffs[lane]))
                if quiet < 2:
                    print ("bestDly[%d]=%s, bestDiffs[%d]=%s"%(lane,str(bestDly[lane]),lane,str(bestDiffs[lane])))
            if quiet < 2:
                print ('dly=%d rslt=%s'%(dly,str(rslt)))
            if quiet < 2:
                print ("Cache for phase=%d:"%(phase))
                for i,d in enumerate(dqso_cache):
                    if d:
                        print ("%d %d: %s"%(phase,i,str(d)))
            return rslt

        # main method body
        
        if (start_phase+numPhaseSteps)>128:
            old_start_phase=start_phase
            while (start_phase+numPhaseSteps)>128:
                start_phase -= numPhaseSteps
            print("Selected scan phase range (%d..%d) does not fit into -128..+127, changing it to %d..%d)"%
                  (old_start_phase,old_start_phase+numPhaseSteps-1,start_phase,start_phase+numPhaseSteps-1))
#start_phase
        if reinits > 1: # Normally not needed (When started after adjust_cmda_odelay, but refresh should be off (init will do that)
            self.x393_pio_sequences.restart_ddr3()
        wlev_dqs_delays=[None]*numPhaseSteps
        
        for phase in range(start_phase,start_phase+numPhaseSteps):
            phase_mod=phase % numPhaseSteps
            if quiet <3:
                print ("%d(%d):"%(phase,phase_mod),end=" ")
                sys.stdout.flush()
            elif quiet < 5:
                print (".",end="")
                sys.stdout.flush()
            dlys=wlev_phase_step(phase)
            wlev_dqs_delays[phase_mod]=dlys
            if quiet <3:
                print ("%s"%str(dlys),end=" ")
                sys.stdout.flush()
            elif quiet < 5:
                print (".",end="")
                sys.stdout.flush()
            if quiet< 2:
                print()
                
        if quiet < 4:
            print("\nMeasured wlev data, When error is None add 1/2 of compare_prim_steps to the estimated result")
            print("compare_prim_steps=",compare_prim_steps)
            print("Phase dly0 dly1 fdly0 fdly1 err0 err1")
            for i,d in enumerate(wlev_dqs_delays):
                if d:
                    print ("%d %d %d"%(i, d[0][0], d[1][0]), end=" ")
                    for ld in d:
                        if not ld[1] is None:
                            print ("%d"%(ld[0]),end= " ")
                        else:
                            print ("?",end=" ")
                    for ld in d:
                        try:
                            print ("%.3f"%(ld[1]),end= " ")
                        except:
                            print ("?",end=" ")
                    print()        
                else:
                    print ("%d"%(i))
        elif quiet < 5:
            print ()
            
        #measurement done, now processing results. TODO: move to a separate function            
        if quiet < 4:
            print ("wlev_dqs_delays=",wlev_dqs_delays)
            print ("wlev_dqs_steps=", compare_prim_steps)
            
        self.adjustment_state["wlev_dqs_delays"]=wlev_dqs_delays    
        self.adjustment_state["wlev_dqs_steps"]=compare_prim_steps
        if not dqs_patt is None:
            self.adjustment_state["dqs_pattern"]=dqs_patt
        return wlev_dqs_delays
    

    def proc_write_levelling(self,
                             data_set_number=2,        # not number - use measured data
                             max_phase_err=0.1,
                             quiet=1):
        if isinstance (data_set_number,(int,long)) and (data_set_number>=0) :
            if quiet < 4:
                print("Using hard-coded data set ")
                wlev_dqs_delays=get_test_dq_dqs_data.get_wlev_dqs_delays()
        else:
            if quiet < 4:
                print("Using measured data set")
            try:
                wlev_dqs_delays=self.adjustment_state["wlev_dqs_delays"]
            except:
                print ("Write levelling measured data is not available, exiting")
                return
        dly_steps=self.x393_mcntrl_timing.get_dly_steps()
        numPhaseSteps= int(dly_steps['SDCLK_PERIOD']/dly_steps['PHASE_STEP']+0.5)

        #find the largest positive step of cmda_marg_dly while cyclically increasing phase
        numValid=0
        for i,d in enumerate(wlev_dqs_delays):
            if d:
                numValid += 1
        if numValid < 2:
            raise Exception("Too few points with DQS output delay in write levelling mode: %d"%numValid)
        
        print("wlev_dqs_delays=",wlev_dqs_delays)
        
        firstIndex=[None]*2
        for lane in range(2):
            maxPosSep=0
            for i,d in enumerate(wlev_dqs_delays):
                if d>0:
                    for j in range(1,numPhaseSteps):
                        d1=wlev_dqs_delays[(i + j) % numPhaseSteps]
                        if d1: # valid data
                            if (d1[lane] - d[lane]) > maxPosSep:
                                maxPosSep = d1[lane] - d[lane]
                                firstIndex[lane]=(i + j) % numPhaseSteps
                            break;
        #now data from  firstIndex to (firstIndex+numPhaseSteps)%numPhaseSteps is ~monotonic - apply linear approximation
        if quiet <2:
            print ("firstIndices=[%d,%d]"%(firstIndex[0],firstIndex[1]))
        #Linear approximate each lane
        a=[None]*2
        b=[None]*2
        for lane in range(2):
            S0=0
            SX=0
            SY=0
            SX2=0
            SXY=0
            for x in range(numPhaseSteps):
                dlys=wlev_dqs_delays[(x+firstIndex[lane]) % numPhaseSteps]
                if dlys:
                    y=dlys[lane]+0.5
                    S0+=1
                    SX+=x
                    SY+=y
                    SX2+=x*x
                    SXY+=x*y
    #            print("x=%f, index=%d, y=%f, S0=%f, SX=%f, SY=%f, SX2=%f, SXY=%f"%(x, (x+firstIndex) % numPhaseSteps, y, S0, SX, SY, SX2, SXY))
            a[lane] = (SXY*S0 - SY*SX) / (SX2*S0 - SX*SX)
            b[lane] = (SY*SX2 - SXY*SX) / (SX2*S0 - SX*SX)
        if quiet < 2:
            print ("a=[%f, %f], b=[%f, %f]"%(a[0],a[1],b[0],b[1]))

        # fine delay corrections
        fineCorr= [[0.0]*5,[0.0]*5] # not [[0.0]*5]*2 ! - they will poin to the same top element 
        fineCorrN=[[0]*5,[0]*5]     # not [[0]*5]*2 !
        for lane in range(2):
            for x in range(numPhaseSteps):
                dlys=wlev_dqs_delays[(x+firstIndex[lane]) % numPhaseSteps]
                if dlys:
                    y=dlys[lane]
                    i=y % 5
                    y+=0.5
                    diff=y- (a[lane] * x + b[lane])
                    fineCorr[lane][i]  += diff
                    fineCorrN[lane][i] += 1
#                    print("lane,x,y,i,diff,fc,fcn= %d, %d, %f, %d, %f, %f, %d"%(lane,x,y,i,diff,fineCorr[lane][i],fineCorrN[lane][i]))
#            print ("lane=%d, fineCorr=%s, fineCorrN=%s"%(lane, fineCorr[lane], fineCorrN[lane]))
            for i in range(5):
                if fineCorrN[lane][i]>0:
                    fineCorr[lane][i]/=fineCorrN[lane][i]
#            print ("lane=%d, fineCorr=%s, fineCorrN=%s"%(lane, fineCorr[lane], fineCorrN[lane]))
                    
        if (quiet <2):
            print ("fineCorr lane0 = %s"%str(fineCorr[0])) # Why ar they both the same?
            print ("fineCorr lane1 = %s"%str(fineCorr[1]))
        variantStep=[-a[0]*numPhaseSteps,-a[1]*numPhaseSteps] #how much b changes when moving over the full SDCLK period
        if (quiet <2):
            print ("Delay matching the full SDCLK period = [%f, %f]"%(variantStep[0],variantStep[1]))
        b_period=[None]*2
        for lane in range(2):
            b[lane]-=a[lane]*firstIndex[lane] # recalculate b for phase=0
            b_period[lane]=0
            if (quiet <2):
                print ("a[%d]=%f, b[%d]=%f"%(lane,a[lane],lane,b[lane]))
            #Make b fit into 0..max_lin_dly range
            while (b[lane] >= NUM_DLY_STEPS):
                b[lane]-=variantStep[lane]
                b_period[lane]-=1
            while (b[lane] < 0):
                b[lane] += variantStep[lane] # can end up having b>max_lin_dly - if the phase adjust by delay is lower than full period
                b_period[lane] += 1
        if (quiet <2):
            print ("a[0]=%f, b[0]=%f, b_period[0]=%d"%(a[0],b[0],b_period[0]))
            print ("a[1]=%f, b[1]=%f, b_period[1]=%d"%(a[1],b[1],b_period[1]))
            
        # Find best minimal delay (with higher SDCLK frequency delay range can exceed the period and there could
        # be more than one solution
        bestSolPerErr=[[],[]] # pair (for two lanes) of lists ot tuples, each containing(best cmda_odelay,number of added periods,error)
        max_dly_err=[abs(a[0])*max_phase_err*numPhaseSteps, # maximal allowed delay error (in 160-step scale)
                     abs(a[1])*max_phase_err*numPhaseSteps]
        if (quiet <2):
            print("Max dly error=%s"%(str(max_dly_err)))
        for lane in range(2):
            for phase in range (numPhaseSteps):
                periods=0 # b_period[lane]
                y=a[lane]*phase+b[lane]
                y0=y
                #find the lowest approximate solution to consider
                if y0 > (-max_dly_err[lane]):
                    while (y0 >= (variantStep[lane]-max_dly_err[lane])):
                        y0 -= variantStep[lane]
                        periods -= 1
                else:
                    while (y0<(-max_dly_err[lane])):
                        y0 += variantStep[lane]
                        periods += 1
                dly_min= max(0,int(y0-4.5))
                dly_max= min(NUM_DLY_STEPS-1,int(y0+5.5))
                dly_to_try=[]
                for d in range(dly_min,dly_max+1):
                    dly_to_try.append((d,periods))
                if (y0<0): # add a second range to try (higher delay values
                    y0+=variantStep[lane]
                    periods += 1
                    dly_min= max(0,int(y0-4.5))
                    dly_max= min(NUM_DLY_STEPS-1,int(y0+5.5))
                    for d in range(dly_min,dly_max+1):
                        dly_to_try.append((d,periods))
                bestDly=None
                bestDiff=None
                bestPeriods=None
                for dp in dly_to_try:
                    actualDelay=dp[0]-fineCorr[lane][dp[0] % 5] # delay corrected for the non-uniform 160-scale
                    diff=actualDelay-(y+variantStep[lane]*dp[1]) # dp[1] - number of added/removed full periods
                    if (bestDiff is None) or (abs(bestDiff) > abs(diff)):
                        bestDiff = diff
                        bestDly =  dp[0]
                        bestPeriods= dp[1]
                phase_rslt=() #Default, if nothing was found
                if not bestDiff is None:
                    phase_rslt=(bestDly,bestPeriods,bestDiff)
                if (quiet <2):
                    print ("%d:%d: %s %s"%(lane, phase, str(dly_to_try), str(phase_rslt)) )
                
                bestSolPerErr[lane].append(phase_rslt)
        if (quiet <2):
            for i in range(numPhaseSteps): # enumerate(cmda_marg_dly):
                d=wlev_dqs_delays[i]
                if d:
                    print ("%d %d %d"%(i, d[0], d[1]),end=" ")
                else:
                    print ("%d X X"%(i),end=" ")
                for lane in range(2):
                    bspe=bestSolPerErr[lane][i]
                    if bspe:
                        print("%d %d %f"%(bspe[0], bspe[1], bspe[2]),end=" ")
                    else:
                        print("X X X",end=" ")
                print()
        wlev_bspe=[[],[]]
        for lane in range (2):
            for phase in range (numPhaseSteps):
                bspe=bestSolPerErr[lane][phase]
                if bspe:
                    wlev_bspe[lane].append({'ldly':bspe[0],
                                             'period':bspe[1]+b_period[lane], # b_period - shift from the branch
                                                                        # where phase starts from the longest cmda_odelay and goes down
                                             'err':bspe[2]})
                else:
                    wlev_bspe[lane].append({})
                
        rdict={"wlev_dqs_odly_a":    a, #[,]
               "wlev_dqs_odly_b":    b,#[,]
               "wlev_dqs_period":    b_period, # 
               "wlev_dqs_fine_corr": fineCorr,
               "wlev_dqs_bspe":      wlev_bspe}
        if (quiet <3):
            print("\nwrite levelling DQS output delay adjustmet results:")
            print('wlev_dqs0_odly_a:    %f'%(rdict['wlev_dqs_odly_a'][0]))
            print('wlev_dqs1_odly_a:    %f'%(rdict['wlev_dqs_odly_a'][1]))
            print('wlev_dqs0_odly_b:    %f'%(rdict['wlev_dqs_odly_b'][0]))
            print('wlev_dqs1_odly_b:    %f'%(rdict['wlev_dqs_odly_b'][1]))
            print('wlev_dqs0_period:    %d'%(rdict['wlev_dqs_period'][0]))
            print('wlev_dqs1_period:    %d'%(rdict['wlev_dqs_period'][1]))
            print('wlev_dqs0_fine_corr: %s'%(rdict['wlev_dqs_fine_corr'][0]))
            print('wlev_dqs1_fine_corr: %s'%(rdict['wlev_dqs_fine_corr'][1]))
            print("\nPhase Measured_DQS0 Measured_DQS1 DQS0 PERIODS0*10 ERR0*10 DQS1 PERIODS1*10 ERR1*10")
            for i in range(numPhaseSteps): # enumerate(cmda_marg_dly):
                d=wlev_dqs_delays[i]
                if d:
                    print ("%d %d %d"%(i, d[0], d[1]),end=" ")
                else:
                    print ("%d X X"%(i),end=" ")
                for lane in range(2):
                    bspe=rdict['wlev_dqs_bspe'][lane][i] # bestSolPerErr[lane][i]
                    if bspe:
                        print("%d %d %f"%(bspe['ldly'], 10*bspe['period'], 10*bspe['err']),end=" ")
                    else:
                        print("X X X",end=" ")
                print()
                            
        self.adjustment_state.update(rdict)
        if (quiet <3):
            print ("rdict={")
            for k,v in rdict.items():
                print("'%s':%s,"%(k,str(v)))
            print ("}")
        return rdict
          
    def measure_pattern(self,
                       compare_prim_steps=True, # while scanning, compare this delay with 1 less by primary(not fine) step,
                                                # save None for fraction in unknown (previous -0.5, next +0.5) 
                       limit_step=0.125, # initial delay step as a fraction of the period
                       max_phase_err=0.1,
                       quiet=1,
                       start_dly=0): #just to check dependence
        """
        for each DQS input delay find 4 DQ transitions for each DQ bit,
        then use them to find finedelay for each of the DQS and DQ,
        linear coefficients (a,b) for each DQ vs DQS and asymmetry
        (late 0->1, early 1->0) for each of the DQ and DQS
        @param quiet reduce output

        """
        nrep=8
        max_lin_dly=NUM_DLY_STEPS-1#159
        timing=self.x393_mcntrl_timing.get_dly_steps()
        #steps={'DLY_FINE_STEP': 0.01, 'DLY_STEP': 0.078125, 'PHASE_STEP': 0.022321428571428572, 'SDCLK_PERIOD': 2.5}
        dly_step=int(NUM_FINE_STEPS*limit_step*timing['SDCLK_PERIOD']/timing['DLY_STEP']+0.5)
        step180= int(NUM_FINE_STEPS*0.5* timing['SDCLK_PERIOD'] / timing['DLY_STEP'] +0.5)                                                                                                                                                                                                                 
        if quiet<2:
            print ("timing)=%s, dly_step=%d step180=%d"%(str(timing),dly_step,step180))
        self.x393_pio_sequences.set_read_pattern(nrep+3) # set sequence once
        
        def patt_dqs_step(dqs_lin):
            patt_cache=[None]*(max_lin_dly+1) # cache for holding already measured delays
            def measure_patt(dly,force_meas=False):
                if (patt_cache[dly] is None) or force_meas:
                    self.x393_mcntrl_timing.axi_set_dq_idelay(combine_delay(dly),quiet=quiet)
                    patt= self.x393_pio_sequences.read_levelling(nrep,
                                                                 -1, # sel=1, # 0 - early, 1 - late read command (shift by a SDCLK period), -1 - use current sequence 
                                                                 quiet+1)
                    patt_cache[dly]=patt
                    if quiet < 1:
                        print ('measure_patt(%d,%s) - new measurement'%(dly,str(force_meas)))
                else:
                    patt=patt_cache[dly]
                    if quiet < 1:
                        print ('measure_patt(%d,%s) - using cache'%(dly,str(force_meas)))
                return patt
            def get_sign(data,edge=None):
                """
                edge: 0 - first 16, 1 - second 16
                return -1 if  all <0.5
                return +1 if all >0.5
                return 0 otherwise
                """
                if edge == 0:
                    return get_sign(data[:16])
                if edge == 1:
#                    return -get_sign(data[16:])
                    return get_sign(data[16:])
                m1=True
                p1=True
                for d in data:
                    m1 &= (d < 0.5)
                    p1 &= (d > 0.5)
                    if not (m1 or p1):
                        break
                else:
                    if m1:
                        return -1
                    elif p1:
                        return 1
                return 0
            
            rslt=[None]*16 # each bit will have [inphase][dqs_falling]
            self.x393_mcntrl_timing.axi_set_dqs_idelay(combine_delay(dqs_lin),quiet=quiet)
            d_low=[None]*2  # first - lowest when all are -+, second - when all are +-  
            d_high=[None]*2 # first - when all are +- after -+, second - when all are -+ after +-
            dly=0
            notLast=True
            needSigns=None
            lowGot=None
            highGot=None
            while (dly <= max_lin_dly) and notLast:
                notLast= dly < max_lin_dly
                patt=measure_patt(dly) # ,force_meas=False)
                signs=(get_sign(patt,0),get_sign(patt,1))
                if quiet < 1:
                    print ('dly=%d lowGot=%s, highGot=%s, signs=%s'%(dly,str(lowGot),str(highGot),str(signs)))
                if lowGot is None : # looking for the first good sample
                    if (signs==(-1,1)) or  (signs==(1,-1)) :
                        if signs[0] == -1: #  == (-1,1):
                            lowGot=0
                        else:
                            lowGot=1
                        d_low[lowGot] = dly
                        needSigns=((1,-1),(-1,1))[lowGot]
                        dly += step180-dly_step # almost 180 degrees
                    else: # at least one is 0
                        dly += dly_step # small step
                    if quiet < 1:
                        print ('lowGot was None : dly=%d, lowGot=%s, needSigns=%s'%(dly,str(lowGot),str(needSigns)))
                elif highGot is None : # only one good sample is available so far
                    if signs == needSigns:
                        highGot=lowGot
                        d_high[highGot] = dly
                        d_low[1-lowGot] = dly
                        needSigns=((-1,1),(1,-1))[lowGot]
                        dly += step180-dly_step # almost 180 degrees
                    else:
                        dly += dly_step # small step
                    if quiet < 1:
                        print ('highGot was None : dly=%d, lowGot=%s, highGot=%s, needSigns=%s'%(dly,str(lowGot),str(lowGot),str(needSigns)))
                else: # looking for the 3-rd sample 
                    if signs == needSigns:
                        highGot=1-highGot
                        d_high[highGot] = dly
                        break
                    else:
                        dly += dly_step # small step
                dly = min (dly,max_lin_dly)
            if highGot is None:
                if quiet < 3:
                    print ("Could not find initial bounds for DQS input delay = %d d_low=%s, d_high=%s"%(dqs_lin,str(d_low),str(d_high)))
                return None
            if quiet < 2:
                    print ("DQS input delay = %d , preliminary bounds: d_low=%s, d_high=%s"%(dqs_lin,str(d_low),str(d_high)))
            for inPhase in range(2):
                if not d_high[inPhase] is None:
                    # Try to squeeze d_low, d_high closer to reduce scan range
                    while d_high[inPhase]>d_low[inPhase]:
                        dly=(d_high[inPhase] + d_low[inPhase])//2
                        patt=measure_patt(dly) # ,force_meas=False)
                        signs=(get_sign(patt,0),get_sign(patt,1))
                        if signs==(-1,1):
                            if inPhase:
                                d_high[inPhase]=dly 
                            else:
                                if d_low[inPhase]==dly:
                                    break
                                d_low[inPhase]=dly 
                        elif signs==(1,-1):     
                            if inPhase:
                                if d_low[inPhase]==dly:
                                    break
                                d_low[inPhase]=dly 
                            else:
                                d_high[inPhase]=dly 
                        else: # uncertain result 
                            break
            if quiet < 2:
                    print ("DQS input delay = %d , squeezed bounds: d_low=%s, d_high=%s"%(dqs_lin,str(d_low),str(d_high)))
#Improve squeezing - each limit to the last

            for inPhase in range(2):
                if not d_high[inPhase] is None:
                    # Try to squeeze d_low first
                    d_uncertain=d_high[inPhase]
                    while d_uncertain > d_low[inPhase]:
                        dly=(d_uncertain + d_low[inPhase])//2
                        patt=measure_patt(dly) # ,force_meas=False)
                        signs=(get_sign(patt,0),get_sign(patt,1))
                        if signs==(-1,1):
                            if inPhase:
                                d_uncertain=dly 
                            else:
                                if d_low[inPhase]==dly:
                                    break
                                d_low[inPhase]=dly 
                        elif signs==(1,-1):     
                            if inPhase:
                                if d_low[inPhase]==dly:
                                    break
                                d_low[inPhase]=dly 
                            else:
                                d_uncertain=dly 
                        else: # uncertain result
                            d_uncertain=dly
                    #now udjust upper limit
                    while d_high[inPhase] > d_uncertain:
                        dly=(d_high[inPhase] + d_uncertain)//2
                        patt=measure_patt(dly) # ,force_meas=False)
                        signs=(get_sign(patt,0),get_sign(patt,1))
                        if signs==(-1,1):
                            if inPhase:
                                d_high[inPhase]=dly 
                            else:
                                if d_uncertain==dly:
                                    break
                                d_uncertain=dly 
                        elif signs==(1,-1):     
                            if inPhase:
                                if d_uncertain==dly:
                                    break
                                d_uncertain=dly 
                            else:
                                d_high[inPhase]=dly 
                        else: # uncertain result 
                            if d_uncertain==dly:
                                break
                            d_uncertain=dly
            if quiet < 2:
                    print ("DQS input delay = %d , tight squeezed bounds: d_low=%s, d_high=%s"%(dqs_lin,str(d_low),str(d_high)))

                    
            # scan ranges, find closest solutions
            #compare_prim_steps
            best_dly= [[],[]]
            best_diff=[[],[]]
            for inPhase in range(2):
                if not d_high[inPhase] is None:
#                    patt=None
                    best_dly[inPhase]=[d_low[inPhase]]*32
                    best_diff[inPhase]=[None]*32
#                    for b,p in enumerate(patt):
#                        positiveJump=((not inPhase) and (b<16)) or (inPhase and (b >= 16)) # may be 0, False, True
#                        if positiveJump:
#                            best_diff[inPhase].append(p-0.5)
#                        else:
#                            best_diff[inPhase].append(0.5-p)
                    for dly in range(d_low[inPhase]+1,d_high[inPhase]+1):
#                        patt_prev=patt
                        #as measured data is cached, there is no need to specially maintain patt_prev from earlier measurement
                        dly_prev= max(0,dly-(1,NUM_FINE_STEPS)[compare_prim_steps])
                        patt_prev=measure_patt(dly_prev) # ,force_meas=False) - will be stored in cache
                        patt=     measure_patt(dly) # ,force_meas=False) - will be stored in cache
                        for b in range(32):
                            positiveJump=((not inPhase) and (b<16)) or (inPhase and (b >= 16)) # may be 0, False, True       
                            signs=((-1,1)[patt_prev[b]>0.5],(-1,1)[patt[b]>0.5])
                            if (positiveJump and (signs==(-1,1))) or (not positiveJump and (signs==(1,-1))):
                                if positiveJump:
                                    diffs_prev_this=(patt_prev[b]-0.5,patt[b]-0.5)
                                else:
                                    diffs_prev_this=(0.5-patt_prev[b],0.5-patt[b])
                                if abs(diffs_prev_this[0]) <= abs(diffs_prev_this[1]): # store previous sample
                                    if (best_diff[inPhase][b] is None) or (abs (diffs_prev_this[0])<abs(best_diff[inPhase][b])):
                                        best_dly[inPhase][b]=dly_prev # dly-1
                                        best_diff[inPhase][b]=diffs_prev_this[0]
                                        if quiet < 1:
                                            print ("*%d:%0.3f:%0.3f%s"%(b,diffs_prev_this[0],diffs_prev_this[1],str(signs)),end="")
                                else:
                                    if (best_diff[inPhase][b] is None) or (abs (diffs_prev_this[1])<abs(best_diff[inPhase][b])):
                                        best_dly[inPhase][b]=dly # dly-1
                                        best_diff[inPhase][b]=diffs_prev_this[1]
                                        if quiet < 1:
                                            print ("?%d:%0.3f:%0.3f%s"%(b,diffs_prev_this[0],diffs_prev_this[1],str(signs)),end="")
                        if quiet < 1:
                            print("\n dly=%d dly_prev=%d:"%(dly,dly_prev),end=" ")
                    for b in range(32):
                        if  best_diff[inPhase][b] == -0.5:
                            best_diff[inPhase][b] = None # will have to add half-interval (0.5 or 2.5) 
                # rslt=[None]*16 # each bit will have [inphase][dqs_falling], each - a pair of (delay,diff)
            for b in range(16):
                rslt[b]=[[None]*2,[None]*2] # [inphase][dqs_falling]
                for inPhase in range(2):
                    if not d_high[inPhase] is None:
                        rslt[b][inPhase]= [(best_dly[inPhase][b],best_diff[inPhase][b]),(best_dly[inPhase][b+16],best_diff[inPhase][b+16])]
            if quiet < 2:
                    print ("%d: rslt=%s"%(dqs_lin,str(rslt)))
            return rslt
#        meas_data=[]
#        for ldly in range(max_lin_dly+1):
#            if quiet <3:
#                print ("%d(0x%x):"%(ldly,combine_delay(ldly)),end=" ")
#                sys.stdout.flush()
#            meas_data.append(patt_dqs_step(ldly))
#        if quiet <3:
#            print ()
        # main method code
        meas_data=[None]*(max_lin_dly+1)
        #start_dly
        for sdly in range(max_lin_dly+1):
            ldly = (start_dly+sdly)%(max_lin_dly+1)
#        for ldly in range(max_lin_dly+1):
            if quiet <3:
                print ("%d(0x%x):"%(ldly,combine_delay(ldly)),end=" ")
                sys.stdout.flush()
            elif quiet < 5:
                print (".",end="")
                sys.stdout.flush()
            meas_data[ldly] = patt_dqs_step(ldly)
        if quiet < 5:
            print ()

        if quiet < 3:
            print("\n\nMeasured data, integer portion, measured with %s steps"%(("fine","primary")[compare_prim_steps]))
            print ("DQS",end=" ")
            for f in ('ir','if','or','of'):
                for b in range (16):
                    print ("%s_%d"%(f,b),end=" ")
            print()        
            for ldly, data in enumerate(meas_data):
                print("%d"%ldly,end=" ")
                if data:
                    for typ in ((0,0),(0,1),(1,0),(1,1)):
                        for pData in data: # 16 DQs, each None nor a pair of lists for inPhase in (0,1), each a pair of edges, each a pair of (dly,diff)
                            if pData:
                                if pData[typ[0]] and pData[typ[0]][typ[1]]:
                                    print ("%d"%pData[typ[0]][typ[1]][0],end=" ")
                                    '''
                                    try:
                                        print ("%d"%pData[typ[0]][typ[1]][0],end=" ")
                                    except:
                                        print (".", end=" ")
                                    '''
                                else:
                                    print ("?", end=" ")
                            else:
                                print ("x",end=" ")
                        
                print()
        if quiet < 2:
            print("\n\nMasked measured data, integer portion, measured with %s steps"%(("fine","primary")[compare_prim_steps]))
            for f in ('ir','if','or','of'):
                for b in range (16):
                    print ("%s_%d"%(f,b),end=" ")
            print()        
            for ldly, data in enumerate(meas_data):
                print("%d"%ldly,end=" ")
                if data:
                    for typ in ((0,0),(0,1),(1,0),(1,1)):
                        for pData in data: # 16 DQs, each None nor a pair of lists for inPhase in (0,1), each a pair of edges, each a pair of (dly,diff)
                            if pData:
                                if pData[typ[0]] and pData[typ[0]][typ[1]] and (not pData[typ[0]][typ[1]][1] is None):
                                    print ("%d"%pData[typ[0]][typ[1]][0],end=" ")
                                    '''
                                    try:
                                        print ("%d"%pData[typ[0]][typ[1]][0],end=" ")
                                    except:
                                        print (".", end=" ")
                                    '''
                                else:
                                    print ("?", end=" ")
                            else:
                                print ("x",end=" ")
                        
                print()
                    
        if quiet < 2:
            print ("\nDifferences from 0.5:")

            print ("DQS",end=" ")
            for f in ('ir','if','or','of'):
                for b in range (16):
                    print ("%s_%d"%(f,b),end=" ")
            print()        
            for ldly, data in enumerate(meas_data):
                print("%d"%ldly,end=" ")
                if data:
                    for typ in ((0,0),(0,1),(1,0),(1,1)):
                        for pData in data: # 16 DQs, each None nor a pair of lists for inPhase in (0,1), each a pair of edges, each a pair of (dly,diff)
                            if pData:
                                if pData[typ[0]] and pData[typ[0]][typ[1]] and (not pData[typ[0]][typ[1]][1] is None):
                                    print ("%.2f"%pData[typ[0]][typ[1]][1],end=" ")
                                    '''
                                    try:
                                        print ("%d"%pData[typ[0]][typ[1]][0],end=" ")
                                    except:
                                        print (".", end=" ")
                                    '''
                                else:
                                    print ("?", end=" ")
                            else:
                                print ("x",end=" ")
                        
                print()
        if quiet < 3:
            print("\n\nMeasured data, comparing current data with the earlier by one %s step"%(("fine","primary")[compare_prim_steps]))
            print("When the fractional (second in the tuple) data is exactly -0.5, the actual result is in the range %s from the integer delay"%
                  (("+0.0..+1.0","+0.0..+%d"%NUM_FINE_STEPS)[compare_prim_steps]))
            print ("meas_data=[")
            for d in meas_data:
                print("%s,"%(str(d)))
            print("]")
        rdict={"patt_prim_steps":    compare_prim_steps,
               "patt_meas_data":     meas_data} # TODO: May delete after LMA fitting
        self.adjustment_state.update(rdict)

    def measure_dqs_idly_phase(self,
                               compare_prim_steps = True, # while scanning, compare this delay with 1 less by primary(not fine) step,
                                                # save None for fraction in unknown (previous -0.5, next +0.5) 
                               frac_step=0.125,
                               sel=1,
                               quiet=1):
        """
        Scan phase and find DQS input delay value to find when
        the result changes (it is caused by crossing clock boundarty from extrenal memory device derived
        to system-synchronous one
        cmda_odelay should be already calibrated, refresh will be turned on.
        Uses random/previously written pattern in one memory block (should have some varying data
        @param quiet reduce output
        """
        
        try:
            dqi_dqsi=self.adjustment_state['dqi_dqsi']
        except:
            print ("No DQ IDELAY vs. DQS IDELAY data available, exiting")
            return
        # Mark DQS idelay values that have all DQ delays valid 
        dqsi_valid={} #[None]*NUM_DLY_STEPS
        for k,v in dqi_dqsi.items():
            if v:
                dqsi_valid[k]=[False]*NUM_DLY_STEPS
                for dly in range(NUM_DLY_STEPS):
                    if v[dly]:
                        for d in v[dly]:
                            if d is None:
                                break
                        else: # All values are not None
                            dqsi_valid[k][dly]=True
        if not dqsi_valid:
            print ("No Valid DQ IDELAY vs. DQS IDELAY data is available, exiting")
            return
        if quiet <1:
            print ('dqi_dqsi=%s'%(str(dqi_dqsi)))
            print("\n\n")
        if quiet <2:
            print ('dqsi_valid=%s'%(str(dqsi_valid)))
        dqsi_lohi={}
        for k,vdly in dqsi_valid.items():
            if quiet <2:
                print ("k='%s', vdly=%s"%(k,str(vdly)))
            for i,v in enumerate(vdly):
                if v:
                    low=i
                    break
            else:
                print ("Could not find valid data in dqsi_valid[%s]=%s"%(k,str(vdly)))
                continue
            for i in range(low+1,NUM_DLY_STEPS):
                if not vdly[i]:
                    high=i
                    break
            else:
                high= NUM_DLY_STEPS-1
            dqsi_lohi[k]=(low,high)       
        if quiet <2:
            print ('dqsi_valid=%s'%(str(dqsi_valid)))
        if quiet <3:
            print ('dqsi_lohi=%s'%(str(dqsi_lohi)))
         

        brc=(5,        # 3'h5,     # bank
             0x1234,   # 15'h1234, # row address
             0x100)     # 10'h100   # column address
        nrep=8 # number of 8-bursts to compare (actual will have 3 more, first/last will be discarded
        timing=self.x393_mcntrl_timing.get_dly_steps()
        #steps={'DLY_FINE_STEP': 0.01, 'DLY_STEP': 0.078125, 'PHASE_STEP': 0.022321428571428572, 'SDCLK_PERIOD': 2.5}
        dly_step=int(NUM_FINE_STEPS*frac_step*timing['SDCLK_PERIOD']/timing['DLY_STEP']+0.5)
        numPhaseSteps= int(timing['SDCLK_PERIOD']/timing['PHASE_STEP']+0.5)
        step180= int(NUM_FINE_STEPS*0.5* timing['SDCLK_PERIOD'] / timing['DLY_STEP'] +0.5)                                                                                                                                                                                                                 
        if quiet<2:
            print ("timing)=%s, dly_step=%d step180=%d"%(str(timing),dly_step,step180))
        self.x393_pio_sequences.set_read_block(*(brc+(nrep+3,sel))) # set sequence once
        #prepare writing block:
        wdata16=(0,0,0xffff,0xffff)*(2*(nrep+3)) # Data will have o/1 transitions in every bit, even if DQ_ODELAY to DQS_ODELAY is not yet adjusted
        wdata32=convert_mem16_to_w32(wdata16)
        self.x393_mcntrl_buffers.write_block_buf_chn(0,0,wdata32,quiet) # fill block memory (channel, page, number)
        self.x393_pio_sequences.set_write_block(*(brc+(nrep+3,0,sel))) # set sequence once
        cmda_bspe=self.adjustment_state['cmda_bspe']
        # Replacement for older  wlev_dqs_bspe=self.adjustment_state['wlev_dqs_bspe']
        # Can be improved
        try:
            wlev_p_l=   self.get_delays_for_phase(phase = None,
                                                  list_branches=False,
                                                  target=DQSO_KEY,
                                                  b_filter=DFLT_DLY_FILT,
                                                  cost=None, # if None - will default to NUM_FINE_STEPS, if 0 - will keep it 
                                                  quiet = quiet+1)
        except:
            raise Exception ("No write levelling data is available, this method should run after write levelling and proc_dqso_phase")
        numLanes=max(len(wp) for wp in wlev_p_l if not wp is None)
        if quiet < 1:    
            print("numLanes=",numLanes)
        
        for phase in range(numPhaseSteps):
            try:
#                dqs_odelay=[wlev_dqs_bspe[lane][phase]['ldly'] for lane in range(len(wlev_dqs_bspe))]
                dqs_odelay=[wlev_p_l[phase][lane] for lane in range(numLanes)]
                cmda_odelay=cmda_bspe[phase]['ldly']
                if (not None in dqs_odelay) and (not cmda_odelay is None):
                    break
            except:
                pass    
        else:
            raise Exception("BUG: could not find phase that has valid cmda_odelay and dqs_odelay")
        phase_ok=self.set_phase_with_refresh( # check result for not None
                           phase,
                           quiet)
        if not phase_ok:
            raise Exception("BUG: Failed set_phase_with_refresh(%s)"%(str(phase)))
        self.x393_mcntrl_timing.axi_set_dqs_odelay(combine_delay(dqs_odelay),quiet=quiet)
        self.x393_pio_sequences.write_block() #page= 0, wait_complete=1)
        
        def dqsi_phase_step (phase):
            dqsi_cache=[None]*NUM_DLY_STEPS # cache for holding already measured delays. None - not measured, 0 - no data, [[]..[]]
            def measure_dqsi(dqs_idly,branch,force_meas=False):
                if not dqsi_valid[branch]:
                    return None
                if (dqs_idly > len(dqsi_cache)) or (dqs_idly <0 ):
                    print ("dqs_idly=%d, dqsi_cache=%s"%(dqs_idly,str(dqsi_cache)))
                try:
                    dqsi_cache[dqs_idly] 
                except:
                    print ("dqs_idly=%d, dqsi_cache=%s"%(dqs_idly,str(dqsi_cache)))
                       
                if (dqsi_cache[dqs_idly] is None) or force_meas:
                    self.x393_mcntrl_timing.axi_set_dqs_idelay(combine_delay(dqs_idly),quiet=quiet)
                    self.x393_mcntrl_timing.axi_set_dq_idelay(combine_delay(dqi_dqsi[branch][dqs_idly]),quiet=quiet)
                    buf=self.x393_pio_sequences.read_block(4 * (nrep+1) +2,
                                                           (0,1)[quiet<1], #show_rslt,
                                                           1) # wait_complete=1)
                    buf= buf[4:(nrep*4)+4] # discard first 4*32-bit words and the "tail" after nrep*4 words32
                    patt=convert_w32_to_mem16(buf)# will be nrep*8 items
                    dqsi_cache[dqs_idly]=patt
                    if quiet < 1:
                        print ('measure_phase(%d,%s) - new measurement'%(phase,str(force_meas)))
                else:
                    patt=dqsi_cache[dqs_idly]
                    if quiet < 1:
                        print ('measure_patt(%d,%s) - using cache'%(phase,str(force_meas)))
                return patt
            def get_bit_diffs(dqs_idly0,dqs_idly1,branch):
                patt0=measure_dqsi(dqs_idly0,branch)
                patt1=measure_dqsi(dqs_idly1,branch)
                if (patt0 is None) or (patt1 is None):
                    raise Exception("Tried to compare invalid(s): dqs_idly0=%d, dqs_idly1=%d, branch=%s"%(dqs_idly0, dqs_idly1, branch))
                rslt=[0]*16
                for i in range (nrep*8): # with 8 nursts - 64 x16-bit words
                    diffs=patt0[i] ^ patt1[i]
                    for b in range(len(rslt)):
                        rslt[b]+= (diffs >> b) & 1
                return rslt        
            def get_lane_diffs(dqs_idly0,dqs_idly1,branch):
                diffs= get_bit_diffs(dqs_idly0,dqs_idly1,branch)
#                lane_diffs=[0]*(len(diffs)//8)
                lane_diffs=[]
                for lane in range(len(diffs)//8):
                    num_diffs=0   
                    for b in range(8):
                        num_diffs += (0,1)[diffs[8*lane+b] != 0]
                    lane_diffs.append(num_diffs)
                if quiet <3:
                    print ("%d ? %d : %s"%(dqs_idly0,dqs_idly1,lane_diffs))

                return lane_diffs
            def get_lane_adiffs(dqs_idly0,dqs_idly1,branch): # Assuming all 8 bits differ in the read data - check it in a single block? Write pattern?
                diffs=get_lane_diffs(dqs_idly0,dqs_idly1,branch)
                    
                return ((diffs[0]-4)/4.0,(diffs[1]-4)/4.0)
            # Set phase
            phase_ok=self.set_phase_with_refresh( # check result for not None
                               phase,
                               quiet)
            if not phase_ok:
                return None # no valid CMDA ODELAY exists for this phase 
            # try branches (will exit on first match)
            for branch in dqsi_lohi.keys():
                low=dqsi_lohi[branch][0]
                high=dqsi_lohi[branch][1]
                # start with low dqs idelay and increase it by 1 primary step until getting 2 results with no bit differences
                # (using both byte lanes now)
                for idly1 in range(low+NUM_FINE_STEPS,high,NUM_FINE_STEPS):
                    diffs=get_lane_diffs(idly1-NUM_FINE_STEPS,idly1,branch)
                    if diffs == [0,0]: # no bit diffs in both byte lanes
                        low=idly1
                        break
                else: #failed to find two delays to get the same read results (no bit differences in both lanes)
                    continue
                # got both byte lanes with no difference, now try to find dqs_idelay delay where both bytes differ
                for idly in range(low,high,dly_step):
                    idly1=min(idly+dly_step,high)
                    diffs=get_lane_diffs(low,idly1,branch)
                    if (diffs[0] != 0) and (diffs[1] != 0):
                        high=idly1
                        break
                    elif (diffs[0] == 0) and (diffs[1] == 0):
                        low=idly1 # move low higher
                else: #failed to find another delay to get different read results (both myte lanes have bit differences
                    continue
                if quiet <3:
                    print ("0: low=%d, high=%d"%(low,high))
                low_safe=low # safe low
                # now find marginal dqs idelay for each byte lane by dividing (low,high) interval
                #reduce low,high range for combined lanes
                dly = high
                while low < dly: # first adjust low
                    dly_next = (low+dly) // 2
                    diffs=get_lane_diffs(low,dly_next,branch)
                    if (diffs[0] != 0) and (diffs[1] != 0):
                        dly = dly_next
                        high= dly
                    elif (diffs[0] == 0) and (diffs[1] == 0):
                        if low == dly_next:
                            break
                        low = dly_next # move low higher
                    else: # one byte matches, other - not (uncertain)
                        dly = dly_next
                dly = low
                while dly < high: # now adjust high
                    dly_next = (high+dly) // 2
                    diffs=get_lane_diffs(low_safe,dly_next,branch)
                    if (diffs[0] != 0) and (diffs[1] != 0):
                        high= dly_next
                    else: 
                        if dly == dly_next:
                            break
                        dly = dly_next # move low higher
                #low, high are now closer, now scan and store (delay,num_bits) for each lane
                #May be check maximal number of bits that mismatch for each lane? Now assuming that it can be up to all 8
#                low -= NUM_FINE_STEPS
#                low =  max(dqsi_lohi[branch][0], low - NUM_FINE_STEPS ) # try to move lower by the fine steps interval, if possible
#                high = min(dqsi_lohi[branch][1], high+ NUM_FINE_STEPS ) # try to move higher by the fine steps interval, if possible
                if quiet <3:
                    print ("1: low=%d(%d), high=%d"%(low,low_safe,high))
                high = min(dqsi_lohi[branch][1], high+ 2*NUM_FINE_STEPS ) # try to move higher by the fine steps interval, if possible
                if quiet <3:
                    print ("2: low=%d(%d), high=%d"%(low,low_safe,high))
                rslt=[]
                bestDly=[None]*2 # [low_safe]*2 # otherwise may fail - check it?
                bestDiffs=[None]*2
                comp_step=(1,NUM_FINE_STEPS)[compare_prim_steps]
                lastPositive=[0]*2
                for dly in range (low, high+1):
                    ref_dly= dly-comp_step
                    if ref_dly < low_safe:
                        continue
                    if quiet <2:
                        print ("dly=%d, ref_dly=%d"%(dly, ref_dly),end=" ")
                    adiffs= get_lane_adiffs(low_safe,dly,branch)
                    adiffs_ref=get_lane_adiffs(low_safe,ref_dly,branch)
                    for i, diff in enumerate(adiffs):
                        if diff > 0:
                            lastPositive[i] += 1
                        else:
                            lastPositive[i] = 0
                        
                    for lane in range(len(adiffs)):
                        diffs_prev_this=(adiffs_ref[lane],adiffs[lane])
                        if (diffs_prev_this[0] <= 0) and (diffs_prev_this[1] >= 0): 
                            if abs(diffs_prev_this[0]) <= abs(diffs_prev_this[1]): # store previous sample
                                if (bestDiffs[lane] is None) or (abs (diffs_prev_this[0]) < abs(bestDiffs[lane])):
                                    bestDly[lane]=ref_dly # dly-1/dly-NUM_FINE_STEPS
                                    bestDiffs[lane]=diffs_prev_this[0]
                            else:
                                if (bestDiffs[lane] is None) or (abs (diffs_prev_this[1])<abs(bestDiffs[lane])):
                                    bestDly[lane]=dly # dly-1
                                    bestDiffs[lane]=diffs_prev_this[1]
#                    if (adiffs[0] > 0) and (adiffs[1] > 0):
                    if (lastPositive[0] > NUM_FINE_STEPS) and (lastPositive[0] > NUM_FINE_STEPS):
                        break # no need to continue, data got already 
                for lane in range(len(adiffs)):
                    if bestDiffs[lane] == -1.0:
                        bestDiffs[lane] = None # single step jumps from none to all            
                    rslt.append((bestDly[lane],bestDiffs[lane],branch[0])) # adding first letter of branch name
                    if quiet <3:
                        print ("bestDly[%d]=%s, bestDiffs[%d]=%s, branch=%s"%(lane,str(bestDly[lane]),lane,str(bestDiffs[lane]),branch))
                if quiet <3:
                    print ('dly=%d rslt=%s'%(dly,str(rslt)))                    
                        
                if quiet < 2:
                    for i,d in enumerate(dqsi_cache):
                        if d:
                            print ("%d %s  %d: %s"%(phase,branch,i,str(d)))
                return rslt
            return None # All Early/Nominal/Late variants were exhausted, did not find critical DQS input delay for this phase value 
        # body of the  measure_dqs_idly_phase()
        dqsi_vs_phase=[]
        for phase in range (numPhaseSteps):
            if quiet <2:
                print ("====== PHASE=%d ======"%(phase))

            elif quiet < 3:
                print ("%d:"%(phase),end=" ")
                sys.stdout.flush()
            elif quiet < 5:
                print (".",end="")
                sys.stdout.flush()
            dqsi_vs_phase.append(dqsi_phase_step (phase))
                    
        if quiet < 3 :
            print ("dqsi_vs_phase=%s"%(str(dqsi_vs_phase)))
            print("Phase DQSI0 DQSI1 diff0 diff1 branch0 branch1")
            for phase,v in enumerate(dqsi_vs_phase):
                print("%d"%(phase), end=" ")
                if v:
                    print ("%s %s %s %s %s %s"%(str(v[0][0]),str(v[1][0]),str(v[0][1]),str(v[1][1]), v[0][2], v[1][2]))
                else:
                    print()
        elif quiet < 5:
            print ()
        self.adjustment_state['dqsi_vs_phase']=      dqsi_vs_phase
        self.adjustment_state['dqsi_vs_phase_steps']=compare_prim_steps            
        return dqsi_vs_phase        
                
                    
    def measure_dqo_dqso(self,
                               compare_prim_steps = True, # while scanning, compare this delay with 1 less by primary(not fine) step,
                                                # save None for fraction in unknown (previous -0.5, next +0.5) 
                               frac_step=0.125,
                               sel=1,
                               quiet=1,
                               start_dly=0): #just to check dependence

        """
        Scan dqs odelay (setting phase appropriately), write
        0x0000/0xffff/0x0000/0xffff (same as fixed pattern) data and read it with known dqsi/dqi
        values (maybe even set different phase for read?), discarding first and last 1.5 8-bursts
        Measure 4 different transitions for each data bit (rising DQS/rising DQ, falling DQS/falling DQ,
        rising DQS/falling DQ and falling DQS/rising DQ (that allows to measure duty cycles fro both
        DQS and DQ lines
        @param quiet reduce output
        """
#        self.load_hardcoded_data() # TODO: REMOVE LATER
        try:
            dqi_dqsi=self.adjustment_state['dqi_dqsi']
        except:
            print ("No DQ IDELAY vs. DQS IDELAY data available, exiting")
            return
        dqsi_phase=self.adjustment_state['dqsi_phase']
        num_lanes=len(dqsi_phase)
        cmda_bspe=self.adjustment_state['cmda_bspe']
        
                # Replacement for older  wlev_dqs_bspe=self.adjustment_state['wlev_dqs_bspe']
        # Can be improved
        try:
            wlev_p_l=   self.get_delays_for_phase(phase = None,
                                                  list_branches=False,
                                                  target=DQSO_KEY,
                                                  b_filter=DFLT_DLY_FILT,
                                                  cost=None, # if None - will default to NUM_FINE_STEPS, if 0 - will keep it 
                                                  quiet = quiet+1)
        except:
            raise Exception ("No write levelling data is available, this method should run after write levelling and proc_dqso_phase")
        numLanes=max(len(wp) for wp in wlev_p_l if not wp is None)
        if quiet < 1:    
            print("numLanes=",numLanes)
#        wlev_dqs_bspe=self.adjustment_state['wlev_dqs_bspe']
        
        brc=(5,        # 3'h5,     # bank
             0x1234,   # 15'h1234, # row address
             0x100)     # 10'h100   # column address
        nrep=8 # number of 8-bursts to compare (actual will have 3 more, first/last will be discarded
        extraTgl=0 # data is repetitive,so extra toggle is not needed (an there is an extra 8-burst anyway)
        timing=self.x393_mcntrl_timing.get_dly_steps()
        dly_step=int(NUM_FINE_STEPS*frac_step*timing['SDCLK_PERIOD']/timing['DLY_STEP']+0.5)
        numPhaseSteps= int(timing['SDCLK_PERIOD']/timing['PHASE_STEP']+0.5)
        step180= int(NUM_FINE_STEPS*0.5* timing['SDCLK_PERIOD'] / timing['DLY_STEP'] +0.5)                                                                                                                                                                                                                 
        try:
            dqs_patt=self.adjustment_state["dqs_pattern"]
            self.x393_mcntrl_timing.axi_set_dqs_dqm_patterns(dqs_patt=dqs_patt,
                                                             dqm_patt=None,
                                                             quiet=quiet+2)
            
        except:
            print("Skipping DQS pattern (0x55/0xaa) control as it is not in gloabal data (dqs_patt=self.adjustment_state['dqs_pattern'])")
            dqs_patt=None
        
        #Calculate phase for the best match for the DQS output delay (for both lanes - use average). If
        # solution for different lanes point to the opposite ends of the phase range - keep previous
        # do not look outside of +/- frac_step 
        def get_phase_for_dqso():
            phase_dqso=[]
            last_phase=0
            for dly in range(NUM_DLY_STEPS):
                best_phases= []
                for lane in range(num_lanes):
                    best_diff= frac_step*NUM_DLY_STEPS
                    best_phase=None
                    for phase in range(numPhaseSteps):
                        try:
                            dly_phase=wlev_p_l[phase][lane] # wlev_dqs_bspe[lane][phase]['ldly']
                        except:
                            dly_phase=None
                        if (not dly_phase is None) and (cmda_bspe[phase % numPhaseSteps] is None): # check that CMDA odelay exists for this phase
                            dly_phase=None
                        """    
                        # Make sure that dqsi and dqi exist for the phase
                        if dqsi_dqi_for_phase[phase] is None:
                            dly_phase=None
                        if dly==65:
                            print("lane=%d dly=%d, dqsi_dqi_for_phase[%d]=%s (%s)"%(lane, dly,phase,str(dqsi_dqi_for_phase[phase]),str(dly_phase)))
                        """                            
                        if not dly_phase is None:
                            adiff=abs(dly_phase-dly)
                            if adiff < best_diff:
                                best_diff = adiff
                                best_phase = phase
                    if best_phase is None:
                        best_phases=None # At least one of the lanes does not have an acceptable solution (should not normally happen)
                        break
#                    print("lane=%d dly=%d, best_phase=%s best_diff=%s"%(lane, dly,str(best_phase),str(best_diff)))                        
                    best_phases.append(best_phase)
                if best_phases is None:
                    phase_dqso.append(None)
                    continue
                else:
                    diff_per= max(best_phases)-min(best_phases) > numPhaseSteps/2 # different ends
                        #find which one is closer to last_phase, modify the other one by +/- period
                    sp=0.0
                    for lane in range(num_lanes):
                        if diff_per and (best_phases[lane] >= numPhaseSteps/2):
                            best_phases[lane] -= numPhaseSteps
                        sp+=best_phases[lane]
                    sp /= num_lanes # average phase for all lanes
                    sp=int(round(sp))
                    # only if results for lanes are on the different ends - if they agree - just take an average
                    if diff_per and (abs(sp-last_phase) > abs(sp+numPhaseSteps-last_phase)):
                        sp += numPhaseSteps 
                    sp=max(sp,0)
                    # May be that both best phases were OK, but their average falls into the gap - find closest
                    if dqsi_dqi_for_phase[sp] is None:
                        best_dist=numPhaseSteps
                        best_phase=None
                        for phase in range(numPhaseSteps):
                            if not dqsi_dqi_for_phase[phase] is None:
                                dist = min(abs(phase-sp),abs(phase+numPhaseSteps-sp),abs(phase-numPhaseSteps-sp))
                                if dist < best_dist:
                                    best_dist=dist
                                    best_phase=phase
                        if best_dist >= frac_step*numPhaseSteps:
#                            print("Could not find phase substitute for %d, %s is too far "%(sp, str(best_phase)))
                            best_phase=None
#                        else:
#                            print("Using substitute %d for %d"%(best_phase,sp))
                        sp=  best_phase 

                    sp=min(sp,numPhaseSteps-1)
#                    print("dly=%d best_phases=%s"%(dly, str(best_phases)))    
                    phase_dqso.append(sp)
            return phase_dqso
        
        def get_dqsi_dqi_for_phase():
            # Mark DQS idelay values that have all DQ delays valid
            # for each phase check that DQS input delay value exists and store DQi varinat (early/nominal/late
            dqsi_dqi_phase=[None]*numPhaseSteps
            inv_vars=('early','late') 
            for phase in range (numPhaseSteps):
#                print (phase, end=" ")
                dqsi=[]
                for lane_data in dqsi_phase:
                    dqsi.append(lane_data[phase])
                if None in dqsi:
                    continue # Keep False
                for k, dqi_dqsi_v in dqi_dqsi.items():
#                    print (" k=%s"%(k), end=" ")
                    if not dqi_dqsi_v:
                        continue # need to continue with next phase
                    dqi=[]
                    for lane, dqsi_lane in enumerate(dqsi):
#                        print (" lane=%d"%(lane), end=" ")
                        dq_lane=dqi_dqsi_v[dqsi_lane] #list of 16 DQ values for dqsi_lane or None 
                        if (dq_lane is None) or (None in dq_lane[8*lane:8*(lane+1)]):
                            break
                        dqi += dq_lane[8*lane:8*(lane+1)]
                    else:
                        dqsi_dqi_phase[phase]={DQSI_KEY:dqsi,
                                               DQI_KEY:dqi,
                                               'invert':k in inv_vars,
                                               'variant':k } # dqsi - a pair of dqs input delays, dqi - dq delays for the same phase
                        break
#                print()
            return dqsi_dqi_phase
            
        def dqs_step(dqs_lin):
            patt_cache=[None]*NUM_DLY_STEPS # cache for holding already measured delays
            def measure_block(dly,invert_patt, force_meas=False):
                if (patt_cache[dly] is None) or force_meas:
                    self.x393_mcntrl_timing.axi_set_dq_odelay(combine_delay(dly),quiet=quiet)
                    self.x393_pio_sequences.write_block() #page= 0, wait_complete=1)
                    patt= self.x393_pio_sequences.read_levelling(nrep,
                                                                 -2, # Actually read block, but pre-process as a pattern  
                                                                 quiet+1)
                    #invert pattern if using early/late (not nominal) variants
#                    if (invert_patt):
#                        for i in range(len(patt)):
#                            patt[i]=1.0-patt[i]
                    patt_cache[dly]=patt
                    if quiet < 1:
                        print ('measure_block(%d,%s) - new measurement'%(dly,str(force_meas)))
                else:
                    patt=patt_cache[dly]
                    if quiet < 1:
                        print ('measure_block(%d,%s) - using cache'%(dly,str(force_meas)))
                return patt
            def get_sign(data,edge=None):
                """
                edge: 0 - first 16, 1 - second 16
                return -1 if  all <0.5
                return +1 if all >0.5
                return 0 otherwise
                """
                if edge == 0:
                    return get_sign(data[:16])
                if edge == 1:
#                    return -get_sign(data[16:])
                    return get_sign(data[16:])
                m1=True
                p1=True
                for d in data:
                    m1 &= (d < 0.5)
                    p1 &= (d > 0.5)
                    if not (m1 or p1):
                        break
                else:
                    if m1:
                        return -1
                    elif p1:
                        return 1
                return 0
            
            rslt=[None]*16 # each bit will have [inphase][dqs_falling]
            self.x393_mcntrl_timing.axi_set_dqs_odelay(combine_delay(dqs_lin),quiet=quiet)
            #set phase, cmda_odelay, dqsi, dqi to match this delay
            phase=phase_dqso[dqs_lin]
            if phase is None: # no good phase exist for the specified dqs_odelay
                if quiet <2:
                    print("No dood phase for DQS odelay = %d"%(dqs_lin))
                return None
            # set phase
            # TODO: maybe keep last phase set and do not change it if required is not too far from the last set
            # Set phase (and cmda_odelay as needed)
            if quiet < 2:
                print ("set_phase_with_refresh(%d), dqs_odelay=%d"%(phase,dqs_lin))
            phase_ok=self.set_phase_with_refresh( # check result for not None
                               phase,
                               quiet)
            if not phase_ok:
                print ("Failed to set phase=%d for dly=%d- that should not happen (phase_dqso)- "%(phase,dqs_lin))
                return None # no valid CMDA ODELAY exists for this phase
            #set DQS IDELAY and DQ IDELAY matching phase 
            dqs_idelay=dqsi_dqi_for_phase[phase][DQSI_KEY] # 2-element list
            dq_idelay= dqsi_dqi_for_phase[phase][DQI_KEY]  # 16-element list
            invert_patt= dqsi_dqi_for_phase[phase]['invert']  # 16-element list
            self.x393_mcntrl_timing.axi_set_dqs_idelay(combine_delay(dqs_idelay),quiet=quiet)
            self.x393_mcntrl_timing.axi_set_dq_idelay(combine_delay(dq_idelay),quiet=quiet)

            
            
            d_low=[None]*2  # first - lowest when all are -+, second - when all are +-  
            d_high=[None]*2 # first - when all are +- after -+, second - when all are -+ after +-
            dly=0
            notLast=True
            needSigns=None
            lowGot=None
            highGot=None
            while (dly < NUM_DLY_STEPS) and notLast:
                notLast= dly < NUM_DLY_STEPS-1
                patt=measure_block(dly,invert_patt) # ,force_meas=False)
                signs=(get_sign(patt,0),get_sign(patt,1))
                if quiet < 1:
                    print ('dly=%d lowGot=%s, highGot=%s, signs=%s'%(dly,str(lowGot),str(highGot),str(signs)))
                if lowGot is None : # looking for the first good sample
                    if (signs==(-1,1)) or  (signs==(1,-1)) :
                        if signs[0] == -1: #  == (-1,1):
                            lowGot=0
                        else:
                            lowGot=1
                        d_low[lowGot] = dly
                        needSigns=((1,-1),(-1,1))[lowGot]
                        dly += step180-dly_step # almost 180 degrees
                    else: # at least one is 0
                        dly += dly_step # small step
                    if quiet < 1:
                        print ('lowGot was None : dly=%d, lowGot=%s, needSigns=%s'%(dly,str(lowGot),str(needSigns)))
                elif highGot is None : # only one good sample is available so far
                    if signs == needSigns:
                        highGot=lowGot
                        d_high[highGot] = dly
                        d_low[1-lowGot] = dly
                        needSigns=((-1,1),(1,-1))[lowGot]
                        dly += step180-dly_step # almost 180 degrees
                    else:
                        dly += dly_step # small step
                    if quiet < 1:
                        print ('highGot was None : dly=%d, lowGot=%s, highGot=%s, needSigns=%s'%(dly,str(lowGot),str(lowGot),str(needSigns)))
                else: # looking for the 3-rd sample 
                    if signs == needSigns:
                        highGot=1-highGot
                        d_high[highGot] = dly
                        break
                    else:
                        dly += dly_step # small step
                dly = min (dly,NUM_DLY_STEPS-1)
            if highGot is None:
                if quiet < 3:
                    print ("Could not find initial bounds for DQS output delay = %d d_low=%s, d_high=%s"%(dqs_lin,str(d_low),str(d_high)))
                return None
            if quiet < 2:
                    print ("DQS outut delay = %d , preliminary bounds: d_low=%s, d_high=%s"%(dqs_lin,str(d_low),str(d_high)))
            for inPhase in range(2):
                if not d_high[inPhase] is None:
                    # Try to squeeze d_low, d_high closer to reduce scan range
                    while d_high[inPhase]>d_low[inPhase]:
                        dly=(d_high[inPhase] + d_low[inPhase])//2
                        patt=measure_block(dly,invert_patt) # ,force_meas=False)
                        signs=(get_sign(patt,0),get_sign(patt,1))
                        if signs==(-1,1):
                            if inPhase:
                                d_high[inPhase]=dly 
                            else:
                                if d_low[inPhase]==dly:
                                    break
                                d_low[inPhase]=dly 
                        elif signs==(1,-1):     
                            if inPhase:
                                if d_low[inPhase]==dly:
                                    break
                                d_low[inPhase]=dly 
                            else:
                                d_high[inPhase]=dly 
                        else: # uncertain result 
                            break
            if quiet < 2:
                    print ("DQS output delay = %d , squeezed bounds: d_low=%s, d_high=%s"%(dqs_lin,str(d_low),str(d_high)))
#Improve squeezing - each limit to the last
            for inPhase in range(2):
                if not d_high[inPhase] is None:
                    # Try to squeeze d_low first
                    d_uncertain=d_high[inPhase]
                    while d_uncertain > d_low[inPhase]:
                        dly=(d_uncertain + d_low[inPhase])//2
                        patt=measure_block(dly,invert_patt) # ,force_meas=False)
                        signs=(get_sign(patt,0),get_sign(patt,1))
                        if signs==(-1,1):
                            if inPhase:
                                d_uncertain=dly 
                            else:
                                if d_low[inPhase]==dly:
                                    break
                                d_low[inPhase]=dly 
                        elif signs==(1,-1):     
                            if inPhase:
                                if d_low[inPhase]==dly:
                                    break
                                d_low[inPhase]=dly 
                            else:
                                d_uncertain=dly 
                        else: # uncertain result
                            d_uncertain=dly
                    #now udjust upper limit
                    while d_high[inPhase] > d_uncertain:
                        dly=(d_high[inPhase] + d_uncertain)//2
                        patt=measure_block(dly,invert_patt) # ,force_meas=False)
                        signs=(get_sign(patt,0),get_sign(patt,1))
                        if signs==(-1,1):
                            if inPhase:
                                d_high[inPhase]=dly 
                            else:
                                if d_uncertain==dly:
                                    break
                                d_uncertain=dly 
                        elif signs==(1,-1):     
                            if inPhase:
                                if d_uncertain==dly:
                                    break
                                d_uncertain=dly 
                            else:
                                d_high[inPhase]=dly 
                        else: # uncertain result 
                            if d_uncertain==dly:
                                break
                            d_uncertain=dly
            if quiet < 2:
                    print ("DQS output delay = %d , tight squeezed bounds: d_low=%s, d_high=%s"%(dqs_lin,str(d_low),str(d_high)))

#            if resetCacheBeforeScan:
#                patt_cache=[None]*NUM_DLY_STEPS # cache for holding already measured delays
            # scan ranges, find closest solutions
            #compare_prim_steps
            best_dly= [[],[]]
            best_diff=[[],[]]
            for inPhase in range(2):
                if not d_high[inPhase] is None:
                    best_dly[inPhase]=[d_low[inPhase]]*32
                    best_diff[inPhase]=[None]*32
                    for dly in range(d_low[inPhase]+1,d_high[inPhase]+1):
                        #as measured data is cached, there is no need to specially maintain patt_prev from earlier measurement
                        dly_prev= max(0,dly-(1,NUM_FINE_STEPS)[compare_prim_steps])
                        patt_prev=measure_block(dly_prev,invert_patt) # ,force_meas=False) - will be stored in cache
                        patt=     measure_block(dly,invert_patt) # ,force_meas=False) - will be stored in cache
                        for b in range(32):
                            positiveJump=((not inPhase) and (b<16)) or (inPhase and (b >= 16)) # may be 0, False, True       
                            signs=((-1,1)[patt_prev[b]>0.5],(-1,1)[patt[b]>0.5])
                            if (positiveJump and (signs==(-1,1))) or (not positiveJump and (signs==(1,-1))):
                                if positiveJump:
                                    diffs_prev_this=(patt_prev[b]-0.5,patt[b]-0.5)
                                else:
                                    diffs_prev_this=(0.5-patt_prev[b],0.5-patt[b])
                                if abs(diffs_prev_this[0]) <= abs(diffs_prev_this[1]): # store previous sample
                                    if (best_diff[inPhase][b] is None) or (abs (diffs_prev_this[0])<abs(best_diff[inPhase][b])):
                                        best_dly[inPhase][b]=dly_prev # dly-1
                                        best_diff[inPhase][b]=diffs_prev_this[0]
                                        if quiet < 1:
                                            print ("*%d:%0.3f:%0.3f%s"%(b,diffs_prev_this[0],diffs_prev_this[1],str(signs)),end="")
                                else:
                                    if (best_diff[inPhase][b] is None) or (abs (diffs_prev_this[1])<abs(best_diff[inPhase][b])):
                                        best_dly[inPhase][b]=dly # dly-1
                                        best_diff[inPhase][b]=diffs_prev_this[1]
                                        if quiet < 1:
                                            print ("?%d:%0.3f:%0.3f%s"%(b,diffs_prev_this[0],diffs_prev_this[1],str(signs)),end="")
                        if quiet < 1:
                            print("\n dly=%d dly_prev=%d:"%(dly,dly_prev),end=" ")
                    for b in range(32):
                        if  best_diff[inPhase][b] == -0.5:
                            best_diff[inPhase][b] = None # will have to add half-interval (0.5 or 2.5) 
                # rslt=[None]*16 # each bit will have [inphase][dqs_falling], each - a pair of (delay,diff)
            for b in range(16):
                rslt[b]=[[None]*2,[None]*2] # [inphase][dqs_falling]
                for inPhase in range(2):
                    if not d_high[inPhase] is None:
                        rslt[b][inPhase]= [(best_dly[inPhase][b],best_diff[inPhase][b]),(best_dly[inPhase][b+16],best_diff[inPhase][b+16])]
            if quiet < 2:
                    print ("%d: rslt=%s"%(dqs_lin,str(rslt)))
            return rslt

        # main method code
        #dqs_patt
        #TODO: invert pattern if dqs_patt == 0xaa?               
        if quiet<2:
            print ("timing=%s, dly_step=%d step180=%d"%(str(timing),dly_step,step180))
        wdata16=(0,0xffff)*(4*(nrep+3))
        wdata32=convert_mem16_to_w32(wdata16)
        dqsi_dqi_for_phase=get_dqsi_dqi_for_phase()
        phase_dqso=get_phase_for_dqso() # uses dqsi_dqi_for_phase
        if quiet < 2:
            for i, v in enumerate(phase_dqso):
                print("%d %s"%(i,str(v)))
            for p, v in enumerate(dqsi_dqi_for_phase):
                print("%d"%(p),end=" ")
                if v:
                    for dqsi in v[DQSI_KEY]:
                        print(dqsi,end=" ") 
                    for dqi in v[DQI_KEY]:
                        print(dqi,end=" ") 
                    print(v['invert'],end=" ")
                    print(v['variant'],end=" ")
                print()
        if self.DRY_MODE:        
            return
        
        self.x393_mcntrl_buffers.write_block_buf_chn(0,0,wdata32,quiet); # fill block memory (channel, page, number)
        self.x393_pio_sequences.set_write_block(*(brc+(nrep+3,extraTgl,sel))) # set sequence once
        self.x393_pio_sequences.set_read_block(*(brc+(nrep+3,sel))) # set sequence once
        #With the data to write being the same as pattern data, try using the same measurements as for the pattern
 
        meas_data=[None]*(NUM_DLY_STEPS)
        #start_dly
        for sdly in range(NUM_DLY_STEPS):
            ldly = (start_dly+sdly)%(NUM_DLY_STEPS)
#        for ldly in range(max_lin_dly+1):
            if quiet <3:
                print ("%d(0x%x):"%(ldly,combine_delay(ldly)),end=" ")
                sys.stdout.flush()
            elif quiet < 5:
                print (".",end="")
                sys.stdout.flush()
            meas_data[ldly] = dqs_step(ldly)
        if quiet < 5:
            print ()

        if quiet < 3:
            print("\n\nMeasured data, integer portion, measured with %s steps"%(("fine","primary")[compare_prim_steps]))
            print ("DQS",end=" ")
            for f in ('ir','if','or','of'):
                for b in range (16):
                    print ("%s_%d"%(f,b),end=" ")
            print()        
            for ldly, data in enumerate(meas_data):
                print("%d"%ldly,end=" ")
                if data:
                    for typ in ((0,0),(0,1),(1,0),(1,1)):
                        for pData in data: # 16 DQs, each None nor a pair of lists for inPhase in (0,1), each a pair of edges, each a pair of (dly,diff)
                            if pData:
                                if pData[typ[0]] and pData[typ[0]][typ[1]]:
                                    print ("%d"%pData[typ[0]][typ[1]][0],end=" ")
                                    '''
                                    try:
                                        print ("%d"%pData[typ[0]][typ[1]][0],end=" ")
                                    except:
                                        print (".", end=" ")
                                    '''
                                else:
                                    print ("?", end=" ")
                            else:
                                print ("x",end=" ")
                        
                print()
        if quiet < 2:
            print("\n\nMasked measured data, integer portion, measured with %s steps"%(("fine","primary")[compare_prim_steps]))
            for f in ('ir','if','or','of'):
                for b in range (16):
                    print ("%s_%d"%(f,b),end=" ")
            print()        
            for ldly, data in enumerate(meas_data):
                print("%d"%ldly,end=" ")
                if data:
                    for typ in ((0,0),(0,1),(1,0),(1,1)):
                        for pData in data: # 16 DQs, each None nor a pair of lists for inPhase in (0,1), each a pair of edges, each a pair of (dly,diff)
                            if pData:
                                if pData[typ[0]] and pData[typ[0]][typ[1]] and (not pData[typ[0]][typ[1]][1] is None):
                                    print ("%d"%pData[typ[0]][typ[1]][0],end=" ")
                                    '''
                                    try:
                                        print ("%d"%pData[typ[0]][typ[1]][0],end=" ")
                                    except:
                                        print (".", end=" ")
                                    '''
                                else:
                                    print ("?", end=" ")
                            else:
                                print ("x",end=" ")
                        
                print()
                    
        if quiet < 2:
            print ("\nDifferences from 0.5:")

            print ("DQS",end=" ")
            for f in ('ir','if','or','of'):
                for b in range (16):
                    print ("%s_%d"%(f,b),end=" ")
            print()        
            for ldly, data in enumerate(meas_data):
                print("%d"%ldly,end=" ")
                if data:
                    for typ in ((0,0),(0,1),(1,0),(1,1)):
                        for pData in data: # 16 DQs, each None nor a pair of lists for inPhase in (0,1), each a pair of edges, each a pair of (dly,diff)
                            if pData:
                                if pData[typ[0]] and pData[typ[0]][typ[1]] and (not pData[typ[0]][typ[1]][1] is None):
                                    print ("%.2f"%pData[typ[0]][typ[1]][1],end=" ")
                                    '''
                                    try:
                                        print ("%d"%pData[typ[0]][typ[1]][0],end=" ")
                                    except:
                                        print (".", end=" ")
                                    '''
                                else:
                                    print ("?", end=" ")
                            else:
                                print ("x",end=" ")
                        
                print()
        if quiet < 3:
            print("\n\nMeasured data, comparing current data with the earlier by one %s step"%(("fine","primary")[compare_prim_steps]))
            print("When the fractional (second in the tuple) data is exactly -0.5, the actual result is in the range %s from the integer delay"%
                  (("+0.0..+1.0","+0.0..+%d"%NUM_FINE_STEPS)[compare_prim_steps]))
            print ("meas_data=[")
            for d in meas_data:
                print("%s,"%(str(d)))
            print("]")
        rdict={"write_prim_steps":    compare_prim_steps,
               "write_meas_data":     meas_data} # TODO: May delete after LMA fitting
        self.adjustment_state.update(rdict)
    
    def measure_addr_odelay(self,
                            safe_phase=0.25, # 0 strictly follow cmda_odelay, >0 -program with this fraction of clk period from the margin
                            dqsi_safe_phase=0.125, # > 0 - allow DQSI with DQI simultaneously deviate  +/- this fraction of a period   
                            ra = 0,
                            ba = 0,
                            quiet=1,
                            single=False):
#                            quiet=0):
        """
        Will raise exception if read non good or bad - that may happen if cmda_odelay is violated too much. Need to re-
        init memory if that happems and possibly re-run with largersafe_phase or safe_phase==0/None to disable this feature
        Final measurement of output delay on address lines, performed when read/write timing is set
        Writes different data in the specified block and then different pattern to all blocks different
        by one row address or bank address bit.
        Refresh is programmed to drive inverted ra and ba, so the lines have to switch during activate
        command of read block, and the too late switch can be detected as it will cause the different block to
        be read. Address and bank lines are tested with different delays, one bit at a time. 
        """
#        self.load_hardcoded_data() # TODO: TEMPORARY - remove later
            
        try:
            self.x393_mcntrl_timing.axi_set_dqs_dqm_patterns(dqs_patt=self.adjustment_state["dqs_pattern"],
                                                             dqm_patt=None,
                                                             quiet=quiet+2)
        except:
            print("Skipping DQS pattern (0x55/0xaa) control as it is not in gloabal data (dqs_patt=self.adjustment_state['dqs_pattern'])")

        num_ba=3
        if not single:
            pass1=self.measure_addr_odelay(safe_phase=safe_phase, #0.25, # 0 strictly follow cmda_odelay, >0 -program with this fraction of clk period from the margin
                                           dqsi_safe_phase=dqsi_safe_phase, 
                                           ra = ra, # 0,
                                           ba = ba, # 0,
                                           quiet=quiet+1, #1,
                                           single=True) # single=False)
            pass2=self.measure_addr_odelay(safe_phase=safe_phase, #0.25, # 0 strictly follow cmda_odelay, >0 -program with this fraction of clk period from the margin 
                                           dqsi_safe_phase=dqsi_safe_phase, 
                                           ra = ra ^ ((1 << vrlg.ADDRESS_NUMBER)-1), # 0,
                                           ba = ba ^ ((1 << num_ba)-1), # 0,
                                           quiet=quiet+1, #1,
                                           single=True) # single=False)
            self.adjustment_state['addr_meas']=[pass1,pass2]
            if (quiet<4):
                print ('addr_meas=[')
                for p in [pass1,pass2]:
                    print(p,",")
                print(']')

            if (quiet<4):
                num_addr=vrlg.ADDRESS_NUMBER
                num_banks=3
                print ("\n measured marginal addresses and bank adresses for each phase")
                print ("phase", end=" ")
                for edge in ("\\_","_/"):
                    for i in range (num_addr):
                        print("A%d%s"%(i,edge),end=" ")
                    for i in range (num_banks):
                        print("BA%d%s"%(i,edge),end=" ")
                print()
                    
                for phase in range (len(pass1)):
                    print ("%d"%(phase), end=" ")
                    for p in pass1,pass2:
                        for i in range (num_addr+num_banks):
                            try:
                                print ("%d"%(p[phase][i]),end=" ")
                            except:
                                print ("?", end=" ")
                    print()
            return [pass1,pass2]
        dly_steps=self.x393_mcntrl_timing.get_dly_steps()
        numPhaseSteps= int(dly_steps['SDCLK_PERIOD']/dly_steps['PHASE_STEP']+0.5)
        
        if dqsi_safe_phase:
            dqsi_safe_phase*=1000*dly_steps['SDCLK_PERIOD']
            if quiet<3:
                print("Using dqsi_safe_phase=%f ps"%(dqsi_safe_phase))
            maxPhaseErrorsPS=(None,dqsi_safe_phase,None)
        else:
            maxPhaseErrorsPS=None 

        nbursts=1 # just 1 full burst for block comparison(will write nbursts+3)
        sel_wr=1
        sel_rd=1
        extraTgl=0
        inv_ra=ra ^ ((1 << vrlg.ADDRESS_NUMBER)-1)
        ca= ra & ((1 << vrlg.COLADDR_NUMBER) -1)
        inv_ba=ba ^ ((1 << num_ba)-1)
        if not "cmda_bspe" in self.adjustment_state:
            raise Exception ("No cmda_odelay data is available. 'adjust_cmda_odelay 0 1 0.1 3' command should run first.")
        #create a list of None/optimal cmda determined earlier
        
        cmda_odly=     [None if (self.adjustment_state['cmda_bspe'][phase] is None) else self.adjustment_state['cmda_bspe'][phase]['ldly'] for phase in range(numPhaseSteps)]
        if safe_phase:
            cmda_odly_zerr=[None if (self.adjustment_state['cmda_bspe'][phase] is None) else self.adjustment_state['cmda_bspe'][phase]['zerr'] for phase in range(numPhaseSteps)]
            cmda_odly_early=[]
            for phase,zerr in enumerate (cmda_odly_zerr):
                if (not zerr is None) and (zerr < 0.5-safe_phase):
                    cmda_odly_early.append(0)
                else:
                    cmda_odly_early.append(cmda_odly[phase])
        else:
            cmda_odly_early=cmda_odly
#        cmda_odly=tuple(cmda_odly)
        if quiet <1:
            for phase,dly in enumerate(cmda_odly):
                ldly=None
                if not self.adjustment_state['cmda_bspe'][phase] is None:
                    ldly=self.adjustment_state['cmda_bspe'][phase]['ldly']
                print("%d %s %s"%(phase,str(dly),str(ldly)))
        
        dly_try_step=NUM_FINE_STEPS # how far to step when looking for zero crossing (from predicted)
        phase_try_step=numPhaseSteps//8 # when searching for marginal delay, try not optimal+perid/2 but smaller step to accommodate per-bit variations
        good_patt=0xaaaa
        bad_patt = good_patt ^ 0xffff
        # find first suitable phase
        for phase in range(numPhaseSteps):
            try:
                ph_dlys= self.get_all_delays(phase=phase,
                                             filter_cmda= DFLT_DLY_FILT, # may be special case: 'S<safe_phase_as_float_number>
                                             filter_dqsi= DFLT_DLY_FILT,
                                             filter_dqi=  DFLT_DLY_FILT,
                                             filter_dqso= DFLT_DLY_FILT, #None, # these are not needed here
                                             filter_dqo=  DFLT_DLY_FILT, #None,
                                             cost=        None,
                                             forgive_missing=False,
                                             maxPhaseErrorsPS = maxPhaseErrorsPS, #CMDA, DQSI, DQSO
                                             quiet=       quiet)
                if not ph_dlys is None:
                    break
            except:
                pass
        else:
            raise Exception("Could not find a valid phase to use")
        #phase is usable delay
        # reprogram refresh
        self.x393_axi_tasks.enable_refresh(0) # turn off refresh
        self.x393_pio_sequences.set_refresh(vrlg.T_RFC, # input [ 9:0] t_rfc; # =50 for tCK=2.5ns
                                            vrlg.T_REFI, #input [ 7:0] t_refi; # 48/97 for normal, 16 - for simulation
                                            0, #  en_refresh=0,
                                            inv_ra, # used only for calibration of the address line output delay
                                            inv_ba,
                                            0) # verbose=0
        # set usable timing, enable refresh
        if quiet <3 :
            print ("+++ dqsi_safe_phase=",dqsi_safe_phase)
        used_delays=self.set_delays(phase=phase,
                                    filter_cmda=DFLT_DLY_FILT, # may be special case: 'S<safe_phase_as_float_number>
                                    filter_dqsi=DFLT_DLY_FILT,
                                    filter_dqi= DFLT_DLY_FILT,
                                    filter_dqso=DFLT_DLY_FILT,
                                    filter_dqo= DFLT_DLY_FILT,
                                    cost=None,
                                    refresh=True,
                                    forgive_missing=True,
                                    maxPhaseErrorsPS=maxPhaseErrorsPS,
                                    quiet=quiet)
        if used_delays is None:
            raise Exception("measure_addr_odelay(): failed to set phase = %d"%(phase))  #      
        #Write 0xaaaa pattern to correct block (all used words), address number - to all with a single bit different
        self.x393_pio_sequences.set_read_block(ba,ra,ca,nbursts+3,sel_wr)
        #prepare and writ 'correct' block:
        wdata16_good=(good_patt,)*(8*(nbursts+3)) 
        wdata32_good=convert_mem16_to_w32(wdata16_good)
        wdata16_bad=(bad_patt,)*(8*(nbursts+3)) 
        wdata32_bad=convert_mem16_to_w32(wdata16_bad)
        comp32_good= wdata32_good[4:(nbursts*4)+4] # data to compare with read buffer - discard first 4*32-bit words and the "tail" after nrep*4 words32
        comp32_bad=  wdata32_bad[4:(nbursts*4)+4] # data to compare with read buffer - discard first 4*32-bit words and the "tail" after nrep*4 words32
        
        self.x393_mcntrl_buffers.write_block_buf_chn(0,0,wdata32_good,quiet) # fill block memory (channel, page, number)
        self.x393_pio_sequences.set_write_block(ba,ra,ca,nbursts+3,extraTgl,sel_wr) # set sequence to write 'correct' block
        self.x393_pio_sequences.set_read_block(ba,ra,ca,nbursts+3,sel_rd) # set sequence to read block (will always be the same address)
        self.x393_pio_sequences.write_block() #page= 0, wait_complete=1) # write 'correct' block
        #prepare and write all alternative blocks (different by one address/bank 
        self.x393_mcntrl_buffers.write_block_buf_chn(0,0,wdata32_bad,quiet) # fill block memory (channel, page, number)
        raba_bits=[]
#        print('vrlg.ADDRESS_NUMBER=',vrlg.ADDRESS_NUMBER)
#        print('num_ba=',num_ba)
        for addr_bit in range(vrlg.ADDRESS_NUMBER):
            raba_bits.append((addr_bit,None))
            ra_alt=ra ^ (1<<addr_bit)
            self.x393_pio_sequences.set_write_block(ba,ra_alt,ca,nbursts+3,extraTgl,sel_wr,(0,1)[quiet<2]) # set sequence to write alternative (by one address bit) block
            self.x393_pio_sequences.write_block() #page= 0, wait_complete=1) # write alternative block
        for bank_bit in range(num_ba):
            raba_bits.append((None,bank_bit))
            ba_alt=ra ^ (1<<bank_bit)
            self.x393_pio_sequences.set_write_block(ba_alt,ra,ca,nbursts+3,extraTgl,sel_wr,(0,1)[quiet<2]) # set sequence to write alternative (by one address bit) block
            self.x393_pio_sequences.write_block() #page= 0, wait_complete=1) # write alternative block
        # For each valid phase, set valid delays, then find marginal delay for one bit (start with the longest available delay?
        # if got for one bit - try other bits  in vicinity
        # check that the particular phase is valid for all parameters
        # To increase valid range it is possible to ignore write delays as they are not used here 

        def addr_phase_step(phase):
            def measure_block(dly,
                              addr_bit,
                              bank_bit,
                              force_meas=False):
                if (meas_cache[dly] is None) or force_meas:
                    for _ in range(5):
                        #set same delays for all cmda bits   (should be already done with 'set_phase_with_refresh'
                        if not addr_bit is None:
                            self.x393_mcntrl_timing.axi_set_address_odelay(combine_delay(dly),addr_bit,quiet=quiet)
                        elif not bank_bit is None:
                            self.x393_mcntrl_timing.axi_set_address_odelay(combine_delay(dly),bank_bit,quiet=quiet)
                        else:
                            raise Exception("BUG: both addr_bit and bank_bit are None")
                        if quiet < 1:
                            print ('measure_block(%d,%s) - new measurement'%(dly,str(force_meas)))
                        self.x393_pio_sequences.manual_refresh() # run refresh that sets address bit to opposite values to the required row+bank address
                        buf=self.x393_pio_sequences.read_block(4 * (nbursts+1) +2,
                                                               (0,1)[quiet<1], #show_rslt,
                                                               1) # wait_complete=1)
                        buf= buf[4:(nbursts*4)+4] # discard first 4*32-bit words and the "tail" after nrep*4 words32
                        if buf==comp32_good:
                            meas=True
                        elif buf==comp32_bad:
                            meas=False
                        else:
                            print ("Inconclusive result for comparing read data for phase=%d, addr_bit=%s, bank_bit=%s  dly=%d"%(phase,str(addr_bit),str(bank_bit),dly))
                            print ("Data read from memory=",buf, "(",convert_w32_to_mem16(buf),")")
                            print ("Expected 'good' data=",comp32_good, "(",convert_w32_to_mem16(comp32_good),")")
                            print ("Expected 'bad'  data=", comp32_bad, "(",convert_w32_to_mem16(comp32_bad),")")
                            meas=None
                        meas_cache[dly]=meas
                        if not meas is None:
                            break
                    else:
                        print("***** FAILED to get measurement ******")
#                        raise Exception("***** FAILED to get measurement ******")
                        meas=False
                else:
                    meas=meas_cache[dly]
                    if quiet < 1:
                        print ('measure_block(%d,%s) - using cache'%(dly,str(force_meas)))
                return meas
            # pass # addr_phase_step body
            # check that the particular phase is valid for all parameters
            # To increase valid range it is possible to ignore write delays as they are not used here
            # after write is done
            if quiet < 2:
                print ("****** phase=%d ******"%(phase),end=" ")
            # Remove try/except to troubleshoot newly introduced bugs                
            try:
                ph_dlys= self.get_all_delays(phase=phase,
                                             filter_cmda= DFLT_DLY_FILT, # may be special case: 'S<safe_phase_as_float_number>
                                             filter_dqsi= DFLT_DLY_FILT,
                                             filter_dqi=  DFLT_DLY_FILT,
                                             filter_dqso= None, # these are not needed here
                                             filter_dqo=  None,
                                             cost=        None,
                                             forgive_missing=False,
                                             maxPhaseErrorsPS = maxPhaseErrorsPS,
                                             quiet=       quiet)
                if ph_dlys is None:
                    if quiet < 1:
                        print ("get_all_delays(%d,...) is None"%(phase))
                    return None
                        
            except:
                print ("********** Failed get_all_delays(%d,...) is None"%(phase))
                return None
 
            dly_optimal= cmda_odly[phase]
            if dly_optimal is None:
                if quiet < 1:
                    print ("dly_optimal is None")
                return None
            # may increase range by using dly_optimal=0 until it is not dangerously late (say only 1/4 period off)
            phase_marg= (phase+ (numPhaseSteps//2)-phase_try_step) % numPhaseSteps
            if  cmda_odly[phase_marg] is None:
                phase_marg_traget=phase_marg
                phase_marg=None
                for p in range(numPhaseSteps):
                    if not cmda_odly[p is None]:
                        if (phase_marg is None) or (min(abs(p-phase_marg_traget),
                                                        abs(p-phase_marg_traget+numPhaseSteps),
                                                        abs(p-phase_marg_traget-numPhaseSteps)) < min(abs(phase_marg-phase_marg_traget),
                                                                                                      abs(phase_marg-phase_marg_traget+numPhaseSteps),
                                                                                                      abs(phase_marg-phase_marg_traget-numPhaseSteps))):
                            phase_marg=p
                else:
                    print("BUG: could to find a valid marginal phase")
                    return None
            # may increase range by using dly_optimal=0 until it is not dangerously late (say only 1/4 period off)
            dly_marg = cmda_odly[phase_marg]# - dly_try_step
            if dly_marg < dly_optimal:
                if cmda_odly_early[phase] < dly_marg:
                    dly_optimal=cmda_odly_early[phase]
                else:
                    if quiet < 1:
                        print ("dly_marg (==%d) < dly_optimal (==%d)"%(dly_marg,dly_optimal))
                    return None # It is not possble to try delay lower than optimal with this method
                
            #set phase and all optimal delays for that phase
            #here use special delays for cmda
            self.set_delays(phase=phase,
                            filter_cmda="S%f"%(safe_phase), # DFLT_DLY_FILT, # may be special case: 'S<safe_phase_as_float_number>
                            filter_dqsi=DFLT_DLY_FILT,
                            filter_dqi= DFLT_DLY_FILT,
                            filter_dqso=None, #DFLT_DLY_FILT,
                            filter_dqo= None, #DFLT_DLY_FILT,
                            cost=None,
                            refresh=True,
                            forgive_missing=True,
                            maxPhaseErrorsPS=maxPhaseErrorsPS,
                            quiet=quiet)
            if used_delays is None:
                raise Exception("measure_addr_odelay(): failed to set phase = %d"%(phase))        

            # Now try
            #raba_bits [(addr_bit,bank_bit),...]
            rslt=[]
            for addr_bit,bank_bit in raba_bits:
                if quiet < 1 :
                    print("\n===== phase=%d, dly_optimal=%d, addr_bit=%s, bank_bit=%s"%(phase, dly_optimal,str(addr_bit),str(bank_bit)))
                
                self.x393_mcntrl_timing.axi_set_cmda_odelay(combine_delay(dly_optimal),quiet=quiet) # set all bits to optimal delay
                meas_cache=[None]*NUM_DLY_STEPS # cache for holding results of already measured delays, new cach for each address bit
#                ts=dly_try_step
                dly=dly_marg
                dly_low=None #dly
                dly_high=None# dly
                
                while ((dly_low is None) or (dly_high is None)) and (dly > dly_optimal) and (dly < NUM_DLY_STEPS):
                    meas=measure_block(dly,
                                  addr_bit,
                                  bank_bit)
                    if meas :
                        if dly==(NUM_DLY_STEPS-1):
                            dly = None
                            break
                        dly_low=dly
                        dly=min(NUM_DLY_STEPS-1,dly+dly_try_step)
                    else:                        
                        dly_high=dly
                        dly=max(dly_optimal,dly-dly_try_step)
                if quiet < 1 :
                    print ("dly_low=%s, dly_high=%s, dly=%s"%(str(dly_low),str(dly_high),str(dly)))
                if (dly_low is None) or (dly_high is None): # dly is None:
                    rslt.append(None)
                    continue
                #find highest delay that is lower than margin (here delay monotonicity is assumed!)
                while dly_low < (dly_high-1):
                    dly=(dly_low+dly_high)//2
                    meas=measure_block(dly,
                                  addr_bit,
                                  bank_bit)
                    if meas:
                        dly_low=dly
                    else:
                        dly_high=dly
                rslt.append(dly_low)
            return rslt     
        #main method body - iterate over phases
        addr_odelay=[]
        for phase in range(numPhaseSteps):
            if quiet < 6:
                print (".",end="")
                sys.stdout.flush()
            addr_odelay.append(addr_phase_step(phase))
        if quiet < 6:
            print ()
#        self.adjustment_state['addr_odelay_meas']=addr_odelay
        if quiet < 3:
            for phase, adly in enumerate(addr_odelay):
                print("%d"%(phase),end=" ")
                print("%s"%(str(cmda_odly[phase])),end=" ")
                if adly:
                    for b in adly:
                        if not b is None:
                            print("%d"%(b),end=" ")
                        else:
                            print("?",end=" ")
                print()
        return addr_odelay              

    def measure_cmd_odelay(self,
                           safe_phase=0.25, # 0 strictly follow cmda_odelay, >0 -program with this fraction of clk period from the margin
                           reinits=1,
                           tryWrongWlev=1, # try wrong write levelling mode to make sure device is not stuck in write levelling mode 
                           quiet=0):
        """
        Measure output delay on 3 command lines - WE, RAS and CAS, only for high-low transitions as controller
        keeps these lines at high (inactive) level all the time but the command itself.
        Scanning is performed with refresh off, one bit at a time in write levelling mode and DQS output delay set
        1/4 later than nominal, so 0x01010101 pattern is supposed to be read on all bits. If it is not (usually just 0xffffffff-s)
        the command bit is wrong. After each test one read with normal delay is done to make sure the write levelling mode is
        turned off - during write levelling mode it is turned on first, then off and marginal command bit delay may cause
        write levelling to turn on, but not off 
        """
#        self.load_hardcoded_data() # TODO: ******** TEMPORARY - remove later
        nrep=4 #16 # number of 8-bursts in write levelling mode
        margin_error=0.1 # put 0.0? - how high wlev error can be to accept 
        cmd_bits=(0,1,2) # WE, RAS, CAS
        if not "cmda_bspe" in self.adjustment_state:
            raise Exception ("No cmda_odelay data is available. 'adjust_cmda_odelay 0 1 0.1 3' command should run first.")
        dly_steps=self.x393_mcntrl_timing.get_dly_steps()
        numPhaseSteps= int(dly_steps['SDCLK_PERIOD']/dly_steps['PHASE_STEP']+0.5)
        #create a list of None/optimal cmda determined earlier
        cmda_odly=     [None if (self.adjustment_state['cmda_bspe'][phase] is None) else self.adjustment_state['cmda_bspe'][phase]['ldly'] for phase in range(numPhaseSteps)]
        if safe_phase:
            cmda_odly_zerr=[None if (self.adjustment_state['cmda_bspe'][phase] is None) else self.adjustment_state['cmda_bspe'][phase]['zerr'] for phase in range(numPhaseSteps)]
            cmda_odly_early=[]
            for phase,zerr in enumerate (cmda_odly_zerr):
                if (not zerr is None) and (zerr < 0.5-safe_phase):
                    cmda_odly_early.append(0)
                else:
                    cmda_odly_early.append(cmda_odly[phase])
        else:
            cmda_odly_early=cmda_odly
        #get write levellimg data - Maybe it is now not needed - just use set_delay()?
        try:
            wlev_p_l=   self.get_delays_for_phase(phase = None,
                                                  list_branches=False,
                                                  target=DQSO_KEY,
                                                  b_filter=DFLT_DLY_FILT,
                                                  cost=None, # if None - will default to NUM_FINE_STEPS, if 0 - will keep it 
                                                  quiet = quiet+1)
        except:
            raise Exception ("No write levelling data is available, this method should run after write levelling and proc_dqso_phase")
        
        #set DQS write pattern
        try:
            self.x393_mcntrl_timing.axi_set_dqs_dqm_patterns(dqs_patt=self.adjustment_state["dqs_pattern"],
                                                             dqm_patt=None,
                                                             quiet=quiet+2)
        except:
            print("Skipping DQS pattern (0x55/0xaa) control as it is not in gloabal data (dqs_patt=self.adjustment_state['dqs_pattern'])")

        """
        if not "wlev_dqs_bspe" in self.adjustment_state:
            print("self.adjustment_state={")
            for k,v in self.adjustment_state.items():
                print("\n'%s': %s,"%(k,str(v)))
            print("}")
        
            raise Exception ("No wlev_dqs_bspe data is available, this method should run after write levelling")
        """
        numLanes=max(len(wp) for wp in wlev_p_l if not wp is None)
        if quiet < 1:    
            print("numLanes=",numLanes)
        wlev_odly=[]
        for lane in range(numLanes):
            wlev_lane=[]
            for wl_phase in wlev_p_l:
                if wl_phase is None or (wl_phase[lane] is None):
                    wlev_lane.append(None)
                else:
                    wlev_lane.append(wl_phase[lane])
            wlev_odly.append(wlev_lane)    
                      
        """
        for wlev_data in self.adjustment_state['wlev_dqs_bspe']:
            wlev_odly.append([None if (wlev_data[phase] is None) else wlev_data[phase]['ldly'] for phase in range(numPhaseSteps)])
        """
        if quiet <1:    
            print("wlev_odly=",wlev_odly)
        #fill gaps (if any - currently none
        if quiet <1:
            #simulate
            wlev_odly[0][5]=None
            wlev_odly[1][3]=None
            print("wlev_odly=",wlev_odly)
        for wlev_lane in wlev_odly:
            for phase in range(numPhaseSteps):
                if wlev_lane[phase] is None:
                    otherPhase=None
                    for p in range(phase-numPhaseSteps/8,phase+numPhaseSteps/8+1):
                        if not wlev_lane[p % numPhaseSteps] is None:
                            if (otherPhase is None) or (abs(phase-p) < abs(phase-otherPhase)):
                                otherPhase=p
                    if not otherPhase is None:
                        print ("phase=",phase,", otherPhase=",otherPhase)
                        wlev_lane[phase]=wlev_lane[otherPhase % numPhaseSteps]
        if quiet <1:    
            print("wlev_odly=",wlev_odly)
            
        """
        if quiet <1:    
            print("wlev_p_l=",wlev_p_l)
        #fill gaps (if any - currently none
        if quiet <1:
            #simulate
            wlev_p_l[5][0]=None
            wlev_p_l[3][1]=None
            print("wlev_p_l=",wlev_p_l)
        numLanes=max(len(wp) for wp in wlev_p_l if not wp is None)
        if quiet <3:    
            print("numLanes=",numLanes)
        for phase in range(numPhaseSteps):
            if wlev_p_l[phase] is None:
                wlev_p_l[phase] = [None]*numLanes
            
        for lane in range(numLanes):
            for phase in range(numPhaseSteps):
                if wlev_p_l[phase][lane] is None:
                    otherPhase=None
                    for p in range(phase-numPhaseSteps/8,phase+numPhaseSteps/8+1):
                        if not wlev_p_l[p % numPhaseSteps][lane] is None:
                            if (otherPhase is None) or (abs(phase-p) < abs(phase-otherPhase)):
                                otherPhase=p
                    if not otherPhase is None:
                        print ("phase=",phase,", otherPhase=",otherPhase)
                        wlev_p_l[phase][lane]=wlev_p_l[otherPhase % numPhaseSteps][lane]
        if quiet <1:    
            print("wlev_p_l=",wlev_p_l)
        """

            
            
        #shift by 90 degrees
        wlev_odly_late=[]
        for wlev_lane in wlev_odly:
            wlev_odly_late.append(wlev_lane[3*numPhaseSteps//4:]+wlev_lane[:3*numPhaseSteps//4])
        if quiet <1:    
            print("wlev_odly_late=",wlev_odly_late)
        """    
        if quiet <1:
            for phase,dly in enumerate(cmda_odly):
                ldly=None
                if not self.adjustment_state['cmda_bspe'][phase] is None:
                    ldly=self.adjustment_state['cmda_bspe'][phase]['ldly']
                print("%d %s %s"%(phase,str(dly),str(ldly)))
        """
        dly_try_step=NUM_FINE_STEPS # how far to step when looking for zero crossing (from predicted)
        phase_try_step=numPhaseSteps//8 # when searching for marginal delay, try not optimal+perid/2 but smaller step to accommodate per-bit variations
        #turn off refresh - it will not be needed in this test 
        if reinits > 0:
            self.x393_pio_sequences.restart_ddr3()
        else:
            self.x393_axi_tasks.enable_refresh(0) # if not init, at least turn refresh off!
        self.x393_pio_sequences.set_write_lev(nrep,False) # write leveling - 'good' mode 
        
        def set_delays_with_reinit(phase,
                                   restart=False):
            """
            Re-initialize memory device if it stopped responding
            """
            if restart:
                if quiet < 2:
                    print ('Re-initializing memory device after failure, phase=%d'%(phase))
                    
                self.x393_pio_sequences.restart_ddr3()
            if cmda_odly_early[phase] is None:
                if quiet < 2:
                    print ('No good cmda_odly_early delays for phase = %d'%(phase))
                return None
            dly_wlev=(wlev_odly_late[0][phase],wlev_odly_late[1][phase])
            if None in dly_wlev:
                if quiet < 2:
                    print ('No good late write levellilng DQS output delays for phase = %d'%(phase))
                return None
            # no need to set any other delays but cmda and dqs odelay?
            #just set phase!
            self.x393_mcntrl_timing.axi_set_phase(phase,quiet=quiet)
            self.x393_mcntrl_timing.axi_set_cmda_odelay(combine_delay(cmda_odly_early[phase]),None, quiet=quiet)
            # set DQS odelays  to get write levelling pattern
            self.x393_mcntrl_timing.axi_set_dqs_odelay(combine_delay(dly_wlev), quiet=quiet)
            #Verify wlev is OK
            wl_rslt=self.x393_pio_sequences.write_levelling(1, nrep, quiet)
            if wl_rslt[2] > margin_error:
                self.x393_pio_sequences.set_write_lev(nrep,False) # write leveling - 'good' mode (if it was not set so) 
            
            wl_rslt=self.x393_pio_sequences.write_levelling(1, nrep, quiet)
            if wl_rslt[2] > margin_error:
                if not restart:
                    set_delays_with_reinit(phase=phase,restart=True) # try with reinitialization
                else:
                    raise Exception ("set_delays_with_reinit failed to read with safe delays for phase=%d after re-initializing device, wl_rslt=%s"%
                                     (phase,str(wl_rslt)))
            return cmda_odly_early[phase] # safe command/adderss delay
                
        def cmd_phase_step(phase):
            def measure_block(dly,
                              cmd_bit,
                              force_meas=False):
                if (meas_cache[dly] is None) or force_meas:
                    #set same delays for all cmda bits   (should be already done with 'set_phase_with_refresh'
                    self.x393_mcntrl_timing.axi_set_cmd_odelay(combine_delay(cmda_odly_early[phase]),None,   quiet=quiet)
                    self.x393_mcntrl_timing.axi_set_cmd_odelay(combine_delay(dly),     cmd_bit,quiet=quiet)
                    if quiet < 1:
                        print ('measure_block(%d,%d,%d,%d,%s) - new measurement'%(dly,cmda_odly_early[phase],cmd_bit,phase,str(force_meas)))
                        
                    self.x393_pio_sequences.manual_refresh() # run refresh that sets address bit to opposite values to the required row+bank address
                    wl_rslt=self.x393_pio_sequences.write_levelling(1, nrep, quiet)
                    meas= not (wl_rslt[2] > margin_error) # not so many errors (normally should be just 0
                    meas_cache[dly]=meas
                    # now reset command bit delay and make sure it worked
                    self.x393_mcntrl_timing.axi_set_cmd_odelay(combine_delay(cmda_odly_early[phase]),None,   quiet=quiet)
                    wl_rslt=self.x393_pio_sequences.write_levelling(1, nrep,  quiet)
                    
                    if wl_rslt[2] > margin_error:
                        if quiet < 2:
                            print ("measure_block failed to re-read with safe delays for phase=%d, cmd_bit=%d. Resetting memory device, wl_rslt=%s"%(phase,cmd_bit,str(wl_rslt)))
                        set_delays_with_reinit(phase=phase, restart=True)
                        #retry after re-initialization                        
                        wl_rslt=self.x393_pio_sequences.write_levelling(1,nrep, quiet)
                        if wl_rslt[2] > margin_error:
                            raise Exception ("measure_block failed to re-read with safe delays for phase=%d even after re-initializing device, wl_rslt=%s"%(phase,str(wl_rslt)))
                    # Now make sure device responds - setup read "wrong" write levelling (no actually turning on wlev mode)
                    if tryWrongWlev: 
                        self.x393_pio_sequences.set_write_lev(nrep, True) # 'wrong' write leveling - should not work
                        wl_rslt=self.x393_pio_sequences.write_levelling(1, nrep, quiet)
                        #restore normal write levelling mode:
                        self.x393_pio_sequences.set_write_lev(nrep, False) # 'wrong' write leveling - should not work
                        if not (wl_rslt[2] > margin_error):
                            if quiet < 2:
                                print ("!!! Write levelling mode is stuck (not turning off) for phase=%d, wl_rslt=%s"%(phase,str(wl_rslt)))
                            set_delays_with_reinit(phase=phase, restart=True) # just do it, no testimng here (wlev mode is already restored
                    
                else:
                    meas=meas_cache[dly]
                    if quiet < 1:
                        print ('measure_block(%d,%s) - using cache'%(dly,str(force_meas)))
                return meas
            
            #cmd_phase_step(phase) body
            if quiet < 1:
                print ("****** phase=%d ******"%(phase),end=" ")
#            if delays_phase[phase] is None:
#                if quiet < 1:
#                    print ("delays_phase[%d] is None"%(phase))
#                return None
            dly_optimal= cmda_odly[phase]
            if dly_optimal is None:
                if quiet < 1:
                    print ("dly_optimal is None")
                return None
            # may increase range by using dly_optimal=0 until it is not dangerously late (say only 1/4 period off)
            phase_marg= (phase+ (numPhaseSteps//2)-phase_try_step) % numPhaseSteps
            if  cmda_odly[phase_marg] is None:
                phase_marg_traget=phase_marg
                phase_marg=None
                for p in range(numPhaseSteps):
                    if not cmda_odly[p is None]:
                        if (phase_marg is None) or (min(abs(p-phase_marg_traget),
                                                        abs(p-phase_marg_traget+numPhaseSteps),
                                                        abs(p-phase_marg_traget-numPhaseSteps)) < min(abs(phase_marg-phase_marg_traget),
                                                                                                      abs(phase_marg-phase_marg_traget+numPhaseSteps),
                                                                                                      abs(phase_marg-phase_marg_traget-numPhaseSteps))):
                            phase_marg=p
                else:
                    print("BUG: could to find a valid marginal phase")
                    return None
            # may increase range by using dly_optimal=0 until it is not dangerously late (say only 1/4 period off)
            dly_marg = cmda_odly[phase_marg]# - dly_try_step
            if dly_marg < dly_optimal:
                if cmda_odly_early[phase] < dly_marg:
                    dly_optimal=cmda_odly_early[phase]
                else:
                    if quiet < 1:
                        print ("dly_marg (==%d) < dly_optimal (==%d)"%(dly_marg,dly_optimal))
                    return None # It is not possble to try delay lower than optimal with this method
                
            #set phase and all optimal delays for that phase
            dlyOK=set_delays_with_reinit(phase=phase, restart=False) # will check wlev and re-init if required
            if dlyOK is None:
                if quiet < 1:
                    print ("set_delays_with_reinit(%d) failed"%(phase))
                return None
            
            # Now try
            
            rslt=[]
            for cmd_bit in cmd_bits:
                if quiet < 1 :
                    print("\n===== phase=%d, dly_optimal=%d, cmd_bit=%d"%(phase, dly_optimal,cmd_bit))
                set_delays_with_reinit(phase=phase, restart=False) # no need to check results? Maybe remove completely?
#                set_delays_with_reinit(phase=phase, restart=True) # no need to check results? Maybe remove completely?
                meas_cache=[None]*NUM_DLY_STEPS # cache for holding results of already measured delays, new cach for each address bit
                dly=dly_marg
                dly_low=None #dly
                dly_high=None# dly
                
                while ((dly_low is None) or (dly_high is None)) and (dly > dly_optimal) and (dly < NUM_DLY_STEPS):
                    meas=measure_block(dly,
                                  cmd_bit)
                    if meas :
                        if dly==(NUM_DLY_STEPS-1):
                            dly = None
                            break
                        dly_low=dly
                        dly=min(NUM_DLY_STEPS-1,dly+dly_try_step)
                    else:                        
                        dly_high=dly
                        dly=max(dly_optimal,dly-dly_try_step)
                if quiet < 1 :
                    print ("dly_low=%s, dly_high=%s, dly=%s"%(str(dly_low),str(dly_high),str(dly)))
                if (dly_low is None) or (dly_high is None): # dly is None:
                    rslt.append(None)
                    continue
                #find highest delay that is lower than margin (here delay monotonicity is assumed!)
                while dly_low < (dly_high-1):
                    dly=(dly_low+dly_high)//2
                    meas=measure_block(dly,
                                  cmd_bit)
                    if meas:
                        dly_low=dly
                    else:
                        dly_high=dly
                rslt.append(dly_low)
                if quiet < 1 :
                    print ("rslt=",rslt)
            if quiet < 1 :
                print ("final rslt=",rslt)
            return rslt     

        cmd_odelay=[]
        for phase in range(numPhaseSteps):
            if quiet < 6:
                print (".",end="")
                sys.stdout.flush()
            cmd_odelay.append(cmd_phase_step(phase))
        if quiet < 6:
            print ()
        self.adjustment_state['cmd_meas']=cmd_odelay
        if quiet < 3:
            print ("phase cmda cmda_early WE RAS CAS")
            for phase, cdly in enumerate(cmd_odelay):
                print("%d"%(phase),end=" ")
                print("%s %s"%(str(cmda_odly[phase]),str(cmda_odly_early[phase])),end=" ")
                if cdly:
                    for b in cdly:
                        if not b is None:
                            print("%d"%(b),end=" ")
                        else:
                            print("?",end=" ")
                print()
        if quiet < 3:
            print("cmd_meas=",cmd_odelay)    

        # Keeps refresh off?
        # Restore default write levelling sequence
        self.x393_pio_sequences.set_write_lev(16,False) # write leveling - 'good' mode (if it was not set so) 
        
        return cmd_odelay

    def _map_variants(self,
                      list_variants,
                      var_template):
        """
        @param list_variants list of sets of variants - for each variant find the longest steak (rolls over the end of the list)
               Each item of a set should be a tuple of integers(cmda)/pairs of integers(dqi and dqo)
               dqi/dqo tuple consists of reference dqsi/dqso branch (signed int) and a relative shift to it (negative - earlier,
               positive - later)
        @param var_template - a tuple of the same number of elements as each variant in a set, of boolean: True (cmda,dqso, dqo) - add 1 when crossing
               from last to 0, False (dqi,dqsi) - subtract  
        @return dictionary with keys - variants, and values - tuples of starts and lengths of the longest streak
         
        """
        map_all=self._map_variants_all(list_variants=list_variants,
                                       var_template=var_template)
        result={}
        for k,v in map_all.items():
            lengths=[sl[1] for sl in v]
            
            result[k]= v[lengths.index(max(lengths))]
#        print ("map_all=",map_all)
#       print ("result=",result)
        return result
    
    
    def _map_variants_all(self,
                      list_variants,
                      var_template):
        """
        @param list_variants list of sets of variants - for each variant find the longest steak (rolls over the end of the list)
               Each item of a set should be a tuple of integers(cmda)/pairs of integers(dqi and dqo)
               dqi/dqo tuple consists of reference dqsi/dqso branch (signed int) and a relative shift to it (negative - earlier,
               positive - later)
        @param var_template - a tuple of the same number of elements as each variant in a set, of boolean: True (cmda,dqso, dqo) - add 1 when crossing
               from last to 0, False (dqi,dqsi) - subtract  
        @return dictionary with keys - variants, and values - list of tuples (usually just one element) of starts and lengths of the longest streak
         
        """
        numPhases=len(list_variants)
        falling_signs=tuple([(-1,1)[i] for i in var_template])
        # for each variant (key) a list of (start,len,(this_start,this_end))
        # start - start of this steak, possibly rolling through 0, len - length of this streak (rolling over
        # this start - start of this streak not crossing 0, this_end - last+1 - not crossing len
        streaks={} 
        prev_vars=set()
        all_variants=set()
        # First - process phase=0, all the rest will have starts
        def check_extrapolated_var_to_phase(phase,variant):
            extrapolated_variant=variant
            periods = phase // numPhases
            if periods != 0:
                extrapolated_variant = []
                for falling,item_var in zip(falling_signs,variant):
                    if isinstance(item_var,tuple):
                        extrapolated_variant.append((item_var[0]+falling*periods,item_var[1]))
                    else:
                        extrapolated_variant.append(item_var+falling*periods)
                extrapolated_variant=tuple(extrapolated_variant)
            try:
#                print("check_extrapolated_var_to_phase(%d,%s ==> %s)"%(phase,str(variant),str(extrapolated_variant in list_variants[phase % numPhases])))
                return extrapolated_variant in list_variants[phase % numPhases]
            except:
#                print("check_extrapolated_var_to_phase(%d,%s) - was None"%(phase,str(variant)))
                return False # was None
                    
#            periods= phase // numPhases
#            p_phase=phase % numPhases
            
                
            
        for phase, variants in enumerate(list_variants):
            if variants:
                all_variants |= variants
                new_vars = variants - prev_vars
                for new_var in new_vars:
                    # First - process phase=0, all the rest will have starts
                    if phase==0:
                        s_phase = phase
                        while check_extrapolated_var_to_phase(s_phase-1,new_var):
                            s_phase -= 1
                    else:
                        s_phase=phase
                    # now s_phase >=0 for phase>0 or <= 0 for phase=0
                    # find the end of the streak
                    e_phase=phase+1
                    while check_extrapolated_var_to_phase(e_phase,new_var):
                        e_phase += 1
#                    print(".... phase=%d, s_phase=%d, e_phase=%d"%(phase, s_phase, e_phase))    
                    if not new_var in streaks:
                        streaks[new_var]=[]
                    streaks[new_var].append((s_phase % numPhases, e_phase-s_phase)) 
                    """
                    for streak_len in range(1,numPhases):
                        if (list_variants[(s_phase+streak_len) % numPhases] is None) or (not new_var in list_variants[(s_phase+streak_len) % numPhases]):
                            if (not new_var in streaks) or (streaks[new_var][1]<streak_len):
                                streaks[new_var]=(s_phase,streak_len)
                            break
                    """
            else:
                variants=set()
                        
            prev_vars=variants
        return streaks

        """
        prev_vars=list_variants[numPhases-1]
        all_variants=set()
        for s_phase, variants in enumerate(list_variants):
            if variants:
                all_variants |= variants
                if prev_vars:
                    new_vars = variants - prev_vars
                else:
                    new_vars = variants
                for new_var in new_vars:
                    for streak_len in range(1,numPhases):
                        if (list_variants[(s_phase+streak_len) % numPhases] is None) or (not new_var in list_variants[(s_phase+streak_len) % numPhases]):
                            if (not new_var in streaks) or (streaks[new_var][1]<streak_len):
                                streaks[new_var]=(s_phase,streak_len)
                            break
                        
            prev_vars=variants
        # check if a variant is available everywher (should not be the case in this application)
        for v in all_variants:
            if not v in streaks:
                streaks[v]=(0,numPhases) # all length, starting from 0
        return streaks
        """
    
    
    def set_read_branch(self,
                        wbuf_dly=9,
                        quiet=1):
        """
        Try read mode branches and find sel (early/late read command) and wbuf delay,
        if possible
        Detect shift by 1/2 clock cycle (should not happen), if it does proq_dqi_dqsi with duifferent prim_set (^2) is needed
        delay vs. phase should be already calibrated
        @param wbuf_dly - initial wbuf delay to try
        @quiet reduce output
        @return dictionary with key(s) (early,nominal,late) containing dictionary of {'wbuf_dly':xx, 'sel':Y}
                        optionally result may contain key 'odd' with a list of varinats that resulted in odd number of wrong words
                          if the remaining number of errors is odd
        """
        #temporarily:
#        self.load_mcntrl('dbg/x393_mcntrl.pickle')
        
        if wbuf_dly is None:
            wbuf_dly=vrlg.DFLT_WBUF_DELAY
        #find one valid phase per existing branch
#        phase_var={}
        #set DQS write pattern
        try:
            self.x393_mcntrl_timing.axi_set_dqs_dqm_patterns(dqs_patt=self.adjustment_state["dqs_pattern"],
                                                             dqm_patt=None,
                                                             quiet=quiet+2)
        except:
            print("Skipping DQS pattern (0x55/0xaa) control as it is not in gloabal data (dqs_patt=self.adjustment_state['dqs_pattern'])")

        cmda_vars= self.get_delays_for_phase(phase = None,
                                             list_branches=True,
                                             target=CMDA_KEY,
                                             b_filter=None, # will default to earliest (lowest delay) branch, same as 'e',
                                             cost=None, # if None - will default to NUM_FINE_STEPS, if 0 - will keep it 
                                             quiet = quiet+2)
        dqsi_vars= self.get_delays_for_phase(phase = None,
                                             list_branches=True,
                                             target=DQSI_KEY,
                                             b_filter=None, # will default to earliest (lowest delay) branch, same as 'e',
                                             cost=None, # if None - will default to NUM_FINE_STEPS, if 0 - will keep it 
                                             quiet = quiet+2)
        dqi_vars= self.get_delays_for_phase(phase = None,
                                             list_branches=True,
                                             target=DQI_KEY,
                                             b_filter=None, # will default to earliest (lowest delay) branch, same as 'e',
                                             cost=None, # if None - will default to NUM_FINE_STEPS, if 0 - will keep it 
                                             quiet = quiet+2)
        numPhases=len(cmda_vars)
#        print ("numPhases=",numPhases,' cmda_vars',cmda_vars,' dqsi_vars',dqsi_vars,' dqi_vars',dqi_vars)
        read_phase_variants=[]
#        all_read_variants=set()

        for phase,cmda,dqsi,dqi in zip(range(numPhases),cmda_vars,dqsi_vars,dqi_vars):
            if quiet < 3:
                print ("phase=",phase,', cmda=',cmda,', dqsi=',dqsi,', dqi=',dqi)
            if all([cmda,dqsi,dqi]):
                rv=set()
                for cv in cmda:
                    for dv in dqi:
                        if dv[0] in dqsi:
                            rv.add((cv,dv))
                if rv:
                    read_phase_variants.append(rv)
#                    all_read_variants |= rv
                else:
                    read_phase_variants.append(None)
#                    print ("rv is not - it is ",rv)
            else:    
                read_phase_variants.append(None)
#                print ("Some are not: phase=",phase,', cmda=',cmda,', dqsi=',dqsi,', dqi=',dqi)
                
        if quiet < 3:
#               print("all_read_variants=",all_read_variants)    
            for phase, v in enumerate(read_phase_variants):
                print("%d: %s"%(phase,str(v)))
                        
        variants_map=self._map_variants(list_variants=read_phase_variants,
                                        var_template=(True,False))
        centers={}
        skipped_centers=set() # just for debugging
        used_centers=set() # just for debugging
        data_shifts={}
        for k,v in variants_map.items():
            data_shifts[k]=k[1][1]-k[1][0]-k[0]
            center_phase=(v[0]+v[1]//2) % numPhases
            if k in read_phase_variants[center_phase]:
                centers[k]=center_phase
                used_centers.add(center_phase)
            else:
                skipped_centers.add(center_phase)
                if quiet < 2:
                    print ("center phase = %d for variant %s is not in read_phase_variants[%d]=%s"%(center_phase,
                                                                                                    str(k),
                                                                                                    center_phase,
                                                                                                    str(read_phase_variants[center_phase])))
                    print ("It should be listed for some other variant")
        if quiet < 3:
            print ("variants_map=",variants_map)
            print ("centers=",centers)
            print ("used_centers=",used_centers)
            print ("skipped_centers=",skipped_centers)
            print ('data_shifts=',data_shifts)
            
        if skipped_centers - used_centers:
            print ("Some skipped centers %s are not listed for other variants %s, variants_map=%s)"%(str(skipped_centers),
                                                                                                     str(used_centers),
                                                                                                     str(variants_map)))
            raise Exception("BUG: Some skipped centers %s are not listed for other variants")
                    
#        print ("**** REMOVE THIS RETURN ****")    
#        return    
                            
                
# some different varinats are actually the same when they roll over phases TODO: merge them
# actually - only cmda changes - it gets +1 when moving from last to first     

        #write/used block parameters
        startValue=0
        ca=0
        ra=0
        ba=0
        extraTgl=1 # just in case
        wsel=1
        rslt={}
        odd_list=[]
        #write a block with any delay
        write_valid= self.get_all_delays(phase=None,
                                         filter_cmda=DFLT_DLY_FILT, # may be special case: 'S<safe_phase_as_float_number>
                                         filter_dqsi=None, #no need to read - just write
                                         filter_dqi= None,
                                         filter_dqso=DFLT_DLY_FILT,
                                         filter_dqo= DFLT_DLY_FILT,
                                         forgive_missing=False,
                                         cost=None,
                                         maxPhaseErrorsPS = None,
                                         quiet=quiet+2)
        for phase, v in enumerate(write_valid):
            if not v is None:
                break
        else:
            raise Exception("Could not find any valid phase for writing")
        used_delay=self.set_delays(phase=phase,
                                         filter_cmda=DFLT_DLY_FILT, # may be special case: 'S<safe_phase_as_float_number>
                                         filter_dqsi=None, #no need to read - just write
                                         filter_dqi= None,
                                         filter_dqso=DFLT_DLY_FILT,
                                         filter_dqo= DFLT_DLY_FILT,
                                         cost=None,
                                         refresh=True,
                                         forgive_missing = False,
                                         maxPhaseErrorsPS = None,
                                         quiet=quiet+2)
        if used_delay is None:
            raise Exception("Failed to set delay for writing block")
        #write_block_inc, it may turn out to be shifted, have problems at the beginning or end - write is not set up yet
        self.x393_pio_sequences.write_block_inc(num8=64, # max 512 16-bit words
                                                startValue=startValue,
                                                ca=ca,
                                                ra=ra,
                                                ba=ba,
                                                extraTgl=extraTgl,
                                                sel=wsel,
                                                quiet=quiet+1)
        
        for variant, phase in centers.items(): #variant now a tuple of cmda variant an dqi variant which
            used_delays=self.set_delays(phase=phase,
                                        filter_cmda=[variant[0]], # may be special case: 'S<safe_phase_as_float_number>
                                        filter_dqsi=[variant[1][0]],
                                        filter_dqi= [variant[1]],
                                        filter_dqso=None,
                                        filter_dqo= None,
                                        cost=None,
                                        refresh=True,
                                        forgive_missing = False,
                                        maxPhaseErrorsPS = None,
                                        
#                                        quiet=quiet+1)
                                        quiet=quiet+1)
            if used_delays is None:
                raise Exception("set_read_branch(): failed to set phase = %d"%(phase))
            wbuf_dly_max=12
            wdly=max(0,min(wbuf_dly,wbuf_dly_max))
            rsel=0
            #set_and_read_inc  8 16 0 0 1 1
            last_wstep=0
            read_problems=None
            for _ in range(20): # limit numer of repetiotions - just in case
                self.x393_mcntrl_timing.axi_set_wbuf_delay(wdly)
                read_results = self.x393_pio_sequences. set_and_read_inc(num8=8, # max 512 16-bit words
                                                                         ca=ca+16,
                                                                         ra=ra,
                                                                         ba=ba,
                                                                         sel=rsel,
                                                                         quiet=quiet+1)
                read_problems=read_results[:2]
                if (read_problems[0]>=4) or ((rsel==0) and (read_problems[0]>=2)):
                    if last_wstep < 0:
                        if quiet < 1:
                            print ("reversed wstep to +1 at wdly = %d"%(wdly))
                        break
                    last_wstep = 1     
                    wdly += 1
                    if wdly >= wbuf_dly_max:
                        print("Exceeded maximal write buffer delay = %d while setting up read for branch '%s', phase=%d"%(wdly,str(variant),phase))
                        read_problems=None
                        break # continue with next branch
                    continue
                    
                if (read_problems[1]>4) or (rsel and (read_problems[1] == 4)):
                    if last_wstep > 0:
                        if quiet < 1:
                            print ("reversed wstep to -1 at wdly = %d"%(wdly))
                        break
                    last_wstep =- 1     
                    wdly -= 1
                    if wdly < 1:
                        print("Exceeded minimal write buffer delay = %d while setting up read for branch '%s', phase=%d"%(wdly,str(variant),phase))
                        read_problems=None
                        break # continue with next branch
                    continue
                break # close to target
            if read_problems is None:
                continue # could not get initial wbuf delay
            read_problems_min=read_problems
            best_dw,best_sel=(0,0)
            if quiet < 2:
                print("variant=",variant)
                print("Read_problems_min=",read_problems_min)
                print("wdly=",wdly)
                print("rsel=",rsel)
                print("sum(read_problems_min)=",sum(read_problems_min))

            if sum(read_problems_min) > 0:
                for dw,sel in ((-1,0),(-1,1),(0,0),(0,1),(1,0),(1,1)):
                    self.x393_mcntrl_timing.axi_set_wbuf_delay(wdly+dw)
                    read_results = self.x393_pio_sequences. set_and_read_inc(num8=8, # max 512 16-bit words
                                                                             ca=ca+16,
                                                                             ra=ra,
                                                                             ba=ba,
                                                                             sel=sel ^ rsel,
#                                                                             quiet=quiet+1)
                                                                             quiet=quiet+1)
                    read_problems=read_results[:2]
                    shft=(read_results[2] & 0x1ff)-16-read_results[3]
                    if quiet < 2:
                        print("=== Variant=%s, phase=%d sel=%d wbuf=%d : shift=%d,  Read_problems=%s"%(str(variant),
                                                                                                       phase,
                                                                                                       sel ^ rsel,
                                                                                                       wdly+dw,
                                                                                                       str(read_problems)))
                    if quiet < 3:
                        measured_shift= 4*(wdly+dw) - shft - 2* (sel ^ rsel)
#variant=(-1, (0, 0)), calculated shift=1, measured shift=34, cal-meas=-32 shift=0 sel=1 wdly=9 sw=17
                        
                        print ("variant=%s, calculated shift=%d (clocks), measured shift=%d(words), cal-meas=%d(words), problems=%s"%(
                                                                                                  str(variant),
                                                                                                  data_shifts[variant],
                                                                                                  measured_shift,
                                                                                                  2*data_shifts[variant]-measured_shift,
                                                                                                  str(read_problems)))  
                    
                    if sum(read_problems) < sum(read_problems_min):
                        read_problems_min=read_problems
                        best_dw,best_sel= dw,sel
                        if sum(read_problems_min) == 0:
                            break
            wdly += best_dw
            rsel ^= best_sel
            if quiet < 2:
                print("-Read_problems_min=",read_problems_min)
                print("-wdly=",wdly)
                print("-rsel=",rsel)
                print("-sum(read_problems_min)=",sum(read_problems_min))
                print(" shift = ", (read_results[2] & 0x1ff)-16-read_results[3])
            
            if sum(read_problems_min) ==0:
                rslt[variant]={'wbuf_dly':wdly, 'sel':rsel}
                if quiet < 2:
                    print("-rslt=",rslt)
            elif (read_problems_min[0]%2) or (read_problems_min[1]%2):
                odd_list.append(variant)
                if quiet < 3:
                    print("Failed to find read settings for varinat '%s', phase=%d - best start read errors=%d, end read errors=%d"%(
                        str(variant),phase,read_problems_min[0],read_problems_min[1]))
                    print("Odd number of wrong read words means that there is a half clock period shift, you may need to change")
                    print("primary_set parameter of proc_dqi_dqsi() from 2 to 0" )
            else:    
                if quiet < 2:
                    print("Failed to find read settings for varinat '%s', phase=%d - best start read errors=%d, end read errors=%d"%(
                        str(variant),phase,read_problems_min[0],read_problems_min[1]))
        if quiet < 2:
            print("odd_list=",odd_list)
                    
        for v in rslt.values():
            try:
                self.x393_mcntrl_timing.axi_set_wbuf_delay(v['wbuf_dly'])
                break
            except:
                pass
                
        if odd_list:
            rslt[ODD_KEY]=odd_list    
        self.adjustment_state['read_variants']=rslt

        if quiet < 3:
            print ('read_variants=',rslt)
        return rslt            




    def set_write_branch(self,
                         dqs_pattern=None,
                         extraTgl=1, # just in case
                         quiet=1):
        """
        Try write mode branches and find sel (early/late write command), even if it does not match read settings
        Read mode should already be set up
        
        if possible
        Detect shift by 1/2 clock cycle (should not happen), if it does proq_dqi_dqsi with duifferent prim_set (^2) is needed
        delay vs. phase should be already calibrated
        @param dqs_pattern -     0x55/0xaa - DQS output toggle pattern. When it is 0x55 primary_set_out is reversed ? 
        @quiet reduce output
        @return dictioray with a key(s) (early,nominal,late) containing dictionary of {'wbuf_dly':xx, 'sel':Y} or value 'ODD'
                          if the remaining number of errors is odd
        """
        #temporarily:
#        self.load_mcntrl('dbg/x393_mcntrl.pickle')
        #write/used block parameters
        startValue=0
        num8=8 # 8 bursts to read/write
        ca=0
        ra=0
        ba=0
        wsel=1
        rslt={}
        
        readVarKey='read_variants'
        if dqs_pattern is None:
            try:
                dqs_pattern=self.adjustment_state["dqs_pattern"]
            except:
                dqs_pattern=vrlg.DFLT_DQS_PATTERN
                self.adjustment_state["dqs_pattern"] = dqs_pattern
                print("Setting default DQS wirite pattern to self.adjustment_state['dqs_pattern'] and to hardware. Check that write levelling already ran")
        self.x393_mcntrl_timing.axi_set_dqs_dqm_patterns(dqs_patt=dqs_pattern,
                                                         dqm_patt=None,
                                                         quiet=quiet+2)
        """
read_variants= {(-1, (0, 0)): {'sel': 1, 'wbuf_dly': 9},
                 (0, (0, 0)): {'sel': 0, 'wbuf_dly': 8}}
        """
                        
        try:
            readVars=self.adjustment_state[readVarKey]
        except:
            raise Exception ("Read variants are not set up, need to run command set_read_branch90 first")
        
        read_var_set=set()
        for variant in readVars:
            if variant != ODD_KEY:
                read_var_set.add(variant)

        if not read_var_set:
            raise Exception ("No valid read variant is found, can not proceed with write setup")
        if quiet <2:
            print ("read_var_set=",read_var_set)
        cmda_vars= self.get_delays_for_phase(phase = None,
                                             list_branches=True,
                                             target=CMDA_KEY,
                                             b_filter=None, # will default to earliest (lowest delay) branch, same as 'e',
                                             cost=None, # if None - will default to NUM_FINE_STEPS, if 0 - will keep it 
                                             quiet = quiet+2)
        dqsi_vars= self.get_delays_for_phase(phase = None,
                                             list_branches=True,
                                             target=DQSI_KEY,
                                             b_filter=None, # will default to earliest (lowest delay) branch, same as 'e',
                                             cost=None, # if None - will default to NUM_FINE_STEPS, if 0 - will keep it 
                                             quiet = quiet+2)
        dqi_vars= self.get_delays_for_phase(phase = None,
                                             list_branches=True,
                                             target=DQI_KEY,
                                             b_filter=None, # will default to earliest (lowest delay) branch, same as 'e',
                                             cost=None, # if None - will default to NUM_FINE_STEPS, if 0 - will keep it 
                                             quiet = quiet+2)
        dqso_vars= self.get_delays_for_phase(phase = None,
                                             list_branches=True,
                                             target=DQSO_KEY,
                                             b_filter=None, # will default to earliest (lowest delay) branch, same as 'e',
                                             cost=None, # if None - will default to NUM_FINE_STEPS, if 0 - will keep it 
                                             quiet = quiet+2)
        dqo_vars= self.get_delays_for_phase(phase = None,
                                             list_branches=True,
                                             target=DQO_KEY,
                                             b_filter=None, # will default to earliest (lowest delay) branch, same as 'e',
                                             cost=None, # if None - will default to NUM_FINE_STEPS, if 0 - will keep it 
                                             quiet = quiet+2)
        numPhases=len(cmda_vars)
        write_phase_variants=[]
#        all_read_variants=set()
        #1. make a list of all write variants,
        #2. try to find an intersection with valid read branch
        #3. if not all found - use one of other branches, if none found - use any read branch

        for phase,cmda,dqso,dqo in zip(range(numPhases),cmda_vars,dqso_vars,dqo_vars):
            if quiet < 3:
                print ("phase=",phase,', cmda=',cmda,', dqso=',dqso,', dqo=',dqo)
            if all([cmda,dqso,dqo]):
                rv=set()
                for cv in cmda:
                    for dv in dqo:
                        if dv[0] in dqso:
                            rv.add((cv,dv))
                if rv:
                    write_phase_variants.append(rv)
#                    all_read_variants |= rv
                else:
                    write_phase_variants.append(None)
#                    print ("rv is not - it is ",rv)
            else:    
                write_phase_variants.append(None)
#                print ("Some are not: phase=",phase,', cmda=',cmda,', dqsi=',dqsi,', dqi=',dqi)
        if quiet < 3:
            print("\nwrite_phase_variants:")    
            for phase, v in enumerate(write_phase_variants):
                print("%d: %s"%(phase,str(v)))

        #variant - just for writing
        write_only_map=self._map_variants(list_variants=write_phase_variants,
                                           var_template=(True,True))
        if quiet < 3:
            print ("write_only_map=",write_only_map)

        read_write_variants=[]
        for phase,cmda,dqso,dqo,dqsi,dqi in zip(range(numPhases),cmda_vars,dqso_vars,dqo_vars,dqsi_vars,dqi_vars):
            if quiet < 3:
                print ("phase=",phase,', cmda=',cmda,', dqso=',dqso,', dqo=',dqo,', dqsi=',dqsi,', dqi=',dqi)
            if all([cmda,dqso,dqo,dqsi,dqi]):
                rv=set()
                for cv in cmda:
                    for dvo in dqo:
                        if dvo[0] in dqso:
                            for dvi in dqi:
                                if (dvi[0] in dqsi) and ((cv,dvi) in read_var_set):
                                    rv.add((cv,dvo,dvi))
                if rv:
                    read_write_variants.append(rv)
#                    all_read_variants |= rv
                else:
                    read_write_variants.append(None)
#                    print ("rv is not - it is ",rv)
            else:    
                read_write_variants.append(None)
#                print ("Some are not: phase=",phase,', cmda=',cmda,', dqsi=',dqsi,', dqi=',dqi)
        if quiet < 3:
            print("\nread_write_variants:")    
            for phase, v in enumerate(read_write_variants):
                print("%d: %s"%(phase,str(v)))
        #read/write variants
        
        read_write_map=self._map_variants(list_variants=read_write_variants,
                                          var_template=(True,True,False))
        if quiet < 3:
            print ("read_write_map=",read_write_map)
        
        
        if not read_write_map:
            default_read_var=readVars.keys()[0]
            default_read={'cmda_read':  default_read_var[0],
                          'dqi':        default_read_var[1],
                          'dqsi':       default_read_var[1][0],
                          'read_phase':(readVars[default_read_var][0]+readVars[default_read_var][1]//2)% numPhases}
        else: # take a first in r/w map
            default_read_var=read_write_map.keys()[0]
            default_read={'cmda_read':  default_read_var[0], # center of the first interval that works both for read and write
                          'dqi':        default_read_var[2],
                          'dqsi':       default_read_var[2][0],
                          'read_phase':(read_write_map[default_read_var][0]+read_write_map[default_read_var][1]//2)% numPhases}
        # now go through all write only ramnges, try to find included r/w one, if not - use default_read
        write_settings={}
        for k_wo in write_only_map.keys():
            try:
                for k_rw in read_write_map.keys():
                    if (k_rw[0],k_rw[1]) == k_wo:
                        phase=(read_write_map[k_rw][0]+read_write_map[k_rw][1]//2)% numPhases
                        write_settings[k_wo]={'cmda_read':  k_rw[0],
                                              'cmda_write': k_rw[0],
                                              'dqi':        k_rw[2],
                                              'dqsi':       k_rw[2][0],
                                              'dqo':        k_rw[1],
                                              'dqso':       k_rw[1][0],
                                              'read_phase': phase,
                                              'write_phase': phase,
                                              'rel_sel':k_wo[0]+k_wo[1][1]-k_wo[1][0]}
                        break
                else:
                    raise Exception("failed") # just assert
            except:
                phase=(write_only_map[k_wo][0]+read_write_map[k_wo][1]//2)% numPhases
                write_settings[k_wo]={'cmda_write': k_wo[0],
                                      'dqo':        k_wo[1],
                                      'dqso':       k_wo[1][0],
                                      'write_phase': phase,
                                      'rel_sel':k_wo[0]+k_wo[1][1]-k_wo[1][0]}
                write_settings[k_wo].update(default_read)
        #rel_sel has a constant shift to wsel - this can be used to reduce number of measurements and/or verify consistency
        if quiet < 3:
            print ("write_settings=",write_settings)
        """
write_settings= {
   (0, (0, -1)): {
             'dqsi':         0,
             'cmda_write':   0,
             'write_phase': 37,
             'read_phase':  37,
             'dqso':         0,
             'cmda_read':    0,
             'dqo':     (0, -1),
             'dqi':     (0, 0)},
    (-1, (0, 0)): {
             'dqsi':         0,
             'cmda_write':  -1,
             'write_phase': 85,
             'read_phase':  85,
             'dqso':         0,
             'cmda_read':   -1,
             'dqo':      (0, 0),
             'dqi':      (0, 0)},
     (-1, (0, -1)): {
             'dqsi':         0,
             'cmda_write':  -1,
             'write_phase': 46,
             'read_phase':  46,
             'dqso':         0,
             'cmda_read':   -1,
             'dqo':     (0, -1),
             'dqi':     (0,  0)},
     (-1, (-1, -1)): {
             'dqsi':         0,
             'cmda_write':  -1,
             'write_phase': 92,
             'read_phase':  92,
             'dqso':        -1,
             'cmda_read':   -1,
             'dqo':    (-1, -1),
             'dqi':     (0,  0)}}
        
        """    
#        print ("**** REMOVE THIS RETURN ****")    
#        return    

        odd_list=[]    
        for write_variant_key, variant in write_settings.items():
            if quiet < 3:
                print ('Trying variant %s:'%(str(write_variant_key)))
                print ('Settings: %s:'%(str(variant)))
            problems_min=None
            best_wsel=None
            for wsel in range (2):
                #set write delay
                used_delays=self.set_delays(phase =           variant['write_phase'],
                                            filter_cmda =     [variant['cmda_write']], #DFLT_DLY_FILT, # may be special case: 'S<safe_phase_as_float_number>
                                            filter_dqsi =     None, 
                                            filter_dqi =      None,
                                            filter_dqso =     [variant['dqso']],
                                            filter_dqo =      [variant['dqo']],
                                            cost =            None,
                                            refresh =         True,
                                            forgive_missing = False,
                                            maxPhaseErrorsPS= None,
                                            quiet=quiet+2)
                if used_delays is None:
                    raise Exception("set_write_branch(): failed to set phase = %d"%(phase))        
                
                
                self.x393_pio_sequences.write_block_inc(num8=num8, # max 512 16-bit words
                                                        startValue=startValue,
                                                        ca=ca,
                                                        ra=ra,
                                                        ba=ba,
                                                        extraTgl=extraTgl,
                                                        sel=wsel,
                                                        quiet=quiet+1)
                
                startValue += 0x200
                startValue &= 0xffff
                used_delays=self.set_delays(phase =           variant['read_phase'],
                                            filter_cmda =     [variant['cmda_read']], # may be special case: 'S<safe_phase_as_float_number>
                                            filter_dqsi =     [variant['dqsi']],
                                            filter_dqi =      [variant['dqi']],
                                            filter_dqso =     None,
                                            filter_dqo =      None,
                                            cost =            None,
                                            refresh =         True,
                                            forgive_missing = False,
                                            maxPhaseErrorsPS= None,
                                            quiet=quiet+2)
                if used_delays is None:
                    raise Exception("set_write_branch(): failed to set phase = %d"%(phase))
                #set wbuf delay
                self.x393_mcntrl_timing.axi_set_wbuf_delay(readVars[(variant['cmda_read'],variant['dqi'])]['wbuf_dly'])
                read_results = self.x393_pio_sequences. set_and_read_inc(num8=num8, # max 512 16-bit words
                                                                        ca=ca,
                                                                        ra=ra,
                                                                        ba=ba,
                                                                        sel=readVars[(variant['cmda_read'],variant['dqi'])]['sel'],
                                                                        quiet=quiet+1)
                problems=read_results[:2]
                if (problems_min is None) or (sum(problems) < sum(problems_min)):
                    problems_min=problems
                    best_wsel=wsel
            if sum(problems_min) == 0:
                rslt[write_variant_key]={'sel':best_wsel}
            elif (problems_min[0]%2) or (problems_min[1]%2):
                odd_list.append(write_variant_key)
                if quiet < 3:
                    print("Failed to find write settings for varinat '%s', phase=%d - best start write errors=%d, end write errors=%d, wsel=%d"%(
                        write_variant_key,phase,problems_min[0],problems_min[1],best_wsel))
                    print("Odd number of wrong read words means that there is a half clock period shift, you may need to change")
                    print("primary_set parameter of proc_dqo_dqso() 2 <->0 or change DQS pattern (0x55<->0xAA)" )
                    print("Using of DQS PATTERN of 0xAA (output will start from 0, not 1) is not optimal, it requires extra toggling" )
                    print("of the DQS line after the end of block write" )
            else:
                if quiet < 2:
                    print("Failed to find write settings for varinat '%s', phase=%d - best start read errors=%d, end read errors=%d, wsel=%d"%(
                        write_variant_key,phase,problems_min[0],problems_min[1],best_wsel))
        if odd_list:
            rslt[ODD_KEY]=odd_list    
        self.adjustment_state['write_variants']=rslt
        if quiet < 4:
            print ('write_variants=',rslt)
        return rslt            
    
    
    def get_phase_range(self,
                        rsel=None, # None (any) or 0/1
                        wsel=None, # None (any) or 0/1
                        filter_cmda=None,
                        filter_dqsi=None,
                        filter_dqi= None,
                        filter_dqso=None,
                        filter_dqo= None,
                        set_globals=True,
                        quiet=1):
        """
        Find the phase range that satisfies all conditions, possibly filtered by read sel and write sel (early/late command)
        @param rsel filter by early/late read command (in two-clock command cycle - 'sel') Valid values: None, 0 or 1
        @param wsel filter by early/late write command (in two-clock command cycle - 'sel') Valid values: None, 0 or 1
        @param quiet reduce output
        @return {'optimal_phase': optimal phase, 'rsel': read_sel, 'wsel': write_sel, 'min_phase': minimal_phase, 'max_phase': maximal_phase}
                 'max_phase' may be lower than  'min_phase' if the range rolls over
        """
        #temporarily:
#        self.load_mcntrl('dbg/proc_addr_odelay_0x55.pickle')
#        self.load_mcntrl('dbg/x393_mcntrl.pickle')
        filters=dict(zip(SIG_LIST,[filter_cmda,filter_dqsi,filter_dqi,filter_dqso,filter_dqo]))
        for k,v in filters.items():
            if v is None:
                filters[k]=DFLT_DLY_FILT
            elif not isinstance (filters[k],(tuple,list)):
                filters[k]=[filters[k]]
            elif     isinstance (filters[k],tuple):
                filters[k]=list(filters[k]) # tuple not OK as it will be merged
        
        try:
            read_variants=self.adjustment_state['read_variants']
        except:
            read_variants=None
        try:
            write_variants=self.adjustment_state['write_variants']
        except:
            write_variants=None
            
        try:
            dqs_pattern=self.adjustment_state["dqs_pattern"]
        except:
            dqs_pattern=vrlg.DFLT_DQS_PATTERN
            self.adjustment_state["dqs_pattern"] = dqs_pattern
            print("Setting default DQS wirite pattern to self.adjustment_state['dqs_pattern'] and to hardware. Check that write levelling already ran")
        self.x393_mcntrl_timing.axi_set_dqs_dqm_patterns(dqs_patt=dqs_pattern,
                                                         dqm_patt=None,
                                                         quiet=quiet+2)
        if rsel is None:
            rsels=(0,1)
        elif isinstance(rsel,(list,tuple)):
            rsels=tuple(rsel)
        else:
            rsels=(rsel,)
        if wsel is None:
            wsels=(0,1)
        elif isinstance(wsel,(list,tuple)):
            wsels=tuple(wsel)
        else:
            wsels=(wsel,)
        if quiet <2:
            print ("read_variants=", read_variants)
            print ("write_variants=",write_variants)
            print ("rsels=%s, wsels=%s"%(str(rsels),str(wsels)))
        
        #TODO: Add filters (maximal errors?) here
        
        cmda_vars= self.get_delays_for_phase(phase = None,
                                             list_branches=True,
                                             target=CMDA_KEY,
                                             b_filter=filters[CMDA_KEY], 
                                             cost=None, # if None - will default to NUM_FINE_STEPS, if 0 - will keep it 
                                             quiet = quiet+2)
        dqsi_vars= self.get_delays_for_phase(phase = None,
                                             list_branches=True,
                                             target=DQSI_KEY,
                                             b_filter=filters[DQSI_KEY], 
                                             cost=None, # if None - will default to NUM_FINE_STEPS, if 0 - will keep it 
                                             quiet = quiet+2)
        dqi_vars= self.get_delays_for_phase(phase = None,
                                             list_branches=True,
                                             target=DQI_KEY,
                                             b_filter=filters[DQI_KEY],
                                             cost=None, # if None - will default to NUM_FINE_STEPS, if 0 - will keep it 
                                             quiet = quiet+2)
        dqso_vars= self.get_delays_for_phase(phase = None,
                                             list_branches=True,
                                             target=DQSO_KEY,
                                             b_filter=filters[DQSO_KEY],
                                             cost=None, # if None - will default to NUM_FINE_STEPS, if 0 - will keep it 
                                             quiet = quiet+2)
        dqo_vars= self.get_delays_for_phase(phase = None,
                                             list_branches=True,
                                             target=DQO_KEY,
                                             b_filter=filters[DQO_KEY],
                                             cost=None, # if None - will default to NUM_FINE_STEPS, if 0 - will keep it 
                                             quiet = quiet+2)
        numPhases=len(cmda_vars)
        
        all_variants=[]
        for phase,cmda,dqso,dqo,dqsi,dqi in zip(range(numPhases),cmda_vars,dqso_vars,dqo_vars,dqsi_vars,dqi_vars):
            if quiet < 2:
                print ("phase=",phase,', cmda=',cmda,', dqso=',dqso,', dqo=',dqo,', dqsi=',dqsi,', dqi=',dqi)
            if all([cmda,dqso,dqo,dqsi,dqi]):
                av=set()
                for cv in cmda:
                    for dvo in dqo:
                        if dvo[0] in dqso:
                            for dvi in dqi:
                                if(( dvi[0] in dqsi) and
                                   ((cv,dvi) in read_variants.keys()) and
                                   ((cv,dvo) in write_variants.keys()) and
                                   (read_variants[(cv,dvi)]['sel'] in rsels) and
                                   (write_variants[(cv,dvo)]['sel'] in wsels)):
                                    av.add((cv,dvo,dvi))
                if av:
                    all_variants.append(av)
#                    all_read_variants |= rv
                else:
                    all_variants.append(None)
#                    print ("rv is not - it is ",rv)
            else:    
                all_variants.append(None)
#                print ("Some are not: phase=",phase,', cmda=',cmda,', dqsi=',dqsi,', dqi=',dqi)
        
        if quiet < 3:
            print ("all_variants=",all_variants)
        varints_map=self._map_variants(list_variants=all_variants,
                                       var_template=(True,True,False))
        if quiet < 3:
            print ("varints_map=",varints_map)
            
#        print ("**** REMOVE THIS RETURN ****")    
#        return    
            
#When setting optimal phase - see if center is in other period, modify other parameters accordingly            
            
        rslt=[]
        for k,v in varints_map.items():
            rslt.append({
                        'rsel':      read_variants [(k[0],k[2])]['sel'],
                        'wbuf_dly':  read_variants [(k[0],k[2])]['wbuf_dly'],
                        'wsel':      write_variants[(k[0],k[1])]['sel'],
                        'cmda':      k[0],
                        'dqsi':      k[2][0],
                        'dqi':       k[2],
                        'dqo':       k[1],
                        'dqso':      k[1][0],
                        'start':     v[0],
                        'len':       v[1],
                        'phase':     (v[0]+v[1] // 2) % numPhases
                        })
        if not rslt:
            print("Could not find any combination of parameters that fit all filters")
            return None
        
            
        if quiet < 3:
            print ("result=",rslt)
            
        # Find the longest streak : TODO - combine roll over phase (not in this case, cmda just adds +1 from high phase to 0
        # TODO: use minimal cmda/dqsi,dqso errors ? Or just add them to parameters of this method?
        toSort=[(-i['len'], i) for i in rslt]
        toSort.sort()
        if quiet < 3:
            print ("toSort=",toSort)
        rslt=[i[1] for i in toSort]

        if quiet < 4:
            print ("sorted result=",rslt)
        optimal=rslt[0]
        if set_globals:
            self.adjustment_state['adjustment_variants']=rslt
        #set phase and delays matching the best variant
        
        used_delays=self.set_delays(phase=            optimal['phase'],
                                    filter_cmda =     (optimal['cmda'],),
                                    filter_dqsi =     (optimal['dqsi'],),
                                    filter_dqi =      (optimal['dqi'],),
                                    filter_dqso =     (optimal['dqso'],),
                                    filter_dqo =      (optimal['dqo'],),
                                    cost =            None,
                                    refresh =         True,
                                    forgive_missing = False,
                                    maxPhaseErrorsPS= None,
                                    quiet =           quiet+0)
        if used_delays is None:
            print ("sorted result=",rslt)
            raise Exception("get_phase_range(): failed to set phase = %d"%(optimal['phase']))  #      
   
        if quiet < 3:
            print ("Remaining ranges:")
            self.show_all_delays(filter_variants = varints_map.keys(),
                        filter_cmda =    filters[CMDA_KEY],
                        filter_dqsi =    filters[DQSI_KEY],
                        filter_dqi =     filters[DQI_KEY],
                        filter_dqso =    filters[DQSO_KEY],
                        filter_dqo =     filters[DQO_KEY],
                        quiet =          quiet+0)
        if quiet < 4:
            print ("\nBest Range:",end=" ")
            self.show_all_delays(filter_variants = [(optimal['cmda'],optimal['dqo'],optimal['dqi'])],
                        filter_cmda =    filters[CMDA_KEY],
                        filter_dqsi =    filters[DQSI_KEY],
                        filter_dqi =     filters[DQI_KEY],
                        filter_dqso =    filters[DQSO_KEY],
                        filter_dqo =     filters[DQO_KEY],
                        quiet =          quiet+0)
        
        return rslt # first in the list is the best

    def verify_write_read(self,
                          brc=None,
                          adj_vars=None,
                          quiet=1):
        """
        Veriy random write+read for each valid phase (filtered by adj_vars or current  self.adjustment_state['adjustment_variants'],
        either to a selected bank/row/column or using random address
        """
        #temporarily:
        self.load_mcntrl('dbg/x393_mcntrl.pickle')
        
        if adj_vars is None:
            adj_vars=self.adjustment_state['adjustment_variants']
        if quiet < 2:
            print ("adj_vars=",adj_vars)
        for variant in adj_vars:
            if quiet < 2:
                print ("Testing variant %s to write and read data"%(variant))
            start_phase=variant['']    
                
                
                
            dlys= self.get_all_delays(phase=None,
                                      filter_cmda =     [variant[CMDA_KEY]],
                                      filter_dqsi =     [variant[DQSI_KEY]],
                                      filter_dqi =      [variant[DQI_KEY]],
                                      filter_dqso =     [variant[DQSO_KEY]],
                                      filter_dqo =      [variant[DQO_KEY]],
                                      forgive_missing = False,
                                      cost =            None,
                                      maxPhaseErrorsPS = None,
                                      quiet =           quiet+2)
            if quiet < 2:
                for phase, d in enumerate(dlys):
                    if not d is None:
                        print ("%d %s"%(phase,d))

            
             

    def measure_all(self,
                    tasks="*ICWRPOASZB", # "ICWRPOA", #"ICWRPOASZB",
                    prim_steps=1,
                    primary_set_in=2,
                    primary_set_out=2,
                    dqs_pattern=0x55,
                    rsel=None, # None (any) or 0/1
                    wsel=None, # None (any) or 0/1 # Seems wsel=0 has a better fit - consider changing
                    extraTgl=0,
                    quiet=3):
        """
        @param tasks - "*" - load bitfile
                       "C" cmda, "W' - write levelling, "R" - read levelling (DQI-DQSI), "P" -  dqs input phase (DQSI-PHASE),
                       "O" - output timing (DQ odelay vs  DQS odelay), "A" - address/bank lines output delays, "Z" - print results,
                       "B" - select R/W brances and get the optimal phase
        @param prim_steps -  compare measurement with current delay with one lower by 1 primary step (5 fine delay steps), 0 -
                             compare with one fine step lower
        @param primary_set_in -  which of the primary sets to use when processing DQi/DQSi results (2 - normal, 0 - other DQS phase)
        @param primary_set_out - which of the primary sets to use when processing DQo/DQSo results (2 - normal, 0 - other DQS phase)
        @param dqs_pattern -     0x55/0xaa - DQS output toggle pattern. When it is 0x55 primary_set_out is reversed ? 
        @param extraTgl - add extra dqs toggle (2 clock cycles)
        @param quiet reduce output
        """
#        dqs_pattern=0x55 # 0xaa
#        try:
#            s_dqs_pattern="0x%x"%(dqs_pattern)
#        except:
#            s_dqs_pattern=""
        bitfile_path=None # use default
        max_phase_err=0.1
        frac_step=0.125
#        read_sel=1 # set DDR3 command in the second cycle of two (0 - during the first omne)
        read_bin_size=5 # dealy counts
        write_bin_size=5 # dealy counts
        read_scale_w=0.0 # weight of the "binary" results relative to "analog"
        write_scale_w=0.0 # weight of the "binary" results relative to "analog"
        
        idly_phase_sel=1
        bin_size_ps=50.0
        read_phase_scale_w=0.0
        write_phase_scale_w=0.0
        prim_steps_in=prim_steps
        prim_steps_wl=prim_steps
        prim_steps_out=prim_steps
        wbuf_dly=9 # just a hint, start value can be different
#        primary_set_in=2
#        primary_set_out=2
        write_sel=1 # set DDR3 command in the second cycle of two (0 - during the first one)
        safe_phase=0.25 # 0: strictly follow cmda_odelay, >0 -program with this fraction of clk period from the margin
        measure_addr_odelay_dqsi_safe_phase=0.125 # > 0 - allow DQSI with DQI simultaneously deviate  +/- this fraction of a period   
        commonFine=True, # use same values for fine delay for address/bank lines
        DqsiMaxDlyErr=200.0 # currently just to check multiple overlapping DQSI branches
        DqsoMaxDlyErr=200.0 # currently just to check multiple overlapping DQSI branches
        CMDAMaxDlyErr=200.0 # currently just to check multiple overlapping DQSI branches
        task_data=[
                   {'key':'*',
                    'func':self.x393_utils.bitstream,
                    'comment':'Load bitfile, initialize FPGA',
                    'params':{'bitfile':bitfile_path,
                              'quiet':quiet+1}},
                   {'key':'I',
                    'func':self.x393_pio_sequences.task_set_up,
                    'comment':'Initial setup - memory controller, sequences',
                    'params':{'dqs_pattern':dqs_pattern,
                              'quiet':quiet+1}},
                   {'key':'C',
                    'func':self.adjust_cmda_odelay,
                    'comment':'Measuring CMDA output delay for each clock phase',
                    'params':{'start_phase':0,
                              'reinits':1,
                              'max_phase_err':max_phase_err,
                              'quiet':quiet+1}},

                   {'key':'W',
                    'func':self.measure_write_levelling,
                    'comment':'Write levelling - measuring optimal DQS output delay for each phase',
                    'params':{'compare_prim_steps':prim_steps_wl,
                              'start_phase':0,
                              'reinits':1,
                              'invert':0,
                              'dqs_patt':dqs_pattern,
                              'quiet':quiet+1}},
                                       
                   {'key':'W',
                    'func':self.proc_dqso_phase,
                    'comment':'Processing measured write levelling results',
                    'params':{'lane':'All',
                              'bin_size_ps':bin_size_ps,
                              'data_set_number':-1, # use measured data
                              'scale_w':write_phase_scale_w,
                              'maxDlyErr':DqsoMaxDlyErr,
                              'quiet':quiet+1}},
                                       
                   
                   {'key':'A',
                    'func':self.measure_cmd_odelay,
                    'comment':'Measuring command (WE, RAS, CAS) lines output delays',
                    'params':{'safe_phase':safe_phase,
                              'reinits': 1,
                              'tryWrongWlev': 1,
                              'quiet': quiet+1}},
                   {'key':'R',
                    'func':self.measure_pattern,
                    'comment':'Read levelling - measuring predefined pattern to determine DQ input delays relative to DQS ones',
                    'params':{'compare_prim_steps':prim_steps_in,
                              'limit_step':frac_step,
                              'max_phase_err':max_phase_err,
                              'quiet':quiet+1}},
                   {'key':'R',
                    'func':self.proc_dqi_dqsi,
                    'comment':'Processing read levelling results using Levenberg-Marquardt algorithm to determine delay model parameters and optimal delay values',
                    'params':{'lane':'All',
                              'bin_size':read_bin_size,
                              'primary_set':primary_set_in,
                              'data_set_number':-1, # use measured data
                              'scale_w':read_scale_w,
                              'quiet':quiet+1}},
                   {'key':'P',
                    'func':self.measure_dqs_idly_phase,
                    'comment':'Measure optimal DQS input delays for clock phases (clock boundary crossing from DQS in to internal)',
                    'params':{'compare_prim_steps':prim_steps_in,
                              'frac_step':frac_step,
                              'sel':idly_phase_sel,
                              'quiet':quiet+1}},
                   {'key':'P',
                    'func':self.proc_dqsi_phase,
                    'comment':'Calculate optimal DQS input delays vs. clock phase',
                    'params':{'lane':'All',
                              'bin_size_ps':bin_size_ps,
                              'data_set_number':-1, # use measured data
                              'scale_w':read_phase_scale_w,
                              'maxDlyErr':DqsiMaxDlyErr,
                              'quiet':quiet+1}},
                   {'key':'O',
                    'func':self.measure_dqo_dqso,
                    'comment':'Measure write mode output delays on DQ lines relative to DQS output delays',
                    'params':{'compare_prim_steps':prim_steps_out,
                              'frac_step':frac_step,
                              'sel': write_sel,
                              'quiet':quiet+1}},
                   
                    {'key':'O',
                    'func':self.proc_dqo_dqso,
                    'comment':'Processing DQ output delays to DQS output data results using Levenberg-Marquardt algorithm to determine optimal delays',
                    'params':{'lane':'All',
                              'bin_size':write_bin_size,
                              'primary_set':primary_set_out,
                              'data_set_number':-1, # use measured data
                              'scale_w':write_scale_w,
                              'quiet':quiet+1}},
                   
                   {'key':'O',
                    'func':self.proc_dqso_phase,
                    'comment':'Calculate optimal DQS output delays vs. clock phase',
                    'params':{'lane':'All',
                              'bin_size_ps':bin_size_ps,
                              'data_set_number':-1, # use measured data
                              'scale_w':write_phase_scale_w,
                              'maxDlyErr':DqsoMaxDlyErr,
                              'quiet':quiet+1}},

#                    {'key':'O',
#                    'func':self.save_mcntrl,
#                    'comment':'Save current state as Python pickle',
#                    'params':{'path': 'proc_dqso_phase_%s.pickle'%(s_dqs_pattern), # None, # use path defined by the parameter 'PICKLE'
#                              'quiet':quiet+1}},
#                   
                   
                   {'key':'A',
                    'func':self.measure_addr_odelay,
                    'comment':'Measuring address and bank lines output delays',
                    'params':{'safe_phase':safe_phase,
                              'dqsi_safe_phase':measure_addr_odelay_dqsi_safe_phase,
                              'ra': 0,
                              'ba': 0,
                              'quiet':quiet+1}},
                   
                    {'key':'A',
                    'func':self.proc_addr_odelay,
                    'comment':'Processing address and bank lines output delays (using average data for RAS,CAS, WE output delays)',
                    'params':{'commonFine':commonFine,
                              'maxErrPs':CMDAMaxDlyErr,
                              'quiet':quiet+1}},

#                    {'key':'A',
#                    'func':self.save_mcntrl,
#                    'comment':'Save current state as Python pickle',
#                    'params':{'path': 'proc_addr_odelay_%s.pickle'%(s_dqs_pattern), # None, # use path defined by the parameter 'PICKLE'
#                              'quiet':quiet+1}},
                   
                    {'key':'B',
                    'func':self.set_read_branch,
                    'comment':'Try read mode branches and find sel (early/late read command) and wbuf delay, if possible.',
                    'params':{'wbuf_dly':wbuf_dly,
                              'quiet':quiet+1}},
                    {'key':'B',
                    'func':self.set_write_branch,
                    'comment':'Try write mode branches and find sel (early/late read command) and wbuf delay, if possible.',
                    'params':{'dqs_pattern':dqs_pattern,
                              'extraTgl':extraTgl,
                              'quiet':quiet+1}},
                    {'key':'B',
                    'func':self.get_phase_range,
                    'comment':'Find the phase range that satisfies all conditions, possibly filtered by read sel and write sel (early/late command)',
                    'params':{'rsel':rsel,
                              'wsel':wsel,
                              'quiet':quiet+0}},
                    {'key':'S',
                    'func':self.save_mcntrl,
                    'comment':'Save current state as Python pickle',
                    'params':{'path': None, # use path defined by the parameter 'PICKLE'
                              'quiet':quiet+1}},
                    {'key':'S',
                    'func':self.x393_utils.save,
                    'comment':'Save timing parameters as a Verilog header file',
                    'params':{'fileName': None}}, # use path defined by the parameter
                   
                    {'key':'Z',
                    'func':self.show_all_delays,
                    'comment':'Printing results table (delays and errors vs. phase)- all, including invalid phases',
                    'params':{'filter_variants':None, # Here any string
                              'filter_cmda': 'A',
                              'filter_dqsi': 'A',
                              'filter_dqi':  'A',
                              'filter_dqso': 'A',
                              'filter_dqo':  'A',
                              'quiet': quiet+1}},

                    {'key':'Z',
                    'func':self.show_all_delays,
                    'comment':'Printing results table (delays and errors vs. phase)- Only phases that nave valid values for all signals',
                    'params':{'filter_variants':'A', # Here any string
                              'filter_cmda': 'A',
                              'filter_dqsi': 'A',
                              'filter_dqi':  'A',
                              'filter_dqso': 'A',
                              'filter_dqo':  'A',
                              'quiet': quiet+1}},

                  ]
        start_time=time.time()
        last_task_start_time=start_time
        for task_item in task_data: # execute tasks in predefined sequence, if their keys are enabled through arguments (several tasks may be needed for 1 key)
#            if task_item['key'] in tasks.upper():
            if all(k in tasks.upper() for k in task_item['key']):
                tim=time.time()
                if quiet < 5:
                    print ("[%.3f/+%.3f] %s"%(tim-start_time,tim-last_task_start_time,task_item['comment']))
                    print ("     %s("%(task_item['func'].__name__),end="")
#                    print ("task_item=",task_item)
#                    print ("task_item['params']=",task_item['params'])
                    for k,v in task_item['params'].items():
                        print ("%s=%s, "%(k,str(v)),end="")
                    print(")")    
                # TODO: print function name and used arguments
                task_item['func'](**task_item['params'])
                last_task_start_time=tim
        tim=time.time()
        if quiet < 5:
            print ("[%.3f/+%.3f] %s"%(tim-start_time,tim-last_task_start_time,"All Done"))
        
    def load_hardcoded_data(self):
        """
        Debug feature - load hard-coded previously acquired/processed data
        to reduce debugging time for nest stages
        """
        self.adjustment_state["dqi_dqsi"]=            get_test_dq_dqs_data.get_dqi_dqsi()
        self.adjustment_state["maxErrDqsi"]=          get_test_dq_dqs_data.get_maxErrDqsi() 
        self.adjustment_state["dqi_dqsi_parameters"]= get_test_dq_dqs_data.get_dqi_dqsi_parameters()
        self.adjustment_state["dqo_dqso"]=            get_test_dq_dqs_data.get_dqo_dqso()
        self.adjustment_state["maxErrDqso"]=          get_test_dq_dqs_data.get_maxErrDqso() 
        self.adjustment_state["dqo_dqso_parameters"]= get_test_dq_dqs_data.get_dqo_dqso_parameters()
        self.adjustment_state.update(get_test_dq_dqs_data.get_adjust_cmda_odelay())
        self.adjustment_state.update(get_test_dq_dqs_data.get_wlev_data())
        self.adjustment_state.update(get_test_dq_dqs_data.get_dqsi_phase())
        
#        self.adjustment_state['addr_odelay_meas']=    get_test_dq_dqs_data.get_addr_meas()
        self.adjustment_state['addr_meas']=           get_test_dq_dqs_data.get_addr_meas()
        self.adjustment_state['addr_odelay']=         get_test_dq_dqs_data.get_cmda_odelay() # get_addr_odly()
        self.adjustment_state['cmd_meas']=            get_test_dq_dqs_data.get_cmd_meas()
        
    
    def proc_dqi_dqsi(self,
                       lane="all",
                       bin_size=5,
                       primary_set=2,
#                       compare_prim_steps=True, # while scanning, compare this delay with 1 less by primary(not fine) step,
#                                                # save None for fraction in unknown (previous -0.5, next +0.5)
                       data_set_number=2,        # not number - use measured data
                       scale_w=0.0,              # weight for "uncertain" values (where samples chane from all 0 to all 1 in one step)
 
                       quiet=1):
        """
        Run DQ vs DQS fitting for one data lane (0 or 1) using earlier acquired hard-coded data
        @param lane             byte lane to process (or non-number - process all byte lanes of the device) 
        @param bin_size         bin size for the histograms (should be 5/10/20/40)
        @param primary_set      which of the data edge series to use as leading (other will be trailing by 180) 
        @param data_set_number  select one of the hard-coded data sets (sets 0 and 1 use comparing with the data 1 fine step below
                          set #2 (default) used measurement with previous primary step measurement (will not suffer from
                          fine range wider than on primary step)
                          If not number or <0 - use measured data
        @param quiet reduce output
        @param scale_w        weight for "uncertain" values (where samples change from all 0 to all 1 in one step)
                        For sufficient data 0.0 is OK (and seems to work better)- only "analog" samples are considered   
        @return 3-element dictionary of ('early','nominal','late'), each being None or a 160-element list,
                each element being either None, or a list of 3 best DQ delay values for the DQS delay (some mey be None too) 
        """
        if quiet < 3:
            print ("proc_dqi_dqsi(): scale_w=%f"%(scale_w))
        if isinstance (data_set_number,(int,long)) and (data_set_number>=0) :
            if quiet < 4:
                print("Using hard-coded data set #%d"%data_set_number)
            compare_prim_steps=get_test_dq_dqs_data.get_compare_prim_steps_in(data_set_number)
            meas_data=get_test_dq_dqs_data.get_data_in(data_set_number)
        else:
            if quiet < 4:
                print("Using measured data set")
            try:
                compare_prim_steps=self.adjustment_state["patt_prim_steps"]
                meas_data=         self.adjustment_state["patt_meas_data"]
            except:
                print ("Pattern-measured data is not available, exiting")
                return
        meas_delays=[]
        for data in meas_data:
            if data:
                bits=[None]*16
                for b,pData in enumerate(data):
                    if pData:
                        bits[b]=[None]*4
                        for inPhase in (0,1):
                            if pData[inPhase]:
                                for e in (0,1):
                                    if pData[inPhase][e]:
                                        bits[b][inPhase*2+e]=pData[inPhase][e]# [0]
                meas_delays.append(bits)
        if quiet<1:
            x393_lma.test_data(meas_delays,compare_prim_steps,quiet)
        lma=x393_lma.X393LMA()
        rslt = lma.lma_fit_dq_dqs(lane,
                                    bin_size,
                                    1000.0*self.x393_mcntrl_timing.get_dly_steps()['SDCLK_PERIOD'], # 2500.0, # clk_period,
                                    1000.0*self.x393_mcntrl_timing.get_dly_steps()['DLY_STEP'], # 78.0,   # dly_step_ds,
                                    primary_set,
                                    meas_delays,
                                    compare_prim_steps,
                                    scale_w,
                                    quiet)
        if quiet < 4:
            lma.showENLresults(rslt)

        self.adjustment_state["dqi_dqsi_parameters"]=rslt.pop('parameters')
        try:
            self.adjustment_state["maxErrDqsi"]=rslt.pop('maxErrDqs')
            if quiet < 4:
                print("maxErrDqsi={")
                for k,v in self.adjustment_state["maxErrDqsi"].items():
                    print ("'%s':%s,"%(k,str(v)))
                print ("}")
        except:
            print ("maxErrDqs does not exist")
            
        if quiet < 4:
            print ("dqi_dqsi={")
            for k,v in rslt.items():
                print ("'%s':%s,"%(k,str(v)))
            print ("}")
            
        self.adjustment_state["dqi_dqsi"]=rslt         
        return rslt

    def proc_dqsi_phase(self,
                       lane=0, # "all",
                       bin_size_ps=50,
                       data_set_number=0,        # not number - use measured data
                       scale_w=0.1,              # weight for "uncertain" values (where samples chane from all 0 to all 1 in one step)
                       maxDlyErr=200, #ps - trying overlapping dqs branches
                       quiet=1):
        """
        Run DQSI vs PHASE fitting for one data lane (0 or 1) using earlier acquired hard-coded data
        @param lane             byte lane to process (or non-number - process all byte lanes of the device) 
        @param bin_size_ps      histogram bin size (in ps)
        @param data_set_number  select one of the hard-coded data sets (sets 0 and 1 use comparing with the data 1 fine step below
                          set #0 (default) used measurement with previous primary step measurement (will not suffer from
                          fine range wider than on primary step)
                          If not number or <0 - use measured data
        @param scale_w        weight for "uncertain" values (where samples change from all 0 to all 1 in one step)
                        For sufficient data 0.0 is OK (and seems to work better)- only "analog" samples are considered
        @param maxDlyErr - maximal DQS error in ps (currently just to check multiple overlapping branches)   
        @param quiet reduce output
        @return 3-element dictionary of ('early','nominal','late'), each being None or a 160-element list,
                each element being either None, or a list of 3 best DQ delay values for the DQS delay (some mey be None too) 
        """
        if quiet < 3:
            print ("proc_dqsi_phase(): scale_w=%f"%(scale_w))
        if isinstance (data_set_number,(int,long)) and (data_set_number>=0) :
            self.load_hardcoded_data()
            if quiet < 4:
                print("Using hard-coded data set #%d"%data_set_number)
            compare_prim_steps= get_test_dq_dqs_data.get_dqsi_vs_phase_prim_steps(data_set_number)
            dqsi_phase_data=    get_test_dq_dqs_data.get_dqsi_vs_phase(data_set_number)
            dqsi_dqi_parameters=get_test_dq_dqs_data.get_dqi_dqsi_parameters()
            try:
                dqsi_dqi_parameters=get_test_dq_dqs_data.get_dqi_dqsi_parameters()
            except:
                dqsi_dqi_parameters=None
                if quiet < 4:
                    print("DQ vs. DQS input delays calibration parameters are not available yet will use estimated ones")
        else:
            if quiet < 4:
                print("Using measured data set")
            try:
                compare_prim_steps=     self.adjustment_state["dqsi_vs_phase_steps"]
                dqsi_phase_data=         self.adjustment_state["dqsi_vs_phase"]
                try:
                    dqsi_dqi_parameters=     self.adjustment_state["dqi_dqsi_parameters"]
                except:
                    dqsi_dqi_parameters=None
                    if quiet < 4:
                        print("DQ vs. DQS input delays calibration parameters are not available yet will use estimated ones")
            except:
                print ("DQS input delay vs. phase measured data is not available, exiting")
                return
        timing=self.x393_mcntrl_timing.get_dly_steps()
        numPhaseSteps= int(timing['SDCLK_PERIOD']/timing['PHASE_STEP']+0.5)
        lma=x393_lma.X393LMA() # use persistent one?
        
#        print("++++++proc_dqsi_phase(), quiet=",quiet)
            
        dqs_phase=lma.lma_fit_dqs_phase(lane=               lane, # byte lane
                                        bin_size_ps=        bin_size_ps,
                                        clk_period=         1000.0*self.x393_mcntrl_timing.get_dly_steps()['SDCLK_PERIOD'], # 2500.0, # clk_period,
                                        dqs_dq_parameters=  dqsi_dqi_parameters,
                                        tSDQS=              1000.0*self.x393_mcntrl_timing.get_dly_steps()['DLY_STEP']/NUM_FINE_STEPS, # 78.0/5,   # dly_step_ds,
                                        data_set=           dqsi_phase_data, # data_set,
                                        compare_prim_steps= compare_prim_steps,
                                        scale_w=            scale_w,
                                        numPhaseSteps=      numPhaseSteps,
                                        maxDlyErr=          maxDlyErr,
                                        fallingPhase=       False, # fallingPhase
                                        shiftFracPeriod=    0.5, # provided data is marginal, not centered 
                                        quiet=              quiet)
#            rslt_names=("dqs_optimal_ps","dqs_phase","dqs_phase_multi","dqs_phase_err","dqs_min_max_periods")
        gen_keys=dqs_phase.keys()
        for k in gen_keys:
            dqs_phase[k.replace('dqs_','dqsi_')]=dqs_phase.pop(k)
        if quiet < 3:
            print ("dqsi_phase=",dqs_phase)
            numLanes= len(dqs_phase)
            numPhases=len(dqs_phase[0])
            print ("\nphase", end=" ")
            for lane in range (numLanes):
                print("dqsi%d"%(lane),end=" ")
            print()    
            for phase in range (numPhases):
                print ("%d"%(phase),end=" ")
                for lane in range (numLanes):
                    try:
                        print("%d"%(dqs_phase[lane][phase]),end=" ")
                    except:
                        print("?")
                print        
            
        self.adjustment_state.update(dqs_phase)

        #combine DQSI and DQI data to get DQ vs. phase
        delays, errors= self._combine_dq_dqs(dqs_data=self.adjustment_state['dqsi_phase_multi'],
                                             dq_enl_data=self.adjustment_state["dqi_dqsi"],
                                             dq_enl_err = self.adjustment_state["maxErrDqsi"],
                                             quiet=quiet)
        self.adjustment_state['dqi_phase_multi'] = delays
        self.adjustment_state["dqi_phase_err"] =   errors
        return dqs_phase

    def proc_dqso_phase(self,
                       lane=0, # "all",
                       bin_size_ps=50,
                       data_set_number=0,        # not number - use measured data
                       scale_w=0.1,              # weight for "uncertain" values (where samples chane from all 0 to all 1 in one step)
                       maxDlyErr=200, #ps - trying overlapping dqs branches
                       quiet=1):
        """
        Run DQSI vs PHASE fitting for one data lane (0 or 1) using earlier acquired hard-coded data
        @param lane             byte lane to process (or non-number - process all byte lanes of the device) 
        @param bin_size_ps      histogram bin size (in ps)
        @param data_set_number  select one of the hard-coded data sets (sets 0 and 1 use comparing with the data 1 fine step below
                          set #0 (default) used measurement with previous primary step measurement (will not suffer from
                          fine range wider than on primary step)
                          If not number or <0 - use measured data
        @param scale_w        weight for "uncertain" values (where samples change from all 0 to all 1 in one step)
                        For sufficient data 0.0 is OK (and seems to work better)- only "analog" samples are considered
        @param maxDlyErr - maximal DQS error in ps (currently just to check multiple overlapping branches)   
        @param quiet reduce output
        @return 3-element dictionary of ('early','nominal','late'), each being None or a 160-element list,
                each element being either None, or a list of 3 best DQ delay values for the DQS delay (some mey be None too) 
        """
        if quiet < 1:
            print("self.adjustment_state={")
            for k,v in self.adjustment_state.items():
                print("\n'%s': %s,"%(k,str(v)))
            print("}")
        if quiet < 3:
            print ("proc_dqso_phase(): scale_w=%f"%(scale_w))
        if isinstance (data_set_number,(int,long)) and (data_set_number>=0) :
#            self.load_hardcoded_data()
            if quiet < 4:
                print("Using hard-coded data set #%d"%data_set_number)
            compare_prim_steps= get_test_dq_dqs_data.get_wlev_dqs_steps(data_set_number)
            dqso_phase_data=    get_test_dq_dqs_data.get_wlev_dqs_delays(data_set_number)
            try:
#                dqso_dqo_parameters=get_test_dq_dqs_data.get_dqo_dqso_parameters()
                dqso_dqo_parameters=self.adjustment_state["dqo_dqso_parameters"]
            except:
                dqso_dqo_parameters=None
                if quiet < 4:
                    print("DQ vs. DQS output delays calibration parameters are not available yet will use estimated ones")
        else:
            if quiet < 4:
                print("Using measured data set")
            try:
                compare_prim_steps=     self.adjustment_state["wlev_dqs_steps"]
                dqso_phase_data=         self.adjustment_state["wlev_dqs_delays"]
                try:
                    dqso_dqo_parameters=     self.adjustment_state["dqo_dqso_parameters"]
                except:
                    dqso_dqo_parameters=None
                    if quiet < 4:
                        print("DQ vs. DQS output delays calibration parameters are not available yet will use estimated ones")
            except:
                print ("DQS output delay vs. phase measured data (during write levelling) is not available, exiting")
                return
        timing=self.x393_mcntrl_timing.get_dly_steps()
        numPhaseSteps= int(timing['SDCLK_PERIOD']/timing['PHASE_STEP']+0.5)
        lma=x393_lma.X393LMA() # use persistent one?
        
#        print("++++++proc_dqsi_phase(), quiet=",quiet)
                
        dqs_phase=lma.lma_fit_dqs_phase(lane=lane, # byte lane
                                        bin_size_ps=bin_size_ps,
                                        clk_period=1000.0*self.x393_mcntrl_timing.get_dly_steps()['SDCLK_PERIOD'], # 2500.0, # clk_period,
                                        dqs_dq_parameters=dqso_dqo_parameters,
                                        tSDQS=1000.0*self.x393_mcntrl_timing.get_dly_steps()['DLY_STEP']/NUM_FINE_STEPS, # 78.0/5,   # dly_step_ds,
                                        data_set=dqso_phase_data, # data_set,
                                        compare_prim_steps=compare_prim_steps,
                                        scale_w=scale_w,
                                        numPhaseSteps=numPhaseSteps,
                                        maxDlyErr=maxDlyErr,
                                        fallingPhase=True, # fallingPhase
                                        shiftFracPeriod=    0.0, # provided data is centered, not marginal
                                        quiet=quiet)
        
        #Need to modify names to output ones
#            rslt_names=("dqs_optimal_ps","dqs_phase","dqs_phase_multi","dqs_phase_err","dqs_min_max_periods")
        gen_keys=dqs_phase.keys()
        
        for k in gen_keys:
            dqs_phase[k.replace('dqs_','dqso_')]=dqs_phase.pop(k)
        if quiet < 3:
            print ("dqso_phase=",dqs_phase)
                
                
        self.adjustment_state.update(dqs_phase)
        #combine DQSO and DQO data to get DQO vs. phase
        if not dqso_dqo_parameters is None:
            delays, errors= self._combine_dq_dqs(dqs_data=self.adjustment_state['dqso_phase_multi'],
                                                 dq_enl_data=self.adjustment_state["dqo_dqso"],
                                                 dq_enl_err = self.adjustment_state["maxErrDqso"],
                                                 quiet=quiet)
            self.adjustment_state['dqo_phase_multi'] = delays
            self.adjustment_state["dqo_phase_err"] =   errors
            if quiet < 2:
                print("self.adjustment_state={")
                for k,v in self.adjustment_state.items():
                    print("\n'%s': %s,"%(k,str(v)))
                print("}")
            
        else:
            if quiet < 3:
                print ("DQO vs. DQSO dcata is not yet available, skipping '_combine_dq_dqs()'")
        return dqs_phase


    def proc_dqo_dqso(self,
                       lane="all",
                       bin_size=5,
                       primary_set=2,
#                       compare_prim_steps=True, # while scanning, compare this delay with 1 less by primary(not fine) step,
#                                                # save None for fraction in unknown (previous -0.5, next +0.5)
                       data_set_number=0,        # not number - use measured data
                       scale_w=0.0,              # weight for "uncertain" values (where samples chane from all 0 to all 1 in one step)
 
                       quiet=1):
        """
        Run DQ vs DQS fitting for one data lane (0 or 1) using earlier acquired hard-coded data
        @param lane             byte lane to process (or non-number - process all byte lanes of the device) 
        @param bin_size         bin size for the histograms (should be 5/10/20/40)
        @param primary_set      which of the data edge series to use as leading (other will be trailing by 180) 
        @param data_set_number  select one of the hard-coded data sets (sets 0 and 1 use comparing with the data 1 fine step below
                          set #2 (default) used measurement with previous primary step measurement (will not suffer from
                          fine range wider than on primary step)
                          If not number or <0 - use measured data
        @param scale_w        weight for "uncertain" values (where samples change from all 0 to all 1 in one step)
                        For sufficient data 0.0 is OK (and seems to work better)- only "analog" samples are considered   
        @param quiet reduce output
        @return 3-element dictionary of ('early','nominal','late'), each being None or a 160-element list,
                each element being either None, or a list of 3 best DQ delay values for the DQS delay (some mey be None too) 
        """
        if quiet < 3:
            print ("proc_dqi_dqsi(): scale_w=%f"%(scale_w))
        if isinstance (data_set_number,(int,long)) and (data_set_number>=0) :
            if quiet < 4:
                print("Using hard-coded data set #%d"%data_set_number)
            compare_prim_steps=get_test_dq_dqs_data.get_compare_prim_steps_out(data_set_number)
            meas_data=get_test_dq_dqs_data.get_data_out(data_set_number)
        else:
            if quiet < 4:
                print("Using measured data set")
            try:
                compare_prim_steps=self.adjustment_state["write_prim_steps"]
                meas_data=         self.adjustment_state["write_meas_data"]
            except:
                print ("Pattern-measured data is not available, exiting")
                return
        meas_delays=[]
        for data in meas_data:
            if data:
                bits=[None]*16
                for b,pData in enumerate(data):
                    if pData:
                        bits[b]=[None]*4
                        for inPhase in (0,1):
                            if pData[inPhase]:
                                for e in (0,1):
                                    if pData[inPhase][e]:
                                        bits[b][inPhase*2+e]=pData[inPhase][e]# [0]
                meas_delays.append(bits)
        if quiet<1:
            x393_lma.test_data(meas_delays,compare_prim_steps,quiet)
        lma=x393_lma.X393LMA()
        rslt = lma.lma_fit_dq_dqs(lane,
                                    bin_size,
                                    1000.0*self.x393_mcntrl_timing.get_dly_steps()['SDCLK_PERIOD'], # 2500.0, # clk_period,
                                    1000.0*self.x393_mcntrl_timing.get_dly_steps()['DLY_STEP'], # 78.0,   # dly_step_ds,
                                    primary_set,
                                    meas_delays,
                                    compare_prim_steps,
                                    scale_w,
                                    quiet)
        if quiet < 4:
            lma.showENLresults(rslt)

        self.adjustment_state["dqo_dqso_parameters"]=rslt.pop('parameters')
        try:
            self.adjustment_state["maxErrDqso"]=rslt.pop('maxErrDqs')
            if quiet < 4:
                print("maxErrDqso={")
                for k,v in self.adjustment_state["maxErrDqso"].items():
                    print ("'%s':%s,"%(k,str(v)))
                print ("}")
        except:
            print ("maxErrDqs does not exist")
            
        if quiet < 4:
            print ("dqo_dqso={")
            for k,v in rslt.items():
                print ("'%s':%s,"%(k,str(v)))
            print ("}")
        self.adjustment_state["dqo_dqso"]=rslt         
        return rslt
    
    def proc_addr_odelay(self,
                         commonFine=True, # use same values for fine delay
                         maxErrPs=200.0, #ps
                         quiet=2):
        """
        Process delay calibration data for address and bank line, calculate delay scales, shift and rise/fall differences.
        Calculate finedelay corrections and finally optimal delay value for each line each phase
        """
#        self.load_hardcoded_data() # TODO: TEMPORARY - remove later
        try:
#            addr_odelay=self.adjustment_state['addr_odelay_meas']
            addr_odelay=self.adjustment_state['addr_meas']
        except:
            print("No measurement data for address and bank lines is available. Please run 'measure_addr_odelay' first or load 'load_hardcoded_data'")
            return None
        try:
            cmd_odelay=self.adjustment_state['cmd_meas']
        except:
            print("No measurement data for command (WE,RAS,CAS) lines is available. Please run 'measure_cmd_odelay' first or load 'load_hardcoded_data'")
            return None
        numCmdLines=3
        numABLines=vrlg.ADDRESS_NUMBER+3
        numLines=  numABLines+numCmdLines
#        print('addr_odelay=','addr_odelay')
        
        
        dly_steps=self.x393_mcntrl_timing.get_dly_steps()
        numPhaseSteps= int(dly_steps['SDCLK_PERIOD']/dly_steps['PHASE_STEP']+0.5)
        phase_step=1000.0*dly_steps['PHASE_STEP']
        clk_period=1000.0*dly_steps['SDCLK_PERIOD']
        if quiet <1:
            print ("phase_step=%f, clk_period=%f"%(phase_step,clk_period))    
        try:
            cmda_odly_a=self.adjustment_state["cmda_odly_a"]
        except:
            raise Exception ("No cmda_odly_a is available.")
        try:
            cmda_odly_b=self.adjustment_state["cmda_odly_b"]
        except:
            raise Exception ("No cmda_odly_b is available.")
        #Combine measurements for address and command lines
#        print ("cmd_odelay=",cmd_odelay)
        for phase in range (numPhaseSteps):
            if (not addr_odelay[0][phase] is None) or (not cmd_odelay[phase] is None):
                if addr_odelay[0][phase] is None:
                    addr_odelay[0][phase]=[None]*numABLines
                if cmd_odelay[phase] is None:
                    cmd_odelay[phase]=[None]*numCmdLines
                addr_odelay[0][phase] += cmd_odelay[phase]
            if not addr_odelay[1][phase] is None:
                addr_odelay[1][phase] += [None]*numCmdLines
        
        tSA=-clk_period/(numPhaseSteps*cmda_odly_a) # positive 
        variantStep=-cmda_odly_a*numPhaseSteps #how much b changes when moving over the full SDCLK period
        tA=cmda_odly_b*tSA-clk_period/2
        while tA < 0:
            tA+=clk_period
        tOpt=cmda_odly_b*tSA
        while tOpt < 0:
            tOpt+=clk_period
            
        if quiet <1:
            print ("cmda_odly_a=%f, cmda_odly=%f, tSA=%f ps/step, tA=%f ps (%f), variantStep=%f, tOpt=%f(%f)"%(cmda_odly_a,cmda_odly_b, tSA, tA, tA/tSA, variantStep,tOpt,tOpt/tSA))    
#        return
        parameters={# set TSA from cmda_odelay B
                    'tA':  [tA]*numLines,    # static delay in each line, ps
                    # set TSA from cmda_odelay A
                    
                    'tSA': [tSA]*numLines,    # delay per one finedelay step, ps
                    
                    'tAHL':[0.0]*numLines,    # time high - time low, ps
                    'tAF' :[0.0]*((NUM_FINE_STEPS-1)*numLines), # fine delay correction (first 4, last is minus sum of the first 4)
                    'tAFW':[0.0]*((NUM_FINE_STEPS)*numLines) # weight of tAF averaging
                    }
        if quiet <1:
            print("parameters=",parameters)
             
        def proc_addr_step(indx,
                           corrFine=False,
                           useVarStep=False):
            tAF5=parameters['tAF'][(NUM_FINE_STEPS-1)*indx:(NUM_FINE_STEPS-1)*(indx+1)]
            tAF5.append(-sum(tAF5))
            tAF5.append(tAF5[0])
            if (useVarStep):
                tAF5C=[0.5*(tAF5[i]+tAF5[i+1]+ parameters['tSA'][indx]) for i in range(5)]# includes half-step
            else:
                tAF5C=[tAF5[i]+ 0.5*parameters['tSA'][indx] for i in range(5)]# includes half-step
            if quiet <1:
                print ("tAF5=",tAF5)
                print ("tAF5C=",tAF5C)
            S0=0
            SX=0
            SY=0
            SX2=0
            SXY=0
            sAF5=[0.0]*NUM_FINE_STEPS
            nAF5=[0]*NUM_FINE_STEPS
            s01= [0.0]*len(addr_odelay)
            n01= [0]*len(addr_odelay)
            
            for edge,pol_data in enumerate(addr_odelay): 
                for phase, phase_data in enumerate(pol_data):
#                    print("##### ",phase,phase_data)
                    if (not phase_data is None) and (not phase_data[indx] is None):
                        dly=phase_data[indx]
#                        y=-(phase_step*phase+tAF5C[dly %NUM_FINE_STEPS])
                        y=-(phase_step*phase-tAF5C[dly %NUM_FINE_STEPS])
                        diff0= y+parameters['tA'][indx]-parameters['tSA'][indx]*dly
                        periods=int(round(diff0/clk_period))
                        y-=periods*clk_period
                        diff=y+parameters['tA'][indx]-parameters['tSA'][indx]*dly
                        #find closest period and add/subract
                        S0+=1
                        SX+=dly
                        SY+=y
                        SX2+=dly*dly
                        SXY+=dly*y
                        sAF5[dly % NUM_FINE_STEPS]+=diff
                        nAF5[dly % NUM_FINE_STEPS]+=1
                        s01[edge]+=diff
                        n01[edge]+=1
                        if quiet <1:
                            print("%d %d %d %f %f %f"%(edge, phase,dly,y,diff0,diff))
            avgF=0.0
            for i in range (NUM_FINE_STEPS):
                if nAF5[i]:
                    sAF5[i]/=nAF5[i]
                avgF+=sAF5[i]
            avgF/=NUM_FINE_STEPS
            for edge in range(len(addr_odelay)):
                if n01[edge]:
                    s01[edge] /= n01[edge]
                else:
                    s01[edge] = None # commands have onl;y one edge tested
                      
                               
            if quiet <2:
                print ("avgF=",avgF)
                print ("sAF5=",sAF5)
                print ("nAF5=",nAF5)
                print ("s01=",s01)
                
            if quiet <2:
                print ("parameters['tSA'][%d]="%indx,parameters['tSA'][indx], " (old)")
                print ("parameters['tA'][%d]="%indx,parameters['tA'][indx], " (old)")
                print ("parameters['tAHL'][%d]="%indx,parameters['tAHL'][indx], " (old)")
                print ("tAF4=",parameters['tAF'][4*indx:4*(indx+1)], "(old)")
            parameters['tSA'][indx] = (SXY*S0 - SY*SX) / (SX2*S0 - SX*SX)
            parameters['tA'][indx] =  - (SY*SX2 - SXY*SX) / (SX2*S0 - SX*SX)
            try:
                parameters['tAHL'][indx] =  2*(s01[0]-s01[1])
            except:
                parameters['tAHL'][indx] = None
            if corrFine:
                for i in range (NUM_FINE_STEPS-1):
#                    parameters['tAF'][(NUM_FINE_STEPS-1)*indx+i] += sAF5[i] - avgF
                    parameters['tAF'][(NUM_FINE_STEPS-1)*indx+i] -= sAF5[i] - avgF
                for i in range (NUM_FINE_STEPS):
                    parameters['tAFW'][NUM_FINE_STEPS*indx+i] =nAF5[i]
                    
            if quiet <2:
                print ("parameters['tSA'][%d]="%indx,parameters['tSA'][indx])
                print ("parameters['tA'][%d]="%indx,parameters['tA'][indx])
                print ("parameters['tAHL'][%d]="%indx,parameters['tAHL'][indx])
                print ("tAF4=",parameters['tAF'][4*indx:4*(indx+1)])
                print ("parameters=",parameters)
            # correct finedelay values
        def average_finedelays():
            tAF5A=[0.0]*NUM_FINE_STEPS
            tAF5W=[0.0]*NUM_FINE_STEPS
            for line in range(numLines):
                tAF5Ai=parameters['tAF'][(NUM_FINE_STEPS-1)*line:(NUM_FINE_STEPS-1)*(line+1)]
                tAF5Ai.append(-sum(tAF5Ai))
                tAF5Wi=parameters['tAFW'][NUM_FINE_STEPS*line:NUM_FINE_STEPS*(line+1)]
                for i in range (NUM_FINE_STEPS):
                    tAF5A[i]+=tAF5Ai[i]*tAF5Wi[i]
                    tAF5W[i]+=tAF5Wi[i]
            for i in range (NUM_FINE_STEPS):
                if tAF5W[i] > 0.0:
                    tAF5A[i]/=tAF5W[i]
            avg=sum(tAF5A) / NUM_FINE_STEPS    
            if quiet<2:
                print ("tAF5A=",tAF5A)
                print ("tAF5W=",tAF5W)
                print ("avg=",avg)
            for i in range (NUM_FINE_STEPS):
                tAF5A[i]-=avg
            return tAF5A
        
        def get_optimal_multi(phase,maxErrPs):
            """
            Return a dictionary of two dictionaries, both indexed by integers (positive, 0 or negative
            that mean number of full clock cycles.
            Elements of the first dictionary are lists of bit delays, of the second - maximal error (in ps)
            branches are determined by the average parameters (last set of parameters)
            """
            avg_index=numLines # len(parameters['tA'])-1
            num_items=numLines+1
            s_avg=parameters['tSA'][avg_index]
            t_avg= parameters['tA'][avg_index]-phase_step*phase - clk_period/2
            avg_max_delay=s_avg*NUM_DLY_STEPS # maximal delay with average line
            '''
            periods=0
            while t_avg < -maxErrPs:
                t_avg   += clk_period
                periods += 1
            if t_avg > avg_max_delay:
                t_avg -= clk_period
                periods -= 1
                if t_avg < -maxErrPs:
                    if quiet < 2:
                        print ("No solution for average signal for phase=",phase)
                    return None
            '''
            periods=int(round((t_avg+ +maxErrPs)/clk_period - 0.5))
            period_options=[]
            while (t_avg - clk_period*periods) < (avg_max_delay + maxErrPs):
                period_options.append(periods)
                periods-=1
            delays_multi={}
            errors_multi={}
            if quiet<2:
                print ("\n%d: period_options=%s, t_avg=%f"%(phase,str(period_options),t_avg))

            for periods in period_options:
                delays=[]
                worst_err=-1
                for line in range(num_items): #+1):
                    tAF5=parameters['tAF'][(NUM_FINE_STEPS-1)*line:(NUM_FINE_STEPS-1)*(line+1)]
                    tAF5.append(-sum(tAF5))
                    best_dly=None
                    best_err=None
                    if quiet < 1:
                        dbg_dly=[]
                    for dly in range (NUM_DLY_STEPS):
                        #TODO: verify finedelay polarity
                        try:
#                            t_dly=parameters['tA'][line]-parameters['tSA'][line]*dly -phase_step*phase - clk_period/2 + tAF5[dly %NUM_FINE_STEPS] + periods*clk_period
                            t_dly=parameters['tA'][line]-parameters['tSA'][line]*dly -phase_step*phase - clk_period/2 + tAF5[dly %NUM_FINE_STEPS] - periods*clk_period
                            if quiet<1:
                                print ("%d: period_options=%s, t_avg=%f"%(phase,str(period_options),t_avg))
                        except:
                            print ("line=",line)
                            print ("parameters['tA']=",parameters['tA'])
                            print ("parameters['tSA']=",parameters['tSA'])
                            print ("tAF5=",tAF5)
                            
                            raise Exception("That's all")
                        if quiet < 1:
                            dbg_dly.append(t_dly)
                        if (best_dly is None) or (abs(t_dly) < abs(best_err)):
                            best_dly=dly
                            best_err=t_dly
                    if quiet < 2:
                        print ("phase=%d, periods=%d best_dly=%d, best_err=%f"%(phase, periods, best_dly, best_err),end=" ")
                    delays.append(best_dly)
                    if worst_err< abs(best_err):
                        worst_err = abs(best_err)
                if quiet < 1:
                    print ()
                    print (dbg_dly)
                if worst_err > maxErrPs:
                    if quiet < 2:
                        print ("Worst signal error (%f ps) is too high (>%f ps, %f clk_periods) for phase %d"%(worst_err, maxErrPs,maxErrPs/clk_period, phase))
                    continue
                if worst_err < 0:
                    if quiet < 2:
                        print ("No signal meets requirements for periods=%d, phase %d"%(periods, phase))
                    continue
                delays_multi[periods]=delays
                errors_multi[periods]=worst_err
            if delays_multi:   
                return {'err':errors_multi,
                        'dlys':delays_multi}
            else:
                return None        

        #main method body:
        
        for line in range(numLines):
            for _ in range (6):
                proc_addr_step(line,1,0)
        if quiet<3:
            print ("parameters=",parameters)
        if commonFine:
            tAF5A=average_finedelays()    
            for line in range(numLines):
                for i in range (NUM_FINE_STEPS-1):
                    parameters['tAF'][(NUM_FINE_STEPS-1)*line+i] = tAF5A[i]
            for line in range(numLines):
                for _ in range (2):
                    proc_addr_step(line,0,1)
        # Calculate average parameters (to be used for command bits until found better measurement for them:
#        print ("0:len(parameters['tAFW'])=",len(parameters['tAFW']))
        parameters['tAF'] += average_finedelays()[:NUM_FINE_STEPS-1] # do only once - increases length of parameters items
#        print ("1:len(parameters['tAFW'])=",len(parameters['tAFW']))
        for k in ("tSA",'tA','tAHL'):
            try:
                parameters[k].append(sum(parameters[k])/numLines)
            except:
                s=0.0
                n=0
                for d in parameters[k]:
                    if not d is None:
                        s+=d
                        n+=1
                if n>0:
                    parameters[k].append(s/n)
                else:
                    parameters[k].append(None)        
        tAF5A=average_finedelays()

        if quiet<3:
            print ("parameters=",parameters)
                
        #find best solutions/errors
        delays=[]
        errors=[]
        for phase in range(numPhaseSteps):
#            dly_err=get_optimal_dlys(phase,max_err)
            dly_err=get_optimal_multi(phase,maxErrPs)
            if not dly_err is None:
                delays.append(dly_err['dlys'])
                errors.append(dly_err['err'])
            else:
                delays.append(None)
                errors.append(None)
                
        if quiet < 4:
            min_max=None
            for phase_data in delays:
                for k in phase_data.keys():
                    try:
                        min_max[0]=min(min_max[0],k)
                        min_max[1]=max(min_max[1],k)
                    except:
                        min_max=[k,k]
            print ("\nmin_max=",min_max)
            
            for phase in range(numPhaseSteps):
                print("%d"%(phase), end=" ")
                if not delays[phase] is None:
                    for p in range(min_max[0],min_max[1]+1):
                        for line in range(numLines):
#                        for d in delays[phase][p]:
                            try:
                                print ("%s"%(str(delays[phase][p][line])),end=" ")
                            except:
                                print("?",end=" ")
                        try:
                            print ("%s"%(str(errors[phase][p])),end=" ")
                        except:          
                            print("?",end=" ")
                print()
        rslt={'err':errors,
              'dlys':delays}
        if quiet < 4:
            print("addr_odelay={")
            print("'dlys': ",rslt['dlys'],",")
            print("'err': ",rslt['err'])
            print("}")
        if quiet<3:
            print ("parameters=",parameters)
        self.adjustment_state['addr_odelay']= rslt
        return rslt  
 
            
    def save_mcntrl(self,
                    path=None,
                    quiet=1):
        """
        Save memory controller delays measuremnt/adjustment state to file
        @param path location to save state or None to use path defined by parameter PICKLE
        @return None, raises exception if path is not provided and PICKLE is not defined
        """
        if path is None:
            try:
                path=vrlg.PICKLE
            except:
                raise Exception ("path is not provided and Verilog parameter PICKLE is not defined")
        pickle.dump(self.adjustment_state, open(path, "wb" ))
        if quiet <2:
            print ("mcntrl state (self.adjustment_state) is saved to %s"%(path))
        
    def load_mcntrl(self,
                    path=None,
                    quiet=1):
        """
        Load memory controller delays measuremnt/adjustment state from file
        @param path location to load state from or None to use path defined by parameter PICKLE
        @return None, raises exception if path is not provided and PICKLE is not defined
        """
        if path is None:
            try:
                path=vrlg.PICKLE
            except:
                raise Exception ("path is not provided and Verilog parameter PICKLE is not defined")
        self.adjustment_state=pickle.load(open(path, "rb" ))
        if quiet <2:
            print ("mcntrl state (self.adjustment_state) is loaded from %s"%(path))
            if quiet<1:
                print ("self.adjustment_state=",self.adjustment_state)
            
            