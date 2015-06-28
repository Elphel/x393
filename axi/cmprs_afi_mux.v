/*******************************************************************************
 * Module: cmprs_afi_mux
 * Date:2015-06-26  
 * Author: andrey     
 * Description: Writes comressor data from up to 4 channels to system memory over AXI_HP
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * cmprs_afi_mux.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  cmprs_afi_mux.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  cmprs_afi_mux#(
    parameter AFI_MUX_BUF_LATENCY = 2  // buffers read latency from fifo_ren* to fifo_rdata* valid : 2 if no register layers are used
)(
    input                         rst,
    input                         mclk, // for command/status
    input                         hclk,   // global clock to run axi_hp @ 150MHz, shared by all compressor channels
    // programming interface
    input                   [7:0] cmd_ad,      // byte-serial command address/data (up to 6 bytes: AL-AH-D0-D1-D2-D3 
    input                         cmd_stb,     // strobe (with first byte) for the command a/d
    output                  [7:0] status_ad,   // status address/data - up to 5 bytes: A - {seq,status[1:0]} - status[2:9] - status[10:17] - status[18:25]
    output                        status_rq,   // input request to send status downstream
    input                         status_start, // Acknowledge of the first status packet byte (address)
    
    // compressor channel 0
    output                        fifo_rst0,      // reset FIFO (set read adderss to write, reset count)
    output                        fifo_ren0,
    input                  [63:0] fifo_rdata0,
//    input                         fifo_eof0,        // single rclk pulse signalling EOF
    output                        eof_written0,   // confirm frame written ofer AFI to the system memory (single rclk pulse)
    input                         fifo_flush0,    // EOF, need to output all what is in FIFO (Stays active until enough data chunks are read)
    input                  [7:0]  fifo_count0,     // number of 32-byte chunks in FIFO

    // compressor channel 1
    output                        fifo_rst1,      // reset FIFO (set read adderss to write, reset count)
    output                        fifo_ren1,
    input                  [63:0] fifo_rdata1,
//    input                         fifo_eof1,        // single rclk pulse signalling EOF
    output                        eof_written1,   // confirm frame written ofer AFI to the system memory (single rclk pulse)
    input                         fifo_flush1,    // EOF, need to output all what is in FIFO (Stays active until enough data chunks are read)
    input                  [7:0]  fifo_count1,     // number of 32-byte chunks in FIFO

    // compressor channel 2
    output                        fifo_rst2,      // reset FIFO (set read adderss to write, reset count)
    output                        fifo_ren2,
    input                  [63:0] fifo_rdata2,
//    input                         fifo_eof2,        // single rclk pulse signalling EOF
    output                        eof_written2,   // confirm frame written ofer AFI to the system memory (single rclk pulse)
    input                         fifo_flush2,    // EOF, need to output all what is in FIFO (Stays active until enough data chunks are read)
    input                  [7:0]  fifo_count2,     // number of 32-byte chunks in FIFO

    // compressor channel 3
    output                        fifo_rst3,      // reset FIFO (set read adderss to write, reset count)
    output                        fifo_ren3,
    input                  [63:0] fifo_rdata3,
//    input                         fifo_eof3,        // single rclk pulse signalling EOF
    output                        eof_written3,   // confirm frame written ofer AFI to the system memory (single rclk pulse)
    input                         fifo_flush3,    // EOF, need to output all what is in FIFO (Stays active until enough data chunks are read)
    input                  [7:0]  fifo_count3,     // number of 32-byte chunks in FIFO
    
    // axi_hp signals write channel
    // write address
    output                 [31:0] afi_awaddr,
    output                        afi_awvalid,
    input                         afi_awready, // @SuppressThisWarning VEditor unused - used FIF0 level
    output                 [ 5:0] afi_awid,
    output                 [ 1:0] afi_awlock,
    output                 [ 3:0] afi_awcache,
    output                 [ 2:0] afi_awprot,
    output                 [ 3:0] afi_awlen,
    output                 [ 2:0] afi_awsize,
    output                 [ 1:0] afi_awburst,
    output                 [ 3:0] afi_awqos,
    // write data
    output                 [63:0] afi_wdata,
    output                        afi_wvalid,
    input                         afi_wready,  // @SuppressThisWarning VEditor unused - used FIF0 level
    output                 [ 5:0] afi_wid,
    output                        afi_wlast,
    output                 [ 7:0] afi_wstrb,
    // write response
    input                         afi_bvalid,
    output                        afi_bready,
    input                  [ 5:0] afi_bid,
    input                  [ 1:0] afi_bresp,    // @SuppressThisWarning VEditor unused
    // PL extra (non-AXI) signals
    input                  [ 7:0] afi_wcount,
    input                  [ 5:0] afi_wacount,
    output                        afi_wrissuecap1en
);
    reg         en;      // enable mux
    reg   [3:0] en_chn;  // per-channel enable 
//    reg   [2:0] cur_chn;          // 'b0xx - none, 'b1** - ** - channel number (should match fifo_ren*)
    reg   [1:0] cur_chn;           // 'b0xx - none, 'b1** - ** - channel number (should match fifo_ren*)
    reg   [7:0] left_to_eof[0:3];  // number of chunks left to end of frame
    reg   [3:0] fifo_flush_d;      // fifo_flush* delayed by 1 clk (to detect rising edge
    reg   [3:0] eof_stb;           // single-cycle pulse after fifo_flush is asserted
//    reg   [1:0] w64_cnt;           // count 64-bit words in a chunk
    reg   [8:0] counts_corr0[0:3]; // registers to hold corrected (decremented currently processed ones if any) fifo count values, MSB - needs flush
    reg   [8:0] counts_corr1[0:1]; // first arbitration level winning values
    reg   [8:0] counts_corr2;      // second arbitration level winning values
    
    reg   [1:0] winner1;           // 2 first level arbitration winners
    reg   [1:0] winner2;           // 2-bit second level arbitration winner
    
//    reg   [1:0] cur_chn;          // Can it be the same as cur_chn?
    wire  [7:0] fifo_count0_m1 = fifo_count0 - 1;
    wire  [7:0] fifo_count1_m1 = fifo_count1 - 1;
    wire  [7:0] fifo_count2_m1 = fifo_count2 - 1;
    wire  [7:0] fifo_count3_m1 = fifo_count3 - 1;
    // See if we need to bother - any channel needs flushing or has >= 4 of 32-byte chunks to transfer in a single AXI 16-burst 64 bit wide (latency = 4)
    wire        need_to_bother = |counts_corr2[8:2];
    reg         ready_to_start; // TBD: either idle or soon will finish the previous burst (include AFI FIFO level here too?)
    wire  [3:0] last_chunk_w;
    reg   [2:0] busy; // TODO: adjust number of bits. During continuous run busy is deasseted for 1 clock cycle
    wire        done_burst_w; // de-asset busy
    wire        pre_busy_w;
    reg         last_burst_in_frame;
//    reg   [1:0] wlen32; // 2 high bits of burst len (LSB are always 2'b11)
    
    reg   [3:0] wleft; // number of 64-bit words left to be sent - also used as awlen (valid @ awvalid)
    
    reg  [26:0] chunk_addr_chn[0:3]; //system memory address in "chunks" (32-bytes)
    reg  [26:0] chunk_addr;
    reg         awvalid;
    reg         wvalid;
    reg         wlast;
    reg   [3:0] eof_written;
    reg  [63:0] wdata;     // registered data from one of the 4 buffers
    wire        wdata_en;  // register enable for wdata
    wire  [1:0] wdata_sel; // source select for wdata
    reg   [3:0] fifo_ren;
    // use last_chunk_w to apply a special id to waddr and wdata and watch for it during readout
    // compose ID of channel number, frame bumber LSBs and last/not last chunk
//    assign last_chunk_w[3:0] = {~(|left_to_eof[3]),~(|left_to_eof[2]),~(|left_to_eof[1]),~(|left_to_eof[0])};
    assign last_chunk_w[3:0] = {(left_to_eof[3]==1)?1'b1:1'b0,
                                (left_to_eof[2]==1)?1'b1:1'b0,
                                (left_to_eof[1]==1)?1'b1:1'b0,
                                (left_to_eof[0]==1)?1'b1:1'b0};
    
    assign pre_busy_w = !busy && ready_to_start && need_to_bother;
    assign done_burst_w = busy && !(|wleft[3:1]);  // when wleft[3:0] == 0, busy is 0
    assign eof_written0 = eof_written[0];
    assign eof_written1 = eof_written[1];
    assign eof_written2 = eof_written[2];
    assign eof_written3 = eof_written[3];
    assign fifo_ren0 = fifo_ren[0];
    assign fifo_ren1 = fifo_ren[1];
    assign fifo_ren2 = fifo_ren[2];
    assign fifo_ren3 = fifo_ren[3];
    
    assign afi_awaddr =  {chunk_addr,5'b0};
    assign afi_awid =    {3'b0,last_burst_in_frame,cur_chn}; 
    assign afi_awvalid = awvalid;
    assign afi_awlen = wleft;
//    assign afi_wid = {3'b0,last_burst_in_frame,cur_chn};
//    assign afi_wvalid = wvalid;
//    assign afi_wlast = wlast;
    assign afi_wdata = wdata;
    assign afi_bready = 1'b1; // always ready
    
// other fixed-value AFI signals
    assign afi_awlock =        2'h0;
    assign afi_awcache =       4'h3;
    assign afi_awprot =        3'h0;
    assign afi_awsize =        3'h3;
    assign afi_awburst =       2'h1;
    assign afi_awqos =         4'h0;
    assign afi_wstrb =         8'hff;
    assign afi_wrissuecap1en = 1'b0;
    
    
    
    always @ (posedge hclk) begin
        ready_to_start <= en && // ready to strta a burst
                          !afi_wacount[5] && !(&afi_wacount[4:1]) &&  // >=2 free 
                          !afi_wcount[7] &&  !(&afi_wcount[6:3]);     // >=8 free (4 would be enough too)
    
        fifo_flush_d <= {fifo_flush3,fifo_flush2,fifo_flush1,fifo_flush0};
        eof_stb <= {fifo_flush3 & ~fifo_flush_d[3],
                    fifo_flush2 & ~fifo_flush_d[2],
                    fifo_flush1 & ~fifo_flush_d[1],
                    fifo_flush0 & ~fifo_flush_d[0]};
                    
        // TODO: change &w64_cnt[1:0] so left_to_eof[*] will be updated earlier and valid at pre_busy_w       
        // Done, updating at the first (not last) word of 4
        if (eof_stb[0])                      left_to_eof[0] <= fifo_count0 - (fifo_ren0 & (&wleft[1:0]));
        else if (fifo_ren0 & (&wleft[1:0]))  left_to_eof[0] <= left_to_eof[0] - 1;
    
        if (eof_stb[1])                      left_to_eof[1] <= fifo_count1 - (fifo_ren1 & (&wleft[1:0]));
        else if (fifo_ren1 & (&wleft[1:0]))  left_to_eof[1] <= left_to_eof[1] - 1;
    
        if (eof_stb[2])                      left_to_eof[2] <= fifo_count2 - (fifo_ren2 & (&wleft[1:0]));
        else if (fifo_ren2 & (&wleft[1:0]))  left_to_eof[2] <= left_to_eof[2] - 1;
    
        if (eof_stb[3])                      left_to_eof[3] <= fifo_count3 - (fifo_ren3 & (&wleft[1:0]));
        else if (fifo_ren3 & (&wleft[1:0]))  left_to_eof[3] <= left_to_eof[3] - 1;
    
        // Calculate corrected values decrementing currently served channel (if any) values by 1 (latency 1 clk)
        
        if      ((fifo_count0 == 0) || !en_chn[0]) counts_corr0[0] <= 0;
        else if (fifo_ren[0])                      counts_corr0[0] <= (fifo_count0_m1 == 0)? 0 : {fifo_flush0,fifo_count0_m1};
        else                                       counts_corr0[0] <= {fifo_flush0,fifo_count0};

        if      ((fifo_count1 == 0) || !en_chn[1]) counts_corr0[1] <= 0;
        else if (fifo_ren[1])                      counts_corr0[1] <= (fifo_count1_m1 == 0)? 0 : {fifo_flush1,fifo_count1_m1};
        else                                       counts_corr0[1] <= {fifo_flush1,fifo_count1};

        if      ((fifo_count2 == 0) || !en_chn[2]) counts_corr0[2] <= 0;
        else if (fifo_ren[2])                      counts_corr0[2] <= (fifo_count2_m1 == 0)? 0 : {fifo_flush2,fifo_count2_m1};
        else                                       counts_corr0[2] <= {fifo_flush2,fifo_count2};

        if      ((fifo_count3 == 0) || !en_chn[3]) counts_corr0[3] <= 0;
        else if (fifo_ren[3])                      counts_corr0[3] <= (fifo_count3_m1 == 0)? 0 : {fifo_flush3,fifo_count3_m1};
        else                                       counts_corr0[3] <= {fifo_flush3,fifo_count3};

        // 2-level arbitration
        // first arbitration level (latency 2 clk)
        if (counts_corr0[1] > counts_corr0[0]) begin
            counts_corr1[0] <= counts_corr0[1];
            winner1[0] <=      1;
        end else begin
            counts_corr1[0] <= counts_corr0[0];
            winner1[0] <=      0;
        end

        if (counts_corr0[3] > counts_corr0[2]) begin
            counts_corr1[1] <= counts_corr0[3];
            winner1[1] <=      1;
        end else begin
            counts_corr1[1] <= counts_corr0[2];
            winner1[1] <=      0;
        end
        
        // second arbitration level (latency 3 clk)
        if (counts_corr1[1] > counts_corr1[0]) begin
            counts_corr2 <= counts_corr1[1];
            winner2 <=      {1'b1,winner1[1]};
        end else begin
            counts_corr2 <= counts_corr1[0];
            winner2 <=      {1'b0,winner1[0]};
        end
        //ready_to_start need_to_bother
        //done_burst
        if      (!en)          busy <= 0;
        else if (pre_busy_w)   busy <= {busy[1:0],1'b1};
        else if (done_burst_w) busy <= {busy[1:0],1'b0};
        
        if      (!en)        wleft <= 0;
        else if (pre_busy_w) wleft <= {(|counts_corr2[7:2])? 2'b11 : left_to_eof[winner2][1:0], 2'b11};
        else if (wleft != 0) wleft <= wleft - 1;

        if      (!en)        wvalid <= 0;
        else if (pre_busy_w) wvalid <= 1;
        else if (wlast)      wvalid <= 0; // should be after pre_busy_w as both can happen simultaneously

//fifo_ren
        if      (!en)          fifo_ren <= 0;
        else if (pre_busy_w)   fifo_ren <= {(winner2 == 3) ?1'b1:1'b0,
                                            (winner2 == 2) ?1'b1:1'b0,
                                            (winner2 == 1) ?1'b1:1'b0,
                                            (winner2 == 0) ?1'b1:1'b0};
        else if (wlast)        fifo_ren <= 0;
        
        awvalid <= pre_busy_w; // no need to wait for afi_awready, will use fifo levels to enable pre_busy_w
        if (pre_busy_w)  begin
            cur_chn <= winner2;
            last_burst_in_frame <= last_chunk_w[winner2];
            wleft <= {(|counts_corr2[7:2])? 2'b11 : left_to_eof[winner2][1:0], 2'b11};
            chunk_addr <= chunk_addr_chn[winner2];
                
        end
        
        wlast <= done_burst_w; // when wleft==4'h1
        // wdata register mux
        if (wdata_en) wdata <= wdata_sel[1]?(wdata_sel[1]?fifo_rdata3:fifo_rdata2):(wdata_sel[1]?fifo_rdata1:fifo_rdata0);
        
        // Watch write responce channel, detect EOF IDs, generate eof_written* output signals
        eof_written[0] <=  afi_bvalid && (afi_bid[2:0]== 3'h4);
        eof_written[1] <=  afi_bvalid && (afi_bid[2:0]== 3'h5);
        eof_written[2] <=  afi_bvalid && (afi_bid[2:0]== 3'h6);
        eof_written[3] <=  afi_bvalid && (afi_bid[2:0]== 3'h7);
        
        // calculate and rollover channel addresses
        
        
    end

    // delay write channel controls signal to match data latency. wid bits will be optimized (6 -> 3)    
    dly_16 #(
        .WIDTH(8)
    ) afi_wx_i (
        .clk       (hclk), // input
        .rst       (!en),  // input
        .dly       (AFI_MUX_BUF_LATENCY), // input[3:0] will delay by AFI_MUX_BUF_LATENCY+1 (normally 3) 
        .din       ({    wvalid,     wlast, 3'b0,last_burst_in_frame, cur_chn}), // input[0:0] 
        .dout      ({afi_wvalid, afi_wlast, afi_wid}) // output[0:0] 
    );

    dly_16 #(
        .WIDTH(3)
    ) afi_wdata_i (
        .clk       (hclk), // input
        .rst       (!en),  // input
        .dly       (AFI_MUX_BUF_LATENCY-1), // input[3:0] will delay by AFI_MUX_BUF_LATENCY+1 (normally 3) 
        .din       ({wvalid, cur_chn}), // input[0:0] 
        .dout      ({wdata_en,wdata_sel}) // output[0:0] 
    );


endmodule

