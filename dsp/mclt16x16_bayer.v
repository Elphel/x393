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
    input                             inv_checker,  //!< 0 - includes main diagonal (symmetrical DTT), 1 - antisymmetrical DTT
    input                       [7:0] top_left,     //!< index of the 16x16 top left corner
    input                       [1:0] valid_rows,   //!< 3 for green, 1 or 2 for R/B - which of the even/odd checker rows contain pixels
    input           [SHIFT_WIDTH-1:0] x_shft,       //!< tile pixel X fractional shift (valid @ start) 
    input           [SHIFT_WIDTH-1:0] y_shft,       //!< tile pixel Y fractional shift (valid @ start)
    
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
    output signed [OUT_WIDTH - 1 : 0] dout0,        //!<frequency domain data output (even samples)            
    output signed [OUT_WIDTH - 1 : 0] dout1         //!<frequency domain data output (odd s amples)           
    
);
    
    // When defined, use 2 DSP multipleierts
//    `define DSP_ACCUM_FOLD 1
    
    localparam  DTT_OUT_DELAY = 128; // 191; // start output to sin/cos rotator, with checker - 2*64 +/=?
    localparam  DTT_IN_DELAY =  62; // 69; // wa -ra min = 1
    wire signed [OUT_WIDTH - 1 : 0] dbg_dout0 = {dout0[OUT_WIDTH - 1],dout0[OUT_WIDTH - 1 : 1]}; // SuppressThisWarning VEditor : debug only signal
    wire signed [OUT_WIDTH - 1 : 0] dbg_dout1 = {dout1[OUT_WIDTH - 1],dout1[OUT_WIDTH - 1 : 1]}; // SuppressThisWarning VEditor : debug only signal
    
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
    reg [SHIFT_WIDTH-1:0] x_shft_r5; // registered @ dtt_start_first_fill
    reg [SHIFT_WIDTH-1:0] y_shft_r5; // registered @ dtt_start_first_fill
    reg                   inv_checker_r;                
    reg                   inv_checker_r2;                
    reg                   inv_checker_r3;                
    reg                   inv_checker_r4;                
    reg                   inv_checker_r5;                

    wire                     [1:0] signs;        //!< bit 0: sign to add to dtt-cc input, bit 1: sign to add to dtt-cs input
    wire                     [6:0] phases;        //!< other signals
    
    wire signed    [WND_WIDTH-1:0] window_w;
 
    wire signed [DTT_IN_WIDTH-1:0] data_dtt_in; // multiplexed DTT input data
    
       
    reg                      [6:0] dtt_in_cntr; //
    reg                            dtt_in_page;
    wire                     [8:0] dtt_in_wa = {1'b0,dtt_in_page, dtt_in_cntr[0], dtt_in_cntr[6:1]};  
//    wire                           dtt_we = phases[14];
    wire                           dtt_we;
    
       
//    wire                    [ 1:0] pix_sgn_d;
//    reg                     [ 1:0] pix_sgn_r;
    
//    wire                           var_first; // adding subtracting first variant of 4 folds    
    wire                           var_pre2_first; //     
//    reg                            var_last;    // next cycle the   data_xx_r will have data  (in_busy[14], ...)

// reading/converting DTT
    reg                            start_dtt; //  = dtt_in_cntr == 196; // fune tune? ~= 3/4 of 256 
    reg                      [6:0] dtt_r_cntr; //
    reg                            dtt_r_page;
    reg                            dtt_r_re;
    reg                            dtt_r_regen;
    reg                            dtt_start;
    
    wire                           dtt_mode = dtt_r_cntr[6]; // TODO: or reverse? 
    wire                     [8:0] dtt_r_ra = {1'b0,dtt_r_page,dtt_r_cntr};
    wire signed             [35:0] dtt_r_data_w; // high bits are not used 
    wire signed [DTT_IN_WIDTH-1:0] dtt_r_data = dtt_r_data_w[DTT_IN_WIDTH-1:0]; 
    wire signed [DTT_IN_WIDTH-1:0] dbg_dtt_r_data = {dtt_r_data_w[DTT_IN_WIDTH-1],dtt_r_data_w[DTT_IN_WIDTH-1:1]}; // SuppressThisWarning VEditor : debug only signal
   
    reg                            pre_last_out_r;
    wire                           pre_last_in_w;
   
    assign pre_last_out = pre_last_out_r;
    assign pre_busy =     pre_busy_r || start || (!pre_last_in_w && phases[0]);
    assign pre_last_in = pre_last_in_w;
   
    
    always @ (posedge clk) begin
    
        if (start) begin
            x_shft_r <=      x_shft;
            y_shft_r <=      y_shft;
            inv_checker_r <= inv_checker;
        end
        start_r <= {start_r[0], start};
        if (start_r[1]) begin      // same latency as mpix_a_w
            x_shft_r2 <=      x_shft_r;
            y_shft_r2 <=      y_shft_r;
            inv_checker_r2 <= inv_checker_r;
        end

        if (start_dtt) begin 
            x_shft_r3 <=      x_shft_r2; 
            y_shft_r3 <=      y_shft_r2;
            inv_checker_r3 <= inv_checker_r2;
        end

        if (dtt_start_first_fill) begin 
            x_shft_r4 <= x_shft_r3; 
            y_shft_r4 <= y_shft_r3;
            inv_checker_r4 <= inv_checker_r3;
        end

        if (dtt_start_second_fill) begin 
            x_shft_r5 <= x_shft_r4; 
            y_shft_r5 <= y_shft_r4;
            inv_checker_r5 <= inv_checker_r4;
        end


//         if (!phases[14]) dtt_in_cntr <= 0; 
         if     (!dtt_we) dtt_in_cntr <= 0; 
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
        
        dtt_start <= (dtt_r_cntr[5:0] == 0) && dtt_r_re;
    
    end
    
`ifdef DSP_ACCUM_FOLD
        localparam ADDR_DLYL = 4 - EXT_PIX_LATENCY; // 4'h2; // 3 for mpy, 2 - for dsp
`else        
        localparam ADDR_DLYL = 5 - EXT_PIX_LATENCY; // 4'h3; // 3 for mpy, 2 - for dsp
`endif        
  
  
      
    mclt_bayer_fold #(
        .SHIFT_WIDTH     (SHIFT_WIDTH),
        .PIX_ADDR_WIDTH  (PIX_ADDR_WIDTH),
        .ADDR_DLY        (ADDR_DLYL), // 3 for mpy, 2 - for dsp
        .COORD_WIDTH     (COORD_WIDTH),
        .WND_WIDTH       (WND_WIDTH)
    ) mclt_bayer_fold_i (
        .clk           (clk),         // input
        .rst           (rst),         // input
        .start         (start),       // input
        .tile_size     (tile_size),   // input[1:0] 
        .inv_checker   (inv_checker), // input
        .top_left      (top_left),    // input[7:0] 
        .valid_rows    (valid_rows),  // input[1:0] 
        .x_shft        (x_shft),      // input[6:0] 
        .y_shft        (y_shft),      // input[6:0] 
        .pix_addr      (pix_addr),    // output[8:0] 
        .pix_re        (pix_re),      // output
        .pix_page      (pix_page),    // output
        .window        (window_w),    // output[17:0] signed 
        .signs         (signs),       // output[1:0] 
        .phases        (phases),      // output[7:0]
        .var_pre2_first(var_pre2_first), // output
        .pre_last_in   (pre_last_in_w)// output reg
    );



    wire [8:0] dbg_diff_wara_dtt_in = dtt_in_wa-dtt_r_ra; // SuppressThisWarning VEditor : debug only signal
    
    
    wire signed [OUT_WIDTH-1:0] dtt_out_wd;
    wire signed [OUT_WIDTH-1:0] dbg_dtt_out_wd={dtt_out_wd[OUT_WIDTH-1],dtt_out_wd[OUT_WIDTH-1:1]};// SuppressThisWarning VEditor : debug only signal
    
    
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
    

// frequency domain, high address bit - page, 2 next - mode, 6 LSBs - transposed FD data (vertical first)
// will change: 2 address bits - page, 1 - mode, 6 LSBs - transposed FD data (vertical first)
// here delay should start after full 2 modes (128 samples) written, as readout to rotators starts from both ends
 
    wire                  [8:0] dtt_out_ram_wa = {dtt_out_ram_wah,dtt_out_wa16};
    reg                   [7:0] dtt_dly_cntr;
    reg                   [8:0] dtt_rd_cntr_pre; // 1 ahead of the former counter for dtt readout to rotator
    
    // TODO: fix rd addresses
    
    reg                   [8:0] dtt_rd_ra0; 
    reg                   [8:0] dtt_rd_ra1; 
    
    reg                   [3:0] dtt_rd_regen_dv;    // dtt output buffer mem read, register enable, data valid
    wire                 [35:0] dtt_rd_data0_w; // high bits are not used 
    wire                 [35:0] dtt_rd_data1_w; // high bits are not used 
    // data to be input to phase rotator
    wire signed [OUT_WIDTH-1:0] dtt_rd_data0 = dtt_rd_data0_w[OUT_WIDTH-1:0]; // valid with dtt_rd_regen_dv[3]
    wire signed [OUT_WIDTH-1:0] dtt_rd_data1 = dtt_rd_data1_w[OUT_WIDTH-1:0]; // valid with dtt_rd_regen_dv[3]
    wire signed [OUT_WIDTH-1:0] dbg_dtt_rd_data0 = {dtt_rd_data0[OUT_WIDTH-1],dtt_rd_data0[OUT_WIDTH-1:1]}; // SuppressThisWarning VEditor : debug only signal
    wire signed [OUT_WIDTH-1:0] dbg_dtt_rd_data1 = {dtt_rd_data1[OUT_WIDTH-1],dtt_rd_data1[OUT_WIDTH-1:1]}; // SuppressThisWarning VEditor : debug only signal
    
    wire                        dtt_first_quad_out = ~dtt_out_ram_cntr[2];
    
    always @(posedge clk) begin
        if      (rst)        dtt_out_ram_cntr <= 0;
        else if (dtt_inc16)  dtt_out_ram_cntr <= dtt_out_ram_cntr + 1; // make it copy input page?
        
        dtt_out_ram_wah <= dtt_out_ram_cntr - dtt_sub16;
        
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
    
    
    mclt_baeyer_fold_accum #(
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .WND_WIDTH(WND_WIDTH),
        .DTT_IN_WIDTH(DTT_IN_WIDTH),
        .DSP_B_WIDTH(DSP_B_WIDTH),
        .DSP_A_WIDTH(DSP_A_WIDTH),
        .DSP_P_WIDTH(DSP_P_WIDTH)
    ) mclt_baeyer_fold_accum_i (
        .clk       (clk),          // input
        .rst       (rst),          // input
        .pre_phase (phases[6]),    // input
        .pix_d     (pix_d),        // input[15:0] signed 
        .pix_sgn   (signs),        // input[1:0] 
        .window    (window_w),     // input[17:0] signed 
        .var_pre2_first (var_pre2_first),    // input
        .dtt_in    (data_dtt_in),  // output[24:0] signed
        .dtt_in_dv (dtt_we)        // output reg 
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
        .start16        (),                 // output reg 
        .start_out      (dtt_start_fill)    // output[24:0] signed
    );
    //[DTT_IN_WIDTH-1:0
    // still incorrectly shows difference when filled nto sequentially 
    reg  [8:0] dbg_last_dtt_out_ram_wa; // SuppressThisWarning VEditor : debug only signal
    wire [8:0] dbg_diff_wara_dtt_out0 = dbg_last_dtt_out_ram_wa-dtt_rd_ra0; // SuppressThisWarning VEditor : debug only signal
    wire [8:0] dbg_diff_wara_dtt_out1 = dbg_last_dtt_out_ram_wa-dtt_rd_ra1; // SuppressThisWarning VEditor : debug only signal
    always @ (posedge clk) begin
        if (dtt_out_we) dbg_last_dtt_out_ram_wa <= dtt_out_ram_wa;
    end

// Two of 2 page buffers after dtt (feeding two phase rotators), address MSB is not needed
    ram18p_var_w_var_r #(
        .REGISTERS(1),
        .LOG2WIDTH_WR(5),
        .LOG2WIDTH_RD(5)
    ) ram18p_var_w_var_r_dtt_out0_i (
        .rclk     (clk),                // input
        .raddr    (dtt_rd_ra0),          // input[8:0] 
        .ren      (dtt_rd_regen_dv[1]), // input
        .regen    (dtt_rd_regen_dv[2]), // input
        .data_out (dtt_rd_data0_w),      // output[35:0] 
        .wclk     (clk),                // input
        .waddr    (dtt_out_ram_wa),     // input[8:0] 
        .we       (dtt_out_we),         // input
        .web      (4'hf),               // input[3:0] 
        .data_in  ({{(36-DTT_IN_WIDTH){1'b0}}, dtt_out_wd}) // input[35:0] 
    );

    ram18p_var_w_var_r #(
        .REGISTERS(1),
        .LOG2WIDTH_WR(5),
        .LOG2WIDTH_RD(5)
    ) ram18p_var_w_var_r_dtt_out1_i (
        .rclk     (clk),                // input
        .raddr    (dtt_rd_ra1),          // input[8:0] 
        .ren      (dtt_rd_regen_dv[1]), // input
        .regen    (dtt_rd_regen_dv[2]), // input
        .data_out (dtt_rd_data1_w),      // output[35:0] 
        .wclk     (clk),                // input
        .waddr    (dtt_out_ram_wa),     // input[8:0] 
        .we       (dtt_out_we),         // input
        .web      (4'hf),               // input[3:0] 
        .data_in  ({{(36-DTT_IN_WIDTH){1'b0}}, dtt_out_wd}) // input[35:0] 
    );

// Two rotators in parallel
// TODO: add negating for antisymmetrical (inverted checkerboard)
// Rotate phase (equvalent to pixel domain shift)
    phase_rotator #(
        .FD_WIDTH(OUT_WIDTH),
        .SHIFT_WIDTH(SHIFT_WIDTH), // should be exactly 7
        .DSP_B_WIDTH(DSP_B_WIDTH),
        .DSP_A_WIDTH(DSP_A_WIDTH),
        .DSP_P_WIDTH(DSP_P_WIDTH),
        .DECIMATE   (1'b1),
        .ODD        (1'b0)
    ) phase_rotator0_i (
        .clk           (clk),           // input
        .rst           (rst),           // input
        .start         (dtt_start_out[1]), // input
        // are these shift OK? Will need to be valis only @ dtt_start_out
        .shift_h       (x_shft_r5),     // input[6:0] signed 
        .shift_v       (y_shft_r5),     // input[6:0] signed
        .inv_checker   (inv_checker_r5),// input only used for Bayer mosaic data 
        .fd_din        (dtt_rd_data0),  // input[24:0] signed. Expected latency = 3 from start  
        .fd_out        (dout0),         // output[24:0] reg signed 
        .pre_first_out (pre_first_out), // output reg 
        .fd_dv         (dv)             // output reg 
    );

    phase_rotator #(
        .FD_WIDTH(OUT_WIDTH),
        .SHIFT_WIDTH(SHIFT_WIDTH), // should be exactly 7
        .DSP_B_WIDTH(DSP_B_WIDTH),
        .DSP_A_WIDTH(DSP_A_WIDTH),
        .DSP_P_WIDTH(DSP_P_WIDTH),
        .DECIMATE   (1'b1),
        .ODD        (1'b1)
    ) phase_rotator1_i (
        .clk           (clk),           // input
        .rst           (rst),           // input
        .start         (dtt_start_out[1]), // input
        // are these shift OK? Will need to be valis only @ dtt_start_out
        .shift_h       (x_shft_r5),     // input[6:0] signed 
        .shift_v       (y_shft_r5),     // input[6:0] signed
        .inv_checker   (inv_checker_r5),// input only used for Bayer mosaic data 
        .fd_din        (dtt_rd_data1),  // input[24:0] signed. Expected latency = 3 from start  
        .fd_out        (dout1),         // output[24:0] reg signed 
        .pre_first_out (),              // output reg 
        .fd_dv         ()               // output reg 
    );



    reg [7:0] out_addr_r;
    reg [3:0] dead_cntr;
    reg       pre_busy_r;  
    
    assign out_addr = {out_addr_r[0],out_addr_r[1],out_addr_r[4:2],out_addr_r[7:5]};

    always @ (posedge clk) begin
        if (!dv) out_addr_r <= 0;
        else     out_addr_r <= out_addr_r + 1;
        
        pre_last_out_r <= out_addr_r == 8'hfe;
        
        if      (rst)            pre_busy_r <= 0;
        else if (pre_last_in_w)  pre_busy_r <= 1;
        else if (dead_cntr == 0) pre_busy_r <= 0;
        
        
        if (~pre_busy_r) dead_cntr <= DEAD_CYCLES;
        else             dead_cntr <= dead_cntr - 1;
        
    end




endmodule

