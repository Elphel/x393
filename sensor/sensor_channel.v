/*******************************************************************************
 * Module: sensor_channel
 * Date:2015-05-10  
 * Author: Andrey Filippov     
 * Description: Top module for a sensor channel
 *
 * Copyright (c) 2015 Elphel, Inc.
 * sensor_channel.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  sensor_channel.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  sensor_channel#(
    // parameters, individual to sensor channels and those likely to be modified
    parameter SENSOR_NUMBER =             0,     // sensor number (0..3)
    parameter SENSOR_GROUP_ADDR =         'h400, // sensor registers base address
    parameter SENSOR_BASE_INC =           'h040, // increment for sesor channel
    parameter SENSI2C_STATUS_REG_BASE =   'h20,  // 4 locations" x30, x32, x34, x36
    parameter SENSI2C_STATUS_REG_INC =    2,     // increment to the next sensor
    parameter SENSI2C_STATUS_REG_REL =    0,     // 4 locations" 'h30, 'h32, 'h34, 'h36
    parameter SENSIO_STATUS_REG_REL =     1,     // 4 locations" 'h31, 'h33, 'h35, 'h37

    parameter SENS_SYNC_RADDR  =          'h4,
    parameter SENS_SYNC_MASK  =           'h7fc,
    // 2 locations reserved for control/status (if they will be needed)
    parameter SENS_SYNC_MULT  =           'h2,   // relative register address to write number of frames to combine in one (minus 1, '0' - each farme)
    parameter SENS_SYNC_LATE  =           'h3,    // number of lines to delay late frame sync
    parameter SENS_SYNC_FBITS =           16,    // number of bits in a frame counter for linescan mode
    parameter SENS_SYNC_LBITS =           16,    // number of bits in a line counter for sof_late output (limited by eof) 
    parameter SENS_SYNC_LATE_DFLT =       15,    // number of lines to delay late frame sync
    parameter SENS_SYNC_MINBITS =         8,    // number of bits to enforce minimal frame period 
    parameter SENS_SYNC_MINPER =          130,    // minimal frame period (in pclk/mclk?) 
    

    parameter SENSOR_NUM_HISTOGRAM=       3, // number of histogram channels
    parameter HISTOGRAM_RAM_MODE =        "NOBUF", // valid: "NOBUF" (32-bits, no buffering), "BUF18", "BUF32"
    parameter SENS_NUM_SUBCHN =        3, // number of subchannels for his sensor ports (1..4)
    parameter SENS_GAMMA_BUFFER =         0, // 1 - use "shadow" table for clean switching, 0 - single table per channel
    
    // parameters defining address map
    parameter SENSOR_CTRL_RADDR =     0, //'h00
    parameter SENSOR_CTRL_ADDR_MASK = 'h7ff, //
        // bits of the SENSOR mode register
        parameter SENSOR_MODE_WIDTH =     10,
        parameter SENSOR_HIST_EN_BITS =    0,  // 0..3 1 - enable histogram modules, disable after processing the started frame
        parameter SENSOR_HIST_NRST_BITS =  4,  // 0 - immediately reset all histogram modules 
        parameter SENSOR_CHN_EN_BIT =      8,  // 1 - this enable channel
        parameter SENSOR_16BIT_BIT =       9, // 0 - 8 bpp mode, 1 - 16 bpp (bypass gamma). Gamma-processed data is still used for histograms
    
    parameter SENSI2C_CTRL_RADDR =    2, // 'h02..'h03
    parameter SENSI2C_CTRL_MASK =     'h7fe,
      // sensor_i2c_io relative control register addresses
      parameter SENSI2C_CTRL =          'h0,
    // Control register bits
        parameter SENSI2C_CMD_TABLE =       29, // [29]: 1 - write to translation table (ignore any other fields), 0 - write other fields
        parameter SENSI2C_CMD_TAND =        28, // [28]: 1 - write table address (8 bits), 0 - write table data (28 bits)
    
        parameter SENSI2C_CMD_RESET =       14, // [14]   reset all FIFO (takes 16 clock pulses), also - stops i2c until run command
        parameter SENSI2C_CMD_RUN =         13, // [13:12]3 - run i2c, 2 - stop i2c (needed before software i2c), 1,0 - no change to run state
        parameter SENSI2C_CMD_RUN_PBITS =    1,
        parameter SENSI2C_CMD_FIFO_RD =      3, // advane I2C read data FIFO by 1  
        parameter SENSI2C_CMD_ACIVE =        2, // [2] - SENSI2C_CMD_ACIVE_EARLY0, SENSI2C_CMD_ACIVE_SDA
        parameter SENSI2C_CMD_ACIVE_EARLY0 = 1, // release SDA==0 early if next bit ==1
        parameter SENSI2C_CMD_ACIVE_SDA =    0,  // drive SDA=1 during the second half of SCL=1
        
    //i2c page table bit fields
        parameter SENSI2C_TBL_RAH =          0, // high byte of the register address 
        parameter SENSI2C_TBL_RAH_BITS =     8,
        parameter SENSI2C_TBL_RNWREG =       8, // read register (when 0 - write register
        parameter SENSI2C_TBL_SA =           9, // Slave address in write mode
        parameter SENSI2C_TBL_SA_BITS =      7,
        parameter SENSI2C_TBL_NBWR =        16, // number of bytes to write (1..10)
        parameter SENSI2C_TBL_NBWR_BITS =    4,
        parameter SENSI2C_TBL_NBRD =        16, // number of bytes to read (1 - 8) "0" means "8"
        parameter SENSI2C_TBL_NBRD_BITS =    3,
        parameter SENSI2C_TBL_NABRD =       19, // number of address bytes for read (0 - 1 byte, 1 - 2 bytes)
        parameter SENSI2C_TBL_DLY =         20, // bit delay (number of mclk periods in 1/4 of SCL period)
        parameter SENSI2C_TBL_DLY_BITS=      8,
      
      parameter SENSI2C_STATUS =        'h1,
    
    parameter SENS_GAMMA_RADDR =       'h38, //4,  'h38..'h3b
    parameter SENS_GAMMA_ADDR_MASK =   'h7fc,
      // sens_gamma registers
      parameter SENS_GAMMA_CTRL =        'h0,
      parameter SENS_GAMMA_ADDR_DATA =   'h1, // bit 20 ==1 - table address, bit 20==0 - table data (18 bits)
      parameter SENS_GAMMA_HEIGHT01 =    'h2, // bits [15:0] - height minus 1 of image 0, [31:16] - height-1 of image1
      parameter SENS_GAMMA_HEIGHT2 =     'h3, // bits [15:0] - height minus 1 of image 2 ( no need for image 3)
        // bits of the SENS_GAMMA_CTRL mode register
        parameter SENS_GAMMA_MODE_WIDTH =  5, // does not include trig
        parameter SENS_GAMMA_MODE_BAYER =  0,
        parameter SENS_GAMMA_MODE_PAGE =   2,
        parameter SENS_GAMMA_MODE_EN =     3,
        parameter SENS_GAMMA_MODE_REPET =  4,
        parameter SENS_GAMMA_MODE_TRIG =   5,
// Vignetting correction / pixel value scaling - controlled via single data word (same as in 252), some of bits [23:16]
// are used to select register, bits 25:24 - select sub-frame
    parameter SENS_LENS_RADDR =             'h3c, 
    parameter SENS_LENS_ADDR_MASK =         'h7fc,
    parameter SENS_LENS_COEFF =             'h3, // set vignetting/scale coefficients (
      parameter SENS_LENS_AX =              'h00, // 00000...
      parameter SENS_LENS_AX_MASK =         'hf8,
      parameter SENS_LENS_AY =              'h08, // 00001...
      parameter SENS_LENS_AY_MASK =         'hf8,
      parameter SENS_LENS_C =               'h10, // 00010...
      parameter SENS_LENS_C_MASK =          'hf8,
      parameter SENS_LENS_BX =              'h20, // 001.....
      parameter SENS_LENS_BX_MASK =         'he0,
      parameter SENS_LENS_BY =              'h40, // 010.....
      parameter SENS_LENS_BY_MASK =         'he0,
      parameter SENS_LENS_SCALES =          'h60, // 01100...
      parameter SENS_LENS_SCALES_MASK =     'hf8,
      parameter SENS_LENS_FAT0_IN =         'h68, // 01101000
      parameter SENS_LENS_FAT0_IN_MASK =    'hff,
      parameter SENS_LENS_FAT0_OUT =        'h69, // 01101001
      parameter SENS_LENS_FAT0_OUT_MASK =   'hff,
      parameter SENS_LENS_POST_SCALE =      'h6a, // 01101010
      parameter SENS_LENS_POST_SCALE_MASK = 'hff,
    
    parameter SENSIO_RADDR =          8, //'h408  .. 'h40f
    parameter SENSIO_ADDR_MASK =      'h7f8,
      // sens_parallel12 registers
      parameter SENSIO_CTRL =           'h0,
        // SENSIO_CTRL register bits
        parameter SENS_CTRL_MRST =        0,  //  1: 0
        parameter SENS_CTRL_ARST =        2,  //  3: 2
        parameter SENS_CTRL_ARO =         4,  //  5: 4
        parameter SENS_CTRL_RST_MMCM =    6,  //  7: 6
        parameter SENS_CTRL_EXT_CLK =     8,  //  9: 8
        parameter SENS_CTRL_LD_DLY =     10,  // 10
        parameter SENS_CTRL_QUADRANTS =  12,  // 17:12, enable - 20
        parameter SENS_CTRL_QUADRANTS_WIDTH = 6,
        parameter SENS_CTRL_QUADRANTS_EN =   20,  // 17:12, enable - 20 (2 bits reserved)
      parameter SENSIO_STATUS =         'h1,
      parameter SENSIO_JTAG =           'h2,
        // SENSIO_JTAG register bits
        parameter SENS_JTAG_PGMEN =       8,
        parameter SENS_JTAG_PROG =        6,
        parameter SENS_JTAG_TCK =         4,
        parameter SENS_JTAG_TMS =         2,
        parameter SENS_JTAG_TDI =         0,
      parameter SENSIO_WIDTH =          'h3, // 1.. 2^16, 0 - use HACT
      parameter SENSIO_DELAYS =         'h4, // 'h4..'h7
        // 4 of 8-bit delays per register
    // sensor_i2c_io command/data write registers s (relative to SENSOR_BASE_ADDR)
    parameter SENSI2C_ABS_RADDR =       'h10, // 'h410..'h41f
    parameter SENSI2C_REL_RADDR =       'h20, // 'h420..'h42f
    parameter SENSI2C_ADDR_MASK =     'h7f0, // both for SENSI2C_ABS_ADDR and SENSI2C_REL_ADDR

    // sens_hist registers (relative to SENSOR_BASE_ADDR)
    parameter HISTOGRAM_RADDR0 =      'h30, //
    parameter HISTOGRAM_RADDR1 =      'h32, //
    parameter HISTOGRAM_RADDR2 =      'h34, //
    parameter HISTOGRAM_RADDR3 =      'h36, //
    parameter HISTOGRAM_ADDR_MASK =   'h7fe, // for each channel
      // sens_hist registers
      parameter HISTOGRAM_LEFT_TOP =     'h0,
      parameter HISTOGRAM_WIDTH_HEIGHT = 'h1, // 1.. 2^16, 0 - use HACT
    
    //sensor_i2c_io other parameters
    parameter integer SENSI2C_DRIVE=  12,
    parameter SENSI2C_IBUF_LOW_PWR=   "TRUE",
    parameter SENSI2C_IOSTANDARD =    "DEFAULT",
    parameter SENSI2C_SLEW =          "SLOW",
    
    //sensor_fifo parameters
    parameter SENSOR_DATA_WIDTH =      12,
    parameter SENSOR_FIFO_2DEPTH =     4,
    parameter SENSOR_FIFO_DELAY =      5, // 7,
    
    
    // sens_parallel12 other parameters
    
    parameter IODELAY_GRP ="IODELAY_SENSOR", // may need different for different channels?
    parameter integer IDELAY_VALUE = 0,
    parameter integer PXD_DRIVE = 12,
    parameter PXD_IBUF_LOW_PWR = "TRUE",
    parameter PXD_IOSTANDARD = "DEFAULT",
    parameter PXD_SLEW = "SLOW",
    parameter real SENS_REFCLK_FREQUENCY =    300.0,
    parameter SENS_HIGH_PERFORMANCE_MODE =    "FALSE",
    
    parameter SENS_PHASE_WIDTH=        8,      // number of bits for te phase counter (depends on divisors)
    parameter SENS_PCLK_PERIOD =       10.000,  // input period in ns, 0..100.000 - MANDATORY, resolution down to 1 ps
    parameter SENS_BANDWIDTH =         "OPTIMIZED",  //"OPTIMIZED", "HIGH","LOW"

    parameter CLKFBOUT_MULT_SENSOR =   8,  // 100 MHz --> 800 MHz
    parameter CLKFBOUT_PHASE_SENSOR =  0.000,  // CLOCK FEEDBACK phase in degrees (3 significant digits, -360.000...+360.000)
    parameter IPCLK_PHASE =            0.000,
    parameter IPCLK2X_PHASE =          0.000,
    parameter BUF_IPCLK =             "BUFR",
    parameter BUF_IPCLK2X =           "BUFR",  

    parameter SENS_DIVCLK_DIVIDE =     1,            // Integer 1..106. Divides all outputs with respect to CLKIN
    parameter SENS_REF_JITTER1   =     0.010,        // Expected jitter on CLKIN1 (0.000..0.999)
    parameter SENS_REF_JITTER2   =     0.010,
    parameter SENS_SS_EN         =     "FALSE",      // Enables Spread Spectrum mode
    parameter SENS_SS_MODE       =     "CENTER_HIGH",//"CENTER_HIGH","CENTER_LOW","DOWN_HIGH","DOWN_LOW"
    parameter SENS_SS_MOD_PERIOD =     10000        // integer 4000-40000 - SS modulation period in ns
`ifdef DEBUG_RING
        ,parameter DEBUG_CMD_LATENCY = 2 
`endif        
    
) (
//    input         rst,
    input         pclk,   // global clock input, pixel rate (96MHz for MT9P006)
    // TODO: get rid of pclk2x in histograms by doubling memories (making 1 write port and 2 read ones)
    // How to erase?
    // Alternative: copy/erase to a separate buffer in the beginning/end of a frame?
    input         pclk2x, // global clock input, double pixel rate (192MHz for MT9P006)
    
    input         mrst,      // @posedge mclk, sync reset
    input         prst,      // @posedge pclk, sync reset
    
    // I/O pads, pin names match circuit diagram
    inout   [7:0] sns_dp,
    inout   [7:0] sns_dn,
    inout         sns_clkp,
    inout         sns_clkn,
    inout         sns_scl,
    inout         sns_sda,
    inout         sns_ctl,
    inout         sns_pg,
    // programming interface
    input         mclk,     // global clock, half DDR3 clock, synchronizes all I/O through the command port
    input   [7:0] cmd_ad_in,      // byte-serial command address/data (up to 6 bytes: AL-AH-D0-D1-D2-D3 
    input         cmd_stb_in,     // strobe (with first byte) for the command a/d
    output  [7:0] status_ad,   // status address/data - up to 5 bytes: A - {seq,status[1:0]} - status[2:9] - status[10:17] - status[18:25]
    output        status_rq,   // input request to send status downstream
    input         status_start, // Acknowledge of the first status packet byte (address)

    input         trigger_mode, // running in triggered mode (0 - free running mode)
    input         trig_in,      // per-sensor trigger input

    // 16/8-bit mode data to memory (8-bits are packed by 2 in 16 mode @posedge pclk
    output [15:0] dout,         // @posedge pclk
    output        dout_valid,   // in 8-bit mode continues pixel flow have dout_valid alternating on/off
    output        last_in_line, // valid with dout_valid - last in line dout
     
    output        sof_out,       // @pclk start of frame 1-clk pulse with the same delays as output data
    output        eof_out,       // @pclk end of frame 1-clk pulse with the same delays as output data
    output        sof_out_mclk,  // @mclk filtered, possibly decimated  start of frame 
    output        sof_late_mclk, // @mclk filtered, possibly decimated  start of frame, delayed by specified number of lines

    // histogram interface to S_AXI, 256x32bit continuous bursts @posedge mclk, each histogram having 4 bursts
    output        hist_request, // request to transfer a burst
    input         hist_grant,   // request to transfer over S_AXI granted
    output  [1:0] hist_chn,     // output[1:0] histogram (sub) channel, valid with request and transfer
    output        hist_dvalid,  // output data valid - active when sending a burst
    output [31:0] hist_data     // output[31:0] histogram data
`ifdef DEBUG_RING       
    ,output                       debug_do, // output to the debug ring
     input                        debug_sl, // 0 - idle, (1,0) - shift, (1,1) - load
     input                        debug_di  // input from the debug ring
`endif         
    
);
`ifdef DEBUG_RING
    localparam DEBUG_RING_LENGTH = 5; // for now - just connect the histogram(s) module(s)
    wire [DEBUG_RING_LENGTH:0] debug_ring; // TODO: adjust number of bits
    assign debug_do = debug_ring[0];
    assign debug_ring[DEBUG_RING_LENGTH] = debug_di;
`endif    


    localparam    HIST_MONOCHROME = 1'b0; // TODO:make it configurable (at expense of extra hardware)


    localparam SENSOR_BASE_ADDR =   (SENSOR_GROUP_ADDR + SENSOR_NUMBER * SENSOR_BASE_INC);
    localparam SENSI2C_STATUS_REG = (SENSI2C_STATUS_REG_BASE + SENSOR_NUMBER * SENSI2C_STATUS_REG_INC + SENSI2C_STATUS_REG_REL);
    localparam SENSIO_STATUS_REG =  (SENSI2C_STATUS_REG_BASE + SENSOR_NUMBER * SENSI2C_STATUS_REG_INC + SENSIO_STATUS_REG_REL);
    localparam SENS_SYNC_ADDR =     SENSOR_BASE_ADDR + SENS_SYNC_RADDR;
//    parameter SENSOR_BASE_ADDR =    'h300; // sensor registers base address
    localparam SENSOR_CTRL_ADDR =  SENSOR_BASE_ADDR + SENSOR_CTRL_RADDR;
    localparam SENSI2C_CTRL_ADDR = SENSOR_BASE_ADDR + SENSI2C_CTRL_RADDR;
    localparam SENS_GAMMA_ADDR =   SENSOR_BASE_ADDR + SENS_GAMMA_RADDR;
    localparam SENSIO_ADDR =       SENSOR_BASE_ADDR + SENSIO_RADDR; 
    localparam SENS_LENS_ADDR =    SENSOR_BASE_ADDR + SENS_LENS_RADDR; 
    localparam SENSI2C_ABS_ADDR =  SENSOR_BASE_ADDR + SENSI2C_ABS_RADDR;
    localparam SENSI2C_REL_ADDR =  SENSOR_BASE_ADDR + SENSI2C_REL_RADDR;
    localparam HISTOGRAM_ADDR0 =   (SENSOR_NUM_HISTOGRAM > 0)?(SENSOR_BASE_ADDR + HISTOGRAM_RADDR0):-1; //
    localparam HISTOGRAM_ADDR1 =   (SENSOR_NUM_HISTOGRAM > 1)?(SENSOR_BASE_ADDR + HISTOGRAM_RADDR1):-1; //
    localparam HISTOGRAM_ADDR2 =   (SENSOR_NUM_HISTOGRAM > 2)?(SENSOR_BASE_ADDR + HISTOGRAM_RADDR2):-1; //
    localparam HISTOGRAM_ADDR3 =   (SENSOR_NUM_HISTOGRAM > 3)?(SENSOR_BASE_ADDR + HISTOGRAM_RADDR3):-1; //


    reg    [7:0] cmd_ad;      // byte-serial command address/data (up to 6 bytes: AL-AH-D0-D1-D2-D3 
    reg          cmd_stb;     // strobe (with first byte) for the command a/d


    wire   [7:0] sens_i2c_status_ad;
    wire         sens_i2c_status_rq;
    wire         sens_i2c_status_start;
    wire   [7:0] sens_par12_status_ad;
    wire         sens_par12_status_rq;
    wire         sens_par12_status_start;
    
    wire         ipclk;   // Use in FIFO
//    wire         ipclk2x; // Use in FIFO?
    wire  [11:0] pxd_to_fifo;
    wire         vact_to_fifo;    // frame active @posedge  ipclk
    wire         hact_to_fifo;    // line active @posedge  ipclk
    
    // data from FIFO
    wire  [11:0] pxd;     // TODO: align MSB? parallel data, @posedge  ipclk
    wire         hact;    // line active @posedge  ipclk
    wire         sof; // start of frame
    wire         eof; // end of frame
    
    wire         sof_out_sync; // sof filtetred, optionally decimated (for linescan mode)
    
    wire  [15:0] lens_pxd_in; 
    wire         lens_hact_in;
    wire         lens_sof_in;
    wire         lens_eof_in;



    wire  [15:0] gamma_pxd_in; 
    wire         gamma_hact_in;
    wire         gamma_sof_in;
    wire         gamma_eof_in;
    wire   [1:0] gamma_bayer; // gamma module mode register bits -> lens_flat module
    
    
    wire   [7:0] gamma_pxd_out; 
    wire         gamma_hact_out;
    wire         gamma_sof_out;
    wire         gamma_eof_out;
    
    wire  [31:0] sensor_ctrl_data;
    wire         sensor_ctrl_we;
    reg    [SENSOR_MODE_WIDTH-1:0] mode;
    wire   [3:0] hist_en;
    wire         en_mclk; // enable this channel
    wire         en_pclk; // enable in pclk domain   
    wire   [3:0] hist_nrst;
    wire         bit16; // 16-bit mode, 0 - 8 bit mode
    wire   [3:0] hist_rq;
    wire   [3:0] hist_gr;
    wire   [3:0] hist_dv;
    wire  [31:0] hist_do0;
    wire  [31:0] hist_do1;
    wire  [31:0] hist_do2;
    wire  [31:0] hist_do3;
    reg    [7:0] gamma_data_r;
    reg   [15:0] dout_r;
    reg          dav_8bit;
    reg          dav_r;       
    wire  [15:0] dout_w;
    wire         dav_w;
    wire         trig;
    reg          sof_out_r;       
    reg          eof_out_r;       
    
    // TODO: insert vignetting and/or flat field, pixel defects before gamma_*_in
    assign lens_pxd_in = {pxd[11:0],4'b0};
    assign lens_hact_in = hact;
    assign lens_sof_in =  sof_out_sync; // sof;
    assign lens_eof_in =  eof;
    
    assign dout = dout_r;
    assign dout_valid = dav_r;
    assign sof_out = sof_out_r;       
    assign eof_out = eof_out_r;       
    
//    assign dout_w = bit16 ? gamma_pxd_in :  {gamma_data_r,gamma_pxd_out};
    assign dout_w = bit16 ? gamma_pxd_in :  {gamma_pxd_out,gamma_data_r}; // earlier data in LSB, later - MSB
    assign dav_w =  bit16 ? gamma_hact_in : dav_8bit;
    assign last_in_line = ! ( bit16 ? gamma_hact_in : gamma_hact_out);
     
    assign en_mclk =   mode[SENSOR_CHN_EN_BIT];
    assign hist_en =   mode[SENSOR_HIST_EN_BITS +: 4];
    assign hist_nrst = mode[SENSOR_HIST_NRST_BITS +: 4];
    assign bit16 =     mode[SENSOR_16BIT_BIT];
    
    
`ifdef DEBUG_RING
    reg vact_to_fifo_r;
    reg hact_to_fifo_r;
    reg [15:0] debug_line_cntr;
    reg [15:0] debug_lines;
    reg [15:0] hact_cntr;
    reg [15:0] vact_cntr;
    
    always @(posedge ipclk) begin
        vact_to_fifo_r <= vact_to_fifo;
        hact_to_fifo_r <= hact_to_fifo;

        if      (vact_to_fifo && !vact_to_fifo_r)  debug_line_cntr <= 0;
        else if (hact_to_fifo && !hact_to_fifo_r)  debug_line_cntr <= debug_line_cntr + 1;

        if      (vact_to_fifo && !vact_to_fifo_r)   debug_lines <= debug_line_cntr;
        
        if      (irst)                              hact_cntr <= 0;
        else if (hact_to_fifo && !hact_to_fifo_r)   hact_cntr <= hact_cntr + 1;

        if      (irst)                              vact_cntr <= 0;
        else if (vact_to_fifo && !vact_to_fifo_r)   vact_cntr <= vact_cntr + 1;
        
    end
    debug_slave #(
        .SHIFT_WIDTH       (128),
        .READ_WIDTH        (128),
        .WRITE_WIDTH       (32),
        .DEBUG_CMD_LATENCY (DEBUG_CMD_LATENCY)
    ) debug_slave_i (
        .mclk       (mclk),          // input
        .mrst       (mrst),          // input
        .debug_di   (debug_ring[5]), // input
        .debug_sl   (debug_sl),      // input
        .debug_do   (debug_ring[4]), // output
//        .rd_data   ({height_m1[15:0], vcntr[15:0], width_m1[15:0],  hcntr[15:0]}), // input[31:0] 
//        .rd_data   ({vact_cntr[15:0], hact_cntr[15:0], debug_lines[15:0], debug_line_cntr[15:0]}), // input[31:0]
//        .rd_data   ({6'b0,hist_grant,hist_request, hist_gr[3:0], hist_rq[3:0], hact_cntr[15:0], debug_lines[15:0], debug_line_cntr[15:0]}), // input[31:0]
        .rd_data   ({
        lens_pxd_in, gamma_pxd_in[15:0],
        pxd_to_fifo[11:0],pxd[11:0],gamma_pxd_out[7:0],
        6'b0,hist_grant,hist_request, hist_gr[3:0], hist_rq[3:0], hact_cntr[15:0],
        debug_lines[15:0], debug_line_cntr[15:0]}), // input[31:0]
         
//debug_lines <= debug_line_cntr        
        .wr_data    (), // output[31:0]  - not used
        .stb        () // output  - not used
    );
`endif    
    
    
    always @ (posedge mclk) begin
        cmd_ad  <= cmd_ad_in; 
        cmd_stb <= cmd_stb_in;
    end

    always @ (posedge mclk) begin
        if      (mrst)           mode <= 0;
        else if (sensor_ctrl_we) mode <= sensor_ctrl_data[SENSOR_MODE_WIDTH-1:0];
    end
    
    always @ (posedge pclk) begin
        if (dav_w) dout_r <= dout_w;

        dav_r <= dav_w;

        dav_8bit <= gamma_hact_out && !dav_8bit;
        
        if (gamma_hact_out && !dav_8bit) gamma_data_r <= gamma_pxd_out;
        
        sof_out_r <= bit16 ? gamma_sof_in : gamma_sof_out;
        eof_out_r <= bit16 ? gamma_eof_in : gamma_eof_out;
    end

    level_cross_clocks  level_cross_clocks_en_pclk_i (.clk(pclk), .d_in(en_mclk), .d_out(en_pclk));
    
    status_router2 status_router2_sensor_i (
        .rst       (1'b0), //rst),                     // input
        .clk       (mclk),                    // input
        .srst      (mrst),                    // input
        .db_in0    (sens_i2c_status_ad),      // input[7:0] 
        .rq_in0    (sens_i2c_status_rq),      // input
        .start_in0 (sens_i2c_status_start),   // output
        .db_in1    (sens_par12_status_ad),    // input[7:0] 
        .rq_in1    (sens_par12_status_rq),    // input
        .start_in1 (sens_par12_status_start), // output
        .db_out    (status_ad),               // output[7:0] 
        .rq_out    (status_rq),               // output
        .start_out (status_start)             // input
    );

    cmd_deser #(
        .ADDR        (SENSOR_CTRL_ADDR),
        .ADDR_MASK   (SENSOR_CTRL_ADDR_MASK),
        .NUM_CYCLES  (6),
        .ADDR_WIDTH  (1),
        .DATA_WIDTH  (32)
    ) cmd_deser_sens_channel_i (
        .rst         (1'b0), // rst),               // input
        .clk         (mclk),              // input
        .srst        (mrst),                    // input
        .ad          (cmd_ad),            // input[7:0] 
        .stb         (cmd_stb),           // input
        .addr      (),                    // output[0:0] - not used
        .data        (sensor_ctrl_data),  // output[31:0] 
        .we          (sensor_ctrl_we)     // output
    );

    sensor_i2c_io #(
        .SENSI2C_ABS_ADDR        (SENSI2C_ABS_ADDR),
        .SENSI2C_REL_ADDR        (SENSI2C_REL_ADDR),
        .SENSI2C_ADDR_MASK       (SENSI2C_ADDR_MASK),
        .SENSI2C_CTRL_ADDR       (SENSI2C_CTRL_ADDR),
        .SENSI2C_CTRL_MASK       (SENSI2C_CTRL_MASK),
        .SENSI2C_CTRL            (SENSI2C_CTRL),
        .SENSI2C_STATUS          (SENSI2C_STATUS),
        .SENSI2C_STATUS_REG      (SENSI2C_STATUS_REG),
        .SENSI2C_CMD_TABLE       (SENSI2C_CMD_TABLE),
        .SENSI2C_CMD_TAND        (SENSI2C_CMD_TAND),
        .SENSI2C_CMD_RESET       (SENSI2C_CMD_RESET),
        .SENSI2C_CMD_RUN         (SENSI2C_CMD_RUN),
        .SENSI2C_CMD_RUN_PBITS   (SENSI2C_CMD_RUN_PBITS),
        .SENSI2C_CMD_FIFO_RD     (SENSI2C_CMD_FIFO_RD),
        .SENSI2C_CMD_ACIVE       (SENSI2C_CMD_ACIVE),
        .SENSI2C_CMD_ACIVE_EARLY0(SENSI2C_CMD_ACIVE_EARLY0),
        .SENSI2C_CMD_ACIVE_SDA   (SENSI2C_CMD_ACIVE_SDA),
        .SENSI2C_TBL_RAH         (SENSI2C_TBL_RAH), // high byte of the register address 
        .SENSI2C_TBL_RAH_BITS    (SENSI2C_TBL_RAH_BITS),
        .SENSI2C_TBL_RNWREG      (SENSI2C_TBL_RNWREG), // read register (when 0 - write register
        .SENSI2C_TBL_SA          (SENSI2C_TBL_SA), // Slave address in write mode
        .SENSI2C_TBL_SA_BITS     (SENSI2C_TBL_SA_BITS),
        .SENSI2C_TBL_NBWR        (SENSI2C_TBL_NBWR), // number of bytes to write (1..10)
        .SENSI2C_TBL_NBWR_BITS   (SENSI2C_TBL_NBWR_BITS),
        .SENSI2C_TBL_NBRD        (SENSI2C_TBL_NBRD), // number of bytes to read (1 - 8) "0" means "8"
        .SENSI2C_TBL_NBRD_BITS   (SENSI2C_TBL_NBRD_BITS),
        .SENSI2C_TBL_NABRD       (SENSI2C_TBL_NABRD), // number of address bytes for read (0 - 1 byte, 1 - 2 bytes)
        .SENSI2C_TBL_DLY         (SENSI2C_TBL_DLY),   // bit delay (number of mclk periods in 1/4 of SCL period)
        .SENSI2C_TBL_DLY_BITS    (SENSI2C_TBL_DLY_BITS),
        .SENSI2C_DRIVE           (SENSI2C_DRIVE),
        .SENSI2C_IBUF_LOW_PWR    (SENSI2C_IBUF_LOW_PWR),
        .SENSI2C_IOSTANDARD      (SENSI2C_IOSTANDARD),
        .SENSI2C_SLEW            (SENSI2C_SLEW)
    ) sensor_i2c_io_i (
        .mrst                  (mrst),                  // input
        .mclk                  (mclk),                  // input
        .cmd_ad                (cmd_ad),                // input[7:0] 
        .cmd_stb               (cmd_stb),               // input
        .status_ad             (sens_i2c_status_ad),    // output[7:0] 
        .status_rq             (sens_i2c_status_rq),    // output
        .status_start          (sens_i2c_status_start), // input
        .frame_sync            (sof_out_mclk),          // input
        .scl                   (sns_scl),               // inout
        .sda                   (sns_sda)                // inout
    );
    
//    wire [3:0] debug_hist_mclk;
    wire irst; // @ posedge ipclk
    localparam STATUS_ALIVE_WIDTH = 8;
    wire [STATUS_ALIVE_WIDTH - 1 : 0] status_alive;
    reg  hact_r; // hact delayed by 1 cycle to generate start pulse
    wire sol_mclk;
    wire sof_mclk;
    wire eof_mclk;
    reg hist_rq0_r;
    reg hist_gr0_r;
    wire alive_hist0_rq = hist_rq[0] && !hist_rq0_r;
    wire alive_hist0_gr = hist_gr[0] && !hist_gr0_r;
    // sof_out_mclk - already exists
    reg dout_valid_d_pclk; //@ pclk - delayed by 1 clk from dout_valid to detect edge
    reg last_in_line_d_pclk; //@ pclk - delayed by 1 clk from last_in_line to detect edge
    wire dout_valid_1cyc_mclk;
    wire last_in_line_1cyc_mclk;
// debug_hist_mclk is never active, alive_hist0_rq == 0
//    assign status_alive = {last_in_line_1cyc_mclk, dout_valid_1cyc_mclk, alive_hist0_gr, alive_hist0_rq, sof_out_mclk, eof_mclk, sof_mclk, sol_mclk};
//    assign status_alive = {last_in_line_1cyc_mclk, dout_valid_1cyc_mclk, debug_hist_mclk[0], alive_hist0_rq, sof_out_mclk, eof_mclk, sof_mclk, sol_mclk};
    assign status_alive = {last_in_line_1cyc_mclk, dout_valid_1cyc_mclk, alive_hist0_gr, alive_hist0_rq, sof_out_mclk, eof_mclk, sof_mclk, sol_mclk};
/*
 sof, hact are tested to be active

                .sof        (gamma_sof_out),  // input
                .hact       (gamma_hact_out), // input

*/    
    always @ (posedge pclk) begin
