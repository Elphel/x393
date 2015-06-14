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

    wire   [ 2:0] converter_type;    // 0 - color18, 1 - color20, 2 - mono, 3 - jp4, 4 - jp4-diff, 7 - mono8 (not yet implemented)
    //TODO: assign next 5 values from converter_type[2:0]
    reg    [ 5:0] mb_w_m1;            // macroblock width minus 1 // 3 LSB not used, SHOULD BE SET to 3'b111
    reg    [ 5:0] mb_h_m1;            // macroblock horizontal period (8/16) // 3 LSB not used  SHOULD BE SET to 3'b111
    reg    [ 4:0] mb_hper;            // macroblock horizontal period (8/16) // 3 LSB not used TODO: assign from converter_type[2:0]
    reg    [ 1:0] tile_width;         // memory tile width (can be 128 for monochrome JPEG)   Can be 32/64/128: 0 - 16, 1 - 32, 2 - 64, 3 - 128
    reg           tile_col_width;     // 0 - 16 pixels,  1 -32 pixels
    
    
    // signals connecting modules: cmprs_macroblock_buf_iface_i and cmprs_pixel_buf_iface_i:
    wire          mb_pre_end;         // from cmprs_pixel_buf_iface - just in time to start a new macroblock w/o gaps
    wire          mb_release_buf;     // send required "next_page" pulses to buffer. Having rather long minimal latency in the memory
                                      // controller this can just be the same as mb_pre_end_in        
    wire          mb_pre_start;       // 1 clock cycle before stream of addresses to the buffer
    wire   [ 1:0] start_page;         // page to read next tile from (or first of several pages)
    wire   [ 6:0] macroblock_x;        // macroblock left pixel x relative to a tile (page) Maximal page - 128 bytes wide
    
    // signals connecting modules: cmprs_pixel_buf_iface_i and chn_rd_buf_i:
    wire   [ 7:0] buf_di;             // data from the buffer
    wire   [11:0] buf_ra;             // buffer read address (2 MSB - page number)
    wire   [ 1:0] buf_rd;             // buf {regen, re}
    
    
    // signals connecting modules: chn_rd_buf_i and ???:
    wire   [ 7:0] mb_data_out;       // Macroblock data out in scanline order 
    wire          mb_pre_first_out;  // Macroblock data out strobe - 1 cycle just before data valid
    wire          mb_data_valid;     // Macroblock data out valid
    
    // set derived parameters from converter_type
