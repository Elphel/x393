from __future__ import division
from __future__ import print_function

'''
# Copyright (C) 2015, Elphel.inc.
# Class to control image acquisition and compression functionality  
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
#import sys
#import pickle
from x393_mem                import X393Mem
import x393_axi_control_status
import x393_camsync
import x393_gpio
import x393_cmprs_afi
import x393_cmprs
import x393_frame_sequencer
import x393_sensor
import x393_rtc
import x393_mcntrl_membridge
import x393_utils

import time
import vrlg
import x393_mcntrl

from verilog_utils import hx


PAGE_SIZE =           4096
#SI5338_PATH =         '/sys/devices/amba.0/e0004000.ps7-i2c/i2c-0/0-0070'
#POWER393_PATH =       '/sys/devices/elphel393-pwr.1'
#MEM_PATH =            '/sys/devices/elphel393-mem.2/'

SI5338_PATH =         '/sys/devices/soc0/amba@0/e0004000.ps7-i2c/i2c-0/0-0070'
POWER393_PATH =       '/sys/devices/soc0/elphel393-pwr@0'
MEM_PATH =            '/sys/devices/soc0/elphel393-mem@0/'

BUFFER_ADDRESS_NAME = 'buffer_address'
BUFFER_PAGES_NAME =   'buffer_pages'
BUFFER_ADDRESS =      None # in bytes
BUFFER_LEN =          None # in bytes
BUFFER_ADDRESS_NAME =       'buffer_address'
BUFFER_PAGES_NAME =         'buffer_pages'
BUFFER_H2D_ADDRESS_NAME =   'buffer_address_h2d'
BUFFER_H2D_PAGES_NAME =     'buffer_pages_h2d'
BUFFER_D2H_ADDRESS_NAME =   'buffer_address_d2h'
BUFFER_D2H_PAGES_NAME =     'buffer_pages_d2h'
BUFFER_BIDIR_ADDRESS_NAME = 'buffer_address_bidir'
BUFFER_BIDIR_PAGES_NAME =   'buffer_pages_bidir'

BUFFER_FOR_CPU =             'sync_for_cpu' # add suffix
BUFFER_FOR_DEVICE =          'sync_for_device' # add suffix

BUFFER_FOR_CPU_H2D =         'sync_for_cpu_h2d'
BUFFER_FOR_DEVICE_H2D =      'sync_for_device_h2d'

BUFFER_FOR_CPU_D2H =         'sync_for_cpu_d2h'
BUFFER_FOR_DEVICE_D2H =      'sync_for_device_d2h'

BUFFER_FOR_CPU_BIDIR =       'sync_for_cpu_bidir'
BUFFER_FOR_DEVICE_BIDIR =    'sync_for_device_bidir'


GLBL_CIRCBUF_CHN_SIZE = None
GLBL_CIRCBUF_STARTS =   None
GLBL_CIRCBUF_ENDS =   None
GLBL_CIRCBUF_END =      None

GLBL_MEMBRIDGE_START =  None
GLBL_MEMBRIDGE_END =    None

GLBL_MEMBRIDGE_H2D_START =  None
GLBL_MEMBRIDGE_H2D_END =    None

GLBL_MEMBRIDGE_D2H_START =  None
GLBL_MEMBRIDGE_D2H_END =    None

GLBL_BUFFER_END =       None
GLBL_WINDOW =           None

BUFFER_ADDRESS =          None # in bytes
BUFFER_LEN =              None # in bytes

BUFFER_ADDRESS_H2D =      None # in bytes
BUFFER_LEN_H2D =          None # in bytes

BUFFER_ADDRESS_D2H =      None # in bytes
BUFFER_LEN_D2H =          None # in bytes

BUFFER_ADDRESS_BIDIR =    None # in bytes
BUFFER_LEN_BIDIR =        None # in bytes


#SENSOR_INTERFACE_PARALLEL = "PAR12"
#SENSOR_INTERFACE_HISPI =    "HISPI"
# for now - single sensor type per interface
SENSOR_INTERFACES={x393_sensor.SENSOR_INTERFACE_PARALLEL: {"mv":2800, "freq":24.0,   "iface":"2V5_LVDS"},
                   x393_sensor.SENSOR_INTERFACE_HISPI:    {"mv":1820, "freq":24.444, "iface":"1V8_LVDS"}}
#                   x393_sensor.SENSOR_INTERFACE_HISPI:    {"mv":2500, "freq":24.444, "iface":"1V8_LVDS"}}

SENSOR_DEFAULTS= {x393_sensor.SENSOR_INTERFACE_PARALLEL: {"width":2592, "height":1944, "top":0, "left":0, "slave":0x48, "i2c_delay":100, "bayer":3},
                   x393_sensor.SENSOR_INTERFACE_HISPI:   {"width":4384, "height":3288, "top":0, "left":0, "slave":0x10, "i2c_delay":100, "bayer":2}}

#SENSOR_DEFAULTS_SIMULATION= {x393_sensor.SENSOR_INTERFACE_PARALLEL: {"width":2592, "height":1944, "top":0, "left":0, "slave":0x48, "i2c_delay":100, "bayer":3},
#                             x393_sensor.SENSOR_INTERFACE_HISPI:   {"width":4384, "height":3288, "top":0, "left":0, "slave":0x10, "i2c_delay":100, "bayer":2}}
class X393SensCmprs(object):
    DRY_MODE =           True # True
    DEBUG_MODE =         1
    x393_mem =           None
    x393_axi_tasks =     None #x393X393AxiControlStatus
    x393_utils =         None
    verbose =            1

    x393Camsync =        None
    x393GPIO =           None
    x393CmprsAfi =       None
    x393Cmprs =          None
    x393FrameSequencer = None
    x393Sensor =         None
    x393Rtc =            None
    x393Membridge =      None
    
    def __init__(self, debug_mode=1,dry_mode=True, saveFileName=None):
#        global BUFFER_ADDRESS, BUFFER_LEN
        global BUFFER_ADDRESS, BUFFER_LEN, COMMAND_ADDRESS, DATAIN_ADDRESS, DATAOUT_ADDRESS
        global BUFFER_ADDRESS_H2D, BUFFER_LEN_H2D, BUFFER_ADDRESS_D2H, BUFFER_LEN_D2H, BUFFER_ADDRESS_BIDIR, BUFFER_LEN_BIDIR
#        global SENSOR_DEFAULTS_SIMULATION 
        print ("X393SensCmprs.__init__: dry_mode=",dry_mode)
        if (dry_mode):
            try:
                if ":" in dry_mode:
                    print ("X393SensCmprs.__init__: setting SENSOR_DEFAULTS")
                    SENSOR_DEFAULTS[x393_sensor.SENSOR_INTERFACE_PARALLEL]["width"]=  vrlg.WOI_WIDTH + 2 # 4
                    SENSOR_DEFAULTS[x393_sensor.SENSOR_INTERFACE_PARALLEL]["height"]= vrlg.WOI_HEIGHT + 4
                    SENSOR_DEFAULTS[x393_sensor.SENSOR_INTERFACE_PARALLEL]["top"]=    0
                    SENSOR_DEFAULTS[x393_sensor.SENSOR_INTERFACE_PARALLEL]["left"]=   0
                    SENSOR_DEFAULTS[x393_sensor.SENSOR_INTERFACE_HISPI]["width"]=     vrlg.WOI_WIDTH + 2 #4
                    SENSOR_DEFAULTS[x393_sensor.SENSOR_INTERFACE_HISPI]["height"]=    vrlg.WOI_HEIGHT + 4
                    SENSOR_DEFAULTS[x393_sensor.SENSOR_INTERFACE_HISPI]["top"]=       0
                    SENSOR_DEFAULTS[x393_sensor.SENSOR_INTERFACE_HISPI]["left"]=      0
                    print ("Using simulation size sensor defaults ",SENSOR_DEFAULTS)
                    
            except:
                print ("No simulation server is used, just running in dry mode")       
                
        self.DEBUG_MODE=  debug_mode
        self.DRY_MODE=    dry_mode
        self.x393_mem=            X393Mem(debug_mode,dry_mode)
        self.x393_axi_tasks=      x393_axi_control_status.X393AxiControlStatus(debug_mode,dry_mode)
        self.x393_utils=          x393_utils.X393Utils(debug_mode,dry_mode, saveFileName) # should not overwrite save file path
        
        self.x393Camsync =        x393_camsync.X393Camsync(debug_mode,dry_mode, saveFileName)
        self.x393GPIO =           x393_gpio.X393GPIO(debug_mode,dry_mode, saveFileName)
        self.x393CmprsAfi =       x393_cmprs_afi.X393CmprsAfi(debug_mode,dry_mode, saveFileName)
        self.x393Cmprs =          x393_cmprs.X393Cmprs(debug_mode,dry_mode, saveFileName)
        self.x393FrameSequencer = x393_frame_sequencer.X393FrameSequencer(debug_mode,dry_mode, saveFileName)
        self.x393Sensor =         x393_sensor.X393Sensor(debug_mode,dry_mode, saveFileName)
        self.x393Rtc =            x393_rtc.X393Rtc(debug_mode,dry_mode, saveFileName)
        self.x393Membridge =      x393_mcntrl_membridge.X393McntrlMembridge(debug_mode,dry_mode)
        try:
            self.verbose=vrlg.VERBOSE
        except:
            pass
        if dry_mode:
            """
            BUFFER_ADDRESS =       0x38100000
            BUFFER_LEN =           0x06400000
            BUFFER_ADDRESS_H2D =   0x38100000
            BUFFER_LEN_H2D =       0x06400000
            BUFFER_ADDRESS_D2H =   0x38100000
            BUFFER_LEN_D2H =       0x06400000
            BUFFER_ADDRESS_BIDIR = 0x38100000
            BUFFER_LEN_BIDIR =     0x06400000
            """

            BUFFER_ADDRESS =       0x25500000
            BUFFER_LEN =           0x19000000
            BUFFER_ADDRESS_H2D =   0x25500000
            BUFFER_LEN_H2D =       0x19000000
            BUFFER_ADDRESS_D2H =   0x25500000
            BUFFER_LEN_D2H =       0x19000000
            BUFFER_ADDRESS_BIDIR = 0x25500000
            BUFFER_LEN_BIDIR =     0x19000000

            
            
            print ("Running in simulated mode, using hard-coded addresses:")
        else:
            try:
                with open(MEM_PATH + BUFFER_ADDRESS_NAME) as sysfile:
                    BUFFER_ADDRESS = int(sysfile.read(),0)
                with open(MEM_PATH + BUFFER_PAGES_NAME) as sysfile:
                    BUFFER_LEN = PAGE_SIZE * int(sysfile.read(),0)
            except:
                print("Failed to get reserved physical memory range")
                print('BUFFER_ADDRESS=', BUFFER_ADDRESS)    
                print('BUFFER_LEN=', BUFFER_LEN)    
                return

            try:
                with open(MEM_PATH + BUFFER_H2D_ADDRESS_NAME) as sysfile:
                    BUFFER_ADDRESS_H2D=int(sysfile.read(),0)
                with open(MEM_PATH+BUFFER_H2D_PAGES_NAME) as sysfile:
                    BUFFER_LEN_H2D=PAGE_SIZE*int(sysfile.read(),0)
            except:
                print("Failed to get reserved physical memory range")
                print('BUFFER_ADDRESS_H2D=',BUFFER_ADDRESS_H2D)    
                print('BUFFER_LEN_H2D=',BUFFER_LEN_H2D)    
                return
            
            try:
                with open(MEM_PATH + BUFFER_D2H_ADDRESS_NAME) as sysfile:
                    BUFFER_ADDRESS_D2H=int(sysfile.read(),0)
                with open(MEM_PATH+BUFFER_D2H_PAGES_NAME) as sysfile:
                    BUFFER_LEN_D2H=PAGE_SIZE*int(sysfile.read(),0)
            except:
                print("Failed to get reserved physical memory range")
                print('BUFFER_ADDRESS_D2H=',BUFFER_ADDRESS_D2H)    
                print('BUFFER_LEN_D2H=',BUFFER_LEN_D2H)    
                return
            
            try:
                with open(MEM_PATH + BUFFER_BIDIR_ADDRESS_NAME) as sysfile:
                    BUFFER_ADDRESS_BIDIR=int(sysfile.read(),0)
                with open(MEM_PATH+BUFFER_BIDIR_PAGES_NAME) as sysfile:
                    BUFFER_LEN_BIDIR=PAGE_SIZE*int(sysfile.read(),0)
            except:
                print("Failed to get reserved physical memory range")
                print('BUFFER_ADDRESS_BIDIR=',BUFFER_ADDRESS_BIDIR)    
                print('BUFFER_LEN_BIDIR=',BUFFER_LEN_BIDIR)    
                return
            
            
        print('X393SensCmprs: BUFFER_ADDRESS=0x%x'%(BUFFER_ADDRESS))    
        print('X393SensCmprs: BUFFER_LEN=0x%x'%(BUFFER_LEN))
    def get_histogram_byte_start(self): # should be 4KB page aligned
        global BUFFER_ADDRESS
        return BUFFER_ADDRESS
    def get_circbuf_byte_start(self): # should be 4KB page aligned
        global BUFFER_ADDRESS
        return BUFFER_ADDRESS + 4096* (1 << vrlg.NUM_FRAME_BITS)* 16 # 16 subchannels 
    def get_circbuf_byte_end(self): # should be 4KB page aligned
        global BUFFER_ADDRESS, BUFFER_LEN
        return BUFFER_ADDRESS + BUFFER_LEN
    def sleep_ms(self, time_ms):
        """
        Sleep for specified number of milliseconds
        @param time_ms - sleep time in milliseconds
        """    
        time.sleep(0.001*time_ms)
    def setSensorClock(self, freq_MHz = 24.0, iface = "2V5_LVDS", quiet = 0):
        """
        Set up external clock for sensor-synchronous circuitry (and sensor(s) themselves. 
        Currently required clock frequency is 1/4 of the sensor clock, so it is 24MHz for 96MHz sensor
        @param freq_MHz - input clock frequency (MHz). Currently for 96MHZ sensor clock it should be 24.0
        @param iface - one of the supported interfaces
               (see ls /sys/devices/soc0/amba@0/e0004000.ps7-i2c/i2c-0/0-0070/output_drivers)
        @param quiet - reduce output        
        """
        if self.DRY_MODE:
            print ("Not defined for simulation mode")
            return
        with open ( SI5338_PATH + "/output_drivers/" + iface,      "w") as f:
            print("2", file = f)
        with open ( SI5338_PATH + "/output_clocks/out2_freq_fract","w") as f:
            print("%d"%(round(1000000*freq_MHz)), file = f )
        if quiet == 0:
            print ("Set sensor clock to %f MHz, driver type \"%s\""%(freq_MHz,iface))    
    def setSensorPower(self, sub_pair=0, power_on=0, quiet=0):
        """
        @param sub_pair - pair of the sensors: 0 - sensors 1 and 2, 1 - sensors 3 and 4 
        @param power_on - 1 - power on, 0 - power off (both sensor power and interface/FPGA bank voltage) 
        @param quiet - reduce output        
        """
        if quiet == 0:
            print (("vcc_sens01 vp33sens01", "vcc_sens23 vp33sens23")[sub_pair]+" -> "+POWER393_PATH + "/channels_"+ ("dis","en")[power_on])    
        with open (POWER393_PATH + "/channels_"+ ("dis","en")[power_on],"w") as f:
            print(("vcc_sens01 vp33sens01", "vcc_sens23 vp33sens23")[sub_pair], file = f)

    def setSensorIfaceVoltage(self, sub_pair, voltage_mv, quiet = 0):
        """
        Set interface voltage (should be done before power is on) 
        @param sub_pair - pair of the sensors: 0 - sensors 1 and 2, 1 - sensors 3 and 4 
        @param voltage_mv - desired interface voltage (1800..2800 mv) 
        @param quiet - reduce output        
        """
        with open (POWER393_PATH + "/voltages_mv/"+ ("vcc_sens01", "vcc_sens23")[sub_pair],"w") as f:
            print(voltage_mv, file = f)
        if quiet == 0:
            print ("Set sensors %s interface voltage to %d mV"%(("0, 1","2, 3")[sub_pair],voltage_mv))    
        time.sleep(0.1)

    def setupSensorsPower(self, ifaceType,  pairs = "all", quiet=0, dly=0.0):
        """
        Set interface voltage and turn on power for interface and the sensors
        according to sensor type 
        @param pairs - 'all' or list/tuple of pairs of the sensors: 0 - sensors 1 and 2, 1 - sensors 3 and 4 
        @param quiet - reduce output        
        @param dly - debug feature: step delay in sec        
        """
        try:
            if (pairs == all) or (pairs[0].upper() == "A"): #all is a built-in function
                pairs = (0,1)
        except:
            pass
        if not isinstance(pairs,(list,tuple)):
            pairs = (pairs,)
        for pair in pairs:            
            self.setSensorIfaceVoltagePower(sub_pair =   pair,
                                            voltage_mv = SENSOR_INTERFACES[ifaceType]["mv"],
                                            quiet =      quiet,
                                            dly =        dly)
        
    def setSensorIfaceVoltagePower(self, sub_pair, voltage_mv, quiet=0, dly=0.0):
        """
        Set interface voltage and turn on power for interface and the sensors 
        @param sub_pair - pair of the sensors: 0 - sensors 1 and 2, 1 - sensors 3 and 4 
        @param voltage_mv - desired interface voltage (1800..2800 mv) 
        @param quiet - reduce output        
        @param dly - debug feature: step delay in sec        
        """
        self.setSensorPower(sub_pair = sub_pair, power_on = 0)
        time.sleep(2*dly)
        self.setSensorIfaceVoltage(sub_pair=sub_pair, voltage_mv = voltage_mv)
        time.sleep(2*dly)
        if self.DRY_MODE:
            print ("Not defined for simulation mode")
            return
        if quiet == 0:
            print ("Turning on interface power %f V for sensors %s"%(voltage_mv*0.001,("0, 1","2, 3")[sub_pair]))    
        time.sleep(3*dly)
        with open (POWER393_PATH + "/channels_en","w") as f:
            print(("vcc_sens01", "vcc_sens23")[sub_pair], file = f)
        if quiet == 0:
            print ("Turned on interface power %f V for sensors %s"%(voltage_mv*0.001,("0, 1","2, 3")[sub_pair]))    
        time.sleep(3*dly)
        with open (POWER393_PATH + "/channels_en","w") as f:
            print(("vp33sens01", "vp33sens23")[sub_pair], file = f)
        if quiet == 0:
            print ("Turned on +3.3V power for sensors %s"%(("0, 1","2, 3")[sub_pair]))    
        time.sleep(2*dly)


    def setupSensorsPowerClock(self, setPower=False, quiet=0):
        """
        Set interface voltage for all sensors, clock for frequency and sensor power
        for the interface matching bitstream file
        Not possible for diff. termination - power should be set before the bitstream
        """
        ifaceType = self.x393Sensor.getSensorInterfaceType();
        if setPower:
            if quiet == 0:
                print ("Configuring sensor ports for interface type: \"%s\""%(ifaceType))    
            for sub_pair in (0,1):
                self.setSensorIfaceVoltagePower(sub_pair, SENSOR_INTERFACES[ifaceType]["mv"])
        self.setSensorClock(freq_MHz = SENSOR_INTERFACES[ifaceType]["freq"], iface = SENSOR_INTERFACES[ifaceType]["iface"])    
        
#    def setSensorClock(self, freq_MHz = 24.0, iface = "2V5_LVDS"):

    def setup_sensor_channel (self,
                              exit_step =                 None,
                              num_sensor =                0,
#                              histogram_start_phys_page, # Calculate from?
#                              frame_full_width, # 13-bit Padded line length (8-row increment), in 8-bursts (16 bytes)
                              window_width =              None, # 2592,   # 2592
                              window_height =             None, # 1944,   # 1944
                              window_left =               None, # 0,     # 0
                              window_top =                None, # 0, # 0? 1?
#                              compressor_left_margin =    0, #0?`1? 
#                              frame_start_address, # calculate through num_sensor, num frames, frame size and start addr?
#                              frame_start_address_inc,
                              last_buf_frame =            1,  #  - just 2-frame buffer
                              colorsat_blue =             0x120,     # 0x90 fo 1x
                              colorsat_red =              0x16c,     # 0xb6 for x1
                              clk_sel =                   1,         # 1
                              histogram_left =            None, # 0,
                              histogram_top =             None, # 0,
                              histogram_width_m1 =        None, # 2559, #0,
                              histogram_height_m1 =       None, # 1935, #0,
                              verbose =                   1):
        """
        Setup one sensor+compressor channel (for one sub-channel only)
        @param exit_step -         exit after executing specified step:
                                 10 - just after printing calculated values
                                 11 - after programming status
                                 12 - after setup_sensor_memory
                                 13 - after enabling memory controller for the sensor channel
                                 14 - after setup_compressor_channel
                                 15 - after setup_compressor_memory
                                 16 - after compressor run
                                 17 - removing MRST from the sensor
                                 18 - after vignetting, gamma and histograms setup
                                 19 - enabling sensor memory controller (histograms in not yet)
        @param num_sensor - sensor port number (0..3)
        @param window_width -      (here - in pixels)
        @param window_height -     16-bit window height in scan lines
        @param window_left -       left margin of the window (here - in pixels)
        @param window_top -        top margin of the window (16 bit)
        @param last_buf_frame) -   16-bit number of the last frame in a buffer
        @param colorsat_blue - color saturation for blue (10 bits), 0x90 for 100%
        @param colorsat_red -  color saturation for red (10 bits), 0xb6 for 100%
        @param clk_sel - True - use pixel clock from the sensor, False - use internal clock (provided to the sensor), None - no chnage
        @param histogram_left -      histogram window left margin
        @param histogram_top -       histogram window top margin
        @param histogram_width_m1 -  one less than window width. If 0 - use frame right margin (end of HACT)
        @param histogram_height_m1 - one less than window height. If 0 - use frame bottom margin (end of VACT)
        
        ???
        @param verbose - verbose level
        @return True if all done, False if exited prematurely through exit_step
        """
#        @param compressor_left_margin - 0..31 - left margin for compressor (to the nearest 32-byte column)
        sensorType = self.x393Sensor.getSensorInterfaceType()
        if verbose > 0 :
            print ("Sensor port %d interface type: %s"%(num_sensor, sensorType))
        window = self.specify_window (window_width =  window_width,
                                      window_height = window_height,
                                      window_left =   window_left,
                                      window_top =    window_top,
                                      cmode =         None, # will use 0
                                      verbose =       0)
        window_width =   window["width"]
        window_height =  window["height"]
        window_left =    window["left"]
        window_top =     window["top"]
        """
        cmode =          window["cmode"]
        if window_width is None:
            window_width = SENSOR_DEFAULTS[sensorType]["width"]
        if window_height is None:
            window_height = SENSOR_DEFAULTS[sensorType]["height"]
        if window_left is None:
            window_left = SENSOR_DEFAULTS[sensorType]["left"]
        if window_top is None:
            window_top = SENSOR_DEFAULTS[sensorType]["top"]
        """
            
        #setting up histogram window, same for parallel, similar for serial
                    
        if histogram_left is None:
            histogram_left = 0
        if histogram_top is None:
            histogram_top = 0
        if histogram_width_m1 is None:
            histogram_width_m1 = window_width - 33
        if histogram_height_m1 is None:
            histogram_height_m1 = window_height - 9

        
        align_to_bursts = 64 # align full width to multiple of align_to_bursts. 64 is the size of memory access
        width_in_bursts = window_width >> 4
        if (window_width & 0xf):
            width_in_bursts += 1
        compressor_left_margin = window_left % 32
    
        num_burst_in_line = (window_left >> 4) + width_in_bursts
        num_pages_in_line = num_burst_in_line // align_to_bursts;
        if num_burst_in_line % align_to_bursts:
            num_pages_in_line += 1
#        frame_full_width -  13-bit Padded line length (8-row increment), in 8-bursts (16 bytes)
#        frame_start_address_inc - 22-bit frame start address increment  ((3 CA LSBs==0. BA==0)
##        frame_full_width =  num_pages_in_line * align_to_bursts
        """
        Changing frame full width and size to fixed values (normally read from sysfs)
                frame_full_width =  num_pages_in_line * align_to_bursts
        
        """
        
        frame_full_width =  0x200 # Made it fixed width
        
        
        
        num8rows=   (window_top + window_height) // 8
        if (window_top + window_height) % 8:
            num8rows += 1
        """    
        frame_start_address_inc = num8rows * frame_full_width
        """
        frame_start_address_inc = 0x80000 #Fixed size
        
        """ TODO: Calculate tiles and move to initial print """
        num_macro_cols_m1 = (window_width >> 4) - 1
        num_macro_rows_m1 = (window_height >> 4) - 1

#       frame_start_address, # calculate through num_sensor, num frames, frame size and start addr?
#        rame_start_address - 22-bit frame start address ((3 CA LSBs==0. BA==0)
        frame_start_address = (last_buf_frame + 1) * frame_start_address_inc * num_sensor
#       histogram_start_phys_page - system memory 4K page number to start histogram

        histogram_start_phys_page = self.get_histogram_byte_start() // 4096
        
        if verbose >0 :
            print ("setup_sensor_channel:")
            print ("num_sensor =                ", num_sensor)
            print ("frame_full_width =          ", frame_full_width)
            print ("window_width =              ", window_width)
            print ("window_height =             ", window_height)
            print ("window_left =               ", window_left)
            print ("window_top =                ", window_top)
            print ("frame_start_address =       0x%x"%(frame_start_address))
            print ("frame_start_address_inc =   0x%x"%(frame_start_address_inc))
            print ("histogram_start_phys_page = 0x%x"%(histogram_start_phys_page))
            print ("histogram start address =   0x%x"%(histogram_start_phys_page * 4096))
            print ("width_in_bursts =           %d(0x%x)"%(width_in_bursts,width_in_bursts))
            print ("num_burst_in_line =         %d(0x%x)"%(num_burst_in_line,num_burst_in_line))
            print ("num_pages_in_line =         %d(0x%x)"%(num_pages_in_line,num_pages_in_line))
            print ("num8rows =                  %d(0x%x)"%(num8rows,num8rows))
            print ("last_buf_frame =            ", last_buf_frame)
            print ("num_macro_cols_m1 =         ", num_macro_cols_m1)
            print ("num_macro_rows_m1 =         ", num_macro_rows_m1)
            print ("verbose =                   ", verbose)
        if exit_step == 10: return False
            
        self.x393Sensor.program_status_sensor_i2c(
            num_sensor = num_sensor,  # input [1:0] num_sensor;
            mode =       3,           # input [1:0] mode;
            seq_num =    0);          # input [5:0] seq_num;
        self.x393Sensor.program_status_sensor_io(
            num_sensor = num_sensor,  # input [1:0] num_sensor;
            mode =       3,           # input [1:0] mode;
            seq_num =    0);          # input [5:0] seq_num;

        self.x393Cmprs.program_status_compressor(
            cmprs_chn =  num_sensor,  # input [1:0] num_sensor;
            mode =       3,           # input [1:0] mode;
            seq_num =    0);          # input [5:0] seq_num;
        if exit_step == 11: return False

    # moved before camsync to have a valid timestamo w/o special waiting            
        if verbose >0 :
            print ("===================== MEMORY_SENSOR =========================")
            
        self.x393Sensor.setup_sensor_memory (
            num_sensor =       num_sensor,              # input  [1:0] num_sensor;
            frame_sa =         frame_start_address,     # input [31:0] frame_sa;         # 22-bit frame start address ((3 CA LSBs==0. BA==0)
            frame_sa_inc =     frame_start_address_inc, # input [31:0] frame_sa_inc;     # 22-bit frame start address increment  ((3 CA LSBs==0. BA==0)
            last_frame_num =   last_buf_frame,          # input [31:0] last_frame_num;   # 16-bit number of the last frame in a buffer
            frame_full_width = frame_full_width,        # input [31:0] frame_full_width; # 13-bit Padded line length (8-row increment), in 8-bursts (16 bytes)
#            window_width =     window_width >> 4,        # input [31:0] window_width;     # 13 bit - in 8*16=128 bit bursts
            window_width =     num_burst_in_line,       # input [31:0] window_width;     # 13 bit - in 8*16=128 bit bursts
            window_height =    window_height,           # input [31:0] window_height;    # 16 bit
            window_left =      window_left >> 4,        # input [31:0] window_left;
            window_top =       window_top);             # input [31:0] window_top;
    # Enable arbitration of sensor-to-memory controller
        if exit_step == 12: return False

        self.x393_axi_tasks.enable_memcntrl_en_dis(8 + num_sensor, True);
        if exit_step == 13: return False

        self.x393Cmprs.compressor_control(chn =  num_sensor,
                                          run_mode = 0) # reset compressor
        #TODO: Calculate from the image size?
        self.x393Cmprs.setup_compressor_channel (
                                  chn =               num_sensor,
                                  qbank =             0,
                                  dc_sub =            True,
                                  cmode =             vrlg.CMPRS_CBIT_CMODE_JPEG18,
                                  multi_frame =       True,
                                  bayer       =       0,
                                  focus_mode  =       0,
                                  num_macro_cols_m1 = num_macro_cols_m1,
                                  num_macro_rows_m1 = num_macro_rows_m1,
                                  left_margin =       compressor_left_margin,
                                  colorsat_blue =     colorsat_blue,
                                  colorsat_red =      colorsat_red,
                                  coring =            0,
                                  verbose =           verbose)
    # TODO: calculate widths correctly!
        if exit_step == 14: return False
        tile_margin = 2 # 18x18 instead of 16x16
        left_tiles32 = window_left // 32
#        last_tile32 = (window_left + (window_width & ~0xf) + tile_margin - 1) // 32
        last_tile32 = (window_left + ((num_macro_cols_m1 + 1) * 16) + tile_margin - 1) // 32
        width32 = last_tile32 - left_tiles32 + 1 # number of 32-wide tiles needed in each row
        
        if (verbose > 0) :
            print ("setup_compressor_memory:")
            print ("num_sensor =       ", num_sensor)
            print ("frame_sa =         0x%x"%(frame_start_address))
            print ("frame_sa_inc =     0x%x"%(frame_start_address_inc))
            print ("last_frame_num =   0x%x"%(last_buf_frame))
            print ("frame_full_width = 0x%x"%(frame_full_width))
            print ("window_width =     0x%x"%(width32 * 2 )) # window_width >> 4)) # width in 16 - bursts, made evem
            print ("window_height =    0x%x"%(window_height & 0xfffffff0))
            print ("window_left =      0x%x"%(left_tiles32 * 2)) # window_left >> 4)) # left in 16-byte bursts, made even
            print ("window_top =       0x%x"%(window_top))
            print ("byte32 =           1")
            print ("tile_width =       2")
            print ("tile_vstep =      16")
            print ("tile_height =     18")
            print ("extra_pages =      1")
            print ("disable_need =     1")
            print ("abort_late =       0")

        self.x393Cmprs.setup_compressor_memory (
            num_sensor =       num_sensor,
            frame_sa =         frame_start_address,         # input [31:0] frame_sa;         # 22-bit frame start address ((3 CA LSBs==0. BA==0)
            frame_sa_inc =     frame_start_address_inc,     # input [31:0] frame_sa_inc;     # 22-bit frame start address increment  ((3 CA LSBs==0. BA==0)
            last_frame_num =   last_buf_frame,              # input [31:0] last_frame_num;   # 16-bit number of the last frame in a buffer
            frame_full_width = frame_full_width,            # input [31:0] frame_full_width; # 13-bit Padded line length (8-row increment), in 8-bursts (16 bytes)
            window_width =     (width32 * 2 ),              # input [31:0] window_width;     # 13 bit - in 8*16=128 bit bursts
            window_height =    window_height & 0xfffffff0,  # input [31:0] window_height;    # 16 bit
            window_left =      left_tiles32 * 2,            # input [31:0] window_left;
            window_top =       window_top,                  # input [31:0] window_top;
            byte32 =           1,
            tile_width =       2,
            tile_vstep =      16,
            tile_height =     18,
            extra_pages =      1,
            disable_need =     1,
            abort_late =       False)

        if exit_step == 15: return False
    
        self.x393Cmprs.compressor_control(
                       chn = num_sensor,
                       run_mode =  0) #  3)  # run repetitive mode

        if exit_step == 16: return False
        #Set up delays separately, outside of this method
        """   
        if verbose >0 :
            print ("===================== DELAYS_SETUP =========================")
            
        self.x393Sensor.set_sensor_io_dly (
                           num_sensor = num_sensor,
                           mmcm_phase = 0,
                           iclk_dly =   0,
                           vact_dly =   0,
                           hact_dly =   0,
                           pxd_dly =    0)
        self.x393Sensor.set_sensor_io_ctl (
                           quadrants =  vrlg.QUADRANTS_PXD_HACT_VACT)
                           
        """    
        if verbose >0 :
            print ("===================== IO_SETUP =========================")
        self.x393Sensor.set_sensor_io_width(
            num_sensor = num_sensor, # input    [1:0] num_sensor;
            width =      0) # Or use 0 for sensor-generated HACT input   [15:0] width; # 0 - use HACT, >0 - generate HACT from start to specified width
        self.x393Sensor.set_sensor_io_ctl (
                           num_sensor = num_sensor,
                           mrst =       False,
                           arst =       False,
                           aro  =       False,
                           mmcm_rst =   True,   #reset mmcm 
                           clk_sel =    None,   #Dealing with Unisims bug: "Error: [Unisim MMCME2_ADV-4] Input clock can only be switched when..."
                           set_delays = False,
                           quadrants =  None)

        self.x393Sensor.set_sensor_io_ctl (
                           num_sensor = num_sensor,
                           mrst =       False,
                           arst =       False,
                           aro  =       False,
                           mmcm_rst =   True,   #reset mmcm 
                           clk_sel =    clk_sel,
                           set_delays = False,
                           quadrants =  None)

        self.x393Sensor.set_sensor_io_ctl (
                           num_sensor = num_sensor,
                           mmcm_rst =   False, # release MMCM reset (maybe wait longer?
                           clk_sel =    clk_sel,
                           set_delays = False,
                           quadrants =  None)

        if exit_step == 17: return False

        """
        if verbose >0 :
            print ("===================== I2C_TEST =========================")
        self.x393Sensor.test_i2c_353() # test soft/sequencer i2c
        """
        if verbose >0 :
            print ("===================== LENS_FLAT_SETUP ========================= num_sensor=",num_sensor)
        self.x393Sensor.set_sensor_lens_flat_heights (
                                      num_sensor = num_sensor,
                                      height0_m1 = 0xffff,
                                      height1_m1 = None,
                                      height2_m1 = None)
        self.x393Sensor.set_sensor_lens_flat_parameters (
                                         num_sensor = num_sensor,
                                         num_sub_sensor = 0,
                                         AX = 0, # 0x20000,
                                         AY = 0, # 0x20000
                                         BX = 0, # 0x180000
                                         BY = 0, # 0x180000
                                         C =  0x8000,
                                         scales0 =        0x8000,
                                         scales1 =        0x8000,
                                         scales2 =        0x8000,
                                         scales3 =        0x8000,
                                         fatzero_in =     0,
                                         fatzero_out =    0,
                                         post_scale =     1)
        if verbose >0 :
            print ("===================== GAMMA_SETUP =========================")

        self.x393Sensor.set_sensor_gamma_heights ( 
                                  num_sensor = num_sensor,
                                  height0_m1 = 0xffff,
                                  height1_m1 = 0,
                                  height2_m1 = 0)
           
        # Configure histograms
        if verbose >0 :
            print ("===================== HISTOGRAMS_SETUP =========================")
        self.x393Sensor.set_sensor_histogram_window ( # 353 did it using command sequencer)
                                    num_sensor =     num_sensor,
                                    subchannel =     0,
                                    left =           histogram_left,
                                    top =            histogram_top,
                                    width_m1 =       histogram_width_m1,
                                    height_m1 =      histogram_height_m1)

        self.x393Sensor.set_sensor_histogram_saxi_addr (
                                    num_sensor = num_sensor,
                                    subchannel = 0,
                                    page = histogram_start_phys_page) # for the channel/subchannel = 0/0
            
        self.x393Sensor.set_sensor_histogram_saxi (
                                   en = True,
                                   nrst = True,
                                   confirm_write = False, # True,
                                   cache_mode = 3)

        if exit_step == 18: return False

        # Run after histogram channel is set up?
        if verbose >0 :
            print ("===================== SENSOR_SETUP =========================")
            
        self.x393Sensor.set_sensor_mode (
            num_sensor = num_sensor,
            hist_en =    1, # bitmask, only first subchannel
            hist_nrst =  1, # bitmask, only first subchannel 
            chn_en =     True, 
            bits16 =     False)

        if verbose >0 :
            print ("===================== CMPRS_EN_ARBIT =========================")
    # just temporarily - enable channel immediately
        self.x393_axi_tasks.enable_memcntrl_en_dis(12 + num_sensor, True);

        if exit_step == 19: return False

        if verbose >0 :
            print ("===================== GAMMA_CTL =========================")
        self.x393Sensor.set_sensor_gamma_ctl (# doing last to enable sensor data when everything else is set up
            num_sensor = num_sensor, # input   [1:0] num_sensor; # sensor channel number (0..3)
            bayer =      0,
            table_page = 0,
            en_input =   True,
            repet_mode = True, #  Normal mode, single trigger - just for debugging  TODO: re-assign?
            trig = False)
        return True

    def specify_window (self,
                        window_width =              None, # 2592
                        window_height =             None, # 1944
                        window_left =               None,     # 0
                        window_top =                None, # 0? 1?
                        cmode =                     None,
                        bayer =                     None,
                        y_quality =                 None,
                        c_quality =                 None, # use "same" to save None
                        portrait =                  None,
                        gamma =                     None,
                        black =                     None, # 0.04 
                        colorsat_blue =             None, # colorsat_blue, #0x120     # 0x90 for 1x
                        colorsat_red =              None, # colorsat_red, #0x16c,     # 0xb6 for x1
                        verbose =                   1
                        ):
    
        global GLBL_WINDOW
        if GLBL_WINDOW is None:
            GLBL_WINDOW = {}
        sensorType = self.x393Sensor.getSensorInterfaceType()
        if verbose > 0 :
            print ("Sensor interface type: %s"%(sensorType))
        if window_width is None:
            try:
                window_width = GLBL_WINDOW["width"]
            except:
                window_width = SENSOR_DEFAULTS[sensorType]["width"]
        if window_height is None:
            try:
                window_height = GLBL_WINDOW["height"]
            except:
                window_height = SENSOR_DEFAULTS[sensorType]["height"]
        if window_left is None:
            try:
                window_left = GLBL_WINDOW["left"]
            except:
                window_left = SENSOR_DEFAULTS[sensorType]["left"]
        if window_top is None:
            try:
                window_top = GLBL_WINDOW["top"]
            except:
                window_top = SENSOR_DEFAULTS[sensorType]["top"]
        if cmode is None:
            try:
                cmode = GLBL_WINDOW["cmode"]
            except:
                cmode = 0

        if bayer is None:
            try:
                bayer = GLBL_WINDOW["bayer"]
            except:
                bayer = SENSOR_DEFAULTS[sensorType]["bayer"]

        if y_quality is None:
            try:
                y_quality = GLBL_WINDOW["y_quality"]
            except:
                y_quality = 100

        if c_quality is None:
            try:
                c_quality = GLBL_WINDOW["c_quality"]
            except:
                c_quality = "same"
        if c_quality == "same": # to save as None, not to not save
                c_quality = None 
                
        if portrait is None:
            try:
                portrait = GLBL_WINDOW["portrait"]
            except:
                portrait = False
                
        if gamma is None:
            try:
                gamma = GLBL_WINDOW["gamma"]
            except:
                gamma = 0.57

        if black is None:
            try:
                black = GLBL_WINDOW["black"]
            except:
                black = 0.04

        if colorsat_blue is None:
            try:
                colorsat_blue = GLBL_WINDOW["colorsat_blue"]
            except:
                colorsat_blue = 2.0 # *0x90

        if colorsat_red is None:
            try:
                colorsat_red = GLBL_WINDOW["colorsat_red"]
            except:
                colorsat_red = 2.0 #  *0xb6
                
        GLBL_WINDOW = {"width":         window_width,
                       "height":        window_height,
                       "left":          window_left,
                       "top":           window_top,
                       "cmode":         cmode,
                       "bayer":         bayer,
                       "y_quality":     y_quality,
                       "c_quality":     c_quality,
                       "portrait":      portrait,
                       "gamma":         gamma,
                       "black":         black,
                       "colorsat_blue": colorsat_blue,
                       "colorsat_red":  colorsat_red,
                       }
        if verbose > 1:
            print("GLBL_WINDOW:")
            for k in GLBL_WINDOW.keys():
                print ("%15s:%s"%(k,str(GLBL_WINDOW[k])))
        return GLBL_WINDOW
        
                
    def specify_phys_memory(self,
                            circbuf_chn_size= 0x4000000,
                            verbose =         1):
        """
        @param circbuf_chn_size - circular buffer size for each channel, in bytes
        """
        global GLBL_CIRCBUF_CHN_SIZE, GLBL_CIRCBUF_STARTS, GLBL_CIRCBUF_ENDS, GLBL_CIRCBUF_END, GLBL_MEMBRIDGE_START, GLBL_MEMBRIDGE_END, GLBL_BUFFER_END
        global GLBL_MEMBRIDGE_H2D_START, GLBL_MEMBRIDGE_H2D_END, GLBL_MEMBRIDGE_D2H_START, GLBL_MEMBRIDGE_D2H_END
        global BUFFER_ADDRESS_H2D, BUFFER_LEN_H2D, BUFFER_ADDRESS_D2H, BUFFER_LEN_D2H
        
        circbuf_start =   self.get_circbuf_byte_start()
        GLBL_BUFFER_END=  self.get_circbuf_byte_end()
        GLBL_CIRCBUF_CHN_SIZE = circbuf_chn_size
        GLBL_CIRCBUF_STARTS=[]
        GLBL_CIRCBUF_ENDS=[]
        for i in range(16):
            GLBL_CIRCBUF_STARTS.append(circbuf_start + i*circbuf_chn_size)
            GLBL_CIRCBUF_ENDS.append(circbuf_start + (i+1)*circbuf_chn_size)
        GLBL_CIRCBUF_END =     circbuf_start + 4*GLBL_CIRCBUF_CHN_SIZE
        GLBL_MEMBRIDGE_START = GLBL_CIRCBUF_END
        GLBL_MEMBRIDGE_END =   GLBL_BUFFER_END

        GLBL_MEMBRIDGE_H2D_START = BUFFER_ADDRESS_H2D
        GLBL_MEMBRIDGE_H2D_END =   BUFFER_ADDRESS_H2D + BUFFER_LEN_H2D

        GLBL_MEMBRIDGE_D2H_START = BUFFER_ADDRESS_D2H
        GLBL_MEMBRIDGE_D2H_END =   BUFFER_ADDRESS_D2H + BUFFER_LEN_D2H
        
        if verbose >0 :
            print ("compressor system memory buffers:")
            print ("circbuf start 0 =           0x%x"%(GLBL_CIRCBUF_STARTS[0]))
            print ("circbuf start 1 =           0x%x"%(GLBL_CIRCBUF_STARTS[1]))
            print ("circbuf start 2 =           0x%x"%(GLBL_CIRCBUF_STARTS[2]))
            print ("circbuf start 3 =           0x%x"%(GLBL_CIRCBUF_STARTS[3]))
            print ("circbuf end =               0x%x"%(GLBL_BUFFER_END))
            print ("membridge start =           0x%x"%(GLBL_MEMBRIDGE_START))
            print ("membridge end =             0x%x"%(GLBL_MEMBRIDGE_END))
            print ("membridge size =            %d bytes"%(GLBL_MEMBRIDGE_END - GLBL_MEMBRIDGE_START))
            print ("membridge h2d_start =       0x%x"%(GLBL_MEMBRIDGE_H2D_START))
            print ("membridge h2d end =         0x%x"%(GLBL_MEMBRIDGE_H2D_END))
            print ("membridge h2d size =        %d bytes"%(GLBL_MEMBRIDGE_H2D_END - GLBL_MEMBRIDGE_H2D_START))
            print ("membridge h2d start =       0x%x"%(GLBL_MEMBRIDGE_D2H_START))
            print ("membridge h2d end =         0x%x"%(GLBL_MEMBRIDGE_D2H_END))
            print ("membridge h2d size =        %d bytes"%(GLBL_MEMBRIDGE_D2H_END - GLBL_MEMBRIDGE_D2H_START))
            print ("memory buffer end =         0x%x"%(GLBL_BUFFER_END))
    def setup_cmdmux (self):
        #Will report frame number for each channel
        """
        Configure status report for command sequencer to report 4 LSB of each channel frame number
        with get_frame_numbers()
        """    
        self.x393_axi_tasks.program_status( # also takes snapshot
                                           base_addr =    vrlg.CMDSEQMUX_ADDR,
                                           reg_addr =     0,
                                           mode =         3,     # input [1:0] mode;
                                           seq_number =   0)     #input [5:0] seq_num;
    def get_frame_numbers(self):
        """
        @return list of 4-bit frame numbers, per channel
        """
        status =   self.x393_axi_tasks.read_status(address = vrlg.CMDSEQMUX_STATUS)
        frames = []
        for i in range(4):
            frames.append (int((status >> (4*i)) & 0xf))
        return frames
    def get_frame_number(self,
                         channel=0):
        """
        @return frame number of the sequencer for the specified channel (4 bits)
        """
        status =   self.x393_axi_tasks.read_status(address = vrlg.CMDSEQMUX_STATUS)
        return int((status >> (4*channel)) & 0xf)
    
    def get_frame_number_i2c(self,
                             channel=0):
        """
        @return frame number of the i2c sequencer for the specified channel
        """
        try:
            if (channel == all) or (channel[0].upper() == "A"): #all is a built-in function
                frames=[]
                for channel in range(4):
                    frames.append(self.get_frame_number_i2c(channel = channel))
                return frames    
        except:
            pass                    
        status = self.x393_axi_tasks.read_status(
                    address = vrlg.SENSI2C_STATUS_REG_BASE + channel * vrlg.SENSI2C_STATUS_REG_INC + vrlg.SENSI2C_STATUS_REG_REL)
        return int((status >> 12) & 0xf)
        
    def skip_frame(self,
                   channel_mask,
                   loop_delay = 0.01,
                   timeout = 2.0):
        old_frames = self.get_frame_numbers()
        timeout_time = time.time() + timeout
        frameno = -1
        while time.time() < timeout_time :
            new_frames = self.get_frame_numbers()
            all_new=True
            for chn in range(4):
                if ((channel_mask >> chn) & 1):
                    if (old_frames[chn] == new_frames[chn]):
                        all_new = False
                        break
                    else:
                        frameno = new_frames[chn]
            if all_new:
                break;
        return frameno # Frame number of the last  new frame checked         

    def wait_frame(self,
                   channel = 0,
                   frame =      0,
                   loop_delay = 0.01,
                   timeout = 2.0):
        timeout_time = time.time() + timeout
        frameno = -1
        while time.time() < timeout_time :
            frameno = self.get_frame_number(channel)
            if frameno == (frame & 15):
                return frameno
        return frameno # Frame number of the last  new frame checked         

    def skip_frame_i2c(self,
                   channel_mask,
                   loop_delay = 0.01,
                   timeout = 2.0):
        old_frames = self.get_frame_number_i2c("all")
        timeout_time = time.time() + timeout
        frameno = -1
        while time.time() < timeout_time :
            new_frames = self.get_frame_number_i2c("all")
            all_new=True
            for chn in range(4):
                if ((channel_mask >> chn) & 1):
                    if (old_frames[chn] == new_frames[chn]):
                        all_new = False
                        break
                    else:
                        frameno = new_frames[chn]
            if all_new:
                break;
        return frameno # Frame number of the last  new frame checked         
             
    def setup_compressor(self,
                          chn,
                          cmode =            vrlg.CMPRS_CBIT_CMODE_JPEG18,
                          bayer =            0,
                          qbank =            0,
                          dc_sub =           1,
                          multi_frame =      1,
                          focus_mode =       0,
                          coring =           0,
                          window_width =     None, # 2592,   # 2592
                          window_height =    None, # 1944,   # 1944
                          window_left =      None, # 0,     # 0
                          window_top =       None, # 0, # 0? 1?
                          last_buf_frame =   1,  #  - just 2-frame buffer
                          colorsat_blue =    0x120,     # 0x90 for 1x
                          colorsat_red =     0x16c,     # 0xb6 for x1
                          verbose =          1):
        """
        @param chn -         compressor channel (0..3)
        @param cmode -       color mode:
                                CMPRS_CBIT_CMODE_JPEG18 =          0 - color 4:2:0
                                CMPRS_CBIT_CMODE_MONO6 =           1 - mono 4:2:0 (6 blocks)
                                CMPRS_CBIT_CMODE_JP46 =            2 - jp4, 6 blocks, original
                                CMPRS_CBIT_CMODE_JP46DC =          3 - jp4, 6 blocks, dc -improved
                                CMPRS_CBIT_CMODE_JPEG20 =          4 - mono, 4 blocks (but still not actual monochrome JPEG as the blocks are scanned in 2x2 macroblocks)
                                CMPRS_CBIT_CMODE_JP4 =             5 - jp4,  4 blocks, dc-improved
                                CMPRS_CBIT_CMODE_JP4DC =           6 - jp4,  4 blocks, dc-improved
                                CMPRS_CBIT_CMODE_JP4DIFF =         7 - jp4,  4 blocks, differential
                                CMPRS_CBIT_CMODE_JP4DIFFHDR =      8 - jp4,  4 blocks, differential, hdr
                                CMPRS_CBIT_CMODE_JP4DIFFDIV2 =     9 - jp4,  4 blocks, differential, divide by 2
                                CMPRS_CBIT_CMODE_JP4DIFFHDRDIV2 = 10 - jp4,  4 blocks, differential, hdr,divide by 2
                                CMPRS_CBIT_CMODE_MONO1 =          11 -  mono JPEG (not yet implemented)
                                CMPRS_CBIT_CMODE_MONO4 =          14 -  mono 4 blocks
        @param qbank -       quantization table page (0..15)
        @param dc_sub -      True - subtract DC before running DCT, False - no subtraction, convert as is,
        @param multi_frame -  False - single-frame buffer, True - multi-frame video memory buffer,
        @param bayer -        Bayer shift (0..3)
        @param focus_mode -   focus mode - how to combine image with "focus quality" in the result image 
        @param coring - coring value
        @param window_width -      (here - in pixels)
        @param window_height -     16-bit window height in scan lines
        @param window_left -       left margin of the window (here - in pixels)
        @param window_top -        top margin of the window (16 bit)
        @param last_buf_frame) -   16-bit number of the last frame in a buffer
        @param colorsat_blue - color saturation for blue (10 bits), 0x90 for 100%
        @param colorsat_red -  color saturation for red (10 bits), 0xb6 for 100%
        @param verbose - verbose level
        """
        try:
            if (chn == all) or (chn[0].upper() == "A"): #all is a built-in function
                for chn in range(4):
                    self. setup_compressor( #self,
                                           chn =            chn,
                                           cmode =          cmode,
                                           qbank =          qbank,
                                           dc_sub =         dc_sub,
                                           multi_frame =    multi_frame,
                                           bayer =          bayer,
                                           focus_mode =     focus_mode,
                                           coring =         coring,
                                           window_width =   None, # 2592,   # 2592
                                           window_height =  None, # 1944,   # 1944
                                           window_left =    None, # 0,     # 0
                                           window_top =     None, # 0, # 0? 1?
                                           last_buf_frame = last_buf_frame,  #  - just 2-frame buffer
                                           colorsat_blue =  colorsat_blue, #0x120     # 0x90 for 1x
                                           colorsat_red =   colorsat_red, #0x16c,     # 0xb6 for x1
                                           verbose =        verbose)
                return
        except:
            pass
        window = self.specify_window (window_width =  window_width,
                                      window_height = window_height,
                                      window_left =   window_left,
                                      window_top =    window_top,
                                      cmode =         cmode, # will use 0
                                      verbose =       0)
        window_width =   window["width"]
        window_height =  window["height"]
        window_left =    window["left"]
        window_top =     window["top"]
        cmode =          window["cmode"]
        num_sensor = chn # 1:1 sensor - compressor
        
        align_to_bursts = 64 # align full width to multiple of align_to_bursts. 64 is the size of memory access
        width_in_bursts = window_width >> 4
        if (window_width & 0xf):
            width_in_bursts += 1
        compressor_left_margin = window_left % 32
    
        num_burst_in_line = (window_left >> 4) + width_in_bursts
        num_pages_in_line = num_burst_in_line // align_to_bursts;
        if num_burst_in_line % align_to_bursts:
            num_pages_in_line += 1
        """
        Changing frame full width and size to fixed values (normally read from sysfs)
                frame_full_width =  num_pages_in_line * align_to_bursts
        
        """
        
        frame_full_width =  0x200 # Made it fixed width
        num8rows=   (window_top + window_height) // 8
        if (window_top + window_height) % 8:
            num8rows += 1
        """    
        frame_start_address_inc = num8rows * frame_full_width
        """
        frame_start_address_inc = 0x80000 #Fixed size

        num_macro_cols_m1 = (window_width >> 4) - 1
        num_macro_rows_m1 = (window_height >> 4) - 1
        frame_start_address = (last_buf_frame + 1) * frame_start_address_inc * num_sensor
        
        self.x393Cmprs.setup_compressor_channel (
                                  chn =               chn,
                                  qbank =             qbank,
                                  dc_sub =            dc_sub,
                                  cmode =             cmode, # vrlg.CMPRS_CBIT_CMODE_JPEG18,
                                  multi_frame =       True,
                                  bayer       =       bayer,
                                  focus_mode  =       focus_mode,
                                  num_macro_cols_m1 = num_macro_cols_m1,
                                  num_macro_rows_m1 = num_macro_rows_m1,
                                  left_margin =       compressor_left_margin,
                                  colorsat_blue =     colorsat_blue,
                                  colorsat_red =      colorsat_red,
                                  coring =            0,
                                  verbose =           verbose)
    # TODO: calculate widths correctly!
        if cmode == vrlg.CMPRS_CBIT_CMODE_JPEG18:
            tile_margin = 2 # 18x18 instead of 16x16
            tile_width =  2
            extra_pages = 1
            
        else: # actually other modes should be parsed here, now considering just JP4 flavors
            tile_margin = 0 # 18x18 instead of 16x16
            tile_width =  4
#            extra_pages = (0,1)[(compressor_left_margin % 16) != 0] # memory access block border does not cut macroblocks
            extra_pages = 1 # just testing, 0 should be OK  here
        tile_vstep = 16
        tile_height = tile_vstep + tile_margin

        left_tiles32 = window_left // 32
        last_tile32 = (window_left + ((num_macro_cols_m1 + 1) * 16) + tile_margin - 1) // 32
        width32 = last_tile32 - left_tiles32 + 1 # number of 32-wide tiles needed in each row
        
        if (verbose > 0) :
            print ("setup_compressor_memory:")
            print ("num_sensor =       ", num_sensor)
            print ("frame_sa =         0x%x"%(frame_start_address))
            print ("frame_sa_inc =     0x%x"%(frame_start_address_inc))
            print ("last_frame_num =   0x%x"%(last_buf_frame))
            print ("frame_full_width = 0x%x"%(frame_full_width))
            print ("window_width =     0x%x (in 16 - bursts, made even)"%(width32 * 2 )) # window_width >> 4)) # width in 16 - bursts, made even
            print ("window_height =    0x%x"%(window_height & 0xfffffff0))
            print ("window_left =      0x%x"%(left_tiles32 * 2)) # window_left >> 4)) # left in 16-byte bursts, made even
            print ("window_top =       0x%x"%(window_top))
            print ("byte32 =           1")
            print ("tile_width =       0x%x"%(tile_width))
            print ("tile_vstep =       0x%x"%(tile_vstep))
            print ("tile_height =      0x%x"%(tile_height))
            print ("extra_pages =      0x%x"%(extra_pages))
            print ("disable_need =     1")
            print ("abort_late =       0")

        self.x393Cmprs.setup_compressor_memory (
            num_sensor =       num_sensor,
            frame_sa =         frame_start_address,         # input [31:0] frame_sa;         # 22-bit frame start address ((3 CA LSBs==0. BA==0)
            frame_sa_inc =     frame_start_address_inc,     # input [31:0] frame_sa_inc;     # 22-bit frame start address increment  ((3 CA LSBs==0. BA==0)
            last_frame_num =   last_buf_frame,              # input [31:0] last_frame_num;   # 16-bit number of the last frame in a buffer
            frame_full_width = frame_full_width,            # input [31:0] frame_full_width; # 13-bit Padded line length (8-row increment), in 8-bursts (16 bytes)
            window_width =     (width32 * 2 ),              # input [31:0] window_width;     # 13 bit - in 8*16=128 bit bursts
            window_height =    window_height & 0xfffffff0,  # input [31:0] window_height;    # 16 bit
            window_left =      left_tiles32 * 2,            # input [31:0] window_left;
            window_top =       window_top,                  # input [31:0] window_top;
            byte32 =           1,
            tile_width =       tile_width,
            tile_vstep =       tile_vstep,
            tile_height =      tile_height,
            extra_pages =      extra_pages,
            disable_need =     1,
            abort_late =       False)

    def reset_channels(self,
                       sensor_mask = 0x1,
                       reset_mask =  0xf):
        """
        Reset channels before re-programming
        @param sensor_mask -       bitmap of the selected channels (1 - only channel 0, 0xf - all channels)
        @param reset_mask -        +1 - reset sensor(s) (MRST and internal),
                                   +2 - reset compressor(s)
                                   +4 - reset sensor-to-memory modules
                                   +8 - reset memory-to-compressor modules
        """
        MASK_SENSOR =        1
        MASK_COMPRESSOR =    2
        MASK_MEMSENSOR =     4
        MASK_MEMCOMPRESSOR = 8
        
        for chn in range (4):
            if sensor_mask & (1 << chn):
                if reset_mask & MASK_COMPRESSOR:
                    self.x393Cmprs.compressor_control        (chn =      chn,
                                                              run_mode = 1) # stop after frame done
                    
                if reset_mask & MASK_MEMSENSOR:
                    self.x393Sensor.control_sensor_memory    (num_sensor = chn,
                                                              command = 'stop')
                      
                if reset_mask & MASK_MEMCOMPRESSOR:
                    self.x393Cmprs.control_compressor_memory (num_sensor = chn,
                                                              command = 'stop')
                    
        self.sleep_ms(200)            
        for chn in range (4):
            if sensor_mask & (1 << chn):
                if reset_mask & MASK_COMPRESSOR:
                    self.x393Cmprs.compressor_control        (chn =      chn,
                                                              run_mode = 0)  # reset, 'kill -9'
                if reset_mask & MASK_MEMSENSOR:
                    self.x393Sensor.control_sensor_memory    (num_sensor = chn,
                                                              command = 'reset')
                      
                if reset_mask & MASK_MEMCOMPRESSOR:
                    self.x393Cmprs.control_compressor_memory (num_sensor = chn,
                                                              command = 'reset')

                if reset_mask & MASK_SENSOR:
                    self.x393Sensor.set_sensor_io_ctl        (num_sensor =  chn,
                                                              mrst =        True)

        
    def setup_all_sensors (self,
                              setup_membridge =           False,
                              exit_step =                 None,
                              sensor_mask =               0x1, # channel 0 only
                              gamma_load =                False,
                              window_width =              None, # 2592,   # 2592
                              window_height =             None, # 1944,   # 1944
                              window_left =               None, # 0,     # 0
                              window_top =                None, # 0, # 0? 1?
                              compressor_left_margin =    0, #0?`1? 
                              last_buf_frame =            1,  #  - just 2-frame buffer
                              colorsat_blue =             0x120,     # 0x90 fo 1x
                              colorsat_red =              0x16c,     # 0xb6 for x1
                              clk_sel =                   1,         # 1
                              histogram_left =            None,
                              histogram_top =             None,
                              histogram_width_m1 =        None, # 2559, #0,
                              histogram_height_m1 =       None, # 799, #0,
                              circbuf_chn_size=           0x4000000, # 64 Mib - all 4 channels?
                              reset_afi =                 False, # reset AFI multiplexer 
                              verbose =                   1):
        """
        Setup one sensor+compressor channel (for one sub-channel only)
        @param exit_step -         exit after executing specified step:
                                1 - after power and clock
                                2 - exit after GPIO setup
                                3 - exit after RTC setup
                                10..19 - exit from setup_sensor_channel:
                                   10 - just after printing calculated values
                                   11 - after programming status
                                   12 - after setup_sensor_memory
                                   13 - after enabling memory controller for the sensor channel
                                   14 - after setup_compressor_channel
                                   15 - after setup_compressor_memory
                                   16 - after compressor run
                                   17 - removing MRST from the sensor
                                   18 - after vignetting, gamma and histograms setup
                                   19 - enabling sensor memory controller (histograms in not yet)
                                20 - after setup_sensor_channel
                                21 - after afi_mux_setup
        @param sensor_mask -       bitmap of the selected channels (1 - only channel 0, 0xf - all channels)
        @param gamma_load -        load gamma table TODO: Change to calculate and load table
        @param window_width -      (here - in pixels)
        @param window_height -     16-bit window height in scan lines
        @param window_left -       left margin of the window (here - in pixels)
        @param window_top -        top margin of the window (16 bit)
        @param compressor_left_margin - 0..31 - left margin for compressor (to the nearest 32-byte column)
        @param last_buf_frame) -   16-bit number of the last frame in a buffer
        @param colorsat_blue - color saturation for blue (10 bits), 0x90 for 100%
        @param colorsat_red -  color saturation for red (10 bits), 0xb6 for 100%
        @param clk_sel - True - use pixel clock from the sensor, False - use internal clock (provided to the sensor), None - no change
        @param histogram_left -      histogram window left margin
        @param histogram_top -       histogram window top margin
        @param histogram_width_m1 -  one less than window width. If 0 - use frame right margin (end of HACT)
        @param histogram_height_m1 - one less than window height. If 0 - use frame bottom margin (end of VACT)
        @param reset_afi            Reset AFI multiplexer when initializing 

        @param circbuf_chn_size - circular buffer size for each channel, in bytes
        @param verbose - verbose level
        @return True if all done, False if exited prematurely by  exit_step
        """
        global GLBL_CIRCBUF_CHN_SIZE, GLBL_CIRCBUF_STARTS, GLBL_CIRCBUF_ENDS, GLBL_CIRCBUF_END, GLBL_MEMBRIDGE_START, GLBL_MEMBRIDGE_END, GLBL_BUFFER_END, GLBL_WINDOW
        global GLBL_MEMBRIDGE_H2D_START, GLBL_MEMBRIDGE_H2D_END, GLBL_MEMBRIDGE_D2H_START, GLBL_MEMBRIDGE_D2H_END

        sensorType = self.x393Sensor.getSensorInterfaceType()
        if verbose > 0 :
            print ("Sensor interface type: %s"%(sensorType))
        window = self.specify_window (window_width =  window_width,
                                      window_height = window_height,
                                      window_left =   window_left,
                                      window_top =    window_top,
                                      cmode =         None, # will use 0
                                      verbose =       0)
        window_width =   window["width"]
        window_height =  window["height"]
        window_left =    window["left"]
        window_top =     window["top"]
        """
        if window_width is None:
            window_width = SENSOR_DEFAULTS[sensorType]["width"]
        if window_height is None:
            window_height = SENSOR_DEFAULTS[sensorType]["height"]
        if window_left is None:
            window_left = SENSOR_DEFAULTS[sensorType]["left"]
        if window_top is None:
            window_top = SENSOR_DEFAULTS[sensorType]["top"]
        """    
        #setting up histogram window, same for parallel, similar for serial
                    
        if histogram_left is None:
            histogram_left = 0
        if histogram_top is None:
            histogram_top = 0
        if histogram_width_m1 is None:
            histogram_width_m1 = window_width - 33
        if histogram_height_m1 is None:
            histogram_height_m1 = window_height - 1145

        self.specify_phys_memory(circbuf_chn_size = circbuf_chn_size)
        """
        self.specify_window (window_width =  window_width,
                             window_height = window_height,
                             window_left =   window_left,
                             window_top =    window_top,
                             cmode =         None, # will use 0
                             verbose =       0)
        """
    #TODO: calculate addresses/lengths
        """
        AFI mux is programmed in 32-byte chunks
        """
        afi_cmprs0_sa = GLBL_CIRCBUF_STARTS[0] // 32  
        afi_cmprs1_sa = GLBL_CIRCBUF_STARTS[1] // 32
        afi_cmprs2_sa = GLBL_CIRCBUF_STARTS[2] // 32
        afi_cmprs3_sa = GLBL_CIRCBUF_STARTS[3] // 32
        afi_cmprs0_len = (GLBL_CIRCBUF_ENDS[0] - GLBL_CIRCBUF_STARTS[0]) // 32  
        afi_cmprs1_len = (GLBL_CIRCBUF_ENDS[1] - GLBL_CIRCBUF_STARTS[1]) // 32
        afi_cmprs2_len = (GLBL_CIRCBUF_ENDS[2] - GLBL_CIRCBUF_STARTS[2]) // 32
        afi_cmprs3_len = (GLBL_CIRCBUF_ENDS[3] - GLBL_CIRCBUF_STARTS[3]) // 32
        
#        afi_cmprs_len = GLBL_CIRCBUF_CHN_SIZE  // 32    
        if verbose >0 :
            print ("compressor system memory buffers:")
            print ("circbuf start 0 =           0x%x"%(GLBL_CIRCBUF_STARTS[0]))
            print ("circbuf start 1 =           0x%x"%(GLBL_CIRCBUF_STARTS[1]))
            print ("circbuf start 2 =           0x%x"%(GLBL_CIRCBUF_STARTS[2]))
            print ("circbuf start 3 =           0x%x"%(GLBL_CIRCBUF_STARTS[3]))
            print ("circbuf end 0 =             0x%x"%(GLBL_CIRCBUF_ENDS[0]))
            print ("circbuf end 1 =             0x%x"%(GLBL_CIRCBUF_ENDS[1]))
            print ("circbuf end 2 =             0x%x"%(GLBL_CIRCBUF_ENDS[2]))
            print ("circbuf end 3 =             0x%x"%(GLBL_CIRCBUF_ENDS[3]))
            print ("circbuf end =               0x%x"%(GLBL_BUFFER_END))
            print ("membridge start =           0x%x"%(GLBL_MEMBRIDGE_START))
            print ("membridge end =             0x%x"%(GLBL_MEMBRIDGE_END))
            print ("membridge size =            %d bytes"%(GLBL_MEMBRIDGE_END - GLBL_MEMBRIDGE_START))
            print ("membridge h2d_start =       0x%x"%(GLBL_MEMBRIDGE_H2D_START))
            print ("membridge h2d end =         0x%x"%(GLBL_MEMBRIDGE_H2D_END))
            print ("membridge h2d size =        %d bytes"%(GLBL_MEMBRIDGE_H2D_END - GLBL_MEMBRIDGE_H2D_START))
            print ("membridge h2d start =       0x%x"%(GLBL_MEMBRIDGE_D2H_START))
            print ("membridge h2d end =         0x%x"%(GLBL_MEMBRIDGE_D2H_END))
            print ("membridge h2d size =        %d bytes"%(GLBL_MEMBRIDGE_D2H_END - GLBL_MEMBRIDGE_D2H_START))
            print ("memory buffer end =         0x%x"%(GLBL_BUFFER_END))
            
        self.program_status_debug (3,0)
        if setup_membridge:
            self.setup_membridge_sensor(
                               num_sensor      = 0,         
                               write_mem       = False,
                               window_width    = window_width,
                               window_height   = window_height,
                               window_left     = window_left,
                               window_top      = window_top,
                               last_buf_frame  = last_buf_frame,
#                               membridge_start = GLBL_MEMBRIDGE_START,
#                               membridge_end   = GLBL_MEMBRIDGE_END,
#Setting up to read raw sensor data
                               membridge_start = GLBL_MEMBRIDGE_D2H_START,
                               membridge_end   = GLBL_MEMBRIDGE_D2H_END,
                               verbose         = verbose)
        self.sync_for_device('D2H', GLBL_MEMBRIDGE_D2H_START, GLBL_MEMBRIDGE_D2H_END - GLBL_MEMBRIDGE_D2H_START) # command and PRD table
            
        
#        if verbose >0 :
#            print ("===================== Sensor power setup: sensor ports 0 and 1 =========================")
#        self.setSensorPower(sub_pair=0, power_on=0)
        """        
        if sensor_mask & 3: # Need power for sens1 and sens 2
            if verbose >0 :
                print ("===================== Sensor power setup: sensor ports 0 and 1 =========================")
            self.setSensorPower(sub_pair=0, power_on=1)
        if sensor_mask & 0xc: # Need power for sens1 and sens 2
            if verbose >0 :
                print ("===================== Sensor power setup: sensor ports 2 and 3 =========================")
            self.setSensorPower(sub_pair=1, power_on=1)
        if verbose >0 :
            print ("===================== Sensor clock setup 24MHz (will output 96MHz) =========================")
        self.setSensorClock(freq_MHz = 24.0)
        """
        if verbose >0 :
#            print ("===================== Set up sensor and interface power, clock generator  =========================")
            print ("===================== Set up clock generator (power should be set before bitstream)  =========================")
        self.setupSensorsPowerClock(setPower=False,       # Should be set before bitstream
                                    quiet = (verbose >0))
        if exit_step == 1: return False
        if verbose >0 :
            print ("===================== GPIO_SETUP =========================")
            
        self.x393GPIO.program_status_gpio (
                                       mode =    3,   # input [1:0] mode;
                                       seq_num = 0)   # input [5:0] seq_num;

        if verbose >0 :
            print ("===================== CMDSEQMUX_SETUP =========================")
        #Will report frame number for each channel
        self.setup_cmdmux()    
           
        if exit_step == 2: return False
        if verbose >0 :
            print ("===================== RTC_SETUP =========================")
        self.x393Rtc.program_status_rtc( # also takes snapshot
                                     mode =    1, # 3,     # input [1:0] mode;
                                     seq_num = 0)     #input [5:0] seq_num;
            
        self.x393Rtc.set_rtc () # no correction, use current system time
        if exit_step == 3: return False
        
        if verbose >0 :
            print ("===================== AFI_MUX_SETUP =========================")
        
        self.x393CmprsAfi.afi_mux_setup (
                               port_afi =       0,
                               chn_mask =       sensor_mask,
                               status_mode =    3, # = 3,
                                # mode == 0 - show EOF pointer, internal
                                # mode == 1 - show EOF pointer, confirmed written to the system memory
                                # mode == 2 - show current pointer, internal
                                # mode == 3 - show current pointer, confirmed written to the system memory
                               report_mode =    0, # = 0,
                               afi_cmprs0_sa =  afi_cmprs0_sa,
                               afi_cmprs0_len = afi_cmprs0_len,
                               afi_cmprs1_sa =  afi_cmprs1_sa,
                               afi_cmprs1_len = afi_cmprs1_len,
                               afi_cmprs2_sa =  afi_cmprs2_sa,
                               afi_cmprs2_len = afi_cmprs2_len,
                               afi_cmprs3_sa =  afi_cmprs3_sa,
                               afi_cmprs3_len = afi_cmprs3_len,
                               reset =          reset_afi)

        for num_sensor in range(4):
            if sensor_mask & (1 << num_sensor):
                if verbose >0 :
                    print ("===================== SENSOR%d_SETUP ========================="%(num_sensor+1))
                if gamma_load:    
                    if verbose >0 :
                        print ("===================== GAMMA_LOAD =========================")
                    self.x393_sensor.program_curves(
                                                    num_sensor = num_sensor,  #num_sensor,  # input   [1:0] num_sensor;
                                                    sub_channel = 0)          # input   [1:0] sub_channel;    
                    if verbose >0 :
                        print ("===================== SETUP_SENSOR_CHANNEL =========================")
                rslt = self.setup_sensor_channel (
                          exit_step =               exit_step,      # 10 .. 19
                          num_sensor =              num_sensor,
                          window_width =            window_width,   # 2592
                          window_height =           window_height,   # 1944
                          window_left =             window_left,     # 0
                          window_top =              window_top, # 0? 1?
#                          compressor_left_margin =  compressor_left_margin, #0?`1? 
                          last_buf_frame =          last_buf_frame,  #  - just 2-frame buffer
                          colorsat_blue =           colorsat_blue,     # 0x90 fo 1x
                          colorsat_red =            colorsat_red,     # 0xb6 for x1
                          clk_sel =                 clk_sel,         # 1
                          histogram_left =          histogram_left,
                          histogram_top =           histogram_top,
                          histogram_width_m1 =      histogram_width_m1,
                          histogram_height_m1 =     histogram_height_m1,
                          verbose =                 verbose)
                if not rslt : return False
                if exit_step == 20: return False
                """
                if verbose >0 :
                    print ("===================== AFI_MUX_SETUP =========================")
                
                self.x393CmprsAfi.afi_mux_setup (
                                       port_afi =       0,
                                       chn_mask =       sensor_mask,
                                       status_mode =    3, # = 3,
                                        # mode == 0 - show EOF pointer, internal
                                        # mode == 1 - show EOF pointer, confirmed written to the system memory
                                        # mode == 2 - show current pointer, internal
                                        # mode == 3 - show current pointer, confirmed written to the system memory
                                       report_mode =    0, # = 0,
                                       afi_cmprs0_sa =  afi_cmprs0_sa,
                                       afi_cmprs0_len = afi_cmprs_len,
                                       afi_cmprs1_sa =  afi_cmprs1_sa,
                                       afi_cmprs1_len = afi_cmprs_len,
                                       afi_cmprs2_sa =  afi_cmprs2_sa,
                                       afi_cmprs2_len = afi_cmprs_len,
                                       afi_cmprs3_sa =  afi_cmprs3_sa,
                                       afi_cmprs3_len = afi_cmprs_len)
                """                           
                self.x393Sensor.print_status_sensor_io (num_sensor = num_sensor)
                self.x393Sensor.print_status_sensor_i2c (num_sensor = num_sensor)
                
                if verbose >0 :
                    print ("===================== I2C_SETUP =========================")
                slave_addr = SENSOR_DEFAULTS[sensorType]["slave"]
                i2c_delay=  SENSOR_DEFAULTS[sensorType]["i2c_delay"]
                    
                self.x393Sensor.set_sensor_i2c_command (
                                num_sensor = num_sensor,
                                rst_cmd =   True,
                                verbose = verbose)

                self.x393Sensor.set_sensor_i2c_command (
                                num_sensor =      num_sensor,
                                active_sda =      True,
                                early_release_0 = True,
                                verbose = verbose)
    
                if sensorType ==  x393_sensor.SENSOR_INTERFACE_PARALLEL:
                    self.x393Sensor.set_sensor_i2c_table_reg_wr (
                                    num_sensor = num_sensor,
                                    page       = 0,
                                    slave_addr = slave_addr,
                                    rah        = 0,
                                    num_bytes  = 3, 
                                    bit_delay  = i2c_delay,
                                    verbose =    verbose)
                     
                    self.x393Sensor.set_sensor_i2c_table_reg_rd (
                                    num_sensor =    num_sensor,
                                    page       =    1,
                                    two_byte_addr = 0,
                                    num_bytes_rd =  2,
                                    bit_delay  =    i2c_delay,
                                    verbose =       verbose)
    # aliases for indices 0x90 and 0x91
                    self.x393Sensor.set_sensor_i2c_table_reg_wr (
                                    num_sensor = num_sensor,
                                    page       = 0x90,
                                    slave_addr = slave_addr,
                                    rah        = 0,
                                    num_bytes  = 3, 
                                    bit_delay  = i2c_delay,
                                    verbose = verbose)
                     
                    self.x393Sensor.set_sensor_i2c_table_reg_rd (
                                    num_sensor =    num_sensor,
                                    page       =    0x91,
                                    two_byte_addr = 0,
                                    num_bytes_rd =  2,
                                    bit_delay  =    100,
                                    verbose =       verbose)
                    
                    self.x393Sensor.set_sensor_i2c_table_reg_rd ( #for compatibility with HiSPi mode, last page for read
                                    num_sensor =    num_sensor,
                                    page       =    0xff,
                                    two_byte_addr = 0,
                                    num_bytes_rd =  2,
                                    bit_delay  =    i2c_delay,
                                    verbose =       verbose)

                elif sensorType == x393_sensor.SENSOR_INTERFACE_HISPI:
                    for page in (0,1,2,3,4,5,6,                           # SMIA configuration registers
                                 0x10,0x11,0x12,0x13,0x14,                # SMIA limit registers
                                 0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37, # Manufacturer registers
                                 0x38,0x39,0x3a,0x3b,0x3c,0x3d,0x3e):
                        self.x393Sensor.set_sensor_i2c_table_reg_wr (
                                        num_sensor = num_sensor,
                                        page       = page,
                                        slave_addr = slave_addr,
                                        rah        = page,
                                        num_bytes  = 4, 
                                        bit_delay  = i2c_delay,
                                        verbose = verbose)
                    
                    self.x393Sensor.set_sensor_i2c_table_reg_rd ( # last page used for read
                                    num_sensor =    num_sensor,
                                    page       =    0xff,
                                    two_byte_addr = 1,
                                    num_bytes_rd =  2,
                                    bit_delay  =    i2c_delay,
                                    verbose =       verbose)
                else:
                    raise ("Unknown sensor type: %s"%(sensorType))
                
                
# Turn off reset (is it needed?)
                self.x393Sensor.set_sensor_i2c_command (
                                num_sensor = num_sensor,
                                rst_cmd =   False)
# Turn on sequencer
                self.x393Sensor.set_sensor_i2c_command (
                                num_sensor = num_sensor,
                                run_cmd =   True)

        if exit_step == 21: return False

        self.x393Camsync.camsync_setup (
                     sensor_mask =        sensor_mask,
                      trigger_mode =       False, # False - async (free running) sensor mode, True - triggered (global reset) sensor mode
                      ext_trigger_mode =   False, # True - external trigger source, 0 - local FPGA trigger source
                      external_timestamp = False, # True - use received timestamp in the image file, False - use local timestamp 
                      camsync_period =     None,
                      camsync_delay =      None)
        
        
    def print_status_sensor(self,
                            restart = False,
                            chn = None):
        """
        Decode and print channel-related status
        @param restart - reset "alive" bits, wait 1 second, read status
        @param chn - channel numberr or None - in that case print it for all channels
        """
        if chn is None:
            sensors=range(4)
        else:
            sensors = [chn]

        if restart:
            for chn in sensors:

                self.x393Sensor.program_status_sensor_i2c(
                    num_sensor = chn,  # input [1:0] num_sensor;
                    mode =       3,           # input [1:0] mode;
                    seq_num =    0);          # input [5:0] seq_num;
                self.x393Sensor.program_status_sensor_io(
                    num_sensor = chn,  # input [1:0] num_sensor;
                    mode =       3,           # input [1:0] mode;
                    seq_num =    0);          # input [5:0] seq_num;
        
                self.x393Cmprs.program_status_compressor(
                    cmprs_chn =  chn,  # input [1:0] num_sensor;
                    mode =       3,           # input [1:0] mode;
                    seq_num =    0);          # input [5:0] seq_num;
            time.sleep(1)
        for chn in sensors:
            self.x393Sensor.print_status_sensor_io (num_sensor = chn)
            self.x393Sensor.print_status_sensor_i2c (num_sensor = chn)
            
### Debug network methods
    def program_status_debug( self,
                              mode,     # input [1:0] mode;
                              seq_num): # input [5:0] seq_num;
        """
        Set status generation mode for selected sensor port i2c control
        @param mode -       status generation mode:
                                  0: disable status generation,
                                  1: single status request,
                                  2: auto status, keep specified seq number,
                                  3: auto, inc sequence number 
        @param seq_number - 6-bit sequence number of the status message to be sent
        """

        self.x393_axi_tasks.program_status (vrlg.DEBUG_ADDR,
                             vrlg.DEBUG_SET_STATUS,
                             mode,
                             seq_num)
            
    def debug_read_ring(self,
                        num32 = 32):
        """
        Read serial debug ring
        @param num32 - number of 32-bit words to read
        @return - list of the 32-bit words read
        """
        maxTimeout = 2.0 # sec
        endTime=time.time() + maxTimeout
        result = []
        # load all shift registers from sources
        self.x393_axi_tasks.write_control_register(vrlg.DEBUG_ADDR + vrlg.DEBUG_LOAD, 0); 
        for i in range (num32): 
            seq_num = (self.x393_axi_tasks.read_status(vrlg.DEBUG_STATUS_REG_ADDR) >> vrlg.STATUS_SEQ_SHFT) & 0x3f;
            self.x393_axi_tasks.write_control_register(vrlg.DEBUG_ADDR + vrlg.DEBUG_SHIFT_DATA, (0,0xffffffff)[i==0]);
            while seq_num == (self.x393_axi_tasks.read_status(vrlg.DEBUG_STATUS_REG_ADDR) >> vrlg.STATUS_SEQ_SHFT) & 0x3f:
                if time.time() > endTime:
                    return None 
            result.append(self.x393_axi_tasks.read_status(vrlg.DEBUG_READ_REG_ADDR))
        return result    
            

    def setup_membridge_sensor(self,
                               num_sensor      = 0,
                               write_mem       = False,
#                               cache_mode      = 0x3, # 0x13 for debug mode
                               window_width    = 2592,
                               window_height   = 1944,
                               window_left     = 0,
                               window_top      = 0,
                               last_buf_frame =  1,  #  - just 2-frame buffer
                               membridge_start = None,
                               membridge_end   = None,
                               verbose         = 1):
        """
        Configure membridge to read/write to the sensor 0 area in the video memory
        @param num_sensor - sensor port number (0..3)
        @param write_mem - Write to video memory (Flase - read from)
        @param window_width -  window width in pixels (bytes) (TODO: add 16-bit mode)
        @param window_height - window height in lines
        @param window_left -   window left margin
        @param window_top -    window top margin
        @param last_buf_frame) -   16-bit number of the last frame in a buffer
        @param membridge_start system memory low address (bytes) 0x2ba00000,
        @param membridge_end   system memory buffer length (bytes)= 0x2dd00000,
        @param verbose         verbose level):
        """
        global GLBL_MEMBRIDGE_H2D_START, GLBL_MEMBRIDGE_H2D_END, GLBL_MEMBRIDGE_D2H_START, GLBL_MEMBRIDGE_D2H_END
        if (membridge_start is None) or (membridge_end is None):
            if write_mem:
                membridge_start = GLBL_MEMBRIDGE_H2D_START
                membridge_end =   GLBL_MEMBRIDGE_H2D_END
            else:
                membridge_start = GLBL_MEMBRIDGE_D2H_START
                membridge_end =   GLBL_MEMBRIDGE_D2H_END
#copied from setup_sensor_channel()
        align_to_bursts = 64 # align full width to multiple of align_to_bursts. 64 is the size of memory access
        width_in_bursts = window_width >> 4
        if (window_width & 0xf):
            width_in_bursts += 1
        num_burst_in_line = (window_left >> 4) + width_in_bursts
        num_pages_in_line = num_burst_in_line // align_to_bursts;
        if num_burst_in_line % align_to_bursts:
            num_pages_in_line += 1
        """
        Changing frame full width and size to fixed values (normally read from sysfs)
                frame_full_width =  num_pages_in_line * align_to_bursts
        
        """
        
        frame_full_width =  0x200 # Made it fixed width
        num8rows=   (window_top + window_height) // 8
        if (window_top + window_height) % 8:
            num8rows += 1
        """    
        frame_start_address_inc = num8rows * frame_full_width
        """
        frame_start_address_inc = 0x80000 #Fixed size

        frame_start_address = (last_buf_frame + 1) * frame_start_address_inc * num_sensor
        
        if verbose >0 :
            print ("===================== Setting membridge for sensor 0 =========================")
            print ("Write to video buffer =     %s"%(("False","True")[write_mem]))
            print ("num_sensor =                ", num_sensor)
            print ("Window width =              %d(0x%x)"%(window_width,window_width))
            print ("Window height =             %d(0x%x)"%(window_height,window_height))
            print ("Window left =               %d(0x%x)"%(window_left,window_left))
            print ("Window top =                %d(0x%x)"%(window_top,window_top))
            print ("frame_start_address =       0x%x"%(frame_start_address))
            print ("frame_start_address_inc =   0x%x"%(frame_start_address_inc))
            print ("membridge start =           0x%x"%(membridge_start))
            print ("membridge end =             0x%x"%(membridge_end))
            print ("membridge size =            %d bytes"%(membridge_end - membridge_start))
            
            
        # Copied from setup_sensor    
        align_to_bursts = 64 # align full width to multiple of align_to_bursts. 64 is the size of memory access
        width_in_bursts = window_width >> 4
        if (window_width & 0xf):
            width_in_bursts += 1
        num_burst_in_line = (window_left >> 4) + width_in_bursts
        num_pages_in_line = num_burst_in_line // align_to_bursts;
        if num_burst_in_line % align_to_bursts:
            num_pages_in_line += 1
        """
        Changing frame full width and size to fixed values (normally read from sysfs)
                frame_full_width =  num_pages_in_line * align_to_bursts
        
        """
        
        frame_full_width =  0x200 # Made it fixed width
        num8rows=   (window_top + window_height) // 8
        if (window_top + window_height) % 8:
            num8rows += 1
            
        if verbose >0 :
            print ("width_in_bursts =           %d(0x%x)"%(width_in_bursts,width_in_bursts))
            print ("num_burst_in_line =         %d(0x%x)"%(num_burst_in_line,num_burst_in_line))
            print ("num_pages_in_line =         %d(0x%x)"%(num_pages_in_line,num_pages_in_line))
            print ("num8rows =                  %d(0x%x)"%(num8rows,num8rows))
            
#        frame_start_addr = 0 # for sensor 0
#        frame_start_address_inc = num8rows * frame_full_width
#        len64 = num_burst_in_line * 2 * window_height    
  
        """
        Setup video memory
        """
        mode=   x393_mcntrl.func_encode_mode_scan_tiled(
                                   skip_too_late = False,                     
                                   disable_need = False,
                                   repetitive=    True,
                                   single =       False,
                                   reset_frame =  True, # False, now start address is only copied at reset_frame
                                   extra_pages =  0,
                                   write_mem =    write_mem,
                                   enable =       True,
                                   chn_reset =    False,
                                   abort_late =   False)

        self.x393_axi_tasks.write_control_register(vrlg.MCNTRL_SCANLINE_CHN1_ADDR + vrlg.MCNTRL_SCANLINE_STARTADDR,        frame_start_address) # RA=80, CA=0, BA=0 22-bit frame start address (3 CA LSBs==0. BA==0) 
        self.x393_axi_tasks.write_control_register(vrlg.MCNTRL_SCANLINE_CHN1_ADDR + vrlg.MCNTRL_SCANLINE_FRAME_FULL_WIDTH, frame_full_width)
#        self.x393_axi_tasks.write_control_register(vrlg.MCNTRL_SCANLINE_CHN1_ADDR + vrlg.MCNTRL_SCANLINE_WINDOW_WH,        (window_height << 16) | (window_width >> 4)) # WINDOW_WIDTH + (WINDOW_HEIGHT<<16));
# width should include partial bursts to matych membridge
        self.x393_axi_tasks.write_control_register(vrlg.MCNTRL_SCANLINE_CHN1_ADDR + vrlg.MCNTRL_SCANLINE_WINDOW_WH,        (window_height << 16) | num_burst_in_line) # WINDOW_WIDTH + (WINDOW_HEIGHT<<16));
        self.x393_axi_tasks.write_control_register(vrlg.MCNTRL_SCANLINE_CHN1_ADDR + vrlg.MCNTRL_SCANLINE_WINDOW_X0Y0,      (window_top << 16) | (window_left >> 4))     # WINDOW_X0+ (WINDOW_Y0<<16));
        self.x393_axi_tasks.write_control_register(vrlg.MCNTRL_SCANLINE_CHN1_ADDR + vrlg.MCNTRL_SCANLINE_WINDOW_STARTXY,   0)
        self.x393_axi_tasks.write_control_register(vrlg.MCNTRL_SCANLINE_CHN1_ADDR + vrlg.MCNTRL_SCANLINE_MODE,             mode) 
        self.x393_axi_tasks.configure_channel_priority(1,0);    # lowest priority channel 1
        self.x393_axi_tasks.enable_memcntrl_en_dis(1,1);
        self.x393Membridge.afi_setup(0)
        """
        self.afi_write_reg(port_num, 0x0,      0) # AFI_RDCHAN_CTRL
        self.afi_write_reg(port_num, 0x04,   0x7) # AFI_RDCHAN_ISSUINGCAP
        self.afi_write_reg(port_num, 0x08,     0) # AFI_RDQOS
        #self.afi_write_reg(port_num,0x0c,     0) # AFI_RDDATAFIFO_LEVEL
        #self.afi_write_reg(port_num,0x10,     0) # AFI_RDDEBUG
        self.afi_write_reg(port_num, 0x14, 0xf00) # AFI_WRCHAN_CTRL
        self.afi_write_reg(port_num, 0x18,   0x7) # AFI_WRCHAN_ISSUINGCAP
        self.afi_write_reg(port_num, 0x1c,     0) # AFI_WRQOS
        #self.afi_write_reg(port_num,0x20,     0) # AFI_WRDATAFIFO_LEVEL
        #self.afi_write_reg(port_num,0x24,     0) # AFI_WRDEBUG
        """
        self.x393Membridge.membridge_setup(
                                           len64 =     num_burst_in_line * 2 * window_height,
                                           width64 =   num_burst_in_line * 2, # 0,
                                           start64 =   0,
                                           lo_addr64 = membridge_start // 8,
                                           size64 =    (membridge_end - membridge_start) // 8,
#                                           cache =     cache_mode,
                                           quiet = 1 - verbose)
        
        self.x393Membridge.membridge_en( # enable membridge
                                        en =     True,
                                        quiet = 1 - verbose)
        
        if verbose >0 :
            print ("Run 'membridge_start' to initiate data transfer")
            print ("Use 'mem_dump 0x%x <length>' to view data"%(membridge_start))
            if (write_mem):
                print ("Synchronize to device after preparing data with:")
                print ('sync_for_device "H2D" 0x%x 0x%x'%(membridge_start, membridge_end - membridge_start))
            else:    
                print ("Synchronize to CPU with:")
                print ('sync_for_cpu "D2H" 0x%x 0x%x'%(membridge_start, membridge_end - membridge_start))
            print ("Use 'mem_save \"/usr/local/verilog/memdumpXX\" 0x%x 0x%x' to save data"%(membridge_start,(membridge_end - membridge_start)))
        return {"start_addr":membridge_start,"width_padded":num_burst_in_line*16}    

    def print_debug( self,
                     first = None,
                     last = None,
                     num32 = 200):
        """
        Read and print serial debug ring as a sequence of 32-bit numbers
        @parame first - index of the first 32-bit debug word to decode
                       also valid: "list" - print list of all fields,
                       "raw" - print 32-bit hex data only
        @parame last - index of the last 32-bit debug word to decode
        @param num32 - number of 32-bit words to read
        @return - list of the 32-bit words read
        """
        debug_dict = {"x393":          (("sensors393_i",       "sensors393"),
                                        ("compressors393_i",   "compressors393"),
                                        ("membridge_i",        "membridge")),
                      "sensors393":    (("sensor_channel0_i",  "sensor_channel"),
                                        ("sensor_channel1_i",  "sensor_channel"),
                                        ("sensor_channel2_i",  "sensor_channel"),
                                        ("sensor_channel3_i",  "sensor_channel"),
                                        ("histogram_saxi_i",   "histogram_saxi")),
                      "sensor_channel":(("sens_histogram0_i",  "sens_histogram"),
#                                        ("sens_histogram1_i",  "sens_histogram"),
#                                        ("sens_histogram2_i",  "sens_histogram"),
#                                        ("sens_histogram3_i",  "sens_histogram"),
                                        
                                        ("debug_line_cntr",    16),
                                        ("debug_lines",        16),
                                        ("hact_cntr",          16),
                                        ("hist_rq",            4),
                                        ("hist_gr",            4),
                                        ("hist_request",       1),
                                        ("hist_grant",         1),
                                        (None,                 6),
                                        ("gamma_pxd_out",      8),
                                        ("pxd",                12),
                                        ("pxd_to_fifo",        12),
                                        ("gamma_pxd_in",       16),
                                         ("lens_pxd_in",       16)),
                      "sens_histogram":(("hcntr",              16),
                                        ("width_m1",           16),
                                        ("debug_line_cntr",    16),
                                        ("debug_lines",        16)),
                      "histogram_saxi":(("pri_rq",             4),
                                        ("enc_rq",             3),
                                        ("start_w",            1), # 8
                                        ("pages_in_buf_wr",    3),
                                        (None,                 1),
                                        ("burst",              3 ), 
                                        (None,                 1), # 16
                                        ("started",            1),
                                        ("busy_r",             1),
                                        ("busy_w",             1),
                                        (None,                 1),
                                        ("chn_grant",          4), # 24
                                        ("frame0",             4),
                                        ("hist_chn0",          2),
                                        (None,                 2), # 32
                                        ("saxi_awsize",        2),
                                        ("saxi_awburst",       2),
                                        ("saxi_awlen",         4), # 40
                                        ("saxi_awprot",        3),
                                        (None,                 1),
                                        ("saxi_awcache",       4), # 48
                                        ("saxi_awid",          6),
                                        ("saxi_awlock",        2), # 56
                                        ("saxi_awvalid",       1),
                                        ("saxi_awready",       1),
                                        (None,                 6), # 64
                                        ("saxi_wid",           6),
                                        ("saxi_wvalid",        1),
                                        ("saxi_wready",        1), # 72
                                        ("saxi_wlast",         1),
                                        (None,                 3),
                                        ("page_rd",            2),
                                        ("page_wr",            2), # 80
                                        ("num_bursts_pending", 5),
                                        (None,                 3), # 88
                                        ("num_bursts_in_buf",  5),
                                        (None,                 3), # 96
                                        ("page_ra",            8), # 104
                                        ("extra_ra",           8), # 112
                                        ("page_wa",            8), # 120
                                        ("extra_wa",           8), # 128
                                        ("num_addr_saxi",     16), # 144
                                        ("num_addr_saxi",     16), # 160
                                        ),
                      "compressors393":(("jp_channel0_i",      "jp_channel"),
                                        ("jp_channel1_i",      "jp_channel"),
                                        ("jp_channel2_i",      "jp_channel"),
                                        ("jp_channel3_i",      "jp_channel"),
                                        ("cmprs_afi0_mux_i",   "cmprs_afi_mux")),
                      "jp_channel":    (("line_unfinished_src",16),
                                        ("frame_number_src",   16),
                                        ("line_unfinished_dst",16),
                                        ("frame_number_dst",   16),
                                        ("suspend",            1),
                                        ("sigle_frame_buf",    1),
                                        ("dbg_last_DCAC",      1),
                                        ("dbg_lastBlock_sent", 1),
                                        ("dbg_gotLastBlock_persist",1),
                                        ("dbg_fifo_or_full",   1),
                                        (None,                 2),
                                        ("fifo_count",         8),
                                        ("reading_frame",      1),
                                        ("debug_frame_done",   1),
                                        ("stuffer_running_mclk",1),
                                        ("dbg_stuffer_ext_running",1),
                                        ("etrax_dma",          4),
                                        ("stuffer_rdy",        1),
                                        ("dbg_flushing",       1),
                                        ("dbg_flush_hclk",     1),
                                        ("dbg_last_block",     1),
                                        ("dbg_test_lbw",       1),
                                        ("dbg_gotLastBlock",   1),
                                        ("dbg_last_block_persist",1),
                                        ("color_last",         1),
#                                        (None,                 2),
                                        ("debug_fifo_in",      32),
                                        ("debug_fifo_out",     28),
                                        ("dbg_block_mem_ra",    3),
                                        ("dbg_comp_lastinmbo",  1),
                                        ("pages_requested",    16),
                                        ("pages_got",          16),
                                        ("pre_start_cntr",     16),
                                        ("pre_end_cntr",       16),
                                        ("page_requests",      16),
                                        ("pages_needed",       16),
                                        ("dbg_stb_cntr",       16),
                                        ("dbg_zds_cntr",       16),
                                        ("dbg_block_mem_wa",   3),
                                        ("dbg_block_mem_wa_save",3),
                                        (None,                 26),
                                        ("dbg_sec",            32),
                                        ("dbg_usec",           32)
                                        ),
                      "cmprs_afi_mux": (("fifo_count0",        8),
                                        (None,                 24),
                                        ("left_to_eof",        32)),
                      "membridge":     (("afi_wcount",         8),
                                        ("afi_wacount",        6),
                                        (None,                 2),
                                        ("afi_rcount",         8),
                                        ("afi_racount",        3),
                                        (None,                 5))       
                      }
        def flatten_debug(inst,item):
            if (isinstance(item,str)):
                mod_struct=debug_dict[item]
                result = []
                for node in mod_struct:
                    sub_inst = node[0]
                    if not ((inst is None) or (node[0] is None)):
                        sub_inst= inst+"."+node[0]
                    result += flatten_debug(sub_inst,node[1])    
            else: # value
                result = [(inst, item)]
            return result

        flat =  flatten_debug(None,"x393")
        maximal_name_length = max([len(f[0]) for f in flat if f[0] is not None])
        num_bits=0;
        for p in flat:
            num_bits += p[1]
        num_words = num_bits// 32
        if num_bits % 32:
            num_words += 1
        if (first == list) or (first == "list"):
            l=0;
            for p in flat:
                print (("%03x.%02x: %"+str(maximal_name_length)+"s")%(l // 32, l % 32, p[0]))
                l += p[1]
            print("total bits: ", l)    
            print("total words32: ", l / 32) 
            return
        
        if (self.DRY_MODE):
            status = [0xaaaaaaaa,0x55555555]*(num32 // 2)
            if (num32 % 2) !=0:
                status += [0xaaaaaaaa]
            status.append(0xffffffff)
        else:
            status = self.debug_read_ring(num32)
        if first == "raw":
            numPerLine = 8
            for i,d in enumerate (status):
                if ( i % numPerLine) == 0:
                    print ("\n%2x: "%(i), end="")
                print("%s "%(hx(d,8)), end = "") 
            print()   
            return
        
        if not (first is None) and (last is None):
            last=first
        if first is None:
            first = 0
            
        if (last is None) or (last > (num32-1)):
            last = (num32-1)
        if (last is None) or (last > (num_words-1)):
            last = (num_words-1)
#        if (num_words)    
#        for i,d in enumerate (status):
#            if d == 0xffffffff:
#                if i <= last:
#                   last = i - 1
#                break
#        print("first = ",first)
#        print ("last = ",last)    
#        print("total bits: ", l)    
#        print("total words32: ", l // 32) 
        l=0;
        long_status = 0;
        for i,s in enumerate(status):
            long_status |= s << (32*i)
#        print (long_status)
#       print (hex(long_status))        
        for p in flat:
            if ((l // 32) >= first) and ((l // 32) <= last) and (not p[0] is None):
                d = (long_status >> l) & ((1 << p[1]) - 1)
                print (("%03x.%02x: %"+str(maximal_name_length)+"s [%2d] = 0x%x (%d)")%(l // 32, l % 32, p[0],p[1],d,d))
            l += p[1]
    def program_huffman(self,
                        chn,
                        index,
                        huffman_data):
        """
        @brief Program data to compressor Huffman table
        @param chn - compressor channel (0..3)
        @param index offset address by multiple input data sizes
        @param huffman_data - list of table 512 items or a file path
                             with the same data, same as for Verilog $readmemh
        """
        if isinstance(huffman_data, (unicode,str)):
            with open(huffman_data) as f:
                tokens=f.read().split()
            huffman_data = []
            for w in tokens:
                huffman_data.append(int(w,16))
        self.program_table(chn =        chn,
                           table_type = "huffman",
                           index =      index,
                           data =       huffman_data)                
                
    def program_quantization(self,
                             chn,
                             index,
                             quantization_data,
                             verbose = 1):
        """
        @brief Program data to quantization table ( a pair or four of Y/C 64-element tables)
        @param chn - compressor channel (0..3)
        @param index offset address by multiple input data sizes
        @param quantization_data - list of table 64/128/256 items or a file path (file has 256-entry table)
        @param verbose - verbose level
                             with the same data, same as for Verilog $readmemh
        """
        if isinstance(quantization_data, (unicode,str)):
            with open(quantization_data) as f:
                tokens=f.read().split()
            quantization_data = []
            for w in tokens:
                quantization_data.append(int(w,16))
        self.program_table(chn =        chn,
                           table_type = "quantization",
                           index =      index,
                           data =       quantization_data,
                           verbose =    verbose)                
    def program_coring(self,
                       chn,
                       index,
                       coring_data):
        """
        @brief Program data to quantization table ( a pair or four of Y/C 64-element tables)
        @param chn - compressor channel (0..3)
        @param index offset address by multiple input data sizes
        @param coring_data - list of table 64/128/256 items or a file path (file has 256-entry table)
                             with the same data, same as for Verilog $readmemh
        """
        if isinstance(coring_data, (unicode,str)):
            with open(coring_data) as f:
                tokens=f.read().split()
            coring_data = []
            for w in tokens:
                coring_data.append(int(w,16))
        self.program_table(chn =        chn,
                           table_type = "coring",
                           index =      index,
                           data =       coring_data)
        
    def program_focus(self,
                      chn,
                      index,
                      focus_data):
        """
        @brief Program data to focus sharpness weight table
        @param chn - compressor channel (0..3)
        @param index offset address by multiple input data sizes
        @param focus_data - list of table 128 items or a file path
                             with the same data, same as for Verilog $readmemh
        """
        if isinstance(focus_data, (unicode,str)):
            with open(focus_data) as f:
                tokens=f.read().split()
            focus_data = []
            for w in tokens:
                focus_data.append(int(w,16))
        self.program_table(chn =        chn,
                           table_type = "focus",
                           index =      index,
                           data =       focus_data)                
                
    
    def program_table(self,
                      chn,
                      table_type,
                      index,
                      data,
                      verbose = 0):
        """
        @brief Program data to compressor table
        @param chn - compressor channel (0..3)
        @param table_type : one of "quantization", "coring","focus","huffman"
        @param index offset address as index*len(data32) = index*len(data)*merge_num
        @param data - list of table items
        """
        table_types = [{"name":"quantization", "merge":2, "t_num": vrlg.TABLE_QUANTIZATION_INDEX},
                       {"name":"coring",       "merge":2, "t_num": vrlg.TABLE_CORING_INDEX},
                       {"name":"focus",        "merge":2, "t_num": vrlg.TABLE_FOCUS_INDEX},
                       {"name":"huffman",      "merge":1, "t_num": vrlg.TABLE_HUFFMAN_INDEX}]
        
        for item in table_types:
            if (table_type == item['name']):
                merge_num =   item["merge"];
                t_num =       item["t_num"];
                break;
        else:
            raise Exception ("Invalid table type :",table_type," table_types=",table_types)
        reg_addr = (vrlg.CMPRS_GROUP_ADDR + chn * vrlg.CMPRS_BASE_INC) + vrlg.CMPRS_TABLES # for data, adderss is "reg_addr + 1"
        if merge_num == 1:
            data32 = data
        else:
            data32 = []
            for i in range(len(data) // merge_num):
                d = 0;
                for j in range (merge_num):
                    d |=  data[2* i + j] << (j * (32 // merge_num))   
                data32.append(d)
        '''
        t_addr[23:0] is in BYTES (so *4)
        '''        
        t_addr = (t_num << 24) + index* len(data32) * 4
        print("name: %s, merge_num=%d, t_num=%d, len(data32)=%d, index=%d, t_addr=0x%x"%
              (item['name'], merge_num, t_num, len(data32), index,t_addr))
        self.x393_axi_tasks.write_control_register(reg_addr + 1, t_addr)
        for d in data32:
            self.x393_axi_tasks.write_control_register(reg_addr, d)

#copied from x393_sata                               
    def get_mem_buf_args(self, saddr=None, leng=None):
        #Is it really needed? Or use cache line size (32B), not PAGE_SIZE?
#        args=""
        if (saddr is None) or (leng is None):
            return ""
        else:
            eaddr = PAGE_SIZE * ((saddr+leng) // PAGE_SIZE)
            if ((saddr+leng) % PAGE_SIZE):
                eaddr += PAGE_SIZE
            saddr = PAGE_SIZE * (saddr // PAGE_SIZE)
            return "%d %d"%(saddr, eaddr-saddr )    
    def _get_dma_dir_suffix(self, direction):
        if   direction.upper()[0] in "HT":
            return "_h2d"
        elif direction.upper()[0] in "DF":
            return "_d2h"
        elif direction.upper()[0] in "B":
            return "_bidir"
    def sync_for_cpu(self, direction, saddr=None, leng=None):
        if self.DRY_MODE:
            self.x393_mem.flush_simulation()            
            #print ("Simulating sync_for_cpu(),",self.get_mem_buf_args(saddr, leng)," -> ",MEM_PATH + BUFFER_FOR_CPU + self._get_dma_dir_suffix(direction))
            return
        with open (MEM_PATH + BUFFER_FOR_CPU + self._get_dma_dir_suffix(direction),"w") as f:
            print (self.get_mem_buf_args(saddr, leng),file=f)
                    
    def sync_for_device(self, direction, saddr=None, leng=None):
        if self.DRY_MODE:
            self.x393_mem.flush_simulation()            
            #print ("Simulating sync_for_device(),",self.get_mem_buf_args(saddr, leng)," -> ",MEM_PATH + BUFFER_FOR_DEVICE + self._get_dma_dir_suffix(direction))
            return
        with open (MEM_PATH + BUFFER_FOR_DEVICE + self._get_dma_dir_suffix(direction),"w") as f:
            print (self.get_mem_buf_args(saddr, leng),file=f)
    """
flush_simulation    
cd /usr/local/verilog/; test_mcntrl.py @hargs
#fpga_shutdown
setupSensorsPower "PAR12"
measure_all "*DI"
#program_status_sensor_io all 1 0
#setup_all_sensors True None 0xf

setup_simulated_mode "sensor_to_memory_1.dat"
#compressor_control  all  None  None  None None None  3

sync_for_device "D2H" 0x2d800000 0x400000
compressor_control 0 2
sync_for_cpu "D2H" 0x2d800000 0x400000
jpeg_write "img.jpeg" 0

specify_window 66 36 0 0 0 3 1
jpeg_write "img.jpeg" 1



membridge h2d_start =       0x2dc00000
membridge h2d end =         0x2e000000
membridge h2d size =        4194304 bytes
membridge h2d start =       0x2d800000
membridge h2d end =         0x2dc00000
membridge h2d size =        4194304 bytes
    
setup_membridge_sensor 0 False 3 66 36 0 0 0 0x2d800000 0x2dc00000 2
jpeg_write "img.jpeg" 0 100 None False 0 "/www/pages/" 3
    
00000000: fe 08 3c 33 ff 00 21 5b 3f fa f8 8f ff 00 42 1f 
00000010: e7 b7 d4 75 1f 66 fe db 72 ef b6 fd 9b 63 f3 77 
00000020: f9 5f 04 2d 07 97 f6 8f 37 c9 dd e2 df 11 b6 df 
00000030: 27 fb 5e fb ec db be f6 cf ec dd 17 7f df f2 2e 
00000040: bf e3 e0 fc 6b e1 e8 a5 87 55 b0 f3 a3 92 2f 32 
00000050: 68 de 3f 31 19 37 a0 98 c4 5d 37 01 b9 44 b1 bc 
00000060: 65 87 02 44 74 dc 19 4e 3e e6 fd af 7c 3d af f8 
00000070: ae cb f6 7e 7f 0e e9 d7 da ec 3a 1f c0 68 ef 35 
00000080: 43 a7 33 5f 47 a4 da 41 e2 8d 7a e2 e2 6b b4 8f 
00000090: 57 bf 5d 3e 28 e1 9e 29 e4 f3 34 ed 0c 34 52 2c 
000000a0: e6 0b a4 3f 6a 3f 97 71 c6 27 0f 85 e3 3f 09 aa 
000000b0: e2 ab d1 c3 52 7c 55 9d 53 f6 98 8a b0 a3 4f da 
000000c0: 55 e0 1e 31 a7 4a 9f 3d 49 46 3c f5 6a 4a 34 e9 
000000d0: c6 fc d3 9c a3 18 a7 26 91 f7 fe 1e 65 f8 fe 21 
000000e0: cb bc 43 c2 e4 18 1c 5e 79 89 c6 70 6e 5d 80 c2 
000000f0: 61 f2 7c 35 6c ce be 2b 1d 5f c5 8f 0d f2 ea 18 
00000100: 2c 3d 1c 14 2b d4 af 8b ad 98 4a 38 1a 58 6a 51 
00000110: 95 6a 98 c9 47 0b 08 3a ed 40 f8 5b c3 3f f2 15 
00000120: b3 ff 00 af 88 ff 00 f4 21 fe 7b 7d 47 51 f6 67 


    
    
    """

# Setup for compression of the simulated data
    def setup_simulated_mode(self,
                             data_file =       None,
                             chn =             0,
                             qbank =           0,
                             y_quality =       None,
                             c_quality =       None, # use "same" to save None
                             cmode =           0, # vrlg.CMPRS_CBIT_CMODE_JPEG18,
                             bayer =           3, #0, as in simulator
                             window_width    = 66,
                             window_height   = 36,
                             window_left     = 0,
                             window_top      = 0,
                             colorsat_blue =    0x120,     # 0x90 for 1x
                             colorsat_red =     0x16c,     # 0xb6 for x1
                             verbose         = verbose):
        """
        @brief Stop sensor, configure membridge channel and write simulated data from teh text file (same as for simulation)
        @param data_file -     data_file - hex simulation data as used in simulation ('None' will use sensor_to_memory_%d.dat)
        @param chn -           compressor channel (0..3)
        @param qbank -         quantization table page (0..15)
        @param y_quality -     for JPEG header only
        @param c_quality =     for JPEG header only,use "same" to save None
        
        @param cmode -         color mode:
                                CMPRS_CBIT_CMODE_JPEG18 =          0 - color 4:2:0
                                CMPRS_CBIT_CMODE_MONO6 =           1 - mono 4:2:0 (6 blocks)
                                CMPRS_CBIT_CMODE_JP46 =            2 - jp4, 6 blocks, original
                                CMPRS_CBIT_CMODE_JP46DC =          3 - jp4, 6 blocks, dc -improved
                                CMPRS_CBIT_CMODE_JPEG20 =          4 - mono, 4 blocks (but still not actual monochrome JPEG as the blocks are scanned in 2x2 macroblocks)
                                CMPRS_CBIT_CMODE_JP4 =             5 - jp4,  4 blocks, dc-improved
                                CMPRS_CBIT_CMODE_JP4DC =           6 - jp4,  4 blocks, dc-improved
                                CMPRS_CBIT_CMODE_JP4DIFF =         7 - jp4,  4 blocks, differential
                                CMPRS_CBIT_CMODE_JP4DIFFHDR =      8 - jp4,  4 blocks, differential, hdr
                                CMPRS_CBIT_CMODE_JP4DIFFDIV2 =     9 - jp4,  4 blocks, differential, divide by 2
                                CMPRS_CBIT_CMODE_JP4DIFFHDRDIV2 = 10 - jp4,  4 blocks, differential, hdr,divide by 2
                                CMPRS_CBIT_CMODE_MONO1 =          11 -  mono JPEG (not yet implemented)
                                CMPRS_CBIT_CMODE_MONO4 =          14 -  mono 4 blocks
        @param bayer -         Bayer shift (0..3)
        @param window_width -  window width in pixels (bytes) (TODO: add 16-bit mode)
        @param window_height - window height in lines
        @param window_left -   window left margin
        @param window_top -    window top margin
        @param colorsat_blue - color saturation for blue (10 bits), 0x90 for 100%
        @param colorsat_red -  color saturation for red (10 bits), 0xb6 for 100%
        @param verbose         verbose level
        """
        
        global GLBL_CIRCBUF_STARTS, GLBL_CIRCBUF_ENDS
        global GLBL_MEMBRIDGE_H2D_START, GLBL_MEMBRIDGE_H2D_END, GLBL_MEMBRIDGE_D2H_START, GLBL_MEMBRIDGE_D2H_END

        if data_file is None:
            data_file = "sensor_to_memory_%d.dat"%chn

        # Read data file
        sensor_data = []
        try:
            with open(data_file) as f:
                for l in f:
                    line = l.strip()
                    if line:
                        dl = []
                        for item in line.split():
                            dl.append(int(item,16))
                        sensor_data.append(dl)
            num_cols =  max([len(l) for l in sensor_data])
            num_rows = len(sensor_data)           
                        
            if verbose > 0:
                print ("Read simulated sensor data of %d rows by %d columns from %s data file"%(num_rows, num_cols,data_file))
        except:
            print("Failed to read data from ", data_file)
            return

            
# Above did not work, try disabling memory channel
        self.x393_axi_tasks.enable_memcntrl_en_dis(8 + chn, False);

#Will restore default circbuf parameters        
        self.specify_phys_memory() # setup physical memory
        
#Overwrite CIRCBUF parameters for selected channel with D2H stream DMA buffer (shared with membridge)        
        GLBL_CIRCBUF_STARTS[chn] = GLBL_MEMBRIDGE_D2H_START
        GLBL_CIRCBUF_ENDS[chn] =   GLBL_MEMBRIDGE_D2H_END
        
        membridge_format = self.setup_membridge_sensor(
                               num_sensor      = chn,         
                               write_mem       = True,
                               window_width    = window_width,
                               window_height   = window_height,
                               window_left     = window_left,
                               window_top      = window_top,
                               last_buf_frame  = 0, # single frame
#                               membridge_start = GLBL_MEMBRIDGE_START,
#                               membridge_end   = GLBL_MEMBRIDGE_END,
                               membridge_start = GLBL_MEMBRIDGE_H2D_START,
                               membridge_end   = GLBL_MEMBRIDGE_H2D_END,
                               verbose         = verbose)
#Fill membridge buffer with the data read from the file, rolling over if insufficient columns/rows
        if verbose > 1:
            print("membridge_format: start_addr=0x%08x, width_padded=0x%08x"%(membridge_format["start_addr"],membridge_format["width_padded"]))
        self.sync_for_cpu('H2D',GLBL_MEMBRIDGE_H2D_START, GLBL_MEMBRIDGE_H2D_END - GLBL_MEMBRIDGE_H2D_START) # command and PRD table
        for sline in range(window_height):
            line_start = membridge_format["start_addr"] + sline * membridge_format["width_padded"]
            if verbose > 1:
                print("0x%08x: "%(line_start), end = "")
            for scol4 in range(0,window_width,4):
                data = 0
                for b in range(4): 
                    try:
                        data |= sensor_data[sline % num_rows][(scol4 + b) % num_cols] << (8*b)
                    except:
                        pass # should happen only for short (<num_cols) lines
                if verbose > 1:
                    print("%08x "%(data), end = "")
                self.x393_mem.write_mem(line_start + scol4,data)
            if verbose > 1:
                print()
# Hand buffer to FPGA   
            self.sync_for_device('H2D',GLBL_MEMBRIDGE_H2D_START, GLBL_MEMBRIDGE_H2D_END - GLBL_MEMBRIDGE_H2D_START) # command and PRD table

                
#run membridge write to video memory                
        self.x393Membridge.membridge_start ()         
# just wait done (default timeout = 10 sec)
        self.x393_axi_tasks.wait_status_condition ( # may also be read directly from the same bit of mctrl_linear_rw (address=5) status
            vrlg.MEMBRIDGE_STATUS_REG, # MCNTRL_TEST01_STATUS_REG_CHN3_ADDR,
            vrlg.MEMBRIDGE_ADDR +vrlg.MEMBRIDGE_STATUS_CNTRL, # MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN3_STATUS_CNTRL,
            vrlg.DEFAULT_STATUS_MODE,
            2 << vrlg.STATUS_2LSB_SHFT, # bit 24 - busy, bit 25 - frame done
            2 << vrlg.STATUS_2LSB_SHFT,  # mask for the 4-bit page number
            0, # equal to
            1); # synchronize sequence number
# setup compressor memory and mode
        self. setup_compressor(chn =            chn,
                               cmode =          cmode,
                               qbank =          qbank,
                               dc_sub =         True,
                               multi_frame =    False,
                               bayer =          bayer,
                               focus_mode =     0,
                               coring =         0,
                               window_width =   window_width, # 2592,   # 2592
                               window_height =  window_height, # 1944,   # 1944
                               window_left =    window_left, # 0,     # 0
                               window_top =     window_top, # 0, # 0? 1?
                               last_buf_frame = 0,  #  - just 2-frame buffer
                               colorsat_blue =  colorsat_blue, #0x120     # 0x90 for 1x
                               colorsat_red =   colorsat_red, #0x16c,     # 0xb6 for x1
                               verbose =        verbose)
        self.specify_window (window_width =  window_width,
                             window_height = window_height,
                             window_left =   window_left,
                             window_top =    window_top,
                             cmode =         cmode,
                             bayer =         bayer,
#                             colorsat_blue = colorsat_blue, # colorsat_blue, #0x120     # 0x90 for 1x
#                             colorsat_red =  colorsat_red, # colorsat_red, #0x16c,     # 0xb6 for x1
                             verbose =       verbose)
#Setup afi_mux for only one (this) channel, others will be disabled
        afi_cmprs0_sa = GLBL_CIRCBUF_STARTS[0] // 32  
        afi_cmprs1_sa = GLBL_CIRCBUF_STARTS[1] // 32
        afi_cmprs2_sa = GLBL_CIRCBUF_STARTS[2] // 32
        afi_cmprs3_sa = GLBL_CIRCBUF_STARTS[3] // 32
        afi_cmprs0_len = (GLBL_CIRCBUF_ENDS[0] - GLBL_CIRCBUF_STARTS[0]) // 32  
        afi_cmprs1_len = (GLBL_CIRCBUF_ENDS[1] - GLBL_CIRCBUF_STARTS[1]) // 32
        afi_cmprs2_len = (GLBL_CIRCBUF_ENDS[2] - GLBL_CIRCBUF_STARTS[2]) // 32
        afi_cmprs3_len = (GLBL_CIRCBUF_ENDS[3] - GLBL_CIRCBUF_STARTS[3]) // 32

        self.x393CmprsAfi.afi_mux_setup (
                               port_afi =       0,
                               chn_mask =       1 << chn,
                               status_mode =    3, # = 3,
                                # mode == 0 - show EOF pointer, internal
                                # mode == 1 - show EOF pointer, confirmed written to the system memory
                                # mode == 2 - show current pointer, internal
                                # mode == 3 - show current pointer, confirmed written to the system memory
                               report_mode =    0, # = 0,
                               afi_cmprs0_sa =  afi_cmprs0_sa,
                               afi_cmprs0_len = afi_cmprs0_len,
                               afi_cmprs1_sa =  afi_cmprs1_sa,
                               afi_cmprs1_len = afi_cmprs1_len,
                               afi_cmprs2_sa =  afi_cmprs2_sa,
                               afi_cmprs2_len = afi_cmprs2_len,
                               afi_cmprs3_sa =  afi_cmprs3_sa,
                               afi_cmprs3_len = afi_cmprs3_len)
# Hand CIRCBUF to FPGA   
        self.sync_for_device('D2H',GLBL_CIRCBUF_STARTS[chn], GLBL_CIRCBUF_ENDS[chn] - GLBL_CIRCBUF_STARTS[chn])
        
        
#        self.x393Cmprs.compressor_control(chn =  chn,
#                                          run_mode = 2) # 2: run single from memory
        print ('Use the next commands')
        print ('compressor_control %d 2'%(chn))
        print ('sync_for_cpu "D2H" 0x%x 0x%x'%(GLBL_CIRCBUF_STARTS[chn], GLBL_CIRCBUF_ENDS[chn] - GLBL_CIRCBUF_STARTS[chn]))
        print ('jpeg_write "img.jpeg" %d\n to make jpeg from simulated data'%(chn))
