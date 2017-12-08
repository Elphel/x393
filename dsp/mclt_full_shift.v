/*!
 * <b>Module:</b> mclt_full_shift
 * @file mclt_full_shift.v
 * @date 2017-12-06  
 * @author eyesis
 *     
 * @brief 1d index for window with fractional shift
 *
 * @copyright Copyright (c) 2017 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 *
 * <b>License </b>
 *
 * mclt_full_shift.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * mclt_full_shift.v is distributed in the hope that it will be useful,
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

module  mclt_full_shift#(
    parameter COORD_WIDTH =     5,  //
    parameter SHIFT_WIDTH =     3   // bits in shift  
    
    )(
    input                          clk,           //!< system clock, posedge
    input                    [3:0] coord,         //!< hort/vert pixel coordinate in mclt 16x16 tile
    input signed [SHIFT_WIDTH-1:0] shift,         //!< fractional pixel shift (number after point = COORD_WIDTH-3
    output reg   [COORD_WIDTH-1:0] coord_out,     //!< pixel coordinate in window ROM (latency 2)
    output reg                     zero           //!< window is zero (on or out of the boundary)  (latency 2)     
);
    wire [COORD_WIDTH+1:0] mod_coord_w = {1'b0, coord,1'b0, {(COORD_WIDTH-4){1'b1}}} - {{(COORD_WIDTH-SHIFT_WIDTH + 2){shift[SHIFT_WIDTH-1]}}, shift};
    reg [COORD_WIDTH+1:0] mod_coord_r;
    always @ (posedge clk) begin
    coord_out <= mod_coord_r[COORD_WIDTH] ? ~mod_coord_r[COORD_WIDTH-1:0] : mod_coord_r[COORD_WIDTH-1:0];
        mod_coord_r <= mod_coord_w;
        zero <= mod_coord_r[COORD_WIDTH + 1];
    end 

endmodule

