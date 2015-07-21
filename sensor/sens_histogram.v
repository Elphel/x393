/*******************************************************************************
 * Module: sens_histogram
 * Date:2015-05-29  
 * Author: Andrey Filippov     
 * Description: Calculates per-color histogram over the specified rectangular region
 *
 * Copyright (c) 2015 Elphel, Inc.
 * sens_histogram.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  sens_histogram.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  sens_histogram #(
    parameter HISTOGRAM_RAM_MODE =     "NOBUF", // valid: "NOBUF" (32-bits, no buffering), "BUF18", "BUF32"
    parameter HISTOGRAM_ADDR =         'h33c,
    parameter HISTOGRAM_ADDR_MASK =    'h7fe,
    parameter HISTOGRAM_LEFT_TOP =     'h0,
    parameter HISTOGRAM_WIDTH_HEIGHT = 'h1 // 1.. 2^16, 0 - use HACT
)(
//    input         rst,
    input         mrst,      // @posedge mclk, sync reset
    input         prst,      // @posedge pclk, sync reset
    input         pclk,   // global clock input, pixel rate (96MHz for MT9P006)
    input         pclk2x,
    input         sof,
    input         hact,
    input   [7:0] hist_di, // 8-bit pixel data
    
    input         mclk,
    input         hist_en,  // @mclk - gracefully enable/disable histogram
    input         hist_rst, // @mclk - immediately disable if true
    output        hist_rq,
    input         hist_grant,
    output [31:0] hist_do,
    output        hist_dv,
    input   [7:0] cmd_ad,      // byte-serial command address/data (up to 6 bytes: AL-AH-D0-D1-D2-D3 
    input         cmd_stb      // strobe (with first byte) for the command a/d

);
    reg         hist_bank_pclk;
    
    reg   [7:0] hist_d;
    reg   [9:0] hist_addr;
    reg   [9:0] hist_addr_d;
    reg   [9:0] hist_addr_d2;
    reg   [9:0] hist_rwaddr;
    
    reg  [31:0] inc_r;
    wire [31:0] inc_w;
    reg  [31:0] to_inc;
    wire [31:0] hist_new;
    reg         hist_rwen;  // read/write enable
//    reg   [2:0] hist_regen; // bram output register enable: [0] - ren, [1] - regen, [2] - next after regen
    reg   [1:0] hist_regen; // bram output register enable: [0] - ren, [1] - regen, [2] - next after regen
    reg         hist_we;    // bram write enable
    reg         hist_bank_mclk;
    
    wire          set_left_top_w;
    wire          set_width_height_w;
     
    wire    [1:0] pio_addr;
    wire   [31:0] pio_data;
    wire          pio_stb;
    
    reg    [31:0] lt_mclk;   // left+top @ posedge mclk
    reg    [31:0] wh_mclk;   // width+height @ posedge mclk
    reg    [15:0] width_m1;  // @posedge pclk
    reg    [15:0] height_m1; // @posedge pclk 
    reg    [15:0] left;      // @posedge pclk
    reg    [15:0] top;       // @posedge pclk
    
    reg           hist_en_pclk;  // @pclk - gracefully enable/disable histogram
    reg           hist_rst_pclk; // @pclk - immediately disable if true
    reg           en;
    reg           en_new; // @ pclk - enable new frame
    
    reg           en_mclk;
    
    wire          set_left_top_pclk;
    wire          set_width_height_pclk;
    wire          pclk_sync; // CE for pclk2x, ~=pclk
    
    reg     [1:0] bayer_pclk;
    reg           hact_d;
    
    reg           top_margin;   // above (before) active window
    reg           hist_done;    // @pclk single cycle
    wire          hist_done_mclk;
    reg           vert_woi;     // vertically in window
    reg           left_margin;  // left of (before) active window
    reg    [2:0]  woi;          // @ pclk2x - inside WOI (and delayed
    reg           hor_woi;      // vertically in window
    reg    [15:0] vcntr;        // vertical (line) counter
    reg    [15:0] hcntr;        // horizontal (pixel) counter
    wire          vcntr_zero_w; // vertical counter is zero
    wire          hcntr_zero_w; // horizontal counter is zero
    reg           same_addr; // @pclk2x - current histoigram address is the same as before-previous (previous was different color)
    

    reg           hist_out; // some data yet to be sent out
    reg           hist_out_d;
    reg     [2:0] hist_re;
    reg     [9:0] hist_raddr;
    reg           hist_rq_r;
    wire          hist_xfer_done_mclk; //@ mclk
    wire          hist_xfer_done; // @pclk
    reg           hist_xfer_busy; // @pclk, during histogram readout , immediately after woi (no gaps)
    reg           wait_readout;   // only used in NOBUF mode, in outher modes readout is expected to be always finished in time
    
    
    assign set_left_top_w =     pio_stb && (pio_addr == HISTOGRAM_LEFT_TOP );
    assign set_width_height_w = pio_stb && (pio_addr == HISTOGRAM_WIDTH_HEIGHT );
    assign vcntr_zero_w =      !(|vcntr);
    assign hcntr_zero_w =      !(|hcntr);
    assign inc_w =             to_inc+1;

    assign hist_rq = hist_rq_r;
    assign hist_dv = hist_re[2];
    assign hist_xfer_done_mclk = hist_out_d && !hist_out_d;
    
    
    always @ (posedge mclk) begin
        if (set_left_top_w)     lt_mclk <= pio_data;
        if (set_width_height_w) wh_mclk <= pio_data;
    end
    
    always @ (posedge pclk) begin
        if (set_left_top_pclk)     {top,left} <= lt_mclk[31:0];
        if (set_width_height_pclk) {height_m1,width_m1} <= wh_mclk[31:0];
    end
    
    always @ (posedge pclk) begin
        hact_d <= hact;
        if (sof)        bayer_pclk <= 0;
        else if (hact)  bayer_pclk <= {bayer_pclk[1],         ~bayer_pclk[0]};
        else            bayer_pclk <= {bayer_pclk[1] ^ hact_d, 1'b0};
        
        
    end
    
    // process WOI
    always @ (posedge pclk) begin
        if      (!en)           top_margin <= 0;
        else if (sof && en_new) top_margin <= 1;
        else if (vcntr_zero_w)  top_margin <= 0;
        
        if      (!en)          vert_woi <= 0;
        else if (vcntr_zero_w) vert_woi <= top_margin;
        
        hist_done <= vcntr_zero_w && vert_woi;
        
        if (sof)                             vcntr <= top;
        else if (vcntr_zero_w && top_margin) vcntr <= height_m1;
        else if (top_margin || vert_woi)     vcntr <= vcntr - 1;
        
        if (!vert_woi)         left_margin <= 0;
        else if (!hact)        left_margin <= 1;
        else if (hcntr_zero_w) left_margin <= 0;

        if (!vert_woi || wait_readout)  hor_woi <= 0; // postpone WOI if reading out/erasing histogram (no-buffer mode)
        else if (hcntr_zero_w)          hor_woi <= left_margin;
        
        if      (!hact)                       hcntr <= left;
        else if (hcntr_zero_w && left_margin) hcntr <= width_m1;
        else if (left_margin || hor_woi)      hcntr <= hcntr - 1;
        
        if (hor_woi) hist_d <= hist_di;
        
        if      (!en)                                          hist_bank_pclk <= 0;
        else if (hist_done && (HISTOGRAM_RAM_MODE != "NOBUF")) hist_bank_pclk <= !hist_bank_pclk;
        // hist_xfer_busy to extend en
        if      (!en)                      hist_xfer_busy <= 0;
        else if (hist_xfer_done)           hist_xfer_busy <= 0;
        else if (vcntr_zero_w && vert_woi) hist_xfer_busy <= 1;
        
        hist_en_pclk <= hist_en;
        hist_rst_pclk <= hist_rst;
        
        if      (hist_rst_pclk)                               en <= 0;
        else if (hist_en_pclk)                                en <= 1;
        else if (!top_margin && !vert_woi && !hist_xfer_busy) en <= 0;
        
        en_new <= !hist_rst_pclk && hist_en_pclk;
        
    end


    always @(posedge pclk2x) begin
        if (pclk_sync)  begin
            woi <= {woi[1:0],hor_woi};
            hist_addr <= {bayer_pclk,hist_d};
            hist_addr_d <= hist_addr;
            hist_addr_d2 <= hist_addr_d;
            same_addr <= woi[0] && woi[2] && (hist_addr_d2 == hist_addr);
            if (same_addr) to_inc <= inc_r;
            else           to_inc <= hist_new;
            
        end
        hist_rwen <= (woi[0] & ~pclk_sync) || (woi[2] & pclk_sync);
//        hist_regen <= {hist_regen[1:0], woi[0] & ~pclk_sync};
        hist_regen <= {hist_regen[0], woi[0] & ~pclk_sync};
        hist_we <= woi[2] & pclk_sync;
        
        if     (woi[0] & ~pclk_sync) hist_rwaddr <= hist_addr;
        else if (woi[2] & pclk_sync) hist_rwaddr <= hist_addr_d2;

        if      (HISTOGRAM_RAM_MODE != "BUF18")  inc_r <= inc_w;
        else if (inc_w[18])                      inc_r <= 32'h3fff; // maximal value
        else                                     inc_r <= {14'b0,inc_w[17:0]};
        
    end

    
    always @ (posedge mclk) begin
        en_mclk <= en;
        if      (!en_mclk)       hist_out <= 0;
        else if (hist_done_mclk) hist_out <= 1;
        else if (&hist_raddr)    hist_out <= 0;
        
        hist_out_d <= hist_out;
        
        if      (!en_mclk)       hist_raddr <= 0;
        else if (hist_re)        hist_raddr <= hist_raddr + 1;
        
        if      (!en_mclk)             hist_rq_r <= 0;
        else if (hist_out && !hist_re) hist_rq_r <= 1;
        
        if      (!hist_out)        hist_re[0] <= 0;
        else if (hist_grant)   hist_re[0] <= 1;
        else if (&hist_raddr[7:0]) hist_re[0] <= 0;
        
        hist_re[2:1] <= hist_re[1:0];
        
        if      (!en_mclk)                                               hist_bank_mclk <= 0;
        else if (hist_xfer_done_mclk && (HISTOGRAM_RAM_MODE != "NOBUF")) hist_bank_mclk <= !hist_bank_mclk;
    
    end
    
    always @ (posedge pclk) begin
        if      (!en)                                          wait_readout <= 0;
        else if ((HISTOGRAM_RAM_MODE == "NOBUF") && hist_done) wait_readout <= 1;
        else if (hist_xfer_done)                               wait_readout <= 0;
    
    end

    
    cmd_deser #(
        .ADDR        (HISTOGRAM_ADDR),
        .ADDR_MASK   (HISTOGRAM_ADDR_MASK),
        .NUM_CYCLES  (6),
        .ADDR_WIDTH  (2),
        .DATA_WIDTH  (32),
        .ADDR1       (0),
        .ADDR_MASK1  (0),
        .ADDR2       (0),
        .ADDR_MASK2  (0)
    ) cmd_deser_sens_histogram_i (
        .rst         (1'b0), // input
        .clk         (mclk), // input
        .srst        (mrst), // input
        .ad          (cmd_ad), // input[7:0] 
        .stb         (cmd_stb), // input
        .addr        (pio_addr), // output[15:0] 
        .data        (pio_data), // output[31:0] 
        .we          (pio_stb) // output
    );
    
    pulse_cross_clock pulse_cross_clock_lt_i (
        .rst         (mrst), // input
        .src_clk     (mclk), // input
        .dst_clk     (pclk), // input
        .in_pulse    (set_left_top_w), // input
        .out_pulse   (set_left_top_pclk),    // output
        .busy() // output
    );
    
    pulse_cross_clock pulse_cross_clock_wh_i (
        .rst         (mrst), // input
        .src_clk     (mclk), // input
        .dst_clk     (pclk), // input
        .in_pulse    (set_width_height_w), // input
        .out_pulse   (set_width_height_pclk),    // output
        .busy() // output
    );
    
    pulse_cross_clock pulse_cross_clock_hist_done_i (
        .rst         (prst), // input
        .src_clk     (pclk), // input
        .dst_clk     (mclk), // input
        .in_pulse    (hist_done), // input
        .out_pulse   (hist_done_mclk),    // output
        .busy() // output
    );

    pulse_cross_clock pulse_cross_clock_hist_xfer_done_i (
        .rst         (mrst), // input
        .src_clk     (mclk), // input
        .dst_clk     (pclk), // input
        .in_pulse    (hist_xfer_done_mclk), // input
        .out_pulse   (hist_xfer_done),    // output
        .busy() // output
    );
    
    clk_to_clk2x clk_to_clk2x_i (
        .clk         (pclk), // input
        .clk2x       (pclk2x), // input
        .clk_sync    (pclk_sync) // output
    );
    
    //TODO:  make it double cycle in timing

    // select between 18-bit wide histogram data using a single BRAM or 2 BRAMs having full 32 bits    
    generate
        if (HISTOGRAM_RAM_MODE=="BUF18")
            sens_hist_ram_double sens_hist_ram_i (
                .pclk2x     (pclk2x), // input
                .addr_a     ({hist_bank_pclk,hist_rwaddr[9:0]}), // input[10:0] 
                .data_in_a  (inc_r),         // input[31:0] 
                .data_out_a (hist_new),      // output[31:0] 
                .en_a       (hist_rwen),     // input
                .regen_a    (hist_regen[1]), // input
                .we_a       (hist_we),       // input
                .mclk       (mclk),          // input
                .addr_b     ({hist_bank_mclk,hist_raddr[9:0]}), // input[10:0] 
                .data_out_b (hist_do),       // output[31:0] 
                .re_b       (hist_re[0]),    // input
                .regen_b    (hist_re[1])     // input
            );
        else if (HISTOGRAM_RAM_MODE=="BUF32")
            sens_hist_ram_single sens_hist_ram_i (
                .pclk2x     (pclk2x), // input
                .addr_a     ({hist_bank_pclk,hist_rwaddr[9:0]}), // input[10:0] 
                .data_in_a  (inc_r),      // input[31:0] 
                .data_out_a (hist_new),   // output[31:0] 
                .en_a       (hist_rwen),  // input
                .regen_a    (hist_regen[1]), // input
                .we_a       (hist_we),    // input
                .mclk       (mclk),       // input
                .addr_b     ({hist_bank_mclk,hist_raddr[9:0]}), // input[10:0] 
                .data_out_b (hist_do), // output[31:0] 
                .re_b       (hist_re[0]),    // input
                .regen_b    (hist_re[1])     // input
            );
        else if (HISTOGRAM_RAM_MODE=="NOBUF")
            sens_hist_ram_nobuff sens_hist_ram_i (
                .pclk2x     (pclk2x), // input
                .addr_a     ({hist_bank_pclk,hist_rwaddr[9:0]}), // input[10:0] 
                .data_in_a  (inc_r),      // input[31:0] 
                .data_out_a (hist_new),   // output[31:0] 
                .en_a       (hist_rwen),  // input
                .regen_a    (hist_regen[1]), // input
                .we_a       (hist_we),    // input
                .mclk       (mclk),       // input
                .addr_b     ({hist_bank_mclk,hist_raddr[9:0]}), // input[10:0] 
                .data_out_b (hist_do), // output[31:0] 
                .re_b       (hist_re[0]),    // input
                .regen_b    (hist_re[1])     // input
            );
        
    endgenerate


endmodule

module sens_hist_ram_single(
    input         pclk2x,
    input  [10:0] addr_a,
    input  [31:0] data_in_a,
    output [31:0] data_out_a,
    input         en_a,
    input         regen_a,
    input         we_a,
    
    input         mclk,
    input  [10:0] addr_b,
    output [31:0] data_out_b,
    input         re_b,
    input         regen_b
);
    wire   [17:0] data_out_a18;
    wire   [17:0] data_out_b18;
    assign data_out_b = {14'b0,data_out_b18};
    assign data_out_a = {14'b0,data_out_a18};
    ramtp_var_w_var_r #(
        .REGISTERS_A(1),
        .REGISTERS_B(1),
        .LOG2WIDTH_A(4),               // 18 bits
        .LOG2WIDTH_B(4),                // 18 bits
        .WRITE_MODE_A("NO_CHANGE"),
        .WRITE_MODE_B("READ_FIRST")
    ) ramtp_var_w_var_r_i (
        .clk_a      (pclk2x),          // input
        .addr_a     (addr_a),          // input[10:0] 
        .en_a       (en_a),            // input
        .regen_a    (regen_a),         // input
        .we_a       (we_a),            // input
        .data_out_a (data_out_a18),    // output[17:0] 
        .data_in_a  (data_in_a[17:0]), // input[17:0] 
        .clk_b      (mclk),            // input
        .addr_b     (addr_b),          // input[10:0] 
        .en_b       (re_b),            // input
        .regen_b    (regen_b),         // input
        .we_b       (1'b1),            // input
        .data_out_b (data_out_b18),    // output[17:0] 
        .data_in_b  (18'b0)            // input[17:0] 
    );
endmodule
// TODO: without ping-pong buffering as histograms are transferred to the system memory over axi master,
// it may be possible to use a single RAM block (if vertical blanking outside of selected window is sufficient)

module sens_hist_ram_double(
    input         pclk2x,
    input  [10:0] addr_a,
    input  [31:0] data_in_a,
    output [31:0] data_out_a,
    input         en_a,
    input         regen_a,
    input         we_a,
    
    input         mclk,
    input  [10:0] addr_b,
    output [31:0] data_out_b,
    input         re_b,
    input         regen_b
);
    
    ramt_var_w_var_r #(
        .REGISTERS_A(1),
        .REGISTERS_B(1),
        .LOG2WIDTH_A(4),
        .LOG2WIDTH_B(4),
        .WRITE_MODE_A("NO_CHANGE"),
        .WRITE_MODE_B("READ_FIRST")
    ) ramt_var_w_var_r_lo_i (
        .clk_a      (pclk2x),           // input
        .addr_a     (addr_a),           // input[10:0] 
        .en_a       (en_a),             // input
        .regen_a    (regen_a),          // input
        .we_a       (we_a),             // input
        .data_out_a (data_out_a[15:0]), // output[15:0] 
        .data_in_a  (data_in_a[15:0]),  // input[15:0] 
        .clk_b      (mclk),             // input
        .addr_b     (addr_b),           // input[10:0] 
        .en_b       (re_b),             // input
        .regen_b    (regen_b),          // input
        .we_b       (1'b1),             // input
        .data_out_b (data_out_b[15:0]), // output[15:0] 
        .data_in_b  (16'b0)             // input[15:0] 
    );
    
    ramt_var_w_var_r #(
        .REGISTERS_A(1),
        .REGISTERS_B(1),
        .LOG2WIDTH_A(4),
        .LOG2WIDTH_B(4),
        .WRITE_MODE_A("NO_CHANGE"),
        .WRITE_MODE_B("READ_FIRST")
    ) ramt_var_w_var_r_hi_i (
        .clk_a      (pclk2x),           // input
        .addr_a     (addr_a),           // input[10:0] 
        .en_a       (en_a),             // input
        .regen_a    (regen_a),          // input
        .we_a       (we_a),             // input
        .data_out_a (data_out_a[31:16]),// output[15:0] 
        .data_in_a  (data_in_a[31:16]), // input[15:0] 
        .clk_b      (mclk),             // input
        .addr_b     (addr_b),           // input[10:0] 
        .en_b       (re_b),             // input
        .regen_b    (regen_b),          // input
        .we_b       (1'b1),             // input
        .data_out_b (data_out_b[31:16]),// output[15:0] 
        .data_in_b  (16'b0)             // input[15:0] 
    );
endmodule

module sens_hist_ram_nobuff(
    input         pclk2x,
    input  [10:0] addr_a,
    input  [31:0] data_in_a,
    output [31:0] data_out_a,
    input         en_a,
    input         regen_a,
    input         we_a,
    
    input         mclk,
    input  [10:0] addr_b,
    output [31:0] data_out_b,
    input         re_b,
    input         regen_b
);
    
    ramt_var_w_var_r #(
        .REGISTERS_A(1),
        .REGISTERS_B(1),
        .LOG2WIDTH_A(5), // 32 bits
        .LOG2WIDTH_B(5),
        .WRITE_MODE_A("NO_CHANGE"),
        .WRITE_MODE_B("READ_FIRST")
    ) ramt_var_w_var_r_i (
        .clk_a      (pclk2x),           // input
        .addr_a     (addr_a[9:0]),      // input[10:0] 
        .en_a       (en_a),             // input
        .regen_a    (regen_a),          // input
        .we_a       (we_a),             // input
        .data_out_a (data_out_a[31:0]), // output[15:0] 
        .data_in_a  (data_in_a[31:0]),  // input[15:0] 
        .clk_b      (mclk),             // input
        .addr_b     (addr_b[9:0]),      // input[10:0] 
        .en_b       (re_b),             // input
        .regen_b    (regen_b),          // input
        .we_b       (1'b1),             // input
        .data_out_b (data_out_b[31:0]), // output[15:0] 
        .data_in_b  (32'b0)             // input[15:0] 
    );
    
endmodule

module  sens_histogram_dummy(
    output        hist_rq,
    output [31:0] hist_do,
    output        hist_dv

);
    assign         hist_rq = 0;
    assign         hist_do = 0;
    assign         hist_dv = 0;
endmodule