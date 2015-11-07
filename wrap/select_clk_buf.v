/*******************************************************************************
 * Module: select_clk_buf
 * Date:2015-11-07  
 * Author: andrey     
 * Description: Select one of the clock buffers primitives by parameter
 *
 * Copyright (c) 2015 Elphel, Inc .
 * select_clk_buf.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  select_clk_buf.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  select_clk_buf #(
    parameter BUFFER_TYPE = "BUFR" // to use clr
    )(
        output o,
        input  i,
        input  clr // for BUFR_only
);
     generate
        if      (BUFFER_TYPE == "BUFG")  BUFG  clk1x_i (.O(o), .I(i));
        else if (BUFFER_TYPE == "BUFH")  BUFH  clk1x_i (.O(o), .I(i));
        else if (BUFFER_TYPE == "BUFR")  BUFR  clk1x_i (.O(o), .I(i), .CE(1'b1), .CLR(clr));
        else if (BUFFER_TYPE == "BUFMR") BUFMR clk1x_i (.O(o), .I(i));
        else if (BUFFER_TYPE == "BUFIO") BUFIO clk1x_i (.O(o), .I(i));
        else assign o = i;
    endgenerate

endmodule

