/*******************************************************************************
 * Module: cmprs_afi_mux_status
 * Date:2015-06-28  
 * Author: andrey     
 * Description: prepare and send per-channel chunk pointer information as status
 * Using 4 consecutive locations. Each channel can provide one of the 4 pointers:
 * frame pointer in the write channel, current chunk pointer in the write channel
 * and the same for the write response channel (confirmed written to the system
 * memory
 *
 * Copyright (c) 2015 Elphel, Inc.
 * cmprs_afi_mux_status.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  cmprs_afi_mux_status.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  cmprs_afi_mux_status #(
    parameter CMPRS_AFIMUX_STATUS_REG_ADDR=     'h20,  //Uses 4 locations TODO: assign valid address
    parameter CMPRS_AFIMUX_WIDTH =              26, // maximal for status: currently only works with 26)
    parameter CMPRS_AFIMUX_CYCBITS =            3
 ) (
    input                          rst,
    input                          hclk,         // global clock to run axi_hp @ 150MHz, shared by all compressor channels
    input                          mclk,         // for command/status
    // mclk domain
    input                   [15:0] cmd_data,     //  
    input                   [ 1:0] cmd_a,        //
    input                          status_we,    //
    input                          mode_we,      //
      
    output                   [7:0] status_ad,    // status address/data - up to 5 bytes: A - {seq,status[1:0]} - status[2:9] - status[10:17] - status[18:25]
    output                         status_rq,    // input request to send status downstream
    input                          status_start, // Acknowledge of the first status packet byte (address)
    // hclk domain
    input                          en,           // 1- enable, 0 - reset
    output reg               [3:0] chunk_ptr_ra, // full pointer address - {eof,wresp,chn[1:0]}
    input [CMPRS_AFIMUX_WIDTH-1:0] chunk_ptr_rd  // pointer data
);
    reg [15:0] mode_data_mclk; // some bits unused
    wire       mode_we_hclk;
    reg  [7:0] mode_hclk;
//    wire [1:0] sel[0:3]={mode_hclk[7:6],mode_hclk[5:4],mode_hclk[3:2],mode_hclk[1:0]};

    reg  [1:0] index;
    reg  [CMPRS_AFIMUX_CYCBITS-1:0] cntr;
    reg    [CMPRS_AFIMUX_WIDTH-1:0] chunk_ptr_hclk;  // pointer data
    reg                       [1:0] chunk_chn_hclk;  // pointer channel
    
    reg    [CMPRS_AFIMUX_WIDTH-1:0] status_data[0:3];
    
    wire stb_w;
    reg  stb_r;
    wire stb_mclk;
    
    wire [7:0] ad[0:3];
    wire [3:0] rq;
    wire [3:0] start;
    
    assign stb_w = en && (cntr==0);
    always @ (posedge mclk) begin
        if (mode_we) mode_data_mclk <= cmd_data[15:0];
    end

    always @ (posedge hclk) begin
        if (mode_we_hclk) begin 
            if (mode_data_mclk[ 2]) mode_hclk[1:0] <= mode_data_mclk[ 1: 0];
            if (mode_data_mclk[ 6]) mode_hclk[3:2] <= mode_data_mclk[ 5: 4];
            if (mode_data_mclk[10]) mode_hclk[5:4] <= mode_data_mclk[ 9: 8];
            if (mode_data_mclk[14]) mode_hclk[7:6] <= mode_data_mclk[13:12];
            
            if (stb_mclk) status_data[chunk_chn_hclk] <= chunk_ptr_hclk;
        end
        
        if (!en) {index,cntr} <= 0;
        else     {index,cntr} <= {index,cntr} + 1;
        
        if (stb_w) begin
            chunk_ptr_ra[1:0] <= index;
            case (index) 
                2'h0: chunk_ptr_ra[3:2] <= mode_hclk[1:0] ^ 1; // so 0 will be eof, internal
                2'h1: chunk_ptr_ra[3:2] <= mode_hclk[3:2] ^ 1;
                2'h2: chunk_ptr_ra[3:2] <= mode_hclk[5:4] ^ 1;
                2'h3: chunk_ptr_ra[3:2] <= mode_hclk[7:6] ^ 1;
            endcase
        end
        stb_r <= stb_w;
        if (stb_r) begin
            chunk_ptr_hclk <= {chunk_ptr_rd[23:0],chunk_ptr_rd[25:24]}; // bits 0,1 are sent to 25:24
            chunk_chn_hclk <= index;
        end
        
    end
    
    pulse_cross_clock mode_we_hclk_i (.rst(rst), .src_clk(mclk), .dst_clk(hclk), .in_pulse(mode_we), .out_pulse(mode_we_hclk),.busy());
    pulse_cross_clock stb_mclk_i     (.rst(rst), .src_clk(hclk), .dst_clk(mclk), .in_pulse(stb_r),   .out_pulse(stb_mclk),    .busy());
    status_router4 status_router4_i (
        .rst       (rst),          // input
        .clk       (mclk),         // input
        .db_in0    (ad[0]),        // input[7:0] 
        .rq_in0    (rq[0]),        // input
        .start_in0 (start[0]),     // output

        .db_in1    (ad[1]),        // input[7:0] 
        .rq_in1    (rq[1]),        // input
        .start_in1 (start[1]),     // output
        .db_in2    (ad[2]),        // input[7:0] 
        .rq_in2    (rq[2]),        // input
        .start_in2 (start[2]),     // output
        .db_in3    (ad[3]),        // input[7:0] 
        .rq_in3    (rq[3]),        // input
        .start_in3 (start[3]),     // output
        .db_out    (status_ad),    // output[7:0] 
        .rq_out    (status_rq),    // output
        .start_out (status_start)  // input
    );

    status_generate #(
        .STATUS_REG_ADDR  (CMPRS_AFIMUX_STATUS_REG_ADDR+0),
        .PAYLOAD_BITS     (CMPRS_AFIMUX_WIDTH)
    ) status_generate0_i (
        .rst     (rst),                     // input
        .clk     (mclk),                    // input
        .we      (status_we && (cmd_a==0)), // input
        .wd      (cmd_data[7:0]),           // input[7:0] 
        .status  (status_data[0]),          // input[25:0] 
        .ad      (ad[0]),                   // output[7:0] 
        .rq      (rq[0]),                   // output
        .start   (start[0])                 // input
    );

    status_generate #(
        .STATUS_REG_ADDR  (CMPRS_AFIMUX_STATUS_REG_ADDR+0),
        .PAYLOAD_BITS     (CMPRS_AFIMUX_WIDTH)
    ) status_generate1_i (
        .rst     (rst),                     // input
        .clk     (mclk),                    // input
        .we      (status_we && (cmd_a==1)), // input
        .wd      (cmd_data[7:0]),           // input[7:0] 
        .status  (status_data[1]),          // input[25:0] 
        .ad      (ad[1]),                   // output[7:0] 
        .rq      (rq[1]),                   // output
        .start   (start[1])                 // input
    );

    status_generate #(
        .STATUS_REG_ADDR  (CMPRS_AFIMUX_STATUS_REG_ADDR+0),
        .PAYLOAD_BITS     (CMPRS_AFIMUX_WIDTH)
    ) status_generate2_i (
        .rst     (rst),                     // input
        .clk     (mclk),                    // input
        .we      (status_we && (cmd_a==2)), // input
        .wd      (cmd_data[7:0]),           // input[7:0] 
        .status  (status_data[2]),          // input[25:0] 
        .ad      (ad[2]),                   // output[7:0] 
        .rq      (rq[2]),                   // output
        .start   (start[2])                 // input
    );

    status_generate #(
        .STATUS_REG_ADDR  (CMPRS_AFIMUX_STATUS_REG_ADDR+0),
        .PAYLOAD_BITS     (CMPRS_AFIMUX_WIDTH)
    ) status_generate3_i (
        .rst     (rst),                     // input
        .clk     (mclk),                    // input
        .we      (status_we && (cmd_a==3)), // input
        .wd      (cmd_data[7:0]),           // input[7:0] 
        .status  (status_data[3]),          // input[25:0] 
        .ad      (ad[3]),                   // output[7:0] 
        .rq      (rq[3]),                   // output
        .start   (start[3])                 // input
    );

endmodule

