 /*******************************************************************************
 * File: x393_tasks_pio_sequences.vh
 * Date:2015-02-07  
 * Author: Andrey Filippov     
 * Description: Simulation tasks for programming memory transaction
 * sequences (controlles by PS)
 *
 * Copyright (c) 2015 Elphel, Inc.
 * x393_tasks_pio_sequences.vh is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * x393_tasks_pio_sequences.vh is distributed in the hope that it will be useful,
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
task enable_reset_ps_pio; // control reset and enable of the PS PIO channel;
    input en;
    input rst;
    begin
        write_contol_register(MCNTRL_PS_ADDR +  MCNTRL_PS_EN_RST, {30'b0,en,~rst});
    end
endtask

task set_read_block;
    input [ 2:0] ba;
    input [14:0] ra;
    input [ 9:0] ca;
    input        sel;
    reg   [29:0] cmd_addr;
    reg   [31:0] data;
    integer i;
    begin
        cmd_addr <= MCONTR_CMD_WR_ADDR + READ_BLOCK_OFFSET;
// activate
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd( ra[14:0],            ba[2:0],    4,  0,  0,  0,  0,    0,    0,    0,  0,   0,   0,   0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// see if pause is needed . See when buffer read should be started - maybe before WR command
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   1,       0,           0,          0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// first read
// read
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd( {5'b0,ca[9:0]},      ba[2:0],    2,  0,  0, sel, 0,    0,    0,    1,  1,   0,   0,   0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// nop
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       0,       ba[2:0],        0,  0, sel, 0,    0,    0,    1,  1,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
//repeat remaining reads             
        for (i=1;i<64;i=i+1) begin
// read
//                                  addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
            data <=  func_encode_cmd({5'b0,ca[9:0]}+(i<<3),ba[2:0],2,  0,  0,  1,  0,    0,    0,    1,  1,   0,   1,   0);
            @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        end
// nop - all 3 below are the same? - just repeat?
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       0,       ba[2:0],        0,  0, sel, 0,    0,    0,    1,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// nop
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       0,       ba[2:0],        0,  0, sel, 0,    0,    0,    1,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// nop
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       0,       ba[2:0],        0,  0, sel, 0,    0,    0,    1,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// tRTP = 4*tCK is already satisfied, no skip here
// precharge, end of a page (B_RST)         
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd( ra[14:0],            ba[2:0],    5,  0,  0,  0,  0,    0,    0,    1,  0,   0,   0,   1);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   2,       0,          0,           0,  0,  0,  0,    0,    0,    1,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// Turn off DCI, set DONE
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       1,          0,           0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
    end
endtask

task set_write_block;
    input[2:0]ba;
    input[14:0]ra;
    input[9:0]ca;
    input sel;
    reg[29:0] cmd_addr;
    reg[31:0] data;
    integer i;
    begin
        cmd_addr <= MCONTR_CMD_WR_ADDR + WRITE_BLOCK_OFFSET;
// activate
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd( ra[14:0],            ba[2:0],    4,  0,  0,  0,  0,    0,    0,    0,  0,   1,   0,   0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// see if pause is needed . See when buffer read should be started - maybe before WR command
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   1,       0,           0,          0,  0,  0,  0,    0,    0,    0,  0,   1,        0); // tRCD - 2 read bufs
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// first write, 3 rd_buf
// write
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd( {5'b0,ca[9:0]},      ba[2:0],    3,  1,  0, sel, 0,    0,    0,    0,  0,   1,   0,   0); // B_RD moved 1 cycle earlier 
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// nop 4-th rd_buf
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
//      data <=  func_encode_skip(   0,       0,       ba[2:0],        1,  0,  1,  1,    1,    0,    1,  0,   1,        0);
//      data <=  func_encode_skip(   0,       0,       ba[2:0],        1,  0,  0,  1,    1,    0,    0,  0,   1,        0);
        data <=  func_encode_skip(   0,       0,       ba[2:0],        1,  0,  0,  0,    0,    0,    0,  0,   1,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
//repeat remaining writes
        for (i = 1; i < 62; i = i + 1) begin
// write
        //                                add            bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
            data <=  func_encode_cmd( {5'b0,ca[9:0]}+(i<<3),ba[2:0],3, 1,  0, sel, 1,    1,    1,    0,  0,   1,   1,   0); 
            @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        end
        //                                add            bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd( {5'b0,ca[9:0]}+(62<<3),ba[2:0],  3,  1,  0, sel, 1,    1,    1,    0,  0,   1,   0,   0);  // write w/o nop
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// nop
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       0,       ba[2:0],        1,  0, sel, 1,    1,    1,    0,  0,   0,        0); // nop with buffer read off
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        
// One last write pair w/o buffer
        //                                add            bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd( {5'b0,ca[9:0]}+(63<<3),ba[2:0],  3,  1,  0, sel, 1,    1,    1,    0,  0,   0,   1,   0);  // write with nop
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;

// nop
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       0,       ba[2:0],        1,  0,  0,  1,    1,    1,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// nop
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       0,       ba[2:0],        1,  0,  0,  1,    1,    1,    0,  0,   0,        1); // removed B_RD 1 cycle earlier
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// nop
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       0,       ba[2:0],        1,  0,  0,  1,    1,    1,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// ODT off, it has latency
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   2,       0,       ba[2:0],        0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// precharge, ODT off
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd( ra[14:0],            ba[2:0],    5,  0,  0,  0,  0,    0,    0,    0,  0,   0,   0,   0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   2,       0,       ba[2:0],        0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// Finalize, set DONE        
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       1,          0,           0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
    end
endtask


  // Set MR3, read nrep*8 words, save to buffer (port0). No ACTIVATE/PRECHARGE are needed/allowed   
task set_read_pattern; 
    input integer nrep;
//        input [ 2:0] ba;
//        input [14:0] ra;
//        input [ 9:0] ca;
    reg[29:0] cmd_addr;
    reg[31:0] data;
    reg[17:0] mr3_norm;
    reg[17:0] mr3_patt;
    integer i;
    begin
        cmd_addr <= MCONTR_CMD_WR_ADDR + READ_PATTERN_OFFSET;
        
        mr3_norm <= ddr3_mr3(
            1'h0,     //       mpr;    // MPR mode: 0 - normal, 1 - dataflow from MPR
            2'h0);    // [1:0] mpr_rf; // MPR read function: 2'b00: predefined pattern 0101...
        mr3_patt <= ddr3_mr3(
            1'h1,     //       mpr;    // MPR mode: 0 - normal, 1 - dataflow from MPR
            2'h0);    // [1:0] mpr_rf; // MPR read function: 2'b00: predefined pattern 0101...
        @(posedge CLK);
// Set pattern mode
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd(mr3_patt[14:0],  mr3_patt[17:15], 7,  0,  0,  0,  0,    0,    0,    0,  0,   0,   0,   0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   5,       0,           0,          0,  0,  0,  0,    0,    0,    0,  0,   0,        0); // tMOD
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// first read
// read
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd(    0,                   0,       2,  0,  0,  1,  0,    0,    0,    1,  1,   0,   0,   0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// nop (combine with previous?)
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       0,          0,           0,  0,  1,  0,    0,    0,    1,  1,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
//repeat remaining reads
        for (i = 1; i < nrep; i = i + 1) begin
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
            data <=  func_encode_cmd( 0,                  0,       2,  0,  0,  1,  0,    0,    0,    1,  1,   0,   1,   0);
            @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        end
// nop - all 3 below are the same? - just repeat?
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       0,          0,           0,  0,  1,  0,    0,    0,    1,  0,   0,        0); // was BUF WR
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// nop
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       0,          0,           0,  0,  1,  0,    0,    0,    1,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// nop
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       0,          0,           0,  0,  1,  0,    0,    0,    1,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// nop, no write buffer - next page
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       0,          0,           0,  0,  1,  0,    0,    0,    1,  0,   0,        1);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   1,       0,          0,           0,  0,  1,  0,    0,    0,    1,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// Turn off read pattern mode
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd(mr3_norm[14:0],  mr3_norm[17:15], 7,  0,  0,  0,  0,    0,    0,    1,  0,   0,   0,   0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// tMOD (keep DCI enabled)
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   5,       0,          0,           0,  0,  0,  0,    0,    0,    1,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// Turn off DCI
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       0,          0,           0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// Finalize (set DONE)
        data <=  func_encode_skip(   0,       1,          0,           0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
    end
endtask



task set_write_lev;
    input[CMD_PAUSE_BITS-1:0]nrep;
    reg[17:0] mr1_norm;
    reg[17:0] mr1_wlev;
    reg[29:0] cmd_addr;
    reg[31:0] data;
    reg[CMD_PAUSE_BITS-1:0] dqs_low_rpt;
    reg[CMD_PAUSE_BITS-1:0] nrep_minus_1;
    begin
        dqs_low_rpt <= 8;
        nrep_minus_1 <= nrep - 1;
        mr1_norm <= ddr3_mr1(
            1'h0,     //       qoff; // output enable: 0 - DQ, DQS operate in normal mode, 1 - DQ, DQS are disabled
            1'h0,     //       tdqs; // termination data strobe (for x8 devices) 0 - disabled, 1 - enabled
            3'h2,     // [2:0] rtt;  // on-die termination resistance: //  3'b010 - RZQ/2 (120 Ohm)
            1'h0,     //       wlev; // write leveling
            2'h0,     //       ods;  // output drive strength: //  2'b00 - RZQ/6 - 40 Ohm
            2'h0,     // [1:0] al;   // additive latency: 2'b00 - disabled (AL=0)
            1'b0);    //       dll;  // 0 - DLL enabled (normal), 1 - DLL disabled
        mr1_wlev <= ddr3_mr1(
            1'h0,     //       qoff; // output enable: 0 - DQ, DQS operate in normal mode, 1 - DQ, DQS are disabled
            1'h0,     //       tdqs; // termination data strobe (for x8 devices) 0 - disabled, 1 - enabled
            3'h2,     // [2:0] rtt;  // on-die termination resistance: //  3'b010 - RZQ/2 (120 Ohm)
            1'h1,     //       wlev; // write leveling
            2'h0,     //       ods;  // output drive strength: //  2'b00 - RZQ/6 - 40 Ohm
            2'h0,     // [1:0] al;   // additive latency: 2'b00 - disabled (AL=0)
            1'b0);    //       dll;  // 0 - DLL enabled (normal), 1 - DLL disabled
        cmd_addr <= MCONTR_CMD_WR_ADDR + WRITELEV_OFFSET;
// Enter write leveling mode
        @(posedge CLK)
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd(mr1_wlev[14:0],  mr1_wlev[17:15], 7,  0,  0,  0,  0,    0,    0,    0,  0,   0,   0,   0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(  13,       0,           0,          0,  0,  0,  0,    0,    0,    0,  0,   0,        0); // tWLDQSEN=25tCK
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// enable DQS output, keep it low (15 more tCK for the total of 40 tCK
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(dqs_low_rpt, 0,         0,           1,  0,  0,  0,    1,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// Toggle DQS as needed for write leveling, write to buffer
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(nrep_minus_1,0,         0,           1,  0,  0,  0,    1,    1,    1,  1,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// continue toggling (5 times), but disable writing to buffer (used same wbuf latency as for read) 
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(  4,        0,         0,            1,  0,  0,  0,    1,    1,    1,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        // Keep DCI (but not ODT) active  ODT should be off befor MRS
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(  2,        0,         0,            0,  0,  0,  0,    0,    0,    1,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        // exit write leveling mode, ODT off, DCI off
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd(mr1_norm[14:0],  mr1_norm[17:15], 7,  0,  0,  0,  0,    0,    0,    0,  0,   0,   0,   0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(  5,        0,         0,            0,  0,  0,  0,    0,    0,    0,  0,   0,        0); // tMOD
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        // Finalize. See if DONE can be combined with B_RST, if not - insert earlier
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       1,           0,          0,  0,  0,  0,    0,    0,    0,  0,   0,        1); // can DONE be combined with B_RST?
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
    end
endtask

task set_refresh;
    input[9:0]t_rfc; // =50 for tCK=2.5ns
    input[7:0]t_refi; // 48/97 for normal, 8 - for simulation
    reg[29:0] cmd_addr;
    reg[31:0] data;
    begin
        cmd_addr <= MCONTR_CMD_WR_ADDR + REFRESH_OFFSET;
        @(posedge CLK)
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd(    0,                   0,       6,  0,  0,  0,  0,    0,    0,    0,  0,   0,   0,   0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        // =50 tREFI=260 ns before next ACTIVATE or REFRESH, @2.5ns clock, @5ns cycle
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip( t_rfc,      0,           0,          0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// Ready for normal operation
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       1,           0,          0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
//            write_contol_register(DLY_SET,0);
        write_contol_register(MCONTR_TOP_16BIT_ADDR + MCONTR_TOP_16BIT_REFRESH_ADDRESS, REFRESH_OFFSET);
        write_contol_register(MCONTR_TOP_16BIT_ADDR + MCONTR_TOP_16BIT_REFRESH_PERIOD, {24'h0,t_refi});
        // enable refresh - should it be done here?
//        write_contol_register(MCONTR_PHY_0BIT_ADDR +  MCONTR_TOP_0BIT_REFRESH_EN + 1, 0);
    end
endtask         

task set_mrs; // will also calibrate ZQ
    input reset_dll;
    reg[17:0] mr0;
    reg[17:0] mr1;
    reg[17:0] mr2;
    reg[17:0] mr3;
    reg[29:0] cmd_addr;
    reg[31:0] data;
    begin
        mr0 <= ddr3_mr0(
            1'h0,      //       pd; // precharge power down 0 - dll off (slow exit), 1 - dll on (fast exit)
            3'h2,      // [2:0] wr; // write recovery (encode ceil(tWR/tCK)) // 3'b010:  6
            reset_dll, //       dll_rst; // 1 - dll reset (self clearing bit)
            4'h4,      // [3:0] cl; // CAS latency: // 0100:  6 (time 15ns)
            1'h0,      //       bt; // read burst type: 0 sequential (nibble), 1 - interleave
            2'h0);       // [1:0] bl; // burst length: // 2'b00 - fixed BL8

        mr1 <= ddr3_mr1(
            1'h0,     //       qoff; // output enable: 0 - DQ, DQS operate in normal mode, 1 - DQ, DQS are disabled
            1'h0,     //       tdqs; // termination data strobe (for x8 devices) 0 - disabled, 1 - enabled
            3'h2,     // [2:0] rtt;  // on-die termination resistance: //  3'b010 - RZQ/2 (120 Ohm)
            1'h0,     //       wlev; // write leveling
            2'h0,     //       ods;  // output drive strength: //  2'b00 - RZQ/6 - 40 Ohm
            2'h0,     // [1:0] al;   // additive latency: 2'b00 - disabled (AL=0)
            1'b0);    //       dll;  // 0 - DLL enabled (normal), 1 - DLL disabled

        mr2 <= ddr3_mr2(
            2'h0,     // [1:0] rtt_wr; // Dynamic ODT : //  2'b00 - disabled, 2'b01 - RZQ/4 = 60 Ohm, 2'b10 - RZQ/2 = 120 Ohm
            1'h0,     //       srt;    // Self-refresh temperature 0 - normal (0-85C), 1 - extended (<=95C)
            1'h0,     //       asr;    // Auto self-refresh 0 - disabled (manual), 1 - enabled (auto)
            3'h0);    // [2:0] cwl;    // CAS write latency:3'b000  5CK (tCK >= 2.5ns), 3'b001  6CK (1.875ns <= tCK < 2.5ns)

        mr3 <= ddr3_mr3(
            1'h0,     //       mpr;    // MPR mode: 0 - normal, 1 - dataflow from MPR
            2'h0);    // [1:0] mpr_rf; // MPR read function: 2'b00: predefined pattern 0101...
        cmd_addr <= MCONTR_CMD_WR_ADDR + INITIALIZE_OFFSET;
        @(posedge CLK)
        $display("mr0=0x%x", mr0);
        $display("mr1=0x%x", mr1);
        $display("mr2=0x%x", mr2);
        $display("mr3=0x%x", mr3);
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd(mr2[14:0],          mr2[17:15],   7,  0,  0,  0,  0,    0,    0,    0,  0,   0,   0,   0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(    1,      0,           0,          0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd(mr3[14:0],          mr3[17:15],   7,  0,  0,  0,  0,    0,    0,    0,  0,   0,   0,   0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(    0,      0,           0,          0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd(mr1[14:0],          mr1[17:15],   7,  0,  0,  1,  0,    0,    0,    0,  0,   0,   0,   0); // SEL==1 - just testing?
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(    2,      0,           0,          0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd(mr0[14:0],          mr0[17:15],   7,  0,  0,  0,  0,    0,    0,    0,  0,   0,   0,   0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(    5,      0,           0,          0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        // encode ZQCL:
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd(15'h400,                 0,       1,  0,  0,  0,  0,    0,    0,    0,  0,   0,   0,   0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        // 512 clock cycles after ZQCL
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(  256,      0,           0,          0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        // sequence done bit, skip length is ignored
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   10,      1,           0,          0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
    end
endtask

    function [ADDRESS_NUMBER+2:0] ddr3_mr0;
        input       pd; // precharge power down 0 - dll off (slow exit), 1 - dll on (fast exit) 
        input [2:0] wr; // write recovery:
                        // 3'b000: 16
                        // 3'b001:  5
                        // 3'b010:  6
                        // 3'b011:  7
                        // 3'b100:  8
                        // 3'b101: 10
                        // 3'b110: 12
                        // 3'b111: 14
        input       dll_rst; // 1 - dll reset (self clearing bit)
        input [3:0] cl; // CAS latency (>=15ns):
                        // 0000: reserved                   
                        // 0010:  5                   
                        // 0100:  6                   
                        // 0110:  7                 
                        // 1000:  8                 
                        // 1010:  9                 
                        // 1100: 10                   
                        // 1110: 11                   
                        // 0001: 12                  
                        // 0011: 13                  
                        // 0101: 14
        input       bt; // read burst type: 0 sequential (nibble), 1 - interleaved
        input [1:0] bl; // burst length:
                        // 2'b00 - fixed BL8
                        // 2'b01 - 4 or 8 on-the-fly by A12                                     
                        // 2'b10 - fixed BL4 (chop)
                        // 2'b11 - reserved
        begin
          ddr3_mr0 = {
              3'b0,
              {ADDRESS_NUMBER-13{1'b0}},
              pd,       // MR0.12 
              wr,       // MR0.11_9
              dll_rst,  // MR0.8
              1'b0,     // MR0.7
              cl[3:1],  // MR0.6_4
              bt,       // MR0.3
              cl[0],    // MR0.2
              bl[1:0]}; // MR0.1_0
        end
    
    endfunction
    
    function [ADDRESS_NUMBER+2:0] ddr3_mr1;
        input       qoff; // output enable: 0 - DQ, DQS operate in normal mode, 1 - DQ, DQS are disabled
        input       tdqs; // termination data strobe (for x8 devices) 0 - disabled, 1 - enabled
        input [2:0] rtt;  // on-die termination resistance:
                          //  3'b000 - disabled
                          //  3'b001 - RZQ/4 (60 Ohm)
                          //  3'b010 - RZQ/2 (120 Ohm)
                          //  3'b011 - RZQ/6 (40 Ohm)
                          //  3'b100 - RZQ/12(20 Ohm)
                          //  3'b101 - RZQ/8 (30 Ohm)
                          //  3'b11x - reserved
        input       wlev; // write leveling
        input [1:0] ods;  // output drive strength:
                          //  2'b00 - RZQ/6 - 40 Ohm
                          //  2'b01 - RZQ/7 - 34 Ohm
                          //  2'b1x - reserved
        input [1:0] al;   // additive latency:
                          //  2'b00 - disabled (AL=0)
                          //  2'b01 - AL=CL-1;
                          //  2'b10 - AL=CL-2
                          //  2'b11 - reserved
        input       dll;  // 0 - DLL enabled (normal), 1 - DLL disabled
        begin
            ddr3_mr1 = {
              3'h1,
              {ADDRESS_NUMBER-13{1'b0}},
              qoff,       // MR1.12 
              tdqs,       // MR1.11
              1'b0,       // MR1.10
              rtt[2],     // MR1.9
              1'b0,       // MR1.8
              wlev,       // MR1.7 
              rtt[1],     // MR1.6 
              ods[1],     // MR1.5 
              al[1:0],    // MR1.4_3 
              rtt[0],     // MR1.2 
              ods[0],     // MR1.1 
              dll};       // MR1.0 
        end                            
    endfunction

    function [ADDRESS_NUMBER+2:0] ddr3_mr2;
        input [1:0] rtt_wr; // Dynamic ODT :
                            //  2'b00 - disabled
                            //  2'b01 - RZQ/4 = 60 Ohm
                            //  2'b10 - RZQ/2 = 120 Ohm
                            //  2'b11 - reserved
        input       srt;    // Self-refresh temperature 0 - normal (0-85C), 1 - extended (<=95C)
        input       asr;    // Auto self-refresh 0 - disabled (manual), 1 - enabled (auto)
        input [2:0] cwl;    // CAS write latency:
                            //  3'b000  5CK (           tCK >= 2.5ns)  
                            //  3'b001  6CK (1.875ns <= tCK < 2.5ns)  
                            //  3'b010  7CK (1.5ns   <= tCK < 1.875ns)  
                            //  3'b011  8CK (1.25ns  <= tCK < 1.5ns)  
                            //  3'b100  9CK (1.071ns <= tCK < 1.25ns)  
                            //  3'b101 10CK (0.938ns <= tCK < 1.071ns)  
                            //  3'b11x reserved  
        begin
            ddr3_mr2 = {
              3'h2,
              {ADDRESS_NUMBER-11{1'b0}},
              rtt_wr[1:0], // MR2.10_9
              1'b0,        // MR2.8
              srt,         // MR2.7
              asr,         // MR2.6
              cwl[2:0],    // MR2.5_3
              3'b0};       // MR2.2_0 
        end                            
    endfunction
        
    function [ADDRESS_NUMBER+2:0] ddr3_mr3;
        input       mpr;    // MPR mode: 0 - normal, 1 - dataflow from MPR
        input [1:0] mpr_rf; // MPR read function:
                            //  2'b00: predefined pattern 0101...
                            //  2'b1x, 2'bx1 - reserved
        begin
            ddr3_mr3 = {
              3'h3,
              {ADDRESS_NUMBER-3{1'b0}},
              mpr,          // MR3.2
              mpr_rf[1:0]}; // MR3.1_0 
        end                            
    endfunction
