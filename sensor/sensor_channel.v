/*******************************************************************************
 * Module: sensor_channel
 * Date:2015-05-10  
 * Author: andrey     
 * Description: Top module for a sensor channel
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
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
    parameter SENSOR_BASE_ADDR =    'h300, // sensor registers base address
    parameter SENSOR_NUM_HISTOGRAM= 3, // number of histogram channels
    parameter SENSOR_CTRL_RADDR =   0, //'h300
    parameter SENSI2C_CTRL_RADDR =  2, // 302..'h303
    parameter SENS_GAMMA_RADDR =    4,
    parameter SENSIO_RADDR =        8, //'h308  .. 'h30c
    parameter SENSI2C_ABS_RADDR =   'h10, // 'h310..'h31f
    parameter SENSI2C_REL_RADDR =   'h20, // 'h320..'h32f
    parameter HISTOGRAM_RADDR0 =    'h30, //
    parameter HISTOGRAM_RADDR1 =    'h32, //
    parameter HISTOGRAM_RADDR2 =    'h34, //
    parameter HISTOGRAM_RADDR3 =    -1,    // < 0 - not implemented
    
//    parameter SENSI2C_ABS_ADDR =   'h302, // 'h300,
//    parameter SENSI2C_REL_ADDR =   'h320, // 'h310,
    parameter SENSOR_CTRL_ADDR_MASK = 'h3ff, //
    parameter SENSI2C_ADDR_MASK =   'h3f0, // both for SENSI2C_ABS_ADDR and SENSI2C_REL_ADDR
//    parameter SENSI2C_CTRL_ADDR = 'h302. //  'h320,
    parameter SENSI2C_CTRL_MASK =   'h3fe,
    parameter SENSI2C_CTRL =        'h0,
    parameter SENSI2C_STATUS =      'h1,
    parameter SENSI2C_STATUS_REG =  'h30,
    parameter integer SENSI2C_DRIVE=12,
    parameter SENSI2C_IBUF_LOW_PWR= "TRUE",
    parameter SENSI2C_IOSTANDARD =  "DEFAULT",
    parameter SENSI2C_SLEW =        "SLOW",
    
//    parameter SENSIO_ADDR =        'h308, //  'h330,
    parameter SENSIO_ADDR_MASK =    'h3f8,
    parameter SENSIO_CTRL =         'h0,
    parameter SENSIO_STATUS =       'h1,
    parameter SENSIO_JTAG =         'h2,
    parameter SENSIO_WIDTH =        'h3, // 1.. 2^16, 0 - use HACT
    parameter SENSIO_DELAYS =       'h4, // 'h4..'h7
    parameter SENSIO_STATUS_REG =   'h31,

    parameter SENS_JTAG_PGMEN =     8,
    parameter SENS_JTAG_PROG =      6,
    parameter SENS_JTAG_TCK =       4,
    parameter SENS_JTAG_TMS =       2,
    parameter SENS_JTAG_TDI =       0,
    
    parameter SENS_CTRL_MRST =      0,  //  1: 0
    parameter SENS_CTRL_ARST =      2,  //  3: 2
    parameter SENS_CTRL_ARO =       4,  //  5: 4
    parameter SENS_CTRL_RST_MMCM =  6,  //  7: 6
    parameter SENS_CTRL_EXT_CLK =   8,  //  9: 8
    parameter SENS_CTRL_LD_DLY =   10,  // 10
    parameter SENS_CTRL_QUADRANTS =12,  // 17:12, enable - 20
    
    parameter SENSOR_DATA_WIDTH =  12,
    parameter SENSOR_FIFO_2DEPTH = 4,
    parameter SENSOR_FIFO_DELAY =  7,
    
//    parameter SENS_GAMMA_ADDR =      'h304, //..'h307, //  'h338,
    parameter SENS_GAMMA_NUM_CHN =     3, // number of subchannels for his sensor ports (1..4)
    parameter SENS_GAMMA_BUFFER =      0, // 1 - use "shadow" table for clean switching, 0 - single table per channel
//    parameter SENS_GAMMA_ADDR =        'h338,
    parameter SENS_GAMMA_ADDR_MASK =   'h3fc,
    parameter SENS_GAMMA_CTRL =        'h0,
    parameter SENS_GAMMA_ADDR_DATA =   'h1, // bit 20 ==1 - table address, bit 20==0 - table data (18 bits)
    parameter SENS_GAMMA_HEIGHT01 =    'h2, // bits [15:0] - height minus 1 of image 0, [31:16] - height-1 of image1
    parameter SENS_GAMMA_HEIGHT2 =     'h3, // bits [15:0] - height minus 1 of image 2 ( no need for image 3)
//    parameter SENS_GAMMA_STATUS_REG =  'h32
    parameter SENS_GAMMA_MODE_WIDTH =  5, // does not include trig
    parameter SENS_GAMMA_MODE_BAYER =  0,
    parameter SENS_GAMMA_MODE_PAGE =   2,
    parameter SENS_GAMMA_MODE_EN =     3,
    parameter SENS_GAMMA_MODE_REPET =  4,
    parameter SENS_GAMMA_MODE_TRIG =   5,
    
    parameter HISTOGRAM_RAM_MODE =     "NOBUF", // valid: "NOBUF" (32-bits, no buffering), "BUF18", "BUF32"
    parameter HISTOGRAM_ADDR_MASK =    'h3fe,
    parameter HISTOGRAM_LEFT_TOP =     'h0,
    parameter HISTOGRAM_WIDTH_HEIGHT = 'h1, // 1.. 2^16, 0 - use HACT
//    parameter HISTOGRAM_ADDR0 =        'h340, // TODO: optimize!
//    parameter HISTOGRAM_ADDR1 =        'h342, // TODO: optimize!
//    parameter HISTOGRAM_ADDR2 =        'h344, // TODO: optimize!
//    parameter HISTOGRAM_ADDR3 =        -1,    // < 0 - not implemented
    
    
    parameter IODELAY_GRP ="IODELAY_SENSOR", // may need different for different channels?
    parameter integer IDELAY_VALUE = 0,
    parameter integer PXD_DRIVE = 12,
    parameter PXD_IBUF_LOW_PWR = "TRUE",
    parameter PXD_IOSTANDARD = "DEFAULT",
    parameter PXD_SLEW = "SLOW",
    parameter real REFCLK_FREQUENCY = 300.0,
    parameter HIGH_PERFORMANCE_MODE = "FALSE",
    
    parameter PHASE_WIDTH=      8,      // number of bits for te phase counter (depends on divisors)
    parameter PCLK_PERIOD =     10.000,  // input period in ns, 0..100.000 - MANDATORY, resolution down to 1 ps
    parameter BANDWIDTH =       "OPTIMIZED",  //"OPTIMIZED", "HIGH","LOW"

    parameter CLKFBOUT_MULT_SENSOR =   8,  // 100 MHz --> 800 MHz
    parameter CLKFBOUT_PHASE_SENSOR =  0.000,  // CLOCK FEEDBACK phase in degrees (3 significant digits, -360.000...+360.000)
    parameter IPCLK_PHASE =           0.000,
    parameter IPCLK2X_PHASE =         0.000,
    

    parameter DIVCLK_DIVIDE =         1,            // Integer 1..106. Divides all outputs with respect to CLKIN
    parameter REF_JITTER1   =         0.010,        // Expectet jitter on CLKIN1 (0.000..0.999)
    parameter REF_JITTER2   =         0.010,
    parameter SS_EN         =         "FALSE",      // Enables Spread Spectrum mode
    parameter SS_MODE       =         "CENTER_HIGH",//"CENTER_HIGH","CENTER_LOW","DOWN_HIGH","DOWN_LOW"
    parameter SS_MOD_PERIOD =         10000        // integer 4000-40000 - SS modulation period in ns
    
) (
    input         rst,
    input         pclk,   // global clock input, pixel rate (96MHz for MT9P006)
    input         pclk2x, // global clock input, double pixel rate (192MHz for MT9P006)
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

    output [15:0] dout,
    output        dout_valid,
    output        sof_out,
    output        eof_out,

    output        hist_request,
    input         hist_grant,
    output  [1:0] hist_chn,      // output[1:0]
    output        hist_dvalid,   // output
    output [31:0] hist_data     // output[31:0] 
    
// (much) more will be added later
    
    
);
//    parameter SENSOR_BASE_ADDR =    'h300; // sensor registers base address
    localparam SENSOR_CTRL_ADDR =  SENSOR_BASE_ADDR + SENSOR_CTRL_RADDR; //'h300
    localparam SENSI2C_CTRL_ADDR = SENSOR_BASE_ADDR + SENSI2C_CTRL_RADDR; // 302..'h303
    localparam SENS_GAMMA_ADDR =   SENSOR_BASE_ADDR + SENS_GAMMA_RADDR;
    localparam SENSIO_ADDR =       SENSOR_BASE_ADDR + SENSIO_RADDR; //'h308  .. 'h30c
    localparam SENSI2C_ABS_ADDR =  SENSOR_BASE_ADDR + SENSI2C_ABS_RADDR; // 'h310..'h31f
    localparam SENSI2C_REL_ADDR =  SENSOR_BASE_ADDR + SENSI2C_REL_RADDR; // 'h320..'h32f
    localparam HISTOGRAM_ADDR0 =   (SENSOR_NUM_HISTOGRAM > 0)?HISTOGRAM_RADDR0:-1; //
    localparam HISTOGRAM_ADDR1 =   (SENSOR_NUM_HISTOGRAM > 1)?HISTOGRAM_RADDR1:-1; //
    localparam HISTOGRAM_ADDR2 =   (SENSOR_NUM_HISTOGRAM > 2)?HISTOGRAM_RADDR2:-1; //
    localparam HISTOGRAM_ADDR3 =   (SENSOR_NUM_HISTOGRAM > 3)?HISTOGRAM_RADDR3:-1; //


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
    
    wire  [15:0] gamma_pxd_in; 
    wire         gamma_hact_in;
    wire         gamma_sof_in;
    wire         gamma_eof_in;
    
    wire   [7:0] gamma_pxd_out; 
    wire         gamma_hact_out;
    wire         gamma_sof_out;
    wire         gamma_eof_out;
    
    wire  [31:0] sensor_ctrl_data;
    wire         sensor_ctrl_we;
    reg    [8:0] mode;
    wire   [3:0] hist_en;
    wire         hist_nrst;
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
    
    reg          sof_out_r;       
    reg          eof_out_r;       
    
    // TODO: insert vignetting and/or flat field, pixel defects before gamma_*_in
    assign gamma_pxd_in = {pxd[11:0],4'b0};
    assign gamma_hact_in = hact;
    assign gamma_sof_in =  sof;
    assign gamma_eof_in =  eof;
    
    assign dout = dout_r;
    assign dout_valid = dav_r;
    assign sof_out = sof_out_r;       
    assign eof_out = eof_out_r;       
    
    assign dout_w = bit16 ? gamma_pxd_in :  {gamma_data_r,gamma_pxd_out};
    assign dav_w =  bit16 ? gamma_hact_in : dav_8bit;
    
     
    assign hist_en =   mode[3:0];
    assign hist_nrst = mode[4];
    assign bit16 =     mode[8];
    
    
    always @ (posedge mclk) begin
        cmd_ad  <= cmd_ad_in; 
        cmd_stb <= cmd_stb_in;
    end

    always @ (posedge  rst or posedge mclk) begin
        if      (rst)            mode <= 0;
        else if (sensor_ctrl_we) mode <= sensor_ctrl_data[8:0];
    end
    
    always @ (posedge pclk) begin
        if (dav_w) dout_r <= dout_w;

        dav_r <= dav_w;

        dav_8bit <= gamma_hact_out && !dav_8bit;
        
        if (gamma_hact_out && !dav_8bit) gamma_data_r <= gamma_pxd_out;
        
        sof_out_r <= bit16 ? gamma_sof_in : gamma_sof_out;
        eof_out_r <= bit16 ? gamma_eof_in : gamma_eof_out;
    end

    status_router2 status_router2_sensor_i (
        .rst       (rst),                     // input
        .clk       (mclk),                    // input
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
        .rst         (rst), // input
        .clk         (mclk), // input
        .ad          (cmd_ad), // input[7:0] 
        .stb         (cmd_stb), // input
        .addr        (), // output[0:0] - not used
        .data        (sensor_ctrl_data), // output[31:0] 
        .we          (sensor_ctrl_we) // output
    );

    sensor_i2c_io #(
        .SENSI2C_ABS_ADDR      (SENSI2C_ABS_ADDR),
        .SENSI2C_REL_ADDR      (SENSI2C_REL_ADDR),
        .SENSI2C_ADDR_MASK     (SENSI2C_ADDR_MASK),
        .SENSI2C_CTRL_ADDR     (SENSI2C_CTRL_ADDR),
        .SENSI2C_CTRL_MASK     (SENSI2C_CTRL_MASK),
        .SENSI2C_CTRL          (SENSI2C_CTRL),
        .SENSI2C_STATUS        (SENSI2C_STATUS),
        .SENSI2C_STATUS_REG    (SENSI2C_STATUS_REG),
        .SENSI2C_DRIVE         (SENSI2C_DRIVE),
        .SENSI2C_IBUF_LOW_PWR  (SENSI2C_IBUF_LOW_PWR),
        .SENSI2C_IOSTANDARD    (SENSI2C_IOSTANDARD),
        .SENSI2C_SLEW          (SENSI2C_SLEW)
    ) sensor_i2c_io_i (
        .rst                   (rst), // input
        .mclk                  (mclk), // input
        .cmd_ad                (cmd_ad), // input[7:0] 
        .cmd_stb               (cmd_stb), // input
        .status_ad             (sens_i2c_status_ad), // output[7:0] 
        .status_rq             (sens_i2c_status_rq), // output
        .status_start          (sens_i2c_status_start), // input
        .frame_sync      (), // input
        .scl                   (sns_scl), // inout
        .sda                   (sns_sda) // inout
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
        .IODELAY_GRP           (IODELAY_GRP),
        .IDELAY_VALUE          (IDELAY_VALUE),
        .PXD_DRIVE             (PXD_DRIVE),
        .PXD_IBUF_LOW_PWR      (PXD_IBUF_LOW_PWR),
        .PXD_IOSTANDARD        (PXD_IOSTANDARD),
        .PXD_SLEW              (PXD_SLEW),
        .REFCLK_FREQUENCY      (REFCLK_FREQUENCY),
        .HIGH_PERFORMANCE_MODE (HIGH_PERFORMANCE_MODE),
        .PHASE_WIDTH           (PHASE_WIDTH),
        .PCLK_PERIOD           (PCLK_PERIOD),
        .BANDWIDTH             (BANDWIDTH),
        .CLKFBOUT_MULT_SENSOR  (CLKFBOUT_MULT_SENSOR),
        .CLKFBOUT_PHASE_SENSOR (CLKFBOUT_PHASE_SENSOR),
        .IPCLK_PHASE           (IPCLK_PHASE),
        .IPCLK2X_PHASE         (IPCLK2X_PHASE),
        .DIVCLK_DIVIDE         (DIVCLK_DIVIDE),
        .REF_JITTER1           (REF_JITTER1),
        .REF_JITTER2           (REF_JITTER2),
        .SS_EN                 (SS_EN),
        .SS_MODE               (SS_MODE),
        .SS_MOD_PERIOD         (SS_MOD_PERIOD)
    ) sens_parallel12_i (
        .rst                  (rst),                    // input
        .pclk                 (pclk),                   // input
        .ipclk                (ipclk),                  // output
        .ipclk2x              (), // ipclk2x),          // output
        .vact                 (sns_dn[1]),              // input
        .hact                 (sns_dp[1]),              // input
        .bpf                  (sns_dn[0]),              // inout
        .pxd                  ({sns_dn[6],sns_dp[6],sns_dn[5],sns_dp[5],sns_dn[4],sns_dp[4],sns_dn[3],sns_dp[3],sns_dn[2],sns_dp[2],sns_clkp,sns_clkn}), // inout[11:0] 
        .mrst                 (sns_dp[7]),              // inout
        .senspgm              (sns_pg),                 // inout
        .arst                 (sns_dn[7]),              // inout
        .aro                  (sns_ctl),                // inout
        .dclk                 (sns_dp[0]),              // output
        .pxd_out              (pxd_to_fifo[11:0]),      // output[11:0] 
        .vact_out             (vact_to_fifo),                   // output
        .hact_out             (hact_to_fifo),                   // output: either delayed input, or regenerated from the leading edge and programmable duration
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
        .rst         (rst),     // input
        .iclk        (ipclk), // input
        .pclk        (pclk), // input
        .pxd_in      (pxd_to_fifo), // input[11:0] 
        .vact        (vact_to_fifo), // input
        .hact        (hact_to_fifo), // input
        .pxd_out     (pxd), // output[11:0] 
        .data_valid  (hact), // output
        .sof         (sof), // output
        .eof         (eof) // output
    );

    sens_gamma #(
        .SENS_GAMMA_NUM_CHN    (SENS_GAMMA_NUM_CHN),
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
        .rst         (rst), // input
        .pclk        (pclk), // input
        .pxd_in      (gamma_pxd_in), // input[15:0] 
        .hact_in     (gamma_hact_in), // input
        .sof_in      (gamma_sof_in), // input
        .eof_in      (gamma_eof_in), // input
        .trig_in     (1'b0), // input (use trig_soft)
        .pxd_out     (gamma_pxd_out), // output[7:0] 
        .hact_out    (gamma_hact_out), // output
        .sof_out     (gamma_sof_out), // output
        .eof_out     (gamma_eof_out), // output
        .mclk        (mclk), // input
        .cmd_ad      (cmd_ad), // input[7:0] 
        .cmd_stb     (cmd_stb) // input
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
            ) sens_histogram_i (
                .rst        (rst), // input
                .pclk       (pclk), // input
                .pclk2x     (pclk2x), // input
                .sof        (gamma_sof_out), // input
                .hact       (gamma_hact_out), // input
                .hist_di    (gamma_pxd_out), // input[7:0] 
                .mclk       (mclk), // input
                .hist_en    (hist_en[0]), // input
                .hist_rst   (!hist_nrst), // input
                .hist_rq    (hist_rq[0]), // output
                .hist_grant (hist_gr[0]), // input
                .hist_do    (hist_do0), // output[31:0] 
                .hist_dv    (hist_dv[0]), // output
                .cmd_ad     (cmd_ad), // input[7:0] 
                .cmd_stb    (cmd_stb) // input
            );
        else
            sens_histogram_dummy sens_histogram_dummy_i (
                .hist_rq(hist_rq[0]), // output
                .hist_do(hist_do0), // output[31:0] 
                .hist_dv(hist_dv[0]) // output
            );
    endgenerate
    generate
        if (HISTOGRAM_ADDR1 >=0)
            sens_histogram #(
                .HISTOGRAM_RAM_MODE     (HISTOGRAM_RAM_MODE),
                .HISTOGRAM_ADDR         (HISTOGRAM_ADDR1),
                .HISTOGRAM_ADDR_MASK    (HISTOGRAM_ADDR_MASK),
                .HISTOGRAM_LEFT_TOP     (HISTOGRAM_LEFT_TOP),
                .HISTOGRAM_WIDTH_HEIGHT (HISTOGRAM_WIDTH_HEIGHT)
            ) sens_histogram_i (
                .rst        (rst), // input
                .pclk       (pclk), // input
                .pclk2x     (pclk2x), // input
                .sof        (gamma_sof_out), // input
                .hact       (gamma_hact_out), // input
                .hist_di    (gamma_pxd_out), // input[7:0] 
                .mclk       (mclk), // input
                .hist_en    (hist_en[1]), // input
                .hist_rst   (!hist_nrst), // input
                .hist_rq    (hist_rq[1]), // output
                .hist_grant (hist_gr[1]), // input
                .hist_do    (hist_do1), // output[31:0] 
                .hist_dv    (hist_dv[1]), // output
                .cmd_ad     (cmd_ad), // input[7:0] 
                .cmd_stb    (cmd_stb) // input
            );
        else
            sens_histogram_dummy sens_histogram_dummy_i (
                .hist_rq(hist_rq[1]), // output
                .hist_do(hist_do1), // output[31:0] 
                .hist_dv(hist_dv[1]) // output
            );
    endgenerate
    generate
        if (HISTOGRAM_ADDR2 >=0)
            sens_histogram #(
                .HISTOGRAM_RAM_MODE     (HISTOGRAM_RAM_MODE),
                .HISTOGRAM_ADDR         (HISTOGRAM_ADDR2),
                .HISTOGRAM_ADDR_MASK    (HISTOGRAM_ADDR_MASK),
                .HISTOGRAM_LEFT_TOP     (HISTOGRAM_LEFT_TOP),
                .HISTOGRAM_WIDTH_HEIGHT (HISTOGRAM_WIDTH_HEIGHT)
            ) sens_histogram_i (
                .rst        (rst), // input
                .pclk       (pclk), // input
                .pclk2x     (pclk2x), // input
                .sof        (gamma_sof_out), // input
                .hact       (gamma_hact_out), // input
                .hist_di    (gamma_pxd_out), // input[7:0] 
                .mclk       (mclk), // input
                .hist_en    (hist_en[2]), // input
                .hist_rst   (!hist_nrst), // input
                .hist_rq    (hist_rq[2]), // output
                .hist_grant (hist_gr[2]), // input
                .hist_do    (hist_do2), // output[31:0] 
                .hist_dv    (hist_dv[2]), // output
                .cmd_ad     (cmd_ad), // input[7:0] 
                .cmd_stb    (cmd_stb) // input
            );
        else
            sens_histogram_dummy sens_histogram_dummy_i (
                .hist_rq(hist_rq[2]), // output
                .hist_do(hist_do2), // output[31:0] 
                .hist_dv(hist_dv[2]) // output
            );
    endgenerate
    generate
        if (HISTOGRAM_ADDR3 >=0)
            sens_histogram #(
                .HISTOGRAM_RAM_MODE     (HISTOGRAM_RAM_MODE),
                .HISTOGRAM_ADDR         (HISTOGRAM_ADDR3),
                .HISTOGRAM_ADDR_MASK    (HISTOGRAM_ADDR_MASK),
                .HISTOGRAM_LEFT_TOP     (HISTOGRAM_LEFT_TOP),
                .HISTOGRAM_WIDTH_HEIGHT (HISTOGRAM_WIDTH_HEIGHT)
            ) sens_histogram_i (
                .rst        (rst), // input
                .pclk       (pclk), // input
                .pclk2x     (pclk2x), // input
                .sof        (gamma_sof_out), // input
                .hact       (gamma_hact_out), // input
                .hist_di    (gamma_pxd_out), // input[7:0] 
                .mclk       (mclk), // input
                .hist_en    (hist_en[3]), // input
                .hist_rst   (!hist_nrst), // input
                .hist_rq    (hist_rq[3]), // output
                .hist_grant (hist_gr[3]), // input
                .hist_do    (hist_do3), // output[31:0] 
                .hist_dv    (hist_dv[3]), // output
                .cmd_ad     (cmd_ad), // input[7:0] 
                .cmd_stb    (cmd_stb) // input
            );
        else
            sens_histogram_dummy sens_histogram_dummy_i (
                .hist_rq(hist_rq[3]), // output
                .hist_do(hist_do3), // output[31:0] 
                .hist_dv(hist_dv[3]) // output
            );
    endgenerate
    
    sens_histogram_mux sens_histogram_mux_i (
        .mclk   (mclk),          // input
        .en     (!hist_nrst),    // input
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

