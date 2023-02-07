from __future__ import division
from __future__ import print_function

'''
# Copyright (C) 2016, Elphel.inc.
# Class to control event logger module  
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
import x393_gpio

import x393_utils

#import time
import vrlg

#  parameter SYNC_BIT_LENGTH=8-1; /// 7 pixel clock pulses
#  SYNC_BIT_LENGTH=8-1 # 7 pixel clock pulses
MEM_PATH='/sys/devices/soc0/elphel393-mem@0/'
BUFFER_ADDRESS_LOGGER_NAME='buffer_address_logger'
BUFFER_PAGES_LOGGER_NAME='buffer_pages_logger'
PAGE_SIZE=4096

# For simulation
BUFFER_ADDRESS_LOGGER = 0x2d000000
BUFFER_LEN_LOGGER =    1024*PAGE_SIZE


class X393Logger(object):
    DRY_MODE=         True # True
    DEBUG_MODE=       1
    ADDR_REG =        1
    DATA_REG =        0
    PCA9500_PP_ADDR = 0x40 #< PCA9500 i2c slave addr for the parallel port (read will be 0x41)
    SLOW_SPI =        26 # just for the driver, not written to FPGA (was 23 for NC353)
    I2C_SA3 =         28   #Low 3 bits of the SA7 of the PCA9500 slave address
    
#    X313_IMU_PERIOD_ADDR =      0x0  # request period for IMU (in SPI bit periods)
#    X313_IMU_DIVISOR_ADDR =     0x1  # xclk (80MHz) clock divisor for half SPI bit period 393: clock is Now clock is logger_clk=100MHz (200 MHz?)
#    X313_IMU_RS232DIV_ADDR =    0x2  # serial gps bit duration in xclk (80MHz) periods - 16 bits
#    X313_IMU_CONFIGURE_ADDR =   0x3  # IMU logger configuration
    X313_IMU_REGISTERS_ADDR =   0x4
    X313_IMU_NMEA_FORMAT_ADDR = 0x20
    X313_IMU_MESSAGE_ADDR =     0x40  #40..4f, only first 0xe visible

#// offsets in the file (during write)
    X313_IMU_PERIOD_OFFS =      0x0
    X313_IMU_DIVISOR_OFFS =     0x4

    X313_IMU_RS232DIV_OFFS =    0x8
    X313_IMU_CONFIGURE_OFFS =   0xc

    X313_IMU_SLEEP_OFFS =       0x10
    X313_IMU_REGISTERS_OFFS =   0x14 # .. 0x2f

    X313_IMU_NMEA_FORMAT_OFFS = 0x30
    X313_IMU_MESSAGE_OFFS =     0xB0 # 0xB0..0xE7

    WHICH_INIT =                1
    WHICH_RESET =               2
    WHICH_RESET_SPI =           4
    WHICH_DIVISOR =             8
    WHICH_RS232DIV =           16
    WHICH_NMEA =               32
    WHICH_CONFIG =             64
    WHICH_REGISTERS =         128
    WHICH_MESSAGE =           256
    WHICH_PERIOD =            512
    WHICH_EN_DMA =           1024
    WHICH_EN_LOGGER =        2048
    
    
    x393_mem=None
    x393_axi_tasks=None #x393X393AxiControlStatus
    X393_gpio=None
    x393_utils=None
    verbose=1
    def __init__(self, debug_mode=1,dry_mode=True, saveFileName=None):
        global BUFFER_ADDRESS_LOGGER, BUFFER_LEN_LOGGER
        self.DEBUG_MODE=  debug_mode
        self.DRY_MODE=    dry_mode
        self.x393_mem=            X393Mem(debug_mode,dry_mode)
        self.x393_axi_tasks=      x393_axi_control_status.X393AxiControlStatus(debug_mode,dry_mode)
        self.x393_utils=          x393_utils.X393Utils(debug_mode,dry_mode, saveFileName) # should not overwrite save file path
        self.X393_gpio =          x393_gpio.X393GPIO(debug_mode,dry_mode, saveFileName)
        try:
            self.verbose=vrlg.VERBOSE
        except:
            pass
        
        if dry_mode:
            print ("Running in simulated mode, using hard-coded addresses:")
        else:
            try:
                with open(MEM_PATH+BUFFER_ADDRESS_LOGGER_NAME) as sysfile:
                    BUFFER_ADDRESS_LOGGER=int(sysfile.read(),0)
                with open(MEM_PATH+BUFFER_PAGES_LOGGER_NAME) as sysfile:
                    BUFFER_LEN_LOGGER=PAGE_SIZE*int(sysfile.read(),0)
            except:
                print("Failed to get reserved physical memory range")
                print('BUFFER_ADDRESS_LOGGER=',BUFFER_ADDRESS_LOGGER)    
                print('BUFFER_LEN_LOGGER=',BUFFER_LEN_LOGGER)    
                return
        print('BUFFER_ADDRESS_LOGGER=0x%x'%(BUFFER_ADDRESS_LOGGER))    
        print('BUFFER_LEN_LOGGER=0x%x'%(BUFFER_LEN_LOGGER))
    """
/** Initialize FPGA DMA engine for the logger. Obviously requires bitstream to be loaded. */
int logger_init_fpga(int force) ///< if 0, only do if not already initialized
{
    x393_status_ctrl_t logger_status_ctrl=    {.d32 = 0};
    x393_status_ctrl_t mult_saxi_status_ctrl= {.d32 = 0};
    x393_mult_saxi_al_t    mult_saxi_a=   {.d32=0};
    x393_mult_saxi_al_t    mult_saxi_l=   {.d32=0};
    x393_mult_saxi_irqlen_t mult_saxi_irqlen=   {.d32=0};
    if (logger_fpga_configured && !force) return 0; // Already initialized
    mult_saxi_a.addr32 = logger_phys >> 2; // in DWORDs
    x393_mult_saxi_buf_address(mult_saxi_a,      MULT_SAXI_CHN);
    mult_saxi_l.addr32 = logger_size >> 2;
    x393_mult_saxi_buf_len    (mult_saxi_l,      MULT_SAXI_CHN);
    mult_saxi_irqlen.irqlen = LOGGER_IRQ_DW_BIT;
    x393_mult_saxi_irqlen     (mult_saxi_irqlen, MULT_SAXI_CHN);
    logger_status_ctrl.mode = LOGGER_STATUS_MODE;
    set_x393_logger_status_ctrl(logger_status_ctrl);
    if (MULT_SAXI_STATUS_MODE) { // do not set (overwrite other channels if 0)
        mult_saxi_status_ctrl.mode = MULT_SAXI_STATUS_MODE;
        set_x393_mult_saxi_status_ctrl(mult_saxi_status_ctrl);
    }
    // resets (do once?)
    logger_dma_ctrl(0); ///reset DMA
#if LOGGER_USE_IRQ
    logger_irq_cmd(X393_IRQ_RESET);
    logger_irq_cmd(X393_IRQ_ENABLE);
#endif /* LOGGER_USE_IRQ */
    logger_fpga_configured = 1;
    return 0;
}
    """
    def logger_init_fpga(self, force = False, irqlen = 4, chn = 0):
        """
        Initialize DMA channel for the event logger
        @param irqlen [ 4: 0] (0) lowest DW address bit that has to change to generate interrupt
        @param force if False only do if not yet done
        @param chn - mult_saxi channel (0..3), currently connected is 0
        """
        print ("logger_init_fpga")
        if not force:
            if self.x393_axi_tasks.read_control_register(vrlg.MULT_SAXI_ADDR + 2* chn):
                return
        print("write_control_register 0x%x 0x%x"% (vrlg.MULT_SAXI_ADDR + 2* chn,     BUFFER_ADDRESS_LOGGER >> 2))     
        self.x393_axi_tasks.write_control_register(vrlg.MULT_SAXI_ADDR + 2* chn,     BUFFER_ADDRESS_LOGGER >> 2)
        
        print("write_control_register 0x%x 0x%x"% (vrlg.MULT_SAXI_ADDR + 2* chn + 1, BUFFER_LEN_LOGGER >> 2))     
        self.x393_axi_tasks.write_control_register(vrlg.MULT_SAXI_ADDR + 2* chn + 1, BUFFER_LEN_LOGGER >> 2)
        
        print("write_control_register 0x%x 0x%x"% (vrlg.MULT_SAXI_IRQLEN_ADDR + chn, irqlen))     
        self.x393_axi_tasks.write_control_register(vrlg.MULT_SAXI_IRQLEN_ADDR + chn, irqlen)
        
        print("program_status 0x%x 0x%x 3 0"%(vrlg.MULT_SAXI_CNTRL_ADDR, vrlg.MULT_SAXI_CNTRL_STATUS))     
        self.x393_axi_tasks.program_status   (vrlg.MULT_SAXI_CNTRL_ADDR, vrlg.MULT_SAXI_CNTRL_STATUS, 3, 0) # auto update
    def logger_dma_ctrl (self, mode, chn = 0):
        """
        Control dma for channel (the only channel)
        @param mode: 0 - reset, 1 - enable/pause, 2 - reset
        @param chn - mult_saxi channel (0..3), currently connected is 0
        """
        print ("logger_dma_ctrl")
        if mode == 0:
            d = 0
        elif mode == 1:
            d = 0x1 << chn
        elif mode == 2:
            d = 0x11 << chn
        else:
            raise Exception("mode should be 0 (reset), 1 - pause or 2 - run")
        print("write_control_register 0x%x 0x%x"% (vrlg.MULT_SAXI_CNTRL_ADDR + vrlg.MULT_SAXI_CNTRL_MODE, d))     
        self.x393_axi_tasks.write_control_register(vrlg.MULT_SAXI_CNTRL_ADDR + vrlg.MULT_SAXI_CNTRL_MODE, d)
        
    def logger_interrupt_control (self,
                                  cntrl = "clr",
                                  chn = 0):
        """
        Control logger interrupts
        @param cntrl -    "clr" - clear, "en" - enable, "dis" - disable
        @param chn -      compressor channel number, "a" or "all" - same for all 4 channels
        """
        print ("logger_interrupt_control")
        if cntrl.lower() == "clr":
            data = 1
        elif cntrl.lower() == "dis":
            data = 2
        elif cntrl.lower() == "en":
            data = 3
        else:
            raise Exception ("logger_interrupt_control(): invalid control mode: %s, only 'clr', 'en' and 'dis' are accepted"%(str(cntrl)))
        print("write_control_register 0x%x 0x%x"% (vrlg.MULT_SAXI_CNTRL_ADDR + vrlg.MULT_SAXI_CNTRL_IRQ, data << (2* chn)))     
        self.x393_axi_tasks.write_control_register(vrlg.MULT_SAXI_CNTRL_ADDR + vrlg.MULT_SAXI_CNTRL_IRQ, data << (2* chn))
        
        
    def logger_reset(self, rst):
        """
        Reset logger module
        @param rst: 1 - reset, 0 - normal operation
        """
        print ("need to stop logger DMA if it is running")
        print ("Resetting logger")
        self.x393_axi_tasks.write_control_register(vrlg.LOGGER_ADDR + self.ADDR_REG, vrlg.LOGGER_CONFIG);
        data = (2,3)[rst] << (vrlg.LOGGER_CONF_EN - vrlg.LOGGER_CONF_EN_BITS)
        self.x393_axi_tasks.write_control_register(vrlg.LOGGER_ADDR + self.DATA_REG, data);
        
    def logger_init(self,config):
        """
        Init logger module
        @param config - configuration word (only non-FPGA bit fields are processed)
        """
        print("Enabling I/O pins for IMU")
        data = 3 << 6 
        self.x393_axi_tasks.write_control_register(vrlg.GPIO_ADDR +  vrlg.GPIO_SET_PINS, data << vrlg.GPIO_PORTEN)
        
        i2c_sa8= self.PCA9500_PP_ADDR + (((config >> self.I2C_SA3) & 0x7)<<1) # Here 8-bit is needed, not SA7
        enable_IMU = (0xff,0xfd)[(config >> self.SLOW_SPI) & 1] # bit[0] - reset IMU
        i2c_err = 0
        print("Supposed (not yet implemented) to send i2c command in raw mode - address=0x%x, data=0x%x, result=0x%x\n"%(i2c_sa8, enable_IMU, i2c_err))
        self.logger_init_fpga(force = False, irqlen = 4, chn = 0)
        self.logger_interrupt_control (cntrl = "en", chn = 0) 
    def logger_reset_spi(self):
        """
        Reset IMU SPI
        """
        print("Resetting IMU SPI")
        self.logger_set_period(0)
    
    def logger_set_period(self,period):
        """
        Set SPI clock divisor
        @param period: IMU update period (0xffff - automatic, when IMU is ready)
        """
        print("Setting IMU update period = 0x%x"%(period))
        self.x393_axi_tasks.write_control_register(vrlg.LOGGER_ADDR + self.ADDR_REG, vrlg.LOGGER_PERIOD)
        self.x393_axi_tasks.write_control_register(vrlg.LOGGER_ADDR + self.DATA_REG, period)

    def logger_set_divisor(self,divisor):
        """
        Set SPI clock divisor
        @param divisor: clock divisor for SPI from 100MHz (divisor -1 will be written to FPGA)
        """
        print("Setting SPI clock divisor (decremented) value = 0x%x"%(divisor - 1))
        self.x393_axi_tasks.write_control_register(vrlg.LOGGER_ADDR + self.ADDR_REG, vrlg.LOGGER_BIT_DURATION)
        self.x393_axi_tasks.write_control_register(vrlg.LOGGER_ADDR + self.DATA_REG, divisor - 1)

    def logger_set_rs232div(self,divisor):
        """
        Set RS232 clock divisor
        @param divisor: clock divisor for 1/2 RS232 sample period from 100MHz (divisor -1 will be written to FPGA)
        """
        print("Setting RS232 clock divisor (decremented) value = 0x%x"%(divisor - 1))
        self.x393_axi_tasks.write_control_register(vrlg.LOGGER_ADDR + self.ADDR_REG, vrlg.LOGGER_BIT_HALF_PERIOD)
        self.x393_axi_tasks.write_control_register(vrlg.LOGGER_ADDR + self.DATA_REG, divisor - 1)
        
    def zterm(self,l):
#        return ''.join(l[:l.index(chr(0))])
        return l[:l.index(0)]

    def logger_set_nmea(self, nmea_format):
        """
        Set RS232 clock divisor
        @param nmea_format: encoded NMEA sentences as a string
        """
#    int nmea_sel[16];
#    int nmea_fpga_frmt[16];
        nmea_chars= list(nmea_format)
        nmea_sel =       [0]*16
        nmea_fpga_frmt = [0]*16
        for n in range(4):
            nmea_chars[32*n+27]=0; # just in case
            print("Setting NMEA sentence format for $GP%s"%(bytearray(self.zterm(nmea_chars[32*n:])).decode()))
#            print("(0x%x, 0x%x, 0x%x\n"%(ord(nmea_chars[32*n]),ord(nmea_chars[32*n+1]),ord(nmea_chars[32*n+2])));
            print("(0x%x, 0x%x, 0x%x\n"%(nmea_chars[32*n],nmea_chars[32*n+1],nmea_chars[32*n+2]));
            f=0;
            for i in range(2,-1,-1):
#                b=ord(nmea_chars[32*n+i]) # first 3 letters in each sentence
                b=nmea_chars[32*n+i] # first 3 letters in each sentence
                print("n=%d, i=%d, b=0x%x"%(n,i,b))
                for j in  range (4,-1,-1): # (j=4; j>=0; j--) {
                    f<<=1;
                    if ((b & (1<<j)) != 0):
                        f += 1
            print("n=%d, f=0x%x"%(n,f)) # good
            for i in range(15):
                if ((f & (1<<i))!=0):
                    nmea_sel[i] |= (1<<n);
            f=0
            
            nmea_fpga_frmt[n*4]=0;
            
            #for (i=0; (i<24) && (nmea_format[32*n+3+i]!=0);i++ ) {
            for i in range(24):
#                if nmea_chars[32*n+3+i]==chr(0):
                if nmea_chars[32*n+3+i]==0:
                    break
                b=nmea_chars[32*n+3+i]
#                if (b=='b') or (b=='B'):
                if (b==ord('b')) or (b==ord('B')):
                     f |= (1<<i);
                nmea_fpga_frmt[n*4] += 1
            nmea_fpga_frmt[n*4+1] = f         & 0xff;
            nmea_fpga_frmt[n*4+2] = (f >>  8) & 0xff;
            nmea_fpga_frmt[n*4+3] = (f >> 16) & 0xff;
    
        print("Selection data is %x%x%x%x%x%x%x%x%x%x%x%x%x%x%x"%(nmea_sel[0],nmea_sel[1],nmea_sel[2],
                nmea_sel[3],nmea_sel[4],nmea_sel[5],nmea_sel[6],nmea_sel[7],nmea_sel[8],nmea_sel[9],
                nmea_sel[10],nmea_sel[11],nmea_sel[12],nmea_sel[13],nmea_sel[14])) # good
        print("Format data for sentence 1 is %02x %02x %02x %02x\n"%(nmea_fpga_frmt[ 0],nmea_fpga_frmt[ 1],nmea_fpga_frmt[ 2],nmea_fpga_frmt[ 3])) # all but [0] are 0
        print("Format data for sentence 2 is %02x %02x %02x %02x\n"%(nmea_fpga_frmt[ 4],nmea_fpga_frmt[ 5],nmea_fpga_frmt[ 6],nmea_fpga_frmt[ 7]))
        print("Format data for sentence 3 is %02x %02x %02x %02x\n"%(nmea_fpga_frmt[ 8],nmea_fpga_frmt[ 9],nmea_fpga_frmt[10],nmea_fpga_frmt[11]))
        print("Format data for sentence 4 is %02x %02x %02x %02x\n"%(nmea_fpga_frmt[12],nmea_fpga_frmt[13],nmea_fpga_frmt[14],nmea_fpga_frmt[15]))
        self.x393_axi_tasks.write_control_register(vrlg.LOGGER_ADDR + self.ADDR_REG, self.X313_IMU_NMEA_FORMAT_ADDR);
        for i in range(16):
            self.x393_axi_tasks.write_control_register(vrlg.LOGGER_ADDR + self.DATA_REG, nmea_sel[i])
            print("Loaded imu fpga register 0x%x with 0x%x"%(self.X313_IMU_NMEA_FORMAT_ADDR + i, nmea_sel[i] ))
        for i in range(16):
            self.x393_axi_tasks.write_control_register(vrlg.LOGGER_ADDR + self.DATA_REG, nmea_fpga_frmt[i])
            print("Loaded imu fpga register 0x%x with 0x%x"%(self.X313_IMU_NMEA_FORMAT_ADDR + i + 16, nmea_fpga_frmt[i]))

    def logger_config(self,config):
        """
        Write configuration word to logger module
        @param config - logger configuration word
        
        """
        print("Writing logger configuration word: 0x%08x to register 0x%x"%(config & 0x3ffffff, vrlg.LOGGER_CONFIG))
        self.x393_axi_tasks.write_control_register(vrlg.LOGGER_ADDR + self.ADDR_REG, vrlg.LOGGER_CONFIG);
        self.x393_axi_tasks.write_control_register(vrlg.LOGGER_ADDR + self.DATA_REG, config & 0x3ffffff);

    def logger_registers(self,registers):
        """
        Specify IMU registers to log data for
        @param registers - list of IMU register addresses to write to the logger
        
        """
        self.x393_axi_tasks.write_control_register(vrlg.LOGGER_ADDR + self.ADDR_REG, self.X313_IMU_REGISTERS_ADDR);
        for i,c in enumerate(registers):
#            d = ord(c)
            d = c
            print("%d: logging IMU register with 0x%lx"%(i+1, d))
            self.x393_axi_tasks.write_control_register(vrlg.LOGGER_ADDR + self.DATA_REG, d);

    def logger_message(self,message):
        """
        Set odometer message (up to 56 bytes)
        @param message - odometer message as a string
        """
        lmessage = list(message)
        if len(lmessage) < 56:
            lmessage +=chr(0)*(56-len(lmessage))
        lmessage = lmessage[:56]
        print("Setting odometer message %56s"%(bytearray(self.zterm(lmessage)).decode()))
        self.x393_axi_tasks.write_control_register(vrlg.LOGGER_ADDR + self.ADDR_REG, self.X313_IMU_REGISTERS_ADDR)
        for i in range(0,56,4):
#            d=ord(lmessage[i]) + (ord(lmessage[i+1]) << 8)  + (ord(lmessage[i+1]) << 16)  + (ord(lmessage[i+1]) << 24)
            d=lmessage[i] + (lmessage[i+1] << 8)  + (lmessage[i+1] << 16)  + (lmessage[i+1] << 24)
            print("%d: message 4 bytes= 0x%08x"%((i//4)+1,d))
            self.x393_axi_tasks.write_control_register(vrlg.LOGGER_ADDR + self.DATA_REG, d)

    def logger_en_dma(self):
        """
        Turn on DMA
        """
        self.logger_dma_ctrl (mode = 2, chn = 0) # mode = 2 - enable and run
        print("Turn on DMA here")

    def logger_en_logger(self):
        """
        Enable logger (turn off reset)
        """
        print("Turning off logger reset")
        self.logger_reset(0)
        
    def set_logger_params(self, which,wbuf):
        """
        Set logger parameters from the string buffer (same as in the driver)
        @param which - bitmask of parameters to set:
            WHICH_INIT =                1
            WHICH_RESET =               2
            WHICH_RESET_SPI =           4
            WHICH_DIVISOR =             8
            WHICH_RS232DIV =           16
            WHICH_NMEA =               32
            WHICH_CONFIG =             64
            WHICH_REGISTERS =         128
            WHICH_MESSAGE =           256
            WHICH_PERIOD =            512
            WHICH_EN_DMA =           1024
            WHICH_EN_LOGGER =        2048
        @param wbuf - string with configuration data (as generated by start_gps_compas.php    
        """
        period =      struct.unpack_from("<I", wbuf, offset=self.X313_IMU_PERIOD_OFFS)[0]
        divisor =     struct.unpack_from("<I", wbuf, offset=self.X313_IMU_DIVISOR_OFFS)[0]
        rs232_div =   struct.unpack_from("<I", wbuf, offset=self.X313_IMU_RS232DIV_OFFS)[0]
        if (self.DRY_MODE):
            rs232_div = 8
        config =      struct.unpack_from("<I", wbuf, offset=self.X313_IMU_CONFIGURE_OFFS)[0]
        message =     wbuf[self.X313_IMU_MESSAGE_OFFS:    self.X313_IMU_MESSAGE_OFFS+56]
        nmea_format = wbuf[self.X313_IMU_NMEA_FORMAT_OFFS:self.X313_IMU_NMEA_FORMAT_OFFS+128]
        registers =   wbuf[self.X313_IMU_REGISTERS_OFFS:  self.X313_IMU_NMEA_FORMAT_OFFS]
        for i, d in enumerate(wbuf):
            if (i & 0x1f) == 0:
                print("\n %03x"%(i), end = "")
            print(" %02x"%(wbuf[i]),end="")
        if which & self.WHICH_RESET:
            self.logger_reset(1)
        if which & self.WHICH_INIT:
            self.logger_init(config)
        if which & self.WHICH_RESET_SPI:
            self.logger_reset_spi()
        if which & self.WHICH_DIVISOR:
            self.logger_set_divisor(divisor)
        if which & self.WHICH_RS232DIV:
            self.logger_set_rs232div(rs232_div)
        if which & self.WHICH_NMEA:
            self.logger_set_nmea(nmea_format)
        if which & self.WHICH_CONFIG:
            self.logger_config(config)
        if which & self.WHICH_REGISTERS:
            self.logger_registers(registers)
        if which & self.WHICH_MESSAGE:
            self.logger_message(message)
        if which & self.WHICH_PERIOD:
            self.logger_set_period(period)
        if which & self.WHICH_EN_DMA:
            self.logger_en_dma()
        if which & self.WHICH_EN_LOGGER:
            self.logger_en_logger()
    def set_logger_params_file(self, file_path="/home/eyesis/git/x393-neon/attic/imu_config.bin", which = 0x7fb): # 0x3f9):
        """
        Set logger parameters from the string buffer (same as in the driver)
        @param which - bitmask of parameters to set:
            WHICH_INIT =                1
            WHICH_RESET =               2
            WHICH_RESET_SPI =           4
            WHICH_DIVISOR =             8
            WHICH_RS232DIV =           16
            WHICH_NMEA =               32
            WHICH_CONFIG =             64
            WHICH_REGISTERS =         128
            WHICH_MESSAGE =           256
            WHICH_PERIOD =            512
            WHICH_EN_DMA =           1024
            WHICH_EN_LOGGER =        2048
        @param wbuf - string with configuration data (as generated by start_gps_compas.php    
        """
        with open (file_path,"rb") as f:
            wbuf=f.read()
        self.set_logger_params(which = which, wbuf=wbuf)
        
    """
    def logger_reset(self, rst):
    def logger_init(self,config):
    def logger_reset_spi(self):
    def logger_set_divisor(self,divisor):
    def logger_set_rs232div(self,divisor):
    def zterm(self,l):
    def logger_set_nmea(self, nmea_format):
    def logger_config(self,config):
    def logger_registers(self,registers):
    def logger_message(self,message):
    def logger_en_dma(self):
    def logger_en_logger(self):
    
    
    
    unsigned long * period=     (unsigned long *) &wbuf[X313_IMU_PERIOD_OFFS];
    unsigned long * divisor=    (unsigned long *) &wbuf[X313_IMU_DIVISOR_OFFS];
    unsigned long * rs232_div=  (unsigned long *) &wbuf[X313_IMU_RS232DIV_OFFS];
    unsigned long * config=     (unsigned long *) &wbuf[X313_IMU_CONFIGURE_OFFS];
    unsigned long * message=    (unsigned long *) &wbuf[X313_IMU_MESSAGE_OFFS];
    char * nmea_format=         (char *) &wbuf[X313_IMU_NMEA_FORMAT_OFFS];

period =    struct.unpack_from("<I", wbuf, offset=X313_IMU_PERIOD_OFFS)[0]
divisor =   struct.unpack_from("<I", wbuf, offset=X313_IMU_DIVISOR_OFFS)[0]
rs232_div = struct.unpack_from("<I", wbuf, offset=X313_IMU_RS232DIV_OFFS)[0]
config =    struct.unpack_from("<I", wbuf, offset=X313_IMU_CONFIGURE_OFFS)[0]
hex(period)    '0xffffffff'
hex(divisor)   '0x140a'
hex(rs232_div) '0x364'
hex(config)    '0x350eab5'

    
    
>>> with open ("/home/eyesis/git/x393-neon/attic/aaa","r") as f:
...     aaa=f.read()
which= 0x3f9
    WHICH_INIT =                1
    WHICH_RESET =               2
    WHICH_RESET_SPI =           4
    WHICH_DIVISOR =             8
    WHICH_RS232DIV =           16
    WHICH_NMEA =               32
    WHICH_CONFIG =             64
    WHICH_REGISTERS =         128
    WHICH_MESSAGE =           256
    WHICH_PERIOD =            512
    WHICH_EN_DMA =           1024
    WHICH_EN_LOGGER =        2048
    
#define   X313_IMU_REGISTERS_ADDR    0x4
#define   X313_IMU_NMEA_FORMAT_ADDR  0x20
#define   X313_IMU_MESSAGE_ADDR    0x40  ///< 40..4f, only first 0xe visible

// offsets in the file (during write)
#define   X313_IMU_PERIOD_OFFS     0x0
#define   X313_IMU_DIVISOR_OFFS    0x4

#define   X313_IMU_RS232DIV_OFFS   0x8
#define   X313_IMU_CONFIGURE_OFFS  0xc

#define   X313_IMU_SLEEP_OFFS      0x10
#define   X313_IMU_REGISTERS_OFFS  0x14 // .. 0x2f

#define   X313_IMU_NMEA_FORMAT_OFFS  0x30
#define   X313_IMU_MESSAGE_OFFS      0xB0 // 0xB0..0xE7

    
     def set_gpio_ports(self,
                       port_soft = None,
                       port_a =    None,
                       port_b =    None,
                       port_c =    None):
        Set status GPIO ports (None - no change, False - disable, True - enable)
        @param port_soft - software-controlled port
        @param port_a -    port A : camsync
        @param port_b -    port B : motors on 10353, unused on 10393
        @param port_c -    port C : logger (IMU/GPS, external)
        data = 0
        if not port_soft is None:
            data |= (2,3)[port_soft]
        if not port_a is None:
            data |= (2,3)[port_a] << 2
        if not port_b is None:
            data |= (2,3)[port_a] << 4
        if not port_c is None:
            data |= (2,3)[port_a] << 6
        self.x393_axi_tasks.write_control_register(vrlg.GPIO_ADDR +  vrlg.GPIO_SET_PINS, data << vrlg.GPIO_PORTEN)

    parameter LOGGER_ADDR =                    'h720, //..'h721
    parameter LOGGER_STATUS =                  'h722, // .. 'h722
    parameter LOGGER_STATUS_REG_ADDR =         'h39, // just 1 location)
    parameter LOGGER_MASK =                    'h7fe,
    parameter LOGGER_STATUS_MASK =             'h7ff,
//First 4 registers are not used (it is when time stamps are sent)
    parameter LOGGER_PAGE_IMU =                 0, // 'h04..'h1f - overlaps with period/duration/halfperiod/config? (was so in x353)
    parameter LOGGER_PAGE_GPS =                 1, // 'h20..'h3f
    parameter LOGGER_PAGE_MSG =                 2, // 'h40..'h5f
    
    parameter LOGGER_PERIOD =                   0,
    parameter LOGGER_BIT_DURATION =             1,
    parameter LOGGER_BIT_HALF_PERIOD =          2, //rs232 half bit period
    parameter LOGGER_CONFIG =                   3,

    parameter LOGGER_CONF_IMU =                 2,
    parameter LOGGER_CONF_IMU_BITS =            2,
    parameter LOGGER_CONF_GPS =                 7,
    parameter LOGGER_CONF_GPS_BITS =            4,
    parameter LOGGER_CONF_MSG =                13,
    parameter LOGGER_CONF_MSG_BITS =            5,
    parameter LOGGER_CONF_SYN =                18, // 15,
    parameter LOGGER_CONF_SYN_BITS =            4, // 1,
    parameter LOGGER_CONF_EN =                 20, // 17,
    parameter LOGGER_CONF_EN_BITS =             1,
    parameter LOGGER_CONF_DBG =                25, // 22,
    parameter LOGGER_CONF_DBG_BITS =            4,

    parameter GPIO_N =                     10 // number of GPIO bits to control
X313_IMU_PERIOD_OFFS =      0x0
X313_IMU_DIVISOR_OFFS =     0x4

X313_IMU_RS232DIV_OFFS =    0x8
X313_IMU_CONFIGURE_OFFS =   0xc

X313_IMU_SLEEP_OFFS =       0x10
X313_IMU_REGISTERS_OFFS =   0x14 # .. 0x2f

X313_IMU_NMEA_FORMAT_OFFS = 0x30
X313_IMU_MESSAGE_OFFS =     0xB0 # 0xB0..0xE7
    
    """
