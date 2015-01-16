/*******************************************************************************
 * Module: status_generate
 * Date:2015-01-14  
 * Author: andrey     
 * Description: generate byte-serial status data
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * status_generate.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  status_generate.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps
// mode bits: 0 disable status generation, 1 single status request, 2 - auto status, keep specified seq number, 3 - auto, inc sequence number 
module  status_generate #(
    parameter STATUS_REG_ADDR=7, // status register address to direct data to
    parameter PAYLOAD_BITS=26 //6   // >=2! (2..26)
)(
    input                    rst,
    input                    clk,
    input                    we,     // command strobe
    input              [7:0] wd,     // command data - 6 bits of sequence and 2 mode bits
    input [PAYLOAD_BITS-1:0] status, // parallel status data to be sent out
    output             [7:0] ad,     // byte-wide address/data
    output                   rq,     // request to send downstream (last byte with rq==0)
    input                    start   // acknowledge of address (first byte) from downsteram   
);
/*
    Some tools may not like {0{}}, and currently VEditor makes it UNDEFINED->32 bits
    assigning to constant?a:b now works if constant has defined value, i.e. if constant=1 b is ignored
*/
    localparam NUM_BYTES=(PAYLOAD_BITS+21)>>3;
    localparam ALIGNED_STATUS_WIDTH=((NUM_BYTES-2)<<3)+2; // 2 ->2,
    // ugly solution to avoid warnings in unused branch
    localparam ALIGNED_STATUS_BIT_2=(ALIGNED_STATUS_WIDTH>2)?2:0;
    reg                 [1:0] mode;
    reg                 [5:0] seq;
    reg    [PAYLOAD_BITS-1:0] status_r; // "frozen" status to be sent;
    reg                       status_changed_r; // not reset if status changes back to original
    reg                       cmd_pend;
    reg     [((NUM_BYTES-1)<<3)-1:0] data;
    wire     snd_rest;
    wire    need_to_send;
    wire   [ALIGNED_STATUS_WIDTH-1:0] aligned_status;
    
    reg    [NUM_BYTES-2:0]    rq_r;
    
    assign aligned_status=(ALIGNED_STATUS_WIDTH==PAYLOAD_BITS)?status:{{(ALIGNED_STATUS_WIDTH-PAYLOAD_BITS){1'b0}},status};
    assign  ad=data[7:0];
    assign need_to_send=cmd_pend || (mode[1] && status_changed_r); // latency
    assign rq=rq_r[0]; // NUM_BYTES-2];
    assign snd_rest=rq_r[0] && !rq_r[NUM_BYTES-2];
    always @ (posedge rst or posedge clk) begin
        
        if (rst) status_changed_r <= 0;
        else     status_changed_r <= (status_changed_r && !start) || (status_r != status);
        
        if     (rst) mode <= 0;
        else if (we) mode <= wd[7:6];
        
        if     (rst)                 seq <= 0;
        else if (we)                 seq <= wd[5:0];
        else if ((mode==3) && start) seq <= seq+1;
        
        if     (rst)       cmd_pend <= 0;
        else if (we)       cmd_pend <= 1;
        else if (start) cmd_pend <= 0;
        
        if      (rst)   status_r<=0;
        else if (start) status_r<=status;
        
        if (rst)                             data <= STATUS_REG_ADDR;
        else if (start)                      data <= (NUM_BYTES>2)?
                                                     {aligned_status[ALIGNED_STATUS_WIDTH-1:ALIGNED_STATUS_BIT_2],seq,status[1:0]}:
                                                     {seq,status[1:0]};
        else if ((NUM_BYTES>2) && snd_rest)  data <= data >> 8; // never happens with 2-byte packet
        else                                 data <= STATUS_REG_ADDR;
        
        if (rst)                                                 rq_r <= 0;
        else if (need_to_send && !rq_r[0])                       rq_r <= {NUM_BYTES-1{1'b1}};
        else if (start || ((NUM_BYTES>2) && !rq_r[NUM_BYTES-2])) rq_r <= rq_r >> 1;
    end
endmodule

