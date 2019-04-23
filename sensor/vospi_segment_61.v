/*!
 * <b>Module:</b> vospi_segment_61
 * @file vospi_segment_61.v
 * @date 2019-04-08  
 * @author eyesis
 *     
 * @brief Read one 61-packet segment from the sensor 
 *
 * @copyright Copyright (c) 2019 Elphel, Inc.
 *
 * <b>License </b>
 *
 * vospi_segment_61.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * vospi_segment_61.v is distributed in the hope that it will be useful,
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

module  vospi_segment_61#(
    parameter VOSPI_PACKET_WORDS =    80,
    parameter VOSPI_NO_INVALID =       1, // do not output invalid packets data
    parameter VOSPI_PACKETS_PER_LINE = 2,
    parameter VOSPI_SEGMENT_FIRST =    1,
    parameter VOSPI_SEGMENT_LAST =     4,
    parameter VOSPI_PACKET_FIRST =     0,
    parameter VOSPI_PACKET_LAST =     60,
    parameter VOSPI_PACKET_TTT =      20,  // line number where segment number is provided
    parameter VOSPI_SOF_TO_HACT =      2,  // clock cycles from SOF to HACT
    parameter VOSPI_HACT_TO_HACT_EOF = 2  // minimal clock cycles from HACT to HACT or to EOF
    
//    parameter VOSPI_HACT_TO_EOF =      2   // clock cycles from HACT to EOF
)(
    input         rst,
    input         clk,
    input         start,           // start reading segment
    input  [3:0]  exp_segment,     // expected segment (1,2,3,4)
    input         segm0_ok,        // OK to read segment 0 instead of the current ( exp_segment still has to be 1..4)
    input         out_en,          // enable frame output generation (will finish current frame if disabled, single-pulse
                                   // runs a single frame
    // SPI signals
    output        spi_clken,       // enable clock on spi_clk
    output        spi_cs,          // active low
    input         miso,            // input from the sensor
    
    output        in_busy,         // waiting for or receiving a segment
    output        out_busy,
    output reg    segment_done,    // finished receiving segment (good or bad). next after busy off
    output        discard_segment, // segment was disc arded  
    output [15:0] dout,            // 16-bit data received
    output        hact,            // data valid 
    output        sof,             // start of frame
    output        eof,             // end of frame
    output        crc_err,         // crc error happened for any packet (valid at eos)
    output  [3:0] id,               // segment number  (valid at eos)
    output        dbg_running      // debug output for segment_running
);
    localparam VOSPI_PACKETS_FRAME = (VOSPI_SEGMENT_LAST - VOSPI_SEGMENT_FIRST + 1) *
                                     (VOSPI_PACKET_LAST - VOSPI_PACKET_FIRST + 1);
    localparam VOSPI_LINE_WIDTH = VOSPI_PACKET_WORDS * VOSPI_PACKETS_PER_LINE;
    
    // save fifo write pointer, write packet full index (in the frame)
    // read and buffer first 20 valid packets, then (in packet 20) verify that the segment is correct.
    // if correct - generate sof if appropriate/eof),  proceed with hact, readout data
    // if incorrect - restore write pointer and write packet index, read rest of the segment without writing to the buffer
//    reg          first_segment_in;     // processing first segment in a frame
    reg          last_segment_in;      // processing last segment in a frame
    reg   [10:0] segment_start_waddr;  // write address for the beginning of the current packet
    reg   [10:0] waddr;                // current frite address
    reg   [ 7:0] segment_start_packet; // full packet number in a fragment for the start of the segment
    reg   [ 7:0] full_packet;          // current full packet number in a fragment
    reg   [ 7:0] full_packet_verified; // next packet verified (will not be discarded later)
    reg          full_packet_frame;    // lsb of the input frame  // not needed?
    reg          discard_set;          // start discard_segment_r
    wire         segment_good_w;       // recognized expected segment, OK to read FIFO
    reg          segment_good;         // recognized expected segment, OK to read FIFO
    reg          discard_segment_r;    // read and discard the rest of the current segment
    reg          running_good;         // passed packet 20
    wire         packet_done;          // read full packet
    wire         packet_busy;          // receiving SPI packet (same as spi_clken, !spi_cs)
    wire         packet_dv;            // read full packet
    wire  [15:0] packet_dout;          // read full packet
    wire  [15:0] packet_id;
    wire  [ 3:0] segment_id;
    wire         packet_invalid;
    wire         id_stb;
    wire         is_first_segment_w;
    wire         is_last_segment_w;
    reg          start_d;
    wire         segment_stb;
//  reg          crc_err_r;
    wire         packet_crc_err;
    reg          packet_start;
    wire         we; // write data to buffer
    wire         segment_done_w;
    reg          segment_busy_r;
    reg          segment_running; // may be discarded
    reg    [3:0] segment_id_r;
    wire         frame_in_done;
//    reg          packet_running; // may be discarded

    assign is_first_segment_w = (exp_segment == VOSPI_SEGMENT_FIRST);
    assign is_last_segment_w =  (exp_segment == VOSPI_SEGMENT_LAST);
    assign segment_id =         packet_id[15:12]; 
//    assign segment_good_w =     (packet_id[15:12] == exp_segment) || ((packet_id[15:12] == 0) && segm0_ok);
    assign segment_good_w =     (segment_id == exp_segment) || ((packet_id[15:12] == 0) && segm0_ok);
    assign segment_stb =        id_stb && (packet_id[11:0] == VOSPI_PACKET_TTT);
    assign we =                 segment_running && !discard_segment_r && packet_dv;
    assign crc_err =            packet_done && packet_crc_err; // crc_err_r;
    assign segment_done_w =     segment_running && packet_done && (packet_id[11:0] == VOSPI_PACKET_LAST) ;
    assign id =                 segment_id_r;
    assign frame_in_done =      segment_done_w && last_segment_in;
    
    assign in_busy=             segment_busy_r;       // waiting for or receiving a segment
    assign discard_segment=     discard_segment_r;    // segment was disc arded  
    
    assign dbg_running =        segment_running;
    // To Buffer
    always @ (posedge clk) begin
//        if      (rst)   first_segment_in <= 0;
//        else if (start) first_segment_in <= is_first_segment_w;

        if      (rst)   last_segment_in <= 0;
        else if (start) last_segment_in <= is_last_segment_w;
        
        start_d <= start;
        
        discard_set <=  segment_running && !discard_segment_r && segment_stb && !segment_good_w;
        
        segment_good <= segment_running && !discard_segment_r && segment_stb && segment_good_w;
        
        if (segment_running && !discard_segment_r && segment_stb) segment_id_r <= packet_id[15:12];
        
        if      (start)        discard_segment_r <= 0;
        else if (discard_set)  discard_segment_r <= 1;
        
        if      (start)        running_good <= 0;
        else if (segment_good) running_good <= 1;
        
        if (start_d || running_good) full_packet_verified <= full_packet;
        
        
        
        if (start_d) segment_start_packet <= full_packet;
        if (start_d) segment_start_waddr <=  waddr;

        if (rst || (start && is_first_segment_w))                      full_packet <= 0;
        else if (discard_set)                                          full_packet <= segment_start_packet;
        else if (!discard_segment_r && !packet_invalid && packet_done) full_packet <= full_packet + 1;
        
//        if      (rst || start)                    crc_err_r <= 0;
//        else if (packet_done && packet_crc_err)   crc_err_r <= 0;
        
        if      (rst)            segment_busy_r <= 0;
        else if (start)          segment_busy_r <= 1'b1;
        else if (segment_done_w) segment_busy_r <= 1'b0;
        
        segment_done <= segment_done_w; // module output reg
        
        if      (!segment_busy_r || start)                           segment_running <= 0;
        else if (id_stb && (packet_id[11:0] == VOSPI_PACKET_FIRST))  segment_running <= 1;
        
//        packet_start <= !rst && !packet_busy && segment_busy_r;
        packet_start <= !rst && !packet_busy && segment_busy_r && !packet_start;
        
        if      (rst)            waddr <= 0;
        else if (discard_set)    waddr <= segment_start_waddr;
        else if (we)             waddr <= waddr + 1;
        
        if      (rst)            full_packet_frame <= 0; // not needed?
        else if (frame_in_done)  full_packet_frame <=~full_packet_frame;
    end
// From buffer, generating frame
    reg          out_request;
    reg          out_frame;
    wire         sof_w;
    reg          sof_r;
    wire         eof_w;
    reg   [ 2:0] eof_r;
    wire         start_out_frame_w;
    reg   [ 7:0] full_packet_out;          // current full packet number in a fragment
    wire  [ 8:0] packets_avail; //        line_avail; //
    reg          out_pending;   // frame read from the sensor, but not yet output
//    reg          packet_out_done;
    wire         frame_out_done_w; // last packet data was sent out
    wire         frame_dav;
    wire         hact_start_w; // (hact will start next cycle
    wire         hact_end_w;
`ifdef SIMULATION
    reg   [15:0] duration_cntr;
`else    
    reg   [ 7:0] duration_cntr;
`endif
    reg    [2:0] hact_r;
    reg          pend_eof_r;
    reg   [10:0] raddr;



    assign start_out_frame_w = segment_good && is_first_segment_w && out_request;
    assign packets_avail =     {1'b0,full_packet_verified} - {1'b0,full_packet_out} - VOSPI_PACKETS_PER_LINE;
//    assign frame_out_done_w =  packet_out_done && (full_packet_out == (VOSPI_PACKETS_FRAME - 1));
    assign frame_out_done_w =  hact_end_w  &&  (full_packet_out == (VOSPI_PACKETS_FRAME - VOSPI_PACKETS_PER_LINE));
    
    assign frame_dav =         !packets_avail[8] || out_pending;
    assign hact_start_w =      out_frame && (duration_cntr == 0) && !hact_r[0] && frame_dav;
    assign hact_end_w =        (duration_cntr == 0) && hact_r[0];
    assign eof_w =             out_frame && (duration_cntr == 0) && pend_eof_r;
    assign sof_w =             !rst && start_out_frame_w;
    assign hact =              hact_r[2];
    assign eof =               eof_r[2];
    assign sof =               sof_r;
    assign out_busy =          out_request | out_frame;
    
    always @ (posedge clk) begin
        if (rst) hact_r <= 0;
        else     hact_r  <= {hact_r[1:0], hact_start_w | (hact_r[0] & ~hact_end_w)};
    
    
        if (rst || start_out_frame_w) full_packet_out <= 0;
        else if (hact_end_w)          full_packet_out <= full_packet_out + VOSPI_PACKETS_PER_LINE;
    
        if      (rst)                 out_request <= 0;
        else if (out_en)              out_request <= 1;
        else if (sof_r)               out_request <= 0;
        
        if      (rst)                 out_frame <= 0;
        else if (start_out_frame_w)   out_frame <= 1;
        else if (eof_r[0])            out_frame <= 0;
        
        sof_r <= sof_w;
        
        eof_r <= {eof_r[1:0], eof_w};
        
        if      (rst)               out_pending <= 0; // not needed?
        else if (frame_in_done)     out_pending <= 1;
        else if (frame_out_done_w)  out_pending <= 0;
        
        if      (rst)               pend_eof_r <= 0; // not needed?
        else if (frame_out_done_w)  pend_eof_r <= 1;
//        else if (eof_r[0])          pend_eof_r <= 0;
        else if (eof_w)             pend_eof_r <= 0;
        
        if      (rst)               duration_cntr <= 0;
        else if (start_out_frame_w) duration_cntr <= VOSPI_SOF_TO_HACT;
        else if (hact_start_w)      duration_cntr <= VOSPI_LINE_WIDTH - 1;
        else if (hact_end_w)        duration_cntr <= VOSPI_HACT_TO_HACT_EOF;
        else if (|duration_cntr)    duration_cntr <= duration_cntr - 1;
        
        if      (sof_w)             raddr <= segment_start_waddr;
        else if (hact_r[0])         raddr <= raddr + 1;
    
    end
    
    vospi_packet_80 #(
        .VOSPI_PACKET_WORDS  (VOSPI_PACKET_WORDS), // 80,
        .VOSPI_NO_INVALID    (VOSPI_NO_INVALID)    // 1
    ) vospi_packet_80_i (
        .rst            (rst),            // input
        .clk            (clk),            // input
        .start          (packet_start),   // input
        .spi_clken      (spi_clken),      // output
        .spi_cs         (spi_cs),         // output
        .miso           (miso),           // input
        .dout           (packet_dout),    // output[15:0] 
        .dv             (packet_dv),      // output
        .packet_done    (packet_done),    // output
        .packet_busy    (packet_busy),    // output
        .crc_err        (packet_crc_err), // output
        .id             (packet_id),      // output[15:0] 
        .packet_invalid (packet_invalid), // output - not used, processed internally, no dv generated
        .id_stb         (id_stb)          // output reg 
    );

   ram_var_w_var_r #(
        .COMMENT("vospi_segment"),
        .REGISTERS(1),
        .LOG2WIDTH_WR(4),
        .LOG2WIDTH_RD(4)
    ) buf_i (
        .rclk     (clk),              // input
        .raddr    (raddr),            // input[11:0] 
        .ren      (hact_r[0]),        // input
        .regen    (hact_r[1]),        // input
        .data_out (dout),             // output[7:0] 
        .wclk     (clk),              // input
        .waddr    (waddr),            // input[11:0]
        .we       (we),               // input
        .web      (8'hff),            // input[7:0]
        .data_in  (packet_dout)       // input[7:0]
    );




endmodule

