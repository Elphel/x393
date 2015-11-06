/*
** -----------------------------------------------------------------------------**
** varlen_encode_snglclk.v
**
** Part of the Huffman encoder for JPEG compressor - variable length encoder
**
** Copyright (C) 2002-2015 Elphel, Inc
**
** -----------------------------------------------------------------------------**
**  varlen_encode_snglclk.v is free software - hardware description language (HDL) code.
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

module    varlen_encode_snglclk (
    input             clk,       // posedge
    input       [11:0] d,        // 12-bit 2-s complement
    output reg   [3:0] l,        // [3:0] code length, latency 2 clocks
    output reg  [10:0] q);       // [10:0] literal, latency = 2 clocks

    reg    [11:0] d1;

    wire          this0 =  |d1[ 3:0];
    wire          this1 =  |d1[ 7:4];
    wire          this2 =  |d1[10:8];
    wire    [1:0] codel0 = {|d1[ 3: 2],d1[ 3] || (d1[ 1] & ~d1[ 2])};
    wire    [1:0] codel1 = {|d1[ 7: 6],d1[ 7] || (d1[ 5] & ~d1[ 6])};
    wire    [1:0] codel2 = {|d1[   10],          (d1[ 9] & ~d1[10])};
    wire    [3:0] codel =  this2? {2'b10,codel2[1:0]} :
                     (this1? {2'b01, codel1[1:0]} :
                             (this0 ? {2'b00,codel0[1:0]} : 4'b1111));    // after +1 will be 0;

    always @(posedge clk) begin
        d1[  11]    <=  d[11];
        d1[10:0]    <=  d[11] ? -d[10:0] : d[10:0];
    
        q[10:0]     <= d1[11] ? ~d1[10:0] : d1[10:0];
        l    <= codel[3:0]+1;    // needed only ASAP, valid only 2 cycles after start

    end

endmodule
