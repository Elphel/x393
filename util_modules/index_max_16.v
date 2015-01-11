/*******************************************************************************
 * Module: index_max_16
 * Date:2015-01-09  
 * Author: andrey     
 * Description: Find index of the maximal of 16 values (masked), 4 cycle latency
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * index_max_16.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  index_max_16.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  index_max_16 #(
    parameter width=16
    ) (
    input                clk,
    input [16*width-1:0] values,
    input         [15:0] mask,
    input                need_in, // at least one of the channels needs access 
    output        [ 3:0] index,
    output               valid,
    output               need_out // need_in with matching delay
);
    wire [width-1:0] max0001,max0203,max0405,max0607,max0809,max1011,max1213,max1415,max00010203,max04050607,max08091011, max12131415; 
    wire [width-1:0] max0001020304050607,max0809101112131415; 
    wire sel0001,sel0203,sel0405,sel0607,sel0809,sel1011,sel1213,sel1415,sel00010203,sel04050607;
    wire sel08091011, sel12131415, sel0001020304050607,sel0809101112131415, sel; 
    reg  sel0001_r,sel0203_r,sel0405_r,sel0607_r,sel0809_r,sel1011_r,sel1213_r,sel1415_r;
    reg  [1:0] sel00010203_r,sel04050607_r,sel08091011_r, sel12131415_r;
    reg  [2:0] sel0001020304050607_r,sel0809101112131415_r;
    reg  [3:0] valid_dly;
    reg  [3:0] need_dly;

// 1-st layer
    masked_max_reg #(width) i_masked_max_reg0001(
        .clk(clk),
        .a(values[width*0 +: width]),
        .mask_a(mask[0]),
        .b(values[width*1 +: width]),
        .mask_b(mask[1]),
        .max(max0001),
        .s(sel0001));
    masked_max_reg #(width) i_masked_max_reg0203(
        .clk(clk),
        .a(values[width*2 +: width]),
        .mask_a(mask[2]),
        .b(values[width*3 +: width]),
        .mask_b(mask[3]),
        .max(max0203),
        .s(sel0203));
    masked_max_reg #(width) i_masked_max_reg0405(
        .clk(clk),
        .a(values[width*4 +: width]),
        .mask_a(mask[4]),
        .b(values[width*5 +: width]),
        .mask_b(mask[5]),
        .max(max0405),
        .s(sel0405));
    masked_max_reg #(width) i_masked_max_reg0607(
        .clk(clk),
        .a(values[width*6 +: width]),
        .mask_a(mask[6]),
        .b(values[width*7 +: width]),
        .mask_b(mask[7]),
        .max(max0607),
        .s(sel0607));
    masked_max_reg #(width) i_masked_max_reg0809(
        .clk(clk),
        .a(values[width*8 +: width]),
        .mask_a(mask[8]),
        .b(values[width*9 +: width]),
        .mask_b(mask[9]),
        .max(max0809),
        .s(sel0809));
    masked_max_reg #(width) i_masked_max_reg1011(
        .clk(clk),
        .a(values[width*10 +: width]),
        .mask_a(mask[10]),
        .b(values[width*11 +: width]),
        .mask_b(mask[11]),
        .max(max1011),
        .s(sel1011));
    masked_max_reg #(width) i_masked_max_reg1213(
        .clk(clk),
        .a(values[width*12 +: width]),
        .mask_a(mask[12]),
        .b(values[width*13 +: width]),
        .mask_b(mask[13]),
        .max(max1213),
        .s(sel1213));
    masked_max_reg #(width) i_masked_max_reg1415(
        .clk(clk),
        .a(values[width*14 +: width]),
        .mask_a(mask[14]),
        .b(values[width*15 +: width]),
        .mask_b(mask[15]),
        .max(max1415),
        .s(sel1415));
        
// 2-nd layer
    masked_max_reg #(width) i_masked_max_reg00010203(
        .clk(clk),
        .a(max0001),
        .mask_a(&mask[1:0]),
        .b(max0203),
        .mask_b(&mask[3:2]),
        .max(max00010203),
        .s(sel00010203));
    masked_max_reg #(width) i_masked_max_reg04050607(
        .clk(clk),
        .a(max0405),
        .mask_a(&mask[5:4]),
        .b(max0607),
        .mask_b(&mask[7:6]),
        .max(max04050607),
        .s(sel04050607));
    masked_max_reg #(width) i_masked_max_reg08091011(
        .clk(clk),
        .a(max0809),
        .mask_a(&mask[9:8]),
        .b(max1011),
        .mask_b(&mask[11:10]),
        .max(max08091011),
        .s(sel08091011));
    masked_max_reg #(width) i_masked_max_reg12131415(
        .clk(clk),
        .a(max1213),
        .mask_a(&mask[13:12]),
        .b(max1415),
        .mask_b(&mask[15:14]),
        .max(max12131415),
        .s(sel12131415));
// 3-nd layer
    masked_max_reg #(width) i_masked_max_reg0001020304050607(
        .clk(clk),
        .a(max00010203),
        .mask_a(&mask[3:0]),
        .b(max04050607),
        .mask_b(&mask[7:4]),
        .max(max0001020304050607),
        .s(sel0001020304050607));
    masked_max_reg #(width) i_masked_max_reg0809101112131415(
        .clk(clk),
        .a(max08091011),
        .mask_a(&mask[11:8]),
        .b(max12131415),
        .mask_b(&mask[15:12]),
        .max(max0809101112131415),
        .s(sel0809101112131415));
// 4-th layer
    masked_max_reg #(width) i_masked_max_reg(
        .clk(clk),
        .a(max0001020304050607),
        .mask_a(&mask[7:0]),
        .b(max0809101112131415),
        .mask_b(&mask[15:8]),
        .max(),
        .s(sel));
    always @ (posedge clk) begin
        sel0001_r<=sel0001;
        sel0203_r<=sel0203;
        sel0405_r<=sel0405;
        sel0607_r<=sel0607;
        sel0809_r<=sel0809;
        sel1011_r<=sel1011;
        sel1213_r<=sel1213;
        sel1415_r<=sel1415;
        sel00010203_r[1:0]<={sel00010203,sel00010203?sel0203_r:sel0001_r};
        sel04050607_r[1:0]<={sel04050607,sel04050607?sel0607_r:sel0405_r};
        sel08091011_r[1:0]<={sel08091011,sel08091011?sel1011_r:sel0809_r};
        sel12131415_r[1:0]<={sel12131415,sel12131415?sel1415_r:sel1213_r};
        sel0001020304050607_r[2:0]<={sel0001020304050607,sel0001020304050607?sel04050607_r[1:0]:sel00010203_r[1:0]};
        sel0809101112131415_r[2:0]<={sel0809101112131415,sel0809101112131415?sel12131415_r[1:0]:sel08091011_r[1:0]};
        valid_dly[3:0] <= {valid_dly[2:0],|mask[15:0]};
        need_dly[3:0]  <= {need_dly[2:0],need_in};
    end
assign index[3:0]={
                sel,
                sel?sel0809101112131415_r[2:0]:sel0001020304050607_r[2:0]};
                
assign valid=valid_dly[3];
assign need_out=need_dly[3];
endmodule

