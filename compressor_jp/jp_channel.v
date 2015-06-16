/*******************************************************************************
 * Module: jp_channel
 * Date:2015-06-10  
 * Author: andrey     
 * Description: Top module of JPEG/JP4 compressor channel
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * jp_channel.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  jp_channel.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  jp_channel#(
        parameter CMPRS_COLOR18 =           0, // JPEG 4:2:0 with 18x18 overlapping tiles for de-bayer
        parameter CMPRS_COLOR20 =           1, // JPEG 4:2:0 with 18x18 overlapping tiles for de-bayer (not implemented)
        parameter CMPRS_MONO16 =            2, // JPEG 4:2:0 with 16x16 non-overlapping tiles, color components zeroed
        parameter CMPRS_JP4 =               3, // JP4 mode with 16x16 macroblocks
        parameter CMPRS_JP4DIFF =           4, // JP4DIFF mode TODO: see if correct
        parameter CMPRS_MONO8 =             7  // Regular JPEG monochrome with 8x8 macroblocks (not yet implemented)
)(
    input         rst,
    input         xclk,   // global clock input, compressor single clock rate
    input         xclk2x, // global clock input, compressor double clock rate, nominally rising edge aligned
    // programming interface
    input         mclk,     // global clock, half DDR3 clock, synchronizes all I/O through the command port
    input   [7:0] cmd_ad_in,      // byte-serial command address/data (up to 6 bytes: AL-AH-D0-D1-D2-D3 
    input         cmd_stb_in,     // strobe (with first byte) for the command a/d
    output  [7:0] status_ad,   // status address/data - up to 5 bytes: A - {seq,status[1:0]} - status[2:9] - status[10:17] - status[18:25]
    output        status_rq,   // input request to send status downstream
    input         status_start, // Acknowledge of the first status packet byte (address)
    
    // TODO: Maybe move buffer to memory controller ?
    input         xfer_reset_page_rd, // from mcntrl_tiled_rw
    input         buf_wpage_nxt,     // input
    input         buf_wr,            // input
    input  [63:0] buf_wdata, // input[63:0] 
    
    input         page_ready_chn,     // single mclk (posedge)
    output        next_page_chn      // single mclk (posedge): Done with the page in the  buffer, memory controller may read more data 
    

);
    // Control signals to be defined
    wire          frame_en;           // if 0 - will reset logic immediately (but not page number)
    wire          frame_go;           // start frame: if idle, will start reading data (if available),
                                      // if running - will not restart a new frame if 0.
    wire   [ 4:0] left_marg;          // left margin (for not-yet-implemented) mono JPEG (8 lines tile row) can need 7 bits (mod 32 - tile)
    wire   [12:0] n_blocks_in_row_m1; // number of macroblocks in a macroblock row minus 1
    wire   [12:0] n_block_rows_m1;    // number of macroblock rows in a frame minus 1
    wire          ignore_color;       // zero Cb/Cr components (TODO: maybe include into converter_type?)
    wire   [ 1:0] bayer_phase;        // [1:0])  bayer color filter phase 0:(GR/BG), 1:(RG/GB), 2: (BG/GR), 3: (GB/RG)
    wire          four_blocks;        // use only 6 blocks for the output, not 6
    wire          jp4_dc_improved;    // in JP4 mode, compare DC coefficients to the same color ones
    wire   [ 1:0] tile_margin;        // margins around 16x16 tiles (0/1/2)
    wire   [ 2:0] tile_shift;         // tile shift from top left corner
    wire   [ 2:0] converter_type;     // 0 - color18, 1 - color20, 2 - mono, 3 - jp4, 4 - jp4-diff, 7 - mono8 (not yet implemented)
    wire          scale_diff;         // divide differences by 2 (to fit in 8-bit range)
    wire          hdr;                // second green absolute, not difference
    wire          subtract_dc_in;     // subtract/restore DC components
    wire   [ 9:0] m_cb;               // [9:0] scale for CB - default 0.564 (10'h90)
    wire   [ 9:0] m_cr;               // [9:0] scale for CB - default 0.713 (10'hb6)



    //TODO: assign next 5 values from converter_type[2:0]
    wire   [ 5:0] mb_w_m1;            // macroblock width minus 1 // 3 LSB not used, SHOULD BE SET to 3'b111
    wire   [ 5:0] mb_h_m1;            // macroblock horizontal period (8/16) // 3 LSB not used  SHOULD BE SET to 3'b111
    wire   [ 4:0] mb_hper;            // macroblock horizontal period (8/16) // 3 LSB not used TODO: assign from converter_type[2:0]
    wire   [ 1:0] tile_width;         // memory tile width (can be 128 for monochrome JPEG)   Can be 32/64/128: 0 - 16, 1 - 32, 2 - 64, 3 - 128
    wire          tile_col_width;     // 0 - 16 pixels,  1 -32 pixels
    
    
    // signals connecting modules: cmprs_macroblock_buf_iface_i and cmprs_pixel_buf_iface_i:
    wire          mb_pre_end;         // from cmprs_pixel_buf_iface - just in time to start a new macroblock w/o gaps
    wire          mb_release_buf;     // send required "next_page" pulses to buffer. Having rather long minimal latency in the memory
                                      // controller this can just be the same as mb_pre_end_in        
    wire          mb_pre_start;       // 1 clock cycle before stream of addresses to the buffer
    wire   [ 1:0] start_page;         // page to read next tile from (or first of several pages)
    wire   [ 6:0] macroblock_x;       // macroblock left pixel x relative to a tile (page) Maximal page - 128 bytes wide
    
    // signals connecting modules: cmprs_macroblock_buf_iface_i and cmprs_buf_average:
    
     wire         first_mb;           // output reg 
     wire         last_mb;            // output
    
    // signals connecting modules: cmprs_pixel_buf_iface_i and chn_rd_buf_i:
    wire   [ 7:0] buf_di;             // data from the buffer
    wire   [11:0] buf_ra;             // buffer read address (2 MSB - page number)
    wire   [ 1:0] buf_rd;             // buf {regen, re}
    
    
    // signals connecting modules: chn_rd_buf_i and ???:
    wire   [ 7:0] mb_data_out;       // Macroblock data out in scanline order 
    wire          mb_pre_first_out;  // Macroblock data out strobe - 1 cycle just before data valid
    wire          mb_data_valid;     // Macroblock data out valid
    
    wire           limit_diff     = 1'b1;  // as in the prototype - just a constant 1
    
    // signals connecting modules: csconvert and cmprs_buf_average:
    
 
    wire   [8:0]  signed_y; // was y_in
    wire   [8:0]  signed_c; // was c_in
    wire   [7:0]  yaddrw; 
    wire          ywe; 
    wire   [7:0]  caddrw; 
    wire          cwe; 
    wire          yc_pre_first_out; // pre first output from color converter (was  pre_first_out) - last cycle of writing (may inc wpage
    // How they are used? Can it be average instead?  
    wire   [7:0]  n000;  // number of all 0 in macroblock (255 for 256), valid only for color JPEG 
    wire   [7:0]  n255;  // number of all 255 in macroblock (255 for 256), valid only for color JPEG 
    
    // signals connecting modules: cmprs_buf_average and ???:

    wire   [ 9:0] yc_nodc;         // [9:0] data out (4:2:0) (signed, average=0)
    wire   [ 8:0] yc_avr;          // [8:0]    DC (average value) - RAM output, no register. For Y components 9'h080..9'h07f, for C - 9'h100..9'h0ff!
    wire          yc_nodc_dv;         // out data valid (will go high for at least 64 cycles)
    wire          yc_nodc_ds;         // single-cycle mark of the first_r pixel in a 64 (8x8) - pixel block
    wire   [ 2:0] yc_nodc_tn;   // [2:0] tile number 0..3 - Y, 4 - Cb, 5 - Cr (valid with start)
    wire          yc_nodc_first;      // sending first_r MCU (valid @ ds)
    wire          yc_nodc_last;       // sending last_r MCU (valid @ ds)
// below signals valid at ds ( 1 later than tn, first_r, last_r)
    wire    [2:0] yc_nodc_component_num;    //[2:0] - component number (YCbCr: 0 - Y, 1 - Cb, 2 - Cr, JP4: 0-1-2-3 in sequence (depends on shift) 4 - don't use
    wire          yc_nodc_component_color;  // use color quantization table (YCbCR, jp4diff)
    wire          yc_nodc_component_first;   // first_r this component in a frame (DC absolute, otherwise - difference to previous)
    wire          yc_nodc_component_lastinmb; // last_r component in a macroblock;



    
    
// set derived parameters from converter_type
//    wire   [ 2:0] converter_type;    // 0 - color18, 1 - color20, 2 - mono, 3 - jp4, 4 - jp4-diff, 7 - mono8 (not yet implemented)
    cmprs_tile_mode_decode #( // fully combinatorial
        .CMPRS_COLOR18(0),
        .CMPRS_COLOR20(1),
        .CMPRS_MONO16(2),
        .CMPRS_JP4(3),
        .CMPRS_JP4DIFF(4),
        .CMPRS_MONO8(7)
    ) cmprs_tile_mode_decode_i (
        .converter_type  (converter_type), // input[2:0] 
        .mb_w_m1         (mb_w_m1),        // output[5:0] reg 
        .mb_h_m1         (mb_h_m1),        // output[5:0] reg 
        .mb_hper         (mb_hper),        // output[4:0] reg 
        .tile_width      (tile_width),     // output[1:0] reg 
        .tile_col_width  (tile_col_width)  // output reg 
    );
    
//mb_pre_first_out    
// Port buffer - TODO: Move to memory controller
    mcntrl_buf_rd #(
        .LOG2WIDTH_RD(3) // 64 bit external interface
    ) chn_rd_buf_i (
        .ext_clk      (xclk), // input
        .ext_raddr    (buf_ra), // input[11:0] 
        .ext_rd       (buf_rd[0]), // input
        .ext_regen    (buf_rd[1]), // input
        .ext_data_out (buf_di), // output[7:0] 
        .wclk         (!mclk), // input
        .wpage_in     (2'b0), // input[1:0] 
        .wpage_set    (xfer_reset_page_rd), // input  TODO: Generate @ negedge mclk on frame start
        .page_next    (buf_wpage_nxt), // input
        .page         (), // output[1:0]
        .we           (buf_wr), // input
        .data_in      (buf_wdata) // input[63:0] 
    );

    cmprs_macroblock_buf_iface cmprs_macroblock_buf_iface_i (
        .rst                (rst), // input
        .xclk               (xclk), // input
        .mclk               (mclk), // input
        .xfer_reset_page_rd (xfer_reset_page_rd), // input
        .page_ready_chn     (page_ready_chn), // input
        .next_page_chn      (next_page_chn), // output
        .frame_en           (frame_en), // input
        .frame_go           (frame_go), // input
        .left_marg          (left_marg), // input[4:0] 
        .n_blocks_in_row_m1 (n_blocks_in_row_m1), // input[12:0] 
        .n_block_rows_m1    (n_block_rows_m1), // input[12:0] 
        .mb_w_m1            (mb_w_m1), // input[5:0]   // macroblock width minus 1 // 3 LSB not used - set them to all 1
        .mb_hper            (mb_hper), // input[4:0]   // macroblock horizontal period (8/16) // 3 LSB not used (set them 0)
        .tile_width         (tile_width), // input[1:0]   // memory tile width. Can be 32/64/128: 0 - 16, 1 - 32, 2 - 64, 3 - 128
        .mb_pre_end_in      (mb_pre_end), // input
        .mb_release_buf     (mb_release_buf), // input
        .mb_pre_start_out   (mb_pre_start), // output
        .start_page         (start_page), // output[1:0] 
        .macroblock_x       (macroblock_x),  // output[6:0] 
        .first_mb           (first_mb), // output reg 
        .last_mb            (last_mb) // output
        
    );

    cmprs_pixel_buf_iface #(
        .CMPRS_PREEND_EARLY      (6), // TODO:Check / Adjust
        .CMPRS_RELEASE_EARLY     (16),
        .CMPRS_BUF_EXTRA_LATENCY (0),
        .CMPRS_COLOR18           (CMPRS_COLOR18),
        .CMPRS_COLOR20           (CMPRS_COLOR20),
        .CMPRS_MONO16            (CMPRS_MONO16),
        .CMPRS_JP4               (CMPRS_JP4),
        .CMPRS_JP4DIFF           (CMPRS_JP4DIFF),
        .CMPRS_MONO8             (CMPRS_MONO8)
         
    ) cmprs_pixel_buf_iface_i (
        .xclk               (xclk), // input
        .frame_en           (frame_en), // input
        .buf_di             (buf_di), // input[7:0] 
        .buf_ra             (buf_ra), // output[11:0] 
        .buf_rd             (buf_rd), // output[1:0] 
        .converter_type     (converter_type), // input[2:0] 
        .mb_w_m1            (mb_w_m1), // input[5:0] 
        .mb_h_m1            (mb_h_m1), // input[5:0] 
        .tile_width         (tile_width), // input[1:0] 
        .tile_col_width     (tile_col_width), // input
        .mb_pre_end         (mb_pre_end), // output
        .mb_release_buf     (mb_release_buf), // output
        .mb_pre_start       (mb_pre_start), // input
        .start_page         (start_page), // input[1:0] 
        .macroblock_x       (macroblock_x), // input[6:0] 
        .data_out           (mb_data_out), // output[7:0] // Macroblock data out in scanline order
        .pre_first_out      (mb_pre_first_out), // output // Macroblock data out strobe - 1 cycle just before data valid  == old pre_first_pixel?
        .data_valid         (mb_data_valid) // output     // Macroblock data out valid
    );

    csconvert #(
        .CMPRS_COLOR18   (CMPRS_COLOR18),
        .CMPRS_COLOR20   (CMPRS_COLOR20),
        .CMPRS_MONO16    (CMPRS_MONO16),
        .CMPRS_JP4       (CMPRS_JP4),
        .CMPRS_JP4DIFF   (CMPRS_JP4DIFF),
        .CMPRS_MONO8     (CMPRS_MONO8)
    ) csconvert_i (
        .xclk           (xclk),             // input
        .frame_en       (frame_en),         // input
        .converter_type (converter_type),   // input[2:0] 
        .ignore_color   (ignore_color),     // input
        .scale_diff     (scale_diff),       // input
        .hdr            (hdr),              // input
        .limit_diff     (limit_diff),       // input
        .m_cb           (m_cb),             // input[9:0] 
        .m_cr           (m_cr),             // input[9:0] 
        .mb_din         (mb_data_out),      // input[7:0] 
        .bayer_phase    (bayer_phase),      // input[1:0] 
        .pre_first_in   (mb_pre_first_out), // input
        .signed_y       (signed_y),         // output[8:0] reg 
        .signed_c       (signed_c),         // output[8:0] reg 
        .yaddrw         (yaddrw),           // output[7:0] reg 
        .ywe            (ywe),              // output reg 
        .caddrw         (caddrw),           // output[7:0] reg 
        .cwe            (cwe),              // output reg 
        .pre_first_out  (yc_pre_first_out), // output reg 
        .n000           (n000),             // output[7:0] reg 
        .n255           (n255)              // output[7:0] reg 
    );


    cmprs_buf_average #(
        .CMPRS_COLOR18   (CMPRS_COLOR18),
        .CMPRS_COLOR20   (CMPRS_COLOR20),
        .CMPRS_MONO16    (CMPRS_MONO16),
        .CMPRS_JP4       (CMPRS_JP4),
        .CMPRS_JP4DIFF   (CMPRS_JP4DIFF),
        .CMPRS_MONO8     (CMPRS_MONO8)
    ) cmprs_buf_average_i (
        .xclk               (xclk),             // input
        .frame_en           (frame_en),         // input
        .converter_type     (converter_type),   // input[2:0] 
        .pre_first_in       (mb_pre_first_out), // input
        .yc_pre_first_out   (yc_pre_first_out), // input
        .bayer_phase        (bayer_phase),      // input[1:0] 
        .jp4_dc_improved    (jp4_dc_improved),  // input
        .hdr                (hdr),              // input
        .subtract_dc_in     (subtract_dc_in),   // input
        .first_mb_in        (first_mb),         // input - calculate in cmprs_macroblock_buf_iface 
        .last_mb_in         (last_mb),          // input - calculate in cmprs_macroblock_buf_iface
        .yaddrw             (yaddrw),           // input[7:0] 
        .ywe                (ywe),              // input
        .signed_y           (signed_y),         // input[8:0] 
        .caddrw             (caddrw),           // input[7:0] 
        .cwe                (cwe),              // input
        .signed_c           (signed_c),         // input[8:0] 
        .do                 (yc_nodc), // output[9:0] 
        .avr                (yc_avr), // output[8:0] 
        .dv                 (yc_nodc_dv), // output
        .ds                 (yc_nodc_ds), // output
        .tn                 (yc_nodc_tn), // output[2:0] 
        .first              (yc_nodc_first), // output reg 
        .last               (yc_nodc_last), // output reg 
        .component_num      (yc_nodc_component_num), // output[2:0] 
        .component_color    (yc_nodc_component_color), // output
        .component_first    (yc_nodc_component_first), // output
        .component_lastinmb (yc_nodc_component_lastinmb) // output reg 
    );

endmodule

