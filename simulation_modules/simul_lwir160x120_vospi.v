/*!
 * <b>Module:</b> simul_lwir160x120_vospi
 * @file simul_lwir160x120_vospi.v
 * @date 2019-03-30  
 * @author Andrey FIlippov
 *     
 * @brief simulates FLIR Lepton 3.0 output over VoSPI
 *
 * @copyright Copyright (c) 2019 Elphel, Inc .
 *
 * <b>License </b>
 *
 * simul_lwir160x120_vospi.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * simul_lwir160x120_vospi.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *
 * Additional permission under GNU GPL version 3 section 7:
 * If you modify this Program, or any covered work, by linking or combining it
 * with independent modules provided by the FPGA vendor only (this permission
 * does not extend to any 3-rd party modules, "soft cores" or macros) under
 * different license terms solely for the purpose of generating binary "bitstream"
 * files and/or simulating the code, the copyright holders of this Program give
 * you the right to distribute the covered work without those independent modules
 * as long as the source code for them is available from the FPGA vendor free of
 * charge, and there is no dependence on any encrypted modules for simulating of
 * the combined code. This permission applies to you if the distributed code
 * contains all the components and scripts required to completely simulate it
 * with at least one of the Free Software programs.
 */
`timescale 1ns/1ps

module  simul_lwir160x120_vospi # (
    parameter DATA_FILE =         "/data_ssd/nc393/elphel393/fpga-elphel/x393/input_data/pattern_160_120_14.dat",  //
    parameter WINDOW_WIDTH    =    160,  //
    parameter WINDOW_HEIGHT   =    120,  //
    parameter LWIR_GPIO_IN    = 4'b0000,
    
    parameter TELEMETRY       =      1,  // 0 - disabled, 1 - as header, 2 - as footer
    parameter FRAME_PERIOD    = 946969,  // 26.4 fps @25 MHz
    parameter SEGMENT_PERIOD  =  5100, // min 05063? // 10000,  // 236742,  // 26.4 fps @25 MHz
    parameter SEGMENTS_SEQ    =      8,  // 12 With ITAR
    
    parameter FRAME_DELAY     =    100,  // mclk period to start first frame 1
    parameter MS_PERIOD       =     25   // ahould actually be 25000  
)(
    input          mclk,
    input          mrst,  // active low 
    input          pwdn,  // active low
    input          spi_clk,
    input          spi_cs,
    output         spi_miso,
    input          spi_mosi,
    inout          gpio0,
    inout          gpio1,
    inout          gpio2,
    inout          gpio3, // may be used as segment sync (ready)
    input          i2c_scl,
    inout          i2c_sda,
    output         mipi_dp,   // not implemented
    output         mipi_dn,   // not implemented
    output         mipi_clkp, // not implemented
    output         mipi_clkn, // not implemented
    
    // telemetry data
    input   [15:0] telemetry_rev,
    input   [31:0] telemetry_status,
    input   [63:0] telemetry_srev,
    input   [15:0] telemetry_temp_counts,
    input   [15:0] telemetry_temp_kelvin,
    input   [15:0] telemetry_temp_last_kelvin,
    input   [31:0] telemetry_time_last_ms,
    input   [15:0] telemetry_agc_roi_top,
    input   [15:0] telemetry_agc_roi_left,
    input   [15:0] telemetry_agc_roi_bottom,
    input   [15:0] telemetry_agc_roi_right,
    input   [15:0] telemetry_agc_high,
    input   [15:0] telemetry_agc_low,
    input   [31:0] telemetry_video_format //???
    );
    localparam OUT_BITS =        16;
    localparam PACKET_PIXELS =   80;
    localparam PACKET_HEADER =    2;
    localparam PACKET_WORDS =    PACKET_PIXELS + PACKET_HEADER;
    localparam SEGMENT_PACKETS = 60; // w/o telemetry
    localparam SEGMENT_PACKETS_TELEMETRY = SEGMENT_PACKETS + ((TELEMETRY > 0)? 1 : 0);
    localparam FRAME_SEGMENTS =   4;
    localparam FRAME_PACKETS =        SEGMENT_PACKETS * FRAME_SEGMENTS;
    localparam FRAME_PACKETS_FULL =   FRAME_PACKETS + ((TELEMETRY==0) ? 0 : 4);
    localparam FRAMES =               2; // 2 frames in a ping-pong buffer 
    localparam FRAME_WORDS =          FRAME_SEGMENTS * (SEGMENT_PACKETS + ((TELEMETRY>0)?1 : 0)) * PACKET_WORDS;
    localparam SEGMENT_PACKETS_FULL = SEGMENT_PACKETS + ((TELEMETRY>0)?1 : 0);
    localparam SEGMENT_WORDS =        SEGMENT_PACKETS_FULL * PACKET_WORDS;
    localparam SEGMENTS_MIN =     4;  // minimal segments ready to be able to read
    localparam SEGMENTS_MAX =     6;  // maximum segments ready before sync is lost
        
    
    wire rst = !mrst;
    
    reg  [OUT_BITS-1:0] sensor_data[0 : WINDOW_WIDTH * WINDOW_HEIGHT - 1]; // SuppressThisWarning VEditor - Will be assigned by $readmem
    reg  [OUT_BITS-1:0] packed_data[0: FRAMES * FRAME_WORDS -1];
    reg  [OUT_BITS-1:0] packet_bad [0: PACKET_WORDS-1];

    wire [160*16-1:0] telemetry_a;
    wire [160*16-1:0] telemetry_b;

    // registers for copiing data to packet array
    
//'0xe7319'
//    reg            [19:0]  frame_dly_cntr; // delay till next frame start   
    reg            [19:0]  segment_dly_cntr; // delay till next frame segment
    reg                    frame_start;
    reg                    segment_start;
    reg            [ 3:0]  segments_cntr;
    wire           [ 3:0]  segment_id;
    
    reg                    copy_page;
//    reg                    copy_run;
//    wire                   copy_done;
    wire                   frame_done;
    reg                    segment_run;
    wire                   segment_done;
    
//    reg              [2:0] copy_segment; // 4 - copy average and telemetry
    reg              [7:0] copy_packet;       // number of a packet in a frame 240 image packets, then telemetry
    reg              [6:0] segment_packet;    // 60/61 packets
    
    reg              [6:0] copy_word;      // word number to copy in a packet (0..82), last one copies CRC to word 1
    reg                    copy_crc;
    wire                   copy_crc_w;
    wire             [7:0] copy_packet_full;
    wire             [7:0] copy_telemetry_packet; // only 2 LSB
//    wire             [7:0] copy_packet_segment;
    wire            [11:0] copy_packet_indx; // high bits are always 0
    wire             [3:0] copy_packet_ttt;
    
    reg             [15:0] copy_pxd;
    reg             [30:0] frame_sum;
    wire            [31:0] frame_average32;
    wire            [15:0] frame_average;
    reg             [15:0] copy_telemetry_d;
    reg             [15:0] copy_d;
    wire                   copy_pix_or_tel;
    wire                   copy_pix_only;
    wire                   copy_tel_only;
//    reg                    copy_pixels_r;
    reg                    copy_pixels_pix;
//    reg                    copy_pixels_tel;
    
    wire            [15:0] copy_din;
    wire            [ 6:0] copy_wa; // address in a packet where to write data
    wire            [15:0] copy_wa_full;
    wire            [15:0] crc_in;
    wire            [15:0] crc_out;
    reg                    en_avg; // write frame average value to telemetry
    reg             [31:0] frame_num;
    reg             [31:0] time_ms;
    reg             [31:0] ms_cntr;
    
    //----------------
    wire                   start_segm_rd;      // starting readout page, spi_clk domain
    wire                   start_segm_rd_mclk; // starting readout page, resync to mclk
    reg                    readout_page;          // readout page number
    reg             [ 1:0] readout_segment;    // actually just 2 (2 bits, but will use FRAME_SEGMENTS==4
    reg             [ 5:0] readout_packet;     // number of packet read out in a segment
    reg             [ 6:0] readout_word_indx;  // number of word in a readout packet   
    reg             [ 3:0] readout_bit;        // 0 - msb, 15 - lsb
    reg             [15:0] readout_sr_good;
    reg             [15:0] readout_sr_good_dbg; // no shift, just memory read
    reg             [15:0] readout_sr_bad;
    reg             [ 3:0] segments_ready;
    reg                    segment_av_mclk;       // segments avalable for readout
//    reg                    segment_av;            // segments avalable for readout
    reg                    sync_lost; 
    reg                    packet_sent;
//    reg                    packet_skipped; // sent invalid packet 
    reg                    packet_re_last;
    
    wire                   readout_last_segment;  // reading last segment in a frame
    wire                   readout_last_packet;   // reading last packet in a segment
    wire                   readout_last_word;     // reading last word in a packet
    wire                   readout_pre_last_bit;  // reading out pre-last bit
    wire                   readout_pre_first_bit; // reading out pre-first bit in a word
    reg                    readout_last_bit;     
    reg                    readout_first_bit = 1;
    wire            [15:0] readout_address;      // buffer readout address
//    wire                   readout_good_w ;       // should be valid at first negative transition of the spi_clk
    reg                    readout_good;          // reading out/sending valid packet
    wire                   readout_segment_done_w;
    reg                    readout_segment_done;
    assign readout_last_segment =   readout_segment == (FRAME_SEGMENTS - 1);
    assign readout_last_packet =    readout_packet == (SEGMENT_PACKETS_TELEMETRY -1);
    assign readout_last_word =      readout_word_indx == (PACKET_WORDS -1);
    assign readout_pre_last_bit =   readout_bit[3:0] == 14;
    assign readout_pre_first_bit =  readout_bit[3:0] == 15;
    
//    assign readout_segment_done_w = readout_last_packet && readout_last_word && readout_pre_last_bit;

    assign readout_segment_done_w = readout_last_packet && readout_last_word && readout_last_bit;
    
    assign readout_address = readout_word_indx +
                            (PACKET_WORDS *  readout_packet) +
                            (SEGMENT_WORDS * readout_segment) +
                            (FRAME_WORDS *   readout_page);
                            
//    assign readout_good_w = segment_av_mclk;                            
    assign spi_miso = readout_good ? readout_sr_good[15] : readout_sr_bad[15];
//    assign start_segm_rd = (readout_word_indx == 0) && readout_last_bit && !spi_cs; 
    assign start_segm_rd = readout_last_bit  && (readout_word_indx == 0) && readout_last_packet && !spi_cs && readout_good; 
    
//    wire            [ 2:0] copy_segment;

//946,969 '0xe7319'
      assign mipi_dp = 'bz;
      assign mipi_dn = 'bz;
      assign mipi_clkp = 'bz;
      assign mipi_clkn = 'bz;
      
      assign gpio0 = LWIR_GPIO_IN[0]?'bz: 0;
      assign gpio1 = LWIR_GPIO_IN[1]?'bz: 0;
      assign gpio2 = LWIR_GPIO_IN[2]?'bz: 0;
      assign gpio3 = LWIR_GPIO_IN[3]?'bz: 0;
      assign i2c_sda = 'bz;
      
      
//      assign copy_done =           copy_run && copy_crc && (copy_packet== (FRAME_PACKETS_FULL -1));
//      assign segment_done =        copy_run && copy_crc && (segment_packet== (SEGMENT_PACKETS_FULL -1));

//      assign copy_done =           segment_run && copy_crc && (copy_packet== (FRAME_PACKETS_FULL -1));
      assign frame_done =          segment_run && copy_crc && (copy_packet== (FRAME_PACKETS_FULL -1));
      assign segment_done =        segment_run && copy_crc && (segment_packet== (SEGMENT_PACKETS_FULL -1));


      assign segment_id =          (segments_cntr < 4) ? (segments_cntr +1) : 4'b0;
      
      assign copy_packet_full =    (copy_packet < FRAME_PACKETS)?(copy_packet + ((TELEMETRY == 1) ? 4 : 0)):(copy_packet - ((TELEMETRY == 1)?FRAME_PACKETS: 0)) ;
      
      assign copy_telemetry_packet = copy_packet - FRAME_PACKETS;      
//      assign copy_pix_or_tel =     copy_run && (copy_word < PACKET_PIXELS); //  && (copy_packet < FRAME_PACKETS);
      assign copy_pix_or_tel =     segment_run && (copy_word < PACKET_PIXELS); //  && (copy_packet < FRAME_PACKETS);
      assign copy_pix_only =       copy_pix_or_tel && (copy_packet < FRAME_PACKETS);
      assign copy_tel_only =       copy_pix_or_tel && (copy_packet >= FRAME_PACKETS);
//      assign copy_packet_segment = copy_packet_full / SEGMENT_PACKETS_TELEMETRY;  /// 
      assign copy_packet_indx =    copy_packet_full % SEGMENT_PACKETS_TELEMETRY; 
      
      assign copy_packet_ttt =     (copy_packet_indx == 20) ? segment_id: 4'b0; 
      
      assign crc_in =   (copy_word == 0) ? {4'b0,copy_packet_indx[11:0]}:(
                        (copy_word == 1) ?16'b0:copy_d[15:0]);

      assign copy_din = (copy_word == 0) ? {1'b0,copy_packet_ttt[2:0], copy_packet_indx[11:0]}:(
                        (copy_word == 1) ?16'bxx:(copy_crc? (crc_out): copy_d[15:0]));
                        
      assign copy_wa = copy_crc? 7'h01 : copy_word;                  

      assign copy_wa_full = copy_wa + (PACKET_WORDS * copy_packet_full) + (FRAME_WORDS * copy_page);
      
      assign copy_crc_w = copy_word == (PACKET_WORDS - 1); 
      
      assign frame_average32 = (frame_sum / (WINDOW_WIDTH * WINDOW_HEIGHT));
      assign frame_average = frame_average32[15:0];
      
`ifndef ROOTPATH
    `include "IVERILOG_INCLUDE.v"// SuppressThisWarning VEditor - maybe not used
    `ifndef ROOTPATH
        `define ROOTPATH "."
    `endif
