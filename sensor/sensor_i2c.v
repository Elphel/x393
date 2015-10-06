/*******************************************************************************
 * Module: sensor_i2c
 * Date:2015-05-10  
 * Author: Andrey Filippov     
 * Description: i2c write-only sequencer to control image sensor
 *
 * Copyright (c) 2015 Elphel, Inc.
 * sensor_i2c.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  sensor_i2c.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  sensor_i2c#(
    parameter SENSI2C_ABS_ADDR =       'h410,
    parameter SENSI2C_REL_ADDR =       'h420,
    parameter SENSI2C_ADDR_MASK =      'h7f0, // both for SENSI2C_ABS_ADDR and SENSI2C_REL_ADDR
    parameter SENSI2C_CTRL_ADDR =      'h402,
    parameter SENSI2C_CTRL_MASK =      'h7fe,
    parameter SENSI2C_CTRL =           'h0,
    parameter SENSI2C_STATUS =         'h1,
    parameter SENSI2C_STATUS_REG =     'h20,
    // Control register bits
    parameter SENSI2C_CMD_RESET =       14, // [14]   reset all FIFO (takes 16 clock pulses), also - stops i2c until run command
    parameter SENSI2C_CMD_RUN =         13, // [13:12]3 - run i2c, 2 - stop i2c (needed before software i2c), 1,0 - no change to run state
    parameter SENSI2C_CMD_RUN_PBITS =    1,
    parameter SENSI2C_CMD_BYTES =       11, // if 1, use [10:9] to set command bytes to send after slave address (0..3)
    parameter SENSI2C_CMD_BYTES_PBITS =  2,
    parameter SENSI2C_CMD_DLY =          8, // [7:0]  - duration of quater i2c cycle (if 0, [3:0] control SCL+SDA)
    parameter SENSI2C_CMD_DLY_PBITS =    8,

    parameter SENSI2C_CMD_SCL =         16, // [17:16] : 0: NOP, 1: 1'b0->SCL, 2: 1'b1->SCL, 3: 1'bz -> SCL 
    parameter SENSI2C_CMD_SCL_WIDTH =    2,
    parameter SENSI2C_CMD_SDA =         18, // [19:18] : 0: NOP, 1: 1'b0->SDA, 2: 1'b1->SDA, 3: 1'bz -> SDA,  
    parameter SENSI2C_CMD_SDA_WIDTH =    2
)(
    input         mrst,         // @ posedge mclk
    input         mclk,         // global clock, half DDR3 clock, synchronizes all I/O through the command port
    input   [7:0] cmd_ad,       // byte-serial command address/data (up to 6 bytes: AL-AH-D0-D1-D2-D3 
    input         cmd_stb,      // strobe (with first byte) for the command a/d
// status will {frame_num[3:0],busy,sda,scl} - read outside of this module?
// Or still use status here but program it in other bits?
// increase address range over 5 bits?
// borrow 0x1e?    
    output  [7:0] status_ad,   // status address/data - up to 5 bytes: A - {seq,status[1:0]} - status[2:9] - status[10:17] - status[18:25]
    output        status_rq,   // input request to send status downstream
    input         status_start,// Acknowledge of the first status packet byte (address)
    input         frame_sync,  // @posedge mclk increment/reset frame number 
//    input         frame_0,     // reset frame number to zero - can be done by soft reset before first enabled frame
//    output        busy,        // busy (do not use software i2i)
    input         scl_in,      // i2c SCL input
    input         sda_in,      // i2c SDA input
    output        scl_out,         // i2c SCL output
    output        sda_out,         // i2c SDA output
    output        scl_en,      // i2c SCL enable
    output        sda_en       // i2c SDA enable
//    output        busy,
//    output  [3:0] frame_num

);
// TODO: Make sure that using more than 64 commands will just send them during next frame, not loose?
// 0x0..0xf write directly to the frame number [3:0] modulo 16, except if you write to the frame
//          "just missed" - in that case data will go to the current frame.
// 0x10 - write i2c commands to be sent ASAP
// 0x11 - write i2c commands to be sent after the next frame starts 
// ... 
// 0x1e - write i2c commands to be sent after the next 14 frames start
// 0x1e - program status? Or
// 0x1f - control register:
//     [14] -   reset all FIFO (takes 16 clock pulses), also - stops i2c until run command
//     [13:12] - 3 - run i2c, 2 - stop i2c (needed before software i2c), 1,0 - no change to run state
//     [11] -   if 1, use [10:9] to set command bytes to send after slave address (0..3)
//     [10:9] - number of bytes to send, valid if [11] is set
//     [8]    - set duration of quarter i2c cycle in system clock cycles - nominal value 100 (0x64)
//     [7:0]  - duration of quater i2c cycle (applied if [8] is set)

     wire           we_abs;
     wire           we_rel;
     wire           we_cmd;
     wire           wen;
     wire    [31:0] di;
     wire     [3:0] wa; 
//     wire           busy;        // busy (do not use software i2i)
     
     
//    reg    [4:0]  wen_d; // [0] - not just fifo, but any PIO writes, [1] and next - filtered for FIFO only
//     reg    [3:0]  wen_d; // [0] - not just fifo, but any PIO writes, [1] and next - filtered for FIFO only
//     reg    [3:0]  wad; 
     reg   [31:0]  di_r; // 32 bit command takes 6 cycles, so di_r can hold data for up to this long
//     reg   [15:0]  di_1;
//     reg   [15:0]  di_2;
//     reg   [15:0]  di_3;
     reg    [3:0]  wpage0;     // FIFO page where ASAP writes go
     reg    [3:0]  wpage_prev;     // unused page, currently being cleared
     reg    [3:0]  page_r;     // FIFO page where current i2c commands are taken from
     
     reg    [3:0]  wpage_wr;    // FIFO page where current write goes (reading from write address) 
     reg    [1:0]  wpage0_inc; // increment wpage0 (after frame sync or during reset)
     reg           reset_cmd;
     reg           dly_cmd;
     reg           bytes_cmd;
     reg           run_cmd;
     reg           reset_on;   // reset FIFO in progress
     reg    [1:0]  i2c_bytes;
     reg    [7:0]  i2c_dly;
     reg           i2c_enrun;     // enable i2c
     reg           we_fifo_wp; // enable writing to fifo write pointer memory
     reg           req_clr;    // request for clearing fifo_wp (delay frame sync if previous is not yet sent out), also used for clearing all
//     wire          is_ctl= (wad[3:0]==4'hf);
//     wire          is_abs= (wad[3]==0);
     wire          pre_wpage0_inc; // ready to increment
     
     wire   [3:0]  frame_num=wpage0[3:0];
//fifo write pointers (dual port distributed RAM)
     reg    [5:0]  fifo_wr_pointers_ram [0:15]; // dual ported read?
     wire   [5:0]  fifo_wr_pointers_outw; // pointer dual-ported RAM - write port out, valid next after command
     wire   [5:0]  fifo_wr_pointers_outr; // pointer dual-ported RAM - read port out

     reg    [5:0]  fifo_wr_pointers_outw_r;
     reg    [5:0]  fifo_wr_pointers_outr_r;
// command i2c fifo (RAMB16_S9_S18)
     reg    [9:0]  i2c_cmd_wa; // wite address for the current pair of 16-bit data words - changed to a single 32-bit word
                               // {page[3:0],word[5:0],MSW[0]}
     reg           i2c_cmd_we; // write enable to blockRAM

     reg    [1:0]  page_r_inc; // increment page_r[2:0]; - signal and delayed version
     reg    [5:0]  rpointer;    // FIFO read pointer for current page

     reg           i2c_start; // initiate i2c register write sequence
     reg           i2c_run;   // i2c sequence is in progress
     reg           i2c_done;  // i2c sequence is over
     reg    [1:0]  bytes_left; // bytes left to send after this one
     reg    [1:0]  byte_number;  // byte number to send next (3-2-1-0)
     reg    [1:0]  byte_sending; // byte number currently sending (3-2-1-0)
     reg    [5:0]  i2c_state;  // 0x2b..0x28 - sending start, 0x27..0x24 - stop, 0x23..0x4 - data, 0x03..0x00 - ACKN
     reg    [7:0]  dly_cntr;   // bit delay down counter


     reg           scl_hard;
     reg           sda_hard;
     reg           sda_en_hard;
//     reg           wen_i2c_soft; // write software-contrlolles SDA, SCL state
     reg           scl_en_soft;  // software i2c control signals (used when i2c controller is disabled)
     reg           scl_soft;
     reg           sda_en_soft;
     reg           sda_soft;

    wire   [7:0]  i2c_data;
     reg    [8:0]  i2c_sr;
     reg           i2c_dly_pre_over; 
     wire          i2c_dly_pre2_over;
     reg           i2c_dly_over;
     wire          i2c_startseq_last=(i2c_state[5:0]==6'h28);
     wire          i2c_stopseq_last= (i2c_state[5:0]==6'h24);
     wire          i2c_dataseq_last= (i2c_state[5:0]==6'h00);
     wire          i2c_bit_last    = (i2c_state[1:0]==2'h0);
     wire          i2c_is_ackn     = (i2c_state[5:2]==4'h0);
     wire          i2c_is_start    = i2c_state[5] && i2c_state[3];
     wire          i2c_is_stop     = i2c_state[5] && i2c_state[2];
     wire          i2c_is_data     = !i2c_state[5] || (!i2c_state[3] && !i2c_state[2]); // including ackn

//   reg           i2c_startseq_done; // last cycle of start sequence
     reg           i2c_dataseq_done;  // last cycle of each byte sequence
//   reg           i2c_dataseq_all_done; // last cycle of the last byte sequence
     reg    [2:0]  i2c_byte_start;
     reg           i2c_sr_shift;
     reg           i2c_stop_start;
     reg           sda_0;
     reg           scl_0;
     reg           busy;
     reg    [3:0]  busy_cntr;
     assign  i2c_dly_pre2_over=(dly_cntr[7:0]==8'h2);
     
     wire          set_ctrl_w;
     wire          set_status_w;

     reg            [1:0] wen_r;
//     reg            [1:0] wen_fifo;
     reg            wen_fifo; // [1] was not used - we_fifo_wp was used instead

     
     assign set_ctrl_w = we_cmd && ((wa & ~SENSI2C_CTRL_MASK) == SENSI2C_CTRL );// ==0
     assign set_status_w = we_cmd && ((wa & ~SENSI2C_CTRL_MASK) == SENSI2C_STATUS );// ==0
     assign          scl_out=i2c_run?    scl_hard:    scl_soft ;
     assign          sda_out=i2c_run?    sda_hard:    sda_soft ;
     assign          scl_en=i2c_run? 1'b1:        scl_en_soft  ;
     assign          sda_en=i2c_run? sda_en_hard: sda_en_soft ;
     assign  pre_wpage0_inc = (!wen && !(|wen_r) && !wpage0_inc[0]) && (req_clr || reset_on) ;

     assign  fifo_wr_pointers_outw = fifo_wr_pointers_ram[wpage_wr[3:0]]; // valid next after command
     assign  fifo_wr_pointers_outr = fifo_wr_pointers_ram[page_r[3:0]];
     
     
//    wire           we_abs;
//    wire           we_rel;
//    wire           we_cmd;
//    wire    [15:0] di;
//    wire     [3:0] wa; 

     assign         wen=set_ctrl_w || we_rel || we_abs; //remove set_ctrl_w?
    reg alive_fs;
    always @ (posedge mclk) begin
        if    (set_status_w) alive_fs <= 0;
        else if (frame_sync) alive_fs <= 1;
    end
    

    cmd_deser #(
        .ADDR        (SENSI2C_ABS_ADDR),
        .ADDR_MASK   (SENSI2C_ADDR_MASK),
        .NUM_CYCLES  (6),
        .ADDR_WIDTH  (4),
        .DATA_WIDTH  (32),
        .ADDR1       (SENSI2C_REL_ADDR),
        .ADDR_MASK1  (SENSI2C_ADDR_MASK),
        .ADDR2       (SENSI2C_CTRL_ADDR),
        .ADDR_MASK2  (SENSI2C_CTRL_MASK)
    ) cmd_deser_sens_i2c_i (
        .rst         (1'b0), // rst), // input
        .clk         (mclk), // input
        .srst        (mrst), // input
        .ad          (cmd_ad), // input[7:0] 
        .stb         (cmd_stb), // input
        .addr        (wa), // output[15:0] 
        .data        (di), // output[31:0] 
        .we          ({we_cmd,we_rel,we_abs}) // output
    );

    status_generate #(
        .STATUS_REG_ADDR(SENSI2C_STATUS_REG),
        .PAYLOAD_BITS(7+3) // STATUS_PAYLOAD_BITS)
    ) status_generate_sens_i2c_i (
        .rst        (1'b0), // rst), // input
        .clk        (mclk), // input
        .srst       (mrst), // input
        .we         (set_status_w), // input
        .wd         (di[7:0]), // input[7:0] 
        .status     ({reset_on, req_clr, alive_fs,busy, frame_num, sda_in, scl_in}), // input[25:0] 
        .ad         (status_ad), // output[7:0] 
        .rq         (status_rq), // output
        .start      (status_start) // input
    );
     
    always @ (posedge mclk) begin
        if (wen) di_r <= di; // 32 bit command takes 6 cycles, so di_r can hold data for up to this long
        wen_r    <= {wen_r[0],wen}; // is it needed?      
//        wen_fifo <= {wen_fifo[0],we_rel || we_abs};      
        wen_fifo <= we_rel || we_abs;              
         
// signals related to writing to i2c FIFO
// delayed versions of address, data write strobe
//       if (wen)   wad [ 3:0] <= wa[ 3:0];
//       if (wen || wen_d[0]) di_1[15:0] <= di[15:0];
//       di_2[15:0] <= di_1[15:0];
//       di_3[15:0] <= di_2[15:0];
//      wen_d[4:0] <= {wen_d[3:1],wen_d[0] && !is_ctl,wen};
//        wen_d[3:0] <= {wen_d[2:1],wen_d[0] && !is_ctl,wen};
// software i2c signals     
//        wen_i2c_soft <= wen_d[0] && is_ctl;

// decoded commands, valid next cycle after we_*     
        reset_cmd <=  set_ctrl_w && di[SENSI2C_CMD_RESET];
        run_cmd   <=  set_ctrl_w && di[SENSI2C_CMD_RUN];
        bytes_cmd <=  set_ctrl_w && di[SENSI2C_CMD_BYTES];
        dly_cmd   <=  set_ctrl_w && di[SENSI2C_CMD_DLY];

// direct i2c control, valid 1 cycle after we_*
        if      (i2c_run)           scl_en_soft <= 1'b0;
        else if (set_ctrl_w && !di[SENSI2C_CMD_DLY] && |di[SENSI2C_CMD_SCL +: SENSI2C_CMD_SCL_WIDTH])
                                    scl_en_soft <= (di[SENSI2C_CMD_SCL +: SENSI2C_CMD_SCL_WIDTH] != 2'h3); 
        if      (i2c_run)           scl_soft <= 1'b0;
        else if (set_ctrl_w && !di[SENSI2C_CMD_DLY] && |di[SENSI2C_CMD_SCL +: SENSI2C_CMD_SCL_WIDTH])
                                    scl_soft <= (di[SENSI2C_CMD_SCL +: SENSI2C_CMD_SCL_WIDTH] == 2'h2); 
        if      (i2c_run)           sda_en_soft <= 1'b0;
        else if (set_ctrl_w && !di[SENSI2C_CMD_DLY] && |di[SENSI2C_CMD_SDA +: SENSI2C_CMD_SDA_WIDTH])
                                    sda_en_soft <= (di[SENSI2C_CMD_SDA +: SENSI2C_CMD_SDA_WIDTH] != 2'h3); 
        if      (i2c_run)           sda_soft <= 1'b0;
        else if (set_ctrl_w && !di[SENSI2C_CMD_DLY] && |di[SENSI2C_CMD_SDA +: SENSI2C_CMD_SDA_WIDTH])
                                    sda_soft <= (di[SENSI2C_CMD_SDA +: SENSI2C_CMD_SDA_WIDTH] == 2'h2); 
    
// setting i2c control parameters, valid 2 cycles after we_*       
        if (bytes_cmd) i2c_bytes[1:0] <= di_r[SENSI2C_CMD_BYTES - 1 -: SENSI2C_CMD_BYTES_PBITS]; //[10:9];
        if (dly_cmd)   i2c_dly[7:0]   <= di_r[SENSI2C_CMD_DLY - 1 -: SENSI2C_CMD_DLY_PBITS]; //[ 7:0];

        if    (reset_cmd)         i2c_enrun <= 1'b0;
        else if (run_cmd)         i2c_enrun <= di_r[SENSI2C_CMD_RUN - 1 -: SENSI2C_CMD_RUN_PBITS]; // [12];

// write pointer memory
      wpage0_inc <= {wpage0_inc[0],pre_wpage0_inc};
      // reset pointers in all 16 pages:      
      reset_on <= reset_cmd  || (reset_on && !(wpage0_inc[0] && ( wpage0[3:0] == 4'hf)));
      // request to clear pointer(s)? for one page - during reset or delayed frame sync (if previous was not finished)
      req_clr  <= frame_sync || (req_clr && !wpage0_inc[0]);

      if      (reset_cmd)     wpage0 <= 0;
//      else if (frame_0)    wpage0 <= 0;
      else if (wpage0_inc[0]) wpage0<=wpage0+1;
      
      if      (reset_cmd)     wpage_prev<=4'hf;
      else if (wpage0_inc[0]) wpage_prev<=wpage0;
      
      
      if      (we_abs)        wpage_wr <= ((wa==wpage_prev)? wpage0[3:0] : wa);
      else if (we_rel)        wpage_wr <= wpage0+wa;
      else if (wpage0_inc[0]) wpage_wr <= wpage_prev; // only for erasing?
      
//      we_fifo_wp <= wen || wpage0_inc; // during commands and during reset?

///   we_fifo_wp <= wen_fifo[0] || wpage0_inc; // during commands and during reset?
//      we_fifo_wp <= wen_fifo[0] || we_rel || we_abs; // ??
////      we_fifo_wp <= wen_fifo || we_rel || we_abs; // ??
      we_fifo_wp <= wen_fifo || wpage0_inc[0];
      
//     reg            [1:0] wen_r;
//     reg            [1:0] wen_fifo;
      
      
//       if (wen_fifo[0])  fifo_wr_pointers_outw_r[5:0] <= fifo_wr_pointers_outw[5:0];
       if (wen_fifo)  fifo_wr_pointers_outw_r[5:0] <= fifo_wr_pointers_outw[5:0];
       
       // write to dual-port pointer memory
       if (we_fifo_wp) fifo_wr_pointers_ram[wpage_wr] <= wpage0_inc[1]? 6'h0:(fifo_wr_pointers_outw_r[5:0]+1); 
        
        fifo_wr_pointers_outr_r[5:0] <= fifo_wr_pointers_outr[5:0]; // just register distri
// command i2c fifo (RAMB16_S9_S18)

//      if (wen_fifo[0]) i2c_cmd_wa <= {wpage_wr[3:0],fifo_wr_pointers_outw[5:0]};
      if (wen_fifo) i2c_cmd_wa <= {wpage_wr[3:0],fifo_wr_pointers_outw[5:0]};
//      if (wen_d[1]) i2c_cmd_wa[10:1] <= {wpage_wr[3:0],fifo_wr_pointers_outw[5:0]};
//        i2c_cmd_wa[0] <= !wen_d[1]; // 0 for the first in a pair, 1 - for the second
  //    i2c_cmd_we    <=  !reset_cmd && (wen_d[1]  || (i2c_cmd_we && !wen_d[3])); //reset_cmd added to keep simulator happy
      i2c_cmd_we    <=  !reset_cmd && wen_fifo; // [0];
        
// signals related to reading from i2c FIFO
      if      (reset_on)      page_r<=0;
      else if (page_r_inc[0]) page_r<=page_r+1;


      if      (reset_cmd || page_r_inc[0])  rpointer[5:0] <= 6'h0;
      else if (i2c_done)                    rpointer[5:0] <= rpointer[5:0] + 1;

      i2c_run <= !reset_cmd && !reset_on && (i2c_start || (i2c_run && !i2c_done));
      i2c_start <= i2c_enrun && !i2c_run && !i2c_start && (rpointer[5:0]!= fifo_wr_pointers_outr_r[5:0]) && !(|page_r_inc);
      page_r_inc[1:0] <= {page_r_inc[0],
                           !i2c_run &&                              // not i2c in progress
                           !page_r_inc[0] &&                        // was not incrementing in previous cycle
                           (rpointer == fifo_wr_pointers_outr_r) && // nothing left for this page
                           (page_r !=  wpage0)};                    // not already the write-open current page
//i2c sequence generation       
        if      (!i2c_run)         bytes_left[1:0] <= i2c_bytes[1:0];
        else if (i2c_dataseq_done) bytes_left[1:0] <= bytes_left[1:0] -1;

        if (!i2c_run)              byte_sending[1:0] <= 2'h3;
        else if (i2c_dataseq_done) byte_sending[1:0] <= byte_sending[1:0] + 1;

        if (!i2c_run)              byte_number[1:0] <= 2'h3;
        else if (i2c_byte_start[2])byte_number[1:0] <= byte_number[1:0] - 1;

        if (!i2c_run || i2c_dly_over) dly_cntr[7:0] <= i2c_dly[7:0];
        else dly_cntr[7:0] <= dly_cntr[7:0] - 1;
        i2c_dly_pre_over <= i2c_dly_pre2_over; // period = 3..258
        i2c_dly_over <=i2c_dly_pre_over;
        
        i2c_dataseq_done     <= i2c_dataseq_last &&  i2c_dly_pre_over;

        i2c_byte_start[2:0]  <= {i2c_byte_start[1:0],
                        (i2c_startseq_last || (i2c_dataseq_last && (bytes_left[1:0] != 2'h0))) && i2c_dly_pre2_over };
        i2c_sr_shift    <=   i2c_bit_last && !(i2c_dataseq_last) && i2c_dly_pre_over;
        i2c_stop_start  <=   i2c_dataseq_last && (bytes_left[1:0] == 2'h0) && i2c_dly_pre_over ;

        i2c_done     <=  i2c_stopseq_last && i2c_dly_pre_over;
        if    (i2c_byte_start[2]) i2c_sr[8:0] <= {i2c_data[7:0], 1'b1};
        else if (i2c_sr_shift)    i2c_sr[8:0] <= {i2c_sr[7:0],   1'b1};
        
        if      (!i2c_run)          i2c_state[5:0] <= 6'h2a; // start of start seq
        else if (i2c_stop_start)    i2c_state[5:0] <= 6'h26; // start of stop  seq
        else if (i2c_byte_start[2]) i2c_state[5:0] <= 6'h23; // start of data  seq
        else if (i2c_dly_over)      i2c_state[5:0] <= i2c_state[5:0] - 1;
        
        
// now creating output signals
      scl_0 <= (i2c_is_start && (i2c_state[1:0]!=2'h0)) ||
               (i2c_is_stop  && !i2c_state[1]) ||
               (i2c_is_data  && (i2c_state[1] ^i2c_state[0])) ||
                     !i2c_run;
      sda_0 <= (i2c_is_start &&  i2c_state[1]) ||
               (i2c_is_stop  && (i2c_state[1:0]==2'h0)) ||
               (i2c_is_data  && i2c_sr[8]) ||
               !i2c_run;
      sda_hard <= sda_0;
      scl_hard <= scl_0;
      sda_en_hard <= i2c_run && (!sda_0 || (!i2c_is_ackn && !sda_hard));   

      if (wen)             busy_cntr <= 4'hf;
      else if (|busy_cntr) busy_cntr <= busy_cntr-1;
        
      busy <= (i2c_enrun && ((rpointer[5:0]!= fifo_wr_pointers_outr_r[5:0]) || (page_r!=wpage0))) ||
                (|busy_cntr) ||
                  i2c_run ||
                  reset_on;
    end
    ram_var_w_var_r #(
        .REGISTERS(1), // try to delay i2c_byte_start by one more cycle
        .LOG2WIDTH_WR(5),
        .LOG2WIDTH_RD(3)
    ) i_fifo (
        .rclk(mclk), // input
        .raddr({page_r[3:0],  rpointer[5:0], byte_number[1:0]}), // input[11:0] 
        .ren(i2c_byte_start[0]), // input
        .regen(i2c_byte_start[1]), // input
        .data_out(i2c_data[7:0]), // output[7:0] 
        .wclk(mclk), // input
        .waddr(i2c_cmd_wa), // input[9:0] 
        .we(i2c_cmd_we), // input
        .web(8'hff), // input[7:0] 
        .data_in(di_r) // input[31:0] 
    );

endmodule

