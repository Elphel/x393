/*******************************************************************************
 * Module: cmd_encod_tiled_mux
 * Date:2015-01-31  
 * Author: andrey     
 * Description: Multiplex parameters from multiple channels sharing the same
 * tiled command encoders (cmd_encod_tiled_rd and cmd_encod_tiled_wr)
 * Latency 1 clcok cycle
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * cmd_encod_tiled_mux.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  cmd_encod_tiled_mux.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  cmd_encod_tiled_mux #(
    parameter ADDRESS_NUMBER=       15,
    parameter COLADDR_NUMBER=       10,
    parameter FRAME_WIDTH_BITS=                 13,    // Maximal frame width - 8-word (16 bytes) bursts 
//    parameter FRAME_HEIGHT_BITS=                16,    // Maximal frame height 
    parameter MAX_TILE_WIDTH=                   6,     // number of bits to specify maximal tile (width-1) (6 -> 64)
    parameter MAX_TILE_HEIGHT=                  6      // number of bits to specify maximal tile (height-1) (6 -> 64)
) (
    input                        clk,
`ifdef def_tiled_chn0
    input                  [2:0] bank0,    // bank address
    input   [ADDRESS_NUMBER-1:0] row0,     // memory row
    input   [COLADDR_NUMBER-4:0] col0,     // start memory column in 8-bit bursts 
    input   [FRAME_WIDTH_BITS:0] rowcol_inc0, // increment {row.col} when bank rolls over, removed 3 LSBs (in 8-bursts)
    input   [MAX_TILE_WIDTH-1:0] num_rows0,   // number of rows to read minus 1
    input  [MAX_TILE_HEIGHT-1:0] num_cols0,   // number of 16-pixel columns to read (rows first, then columns) - 1
    input                        keep_open0,  // keep banks open (for <=8 banks only    
    input                        partial0,    // first of the two halves of a split tile (caused by memory page crossing)    
    input                        start0,       // start generating commands
`endif
`ifdef def_tiled_chn1
    input                  [2:0] bank1,    // bank address
    input   [ADDRESS_NUMBER-1:0] row1,     // memory row
    input   [COLADDR_NUMBER-4:0] col1,     // start memory column in 8-bit bursts 
    input   [FRAME_WIDTH_BITS:0] rowcol_inc1, // increment {row.col} when bank rolls over, removed 3 LSBs (in 8-bursts)
    input   [MAX_TILE_WIDTH-1:0] num_rows1,   // number of rows to read minus 1
    input  [MAX_TILE_HEIGHT-1:0] num_cols1,   // number of 16-pixel columns to read (rows first, then columns) - 1
    input                        keep_open1,  // keep banks open (for <=8 banks only    
    input                        partial1,    // first of the two halves of a split tile (caused by memory page crossing)    
    input                        start1,       // start generating commands
`endif
`ifdef def_tiled_chn2
    input                  [2:0] bank2,    // bank address
    input   [ADDRESS_NUMBER-1:0] row2,     // memory row
    input   [COLADDR_NUMBER-4:0] col2,     // start memory column in 8-bit bursts 
    input   [FRAME_WIDTH_BITS:0] rowcol_inc2, // increment {row.col} when bank rolls over, removed 3 LSBs (in 8-bursts)
    input   [MAX_TILE_WIDTH-1:0] num_rows2,   // number of rows to read minus 1
    input  [MAX_TILE_HEIGHT-1:0] num_cols2,   // number of 16-pixel columns to read (rows first, then columns) - 1
    input                        keep_open2,  // keep banks open (for <=8 banks only    
    input                        partial2,    // first of the two halves of a split tile (caused by memory page crossing)    
    input                        start2,       // start generating commands
`endif
`ifdef def_tiled_chn3
    input                  [2:0] bank3,    // bank address
    input   [ADDRESS_NUMBER-1:0] row3,     // memory row
    input   [COLADDR_NUMBER-4:0] col3,     // start memory column in 8-bit bursts 
    input   [FRAME_WIDTH_BITS:0] rowcol_inc3, // increment {row.col} when bank rolls over, removed 3 LSBs (in 8-bursts)
    input   [MAX_TILE_WIDTH-1:0] num_rows3,   // number of rows to read minus 1
    input  [MAX_TILE_HEIGHT-1:0] num_cols3,   // number of 16-pixel columns to read (rows first, then columns) - 1
    input                        keep_open3,  // keep banks open (for <=8 banks only    
    input                        partial3,    // first of the two halves of a split tile (caused by memory page crossing)    
    input                        start3,       // start generating commands
`endif
`ifdef def_tiled_chn4
    input                  [2:0] bank4,    // bank address
    input   [ADDRESS_NUMBER-1:0] row4,     // memory row
    input   [COLADDR_NUMBER-4:0] col4,     // start memory column in 8-bit bursts 
    input   [FRAME_WIDTH_BITS:0] rowcol_inc4, // increment {row.col} when bank rolls over, removed 3 LSBs (in 8-bursts)
    input   [MAX_TILE_WIDTH-1:0] num_rows4,   // number of rows to read minus 1
    input  [MAX_TILE_HEIGHT-1:0] num_cols4,   // number of 16-pixel columns to read (rows first, then columns) - 1
    input                        keep_open4,  // keep banks open (for <=8 banks only
    input                        partial4,    // first of the two halves of a split tile (caused by memory page crossing)    
    input                        start4,       // start generating commands
`endif
`ifdef def_tiled_chn5
    input                  [2:0] bank5,    // bank address
    input   [ADDRESS_NUMBER-1:0] row5,     // memory row
    input   [COLADDR_NUMBER-4:0] col5,     // start memory column in 8-bit bursts 
    input   [FRAME_WIDTH_BITS:0] rowcol_inc5, // increment {row.col} when bank rolls over, removed 3 LSBs (in 8-bursts)
    input   [MAX_TILE_WIDTH-1:0] num_rows5,   // number of rows to read minus 1
    input  [MAX_TILE_HEIGHT-1:0] num_cols5,   // number of 16-pixel columns to read (rows first, then columns) - 1
    input                        keep_open5,  // keep banks open (for <=8 banks only    
    input                        partial5,    // first of the two halves of a split tile (caused by memory page crossing)    
    input                        start5,       // start generating commands
`endif
`ifdef def_tiled_chn6
    input                  [2:0] bank6,    // bank address
    input   [ADDRESS_NUMBER-1:0] row6,     // memory row
    input   [COLADDR_NUMBER-4:0] col6,     // start memory column in 8-bit bursts 
    input   [FRAME_WIDTH_BITS:0] rowcol_inc6, // increment {row.col} when bank rolls over, removed 3 LSBs (in 8-bursts)
    input   [MAX_TILE_WIDTH-1:0] num_rows6,   // number of rows to read minus 1
    input  [MAX_TILE_HEIGHT-1:0] num_cols6,   // number of 16-pixel columns to read (rows first, then columns) - 1
    input                        keep_open6,  // keep banks open (for <=8 banks only    
    input                        partial6,    // first of the two halves of a split tile (caused by memory page crossing)    
    input                        start6,       // start generating commands
`endif
`ifdef def_tiled_chn7
    input                  [2:0] bank7,    // bank address
    input   [ADDRESS_NUMBER-1:0] row7,     // memory row
    input   [COLADDR_NUMBER-4:0] col7,     // start memory column in 8-bit bursts 
    input   [FRAME_WIDTH_BITS:0] rowcol_inc7, // increment {row.col} when bank rolls over, removed 3 LSBs (in 8-bursts)
    input   [MAX_TILE_WIDTH-1:0] num_rows7,   // number of rows to read minus 1
    input  [MAX_TILE_HEIGHT-1:0] num_cols7,   // number of 16-pixel columns to read (rows first, then columns) - 1
    input                        keep_open7,  // keep banks open (for <=8 banks only    
    input                        partial7,    // first of the two halves of a split tile (caused by memory page crossing)    
    input                        start7,       // start generating commands
`endif
`ifdef def_tiled_chn8
    input                  [2:0] bank8,    // bank address
    input   [ADDRESS_NUMBER-1:0] row8,     // memory row
    input   [COLADDR_NUMBER-4:0] col8,     // start memory column in 8-bit bursts 
    input   [FRAME_WIDTH_BITS:0] rowcol_inc8, // increment {row.col} when bank rolls over, removed 3 LSBs (in 8-bursts)
    input   [MAX_TILE_WIDTH-1:0] num_rows8,   // number of rows to read minus 1
    input  [MAX_TILE_HEIGHT-1:0] num_cols8,   // number of 16-pixel columns to read (rows first, then columns) - 1
    input                        keep_open8,  // keep banks open (for <=8 banks only    
    input                        partial8,    // first of the two halves of a split tile (caused by memory page crossing)    
    input                        start8,       // start generating commands
`endif
`ifdef def_tiled_chn9
    input                  [2:0] bank9,    // bank address
    input   [ADDRESS_NUMBER-1:0] row9,     // memory row
    input   [COLADDR_NUMBER-4:0] col9,     // start memory column in 8-bit bursts 
    input   [FRAME_WIDTH_BITS:0] rowcol_inc9, // increment {row.col} when bank rolls over, removed 3 LSBs (in 8-bursts)
    input   [MAX_TILE_WIDTH-1:0] num_rows9,   // number of rows to read minus 1
    input  [MAX_TILE_HEIGHT-1:0] num_cols9,   // number of 16-pixel columns to read (rows first, then columns) - 1
    input                        keep_open9,  // keep banks open (for <=8 banks only    
    input                        partial9,    // first of the two halves of a split tile (caused by memory page crossing)    
    input                        start9,      // start generating commands
`endif
`ifdef def_tiled_chn10
    input                  [2:0] bank10,    // bank address
    input   [ADDRESS_NUMBER-1:0] row10,     // memory row
    input   [COLADDR_NUMBER-4:0] col10,     // start memory column in 8-bit bursts 
    input   [FRAME_WIDTH_BITS:0] rowcol_inc10, // increment {row.col} when bank rolls over, removed 3 LSBs (in 8-bursts)
    input   [MAX_TILE_WIDTH-1:0] num_rows10,   // number of rows to read minus 1
    input  [MAX_TILE_HEIGHT-1:0] num_cols10,   // number of 16-pixel columns to read (rows first, then columns) - 1
    input                        keep_open10,  // keep banks open (for <=8 banks only    
    input                        partial10,    // first of the two halves of a split tile (caused by memory page crossing)    
    input                        start10,      // start generating commands
`endif
`ifdef def_tiled_chn11
    input                  [2:0] bank11,    // bank address
    input   [ADDRESS_NUMBER-1:0] row11,     // memory row
    input   [COLADDR_NUMBER-4:0] col11,     // start memory column in 8-bit bursts 
    input   [FRAME_WIDTH_BITS:0] rowcol_inc11, // increment {row.col} when bank rolls over, removed 3 LSBs (in 8-bursts)
    input   [MAX_TILE_WIDTH-1:0] num_rows11,   // number of rows to read minus 1
    input  [MAX_TILE_HEIGHT-1:0] num_cols11,   // number of 16-pixel columns to read (rows first, then columns) - 1
    input                        keep_open11,  // keep banks open (for <=8 banks only    
    input                        partial11,    // first of the two halves of a split tile (caused by memory page crossing)    
    input                        start11,      // start generating commands
`endif
`ifdef def_tiled_chn12
    input                  [2:0] bank12,    // bank address
    input   [ADDRESS_NUMBER-1:0] row12,     // memory row
    input   [COLADDR_NUMBER-4:0] col12,     // start memory column in 8-bit bursts 
    input   [FRAME_WIDTH_BITS:0] rowcol_inc12, // increment {row.col} when bank rolls over, removed 3 LSBs (in 8-bursts)
    input   [MAX_TILE_WIDTH-1:0] num_rows12,   // number of rows to read minus 1
    input  [MAX_TILE_HEIGHT-1:0] num_cols12,   // number of 16-pixel columns to read (rows first, then columns) - 1
    input                        keep_open12,  // keep banks open (for <=8 banks only    
    input                        partial12,    // first of the two halves of a split tile (caused by memory page crossing)    
    input                        start12,      // start generating commands
`endif
`ifdef def_tiled_chn13
    input                  [2:0] bank13,    // bank address
    input   [ADDRESS_NUMBER-1:0] row13,     // memory row
    input   [COLADDR_NUMBER-4:0] col13,     // start memory column in 8-bit bursts 
    input   [FRAME_WIDTH_BITS:0] rowcol_inc13, // increment {row.col} when bank rolls over, removed 3 LSBs (in 8-bursts)
    input   [MAX_TILE_WIDTH-1:0] num_rows13,   // number of rows to read minus 1
    input  [MAX_TILE_HEIGHT-1:0] num_cols13,   // number of 16-pixel columns to read (rows first, then columns) - 1
    input                        keep_open13,  // keep banks open (for <=8 banks only    
    input                        partial13,    // first of the two halves of a split tile (caused by memory page crossing)    
    input                        start13,      // start generating commands
`endif
`ifdef def_tiled_chn14
    input                  [2:0] bank14,    // bank address
    input   [ADDRESS_NUMBER-1:0] row14,     // memory row
    input   [COLADDR_NUMBER-4:0] col14,     // start memory column in 8-bit bursts 
    input   [FRAME_WIDTH_BITS:0] rowcol_inc14, // increment {row.col} when bank rolls over, removed 3 LSBs (in 8-bursts)
    input   [MAX_TILE_WIDTH-1:0] num_rows14,   // number of rows to read minus 1
    input  [MAX_TILE_HEIGHT-1:0] num_cols14,   // number of 16-pixel columns to read (rows first, then columns) - 1
    input                        keep_open14,  // keep banks open (for <=8 banks only    
    input                        partial14,    // first of the two halves of a split tile (caused by memory page crossing)    
    input                        start14,      // start generating commands
`endif
`ifdef def_tiled_chn15
    input                  [2:0] bank15,    // bank address
    input   [ADDRESS_NUMBER-1:0] row15,     // memory row
    input   [COLADDR_NUMBER-4:0] col15,     // start memory column in 8-bit bursts 
    input   [FRAME_WIDTH_BITS:0] rowcol_inc15, // increment {row.col} when bank rolls over, removed 3 LSBs (in 8-bursts)
    input   [MAX_TILE_WIDTH-1:0] num_rows15,   // number of rows to read minus 1
    input  [MAX_TILE_HEIGHT-1:0] num_cols15,   // number of 16-pixel columns to read (rows first, then columns) - 1
    input                        keep_open15,  // keep banks open (for <=8 banks only    
    input                        partial15,    // first of the two halves of a split tile (caused by memory page crossing)    
    input                        start15,       // start generating commands
`endif
    output                  [2:0] bank,    // bank address
    output   [ADDRESS_NUMBER-1:0] row,     // memory row
    output   [COLADDR_NUMBER-4:0] col,     // start memory column in 8-bit bursts 
    output   [FRAME_WIDTH_BITS:0] rowcol_inc, // increment {row.col} when bank rolls over, removed 3 LSBs (in 8-bursts)
    output   [MAX_TILE_WIDTH-1:0] num_rows,   // number of rows to read minus 1
    output  [MAX_TILE_HEIGHT-1:0] num_cols,   // number of 16-pixel columns to read (rows first, then columns) - 1
    output                        keep_open,  // keep banks open (for <=8 banks only
    output                        partial,    // first of the two halves of a split tile (caused by memory page crossing)    
    output                        start_rd,   // start generating commands in cmd_encod_linear_rd
    output                        start_wr    // start generating commands in cmd_encod_linear_wr
);
    reg                  [2:0] bank_r;       // bank address
    reg   [ADDRESS_NUMBER-1:0] row_r;        // memory row
    reg   [COLADDR_NUMBER-4:0] col_r;        // start memory column in 8-bit bursts 
    reg   [FRAME_WIDTH_BITS:0] rowcol_inc_r; // increment {row.col} when bank rolls over_r; removed 3 LSBs (in 8-bursts)
    reg   [MAX_TILE_WIDTH-1:0] num_rows_r;   // number of rows to read minus 1
    reg  [MAX_TILE_HEIGHT-1:0] num_cols_r;   // number of 16-pixel columns to read (rows first_r; then columns) - 1
    reg                        keep_open_r;  // keep banks open (for <=8 banks only
    reg                        partial_r;    // partial tile    
    reg                        start_rd_r;   // start generating commands in cmd_encod_linear_rd
    reg                        start_wr_r;   // start generating commands in cmd_encod_linear_wr

    wire                  [2:0] bank_w;       // bank address
    wire   [ADDRESS_NUMBER-1:0] row_w;        // memory row
    wire   [COLADDR_NUMBER-4:0] col_w;        // start memory column in 8-bit bursts 
    wire   [FRAME_WIDTH_BITS:0] rowcol_inc_w; // increment {row.col} when bank rolls over_r; removed 3 LSBs (in 8-bursts)
    wire   [MAX_TILE_WIDTH-1:0] num_rows_w;   // number of rows to read minus 1
    wire  [MAX_TILE_HEIGHT-1:0] num_cols_w;   // number of 16-pixel columns to read (rows first_r; then columns) - 1
    wire                        keep_open_w;  // keep banks open (for <=8 banks only
    wire                        partial_w;    // partila tile (first half)    
    wire                        start_rd_w;   // start generating commands in cmd_encod_linear_rd
    wire                        start_wr_w;   // start generating commands in cmd_encod_linear_wr

   
    localparam PAR_WIDTH=(3)+(ADDRESS_NUMBER)+(COLADDR_NUMBER-3)+(FRAME_WIDTH_BITS+1)+(MAX_TILE_WIDTH)+(MAX_TILE_HEIGHT)+(1)+(1)+(2);
    localparam [PAR_WIDTH-1:0] PAR_DEFAULT=0;
    assign bank =         bank_r;
    assign row =          row_r;
    assign col =          col_r;
    assign rowcol_inc =   rowcol_inc_r; // increment {row.col} when bank rolls over_r; removed 3 LSBs (in 8-bursts)
    assign num_rows =     num_rows_r;   // number of rows to read minus 1
    assign num_cols =     num_cols_r;   // number of 16-pixel columns to read (rows first_r; then columns) - 1
    assign keep_open =    keep_open_r;  // keep banks open (for <=8 banks only    
    assign partial =      partial_r;    // partial tile    
    assign start_rd =     start_rd_r;
    assign start_wr =     start_wr_r;
    localparam [15:0]  CHN_RD_MEM={
`ifdef def_read_mem_chn15
    1'b1,
`else 
    1'b0,           
`endif    
`ifdef def_read_mem_chn14
    1'b1,
`else 
    1'b0,           
`endif    
`ifdef def_read_mem_chn13
    1'b1,
`else 
    1'b0,           
`endif    
`ifdef def_read_mem_chn12
    1'b1,
`else 
    1'b0,           
`endif    
`ifdef def_read_mem_chn11
    1'b1,
`else 
    1'b0,           
`endif    
`ifdef def_read_mem_chn10
    1'b1,
`else 
    1'b0,           
`endif    
`ifdef def_read_mem_chn9
    1'b1,
`else 
    1'b0,           
`endif    
`ifdef def_read_mem_chn8
    1'b1,
`else 
    1'b0,           
`endif    
`ifdef def_read_mem_chn7
    1'b1,
`else 
    1'b0,           
`endif    
`ifdef def_read_mem_chn6
    1'b1,
`else 
    1'b0,           
`endif    
`ifdef def_read_mem_chn5
    1'b1,
`else 
    1'b0,           
`endif    
`ifdef def_read_mem_chn4
    1'b1,
`else 
    1'b0,           
`endif    
`ifdef def_read_mem_chn3
    1'b1,
`else 
    1'b0,           
`endif    
`ifdef def_read_mem_chn2
    1'b1,
`else 
    1'b0,           
`endif    
`ifdef def_read_mem_chn1
    1'b1,
`else 
    1'b0,           
`endif    
`ifdef def_read_mem_chn0
    1'b1};
`else 
    1'b0};           
`endif    
    
    
    assign {bank_w, row_w, col_w, rowcol_inc_w, num_rows_w, num_cols_w, keep_open_w, partial_w, start_rd_w, start_wr_w} = 0    
`ifdef def_tiled_chn0
            | (start0?{bank0, row0, col0, rowcol_inc0, num_rows0, num_cols0, keep_open0, partial0, CHN_RD_MEM[0],~CHN_RD_MEM[0]}:PAR_DEFAULT)
`endif    
`ifdef def_tiled_chn1
            | (start1?{bank1, row1, col1, rowcol_inc1, num_rows1, num_cols1, keep_open1, partial1, CHN_RD_MEM[1],~CHN_RD_MEM[1]}:PAR_DEFAULT)
`endif    
`ifdef def_tiled_chn2
            | (start2?{bank2, row2, col2, rowcol_inc2, num_rows2, num_cols2, keep_open2, partial2, CHN_RD_MEM[2],~CHN_RD_MEM[2]}:PAR_DEFAULT)
`endif    
`ifdef def_tiled_chn3
            | (start3?{bank3, row3, col3, rowcol_inc3, num_rows3, num_cols3, keep_open3, partial3, CHN_RD_MEM[3],~CHN_RD_MEM[3]}:PAR_DEFAULT)
`endif    
`ifdef def_tiled_chn4
            | (start4?{bank4, row4, col4, rowcol_inc4, num_rows4, num_cols4, keep_open4, partial4, CHN_RD_MEM[4],~CHN_RD_MEM[4]}:PAR_DEFAULT)
`endif    
`ifdef def_tiled_chn5
            | (start5?{bank5, row5, col5, rowcol_inc5, num_rows5, num_cols5, keep_open5, partial5, CHN_RD_MEM[5],~CHN_RD_MEM[5]}:PAR_DEFAULT)
`endif    
`ifdef def_tiled_chn6
            | (start6?{bank6, row6, col6, rowcol_inc6, num_rows6, num_cols6, keep_open6, partial6, CHN_RD_MEM[6],~CHN_RD_MEM[6]}:PAR_DEFAULT)
`endif    
`ifdef def_tiled_chn7
            | (start7?{bank7, row7, col7, rowcol_inc7, num_rows7, num_cols7, keep_open7, partial7, CHN_RD_MEM[7],~CHN_RD_MEM[7]}:PAR_DEFAULT)
`endif    
`ifdef def_tiled_chn8
            | (start8?{bank8, row8, col8, rowcol_inc8, num_rows8, num_cols8, keep_open8, partial8, CHN_RD_MEM[8],~CHN_RD_MEM[8]}:PAR_DEFAULT)
`endif    
`ifdef def_tiled_chn9
            | (start9?{bank9, row9, col9, rowcol_inc9, num_rows9, num_cols9, keep_open9, partial9, CHN_RD_MEM[9],~CHN_RD_MEM[9]}:PAR_DEFAULT)
`endif    
`ifdef def_tiled_chn10
            | (start10?{bank10, row10, col10, rowcol_inc10, num_rows10, num_cols10, keep_open10, partial10, CHN_RD_MEM[10],~CHN_RD_MEM[10]}:PAR_DEFAULT)
`endif    
`ifdef def_tiled_chn11
            | (start11?{bank11, row11, col11, rowcol_inc11, num_rows11, num_cols11, keep_open11, partial11, CHN_RD_MEM[11],~CHN_RD_MEM[11]}:PAR_DEFAULT)
`endif    
`ifdef def_tiled_chn12
            | (start12?{bank12, row12, col12, rowcol_inc12, num_rows12, num_cols12, keep_open12, partial12, CHN_RD_MEM[12],~CHN_RD_MEM[12]}:PAR_DEFAULT)
`endif    
`ifdef def_tiled_chn13
            | (start13?{bank13, row13, col13, rowcol_inc13, num_rows13, num_cols13, keep_open13, partial13, CHN_RD_MEM[13],~CHN_RD_MEM[13]}:PAR_DEFAULT)
`endif    
`ifdef def_tiled_chn14
            | (start14?{bank14, row14, col14, rowcol_inc14, num_rows14, num_cols14, keep_open14, partial14, CHN_RD_MEM[14],~CHN_RD_MEM[14]}:PAR_DEFAULT)
`endif    
`ifdef def_tiled_chn15
            | (start15?{bank15, row15, col15, rowcol_inc15, num_rows15, num_cols15, keep_open15, partial15, CHN_RD_MEM[15],~CHN_RD_MEM[15]}:PAR_DEFAULT)
`endif    
;
    always @ (posedge clk) begin
        if (start_rd_w || start_wr_w) begin
            bank_r <=        bank_w;
            row_r <=         row_w;
            col_r <=         col_w;
            rowcol_inc_r <=  rowcol_inc_w;
            num_rows_r <=    num_rows_w;
            num_cols_r <=    num_cols_w;
            keep_open_r <=   keep_open_w;
            partial_r <=     partial_w;
        end
        start_rd_r <=     start_rd_w;
        start_wr_r <=     start_wr_w;
    end
    

endmodule
