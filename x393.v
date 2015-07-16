/*******************************************************************************
 * Module: x393
 * Date:2015-01-13  
 * Author: Andrey Filippov     
 * Description: Elphel NC393 camera FPGA top module
 *
 * Copyright (c) 2015 Elphel, Inc.
 * x393.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  x393.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps
//`define use200Mhz 1
//`define DEBUG_FIFO 1
`include "system_defines.vh" 
module  x393 #(
`include "includes/x393_parameters.vh"
)(
    // Sensors interface: I/O pads, pin names match circuit diagram (each sensor)
    inout                  [7:0] sns1_dp,
    inout                  [7:0] sns1_dn,
    inout                        sns1_clkp,
    inout                        sns1_clkn,
    inout                        sns1_scl,
    inout                        sns1_sda,
    inout                        sns1_ctl,
    inout                        sns1_pg,
    
    inout                  [7:0] sns2_dp,
    inout                  [7:0] sns2_dn,
    inout                        sns2_clkp,
    inout                        sns2_clkn,
    inout                        sns2_scl,
    inout                        sns2_sda,
    inout                        sns2_ctl,
    inout                        sns2_pg,
    
    inout                  [7:0] sns3_dp,
    inout                  [7:0] sns3_dn,
    inout                        sns3_clkp,
    inout                        sns3_clkn,
    inout                        sns3_scl,
    inout                        sns3_sda,
    inout                        sns3_ctl,
    inout                        sns3_pg,
    
    inout                  [7:0] sns4_dp,
    inout                  [7:0] sns4_dn,
    inout                        sns4_clkp,
    inout                        sns4_clkn,
    inout                        sns4_scl,
    inout                        sns4_sda,
    inout                        sns4_ctl,
    inout                        sns4_pg,
    

    // DDR3 interface
    output                       SDRST, // DDR3 reset (active low)
    output                       SDCLK, // DDR3 clock differential output, positive
    output                       SDNCLK,// DDR3 clock differential output, negative
    output  [ADDRESS_NUMBER-1:0] SDA,   // output address ports (14:0) for 4Gb device
    output                 [2:0] SDBA,  // output bank address ports
    output                       SDWE,  // output WE port
    output                       SDRAS, // output RAS port
    output                       SDCAS, // output CAS port
    output                       SDCKE, // output Clock Enable port
    output                       SDODT, // output ODT port

    inout                 [15:0] SDD,   // DQ  I/O pads
    output                       SDDML, // LDM  I/O pad (actually only output)
    inout                        DQSL,  // LDQS I/O pad
    inout                        NDQSL, // ~LDQS I/O pad
    output                       SDDMU, // UDM  I/O pad (actually only output)
    inout                        DQSU,  // UDQS I/O pad
    inout                        NDQSU,
    output                       DUMMY_TO_KEEP  // to keep PS7 signals from "optimization"
    ,input                        MEMCLK
);

//    localparam ADDRESS_NUMBER=15;
//    localparam COLADDR_NUMBER=10;
// Source for reset and clock
(* keep = "true" *)
   wire    [3:0]     fclk;      // PL Clocks [3:0], output
(* keep = "true" *)   
   wire    [3:0]     frst;      // PL Clocks [3:0], output
    
// AXI write interface signals
//(* keep = "true" *) 
   wire           axi_aclk;    // clock - should be buffered
//   wire           axi_naclk;   // debugging
//   wire           axi_aresetn; // reset, active low
//(* dont_touch = "true" *)
   wire           axi_rst;     // reset, active high
// AXI Write Address
   wire   [31:0]  maxi0_awaddr;  // AWADDR[31:0], input
   wire           maxi0_awvalid; // AWVALID, input
   wire           maxi0_awready; // AWREADY, output
   wire   [11:0]  maxi0_awid;    // AWID[11:0], input
//   input  [ 1:0] awlock,     // AWLOCK[1:0], input
//   input  [ 3:0] awcache,    // AWCACHE[3:0], input
//   input  [ 2:0] awprot,     // AWPROT[2:0], input
   wire   [ 3:0]  maxi0_awlen;       // AWLEN[3:0], input
   wire   [ 1:0]  maxi0_awsize;      // AWSIZE[1:0], input
   wire   [ 1:0]  maxi0_awburst;     // AWBURST[1:0], input
//   input  [ 3:0] awqos,      // AWQOS[3:0], input
// AXI PS Master GP0: Write Data
   wire   [31:0]  maxi0_wdata;       // WDATA[31:0], input
   wire           maxi0_wvalid;      // WVALID, input
   wire           maxi0_wready;      // WREADY, output
   wire   [11:0]  maxi0_wid;         // WID[11:0], input
   wire           maxi0_wlast;       // WLAST, input
   wire   [ 3:0]  maxi0_wstb;        // WSTRB[3:0], input
// AXI PS Master GP0: Write Responce
   wire           maxi0_bvalid;      // BVALID, output
   wire           maxi0_bready;      // BREADY, input
   wire   [11:0]  maxi0_bid;         // BID[11:0], output
   wire   [ 1:0]  maxi0_bresp;       // BRESP[1:0], output
   
// BRAM (and other write modules) interface from AXI write
   wire [AXI_WR_ADDR_BITS-1:0] axiwr_pre_awaddr; // same as awaddr_out, early address to decode and return dev_ready
   wire           axiwr_start_burst; // start of write burst, valid pre_awaddr, save externally to control ext. dev_ready multiplexer
   wire           axiwr_dev_ready;   // extrernal combinatorial ready signal, multiplexed from different sources according to pre_awaddr@start_burst
   wire           axiwr_wclk;
   wire  [AXI_WR_ADDR_BITS-1:0] axiwr_waddr;
   wire           axiwr_wen;    // external memory write enable, (internally combined with registered dev_ready
// SuppressWarnings VEditor unused (yet?) 
   wire    [3:0]  axiwr_bram_wstb; 
   wire   [31:0]  axiwr_wdata;

 // AXI Read Address   
   wire   [31:0]  maxi0_araddr;  // ARADDR[31:0], input 
   wire           maxi0_arvalid; // ARVALID, input
   wire           maxi0_arready; // ARREADY, output
   wire   [11:0]  maxi0_arid;    // ARID[11:0], input
//   input  [ 1:0] arlock,  // ARLOCK[1:0], input
//   input  [ 3:0] archache,// ARCACHE[3:0], input
//   input  [ 2:0] arprot,  // ARPROT[2:0], input
   wire   [ 3:0]  maxi0_arlen;   // ARLEN[3:0], input
   wire   [ 1:0]  maxi0_arsize;  // ARSIZE[1:0], input
   wire   [ 1:0]  maxi0_arburst; // ARBURST[1:0], input
//   input  [ 3:0] adqos,   // ARQOS[3:0], input
// AXI Read Data
   wire   [31:0]  maxi0_rdata;   // RDATA[31:0], output
   wire           maxi0_rvalid;  // RVALID, output
   wire           maxi0_rready;  // RREADY, input
   wire   [11:0]  maxi0_rid;     // RID[11:0], output
   wire           maxi0_rlast;   // RLAST, output
   wire   [ 1:0]  maxi0_rresp;

// External memory synchronization
   wire [AXI_RD_ADDR_BITS-1:0] axird_pre_araddr; // same as awaddr_out, early address to decode and return dev_ready
   wire           axird_start_burst; // start of read burst, valid pre_araddr, save externally to control ext. dev_ready multiplexer
   wire           axird_dev_ready;   // extrernal combinatorial ready signal, multiplexed from different sources according to pre_araddr@start_burst
// External memory interface   
// SuppressWarnings VEditor unused (yet?) - use mclk 
   wire           axird_bram_rclk;  // == axi_aclk      .rclk(aclk),                  // clock for read port
   // while only status provides read data, the next signals are not used (relies on axird_pre_araddr, axird_start_burst)
   wire  [AXI_RD_ADDR_BITS-1:0] axird_raddr; //   .raddr(read_in_progress?read_address[9:0]:10'h3ff),    // read address
   wire           axird_ren;   //      .ren(bram_reg_re_w) ,      // read port enable
   wire           axird_regen; //   .regen(bram_reg_re_w),        // output register enable
   wire  [31:0]   axird_rdata;  //      .data_out(rdata[31:0]),       // data out
//   wire  [31:0]   port0_rdata;  //
   wire  [31:0]   status_rdata;  //
   wire           status_selected;
   wire  [31:0]   readback_rdata;  //
   wire           readback_selected;
   wire  [31:0]   mcntrl_axird_rdata; // read data from the memory controller 


   
   wire           mcntrl_axird_selected; // memory controller has valid data output on mcntrl_axird_rdata 
   reg            status_selected_ren;         // status_selected (set at axird_start_burst) delayed when ren is active
   reg            readback_selected_ren;
   reg            mcntrl_axird_selected_ren;   // mcntrl_axird_selected (set at axird_start_burst) delayed when ren is active
   reg            status_selected_regen;       // status_selected (set at axird_start_burst) delayed when ren is active, then when regen (normally 2 cycles)
   reg            readback_selected_regen;
   reg            mcntrl_axird_selected_regen; // mcntrl_axird_selected (set at axird_start_burst) delayed when ren is active, then when regen (normally 2 cycles)

   // global clocks
   wire           mclk; // global clock, memory controller, command/status network (currently 200MHz)
   wire           ref_clk; // global clock for idelay_ctrl calibration
   wire           hclk; // global clock, axi_hp (150MHz) derived from aclk_in = 50MHz
   
    // sensor pixel rate clock likely to originate from the external clock
   wire           pclk;   // global clock, sensor pixel rate (96 MHz)
   wire           pclk2x; // global clock, sensor double pixel rate (192 MHz)
   
   // compressor pixel rate can be adjusted independently
   wire           xclk;   // global clock, compressor pixel rate (100 MHz)?
   wire           xclk2x; // global clock, compressor double pixel rate (200 MHz)
   
   

   wire [11:0] tmp_debug; 
   
//   reg    select_port0; // May be used later!
   wire axiwr_dev_busy;
   wire axird_dev_busy;
   
   //TODO: The following is the interface to the frame-based command sequencer (not yet implemnted)        
    wire [AXI_WR_ADDR_BITS-1:0] cseq_waddr;   // command sequencer write address (output to command multiplexer)
    wire                        cseq_wr_en;   // command sequencer write enable (output to command multiplexer) - keep until cseq_ackn received
    wire                 [31:0] cseq_wdata;   // command sequencer write data (output to command multiplexer) 
    wire                        cseq_ackn;    // ackn to command sequencer, command sequencer should de-assert cseq_wr_en
    // per-sensor channel command sequencer signals
    wire [AXI_WR_ADDR_BITS-1:0] cseq0_waddr;   // command sequencer write address (output to command multiplexer)
    wire                        cseq0_wr_en;   // command sequencer write enable (output to command multiplexer) - keep until cseq_ackn received
    wire                 [31:0] cseq0_wdata;   // command sequencer write data (output to command multiplexer) 
    wire                        cseq0_ackn;    /// SuppressThisWarning VEditor ****** ackn to command sequencer, command sequencer should de-assert cseq_wr_en
    wire [AXI_WR_ADDR_BITS-1:0] cseq1_waddr;   // command sequencer write address (output to command multiplexer)
    wire                        cseq1_wr_en;   // command sequencer write enable (output to command multiplexer) - keep until cseq_ackn received
    wire                 [31:0] cseq1_wdata;   // command sequencer write data (output to command multiplexer) 
    wire                        cseq1_ackn;    /// SuppressThisWarning VEditor ****** ackn to command sequencer, command sequencer should de-assert cseq_wr_en
    wire [AXI_WR_ADDR_BITS-1:0] cseq2_waddr;   // command sequencer write address (output to command multiplexer)
    wire                        cseq2_wr_en;   // command sequencer write enable (output to command multiplexer) - keep until cseq_ackn received
    wire                 [31:0] cseq2_wdata;   // command sequencer write data (output to command multiplexer) 
    wire                        cseq2_ackn;    /// SuppressThisWarning VEditor ****** ackn to command sequencer, command sequencer should de-assert cseq_wr_en
    wire [AXI_WR_ADDR_BITS-1:0] cseq3_waddr;   // command sequencer write address (output to command multiplexer)
    wire                        cseq3_wr_en;   // command sequencer write enable (output to command multiplexer) - keep until cseq_ackn received
    wire                 [31:0] cseq3_wdata;   // command sequencer write data (output to command multiplexer) 
    wire                        cseq3_ackn;    /// SuppressThisWarning VEditor ****** ackn to command sequencer, command sequencer should de-assert cseq_wr_en
    
    
// parallel address/data - where higher bandwidth (single-cycle) is needed        
    wire [AXI_WR_ADDR_BITS-1:0] par_waddr; 
    wire                 [31:0] par_data; 



    wire                  [7:0] cmd_root_ad;       // multiplexed byte-wide serialized address/data to salve devices (AL-AH-D0-D1-D2-D3), may contain less cycles 
    wire                        cmd_root_stb;      // strobe marking the first of 1-6 a/d bytes and also data valid for par_waddr and par_data

    wire                  [7:0] status_root_ad;    // Root status byte-wide address/data 
    wire                        status_root_rq;    // Root status request  
    wire                        status_root_start; // Root status packet transfer start (currently with 0 latency from status_root_rq)

    wire                  [7:0] status_mcontr_ad;    // Memory controller status byte-wide address/data 
    wire                        status_mcontr_rq;    // Memory controller status request  
    wire                        status_mcontr_start; // Memory controller status packet transfer start (currently with 0 latency from status_root_rq)
// Not yet connected
    wire                  [7:0] status_membridge_ad;    // membridge (afi to ddr3) status byte-wide address/data 
    wire                        status_membridge_rq;    // membridge (afi to ddr3) status request  
    wire                        status_membridge_start; //membridge (afi to ddr3) status packet transfer start (currently with 0 latency from status_root_rq)

//    wire                  [7:0] status_other_ad = 0; // Other status byte-wide address/data
//    wire                        status_other_rq = 0; // Other status request   
//    wire                        status_other_start;  // SuppressThisWarning VEditor ****** Other status packet transfer start (currently with 0 latency from status_root_rq)


    wire                  [7:0] status_test01_ad;    // Test module status byte-wide address/data 
    wire                        status_test01_rq;    // Test module status request  
    wire                        status_test01_start; // Test module status packet transfer start (currently with 0 latency from status_root_rq)


    wire                  [7:0] status_sensor_ad;     // Other status byte-wide address/data
    wire                        status_sensor_rq;     // Other status request   
    wire                        status_sensor_start;  // S uppressThisWarning VEditor ****** Other status packet transfer start (currently with 0 latency from status_root_rq)

    wire                  [7:0] status_compressor_ad; // Other status byte-wide address/data
    wire                        status_compressor_rq; // Other status request   
    wire                        status_compressor_start;  // S uppressThisWarning VEditor ****** Other status packet transfer start (currently with 0 latency from status_root_rq)

    wire                  [7:0] status_sequencer_ad; // Other status byte-wide address/data
    wire                        status_sequencer_rq; // Other status request   
    wire                        status_sequencer_start;  // S uppressThisWarning VEditor ****** Other status packet transfer start (currently with 0 latency from status_root_rq)

    wire                  [7:0] status_logger_ad; // Other status byte-wide address/data
    wire                        status_logger_rq; // Other status request   
    wire                        status_logger_start;  // S uppressThisWarning VEditor ****** Other status packet transfer start (currently with 0 latency from status_root_rq)

    wire                  [7:0] status_timing_ad; // Other status byte-wide address/data
    wire                        status_timing_rq; // Other status request   
    wire                        status_timing_start;  // S uppressThisWarning VEditor ****** Other status packet transfer start (currently with 0 latency from status_root_rq)

    // Insert register layer if needed
    reg  [7:0] cmd_mcontr_ad;
    reg        cmd_mcontr_stb;
    
    reg  [7:0] cmd_test01_ad;
    reg        cmd_test01_stb;
    
    reg  [7:0] cmd_membridge_ad;
    reg        cmd_membridge_stb;

    reg  [7:0] cmd_sensor_ad;
    reg        cmd_sensor_stb;

    reg  [7:0] cmd_compressor_ad;
    reg        cmd_compressor_stb;

    reg  [7:0] cmd_sequencer_ad;
    reg        cmd_sequencer_stb;

    reg  [7:0] cmd_logger_ad;
    reg        cmd_logger_stb;

    reg  [7:0] cmd_timing_ad;
    reg        cmd_timing_stb;

// membridge
    wire                        frame_start_chn1; // input
    wire                        next_page_chn1; // input
    wire                        cmd_wrmem_chn1;
    wire                        page_ready_chn1; // output
    wire                        frame_done_chn1; // output
    wire[FRAME_HEIGHT_BITS-1:0] line_unfinished_chn1; // output[15:0] 
    wire                        suspend_chn1; // input
    wire                        xfer_reset_page1_rd;
    wire                        buf_wpage_nxt_chn1;
    wire                        buf_wr_chn1;
    wire                 [63:0] buf_wdata_chn1; 
    wire                        xfer_reset_page1_wr;
    wire                        rpage_nxt_chn1;
    wire                        buf_rd_chn1;
    wire                 [63:0] buf_rdata_chn1; 
    
    
    
    
//mcntrl393_test01
    wire                        frame_start_chn2;  // input
    wire                        next_page_chn2;    // input
    wire                        page_ready_chn2; // output
    wire                        frame_done_chn2; // output
    wire[FRAME_HEIGHT_BITS-1:0] line_unfinished_chn2; // output[15:0] 
    wire  [LAST_FRAME_BITS-1:0] frame_number_chn2; // output[15:0] 
    wire                        suspend_chn2; // input
    wire                        frame_start_chn3; // input
    wire                        next_page_chn3; // input
    wire                        page_ready_chn3; // output
    wire                        frame_done_chn3; // output
    wire[FRAME_HEIGHT_BITS-1:0] line_unfinished_chn3; // output[15:0] 
    wire  [LAST_FRAME_BITS-1:0] frame_number_chn3; // output[15:0] 
    wire                        suspend_chn3; // input
    wire                        frame_start_chn4; // input
    wire                        next_page_chn4; // input
    wire                        page_ready_chn4; // output
    wire                        frame_done_chn4; // output
    wire[FRAME_HEIGHT_BITS-1:0] line_unfinished_chn4; // output[15:0]
    wire  [LAST_FRAME_BITS-1:0] frame_number_chn4; // output[15:0] 
    wire                        suspend_chn4; // input
   
    reg                         axi_rst_pre=1'b1;
    wire                        comb_rst; //=~frst[0] | frst[1];
   //MEMCLK
    wire                 [63:0] gpio_in;
    
    // signals for sensor393 (in/outs as sseen for the sensor393)
    wire                  [3:0] sens_rpage_set;  //    (), // input
    wire                  [3:0] sens_rpage_next; //    (), // input
    wire                  [3:0] sens_buf_rd;     //    (), // input
    wire                [255:0] sens_buf_dout;   //    (), // output[63:0] 
        
    wire                        trigger_mode; //       (), // input
    wire                  [3:0] trig_in;                  // input[3:0] 
        
    wire                  [3:0] sof_out_pclk; //       (), // output[3:0] 
    wire                  [3:0] eof_out_pclk; //       (), // output[3:0] 
    wire                  [3:0] sof_out_mclk; //       (), // output[3:0] 
    wire                  [3:0] sof_late_mclk; //      (), // output[3:0] 
        
    wire [NUM_FRAME_BITS - 1:0] frame_num0; //         (), // input[3:0] 
    wire [NUM_FRAME_BITS - 1:0] frame_num1; //         (), // input[3:0] 
    wire [NUM_FRAME_BITS - 1:0] frame_num2; //         (), // input[3:0] 
    wire [NUM_FRAME_BITS - 1:0] frame_num3; //         (), // input[3:0] 
    
    // signals for compressor393 (in/outs as seen for the sensor393)
    // per-channel memory buffers interface

    wire   [3:0] cmprs_xfer_reset_page_rd;  // input
    wire   [3:0] cmprs_buf_wpage_nxt;       // input
    wire   [3:0] cmprs_buf_we;              // input
    wire [255:0] cmprs_buf_din;             // input[63:0] 
    wire   [3:0] cmprs_page_ready;          // input
    wire   [3:0] cmprs_next_page;           // output

// per-channel master (sesnor)/slave (compressor) synchronization (compressor wait until sesnor provided data)
    wire                     [3:0] cmprs_frame_start_dst; // output - trigger receive (tiledc) memory channel (it will take care of single/repetitive
                                                          // these output either follows vsync_late (reclocks it) or generated in non-bonded mode
                                                          // (compress from memory)
    wire [4*FRAME_HEIGHT_BITS-1:0] cmprs_line_unfinished_src; // input[15:0] number of the current (unfinished ) line, in the source (sensor)
                                                          //  channel (RELATIVE TO FRAME, NOT WINDOW?)
    wire   [4*LAST_FRAME_BITS-1:0] cmprs_frame_number_src;// input[15:0] current frame number (for multi-frame ranges) in the source (sensor) channel
    wire                     [3:0] cmprs_frame_done_src;  // input single-cycle pulse when the full frame (window) was transferred to/from DDR3 memory 
                                                          // frame_done_src is later than line_unfinished_src/ frame_number_src changes
                                                          // Used withe a single-frame buffers
    wire [4*FRAME_HEIGHT_BITS-1:0] cmprs_line_unfinished_dst; // input[15:0] number of the current (unfinished ) line in this (compressor) channel
    wire   [4*LAST_FRAME_BITS-1:0] cmprs_frame_number_dst; // input[15:0] current frame number (for multi-frame ranges) in this (compressor channel
    wire                     [3:0] cmprs_frame_done_dst;   // input single-cycle pulse when the full frame (window) was transferred to/from DDR3 memory
                                                           // use as 'eot_real' in 353 
    wire                     [3:0] cmprs_suspend;          // output suspend reading data for this channel - waiting for the source data

// Timestamp messages (@mclk) - combine to a single ts_data?    
   wire                      [3:0] ts_pre_stb; // input
   wire                     [31:0] ts_data;    // input[7:0] 
   
// Compressor signals for interrupts generation    
   wire                      [3:0] eof_written_mclk;  // output
   wire                      [3:0] stuffer_done_mclk; // output
// Compressor frame synchronization
   wire                      [3:0] vsync_late; // input
    
    
    assign gpio_in= {48'h0,frst,tmp_debug};
   
   
   
   
   assign axird_dev_ready = ~axird_dev_busy; //may combine (AND) multiple sources if needed
   assign axird_dev_busy = 1'b0; // always for now
// Use this later    
   assign axird_rdata= ({32{status_selected_regen}} & status_rdata[31:0]) |
                       ({32{readback_selected_regen}} & readback_rdata[31:0]) |
                       ({32{mcntrl_axird_selected_regen}} & mcntrl_axird_rdata[31:0]);
   
//Debug with this (to show 'x)   
//   assign axird_rdata= status_selected_regen?status_rdata[31:0] : (mcntrl_axird_selected_regen? mcntrl_axird_rdata[31:0]:'bx);

// temporary for Vivado debugging
//   assign axird_rdata= status_rdata[31:0] |  mcntrl_axird_rdata[31:0];

   
   assign axiwr_dev_ready = ~axiwr_dev_busy; //may combine (AND) multiple sources if needed

// Clock and reset from PS
   assign comb_rst=~frst[0] | frst[1];

    // insert register layers if needed
    always @ (posedge mclk) begin
        cmd_mcontr_ad <=      cmd_root_ad;
        cmd_mcontr_stb <=     cmd_root_stb;
        
        cmd_test01_ad <=      cmd_root_ad;
        cmd_test01_stb <=     cmd_root_stb;
        
        cmd_membridge_ad <=   cmd_root_ad;
        cmd_membridge_stb <=  cmd_root_stb;
        
        cmd_sensor_ad <=      cmd_root_ad;
        cmd_sensor_stb <=     cmd_root_stb;
        
        cmd_compressor_ad <=  cmd_root_ad;
        cmd_compressor_stb <= cmd_root_stb;
        
        cmd_sequencer_ad <=   cmd_root_ad;
        cmd_sequencer_stb <=  cmd_root_stb;
        
        cmd_logger_ad <=      cmd_root_ad;
        cmd_logger_stb <=     cmd_root_stb;
        
        cmd_timing_ad <=      cmd_root_ad;
        cmd_timing_stb <=     cmd_root_stb;
    end

// For now - connect status_test01 to status_other, if needed - increase number of multiplexer inputs)
//   assign status_other_ad = status_test01_ad;
//   assign status_other_rq = status_test01_rq;
//   assign status_test01_start = status_other_start;

// missing command sequencer:
   assign cseq0_waddr='bx;  // command sequencer write address (output to command multiplexer)
   assign cseq0_wr_en= 0;   // command sequencer write enable (output to command multiplexer) - keep until cseq_ackn received
   assign cseq0_wdata='bx;  // command sequencer write data (output to command multiplexer) 

   assign cseq1_waddr='bx;  // command sequencer write address (output to command multiplexer)
   assign cseq1_wr_en= 0;   // command sequencer write enable (output to command multiplexer) - keep until cseq_ackn received
   assign cseq1_wdata='bx;  // command sequencer write data (output to command multiplexer) 

   assign cseq2_waddr='bx;  // command sequencer write address (output to command multiplexer)
   assign cseq2_wr_en= 0;   // command sequencer write enable (output to command multiplexer) - keep until cseq_ackn received
   assign cseq2_wdata='bx;  // command sequencer write data (output to command multiplexer) 

   assign cseq3_waddr='bx;  // command sequencer write address (output to command multiplexer)
   assign cseq3_wr_en= 0;   // command sequencer write enable (output to command multiplexer) - keep until cseq_ackn received
   assign cseq3_wdata='bx;  // command sequencer write data (output to command multiplexer) 



// delay status_selected and mcntrl_axird_selected to match data for multiplexing

    always @(posedge axi_rst or posedge axird_bram_rclk) begin // axird_bram_rclk==axi_aclk
//    always @(posedge axi_rst or posedge axi_aclk) begin
        if      (axi_rst)     status_selected_ren <= 1'b0;
        else if (axird_ren)   status_selected_ren <= status_selected;
        
        if      (axi_rst)     status_selected_regen <= 1'b0;
        else if (axird_regen) status_selected_regen <= status_selected_ren;

        if      (axi_rst)     readback_selected_ren <= 1'b0;
        else if (axird_ren)   readback_selected_ren <= readback_selected;
        
        if      (axi_rst)     readback_selected_regen <= 1'b0;
        else if (axird_regen) readback_selected_regen <= readback_selected_ren;

        if      (axi_rst)     mcntrl_axird_selected_ren <= 1'b0;
        else if (axird_ren)   mcntrl_axird_selected_ren <=  mcntrl_axird_selected;
        
        if      (axi_rst)     mcntrl_axird_selected_regen <= 1'b0;
        else if (axird_regen) mcntrl_axird_selected_regen <= mcntrl_axird_selected_ren;
    end



    always @(posedge comb_rst or posedge axi_aclk) begin
        if (comb_rst) axi_rst_pre <= 1'b1;
        else          axi_rst_pre <= 1'b0;
    end
     
//BUFG bufg_axi_rst_i   (.O(axi_rst),.I(axi_rst_pre));
//BUFG bufg_axi_aclk_i  (.O(axi_aclk),.I(fclk[0]));
   

`ifdef DEBUG_FIFO
        wire    waddr_under, wdata_under, wresp_under; 
        wire    waddr_over, wdata_over, wresp_over;
        reg     waddr_under_r, wdata_under_r, wresp_under_r;
        reg     waddr_over_r, wdata_over_r, wresp_over_r;
        wire    fifo_rst= frst[2];
        wire [3:0]   waddr_wcount; 
        wire [3:0]   waddr_rcount; 
        wire [3:0]   waddr_num_in_fifo; 
        
        wire [3:0]   wdata_wcount; 
        wire [3:0]   wdata_rcount; 
        wire [3:0]   wdata_num_in_fifo; 
        
        wire [3:0]   wresp_wcount; 
        wire [3:0]   wresp_rcount; 
        wire [3:0]   wresp_num_in_fifo; 
        wire [3:0]   wleft;
        wire [3:0]   wlength; // output[3:0] 
        wire [3:0]   wlen_in_dbg; // output[3:0] reg 
        
           
    always @(posedge fifo_rst or posedge axi_aclk) begin
     if (fifo_rst) {waddr_under_r, wdata_under_r, wresp_under_r,waddr_over_r, wdata_over_r, wresp_over_r} <= 0;
     else {waddr_under_r, wdata_under_r, wresp_under_r, waddr_over_r, wdata_over_r, wresp_over_r} <=
          {waddr_under_r, wdata_under_r, wresp_under_r, waddr_over_r, wdata_over_r, wresp_over_r} | 
          {waddr_under,   wdata_under,   wresp_under,   waddr_over,   wdata_over,   wresp_over};
    end         
`endif

BUFG bufg_axi_rst_i   (.O(axi_rst),.I(axi_rst_pre));
BUFG bufg_axi_aclk_i  (.O(axi_aclk),.I(fclk[0]));
    axi_hp_clk #(
        .CLKIN_PERIOD(CLKIN_PERIOD),
        .CLKFBOUT_MULT_AXIHP(CLKFBOUT_MULT_AXIHP),
        .CLKFBOUT_DIV_AXIHP(CLKFBOUT_DIV_AXIHP)
    ) axi_hp_clk_i (
        .rst          (axi_rst), // input
        .clk_in       (axi_aclk), // input
        .clk_axihp    (hclk), // output
        .locked_axihp () // output // not controlled?
    );


// channel test module
    mcntrl393_test01 #(
        .MCNTRL_TEST01_ADDR                 (MCNTRL_TEST01_ADDR),
        .MCNTRL_TEST01_MASK                 (MCNTRL_TEST01_MASK),
        .FRAME_HEIGHT_BITS                  (FRAME_HEIGHT_BITS),
        .MCNTRL_TEST01_CHN1_MODE            (MCNTRL_TEST01_CHN1_MODE),
        .MCNTRL_TEST01_CHN1_STATUS_CNTRL    (MCNTRL_TEST01_CHN1_STATUS_CNTRL),
        .MCNTRL_TEST01_CHN2_MODE            (MCNTRL_TEST01_CHN2_MODE),
        .MCNTRL_TEST01_CHN2_STATUS_CNTRL    (MCNTRL_TEST01_CHN2_STATUS_CNTRL),
        .MCNTRL_TEST01_CHN3_MODE            (MCNTRL_TEST01_CHN3_MODE),
        .MCNTRL_TEST01_CHN3_STATUS_CNTRL    (MCNTRL_TEST01_CHN3_STATUS_CNTRL),
        .MCNTRL_TEST01_CHN4_MODE            (MCNTRL_TEST01_CHN4_MODE),
        .MCNTRL_TEST01_CHN4_STATUS_CNTRL    (MCNTRL_TEST01_CHN4_STATUS_CNTRL),
        .MCNTRL_TEST01_STATUS_REG_CHN1_ADDR (MCNTRL_TEST01_STATUS_REG_CHN1_ADDR),
        .MCNTRL_TEST01_STATUS_REG_CHN2_ADDR (MCNTRL_TEST01_STATUS_REG_CHN2_ADDR),
        .MCNTRL_TEST01_STATUS_REG_CHN3_ADDR (MCNTRL_TEST01_STATUS_REG_CHN3_ADDR),
        .MCNTRL_TEST01_STATUS_REG_CHN4_ADDR (MCNTRL_TEST01_STATUS_REG_CHN4_ADDR)
    ) mcntrl393_test01_i (
        .rst                  (axi_rst), // input
        .mclk                 (mclk), // input
        .cmd_ad               (cmd_test01_ad), // input[7:0] 
        .cmd_stb              (cmd_test01_stb), // input
        .status_ad            (status_test01_ad), // output[7:0] 
        .status_rq            (status_test01_rq), // output
        .status_start         (status_test01_start), // input
        .frame_start_chn1     (), //frame_start_chn1), // output
        .next_page_chn1       (), //next_page_chn1), // output
        .page_ready_chn1      (1'b0), // page_ready_chn1), // input
        .frame_done_chn1      (1'b0), //frame_done_chn1), // input
        .line_unfinished_chn1 (16'b0), //line_unfinished_chn1), // input[15:0] 
        .suspend_chn1         (), //suspend_chn1), // output
        .frame_start_chn2     (frame_start_chn2), // output
        .next_page_chn2       (next_page_chn2), // output
        .page_ready_chn2      (page_ready_chn2), // input
        .frame_done_chn2      (frame_done_chn2), // input
        .line_unfinished_chn2 (line_unfinished_chn2), // input[15:0] 
        .suspend_chn2         (suspend_chn2), // output
        .frame_start_chn3     (frame_start_chn3), // output
        .next_page_chn3       (next_page_chn3), // output
        .page_ready_chn3      (page_ready_chn3), // input
        .frame_done_chn3      (frame_done_chn3), // input
        .line_unfinished_chn3 (line_unfinished_chn3), // input[15:0] 
        .suspend_chn3         (suspend_chn3), // output
        .frame_start_chn4     (frame_start_chn4), // output
        .next_page_chn4       (next_page_chn4), // output
        .page_ready_chn4      (page_ready_chn4), // input
        .frame_done_chn4      (frame_done_chn4), // input
        .line_unfinished_chn4 (line_unfinished_chn4), // input[15:0] 
        .suspend_chn4         (suspend_chn4) // output
    );

// Interface to channels to read/write memory (including 4 page BRAM buffers)
// TODO:increase depth, number of NUM_CYCLES - twice?
    cmd_mux #(
        .AXI_WR_ADDR_BITS  (AXI_WR_ADDR_BITS),
        .CONTROL_ADDR      (CONTROL_ADDR),
        .CONTROL_ADDR_MASK (CONTROL_ADDR_MASK),
// TODO: Put correct numcycles!        
        .NUM_CYCLES_LOW_BIT(NUM_CYCLES_LOW_BIT),
        .NUM_CYCLES_00     (NUM_CYCLES_00),
        .NUM_CYCLES_01     (NUM_CYCLES_01),
        .NUM_CYCLES_02     (NUM_CYCLES_02),
        .NUM_CYCLES_03     (NUM_CYCLES_03),
        .NUM_CYCLES_04     (NUM_CYCLES_04),
        .NUM_CYCLES_05     (NUM_CYCLES_05),
        .NUM_CYCLES_06     (NUM_CYCLES_06),
        .NUM_CYCLES_07     (NUM_CYCLES_07),
        .NUM_CYCLES_08     (NUM_CYCLES_08),
        .NUM_CYCLES_09     (NUM_CYCLES_09),
        .NUM_CYCLES_10     (NUM_CYCLES_10),
        .NUM_CYCLES_11     (NUM_CYCLES_11),
        .NUM_CYCLES_12     (NUM_CYCLES_12),
        .NUM_CYCLES_13     (NUM_CYCLES_13),
        .NUM_CYCLES_14     (NUM_CYCLES_14),
        .NUM_CYCLES_15     (NUM_CYCLES_15),
        .NUM_CYCLES_16     (NUM_CYCLES_16),
        .NUM_CYCLES_17     (NUM_CYCLES_17),
        .NUM_CYCLES_18     (NUM_CYCLES_18),
        .NUM_CYCLES_19     (NUM_CYCLES_19),
        .NUM_CYCLES_20     (NUM_CYCLES_20),
        .NUM_CYCLES_21     (NUM_CYCLES_21),
        .NUM_CYCLES_22     (NUM_CYCLES_22),
        .NUM_CYCLES_23     (NUM_CYCLES_23),
        .NUM_CYCLES_24     (NUM_CYCLES_24),
        .NUM_CYCLES_25     (NUM_CYCLES_25),
        .NUM_CYCLES_26     (NUM_CYCLES_26),
        .NUM_CYCLES_27     (NUM_CYCLES_27),
        .NUM_CYCLES_28     (NUM_CYCLES_28),
        .NUM_CYCLES_29     (NUM_CYCLES_29),
        .NUM_CYCLES_30     (NUM_CYCLES_30),
        .NUM_CYCLES_31     (NUM_CYCLES_31)
    ) cmd_mux_i ( // SuppressThisWarning ISExst: Output port <par_data>,<par_waddr>, <cseq_ackn> of the instance <cmd_mux_i> is unconnected or connected to loadless signal.
        .axi_clk      (axiwr_wclk), // input
        .mclk         (mclk), // input
        .rst          (axi_rst), // input
        .pre_waddr    (axiwr_pre_awaddr[AXI_WR_ADDR_BITS-1:0]), // input[12:0] // SuppressThisWarning VivadoSynthesis: [Synth 8-3295] tying undriven pin #cmd_mux_i:pre_waddr[9:0] to constant 0
        .start_wburst (axiwr_start_burst), // input
        .waddr        (axiwr_waddr[AXI_WR_ADDR_BITS-1:0]), // input[12:0] 
        .wr_en        (axiwr_wen), // input
        .wdata        (axiwr_wdata[31:0]), // input[31:0] 
        .busy         (axiwr_dev_busy), // output // assign axiwr_dev_ready = ~axiwr_dev_busy; //may combine (AND) multiple sources if needed
//TODO: The following is the interface to the command sequencer (not yet implemnted)        
        .cseq_waddr   (cseq_waddr), // input[12:0] // SuppressThisWarning VivadoSynthesis: [Synth 8-3295] tying undriven pin #cmd_mux_i:cseq_waddr[13:0] to constant 0 (command sequencer not yet implemented)
        .cseq_wr_en   (cseq_wr_en), // input // SuppressThisWarning VivadoSynthesis: [Synth 8-3295] tying undriven pin #cmd_mux_i:cseq_wr_en to constant 0 (command sequencer not yet implemented)
        .cseq_wdata   (cseq_wdata), // input[31:0] // SuppressThisWarning VivadoSynthesis: [Synth 8-3295] tying undriven pin #cmd_mux_i:cseq_wdata[31:0] to constant 0 (command sequencer not yet implemented)
        .cseq_ackn    (cseq_ackn), // output // SuppressThisWarning ISExst: Assignment to cseq_ackn ignored, since the identifier is never used (command sequencer not yet implemented)
// parallel address/data - where higher bandwidth (single-cycle) is needed        
        .par_waddr    (par_waddr), // output[12:0] // SuppressThisWarning ISExst: Assignment to par_waddr ignored, since the identifier is never used (not yet used)
        .par_data     (par_data), // output[31:0] // SuppressThisWarning ISExst: Assignment to par_data ignored, since the identifier is never used (not yet used)
        // registers may be inserted before byte_ad and ad_stb  
        .byte_ad      (cmd_root_ad), // output[7:0] 
        .ad_stb       (cmd_root_stb) // output
    );
    
    cmd_seq_mux #(
        .AXI_WR_ADDR_BITS (AXI_WR_ADDR_BITS)
    ) cmd_seq_mux_i (
        .rst          (axi_rst),     // input
        .mclk         (mclk),        // input
        .waddr0       (cseq0_waddr), // input[13:0] 
        .wr_en0       (cseq0_wr_en), // input
        .wdata0       (cseq0_wdata), // input[31:0] 
        .ackn0        (cseq0_ackn),  // output
        .waddr1       (cseq1_waddr), // input[13:0] 
        .wr_en1       (cseq1_wr_en), // input
        .wdata1       (cseq1_wdata), // input[31:0] 
        .ackn1        (cseq1_ackn),  // output
        .waddr2       (cseq2_waddr), // input[13:0] 
        .wr_en2       (cseq2_wr_en), // input
        .wdata2       (cseq2_wdata), // input[31:0] 
        .ackn2        (cseq2_ackn),  // output
        .waddr3       (cseq3_waddr), // input[13:0] 
        .wr_en3       (cseq3_wr_en), // input
        .wdata3       (cseq3_wdata), // input[31:0] 
        .ackn3        (cseq3_ackn),  // output
        .waddr_out    (cseq_waddr),  // output[13:0] reg 
        .wr_en_out    (cseq_wr_en),  // output
        .wdata_out    (cseq_wdata),  // output[31:0] reg 
        .ackn_out     (cseq_ackn)    // input
    );
    
    
    // Mirror control register data for readback (registers can be written both from the PS and from the command sequencer)
    cmd_readback #(
        .AXI_WR_ADDR_BITS        (AXI_WR_ADDR_BITS),
        .AXI_RD_ADDR_BITS        (AXI_RD_ADDR_BITS),
        .CONTROL_RBACK_DEPTH     (CONTROL_RBACK_DEPTH),
        .CONTROL_ADDR            (CONTROL_ADDR),
        .CONTROL_ADDR_MASK       (CONTROL_ADDR_MASK),
        .CONTROL_RBACK_ADDR      (CONTROL_RBACK_ADDR),
        .CONTROL_RBACK_ADDR_MASK (CONTROL_RBACK_ADDR_MASK)
    ) cmd_readback_i (
        .rst                     (axi_rst), // input
        .mclk                    (mclk), // input
        .axi_clk                 (axird_bram_rclk), // input
        .par_waddr               (par_waddr), // input[13:0] 
        .par_data                (par_data), // input[31:0] 
        .ad_stb                  (cmd_root_stb), // input
        .axird_pre_araddr        (axird_pre_araddr), // input[13:0] 
        .axird_start_burst       (axird_start_burst), // input
        .axird_raddr             (axird_raddr[CONTROL_RBACK_DEPTH-1:0]), // input[9:0] 
        .axird_ren               (axird_ren), // input
        .axird_rdata             (readback_rdata), // output[31:0] 
        .axird_selected          (readback_selected) // output
    );

    status_read #(
        .STATUS_ADDR      (STATUS_ADDR),
        .STATUS_ADDR_MASK (STATUS_ADDR_MASK),
        .AXI_RD_ADDR_BITS (AXI_RD_ADDR_BITS),
        .STATUS_DEPTH     (STATUS_DEPTH)
    ) status_read_i (
        .rst              (axi_rst), // input
        .clk              (mclk), // input
        .axi_clk          (axird_bram_rclk), // input == axi_aclk
        .axird_pre_araddr (axird_pre_araddr), // input[7:0] // SuppressThisWarning VivadoSynthesis: [Synth 8-3295] tying undriven pin #status_read_i:axird_pre_araddr[9:0] to constant 0
        .axird_start_burst(axird_start_burst), // input
        .axird_raddr      (axird_raddr[STATUS_DEPTH-1:0]), // input[7:0] 
        .axird_ren        (axird_ren), // input
        .axird_regen      (axird_regen), // input
        .axird_rdata      (status_rdata), // output[31:0] 
        .axird_selected   (status_selected), // output
        .ad               (status_root_ad), // input[7:0] 
        .rq               (status_root_rq), // input
        .start            (status_root_start) // output
    );

// mux status info from the memory controller and other modules    
    status_router8 status_router8_top_i (
        .rst       (axi_rst), // input
        .clk       (mclk), // input
        .db_in0    (status_mcontr_ad), // input[7:0] 
        .rq_in0    (status_mcontr_rq), // input
        .start_in0 (status_mcontr_start), // output
        
        .db_in1    (status_test01_ad), // input[7:0] 
        .rq_in1    (status_test01_rq), // input
        .start_in1 (status_test01_start), // output
        
        .db_in2    (status_membridge_ad), // input[7:0] 
        .rq_in2    (status_membridge_rq), // input
        .start_in2 (status_membridge_start), // output

//        .db_in3    (status_other_ad), // input[7:0] 
//        .rq_in3    (status_other_rq), // input
//        .start_in3 (status_other_start), // output
        
        .db_in3    (status_sensor_ad), // input[7:0] 
        .rq_in3    (status_sensor_rq), // input
        .start_in3 (status_sensor_start), // output
        
        .db_in4    (status_compressor_ad), // input[7:0] 
        .rq_in4    (status_compressor_rq), // input
        .start_in4 (status_compressor_start), // output
        
        .db_in5    (status_sequencer_ad), // input[7:0] 
        .rq_in5    (status_sequencer_rq), // input
        .start_in5 (status_sequencer_start), // output
        
        .db_in6    (status_logger_ad), // input[7:0] 
        .rq_in6    (status_logger_rq), // input
        .start_in6 (status_logger_start), // output
        
        .db_in7    (status_timing_ad), // input[7:0] 
        .rq_in7    (status_timing_rq), // input
        .start_in7 (status_timing_start), // output
        
        .db_out    (status_root_ad), // output[7:0] 
        .rq_out    (status_root_rq), // output
        .start_out (status_root_start) // input
    );

    /* Instance template for module mcntrl393 */
    mcntrl393 #(
        .MCONTR_SENS_BASE('h680),
        .MCONTR_SENS_INC('h10),
        .MCONTR_CMPRS_BASE('h6c0),
        .MCONTR_CMPRS_INC('h10),
        .MCONTR_SENS_STATUS_BASE('h28),
        .MCONTR_SENS_STATUS_INC('h1),
        .MCONTR_CMPRS_STATUS_BASE('h2c),
        .MCONTR_CMPRS_STATUS_INC('h1),
    
        .MCONTR_WR_MASK                    (MCONTR_WR_MASK),
        .MCONTR_RD_MASK                    (MCONTR_RD_MASK),
        .MCONTR_CMD_WR_ADDR                (MCONTR_CMD_WR_ADDR),
        .MCONTR_BUF0_RD_ADDR               (MCONTR_BUF0_RD_ADDR),
        .MCONTR_BUF0_WR_ADDR               (MCONTR_BUF0_WR_ADDR),
        .MCONTR_BUF2_RD_ADDR               (MCONTR_BUF2_RD_ADDR),
        .MCONTR_BUF2_WR_ADDR               (MCONTR_BUF2_WR_ADDR),
        .MCONTR_BUF3_RD_ADDR               (MCONTR_BUF3_RD_ADDR),
        .MCONTR_BUF3_WR_ADDR               (MCONTR_BUF3_WR_ADDR),
        .MCONTR_BUF4_RD_ADDR               (MCONTR_BUF4_RD_ADDR),
        .MCONTR_BUF4_WR_ADDR               (MCONTR_BUF4_WR_ADDR),
        .AXI_WR_ADDR_BITS                  (AXI_WR_ADDR_BITS),
        .AXI_RD_ADDR_BITS                  (AXI_RD_ADDR_BITS),
       
        .DLY_LD                            (DLY_LD),
        .DLY_LD_MASK                       (DLY_LD_MASK),
        .MCONTR_PHY_0BIT_ADDR              (MCONTR_PHY_0BIT_ADDR),
        .MCONTR_PHY_0BIT_ADDR_MASK         (MCONTR_PHY_0BIT_ADDR_MASK),
        .MCONTR_PHY_0BIT_DLY_SET           (MCONTR_PHY_0BIT_DLY_SET),
        .MCONTR_PHY_0BIT_CMDA_EN           (MCONTR_PHY_0BIT_CMDA_EN),
        .MCONTR_PHY_0BIT_SDRST_ACT         (MCONTR_PHY_0BIT_SDRST_ACT),
        .MCONTR_PHY_0BIT_CKE_EN            (MCONTR_PHY_0BIT_CKE_EN),
        .MCONTR_PHY_0BIT_DCI_RST           (MCONTR_PHY_0BIT_DCI_RST),
        .MCONTR_PHY_0BIT_DLY_RST           (MCONTR_PHY_0BIT_DLY_RST),
        .MCONTR_TOP_0BIT_ADDR              (MCONTR_TOP_0BIT_ADDR),
        .MCONTR_TOP_0BIT_ADDR_MASK         (MCONTR_TOP_0BIT_ADDR_MASK),
        .MCONTR_TOP_0BIT_MCONTR_EN         (MCONTR_TOP_0BIT_MCONTR_EN),
        .MCONTR_TOP_0BIT_REFRESH_EN        (MCONTR_TOP_0BIT_REFRESH_EN),
        .MCONTR_PHY_16BIT_ADDR             (MCONTR_PHY_16BIT_ADDR),
        .MCONTR_PHY_16BIT_ADDR_MASK        (MCONTR_PHY_16BIT_ADDR_MASK),
        .MCONTR_PHY_16BIT_PATTERNS         (MCONTR_PHY_16BIT_PATTERNS),
        .MCONTR_PHY_16BIT_PATTERNS_TRI     (MCONTR_PHY_16BIT_PATTERNS_TRI),
        .MCONTR_PHY_16BIT_WBUF_DELAY       (MCONTR_PHY_16BIT_WBUF_DELAY),
        .MCONTR_PHY_16BIT_EXTRA            (MCONTR_PHY_16BIT_EXTRA),
        .MCONTR_PHY_STATUS_CNTRL           (MCONTR_PHY_STATUS_CNTRL),
        .MCONTR_ARBIT_ADDR                 (MCONTR_ARBIT_ADDR),
        .MCONTR_ARBIT_ADDR_MASK            (MCONTR_ARBIT_ADDR_MASK),
        .MCONTR_TOP_16BIT_ADDR             (MCONTR_TOP_16BIT_ADDR),
        .MCONTR_TOP_16BIT_ADDR_MASK        (MCONTR_TOP_16BIT_ADDR_MASK),
        .MCONTR_TOP_16BIT_CHN_EN           (MCONTR_TOP_16BIT_CHN_EN),
        .MCONTR_TOP_16BIT_REFRESH_PERIOD   (MCONTR_TOP_16BIT_REFRESH_PERIOD),
        .MCONTR_TOP_16BIT_REFRESH_ADDRESS  (MCONTR_TOP_16BIT_REFRESH_ADDRESS),
        .MCONTR_TOP_16BIT_STATUS_CNTRL     (MCONTR_TOP_16BIT_STATUS_CNTRL),
        .MCONTR_PHY_STATUS_REG_ADDR        (MCONTR_PHY_STATUS_REG_ADDR),
        .MCONTR_TOP_STATUS_REG_ADDR        (MCONTR_TOP_STATUS_REG_ADDR),
        .CHNBUF_READ_LATENCY               (CHNBUF_READ_LATENCY),
        .DFLT_DQS_PATTERN                  (DFLT_DQS_PATTERN),
        .DFLT_DQM_PATTERN                  (DFLT_DQM_PATTERN),
        .DFLT_DQ_TRI_ON_PATTERN            (DFLT_DQ_TRI_ON_PATTERN),
        .DFLT_DQ_TRI_OFF_PATTERN           (DFLT_DQ_TRI_OFF_PATTERN),
        .DFLT_DQS_TRI_ON_PATTERN           (DFLT_DQS_TRI_ON_PATTERN),
        .DFLT_DQS_TRI_OFF_PATTERN          (DFLT_DQS_TRI_OFF_PATTERN),
        .DFLT_WBUF_DELAY                   (DFLT_WBUF_DELAY),
        .DFLT_INV_CLK_DIV                  (DFLT_INV_CLK_DIV),
        .DFLT_CHN_EN                       (DFLT_CHN_EN),
        .DFLT_REFRESH_ADDR                 (DFLT_REFRESH_ADDR),
        .DFLT_REFRESH_PERIOD               (DFLT_REFRESH_PERIOD),
        .ADDRESS_NUMBER                    (ADDRESS_NUMBER),
        .COLADDR_NUMBER                    (COLADDR_NUMBER),
        .PHASE_WIDTH                       (PHASE_WIDTH),
        .SLEW_DQ                           (SLEW_DQ),
        .SLEW_DQS                          (SLEW_DQS),
        .SLEW_CMDA                         (SLEW_CMDA),
        .SLEW_CLK                          (SLEW_CLK),
        .IBUF_LOW_PWR                      (IBUF_LOW_PWR),
        .REFCLK_FREQUENCY                  (REFCLK_FREQUENCY),
        .HIGH_PERFORMANCE_MODE             (HIGH_PERFORMANCE_MODE),
        .CLKIN_PERIOD                      (CLKIN_PERIOD),
        .CLKFBOUT_MULT                     (CLKFBOUT_MULT),
        .CLKFBOUT_MULT_REF                 (CLKFBOUT_MULT_REF),
        .CLKFBOUT_DIV_REF                  (CLKFBOUT_DIV_REF),
        .DIVCLK_DIVIDE                     (DIVCLK_DIVIDE),
        .CLKFBOUT_PHASE                    (CLKFBOUT_PHASE),
        .SDCLK_PHASE                       (SDCLK_PHASE),
        .CLK_PHASE                         (CLK_PHASE),
        .CLK_DIV_PHASE                     (CLK_DIV_PHASE),
        .MCLK_PHASE                        (MCLK_PHASE),
        .REF_JITTER1                       (REF_JITTER1),
        .SS_EN                             (SS_EN),
        .SS_MODE                           (SS_MODE),
        .SS_MOD_PERIOD                     (SS_MOD_PERIOD),
        .CMD_PAUSE_BITS                    (CMD_PAUSE_BITS),
        .CMD_DONE_BIT                      (CMD_DONE_BIT),
        
        .MCNTRL_PS_ADDR                    (MCNTRL_PS_ADDR),
        .MCNTRL_PS_MASK                    (MCNTRL_PS_MASK),
        .MCNTRL_PS_STATUS_REG_ADDR         (MCNTRL_PS_STATUS_REG_ADDR),
        .MCNTRL_PS_EN_RST                  (MCNTRL_PS_EN_RST),
        .MCNTRL_PS_CMD                     (MCNTRL_PS_CMD),
        .MCNTRL_PS_STATUS_CNTRL            (MCNTRL_PS_STATUS_CNTRL),
        .NUM_XFER_BITS                     (NUM_XFER_BITS),
        .FRAME_WIDTH_BITS                  (FRAME_WIDTH_BITS),
        .FRAME_HEIGHT_BITS                 (FRAME_HEIGHT_BITS),
        .LAST_FRAME_BITS                   (LAST_FRAME_BITS),
        .MCNTRL_SCANLINE_CHN1_ADDR         (MCNTRL_SCANLINE_CHN1_ADDR),
        .MCNTRL_SCANLINE_CHN3_ADDR         (MCNTRL_SCANLINE_CHN3_ADDR),
        .MCNTRL_SCANLINE_MASK              (MCNTRL_SCANLINE_MASK),
        .MCNTRL_SCANLINE_MODE              (MCNTRL_SCANLINE_MODE),
        .MCNTRL_SCANLINE_STATUS_CNTRL      (MCNTRL_SCANLINE_STATUS_CNTRL),
        .MCNTRL_SCANLINE_STARTADDR         (MCNTRL_SCANLINE_STARTADDR),
        .MCNTRL_SCANLINE_FRAME_FULL_WIDTH  (MCNTRL_SCANLINE_FRAME_FULL_WIDTH),
        .MCNTRL_SCANLINE_WINDOW_WH         (MCNTRL_SCANLINE_WINDOW_WH),
        .MCNTRL_SCANLINE_WINDOW_X0Y0       (MCNTRL_SCANLINE_WINDOW_X0Y0),
        .MCNTRL_SCANLINE_WINDOW_STARTXY    (MCNTRL_SCANLINE_WINDOW_STARTXY),
        .MCNTRL_SCANLINE_STATUS_REG_CHN1_ADDR   (MCNTRL_SCANLINE_STATUS_REG_CHN1_ADDR),
        .MCNTRL_SCANLINE_STATUS_REG_CHN3_ADDR   (MCNTRL_SCANLINE_STATUS_REG_CHN3_ADDR),
        .MCNTRL_SCANLINE_PENDING_CNTR_BITS (MCNTRL_SCANLINE_PENDING_CNTR_BITS),
        .MCNTRL_SCANLINE_FRAME_PAGE_RESET  (MCNTRL_SCANLINE_FRAME_PAGE_RESET),
        .MAX_TILE_WIDTH                    (MAX_TILE_WIDTH),
        .MAX_TILE_HEIGHT                   (MAX_TILE_HEIGHT),
        .MCNTRL_TILED_CHN2_ADDR            (MCNTRL_TILED_CHN2_ADDR),
        .MCNTRL_TILED_CHN4_ADDR            (MCNTRL_TILED_CHN4_ADDR),
        .MCNTRL_TILED_MASK                 (MCNTRL_TILED_MASK),
        .MCNTRL_TILED_MODE                 (MCNTRL_TILED_MODE),
        .MCNTRL_TILED_STATUS_CNTRL         (MCNTRL_TILED_STATUS_CNTRL),
        .MCNTRL_TILED_STARTADDR            (MCNTRL_TILED_STARTADDR),
        .MCNTRL_TILED_FRAME_FULL_WIDTH     (MCNTRL_TILED_FRAME_FULL_WIDTH),
        .MCNTRL_TILED_WINDOW_WH            (MCNTRL_TILED_WINDOW_WH),
        .MCNTRL_TILED_WINDOW_X0Y0          (MCNTRL_TILED_WINDOW_X0Y0),
        .MCNTRL_TILED_WINDOW_STARTXY       (MCNTRL_TILED_WINDOW_STARTXY),
        .MCNTRL_TILED_TILE_WHS             (MCNTRL_TILED_TILE_WHS),
        .MCNTRL_TILED_STATUS_REG_CHN2_ADDR (MCNTRL_TILED_STATUS_REG_CHN2_ADDR),
        .MCNTRL_TILED_STATUS_REG_CHN4_ADDR (MCNTRL_TILED_STATUS_REG_CHN4_ADDR),
        .MCNTRL_TILED_PENDING_CNTR_BITS    (MCNTRL_TILED_PENDING_CNTR_BITS),
        .MCNTRL_TILED_FRAME_PAGE_RESET     (MCNTRL_TILED_FRAME_PAGE_RESET),
        .BUFFER_DEPTH32                    (BUFFER_DEPTH32),
        .RSEL                              (RSEL),
        .WSEL                              (WSEL)
    ) mcntrl393_i (
        .rst_in                    (axi_rst), // input
        .clk_in                    (axi_aclk), // == axird_bram_rclk SuppressThisWarning VivadoSynthesis: [Synth 8-3295] tying undriven pin #mcntrl393_i:clk_in to constant 0
        .mclk                      (mclk), // output
        .ref_clk                   (ref_clk), // output
        .cmd_ad                    (cmd_mcontr_ad), // input[7:0] 
        .cmd_stb                   (cmd_mcontr_stb), // input
        .status_ad                 (status_mcontr_ad[7:0]), // output[7:0]
        .status_rq                 (status_mcontr_rq),   // input request to send status downstream
        .status_start              (status_mcontr_start), // Acknowledge of the first status packet byte (address)
        
        .axi_clk                   (axird_bram_rclk), // ==axi_aclk, // input - same?
        .axiwr_pre_awaddr          (axiwr_pre_awaddr), // input[12:0] // SuppressThisWarning VivadoSynthesis: [Synth 8-3295] tying undriven pin #mcntrl393_i:axiwr_pre_awaddr[9:0] to constant 0
        .axiwr_start_burst         (axiwr_start_burst), // input
        .axiwr_waddr               (axiwr_waddr[BUFFER_DEPTH32-1:0]), // input[9:0] 
        .axiwr_wen                 (axiwr_wen), // input
        .axiwr_data                (axiwr_wdata), // input[31:0] 
        
        .axird_pre_araddr          (axird_pre_araddr), // input[12:0] // SuppressThisWarning VivadoSynthesis: [Synth 8-3295] tying undriven pin #mcntrl393_i:axird_pre_araddr[9:0] to constant 0 (seems to be unused, not undriven) 
        .axird_start_burst         (axird_start_burst), // input
        .axird_raddr               (axird_raddr[BUFFER_DEPTH32-1:0]), // input[9:0] 
        .axird_ren                 (axird_ren), // input
        .axird_regen               (axird_regen), // input
        .axird_rdata               (mcntrl_axird_rdata), // output[31:0]
        .axird_selected            (mcntrl_axird_selected), // output 

// sensors interface
        .sens_rpage_set            (sens_rpage_set),             // output[3:0] 
        .sens_rpage_next           (sens_rpage_next),            // output[3:0] 
        .sens_buf_rd               (sens_buf_rd),                // output[3:0] 
        .sens_buf_dout             (sens_buf_dout),              // input[255:0] 


// compressor interface
        .cmprs_xfer_reset_page_rd  (cmprs_xfer_reset_page_rd),   // output[3:0] 
        .cmprs_buf_wpage_nxt       (cmprs_buf_wpage_nxt),        // output[3:0] 
        .cmprs_buf_we              (cmprs_buf_we),               // output[3:0] 
        .cmprs_buf_din             (cmprs_buf_din),              // output[255:0] 
        .cmprs_page_ready          (cmprs_page_ready),           // output[3:0] 
        .cmprs_next_page           (cmprs_next_page),            // input[3:0] 
        .cmprs_frame_start_dst     (cmprs_frame_start_dst),      // input[3:0] 
        .cmprs_line_unfinished_src (cmprs_line_unfinished_src),  // output[63:0] 
        .cmprs_frame_number_src    (cmprs_frame_number_src),     // output[63:0] 
        .cmprs_frame_done_src      (cmprs_frame_done_src),       // output[3:0] 
        .cmprs_line_unfinished_dst (cmprs_line_unfinished_dst),  // output[63:0] 
        .cmprs_frame_number_dst    (cmprs_frame_number_dst),     // output[63:0] 
        .cmprs_frame_done_dst      (cmprs_frame_done_dst),       // output[3:0] 
        .cmprs_suspend             (cmprs_suspend),              // input[3:0] 
        
 // Originally implemented channels, some are just for testing and may be replaced        
        .frame_start_chn1          (frame_start_chn1),           // input
        .next_page_chn1            (next_page_chn1),             // input
        .cmd_wrmem_chn1            (cmd_wrmem_chn1),             // output
        .page_ready_chn1           (page_ready_chn1),            // output
        .frame_done_chn1           (frame_done_chn1),            // output
        .line_unfinished_chn1      (line_unfinished_chn1),       // output[15:0]
        .suspend_chn1              (suspend_chn1),               // input
        .xfer_reset_page1_rd       (xfer_reset_page1_rd),        // output
        .buf_wpage_nxt_chn1        (buf_wpage_nxt_chn1),         // output
        .buf_wr_chn1               (buf_wr_chn1),                // output
        .buf_wdata_chn1            (buf_wdata_chn1[63:0]),       // output[63:0] 
        .xfer_reset_page1_wr       (xfer_reset_page1_wr),        // output
        .rpage_nxt_chn1            (rpage_nxt_chn1),             // output
        .buf_rd_chn1               (buf_rd_chn1),                // output
        .buf_rdata_chn1            (buf_rdata_chn1[63:0]),       // input[63:0] 
        
        .frame_start_chn2          (frame_start_chn2),           // input
        .next_page_chn2            (next_page_chn2),             // input
        .page_ready_chn2           (page_ready_chn2),            // output
        .frame_done_chn2           (frame_done_chn2),            // output
        .line_unfinished_chn2      (line_unfinished_chn2),       // output[15:0]
        .frame_number_chn2         (frame_number_chn2),          // output[15:0]  
        .suspend_chn2              (suspend_chn2),               // input
        
        .frame_start_chn3          (frame_start_chn3),           // input
        .next_page_chn3            (next_page_chn3),             // input
        .page_ready_chn3           (page_ready_chn3),            // output
        .frame_done_chn3           (frame_done_chn3),            // output
        .line_unfinished_chn3      (line_unfinished_chn3),       // output[15:0] 
        .frame_number_chn3         (frame_number_chn3),          // output[15:0]  
        .suspend_chn3              (suspend_chn3),               // input
        
        .frame_start_chn4          (frame_start_chn4),           // input
        .next_page_chn4            (next_page_chn4),             // input
        .page_ready_chn4           (page_ready_chn4),            // output
        .frame_done_chn4           (frame_done_chn4),            // output
        .line_unfinished_chn4      (line_unfinished_chn4),       // output[15:0]
        .frame_number_chn4         (frame_number_chn4),          // output[15:0]  
        .suspend_chn4              (suspend_chn4),               // input

        .SDRST                     (SDRST),                      // output
        .SDCLK                     (SDCLK),                      // output
        .SDNCLK                    (SDNCLK),                     // output
        .SDA                       (SDA),                        // output[14:0] 
        .SDBA                      (SDBA),                       // output[2:0] 
        .SDWE                      (SDWE),                       // output
        .SDRAS                     (SDRAS),                      // output
        .SDCAS                     (SDCAS),                      // output
        .SDCKE                     (SDCKE),                      // output
        .SDODT                     (SDODT),                      // output
        .SDD                       (SDD),                        // inout[15:0] 
        .SDDML                     (SDDML),                      // output
        .DQSL                      (DQSL),                       // inout
        .NDQSL                     (NDQSL),                      // inout
        .SDDMU                     (SDDMU),                      // output
        .DQSU                      (DQSU),                       // inout
        .NDQSU                     (NDQSU),                      // inout
        .tmp_debug                 (tmp_debug)                   // output[11:0] 
    );
    // AFI0 (AXI_HP0) signals
    wire [31:0] afi0_awaddr;   // output[31:0]
    wire        afi0_awvalid;  // output
    wire        afi0_awready;     // input
    wire [ 5:0] afi0_awid;     // output[5:0] 
    wire [ 1:0] afi0_awlock;     // output[1:0] 
    wire [ 3:0] afi0_awcache;     // output[3:0] 
    wire [ 2:0] afi0_awprot;     // output[2:0] 
    wire [ 3:0] afi0_awlen;     // output[3:0] 
    wire [ 2:0] afi0_awsize;     // output[2:0] 
    wire [ 1:0] afi0_awburst;     // output[1:0] 
    wire [ 3:0] afi0_awqos;     // output[3:0] 
    wire [63:0] afi0_wdata;     // output[63:0] 
    wire        afi0_wvalid;     // output
    wire        afi0_wready;     // input
    wire [ 5:0] afi0_wid;     // output[5:0] 
    wire        afi0_wlast;     // output
    wire [ 7:0] afi0_wstrb;     // output[7:0] 
    wire        afi0_bvalid;     // input
    wire        afi0_bready;     // output
    wire [ 5:0] afi0_bid;     // input[5:0] 
    wire [ 1:0] afi0_bresp;     // input[1:0] 
    wire [ 7:0] afi0_wcount;     // input[7:0] 
    wire [ 5:0] afi0_wacount;     // input[5:0] 
    wire        afi0_wrissuecap1en;     // output
    wire [31:0] afi0_araddr;     // output[31:0] 
    wire        afi0_arvalid;     // output
    wire        afi0_arready;     // input
    wire [ 5:0] afi0_arid;     // output[5:0] 
    wire [ 1:0] afi0_arlock;     // output[1:0] 
    wire [ 3:0] afi0_arcache;     // output[3:0] 
    wire [ 2:0] afi0_arprot;     // output[2:0] 
    wire [ 3:0] afi0_arlen;     // output[3:0] 
    wire [ 2:0] afi0_arsize;     // output[2:0] 
    wire [ 1:0] afi0_arburst;     // output[1:0] 
    wire [ 3:0] afi0_arqos;     // output[3:0] 
    wire [63:0] afi0_rdata;     // input[63:0] 
    wire        afi0_rvalid;     // input
    wire        afi0_rready;     // output
    wire [ 5:0] afi0_rid;     // input[5:0] 
    wire        afi0_rlast;     // input
    wire [ 1:0] afi0_rresp;     // input[2:0] 
    wire [ 7:0] afi0_rcount;     // input[7:0] 
    wire [ 2:0] afi0_racount;     // input[2:0] 
    wire        afi0_rdissuecap1en; // output





    // DDR3 frame memory to system memory bridge over axi_hp
    membridge #(
        .MEMBRIDGE_ADDR         (MEMBRIDGE_ADDR),
        .MEMBRIDGE_MASK         (MEMBRIDGE_MASK),
        .MEMBRIDGE_CTRL         (MEMBRIDGE_CTRL),
        .MEMBRIDGE_STATUS_CNTRL (MEMBRIDGE_STATUS_CNTRL),
        .MEMBRIDGE_LO_ADDR64    (MEMBRIDGE_LO_ADDR64),
        .MEMBRIDGE_SIZE64       (MEMBRIDGE_SIZE64),
        .MEMBRIDGE_START64      (MEMBRIDGE_START64),
        .MEMBRIDGE_LEN64        (MEMBRIDGE_LEN64),
        .MEMBRIDGE_WIDTH64      (MEMBRIDGE_WIDTH64),
        .MEMBRIDGE_MODE         (MEMBRIDGE_MODE),
        .MEMBRIDGE_STATUS_REG   (MEMBRIDGE_STATUS_REG),
        .FRAME_HEIGHT_BITS      (FRAME_HEIGHT_BITS),
        .FRAME_WIDTH_BITS       (FRAME_WIDTH_BITS)
    ) membridge_i (
        .rst                    (axi_rst), // input
        .mclk                   (mclk), // input
        .hclk                   (hclk), // input
        .cmd_ad                 (cmd_membridge_ad), // input[7:0] 
        .cmd_stb                (cmd_membridge_stb), // input
        .status_ad              (status_membridge_ad[7:0]), // output[7:0] 
        .status_rq              (status_membridge_rq),      // output
        .status_start           (status_membridge_start),   // input
        .frame_start_chn        (frame_start_chn1),     // output
        .next_page_chn          (next_page_chn1),       // output
        .cmd_wrmem              (cmd_wrmem_chn1),       // input
        .page_ready_chn         (page_ready_chn1),      // input
        .frame_done_chn         (frame_done_chn1),      // input
        .line_unfinished_chn1   (line_unfinished_chn1), // input[15:0] 
        .suspend_chn1           (suspend_chn1),         // output
        .xfer_reset_page_rd     (xfer_reset_page1_rd),  // input
        .buf_wpage_nxt          (buf_wpage_nxt_chn1),   // input
        .buf_wr                 (buf_wr_chn1),          // input
        .buf_wdata              (buf_wdata_chn1[63:0]), // input[63:0] 
        .xfer_reset_page_wr     (xfer_reset_page1_wr),  // input
        .buf_rpage_nxt          (rpage_nxt_chn1),       // input
        .buf_rd                 (buf_rd_chn1),          // input
        .buf_rdata              (buf_rdata_chn1[63:0]), // output[63:0] 
        .afi_awaddr             (afi0_awaddr), // output[31:0] 
        .afi_awvalid            (afi0_awvalid), // output
        .afi_awready            (afi0_awready), // input
        .afi_awid               (afi0_awid), // output[5:0] 
        .afi_awlock             (afi0_awlock), // output[1:0] 
        .afi_awcache            (afi0_awcache), // output[3:0] 
        .afi_awprot             (afi0_awprot), // output[2:0] 
        .afi_awlen              (afi0_awlen), // output[3:0] 
        .afi_awsize             (afi0_awsize), // output[2:0] 
        .afi_awburst            (afi0_awburst), // output[1:0] 
        .afi_awqos              (afi0_awqos), // output[3:0] 
        .afi_wdata              (afi0_wdata), // output[63:0] 
        .afi_wvalid             (afi0_wvalid), // output
        .afi_wready             (afi0_wready), // input
        .afi_wid                (afi0_wid), // output[5:0] 
        .afi_wlast              (afi0_wlast), // output
        .afi_wstrb              (afi0_wstrb), // output[7:0] 
        .afi_bvalid             (afi0_bvalid), // input
        .afi_bready             (afi0_bready), // output
        .afi_bid                (afi0_bid), // input[5:0] 
        .afi_bresp              (afi0_bresp), // input[1:0] 
        .afi_wcount             (afi0_wcount), // input[7:0] 
        .afi_wacount            (afi0_wacount), // input[5:0] 
        .afi_wrissuecap1en      (afi0_wrissuecap1en), // output
        .afi_araddr             (afi0_araddr), // output[31:0] 
        .afi_arvalid            (afi0_arvalid), // output
        .afi_arready            (afi0_arready), // input
        .afi_arid               (afi0_arid), // output[5:0] 
        .afi_arlock             (afi0_arlock), // output[1:0] 
        .afi_arcache            (afi0_arcache), // output[3:0] 
        .afi_arprot             (afi0_arprot), // output[2:0] 
        .afi_arlen              (afi0_arlen), // output[3:0] 
        .afi_arsize             (afi0_arsize), // output[2:0] 
        .afi_arburst            (afi0_arburst), // output[1:0] 
        .afi_arqos              (afi0_arqos), // output[3:0] 
        .afi_rdata              (afi0_rdata), // input[63:0] 
        .afi_rvalid             (afi0_rvalid), // input
        .afi_rready             (afi0_rready), // output
        .afi_rid                (afi0_rid), // input[5:0] 
        .afi_rlast              (afi0_rlast), // input
        .afi_rresp              (afi0_rresp), // input[2:0] 
        .afi_rcount             (afi0_rcount), // input[7:0] 
        .afi_racount            (afi0_racount), // input[2:0] 
        .afi_rdissuecap1en      (afi0_rdissuecap1en) // output
    );
    
    // SAXIGP0 signals
    
    wire        saxi0_aclk     = hclk; // 150KHz
    wire [31:0] saxi0_awaddr;
    wire        saxi0_awvalid;
    wire        saxi0_awready;
    wire [ 5:0] saxi0_awid; 
    wire [ 1:0] saxi0_awlock; 
    wire [ 3:0] saxi0_awcache; 
    wire [ 2:0] saxi0_awprot; 
    wire [ 3:0] saxi0_awlen; 
    wire [ 1:0] saxi0_awsize; 
    wire [ 1:0] saxi0_awburst; 
    wire [ 3:0] saxi0_awqos; 
    wire [31:0] saxi0_wdata; 
    wire        saxi0_wvalid;
    wire        saxi0_wready;
    wire [ 5:0] saxi0_wid; 
    wire        saxi0_wlast;
    wire [ 3:0] saxi0_wstrb; 
    wire        saxi0_bvalid;
    wire        saxi0_bready;
    wire [ 5:0] saxi0_bid; 
    wire [ 1:0] saxi0_bresp; 

    sensors393 #(
        .SENSOR_GROUP_ADDR          (SENSOR_GROUP_ADDR),
        .SENSOR_BASE_INC            (SENSOR_BASE_INC),
        .HIST_SAXI_ADDR_REL         (HIST_SAXI_ADDR_REL),
        .HIST_SAXI_MODE_ADDR_REL    (HIST_SAXI_MODE_ADDR_REL),
        .SENSI2C_STATUS_REG_BASE    (SENSI2C_STATUS_REG_BASE),
        .SENSI2C_STATUS_REG_INC     (SENSI2C_STATUS_REG_INC),
        .SENSI2C_STATUS_REG_REL     (SENSI2C_STATUS_REG_REL),
        .SENSIO_STATUS_REG_REL      (SENSIO_STATUS_REG_REL),
        .SENSOR_NUM_HISTOGRAM       (SENSOR_NUM_HISTOGRAM),
        .HISTOGRAM_RAM_MODE         (HISTOGRAM_RAM_MODE),
        .SENS_GAMMA_NUM_CHN         (SENS_GAMMA_NUM_CHN),
        .SENS_GAMMA_BUFFER          (SENS_GAMMA_BUFFER),
        .SENSOR_CTRL_RADDR          (SENSOR_CTRL_RADDR),
        .SENSOR_CTRL_ADDR_MASK      (SENSOR_CTRL_ADDR_MASK),
        .SENSOR_MODE_WIDTH          (SENSOR_MODE_WIDTH),
        .SENSOR_HIST_EN_BIT         (SENSOR_HIST_EN_BIT),
        .SENSOR_HIST_NRST_BIT       (SENSOR_HIST_NRST_BIT),
        .SENSOR_16BIT_BIT           (SENSOR_16BIT_BIT),
        .SENSI2C_CTRL_RADDR         (SENSI2C_CTRL_RADDR),
        .SENSI2C_CTRL_MASK          (SENSI2C_CTRL_MASK),
        .SENSI2C_CTRL               (SENSI2C_CTRL),
        .SENSI2C_STATUS             (SENSI2C_STATUS),
        .SENS_SYNC_RADDR            (SENS_SYNC_RADDR),
        .SENS_SYNC_MASK             (SENS_SYNC_MASK),
        .SENS_SYNC_MULT             (SENS_SYNC_MULT),
        .SENS_SYNC_LATE             (SENS_SYNC_LATE),
        .SENS_GAMMA_RADDR           (SENS_GAMMA_RADDR),
        .SENS_GAMMA_ADDR_MASK       (SENS_GAMMA_ADDR_MASK),
        .SENS_GAMMA_CTRL            (SENS_GAMMA_CTRL),
        .SENS_GAMMA_ADDR_DATA       (SENS_GAMMA_ADDR_DATA),
        .SENS_GAMMA_HEIGHT01        (SENS_GAMMA_HEIGHT01),
        .SENS_GAMMA_HEIGHT2         (SENS_GAMMA_HEIGHT2),
        .SENS_GAMMA_MODE_WIDTH      (SENS_GAMMA_MODE_WIDTH),
        .SENS_GAMMA_MODE_BAYER      (SENS_GAMMA_MODE_BAYER),
        .SENS_GAMMA_MODE_PAGE       (SENS_GAMMA_MODE_PAGE),
        .SENS_GAMMA_MODE_EN         (SENS_GAMMA_MODE_EN),
        .SENS_GAMMA_MODE_REPET      (SENS_GAMMA_MODE_REPET),
        .SENS_GAMMA_MODE_TRIG       (SENS_GAMMA_MODE_TRIG),
        .SENSIO_RADDR               (SENSIO_RADDR),
        .SENSIO_ADDR_MASK           (SENSIO_ADDR_MASK),
        .SENSIO_CTRL                (SENSIO_CTRL),
        .SENS_CTRL_MRST             (SENS_CTRL_MRST),
        .SENS_CTRL_ARST             (SENS_CTRL_ARST),
        .SENS_CTRL_ARO              (SENS_CTRL_ARO),
        .SENS_CTRL_RST_MMCM         (SENS_CTRL_RST_MMCM),
        .SENS_CTRL_EXT_CLK          (SENS_CTRL_EXT_CLK),
        .SENS_CTRL_LD_DLY           (SENS_CTRL_LD_DLY),
        .SENS_CTRL_QUADRANTS        (SENS_CTRL_QUADRANTS),
        .SENSIO_STATUS              (SENSIO_STATUS),
        .SENSIO_JTAG                (SENSIO_JTAG),
        .SENS_JTAG_PGMEN            (SENS_JTAG_PGMEN),
        .SENS_JTAG_PROG             (SENS_JTAG_PROG),
        .SENS_JTAG_TCK              (SENS_JTAG_TCK),
        .SENS_JTAG_TMS              (SENS_JTAG_TMS),
        .SENS_JTAG_TDI              (SENS_JTAG_TDI),
        .SENSIO_WIDTH               (SENSIO_WIDTH),
        .SENSIO_DELAYS              (SENSIO_DELAYS),
        .SENSI2C_ABS_RADDR          (SENSI2C_ABS_RADDR),
        .SENSI2C_REL_RADDR          (SENSI2C_REL_RADDR),
        .SENSI2C_ADDR_MASK          (SENSI2C_ADDR_MASK),
        .HISTOGRAM_RADDR0           (HISTOGRAM_RADDR0),
        .HISTOGRAM_RADDR1           (HISTOGRAM_RADDR1),
        .HISTOGRAM_RADDR2           (HISTOGRAM_RADDR2),
        .HISTOGRAM_RADDR3           (HISTOGRAM_RADDR3),
        .HISTOGRAM_ADDR_MASK        (HISTOGRAM_ADDR_MASK),
        .HISTOGRAM_LEFT_TOP         (HISTOGRAM_LEFT_TOP),
        .HISTOGRAM_WIDTH_HEIGHT     (HISTOGRAM_WIDTH_HEIGHT),
        .SENSI2C_DRIVE              (SENSI2C_DRIVE),
        .SENSI2C_IBUF_LOW_PWR       (SENSI2C_IBUF_LOW_PWR),
        .SENSI2C_IOSTANDARD         (SENSI2C_IOSTANDARD),
        .SENSI2C_SLEW               (SENSI2C_SLEW),
        .SENSOR_DATA_WIDTH          (SENSOR_DATA_WIDTH),
        .SENSOR_FIFO_2DEPTH         (SENSOR_FIFO_2DEPTH),
        .SENSOR_FIFO_DELAY          (SENSOR_FIFO_DELAY),
        .HIST_SAXI_ADDR_MASK        (HIST_SAXI_ADDR_MASK),
        .HIST_SAXI_MODE_WIDTH       (HIST_SAXI_MODE_WIDTH),
        .HIST_SAXI_EN               (HIST_SAXI_EN),
        .HIST_SAXI_NRESET           (HIST_SAXI_NRESET),
        .HIST_CONFIRM_WRITE         (HIST_CONFIRM_WRITE),
        .HIST_SAXI_AWCACHE          (HIST_SAXI_AWCACHE),
        .HIST_SAXI_MODE_ADDR_MASK   (HIST_SAXI_MODE_ADDR_MASK),
        .NUM_FRAME_BITS             (NUM_FRAME_BITS),
        .SENS_SYNC_FBITS            (SENS_SYNC_FBITS),
        .SENS_SYNC_LBITS            (SENS_SYNC_LBITS),
        .SENS_SYNC_LATE_DFLT        (SENS_SYNC_LATE_DFLT),
        .SENS_SYNC_MINBITS          (SENS_SYNC_MINBITS),
        .SENS_SYNC_MINPER           (SENS_SYNC_MINPER),
        .IDELAY_VALUE               (IDELAY_VALUE),
        .PXD_DRIVE                  (PXD_DRIVE),
        .PXD_IBUF_LOW_PWR           (PXD_IBUF_LOW_PWR),
        .PXD_IOSTANDARD             (PXD_IOSTANDARD),
        .PXD_SLEW                   (PXD_SLEW),
        .SENS_REFCLK_FREQUENCY      (SENS_REFCLK_FREQUENCY),
        .SENS_HIGH_PERFORMANCE_MODE (SENS_HIGH_PERFORMANCE_MODE),
        .SENS_PHASE_WIDTH           (SENS_PHASE_WIDTH),
        .SENS_PCLK_PERIOD           (SENS_PCLK_PERIOD),
        .SENS_BANDWIDTH             (SENS_BANDWIDTH),
        .CLKFBOUT_MULT_SENSOR       (CLKFBOUT_MULT_SENSOR),
        .CLKFBOUT_PHASE_SENSOR      (CLKFBOUT_PHASE_SENSOR),
        .IPCLK_PHASE                (IPCLK_PHASE),
        .IPCLK2X_PHASE              (IPCLK2X_PHASE),
        .SENS_DIVCLK_DIVIDE         (SENS_DIVCLK_DIVIDE),
        .SENS_REF_JITTER1           (SENS_REF_JITTER1),
        .SENS_REF_JITTER2           (SENS_REF_JITTER2),
        .SENS_SS_EN                 (SENS_SS_EN),
        .SENS_SS_MODE               (SENS_SS_MODE),
        .SENS_SS_MOD_PERIOD         (SENS_SS_MOD_PERIOD)
    ) sensors393_i (
        .rst                (axi_rst),             // input
        .pclk               (pclk),                //  input
        .pclk2x             (pclk2x),              // input
        .ref_clk            (ref_clk),             // input
        .dly_rst            (axi_rst),             // input
        .mclk               (mclk),                // input
        .cmd_ad_in          (cmd_sensor_ad),       // input[7:0] 
        .cmd_stb_in         (cmd_sensor_stb),      // input
        .status_ad          (status_sensor_ad),    // output[7:0] 
        .status_rq          (status_sensor_rq),    // output
        .status_start       (status_sensor_start), // input
        .sns1_dp            (sns1_dp),             // inout[7:0] 
        .sns1_dn            (sns1_dn),             // inout[7:0] 
        .sns1_clkp          (sns1_clkp),           // inout
        .sns1_clkn          (sns1_clkn),           // inout
        .sns1_scl           (sns1_scl),            // inout
        .sns1_sda           (sns1_sda),            // inout
        .sns1_ctl           (sns1_ctl),            // inout
        .sns1_pg            (sns1_pg),             // inout

        .sns2_dp            (sns2_dp),             // inout[7:0] 
        .sns2_dn            (sns2_dn),             // inout[7:0] 
        .sns2_clkp          (sns2_clkp),           // inout
        .sns2_clkn          (sns2_clkn),           // inout
        .sns2_scl           (sns2_scl),            // inout
        .sns2_sda           (sns2_sda),            // inout
        .sns2_ctl           (sns2_ctl),            // inout
        .sns2_pg            (sns2_pg),             // inout

        .sns3_dp            (sns3_dp),             // inout[7:0] 
        .sns3_dn            (sns3_dn),             // inout[7:0] 
        .sns3_clkp          (sns3_clkp),           // inout
        .sns3_clkn          (sns3_clkn),           // inout
        .sns3_scl           (sns3_scl),            // inout
        .sns3_sda           (sns3_sda),            // inout
        .sns3_ctl           (sns3_ctl),            // inout
        .sns3_pg            (sns3_pg),             // inout

        .sns4_dp            (sns4_dp),             // inout[7:0] 
        .sns4_dn            (sns4_dn),             // inout[7:0] 
        .sns4_clkp          (sns4_clkp),           // inout
        .sns4_clkn          (sns4_clkn),           // inout
        .sns4_scl           (sns4_scl),            // inout
        .sns4_sda           (sns4_sda),            // inout
        .sns4_ctl           (sns4_ctl),            // inout
        .sns4_pg            (sns4_pg),             // inout

        .rpage_set         (sens_rpage_set),          // input
        .rpage_next        (sens_rpage_next),         // input
        .buf_rd            (sens_buf_rd),             // input
        .buf_dout          (sens_buf_dout),           // output[63:0] 
        
        .trigger_mode       (trigger_mode),        // input
        .trig_in            (trig_in),             // input[3:0] 
        
        .sof_out_pclk       (sof_out_pclk),        // output[3:0] 
        .eof_out_pclk       (eof_out_pclk),        // output[3:0] 
        .sof_out_mclk       (sof_out_mclk),        // output[3:0] 
        .sof_late_mclk      (sof_late_mclk),       // output[3:0] 
        
        .frame_num0         (frame_num0),          // input[3:0] 
        .frame_num1         (frame_num1),          // input[3:0] 
        .frame_num2         (frame_num2),          // input[3:0] 
        .frame_num3         (frame_num3),          // input[3:0] 
        
        .aclk               (saxi0_aclk),          // input
        .saxi_awaddr        (saxi0_awaddr),        // output[31:0] 
        .saxi_awvalid       (saxi0_awvalid),       // output
        .saxi_awready       (saxi0_awready),       // input
        .saxi_awid          (saxi0_awid),          // output[5:0] 
        .saxi_awlock        (saxi0_awlock),        // output[1:0] 
        .saxi_awcache       (saxi0_awcache),       // output[3:0] 
        .saxi_awprot        (saxi0_awprot),        // output[2:0] 
        .saxi_awlen         (saxi0_awlen),         // output[3:0] 
        .saxi_awsize        (saxi0_awsize),        // output[1:0] 
        .saxi_awburst       (saxi0_awburst),       // output[1:0] 
        .saxi_awqos         (saxi0_awqos),         // output[3:0] 
        .saxi_wdata         (saxi0_wdata),         // output[31:0] 
        .saxi_wvalid        (saxi0_wvalid),        // output
        .saxi_wready        (saxi0_wready),        // input
        .saxi_wid           (saxi0_wid),           // output[5:0] 
        .saxi_wlast         (saxi0_wlast),         // output
        .saxi_wstrb         (saxi0_wstrb),         // output[3:0] 
        .saxi_bvalid        (saxi0_bvalid),        // input
        .saxi_bready        (saxi0_bready),        // output
        .saxi_bid           (saxi0_bid),           // input[5:0] 
        .saxi_bresp         (saxi0_bresp)          // input[1:0] 
    );

    // AFI1 (AXI_HP1) signals - write channels only
    wire [31:0] afi1_awaddr;   // output[31:0]
    wire        afi1_awvalid;  // output
    wire        afi1_awready;     // input
    wire [ 5:0] afi1_awid;     // output[5:0] 
    wire [ 1:0] afi1_awlock;     // output[1:0] 
    wire [ 3:0] afi1_awcache;     // output[3:0] 
    wire [ 2:0] afi1_awprot;     // output[2:0] 
    wire [ 3:0] afi1_awlen;     // output[3:0] 
    wire [ 2:0] afi1_awsize;     // output[2:0] 
    wire [ 1:0] afi1_awburst;     // output[1:0] 
    wire [ 3:0] afi1_awqos;     // output[3:0] 
    wire [63:0] afi1_wdata;     // output[63:0] 
    wire        afi1_wvalid;     // output
    wire        afi1_wready;     // input
    wire [ 5:0] afi1_wid;     // output[5:0] 
    wire        afi1_wlast;     // output
    wire [ 7:0] afi1_wstrb;     // output[7:0] 
    wire        afi1_bvalid;     // input
    wire        afi1_bready;     // output
    wire [ 5:0] afi1_bid;     // input[5:0] 
    wire [ 1:0] afi1_bresp;     // input[1:0] 
    wire [ 7:0] afi1_wcount;     // input[7:0] 
    wire [ 5:0] afi1_wacount;     // input[5:0] 
    wire        afi1_wrissuecap1en;     // output

    // AFI2 (AXI_HP2) signals - write channels only - used only if CMPRS_NUM_AFI_CHN == 2
    wire [31:0] afi2_awaddr;   // output[31:0]
    wire        afi2_awvalid;  // output
    wire        afi2_awready;     // input
    wire [ 5:0] afi2_awid;     // output[5:0] 
    wire [ 1:0] afi2_awlock;     // output[1:0] 
    wire [ 3:0] afi2_awcache;     // output[3:0] 
    wire [ 2:0] afi2_awprot;     // output[2:0] 
    wire [ 3:0] afi2_awlen;     // output[3:0] 
    wire [ 2:0] afi2_awsize;     // output[2:0] 
    wire [ 1:0] afi2_awburst;     // output[1:0] 
    wire [ 3:0] afi2_awqos;     // output[3:0] 
    wire [63:0] afi2_wdata;     // output[63:0] 
    wire        afi2_wvalid;     // output
    wire        afi2_wready;     // input
    wire [ 5:0] afi2_wid;     // output[5:0] 
    wire        afi2_wlast;     // output
    wire [ 7:0] afi2_wstrb;     // output[7:0] 
    wire        afi2_bvalid;     // input
    wire        afi2_bready;     // output
    wire [ 5:0] afi2_bid;     // input[5:0] 
    wire [ 1:0] afi2_bresp;     // input[1:0] 
    wire [ 7:0] afi2_wcount;     // input[7:0] 
    wire [ 5:0] afi2_wacount;     // input[5:0] 
    wire        afi2_wrissuecap1en;     // output





    compressor393 #(
        .CMPRS_NUM_AFI_CHN               (CMPRS_NUM_AFI_CHN),
        .CMPRS_GROUP_ADDR                (CMPRS_GROUP_ADDR),
        .CMPRS_BASE_INC                  (CMPRS_BASE_INC),
        .CMPRS_AFIMUX_RADDR0             (CMPRS_AFIMUX_RADDR0),
        .CMPRS_AFIMUX_RADDR1             (CMPRS_AFIMUX_RADDR1),
        .CMPRS_AFIMUX_MASK               (CMPRS_AFIMUX_MASK),
        .CMPRS_STATUS_REG_BASE           (CMPRS_STATUS_REG_BASE),
        .CMPRS_HIFREQ_REG_BASE           (CMPRS_HIFREQ_REG_BASE),
        .CMPRS_AFIMUX_REG_ADDR0          (CMPRS_AFIMUX_REG_ADDR0),
        .CMPRS_AFIMUX_REG_ADDR1          (CMPRS_AFIMUX_REG_ADDR1),
        .CMPRS_STATUS_REG_INC            (CMPRS_STATUS_REG_INC),
        .CMPRS_HIFREQ_REG_INC            (CMPRS_HIFREQ_REG_INC),
        .CMPRS_MASK                      (CMPRS_MASK),
        .CMPRS_CONTROL_REG               (CMPRS_CONTROL_REG),
        .CMPRS_STATUS_CNTRL              (CMPRS_STATUS_CNTRL),
        .CMPRS_FORMAT                    (CMPRS_FORMAT),
        .CMPRS_COLOR_SATURATION          (CMPRS_COLOR_SATURATION),
        .CMPRS_CORING_MODE               (CMPRS_CORING_MODE),
        .CMPRS_TABLES                    (CMPRS_TABLES),
        .FRAME_HEIGHT_BITS               (FRAME_HEIGHT_BITS),
        .LAST_FRAME_BITS                 (LAST_FRAME_BITS),
        .CMPRS_CBIT_RUN                  (CMPRS_CBIT_RUN),
        .CMPRS_CBIT_RUN_BITS             (CMPRS_CBIT_RUN_BITS),
        .CMPRS_CBIT_QBANK                (CMPRS_CBIT_QBANK),
        .CMPRS_CBIT_QBANK_BITS           (CMPRS_CBIT_QBANK_BITS),
        .CMPRS_CBIT_DCSUB                (CMPRS_CBIT_DCSUB),
        .CMPRS_CBIT_DCSUB_BITS           (CMPRS_CBIT_DCSUB_BITS),
        .CMPRS_CBIT_CMODE                (CMPRS_CBIT_CMODE),
        .CMPRS_CBIT_CMODE_BITS           (CMPRS_CBIT_CMODE_BITS),
        .CMPRS_CBIT_FRAMES               (CMPRS_CBIT_FRAMES),
        .CMPRS_CBIT_FRAMES_BITS          (CMPRS_CBIT_FRAMES_BITS),
        .CMPRS_CBIT_BAYER                (CMPRS_CBIT_BAYER),
        .CMPRS_CBIT_BAYER_BITS           (CMPRS_CBIT_BAYER_BITS),
        .CMPRS_CBIT_FOCUS                (CMPRS_CBIT_FOCUS),
        .CMPRS_CBIT_FOCUS_BITS           (CMPRS_CBIT_FOCUS_BITS),
        .CMPRS_CBIT_RUN_RST              (CMPRS_CBIT_RUN_RST),
        .CMPRS_CBIT_RUN_STANDALONE       (CMPRS_CBIT_RUN_STANDALONE),
        .CMPRS_CBIT_RUN_ENABLE           (CMPRS_CBIT_RUN_ENABLE),
        .CMPRS_CBIT_CMODE_JPEG18         (CMPRS_CBIT_CMODE_JPEG18),
        .CMPRS_CBIT_CMODE_MONO6          (CMPRS_CBIT_CMODE_MONO6),
        .CMPRS_CBIT_CMODE_JP46           (CMPRS_CBIT_CMODE_JP46),
        .CMPRS_CBIT_CMODE_JP46DC         (CMPRS_CBIT_CMODE_JP46DC),
        .CMPRS_CBIT_CMODE_JPEG20         (CMPRS_CBIT_CMODE_JPEG20),
        .CMPRS_CBIT_CMODE_JP4            (CMPRS_CBIT_CMODE_JP4),
        .CMPRS_CBIT_CMODE_JP4DC          (CMPRS_CBIT_CMODE_JP4DC),
        .CMPRS_CBIT_CMODE_JP4DIFF        (CMPRS_CBIT_CMODE_JP4DIFF),
        .CMPRS_CBIT_CMODE_JP4DIFFHDR     (CMPRS_CBIT_CMODE_JP4DIFFHDR),
        .CMPRS_CBIT_CMODE_JP4DIFFDIV2    (CMPRS_CBIT_CMODE_JP4DIFFDIV2),
        .CMPRS_CBIT_CMODE_JP4DIFFHDRDIV2 (CMPRS_CBIT_CMODE_JP4DIFFHDRDIV2),
        .CMPRS_CBIT_CMODE_MONO1          (CMPRS_CBIT_CMODE_MONO1),
        .CMPRS_CBIT_CMODE_MONO4          (CMPRS_CBIT_CMODE_MONO4),
        .CMPRS_CBIT_FRAMES_SINGLE        (CMPRS_CBIT_FRAMES_SINGLE),
        .CMPRS_COLOR18                   (CMPRS_COLOR18),
        .CMPRS_COLOR20                   (CMPRS_COLOR20),
        .CMPRS_MONO16                    (CMPRS_MONO16),
        .CMPRS_JP4                       (CMPRS_JP4),
        .CMPRS_JP4DIFF                   (CMPRS_JP4DIFF),
        .CMPRS_MONO8                     (CMPRS_MONO8),
        .CMPRS_FRMT_MBCM1                (CMPRS_FRMT_MBCM1),
        .CMPRS_FRMT_MBCM1_BITS           (CMPRS_FRMT_MBCM1_BITS),
        .CMPRS_FRMT_MBRM1                (CMPRS_FRMT_MBRM1),
        .CMPRS_FRMT_MBRM1_BITS           (CMPRS_FRMT_MBRM1_BITS),
        .CMPRS_FRMT_LMARG                (CMPRS_FRMT_LMARG),
        .CMPRS_FRMT_LMARG_BITS           (CMPRS_FRMT_LMARG_BITS),
        .CMPRS_CSAT_CB                   (CMPRS_CSAT_CB),
        .CMPRS_CSAT_CB_BITS              (CMPRS_CSAT_CB_BITS),
        .CMPRS_CSAT_CR                   (CMPRS_CSAT_CR),
        .CMPRS_CSAT_CR_BITS              (CMPRS_CSAT_CR_BITS),
        .CMPRS_CORING_BITS               (CMPRS_CORING_BITS),
        .CMPRS_TIMEOUT_BITS              (CMPRS_TIMEOUT_BITS),
        .CMPRS_TIMEOUT                   (CMPRS_TIMEOUT),
        .CMPRS_AFIMUX_EN                 (CMPRS_AFIMUX_EN),
        .CMPRS_AFIMUX_RST                (CMPRS_AFIMUX_RST),
        .CMPRS_AFIMUX_MODE               (CMPRS_AFIMUX_MODE),
        .CMPRS_AFIMUX_STATUS_CNTRL       (CMPRS_AFIMUX_STATUS_CNTRL),
        .CMPRS_AFIMUX_SA_LEN             (CMPRS_AFIMUX_SA_LEN),
        .CMPRS_AFIMUX_WIDTH              (CMPRS_AFIMUX_WIDTH),
        .CMPRS_AFIMUX_CYCBITS            (CMPRS_AFIMUX_CYCBITS),
        .AFI_MUX_BUF_LATENCY             (AFI_MUX_BUF_LATENCY)
    ) compressor393_i (
        .rst                       (axi_rst),                    // input
        .xclk                      (xclk),                       // input
        .xclk2x                    (xclk2x),                     // input
        .mclk                      (mclk),                       // input
        .cmd_ad                    (cmd_compressor_ad),          // input[7:0] 
        .cmd_stb                   (cmd_compressor_stb),         // input
        .status_ad                 (status_compressor_ad),       // output[7:0] 
        .status_rq                 (status_compressor_rq),       // output
        .status_start              (status_compressor_start),    // input

        .xfer_reset_page_rd        (cmprs_xfer_reset_page_rd),   // input[3:0]
        .buf_wpage_nxt             (cmprs_buf_wpage_nxt),        // input[3:0]
        .buf_we                    (cmprs_buf_we),               // input[3:0]
        .buf_din                   (cmprs_buf_din),              // input[255:0] 
        .page_ready                (cmprs_page_ready),           // input[3:0]
        .next_page                 (cmprs_next_page),            // output[3:0]
        
        .frame_start_dst           (cmprs_frame_start_dst),      // output[3:0] 
        .line_unfinished_src       (cmprs_line_unfinished_src),  // input[63:0] 
        .frame_number_src          (cmprs_frame_number_src),     // input[63:0] 
        .frame_done_src            (cmprs_frame_done_src),       // input[3:0] 
        .line_unfinished_dst       (cmprs_line_unfinished_dst),  // input[63:0] 
        .frame_number_dst          (cmprs_frame_number_dst),     // input[63:0] 
        .frame_done_dst            (cmprs_frame_done_dst),       // input[3:0] 
        .suspend                   (cmprs_suspend),              // output[3:0] 

        .ts_pre_stb                (ts_pre_stb),                 // input[3:0]
        .ts_data                   (ts_data),                    // input[31:0] 
        
        .eof_written_mclk          (eof_written_mclk),           // output[3:0]
        .stuffer_done_mclk         (stuffer_done_mclk),          // output[3:0]

        .vsync_late                (vsync_late),                 // input[3:0]
        
        .hclk                      (hclk),                       // input
        .afi0_awaddr               (afi1_awaddr),                // output[31:0] 
        .afi0_awvalid              (afi1_awvalid),               // output
        .afi0_awready              (afi1_awready),               // input
        .afi0_awid                 (afi1_awid),                  // output[5:0] 
        .afi0_awlock               (afi1_awlock),                // output[1:0] 
        .afi0_awcache              (afi1_awcache),               // output[3:0] 
        .afi0_awprot               (afi1_awprot),                // output[2:0] 
        .afi0_awlen                (afi1_awlen),                 // output[3:0] 
        .afi0_awsize               (afi1_awsize),                // output[2:0] 
        .afi0_awburst              (afi1_awburst),               // output[1:0] 
        .afi0_awqos                (afi1_awqos),                 // output[3:0] 
        .afi0_wdata                (afi1_wdata),                 // output[63:0] 
        .afi0_wvalid               (afi1_wvalid),                // output
        .afi0_wready               (afi1_wready),                // input
        .afi0_wid                  (afi1_wid),                   // output[5:0] 
        .afi0_wlast                (afi1_wlast),                 // output
        .afi0_wstrb                (afi1_wstrb),                 // output[7:0] 
        .afi0_bvalid               (afi1_bvalid),                // input
        .afi0_bready               (afi1_bready),                // output
        .afi0_bid                  (afi1_bid),                   // input[5:0] 
        .afi0_bresp                (afi1_bresp),                 // input[1:0] 
        .afi0_wcount               (afi1_wcount),                // input[7:0] 
        .afi0_wacount              (afi1_wacount),               // input[5:0] 
        .afi0_wrissuecap1en        (afi1_wrissuecap1en),         // output
        
        .afi1_awaddr               (afi2_awaddr),                // output[31:0] 
        .afi1_awvalid              (afi2_awvalid),               // output
        .afi1_awready              (afi2_awready),               // input
        .afi1_awid                 (afi2_awid),                  // output[5:0] 
        .afi1_awlock               (afi2_awlock),                // output[1:0] 
        .afi1_awcache              (afi2_awcache),               // output[3:0] 
        .afi1_awprot               (afi2_awprot),                // output[2:0] 
        .afi1_awlen                (afi2_awlen),                 // output[3:0] 
        .afi1_awsize               (afi2_awsize),                // output[2:0] 
        .afi1_awburst              (afi2_awburst),               // output[1:0] 
        .afi1_awqos                (afi2_awqos),                 // output[3:0] 
        .afi1_wdata                (afi2_wdata),                 // output[63:0] 
        .afi1_wvalid               (afi2_wvalid),                // output
        .afi1_wready               (afi2_wready),                // input
        .afi1_wid                  (afi2_wid),                   // output[5:0] 
        .afi1_wlast                (afi2_wlast),                 // output
        .afi1_wstrb                (afi2_wstrb),                 // output[7:0] 
        .afi1_bvalid               (afi2_bvalid),                // input
        .afi1_bready               (afi2_bready),                // output
        .afi1_bid                  (afi2_bid),                   // input[5:0] 
        .afi1_bresp                (afi2_bresp),                 // input[1:0] 
        .afi1_wcount               (afi2_wcount),                // input[7:0] 
        .afi1_wacount              (afi2_wacount),               // input[5:0] 
        .afi1_wrissuecap1en        (afi2_wrissuecap1en)          // output
    );

    axibram_write #(
        .ADDRESS_BITS(AXI_WR_ADDR_BITS)
    ) axibram_write_i (  //SuppressThisWarning ISExst Output port <bram_wstb> of the instance <axibram_write_i> is unconnected or connected to loadless signal.
        .aclk        (axi_aclk), // input
        .rst         (axi_rst), // input
        .awaddr      (maxi0_awaddr[31:0]), // input[31:0] // SuppressThisWarning VivadoSynthesis: [Synth 8-3295] tying undriven pin #axibram_write_i:awaddr[31:16,1:0] to constant 0
        .awvalid     (maxi0_awvalid), // input
        .awready     (maxi0_awready), // output
        .awid        (maxi0_awid[11:0]), // input[11:0] // SuppressThisWarning VivadoSynthesis: [Synth 8-3295] tying undriven pin #axibram_write_i:awid[11:2] to constant 0
        .awlen       (maxi0_awlen[3:0]), // input[3:0] 
        .awsize      (maxi0_awsize[1:0]), // input[1:0] 
        .awburst     (maxi0_awburst[1:0]), // input[1:0] 
        .wdata       (maxi0_wdata[31:0]), // input[31:0] 
        .wvalid      (maxi0_wvalid), // input
        .wready      (maxi0_wready), // output
        .wid         (maxi0_wid[11:0]), // input[11:0] 
        .wlast       (maxi0_wlast), // input
        .wstb        (maxi0_wstb[3:0]), // input[3:0] 
        .bvalid      (maxi0_bvalid), // output
        .bready      (maxi0_bready), // input
        .bid         (maxi0_bid[11:0]), // output[11:0] 
        .bresp       (maxi0_bresp[1:0]), // output[1:0] 
        .pre_awaddr  (axiwr_pre_awaddr[AXI_WR_ADDR_BITS-1:0]), // output[9:0] 
        .start_burst (axiwr_start_burst), // output
        .dev_ready   (axiwr_dev_ready), // input
        .bram_wclk   (axiwr_wclk), // output
        .bram_waddr  (axiwr_waddr[AXI_WR_ADDR_BITS-1:0]), // output[9:0] 
        .bram_wen    (axiwr_wen), // output
        .bram_wstb   (axiwr_bram_wstb[3:0]), // output[3:0] //SuppressThisWarning ISExst Assignment to axiwr_bram_wstb ignored, since the identifier is never used
        .bram_wdata  (axiwr_wdata[31:0]) // output[31:0]
`ifdef DEBUG_FIFO
        ,
        .waddr_under (waddr_under), // output
        .wdata_under (wdata_under), // output
        .wresp_under (wresp_under), // output
        .waddr_over  (waddr_over),  // output
        .wdata_over  (wdata_over),  // output
        .wresp_over  (wresp_over),   // output
        .waddr_wcount(waddr_wcount), // output[3:0] 
        .waddr_rcount(waddr_rcount), // output[3:0] 
        .waddr_num_in_fifo(waddr_num_in_fifo), // output[3:0] 
        .wdata_wcount(wdata_wcount), // output[3:0] 
        .wdata_rcount(wdata_rcount), // output[3:0] 
        .wdata_num_in_fifo(wdata_num_in_fifo), // output[3:0] 
        .wresp_wcount(wresp_wcount), // output[3:0] 
        .wresp_rcount(wresp_rcount), // output[3:0] 
        .wresp_num_in_fifo(wresp_num_in_fifo), // output[3:0]
        .wleft       (wleft[3:0]),
        .wlength     (wlength[3:0]), // output[3:0] 
        .wlen_in_dbg (wlen_in_dbg[3:0]) // output[3:0] reg 
                 
`endif         
    );

    axibram_read #(
        .ADDRESS_BITS(AXI_RD_ADDR_BITS)
    ) axibram_read_i ( //SuppressThisWarning ISExst Output port <bram_rclk> of the instance <axibram_read_i> is unconnected or connected to loadless signal.
        .aclk        (axi_aclk), // input
        .rst         (axi_rst), // input
        .araddr      (maxi0_araddr[31:0]), // input[31:0] // SuppressThisWarning VivadoSynthesis: [Synth 8-3295] tying undriven pin #axibram_read_i:araddr[31:16,1:0] to constant 0
        .arvalid     (maxi0_arvalid), // input
        .arready     (maxi0_arready), // output
        .arid        (maxi0_arid[11:0]), // input[11:0] 
        .arlen       (maxi0_arlen[3:0]), // input[3:0] 
        .arsize      (maxi0_arsize[1:0]), // input[1:0] 
        .arburst     (maxi0_arburst[1:0]), // input[1:0] 
        .rdata       (maxi0_rdata[31:0]), // output[31:0] 
        .rvalid      (maxi0_rvalid), // output reg 
        .rready      (maxi0_rready), // input
        .rid         (maxi0_rid), // output[11:0] reg 
        .rlast       (maxi0_rlast), // output reg 
        .rresp       (maxi0_rresp[1:0]), // output[1:0] 
        .pre_araddr  (axird_pre_araddr[AXI_RD_ADDR_BITS-1:0]), // output[9:0] 
        .start_burst (axird_start_burst), // output
        .dev_ready   (axird_dev_ready), // input  SuppressThisWarning VivadoSynthesis: [Synth 8-3295] tying undriven pin #axibram_read_i:dev_ready to constant 0
        .bram_rclk   (axird_bram_rclk), // output //SuppressThisWarning ISExst Assignment to axird_bram_rclk ignored, since the identifier is never used
        .bram_raddr  (axird_raddr[AXI_RD_ADDR_BITS-1:0]), // output[9:0] 
        .bram_ren    (axird_ren), // output
        .bram_regen  (axird_regen), // output
        .bram_rdata  (axird_rdata ) // input[31:0] == axi_rdata[31:0], so SuppressThisWarning VivadoSynthesis: [Synth 8-3295] tying undriven pin #axibram_read_i:bram_rdata[31:0] to constant 0
    );
assign DUMMY_TO_KEEP = frst[2] && MEMCLK; // 1'b0; // dbg_toggle[0];

  PS7 ps7_i (
 // EMIO interface
 // CAN interface
    .EMIOCAN0PHYTX(),            // CAN 0 TX, output
    .EMIOCAN0PHYRX(),            // CAN 0 RX, input
    .EMIOCAN1PHYTX(),            // Can 1 TX, output
    .EMIOCAN1PHYRX(),            // CAN 1 RX, input
 // GMII 0
    .EMIOENET0GMIICRS(),         // GMII 0 Carrier sense, input
    .EMIOENET0GMIICOL(),         // GMII 0 Collision detect, input
    .EMIOENET0EXTINTIN(),        // GMII 0 Controller Interrupt input, input
    // GMII 0 TX signals
    .EMIOENET0GMIITXCLK(),       // GMII 0 TX clock, input
    .EMIOENET0GMIITXD(),         // GMII 0 Tx Data[7:0], output
    .EMIOENET0GMIITXEN(),        // GMII 0 Tx En, output
    .EMIOENET0GMIITXER(),        // GMII 0 Tx Err, output
    // GMII 0 TX timestamp signals
    .EMIOENET0SOFTX(),           // GMII 0 Tx Tx Start-of-Frame, output
    .EMIOENET0PTPDELAYREQTX(),   // GMII 0 Tx PTP delay req frame detected, output
    .EMIOENET0PTPPDELAYREQTX(),  // GMII 0 Tx PTP peer delay frame detect, output
    .EMIOENET0PTPPDELAYRESPTX(), // GMII 0 Tx PTP pear delay response frame detected, output
    .EMIOENET0PTPSYNCFRAMETX(),  // GMII 0 Tx PTP sync frame detected, output
    // GMII 0 RX signals
    .EMIOENET0GMIIRXCLK(),       // GMII 0 Rx Clock, input
    .EMIOENET0GMIIRXD(),         // GMII 0 Rx Data (7:0), input
    .EMIOENET0GMIIRXDV(),        // GMII 0 Rx Data valid, input
    .EMIOENET0GMIIRXER(),        // GMII 0 Rx Error, input
    // GMII 0 RX timestamp signals
    .EMIOENET0SOFRX(),           // GMII 0 Rx Start of Frame, output
    .EMIOENET0PTPDELAYREQRX(),   // GMII 0 Rx PTP delay req frame detected
    .EMIOENET0PTPPDELAYREQRX(),  // GMII 0 Rx PTP peer delay frame detected, output
    .EMIOENET0PTPPDELAYRESPRX(), // GMII 0 Rx PTP peer delay response frame detected, output
    .EMIOENET0PTPSYNCFRAMERX(),  // GMII 0 Rx PTP sync frame detected, output
    // MDIO 0
    .EMIOENET0MDIOMDC(),         // MDIO 0 MD clock output, output
    .EMIOENET0MDIOO(),           // MDIO 0 MD data output, output
    .EMIOENET0MDIOTN(),          // MDIO 0 MD data 3-state, output
    .EMIOENET0MDIOI(),           // MDIO 0 MD data input, input

 // GMII 1
    .EMIOENET1GMIICRS(),         // GMII 1 Carrier sense, input
    .EMIOENET1GMIICOL(),         // GMII 1 Collision detect, input
    .EMIOENET1EXTINTIN(),        // GMII 1 Controller Interrupt input, input
    // GMII 1 TX signals
    .EMIOENET1GMIITXCLK(),       // GMII 1 TX clock, input
    .EMIOENET1GMIITXD(),         // GMII 1 Tx Data[7:0], output
    .EMIOENET1GMIITXEN(),        // GMII 1 Tx En, output
    .EMIOENET1GMIITXER(),        // GMII 1 Tx Err, output
    // GMII 1 TX timestamp signals
    .EMIOENET1SOFTX(),           // GMII 1 Tx Tx Start-of-Frame, output
    .EMIOENET1PTPDELAYREQTX(),   // GMII 1 Tx PTP delay req frame detected, output
    .EMIOENET1PTPPDELAYREQTX(),  // GMII 1 Tx PTP peer delay frame detect, output
    .EMIOENET1PTPPDELAYRESPTX(), // GMII 1 Tx PTP pear delay response frame detected, output
    .EMIOENET1PTPSYNCFRAMETX(),  // GMII 1 Tx PTP sync frame detected, output
    // GMII 1 RX signals
    .EMIOENET1GMIIRXCLK(),       // GMII 1 Rx Clock, input
    .EMIOENET1GMIIRXD(),         // GMII 1 Rx Data (7:0), input
    .EMIOENET1GMIIRXDV(),        // GMII 1 Rx Data valid, input
    .EMIOENET1GMIIRXER(),        // GMII 1 Rx Error, input
    // GMII 1 RX timestamp signals
    .EMIOENET1SOFRX(),           // GMII 1 Rx Start of Frame, output
    .EMIOENET1PTPDELAYREQRX(),   // GMII 1 Rx PTP delay req frame detected
    .EMIOENET1PTPPDELAYREQRX(),  // GMII 1 Rx PTP peer delay frame detected, output
    .EMIOENET1PTPPDELAYRESPRX(), // GMII 1 Rx PTP peer delay response frame detected, output
    .EMIOENET1PTPSYNCFRAMERX(),  // GMII 1 Rx PTP sync frame detected, output
    // MDIO 1
    .EMIOENET1MDIOMDC(),         // MDIO 1 MD clock output, output
    .EMIOENET1MDIOO(),           // MDIO 1 MD data output, output
    .EMIOENET1MDIOTN(),          // MDIO 1 MD data 3-state, output
    .EMIOENET1MDIOI(),           // MDIO 1 MD data input, input
  // EMIO GPIO
    .EMIOGPIOO(),                // EMIO GPIO Data out[63:0], output
    .EMIOGPIOI(gpio_in[63:0]),   // EMIO GPIO Data in[63:0], input
    .EMIOGPIOTN(),               // EMIO GPIO OutputEnable[63:0], output
  // EMIO I2C 0  
    .EMIOI2C0SCLO(),             // I2C 0 SCL OUT, output // manual says input
    .EMIOI2C0SCLI(),             // I2C 0 SCL IN,  input  // manual says output
    .EMIOI2C0SCLTN(),            // I2C 0 SCL EN,  output // manual says input 
    .EMIOI2C0SDAO(),             // I2C 0 SDA OUT, output // manual says input
    .EMIOI2C0SDAI(),             // I2C 0 SDA IN,  input  // manual says output
    .EMIOI2C0SDATN(),            // I2C 0 SDA EN,  output // manual says input
  // EMIO I2C 1  
    .EMIOI2C1SCLO(),             // I2C 1 SCL OUT, output // manual says input
    .EMIOI2C1SCLI(),             // I2C 1 SCL IN,  input  // manual says output
    .EMIOI2C1SCLTN(),            // I2C 1 SCL EN,  output // manual says input 
    .EMIOI2C1SDAO(),             // I2C 1 SDA OUT, output // manual says input
    .EMIOI2C1SDAI(),             // I2C 1 SDA IN,  input  // manual says output
    .EMIOI2C1SDATN(),            // I2C 1 SDA EN,  output // manual says input
// JTAG
    .EMIOPJTAGTCK(),             // JTAG TCK, input
    .EMIOPJTAGTMS(),             // JTAG TMS, input
    .EMIOPJTAGTDI(),             // JTAG TDI, input
    .EMIOPJTAGTDO(),             // JTAG TDO, output
    .EMIOPJTAGTDTN(),            // JTAG TDO OE, output
 // SDIO 0  
    .EMIOSDIO0CLKFB(),           // SDIO 0 Clock feedback, input
    .EMIOSDIO0CLK(),             // SDIO 0 Clock, output
    .EMIOSDIO0CMDI(),            // SDIO 0 Command in, input
    .EMIOSDIO0CMDO(),            // SDIO 0 Command out, output
    .EMIOSDIO0CMDTN(),           // SDIO 0 command OE, output
    .EMIOSDIO0DATAI(),           // SDIO 0 Data in [3:0], input
    .EMIOSDIO0DATAO(),           // SDIO 0 Data out [3:0], output
    .EMIOSDIO0DATATN(),          // SDIO 0 Data OE [3:0], output
    .EMIOSDIO0CDN(),             // SDIO 0 Card detect, input
    .EMIOSDIO0WP(),              // SDIO 0 Write protect, input
    .EMIOSDIO0BUSPOW(),          // SDIO 0 Power control, output
    .EMIOSDIO0LED(),             // SDIO 0 LED control, output
    .EMIOSDIO0BUSVOLT(),         // SDIO 0 Bus voltage [2:0], output
 // SDIO 1  
    .EMIOSDIO1CLKFB(),           // SDIO 1 Clock feedback, input
    .EMIOSDIO1CLK(),             // SDIO 1 Clock, output
    .EMIOSDIO1CMDI(),            // SDIO 1 Command in, input
    .EMIOSDIO1CMDO(),            // SDIO 1 Command out, output
    .EMIOSDIO1CMDTN(),           // SDIO 1 command OE, output
    .EMIOSDIO1DATAI(),           // SDIO 1 Data in [3:0], input
    .EMIOSDIO1DATAO(),           // SDIO 1 Data out [3:0], output
    .EMIOSDIO1DATATN(),          // SDIO 1 Data OE [3:0], output
    .EMIOSDIO1CDN(),             // SDIO 1 Card detect, input
    .EMIOSDIO1WP(),              // SDIO 1 Write protect, input
    .EMIOSDIO1BUSPOW(),          // SDIO 1 Power control, output
    .EMIOSDIO1LED(),             // SDIO 1 LED control, output
    .EMIOSDIO1BUSVOLT(),         // SDIO 1 Bus voltage [2:0], output
  // SPI 0    
    .EMIOSPI0SCLKI(),            // SPI 0 CLK in , input
    .EMIOSPI0SCLKO(),            // SPI 0 CLK out, output
    .EMIOSPI0SCLKTN(),           // SPI 0 CLK OE, output
    .EMIOSPI0SI(),               // SPI 0 MOSI in , input
    .EMIOSPI0MO(),               // SPI 0 MOSI out , output
    .EMIOSPI0MOTN(),             // SPI 0 MOSI OE, output
    .EMIOSPI0MI(),               // SPI 0 MISO in, input
    .EMIOSPI0SO(),               // SPI 0 MISO out, output
    .EMIOSPI0STN(),              // SPI 0 MISO OE, output
    .EMIOSPI0SSIN(),             // SPI 0 Slave select 0 in, input
    .EMIOSPI0SSON(),             // SPI 0 Slave select [2:0] out, output
    .EMIOSPI0SSNTN(),            // SPI 0 Slave select OE, output
  // SPI 1    
    .EMIOSPI1SCLKI(),            // SPI 1 CLK in , input
    .EMIOSPI1SCLKO(),            // SPI 1 CLK out, output
    .EMIOSPI1SCLKTN(),           // SPI 1 CLK OE, output
    .EMIOSPI1SI(),               // SPI 1 MOSI in , input
    .EMIOSPI1MO(),               // SPI 1 MOSI out , output
    .EMIOSPI1MOTN(),             // SPI 1 MOSI OE, output
    .EMIOSPI1MI(),               // SPI 1 MISO in, input
    .EMIOSPI1SO(),               // SPI 1 MISO out, output
    .EMIOSPI1STN(),              // SPI 1 MISO OE, output
    .EMIOSPI1SSIN(),             // SPI 1 Slave select 0 in, input
    .EMIOSPI1SSON(),             // SPI 1 Slave select [2:0] out, output
    .EMIOSPI1SSNTN(),            // SPI 1 Slave select OE, output
// TPIU signals (Trace)    
    .EMIOTRACECTL(),             // Trace CTL, output
    .EMIOTRACEDATA(),            // Trace Data[31:0], output
    .EMIOTRACECLK(),             // Trace CLK, input
// Timers/counters    
    .EMIOTTC0CLKI(),             // Counter/Timer 0 clock in [2:0], input
    .EMIOTTC0WAVEO(),            // Counter/Timer 0 wave out[2:0], output
    .EMIOTTC1CLKI(),             // Counter/Timer 1 clock in [2:0], input
    .EMIOTTC1WAVEO(),            // Counter/Timer 1 wave out[2:0], output
 //UART 0
    .EMIOUART0TX(),              // UART 0 Transmit, output
    .EMIOUART0RX(),              // UART 0 Receive, input
    .EMIOUART0CTSN(),            // UART 0 Clear To Send, input
    .EMIOUART0RTSN(),            // UART 0 Ready to Send, output
    .EMIOUART0DSRN(),            // UART 0 Data Set Ready , input
    .EMIOUART0DCDN(),            // UART 0 Data Carrier Detect, input
    .EMIOUART0RIN(),             // UART 0 Ring Indicator, input
    .EMIOUART0DTRN(),            // UART 0 Data Terminal Ready, output
 //UART 1
    .EMIOUART1TX(),              // UART 1 Transmit, output
    .EMIOUART1RX(),              // UART 1 Receive, input
    .EMIOUART1CTSN(),            // UART 1 Clear To Send, input
    .EMIOUART1RTSN(),            // UART 1 Ready to Send, output
    .EMIOUART1DSRN(),            // UART 1 Data Set Ready , input
    .EMIOUART1DCDN(),            // UART 1 Data Carrier Detect, input
    .EMIOUART1RIN(),             // UART 1 Ring Indicator, input
    .EMIOUART1DTRN(),            // UART 1 Data Terminal Ready, output
 // USB 0    
    .EMIOUSB0PORTINDCTL(),       // USB 0 Port Indicator [1:0], output 
    .EMIOUSB0VBUSPWRFAULT(),     // USB 0 Power Fault, input
    .EMIOUSB0VBUSPWRSELECT(),    // USB 0 Power Select, output
 // USB 1    
    .EMIOUSB1PORTINDCTL(),       // USB 1 Port Indicator [1:0], output 
    .EMIOUSB1VBUSPWRFAULT(),     // USB 1 Power Fault, input
    .EMIOUSB1VBUSPWRSELECT(),    // USB 1 Power Select, output
 // Watchdog Timer    
    .EMIOWDTCLKI(),              // Watchdog Timer Clock in, input
    .EMIOWDTRSTO(),              // Watchdog Timer Reset out, output
 // DMAC 0  
    .DMA0ACLK(),                 // DMAC 0 Clock, input
    .DMA0DRVALID(),              // DMAC 0 DMA Request Valid, input
    .DMA0DRLAST(),               // DMAC 0 DMA Request Last, input
    .DMA0DRTYPE(),               // DMAC 0 DMA Request Type [1:0] ()single/burst/ackn flush/reserved), input
    .DMA0DRREADY(),              // DMAC 0 DMA Request Ready, output
    .DMA0DAVALID(),              // DMAC 0 DMA Acknowledge Valid (DA_TYPE[1:0] valid), output
    .DMA0DAREADY(),              // DMAC 0 DMA Acknowledge (peripheral can accept DA_TYPE[1:0]), input
    .DMA0DATYPE(),               // DMAC 0 DMA Ackbowledge TYpe (completed single AXI, completed burst AXI, flush request), output
    .DMA0RSTN(),                 // DMAC 0 RESET output (reserved, do not use), output
 // DMAC 1 
    .DMA1ACLK(),                 // DMAC 1 Clock, input
    .DMA1DRVALID(),              // DMAC 1 DMA Request Valid, input
    .DMA1DRLAST(),               // DMAC 1 DMA Request Last, input
    .DMA1DRTYPE(),               // DMAC 1 DMA Request Type [1:0] ()single/burst/ackn flush/reserved), input
    .DMA1DRREADY(),              // DMAC 1 DMA Request Ready, output
    .DMA1DAVALID(),              // DMAC 1 DMA Acknowledge Valid (DA_TYPE[1:0] valid), output
    .DMA1DAREADY(),              // DMAC 1 DMA Acknowledge (peripheral can accept DA_TYPE[1:0]), input
    .DMA1DATYPE(),               // DMAC 1 DMA Ackbowledge TYpe (completed single AXI, completed burst AXI, flush request), output
    .DMA1RSTN(),                 // DMAC 1 RESET output (reserved, do not use), output
 // DMAC 2  
    .DMA2ACLK(),                 // DMAC 2 Clock, input
    .DMA2DRVALID(),              // DMAC 2 DMA Request Valid, input
    .DMA2DRLAST(),               // DMAC 2 DMA Request Last, input
    .DMA2DRTYPE(),               // DMAC 2 DMA Request Type [1:0] ()single/burst/ackn flush/reserved), input
    .DMA2DRREADY(),              // DMAC 2 DMA Request Ready, output
    .DMA2DAVALID(),              // DMAC 2 DMA Acknowledge Valid (DA_TYPE[1:0] valid), output
    .DMA2DAREADY(),              // DMAC 2 DMA Acknowledge (peripheral can accept DA_TYPE[1:0]), input
    .DMA2DATYPE(),               // DMAC 2 DMA Ackbowledge TYpe (completed single AXI, completed burst AXI, flush request), output
    .DMA2RSTN(),                 // DMAC 2 RESET output (reserved, do not use), output
 // DMAC 3  
    .DMA3ACLK(),                 // DMAC 3 Clock, input
    .DMA3DRVALID(),              // DMAC 3 DMA Request Valid, input
    .DMA3DRLAST(),               // DMAC 3 DMA Request Last, input
    .DMA3DRTYPE(),               // DMAC 3 DMA Request Type [1:0] ()single/burst/ackn flush/reserved), input
    .DMA3DRREADY(),              // DMAC 3 DMA Request Ready, output
    .DMA3DAVALID(),              // DMAC 3 DMA Acknowledge Valid (DA_TYPE[1:0] valid), output
    .DMA3DAREADY(),              // DMAC 3 DMA Acknowledge (peripheral can accept DA_TYPE[1:0]), input
    .DMA3DATYPE(),               // DMAC 3 DMA Ackbowledge TYpe (completed single AXI, completed burst AXI, flush request), output
    .DMA3RSTN(),                 // DMAC 3 RESET output (reserved, do not use), output
 // Interrupt signals
    .IRQF2P(),                   // Interrupts, OL to PS [19:0], input
    .IRQP2F(),                   // Interrupts, OL to PS [28:0], output
 // Event Signals
    .EVENTEVENTI(),              // EVENT Wake up one or both CPU from WFE state, input
    .EVENTEVENTO(),              // EVENT Asserted when one of the COUs executed SEV instruction, output
    .EVENTSTANDBYWFE(),          // EVENT CPU standby mode [1:0], asserted when CPU is waiting for an event, output
    .EVENTSTANDBYWFI(),          // EVENT CPU standby mode [1:0], asserted when CPU is waiting for an interrupt, output
 // PL Resets and clocks
    .FCLKCLK(fclk[3:0]),         // PL Clocks [3:0], output
    .FCLKCLKTRIGN(),             // PL Clock Throttle Control [3:0], input
    .FCLKRESETN(frst[3:0]),      // PL General purpose user reset [3:0], output (active low)
// Debug signals
    .FTMTP2FDEBUG(),             // Debug General purpose debug output [31:0], output
    .FTMTF2PDEBUG(),             // Debug General purpose debug input [31:0], input
    .FTMTP2FTRIG(),              // Debug Trigger PS to PL [3:0], output
    .FTMTP2FTRIGACK(),           // Debug Trigger PS to PL acknowledge[3:0], input
    .FTMTF2PTRIG(),              // Debug Trigger PL to PS [3:0], input
    .FTMTF2PTRIGACK(),           // Debug Trigger PL to PS acknowledge[3:0], output
    .FTMDTRACEINCLOCK(),         // Debug Trace PL to PS Clock, input
    .FTMDTRACEINVALID(),         // Debug Trace PL to PS Clock, data&id valid, input
    .FTMDTRACEINDATA(),          // Debug Trace PL to PS data [31:0], input
    .FTMDTRACEINATID(),          // Debug Trace PL to PS ID [3:0], input
// DDR Urgent
    .DDRARB(),                   // DDR Urgent[3:0], input
    
// SRAM interrupt (on rising edge)
    .EMIOSRAMINTIN(),             // SRAM interrupt #50 shared with NAND busy, input
// AXI interfaces
    .FPGAIDLEN(1'b1),             //Idle PL AXI interfaces (active low), input
// AXI PS Master GP0    
// AXI PS Master GP0: Clock, Reset
    .MAXIGP0ACLK(axi_aclk),       // AXI PS Master GP0 Clock , input
//    .MAXIGP0ACLK(fclk[0]),       // AXI PS Master GP0 Clock , input
//      .MAXIGP0ACLK(~fclk[0]),       // AXI PS Master GP0 Clock , input
//      .MAXIGP0ACLK(axi_naclk),       // AXI PS Master GP0 Clock , input
    //
    .MAXIGP0ARESETN(),            // AXI PS Master GP0 Reset, output
// AXI PS Master GP0: Read Address    
    .MAXIGP0ARADDR  (maxi0_araddr[31:0]), // AXI PS Master GP0 ARADDR[31:0], output  
    .MAXIGP0ARVALID (maxi0_arvalid),     // AXI PS Master GP0 ARVALID, output
    .MAXIGP0ARREADY (maxi0_arready),     // AXI PS Master GP0 ARREADY, input
    .MAXIGP0ARID    (maxi0_arid[11:0]),     // AXI PS Master GP0 ARID[11:0], output
    .MAXIGP0ARLOCK   (),  // AXI PS Master GP0 ARLOCK[1:0], output
    .MAXIGP0ARCACHE  (),// AXI PS Master GP0 ARCACHE[3:0], output
    .MAXIGP0ARPROT(),  // AXI PS Master GP0 ARPROT[2:0], output
    .MAXIGP0ARLEN   (maxi0_arlen[3:0]),    // AXI PS Master GP0 ARLEN[3:0], output
    .MAXIGP0ARSIZE  (maxi0_arsize[1:0]),  // AXI PS Master GP0 ARSIZE[1:0], output
    .MAXIGP0ARBURST (maxi0_arburst[1:0]),// AXI PS Master GP0 ARBURST[1:0], output
    .MAXIGP0ARQOS    (),    // AXI PS Master GP0 ARQOS[3:0], output
// AXI PS Master GP0: Read Data
    .MAXIGP0RDATA   (maxi0_rdata[31:0]),   // AXI PS Master GP0 RDATA[31:0], input
    .MAXIGP0RVALID  (maxi0_rvalid),       // AXI PS Master GP0 RVALID, input
    .MAXIGP0RREADY  (maxi0_rready),       // AXI PS Master GP0 RREADY, output
    .MAXIGP0RID     (maxi0_rid[11:0]),       // AXI PS Master GP0 RID[11:0], input
    .MAXIGP0RLAST   (maxi0_rlast),         // AXI PS Master GP0 RLAST, input
    .MAXIGP0RRESP   (maxi0_rresp[1:0]),    // AXI PS Master GP0 RRESP[1:0], input
    
// AXI PS Master GP0: Write Address    
    .MAXIGP0AWADDR  (maxi0_awaddr[31:0]), // AXI PS Master GP0 AWADDR[31:0], output
    .MAXIGP0AWVALID (maxi0_awvalid),     // AXI PS Master GP0 AWVALID, output
    .MAXIGP0AWREADY (maxi0_awready),     // AXI PS Master GP0 AWREADY, input
    .MAXIGP0AWID    (maxi0_awid[11:0]),     // AXI PS Master GP0 AWID[11:0], output
    .MAXIGP0AWLOCK   (),  // AXI PS Master GP0 AWLOCK[1:0], output
    .MAXIGP0AWCACHE  (),// AXI PS Master GP0 AWCACHE[3:0], output
    .MAXIGP0AWPROT   (),  // AXI PS Master GP0 AWPROT[2:0], output
    .MAXIGP0AWLEN   (maxi0_awlen[3:0]),    // AXI PS Master GP0 AWLEN[3:0], output
    .MAXIGP0AWSIZE  (maxi0_awsize[1:0]),  // AXI PS Master GP0 AWSIZE[1:0], output
    .MAXIGP0AWBURST (maxi0_awburst[1:0]),// AXI PS Master GP0 AWBURST[1:0], output
    .MAXIGP0AWQOS    (),          // AXI PS Master GP0 AWQOS[3:0], output
// AXI PS Master GP0: Write Data
    .MAXIGP0WDATA   (maxi0_wdata[31:0]),   // AXI PS Master GP0 WDATA[31:0], output
    .MAXIGP0WVALID  (maxi0_wvalid),       // AXI PS Master GP0 WVALID, output
    .MAXIGP0WREADY  (maxi0_wready),       // AXI PS Master GP0 WREADY, input
    .MAXIGP0WID     (maxi0_wid[11:0]),       // AXI PS Master GP0 WID[11:0], output
    .MAXIGP0WLAST   (maxi0_wlast),         // AXI PS Master GP0 WLAST, output
    .MAXIGP0WSTRB   (maxi0_wstb[3:0]),    // AXI PS Master GP0 WSTRB[3:0], output
// AXI PS Master GP0: Write Responce
    .MAXIGP0BVALID  (maxi0_bvalid),       // AXI PS Master GP0 BVALID, input
    .MAXIGP0BREADY  (maxi0_bready),       // AXI PS Master GP0 BREADY, output
    .MAXIGP0BID     (maxi0_bid[11:0]),       // AXI PS Master GP0 BID[11:0], input
    .MAXIGP0BRESP   (maxi0_bresp[1:0]),    // AXI PS Master GP0 BRESP[1:0], input

// AXI PS Master GP1    
// AXI PS Master GP1: Clock, Reset
    .MAXIGP1ACLK(),              // AXI PS Master GP1 Clock , input
    .MAXIGP1ARESETN(),           // AXI PS Master GP1 Reset, output
// AXI PS Master GP1: Read Address    
    .MAXIGP1ARADDR(),            // AXI PS Master GP1 ARADDR[31:0], output  
    .MAXIGP1ARVALID(),           // AXI PS Master GP1 ARVALID, output
    .MAXIGP1ARREADY(),           // AXI PS Master GP1 ARREADY, input
    .MAXIGP1ARID(),              // AXI PS Master GP1 ARID[11:0], output
    .MAXIGP1ARLOCK(),            // AXI PS Master GP1 ARLOCK[1:0], output
    .MAXIGP1ARCACHE(),           // AXI PS Master GP1 ARCACHE[3:0], output
    .MAXIGP1ARPROT(),            // AXI PS Master GP1 ARPROT[2:0], output
    .MAXIGP1ARLEN(),             // AXI PS Master GP1 ARLEN[3:0], output
    .MAXIGP1ARSIZE(),            // AXI PS Master GP1 ARSIZE[1:0], output
    .MAXIGP1ARBURST(),           // AXI PS Master GP1 ARBURST[1:0], output
    .MAXIGP1ARQOS(),             // AXI PS Master GP1 ARQOS[3:0], output
// AXI PS Master GP1: Read Data
    .MAXIGP1RDATA(),             // AXI PS Master GP1 RDATA[31:0], input
    .MAXIGP1RVALID(),            // AXI PS Master GP1 RVALID, input
    .MAXIGP1RREADY(),            // AXI PS Master GP1 RREADY, output
    .MAXIGP1RID(),               // AXI PS Master GP1 RID[11:0], input
    .MAXIGP1RLAST(),             // AXI PS Master GP1 RLAST, input
    .MAXIGP1RRESP(),             // AXI PS Master GP1 RRESP[1:0], input
// AXI PS Master GP1: Write Address    
    .MAXIGP1AWADDR(),            // AXI PS Master GP1 AWADDR[31:0], output
    .MAXIGP1AWVALID(),           // AXI PS Master GP1 AWVALID, output
    .MAXIGP1AWREADY(),           // AXI PS Master GP1 AWREADY, input
    .MAXIGP1AWID(),              // AXI PS Master GP1 AWID[11:0], output
    .MAXIGP1AWLOCK(),            // AXI PS Master GP1 AWLOCK[1:0], output
    .MAXIGP1AWCACHE(),           // AXI PS Master GP1 AWCACHE[3:0], output
    .MAXIGP1AWPROT(),            // AXI PS Master GP1 AWPROT[2:0], output
    .MAXIGP1AWLEN(),             // AXI PS Master GP1 AWLEN[3:0], output
    .MAXIGP1AWSIZE(),            // AXI PS Master GP1 AWSIZE[1:0], output
    .MAXIGP1AWBURST(),           // AXI PS Master GP1 AWBURST[1:0], output
    .MAXIGP1AWQOS(),             // AXI PS Master GP1 AWQOS[3:0], output
// AXI PS Master GP1: Write Data
    .MAXIGP1WDATA(),             // AXI PS Master GP1 WDATA[31:0], output
    .MAXIGP1WVALID(),            // AXI PS Master GP1 WVALID, output
    .MAXIGP1WREADY(),            // AXI PS Master GP1 WREADY, input
    .MAXIGP1WID(),               // AXI PS Master GP1 WID[11:0], output
    .MAXIGP1WLAST(),             // AXI PS Master GP1 WLAST, output
    .MAXIGP1WSTRB(),             // AXI PS Master GP1 WSTRB[3:0], output
// AXI PS Master GP1: Write Responce
    .MAXIGP1BVALID(),            // AXI PS Master GP1 BVALID, input
    .MAXIGP1BREADY(),            // AXI PS Master GP1 BREADY, output
    .MAXIGP1BID(),               // AXI PS Master GP1 BID[11:0], input
    .MAXIGP1BRESP(),             // AXI PS Master GP1 BRESP[1:0], input

// AXI PS Slave GP0    
// AXI PS Slave GP0: Clock, Reset
    .SAXIGP0ACLK       (saxi0_aclk),              // AXI PS Slave GP0 Clock , input
    .SAXIGP0ARESETN(),           // AXI PS Slave GP0 Reset, output
// AXI PS Slave GP0: Read Address    - Not used
    .SAXIGP0ARADDR(),            // AXI PS Slave GP0 ARADDR[31:0], input  
    .SAXIGP0ARVALID(),           // AXI PS Slave GP0 ARVALID, input
    .SAXIGP0ARREADY(),           // AXI PS Slave GP0 ARREADY, output
    .SAXIGP0ARID(),              // AXI PS Slave GP0 ARID[5:0], input
    .SAXIGP0ARLOCK(),            // AXI PS Slave GP0 ARLOCK[1:0], input
    .SAXIGP0ARCACHE(),           // AXI PS Slave GP0 ARCACHE[3:0], input
    .SAXIGP0ARPROT(),            // AXI PS Slave GP0 ARPROT[2:0], input
    .SAXIGP0ARLEN(),             // AXI PS Slave GP0 ARLEN[3:0], input
    .SAXIGP0ARSIZE(),            // AXI PS Slave GP0 ARSIZE[1:0], input
    .SAXIGP0ARBURST(),           // AXI PS Slave GP0 ARBURST[1:0], input
    .SAXIGP0ARQOS(),             // AXI PS Slave GP0 ARQOS[3:0], input
// AXI PS Slave GP0: Read Data    - Not used
    .SAXIGP0RDATA(),             // AXI PS Slave GP0 RDATA[31:0], output
    .SAXIGP0RVALID(),            // AXI PS Slave GP0 RVALID, output
    .SAXIGP0RREADY(),            // AXI PS Slave GP0 RREADY, input
    .SAXIGP0RID(),               // AXI PS Slave GP0 RID[5:0], output
    .SAXIGP0RLAST(),             // AXI PS Slave GP0 RLAST, output
    .SAXIGP0RRESP(),             // AXI PS Slave GP0 RRESP[1:0], output
// AXI PS Slave GP0: Write Address    
    .SAXIGP0AWADDR     (saxi0_awaddr),   // AXI PS Slave GP0 AWADDR[31:0], input
    .SAXIGP0AWVALID    (saxi0_awvalid),  // AXI PS Slave GP0 AWVALID, input
    .SAXIGP0AWREADY    (saxi0_awready),  // AXI PS Slave GP0 AWREADY, output
    .SAXIGP0AWID       (saxi0_awid),     // AXI PS Slave GP0 AWID[5:0], input
    .SAXIGP0AWLOCK     (saxi0_awlock),   // AXI PS Slave GP0 AWLOCK[1:0], input
    .SAXIGP0AWCACHE    (saxi0_awcache),  // AXI PS Slave GP0 AWCACHE[3:0], input
    .SAXIGP0AWPROT     (saxi0_awprot),   // AXI PS Slave GP0 AWPROT[2:0], input
    .SAXIGP0AWLEN      (saxi0_awlen),    // AXI PS Slave GP0 AWLEN[3:0], input
    .SAXIGP0AWSIZE     (saxi0_awsize),   // AXI PS Slave GP0 AWSIZE[1:0], input
    .SAXIGP0AWBURST    (saxi0_awburst),  // AXI PS Slave GP0 AWBURST[1:0], input
    .SAXIGP0AWQOS      (saxi0_awqos),    // AXI PS Slave GP0 AWQOS[3:0], input
// AXI PS Slave GP0: Write Data
    .SAXIGP0WDATA      (saxi0_wdata),    // AXI PS Slave GP0 WDATA[31:0], input
    .SAXIGP0WVALID     (saxi0_wvalid),   // AXI PS Slave GP0 WVALID, input
    .SAXIGP0WREADY     (saxi0_wready),   // AXI PS Slave GP0 WREADY, output
    .SAXIGP0WID        (saxi0_wid),      // AXI PS Slave GP0 WID[5:0], input
    .SAXIGP0WLAST      (saxi0_wlast),    // AXI PS Slave GP0 WLAST, input
    .SAXIGP0WSTRB      (saxi0_wstrb),    // AXI PS Slave GP0 WSTRB[3:0], input
// AXI PS Slave GP0: Write Responce
    .SAXIGP0BVALID     (saxi0_bvalid),   // AXI PS Slave GP0 BVALID, output
    .SAXIGP0BREADY     (saxi0_bready),   // AXI PS Slave GP0 BREADY, input
    .SAXIGP0BID        (saxi0_bid),      // AXI PS Slave GP0 BID[5:0], output //TODO:  Update range !!!
    .SAXIGP0BRESP      (saxi0_bresp),    // AXI PS Slave GP0 BRESP[1:0], output

// AXI PS Slave GP1    
// AXI PS Slave GP1: Clock, Reset
    .SAXIGP1ACLK(),              // AXI PS Slave GP1 Clock , input
    .SAXIGP1ARESETN(),           // AXI PS Slave GP1 Reset, output
// AXI PS Slave GP1: Read Address    
    .SAXIGP1ARADDR(),            // AXI PS Slave GP1 ARADDR[31:0], input  
    .SAXIGP1ARVALID(),           // AXI PS Slave GP1 ARVALID, input
    .SAXIGP1ARREADY(),           // AXI PS Slave GP1 ARREADY, output
    .SAXIGP1ARID(),              // AXI PS Slave GP1 ARID[5:0], input
    .SAXIGP1ARLOCK(),            // AXI PS Slave GP1 ARLOCK[1:0], input
    .SAXIGP1ARCACHE(),           // AXI PS Slave GP1 ARCACHE[3:0], input
    .SAXIGP1ARPROT(),            // AXI PS Slave GP1 ARPROT[2:0], input
    .SAXIGP1ARLEN(),             // AXI PS Slave GP1 ARLEN[3:0], input
    .SAXIGP1ARSIZE(),            // AXI PS Slave GP1 ARSIZE[1:0], input
    .SAXIGP1ARBURST(),           // AXI PS Slave GP1 ARBURST[1:0], input
    .SAXIGP1ARQOS(),             // AXI PS Slave GP1 ARQOS[3:0], input
// AXI PS Slave GP1: Read Data
    .SAXIGP1RDATA(),             // AXI PS Slave GP1 RDATA[31:0], output
    .SAXIGP1RVALID(),            // AXI PS Slave GP1 RVALID, output
    .SAXIGP1RREADY(),            // AXI PS Slave GP1 RREADY, input
    .SAXIGP1RID(),               // AXI PS Slave GP1 RID[5:0], output
    .SAXIGP1RLAST(),             // AXI PS Slave GP1 RLAST, output
    .SAXIGP1RRESP(),             // AXI PS Slave GP1 RRESP[1:0], output
// AXI PS Slave GP1: Write Address    
    .SAXIGP1AWADDR(),            // AXI PS Slave GP1 AWADDR[31:0], input
    .SAXIGP1AWVALID(),           // AXI PS Slave GP1 AWVALID, input
    .SAXIGP1AWREADY(),           // AXI PS Slave GP1 AWREADY, output
    .SAXIGP1AWID(),              // AXI PS Slave GP1 AWID[5:0], input
    .SAXIGP1AWLOCK(),            // AXI PS Slave GP1 AWLOCK[1:0], input
    .SAXIGP1AWCACHE(),           // AXI PS Slave GP1 AWCACHE[3:0], input
    .SAXIGP1AWPROT(),            // AXI PS Slave GP1 AWPROT[2:0], input
    .SAXIGP1AWLEN(),             // AXI PS Slave GP1 AWLEN[3:0], input
    .SAXIGP1AWSIZE(),            // AXI PS Slave GP1 AWSIZE[1:0], input
    .SAXIGP1AWBURST(),           // AXI PS Slave GP1 AWBURST[1:0], input
    .SAXIGP1AWQOS(),             // AXI PS Slave GP1 AWQOS[3:0], input
// AXI PS Slave GP1: Write Data
    .SAXIGP1WDATA(),             // AXI PS Slave GP1 WDATA[31:0], input
    .SAXIGP1WVALID(),            // AXI PS Slave GP1 WVALID, input
    .SAXIGP1WREADY(),            // AXI PS Slave GP1 WREADY, output
    .SAXIGP1WID(),               // AXI PS Slave GP1 WID[5:0], input
    .SAXIGP1WLAST(),             // AXI PS Slave GP1 WLAST, input
    .SAXIGP1WSTRB(),             // AXI PS Slave GP1 WSTRB[3:0], input
// AXI PS Slave GP1: Write Responce
    .SAXIGP1BVALID(),            // AXI PS Slave GP1 BVALID, output
    .SAXIGP1BREADY(),            // AXI PS Slave GP1 BREADY, input
    .SAXIGP1BID(),               // AXI PS Slave GP1 BID[5:0], output
    .SAXIGP1BRESP(),             // AXI PS Slave GP1 BRESP[1:0], output

// AXI PS Slave HP0    
// AXI PS Slave HP0: Clock, Reset
    .SAXIHP0ACLK          (hclk),                   // AXI PS Slave HP0 Clock , input
    .SAXIHP0ARESETN       (),                       // AXI PS Slave HP0 Reset, output
// AXI PS Slave HP0: Read Address    
    .SAXIHP0ARADDR        (afi0_araddr),            // AXI PS Slave HP0 ARADDR[31:0], input  
    .SAXIHP0ARVALID       (afi0_arvalid),           // AXI PS Slave HP0 ARVALID, input
    .SAXIHP0ARREADY       (afi0_arready),           // AXI PS Slave HP0 ARREADY, output
    .SAXIHP0ARID          (afi0_arid),              // AXI PS Slave HP0 ARID[5:0], input
    .SAXIHP0ARLOCK        (afi0_arlock),            // AXI PS Slave HP0 ARLOCK[1:0], input
    .SAXIHP0ARCACHE       (afi0_arcache),           // AXI PS Slave HP0 ARCACHE[3:0], input
    .SAXIHP0ARPROT        (afi0_arprot),            // AXI PS Slave HP0 ARPROT[2:0], input
    .SAXIHP0ARLEN         (afi0_arlen),             // AXI PS Slave HP0 ARLEN[3:0], input
    .SAXIHP0ARSIZE        (afi0_arsize),            // AXI PS Slave HP0 ARSIZE[2:0], input
    .SAXIHP0ARBURST       (afi0_arburst),           // AXI PS Slave HP0 ARBURST[1:0], input
    .SAXIHP0ARQOS         (afi0_arqos),             // AXI PS Slave HP0 ARQOS[3:0], input
// AXI PS Slave HP0: Read Data
    .SAXIHP0RDATA         (afi0_rdata),             // AXI PS Slave HP0 RDATA[63:0], output
    .SAXIHP0RVALID        (afi0_rvalid),            // AXI PS Slave HP0 RVALID, output
    .SAXIHP0RREADY        (afi0_rready),            // AXI PS Slave HP0 RREADY, input
    .SAXIHP0RID           (afi0_rid),               // AXI PS Slave HP0 RID[5:0], output
    .SAXIHP0RLAST         (afi0_rlast),             // AXI PS Slave HP0 RLAST, output
    .SAXIHP0RRESP         (afi0_rresp),             // AXI PS Slave HP0 RRESP[1:0], output
    .SAXIHP0RCOUNT        (afi0_rcount),            // AXI PS Slave HP0 RCOUNT[7:0], output
    .SAXIHP0RACOUNT       (afi0_racount),           // AXI PS Slave HP0 RACOUNT[2:0], output
    .SAXIHP0RDISSUECAP1EN (afi0_rdissuecap1en),     // AXI PS Slave HP0 RDISSUECAP1EN, input
// AXI PS Slave HP0: Write Address    
    .SAXIHP0AWADDR        (afi0_awaddr),            // AXI PS Slave HP0 AWADDR[31:0], input
    .SAXIHP0AWVALID       (afi0_awvalid),           // AXI PS Slave HP0 AWVALID, input
    .SAXIHP0AWREADY       (afi0_awready),           // AXI PS Slave HP0 AWREADY, output
    .SAXIHP0AWID          (afi0_awid),              // AXI PS Slave HP0 AWID[5:0], input
    .SAXIHP0AWLOCK        (afi0_awlock),            // AXI PS Slave HP0 AWLOCK[1:0], input
    .SAXIHP0AWCACHE       (afi0_awcache),           // AXI PS Slave HP0 AWCACHE[3:0], input
    .SAXIHP0AWPROT        (afi0_awprot),            // AXI PS Slave HP0 AWPROT[2:0], input
    .SAXIHP0AWLEN         (afi0_awlen),             // AXI PS Slave HP0 AWLEN[3:0], input
    .SAXIHP0AWSIZE        (afi0_awsize),            // AXI PS Slave HP0 AWSIZE[1:0], input
    .SAXIHP0AWBURST       (afi0_awburst),           // AXI PS Slave HP0 AWBURST[1:0], input
    .SAXIHP0AWQOS         (afi0_awqos),             // AXI PS Slave HP0 AWQOS[3:0], input
// AXI PS Slave HP0: Write Data
    .SAXIHP0WDATA         (afi0_wdata),             // AXI PS Slave HP0 WDATA[63:0], input
    .SAXIHP0WVALID        (afi0_wvalid),            // AXI PS Slave HP0 WVALID, input
    .SAXIHP0WREADY        (afi0_wready),            // AXI PS Slave HP0 WREADY, output
    .SAXIHP0WID           (afi0_wid),               // AXI PS Slave HP0 WID[5:0], input
    .SAXIHP0WLAST         (afi0_wlast),             // AXI PS Slave HP0 WLAST, input
    .SAXIHP0WSTRB         (afi0_wstrb),             // AXI PS Slave HP0 WSTRB[7:0], input
    .SAXIHP0WCOUNT        (afi0_wcount),            // AXI PS Slave HP0 WCOUNT[7:0], output
    .SAXIHP0WACOUNT       (afi0_wacount),           // AXI PS Slave HP0 WACOUNT[5:0], output
    .SAXIHP0WRISSUECAP1EN (afi0_wrissuecap1en),     // AXI PS Slave HP0 WRISSUECAP1EN, input
// AXI PS Slave HP0: Write Responce
    .SAXIHP0BVALID        (afi0_bvalid),            // AXI PS Slave HP0 BVALID, output
    .SAXIHP0BREADY        (afi0_bready),            // AXI PS Slave HP0 BREADY, input
    .SAXIHP0BID           (afi0_bid),               // AXI PS Slave HP0 BID[5:0], output
    .SAXIHP0BRESP         (afi0_bresp),             // AXI PS Slave HP0 BRESP[1:0], output

// AXI PS Slave HP1    
// AXI PS Slave 1: Clock, Reset
    .SAXIHP1ACLK          (hclk),              // AXI PS Slave HP1 Clock , input
    .SAXIHP1ARESETN(),           // AXI PS Slave HP1 Reset, output
// AXI PS Slave HP1: Read Address   - unused
    .SAXIHP1ARADDR(),            // AXI PS Slave HP1 ARADDR[31:0], input  
    .SAXIHP1ARVALID(),           // AXI PS Slave HP1 ARVALID, input
    .SAXIHP1ARREADY(),           // AXI PS Slave HP1 ARREADY, output
    .SAXIHP1ARID(),              // AXI PS Slave HP1 ARID[5:0], input
    .SAXIHP1ARLOCK(),            // AXI PS Slave HP1 ARLOCK[1:0], input
    .SAXIHP1ARCACHE(),           // AXI PS Slave HP1 ARCACHE[3:0], input
    .SAXIHP1ARPROT(),            // AXI PS Slave HP1 ARPROT[2:0], input
    .SAXIHP1ARLEN(),             // AXI PS Slave HP1 ARLEN[3:0], input
    .SAXIHP1ARSIZE(),            // AXI PS Slave HP1 ARSIZE[2:0], input
    .SAXIHP1ARBURST(),           // AXI PS Slave HP1 ARBURST[1:0], input
    .SAXIHP1ARQOS(),             // AXI PS Slave HP1 ARQOS[3:0], input
// AXI PS Slave HP1: Read Data
    .SAXIHP1RDATA(),             // AXI PS Slave HP1 RDATA[63:0], output
    .SAXIHP1RVALID(),            // AXI PS Slave HP1 RVALID, output
    .SAXIHP1RREADY(),            // AXI PS Slave HP1 RREADY, input
    .SAXIHP1RID(),               // AXI PS Slave HP1 RID[5:0], output
    .SAXIHP1RLAST(),             // AXI PS Slave HP1 RLAST, output
    .SAXIHP1RRESP(),             // AXI PS Slave HP1 RRESP[1:0], output
    .SAXIHP1RCOUNT(),            // AXI PS Slave HP1 RCOUNT[7:0], output
    .SAXIHP1RACOUNT(),           // AXI PS Slave HP1 RACOUNT[2:0], output
    .SAXIHP1RDISSUECAP1EN(),     // AXI PS Slave HP1 RDISSUECAP1EN, input
// AXI PS Slave HP1: Write Address    
    .SAXIHP1AWADDR        (afi1_awaddr),            // AXI PS Slave HP1 AWADDR[31:0], input
    .SAXIHP1AWVALID       (afi1_awvalid),           // AXI PS Slave HP1 AWVALID, input
    .SAXIHP1AWREADY       (afi1_awready),           // AXI PS Slave HP1 AWREADY, output
    .SAXIHP1AWID          (afi1_awid),              // AXI PS Slave HP1 AWID[5:0], input
    .SAXIHP1AWLOCK        (afi1_awlock),            // AXI PS Slave HP1 AWLOCK[1:0], input
    .SAXIHP1AWCACHE       (afi1_awcache),           // AXI PS Slave HP1 AWCACHE[3:0], input
    .SAXIHP1AWPROT        (afi1_awprot),            // AXI PS Slave HP1 AWPROT[2:0], input
    .SAXIHP1AWLEN         (afi1_awlen),             // AXI PS Slave HP1 AWLEN[3:0], input
    .SAXIHP1AWSIZE        (afi1_awsize),            // AXI PS Slave HP1 AWSIZE[1:0], input
    .SAXIHP1AWBURST       (afi1_awburst),           // AXI PS Slave HP1 AWBURST[1:0], input
    .SAXIHP1AWQOS         (afi1_awqos),             // AXI PS Slave HP1 AWQOS[3:0], input
// AXI PS Slave HP1: Write Data
    .SAXIHP1WDATA         (afi1_wdata),             // AXI PS Slave HP1 WDATA[63:0], input
    .SAXIHP1WVALID        (afi1_wvalid),            // AXI PS Slave HP1 WVALID, input
    .SAXIHP1WREADY        (afi1_wready),            // AXI PS Slave HP1 WREADY, output
    .SAXIHP1WID           (afi1_wid),               // AXI PS Slave HP1 WID[5:0], input
    .SAXIHP1WLAST         (afi1_wlast),             // AXI PS Slave HP1 WLAST, input
    .SAXIHP1WSTRB         (afi1_wstrb),             // AXI PS Slave HP1 WSTRB[7:0], input
    .SAXIHP1WCOUNT        (afi1_wcount),            // AXI PS Slave HP1 WCOUNT[7:0], output
    .SAXIHP1WACOUNT       (afi1_wacount),           // AXI PS Slave HP1 WACOUNT[5:0], output
    .SAXIHP1WRISSUECAP1EN (afi1_wrissuecap1en),     // AXI PS Slave HP1 WRISSUECAP1EN, input
// AXI PS Slave HP1: Write Responce
    .SAXIHP1BVALID        (afi1_bvalid),            // AXI PS Slave HP1 BVALID, output
    .SAXIHP1BREADY        (afi1_bready),            // AXI PS Slave HP1 BREADY, input
    .SAXIHP1BID           (afi1_bid),               // AXI PS Slave HP1 BID[5:0], output
    .SAXIHP1BRESP         (afi1_bresp),             // AXI PS Slave HP1 BRESP[1:0], output

// AXI PS Slave HP2    
// AXI PS Slave HP2: Clock, Reset
    .SAXIHP2ACLK(),              // AXI PS Slave HP2 Clock , input
    .SAXIHP2ARESETN(),           // AXI PS Slave HP2 Reset, output
// AXI PS Slave HP2: Read Address   - not used
    .SAXIHP2ARADDR(),            // AXI PS Slave HP2 ARADDR[31:0], input  
    .SAXIHP2ARVALID(),           // AXI PS Slave HP2 ARVALID, input
    .SAXIHP2ARREADY(),           // AXI PS Slave HP2 ARREADY, output
    .SAXIHP2ARID(),              // AXI PS Slave HP2 ARID[5:0], input
    .SAXIHP2ARLOCK(),            // AXI PS Slave HP2 ARLOCK[1:0], input
    .SAXIHP2ARCACHE(),           // AXI PS Slave HP2 ARCACHE[3:0], input
    .SAXIHP2ARPROT(),            // AXI PS Slave HP2 ARPROT[2:0], input
    .SAXIHP2ARLEN(),             // AXI PS Slave HP2 ARLEN[3:0], input
    .SAXIHP2ARSIZE(),            // AXI PS Slave HP2 ARSIZE[2:0], input
    .SAXIHP2ARBURST(),           // AXI PS Slave HP2 ARBURST[1:0], input
    .SAXIHP2ARQOS(),             // AXI PS Slave HP2 ARQOS[3:0], input
// AXI PS Slave HP2: Read Data - not used
    .SAXIHP2RDATA(),             // AXI PS Slave HP2 RDATA[63:0], output
    .SAXIHP2RVALID(),            // AXI PS Slave HP2 RVALID, output
    .SAXIHP2RREADY(),            // AXI PS Slave HP2 RREADY, input
    .SAXIHP2RID(),               // AXI PS Slave HP2 RID[5:0], output
    .SAXIHP2RLAST(),             // AXI PS Slave HP2 RLAST, output
    .SAXIHP2RRESP(),             // AXI PS Slave HP2 RRESP[1:0], output
    .SAXIHP2RCOUNT(),            // AXI PS Slave HP2 RCOUNT[7:0], output
    .SAXIHP2RACOUNT(),           // AXI PS Slave HP2 RACOUNT[2:0], output
    .SAXIHP2RDISSUECAP1EN(),     // AXI PS Slave HP2 RDISSUECAP1EN, input
// AXI PS Slave HP2: Write Address    
    .SAXIHP2AWADDR        (afi2_awaddr),            // AXI PS Slave HP2 AWADDR[31:0], input
    .SAXIHP2AWVALID       (afi2_awvalid),           // AXI PS Slave HP2 AWVALID, input
    .SAXIHP2AWREADY       (afi2_awready),           // AXI PS Slave HP2 AWREADY, output
    .SAXIHP2AWID          (afi2_awid),              // AXI PS Slave HP2 AWID[5:0], input
    .SAXIHP2AWLOCK        (afi2_awlock),            // AXI PS Slave HP2 AWLOCK[1:0], input
    .SAXIHP2AWCACHE       (afi2_awcache),           // AXI PS Slave HP2 AWCACHE[3:0], input
    .SAXIHP2AWPROT        (afi2_awprot),            // AXI PS Slave HP2 AWPROT[2:0], input
    .SAXIHP2AWLEN         (afi2_awlen),             // AXI PS Slave HP2 AWLEN[3:0], input
    .SAXIHP2AWSIZE        (afi2_awsize),            // AXI PS Slave HP2 AWSIZE[1:0], input
    .SAXIHP2AWBURST       (afi2_awburst),           // AXI PS Slave HP2 AWBURST[1:0], input
    .SAXIHP2AWQOS         (afi2_awqos),             // AXI PS Slave HP2 AWQOS[3:0], input
// AXI PS Slave HP2: Write Data
    .SAXIHP2WDATA         (afi2_wdata),             // AXI PS Slave HP2 WDATA[63:0], input
    .SAXIHP2WVALID        (afi2_wvalid),            // AXI PS Slave HP2 WVALID, input
    .SAXIHP2WREADY        (afi2_wready),            // AXI PS Slave HP2 WREADY, output
    .SAXIHP2WID           (afi2_wid),               // AXI PS Slave HP2 WID[5:0], input
    .SAXIHP2WLAST         (afi2_wlast),             // AXI PS Slave HP2 WLAST, input
    .SAXIHP2WSTRB         (afi2_wstrb),             // AXI PS Slave HP2 WSTRB[7:0], input
    .SAXIHP2WCOUNT        (afi2_wcount),            // AXI PS Slave HP2 WCOUNT[7:0], output
    .SAXIHP2WACOUNT       (afi2_wacount),           // AXI PS Slave HP2 WACOUNT[5:0], output
    .SAXIHP2WRISSUECAP1EN (afi2_wrissuecap1en),     // AXI PS Slave HP2 WRISSUECAP1EN, input
// AXI PS Slave HP2: Write Responce
    .SAXIHP2BVALID        (afi2_bvalid),            // AXI PS Slave HP2 BVALID, output
    .SAXIHP2BREADY        (afi2_bready),            // AXI PS Slave HP2 BREADY, input
    .SAXIHP2BID           (afi2_bid),               // AXI PS Slave HP2 BID[5:0], output
    .SAXIHP2BRESP         (afi2_bresp),             // AXI PS Slave HP2 BRESP[1:0], output

// AXI PS Slave HP3    
// AXI PS Slave HP3: Clock, Reset
    .SAXIHP3ACLK(),              // AXI PS Slave HP3 Clock , input
    .SAXIHP3ARESETN(),           // AXI PS Slave HP3 Reset, output
// AXI PS Slave HP3: Read Address    
    .SAXIHP3ARADDR(),            // AXI PS Slave HP3 ARADDR[31:0], input  
    .SAXIHP3ARVALID(),           // AXI PS Slave HP3 ARVALID, input
    .SAXIHP3ARREADY(),           // AXI PS Slave HP3 ARREADY, output
    .SAXIHP3ARID(),              // AXI PS Slave HP3 ARID[5:0], input
    .SAXIHP3ARLOCK(),            // AXI PS Slave HP3 ARLOCK[1:0], input
    .SAXIHP3ARCACHE(),           // AXI PS Slave HP3 ARCACHE[3:0], input
    .SAXIHP3ARPROT(),            // AXI PS Slave HP3 ARPROT[2:0], input
    .SAXIHP3ARLEN(),             // AXI PS Slave HP3 ARLEN[3:0], input
    .SAXIHP3ARSIZE(),            // AXI PS Slave HP3 ARSIZE[2:0], input
    .SAXIHP3ARBURST(),           // AXI PS Slave HP3 ARBURST[1:0], input
    .SAXIHP3ARQOS(),             // AXI PS Slave HP3 ARQOS[3:0], input
// AXI PS Slave HP3: Read Data
    .SAXIHP3RDATA(),             // AXI PS Slave HP3 RDATA[63:0], output
    .SAXIHP3RVALID(),            // AXI PS Slave HP3 RVALID, output
    .SAXIHP3RREADY(),            // AXI PS Slave HP3 RREADY, input
    .SAXIHP3RID(),               // AXI PS Slave HP3 RID[5:0], output
    .SAXIHP3RLAST(),             // AXI PS Slave HP3 RLAST, output
    .SAXIHP3RRESP(),             // AXI PS Slave HP3 RRESP[1:0], output
    .SAXIHP3RCOUNT(),            // AXI PS Slave HP3 RCOUNT[7:0], output
    .SAXIHP3RACOUNT(),           // AXI PS Slave HP3 RACOUNT[2:0], output
    .SAXIHP3RDISSUECAP1EN(),     // AXI PS Slave HP3 RDISSUECAP1EN, input
// AXI PS Slave HP3: Write Address    
    .SAXIHP3AWADDR(),            // AXI PS Slave HP3 AWADDR[31:0], input
    .SAXIHP3AWVALID(),           // AXI PS Slave HP3 AWVALID, input
    .SAXIHP3AWREADY(),           // AXI PS Slave HP3 AWREADY, output
    .SAXIHP3AWID(),              // AXI PS Slave HP3 AWID[5:0], input
    .SAXIHP3AWLOCK(),            // AXI PS Slave HP3 AWLOCK[1:0], input
    .SAXIHP3AWCACHE(),           // AXI PS Slave HP3 AWCACHE[3:0], input
    .SAXIHP3AWPROT(),            // AXI PS Slave HP3 AWPROT[2:0], input
    .SAXIHP3AWLEN(),             // AXI PS Slave HP3 AWLEN[3:0], input
    .SAXIHP3AWSIZE(),            // AXI PS Slave HP3 AWSIZE[1:0], input
    .SAXIHP3AWBURST(),           // AXI PS Slave HP3 AWBURST[1:0], input
    .SAXIHP3AWQOS(),             // AXI PS Slave HP3 AWQOS[3:0], input
// AXI PS Slave HP3: Write Data
    .SAXIHP3WDATA(),             // AXI PS Slave HP3 WDATA[63:0], input
    .SAXIHP3WVALID(),            // AXI PS Slave HP3 WVALID, input
    .SAXIHP3WREADY(),            // AXI PS Slave HP3 WREADY, output
    .SAXIHP3WID(),               // AXI PS Slave HP3 WID[5:0], input
    .SAXIHP3WLAST(),             // AXI PS Slave HP3 WLAST, input
    .SAXIHP3WSTRB(),             // AXI PS Slave HP3 WSTRB[7:0], input
    .SAXIHP3WCOUNT(),            // AXI PS Slave HP3 WCOUNT[7:0], output
    .SAXIHP3WACOUNT(),           // AXI PS Slave HP3 WACOUNT[5:0], output
    .SAXIHP3WRISSUECAP1EN(),     // AXI PS Slave HP3 WRISSUECAP1EN, input
// AXI PS Slave HP3: Write Responce
    .SAXIHP3BVALID(),            // AXI PS Slave HP3 BVALID, output
    .SAXIHP3BREADY(),            // AXI PS Slave HP3 BREADY, input
    .SAXIHP3BID(),               // AXI PS Slave HP3 BID[5:0], output
    .SAXIHP3BRESP(),             // AXI PS Slave HP3 BRESP[1:0], output

// AXI PS Slave ACP    
// AXI PS Slave ACP: Clock, Reset
    .SAXIACPACLK(),              // AXI PS Slave ACP Clock, input
    .SAXIACPARESETN(),           // AXI PS Slave ACP Reset, output
// AXI PS Slave ACP: Read Address    
    .SAXIACPARADDR(),            // AXI PS Slave ACP ARADDR[31:0], input  
    .SAXIACPARVALID(),           // AXI PS Slave ACP ARVALID, input
    .SAXIACPARREADY(),           // AXI PS Slave ACP ARREADY, output
    .SAXIACPARID(),              // AXI PS Slave ACP ARID[2:0], input
    .SAXIACPARLOCK(),            // AXI PS Slave ACP ARLOCK[1:0], input
    .SAXIACPARCACHE(),           // AXI PS Slave ACP ARCACHE[3:0], input
    .SAXIACPARPROT(),            // AXI PS Slave ACP ARPROT[2:0], input
    .SAXIACPARLEN(),             // AXI PS Slave ACP ARLEN[3:0], input
    .SAXIACPARSIZE(),            // AXI PS Slave ACP ARSIZE[2:0], input
    .SAXIACPARBURST(),           // AXI PS Slave ACP ARBURST[1:0], input
    .SAXIACPARQOS(),             // AXI PS Slave ACP ARQOS[3:0], input
    .SAXIACPARUSER(),            // AXI PS Slave ACP ARUSER[4:0], input
// AXI PS Slave ACP: Read Data
    .SAXIACPRDATA(),             // AXI PS Slave ACP RDATA[63:0], output
    .SAXIACPRVALID(),            // AXI PS Slave ACP RVALID, output
    .SAXIACPRREADY(),            // AXI PS Slave ACP RREADY, input
    .SAXIACPRID(),               // AXI PS Slave ACP RID[2:0], output
    .SAXIACPRLAST(),             // AXI PS Slave ACP RLAST, output
    .SAXIACPRRESP(),             // AXI PS Slave ACP RRESP[1:0], output
// AXI PS Slave ACP: Write Address    
    .SAXIACPAWADDR(),            // AXI PS Slave ACP AWADDR[31:0], input
    .SAXIACPAWVALID(),           // AXI PS Slave ACP AWVALID, input
    .SAXIACPAWREADY(),           // AXI PS Slave ACP AWREADY, output
    .SAXIACPAWID(),              // AXI PS Slave ACP AWID[2:0], input
    .SAXIACPAWLOCK(),            // AXI PS Slave ACP AWLOCK[1:0], input
    .SAXIACPAWCACHE(),           // AXI PS Slave ACP AWCACHE[3:0], input
    .SAXIACPAWPROT(),            // AXI PS Slave ACP AWPROT[2:0], input
    .SAXIACPAWLEN(),             // AXI PS Slave ACP AWLEN[3:0], input
    .SAXIACPAWSIZE(),            // AXI PS Slave ACP AWSIZE[1:0], input
    .SAXIACPAWBURST(),           // AXI PS Slave ACP AWBURST[1:0], input
    .SAXIACPAWQOS(),             // AXI PS Slave ACP AWQOS[3:0], input
    .SAXIACPAWUSER(),            // AXI PS Slave ACP AWUSER[4:0], input
    
// AXI PS Slave ACP: Write Data
    .SAXIACPWDATA(),             // AXI PS Slave ACP WDATA[63:0], input
    .SAXIACPWVALID(),            // AXI PS Slave ACP WVALID, input
    .SAXIACPWREADY(),            // AXI PS Slave ACP WREADY, output
    .SAXIACPWID(),               // AXI PS Slave ACP WID[2:0], input
    .SAXIACPWLAST(),             // AXI PS Slave ACP WLAST, input
    .SAXIACPWSTRB(),             // AXI PS Slave ACP WSTRB[7:0], input
// AXI PS Slave ACP: Write Responce
    .SAXIACPBVALID(),            // AXI PS Slave ACP BVALID, output
    .SAXIACPBREADY(),            // AXI PS Slave ACP BREADY, input
    .SAXIACPBID(),               // AXI PS Slave ACP BID[2:0], output
    .SAXIACPBRESP(),             // AXI PS Slave ACP BRESP[1:0], output
// Direct connection to PS package pads
    .DDRA(),                     // PS DDRA[14:0], inout
    .DDRBA(),                    // PS DDRBA[2:0], inout
    .DDRCASB(),                  // PS DDRCASB, inout
    .DDRCKE(),                   // PS DDRCKE, inout
    .DDRCKP(),                   // PS DDRCKP, inout
    .DDRCKN(),                   // PS DDRCKN, inout
    .DDRCSB(),                   // PS DDRCSB, inout
    .DDRDM(),                    // PS DDRDM[3:0], inout
    .DDRDQ(),                    // PS DDRDQ[31:0], inout
    .DDRDQSP(),                  // PS DDRDQSP[3:0], inout
    .DDRDQSN(),                  // PS DDRDQSN[3:0], inout
    .DDRDRSTB(),                 // PS DDRDRSTB, inout
    .DDRODT(),                   // PS DDRODT, inout
    .DDRRASB(),                  // PS DDRRASB, inout
    .DDRVRN(),                   // PS DDRVRN, inout
    .DDRVRP(),                   // PS DDRVRP, inout
    .DDRWEB(),                   // PS DDRWEB, inout
    .MIO(),                      // PS MIO[53:0], inout // clg225 has less
    .PSCLK(),                    // PS PSCLK, inout
    .PSPORB(),                   // PS PSPORB, inout
    .PSSRSTB()                  // PS PSSRSTB, inout
  );
endmodule
