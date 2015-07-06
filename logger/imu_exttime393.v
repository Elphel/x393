/*******************************************************************************
 * Module: imu_exttime393
 * Date:2015-07-06  
 * Author: andrey     
 * Description: get external timestamp (for image)
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * imu_exttime393.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  imu_exttime393.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps
/*
logs frame synchronization data from other camera (same as frame sync)
*/

module  imu_exttime393(
                       xclk,  // half frequency (80 MHz nominal)
                       en,    // enable module operation, if 0 - reset
                       trig,  // external time stamp updated
                       usec,  // microseconds from external timestamp (should not chnage after trig for 10 xclk)
                       sec,   // seconds from external timestamp
                       ts,    // timestamop request
                       rdy,    // data ready
                       rd_stb, // data read strobe (increment address)
                       rdata); // data out (16 bits)

  input         xclk;  // half frequency (80 MHz nominal)
  input         en;    // enable
  input         trig;  // external time stamp updated
  input  [19:0] usec;  // microseconds from external timestamp
  input  [31:0] sec;   // seconds from external timestamp
  output        ts;    // timestamp request
  output        rdy;   // encoded nmea data ready
  input         rd_stb;// encoded nmea data read strobe (increment address)
  output [15:0] rdata; // encoded data (16 bits)

  reg  [ 4:0]   raddr;
  reg           rdy=1'b0;
  

  reg           we, pre_we;
  reg  [ 3:0]   pre_waddr;
  reg  [ 1:0]   waddr;
  reg  [ 2:0]   trig_d;
  reg           pre_ts,ts;
  reg  [15:0]   time_mux;
  always @ (posedge xclk) begin
    if  (!en) trig_d[2:0] <= 3'h0;
    else      trig_d[2:0] <= {trig_d[1:0], trig};

    pre_ts <= !trig_d[2] && trig_d[1];
    ts <= pre_ts; // delayed so arbiter will enable ts to go through
    if      (!en || pre_ts)     pre_waddr[3:0] <= 4'b0;
    else if (!pre_waddr[3]) pre_waddr[3:0] <= pre_waddr[3:0] + 1;
    if (pre_waddr[0]) waddr[1:0] <=pre_waddr[2:1];
    if (pre_waddr[0] && !pre_waddr[3]) case (pre_waddr[2:1])
      2'b00: time_mux[15:0] <= usec[15:0];
      2'b01: time_mux[15:0] <= {12'h0,usec[19:16]};
      2'b10: time_mux[15:0] <= sec[15:0];
      2'b11: time_mux[15:0] <= sec[31:16];
    endcase
    pre_we<=pre_waddr[0] && !pre_waddr[3];
    we <= pre_we;

    if (!en || pre_ts)   raddr[4:0] <= 5'h0;
    else if (rd_stb)    raddr[4:0] <= raddr[4:0] + 1;

    if  (pre_ts || (rd_stb && (raddr[1:0]==2'h3)) || !en) rdy <= 1'b0;
    else if (we && (waddr[1:0]==2'h3))                rdy <= 1'b1;
  end

  myRAM_WxD_D #( .DATA_WIDTH(16),.DATA_DEPTH(2))
            i_odbuf (.D(time_mux[15:0]),
                     .WE(we),
                     .clk(xclk),
                     .AW(waddr[1:0]),
                     .AR(raddr[1:0]),
                     .QW(),
                     .QR(rdata[15:0]));

endmodule



endmodule

