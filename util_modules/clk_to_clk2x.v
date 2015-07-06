/*******************************************************************************
 * Module: clk_to_clk2x
 * Date:2015-05-29  
 * Author: andrey     
 * Description: move data between clk and clk2x (nominally posedge aligned)
 *
 * Copyright (c) 2015 Elphel, Inc.
 * clk_to_clk2x.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  clk_to_clk2x.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  clk_to_clk2x(
    input  clk,     // single rate clock
    input  clk2x,   // double rate clock, approximately posedge aligned to clk
    output clk_sync // approximately repeating clk, clocked @posedge clk2x - use as CE to transfer data
);

    reg r_clk =    0;
    reg r_nclk2x = 0;
    reg r_clk2x;
   
    assign clk_sync=r_clk2x;
    
    always @(posedge r_nclk2x or posedge clk) begin
        if (r_nclk2x) r_clk <= 0;
        else          r_clk <= 1;
    end   

    always @(negedge clk2x) r_nclk2x <= r_clk;
    always @(posedge clk2x) r_clk2x <= !r_nclk2x;

endmodule

