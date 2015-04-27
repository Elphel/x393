/*******************************************************************************
 * Module: mcntrl_buf_rd
 * Date:2015-02-03  
 * Author: andrey     
 * Description: Paged buffer for ddr3 controller read channel
 * with address autoincrement. Variable width external data
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * mcntrl_buf_rd.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  mcntrl_buf_rd.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  mcntrl_buf_rd #(
    parameter integer LOG2WIDTH_RD = 5   // WIDTH= 1  << LOG2WIDTH
 ) (
      input                            ext_clk,
      input        [14-LOG2WIDTH_RD:0] ext_raddr,    // read address
      input                            ext_rd,       // read port enable
      input                            ext_regen,    // output register enable
      output [(1 << LOG2WIDTH_RD)-1:0] ext_data_out, // data out
      
      input                            wclk,         // !mclk (inverted)
      input                      [1:0] wpage_in,     // will register to wclk, input OK with mclk
      input                            wpage_set,    // set internal read page to rpage_in 
      input                            page_next,    // advance to next page (and reset lower bits to 0)
      output                     [1:0] page,         // current inernal page   
      input                            we,           // write port enable (also increment write buffer address)
      input                     [63:0] data_in       // data in
);
    reg  [1:0] page_r;
    reg  [6:0] waddr;
    assign page=page_r;
    always @ (posedge wclk) begin
    
        if      (wpage_set) page_r <= wpage_in;
        else if (page_next) page_r <= page_r+1;

        if      (page_next || wpage_set) waddr <= 0;
        else if (we)                     waddr <= waddr+1;
    end
//    ram_512x64w_1kx32r #(
    ram_var_w_var_r #(
        .REGISTERS(1),
        .LOG2WIDTH_WR(6),
        .LOG2WIDTH_RD(LOG2WIDTH_RD)
    ) ram_512x64w_1kx32r_i (
        .rclk     (ext_clk),              // input
        .raddr    (ext_raddr),            // input[9:0] 
        .ren      (ext_rd),               // input
        .regen    (ext_regen),            // input
        .data_out (ext_data_out),         // output[31:0] 
        .wclk     (wclk),                 // input - OK, negedge mclk
        .waddr    ({page,waddr}),         // input[8:0] @negedge mclk
        .we       (we),                   // input @negedge mclk
        .web      (8'hff),                // input[7:0]
        .data_in  (data_in)               // input[63:0]  @negedge mclk
    );
endmodule

