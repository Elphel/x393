/*!
 * <b>Module:</b>nmea_decoder393
 * @file nmea_decoder393.v
 * @date 2023-02-09  
 * @author Andrey Filippov     
 *
 * @brief Decode some of the NMEA sentences (to compress them)
 *
 * @copyright Copyright (c) 2015 Elphel, Inc.
 *
 * <b>License:</b>
 *
 * imx5_decoder393.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  imx5_decoder393.v is distributed in the hope that it will be useful,
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

module  imx5_decoder393(
    input                         xclk,    // half frequency (80 MHz nominal)
//  input                         start,  // start of the serial message
//  input                         rs232_wait_pause,// may be used as reset for decoder
    input                         start_char,           // serial character start (single pulse)
//    output reg                    nmea_sent_start,  // serial character start (single pulse)
    input                         ser_di, // serial data in (LSB first)
    input                         ser_stb,// serial data strobe, single-cycle, first cycle after ser_di valid
    
    output                        rdy,    // encoded nmea data ready
    input                         rd_stb, // encoded nmea data read strobe (increment address)
    output                 [15:0] rdata,   // encoded data (16 bits)
    input                         ser_rst,
    output                        ts_rq,
    output                 [3:0]  ts_mode);
    localparam  CHR_START = 8'hff;
    localparam  CHR_STOP =  8'hfe;
    localparam  CHR_ESC =   8'hfd; // invert next byte
    localparam  PACKET_ID = 8'h04; // data packet
//    output                 [23:0] debug);
    
    reg     [7:0] odbuf0_ram[0:63]; // byte-wide in, 16-bit output
    reg     [7:0] odbuf1_ram[0:63];
    reg     [5:0] raddr;            // memory buffer read out address (16-bit words)
    reg     [6:0] waddr;            // byte counter
    reg           pre_wr;
    reg     [1:0] buf_we;
    reg     [3:0] stb;
    reg     [7:0] byte_sr;
    reg     [7:0] byte_in;
    reg     [2:0] bit_cntr;
    reg           header_run;
    reg           did_start;
    reg           rec_run;
//    reg           footer_run;
    reg           got_start;
    reg           got_stop;
    reg           got_esc;
    reg     [2:0] got_char;
    reg           proc_escape;
    reg           nreset_r;
    reg           ser_stb_r;
    reg     [2:0] sr_byte_got;
//    reg           rec_done;
    reg     [3:0] rec_errs; // wrong record - abandon;
    reg     [7:0] byte_count;
    reg     [7:0] did_len;
//    reg     [7:0] did;
    reg     [5:0] out_cntr; // bytes left in packet (of 64)
    wire          got_special_w;
    reg           byte_count_zero;
    reg     [5:0] last_word_written;  // number of the last word (4 nibbles) written - used to deassert rdy (garbage after)
    reg     [4:0] out_words;
    reg           rdy_r=1'b0;
    
    
//    reg     
    wire          packet_run_w;
    
    reg           ts_rq_r;   // initial ts and all but last 
    // delaying ts request until prev. one packet is served
    reg           ts_rq_pend; // pending ts request, waiting packet to be sent out
    reg           ts_rq_next; // end of ts_rq_pend, issue timestamp request
//    reg           nxt_frag;  // next packet fragment (request a new timestamp, output pack_frag to be included in usec of ts.
    reg           frag_start; // first one will start before ts request (packet will be aborted if wrong header)
    reg           frag_done;  // next packet fragment (request a new timestamp, output pack_frag to be included in usec of ts.
    reg     [1:0] pack_frag; // fragment of a packet sent to the logger
    
    assign ts_rq =   ts_rq_r;
    assign rdy =     rdy_r;
    
    assign ts_mode = {1'b1, 1'b0, pack_frag};
    assign got_special_w = got_start || got_stop || got_esc;
    assign packet_run_w = header_run || rec_run;
    
    assign rdata[ 7: 0] = odbuf0_ram[raddr[5:0]];
    assign rdata[15: 8] = odbuf1_ram[raddr[5:0]];
    
    
    always @ (posedge xclk) begin
        nreset_r <= !ser_rst;
        stb[3:0] <= {stb[2:0], ser_stb};
        ser_stb_r <= nreset_r && ser_stb;
        
        if (!nreset_r || start_char)  bit_cntr <= 0;
        else if (ser_stb_r)           bit_cntr <= bit_cntr+1;
        
        if (ser_stb_r) byte_sr <=  {ser_di, byte_sr[7:1]};
        sr_byte_got <= {sr_byte_got[1:0], &bit_cntr & ser_stb_r};
        got_start <= sr_byte_got[0] && (byte_sr == CHR_START);
        got_stop <=  sr_byte_got[0] && (byte_sr == CHR_STOP);
        got_esc <=   sr_byte_got[0] && (byte_sr == CHR_ESC);
        got_char <=  {got_char[1:0], sr_byte_got[1] & !got_special_w};
        
        if (!nreset_r || got_char) proc_escape <= 0;
        else if (got_esc)          proc_escape <= 1;
        
        if (got_char[0]) byte_in <= byte_sr ^ {8{proc_escape}}; 
        
        if (!nreset_r  || |rec_errs || got_stop || did_start) header_run <= 0;
        else if (got_start)                                   header_run <= 1;

// do not end on stop until written out
        if (!nreset_r  || (frag_done && byte_count_zero))     rec_run <= 0;
        else if (did_start)                                   rec_run <= 1;
        
// add footer?        
        
        if      (got_start)    byte_count <= 8'h0e;
        else if (did_start)    byte_count <= did_len - 1;
        else if  (got_char[2]) byte_count <= byte_count - 1;
//        else if (pre_wr)       byte_count <= byte_count - 1;
        byte_count_zero <= packet_run_w && (byte_count == 0);
        
        did_start <= header_run && got_char[1] && byte_count_zero;
        
        rec_errs[0] <= header_run && got_char[1] && (byte_count[3:0] == 4'he) && (byte_in != PACKET_ID);
//        if (header_run && got_char[1] && (byte_count[3:0] == 4'hb)) did <=     byte_in;
        if (header_run && got_char[1] && (byte_count[3:0] == 4'h7)) did_len <= byte_in;
        
        if (!packet_run_w) waddr <= 0;
        else if (|buf_we)  waddr <= waddr + 1;
        // some bytes from the header and all bytes from the data
        pre_wr <= got_char[1] && ((header_run && ((byte_count[3:1] == 5) || (byte_count[3:1] == 3))) || rec_run);
        
        buf_we <= {2{pre_wr}} & {waddr[0],~waddr[0]};
        
        if (buf_we[0]) odbuf0_ram[waddr[6:1]] <= byte_in;
        if (buf_we[1]) odbuf1_ram[waddr[6:1]] <= byte_in;
        
        if (pre_wr) last_word_written[5:0] <= waddr[6:1];
        
        if (!packet_run_w)  pack_frag <= 0;
        else if (frag_done) pack_frag <= pack_frag + 1;
        
        frag_done <= pre_wr && rec_run && ((byte_count == 0) || (out_cntr == 0));
        frag_start <= got_start || (frag_done && !byte_count_zero); 
        
        if (frag_start)  out_cntr <= 6'h37;
        else if (pre_wr) out_cntr <= out_cntr - 1;
        
        if (!rec_run || ts_rq_next)             ts_rq_pend <= 0;
        else if (frag_done && !byte_count_zero) ts_rq_pend <= 1;
        
        ts_rq_next <= ts_rq_pend && !rdy_r && !rd_stb;
       // nxt_frag        
       //    reg           ts_rq_pend; // pending ts request, waiting packet to be sent out
       // reg           ts_rq_next; // end of ts_rq_pend, issue timestamp request
       
        ts_rq_r <= did_start || ts_rq_next; // (frag_done && !byte_count_zero); //first start only after header processed OK;
        if      (!rdy_r) out_words <= 5'h1b;
        else if (rd_stb) out_words <=  out_words - 1;
        
        if (!nreset_r || header_run) raddr <= 0;
        else if (rd_stb)             raddr <=  raddr + 1;
        
        if (!nreset_r || header_run || (out_words == 0) || (raddr == last_word_written)) rdy_r <= 0;
        else if (frag_done) rdy_r <= 1;
        
    end    
endmodule
