/*******************************************************************************
 * <b>Module:</b>dct1d_chen_reorder_out
 * @file dct1d_chen_reorder_out.v
 * @date:2016-06-08  
 * @author: Andrey Filippov
 *     
 * @brief: Reorder data from dct1d_chen output to natural sequence
 *
 * @copyright Copyright (c) 2016 Elphel, Inc.
 *
 * <b>License:</b>
 *
 *dct1d_chen_reorder_out.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  dct1d_chen_reorder_out.v is distributed in the hope that it will be useful,
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
 *******************************************************************************/
`timescale 1ns/1ps

module  dct1d_chen_reorder_out#(
    parameter WIDTH = 24
 )(
    input                  clk,
    input                  rst,
    input  [WIDTH -1:0]    din,       // pre2_start-X-F4-X-F2-X-F6-F5-F0-F3-X-F1-X-F7
    input                  pre2_start,     // Two cycles ahead of F4 
    output   [WIDTH -1:0]  dout,      // data in natural order: F0-F1-F2-F3-F4-F5-F6-F7
    output                 start_out, // 1 ahead of F0
    output reg             en_out // to be sampled when start_out is expected
);
    reg [WIDTH -1:0] reord_buf_ram[0:15];
    reg [WIDTH -1:0] dout_r;
    reg  [3:0] cntr_in;
    wire       start_8;
    wire       start_11;
    reg        start_12;
    wire       stop_in;
    reg        we_r;
    reg  [3:0] ina_rom;
    wire [3:0] waddr = {ina_rom[3] ^ cntr_in[3], ina_rom[2:0]};   
    reg  [3:0] raddr;
    assign dout = dout_r; 
    assign start_out = start_12;
    always @(posedge clk) begin
        if      (rst)        we_r <= 0;
        else if (pre2_start) we_r <= 1;
        else if (stop_in)    we_r <= 0;
        
        if      (rst)        cntr_in <= 0;
        else if (pre2_start) cntr_in <= {~cntr_in[3],3'b0};
        else if (we_r)       cntr_in <= cntr_in + 1;
        case (cntr_in[2:0])
            3'h0: ina_rom <= {1'b0,3'h4};
            3'h1: ina_rom <= {1'b1,3'h1};
            3'h2: ina_rom <= {1'b0,3'h2};
            3'h3: ina_rom <= {1'b1,3'h7};
            3'h4: ina_rom <= {1'b0,3'h6};
            3'h5: ina_rom <= {1'b0,3'h5};
            3'h6: ina_rom <= {1'b0,3'h0};
            3'h7: ina_rom <= {1'b0,3'h3};
        endcase
        
        if (we_r) reord_buf_ram[waddr] <= din;

        if      (start_11)                  raddr <= {~cntr_in[3], 3'b0};
        else if ((raddr[2:0] != 0) || we_r) raddr <= raddr + 1;
        
        dout_r <=  reord_buf_ram[raddr];
        
        start_12 <= start_11;
        
        en_out <= start_12 || (raddr[2:0] != 0); 
        
    end

    dly01_16 start_8__i (
        .clk   (clk), // input
        .rst   (rst), // input
        .dly   (4'h7), // input[3:0] 
        .din   (pre2_start), // input
        .dout  (start_8) // output
    );

    dly01_16 start_11__i (
        .clk   (clk), // input
        .rst   (rst), // input
        .dly   (4'h1), // input[3:0] 
        .din   (start_8), // input
        .dout  (start_11) // output
    );

    dly01_16 dly01_16_2_i (
        .clk   (clk), // input
        .rst   (rst), // input
        .dly   (4'h4), // input[3:0] 
        .din   (start_8 && !pre2_start), // input
        .dout  (stop_in)            // output
    );


endmodule

