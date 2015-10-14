/*******************************************************************************
 * Module: sens_hispi12l4
 * Date:2015-10-13  
 * Author: andrey     
 * Description: Decode HiSPi 4-lane, 12 bits Packetized-SP data from the sensor
 *
 * Copyright (c) 2015 Elphel, Inc .
 * sens_hispi12l4.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  sens_hispi12l4.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  sens_hispi12l4#(
    parameter IODELAY_GRP =               "IODELAY_SENSOR",
    parameter integer IDELAY_VALUE =       0,
    parameter real REFCLK_FREQUENCY =      200.0,
    parameter HIGH_PERFORMANCE_MODE =     "FALSE",
    parameter SENS_PHASE_WIDTH=            8,      // number of bits for te phase counter (depends on divisors)
    parameter SENS_PCLK_PERIOD =           3.000,  // input period in ns, 0..100.000 - MANDATORY, resolution down to 1 ps
    parameter SENS_BANDWIDTH =             "OPTIMIZED",  //"OPTIMIZED", "HIGH","LOW"

    parameter CLKFBOUT_MULT_SENSOR =       4,  // 220 MHz --> 880 MHz
    parameter CLKFBOUT_PHASE_SENSOR =      0.000,  // CLOCK FEEDBACK phase in degrees (3 significant digits, -360.000...+360.000)
    parameter IPCLK_PHASE =                0.000,
    parameter IPCLK2X_PHASE =              0.000,
    parameter BUF_IPCLK =                 "BUFR",
    parameter BUF_IPCLK2X =               "BUFR",  

    parameter SENS_DIVCLK_DIVIDE =         1,            // Integer 1..106. Divides all outputs with respect to CLKIN
    parameter SENS_REF_JITTER1   =         0.010,        // Expectet jitter on CLKIN1 (0.000..0.999)
    parameter SENS_REF_JITTER2   =         0.010,
    parameter SENS_SS_EN         =        "FALSE",      // Enables Spread Spectrum mode
    parameter SENS_SS_MODE       =        "CENTER_HIGH",//"CENTER_HIGH","CENTER_LOW","DOWN_HIGH","DOWN_LOW"
    parameter SENS_SS_MOD_PERIOD =         10000,        // integer 4000-40000 - SS modulation period in ns

    parameter HISPI_NUMLANES =             4,
    parameter HISPI_CAPACITANCE =         "DONT_CARE",
    parameter HISPI_DIFF_TERM =           "TRUE",
    parameter HISPI_DQS_BIAS =            "TRUE",
    parameter HISPI_IBUF_DELAY_VALUE =    "0",
    parameter HISPI_IBUF_LOW_PWR =        "TRUE",
    parameter HISPI_IFD_DELAY_VALUE =     "AUTO",
    parameter HISPI_IOSTANDARD =          "DEFAULT"
)(
    input             pclk,   // global clock input, pixel rate (220MHz for MT9F002)
    input             prst,
    output            irst,
    
    input             trigger_mode, // running in triggered mode (0 - free running mode)
    input             trig,      // per-sensor trigger input
    // I/O pads
    input [HISPI_NUMLANES-1:0] sns_dp,
    input [HISPI_NUMLANES-1:0] sns_dn,
    input                      sns_clkp,
    input                      sns_clkn,
    // output
    output reg          [11:0] pxd_out,
    output reg                 vact_out, 
    output                     hact_out,
    
    // delay control inputs
    input                           mclk,
    input                           mrst,
    input  [HISPI_NUMLANES * 8-1:0] dly_data,        // delay value (3 LSB - fine delay) - @posedge mclk
    input      [HISPI_NUMLANES-1:0] set_idelay,      // mclk synchronous load idelay value
    input                           ld_idelay,       // mclk synchronous set idealy value
    input                           set_clk_phase,    // mclk synchronous set idealy value
    input                           rst_mmcm,
    // MMCP output status
    output       ps_rdy,          // output
    output [7:0] ps_out,          // output[7:0] reg 
    output       locked_pxd_mmcm,
    output       clkin_pxd_stopped_mmcm, // output
    output       clkfb_pxd_stopped_mmcm // output
    
);
    wire                          ipclk;  // re-generated half HiSPi clock (165 MHz) 
    wire                          ipclk2x;// re-generated HiSPi clock (330 MHz)
    wire [HISPI_NUMLANES * 4-1:0] sns_d;
    sens_hispi_clock #(
        .SENS_PHASE_WIDTH       (SENS_PHASE_WIDTH),
        .SENS_PCLK_PERIOD       (SENS_PCLK_PERIOD),
        .SENS_BANDWIDTH         (SENS_BANDWIDTH),
        .CLKFBOUT_MULT_SENSOR   (CLKFBOUT_MULT_SENSOR),
        .CLKFBOUT_PHASE_SENSOR  (CLKFBOUT_PHASE_SENSOR),
        .IPCLK_PHASE            (IPCLK_PHASE),
        .IPCLK2X_PHASE          (IPCLK2X_PHASE),
        .BUF_IPCLK              (BUF_IPCLK),
        .BUF_IPCLK2X            (BUF_IPCLK2X),
        .SENS_DIVCLK_DIVIDE     (SENS_DIVCLK_DIVIDE),
        .SENS_REF_JITTER1       (SENS_REF_JITTER1),
        .SENS_REF_JITTER2       (SENS_REF_JITTER2),
        .SENS_SS_EN             (SENS_SS_EN),
        .SENS_SS_MODE           (SENS_SS_MODE),
        .SENS_SS_MOD_PERIOD     (SENS_SS_MOD_PERIOD),
        .HISPI_CAPACITANCE      (HISPI_CAPACITANCE),
        .HISPI_DIFF_TERM        (HISPI_DIFF_TERM),
        .HISPI_DQS_BIAS         (HISPI_DQS_BIAS),
        .HISPI_IBUF_DELAY_VALUE (HISPI_IBUF_DELAY_VALUE),
        .HISPI_IBUF_LOW_PWR     (HISPI_IBUF_LOW_PWR),
        .HISPI_IFD_DELAY_VALUE  (HISPI_IFD_DELAY_VALUE),
        .HISPI_IOSTANDARD       (HISPI_IOSTANDARD)
    ) sens_hispi_clock_i (
        .mclk                   (mclk),                   // input
        .mrst                   (mrst),                   // input
        .phase                  (dly_data[7:0]),          // input[7:0] 
        .set_phase              (set_clk_phase),          // input
        .rst_mmcm               (rst_mmcm),               // input
        .clp_p                  (sns_clkp),               // input
        .clk_n                  (sns_clkn),               // input
        .ipclk                  (ipclk),                  // output
        .ipclk2x                (ipclk2x),                // output
        .ps_rdy                 (ps_rdy),                 // output
        .ps_out                 (ps_out),                 // output[7:0] 
        .locked_pxd_mmcm        (locked_pxd_mmcm),        // output
        .clkin_pxd_stopped_mmcm (clkin_pxd_stopped_mmcm), // output
        .clkfb_pxd_stopped_mmcm (clkfb_pxd_stopped_mmcm)  // output
    );

    sens_hispi_din #(
        .IODELAY_GRP            (IODELAY_GRP),
        .IDELAY_VALUE           (IDELAY_VALUE),
        .REFCLK_FREQUENCY       (REFCLK_FREQUENCY),
        .HIGH_PERFORMANCE_MODE  (HIGH_PERFORMANCE_MODE),
        .HISPI_NUMLANES         (HISPI_NUMLANES),
        .HISPI_CAPACITANCE      (HISPI_CAPACITANCE),
        .HISPI_DIFF_TERM        (HISPI_DIFF_TERM),
        .HISPI_DQS_BIAS         (HISPI_DQS_BIAS),
        .HISPI_IBUF_DELAY_VALUE (HISPI_IBUF_DELAY_VALUE),
        .HISPI_IBUF_LOW_PWR     (HISPI_IBUF_LOW_PWR),
        .HISPI_IFD_DELAY_VALUE  (HISPI_IFD_DELAY_VALUE),
        .HISPI_IOSTANDARD       (HISPI_IOSTANDARD)
    ) sens_hispi_din_i (
        .mclk         (mclk), // input
        .mrst         (mrst), // input
        .dly_data     (dly_data), // input[31:0] 
        .set_idelay   (set_idelay), // input[3:0] 
        .ld_idelay    (ld_idelay), // input
        .ipclk        (ipclk), // input
        .ipclk2x      (ipclk2x), // input
        .irst         (irst), // input
        .din_p        (sns_dp), // input[3:0] 
        .din_n        (sns_dn), // input[3:0] 
        .dout         (sns_d) // output[15:0] 
    );



endmodule

