/*******************************************************************************
 * Module: sensors393
 * Date:2015-07-12  
 * Author: Andrey Filippov     
 * Description: 4-channel sensor subsystem
 *  Uniform, assuming the same sensors/multiplexers, common pixel clock
 *
 * Copyright (c) 2015 Elphel, Inc .
 * sensors393.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  sensors393.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  sensors393 #(
    // parameters, individual to sensor channels and those likely to be modified
    parameter SENSOR_GROUP_ADDR =         'h400, // sensor registers base address
    parameter SENSOR_BASE_INC =           'h040, // increment for sesor channel
    
    parameter HIST_SAXI_ADDR_REL =         'h100, // histograms control addresses (16 locations) relative to SENSOR_GROUP_ADDR
    parameter HIST_SAXI_MODE_ADDR_REL =    'h110, // histograms mode address (1 locatios) relative to SENSOR_GROUP_ADDR
    
    
    parameter SENSI2C_STATUS_REG_BASE =   'h30,  // 4 locations" x30, x32, x34, x36
    parameter SENSI2C_STATUS_REG_INC =    2,     // increment to the next sensor
    parameter SENSI2C_STATUS_REG_REL =    0,     // 4 locations" 'h30, 'h32, 'h34, 'h36
    parameter SENSIO_STATUS_REG_REL =     1,     // 4 locations" 'h31, 'h33, 'h35, 'h37
    parameter SENSOR_NUM_HISTOGRAM=       3,     // number of histogram channels
    parameter HISTOGRAM_RAM_MODE =        "NOBUF", // valid: "NOBUF" (32-bits, no buffering), "BUF18", "BUF32"
    parameter SENS_GAMMA_NUM_CHN =        3,     // number of subchannels for his sensor ports (1..4)
    parameter SENS_GAMMA_BUFFER =         0,     // 1 - use "shadow" table for clean switching, 0 - single table per channel
    
    // parameters defining address map
    parameter SENSOR_CTRL_RADDR =         0, // relative to SENSOR_GROUP_ADDR 
    parameter SENSOR_CTRL_ADDR_MASK =    'h7ff, //
        // bits of the SENSOR mode register
        parameter SENSOR_MODE_WIDTH =     9,
        parameter SENSOR_HIST_EN_BIT =    0, // 0..3 1 - enable histogram modules, disable after processing the started frame
        parameter SENSOR_HIST_NRST_BIT =  4, // 0 - immediately reset all histogram modules 
        parameter SENSOR_16BIT_BIT =      8, // 0 - 8 bpp mode, 1 - 16 bpp (bypass gamma). Gamma-processed data is still used for histograms
    
    parameter SENSI2C_CTRL_RADDR =        2, // 302..'h303
    parameter SENSI2C_CTRL_MASK =     'h7fe,
      // sensor_i2c_io relative control register addresses
      parameter SENSI2C_CTRL =          'h0,
      parameter SENSI2C_STATUS =        'h1,
    
    parameter SENS_SYNC_RADDR  =        'h4,
    parameter SENS_SYNC_MASK  =         'h7fc,
      // 2 locations reserved for control/status (if they will be needed)
      parameter SENS_SYNC_MULT  =       'h2,   // relative register address to write number of frames to combine in one (minus 1, '0' - each farme)
      parameter SENS_SYNC_LATE  =       'h3,    // number of lines to delay late frame sync
    
    
    
    parameter SENS_GAMMA_RADDR =        'h38, // 'h38..'h3b was 4,
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
    
    parameter SENSIO_RADDR =          8, //'h308  .. 'h30c
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
    // sensor_i2c_io command/data write registers s (relative to SENSOR_GROUP_ADDR)
    parameter SENSI2C_ABS_RADDR =       'h10, // 'h310..'h31f
    parameter SENSI2C_REL_RADDR =       'h20, // 'h320..'h32f
    parameter SENSI2C_ADDR_MASK =       'h7f0, // both for SENSI2C_ABS_ADDR and SENSI2C_REL_ADDR

    // sens_hist registers (relative to SENSOR_GROUP_ADDR)
    parameter HISTOGRAM_RADDR0 =        'h30, //
    parameter HISTOGRAM_RADDR1 =        'h32, //
    parameter HISTOGRAM_RADDR2 =        'h34, //
    parameter HISTOGRAM_RADDR3 =        'h36, //
    parameter HISTOGRAM_ADDR_MASK =     'h7fe, // for each channel
      // sens_hist registers
      parameter HISTOGRAM_LEFT_TOP =     'h0,
      parameter HISTOGRAM_WIDTH_HEIGHT = 'h1, // 1.. 2^16, 0 - use HACT
    
    //sensor_i2c_io other parameters
    parameter integer SENSI2C_DRIVE=     12,
    parameter SENSI2C_IBUF_LOW_PWR=      "TRUE",
    parameter SENSI2C_IOSTANDARD =       "DEFAULT",
    parameter SENSI2C_SLEW =             "SLOW",
    
    //sensor_fifo parameters
    parameter SENSOR_DATA_WIDTH =        12,
    parameter SENSOR_FIFO_2DEPTH =       4,
    parameter SENSOR_FIFO_DELAY =        7,
    // other parameters for histogram_saxi module
    parameter HIST_SAXI_ADDR_MASK =      'h7f0,
      parameter HIST_SAXI_MODE_WIDTH =   8,
      parameter HIST_SAXI_EN =           0,
      parameter HIST_SAXI_NRESET =       1,
      parameter HIST_CONFIRM_WRITE =     2, // wait write confirmation for each block
      parameter HIST_SAXI_AWCACHE =      4'h3, //..7 cache mode (4 bits, default 4'h3)
      
    parameter HIST_SAXI_MODE_ADDR_MASK = 'h7ff,
    parameter NUM_FRAME_BITS =           4, // number of bits use for frame number 
    
    // Other parameters
    parameter SENS_SYNC_FBITS =          16,    // number of bits in a frame counter for linescan mode
    parameter SENS_SYNC_LBITS =          16,    // number of bits in a line counter for sof_late output (limited by eof) 
    parameter SENS_SYNC_LATE_DFLT =      15,    // number of lines to delay late frame sync
    parameter SENS_SYNC_MINBITS =        8,    // number of bits to enforce minimal frame period 
    parameter SENS_SYNC_MINPER =         130,    // minimal frame period (in pclk/mclk?) 
    
    
    // sens_parallel12 other parameters
    
//    parameter IODELAY_GRP ="IODELAY_SENSOR", // may need different for different channels?
    parameter integer IDELAY_VALUE =     0,
    parameter integer PXD_DRIVE =        12,
    parameter PXD_IBUF_LOW_PWR =         "TRUE",
    parameter PXD_IOSTANDARD =           "DEFAULT",
    parameter PXD_SLEW =                 "SLOW",
    parameter real SENS_REFCLK_FREQUENCY =    300.0,
    parameter SENS_HIGH_PERFORMANCE_MODE =    "FALSE",
    
    parameter SENS_PHASE_WIDTH=               8,      // number of bits for te phase counter (depends on divisors)
    parameter SENS_PCLK_PERIOD =              10.000,  // input period in ns, 0..100.000 - MANDATORY, resolution down to 1 ps
    parameter SENS_BANDWIDTH =                "OPTIMIZED",  //"OPTIMIZED", "HIGH","LOW"

    parameter CLKFBOUT_MULT_SENSOR =     8,  // 100 MHz --> 800 MHz
    parameter CLKFBOUT_PHASE_SENSOR =    0.000,  // CLOCK FEEDBACK phase in degrees (3 significant digits, -360.000...+360.000)
    parameter IPCLK_PHASE =              0.000,
    parameter IPCLK2X_PHASE =            0.000,
    

    parameter SENS_DIVCLK_DIVIDE =       1,            // Integer 1..106. Divides all outputs with respect to CLKIN
    parameter SENS_REF_JITTER1   =       0.010,        // Expectet jitter on CLKIN1 (0.000..0.999)
    parameter SENS_REF_JITTER2   =       0.010,
    parameter SENS_SS_EN         =       "FALSE",      // Enables Spread Spectrum mode
    parameter SENS_SS_MODE       =       "CENTER_HIGH",//"CENTER_HIGH","CENTER_LOW","DOWN_HIGH","DOWN_LOW"
    parameter SENS_SS_MOD_PERIOD =       10000        // integer 4000-40000 - SS modulation period in ns
    
) (
    input         rst,
// will generate it here
    input         ref_clk, // IODELAY calibration 
    input         dly_rst,       
    input         pclk,   // global clock input, pixel rate (96MHz for MT9P006)
    input         pclk2x, // global clock input, double pixel rate (192MHz for MT9P006)
    
    // programming interface
    input         mclk,     // global clock, half DDR3 clock, synchronizes all I/O through the command port
    input   [7:0] cmd_ad_in,      // byte-serial command address/data (up to 6 bytes: AL-AH-D0-D1-D2-D3 
    input         cmd_stb_in,     // strobe (with first byte) for the command a/d
    output  [7:0] status_ad,   // status address/data - up to 5 bytes: A - {seq,status[1:0]} - status[2:9] - status[10:17] - status[18:25]
    output        status_rq,   // input request to send status downstream
    input         status_start, // Acknowledge of the first status packet byte (address)
    
    // I/O pads, pin names match circuit diagram (each sensor)
    inout   [7:0] sns1_dp,
    inout   [7:0] sns1_dn,
    inout         sns1_clkp,
    inout         sns1_clkn,
    inout         sns1_scl,
    inout         sns1_sda,
    inout         sns1_ctl,
    inout         sns1_pg,
    
    inout   [7:0] sns2_dp,   //SuppressThisWarning VEditor : VDT bug? - assigned used in generate block only
    inout   [7:0] sns2_dn,   //SuppressThisWarning VEditor : VDT bug? - assigned used in generate block only
    inout         sns2_clkp, //SuppressThisWarning VEditor : VDT bug? - assigned used in generate block only
    inout         sns2_clkn, //SuppressThisWarning VEditor : VDT bug? - assigned used in generate block only
    inout         sns2_scl,  //SuppressThisWarning VEditor : VDT bug? - assigned used in generate block only
    inout         sns2_sda,  //SuppressThisWarning VEditor : VDT bug? - assigned used in generate block only
    inout         sns2_ctl,  //SuppressThisWarning VEditor : VDT bug? - assigned used in generate block only
    inout         sns2_pg,   //SuppressThisWarning VEditor : VDT bug? - assigned used in generate block only
    
    inout   [7:0] sns3_dp,   //SuppressThisWarning VEditor : VDT bug? - assigned used in generate block only
    inout   [7:0] sns3_dn,   //SuppressThisWarning VEditor : VDT bug? - assigned used in generate block only
    inout         sns3_clkp, //SuppressThisWarning VEditor : VDT bug? - assigned used in generate block only
    inout         sns3_clkn, //SuppressThisWarning VEditor : VDT bug? - assigned used in generate block only
    inout         sns3_scl,  //SuppressThisWarning VEditor : VDT bug? - assigned used in generate block only
    inout         sns3_sda,  //SuppressThisWarning VEditor : VDT bug? - assigned used in generate block only
    inout         sns3_ctl,  //SuppressThisWarning VEditor : VDT bug? - assigned used in generate block only
    inout         sns3_pg,   //SuppressThisWarning VEditor : VDT bug? - assigned used in generate block only
    
    inout   [7:0] sns4_dp,   //SuppressThisWarning VEditor : VDT bug? - assigned used in generate block only
    inout   [7:0] sns4_dn,   //SuppressThisWarning VEditor : VDT bug? - assigned used in generate block only
    inout         sns4_clkp, //SuppressThisWarning VEditor : VDT bug? - assigned used in generate block only
    inout         sns4_clkn, //SuppressThisWarning VEditor : VDT bug? - assigned used in generate block only
    inout         sns4_scl,  //SuppressThisWarning VEditor : VDT bug? - assigned used in generate block only
    inout         sns4_sda,  //SuppressThisWarning VEditor : VDT bug? - assigned used in generate block only
    inout         sns4_ctl,  //SuppressThisWarning VEditor : VDT bug? - assigned used in generate block only
    inout         sns4_pg,   //SuppressThisWarning VEditor : VDT bug? - assigned used in generate block only
    
    // Memory interface
    input         rpage_set0,    // set internal read page to rpage_in (reset pointers)
    input         rpage_next0,   // advance to next page (and reset lower bits to 0)
    input         buf_rd0,       // read buffer to memory, increment read address (regester enable will be delayed)
    output [63:0] buf_dout0,     // data out 
    
    input         rpage_set1,    // set internal read page to rpage_in (reset pointers)
    input         rpage_next1,   // advance to next page (and reset lower bits to 0)
    input         buf_rd1,       // read buffer to memory, increment read address (regester enable will be delayed)
    output [63:0] buf_dout1,     // data out
    
    input         rpage_set2,    // set internal read page to rpage_in (reset pointers)
    input         rpage_next2,   // advance to next page (and reset lower bits to 0)
    input         buf_rd2,       // read buffer to memory, increment read address (regester enable will be delayed)
    output [63:0] buf_dout2,     // data out
    
    input         rpage_set3,    // set internal read page to rpage_in (reset pointers)
    input         rpage_next3,   // advance to next page (and reset lower bits to 0)
    input         buf_rd3,       // read buffer to memory, increment read address (regester enable will be delayed)
    output [63:0] buf_dout3,     // data out
    
    // Lower bits of frame numbers to use with the histograms, get from the sequencers
    // trigger inputs
    input         trigger_mode, // common to all sensors - running in triggered mode (0 - free running mode)
    input   [3:0] trig_in,      // per-sensor trigger input
    output  [3:0] sof_out_pclk, // @ pclk start of frame 
    output  [3:0] eof_out_pclk, // @ pclk end of frame
    output  [3:0] sof_out_mclk, // @ mclk start of frame - use to run sequencer, so register writes should be before compressor start
    output  [3:0] sof_late_mclk,// @ mclk start of frame, delayed (use to start compressor and interrupts)
    
    
    input  [NUM_FRAME_BITS-1:0] frame_num0,
    input  [NUM_FRAME_BITS-1:0] frame_num1, 
    input  [NUM_FRAME_BITS-1:0] frame_num2, 
    input  [NUM_FRAME_BITS-1:0] frame_num3, 
    
    // S_AXI interface write only (histograms out)
    // write address
    input                      aclk,                   // global clock for S_AXI0 (150 MHz)    
    output              [31:0] saxi_awaddr,            // AXI PS Slave GP0 AWADDR[31:0], input
    output                     saxi_awvalid,           // AXI PS Slave GP0 AWVALID, input
    input                      saxi_awready,           // AXI PS Slave GP0 AWREADY, output
    output               [5:0] saxi_awid,              // AXI PS Slave GP0 AWID[5:0], input
    output               [1:0] saxi_awlock,            // AXI PS Slave GP0 AWLOCK[1:0], input
    output              [ 3:0] saxi_awcache,           // AXI PS Slave GP0 AWCACHE[3:0], input
    output              [ 2:0] saxi_awprot,            // AXI PS Slave GP0 AWPROT[2:0], input
    output              [ 3:0] saxi_awlen,             // AXI PS Slave GP0 AWLEN[3:0], input
    output              [ 1:0] saxi_awsize,            // AXI PS Slave GP0 AWSIZE[1:0], input
    output              [ 1:0] saxi_awburst,           // AXI PS Slave GP0 AWBURST[1:0], input
    output              [ 3:0] saxi_awqos,             // AXI PS Slave GP0 AWQOS[3:0], input
    // write data
    output              [31:0] saxi_wdata,             // AXI PS Slave GP0 WDATA[31:0], input
    output                     saxi_wvalid,            // AXI PS Slave GP0 WVALID, input
    input                      saxi_wready,            // AXI PS Slave GP0 WREADY, output
    output              [ 5:0] saxi_wid,               // AXI PS Slave GP0 WID[5:0], input
    output                     saxi_wlast,             // AXI PS Slave GP0 WLAST, input
    output              [ 3:0] saxi_wstrb,             // AXI PS Slave GP0 WSTRB[3:0], input
    // write response
    input                      saxi_bvalid,            // AXI PS Slave GP0 BVALID, output
    output                     saxi_bready,            // AXI PS Slave GP0 BREADY, input
    input               [ 5:0] saxi_bid,               // AXI PS Slave GP0 BID[5:0], output
    input               [ 1:0] saxi_bresp              // AXI PS Slave GP0 BRESP[1:0], output
    
);


    wire [3:0] rpage_set =  {rpage_set3,  rpage_set2,  rpage_set1,  rpage_set0};   // set internal read page to rpage_in (reset pointers)
    wire [3:0] rpage_next = {rpage_next3, rpage_next2, rpage_next1, rpage_next0};   // advance to next page (and reset lower bits to 0)
    wire [3:0] buf_rd =     {buf_rd3,     buf_rd2,     buf_rd1,     buf_rd0};       // read buffer to memory, increment read address (regester enable will be delayed)


    reg              [7:0] cmd_ad;    
    reg                    cmd_stb;
    wire            [31:0] status_ad_chn;
    wire             [3:0] status_rq_chn;
    wire             [3:0] status_start_chn;

    wire            [63:0] px_data;
    wire             [3:0] px_valid;
    wire             [3:0] last_in_line;
    wire             [3:0] hist_request;
    wire             [3:0] hist_grant;
    wire             [7:0] hist_chn; 
    wire             [3:0] hist_dvalid;
    wire           [127:0] hist_data; 
    wire           [255:0] buf_dout_all;
    
//    wire             [3:0] sns_pg; // bidir!
//my_alias    
//    my_alias #(.WIDTH(4)) my_alias_i (sns_pg, {sns4_pg, sns3_pg, sns2_pg, sns1_pg});
    
    assign  {buf_dout3, buf_dout2, buf_dout1, buf_dout0} = buf_dout_all;
    
    always @ (posedge mclk) begin
        cmd_ad <= cmd_ad_in;
        cmd_stb <= cmd_stb_in;
    end    

    generate
        genvar i;
        for (i=0; i < 4; i=i+1) begin: sensor_channel_block
            sensor_channel #(
                .SENSOR_NUMBER                 (i),
                .SENSOR_GROUP_ADDR             (SENSOR_GROUP_ADDR),
                .SENSOR_BASE_INC               (SENSOR_BASE_INC),
                .SENSI2C_STATUS_REG_BASE       (SENSI2C_STATUS_REG_BASE),
                .SENSI2C_STATUS_REG_INC        (SENSI2C_STATUS_REG_INC),
                .SENSI2C_STATUS_REG_REL        (SENSI2C_STATUS_REG_REL),
                .SENSIO_STATUS_REG_REL         (SENSIO_STATUS_REG_REL),
                .SENS_SYNC_RADDR               (SENS_SYNC_RADDR),
                .SENS_SYNC_MASK                (SENS_SYNC_MASK),
                .SENS_SYNC_MULT                (SENS_SYNC_MULT),
                .SENS_SYNC_LATE                (SENS_SYNC_LATE),
                .SENS_SYNC_FBITS               (SENS_SYNC_FBITS),
                .SENS_SYNC_LBITS               (SENS_SYNC_LBITS),
                .SENS_SYNC_LATE_DFLT           (SENS_SYNC_LATE_DFLT),
                .SENS_SYNC_MINBITS             (SENS_SYNC_MINBITS),
                .SENS_SYNC_MINPER              (SENS_SYNC_MINPER),
                .SENSOR_NUM_HISTOGRAM          (SENSOR_NUM_HISTOGRAM),
                .HISTOGRAM_RAM_MODE            (HISTOGRAM_RAM_MODE),
                .SENS_GAMMA_NUM_CHN            (SENS_GAMMA_NUM_CHN),
                .SENS_GAMMA_BUFFER             (SENS_GAMMA_BUFFER),
                .SENSOR_CTRL_RADDR             (SENSOR_CTRL_RADDR),
                .SENSOR_CTRL_ADDR_MASK         (SENSOR_CTRL_ADDR_MASK),
                .SENSOR_MODE_WIDTH             (SENSOR_MODE_WIDTH),
                .SENSOR_HIST_EN_BIT            (SENSOR_HIST_EN_BIT),
                .SENSOR_HIST_NRST_BIT          (SENSOR_HIST_NRST_BIT),
                .SENSOR_16BIT_BIT              (SENSOR_16BIT_BIT),
                .SENSI2C_CTRL_RADDR            (SENSI2C_CTRL_RADDR),
                .SENSI2C_CTRL_MASK             (SENSI2C_CTRL_MASK),
                .SENSI2C_CTRL                  (SENSI2C_CTRL),
                .SENSI2C_STATUS                (SENSI2C_STATUS),
                .SENS_GAMMA_RADDR              (SENS_GAMMA_RADDR),
                .SENS_GAMMA_ADDR_MASK          (SENS_GAMMA_ADDR_MASK),
                .SENS_GAMMA_CTRL               (SENS_GAMMA_CTRL),
                .SENS_GAMMA_ADDR_DATA          (SENS_GAMMA_ADDR_DATA),
                .SENS_GAMMA_HEIGHT01           (SENS_GAMMA_HEIGHT01),
                .SENS_GAMMA_HEIGHT2            (SENS_GAMMA_HEIGHT2),
                .SENS_GAMMA_MODE_WIDTH         (SENS_GAMMA_MODE_WIDTH),
                .SENS_GAMMA_MODE_BAYER         (SENS_GAMMA_MODE_BAYER),
                .SENS_GAMMA_MODE_PAGE          (SENS_GAMMA_MODE_PAGE),
                .SENS_GAMMA_MODE_EN            (SENS_GAMMA_MODE_EN),
                .SENS_GAMMA_MODE_REPET         (SENS_GAMMA_MODE_REPET),
                .SENS_GAMMA_MODE_TRIG          (SENS_GAMMA_MODE_TRIG),
                .SENSIO_RADDR                  (SENSIO_RADDR),
                .SENSIO_ADDR_MASK              (SENSIO_ADDR_MASK),
                .SENSIO_CTRL                   (SENSIO_CTRL),
                .SENS_CTRL_MRST                (SENS_CTRL_MRST),
                .SENS_CTRL_ARST                (SENS_CTRL_ARST),
                .SENS_CTRL_ARO                 (SENS_CTRL_ARO),
                .SENS_CTRL_RST_MMCM            (SENS_CTRL_RST_MMCM),
                .SENS_CTRL_EXT_CLK             (SENS_CTRL_EXT_CLK),
                .SENS_CTRL_LD_DLY              (SENS_CTRL_LD_DLY),
                .SENS_CTRL_QUADRANTS           (SENS_CTRL_QUADRANTS),
                .SENSIO_STATUS                 (SENSIO_STATUS),
                .SENSIO_JTAG                   (SENSIO_JTAG),
                .SENS_JTAG_PGMEN               (SENS_JTAG_PGMEN),
                .SENS_JTAG_PROG                (SENS_JTAG_PROG),
                .SENS_JTAG_TCK                 (SENS_JTAG_TCK),
                .SENS_JTAG_TMS                 (SENS_JTAG_TMS),
                .SENS_JTAG_TDI                 (SENS_JTAG_TDI),
                .SENSIO_WIDTH                  (SENSIO_WIDTH),
                .SENSIO_DELAYS                 (SENSIO_DELAYS),
                .SENSI2C_ABS_RADDR             (SENSI2C_ABS_RADDR),
                .SENSI2C_REL_RADDR             (SENSI2C_REL_RADDR),
                .SENSI2C_ADDR_MASK             (SENSI2C_ADDR_MASK),
                .HISTOGRAM_RADDR0              (HISTOGRAM_RADDR0),
                .HISTOGRAM_RADDR1              (HISTOGRAM_RADDR1),
                .HISTOGRAM_RADDR2              (HISTOGRAM_RADDR2),
                .HISTOGRAM_RADDR3              (HISTOGRAM_RADDR3),
                .HISTOGRAM_ADDR_MASK           (HISTOGRAM_ADDR_MASK),
                .HISTOGRAM_LEFT_TOP            (HISTOGRAM_LEFT_TOP),
                .HISTOGRAM_WIDTH_HEIGHT        (HISTOGRAM_WIDTH_HEIGHT),
                
                .SENSI2C_DRIVE                 (SENSI2C_DRIVE),
                .SENSI2C_IBUF_LOW_PWR          (SENSI2C_IBUF_LOW_PWR),
                .SENSI2C_IOSTANDARD            (SENSI2C_IOSTANDARD),
                .SENSI2C_SLEW                  (SENSI2C_SLEW),
                .SENSOR_DATA_WIDTH             (SENSOR_DATA_WIDTH),
                .SENSOR_FIFO_2DEPTH            (SENSOR_FIFO_2DEPTH),
                .SENSOR_FIFO_DELAY             (SENSOR_FIFO_DELAY),
                .IODELAY_GRP                   ((i & 2)?"IODELAY_SENSOR_34":"IODELAY_SENSOR_12"),
                .IDELAY_VALUE                  (IDELAY_VALUE),
                .PXD_DRIVE                     (PXD_DRIVE),
                .PXD_IBUF_LOW_PWR              (PXD_IBUF_LOW_PWR),
                .PXD_IOSTANDARD                (PXD_IOSTANDARD),
                .PXD_SLEW                      (PXD_SLEW),
                .SENS_REFCLK_FREQUENCY         (SENS_REFCLK_FREQUENCY),
                .SENS_HIGH_PERFORMANCE_MODE    (SENS_HIGH_PERFORMANCE_MODE),
                .SENS_PHASE_WIDTH              (SENS_PHASE_WIDTH),
                .SENS_PCLK_PERIOD              (SENS_PCLK_PERIOD),
                .SENS_BANDWIDTH                (SENS_BANDWIDTH),
                .CLKFBOUT_MULT_SENSOR          (CLKFBOUT_MULT_SENSOR),
                .CLKFBOUT_PHASE_SENSOR         (CLKFBOUT_PHASE_SENSOR),
                .IPCLK_PHASE                   (IPCLK_PHASE),
                .IPCLK2X_PHASE                 (IPCLK2X_PHASE),
                .SENS_DIVCLK_DIVIDE            (SENS_DIVCLK_DIVIDE),
                .SENS_REF_JITTER1              (SENS_REF_JITTER1),
                .SENS_REF_JITTER2              (SENS_REF_JITTER2),
                .SENS_SS_EN                    (SENS_SS_EN),
                .SENS_SS_MODE                  (SENS_SS_MODE),
                .SENS_SS_MOD_PERIOD            (SENS_SS_MOD_PERIOD)
            ) sensor_channel_i (
                .rst          (rst),       // input
                .pclk         (pclk),      // input
                .pclk2x       (pclk2x),    // input
                .sns_dp       ((i & 2) ? ((i & 1) ? sns4_dp:   sns3_dp):  ((i & 1) ? sns2_dp:   sns1_dp)),   // inout[7:0] 
                .sns_dn       ((i & 2) ? ((i & 1) ? sns4_dn:   sns3_dn):  ((i & 1) ? sns2_dn:   sns1_dn)),   // inout[7:0] 
                .sns_clkp     ((i & 2) ? ((i & 1) ? sns4_clkp: sns3_clkp):((i & 1) ? sns2_clkp: sns1_clkp)), // inout
                .sns_clkn     ((i & 2) ? ((i & 1) ? sns4_clkn: sns3_clkn):((i & 1) ? sns2_clkn: sns1_clkn)), // inout
                .sns_scl      ((i & 2) ? ((i & 1) ? sns4_scl:  sns3_scl): ((i & 1) ? sns2_scl:  sns1_scl)),  // inout
                .sns_sda      ((i & 2) ? ((i & 1) ? sns4_sda:  sns3_sda): ((i & 1) ? sns2_sda:  sns1_sda)),  // inout
                .sns_ctl      ((i & 2) ? ((i & 1) ? sns4_ctl:  sns3_ctl): ((i & 1) ? sns2_ctl:  sns1_ctl)),  // inout
                .sns_pg       ((i & 2) ? ((i & 1) ? sns4_pg:   sns3_pg):  ((i & 1) ? sns2_pg:   sns1_pg)),   // inout
//                .sns_pg       (sns_pg[i]),   // inout
                .mclk         (mclk),                  // input
                .cmd_ad_in    (cmd_ad),                // input[7:0] 
                .cmd_stb_in   (cmd_stb),               // input
                .status_ad    (status_ad_chn[i * 8 +: 8]), // output[7:0] 
                .status_rq    (status_rq_chn[i]),      // output
                .status_start (status_start_chn[i]),   // input
                .trigger_mode (trigger_mode),          // input
                .trig_in      (trig_in[i]),            // input
                
                .dout         (px_data[16 * i +: 16]), // output[15:0] 
                .dout_valid   (px_valid[i]),           // output
                .last_in_line (last_in_line[i]),       // output
                .sof_out      (sof_out_pclk[i]),       // output
                .eof_out      (eof_out_pclk[i]),       // output
                .sof_out_mclk (sof_out_mclk[i]),       // output
                .sof_late_mclk(sof_late_mclk[i]),      // output
                .hist_request (hist_request[i]),       // output
                .hist_grant   (hist_grant[i]),         // input
                .hist_chn     (hist_chn[2 * i +: 2]),  // output[1:0] 
                .hist_dvalid  (hist_dvalid[i]),        // output
                .hist_data    (hist_data[i * 32 +: 32])// output[31:0] 
            );

            sensor_membuf #(
                .WADDR_WIDTH(9)
            ) sensor_membuf_i (
                .pclk         (pclk),                    // input
                .px_data      (px_data[16 * i +: 16]),   // input[15:0] 
                .px_valid     (px_valid[i]),             // input
                .last_in_line (last_in_line[i]),         // input
                .mclk         (mclk),                    // input
                .rpage_set    (rpage_set[i]),            // input
                .rpage_next   (rpage_next[i]),           // input
                .buf_rd       (buf_rd[i]),               // input
                .buf_dout     (buf_dout_all[64*i +: 64]) // output[63:0] 
            );
        end
    endgenerate

    histogram_saxi #(
        .HIST_SAXI_ADDR           (SENSOR_GROUP_ADDR + HIST_SAXI_ADDR_REL),
        .HIST_SAXI_ADDR_MASK      (HIST_SAXI_ADDR_MASK),
        .HIST_SAXI_MODE_ADDR      (SENSOR_GROUP_ADDR + HIST_SAXI_MODE_ADDR_REL),
        .HIST_SAXI_MODE_WIDTH     (HIST_SAXI_MODE_WIDTH),
        .HIST_SAXI_EN             (HIST_SAXI_EN),
        .HIST_SAXI_NRESET         (HIST_SAXI_NRESET),
        .HIST_CONFIRM_WRITE       (HIST_CONFIRM_WRITE),
        .HIST_SAXI_AWCACHE        (HIST_SAXI_AWCACHE),
        .HIST_SAXI_MODE_ADDR_MASK (HIST_SAXI_MODE_ADDR_MASK),
        .NUM_FRAME_BITS           (NUM_FRAME_BITS)
    ) histogram_saxi_i (
        .rst            (rst),                    // input
        .mclk           (mclk),                   // input
        .aclk           (aclk),                   // input
        .frame0         (frame_num0),             // input[3:0] 
        .hist_request0  (hist_request[0]),        // input
        .hist_grant0    (hist_grant[0]),          // output
        .hist_chn0      (hist_chn[0 * 2 +: 2]),   // input[1:0] 
        .hist_dvalid0   (hist_dvalid[0]),         // input
        .hist_data0     (hist_data[0 * 32 +: 32]),// input[31:0] 
        .frame1         (frame_num1),             // input[3:0] 
        .hist_request1  (hist_request[1]),        // input
        .hist_grant1    (hist_grant[1]),          // output
        .hist_chn1      (hist_chn[1 * 2 +: 2]),   // input[1:0] 
        .hist_dvalid1   (hist_dvalid[1]),         // input
        .hist_data1     (hist_data[1 * 32 +: 32]),// input[31:0] 
        .frame2         (frame_num2),             // input[3:0] 
        .hist_request2  (hist_request[2]),        // input
        .hist_grant2    (hist_grant[2]),          // output
        .hist_chn2      (hist_chn[2 * 2 +: 2]),   // input[1:0]
        .hist_dvalid2   (hist_dvalid[2]),         // input
        .hist_data2     (hist_data[2 * 32 +: 32]),// input[31:0] 
        .frame3         (frame_num3),             // input[3:0] 
        .hist_request3  (hist_request[3]),        // input
        .hist_grant3    (hist_grant[3]),          // output
        .hist_chn3      (hist_chn[3 * 2 +: 2]),   // input[1:0]
        .hist_dvalid3   (hist_dvalid[3]),         // input
        .hist_data3     (hist_data[3 * 32 +: 32]),// input[31:0] 
        .cmd_ad         (cmd_ad),                 // input[7:0] 
        .cmd_stb        (cmd_stb),                // input
        .saxi_awaddr    (saxi_awaddr),            // output[31:0] 
        .saxi_awvalid   (saxi_awvalid),           // output
        .saxi_awready   (saxi_awready),           // input
        .saxi_awid      (saxi_awid),              // output[5:0] 
        .saxi_awlock    (saxi_awlock),            // output[1:0] 
        .saxi_awcache   (saxi_awcache),           // output[3:0] 
        .saxi_awprot    (saxi_awprot),            // output[2:0] 
        .saxi_awlen     (saxi_awlen),             // output[3:0] 
        .saxi_awsize    (saxi_awsize),            // output[1:0] 
        .saxi_awburst   (saxi_awburst),           // output[1:0] 
        .saxi_awqos     (saxi_awqos),             // output[3:0] 
        .saxi_wdata     (saxi_wdata),             // output[31:0] 
        .saxi_wvalid    (saxi_wvalid),            // output
        .saxi_wready    (saxi_wready),            // input
        .saxi_wid       (saxi_wid),               // output[5:0] 
        .saxi_wlast     (saxi_wlast),             // output
        .saxi_wstrb     (saxi_wstrb),             // output[3:0] 
        .saxi_bvalid    (saxi_bvalid),            // input
        .saxi_bready    (saxi_bready),            // output
        .saxi_bid       (saxi_bid),               // input[5:0] 
        .saxi_bresp     (saxi_bresp)              // input[1:0] 
    );
    
    status_router4 status_router4_i (
        .rst           (rst),                    // input
        .clk           (mclk),                   // input
        .db_in0        (status_ad_chn[0 +: 8]),  // input[7:0] 
        .rq_in0        (status_rq_chn[0]),       // input
        .start_in0     (status_start_chn[0]),    // output
        .db_in1        (status_ad_chn[8 +: 8]),  // input[7:0] 
        .rq_in1        (status_rq_chn[1]),       // input
        .start_in1     (status_start_chn[1]),    // output
        .db_in2        (status_ad_chn[16 +: 8]), // input[7:0] 
        .rq_in2        (status_rq_chn[2]),       // input
        .start_in2     (status_start_chn[2]),    // output
        .db_in3        (status_ad_chn[24 +: 8]), // input[7:0] 
        .rq_in3        (status_rq_chn[3]),       // input
        .start_in3     (status_start_chn[3]),    // output
        .db_out        (status_ad),              // output[7:0] 
        .rq_out        (status_rq),              // output
        .start_out     (status_start)            // input
    );

    idelay_ctrl# (
        .IODELAY_GRP("IODELAY_SENSOR_12")
    ) idelay_ctrl_sensor12_i (
        .refclk(ref_clk),
        .rst(dly_rst), //rst || dly_rst
        .rdy()
    );
    
    idelay_ctrl# (
        .IODELAY_GRP("IODELAY_SENSOR_34")
    ) idelay_ctrl_sensor34_i (
        .refclk(ref_clk),
        .rst(dly_rst), //rst || dly_rst
        .rdy()
    );
    
    
endmodule
// TODO: if that works, move it to util_modules
/*
                .IODELAY_GRP                   ((i & 2)?"IODELAY_SENSOR_34":"IODELAY_SENSOR_12"),

module my_alias #(
    parameter WIDTH=1
) (a,a);
inout [WIDTH-1:0] a; // SuppressThisWarning VEditor : it is just an alias for bidirectional wires
endmodule
*/
