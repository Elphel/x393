/*******************************************************************************
 * Module: oddr_ss
 * Date:2015-05-16  
 * Author: Andrey Filippov     
 * Description: Wrapper for ODDR+OBUFT
 *
 * Copyright (c) 2015 Elphel, Inc.
 * oddr_ss.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  oddr_ss.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  oddr_ss #(
    parameter IOSTANDARD = "DEFAULT",
    parameter SLEW = "SLOW",
    parameter DDR_CLK_EDGE = "OPPOSITE_EDGE",
    parameter INIT         = 1'b0,
    parameter SRTYPE =       "SYNC"
)(
    input  clk,
    input  ce,
    input  rst,
    input  set,
    input [1:0] din,
    input  tin, // tristate control
    output dq
);
    wire idq;
    ODDR #(
        .DDR_CLK_EDGE(DDR_CLK_EDGE),
        .INIT(INIT),
        .SRTYPE(SRTYPE)
    ) ODDR_i (
        .Q(idq), // output 
        .C(clk), // input 
        .CE(ce), // input 
        .D1(din[0]), // input 
        .D2(din[1]), // input 
        .R(rst), // input 
        .S(set) // input 
    );
OBUFT #(
    .IOSTANDARD(IOSTANDARD),
    .SLEW(SLEW)
) iobufs_i (
    .O(dq),
    .I(idq),
    .T(tin));
endmodule

