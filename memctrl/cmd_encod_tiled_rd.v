/*******************************************************************************
 * Module: cmd_encod_tiled_rd
 * Date:2015-01-23  
 * Author: andrey     
 * Description: Command sequencer generator for reading a tiled aread
 * up to 1 kB. Memory is mapped so 8 consecuitive rows have same RA, CA
 * and alternating BA (0 to 7). Data will be read in columns 16 bytes wide,
 * then proceding to the next column (if >1).
 * If number of rows is less than 8 it is possible to use keep_open_in input,
 * then there will be no ACTIVATE in other than first column and 
 * AUTO RECHARGE will be applied only to the last column (single column OK).
 * if number of rows >=8, that port is ignored. If number of rows is less than
 * 5 (less for slower clock) without keep_open_in tRTP may be not matched.
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * cmd_encod_tiled_rd.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  cmd_encod_tiled_rd.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  cmd_encod_tiled_rd #(
//    parameter BASEADDR = 0,
    parameter ADDRESS_NUMBER=       15,
    parameter COLADDR_NUMBER=       10,
//    parameter MIN_COL_INC=           3, // minimal number of zero column bits when incrementing row (after bank)  
    parameter CMD_PAUSE_BITS=       10,
    parameter CMD_DONE_BIT=         10,  // VDT BUG: CMD_DONE_BIT is used in a function call parameter!
    parameter FRAME_WIDTH_BITS=     13  // Maximal frame width - 8-word (16 bytes) bursts 
    
) (
    input                        rst,
    input                        clk,
// programming interface
//    input                  [7:0] cmd_ad,      // byte-serial command address/data (up to 6 bytes: AL-AH-D0-D1-D2-D3 
//    input                        cmd_stb,     // strobe (with first byte) for the command a/d
    input                  [2:0] start_bank,    // bank address
    input   [ADDRESS_NUMBER-1:0] start_row,     // memory row
    input   [COLADDR_NUMBER-4:0] start_col,     // start memory column in 8-bit bursts 
//    input [ADDRESS_NUMBER+COLADDR_NUMBER-4:0] rowcol_inc_in, // increment {row.col} when bank rolls over, removed 3 LSBs (in 8-bursts)
    input [FRAME_WIDTH_BITS:0] rowcol_inc_in, // increment {row.col} when bank rolls over, removed 3 LSBs (in 8-bursts)
    input                  [5:0] num_rows_in_m1,   // number of rows to read minus 1
    input                  [5:0] num_cols_in_m1,   // number of 16-pixel columns to read (rows first, then columns) - 1
    input                        keep_open_in,  // keep banks open (for <=8 banks only
    input                        skip_next_page_in, // do not reset external buffer (continue)    
    input                        start,       // start generating commands
    output reg            [31:0] enc_cmd,     // encoded commnad
    output reg                   enc_wr,      // write encoded command
    output reg                   enc_done     // encoding finished
);
    localparam FULL_ADDR_NUMBER=ADDRESS_NUMBER+COLADDR_NUMBER; // excluding 3 CA lsb, but adding 3 bank
    localparam ROM_WIDTH=10;
    localparam ROM_DEPTH=4;
    
    localparam ENC_NOP=        0;
    localparam ENC_BUF_WR=     1;
    localparam ENC_DCI=        2;
    localparam ENC_SEL=        3;
    localparam ENC_CMD_SHIFT=  4; // [5:4] - command: 0 -= NOP, 1 - READ, 2 - PRECHARGE, 3 - ACTIVATE
    localparam ENC_PAUSE_SHIFT=6; // [7:6] - 2- bit pause (for NOP commandes)
    localparam ENC_PRE_DONE=   8;
    localparam ENC_BUF_PGNEXT=    9;
    
    localparam ENC_CMD_NOP=      0; // 2-bit locally encoded commands
    localparam ENC_CMD_READ=     1;
//    localparam ENC_CMD_PRECHARGE=2;
    localparam ENC_CMD_ACTIVATE= 2; // using autoprecharge, so no PRECHARGE is needed. When en_act==0, ENC_CMD_ACTIVATE-> ENC_CMD_NOP (delay should be 0)
//    localparam REPEAT_ADDR=3;
    localparam LOOP_FIRST=   5; // address of the first word in a loop
    localparam LOOP_LAST=    6; // address of the last word in a loop
    localparam CMD_NOP=      0; // 3-bit normal memory RCW commands (positive logic)
    localparam CMD_READ=     3;
//    localparam CMD_PRECHARGE=5;
    localparam CMD_ACTIVATE= 4;
//    localparam AUTOPRECHARGE_BIT=COLADDR_NUMBER;
    
    reg   [ADDRESS_NUMBER-1:0] row;     // memory row
    reg   [COLADDR_NUMBER-4:0] col;     // start memory column in 8-bursts
    reg                  [2:0] bank;    // memory bank;
    reg                  [5:0] num_rows_m1;  // number of rows in a tile minus 1
    reg                  [5:0] num_cols128_m1;  // number of r16-byte columns in a tile  -1
//    reg  [FULL_ADDR_NUMBER-4:0] rowcol_inc; // increment {row.col} when bank rolls over, remove 3 LSBs (in 8-bursts)
    reg   [FRAME_WIDTH_BITS:0] rowcol_inc; // increment {row.col} when bank rolls over, remove 3 LSBs (in 8-bursts)
    
    reg                        keep_open;                        
    reg                        skip_next_page;
    reg                        gen_run;
    reg                        gen_run_d;
    reg        [ROM_DEPTH-1:0] gen_addr; // will overrun as stop comes from ROM
    
    reg        [ROM_WIDTH-1:0] rom_r; 
    wire                       pre_done;
    wire                 [1:0] rom_cmd;
    wire                 [1:0] rom_skip;
    wire                 [2:0] full_cmd;
    reg                        done;
    
    reg [FULL_ADDR_NUMBER-4:0] top_rc; // top combined row,column,bank burst address (excludes 3 CA LSBs), valid/modified @pre_act
    reg                        first_col;
    reg                        last_col;
    wire                       pre_act; //1 cycle before optional ACTIVATE
    wire                       pre_read; //1 cycle before READ command
    reg                  [5:0] scan_row; // current row in a tile (valid @pre_act)
    reg                  [5:0] scan_col; // current 16-byte column in a tile (valid @pre_act)
    reg                        start_d; // start, delayed by 1 clocks
    wire                       last_row;
    reg [FULL_ADDR_NUMBER-1:0] row_col_bank;     // RA,CA, BA - valid @pre_act;
    reg [FULL_ADDR_NUMBER-1:0] row_col_bank_inc; // incremented RA,CA, BA - valid @pre_act_d;
    reg   [COLADDR_NUMBER-1:0] col_bank;// CA, BA - valid @ pre_read; 
    
    wire                       enable_act;
//    wire                       enable_autopre;
    reg                       enable_autopre;
    
    reg                        pre_act_d;
    reg                        other_row; // other than first row (valid/changed @pre_act)
    wire                 [2:0] next_bank_w;
    wire [ADDRESS_NUMBER+COLADDR_NUMBER-4:0] next_rowcol_w; // next row/col when bank rolls over (in 8-bursts)
    
    reg                        loop_continue;
    reg                        last_col_d; // delay by 1 pre_act cycles;
    

    assign     pre_done=rom_r[ENC_PRE_DONE] && gen_run;
    assign     rom_cmd=  rom_r[ENC_CMD_SHIFT+:2] & {enable_act,1'b0}; // disable bit 1 if activate is disabled (not the first column)
    assign     rom_skip= rom_r[ENC_PAUSE_SHIFT+:2];
    assign     full_cmd= rom_cmd[1]?CMD_ACTIVATE:(rom_cmd[0]?CMD_READ:CMD_NOP);
    
    assign last_row=       (scan_row==num_rows_m1);
    assign enable_act=     first_col || !keep_open; // TODO: do not forget to zero addresses too (or they will become pause/done)
    assign next_bank_w=    bank+1;
    assign next_rowcol_w=row_col_bank[FULL_ADDR_NUMBER-1:3]+rowcol_inc;
    
    assign pre_act=        rom_r[ENC_CMD_SHIFT+1]; //1 cycle before optional ACTIVATE
    assign pre_read=       rom_r[ENC_CMD_SHIFT]; //1 cycle before READ command
    
//TODO:Add AUTOPRECHARGE + ACTIVATE when column crossed - No, caller should make sure there is no row address change in the same line   
    
    always @ (posedge rst or posedge clk) begin
        if (rst)           gen_run <= 0;
        else if (start)    gen_run<= 1;
        else if (pre_done) gen_run<= 0;
        
        if (rst)           gen_run_d <= 0;
        else               gen_run_d <= gen_run;

        if (rst)        num_rows_m1 <= 0;                    
        else if (start) num_rows_m1 <= num_rows_in_m1;  // number of rows
        if (rst)        num_cols128_m1 <= 0;
        else if (start)         num_cols128_m1 <= num_cols_in_m1;  // number of r16-byte columns
        
        if (rst)         start_d <=0;
        else             start_d <=  start;
        
        if (rst)                      top_rc <= 0;
        else if (start_d)             top_rc <= {row,col};
        else if (pre_act && last_row) top_rc <= top_rc+1; // may increment RA  
        
        if (rst)                      pre_act_d <= 0;
        else if (start_d)             pre_act_d <= 0;
        else                          pre_act_d <= pre_act;
        
        if (rst)                      other_row <= 0;
        else if (pre_act)             other_row <= ~last_row;
        
        if (rst)                          row_col_bank <= 0;
        else if (start_d)                 row_col_bank <= {row,col,bank};
        else if (pre_act_d && ~other_row) row_col_bank <= {top_rc,bank};
        else if (pre_act_d)               row_col_bank <= row_col_bank_inc; 
        
        if (rst)    row_col_bank_inc<=0;
        else        row_col_bank_inc<=(&row_col_bank_inc[2:0]!=0)?
                                      {row_col_bank_inc[FULL_ADDR_NUMBER-1:3],next_bank_w}:
                                      {next_rowcol_w,row_col_bank_inc[2:0]};  

        if (rst)                      scan_row <= 0;
        else if (start_d)             scan_row <= 0;
        else if (pre_act)             scan_row <= last_row?0:scan_row+1;
        
        if (rst)                      scan_col <= 0;
        else if (start_d)             scan_col <= 0;
        else if (pre_act && last_row) scan_col <= scan_col+1; // for ACTIVATE, not for READ

        if (rst)                      first_col <= 0;
        else if (start_d)             first_col <= 1;
        else if (pre_act && last_row) first_col  <= 0;

        if (rst)                      last_col <= 0;
        else if (start_d)             last_col <= num_cols128_m1==0; // if single column - will start with 1'b1;
        else if (pre_act)             last_col <= (scan_col==num_cols128_m1); // too early for READ ?

        if (rst)                      last_col_d <= 0;
        else if (start_d)             last_col_d <= 0;
        else if (pre_act)             last_col_d <= last_col;

        if (rst)                      enable_autopre <= 0;
        else if (start_d)             enable_autopre <= 0;
        else if (pre_act)             enable_autopre <=  last_col_d || !keep_open; // delayed by 2 pre_act tacts form last_col, OK with a single column
        
        if (rst)                      col_bank<=0;
        else if (start_d)             col_bank<= {col,bank};
        else if (pre_read)            col_bank<= row_col_bank[COLADDR_NUMBER-1:0];
        
        if (rst)     loop_continue<=0;
        else loop_continue <=  (scan_col==num_cols128_m1) && last_row;                 
        
        if (rst)                     gen_addr <= 0;
        else if (!start && !gen_run) gen_addr <= 0;
        else if ((gen_addr==LOOP_LAST) && !loop_continue) gen_addr <= LOOP_FIRST; // skip loop alltogeter
        else                         gen_addr <= gen_addr+1; // not in a loop
    end
    
    always @ (posedge clk) if (start) begin
        row<=start_row;
        col <= start_col;
        bank <= start_bank;
        rowcol_inc <= rowcol_inc_in;
        keep_open <= keep_open_in && (|num_cols_in_m1[5:3]!=0);
        skip_next_page <= skip_next_page_in;
    end
    
    // ROM-based (registered output) encoded sequence
    always @ (posedge rst or posedge clk) begin
        if (rst)           rom_r <= 0;
        else case (gen_addr)
            4'h0:  rom_r <= (ENC_CMD_ACTIVATE <<  ENC_CMD_SHIFT)  | (1 << ENC_NOP);
            4'h1:  rom_r <= (ENC_CMD_ACTIVATE <<  ENC_CMD_SHIFT); 
            4'h2:  rom_r <= (ENC_CMD_READ <<      ENC_CMD_SHIFT)                                              | (1 << ENC_DCI) | (1 << ENC_SEL); 
            4'h3:  rom_r <= (ENC_CMD_ACTIVATE <<  ENC_CMD_SHIFT)                                              | (1 << ENC_DCI) | (1 << ENC_SEL); 
            4'h4:  rom_r <= (ENC_CMD_READ <<      ENC_CMD_SHIFT)                          | (1 << ENC_BUF_WR) | (1 << ENC_DCI) | (1 << ENC_SEL); 
            4'h5:  rom_r <= (ENC_CMD_ACTIVATE <<  ENC_CMD_SHIFT)                          | (1 << ENC_BUF_WR) | (1 << ENC_DCI) | (1 << ENC_SEL); 
            4'h6:  rom_r <= (ENC_CMD_READ <<      ENC_CMD_SHIFT)                          | (1 << ENC_BUF_WR) | (1 << ENC_DCI) | (1 << ENC_SEL); 
            4'h7:  rom_r <= (ENC_CMD_NOP <<       ENC_CMD_SHIFT)                          | (1 << ENC_BUF_WR) | (1 << ENC_DCI) | (1 << ENC_SEL); 
            4'h8:  rom_r <= (ENC_CMD_READ <<      ENC_CMD_SHIFT)                          | (1 << ENC_BUF_WR) | (1 << ENC_DCI) | (1 << ENC_SEL); 
            4'h9:  rom_r <= (ENC_CMD_NOP <<       ENC_CMD_SHIFT) | (2 << ENC_PAUSE_SHIFT) | (1 << ENC_BUF_WR) | (1 << ENC_DCI) | (1 << ENC_SEL); 
            4'ha: rom_r <= (ENC_CMD_NOP <<       ENC_CMD_SHIFT) | (1 << ENC_DCI) | (1 << ENC_SEL) | (skip_next_page? 1'b0:(1 << ENC_BUF_PGNEXT)); 
            4'hb: rom_r <= (ENC_CMD_NOP <<       ENC_CMD_SHIFT) | (3 << ENC_PAUSE_SHIFT)                     | (1 << ENC_DCI);
            4'hc: rom_r <= (ENC_CMD_NOP <<       ENC_CMD_SHIFT) | (1 << ENC_PRE_DONE);
            default:rom_r <= 0;
       endcase
    end
    always @ (posedge rst or posedge clk) begin
        if (rst)           done <= 0;
        else               done <= pre_done;
        
        if (rst)           enc_wr <= 0;
        else               enc_wr <= gen_run || gen_run_d;
        
        if (rst)           enc_done <= 0;
        else               enc_done <= enc_wr || !gen_run_d;
        
        if (rst)             enc_cmd <= 0;
        else if (rom_cmd==0) enc_cmd <= func_encode_skip ( // encode pause
            {{CMD_PAUSE_BITS-2{1'b0}},rom_skip[1:0]}, // skip;   // number of extra cycles to skip (and keep all the other outputs)
            done,                                     // end of sequence 
            3'b0,                    // bank (here OK to be any)
            1'b0,                    //   odt_en;     // enable ODT
            1'b0,                    //   cke;        // disable CKE
            rom_r[ENC_SEL],          //   sel;        // first/second half-cycle, other will be nop (cke+odt applicable to both)
            1'b0,                    //   dq_en;      // enable (not tristate) DQ  lines (internal timing sequencer for 0->1 and 1->0)
            1'b0,                    //   dqs_en;     // enable (not tristate) DQS lines (internal timing sequencer for 0->1 and 1->0)
            1'b0,                    //   dqs_toggle; // enable toggle DQS according to the pattern
            rom_r[ENC_DCI],          //   dci;        // DCI disable, both DQ and DQS lines (internal logic and timing sequencer for 0->1 and 1->0)
            rom_r[ENC_BUF_WR],       //   buf_wr;     // connect to external buffer (but only if not paused)
            1'b0,                    //   buf_rd;     // connect to external buffer (but only if not paused)
            rom_r[ENC_BUF_PGNEXT]);     //   buf_rst;    // connect to external buffer (but only if not paused)
       else  enc_cmd <= func_encode_cmd ( // encode non-NOP command
            rom_cmd[1]? // activate
            row_col_bank[FULL_ADDR_NUMBER-1:COLADDR_NUMBER]: // top combined row,column,bank burst address (excludes 3 CA LSBs), valid/modified @pre_act
                    {{ADDRESS_NUMBER-COLADDR_NUMBER-1{1'b0}},
                        enable_autopre,
                        col_bank[COLADDR_NUMBER-1:3],
                        3'b0}, //  [14:0] addr;       // 15-bit row/column adderss
            rom_cmd[1]?
                row_col_bank[2:0]:
                col_bank[2:0],        // bank (here OK to be any)
            full_cmd[2:0],           //   rcw;        // RAS/CAS/WE, positive logic
            1'b0,                    //   odt_en;     // enable ODT
            1'b0,                    //   cke;        // disable CKE
            rom_r[ENC_SEL],          //   sel;        // first/second half-cycle, other will be nop (cke+odt applicable to both)
            1'b0,                    //   dq_en;      // enable (not tristate) DQ  lines (internal timing sequencer for 0->1 and 1->0)
            1'b0,                    //   dqs_en;     // enable (not tristate) DQS lines (internal timing sequencer for 0->1 and 1->0)
            1'b0,                    //   dqs_toggle; // enable toggle DQS according to the pattern
            rom_r[ENC_DCI],          //   dci;        // DCI disable, both DQ and DQS lines (internal logic and timing sequencer for 0->1 and 1->0)
            rom_r[ENC_BUF_WR],       //   buf_wr;     // connect to external buffer (but only if not paused)
            1'b0,                    //   buf_rd;     // connect to external buffer (but only if not paused)     
            rom_r[ENC_NOP],          //   nop;        // add NOP after the current command, keep other data
            rom_r[ENC_BUF_PGNEXT]);     //   buf_rst;    // connect to external buffer (but only if not paused)
    end    

// move to include?, Yes, after fixing problem with paths
// move to include?
`include "includes/x393_mcontr_encode_cmd.vh" 
/*
    function [31:0] func_encode_skip;
        input [CMD_PAUSE_BITS-1:0] skip;       // number of extra cycles to skip (and keep all the other outputs)
        input                      done;       // end of sequence 
        input [2:0]                bank;       // bank (here OK to be any)
        input                      odt_en;     // enable ODT
        input                      cke;        // disable CKE
        input                      sel;        // first/second half-cycle, other will be nop (cke+odt applicable to both)
        input                      dq_en;      // enable (not tristate) DQ  lines (internal timing sequencer for 0->1 and 1->0)
        input                      dqs_en;     // enable (not tristate) DQS lines (internal timing sequencer for 0->1 and 1->0)
        input                      dqs_toggle; // enable toggle DQS according to the pattern
        input                      dci;        // DCI disable, both DQ and DQS lines (internal logic and timing sequencer for 0->1 and 1->0)
        input                      buf_wr;     // connect to external buffer (but only if not paused)
        input                      buf_rd;     // connect to external buffer (but only if not paused)
        input                      buf_rst;    // connect to external buffer (but only if not paused)
        begin
            func_encode_skip= func_encode_cmd (
                {{14-CMD_DONE_BIT{1'b0}}, done, skip[CMD_PAUSE_BITS-1:0]},       // 15-bit row/column adderss
                bank[2:0],  // bank (here OK to be any)
                3'b0,       // RAS/CAS/WE, positive logic
                odt_en,     // enable ODT
                cke,        // disable CKE
                sel,        // first/second half-cycle, other will be nop (cke+odt applicable to both)
                dq_en,      // enable (not tristate) DQ  lines (internal timing sequencer for 0->1 and 1->0)
                dqs_en,     // enable (not tristate) DQS lines (internal timing sequencer for 0->1 and 1->0)
                dqs_toggle, // enable toggle DQS according to the pattern
                dci,        // DCI disable, both DQ and DQS lines (internal logic and timing sequencer for 0->1 and 1->0)
                buf_wr,     // connect to external buffer (but only if not paused)
                buf_rd,     // connect to external buffer (but only if not paused)
                1'b0,       // nop
                buf_rst);
        end
    endfunction

    function [31:0] func_encode_cmd;
        input               [14:0] addr;       // 15-bit row/column adderss
        input                [2:0] bank;       // bank (here OK to be any)
        input                [2:0] rcw;        // RAS/CAS/WE, positive logic
        input                      odt_en;     // enable ODT
        input                      cke;        // disable CKE
        input                      sel;        // first/second half-cycle, other will be nop (cke+odt applicable to both)
        input                      dq_en;      // enable (not tristate) DQ  lines (internal timing sequencer for 0->1 and 1->0)
        input                      dqs_en;     // enable (not tristate) DQS lines (internal timing sequencer for 0->1 and 1->0)
        input                      dqs_toggle; // enable toggle DQS according to the pattern
        input                      dci;        // DCI disable, both DQ and DQS lines (internal logic and timing sequencer for 0->1 and 1->0)
        input                      buf_wr;     // connect to external buffer (but only if not paused)
        input                      buf_rd;     // connect to external buffer (but only if not paused)
        input                      nop;        // add NOP after the current command, keep other data
        input                      buf_rst;    // connect to external buffer (but only if not paused)
        begin
            func_encode_cmd={
            addr[14:0], // 15-bit row/column adderss
            bank [2:0], // bank
            rcw[2:0],   // RAS/CAS/WE
            odt_en,     // enable ODT
            cke,        // may be optimized (removed from here)?
            sel,        // first/second half-cycle, other will be nop (cke+odt applicable to both)
            dq_en,      // enable (not tristate) DQ  lines (internal timing sequencer for 0->1 and 1->0)
            dqs_en,     // enable (not tristate) DQS  lines (internal timing sequencer for 0->1 and 1->0)
            dqs_toggle, // enable toggle DQS according to the pattern
            dci,        // DCI disable, both DQ and DQS lines (internal logic and timing sequencer for 0->1 and 1->0)
            buf_wr,     // phy_buf_wr,   // connect to external buffer (but only if not paused)
            buf_rd,     // phy_buf_rd,    // connect to external buffer (but only if not paused)
            nop,        // add NOP after the current command, keep other data
            buf_rst     // Reserved for future use
           };
        end
    endfunction
*/
endmodule

