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

import x393_utils

import time
import vrlg


PAGE_SIZE =           4096
SI5338_PATH =         '/sys/devices/amba.0/e0004000.ps7-i2c/i2c-0/0-0070'
POWER393_PATH =       '/sys/devices/elphel393-pwr.1'
MEM_PATH =            '/sys/devices/elphel393-mem.2/'
BUFFER_ASSRESS_NAME = 'buffer_address'
BUFFER_PAGES_NAME =   'buffer_pages'
BUFFER_ADDRESS =      None # in bytes
BUFFER_LEN =          None # in bytes

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
    
    def __init__(self, debug_mode=1,dry_mode=True, saveFileName=None):
        global BUFFER_ADDRESS, BUFFER_LEN
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
        
        try:
            self.verbose=vrlg.VERBOSE
        except:
            pass
        if dry_mode:
            BUFFER_ADDRESS=0x27900000
            BUFFER_LEN=    0x6400000
            print ("Running in simulated mode, using hard-coded addresses:")
        else:
            try:
                with open(MEM_PATH + BUFFER_ASSRESS_NAME) as sysfile:
                    BUFFER_ADDRESS = int(sysfile.read(),0)
                with open(MEM_PATH + BUFFER_PAGES_NAME) as sysfile:
                    BUFFER_LEN = PAGE_SIZE * int(sysfile.read(),0)
            except:
                print("Failed to get reserved physical memory range")
                print('BUFFER_ADDRESS=', BUFFER_ADDRESS)    
                print('BUFFER_LEN=', BUFFER_LEN)    
                return
        print('X393SensCmprs: BUFFER_ADDRESS=0x%x'%(BUFFER_ADDRESS))    
        print('X393SensCmprs: BUFFER_LEN=0x%x'%(BUFFER_LEN))
    def get_histogram_byte_start(self): # should be 4KB page aligned
        global BUFFER_ADDRESS
        return BUFFER_ADDRESS
    def get_circbuf_byte_start(self): # should be 4KB page aligned
        global BUFFER_ADDRESS
        return BUFFER_ADDRESS + 16 * 4096
    def get_circbuf_byte_end(self): # should be 4KB page aligned
        global BUFFER_ADDRESS, BUFFER_LEN
        return BUFFER_ADDRESS + BUFFER_LEN
        
    def setSensorClock(self, freq_MHz = 24.0):
        """
        Set up external clock for sensor-synchronous circuitry (and sensor(s) themselves. 
        Currently required clock frequency is 1/4 of the sensor clock, so it is 24MHz for 96MHz sensor
        @param freq_MHz - input clock frequency (MHz). Currently for 96MHZ sensor clock it should be 24.0 
        """
        with open ( SI5338_PATH + "/output_drivers/2V5_LVDS",      "w") as f:
            print("2", file = f)
        with open ( SI5338_PATH + "/output_clocks/out2_freq_fract","w") as f:
            print("%d"%(round(1000000*freq_MHz)), file = f )
    def setSensorPower(self, sub_pair=0, power_on=0):
        """
        @param sub_pair - pair of the sensors: 0 - sensors 1 and 2, 1 - sensors 3 and 4 
        @param power_on - 1 - power on, 0 - power off (both sensor power and interface/FPGA bank voltage) 
        """
        with open (POWER393_PATH + "/channels_"+ ("dis","en")[power_on],"w") as f:
            print(("vcc_sens01 vp33sens01", "vcc_sens23 vp33sens23")[sub_pair], file = f)

    def setup_sensor_channel (self,
                              exit_step =                 None,
                              num_sensor =                0,
#                              histogram_start_phys_page, # Calculate from?
#                              frame_full_width, # 13-bit Padded line length (8-row increment), in 8-bursts (16 bytes)
                              window_width =              2592,   # 2592
                              window_height =             1944,   # 1944
                              window_left =               0,     # 0
                              window_top =                0, # 0? 1?
                              compressor_left_margin =    0, #0?`1? 
#                              frame_start_address, # calculate through num_sensor, num frames, frame size and start addr?
#                              frame_start_address_inc,
                              last_buf_frame =            1,  #  - just 2-frame buffer
                              colorsat_blue =             0x180,     # 0x90 fo 1x
                              colorsat_red =              0x16c,     # 0xb6 for x1
                              clk_sel =                   1,         # 1
                              histogram_left =            0,
                              histogram_top =             0,
                              histogram_width_m1 =        2559, #0,
                              histogram_height_m1 =       1935, #0,
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
        @param compressor_left_margin - 0..31 - left margin for compressor (to the nearest 32-byte column)
        @param last_buf_frame) -   16-bit number of the last frame in a buffer
        @param colorsat_blue - color saturation for blue (10 bits), 0x90 for 100%
        @param colorsat_red -  color saturation for red (10 bits), 0xb6 for 100%
        @param clk_sel - True - use pixel clock from the sensor, False - use internal clock (provided to the sensor), None - no chnage
        @param histogram_left -      histogram window left margin
        @param histogram_top -       histogram window top margin
        @param histogram_width_m1 -  one less than window width. If 0 - use frame right margin (end of HACT)
        @param histogram_height_m1 - one less than window height. If 0 - use frame bottom margin (end of VACT)
        
        ???
        @parame verbose - verbose level
        @return True if all done, False if exited prematurely through exit_step
        """
        align_to_bursts = 64 # align full width to multiple of align_to_bursts. 64 is the size of memory access
        width_in_bursts = window_width >> 4
        if (window_width & 0xf):
            width_in_bursts += 1
            
        num_burst_in_line = (window_left >> 4) + width_in_bursts
        num_pages_in_line = num_burst_in_line // align_to_bursts;
        if num_burst_in_line % align_to_bursts:
            num_pages_in_line += 1
#        frame_full_width -  13-bit Padded line length (8-row increment), in 8-bursts (16 bytes)
#        frame_start_address_inc - 22-bit frame start address increment  ((3 CA LSBs==0. BA==0)
        frame_full_width =  num_pages_in_line * align_to_bursts
        num8rows=   (window_top + window_height) // 8
        if (window_top + window_height) % 8:
            num8rows += 1
        frame_start_address_inc = num8rows * frame_full_width
        """ TODO: Calculate tiles and mov e to initial print """
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
            window_width =     window_width >> 4,        # input [31:0] window_width;     # 13 bit - in 8*16=128 bit bursts
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
                                  num_sensor = num_sensor,
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

        self.x393Cmprs.setup_compressor_memory (
            num_sensor =       num_sensor,
            frame_sa =         frame_start_address,     # input [31:0] frame_sa;         # 22-bit frame start address ((3 CA LSBs==0. BA==0)
            frame_sa_inc =     frame_start_address_inc, # input [31:0] frame_sa_inc;     # 22-bit frame start address increment  ((3 CA LSBs==0. BA==0)
            last_frame_num =   last_buf_frame,          # input [31:0] last_frame_num;   # 16-bit number of the last frame in a buffer
            frame_full_width = frame_full_width,        # input [31:0] frame_full_width; # 13-bit Padded line length (8-row increment), in 8-bursts (16 bytes)
            window_width =     window_width >> 4,       # input [31:0] window_width;     # 13 bit - in 8*16=128 bit bursts
            window_height =    window_height,           # input [31:0] window_height;    # 16 bit
            window_left =      window_left >> 4,        # input [31:0] window_left;
            window_top =       window_top,              # input [31:0] window_top;
            byte32 =           1,
            tile_width =       2,
            extra_pages =      1,
            disable_need =     1)

        if exit_step == 15: return False
    
        self.x393Cmprs.compressor_control(
                       chn = num_sensor,
                       run_mode =   3)  # run repetitive mode

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
                                         C =  0, # 0x8000
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
                                    page = histogram_start_phys_page)
            
        self.x393Sensor.set_sensor_histogram_saxi (
                                   en = True,
                                   nrst = True,
                                   confirm_write = True,
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
        self.x393Sensor.set_sensor_gamma_ctl (# doing last to enable sesnor data when everything else is set up
            num_sensor = num_sensor, # input   [1:0] num_sensor; # sensor channel number (0..3)
            bayer =      0,
            table_page = 0,
            en_input =   True,
            repet_mode = True, #  Normal mode, single trigger - just for debugging  TODO: re-assign?
            trig = False)
        return True
    def setup_all_sensors (self,
                              exit_step =                 None,
                              sensor_mask =               0x1, # channel 0 only
                              gamma_load =                False,
#                              histogram_start_phys_page, # Calculate from?
#                              frame_full_width, # 13-bit Padded line length (8-row increment), in 8-bursts (16 bytes)
                              window_width =              2592,   # 2592
                              window_height =             1944,   # 1944
                              window_left =               0,     # 0
                              window_top =                0, # 0? 1?
                              compressor_left_margin =    0, #0?`1? 
#                              frame_start_address, # calculate through num_sensor, num frames, frame size and start addr?
#                              frame_start_address_inc,
                              last_buf_frame =            1,  #  - just 2-frame buffer
                              colorsat_blue =             0x180,     # 0x90 fo 1x
                              colorsat_red =              0x16c,     # 0xb6 for x1
                              clk_sel =                   1,         # 1
                              histogram_left =            0,
                              histogram_top =             0,
                              histogram_width_m1 =        2559, #0,
                              histogram_height_m1 =       799, #0,
                              circbuf_chn_size=           0x1000000, #16777216
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
        @param clk_sel - True - use pixel clock from the sensor, False - use internal clock (provided to the sensor), None - no chnage
        @param histogram_left -      histogram window left margin
        @param histogram_top -       histogram window top margin
        @param histogram_width_m1 -  one less than window width. If 0 - use frame right margin (end of HACT)
        @param histogram_height_m1 - one less than window height. If 0 - use frame bottom margin (end of VACT)
        @param circbuf_chn_size - circular buffer size for each channel, in bytes
        @parame verbose - verbose level
        @return True if all done, False if exited prematurely by  exit_step
        """
