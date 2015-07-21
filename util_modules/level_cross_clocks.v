/*******************************************************************************
 * Module: level_cross_clocks
 * Date:2015-07-19  
 * Author: Aandrey Filippov     
 * Description: re-sample signal to a different clock to reduce metastability
 *
 * Copyright (c) 2015 Elphel, Inc .
 * level_cross_clocks.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  level_cross_clocks.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  level_cross_clocks#(
    parameter WIDTH = 1,
    parameter REGISTER = 2 // number of registers (>=12)
)(
    input              clk,
    input  [WIDTH-1:0] d_in,
    output [WIDTH-1:0] d_out
);

    reg [WIDTH * REGISTER -1 : 0] regs;
    assign d_out = regs [WIDTH-1:0];
    always @ (posedge clk) begin
        regs <= {d_in, regs[WIDTH * REGISTER -1 : WIDTH]};
    end
endmodule

