/*******************************************************************************
 * Module: event_logger
 * Date:2015-07-06  
 * Author: andrey     
 * Description: top module of the event logger (ported from imu_logger)
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * event_logger.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  event_logger.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  event_logger(  clk,   // system clock, negedge
                       xclk,  // half frequency (80 MHz nominal)
                       we,    // write enable (lower 16 bits, high - next cycle)
                       wa,    // write address(1)/data(0)
                       di,    // 16-bit data in (32 multiplexed)
                       usec,  // un-latched timestamp microseconds
                       sec,   // un-latched timestamp seconds
                       ext_di,
                       ext_do,
                       ext_en,
                       ts_rcv_sec,  // [31:0] timestamp seconds received over the sync line
                       ts_rcv_usec, // [19:0] timestamp microseconds received over the sync line
                       ts_stb,      // strobe when received timestamp is valid - single negedge sclk cycle
                       data_out,    // 16-bit data out to DMA1 (@negedge clk)
                       data_out_stb,// data out valid (@negedge clk)
                       sample_counter, // could be DMA latency, safe to use sample_counter-1
                       debug_state
                       );
                       
  input         clk;   // system clock, negedge
  input         xclk;  // half frequency (80 MHz nominal)
  input         we;    // write enable (lower 16 bits, high - next cycle)
  input         wa;    // write address(1)/data(0)
  input  [15:0] di;    // 16-bit data in (32 multiplexed)
  input  [19:0] usec;  // latched timestamp microseconds
  input  [31:0] sec;   // latched timestamp seconds
  input  [11:0] ext_di; // external GPIO in
  output [11:0] ext_do; // external GPIO out
  output [11:0] ext_en; // external GPIO enable out
  input  [31:0] ts_rcv_sec;  // [31:0] timestamp seconds received over the sync line
  input  [19:0] ts_rcv_usec; // [19:0] timestamp microseconds received over the sync line
  input         ts_stb;      // strobe when received timestamp is valid - single negedge sclk cycle
  output [15:0] data_out;    // 16-bit data out to DMA1 (@negedge clk)
  output        data_out_stb;// data out valid (@negedge clk)
  output [23:0] sample_counter; // could be DMA latency, safe to use sample_counter-1
  output [31:0] debug_state;

  wire         ser_di;      // gps serial data in
  wire         gps_pulse1sec;
  wire         mosi;  // to IMU, bit 2 in J9
  wire         miso;  // from IMU, bit 3 on J9 
  wire         sda, sda_en, scl, scl_en;

  reg    [6:0]  ctrl_addr=7'h0; // 0 - period, 1 - reserved, 2..31 - registers to log, >32 - gps parameters, >64 - odometer message
  reg           we_d; // only if wa was 0
  reg           we_imu;
  reg           we_gps;
  reg           we_period;
  reg           we_bit_duration;
  reg           we_message;
  reg           we_config;
  reg           we_config_imu; // bits 1:0, 2 - enable slot[1:0]
  reg           we_config_gps; // bits 6:3, 7 - enable - {ext,invert, slot[1:0]} slot==0 - disable
  reg           we_config_msg; // bits 12:8,13 - enable - {invert,extinp[3:0]} extinp[3:0]=='hf' - disable
  reg           we_config_syn; // bit  14,  15 - enable  - enable logging external timestamps

//  reg           we_config_rst; // bit  16,  17 - enable - reset modules 
//  reg           we_config_debug; // bits  21:18, 22 - enable
  reg    [15:0] di_d;
//  reg           di_d2; 

  reg    [1:0]  config_imu;
  reg    [3:0]  config_gps;
  reg    [4:0]  config_msg;
  reg           config_syn;
  reg           config_rst;
  reg    [3:0]  config_debug;

  reg    [1:0]  config_imu_mclk;
  reg    [3:0]  config_gps_mclk;
  reg    [4:0]  config_msg_mclk;
  reg           config_syn_mclk;
  reg           config_rst_mclk;
  reg    [3:0]  config_debug_mclk;

  reg    [1:0]  config_imu_pre;
  reg    [3:0]  config_gps_pre;
  reg    [4:0]  config_msg_pre;
  reg           config_syn_pre;
  reg           config_rst_pre;
  reg    [3:0]  config_debug_pre;
 
  reg   [15:0]  bitHalfPeriod;//  serial gps speed - number of xclk pulses in half bit period
  reg           we_bitHalfPeriod;
  reg   [15:0]  bitHalfPeriod_mclk;

  reg           enable_gps;
  reg           enable_msg;
  reg           enable_syn;
  reg           enable_timestamps;
  wire          message_trig;

  reg          ts_stb_rq;
  reg    [1:0] ext_ts_stb;

  wire        gps_ts_stb, ser_do,ser_do_stb;
  wire [15:0] imu_data;
  wire [15:0] nmea_data;
  wire [15:0] extts_data;
  wire [15:0] msg_data;

  wire [15:0] timestamps_rdata; // multiplexed timestamp data

  reg   [2:0] gps_pulse1sec_d;
  reg   [1:0] gps_pulse1sec_denoise;
  reg   [7:0] gps_pulse1sec_denoise_count;
  reg         gps_pulse1sec_single;
//  wire        gps_ts; // single cycle @posedge xclk

  wire  [3:0] timestamp_request; // 0 - imu, 1 - gps, 2 - ext, 3 - msg
  wire  [3:0] timestamp_ackn;

  wire [23:0] sample_counter;// could be DMA latency, safe to use sample_counter-1
  wire  [3:0] timestamp_request_long; //from sub-module ts request until reset by arbiter, to allow  timestamp_ackn
  wire  [3:0] channel_ready;  // 0 - imu, 1 - gps, 2 - ext, 3 - msg
  wire  [3:0] channel_next;   // 0 - imu, 1 - gps, 2 - ext, 3 - msg
  wire  [1:0] channel;        // currently logged channel number
  wire  [1:0] timestamp_sel;  // selected word in timestamp (0..3)
  wire        ts_en;          // log timestamp (when false - data)
  wire        mux_data_valid; // data valid from multiplexer (to xclk->clk converter fifo)
  reg  [15:0] mux_data_source;// data multiplexed from 1 of the 4 channels
  reg         mux_rdy_source; // data ready multiplexed from 1of the 4 channels (to fill rest with zeros)
  reg  [15:0] mux_data_final; // data multiplexed between timestamps and channel data (or 0 if ~ready)
  wire [15:0] data_out;    // 16-bit data out to DMA1 (@negedge clk)
  wire        data_out_stb;// data out valid (@posegedge clk)

  wire        rs232_wait_pause;// may be used as reset for decoder
  wire        rs232_start;          // serial character start (single pulse)
  wire        nmea_sent_start;          // serial character start (single pulse)
  reg         pre_message_trig;

 // reg  [1:0]  debug_reg;
  reg [7:0] dbg_cntr;


  assign ext_en[11:0]= {5'b0,(config_imu[1:0]==2'h3)?1'b1:1'b0,1'b0,(config_imu[1:0]==2'h2)?1'b1:1'b0,1'b0,(config_imu[1:0]==2'h1)?1'b1:1'b0,(config_imu[1:0]!=2'h0)?{sda_en,scl_en}:2'h0};
  assign ext_do[11:0]= {5'b0,(config_imu[1:0]==2'h3)?mosi:1'b0,1'b0,(config_imu[1:0]==2'h2)?mosi:1'b0,1'b0,(config_imu[1:0]==2'h1)?mosi:1'b0,(config_imu[1:0]!=2'h0)?{sda,scl}:2'h0};
  assign miso=         config_imu[1]?(config_imu[0]?ext_di[7] :ext_di[5]):(config_imu[0]?ext_di[3]:1'b0);
  assign ser_di=       config_gps[1]?(config_gps[0]?ext_di[6] :ext_di[4]):(config_gps[0]?ext_di[2]:1'b0);
  assign gps_pulse1sec=config_gps[2]^(config_gps[1]?(config_gps[0]?ext_di[7] :ext_di[5]):(config_gps[0]?ext_di[3]:1'b0));

//sngl_wire  
  
  always @(config_msg[3:0] or ext_di[11:0])  begin
    case (config_msg[3:0])
      4'h0:   pre_message_trig = ext_di[0];
      4'h1:   pre_message_trig = ext_di[1];
      4'h2:   pre_message_trig = ext_di[2];
      4'h3:   pre_message_trig = ext_di[3];
      4'h4:   pre_message_trig = ext_di[4];
      4'h5:   pre_message_trig = ext_di[5];
      4'h6:   pre_message_trig = ext_di[6];
      4'h7:   pre_message_trig = ext_di[7];
      4'h8:   pre_message_trig = ext_di[8]; // internal optocoupler, use invert 5'h18
      4'h9:   pre_message_trig = ext_di[9];
      4'ha:   pre_message_trig = ext_di[10];// external optocoupler, use invert 5'h1a
      4'hb:   pre_message_trig = ext_di[10];
      default:pre_message_trig = 1'b0;
    endcase
  end 
  assign message_trig= config_msg[4]^pre_message_trig;

  assign timestamp_request[1]=config_gps[3]? (config_gps[2]?nmea_sent_start:gps_ts_stb):gps_pulse1sec_single;
 

// filter gps_pulse1sec
  always @ (posedge xclk) begin
    if  (config_rst) gps_pulse1sec_d[2:0] <= 3'h0;
    else      gps_pulse1sec_d[2:0] <= {gps_pulse1sec_d[1:0], gps_pulse1sec};
    
    if      (config_rst)                      gps_pulse1sec_denoise[0] <= 1'b0;
    else if (gps_pulse1sec_denoise_count[7:0]==8'h0) gps_pulse1sec_denoise[0] <= gps_pulse1sec_d[2];
    
    if (gps_pulse1sec_d[2]==gps_pulse1sec_denoise[0]) gps_pulse1sec_denoise_count[7:0] <= 8'hff;
    else                            gps_pulse1sec_denoise_count[7:0] <= gps_pulse1sec_denoise_count[7:0] - 1;
    
    gps_pulse1sec_denoise[1] <= gps_pulse1sec_denoise[0];
    gps_pulse1sec_single <= !gps_pulse1sec_denoise[1] && gps_pulse1sec_denoise[0];
  end


// re-sync single pulse @ negedge sclk - ts_stb to @posedge xclk
  always @ (posedge ext_ts_stb[1] or negedge clk) begin
    if (ext_ts_stb[1])        ts_stb_rq <= 1'b0;
    else if (config_rst_mclk) ts_stb_rq <= 1'b0;
    else if (ts_stb)          ts_stb_rq <= 1'b1;
  end
  always @ (posedge xclk) begin
     ext_ts_stb[1:0] <= {ext_ts_stb[0] & ~ext_ts_stb[1],ts_stb_rq};
  end

  always @ (negedge clk) begin
    if (we)      di_d[15:0] <= di[15:0];
//    di_d2 <=di_d[0];
//    we_d       <= we && !wa;
    we_d       <= we && !wa;
    we_imu     <= we && !wa && (ctrl_addr[6:5] == 2'h0);
    we_gps     <= we && !wa && (ctrl_addr[6:5] == 2'h1);
    we_message <= we && !wa && (ctrl_addr[6:5] == 2'h2);
//    we_timer[4:0] <=  {we_timer[3:0], we && !wa && (ctrl_addr[5:0]==6'h0)} ;
    we_period  <=      we && !wa && (ctrl_addr[6:0]==7'h0);
    we_bit_duration <= we && !wa && (ctrl_addr[6:0]==7'h1);
    we_bitHalfPeriod<= we && !wa && (ctrl_addr[6:0]==7'h2);
    we_config      <=  we && !wa && (ctrl_addr[6:0]==7'h3);
    we_config_imu  <=  we && !wa && (ctrl_addr[6:0]==7'h3) && di[ 2];
    we_config_gps  <=  we && !wa && (ctrl_addr[6:0]==7'h3) && di[ 7];
    we_config_msg  <=  we && !wa && (ctrl_addr[6:0]==7'h3) && di[13];
    we_config_syn  <=  we && !wa && (ctrl_addr[6:0]==7'h3) && di[15];
//    we_config_rst  <=  we_config && di[1];

    if (we_config_imu) config_imu_mclk[1:0] <= di_d[ 1:0]; // bits 1:0, 2 - enable slot[1:0]
    if (we_config_gps) config_gps_mclk[3:0] <= di_d[ 6:3]; // bits 6:3, 7 - enable - {ext,inver, slot[1:0]} slot==0 - disable
    if (we_config_msg) config_msg_mclk[4:0] <= di_d[12:8]; // bits 12:8,13 - enable - {invert,extinp[3:0]} extinp[3:0]=='hf' - disable
    if (we_config_syn) config_syn_mclk      <= di_d[  14]; // bit  14,  15 - enable
    if (we_config && di[1]) config_rst_mclk <= di[0]; // bit  16,  17 - enable

    if (we_config && di[6]) config_debug_mclk[3:0] <= di[5:2]; // bit  21:18,  22 - enable
    
    if (we_bitHalfPeriod) bitHalfPeriod_mclk[15:0]<=di_d[15:0];

    if      (we && wa) ctrl_addr[6:5] <= di[6:5];
    if      (we && wa) ctrl_addr[4:0] <= di[4:0];
    else if (we_d && (ctrl_addr[4:0]!=5'h1f)) ctrl_addr[4:0] <=ctrl_addr[4:0]+1; // no roll over, 
    
  end

  always @ (posedge xclk) begin
    bitHalfPeriod[15:0] <= bitHalfPeriod_mclk[15:0];
    config_imu_pre[1:0] <= config_imu_mclk[1:0];
    config_gps_pre[3:0] <= config_gps_mclk[3:0];
    config_msg_pre[4:0] <= config_msg_mclk[4:0];
    config_syn_pre      <= config_syn_mclk;
    config_rst_pre      <= config_rst_mclk;
    config_debug_pre[3:0] <= config_debug_mclk[3:0];

    config_imu[1:0] <= config_imu_pre[1:0];
    config_gps[3:0] <= config_gps_pre[3:0];
    config_msg[4:0] <= config_msg_pre[4:0];
    config_syn      <= config_syn_pre;
    config_rst      <= config_rst_pre;
    config_debug[3:0] <= config_debug_pre[3:0];

    enable_gps         <= (config_gps[1:0] != 2'h0) && !config_rst;
    enable_msg         <= (config_gps[3:0] != 4'hf) && !config_rst;
    enable_syn         <= config_syn && !config_rst;
    enable_timestamps  <= !config_rst;
  end

  always @ (posedge xclk) begin
    mux_data_source[15:0] <= channel[1]?(channel[0]?msg_data[15:0]:extts_data[15:0]):(channel[0]?nmea_data[15:0]:imu_data[15:0]);
    mux_rdy_source        <= channel[1]?(channel[0]?channel_ready[3]:channel_ready[2]):(channel[0]?channel_ready[1]:channel_ready[0]);
    mux_data_final[15:0]  <= ts_en? timestamps_rdata[15:0]:(mux_rdy_source?mux_data_source[15:0]:16'h0); // replace 16'h0 with some pattern to debug output
  end

imu_spi393 i_imu_spi ( .sclk(clk),  // system clock, negedge
                    .xclk(xclk),  // half frequency (80 MHz nominal)
                    .we_ra(we_imu), // write enable for registers to log (@negedge clk)
                    .we_div(we_bit_duration),// write enable for clock dividing(@negedge clk)
                    .we_period(we_period),// write enable for IMU cycle period(@negedge clk) 0 - disable, 1 - single, >1 - half bit periods
                    .wa(ctrl_addr[4:0]),    // write address for register (5 bits, @negedge clk)
                    .di(di[15:0]),    // 16?-bit data in  (di, not di_d)
                    .mosi(mosi),  // to IMU, bit 2 in J9
                    .miso(miso),  // from IMU, bit 3 on J9 
                    .config_debug(config_debug[3:0]),
                    .sda(sda),   // sda, shared with i2c, bit 1
                    .sda_en(sda_en), // enable sda output (when sda==0 and 1 cycle after sda 0->1)
                    .scl(scl),   // scl, shared with i2c, bit 0
                    .scl_en(scl_en), // enable scl output (when scl==0 and 1 cycle after sda 0->1)
//                    .sngl_wire(sngl_wire), // single wire clock/data for the 103695 rev A

                    .ts(timestamp_request[0]),    // timestamop request
                    .rdy(channel_ready[0]),    // data ready
                    .rd_stb(channel_next[0]), // data read strobe (increment address)
                    .rdata(imu_data[15:0])); // data out (16 bits)
/*
logs events from odometer (can be software triggered), includes 56-byte message written to the buffer
So it is possible to assert trig input (will request timestamp), write message by software, then
de-assert the trig input - message with the timestamp will be logged
fixed-length de-noise circuitry with latency 256*T(xclk) (~3usec)
*/
imu_message393 i_imu_message(.sclk(clk),   // system clock, negedge
                       .xclk(xclk),  // half frequency (80 MHz nominal)
                       .we(we_message),    // write enable for registers to log (@negedge sclk), with lower data half
                       .wa(ctrl_addr[3:0]),    // write address for register (4 bits, @negedge sclk)
                       .di(di[15:0]),    // 16-bit data in  multiplexed 
                       .en(enable_msg),    // enable module operation, if 0 - reset
                       .trig(message_trig),  // leading edge - sample time, trailing set rdy
                       .ts(timestamp_request[3]),    // timestamop request
                       .rdy(channel_ready[3]),    // data ready
                       .rd_stb(channel_next[3]), // data read strobe (increment address)
                       .rdata(msg_data[15:0])); // data out (16 bits)
