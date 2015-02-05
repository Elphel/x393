/*******************************************************************************
 * Module: mcont_from_chnbuf_reg
 * Date:2015-01-19  
 * Author: andrey     
 * Description: Registering data from channel buffer to memory controller
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * mcont_from_chnbuf_reg.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  mcont_from_chnbuf_reg.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  mcont_from_chnbuf_reg #(
    parameter CHN_NUMBER=0,
    parameter CHN_LATENCY=0 // 0 - no extra latency in extrenal BRAM - data available next cycle after re (but prev. data)
)(
    input rst,
    input clk,
    input                       ext_buf_rd,
//    input                       ext_buf_raddr_rst,
    input                 [3:0] ext_buf_rchn,  // ==run_chn_d valid 1 cycle ahead opf ext_buf_rd!, maybe not needed - will be generated externally
//    input                       seq_done,      // sequence done
//    output reg                  buf_done,      // sequence done for the specified channel
    output reg           [63:0] ext_buf_rdata, // Latency of ram_1kx32w_512x64r plus 2
    output reg                  buf_rd_chn,
//    output reg                  buf_raddr_rst_chn,
    input                [63:0] buf_rdata_chn
);
    reg                 buf_chn_sel;
    reg [CHN_LATENCY:0] latency_reg=0;
    always @ (posedge rst or posedge clk) begin
        if (rst) buf_chn_sel <= 0;
        else     buf_chn_sel <= (ext_buf_rchn==CHN_NUMBER);
        
        if (rst) buf_rd_chn <= 0;
        else     buf_rd_chn <= buf_chn_sel && ext_buf_rd;
        
        if (rst) latency_reg<= 0;
        else     latency_reg <= buf_rd_chn | (latency_reg << 1);
        
        if (rst) buf_done <= 0;
        else     buf_done <= buf_chn_sel && seq_done;
    end
//    always @ (posedge clk)  buf_raddr_rst_chn <= ext_buf_raddr_rst && (ext_buf_rchn==CHN_NUMBER);
//    always @ (posedge clk) if (buf_chn_sel && ext_buf_rd) buf_raddr_chn <= ext_buf_raddr;
    always @ (posedge clk) if (latency_reg[CHN_LATENCY])  ext_buf_rdata <= buf_rdata_chn;
endmodule

