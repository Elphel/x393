/*******************************************************************************
 * Module: cmd_encod_linear_mux
 * Date:2015-01-31  
 * Author: andrey     
 * Description: Multiplex parameters from multiple channels sharing the same
 * linear command encoders (cmd_encod_linear_rd and cmd_encod_linear_wr)
 * Latency 1 clcok cycle
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * cmd_encod_linear_mux.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  cmd_encod_linear_mux.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  cmd_encod_linear_mux#(
    parameter ADDRESS_NUMBER=       15,
    parameter COLADDR_NUMBER=       10
) (
    input                        clk,
`ifdef def_scanline_chn0
    input                  [2:0] bank0,      // bank address
    input   [ADDRESS_NUMBER-1:0] row0,       // memory row
    input   [COLADDR_NUMBER-4:0] start_col0, // start memory column in 8-bursts
    input                  [5:0] num128_0,   // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    input                        start0,     // start generating commands
`endif
`ifdef def_scanline_chn1
    input                  [2:0] bank1,      // bank address
    input   [ADDRESS_NUMBER-1:0] row1,       // memory row
    input   [COLADDR_NUMBER-4:0] start_col1, // start memory column in 8-bursts
    input                  [5:0] num128_1,   // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    input                        start1,     // start generating commands
`endif
`ifdef def_scanline_chn2
    input                  [2:0] bank2,      // bank address
    input   [ADDRESS_NUMBER-1:0] row2,       // memory row
    input   [COLADDR_NUMBER-4:0] start_col2, // start memory column in 8-bursts
    input                  [5:0] num128_2,   // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    input                        start2,     // start generating commands
`endif
`ifdef def_scanline_chn3
    input                  [2:0] bank3,      // bank address
    input   [ADDRESS_NUMBER-1:0] row3,       // memory row
    input   [COLADDR_NUMBER-4:0] start_col3, // start memory column in 8-bursts
    input                  [5:0] num128_3,   // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    input                        start3,     // start generating commands
`endif
`ifdef def_scanline_chn4
    input                  [2:0] bank4,      // bank address
    input   [ADDRESS_NUMBER-1:0] row4,       // memory row
    input   [COLADDR_NUMBER-4:0] start_col4, // start memory column in 8-bursts
    input                  [5:0] num128_4,   // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    input                        start4,     // start generating commands

`endif
`ifdef def_scanline_chn5
    input                  [2:0] bank5,      // bank address
    input   [ADDRESS_NUMBER-1:0] row5,       // memory row
    input   [COLADDR_NUMBER-4:0] start_col5, // start memory column in 8-bursts
    input                  [5:0] num128_5,   // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    input                        start5,     // start generating commands

`endif
`ifdef def_scanline_chn6
    input                  [2:0] bank6,      // bank address
    input   [ADDRESS_NUMBER-1:0] row6,       // memory row
    input   [COLADDR_NUMBER-4:0] start_col6, // start memory column in 8-bursts
    input                  [5:0] num128_6,   // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    input                        start6,     // start generating commands
`endif
`ifdef def_scanline_chn7
    input                  [2:0] bank7,      // bank address
    input   [ADDRESS_NUMBER-1:0] row7,       // memory row
    input   [COLADDR_NUMBER-4:0] start_col7, // start memory column in 8-bursts
    input                  [5:0] num128_7,   // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    input                        start7,     // start generating commands
`endif
`ifdef def_scanline_chn8
    input                  [2:0] bank8,      // bank address
    input   [ADDRESS_NUMBER-1:0] row8,       // memory row
    input   [COLADDR_NUMBER-4:0] start_col8, // start memory column in 8-bursts
    input                  [5:0] num128_8,   // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    input                        start8,     // start generating commands
`endif
`ifdef def_scanline_chn9
    input                  [2:0] bank9,      // bank address
    input   [ADDRESS_NUMBER-1:0] row9,       // memory row
    input   [COLADDR_NUMBER-4:0] start_col9, // start memory column in 8-bursts
    input                  [5:0] num128_9,   // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    input                        start9,     // start generating commands
`endif
`ifdef def_scanline_chn10
    input                  [2:0] bank10,      // bank address
    input   [ADDRESS_NUMBER-1:0] row10,       // memory row
    input   [COLADDR_NUMBER-4:0] start_col10, // start memory column in 8-bursts
    input                  [5:0] num128_10,   // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    input                        start10,     // start generating commands
`endif
`ifdef def_scanline_chn11
    input                  [2:0] bank11,      // bank address
    input   [ADDRESS_NUMBER-1:0] row11,       // memory row
    input   [COLADDR_NUMBER-4:0] start_col11, // start memory column in 8-bursts
    input                  [5:0] num128_11,   // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    input                        start11,     // start generating commands
`endif
`ifdef def_scanline_chn12
    input                  [2:0] bank12,      // bank address
    input   [ADDRESS_NUMBER-1:0] row12,       // memory row
    input   [COLADDR_NUMBER-4:0] start_col12, // start memory column in 8-bursts
    input                  [5:0] num128_12,   // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    input                        start12,     // start generating commands
`endif
`ifdef def_scanline_chn13
    input                  [2:0] bank13,      // bank address
    input   [ADDRESS_NUMBER-1:0] row13,       // memory row
    input   [COLADDR_NUMBER-4:0] start_col13, // start memory column in 8-bursts
    input                  [5:0] num128_13,   // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    input                        start13,     // start generating commands
`endif
`ifdef def_scanline_chn14
    input                  [2:0] bank14,      // bank address
    input   [ADDRESS_NUMBER-1:0] row14,       // memory row
    input   [COLADDR_NUMBER-4:0] start_col14, // start memory column in 8-bursts
    input                  [5:0] num128_14,   // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    input                        start14,     // start generating commands
`endif
`ifdef def_scanline_chn15
    input                  [2:0] bank15,      // bank address
    input   [ADDRESS_NUMBER-1:0] row15,       // memory row
    input   [COLADDR_NUMBER-4:0] start_col15, // start memory column in 8-bursts
    input                  [5:0] num128_15,   // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    input                        start15,     // start generating commands
`endif
    output                  [2:0] bank,       // bank address
    output   [ADDRESS_NUMBER-1:0] row,        // memory row
    output   [COLADDR_NUMBER-4:0] start_col,  // start memory column in 8-bursts
    output                  [5:0] num128,     // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    output                        start_rd,   // start generating commands in cmd_encod_linear_rd
    output                        start_wr    // start generating commands in cmd_encod_linear_wr
);
    reg                     [2:0] bank_r;     // bank address
    reg      [ADDRESS_NUMBER-1:0] row_r;      // memory row
    reg      [COLADDR_NUMBER-4:0] start_col_r;// start memory column in 8-bursts
    reg                     [5:0] num128_r;   // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    reg                           start_rd_r;    // start generating commands
    reg                           start_wr_r;    // start generating commands

    wire                    [2:0] bank_w;     // bank address
    wire     [ADDRESS_NUMBER-1:0] row_w;      // memory row
    wire     [COLADDR_NUMBER-4:0] start_col_w;// start memory column in 8-bursts
    wire                    [5:0] num128_w;   // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    wire                          start_rd_w;    // start generating commands
    wire                          start_wr_w;    // start generating commands
   
    localparam PAR_WIDTH=3+ADDRESS_NUMBER+COLADDR_NUMBER-3+6+2;
    localparam [PAR_WIDTH-1:0] PAR_DEFAULT=0;
    assign bank =      bank_r;
    assign row =       row_r;
    assign start_col = start_col_r;
    assign num128 =    num128_r;
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
    
    
    assign {bank_w, row_w, start_col_w, num128_w, start_rd_w, start_wr_w} = 0    
`ifdef def_scanline_chn0
            | (start0?{bank0, row0, start_col0, num128_0,CHN_RD_MEM[0],~CHN_RD_MEM[0]}:PAR_DEFAULT)
`endif    
`ifdef def_scanline_chn1
            | (start1?{bank1, row1, start_col1, num128_1,CHN_RD_MEM[1],~CHN_RD_MEM[1]}:PAR_DEFAULT)
`endif    
`ifdef def_scanline_chn2
            | (start2?{bank2, row2, start_col2, num128_2,CHN_RD_MEM[2],~CHN_RD_MEM[2]}:PAR_DEFAULT)
`endif    
`ifdef def_scanline_chn3
            | (start3?{bank3, row3, start_col3, num128_3,CHN_RD_MEM[3],~CHN_RD_MEM[3]}:PAR_DEFAULT)
`endif    
`ifdef def_scanline_chn4
            | (start4?{bank4, row4, start_col4, num128_4,CHN_RD_MEM[4],~CHN_RD_MEM[4]}:PAR_DEFAULT)
`endif    
`ifdef def_scanline_chn5
            | (start5?{bank5, row5, start_col5, num128_5,CHN_RD_MEM[5],~CHN_RD_MEM[5]}:PAR_DEFAULT)
`endif    
`ifdef def_scanline_chn6
            | (start6?{bank6, row6, start_col6, num128_6,CHN_RD_MEM[6],~CHN_RD_MEM[6]}:PAR_DEFAULT)
`endif    
`ifdef def_scanline_chn7
            | (start7?{bank7, row7, start_col7, num128_7,CHN_RD_MEM[7],~CHN_RD_MEM[7]}:PAR_DEFAULT)
`endif    
`ifdef def_scanline_chn8
            | (start8?{bank8, row8, start_col8, num128_8,CHN_RD_MEM[8],~CHN_RD_MEM[8]}:PAR_DEFAULT)
`endif    
`ifdef def_scanline_chn9
            | (start9?{bank9, row9, start_col9, num128_9,CHN_RD_MEM[9],~CHN_RD_MEM[9]}:PAR_DEFAULT)
`endif    
`ifdef def_scanline_chn10
            | (start10?{bank10, row10, start_col10, num128_10,CHN_RD_MEM[10],~CHN_RD_MEM[10]}:PAR_DEFAULT)
`endif    
`ifdef def_scanline_chn11
            | (start11?{bank11, row11, start_col11, num128_11,CHN_RD_MEM[11],~CHN_RD_MEM[11]}:PAR_DEFAULT)
`endif    
`ifdef def_scanline_chn12
            | (start12?{bank12, row12, start_col12, num128_12,CHN_RD_MEM[12],~CHN_RD_MEM[12]}:PAR_DEFAULT)
`endif    
`ifdef def_scanline_chn13
            | (start13?{bank13, row13, start_col13, num128_13,CHN_RD_MEM[13],~CHN_RD_MEM[13]}:PAR_DEFAULT)
`endif    
`ifdef def_scanline_chn14
            | (start14?{bank14, row14, start_col14, num128_14,CHN_RD_MEM[14],~CHN_RD_MEM[14]}:PAR_DEFAULT)
`endif    
`ifdef def_scanline_chn15
            | (start15?{bank15, row15, start_col15, num128_15,CHN_RD_MEM[15],~CHN_RD_MEM[15]}:PAR_DEFAULT)
`endif    
;
    always @ (posedge clk) begin
        if (start_rd_w || start_wr_w) begin
            bank_r <=      bank_w;
            row_r <=       row_w;
            start_col_r <= start_col_w;
            num128_r <=    num128_w;
        end
        start_rd_r <=     start_rd_w;
        start_wr_r <=     start_wr_w;
    end
    

endmodule