/* logs frame synchronization data from other camera (same as frame sync) */
// ts_stb (mclk) -> trig)
imu_exttime393 i_imu_exttime(.xclk(xclk),  // half frequency (80 MHz nominal)
                       .en(enable_syn),    // enable module operation, if 0 - reset
                       .trig(ext_ts_stb[1]),  // external time stamp updated, single pulse @posedge xclk
                       .usec(ts_rcv_usec[19:0]),  // microseconds from external timestamp (should not chnage after trig for 10 xclk)
                       .sec(ts_rcv_sec[31:0]),   // seconds from external timestamp
                       .ts(timestamp_request[2]),    // timestamop request
                       .rdy(channel_ready[2]),    // data ready
                       .rd_stb(channel_next[2]), // data read strobe (increment address)
                       .rdata(extts_data[15:0])); // data out (16 bits)

imu_timestamps393 i_imu_timestamps (
                        .sclk(clk), // 160MHz, negedge            
                        .xclk(xclk), // 80 MHz, posedge
                        .rst(!enable_timestamps),  // reset (@posedge xclk)
                        .sec(sec[31:0]),  // running seconds (@negedge sclk)
                        .usec(usec[19:0]), // running microseconds (@negedge sclk)
                        .ts_rq(timestamp_request_long[3:0]),// requests to create timestamps (4 channels), @posedge xclk
                        .ts_ackn(timestamp_ackn[3:0]), // timestamp for this channel is stored
                        .ra({channel[1:0],timestamp_sel[1:0]}),   // read address (2 MSBs - channel number, 2 LSBs - usec_low, (usec_high ORed with channel <<24), sec_low, sec_high
                        .dout(timestamps_rdata[15:0]));// output data
