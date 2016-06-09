/*******************************************************************************
 * <b>Module:</b>dct1d_chen
 * @file dct1d_chen.v
 * @date:2016-06-05  
 * @author: Andrey Filippov
 *     
 * @brief: 1d 8-point DCT based on Chen algorithm
 *
 * @copyright Copyright (c) 2016 Elphel, Inc.
 *
 * <b>License:</b>
 *
 *dct1d_chen.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  dct1d_chen.v is distributed in the hope that it will be useful,
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

module  dct1d_chen#(
    parameter WIDTH = 24,
    parameter OUT_WIDTH = 24,
    parameter B_WIDTH = 18,
    parameter A_WIDTH = 25,
    parameter P_WIDTH = 48,
    parameter M_WIDTH = 43, // actual multiplier width (== (A_WIDTH +B_WIDTH)
    parameter COS_1_16 = 128553, // (1<<17) * cos(1*pi/16)
    parameter COS_2_16 = 121095, // (2<<17) * cos(1*pi/16)
    parameter COS_3_16 = 108982, // (3<<17) * cos(1*pi/16)
    parameter COS_4_16 =  92682, // (4<<17) * cos(1*pi/16)
    parameter COS_5_16 =  72820, // (5<<17) * cos(1*pi/16)
    parameter COS_6_16 =  50159, // (6<<17) * cos(1*pi/16)
    parameter COS_7_16 =  25570  // (7<<17) * cos(1*pi/16)
)(
    input                          clk,
    input                          rst,
    input                          en,
    input  [2 * WIDTH -1:0]        d10_32_76_54, // Concatenated input data {x[1],x[0]}/{x[3],x[2]}/ {x[7],x[6]}/{x[5],x[4]}
    input                          start,      // {x[1],x[0]} available next after start,  {x[3],x[2]} - second next, then {x[7],x[6]} and {x[5],x[4]} 
    output [WIDTH -1:0]            dout,
    output                         pre2_start_out // 2 clock cycle before F4 output, full dout sequence
                                             // start_out-X-F4-X-F2-X-F6-F5-F0-F3-X-F1-X-F7
);
    reg    signed [B_WIDTH-1:0] dsp_ma_bin;
    wire                        dsp_ma_ceb1_1;     // load b1 register
    wire                        dsp_ma_ceb2_1;     // load b2 register
    wire                        dsp_ma_selb_1;     // 0 - select b1, 1 - select b2
    wire   signed [A_WIDTH-1:0] dsp_ma_ain_1;
    wire                        dsp_ma_cea1_1;
    wire                        dsp_ma_cea2_1;
    wire   signed [A_WIDTH-1:0] dsp_ma_din_1;
    wire                        dsp_ma_ced_1;
    wire                        dsp_ma_sela_1;
    wire                        dsp_ma_en_a_1;      // 0: +/- D, 1: A or A +/- D 
    wire                        dsp_ma_en_d_1;      // 0: A, 1: D  or A +/- D 
    wire                        dsp_ma_sub_d_1;     // 1 when  - D, 0 - all other
    wire                        dsp_ma_neg_m_1;    // 1 - negate multiplier result
    wire                        dsp_ma_accum_1;    // 0 - use multiplier result, 1 add to accumulator
    wire   signed [P_WIDTH-1:0] dsp_ma_p_1;

    wire                        dsp_ma_ceb1_2;     // load b1 register
    wire                        dsp_ma_ceb2_2;     // load b2 register
    wire                        dsp_ma_selb_2;     // 0 - select b1, 1 - select b2
    wire   signed [A_WIDTH-1:0] dsp_ma_ain_2;
    wire                        dsp_ma_cea1_2;
    wire                        dsp_ma_cea2_2;
    wire   signed [A_WIDTH-1:0] dsp_ma_din_2;
    wire                        dsp_ma_ced_2;
    wire                        dsp_ma_sela_2;     // 0 - select a1, 1 - select a2
    wire                        dsp_ma_seld_2;     // 0 - select a1/a2, 1 - select d
    wire                        dsp_ma_neg_m_2;    // 1 - negate multiplier result
    wire                        dsp_ma_accum_2;    // 0 - use multiplier result, 1 add to accumulator
    wire   signed [P_WIDTH-1:0] dsp_ma_p_2;
    
    // Multipler A/D inputs before shift
    wire   signed [WIDTH-1:0] dsp_ma_ain24_1;
    wire   signed [WIDTH-1:0] dsp_ma_din24_1;
    wire   signed [WIDTH-1:0] dsp_ma_ain24_2;
    wire   signed [WIDTH-1:0] dsp_ma_din24_2;
    
    
    
    
    wire   signed   [WIDTH-1:0] simd_a0;
    wire   signed   [WIDTH-1:0] simd_a1;
    wire   signed   [WIDTH-1:0] simd_a2;
    wire   signed   [WIDTH-1:0] simd_a3;
    wire   signed   [WIDTH-1:0] simd_a4;
    wire   signed   [WIDTH-1:0] simd_a5;
    
    wire   signed   [WIDTH-1:0] simd_b0;
    wire   signed   [WIDTH-1:0] simd_b1;
    wire   signed   [WIDTH-1:0] simd_b2;
    wire   signed   [WIDTH-1:0] simd_b3;
    wire   signed   [WIDTH-1:0] simd_b4;
    wire   signed   [WIDTH-1:0] simd_b5;

    wire   signed   [WIDTH-1:0] simd_p0;
    wire   signed   [WIDTH-1:0] simd_p1;
    wire   signed   [WIDTH-1:0] simd_p2;
    wire   signed   [WIDTH-1:0] simd_p3;
    wire   signed   [WIDTH-1:0] simd_p4;
    wire   signed   [WIDTH-1:0] simd_p5;
    
    wire                        simd_cea01;
    wire                        simd_cea23;
    wire                        simd_ceaf45; // first stage A registers CE
    wire                        simd_ceas45; // second stage A registers CE
    wire                        simd_ceb01;
    wire                        simd_ceb23;
    wire                        simd_ceb45;  // B registers CE
    wire                        simd_sub01;
    wire                        simd_sub23;
    wire                        simd_sub45;
    wire                        simd_cep01;
    wire                        simd_cep23;
    wire                        simd_cep45;

    reg                   [7:0] phase;
    reg                   [3:0] phase_cnt;
    reg        [OUT_WIDTH -1:0] dout_r;
    wire       [OUT_WIDTH -1:0] dout1_w;
    wire       [OUT_WIDTH -1:0] dout2_w;

//        .ain      ({simd_a1,simd_a0}), // input[47:0] 
//        .bin      ({simd_b1,simd_b0}), // input[47:0]
    // dsp_addsub_simd1_i input connections
    assign  simd_a0 = phase[0]? d10_32_76_54[0 * WIDTH +: WIDTH] : simd_p0; // only phase[0] & phase[4], other phases - don't care
    assign  simd_a1 = phase[0]? d10_32_76_54[1 * WIDTH +: WIDTH] : simd_p1; // only phase[0] & phase[4], other phases - don't care
    
    assign  simd_b0 = phase[2]? d10_32_76_54[0 * WIDTH +: WIDTH] : simd_p3; // only phase[2] & phase[5], other phases - don't care
    assign  simd_b1 = phase[2]? d10_32_76_54[1 * WIDTH +: WIDTH] : simd_p2; // only phase[2] & phase[5], other phases - don't care

    assign simd_cea01 =  phase[0] | phase[4];
    assign simd_ceb01 =  phase[2] | phase[5];

    assign simd_sub01 = phase[3] | phase[6];
    assign simd_cep01 = phase[2] | phase[3] | phase[5] | phase[6];
    
    // dsp_addsub_simd2_i input connections
    assign  simd_a2 = phase[1]? d10_32_76_54[0 * WIDTH +: WIDTH] : simd_p0; // only phase[1] & phase[7], other phases - don't care
    assign  simd_a3 =           d10_32_76_54[1 * WIDTH +: WIDTH];           // only phase[1],            other phases - don't care 

    assign  simd_b2 = phase[3]? d10_32_76_54[0 * WIDTH +: WIDTH] : simd_p1; // only phase[3] & phase[7], other phases - don't care
    assign  simd_b3 =           d10_32_76_54[1 * WIDTH +: WIDTH];           // only phase[3],            other phases - don't care
    
    assign simd_cea23 =  phase[1] | phase[7];
    assign simd_ceb23 =  phase[3] | phase[7];

    assign simd_sub23 = phase[4] | phase[7];
    assign simd_cep23 = phase[0] | phase[3] | phase[4] | phase[7];
    
    assign  simd_a4 = simd_p3; // only at phase[6], other phases - don't care
    assign  simd_a5 = simd_p0; // only at phase[6], other phases - don't care

    // dsp_addsub_reg2_simd_i input connections
    assign  simd_b4 = dsp_ma_p_1[M_WIDTH-1 -: WIDTH]; // only at phase[6], other phases - don't care. TODO: add symmetric rounding here?
    assign  simd_b5 = dsp_ma_p_1[M_WIDTH-1 -: WIDTH]; // only at phase[2], other phases - don't care. TODO: add symmetric rounding here?

    assign simd_ceaf45 = phase[6];
    assign simd_ceas45 = phase[2];
    assign simd_ceb45 =  phase[2] | phase[4];

    assign simd_sub45 = phase[2] | phase[4];
    assign simd_cep45 = phase[2] | phase[3] | phase[4] | phase[5];
    
    // dsp_ma1_i control connections
    assign dsp_ma_ceb1_1 =  phase[3] | phase[7];
    assign dsp_ma_ceb2_1 =  phase[0];
    assign dsp_ma_selb_1 =  phase[3] | phase[6];
    assign dsp_ma_cea1_1 =  phase[2] | phase[6];
    assign dsp_ma_cea2_1 =  phase[1] | phase[3];
    assign dsp_ma_ced_1 =   phase[2] | phase[6];
    assign dsp_ma_sela_1 =  phase[1] | phase[7];
    assign dsp_ma_en_a_1 =  !(phase[2] | phase[4]);
    assign dsp_ma_en_d_1 =  phase[0] | phase[2] | phase[4] | phase[6];
    assign dsp_ma_sub_d_1 = phase[0];
    assign dsp_ma_neg_m_1 = phase[6];
    assign dsp_ma_accum_1 = phase[5] | phase[7];
    // dsp_ma1_i data input connections
/*  assign dsp_ma_ain24_1 = ({WIDTH{phase[6]}} & simd_p1) |
                            ({WIDTH{phase[1]}} & simd_p2) |
                            ({WIDTH{phase[2]}} & simd_p0) |
                            ({WIDTH{phase[3]}} & simd_p2) ; // Other - don't care */
    assign dsp_ma_ain24_1 = phase[6] ? simd_p1 : (phase[2] ? simd_p0 : simd_p2); 
    assign dsp_ma_din24_1 = phase[6] ? simd_p2 :  simd_p1; 

    // dsp_ma2_i control connections
    assign dsp_ma_ceb1_2 = phase[1] | phase[6];
    assign dsp_ma_ceb2_2 = phase[2] | phase[5];
    assign dsp_ma_selb_2 = phase[1] | phase[3] | phase[5] | phase[7];
    assign dsp_ma_cea1_2 = phase[5];
    assign dsp_ma_cea2_2 = phase[4];
    assign dsp_ma_ced_2 =  phase[1] | phase[6];
    assign dsp_ma_sela_2 =  phase[1] | phase[6];
    assign dsp_ma_seld_2 =  phase[0] | phase[3] | phase[4] | phase[7];
    assign dsp_ma_neg_m_2 = phase[6];
    assign dsp_ma_accum_2 = phase[0] | phase[2] | phase[4] | phase[6];
    // dsp_ma2_i data input connections
    assign dsp_ma_ain24_2 = simd_p5; 
    assign dsp_ma_din24_2 = simd_p4; 

    assign dsp_ma_din24_1 = phase[6] ? simd_p2 :  simd_p1; 


