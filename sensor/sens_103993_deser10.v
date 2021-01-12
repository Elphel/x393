/*!
 * <b>Module:</b> sens_103993_deser10
 * @file sens_103993_deser10.v
 * @date 2020-12-16  
 * @author eyesis
 *     
 * @brief 10:1 deserializer for 103993 (270MHz->27MHz)
 *
 * @copyright Copyright (c) 2020 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 *
 * <b>License </b>
 *
 * sens_103993_deser10.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * sens_103993_deser10.v is distributed in the hope that it will be useful,
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

module  sens_103993_deser10(
    input pclk10,
    input pclk,
    input din,
    output [9:0] dout
);
//    reg [9:0] sr;
    reg [9:0] dout_r;
//    wire [9:0] pre_sr;
    assign dout = dout_r;
    /*
    assign pre_sr = {sr[8:0], din};
    always @(posedge pclk10) begin
        sr <= pre_sr;
    end
    always @(posedge pclk) begin
        dout_r <= pre_sr;
    end
    */
    reg        xclk_r;
    reg  [2:0] copy_r;
    reg [11:0] sr;
    reg [ 9:0] dout_pclk10;
    always @(posedge pclk or posedge copy_r[2]) begin  // re_simulate!
        if (copy_r[2]) xclk_r <= 0;
        else           xclk_r <= 1;
    end
    
    always @ (negedge pclk10) begin
        copy_r <= {copy_r[1] & ~copy_r[0], copy_r[0], xclk_r};
        sr <=     {sr[10:0], din};
        if (copy_r[2]) dout_pclk10 <= sr[11:2];
    end

    always @(posedge pclk) begin
        dout_r <= dout_pclk10;
    end

    
endmodule

