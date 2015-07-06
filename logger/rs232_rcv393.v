/*******************************************************************************
 * Module: rs232_rcv393
 * Date:2015-07-06  
 * Author: andrey     
 * Description: rs232 receiver
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * rs232_rcv393.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  rs232_rcv393.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  rs232_rcv393(
                   xclk,           // half frequency (80 MHz nominal)
                   bitHalfPeriod,  // half of the serial bit duration, in xclk cycles
                   ser_di,         // rs232 (ttl) serial data in
                   ser_rst,        // reset (force re-sync)
                   ts_stb,         // strobe timestamp (start of message) (reset bit counters in nmea decoder)
                   wait_just_pause,// may be used as reset for decoder
                   start,          // serial character start (single pulse)
//                   char,           // byte out
//                   char_stb);      // char strobe (@posedge xclk)
                   ser_do,         // serial data out(@posedge xclk) LSB first!
                   ser_do_stb,    // output data strobe (@posedge xclk), first cycle after ser_do becomes valid
                   debug,        // {was_ts_stb, was_start, was_error, was_ser_di_1, was_ser_di_0} - once after reset
                   bit_dur_cntr,
                   bit_cntr);
  input         xclk;           // half frequency (80 MHz nominal)
  input  [15:0] bitHalfPeriod;  // half of the serial bit duration, in xclk cycles
  input         ser_di;         // rs232 (ttl) serial data in
  input         ser_rst;        // reset (force re-sync)
  output        ts_stb;         // strobe timestamp (start of message)
  output        wait_just_pause;// may be used as reset for decoder
  output        start;          // serial character start (single pulse)
  output [4:0]  debug;          // {was_ts_stb, was_start, was_error, was_ser_di_1, was_ser_di_0} - once after reset
  output        ser_do;         // serial data out(@posedge xclk)
  output        ser_do_stb;     // output data strobe (@posedge xclk), 2 cycles after ser_do becomes valid
  output [15:0] bit_dur_cntr;   // debug
  output  [4:0] bit_cntr;       // debug
  
  reg  [4:0] ser_di_d;
  reg        ser_filt_di;
  reg        ser_filt_di_d;
  reg        bit_half_end; // last cycle in half-bit
  reg        last_half_bit;
  reg        wait_pause;   // waiting input to stay at 1 for 10 cycles
  reg        wait_start;   // (or use in_sync - set it after wait_pause is over?
  reg        receiving_byte;
  reg        start;
  reg [15:0] bit_dur_cntr; // bit duration counter (half bit duration)
  reg [4:0]  bit_cntr;     // counts half-bit intervals
  wire       error;        // low level during stop slot
  reg  [1:0] restart;
  wire       reset_wait_pause;
  reg        ts_stb;
  reg        shift_en;
  
  reg        ser_do;
  reg        ser_do_stb;
  wire       sample_bit;
  wire       reset_bit_duration;
  reg        wait_just_pause;
  wire       wstart;
  wire [4:0] debug;
  reg  [4:0] debug0;          // {was_ts_stb, was_start, was_error, was_ser_di_1, was_ser_di_0} - once after reset
  assign     reset_wait_pause= (restart[1] && !restart[0]) || (wait_pause && !wait_start && !ser_di);
  assign     error=!ser_filt_di && last_half_bit && bit_half_end && receiving_byte;
  assign     sample_bit=shift_en && bit_half_end && !bit_cntr[0];
  assign     reset_bit_duration= reset_wait_pause || start || bit_half_end || ser_rst;
  
  assign wstart=wait_start && ser_filt_di_d && !ser_filt_di;
  
  assign debug[4:0] = {1'b0,wait_start,wait_pause,receiving_byte,shift_en};
  always @ (posedge xclk) begin
//    reg  [4:0] ser_di_d;
//  reg        ser_filt_di;
//  reg        ser_filt_di_d;
    ser_di_d[4:0] <= {ser_di_d[3:0],ser_di};
    if (ser_rst || &ser_di_d[4:0]) ser_filt_di <= 1'b1;
    else if      (~|ser_di_d[4:0]) ser_filt_di <= 1'b0;

    ser_filt_di_d <= ser_filt_di;
    
    restart[1:0] <= {restart[0],(ser_rst || (last_half_bit && bit_half_end && receiving_byte))};
    wait_pause <= !ser_rst && (reset_wait_pause ||
                               (receiving_byte && last_half_bit && bit_half_end ) ||
                               (wait_pause && !(last_half_bit && bit_half_end) && !(wait_start && !ser_filt_di)));
//    start                 <= wait_start && ser_di_d && !ser_di;
    start                 <= wstart;
//    ts_stb <= !wait_pause && wait_start && ser_di_d && !ser_di;
    ts_stb <= !wait_pause && wstart; // only first start after pause
    bit_half_end <=(bit_dur_cntr[15:0]==16'h1) && !reset_bit_duration;
    
//    wait_start <= ser_di && !ser_rst && ((wait_pause || receiving_byte) && last_half_bit && bit_half_end  || wait_start);
    wait_start <= !ser_rst && ((wait_pause || receiving_byte) && last_half_bit && bit_half_end  || (wait_start && !wstart));
//    receiving_byte <= !ser_rst && !error && (start || (receiving_byte && !(last_half_bit && bit_half_end)));
    receiving_byte <= !ser_rst && (start || (receiving_byte && !(last_half_bit && bit_half_end)));
    wait_just_pause <=wait_pause && !wait_start;
    
    
    if (reset_bit_duration) bit_dur_cntr[15:0] <= bitHalfPeriod[15:0];
    else                    bit_dur_cntr[15:0] <= bit_dur_cntr[15:0] - 1;
    
    if (reset_wait_pause || ser_rst)  bit_cntr[4:0] <= 5'h13;
    else if (start)                    bit_cntr[4:0] <= 5'h12;
    else if (bit_half_end)             bit_cntr[4:0] <= bit_cntr[4:0] - 1;

    last_half_bit <= ((bit_cntr[4:0] == 5'h0) && !bit_half_end); 
    shift_en <= receiving_byte &&  ((bit_half_end && ( bit_cntr[3:0]==4'h2))? bit_cntr[4]:shift_en);

   
    if (sample_bit) ser_do <= ser_filt_di;
    ser_do_stb <= sample_bit; 
    
    
    if (ser_rst) debug0[4:0] <=5'b0;
    else debug0[4:0] <= debug | {ts_stb,start,error,ser_di_d,~ser_di_d};
  end
endmodule
