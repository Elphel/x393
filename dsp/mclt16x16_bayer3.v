/*!
 * <b>Module:</b> mclt16x16_bayer3
 * @file mclt16x16_bayer3.v
 * @date 2017-12-21  
 * @author eyesis
 *     
 * @brief Generate addresses and windows to fold MCLT Bayer data
 *
 * @copyright Copyright (c) 2017 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 *
 * <b>License </b>
 *
 * mclt16x16_bayer3.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * mclt16x16_bayer3.v is distributed in the hope that it will be useful,
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

module  mclt16x16_bayer3#(
    parameter SHIFT_WIDTH =      7, // bits in shift (7 bits - fractional)
    parameter PIX_ADDR_WIDTH =   9, // number of pixel address width
    parameter EXT_PIX_LATENCY =  2, // external pixel buffer a->d latency (may increase to 4 for gamma)
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
    input                       [1:0] color_wa,     //!< color index to apply parameters to (0 - R, 1 - B, 2 - G) 
    input                             inv_checker,  //!< 0 - includes main diagonal (symmetrical DTT), 1 - antisymmetrical DTT
    input                       [7:0] top_left,     //!< index of the 16x16 top left corner
//    input                       [1:0] valid_rows,   //!< 3 for green, 1 or 2 for R/B - which of the even/odd checker rows contain pixels
    input                             valid_odd,    //!< For R and B: 0 - even rows (0,2...) valid, 1 - odd rows valid, green - N/A
    input           [SHIFT_WIDTH-1:0] x_shft,       //!< tile pixel X fractional shift (valid @ start) 
    input           [SHIFT_WIDTH-1:0] y_shft,       //!< tile pixel Y fractional shift (valid @ start)
    input                             set_inv_checker, //!< 0 write inv_checker for the color selected by color_wa
    input                             set_top_left, //!< 0 write top_left for the color selected by color_wa
    input                             set_valid_odd, //!< 0 write top_left for the color selected by color_wa
    input                             set_x_shft, //!< 0 write top_left for the color selected by color_wa
    input                             set_y_shft, //!< 0 write top_left for the color selected by color_wa
    
    output       [PIX_ADDR_WIDTH-1:0] pix_addr,     //!< external pixel buffer address
    output                            pix_re,       //!< pixel read enable (sync with  mpixel_a)
    output                            pix_page,     //!< copy pixel page (should be externally combined with first color)
    input           [PIXEL_WIDTH-1:0] pix_d,         //!< pixel data, latency = 2 from pixel address
    output                            pre_busy,     //!< start should come each 256-th cycle (next after pre_last_in), and not after pre_busy)          
    output                            pre_last_in,  //!< may increment page
    output                            pre_first_out,//!< next will output first of DCT/DCT coefficients          
    output                            pre_last_out, //!< next will be last output of DST/DST coefficients
    output                      [7:0] out_addr,     //!< address to save coefficients, 2 MSBs - mode (CC,SC,CS,SS), others - down first         
    output                            dv,           //!< output data valid
    output signed [OUT_WIDTH - 1 : 0] dout_r,       //!<frequency domain data output for red   color components            
    output signed [OUT_WIDTH - 1 : 0] dout_b,       //!<frequency domain data output for blue  color components           
    output signed [OUT_WIDTH - 1 : 0] dout_g        //!<frequency domain data output for green color components           
);
    
    // When defined, use 2 DSP multipleierts
//    `define DSP_ACCUM_FOLD 1
    
    localparam  DTT_OUT_DELAY = 128; // 191; // start output to sin/cos rotator, with checker - 2*64 +/=?
    localparam  DTT_IN_DELAY =  63; // 69; // wa -ra min = 1
    reg                      [7:0] in_cntr; //
    reg                            run_r;

    // general timing    
    always @(posedge clk) begin
        if      (rst)      run_r <= 0;
        else if (start)    run_r <= 1;
        else if (&in_cntr) run_r <= 0;
        
        if (!run_r)  in_cntr <= 0;
        else         in_cntr <= in_cntr + 1;
        
    end
    
    // register files - should be valid for 3 cycles after start (while being copied)
    reg                            inv_checker_rf_ram[0:3]; //
    reg                      [7:0] top_left_rf_ram[0:3];    //
    reg                            valid_odd_rf_ram[0:3];   //
    reg          [SHIFT_WIDTH-1:0] x_shft_rf_ram[0:3];      // 
    reg          [SHIFT_WIDTH-1:0] y_shft_rf_ram[0:3];      //
    reg                            inv_checker_rf_ram_reg;  //
    reg                      [7:0] top_left_rf_ram_reg;     //
    reg                            valid_odd_rf_ram_reg;    //
    reg          [SHIFT_WIDTH-1:0] x_shft_rf_ram_reg;       // 
    reg          [SHIFT_WIDTH-1:0] y_shft_rf_ram_reg;       //
    reg                      [1:0] copy_regs;
    // internal per-color registers
    reg                            inv_checker_ram[0:3]; //
    reg                      [7:0] top_left_ram[0:3];    //
    reg                            valid_odd_ram[0:3];   //
    reg          [SHIFT_WIDTH-1:0] x_shft_ram[0:3];      // 
    reg          [SHIFT_WIDTH-1:0] y_shft_ram[0:3];      //
    reg                            reg_rot_page; // odd/even register sets for long latency (rotator)
    reg                      [1:0] regs_wa;
    reg                            inv_checker_rot_ram[0:7]; //
    reg                            valid_odd_rot_ram[0:7];   //
    reg          [SHIFT_WIDTH-1:0] x_shft_rot_ram[0:7];      // 
    reg          [SHIFT_WIDTH-1:0] y_shft_rot_ram[0:7];      //
    reg                      [1:0] start_block_r;            // 0 - read regs, 1 - start fold
    reg                            inv_checker_ram_reg; //
    reg                      [7:0] top_left_ram_reg; //
    reg                            valid_odd_ram_reg; //
    reg          [SHIFT_WIDTH-1:0] x_shft_ram_reg; // 
    reg          [SHIFT_WIDTH-1:0] y_shft_ram_reg; //
    // todo: add registers to read into rotators
    
    
    always @(posedge clk) begin
        if (set_inv_checker)  inv_checker_rf_ram[color_wa] <= inv_checker;
        if (set_top_left)     top_left_rf_ram   [color_wa] <= top_left;
        if (set_valid_odd)    valid_odd_rf_ram  [color_wa] <= valid_odd;
        if (set_x_shft)       x_shft_rf_ram     [color_wa] <= x_shft;
        if (set_y_shft)       y_shft_rf_ram     [color_wa] <= y_shft;
        copy_regs <= {copy_regs[0], start | (run_r && (in_cntr[7:1]==0))?1'b1:1'b0};
        if (copy_regs[0]) begin
            regs_wa <= in_cntr[1:0];
            inv_checker_rf_ram_reg <= inv_checker_rf_ram[in_cntr[1:0]];
            top_left_rf_ram_reg <=    top_left_rf_ram[in_cntr[1:0]];
            valid_odd_rf_ram_reg <=   valid_odd_rf_ram[in_cntr[1:0]];
            x_shft_rf_ram_reg <=      x_shft_rf_ram[in_cntr[1:0]];
            y_shft_rf_ram_reg <=      y_shft_rf_ram[in_cntr[1:0]];
        end
        
        if      (rst)   reg_rot_page <= 1;
        else if (start) reg_rot_page <= ~reg_rot_page;
        
        if (copy_regs[1]) begin
            inv_checker_ram[regs_wa] <= inv_checker_rf_ram_reg;
            top_left_ram[regs_wa] <=    top_left_rf_ram_reg;
            valid_odd_ram[regs_wa] <=   valid_odd_rf_ram_reg;
            x_shft_ram[regs_wa] <=      x_shft_rf_ram_reg;
            y_shft_ram[regs_wa] <=      y_shft_rf_ram_reg;
            
            inv_checker_rot_ram[{reg_rot_page,regs_wa}] <= inv_checker_rf_ram_reg;
            valid_odd_rot_ram[{reg_rot_page,regs_wa}] <=   valid_odd_rf_ram_reg;
            x_shft_rot_ram[{reg_rot_page,regs_wa}] <=      x_shft_rf_ram_reg;
            y_shft_rot_ram[{reg_rot_page,regs_wa}] <=      y_shft_rf_ram_reg;
        end
        
        start_block_r <= {start_block_r[0], ((in_cntr[5:0] == 1) && (in_cntr[7:6] != 3))?1'b1:1'b0};         
        if (start_block_r[0]) begin
            inv_checker_ram_reg <= inv_checker_ram[in_cntr[7:6]];
            top_left_ram_reg <=    top_left_ram[in_cntr[7:6]];
            valid_odd_ram_reg <=   valid_odd_ram[in_cntr[7:6]];
            x_shft_ram_reg <=      x_shft_ram[in_cntr[7:6]];
            y_shft_ram_reg <=      y_shft_ram[in_cntr[7:6]];
        end
        
    end

`ifdef DSP_ACCUM_FOLD
        localparam ADDR_DLYL = 4 - EXT_PIX_LATENCY; // 4'h2; // 3 for mpy, 2 - for dsp
`else        
        localparam ADDR_DLYL = 5 - EXT_PIX_LATENCY; // 4'h3; // 3 for mpy, 2 - for dsp
`endif
    wire                     [1:0] signs;        //!< bit 0: sign to add to dtt-cc input, bit 1: sign to add to dtt-cs input
    wire                     [6:0] phases;        //!< other signals
        
    wire signed    [WND_WIDTH-1:0] window_w;
    wire                           var_pre2_first; //     
    wire                           pre_last_in_w;
    wire                           green_late;
    wire signed [DTT_IN_WIDTH-1:0] data_dtt_in; // multiplexed DTT input data
    reg                            dtt_we;
    wire                           dtt_prewe;
    reg                      [7:0] dtt_in_precntr; //
//    reg                            dtt_in_page;
    reg                      [8:0] dtt_in_wa;  
    
    
   
//    assign pre_last_out = pre_last_out_r;
//    assign pre_busy =     pre_busy_r || start || (!pre_last_in_w && phases[0]);
    assign pre_last_in = pre_last_in_w;
  
    mclt_bayer_fold_rgb #(
        .SHIFT_WIDTH     (SHIFT_WIDTH),
        .PIX_ADDR_WIDTH  (PIX_ADDR_WIDTH),
        .ADDR_DLY        (ADDR_DLYL), // 3 for mpy, 2 - for dsp
        .COORD_WIDTH     (COORD_WIDTH),
        .WND_WIDTH       (WND_WIDTH)
    ) mclt_bayer_fold_rgb_i (
        .clk           (clk),                 // input
        .rst           (rst),                 // input
        .start         (start_block_r[1]),    // input
        .tile_size     (tile_size),           // input[1:0] 
        .inv_checker   (inv_checker_ram_reg), // input
        .top_left      (top_left_ram_reg),    // input[7:0] 
        .green         (in_cntr[7]),  // input
        .valid_odd     (valid_odd_ram_reg),  // input[1:0] 
        .x_shft        (x_shft_ram_reg),      // input[6:0] 
        .y_shft        (y_shft_ram_reg),      // input[6:0] 
        .pix_addr      (pix_addr),    // output[8:0] 
        .pix_re        (pix_re),      // output
        .pix_page      (pix_page),    // output
        .window        (window_w),    // output[17:0] signed 
        .signs         (signs),       // output[1:0] 
        .phases        (phases),      // output[7:0]
// make it always 0 or 1 for R/B, then if use only not-in-series, use D -input for twice value         
        .var_pre2_first(var_pre2_first), // output
        .pre_last_in   (pre_last_in_w),// output reg
        .green_late    (green_late)    // output reg
    );
    
    
    mclt_baeyer_fold_accum_rgb #(
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .WND_WIDTH(WND_WIDTH),
        .DTT_IN_WIDTH(DTT_IN_WIDTH),
        .DSP_B_WIDTH(DSP_B_WIDTH),
        .DSP_A_WIDTH(DSP_A_WIDTH),
        .DSP_P_WIDTH(DSP_P_WIDTH)
    ) mclt_baeyer_fold_accum_rgb_i (
        .clk       (clk),          // input
        .rst       (rst),          // input
        .pre_phase (phases[6]),    // input
        .green     (green_late),   //input // valid with pix_d
        
        .pix_d     (pix_d),        // input[15:0] signed 
        .pix_sgn   (signs),        // input[1:0] 
        .window    (window_w),     // input[17:0] signed 
        .var_pre2_first (var_pre2_first),    // input
        .dtt_in    (data_dtt_in),  // output[24:0] signed
        .dtt_in_predv (dtt_prewe),  // output reg 
        .dtt_in_dv ()              // output reg 
    );

    always @ (posedge clk) begin
         if     (!dtt_prewe) dtt_in_precntr <= 0; 
         else                dtt_in_precntr <= dtt_in_precntr + 1;
         dtt_in_wa <= {1'b0, dtt_in_precntr[7],
                             dtt_in_precntr[7]?
                                 {dtt_in_precntr[0], dtt_in_precntr[6:1]}:
                                 dtt_in_precntr[6:0]};
         dtt_we<=dtt_prewe;
    end
// reading/converting DTT
    reg                            start_dtt; //  = dtt_in_cntr == 196; // fune tune? ~= 3/4 of 256 
//    reg                      [6:0] dtt_r_cntr; //
    reg                      [7:0] dtt_r_cntr; //
//    reg                            dtt_r_page;
    reg                            dtt_r_re;
    reg                            dtt_r_regen;
    reg                            dtt_start;
    
//    wire                           dtt_mode = dtt_r_cntr[6]; // TODO: or reverse? 
    wire                           dtt_mode = dtt_r_cntr[7] & dtt_r_cntr[6]; // (second of green only) 
//    wire                     [8:0] dtt_r_ra = {1'b0,dtt_r_page,dtt_r_cntr};
    wire                     [8:0] dtt_r_ra = {1'b0, dtt_r_cntr};
    wire signed             [35:0] dtt_r_data_w; // high bits are not used 
    wire signed [DTT_IN_WIDTH-1:0] dtt_r_data = dtt_r_data_w[DTT_IN_WIDTH-1:0]; 
    wire                     [8:0] dbg_dtt_in_rawa = dtt_in_wa-dtt_r_ra; // SuppressThisWarning VEditor : debug only signal
        
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

    wire signed [OUT_WIDTH-1:0] dtt_out_wd;
    wire                  [3:0] dtt_out_wa16;
    wire                        dtt_out_we;    
    wire                        dtt_sub16;
    wire                        dtt_inc16;
    reg                   [4:0] dtt_out_ram_cntr;
    reg                   [4:0] dtt_out_ram_wah;
    reg                   [1:0] dtt_out_ram_wpage;  // one of 4 pages (128 samples long) being written to
    reg                   [1:0] dtt_out_ram_wpage2; // later by 1 DTT
    wire                        dtt_start_fill; // some data available in DTT output buffer, OK to start consecutive readout
    reg                         dtt_start_first_fill;
    reg                         dtt_start_second_fill;
    reg                   [1:0] dtt_start_out;  // start read out to sin/cos rotator
    
    wire                  [8:0] dtt_out_ram_wa = {dtt_out_ram_wah,dtt_out_wa16};
    
    wire                  [8:0] dtt_out_ram_wa_rb =   {2'b0,dtt_out_ram_wa[8],dtt_out_ram_wa[5:0]};
    wire                  [8:0] dtt_out_ram_wa_g =    {1'b0,dtt_out_ram_wa[8],dtt_out_ram_wa[6:0]};
    
    wire                        dtt_out_we_r = dtt_out_we & ~dtt_out_ram_wa[7] & ~dtt_out_ram_wa[6];
    wire                        dtt_out_we_b = dtt_out_we & ~dtt_out_ram_wa[7] &  dtt_out_ram_wa[6];
    wire                        dtt_out_we_g = dtt_out_we &  dtt_out_ram_wa[7];
    
    reg                   [7:0] dtt_dly_cntr;
    reg                   [8:0] dtt_rd_cntr_pre; // 1 ahead of the former counter for dtt readout to rotator
    
    reg                   [8:0] dtt_rd_ra0; 
    reg                   [8:0] dtt_rd_ra1; 
    
    reg                   [3:0] dtt_rd_regen_dv;    // dtt output buffer mem read, register enable, data valid
    wire                 [35:0] dtt_rd_data_r_w; // high bits are not used 
    wire                 [35:0] dtt_rd_data_b_w; // high bits are not used 
    wire                 [35:0] dtt_rd_data_g_w; // high bits are not used 
    // data to be input to phase rotator
    wire signed [OUT_WIDTH-1:0] dtt_rd_data_r = dtt_rd_data_r_w[OUT_WIDTH-1:0]; // valid with dtt_rd_regen_dv[3]
    wire signed [OUT_WIDTH-1:0] dtt_rd_data_b = dtt_rd_data_b_w[OUT_WIDTH-1:0]; // valid with dtt_rd_regen_dv[3]
    wire signed [OUT_WIDTH-1:0] dtt_rd_data_g = dtt_rd_data_g_w[OUT_WIDTH-1:0]; // valid with dtt_rd_regen_dv[3]
    
    wire                        dtt_first_quad_out = ~dtt_out_ram_cntr[2];
   
    
    always @ (posedge clk) begin
    // reading memory and running DTT
         start_dtt <= dtt_in_precntr == DTT_IN_DELAY;
//        if (start_dtt)        dtt_r_page <= dtt_in_wa[7];// dtt_in_page;
        
        if (rst)              dtt_r_re <= 1'b0;
        else if (start_dtt)   dtt_r_re <= 1'b1;
        else if (&dtt_r_cntr) dtt_r_re <= 1'b0;
        dtt_r_regen <= dtt_r_re;
        
        if (!dtt_r_re) dtt_r_cntr <= 0;
        else           dtt_r_cntr <= dtt_r_cntr + 1;
        
        dtt_start <= (dtt_r_cntr[5:0] == 0) && dtt_r_re;
    end
    
    dtt_iv_8x8_ad #(
        .INPUT_WIDTH     (DTT_IN_WIDTH),
        .OUT_WIDTH       (OUT_WIDTH),
        .OUT_RSHIFT1     (OUT_RSHIFT),
        .OUT_RSHIFT2     (OUT_RSHIFT2),
        .TRANSPOSE_WIDTH (TRANSPOSE_WIDTH),
        .DSP_B_WIDTH     (DSP_B_WIDTH),
        .DSP_A_WIDTH     (DSP_A_WIDTH),
        .DSP_P_WIDTH     (DSP_P_WIDTH)
    ) dtt_iv_8x8_ad_i (
        .clk            (clk),              // input
        .rst            (rst),              // input
        .start          (dtt_start),        // input
        .mode           ({dtt_mode, 1'b0}), // input[1:0] for checker-board: only 2 of 4 modes (CC, SC) 
//        .xin            (dtt_r_data),       // input[24:0] signed 
        .xin            ({dtt_r_data[DTT_IN_WIDTH-1],dtt_r_data[DTT_IN_WIDTH-1:1]}),       // input[24:0] signed 
        .pre_last_in    (),                 // output reg 
        .mode_out       (), // dtt_mode_out),     // output[1:0] reg 
        .pre_busy       (),                 // output reg 
        .out_wd         (dtt_out_wd),       // output[24:0] reg 
        .out_wa         (dtt_out_wa16),     // output[3:0] reg 
        .out_we         (dtt_out_we),       // output reg 
        .sub16          (dtt_sub16),        // output reg 
        .inc16          (dtt_inc16),        // output reg 
        .start_out      (dtt_start_fill)    // output[24:0] signed
    );


    always @(posedge clk) begin
        if      (rst)        dtt_out_ram_cntr <= 0;
        else if (dtt_inc16)  dtt_out_ram_cntr <= dtt_out_ram_cntr + 1;
        dtt_out_ram_wah <=   dtt_out_ram_cntr - dtt_sub16;
        
        dtt_start_first_fill <= dtt_start_fill & dtt_first_quad_out;
        
        dtt_start_second_fill<= dtt_start_fill & ~dtt_first_quad_out;
        
        if (dtt_start_first_fill) dtt_out_ram_wpage <= dtt_out_ram_wah[4:3];
         
        if (dtt_start_second_fill) dtt_out_ram_wpage2 <= dtt_out_ram_wpage; 

        if      (rst)                  dtt_dly_cntr <= 0;
        else if (dtt_start_first_fill) dtt_dly_cntr <= DTT_OUT_DELAY;
        else if (|dtt_dly_cntr)        dtt_dly_cntr <= dtt_dly_cntr - 1;
        
        dtt_start_out <= {dtt_start_out[0],(dtt_dly_cntr == 1) ? 1'b1 : 1'b0};

        if      (rst)                   dtt_rd_regen_dv[0] <= 0;
        else if (dtt_start_out[0])      dtt_rd_regen_dv[0] <= 1;
        else if (&dtt_rd_cntr_pre[6:0]) dtt_rd_regen_dv[0] <= 0;
        
        if      (rst)                   dtt_rd_regen_dv[3:1] <= 0;
        else                            dtt_rd_regen_dv[3:1] <= dtt_rd_regen_dv[2:0];
        
//        if (dtt_start_out[0])           dtt_rd_cntr_pre <= {dtt_out_ram_wpage, 7'b0}; //copy page number
        if (dtt_start_out[0])           dtt_rd_cntr_pre <= {dtt_out_ram_wpage2, 7'b0}; //copy page number
        else if (dtt_rd_regen_dv[0]) dtt_rd_cntr_pre <= dtt_rd_cntr_pre + 1;

        dtt_rd_ra0 <= {dtt_rd_cntr_pre[8:7],
                       dtt_rd_cntr_pre[0] ^ dtt_rd_cntr_pre[1],
                       dtt_rd_cntr_pre[0]? (~dtt_rd_cntr_pre[6:2]) : dtt_rd_cntr_pre[6:2],
                       dtt_rd_cntr_pre[0]};    
        dtt_rd_ra1 <= {dtt_rd_cntr_pre[8:7],
                       dtt_rd_cntr_pre[0] ^ dtt_rd_cntr_pre[1],
                       dtt_rd_cntr_pre[0]? (~dtt_rd_cntr_pre[6:2]) : dtt_rd_cntr_pre[6:2],
                      ~dtt_rd_cntr_pre[0]};    
        
    end




// Three of 2 page buffers after dtt (feeding two phase rotators), address MSB is not needed
    ram18p_var_w_var_r #(
        .REGISTERS(1),
        .LOG2WIDTH_WR(5),
        .LOG2WIDTH_RD(5)
    ) ram18p_var_w_var_r_dtt_out_r_i (
        .rclk     (clk),                // input
        .raddr    (dtt_rd_ra0),         // input[8:0] 
        .ren      (dtt_rd_regen_dv[1]), // input
        .regen    (dtt_rd_regen_dv[2]), // input
        .data_out (dtt_rd_data_r_w),    // output[35:0] 
        .wclk     (clk),                // input
        .waddr    (dtt_out_ram_wa_rb),  // input[8:0] 
        .we       (dtt_out_we_r),       // input
        .web      (4'hf),               // input[3:0] 
        .data_in  ({{(36-DTT_IN_WIDTH){1'b0}}, dtt_out_wd}) // input[35:0] 
    );

    ram18p_var_w_var_r #(
        .REGISTERS(1),
        .LOG2WIDTH_WR(5),
        .LOG2WIDTH_RD(5)
    ) ram18p_var_w_var_r_dtt_out_b_i (
        .rclk     (clk),                // input
        .raddr    (dtt_rd_ra1),         // input[8:0] 
        .ren      (dtt_rd_regen_dv[1]), // input
        .regen    (dtt_rd_regen_dv[2]), // input
        .data_out (dtt_rd_data_b_w),    // output[35:0] 
        .wclk     (clk),                // input
        .waddr    (dtt_out_ram_wa_rb),  // input[8:0] 
        .we       (dtt_out_we_b),       // input
        .web      (4'hf),               // input[3:0] 
        .data_in  ({{(36-DTT_IN_WIDTH){1'b0}}, dtt_out_wd}) // input[35:0] 
    );

    ram18p_var_w_var_r #(
        .REGISTERS(1),
        .LOG2WIDTH_WR(5),
        .LOG2WIDTH_RD(5)
    ) ram18p_var_w_var_r_dtt_out_g_i (
        .rclk     (clk),                // input
        .raddr    (dtt_rd_ra1),         // input[8:0] 
        .ren      (dtt_rd_regen_dv[1]), // input
        .regen    (dtt_rd_regen_dv[2]), // input
        .data_out (dtt_rd_data_g_w),    // output[35:0] 
        .wclk     (clk),                // input
        .waddr    (dtt_out_ram_wa_g),   // input[8:0] 
        .we       (dtt_out_we_g),       // input
        .web      (4'hf),               // input[3:0] 
        .data_in  ({{(36-DTT_IN_WIDTH){1'b0}}, dtt_out_wd}) // input[35:0] 
    );




endmodule

