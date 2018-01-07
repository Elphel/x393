/*!
 * <b>Module:</b> mclt_wnd_sres4
 * @file mclt_wnd_sres4.v
 * @date 2017-12-06  
 * @author Andrey Filippov
 *     
 * @brief MCLT window w/o MPY (4:1 superresolution)
 *
 * @copyright Copyright (c) 2017 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 *
 * <b>License </b>
 *
 * mclt_wnd_sres4.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * mclt_wnd_sres4.v is distributed in the hope that it will be useful,
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
// Latency = 4
module  mclt_wnd_sres4#(
    parameter SHIFT_WIDTH =  3,  // bits in shift (1 bit - integer, 2 bits - fractional
    parameter COORD_WIDTH =  5,  // bits in full coordinate 10/2 for 18K RAM 
    parameter OUT_WIDTH =   18   // bits in window value (positive) 
)(
    input                          clk,   //!< system clock, posedge
    input                          en,    //!< re (both re and ren - just for power)
    input                    [3:0] x_in,  //!< tile pixel X
    input                    [3:0] y_in,  //!< tile pixel Y
    input        [SHIFT_WIDTH-1:0] x_shft,  //!< tile pixel X
    input        [SHIFT_WIDTH-1:0] y_shft,  //!< tile pixel Y
    output     [OUT_WIDTH - 1 : 0] wnd_out            
);
    wire [COORD_WIDTH - 1 : 0] x_full;
    wire [COORD_WIDTH - 1 : 0] y_full;
    wire                       x_zero;
    wire                       y_zero;
    reg                  [1:0] zero; // x_zero | y_zero;
    reg                  [2:0] regen; // 
    always @ (posedge clk) begin
        regen <= {regen[1:0],en};
        zero <= {1'b0, x_zero | y_zero};
    
    end

    mclt_full_shift #(
        .COORD_WIDTH(COORD_WIDTH),
        .SHIFT_WIDTH(SHIFT_WIDTH)
    ) mclt_full_shift_x_i (
        .clk       (clk),    // input
        .coord     (x_in),   // input[3:0] 
        .shift     (x_shft), // input[2:0] signed 
        .coord_out (x_full), // output[4:0] reg 
        .zero      (x_zero) // output reg 
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

    ram18pr_var_w_var_r #(
        .REGISTERS(1),
        .LOG2WIDTH_WR(4),
        .LOG2WIDTH_RD(4),
        .DUMMY(0)
`ifdef PRELOAD_BRAMS
    `include "mclt_wnd_sres4.vh"
`endif
    ) i_wnd_rom (
        .rclk     (clk),             // input
        .raddr    ({y_full,x_full}), // input[9:0] 
        .ren      (regen[1]),        // input
        .regen    (regen[2]),        // input
        .rrst     (1'b0),            // input
        .regrst   (zero[1]),         // input
        .data_out (wnd_out),         // output[17:0] 
        .wclk     (1'b0),            // input
        .waddr    (10'b0),           // input[9:0] 
        .we       (1'b0),            // input
        .web      (4'hf),            // input[3:0] 
        .data_in  (18'b0)            // input[17:0] 
    );

endmodule

