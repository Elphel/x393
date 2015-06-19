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
    output        next_page_chn,      // single mclk (posedge): Done with the page in the  buffer, memory controller may read more data 
// statistics data was not used in late nc353    
    output        statistics_dv,
    output [15:0] statistics_do
    

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

    reg    [ 1:0] cmprs_fmode_this;   // focusing/overlay mode

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
    wire          dct_start;         // single-cycle mark of the first_r pixel in a 64 (8x8) - pixel block
    wire   [ 2:0] color_tn;   // [2:0] tile number 0..3 - Y, 4 - Cb, 5 - Cr (valid with start)
    wire          color_first;      // sending first_r MCU (valid @ ds)
    wire          color_last;       // sending last_r MCU (valid @ ds)
// below signals valid at ds ( 1 later than tn, first_r, last_r)
    wire    [2:0] component_num;    //[2:0] - component number (YCbCr: 0 - Y, 1 - Cb, 2 - Cr, JP4: 0-1-2-3 in sequence (depends on shift) 4 - don't use
    wire          component_color;  // use color quantization table (YCbCR, jp4diff)
    wire          component_first;  // first this component in a frame (DC absolute, otherwise - difference to previous)
    
    wire          component_lastinmb; // last_r component in a macroblock;



    
    
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
        .do                 (yc_nodc),          // output[9:0] 
        .avr                (yc_avr),           // output[8:0] 
        .dv                 (yc_nodc_dv),       // output
        .ds                 (dct_start),        // output
        .tn                 (color_tn),         // output[2:0] 
        .first              (color_first),      // output reg 
        .last               (color_last),       // output reg 
        .component_num      (component_num),    // output[2:0] 
        .component_color    (component_color),  // output
        .component_first    (component_first),  // output
        .component_lastinmb (component_lastinmb)// output reg 
    );
