/*******************************************************************************
 * Module: sens_gamma
 * Date:2015-05-24  
 * Author: andrey     
 * Description: table based piecewise-linear conversion of 16 -> 8 bit data
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * sens_gamma.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  sens_gamma.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  sens_gamma #(
    parameter SENS_GAMMA_ADDR =        'h338,
    parameter SENS_GAMMA_ADDR_MASK =   'h3fc,
    parameter SENS_GAMMA_CTRL =        'h0,
//    parameter SENS_GAMMA_STATUS =      'h1,
    parameter SENS_GAMMA_TADDR =       'h2,
    parameter SENS_GAMMA_TDATA =       'h3, // 1.. 2^16, 0 - use HACT
//    parameter SENS_GAMMA_STATUS_REG =  'h32
    parameter    SENS_GAMMA_MODE_WIDTH = 5, // does not include trig
    parameter    SENS_GAMMA_MODE_BAYER = 0,
    parameter    SENS_GAMMA_MODE_PAGE =  2,
    parameter    SENS_GAMMA_MODE_EN =    3,
    parameter    SENS_GAMMA_MODE_REPET = 4,
    parameter    SENS_GAMMA_MODE_TRIG =  5
) (
    input         rst,
    input         pclk,   // global clock input, pixel rate (96MHz for MT9P006)
    //input         en,     //    @(posedge pclk)      // Enable. Should go active before or with the first hact going active.
                                       // when low will also reset MSB of addresses - buffer page for ping-pong access.
                                       // SDRAM ch1 should be enabled earler to have data ready in the buffer
                                       // When going low will mask input hact, finish pending data->SDRAM and quit
                                       // So normal sequence is:
                                       //   1 - program (end enable) SDRAM channels 0 and 1, channel 1 will start reading
                                       //   2 - wait for frame sync and enable "en"
                                       //   3 (optional) - after frame is over (before the first hact of the next one)
                                       //      turn "en" off. If needed to restart - go to step 1 to keep buffer pages in sync.
    
    input  [15:0] pxd_in, //    @(posedge pclk)
    input         hact_in,
    input         sof_in,    // start of frame, single pclk, input
    input         eof_in,   // end of frame
    input         trig_in,  // external trigger to process a single frame. May be unused (grounded) as there
                            // is a software trigger option implemented
    output [7:0]  pxd_out,
    output        hact_out,
    output        sof_out,    // start of frame, single pclk, output
    output        eof_out,   // end of frame

    // programming interface
    input         mclk,        // global clock, half DDR3 clock, synchronizes all I/O through the command port
    input   [7:0] cmd_ad,      // byte-serial command address/data (up to 6 bytes: AL-AH-D0-D1-D2-D3 
    input         cmd_stb     // strobe (with first byte) for the command a/d
/*    
    output  [7:0] status_ad,   // status address/data - up to 5 bytes: A - {seq,status[1:0]} - status[2:9] - status[10:17] - status[18:25]
    output        status_rq,   // input request to send status downstream
    input         status_start // Acknowledge of the first status packet byte (address)
*/    
);
    wire    [1:0] cmd_a;
    wire   [31:0] cmd_data;
    wire          cmd_we;
//    wire          set_status_w;
    wire          set_ctrl_w;
    wire          set_taddr_w;
    wire          set_tdata_w;
    reg    [10:0] taddr;
    reg [SENS_GAMMA_MODE_WIDTH-1:0] mode=0;
    reg [SENS_GAMMA_MODE_WIDTH-1:0] mode_mclk=0;
    wire    [1:0] bayer;
    wire          table_page; //part of the mode register
    wire          en_input;
    wire          repet_mode;
    
    
    reg           bayer_nset; // set color to bayer (start of frame up to first hact) when zero
    wire          sync_bayer; // at the beginning of the line - sync color to bayer
    reg     [1:0] color; // for selecting page in a gamma table
    reg           bayer0_latched; // latch bayer[0] at the beginning of first line
//    reg           hact_m;
    reg     [3:0] hact_d; // combine sevaral delays?
//    reg           en_d;
    reg     [7:0] cdata;   //8-bit pixel data after "curves"
