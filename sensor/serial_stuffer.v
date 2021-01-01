/*!
 * <b>Module:</b> serial_stuffer
 * @file serial_stuffer.v
 * @date 2020-12-13  
 * @author eyesis
 *     
 * @brief wrap serial packet for fslp
 *
 * @copyright Copyright (c) 2020 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 *
 * <b>License </b>
 *
 * serial_stuffer.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * serial_stuffer.v is distributed in the hope that it will be useful,
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

module  serial_stuffer #(
    parameter START_FRAME_BYTE  =         'h8E,
    parameter END_FRAME_BYTE  =           'hAE,
    parameter ESCAPE_BYTE =               'h9E,
    parameter REPLACED_START_FRAME_BYTE = 'h81,
    parameter REPLACED_END_FRAME_BYTE =   'hA1,
    parameter REPLACED_ESCAPE_BYTE =      'h91
)(
    input         mrst,         // @posedge mclk, sync reset
    input         mclk,         // global clock, half DDR3 clock, synchronizes all I/O through the command port
    input         packet_run,   // goes inactive after last txd_in_stb
    input         tx_in_stb,    // data strobe from crc16
    input   [7:0] txd_in,
    output        stuffer_rdy,  // stuffer ready to accept tx_in_stb
    input         uart_rdy,     // uart ready to accept byte
    output        uart_stb,     // write byte to UART
    output  [7:0] uart_txd,     // byte to uart
    output        stuffer_busy  // processing packet (not including UART)
);

    reg           stuffer_busy_r;
    reg     [1:0] stuffer_start;
    reg           stuffer_finsh;
    reg           packet_trailer;
    reg           pre_trailer;
    reg           packet_header;
    reg           escape_cyc0;
    reg     [2:0] escape_cyc1;
    reg           uart_stb_r;
    reg     [7:0] txd_in_r;
    reg     [2:0] tx_in_stb_r;
    reg     [2:0] need_escape;
    reg     [3:0] byte_out_set; //  
    wire          byte_out_stb; // ==byte_out_set[1]
    reg     [7:0] uart_txd_r;
    reg           tx_dav;       // for sending data to uart
    reg           copy_in_byte;
    reg           stuffer_rdy_r;
    wire          pre_stuffer_start_w;
    wire          proc_next_in_byte; // when txd_in_r contains new data and uart is ready to accept one
    wire          proc_trailer;      // when trailer and uart is ready to accept one
    reg           txd_in_r_full; // txd_in_r contains data 
    wire          use_txd_in_r;
    wire          set_trailer;
    assign stuffer_busy = stuffer_busy_r;
    assign uart_stb =     uart_stb_r;
    assign uart_txd =     uart_txd_r;
    assign stuffer_rdy =  stuffer_rdy_r;
    assign pre_stuffer_start_w = ~stuffer_busy_r & packet_run;
    assign use_txd_in_r =  byte_out_stb && !escape_cyc0 && !packet_header && !packet_trailer;
    assign proc_next_in_byte = txd_in_r_full && uart_rdy && ! (|tx_in_stb_r) && !(|byte_out_set);
    assign proc_trailer =     packet_trailer && uart_rdy && ! (|tx_in_stb_r) && !(|byte_out_set) && !stuffer_finsh;
    assign set_trailer =   !pre_trailer && !packet_trailer && !escape_cyc0 && !packet_run && stuffer_busy_r; //
    assign byte_out_stb = byte_out_set[1];
    always @(posedge mclk) begin
        if (mrst || !stuffer_busy_r)  txd_in_r_full <= 0;
        else if (tx_in_stb)           txd_in_r_full <= 1;
        else if (use_txd_in_r)        txd_in_r_full <= 0;
    
        stuffer_start <= {stuffer_start[0], pre_stuffer_start_w};
         
        if      (mrst)                              stuffer_busy_r <= 0;
        else if (pre_stuffer_start_w)               stuffer_busy_r <= 1;
        else if (packet_trailer && uart_stb_r)      stuffer_busy_r <= 0;
        if      (mrst || !stuffer_busy_r)                               stuffer_rdy_r <= 0;
        else if (stuffer_start[0])                                      stuffer_rdy_r <= 1;
        else if (tx_in_stb || stuffer_finsh)                            stuffer_rdy_r <= 0;
        else if (use_txd_in_r)                                          stuffer_rdy_r <= 1;
        else if (!stuffer_busy_r)                                       stuffer_rdy_r <= 1; //*
        
        tx_in_stb_r <= {tx_in_stb_r[1:0], proc_next_in_byte}; // tx_in_stb};
        
        if (tx_in_stb) txd_in_r <= txd_in;
//        if (tx_in_stb_r[0]) need_escape <= {
        if (tx_in_stb_r[0] && !escape_cyc0) need_escape <= {
            (txd_in_r == ESCAPE_BYTE)?      1'b1 : 1'b0,
            (txd_in_r == END_FRAME_BYTE)?   1'b1 : 1'b0,
            (txd_in_r == START_FRAME_BYTE)? 1'b1 : 1'b0};

        if      (mrst)             escape_cyc0 <= 0; 
//        else if (tx_in_stb_r[1])   escape_cyc0 <= |need_escape;
//        else if (uart_stb_r)       escape_cyc0 <= 0;
        else if (tx_in_stb_r[1])   escape_cyc0 <= |need_escape && !escape_cyc0;
        
        if      (mrst)             escape_cyc1 <= 0;
//        else if (uart_stb_r)       escape_cyc1 <= {3{escape_cyc0}} & need_escape;
        else if (uart_stb_r)       escape_cyc1 <= {3{escape_cyc0}} & need_escape;
        
        if      (mrst)             byte_out_set <= 0;
        else                       byte_out_set <= {byte_out_set[2:0], tx_in_stb_r[2] | stuffer_start[1] | stuffer_finsh};
        
        if      (mrst)             packet_header <= 0;
        else if (stuffer_start[1]) packet_header <= 1;
        else if (byte_out_stb)  packet_header <= 0;

        if      (!stuffer_busy_r)  pre_trailer <= 0;
        else if (byte_out_stb)  pre_trailer <= set_trailer;

        if      (!stuffer_busy_r)  packet_trailer <= 0;
        else if (uart_stb_r)       packet_trailer <= pre_trailer;

        stuffer_finsh <= proc_trailer; // stuffer_rdy_r && stuffer_busy_r && packet_trailer; // !packet_run
        
        
        copy_in_byte <= !(|need_escape) && !packet_header && !packet_trailer;
        
        if (byte_out_stb) uart_txd_r <=
            ({8{packet_header}}  &  START_FRAME_BYTE) |
            ({8{packet_trailer}} &  END_FRAME_BYTE) |
            ({8{escape_cyc0}}  &    ESCAPE_BYTE) |
            ({8{escape_cyc1[0]}} &  REPLACED_START_FRAME_BYTE) |
            ({8{escape_cyc1[1]}} &  REPLACED_END_FRAME_BYTE) |
            ({8{escape_cyc1[2]}} &  REPLACED_ESCAPE_BYTE) |
            ({8{copy_in_byte}} &    txd_in_r);
            
        if      (mrst)            tx_dav <= 0;
        else if (byte_out_stb) tx_dav <= 1;
        else if (uart_stb_r)      tx_dav <= 0;
        
        if (mrst) uart_stb_r <= 0;
        else      uart_stb_r <= !uart_stb_r && tx_dav && uart_rdy;
         
    end

endmodule

