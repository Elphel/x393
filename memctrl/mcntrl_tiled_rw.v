/*******************************************************************************
 * Module: mcntrl_tiled_rw
 * Date:2015-02-03  
 * Author: andrey     
 * Description:  Organize paged R/W from DDR3 memory in tiled order
 * with window support
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * mcntrl_tiled_rw.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  mcntrl_tiled_rw.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  mcntrl_tiled_rw#(
   parameter ADDRESS_NUMBER=                   15,
    parameter COLADDR_NUMBER=                   10,
    parameter FRAME_WIDTH_BITS=                 13,    // Maximal frame width - 8-word (16 bytes) bursts 
    parameter FRAME_HEIGHT_BITS=                16,    // Maximal frame height 
    parameter MAX_TILE_WIDTH=                   6,     // number of bits to specify maximal tile (width-1) (6 -> 64)
    parameter MAX_TILE_HEIGHT=                  6,     // number of bits to specify maximal tile (height-1) (6 -> 64)
    parameter MCNTRL_TILED_ADDR=            'h120,
    parameter MCNTRL_TILED_MASK=            'h3f0, // both channels 0 and 1
    parameter MCNTRL_TILED_MODE=            'h0,   // set mode register: {extra_pages[1:0],write_mode,enable,!reset}
    parameter MCNTRL_TILED_STATUS_CNTRL=    'h1,   // control status reporting
    parameter MCNTRL_TILED_STARTADDR=       'h2,   // 22-bit frame start address (3 CA LSBs==0. BA==0)
    parameter MCNTRL_TILED_FRAME_FULL_WIDTH='h3,   // Padded line length (8-row increment), in 8-bursts (16 bytes)
    parameter MCNTRL_TILED_WINDOW_WH=       'h4,   // low word - 13-bit window width (0->'h4000), high word - 16-bit frame height (0->'h10000)
    parameter MCNTRL_TILED_WINDOW_X0Y0=     'h5,   // low word - 13-bit window left, high word - 16-bit window top
    parameter MCNTRL_TILED_WINDOW_STARTXY=  'h6,   // low word - 13-bit start X (relative to window), high word - 16-bit start y
                                                      // Start XY can be used when read command to start from the middle
                                                      // TODO: Add number of blocks to R/W? (blocks can be different) - total length?
                                                      // Read back current address (for debugging)?
    parameter MCNTRL_TILED_TILE_WH=         'h7,   // low word - 6-bit tile width in 8-bursts, high - tile height (0 - > 64)
    parameter MCNTRL_TILED_STATUS_REG_ADDR= 'h5,
    parameter MCNTRL_TILED_PENDING_CNTR_BITS=2,    // Number of bits to count pending trasfers, currently 2 is enough, but may increase
                                                   // if memory controller will allow programming several sequences in advance to
                                                   // spread long-programming (tiled) over fast-programming (linear) requests.
                                                   // But that should not be too big to maintain 2-level priorities
    parameter MCNTRL_TILED_FRAME_PAGE_RESET =1'b0, // reset internal page number to zero at the frame start (false - only when hard/soft reset)                                                     
    parameter MCNTRL_TILED_WRITE_MODE =      1'b0  // module is configured to write tiles to external memory (false - read tiles)                                                     
)(
    input                          rst,
    input                          mclk,
// programming interface
    input                    [7:0] cmd_ad,      // byte-serial command address/data (up to 6 bytes: AL-AH-D0-D1-D2-D3 
    input                          cmd_stb,     // strobe (with first byte) for the command a/d
    
    output                   [7:0] status_ad,     // byte-wide address/data
    output                         status_rq,     // request to send downstream (last byte with rq==0)
    input                          status_start,   // acknowledge of address (first byte) from downsteram   

    input                          frame_start,   // resets page, x,y, and initiates transfer requests (in write mode will wait for next_page)
    input                          next_page,     // page was read/written from/to 4*1kB on-chip buffer
//    output                         page_ready,    // == xfer_done, connect externally | Single-cycle pulse indicating that a page was read/written from/to DDR3 memory
    output                         frame_done,    // single-cycle pulse when the full frame (window) was transferred to/from DDR3 memory
// optional I/O for channel synchronization
    output [FRAME_HEIGHT_BITS-1:0] line_unfinished, // number of the current (ufinished ) line, REALATIVE TO FRAME, NOT WINDOW?. 
    input                          suspend,       // suspend transfers (from external line number comparator)
    output                         xfer_want,     // "want" data transfer
    output                         xfer_need,     // "need" - really need a transfer (only 1 page/ room for 1 page left in a buffer), want should still be set.
    input                          xfer_grant,    // sequencer programming access granted, deassert wait/need 
    output                         xfer_start,    // initiate a transfer (next cycle after xfer_grant), following signals (up to xfer_partial) are valid
    output                   [2:0] xfer_bank,     // start bank address
    output    [ADDRESS_NUMBER-1:0] xfer_row,      // memory row
    output    [COLADDR_NUMBER-4:0] xfer_col,      // start memory column in 8-bursts
    output    [FRAME_WIDTH_BITS:0] rowcol_inc,    // increment row+col (after bank) for the new scan line in 8-bursts (externally pad with 0)
    output    [MAX_TILE_WIDTH-1:0] num_rows_m1,   // number of rows to read minus 1
    output  [MAX_TILE_HEIGHT-1:0] num_cols_m1,   // number of 16-pixel columns to read (rows first, then columns) - 1
    output                         keep_open,     // (programmable bit)keep banks open (for <=8 banks only
    output                         xfer_partial,  // partial tile (first of 2) , sequencer will not generate page_next at the end of block   
    input                          xfer_page_done,     // transfer to/from the buffer finished (partial transfers should not generate), use rpage_nxt_chn@mclk
    output                         xfer_page_rst // reset buffer internal page - at each frame start or when specifically reset
);
//MAX_TILE_WIDTH
    localparam NUM_RC_BURST_BITS=ADDRESS_NUMBER+COLADDR_NUMBER-3;  //to spcify row and col8 == 22
    localparam MPY_WIDTH=        NUM_RC_BURST_BITS; // 22
    localparam PAR_MOD_LATENCY=  7; // TODO: Find actual worst-case latency for:
    reg    [FRAME_WIDTH_BITS-1:0] curr_x;         // (calculated) start of transfer x (relative to window left)
    reg   [FRAME_HEIGHT_BITS-1:0] curr_y;         // (calculated) start of transfer y (relative to window top)
    reg     [FRAME_HEIGHT_BITS:0] next_y;         // (calculated) next row number
    reg   [NUM_RC_BURST_BITS-1:0] line_start_addr;// (calculated) Line start (in {row,col8} in burst8
    reg      [COLADDR_NUMBER-4:0] line_start_page_left; // number of 8-burst left in the memory page from the start of the frame line
 // calculating full width from the frame width
    reg   [FRAME_HEIGHT_BITS-1:0] frame_y;     // current line number referenced to the frame top
    reg    [FRAME_WIDTH_BITS-1:0] frame_x;     // current column number referenced to the frame left
    reg   [FRAME_HEIGHT_BITS-4:0] frame_y8_r;  // (13 bits) current row with bank removed, latency2 (to be absorbed when inferred DSP multipler)
    reg      [FRAME_WIDTH_BITS:0] frame_full_width_r;  // (14 bit) register to be absorbed by MPY
    reg           [MPY_WIDTH-1:0] mul_rslt;
    reg   [NUM_RC_BURST_BITS-1:0] start_addr_r;   // 22 bit - to be absorbed by DSP
    reg                     [2:0] bank_reg [2:0];
    wire [FRAME_WIDTH_BITS+FRAME_HEIGHT_BITS-3:0] mul_rslt_w;
 //   wire                    [2:0] cur_bank;
    reg      [FRAME_WIDTH_BITS:0] row_left;   // number of 8-bursts left in the current row
    reg                           last_in_row;
    reg      [COLADDR_NUMBER-3:0] mem_page_left; // number of 8-bursts left in the pointed memory page
    reg        [MAX_TILE_WIDTH:0] lim_by_tile_width;     // number of bursts left limited by the longest transfer (currently 64)
    wire     [COLADDR_NUMBER-3:0] remainder_tile_width;  // number of bursts postponed to the next partial tile (because of the page crossing) MSB-sign
    reg                           continued_tile;        // this is a continued tile (caused by page crossing) - only once
    reg      [MAX_TILE_WIDTH-1:0] leftover_cols;         // valid with continued_tile, number of columns left
    wire                          pgm_param_w;  // program one of the parameters, invalidate calculated results for PAR_MOD_LATENCY
    reg                     [2:0] xfer_start_r;
    reg     [PAR_MOD_LATENCY-1:0] par_mod_r; 
    reg     [PAR_MOD_LATENCY-1:0] recalc_r; // 1-hot CE for re-calculating registers
    wire                          calc_valid;   // calculated registers have valid values   
    wire                          chn_en;   // enable requests by channle (continue ones in progress)
    wire                          chn_rst; // resets command, including fifo;
    reg                           chn_rst_d; // delayed by 1 cycle do detect turning off
    reg                           xfer_page_rst_r=1;  
    reg                     [2:0] page_cntr; // to maintain requests - difference between client requests and generated requests
                                             // partial (truncated by memory page) generated requests should not count 
    
    wire                          cmd_wrmem= MCNTRL_TILED_WRITE_MODE; // 0: read from memory, 1:write to memory (change to parameter?)
    wire                    [1:0] cmd_extra_pages; // external module needs more than 1 page
    reg                           busy_r;
    reg                           want_r;
    reg                           need_r;
    reg                           frame_done_r;
    wire                          last_in_row_w;
    wire                          last_row_w;
    reg                           last_block;
    reg [MCNTRL_TILED_PENDING_CNTR_BITS-1:0] pending_xfers; // number of requested,. but not finished block transfers   (to genearate frame done)   
    reg   [NUM_RC_BURST_BITS-1:0] row_col_r;
    reg   [FRAME_HEIGHT_BITS-1:0] line_unfinished_r [1:0];
    wire                          pre_want;
    wire                    [1:0] status_data;
    wire                    [3:0] cmd_a; 
    wire                   [31:0] cmd_data; 
    wire                          cmd_we;
    
    wire                          set_mode_w;
    wire                          set_status_w;
    wire                          set_start_addr_w;
    wire                          set_frame_width_w;
    wire                          set_window_wh_w;
    wire                          set_window_x0y0_w;
    wire                          set_window_start_w;
    wire                          set_tile_wh_w;
    wire                          lsw13_zero=!(|cmd_data[FRAME_WIDTH_BITS-1:0]); // LSW 13 (FRAME_WIDTH_BITS) low bits are all 0 - set carry bit  
//    wire                          msw13_zero=!(|cmd_data[FRAME_WIDTH_BITS+15:16]); // MSW 13 (FRAME_WIDTH_BITS) low bits are all 0 - set carry bit
    wire                          msw_zero=  !(|cmd_data[31:16]); // MSW all bits are 0 - set carry bit
    wire                          tile_width_zero= !(|cmd_data[MAX_TILE_WIDTH-1:0]);  
    wire                          tile_height_zero=!(|cmd_data[MAX_TILE_HEIGHT+15:16]);  
    
//    reg                     [5:0] mode_reg;//mode register: {write_mode,keep_open,extra_pages[1:0],enable,!reset}
    reg                     [4:0] mode_reg;//mode register: {keep_open,extra_pages[1:0],enable,!reset}
    reg   [NUM_RC_BURST_BITS-1:0] start_addr;     // (programmed) Frame start (in {row,col8} in burst8, bank ==0
    reg        [MAX_TILE_WIDTH:0] tile_cols; // full number of columns in a tile
    reg       [MAX_TILE_HEIGHT:0] tile_rows; // full number of rows in a tile

    reg        [MAX_TILE_WIDTH:0] num_cols_r; // full number of columns to transfer (not minus 1)
    wire       [MAX_TILE_WIDTH:0] num_cols_m1_w; // full number of columns to transfer minus 1 with extra bit
    wire      [MAX_TILE_HEIGHT:0] num_rows_m1_w; // full number of columns to transfer minus 1 with extra bit
    reg      [FRAME_WIDTH_BITS:0] frame_full_width;     // (programmed) increment combined row/col when moving to the next line
                                                  // frame_width rounded up to max transfer (half page) if frame_width> max transfer/2,
                                                  // otherwise (smaller widths) round up to the nearest power of 2
    reg      [FRAME_WIDTH_BITS:0] window_width;   // (programmed) 0- max
    reg     [FRAME_HEIGHT_BITS:0] window_height;  // (programmed) 0- max
    reg    [FRAME_WIDTH_BITS-1:0] window_x0;      // (programmed) window left
    reg   [FRAME_HEIGHT_BITS-1:0] window_y0;      // (programmed) window top
    reg    [FRAME_WIDTH_BITS-1:0] start_x;        // (programmed) normally 0, copied to curr_x on frame_start  
    reg   [FRAME_HEIGHT_BITS-1:0] start_y;        // (programmed) normally 0, copied to curr_y on frame_start 
    
    
    assign set_mode_w =         cmd_we && (cmd_a== MCNTRL_TILED_MODE);
    assign set_status_w =       cmd_we && (cmd_a== MCNTRL_TILED_STATUS_CNTRL);
    assign set_start_addr_w =   cmd_we && (cmd_a== MCNTRL_TILED_STARTADDR);
    assign set_frame_width_w =  cmd_we && (cmd_a== MCNTRL_TILED_FRAME_FULL_WIDTH);
    assign set_window_wh_w =    cmd_we && (cmd_a== MCNTRL_TILED_WINDOW_WH);
    assign set_window_x0y0_w =  cmd_we && (cmd_a== MCNTRL_TILED_WINDOW_X0Y0);
    assign set_window_start_w = cmd_we && (cmd_a== MCNTRL_TILED_WINDOW_STARTXY);
    assign set_tile_wh_w =      cmd_we && (cmd_a== MCNTRL_TILED_TILE_WH);
    //
    // Set parameter registers
    always @(posedge rst or posedge mclk) begin
        if      (rst)                mode_reg <= 0;
        else if (set_mode_w)         mode_reg <= cmd_data[4:0]; // [5:0];
        
        if      (rst)                start_addr <= 0;
        else if (set_start_addr_w)   start_addr <= cmd_data[NUM_RC_BURST_BITS-1:0];

        if      (rst)               frame_full_width <=  0;
        else if (set_frame_width_w) frame_full_width <= {lsw13_zero,cmd_data[FRAME_WIDTH_BITS-1:0]};
        
        if (rst) begin
               window_width <= 0; 
               window_height <=  0;
        end else if (set_window_wh_w)  begin
               window_width <= {lsw13_zero,cmd_data[FRAME_WIDTH_BITS-1:0]};
               window_height  <= {msw_zero,cmd_data[FRAME_HEIGHT_BITS+15:16]};
        end

        if (rst) begin
               tile_cols <= 0; 
               tile_rows <=  0;
        end else if (set_tile_wh_w)  begin
               tile_cols <= {tile_width_zero,  cmd_data[MAX_TILE_WIDTH-1:0]};
               tile_rows <= {tile_height_zero, cmd_data[MAX_TILE_HEIGHT+15:16]};
        end

        if (rst) begin
               window_x0 <= 0; 
               window_y0 <=  0;
        end else if (set_window_x0y0_w)  begin
               window_x0 <= cmd_data[FRAME_WIDTH_BITS-1:0];
               window_y0  <=cmd_data[FRAME_HEIGHT_BITS+15:16];
        end

        if (rst) begin
               start_x <= 0; 
               start_y <=  0;
        end else if (set_window_start_w)  begin
               start_x <= cmd_data[FRAME_WIDTH_BITS-1:0];
               start_y  <=cmd_data[FRAME_HEIGHT_BITS+15:16];
        end
        
    end
    assign mul_rslt_w=  frame_y8_r * frame_full_width_r; // 5 MSBs will be discarded
    assign xfer_start=  xfer_start_r[0];
    assign calc_valid=  par_mod_r[PAR_MOD_LATENCY-1]; // MSB, longest 0
    assign frame_done=  frame_done_r;
    assign pre_want=    chn_en && busy_r && !want_r && !xfer_start_r[0] && calc_valid && !last_block && !suspend;
    assign last_in_row_w=(row_left=={{(FRAME_WIDTH_BITS-MAX_TILE_WIDTH){1'b0}},num_cols_r}); // what if it crosses page? OK, num_cols_r & row_left know that
    assign last_row_w=  next_y>=window_height; // (next_y==window_height) is faster, but will not forgive software errors
    assign xfer_want=   want_r;
    assign xfer_need=   need_r;
    assign xfer_bank=   bank_reg[2]; // TODO: just a single reg layer
    assign xfer_row= row_col_r[NUM_RC_BURST_BITS-1:COLADDR_NUMBER-3] ;      // memory row
    assign xfer_col= row_col_r[COLADDR_NUMBER-4:0];    // start memory column in 8-bursts
    assign line_unfinished=line_unfinished_r[1];
    assign chn_en =         &mode_reg[1:0];   // enable requests by channle (continue ones in progress)
    assign chn_rst =        ~mode_reg[0]; // resets command, including fifo;
    assign cmd_extra_pages = mode_reg[3:2]; // external module needs more than 1 page
    assign keep_open=        mode_reg[4]; // keep banks open (will be used only if number of rows <= 8 
//    assign cmd_wrmem =       mode_reg[5];// 0: read from memory, 1:write to memory
    assign status_data=      {frame_done, busy_r}; 
    assign pgm_param_w=      cmd_we;
    assign rowcol_inc=       frame_full_width;
    assign num_cols_m1_w=    num_cols_r-1;
    assign num_rows_m1_w=    tile_rows-1; // now number of rows == tile height
    assign num_cols_m1=      num_cols_m1_w[MAX_TILE_WIDTH-1:0];  // remove MSB
    assign num_rows_m1=      num_rows_m1_w[MAX_TILE_HEIGHT-1:0]; // remove MSB
    assign remainder_tile_width = {EXTRA_BITS,lim_by_tile_width}-mem_page_left;
    
//    assign buf_skip_reset=   continued_tile; // buf_skip_reset_r;
    assign xfer_page_rst=   xfer_page_rst_r;
    assign xfer_partial=      xfer_limited_by_mem_page_r;
    
    integer i;
//    localparam EXTRA_BITS={COLADDR_NUMBER-3-NUM_XFER_BITS{1'b0}};
    localparam [COLADDR_NUMBER-3-MAX_TILE_WIDTH-1:0] EXTRA_BITS=0;
    wire xfer_limited_by_mem_page;
    reg  xfer_limited_by_mem_page_r;
    assign xfer_limited_by_mem_page= mem_page_left < {EXTRA_BITS,lim_by_tile_width};
    always @(posedge mclk) begin // TODO: Match latencies (is it needed?) Reduce consumption by CE?
    // cycle 1
        if (recalc_r[0]) begin
            frame_x <= curr_x + window_x0;
            frame_y <= curr_y + window_y0;
            next_y <= curr_y + tile_rows;
            row_left <= window_width - curr_x; // 14 bits - 13 bits
        end    
   // cycle 2     
        if (recalc_r[1]) begin
//            mem_page_left <= (1 << (COLADDR_NUMBER-3)) - frame_x[COLADDR_NUMBER-4:0];
            mem_page_left <= {1'b1,line_start_page_left} - frame_x[COLADDR_NUMBER-4:0];
            
//            lim_by_tile_width <= (|row_left[FRAME_WIDTH_BITS:MAX_TILE_WIDTH])?(1<<MAX_TILE_WIDTH):row_left[MAX_TILE_WIDTH:0]; // 7 bits, max 'h40
            lim_by_tile_width <= (|row_left[FRAME_WIDTH_BITS:MAX_TILE_WIDTH] || (row_left[MAX_TILE_WIDTH:0]>= tile_cols))?
                                    tile_cols:
                                    row_left[MAX_TILE_WIDTH:0]; // 7 bits, max 'h40
        end
   // cycle 3
        if (recalc_r[2]) begin
            xfer_limited_by_mem_page_r <= xfer_limited_by_mem_page && !continued_tile;     
            num_cols_r<= continued_tile?
                {EXTRA_BITS,leftover_cols}:
                (xfer_limited_by_mem_page? mem_page_left[MAX_TILE_WIDTH:0]:lim_by_tile_width[MAX_TILE_WIDTH:0]);
                leftover_cols <= remainder_tile_width[MAX_TILE_WIDTH-1:0];
//            remainder_tile_width <= {EXTRA_BITS,lim_by_tile_width}-mem_page_left;
        end
// VDT bug? next line gives a warning        
//        xfer_num128_r<= (mem_page_left> {{COLADDR_NUMBER-3-COLADDR_NUMBER-3{1'b0}},lim_by_xfer})?mem_page_left[NUM_XFER_BITS-1:0]:lim_by_xfer[NUM_XFER_BITS-1:0];
   // cycle 4
        if (recalc_r[3]) begin
            last_in_row <= last_in_row_w;
        end
// registers to be absorbed in DSP block        
        frame_y8_r <= frame_y[FRAME_HEIGHT_BITS-1:3]; // lat=2 // if (recalc_r[2]) begin
        frame_full_width_r <= frame_full_width; //(cycle 2) // if (recalc_r[2]) begin
        start_addr_r <= start_addr; // // if (recalc_r[2]) begin
        mul_rslt <= mul_rslt_w[MPY_WIDTH-1:0]; // frame_y8_r * frame_width_r; // 7 bits will be discarded lat=3; if (recalc_r[3]) begin
        line_start_addr <= start_addr_r+mul_rslt; // lat=4 if (recalc_r[4]) begin
// TODO: Verify MPY/register timing above        
        if (recalc_r[5]) begin
            row_col_r <= line_start_addr+frame_x;
//            line_start_page_left <= {COLADDR_NUMBER-3{1'b0}} - line_start_addr[COLADDR_NUMBER-4:0]; // 7 bits
            line_start_page_left <=  - line_start_addr[COLADDR_NUMBER-4:0]; // 7 bits
        end
        bank_reg[0]   <= frame_y[2:0]; //TODO: is it needed - a pipeline for the bank? - remove! 
        for (i=0;i<2; i = i+1)
            bank_reg[i+1] <= bank_reg[i];
            
    end
    
// now have row start address, bank and row_left ;
// calculate number to read (min of row_left, maximal xfer and what is left in the DDR3 page
wire    start_not_partial= xfer_start_r[0] && !xfer_limited_by_mem_page_r;    
    always @(posedge rst or posedge mclk) begin
        if      (rst)                                       par_mod_r<=0;
        else if (pgm_param_w || xfer_start_r[0] || chn_rst) par_mod_r<=0;
        else                                                par_mod_r <= {par_mod_r[PAR_MOD_LATENCY-2:0], 1'b1};

        if      (rst)          chn_rst_d <= 0;
        else                   chn_rst_d <= chn_rst;

        if      (rst)          recalc_r<=0;
        else if (chn_rst)      recalc_r<=0;
        else                   recalc_r <= {recalc_r[PAR_MOD_LATENCY-2:0], (xfer_grant & ~chn_rst) | pgm_param_w | (chn_rst_d & ~chn_rst)};
        
        if      (rst)          busy_r <= 0;
        else if (chn_rst)      busy_r <= 0;
        else if (frame_start)  busy_r <= 1;
        else if (frame_done_r) busy_r <= 0;
        
        if (rst) xfer_start_r <= 0;
        else     xfer_start_r <= {xfer_start_r[1:0],xfer_grant && !chn_rst};
        
        if (rst)                   continued_tile <= 1'b0;
        else if (chn_rst)          continued_tile <= 1'b0;
        else if (frame_start)      continued_tile <= 1'b0;
        else if (xfer_start_r[0])  continued_tile <= xfer_limited_by_mem_page_r; // only set after actual start if it was partial, not after parameter change
        
        if (rst)                             need_r <= 0;
        else if (chn_rst || xfer_grant)      need_r <= 0;
        else if (pre_want && (page_cntr>=3)) need_r <= 1;

        if (rst)                                                 want_r <= 0;
        else if (chn_rst || xfer_grant)                          want_r <= 0;
        else if (pre_want && (page_cntr>{1'b0,cmd_extra_pages})) want_r <= 1;
        
        if (rst)                                   page_cntr <= 0;
        else if (frame_start)                      page_cntr <= cmd_wrmem?0:4;
//        else if ( xfer_start_r[0] && !next_page) page_cntr <= page_cntr + 1;     
//        else if (!xfer_start_r[0] &&  next_page) page_cntr <= page_cntr - 1;
        else if ( start_not_partial && !next_page) page_cntr <= page_cntr + 1;     
        else if (!start_not_partial &&  next_page) page_cntr <= page_cntr - 1;
        
        if (rst) xfer_page_rst_r <= 1;
        else     xfer_page_rst_r <= chn_rst || (MCNTRL_TILED_FRAME_PAGE_RESET ? frame_start:1'b0);
        
// increment x,y (two cycles)
        if (rst)                                  curr_x <= 0;
        else if (chn_rst || frame_start)          curr_x <= start_x;
        else if (xfer_start_r[0])                 curr_x <= last_in_row?0: curr_x + num_cols_r;
        
        if (rst)                                  curr_y <= 0;
        else if (chn_rst || frame_start)          curr_y <= start_y;
        else if (xfer_start_r[0] && last_in_row)  curr_y <= next_y[FRAME_HEIGHT_BITS-1:0];
               
        if      (rst)                         last_block <= 0;
        else if (chn_rst || !busy_r)          last_block <= 0;
        else if (last_row_w && last_in_row_w) last_block <= 1;
 
 // start_not_partial is not generated when partial (first of 2, caused by a tile crossing memory page) transfer is requested       
 // here we need to cout all requests - partial or not
        if      (rst)                                   pending_xfers <= 0;
        else if (chn_rst || !busy_r)                    pending_xfers <= 0;
        else if ( xfer_start_r[0] && !xfer_page_done) pending_xfers <= pending_xfers + 1;     
        else if (!xfer_start_r[0] &&  xfer_page_done) pending_xfers <= pending_xfers - 1; // page done is not generated on partial (first) pages
//        else if ( start_not_partial && !xfer_page_done) pending_xfers <= pending_xfers + 1;     
//        else if (!start_not_partial &&  xfer_page_done) pending_xfers <= pending_xfers - 1; // page done is not generated on partial (first) pages
        
        if (rst)          frame_done_r <= 0;
        else              frame_done_r <= busy_r && last_block && xfer_page_done && (pending_xfers==0);
        
        //line_unfinished_r cmd_wrmem
        if (rst)                         line_unfinished_r[0] <= 0; //{FRAME_HEIGHT_BITS{1'b0}};
        else if (chn_rst || frame_start) line_unfinished_r[0] <= window_y0+start_y;
        else if (xfer_start_r[2])        line_unfinished_r[0] <= window_y0+next_y[FRAME_HEIGHT_BITS-1:0]; // latency 2 from xfer_start

        if (rst)                                line_unfinished_r[1] <= 0; //{FRAME_HEIGHT_BITS{1'b0}};
        else if (chn_rst || frame_start)        line_unfinished_r[1] <= window_y0+start_y;
        // in read mode advance line number ASAP
        else if (xfer_start_r[2] && !cmd_wrmem) line_unfinished_r[1] <= window_y0+next_y[FRAME_HEIGHT_BITS-1:0]; // latency 2 from xfer_start
        // in write mode advance line number only when it is guaranteed it will be the first to actually access memory
        else if (xfer_grant      && cmd_wrmem)  line_unfinished_r[1] <=  line_unfinished_r[0];
        
    end
 
    cmd_deser #(
        .ADDR       (MCNTRL_TILED_ADDR),
        .ADDR_MASK  (MCNTRL_TILED_MASK),
        .NUM_CYCLES (6),
        .ADDR_WIDTH (4),
        .DATA_WIDTH (32)
    ) cmd_deser_32bit_i (
        .rst        (rst), // input
        .clk        (mclk), // input
        .ad         (cmd_ad), // input[7:0] 
        .stb        (cmd_stb), // input
        .addr       (cmd_a), // output[15:0] 
        .data       (cmd_data), // output[31:0] 
        .we         (cmd_we) // output
    );

    status_generate #(
        .STATUS_REG_ADDR  (MCNTRL_TILED_STATUS_REG_ADDR),
        .PAYLOAD_BITS     (2)
    ) status_generate_i (
        .rst              (rst), // input
        .clk              (mclk), // input
        .we               (set_status_w), // input
        .wd               (cmd_data[7:0]), // input[7:0] 
        .status           (status_data), // input[25:0] 
        .ad               (status_ad), // output[7:0] 
        .rq               (status_rq), // output
        .start            (status_start) // input
    );
endmodule

