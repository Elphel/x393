/*******************************************************************************
 * Module: mcntrl_1kx32w
 * Date:2015-02-03  
 * Author: andrey     
 * Description: Paged buffer for ddr3 controller write channel
 * with address autoincrement. 32 bit external data. Extends rd to regen
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * mcntrl_1kx32w.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  mcntrl_1kx32w.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  mcntrl_1kx32w(
      input         ext_clk,
      input  [ 9:0] ext_waddr,    // external write address
      input         ext_we,       // external write enable
      input [31:0] ext_data_in,  // data input
      
      input         rclk,         // mclk
      input  [1:0]  rpage,        // will register to wclk, input OK with mclk
      input         raddr_reset,  // reset buffer read address (to page start)
      input         skip_reset,   // ignore waddr_reset (resync to wclk)   
      input         rd,           // read buffer tomemory, increment read address (regester enable will be delayed)
      output [63:0] data_out      // data out

);
    reg        skip_reset_rclk;
    reg  [6:0] raddr;
    reg        regen;
    always @ (posedge rclk) begin
        regen <= rd;
        
        skip_reset_rclk <= skip_reset;
        
        if (raddr_reset && !skip_reset_rclk) raddr <= 0;
        else if (rd)                         raddr <= raddr +1;
    end
    ram_1kx32w_512x64r #(
        .REGISTERS(1)
    )ram_1kx32w_512x64r_i (
        .rclk     (rclk),                        // input
        .raddr    ({rpage,raddr}), // input[8:0] 
        .ren      (rd),                 // input
        .regen    (regen),                 // input
        .data_out (data_out),              // output[63:0] 
        .wclk     (ext_clk),                     // input
        .waddr    (ext_waddr),                   // input[9:0] 
        .we       (ext_we),                     // input
        .web      (4'hf),                        // input[3:0] 
        .data_in  (ext_data_in)                    // input[31:0] 
    );


endmodule

