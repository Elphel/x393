/*******************************************************************************
 * Module: dly01_16
 * Date:2014-05-30  
 * Author: Andrey Filippov
 * Description: Synchronous delay by 1-16 clock cycles with reset (will map to primitive)
 *
 * Copyright (c) 2014 Elphel, Inc.
 * dly01_16.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  dly01_16.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  dly01_16(
    input       clk,
    input       rst,
    input [3:0] dly,
    input       din,
    output      dout
);
    reg [15:0] sr=0;
`ifdef SHREG_SEQUENTIAL_RESET
    always @ (posedge clk) begin
        sr <= {sr[14:0], din & ~rst}; 
    end
`else 
//    always @ (posedge rst or posedge clk) begin
    always @ (posedge clk) begin
       if (rst) sr <=0;
       else     sr <= {sr[14:0],din}; 
    end
`endif
`ifdef SIMULATION
    assign dout = (|sr) ? ((&sr) ? 1'b1 : sr[dly]) :  1'b0 ;
`else
    assign dout =sr[dly];
`endif        
endmodule

