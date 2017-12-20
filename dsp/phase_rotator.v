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
    parameter DSP_P_WIDTH =     48,
    parameter COEFF_WIDTH =     17 // = DSP_B_WIDTH - 1 or positive numbers,
)(
    input                            clk,           //!< system clock, posedge
    input                            rst,           //!< sync reset
    input                            start,         //!< single-cycle start pulse that goes 1 cycle before first data
    input signed   [SHIFT_WIDTH-1:0] shift_h,       //!< subpixel shift horizontal
    input signed   [SHIFT_WIDTH-1:0] shift_v,       //!< subpixel shift vertical
    // input data CC,CS,SC,SS in column scan order (matching DTT)
    input signed      [FD_WIDTH-1:0] fd_din,        //!< frequency domain data in, LATENCY=3 from start
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
// shift               i    sin  ROM[9]     ROM A[8:3]   ROM A[2:0]   sign cos   sign sin
// 1000000 (-0.5)     nnn    0     1         0           ~nnn          0         1
//                    nnn    1     1         0            nnn          0         1
//
// 1xxxxxx (<0)       nnn    s     s   -xxxxxx            nnn          0         1
//
// 0000000 (==0)      nnn    0     0          0             0          0         0
//                    nnn    1     0          0             1          0         0
//
// 0xxxxxx (>0)       nnn    s     s    xxxxxx            nnn          0         0

    reg                     [5:0] start_d; // delayed versions of start (TODO: adjust length)  
    reg                     [7:0] cntr_h; // input sample counter
    reg                           run_h;
    wire                    [7:0] cntr_v; // delayed sample counter
    wire                          run_v;
    wire                          run_hv = run_h || run_v;
    reg                     [2:0] hv_index; // horizontal/vertical index
//    reg                    [16:0] dsp_phase; //      
    reg                           hv_sin; // 0 - cos, 1 - sin      
    
    reg         [SHIFT_WIDTH-1:0] shift_hr;
    reg         [SHIFT_WIDTH-1:0] shift_v0;
    reg         [SHIFT_WIDTH-1:0] shift_vr;
    reg         [SHIFT_WIDTH-1:0] shift_hv; // combined horizonta and vertical shifts to match cntr_mux;
    reg                     [4:0] sign_cs;  // sign for cos / sin, feed to DSP
    wire                          sign_cs_d; // sign_cs delayed by 3 clocks
    reg                     [1:0] sign_cs_r; // sign_cs delayed by 5 clocks      
    reg         [SHIFT_WIDTH-2:0] rom_a_shift; // ~shift absolute value
    reg                     [2:0] rom_a_indx;  // rom index (hor/vert)
    reg                           rom_a_sin;   // rom cos =0; sin = 1
    wire        [SHIFT_WIDTH+2:0] rom_a = {rom_a_sin,rom_a_shift,rom_a_indx};
    wire                          shift_ends_0 = shift_hv[SHIFT_WIDTH-2:0] == 0;
    reg                     [2:0] rom_re_regen;
    wire signed [DSP_B_WIDTH-1:0] cos_sin_w;
    wire mux_v =  cntr_v[1]; //  && run_v; // removed for debugging to see 'x' 

    always @ (posedge clk) begin
        if (rst) start_d <= 0;
        else     start_d <= {start_d[4:0], start};
        
        if (start)      shift_hr <= shift_h;
        if (start)      shift_v0 <= shift_v;
        if (start_d[3]) shift_vr <= shift_v0;
        
        if   (rst)        run_h <= 0;
        else if (start)   run_h <= 1;
        else if (&cntr_h) run_h <= 0;
        
        if (!run_h) cntr_h <= 0;
        else        cntr_h <= cntr_h + 1;
        
//        if (!run_hv) hv_phase <= 0;
//        else         hv_phase <= hv_phase + 1;
        
        // combine horizontal and vertical counters and shifts to feed to ROM
        hv_index <= mux_v ? cntr_v[4:2] : cntr_h[7:5]; // input data "down first" (transposed) 
        hv_sin <=   mux_v ? cntr_v[0] :   cntr_h[0]; 
        shift_hv <= mux_v ? shift_vr :    shift_hr;
        
        // convert index, shift to ROM address
        
        rom_a_indx <=  shift_ends_0 ? (shift_hv[SHIFT_WIDTH-1]?({3{~hv_sin}} ^ hv_index) : +{2'b0,hv_sin}) : hv_index;
        
        rom_a_shift <= shift_hv[SHIFT_WIDTH-1] ? -shift_hv[SHIFT_WIDTH-2:0] : shift_hv[SHIFT_WIDTH-2:0];
        rom_a_sin <=   shift_ends_0 ? shift_hv[SHIFT_WIDTH-1] : hv_sin;
//        sign_cs <=     shift_hv[SHIFT_WIDTH-1] & ( hv_sin | (shift_ends_0 & hv_index[2]));
//        sign_cs <=     shift_hv[SHIFT_WIDTH-1] &  hv_sin;
        sign_cs <=     {sign_cs[3:0], shift_hv[SHIFT_WIDTH-1] &  hv_sin};
        
        rom_re_regen <= {rom_re_regen[1:0],run_hv};
        
        sign_cs_r <= {sign_cs_r[0], sign_cs_d}; 
        
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
    
    dly_var #(
        .WIDTH(1),
        .DLY_WIDTH(4)
    ) dly_sign_cs_d_i (
        .clk  (clk),             // input
        .rst  (rst),             // input
        .dly  (4'h2),            // input[3:0] 
        .din  (sign_cs[0]),      // input[0:0] 
        .dout (sign_cs_d)        // output[0:0] 
    );
    
    
     ram18tp_var_w_var_r #(
        .REGISTERS_A(1),
        .REGISTERS_B(1),
        .LOG2WIDTH_A(4),
        .LOG2WIDTH_B(4)
`ifdef PRELOAD_BRAMS
    `include "mclt_rotator_rom.vh"
`endif
    ) i_mclt_rot_rom (
    
        .clk_a     (clk),             // input
        .addr_a    (rom_a),           // input[9:0] 
        .en_a      (rom_re_regen[1]), // input
        .regen_a   (rom_re_regen[2]), // input
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
    
  // Registers for DSP control
    reg ceb1_1, ceb1_2, ceb1_3, ceb1_4;
    reg ceb2_1, ceb2_2, ceb2_3, ceb2_4;
    reg selb_1, selb_2, selb_3, selb_4;
    wire signed [DSP_A_WIDTH-1:0] ain_34 = pout_1[COEFF_WIDTH +: DSP_A_WIDTH]; // bit select from pout_1    
    wire signed [DSP_A_WIDTH-1:0] din_34 = pout_2[COEFF_WIDTH +: DSP_A_WIDTH]; // bit select from pout_1    
    reg cea1_1,  cea1_2,  cea1_3,  cea1_4;
    reg cea2_1,  cea2_2,  ced_3,   ced_4;
    reg sela_1,  sela_2,  end_3,   end_4;
    reg cead_1,  cead_2,  cead_3,  cead_4;
    reg negm_1,  negm_2,  negm_3,  negm_4;
    reg accum_1, accum_2, accum_3, accum_4;
    wire signed [DSP_P_WIDTH-1:0] pout_1;    
    wire signed [DSP_P_WIDTH-1:0] pout_2;  
    wire signed [DSP_P_WIDTH-1:0] pout_3;    
    wire signed [DSP_P_WIDTH-1:0] pout_4;
    reg  omux_sel;  
    wire pre_dv = |ph[16:13];
    reg    [16:0] ph; // DSP pre phase,
    
    always @(posedge clk) begin
        if (rst) ph <= 0;
//        else ph <= {ph[15:0], run_h & ~cntr_h[0] & cntr_h[1]};
        else ph <= {ph[15:0], run_h & ~cntr_h[0] & ~cntr_h[1]};
        cea1_1 <= ph[0]; cea2_1 <= ph[2]; cea1_2 <= ph[1]; cea2_2 <= ph[3];
        ceb1_1 <= ph[3]; ceb2_1 <= ph[2]; ceb1_2 <= ph[2] | ph[3]; ceb2_2 <= ph[3];
        cead_1 <= |ph[5:2]; cead_2 <= |ph[6:3];
        // 1 cycle ahead
        sela_1 <= ph[2] | ph[4]; sela_2 <= ph[3] | ph[5];
        selb_1 <= ph[2] | ph[5]; selb_2 <= ph[3] | ph[6];
        // 0 1 0 0
//        negm_1 <= (ph[3] ^ sign_cs_d) | (~ph[4] ^ sign_cs_d) | (ph[5] ^ sign_cs_r[1]) | (ph[6] ^ sign_cs_r[1]);
//        negm_2 <= (ph[4] ^ sign_cs_d) | (~ph[5] ^ sign_cs_d) | (ph[6] ^ sign_cs_r[1]) | (ph[7] ^ sign_cs_r[1]);
///        negm_1 <= (ph[4] & ~sign_cs[0]) | (ph[5] & sign_cs[1]);
///        negm_2 <= (ph[5] & ~sign_cs[1]) | (ph[6] & sign_cs[2]);
        negm_1 <= (ph[4] & ~sign_cs[2]) | (ph[5] & sign_cs[3]);
        negm_2 <= (ph[5] & ~sign_cs[3]) | (ph[6] & sign_cs[4]);
        
        accum_1 <= ph[4] | ph[6]; accum_2 <= ph[5] | ph[7];
    // vertical shift DSPs
        cea1_3 <= ph[6]; ced_3 <= ph[7]; cea1_4 <= ph[8]; ced_4 <= ph[9];
        ceb1_3 <= ph[9]; ceb2_3 <= ph[8]; ceb1_4 <= ph[8] | ph[9]; ceb2_4 <= ph[9];
        cead_3 <= |ph[11:8]; cead_4 <= |ph[12:9];
        // 1 cycle ahead
        end_3  <= ph[10] | ph[8]; end_4 <= ph[11] | ph[9];
        selb_3 <= ph[8] | ph[11]; selb_4 <= ph[9] | ph[12];

//        negm_4 <= (ph[ 9] ^ sign_cs_d) | (~ph[10] ^ sign_cs_d) | (ph[11] ^ sign_cs_r[1]) | (ph[12] ^ sign_cs_r[1]);
//        negm_3 <= (ph[10] ^ sign_cs_d) | (~ph[11] ^ sign_cs_d) | (ph[12] ^ sign_cs_r[1]) | (ph[13] ^ sign_cs_r[1]);
///        negm_3 <= (ph[10] & ~sign_cs[0]) | (ph[11] & sign_cs[1]);
///        negm_4 <= (ph[11] & ~sign_cs[1]) | (ph[12] & sign_cs[2]);
        negm_3 <= (ph[10] & ~sign_cs[2]) | (ph[11] & sign_cs[3]);
        negm_4 <= (ph[11] & ~sign_cs[3]) | (ph[12] & sign_cs[4]);

        accum_3 <= ph[10] | ph[12]; accum_4 <= ph[11] | ph[13];
        
        omux_sel <= ph[13] | ph[15];
        fd_dv <= pre_dv;
        if (pre_dv) fd_out <= omux_sel ? pout_4[COEFF_WIDTH +: DSP_A_WIDTH] : pout_3[COEFF_WIDTH +: DSP_A_WIDTH];
        
//        pre_first_out <= ph[12];
        pre_first_out <= cntr_h[7:0] == 8'hf;
        
    end
     
/*
    output reg signed [FD_WIDTH-1:0] fd_out,        //!< frequency domain data in

*/
    // horizontal shift stage

    dsp_ma_preadd #(
        .B_WIDTH(DSP_B_WIDTH),
        .A_WIDTH(DSP_A_WIDTH),
        .P_WIDTH(DSP_P_WIDTH)
    ) dsp_1_i (
        .clk   (clk),       // input
        .rst   (rst),       // input
        .bin   (cos_sin_w), // input[17:0] signed 
        .ceb1  (ceb1_1),    // input
        .ceb2  (ceb2_1),    // input
        .selb  (selb_1),    // input
        .ain   (fd_din),    // input[24:0] signed 
        .cea1  (cea1_1),    // input
        .cea2  (cea2_1),    // input
        .din   (25'b0),     // input[24:0] signed 
        .ced   (1'b0),      // input
        .cead  (cead_1),    // input
        .sela  (sela_1),    // input
        .en_a  (1'b1),      // input
        .en_d  (1'b0),      // input
        .sub_a (1'b0),      // input
        .neg_m (negm_1),    // input
        .accum (accum_1),   // input
        .pout  (pout_1)     // output[47:0] signed 
    );

    dsp_ma_preadd #(
        .B_WIDTH(DSP_B_WIDTH),
        .A_WIDTH(DSP_A_WIDTH),
        .P_WIDTH(DSP_P_WIDTH),
        .BREG   (2)
    ) dsp_2_i (
        .clk   (clk),       // input
        .rst   (rst),       // input
        .bin   (cos_sin_w), // input[17:0] signed 
        .ceb1  (ceb1_2),    // input
        .ceb2  (ceb2_2),    // input
        .selb  (selb_2),    // input
        .ain   (fd_din),    // input[24:0] signed 
        .cea1  (cea1_2),    // input
        .cea2  (cea2_2),    // input
        .din   (25'b0),     // input[24:0] signed 
        .ced   (1'b0),      // input
        .cead  (cead_2),    // input
        .sela  (sela_2),    // input
        .en_a  (1'b1),      // input
        .en_d  (1'b0),      // input
        .sub_a (1'b0),      // input
        .neg_m (negm_2),    // input
        .accum (accum_2),   // input
        .pout  (pout_2)     // output[47:0] signed 
    );

    // vertical shift stage

    dsp_ma_preadd #(
        .B_WIDTH(DSP_B_WIDTH),
        .A_WIDTH(DSP_A_WIDTH),
        .P_WIDTH(DSP_P_WIDTH)
    ) dsp_3_i (
        .clk   (clk),       // input
        .rst   (rst),       // input
        .bin   (cos_sin_w), // input[17:0] signed 
        .ceb1  (ceb1_3),    // input
        .ceb2  (ceb2_3),    // input
        .selb  (selb_3),    // input
        .ain   (ain_34),    // input[24:0] signed 
        .cea1  (cea1_3),    // input
        .cea2  (1'b0),      // input
        .din   (din_34),    // input[24:0] signed 
        .ced   (ced_3),     // input
        .cead  (cead_3),    // input
        .sela  (1'b0),      // input
        .en_a  (~end_3),    // input
        .en_d  (end_3),     // input
        .sub_a (1'b0),      // input
        .neg_m (negm_3),    // input
        .accum (accum_3),   // input
        .pout  (pout_3)     // output[47:0] signed 
    );

    dsp_ma_preadd #(
        .B_WIDTH(DSP_B_WIDTH),
        .A_WIDTH(DSP_A_WIDTH),
        .P_WIDTH(DSP_P_WIDTH),
        .BREG   (2)
    ) dsp_4_i (
        .clk   (clk),       // input
        .rst   (rst),       // input
        .bin   (cos_sin_w), // input[17:0] signed 
        .ceb1  (ceb1_4),    // input
        .ceb2  (ceb2_4),    // input
        .selb  (selb_4),    // input
        .ain   (ain_34),    // input[24:0] signed 
        .cea1  (cea1_4),    // input
        .cea2  (1'b0),      // input
        .din   (din_34),    // input[24:0] signed 
        .ced   (ced_4),     // input
        .cead  (cead_4),    // input
        .sela  (1'b0),      // input
        .en_a  (~end_4),    // input
        .en_d  (end_4),     // input
        .sub_a (1'b0),      // input
        .neg_m (negm_4),    // input
        .accum (accum_4),   // input
        .pout  (pout_4)     // output[47:0] signed 
    );

    
endmodule
