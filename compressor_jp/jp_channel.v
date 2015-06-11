/*******************************************************************************
 * Module: jp_channel
 * Date:2015-06-10  
 * Author: andrey     
 * Description: Top module of JPEG/JP4 compressor channel
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * jp_channel.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  jp_channel.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  jp_channel#(
)(
    input         rst,
    input         xclk,   // global clock input, compressor single clock rate
    input         xclk2x, // global clock input, compressor double clock rate, nominally rising edge aligned
    // programming interface
    input         mclk,     // global clock, half DDR3 clock, synchronizes all I/O through the command port
    input   [7:0] cmd_ad_in,      // byte-serial command address/data (up to 6 bytes: AL-AH-D0-D1-D2-D3 
    input         cmd_stb_in,     // strobe (with first byte) for the command a/d
    output  [7:0] status_ad,   // status address/data - up to 5 bytes: A - {seq,status[1:0]} - status[2:9] - status[10:17] - status[18:25]
    output        status_rq,   // input request to send status downstream
    input         status_start // Acknowledge of the first status packet byte (address)

);



// Port 1rd (read DDR to AFI) buffer, linear
    mcntrl_buf_rd #(
        .LOG2WIDTH_RD(6) // 64 bit external interface
    ) chn1rd_buf_i (
        .ext_clk      (hclk), // input
        .ext_raddr    ({read_page,buf_in_line64[6:0]}), // input[8:0] 
        .ext_rd       (bufrd_rd[0]), // input
        .ext_regen    (bufrd_rd[1]), // input
        .ext_data_out (afi_wdata), // output[63:0] 
        .wclk         (!mclk), // input
        .wpage_in     (2'b0), // input[1:0] 
        .wpage_set    (xfer_reset_page_rd), // input  TODO: Generate @ negedge mclk on frame start
        .page_next    (buf_wpage_nxt), // input
        .page         (), // output[1:0]
        .we           (buf_wr), // input
        .data_in      (buf_wdata) // input[63:0] 
    );

endmodule

