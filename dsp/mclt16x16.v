/*!
 * <b>Module:</b> mclt16x16
 * @file mclt16x16.v
 * @date 2017-12-07  
 * @author eyesis
 *     
 * @brief Direct MCLT of 16x16 tile with subpixel window shift
 *
 * @copyright Copyright (c) 2017 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 *
 * <b>License </b>
 *
 * mclt16x16.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * mclt16x16.v is distributed in the hope that it will be useful,
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

module  mclt16x16#(
    parameter SHIFT_WIDTH =  8,  // bits in shift (1 bit - integer, 7 bits - fractional
    parameter COORD_WIDTH = 10,  // bits in full coordinate 10 for 18K RAM
    parameter PIXEL_WIDTH = 18,  // input pixel width (unsigned) 
    parameter OUT_WIDTH =   18   // bits in window value (positive) 
)(
    input                          clk,          //!< system clock, posedge
    input                          rst,           //!< sync reset
    input                          en,           //!< re (both re and ren - just for power)
    input                          start,        //!< start convertion of the next 256 samples
    input        [SHIFT_WIDTH-1:0] x_shft,       //!< tile pixel X fractional shift (valid @ start) 
    input        [SHIFT_WIDTH-1:0] y_shft,       //!< tile pixel Y fractional shift (valid @ start)
    input                    [3:0] bayer,        // bayer mask (0 bits - skip pixel, valid @ start)
    output                   [7:0] mpixel_a,     //!< pixel address {y,x} of the input tile
    input        [PIXEL_WIDTH-1:0] mpixel_d,     //!< pixel data, latency = 2 from pixel address
    output                         pre2_rdy,     //!< after next cycle may be start of the next block          
    output                         pre_last_in,  //!< may increment page
    output                         pre_first_out,//!< next will output first of DCT/DCT coefficients          
    output                         pre_last_out, //!< next will be last output of DST/DST coefficients
    output                   [7:0] out_addr,     //!< address to save coefficients, 2 MSBs - mode (CC,SC,CS,SS), others - down first         
    output                         dv,           //!< output data valid
    output     [OUT_WIDTH - 1 : 0] dout          //<frequency domain data output            
);

    reg [SHIFT_WIDTH-1:0] x_shft_r;
    reg [SHIFT_WIDTH-1:0] y_shft_r;
    reg             [3:0] bayer_r;
    always @ (posedge clk) begin
    end

endmodule