`endif
integer i;
initial begin
// $readmemh({`ROOTPATH,"/input_data/sensor_16.dat"},sensor_data);
  $readmemh(DATA_FILE,sensor_data,0);
  //    reg  [OUT_BITS-1:0] packet_bad [0: PACKET_WORDS-1];
  packet_bad[0] = 'h0f00;
  packet_bad[1] = 'h5220; // calculate and put crc?
  for (i = 2; i < PACKET_WORDS; i = i+1) begin
    packet_bad[i] = 0;
  end
  packet_bad[1] = 'h5220; // calculate and put crc?
end
always @ (posedge mclk) begin
    if (rst || (ms_cntr == 0)) ms_cntr <= MS_PERIOD -1;
    else                       ms_cntr <=  ms_cntr - 1;

    if      (rst)              time_ms <= 0;
    else if ((ms_cntr == 0))   time_ms <=  time_ms + 1;

    //restarting frames
    if      (rst)              segment_dly_cntr <= FRAME_DELAY;
    else if (segment_start)    segment_dly_cntr <= SEGMENT_PERIOD;
    else                       segment_dly_cntr <= segment_dly_cntr - 1;
    
    segment_start <=  !rst && (segment_dly_cntr == 0);
    
    if      (rst || segment_done) segment_run <= 0;
    else if (segment_start)       segment_run <= 1;
    
    
    
