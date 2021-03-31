/*!
 * <b>Module:</b> drp_mmcm_pll
 * @file drp_mmcm_pll.v
 * @date 2021-03-29  
 * @author eyesis
 *     
 * @brief MMCME2/PLLE2 DRP control 
 *
 * @copyright Copyright (c) 2021 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 *
 * <b>License </b>
 *
 * drp_mmcm_pll.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * drp_mmcm_pll.v is distributed in the hope that it will be useful,
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
 */
`timescale 1ns/1ps

/*
Read operation:
Shift 7 address bits (may ignore responses, just maintain expected out_odd_bit), big endian (MSB first)
Send "execute" (after 7 bits)
Wait for flipping of out_odd_bit (out_bit will not change, ignore it)
read 16 bit of data by
 - shifting 0 (or 1);
 - waiting for flipping of out_odd_bit
 - reading out_bit (big endian, MSB first)
issue "execute" - will just reset state machine to inoitial state (as there were 16 - not 7 or 23 bits)

Write operation
Shift 7 address bits and 16 data bits (23 total) (may ignore responses, just maintain expected out_odd_bit), big endian (MSB first)
Send execute (after 23 bits)
 - waiting for flipping of out_odd_bit (in response to the 24 bit sent), out_bit will not change, ignore it
 
 Use mclk as DCLK
*/

module  drp_mmcm_pll#(
    parameter DRP_ADDRESS_LENGTH = 7,
    parameter DRP_DATA_LENGTH =    16
    )(
    // host interface
        input                           dclk,
        input                           mmcm_rst,   // this module is reset by mmcm_rst=0
        input                     [1:0] cmd,        // 0 - NOP, 1 - shift 0, 2 - shift 1, 3 - execute 
        output                          out_bit,    // output data ( ready after execute, data bit after shift 0/shift 1 
        output                          out_odd_bit, // alternates when new out_bit is available
    // mmcme2/plle2 interface
        output [DRP_ADDRESS_LENGTH-1:0] daddr,
        output [DRP_DATA_LENGTH-1:0]    di_drp,
        input  [DRP_DATA_LENGTH-1:0]    do_drp,
        input                           drdy,      // single pulse!
        output                          den,
        output                          dwe     
);
    localparam DRP_FULL_LENGTH = DRP_ADDRESS_LENGTH + DRP_DATA_LENGTH;
    reg                          out_odd_bit_r = 0;
    reg                    [4:0] bit_cntr;
    reg                    [1:0] cmd_r;
    reg    [DRP_FULL_LENGTH-1:0] sr;
    reg [DRP_ADDRESS_LENGTH-1:0] daddr_r;
    wire                         shift0_w;
    wire                         shift1_w;
    wire                         shift_w;
    wire                         exec_w;
    wire                         exec_wr_w;
    wire                         exec_rd_w;
    wire                         exec_nop_w;
    reg                          exec_wr_r;
    reg                          exec_rd_r;
    reg                          den_r;
    reg                          dwe_r;
//    reg                    [1:0] den_r2;
    reg                          drdy_r;
    wire                         busy_w;
    reg                    [1:0] rdy_r;
    wire                         done; // single-clock rd/wr over
    reg                          nxt_bit_r;
    reg                          was_read;
    
    assign out_odd_bit = out_odd_bit_r;
    assign out_bit =     sr[DRP_FULL_LENGTH-1];
    assign daddr =       daddr_r;
    assign den =         den_r;
    assign dwe =         dwe_r;
    assign shift0_w =    (cmd_r == 1);
    assign shift1_w =    (cmd_r == 2);
    assign shift_w =     shift0_w || shift1_w;
    assign exec_w =      (cmd_r == 3);
    assign exec_wr_w =   exec_w && (bit_cntr == 23);
    assign exec_rd_w =   exec_w && (bit_cntr == 7);
    assign exec_nop_w =  exec_w && (bit_cntr != 23)  && (bit_cntr != 7);
    assign di_drp =      sr[DRP_DATA_LENGTH-1:0];
    assign busy_w =      !mmcm_rst || exec_wr_w || exec_rd_w || exec_wr_r || exec_rd_r || den_r; //  || (|den_r2);
    assign done =        rdy_r[0] && !rdy_r[1];
    always @ (posedge dclk) begin
        exec_wr_r <= mmcm_rst && exec_wr_w; 
        exec_rd_r <= mmcm_rst && exec_rd_w; 
    
        if (!mmcm_rst)     cmd_r <= 0;
        else               cmd_r <= cmd;
        
        if (!mmcm_rst || exec_w) bit_cntr <= 0;
        else if (shift_w)        bit_cntr <= bit_cntr + 1;
        
        if (!mmcm_rst)      out_odd_bit_r <= 0;
        else if (nxt_bit_r) out_odd_bit_r <= !out_odd_bit_r;
        
        if      (exec_wr_w) daddr_r <= sr[22:16];
        else if (exec_rd_w) daddr_r <= sr[6:0];
        
        den_r <=  mmcm_rst && (exec_wr_r || exec_rd_r);
//        den_r2 <= {den_r2[0], den_r};
         
        dwe_r <= mmcm_rst && exec_wr_r;
        drdy_r <= drdy;
        
        rdy_r <= {rdy_r[0], ~busy_w & (drdy_r | rdy_r[0])};
        
        nxt_bit_r <= mmcm_rst && (shift_w || exec_nop_w || done);

        if      (exec_wr_r) was_read <= 0;
        else if (exec_rd_r) was_read <= 1;

        if      (shift_w)          sr[DRP_FULL_LENGTH-1:0] <= {sr[DRP_FULL_LENGTH-2:0],  shift1_w};
        else if (was_read && done) sr[DRP_FULL_LENGTH-1:0] <= {do_drp, sr[DRP_ADDRESS_LENGTH-1:0]}; // keep lower bits
    
    end
endmodule

