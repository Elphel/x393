/*******************************************************************************
 * Module: buf_xclk_mclk16_393
 * Date:2015-07-06  
 * Author: andrey     
 * Description: move data from xclk to mclk domain
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * buf_xclk_mclk16_393.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  buf_xclk_mclk16_393.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  buf_xclk_mclk16_393(
                          xclk, // posedge
                          mclk, // posedge
                          rst,  // @posedge xclk
                          din,
                          din_stb,
                          dout,
                          dout_stb);

  input         xclk;  // half frequency (80 MHz nominal)
  input         mclk;  // system clock - frequency (160 MHz nominal)
  input         rst;   // reset module
  input  [15:0] din;
  input         din_stb;
  output [15:0] dout;
  output        dout_stb;

  reg   [1:0] wa;
  reg   [1:0] wa_mclk;
  reg   [1:0] wa_mclk_d;
  reg         rst_mclk;
  reg   [1:0] ra;
  reg   [1:0] ra_next;
  reg         inc_ra;
  wire [15:0] pre_dout;
  reg  [15:0] dout;
  reg         dout_stb;
  always @ (posedge xclk) begin
    if      (rst)     wa[1:0] <= 2'h0;
    else if (din_stb) wa[1:0] <={wa[0],~wa[1]};
  end
  always @ (posedge mclk) begin
    wa_mclk[1:0]   <= wa[1:0];
    wa_mclk_d[1:0] <= wa_mclk[1:0];
    rst_mclk<= rst;
    if (rst_mclk) ra[1:0] <= 2'h0;
    else          ra[1:0] <= inc_ra?{ra[0],~ra[1]}:{ra[1],ra[0]};

    if (rst_mclk) ra_next[1:0] <= 2'h1;
    else          ra_next[1:0] <= inc_ra?{~ra[1],~ra[0]}:{ra[0],~ra[1]};

    inc_ra <= !rst && (ra[1:0]!=wa_mclk_d[1:0]) && (!inc_ra || (ra_next[1:0]!=wa_mclk_d[1:0]));
    dout_stb <= inc_ra;
    if (inc_ra) dout[15:0] <= pre_dout[15:0];
  end


  myRAM_WxD_D #( .DATA_WIDTH(16),.DATA_DEPTH(2))
            i_fifo_4x16   (.D(din[15:0]),
                             .WE(din_stb),
                             .clk(xclk),
                             .AW(wa[1:0]),
                             .AR(ra[1:0]),
                             .QW(),
                             .QR(pre_dout[15:0]));

endmodule


endmodule

