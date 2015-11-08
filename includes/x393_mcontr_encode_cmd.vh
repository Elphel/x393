/*******************************************************************************
 * File: x393_mcontr_encode_cmd.vh
 * Date:2015-02-09  
 * Author: Andrey Filippov     
 * Description: Functions used to encode memory controller sequences
 *
 * Copyright (c) 2015 Elphel, Inc.
 * x393_mcontr_encode_cmd.vh is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * x393_mcontr_encode_cmd.vh is distributed in the hope that it will be useful,
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
 *******************************************************************************/

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
                {{14-CMD_DONE_BIT{1'b0}}, done, skip[CMD_PAUSE_BITS-1:0]},       // 15-bit row/column address
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
        input               [14:0] addr;       // 15-bit row/column address
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
            addr[14:0], // 15-bit row/column address
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
 
