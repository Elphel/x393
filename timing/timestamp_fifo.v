/*******************************************************************************
 * Module: timestamp_fifo
 * Date:2015-07-02  
 * Author: Andrey Filippov     
 * Description: Receives 64-bit timestamp data over 8-bit bus,
 * copies it to the outputr register set at 'advance' leading edge
 * and then reads through the different clock domain 8-bit bus.
 * Write, advance registers and readout events are supposed to have suffitient
 * pauses between them
 *
 * Copyright (c) 2015 Elphel, Inc.
 * timestamp_fifo.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  timestamp_fifo.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  timestamp_fifo(
//    input                rst,
    input                sclk,
    input                srst,    // @ posedge smclk - sync reset
    
    input                pre_stb, // marks pre-first input byte (s0,s1,s2,s3,u0,u1,u2,u3)
    input          [7:0] din,     // data in - valid for 8 cycles after pre_stb

    input                aclk,    // clock to synchronize "advance" commands
    input                arst,    // @ posedge aclk - sync reset
    
    input                advance, // @aclk advance registers
    
    input                rclk,    // output clock
    input                rrst,   // @ posedge rclk - sync reset
    input                rstb,    // @rclk, read start (data available next 8 cycles)
    output    reg [ 7:0] dout
);
    reg    [7:0] fifo_ram[0:15]; // 16x8 fifo
    reg    [3:0] wpntr;          // input fifo pointer
    reg          rcv;            // receive data
    reg    [3:0] rpntr;          // fifo read pointer
    reg    [1:0] advance_r;
    reg          snd;            // receive data
    always @ (posedge sclk) begin
        if      (srst)        rcv <= 0; 
        else if (pre_stb)     rcv <= 1;
        else if (&wpntr[2:0]) rcv <= 0;
        
        if      (srst) wpntr <= 0;
        else if (!rcv) wpntr <= {wpntr[3],3'b0};
        else           wpntr <= wpntr + 1;
    end

    always @ (posedge sclk) begin
        if (rcv) fifo_ram[wpntr] <= din;
    end
    
    always @(posedge aclk) begin
        if (arst) advance_r <= 0;
        else      advance_r <= {advance_r[0], advance};
    end

    always @(posedge aclk) begin
        if (advance_r[0] && !advance_r[1]) rpntr[3] <= wpntr[3];
    end
    
    always @(posedge rclk) begin
        if      (rrst)         snd <= 0; 
        else if (rstb)        snd <= 1;
        else if (&rpntr[2:1]) snd <= 0; // at count 6 
    
        if      (rrst)           rpntr[2:0] <= 0;
        else if (!snd && !rstb) rpntr[2:0] <= 0;
        else                    rpntr[2:0] <= rpntr[2:0] + 1;
    end

    always @(posedge rclk) begin
        if (snd)          dout <= fifo_ram[rpntr];
    end
endmodule

