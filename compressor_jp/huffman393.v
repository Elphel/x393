/*
** -----------------------------------------------------------------------------**
** huffman333.v
**
** Huffman encoder for JPEG compressorrdy
**
** Copyright (C) 2002-20015 Elphelk, Inc
**
** -----------------------------------------------------------------------------**
**  huffman393 is free software - hardware description language (HDL) code.
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
// 01/22/2004 - extended flush until ready (modified stuffer.v too)
module huffman393    (
    input             xclk,            // pixel clock, sync to incoming data
    input             xclk2x,          // twice frequency - uses negedge inside
    input             en,              // will reset if ==0 (sync to xclk)
    input             sclk,            // clock to write tables (NOW posgedge) AF2015
    input             twe,             // enable write to a table - now the following will be valid ant negedge sclk
    input       [8:0] ta,              // [8:0]  table address
    input      [15:0] tdi,             // [15:0] table data in
    input      [15:0] di,              // [15:0]    specially RLL prepared 16-bit data (to FIFO) (sync to xclk)
    input             ds,              // di valid strobe  (sync to xclk)
    input             rdy,             // receiver (bit stuffer) is ready to accept data
    output reg [15:0] do,              // [15:0]    output data
    output reg [ 3:0] dl,              // [3:0] data length (4'h0 is 'h16)
    output reg        dv,              // output data valid
    output reg        flush,           // last block done - flush the rest bits
    output reg        last_block,
    output reg        test_lbw,
    output            gotLastBlock);   // last block done - flush the rest bits
/*
  huffman i_huffman  (.pclk(clk),      // pixel clock
                      .clk(clk2x),     // twice frequency - uses negedge inside
                      .en(cmprs_en),      // enable (0 resets counter) sync to .pclk(clk)
                      .twe(twhe),      // enable write to a table
                      .ta(ta[8:0]),      // [8:0]  table address
                      .tdi(di[15:0]),      // [23:0] table data in (8 LSBs - quantization data, [13:9] zigzag address
                      .di(enc_do[15:0]),      // [15:0]   specially RLL prepared 16-bit data (to FIFO)
                      .ds(enc_dv),      // di valid strobe
                      .rdy(stuffer_rdy),      // receiver (bit stuffer) is ready to accept data
                      .do(huff_do),      // [15:0]   output data
                      .dl(huff_dl),      // [3:0]   output width (0==16)
                      .dv(huff_dv),      // output data bvalid
                     .flush(flush),
                     .last_block(last_block),
                     .test_lbw(),
                     .gotLastBlock(test_lbw));   // last block done - flush the rest bits

                     
*/

    wire   [31:0] tables_out; // Only [19:0] are used
    reg    [15:0] hcode_latch;    // table output huffman code (1..16 bits)
    reg    [ 3:0] hlen_latch;        // table - code length only 4 LSBs are used
    reg    [ 7:0] haddr_r;    // index in huffman table    
    wire   [ 7:0] haddr_next;

    reg    [ 7:0] haddr70_latch;
    reg           haddr8_latch;
    wire   [ 8:0] haddr = {haddr8_latch,haddr70_latch};    // index in huffman table     (after latches)
     
    wire   [15:0] fifo_o;
    reg           stuffer_was_rdy;
    reg           tables_re_latch;
    wire          read_next;    // assigned depending on steps (each other cycle for normal codes, each for special 00/F0

    reg     [5:0] steps;
// first stage registers 
    reg     [5:0] rll;    // 2 MSBs - counter to send "f0" codes