//    wire   [ 2:0] converter_type;    // 0 - color18, 1 - color20, 2 - mono, 3 - jp4, 4 - jp4-diff, 7 - mono8 (not yet implemented)
    always @(converter_type) begin
        case (converter_type)
            CMPRS_COLOR18:    begin
                        mb_w_m1 <=        17;            // macroblock width minus 1 // 3 LSB not used, SHOULD BE SET to 3'b111
                        mb_h_m1 <=        17;            // macroblock horizontal period (8/16) // 3 LSB not used  SHOULD BE SET to 3'b111
                        mb_hper <=        16;            // macroblock horizontal period (8/16) // 3 LSB not used TODO: assign from converter_type[2:0]
                        tile_width <=      1;            // memory tile width (can be 128 for monochrome JPEG)   Can be 32/64/128: 0 - 16, 1 - 32, 2 - 64, 3 - 128
                        tile_col_width <=  1;            // 0 - 16 pixels,  1 -32 pixels
                     end
            CMPRS_COLOR20:    begin
                        mb_w_m1 <=        19;            // macroblock width minus 1 // 3 LSB not used, SHOULD BE SET to 3'b111
                        mb_h_m1 <=        19;            // macroblock horizontal period (8/16) // 3 LSB not used  SHOULD BE SET to 3'b111
                        mb_hper <=        16;            // macroblock horizontal period (8/16) // 3 LSB not used TODO: assign from converter_type[2:0]
                        tile_width <=      1;            // memory tile width (can be 128 for monochrome JPEG)   Can be 32/64/128: 0 - 16, 1 - 32, 2 - 64, 3 - 128
                        tile_col_width <=  1;            // 0 - 16 pixels,  1 -32 pixels
                     end
            CMPRS_MONO16:    begin
                        mb_w_m1 <=        15;            // macroblock width minus 1 // 3 LSB not used, SHOULD BE SET to 3'b111
                        mb_h_m1 <=        15;            // macroblock horizontal period (8/16) // 3 LSB not used  SHOULD BE SET to 3'b111
                        mb_hper <=        16;            // macroblock horizontal period (8/16) // 3 LSB not used TODO: assign from converter_type[2:0]
                        tile_width <=      2;            // memory tile width (can be 128 for monochrome JPEG)   Can be 32/64/128: 0 - 16, 1 - 32, 2 - 64, 3 - 128
                        tile_col_width <=  1;            // 0 - 16 pixels,  1 -32 pixels
                     end
            CMPRS_JP4:    begin
                        mb_w_m1 <=        15;            // macroblock width minus 1 // 3 LSB not used, SHOULD BE SET to 3'b111
                        mb_h_m1 <=        15;            // macroblock horizontal period (8/16) // 3 LSB not used  SHOULD BE SET to 3'b111
                        mb_hper <=        16;            // macroblock horizontal period (8/16) // 3 LSB not used TODO: assign from converter_type[2:0]
                        tile_width <=      2;            // memory tile width (can be 128 for monochrome JPEG)   Can be 32/64/128: 0 - 16, 1 - 32, 2 - 64, 3 - 128
                        tile_col_width <=  1;            // 0 - 16 pixels,  1 -32 pixels
                     end
            CMPRS_JP4DIFF:    begin
                        mb_w_m1 <=        15;            // macroblock width minus 1 // 3 LSB not used, SHOULD BE SET to 3'b111
                        mb_h_m1 <=        15;            // macroblock horizontal period (8/16) // 3 LSB not used  SHOULD BE SET to 3'b111
                        mb_hper <=        16;            // macroblock horizontal period (8/16) // 3 LSB not used TODO: assign from converter_type[2:0]
                        tile_width <=      2;            // memory tile width (can be 128 for monochrome JPEG)   Can be 32/64/128: 0 - 16, 1 - 32, 2 - 64, 3 - 128
                        tile_col_width <=  1;            // 0 - 16 pixels,  1 -32 pixels
                     end
            CMPRS_MONO8:    begin
                        mb_w_m1 <=         7;            // macroblock width minus 1 // 3 LSB not used, SHOULD BE SET to 3'b111
                        mb_h_m1 <=         7;            // macroblock horizontal period (8/16) // 3 LSB not used  SHOULD BE SET to 3'b111
                        mb_hper <=         8;            // macroblock horizontal period (8/16) // 3 LSB not used TODO: assign from converter_type[2:0]
                        tile_width <=      3;            // memory tile width (can be 128 for monochrome JPEG)   Can be 32/64/128: 0 - 16, 1 - 32, 2 - 64, 3 - 128
                        tile_col_width <=  1;            // 0 - 16 pixels,  1 -32 pixels
                     end
            default: begin
                        mb_w_m1 <=        'bx;            // macroblock width minus 1 // 3 LSB not used, SHOULD BE SET to 3'b111
                        mb_h_m1 <=        'bx;            // macroblock horizontal period (8/16) // 3 LSB not used  SHOULD BE SET to 3'b111
                        mb_hper <=        'bx;            // macroblock horizontal period (8/16) // 3 LSB not used TODO: assign from converter_type[2:0]
                        tile_width <=     'bx;            // memory tile width (can be 128 for monochrome JPEG)   Can be 32/64/128: 0 - 16, 1 - 32, 2 - 64, 3 - 128
                        tile_col_width <= 'bx;            // 0 - 16 pixels,  1 -32 pixels
                     end
        endcase
    end
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
        .macroblock_x       (macroblock_x)  // output[6:0] 
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
        .pre_first_out      (mb_pre_first_out), // output // Macroblock data out strobe - 1 cycle just before data valid
        .data_valid         (mb_data_valid) // output     // Macroblock data out valid
    );

/*
*/



endmodule