// modified table data to increase precision. table_base[9:0] is now 10 bits (2 extra).
// The 10-bit interpolation will be rounded to 8 bits at the very last stage
// 8 bit table_diff will be "floating point" with the following format
// now "signed" is 2's complement, was sign, abs() before

    wire    [7:0] table_diff_w; // 8 msbs in table word - msb - sign (0 plus, 1 - minus), other 7 bits - +/-127 difference to the next value
    wire    [9:0] table_base_w; // 10 lsbs in the table - base value, will be corrected using table_diff and input data lsbs (2 for now)
    wire   [35:0] table_mult;
    
// register decoded memory output
    reg     [9:0] table_base;
    reg    [10:0] table_diff;
    reg    [17:7] table_mult_r;
    reg    [ 9:0] table_base_r;
    
    wire    [9:0] interp_data;
    wire    [7:0] pxd_in_d2;
    reg     [7:0] pxd_in_r3; // register to be absorbed in mpy
    
    reg           vblank;    // from sof to first hact
    reg           pend_trig; // pending trigger (if trig came outside of vblank 
    wire          sof_masked;
    reg           frame_run;
    wire          trig_soft;
    wire          trig;

    assign        pxd_out = cdata;
    assign        hact_out = hact_d[3];
    
    assign set_ctrl_w =   cmd_we && (cmd_a == SENS_GAMMA_CTRL );
//    assign set_status_w = cmd_we && (cmd_a == SENS_GAMMA_STATUS );
    assign set_taddr_w =  cmd_we && (cmd_a == SENS_GAMMA_TADDR );
    assign set_tdata_w =  cmd_we && (cmd_a == SENS_GAMMA_TDATA );
    
