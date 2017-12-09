/*!
 * <b>Module:</b>dtt_iv_8x8_obuf
 * @file dtt_iv_8x8_obuf.v
 * @date 2016-12-08  
 * @author  Andrey Filippov
 *     
 * @brief 2-d DCT-IV implementation, 1 clock/data word. Input in scanline order, output - transposed, with output buffer
 *
 * @copyright Copyright (c) 2016 Elphel, Inc.
 *
 * <b>License:</b>
 *
 *dtt_iv_8x8_obuf.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  dtt_iv_8x8_obuf.v is distributed in the hope that it will be useful,
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

module  dtt_iv_8x8_obuf#(
    parameter INPUT_WIDTH =     25,
    parameter OUT_WIDTH =       25,
    parameter OUT_RSHIFT1 =      1,  // overall right shift of the result from input, aligned by MSB for pass1 (>=3 will never cause saturation)
    parameter OUT_RSHIFT2 =      1, //  if sum OUT_RSHIFT1+OUT_RSHIFT2 == 2, direct*reverse == ident (may use 3, -1) or 3,0 with wider output and saturate
    parameter TRANSPOSE_WIDTH = 25, // transpose memory width
    parameter DSP_B_WIDTH =     18,
    parameter DSP_A_WIDTH =     25,
    parameter DSP_P_WIDTH =     48,
    parameter COSINE_SHIFT=     17,
    parameter ODEPTH =           5, // output buffer depth (bits). Here 5, put can use more if used as a full block buffer 
    parameter COS_01_32 =    130441, // int(round((1<<17) * cos( 1*pi/32)))
    parameter COS_03_32 =    125428, // int(round((1<<17) * cos( 3*pi/32)))
    parameter COS_04_32 =    121095, // int(round((1<<17) * cos( 4*pi/32)))
    parameter COS_05_32 =    115595, // int(round((1<<17) * cos( 5*pi/32)))
    parameter COS_07_32 =    101320, // int(round((1<<17) * cos( 7*pi/32)))
    parameter COS_08_32 =    92682,  // int(round((1<<17) * cos( 8*pi/32)))
    parameter COS_09_32 =    83151,  // int(round((1<<17) * cos( 9*pi/32)))
    parameter COS_11_32 =    61787,  // int(round((1<<17) * cos(11*pi/32)))
    parameter COS_12_32 =    50159,  // int(round((1<<17) * cos(12*pi/32)))
    parameter COS_13_32 =    38048,  // int(round((1<<17) * cos(13*pi/32)))
    parameter COS_15_32 =    12847   // int(round((1<<17) * cos(15*pi/32)))
    ) (
    input                            clk,           //!< system clock, posedge
    input                            rst,           //!< sync reset
    input                            start,         //!< single-cycle start pulse that goes 1 cycle before first data
    input                      [1:0] mode,          //!< DCT/DST: [1] - first (horizontal) pass, [0] - second (vertical) pass. 0 - DCT, 1 - DST  
                                                    // Next data should be sent in bursts of 8, pause of 8 - total 128 cycles
    input  signed  [INPUT_WIDTH-1:0] xin,           //!< input data
    output                           pre_last_in,   //!< output high during input of the pre-last of 64 pixels in a 8x8 block (next can be start
    output                           pre_first_out, //!< 1 cycle ahead of the first output in a 64 block
    output reg                       dv,            //!< data output valid. WAS: Will go high on the 94-th cycle after the start
    output reg signed[OUT_WIDTH-1:0] d_out,         //!< output data
    output                     [1:0] mode_out,      //!< copy of mode input, valid @ pre_first_out
    output                           pre_busy);     //!< start should come each 64-th cycle (next after pre_last_in), and not after pre_busy) 

    reg signed       [OUT_WIDTH-1:0] out_ram[0: ((1<<ODEPTH)-1)]; // [0:31];
    wire signed      [OUT_WIDTH-1:0] out_wd;
    wire signed                [3:0] out_wa;
    wire                             out_we;
    wire                             sub16;
    wire                             inc16;
    wire                             start64;
    reg                 [ODEPTH-5:0] out_ram_cntr;
    reg                 [ODEPTH-5:0] out_ram_wah;
    
    wire                [ODEPTH-1:0] out_ram_wa = {out_ram_wah,out_wa};
    reg                              out_ram_ren;
    reg                              out_ram_regen;
    reg                        [5:0] out_ram_ra;
    
    reg signed      [OUT_WIDTH-1:0]  out_ram_r;
    
    
    
    always @ (posedge clk) begin
        if      (rst)    out_ram_cntr <= 0;
        else if (inc16)  out_ram_cntr <= out_ram_cntr + 1;
        out_ram_wah <= out_ram_cntr - sub16;
        
        if (out_we) out_ram[out_ram_wa] <= out_wd;
        
        if      (rst)         out_ram_ren <= 1'b0;
        else if (start64)     out_ram_ren <= 1'b1;
        else if (&out_ram_ra) out_ram_ren <= 1'b0;
        
        out_ram_regen <= out_ram_ren;
        dv <=            out_ram_regen;
        if (!out_ram_ren) out_ram_ra <= 0;
        else              out_ram_ra <= out_ram_ra + 1;
        
        if (out_ram_ren)   out_ram_r <= out_ram[out_ram_ra[4:0]];
        if (out_ram_regen) d_out     <= out_ram_r;
    
    end

    dly_var #(
        .WIDTH(1),
        .DLY_WIDTH(4)
    ) dly_pre_first_out_i (
        .clk  (clk),           // input
        .rst  (rst),           // input
        .dly  (4'h1),          // input[3:0] 
        .din  (start64),       // input[0:0] 
        .dout (pre_first_out)  // output[0:0] 
    );

    dtt_iv_8x8_ad #(
        .INPUT_WIDTH     (INPUT_WIDTH),
        .OUT_WIDTH       (OUT_WIDTH),
        .OUT_RSHIFT1     (OUT_RSHIFT1),
        .OUT_RSHIFT2     (OUT_RSHIFT2),
        .TRANSPOSE_WIDTH (TRANSPOSE_WIDTH),
        .DSP_B_WIDTH     (DSP_B_WIDTH),
        .DSP_A_WIDTH     (DSP_A_WIDTH),
        .DSP_P_WIDTH     (DSP_P_WIDTH),
        .COSINE_SHIFT    (COSINE_SHIFT),
        .COS_01_32       (COS_01_32),
        .COS_03_32       (COS_03_32),
        .COS_04_32       (COS_04_32),
        .COS_05_32       (COS_05_32),
        .COS_07_32       (COS_07_32),
        .COS_08_32       (COS_08_32),
        .COS_09_32       (COS_09_32),
        .COS_11_32       (COS_11_32),
        .COS_12_32       (COS_12_32),
        .COS_13_32       (COS_13_32),
        .COS_15_32       (COS_15_32)
    ) dtt_iv_8x8_i (
        .clk            (clk),              // input
        .rst            (rst),              // input
        .start          (start),            // input
        .mode           (mode),             // input[1:0] 
        .xin            (xin),              // input[24:0] signed 
        .pre_last_in    (pre_last_in),      // output reg 
        .mode_out       (mode_out),         // output[1:0] reg 
        .pre_busy       (pre_busy),         // output reg
        .out_wd         (out_wd),           // output[24:0] reg 
        .out_wa         (out_wa),           // output[3:0] reg 
        .out_we         (out_we),           // output reg 
        .sub16          (sub16),            // output reg 
        .inc16          (inc16),            // output reg 
        .start64        (start64)           // output reg 
    );



endmodule

