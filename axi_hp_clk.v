/*******************************************************************************
 * Module: axi_hp_clk
 * Date:2015-04-27  
 * Author: Andrey Filippov     
 * Description: Generate global clock for axi_hp
 *
 * Copyright (c) 2015 Elphel, Inc.
 * axi_hp_clk.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  axi_hp_clk.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  axi_hp_clk#(
    parameter CLKIN_PERIOD =        20, //ns >1.25, 600<Fvco<1200
    parameter CLKFBOUT_MULT_AXIHP = 18, // Fvco=Fclkin*CLKFBOUT_MULT_F/DIVCLK_DIVIDE, Fout=Fvco/CLKOUT#_DIVIDE
    parameter CLKFBOUT_DIV_AXIHP =  6   // To get 150MHz for the reference clock
    )(
    input   rst,
    input   clk_in,
    output  clk_axihp,
    output  locked_axihp
);
    wire  clkfb_axihp, clk_axihp_pre; 
    BUFG clk_axihp_i (.O(clk_axihp), .I(clk_axihp_pre));
    pll_base #(
        .CLKIN_PERIOD(CLKIN_PERIOD), // 20
        .BANDWIDTH("OPTIMIZED"),
        .CLKFBOUT_MULT(CLKFBOUT_MULT_AXIHP), // 18, // Fvco=Fclkin*CLKFBOUT_MULT_F/DIVCLK_DIVIDE, Fout=Fvco/CLKOUT#_DIVIDE
        .CLKOUT0_DIVIDE(CLKFBOUT_DIV_AXIHP), // 6, // To get 300MHz for the reference clock
        .REF_JITTER1(0.010),
        .STARTUP_WAIT("FALSE")
    ) pll_base_i (
        .clkin(clk_in), // input
        .clkfbin(clkfb_axihp), // input
//        .rst(rst), // input
        .rst(rst), // input
        .pwrdwn(1'b0), // input
        .clkout0(clk_axihp_pre), // output
        .clkout1(), // output
        .clkout2(), // output
        .clkout3(), // output
        .clkout4(), // output
        .clkout5(), // output
        .clkfbout(clkfb_axihp), // output
        .locked(locked_axihp) // output
    );


endmodule

