/*******************************************************************************
 * Module: iobuf
 * Date:2015-05-15  
 * Author: andrey     
 * Description: Wrapper for IOBUF primitive
 *
 * Copyright (c) 2015 Elphel, Inc.
 * iobuf.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  iobuf.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  iobuf#(
    parameter integer DRIVE = 12,
    parameter IBUF_LOW_PWR = "TRUE",
    parameter IOSTANDARD = "DEFAULT",
`ifdef XIL_TIMING
    parameter LOC = " UNPLACED",
`endif
    parameter SLEW = "SLOW"
)(
    output O,
    inout  IO,
    input  I,
    input  T
);

    IOBUF #(
        .DRIVE        (DRIVE),
        .IBUF_LOW_PWR (IBUF_LOW_PWR),
        .IOSTANDARD   (IOSTANDARD),
        .SLEW         (SLEW)
    ) IOBUF_i (
        .O  (O), // output 
        .IO (IO), // inout 
        .I  (I), // input 
        .T  (T) // input 
    );
endmodule