//        hact_r <= hact;
        hact_r <= gamma_hact_out;
        dout_valid_d_pclk <= dout_valid;
        last_in_line_d_pclk <= last_in_line;
    end
    
    always @ (posedge mclk) begin
//        hist_rq0_r <= en_mclk & (hist_rq[0] ^ hist_rq0_r);
        hist_rq0_r <= hist_rq[0];
        hist_gr0_r <= hist_gr[0];
    end
    
    /*
                .hist_rq    (hist_rq[0]),     // output
                .hist_grant (hist_gr[0]),     // input
    */
// for debug/test alive   
    pulse_cross_clock pulse_cross_clock_sol_mclk_i (
        .rst         (prst),                  // input
        .src_clk     (pclk),                  // input
        .dst_clk     (mclk),                  // input
//        .in_pulse    (hact && !hact_r),       // input
        .in_pulse    (gamma_hact_out && !hact_r),       // input
        .out_pulse   (sol_mclk),              // output
        .busy() // output
    );

    pulse_cross_clock pulse_cross_clock_sof_mclk_i (
        .rst         (prst),                  // input
        .src_clk     (pclk),                  // input
        .dst_clk     (mclk),                  // input
//        .in_pulse    (sof),                   // input
        .in_pulse    (gamma_sof_out),         // input
        .out_pulse   (sof_mclk),              // output
        .busy() // output
    );

    pulse_cross_clock pulse_cross_clock_eof_mclk_i (
        .rst         (prst),                  // input
        .src_clk     (pclk),                  // input
        .dst_clk     (mclk),                  // input
        .in_pulse    (eof),                   // input
        .out_pulse   (eof_mclk),              // output
        .busy() // output
    );

    pulse_cross_clock pulse_cross_clock_dout_valid_1cyc_mclk_i (
        .rst         (prst),                             // input
        .src_clk     (pclk),                             // input
        .dst_clk     (mclk),                             // input
        .in_pulse    (dout_valid && !dout_valid_d_pclk), // input
        .out_pulse   (dout_valid_1cyc_mclk),             // output
        .busy() // output
    );

    pulse_cross_clock pulse_cross_clock_last_in_line_1cyc_mclk_i (
        .rst         (prst),                                 // input
        .src_clk     (pclk),                                 // input
        .dst_clk     (mclk),                                 // input
        .in_pulse    (last_in_line && !last_in_line_d_pclk), // input
        .out_pulse   (last_in_line_1cyc_mclk),               // output
        .busy() // output
    );

    
    sens_parallel12 #(
        .SENSIO_ADDR           (SENSIO_ADDR),
        .SENSIO_ADDR_MASK      (SENSIO_ADDR_MASK),
        .SENSIO_CTRL           (SENSIO_CTRL),
        .SENSIO_STATUS         (SENSIO_STATUS),
        .SENSIO_JTAG           (SENSIO_JTAG),
        .SENSIO_WIDTH          (SENSIO_WIDTH),
        .SENSIO_DELAYS         (SENSIO_DELAYS),
        .SENSIO_STATUS_REG     (SENSIO_STATUS_REG),
        .SENS_JTAG_PGMEN       (SENS_JTAG_PGMEN),
        .SENS_JTAG_PROG        (SENS_JTAG_PROG),
        .SENS_JTAG_TCK         (SENS_JTAG_TCK),
        .SENS_JTAG_TMS         (SENS_JTAG_TMS),
        .SENS_JTAG_TDI         (SENS_JTAG_TDI),
        .SENS_CTRL_MRST        (SENS_CTRL_MRST),
        .SENS_CTRL_ARST        (SENS_CTRL_ARST),
        .SENS_CTRL_ARO         (SENS_CTRL_ARO),
        .SENS_CTRL_RST_MMCM    (SENS_CTRL_RST_MMCM),
        .SENS_CTRL_EXT_CLK     (SENS_CTRL_EXT_CLK),
        .SENS_CTRL_LD_DLY      (SENS_CTRL_LD_DLY),
        .SENS_CTRL_QUADRANTS   (SENS_CTRL_QUADRANTS),
        .SENS_CTRL_QUADRANTS_WIDTH  (SENS_CTRL_QUADRANTS_WIDTH),
        .SENS_CTRL_QUADRANTS_EN     (SENS_CTRL_QUADRANTS_EN),
        .IODELAY_GRP           (IODELAY_GRP),
        .IDELAY_VALUE          (IDELAY_VALUE),
        .PXD_DRIVE             (PXD_DRIVE),
        .PXD_IBUF_LOW_PWR      (PXD_IBUF_LOW_PWR),
        .PXD_IOSTANDARD        (PXD_IOSTANDARD),
        .PXD_SLEW              (PXD_SLEW),
        .SENS_REFCLK_FREQUENCY (SENS_REFCLK_FREQUENCY),
        .SENS_HIGH_PERFORMANCE_MODE (SENS_HIGH_PERFORMANCE_MODE),
        .SENS_PHASE_WIDTH      (SENS_PHASE_WIDTH),
        .SENS_PCLK_PERIOD      (SENS_PCLK_PERIOD),
        .SENS_BANDWIDTH        (SENS_BANDWIDTH),
        .CLKFBOUT_MULT_SENSOR  (CLKFBOUT_MULT_SENSOR),
        .CLKFBOUT_PHASE_SENSOR (CLKFBOUT_PHASE_SENSOR),
        .IPCLK_PHASE           (IPCLK_PHASE),
        .IPCLK2X_PHASE         (IPCLK2X_PHASE),
        .BUF_IPCLK             (BUF_IPCLK),
        .BUF_IPCLK2X           (BUF_IPCLK2X),
        .SENS_DIVCLK_DIVIDE    (SENS_DIVCLK_DIVIDE),
        .SENS_REF_JITTER1      (SENS_REF_JITTER1),
        .SENS_REF_JITTER2      (SENS_REF_JITTER2),
        .SENS_SS_EN            (SENS_SS_EN),
        .SENS_SS_MODE          (SENS_SS_MODE),
        .SENS_SS_MOD_PERIOD    (SENS_SS_MOD_PERIOD),
        .STATUS_ALIVE_WIDTH    (STATUS_ALIVE_WIDTH)
    ) sens_parallel12_i (
//        .rst                  (rst),                    // input
        .pclk                 (pclk),                   // input
        .mclk_rst             (mrst),                   // input
        .prst                 (prst),                   // input
        .irst                 (irst),                   // output
        .ipclk                (ipclk),                  // output
        .ipclk2x              (), // ipclk2x),          // output
        .trigger_mode         (trigger_mode), // input
        .trig                 (trig),                   // input
        .vact                 (sns_dn[1]),              // input
        .hact                 (sns_dp[1]),              // input
        .bpf                  (sns_dn[0]),              // inout
        .pxd                  ({sns_dn[6],sns_dp[6],sns_dn[5],sns_dp[5],sns_dn[4],sns_dp[4],sns_dn[3],sns_dp[3],sns_dn[2],sns_dp[2],sns_clkp,sns_clkn}), // inout[11:0] 
        .mrst                 (sns_dp[7]),              // inout
        .senspgm              (sns_pg),                 // inout
        .arst                 (sns_dn[7]),              // inout
        .aro                  (sns_ctl),                // inout
        .dclk                 (sns_dp[0]),              // output
        .pxd_out              (pxd_to_fifo[11:0]),      // output[11:0] @posedge ipclk
        .vact_out             (vact_to_fifo),           // output @posedge ipclk
        .hact_out             (hact_to_fifo),           // output @posedge ipclk: either delayed input, or regenerated from the leading edge and programmable duration
        .status_alive_1cyc    (status_alive),           // input [3:0] @ posedge mclk, each bit single cycle pulse
        .mclk                 (mclk),                   // input
        .cmd_ad               (cmd_ad),                 // input[7:0] 
        .cmd_stb              (cmd_stb),                // input
        .status_ad            (sens_par12_status_ad),   // output[7:0] 
        .status_rq            (sens_par12_status_rq),   // output
        .status_start         (sens_par12_status_start) // input
    );

    sensor_fifo #(
        .SENSOR_DATA_WIDTH  (SENSOR_DATA_WIDTH),
        .SENSOR_FIFO_2DEPTH (SENSOR_FIFO_2DEPTH),
        .SENSOR_FIFO_DELAY  (SENSOR_FIFO_DELAY)
    ) sensor_fifo_i (
//        .rst         (rst),        // input
        .iclk        (ipclk),        // input
        .pclk        (pclk),         // input
        .prst        (prst),         // input
        .irst        (irst),         // input
        .pxd_in      (pxd_to_fifo),  // input[11:0] 
        .vact        (vact_to_fifo), // input
        .hact        (hact_to_fifo), // input
        .pxd_out     (pxd),          // output[11:0]  @posedge pclk
        .data_valid  (hact),         // output @posedge pclk
        .sof         (sof),          // output @posedge pclk
        .eof         (eof)           // output @posedge pclk
    );

    sens_sync #(
        .SENS_SYNC_ADDR       (SENS_SYNC_ADDR),
        .SENS_SYNC_MASK       (SENS_SYNC_MASK),
        .SENS_SYNC_MULT       (SENS_SYNC_MULT),
        .SENS_SYNC_LATE       (SENS_SYNC_LATE),
        .SENS_SYNC_FBITS      (SENS_SYNC_FBITS),
        .SENS_SYNC_LBITS      (SENS_SYNC_LBITS),
        .SENS_SYNC_LATE_DFLT  (SENS_SYNC_LATE_DFLT),
        .SENS_SYNC_MINBITS    (SENS_SYNC_MINBITS),
        .SENS_SYNC_MINPER     (SENS_SYNC_MINPER)
    ) sens_sync_i (
        .pclk         (pclk),          // input
        .mclk         (mclk),          // input
        .mrst         (mrst),          // input
        .prst         (prst),          // input
        .en           (en_pclk),       // input @pclk
        .sof_in       (sof),           // input
        .eof_in       (eof),           // input
        .hact         (hact),          // input
        .trigger_mode (trigger_mode),  // input
        .trig_in      (trig_in),       // input
        .trig         (trig),          // output      @pclk
        .sof_out_pclk (sof_out_sync),  // output reg  @pclk
        .sof_out      (sof_out_mclk),  // output      @mclk
        .sof_late     (sof_late_mclk), // output      @mclk
        .cmd_ad       (cmd_ad),        // input[7:0] 
        .cmd_stb      (cmd_stb)        // input
    );

    lens_flat393 #(
        .SENS_LENS_ADDR            (SENS_LENS_ADDR),
        .SENS_LENS_ADDR_MASK       (SENS_LENS_ADDR_MASK),
        .SENS_LENS_COEFF           (SENS_LENS_COEFF),
        .SENS_LENS_AX              (SENS_LENS_AX),
        .SENS_LENS_AX_MASK         (SENS_LENS_AX_MASK),
        .SENS_LENS_AY              (SENS_LENS_AY),
        .SENS_LENS_AY_MASK         (SENS_LENS_AY_MASK),
        .SENS_LENS_C               (SENS_LENS_C),
        .SENS_LENS_C_MASK          (SENS_LENS_C_MASK),
        .SENS_LENS_BX              (SENS_LENS_BX),
        .SENS_LENS_BX_MASK         (SENS_LENS_BX_MASK),
        .SENS_LENS_BY              (SENS_LENS_BY),
        .SENS_LENS_BY_MASK         (SENS_LENS_BY_MASK),
        .SENS_LENS_SCALES          (SENS_LENS_SCALES),
        .SENS_LENS_SCALES_MASK     (SENS_LENS_SCALES_MASK),
        .SENS_LENS_FAT0_IN         (SENS_LENS_FAT0_IN),
        .SENS_LENS_FAT0_IN_MASK    (SENS_LENS_FAT0_IN_MASK),
        .SENS_LENS_FAT0_OUT        (SENS_LENS_FAT0_OUT),
        .SENS_LENS_FAT0_OUT_MASK   (SENS_LENS_FAT0_OUT_MASK),
        .SENS_LENS_POST_SCALE      (SENS_LENS_POST_SCALE),
        .SENS_LENS_POST_SCALE_MASK (SENS_LENS_POST_SCALE_MASK),
        .SENS_NUM_SUBCHN           (SENS_NUM_SUBCHN),
        .SENS_LENS_F_WIDTH         (19),
        .SENS_LENS_F_SHIFT         (22),
        .SENS_LENS_B_SHIFT         (12),
        .SENS_LENS_A_WIDTH         (19),
        .SENS_LENS_B_WIDTH         (21)
    ) lens_flat393_i (
        .prst       (prst),          // input
        .pclk       (pclk),          // input
        .mrst       (mrst),          // input
        .mclk       (mclk),          // input
        .cmd_ad     (cmd_ad),        // input[7:0] 
        .cmd_stb    (cmd_stb),       // input
        .pxd_in     (lens_pxd_in),   // input[15:0] 
        .hact_in    (lens_hact_in),  // input
        .sof_in     (lens_sof_in),   // input
        .eof_in     (lens_eof_in),   // input
        .pxd_out    (gamma_pxd_in),  // output[15:0] reg 
        .hact_out   (gamma_hact_in), // output
        .sof_out    (gamma_sof_in),  // output
        .eof_out    (gamma_eof_in),  // output
        .bayer      (gamma_bayer), // input[1:0] // from gamma module
        .subchannel(), // output[1:0] - RFU 
        .last_in_sub() // output -    RFU
    );

    sens_gamma #(
        .SENS_NUM_SUBCHN       (SENS_NUM_SUBCHN),
        .SENS_GAMMA_BUFFER     (SENS_GAMMA_BUFFER),
        .SENS_GAMMA_ADDR       (SENS_GAMMA_ADDR),
        .SENS_GAMMA_ADDR_MASK  (SENS_GAMMA_ADDR_MASK),
        .SENS_GAMMA_CTRL       (SENS_GAMMA_CTRL),
        .SENS_GAMMA_ADDR_DATA  (SENS_GAMMA_ADDR_DATA),
        .SENS_GAMMA_HEIGHT01   (SENS_GAMMA_HEIGHT01),
        .SENS_GAMMA_HEIGHT2    (SENS_GAMMA_HEIGHT2),
        .SENS_GAMMA_MODE_WIDTH (SENS_GAMMA_MODE_WIDTH),
        .SENS_GAMMA_MODE_BAYER (SENS_GAMMA_MODE_BAYER),
        .SENS_GAMMA_MODE_PAGE  (SENS_GAMMA_MODE_PAGE),
        .SENS_GAMMA_MODE_EN    (SENS_GAMMA_MODE_EN),
        .SENS_GAMMA_MODE_REPET (SENS_GAMMA_MODE_REPET),
        .SENS_GAMMA_MODE_TRIG  (SENS_GAMMA_MODE_TRIG)
    ) sens_gamma_i (
//        .rst         (rst),            // input
        .pclk        (pclk),           // input
        .mrst        (mrst),          // input
        .prst        (prst),          // input
        .pxd_in      (gamma_pxd_in),   // input[15:0] 
        .hact_in     (gamma_hact_in),  // input
        .sof_in      (gamma_sof_in),   // input
        .eof_in      (gamma_eof_in),   // input
        .trig_in  (1'b0),              // input (use trig_soft)
        .pxd_out     (gamma_pxd_out),  // output[7:0] 
        .hact_out    (gamma_hact_out), // output
        .sof_out     (gamma_sof_out),  // output
        .eof_out     (gamma_eof_out),  // output
        .mclk        (mclk),           // input
        .cmd_ad      (cmd_ad),         // input[7:0] 
        .cmd_stb     (cmd_stb),        // input
        .bayer_out   (gamma_bayer)     // output [1:0]
    );

    // TODO: Use generate to generate 1-4 histogram modules
    generate
        if (HISTOGRAM_ADDR0 >=0)
            sens_histogram #(
                .HISTOGRAM_RAM_MODE     (HISTOGRAM_RAM_MODE),
                .HISTOGRAM_ADDR         (HISTOGRAM_ADDR0),
                .HISTOGRAM_ADDR_MASK    (HISTOGRAM_ADDR_MASK),
                .HISTOGRAM_LEFT_TOP     (HISTOGRAM_LEFT_TOP),
                .HISTOGRAM_WIDTH_HEIGHT (HISTOGRAM_WIDTH_HEIGHT)
`ifdef DEBUG_RING
                ,.DEBUG_CMD_LATENCY         (DEBUG_CMD_LATENCY) 
`endif        
            ) sens_histogram_i (
//                .rst        (rst),            // input
                .mrst       (mrst),           // input
                .prst       (prst),           // input
                .pclk       (pclk),           // input
                .pclk2x     (pclk2x),         // input
                .sof        (gamma_sof_out),  // input
                .eof        (gamma_eof_out),  // input
                .hact       (gamma_hact_out), // input
                .hist_di    (gamma_pxd_out),  // input[7:0] 
                .mclk       (mclk),           // input
                .hist_en    (hist_en[0]),     // input
                .hist_rst   (!hist_nrst[0]),     // input
                .hist_rq    (hist_rq[0]),     // output
                .hist_grant (hist_gr[0]),     // input
                .hist_do    (hist_do0),       // output[31:0] 
                .hist_dv    (hist_dv[0]),     // output
                .cmd_ad     (cmd_ad),         // input[7:0] 
                .cmd_stb    (cmd_stb),        // input
                .monochrome (HIST_MONOCHROME) // input
//                ,.debug_mclk(debug_hist_mclk[0])
`ifdef DEBUG_RING       
                ,.debug_do    (debug_ring[0]),         // output
                .debug_sl     (debug_sl),              // input
                .debug_di     (debug_ring[1])        // input
`endif         
                  
            );
        else
            sens_histogram_dummy sens_histogram_dummy_i (
                .hist_rq      (hist_rq[0]),         // output
                .hist_do      (hist_do0),           // output[31:0] 
                .hist_dv      (hist_dv[0])          // output
`ifdef DEBUG_RING       
                ,.debug_do    (debug_ring[0]),         // output
                .debug_di     (debug_ring[1])          // input
`endif         
            );
