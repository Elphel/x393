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
    output reg [15:0] q_latch);        // output data

    reg     [9:0] wa;
    reg     [9:0] sync_wa;    // delayed wa, re_latch-calculated at output clock
    reg     [9:0] ra_r;
    reg     [9:0] ra_latch;
    reg           load_q;
    wire   [15:0] fifo_o;
    reg           ds1;    // ds delayed by one xclk to give time to block ram to write data. Not needed likely.
    reg           synci;
    reg     [1:0] synco;
    reg           sync_we; // single xclk2x period pulse for each ds@xclk
    reg           en2x; // en sync to xclk2x;

    reg           re_r;
    reg           re_latch;
    reg           fifo_dav; // RAM output reg has data
    reg           dav_and_fifo_dav;
    wire          ram_dav;  // RAM has data inside
    reg     [9:0] diff_a;
    wire          next_re;


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
/*  
  LD i_re  (.Q(re_latch),.G(xclk2x),.D(next_re));  

  LD i_ra9 (.Q(ra_latch[9]),.G(xclk2x),.D(ra_r[9]));  
  LD i_ra8 (.Q(ra_latch[8]),.G(xclk2x),.D(ra_r[8]));  
  LD i_ra7 (.Q(ra_latch[7]),.G(xclk2x),.D(ra_r[7]));  
  LD i_ra6 (.Q(ra_latch[6]),.G(xclk2x),.D(ra_r[6]));  
  LD i_ra5 (.Q(ra_latch[5]),.G(xclk2x),.D(ra_r[5]));  
  LD i_ra4 (.Q(ra_latch[4]),.G(xclk2x),.D(ra_r[4]));  
  LD i_ra3 (.Q(ra_latch[3]),.G(xclk2x),.D(ra_r[3]));  
  LD i_ra2 (.Q(ra_latch[2]),.G(xclk2x),.D(ra_r[2]));  
  LD i_ra1 (.Q(ra_latch[1]),.G(xclk2x),.D(ra_r[1]));  
  LD i_ra0 (.Q(ra_latch[0]),.G(xclk2x),.D(ra_r[0]));  
*/  
    always @* if (xclk2x) re_latch <= next_re;
    always @* if (xclk2x) ra_latch <= ra_r;
  
  
    always @ (posedge xclk2x) begin
        load_q <= dav?want_read_early:re_r;
    end
/*  
  LD_1 i_q15 (.Q( q_latch[15]),.G(xclk2x),.D(load_q?fifo_o[15]:q_latch[15]));  
  LD_1 i_q14 (.Q( q_latch[14]),.G(xclk2x),.D(load_q?fifo_o[14]:q_latch[14]));  
  LD_1 i_q13 (.Q( q_latch[13]),.G(xclk2x),.D(load_q?fifo_o[13]:q_latch[13]));  
  LD_1 i_q12 (.Q( q_latch[12]),.G(xclk2x),.D(load_q?fifo_o[12]:q_latch[12]));  
  LD_1 i_q11 (.Q( q_latch[11]),.G(xclk2x),.D(load_q?fifo_o[11]:q_latch[11]));  
  LD_1 i_q10 (.Q( q_latch[10]),.G(xclk2x),.D(load_q?fifo_o[10]:q_latch[10]));  
  LD_1 i_q9  (.Q( q_latch[ 9]),.G(xclk2x),.D(load_q?fifo_o[ 9]:q_latch[ 9]));  
  LD_1 i_q8  (.Q( q_latch[ 8]),.G(xclk2x),.D(load_q?fifo_o[ 8]:q_latch[ 8]));  
  LD_1 i_q7  (.Q( q_latch[ 7]),.G(xclk2x),.D(load_q?fifo_o[ 7]:q_latch[ 7]));  
  LD_1 i_q6  (.Q( q_latch[ 6]),.G(xclk2x),.D(load_q?fifo_o[ 6]:q_latch[ 6]));  
  LD_1 i_q5  (.Q( q_latch[ 5]),.G(xclk2x),.D(load_q?fifo_o[ 5]:q_latch[ 5]));  
  LD_1 i_q4  (.Q( q_latch[ 4]),.G(xclk2x),.D(load_q?fifo_o[ 4]:q_latch[ 4]));  
  LD_1 i_q3  (.Q( q_latch[ 3]),.G(xclk2x),.D(load_q?fifo_o[ 3]:q_latch[ 3]));  
  LD_1 i_q2  (.Q( q_latch[ 2]),.G(xclk2x),.D(load_q?fifo_o[ 2]:q_latch[ 2]));  
  LD_1 i_q1  (.Q( q_latch[ 1]),.G(xclk2x),.D(load_q?fifo_o[ 1]:q_latch[ 1]));  
  LD_1 i_q0  (.Q( q_latch[ 0]),.G(xclk2x),.D(load_q?fifo_o[ 0]:q_latch[ 0]));  
*/
    always @* if (~xclk2x) begin
        if (load_q) q_latch <= fifo_o;
    end
/*
   RAMB16_S18_S18 i_fifo (
                          .DOA(),            // Port A 16-bit Data Output
                          .DOPA(),           // Port A 2-bit Parity Output
                          .ADDRA(wa[9:0]),   // Port A 10-bit Address Input
                          .CLKA(xclk),       // Port A Clock
                          .DIA(di[15:0]),    // Port A 16-bit Data Input
                          .DIPA(2'b0),       // Port A 2-bit parity Input
                          .ENA(ds),          // Port A RAM Enable Input
                          .SSRA(1'b0),       // Port A Synchronous Set/Reset Input
                          .WEA(1'b1),        // Port A Write Enable Input

                          .DOB(fifo_o[15:0]),// Port B 16-bit Data Output
                          .DOPB(),           // Port B 2-bit Parity Output
                          .ADDRB(ra_latch[9:0]),   // Port B 10-bit Address Input
                          .CLKB(xclk2x),        // Port B Clock
                          .DIB(16'b0),       // Port B 16-bit Data Input
                          .DIPB(2'b0),       // Port-B 2-bit parity Input
                          .ENB(re_latch),          // PortB RAM Enable Input
                          .SSRB(1'b0),       // Port B Synchronous Set/Reset Input
                          .WEB(1'b0)         // Port B Write Enable Input
                          );
*/

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
