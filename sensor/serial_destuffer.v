/*!
 * <b>Module:</b> serial_destuffer
 * @file serial_destuffer.v
 * @date 2020-12-13  
 * @author eyesis
 *     
 * @brief unwrap serial packet from fslp
 *
 * @copyright Copyright (c) 2020 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 *
 * <b>License </b>
 *
 * serial_destuffer.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * serial_destuffer.v is distributed in the hope that it will be useful,
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

module  serial_destuffer#(
    parameter START_FRAME_BYTE  =         'h8E,
    parameter END_FRAME_BYTE  =           'hAE,
    parameter ESCAPE_BYTE =               'h9E,
    parameter REPLACED_START_FRAME_BYTE = 'h81,
    parameter REPLACED_END_FRAME_BYTE =   'hA1,
    parameter REPLACED_ESCAPE_BYTE =      'h91
)(
    input         mrst,         // @posedge mclk, sync reset
    input         mclk,         // global clock, half DDR3 clock, synchronizes all I/O through the command port
    input   [7:0] rxd_in,       // data byte from uart
    input         rx_in_stb,    // data strob from uart
    output  [7:0] rxd_out,      // destuffed payload (including channel and CRC, excluding START/END
    output        rx_stb,       // output data strobe
    output        packet_run,   // receiving packet (debug output)         
    output        packet_done   // single-cycle packet end indicator         
);
    reg     [1:0] packet_run_r;
    reg           packet_done_r;
    reg           payload;
    reg     [7:0] rxd_in_r;
    reg     [2:0] in_stb;
    reg           is_esc;
    reg     [7:0] rxd_r;
    reg     [2:0] replaced;
    reg           thru; // pass input data through
    reg     [1:0] out_stb;
//    reg           flsp_end_r;
    
    wire          flsp_start; 
    wire          flsp_end;
    wire          is_esc_w;
    wire    [2:0] replaced_w; 
    
    assign flsp_start = in_stb[0] && (rxd_in_r == START_FRAME_BYTE);
    assign flsp_end =   in_stb[0] && (rxd_in_r == END_FRAME_BYTE);
    assign is_esc_w =   rxd_in_r == ESCAPE_BYTE;
    assign replaced_w = {
        (rxd_in_r == REPLACED_ESCAPE_BYTE) ?      1'b1: 1'b0,
        (rxd_in_r == REPLACED_END_FRAME_BYTE) ?   1'b1: 1'b0,
        (rxd_in_r == REPLACED_START_FRAME_BYTE) ? 1'b1: 1'b0
        };

    assign packet_run = packet_run_r[0];
    assign rxd_out = rxd_r;
    assign rx_stb = out_stb[1];
    assign packet_done = packet_done_r;
    always @(posedge mclk) begin
//        flsp_end_r <= flsp_end && !mrst;
        
        if (mrst) in_stb <= 0;
        else      in_stb <= {in_stb[1:0], rx_in_stb};
    
        if      (mrst)      rxd_in_r <= 0;
        else if (rx_in_stb) rxd_in_r <= rxd_in;
    
        if      (mrst)       packet_run_r[0] <= 0;
        else if (flsp_start) packet_run_r[0] <= 1; 
        else if (flsp_end)   packet_run_r[0] <= 0;
        packet_run_r[1] <= packet_run_r[0];
        
        if   (!packet_run || flsp_end)  payload <= 0;
        else if (in_stb[0])             payload <= 1;
        
        if      (mrst)      is_esc <= 0;
        else if (in_stb[0]) is_esc <= is_esc_w;

        if      (mrst)      replaced <= 0;
        else if (in_stb[0]) replaced <= {3{is_esc}} & replaced_w;
        
        if (in_stb[0])      thru <= !is_esc_w && !is_esc;       
        
        if (mrst)           out_stb <= 0;
        else                out_stb <= {out_stb[0], in_stb[1] & payload & ~is_esc};
//        else                out_stb <= {out_stb[0], (in_stb[1] & payload & ~is_esc) || flsp_end_r}; // added extra pulse after end
        
        if (out_stb[0]) rxd_r <=
                 ({8{thru}} &        rxd_in_r) |
                 ({8{replaced[0]}} & START_FRAME_BYTE) |
                 ({8{replaced[1]}} & END_FRAME_BYTE) |
                 ({8{replaced[2]}} & ESCAPE_BYTE);
                 
        packet_done_r <= !packet_run_r[0] && packet_run_r[1];
         
    end


endmodule

