from __future__ import division
from __future__ import print_function

'''
# Copyright (C) 2015, Elphel.inc.
# Class to control 10393 sensor-to-memory channel (including histograms)  
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

import x393_utils

#import time
import vrlg
import x393_mcntrl
class X393Sensor(object):
    DRY_MODE= True # True
    DEBUG_MODE=1
    x393_mem=None
    x393_axi_tasks=None #x393X393AxiControlStatus
    x393_utils=None
    verbose=1
    def __init__(self, debug_mode=1,dry_mode=True, saveFileName=None):
        self.DEBUG_MODE=  debug_mode
        self.DRY_MODE=    dry_mode
        self.x393_mem=            X393Mem(debug_mode,dry_mode)
        self.x393_axi_tasks=      x393_axi_control_status.X393AxiControlStatus(debug_mode,dry_mode)
        self.x393_utils=          x393_utils.X393Utils(debug_mode,dry_mode, saveFileName) # should not overwrite save file path
        try:
            self.verbose=vrlg.VERBOSE
        except:
            pass
    def program_status_sensor_i2c( self,
                                   num_sensor,
                                   mode,     # input [1:0] mode;
                                   seq_num): # input [5:0] seq_num;
        """
        Set status generation mode for selected sensor port i2c control
        @param num_sensor - number of the sensor port (0..3)
        @param mode -       status generation mode:
                                  0: disable status generation,
                                  1: single status request,
                                  2: auto status, keep specified seq number,
                                  4: auto, inc sequence number 
        @param seq_number - 6-bit sequence number of the status message to be sent
        """

        self.program_status (vrlg.SENSOR_GROUP_ADDR  + num_sensor * vrlg.SENSOR_BASE_INC + vrlg.SENSI2C_CTRL_RADDR,
                             vrlg.SENSI2C_STATUS,
                             mode,
                             seq_num)# //MCONTR_PHY_STATUS_REG_ADDR=          'h0,

    def program_status_sensor_io( self,
                                  num_sensor,
                                  mode,     # input [1:0] mode;
                                  seq_num): # input [5:0] seq_num;
        """
        Set status generation mode for selected sensor port io subsystem
        @param num_sensor - number of the sensor port (0..3)
        @param mode -       status generation mode:
                                  0: disable status generation,
                                  1: single status request,
                                  2: auto status, keep specified seq number,
                                  4: auto, inc sequence number 
        @param seq_number - 6-bit sequence number of the status message to be sent
        """

        self.x393_axi_tasks.program_status (
                             vrlg.SENSOR_GROUP_ADDR  + num_sensor * vrlg.SENSOR_BASE_INC + vrlg.SENSIO_RADDR,
                             vrlg.SENSIO_STATUS,
                             mode,
                             seq_num)# //MCONTR_PHY_STATUS_REG_ADDR=          'h0,

# Functions used by sensor-related tasks
    def func_sensor_mode (self,
                          hist_en,
                          hist_nrst, 
                          chn_en, 
                          bits16):
        """
        Combine parameters into sensor mode control word
        @param hist_en -   bit mask to enable histogram sub-modules, when 0 - disable after processing
                           the started frame
        @param hist_nrst - bit mask to immediately reset histogram sub-module (if 0) 
        @param chn_en    - enable sensor channel (False - reset) 
        @param bits16)   - True - 16 bpp mode, false - 8 bpp mode (bypass gamma). Gamma-processed data
                           is still used for histograms
        @return: sensor mode control word
        """
        rslt = 0;
        rslt |= (hist_en & 0xf) <<   vrlg.SENSOR_HIST_EN_BITS
        rslt |= (hist_nrst & 0xf) << vrlg.SENSOR_HIST_NRST_BITS
        rslt |= ((0,1)[chn_en]) <<   vrlg.SENSOR_CHN_EN_BIT
        rslt |= ((0,1)[bits16]) <<   vrlg.SENSOR_16BIT_BIT
        return rslt
    
    def func_sensor_i2c_command (self,
                                 rst_cmd =   False,
                                 run_cmd =   None,
                                 num_bytes = None,
                                 dly =       None,
                                 scl_ctl =   None, 
                                 sda_ctl =   None):
        """
        @param rst_cmd - reset all FIFO (takes 16 clock pulses), also - stops i2c until run command
        @param run_cmd - True - run i2c, False - stop i2c (needed before software i2c), None - no change
        @param num_bytes - set number of i2c bytes after slave address  (0..3), None - no change
        @param dly - set duration of quarter i2c cycle (if 0, [3:0] control SCL+SDA??? obsolete)
        @param scl_ctl - directly control SCL line: None - NOP, 'Z' - high Z, 0/False/'L' - low level,
                         1/True/'H' - high level 
        @param sda_ctl - directly control SDA line: None - NOP, 'Z' - high Z, 0/False/'L' - low level,
                         1/True/'H' - high level
        @return: i2c control word
        """  
        rslt = 0
        rslt |= (0,1)[rst_cmd] << vrlg.SENSI2C_CMD_RESET
        if not run_cmd is None:
            rslt |= 1 <<                 vrlg.SENSI2C_CMD_RUN
            rslt |= (0,1)[run_cmd] <<    (vrlg.SENSI2C_CMD_RUN - vrlg.SENSI2C_CMD_RUN_PBITS)
        if not num_bytes is None:
            num_bytes &= (1 << vrlg.SENSI2C_CMD_BYTES_PBITS) -1
            rslt |= 1 <<          vrlg.SENSI2C_CMD_BYTES
            rslt |= num_bytes << (vrlg.SENSI2C_CMD_BYTES - vrlg.SENSI2C_CMD_BYTES_PBITS)
        if not dly is None:
            dly &= (1 <<    vrlg.SENSI2C_CMD_BYTES_PBITS) -1
            rslt |= 1 <<    vrlg.SENSI2C_CMD_BYTES            
            rslt |= dly << (vrlg.SENSI2C_CMD_BYTES - vrlg.SENSI2C_CMD_BYTES_PBITS)
        scl=0
        if not scl_ctl is None:
            if   (scl_ctl is False) or (scl_ctl == 0) or (scl_ctl == "0") or (scl_ctl.upper() == "L"):
                scl = 1
            elif (scl_ctl is True) or  (scl_ctl == 1) or (scl_ctl == "1") or (scl_ctl.upper() == "H"):   
                scl = 2
            elif scl_ctl.upper() == "Z":   
                scl = 3
        rslt |= scl << vrlg.SENSI2C_CMD_SCL        
              
        sda=0
        if not sda_ctl is None:
            if   (sda_ctl is False) or (sda_ctl == 0) or (sda_ctl == "0") or (sda_ctl.upper() == "L"):
                sda = 1
            elif (sda_ctl is True) or  (sda_ctl == 1) or (sda_ctl == "1") or (sda_ctl.upper() == "H"):   
                sda = 2
            elif sda_ctl.upper() == "Z":   
                sda = 3
        rslt |= sda << vrlg.SENSI2C_CMD_SDA
        return rslt        

    def func_sensor_io_ctl (self,
                            mrst = None,
                            arst = None,
                            aro  = None,
                            mmcm_rst = None,
                            clk_sel = None,
                            set_delays = False,
                            quadrants = None):
        """
        Combine sensor I/O control parameters into a control word 
        @param mrst -  True - activate MRST signal (low), False - deactivate MRST (high), None - no change
        @param arst -  True - activate ARST signal (low), False - deactivate ARST (high), None - no change
        @param aro -   True - activate ARO signal (low), False - deactivate ARO (high), None - no change
        @param mmcm_rst - True - activate MMCM reset, False - deactivate MMCM reset, None - no change (needed after clock change/interruption)
        @param clk_sel - True - use pixel clock from the sensor, False - use internal clock (provided to the sensor), None - no chnage
        @param set_delays - (self-clearing) load all pre-programmed delays for the sensor pad inputs 
        @param quadrants -  90-degree shifts for data [1:0], hact [3:2] and vact [5:4] (6'h01), None - no change
        @return sensor i/o control word
        """
        rslt = 0
        if not mrst is None:
            rslt |= (2,3)[mrst] <<     vrlg.SENS_CTRL_MRST
        if not arst is None:
            rslt |= (2,3)[arst] <<     vrlg.SENS_CTRL_ARST
        if not aro is None:
            rslt |= (2,3)[aro]  <<     vrlg.SENS_CTRL_ARO
        if not mmcm_rst is None:
            rslt |= (2,3)[mmcm_rst] << vrlg.SENS_CTRL_RST_MMCM
        if not clk_sel is None:
            rslt |= (2,3)[clk_sel] <<  vrlg.SENS_CTRL_EXT_CLK
        rslt |= (0,1)[set_delays] <<   vrlg.SENS_CTRL_LD_DLY

        if not quadrants is None:
            rslt |= 1 <<  vrlg.SENS_CTRL_QUADRANTS_EN
            rslt |= (quadrants & ((1 << vrlg.SENS_CTRL_QUADRANTS_WIDTH) - 1)) <<  vrlg.SENS_CTRL_QUADRANTS
        return rslt

    def func_sensor_jtag_ctl(self,
                             pgmen = None,    # <2: keep PGMEN, 2 - PGMEN low (inactive),  3 - high (active) enable JTAG control
                             prog =  None,    # <2: keep prog, 2 - prog low (active),  3 - high (inactive) ("program" pin control)
                             tck =   None,    # <2: keep TCK,  2 - set TCK low,  3 - set TCK high
                             tms =   None,    # <2: keep TMS,  2 - set TMS low,  3 - set TMS high
                             tdi =   None):   # <2: keep TDI,  2 - set TDI low,  3 - set TDI high
        """
        JTAG interface for programming external sensor multiplexer using shared signal lines on the sensor ports
        @param pgmen - False PGMEN low (inactive),  True - high (active) enable JTAG control, None - keep previous value
        @param prog -  False prog low (active),  True - high (inactive) ("program" pin control), None - keep previous value
        @param tck =   False - set TCK low,  True - set TCK high, None - keep previous value
        @param tms =   False - set TMS low,  True - set TMS high, None - keep previous value
        @param tdi =   False - set TDI low,  True - set TDI high, None - keep previous value
        @return combined control word       
        """
        rslt = 0
        if not pgmen is None:
            rslt |= (2,3)[pgmen] << vrlg.SENS_JTAG_PGMEN
        if not prog is None:
            rslt |= (2,3)[prog] <<  vrlg.SENS_JTAG_PROG
        if not tck is None:
            rslt |= (2,3)[tck] <<   vrlg.SENS_JTAG_TCK
        if not tms is None:
            rslt |= (2,3)[tms] <<   vrlg.SENS_JTAG_TMS
        if not tdi is None:
            rslt |= (2,3)[tdi] <<   vrlg.SENS_JTAG_TDI
        return rslt

    def func_sensor_gamma_ctl(self,
                              bayer =      0,
                              table_page = 0,
                              en_input =   True,
                              repet_mode = True, #  Normal mode, single trigger - just for debugging  TODO: re-assign?
                              trig = False):
        """
        @param bayer - Bayer shift (0..3)
        @param table_page - Gamma table page
        @param en_input -   Enable input
        @param repet_mode - Repetitive (normal) mode. Set False for debugging, then use trig for single frame trigger
        @param trig       - single trigger (when repet_mode is False), debug feature
        @return combined control word
        """
        rslt = 0
        rslt |= (bayer & 3) <<       vrlg.SENS_GAMMA_MODE_BAYER
        rslt |= (0,1)[table_page] << vrlg.SENS_GAMMA_MODE_PAGE
        rslt |= (0,1)[en_input] <<   vrlg.SENS_GAMMA_MODE_EN
        rslt |= (0,1)[repet_mode] << vrlg.SENS_GAMMA_MODE_REPET
        rslt |= (0,1)[trig] <<       vrlg.SENS_GAMMA_MODE_TRIG
        return rslt

    def func_status_addr_sensor_i2c(self,
                                    num_sensor):
        """
        @param num_sensor - sensor port number (0..3)
        @return status register address for i2c for selected sensor port
        """
        return (vrlg.SENSI2C_STATUS_REG_BASE + num_sensor * vrlg.SENSI2C_STATUS_REG_INC + vrlg.SENSI2C_STATUS_REG_REL);

    def func_status_addr_sensor_io(self,
                                    num_sensor):
        """
        @param num_sensor - sensor port number (0..3)
        @return status register address for I/O for selected sensor port
        """
        return (vrlg.SENSI2C_STATUS_REG_BASE + num_sensor * vrlg.SENSI2C_STATUS_REG_INC + vrlg.SENSIO_STATUS_REG_REL);
    
    def set_sensor_mode (self,
                         num_sensor,
                         hist_en,
                         hist_nrst, 
                         chn_en, 
                         bits16):
        """
        Set sensor mode
        @param num_sensor - sensor port number (0..3)
        @param hist_en -   bit mask to enable histogram sub-modules, when 0 - disable after processing
                           the started frame
        @param hist_nrst - bit mask to immediately reset histogram sub-module (if 0) 
        @param chn_en    - enable sensor channel (False - reset) 
        @param bits16)   - True - 16 bpp mode, false - 8 bpp mode (bypass gamma). Gamma-processed data
                           is still used for histograms
        """
        self.x393_axi_tasks.write_contol_register(vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC + vrlg.SENSOR_CTRL_RADDR,
                                                  self.func_sensor_mode(
                                                                   hist_en =   hist_en,
                                                                   hist_nrst = hist_nrst,
                                                                   chn_en =    chn_en,
                                                                   bits16 =    bits16))

    def set_sensor_i2c_command (self,
                                num_sensor,
                                rst_cmd =   False,
                                run_cmd =   None,
                                num_bytes = None,
                                dly =       None,
                                scl_ctl =   None, 
                                sda_ctl =   None):
        """
        @param rst_cmd - reset all FIFO (takes 16 clock pulses), also - stops i2c until run command
        @param run_cmd - True - run i2c, False - stop i2c (needed before software i2c), None - no change
        @param num_bytes - set number of i2c bytes after slave address  (0..3), None - no change
        @param dly - set duration of quarter i2c cycle (if 0, [3:0] control SCL+SDA??? obsolete)
        @param scl_ctl - directly control SCL line: None - NOP, 'Z' - high Z, 0/False/'L' - low level,
                         1/True/'H' - high level 
        @param sda_ctl - directly control SDA line: None - NOP, 'Z' - high Z, 0/False/'L' - low level,
                         1/True/'H' - high level
        @return: i2c control word
        """  
        self.x393_axi_tasks.write_contol_register(vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC + vrlg.SENSI2C_CTRL_RADDR,
                                                  self.func_sensor_i2c_command(
                                                       rst_cmd =   rst_cmd,
                                                       run_cmd =   run_cmd,
                                                       num_bytes = num_bytes,
                                                       dly =       dly,
                                                       scl_ctl =   scl_ctl, 
                                                       sda_ctl =   sda_ctl))

    def write_sensor_i2c (self,
                          num_sensor,
                          rel_addr,
                          addr,
                          data):
        """
        Write i2c command to the i2c command sequencer
        @param num_sensor - sensor port number (0..3)
        @param rel_addr - True - relative frame address, False - absolute frame address
        @param addr - frame address (0..15)
        @param data - Combine slave address/register address/ register data for the i2c command
        """
        reg_addr =  (vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC)
        reg_addr += ((vrlg.SENSI2C_ABS_RADDR,vrlg.SENSI2C_REL_RADDR)[rel_addr] )
        reg_addr += (addr & ~vrlg.SENSI2C_ADDR_MASK);
        self.x393_axi_tasks.write_contol_register(reg_addr, data)
        
    def set_sensor_io_ctl (self,
                           num_sensor,
                           mrst = None,
                           arst = None,
                           aro  = None,
                           mmcm_rst = None,
                           clk_sel = None,
                           set_delays = False,
                           quadrants = None):
        """
        Set sensor I/O controls, including I/O signals 
        @param num_sensor - sensor port number (0..3)
        @param mrst -  True - activate MRST signal (low), False - deactivate MRST (high), None - no change
        @param arst -  True - activate ARST signal (low), False - deactivate ARST (high), None - no change
        @param aro -   True - activate ARO signal (low), False - deactivate ARO (high), None - no change
        @param mmcm_rst - True - activate MMCM reset, False - deactivate MMCM reset, None - no change (needed after clock change/interruption)
        @param clk_sel - True - use pixel clock from the sensor, False - use internal clock (provided to the sensor), None - no chnage
        @param set_delays - (self-clearing) load all pre-programmed delays for the sensor pad inputs 
        @param quadrants -  90-degree shifts for data [1:0], hact [3:2] and vact [5:4] (6'h01), None - no change
        """
        data = self.func_sensor_io_ctl (
                    mrst =       mrst,
                    arst =       arst,
                    aro =        aro,
                    mmcm_rst =   mmcm_rst,
                    clk_sel =    clk_sel,
                    set_delays = set_delays,
                    quadrants =  quadrants)
        reg_addr = (vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC) + vrlg.SENSIO_RADDR + vrlg.SENSIO_CTRL;
        self.x393_axi_tasks.write_contol_register(reg_addr, data)

    def set_sensor_io_dly (self,
                           num_sensor,
                           mmcm_phase,
                           iclk_dly,
                           vact_dly,
                           hact_dly,
                           pxd_dly):
        """
        Set sensor port input delays and mmcm phase
        @param num_sensor - sensor port number (0..3)
        @param mmcm_phase - MMCM clock phase
        @param iclk_dly - delay in the input clock line (3 LSB are not used)
        @param vact_dly - delay in the VACT line (3 LSB are not used)
        @param hact_dly - delay in the HACT line (3 LSB are not used)
        @param pxd_dly - list of data line delays (12 elements, 3 LSB are not used)                      
        """
        dlys=((pxd_dly[0] & 0xff) | ((pxd_dly[1] & 0xff) << 8) | ((pxd_dly[ 2] & 0xff) << 16) | ((pxd_dly[ 3] & 0xff) << 24),
              (pxd_dly[4] & 0xff) | ((pxd_dly[5] & 0xff) << 8) | ((pxd_dly[ 6] & 0xff) << 16) | ((pxd_dly[ 7] & 0xff) << 24),
              (pxd_dly[8] & 0xff) | ((pxd_dly[9] & 0xff) << 8) | ((pxd_dly[10] & 0xff) << 16) | ((pxd_dly[11] & 0xff) << 24),
              (hact_dly & 0xff) |   ((vact_dly & 0xff) <<   8) | ((iclk_dly & 0xff)    << 16) | ((mmcm_phase & 0xff) <<  24))                       
        reg_addr = (vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC) + vrlg.SENSIO_RADDR + vrlg.SENSIO_DELAYS;
        self.x393_axi_tasks.write_contol_register(reg_addr + 0, dlys[0]) # {pxd3,       pxd2,  pxd1, pxd0}
        self.x393_axi_tasks.write_contol_register(reg_addr + 1, dlys[1]) # {pxd7,       pxd6,  pxd5, pxd4}
        self.x393_axi_tasks.write_contol_register(reg_addr + 2, dlys[2]) # {pxd11,      pxd10, pxd9, pxd8}
        self.x393_axi_tasks.write_contol_register(reg_addr + 3, dlys[3]) # {mmcm_phase, bpf,   vact, hact}
        self.set_sensor_io_ctl (num_sensor = num_sensor,
                                set_delays = True)

    def set_sensor_io_jtag (self,
                            num_sensor,
                            pgmen = None,    # <2: keep PGMEN, 2 - PGMEN low (inactive),  3 - high (active) enable JTAG control
                            prog =  None,    # <2: keep prog, 2 - prog low (active),  3 - high (inactive) ("program" pin control)
                            tck =   None,    # <2: keep TCK,  2 - set TCK low,  3 - set TCK high
                            tms =   None,    # <2: keep TMS,  2 - set TMS low,  3 - set TMS high
                            tdi =   None):   # <2: keep TDI,  2 - set TDI low,  3 - set TDI high
        """
        JTAG interface for programming external sensor multiplexer using shared signal lines on the sensor ports
        @param num_sensor - sensor port number (0..3)
        @param pgmen - False PGMEN low (inactive),  True - high (active) enable JTAG control, None - keep previous value
        @param prog -  False prog low (active),  True - high (inactive) ("program" pin control), None - keep previous value
        @param tck =   False - set TCK low,  True - set TCK high, None - keep previous value
        @param tms =   False - set TMS low,  True - set TMS high, None - keep previous value
        @param tdi =   False - set TDI low,  True - set TDI high, None - keep previous value
        """
        reg_addr = (vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC) + vrlg.SENSIO_RADDR + vrlg.SENSIO_JTAG;
        data = self.func_sensor_jtag_ctl (
                            pgmen = pgmen,
                            prog =  prog,
                            tck =   tck,
                            tms =   tms,
                            tdi =   tdi)
        self.x393_axi_tasks.write_contol_register(reg_addr, data)

    def set_sensor_io_width (
                             self,
                             num_sensor,
                             width): # 0 - use HACT, >0 - generate HACT from start to specified width
        """
        Set sensor frame width
        @param num_sensor - sensor port number (0..3)
        @param width - sensor 16-bit frame width (0 - use sensor HACT signal) 
        """
        reg_addr = (vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC) + vrlg.SENSIO_RADDR + vrlg.SENSIO_WIDTH;
        self.x393_axi_tasks.write_contol_register(reg_addr, width)
 
    def set_sensor_lens_flat_heights (self,
                                      num_sensor,
                                      height0_m1 = None,
                                      height1_m1 = None,
                                      height2_m1 = None):
        """
        Set division of the composite frame into sub-frames for the vignetting correction module
        @param num_sensor - sensor port number (0..3)
        @param height0_m1 - height of the first sub-frame minus 1
        @param height1_m1 - height of the second sub-frame minus 1
        @param height2_m1 - height of the third sub-frame minus 1
        (No need for the  4-th, as it will just go until end of the composite frame)
        """
        reg_addr = (vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC) + vrlg.SENS_LENS_RADDR;
        if not height0_m1 is None:
            self.x393_axi_tasks.write_contol_register(reg_addr + 0, height0_m1)
        if not height1_m1 is None:
            self.x393_axi_tasks.write_contol_register(reg_addr + 1, height1_m1)
        if not height2_m1 is None:
            self.x393_axi_tasks.write_contol_register(reg_addr + 2, height2_m1)


    def set_sensor_lens_flat_parameters (self,
                                         num_sensor,
                                         num_sub_sensor,
# add mode "DIRECT", "ASAP", "RELATIVE", "ABSOLUTE" and frame number
                                         AX = None,
                                         AY = None,
                                         BX = None,
                                         BY = None,
                                         C = None,
                                         scales0 = None,
                                         scales1 = None,
                                         scales2 = None,
                                         scales3 = None,
                                         fatzero_in = None,
                                         fatzero_out = None,
                                         post_scale = None):
        """
        Program vignetting correction and per-color scale
        @param num_sensor -     sensor port number (0..3)
        @param num_sub_sensor - sub-sensor attached to the same port through multiplexer (0..3)
    TODO: add mode "DIRECT", "ASAP", "RELATIVE", "ABSOLUTE" and frame number for sequencer
        All the next parameters can be None - will not be set 
        @param AX (19 bits)
        @param AY (19 bits)
        @param BX (21 bits)
        @param BY (21 bits)
        @param C (19 bits)
        @param scales0 (17 bits) - color channel 0 scale
        @param scales1 (17 bits) - color channel 1 scale
        @param scales2 (17 bits) - color channel 2 scale
        @param scales3 (17 bits) - color channel 3 scale
        @param fatzero_in (16 bits)
        @param fatzero_out (16 bits)
        @param post_scale (4 bits) - shift of the result
        """
        def func_lens_data (self,
                        num_sensor,
                        addr,
                        data,
                        width):
            
            return ((num_sensor & 3) << 24) | ((addr & 0xff) << 16) | (data & ((1 << width) - 1))
        reg_addr = (vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC) + vrlg.SENS_LENS_RADDR + vrlg.SENS_LENS_COEFF
        if not AX is None:
            self.x393_axi_tasks.write_contol_register(reg_addr, func_lens_data(num_sub_sensor, vrlg.SENS_LENS_AX, AX, 19))
        if not AY is None:
            self.x393_axi_tasks.write_contol_register(reg_addr, func_lens_data(num_sub_sensor, vrlg.SENS_LENS_AY, AY, 19))
        if not BX is None:
            self.x393_axi_tasks.write_contol_register(reg_addr, func_lens_data(num_sub_sensor, vrlg.SENS_LENS_BX, BX, 21))
        if not BY is None:
            self.x393_axi_tasks.write_contol_register(reg_addr, func_lens_data(num_sub_sensor, vrlg.SENS_LENS_BY, BY, 21))
        if not C is None:
            self.x393_axi_tasks.write_contol_register(reg_addr, func_lens_data(num_sub_sensor, vrlg.SENS_LENS_C,   C, 19))
        if not scales0 is None:
            self.x393_axi_tasks.write_contol_register(reg_addr, func_lens_data(num_sub_sensor, vrlg.SENS_LENS_SCALES + 0,   scales0, 17))
        if not scales1 is None:
            self.x393_axi_tasks.write_contol_register(reg_addr, func_lens_data(num_sub_sensor, vrlg.SENS_LENS_SCALES + 2,   scales1, 17))
        if not scales2 is None:
            self.x393_axi_tasks.write_contol_register(reg_addr, func_lens_data(num_sub_sensor, vrlg.SENS_LENS_SCALES + 4,   scales2, 17))
        if not scales3 is None:
            self.x393_axi_tasks.write_contol_register(reg_addr, func_lens_data(num_sub_sensor, vrlg.SENS_LENS_SCALES + 6,   scales3, 17))
        if not fatzero_in is None:
            self.x393_axi_tasks.write_contol_register(reg_addr, func_lens_data(num_sub_sensor, vrlg.SENS_LENS_FAT0_IN, fatzero_in, 16))
        if not fatzero_out is None:
            self.x393_axi_tasks.write_contol_register(reg_addr, func_lens_data(num_sub_sensor, vrlg.SENS_LENS_FAT0_OUT, fatzero_out, 16))

        if not post_scale is None:
            self.x393_axi_tasks.write_contol_register(reg_addr, func_lens_data(num_sub_sensor, vrlg.SENS_LENS_POST_SCALE, post_scale, 4))

    def program_curves (self,
                        num_sensor,
                        sub_channel,
                        curves_data,
                        page = 0):
        """
        Program gamma tables for specified sensor port and subchannel
        @param num_sensor -     sensor port number (0..3)
        @param num_sub_sensor - sub-sensor attached to the same port through multiplexer (0..3)
        @param curves_data - either 1028-element list (257 per color component) or a file path
                             with the same data, same as for Verilog $readmemh
        @param page - gammma table page number (only used if SENS_GAMMA_BUFFER > 0
        """  
        def set_sensor_gamma_table_addr (
                                         num_sensor,
                                         sub_channel,
                                         color,
                                         page = 0): # only used if SENS_GAMMA_BUFFER != 0

            data =  (1 << 20) | ((color & 3) <<8)
            if (vrlg.SENS_GAMMA_BUFFER):
                data |= (sub_channel & 3) << 11 # [12:11]
                data |= page << 10
            else:
                data |= (sub_channel & 3) << 10 # [11:10]
            reg_addr = (vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC) + vrlg.SENS_GAMMA_RADDR + vrlg.SENS_GAMMA_ADDR_DATA
            self.x393_axi_tasks.write_contol_register(reg_addr, data)                   
        def set_sensor_gamma_table_data ( #; // need 256 for a single color data
                                          num_sensor,
                                          data18): # ; // 18-bit table data
            reg_addr = (vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC) + vrlg.SENS_GAMMA_RADDR + vrlg.SENS_GAMMA_ADDR_DATA;
            self.x393_axi_tasks.write_contol_register(reg_addr, data18 & ((1 << 18) - 1))                   

                  
        if isinstance(curves_data, unicode):
            with open(curves_data) as f:
                tokens=f.read().split()
            curves_data = []
            for w in tokens:
                curves_data.append(int(w,16))
        set_sensor_gamma_table_addr (
                num_sensor = num_sensor,
                sub_channel = sub_channel,
                color = 0,
                page = page)
        for n in range(4):
            for i in range(256):
                base =curves_data[257*n+i];
                diff =curves_data[257*n+i+1]-curves_data[257*n+i];
                diff1=curves_data[257*n+i+1]-curves_data[257*n+i]+8;
        #        $display ("%x %x %x %x %x %x",n,i,curves_data[257*n+i], base, diff, diff1);
                #1;
                if ((diff > 63) or (diff < -64)):
                    data18 = (1 << 17) | (base & 0x3ff) | (((diff1 >> 4) & 0x7f) << 10) # {1'b1,diff1[10:4],base[9:0]};
                else:
                    data18 =             (base & 0x3ff) | (( diff        & 0x7f) << 10) # {1'b0,diff [ 6:0],base[9:0]};
                set_sensor_gamma_table_data (
                    num_sensor = num_sensor,
                    data18 = data18)
            
    def set_sensor_gamma_heights (self, 
                                  num_sensor,
                                  height0_m1,
                                  height1_m1,
                                  height2_m1):
        """
        Set division of the composite frame into sub-frames for gamma correction (separate for each subframe
        @param num_sensor - sensor port number (0..3)
        @param height0_m1 - height of the first sub-frame minus 1
        @param height1_m1 - height of the second sub-frame minus 1
        @param height2_m1 - height of the third sub-frame minus 1
        (No need for the  4-th, as it will just go until end of the composite frame)
        """
        reg_addr = (vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC) + vrlg.SENS_GAMMA_RADDR + vrlg.SENS_GAMMA_HEIGHT01
        self.x393_axi_tasks.write_contol_register(reg_addr, (height0_m1 & 0xffff) | ((height1_m1 & 0xffff) << 16));                   

        reg_addr = (vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC) + vrlg.SENS_GAMMA_RADDR + vrlg.SENS_GAMMA_HEIGHT2;
        self.x393_axi_tasks.write_contol_register(reg_addr, height2_m1 & 0xffff);                   

    def set_sensor_gamma_ctl (self,
                              num_sensor,
                              bayer =      0,
                              table_page = 0,
                              en_input =   True,
                              repet_mode = True, #  Normal mode, single trigger - just for debugging  TODO: re-assign?
                              trig = False):
        """
        Setup sensor gamma correction
        @param num_sensor - sensor port number (0..3)
        @param bayer - Bayer shift (0..3)
        @param table_page - Gamma table page
        @param en_input -   Enable input
        @param repet_mode - Repetitive (normal) mode. Set False for debugging, then use trig for single frame trigger
        @param trig       - single trigger (when repet_mode is False), debug feature
        """
        data = self.func_sensor_gamma_ctl (
                                            bayer =      bayer,
                                            table_page = table_page,
                                            en_input =   en_input,
                                            repet_mode = repet_mode,
                                            trig =       trig)
        reg_addr = (vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC) + vrlg.SENS_GAMMA_RADDR + vrlg.SENS_GAMMA_CTRL;
        self.x393_axi_tasks.write_contol_register(reg_addr, data);
        
    def set_sensor_histogram_window (self,
                                     num_sensor,
                                     subchannel,
                                     left,
                                     top,
                                     width_m1,
                                     height_m1):
        """
        Program histogram window
        @param num_sensor -     sensor port number (0..3)
        @param num_sub_sensor - sub-sensor attached to the same port through multiplexer (0..3)
        @param left - histogram window left margin
        @param top -  histogram window top margin
        @param width_m1 - one less than window width. If 0 - use frame right margin (end of HACT)
        @param height_m1 - one less than window height. If 0 - use frame bottom margin (end of VACT)
        """
        raddr = (vrlg.HISTOGRAM_RADDR0, vrlg.HISTOGRAM_RADDR1, vrlg.HISTOGRAM_RADDR2, vrlg.HISTOGRAM_RADDR3)
        reg_addr = (vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC) + raddr[subchannel & 3]
        self.x393_axi_tasks.write_contol_register(reg_addr + vrlg.HISTOGRAM_LEFT_TOP,     ((top & 0xffff) << 16) | (left & 0xff))
        self.x393_axi_tasks.write_contol_register(reg_addr + vrlg.HISTOGRAM_WIDTH_HEIGHT, ((height_m1 & 0xffff) << 16) | (width_m1 & 0xff))
    def set_sensor_histogram_saxi (self,
                                   en,
                                   nrst,
                                   confirm_write,
                                   cache_mode = 3):
        """
        Setup SAXI GP channel to transfer histograms (16 pages, up to 16 sensors) to the system memory
        @param en - enable transfers
        @param nrst - negated reset False - immediate reset, True - normal run;
        @param confirm_write -  wait for the write confirmed (over B channel) before switching channels
        @param cache_mode AXI cache mode,  default should be 4'h3
        """ 
        data = 0;
        data |= (0,1)[en] <<            vrlg.HIST_SAXI_EN
        data |= (0,1)[nrst] <<          vrlg.HIST_SAXI_NRESET
        data |= (0,1)[confirm_write] << vrlg.HIST_CONFIRM_WRITE
        data |= (cache_mode & 0xf) <<   vrlg.HIST_SAXI_AWCACHE
        self.x393_axi_tasks.write_contol_register(vrlg.SENSOR_GROUP_ADDR + vrlg.HIST_SAXI_MODE_ADDR_REL, data)

    def set_sensor_histogram_saxi_addr (self,
                                        num_sensor,
                                        subchannel,
                                        page):
        """
        Setup SAXI GP start address in 4KB pages (1 page - 1 subchannel histogram)
        @param num_sensor -     sensor port number (0..3)
        @param num_sub_sensor - sub-sensor attached to the same port through multiplexer (0..3)
        @param page -           system memory page address (in 4KB units)
        """ 
        channel = ((num_sensor & 3) << 2) + (subchannel & 3) 
        self.x393_axi_tasks.write_contol_register(vrlg.SENSOR_GROUP_ADDR + vrlg.HIST_SAXI_ADDR_REL + channel,page)

    def setup_sensor_memory (self,
                             num_sensor,
                             frame_sa,
                             frame_sa_inc,
                             last_frame_num,
                             frame_full_width,
                             window_width,
                             window_height,
                             window_left,
                             window_top):
        """
        Setup memory controller for a sensor channel
        @param num_sensor -       sensor port number (0..3)
        @param frame_sa -         22-bit frame start address ((3 CA LSBs==0. BA==0)
        @param frame_sa_inc -     22-bit frame start address increment  ((3 CA LSBs==0. BA==0)
        @param last_frame_num -   16-bit number of the last frame in a buffer
        @param frame_full_width - 13-bit Padded line length (8-row increment), in 8-bursts (16 bytes)
        @param window_width -     13-bit - in 8*16=128 bit bursts
        @param window_height -    16-bit window height (in scan lines)
        @param window_left -      13-bit window left margin in 8-bursts (16 bytes)
        @param window_top -       16-bit window top margin (in scan lines
        """
        base_addr = vrlg.MCONTR_SENS_BASE + vrlg.MCONTR_SENS_INC * num_sensor;
        mode=   x393_mcntrl.func_encode_mode_scan_tiled(
                                   disable_need = False,
                                   repetitive=    True,
                                   single =       False,
                                   reset_frame =  False,
                                   extra_pages =  0,
                                   write_mem =    True,
                                   enable =       True,
                                   chn_reset =    False)
                    
        self.x393_axi_tasks.write_contol_register(base_addr + vrlg.MCNTRL_SCANLINE_STARTADDR,
                                                  frame_sa); # RA=80, CA=0, BA=0 22-bit frame start address (3 CA LSBs==0. BA==0)
        self.x393_axi_tasks.write_contol_register(base_addr + vrlg.MCNTRL_SCANLINE_FRAME_SIZE,
                                                  frame_sa_inc);
        self.x393_axi_tasks.write_contol_register(base_addr + vrlg.MCNTRL_SCANLINE_FRAME_LAST,
                                                  last_frame_num);
        self.x393_axi_tasks.write_contol_register(base_addr + vrlg.MCNTRL_SCANLINE_FRAME_FULL_WIDTH,
                                                  frame_full_width);
        self.x393_axi_tasks.write_contol_register(base_addr + vrlg.MCNTRL_SCANLINE_WINDOW_WH,
                                                  ((window_height & 0xffff) << 16) | (window_width & 0xffff)) #/WINDOW_WIDTH + (WINDOW_HEIGHT<<16));
        self.x393_axi_tasks.write_contol_register(base_addr + vrlg.MCNTRL_SCANLINE_WINDOW_X0Y0,
                                                  ((window_top & 0xffff) << 16) | (window_left & 0xffff)) #WINDOW_X0+ (WINDOW_Y0<<16));
        self.x393_axi_tasks.write_contol_register(base_addr + vrlg.MCNTRL_SCANLINE_WINDOW_STARTXY,   0)
        self.x393_axi_tasks.write_contol_register(base_addr + vrlg.MCNTRL_SCANLINE_MODE,          mode) 
