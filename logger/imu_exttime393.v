/*******************************************************************************
 * Module: imu_exttime393
 * Date:2015-07-06  
 * Author: Andrey Filippov     
 * Description: get external timestamp (for image)
 *
 * Copyright (c) 2015 Elphel, Inc.
 * imu_exttime393.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  imu_exttime393.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps
/*
Logs frame synchronization data from other camera (same as frame sync)
When sensors are running in free running mode, each sensor may provide individual timestamp (sampled at vsync)
*/

module  imu_exttime393(
    input                         rst,
    input                         mclk,         // system clock, negedge TODO:COnvert to posedge!
    input                         xclk,         // half frequency (80 MHz nominal)
    input                   [3:0] en_chn_mclk,  // enable per-channel module operation, if all 0 - reset
    // byte-parallel timestamps from 4 sensors channels (in triggered mode all are the same, different only in free running mode)
    // each may generate logger event, channel number encoded in bits 25:24 of the external microseconds

    input                         ts_stb_chn0,  // @mclk 1 clock before ts_rcv_data is valid
    input                   [7:0] ts_data_chn0, // @mclk byte-wide serialized timestamp message received or local

    input                         ts_stb_chn1,  // @mclk 1 clock before ts_rcv_data is valid
    input                   [7:0] ts_data_chn1, // @mclk byte-wide serialized timestamp message received or local

    input                         ts_stb_chn2,  // @mclk 1 clock before ts_rcv_data is valid
    input                   [7:0] ts_data_chn2, // @mclk byte-wide serialized timestamp message received or local

    input                         ts_stb_chn3,  // @mclk 1 clock before ts_rcv_data is valid
    input                   [7:0] ts_data_chn3, // @mclk byte-wide serialized timestamp message received or local
                       
    output                        ts,           // timestamop request
    output reg                    rdy,          // data ready will go up with timestamp request (ahead of actual time), but it will
                                                // anyway be ready sooner, than the local timestamp retrieved ant sent
    input                         rd_stb,       // data read strobe (increment address) - continuous 1'b1 until allthe packet is read out
    output                 [15:0] rdata);       // data out (16 bits)

    reg    [ 4:0] raddr;
    wire          en_mclk = |en_chn_mclk;
    wire    [3:0] ts_stb = {ts_stb_chn3, ts_stb_chn2, ts_stb_chn1, ts_stb_chn0};
    reg           en;   
    
    reg           rd_stb_r;
    reg           rd_start; // 1 xclk pulse at the readout start
    wire          rd_start_mclk;
    reg           ts_full;       // internal 4 x 16 fifo is full (or getting full)
    reg     [3:0] in_full; // input fifo has (or is acquiring) timestamp
    wire          pre_copy_w;
    reg     [1:0] copy_selected; // copying from the winner of 4 input fifos to the x16 output fifo
    reg           copy_started;
    reg     [2:0] copy_cntr;     // byte counter for copying
    reg     [1:0] sel_chn;       // selected channel
    wire    [3:0] chn1hot={(sel_chn == 2'h3), (sel_chn == 2'h2), (sel_chn == 2'h1), (sel_chn == 2'h0)};
    wire          pre_copy_started = copy_selected == 'b01;
    wire    [3:0] chn_pri_w;
    wire    [1:0] chn_enc_w;
    
    reg    [15:0] ts_ram [0:3];  // inner timestamp x16 memory that receives timestamp from one of the 4 input channel fifos
    wire   [31:0] dout_chn;
    wire    [7:0] copy_data;     // data from the selected input fifos
    reg     [7:0] copy_data_r; // low byte of the timestamp data being copied from one of the input fifos to the ts_ram
    
    assign chn_pri_w = {in_full[3] & ~(|in_full[2:0]),
                        in_full[2] & ~(|in_full[1:0]),
                        in_full[1] & ~in_full[0],
                        in_full[0]};
    assign chn_enc_w = {chn_pri_w[3] | chn_pri_w[2],
                        chn_pri_w[3] | chn_pri_w[1]};
    
    assign pre_copy_w = (|in_full) && !copy_selected[0] && !ts_full;
    assign copy_data  = dout_chn[sel_chn * 8 +: 8]; // 4:1 mux
    
