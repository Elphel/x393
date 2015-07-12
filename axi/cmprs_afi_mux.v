/*******************************************************************************
 * Module: cmprs_afi_mux
 * Date:2015-06-26  
 * Author: andrey     
 * Description: Writes comressor data from up to 4 channels to system memory over AXI_HP
 *
 * Copyright (c) 2015 Elphel, Inc.
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
    parameter CMPRS_AFIMUX_ADDR=                'h140, //TODO: assign valid address
    parameter CMPRS_AFIMUX_MASK=                'h3f0,
    parameter CMPRS_AFIMUX_EN=                  'h0, // enables (gl;obal and per-channel)
    parameter CMPRS_AFIMUX_RST=                 'h1, // per-channel resets
    parameter CMPRS_AFIMUX_MODE=                'h2, // per-channel select - which register to return as status
    parameter CMPRS_AFIMUX_STATUS_CNTRL=        'h4, // .. 'h7
    parameter CMPRS_AFIMUX_SA_LEN=              'h8, // .. 'hf

    parameter CMPRS_AFIMUX_STATUS_REG_ADDR=     'h20,  //Uses 4 locations TODO: assign valid address
    parameter CMPRS_AFIMUX_WIDTH =              26, // maximal for status: currently only works with 26)
    parameter CMPRS_AFIMUX_CYCBITS =            3,
    parameter AFI_MUX_BUF_LATENCY =             2  // buffers read latency from fifo_ren* to fifo_rdata* valid : 2 if no register layers are used
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
    output                        fifo_rst0,      // reset FIFO (set read address to write, reset count)
    output                        fifo_ren0,
    input                  [63:0] fifo_rdata0,
//    input                         fifo_eof0,        // single rclk pulse signalling EOF
    output                        eof_written0,   // confirm frame written over AFI to the system memory (single hclk pulse)
    input                         fifo_flush0,    // EOF, need to output all what is in FIFO (Stays active until enough data chunks are read)
    input                  [7:0]  fifo_count0,     // number of 32-byte chunks in FIFO

    // compressor channel 1
    output                        fifo_rst1,      // reset FIFO (set read address to write, reset count)
    output                        fifo_ren1,
    input                  [63:0] fifo_rdata1,
//    input                         fifo_eof1,        // single rclk pulse signalling EOF
    output                        eof_written1,   // confirm frame written over AFI to the system memory (single hclk pulse)
    input                         fifo_flush1,    // EOF, need to output all what is in FIFO (Stays active until enough data chunks are read)
    input                  [7:0]  fifo_count1,     // number of 32-byte chunks in FIFO

    // compressor channel 2
    output                        fifo_rst2,      // reset FIFO (set read address to write, reset count)
    output                        fifo_ren2,
    input                  [63:0] fifo_rdata2,
//    input                         fifo_eof2,        // single rclk pulse signalling EOF
    output                        eof_written2,   // confirm frame written over AFI to the system memory (single hclk pulse)
    input                         fifo_flush2,    // EOF, need to output all what is in FIFO (Stays active until enough data chunks are read)
    input                  [7:0]  fifo_count2,     // number of 32-byte chunks in FIFO

    // compressor channel 3
    output                        fifo_rst3,      // reset FIFO (set read address to write, reset count)
    output                        fifo_ren3,
    input                  [63:0] fifo_rdata3,
//    input                         fifo_eof3,        // single rclk pulse signalling EOF
    output                        eof_written3,   // confirm frame written over AFI to the system memory (single hclk pulse)
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
    reg         en_d;    // or use it to reset all channels?
    reg   [3:0] en_chn;  // per-channel enable 
    
    wire [31:0] cmd_data;
    wire [ 3:0] cmd_a;
    wire        cmd_we;
    wire        cmd_we_status_w;    
    wire        cmd_we_mode_w;    

    wire        cmd_we_sa_len_w;
    wire        cmd_we_en_w;    
    wire        cmd_we_rst_w; 

    reg [26:0] sa_len_d;
    reg  [2:0] sa_len_wa;
    reg  [3:0] rst_mclk;
    reg  [9:0] en_mclk;

    // hclk domain    
//    reg [26:0] sa_len_d;
//    reg  [2:0] sa_len_wa;
    wire       sa_len_we;
    wire       en_we;
    wire       en_rst;
    
    
       
    
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
    reg   [3:0] busy; // TODO: adjust number of bits. During continuous run busy is deasseted for 1 clock cycle
    wire        done_burst_w; // de-asset busy
    wire        pre_busy_w;
    reg         last_burst_in_frame;
//    reg   [1:0] wlen32; // 2 high bits of burst len (LSB are always 2'b11)
    
    reg   [3:0] wleft; // number of 64-bit words left to be sent - also used as awlen (valid @ awvalid)
    reg   [2:0] chunk_inc;              // how much to increment chunk pointer (1..4)

    reg [ 3:0] reset_pointers;         // per-channel - after chunk_start_hclk or chunk_len_hclk were written or  explicit fifo_rst*
    
    wire        ptr_resetting;          // pointers are being reset in cmprs_afi_mux_ptr module
    
    
    wire [26:0] chunk_addr;
    reg   [1:0] awvalid;
    reg         wvalid;
    reg         wlast;
    reg  [63:0] wdata;     // registered data from one of the 4 buffers
    wire        wdata_en;  // register enable for wdata
    wire  [1:0] wdata_sel; // source select for wdata
    reg   [3:0] fifo_ren;
    
    wire [26:0] chunk_ptr_rd;
    wire [ 3:0] chunk_ptr_ra;
    
    
    

    assign cmd_we_status_w = cmd_we && ((cmd_a & 'hc) ==       CMPRS_AFIMUX_STATUS_CNTRL);    
    assign cmd_we_mode_w =   cmd_we && (cmd_a ==               CMPRS_AFIMUX_MODE);    

    assign cmd_we_sa_len_w = cmd_we && ((cmd_a & 'h8) ==       CMPRS_AFIMUX_SA_LEN);
    assign cmd_we_en_w =     cmd_we && (cmd_a ==               CMPRS_AFIMUX_EN);    
    assign cmd_we_rst_w =    cmd_we && (cmd_a ==               CMPRS_AFIMUX_RST);    
    
    
    
    // use last_chunk_w to apply a special id to waddr and wdata and watch for it during readout
    // compose ID of channel number, frame bumber LSBs and last/not last chunk
    assign last_chunk_w[3:0] = {(left_to_eof[3]==1)?1'b1:1'b0,
                                (left_to_eof[2]==1)?1'b1:1'b0,
                                (left_to_eof[1]==1)?1'b1:1'b0,
                                (left_to_eof[0]==1)?1'b1:1'b0};
    
    assign pre_busy_w = !busy[0] && ready_to_start && need_to_bother && !ptr_resetting;
    assign done_burst_w = busy[0] && !(|wleft[3:1]);  // when wleft[3:0] == 0, busy is 0
    assign {fifo_rst3, fifo_rst2, fifo_rst1, fifo_rst0} = reset_pointers;
    assign {fifo_ren3, fifo_ren2, fifo_ren1, fifo_ren0} = fifo_ren;
    
    assign afi_awaddr =  {chunk_addr,5'b0};
    assign afi_awid =    {1'b0,wleft[3:2],last_burst_in_frame,cur_chn}; 
    assign afi_awvalid = awvalid[1];
    assign afi_awlen = {wleft[3:2],2'b11};
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
    
    always @ (posedge mclk) begin
        if (cmd_we_sa_len_w) begin
            sa_len_d <= cmd_data[26:0];
            sa_len_wa <= cmd_a[2:0];
        end
        if (cmd_we_en_w)  en_mclk <=  cmd_data[9:0];
        if (cmd_we_rst_w) rst_mclk <= cmd_data[3:0];
    end

    always @ (posedge hclk) begin
        reset_pointers <= (en && !en_d)? 4'hf : (en_rst ? rst_mclk : 4'h0);
        if (en_we && en_mclk[1]) en_chn[0] <= en_mclk[0];
        if (en_we && en_mclk[3]) en_chn[1] <= en_mclk[2];
        if (en_we && en_mclk[5]) en_chn[2] <= en_mclk[4];
        if (en_we && en_mclk[7]) en_chn[3] <= en_mclk[6];
        if (en_we && en_mclk[9]) en <=        en_mclk[8];
    end

    
    always @ (posedge hclk) begin
        en_d <= en;
    
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
        else if (pre_busy_w)   busy <= {busy[2:0],1'b1};
        else if (done_burst_w) busy <= 0; // {busy[2:0],1'b0};
        
        if      (!en)        wleft <= 0;
        else if (pre_busy_w) wleft <= {(|counts_corr2[7:2])? 2'b11 : left_to_eof[winner2][1:0], 2'b11};
        else if (wleft != 0) wleft <= wleft - 1;
        

        if      (!en)        wvalid <= 0;
        else if (pre_busy_w) wvalid <= 1;
        else if (wlast)      wvalid <= 0; // should be after pre_busy_w as both can happen simultaneously

        if      (!en)          fifo_ren <= 0;
        else if (pre_busy_w)   fifo_ren <= {(winner2 == 3) ?1'b1:1'b0,
                                            (winner2 == 2) ?1'b1:1'b0,
                                            (winner2 == 1) ?1'b1:1'b0,
                                            (winner2 == 0) ?1'b1:1'b0};
        else if (wlast)        fifo_ren <= 0;
        
        awvalid <= {awvalid[0],pre_busy_w}; // no need to wait for afi_awready, will use fifo levels to enable pre_busy_w
        
        if (pre_busy_w)  begin
            cur_chn <= winner2;
            last_burst_in_frame <= last_chunk_w[winner2];
        end
        
        wlast <= done_burst_w; // when wleft==4'h1

        // wdata register mux
        if (wdata_en) wdata <= wdata_sel[1]?(wdata_sel[1]?fifo_rdata3:fifo_rdata2):(wdata_sel[1]?fifo_rdata1:fifo_rdata0);

        if (pre_busy_w) chunk_inc <= (|counts_corr2[7:2])?
                                       3'h4 :
                                       ({1'b0,left_to_eof[winner2][1:0]} + 3'h1);
        
    end

    // delay write channel controls signal to match data latency. wid bits will be optimized (6 -> 3)    
    dly_16 #(
        .WIDTH(8)
    ) afi_wx_i (
        .clk       (hclk), // input
        .rst       (!en),  // input
        .dly       (AFI_MUX_BUF_LATENCY), // input[3:0] will delay by AFI_MUX_BUF_LATENCY+1 (normally 3) 
        .din       ({    wvalid,     wlast, afi_awid}), // input[0:0] 
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
    
    cmd_deser #(
        .ADDR       (CMPRS_AFIMUX_ADDR),
        .ADDR_MASK  (CMPRS_AFIMUX_MASK),
        .NUM_CYCLES (6),
        .ADDR_WIDTH (4),
        .DATA_WIDTH (32)
    ) cmd_deser_32bit_i (
        .rst        (rst),      // input
        .clk        (mclk),     // input
        .ad         (cmd_ad),   // input[7:0] 
        .stb        (cmd_stb),  // input
        .addr       (cmd_a),    // output[3:0] 
        .data       (cmd_data), // output[31:0] 
        .we         (cmd_we)    // output
    );
    
    
    wire [26:0] chunk_ptr_rd01[0:1];

    cmprs_afi_mux_ptr cmprs_afi_mux_ptr_i (
        .hclk                (hclk),                // input
        .sa_len_di           (sa_len_d[26:0]),      // input[26:0] 
        .sa_len_wa           (sa_len_wa[2:0]),      // input[2:0] 
        .sa_len_we           (sa_len_we),           // input
        .en                  (en),                  // input
        .reset_pointers      (reset_pointers),      // input[3:0] 
        .pre_busy_w          (pre_busy_w),          // input
        .winner_channel      (winner2),             // input[1:0] 
        .need_to_bother      (need_to_bother),      // input
        .chunk_inc           (chunk_inc),           // input[2:0] 
        .last_burst_in_frame (last_burst_in_frame), // input
        .busy                (busy),                // input[3:0] 
        .ptr_resetting       (ptr_resetting),       // output
        .chunk_addr          (chunk_addr),          // output[26:0] reg 
        .chunk_ptr_ra        (chunk_ptr_ra[2:0]),   // input[2:0] 
        .chunk_ptr_rd        (chunk_ptr_rd01[0])    // output[26:0] 
    );
    assign chunk_ptr_rd=chunk_ptr_ra[3]?chunk_ptr_rd01[1]:chunk_ptr_rd01[0];
    cmprs_afi_mux_ptr_wresp cmprs_afi_mux_ptr_wresp_i (
        .hclk                (hclk),                // input
        .length_di           (sa_len_d[26:0]),      // input[26:0] 
        .length_wa           (sa_len_wa[1:0]),      // input[1:0] 
        .length_we           (sa_len_we & sa_len_wa[2]), // input
        .en                  (en),                  // input
        .reset_pointers      (reset_pointers),      // input[3:0] 
        .chunk_ptr_ra        (chunk_ptr_ra[2:0]),   // input[2:0] 
        .chunk_ptr_rd        (chunk_ptr_rd01[1]),   // output[26:0] 
        .eof_written         ({eof_written3,eof_written2,eof_written1,eof_written0}), // output[3:0] reg 
        .afi_bvalid          (afi_bvalid),          // input
        .afi_bready          (afi_bready),          // output
        .afi_bid             (afi_bid)              // input[5:0] 
    );

    cmprs_afi_mux_status #(
        .CMPRS_AFIMUX_STATUS_REG_ADDR (CMPRS_AFIMUX_STATUS_REG_ADDR), // uses 4 locations
        .CMPRS_AFIMUX_WIDTH(CMPRS_AFIMUX_WIDTH),
        .CMPRS_AFIMUX_CYCBITS(CMPRS_AFIMUX_CYCBITS)
    ) cmprs_afi_mux_status_i (
        .rst          (rst), // input
        .hclk         (hclk), // input
        .mclk         (mclk), // input
        .cmd_data     (cmd_data[15:0]), // input[15:0] 
        .cmd_a        (cmd_a[1:0]), // input[1:0] 
        .status_we    (cmd_we_status_w), // input
        .mode_we      (cmd_we_mode_w), // input
        .status_ad    (status_ad), // output[7:0] 
        .status_rq    (status_rq), // output
        .status_start (status_start), // input
        .en           (en), // input
        .chunk_ptr_ra (chunk_ptr_ra), // output[3:0] reg 
        .chunk_ptr_rd (chunk_ptr_rd[CMPRS_AFIMUX_WIDTH-1:0]) // input[25:0] 
    );
    pulse_cross_clock sa_len_we_i (.rst(rst), .src_clk(mclk), .dst_clk(hclk), .in_pulse(cmd_we_sa_len_w), .out_pulse(sa_len_we),.busy());
    pulse_cross_clock en_we_i     (.rst(rst), .src_clk(mclk), .dst_clk(hclk), .in_pulse(cmd_we_en_w),     .out_pulse(en_we),    .busy());
    pulse_cross_clock en_rst_i    (.rst(rst), .src_clk(mclk), .dst_clk(hclk), .in_pulse(cmd_we_rst_w),    .out_pulse(en_rst),.busy());

endmodule