//    if      (rst)              frame_dly_cntr <= FRAME_DELAY;
//    else if (frame_start)      frame_dly_cntr <= FRAME_PERIOD;
//    else                       frame_dly_cntr <= frame_dly_cntr - 1;
    
    
//    frame_start <= !rst && (frame_dly_cntr == 0);
    frame_start <=  !rst && (segment_dly_cntr == 0) && (segments_cntr[1:0] == 0);
    
    if      (rst)              frame_num <= 0;
    else if (frame_start)      frame_num <=  frame_num + 1;
    
    if      (rst)              copy_page <= 0;
//    else if (frame_start)      copy_page <= !copy_page;
    else if (frame_done)      copy_page <= !copy_page;

// remove copy_run completely?
//    if      (rst || copy_done) copy_run <= 0;
//    if      (rst || frame_done) copy_run <= 0;
//    else if (frame_start)       copy_run <= 1;
    
    copy_crc <= copy_word == (PACKET_WORDS - 1);
     
//    if (!copy_run || copy_crc) copy_word <= 0;
    if (!segment_run || copy_crc) copy_word <= 0;
    else                          copy_word <= copy_word + 1;
    
//    if      (!copy_run)               copy_packet <= 0;
//    else if (copy_crc)         copy_packet <= copy_packet + 1;
//    else if (copy_crc && segment_run) copy_packet <= copy_packet + 1;

    if      (rst || frame_done)        copy_packet <= 0;
    else if (copy_crc && segment_run)  copy_packet <= copy_packet + 1;


    
