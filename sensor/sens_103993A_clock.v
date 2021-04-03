/*!
 * <b>Module:</b>sens_103993A_clock
 * @file sens_103993A_clock.v
 * @date 2020-12-16  
 * @author Andrey Filippov     
 *
 * @brief Recover iclk/iclk2x from the 103993 differntial clock
 *
 * @copyright Copyright (c) 2020 Elphel, Inc .
 *
 * <b>License:</b>
 *
 * sens_103993A_clock.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  sens_103993A_clock.v is distributed in the hope that it will be useful,
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

module  sens_103993A_clock#(
//    parameter SENS_PHASE_WIDTH=            8,      // number of bits for te phase counter (depends on divisors)
    parameter SENS_BANDWIDTH =             "OPTIMIZED",  //"OPTIMIZED", "HIGH","LOW"
    parameter CLKIN_PERIOD_SENSOR =        37.037, // input period in ns, 0..100.000 - MANDATORY, resolution down to 1 ps 1000/27.0
    parameter CLKFBOUT_MULT_SENSOR =       35, // 945 MHz //  28,      // 27 MHz --> 756 MHz
    parameter CLKFBOUT_PHASE_SENSOR =      0.000,  // CLOCK FEEDBACK phase in degrees (3 significant digits, -360.000...+360.000)
    parameter PCLK_PHASE =                 0.000,
    parameter IPCLK2X_PHASE =              0.000,
    parameter IPCLK1X_PHASE =              0.000,
    parameter BUF_PCLK =                  "BUFR",  
    parameter BUF_IPCLK2X =               "BUFR",  
    parameter BUF_IPCLK1X =               "BUFR",
    parameter BUF_CLK_FB  =               "BUFR", // was  localparam BUF_CLK_FB = BUF_IPCLK2X; 

    parameter SENS_DIVCLK_DIVIDE =         1,            // Integer 1..106. Divides all outputs with respect to CLKIN
    parameter SENS_REF_JITTER1   =         0.010,        // Expected jitter on CLKIN1 (0.000..0.999)
    parameter SENS_REF_JITTER2   =         0.010,
    parameter SENS_SS_EN         =        "FALSE",      // Enables Spread Spectrum mode
    parameter SENS_SS_MODE       =        "CENTER_HIGH",//"CENTER_HIGH","CENTER_LOW","DOWN_HIGH","DOWN_LOW"
    parameter SENS_SS_MOD_PERIOD =         10000,        // integer 4000-40000 - SS modulation period in ns
    // Used with delay
    parameter IODELAY_GRP =               "IODELAY_SENSOR", // may need different for different channels?
    parameter integer IDELAY_VALUE =      0,
    parameter real REFCLK_FREQUENCY =     200.0,
    parameter HIGH_PERFORMANCE_MODE =     "FALSE",
    
    parameter LVDS_DELAY_CLK =           "FALSE",      
    parameter LVDS_MMCM =                "TRUE",
    parameter LVDS_CAPACITANCE =         "DONT_CARE",
    parameter LVDS_DIFF_TERM =           "TRUE",
    parameter LVDS_UNTUNED_SPLIT =       "FALSE", // Very power-hungry
    parameter LVDS_DQS_BIAS =            "TRUE",
    parameter LVDS_IBUF_DELAY_VALUE =    "0",
    parameter LVDS_IBUF_LOW_PWR =        "TRUE",
    parameter LVDS_IFD_DELAY_VALUE =     "AUTO",
    parameter LVDS_IOSTANDARD =          "DIFF_SSTL18_I", //"DIFF_SSTL18_II" for high current (13.4mA vs 8mA)
    parameter DRP_ADDRESS_LENGTH =        7,
    parameter DRP_DATA_LENGTH =          16
)(
    input        mclk,
    input        mrst,
    input  [7:0] phase,
    input        set_phase,
    input        apply,      // only used when delay, not phase
    input        rst_mmcm,
    input        clp_p,
    input        clk_n,
    output       ipclk2x, // 330 MHz
    output       ipclk1x, // 165 MHz
    output       pclk,    // 27 MHz
    output       locked_pxd_mmcm,
    output       clkin_pxd_stopped_mmcm, // output
    output       clkfb_pxd_stopped_mmcm, // output
    output       for_pclk,           // @posedge ipclk1x: copy 7 bits from posedge ipclk1x to negedge ipclk1x to be copief on posedge pclk
    output       for_pclk_last,      // @posedge ipclk1x: next for_pclk will apply to last 7 bits (count 0..3) 
    input  [1:0] drp_cmd,
    output       drp_bit,
    output       drp_odd_bit 
);
localparam DELAY_FOR_PCLK = 3; // 3 ipclk1x clocks
//    localparam BUF_CLK_FB = BUF_IPCLK2X;
    wire         pclk_pre;
    wire         ipclk2x_pre;
    wire         ipclk1x_pre;
    wire         clk_fb_pre;
    wire         clk_fb;
    wire         prst = mrst;
    wire         clk_in;
    wire         clk_int;
    wire         ipclk2x_alt; // to use for nonIOB trigger
    
    // 3-reg sync chain
    reg          sync_neg_pclk;
    reg          sync_neg_ipclk2x;
    reg [DELAY_FOR_PCLK:0] sync_neg_ipclk1x;
    reg          for_pclk_r;
    
    
    assign for_pclk =       for_pclk_r;
    assign for_pclk_last = for_pclk_r & ~sync_neg_ipclk1x[DELAY_FOR_PCLK];
    generate
        if (LVDS_UNTUNED_SPLIT == "TRUE") begin
            ibufds_ibufgds_50 #(
                .CAPACITANCE      (LVDS_CAPACITANCE),
                .DIFF_TERM        (LVDS_DIFF_TERM),
                .DQS_BIAS         (LVDS_DQS_BIAS),
                .IBUF_DELAY_VALUE (LVDS_IBUF_DELAY_VALUE),
                .IBUF_LOW_PWR     (LVDS_IBUF_LOW_PWR),
                .IFD_DELAY_VALUE  (LVDS_IFD_DELAY_VALUE),
                .IOSTANDARD       (LVDS_IOSTANDARD)
            ) ibufds_ibufgds0_i (
                .O    (clk_int),      // output
                .I    (clp_p), // input
                .IB   (clk_n)  // input
            );
        // variable termination    
        end else if (LVDS_UNTUNED_SPLIT == "40") begin
            ibufds_ibufgds_40 #(
                .CAPACITANCE      (LVDS_CAPACITANCE),
                .DIFF_TERM        (LVDS_DIFF_TERM),
                .DQS_BIAS         (LVDS_DQS_BIAS),
                .IBUF_DELAY_VALUE (LVDS_IBUF_DELAY_VALUE),
                .IBUF_LOW_PWR     (LVDS_IBUF_LOW_PWR),
                .IFD_DELAY_VALUE  (LVDS_IFD_DELAY_VALUE),
                .IOSTANDARD       (LVDS_IOSTANDARD)
            ) ibufds_ibufgds0_i (
                .O    (clk_int),      // output
                .I    (clp_p), // input
                .IB   (clk_n)  // input
            );
        end else if (LVDS_UNTUNED_SPLIT == "50") begin
            ibufds_ibufgds_50 #(
                .CAPACITANCE      (LVDS_CAPACITANCE),
                .DIFF_TERM        (LVDS_DIFF_TERM),
                .DQS_BIAS         (LVDS_DQS_BIAS),
                .IBUF_DELAY_VALUE (LVDS_IBUF_DELAY_VALUE),
                .IBUF_LOW_PWR     (LVDS_IBUF_LOW_PWR),
                .IFD_DELAY_VALUE  (LVDS_IFD_DELAY_VALUE),
                .IOSTANDARD       (LVDS_IOSTANDARD)
            ) ibufds_ibufgds0_i (
                .O    (clk_int),      // output
                .I    (clp_p), // input
                .IB   (clk_n)  // input
            );
        end else if (LVDS_UNTUNED_SPLIT == "60") begin
            ibufds_ibufgds_60 #(
                .CAPACITANCE      (LVDS_CAPACITANCE),
                .DIFF_TERM        (LVDS_DIFF_TERM),
                .DQS_BIAS         (LVDS_DQS_BIAS),
                .IBUF_DELAY_VALUE (LVDS_IBUF_DELAY_VALUE),
                .IBUF_LOW_PWR     (LVDS_IBUF_LOW_PWR),
                .IFD_DELAY_VALUE  (LVDS_IFD_DELAY_VALUE),
                .IOSTANDARD       (LVDS_IOSTANDARD)
            ) ibufds_ibufgds0_i (
                .O    (clk_int),      // output
                .I    (clp_p), // input
                .IB   (clk_n)  // input
            );
        end else begin
            ibufds_ibufgds #(
                .CAPACITANCE      (LVDS_CAPACITANCE),
                .DIFF_TERM        (LVDS_DIFF_TERM),
                .DQS_BIAS         (LVDS_DQS_BIAS),
                .IBUF_DELAY_VALUE (LVDS_IBUF_DELAY_VALUE),
                .IBUF_LOW_PWR     (LVDS_IBUF_LOW_PWR),
                .IFD_DELAY_VALUE  (LVDS_IFD_DELAY_VALUE),
                .IOSTANDARD       (LVDS_IOSTANDARD)
            ) ibufds_ibufgds0_i (
                .O    (clk_int),      // output
                .I    (clp_p), // input
                .IB   (clk_n)  // input
            );
        end
    endgenerate
    generate
        if (LVDS_DELAY_CLK == "TRUE") begin // Avoid - delay output is routed using general routing resources even from the clock-capable
            idelay_nofine # (
                .IODELAY_GRP           (IODELAY_GRP),
                .DELAY_VALUE           (IDELAY_VALUE),
                .REFCLK_FREQUENCY      (REFCLK_FREQUENCY),
                .HIGH_PERFORMANCE_MODE (HIGH_PERFORMANCE_MODE)
            ) clk_dly_i(
                .clk          (mclk),
                .rst          (mrst),
                .set          (apply),
                .ld           (set_phase),
                .delay        (phase[7:3]), // skip lsb, not MSB
                .data_in      (clk_int),
                .data_out     (clk_in)
            );
        end else begin // just testing placement
            assign clk_in =  clk_int;
        end
    endgenerate

    // generate phase-shifterd pixel clock (and 2x version) from either the internal clock (that is output to the sensor) or from the clock
    // received from the sensor (may need to reset MMCM after resetting sensor)
    
    generate
        if (LVDS_MMCM == "TRUE") begin
            mmcm_drp #(
                .CLKIN_PERIOD        (CLKIN_PERIOD_SENSOR),
                .BANDWIDTH           (SENS_BANDWIDTH),
                .CLKFBOUT_MULT_F     (CLKFBOUT_MULT_SENSOR), // 28
                .DIVCLK_DIVIDE       (SENS_DIVCLK_DIVIDE),
                .CLKFBOUT_PHASE      (CLKFBOUT_PHASE_SENSOR),
                .CLKOUT0_PHASE       (PCLK_PHASE),
                .CLKOUT1_PHASE       (IPCLK2X_PHASE),
                .CLKOUT2_PHASE       (IPCLK1X_PHASE),
                .CLKFBOUT_USE_FINE_PS("FALSE"),
                .CLKOUT0_USE_FINE_PS ("FALSE"), //"TRUE"),
                .CLKOUT1_USE_FINE_PS ("FALSE"), //"TRUE"),
                .CLKOUT2_USE_FINE_PS ("FALSE"), //"TRUE"),
                .CLKOUT0_DIVIDE_F    (CLKFBOUT_MULT_SENSOR),       // /35 -> 27 MHz 
                .CLKOUT1_DIVIDE      (2*CLKFBOUT_MULT_SENSOR / 7), // /10  -> 94.5 MHz
                .CLKOUT2_DIVIDE      (4*CLKFBOUT_MULT_SENSOR / 7), // /20 -> 47.25 MHz
                .COMPENSATION        ("ZHOLD"),
                .REF_JITTER1         (SENS_REF_JITTER1),
                .REF_JITTER2         (SENS_REF_JITTER2),
                .SS_EN               (SENS_SS_EN),
                .SS_MODE             (SENS_SS_MODE),
                .SS_MOD_PERIOD       (SENS_SS_MOD_PERIOD),
                .STARTUP_WAIT        ("FALSE"),
                .DRP_ADDRESS_LENGTH  (DRP_ADDRESS_LENGTH),
                .DRP_DATA_LENGTH     (DRP_DATA_LENGTH)
                
            ) mmcm_or_pll_i (
                .clkin1              (clk_in),                 // input 27MHz
                .clkin2              (1'b0),                   // input 
                .sel_clk2            (1'b0),                   // input
                .clkfbin             (clk_fb),                 // input
                .rst                 (rst_mmcm),               // input
                .pwrdwn              (1'b0),                   // input
                .clkout0             (pclk_pre),               // output -> 27 MHz
                .clkout1             (ipclk2x_pre),            // output 135 Mhz
                .clkout2             (ipclk1x_pre),            // output 67.5 MHz
                .clkout3             (),                       // output
                .clkout4             (),                       // output
                .clkout5             (),                       // output
                .clkout6             (),                       // output
                .clkout0b            (),                       // output
                .clkout1b            (),                       // output
                .clkout2b            (),                       // output
                .clkout3b            (),                       // output
                .clkfbout            (clk_fb_pre),             // output
                .clkfboutb           (),                       // output
                .locked              (locked_pxd_mmcm),        // output
                .clkin_stopped       (clkin_pxd_stopped_mmcm), // output
                .clkfb_stopped       (clkfb_pxd_stopped_mmcm), // output
                .drp_clk             (mclk),                   // input
                .drp_cmd             (drp_cmd),                // input[1:0] 
                .drp_out_bit         (drp_bit),                // output
                .drp_out_odd_bit     (drp_odd_bit)             // output
            );
        end else begin
            pll_drp #(
                .CLKIN_PERIOD        (CLKIN_PERIOD_SENSOR),
                .BANDWIDTH           (SENS_BANDWIDTH),
                .CLKFBOUT_MULT       (CLKFBOUT_MULT_SENSOR), // 28
                .DIVCLK_DIVIDE       (SENS_DIVCLK_DIVIDE),
                .CLKFBOUT_PHASE      (CLKFBOUT_PHASE_SENSOR),
                .CLKOUT0_PHASE       (PCLK_PHASE),
                .CLKOUT1_PHASE       (IPCLK2X_PHASE),
                .CLKOUT2_PHASE       (IPCLK1X_PHASE),
                .CLKOUT0_DIVIDE      (CLKFBOUT_MULT_SENSOR),       // /28 -> 27 MHz 
                .CLKOUT1_DIVIDE      (2*CLKFBOUT_MULT_SENSOR / 7), // /8  -> 94.5 MHz
                .CLKOUT2_DIVIDE      (4*CLKFBOUT_MULT_SENSOR / 7), // /16 -> 47.25 MHz
                .REF_JITTER1         (SENS_REF_JITTER1),
                .STARTUP_WAIT        ("FALSE"),
                .DRP_ADDRESS_LENGTH  (DRP_ADDRESS_LENGTH),
                .DRP_DATA_LENGTH     (DRP_DATA_LENGTH)
            ) mmcm_or_pll_i (
                .clkin               (clk_in),          // input
                .clkfbin             (clk_fb),          // input
                .rst                 (rst_mmcm),        // input
                .pwrdwn              (1'b0),            // input
                .clkout0             (pclk_pre),        // output -> 27MHz
                .clkout1             (ipclk2x_pre),     // output 135 Mhz
                .clkout2             (ipclk1x_pre),     // output 67.5 MHz
                .clkout3             (),                // output
                .clkout4             (),                // output
                .clkout5             (),                // output
                .clkfbout            (clk_fb_pre),      // output
                .locked              (locked_pxd_mmcm), // output
                .drp_clk             (mclk),            // input
                .drp_cmd             (drp_cmd),         // input[1:0] 
                .drp_out_bit         (drp_bit),         // output
                .drp_out_odd_bit     (drp_odd_bit)      // output
            );
            assign clkin_pxd_stopped_mmcm = 0;
            assign clkfb_pxd_stopped_mmcm = 0;
        end
    endgenerate
    
    generate
        if      (BUF_CLK_FB == "BUFG")  BUFG  clk2x_i (.O(clk_fb), .I(clk_fb_pre));
        else if (BUF_CLK_FB == "BUFH")  BUFH  clk2x_i (.O(clk_fb), .I(clk_fb_pre));
        else if (BUF_CLK_FB == "BUFR")  BUFR  clk2x_i (.O(clk_fb), .I(clk_fb_pre), .CE(1'b1), .CLR(prst));
        else if (BUF_CLK_FB == "BUFMR") BUFMR clk2x_i (.O(clk_fb), .I(clk_fb_pre));
        else if (BUF_CLK_FB == "BUFIO") BUFIO clk2x_i (.O(clk_fb), .I(clk_fb_pre));
        else assign clk_fb = clk_fb_pre;
    endgenerate

    generate
        if      (BUF_IPCLK2X == "BUFG")  BUFG  clk2x_i (.O(ipclk2x), .I(ipclk2x_pre));
        else if (BUF_IPCLK2X == "BUFH")  BUFH  clk2x_i (.O(ipclk2x), .I(ipclk2x_pre));
        else if (BUF_IPCLK2X == "BUFR")  BUFR  clk2x_i (.O(ipclk2x), .I(ipclk2x_pre), .CE(1'b1), .CLR(prst));
        else if (BUF_IPCLK2X == "BUFIO") BUFIO clk2x_i (.O(ipclk2x), .I(ipclk2x_pre));
        else if (BUF_IPCLK2X == "BUFMR") begin
          wire ipclk2xr_pre2;
          BUFMR clk2x2_i  (.O(ipclk2xr_pre2), .I(ipclk2x_pre));
          BUFR  clk2x_i   (.O(ipclk2x),      .I(ipclk2xr_pre2), .CE(1'b1), .CLR(prst));
        end else if (BUF_IPCLK2X == "BUFMIO") begin
          wire ipclk2x_pre2;
          BUFMR clk2x2_i (.O(ipclk2x_pre2), .I(ipclk2x_pre));
          BUFIO clk2x_i  (.O(ipclk2x),      .I(ipclk2x_pre2));
        end else assign ipclk2x = ipclk2x_pre;
        
        if (BUF_IPCLK2X == "BUFIO") begin
            BUFH clk2x_alt_i (.O(ipclk2x_alt), .I(ipclk2x_pre));
        end else begin
            assign ipclk2x_alt = ipclk2x;
        end    
        
    endgenerate

    generate
        if      (BUF_IPCLK1X == "BUFG")  BUFG  clk1x_i (.O(ipclk1x), .I(ipclk1x_pre));
        else if (BUF_IPCLK1X == "BUFH")  BUFH  clk1x_i (.O(ipclk1x), .I(ipclk1x_pre));
        else if (BUF_IPCLK1X == "BUFR")  BUFR  clk1x_i (.O(ipclk1x), .I(ipclk1x_pre), .CE(1'b1), .CLR(prst));
        else if (BUF_IPCLK1X == "BUFIO") BUFIO clk1x_i (.O(ipclk1x), .I(ipclk1x_pre));
        else if (BUF_IPCLK2X == "BUFMR") begin
          wire ipclk1xr_pre2;
          BUFMR clk1x2_i (.O(ipclk1xr_pre2), .I(ipclk1x_pre));
          BUFR  clk1x_i  (.O(ipclk1x),       .I(ipclk1xr_pre2), .CE(1'b1), .CLR(prst));
        end else if (BUF_IPCLK2X == "BUFMIO") begin
          wire ipclk1x_pre2;
          BUFMR clk1x2_i (.O(ipclk1x_pre2), .I(ipclk1x_pre));
          BUFIO clk1x_i  (.O(ipclk1x),      .I(ipclk1x_pre2));
        end else assign ipclk1x = ipclk1x_pre;
    endgenerate

    generate
        if      (BUF_PCLK == "BUFG")  BUFG  clk2x_i (.O(pclk), .I(pclk_pre));
        else if (BUF_PCLK == "BUFH")  BUFH  clk2x_i (.O(pclk), .I(pclk_pre));
        else if (BUF_PCLK == "BUFR")  BUFR  clk2x_i (.O(pclk), .I(pclk_pre), .CE(1'b1), .CLR(prst));
        else if (BUF_PCLK == "BUFIO") BUFIO clk2x_i (.O(pclk), .I(pclk_pre));
        else if (BUF_PCLK == "BUFMR") BUFMR clk2x_i (.O(pclk), .I(pclk_pre));
        else assign pclk = pclk_pre;
    endgenerate



    always @(negedge pclk or posedge sync_neg_ipclk1x[0]) begin
        if (sync_neg_ipclk1x[0]) sync_neg_pclk <= 0;
        else                     sync_neg_pclk <= locked_pxd_mmcm; // !prst;
    end
    
    always @(negedge ipclk2x_alt) begin
        sync_neg_ipclk2x <= sync_neg_pclk; 
    end
    
    always @ (negedge ipclk1x) begin
       sync_neg_ipclk1x <= { sync_neg_ipclk1x[DELAY_FOR_PCLK-1:0], locked_pxd_mmcm & sync_neg_ipclk2x};
       for_pclk_r <= ~sync_neg_ipclk1x[DELAY_FOR_PCLK];
    end

endmodule

