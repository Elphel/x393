/*******************************************************************************
 * Module: mult_saxi_wr_pointers
 * Date:2015-07-10  
 * Author: andrey     
 * Description: Process pointers for mult_saxi_wr
 *
 * Copyright (c) 2015 Elphel, Inc .
 * mult_saxi_wr_pointers.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  mult_saxi_wr_pointers.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  mult_saxi_wr_pointers#(
    parameter MULT_SAXI_BSLOG0 =          4,     // number of bits to represent burst size (4 - b.s. = 16, 0 - b.s = 1)
    parameter MULT_SAXI_BSLOG1 =          4,
    parameter MULT_SAXI_BSLOG2 =          4,
    parameter MULT_SAXI_BSLOG3 =          4
)(
    input                         mclk,             // system clock
    input                         aclk,             // global clock to run s_axi (@150MHz?)
    input                   [3:0] chn_en_mclk,      // enable this channle ( 0 - reset)
    input                  [29:0] sa_len_di,        // input data to write pointers address/data
    input                  [ 2:0] sa_len_wa,        // channel address to write sa/lengths
    input                         sa_len_we,        // write enable sa/length data
    input                  [ 1:0] chn,              // selected channel number, valid with start
    input                         start,            // start address generation/pointer increment
    output                        busy,             // suspend new accesses (check latencies)
    // provide address and burst length for AXI @aclk, will stay until ackn
    output reg             [29:0] axi_addr,
    output reg              [3:0] axi_len,
    // write data to external pointre memory (to be read out by PIO) @ aclk
    // alternatively - read out directly from ptr_ram?
    output                 [29:0] pntr_wd, // @aclk
    output                  [1:0] pntr_wa,
    output                        pntr_we
);
    reg   [3:0] chn_en_mclk_r;
    reg   [3:0] chn_en_aclk;
    wire        rst =      !(|chn_en_mclk);    // just for simulation
    wire        rst_aclk = !(|chn_en_aclk);    // just for simulation
    wire  [3:0] chn_wr_mclk = {(sa_len_wa[2:1]==3),(sa_len_wa[2:1]==2),(sa_len_wa[2:1]==1),(sa_len_wa[2:1]==0)};
    wire  [3:0] rst_pntr_mclk =  (chn_en_mclk & ~chn_en_mclk_r) | (sa_len_we ? chn_wr_mclk : 4'b0);
    wire  [3:0] rst_pntr_aclk;
    wire        start_resetting_w;
    reg   [1:0] resetting;              // resetting chunk_pointer and eof_pointer
    reg         busy_r;
    reg   [3:0] reset_rq;               // request to reset pointers when ready
    reg   [3:0] reset_rq_pri;           // one-hot reset rq 
    wire  [1:0] reset_rq_enc;           // encoded reset_rq_pri
    wire        en_aclk = |chn_en_aclk;
    reg   [1:0] chn_r;                  // registered channel being processed (or reset)
    reg   [1:0] seq;                    // 1-hot sequence of address generation
    wire [29:0] sa_len_ram_out;
    wire [29:0] ptr_ram_out;
    wire  [2:0] sa_len_ra;
    reg         ptr_we;                 // write to the pointer memory
    reg  [29:0] ptr_inc;                // incremented pointer
    reg  [30:0] ptr_rollover;
    reg   [4:0] burst_size;             // ROM
    wire [29:0] ptr_wd;
    
    assign reset_rq_enc = {reset_rq_pri[3] | reset_rq_pri[2],
                           reset_rq_pri[3] | reset_rq_pri[1]};
    
    assign start_resetting_w = en_aclk && !busy_r && !resetting[0] && (|reset_rq);
    assign busy = busy_r; //?
    assign ptr_wd = resetting[1] ? 30'b0 : (ptr_rollover[30]? ptr_inc : ptr_rollover[29:0]);
    
    assign pntr_wd = ptr_wd;
    assign pntr_we = ptr_we;
    assign pntr_wa = chn_r;
    
    assign sa_len_ra = {chn_r,seq[1]};
    always @ (posedge mclk) begin
        chn_en_mclk_r <= chn_en_mclk;
    end
    
//  8x30 RAM for address/length    
    reg  [29:0] sa_len_ram[0:7];           // start chunk/num cunks in a buffer (write port @mclk)
    always @ (posedge mclk) begin
        if (sa_len_we) sa_len_ram[sa_len_wa] <= sa_len_di;
    end
    assign sa_len_ram_out = sa_len_ram[sa_len_ra];

// 4 x 30 RAM for current pointers
    reg  [29:0] ptr_ram[0:3];           // start chunk/num cunks in a buffer (write port @mclk)
    always @ (posedge aclk) begin
        if (ptr_we) ptr_ram[chn_r] <= ptr_wd; 
    end
    assign ptr_ram_out = ptr_ram[chn_r];

    always @ (posedge aclk) if (start) case (chn) // small ROM
        'h0 : burst_size <= 1 << MULT_SAXI_BSLOG0;
        'h1 : burst_size <= 1 << MULT_SAXI_BSLOG1;
        'h2 : burst_size <= 1 << MULT_SAXI_BSLOG2;
        'h3 : burst_size <= 1 << MULT_SAXI_BSLOG3;
    endcase
    
    always @ (posedge aclk) begin
        chn_en_aclk <= chn_en_mclk;
        reset_rq <= rst_pntr_aclk | (reset_rq  & ~({4{resetting[0] &~ resetting[1]}} & reset_rq_pri));        
        if (start_resetting_w)  reset_rq_pri <= {reset_rq[3] & ~(|reset_rq[2:0]),
                                                 reset_rq[2] & ~(|reset_rq[1:0]),
                                                 reset_rq[1] &     ~reset_rq[0],
                                                 reset_rq[0]};
        if (rst_aclk) resetting <= 0;
        else          resetting <= {resetting[0], start_resetting_w | (resetting[0] & ~resetting[1])};
        
        if (rst_aclk)                        busy_r <= 0;
        else if (start_resetting_w || start) busy_r <= 1;
        else if (ptr_we)                     busy_r <= 0;

        if (rst_aclk)                        seq <= 0;
        else                                 seq <= {seq[0],start};
        
        if (resetting == 2'b1)               chn_r[1:0] <= reset_rq_enc; // during reset pointers
        else if (start)                      chn_r[1:0] <= chn;          // during normal address generation
        
        if (seq[0]) axi_addr <= sa_len_ram_out + ptr_ram_out;
        if (seq[0]) case (chn_r) // small ROM
            'h0 : axi_len <= (1 << MULT_SAXI_BSLOG0) - 1;
            'h1 : axi_len <= (1 << MULT_SAXI_BSLOG1) - 1;
            'h2 : axi_len <= (1 << MULT_SAXI_BSLOG2) - 1;
            'h3 : axi_len <= (1 << MULT_SAXI_BSLOG3) - 1;
        endcase
        
        if (seq[0]) ptr_inc <= ptr_ram_out + burst_size;

        if (seq[1]) ptr_rollover <= {1'b0, ptr_inc} -sa_len_ram_out; //sa_len_ram_out is now length
        
        ptr_we <= resetting[0] || seq[1];
        
        // add one extra register layer here?
    
    end

    pulse_cross_clock #(.EXTRA_DLY(1)) rst_pntr_aclk0_i (.rst(rst), .src_clk(mclk), .dst_clk(aclk), .in_pulse(rst_pntr_mclk[0]), .out_pulse(rst_pntr_aclk[0]),.busy());
    pulse_cross_clock #(.EXTRA_DLY(1)) rst_pntr_aclk1_i (.rst(rst), .src_clk(mclk), .dst_clk(aclk), .in_pulse(rst_pntr_mclk[1]), .out_pulse(rst_pntr_aclk[1]),.busy());
    pulse_cross_clock #(.EXTRA_DLY(1)) rst_pntr_aclk2_i (.rst(rst), .src_clk(mclk), .dst_clk(aclk), .in_pulse(rst_pntr_mclk[2]), .out_pulse(rst_pntr_aclk[2]),.busy());
    pulse_cross_clock #(.EXTRA_DLY(1)) rst_pntr_aclk3_i (.rst(rst), .src_clk(mclk), .dst_clk(aclk), .in_pulse(rst_pntr_mclk[3]), .out_pulse(rst_pntr_aclk[3]),.busy());

endmodule

