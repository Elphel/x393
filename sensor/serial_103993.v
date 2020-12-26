/*!
 * <b>Module:</b> serial_103993
 * @file serial_103993.v
 * @date 2020-12-18  
 * @author eyesis
 *     
 * @brief Serial interface to communicate with Boson (software r/w any, sequencer - short writes)
 *
 * @copyright Copyright (c) 2020 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 *
 * <b>License </b>
 *
 * serial_103993.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * serial_103993.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *
 * Additional permission under GNU GPL version 3 section 7:
 * If you modify this Program, or any covered work, by linking or combining it
 * with independent modules provided by the FPGA vendor only (this permission
 * does not extend to any 3-rd party modules, "soft cores" or macros) under
 * different license terms solely for the purpose of generating binary "bitstream"
 * files and/or simulating the code, the copyright holders of this Program give
 * you the right to distribute the covered work without those independent modules
 * as long as the source code for them is available from the FPGA vendor free of
 * charge, and there is no dependence on any encrypted modules for simulating of
 * the combined code. This permission applies to you if the distributed code
 * contains all the components and scripts required to completely simulate it
 * with at least one of the Free Software programs.
 */
`timescale 1ns/1ps

module  serial_103993#(
    parameter START_FRAME_BYTE  =         'h8E,
    parameter END_FRAME_BYTE  =           'hAE,
    parameter ESCAPE_BYTE =               'h9E,
    parameter REPLACED_START_FRAME_BYTE = 'h81,
    parameter REPLACED_END_FRAME_BYTE =   'hA1,
    parameter REPLACED_ESCAPE_BYTE =      'h91,
    parameter INITIAL_CRC16 =           16'h1d0f,
    parameter CLK_DIV =                   217,
    parameter RX_DEBOUNCE =               60,
    parameter EXTIF_MODE =                 1 // 1,2 or 3 if there are several different extif
)(
    input         mrst,           // @posedge mclk, sync reset
    input         mclk,           // global clock, half DDR3 clock, synchronizes all I/O through the command port
    output        txd,            // serial data out
    input         rxd,            // serial data in
    // sequencer interface now always 5 bytes form the sequencer! (no need for extif_last - remove)
    // interface for uart in write-only mode for short commands
    // 1-st byte - SA (use 2 LSB to select 0,1,2 data bytes
    // 2-nd byte module
    // 3-rd byte function
    // 4 (optional) data[15:8] or data[7:0] if last
    // 5 (optional) data[7:0] 
    input                      extif_dav,  // data byte available for external interface 
//    input                      extif_last, // last byte for  external interface (with extif_dav)
    input                [1:0] extif_sel,  // interface type (0 - internal, 1 - uart, 2,3 - reserved)
    input                [7:0] extif_byte, // data to external interface (first - extif_sa)
    output                     extif_ready, // acknowledges extif_dav
    input                      extif_rst,   // reset seq xmit and sequence number
    // software interface (byte R/W)
    input                      extif_en,    // enable transmission from the sequencer
    input                      xmit_rst,    // reset (soft xmit only)
    input                      xmit_start,  // all in programmatic FIFO
    input                [7:0] xmit_data,   // write data byte
    input                      xmit_stb,    // write data strobe
    output                     xmit_busy,
    
    input                      recv_rst,    // reset read uart FIFO
    input                      recv_next,
    output                     recv_prgrs, // read in progress
    output                     recv_dav,   // read byte available 
    output               [7:0] recv_data

);
    wire                [ 7:0] xmit_fifo_out;
    wire                [ 1:0] xmit_fifo_re_regen;
    wire                [10:0] xmit_fifo_waddr;
    wire                [10:0] xmit_fifo_raddr;
//    wire                [11:0] xmit_fifo_fill;
//    reg                        xmit_fifo_rd;
    wire                       xmit_fifo_nempty;
    
    wire                       recv_fifo_wr;
    wire                [ 1:0] recv_fifo_re_regen;
    wire                [10:0] recv_fifo_waddr;
    wire                [10:0] recv_fifo_raddr;
//    wire                [11:0] recv_fifo_fill;
    wire                [ 7:0] recv_fifo_din;
    
    reg                        xmit_pend; // initiated soft xmit
    reg                        xmit_run;  // runing soft xmit
    reg                        xmit_run_d; // runing soft xmit, delayed
    reg                        extif_run; // running xmit from the sequencer
    reg                        extif_run_d; // running xmit from the sequencer
    wire                [ 7:0] xmit_extif_data; // data byte to transmit from the sequencer
    reg                        xmit_stb_fifo; 
    reg                        xmit_stb_seq; 
    reg                        xmit_over_fifo; 
    reg                        xmit_over_seq;
    reg                        xmit_stb_d; 
    reg                        xmit_over_d;
    reg                        stuffer_busy_d; 
    reg                        xmit_busy_r;
    
    wire                       xmit_start_out_fifo;
    wire                       xmit_start_out_seq;
    wire                       xmit_start_out;
    reg                        xmit_done; // any mode - soft or seq;
    wire                       extif_rq_w;
    wire                [ 7:0] xmit_any_data;
    wire                       xmit_stb_any;
    wire                       xmit_over;
    wire                       tx_rdy; // transmit IF ready to accept byte
    wire                       pre_tx_stb;
    wire                       stuffer_busy; // output processing packet (not including UART)
    wire                       uart_tx_busy; // output UART busy ('or' with stuffer_busy?)
//                                             // soft seq number may always use >0xffff to distinguish
    
    wire                       packet_ready_seq;
    wire                       packet_over_seq;
//    wire                       packet_sent;
    
    assign extif_rq_w =          packet_ready_seq && !extif_run && !packet_over_seq;
    assign xmit_any_data =       extif_run ? xmit_extif_data : xmit_fifo_out;
    assign xmit_stb_any =            extif_run ? xmit_stb_seq :    xmit_stb_fifo;
    assign xmit_over =           extif_run ? xmit_over_seq :   xmit_over_fifo;
    assign xmit_start_out_fifo = xmit_run && !xmit_run_d;
    assign xmit_start_out_seq =  extif_run && !extif_run_d;
    assign xmit_start_out =      xmit_start_out_fifo || xmit_start_out_seq;
    assign pre_tx_stb =          !xmit_stb_d && !xmit_over_d && !mrst && !xmit_rst && !extif_rst && xmit_run && tx_rdy;
    assign xmit_busy =           xmit_busy_r;
//    assign packet_sent =         xmit_over && !xmit_over_d;
    always @(posedge mclk) begin
        xmit_busy_r  <= uart_tx_busy || stuffer_busy_d || xmit_pend || xmit_run || extif_run;
    
        if (mrst || xmit_rst)                          xmit_pend <= 0;
        else if (xmit_start)                           xmit_pend <= 1;
        else if (xmit_start_out_fifo)                  xmit_pend <= 0;
        
        if (mrst || xmit_rst)                          xmit_run <= 0;
        else if (xmit_pend && !xmit_run && extif_run)  xmit_run <= 1;
        else if (xmit_done)                            xmit_run <= 0; // no need to condition with xmit_run
//        else if (!stuffer_busy && !xmit_fifo_nempty)   xmit_run <= 0; // no need to condition with xmit_run
    
        xmit_run_d <= xmit_run && !mrst && !xmit_rst;
        
        if (mrst || extif_rst)                         extif_run <= 0;
        else if (!xmit_run && !xmit_pend && extif_rq_w) extif_run <= 1;
        else if (xmit_done)                            extif_run <= 0; // no need to condition with xmit_run
        extif_run_d <= extif_run  && !mrst && !extif_rst;
        
        xmit_stb_d <= xmit_stb_any;
        xmit_over_d <= xmit_over;
        stuffer_busy_d <= stuffer_busy;
        xmit_done <= stuffer_busy_d && !stuffer_busy;
        
         
        // transmit soft (from fifo) (FIFO should always be not empty until last byte (should nit be replenished)
        xmit_stb_fifo <=  pre_tx_stb &&  xmit_fifo_nempty; // also advances FIFO read
        xmit_over_fifo <= pre_tx_stb && !xmit_fifo_nempty;
        
        // Generate sequencer packet and transmit it 
        xmit_stb_seq <=  pre_tx_stb && packet_ready_seq;
        xmit_over_seq <= pre_tx_stb && packet_over_seq;
        
    end
    
        /* Instance template for module serial_103993_extif */
    serial_103993_extif #(
        .EXTIF_MODE (EXTIF_MODE) // 1)
    ) serial_103993_extif_i (
        .mclk            (mclk),            // input
        .mrst            (mrst),            // input
        .extif_en        (extif_en),        // input
        .extif_dav       (extif_dav),       // input
        .extif_sel       (extif_sel),       // input[1:0] 
        .extif_byte      (extif_byte),      // input[7:0] 
        .extif_ready     (extif_ready),     // output
        .extif_rst       (extif_rst),       // input
        .packet_ready    (packet_ready_seq),    // output
        .packet_byte     (xmit_extif_data), // output[7:0] 
        .packet_byte_stb (xmit_stb_seq),    // input
        .packet_over     (packet_over_seq),     // output
        .packet_sent     (xmit_done)        // input
    );
    
    
    serial_fslp #(
        .START_FRAME_BYTE          (START_FRAME_BYTE),          // 'h8E),
        .END_FRAME_BYTE            (END_FRAME_BYTE),            // 'hAE),
        .ESCAPE_BYTE               (ESCAPE_BYTE),               // 'h9E),
        .REPLACED_START_FRAME_BYTE (REPLACED_START_FRAME_BYTE), // 'h81),
        .REPLACED_END_FRAME_BYTE   (REPLACED_END_FRAME_BYTE),   // 'hA1),
        .REPLACED_ESCAPE_BYTE      (REPLACED_ESCAPE_BYTE),      // 'h91),
        .INITIAL_CRC16             (INITIAL_CRC16),             // 16'h1d0f),
        .CLK_DIV                   (CLK_DIV),                   // 217),
        .RX_DEBOUNCE               (RX_DEBOUNCE)                // 60)
    ) serial_fslp_i (
        .mrst           (mrst),            // input
        .mclk           (mclk),            // input
        .txd            (txd),             // output serial data out
        .rxd            (rxd),             // input serial data in
        .tx_start       (xmit_start_out),  // input start transmit packet
        .tx_done        (xmit_over),       // input end transmit packet
        .tx_stb         (xmit_stb_any),    // input transmit byte strobe
        .tx_byte        (xmit_any_data),   // input[7:0] transmit byte input
        .tx_rdy         (tx_rdy),          // output crc16 ready to accept tx_in_stb
        .stuffer_busy   (stuffer_busy),    // output processing packet (not including UART)
        .uart_tx_busy   (uart_tx_busy),    // output UART busy ('or' with stuffer_busy?)
        .rx_byte        (recv_fifo_din),   // output[7:0] received byte output
        .rx_stb         (recv_fifo_wr),    // output received byte strobe
        .rx_packet_run  (recv_prgrs),      // output  run received packet
        .rx_packet_done () // output finished receiving packet (last 2 bytes - crc16)
    );

   fifo_sameclock_control #(
        .WIDTH(11)
    ) fifo_xmit_control_i (
        .clk      (mclk),                   // input
        .rst      (mrst || xmit_rst),       // input
        .wr       (xmit_stb),               // input
        .rd       (xmit_stb_fifo),          // input
        .nempty   (xmit_fifo_nempty),       // output
        .fill_in  (),                       // output[11:0] 
        .mem_wa   (xmit_fifo_waddr),        // output[10:0] reg 
        .mem_ra   (xmit_fifo_raddr),        // output[10:0] reg 
        .mem_re   (xmit_fifo_re_regen[0]),  // output
        .mem_regen(xmit_fifo_re_regen[1]),  // output
        .over     (),                       // output reg 
        .under    () //h2d_under)           // output reg 
    );
    
    ram18_var_w_var_r #(
        .REGISTERS    (1),
        .LOG2WIDTH_WR (3),
        .LOG2WIDTH_RD (3)
    ) fifo_xmit_i (
        .rclk     (mclk),                   // input
        .raddr    (xmit_fifo_raddr),        // input[10:0] 
        .ren      (xmit_fifo_re_regen[0]),  // input
        .regen    (xmit_fifo_re_regen[1]),  // input
        .data_out (xmit_fifo_out),          // output[7:0] 
        .wclk     (mclk),                   // input
        .waddr    (xmit_fifo_waddr),        // input[10:0] 
        .we       (xmit_stb),               // input
        .web      (4'hf),                   // input[3:0] 
        .data_in  (xmit_data)               // input[7:0] 
    );

    
    fifo_sameclock_control #(
        .WIDTH(11)
    ) fifo_recv_control_i (
        .clk      (mclk),                   // input
        .rst      (mrst || recv_rst),       // input
        .wr       (recv_fifo_wr),           // input
        .rd       (recv_next),              // input
        .nempty   (recv_dav),               // output
        .fill_in  (), // recv_fifo_fill),         // output[11:0] 
        .mem_wa   (recv_fifo_waddr),        // output[10:0] reg 
        .mem_ra   (recv_fifo_raddr),        // output[10:0] reg 
        .mem_re   (recv_fifo_re_regen[0]),  // output
        .mem_regen(recv_fifo_re_regen[1]),  // output
        .over     (),                       // output reg 
        .under    () //h2d_under)           // output reg 
    );
    
    ram18_var_w_var_r #(
        .REGISTERS    (1),
        .LOG2WIDTH_WR (3),
        .LOG2WIDTH_RD (3)
    ) fifo_recv_i (
        .rclk     (mclk),                   // input
        .raddr    (recv_fifo_raddr),        // input[10:0] 
        .ren      (recv_fifo_re_regen[0]),  // input
        .regen    (recv_fifo_re_regen[1]),  // input
        .data_out (recv_data),              // output[7:0] 
        .wclk     (mclk),                   // input
        .waddr    (recv_fifo_waddr),        // input[10:0] 
        .we       (recv_fifo_wr),           // input
        .web      (4'hf),                   // input[3:0] 
        .data_in  (recv_fifo_din)           // input[7:0] 
    );




endmodule