// acquire external timestamps @ mclk
    
    always @ (posedge mclk) begin
    
        copy_started <= pre_copy_started;
        if      (!en_mclk)         ts_full <= 0;
        else if (pre_copy_started) ts_full <= 1; // turns on before in_full[*] - || will have no glitches
        else if (rd_start_mclk)    ts_full <= 0;
        
        if (!en_mclk) in_full <= 0;
        else          in_full <= en_chn_mclk & (ts_stb | (in_full & ~(chn1hot & {4{copy_started}})));
        
        copy_selected <= {copy_selected[0], pre_copy_w | (copy_selected[0] & ~(&copy_cntr[2:1]))}; // off at count 6
        
        if (pre_copy_w) sel_chn <= chn_enc_w;
        
        if (!copy_selected[1]) copy_cntr <= 4;             // reverse order - timestamp message start with seconds, here usec first
        else                   copy_cntr <= copy_cntr + 1;
        
        copy_data_r <= copy_data; // previous data is low byte
        // write x16 timestamp data to RAM, insert channel number into unused microseconds byte
        if (copy_selected[1] && copy_cntr[0]) ts_ram[copy_cntr[2:1]] <= {copy_selected[0]?copy_data:{6'b0,sel_chn},copy_data_r};
         
    end

    assign rdata[15:0] = ts_ram[raddr[1:0]];

    
    always @ (posedge xclk) begin
        en <=       en_mclk;
        rd_stb_r <= rd_stb;
        rd_start <= en &&  rd_stb && ! rd_stb_r;
        if (!en || ts)   raddr[4:0] <= 5'h0;
        else if (rd_stb) raddr[4:0] <= raddr[4:0] + 1;
        
        if      (!en)                          rdy <= 1'b0;
        else if (ts)                           rdy <= 1'b1; // too early, but it will become ready in time, before the local timestamp 
        else if (rd_stb && (raddr[1:0]==2'h3)) rdy <= 1'b0;
    end
    
    
    
    timestamp_fifo timestamp_fifo_chn0_i (
        .rst      (rst),                                  // input
        .sclk     (mclk),                                 // input
        .pre_stb  (ts_stb[0]),                            // input
        .din      (ts_data_chn0),                         // input[7:0] 
        .aclk     (mclk),                                 // input
        .advance  (ts_stb[0]),                            // enough time 
        .rclk     (mclk),                                 // input
        .rstb     (pre_copy_started && (sel_chn == 2'h0)),// input
        .dout     (dout_chn[0 * 8 +: 8])                  // output[7:0] reg valid with copy_selected[1]
    );

    timestamp_fifo timestamp_fifo_chn1_i (
        .rst      (rst),                                  // input
        .sclk     (mclk),                                 // input
        .pre_stb  (ts_stb[1]),                            // input
        .din      (ts_data_chn1),                         // input[7:0] 
        .aclk     (mclk),                                 // input
        .advance  (ts_stb[1]),                            // enough time 
        .rclk     (mclk),                                 // input
        .rstb     (pre_copy_started && (sel_chn == 2'h1)),// input
        .dout     (dout_chn[1 * 8 +: 8])                  // output[7:0] reg valid with copy_selected[1]
    );

    timestamp_fifo timestamp_fifo_chn2_i (
        .rst      (rst),                                  // input
        .sclk     (mclk),                                 // input
        .pre_stb  (ts_stb[2]),                            // input
        .din      (ts_data_chn2),                         // input[7:0] 
        .aclk     (mclk),                                 // input
        .advance  (ts_stb[2]),                            // enough time 
        .rclk     (mclk),                                 // input
        .rstb     (pre_copy_started && (sel_chn == 2'h2)),// input
        .dout     (dout_chn[2 * 8 +: 8])                  // output[7:0] reg valid with copy_selected[1]
    );

    timestamp_fifo timestamp_fifo_chn3_i (
        .rst      (rst),                                  // input
        .sclk     (mclk),                                 // input
        .pre_stb  (ts_stb[3]),                            // input
        .din      (ts_data_chn3),                         // input[7:0] 
        .aclk     (mclk),                                 // input
        .advance  (ts_stb[3]),                            // enough time 
        .rclk     (mclk),                                 // input
        .rstb     (pre_copy_started && (sel_chn == 2'h3)),// input
        .dout     (dout_chn[3 * 8 +: 8])                  // output[7:0] reg valid with copy_selected[1]
    );


    pulse_cross_clock i_rd_start_mclk (.rst(1'b0), .src_clk(xclk), .dst_clk(mclk), .in_pulse(rd_start), .out_pulse(rd_start_mclk),.busy());

// generate timestamp request as soon as one of the sub-channels starts copying. That time stamp will be stored for this (ext) channel
    pulse_cross_clock i_ts           (.rst(1'b0), .src_clk(mclk), .dst_clk(xclk), .in_pulse(pre_copy_w), .out_pulse(ts),.busy());

endmodule

