/*******************************************************************************
 * Module: cmd_deser
 * Date:2015-01-12  
 * Author: andrey     
 * Description: Expand command address/data from a byte-wide
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * cmd_deser.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  cmd_deser.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  cmd_deser#(
    parameter ADDR=0,
    parameter ADDR_MASK='hffff,
    parameter NUM_CYCLES=6,
    parameter ADDR_WIDTH=16,
    parameter DATA_WIDTH=32,
    parameter ADDR1=0,        // optional second address
    parameter ADDR_MASK1=0,   // optional second mask
    parameter ADDR2=0,        // optional third address 
    parameter ADDR_MASK2=0    // optional third mask
)(
    input                                               rst,
    input                                               clk,
    input                                         [7:0] ad,
    input                                               stb,
    output                             [ADDR_WIDTH-1:0] addr,
    output                             [DATA_WIDTH-1:0] data,
    output [(ADDR_MASK2!=0)?2:((ADDR_MASK1!=0)?1:0):0]  we
);
    localparam  WE_WIDTH=(ADDR_MASK2!=0)?3:((ADDR_MASK1!=0)?2:1);
    generate
        if (NUM_CYCLES==1)
            cmd_deser_single # (
                .ADDR       (ADDR),
                .ADDR_MASK  (ADDR_MASK),
                .ADDR_WIDTH (ADDR_WIDTH),
                .DATA_WIDTH (DATA_WIDTH),
                .ADDR1      (ADDR1),
                .ADDR_MASK1 (ADDR_MASK1),
                .ADDR2      (ADDR2),
                .ADDR_MASK2 (ADDR_MASK2),
                .WE_WIDTH   (WE_WIDTH)
            ) i_cmd_deser_single (
                .rst(rst),
                .clk(clk),
                .ad(ad),
                .stb(stb),
                .addr(addr),
                .data(data),
                .we(we)
            );
        else if (NUM_CYCLES==2)
            cmd_deser_dual # (
                .ADDR(ADDR),
                .ADDR_MASK(ADDR_MASK),
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH),
                .ADDR1      (ADDR1),
                .ADDR_MASK1 (ADDR_MASK1),
                .ADDR2      (ADDR2),
                .ADDR_MASK2 (ADDR_MASK2),
                .WE_WIDTH   (WE_WIDTH)
            ) i_cmd_deser_dual (
                .rst(rst),
                .clk(clk),
                .ad(ad),
                .stb(stb),
                .addr(addr),
                .data(data),
                .we(we)
            );
        else 
            cmd_deser_multi # (
                .ADDR(ADDR),
                .ADDR_MASK(ADDR_MASK),
                .NUM_CYCLES(NUM_CYCLES),
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH),
                .ADDR1      (ADDR1),
                .ADDR_MASK1 (ADDR_MASK1),
                .ADDR2      (ADDR2),
                .ADDR_MASK2 (ADDR_MASK2),
                .WE_WIDTH   (WE_WIDTH)
            ) i_cmd_deser_multi (
                .rst(rst),
                .clk(clk),
                .ad(ad),
                .stb(stb),
                .addr(addr),
                .data(data),
                .we(we)
            );
        
    endgenerate

endmodule

module  cmd_deser_single#(
    parameter ADDR=0,
    parameter ADDR_MASK='hffff,
    parameter ADDR_WIDTH=8, // <=8
    parameter DATA_WIDTH=1,  // will 0 work?
    parameter ADDR1=0,
    parameter ADDR_MASK1=0,
    parameter ADDR2=0,
    parameter ADDR_MASK2=0,
    parameter WE_WIDTH=1
)(
    input                   rst,
    input                   clk,
    input             [7:0] ad,
    input                   stb,
    output [ADDR_WIDTH-1:0] addr,
    output [DATA_WIDTH-1:0] data,
    output  [WE_WIDTH-1:0]  we
);
    localparam  ADDR_LOW= ADDR & 8'hff;
    localparam  ADDR_MASK_LOW= ADDR_MASK & 8'hff;
    localparam  ADDR_LOW1= ADDR1 & 8'hff;
    localparam  ADDR_MASK_LOW1= ADDR_MASK1 & 8'hff;
    localparam  ADDR_LOW2= ADDR2 & 8'hff;
    localparam  ADDR_MASK_LOW2= ADDR_MASK2 & 8'hff;
    reg                 [7:0] deser_r;
    wire                [2:0] match_low;
    reg [WE_WIDTH-1:0]         we_r;
    
    assign we=we_r;
    assign match_low= { // unused bits will be optimized
     ((ad ^ ADDR_LOW2)  & (8'hff & ADDR_MASK_LOW2)) == 0,
     ((ad ^ ADDR_LOW1)  & (8'hff & ADDR_MASK_LOW1)) == 0,
     ((ad ^ ADDR_LOW )  & (8'hff & ADDR_MASK_LOW )) == 0};
    always @ (posedge rst or posedge clk) begin
        if (rst) we_r <= 0; 
        else we_r <= match_low && stb;
        if (rst) deser_r <= 0; 
        else if ((|match_low) && stb) deser_r <= ad;
    end
    assign data={DATA_WIDTH{1'b0}};
    assign addr=deser_r[ADDR_WIDTH-1:0];
endmodule

module  cmd_deser_dual#(
    parameter ADDR=0,
    parameter ADDR_MASK='hffff,
    parameter ADDR_WIDTH=12, // <=16
    parameter DATA_WIDTH=1,  // will 0 work?
    parameter ADDR1=0,
    parameter ADDR_MASK1=0,
    parameter ADDR2=0,
    parameter ADDR_MASK2=0,
    parameter WE_WIDTH=1
)(
    input                   rst,
    input                   clk,
    input             [7:0] ad,
    input                   stb,
    output [ADDR_WIDTH-1:0] addr,
    output [DATA_WIDTH-1:0] data,
    output   [WE_WIDTH-1:0] we
);
    localparam  ADDR_LOW= ADDR & 8'hff;
    localparam  ADDR_HIGH=(ADDR>>8) & 8'hff;
    localparam  ADDR_MASK_LOW= ADDR_MASK & 8'hff;
    localparam  ADDR_MASK_HIGH=(ADDR_MASK>>8) & 8'hff;

    localparam  ADDR_LOW1= ADDR1 & 8'hff;
    localparam  ADDR_MASK_LOW1= ADDR_MASK1 & 8'hff;
    localparam  ADDR_LOW2= ADDR2 & 8'hff;
    localparam  ADDR_MASK_LOW2= ADDR_MASK2 & 8'hff;

    localparam  ADDR_HIGH1=(ADDR1>>8) & 8'hff;
    localparam  ADDR_MASK_HIGH1=(ADDR_MASK1>>8) & 8'hff;
    localparam  ADDR_HIGH2=(ADDR2>>8) & 8'hff;
    localparam  ADDR_MASK_HIGH2=(ADDR_MASK2>>8) & 8'hff;


    reg                [15:0] deser_r;
    reg                       stb_d;
    wire                [2:0] match_low;
    wire                [2:0] match_high;
    reg        [WE_WIDTH-1:0] we_r;
    
    assign we=we_r;
    assign match_low=  {((ad ^ ADDR_LOW2)  & (8'hff & ADDR_MASK_LOW2)) == 0,
                        ((ad ^ ADDR_LOW1)  & (8'hff & ADDR_MASK_LOW1)) == 0,
                        ((ad ^ ADDR_LOW )  & (8'hff & ADDR_MASK_LOW )) == 0};
    assign match_high= {((ad ^ ADDR_HIGH2) & (8'hff & ADDR_MASK_HIGH2)) == 0,
                        ((ad ^ ADDR_HIGH1) & (8'hff & ADDR_MASK_HIGH1)) == 0,
                        ((ad ^ ADDR_HIGH ) & (8'hff & ADDR_MASK_HIGH )) == 0};
    
    always @ (posedge rst or posedge clk) begin
        if (rst) stb_d <= 1'b0;
        else stb_d <= match_low && stb;
        if (rst) we_r <= 1'b0;
        else we_r  <= match_high && stb_d;
        if      (rst)                                         deser_r[15:0]  <= 0;
        else if ((match_low && stb) || (match_high && stb_d)) deser_r[15:0] <= {ad,deser_r[15:8]};
    end
    assign data=0; // {DATA_WIDTH{1'b0}};
    assign addr=deser_r[ADDR_WIDTH-1:0];
endmodule

module  cmd_deser_multi#(
    parameter ADDR=0,
    parameter ADDR_MASK='hffff,
    parameter NUM_CYCLES=6, // >=3
    parameter ADDR_WIDTH=16,
    parameter DATA_WIDTH=32,
    parameter ADDR1=0,
    parameter ADDR_MASK1=0,
    parameter ADDR2=0,
    parameter ADDR_MASK2=0,
    parameter WE_WIDTH=1
)(
    input                   rst,
    input                   clk,
    input             [7:0] ad,
    input                   stb,
    output [ADDR_WIDTH-1:0] addr,
    output [DATA_WIDTH-1:0] data,
    output   [WE_WIDTH-1:0] we
);
    localparam  ADDR_LOW= ADDR & 8'hff;
    localparam  ADDR_HIGH=(ADDR>>8) & 8'hff;
    localparam  ADDR_MASK_LOW= ADDR_MASK & 8'hff;
    localparam  ADDR_MASK_HIGH=(ADDR_MASK>>8) & 8'hff;

    localparam  ADDR_LOW1= ADDR1 & 8'hff;
    localparam  ADDR_MASK_LOW1= ADDR_MASK1 & 8'hff;
    localparam  ADDR_LOW2= ADDR2 & 8'hff;
    localparam  ADDR_MASK_LOW2= ADDR_MASK2 & 8'hff;

    localparam  ADDR_HIGH1=(ADDR1>>8) & 8'hff;
    localparam  ADDR_MASK_HIGH1=(ADDR_MASK1>>8) & 8'hff;
    localparam  ADDR_HIGH2=(ADDR2>>8) & 8'hff;
    localparam  ADDR_MASK_HIGH2=(ADDR_MASK2>>8) & 8'hff;

    
    reg    [8*NUM_CYCLES-1:0] deser_r;
    reg                 [2:0] stb_d;
    wire                [2:0] match_low;
    wire                [2:0] match_high;
    reg      [NUM_CYCLES-2:0] sr;
    reg      [NUM_CYCLES-2:0] sr1;
    reg      [NUM_CYCLES-2:0] sr2;
    assign we=sr[0]; // we_r;
    assign match_low=  {((ad ^ ADDR_LOW2)  & (8'hff & ADDR_MASK_LOW2)) == 0,
                        ((ad ^ ADDR_LOW1)  & (8'hff & ADDR_MASK_LOW1)) == 0,
                        ((ad ^ ADDR_LOW )  & (8'hff & ADDR_MASK_LOW )) == 0};
    assign match_high= {((ad ^ ADDR_HIGH2) & (8'hff & ADDR_MASK_HIGH2)) == 0,
                        ((ad ^ ADDR_HIGH1) & (8'hff & ADDR_MASK_HIGH1)) == 0,
                        ((ad ^ ADDR_HIGH ) & (8'hff & ADDR_MASK_HIGH )) == 0};
    always @ (posedge rst or posedge clk) begin
        if (rst) stb_d <= 0;
        else stb_d <= stb?match_low:3'b0;
        if      (rst)                    sr <= 0;
        else if (match_high[0] && stb_d) sr <= 1 << (NUM_CYCLES-2);
        else                             sr <= {1'b0,sr[NUM_CYCLES-2:1]};

        if      (rst)                    sr1<= 0;
        else if (match_high[1] && stb_d) sr1 <= 1 << (NUM_CYCLES-2);
        else                             sr1 <= {1'b0,sr1[NUM_CYCLES-2:1]};

        if      (rst)                    sr2 <= 0;
        else if (match_high[2] && stb_d) sr2 <= 1 << (NUM_CYCLES-2);
        else                             sr2 <= {1'b0,sr2[NUM_CYCLES-2:1]};
        
        if      (rst)                       deser_r[8*NUM_CYCLES-1:0] <= 0;
        else if ((match_low &&  (|stb)) ||
                 (match_high && (|stb_d)) ||
                 (|sr) || (|sr1) || (|sr2)) deser_r[8*NUM_CYCLES-1:0] <= {ad,deser_r[8*NUM_CYCLES-1:8]};

    end
    assign data=deser_r[DATA_WIDTH+15:16];
    assign addr=deser_r[ADDR_WIDTH-1:0];
endmodule
