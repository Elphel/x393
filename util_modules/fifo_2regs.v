/*******************************************************************************
 * Module: fifo_2regs
 * Date:2015-02-17  
 * Author: andrey     
 * Description: Simple two-register FIFO, no over/under check,
 * behaves correctly only for correct inputs
 *
 * Copyright (c) 2015 Elphel, Inc.
 * fifo_2regs.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  fifo_2regs.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  fifo_2regs #(
    parameter WIDTH =16)
     (
     input              rst,
     input              clk,
     input  [WIDTH-1:0] din,
     input              wr,
     input              rd,
     input              srst,
     output [WIDTH-1:0] dout
);
    reg              full_out;
    reg              full_in;
    reg  [WIDTH-1:0] reg_out;
    reg  [WIDTH-1:0] reg_in;
    
    assign dout=reg_out;
    always @ (posedge rst or posedge clk) begin
        if      (rst)      full_out <=0;
        else if (srst)     full_out <=0;
        else if (wr || rd) full_out <= !(!wr && rd && !full_in);
        
        if      (rst)      full_in <=0;
        else if (srst)     full_in <=0;
        else if (wr ^rd)   full_in <= wr && (full_out || full_in);
    end
    always @ (posedge clk) begin
        if (wr)                      reg_in <=  din;
        
        if (wr && (!full_out || rd)) reg_out <=  din;
        else if (rd)                 reg_out <=  reg_in;
    end

endmodule

