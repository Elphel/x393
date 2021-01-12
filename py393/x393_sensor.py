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
import struct

from x393_mem                import X393Mem
import x393_axi_control_status

import x393_utils

import time
import vrlg
import x393_mcntrl

##import subprocess

#import x393_sens_cmprs
SENSOR_INTERFACE_PARALLEL = "PAR12"
SENSOR_INTERFACE_HISPI =    "HISPI"
SENSOR_INTERFACE_VOSPI =    "VOSPI"
SENSOR_INTERFACE_BOSON =    "BOSON"
BOSON_MAP = {"gao":      (0x00, 0), # (module, table index - will be multiplied by 4 for 0,1,2 and 4-byte xmit command)
             "roic":     (0x02, 1),
             "bpr":      (0x03, 2),
             "telemetry":(0x04, 3),
             "boson":    (0x05, 4),
             "dvo":      (0x06, 5),
             "scnr":     (0x08, 6),
             "tnr":      (0x0a, 7),
             "snr":      (0x0c, 8),
             "sysctrl":  (0x0e, 9),
             "testramp": (0x10,10),
             "spnr":     (0x28,11)}
BOSON_EXTIF = 1 #EXTIF code for i2c commands - 0 - i2c, 1 - uart, 2,3 - reserved

class X393Sensor(object):
    DRY_MODE= True # True
    DEBUG_MODE=1
    x393_mem=None
    x393_axi_tasks=None #x393X393AxiControlStatus
    x393_utils=None
    uart_seq_number = 0

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
    def getSensorInterfaceType(self):
        """
        Get sensor interface type by reading status register 0xfe that is set to 0 for parallel and 1 for HiSPi
        @return "PAR12" or "HISPI"
        """
        print ("===== Was: Running in dry mode, using parallel sensor======")
#        if  self.DRY_MODE is True:
#            print ("===== Running in dry mode, using parallel sensor======")
#            return SENSOR_INTERFACE_PARALLEL
        try:
            print(self.x393_axi_tasks.read_status(address=0xfe))
        except:
            print ("===== Failed to read sesnor type, using parallel sensor======")
            if  self.DRY_MODE is True:
                return SENSOR_INTERFACE_PARALLEL
        sens_type = (SENSOR_INTERFACE_PARALLEL,
                     SENSOR_INTERFACE_HISPI,
                     SENSOR_INTERFACE_VOSPI,
                     SENSOR_INTERFACE_BOSON
                     )[self.x393_axi_tasks.read_status(address=0xfe)] # "PAR12" , "HISPI"
        print ("===== Sensor type read from FPGA = >>> %s <<< ======"%(sens_type))
        return sens_type

    def program_status_sensor_i2c( self,
                                   num_sensor,
                                   mode,     # input [1:0] mode;
                                   seq_num): # input [5:0] seq_num;
        """
        Set status generation mode for selected sensor port i2c control
        @param num_sensor - number of the sensor port (0..3) or all
        @param mode -       status generation mode:
                                  0: disable status generation,
                                  1: single status request,
                                  2: auto status, keep specified seq number,
                                  3: auto, inc sequence number
        @param seq_number - 6-bit sequence number of the status message to be sent
        """
        try:
            if (num_sensor == all) or (num_sensor[0].upper() == "A"): #all is a built-in function
                for num_sensor in range(4):
                    self.program_status_sensor_i2c (num_sensor = num_sensor,
                                                    mode =       mode,
                                                    seq_num =    seq_num)
                return
        except:
            pass

        self.x393_axi_tasks.program_status (vrlg.SENSOR_GROUP_ADDR  + num_sensor * vrlg.SENSOR_BASE_INC + vrlg.SENSI2C_CTRL_RADDR,
                             vrlg.SENSI2C_STATUS,
                             mode,
                             seq_num)# //MCONTR_PHY_STATUS_REG_ADDR=          'h0,

    def program_status_sensor_io( self,
                                  num_sensor,
                                  mode,     # input [1:0] mode;
                                  seq_num): # input [5:0] seq_num;
        """
        Set status generation mode for selected sensor port io subsystem
        @param num_sensor - number of the sensor port (0..3) or all
        @param mode -       status generation mode:
                                  0: disable status generation,
                                  1: single status request,
                                  2: auto status, keep specified seq number,
                                  3: auto, inc sequence number
        @param seq_number - 6-bit sequence number of the status message to be sent
        """
        try:
            if (num_sensor == all) or (num_sensor[0].upper() == "A"): #all is a built-in function
                for num_sensor in range(4):
                    self.program_status_sensor_io (num_sensor = num_sensor,
                                                   mode =       mode,
                                                   seq_num =    seq_num)
                return
        except:
            pass

        self.x393_axi_tasks.program_status (
                             vrlg.SENSOR_GROUP_ADDR  + num_sensor * vrlg.SENSOR_BASE_INC + vrlg.SENSIO_RADDR,
                             vrlg.SENSIO_STATUS,
                             mode,
                             seq_num)# //MCONTR_PHY_STATUS_REG_ADDR=          'h0,

    def get_status_sensor_io ( self,
                              num_sensor="All"):
        """
        Read sensor_io status word (no sync)
        @param num_sensor - number of the sensor port (0..3)
        @return sensor_io status
        """
        try:
            if (num_sensor == all) or (num_sensor[0].upper() == "A"): #all is a built-in function
                rslt = []
                for num_sensor in range(4):
                    rslt.append(self.get_status_sensor_io (num_sensor = num_sensor))
                return rslt
        except:
            pass
        return self.x393_axi_tasks.read_status(
                    address=(vrlg.SENSI2C_STATUS_REG_BASE + num_sensor * vrlg.SENSI2C_STATUS_REG_INC + vrlg.SENSIO_STATUS_REG_REL))

    def print_status_sensor_io (self,
                                num_sensor="All", sensorType = SENSOR_INTERFACE_PARALLEL):
        """
        Print sensor_io status word (no sync)
        @param num_sensor - number of the sensor port (0..3)
        """
        try:
            if (num_sensor == all) or (num_sensor[0].upper() == "A"): #all is a built-in function
                for num_sensor in range(4):
                    print ("\n ==== Sensor %d"%(num_sensor))
                    self.print_status_sensor_io (num_sensor = num_sensor, sensorType = sensorType)
                return
        except:
            pass
        status= self.get_status_sensor_io(num_sensor)
        print ("print_status_sensor_io(%d):"%(num_sensor))
        
        if (sensorType == SENSOR_INTERFACE_VOSPI):
            print ("   segment_id =             %d"%((status>> 0) & 0x0f))
            print ("   gpio_in =                %d"%((status>> 4) & 0x0f))
            print ("   in_busy =                %d"%((status>> 8) & 1))
            print ("   out_busy =               %d"%((status>> 9) & 1))
            print ("   crc_err =                %d"%((status>>10) & 1))
            print ("   fake_in =                %d"%((status>>11) & 1))
            print ("   senspgmin =              %d"%((status>>24) & 1))
            print ("   busy =                   %d"%((status>>25) & 1))
            print ("   seq =                    %d"%((status>>26) & 0x3f))
        elif (sensorType == SENSOR_INTERFACE_BOSON):
            print ("   ps_out =                 %d"%((status>> 0) & 0xff))
            print ("   ps_rdy =                 %d"%((status>> 8) & 1))
            print ("   perr =                   %d"%((status>> 9) & 1))
            print ("   clkfb_pxd_stopped_mmcm = %d"%((status>>10) & 1))
            print ("   clkin_pxd_stopped_mmcm = %d"%((status>>11) & 1))
            print ("   locked_pxd_mmcm =        %d"%((status>>12) & 1))
            print ("   hact_alive =             %d"%((status>>13) & 1))
            print ("   recv_prgrs =             %d"%((status>>14) & 1))
            print ("   recv_dav =               %d"%((status>>15) & 1))
            print ("   recv_data =              %d"%((status>>16) & 0xff))
            print ("   senspgmin =              %d"%((status>>24) & 1))
            print ("   xmit_busy =              %d"%((status>>25) & 1))
            print ("   seq =                    %d"%((status>>26) & 0x3f))
        else:    
#last_in_line_1cyc_mclk, dout_valid_1cyc_mclk
            """
            print ("   last_in_line_1cyc_mclk = %d"%((status>>23) & 1))
            print ("   dout_valid_1cyc_mclk =   %d"%((status>>22) & 1))
            print ("   alive_hist0_gr =         %d"%((status>>21) & 1))
            print ("   alive_hist0_rq =         %d"%((status>>20) & 1))
            print ("   sof_out_mclk =           %d"%((status>>19) & 1))
            print ("   eof_mclk =               %d"%((status>>18) & 1))
            print ("   sof_mclk =               %d"%((status>>17) & 1))
            print ("   sol_mclk =               %d"%((status>>16) & 1))
            """
            """
            #Folowing 5 bits may be just temporarily available
            print ("   irst =                   %d"%((status>>20) & 1))
            print ("async_prst_with_sens_mrst = %d"%((status>>19) & 1))
            print ("   imrst =                  %d"%((status>>18) & 1))
            print ("   rst_mmcm =               %d"%((status>>17) & 1))
            print ("   pxd_out_pre[1] =         %d"%((status>>16) & 1))
            """
    
            print ("   shifted TDO              %d"%((status>>16) & 0xff))
    
            print ("   vact_alive =             %d"%((status>>15) & 1))
            print ("   hact_ext_alive =         %d"%((status>>14) & 1))
    #        print ("   hact_alive =             %d"%((status>>13) & 1))
            print ("   hact_run =               %d"%((status>>13) & 1))
            print ("   locked_pxd_mmcm =        %d"%((status>>12) & 1))
            print ("   clkin_pxd_stopped_mmcm = %d"%((status>>11) & 1))
            print ("   clkfb_pxd_stopped_mmcm = %d"%((status>>10) & 1))
            print ("   xfpgadone =              %d"%((status>> 9) & 1))
            print ("   ps_rdy =                 %d"%((status>> 8) & 1))
            print ("   ps_out =                 %d"%((status>> 0)  & 0xff))
            print ("   xfpgatdo =               %d"%((status>>25) & 1))
            print ("   senspgmin =              %d"%((status>>24) & 1))
            print ("   seq =                    %d"%((status>>26) & 0x3f))
#vact_alive, hact_ext_alive, hact_alive
    def get_status_sensor_i2c ( self,
                              num_sensor="All"):
        """
        Read sensor_i2c status word (no sync)
        @param num_sensor - number of the sensor port (0..3)
        @return sesnor_io status
        """
        try:
            if (num_sensor == all) or (num_sensor[0].upper() == "A"): #all is a built-in function
                rslt = []
                for num_sensor in range(4):
                    rslt.append(self.get_status_sensor_i2c (num_sensor = num_sensor))
                return rslt
        except:
            pass
        return self.x393_axi_tasks.read_status(
                    address=(vrlg.SENSI2C_STATUS_REG_BASE + num_sensor * vrlg.SENSI2C_STATUS_REG_INC + vrlg.SENSI2C_STATUS_REG_REL))

    def print_status_sensor_i2c (self,
                                num_sensor="All"):
        """
        Print sensor_i2c status word (no sync)
        @param num_sensor - number of the sensor port (0..3)
        """
        try:
            if (num_sensor == all) or (num_sensor[0].upper() == "A"): #all is a built-in function
                for num_sensor in range(4):
                    print ("\n ==== Sensor %d"%(num_sensor))
                    self.print_status_sensor_i2c (num_sensor = num_sensor)
                return
        except:
            pass
        status= self.get_status_sensor_i2c(num_sensor)
        print ("print_status_sensor_i2c(%d):"%(num_sensor))
        print ("   reset_on =               %d"%((status>>17) & 1))
        print ("   req_clr =                %d"%((status>>16) & 1))
        print ("   frame_num =              %d"%((status>>12) & 0xf))
        print ("   wr_full =                %d"%((status>>11) & 1))
        print ("   busy =                   %d"%((status>>10) & 1))
        print ("   i2c_fifo_lsb =           %d"%((status>> 9) & 1))
        print ("   i2c_fifo_nempty =        %d"%((status>> 8) & 1))
        print ("   i2c_fifo_dout =          %d"%((status>> 0) & 0xff))

        print ("   sda_in =                 %d"%((status>>25) & 1))
        print ("   scl_in =                 %d"%((status>>24) & 1))
        print ("   seq =                    %d"%((status>>26) & 0x3f))

