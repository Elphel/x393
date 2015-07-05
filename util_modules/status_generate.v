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
// mode bits:
//  0 disable status generation,
//  1 single status request,
//  2 - auto status, keep specified seq number,
//  3 - auto, inc sequence number

module  status_generate #(
    parameter STATUS_REG_ADDR=   7, // status register address to direct data to
    parameter PAYLOAD_BITS =     15, //6   // >=2! (2..26)
    parameter REGISTER_STATUS =  1,  // 1 - register input status data (for different clock domains),  0 - do not register (same domain)
    parameter EXTRA_WORDS=       1, // should always be >0
    // if EXTRA_WORDS >0 the mesasges with these extra data will be generated and sent before the status message itself
    // if PAYLOAD_BITS == 0, then one status bit will still have to be provided (status input will have width of 1+32*EXTRA_WORDS),
    // but the status message will not be sent - only the data words
    parameter EXTRA_REG_ADDR=    8 // Where to place optional extra data words
)(
    input                    rst,
    input                    clk,
    input                    we,     // command strobe
    input              [7:0] wd,     // command data - 6 bits of sequence and 2 mode bits
//    input [PAYLOAD_BITS-1:0] status, // parallel status data to be sent out, may come from different clock domain
    input     [ALL_BITS-1:0] status, // parallel status data to be sent out, may come from different clock domain
    output             [7:0] ad,     // byte-wide address/data
    output                   rq,     // request to send downstream (last byte with rq==0)
    input                    start   // acknowledge of address (first byte) from downsteram   
);
    localparam STATUS_BITS = ((PAYLOAD_BITS > 0) ? PAYLOAD_BITS: 1);
    localparam ALL_BITS = STATUS_BITS + 32 * EXTRA_WORDS;
    generate
        if (EXTRA_WORDS >0) begin
            status_generate_extra #(
                .STATUS_REG_ADDR  (STATUS_REG_ADDR),
                .PAYLOAD_BITS     (PAYLOAD_BITS),
                .REGISTER_STATUS  (REGISTER_STATUS),
                .EXTRA_WORDS      (EXTRA_WORDS), // guaranteed >0
                .EXTRA_REG_ADDR   (EXTRA_REG_ADDR)
            ) status_generate_extra_i (
                .rst      (rst), // input
                .clk      (clk), // input
                .we       (we), // input
                .wd       (wd), // input[7:0] 
                .status   (status), // input[46:0] 
                .ad       (ad), // output[7:0] 
                .rq       (rq), // output
                .start    (start) // input
            );
        
        end else begin
            status_generate_only #(
                .STATUS_REG_ADDR(7),
                .PAYLOAD_BITS(15),
                .REGISTER_STATUS(1)
            ) status_generate_only_i (
                .rst      (rst), // input
                .clk      (clk), // input
                .we       (we), // input
                .wd       (wd), // input[7:0] 
                .status   (status[PAYLOAD_BITS-1:0]), // input[14:0] 
                .ad       (ad), // output[7:0] 
                .rq       (rq), // output
                .start    (start) // input
            );
        
        end
    endgenerate

endmodule

