/*******************************************************************************
 * Module: elastic_cross_clock
 * Date:2015-09-12  
 * Author: Andrey Filippov     
 * Description: Generate a train of pulses through clock domains boundary
 * One output pulse per 1 active input cycle
 * Maximal duty cycle (with EXTRA_DLY=0 and Fdst << Fsrc) = 50%
 * same frequencies - ~1/3 (with EXTRA_DLY=0) and 1/5 (with EXTRA_DLY=1)
 * Lowering Fsrc reduces duty cycle proportianally as counter is in src_clk
 * domain.
 *
 * Copyright (c) 2015 Elphel, Inc.
 * elastic_cross_clock.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  elastic_cross_clock.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  elastic_cross_clock#(
    parameter WIDTH=2,          // width of the pulse counter
    parameter EXTRA_DLY=0)(     // 0 or 1 - output duty cycle control
    input              rst,
    input              src_clk,
    input              dst_clk,
    input              in_pulses,
    output             out_pulse,
    output             busy
);
    reg   [WIDTH-1:0] pend_cntr=0;
    wire              busy_single;
    wire              single_rq_w;

//    assign busy = busy_single && (|pend_cntr);
    assign busy = busy_single || (|pend_cntr);
    assign single_rq_w = !busy_single && ((|pend_cntr) || in_pulses);
    
    always @(posedge src_clk) begin
        if      (rst)                        pend_cntr <= 0;
        else if ( in_pulses && !single_rq_w) pend_cntr <= pend_cntr + 1;
        else if (!in_pulses &&  single_rq_w) pend_cntr <= pend_cntr - 1;
    end
    
    pulse_cross_clock #(
        .EXTRA_DLY(EXTRA_DLY)
    ) pulse_cross_clock_i (
        .rst       (rst), // input
        .src_clk   (src_clk), // input
        .dst_clk   (dst_clk), // input
        .in_pulse  (single_rq_w), // input
        .out_pulse (out_pulse), // output
        .busy      (busy_single) // output
    );
    
endmodule

