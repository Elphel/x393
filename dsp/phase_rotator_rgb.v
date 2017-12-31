/*!
 * <b>Module:</b> phase_rotator_rgb
 * @file phase_rotator_rgb.v
 * @date 2017-12-11  
 * @author eyesis
 *     
 * @brief 2-d phase rotator in frequency domain (subpixel shift)
 *
 * @copyright Copyright (c) 2017 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 *
 * <b>License </b>
 *
 * phase_rotator_rgb.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * phase_rotator_rgb.v is distributed in the hope that it will be useful,
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

module  phase_rotator_rgb#(
    parameter FD_WIDTH =        25, // input/output data width, signed
    parameter SHIFT_WIDTH =      7, // x/y subpixel shift, signed -0.5<=shift<0.5
    parameter DSP_B_WIDTH =     18, // signed, output from sin/cos ROM
    parameter DSP_A_WIDTH =     25,
    parameter DSP_P_WIDTH =     48,
    parameter COEFF_WIDTH =     17, // = DSP_B_WIDTH - 1 or positive numbers,
    parameter GREEN       =      0, // 0: use 1 DTT block (R,B), 1: use two DTT blocks (G) 
    parameter START_DELAY =    128, // delay start of input memory readout
    parameter TILE_PAGE_BITS =   2   // 1 or 2  only: number of bits in tile counter (>=2 for simultaneous rotated readout, limited by red)
)(
    input                            clk,           //!< system clock, posedge
    input                            rst,           //!< sync reset
    input                            start,         //!< start of delay
    input       [TILE_PAGE_BITS-1:0] wpage,         //!< page (64 for R,B, 128 for G) last being written (may need delay?)
    input signed   [SHIFT_WIDTH-1:0] shift_h,       //!< subpixel shift horizontal
    input signed   [SHIFT_WIDTH-1:0] shift_v,       //!< subpixel shift vertical
    input                            inv_checker,   //!< negate 2-nd and fourth samples (for handling inverted checkerboard)
    input                            odd_rows,      //!< when not GEEN (R or B) 0: even (first) rows non-zero, 1: odd (second)  
    // input data CC,CS,SC,SS in column scan order (matching DTT)
//    output             [GREEN + 6:0] in_addr,       //!< input buffer address
    output [GREEN + TILE_PAGE_BITS + 5:0] in_addr,       //!< input buffer address
    output                     [1:0] in_re,         //!< input buffer re/regen      
    input signed      [FD_WIDTH-1:0] fd_din,        //!< frequency domain data in, LATENCY=3 from start
    output signed     [FD_WIDTH-1:0] fd_out,        //!< frequency domain data in
    output                           pre_first_out, //!< 1 cycle before output data valid 
    output reg                       pre_last_out,  //!< 2 cycle before last data valid 
    output                           fd_dv,         //!< output data valid
    output                     [8:0] fd_wa          // output address including page
);

    reg signed   [SHIFT_WIDTH-1:0] shift_h_r;
    reg signed   [SHIFT_WIDTH-1:0] shift_v_r;
    reg       [TILE_PAGE_BITS-1:0] wpage_r;
    reg                      [2:0] inv;
    reg                      [1:0] dtt_start_out;
    reg                      [7:0] dtt_dly_cntr;
    reg                      [4:0] dtt_rd_regen_dv;
    reg     [TILE_PAGE_BITS + 7:0] dtt_rd_cntr_pre; // 1 ahead of the former counter for dtt readout to rotator
    reg                      [7:0] in_addr_r;       //!< input buffer address
    reg                      [8:0] out_addr_r;
    assign  in_addr = in_addr_r[GREEN + TILE_PAGE_BITS + 5:0];
    assign  in_re = dtt_rd_regen_dv[2:1];
//    assign  fd_wa = {out_addr_r[8], out_addr_r[0],out_addr_r[1],out_addr_r[4:2],out_addr_r[7:5]};
    assign  fd_wa = {out_addr_r[8], out_addr_r[1],out_addr_r[0],out_addr_r[4:2],out_addr_r[7:5]};

    
    wire [TILE_PAGE_BITS + 8:0]  dtt_rd_cntr_pre_ext = {1'b0,dtt_rd_cntr_pre}; // to make sure it is 10 bits at least
    always @ (posedge clk) begin
        if (start) begin
            shift_h_r <=     shift_h;
            shift_v_r <=     shift_v;
            inv <= inv_checker ?
                   (( GREEN || odd_rows) ? 5 : 6):
                   ((!GREEN && odd_rows) ? 3 : 0);
            wpage_r <=       wpage;
        end
        

        if      (rst)                   dtt_dly_cntr <= 0;
        else if (start)                 dtt_dly_cntr <= START_DELAY;
        else if (|dtt_dly_cntr)         dtt_dly_cntr <= dtt_dly_cntr - 1;
        
        dtt_start_out <= {dtt_start_out[0],(dtt_dly_cntr == 1) ? 1'b1 : 1'b0};
        
        if      (rst)                   dtt_rd_regen_dv[0] <= 0;
        else if (dtt_start_out[0])      dtt_rd_regen_dv[0] <= 1;
        else if (&dtt_rd_cntr_pre[7:0]) dtt_rd_regen_dv[0] <= 0;
        
        if      (rst)                   dtt_rd_regen_dv[3:1] <= 0;
        else                            dtt_rd_regen_dv[3:1] <= dtt_rd_regen_dv[2:0];
        
        if (dtt_start_out[0])           dtt_rd_cntr_pre <= {wpage_r, 8'b0}; //copy page number
        else if (dtt_rd_regen_dv[0])    dtt_rd_cntr_pre <= dtt_rd_cntr_pre + 1;
        
        if (GREEN) in_addr_r <= {dtt_rd_cntr_pre[8],
                                 dtt_rd_cntr_pre[0] ^ dtt_rd_cntr_pre[1],
                                 dtt_rd_cntr_pre[0] ? (~dtt_rd_cntr_pre[7:2]) : dtt_rd_cntr_pre[7:2]};
        else       in_addr_r <= {dtt_rd_cntr_pre_ext[9], // 1'b0, 
                                 dtt_rd_cntr_pre[8],
//                               dtt_rd_cntr_pre[0] ^ dtt_rd_cntr_pre[1],
                                 dtt_rd_cntr_pre[1] ?
                                 (dtt_rd_cntr_pre[0] ? (~dtt_rd_cntr_pre[7:2]) : {~dtt_rd_cntr_pre[7:5],dtt_rd_cntr_pre[4:2]}):
                                 (dtt_rd_cntr_pre[0] ? {dtt_rd_cntr_pre[7:5],~dtt_rd_cntr_pre[4:2]} : dtt_rd_cntr_pre[7:2])};

        if (pre_first_out) out_addr_r <= {wpage_r[0],8'b0};
        else if (fd_dv)    out_addr_r <= out_addr_r + 1;
        
        pre_last_out <=  out_addr_r[7:0] == 8'hfe;
        
    end

    phase_rotator #(
        .FD_WIDTH   (FD_WIDTH),
        .SHIFT_WIDTH(SHIFT_WIDTH), // should be exactly 7
        .DSP_B_WIDTH(DSP_B_WIDTH),
        .DSP_A_WIDTH(DSP_A_WIDTH),
        .DSP_P_WIDTH(DSP_P_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH),
        .DECIMATE   (1'b0),
        .ODD        (1'b0)
    ) phase_rotator0_i (
        .clk           (clk),            // input
        .rst           (rst),            // input
        .start         (dtt_start_out[1]), // input
        // are these shift OK? Will need to be valid only @ dtt_start_out
        .shift_h       (shift_h_r),      // input[6:0] signed 
        .shift_v       (shift_v_r),      // input[6:0] signed
        .inv           (inv),            // input [2:0] 
        .fd_din        (fd_din),         // input[24:0] signed. Expected latency = 3 from start  
        .fd_out        (fd_out),         // output[24:0] reg signed 
        .pre_first_out (pre_first_out),  // output reg 
        .fd_dv         (fd_dv)           // output reg 
    );

    
endmodule