/*
    assign bayer =        mode[1:0];
    assign table_page =   mode[2]; // TODO: re-assign?
    assign en_input =     mode[3]; 
    assign repet_mode =   mode[4]; // TODO: re-assign?
    parameter    SENS_GAMMA_MODE_WIDTH = 5, // does not include trig
    parameter    SENS_GAMMA_MODE_BAYER = 0,
    parameter    SENS_GAMMA_MODE_PAGE =  2,
    parameter    SENS_GAMMA_MODE_EN =    3,
    parameter    SENS_GAMMA_MODE_REPET = 4,
    parameter    SENS_GAMMA_MODE_TRIG =  5

*/    
    assign bayer =        mode[SENS_GAMMA_MODE_BAYER +: 2];
    assign table_page =   mode[SENS_GAMMA_MODE_PAGE]; // TODO: re-assign?
    assign en_input =     mode[SENS_GAMMA_MODE_EN]; 
    assign repet_mode =   mode[SENS_GAMMA_MODE_REPET]; // TODO: re-assign?
    
    assign sync_bayer=hact_d[1] && ~hact_d[2];
    assign interp_data[9:0] = table_base_r[9:0]+table_mult_r[17:8]+table_mult_r[7]; //round
    assign table_mult=table_diff*{1'b0,pxd_in_r3[7:0]}; // 11 bits, signed* 9 bits, positive
    
    assign sof_masked= sof_in && (pend_trig || repet_mode) && en_input;
    assign trig = trig_in || trig_soft;
    always @ (posedge rst or posedge mclk) begin
        if      (rst)         taddr <= 0;
        else if (set_taddr_w) taddr <= cmd_data[10:0];
        else if (set_tdata_w) taddr <= taddr + 1;
        if      (rst)         mode_mclk <= 0;
        else if (set_ctrl_w)  mode_mclk <= cmd_data[SENS_GAMMA_MODE_WIDTH-1:0];
    end 
//    reg           vblank;    // from sof to first hact
//    reg           pend_trig; // pending trigger (if trig came outside of vblank 
//SENS_GAMMA_MODE_TRIG    
    always @ (posedge rst or posedge pclk) begin
        if (rst) begin
            mode <= 0;
//            hact_m <= 0;
//            en_d   <= 0;
            hact_d[3:0] <= 0;
            bayer_nset <= 0;
            bayer0_latched <= 0;
            color[1:0] <= 0;
            cdata[7:0] <= 0;
            vblank     <= 0;  // from sof to first hact
            pend_trig  <= 0; // pending trigger (if trig came outside of vblank
            frame_run <= 0; 
            
        end else begin
            mode <= mode_mclk;
//            hact_m <= hact_in && en;
//            en_d   <= en;
            hact_d[3:0] <= {hact_d[2:0],hact_in};
            bayer_nset <= frame_run && (bayer_nset || hact_in);
            bayer0_latched <= bayer_nset? bayer0_latched:bayer[0];
            color[1:0] <= { bayer_nset? (sync_bayer ^ color[1]):bayer[1] ,
                           (bayer_nset &&(~sync_bayer))?~color[0]:bayer0_latched };
            pxd_in_r3 <= pxd_in_d2;
            cdata[7:0] <= interp_data[9:2];
            vblank <= sof_in || (vblank && !hact_in);
            pend_trig <= (trig && !vblank) || (pend_trig && !sof_in);  
            frame_run <= sof_masked || (frame_run && !eof_in);
        end
        
        
    end
    
  always @ (posedge pclk) begin
    table_base[9:0]  <= table_base_w[9:0];
    table_diff[10:0] <= table_diff_w[7]?
                          {table_diff_w[6:0],4'b0}:
                          {{4{table_diff_w[6]}},table_diff_w[6:0]}; 
    table_mult_r[17:7] <= table_mult[17:7];
    table_base_r[ 9:0] <= table_base[ 9:0];
  end
    
    
    cmd_deser #(
        .ADDR        (SENS_GAMMA_ADDR),
        .ADDR_MASK   (SENS_GAMMA_ADDR_MASK),
        .NUM_CYCLES  (6),
        .ADDR_WIDTH  (2),
        .DATA_WIDTH  (32)
    ) cmd_deser_sens_io_i (
        .rst         (rst), // input
        .clk         (mclk), // input
        .ad          (cmd_ad), // input[7:0] 
        .stb         (cmd_stb), // input
        .addr        (cmd_a), // output[15:0] 
        .data        (cmd_data), // output[31:0] 
        .we          (cmd_we) // output
    );
/*
    status_generate #(
        .STATUS_REG_ADDR(SENS_GAMMA_STATUS_REG),
        .PAYLOAD_BITS(15) // STATUS_PAYLOAD_BITS)
    ) status_generate_sens_io_i (
        .rst        (rst), // input
        .clk        (mclk), // input
        .we         (set_status_w), // input
        .wd         (cmd_data[7:0]), // input[7:0] 
        .status     (status), // input[25:0] 
        .ad         (status_ad), // output[7:0] 
        .rq         (status_rq), // output
        .start      (status_start) // input
    );
*/
    dly_16 #(
        .WIDTH(8)
    ) dly_16_pxd_i (
        .clk (pclk),        // input
        .rst (rst),         // input
        .dly (2),           // input[3:0] 
        .din (pxd_in[7:0]), // input[0:0] 
        .dout(pxd_in_d2)    // output[0:0] 
    );

    dly_16 #(
        .WIDTH(2)
    ) dly_16_sof_eof_i (
        .clk (pclk),        // input
        .rst (rst),         // input
        .dly (3),           // input[3:0] 
        .din ({eof_in, sof_masked}), // input[0:0] 
        .dout({eof_out,sof_out})    // output[0:0] 
    );
    pulse_cross_clock trig_soft_i (
        .rst       (rst),
        .src_clk   (mclk),
        .dst_clk   (pclk),
        .in_pulse  (cmd_data[SENS_GAMMA_MODE_TRIG] && set_ctrl_w),
        .out_pulse (trig_soft),
        .busy      ());
    

//sof_masked
    ramp_var_w_var_r #(
        .REGISTERS    (1), // try to delay i2c_byte_start by one more cycle
        .LOG2WIDTH_WR (4),
        .LOG2WIDTH_RD (4)
    ) i_gamma_table (
        .rclk         (pclk), // input
        .raddr        ({table_page,color[1:0],pxd_in[15:8]}), // input[11:0] 
        .ren          (hact_in), // input TODO: add "en"?
        .regen        (hact_d[0]), // input
        .data_out     ({table_diff_w[7:0],table_base_w[9:0]}), // output[7:0] 
        .wclk         (mclk), // input
        .waddr        (taddr), // input[9:0] 
        .we           (set_tdata_w), // input
        .web          (8'hff), // input[7:0] 
        .data_in      (cmd_data[17:0]) // input[31:0] 
    );


endmodule

