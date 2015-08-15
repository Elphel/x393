/**********************************************************************
** -----------------------------------------------------------------------------**
** xdct393.v
**
** 8x8 discrete Cosine Transform
**
** Copyright (C) 2002-2015 Elphel, Inc
**
** -----------------------------------------------------------------------------**
**  xdct393 is free software - hardware description language (HDL) code.
** 
**  This program is free software: you can redistribute it and/or modify
**  it under the terms of the GNU General Public License as published by
**  the Free Software Foundation, either version 3 of the License, or
**  (at your option) any later version.
**
**  This program is distributed in the hope that it will be useful,
**  but WITHOUT ANY WARRANTY; without even the implied warranty of
**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
**  GNU General Public License for more details.
**
**  You should have received a copy of the GNU General Public License
**  along with this program.  If not, see <http://www.gnu.org/licenses/>.
** -----------------------------------------------------------------------------**
**
** Modified by Andrey Filippov - goal to make it work in start/stop mode, using
** "start" input (going together with the first data, no restriction on the gap between 64-pixel blocks (>=0)
** Removed "RST" input ("en" is only used to reset ping-pong transpose memory address)
** Split module in 2 stages
** Also saved some area - original design compiled by XST to 865 slices (XC2S300e), this one - 780!
**
** It is based on the original design (Xilix app. note XAPP610) by:
**                  Author: Latha Pillai
**                  Senior Applications Engineer
**
**                  Video Applications
**                  Advanced Products Group
**                  Xilinx, Inc.
**
**                  Copyright (c) 2001 Xilinx, Inc.
**                  All rights reserved
**
**                  Date:   Feb. 10, 2002
**
**                  RESTRICTED RIGHTS LEGEND
**
**      This software has not been published by the author, and 
**      has been disclosed to others for the purpose of enhancing 
**      and promoting design productivity in Xilinx products.
**
**      Therefore use, duplication or disclosure, now and in the 
**      future should give consideration to the productivity 
**      enhancements afforded the user of this code by the author's 
**      efforts.  Thank you for using our products !
**
** Disclaimer:  THESE DESIGNS ARE PROVIDED "AS IS" WITH NO WARRANTY 
**              WHATSOEVER AND XILINX SPECIFICALLY DISCLAIMS ANY 
**              IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR
**              A PARTICULAR PURPOSE, OR AGAINST INFRINGEMENT.
***********************************************************************/

/*
after I added DC subtraction before DCT I got 9-bit (allthough not likely to go out of 8bit range) signed data.
also increased transpose memory to 9 bits (anyway it is 16-bit wide) - see if it will help to prevent saturation
without significant increase in gates

Saturatuion is still visible on real pictures, but there was a bug - addsub<i>a_comp, addsub<i>b_comp where not using their
MSB. I added 1 more bit to add_sub<i>a and add_sub<i>b and fixed that bug. Only 2 mofre slices were used

Device utilization summary:

   Number of External GCLKIOBs         1 out of 4      25%
   Number of External IOBs            23 out of 178    12%
      Number of LOCed External IOBs    0 out of 23      0%

   Number of BLOCKRAMs                 1 out of 16      6%
   Number of SLICEs                  855 out of 3072   27%

   Number of GCLKs                     1 out of 4      25%


*/

// still not enough - maybe one tiny bit more??
/*
Device utilization summary:

   Number of External GCLKIOBs         1 out of 4      25%
   Number of External IOBs            26 out of 178    14%
      Number of LOCed External IOBs    0 out of 26      0%

   Number of BLOCKRAMs                 1 out of 16      6%
   Number of SLICEs                  837 out of 3072   27%

   Number of GCLKs                     1 out of 4      25%
*/



