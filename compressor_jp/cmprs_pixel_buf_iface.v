/*******************************************************************************
 * Module: cmprs_pixel_buf_iface
 * Date:2015-06-11  
 * Author: andrey     
 * Description: Communicates with compressor memory buffer, generates pixel
 * stream matching selected color mode, accommodates for the buffer latency,
 * acts as a pacemaker for the whole compressor (next stages are able to keep up).
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * cmprs_pixel_buf_iface.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  cmprs_pixel_buf_iface.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  cmprs_pixel_buf_iface #(
        parameter CMPRS_BUF_EXTRA_LATENCY = 0  // extra register layers insered between the buffer and this module
    )(
    input         rst,
    input         xclk,               // global clock input, compressor single clock rate
    
    input         mclk,               // global clock for commands (posedge) and write side of the memory buffer (negedge)
    // buffer interface, DDR3 memory read
    input         xfer_reset_page_rd, // @ negedge mclk - reset ddr3 memory buffer. Use it to reset the read buffer too
    input         page_ready_chn,     // single mclk (posedge)
    output        next_page_chn,      // single mclk (posedge): Done with the page in the  buffer, memory controller may read more data 
    input  [ 7:0] buf_di,             // data from the buffer
    output [11:0] buf_ra,             // buffer read address (1 MSB - page number)
    output [ 1:0] buf_rd,             // buf {regen, re}
     
    input         frame_en,           // if 0 - will reset logic immediately (but not page number)
    input         frame_go,           // start frame: if idle, will start reading data (if available),
                                      // if running - will not restart a new frame if 0.
    input  [ 6:0] mode,               // TODO: adjust width. Color mode that determins address mapping
    input  [ 4:0] left_marg,          // left margin (for not-yet-implemented) mono JPEG (8 lines tile row) can need 7 bits (mod 32 - tile)
    input  [12:0] n_blocks_in_row_m1, // number of macroblocks in a macroblock row minus 1
    input  [12:0] n_block_rows_m1,    // number of macroblock rows in a frame minus 1
    
    output [ 7:0] data_out,           //
    output        pre_first_out,      // For each macroblock in a frame
    output        data_valid          //
);
    localparam CMPRS_MB_DLY=5;
    wire          buf_re_w;
    reg   [CMPRS_BUF_EXTRA_LATENCY+2:0] buf_re;
    reg    [ 7:0] do_r; 
    wire          reset_page_rd;
    wire          page_ready;
//    wire          next_page; // @ posedge xclk - source 
//    wire          busy_next_page; // do not send next_page -previous is crossing clock boundaries
    wire          frame_end_w;    // calculated
    
    wire          frame_en_w;
    reg           frame_en_r;
    wire          pre_frame_start;
    wire          frame_start;
    wire          en;
    reg           pre_en;
    
    reg    [11:0] mb_start;       // full adderss of the next macroblock start;
    reg    [11:0] mbr_start;      // start address of the next macroblock row
    reg    [11:0] buf_ra_r;       // buffer read address
    reg    [ 5:0] mb_w_m1;        // macroblock width minus 1
    reg    [ 5:0] mb_h_m1;        // macroblock height minus 1
//    reg    [ 4:0] left_marg;      // left margin of the leftmost macroblock column relative to read tiles (aligned to 32 bytes)
    reg    [ 4:3] mb_hper;        // macroblock horizontal period (8/16)
    reg    [ 1:0] tile_width;     // memory tile width (can be 128 for monochrome JPEG)   Can be 32/64/128: 0 - 16, 1 - 32, 2 - 64, 3 - 128
    
    reg    [12:0] mb_col;         // number of a macroblock in a row    
    reg    [12:0] mb_row;         // number of a macroblock row
    wire   [ 6:0] mbl_x;          // macroblock left pixel x relative to a tile (page) Maximal page - 128 bytes wide
    reg    [ 6:3] mbl_x_r;        // macroblock left pixel x relative to a tile (page) (3 low don't change)
    reg    [ 6:3] mbl_x_next_r;   // macroblock left pixel x relative to a tile (page), not valid for first column (3 low don't change)    
    reg    [ 7:3] mbl_x_inc_r;    // intermediate register for calculating mbl_x_next_r and add_invalid
    reg    [ 7:3] mbl_x_last_r;   // intermediate register for calculating needed_page
    wire          mb_pre_end_w;   // start mb_pre_end sequence
    reg    [ 3:0] mb_pre_end;     // 1-hot macroblock pre end calcualtions
//    wire          mb_pre_end_done = mb_pre_end[2]; // overlap
    reg    [1:0]  pre_advance_tiles; // advance tiles by this for same row of macroblocks

    wire          mb_pre_start_w; // same timing as mb_pre_end[1]
    reg    [ 4:0] mb_pre_start;   // 1-hot macroblock pre start calcualtions - TODO: adjust width
    wire   [ 2:0] buf_diff;       // difference between page needed and next valid - should be negative to have it ready
    wire          buf_ready_w;    // External memory buffer has all the pages needed
       
    reg           mb_first_in_row;
    reg           mb_last_in_row;
    
    reg    [ 2:0] next_valid;     // number of next valid page (only 2 LSB are actual page number)
    reg    [ 2:0] next_invalid;   // oldest valid page
    reg    [ 1:0] add_invalid;    // advance next_invalid pointer by this value, send next_page pulses
    reg           we_invalid;     // advance next_invalid pointer, send next_page pulses
    reg    [ 2:0] used_pages;     // number of pages simultaneously used for the last macroblock
    reg    [ 2:0] needed_page;    // calculate at MB start
//    reg    [ 1:0] need_pages_m1;  // number of tiles needed for macroblock being started minus 1 (0 - just a single macroblock) 
    
    assign buf_rd = buf_re[1:0];
    assign data_out = do_r;
    
    assign frame_en_w = frame_en && frame_go;
    assign pre_frame_start=frame_en_w && (en?frame_end_w:(!frame_en_r));
    
    assign mbl_x={mbl_x_r[6:3], left_marg[2:0]};
    
    assign buf_diff = needed_page - next_valid;
    assign buf_ready_w = buf_diff[2];
    
    always @ (posedge xclk) begin
        if (!frame_en) frame_en_r <= 0;
        else           frame_en_r <= frame_en_w;
                 
        if      (!frame_en)               pre_en <= 0;
        else if ( frame_end_w || !pre_en) pre_en <= frame_go;
    
        if (!en) buf_re <= 0;
        else buf_re <= {buf_re[CMPRS_BUF_EXTRA_LATENCY+1:0],buf_re_w};
        if (buf_re[CMPRS_BUF_EXTRA_LATENCY+2]) do_r <= buf_di;
        
        // pages read from the external memory, previous one is the last in the buffer
        if   (reset_page_rd) next_valid <= 0;
        else if (page_ready) next_valid <=  next_valid + 1;
        
        // at the end of each macroblock - calculate start page increment (and after delay - advance invalidate_next)
        // calculate next start X in page (regardless of emd of macroblock row - selection will be at macroblock start)
        if (mb_pre_end_w) mb_pre_end <= 1;
        else              mb_pre_end <= mb_pre_end << 1;
        if (mb_pre_end[0]) mbl_x_inc_r[7:3] <= {1'b0,mbl_x_r[6:3]} + {3'b0,mb_hper[4:3]};
        if  (mb_pre_end[1]) begin
            case (tile_width)
                2'b00:  begin
                            mbl_x_next_r[6:3] <=       {3'b0,mbl_x_inc_r[3]};
                            pre_advance_tiles[1:0]  <= mbl_x_inc_r[5:4]; 
                        end
                2'b01:  begin
                            mbl_x_next_r[6:3] <=       {2'b0,mbl_x_inc_r[4:3]};
                            pre_advance_tiles[1:0]  <= mbl_x_inc_r[6:5]; 
                        end
                2'b10:  begin
                            mbl_x_next_r[6:3] <=       {1'b0,mbl_x_inc_r[5:3]};
                            pre_advance_tiles[1:0]  <= mbl_x_inc_r[7:6]; 
                        end
                2'b11:  begin
                            mbl_x_next_r[6:3] <=       {     mbl_x_inc_r[6:3]};
                            pre_advance_tiles[1:0]  <= {1'b0, mbl_x_inc_r[7]}; 
                        end
            endcase
            used_pages <= needed_page - next_invalid +1;
        end
        if  (mb_pre_end[2]) begin // TODO: apply after delay, regardless last or not
            if (mb_last_in_row) add_invalid <= used_pages[1:0];
            else                add_invalid <= pre_advance_tiles;
        end
        // pages already processed by compressor - they can be reused for reading new tiles
        if      (reset_page_rd) next_invalid <= 0;
        else if (mb_pre_end[3]) next_invalid <= next_invalid + {1'b0, add_invalid}; // TODO: Send next_page after delay
        
         
        // calculate before starting each macroblock (will wait if buffer is not ready) (TODO: align mb_pre_start[0] to mb_pre_end[2] - same)
        //mb_pre_start_w
        if      (mb_pre_start_w)                  mb_pre_start <= 1;
        else if (!mb_pre_start[3] || buf_ready_w) mb_pre_start <= mb_pre_start << 1;
         
        if (mb_pre_start[0]) mbl_x_r[6:3] <=      mb_first_in_row? {2'b0,left_marg[4:3]} : mbl_x_next_r[6:3];
        if (mb_pre_start[1]) mbl_x_last_r[7:3] <= {1'b0,mbl_x_r[6:3]} + {2'b0,mb_w_m1[5:3]};
        if (mb_pre_start[2]) begin
            case (tile_width)
                2'b00: needed_page[2:0] <=  next_invalid[2:0]+{1'b0, mbl_x_last_r[5:4]}; 
                2'b01: needed_page[2:0] <=  next_invalid[2:0]+{1'b0, mbl_x_last_r[6:5]}; 
                2'b10: needed_page[2:0] <=  next_invalid[2:0]+{1'b0, mbl_x_last_r[7:6]}; 
                2'b11: needed_page[2:0] <=  next_invalid[2:0]+{2'b0, mbl_x_last_r[7]}; 
            endcase
        end
         //need_pages_m1[1:0] <= ;
        
        
/*
        if (mb_pre_end_w) mb_pre_end <= 1;
        else              mb_pre_end <= mb_pre_end << 1;


    reg    [ 3:0] mb_pre_start;   // 1-hot macroblock pre start calcualtions - TODO: adjust width
    wire          buf_ready_w;    // External memory buffer has all the pages needed
    reg           mb_first_in_row;
    
    reg    [ 2:0] next_valid;     // number of next valid page (only 2 LSB are actual page number)
    reg    [ 2:0] next_invalid;   // oldest valid page
    reg    [ 2:0] needed_page;    // calculate at MB start 

    reg    [ 7:3] mbl_x_last_r;   // intermediate register for calculating needed_page

    reg    [ 5:0] mb_w_m1;        // macroblock width minus 1


    wire   [ 6:0] mbl_x;          // macroblock left pixel x relative to a tile (page) Maximal page - 128 bytes wide
    reg    [ 6:3] mbl_x_r;        // macroblock left pixel x relative to a tile (page) (3 low don't change)
    reg    [ 6:3] mbl_x_next_r;   // macroblock left pixel x relative to a tile (page), not valid for first column (3 low don't change)    


    reg    [ 1:0] add_invalid;    // advance next_invalid pointer by this value, send next_page pulses
    reg           we_invalid;     // advance next_invalid pointer, send next_page pulses
    reg    [ 4:3] mb_hper;        // macroblock horizontal period (8/16)
    reg    [ 4:0] mb_pre_end;     // 1-hot macroblock pre end calcualtions - TODO: adjust width

    wire   [ 6:0] mbl_x;          // macroblock left pixel x relative to a tile (page) Maximal page - 128 bytes wide
    reg    [ 6:3] mbl_x_r;        // macroblock left pixel x relative to a tile (page) (3 low don't change)
    reg    [ 6:3] mbl_x_next_r;   // macroblock left pixel x relative to a tile (page), not valid for first column (3 low don't change)    
    reg    [ 7:3] mbl_x_inc_r;    // intermediate register for calculatingm bl_x_next_r and add_invalid

    reg    [ 4:0] mb_hper;        // macroblock horizontal period (8/16)
    reg    [ 1:0] tile_width;     // memory tile width (can be 128 for monochrome JPEG)   Can be 32/64/128: 0 - 16, 1 - 32, 2 - 64, 3 - 128

    reg           mb_first_in_row;
    reg           mb_last_in_row;
    
    reg    [ 1:0] add_invalid;    // advance next_invalid pointer by this value, send next_page pulses
    reg           we_invalid;     // advance next_invalid pointer, send next_page pulses
*/        
        
    
    end     

    // synchronization between mclk and xclk clock domains
    // negedge mclk -> xclk (verify clock inversion is absorbed)
    pulse_cross_clock  reset_page_rd_i (.rst(rst), .src_clk(~mclk),.dst_clk(xclk), .in_pulse(xfer_reset_page_rd), .out_pulse(reset_page_rd),.busy());
    // mclk -> xclk
    pulse_cross_clock page_ready_i     (.rst(rst), .src_clk(mclk), .dst_clk(xclk), .in_pulse(page_ready_chn), .out_pulse(page_ready),.busy());
    // xclk -> mclk
//    pulse_cross_clock next_page_i  (.rst(rst), .src_clk(xclk), .dst_clk(mclk), .in_pulse(next_page), .out_pulse(next_page_chn),.busy(busy_next_page));

    dly_16 #(.WIDTH(1)) dly_16_i (.clk(xclk),.rst(rst),      .dly(CMPRS_MB_DLY), .din(pre_frame_start), .dout(frame_start));
    dly_16 #(.WIDTH(1)) dly_16_i (.clk(xclk),.rst(!frame_en),.dly(CMPRS_MB_DLY), .din(pre_en),          .dout(en));

    multipulse_cross_clock #(
        .WIDTH(3),
        .EXTRA_DLY(0)
    ) multipulse_cross_clock_i (
        .rst        (rst), // input
        .src_clk    (xclk), // input
        .dst_clk    (mclk), // input
        .num_pulses ({1'b0,add_invalid}), // input[0:0] 
        .we         (we_invalid), // input
        .out_pulse  (next_page_chn), // output
        .busy       () // output
    );

endmodule

