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
 * Copyright (c) 2015 Elphel, Inc.
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
    parameter STATUS_ADDR =           'h2400, // AXI write address of status read registers
    parameter STATUS_ADDR_MASK =      'h3c00, // AXI write address of status registers
    parameter AXI_RD_ADDR_BITS =      14,
    parameter integer STATUS_DEPTH=   8 // 256 cells, maybe just 16..64 are enough?
)(
    input rst,
    input clk,
    input                        axi_clk,   // common for read and write channels
    input [AXI_RD_ADDR_BITS-1:0] axird_pre_araddr,     // status read address, 1 cycle ahead of read data
//    input                        pre_stb,          // read data request, with axi_pre_addr
//    output reg            [31:0] axi_status_rdata, // read data, 1 cycle latency from the address/stb
//    output reg                   data_valid,       // read data valid, 1 cycle latency from pre_stb, decoded address
    input                        axird_start_burst, // start of read burst, valid pre_araddr, save externally to control ext. dev_ready multiplexer
    input     [STATUS_DEPTH-1:0] axird_raddr, //   .raddr(read_in_progress?read_address[9:0]:10'h3ff),    // read address
    input                        axird_ren,   //      .ren(bram_reg_re_w) ,      // read port enable
    input                        axird_regen, //==axird_ren?? - remove?   .regen(bram_reg_re_w),        // output register enable
    output              [31:0]   axird_rdata,  // combinatorial multiplexed (add external register layer, modify axibram_read?)     .data_out(rdata[31:0]),       // data out
    output                       axird_selected, // axird_rdata contains cvalid data from this module, vcalid next after axird_start_burst
                                                 // so with ren/regen it may be delayed 1 more cycle
    input                  [7:0] ad,               // byte-serial status data from the sources
    input                        rq,               // request from sources to transfer status data
    output                       start             // acknowledge receiving of first byte (address), currently always ready
);
    localparam integer DATA_2DEPTH=(1<<STATUS_DEPTH)-1;
    reg  [31:0] ram [0:DATA_2DEPTH];
    reg         [STATUS_DEPTH-1:0] waddr;
//    wire        [STATUS_DEPTH-1:0] raddr;
    reg                          we;
//    wire                         re;
    reg                  [31: 0] wdata;
    reg                          rq_r;
    reg                   [3:0]  dstb;
    
    wire                         select_w;
    reg                          select_r;
    reg                          select_d;
    
    wire                         rd;
    wire                         regen;
    reg                 [31:0]   axi_status_rdata; 
    reg                 [31:0]   axi_status_rdata_r;
    
// registering to match BRAM timing (so it is possible to instantioate it instead)    
//    reg       [STATUS_DEPTH-1:0] raddr_r; //   .raddr(read_in_progress?read_address[9:0]:10'h3ff),    // read address
//    reg                          rd_r;   //      .ren(bram_reg_re_w) ,      // read port enable
//    reg                          regen_r; //==axird_ren?? - remove?   .regen(bram_reg_re_w),        // output register enable
   
    
    
    assign select_w = ((axird_pre_araddr ^ STATUS_ADDR) & STATUS_ADDR_MASK)==0;
    assign rd =        axird_ren   && select_r;
    assign regen =     axird_regen && select_d;
    
    
    
    
//    assign re= pre_stb && (((axi_pre_addr ^ STATUS_ADDR) & STATUS_ADDR_MASK) == 0);
//    assign raddr=axi_pre_addr[STATUS_DEPTH-1:0];
    assign start=rq && !rq_r;
    assign axird_rdata=axi_status_rdata_r;
    assign axird_selected = select_r; 
    always @ (posedge rst or posedge axi_clk) begin
        if      (rst)               select_r <= 0;
        else if (axird_start_burst) select_r <= select_w;
    end
    always @ (posedge axi_clk) begin
//        if (rd_r)     axi_status_rdata <= ram[raddr_r];
//        if (regen_r)  axi_status_rdata_r <= axi_status_rdata;
        if (rd)       axi_status_rdata <= ram[axird_raddr];
        if (regen)    axi_status_rdata_r <= axi_status_rdata;
        
        select_d <=   select_r;
//        raddr_r <=   axird_raddr;
//        rd_r <=      rd;
//        regen_r <=   regen;
    end
    
    always @ (posedge rst or posedge clk) begin
    
//        if (rst) data_valid <= 0;
//        else     data_valid <= re;
        
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
        if (we)     ram[waddr]  <= wdata; // shifted data here
    end
                             


endmodule

