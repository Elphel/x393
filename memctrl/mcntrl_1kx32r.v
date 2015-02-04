/*******************************************************************************
 * Module: mcntrl_1kx32r
 * Date:2015-02-03  
 * Author: andrey     
 * Description: Paged buffer for ddr3 controller read channel
 * with address autoincrement. 32 bit external data.
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * mcntrl_1kx32r.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  mcntrl_1kx32r.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  mcntrl_1kx32r(
      input         ext_clk,
      input  [ 9:0] ext_raddr,    // read address
      input         ext_rd,       // read port enable
      input         ext_regen,    // output register enable
      output [31:0] ext_data_out, // data out
      
      input         wclk,         // !mclk (inverted)
      input  [1:0]  wpage,        // will register to wclk, input OK with mclk
      input         waddr_reset,  // reset write buffer address (to page start), sync to wclk (!mclk)
      input         skip_reset,   // ignore waddr_reset (resync to wclk)   
      input         we,           // write port enable (also increment write buffer address)
      input  [63:0] data_in       // data in
);
    reg  [1:0] wpage_wclk;
    reg        skip_reset_wclk;
    reg  [6:0] waddr;
    always @ (posedge wclk) begin
        wpage_wclk <= wpage;
        skip_reset_wclk <= skip_reset;
        if (waddr_reset && !skip_reset_wclk) waddr <= 0;
        else if (we)                         waddr <= waddr +1;
    end
    ram_512x64w_1kx32r #(
        .REGISTERS(1)
    ) ram_512x64w_1kx32r_i (
        .rclk     (ext_clk),              // input
        .raddr    (ext_raddr),            // input[9:0] 
        .ren      (ext_rd),               // input
        .regen    (ext_regen),            // input
        .data_out (ext_data_out),         // output[31:0] 
        .wclk     (wclk),                 // input - OK, negedge mclk
        .waddr    ({wpage_wclk,waddr}),   // input[8:0] @negedge mclk
        .we       (we),                   // input @negedge mclk
        .web      (8'hff),                // input[7:0]
        .data_in  (data_in)        // input[63:0]  @negedge mclk
    );
endmodule

