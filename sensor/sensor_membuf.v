/*******************************************************************************
 * Module: sensor_membuf
 * Date:2015-07-12  
 * Author: Andrey Filippov     
 * Description: Memory buffer for one sensor channel
 *
 * Copyright (c) 2015 Elphel, Inc .
 * sensor_membuf.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  sensor_membuf.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  sensor_membuf #(
    parameter WADDR_WIDTH=9 // for 36Kb RAM
)(
    input         pclk,
    input  [15:0] px_data,      // @posedge pclk pixel (pixel pair) data from the sensor channel
    input         px_valid,     // px_data valid
    input         last_in_line, // valid with px_valid - last px_data in line
    
    input         mclk,         // memory interface clock
    input         rpage_set,    // set internal read page to rpage_in (reset pointers)
    input         rpage_next,   // advance to next page (and reset lower bits to 0)
    input         buf_rd,       // read buffer to memory, increment read address (regester enable will be delayed)
    output [63:0] buf_dout,     // data out
    output reg    page_written  // buffer page (full or partial) is written to the memory buffer 
              

);
    
    reg              [1:0] wpage;
    reg  [WADDR_WIDTH-1:0] waddr;
    
    reg                    sim_rst = 1; // jsut for simulation - reset from system reset to the first rpage_set
    reg              [2:0] rst_pntr;
    wire                   rst_wpntr;
    wire                   inc_wpage_w;
    
    assign inc_wpage_w = px_valid && (last_in_line || (&waddr));
    always @ (posedge mclk) begin
        rst_pntr <= {rst_pntr[1] &~rst_pntr[0], rst_pntr[0], rpage_set};
        if (rpage_set) sim_rst <= 0;
    end
    
    always @ (posedge pclk) begin
        if (rst_wpntr || (px_valid && last_in_line)) waddr <= 0;
        else if (px_valid)                           waddr <= waddr + 1;
        
        if      (rst_wpntr)   wpage <= 0;
        else if (inc_wpage_w) wpage <=  wpage + 1;
    end 

    pulse_cross_clock  rst_wpntr_i (
            .rst        (sim_rst),
            .src_clk    (mclk),
            .dst_clk    (pclk),
            .in_pulse   (rst_pntr[2]),
            .out_pulse  (rst_wpntr),
            .busy       ()
     );

    pulse_cross_clock  page_written_i (
            .rst        (sim_rst),
            .src_clk    (pclk),
            .dst_clk    (mclk),
            .in_pulse   (inc_wpage_w),
            .out_pulse  (page_written),
            .busy       ()
     );


    mcntrl_buf_wr #(
         .LOG2WIDTH_WR(4)  // 64 bit external interface
    ) chn1wr_buf_i (
        .ext_clk      (pclk),            // input
        .ext_waddr    ({wpage, waddr}),  // input[9:0] 
        .ext_we       (px_valid),        // input
        .ext_data_in  (px_data),         // input[15:0] buf_wdata - from AXI
        .rclk         (mclk),            // input
        .rpage_in     (2'b0),            // input[1:0] 
        .rpage_set    (rpage_set),       // input  @ posedge mclk
        .page_next    (rpage_next),      // input
        .page         (),                // output[1:0]
        .rd           (buf_rd),          // input
        .data_out     (buf_dout)         // output[63:0] 
    );


endmodule