//`ifdef DEBUG_RING       
//            assign debug_ring[0] = debug_ring[1]; // just bypass
//            assign tmp1 = debug_ring[1]; // just bypass
//`endif
    endgenerate
    
    
    generate
        if (HISTOGRAM_ADDR1 >=0)
            sens_histogram #(
                .HISTOGRAM_RAM_MODE     (HISTOGRAM_RAM_MODE),
                .HISTOGRAM_ADDR         (HISTOGRAM_ADDR1),
                .HISTOGRAM_ADDR_MASK    (HISTOGRAM_ADDR_MASK),
                .HISTOGRAM_LEFT_TOP     (HISTOGRAM_LEFT_TOP),
                .HISTOGRAM_WIDTH_HEIGHT (HISTOGRAM_WIDTH_HEIGHT)
`ifdef DEBUG_RING
                ,.DEBUG_CMD_LATENCY         (DEBUG_CMD_LATENCY) 
`endif        
            ) sens_histogram_i (
//                .rst        (rst),            // input
                .mrst        (mrst),          // input
                .prst        (prst),          // input
                .pclk       (pclk),           // input
                .pclk2x     (pclk2x),         // input
                .sof        (gamma_sof_out),  // input
                .eof        (gamma_eof_out),  // input
                .hact       (gamma_hact_out), // input
                .hist_di    (gamma_pxd_out),  // input[7:0] 
                .mclk       (mclk),           // input
                .hist_en    (hist_en[1]),     // input
                .hist_rst   (!hist_nrst[1]),     // input
                .hist_rq    (hist_rq[1]),     // output
                .hist_grant (hist_gr[1]),     // input
                .hist_do    (hist_do1),       // output[31:0] 
                .hist_dv    (hist_dv[1]),     // output
                .cmd_ad     (cmd_ad),         // input[7:0] 
                .cmd_stb    (cmd_stb),        // input
                .monochrome (HIST_MONOCHROME) // input 
//                ,.debug_mclk(debug_hist_mclk[1])  
`ifdef DEBUG_RING       
                ,.debug_do    (debug_ring[1]),         // output
                .debug_sl     (debug_sl),              // input
                .debug_di     (debug_ring[2])        // input
`endif         
            );
        else
            sens_histogram_dummy sens_histogram_dummy_i (
                .hist_rq      (hist_rq[1]),   // output
                .hist_do      (hist_do1),     // output[31:0] 
                .hist_dv      (hist_dv[1])    // output
            `ifdef DEBUG_RING       
                ,.debug_do    (debug_ring[1]),         // output
                .debug_di     (debug_ring[2])          // input
`endif         
            );
