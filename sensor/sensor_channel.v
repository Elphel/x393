/*******************************************************************************
 * Module: sensor_channel
 * Date:2015-05-10  
 * Author: andrey     
 * Description: Top module for a sensor channel
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * sensor_channel.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  sensor_channel.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  sensor_channel#(
    parameter SENSI2C_ABS_ADDR =    'h300,
    parameter SENSI2C_REL_ADDR =    'h310,
    parameter SENSI2C_ADDR_MASK =   'h3f0, // both for SENSI2C_ABS_ADDR and SENSI2C_REL_ADDR
    parameter SENSI2C_CTRL_ADDR =   'h320,
    parameter SENSI2C_CTRL_MASK =   'h3fe,
    parameter SENSI2C_CTRL =        'h0,
    parameter SENSI2C_STATUS =      'h1,
    parameter SENSI2C_STATUS_REG =  'h30,
    parameter integer DRIVE = 12,
    parameter IBUF_LOW_PWR = "TRUE",
    parameter IOSTANDARD = "DEFAULT",
`ifdef XIL_TIMING
    parameter LOC = " UNPLACED",
`endif
    parameter SLEW = "SLOW"
) (
    input rst,
    input pclk, // global clock input, pixel rate (96MHz for MT9P006)
    // I/O pads, pin names match circuit diagram
    inout [7:0] sns_dp,
    inout [7:0] sns_dn,
    inout       sns_clkp,
    inout       sns_scl,
    inout       sns_sda,
    inout       sns_ctl,
    inout       sns_pg,
    // programming interface
    input        mclk,     // global clock, half DDR3 clock, synchronizes all I/O thorough the command port
    input   [7:0] cmd_ad,      // byte-serial command address/data (up to 6 bytes: AL-AH-D0-D1-D2-D3 
    input         cmd_stb,     // strobe (with first byte) for the command a/d
    output  [7:0] status_ad,   // status address/data - up to 5 bytes: A - {seq,status[1:0]} - status[2:9] - status[10:17] - status[18:25]
    output        status_rq,   // input request to send status downstream
    input         status_start // Acknowledge of the first status packet byte (address)
// (much) more will be added later    
    
);
    sensor_i2c_io #(
        .SENSI2C_ABS_ADDR(SENSI2C_ABS_ADDR),
        .SENSI2C_REL_ADDR(SENSI2C_REL_ADDR),
        .SENSI2C_ADDR_MASK(SENSI2C_ADDR_MASK),
        .SENSI2C_CTRL_ADDR(SENSI2C_CTRL_ADDR),
        .SENSI2C_CTRL_MASK(SENSI2C_CTRL_MASK),
        .SENSI2C_CTRL(SENSI2C_CTRL),
        .SENSI2C_STATUS(SENSI2C_STATUS),
        .SENSI2C_STATUS_REG(SENSI2C_STATUS_REG),
        .SENSI2C_DRIVE(SENSI2C_DRIVE),
        .SENSI2C_IBUF_LOW_PWR(SENSI2C_IBUF_LOW_PWR),
        .SENSI2C_IOSTANDARD(SENSI2C_IOSTANDARD),
        .SENSI2C_SLEW(SENSI2C_SLEW)
    ) sensor_i2c_io_i (
        .rst(), // input
        .mclk(), // input
        .cmd_ad(), // input[7:0] 
        .cmd_stb(), // input
        .status_ad(), // output[7:0] 
        .status_rq(), // output
        .status_start(), // input
        .frame_sync(), // input
        .scl(), // inout
        .sda() // inout
    );


endmodule

