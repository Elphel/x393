/*******************************************************************************
 * Module: pulse_cross_clock
 * Date:2015-04-27  
 * Author: Andrey Filippov     
 * Description: Propagate a single pulse through clock domain boundary
 * For same frequencies input pulses can have 1:3 duty cycle EXTRA_DLY=0
 * and 1:5 for EXTRA_DLY=1 
 *
 * Copyright (c) 2015 Elphel, Inc.
 * pulse_cross_clock.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  pulse_cross_clock.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  pulse_cross_clock#(
    parameter EXTRA_DLY=0 // for 
)(
    input  rst,
    input  src_clk,
    input  dst_clk,
    input  in_pulse, // single-cycle positive pulse
    output out_pulse,
    output busy
);
    localparam EXTRA_DLY_SAFE=EXTRA_DLY ? 1 : 0;
    reg       in_reg = 0;
    reg [2:0] out_reg = 0;
    reg       busy_r = 0;
    assign out_pulse=out_reg[2];
    assign busy=busy_r; // in_reg;
    always @(posedge src_clk or posedge rst) begin
        if   (rst) in_reg <= 0;
        else       in_reg <= in_pulse || (in_reg && !out_reg[EXTRA_DLY_SAFE]);
        if   (rst) busy_r <= 0;
        else       busy_r <= in_pulse || in_reg || (busy_r && (|out_reg[EXTRA_DLY_SAFE:0]));
    end
//    always @(posedge dst_clk or posedge rst) begin
    always @(posedge dst_clk) begin
        out_reg <= {out_reg[0] & ~out_reg[1],out_reg[0],in_reg};
    end
endmodule

