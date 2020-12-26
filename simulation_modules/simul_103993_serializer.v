/*!
 * <b>Module:</b> simul_103993_serializer
 * @file simul_103993_serializer.v
 * @date 2020-12-23  
 * @author eyesis
 *     
 * @brief Serializer for Boson640 output based on SN65LVDS301
 *
 * @copyright Copyright (c) 2020 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 *
 * <b>License </b>
 *
 * simul_103993_serializer.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * simul_103993_serializer.v is distributed in the hope that it will be useful,
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

module  simul_103993_serializer#(
    parameter PCLK_FREQ_MHZ = 27.0
)(
    input  [7:0] red,
    input  [7:0] green,
    input  [7:0] blue,
    input        hs,
    input        vs,
    input        de,
    input        pclk,
    output [2:0] dp,
    output [2:0] dn,
    output       clkp,
    output       clkn
);
    localparam PERIOD = 1000.0/PCLK_FREQ_MHZ; 
    wire   [9:0] dclocks;
    
    
    assign #(PERIOD/20) dclocks[9:0] = ~{dclocks[8:0], pclk};
    /*
    assign #(PERIOD/20) dclocks[0] = pclk;
    assign #(PERIOD/20) dclocks[1] = dclocks[0];
    assign #(PERIOD/20) dclocks[2] = dclocks[1];
    assign #(PERIOD/20) dclocks[3] = dclocks[2];
    assign #(PERIOD/20) dclocks[4] = dclocks[3];
    assign #(PERIOD/20) dclocks[5] = dclocks[4];
    assign #(PERIOD/20) dclocks[6] = dclocks[5];
    assign #(PERIOD/20) dclocks[7] = dclocks[6];
    assign #(PERIOD/20) dclocks[8] = dclocks[7];
    assign #(PERIOD/20) dclocks[9] = dclocks[8];
    */
    wire clk10 = ^dclocks[9:0];
    reg [9:0] r_red;
    reg [9:0] r_green;
    reg [9:0] r_blue;
    reg [9:0] sr_red;
    reg [9:0] sr_green;
    reg [9:0] sr_blue;
    reg [9:0] sr_clk;
    reg [1:0] clk_r;
    reg       set_sr;
    wire      cp = (^red) ^ (^green) ^ (^blue) ^ vs ^ hs ^ de;
    assign dp =    {sr_blue[9],sr_green[9], sr_red[9]};
    assign dn =   ~{sr_blue[9],sr_green[9], sr_red[9]};
    assign clkp =  sr_clk [9];
    assign clkn = ~sr_clk [9];
    always @ (posedge pclk) begin
        r_red <=   {red,   vs, cp};
        r_green <= {green, hs, 1'b0};
        r_blue <=  {blue,  de, 1'b0};
    end
    
    always @ (posedge clk10) begin
        clk_r <= {clk_r[0], pclk};
        set_sr <= clk_r[0] && !clk_r[0];
        if (set_sr) begin
            sr_red <=   r_red;
            sr_green <= r_green;
            sr_blue <=  r_blue;
            sr_clk <=   10'b1111100000;
        end else begin
            sr_red <=    {sr_red[8:0],   1'b0};   
            sr_green <=  {sr_green[8:0], 1'b0};   
            sr_blue <=   {sr_blue[8:0],  1'b0};   
            sr_clk <=    {sr_clk[8:0],   1'b0};   
        end
    end

endmodule