//    if       (rst || frame_start)  segment_packet <= 0;
//    else if (copy_run && copy_crc) segment_packet <= (copy_packet== (FRAME_PACKETS_FULL -1))? 0:  (segment_packet + 1);

    if         (rst || segment_start) segment_packet <= 0;
    else if (segment_run && copy_crc) segment_packet <= segment_packet + 1;

//    if (copy_run) packed_data[copy_wa_full] <= copy_din; // copy_d;
    if (segment_run) packed_data[copy_wa_full] <= copy_din; // copy_d;

    
    if (rst)                  segments_cntr <= 0;
    else if (segment_done)    segments_cntr <= (segments_cntr == (SEGMENTS_SEQ - 1)) ? 0: (segments_cntr + 1);
    
    
    if (copy_pix_only)         copy_pxd <= sensor_data[copy_packet * PACKET_PIXELS + copy_word];
    else                       copy_pxd <= 'bx;

    if (copy_tel_only)   copy_telemetry_d <= copy_telemetry_packet[1]?
                                             telemetry_b[(PACKET_PIXELS * (2 - copy_telemetry_packet[0])-copy_word - 1)*16 +: 16]:
                                             telemetry_a[(PACKET_PIXELS * (2 - copy_telemetry_packet[0])-copy_word - 1)*16 +: 16];
    else                 copy_telemetry_d <= 'bx;
    
    copy_d <= (copy_packet < FRAME_PACKETS) ? copy_pxd : copy_telemetry_d;
    
    copy_pixels_pix <= copy_pix_or_tel && (copy_packet < FRAME_PACKETS); 
    
    if      (frame_start)     frame_sum <= 0;
    
    else if (copy_pixels_pix) frame_sum <= frame_sum + copy_pxd;
    
    
