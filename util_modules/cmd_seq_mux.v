/*******************************************************************************
 * Module: cmd_seq_mux
 * Date:2015-06-29  
 * Author: andrey     
 * Description: Command multiplexer from 4 channels of frame-based command
 * sequencers.
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * cmd_seq_mux.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  cmd_seq_mux.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  cmd_seq_mux#(
    parameter                         AXI_WR_ADDR_BITS=14
)(
    input                             rst,      // global system reset
    input                             mclk,     // global system clock
    // Sensor channel 0
    input      [AXI_WR_ADDR_BITS-1:0] waddr0,   // write address, valid with wr_en_out
    input                             wr_en0,   // write enable 
    input                      [31:0] wdata0,   // write data, valid with waddr_out and wr_en_out
    output                            ackn0,    // command sequencer address/data accepted
    // Sensor channel 1
    input      [AXI_WR_ADDR_BITS-1:0] waddr1,   // write address, valid with wr_en_out
    input                             wr_en1,   // write enable 
    input                      [31:0] wdata1,   // write data, valid with waddr_out and wr_en_out
    output                            ackn1,    // command sequencer address/data accepted
    // Sensor channel 2
    input      [AXI_WR_ADDR_BITS-1:0] waddr2,   // write address, valid with wr_en_out
    input                             wr_en2,   // write enable 
    input                      [31:0] wdata2,   // write data, valid with waddr_out and wr_en_out
    output                            ackn2,    // command sequencer address/data accepted
    // Sensor channel 3
    input      [AXI_WR_ADDR_BITS-1:0] waddr3,   // write address, valid with wr_en_out
    input                             wr_en3,   // write enable 
    input                      [31:0] wdata3,   // write data, valid with waddr_out and wr_en_out
    output                            ackn3,    // command sequencer address/data accepted
    // mux output
    output reg [AXI_WR_ADDR_BITS-1:0] waddr_out,   // write address, valid with wr_en_out
    output                            wr_en_out,   // write enable 
    output reg                 [31:0] wdata_out,   // write data, valid with waddr_out and wr_en_out
    input                             ackn_out     // command sequencer address/data accepted
);
    wire [3:0] wr_en = {wr_en3 & ~ackn3, wr_en2 & ~ackn2, wr_en1 & ~ackn1, wr_en0 & ~ackn0};
    wire [3:0] pri_one_rr[0:3]; // round robin priority
    wire [3:0] pri_one;
    reg  [1:0] chn_r; // last served channel
    wire       rq_any;
    wire [1:0] pri_enc_w;
    reg        full_r;
    wire       ackn_w;  //pre-acknowledge of one of the channels
    reg  [3:0] ackn_r;
    
    assign pri_one_rr[0]={wr_en[3] & ~(|wr_en[2:1]), wr_en[2] & ~wr_en[1],             wr_en[1],                              wr_en[0] & ~(|wr_en[3:1])};
    assign pri_one_rr[1]={wr_en[3] & ~  wr_en[2],    wr_en[2],                         wr_en[1] & ~(|wr_en[3:2]) & wr_en[0],  wr_en[0] & ~(|wr_en[3:2])};
    assign pri_one_rr[2]={wr_en[3],                  wr_en[2]&~(|wr_en[1:0])&wr_en[3], wr_en[1] & ~  wr_en[3]    & wr_en[0],  wr_en[0] & ~  wr_en[3]   };
    assign pri_one_rr[3]={wr_en[3] & ~(|wr_en[2:0]), wr_en[2]&~(|wr_en[1:0]),          wr_en[1] &                  wr_en[0],  wr_en[0]                 };
    assign pri_one = pri_one_rr[chn_r];
    assign rq_any= |wr_en;
    assign pri_enc_w ={pri_one[3] | pri_one[2],
                       pri_one[3] | pri_one[1]};
    assign wr_en_out = full_r;
    assign {ackn3, ackn2, ackn1, ackn0} = ackn_r;               
    assign ackn_w = rq_any && (!full_r || ackn_out);
    
    always @(posedge rst or posedge mclk) begin
        if (rst)            full_r <= 0;
        else if (rq_any)    full_r <= 1;
        else if (ackn_out)  full_r <= 0;
        
        if (rst)            ackn_r <=0;
        else                ackn_r <= {4{ackn_w}} & { pri_enc_w[1] &  pri_enc_w[0],
                                                      pri_enc_w[1] & ~pri_enc_w[0],
                                                     ~pri_enc_w[1] &  pri_enc_w[0],
                                                     ~pri_enc_w[1] & ~pri_enc_w[0]};
    end
        
    always @(posedge mclk) begin
    
        if (ackn_w) begin
            chn_r <= pri_enc_w;
            case (pri_enc_w)
                2'h0:begin
                    waddr_out <= waddr0;
                    wdata_out <= wdata0;
                end 
                2'h1:begin
                    waddr_out <= waddr1;
                    wdata_out <= wdata1;
                end 
                2'h2:begin
                    waddr_out <= waddr2;
                    wdata_out <= wdata2;
                end 
                2'h3:begin
                    waddr_out <= waddr3;
                    wdata_out <= wdata3;
                end 
            endcase
        
        end
    end
                      


endmodule