// replacing SRL16 with FD as SRL has longer output delay from clock 
    reg     [3:0] rll1;
    reg     [3:0] rll2;
    reg           typeDC;
    reg           typeAC;
    reg    [11:0] sval;    // signed input value

    wire    [1:0] code_typ0;    // valid at steps[0]
    reg           tbsel_YC0;    // valid at steps[0] - 0 -Y table, 1 - CbCr
    reg     [1:0] code_typ1;
    reg     [1:0] code_typ2;
    reg           code_typ3;
    reg           code_typ4;
    reg           tbsel_YC1;
    reg           tbsel_YC2;
    reg           tbsel_YC3;

    reg    [15:0] out_bits;    // bits to send
    reg     [3:0] out_len;        // length of bits to send (4'h0 means 16)
    wire          fifo_or_full;    // fifo output register full read_next
    wire          will_read;
    wire   [10:0] var_do;
    wire    [3:0] var_dl;
    wire    [3:0] var_dl_late;

    reg           dv0;

    reg           eob;
    wire          gotDC;
    wire          gotAC;
    wire          gotRLL;
    wire          gotEOB;
    wire          gotLastWord;
    wire          gotColor;

    wire          want_read; // as will_read, but w/o fifo status
    reg           ready_to_flush;    // read the last data from fifo
    reg           en2x; // en sync to xclk2x;


    wire          pre_dv;
    wire   [15:0] pre_bits;
    wire   [ 3:0] pre_len;

    reg           twe_d; // table write enable (twe) delayed by 1 clock

    always @ (negedge xclk2x) en2x <= en;
    
    assign gotDC=         fifo_o[15] &&  fifo_o[14];
    assign gotAC=         fifo_o[15] && !fifo_o[14];
    assign gotRLL=        !fifo_o[15] && !fifo_o[12];
    assign gotEOB=        !fifo_o[15] &&  fifo_o[12];
    assign gotLastBlock=  fifo_o[15] &&  fifo_o[14] && fifo_o[12];
    assign gotLastWord=  !fifo_o[14] &&  fifo_o[12];    // (AC or RLL) and last bit set
    assign gotColor= fifo_o[13];

    always @(negedge xclk2x) stuffer_was_rdy <= !en2x || rdy; // stuffer ready shoud be on if !en (move to register?)for now]
    reg           stuffer_was_rdy_early_latch;
    wire          want_read_early;