rs232_rcv393 i_rs232_rcv (.xclk(xclk),           // half frequency (80 MHz nominal)
                       .bitHalfPeriod(bitHalfPeriod[15:0]),  // half of the serial bit duration, in xclk cycles
                       .ser_di(ser_di),              // rs232 (ttl) serial data in
                       .ser_rst(!enable_gps),        // reset (force re-sync)
                       .ts_stb(gps_ts_stb),          // strobe timestamp (start of message) (reset bit counters in nmea decoder)
                       .wait_just_pause(rs232_wait_pause),// may be used as reset for decoder
                       .start(rs232_start),          // serial character start (single pulse)
                       
                       .ser_do(ser_do),         // serial data out(@posedge xclk) LSB first!
                       .ser_do_stb(ser_do_stb),    // output data strobe (@posedge xclk), first cycle after ser_do becomes valid
//                       .debug(debug_state[4:0]),
                       .debug(debug_state[15:12]),
                       .bit_dur_cntr(debug_state[31:16]),
                       .bit_cntr(debug_state[11:7])
                       );
//  output [15:0] debug_state;
// reg [7:0] dbg_cntr;
//    assign debug_state[15:12]=3'b0;
    assign debug_state[6:0] = dbg_cntr [6:0];

 always @ (posedge xclk) begin
   if (!enable_gps) dbg_cntr[7:0] <= 8'h0;
