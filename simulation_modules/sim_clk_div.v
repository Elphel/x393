/*******************************************************************************
 * Module: sim_clk_div
 * Date:2015-10-11  
 * Author: andrey     
 * Description: Divide clock frequency by integer number
 *
 * Copyright (c) 2015 Elphel, Inc .
 * sim_clk_div.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  sim_clk_div.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  sim_clk_div#(
        parameter DIVISOR =  5
    ) (
        input      clk_in,
        input      en,
        output     clk_out
    );
    integer cntr = 0;
    reg clk_out_r = 0;
    assign clk_out = (DIVISOR == 1) ? clk_in: clk_out_r;
    always @(clk_in) if (en) begin
        if (cntr == 0) begin
            cntr = DIVISOR - 1;
            clk_out_r = !clk_out_r;
        end else begin
            cntr = cntr - 1;
        end
    end
endmodule

