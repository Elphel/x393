/*******************************************************************************
 * Module: imu_message393
 * Date:2015-07-06  
 * Author: andrey     
 * Description: 
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * imu_message393.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  imu_message393.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

/*
logs events from odometer (can be software triggered), includes 56-byte message written to the buffer
So it is possible to assert trig input (will request timestamp), write message by software, then
de-assert the trig input - message with the timestamp will be logged
fixed-length de-noise circuitry with latency 256*T(xclk) (~3usec)
*/

module  imu_message393 ( sclk,   // system clock, negedge
                       xclk,  // half frequency (80 MHz nominal)
                       we,    // write enable for registers to log (@negedge sclk), with lower data half
                       wa,    // write address for register (4 bits, @negedge sclk)
                       di,    // 16-bit data in  multiplexed 
                       en,    // enable module operation, if 0 - reset
                       trig,  // leading edge - sample time, trailing set rdy
                       ts,    // timestamop request
                       rdy,    // data ready
                       rd_stb, // data read strobe (increment address)
                       rdata); // data out (16 bits)

  input         sclk;   // system clock, negedge
  input         xclk;  // half frequency (80 MHz nominal)
  input         we;    // write enable for registers to log (@negedge sclk)
  input  [3:0]  wa;    // write address for register (4 bits, @negedge sclk)
  input  [15:0] di;    // 16-bit data in (32 multiplexed)
  input         en;    // enable
  input         trig;  // leading edge - sample time, trailing set rdy
  output        ts;    // timestamp request
  output        rdy;    // encoded nmea data ready
  input         rd_stb; // encoded nmea data read strobe (increment address)
  output [15:0] rdata;  // encoded data (16 bits)

  reg  [ 4:0]   raddr;
  reg           rdy=1'b0;
  reg           we_d;
  reg  [ 4:1]   waddr;
  reg  [ 2:0]   trig_d;
  reg  [ 7:0]   denoise_count;
  reg  [ 1:0]   trig_denoise;
  reg           ts;
  reg    [15:0] di_d;

  always @ (negedge sclk) begin
    di_d[15:0] <= di[15:0];
    waddr[4:1] <= wa[3:0];
    we_d <=we;
  end
  always @ (posedge xclk) begin
    if  (!en) trig_d[2:0] <= 3'h0;
    else      trig_d[2:0] <= {trig_d[1:0], trig};
    if      (!en)                      trig_denoise[0] <= 1'b0;
    else if (denoise_count[7:0]==8'h0) trig_denoise[0] <= trig_d[2];
    if (trig_d[2]==trig_denoise[0]) denoise_count[7:0] <= 8'hff;
    else                            denoise_count[7:0] <= denoise_count[7:0] - 1;
    trig_denoise[1] <= trig_denoise[0];
    ts <= !trig_denoise[1] && trig_denoise[0];

    if (!en || ts)   raddr[4:0] <= 5'h0;
    else if (rd_stb)    raddr[4:0] <= raddr[4:0] + 1;

    if  (ts || (rd_stb && (raddr[4:0]==5'h1b)) || !en) rdy <= 1'b0;
    else if (trig_denoise[1] && !trig_denoise[0])     rdy <= 1'b1;
  end

  myRAM_WxD_D #( .DATA_WIDTH(16),.DATA_DEPTH(5))
            i_odbuf (.D(di_d[15:0]),
                     .WE(we | we_d),
                     .clk(~sclk),
                     .AW({waddr[4:1],we_d}),
                     .AR(raddr[4:0]),
                     .QW(),
                     .QR(rdata[15:0]));

endmodule


endmodule