//   else if (ser_do_stb) dbg_cntr[7:0] <= dbg_cntr[7:0]+1;
   else if (rs232_start) dbg_cntr[7:0] <= dbg_cntr[7:0]+1;
 end
nmea_decoder393 i_nmea_decoder (.sclk(clk),   // system clock, @negedge
                             .we(we_gps),     // registers write enable (@negedge sclk)
                             .wa(ctrl_addr[4:0]),     // registers write address
                             .wd(di_d[7:0]),     // write data
                             .xclk(xclk),   // 80MHz, posedge
                             .start(gps_ts_stb),  // start of the serial message
                             .rs232_wait_pause(rs232_wait_pause),// may be used as reset for decoder
                             .start_char(rs232_start),           // serial character start (single pulse)
                             .nmea_sent_start(nmea_sent_start),  // serial character start (single pulse)
                             .ser_di(ser_do), // serial data in (LSB first)
                             .ser_stb(ser_do_stb),// serial data strobe, single-cycle, first cycle after ser_di valid
                             .rdy(channel_ready[1]),    // encoded nmea data ready
                             .rd_stb(channel_next[1]), // encoded nmea data read strobe (increment address)
                             .rdata(nmea_data[15:0]), // encoded data (16 bits)
                             .ser_rst(!enable_gps),        // reset (now only debug register)
//                             .debug(debug_state[31:8])
//                             .debug(debug_state[15:8])
                             .debug()
                             );
                             

