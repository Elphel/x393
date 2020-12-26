/*!
 * <b>Module:</b>sens_103993_l3
 * @file sens_hispi12l4.v
 * @date 2015-10-13  
 * @author Andrey Filippov     
 *
 * @brief data from 103993 over 3 lanes
 *
 * @copyright Copyright (c) 2020 Elphel, Inc .
 *
 * <b>License:</b>
 *
 * sens_103993_l3.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  sens_103993_l3.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *
 * Additional permission under GNU GPL version 3 section 7:
 * If you modify this Program, or any covered work, by linking or combining it
 * with independent modules provided by the FPGA vendor only (this permission
 * does not extend to any 3-rd party modules, "soft cores" or macros) under
 * different license terms solely for the purpose of generating binary "bitstream"
 * files and/or simulating the code, the copyright holders of this Program give
 * you the right to distribute the covered work without those independent modules
 * as long as the source code for them is available from the FPGA vendor free of
 * charge, and there is no dependence on any encrypted modules for simulating of
 * the combined code. This permission applies to you if the distributed code
 * contains all the components and scripts required to completely simulate it
 * with at least one of the Free Software programs.
 */
`timescale 1ns/1ps
//`define MON_HISPI // moved to system_defines
module  sens_103993_l3#(
    parameter IODELAY_GRP =               "IODELAY_SENSOR",
    parameter integer IDELAY_VALUE =       0,
    parameter real REFCLK_FREQUENCY =      200.0,
    parameter HIGH_PERFORMANCE_MODE =     "FALSE",
    parameter SENS_PHASE_WIDTH=            8,      // number of bits for te phase counter (depends on divisors)
    parameter SENS_BANDWIDTH =             "OPTIMIZED",  //"OPTIMIZED", "HIGH","LOW"

    parameter CLKIN_PERIOD_SENSOR =        37.037, // input period in ns, 0..100.000 - MANDATORY, resolution down to 1 ps
    parameter CLKFBOUT_MULT_SENSOR =       30,      // 27 MHz --> 810 MHz (3*270MHz)
    parameter CLKFBOUT_PHASE_SENSOR =      0.000,  // CLOCK FEEDBACK phase in degrees (3 significant digits, -360.000...+360.000)
    parameter PCLK_PHASE =                 0.000,
    parameter IPCLK2X_PHASE =              0.000,
    parameter BUF_PCLK =                  "BUFR",  
    parameter BUF_IPCLK2X =               "BUFR",  

    parameter SENS_DIVCLK_DIVIDE =         1,            // Integer 1..106. Divides all outputs with respect to CLKIN
    parameter SENS_REF_JITTER1   =         0.010,        // Expected jitter on CLKIN1 (0.000..0.999)
    parameter SENS_REF_JITTER2   =         0.010,
    parameter SENS_SS_EN         =        "FALSE",      // Enables Spread Spectrum mode
    parameter SENS_SS_MODE       =        "CENTER_HIGH",//"CENTER_HIGH","CENTER_LOW","DOWN_HIGH","DOWN_LOW"
    parameter SENS_SS_MOD_PERIOD =         10000,        // integer 4000-40000 - SS modulation period in ns

    parameter NUMLANES =                   3,
    parameter LVDS_DELAY_CLK =            "FALSE",      
    parameter LVDS_MMCM =                 "TRUE",
    parameter LVDS_CAPACITANCE =          "DONT_CARE",
    parameter LVDS_DIFF_TERM =            "TRUE",
    parameter LVDS_UNTUNED_SPLIT =        "FALSE", // Very power-hungry
    parameter LVDS_DQS_BIAS =             "TRUE",
    parameter LVDS_IBUF_DELAY_VALUE =     "0",
    parameter LVDS_IBUF_LOW_PWR =         "TRUE",
    parameter LVDS_IFD_DELAY_VALUE =      "AUTO",
    parameter LVDS_IOSTANDARD =           "DIFF_SSTL18_I" //"DIFF_SSTL18_II" for high current (13.4mA vs 8mA),
)(
    output            pclk,   // global clock input, pixel rate (27MHz for 103993) (220MHz for MT9F002)
    // I/O pads
    input [NUMLANES-1:0] sns_dp,
    input [NUMLANES-1:0] sns_dn,
    input                      sns_clkp,
    input                      sns_clkn,
    // output
    output              [15:0] pxd_out, 
    output                     vsync, 
    output                     hsync,
    output                     dvalid,
    // delay control inputs
    input                           mclk,
    input                           mrst,
    input        [NUMLANES * 8-1:0] dly_data,        // delay value (3 LSB - fine delay) - @posedge mclk
    input            [NUMLANES-1:0] set_idelay,      // mclk synchronous load idelay value
    input                           ld_idelay,       // mclk synchronous set idelay value
    input                           set_clk_phase,   // mclk synchronous set idelay value
    input                           rst_mmcm,
    // MMCP output status
    output                         perr,            // parity error
    output                         ps_rdy,          // output
    output                   [7:0] ps_out,          // output[7:0] reg 
    output                         locked_pxd_mmcm,
    output                         clkin_pxd_stopped_mmcm, // output
    output                         clkfb_pxd_stopped_mmcm  // output
);
    wire                     ipclk2x;// re-generated HiSPi clock (270 MHa) 330 MHz)
    wire [NUMLANES * 10-1:0] sns_d;
    reg               [15:0] pxd_out_r; 
    reg                      vsync_r; 
    reg                      hsync_r;
    reg                      dvalid_r;
    reg                      perr_r;
    reg                      cp_r;
    
    assign pxd_out =    pxd_out_r;
    assign vsync =      vsync_r;
    assign hsync =      hsync_r;
    assign dvalid =     dvalid_r;
    assign perr =       perr_r;

    sens_103993_clock #(
        .SENS_PHASE_WIDTH       (SENS_PHASE_WIDTH),
        .SENS_BANDWIDTH         (SENS_BANDWIDTH),
        .CLKIN_PERIOD_SENSOR    (CLKIN_PERIOD_SENSOR),
        .CLKFBOUT_MULT_SENSOR   (CLKFBOUT_MULT_SENSOR),
        .CLKFBOUT_PHASE_SENSOR  (CLKFBOUT_PHASE_SENSOR),
        .PCLK_PHASE             (PCLK_PHASE),
        .IPCLK2X_PHASE          (IPCLK2X_PHASE),
        .BUF_PCLK               (BUF_PCLK),
        .BUF_IPCLK2X            (BUF_IPCLK2X),
        .SENS_DIVCLK_DIVIDE     (SENS_DIVCLK_DIVIDE),
        .SENS_REF_JITTER1       (SENS_REF_JITTER1),
        .SENS_REF_JITTER2       (SENS_REF_JITTER2),
        .SENS_SS_EN             (SENS_SS_EN),
        .SENS_SS_MODE           (SENS_SS_MODE),
        .SENS_SS_MOD_PERIOD     (SENS_SS_MOD_PERIOD),
        .IODELAY_GRP            (IODELAY_GRP),
        .IDELAY_VALUE           (IDELAY_VALUE),
        .REFCLK_FREQUENCY       (REFCLK_FREQUENCY),
        .HIGH_PERFORMANCE_MODE  (HIGH_PERFORMANCE_MODE),

        .LVDS_DELAY_CLK         (LVDS_DELAY_CLK),
        .LVDS_MMCM              (LVDS_MMCM),
         
        .LVDS_CAPACITANCE       (LVDS_CAPACITANCE),
        .LVDS_DIFF_TERM         (LVDS_DIFF_TERM),
        .LVDS_DQS_BIAS          (LVDS_DQS_BIAS),
        .LVDS_IBUF_DELAY_VALUE  (LVDS_IBUF_DELAY_VALUE),
        .LVDS_IBUF_LOW_PWR      (LVDS_IBUF_LOW_PWR),
        .LVDS_IFD_DELAY_VALUE   (LVDS_IFD_DELAY_VALUE),
        .LVDS_IOSTANDARD        (LVDS_IOSTANDARD)
    ) sens_103993_clock_i (
        .mclk                   (mclk),                   // input
        .mrst                   (mrst),                   // input
        .phase                  (dly_data[7:0]),          // input[7:0] 
        .set_phase              (set_clk_phase),          // input
        .load                   (ld_idelay),              // input
        .rst_mmcm               (rst_mmcm),               // input
        .clp_p                  (sns_clkp),               // input
        .clk_n                  (sns_clkn),               // input
        .pclk                   (pclk),                   // output 27MHz
        .ipclk2x                (ipclk2x),                // output
        .ps_rdy                 (ps_rdy),                 // output
        .ps_out                 (ps_out),                 // output[7:0] 
        .locked_pxd_mmcm        (locked_pxd_mmcm),        // output
        .clkin_pxd_stopped_mmcm (clkin_pxd_stopped_mmcm), // output
        .clkfb_pxd_stopped_mmcm (clkfb_pxd_stopped_mmcm)  // output
    );

    sens_103993_din #(
        .IODELAY_GRP            (IODELAY_GRP),
        .IDELAY_VALUE           (IDELAY_VALUE),
        .REFCLK_FREQUENCY       (REFCLK_FREQUENCY),
        .HIGH_PERFORMANCE_MODE  (HIGH_PERFORMANCE_MODE),
        .NUMLANES               (NUMLANES),
        .LVDS_CAPACITANCE       (LVDS_CAPACITANCE),
        .LVDS_DIFF_TERM         (LVDS_DIFF_TERM),
        .LVDS_UNTUNED_SPLIT     (LVDS_UNTUNED_SPLIT),        
        .LVDS_DQS_BIAS          (LVDS_DQS_BIAS),
        .LVDS_IBUF_DELAY_VALUE  (LVDS_IBUF_DELAY_VALUE),
        .LVDS_IBUF_LOW_PWR      (LVDS_IBUF_LOW_PWR),
        .LVDS_IFD_DELAY_VALUE   (LVDS_IFD_DELAY_VALUE),
        .LVDS_IOSTANDARD        (LVDS_IOSTANDARD)
    ) sens_103993_din_i (
        .mclk         (mclk),        // input
        .mrst         (mrst),        // input
        .dly_data     (dly_data),    // input[31:0] 
        .set_idelay   (set_idelay),  // input[3:0] 
        .ld_idelay    (ld_idelay),   // input
        .pclk         (pclk),        // input
        .ipclk2x      (ipclk2x),     // input
        .din_p        (sns_dp),      // input[2:0] 
        .din_n        (sns_dn),      // input[2:0] 
        .dout         (sns_d)        // output[29:0] 
    );
    always @(posedge pclk) begin
        pxd_out_r <= {sns_d[19:12],sns_d[9:2]};
        vsync_r <=   sns_d[1]; // input - active high
        hsync_r <=   sns_d[11]; // input - active high
        dvalid_r <= sns_d[21]; // input - active hight
        cp_r <=         sns_d [0]; 
        perr_r <= ~ cp_r ^ (^pxd_out_r)  ^ vsync_r  ^ hsync_r ^ dvalid_r; 
    end
    
endmodule