//  wire   [ 9:0] yc_nodc;         // [9:0] data out (4:2:0) (signed, average=0)

    wire          dct_last_in;
    wire          dct_pre_first_out;
    wire          dct_dv;
    wire   [12:0] dct_out;
    
    
 //propagation of first block through compressor pipeline
 
    wire          first_block_color=(color_tn[2:0]==3'h0) && color_first;        // while color conversion,
    reg           first_block_color_after;  // after color conversion,
    reg           first_block_dct;     // after DCT
    wire          first_block_quant;   // after quantizer
    always @ (posedge xclk) begin
        if (dct_start)   first_block_color_after <= first_block_color;
        if (dct_last_in) first_block_dct   <= first_block_color_after;
    end
    
    
    
    
    xdct393 xdct393_i (
        .clk                (xclk), // input
        .en                 (frame_en), // input  if zero will reset transpose memory page numbers
        .start              (dct_start), // input  single-cycle start pulse that goes with the first pixel data. Other 63 should follow
        .xin                (yc_nodc), // input[9:0] 
        .last_in            (dct_last_in), // output reg  output high during input of the last of 64 pixels in a 8x8 block //
        .pre_first_out      (dct_pre_first_out), // outpu 1 cycle ahead of the first output in a 64 block
        .dv                 (dct_dv), // output data output valid. Will go high on the 94-th cycle after the start (now - on 95-th?)
        .d_out              (dct_out) // output[12:0] 
    );
    wire          quant_start;
    dly_16 #(.WIDTH(1)) i_quant_start (.clk(xclk),.rst(1'b0), .dly(0), .din(dct_pre_first_out), .dout(quant_start));    // dly=0+1
 
    reg    [ 2:0] cmprs_qpage_this;
    wire          first_block_quant;
    wire   [12:0] quant_do; 
    wire          quant_ds;
    wire   [15:0] quant_dc_tdo;// MSB aligned coefficient for the DC component (used in focus module)
    wire   [ 2:0] coring_num;
    reg           dcc_en;
    wire          dccout;
    wire   [ 2:0] hfc_sel;

    wire   [15:0] dccdata; // was not used in late nc353
    wire          dccvld;  // was not used in late nc353
    
    always @ (posedge xclk) begin
        if (!dccout) dcc_en <=1'b0;
        else if (dct_start && color_first && (color_tn[2:0]==3'b001)) dcc_en <=1'b1; // 3'b001 - closer to the first "start" in quantizator
    end
    
    
    wire          table_a_not_d; // writing table address /not data (a[0] from cmd_deser)
    wire          table_we;      // writing to tables               (decoded stb from cmd_deser)
    wire   [31:0] table_di;      // 32-bit data to write to tables (LSB first) - from cmd_deser
    wire          tser_a_not_d;  // address/not data distributed to submodules
    wire   [ 7:0] tser_d;        // byte-wide serialized tables address/data to submodules
    wire          tser_qe;       // write serialized table data to quantizer
    wire          tser_ce;       // write serialized table data to coring
    wire          tser_fe;       // write serialized table data to focusing
    wire          tser_he;       // write serialized table data to Huffman
    
    table_ad_transmit #(
        .NUM_CHANNELS(4),
        .ADDR_BITS(3)
    ) table_ad_transmit_i (
        .clk             (mclk),                  // input @posedge
        .a_not_d_in      (table_a_not_d),         // input writing table address /not data (a[0] from cmd_deser)
        .we              (table_we),              // input writing to tables               (decoded stb from cmd_deser)
        .din             (table_di),              // input[31:0] 32-bit data to serialize/write to tables (LSB first) - from cmd_deser
        .ser_d           (tser_d),                // output[7:0] byte-wide serialized tables address/data to submodules
        .a_not_d         (tser_a_not_d),          // output reg address/not data distributed to submodules
        .chn_en          ({tser_he,tser_fe,tser_ce,tser_qe}) // output[0:0] reg - table 1-hot select outputs
    );
    
    
    
    quantizer393 quantizer393_i (
        .clk                (xclk),                   // input
        .en                 (frame_en),               // input 
        .mclk               (mclk),                   // input system clock, twqe, twce, ta,tdi - valid @posedge (ra, tdi - 2 cycles ahead (was negedge)
        .tser_qe            (tser_qe),                // input - write to a quantization table
        .tser_ce            (tser_ce),                // input - write to a coring table
        .tser_a_not_d       (tser_a_not_d),           // input - address/not data to tables
        .tser_d             (tser_d),                 // input[7:0] - byte-wide data to tables
        .ctypei             (component_color),        // input component type input (Y/C)
        .dci                (yc_avr),                 // input[8:0] - average value in a block - subtracted before DCT. now normal signed number
        .first_stb          (first_block_color),      // input - this is first stb pulse in a frame
        .stb                (dct_start),              // input - strobe that writes ctypei, dci
        .tsi                (cmprs_qpage_this[2:0]),  // input[2:0] - table (quality) select [2:0]
        .pre_start          (dct_pre_first_out),      // input - marks first input pixel (one before)
        .first_in           (first_block_dct),        // input - first block in (valid @ start)
        .first_out          (first_block_quant),      // output reg - valid @ ds
        .di                 (dct_out[12:0]),          // input[12:0] -  pixel data in (signed)
        .do                 (quant_do[12:0]),         // output[12:0] - pixel data out (AC is only 9 bits long?) - changed to 10
        .dv                 (),                       // output reg - data out valid
        .ds                 (quant_ds),               // output reg - data out strobe (one ahead of the start of dv)
        .dc_tdo             (quant_dc_tdo[15:0]),     // output[15:0] reg -  MSB aligned coefficient for the DC component (used in focus module)
        .dcc_en             (dcc_en),                 // input - enable dcc (sync to beginning of a new frame)
        .hfc_sel            (hfc_sel),                // input[2:0] - hight frequency components select [2:0] (includes components with both numbers >=hfc_sel
        .color_first        (color_first),            // input - first MCU in a frame
        .coring_num         (coring_num),             // input[2:0] - coring table pair number (0..7)
        .dcc_vld            (dccvld),                 // output reg  - single cycle when dcc_data is valid
        .dcc_data           (dccdata[15:0]),          // output[15:0] - dc component data out (for reading by software) 
        .n000               (n000),                   // input[7:0] - number of zero pixels (255 if 256) - to be multiplexed with dcc
        .n255               (n255)                    // input[7:0] - number of 0xff pixels (255 if 256) - to be multiplexed with dcc
    );

    // focus sharp module calculates amount of high-frequency components and optioanlly overlays/replaces actual image
    wire   [12:0] focus_do;     // output[12:0] reg  pixel data out, make timing ignore (valid 1.5 clk earlier that Quantizer output)
    wire          focus_ds;     // output reg data out strobe (one ahead of the start of dv)
    wire   [31:0] hifreq;       // output[31:0] reg accumulated high frequency components in a frame sub-window
    
    focus_sharp393 focus_sharp393_i (
        .clk                (xclk),                   // input - pixel clock
        .clk2x              (xclk2x),                 // input 2x pixel clock
        .en                 (frame_en),               // input 

        .mclk               (mclk),                   // input system clock, twqe, twce, ta,tdi - valid @posedge (ra, tdi - 2 cycles ahead (was negedge)
        .tser_we            (tser_fe),                // input - write to a quantization table
        .tser_a_not_d       (tser_a_not_d),           // input - address/not data to tables
        .tser_d             (tser_d),                 // input[7:0] - byte-wide data to tables
        
        .mode               (cmprs_fmode_this[1:0]),  // input[1:0] focus mode (combine image with focus info) - 0 - none, 1 - replace, 2 - combine all,  3 - combine woi
        .firsti             (color_first),            // input first macroblock
        .lasti              (color_last),             // input last macroblock
        .tni                (color_tn[2:0]),          // input[2:0] block number in a macronblock - 0..3 - Y, >=4 - color (sync to stb)
        .stb                (dct_start),              // input strobe that writes ctypei, dci
        .start              (quant_start),            // input marks first input pixel (needs 1 cycle delay from previous DCT stage)
        .di                 (dct_out),                // input[12:0] pixel data in (signed)
        .quant_ds           (quant_ds),               // input quantizator ds
        .quant_d            (quant_do[12:0]),         // input[12:0] quantizator data output
        .quant_dc_tdo       (quant_dc_tdo),           // input[15:0] MSB aligned coefficient for the DC component (used in focus module)
        .do                 (focus_do[12:0]),         // output[12:0] reg  pixel data out, make timing ignore (valid 1.5 clk earlier that Quantizer output)
        .ds                 (focus_ds),               // output reg data out strobe (one ahead of the start of dv)
        .hifreq             (hifreq[31:0])            // output[31:0] reg accumulated high frequency components in a frame sub-window
    );

    // Format DC components to be output as a mini-frame. Was not used in the late NC353 as the dma1 channel was use3d for IMU instead of dcc
    reg           pre_finish_dcc;
    reg           finish_dcc;
    
    dcc_sync393 dcc_sync393_i (
        .sclk               (xclk2x),                // input
        .dcc_en             (dcc_en),                // input xclk rising, sync with start of the frame
        .finish_dcc         (finish_dcc),            // input @ sclk rising
        .dcc_vld            (dccvld),                // input xclk rising
        .dcc_data           (dccdata[15:0]),         // input[15:0] @clk rising
        .statistics_dv      (statistics_dv),         // output reg 
        .statistics_do      (statistics_do[15:0])    // output[15:0] reg @ sclk
    );
    
    wire          enc_last; 
    wire   [15:0] enc_do; 
    wire          enc_dv; 

// generate DC data/strobe for the direct output (re) using sdram channel3 buffering
// encoderDCAC is updated to handle 13-bit signed data instead of the 12-bit. It will limit the values on ot's own
    encoderDCAC393 encoderDCAC393_i (
        .clk                (xclk),                   // input
        .en                 (frame_en),               // input 
        .lasti              (color_last),             // input - was "last MCU in a frame" (@ stb)
        .first_blocki       (first_block_color),      // input - first block in frame - save fifo write address (@ stb)
        .comp_numberi       (component_num[2:0]),     // input[2:0] - component number 0..2 in color, 0..3 - in jp4diff, >= 4 - don't use (@ stb)
        .comp_firsti        (component_first),        // input - first this component in a frame (reset DC) (@ stb)
        .comp_colori        (component_color),        // input - use color - huffman? (@ stb)
        .comp_lastinmbi     (component_lastinmb),     // input - last component in a macroblock (@ stb) is it needed?
        .stb                (dct_start),              // input - strobe that writes firsti, lasti, tni,average
        .zdi                (focus_do[12:0]),         // input[12:0] - zigzag-reordered data input
        .first_blockz       (first_block_quant),      // input - first block input (@zds)
        .zds                (focus_ds),               // input - strobe - one ahead of the DC component output
        .last               (enc_last),               // output reg 
        .do                 (enc_do[15:0]),           // output[15:0] reg 
        .dv                 (enc_dv)                  // output reg 
    );

    wire          last_block;
    wire          test_lbw;
    wire          stuffer_rdy; // receiver (bit stuffer) is ready to accept data;
    wire   [15:0] huff_do;     // output[15:0] reg 
    wire    [3:0] huff_dl;     // output[3:0] reg 
    wire          huff_dv;     // output reg 
    wire          flush;       // output reg 

    huffman393 i_huffman (
        .xclk               (xclk),                   // input
        .xclk2x             (xclk2x),                 // input
        .en                 (frame_en),               // input
        .sclk               (mclk),                   // input - for writing tables - now @posedge
        .twe                (twhe),                   // input - for writing tables - now @posedge mclk
        .ta                 (ta[8:0]),                // input[8:0] - table write address @posedge mclk
        .tdi                (tdi),                    // input[15:0] - table data in @posedge mclk
        .di                 (enc_do[15:0]),           // input[15:0] - specially RLL prepared 16-bit data (to FIFO)
        .ds                 (enc_dv),                 // input -  di valid strobe
        .rdy                (stuffer_rdy),            // input - receiver (bit stuffer) is ready to accept data
        .do(huff_do[15:0]), // output[15:0] reg 
        .dl(huff_dl[3:0]), // output[3:0] reg 
        .dv(huff_dv), // output reg 
        .flush(flush), // output reg 
        .last_block(last_block), // output reg 
        .test_lbw(), // output reg ??
        .gotLastBlock(test_lbw) // output ??
    );
    
  /*
 wire last_block, test_lbw;
 huffman i_huffman  (.pclk(clk),      // pixel clock
                      .clk(clk2x),   // twice frequency - uses negedge inside
                      .en(cmprs_en),      // enable (0 resets counter) sync to .pclk(clk)
//                      .cwr(cwr),      // CPU WR global clock
                      .twe(twhe),      // enable write to a table
                      .ta(ta[8:0]),      // [8:0]  table address
                      .tdi(di[15:0]),      // [23:0] table data in (8 LSBs - quantization data, [13:9] zigzag address
                      .di(enc_do[15:0]),      // [15:0]   specially RLL prepared 16-bit data (to FIFO)
                      .ds(enc_dv),      // di valid strobe
                      .rdy(stuffer_rdy),      // receiver (bit stuffer) is ready to accept data
                      .do(huff_do),      // [15:0]   output data
                      .dl(huff_dl),      // [3:0]   output width (0==16)
                      .dv(huff_dv),      // output data bvalid
                     .flush(flush),
                     .last_block(last_block),
                     .test_lbw(),
                     .gotLastBlock(test_lbw));   // last block done - flush the rest bits
  
  */  
    
    
    wire   [15:0] stuffer_do;
    wire          stuffer_dv;
    wire          stuffer_done;
    reg           stuffer_done_persist;
    wire          stuffer_flushing;
    wire   [23:0] imgptr;
    wire   [31:0] sec;
    wire   [19:0] usec;
    
    always @ (negedge xclk2x) pre_finish_dcc <= stuffer_done;
    always @ (posedge xclk2x) finish_dcc     <= pre_finish_dcc; //stuffer+done - @negedge clk2x

    stuffer393 stuffer393_i (
        .clk                 (xclk2x),                 // input clock - uses negedge inside
        .en                  (cmprs_en_2x_n),          // input
        .reset_data_counters (reset_data_counters[1]), // input reset data transfer counters (only when DMA and compressor are disabled)
        .flush               (flush || force_flush),   // input - flush output data (fill byte with 0, long word with FFs
        .stb                 (huff_dv),                // input
        .dl                  (huff_dl),                // input[3:0] number of bits to send (0 - 16) (0-16??)
        .d                   (huff_do),                // input[15:0] data to shift (only lower huff_dl bits are valid)
// time stamping - will copy time at the end of color_first (later than the first hact after vact in the current froma, but before the next one
// and before the data is needed for output 
        .color_first(color_first), // input
        .sec(sec[31:0]), // input[31:0] 
        .usec(usec[19:0]), // input[19:0] 
        .rdy(stuffer_rdy), // output - enable huffman encoder to proceed. Used as CE for many huffman encoder registers
        .q(stuffer_do), // output[15:0] reg - output data
        .qv(stuffer_dv), // output reg - output data valid
        .done(stuffer_done), // output
        .imgptr(imgptr[23:0]), // output[23:0] reg - image pointer in 32-byte chunks
        .flushing(stuffer_flushing) // output reg 
`ifdef debug_stuffer
       ,.etrax_dma_r(tst_stuf_etrax[3:0]) // [3:0] just for testing
       ,.test_cntr(test_cntr[3:0])
       ,.test_cntr1(test_cntr1[7:0])
`endif
    );
    
/*
 stuffer   i_stuffer  (.clk(clk2x),         //clock - uses negedge inside
                     .en(cmprs_en_2x_n),         // enable, 0- reset
                     .reset_data_counters(reset_data_counters[1]), // reset data transfer counters (only when DMA and compressor are disabled)
                     .flush(flush || force_flush),      // flush output data (fill byte with 0, long word with FFs
                     .stb(huff_dv),       // input data strobe
                     .dl(huff_dl),         // [3:0] number of bits to send (0 - 16)
                     .d(huff_do),          // [15:0] input data to shift (only lower bits are valid)
// time stamping - will copy time at the end of color_first (later than the first hact after vact in the current froma, but before the next one
// and before the data is needed for output 
                     .color_first(color_first), //
                     .sec(sec[31:0]),
                     .usec(usec[19:0]),
                     .rdy(stuffer_rdy),      // enable huffman encoder to proceed. Used as CE for many huffman encoder registers
                     .q(stuffer_do),         // [15:0] output data
                     .qv(stuffer_dv),      // output data valid
                     .done(stuffer_done),
                     .imgptr (imgptr[23:0]), // [23:0]image pointer in 32-byte chunks
                     .flushing(stuffer_flushing)
`ifdef debug_stuffer
                     ,.etrax_dma_r(tst_stuf_etrax[3:0]) // [3:0] just for testing
                     ,.test_cntr(test_cntr[3:0])
                     ,.test_cntr1(test_cntr1[7:0])
`endif
                     );



dcc_sync i_dcc_sync(//.clk(clk),
                    .sclk(clk2x),
                    .dcc_en(dcc_en),                   // clk rising, sync with start of the frame
                    .finish_dcc(finish_dcc),           // sclk rising
                    .dcc_vld(dccvld),                 // clk rising
                    .dcc_data(dccdata[15:0]),         //[15:0] clk risimg
                    .statistics_dv(statistics_dv),     //sclk
                    .statistics_do(statistics_do[15:0])//[15:0] sclk
                 );



//TODO: compact table                     
focus_sharp i_focus_sharp(.clk(clk),   // pixel clock
                   .en(cmprs_en),   // enable (0 resets counter)
                   .sclk(clk2x), // system clock, twe, ta,tdi - valid @negedge (ra, tdi - 2 cycles ahead
                   .twe(twfe), // enable write to a table
                   .ta(ta[9:0]),  // [9:0]  table address
                   .tdi(di[15:0]),  // [15:0] table data in (8 LSBs - quantization data)
                   .mode(cmprs_fmode_this[1:0]), // focus mode (combine image with focus info) - 0 - none, 1 - replace, 2 - combine all,  3 - combine woi
//                   .stren(focus_strength),
                   .firsti(color_first),  // first macroblock
                   .lasti(color_last),    // last macroblock
                   .tni(color_tn[2:0]),   // block number in a macronblock - 0..3 - Y, >=4 - color (sync to stb)
                   .stb(dct_start),      // strobe that writes ctypei, dci
                   .start(quant_start),// marks first input pixel (needs 1 cycle delay from previous DCT stage)
                   .di(dct_out[12:0]),    // [11:0] pixel data in (signed)
                   .quant_ds(quant_ds), // quantizator data strobe (1 before DC)
                   .quant_d(quant_do[12:0]), // quantizator data output
                   .quant_dc_tdo(quant_dc_tdo[15:0]), //[15:0], MSB aligned coefficient for the DC component (used in focus module)
//                   .quant_dc_tdo_stb(quant_dc_tdo_stb),
                   .do(focus_do[12:0]),    // [11:0] pixel data out (AC is only 9 bits long?) - changed to 10
                   .ds(focus_ds),  // data out strobe (one ahead of the start of dv)
                   .hifreq(hifreq[31:0])  //[31:0])  //  accumulated high frequency components in a frame sub-window
                   );


 xdct       i_xdct ( .clk(clk),             // top level module
                     .en(cmprs_en),       // if zero will reset transpose memory page numbers
                     .start(dct_start),    // single-cycle start pulse that goes with the first pixel data. Other 63 should follow
                     .xin(color_d[9:0]),    // [7:0] - input data
                     .last_in(dct_last_in),   // output high during input of the last of 64 pixels in a 8x8 block //
                     .pre_first_out(dct_pre_first_out),// 1 cycle ahead of the first output in a 64 block

                     .dv(dct_dv),          // data output valid. Will go high on the 94-th cycle after the start
                     .d_out(dct_out[12:0]));// [12:0]output data

// probably dcc things are not needed anymore

 always @ (posedge clk) quant_start <= dct_pre_first_out;

 always @ (posedge clk) begin
  if (!dccout) dcc_en <=1'b0;
  else if (dct_start && color_first && (color_tn[2:0]==3'b001)) dcc_en <=1'b1; // 3'b001 - closer to the first "start" in quantizator
 end
 wire [15:0] quant_dc_tdo;// MSB aligned coefficient for the DC component (used in focus module)

 wire [2:0]  coring_num;

   FDE_1   i_coring_num0   (.C(clk2x),.CE(wr_quantizer_mode),.D(di[ 0]),.Q(coring_num[0]));
   FDE_1   i_coring_num1   (.C(clk2x),.CE(wr_quantizer_mode),.D(di[ 1]),.Q(coring_num[1]));
   FDE_1   i_coring_num2   (.C(clk2x),.CE(wr_quantizer_mode),.D(di[ 2]),.Q(coring_num[2]));

*/

endmodule