#    camsync_setup (
#        4'hf ); # sensor_mask); #
        circbuf_start = self.get_circbuf_byte_start()
        mem_end=        self.get_circbuf_byte_end()
#circbuf_chn_size
        circbuf_starts=[]
        for i in range(16):
            circbuf_starts.append(circbuf_start + i*circbuf_chn_size)
        circbuf_end = circbuf_start + 4*circbuf_chn_size

    #TODO: calculate addersses/lengths
        afi_cmprs0_sa = circbuf_starts[0] // 4  
        afi_cmprs1_sa = circbuf_starts[1] // 4
        afi_cmprs2_sa = circbuf_starts[2] // 4
        afi_cmprs3_sa = circbuf_starts[3] // 4
        afi_cmprs_len = circbuf_chn_size  // 4    
        if verbose >0 :
            print ("compressor system memory buffers:")
            print ("circbuf start 0 =           0x%x"%(circbuf_starts[0]))
            print ("circbuf start 1 =           0x%x"%(circbuf_starts[1]))
            print ("circbuf start 2 =           0x%x"%(circbuf_starts[2]))
            print ("circbuf start 3 =           0x%x"%(circbuf_starts[3]))
            print ("circbuf end =               0x%x"%(circbuf_end))
            print ("memory buffer end =         0x%x"%(mem_end))
        
        if sensor_mask & 3: # Need mower for sesns1 and sens 2
            if verbose >0 :
                print ("===================== Sensor power setup: sensor ports 0 and 1 =========================")
            self.setSensorPower(sub_pair=0, power_on=1)
        if sensor_mask & 0xc: # Need mower for sesns1 and sens 2
            if verbose >0 :
                print ("===================== Sensor power setup: sensor ports 2 and 3 =========================")
            self.setSensorPower(sub_pair=1, power_on=1)
        if verbose >0 :
            print ("===================== Sensor clock setup 24MHz (will output 96MHz) =========================")
        self.setSensorClock(freq_MHz = 24.0)
        if exit_step == 1: return False
        if verbose >0 :
            print ("===================== GPIO_SETUP =========================")
            
        self.x393GPIO.program_status_gpio (
                                       mode =    3,   # input [1:0] mode;
                                       seq_num = 0)   # input [5:0] seq_num;

        if exit_step == 2: return False
        if verbose >0 :
            print ("===================== RTC_SETUP =========================")
        self.x393Rtc.program_status_rtc( # also takes snapshot
                                     mode =    1, # 3,     # input [1:0] mode;
                                     seq_num = 0)     #input [5:0] seq_num;
            
        self.x393Rtc.set_rtc () # no correction, use current system time
        if exit_step == 3: return False
        

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
                rslt = self.setup_sensor_channel (
                          exit_step =               exit_step,      # 10 .. 19
                          num_sensor =              num_sensor,
                          window_width =            window_width,   # 2592
                          window_height =           window_height,   # 1944
                          window_left =             window_left,     # 0
                          window_top =              window_top, # 0? 1?
                          compressor_left_margin =  compressor_left_margin, #0?`1? 
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
                self.x393Sensor.print_status_sensor_io (num_sensor = num_sensor)
                self.x393Sensor.print_status_sensor_i2c (num_sensor = num_sensor)
                
                self.x393Sensor.set_sensor_i2c_command (
                                num_sensor = num_sensor,
                                rst_cmd =   True)
                self.x393Sensor.set_sensor_i2c_command (
                                num_sensor = num_sensor,
                                num_bytes = 3,
                                dly =       100, # ??None,
                                scl_ctl =   None, 
                                sda_ctl =   None)
                self.x393Sensor.set_sensor_i2c_command (
                                num_sensor = num_sensor,
                                rst_cmd =   False)

                self.x393Sensor.set_sensor_i2c_command (
                                num_sensor = num_sensor,
                                run_cmd =   True)

        if exit_step == 21: return False

        self.x393Camsync.camsync_setup (
                     sensor_mask =        sensor_mask,
                      trigger_mode =       False, #False - async (free running) sensor mode, True - triggered (global reset) sensor mode
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
