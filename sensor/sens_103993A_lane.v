/*!
 * <b>Module:</b> sens_103993A_lane
 * @file sens_103993A_lane.v
 * @date 2021-03-26  
 * @author eyesis
 *     
 * @brief 
 *
 * @copyright Copyright (c) 2021 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 *
 * <b>License </b>
 *
 * sens_103993A_lane.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * sens_103993A_lane.v is distributed in the hope that it will be useful,
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

module  sens_103993A_lane#(
    parameter IODELAY_GRP =             "IODELAY_SENSOR", // may need different for different channels?
    parameter integer IDELAY_VALUE =     0,
    parameter real REFCLK_FREQUENCY =    200.0,
    parameter HIGH_PERFORMANCE_MODE =   "FALSE",

//    parameter NUMLANES =                 3,
    parameter LVDS_CAPACITANCE =        "DONT_CARE",
    parameter LVDS_DIFF_TERM =          "TRUE",
    parameter LVDS_UNTUNED_SPLIT =      "FALSE", // Very power-hungry
    parameter LVDS_DQS_BIAS =           "TRUE",
    parameter LVDS_IBUF_DELAY_VALUE =   "0",
    parameter LVDS_IBUF_LOW_PWR =       "TRUE",
    parameter LVDS_IFD_DELAY_VALUE =    "AUTO",
    parameter LVDS_IOSTANDARD =         "DIFF_SSTL18_I" //"DIFF_SSTL18_II" for high current (13.4mA vs 8mA)
)(
    input                 mclk,
    input                 mrst,
    input           [7:0] dly_data,       // delay value (3 LSB - fine delay) - @posedge mclk
    input                 ld_idelay,      // mclk synchronous load idelay value
    input                 apply_idelay,   // mclk synchronous set idealy value
    input                 pclk,           // 27 MHz
    input                 ipclk2x,        // 135 MHz
    input                 ipclk1x,        // 67.5 MHz
    input                 rst,            // reset//  @posedge iclk
    input                 for_pclk,       // @posedge ipclk1x copy 10 bits form ipclk1x domain to pclk (alternating 2/3 iplck1x intervals)
    input                 for_pclk_last,  // @posedge ipclk1x: next for_pclk will apply to last 7 bits (count 0..3)  
    input                 din_p,
    input                 din_n,
    output          [6:0] dout);
    
    wire                  din;
    wire                  din_dly;
    wire            [9:0] deser_w; // deserializer 4-bit output and previous values
    reg             [5:0] deser_r;
    
    reg             [6:0] dout_r;
    reg             [6:0] pre_dout_r;
    reg             [3:0] bshift; // one-hot shift of the data output
    
    assign dout=dout_r;
    assign deser_w[9:4] = deser_r[5:0];      
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
                .O    (din),   // output
                .I    (din_p), // input
                .IB   (din_n)  // input
            );
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
                .O    (din),   // output
                .I    (din_p), // input
                .IB   (din_n)  // input
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
                .O    (din),   // output
                .I    (din_p), // input
                .IB   (din_n)  // inputpre_dout_r
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
                .O    (din),   // output
                .I    (din_p), // input
                .IB   (din_n)  // input
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
                .O    (din),   // output
                .I    (din_p), // input
                .IB   (din_n)  // input
            );
        end
    endgenerate

    idelay_nofine # (
        .IODELAY_GRP           (IODELAY_GRP),
        .DELAY_VALUE           (IDELAY_VALUE),
        .REFCLK_FREQUENCY      (REFCLK_FREQUENCY),
        .HIGH_PERFORMANCE_MODE (HIGH_PERFORMANCE_MODE)
    ) pxd_dly_i(
        .clk          (mclk),
        .rst          (mrst),
        .set          (apply_idelay),
        .ld           (ld_idelay),
        .delay        (dly_data[7:3]),
        .data_in      (din),
        .data_out     (din_dly)
    );
        
    iserdes_mem #(
        .DYN_CLKDIV_INV_EN ("FALSE"),
        .MSB_FIRST         (1)          // MSB is received first
    ) iserdes_pxd_i (
        .iclk         (ipclk2x),       // source-synchronous clock
        .oclk         (ipclk2x),       // system clock, phase should allow iclk-to-oclk jitter with setup/hold margin
        .oclk_div     (ipclk1x),       // oclk divided by 2, front aligned
        .inv_clk_div  (1'b0),          // invert oclk_div (this clock is shared between iserdes and oserdes. Works only in MEMORY_DDR3 mode?
        .rst          (rst),           // reset
        .d_direct     (1'b0),          // direct input from IOB, normally not used, controlled by IOBDELAY parameter (set to "NONE")
        .ddly         (din_dly),       // serial input from idelay 
        .dout         (deser_w[3:0]),  // parallel data out
        .comb_out()                    // output
    );

    always @ (negedge ipclk1x) begin
        deser_r <= {deser_r[1:0],deser_w[3:0]};
    end
       
    always @ (negedge ipclk1x) begin
        if (for_pclk) bshift <=  for_pclk_last ? 4'b0001 : {bshift[2:0],1'b0};
        if (for_pclk) pre_dout_r <=
            ({7{bshift[0]}} & deser_w[6:0]) | 
            ({7{bshift[1]}} & deser_w[7:1]) | 
            ({7{bshift[2]}} & deser_w[8:2]) | 
            ({7{bshift[3]}} & deser_w[9:3]); 
    end
    
    always @ (posedge pclk) begin
        dout_r <= pre_dout_r;
    end




endmodule

