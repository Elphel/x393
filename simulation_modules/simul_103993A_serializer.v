/*!
 * <b>Module:</b> simul_103993A_serializer
 * @file simul_103993A_serializer.v
 * @date 2020-12-23  
 * @author eyesis
 *     
 * @brief Serializer for Boson640 output based on SN65LVDS301
 *
 * @copyright Copyright (c) 2020 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 *
 * <b>License </b>
 *
 * simul_103993A_serializer.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * simul_103993A_serializer.v is distributed in the hope that it will be useful,
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

module  simul_103993A_serializer#(
    parameter PCLK_FREQ_MHZ = 27.0
)(
    input  [6:0] ta,
    input  [6:0] tb,
    input  [6:0] tc,
    input  [6:0] td,
    input        pclk,
    output [3:0] dp,
    output [3:0] dn,
    output       clkp,
    output       clkn
);
    localparam PERIOD = 1000.0/PCLK_FREQ_MHZ; 
    wire   [13:0] dclocks;
    
    assign #(PERIOD/14) dclocks[ 0] = pclk;
    assign #(PERIOD/14) dclocks[ 1] = dclocks[ 0];
    assign #(PERIOD/14) dclocks[ 2] = dclocks[ 1];
    assign #(PERIOD/14) dclocks[ 3] = dclocks[ 2];
    assign #(PERIOD/14) dclocks[ 4] = dclocks[ 3];
    assign #(PERIOD/14) dclocks[ 5] = dclocks[ 4];
    assign #(PERIOD/14) dclocks[ 6] = dclocks[ 5];
    assign #(PERIOD/14) dclocks[ 6] = dclocks[ 5];
    assign #(PERIOD/14) dclocks[ 7] = dclocks[ 6];
    assign #(PERIOD/14) dclocks[ 8] = dclocks[ 7];
    assign #(PERIOD/14) dclocks[ 9] = dclocks[ 8];
    assign #(PERIOD/14) dclocks[10] = dclocks[ 9];
    assign #(PERIOD/14) dclocks[11] = dclocks[10];
    assign #(PERIOD/14) dclocks[12] = dclocks[11];
    assign #(PERIOD/14) dclocks[13] = dclocks[12];
    
    wire clk7 = (~dclocks[ 1] & dclocks[ 0]) |
                (~dclocks[ 3] & dclocks[ 2]) |
                (~dclocks[ 5] & dclocks[ 4]) |
                (~dclocks[ 7] & dclocks[ 6]) |
                (~dclocks[ 9] & dclocks[ 8]) |
                (~dclocks[11] & dclocks[10]) |
                (~dclocks[13] & dclocks[12]);
    
    reg [6:0] r_ta;
    reg [6:0] r_tb;
    reg [6:0] r_tc;
    reg [6:0] r_td;
    reg [6:0] sr_ta;
    reg [6:0] sr_tb;
    reg [6:0] sr_tc;
    reg [6:0] sr_td;
    reg [6:0] sr_clk;
    reg [1:0] clk_r;
    reg       set_sr;
    assign dp =    {sr_td[6], sr_tc[6],  sr_tb[6], sr_ta[6]};
    assign dn =   ~{sr_td[6], sr_tc[6],  sr_tb[6], sr_ta[6]};

    assign clkp =  sr_clk [6];
    assign clkn = ~sr_clk [6];
    
    always @ (posedge pclk) begin
        r_ta <= ta;
        r_tb <= tb;
        r_tc <= tc;
        r_td <= td;
    end

    always @ (posedge clk7) begin
        clk_r <= {clk_r[0], pclk};
        set_sr <= clk_r[0] && !clk_r[1];
        if (set_sr) begin
            sr_ta <=    r_ta;
            sr_tb <=    r_tb;
            sr_tc <=    r_tc;
            sr_td <=    r_td;
            sr_clk <=   7'b1100011;
        end else begin
            sr_ta <=     {sr_ta[5:0],   1'b0};   
            sr_tb <=     {sr_tb[5:0],   1'b0};   
            sr_tc <=     {sr_tc[5:0],   1'b0};   
            sr_td <=     {sr_td[5:0],   1'b0};   
            sr_clk <=    {sr_clk[5:0],  1'b0};   
        end
    end

endmodule