logger_arbiter393 i_logger_arbiter(.xclk(xclk), // 80 MHz, posedge
                                .rst(config_rst), // module reset
                                .ts_rq_in(timestamp_request[3:0]),      // in requests for timestamp (single-cycle - just leading edge )
                                .ts_rq(timestamp_request_long[3:0]),         // out request for timestamp, to timestmp module
                                .ts_grant(timestamp_ackn[3:0]),      // granted ts requests from timestamping module
                                .rdy(channel_ready[3:0]),           // channels ready (leading edge - became ready, trailing - no more data, use zero)
                                .nxt(channel_next[3:0]),           // pulses to modules to output next word
                                .channel(channel[1:0]),       // decoded channel number (2 bits)
                                .ts_sel(timestamp_sel[1:0]),        // select timestamp word to be output (0..3)
                                .ts_en(ts_en),         // 1 - use timestamp, 0 - channel data (or 16'h0 if !ready)
                                .dv(mux_data_valid),            // output data valid (from registered mux - 2 stage - first selects data and ready, second ts/data/zero)
                                .sample_counter(sample_counter));// number of 64-byte samples logged

buf_xclk_mclk16_393 i_buf_xclk_mclk16(.xclk(xclk), // posedge
                                  .mclk(clk), // posedge!
                                  .rst(config_rst),  // @posedge xclk
                                  .din(mux_data_final[15:0]),
                                  .din_stb(mux_data_valid),
                                  .dout(data_out[15:0]),
                                  .dout_stb(data_out_stb));

endmodule