// Shift adder outputs to the MSB of the multiplier inputs
    assign dsp_ma_ain_1 = {dsp_ma_ain24_1, {A_WIDTH-WIDTH{1'b0}}};   
    assign dsp_ma_din_1 = {dsp_ma_din24_1, {A_WIDTH-WIDTH{1'b0}}};   
    assign dsp_ma_ain_2 = {dsp_ma_ain24_2, {A_WIDTH-WIDTH{1'b0}}};   
    assign dsp_ma_din_2 = {dsp_ma_din24_2, {A_WIDTH-WIDTH{1'b0}}};
// Shift DSP outputs to match output results    
    assign  dout1_w = dsp_ma_p_1[M_WIDTH -: WIDTH]; // adding one it for adder (two MPY outputs are added)
    assign  dout2_w = dsp_ma_p_2[M_WIDTH -: WIDTH]; // adding one it for adder (two MPY outputs are added)
    assign dout = dout_r;

    always @ (posedge clk) begin
        phase <= {phase[6:0], en & (start |phase[7])};
        if      (!rst || start)          phase_cnt <= 0;
        else if (en || (phase_cnt != 7)) phase_cnt <= phase_cnt + 1;
        // Cosine table, defined to fit into 17 bits for 18-bit signed DSP B-operand
        case (phase_cnt)
            3'h0: dsp_ma_bin <= COS_1_16;
            3'h1: dsp_ma_bin <= COS_7_16;
            3'h2: dsp_ma_bin <= COS_2_16;
            3'h3: dsp_ma_bin <= COS_2_16;
            3'h4: dsp_ma_bin <= COS_3_16;
            3'h5: dsp_ma_bin <= COS_5_16;
            3'h6: dsp_ma_bin <= COS_4_16;
            3'h7: dsp_ma_bin <= COS_6_16;
        endcase
        dout_r <= phase_cnt[0] ? dout1_w : dout2_w;
    end

    dsp_addsub_simd #(
        .NUM_DATA (2),
        .WIDTH    (WIDTH)
    ) dsp_addsub_simd1_i (
        .clk      (clk),               // input
        .rst      (rst),               // input
        .ain      ({simd_a1,simd_a0}), // input[47:0] 
        .bin      ({simd_b1,simd_b0}), // input[47:0] 
        .cea      (simd_cea01),        // input
        .ceb      (simd_ceb01),        // input
        .subtract (simd_sub01),        // input
        .cep      (simd_cep01),        // input
        .pout     ({simd_p1,simd_p0})  // output[47:0] 
    );

    dsp_addsub_simd #(
        .NUM_DATA (2),
        .WIDTH    (WIDTH)
    ) dsp_addsub_simd2_i (
        .clk      (clk),               // input
        .rst      (rst),               // input
        .ain      ({simd_a3,simd_a2}), // input[47:0] 
        .bin      ({simd_b3,simd_b2}), // input[47:0] 
        .cea      (simd_cea23),        // input
        .ceb      (simd_ceb23),        // input
        .subtract (simd_sub23),        // input
        .cep      (simd_cep23),        // input
        .pout     ({simd_p3,simd_p2})  // output[47:0] 
    );

    dsp_addsub_reg2_simd #(
        .NUM_DATA(2),
        .WIDTH(24)
    ) dsp_addsub_reg2_simd_i (
        .clk      (clk),               // input
        .rst      (rst),               // input
        .ain      ({simd_a5,simd_a4}), // input[47:0] 
        .bin      ({simd_b5,simd_b4}), // input[47:0] 
        .cea1     (simd_ceaf45),       // input
        .cea2     (simd_ceas45),       // input
        .ceb      (simd_ceb45),        // input
        .subtract (simd_sub45),        // input
        .cep      (simd_cep45),        // input
        .pout     ({simd_p5,simd_p4})  // output[47:0] 
    );

   
    dsp_ma_preadd #(
        .B_WIDTH(18),
        .A_WIDTH(25),
        .P_WIDTH(48)
    ) dsp_ma1_i (
        .clk   (clk),            // input
        .rst   (rst),            // input
        .bin   (dsp_ma_bin),     // input[17:0] signed 
        .ceb1  (dsp_ma_ceb1_1),  // input
        .ceb2  (dsp_ma_ceb2_1),  // input
        .selb  (dsp_ma_selb_1),  // input
        .ain   (dsp_ma_ain_1),   // input[24:0] signed 
        .cea1  (dsp_ma_cea1_1),  // input
        .cea2  (dsp_ma_cea2_1),  // input
        .din   (dsp_ma_din_1),   // input[24:0] signed 
        .ced   (dsp_ma_ced_1),   // input
        .cead  (1'b1),           // input
        .sela  (dsp_ma_sela_1),  // input
        .en_a  (dsp_ma_en_a_1),    // input
        .en_d  (dsp_ma_en_d_1), // input
        .sub_d (dsp_ma_sub_d_1), // input
        .neg_m (dsp_ma_neg_m_1), // input
        .accum (dsp_ma_accum_1), // input
        .pout  (dsp_ma_p_1)      // output[47:0] signed 
    );
    

    dsp_ma #(
        .B_WIDTH(B_WIDTH),
        .A_WIDTH(A_WIDTH),
        .P_WIDTH(P_WIDTH)
    ) dsp_ma2_i (
        .clk   (clk),            // input
        .rst   (rst),            // input
        .bin   (dsp_ma_bin),     // input[17:0] signed 
        .ceb1  (dsp_ma_ceb1_2),  // input
        .ceb2  (dsp_ma_ceb2_2),  // input
        .selb  (dsp_ma_selb_2),  // input
        .ain   (dsp_ma_ain_2),   // input[24:0] signed 
        .cea1  (dsp_ma_cea1_2),  // input
        .cea2  (dsp_ma_cea2_2),  // input
        .din   (dsp_ma_din_2),   // input[24:0] signed 
        .ced   (dsp_ma_ced_2),   // input
        .sela  (dsp_ma_sela_2),  // input
        .seld  (dsp_ma_seld_2),  // input
        .neg_m (dsp_ma_neg_m_2), // input
        .accum (dsp_ma_accum_2), // input
        .pout  (dsp_ma_p_2)      // output[47:0] signed 
    );

    dly01_16 dly01_16_i (
        .clk   (clk),           // input
        .rst   (rst),           // input
        .dly   (4'h4),          // input[3:0] 
        .din   (phase[7]),      // input
        .dout  (pre2_start_out) // output
    );


endmodule