/*    
  LD  i_stuffer_was_rdy_early (.Q(stuffer_was_rdy_early_latch),.G(xclk2x),.D(!en2x || rdy));
  LD  i_tables_re (.Q(tables_re_latch),.G(xclk2x),.D(en2x && rdy));
*/  
    always @* if (xclk2x) stuffer_was_rdy_early_latch <= !en2x || rdy;
    always @* if (xclk2x) tables_re_latch <= en2x && rdy;
   


    assign read_next= en2x && ((!steps[0] && !rll[5]) || eob ) && fifo_or_full; // fifo will never have data after the last block...
    assign will_read= stuffer_was_rdy && fifo_or_full && en2x && ((!steps[0] && !rll[5]) || eob ); // fifo will never have data after the last block...
    assign want_read= stuffer_was_rdy && ((!steps[0] && !rll[5]) || eob ); // for FIFO
    assign want_read_early= stuffer_was_rdy_early_latch && ((!steps[0] && !rll[5]) || eob ); // for FIFO

    always @ (negedge xclk2x) if (stuffer_was_rdy) begin
        eob <= read_next && gotEOB;// will be 1 only during step[0]

        if (!en2x) steps[5:0]    <= 'b0;
        else     steps[5:0]    <= {steps[4] && code_typ4, // will be skipped for codes 00/F0
                                   steps[3:0],
                                   (read_next && !(gotRLL && (fifo_o[5:4]==2'b00))) || rll[5] }; // will not start if it was <16, waiting for AC
    end
    always @ (negedge xclk2x)    begin
        last_block <= en2x && (last_block?(!flush):(stuffer_was_rdy && will_read && gotLastBlock));
        ready_to_flush <= en2x && (ready_to_flush?(!flush):(stuffer_was_rdy && last_block &&  will_read && gotLastWord));
        test_lbw <= en2x && last_block &&  gotLastWord;
// did not work if flush was just after not ready?
        flush    <= en2x &&( flush?(!rdy):(rdy && stuffer_was_rdy && ready_to_flush && !(|steps)) );
    end


    always @ (negedge xclk2x) if (will_read) begin
        typeDC               <= gotDC;
        typeAC               <= gotAC;
        sval[11:0]           <= fifo_o[11:0];
        if (gotDC) tbsel_YC0 <= gotColor;
    end
  

    always @ (negedge xclk2x) if (stuffer_was_rdy) begin
        if (!en2x || (read_next && gotAC) || (steps[0] && typeAC))             rll[5:4] <= 2'b0;
        else if (read_next && gotRLL)                                          rll[5:4] <= fifo_o[5:4];
        else if (rll[5:4]!=2'b00)                                              rll[5:4] <= rll[5:4]-1;
        
        if (!en2x || (read_next && !gotAC && !gotRLL) || (steps[0] && typeAC)) rll[3:0] <= 4'b0;
        else if (read_next && gotRLL)                                          rll[3:0] <= fifo_o[3:0];
    end

    assign code_typ0={typeDC || (!eob && (rll[5:4]==2'b0)),
                      typeDC || (!eob && (rll[5:4]!=2'b0))};

    assign haddr_next[7:0] = code_typ2[1]?
                                        (code_typ2[0]?{var_dl[3:0],4'hf}:       // DC (reusing the spare cells of the AC table)
                                                      {rll2[3:0],var_dl[3:0]}): // AC normal code
                                        (code_typ2[0]?8'hf0:                    //skip 16 zeros code
                                                      8'h00);                   //skip to end of block code

    always @ (negedge xclk2x) if (stuffer_was_rdy && steps[2]) begin    // may be just if (stuffer_was_rdy)
        haddr_r[7:0]    <= haddr_next[7:0];
    end
/*  
  LD  i_haddr_8 (.Q(haddr[8]),.G(xclk2x),.D(stuffer_was_rdy?tbsel_YC2:tbsel_YC3));
  LD  i_haddr_7 (.Q(haddr[7]),.G(xclk2x),.D((stuffer_was_rdy && steps[2])?haddr_next[7]:haddr_r[7]));
  LD  i_haddr_6 (.Q(haddr[6]),.G(xclk2x),.D((stuffer_was_rdy && steps[2])?haddr_next[6]:haddr_r[6]));
  LD  i_haddr_5 (.Q(haddr[5]),.G(xclk2x),.D((stuffer_was_rdy && steps[2])?haddr_next[5]:haddr_r[5]));
  LD  i_haddr_4 (.Q(haddr[4]),.G(xclk2x),.D((stuffer_was_rdy && steps[2])?haddr_next[4]:haddr_r[4]));
  LD  i_haddr_3 (.Q(haddr[3]),.G(xclk2x),.D((stuffer_was_rdy && steps[2])?haddr_next[3]:haddr_r[3]));
  LD  i_haddr_2 (.Q(haddr[2]),.G(xclk2x),.D((stuffer_was_rdy && steps[2])?haddr_next[2]:haddr_r[2]));
  LD  i_haddr_1 (.Q(haddr[1]),.G(xclk2x),.D((stuffer_was_rdy && steps[2])?haddr_next[1]:haddr_r[1]));
  LD  i_haddr_0 (.Q(haddr[0]),.G(xclk2x),.D((stuffer_was_rdy && steps[2])?haddr_next[0]:haddr_r[0]));
*/
//     wire   [ 8:0] haddr = {haddr8_latch,haddr70_latch};    // index in huffman table     (after latches)
    always @* if (xclk2x) begin
        if (stuffer_was_rdy) haddr8_latch <= tbsel_YC2;
        else                 haddr8_latch <= tbsel_YC3;
    end

    always @* if (xclk2x) begin
        if (stuffer_was_rdy && steps[2]) haddr70_latch <= haddr_next;
        else                             haddr70_latch <= haddr_r;
    end


    assign pre_dv =         steps[4] || (steps[5] && (var_dl_late[3:0]!=4'b0));
    assign pre_bits[15:0]    = steps[5]?{5'b0,var_do[10:0]}:     hcode_latch[15:0];
    assign pre_len [ 3:0]    = steps[5]?      var_dl_late[ 3:0]: hlen_latch  [3:0];

    always @ (negedge xclk2x) if (stuffer_was_rdy) begin
        dv0            <= pre_dv;
        out_bits[15:0] <= pre_bits[15:0];
        out_len [ 3:0] <= pre_len [ 3:0];
    end
    
    always @ (negedge xclk2x) if (!en2x || rdy) begin
        dv       <= stuffer_was_rdy? pre_dv:dv0;
        do[15:0] <= stuffer_was_rdy? pre_bits[15:0]:out_bits[15:0];
        dl[ 3:0] <= stuffer_was_rdy? pre_len [ 3:0]:out_len [ 3:0];
    end



// "Extract shift registers" in synthesis should be off! FD has lower output delay than SRL16
    always @ (negedge xclk2x) if (stuffer_was_rdy) begin
        code_typ1[1:0] <= code_typ0[1:0];
        code_typ2[1:0] <= code_typ1[1:0];
        code_typ3      <= code_typ2[1];
        code_typ4      <= code_typ3;
        rll1[3:0]      <= rll[3:0];
        rll2[3:0]      <= rll1[3:0];
        tbsel_YC1      <= tbsel_YC0;
        tbsel_YC2      <= tbsel_YC1;
        tbsel_YC3      <= tbsel_YC2;
    end
  /*
  LD_1 i_hlen3  (.Q( hlen_latch[ 3]),.G(xclk2x),.D(tables_out[19]));  
  LD_1 i_hlen2  (.Q( hlen_latch[ 2]),.G(xclk2x),.D(tables_out[18]));  
  LD_1 i_hlen1  (.Q( hlen_latch[ 1]),.G(xclk2x),.D(tables_out[17]));  
  LD_1 i_hlen0  (.Q( hlen_latch[ 0]),.G(xclk2x),.D(tables_out[16]));  
  LD_1 i_hcode15(.Q(hcode_latch[15]),.G(xclk2x),.D(tables_out[15]));  
  LD_1 i_hcode14(.Q(hcode_latch[14]),.G(xclk2x),.D(tables_out[14]));  
  LD_1 i_hcode13(.Q(hcode_latch[13]),.G(xclk2x),.D(tables_out[13]));  
  LD_1 i_hcode12(.Q(hcode_latch[12]),.G(xclk2x),.D(tables_out[12]));  
  LD_1 i_hcode11(.Q(hcode_latch[11]),.G(xclk2x),.D(tables_out[11]));  
  LD_1 i_hcode10(.Q(hcode_latch[10]),.G(xclk2x),.D(tables_out[10]));  
  LD_1 i_hcode9 (.Q(hcode_latch[ 9]),.G(xclk2x),.D(tables_out[ 9]));  
  LD_1 i_hcode8 (.Q(hcode_latch[ 8]),.G(xclk2x),.D(tables_out[ 8]));  
  LD_1 i_hcode7 (.Q(hcode_latch[ 7]),.G(xclk2x),.D(tables_out[ 7]));  
  LD_1 i_hcode6 (.Q(hcode_latch[ 6]),.G(xclk2x),.D(tables_out[ 6]));  
  LD_1 i_hcode5 (.Q(hcode_latch[ 5]),.G(xclk2x),.D(tables_out[ 5]));  
  LD_1 i_hcode4 (.Q(hcode_latch[ 4]),.G(xclk2x),.D(tables_out[ 4]));  
  LD_1 i_hcode3 (.Q(hcode_latch[ 3]),.G(xclk2x),.D(tables_out[ 3]));  
  LD_1 i_hcode2 (.Q(hcode_latch[ 2]),.G(xclk2x),.D(tables_out[ 2]));  
  LD_1 i_hcode1 (.Q(hcode_latch[ 1]),.G(xclk2x),.D(tables_out[ 1]));  
  LD_1 i_hcode0 (.Q(hcode_latch[ 0]),.G(xclk2x),.D(tables_out[ 0]));  
*/  
    always @* if (~xclk2x) hlen_latch <=  tables_out[19:16];
    always @* if (~xclk2x) hcode_latch <= tables_out[15:0];
  

    huff_fifo393 i_huff_fifo (
        .xclk(xclk), // input
        .xclk2x(xclk2x), // input
        .en(en), // input
        .di(di[15:0]), // input[15:0] data in (sync to xclk)
        .ds(ds), // input din valid (sync to xclk)
        .want_read(want_read), // input
        .want_read_early(want_read_early), // input
        .dav(fifo_or_full), // output reg FIFO output register has data 
        .q_latch(fifo_o[15:0])); // output[15:0] reg data (will add extra buffering if needed)

    varlen_encode393 i_varlen_encode(
        .clk      (xclk2x),           // input
        .en       (stuffer_was_rdy),  // input  will enable registers. 0 - freeze
        .start    (steps[0]),         // input
        .d        (sval[11:0]),       // input[11:0] 12-bit signed
        .l        (var_dl[ 3:0]),     // output[3:0] reg code length
        .l_late   (var_dl_late[3:0]), // output[3:0] reg
        .q        (var_do[10:0]));    // output[10:0] reg code
                                        
                                        
//   always @ (negedge xclk2x) twe_d <= twe;
    always @ (posedge   sclk) twe_d <= twe;
/*   
   RAMB16_S18_S36 i_htab (
                          .DOA(),           // Port A 16-bit Data Output
                          .DOPA(),          // Port A 2-bit Parity Output
                          .ADDRA({ta[8:0],twe_d}),  // Port A 10-bit Address Input
                          .CLKA(!xclk2x),      // Port A Clock
                          .DIA(tdi[15:0]),  // Port A 16-bit Data Input
                          .DIPA(2'b0),      // Port A 2-bit parity Input
                          .ENA(1'b1),       // Port A RAM Enable Input
                          .SSRA(1'b0),      // Port A Synchronous Set/Reset Input
                          .WEA(twe | twe_d),// Port A Write Enable Input

                          .DOB({unused[11:0],tables_out[19:0]}),      // Port B 32-bit Data Output
                          .DOPB(),          // Port B 4-bit Parity Output
                          .ADDRB(haddr[8:0]),  // Port B 9-bit Address Input
                          .CLKB(xclk2x),       // Port B Clock
                          .DIB(32'b0),      // Port B 32-bit Data Input
                          .DIPB(4'b0),      // Port-B 4-bit parity Input
                          .ENB(tables_re_latch),  // PortB RAM Enable Input
                          .SSRB(1'b0),      // Port B Synchronous Set/Reset Input
                          .WEB(1'b0)        // Port B Write Enable Input
   );
*/

    ram18_var_w_var_r #(
        .REGISTERS(0),
        .LOG2WIDTH_WR(4),
        .LOG2WIDTH_RD(5),
        .DUMMY(0)
    ) i_htab (
        .rclk(xclk2x), // input
        .raddr(haddr[8:0]), // input[8:0] 
        .ren(tables_re_latch), // input
        .regen(1'b1), // input
//        .data_out({unused[11:0],tables_out[19:0]}), // output[31:0] 
        .data_out(tables_out), // output[31:0] 
        .wclk(sclk), // input
        .waddr({ta[8:0],twe_d}), // input[9:0] 
        .we(twe | twe_d), // input
        .web(4'hf), // input[3:0] 
        .data_in(tdi[15:0]) // input[15:0] 
    );
endmodule