//`ifdef DEBUG_RING       
//            assign debug_ring[1] = debug_ring[2]; // just bypass
//`endif
            
    endgenerate
    generate
        if (HISTOGRAM_ADDR2 >=0)
            sens_histogram #(
                .HISTOGRAM_RAM_MODE     (HISTOGRAM_RAM_MODE),
                .HISTOGRAM_ADDR         (HISTOGRAM_ADDR2),
                .HISTOGRAM_ADDR_MASK    (HISTOGRAM_ADDR_MASK),
                .HISTOGRAM_LEFT_TOP     (HISTOGRAM_LEFT_TOP),
                .HISTOGRAM_WIDTH_HEIGHT (HISTOGRAM_WIDTH_HEIGHT)
`ifdef DEBUG_RING
                ,.DEBUG_CMD_LATENCY         (DEBUG_CMD_LATENCY) 
`endif        
            ) sens_histogram_i (
//                .rst        (rst),            // input
                .mrst        (mrst),          // input
                .prst        (prst),          // input
                .pclk       (pclk),           // input
                .pclk2x     (pclk2x),         // input
                .sof        (gamma_sof_out),  // input
                .eof        (gamma_eof_out),  // input
                .hact       (gamma_hact_out), // input
                .hist_di    (gamma_pxd_out),  // input[7:0] 
                .mclk       (mclk),           // input
                .hist_en    (hist_en[2]),     // input
                .hist_rst   (!hist_nrst[2]),     // input
                .hist_rq    (hist_rq[2]),     // output
                .hist_grant (hist_gr[2]),     // input
                .hist_do    (hist_do2),       // output[31:0] 
                .hist_dv    (hist_dv[2]),     // output
                .cmd_ad     (cmd_ad),         // input[7:0] 
                .cmd_stb    (cmd_stb),        // input
                .monochrome (HIST_MONOCHROME) // input  
//                ,.debug_mclk(debug_hist_mclk[2])  
`ifdef DEBUG_RING       
                ,.debug_do    (debug_ring[2]),         // output
                .debug_sl     (debug_sl),              // input
                .debug_di     (debug_ring[3])        // input
`endif         
            );
        else
            sens_histogram_dummy sens_histogram_dummy_i (
                .hist_rq(hist_rq[2]),        // output
                .hist_do(hist_do2),          // output[31:0] 
                .hist_dv(hist_dv[2])         // output
`ifdef DEBUG_RING       
                ,.debug_do    (debug_ring[2]),         // output
                .debug_di     (debug_ring[3])          // input
`endif         
            );
