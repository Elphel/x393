/*******************************************************************************
 * Module: latch_g_ce
 * Date:2015-07-22  
 * Author: Andrey Filippov    
 * Description: Multi-bit wrapper for the transparent latch primitive
 *
 * Copyright (c) 2015 Elphel, Inc .
 * latch_g_ce.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  latch_g_ce.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  latch_g_ce#(
  parameter WIDTH = 1,
  parameter INIT = 0,
  parameter [0:0] IS_CLR_INVERTED = 0,
  parameter [0:0] IS_G_INVERTED = 0

)(
    input                rst,
    input                g,
    input                ce,
    input  [WIDTH-1: 0 ] d_in,
    output [WIDTH-1: 0 ] q_out
);
    generate
        genvar i;
        for (i = 0; i < WIDTH; i = i+ 1) begin:ldce_block
            LDCE #(
                .INIT            ((INIT >> i) & 1),
                .IS_CLR_INVERTED (IS_CLR_INVERTED),
                .IS_G_INVERTED   (IS_G_INVERTED)
            ) ldce_i (
                .Q    (q_out[i]), // output
                .CLR  (rst),      // input
                .D    (d_in[i]),  // input
                .G    (g),        // input
                .GE   (ce)        // input
            );
        end
    endgenerate


endmodule

