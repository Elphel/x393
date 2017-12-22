/*!
 * <b>Module:</b> mclt16x16_bayer
 * @file mclt16x16_bayer.v
 * @date 2017-12-21  
 * @author eyesis
 *     
 * @brief Generate addresses and windows to fold MCLT Bayer data
 *
 * @copyright Copyright (c) 2017 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 *
 * <b>License </b>
 *
 * mclt16x16_bayer.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * mclt16x16_bayer.v is distributed in the hope that it will be useful,
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

module  mclt16x16_bayer#(
    parameter SHIFT_WIDTH =      7, // bits in shift (7 bits - fractional)
    parameter PIX_ADDR_WIDTH =   9, // number of pixel address width
//    parameter EXT_PIX_LATENCY =  2, // external pixel buffer a->d latency
    parameter COORD_WIDTH =     10, // bits in full coordinate 10 for 18K RAM
    parameter PIXEL_WIDTH =     16, // input pixel width (unsigned) 
    parameter WND_WIDTH =       18, // input pixel width (unsigned) 
    parameter OUT_WIDTH =       25, // bits in dtt output
    parameter DTT_IN_WIDTH =    25, // bits in DTT input
    parameter TRANSPOSE_WIDTH = 25, // width of the transpose memory (intermediate results)    
    parameter OUT_RSHIFT =       2, // overall right shift of the result from input, aligned by MSB (>=3 will never cause saturation)
    parameter OUT_RSHIFT2 =      0, // overall right shift for the second (vertical) pass
    parameter DSP_B_WIDTH =     18, // signed, output from sin/cos ROM
    parameter DSP_A_WIDTH =     25,
    parameter DSP_P_WIDTH =     48,
    parameter DEAD_CYCLES =     14  // start next block immedaitely, or with longer pause
)(
    input                             clk,          //!< system clock, posedge
    input                             rst,          //!< sync reset
    input                             start,        //!< start convertion of the next 256 samples
    input                       [1:0] tile_size,    //!< o: 16x16, 1 - 18x18, 2 - 20x20, 3 - 22x22 (max for 9-bit addr)
    input                             inv_checker,  //!< 0 - includes main diagonal (symmetrical DTT), 1 - antisymmetrical DTT
    input                       [7:0] top_left,     //!< index of the 16x16 top left corner
    input                       [1:0] valid_rows,   //!< 3 for green, 1 or 2 for R/B - which of the even/odd checker rows contain pixels
    input           [SHIFT_WIDTH-1:0] x_shft,       //!< tile pixel X fractional shift (valid @ start) 
    input           [SHIFT_WIDTH-1:0] y_shft,       //!< tile pixel Y fractional shift (valid @ start)
    
    output       [PIX_ADDR_WIDTH-1:0] pix_addr,     //!< external pixel buffer address
    output                            pix_re,       //!< pixel read enable (sync with  mpixel_a)
    output                            pix_page,     //!< copy pixel page (should be externally combined with first color)
    input           [PIXEL_WIDTH-1:0] pix_d         //!< pixel data, latency = 2 from pixel address
);
    localparam  DTT_OUT_DELAY = 99; // 191; // start output to sin/cos rotator, ~=3/4 of 256
    localparam  DTT_IN_DELAY =  62; // 69; // wa -ra min = 1
    reg            [ 1:0] start_r;

    // maybe use small FIFO memory?
    reg [SHIFT_WIDTH-1:0] x_shft_r;  // registered at start
    reg [SHIFT_WIDTH-1:0] y_shft_r;  // registered at start
    reg [SHIFT_WIDTH-1:0] x_shft_r2; // use for the window calculation
    reg [SHIFT_WIDTH-1:0] y_shft_r2; // use for the window calculation
    reg [SHIFT_WIDTH-1:0] x_shft_r3; // registered @ start_dtt
    reg [SHIFT_WIDTH-1:0] y_shft_r3; // registered @ start_dtt
    reg [SHIFT_WIDTH-1:0] x_shft_r4; // registered @ dtt_start_first_fill
    reg [SHIFT_WIDTH-1:0] y_shft_r4; // registered @ dtt_start_first_fill

//    wire signed       [WND_WIDTH-1:0] window;       //!< msb==0, always positive
    wire                         [1:0] signs;        //!< bit 0: sign to add to dtt-cc input, bit 1: sign to add to dtt-cs input
    wire                        [14:0] phases;        //!< other signals
    
    wire signed   [WND_WIDTH-1:0] window_w;
    reg  signed   [WND_WIDTH-1:0] window_r;
    reg  signed [PIXEL_WIDTH-1:0] pix_d_r;         // registered pixel data (to be absorbed by MPY)
    
    reg  signed [PIXEL_WIDTH + WND_WIDTH - 1:0] pix_wnd_r; // MSB not used: positive[PIXEL_WIDTH]*positive[WND_WIDTH]->positive[PIXEL_WIDTH+WND_WIDTH-1]
    reg  signed              [DTT_IN_WIDTH-1:0] pix_wnd_r2; // pixels (positive) multiplied by window(positive), two MSBs == 2'b0 to prevent overflow
    // rounding
    wire signed              [DTT_IN_WIDTH-3:0] pix_wnd_r2_w = pix_wnd_r[PIXEL_WIDTH + WND_WIDTH - 2 -: DTT_IN_WIDTH - 2]
    `ifdef ROUND
                 + pix_wnd_r[PIXEL_WIDTH + WND_WIDTH -DTT_IN_WIDTH]
    `endif
    ;

    reg  signed [DTT_IN_WIDTH-1:0] data_cc_r;   
    reg  signed [DTT_IN_WIDTH-1:0] data_sc_r;
    reg  signed [DTT_IN_WIDTH-1:0] data_sc_r2; // data_sc_r delayed by 1 cycle 
    reg  signed [DTT_IN_WIDTH-1:0] data_dtt_in; // multiplexed DTT input data
    
    reg                            mode_mux;   
    reg                      [6:0] dtt_in_cntr; //
    reg                            dtt_in_page;
    wire                     [8:0] dtt_in_wa = {1'b0,dtt_in_page, dtt_in_cntr[0], dtt_in_cntr[6:1]};  
    wire                           dtt_we = phases[14];
    
       
    wire                    [ 1:0] pix_sgn_d;
    reg                     [ 1:0] pix_sgn_r;
    
    wire                           var_first; // adding subtracting first variant of 4 folds    
    reg                            var_last;    // next cycle the   data_xx_r will have data  (in_busy[14], ...)

// reading/converting DTT
    reg                            start_dtt; //  = dtt_in_cntr == 196; // fune tune? ~= 3/4 of 256 
    reg                      [6:0] dtt_r_cntr; //
    reg                            dtt_r_page;
    reg                            dtt_r_re;
    reg                            dtt_r_regen;
    reg                            dtt_start;
    
//    wire                     [1:0] dtt_mode = {dtt_r_cntr[7], dtt_r_cntr[6]}; // TODO: or reverse? 
    wire                           dtt_mode = dtt_r_cntr[6]; // TODO: or reverse? 
    wire                     [8:0] dtt_r_ra = {1'b0,dtt_r_page,dtt_r_cntr};
    wire signed             [35:0] dtt_r_data_w; // high bits are not used 
    wire signed [DTT_IN_WIDTH-1:0] dtt_r_data = dtt_r_data_w[DTT_IN_WIDTH-1:0]; 
   
   
   
    
    always @ (posedge clk) begin
    
        if (start) begin
            x_shft_r <= x_shft;
            y_shft_r <= y_shft;
        end
        start_r <= {start_r[0], start};
        if (start_r[1]) begin      // same latency as mpix_a_w
            x_shft_r2 <= x_shft_r; // use for the window 
            y_shft_r2 <= y_shft_r;
        end

        if (start_dtt) begin 
            x_shft_r3 <= x_shft_r2; 
            y_shft_r3 <= y_shft_r2;
        end
/*
        if (dtt_start_first_fill) begin 
            x_shft_r4 <= x_shft_r3; 
            y_shft_r4 <= y_shft_r3;
        end
*/
        if (phases[8]) begin
            pix_d_r <= pix_d;
            window_r <=   window_w;
        end
        if (phases[9])  pix_wnd_r <= pix_d_r * window_r; // 1 MSB is extra
    
        // pix_wnd_r2 - positive with 2 extra zeros, max value 0x3fff60
        if (phases[10]) begin
            pix_wnd_r2 <= {{2{pix_wnd_r2_w[DTT_IN_WIDTH-3]}},pix_wnd_r2_w};