//`ifdef DEBUG_RING       
//            assign debug_ring[2] = debug_ring[3]; // just bypass
//`endif
    endgenerate
    generate
        if (HISTOGRAM_ADDR3 >=0)
            sens_histogram #(
                .HISTOGRAM_RAM_MODE     (HISTOGRAM_RAM_MODE),
                .HISTOGRAM_ADDR         (HISTOGRAM_ADDR3),
                .HISTOGRAM_ADDR_MASK    (HISTOGRAM_ADDR_MASK),
                .HISTOGRAM_LEFT_TOP     (HISTOGRAM_LEFT_TOP),
                .HISTOGRAM_WIDTH_HEIGHT (HISTOGRAM_WIDTH_HEIGHT)
`ifdef DEBUG_RING
                ,.DEBUG_CMD_LATENCY         (DEBUG_CMD_LATENCY) 
`endif        
            ) sens_histogram_i (
//                .rst        (rst),            // input
                .mrst        (mrst),          // input
                .prst        (prst),          // input
                .pclk       (pclk),           // input
                .pclk2x     (pclk2x),         // input
                .sof        (gamma_sof_out),  // input
                .eof        (gamma_eof_out),  // input
                .hact       (gamma_hact_out), // input
                .hist_di    (gamma_pxd_out),  // input[7:0] 
                .mclk       (mclk),           // input
                .hist_en    (hist_en[3]),     // input
                .hist_rst   (!hist_nrst[3]),  // input
                .hist_rq    (hist_rq[3]),     // output
                .hist_grant (hist_gr[3]),     // input
                .hist_do    (hist_do3),       // output[31:0] 
                .hist_dv    (hist_dv[3]),     // output
                .cmd_ad     (cmd_ad),         // input[7:0] 
                .cmd_stb    (cmd_stb),        // input
                .monochrome (HIST_MONOCHROME) // input  
//                ,.debug_mclk(debug_hist_mclk[3])  
`ifdef DEBUG_RING       
                ,.debug_do    (debug_ring[3]),         // output
                .debug_sl     (debug_sl),              // input
                .debug_di     (debug_ring[4])        // input
`endif         
            );
        else
            sens_histogram_dummy sens_histogram_dummy_i (
                .hist_rq(hist_rq[3]),  // output
                .hist_do(hist_do3),    // output[31:0] 
                .hist_dv(hist_dv[3])   // output
`ifdef DEBUG_RING       
                ,.debug_do    (debug_ring[3]),         // output
                .debug_di     (debug_ring[4])          // input
`endif         
            );
