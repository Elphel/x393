/*******************************************************************************
 * Module: bit_stuffer_27_32
 * Date:2015-10-23  
 * Author: andrey     
 * Description: Aggregate MSB aligned variable-length (1..27) data to 32-bit words
 *
 * Copyright (c) 2015 Elphel, Inc .
 * bit_stuffer_27_32.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  bit_stuffer_27_32.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  bit_stuffer_27_32#(
    parameter DIN_LEN = 27
)(
    input                   xclk,            // pixel clock, sync to incoming data
    input                   rst,             // @xclk
    input     [DIN_LEN-1:0] din,             // input data, MSB aligned
    input             [4:0] dlen,            // input data width
    input                   ds,              // input data valid
    input                   flush_in,        // flush remaining data - should be after last ds. Also prepares for the next block
    output           [31:0] d_out,           // outpt 32-bit data
    output reg        [1:0] bytes_out,       // (0 means 4) valid with dv
    output reg              dv,              // output data valid
    output reg              flush_out        // delayed flush in matching the data latency
);
    localparam  DATA1_LEN = DIN_LEN + 32 - 8;
    localparam  DATA2_LEN = DIN_LEN + 32 - 2;
    localparam  DATA3_LEN = DIN_LEN + 32 - 1;
    reg  [DATA1_LEN-1:0] data1;   // first stage of the barrel shifter
    reg  [DATA2_LEN-1:0] data2;   // second stage of the barrel shifter
    reg  [DATA3_LEN-1:0] data3;   // second stage of the barrel shifter/ output register
    
    reg         [5:0] early_length; // number of bits in the last word (mod 32)
    reg         [5:0] dlen1; // use for the stage 2, MSB - carry out
    reg         [5:0] dlen2; // use for the stege 3
    
    reg        [31:0] dmask2_rom; // data mask (sync with data2) - 1 use new data, 0 - use old data. Use small ROM?
    
    reg         [1:0] stage; // delayed ds or flush
    reg         [1:0] ds_stage;
    reg         [2:0] flush_stage;
    wire        [4:0] pre_bits_out_w = dlen2[4:0] + 5'h7; 

    assign d_out = data3[DATA3_LEN-1 -: 32];
    
    always @ (posedge xclk) begin
    
        if (rst) stage <= 0;
        else     stage <= {stage[0], ds | flush_in};

        if (rst) ds_stage <= 0;
        else     ds_stage <= {ds_stage[0], ds};

        if (rst) flush_stage <= 0;
        else     flush_stage <= {flush_stage[1:0], ds};
        
        if (rst || flush_in) early_length <= 0;
        else if (ds)         early_length <= early_length[4:0] + dlen; // early_length[5] is not used in calculations, it is just carry out
        
        if     (rst)       dlen1 <= 0;
        else if (ds)       dlen1 <= early_length; // previous value

        if      (rst)      dlen2 <= 0;
        else if (stage[0]) dlen2 <= dlen1; // previous value (position)
        

        // barrel shifter stage 1 (0/8/16/24)
        if (ds) case (early_length[4:3])
            2'h0: data1 <= {      din, 24'b0};
            2'h1: data1 <= { 8'b0,din, 16'b0};
            2'h2: data1 <= {16'b0,din,  8'b0};
            2'h3: data1 <= {24'b0,din       }; 
        endcase
    
        // barrel shifter stage 2 (0/2/4/6)
        if (stage[0]) case (dlen1[2:1])
            2'h0: data2 <= {      data1, 6'b0};
            2'h1: data2 <= { 2'b0,data1, 4'b0};
            2'h2: data2 <= { 4'b0,data1, 2'b0};
            2'h3: data2 <= { 6'b0,data1      };
        endcase
        if (stage[0]) case (dlen1[4:0])
            5'h00: dmask2_rom <= 32'hffffffff;
            5'h01: dmask2_rom <= 32'hfffffffe;
            5'h02: dmask2_rom <= 32'hfffffffc;
            5'h03: dmask2_rom <= 32'hfffffff8;
            5'h04: dmask2_rom <= 32'hfffffff0;
            5'h05: dmask2_rom <= 32'hffffffe0;
            5'h06: dmask2_rom <= 32'hffffffc0;
            5'h07: dmask2_rom <= 32'hffffff80;
            5'h08: dmask2_rom <= 32'hffffff00;
            5'h09: dmask2_rom <= 32'hfffffe00;
            5'h0a: dmask2_rom <= 32'hfffffc00;
            5'h0b: dmask2_rom <= 32'hfffff800;
            5'h0c: dmask2_rom <= 32'hfffff000;
            5'h0d: dmask2_rom <= 32'hffffe000;
            5'h0e: dmask2_rom <= 32'hffffc000;
            5'h0f: dmask2_rom <= 32'hffff8000;
            5'h10: dmask2_rom <= 32'hffff0000;
            5'h11: dmask2_rom <= 32'hfffe0000;
            5'h12: dmask2_rom <= 32'hfffc0000;
            5'h13: dmask2_rom <= 32'hfff80000;
            5'h14: dmask2_rom <= 32'hfff00000;
            5'h15: dmask2_rom <= 32'hffe00000;
            5'h16: dmask2_rom <= 32'hffc00000;
            5'h17: dmask2_rom <= 32'hff800000;
            5'h18: dmask2_rom <= 32'hff000000;
            5'h19: dmask2_rom <= 32'hfe000000;
            5'h1a: dmask2_rom <= 32'hfc000000;
            5'h1b: dmask2_rom <= 32'hf8000000;
            5'h1c: dmask2_rom <= 32'hf0000000;
            5'h1d: dmask2_rom <= 32'he0000000;
            5'h1e: dmask2_rom <= 32'hc0000000;
            5'h1f: dmask2_rom <= 32'h80000000;
        endcase
        // barrel shifter stage 3 (0/1), combined with output/hold register
        if (ds_stage[1]) begin
            data3[DATA3_LEN-1 -: 32] <= (~dmask2_rom & (dlen2[5] ? {data3[DATA3_LEN-1-32 : 0],6'b0}: data3[DATA3_LEN-1 -: 32])) |
                               ( dmask2_rom & (dlen2[0] ? {1'b0,data2[DATA2_LEN-1 -: 31]} : data2[DATA2_LEN-1 -: 32]));
            data3[DATA3_LEN-1-32: 0] <= dlen2[0] ? data2[DATA2_LEN-31-1 : 0] : {data2[DATA2_LEN-32-1 : 0], 1'b0};
            
        end
        dv <= (ds_stage[1] && dlen2[5]) || (flush_stage[1] && !(|data3[DATA3_LEN-1 -: 32]));

        if  (rst || ds_stage[1]) bytes_out <= 0; // if the dv was caused by 32 bits full - output 4 bytes
        else if (flush_stage[1]) bytes_out <= pre_bits_out_w[4:3];
    
        flush_out <= flush_stage[2];

    end

endmodule

