/*******************************************************************************
 * Module: rtc393
 * Date:2015-07-05  
 * Author: andrey     
 * Description: Adjustable real time clock, generate 1 microsecond resolution,
 * timestamps. Provides seconds (32 bit) and microseconds (20 bits),
 * allows 24-bit accummulator-based fine adjustment
 *
 * Copyright (c) 2005-2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * rtc393.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  rtc393.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  rtc393 #(
        parameter RTC_ADDR=                  'h170, //TODO: assign valid address
        parameter RTC_MASK=                  'h3fc,
        parameter RTC_MHZ=                      25, // RTC input clock in MHz (should be interger number)
        parameter RTC_BITC_PREDIV =              5, // number of bits to generate 2 MHz pulses counting refclk 
        parameter RTC_SET_USEC=                  0, // 20-bit number of microseconds
        parameter RTC_SET_SEC=                   1, // 32-bit full number of seconds (und actually update timer)
        parameter RTC_SET_CORR=                  2 // write correction 16-bit signed

)   (
    input                         rst,
    input                         mclk,
    input                         refclk, // not a global clock, reference frequency < mclk/2
    // programming interface
    input                   [7:0] cmd_ad,      // byte-serial command address/data (up to 6 bytes: AL-AH-D0-D1-D2-D3 
    input                         cmd_stb,     // strobe (with first byte) for the command a/d
    
    output                 [31:0] live_sec,
    output                 [19:0] live_usec);
    
    wire  [31:0] cmd_data;
    wire   [2:0] cmd_a;
    wire         cmd_we; 

    wire         set_usec_w;  
    wire         set_sec_w;  
    wire         set_corr_w;
    
    reg  [19:0] wusec;   
    reg  [31:0] wsec;   
    reg  [15:0] corr;
    
    reg  [RTC_BITC_PREDIV-1:0] pre_cntr = 0;
    reg   [3:0] halfusec = 0; // 1-hot running pulse with 0.5 usec period
    reg   [2:0] refclk_mclk;
    reg         refclk2x_mclk;   
    reg         enable_rtc=0;
    reg         pend_set_cntr=0;
    reg         set_cntr; // valid for the full 0.5 usec
    reg  [23:0] acc;
    wire [24:0] next_acc;
    reg   [1:0] inc_usec;
    reg   [1:0] inc_sec;

    reg  [19:0] usec;
    reg  [31:0] sec;

    reg  [19:0] usec_plus1;
    reg  [31:0] sec_plus1;
    
    
    
    assign set_usec_w = cmd_we && (cmd_a == RTC_SET_USEC);
    assign set_sec_w =  cmd_we && (cmd_a == RTC_SET_SEC);
    assign set_corr_w = cmd_we && (cmd_a == RTC_SET_CORR);
    assign next_acc[24:0]= {1'b0,acc[23:0]} + {1'b0,~corr [15], {7{corr [15]}}, corr[15:0]};
    
    assign live_sec = sec;
    assign live_usec = usec;
    
    always @ (posedge mclk) begin
        if (set_usec_w) wusec <= cmd_data[19:0]; 
        if (set_sec_w)  wsec <=  cmd_data[31:0]; 
        if (set_corr_w) corr <=  cmd_data[15:0]; 
    end

    always @ (posedge rst or posedge mclk) begin
        if      (rst)       enable_rtc <= 0;
        else if (set_sec_w) enable_rtc <= 1;
    end
    
    always @ (posedge mclk) begin
        
        if (!enable_rtc || halfusec[0]) pre_cntr <= RTC_MHZ-2;
        else if (refclk2x_mclk)         pre_cntr <= pre_cntr - 1;
        
        if (!enable_rtc) halfusec <= 0;
        else             halfusec <= {halfusec[2:0], (|pre_cntr)?1'b0:1'b1};
        
        if (set_usec_w)      pend_set_cntr <= 1'b0; // just to get rid of undefined
        if (set_sec_w)       pend_set_cntr <= 1'b1;
        else if (halfusec[3])pend_set_cntr <= 1'b0;
        
    
        refclk_mclk <= {refclk_mclk[1:0], refclk};
        refclk2x_mclk <= refclk_mclk[2] ^ refclk_mclk[1];
        
        if (halfusec[1]) acc[23:0] <= set_cntr?24'h0:next_acc[23:0];
  
        if      (!enable_rtc) set_cntr <= 1'b0;
        else if (halfusec[3]) set_cntr <= pend_set_cntr;
      
      
        inc_usec <= {inc_usec[0],halfusec[1] & next_acc[24]};
        inc_sec  <= {inc_sec[0], halfusec[1] & next_acc[24] & ((usec[19:0]==20'hf423f)?1'b1:1'b0)};

        sec_plus1  <= sec + 1;
        usec_plus1 <= usec + 1;
        
        if      (set_cntr)    usec[19:0] <= wusec[19:0];
        else if (inc_sec[1])  usec[19:0] <= 20'h0;
        else if (inc_usec[1]) usec[19:0] <= usec_plus1[19:0];
      
        if      (set_cntr)    sec[31:0] <= wsec[31:0];
        else if (inc_sec[1])  sec[31:0] <= sec_plus1[31:0];
        
    end

        cmd_deser #(
        .ADDR       (RTC_ADDR),
        .ADDR_MASK  (RTC_MASK),
        .NUM_CYCLES (6),
        .ADDR_WIDTH (3),
        .DATA_WIDTH (32)
    ) cmd_deser_32bit_i (
        .rst        (rst),      // input
        .clk        (mclk),     // input
        .ad         (cmd_ad),   // input[7:0] 
        .stb        (cmd_stb),  // input
        .addr       (cmd_a),    // output[3:0] 
        .data       (cmd_data), // output[31:0] 
        .we         (cmd_we)    // output
    );
    
endmodule