//            mpix_use_r  <= mpix_use_d;
//            var_first_r <= var_first_d;
            pix_sgn_r <=  pix_sgn_d; 
        end
        
        var_last <= var_first & phases[11];
       
        if (phases[11]) begin
//            data_cc_r <= (var_first ? {DTT_IN_WIDTH{1'b0}} : data_cc_r) + (mpix_use_r ? (mpix_sgn_r[0]?(-pix_wnd_r2):pix_wnd_r2): {DTT_IN_WIDTH{1'b0}}) ;
//            data_sc_r <= (var_first ? {DTT_IN_WIDTH{1'b0}} : data_sc_r) + (mpix_use_r ? (mpix_sgn_r[1]?(-pix_wnd_r2):pix_wnd_r2): {DTT_IN_WIDTH{1'b0}}) ;
             data_cc_r <= (var_first ? {DTT_IN_WIDTH{1'b0}} : data_cc_r) + (pix_sgn_r[0]?(-pix_wnd_r2):pix_wnd_r2) ;
             data_sc_r <= (var_first ? {DTT_IN_WIDTH{1'b0}} : data_sc_r) + (pix_sgn_r[1]?(-pix_wnd_r2):pix_wnd_r2) ;
             data_sc_r2 <= data_sc_r;
         end
         
         if (phases[12]) data_sc_r2 <= data_sc_r;
        
         if      (var_last)    mode_mux <= 0;
         else if (phases[13])  mode_mux <= mode_mux + 1;
    
         if (phases[13]) case (mode_mux)
             1'b0: data_dtt_in <= data_cc_r;
             1'b1: data_dtt_in <= data_sc_r2;
         endcase
    
         if (!phases[14]) dtt_in_cntr <= 0; 
         else             dtt_in_cntr <= dtt_in_cntr + 1;
   
         start_dtt <= dtt_in_cntr == DTT_IN_DELAY;

         if (rst)               dtt_in_page <= 0;
         else if (&dtt_in_cntr) dtt_in_page <= dtt_in_page + 1;
        
        // reading memory and running DTT
        
        if (start_dtt)        dtt_r_page <=dtt_in_page;
        
        if (rst)              dtt_r_re <= 1'b0;
        else if (start_dtt)   dtt_r_re <= 1'b1;
        else if (&dtt_r_cntr) dtt_r_re <= 1'b0;
        dtt_r_regen <= dtt_r_re;
        
        if (!dtt_r_re) dtt_r_cntr <= 0;
        else           dtt_r_cntr <= dtt_r_cntr + 1;
        
///        dtt_start <= dtt_r_cntr[5:0] == 0;
        dtt_start <= (dtt_r_cntr[5:0] == 0) && dtt_r_re;
    
    end
    
      
    mclt_bayer_fold #(
        .SHIFT_WIDTH     (SHIFT_WIDTH),
        .PIX_ADDR_WIDTH  (PIX_ADDR_WIDTH),
        .COORD_WIDTH     (COORD_WIDTH),
        .PIXEL_WIDTH     (PIXEL_WIDTH),
        .WND_WIDTH       (WND_WIDTH),
        .OUT_WIDTH       (OUT_WIDTH),
        .DTT_IN_WIDTH    (DTT_IN_WIDTH),
        .TRANSPOSE_WIDTH (TRANSPOSE_WIDTH),
        .OUT_RSHIFT      (OUT_RSHIFT),
        .OUT_RSHIFT2     (OUT_RSHIFT2),
        .DSP_B_WIDTH     (DSP_B_WIDTH),
        .DSP_A_WIDTH     (DSP_A_WIDTH),
        .DSP_P_WIDTH     (DSP_P_WIDTH),
        .DEAD_CYCLES     (DEAD_CYCLES)
    ) mclt_bayer_fold_i (
        .clk         (clk),         // input
        .rst         (rst),         // input
        .start       (start),       // input
        .tile_size   (tile_size),   // input[1:0] 
        .inv_checker (inv_checker), // input
        .top_left    (top_left),    // input[7:0] 
        .valid_rows  (valid_rows),  // input[1:0] 
        .x_shft      (x_shft),      // input[6:0] 
        .y_shft      (y_shft),      // input[6:0] 
        .pix_addr    (pix_addr),    // output[8:0] 
        .pix_re      (pix_re),      // output
        .pix_page    (pix_page),    // output
        .window      (window_w),     // output[17:0] signed 
        .signs       (signs),       // output[1:0] 
        .phases      (phases),      // output[7:0]
        .var_first   (var_first)    // output reg 
    );

    dly_var #(
        .WIDTH(2),
        .DLY_WIDTH(4)
    ) dly_pix_sgn_i (
        .clk  (clk),           // input
        .rst  (rst),           // input
        .dly  (4'h1),          // input[3:0] 
        .din  (signs),    // input[0:0] 
        .dout (pix_sgn_d)     // output[0:0] 
    );


    ram18p_var_w_var_r #(
        .REGISTERS(1),
        .LOG2WIDTH_WR(5),
        .LOG2WIDTH_RD(5)
    ) ram18p_var_w_var_r_dtt_in_i (
        .rclk     (clk),          // input
        .raddr    (dtt_r_ra),     // input[8:0] 
        .ren      (dtt_r_re),     // input
        .regen    (dtt_r_regen),  // input
        .data_out (dtt_r_data_w), // output[35:0] 
        .wclk     (clk),          // input
        .waddr    (dtt_in_wa),    // input[8:0] 
        .we       (dtt_we),       // input
        .web      (4'hf),         // input[3:0] 
        .data_in  ({{(36-DTT_IN_WIDTH){1'b0}}, data_dtt_in}) // input[35:0] 
    );
    wire [8:0] dbgt_diff_wara = dtt_in_wa-dtt_r_ra;
    
    
/*
    wire signed [OUT_WIDTH-1:0] dtt_out_wd;
    wire                  [3:0] dtt_out_wa16;
    wire                        dtt_out_we;
    wire                        dtt_sub16;
    wire                        dtt_inc16;
    reg                   [4:0] dtt_out_ram_cntr;
    reg                   [4:0] dtt_out_ram_wah;
    wire                        dtt_start_fill; // some data available in DTT output buffer, OK to start consecutive readout
    reg                         dtt_start_first_fill;
    reg                         dtt_start_out;  // start read out to sin/cos rotator
*/

endmodule

