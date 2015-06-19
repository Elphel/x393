/*
** -----------------------------------------------------------------------------**
** varlen_encode393.v
**
** Part of the Huffman encoder for JPEG compressor - variable length encoder
**
** Copyright (C) 2002-2015 Elphel, Inc
**
** -----------------------------------------------------------------------------**
**  varlen_encode393.v is free software - hardware description language (HDL) code.
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

// Encoder will work 2 cycles/"normal" word, 1 cycle for codes "00" and "f0",
// only magnitude output is needed ASAP (2 cycles, the value out should be
// valid on the 5-th cycle - it will latency 4 cycles run each other cycle
// I'll make a shortcut - all codes processed in 2 cycles.

module    varlen_encode393 (
    input             clk,       // twice frequency - uses negedge inside
    input              en,       // will enable registers. 0 - freeze at once
    input              start, // (not faster than each other cycle)
    input       [11:0] d,        // 12-bit signed
    output reg   [3:0] l,        // [3:0] code length
    output reg   [3:0] l_late,// delayed l (sync to q)
    output reg  [10:0] q);    // [10:0]code
/*
    varlen_encode393 i_varlen_encode(.clk(clk),
                                        .en(stuffer_was_rdy), //will enable registers. 0 - freeze
                                        .start(steps[0]),
                                        .d(sval[11:0]),        // 12-bit signed
                                        .l(var_dl[ 3:0]),        // [3:0] code length
                                        .l_late(var_dl_late[3:0]),
                                        .q(var_do[10:0]));    // [10:0]code
*/                                
    reg    [11:0] d1;
    reg    [10:0] q0;
    reg     [2:0] cycles;

    wire          this0 =  |d1[ 3:0];
    wire          this1 =  |d1[ 7:4];
    wire          this2 =  |d1[10:8];
    wire    [1:0] codel0 = {|d1[ 3: 2],d1[ 3] || (d1[ 1] & ~d1[ 2])};
    wire    [1:0] codel1 = {|d1[ 7: 6],d1[ 7] || (d1[ 5] & ~d1[ 6])};
    wire    [1:0] codel2 = {|d1[   10],          (d1[ 9] & ~d1[10])};
    wire    [3:0] codel =  this2? {2'b10,codel2[1:0]} :
                     (this1? {2'b01, codel1[1:0]} :
                             (this0 ? {2'b00,codel0[1:0]} : 4'b1111));    // after +1 will be 0;

    always @ (negedge clk)  if (en) begin
        cycles[2:0]    <= {cycles[1:0],start};
    end

    always @ (negedge clk) if (en && start) begin
        d1[  11]    <=  d[11];
        d1[10:0]    <=  d[11]?-d[10:0]:d[10:0];
    end

    always @ (negedge clk) if (en & cycles[0]) begin
        q0[10:0]    <= d1[11]?~d1[10:0]:d1[10:0];
        l    <= codel[3:0]+1;    // needed only ASAP, valid only 2 cycles after start
    end
    
    always @ (negedge clk) if (en & cycles[2]) begin
        q[10:0]    <= q0[10:0];
        l_late[3:0]    <= l[3:0];
    end

endmodule
