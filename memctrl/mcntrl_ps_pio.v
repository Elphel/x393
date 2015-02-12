/*******************************************************************************
 * Module: mcntrl_ps_pio
 * Date:2015-01-27  
 * Author: andrey     
 * Description: Read/write channels to DDR3 memory with software-programmable
 * command sequence
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * mcntrl_ps_pio.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  mcntrl_ps_pio.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps
`undef DEBUG_FIFO
module  mcntrl_ps_pio#(
    parameter MCNTRL_PS_ADDR=                    'h100,
    parameter MCNTRL_PS_MASK=                    'h3e0, // both channels 0 and 1
    parameter MCNTRL_PS_STATUS_REG_ADDR=         'h2,
    parameter MCNTRL_PS_EN_RST=                  'h0,
    parameter MCNTRL_PS_CMD=                     'h1,
    parameter MCNTRL_PS_STATUS_CNTRL=            'h2
)(
    input                        rst,
    input                        mclk,
// programming interface
    input                  [7:0] cmd_ad,      // byte-serial command address/data (up to 6 bytes: AL-AH-D0-D1-D2-D3 
    input                        cmd_stb,     // strobe (with first byte) for the command a/d
    
    output                 [7:0] status_ad,     // byte-wide address/data
    output                       status_rq,     // request to send downstream (last byte with rq==0)
    input                        status_start,   // acknowledge of address (first byte) from downsteram   
    
// buffers R/W access 
// read port 0   
    input                        port0_clk,
    input                        port0_re,
    input                        port0_regen, 
    input                [9:0]   port0_addr, // includes page
    output              [31:0]   port0_data,
// write port 1
    input                        port1_clk,
    input                        port1_we,
    input                [9:0]   port1_addr, // includes page
    input               [31:0]   port1_data,
// memory controller interface
// read port 0   
    output reg                   want_rq0,
    output reg                   need_rq0,
    input                        channel_pgm_en0, 
    output               [9:0]   seq_data0, // only address 
//    output                       seq_wr0, // never generated
    output                       seq_set0,
    input                        seq_done0,
    input                        buf_wr_chn0,
    input                        buf_wpage_nxt_chn0,
//    input                        buf_waddr_rst_chn0, 
    input               [63:0]   buf_wdata_chn0,
// write port 1
    output reg                   want_rq1,
    output reg                   need_rq1,
    input                        channel_pgm_en1, 
//    output               [9:0]   seq_data1, // only address (with seq_set) connect externally to seq_data0
//    output                       seq_wr1, // never generated
//    output                       seq_set1, // connect externally to seq_set0
    input                        seq_done1,
    input                        rpage_nxt_chn1,
    input                        buf_rd_chn1,
//    input                        buf_raddr_rst_chn1, 
    output              [63:0]   buf_rdata_chn1 
);
 localparam CMD_WIDTH=14;
 localparam CMD_FIFO_DEPTH=4;
 wire                     channel_pgm_en=channel_pgm_en0 || channel_pgm_en1;
 wire                     seq_done= seq_done0 || seq_done1;


 wire               [4:0] cmd_a; // just to compare
 wire              [31:0] cmd_data;
 wire                     cmd_we;
 wire               [1:0] status_data;
 
 wire     [CMD_WIDTH-1:0] cmd_out; 
 wire                     cmd_nempty;
 wire                     cmd_half_full; // to status bit

// decoded commands
 wire                     set_cmd_w;
 wire                     set_status_w;
 wire                     set_en_rst; // set enable, reset register
 reg                [1:0] en_reset;//
 wire                     chn_rst = ~en_reset[0]; // resets command, including fifo;
 wire                     chn_en = &en_reset[1];   // enable requests by channle (continue ones in progress)
 reg                      mem_run;              // sequencer pgm granted and set, waiting/executing memory transfer to/from buffur 0/1
 wire                     busy;
 wire                     start;
 reg                [1:0] page;
 reg                [1:0] page_neg;
 reg                [1:0] cmd_set_d;
 reg                      cmd_set_d_neg;
// reg                      chn_run; // running memory access to channel 0/1
// command bit fields
 wire               [9:0] cmd_seq_a= cmd_out[9:0];
 wire               [1:0] cmd_page=  cmd_out[11:10];
 wire                     cmd_need=  cmd_out[12];
 wire                     cmd_chn=   cmd_out[13];
 reg                      cmd_set;
 
 assign busy= want_rq0 || need_rq0 ||want_rq1 || need_rq1 || mem_run;
 assign start= chn_en && !busy && cmd_nempty;
 assign seq_data0= cmd_seq_a;
 assign seq_set0=cmd_set;
 assign status_data=   {cmd_half_full,cmd_nempty | busy};
 assign set_cmd_w =    cmd_we && (cmd_a== MCNTRL_PS_CMD);
 assign set_status_w = cmd_we && (cmd_a== MCNTRL_PS_STATUS_CNTRL);
 assign set_en_rst =   cmd_we && (cmd_a== MCNTRL_PS_EN_RST);
    always @ (posedge rst or posedge mclk) begin
        if (rst) en_reset <= 0;
        else if (set_en_rst) en_reset <= cmd_data[1:0];
        
        if (rst) begin
            want_rq0 <= 0;
            need_rq0 <= 0;
            want_rq1 <= 0;
            need_rq1 <= 0;
        end else if (chn_rst || channel_pgm_en) begin
            want_rq0 <= 0;
            need_rq0 <= 0;
            want_rq1 <= 0;
            need_rq1 <= 0;
        end else if (start) begin
            want_rq0 <= !cmd_chn;
            need_rq0 <= !cmd_chn && cmd_need;
            want_rq1 <= cmd_chn;
            need_rq1 <= cmd_chn && cmd_need;
        end
        
        if (rst)                      mem_run <=0;
        else if (chn_rst || seq_done) mem_run <=0;
        else if (channel_pgm_en)      mem_run <=1;
        
        if (rst)          cmd_set <= 0;
        else if (chn_rst) cmd_set <= 0;
        else              cmd_set <= channel_pgm_en;
        
 //       if (rst)          chn_run <= 0;
 //       else if (cmd_set) chn_run <= cmd_chn;
        
        if (rst)          page <= 0;
        else if (cmd_set) page <= cmd_page;
        
        if (rst)          cmd_set_d <= 0;
        else              cmd_set_d <= {cmd_set_d[0],cmd_set};
    end
    
    always @ (negedge mclk) begin
        page_neg <= page;
        cmd_set_d_neg <= cmd_set_d[1];
    end 
    
    cmd_deser #(
        .ADDR       (MCNTRL_PS_ADDR),
        .ADDR_MASK  (MCNTRL_PS_MASK),
        .NUM_CYCLES (6),
        .ADDR_WIDTH (5),
        .DATA_WIDTH (32)
    ) cmd_deser_mcontr_32bit_i (
        .rst        (rst), // input
        .clk        (mclk), // input
        .ad         (cmd_ad), // input[7:0] 
        .stb        (cmd_stb), // input
        .addr       (cmd_a), // output[15:0] 
        .data       (cmd_data), // output[31:0] 
        .we         (cmd_we) // output
    );

    status_generate #(
        .STATUS_REG_ADDR  (MCNTRL_PS_STATUS_REG_ADDR),
        .PAYLOAD_BITS     (2)
    ) status_generate_i (
        .rst              (rst), // input
        .clk              (mclk), // input
        .we               (set_status_w), // input
        .wd               (cmd_data[7:0]), // input[7:0] 
        .status           (status_data), // input[25:0] 
        .ad               (status_ad), // output[7:0] 
        .rq               (status_rq), // output
        .start            (status_start) // input
    );

fifo_same_clock   #(
    .DATA_WIDTH(CMD_WIDTH),
    .DATA_DEPTH(CMD_FIFO_DEPTH) 
    ) cmd_fifo_i (
        .rst       (rst),
        .clk       (mclk),
        .sync_rst(chn_rst), // synchronously reset fifo;
        .we        (set_cmd_w),
        .re        (cmd_set),
        .data_in   (cmd_data[CMD_WIDTH-1:0]),
        .data_out  (cmd_out),  //SuppressThisWarning ISExst Assignment to awsize_out ignored, since the identifier is never used
        .nempty    (cmd_nempty),
        .half_full (cmd_half_full)
`ifdef DEBUG_FIFO
        ,
        .under      (waddr_under), // output reg 
        .over       (waddr_over), // output reg
        .wcount     (waddr_wcount), // output[3:0] reg 
        .rcount     (waddr_rcount), // output[3:0] reg 
        .num_in_fifo(waddr_num_in_fifo) // output[3:0] 
`endif         
    );


// Port 0 (read DDR to AXI) buffer
    mcntrl_1kx32r chn0_buf_i (
        .ext_clk      (port0_clk), // input
        .ext_raddr    (port0_addr), // input[9:0] 
        .ext_rd       (port0_re), // input
        .ext_regen    (port0_regen), // input
        .ext_data_out (port0_data), // output[31:0] 
        .wclk         (!mclk), // input
        .wpage_in     (page_neg), // input[1:0] 
        .wpage_set    (cmd_set_d_neg), // input 
        .page_next    (buf_wpage_nxt_chn0), // input
        .page         (), // output[1:0]
        .we           (buf_wr_chn0), // input
        .data_in      (buf_wdata_chn0) // input[63:0] 
    );
    
// Port 1 (write DDR from AXI) buffer
     mcntrl_1kx32w chn1_buf_i (
        .ext_clk      (port1_clk), // input
        .ext_waddr    (port1_addr), // input[9:0] 
        .ext_we       (port1_we), // input
        .ext_data_in  (port1_data), // input[31:0] buf_wdata - from AXI
        .rclk         (mclk), // input
        .rpage_in     (page), // input[1:0] 
        .rpage_set    (cmd_set_d[0]), // input 
        .page_next    (rpage_nxt_chn1), // input
        .page         (), // output[1:0]
        .rd           (buf_rd_chn1), // input
        .data_out     (buf_rdata_chn1) // output[63:0] 
    );
    
    
endmodule

