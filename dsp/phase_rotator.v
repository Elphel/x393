/*!
 * <b>Module:</b> phase_rotator
 * @file phase_rotator.v
 * @date 2017-12-11  
 * @author eyesis
 *     
 * @brief 2-d phase rotator in frequency domain (subpixel shift)
 *
 * @copyright Copyright (c) 2017 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 *
 * <b>License </b>
 *
 * phase_rotator.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * phase_rotator.v is distributed in the hope that it will be useful,
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

module  phase_rotator#(
    parameter FD_WIDTH =        25, // input/output data width, signed
    parameter SHIFT_WIDTH =      7, // x/y subpixel shift, signed -0.5<=shift<0.5
    parameter DSP_B_WIDTH =     18, // signed, output from sin/cos ROM
    parameter DSP_A_WIDTH =     25,
    parameter DSP_P_WIDTH =     48
)(
    input                            clk,           //!< system clock, posedge
    input                            rst,           //!< sync reset
    input                            start,         //!< single-cycle start pulse that goes 1 cycle before first data
    input signed   [SHIFT_WIDTH-1:0] shift_h,       //!< subpixel shift horizontal
    input signed   [SHIFT_WIDTH-1:0] shift_v,       //!< subpixel shift vertical
    // input data CC,CS,SC,SS in column scan order (matching DTT)
    input signed      [FD_WIDTH-1:0] fd_din,        //!< frequency domain data in
    output reg signed [FD_WIDTH-1:0] fd_out,        //!< frequency domain data in
    output reg                       pre_first_out, //!< 1 cycle before output data valid 
    output reg                       fd_dv          //!< output data valid        
);

// Generating cos_hor, sin_hor, cos_vert, sin_vert coefficients and cosine and sine signs for both horizontal and vertical
// passes. For continuing operation, the sequence of the coefficients should be as following (starting at the same time as CC0):
// CV62-SV62-CH00-SH00-CV63-SV63-CH01-SH01-CV0-SV0-..., where*V62, *V63 - data from the previous tile. 
 
// Signed subpixel shifts in the range [-0.5,0.5) are converted to sign and [0,0.5] and both limits are fit to the same slot as
// the shift -0.5 :  cos((i+0.5)/16*pi), -sin((i+0.5)/16*pi) for i=0..7 is symmetrical around the center (odd for sine, even - cosine)
// ROM input MSB - 0- cos, 1 - sin,  3 LSB s - index (0..7). Signs for cos and sin are passed to DSPs
// shift               i           ROM A[8:3]   ROM A[2:0]   sign cos   sign sin
// 1000000 (-0.5)     000              0            000          0         1
//                    001              0            001          0         1
//                    010              0            010          0         1
//                    011              0            011          0         1
//                    100              0            011          1         1
//                    101              0            010          1         1
//                    110              0            001          1         1
//                    111              0            000          1         1
//
// 1xxxxxx (<0)       nnn        -xxxxxx            nnn          0         1
//
// 0000000 (==0)      nnn              0            100          0         0
//
// 0xxxxxx (>0)       nnn         xxxxxx            nnn          0         0

    reg                     [5:0] start_d; // delayed versions of start (TODO: adjust length)  
    reg                     [7:0] cntr_h; // input sample counter
    reg                           run_h;
    wire                    [7:0] cntr_v; // delayed sample counter
    wire                          run_v;
    wire                          run_hv = run_h || run_v;
    reg                     [2:0] hv_index; // horizontal/vertical index
    reg                     [1:0] hv_phase; //      
    reg                           hv_sin; // 0 - cos, 1 - sin      
    
    reg         [SHIFT_WIDTH-1:0] shift_hr;
    reg         [SHIFT_WIDTH-1:0] shift_v0;
    reg         [SHIFT_WIDTH-1:0] shift_vr;
    reg         [SHIFT_WIDTH-1:0] shift_hv; // combined horizonta and vertical shifts to match cntr_mux;
    reg                           sign_cs;  // sign for cos / sin, feed to DSP
    reg         [SHIFT_WIDTH-2:0] rom_a_shift; // ~shift absolute value
    reg                     [2:0] rom_a_indx;  // rom index (hor/vert)
    reg                           rom_a_sin;   // rom cos =0; sin = 1
    wire        [SHIFT_WIDTH+2:0] rom_a = {rom_a_sin,rom_a_shift,rom_a_indx};
    wire                          shift_ends_0 = shift_hv[SHIFT_WIDTH-2:0] == 0;
    reg                     [1:0] rom_re_regen;
    wire signed [DSP_B_WIDTH-1:0] cos_sin_w; 

    always @ (posedge clk) begin
        if (rst) start_d <= 0;
        else     start_d <= {start_d[4:0], start};
        
        if (start)      shift_hr <= shift_h;
        if (start)      shift_v0 <= shift_v;
        if (start_d[5]) shift_vr <= shift_v0;
        
        if   (rst)            run_h <= 0;
        else if (start_d[0])  run_h <= 1;
        else if (&cntr_h)     run_h <= 0;
        
        if (!run_h) cntr_h <= 0;
        else        cntr_h <= cntr_h + 1;
        
        if (!run_hv) hv_phase <= 0;
        else         hv_phase <= hv_phase + 1;
        
        // combine horizontal and vertical counters and shifts to feed to ROM
        hv_index <= (run_v && cntr_v[1]) ? cntr_v[4:2] : cntr_h[7:5]; // input data "down first" (transposed) 
        hv_sin <= (run_v && cntr_v[1]) ? cntr_v[0] : cntr_h[0]; 
        shift_hv <= (run_v && cntr_v[1]) ? shift_vr :    shift_hr;
        
        // convert index, shift to ROM address
        
        rom_a_indx <=  shift_ends_0 ? (shift_hv[SHIFT_WIDTH-1]?{1'b0,hv_index[2]?~hv_index[1:0]:hv_index[1:0]}:3'h4) : hv_index;
        rom_a_shift <= shift_hv[SHIFT_WIDTH-1] ? -shift_hv[SHIFT_WIDTH-2:0] : shift_hv[SHIFT_WIDTH-2:0];
        rom_a_sin <=   hv_sin;
        sign_cs <=     shift_hv[SHIFT_WIDTH-1] & ( hv_sin | (shift_ends_0 & hv_index[2]));
        
        rom_re_regen <= {rom_re_regen[0],run_hv}; 
        
    end
    
    dly_var #(
        .WIDTH(9),
        .DLY_WIDTH(4)
    ) dly_cntrv_i (
        .clk  (clk),             // input
        .rst  (rst),             // input
        .dly  (4'h3),            // input[3:0] 
        .din  ({run_h, cntr_h}), // input[0:0] 
        .dout ({run_v, cntr_v})  // output[0:0] 
    );
    
     ram18tp_var_w_var_r #(
        .REGISTERS_A(1),
        .REGISTERS_B(1),
        .LOG2WIDTH_A(4),
        .LOG2WIDTH_B(4)
`ifdef PRELOAD_BRAMS
    `include "mclt_fold_rom.vh" // TODO: put real!
`endif
    ) i_mclt_rot_rom (
    
        .clk_a     (clk),             // input
        .addr_a    (rom_a),           // input[9:0] 
        .en_a      (rom_re_regen[0]), // input
        .regen_a   (rom_re_regen[1]), // input
        .we_a      (1'b0),            // input
        .data_out_a(cos_sin_w),       // output[17:0] 
        .data_in_a (18'b0),           // input[17:0]
        .clk_b     (1'b0),            // input
        .addr_b    (10'b0),           // input[9:0] 
        .en_b      (1'b0),            // input
        .regen_b   (1'b0),            // input
        .we_b      (1'b0),            // input
        .data_out_b(),                // output[17:0] 
        .data_in_b (18'b0)            // input[17:0] 
    );

    // horizontal shift stage

    dsp_ma_preadd #(
        .B_WIDTH(DSP_B_WIDTH),
        .A_WIDTH(DSP_A_WIDTH),
        .P_WIDTH(DSP_P_WIDTH),
        .A_INPUT("DIRECT"),
        .B_INPUT("DIRECT")
    ) dsp_1_i (
        .clk(), // input
        .rst(), // input
        .bin(), // input[17:0] signed 
        .ceb1(), // input
        .ceb2(), // input
        .selb(), // input
        .ain(), // input[24:0] signed 
        .cea1(), // input
        .cea2(), // input
        .din(), // input[24:0] signed 
        .ced(), // input
        .cead(), // input
        .sela(), // input
        .en_a(), // input
        .en_d(), // input
        .sub_a(), // input
        .neg_m(), // input
        .accum(), // input
        .pout() // output[47:0] signed 
    );

    dsp_ma_preadd #(
        .B_WIDTH(DSP_B_WIDTH),
        .A_WIDTH(DSP_A_WIDTH),
        .P_WIDTH(DSP_P_WIDTH),
        .A_INPUT("DIRECT"),
        .B_INPUT("CASCADE")
    ) dsp_2_i (
        .clk(), // input
        .rst(), // input
        .bin(), // input[17:0] signed 
        .ceb1(), // input
        .ceb2(), // input
        .selb(), // input
        .ain(), // input[24:0] signed 
        .cea1(), // input
        .cea2(), // input
        .din(), // input[24:0] signed 
        .ced(), // input
        .cead(), // input
        .sela(), // input
        .en_a(), // input
        .en_d(), // input
        .sub_a(), // input
        .neg_m(), // input
        .accum(), // input
        .pout() // output[47:0] signed 
    );

    // vertical shift stage

    dsp_ma_preadd #(
        .B_WIDTH(DSP_B_WIDTH),
        .A_WIDTH(DSP_A_WIDTH),
        .P_WIDTH(DSP_P_WIDTH),
        .A_INPUT("DIRECT"),
        .B_INPUT("DIRECT")
    ) dsp_3_i (
        .clk(), // input
        .rst(), // input
        .bin(), // input[17:0] signed 
        .ceb1(), // input
        .ceb2(), // input
        .selb(), // input
        .ain(), // input[24:0] signed 
        .cea1(), // input
        .cea2(), // input
        .din(), // input[24:0] signed 
        .ced(), // input
        .cead(), // input
        .sela(), // input
        .en_a(), // input
        .en_d(), // input
        .sub_a(), // input
        .neg_m(), // input
        .accum(), // input
        .pout() // output[47:0] signed 
    );

    dsp_ma_preadd #(
        .B_WIDTH(DSP_B_WIDTH),
        .A_WIDTH(DSP_A_WIDTH),
        .P_WIDTH(DSP_P_WIDTH),
        .A_INPUT("DIRECT"),
        .B_INPUT("CASCADE")
    ) dsp_4_i (
        .clk(), // input
        .rst(), // input
        .bin(), // input[17:0] signed 
        .ceb1(), // input
        .ceb2(), // input
        .selb(), // input
        .ain(), // input[24:0] signed 
        .cea1(), // input
        .cea2(), // input
        .din(), // input[24:0] signed 
        .ced(), // input
        .cead(), // input
        .sela(), // input
        .en_a(), // input
        .en_d(), // input
        .sub_a(), // input
        .neg_m(), // input
        .accum(), // input
        .pout() // output[47:0] signed 
    );

    
endmodule

