/*******************************************************************************
 * Module: simul_clk_mult
 * Date:2015-10-10  
 * Author: andrey     
 * Description: Clock multiplier
 *
 * Copyright (c) 2015 Elphel, Inc .
 * simul_clk_mult.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  simul_clk_mult.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  simul_clk_mult#(
        parameter MULTIPLIER = 3,
        parameter SKIP_FIRST = 5
    ) (
        input      clk_in,
        input      en,
        output     clk_out
    );
    real phase;
    real prev_phase = 0.0;
    real out_half_period = 0.0;
    integer num_period = 0;
    reg en1 = 0;
    reg clk_out_r = 0;
    assign clk_out = clk_out_r;
    always @ (posedge clk_in) begin
        phase = $realtime;
        if (num_period >= SKIP_FIRST) begin
            out_half_period = (phase - prev_phase) / (2 * MULTIPLIER); 
            en1 = 1;
        end
        prev_phase = phase;
        num_period = num_period + 1;
    end
    
    always @ (posedge clk_in) if (en && en1) begin
        clk_out_r = 1;
        repeat (MULTIPLIER - 1) begin
            #out_half_period clk_out_r = 0;
            #out_half_period clk_out_r = 1;
        end
        #out_half_period clk_out_r = 0;
    end

endmodule

