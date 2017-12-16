/*!
 * <b>Module:</b> mclt_wnd_mul
 * @file mclt_wnd_mul.v
 * @date 2017-12-06  
 * @author eyesis
 *     
 * @brief MCLT window with MPY (128:1 superresolution)
 *
 * @copyright Copyright (c) 2017 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 *
 * <b>License </b>
 *
 * mclt_wnd_mul.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * mclt_wnd_mul.v is distributed in the hope that it will be useful,
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
// Latency = 5
module  mclt_wnd_mul#(
    parameter SHIFT_WIDTH =  7,  // bits in shift (0 bits - integer, 7 bits - fractional
    parameter COORD_WIDTH = 10,  // bits in full coordinate 10 for 18K RAM 
    parameter OUT_WIDTH =   18   // bits in window value (positive) 
)(
    input                           clk,   //!< system clock, posedge
    input                           en,    //!< re (both re and ren - just for power)
    input                     [3:0] x_in,  //!< tile pixel X
    input                     [3:0] y_in,  //!< tile pixel Y
    input         [SHIFT_WIDTH-1:0] x_shft,  //!< tile pixel X
    input         [SHIFT_WIDTH-1:0] y_shft,  //!< tile pixel Y
    output signed [OUT_WIDTH - 1 : 0] wnd_out            
);
    wire        [COORD_WIDTH - 1 : 0] x_full;
    wire        [COORD_WIDTH - 1 : 0] y_full;
    wire                              x_zero;
    wire                              y_zero;
//    reg                  [1:0] zero; // x_zero | y_zero;
    reg                               zero; // x_zero | y_zero;
    reg                         [2:0] regen; //
    wire signed   [OUT_WIDTH - 1 : 0] wnd_out_x;   // should be all positive         
    wire signed   [OUT_WIDTH - 1 : 0] wnd_out_y;   // should be all positive         
    reg  signed   [OUT_WIDTH - 1 : 0] wnd_out_x_r; // to be absorbed in DSP            
    reg  signed   [OUT_WIDTH - 1 : 0] wnd_out_y_r; // to be absorbed in DSP            
    reg  signed [2*OUT_WIDTH - 1 : 0] wnd_out_r;   // should be all positive
    assign wnd_out = wnd_out_r[2 * OUT_WIDTH - 2: OUT_WIDTH-1];
     
    always @ (posedge clk) begin
        regen <= {regen[1:0],en};
        wnd_out_x_r <= wnd_out_x;
        wnd_out_y_r <= wnd_out_y;
//        zero <= {zero[0],  x_zero | y_zero};
        zero <= x_zero | y_zero;
        wnd_out_r <= wnd_out_x_r * wnd_out_y_r;
    end

    mclt_full_shift #(
        .COORD_WIDTH(COORD_WIDTH),
        .SHIFT_WIDTH(SHIFT_WIDTH)
    ) mclt_full_shift_x_i (
        .clk       (clk),    // input
        .coord     (x_in),   // input[3:0] 
        .shift     (x_shft), // input[2:0] signed 
        .coord_out (x_full), // output[4:0] reg 
        .zero      (x_zero)  // output reg 
    );

    mclt_full_shift #(
        .COORD_WIDTH(COORD_WIDTH),
        .SHIFT_WIDTH(SHIFT_WIDTH)
    ) mclt_full_shift_y_i (
        .clk       (clk),    // input
        .coord     (y_in),   // input[3:0] 
        .shift     (y_shft), // input[2:0] signed 
        .coord_out (y_full), // output[4:0] reg 
        .zero      (y_zero) // output reg 
    );

     ram18tpr_var_w_var_r #(
        .REGISTERS_A(1),
        .REGISTERS_B(1),
        .LOG2WIDTH_A(4),
        .LOG2WIDTH_B(4)
`ifdef PRELOAD_BRAMS
    `include "mclt_wnd_mul.vh"
`endif
    ) i_wnd_rom (
    
        .clk_a     (clk),       // input
        .addr_a    (x_full),    // input[9:0] 
        .en_a      (regen[1]),  // input
        .regen_a   (regen[2]),  // input
        .we_a      (1'b0),      // input
        .rrst_a    (1'b0),      // input
        .regrst_a  (zero),      // input
        .data_out_a(wnd_out_x), // output[17:0] 
        .data_in_a (18'b0),     // input[17:0] 
        .clk_b     (clk),       // input
        .addr_b    (y_full),    // input[9:0] 
        .en_b      (regen[1]),  // input
        .regen_b   (regen[2]),  // input
        .we_b      (1'b0),      // input
        .rrst_b    (1'b0),      // input
        .regrst_b  (zero),      // input
        .data_out_b(wnd_out_y), // output[17:0] 
        .data_in_b (18'b0)      // input[17:0] 
    );

endmodule

