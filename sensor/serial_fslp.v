/*!
 * <b>Module:</b> serial_fslp
 * @file serial_fslp.v
 * @date 2020-12-13  
 * @author eyesis
 *     
 * @brief implementation of the FSLP for Boson
 *
 * @copyright Copyright (c) 2020 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 *
 * <b>License </b>
 *
 * serial_fslp.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * serial_fslp.v is distributed in the hope that it will be useful,
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

module  serial_fslp #(
    parameter START_FRAME_BYTE  =         'h8E,
    parameter END_FRAME_BYTE  =           'hAE,
    parameter ESCAPE_BYTE =               'h9E,
    parameter REPLACED_START_FRAME_BYTE = 'h81,
    parameter REPLACED_END_FRAME_BYTE =   'hA1,
    parameter REPLACED_ESCAPE_BYTE =      'h91,
    parameter INITIAL_CRC16 =           16'h1d0f,
//    parameter BOSON_BAUD =              921600,
    parameter CLK_DIV =                   217,
    parameter RX_DEBOUNCE =               60
    
    
)(
    input         mrst,           // @posedge mclk, sync reset
    input         mclk,           // global clock, half DDR3 clock, synchronizes all I/O through the command port
    output        txd,            // serial data out
    input         rxd,            // serial data in
    input         tx_start,       // start transmit packet
    input         tx_done,        // end transmit packet
    input         tx_stb,         // transmit byte strobe
    input   [7:0] tx_byte,        // transmit byte input
    output        tx_rdy,         // crc16 ready to accept tx_in_stb
    output        stuffer_busy,   // processing packet (not including UART)
    output        uart_tx_busy,   // UART busy ('or' with stuffer_busy?)
    output  [7:0] rx_byte,        // received byte output
    output        rx_stb,         // received byte strobe
    output        rx_packet_run,  // run received packet
    output        rx_packet_done  // finished receiving packet (last 2 bytes - crc16)
);
    wire[7:0]debug_UART_CLK_DIV     = CLK_DIV; //  =                   22,
    wire[7:0]debug_UART_RX_DEBOUNCE = RX_DEBOUNCE; //                6,

    wire  [7:0] uart_txd;
    wire  [7:0] uart_rxd;
    wire        uart_tx_stb;
    wire        uart_tx_rdy;
    wire        stuffer_rdy;
    wire        uart_rx_stb;
    wire  [7:0] crc16_txd;
    wire        crc16_stb;
    wire        crc16_busy;
    
    

    boson_uart #(
        .CLK_DIV     (CLK_DIV),
        .RX_DEBOUNCE (RX_DEBOUNCE)
    ) boson_uart_i (
        .mrst    (mrst),          // input
        .mclk    (mclk),          // input
        .txd     (txd),           // output
        .rxd     (rxd),           // input
        .tx_byte (uart_txd[7:0]), // input[7:0] 
        .tx_stb  (uart_tx_stb),   // input
        .tx_busy (uart_tx_busy),  // output
        .tx_rdy  (uart_tx_rdy),   // output
        .rx_byte (uart_rxd[7:0]), // output[7:0] 
        .rx_stb  (uart_rx_stb)    // output
    );

    crc16_xmodem #(
        .INITIAL_CRC16(INITIAL_CRC16)
    ) crc16_xmodem_i (
        .mrst        (mrst),           // input
        .mclk        (mclk),           // input
        .tx_start    (tx_start),       // input
        .txd_in      (tx_byte[7:0]),   // input[7:0] 
        .tx_in_stb   (tx_stb),         // input
        .tx_over     (tx_done),        // input
        .tx_rdy      (stuffer_rdy),    // input
        .tx_in_rdy   (tx_rdy),         // output
        .txd_out     (crc16_txd[7:0]), // output[7:0] 
        .tx_out_stb  (crc16_stb),      // output
        .tx_busy     (crc16_busy)      // output
    );


    serial_stuffer #(
        .START_FRAME_BYTE          (START_FRAME_BYTE),
        .END_FRAME_BYTE            (END_FRAME_BYTE),
        .ESCAPE_BYTE               (ESCAPE_BYTE),
        .REPLACED_START_FRAME_BYTE (REPLACED_START_FRAME_BYTE),
        .REPLACED_END_FRAME_BYTE   (REPLACED_END_FRAME_BYTE),
        .REPLACED_ESCAPE_BYTE      (REPLACED_ESCAPE_BYTE)
    ) serial_stuffer_i (
        .mrst         (mrst),           // input
        .mclk         (mclk),           // input
        .packet_run   (crc16_busy),     // input
        .tx_in_stb    (crc16_stb),      // input
        .txd_in       (crc16_txd[7:0]), // input[7:0] 
        .stuffer_rdy  (stuffer_rdy),    // output
        .uart_rdy     (uart_tx_rdy),    // input
        .uart_stb     (uart_tx_stb),    // output
        .uart_txd     (uart_txd[7:0]),  // output[7:0] 
        .stuffer_busy (stuffer_busy)    // output
    );

    serial_destuffer #(
        .START_FRAME_BYTE          (START_FRAME_BYTE),
        .END_FRAME_BYTE            (END_FRAME_BYTE),
        .ESCAPE_BYTE               (ESCAPE_BYTE),
        .REPLACED_START_FRAME_BYTE (REPLACED_START_FRAME_BYTE),
        .REPLACED_END_FRAME_BYTE   (REPLACED_END_FRAME_BYTE),
        .REPLACED_ESCAPE_BYTE      (REPLACED_ESCAPE_BYTE)
    ) serial_destuffer_i (
        .mrst         (mrst),          // input
        .mclk         (mclk),          // input
        .rxd_in       (uart_rxd[7:0]), // input[7:0] 
        .rx_in_stb    (uart_rx_stb),   // input
        .rxd_out      (rx_byte[7:0]),  // output[7:0] 
        .rx_stb       (rx_stb),        // output
        .packet_run   (rx_packet_run), // output
        .packet_done  (rx_packet_done) // output
    );



endmodule

