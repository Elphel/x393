/*!
 * <b>Module:</b> sens_103993A_lanes
 * @file sens_103993A_lanes.v
 * @date 2021-03-26  
 * @author eyesis
 *     
 * @brief 3-lane deserializer for Boson640
 *
 * @copyright Copyright (c) 2021 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 *
 * <b>License </b>
 *
 * sens_103993A_lanes.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * sens_103993A_lanes.v is distributed in the hope that it will be useful,
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

module  sens_103993A_lanes #(
    parameter IODELAY_GRP =               "IODELAY_SENSOR",
    parameter integer IDELAY_VALUE =       0,
    parameter real REFCLK_FREQUENCY =      200.0,
    parameter HIGH_PERFORMANCE_MODE =     "FALSE",
//    parameter SENS_PHASE_WIDTH=            8,      // number of bits for te phase counter (depends on divisors)
    parameter SENS_BANDWIDTH =             "OPTIMIZED",  //"OPTIMIZED", "HIGH","LOW"

    parameter CLKIN_PERIOD_SENSOR =        37.037, // input period in ns, 0..100.000 - MANDATORY, resolution down to 1 ps
    parameter CLKFBOUT_MULT_SENSOR =       35, // 945 MHz 28,      // 27 MHz --> 756 MHz
    parameter CLKFBOUT_PHASE_SENSOR =      0.000,  // CLOCK FEEDBACK phase in degrees (3 significant digits, -360.000...+360.000)
    parameter PCLK_PHASE =                 0.000,
    parameter IPCLK2X_PHASE =              0.000,
    parameter IPCLK1X_PHASE =              0.000, /// new
    parameter BUF_PCLK =                  "BUFR",  
    parameter BUF_IPCLK2X =               "BUFR",  
    parameter BUF_IPCLK1X =               "BUFR", /// new  
    parameter BUF_CLK_FB =                "BUFR", /// new  
    parameter SENS_DIVCLK_DIVIDE =         1,            // Integer 1..106. Divides all outputs with respect to CLKIN
    parameter SENS_REF_JITTER1   =         0.010,        // Expected jitter on CLKIN1 (0.000..0.999)
    parameter SENS_REF_JITTER2   =         0.010,
    parameter SENS_SS_EN         =        "FALSE",      // Enables Spread Spectrum mode
    parameter SENS_SS_MODE       =        "CENTER_HIGH",//"CENTER_HIGH","CENTER_LOW","DOWN_HIGH","DOWN_LOW"
    parameter SENS_SS_MOD_PERIOD =         10000,        // integer 4000-40000 - SS modulation period in ns

    parameter NUMLANES =                   4,
    parameter LVDS_DELAY_CLK =            "FALSE",      
    parameter LVDS_MMCM =                 "TRUE",
    parameter LVDS_CAPACITANCE =          "DONT_CARE",
    parameter LVDS_DIFF_TERM =            "TRUE",
    parameter LVDS_UNTUNED_SPLIT =        "FALSE", // Very power-hungry
    parameter LVDS_DQS_BIAS =             "TRUE",
    parameter LVDS_IBUF_DELAY_VALUE =     "0",
    parameter LVDS_IBUF_LOW_PWR =         "TRUE",
    parameter LVDS_IFD_DELAY_VALUE =      "AUTO",
    parameter LVDS_IOSTANDARD =           "DIFF_SSTL18_I", //"DIFF_SSTL18_II" for high current (13.4mA vs 8mA),
    parameter DEGLITCH_DVALID =           1,
    parameter DEGLITCH_HSYNC =            3,
    parameter DEGLITCH_VSYNC =            7
)(
    output                         pclk,   // global clock input, pixel rate (27MHz for 103993) (220MHz for MT9F002)
    input                          prsts,
    // I/O pads
    input           [NUMLANES-1:0] sns_dp,
    input           [NUMLANES-1:0] sns_dn,
    input                          sns_clkp,
    input                          sns_clkn,
    // output
    output                  [15:0] pxd_out, 
    output                         vsync, 
    output                         hsync,
    output                         dvalid,
    // delay control inputs
    input                          mclk,
    input                          mrst,
    input       [NUMLANES * 8-1:0] dly_data,        // delay value (3 LSB - fine delay) - @posedge mclk
    input           [NUMLANES-1:0] set_idelay,      // mclk synchronous load idelay value
    input                          apply_idelay,       // mclk synchronous set idelay value
    input                          set_clk_phase,   // mclk synchronous set idelay value
    input                          rst_mmcm,
    // MMCP output status
    output                         perr,            // parity error
    output                   [7:0] test_out,
    output                         locked_pxd_mmcm,
    output                         clkin_pxd_stopped_mmcm, // output
    output                         clkfb_pxd_stopped_mmcm, // output
    input                    [1:0] drp_cmd,
    output                         drp_bit,
    output                         drp_odd_bit 
);
/*
   Lanes     bits:   6   5   4   3   2   1   0   
            0 (TA)   1   0   d4  d3  d2  d1  d0   sns_d[ 6: 0]
            1 (TB)   1   0   d9  d8  d7  d6  d5   sns_d[13: 7]
            2 (TC)   1   0   d14 d13 d12 d11 d10  sns_d[20:14]
            3 (TD)   1   0   0   de  vs  hs  d15  sns_d[27:21]
            
            0 (TA)   6   5   4   3   2   1   0    sns_d[ 6: 0]
            1 (TB)  13  12  11  10   9   8   7    sns_d[13: 7]
            2 (TC)  20  19  18  17  16  15  14    sns_d[20:14]
            3 (TD)  27  26  25  24  23  22  21    sns_d[27:21]
            
            
        perr_r <= ~sns_d[27] | sns_d[26] | sns_d[25] | ~sns_d[20] | sns_d[19] | ~sns_d[13] | sns_d[12] | ~sns_d[6] | sns_d[5];  
            
*/

    wire  [NUMLANES * 7-1:0] sns_d;
    wire                     ipclk2x;// re-generated clock (135 MHz)
    wire                     ipclk1x;// re-generated clock (67.5 MHz)
    reg               [15:0] pxd_out_r; 
    reg               [15:0] pxd_out_r2; 
    reg                      perr_r;
    wire              [15:0] pxd_w;
    wire                     for_pclk;
    wire                     for_pclk_last;
    
    assign pxd_out =    (DEGLITCH_DVALID == 0) ? pxd_out_r:  pxd_out_r2;
    assign perr =       perr_r;
    assign test_out =   {sns_d[27:26],sns_d[20:19],sns_d[13:12],sns_d[6:5]}; // should be 8'haa
    assign pxd_w =      {sns_d[21],sns_d[18:14],sns_d[11:7],sns_d[4:0]};
   
    sens_103993A_clock #(
        .SENS_BANDWIDTH         (SENS_BANDWIDTH),
        .CLKIN_PERIOD_SENSOR    (CLKIN_PERIOD_SENSOR),
        .CLKFBOUT_MULT_SENSOR   (CLKFBOUT_MULT_SENSOR),
        .CLKFBOUT_PHASE_SENSOR  (CLKFBOUT_PHASE_SENSOR),
        .PCLK_PHASE             (PCLK_PHASE),
        .IPCLK2X_PHASE          (IPCLK2X_PHASE),
        .IPCLK1X_PHASE          (IPCLK1X_PHASE),
        .BUF_PCLK               (BUF_PCLK),
        .BUF_IPCLK2X            (BUF_IPCLK2X),
        .BUF_IPCLK1X            (BUF_IPCLK1X),
        .BUF_CLK_FB             (BUF_CLK_FB),
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
        .LVDS_UNTUNED_SPLIT     (LVDS_UNTUNED_SPLIT),
        .LVDS_DQS_BIAS          (LVDS_DQS_BIAS),
        .LVDS_IBUF_DELAY_VALUE  (LVDS_IBUF_DELAY_VALUE),
        .LVDS_IBUF_LOW_PWR      (LVDS_IBUF_LOW_PWR),
        .LVDS_IFD_DELAY_VALUE   (LVDS_IFD_DELAY_VALUE),
        .LVDS_IOSTANDARD        (LVDS_IOSTANDARD)
        
    ) sens_103993_clock_i ( // same instance name as in sens_103993_l3
        .mclk                   (mclk),                   // input
        .mrst                   (mrst),                   // input
        .phase                  (dly_data[7:0]),          // input[7:0] 
        .set_phase              (set_clk_phase),          // input
        .apply                  (apply_idelay),           // input
        .rst_mmcm               (rst_mmcm),               // input
        .clp_p                  (sns_clkp),               // input
        .clk_n                  (sns_clkn),               // input
        .ipclk2x                (ipclk2x),                // output
        .ipclk1x                (ipclk1x),                // output
        .pclk                   (pclk),                   // output 27MHz
        .locked_pxd_mmcm        (locked_pxd_mmcm),        // output
        .clkin_pxd_stopped_mmcm (clkin_pxd_stopped_mmcm), // output
        .clkfb_pxd_stopped_mmcm (clkfb_pxd_stopped_mmcm), // output
        .for_pclk               (for_pclk),               // output
        .for_pclk_last          (for_pclk_last),         // output
        .drp_cmd                (drp_cmd),                // input[1:0] 
        .drp_bit                (drp_bit),                // output
        .drp_odd_bit            (drp_odd_bit)             // output
    );
    
    generate
        genvar i;
        for (i=0; i < NUMLANES; i=i+1) begin: lane_block
            sens_103993A_lane #(
                .IODELAY_GRP            (IODELAY_GRP),
                .IDELAY_VALUE           (IDELAY_VALUE),
                .REFCLK_FREQUENCY       (REFCLK_FREQUENCY),
                .HIGH_PERFORMANCE_MODE  (HIGH_PERFORMANCE_MODE),
                .LVDS_CAPACITANCE       (LVDS_CAPACITANCE),       // "DONT_CARE"),
                .LVDS_DIFF_TERM         (LVDS_DIFF_TERM),         // "TRUE"),
                .LVDS_UNTUNED_SPLIT     (LVDS_UNTUNED_SPLIT),     // "FALSE"),
                .LVDS_DQS_BIAS          (LVDS_DQS_BIAS),          // "TRUE"),
                .LVDS_IBUF_DELAY_VALUE  (LVDS_IBUF_DELAY_VALUE),  // "0"),
                .LVDS_IBUF_LOW_PWR      (LVDS_IBUF_LOW_PWR),      // "TRUE"),
                .LVDS_IFD_DELAY_VALUE   (LVDS_IFD_DELAY_VALUE),   // "AUTO"),
                .LVDS_IOSTANDARD        (LVDS_IOSTANDARD)         // "DIFF_SSTL18_I")
            ) sens_103993_lane_i (
                .mclk           (mclk),                   // input
                .mrst           (mrst),                   // input
//                .dly_data       (dly_data[7 + 8*i +: 8]), // input[7:0] dly_data[3 + 8*i +: 5
                .dly_data       (dly_data[8*i +: 8]), // input[7:0] dly_data[3 + 8*i +: 5
                .ld_idelay      (set_idelay[i]),          // input
                .apply_idelay   (apply_idelay),           // input
                .pclk           (pclk),                   // input
                .ipclk2x        (ipclk2x),                // input
                .ipclk1x        (ipclk1x),                // input
                .rst            (mrst),                   // input
                .for_pclk       (for_pclk),               // input
                .for_pclk_last  (for_pclk_last),          // input
                .din_p          (sns_dp[i]),              // input
                .din_n          (sns_dn[i]),              // input
                .dout           (sns_d[7*i +: 7])         // output[6:0] 
            );
        end
    endgenerate    

     always @(posedge pclk) begin
        pxd_out_r  <= pxd_w;
        pxd_out_r2 <= pxd_out_r;
        perr_r <= ~sns_d[27] | sns_d[26] | sns_d[25] | ~sns_d[20] | sns_d[19] | ~sns_d[13] | sns_d[12] | ~sns_d[6] | sns_d[5];  
    end

    deglitch #(
        .CLOCKS(DEGLITCH_DVALID)
    ) deglitch_dvalid_i (
        .clk(pclk),    // input
        .rst(prsts),   // input
        .d(sns_d[24]), // input
        .q(dvalid)     // output
    );

    deglitch #(
        .CLOCKS(DEGLITCH_HSYNC)
    ) deglitch_hsync_i (
        .clk(pclk),    // input
        .rst(prsts),   // input
        .d(sns_d[22]), // input
        .q(hsync)      // output
    );
    
    deglitch #(
        .CLOCKS(DEGLITCH_VSYNC)
    ) deglitch_vsync_i (
        .clk(pclk),    // input
        .rst(prsts),   // input
        .d(sns_d[23]),  // input
        .q(vsync)      // output
    );
    
    
    


endmodule

