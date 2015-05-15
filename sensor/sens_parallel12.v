/*******************************************************************************
 * Module: sens_parallel12
 * Date:2015-05-10  
 * Author: andrey     
 * Description: Sensor interface with 12-bit for parallel bus
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * sens_parallel12.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  sens_parallel12.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  sens_parallel12 (
    input         rst,
    input         pclk, // global clock input, pixel rate (96MHz for MT9P006)
    input         pclk2x, // maybe not needed here
    // sensor pads excluding i2c
    input         vact,
    input         hact, //output in fillfactory mode
    inout         bpf,  // output in fillfactory mode
    inout  [11:0] pxd, //actually only 2 LSBs are inouts
    inout         mrst,
    output        arst,
    output        aro,
    // output
    output [15:0] ipxd,
    output        vacts, 
    
    
    // programming interface
    input         mclk,     // global clock, half DDR3 clock, synchronizes all I/O thorough the command port
    input   [7:0] cmd_ad,      // byte-serial command address/data (up to 6 bytes: AL-AH-D0-D1-D2-D3 
    input         cmd_stb,     // strobe (with first byte) for the command a/d
    output  [7:0] status_ad,   // status address/data - up to 5 bytes: A - {seq,status[1:0]} - status[2:9] - status[10:17] - status[18:25]
    output        status_rq,   // input request to send status downstream
    input         status_start // Acknowledge of the first status packet byte (address)
);


endmodule