//`ifdef DEBUG_RING       
//            assign debug_ring[3] = debug_ring[4]; // just bypass
//`endif
    endgenerate
    
    sens_histogram_mux sens_histogram_mux_i (
        .mclk   (mclk),          // input
        .en     (|hist_nrst),    // input
        .rq0    (hist_rq[0]),    // input
        .grant0 (hist_gr[0]),    // output
        .dav0   (hist_dv[0]),    // input
        .din0   (hist_do0),      // input[31:0] 
        .rq1    (hist_rq[1]),    // input
        .grant1 (hist_gr[1]),    // output
        .dav1   (hist_dv[1]),    // input
        .din1   (hist_do1),      // input[31:0] 
        .rq2    (hist_rq[2]),    // input
        .grant2 (hist_gr[2]),    // output
        .dav2   (hist_dv[2]),    // input
        .din2   (hist_do2),      // input[31:0] 
        .rq3    (hist_rq[3]),    // input
        .grant3 (hist_gr[3]),    // output
        .dav3   (hist_dv[3]),    // input
        .din3   (hist_do3),      // input[31:0] 
        .rq     (hist_request),  // output
        .grant  (hist_grant),    // input
        .chn    (hist_chn),      // output[1:0]
        .dv     (hist_dvalid),   // output
        .dout   (hist_data)      // output[31:0] 
    );


endmodule