//module that generates only status message
module  status_generate_only #(
    parameter STATUS_REG_ADDR =  7, // status register address to direct data to
    parameter PAYLOAD_BITS =    15, //6   // >=2! (2..26)
    parameter REGISTER_STATUS =  1  // 1 - register input status data (for different clock domains),  0 - do not register (same domain)
)(
    input                    rst,
    input                    clk,
    input                    we,     // command strobe
    input              [7:0] wd,     // command data - 6 bits of sequence and 2 mode bits
    input [PAYLOAD_BITS-1:0] status, // parallel status data to be sent out, may come from different clock domain
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
    // ugly solution to avoid warnings in unused "if" branch
    localparam ALIGNED_STATUS_BIT_2=(ALIGNED_STATUS_WIDTH>2)?2:0;
    wire                [1:0] mode_w;
    reg                 [1:0] mode;
    reg                 [5:0] seq;
//    reg    [PAYLOAD_BITS-1:0] status_r0; // registered status as it may come from the different clock domain
    reg    [PAYLOAD_BITS-1:0] status_r0r; // registered status as it may come from the different clock domain 
    wire   [PAYLOAD_BITS-1:0] status_r0; // registered/not registered status deata depending on the REGISTER_STATUS
     
    reg    [PAYLOAD_BITS-1:0] status_r; // "frozen" status to be sent;
    reg                       status_changed_r; // not reset if status changes back to original
    reg                       cmd_pend;
    reg     [((NUM_BYTES-1)<<3)-1:0] data;
    wire     snd_rest;
    wire    need_to_send;
    wire   [ALIGNED_STATUS_WIDTH-1:0] aligned_status;
    
    reg    [NUM_BYTES-2:0]    rq_r;
    
    assign aligned_status=(ALIGNED_STATUS_WIDTH==PAYLOAD_BITS)?status_r0:{{(ALIGNED_STATUS_WIDTH-PAYLOAD_BITS){1'b0}},status_r0};
    assign ad=data[7:0];
    assign need_to_send=cmd_pend || (mode[1] && status_changed_r); // latency
    assign rq=rq_r[0]; // NUM_BYTES-2];
    assign snd_rest=rq_r[0] && !rq_r[NUM_BYTES-2];
    assign mode_w=wd[7:6];
    assign status_r0 = REGISTER_STATUS? status_r0r : status;
    
    always @ (posedge rst or posedge clk) begin
        
        if      (rst)       status_changed_r <= 0;
//        else     status_changed_r <= (status_changed_r && !start) || (status_r != status);
        else if (start)     status_changed_r <= 0;
        else                status_changed_r <= status_changed_r  || (status_r != status_r0);
        
        if     (rst) mode <= 0;
        else if (we) mode <= mode_w; // wd[7:6];
        
        if     (rst)                 seq <= 0;
        else if (we)                 seq <= wd[5:0];
        else if ((mode==3) && start) seq <= seq+1;
        
        if      (rst)               cmd_pend <= 0;
        else if (we && (mode_w!=0)) cmd_pend <= 1;
        else if (start)             cmd_pend <= 0;
        
        if      (rst)   status_r0r <= 0;
        else            status_r0r <= status;

        if      (rst)   status_r<=0;
        else if (start) status_r<=status_r0;
        
        if (rst)                             data <= STATUS_REG_ADDR;
        else if (start)                      data <= (NUM_BYTES>2)?
                                                     {aligned_status[ALIGNED_STATUS_WIDTH-1:ALIGNED_STATUS_BIT_2],seq,status_r0[1:0]}:
                                                     {seq,status_r0[1:0]};
        else if ((NUM_BYTES>2) && snd_rest)  data <= data >> 8; // never happens with 2-byte packet
        else                                 data <= STATUS_REG_ADDR;
        
        if (rst)                                                 rq_r <= 0;
        else if (need_to_send && !rq_r[0])                       rq_r <= {NUM_BYTES-1{1'b1}};
        else if (start || ((NUM_BYTES>2) && !rq_r[NUM_BYTES-2])) rq_r <= rq_r >> 1;
    end
endmodule

//module that generates several 32-bit words and optionally status message
module  status_generate_extra #(
    parameter STATUS_REG_ADDR=   7, // status register address to direct data to
    parameter PAYLOAD_BITS =     15, //6   // >=2! (2..26)
    parameter REGISTER_STATUS =  1,  // 1 - register input status data (for different clock domains),  0 - do not register (same domain)
    parameter EXTRA_WORDS=       1, // should always be >0
    parameter EXTRA_WORDS_LN2 =  3, // number of bits to select among extra words and (optional) status 
    // if EXTRA_WORDS >0 the mesasges with these extra data will be generated and sent before the status message itself
    // if PAYLOAD_BITS == 0, then one status bit will still have to be provided (status input will have width of 1+32*EXTRA_WORDS),
    // but the status message will not be sent - only the data words
    parameter EXTRA_REG_ADDR=    8 // Where to place optional extra data words
)(
    input                    rst,
    input                    clk,
    input                    we,     // command strobe
    input              [7:0] wd,     // command data - 6 bits of sequence and 2 mode bits
//    input [PAYLOAD_BITS-1:0] status, // parallel status data to be sent out, may come from different clock domain
    input     [ALL_BITS-1:0] status, // parallel status data to be sent out, may come from different clock domain
    output             [7:0] ad,     // byte-wide address/data
    output                   rq,     // request to send downstream (last byte with rq==0)
    input                    start   // acknowledge of address (first byte) from downsteram   
);

// multiple of 32 bits added to PAYLOAD_BITS, these words are not compared but always sent before status to locations above/below status one
// no need to register extra words - status should be modified after the extra.
    localparam STATUS_BITS = ((PAYLOAD_BITS > 0) ? PAYLOAD_BITS: 1);
    localparam ALL_BITS = STATUS_BITS + 32 * EXTRA_WORDS;
    localparam NUM_MSG = EXTRA_WORDS + ((PAYLOAD_BITS > 0)? 1 : 0);
    
    localparam NUM_BYTES = (STATUS_BITS + 21) >> 3;
    localparam ALIGNED_STATUS_WIDTH = ((NUM_BYTES - 2) << 3) + 2; // 2 ->2,
    // ugly solution to avoid warnings in unused "if" branch
    localparam ALIGNED_STATUS_BIT_2 = (ALIGNED_STATUS_WIDTH > 2) ? 2 : 0;
    localparam STATUS_MASK = (1 << (NUM_BYTES) -1) - 1;   
    
    wire                [1:0] mode_w;
    reg                 [1:0] mode;
    reg                 [5:0] seq;
    reg     [STATUS_BITS-1:0] status_r0r; // registered status as it may come from the different clock domain 
    wire    [STATUS_BITS-1:0] status_r0; // registered/not registered status deata depending on the REGISTER_STATUS
    reg     [STATUS_BITS-1:0] status_r; // "frozen" status to be sent;
    reg                       status_changed_r; // not reset if status changes back to original
    reg                       cmd_pend;
    reg                [39:0] data; 
    wire    need_to_send;
    wire   [ALIGNED_STATUS_WIDTH-1:0] aligned_status;
    
    reg                 [2:0] rq_r; // for all messages
    
    reg      [NUM_MSG-1:0]    msg1hot; 
    wire                      msg_is_last;
    wire                      start_last;   // start last message (status if enabled, or last data if PAYLOAD_BITS ==0)
    wire                      msg_is_status;
    wire                      start_status; // only for status message (if it is ever sent)
    reg                 [7:0] next_addr;    // address to use in the next message
    wire                [7:0] first_addr;   // address to use in the first message
    
    reg                 [2:0] next_mask;    // define duration (0 - 1 cycle, 1 - 2, 3 - 3, 7 - 4)
    wire                [2:0] first_mask;   // define duration (0 - 1 cycle, 1 - 2, 3 - 3, 7 - 4)
    
    
    reg  [EXTRA_WORDS_LN2-1:0] msg_num;
    wire                [31:0] dont_care= 32'bx;
    wire                [31:0] pre_mux [0:(1<<EXTRA_WORDS_LN2)-1];
    wire                [31:0] status32=(NUM_BYTES>2) ?
         ((ALIGNED_STATUS_WIDTH < 26)?
              {{(26-ALIGNED_STATUS_WIDTH){1'b0}},aligned_status[ALIGNED_STATUS_WIDTH-1:ALIGNED_STATUS_BIT_2],seq,status_r0[1:0]}:
              {                                  aligned_status[ALIGNED_STATUS_WIDTH-1:ALIGNED_STATUS_BIT_2],seq,status_r0[1:0]}):
              {24'b0,seq,status_r0[1:0]};
    genvar i;
    generate
        for (i = 0; i <  (1<<EXTRA_WORDS_LN2); i=i+1) begin:gen_cyc1
            assign pre_mux[i] = (i < EXTRA_WORDS)?  //status[PAYLOAD_BITS + 32*i +:32] : // actually change order!
                                {status[PAYLOAD_BITS + 32*i + 24 +:8],status[PAYLOAD_BITS + 32*i +:24] }:
                                (((i == EXTRA_WORDS) && (PAYLOAD_BITS > 0)) ? status32 : dont_care);
        end
    endgenerate
    
    
    assign aligned_status=(ALIGNED_STATUS_WIDTH==STATUS_BITS)?status_r0:{{(ALIGNED_STATUS_WIDTH-STATUS_BITS){1'b0}},status_r0};
    assign ad=data[7:0];
    assign need_to_send=cmd_pend || (mode[1] && status_changed_r); // latency
    assign rq=rq_r[0]; // NUM_BYTES-2];
    assign mode_w=wd[7:6];
    assign status_r0 = REGISTER_STATUS? status_r0r : status;
    
    assign msg_is_last =   msg1hot[NUM_MSG-1];
    assign msg_is_status = msg_is_last && (PAYLOAD_BITS > 0);
    assign start_last =    start && msg_is_last;  
    assign start_status = start && msg_is_status;
    assign first_addr = (EXTRA_WORDS>0) ? EXTRA_REG_ADDR : STATUS_REG_ADDR;
    assign first_mask = (EXTRA_WORDS>0) ? 7 : STATUS_MASK;
    
    always @ (posedge rst or posedge clk) begin
        
        if      (rst)            status_changed_r <= 0;
        else if (start_last)     status_changed_r <= 0;
        else                     status_changed_r <= status_changed_r  || (status_r != status_r0);
        
        if     (rst) mode <= 0;
        else if (we) mode <= mode_w; // wd[7:6];
        
        if     (rst)                        seq <= 0;
        else if (we)                        seq <= wd[5:0];
        else if ((mode==3) && start_status) seq <= seq+1; // no need to increment sequence number if no status is sent
        
        if      (rst)               cmd_pend <= 0;
        else if (we && (mode_w!=0)) cmd_pend <= 1;
        else if (start_last)        cmd_pend <= 0;
        
        if      (rst)   status_r0r <= 0;
        else            status_r0r <= status[STATUS_BITS-1:0];

        if      (rst)              status_r <= 0;
        else if (start_last)       status_r <= status_r0;
        
        if      (!rst)                                  next_addr <= first_addr;
        else if (!need_to_send || start_last)           next_addr <= first_addr;
        else if (start && (msg1hot[EXTRA_WORDS -1:0]))  next_addr <= STATUS_REG_ADDR;
        else if (start)                                 next_addr <= next_addr + 1;

        if      (!rst)                                  next_mask <= first_mask;
        else if (!need_to_send || start_last)           next_mask <= first_mask;
        else if (start && (msg1hot[EXTRA_WORDS -1 :0])) next_mask <= STATUS_MASK;

        if      (rst)                      rq_r <= 0;
        else if (need_to_send && !rq_r[0]) rq_r <= 1;
        else if (start)                    rq_r <= next_mask;
        else if (|rq_r)                    rq_r <= rq_r >> 1;
        
        if (rst)                msg_num <= 0;
        else if (!need_to_send) msg_num <= 0;
        else if (start)         msg_num <= msg_num + 1;

        if (rst)                msg1hot <= 0;
        else if (!need_to_send) msg1hot <= 0;
        else if (start)         msg1hot <= msg1hot >> 1;
        
            
    end
    
    always @ (posedge clk) begin
        if      (!rq)            data <= {next_addr, pre_mux[msg_num]};
        else if (start || start) data <= data >> 8;
    end
    
    
endmodule

