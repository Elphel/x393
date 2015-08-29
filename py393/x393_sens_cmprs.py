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

#import time
import vrlg
SI5338_PATH =   "/sys/devices/amba.0/e0004000.ps7-i2c/i2c-0/0-0070"
POWER393_PATH = "/sys/devices/elphel393-pwr.1"
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
    def setSensorClock(self, freq_MHz = 24.0):
        """
        Set up external clock for sensor-synchronous circuitry (and sensor(s) themselves. 
        Currently required clock frequency is 1/4 of the sensor clock, so it is 24MHz for 96MHz sensor
        @param freq_MHz - input clock frequency (MHz). Currently for 96MHZ sensor clock it should be 24.0 
        """
        with open ( SI5338_PATH + "/output_drivers/2V5_LVDS",      "w") as f:
            print("1", file = f)
        with open ( SI5338_PATH + "/output_clocks/out1_freq_fract","w") as f:
            print("%d"%(round(1000000*freq_MHz)), file = f )
    def setSensorPower(self, sub_pair=0, power_on=0):
        """
        @param sub_pair - pair of the sensors: 0 - sensors 1 and 2, 1 - sensors 3 and 4 
        @param power_on - 1 - power on, 0 - power off (both sensor power and interface/FPGA bank voltage) 
        """
        with open (POWER393_PATH + "/channels_"+ ("dis","en")[power_on],"w") as f:
            print(("vcc_sens01 vp33sens01", "vcc_sens23 vp33sens23")[sub_pair], file = f)

    def setup_sensor_channel (self,
                              num_sensor,
                              frame_full_width, # 13-bit Padded line length (8-row increment), in 8-bursts (16 bytes)
                              window_width,    # 13 bit - in 8*16=128 bit bursts
                              window_height,   # 16 bit
                              window_left,
                              window_top,
                              frame_start_address,
                              frame_start_address_inc,
                              last_buf_frame,
                              colorsat_blue,
                              colorsat_red,
                              clk_sel,
                              histogram_start_phys_page,
                              histogram_left =      0,
                              histogram_top =       0,
                              histogram_width_m1 =  0,
                              histogram_height_m1 = 0,
                              
                              verbose = 1):
        """
        Setup one sensor+compressor channel (for one sub-channel only)
        @param num_sensor - sensor port number (0..3)
        @param frame_full_width -  13-bit Padded line length (8-row increment), in 8-bursts (16 bytes)
        @param window_width -      (here - in pixels)
        @param window_height -     16-bit window height in scan lines
        @param window_left -       left margin of the window (here - in pixels)
        @param window_top -        top margin of the window (16 bit)
        @param frame_start_address - 22-bit frame start address ((3 CA LSBs==0. BA==0)
        @param frame_start_address_inc - 22-bit frame start address increment  ((3 CA LSBs==0. BA==0)
        @param last_buf_frame) -   16-bit number of the last frame in a buffer
        @param colorsat_blue - color saturation for blue (10 bits), 0x90 for 100%
        @param colorsat_red -  color saturation for red (10 bits), 0xb6 for 100%
        @param clk_sel - True - use pixel clock from the sensor, False - use internal clock (provided to the sensor), None - no chnage
        @param histogram_start_phys_page - system memory 4K page number to start histogram
        @param histogram_left -      histogram window left margin
        @param histogram_top -       histogram window top margin
        @param histogram_width_m1 -  one less than window width. If 0 - use frame right margin (end of HACT)
        @param histogram_height_m1 - one less than window height. If 0 - use frame bottom margin (end of VACT)
        
        ???
        @parame verbose - verbose level 
        """
        if verbose >0 :
            print ("setup_sensor_channel:")
            print ("num_sensor =              ", num_sensor)
            print ("frame_full_width =        ", frame_full_width)
            print ("window_width =            ", window_width)
            print ("window_height =           ", window_height)
            print ("window_left =             ", window_left)
            print ("window_top =              ", window_top)
            print ("frame_start_address =     ", frame_start_address)
            print ("frame_start_address_inc = ", frame_start_address_inc)
            print ("last_buf_frame =          ", last_buf_frame)
            print ("verbose =                 ", verbose)
            
        self.x393Sensor.program_status_sensor_i2c(
            num_sensor = num_sensor,  # input [1:0] num_sensor;
            mode =       3,           # input [1:0] mode;
            seq_num =    0);          # input [5:0] seq_num;
        self.x393Sensor.program_status_sensor_io(
            num_sensor = num_sensor,  # input [1:0] num_sensor;
            mode =       3,           # input [1:0] mode;
            seq_num =    0);          # input [5:0] seq_num;

        self.x393Cmprs.program_status_compressor(
            num_sensor = num_sensor,  # input [1:0] num_sensor;
            mode =       3,           # input [1:0] mode;
            seq_num =    0);          # input [5:0] seq_num;

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
        self.x393_axi_tasks.enable_memcntrl_en_dis(8 + num_sensor, True);
        self.x393Cmprs.compressor_control(chn =  num_sensor,
                                          run_mode = 0) # reset compressor
        #TODO: Calculate from the image size?
        num_macro_cols_m1 = 3
        num_macro_rows_m1 = 1
        left_margin = 1
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
                                  left_margin =       left_margin,
                                  colorsat_blue =     colorsat_blue,
                                  colorsat_red =      colorsat_red,
                                  coring =            0,
                                  verbose =           verbose)
    # TODO: calculate widths correctly!
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
    
        self.x393Cmprs.compressor_control(
                       num_sensor = num_sensor,
                       run_mode =   3)  # run repetitive mode
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
        """
        if verbose >0 :
            print ("===================== I2C_TEST =========================")
        self.x393Sensor.test_i2c_353() # test soft/sequencer i2c
        """
        if verbose >0 :
            print ("===================== LENS_FLAT_SETUP =========================")
        self.x393Sensor.set_sensor_lens_flat_heights (self,
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

        self.x393Sensor.set_sensor_gamma_heights (self, 
                                  num_sensor = num_sensor,
                                  height0_m1 = 0xffff,
                                  height1_m1 = 0,
                                  height2_m1 = 0)
           
        # Configure histograms
        if verbose >0 :
            print ("===================== HISTOGRAMS_SETUP =========================")
        self.x393Sensor.set_sensor_histogram_window ( # 353 did it using command sequencer)
                                    num_sensor =     num_sensor,
                                    num_sub_sensor = 0,
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

        if verbose >0 :
            print ("===================== GAMMA_CTL =========================")
        self.x393Sensor.set_sensor_gamma_ctl (# doing last to enable sesnor data when everything else is set up
            num_sensor = num_sensor, # input   [1:0] num_sensor; # sensor channel number (0..3)
            bayer =      0,
            table_page = 0,
            en_input =   True,
            repet_mode = True, #  Normal mode, single trigger - just for debugging  TODO: re-assign?
            trig = False)
        
 