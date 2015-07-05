/*******************************************************************************
 * Module: mcntrl_linear_rw
 * Date:2015-01-29  
 * Author: andrey     
 * Description: Organize paged R/W from DDR3 memory in scan-line order
 * with window support
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * mcntrl_linear_rw.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  mcntrl_linear_rw.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps
// TODO: ADD MCNTRL_SCANLINE_FRAME_PAGE_RESET to caller
module  mcntrl_linear_rw #(
    parameter ADDRESS_NUMBER=                   15,
    parameter COLADDR_NUMBER=                   10,
    parameter NUM_XFER_BITS=                     6,    // number of bits to specify transfer length
    parameter FRAME_WIDTH_BITS=                 13,    // Maximal frame width - 8-word (16 bytes) bursts 
    parameter FRAME_HEIGHT_BITS=                16,    // Maximal frame height
    parameter LAST_FRAME_BITS=                  16,     // number of bits in frame counter (before rolls over)
    parameter MCNTRL_SCANLINE_ADDR=            'h120,
    parameter MCNTRL_SCANLINE_MASK=            'h3f0, // both channels 0 and 1
    parameter MCNTRL_SCANLINE_MODE=            'h0,   // set mode register: {repet,single,rst_frame,na[2:0],extra_pages[1:0],write_mode,enable,!reset}
    parameter MCNTRL_SCANLINE_STATUS_CNTRL=    'h1,   // control status reporting
    parameter MCNTRL_SCANLINE_STARTADDR=       'h2,   // 22-bit frame start address (3 CA LSBs==0. BA==0)
    parameter MCNTRL_SCANLINE_FRAME_SIZE=      'h3,   // 22-bit frame start address increment (3 CA LSBs==0. BA==0)
    parameter MCNTRL_SCANLINE_FRAME_LAST=      'h4,   // 16-bit last frame number in the buffer
    parameter MCNTRL_SCANLINE_FRAME_FULL_WIDTH='h5,   // Padded line length (8-row increment), in 8-bursts (16 bytes)
    parameter MCNTRL_SCANLINE_WINDOW_WH=       'h6,   // low word - 13-bit window width (0->'h4000), high word - 16-bit frame height (0->'h10000)
    parameter MCNTRL_SCANLINE_WINDOW_X0Y0=     'h7,   // low word - 13-bit window left, high word - 16-bit window top
    parameter MCNTRL_SCANLINE_WINDOW_STARTXY=  'h8,   // low word - 13-bit start X (relative to window), high word - 16-bit start y
                                                      // Start XY can be used when read command to start from the middle
                                                      // TODO: Add number of blocks to R/W? (blocks can be different) - total length?
                                                      // Read back current address (for debugging)?
    parameter MCNTRL_SCANLINE_STATUS_REG_ADDR= 'h4,
    parameter MCNTRL_SCANLINE_PENDING_CNTR_BITS=2,     // Number of bits to count pending trasfers, currently 2 is enough, but may increase
                                                      // if memory controller will allow programming several sequences in advance to
                                                      // spread long-programming (tiled) over fast-programming (linear) requests.
                                                      // But that should not be too big to maintain 2-level priorities
    parameter MCNTRL_SCANLINE_FRAME_PAGE_RESET =1'b0 // reset internal page number to zero at the frame start (false - only when hard/soft reset)                                                     
//    parameter MCNTRL_SCANLINE_WRITE_MODE =    1'b0    // module is configured to write tiles to external memory (false - read tiles)                                                                                                           
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
    output                         frame_finished,// turns on and stays on after frame_done
// optional I/O for channel synchronization
// after the last tile in a frame, before starting a new frame line_unfinished will point to non-existent (too high) line in the same frame
    output [FRAME_HEIGHT_BITS-1:0] line_unfinished, // number of the current (unfinished ) line, RELATIVE TO FRAME, NOT WINDOW?. 
    input                          suspend,       // suspend transfers (from external line number comparator)
    output   [LAST_FRAME_BITS-1:0] frame_number,  // current frame number (for multi-frame ranges)
    output                         xfer_want,     // "want" data transfer
    output                         xfer_need,     // "need" - really need a transfer (only 1 page/ room for 1 page left in a buffer), want should still be set.
    input                          xfer_grant,    // sequencer programming access granted, deassert wait/need 
    output                         xfer_start_rd, // initiate a transfer (next cycle after xfer_grant)
    output                         xfer_start_wr, // initiate a transfer (next cycle after xfer_grant)
    output                   [2:0] xfer_bank,     // bank address
    output    [ADDRESS_NUMBER-1:0] xfer_row,      // memory row
    output    [COLADDR_NUMBER-4:0] xfer_col,      // start memory column in 8-bursts
    output     [NUM_XFER_BITS-1:0] xfer_num128,   // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    output                         xfer_partial,  // partial tile (first of 2) , sequencer will not generate page_next at the end of block   
    input                          xfer_done,     // transfer to/from the buffer finished
    output                         xfer_page_rst_wr, // reset buffer internal page - at each frame start or when specifically reset (write to memory channel), @posedge
    output                         xfer_page_rst_rd, // reset buffer internal page - at each frame start or when specifically reset (read memory channel), @negedge
    output                         cmd_wrmem
);
    localparam NUM_RC_BURST_BITS=ADDRESS_NUMBER+COLADDR_NUMBER-3;  //to spcify row and col8 == 22
    localparam MPY_WIDTH=        NUM_RC_BURST_BITS; // 22
    localparam PAR_MOD_LATENCY=  9; // TODO: Find actual worst-case latency for:
    reg    [FRAME_WIDTH_BITS-1:0] curr_x;         // (calculated) start of transfer x (relative to window left)
    reg   [FRAME_HEIGHT_BITS-1:0] curr_y;         // (calculated) start of transfer y (relative to window top)
    reg     [FRAME_HEIGHT_BITS:0] next_y;         // (calculated) next row number
    reg   [NUM_RC_BURST_BITS-1:0] line_start_addr;// (calculated) Line start (in {row,col8} in burst8
 // calculating full width from the frame width
// WARNING: [Synth 8-3936] Found unconnected internal register 'frame_y_reg' and it is trimmed from '16' to '3' bits. [memctrl/mcntrl_linear_rw.v:268]
// Throblem seems to be that frame_y8_r_reg (load of trimmed bits of the frame_y_reg) is (as intended) absorbed into DSP48. The lower 3 bits are used
// outside of the DSP 48.  "dont_touch" seems to work here
 (* keep = "true" *) reg   [FRAME_HEIGHT_BITS-1:0] frame_y;     // current line number referenced to the frame top
    reg    [FRAME_WIDTH_BITS-1:0] frame_x;     // current column number referenced to the frame left
    reg   [FRAME_HEIGHT_BITS-4:0] frame_y8_r;  // (13 bits) current row with bank removed, latency2 (to be absorbed when inferred DSP multipler)
    reg      [FRAME_WIDTH_BITS:0] frame_full_width_r;  // (14 bit) register to be absorbed by MPY
    reg           [MPY_WIDTH-1:0] mul_rslt;
    reg   [NUM_RC_BURST_BITS-1:0] start_addr_r;   // 22 bit - to be absorbed by DSP
    reg                     [2:0] bank_reg [2:0];
    wire [FRAME_WIDTH_BITS+FRAME_HEIGHT_BITS-3:0] mul_rslt_w;
    reg      [FRAME_WIDTH_BITS:0] row_left;   // number of 8-bursts left in the current row
    reg                           last_in_row;
    reg      [COLADDR_NUMBER-3:0] mem_page_left; // number of 8-bursts left in the pointed memory page
    reg      [COLADDR_NUMBER-4:0] line_start_page_left; // number of 8-burst left in the memory page from the start of the frame line
    reg         [NUM_XFER_BITS:0] lim_by_xfer;   // number of bursts left limited by the longest transfer (currently 64)
//    reg        [MAX_TILE_WIDTH:0] lim_by_tile_width;     // number of bursts left limited by the longest transfer (currently 64)
    wire     [COLADDR_NUMBER-3:0] remainder_in_xfer ;//remainder_tile_width;  // number of bursts postponed to the next partial tile (because of the page crossing) MSB-sign
    reg                           continued_xfer;   //continued_tile;        // this is a continued tile (caused by page crossing) - only once
    reg       [NUM_XFER_BITS-1:0] leftover; //[MAX_TILE_WIDTH-1:0] leftover_cols;         // valid with continued_tile, number of columns left
    
    
    
    reg         [NUM_XFER_BITS:0] xfer_num128_r;   // number of 128-bit words to transfer (8*16 bits) - full bursts of 8
//    reg       [NUM_XFER_BITS-1:0] xfer_num128_m1_r;   // number of 128-bit words to transfer minus 1 (8*16 bits) - full bursts of 8
    wire                          pgm_param_w;  // program one of the parameters, invalidate calculated results for PAR_MOD_LATENCY
    reg                     [2:0] xfer_start_r; // 1 hot started by xfer start only (not by parameter change)
    reg                           xfer_start_rd_r;
    reg                           xfer_start_wr_r;
    reg     [PAR_MOD_LATENCY-1:0] par_mod_r;
    reg     [PAR_MOD_LATENCY-1:0] recalc_r; // 1-hot CE for re-calculating registers
    wire                          calc_valid;   // calculated registers have valid values   
    wire                          chn_en;   // enable requests by channel (continue ones in progress), enable frame_start inputs
    wire                          chn_rst; // resets command, including fifo;
    reg                           chn_rst_d; // delayed by 1 cycle do detect turning off
//    reg                           xfer_reset_page_r;
    reg                           xfer_page_rst_r=1;
    reg                           xfer_page_rst_pos=1;  
    reg                           xfer_page_rst_neg=1;  
    
    reg                     [2:0] page_cntr;
    
//    wire                          cmd_wrmem; //=MCNTRL_SCANLINE_WRITE_MODE; // 0: read from memory, 1:write to memory
    wire                    [1:0] cmd_extra_pages; // external module needs more than 1 page
    
    wire                          repeat_frames; // mode bit
    wire                          single_frame_w; // pulse
    wire                          rst_frame_num_w;
    reg                           single_frame_r;  // pulse
    reg                     [1:0] rst_frame_num_r; // reset frame number/next start address
    reg                           frame_en;       // enable next frame
    
    reg                           busy_r;
    reg                           want_r;
    reg                           need_r;
    reg                           frame_done_r;
    reg                           frame_finished_r;    
    wire                          last_in_row_w;
    wire                          last_row_w;
    reg                           last_block;
    reg [MCNTRL_SCANLINE_PENDING_CNTR_BITS-1:0] pending_xfers; // number of requested,. but not finished block transfers      
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
    wire                          set_frame_size_w;
    wire                          set_last_frame_w;
    wire                          set_frame_width_w;
    wire                          set_window_wh_w;
    wire                          set_window_x0y0_w;
    wire                          set_window_start_w;
    wire                          lsw13_zero=!(|cmd_data[FRAME_WIDTH_BITS-1:0]); // LSW 13 (FRAME_WIDTH_BITS) low bits are all 0 - set carry bit  
    wire                          msw_zero=  !(|cmd_data[31:16]); // MSW all bits are 0 - set carry bit
      
    
    reg                    [10:0] mode_reg;//mode register: {repet,single,rst_frame,na[2:0],extra_pages[1:0],write_mode,enable,!reset}
    
    reg   [NUM_RC_BURST_BITS-1:0] start_range_addr; // (programmed) First frame in range start (in {row,col8} in burst8, bank ==0
    reg   [NUM_RC_BURST_BITS-1:0] frame_size;       // (programmed) First frame in range start (in {row,col8} in burst8, bank ==0
    reg     [LAST_FRAME_BITS-1:0] last_frame_number; 
    reg   [NUM_RC_BURST_BITS-1:0] start_addr;     // (programmed) Frame start (in {row,col8} in burst8, bank ==0
    reg   [NUM_RC_BURST_BITS-1:0] next_frame_start_addr;
    reg     [LAST_FRAME_BITS-1:0] frame_number_cntr;
    reg     [LAST_FRAME_BITS-1:0] frame_number_current;
    
    reg                           is_last_frame;
//    reg                     [2:0] frame_start_r;
    reg                     [4:0] frame_start_r; // increased length to have time from line_unfinished to suspend (external)
    
    reg      [FRAME_WIDTH_BITS:0] frame_full_width;     // (programmed) increment combined row/col when moving to the next line
                                                  // frame_width rounded up to max transfer (half page) if frame_width> max transfer/2,
                                                  // otherwise (smaller widths) round up to the nearest power of 2
    reg      [FRAME_WIDTH_BITS:0] window_width;   // (programmed) 0- max
    reg     [FRAME_HEIGHT_BITS:0] window_height;  // (programmed) 0- max
    reg    [FRAME_WIDTH_BITS-1:0] window_x0;      // (programmed) window left
    reg   [FRAME_HEIGHT_BITS-1:0] window_y0;      // (programmed) window top
    reg    [FRAME_WIDTH_BITS-1:0] start_x;        // (programmed) normally 0, copied to curr_x on frame_start  
    reg   [FRAME_HEIGHT_BITS-1:0] start_y;        // (programmed) normally 0, copied to curr_y on frame_start 
    reg                           xfer_done_d;    // xfer_done delayed by 1 cycle;
    assign frame_number =       frame_number_current;
    
    assign set_mode_w =         cmd_we && (cmd_a== MCNTRL_SCANLINE_MODE);
    assign set_status_w =       cmd_we && (cmd_a== MCNTRL_SCANLINE_STATUS_CNTRL);
    assign set_start_addr_w =   cmd_we && (cmd_a== MCNTRL_SCANLINE_STARTADDR);
    assign set_frame_size_w =   cmd_we && (cmd_a== MCNTRL_SCANLINE_FRAME_SIZE);
    assign set_last_frame_w =   cmd_we && (cmd_a== MCNTRL_SCANLINE_FRAME_LAST);
    assign set_frame_width_w =  cmd_we && (cmd_a== MCNTRL_SCANLINE_FRAME_FULL_WIDTH);
    assign set_window_wh_w =    cmd_we && (cmd_a== MCNTRL_SCANLINE_WINDOW_WH);
    assign set_window_x0y0_w =  cmd_we && (cmd_a== MCNTRL_SCANLINE_WINDOW_X0Y0);
    assign set_window_start_w = cmd_we && (cmd_a== MCNTRL_SCANLINE_WINDOW_STARTXY);
    
    assign single_frame_w =  cmd_we && (cmd_a== MCNTRL_SCANLINE_MODE) && cmd_data[9];
    assign rst_frame_num_w = cmd_we && (cmd_a== MCNTRL_SCANLINE_MODE) && cmd_data[8];
    
    // Set parameter registers
    always @(posedge rst or posedge mclk) begin
        if      (rst)                mode_reg <= 0;
        else if (set_mode_w)         mode_reg <= cmd_data[10:0]; // 4:0]; // [4:0];

        if (rst) single_frame_r <= 0;
        else     single_frame_r <= single_frame_w;
        
        if (rst) rst_frame_num_r <= 0;
        else     rst_frame_num_r <= {rst_frame_num_r[0],
                                     rst_frame_num_w |
                                     set_start_addr_w |
                                     set_last_frame_w |
                                     set_frame_size_w};

        if      (rst)                start_range_addr <= 0;
        else if (set_start_addr_w)   start_range_addr <= cmd_data[NUM_RC_BURST_BITS-1:0];

        if      (rst)                frame_size <= 0;
        else if (set_start_addr_w)   frame_size <= 1; // default number of frames - just one
        else if (set_frame_size_w)   frame_size <= cmd_data[NUM_RC_BURST_BITS-1:0];

        if      (rst)              last_frame_number <= 0;
        else if (set_last_frame_w) last_frame_number <= cmd_data[LAST_FRAME_BITS-1:0];
        
        if      (rst)               frame_full_width <=  0;
        else if (set_frame_width_w) frame_full_width <= {lsw13_zero,cmd_data[FRAME_WIDTH_BITS-1:0]};
        
        if (rst) is_last_frame <= 0;
        else     is_last_frame <= frame_number_cntr == last_frame_number;
        
        if (rst) frame_start_r <= 0;
        else     frame_start_r <= {frame_start_r[3:0], frame_start & frame_en};

        if      (rst)                             frame_en <= 0;
        else if (single_frame_r || repeat_frames) frame_en <= 1;
        else if (frame_start)                     frame_en <= 0;
        
        if      (rst)                frame_number_cntr <= 0;
        else if (rst_frame_num_r[0]) frame_number_cntr <= 0;
        else if (frame_start_r[2])   frame_number_cntr <= is_last_frame?{LAST_FRAME_BITS{1'b0}}:(frame_number_cntr+1);

        if      (rst)                frame_number_current <= 0;
        else if (rst_frame_num_r[0]) frame_number_current <= 0;
        else if (frame_start_r[2])   frame_number_current <= frame_number_cntr;

        if      (rst)                next_frame_start_addr <= start_range_addr; // just to use rst
        else if (rst_frame_num_r[1]) next_frame_start_addr <= start_range_addr;
        else if (frame_start_r[2])   next_frame_start_addr <= is_last_frame? start_range_addr : (start_addr+frame_size);

        if      (rst)                start_addr <= start_range_addr; // just to use rst
        else if (frame_start_r[0])   start_addr <= next_frame_start_addr;
        
        if      (rst) begin
               window_width <= 0; 
               window_height <=  0;
        end else if (set_window_wh_w)  begin
               window_width <= {lsw13_zero,cmd_data[FRAME_WIDTH_BITS-1:0]};
               window_height  <= {msw_zero,cmd_data[FRAME_HEIGHT_BITS+15:16]};
        end

        if      (rst) begin
               window_x0 <= 0; 
               window_y0 <=  0;
        end else if (set_window_x0y0_w)  begin
               window_x0 <= cmd_data[FRAME_WIDTH_BITS-1:0];
               window_y0  <=cmd_data[FRAME_HEIGHT_BITS+15:16];
        end

        if      (rst) begin
               start_x <= 0; 
               start_y <=  0;
        end else if (set_window_start_w)  begin
               start_x <= cmd_data[FRAME_WIDTH_BITS-1:0];
               start_y  <=cmd_data[FRAME_HEIGHT_BITS+15:16];
        end
    end
    assign mul_rslt_w=  frame_y8_r * frame_full_width_r; // 5 MSBs will be discarded
    assign xfer_num128= xfer_num128_r[NUM_XFER_BITS-1:0];
    assign xfer_start_rd=  xfer_start_rd_r;
    assign xfer_start_wr=  xfer_start_wr_r;
    assign calc_valid=  par_mod_r[PAR_MOD_LATENCY-1]; // MSB, longest 0
    assign xfer_page_rst_wr=  xfer_page_rst_r;
    assign xfer_page_rst_rd=  xfer_page_rst_neg;
    
    assign xfer_partial=      xfer_limited_by_mem_page_r;
    
    assign frame_done=  frame_done_r;
    assign frame_finished=  frame_finished_r;
    
//    assign pre_want=    chn_en && busy_r && !want_r && !xfer_start_r[0] && calc_valid && !last_block && !suspend && !frame_start_r[0];
    assign pre_want=    chn_en && busy_r && !want_r && !xfer_start_r[0] && calc_valid && !last_block && !suspend && !(|frame_start_r);

    assign last_in_row_w=(row_left=={{(FRAME_WIDTH_BITS-NUM_XFER_BITS){1'b0}},xfer_num128_r});
    assign last_row_w=  next_y==window_height;
    assign xfer_want=   want_r;
    assign xfer_need=   need_r;
    assign xfer_bank=   bank_reg[2]; // TODO: just a single reg layer
    assign xfer_row= row_col_r[NUM_RC_BURST_BITS-1:COLADDR_NUMBER-3] ;      // memory row
    assign xfer_col= row_col_r[COLADDR_NUMBER-4:0];    // start memory column in 8-bursts
    assign line_unfinished=line_unfinished_r[1];
    assign chn_en =         &mode_reg[1:0];   // enable requests by channel (continue ones in progress)
    assign chn_rst =        ~mode_reg[0]; // resets command, including fifo;
    assign cmd_wrmem =       mode_reg[2];// 0: read from memory, 1:write to memory
    assign cmd_extra_pages = mode_reg[4:3]; // external module needs more than 1 page
    assign repeat_frames=    mode_reg[10];
    
    assign status_data= {frame_finished_r, busy_r};     // TODO: Add second bit?
    assign pgm_param_w=      cmd_we;
    localparam [COLADDR_NUMBER-3-NUM_XFER_BITS-1:0] EXTRA_BITS=0;
    assign remainder_in_xfer = {EXTRA_BITS, lim_by_xfer}-mem_page_left;
    
    integer i;
    wire xfer_limited_by_mem_page;
    reg  xfer_limited_by_mem_page_r;
    assign xfer_limited_by_mem_page= mem_page_left < {EXTRA_BITS,lim_by_xfer};

/// Recalcualting just after starting request - preparing for the next one. Also happens after parameter change.
/// Should dpepend only on the parameters updated separately (curr_x, curr_y)
    always @(posedge mclk) begin // TODO: Match latencies (is it needed?) Reduce consumption by CE?
        if (recalc_r[0]) begin // cycle 1
            frame_x <= curr_x + window_x0;
            frame_y <= curr_y + window_y0;
            next_y <= curr_y + 1;
            row_left <= window_width - curr_x; // 14 bits - 13 bits
        end
// registers to be absorbed in DSP block        
        frame_y8_r <= frame_y[FRAME_HEIGHT_BITS-1:3]; // lat=2
        frame_full_width_r <= frame_full_width;
        start_addr_r <= start_addr;
        mul_rslt <= mul_rslt_w[MPY_WIDTH-1:0]; // frame_y8_r * frame_width_r; // 7 bits will be discarded lat=3;
        line_start_addr <= start_addr_r+mul_rslt; // lat=4
        
// TODO: Verify MPY/register timing above        
        if (recalc_r[5]) begin // cycle 6
            row_col_r <= line_start_addr+frame_x;
//            line_start_page_left <= {COLADDR_NUMBER-3{1'b0}} - line_start_addr[COLADDR_NUMBER-4:0]; // 7 bits
            line_start_page_left <=  - line_start_addr[COLADDR_NUMBER-4:0]; // 7 bits
        end
        bank_reg[0]   <= frame_y[2:0]; //TODO: is it needed - a pipeline for the bank? - remove! 
        for (i=0;i<2; i = i+1)
            bank_reg[i+1] <= bank_reg[i];
            
            
        if (recalc_r[6]) begin // cycle 7
            mem_page_left <= {1'b1,line_start_page_left} - frame_x[COLADDR_NUMBER-4:0];
            
            lim_by_xfer <= (|row_left[FRAME_WIDTH_BITS:NUM_XFER_BITS])?
                (1<<NUM_XFER_BITS):
                row_left[NUM_XFER_BITS:0]; // 7 bits, max 'h40
        end
        if (recalc_r[7]) begin // cycle 8
            xfer_limited_by_mem_page_r <= xfer_limited_by_mem_page && !continued_xfer;     
            xfer_num128_r<= continued_xfer?
                {EXTRA_BITS,leftover}:
                (xfer_limited_by_mem_page?
                     mem_page_left[NUM_XFER_BITS:0]:
                     lim_by_xfer[NUM_XFER_BITS:0]);
            //xfer_num128_r depends on leftover only if continued_xfer (after first shortened actual xfer and will not change w/o xfers)
            // and (next) leftover is only set  if continued_xfer==0, so multiple runs without chnge of continued_xfer will not differ       
            if (!continued_xfer) leftover <= remainder_in_xfer[NUM_XFER_BITS-1:0]; //  {EXTRA_BITS, lim_by_xfer}-mem_page_left;
        end
        
        if (recalc_r[8]) begin // cycle 9
            last_in_row <= last_in_row_w; //(row_left=={{(FRAME_WIDTH_BITS-NUM_XFER_BITS){1'b0}},xfer_num128_r});
        end
            
            
    end
wire    start_not_partial= xfer_start_r[0] && !xfer_limited_by_mem_page_r;    
// now have row start address, bank and row_left ;
// calculate number to read (min of row_left, maximal xfer and what is left in the DDR3 page    
    always @(posedge rst or posedge mclk) begin
        if      (rst)                 par_mod_r<=0;
        else if (pgm_param_w ||
                 xfer_start_r[0] ||
                 chn_rst ||
                 frame_start_r[0])    par_mod_r<=0;
        else                          par_mod_r <= {par_mod_r[PAR_MOD_LATENCY-2:0], 1'b1};

        if      (rst)          chn_rst_d <= 0;
        else                   chn_rst_d <= chn_rst;

        if      (rst)          recalc_r<=0;
        else if (chn_rst)      recalc_r<=0;
        else                   recalc_r <= {recalc_r[PAR_MOD_LATENCY-2:0],
             ((xfer_start_r[0] | frame_start_r[0]) & ~chn_rst) | pgm_param_w | (chn_rst_d & ~chn_rst)};
        
        if      (rst)               busy_r <= 0;
        else if (chn_rst)           busy_r <= 0;
        else if (frame_start_r[0])  busy_r <= 1;
        else if (frame_done_r)      busy_r <= 0;
        
        if (rst)          xfer_done_d <= 0;
        else              xfer_done_d <= xfer_done;
        
        
        if (rst)                    continued_xfer <= 1'b0;
        else if (chn_rst)           continued_xfer <= 1'b0;
        else if (frame_start_r[0])  continued_xfer <= 1'b0;
        else if (xfer_start_r[0])   continued_xfer <= xfer_limited_by_mem_page_r; // only set after actual start if it was partial, not after parameter change

        // single cycle (sent out)
        if (rst)          frame_done_r <= 0;
        else              frame_done_r <= busy_r && last_block && xfer_done_d && (pending_xfers==0);

        // turns and stays on (used in status)
        if (rst)                              frame_finished_r <= 0;
        else if (chn_rst || frame_start_r[0]) frame_finished_r <= 0;
        else if (frame_done_r)                frame_finished_r <= 1;
        
        if (rst) xfer_start_r <= 0;
        else     xfer_start_r <= {xfer_start_r[1:0],xfer_grant && !chn_rst};

        if (rst) xfer_start_rd_r <= 0;
        else     xfer_start_rd_r <=  xfer_grant && !chn_rst && !cmd_wrmem;

        if (rst) xfer_start_wr_r <= 0;
        else     xfer_start_wr_r <=  xfer_grant && !chn_rst && cmd_wrmem;
        
        if (rst)                                          need_r <= 0;
        else if (chn_rst || xfer_grant)                   need_r <= 0;
        else if ((pre_want  || want_r) && (page_cntr>=3)) need_r <= 1; // may raise need if want was already set

        if (rst)                                                 want_r <= 0;
        else if (chn_rst || xfer_grant)                          want_r <= 0;
        else if (pre_want && (page_cntr>{1'b0,cmd_extra_pages})) want_r <= 1;
        
        if (rst)                                   page_cntr <= 0;
        else if (frame_start_r[0])                 page_cntr <= cmd_wrmem?0:4; // What about last pages (like if only 1 page is needed)? Early frame end?
        else if ( start_not_partial && !next_page) page_cntr <= page_cntr - 1;     
        else if (!start_not_partial &&  next_page) page_cntr <= page_cntr + 1;
        
        if (rst) xfer_page_rst_r <= 1;
        else     xfer_page_rst_r <= chn_rst || (MCNTRL_SCANLINE_FRAME_PAGE_RESET ? (frame_start_r[0] & cmd_wrmem):1'b0);

        if (rst) xfer_page_rst_pos <= 1;
        else     xfer_page_rst_pos <= chn_rst || (MCNTRL_SCANLINE_FRAME_PAGE_RESET ? (frame_start_r[0] & ~cmd_wrmem):1'b0);

        
// increment x,y (two cycles)
        if (rst)                                  curr_x <= 0;
        else if (chn_rst || frame_start_r[0])     curr_x <= start_x;
        else if (xfer_start_r[0])                 curr_x <= last_in_row?0: curr_x + xfer_num128_r;
        
        if (rst)                                  curr_y <= 0;
        else if (chn_rst || frame_start_r[0])     curr_y <= start_y;
        else if (xfer_start_r[0] && last_in_row)  curr_y <= next_y[FRAME_HEIGHT_BITS-1:0];
               
        if      (rst)                         last_block <= 0;
        else if (chn_rst || !busy_r)          last_block <= 0;
        else if (xfer_start_r[0])             last_block <= last_row_w && last_in_row_w;
        
        if      (rst)                              pending_xfers <= 0;
        else if (chn_rst || !busy_r)               pending_xfers <= 0;
        else if ( xfer_start_r[0] && !xfer_done) pending_xfers <= pending_xfers + 1;     
        else if (!xfer_start_r[0] &&  xfer_done) pending_xfers <= pending_xfers - 1;
        
        
        
        //line_unfinished_r cmd_wrmem
        if (rst)                              line_unfinished_r[0] <= 0; //{FRAME_HEIGHT_BITS{1'b0}};
        else if (chn_rst || frame_start_r[0]) line_unfinished_r[0] <= window_y0+start_y;
        else if (xfer_start_r[2])             line_unfinished_r[0] <= window_y0+next_y[FRAME_HEIGHT_BITS-1:0]; // latency 2 from xfer_start

        if (rst)                              line_unfinished_r[1] <= 0; //{FRAME_HEIGHT_BITS{1'b0}};
//        else if (chn_rst || frame_start_r[0]) line_unfinished_r[1] <= window_y0+start_y;
        else if (chn_rst || frame_start_r[2]) line_unfinished_r[1] <= window_y0+start_y; // _r[0] -> _r[2] to make it simultaneous with frame_number
        // in read mode advance line number ASAP
        else if (xfer_start_r[2] && !cmd_wrmem) line_unfinished_r[1] <= window_y0+next_y[FRAME_HEIGHT_BITS-1:0]; // latency 2 from xfer_start
        // in write mode advance line number only when it is guaranteed it will be the first to actually access memory
        else if (xfer_grant      && cmd_wrmem)  line_unfinished_r[1] <=  line_unfinished_r[0];
        
    end
    always @ (negedge mclk) begin
        xfer_page_rst_neg <= xfer_page_rst_pos;
    end
    cmd_deser #(
        .ADDR       (MCNTRL_SCANLINE_ADDR),
        .ADDR_MASK  (MCNTRL_SCANLINE_MASK),
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
        .STATUS_REG_ADDR  (MCNTRL_SCANLINE_STATUS_REG_ADDR),
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