//    en_avg <= copy_crc && (copy_packet == (FRAME_PACKETS - 1)); // 1 cycle after last pixel written
    en_avg <= copy_crc_w && (copy_packet == (FRAME_PACKETS - 1)); // 1 cycle after last pixel written
end

// readout, mclk part
always @ (posedge mclk) begin
    if      (rst)                                  segments_ready <= 0;
    else if ( segment_done && !start_segm_rd_mclk) segments_ready <= segments_ready + 1;
    else if (!segment_done &&  start_segm_rd_mclk) segments_ready <= segments_ready - 1;
    
    segment_av_mclk <= !rst && !sync_lost && (segments_ready >= SEGMENTS_MIN);
    
    
    if      (rst)                             sync_lost <= 0;
    else if (segments_ready >= SEGMENTS_MAX)  sync_lost <= 1; 
end

// readout, spi_clk part
always @ (posedge rst or negedge spi_clk) begin

    if      (rst)       readout_bit <= 0;
    else if (!spi_cs)   readout_bit <= readout_bit + 1;

    if      (rst)     readout_last_bit <= 0; 
    else if (!spi_cs) readout_last_bit <= readout_pre_last_bit;

    if      (rst)     readout_first_bit <= 1; 
    else if (!spi_cs) readout_first_bit <= readout_pre_first_bit;

    
    if (!spi_cs) begin
        if (readout_first_bit) begin
            readout_sr_good <= packed_data[readout_address];
            readout_sr_bad <=  packet_bad[readout_word_indx];
        end else begin
            readout_sr_good <= {readout_sr_good[14:0], 1'b0};
            readout_sr_bad <=  {readout_sr_bad[14:0],  1'b0};
        end
        if (readout_first_bit) readout_sr_good_dbg <=   packed_data[readout_address];
    end

    if      (rst)                         readout_word_indx <= 0;
    else if (!spi_cs && readout_last_bit) readout_word_indx <=packet_re_last ? 0 : (readout_word_indx + 1);
    
    if      (rst)   begin
        packet_re_last <= 0;
        packet_sent    <= 0;
//        packet_skipped <= 0;   
    end else if (!spi_cs)  begin
        packet_re_last <= readout_last_word && readout_pre_last_bit;
        packet_sent <=    readout_last_word && readout_pre_last_bit &&  readout_good;
//        packet_skipped <= readout_last_word && readout_pre_last_bit && !readout_good;
    end

    if      (rst)                    readout_packet <= 0;
    else if (!spi_cs && packet_sent) readout_packet <= readout_last_packet ? 0 : (readout_packet + 1);
    
    if      (rst)                                          readout_segment <= 0;
    else if (!spi_cs && packet_sent&& readout_last_packet) readout_segment <= readout_last_segment ? 0 : (readout_segment + 1);

    if      (rst)                                                                   readout_page <= 0;
    else if (!spi_cs && packet_sent && readout_last_packet && readout_last_segment) readout_page <= !readout_page;

    if      (rst)                                                      readout_good <= 0; 
    else if (!spi_cs && readout_first_bit && (readout_word_indx == 0)) readout_good <= segment_av_mclk || readout_good;
// WRONG!    
//    else if (segment_done)                                             readout_good <= 0; 
    else if (!spi_cs && readout_segment_done)                          readout_good <= 0;
     
    if (!spi_cs) readout_segment_done <= readout_segment_done_w;

//segment_av_mclk

end



    crc16_x16x12x5x0 crc16_x16x12x5x0_i (
        .clk    (mclk), // input
//        .srst   (!copy_run || copy_crc), // input
        .srst   (!segment_run || copy_crc), // input
        .en     (1'b1),                  // input
        .din    (crc_in), // input[15:0] 
        .dout   (crc_out) // output[15:0]
         
    );


    simul_lwir160x120_telemetry simul_lwir160x120_telemetry_i (
        .clk                       (mclk),                       // input
        .en                        (frame_start),                // input
        .en_avg                    (en_avg),                     // input
        .telemetry_rev             (telemetry_rev),              // input[15:0] 
        .telemetry_time            (time_ms),                    // input[31:0] 
        .telemetry_status          (telemetry_status),           // input[31:0] 
        .telemetry_srev            (telemetry_srev),             // input[63:0] 
        .telemetry_frame           (frame_num),                  // input[31:0] 
        .telemetry_mean            (frame_average),              // input[15:0] 
        .telemetry_temp_counts     (telemetry_temp_counts),      // input[15:0] 
        .telemetry_temp_kelvin     (telemetry_temp_kelvin),      // input[15:0] 
        .telemetry_temp_last_kelvin(telemetry_temp_last_kelvin), // input[15:0] 
        .telemetry_time_last_ms    (telemetry_time_last_ms),     // input[31:0] 
        .telemetry_agc_roi_top     (telemetry_agc_roi_top),      // input[15:0] 
        .telemetry_agc_roi_left    (telemetry_agc_roi_left),     // input[15:0] 
        .telemetry_agc_roi_bottom  (telemetry_agc_roi_bottom),   // input[15:0] 
        .telemetry_agc_roi_right   (telemetry_agc_roi_right),    // input[15:0] 
        .telemetry_agc_high        (telemetry_agc_high),         // input[15:0] 
        .telemetry_agc_low         (telemetry_agc_low),          // input[15:0] 
        .telemetry_video_format    (telemetry_video_format),     // input[31:0] 
        .telemetry_a               (telemetry_a),                // output[2559:0] reg 
        .telemetry_b               (telemetry_b)                 // output[2559:0] reg 
    );

       pulse_cross_clock pulse_cross_clock_start_segm_i (
            .rst         (rst),                  // input extended to include sensor reset and rst_mmcm
            .src_clk     (!spi_clk),             // input
            .dst_clk     (mclk),                 // input
            .in_pulse    (start_segm_rd),                  // input
            .out_pulse   (start_segm_rd_mclk),              // output
            .busy() // output
        );


endmodule




/*
// Most significant bit first (big-endian)
  // x^16+x^12+x^5+1 = (1) 0001 0000 0010 0001 = 0x1021
  function crc(byte array string[1..len], int len) {
     rem := 0
     // A popular variant complements rem here
      for i from 1 to len {
         rem  := rem xor (string[i] leftShift (n-8))   // n = 16 in this example
          for j from 1 to 8 {   // Assuming 8 bits per byte
              if rem and 0x8000 {   // if leftmost (most significant) bit is set
                 rem  := (rem leftShift 1) xor 0x1021
             } else {
                 rem  := rem leftShift 1
             }
             rem  := rem and 0xffff      // Trim remainder to 16 bits
         }
     }
     // A popular variant complements rem here
      return rem
 }

*/

