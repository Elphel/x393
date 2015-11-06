/*******************************************************************************
 * Module: simul_clk_div_mult
 * Date:2015-10-12  
 * Author: andrey     
 * Description: Simulation clock rational multiplier
 *
 * Copyright (c) 2015 Elphel, Inc .
 * simul_clk_div_mult.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  simul_clk_div_mult.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  simul_clk_div_mult#(
        parameter MULTIPLIER = 3,
        parameter DIVISOR =    5,
        parameter SKIP_FIRST = 5
    ) (
        input      clk_in,
        input      en,
        output     clk_out
);
    wire clk_int;
    generate
        if (DIVISOR > 1) 
            sim_clk_div #(
                .DIVISOR   (DIVISOR)
            ) sim_clk_div_i (
                .clk_in   (clk_in), // input
                .en       (en), // input
                .clk_out  (clk_int) // output
            );
        else
            assign clk_int = clk_in;
    endgenerate
    generate
        if (MULTIPLIER > 1) 
            simul_clk_mult #(
                .MULTIPLIER (MULTIPLIER),
                .SKIP_FIRST (SKIP_FIRST)
            ) simul_clk_mult_i (
                .clk_in  (clk_int), // input
                .en      (en), // input
                .clk_out (clk_out) // output
            );
        else
            assign clk_out = clk_int;
    endgenerate
endmodule