`timescale 1ns/1ps

// For xdct353 - increasing data in 9 bits -> 10 bits, out 12 bits ->13 bits

module xdct393   (
    input         clk,           // system clock, posedge
    input         en,            // if zero will reset transpose memory page njumbers
    input         start,         // single-cycle start pulse that goes with the first pixel data. Other 63 should follow
    input   [9:0] xin,           // [7:0] - input data
    output reg    last_in,       // output high during input of the last of 64 pixels in a 8x8 block
    output        pre_first_out, // 1 cycle ahead of the first output in a 64 block
    output        dv,            // data output valid. Will go high on the 94-th cycle after the start
    output [12:0] d_out);        // [8:0]output data


    wire          stage1_done;
    wire          tm_page;
    wire          tm_we;
    wire    [6:0] tm_ra;
    wire    [6:0] tm_wa;
    wire   [15:0] tm_out;
    wire   [15:0] tm_di;

//    reg           stage1_done_r; // delay by one clock to use memory output register
    
    wire          tm_re; // =1'b1; // TODO: generate, for now just 1'b1
    wire           tm_regen;
    always @ (posedge clk) begin
        last_in <=       (tm_wa[5:0]== 6'h30);
//        stage1_done_r <= stage1_done;
//        tm_regen <=      tm_re;
    end
    dct393_stage1 i_dct_stage1(
        .clk       (clk),
        .en        (en),
        .start     (start),
        .xin       (xin),      // [7:0]
        .we        (tm_we),          // write to transpose memory
        .wr_cntr   (tm_wa), // [6:0]    transpose memory write address
        .z_out     (tm_di[15:0]),
        .page      (tm_page),
        .done      (stage1_done));
        
    dct393_stage2 i_dct_stage2(
        .clk       (clk),
        .en        (en),
        .start     (stage1_done),      // stage 1 finished, data available in transpose memory (extra RAM latency)
        .page      (tm_page),      // transpose memory page finished, valid at start
        .rd_cntr   (tm_ra[6:0]), // [6:0]    transpose memory read address
        .ren       (tm_re), // output
        .regen     (tm_regen), // output reg 
        .tdin      (tm_out[15:0]),      // [7:0] - data from transpose memory
        .endv      (pre_first_out),
        .dv        (dv),          // data output valid
        .dct2_out  (d_out[12:0]));// [10:0]output data

    ram18_var_w_var_r #(
        .REGISTERS     (1),
        .LOG2WIDTH_WR  (4),
        .LOG2WIDTH_RD  (4),
        .DUMMY(0)
    ) i_transpose_mem (
        .rclk      (clk), // input
        .raddr     ({3'b0,tm_ra[6:0]}), // input[9:0] 
        .ren       (tm_re), // input
        .regen     (tm_regen), // input
        .data_out  (tm_out[15:0]), // output[15:0] 
        .wclk      (clk), // input
        .waddr     ({3'b0,tm_wa[6:0]}), // input[9:0] 
        .we        (tm_we), // input
        .web       (4'hf), // input[3:0] 
        .data_in   (tm_di[15:0]) // input[15:0] 
    );

endmodule

// 01/24/2004: Moved all clocks in stage 1 to "negedge" to reduce current pulses

module dct393_stage1 (
    input             clk,           // system clock, posedge
    input             en,
    input             start,      // single-cycle start pulse to replace RST
    input      [ 9:0] xin,      // [7:0]
    output reg        we,          // write to transpose memory
    output reg [ 6:0] wr_cntr, // [6:0]    transpose memory write address
    output reg [15:0] z_out,      //data to transpose memory
    output reg        page,    // transpose memory page just filled (valid @ done)
    output reg        done);   // last cycle writing to transpose memory - may use after it (move it earlier?)
/* constants */

    localparam C3= 16'd54491;
    localparam S3= 16'd36410;
    localparam C4= 16'd46341;
    localparam C6= 16'd25080;
    localparam S6= 16'd60547;
    localparam C7= 16'd12785;
    localparam S7= 16'd64277;

    reg    [16:0] memory1a, memory2a, memory3a, memory4a;


/* 1D section */
/* The max value of a pixel after processing (to make their expected mean to zero)
is 127. If all the values in a row are 127, the max value of the product terms
would be (127*2)*(23170/256) and that of z_out_int would be (127*8)*23170/256.
This value divided by 2raised to 8 is equivalent to ignoring the 8 lsb bits of the value */

    reg    [ 9:0] xa0_in, xa1_in, xa2_in, xa3_in, xa4_in, xa5_in, xa6_in, xa7_in;
    reg    [ 9:0] xa0_reg, xa1_reg, xa2_reg, xa3_reg, xa4_reg, xa5_reg, xa6_reg, xa7_reg;

    reg    [ 9:0] addsub1a_comp, addsub2a_comp, addsub3a_comp, addsub4a_comp;
//    reg    [10:0] addsub1a_comp, addsub2a_comp, addsub3a_comp, addsub4a_comp; // AF2015: increasing width - was limiting

    reg    [10:0] add_sub1a, add_sub2a, add_sub3a, add_sub4a;
    reg           save_sign1a, save_sign2a, save_sign3a, save_sign4a;
    reg    [17:0] p1a, p2a, p3a, p4a;
    wire   [35:0] p1a_all, p2a_all, p3a_all, p4a_all;
    reg           toggleA;

    reg    [18:0] z_out_int1, z_out_int2;
    reg    [18:0] z_out_int;
    wire   [15:0] z_out_prelatch;
    reg    [ 2:0] indexi;

/* clks and counters */
    reg    [ 6:0] wr_cntr_prelatch;

/* memory section */
    reg           done_prelatch;
    reg           we_prelatch;
    wire          enwe;
    wire          pre_sxregs;
    reg           sxregs;
    reg           page_prelatch;
    // TODO: See if negedge is needed
    wire          nclk = ~clk; // seems that everything here is running at negedge (and delays too), but not the transpose memory

// to conserve energy by disabling toggleA

    wire          sxregs_d8;
    reg           enable_toggle;
//  SRL16_1 i_sxregs_d8   (.Q(sxregs_d8), .A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b0), .CLK(clk),.D(sxregs));    // dly=7+1
    dly_16 #(.WIDTH(1)) i_sxregs_d8(.clk(nclk),.rst(1'b0), .dly(4'd7), .din(sxregs), .dout(sxregs_d8));   // dly=7+1
    
    
// SRL16_1 i_pre_sxregs (.Q(pre_sxregs), .A0(1'b0), .A1(1'b1), .A2(1'b1), .A3(1'b0), .CLK(clk), .D(start));    // dly=6+1
    dly_16 #(.WIDTH(1)) i_pre_sxregs(.clk(nclk),.rst(1'b0), .dly(4'd6), .din(start), .dout(pre_sxregs));    // dly=6+1
    
// SRL16_1 i_enwe       (.Q(enwe), .A0(1'b1), .A1(1'b0), .A2(1'b1), .A3(1'b0), .CLK(clk), .D(pre_sxregs));    // dly=5+1
    dly_16 #(.WIDTH(1)) i_enwe(.clk(nclk),.rst(1'b0), .dly(4'd5), .din(pre_sxregs), .dout(enwe));    // dly=5+1
  
    always @ (posedge nclk) begin
        enable_toggle <= en && (sxregs || (enable_toggle && !sxregs_d8));
        
        done_prelatch<= (wr_cntr_prelatch[5:0]==6'h3f);
        
        if (wr_cntr_prelatch[5:0]==6'h3f) page_prelatch <= wr_cntr_prelatch[6];
        
        we_prelatch<= enwe || (en && we_prelatch && (wr_cntr_prelatch[5:0]!=6'h3f));
        
        if     (!en) wr_cntr_prelatch <= 7'b0;
        else if (we_prelatch) wr_cntr_prelatch <= wr_cntr_prelatch + 1;
        
        sxregs <= pre_sxregs || ((wr_cntr_prelatch[2:0]==3'h1) && (wr_cntr_prelatch[5:3]!=3'h7));
        
        toggleA <= sxregs || (enable_toggle && (~toggleA));
        
        if (sxregs) indexi <= 3'h7;
        else if (enable_toggle) indexi<=indexi+1;
    end


/*  1D-DCT BEGIN */

// store  1D-DCT constant coeeficient values for multipliers */

    always @ (posedge nclk) begin
        case (indexi)
         0 : begin memory1a <= {1'b0,C4}; //8'd91
                   memory2a <= {1'b0,C4}; //8'd91
                   memory3a <= {1'b0,C4}; //8'd91 
                   memory4a <= {1'b0,C4}; //8'd91
             end
         1 : begin memory1a <= {1'b0,S7}; //8'd126; 
                   memory2a <= {1'b0,C3}; //8'd106;  
                   memory3a <= {1'b0,S3}; //8'd71;  
                   memory4a <= {1'b0,C7}; //8'd25;
             end
         2 : begin memory1a <= {1'b0,S6}; //8'd118; 
                   memory2a <= {1'b0,C6}; //8'd49;  
                   memory3a <= {1'b1,C6}; //-8'd49; 
                   memory4a <= {1'b1,S6}; //-8'd118
             end
         3 : begin memory1a <= {1'b0,C3}; // 8'd106; 
                   memory2a <= {1'b1,C7}; //-8'd25;  
                   memory3a <= {1'b1,S7}; //-8'd126; 
                   memory4a <= {1'b1,S3}; //-8'd71;
             end
         4 : begin memory1a <= {1'b0,C4}; // 8'd91; 
                   memory2a <= {1'b1,C4}; //-8'd91; 
                   memory3a <= {1'b1,C4}; //-8'd91; 
                   memory4a <= {1'b0,C4}; // 8'd91;
             end
         5 : begin memory1a <= {1'b0,S3}; // 8'd71; 
                   memory2a <= {1'b1,S7}; //-8'd126; 
                   memory3a <= {1'b0,C7}; // 8'd25;   
                   memory4a <= {1'b0,C3}; // 8'd106;
             end
         6 : begin memory1a <= {1'b0,C6}; // 8'd49; 
                   memory2a <= {1'b1,S6}; //-8'd118; 
                   memory3a <= {1'b0,S6}; // 8'd118;  
                   memory4a <= {1'b1,C6}; //-8'd49;
             end
         7 : begin memory1a <= {1'b0,C7}; // 8'd25;  
                   memory2a <= {1'b1,S3}; //-8'd71; 
                   memory3a <= {1'b0,C3}; // 8'd106;  
                   memory4a <= {1'b1,S7}; //-8'd126;
             end
        endcase
    end

/* 8-bit input shifted 8 times through a shift register*/
// xa0_in will see output registers from posedge, may be replaced by latches if needed - but currently delay is under 5ns
    always @ (posedge nclk) begin
        xa0_in <= xin;
        xa1_in <= xa0_in;
        xa2_in <= xa1_in;
        xa3_in <= xa2_in;
        xa4_in <= xa3_in;
        xa5_in <= xa4_in;
        xa6_in <= xa5_in;
        xa7_in <= xa6_in;
    end

/* shifted inputs registered every 8th clk (using cntr8)*/
    always @ (posedge nclk) if (sxregs) begin 
        xa0_reg <= xa0_in;
        xa1_reg <= xa1_in; 
        xa2_reg <= xa2_in;
        xa3_reg <= xa3_in;
        xa4_reg <= xa4_in;
        xa5_reg <= xa5_in; 
        xa6_reg <= xa6_in;
        xa7_reg <= xa7_in;
    end

/* adder / subtractor block */
    always @ (negedge clk)
        if (toggleA == 1'b1) begin
            add_sub1a <= {xa7_reg[9],xa7_reg[9:0]} + {xa0_reg[9],xa0_reg[9:0]};
            add_sub2a <= {xa6_reg[9],xa6_reg[9:0]} + {xa1_reg[9],xa1_reg[9:0]};
            add_sub3a <= {xa5_reg[9],xa5_reg[9:0]} + {xa2_reg[9],xa2_reg[9:0]};
            add_sub4a <= {xa4_reg[9],xa4_reg[9:0]} + {xa3_reg[9],xa3_reg[9:0]};
        end else begin
            add_sub1a <= {xa7_reg[9],xa7_reg[9:0]} - {xa0_reg[9],xa0_reg[9:0]};
            add_sub2a <= {xa6_reg[9],xa6_reg[9:0]} - {xa1_reg[9],xa1_reg[9:0]};
            add_sub3a <= {xa5_reg[9],xa5_reg[9:0]} - {xa2_reg[9],xa2_reg[9:0]};
            add_sub4a <= {xa4_reg[9],xa4_reg[9:0]} - {xa3_reg[9],xa3_reg[9:0]};
        end

// First valid add_sub appears at the 10th clk (8 clks for shifting inputs,
// 9th clk for registering shifted input and 10th clk for add_sub
// to synchronize the i value to the add_sub value, i value is incremented
// only after 10 clks

// Adding these wires to get rid of the MSB that is always 0
    wire [10:0] addsub1a_comp_w  = add_sub1a[10]? (-add_sub1a) : add_sub1a;
    wire [10:0] addsub2a_comp_w  = add_sub2a[10]? (-add_sub2a) : add_sub2a;
    wire [10:0] addsub3a_comp_w  = add_sub3a[10]? (-add_sub3a) : add_sub3a;
    wire [10:0] addsub4a_comp_w  = add_sub4a[10]? (-add_sub4a) : add_sub4a;
    
    always @ (posedge nclk) begin
         save_sign1a     <= add_sub1a[10];
         save_sign2a     <= add_sub2a[10];
         save_sign3a     <= add_sub3a[10];
         save_sign4a     <= add_sub4a[10];
         addsub1a_comp	<= addsub1a_comp_w[9:0]; //add_sub1a[10]? (-add_sub1a) : add_sub1a;
         addsub2a_comp	<= addsub2a_comp_w[9:0]; //add_sub2a[10]? (-add_sub2a) : add_sub2a;
         addsub3a_comp	<= addsub3a_comp_w[9:0]; //add_sub3a[10]? (-add_sub3a) : add_sub3a;
         addsub4a_comp	<= addsub4a_comp_w[9:0]; //add_sub4a[10]? (-add_sub4a) : add_sub4a;
    end

    assign p1a_all = addsub1a_comp * memory1a; //[15:0]; // TODO: Check - memory is [16:0] !
    assign p2a_all = addsub2a_comp * memory2a; //[15:0];
    assign p3a_all = addsub3a_comp * memory3a; //[15:0];
    assign p4a_all = addsub4a_comp * memory4a; //[15:0];


    always @ (posedge nclk)
      begin
        p1a <= (save_sign1a ^ memory1a[16]) ? (-p1a_all[26:9]) :(p1a_all[26:9]);
        p2a <= (save_sign2a ^ memory2a[16]) ? (-p2a_all[26:9]) :(p2a_all[26:9]);
        p3a <= (save_sign3a ^ memory3a[16]) ? (-p3a_all[26:9]) :(p3a_all[26:9]);
        p4a <= (save_sign4a ^ memory4a[16]) ? (-p4a_all[26:9]) :(p4a_all[26:9]);
      end

/* Final adder. Adding the ouputs of the 4 multipliers */
    always @ (posedge nclk) begin
        z_out_int1 <= ({p1a[17],p1a} + {p2a[17],p2a});
        z_out_int2 <= ({p3a[17],p3a} + {p4a[17],p4a});
        z_out_int <= (z_out_int1 + z_out_int2);
    end

// rounding of the value
    assign z_out_prelatch[15:0] = z_out_int[18:3]+ z_out_int[2]; // correct rounding

// outputs from output latches to cross clock edge boundary
    always @ (posedge clk) begin
        z_out[15:0]  <= z_out_prelatch[15:0];
        wr_cntr[6:0] <= wr_cntr_prelatch[6:0];  
        done         <= done_prelatch;  
        we           <= we_prelatch;  
        page         <= page_prelatch;  
    end

/* 1D-DCT END */
endmodule


module dct393_stage2 (
    input             clk,           // system clock, posedge
    input             en,
    input             start,      // stage 1 finished, data available in transpose memory
    input             page,      // transpose memory page finished, valid at start
    output      [6:0] rd_cntr, // [6:0]    transpose memory read address
    output            ren,     // read enable transpose memory
    output reg        regen,   // register enable in transpose memory
    input      [15:0] tdin,      // [15:0] - data from transpose memory, added 6 bit fractional part
    output            endv,        // one cycle ahead of starting (continuing) dv
    output reg        dv,          // data output valid
    output    [12:0] dct2_out);// [8:0]output data
/* constants */
    localparam C3= 16'd54491;
    localparam S3= 16'd36410;
    localparam C4= 16'd46341;
    localparam C6= 16'd25080;
    localparam S6= 16'd60547;
    localparam C7= 16'd12785;
    localparam S7= 16'd64277;

    reg    [16:0] memory1a, memory2a, memory3a, memory4a;

    reg     [2:0] indexi;
/* 2D section */
    reg    [15:0] xb0_in, xb1_in, xb2_in, xb3_in, xb4_in, xb5_in, xb6_in, xb7_in;
    reg    [15:0] xb0_reg, xb1_reg, xb2_reg, xb3_reg, xb4_reg, xb5_reg, xb6_reg, xb7_reg;
    reg    [16:0] add_sub1b, add_sub2b, add_sub3b, add_sub4b;
    reg    [15:0] addsub1b_comp, addsub2b_comp, addsub3b_comp, addsub4b_comp;
    reg           save_sign1b, save_sign2b, save_sign3b, save_sign4b;
    reg    [18:0] p1b, p2b, p3b, p4b;
    wire   [35:0] p1b_all, p2b_all, p3b_all, p4b_all;
    reg           toggleB;
    reg    [19:0] dct2d_int1, dct2d_int2;
    reg    [20:0] dct_2d_int;
    wire   [12:0] dct_2d_rnd;

// transpose memory read address
    reg    [ 5:0] rd_cntrs;
    reg           rd_page;

// start with the same as stage1
    wire          sxregs;
// to conserve energy by disabling toggleB

    wire          sxregs_d8;
    reg           enable_toggle;
    reg           en_started;
    wire          disdv; // AF2015: was missing
// SRL16 i_endv       (.Q(endv), .A0(1'b0), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(clk), .D(start));    // dly=14+1
//    dly_16 #(.WIDTH(1)) i_endv(.clk(clk),.rst(1'b0), .dly(4'd14), .din(start), .dout(endv));    // dly=14+1
    dly_16 #(.WIDTH(1)) i_endv(.clk(clk),.rst(1'b0), .dly(4'd15), .din(start), .dout(endv));    // dly=15+1
 
// SRL16 i_disdv      (.Q(disdv), .A0(1'b0), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(clk), .D(rd_cntrs[5:0]==6'h3f));    // dly=14+1
//    dly_16 #(.WIDTH(1)) i_disdv(.clk(clk),.rst(1'b0), .dly(4'd14), .din(rd_cntrs[5:0]==6'h3f), .dout(disdv));    // dly=14+1
    dly_16 #(.WIDTH(1)) i_disdv(.clk(clk),.rst(1'b0), .dly(4'd15), .din(rd_cntrs[5:0]==6'h3f), .dout(disdv));    // dly=15+1

// SRL16 i_sxregs      (.Q(sxregs),    .A0(1'b0), .A1(1'b0), .A2(1'b0), .A3(1'b1), .CLK(clk),.D((rd_cntr[5:3]==3'h0) && en_started));    // dly=8+1
//    dly_16 #(.WIDTH(1)) i_sxregs(.clk(clk),.rst(1'b0), .dly(4'd8), .din((rd_cntr[5:3]==3'h0) && en_started), .dout(sxregs));    // dly=8+1
    dly_16 #(.WIDTH(1)) i_sxregs(.clk(clk),.rst(1'b0), .dly(4'd9), .din((rd_cntrs[2:0]==3'h0) && en_started), .dout(sxregs));    // dly=9+1

// SRL16 i_sxregs_d8   (.Q(sxregs_d8), .A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b0), .CLK(clk),.D(sxregs && en_started));    // dly=7+1
    dly_16 #(.WIDTH(1)) i_sxregs_d8(.clk(clk),.rst(1'b0), .dly(4'd7), .din(sxregs && en_started), .dout(sxregs_d8));    // dly=7+1

    assign ren = en_started;
    
    always @ (posedge clk) begin
        enable_toggle <= en && (sxregs || (enable_toggle && !sxregs_d8));
        
//        en_started <= en && (start || en_started);
        if      (!en)                   en_started <= 0;
        else if (start)                 en_started <= 1;
        else if (rd_cntrs[5:0] == 6'h3f) en_started <= 0; // should be after (start) as they happen simultaneously
        
        regen <= en_started;

        dv <= en && (endv || (dv && ~disdv));

        toggleB <= sxregs || (enable_toggle && (~toggleB));
        
        if (sxregs) indexi <= 3'h7;
        else if (enable_toggle) indexi<=indexi+1;
        
        if (start) rd_page <= page;
        
        if (start) rd_cntrs[5:0] <=6'b0;    // will always count, but that does not matter- What about saving energy ;-) ? Saved...
        else if (rd_cntrs[5:0]!=6'h3f) rd_cntrs[5:0] <= rd_cntrs[5:0]+1;
    end 
  
    assign    rd_cntr[6:0]= {rd_page,rd_cntrs[2:0],rd_cntrs[5:3]}; // transposed counter
// duplicate memory<i>a from stage 1
// store  1D-DCT constant coeeficient values for multipliers */

    always @ (posedge clk) begin
        case (indexi)
         0 : begin memory1a <= {1'b0,C4}; //8'd91
                   memory2a <= {1'b0,C4}; //8'd91
                   memory3a <= {1'b0,C4}; //8'd91 
                   memory4a <= {1'b0,C4}; //8'd91
             end
         1 : begin memory1a <= {1'b0,S7}; //8'd126; 
                   memory2a <= {1'b0,C3}; //8'd106;  
                   memory3a <= {1'b0,S3}; //8'd71;  
                   memory4a <= {1'b0,C7}; //8'd25;
             end
         2 : begin memory1a <= {1'b0,S6}; //8'd118; 
                   memory2a <= {1'b0,C6}; //8'd49;  
                   memory3a <= {1'b1,C6}; //-8'd49; 
                   memory4a <= {1'b1,S6}; //-8'd118
             end
         3 : begin memory1a <= {1'b0,C3}; // 8'd106; 
                   memory2a <= {1'b1,C7}; //-8'd25;  
                   memory3a <= {1'b1,S7}; //-8'd126; 
                   memory4a <= {1'b1,S3}; //-8'd71;
             end
         4 : begin memory1a <= {1'b0,C4}; // 8'd91; 
                   memory2a <= {1'b1,C4}; //-8'd91; 
                   memory3a <= {1'b1,C4}; //-8'd91; 
                   memory4a <= {1'b0,C4}; // 8'd91;
             end
         5 : begin memory1a <= {1'b0,S3}; // 8'd71; 
                   memory2a <= {1'b1,S7}; //-8'd126; 
                   memory3a <= {1'b0,C7}; // 8'd25;   
                   memory4a <= {1'b0,C3}; // 8'd106;
             end
         6 : begin memory1a <= {1'b0,C6}; // 8'd49; 
                   memory2a <= {1'b1,S6}; //-8'd118; 
                   memory3a <= {1'b0,S6}; // 8'd118;  
                   memory4a <= {1'b1,C6}; //-8'd49;
             end
         7 : begin memory1a <= {1'b0,C7}; // 8'd25;  
                   memory2a <= {1'b1,S3}; //-8'd71; 
                   memory3a <= {1'b0,C3}; // 8'd106;  
                   memory4a <= {1'b1,S7}; //-8'd126;
             end
        endcase
    end

    always @ (posedge clk) begin
        xb0_in <= tdin;
        xb1_in <= xb0_in;
        xb2_in <= xb1_in;
        xb3_in <= xb2_in;
        xb4_in <= xb3_in;
        xb5_in <= xb4_in;
        xb6_in <= xb5_in;
        xb7_in <= xb6_in;
    end

/* register inputs, inputs read in every eighth clk*/

    always @ (posedge clk) if (sxregs) begin
        xb0_reg <= xb0_in;
        xb1_reg <= xb1_in; 
        xb2_reg <= xb2_in;
        xb3_reg <= xb3_in;
        xb4_reg <= xb4_in;
        xb5_reg <= xb5_in; 
        xb6_reg <= xb6_in;
        xb7_reg <= xb7_in;
    end

    always @ (posedge clk)
        if (toggleB == 1'b1) begin
            add_sub1b <= {xb7_reg[15],xb7_reg[15:0]} + {xb0_reg[15],xb0_reg[15:0]};
            add_sub2b <= {xb6_reg[15],xb6_reg[15:0]} + {xb1_reg[15],xb1_reg[15:0]};
            add_sub3b <= {xb5_reg[15],xb5_reg[15:0]} + {xb2_reg[15],xb2_reg[15:0]};
            add_sub4b <= {xb4_reg[15],xb4_reg[15:0]} + {xb3_reg[15],xb3_reg[15:0]};
        end else begin
            add_sub1b <= {xb7_reg[15],xb7_reg[15:0]} - {xb0_reg[15],xb0_reg[15:0]};
            add_sub2b <= {xb6_reg[15],xb6_reg[15:0]} - {xb1_reg[15],xb1_reg[15:0]};
            add_sub3b <= {xb5_reg[15],xb5_reg[15:0]} - {xb2_reg[15],xb2_reg[15:0]};
            add_sub4b <= {xb4_reg[15],xb4_reg[15:0]} - {xb3_reg[15],xb3_reg[15:0]};
        end
// Adding these wires to get rid of the MSB that is always 0
    wire [16:0] addsub1b_comp_w  = add_sub1b[16]? (-add_sub1b) : add_sub1b;
    wire [16:0] addsub2b_comp_w  = add_sub2b[16]? (-add_sub2b) : add_sub2b;
    wire [16:0] addsub3b_comp_w  = add_sub3b[16]? (-add_sub3b) : add_sub3b;
    wire [16:0] addsub4b_comp_w  = add_sub4b[16]? (-add_sub4b) : add_sub4b;

    always @ (posedge clk) begin
        save_sign1b    <= add_sub1b[16];
        save_sign2b    <= add_sub2b[16];
        save_sign3b    <= add_sub3b[16];
        save_sign4b    <= add_sub4b[16];
        addsub1b_comp	<= addsub1b_comp_w[15:0]; // add_sub1b[16]? (-add_sub1b) : add_sub1b;
        addsub2b_comp	<= addsub2b_comp_w[15:0]; // add_sub2b[16]? (-add_sub2b) : add_sub2b;
        addsub3b_comp	<= addsub3b_comp_w[15:0]; // add_sub3b[16]? (-add_sub3b) : add_sub3b;
        addsub4b_comp	<= addsub4b_comp_w[15:0]; // add_sub4b[16]? (-add_sub4b) : add_sub4b;
    end

//    assign p1b_all = addsub1b_comp[15:0] * memory1a[15:0]; // TODO: Check - memory is 16:0
//    assign p2b_all = addsub2b_comp[15:0] * memory2a[15:0];
//    assign p3b_all = addsub3b_comp[15:0] * memory3a[15:0];
//   assign p4b_all = addsub4b_comp[15:0] * memory4a[15:0];

    assign p1b_all = addsub1b_comp * memory1a; // AF2015: TODO: Check - memory is 16:0
    assign p2b_all = addsub2b_comp * memory2a;
    assign p3b_all = addsub3b_comp * memory3a;
    assign p4b_all = addsub4b_comp * memory4a;


    always @ (posedge clk) begin
/// Next line was simulated differently in Icarus 0.9 (wrong?) than in Icarus 0.8 (right?)
/// Xilinx probably did as 0.8
/// p1b_all[31:14] - 18-bit number, p1b - 19-bit. in 0.9 (-p1b_all[31:14]) was also 18, not expand to 19 bits, 0.8 - did
///        p1b <= (save_sign1b ^ memory1a[16]) ? (-p1b_all[31:14]) :(p1b_all[31:14]);
        p1b[18:0] <= (save_sign1b ^ memory1a[16]) ? (-p1b_all[32:14]) :(p1b_all[32:14]);
        p2b[18:0] <= (save_sign2b ^ memory2a[16]) ? (-p2b_all[32:14]) :(p2b_all[32:14]);
        p3b[18:0] <= (save_sign3b ^ memory3a[16]) ? (-p3b_all[32:14]) :(p3b_all[32:14]);
        p4b[18:0] <= (save_sign4b ^ memory4a[16]) ? (-p4b_all[32:14]) :(p4b_all[32:14]);
    end

/* multiply the outputs of the add/sub block with the 8 sets of stored coefficients */

/* Final adder. Adding the ouputs of the 4 multipliers */
    always @ (posedge clk) begin
        dct2d_int1 <= ({p1b[18],p1b[18:0]} + {p2b[18],p2b[18:0]});
        dct2d_int2 <= ({p3b[18],p3b[18:0]} + {p4b[18],p4b[18:0]});
        dct_2d_int <= ({dct2d_int1[19],dct2d_int1[19:0]} + {dct2d_int2[19],dct2d_int2[19:0]});
    end

    assign dct_2d_rnd[12:0] = dct_2d_int[20:8];
    assign dct2_out[12:0] = dct_2d_rnd[12:0] + dct_2d_int[7];
endmodule
