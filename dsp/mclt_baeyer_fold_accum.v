/*!
 * <b>Module:</b> mclt_baeyer_fold_accum
 * @file mclt_baeyer_fold_accum.v
 * @date 2017-12-23  
 * @author Andrey Filippov
 *     
 * @brief Alternative implementation of CC and CS folded data accumulators
 *
 * @copyright Copyright (c) 2017 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 *
 * <b>License </b>
 *
 * mclt_baeyer_fold_accum.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * mclt_baeyer_fold_accum.v is distributed in the hope that it will be useful,
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
//`define DSP_ACCUM_FOLD 1
module  mclt_baeyer_fold_accum # (
    parameter PIXEL_WIDTH =     16, // input pixel width (unsigned) 
    parameter WND_WIDTH =       18, // input pixel width (unsigned) 
    parameter DTT_IN_WIDTH =    25, // bits in DTT input
    parameter DSP_B_WIDTH =     18, // signed, output from sin/cos ROM // SuppressThisWarning VEditor  - not always used
    parameter DSP_A_WIDTH =     25, // SuppressThisWarning VEditor - not always used
    parameter DSP_P_WIDTH =     48  // SuppressThisWarning VEditor - not always used

)(
    input                            clk,
    input                            rst,
    input                            pre_phase,
    input signed   [PIXEL_WIDTH-1:0] pix_d,    //!< pixel data (should be 1 cycle later for `undef DSP_ACCUM_FOLD
    input                      [1:0] pix_sgn,  //!< bit 0: sign to add to dtt-cc input, bit 1: sign to add to dtt-cs input
    input signed     [WND_WIDTH-1:0] window,
    input                            var_pre2_first,
    output signed [DTT_IN_WIDTH-1:0] dtt_in,
    output                           dtt_in_dv  
);
    reg                           var_pre_first;
    reg                           var_first;
    reg                           var_last;
    
    reg                      [6:0] phases;
    
    always @ (posedge clk) begin
        phases <= {phases[5:0], pre_phase};

        if (phases[2]) begin
            var_pre_first <= var_pre2_first;
        end
            
        if (phases[3]) begin
            var_first <= var_pre_first; 
        end
        
        var_last <= var_first & phases[4];
       
    end


`ifdef DSP_ACCUM_FOLD
    reg                            dtt_in_dv_dsp_r;
    reg signed [DTT_IN_WIDTH-1:0]  dtt_in_dsp; 

    assign dtt_in =    dtt_in_dsp;
    assign dtt_in_dv = dtt_in_dv_dsp_r;
    
    always @ (posedge clk) begin
        if (rst) dtt_in_dv_dsp_r <= 0;
        else     dtt_in_dv_dsp_r <= phases[5];
    end
    
    wire neg_m1, neg_m2;
    wire accum1= !var_pre2_first;
    wire accum2= !var_pre_first;
    wire [DSP_P_WIDTH-1:0] pout1;
    wire [DSP_P_WIDTH-1:0] pout2;
    wire signed [DTT_IN_WIDTH-1:0] dtt_in_dsp_w = (var_last ?
                       pout1 [PIXEL_WIDTH + WND_WIDTH - 1 -: DTT_IN_WIDTH] :
                       pout2 [PIXEL_WIDTH + WND_WIDTH - 1 -: DTT_IN_WIDTH])
     `ifdef ROUND
        + (var_last ?
                       pout1 [PIXEL_WIDTH + WND_WIDTH -DTT_IN_WIDTH -1] :
                       pout2 [PIXEL_WIDTH + WND_WIDTH -DTT_IN_WIDTH -1)
     `endif                      
                       ;
    
//    wire signed              [DTT_IN_WIDTH-2:0] pix_wnd_r2_w = pix_wnd_r[PIXEL_WIDTH + WND_WIDTH - 2 -: DTT_IN_WIDTH - 1]
    
    always @ (posedge clk) begin
        if (phases[5]) dtt_in_dsp <= dtt_in_dsp_w;
    
    end
    dsp_ma_preadd #(
        .B_WIDTH(DSP_B_WIDTH),
        .A_WIDTH(DSP_A_WIDTH),
        .P_WIDTH(DSP_P_WIDTH),
        .AREG(1),
        .BREG(1)
    ) dsp_fold_cc_i (
        .clk   (clk),       // input
        .rst   (rst),       // input
        .bin   (window),    // input[17:0] signed 
        .ceb1  (1'b0),      // input
        .ceb2  (phases[1]), // input
        .selb  (1'b1),      // input
        .ain   ({{(DSP_A_WIDTH-PIXEL_WIDTH){pix_d[PIXEL_WIDTH-1]}},pix_d}), // input[24:0] signed 
        .cea1  (1'b0),      // input
        .cea2  (phases[0]), // input
        .din   (25'b0),     // input[24:0] signed 
        .ced   (1'b0),      // input
        .cead  (phases[1]), // input
        .sela  (1'b1),      // input
        .en_a  (1'b1),      // input
        .en_d  (1'b0),      // input
        .sub_a (1'b0),      // input
        .neg_m (neg_m1),    // input
        .accum (accum1),    // input
        .pout  (pout1)      // output[47:0] signed 
    );

    dsp_ma_preadd #(
        .B_WIDTH(DSP_B_WIDTH),
        .A_WIDTH(DSP_A_WIDTH),
        .P_WIDTH(DSP_P_WIDTH),
        .AREG(2), // delayed by 1
        .BREG(2)
    ) dsp_fold_cs_i (
        .clk   (clk),       // input
        .rst   (rst),       // input
        .bin   (window),    // input[17:0] signed 
        .ceb1  (phases[1]), // input
        .ceb2  (phases[2]), // input
        .selb  (1'b1),      // input
        .ain   ({{(DSP_A_WIDTH-PIXEL_WIDTH){pix_d[PIXEL_WIDTH-1]}},pix_d}), // input[24:0] signed 
        .cea1  (phases[0]), // input
        .cea2  (phases[1]), // input
        .din   (25'b0),     // input[24:0] signed 
        .ced   (1'b0),      // input
        .cead  (phases[2]), // input
        .sela  (1'b1),      // input
        .en_a  (1'b1),      // input
        .en_d  (1'b0),      // input
        .sub_a (1'b0),      // input
        .neg_m (neg_m2),    // input
        .accum (accum2),    // input
        .pout  (pout2)      // output[47:0] signed 
    );

    dly_var #(
        .WIDTH(1),
        .DLY_WIDTH(4)
    ) dly_neg_m1_i (
        .clk  (clk),           // input
        .rst  (rst),           // input
        .dly  (4'h0),          // input[3:0] 
        .din  (pix_sgn[0]),    // input[0:0] 
        .dout (neg_m1)         // output[0:0] 
    );
    dly_var #(
        .WIDTH(1),
        .DLY_WIDTH(4)
    ) dly_neg_m2_i (
        .clk  (clk),           // input
        .rst  (rst),           // input
        .dly  (4'h1),          // input[3:0] 
        .din  (pix_sgn[1]),    // input[0:0] 
        .dout (neg_m2)         // output[0:0] 
    );

`else
    wire                   [ 1:0] pix_sgn_d;
///    reg            [PIXEL_WIDTH-1:0] pix_dr;         // only for mpy to match dsp
    reg  signed   [WND_WIDTH-1:0] window_r;
    reg  signed [PIXEL_WIDTH-1:0] pix_d_r;         // registered pixel data (to be absorbed by MPY)
    reg                    [ 1:0] pix_sgn_r;
    
    reg  signed [PIXEL_WIDTH + WND_WIDTH - 1:0] pix_wnd_r; // MSB not used: positive[PIXEL_WIDTH]*positive[WND_WIDTH]->positive[PIXEL_WIDTH+WND_WIDTH-1]
    reg  signed              [DTT_IN_WIDTH-1:0] pix_wnd_r2; // pixels (positive) multiplied by window(positive), two MSBs == 2'b0 to prevent overflow
    // rounding
//    wire signed              [DTT_IN_WIDTH-3:0] pix_wnd_r2_w = pix_wnd_r[PIXEL_WIDTH + WND_WIDTH - 2 -: DTT_IN_WIDTH - 2]
    wire signed              [DTT_IN_WIDTH-2:0] pix_wnd_r2_w = pix_wnd_r[PIXEL_WIDTH + WND_WIDTH - 2 -: DTT_IN_WIDTH - 1]
    `ifdef ROUND
//                 + pix_wnd_r[PIXEL_WIDTH + WND_WIDTH -DTT_IN_WIDTH]
                 + pix_wnd_r[PIXEL_WIDTH + WND_WIDTH -DTT_IN_WIDTH -1]
    `endif
    ;
    reg  signed [DTT_IN_WIDTH-1:0] data_cc_r;   
    reg  signed [DTT_IN_WIDTH-1:0] data_sc_r;
    reg  signed [DTT_IN_WIDTH-1:0] data_sc_r2; // data_sc_r delayed by 1 cycle 
    reg                            mode_mux;
    reg                            dtt_in_dv_r;
    reg  signed [DTT_IN_WIDTH-1:0] data_dtt_in; // multiplexed DTT input data

    assign dtt_in =    data_dtt_in;
    assign dtt_in_dv = dtt_in_dv_r;

    always @ (posedge clk) begin
        if (rst) dtt_in_dv_r <= 0;
        else     dtt_in_dv_r <= phases[6];

///        pix_dr <= pix_d;
        if (phases[1]) begin
///            pix_d_r <=    pix_dr;
            pix_d_r <=    pix_d;
            window_r <=   window;
        end
        if (phases[2])  pix_wnd_r <= pix_d_r * window_r; // 1 MSB is extra

        if (phases[3]) begin
            pix_wnd_r2 <= {pix_wnd_r2_w[DTT_IN_WIDTH-2],pix_wnd_r2_w};
            pix_sgn_r <=  pix_sgn_d;
        end
       
        if (phases[4]) begin
             data_cc_r <= (var_first ? {DTT_IN_WIDTH{1'b0}} : data_cc_r) + (pix_sgn_r[0]?(-pix_wnd_r2):pix_wnd_r2) ;
             data_sc_r <= (var_first ? {DTT_IN_WIDTH{1'b0}} : data_sc_r) + (pix_sgn_r[1]?(-pix_wnd_r2):pix_wnd_r2) ;
             data_sc_r2 <= data_sc_r;
         end
         
         if (phases[5]) data_sc_r2 <= data_sc_r;
        
         if      (var_last)    mode_mux <= 0;
         else if (phases[6])  mode_mux <= mode_mux + 1;
    
         if (phases[6]) case (mode_mux)
             1'b0: data_dtt_in <= data_cc_r;
             1'b1: data_dtt_in <= data_sc_r2;
         endcase
    end
    
    dly_var #(
        .WIDTH(2),
        .DLY_WIDTH(4)
    ) dly_pix_sgn_i (
        .clk  (clk),           // input
        .rst  (rst),           // input
        .dly  (4'h1),          // input[3:0] 
        .din  (pix_sgn),       // input[0:0] 
        .dout (pix_sgn_d)      // output[0:0] 
    );
    
`endif

    
endmodule

