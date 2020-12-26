/*!
 * <b>Module:</b>sens_103993_din
 * @file sens_hispi_din.v
 * @date 2020-12-16  
 * @author Andrey Filippov     
 *
 * @brief Input differential receivers for HiSPi lanes
 *
 * @copyright Copyright (c) 2015 Elphel, Inc .
 *
 * <b>License:</b>
 *
 * sens_103993_din.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  sens_103993_din.v is distributed in the hope that it will be useful,
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

module  sens_103993_din #(
    parameter IODELAY_GRP =             "IODELAY_SENSOR", // may need different for different channels?
    parameter integer IDELAY_VALUE =     0,
    parameter real REFCLK_FREQUENCY =    200.0,
    parameter HIGH_PERFORMANCE_MODE =   "FALSE",

    parameter NUMLANES =                 3,
    parameter LVDS_CAPACITANCE =        "DONT_CARE",
    parameter LVDS_DIFF_TERM =          "TRUE",
    parameter LVDS_UNTUNED_SPLIT =      "FALSE", // Very power-hungry
    parameter LVDS_DQS_BIAS =           "TRUE",
    parameter LVDS_IBUF_DELAY_VALUE =   "0",
    parameter LVDS_IBUF_LOW_PWR =       "TRUE",
    parameter LVDS_IFD_DELAY_VALUE =    "AUTO",
    parameter LVDS_IOSTANDARD =         "DIFF_SSTL18_I" //"DIFF_SSTL18_II" for high current (13.4mA vs 8mA)
)(
    input                           mclk,
    input                           mrst,
    input  [NUMLANES * 8-1:0] dly_data,     // delay value (3 LSB - fine delay) - @posedge mclk
    input      [NUMLANES-1:0] set_idelay,   // mclk synchronous load idelay value
    input                           ld_idelay,    // mclk synchronous set idealy value
    input                           pclk,    // 27 MHz
//    input                           ipclk,   // 165 MHz
    input                           ipclk2x, // 330 MHz
//    input                           irst,    // reset @posedge iclk
    input      [NUMLANES-1:0] din_p,
    input      [NUMLANES-1:0] din_n,
    output [NUMLANES * 10-1:0] dout

);
    wire   [NUMLANES-1:0] din;
    wire   [NUMLANES-1:0] din_dly;

    generate
        genvar i;
        for (i=0; i < NUMLANES; i=i+1) begin: din_block
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
                    .O    (din[i]),   // output
                    .I    (din_p[i]), // input
                    .IB   (din_n[i])  // input
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
                    .O    (din[i]),   // output
                    .I    (din_p[i]), // input
                    .IB   (din_n[i])  // input
                );
            end

            idelay_nofine # (
                .IODELAY_GRP           (IODELAY_GRP),
                .DELAY_VALUE           (IDELAY_VALUE),
                .REFCLK_FREQUENCY      (REFCLK_FREQUENCY),
                .HIGH_PERFORMANCE_MODE (HIGH_PERFORMANCE_MODE)
            ) pxd_dly_i(
                .clk          (mclk),
                .rst          (mrst),
                .set          (set_idelay[i]),
                .ld           (ld_idelay),
                .delay        (dly_data[3 + 8*i +: 5]),
                .data_in      (din[i]),
                .data_out     (din_dly[i])
            );
            
            
            sens_103993_deser10 sens_103993_deser10_i (
                .pclk10       (ipclk2x), // input
                .pclk         (pclk), // input
                .din          (din_dly[i]), // input
                .dout         (dout[10*i +: 10]) // output[9:0] 
            );
        
        end
    endgenerate


endmodule

