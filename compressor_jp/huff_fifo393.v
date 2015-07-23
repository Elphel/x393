/*
** -----------------------------------------------------------------------------**
** huff_fifo393.v
**
** Part of Huffman encoder for JPEG compressor - FIFO for Huffman encoder
**
** Copyright (C) 2002-2015 Elphel, Inc
**
** -----------------------------------------------------------------------------**
**  huff_fifo393.v is free software - hardware description language (HDL) code.
** 
**  This program is free software: you can redistribute it and/or modify
**  it under the terms of the GNU General Public License as published by
**  the Free Software Foundation, either version 3 of the License, or
**  (at your option) any later version.
**
**  This program is distributed in the hope that it will be useful,
**  but WITHOUT ANY WARRANTY; without even the implied warranty of
**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
**  GNU General Public License for more details.
**
**  You should have received a copy of the GNU General Public License
**  along with this program.  If not, see <http://www.gnu.org/licenses/>.
** -----------------------------------------------------------------------------**
**
*/
//used the other edge of the clk2x
module huff_fifo393 (
    input             xclk,            // pixel clock, posedge
    input             xclk2x,          // twice frequency - uses negedge inside
    input             en,              // will reset if ==0 (sync to xclk)
    input      [15:0] di,              // data in (sync to xclk)
    input             ds,              // din valid (sync to xclk)
    input             want_read,
    input             want_read_early, 
    output reg        dav,             // FIFO output latch has data (fifo_or_full)
`ifdef INFER_LATCHES
    output reg [15:0] q_latch
`else
    output     [15:0] q_latch
`endif    
    );        // output data

    reg     [9:0] wa;
    reg     [9:0] sync_wa;    // delayed wa, re_latch-calculated at output clock
    reg     [9:0] ra_r;
    wire   [15:0] fifo_o;
    reg           ds1;    // ds delayed by one xclk to give time to block ram to write data. Not needed likely.
    reg           synci;
    reg     [1:0] synco;
    reg           sync_we; // single xclk2x period pulse for each ds@xclk
    reg           en2x; // en sync to xclk2x;

    reg           re_r;
    reg           fifo_dav; // RAM output reg has data
    reg           dav_and_fifo_dav;
    wire          ram_dav;  // RAM has data inside
    reg     [9:0] diff_a;
    wire          next_re;
    reg           load_q;
`ifdef INFER_LATCHES
    reg     [9:0] ra_latch;
    reg           re_latch;
`else
    wire    [9:0] ra_latch;
    wire          re_latch;
`endif    
    


    always @ (posedge xclk) begin // input stage, no overrun detection
        if (!en)       wa[9:0] <= 10'b0;
        else if (ds)  wa[9:0] <= wa[9:0]+1;
        ds1                    <= ds && en;
        if (!en)      synci   <= 1'b0;
        else if (ds1) synci   <= ~synci;
    end
    always @ (negedge xclk2x) begin
        en2x <= en;
        synco[1:0]   <= {synco[0],synci};
        sync_we      <= en2x && (synco[0] != synco[1]);
    end

    assign ram_dav= sync_we || (diff_a[9:0] != 10'b0);
    assign next_re= ram_dav && (!dav_and_fifo_dav || want_read);
  
    always @ (negedge xclk2x) begin
        dav              <= en2x && (fifo_dav || (dav && !want_read));
        fifo_dav         <= en2x && (ram_dav ||(dav && fifo_dav && !want_read));
        dav_and_fifo_dav <= en2x && (fifo_dav || (dav && !want_read)) && (ram_dav ||(dav && fifo_dav && !want_read)); // will optimize auto
        re_r    <= en2x &&  next_re;
        
        if (!en2x)                   sync_wa[9:0] <= 10'b0;
        else if (sync_we)            sync_wa[9:0] <= sync_wa[9:0]+1;
        
        if        (!en2x)             ra_r  [9:0] <= 10'b0;
        else if (next_re)             ra_r  [9:0] <= ra_r[9:0]+1;
        
        if (!en2x)                    diff_a[9:0] <= 10'b0;
        else if (sync_we && !next_re) diff_a[9:0] <= diff_a[9:0]+1;
        else if (!sync_we && next_re) diff_a[9:0] <= diff_a[9:0]-1; 
        
    end

    always @ (posedge xclk2x) begin
        load_q <= dav?want_read_early:re_r;
    end

`ifdef INFER_LATCHES
    always @* if (xclk2x) re_latch <= next_re;
    always @* if (xclk2x) ra_latch <= ra_r;
    always @* if (~xclk2x) 
        if (load_q) q_latch <= fifo_o;
    end
    
`else 
    latch_g_ce #(
        .WIDTH           (1),
        .INIT            (0),
        .IS_CLR_INVERTED (0),
        .IS_G_INVERTED   (0)
    ) latch_re_i (
        .rst     (1'b0),      // input
        .g       (xclk2x),    // input
        .ce      (1'b1),      // input
        .d_in    (next_re),   // input[0:0] 
        .q_out   (re_latch)   // output[0:0] 
    );

    latch_g_ce #(
        .WIDTH           (10),
        .INIT            (0),
        .IS_CLR_INVERTED (0),
        .IS_G_INVERTED   (0)
    ) latch_ra_i (
        .rst     (1'b0),      // input
        .g       (xclk2x),    // input
        .ce      (1'b1),      // input
        .d_in    (ra_r),      // input[0:0] 
        .q_out   (ra_latch)   // output[0:0] 
    );
   
    latch_g_ce #(
        .WIDTH           (16),
        .INIT            (0),
        .IS_CLR_INVERTED (0),
        .IS_G_INVERTED   (1'b1) // inverted!
    ) latch_q_i (
        .rst     (1'b0),      // input
        .g       (xclk2x),    // input
        .ce      (load_q),      // input
        .d_in    (fifo_o),      // input[0:0] 
        .q_out   (q_latch)   // output[0:0] 
    );
`endif    

    ram18_var_w_var_r #(
        .REGISTERS    (0),
        .LOG2WIDTH_WR (4),
        .LOG2WIDTH_RD (4),
        .DUMMY        (0)
    ) i_fifo (
        .rclk         (xclk2x),        // input
        .raddr        (ra_latch[9:0]), // input[9:0] 
        .ren          (re_latch),      // input
        .regen        (1'b1),          // input
        .data_out     (fifo_o[15:0]),  // output[15:0] 
        .wclk         (xclk),          // input
        .waddr        (wa[9:0]),       // input[9:0] 
        .we           (ds),            // input
        .web          (4'hf),          // input[3:0] 
        .data_in      (di[15:0])       // input[15:0] 
    );
 
endmodule
