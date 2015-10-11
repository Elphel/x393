/*******************************************************************************
 * Module: par12_hispi_psp4l
 * Date:2015-10-11  
 * Author: andrey     
 * Description: Convertp parallel 12bit to HiSPi packetized-SP 4 lanes
 *
 * Copyright (c) 2015 Elphel, Inc .
 * par12_hispi_psp4l.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  par12_hispi_psp4l.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  par12_hispi_psp4l#(
    parameter CLOCK_MPY =     10,
    parameter CLOCK_DIV =      3,
    parameter LANE0_DLY =      1.3,
    parameter LANE1_DLY =      2.7,
    parameter LANE2_DLY =      0.2,
    parameter LANE3_DLY =      3.3,
    parameter BLANK_LINES =    2,
    parameter MAX_LINE =    8192
)(
    input        pclk,
    input        rst,
    input [11:0] pxd,
    input        vact,
    input        hact,
    output [3:0] lane_p,
    output [3:0] lane_n,
    output       clk_p,
    output       clk_n
);


endmodule