# Functions used by sensor-related tasks
    def func_sensor_mode (self,
                          hist_en =   None,
                          hist_nrst = None,
                          chn_en =    None,
                          bits16 =    None):
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
        if (not hist_en is None) and (not hist_nrst is None):
            rslt |= (hist_en & 0xf) <<   vrlg.SENSOR_HIST_EN_BITS
            rslt |= (hist_nrst & 0xf) << vrlg.SENSOR_HIST_NRST_BITS
            rslt |= 1 << vrlg.SENSOR_HIST_BITS_SET;
        if not chn_en is None:
            rslt |= ((0,1)[chn_en]) <<   vrlg.SENSOR_CHN_EN_BIT
            rslt |= 1 <<                 vrlg.SENSOR_CHN_EN_BIT_SET
        if not bits16 is None:
            rslt |= ((0,1)[bits16]) <<   vrlg.SENSOR_16BIT_BIT
            rslt |= 1 <<                 vrlg.SENSOR_16BIT_BIT_SET
        return rslt

    def func_sensor_i2c_command (self,
                                 rst_cmd =   False,
                                 run_cmd =   None,
                                 active_sda = None,
                                 early_release_0 = None,
                                 advance_FIFO = None,
                                 sda = None,
                                 scl = None,
                                 use_eof = None,
                                 verbose = 1):
        """
        @param rst_cmd - reset all FIFO (takes 16 clock pulses), also - stops i2c until run command
        @param run_cmd - True - run i2c, False - stop i2c (needed before software i2c), None - no change
        @param active_sda - pull-up SDA line during second half of SCL=0, when needed and possible
        @param early_release_0 -  release SDA=0 immediately after the end of SCL=1 (SDA hold will be provided by week pullup)
        @param advance_FIFO - advance i2c read FIFO
        @param sda - control SDA line (stopped mode only): I<nput>, L<ow> or 0, High or 1
        @param scl - control SCL line (stopped mode only): I<nput>, L<ow> or 0, High or 1
        @param use_eof - advance sequencer at EOF, not at SOF
        @param verbose -          verbose level
        @return combined command word.
        active_sda and early_release_0 should be defined both to take effect (any of the None skips setting these parameters)
        """
        def parse_sda_scl(val):
            if val is None:
                return 0
            elif isinstance(val, (str,)):
                if not val:
                    return 0
                if val[0] in "lL0":
                    return 1
                elif val[0] in "hH1":
                    return 2
                elif val[0] in "iI":
                    return 3
                else:
                    print("Unrecognized value for SDA/SCL: %s, should be in lL0hH1iI (or None/ empty string)"%(val))
                    return 0
            else:
                if val == 0:
                    return 1
                elif val == 1:
                    return 2
                else:
                    return 3

        if verbose>1:
            print ("func_sensor_i2c_command(): rst_cmd= ",rst_cmd,", run_cmd=",run_cmd,", active_sda = ",active_sda,", early_release_0 = ",early_release_0,
                   ", sda=",sda,", scl=",scl)

        rslt = 0
        rslt |= (0,1)[rst_cmd] << vrlg.SENSI2C_CMD_RESET
        if not run_cmd is None:
            rslt |= 1 <<                 vrlg.SENSI2C_CMD_RUN
            rslt |= (0,1)[run_cmd] <<    (vrlg.SENSI2C_CMD_RUN - vrlg.SENSI2C_CMD_RUN_PBITS)
        if (not active_sda is None) and (not early_release_0 is None):
            rslt |= (0,1)[early_release_0] << vrlg.SENSI2C_CMD_ACIVE_EARLY0
            rslt |= (0,1)[active_sda] << vrlg.SENSI2C_CMD_ACIVE_SDA
            rslt |= 1 <<                 vrlg.SENSI2C_CMD_ACIVE
        if advance_FIFO:
            rslt |= 1 << vrlg.SENSI2C_CMD_FIFO_RD
        if not use_eof is None:
            rslt |= 1 <<                (vrlg.SENSI2C_CMD_USE_EOF + 1)
            rslt |= (0,1)[use_eof] <<   (vrlg.SENSI2C_CMD_USE_EOF)

        rslt |= parse_sda_scl(sda) <<  vrlg.SENSI2C_CMD_SOFT_SDA
        rslt |= parse_sda_scl(scl) <<  vrlg.SENSI2C_CMD_SOFT_SCL
        if verbose>0:
            print (" => 0x%x"%(rslt))

        return rslt

    def func_sensor_i2c_table_reg_wr (self,
                                 slave_addr,
                                 rah,
                                 num_bytes,
                                 bit_delay,
                                 extif = 0,
                                 verbose = 1):
        """
        @param slave_addr - 7-bit i2c slave address
        @param rah -        register address high byte (bits [15:8]) optionally used for register write commands
        @param num_bytes -  number of bytes to send (including register address bytes) 1..10
        @param bit_delay -  number of mclk clock cycle in 1/4 of the SCL period
        @param extif -      extrenal intgerface instead of i2c. 0 - i2c, 1 - uart,2,3 - reserved 
        @param verbose -    verbose level
        @return combined table data word.
        """
        if verbose>1:
            print ("func_sensor_i2c_table_reg_wr(): slave_addr= ",slave_addr,", rah=",rah,", num_bytes = ",num_bytes,", bit_delay = ",bit_delay)
        rslt = 0
        rslt |= (slave_addr & ((1 << vrlg.SENSI2C_TBL_SA_BITS)   - 1)) << vrlg.SENSI2C_TBL_SA
        rslt |= (rah &        ((1 << vrlg.SENSI2C_TBL_RAH_BITS)  - 1)) << vrlg.SENSI2C_TBL_RAH
        rslt |= (num_bytes &  ((1 << vrlg.SENSI2C_TBL_NBWR_BITS) - 1)) << vrlg.SENSI2C_TBL_NBWR
        rslt |= (bit_delay &  ((1 << vrlg.SENSI2C_TBL_DLY_BITS)  - 1)) << vrlg.SENSI2C_TBL_DLY
        rslt |= (extif &      ((1 << vrlg.SENSI2C_TBL_EXTIF_BITS)  - 1)) << vrlg.SENSI2C_TBL_EXTIF
        return rslt

    def func_sensor_i2c_table_reg_rd (self,
                                 two_byte_addr,
                                 num_bytes_rd,
                                 bit_delay,
                                 verbose = 1):
        """
        @param two_byte_addr - Use a 2-byte register address for read command (False - single byte)
        @param num_bytes_rd -  Number of bytes to read (1..8)
        @param bit_delay -     number of mclk clock cycle in 1/4 of the SCL period
        @param verbose -       verbose level
        @return combined table data word.
        """
        if verbose>0:
            print ("func_sensor_i2c_table_reg_rd(): two_byte_addr= ",two_byte_addr,", num_bytes_rd=",num_bytes_rd,", bit_delay = ",bit_delay)
        rslt = 0
        rslt |= 1 << vrlg.SENSI2C_TBL_RNWREG # this is read register command (0 - write register)
        if two_byte_addr > 1:
            two_byte_addr = 1
        rslt |= (0,1)[two_byte_addr]                                      << vrlg.SENSI2C_TBL_NABRD
        rslt |= (num_bytes_rd &  ((1 << vrlg.SENSI2C_TBL_NBRD_BITS) - 1)) << vrlg.SENSI2C_TBL_NBRD
        rslt |= (bit_delay &     ((1 << vrlg.SENSI2C_TBL_DLY_BITS)  - 1)) << vrlg.SENSI2C_TBL_DLY
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
        @param quadrants -  90-degree shifts for data [1:0], hact [3:2] and vact [5:4] [6] - extra hact delay by 1 pixel (7'h01), None - no change
        @return sensor i/o control word
        """
        rslt = 0
        if not mrst is None:
            rslt |= (3,2)[mrst] <<     vrlg.SENS_CTRL_MRST
        if not arst is None:
            rslt |= (3,2)[arst] <<     vrlg.SENS_CTRL_ARST
        if not aro is None:
            rslt |= (3,2)[aro]  <<     vrlg.SENS_CTRL_ARO
        if not mmcm_rst is None:
            rslt |= (2,3)[mmcm_rst] << vrlg.SENS_CTRL_RST_MMCM
        if not clk_sel is None:
            rslt |= (2,3)[clk_sel] <<  vrlg.SENS_CTRL_EXT_CLK
        rslt |= (0,1)[set_delays] <<   vrlg.SENS_CTRL_LD_DLY

        if not quadrants is None:
            rslt |= 1 <<  vrlg.SENS_CTRL_QUADRANTS_EN
            rslt |= (quadrants & ((1 << vrlg.SENS_CTRL_QUADRANTS_WIDTH) - 1)) <<  vrlg.SENS_CTRL_QUADRANTS
        return rslt

    def func_sensor_io_ctl_lwir (self,
                                 rst =        None,
                                 rst_seq =    None,
                                 spi_seq =    None,
                                 mclk  =      None,
                                 spi_en =     None, # 1 - reset+disable, 2 - noreset, disable, 3 - noreset, enable
                                 segm_zero =  None,
                                 out_en =     None,
                                 out_single = False,
                                 reset_crc =  False,
                                 spi_clk =    None,
                                 gpio0 =      None, 
                                 gpio1 =      None, 
                                 gpio2 =      None, 
#                                 gpio3 =      None,
                                 telemetry =  None, 
                                 vsync_use =  None,
                                 noresync =   None,
                                 
                                 dbg_src =    None):
        """
        Combine sensor I/O control parameters into a control word
        @param rst -        Sensor reset/power down control (0 - NOP, 1 - power down + reset, 2 - no pwdn, reset, 3 - no pwdn, no reset
        @param rst_seq      Initiate simultaneous all sensors reset, generate SOF after pause
        @param spi_seq      Initiate VOSPI reset, will generate normal SOF if successful
        @param mclk -       True - enable master clock (25MHz) to sensor, False - disable, None - no change
        @param spi_en -     True - SPI reset/enable: 0 - NOP, 1 - reset+disable, 2 - noreset, disable, 3 - noreset, enable, None - no change 
        @param segm_zero =  True - allow receiving segment ID==0 (ITAR invalid), False - disallow, None - no change,
        @param out_en =     True - enable continuously receiving data to memory, False - disable, None - no change
        @param out_single = True - acquire single frame,
        @param reset_crc =  True - reset CRC error status bit,
        @param spi_clk =    True - generate SPI clock during inactive SPI CS, False - do not generate SPI CLK when CS is inactive, None - no change
        @param gpio0 =      Output control for GPIO0: 0 - nop, 1 - set low, 2 - set high, 3 - input
        @param gpio1 =      Output control for GPIO0: 1 - nop, 1 - set low, 2 - set high, 3 - input 
        @param gpio2 =      Output control for GPIO0: 2 - nop, 1 - set low, 2 - set high, 3 - input 
        @param telemetry =  Enable (1) /disable (0) telemetry data lines (should be set in the sensor too, or it will hang)
        @param vsync_use =  Wait for VSYNC (should be enabled over i2c) before reading each segment
        @param noresync =   Disable resynchronization by discard packets
        @param dbg_src =    source of the hardware debug output: 0 - dbg_running
                                                                 1 - will_sync
                                                                 2 - vsync_rdy[1]
                                                                 3 - discard_segment
                                                                 4 - in_busy
                                                                 5 - out_busy
                                                                 6 - hact
                                                                 7 - sof
        @return VOSPI sensor i/o control word
        """
        rslt = 0
        if not rst is None:
            rslt |= (rst & 3) <<         vrlg.VOSPI_MRST
        if rst_seq:
            rslt |= 1 <<                 vrlg.VOSPI_RST_SEQ
        if spi_seq:
            rslt |= 1 <<                 vrlg.VOSPI_SPI_SEQ
        if not mclk is None:
            rslt |= (2,3)[mclk] <<       vrlg.VOSPI_MCLK
        if not spi_en is None:
            rslt |= (spi_en & 3) <<      vrlg.VOSPI_EN
        if not segm_zero is None:
            rslt |= (2,3)[segm_zero] <<  vrlg.VOSPI_SEGM0_OK
        if not out_en is None:
            rslt |= (2,3)[out_en] <<     vrlg.VOSPI_OUT_EN
        if out_single:
            rslt |= 1 <<                 vrlg.VOSPI_OUT_EN_SINGL
        if reset_crc:
            rslt |= 1 <<                 vrlg.VOSPI_RESET_ERR
        if not spi_clk is None:
            rslt |= (2,3)[spi_clk] <<    vrlg.VOSPI_SPI_CLK
        if not gpio0 is None:
            rslt |= (gpio0 & 3) <<       (vrlg.VOSPI_GPIO + 0)
        if not gpio1 is None:
            rslt |= (gpio1 & 3) <<       (vrlg.VOSPI_GPIO + 2)
        if not gpio2 is None:
            rslt |= (gpio2 & 3) <<       (vrlg.VOSPI_GPIO + 4)
            
#        if not gpio3 is None:
#            rslt |= (gpio3 & 3) <<       (vrlg.VOSPI_GPIO + 6)
        if not telemetry is None:
            rslt |= (2,3)[telemetry] <<  vrlg.VOSPI_TELEMETRY
            
        if not vsync_use is None:
            rslt |= (2,3)[vsync_use] <<  vrlg.VOSPI_VSYNC
        if not noresync is None:
            rslt |= (2,3)[noresync] <<   vrlg.VOSPI_NORESYNC

        if not dbg_src is None:
            rslt |= ((dbg_src & (( 1 << (vrlg.VOSPI_DBG_SRC_BITS - 1)) -1 )) |
                      (1 << (vrlg.VOSPI_DBG_SRC_BITS - 1))) << vrlg.VOSPI_DBG_SRC
            pass    
            
#            .VOSPI_DBG_SRC          (VOSPI_DBG_SRC), // =         26, // source of the debug output
#            .VOSPI_DBG_SRC_BITS     (VOSPI_DBG_SRC_BITS), // =     4,
            
            
        return rslt

    def func_sensor_io_ctl_boson (self,
                            mrst =       None,
                            mmcm_rst =   None,
                            set_delays = False,
                            gpio0 =      None,
                            gpio1 =      None,
                            gpio2 =      None,
                            gpio3 =      None):
        """
        Combine sensor I/O control parameters into a control word
        @param mrst -  True - activate MRST signal (low), False - deactivate MRST (high), None - no change
        @param mmcm_rst - True - activate MMCM reset, False - deactivate MMCM reset, None - no change (needed after clock change/interruption)
        @param set_delays - (self-clearing) load all pre-programmed delays for the sensor pad inputs
        @param gpio0 -   GPIO[0]: 0 - float(input), 1 - out low, 2 out high, 3 - pulse high
        @param gpio1 -   GPIO[1]: 0 - float(input), 1 - out low, 2 out high, 3 - pulse high
        @param gpio2 -   GPIO[2]: 0 - float(input), 1 - out low, 2 out high, 3 - pulse high
        @param gpio3 -   GPIO[3]: 0 - float(input), 1 - out low, 2 out high, 3 - pulse high
        @return sensor i/o control word
        """
        rslt = 0
        if not mrst is None:
            rslt |= (3,2)[mrst] <<     vrlg.SENS_CTRL_MRST
        if not mmcm_rst is None:
            rslt |= (2,3)[mmcm_rst] << vrlg.SENS_CTRL_RST_MMCM
        rslt |= (0,1)[set_delays] <<   vrlg.SENS_CTRL_LD_DLY
        #GPIO are not yet used in Boson?
        if not gpio0 is None:
            rslt |= (4 | (gpio0 & 3)) << vrlg.SENS_CTRL_GP0
        if not gpio1 is None:
            rslt |= (4 | (gpio1 & 3)) << vrlg.SENS_CTRL_GP1
        if not gpio2 is None:
            rslt |= (4 | (gpio2 & 3)) << vrlg.SENS_CTRL_GP2
        if not gpio3 is None:
            rslt |= (4 | (gpio3 & 3)) << vrlg.SENS_CTRL_GP3
        return rslt

    def func_sensor_uart_ctl_boson (self,
                            uart_extif_en =   None,
                            uart_xmit_rst =   None,
                            uart_recv_rst =   None,
                            uart_xmit_start = False,
                            uart_recv_next = False):
        """
        Combine sensor UART control parameters into a control word
        @param uart_extif_en -   True - enable sequencer commands, False - disable sequencer commands
        @param uart_xmit_rst -   True - persistent reset software packet transmission, False - disable reset software packet transmission (normal operation)
        @param uart_recv_rst -   True - persistent reset packet receive, False - disable reset packet receive (normal operation)
        @param uart_xmit_start - start transmiting prepared packet
        @param uart_recv_next -  advance receive FIFO to next byte
        @return uart control word
        """
        rslt = 0
        if not uart_extif_en is None:
            rslt |= (2,3)[uart_extif_en] <<     vrlg.SENS_UART_EXTIF_EN

        if not uart_xmit_rst is None:
            rslt |= (2,3)[uart_xmit_rst] <<     vrlg.SENS_UART_XMIT_RST
        if not uart_recv_rst is None:
            rslt |= (2,3)[uart_recv_rst] <<     vrlg.SENS_UART_RECV_RST
        rslt |= (0,1)[uart_xmit_start] <<       vrlg.SENS_UART_XMIT_START
        rslt |= (0,1)[uart_recv_next] <<        vrlg.SENS_UART_RECV_NEXT
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
                              bayer =      None,
                              table_page = None,
                              en_input =   None,
                              repet_mode = None, #  Normal mode, single trigger - just for debugging  TODO: re-assign?
                              trig =       False):
        """
        @param bayer - Bayer shift (0..3)
        @param table_page - Gamma table page
        @param en_input -   Enable input
        @param repet_mode - Repetitive (normal) mode. Set False for debugging, then use trig for single frame trigger
        @param trig       - single trigger (when repet_mode is False), debug feature
        @return combined control word
        """
        rslt = 0
        if not bayer is None:
            rslt |= (bayer & 3) <<       vrlg.SENS_GAMMA_MODE_BAYER
            rslt |=          1  <<       vrlg.SENS_GAMMA_MODE_BAYER_SET

        if not table_page is None:
            rslt |= (0,1)[table_page] << vrlg.SENS_GAMMA_MODE_PAGE
            rslt |=                1  << vrlg.SENS_GAMMA_MODE_PAGE_SET

        if not en_input is None:
            rslt |= (0,1)[en_input] <<   vrlg.SENS_GAMMA_MODE_EN
            rslt |=              1  <<   vrlg.SENS_GAMMA_MODE_EN_SET

        if not repet_mode is None:
            rslt |= (0,1)[repet_mode] << vrlg.SENS_GAMMA_MODE_REPET
            rslt |=                1  << vrlg.SENS_GAMMA_MODE_REPET_SET

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
                         hist_en =   None,
                         hist_nrst = None,
                         chn_en =    None,
                         bits16 =    None):
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
        try:
            if (num_sensor == all) or (num_sensor[0].upper() == "A"): #all is a built-in function
                for num_sensor in range(4):
                    self.set_sensor_mode (num_sensor = num_sensor,
                         hist_en = hist_en,
                         hist_nrst = hist_nrst,
                         chn_en = chn_en,
                         bits16 = bits16)
                return
        except:
            pass

        self.x393_axi_tasks.write_control_register(vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC + vrlg.SENSOR_CTRL_RADDR,
                                                  self.func_sensor_mode(
                                                                   hist_en =   hist_en,
                                                                   hist_nrst = hist_nrst,
                                                                   chn_en =    chn_en,
                                                                   bits16 =    bits16))





    def set_sensor_i2c_command (self,
                                num_sensor,
                                rst_cmd =         False,
                                run_cmd =         None,
                                active_sda =      None,
                                early_release_0 = None,
                                advance_FIFO =    None,
                                sda =             None,
                                scl =             None,
                                use_eof =         None,
                                verbose =         1):
        """
        @param num_sensor - sensor port number (0..3) or all
        @param rst_cmd - reset all FIFO (takes 16 clock pulses), also - stops i2c until run command
        @param run_cmd - True - run i2c, False - stop i2c (needed before software i2c), None - no change
        @param active_sda - pull-up SDA line during second half of SCL=0, when needed and possible
        @param early_release_0 -  release SDA=0 immediately after the end of SCL=1 (SDA hold will be provided by week pullup)
        @param advance_FIFO -     advance i2c read FIFO
        @param sda - control SDA line (stopped mode only): I<nput>, L<ow> or 0, High or 1
        @param scl - control SCL line (stopped mode only): I<nput>, L<ow> or 0, High or 1
        @param use_eof - advance sequencer at EOF, not at SOF
        @param verbose -          verbose level
        active_sda and early_release_0 should be defined both to take effect (any of the None skips setting these parameters)

        """
        try:
            if (num_sensor == all) or (num_sensor[0].upper() == "A"): #all is a built-in function
                for num_sensor in range(4):
                    self.set_sensor_i2c_command (num_sensor,
                                rst_cmd =         rst_cmd,
                                run_cmd =         run_cmd,
                                active_sda =      active_sda,
                                early_release_0 = early_release_0,
                                advance_FIFO =    advance_FIFO,
                                sda =             sda,
                                scl =             scl,
                                use_eof =         use_eof,
                                verbose =         verbose)

                return
        except:
            pass


        self.x393_axi_tasks.write_control_register(vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC + vrlg.SENSI2C_CTRL_RADDR,
                                                  self.func_sensor_i2c_command(
                                                       rst_cmd =         rst_cmd,
                                                       run_cmd =         run_cmd,
                                                       active_sda =      active_sda,
                                                       early_release_0 = early_release_0,
                                                       advance_FIFO =    advance_FIFO,
                                                       sda =             sda,
                                                       scl =             scl,
                                                       use_eof =         use_eof,
                                                       verbose =         verbose-1))

    def set_sensor_i2c_table_reg_wr (self,
                                     num_sensor,
                                     page,
                                     slave_addr,
                                     rah,
                                     num_bytes,
                                     bit_delay,
                                     extif = 0,
                                     verbose = 1):
        """
        Set table entry for a single index for register write
        @param num_sensor - sensor port number (0..3)
        @param page -       1 byte table index (later provided as high byte of the 32-bit command)
        @param slave_addr - 7-bit i2c slave address (number of payload bytes for UART command (0..4)
        @param rah -        register address high byte (bits [15:8]) optionally used for register write commands (module # for UART)
        @param num_bytes -  number of bytes to send (including register address bytes) 1..10 (always 4 for UART)
        @param bit_delay -  number of mclk clock cycle in 1/4 of the SCL period
        @param extif -      extrenal intgerface instead of i2c. 0 - i2c, 1 - uart,2,3 - reserved 
        @param verbose -    verbose level
        """
        ta = (1 << vrlg.SENSI2C_CMD_TABLE) | (1 << vrlg.SENSI2C_CMD_TAND) | (page & 0xff)
        td = (1 << vrlg.SENSI2C_CMD_TABLE) | self.func_sensor_i2c_table_reg_wr(
                                               slave_addr = slave_addr,
                                               rah =        rah,
                                               num_bytes =  num_bytes,
                                               bit_delay =  bit_delay,
                                               extif =      extif,
                                               verbose =    verbose)

        self.x393_axi_tasks.write_control_register(vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC + vrlg.SENSI2C_CTRL_RADDR, ta)
        self.x393_axi_tasks.write_control_register(vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC + vrlg.SENSI2C_CTRL_RADDR, td)

    def set_sensor_i2c_table_reg_rd (self,
                                     num_sensor,
                                     page,
                                     two_byte_addr,
                                     num_bytes_rd,
                                     bit_delay,
                                     verbose = 1):
        """
        Set table entry for a single index for register write
        @param num_sensor -    sensor port number (0..3)
        @param page -          1 byte table index (later provided as high byte of the 32-bit command)
        @param two_byte_addr - Use a 2-byte register address for read command (False - single byte)
        @param num_bytes_rd -  Number of bytes to read (1..8)
        @param bit_delay -     number of mclk clock cycle in 1/4 of the SCL period
        @param verbose -       verbose level
        """
        ta = (1 << vrlg.SENSI2C_CMD_TABLE) | (1 << vrlg.SENSI2C_CMD_TAND) | (page & 0xff)
        td = (1 << vrlg.SENSI2C_CMD_TABLE) | self.func_sensor_i2c_table_reg_rd(
                                               two_byte_addr = two_byte_addr,
                                               num_bytes_rd = num_bytes_rd,
                                               bit_delay =  bit_delay,
                                               verbose =    verbose)
        self.x393_axi_tasks.write_control_register(vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC + vrlg.SENSI2C_CTRL_RADDR, ta)
        self.x393_axi_tasks.write_control_register(vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC + vrlg.SENSI2C_CTRL_RADDR, td)
        if verbose > 1:
            print ("ta= 0x%x, td = 0x%x"%(ta,td))

    def write_boson_cmd(self,
                        num_sensor,
                        rel_addr,
                        addr,
                        mod_name, # module name
                        func_lsb, # LSB of the function
                        num_payload_bytes, #0,1,2,4
                        data):
        """
        Write i2c command to the i2c command sequencer
        @param num_sensor - sensor port number (0..3), or "all" - same to all sensors
        @param rel_addr - True - relative frame address, False - absolute frame address
        @param addr - frame address (0..15)
        @param mod_name - gao, roic, bpr, telemetry, boson, dvo, scnr, tnr, snr, sysctrl, testramp, spnr
        @param func_lsb - function code LSB:
        @param num_payload_bytes - number of payload bytes: 0,1,2 or 4 only
        @param payload data (16 LSB used)
        """

        payload_mode = (0,1,2,-1,3)[num_payload_bytes]
        if payload_mode < 0:
            raise ValueError('Payload of 3 bytes is not implemented, only 0,1,2 or 4 bytes are valid.')
        _,mod_index = BOSON_MAP[mod_name]
        wdata = ((mod_index * 4 + payload_mode) << 24) + (func_lsb & 0xff) << 16 + (data & 0xffff)
        self.write_sensor_i2c (num_sensor = num_sensor,
                               rel_addr = rel_addr,
                               addr = addr,
                               data = wdata)
        
    def write_sensor_reg16(self,
                           num_sensor,
                           reg_addr16,
                           reg_data16):
        """
        Write i2c register in immediate mode
        @param num_sensor - sensor port number (0..3), or "all" - same to all sensors
        @param reg_addr16 - 16-bit register address (page+low byte, for MT9P006 high byte is an 8-bit slave address = 0x90)
        @param reg_data16 - 16-bit data to write to sensor register
        """
        self.write_sensor_i2c (num_sensor = num_sensor,
                               rel_addr = True,
                               addr = 0,
                               data = ((reg_addr16 & 0xffff) << 16) | (reg_data16 & 0xffff) )

    def write_sensor_i2c (self,
                          num_sensor,
                          rel_addr,
                          addr,
                          data):
        """
        Write i2c command to the i2c command sequencer
        @param num_sensor - sensor port number (0..3), or "all" - same to all sensors
        @param rel_addr - True - relative frame address, False - absolute frame address
        @param addr - frame address (0..15)
        @param data - depends on context:
                      1 - register write: index page, 3 payload bytes. Payload bytes are used according to table and sent
                          after the slave address and optional high address byte other bytes are sent in descending order (LSB- last).
                          If less than 4 bytes are programmed in the table the high bytes (starting with the one from the table) are
                          skipped.
                          If more than 4 bytes are programmed in the table for the page (high byte), one or two next 32-bit words
                          bypass the index table and all 4 bytes are considered payload ones. If less than 4 extra bytes are to be
                          sent for such extra word, only the lower bytes are sent.
                      2 - register read: index page, slave address (8-bit, with lower bit 0) and one or 2 address bytes (as programmed
                          in the table. Slave address is always in byte 2 (bits 23:16), byte1 (high register address) is skipped if
                          read address in the table is programmed to be a single-byte one
        """
        try:
            if (num_sensor == all) or (num_sensor[0].upper() == "A"): #all is a built-in function
                for num_sensor in range(4):
                    self.write_sensor_i2c (num_sensor = num_sensor,
                                           rel_addr =   rel_addr,
                                           addr =       addr,
                                           data =       data)
                return
        except:
            pass
        reg_addr =  (vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC)
        reg_addr += ((vrlg.SENSI2C_ABS_RADDR,vrlg.SENSI2C_REL_RADDR)[rel_addr] )
        reg_addr += (addr & ~vrlg.SENSI2C_ADDR_MASK);
        self.x393_axi_tasks.write_control_register(reg_addr, data)

    def read_sensor_i2c (self,
                         num_sensor,
                         num_bytes = None,
                         verbose = 0):
        """
        Read sequence of bytes available
        @param num_sensor - sensor port number (0..3), or "all" - same to all sensors
        @param num_bytes - number of bytes to read (None - all in FIFO)
        @verbose - verbose level
        @return list of read bytes
        """
        ODDEVEN="ODDEVEN"
        DAV = "DAV"
        DATA = "DATA"
        def read_i2c_data(num_sensor):
            addr = vrlg.SENSI2C_STATUS_REG_BASE + num_sensor * vrlg.SENSI2C_STATUS_REG_INC + vrlg.SENSI2C_STATUS_REG_REL
            d = self.x393_axi_tasks.read_status(addr)
            return {ODDEVEN : (d >> 9) & 1, DAV : (d >> 8) & 1, DATA : d & 0xff}

        timeout = 1.0 # sec
        end_time = time.time() + timeout
        rslt = []
        while True:
            d = read_i2c_data(num_sensor)
            if not d[DAV]:
                if num_bytes is None:
                    break # no data available in FIFO and number of bytes is not specified
                while (time.time() < end_time) and (not d[DAV]): # wait for data available
                    d = read_i2c_data(num_sensor)
                if not d[DAV]:
                    break # no data available - timeout
            rslt.append(d[DATA])
            # advance to the next data byte
            oddeven = d[ODDEVEN]
            self. set_sensor_i2c_command (
                                num_sensor =   num_sensor,
                                advance_FIFO = True,
                                verbose =      verbose)
            # wait until odd/even bit reverses (no timeout here)
            while d[ODDEVEN] == oddeven:
                d = read_i2c_data(num_sensor)
            if len(rslt) == num_bytes:
                break # read all that was requested (num_bytes == None will not get here)
        return  rslt

    def print_sensor_i2c (self,
                          num_sensor,
                          reg_addr,
                          indx =  1,
                          sa7   = 0x48,
                          verbose = 1):
        """
        Read sequence of bytes available and print the result as a single hex number
        @param num_sensor - sensor port number (0..3), or "all" - same to all sensors
        @param reg_addr - register to read address 1/2 bytes (defined by previously set format)
        @param indx - i2c command index in 1 256-entry table (defines here i2c delay, number of address bytes and number of data bytes)
        @param sa7 - 7-bit i2c slave address
        @param verbose - verbose level
        """
        #clean up FIFO
        dl = self.read_sensor_i2c (num_sensor = num_sensor,
                                   num_bytes = None,
                                   verbose = verbose)
        if len(dl):
            d = 0
            for b in dl:
                d = (d << 8) | (b & 0xff)
            fmt="FIFO contained %d bytes i2c data = 0x%%0%dx"%(len(dl),len(dl*2))
            print (fmt%(d))
        #create and send i2c command in ASAP mode:
        i2c_cmd = ((indx & 0xff) << 24) | (sa7 <<17) | (reg_addr & 0xffff)
        #write_sensor_i2c  0 1 0 0x91900004
        self.write_sensor_i2c(num_sensor = num_sensor,
                              rel_addr = 1,
                              addr = 0,
                              data = i2c_cmd)
        time.sleep(0.05) # We do not know how many bytes are expected, so just wait long enough and hope all bytes are in fifo already



        dl = self.read_sensor_i2c (num_sensor = num_sensor,
                                   num_bytes = None,
                                   verbose = verbose)
        if len(dl):
            d = 0
            for b in dl:
                d = (d << 8) | (b & 0xff)
            if verbose > 0:
                fmt="i2c data[0x%02x:0x%x] = 0x%%0%dx"%(sa7,reg_addr,len(dl)*2)
                print (fmt%(d))
        return d

    def set_sensor_flipXY(self,
                                  num_sensor,
                                  flip_x =  False,
                                  flip_y =  False,
                                  verbose = 1):
        """
        Set sensor horizontal and vertical mirror (flip)
        @param num_sensor - sensor number or "all"
        @param flip_x -  mirror image around vertical axis
        @param flip_y -  mirror image around horizontal axis
        @param verbose - verbose level
        """
        sensorType = self.getSensorInterfaceType()
        if flip_x is None:
            flip_x = False
        if flip_y is None:
            flip_y = False

        if sensorType == "PAR12":
            data = (0,0x8000)[flip_y] | (0,0x4000)[flip_x]
            self.write_sensor_reg16 (num_sensor = num_sensor,
                                     reg_addr16 = 0x9020,
                                     reg_data16 = data)
        elif sensorType == "HISPI":
            data = (0,0x8000)[flip_y] | (0,0x4000)[flip_x] | 0x41
            self.write_sensor_reg16 (num_sensor = num_sensor,
                                     reg_addr16 = 0x3040,
                                     reg_data16 = data)
        else:
            raise ("Unknown sensor type: %s"%(sensorType))

    def set_sensor_gains_exposure(self,
                                  num_sensor,
                                  gain_r =   None,
                                  gain_gr =  None,
                                  gain_gb =  None,
                                  gain_b =   None,
                                  exposure = None,
                                  verbose =  1):
        """
        Set sensor analog gains (raw register values) and
        exposure (in scan lines)
        @param num_sensor - sensor number or "all"
        @param gain_r -   RED gain
        @param gain_gr -  GREEN in red row gain
        @param gain_gb -  GREEN in blue row gain
        @param gain_b -   BLUE gain
        @param exposure - exposure time in scan lines
        @param verbose -  verbose level
        """
        sensorType = self.getSensorInterfaceType()
        if sensorType == "PAR12":
            if not gain_r is None:
                self.write_sensor_reg16 (num_sensor = num_sensor,
                                         reg_addr16 = 0x902d,
                                         reg_data16 = gain_r)
            if not gain_gr is None:
                self.write_sensor_reg16 (num_sensor = num_sensor,
                                         reg_addr16 = 0x902b,
                                         reg_data16 = gain_gr)
            if not gain_gb is None:
                self.write_sensor_reg16 (num_sensor = num_sensor,
                                         reg_addr16 = 0x902e,
                                         reg_data16 = gain_gb)
            if not gain_b is None:
                self.write_sensor_reg16 (num_sensor = num_sensor,
                                         reg_addr16 = 0x902c,
                                         reg_data16 = gain_b)
            if not exposure is None:
                self.write_sensor_reg16 (num_sensor = num_sensor,
                                         reg_addr16 = 0x9009,
                                         reg_data16 = exposure)
        elif sensorType == "HISPI":
            if not gain_r is None:
                self.write_sensor_reg16 (num_sensor = num_sensor,
                                         reg_addr16 = 0x208,
                                         reg_data16 = gain_r)
            if not gain_gr is None:
                self.write_sensor_reg16 (num_sensor = num_sensor,
                                         reg_addr16 = 0x206, # SMIA register
                                         reg_data16 = gain_gr)
            if not gain_gb is None:
                self.write_sensor_reg16 (num_sensor = num_sensor,
                                         reg_addr16 = 0x20c, # SMIA register
                                         reg_data16 = gain_gb)
            if not gain_b is None:
                self.write_sensor_reg16 (num_sensor = num_sensor,
                                         reg_addr16 = 0x20a, # SMIA register
                                         reg_data16 = gain_b)
            if not exposure is None:
                self.write_sensor_reg16 (num_sensor = num_sensor,
                                         reg_addr16 = 0x202, # SMIA register
                                         reg_data16 = exposure)
        else:
            raise ("Unknown sensor type: %s"%(sensorType))

    def set_sensor_io_ctl (self,
                           num_sensor,
                           mrst =       None,
                           arst =       None,
                           aro  =       None,
                           mmcm_rst =   None,
                           clk_sel =    None,
                           set_delays = False,
                           quadrants =  None):
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
        try:
            if (num_sensor == all) or (num_sensor[0].upper() == "A"): #all is a built-in function
                for num_sensor in range(4):
                    self.set_sensor_io_ctl (num_sensor,
                           mrst =       mrst,
                           arst =       arst,
                           aro  =       aro,
                           mmcm_rst =   mmcm_rst,
                           clk_sel =    clk_sel,
                           set_delays = set_delays,
                           quadrants =  quadrants)
                return
        except:
            pass


        data = self.func_sensor_io_ctl (
                    mrst =       mrst,
                    arst =       arst,
                    aro =        aro,
                    mmcm_rst =   mmcm_rst,
                    clk_sel =    clk_sel,
                    set_delays = set_delays,
                    quadrants =  quadrants)

        reg_addr = (vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC) + vrlg.SENSIO_RADDR + vrlg.SENSIO_CTRL;
        self.x393_axi_tasks.write_control_register(reg_addr, data)
# TODO: Make one for HiSPi (it is different)

    def set_sensor_io_ctl_lwir (self,
                                 num_sensor,
                                 rst =        None,
                                 rst_seq =    None,
                                 spi_seq =    None,
                                 mclk  =      None,
                                 spi_en =     None, # 1 - reset+disable, 2 - noreset, disable, 3 - noreset, enable
                                 segm_zero =  None,
                                 out_en =     None,
                                 out_single = False,
                                 reset_crc =  False,
                                 spi_clk =    None,
                                 gpio0 =      None, 
                                 gpio1 =      None, 
                                 gpio2 =      None, 
#                                 gpio3 =      None,
                                 telemetry =  None, 
                                 vsync_use =  None,
                                 noresync =   None,
                                 dbg_src =    None):
        """
        Combine sensor I/O control parameters into a control word
        @param rst -        Sensor reset/power down control (0 - NOP, 1 - power down + reset, 2 - no pwdn, reset, 3 - no pwdn, no reset
        @param rst_seq      Initiate simultaneous all sensors reset, generate SOF after pause
        @param spi_seq      Initiate VOSPI reset, will generate normal SOF if successful
        @param mclk -       True - enable master clock (25MHz) to sensor, False - disable, None - no change
        @param spi_en -     True - SPI reset/enable: 0 - NOP, 1 - reset+disable, 2 - noreset, disable, 3 - noreset, enable, None - no change 
        @param segm_zero =  True - allow receiving segment ID==0 (ITAR invalid), False - disallow, None - no change,
        @param out_en =     True - enable continuously receiving data to memory, False - disable, None - no change
        @param out_single = True - acquire single frame,
        @param reset_crc =  True - reset CRC error status bit,
        @param spi_clk =    True - generate SPI clock during inactive SPI CS, False - do not generate SPI CLK when CS is inactive, None - no change
        @param gpio0 =      Output control for GPIO0: 0 - nop, 1 - set low, 2 - set high, 3 - input
        @param gpio1 =      Output control for GPIO0: 1 - nop, 1 - set low, 2 - set high, 3 - input 
        @param gpio2 =      Output control for GPIO0: 2 - nop, 1 - set low, 2 - set high, 3 - input 
        @param telemetry =  Enable (1) /disable (0) telemetry data lines (should be set in the sensor too, or it will hang)
        @param vsync_use =  Wait for VSYNC (should be enabled over i2c) before reading each segment
        @param noresync =   Disable resynchronization by discard packets
        @param dbg_src =    source of the hardware debug output: 0 - dbg_running
                                                                 1 - will_sync
                                                                 2 - vsync_rdy[1]
                                                                 3 - discard_segment
                                                                 4 - in_busy
                                                                 5 - out_busy
                                                                 6 - hact
                                                                 7 - sof
        """
        try:
            if (num_sensor == all) or (num_sensor[0].upper() == "A"): #all is a built-in function
                for num_sensor in range(4):
                    self.set_sensor_io_ctl_lwir (num_sensor,
                           rst =        rst,
                           rst_seq =    rst_seq,
                           spi_seq =    spi_seq,
                           mclk  =      mclk,
                           spi_en =     spi_en,
                           segm_zero =  segm_zero,
                           out_en =     out_en,
                           out_single = out_single,
                           reset_crc =  reset_crc,
                           spi_clk =    spi_clk,
                           gpio0 =      gpio0, 
                           gpio1 =      gpio1, 
                           gpio2 =      gpio2, 
#                           gpio3 =      gpio3, 
                           telemetry =  telemetry, 
                           vsync_use =  vsync_use,
                           noresync =   noresync,
                           dbg_src =    dbg_src)
                return
        except:
            pass
        data = self.func_sensor_io_ctl_lwir (
                           rst =        rst,
                           rst_seq =    rst_seq,
                           spi_seq =    spi_seq,
                           mclk  =      mclk,
                           spi_en =     spi_en,
                           segm_zero =  segm_zero,
                           out_en =     out_en,
                           out_single = out_single,
                           reset_crc =  reset_crc,
                           spi_clk =    spi_clk,
                           gpio0 =      gpio0, 
                           gpio1 =      gpio1, 
                           gpio2 =      gpio2, 
#                           gpio3 =      gpio3, 
                           telemetry =  telemetry, 
                           vsync_use =  vsync_use,
                           noresync =   noresync,
                           dbg_src =    dbg_src)

        reg_addr = (vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC) + vrlg.SENSIO_RADDR + vrlg.SENSIO_CTRL;
        self.x393_axi_tasks.write_control_register(reg_addr, data)

    def set_sensor_io_ctl_boson (self,
                           num_sensor,
                            mrst =       None,
                            mmcm_rst =   None,
                            set_delays = False,
                            gpio0 =      None,
                            gpio1 =      None,
                            gpio2 =      None,
                            gpio3 =      None):
        """
        Set sensor I/O controls, including I/O signals
        @param num_sensor - sensor port number (0..3)
        @param mrst -  True - activate MRST signal (low), False - deactivate MRST (high), None - no change
        @param mmcm_rst - True - activate MMCM reset, False - deactivate MMCM reset, None - no change (needed after clock change/interruption)
        @param set_delays - (self-clearing) load all pre-programmed delays for the sensor pad inputs
        @param gpio0 -   GPIO[0]: 0 - float(input), 1 - out low, 2 out high, 3 - pulse high
        @param gpio1 -   GPIO[1]: 0 - float(input), 1 - out low, 2 out high, 3 - pulse high
        @param gpio2 -   GPIO[2]: 0 - float(input), 1 - out low, 2 out high, 3 - pulse high
        @param gpio3 -   GPIO[3]: 0 - float(input), 1 - out low, 2 out high, 3 - pulse high
        """
        try:
            if (num_sensor == all) or (num_sensor[0].upper() == "A"): #all is a built-in function
                for num_sensor in range(4):
                    self.set_sensor_io_ctl_boson (num_sensor,
                            mrst =       mrst,
                            mmcm_rst =   mmcm_rst,
                            set_delays = set_delays,
                            gpio0 =      gpio0,
                            gpio1 =      gpio1,
                            gpio2 =      gpio2,
                            gpio3 =      gpio3)
                return
        except:
            pass


        data = self.func_sensor_io_ctl_boson (
                            mrst =       mrst,
                            mmcm_rst =   mmcm_rst,
                            set_delays = set_delays,
                            gpio0 =      gpio0,
                            gpio1 =      gpio1,
                            gpio2 =      gpio2,
                            gpio3 =      gpio3)

        reg_addr = (vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC) + vrlg.SENSIO_RADDR + vrlg.SENSIO_CTRL;
        self.x393_axi_tasks.write_control_register(reg_addr, data)

    def set_sensor_uart_ctl_boson (self,
                           num_sensor,
                            uart_extif_en =   None,
                            uart_xmit_rst =   None,
                            uart_recv_rst =   None,
                            uart_xmit_start = False,
                            uart_recv_next = False):
        """
        Set sensor UART control signals
        @param num_sensor - sensor port number (0..3)
        @param uart_extif_en -   True - enable sequencer commands, False - disable sequencer commands
        @param uart_xmit_rst -   True - persistent reset software packet transmission, False - disable reset software packet transmission (normal operation)
        @param uart_recv_rst -   True - persistent reset packet receive, False - disable reset packet receive (normal operation)
        @param uart_xmit_start - start transmiting prepared packet
        @param uart_recv_next -  advance receive FIFO to next byte
        """
        try:
            if (num_sensor == all) or (num_sensor[0].upper() == "A"): #all is a built-in function
                for num_sensor in range(4):
                    self.set_sensor_uart_ctl_boson (num_sensor,
                            uart_extif_en =   uart_extif_en,
                            uart_xmit_rst =   uart_xmit_rst,
                            uart_recv_rst =   uart_recv_rst,
                            uart_xmit_start = uart_xmit_start,
                            uart_recv_next =  uart_recv_next)
                return
        except:
            pass


        data = self.func_sensor_uart_ctl_boson (
                            uart_extif_en =   uart_extif_en,
                            uart_xmit_rst =   uart_xmit_rst,
                            uart_recv_rst =   uart_recv_rst,
                            uart_xmit_start = uart_xmit_start,
                            uart_recv_next =  uart_recv_next)

        reg_addr = (vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC) + vrlg.SENSIO_RADDR + (vrlg.SENSIO_DELAYS + 1);
        self.x393_axi_tasks.write_control_register(reg_addr, data)

    def set_sensor_uart_fifo_byte_boson (self,
                           num_sensor,
                           uart_tx_byte):
        """
        Write byte tio the sensor UART transmit FIFO
        @param num_sensor - sensor port number (0..3)
        @param uart_tx_byte - Byte to write to FIFO
        """
        try:
            if (num_sensor == all) or (num_sensor[0].upper() == "A"): #all is a built-in function
                for num_sensor in range(4):
                    self.set_sensor_uart_fifo_byte_boson (num_sensor,
                            uart_tx_byte =   uart_tx_byte)
                return
        except:
            pass


        data = uart_tx_byte & 0xff;

        reg_addr = (vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC) + vrlg.SENSIO_RADDR + (vrlg.SENSIO_DELAYS + 0);
        self.x393_axi_tasks.write_control_register(reg_addr, data)

# TODO: Make one for HiSPi (it is different)
    def set_sensor_io_dly_parallel (self,
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
        self.x393_axi_tasks.write_control_register(reg_addr + 0, dlys[0]) # {pxd3,       pxd2,  pxd1, pxd0}
        self.x393_axi_tasks.write_control_register(reg_addr + 1, dlys[1]) # {pxd7,       pxd6,  pxd5, pxd4}
        self.x393_axi_tasks.write_control_register(reg_addr + 2, dlys[2]) # {pxd11,      pxd10, pxd9, pxd8}
        self.x393_axi_tasks.write_control_register(reg_addr + 3, dlys[3]) # {mmcm_phase, bpf,   vact, hact}
        self.set_sensor_io_ctl (num_sensor = num_sensor,
                                set_delays = True)

    def set_sensor_io_dly_hispi (self,
                                    num_sensor,
                                    mmcm_phase = None, #24 steps in 3ns period
                                    lane0_dly =  None,
                                    lane1_dly =  None,
                                    lane2_dly =  None,
                                    lane3_dly =  None):
        """
        Set sensor port input delays and mmcm phase
        @param num_sensor - sensor port number (0..3) or all, 'A'
        @param mmcm_phase - MMCM clock phase
        @param lane0_dly - delay in the lane0 (3 LSB are not used) // All 4 lane delays should be set simultaneously
        @param lane1_dly - delay in the lane1 (3 LSB are not used)
        @param lane2_dly - delay in the lane2 (3 LSB are not used)
        @param lane3_dly - delay in the lane3 (3 LSB are not used))
        """
        try:
            if (num_sensor == all) or (num_sensor[0].upper() == "A"): #all is a built-in function
                for num_sensor in range(4):
                    self.set_sensor_io_dly_hispi (num_sensor = num_sensor,
                                                  mmcm_phase = mmcm_phase,
                                                  lane0_dly =  lane0_dly,
                                                  lane1_dly =  lane1_dly,
                                                  lane2_dly =  lane2_dly,
                                                  lane3_dly =  lane3_dly)
                return
        except:
            pass
        reg_addr = (vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC) + vrlg.SENSIO_RADDR + vrlg.SENSIO_DELAYS
        try: # if any delay is None - do not set
            dlys=(lane0_dly & 0xff) | ((lane1_dly & 0xff) << 8) | ((lane2_dly & 0xff) << 16) | ((lane3_dly & 0xff) << 24)
            self.x393_axi_tasks.write_control_register(reg_addr + 2, dlys)
        except:
            pass
        if not mmcm_phase is None:
            self.x393_axi_tasks.write_control_register(reg_addr + 3, mmcm_phase & 0xff)

    def set_sensor_hispi_lanes(self,
                               num_sensor,
                               lane0 = 0,
                               lane1 = 1,
                               lane2 = 2,
                               lane3 = 3):
        """
        Set HiSPi sensor lane map (physical lane for each logical lane)
        @param num_sensor - sensor port number (0..3)
        @param lane0 - physical (input) lane number for logical (internal) lane 0
        @param lane1 - physical (input) lane number for logical (internal) lane 1
        @param lane2 - physical (input) lane number for logical (internal) lane 2
        @param lane3 - physical (input) lane number for logical (internal) lane 3
        """
        data = ((lane0 & 3) << 0 ) | ((lane1 & 3) << 2 ) | ((lane2 & 3) << 4 ) | ((lane3 & 3) << 6 )
        reg_addr = (vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC) + vrlg.SENSIO_RADDR + vrlg.SENSIO_DELAYS;
        self.x393_axi_tasks.write_control_register(reg_addr + 1, data)

    def set_sensor_fifo_lag(self,
                            num_sensor,
                            fifo_lag = 7):
        """
        Set HiSPi sensor FIFO lag (when to start line output, ~= 1/2 FIFO size)
        @param num_sensor - sensor port number (0..3)
        @param fifo_lag - number of pixels to write to FIFO before starting output
        """
        reg_addr = (vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC) + vrlg.SENSIO_RADDR + vrlg.SENSIO_DELAYS;
        self.x393_axi_tasks.write_control_register(reg_addr + 0, fifo_lag)

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
        self.x393_axi_tasks.write_control_register(reg_addr, data)

#    def jtag_prep_status(self, chn):
#        seq_num = ((self.get_status_sensor_io(num_sensor = chn) >> 26) + 1) & 0x3f
#        self.program_status_sensor_io(num_sensor = num_sensor,
#                                      mode = 1,     # input [1:0] mode;
#                                      seq_num = seq_num) # input [5:0] seq_num;
#        return seq_num

    def uart_send_packet(self,
                         num_sensor,
                         command,
                         data, #bytearray
                         wait_ready=True,
                         reset_recv=True,
                         reset_xmit=True):
        """
        Send packet to UART
        @param num_sensor - sensor port number (0..3)
        @param command - Full command code (module+function)
        @param data -  Byte array to transmit
        @param wait_ready Wait until all data is sent to UART
        @param reset_recv Reset UART receive channel simultaneously with transmit one
        @param reset_xmit Reset UART transmit channel before sending bytes
        Note: sequencer commands are disabled (may be (re)-enabled after reading response
        """
        
        if self.uart_seq_number < 0x100:
            self.uart_seq_number= 0xabcde100 + (self.uart_seq_number & 0xffffffff)
        packet = bytearray()
        packet.append(0) # channel number == 0
        for b in (self.uart_seq_number).to_bytes(4,byteorder='big'):
            packet.append(b)
        for b in (command).to_bytes(4,byteorder='big'): #command
            packet.append(b)
        for b in (0xffffffff).to_bytes(4,byteorder='big'): # status
            packet.append(b)
        for b in data: # data
            packet.append(b)
        #reset XMIT channe, disable sequencer     
        #write data to FIFO, no need to wait
        if reset_xmit:            
            self.set_sensor_uart_ctl_boson (
                            num_sensor = num_sensor,
                            uart_extif_en =   False,
                            uart_xmit_rst =   True,
                            uart_recv_rst = reset_recv)
        self.set_sensor_uart_ctl_boson (
                        num_sensor = num_sensor,
                        uart_xmit_rst =   False,
                        uart_recv_rst =   False)
        print(packet)
        for b in packet:
            self.set_sensor_uart_fifo_byte_boson (
                        num_sensor=num_sensor,
                        uart_tx_byte = b)
        self.set_sensor_uart_ctl_boson ( # start command
                        num_sensor = num_sensor,
                        uart_xmit_start = True)
            
            
        self.uart_seq_number= (self.uart_seq_number + 1) & 0xffffffff
        if wait_ready:
            while ((self.get_new_status(num_sensor=num_sensor) >> 25) & 1 )!= 0:
                pass

    def get_new_status(self,num_sensor): # same as jtag_get_tdo(self, chn):
        seq_num = ((self.get_status_sensor_io(num_sensor = num_sensor) >> 26) + 1) & 0x3f
        self.program_status_sensor_io(num_sensor = num_sensor,
                                      mode = 1,     # input [1:0] mode;
                                      seq_num = seq_num) # input [5:0] seq_num;
        stat = None
        for _ in range(10):
            stat = self.get_status_sensor_io(num_sensor = num_sensor)
            if seq_num == ((stat >> 26) & 0x3f):
                break
        else:
            print ("wait_sensio_status(): Failed to get seq_num== 0x%x, current is 0x%x"%(seq_num, (stat >> 26) & 0x3f))
        return stat
                
    def uart_print_packet(self,
                         num_sensor,
                         wait_packet =      True,
                         enable_sequencer = True):
        """
        Send packet to UART
        @param num_sensor - sensor port number (0..3)
        @param wait packet - if False, return empty packet if none is available
        @param enable_sequencer (Re)enable sequencer commands
        """
        packet = self.uart_receive_packet(
                         num_sensor =       num_sensor,
                         wait_packet =      wait_packet,
                         enable_sequencer = enable_sequencer)
        print ("received UART packet: ", end="")
        for b in packet:
            print (hex(b), end=", ")
        print()    
                
                
    def uart_receive_packet(self,
                         num_sensor,
                         wait_packet =      True,
                         enable_sequencer = True):
        """
        Send packet to UART
        @param num_sensor - sensor port number (0..3)
        @param wait packet - if False, return empty packet if none is available
        @param enable_sequencer (Re)enable sequencer commands
        """
        
        recv_pav = False
        packet = bytearray()
        while not recv_pav: # wait full packet is in FIFO
            sensor_status = self.get_new_status(num_sensor=num_sensor)
            recv_pav = ((sensor_status >> 14) & 1) != 0
#            recv_eop = ((sensor_status >> 15) & 1) != 0
#            ready = recv_dav and (not recv_prgrs)
            if not wait_packet:
                break
        if not recv_pav:
            return packet # empty bytearray    
        #read byte array. TODO: improve waiting for tghe next byte?
#        packet = bytearray()
        recv_eop = False
        while not recv_eop:
            sensor_status = self.get_new_status(num_sensor=num_sensor)
            recv_eop = ((sensor_status >> 15) & 1) != 0
            recv_data =  (sensor_status >> 16) & 0xff
            self.set_sensor_uart_ctl_boson ( # next byte
                            num_sensor = num_sensor,
                            uart_recv_next = True)
            if not recv_eop:
                packet.append(recv_data)
        #        
        return packet        

    def jtag_get_tdo(self, chn):
        seq_num = ((self.get_status_sensor_io(num_sensor = chn) >> 26) + 1) & 0x3f
        self.program_status_sensor_io(num_sensor = chn,
                                      mode = 1,     # input [1:0] mode;
                                      seq_num = seq_num) # input [5:0] seq_num;

        for _ in range(10):
            stat = self.get_status_sensor_io(num_sensor = chn)
            if seq_num == ((stat >> 26) & 0x3f):
                break
        else:
            print ("wait_sensio_status(): Failed to get seq_num== 0x%x, current is 0x%x"%(seq_num, (stat >> 26) & 0x3f))
        return (stat >> 25) & 1



    def jtag_send(self, chn, tms, ln, d):
        i = ln & 7
        if (i == 0):
            i = 8
        d &= 0xff;
        r = 0
        while i > 0:
            self.set_sensor_io_jtag (num_sensor = chn,
                            pgmen = None,
                            prog =  None,
                            tck =   0,
                            tms =   tms,
                            tdi =   ((d << 1) >> 8) & 1)
            d <<= 1
            r = (r << 1) + self.jtag_get_tdo(chn)
            self.set_sensor_io_jtag (num_sensor = chn,
                            pgmen = None,
                            prog =  None,
                            tck =   1,
                            tms =   None,
                            tdi =   None)
            self.set_sensor_io_jtag (num_sensor = chn,
                            pgmen = None,
                            prog =  None,
                            tck =   0,
                            tms =   None,
                            tdi =   None)
            i -= 1
        return r

    def jtag_write_bits (self,
                         chn,
                         buf,    # data to write
                         ln,     # number of bits to write
#                         check,  # compare readback data with previously written, abort on mismatch
                         last):   # output last bit with TMS=1
#                         prev = None): # if null - don't use
        rbuf = []
        r = 0
        for d0 in buf:
            d=d0
            for _ in range(8):
                if ln >0:
                    self.set_sensor_io_jtag (num_sensor = chn,
                                    pgmen = None,
                                    prog =  None,
                                    tck =   0,
                                    tms =   (0,1)[(ln == 1) and last],
                                    tdi =   ((d << 1) >> 8) & 1)
                    d <<= 1
                    r = (r << 1) + self.jtag_get_tdo(chn)
                    self.set_sensor_io_jtag (num_sensor = chn,
                                    pgmen = None,
                                    prog =  None,
                                    tck =   1,
                                    tms =   None,
                                    tdi =   None)
                    self.set_sensor_io_jtag (num_sensor = chn,
                                    pgmen = None,
                                    prog =  None,
                                    tck =   0,
                                    tms =   None,
                                    tdi =   None)
                else:
                    r <<= 1
                ln -= 1
            rbuf.append(r & 0xff)

        return rbuf

    def jtag_set_pgm_mode(self,chn,en):
        self.set_sensor_io_jtag (num_sensor = chn,
                        pgmen = en,
                        prog =  None,
                        tck =   0,
                        tms =   None,
                        tdi =   None)

    def jtag_set_pgm(self,chn,en):
        self.set_sensor_io_jtag (num_sensor = chn,
                        pgmen = None,
                        prog =  en,
                        tck =   0,
                        tms =   None,
                        tdi =   None)


    def JTAG_openChannel (self, chn):
        self.jtag_set_pgm_mode (chn, 1);
        self.jtag_set_pgm      (chn, 1)
        self.jtag_set_pgm      (chn, 0)
        time.sleep        (0.01)
        self.jtag_send    (chn, 1, 5, 0 ) # set Test-Logic-Reset state
        self.jtag_send    (chn, 0, 1, 0 ) # set Run-Test-Idle state

    def JTAG_EXTEST     (self,  chn, buf, ln):
#        self.jtag_send(chn, 1, 5, 0   ) # step 1 - set Test-Logic-Reset state
#        self.jtag_send(chn, 0, 1, 0   ) # step 2 - set Run-Test-Idle state
        self.jtag_send(chn, 1, 2, 0   ) # step 3 - set SELECT-IR state
        self.jtag_send(chn, 0, 2, 0   ) # step 4 - set SHIFT-IR state
        self.jtag_send(chn, 0, 5, 0xf0) # step 5 - start of EXTEST
        self.jtag_send(chn, 1, 1, 0   ) # step 6 - finish EXTEST
        self.jtag_send(chn, 1, 2, 0   ) # step 7 - set SELECT-DR state
        self.jtag_send(chn, 0, 2, 0   ) # step 8 - set CAPTURE-DR state

        rbuf = self.jtag_write_bits (chn = chn,
                                     buf = buf,    # data to write
                                     ln =  ln,     # number of bytes to write
                                     last = 1)
        self.jtag_send(chn, 1, 1, 0   ) #step 9 - set UPDATE-DR state
        return rbuf



# /dev/sfpgabscan0
    def readbscan(self, filename):
        ffs=(struct.pack("B",0xff)*97).decode('iso-8859-1')
        with open(filename,'r+') as jtag:
            jtag.write(ffs)
            jtag.seek (0,0)
            boundary= jtag.read(97)
        return boundary

    def checkSclSda(self, chn, verbose = 1):
        '''
        Check which board is connected to the sensor board
        @param chn - sensor port number (0..3)
        @param verbose - if >0, print debug output
        @return - name of the FPGA-based board detected, "sensor" (grounded pad 7) or "" if none detected
        '''
        def print_i2c(chn):
            self.program_status_sensor_i2c(num_sensor = chn, mode = 1, seq_num = 0)
            status= self.get_status_sensor_i2c(num_sensor = chn)
            sda_in =(status>>25) & 1
            scl_in =(status>>24) & 1
            print ("chn = %d, scl = %d, sda = %d"%(chn,scl_in, sda_in))

        def print_bv(chn, boundary, value, key):
            self.program_status_sensor_i2c(num_sensor = chn, mode = 1, seq_num = 0)
            status= self.get_status_sensor_i2c(num_sensor = chn)
            sda_in =(status>>25) & 1
            scl_in =(status>>24) & 1
            print ("%d: sda = %d, bit number SDA = %d, pin value SDA = %d"%(key, sda_in, value['sda'], (((ord(boundary[value['sda'] >> 3]) >> (7 -(value['sda'] & 7))) &1)) ))
            print ("%d: scl = %d, bit number SCL = %d, pin value SCL = %d"%(key, scl_in, value['scl'], (((ord(boundary[value['scl'] >> 3]) >> (7 -(value['scl'] & 7))) &1)) ))


        boards = [{'model':'10347', 'scl': 241,'sda': 199},  #// E4, C1
                  {'model':'10359', 'scl': 280,'sda': 296}]  #// H6, J5
        bscan_path=('/dev/sfpgabscan%d'%(chn))
        self. program_status_sensor_io(num_sensor = chn, mode = 1, seq_num = 0)
        status = self.get_status_sensor_io(num_sensor=chn)
        senspgmin = (status >> 24) & 1
        if not senspgmin:
            print ("Some sensor board is connected to port # %d, not FPGA"%(chn))
            return "sensor"

        test = [1]*len(boards)
        #Stop hardware i2c controller
        self.set_sensor_i2c_command(num_sensor = chn,    run_cmd = False)
        #Set SCL=0, SDA=0 and read values:
        self.set_sensor_i2c_command(num_sensor = chn,    sda = 0,  scl = 0)
        if verbose > 0:
            print_i2c(chn = chn)
        boundary = self.readbscan(bscan_path)
        for key, value in enumerate(boards):
            test[key] &= ((((ord(boundary[value['sda'] >> 3]) >> (7 -(value['sda'] & 7))) &1) == 0) and
                          (((ord(boundary[value['scl'] >> 3]) >> (7 -(value['scl'] & 7))) &1) == 0))
            if verbose >0:
                print_bv(chn=chn, boundary = boundary, value = value, key=key)
        #Set SCL=1, SDA=0 and read values:
        self.set_sensor_i2c_command(num_sensor = chn,    sda = 0,  scl = 1)
        boundary = self.readbscan(bscan_path)
        for key, value in enumerate(boards):
            test[key] &= ((((ord(boundary[value['sda'] >> 3]) >> (7 -(value['sda'] & 7))) &1) == 0) and
                          (((ord(boundary[value['scl'] >> 3]) >> (7 -(value['scl'] & 7))) &1) == 1))
            if verbose >0:
                print_bv(chn=chn, boundary = boundary, value = value, key=key)
        #Set SCL=0, SDA=1 and read values:
        self.set_sensor_i2c_command(num_sensor = chn,    sda = 1,  scl = 0)
        boundary = self.readbscan(bscan_path)
        for key, value in enumerate(boards):
            test[key] &= ((((ord(boundary[value['sda'] >> 3]) >> (7 -(value['sda'] & 7))) &1) == 1) and
                          (((ord(boundary[value['scl'] >> 3]) >> (7 -(value['scl'] & 7))) &1) == 0))
            if verbose >0:
                print_bv(chn=chn, boundary = boundary, value = value, key=key)
        #Set SCL=1, SDA=1 and read values:
        self.set_sensor_i2c_command(num_sensor = chn,    sda = 1,  scl = 1)
        boundary = self.readbscan(bscan_path)
        for key, value in enumerate(boards):
            test[key] &= ((((ord(boundary[value['sda'] >> 3]) >> (7 -(value['sda'] & 7))) &1) == 1) and
                          (((ord(boundary[value['scl'] >> 3]) >> (7 -(value['scl'] & 7))) &1) == 1))
            if verbose >0:
                print_bv(chn=chn, boundary = boundary, value = value, key=key)
        for key, value in enumerate(boards):
            if test[key]:
                if verbose >0:
                    print ("Detected FPGA-based board :%s"%(value['model']))
                return value['model']
        return ""


    """
   def set_sensor_i2c_command (self,
                                num_sensor,
                                rst_cmd =         False,
                                run_cmd =         None,
                                active_sda =      None,
                                early_release_0 = None,
                                advance_FIFO =    None,
                                sda =             None,
                                scl =             None,
                                verbose =         1):
        @param num_sensor - sensor port number (0..3)
        @param rst_cmd - reset all FIFO (takes 16 clock pulses), also - stops i2c until run command
        @param run_cmd - True - run i2c, False - stop i2c (needed before software i2c), None - no change
        @param active_sda - pull-up SDA line during second half of SCL=0, when needed and possible
        @param early_release_0 -  release SDA=0 immediately after the end of SCL=1 (SDA hold will be provided by week pullup)
        @param advance_FIFO -     advance i2c read FIFO
        @param sda - control SDA line (stopped mode only): I<nput>, L<ow> or 0, High or 1
        @param scl - control SCL line (stopped mode only): I<nput>, L<ow> or 0, High or 1
        @param verbose -          verbose level
        active_sda and early_release_0 should be defined both to take effect (any of the None skips setting these parameters)
    def program_status_sensor_i2c( self,
                                   num_sensor,
                                   mode,     # input [1:0] mode;
                                   seq_num): # input [5:0] seq_num;

    def print_status_sensor_i2c (self,
                                num_sensor="All"):
        Print sensor_i2c status word (no sync)
        @param num_sensor - number of the sensor port (0..3)
        try:
            if (num_sensor == all) or (num_sensor[0].upper() == "A"): #all is a built-in function
                for num_sensor in range(4):
                    print ("\n ==== Sensor %d"%(num_sensor))
                    self.print_status_sensor_i2c (num_sensor = num_sensor)
                return
        except:
            pass
        status= self.get_status_sensor_i2c(num_sensor)
        print ("print_status_sensor_i2c(%d):"%(num_sensor))
        print ("   reset_on =               %d"%((status>> 7) & 1))
        print ("   req_clr =                %d"%((status>> 6) & 1))
        print ("   wr_full =               %d"%((status>> 5) & 1))

        print ("   busy =                   %d"%((status>> 4) & 1))
        print ("   frame_num =              %d"%((status>> 0)  & 0xf))
        print ("   sda_in =                 %d"%((status>>25) & 1))
        print ("   scl_in =                 %d"%((status>>24) & 1))
        print ("   seq =                    %d"%((status>>26) & 0x3f))


set_sensor_mode 0 0 0 1 0
set_sensor_mode 1 0 0 1 0
set_sensor_mode 2 0 0 1 0
set_sensor_mode 3 0 0 1 0
program_status_sensor_io all 1 0
print_status_sensor_io all



python
import struct
import time
def readbscan(filename):
    ffs=struct.pack("B",0xff)*97
    with open(filename,'r+') as jtag:
        #time.sleep(5)
        jtag.write(ffs)
        #time.sleep(5)
        jtag.seek (0,0)
        #time.sleep(5)
        boundary= jtag.read(97)
        #time.sleep(5)
    return boundary

b = readbscan('/dev/sfpgabscan1')

$boards=array (
                '0' => array ('model' => '10347', 'scl' =>241,'sda' => 199),  // E4, C1
                '1' => array ('model' => '10359', 'scl' =>280,'sda' => 296)   // H6, J5

);
#cd /usr/local/verilog/; test_mcntrl.py -x @hargs
cd /usr/local/verilog/; test_mcntrl.py @hargs
setupSensorsPower "PAR12"
measure_all "*DI"
program_status_sensor_io all 1 0
print_status_sensor_io all
setSensorClock

checkSclSda 1

#cat /usr/local/verilog/x359.bit > /dev/sfpgaconfjtag1


#jtag_set_pgm_mode 0 1
#jtag_set_pgm_mode 1 1
#jtag_set_pgm_mode 2 1
#jtag_set_pgm_mode 3 1

#set_sensor_mode 0 0 0 1 0
#set_sensor_mode 1 0 0 1 0
#set_sensor_mode 2 0 0 1 0
#set_sensor_mode 3 0 0 1 0
set_sensor_io_ctl 1 0 #turn mrst off to enable clocked signal (and to read done!) TODO: Add to the driver

program_status_sensor_io all 1 0
print_status_sensor_io 1 # all


set_sensor_io_ctl (self,

                           num_sensor,
                           mrst =       None,
                           arst =       None,
                           aro  =       None,
                           mmcm_rst =   None,
                           clk_sel =    None,
                           set_delays = False,
                           quadrants =  None):



set_sensor_io_jtag 1 None None None None 0
program_status_sensor_io all 1 0
print_status_sensor_io 1
get_status_sensor_io 1

x393 +0.001s--> set_sensor_io_jtag 1 None None None None 0
x393 +0.001s--> program_status_sensor_io all 1 0
x393 +0.002s--> print_status_sensor_io 1 # all
print_status_sensor_io(1):
   irst =                   0
async_prst_with_sens_mrst = 0
   imrst =                  1
   rst_mmcm =               0
   pxd_out_pre[1] =         0
   vact_alive =             0
   hact_ext_alive =         0
   hact_run =               0
   locked_pxd_mmcm =        1
   clkin_pxd_stopped_mmcm = 0
   clkfb_pxd_stopped_mmcm = 0
   xfpgadone =              1
   ps_rdy =                 1
   ps_out =                 0
   xfpgatdo =               0
   senspgmin =              1
   seq =                    0
x393 +0.001s--> set_sensor_io_jtag 1 None None None None 1
x393 +0.001s--> program_status_sensor_io all 1 0
x393 +0.002s--> print_status_sensor_io 1 # all
print_status_sensor_io(1):
   irst =                   0
async_prst_with_sens_mrst = 0
   imrst =                  1
   rst_mmcm =               0
   pxd_out_pre[1] =         1
   vact_alive =             0
   hact_ext_alive =         0
   hact_run =               0
   locked_pxd_mmcm =        1
   clkin_pxd_stopped_mmcm = 0
   clkfb_pxd_stopped_mmcm = 0
   xfpgadone =              1
   ps_rdy =                 1
   ps_out =                 0
   xfpgatdo =               1
   senspgmin =              1
   seq =                    0


#setSensorClock(self, freq_MHz = 24.0, iface = "2V5_LVDS", quiet = 0)
>>> b = readbscan('/dev/sfpgabscan0')
>>> b
b = '\x00\x00\x00\x00\x00\x00\x00\x00\x08\x00$\x82\x12I\t\x00\x80\x02\x00@\x00\x04\x00\x00@\x00\x00\x00\x00\x00@\x00\x00\x00\x00\x00\x00\x00\x00\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00 \x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
b = '\xff\xff\xff\xff\xff\xff\xff\xff\xf7\xff\xdb}\xed\xb6\xf6\xff\x7f\xfd\xff\xbf\xff\xfb\xff\xff\xbf\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xfb\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xdf\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xf0'
b = '\xff\xff\xff\xff\xff\xff\xff\xff\xf7\xff\xdb}\xed\xb6\xf6\xff\x7f\xfd\xff\xbf\xff\xfb\xff\xff\xbf\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xfb\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xdf\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xf0'

a='ffffffffff7fffffffffffffffffffffffffffffffffffffbfffffffffffffffffffff7fff7ffffffbffffffffffffffffffffffffffffffffffffffffdffffffffffffffffffffff6dfffffffffffffffedf7fdbfedff7ffff6fffeffffffbff0'
al = []
for i in range(len(a)/2):
    al.append(int('0x'+a[2*i:2*i+2],0))

bl = []
for i in b:
    bl.append(ord(i))

for i,x in enumerate(zip(al,bl)):
    print ("%02x %02x %02x"%(i,x[0],x[1]))


fwrite returned 97<br/>
Boundary:
ffffffffff7fffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffff7ffffffbffffffffffffffffffffffffffffffffffffffffdffffffffffffffffffffff6dfffffffffffffffedf7fdbfedff7ffff6fffeffffffbff0

fwrite returned 97<br/>
Boundary:
ffffffffff7fffffffffffffffffffffffffffffffffffffbfffffffffffffffffffff7ffffffffffbffffffffffffffffffffffffffffffffffffffffdffffffffffffffffffffff6dfffffffffffffffedf7fdbfedff7ffff6fffeffffffbff0

fwrite returned 97<br/>
Boundary:
ffffffffff7fffffffffffffffffffffffffffffffffffffbffffffffffffffffffffffffffffffffbffffffffffffffffffffffffffffffffffffffffdffffffffffffffffffffff6dfffffffffffffffedf7fdbfedff7ffff6fffeffffffbff0





>>> b1 = readbscan('/dev/sfpgabscan0')
>>> b1
'\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xf0'

'\x00\x00\x00\x00\x00\x00\x00\x00\x08\x00$\x82\x12I\t\x00\x80\x02\x00@\x00\x04\x00\x00@\x00\x00\x00\x00\x00@\x00\x00\x00\x00\x00\x00\x00\x00\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00 \x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
cd /sys/kernel/debug/dynamic_debug
root@elphel393:/sys/kernel/debug/dynamic_debug# cat control | grep fpga
drivers/elphel/fpgajtag353.c:655 [fpgajtag]fpga_jtag_lseek =_ "fpga_jtag_lseek, fsize= 0x%x\012"
drivers/elphel/fpgajtag353.c:679 [fpgajtag]fpga_jtag_lseek =_ "fpga_jtag_lseek, file->f_pos= 0x%x\012"
drivers/elphel/fpgajtag353.c:1405 [fpgajtag]fpga_jtag_init =_ "elphel test %s: MAJOR %d"
drivers/elphel/fpgajtag353.c:751 [fpgajtag]wait_sensio_status =_ "seq_num = %d received after %d wait cycles"
drivers/elphel/fpgajtag353.c:764 [fpgajtag]set_pgm_mode =_ "set_pgm_mode (%d,%d)\012"
drivers/elphel/fpgajtag353.c:789 [fpgajtag]set_pgm =_ "set_pgm (%d,%d)\012"
drivers/elphel/fpgajtag353.c:851 [fpgajtag]jtag_send =_ "jtag_send(0x%x, 0x%x, 0x%x, 0x%x)\015\012"
drivers/elphel/fpgajtag353.c:950 [fpgajtag]jtag_write_bits =_ "jtag_write_bits(0x%x, 0x%x, 0x%x, 0x%x, 0x%x)\015\012"
drivers/elphel/fpgajtag353.c:1096 [fpgajtag]JTAG_configure =_ "JTAG_configure: chn=%x,  wp=0x%x, rp=0x%x, len=0x%x\015\012"
drivers/elphel/fpgajtag353.c:1211 [fpgajtag]JTAG_openChannel =_ "JTAG_openChannel (%d)\012"
drivers/elphel/fpgajtag353.c:367 [fpgajtag]fpga_jtag_open =_ "fpga_jtag_open: minor=%x, channel=%x, buf=%p\015\012"
drivers/elphel/fpgajtag353.c:440 [fpgajtag]fpga_jtag_open =_ "fpga_jtag_open: chn=%x, JTAG_channels[chn].sizew=%x, JTAG_channels[chn].sizer=%x\015\012"
drivers/elphel/fpgajtag353.c:441 [fpgajtag]fpga_jtag_open =_ "fpga_jtag_open: chn=%x, JTAG_channels[chn].bitsw=%x, JTAG_channels[chn].bitsr=%x\015\012"
drivers/elphel/fpgajtag353.c:446 [fpgajtag]fpga_jtag_open =_ "fpga_jtag_open: inode->i_size=%x, chn=%x\015\012"
drivers/elphel/fpgajtag353.c:1231 [fpgajtag]JTAG_resetChannel =_ "JTAG_resetChannel (%d)\012"
drivers/elphel/fpgajtag353.c:1342 [fpgajtag]JTAG_CAPTURE =_ "\012"
drivers/elphel/fpgajtag353.c:1347 [fpgajtag]JTAG_CAPTURE =_ "\012"
drivers/elphel/fpgajtag353.c:1344 [fpgajtag]JTAG_CAPTURE =_ "%3x "
drivers/elphel/fpgajtag353.c:1345 [fpgajtag]JTAG_CAPTURE =_ "\012"
drivers/elphel/fpgajtag353.c:456 [fpgajtag]fpga_jtag_release =_ "fpga_jtag_release: p=%x,chn=%x,  wp=0x%x, rp=0x%x\015\012"
drivers/elphel/fpgajtag353.c:497 [fpgajtag]fpga_jtag_release =_ "fpga_jtag_release:  done\015\012"
drivers/elphel/fpgajtag353.c:509 [fpgajtag]fpga_jtag_write =_ "fpga_jtag_write: p=%x,chn=%x, buf address=%lx count=%lx *offs=%lx, wp=%lx,size=0x%x\015\012"
drivers/elphel/fpgajtag353.c:562 [fpgajtag]fpga_jtag_write =_ "fpga_jtag_write end: p=%x,chn=%x, buf address=%lx count=%lx *offs=%lx, wp=%lx,size=0x%x\015\012"
drivers/elphel/fpgajtag353.c:574 [fpgajtag]fpga_jtag_read =_ "fpga_jtag_read: p=%x,chn=%x, buf address=%lx count=%lx *offs=%lx, rp=%lx,size=0x%x\015\012"
drivers/elphel/fpgajtag353.c:601 [fpgajtag]fpga_jtag_read =_ "fpga_jtag_read_01: p=%x,chn=%x, buf address=%lx count=%lx *offs=%lx, rp=%lx,size=0x%x\015\012"
drivers/elphel/fpgajtag353.c:624 [fpgajtag]fpga_jtag_read =_ "fpga_jtag_read_01: p=%x,chn=%x, buf address=%lx count=%lx *offs=%lx, rp=%lx,size=0x%x\015\012"
drivers/elphel/fpgajtag353.c:635 [fpgajtag]fpga_jtag_read =_ "fpga_jtag_read_end: p=%x,chn=%x, buf address=%lx count=%lx *offs=%lx, rp=%lx,size=0x%x, mode=%x\015\012"
drivers/elphel/fpgajtag353.c:1416 [fpgajtag]fpga_jtag_exit =_ "unregistering driver"

root@elphel393:/sys/kernel/debug/dynamic_debug# echo 'file drivers/elphel/fpgajtag353.c +p' > control

afpgaconfjtag       jtagraw             memory_bandwidth    mtd4ro              ram2                stderr              tty18               tty30               tty43               tty56               ttyS1
block               kmem                mmcblk0             mtdblock0           ram3                stdin               tty19               tty31               tty44               tty57               ttyS2
char                kmsg                mmcblk0p1           mtdblock1           random              stdout              tty2                tty32               tty45               tty58               ttyS3
console             log                 mmcblk0p2           mtdblock2           rtc0                tty                 tty20               tty33               tty46               tty59               ubi_ctrl
cpu_dma_latency     loop-control        mtab                mtdblock3           sfpgabscan0         tty0                tty21               tty34               tty47               tty6                urandom
disk                loop0               mtd0                mtdblock4           sfpgabscan1         tty1                tty22               tty35               tty48               tty60               vcs
fd                  loop1               mtd0ro              network_latency     sfpgabscan2         tty10               tty23               tty36               tty49               tty61               vcs1
fpgaconfjtag        loop2               mtd1                network_throughput  sfpgabscan3         tty11               tty24               tty37               tty5                tty62               vcsa
fpgaresetjtag       loop3               mtd1ro              null                sfpgaconfjtag       tty12               tty25               tty38               tty50               tty63               vcsa1
full                loop4               mtd2                psaux               sfpgaconfjtag0      tty13               tty26               tty39               tty51               tty7                watchdog
i2c-0               loop5               mtd2ro              ptmx                sfpgaconfjtag1      tty14               tty27               tty4                tty52               tty8                watchdog0
iio:device0         loop6               mtd3                pts                 sfpgaconfjtag2      tty15               tty28               tty40               tty53               tty9                xdevcfg
initctl             loop7               mtd3ro              ram0                sfpgaconfjtag3      tty16               tty29               tty41               tty54               ttyPS0              zero
input               mem                 mtd4                ram1                shm                 tty17               tty3                tty42               tty55               ttyS0


   fseek ($jtag,0);
   $boundary= fread($jtag, 97);
   fclose($jtag);
  return $boundary;



            packedData=struct.pack(self.ENDIAN+"L",data)
            d=struct.unpack(self.ENDIAN+"L",packedData)[0]
            mm[page_offs:page_offs+4]=packedData

    """

    def set_sensor_io_width (
                             self,
                             num_sensor,
                             width): # 0 - use HACT, >0 - generate HACT from start to specified width
        """
        Set sensor frame width
        @param num_sensor - sensor port number (0..3) or all
        @param width - sensor 16-bit frame width (0 - use sensor HACT signal)
        """
        try:
            if (num_sensor == all) or (num_sensor[0].upper() == "A"): #all is a built-in function
                for num_sensor in range(4):
                    self.set_sensor_io_width (num_sensor,
                                width =        width)

                return
        except:
            pass

        reg_addr = (vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC) + vrlg.SENSIO_RADDR + vrlg.SENSIO_WIDTH;
        self.x393_axi_tasks.write_control_register(reg_addr, width)

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
            self.x393_axi_tasks.write_control_register(reg_addr + 0, height0_m1)
        if not height1_m1 is None:
            self.x393_axi_tasks.write_control_register(reg_addr + 1, height1_m1)
        if not height2_m1 is None:
            self.x393_axi_tasks.write_control_register(reg_addr + 2, height2_m1)


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
        def func_lens_data (
                        num_sensor,
                        addr,
                        data,
                        width):

            return ((num_sensor & 3) << 24) | ((addr & 0xff) << 16) | (data & ((1 << width) - 1))
        reg_addr = (vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC) + vrlg.SENS_LENS_RADDR + vrlg.SENS_LENS_COEFF
        if not AX is None:
            self.x393_axi_tasks.write_control_register(reg_addr, func_lens_data(num_sub_sensor, vrlg.SENS_LENS_AX, AX, 19))
        if not AY is None:
            self.x393_axi_tasks.write_control_register(reg_addr, func_lens_data(num_sub_sensor, vrlg.SENS_LENS_AY, AY, 19))
        if not BX is None:
            self.x393_axi_tasks.write_control_register(reg_addr, func_lens_data(num_sub_sensor, vrlg.SENS_LENS_BX, BX, 21))
        if not BY is None:
            self.x393_axi_tasks.write_control_register(reg_addr, func_lens_data(num_sub_sensor, vrlg.SENS_LENS_BY, BY, 21))
        if not C is None:
            self.x393_axi_tasks.write_control_register(reg_addr, func_lens_data(num_sub_sensor, vrlg.SENS_LENS_C,   C, 19))
        if not scales0 is None:
            self.x393_axi_tasks.write_control_register(reg_addr, func_lens_data(num_sub_sensor, vrlg.SENS_LENS_SCALES + 0,   scales0, 17))
        if not scales1 is None:
            self.x393_axi_tasks.write_control_register(reg_addr, func_lens_data(num_sub_sensor, vrlg.SENS_LENS_SCALES + 2,   scales1, 17))
        if not scales2 is None:
            self.x393_axi_tasks.write_control_register(reg_addr, func_lens_data(num_sub_sensor, vrlg.SENS_LENS_SCALES + 4,   scales2, 17))
        if not scales3 is None:
            self.x393_axi_tasks.write_control_register(reg_addr, func_lens_data(num_sub_sensor, vrlg.SENS_LENS_SCALES + 6,   scales3, 17))
        if not fatzero_in is None:
            self.x393_axi_tasks.write_control_register(reg_addr, func_lens_data(num_sub_sensor, vrlg.SENS_LENS_FAT0_IN, fatzero_in, 16))
        if not fatzero_out is None:
            self.x393_axi_tasks.write_control_register(reg_addr, func_lens_data(num_sub_sensor, vrlg.SENS_LENS_FAT0_OUT, fatzero_out, 16))

        if not post_scale is None:
            self.x393_axi_tasks.write_control_register(reg_addr, func_lens_data(num_sub_sensor, vrlg.SENS_LENS_POST_SCALE, post_scale, 4))

    def program_gamma (self,
                       num_sensor,
                       sub_channel,
                       gamma = 0.57,
                       black = 0.04,
                       page = 0):
        """
        Program gamma tables for specified sensor port and subchannel
        @param num_sensor -     sensor port number (0..3), all - all sensors
        @param num_sub_sensor - sub-sensor attached to the same port through multiplexer (0..3)
        @param gamma - gamma value (1.0 - linear)
        @param black - black level, 1.0 corresponds to 256 for 8bit values
        @param page - gamma table page number (only used if SENS_GAMMA_BUFFER > 0
        """
        curves_data = self.calc_gamma257(gamma = gamma,
                                         black = black,
                                         rshift = 6) * 4

        try:
            if (num_sensor == all) or (num_sensor[0].upper() == "A"): #all is a built-in function
                for num_sensor in range(4):
                    self.program_gamma ( num_sensor =  num_sensor,
                                         sub_channel = sub_channel,
                                         gamma =       gamma,
                                         black =       black,
                                         page =        page)
                return
        except:
            pass

        self.program_curves(num_sensor = num_sensor,
                        sub_channel = sub_channel,
                        curves_data = curves_data,
                        page = page)

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
        @param page - gamma table page number (only used if SENS_GAMMA_BUFFER > 0
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
            self.x393_axi_tasks.write_control_register(reg_addr, data)
        def set_sensor_gamma_table_data ( #; // need 256 for a single color data
                                          num_sensor,
                                          data18): # ; // 18-bit table data
            reg_addr = (vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC) + vrlg.SENS_GAMMA_RADDR + vrlg.SENS_GAMMA_ADDR_DATA;
            self.x393_axi_tasks.write_control_register(reg_addr, data18 & ((1 << 18) - 1))


        if isinstance(curves_data, (str,)):
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

    def calc_gamma257(self,
                      gamma,
                      black,
                      rshift = 6
                      ):
        """
        @brief Calculate gamma table (as array of 257 unsigned short values)
        @param gamma - gamma value (1.0 - linear), 0 - linear as a special case
        @param black - black level, 1.0 corresponds to 256 for 8bit values
        @return array of 257 int elements (for a single color), right-shifted to match original 0..0x3ff range
        """
        gtable = []
        if gamma <= 0: # special case
            for i in range (257):
                ig = min(i*256, 0xffff)
                gtable.append(ig >> rshift)
        else:
            black256 =  max(0.0, min(255, black * 256.0))
            k=  1.0 / (256.0 - black256)
            gamma =max(0.13, min(gamma, 10.0))
            for i in range (257):
                x=k * (i - black256)
                x = max(x, 0.0)
                ig = int (0.5 + 65535.0 * pow(x, gamma))
                ig = min(ig, 0xffff)
                gtable.append(ig >> rshift)
        return gtable


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
        self.x393_axi_tasks.write_control_register(reg_addr, (height0_m1 & 0xffff) | ((height1_m1 & 0xffff) << 16));

        reg_addr = (vrlg.SENSOR_GROUP_ADDR + num_sensor * vrlg.SENSOR_BASE_INC) + vrlg.SENS_GAMMA_RADDR + vrlg.SENS_GAMMA_HEIGHT2;
        self.x393_axi_tasks.write_control_register(reg_addr, height2_m1 & 0xffff);

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
        self.x393_axi_tasks.write_control_register(reg_addr, data);

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
        if self.DEBUG_MODE or True:
            print("set_sensor_histogram_window():")
            print("num_sensor = ", num_sensor)
            print("subchannel = ", subchannel)
            print("left =       ", left)
            print("top =        ", top)
            print("width_m1 =   ", width_m1)
            print("height_m1 =  ", height_m1)

        self.x393_axi_tasks.write_control_register(reg_addr + vrlg.HISTOGRAM_LEFT_TOP,     ((top & 0xffff) << 16) | (left & 0xffff))
        self.x393_axi_tasks.write_control_register(reg_addr + vrlg.HISTOGRAM_WIDTH_HEIGHT, ((height_m1 & 0xffff) << 16) | (width_m1 & 0xffff))
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
        if self.DEBUG_MODE:
            print("set_sensor_histogram_saxi():")
            print("en =            ", en)
            print("nrst =          ", nrst)
            print("confirm_write = ", confirm_write)
            print("cache_mode=     ", cache_mode)
        data = 0;
        data |= (0,1)[en] <<            vrlg.HIST_SAXI_EN
        data |= (0,1)[nrst] <<          vrlg.HIST_SAXI_NRESET
        data |= (0,1)[confirm_write] << vrlg.HIST_CONFIRM_WRITE
        data |= (cache_mode & 0xf) <<   vrlg.HIST_SAXI_AWCACHE
        self.x393_axi_tasks.write_control_register(vrlg.SENSOR_GROUP_ADDR + vrlg.HIST_SAXI_MODE_ADDR_REL, data)

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
        if self.DEBUG_MODE:
            print("set_sensor_histogram_saxi_addr():")
            print("num_sensor = ", num_sensor)
            print("subchannel = ", subchannel)
            print("page =       ", page)
        num_histogram_frames = 1 << vrlg.NUM_FRAME_BITS
        channel = ((num_sensor & 3) << 2) + (subchannel & 3)
        channel_page = page + num_histogram_frames * channel
        self.x393_axi_tasks.write_control_register(vrlg.SENSOR_GROUP_ADDR + vrlg.HIST_SAXI_ADDR_REL + channel,
                                                   channel_page)

    def control_sensor_memory(self,
                              num_sensor,
                              command,
                              reset_frame = False,
                              abort_late =   False,
                              verbose = 1):
        """
        Control memory access (write) of a sensor channel
        @param num_sensor - memory sensor channel (or all)
        @param command -    one of (case insensitive):
               reset       - reset channel, channel pointers immediately,
               stop        - stop at the end of the frame (if repetitive),
               single      - acquire single frame ,
               repetitive  - repetitive mode
        @param reset_frame - reset frame number. Needed after changing frame start address (i.e. initial set-up) !
        @param abort_late    abort frame r/w at the next frame sync, if not finished. Wait for pending memory transfers

        @param vebose -      verbose level
        """
        try:
            if (num_sensor == all) or (num_sensor[0].upper() == "A"): #all is a built-in function
                for num_sensor in range(4):
                    print ('num_sensor = ',num_sensor)
                    self.control_sensor_memory(num_sensor =  num_sensor,
                                               command =     command,
                                               reset_frame = reset_frame,
                                               abort_late =  abort_late,
                                               verbose =     verbose)
                return
        except:
            pass


        rpt =    False
        sngl =   False
        en =     False
        rst =    False
        if command[:3].upper() ==   'RES':
            rst = True
        elif command[:2].upper() == 'ST':
            pass
        elif command[:2].upper() == 'SI':
            sngl = True
            en =   True
        elif command[:3].upper() == 'REP':
            rpt =  True
            en =   True
        else:
            print ("Unrecognized command %s. Valid commands are RESET, STOP, SINGLE, REPETITIVE"%(command))
            return

        base_addr = vrlg.MCONTR_SENS_BASE + vrlg.MCONTR_SENS_INC * num_sensor;
        mode=   x393_mcntrl.func_encode_mode_scan_tiled(
                                   skip_too_late = True,
                                   disable_need = False,
                                   repetitive=    rpt,
                                   single =       sngl,
                                   reset_frame =  reset_frame,
                                   extra_pages =  0,
                                   write_mem =    True,
                                   enable =       en,
                                   chn_reset =    rst,
                                   abort_late =   abort_late)
        self.x393_axi_tasks.write_control_register(base_addr + vrlg.MCNTRL_SCANLINE_MODE,  mode)
        if verbose > 0 :
            print ("write_control_register(0x%08x, 0x%08x)"%(base_addr + vrlg.MCNTRL_SCANLINE_MODE,  mode))

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
                                   skip_too_late = True,
                                   disable_need = False,
                                   repetitive=    True,
                                   single =       False,
                                   reset_frame =  True, # False,
                                   extra_pages =  0,
                                   write_mem =    True,
                                   enable =       True,
                                   chn_reset =    False,
                                   abort_late =   False) # default, change with  control_sensor_memory()

        self.x393_axi_tasks.write_control_register(base_addr + vrlg.MCNTRL_SCANLINE_STARTADDR,
                                                  frame_sa); # RA=80, CA=0, BA=0 22-bit frame start address (3 CA LSBs==0. BA==0)
        self.x393_axi_tasks.write_control_register(base_addr + vrlg.MCNTRL_SCANLINE_FRAME_SIZE,
                                                  frame_sa_inc);
        self.x393_axi_tasks.write_control_register(base_addr + vrlg.MCNTRL_SCANLINE_FRAME_LAST,
                                                  last_frame_num);
        self.x393_axi_tasks.write_control_register(base_addr + vrlg.MCNTRL_SCANLINE_FRAME_FULL_WIDTH,
                                                  frame_full_width);
        self.x393_axi_tasks.write_control_register(base_addr + vrlg.MCNTRL_SCANLINE_WINDOW_WH,
                                                  ((window_height & 0xffff) << 16) | (window_width & 0xffff)) #/WINDOW_WIDTH + (WINDOW_HEIGHT<<16));
        self.x393_axi_tasks.write_control_register(base_addr + vrlg.MCNTRL_SCANLINE_WINDOW_X0Y0,
                                                  ((window_top & 0xffff) << 16) | (window_left & 0xffff)) #WINDOW_X0+ (WINDOW_Y0<<16));
        self.x393_axi_tasks.write_control_register(base_addr + vrlg.MCNTRL_SCANLINE_WINDOW_STARTXY,   0)
        self.x393_axi_tasks.write_control_register(base_addr + vrlg.MCNTRL_SCANLINE_MODE,          mode)


    def hispi_phases_adjust(self,num_sensor):
        """
        Try to adjust phases
        @param num_sensor - sensor port number (0..3)
        """

        def thp_set_phase(num_sensor,phase):
            path = "/sys/devices/soc0/elphel393-sensor-i2c@0/i2c"+str(num_sensor)
            f = open(path,'w')
            f.write("mt9f002 0 0x31c0 "+str(phase))
            f.close()

        def thp_reset_flags(num_sensor):
            self.x393_axi_tasks.write_control_register(0x40e+0x40*num_sensor,0x0)

        def thp_read_flags(num_sensor,shift):
            switched = False
            value = 0
            count = 0
            timeout = 512
            # reset bits
            thp_reset_flags(num_sensor)

            # wait until hact alives with a timeout
            t = 0
            hact_alive = 0

            while not hact_alive:
                status = int(self.x393_axi_tasks.read_status(0x21+2*num_sensor) & 0x01ffffff)
                hact_alive = (status>>13)&0x1
                t += 1
                if t==timeout:
                    break
                time.sleep(0.1)

            barrel = (status>>14)&0xff
            barrel = (barrel>>(2*shift))&0x3

            for j in range(4):
                v = (status>>14)&0xff
                v = (v>>(2*(3-j)))&0x3
                print(str(v),end='')
                print(".",end='')
            return barrel


        def thp_run(num_sensor,phase0,shift,bitshift):
            shift = shift*3
            switched = False
            value = 0
            i1 = 0
            i2 = 0
            im = 0

            for i in range(16):
                if (i==0):
                    phase0 += 0x4000
                if (i==8):
                    phase0 -= 0x4000
                    print("| ",end="")
                # set phase
                phase = phase0+((i%8)<<shift)
                thp_set_phase(num_sensor,phase)
                phase_read = int(self.print_sensor_i2c(num_sensor,0x31c0,0xff,0x10,0))&0xffff
                if phase_read!=phase:
                    print("ERROR: phase_read ("+("{:04x}".format(phase_read))+") != phase ("+("{:04x}".format(phase))+")")
                barrel = thp_read_flags(num_sensor,bitshift)
                if ((i==0)or(i==8)):
                    value = barrel
                    switched = False
                else:
                    if (value!=barrel):
                        if i<8:
                            if not switched:
                                switched = True
                                value = barrel
                                i1 = i
                            else:
                                print("Unexpected phase shift at "+str(i))
                        else:
                            if not switched:
                                switched = True
                                value = barrel
                                i2 = i
                            else:
                                print("Unexpected phase shift at "+str(i))
            i1 = i1&0x7
            i2 = i2&0x7

            if (abs(i2-i1)<2):
                print("Error?")
            target_phase = phase0 + (i1<<shift)
            thp_set_phase(num_sensor,target_phase)
            return target_phase
        chn = num_sensor

        print("Test HiSPI phases")

        # check status register
        status_reg = self.x393_axi_tasks.read_control_register(0x409+0x40*chn)

        if (status_reg==0):
            print("Programming status register")
            self.x393_axi_tasks.write_control_register(0x409+0x40*chn,0xc0)

        status_reg = self.x393_axi_tasks.read_control_register(0x409+0x40*chn)

        print("Status register: "+hex(self.x393_axi_tasks.read_control_register(0x409+0x40*chn)))

        phase0 = 0x8000

        for i in range(4):
            print("D"+str(i))
            phase0 = thp_run(num_sensor,phase0,i,i)
            print(" Updated phase = 0x"+"{:04x}".format(phase0))
        print("Done")



    def hispi_test_i2c_write(self,num_sensor):
        """
        Test i2c writes
        @param num_sensor - sensor port number (0..3)
        """

        for i in range(10000000):
            if (i%10000==0):
                print("iteration: "+str(i))
            fname = "/sys/devices/soc0/elphel393-sensor-i2c@0/i2c"+str(num_sensor)
            val = str(hex(0x8000+(i&0xfff)))
            f = open(fname,'w')
            f.write("mt9f002 0 0x31c0 "+val)
            f.close()
            # initiate read
            f = open(fname,'w')
            f.write("mt9f002 0 0x31c0")
            f.close()
            # read
            f = open(fname,'r')
            res = int(f.read())
            f.close()
            if (res!=int(val,0)):
                print(res+" vs "+val)
                break


    def mt9f002_read_regs(self,num_sensor):
        """
        """
        reglist = [
            0x3000,0x3002,0x3004,0x3006,0x3008,0x300a,0x300c,0x3010,
            0x3012,0x3014,0x3016,0x3018,0x301a,0x301c,0x301d,0x301e,
            0x3021,0x3022,0x3023,0x3024,0x3026,0x3028,0x302a,0x302c,
            0x302e,0x3030,0x3032,0x3034,0x3036,0x3038,0x303a,0x303b,
            0x303c,0x3040,0x3046,0x3048,0x3056,0x3058,0x305a,0x305c,
            0x305e,0x306a,0x306e,0x3070,0x3072,0x3074,0x3078,0x307a,
            0x30a0,0x30a2,0x30a4,0x30a6,0x30a8,0x30aa,0x30ac,0x30ae,
            0x30bc,0x30c0,0x30c2,0x30c4,0x30c6,0x30c8,0x30e8,0x30ea,
            0x30ec,0x30ee,0x3138,0x3140,0x3158,0x315a,0x315e,0x3160,
            0x3162,0x3164,0x3166,0x3168,0x316a,0x3178,0x31a0,0x31a2,
            0x31a2,0x31a4,0x31a6,0x31a8,0x31aa,0x31ac,0x31ae,0x31b0,
            0x31b2,0x31b4,0x31b6,0x31b8,0x31ba,0x31bc,0x31c0,0x31c6
            ]

        i=0

        for reg in reglist:
            val = int(self.print_sensor_i2c(num_sensor,reg,0xff,0x2a,0))&0xffff
            print("{:04x}".format(reg)+": "+"{:04x}".format(val),end='    ')
            i += 1
            if i%8==0:
                print("")


    # FLIR Lepton 3.5 testing procedures
    LEPTON35_REG_POWER_ON   = 0x0000
    LEPTON35_REG_STATUS     = 0x0002
    LEPTON35_REG_CMD        = 0x0004
    LEPTON35_REG_DATA_LEN   = 0x0006
    LEPTON35_REG_DATA_FIRST = 0x0008
    LEPTON35_REG_DATA_LAST  = 0x0026


    def lepton35_i2c_w(self,num_sensor,reg,val):
        """
        Write 16 bit value to an i2c register via sysfs
        @param num_sensor - sensor port number (0..3)
        @param reg - register address (0x0 - power_on reg, 0x2 - status reg, 0x4 - command reg, 0x6 - data length reg, 0x08-0x26 - data regs)
        @param val - value
        """
        path = "/sys/devices/soc0/elphel393-sensor-i2c@0/i2c"+str(num_sensor)
        f = open(path,'w')
        f.write("lepton35 0 "+str(reg)+" "+str(val))
        f.close()


    def lepton35_i2c_r(self,num_sensor,reg):
        """
        Read 16 bit value from an i2c register via sysfs
        @param num_sensor - sensor port number (0..3)
        @param reg - register address (0x0 - power_on reg, 0x2 - status reg, 0x4 - command reg, 0x6 - data length reg, 0x08-0x26 - data regs)
        """
        path = "/sys/devices/soc0/elphel393-sensor-i2c@0/i2c"+str(num_sensor)
        f = open(path,'w')
        f.write("lepton35 0 "+str(reg))
        f.close()
        # now read
        # read
        f = open(path,'r')
        res = int(f.read())
        f.close()

        return res


    def lepton35_poll_BUSY(self,num_sensor,ntries=500):
        """
        Poll BUSY bit of a status reg
        @param num_sensor - sensor port number (0..3)
        @param ntries - timeout, exit after ntries times
        """
        # single cycle in python is usually enough
        for i in range(ntries):
            res = self.lepton35_i2c_r(num_sensor,self.LEPTON35_REG_STATUS)
            busy = res&0x1
            if busy==0:
                res_code = (res>>8)&0xf
                print("Response code: "+str(res_code))
                break
            else:
                print("sensor status: busy("+str(i)+")")

            time.sleep(0.01)

        return busy


    def lepton35_read(self,num_sensor,cmdreg,datalen):
        """
        Read attribute sequence, auto-sets OEM bit for OEM(0x08..) and RAD(0x0e..) modules
        @param num_sensor - sensor port number (0..3)
        @param cmdreg     - register base address
        @param datalen    - number of 16-bit words to read
        """
        res = []

        mod = (cmdreg>>8)&0xf
        # mode
        if mod==0x8 or mod==0xe:
            cmdreg += 0x4000

        busy = self.lepton35_poll_BUSY(num_sensor)
        if not busy:
            print("not busy, writing data length and command")
            self.lepton35_i2c_w(num_sensor,self.LEPTON35_REG_DATA_LEN,datalen)
            self.lepton35_i2c_w(num_sensor,self.LEPTON35_REG_CMD,cmdreg)
            busy = self.lepton35_poll_BUSY(num_sensor)
            if not busy:
                for i in range(datalen):
                    tmp = self.lepton35_i2c_r(num_sensor,self.LEPTON35_REG_DATA_FIRST+i)
                    res.append(tmp)
            else:
                print("lepton35_read: sensor busy. timeout.")

        return res


    def lepton35_write(self,num_sensor,cmdreg,cmddata):
        """
        Write sequence, auto-sets OEM bit for OEM(0x08..) and RAD(0x0e..) modules
        @param num_sensor - sensor port number (0..3)
        @param cmdreg     - register base address (true addr = cmdreg|0x1)
        @param cmddata    - string with comma separated values "0,1,2,3,4"
        """
        cmdreg = cmdreg|0x1
        mod = (cmdreg>>8)&0xf
        # mode
        if mod==0x8 or mod==0xe:
            cmdreg += 0x4000

        cmddata = [int(a) for a in cmddata.split(",")]
        datalen = len(cmddata)

        busy = self.lepton35_poll_BUSY(num_sensor)
        if not busy:
            for i in range(datalen):
                self.lepton35_i2c_w(num_sensor,self.LEPTON35_REG_DATA_FIRST+i,cmddata[i])
            self.lepton35_i2c_w(num_sensor,self.LEPTON35_REG_DATA_LEN,datalen)
            self.lepton35_i2c_w(num_sensor,self.LEPTON35_REG_CMD,cmdreg)
            busy = self.lepton35_poll_BUSY(num_sensor)
            if busy:
                print("lepton35_write: sensor busy. timeout.")


    def lepton35_run(self,num_sensor,cmdreg):
        """
        Run command sequence, auto-sets OEM bit for OEM(0x08..) and RAD(0x0e..) modules
        @param num_sensor - sensor port number (0..3)
        @param cmdreg     - register base address (true addr = cmdreg|0x2)
        """
        mod = (cmdreg>>8)&0xf
        # mode
        if mod==0x8 or mod==0xe:
            cmdreg += 0x4000
        busy = self.lepton35_poll_BUSY(num_sensor)
        if not busy:
            self.lepton35_i2c_w(num_sensor,self.LEPTON35_REG_CMD,cmdreg)
            busy = self.lepton35_poll_BUSY(num_sensor)
            if busy:
                print("lepton35_run: sensor busy. timeout.")




    def lepton35_read_serial(self,num_sensor):
        """
        Read serial number (read attribute sequence from 0x0208)
        @param num_sensor - sensor port number (0..3)
        """
        res = self.lepton35_read(num_sensor,0x0208,4)
        print("_".join(["{:04x}".format(a) for a in res]))
