/*******************************************************************************
 * Module: imu_timestamps393
 * Date:2015-07-06  
 * Author: andrey     
 * Description: Acquire timestmps for events
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * imu_timestamps393.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  imu_timestamps393.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  imu_timestamps393(
                        sclk, // 160MHz, negedge            
                        xclk, // 80 MHz, posedge
                        rst,  // reset (@posedge xclk)
                        sec,  // running seconds (@negedge sclk)
                        usec, // running microseconds (@negedge sclk)
                        ts_rq,// requests to create timestamps (4 channels), @posedge xclk
                        ts_ackn, // timestamp for this channel is stored
                        ra,   // read address (2 MSBs - channel number, 2 LSBs - usec_low, (usec_high ORed with channel <<24), sec_low, sec_high
                        dout);// output data
   input         sclk;
   input         xclk;
   input         rst;
   input  [31:0] sec;
   input  [19:0] usec;
   input  [ 3:0] ts_rq;
   output [ 3:0] ts_ackn;
   input  [ 3:0] ra;
   output [15:0] dout;
   
   reg    [31:0] sec_latched;
   reg    [19:0] usec_latched;
   reg    [15:0] ts_mux;
   
   reg    [ 3:0] wa;
   reg           srst;
   reg    [3:0]  rq_d;
   reg    [3:0]  rq_d2;
   reg    [3:0]  rq_r;
   reg    [3:0]  rq_sclk;
   reg    [3:0]  rq_sclk2;
   reg    [3:0]  pri_sclk;
   reg    [3:0]  pri_sclk_d;
   reg    [3:0]  rst_rq;
   reg    [9:0]  proc;
   wire          wstart;
   reg           we;
   wire   [3:0]  wrst_rq;
   reg    [3:0]  ts_preackn;
   reg    [3:0]  ts_ackn;
   assign        wstart=|pri_sclk[3:0] && (pri_sclk[3:0] != pri_sclk_d[3:0]);
   assign        wrst_rq[3:0]={wa[3]&wa[2],wa[3]&~wa[2],~wa[3]&wa[2],~wa[3]&~wa[2]} & {4{proc[5]}};
   always @ (posedge xclk) begin
     rq_d[3:0] <= ts_rq[3:0];
     rq_d2[3:0] <= rq_d[3:0];
   end
   
   always @ (negedge sclk) begin
     srst <= rst;
     rq_sclk[3:0]  <= srst?4'h0:(~rst_rq[3:0] & (rq_r[3:0] | rq_sclk[3:0])) ;
     rq_sclk2[3:0] <= srst?4'h0:(~rst_rq[3:0] & rq_sclk[3:0]) ;
     pri_sclk[3:0] <= {rq_sclk2[3] & ~|rq_sclk2[2:0],
                       rq_sclk2[2] & ~|rq_sclk2[1:0],
                       rq_sclk2[1] &  ~rq_sclk2[0],
                       rq_sclk2[0]};
     pri_sclk_d[3:0] <= pri_sclk[3:0];
     proc[9:0] <= {proc[9:0], wstart};
     if (proc[0]) wa[3:2] <= {|pri_sclk_d[3:2], pri_sclk_d[3] | pri_sclk_d[1]};
     if (proc[0]) sec_latched[31:0] <= sec[31:0];
     if (proc[0]) usec_latched[19:0] <= usec[19:0];
//     if (proc[2]) ts_mux[15:0] <= {6'h0,wa[3:2],4'h0,usec[19:16]};
     casex({proc[8],proc[6],proc[4],proc[2]})
//       4'bXXX1: ts_mux[15:0] <= {6'h0,wa[3:2],4'h0,usec_latched[19:16]};
//       4'bXX1X: ts_mux[15:0] <= usec_latched[15: 0];
//       4'bX1XX: ts_mux[15:0] <=  sec_latched[31:16];
//       4'b1XXX: ts_mux[15:0] <=  sec_latched[15: 0];
       4'bXXX1: ts_mux[15:0] <= usec_latched[15: 0];
       4'bXX1X: ts_mux[15:0] <= {6'h0,wa[3:2],4'h0,usec_latched[19:16]};
       4'bX1XX: ts_mux[15:0] <= sec_latched[15: 0];
       4'b1XXX: ts_mux[15:0] <= sec_latched[31:16];

     endcase
     we <= proc[3] || proc[5] || proc[7] || proc[9];
     if (proc[2]) wa[1:0] <= 2'b0;
     else if (we) wa[1:0] <= wa[1:0] + 1;
     rst_rq[3:0] <= wrst_rq[3:0] | {4{srst}};
   end
   always @ (posedge xclk or posedge rq_sclk2[0]) begin
     if       (rq_sclk2[0])          rq_r[0] <= 1'b0;
     else  if (srst)                 rq_r[0] <= 1'b0;
     else  if (rq_d[0] && !rq_d2[0]) rq_r[0] <= 1'b1;
   end
   always @ (posedge xclk or posedge rq_sclk2[1]) begin
     if       (rq_sclk2[1])          rq_r[1] <= 1'b0;
     else  if (srst)                 rq_r[1] <= 1'b0;
     else  if (rq_d[1] && !rq_d2[1]) rq_r[1] <= 1'b1;
   end
   always @ (posedge xclk or posedge rq_sclk2[2]) begin
     if       (rq_sclk2[2])          rq_r[2] <= 1'b0;
     else  if (srst)                 rq_r[2] <= 1'b0;
     else  if (rq_d[2] && !rq_d2[2]) rq_r[2] <= 1'b1;
   end
   always @ (posedge xclk or posedge rq_sclk2[3]) begin
     if       (rq_sclk2[3])          rq_r[3] <= 1'b0;
     else  if (srst)                 rq_r[3] <= 1'b0;
     else  if (rq_d[3] && !rq_d2[3]) rq_r[3] <= 1'b1;
   end

   always @ (posedge xclk or posedge rst_rq[0]) begin
     if       (rst_rq[0])  ts_preackn[0] <= 1'b1;
     else  if (!ts_rq[0])  ts_preackn[0] <= 1'b0;
   end
   always @ (posedge xclk or posedge rst_rq[1]) begin
     if       (rst_rq[1])  ts_preackn[1] <= 1'b1;
     else  if (!ts_rq[1])  ts_preackn[1] <= 1'b0;
   end
   always @ (posedge xclk or posedge rst_rq[2]) begin
     if       (rst_rq[2])  ts_preackn[2] <= 1'b1;
     else  if (!ts_rq[2])  ts_preackn[2] <= 1'b0;
   end
   always @ (posedge xclk or posedge rst_rq[3]) begin
     if       (rst_rq[3])  ts_preackn[3] <= 1'b1;
     else  if (!ts_rq[3])  ts_preackn[3] <= 1'b0;
   end

   always @ (posedge xclk) begin
     ts_ackn[3:0] <= ts_preackn[3:0] & ts_rq[3:0];
   end

  myRAM_WxD_D #( .DATA_WIDTH(16),.DATA_DEPTH(4))
            i_ts   (.D(ts_mux[15:0]),
                       .WE(we), // we_d, decoded sub_address
                       .clk(!sclk),
                       .AW(wa[3:0]),
                       .AR(ra[3:0]),
                       .QW(),
                       .QR(dout[15:0]));
                       
endmodule 

