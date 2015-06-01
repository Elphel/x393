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
    parameter SENSI2C_ABS_ADDR =    'h300,
    parameter SENSI2C_REL_ADDR =    'h310,
    parameter SENSI2C_ADDR_MASK =   'h3f0, // both for SENSI2C_ABS_ADDR and SENSI2C_REL_ADDR
    parameter SENSI2C_CTRL_ADDR =   'h320,
    parameter SENSI2C_CTRL_MASK =   'h3fe,
    parameter SENSI2C_CTRL =        'h0,
    parameter SENSI2C_STATUS =      'h1,
    parameter SENSI2C_STATUS_REG =  'h30,
    parameter integer SENSI2C_DRIVE=12,
    parameter SENSI2C_IBUF_LOW_PWR= "TRUE",
    parameter SENSI2C_IOSTANDARD =  "DEFAULT",
    parameter SENSI2C_SLEW =        "SLOW",
    
    parameter SENSIO_ADDR =         'h330,
    parameter SENSIO_ADDR_MASK =    'h3f8,
    parameter SENSIO_CTRL =         'h0,
    parameter SENSIO_STATUS =       'h1,
    parameter SENSIO_JTAG =         'h2,
    parameter SENSIO_WIDTH =        'h3, // 1.. 2^16, 0 - use HACT
    parameter SENSIO_DELAYS =       'h4,
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
    
    parameter SENS_GAMMA_ADDR =        'h338,
    parameter SENS_GAMMA_ADDR_MASK =   'h3fc,
    parameter SENS_GAMMA_CTRL =        'h0,
//    parameter SENS_GAMMA_STATUS =      'h1,
    parameter SENS_GAMMA_TADDR =       'h2,
    parameter SENS_GAMMA_TDATA =       'h3, // 1.. 2^16, 0 - use HACT
//    parameter SENS_GAMMA_STATUS_REG =  'h32
    parameter SENS_GAMMA_MODE_WIDTH =  5, // does not include trig
    parameter SENS_GAMMA_MODE_BAYER =  0,
    parameter SENS_GAMMA_MODE_PAGE =   2,
    parameter SENS_GAMMA_MODE_EN =     3,
    parameter SENS_GAMMA_MODE_REPET =  4,
    parameter SENS_GAMMA_MODE_TRIG =   5,
    
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
    input rst,
    input pclk, // global clock input, pixel rate (96MHz for MT9P006)
    // I/O pads, pin names match circuit diagram
    inout  [7:0] sns_dp,
    inout  [7:0] sns_dn,
    inout        sns_clkp,
    inout        sns_clkn,
    inout        sns_scl,
    inout        sns_sda,
    inout        sns_ctl,
    inout        sns_pg,
    // programming interface
    input        mclk,     // global clock, half DDR3 clock, synchronizes all I/O through the command port
    input  [7:0] cmd_ad_in,      // byte-serial command address/data (up to 6 bytes: AL-AH-D0-D1-D2-D3 
    input        cmd_stb_in,     // strobe (with first byte) for the command a/d
    output [7:0] status_ad,   // status address/data - up to 5 bytes: A - {seq,status[1:0]} - status[2:9] - status[10:17] - status[18:25]
    output       status_rq,   // input request to send status downstream
    input        status_start // Acknowledge of the first status packet byte (address)
// (much) more will be added later    
    
);
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
    
    // TODO: insert vignetting and/or flat field, pixel defects before gamma_*_in
    assign gamma_pxd_in = {pxd[11:0],4'b0};
    assign gamma_hact_in = hact;
    assign gamma_sof_in =  sof;
    assign gamma_eof_in =  eof;
     
    
    always @ (posedge mclk) begin
        cmd_ad  <= cmd_ad_in; 
        cmd_stb <= cmd_stb_in;
    end

    status_router2 status_router2_sensori (
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
        .SENS_GAMMA_ADDR       (SENS_GAMMA_ADDR),
        .SENS_GAMMA_ADDR_MASK  (SENS_GAMMA_ADDR_MASK),
        .SENS_GAMMA_CTRL       (SENS_GAMMA_CTRL),
        .SENS_GAMMA_TADDR      (SENS_GAMMA_TADDR),
        .SENS_GAMMA_TDATA      (SENS_GAMMA_TDATA),
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



endmodule

