/*!
 * <b>Module:</b>gpio393_bit
 * @file gpio393.v
 * @date 2015-07-06  
 * @author Andrey Filippov     
 *
 * @brief Control of the 10 GPIO signals of the 10393 board
 * Converted from twelve_ios.v of the x353 project (2005)
 *
 * @copyright Copyright (c) 2005-2015 Elphel, Inc.
 *
 * <b>License:</b>
 *
 * gpio393.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  gpio393.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *
 * Additional permission under GNU GPL version 3 section 7:
 * If you modify this Program, or any covered work, by linking or combining it
 * with independent modules provided by the FPGA vendor only (this permission
 * does not extend to any 3-rd party modules, "soft cores" or macros) under
 * different license terms solely for the purpose of generating binary "bitstream"
 * files and/or simulating the code, the copyright holders of this Program give
 * you the right to distribute the covered work without those independent modules
 * as long as the source code for them is available from the FPGA vendor free of
 * charge, and there is no dependence on any encrypted modules for simulating of
 * the combined code. This permission applies to you if the distributed code
 * contains all the components and scripts required to completely simulate it
 * with at least one of the Free Software programs.
 */
`timescale 1ns/1ps


// update to eliminate need for a shadow register
// each pair of data bits at write cycle control the data and enable in the following way:
// bit 1 bit 0  dibit  enable data
//   0     0      0    - no change -
//   0     1      1      1      0
//   1     0      2      1      1
//   1     1      3      0      0

module gpio393_bit (
//    input         rst,          // global reset
    input         clk,          // system clock
    input         srst,         // @posedge clk - sync reset
    input         we,
    input   [1:0] d_in,         // input bits
    output        d_out,        // output data
    output        en_out);      // enable output
    
    reg d_r = 0;
    reg en_r = 0;
    
    assign d_out = d_r;
    assign en_out = en_r;
    always @ (posedge clk) begin
        if (srst)               d_r <= 0;
        else if (we && (|d_in)) d_r <= !d_in[0];

        if (srst)               en_r <= 0;
        else if (we && (|d_in)) en_r <= !(&d_in);
    end 
    
endmodule
