/*******************************************************************************
 * Module: status_read
 * Date:2015-01-14  
 * Author: andrey     
 * Description: Receives status read data (low bandwidth) from multiple
 * subsystems byte-serial, stores in axi-addressable memory
 * 8-bita ddress is received from the source module,
 * as well as another (optional) byte of sequence number (set in write command)
 * Sequence number (received first afther the address) is stored as a high byte,
 * lower bytes are the actual payload, starting from lower byte (not all 3 are
 * required. Single-bit responsen can be combined in the same byte with the
 * sequence number to use just 2-byte packets? 
 * TODO: add interrupt capabilities
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * status_read.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  status_read.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  status_read#(
    parameter STATUS_ADDR =         'h1400, // AXI write address of status read registers
    parameter STATUS_ADDR_MASK =    'h1400, // AXI write address of status registers
    parameter AXI_RD_ADDR_BITS =    13,
    parameter integer STATUS_DEPTH=   8 // 256 cells, maybe just 16..64 are enough?
)(
    input rst,
    input clk,
    input [AXI_RD_ADDR_BITS-1:0] axi_pre_addr,     // status read address, 1 cycle ahead of read data
    input                        pre_stb,          // read data request, with axi_pre_addr
    output reg            [31:0] axi_status_rdata, // read data, 1 cycle latency from the address/stb
    output reg                   data_valid,       // read data valid, 1 cycle latency from pre_stb, decoded address
    input                  [7:0] ad,               // byte-serial status data from the sources
    input                        rq,               // request from sources to transfer status data
    output                       start             // acknowledge receiving of first byte (address), currently always ready
);
    localparam integer DATA_2DEPTH=(1<<STATUS_DEPTH)-1;
    reg  [31:0] ram [0:DATA_2DEPTH];
    reg         [STATUS_DEPTH-1:0] waddr;
    wire        [STATUS_DEPTH-1:0] raddr;
    reg                          we;
    wire                         re;
    reg                  [31: 0] wdata;
    reg                          rq_r;
    reg                   [3:0]  dstb;
    
    assign re= pre_stb && (((axi_pre_addr ^ STATUS_ADDR) & STATUS_ADDR_MASK) == 0);
    assign raddr=axi_pre_addr[STATUS_DEPTH-1:0];
    assign start=rq && !rq_r;
    
    always @ (posedge rst or posedge clk) begin
        if (rst) data_valid <= 0;
        else     data_valid <= re;
        
        if (rst) rq_r <= 0;
        else     rq_r <= rq;
        
        if (rst)        dstb <= 0;
        else if (!rq)   dstb <= 0;
        else            dstb <= {dstb[2:0],~rq_r};
        // byte 0 - address
        if (rst)        waddr <= 0;
        else if (start) waddr <= ad[STATUS_DEPTH-1:0];
        
        // byte 1 - 2 payload bits and sequence number
        // 6 bits of the sequence number will go to bits 26.. 31
        // 2 bits (24,25) are payload status
        if (rst)          wdata[31:24] <= 0;
        else if (start)   wdata[31:24] <= 0;
        else if (dstb[0]) wdata[31:24] <= ad;

        // byte 2 - payload bits 0..7 
        if (rst)          wdata[ 7: 0] <= 0;
        else if (start)   wdata[ 7: 0] <= 0;
        else if (dstb[1]) wdata[ 7: 0] <= ad;
        
        // byte 3 - payload bits 8..15 
        if (rst)          wdata[15: 8] <= 0;
        else if (start)   wdata[15: 8] <= 0;
        else if (dstb[2]) wdata[15: 8] <= ad;

        // byte 4 - payload bits 16..23 
        if (rst)          wdata[23:16] <= 0;
        else if (start)   wdata[23:16] <= 0;
        else if (dstb[3]) wdata[23:16] <= ad;
        
        if (rst)          we <= 0;
        else              we <= !rq && rq_r; 
    end
    
    always @ (posedge clk) begin
        if (we)  ram[waddr]  <= wdata; // shifted data here
        if (re)  axi_status_rdata<= ram[raddr];
    end
                             


endmodule

