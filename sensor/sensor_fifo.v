/*******************************************************************************
 * Module: sensor_fifo
 * Date:2015-05-19  
 * Author: Andrey Filippov     
 * Description: Cross clock boundary for sensor data, synchronize to HACT
 *
 * Copyright (c) 2015 Elphel, Inc.
 * sensor_fifo.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  sensor_fifo.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  sensor_fifo #(
    parameter SENSOR_DATA_WIDTH = 12,
    parameter SENSOR_FIFO_2DEPTH = 4, // 4-bit address
    parameter SENSOR_FIFO_DELAY = 7 // approxiametly half (1 << SENSOR_FIFO_2DEPTH) - how long to wait after getting HACT on FIFO before stering it on output
)(
    input                          rst,
    input                          iclk, // input -synchronous clock
    input                          pclk, // internal lixel clock
    input  [SENSOR_DATA_WIDTH-1:0] pxd_in,  // sensor data @posedge iclk
    input                          vact,
    input                          hact,
    output [SENSOR_DATA_WIDTH-1:0] pxd_out,
    output                         data_valid, // @posedge pclk: continuous data valid for each line, FIFO should compensate for clock differences
    output                         sof,        // @posedge pclk: single-cycle Start of Frame
    output                         eof         // @posedge pclk: single-cycle End of Frame (not yet used)
);
    reg                          vact_r,hact_r,sof_in,eof_in;
    wire [SENSOR_DATA_WIDTH-1:0] pxd_w;
    wire                         nempty, hact_w,sof_w,eof_w;
    reg                          sof_r,eof_r;
    wire we;
    // output clock domain
    wire pre_re,re_w,re;
    reg                         re_r;
    reg                   [1:0] pre_hact;
    reg                         hact_out_r;
    reg [SENSOR_DATA_WIDTH-1:0] pxd_r;
    wire                        hact_out_start;
    
    assign we=sof_in || eof_in || hact || hact_r;
    always @(posedge rst or posedge iclk) begin
        if (rst) {vact_r,hact_r,sof_in,eof_in} <= 0;
        else     {vact_r,hact_r,sof_in,eof_in} <= {vact,hact, vact && ! vact_r, vact_r && !vact};
    end

    fifo_cross_clocks #(
        .DATA_WIDTH(SENSOR_DATA_WIDTH+3),
        .DATA_DEPTH(SENSOR_FIFO_2DEPTH)
    ) fifo_cross_clocks_i (
        .rst        (rst), // input
        .rclk       (pclk), // input
        .wclk       (iclk), // input
        .we         (we), // input
        .re         (re), // input
        .data_in    ({eof_in, sof_in, hact,   pxd_in}), // input[15:0] 
        .data_out   ({eof_w,  sof_w,  hact_w, pxd_w}), // output[15:0] 
        .nempty     (nempty), // output
        .half_empty () // output
    );

    dly_16 #(
        .WIDTH(1)
    ) hact_dly_16_i (
        .clk(pclk), // input
        .rst(rst), // input
        .dly(SENSOR_FIFO_DELAY), // input[3:0] 
        .din(pre_hact[0] && ! pre_hact[1]), // input[0:0] 
        .dout(hact_out_start) // output[0:0] 
    );
    
    // output clock domain
    assign pre_re = nempty && !re_r;
    assign re_w = re_r && nempty; // to protect from false positive on nempty
    assign re = (re_w && !pre_hact) || hact_out_r;
    assign pxd_out= pxd_r;
    assign data_valid = hact_out_r;
    assign sof = sof_r;
    assign eof = eof_r;
     
    always @(posedge rst or posedge iclk) begin
        if (rst) re_r <= 0;
        else     re_r <= pre_re;

        if     (rst) pre_hact[0] <= 0;
        else if (re) pre_hact[0] <= hact_w;

        if     (rst) pre_hact[1] <= 0;
        else if (re) pre_hact[1] <= pre_hact[0];

        if     (rst) pxd_r <= 0;
        else if (re) pxd_r <= pxd_w;

        if      (rst)            hact_out_r <= 0;
        else if (hact_out_start) hact_out_r <= 1;
        else if (!hact_w)        hact_out_r <= 0;

        if (rst) sof_r <= 0;
        else     sof_r <= re && sof_w;

        if (rst) eof_r <= 0;
        else     eof_r <= re && eof_w;

    end
    


endmodule

