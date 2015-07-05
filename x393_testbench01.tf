/*******************************************************************************
 * Module: x393_testbench01
 * Date:2015-02-06  
 * Author: andrey     
 * Description: testbench for the initial x393.v simulation
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * x393_testbench01.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  x393_testbench01.tf is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps
`include "system_defines.vh"

//`define use200Mhz 1
//`define DEBUG_FIFO 1
`undef WAIT_MRS
`define SET_PER_PIN_DELAYS 1 // set individual (including per-DQ pin delays)
`define READBACK_DELAYS 1
`define PS_PIO_WAIT_COMPLETE 0 // wait until PS PIO module finished transaction before starting a new one
// Disabled already passed test to speedup simulation
//`define TEST_WRITE_LEVELLING 1
//`define TEST_READ_PATTERN 1
//`define TEST_WRITE_BLOCK 1
//`define TEST_READ_BLOCK 1
//`define TEST_SCANLINE_WRITE
    `define TEST_SCANLINE_WRITE_WAIT 1 // wait TEST_SCANLINE_WRITE finished (frame_done)
//`define TEST_SCANLINE_READ
    `define TEST_READ_SHOW  1
//`define TEST_TILED_WRITE  1
    `define TEST_TILED_WRITE_WAIT 1 // wait TEST_SCANLINE_WRITE finished (frame_done)
//`define TEST_TILED_READ  1

//`define TEST_TILED_WRITE32  1
//`define TEST_TILED_READ32  1

`define TEST_AFI_WRITE 1
`define TEST_AFI_READ 1

module  x393_testbench01 #(
`include "includes/x393_parameters.vh" // SuppressThisWarning VEditor - not used
`include "includes/x393_simulation_parameters.vh"
)(
);
`ifdef IVERILOG              
//    $display("IVERILOG is defined");
    `include "IVERILOG_INCLUDE.v"
`else
//    $display("IVERILOG is not defined");
    parameter lxtname = "x393.lxt";
`endif
`define DEBUG_WR_SINGLE 1  
`define DEBUG_RD_DATA 1  
//`include "includes/x393_cur_params_sim.vh" // parameters that may need adjustment, should be before x393_localparams.vh
`include "includes/x393_cur_params_target.vh" // SuppressThisWarning VEditor - not used parameters that may need adjustment, should be before x393_localparams.vh
`include "includes/x393_localparams.vh" // SuppressThisWarning VEditor - not used
  // DDR3 signals
  wire        SDRST;
  wire        SDCLK;  // output
  wire        SDNCLK; // output
  wire [ADDRESS_NUMBER-1:0] SDA;    // output[14:0] 
  wire [ 2:0] SDBA;   // output[2:0] 
  wire        SDWE;   // output
  wire        SDRAS;  // output
  wire        SDCAS;  // output
  wire        SDCKE;  // output
  wire        SDODT;  // output
  wire [15:0] SDD;    // inout[15:0] 
  wire        SDDML;  // inout
  wire        DQSL;   // inout
  wire        NDQSL;  // inout
  wire        SDDMU;  // inout
  wire        DQSU;   // inout
  wire        NDQSU;  // inout
  wire        DUMMY_TO_KEEP;  // output to keep PS7 signals from "optimization" // SuppressThisWarning all - not used
//  wire        MEMCLK;
  
// axi_hp simulation signals
  wire HCLK;
  wire [31:0] afi_sim_rd_address;    // output[31:0] 
  wire [ 5:0] afi_sim_rid;           // output[5:0]  SuppressThisWarning VEditor - not used - just view
//  reg         afi_sim_rd_valid;      // input
  wire        afi_sim_rd_valid;      // input
  wire        afi_sim_rd_ready;      // output
//  reg  [63:0] afi_sim_rd_data;       // input[63:0] 
  wire [63:0] afi_sim_rd_data;       // input[63:0] 
  wire [ 2:0] afi_sim_rd_cap;        // output[2:0]  SuppressThisWarning VEditor - not used - just view
  wire [ 3:0] afi_sim_rd_qos;        // output[3:0]  SuppressThisWarning VEditor - not used - just view
  wire  [ 1:0] afi_sim_rd_resp;       // input[1:0] 
//  reg  [ 1:0] afi_sim_rd_resp;       // input[1:0] 

  wire [31:0] afi_sim_wr_address;    // output[31:0] SuppressThisWarning VEditor - not used - just view
  wire [ 5:0] afi_sim_wid;           // output[5:0]  SuppressThisWarning VEditor - not used - just view
  wire        afi_sim_wr_valid;      // output
  wire        afi_sim_wr_ready;      // input
//  reg         afi_sim_wr_ready;      // input
  wire [63:0] afi_sim_wr_data;       // output[63:0] SuppressThisWarning VEditor - not used - just view
  wire [ 7:0] afi_sim_wr_stb;        // output[7:0]  SuppressThisWarning VEditor - not used - just view
  wire [ 3:0] afi_sim_bresp_latency; // input[3:0] 
//  reg  [ 3:0] afi_sim_bresp_latency; // input[3:0] 
  wire [ 2:0] afi_sim_wr_cap;        // output[2:0]  SuppressThisWarning VEditor - not used - just view
  wire [ 3:0] afi_sim_wr_qos;        // output[3:0]  SuppressThisWarning VEditor - not used - just view

  assign HCLK = x393_i.ps7_i.SAXIHP0ACLK; // shortcut name
// afi loopback
  assign #1 afi_sim_rd_data=  afi_sim_rd_ready?{2'h0,afi_sim_rd_address[31:3],1'h1,  2'h0,afi_sim_rd_address[31:3],1'h0}:64'bx;
  assign #1 afi_sim_rd_valid = afi_sim_rd_ready;
  assign #1 afi_sim_rd_resp = afi_sim_rd_ready?2'b0:2'bx;
  assign #1 afi_sim_wr_ready = afi_sim_wr_valid;
  assign #1 afi_sim_bresp_latency=4'h5; 
  
// axi_hp register access
  // PS memory mapped registers to read/write over a separate simulation bus running at HCLK, no waits
  reg  [31:0] PS_REG_ADDR;
  reg         PS_REG_WR;
  reg         PS_REG_RD;
  reg  [31:0] PS_REG_DIN;
  wire [31:0] PS_REG_DOUT;
  reg  [31:0] PS_RDATA;  // SuppressThisWarning VEditor - not used - just view
/*  
  reg  [31:0] afi_reg_addr; 
  reg         afi_reg_wr;
  reg         afi_reg_rd;
  reg  [31:0] afi_reg_din;
  wire [31:0] afi_reg_dout;
  reg  [31:0] AFI_REG_RD; // SuppressThisWarning VEditor - not used - just view
*/  
  initial begin
    PS_REG_ADDR <= 'bx;
    PS_REG_WR   <= 0;
    PS_REG_RD   <= 0;
    PS_REG_DIN  <= 'bx;
    PS_RDATA    <= 'bx;
  end 
  always @ (posedge HCLK) if (PS_REG_RD) PS_RDATA <= PS_REG_DOUT;
  
  reg [639:0] TEST_TITLE;
  // Simulation signals
  reg [11:0] ARID_IN_r;
  reg [31:0] ARADDR_IN_r;
  reg  [3:0] ARLEN_IN_r;
  reg  [2:0] ARSIZE_IN_r;
  reg  [1:0] ARBURST_IN_r;
  reg [11:0] AWID_IN_r;
  reg [31:0] AWADDR_IN_r;
  reg  [3:0] AWLEN_IN_r;
  reg  [2:0] AWSIZE_IN_r;
  reg  [1:0] AWBURST_IN_r;

  reg [11:0] WID_IN_r;
  reg [31:0] WDATA_IN_r;
  reg [ 3:0] WSTRB_IN_r;
  reg        WLAST_IN_r;
  
  reg [11:0] LAST_ARID; // last issued ARID

  // SuppressWarnings VEditor : assigned in $readmem() system task
  wire [SIMUL_AXI_READ_WIDTH-1:0] SIMUL_AXI_ADDR_W;
  // SuppressWarnings VEditor
  wire        SIMUL_AXI_MISMATCH;
  // SuppressWarnings VEditor
  reg  [31:0] SIMUL_AXI_READ;
  // SuppressWarnings VEditor
  reg  [SIMUL_AXI_READ_WIDTH-1:0] SIMUL_AXI_ADDR;
  // SuppressWarnings VEditor
  reg         SIMUL_AXI_FULL; // some data available
  wire        SIMUL_AXI_EMPTY= ~rvalid && rready && (rid==LAST_ARID); //SuppressThisWarning VEditor : may be unused, just for simulation // use it to wait for?
  reg  [31:0] registered_rdata; // here read data from tasks goes
  // SuppressWarnings VEditor
  reg         WAITING_STATUS;   // tasks are waiting for status

  reg        CLK;
  reg        RST;
  reg        AR_SET_CMD_r;
  wire       AR_READY;

  reg        AW_SET_CMD_r;
  wire       AW_READY;

  reg        W_SET_CMD_r;
  wire       W_READY;

  wire [11:0]  #(AXI_TASK_HOLD) ARID_IN = ARID_IN_r;
  wire [31:0]  #(AXI_TASK_HOLD) ARADDR_IN = ARADDR_IN_r;
  wire  [3:0]  #(AXI_TASK_HOLD) ARLEN_IN = ARLEN_IN_r;
  wire  [2:0]  #(AXI_TASK_HOLD) ARSIZE_IN = ARSIZE_IN_r;
  wire  [1:0]  #(AXI_TASK_HOLD) ARBURST_IN = ARBURST_IN_r;
  wire [11:0]  #(AXI_TASK_HOLD) AWID_IN = AWID_IN_r;
  wire [31:0]  #(AXI_TASK_HOLD) AWADDR_IN = AWADDR_IN_r;
  wire  [3:0]  #(AXI_TASK_HOLD) AWLEN_IN = AWLEN_IN_r;
  wire  [2:0]  #(AXI_TASK_HOLD) AWSIZE_IN = AWSIZE_IN_r;
  wire  [1:0]  #(AXI_TASK_HOLD) AWBURST_IN = AWBURST_IN_r;
  wire [11:0]  #(AXI_TASK_HOLD) WID_IN = WID_IN_r;
  wire [31:0]  #(AXI_TASK_HOLD) WDATA_IN = WDATA_IN_r;
  wire [ 3:0]  #(AXI_TASK_HOLD) WSTRB_IN = WSTRB_IN_r;
  wire         #(AXI_TASK_HOLD) WLAST_IN = WLAST_IN_r;
  wire         #(AXI_TASK_HOLD) AR_SET_CMD = AR_SET_CMD_r;
  wire         #(AXI_TASK_HOLD) AW_SET_CMD = AW_SET_CMD_r;
  wire         #(AXI_TASK_HOLD) W_SET_CMD =  W_SET_CMD_r;

  reg  [3:0] RD_LAG;  // ready signal lag in axi read channel (0 - RDY=1, 1..15 - RDY is asserted N cycles after valid)   
  reg  [3:0] B_LAG;   // ready signal lag in axi arete response channel (0 - RDY=1, 1..15 - RDY is asserted N cycles after valid)   

// Simulation modules interconnection
  wire [11:0] arid;
  wire [31:0] araddr;
  wire [3:0]  arlen;
  wire [2:0]  arsize;
  wire [1:0]  arburst;
  // SuppressWarnings VEditor : assigned in $readmem(14) system task
  wire [3:0]  arcache;
  // SuppressWarnings VEditor : assigned in $readmem() system task
  wire [2:0]  arprot;
  wire        arvalid;
  wire        arready;

  wire [11:0] awid;
  wire [31:0] awaddr;
  wire [3:0]  awlen;
  wire [2:0]  awsize;
  wire [1:0]  awburst;
  // SuppressWarnings VEditor : assigned in $readmem() system task
  wire [3:0]  awcache;
  // SuppressWarnings VEditor : assigned in $readmem() system task
  wire [2:0]  awprot;
  wire        awvalid;
  wire        awready;

  wire [11:0] wid;
  wire [31:0] wdata;
  wire [3:0]  wstrb;
  wire        wlast;
  wire        wvalid;
  wire        wready;
  
  wire [31:0] rdata;
  // SuppressWarnings VEditor : assigned in $readmem() system task
  wire [11:0] rid;
  wire        rlast;
  // SuppressWarnings VEditor : assigned in $readmem() system task
  wire  [1:0] rresp;
  wire        rvalid;
  wire        rready;
  wire        rstb=rvalid && rready;

  // SuppressWarnings VEditor : assigned in $readmem() system task
  wire  [1:0] bresp;
  // SuppressWarnings VEditor : assigned in $readmem() system task
  wire [11:0] bid;
  wire        bvalid;
  wire        bready;
  integer     NUM_WORDS_READ;
  integer     NUM_WORDS_EXPECTED;
  reg  [15:0] ENABLED_CHANNELS = 0; // currently enabled memory channels
//  integer     SCANLINE_CUR_X;
//  integer     SCANLINE_CUR_Y;
  wire AXI_RD_EMPTY=NUM_WORDS_READ==NUM_WORDS_EXPECTED; //SuppressThisWarning VEditor : may be unused, just for simulation
  
  
  
  //NUM_XFER_BITS=6
//  localparam       SCANLINE_PAGES_PER_ROW= (WINDOW_WIDTH>>NUM_XFER_BITS)+((WINDOW_WIDTH[NUM_XFER_BITS-1:0]==0)?0:1);
//  localparam       TILES_PER_ROW= (WINDOW_WIDTH/TILE_WIDTH)+  ((WINDOW_WIDTH % TILE_WIDTH==0)?0:1);
//  localparam       TILE_ROWS_PER_WINDOW= ((WINDOW_HEIGHT-1)/TILE_VSTEP) + 1;
  
//  localparam       TILE_SIZE= TILE_WIDTH*TILE_HEIGHT;
  
  
//  localparam  integer     SCANLINE_FULL_XFER= 1<<NUM_XFER_BITS; // 64 - full page transfer in 8-bursts
//  localparam  integer     SCANLINE_LAST_XFER= WINDOW_WIDTH % (1<<NUM_XFER_BITS); // last page transfer size in a row
  
//  integer ii;
//  integer  SCANLINE_XFER_SIZE;
always #(CLKIN_PERIOD/2) CLK = ~CLK;
  initial begin
`ifdef IVERILOG              
    $display("IVERILOG is defined");
`else
    $display("IVERILOG is not defined");
`endif

`ifdef ICARUS              
    $display("ICARUS is defined");
`else
    $display("ICARUS is not defined");
`endif
    $dumpfile(lxtname);
  // SuppressWarnings VEditor : assigned in $readmem() system task
    $dumpvars(0,x393_testbench01);
    CLK =1'b0;
    RST = 1'bx;
    AR_SET_CMD_r = 1'b0;
    AW_SET_CMD_r = 1'b0;
    W_SET_CMD_r = 1'b0;
    #500;
//    $display ("x393_i.ddrc_sequencer_i.phy_cmd_i.phy_top_i.rst=%d",x393_i.ddrc_sequencer_i.phy_cmd_i.phy_top_i.rst);
    #500;
    RST = 1'b1;
    NUM_WORDS_EXPECTED =0;
//    #99000; // same as glbl
    #9000; // same as glbl
    repeat (20) @(posedge CLK) ;
    RST =1'b0;
//set simulation-only parameters   
    axi_set_b_lag(0); //(1);
    axi_set_rd_lag(0);
    program_status_all(DEFAULT_STATUS_MODE,'h2a); // mode auto with sequence number increment 

    enable_memcntrl(1);                 // enable memory controller

    set_up;
    axi_set_wbuf_delay(WBUF_DLY_DFLT); //DFLT_WBUF_DELAY - used in synth. code
    
    wait_phase_shifter_ready;
    read_all_status;
    
// enable output for address/commands to DDR chip    
    enable_cmda(1);
    repeat (16) @(posedge CLK) ;
// remove reset from DDR chip    
    activate_sdrst(0); // was enabled at system reset

    #5000; // actually 500 usec required
    repeat (16) @(posedge CLK) ;
    enable_cke(1);
    repeat (16) @(posedge CLK) ;
    
//    enable_memcntrl(1);                 // enable memory controller
    enable_memcntrl_channels(16'h0003); // only channel 0 and 1 are enabled
    configure_channel_priority(0,0);    // lowest priority channel 0
    configure_channel_priority(1,0);    // lowest priority channel 1
    enable_reset_ps_pio(1,0);           // enable, no reset

// set MR registers in DDR3 memory, run DCI calibration (long)
    wait_ps_pio_ready(DEFAULT_STATUS_MODE, 1); // wait FIFO not half full 
    schedule_ps_pio ( // schedule software-control memory operation (may need to check FIFO status first)
                        INITIALIZE_OFFSET, // input [9:0] seq_addr; // sequence start address
                        0,                 // input [1:0] page;     // buffer page number
                        0,                 // input       urgent;   // high priority request (only for competion with other channels, wiil not pass in this FIFO)
                        0,                // input       chn;      // channel buffer to use: 0 - memory read, 1 - memory write
                        `PS_PIO_WAIT_COMPLETE );//  wait_complete; // Do not request a newe transaction from the scheduler until previous memory transaction is finished
                        
   
`ifdef WAIT_MRS 
    wait_ps_pio_done(DEFAULT_STATUS_MODE, 1);
`else    
    repeat (32) @(posedge CLK) ;  // what delay is needed to be sure? Add to PS_PIO?
//    first refreshes will be fast (accummulated while waiting)
`endif    
    enable_refresh(1);
    axi_set_dqs_odelay('h78); //??? dafaults - wrong?
    axi_set_dqs_odelay_nominal;
    
`ifdef TEST_WRITE_LEVELLING 
    TEST_TITLE = "WRITE_LEVELLING";
    $display("===================== TEST_%s =========================",TEST_TITLE);
    test_write_levelling;
`endif
`ifdef TEST_READ_PATTERN
    TEST_TITLE = "READ_PATTERN";
    $display("===================== TEST_%s =========================",TEST_TITLE);
    test_read_pattern;
`endif
`ifdef TEST_WRITE_BLOCK
    TEST_TITLE = "WRITE_BLOCK";
    $display("===================== TEST_%s =========================",TEST_TITLE);
    test_write_block;
`endif
`ifdef TEST_READ_BLOCK
    TEST_TITLE = "READ_BLOCK";
    $display("===================== TEST_%s =========================",TEST_TITLE);
    test_read_block;
`endif
`ifdef TESTL_SHORT_SCANLINE
    TEST_TITLE = "TESTL_SHORT_SCANLINE";
    $display("===================== TEST_%s =========================",TEST_TITLE);
    test_scanline_write(
        1, // valid: 1 or 3 input            [3:0] channel;
        SCANLINE_EXTRA_PAGES, // input            [1:0] extra_pages;
        1, // input                  wait_done;
        1, //WINDOW_WIDTH,
        WINDOW_HEIGHT,
        WINDOW_X0,
        WINDOW_Y0);
    test_scanline_read (
        1, // valid: 1 or 3 input            [3:0] channel;
        SCANLINE_EXTRA_PAGES, // input            [1:0] extra_pages;
        1, // input                  show_data;
        1, // WINDOW_WIDTH,
        WINDOW_HEIGHT,
        WINDOW_X0,
        WINDOW_Y0);

    test_scanline_write(
        1, // valid: 1 or 3 input            [3:0] channel;
        SCANLINE_EXTRA_PAGES, // input            [1:0] extra_pages;
        1, // input                  wait_done;
        2, //WINDOW_WIDTH,
        WINDOW_HEIGHT,
        WINDOW_X0,
        WINDOW_Y0);
    test_scanline_read (
        1, // valid: 1 or 3 input            [3:0] channel;
        SCANLINE_EXTRA_PAGES, // input            [1:0] extra_pages;
        1, // input                  show_data;
        2, // WINDOW_WIDTH,
        WINDOW_HEIGHT,
        WINDOW_X0,
        WINDOW_Y0);

    test_scanline_write(
        1, // valid: 1 or 3 input            [3:0] channel;
        SCANLINE_EXTRA_PAGES, // input            [1:0] extra_pages;
        1, // input                  wait_done;
        3, //WINDOW_WIDTH,
        WINDOW_HEIGHT,
        WINDOW_X0,
        WINDOW_Y0);
    test_scanline_read (
        1, // valid: 1 or 3 input            [3:0] channel;
        SCANLINE_EXTRA_PAGES, // input            [1:0] extra_pages;
        1, // input                  show_data;
        3, // WINDOW_WIDTH,
        WINDOW_HEIGHT,
        WINDOW_X0,
        WINDOW_Y0);



`endif

`ifdef TEST_SCANLINE_WRITE
    TEST_TITLE = "SCANLINE_WRITE";
    $display("===================== TEST_%s =========================",TEST_TITLE);
    test_scanline_write(
        3, // valid: 1 or 3 input            [3:0] channel; now - 3 only, 1 is for afi
        SCANLINE_EXTRA_PAGES, // input            [1:0] extra_pages;
        1, // input                  wait_done;
        WINDOW_WIDTH,
        WINDOW_HEIGHT,
        WINDOW_X0,
        WINDOW_Y0);
        
`endif
`ifdef TEST_SCANLINE_READ
    TEST_TITLE = "SCANLINE_READ";
    $display("===================== TEST_%s =========================",TEST_TITLE);
    test_scanline_read (
        3, // valid: 1 or 3 input            [3:0] channel; now - 3 only, 1 is for afi
        SCANLINE_EXTRA_PAGES, // input            [1:0] extra_pages;
        1, // input                  show_data;
        WINDOW_WIDTH,
        WINDOW_HEIGHT,
        WINDOW_X0,
        WINDOW_Y0);
        
`endif

`ifdef TEST_TILED_WRITE
    TEST_TITLE = "TILED_WRITE";
    $display("===================== TEST_%s =========================",TEST_TITLE);
    test_tiled_write (
         2,                 // [3:0] channel;
         0,                 //       byte32;
         TILED_KEEP_OPEN,   //       keep_open;
         TILED_EXTRA_PAGES, //       extra_pages;
         1,                //       wait_done;
        WINDOW_WIDTH,
        WINDOW_HEIGHT,
        WINDOW_X0,
        WINDOW_Y0,
        TILE_WIDTH,
        TILE_HEIGHT,
        TILE_VSTEP);
`endif

`ifdef TEST_TILED_READ
    TEST_TITLE = "TILED_READ";
    $display("===================== TEST_%s =========================",TEST_TITLE);
    test_tiled_read (
        2,                 // [3:0] channel;
        0,                 //       byte32;
        TILED_KEEP_OPEN,   //       keep_open;
        TILED_EXTRA_PAGES, //       extra_pages;
        1,                 //       show_data;
        WINDOW_WIDTH,
        WINDOW_HEIGHT,
        WINDOW_X0,
        WINDOW_Y0,
        TILE_WIDTH,
        TILE_HEIGHT,
        TILE_VSTEP);
         
`endif

`ifdef TEST_TILED_WRITE32
    TEST_TITLE = "TILED_WRITE32";
    $display("===================== TEST_%s =========================",TEST_TITLE);
    test_tiled_write (
        2, // 4, // 2,                 // [3:0] channel;
        1,                 //       byte32;
        TILED_KEEP_OPEN,   //       keep_open;
        TILED_EXTRA_PAGES, //       extra_pages;
        1,                 //       wait_done;
        WINDOW_WIDTH,
        WINDOW_HEIGHT,
        WINDOW_X0,
        WINDOW_Y0,
        TILE_WIDTH,
        TILE_HEIGHT,
        TILE_VSTEP);
`endif

`ifdef TEST_TILED_READ32
    TEST_TITLE = "TILED_READ32";
    $display("===================== TEST_%s =========================",TEST_TITLE);
    test_tiled_read (
        2, // 4, //2,                 // [3:0] channel;
        1,                 //       byte32;
        TILED_KEEP_OPEN,   //       keep_open;
        TILED_EXTRA_PAGES, //       extra_pages;
        1,                 //       show_data;
        WINDOW_WIDTH,
        WINDOW_HEIGHT,
        WINDOW_X0,
        WINDOW_Y0,
        TILE_WIDTH,
        TILE_HEIGHT,
        TILE_VSTEP);
`endif

`ifdef TEST_AFI_WRITE
    TEST_TITLE = "AFI_WRITE";
    $display("===================== TEST_%s =========================",TEST_TITLE);
    test_afi_rw (
       1, // write_ddr3;
       SCANLINE_EXTRA_PAGES,//  extra_pages;
       FRAME_START_ADDRESS, //  input [21:0] frame_start_addr;
       FRAME_FULL_WIDTH,    // input [15:0] window_full_width; // 13 bit - in 8*16=128 bit bursts
       WINDOW_WIDTH,        // input [15:0] window_width;  // 13 bit - in 8*16=128 bit bursts
       WINDOW_HEIGHT,       // input [15:0] window_height; // 16 bit (only 14 are used here)
       WINDOW_X0,           // input [15:0] window_left;
       WINDOW_Y0,           // input [15:0] window_top;
       0,                   // input [28:0] start64;  // relative start address of the transfer (set to 0 when writing lo_addr64)
       AFI_LO_ADDR64,       // input [28:0] lo_addr64; // low address of the system memory range, in 64-bit words 
       AFI_SIZE64,          // input [28:0] size64;    // size of the system memory range in 64-bit words
       0);                  // input        continue;    // 0 start from start64, 1 - continue from where it was
`endif


`ifdef TEST_AFI_READ
    TEST_TITLE = "AFI_READ";
    $display("===================== TEST_%s =========================",TEST_TITLE);
    test_afi_rw (
       0, // write_ddr3;
       SCANLINE_EXTRA_PAGES,//  extra_pages;
       FRAME_START_ADDRESS, //  input [21:0] frame_start_addr;
       FRAME_FULL_WIDTH,    // input [15:0] window_full_width; // 13 bit - in 8*16=128 bit bursts
       WINDOW_WIDTH,        // input [15:0] window_width;  // 13 bit - in 8*16=128 bit bursts
       WINDOW_HEIGHT,       // input [15:0] window_height; // 16 bit (only 14 are used here)
       WINDOW_X0,           // input [15:0] window_left;
       WINDOW_Y0,           // input [15:0] window_top;
       0,                   // input [28:0] start64;  // relative start address of the transfer (set to 0 when writing lo_addr64)
       AFI_LO_ADDR64,       // input [28:0] lo_addr64; // low address of the system memory range, in 64-bit words 
       AFI_SIZE64,          // input [28:0] size64;    // size of the system memory range in 64-bit words
       0);                  // input        continue;    // 0 start from start64, 1 - continue from where it was
    $display("===================== #2 TEST_%s =========================",TEST_TITLE);
    test_afi_rw (
       0, // write_ddr3;
       SCANLINE_EXTRA_PAGES,//  extra_pages;
       FRAME_START_ADDRESS, //  input [21:0] frame_start_addr;
       FRAME_FULL_WIDTH,    // input [15:0] window_full_width; // 13 bit - in 8*16=128 bit bursts
       WINDOW_WIDTH,        // input [15:0] window_width;  // 13 bit - in 8*16=128 bit bursts
       WINDOW_HEIGHT,       // input [15:0] window_height; // 16 bit (only 14 are used here)
       WINDOW_X0,           // input [15:0] window_left;
       WINDOW_Y0,           // input [15:0] window_top;
       0,                   // input [28:0] start64;  // relative start address of the transfer (set to 0 when writing lo_addr64)
       AFI_LO_ADDR64,       // input [28:0] lo_addr64; // low address of the system memory range, in 64-bit words 
       AFI_SIZE64,          // input [28:0] size64;    // size of the system memory range in 64-bit words
       0);                  // input        continue;    // 0 start from start64, 1 - continue from where it was
       
`endif

`ifdef READBACK_DELAYS    
  TEST_TITLE = "READBACK";
  $display("===================== TEST_%s =========================",TEST_TITLE);
    axi_get_delays;
`endif    


  TEST_TITLE = "ALL_DONE";
  $display("===================== TEST_%s =========================",TEST_TITLE);
  #20000;
  $finish;
end
// protect from never end
  initial begin
//       #30000;
     #200000;
//     #60000;
    $display("finish testbench 2");
  $finish;
  end



assign x393_i.ps7_i.FCLKCLK=        {4{CLK}};
assign x393_i.ps7_i.FCLKRESETN=     {RST,~RST,RST,~RST};
// Read address
assign x393_i.ps7_i.MAXIGP0ARADDR=  araddr;
assign x393_i.ps7_i.MAXIGP0ARVALID= arvalid;
assign arready=                            x393_i.ps7_i.MAXIGP0ARREADY;
assign x393_i.ps7_i.MAXIGP0ARID=    arid; 
assign x393_i.ps7_i.MAXIGP0ARLEN=   arlen;
assign x393_i.ps7_i.MAXIGP0ARSIZE=  arsize[1:0]; // arsize[2] is not used
assign x393_i.ps7_i.MAXIGP0ARBURST= arburst;
// Read data
assign rdata=                              x393_i.ps7_i.MAXIGP0RDATA; 
assign rvalid=                             x393_i.ps7_i.MAXIGP0RVALID;
assign x393_i.ps7_i.MAXIGP0RREADY=  rready;
assign rid=                                x393_i.ps7_i.MAXIGP0RID;
assign rlast=                              x393_i.ps7_i.MAXIGP0RLAST;
assign rresp=                              x393_i.ps7_i.MAXIGP0RRESP;
// Write address
assign x393_i.ps7_i.MAXIGP0AWADDR=  awaddr;
assign x393_i.ps7_i.MAXIGP0AWVALID= awvalid;

assign awready=                            x393_i.ps7_i.MAXIGP0AWREADY;

//assign awready= AWREADY_AAAA;
assign x393_i.ps7_i.MAXIGP0AWID=awid;

      // SuppressWarnings VEditor all
//  wire [ 1:0] AWLOCK;
      // SuppressWarnings VEditor all
//  wire [ 3:0] AWCACHE;
      // SuppressWarnings VEditor all
//  wire [ 2:0] AWPROT;
assign x393_i.ps7_i.MAXIGP0AWLEN=   awlen;
assign x393_i.ps7_i.MAXIGP0AWSIZE=  awsize[1:0]; // awsize[2] is not used
assign x393_i.ps7_i.MAXIGP0AWBURST= awburst;
      // SuppressWarnings VEditor all
//  wire [ 3:0] AWQOS;
// Write data
assign x393_i.ps7_i.MAXIGP0WDATA=   wdata;
assign x393_i.ps7_i.MAXIGP0WVALID=  wvalid;
assign wready=                             x393_i.ps7_i.MAXIGP0WREADY;
assign x393_i.ps7_i.MAXIGP0WID=     wid;
assign x393_i.ps7_i.MAXIGP0WLAST=   wlast;
assign x393_i.ps7_i.MAXIGP0WSTRB=   wstrb;
// Write response
assign bvalid=                             x393_i.ps7_i.MAXIGP0BVALID;
assign x393_i.ps7_i.MAXIGP0BREADY=  bready;
assign bid=                                x393_i.ps7_i.MAXIGP0BID;
assign bresp=                              x393_i.ps7_i.MAXIGP0BRESP;
//TODO: See how to show problems in include files opened in the editor (test all top *.v files that have it)
// Top module under test
    x393 #(
        .MCONTR_WR_MASK                    (MCONTR_WR_MASK),
        .MCONTR_RD_MASK                    (MCONTR_RD_MASK),
        .MCONTR_CMD_WR_ADDR                (MCONTR_CMD_WR_ADDR),
        .MCONTR_BUF0_RD_ADDR               (MCONTR_BUF0_RD_ADDR),
        .MCONTR_BUF0_WR_ADDR               (MCONTR_BUF0_WR_ADDR),
//        .MCONTR_BUF1_RD_ADDR               (MCONTR_BUF1_RD_ADDR),
//        .MCONTR_BUF1_WR_ADDR               (MCONTR_BUF1_WR_ADDR),
        .MCONTR_BUF2_RD_ADDR               (MCONTR_BUF2_RD_ADDR),
        .MCONTR_BUF2_WR_ADDR               (MCONTR_BUF2_WR_ADDR),
        .MCONTR_BUF3_RD_ADDR               (MCONTR_BUF3_RD_ADDR),
        .MCONTR_BUF3_WR_ADDR               (MCONTR_BUF3_WR_ADDR),
        .MCONTR_BUF4_RD_ADDR               (MCONTR_BUF4_RD_ADDR),
        .MCONTR_BUF4_WR_ADDR               (MCONTR_BUF4_WR_ADDR),
        .CONTROL_ADDR                      (CONTROL_ADDR),
        .CONTROL_ADDR_MASK                 (CONTROL_ADDR_MASK),
        .STATUS_ADDR                       (STATUS_ADDR),
        .STATUS_ADDR_MASK                  (STATUS_ADDR_MASK),
        .AXI_WR_ADDR_BITS                  (AXI_WR_ADDR_BITS),
        .AXI_RD_ADDR_BITS                  (AXI_RD_ADDR_BITS),
        .STATUS_DEPTH                      (STATUS_DEPTH),
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
        .NUM_CYCLES_LOW_BIT                (NUM_CYCLES_LOW_BIT),
        .NUM_CYCLES_00                     (NUM_CYCLES_00),
        .NUM_CYCLES_01                     (NUM_CYCLES_01),
        .NUM_CYCLES_02                     (NUM_CYCLES_02),
        .NUM_CYCLES_03                     (NUM_CYCLES_03),
        .NUM_CYCLES_04                     (NUM_CYCLES_04),
        .NUM_CYCLES_05                     (NUM_CYCLES_05),
        .NUM_CYCLES_06                     (NUM_CYCLES_06),
        .NUM_CYCLES_07                     (NUM_CYCLES_07),
        .NUM_CYCLES_08                     (NUM_CYCLES_08),
        .NUM_CYCLES_09                     (NUM_CYCLES_09),
        .NUM_CYCLES_10                     (NUM_CYCLES_10),
        .NUM_CYCLES_11                     (NUM_CYCLES_11),
        .NUM_CYCLES_12                     (NUM_CYCLES_12),
        .NUM_CYCLES_13                     (NUM_CYCLES_13),
        .NUM_CYCLES_14                     (NUM_CYCLES_14),
        .NUM_CYCLES_15                     (NUM_CYCLES_15),
        .MCNTRL_PS_ADDR                    (MCNTRL_PS_ADDR),
        .MCNTRL_PS_MASK                    (MCNTRL_PS_MASK),
        .MCNTRL_PS_STATUS_REG_ADDR         (MCNTRL_PS_STATUS_REG_ADDR),
        .MCNTRL_PS_EN_RST                  (MCNTRL_PS_EN_RST),
        .MCNTRL_PS_CMD                     (MCNTRL_PS_CMD),
        .MCNTRL_PS_STATUS_CNTRL            (MCNTRL_PS_STATUS_CNTRL),
        .NUM_XFER_BITS                     (NUM_XFER_BITS),
        .FRAME_WIDTH_BITS                  (FRAME_WIDTH_BITS),
        .FRAME_HEIGHT_BITS                 (FRAME_HEIGHT_BITS),
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
        .MCNTRL_TEST01_ADDR                 (MCNTRL_TEST01_ADDR),
        .MCNTRL_TEST01_MASK                 (MCNTRL_TEST01_MASK),
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
    ) x393_i (
        .SDRST   (SDRST), // DDR3 reset (active low)
        .SDCLK   (SDCLK), // output 
        .SDNCLK  (SDNCLK), // outputread_and_wait(BASEADDR_STATUS)
        .SDA     (SDA[14:0]), // output[14:0] 
        .SDBA    (SDBA[2:0]), // output[2:0] 
        .SDWE    (SDWE), // output
        .SDRAS   (SDRAS), // output
        .SDCAS   (SDCAS), // output
        .SDCKE   (SDCKE), // output
        .SDODT   (SDODT), // output
        .SDD     (SDD[15:0]), // inout[15:0] 
        .SDDML   (SDDML), // inout
        .DQSL    (DQSL), // inout
        .NDQSL   (NDQSL), // inout
        .SDDMU   (SDDMU), // inout
        .DQSU    (DQSU), // inout
        .NDQSU   (NDQSU), // inout
        .DUMMY_TO_KEEP(DUMMY_TO_KEEP)  // to keep PS7 signals from "optimization"
      ,.MEMCLK  (1'b0)
    );
    // just to simplify extra delays in tri-state memory bus - provide output enable
    wire WRAP_MCLK=x393_i.mclk;
    wire [7:0] WRAP_PHY_DQ_TRI=x393_i.mcntrl393_i.memctrl16_i.mcontr_sequencer_i.phy_cmd_i.phy_dq_tri[7:0] ;
    wire [7:0] WRAP_PHY_DQS_TRI=x393_i.mcntrl393_i.memctrl16_i.mcontr_sequencer_i.phy_cmd_i.phy_dqs_tri[7:0] ;    
    //x393_i.mcntrl393_i.mcntrl16_i.mcontr_sequencer_i.phy_cmd_i.phy_dq_tri
    //x393_i.mcntrl393_i.mcntrl16_i.mcontr_sequencer_i.phy_cmd_i.phy_dqs_tri
`define USE_DDR3_WRAP 1    
`ifdef USE_DDR3_WRAP
    ddr3_wrap #(
        .ADDRESS_NUMBER     (ADDRESS_NUMBER),
        .TRISTATE_DELAY_CLK (4'h1), // total 2
        .TRISTATE_DELAY     (0),
        .CLK_DELAY          (1550),
        .CMDA_DELAY         (1550),
        .DQS_IN_DELAY       (3150),
        .DQ_IN_DELAY        (1550),
        .DQS_OUT_DELAY      (1550),
        .DQ_OUT_DELAY       (1550)
    ) ddr3_i (
        .mclk    (WRAP_MCLK), // input
        .dq_tri  ({WRAP_PHY_DQ_TRI[4],WRAP_PHY_DQ_TRI[0]}), // input[1:0] 
        .dqs_tri ({WRAP_PHY_DQS_TRI[4],WRAP_PHY_DQS_TRI[0]}), // input[1:0] 
        .SDRST   (SDRST), 
        .SDCLK   (SDCLK), 
        .SDNCLK  (SDNCLK), 
        .SDCKE   (SDCKE), 
        .SDRAS   (SDRAS), 
        .SDCAS   (SDCAS), 
        .SDWE    (SDWE), 
        .SDDMU   (SDDMU),
        .SDDML   (SDDML),
        .SDBA    (SDBA[2:0]),  
        .SDA     (SDA[ADDRESS_NUMBER-1:0]), 
        .SDD     (SDD[15:0]),  
        .DQSU    (DQSU),
        .NDQSU   (NDQSU),
        .DQSL    (DQSL),
        .NDQSL   (NDQSL),
        .SDODT   (SDODT)          // input 
    );
`else
    ddr3 #(
        .TCK_MIN             (2500), 
        .TJIT_PER            (100),
        .TJIT_CC             (200),
        .TERR_2PER           (147),
        .TERR_3PER           (175),
        .TERR_4PER           (194),
        .TERR_5PER           (209),
        .TERR_6PER           (222),
        .TERR_7PER           (232),
        .TERR_8PER           (241),
        .TERR_9PER           (249),
        .TERR_10PER          (257),
        .TERR_11PER          (263),
        .TERR_12PER          (269),
        .TDS                 (125),
        .TDH                 (150),
        .TDQSQ               (200),
        .TDQSS               (0.25),
        .TDSS                (0.20),
        .TDSH                (0.20),
        .TDQSCK              (400),
        .TQSH                (0.38),
        .TQSL                (0.38),
        .TDIPW               (600),
        .TIPW                (900),
        .TIS                 (350),
        .TIH                 (275),
        .TRAS_MIN            (37500),
        .TRC                 (52500),
        .TRCD                (15000),
        .TRP                 (15000),
        .TXP                 (7500),
        .TCKE                (7500),
        .TAON                (400),
        .TWLS                (325),
        .TWLH                (325),
        .TWLO                (9000),
        .TAA_MIN             (15000),
        .CL_TIME             (15000),
        .TDQSCK_DLLDIS       (400),
        .TRRD                (10000),
        .TFAW                (40000),
        .CL_MIN              (5),
        .CL_MAX              (14),
        .AL_MIN              (0),
        .AL_MAX              (2),
        .WR_MIN              (5),
        .WR_MAX              (16),
        .BL_MIN              (4),
        .BL_MAX              (8),
        .CWL_MIN             (5),
        .CWL_MAX             (10),
        .TCK_MAX             (3300),
        .TCH_AVG_MIN         (0.47),
        .TCL_AVG_MIN         (0.47),
        .TCH_AVG_MAX         (0.53),
        .TCL_AVG_MAX         (0.53),
        .TCH_ABS_MIN         (0.43),
        .TCL_ABS_MIN         (0.43),
        .TCKE_TCK            (3),
        .TAA_MAX             (20000),
        .TQH                 (0.38),
        .TRPRE               (0.90),
        .TRPST               (0.30),
        .TDQSH               (0.45),
        .TDQSL               (0.45),
        .TWPRE               (0.90),
        .TWPST               (0.30),
        .TCCD                (4),
        .TCCD_DG             (2),
        .TRAS_MAX            (60e9),
        .TWR                 (15000),
        .TMRD                (4),
        .TMOD                (15000),
        .TMOD_TCK            (12),
        .TRRD_TCK            (4),
        .TRRD_DG             (3000),
        .TRRD_DG_TCK         (2),
        .TRTP                (7500),
        .TRTP_TCK            (4),
        .TWTR                (7500),
        .TWTR_DG             (3750),
        .TWTR_TCK            (4),
        .TWTR_DG_TCK         (2),
        .TDLLK               (512),
        .TRFC_MIN            (260000),
        .TRFC_MAX            (70200000),
        .TXP_TCK             (3),
        .TXPDLL              (24000),
        .TXPDLL_TCK          (10),
        .TACTPDEN            (1),
        .TPRPDEN             (1),
        .TREFPDEN            (1),
        .TCPDED              (1),
        .TPD_MAX             (70200000),
        .TXPR                (270000),
        .TXPR_TCK            (5),
        .TXS                 (270000),
        .TXS_TCK             (5),
        .TXSDLL              (512),
        .TISXR               (350),
        .TCKSRE              (10000),
        .TCKSRE_TCK          (5),
        .TCKSRX              (10000),
        .TCKSRX_TCK          (5),
        .TCKESR_TCK          (4),
        .TAOF                (0.7),
        .TAONPD              (8500),
        .TAOFPD              (8500),
        .ODTH4               (4),
        .ODTH8               (6),
        .TADC                (0.7),
        .TWLMRD              (40),
        .TWLDQSEN            (25),
        .TWLOE               (2000),
        .DM_BITS             (2),
        .ADDR_BITS           (15),
        .ROW_BITS            (15),
        .COL_BITS            (10),
        .DQ_BITS             (16),
        .DQS_BITS            (2),
        .BA_BITS             (3),
        .MEM_BITS            (10),
        .AP                  (10),
        .BC                  (12),
        .BL_BITS             (3),
        .BO_BITS             (2),
        .CS_BITS             (1),
        .RANKS               (1),
        .RZQ                 (240),
        .PRE_DEF_PAT         (8'hAA),
        .STOP_ON_ERROR       (1),
        .DEBUG               (1),
        .BUS_DELAY           (0),
        .RANDOM_OUT_DELAY    (0),
        .RANDOM_SEED         (31913),
        .RDQSEN_PRE          (2),
        .RDQSEN_PST          (1),
        .RDQS_PRE            (2),
        .RDQS_PST            (1),
        .RDQEN_PRE           (0),
        .RDQEN_PST           (0),
        .WDQS_PRE            (2),
        .WDQS_PST            (1),
        .check_strict_mrbits (1),
        .check_strict_timing (1),
        .feature_pasr        (1),
        .feature_truebl4     (0),
        .feature_odt_hi      (0),
        .PERTCKAVG           (512),
        .LOAD_MODE           (4'b0000),
        .REFRESH             (4'b0001),
        .PRECHARGE           (4'b0010),
        .ACTIVATE            (4'b0011),
        .WRITE               (4'b0100),
        .READ                (4'b0101),
        .ZQ                  (4'b0110),
        .NOP                 (4'b0111),
        .PWR_DOWN            (4'b1000),
        .SELF_REF            (4'b1001),
        .RFF_BITS            (128),
        .RFF_CHUNK           (32),
        .SAME_BANK           (2'd0),
        .DIFF_BANK           (2'd1),
        .DIFF_GROUP          (2'd2),
        .SIMUL_500US         (5),
        .SIMUL_200US         (2)
    ) ddr3_i (
        .rst_n   (SDRST),         // input 
        .ck      (SDCLK),         // input 
        .ck_n    (SDNCLK),        // input 
        .cke     (SDCKE),         // input 
        .cs_n    (1'b0),          // input 
        .ras_n   (SDRAS),         // input 
        .cas_n   (SDCAS),         // input 
        .we_n    (SDWE),          // input 
        .dm_tdqs ({SDDMU,SDDML}), // inout[1:0] 
        .ba      (SDBA[2:0]),     // input[2:0] 
        .addr    (SDA[14:0]),     // input[14:0] 
        .dq      (SDD[15:0]),     // inout[15:0] 
        .dqs     ({DQSU,DQSL}),   // inout[1:0] 
        .dqs_n   ({NDQSU,NDQSL}), // inout[1:0] 
        .tdqs_n  (),              // output[1:0] 
        .odt     (SDODT)          // input 
    );
`endif    
    
// Simulation modules    
simul_axi_master_rdaddr
#(
  .ID_WIDTH(12),
  .ADDRESS_WIDTH(32),
  .LATENCY(AXI_RDADDR_LATENCY),          // minimal delay between inout and output ( 0 - next cycle)
  .DEPTH(8),            // maximal number of commands in FIFO
  .DATA_DELAY(3.5),
  .VALID_DELAY(4.0)
) simul_axi_master_rdaddr_i (
    .clk(CLK),
    .reset(RST),
    .arid_in(ARID_IN[11:0]),
    .araddr_in(ARADDR_IN[31:0]),
    .arlen_in(ARLEN_IN[3:0]),
    .arsize_in(ARSIZE_IN[2:0]),
    .arburst_in(ARBURST_IN[1:0]),
    .arcache_in(4'b0),
    .arprot_in(3'b0), //     .arprot_in(2'b0),
    .arid(arid[11:0]),
    .araddr(araddr[31:0]),
    .arlen(arlen[3:0]),
    .arsize(arsize[2:0]),
    .arburst(arburst[1:0]),
    .arcache(arcache[3:0]),
    .arprot(arprot[2:0]),
    .arvalid(arvalid),
    .arready(arready),
    .set_cmd(AR_SET_CMD),  // latch all other input data at posedge of clock
    .ready(AR_READY)     // command/data FIFO can accept command
);

simul_axi_master_wraddr
#(
  .ID_WIDTH(12),
  .ADDRESS_WIDTH(32),
  .LATENCY(AXI_WRADDR_LATENCY),          // minimal delay between inout and output ( 0 - next cycle)
  .DEPTH(8),            // maximal number of commands in FIFO
  .DATA_DELAY(3.5),
  .VALID_DELAY(4.0)
) simul_axi_master_wraddr_i (
    .clk(CLK),
    .reset(RST),
    .awid_in(AWID_IN[11:0]),
    .awaddr_in(AWADDR_IN[31:0]),
    .awlen_in(AWLEN_IN[3:0]),
    .awsize_in(AWSIZE_IN[2:0]),
    .awburst_in(AWBURST_IN[1:0]),
    .awcache_in(4'b0),
    .awprot_in(3'b0), //.awprot_in(2'b0),
    .awid(awid[11:0]),
    .awaddr(awaddr[31:0]),
    .awlen(awlen[3:0]),
    .awsize(awsize[2:0]),
    .awburst(awburst[1:0]),
    .awcache(awcache[3:0]),
    .awprot(awprot[2:0]),
    .awvalid(awvalid),
    .awready(awready),
    .set_cmd(AW_SET_CMD),  // latch all other input data at posedge of clock
    .ready(AW_READY)     // command/data FIFO can accept command
);

simul_axi_master_wdata
#(
  .ID_WIDTH(12),
  .DATA_WIDTH(32),
  .WSTB_WIDTH(4),
  .LATENCY(AXI_WRDATA_LATENCY),          // minimal delay between inout and output ( 0 - next cycle)
  .DEPTH(8),            // maximal number of commands in FIFO
  .DATA_DELAY(3.2),
  .VALID_DELAY(3.6)
) simul_axi_master_wdata_i (
    .clk(CLK),
    .reset(RST),
    .wid_in(WID_IN[11:0]),
    .wdata_in(WDATA_IN[31:0]),
    .wstrb_in(WSTRB_IN[3:0]),
    .wlast_in(WLAST_IN),
    .wid(wid[11:0]),
    .wdata(wdata[31:0]),
    .wstrb(wstrb[3:0]),
    .wlast(wlast),
    .wvalid(wvalid),
    .wready(wready),
    .set_cmd(W_SET_CMD),  // latch all other input data at posedge of clock
    .ready(W_READY)        // command/data FIFO can accept command
);

simul_axi_slow_ready simul_axi_slow_ready_read_i(
    .clk(CLK),
    .reset(RST), //input         reset,
    .delay(RD_LAG), //input  [3:0]  delay,
    .valid(rvalid), // input         valid,
    .ready(rready)  //output        ready
    );

simul_axi_slow_ready simul_axi_slow_ready_write_resp_i(
    .clk(CLK),
    .reset(RST), //input         reset,
    .delay(B_LAG), //input  [3:0]  delay,
    .valid(bvalid), // input       ADDRESS_NUMBER+2:0  valid,
    .ready(bready)  //output        ready
    );

simul_axi_read #(
    .ADDRESS_WIDTH(SIMUL_AXI_READ_WIDTH)
  ) simul_axi_read_i(
  .clk(CLK),
  .reset(RST),
  .last(rlast),
  .data_stb(rstb),
  .raddr(ARADDR_IN[SIMUL_AXI_READ_WIDTH+1:2]), 
  .rlen(ARLEN_IN),
  .rcmd(AR_SET_CMD),
  .addr_out(SIMUL_AXI_ADDR_W[SIMUL_AXI_READ_WIDTH-1:0]),
  .burst(),     // burst in progress - just debug
  .err_out());  // data last does not match predicted or FIFO over/under run - just debug


simul_axi_hp_rd #(
        .HP_PORT(0)
    ) simul_axi_hp_rd_i (
        .rst            (RST),                               // input
        .aclk           (x393_i.ps7_i.SAXIHP0ACLK),          // input
        .aresetn        (),                                  // output
        .araddr         (x393_i.ps7_i.SAXIHP0ARADDR[31:0]),  // input[31:0] 
        .arvalid        (x393_i.ps7_i.SAXIHP0ARVALID),       // input
        .arready        (x393_i.ps7_i.SAXIHP0ARREADY),       // output
        .arid           (x393_i.ps7_i.SAXIHP0ARID),          // input[5:0] 
        .arlock         (x393_i.ps7_i.SAXIHP0ARLOCK),        // input[1:0] 
        .arcache        (x393_i.ps7_i.SAXIHP0ARCACHE),       // input[3:0] 
        .arprot         (x393_i.ps7_i.SAXIHP0ARPROT),        // input[2:0] 
        .arlen          (x393_i.ps7_i.SAXIHP0ARLEN),         // input[3:0] 
        .arsize         (x393_i.ps7_i.SAXIHP0ARSIZE),        // input[2:0] 
        .arburst        (x393_i.ps7_i.SAXIHP0ARBURST),       // input[1:0] 
        .arqos          (x393_i.ps7_i.SAXIHP0ARQOS),         // input[3:0] 
        .rdata          (x393_i.ps7_i.SAXIHP0RDATA),         // output[63:0] 
        .rvalid         (x393_i.ps7_i.SAXIHP0RVALID),        // output
        .rready         (x393_i.ps7_i.SAXIHP0RREADY),        // input
        .rid            (x393_i.ps7_i.SAXIHP0RID),           // output[5:0] 
        .rlast          (x393_i.ps7_i.SAXIHP0RLAST),         // output
        .rresp          (x393_i.ps7_i.SAXIHP0RRESP),         // output[1:0] 
        .rcount         (x393_i.ps7_i.SAXIHP0RCOUNT),        // output[7:0] 
        .racount        (x393_i.ps7_i.SAXIHP0RACOUNT),       // output[2:0] 
        .rdissuecap1en  (x393_i.ps7_i.SAXIHP0RDISSUECAP1EN), // input
        .sim_rd_address (afi_sim_rd_address), // output[31:0] 
        .sim_rid        (afi_sim_rid), // output[5:0] 
        .sim_rd_valid   (afi_sim_rd_valid), // input
        .sim_rd_ready   (afi_sim_rd_ready), // output
        .sim_rd_data    (afi_sim_rd_data), // input[63:0] 
        .sim_rd_cap     (afi_sim_rd_cap), // output[2:0] 
        .sim_rd_qos     (afi_sim_rd_qos), // output[3:0] 
        .sim_rd_resp    (afi_sim_rd_resp), // input[1:0] 
        .reg_addr       (PS_REG_ADDR), // input[31:0] 
        .reg_wr         (PS_REG_WR), // input
        .reg_rd         (PS_REG_RD), // input
        .reg_din        (PS_REG_DIN), // input[31:0] 
        .reg_dout       (PS_REG_DOUT) // output[31:0] 
    );

simul_axi_hp_wr #(
        .HP_PORT(0)
    ) simul_axi_hp_wr_i (
        .rst            (RST), // input
        .aclk           (x393_i.ps7_i.SAXIHP0ACLK),          // input
        .aresetn        (),                                  // output
        .awaddr         (x393_i.ps7_i.SAXIHP0AWADDR),        // input[31:0] 
        .awvalid        (x393_i.ps7_i.SAXIHP0AWVALID),       // input
        .awready        (x393_i.ps7_i.SAXIHP0AWREADY),       // output
        .awid           (x393_i.ps7_i.SAXIHP0AWID),          // input[5:0] 
        .awlock         (x393_i.ps7_i.SAXIHP0AWLOCK),        // input[1:0] 
        .awcache        (x393_i.ps7_i.SAXIHP0AWCACHE),       // input[3:0] 
        .awprot         (x393_i.ps7_i.SAXIHP0AWPROT),        // input[2:0] 
        .awlen          (x393_i.ps7_i.SAXIHP0AWLEN),         // input[3:0] 
        .awsize         (x393_i.ps7_i.SAXIHP0AWSIZE),        // input[2:0] 
        .awburst        (x393_i.ps7_i.SAXIHP0AWBURST),       // input[1:0] 
        .awqos          (x393_i.ps7_i.SAXIHP0AWQOS),         // input[3:0] 
        .wdata          (x393_i.ps7_i.SAXIHP0WDATA),         // input[63:0] 
        .wvalid         (x393_i.ps7_i.SAXIHP0WVALID),        // input
        .wready         (x393_i.ps7_i.SAXIHP0WREADY),        // output
        .wid            (x393_i.ps7_i.SAXIHP0WID),           // input[5:0] 
        .wlast          (x393_i.ps7_i.SAXIHP0WLAST),         // input
        .wstrb          (x393_i.ps7_i.SAXIHP0WSTRB),         // input[7:0] 
        .bvalid         (x393_i.ps7_i.SAXIHP0BVALID),        // output
        .bready         (x393_i.ps7_i.SAXIHP0BREADY),        // input
        .bid            (x393_i.ps7_i.SAXIHP0BID),           // output[5:0] 
        .bresp          (x393_i.ps7_i.SAXIHP0BRESP),         // output[1:0] 
        .wcount         (x393_i.ps7_i.SAXIHP0WCOUNT),        // output[7:0] 
        .wacount        (x393_i.ps7_i.SAXIHP0WACOUNT),       // output[5:0] 
        .wrissuecap1en  (x393_i.ps7_i.SAXIHP0WRISSUECAP1EN), // input
        .sim_wr_address (afi_sim_wr_address), // output[31:0] 
        .sim_wid        (afi_sim_wid), // output[5:0] 
        .sim_wr_valid   (afi_sim_wr_valid), // output
        .sim_wr_ready   (afi_sim_wr_ready), // input
        .sim_wr_data    (afi_sim_wr_data), // output[63:0] 
        .sim_wr_stb     (afi_sim_wr_stb), // output[7:0] 
        .sim_bresp_latency(afi_sim_bresp_latency), // input[3:0] 
        .sim_wr_cap     (afi_sim_wr_cap), // output[2:0] 
        .sim_wr_qos     (afi_sim_wr_qos), // output[3:0] 
        .reg_addr       (PS_REG_ADDR), // input[31:0] 
        .reg_wr         (PS_REG_WR), // input
        .reg_rd         (PS_REG_RD), // input
        .reg_din        (PS_REG_DIN), // input[31:0] 
        .reg_dout       (PS_REG_DOUT) // output[31:0] 
    );



    
    //  wire [ 3:0] SIMUL_ADD_ADDR; 
    always @ (posedge CLK) begin
        if      (RST) SIMUL_AXI_FULL <=0;
        else if (rstb) SIMUL_AXI_FULL <=1;
        
        if (RST) begin
              NUM_WORDS_READ <= 0;
        end else if (rstb) begin
            NUM_WORDS_READ <= NUM_WORDS_READ + 1; 
        end    
        if (rstb) begin
            SIMUL_AXI_ADDR <= SIMUL_AXI_ADDR_W;
            SIMUL_AXI_READ <= rdata;
`ifdef DEBUG_RD_DATA
        $display (" Read data (addr:data): 0x%x:0x%x @%t",SIMUL_AXI_ADDR_W,rdata,$time);
`endif  
            
        end 
        
    end
    
    
// SuppressWarnings VEditor all - these variables are just for viewing, not used anywhere else
  reg DEBUG1, DEBUG2, DEBUG3;
  reg [11:0] GLOBAL_WRITE_ID=0;
  reg [11:0] GLOBAL_READ_ID=0;
  reg [7:0] target_phase=0; // to compare/wait for phase shifter ready
  
   task set_up;
        begin
// set dq /dqs tristate on/off patterns
            axi_set_tristate_patterns;
// set patterns for DM (always 0) and DQS - always the same (may try different for write lev.)
            axi_set_dqs_dqm_patterns;
// prepare all sequences
            set_all_sequences (1,0); // rsel = 1, wsel=0
// prepare write buffer    
            write_block_buf_chn(0,0,256); // fill block memory (channel, page, number)
// set all delays
//#axi_set_delays - from tables, per-pin
`ifdef SET_PER_PIN_DELAYS
            $display("SET_PER_PIN_DELAYS @ %t",$time);
            axi_set_delays; // set all individual delays, aslo runs axi_set_phase()
`else
            $display("SET COMMON DELAYS @ %t",$time);
            axi_set_same_delays(DLY_DQ_IDELAY,DLY_DQ_ODELAY,DLY_DQS_IDELAY,DLY_DQS_ODELAY,DLY_DM_ODELAY,DLY_CMDA_ODELAY);
// set clock phase relative to DDR clk
            axi_set_phase(DLY_PHASE);
`endif            
            
        end
    endtask

// tasks - when tested - move to includes

task test_write_levelling; // SuppressThisWarning VEditor - may be unused
  begin
// Set special values for DQS idelay for write leveling
        wait_ps_pio_done(DEFAULT_STATUS_MODE,1); // not no interrupt running cycle - delays are changed immediately
        axi_set_dqs_idelay_wlv;
// Set write buffer (from DDR3) WE signal delay for write leveling mode
        axi_set_wbuf_delay(WBUF_DLY_WLV);
        axi_set_dqs_odelay('h80); // 'h80 - inverted, 'h60 - not - 'h80 will cause warnings during simulation
        schedule_ps_pio ( // schedule software-control memory operation (may need to check FIFO status first)
                        WRITELEV_OFFSET,   // input [9:0] seq_addr; // sequence start address
                        0,                 // input [1:0] page;     // buffer page number
                        0,                 // input       urgent;   // high priority request (only for competion with other channels, wiil not pass in this FIFO)
                        0,                // input       chn;      // channel buffer to use: 0 - memory read, 1 - memory write
                        `PS_PIO_WAIT_COMPLETE );//  wait_complete; // Do not request a newe transaction from the scheduler until previous memory transaction is finished
                        
        wait_ps_pio_done(DEFAULT_STATUS_MODE,1); // wait previous memory transaction finished before changing delays (effective immediately)
        read_block_buf_chn (0, 0, 32, 1 ); // chn=0, page=0, number of 32-bit words=32, wait_done
//        @ (negedge rstb);
        axi_set_dqs_odelay(DLY_DQS_ODELAY);
        schedule_ps_pio ( // schedule software-control memory operation (may need to check FIFO status first)
                        WRITELEV_OFFSET,   // input [9:0] seq_addr; // sequence start address
                        1,                 // input [1:0] page;     // buffer page number
                        0,                 // input       urgent;   // high priority request (only for competion with other channels, wiil not pass in this FIFO)
                        0,                // input       chn;      // channel buffer to use: 0 - memory read, 1 - memory write
                        `PS_PIO_WAIT_COMPLETE );//  wait_complete; // Do not request a newe transaction from the scheduler until previous memory transaction is finished
        wait_ps_pio_done(DEFAULT_STATUS_MODE,1); // wait previous memory transaction finished before changing delays (effective immediately)
        read_block_buf_chn (0, 1, 32, 1 ); // chn=0, page=1, number of 32-bit words=32, wait_done
//    task wait_read_queue_empty; - alternative way to check fo empty read queue
        
//        @ (negedge rstb);
        axi_set_dqs_idelay_nominal;
        axi_set_dqs_odelay_nominal;
//        axi_set_dqs_odelay('h78);
        axi_set_wbuf_delay(WBUF_DLY_DFLT); //DFLT_WBUF_DELAY
   end
endtask

task test_read_pattern; // SuppressThisWarning VEditor - may be unused
    begin  
        schedule_ps_pio ( // schedule software-control memory operation (may need to check FIFO status first)
                        READ_PATTERN_OFFSET,   // input [9:0] seq_addr; // sequence start address
                        2,                     // input [1:0] page;     // buffer page number
                        0,                     // input       urgent;   // high priority request (only for competion with other channels, wiil not pass in this FIFO)
                        0,                    // input       chn;      // channel buffer to use: 0 - memory read, 1 - memory write
                        `PS_PIO_WAIT_COMPLETE );//  wait_complete; // Do not request a newe transaction from the scheduler until previous memory transaction is finished
        wait_ps_pio_done(DEFAULT_STATUS_MODE,1); // wait previous memory transaction finished before changing delays (effective immediately)
        read_block_buf_chn (0, 2, 32, 1 ); // chn=0, page=2, number of 32-bit words=32, wait_done
    end
endtask

task test_write_block; // SuppressThisWarning VEditor - may be unused
    begin
//    write_block_buf_chn; // fill block memory - already set in set_up task
        schedule_ps_pio ( // schedule software-control memory operation (may need to check FIFO status first)
                        WRITE_BLOCK_OFFSET,    // input [9:0] seq_addr; // sequence start address
                        0,                     // input [1:0] page;     // buffer page number
                        0,                     // input       urgent;   // high priority request (only for competion with other channels, wiil not pass in this FIFO)
                        1,                    // input       chn;      // channel buffer to use: 0 - memory read, 1 - memory write
                        `PS_PIO_WAIT_COMPLETE );//  wait_complete; // Do not request a newe transaction from the scheduler until previous memory transaction is finished
// tempoary - for debugging:
//        wait_ps_pio_done(DEFAULT_STATUS_MODE,1); // wait previous memory transaction finished before changing delays (effective immediately)
    end
endtask

task test_read_block; // SuppressThisWarning VEditor - may be unused
    begin
        schedule_ps_pio ( // schedule software-control memory operation (may need to check FIFO status first)
                        READ_BLOCK_OFFSET,   // input [9:0] seq_addr; // sequence start address
                        3,                     // input [1:0] page;     // buffer page number
                        0,                     // input       urgent;   // high priority request (only for competion with other channels, wiil not pass in this FIFO)
                        0,                    // input       chn;      // channel buffer to use: 0 - memory read, 1 - memory write
                        `PS_PIO_WAIT_COMPLETE );//  wait_complete; // Do not request a newe transaction from the scheduler until previous memory transaction is finished
        schedule_ps_pio ( // schedule software-control memory operation (may need to check FIFO status first)
                        READ_BLOCK_OFFSET,   // input [9:0] seq_addr; // sequence start address
                        2,                     // input [1:0] page;     // buffer page number
                        0,                     // input       urgent;   // high priority request (only for competion with other channels, wiil not pass in this FIFO)
                        0,                    // input       chn;      // channel buffer to use: 0 - memory read, 1 - memory write
                        `PS_PIO_WAIT_COMPLETE );//  wait_complete; // Do not request a newe transaction from the scheduler until previous memory transaction is finished
        schedule_ps_pio ( // schedule software-control memory operation (may need to check FIFO status first)
                        READ_BLOCK_OFFSET,   // input [9:0] seq_addr; // sequence start address
                        1,                     // input [1:0] page;     // buffer page number
                        0,                     // input       urgent;   // high priority request (only for competion with other channels, wiil not pass in this FIFO)
                        0,                    // input       chn;      // channel buffer to use: 0 - memory read, 1 - memory write
                        `PS_PIO_WAIT_COMPLETE );//  wait_complete; // Do not request a newe transaction from the scheduler until previous memory transaction is finished
        wait_ps_pio_done(DEFAULT_STATUS_MODE,1); // wait previous memory transaction finished before changing delays (effective immediately)
        read_block_buf_chn (0, 3, 256, 1 ); // chn=0, page=3, number of 32-bit words=256, wait_done
    end
endtask


// above - move to include

task test_afi_rw; // SuppressThisWarning VEditor - may be unused
    input        write_ddr3;
    input  [1:0] extra_pages;
    input [21:0] frame_start_addr;
    input [15:0] window_full_width; // 13 bit - in 8*16=128 bit bursts
    input [15:0] window_width;  // 13 bit - in 8*16=128 bit bursts
    input [15:0] window_height; // 16 bit (only 14 are used here)
    input [15:0] window_left;
    input [15:0] window_top;
    input [28:0] start64;  // relative start address of the transfer (set to 0 when writing lo_addr64)
    input [28:0] lo_addr64; // low address of the system memory range, in 64-bit words 
    input [28:0] size64;    // size of the system memory range in 64-bit words
    input        continue;    // 0 start from start64, 1 - continue from where it was
    
// -----------------------------------------
    integer mode;
`ifdef MEMBRIDGE_DEBUG_READ    
    integer       ii;
`endif    
    begin
        $display("====== test_afi_rw: write=%d, extra_pages=%d,  frame_start= %x, window_full_width=%d, window_width=%d, window_height=%d, window_left=%d, window_top=%d,@%t",
                                      write_ddr3,  extra_pages, frame_start_addr, window_full_width,   window_width, window_height, window_left, window_top, $time);
        $display("len64=%x,  width64=%x, start64=%x, lo_addr64=%x, size64=%x,@%t",
                  ((window_width[12:0]==0)? 15'h4000 : {1'b0,window_width[12:0],1'b0})*window_height[13:0],
                  (window_width[12:0]==0)? 29'h4000 : {15'b0,window_width[12:0],1'b0},
                  start64, lo_addr64, size64, $time);
        mode=   func_encode_mode_scanline(
                    extra_pages,
                    write_ddr3, // write_mem,
                    1, // enable
                    0);  // chn_reset
        write_contol_register(MCNTRL_SCANLINE_CHN1_ADDR + MCNTRL_SCANLINE_STARTADDR,        {10'b0,frame_start_addr}); // RA=80, CA=0, BA=0 22-bit frame start address (3 CA LSBs==0. BA==0) 
        write_contol_register(MCNTRL_SCANLINE_CHN1_ADDR + MCNTRL_SCANLINE_FRAME_FULL_WIDTH, {16'h0, window_full_width});
        write_contol_register(MCNTRL_SCANLINE_CHN1_ADDR + MCNTRL_SCANLINE_WINDOW_WH,        {window_height,window_width}); //WINDOW_WIDTH + (WINDOW_HEIGHT<<16));
        write_contol_register(MCNTRL_SCANLINE_CHN1_ADDR + MCNTRL_SCANLINE_WINDOW_X0Y0,      {window_top,window_left}); //WINDOW_X0+ (WINDOW_Y0<<16));
        write_contol_register(MCNTRL_SCANLINE_CHN1_ADDR + MCNTRL_SCANLINE_WINDOW_STARTXY,   0);
        write_contol_register(MCNTRL_SCANLINE_CHN1_ADDR + MCNTRL_SCANLINE_MODE,             mode); 
        configure_channel_priority(1,0);    // lowest priority channel 3
        enable_memcntrl_en_dis(1,1);
//        write_contol_register(test_mode_address,            TEST01_START_FRAME);
        afi_setup(0);
        membridge_setup(
            ((window_width[12:0]==0)? 15'h4000 : {1'b0,window_width[12:0],1'b0})*window_height[13:0], //len64,
            (window_width[12:0]==0)? 29'h4000 : {15'b0,window_width[12:0],1'b0}, // width64,
            start64,
            lo_addr64,
            size64);
        membridge_start (continue);
`ifdef MEMBRIDGE_DEBUG_READ    
        // debugging
        for (ii=0; ii < 10; ii=ii +1) begin
            #200; //#50;
            write_contol_register(MEMBRIDGE_ADDR + MEMBRIDGE_CTRL,         {27'b0,continue,4'b1101});  // enable both address and data
        end
        #500;
        write_contol_register(MEMBRIDGE_ADDR + MEMBRIDGE_CTRL,         {26'b0,continue,5'b10001});  // disable debug (enable remaining xfers)
`endif        
// just wait done
        wait_status_condition ( // may also be read directly from the same bit of mctrl_linear_rw (address=5) status
            MEMBRIDGE_STATUS_REG, // MCNTRL_TEST01_STATUS_REG_CHN3_ADDR,
            MEMBRIDGE_ADDR + MEMBRIDGE_STATUS_CNTRL, // MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN3_STATUS_CNTRL,
            DEFAULT_STATUS_MODE,
            2 << STATUS_2LSB_SHFT, // bit 24 - busy, bit 25 - frame done
            2 << STATUS_2LSB_SHFT,  // mask for the 4-bit page number
            0, // equal to
            1); // do synchronize sequence number
    end
endtask

task test_scanline_write; // SuppressThisWarning VEditor - may be unused
    input            [3:0] channel;
    input            [1:0] extra_pages;
    input                  wait_done;
    input [15:0]           window_width;  // 13 bit - in 8*16=128 bit bursts
    input [15:0]           window_height; // 16 bit
    input [15:0]           window_left;
    input [15:0]           window_top;
    
    
    reg             [29:0] start_addr;
    integer                mode;
    reg [STATUS_DEPTH-1:0] status_address;
    reg             [29:0] status_control_address;
    reg             [29:0] test_mode_address;
    
    integer       ii;
    integer xfer_size;
    integer pages_per_row;
    integer startx,starty; // temporary - because of the vdt bug with integer ports
    begin
        pages_per_row= (window_width>>NUM_XFER_BITS)+((window_width[NUM_XFER_BITS-1:0]==0)?0:1);
        $display("====== test_scanline_write: channel=%d, extra_pages=%d,  wait_done=%d @%t",
                                              channel,    extra_pages,     wait_done,   $time);
        case (channel)
//            1:  begin
//                    start_addr=             MCNTRL_SCANLINE_CHN1_ADDR;
//                    status_address=         MCNTRL_TEST01_STATUS_REG_CHN1_ADDR;
//                    status_control_address= MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN1_STATUS_CNTRL;
//                    test_mode_address=      MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN1_MODE;
//                end
            3:  begin
                    start_addr=             MCNTRL_SCANLINE_CHN3_ADDR;
                    status_address=         MCNTRL_TEST01_STATUS_REG_CHN3_ADDR;
                    status_control_address= MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN3_STATUS_CNTRL;
                    test_mode_address=      MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN3_MODE;
                end
            default: begin
                $display("**** ERROR: Invalid channel, only 3 is valid");
                start_addr=             MCNTRL_SCANLINE_CHN3_ADDR;
                status_address=         MCNTRL_TEST01_STATUS_REG_CHN1_ADDR;
                status_control_address= MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN1_STATUS_CNTRL;
                test_mode_address=      MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN1_MODE;
            end
        endcase
        mode=   func_encode_mode_scanline(
                    extra_pages,
                    1, // write_mem,
                    1, // enable
                    0);  // chn_reset
                
        write_contol_register(start_addr + MCNTRL_SCANLINE_STARTADDR,        FRAME_START_ADDRESS); // RA=80, CA=0, BA=0 22-bit frame start address (3 CA LSBs==0. BA==0) 
        write_contol_register(start_addr + MCNTRL_SCANLINE_FRAME_FULL_WIDTH, FRAME_FULL_WIDTH);
        write_contol_register(start_addr + MCNTRL_SCANLINE_WINDOW_WH,        {window_height,window_width}); //WINDOW_WIDTH + (WINDOW_HEIGHT<<16));
        write_contol_register(start_addr + MCNTRL_SCANLINE_WINDOW_X0Y0,      {window_top,window_left}); //WINDOW_X0+ (WINDOW_Y0<<16));
        write_contol_register(start_addr + MCNTRL_SCANLINE_WINDOW_STARTXY,   SCANLINE_STARTX+(SCANLINE_STARTY<<16));
        write_contol_register(start_addr + MCNTRL_SCANLINE_MODE,             mode); 
        configure_channel_priority(channel,0);    // lowest priority channel 3
//        enable_memcntrl_channels(16'h000b); // channels 0,1,3 are enabled
        enable_memcntrl_en_dis(channel,1);
        write_contol_register(test_mode_address,            TEST01_START_FRAME);
        for (ii=0;ii<TEST_INITIAL_BURST;ii=ii+1) begin
// VDT bugs: 1:does not propagate undefined width through ?:, 2: - does not allow to connect it to task integer input, 3: shows integer input width as 1  
            xfer_size= ((pages_per_row>1)?
                (
                    (
                        ((ii % pages_per_row) < (pages_per_row-1))?
                        (1<<NUM_XFER_BITS):
                        (window_width % (1<<NUM_XFER_BITS))
                    )
                ):
                ({16'b0,window_width}));
           $display("########### test_scanline_write block %d: channel=%d, @%t", ii, channel, $time);
           startx=window_left + ((ii % pages_per_row)<<NUM_XFER_BITS);
           starty=window_top + (ii / pages_per_row);
           write_block_scanline_chn(
            channel,
            (ii & 3),
            xfer_size,
            startx, //window_left + ((ii % pages_per_row)<<NUM_XFER_BITS),  // SCANLINE_CUR_X,
            starty); // window_top + (ii / pages_per_row)); // SCANLINE_CUR_Y);\
            
        end
        for (ii=0;ii< (window_height * pages_per_row) ;ii = ii+1) begin // here assuming 1 page per line
            if (ii >= TEST_INITIAL_BURST) begin // wait page ready and fill page after first 4 are filled
                wait_status_condition (
                    status_address, //MCNTRL_TEST01_STATUS_REG_CHN3_ADDR,
                    status_control_address, // MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN3_STATUS_CNTRL,
                    DEFAULT_STATUS_MODE,
                    (ii-TEST_INITIAL_BURST)<<16, // 4-bit page number
                    'hf << 16,  // mask for the 4-bit page number
                    1, // not equal to
                    (ii == TEST_INITIAL_BURST)); // synchronize sequence number - only first time, next just wait fro auto update
                xfer_size= ((pages_per_row>1)?
                    (
                        (
                            ((ii % pages_per_row) < (pages_per_row-1))?
                        
                         (1<<NUM_XFER_BITS):
                            (window_width % (1<<NUM_XFER_BITS))
                        )
                    ):
                    ({16'b0,window_width}));
                $display("########### test_scanline_write block %d: channel=%d, @%t", ii, channel, $time);
                startx=window_left + ((ii % pages_per_row)<<NUM_XFER_BITS);
                starty=window_top + (ii / pages_per_row);
                
                write_block_scanline_chn(
                    channel,
                    (ii & 3),
                xfer_size,
                startx,  // window_left + ((ii % pages_per_row)<<NUM_XFER_BITS),  // SCANLINE_CUR_X,
                starty); // window_top + (ii / pages_per_row)); // SCANLINE_CUR_Y);
            end
            write_contol_register(test_mode_address,            TEST01_NEXT_PAGE);
        end
        if (wait_done) begin
            wait_status_condition ( // may also be read directly from the same bit of mctrl_linear_rw (address=5) status
                status_address, // MCNTRL_TEST01_STATUS_REG_CHN3_ADDR,
                status_control_address, // MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN3_STATUS_CNTRL,
                DEFAULT_STATUS_MODE,
                2 << STATUS_2LSB_SHFT, // bit 24 - busy, bit 25 - frame done
                2 << STATUS_2LSB_SHFT,  // mask for the 4-bit page number
                0, // equal to
                0); // no need to synchronize sequence number
//     enable_memcntrl_en_dis(channel,0); // disable channel
        end
    end
endtask

task test_scanline_read; // SuppressThisWarning VEditor - may be unused
    input            [3:0] channel;
    input            [1:0] extra_pages;
    input                  show_data;
    input [15:0]           window_width;
    input [15:0]           window_height;
    input [15:0]           window_left;
    input [15:0]           window_top;
    
    reg             [29:0] start_addr;
    integer                mode;
    reg [STATUS_DEPTH-1:0] status_address;
    reg             [29:0] status_control_address;
    reg             [29:0] test_mode_address;
    integer       ii;
    integer xfer_size;
    integer pages_per_row;
    
    begin
        pages_per_row= (window_width>>NUM_XFER_BITS)+((window_width[NUM_XFER_BITS-1:0]==0)?0:1);
        $display("====== test_scanline_read: channel=%d, extra_pages=%d,  show_data=%d @%t",
                                             channel,    extra_pages,     show_data,    $time);
        case (channel)
//            1:  begin
//                    start_addr=             MCNTRL_SCANLINE_CHN1_ADDR;
//                    status_address=         MCNTRL_TEST01_STATUS_REG_CHN1_ADDR;
//                    status_control_address= MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN1_STATUS_CNTRL;
//                    test_mode_address=      MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN1_MODE;
//                end
            3:  begin
                    start_addr=             MCNTRL_SCANLINE_CHN3_ADDR;
                    status_address=         MCNTRL_TEST01_STATUS_REG_CHN3_ADDR;
                    status_control_address= MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN3_STATUS_CNTRL;
                    test_mode_address=      MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN3_MODE;
                end
            default: begin
                $display("**** ERROR: Invalid channel, only 3 is valid");
                start_addr=             MCNTRL_SCANLINE_CHN3_ADDR;
                status_address=         MCNTRL_TEST01_STATUS_REG_CHN1_ADDR;
                status_control_address= MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN1_STATUS_CNTRL;
                test_mode_address=      MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN1_MODE;
            end
        endcase
        mode=   func_encode_mode_scanline(
                    extra_pages,
                    0, // write_mem,
                    1, // enable
                    0);  // chn_reset

   // program to the
        write_contol_register(start_addr + MCNTRL_SCANLINE_STARTADDR,        FRAME_START_ADDRESS); // RA=80, CA=0, BA=0 22-bit frame start address (3 CA LSBs==0. BA==0) 
        write_contol_register(start_addr + MCNTRL_SCANLINE_FRAME_FULL_WIDTH, FRAME_FULL_WIDTH);
        write_contol_register(start_addr + MCNTRL_SCANLINE_WINDOW_WH,        {window_height,window_width}); //WINDOW_WIDTH + (WINDOW_HEIGHT<<16));
        write_contol_register(start_addr + MCNTRL_SCANLINE_WINDOW_X0Y0,      {window_top,window_left}); //WINDOW_X0+ (WINDOW_Y0<<16));
        write_contol_register(start_addr + MCNTRL_SCANLINE_WINDOW_STARTXY,   SCANLINE_STARTX+(SCANLINE_STARTY<<16));
        write_contol_register(start_addr + MCNTRL_SCANLINE_MODE,             mode);// set mode register: {extra_pages[1:0],enable,!reset}
        configure_channel_priority(channel,0);    // lowest priority channel 3
        enable_memcntrl_en_dis(channel,1);
        write_contol_register(test_mode_address,            TEST01_START_FRAME);
        for (ii=0;ii<(window_height * pages_per_row);ii = ii+1) begin
            xfer_size= ((pages_per_row>1)?
                (
                    (
                        ((ii % pages_per_row) < (pages_per_row-1))?
                        (1<<NUM_XFER_BITS):
                        (window_width % (1<<NUM_XFER_BITS))
                    )
                ):
                ({16'b0,window_width}));
            wait_status_condition (
                status_address, //MCNTRL_TEST01_STATUS_REG_CHN2_ADDR,
                status_control_address, // MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN2_STATUS_CNTRL,
                DEFAULT_STATUS_MODE,
                (ii) << 16, // -TEST_INITIAL_BURST)<<16, // 4-bit page number
                'hf << 16,  // mask for the 4-bit page number
                 1, // not equal to
                 (ii == 0)); // synchronize sequence number - only first time, next just wait fro auto update
// read block (if needed), for now just sikip  
                if (show_data) begin
                    $display("########### test_scanline_read block %d: channel=%d, @%t", ii, channel, $time);
                    read_block_buf_chn (
                        channel,
                        (ii & 3),
                        xfer_size <<2,
                        1 ); // chn=0, page=3, number of 32-bit words=256, wait_done
                end
        write_contol_register(test_mode_address,            TEST01_NEXT_PAGE);
    end
  end  
endtask

task test_tiled_write; // SuppressThisWarning VEditor - may be unused
    input            [3:0] channel;
    input                  byte32;
    input                  keep_open;
    input            [1:0] extra_pages;
    input                  wait_done;
    input [15:0]           window_width;
    input [15:0]           window_height;
    input [15:0]           window_left;
    input [15:0]           window_top;
    input [ 7:0]           tile_width;
    input [ 7:0]           tile_height;
    input [ 7:0]           tile_vstep;
    
    
    
    reg             [29:0] start_addr;
    integer                mode;
    reg [STATUS_DEPTH-1:0] status_address;
    reg             [29:0] status_control_address;
    reg             [29:0] test_mode_address;
    integer       ii;
    integer       tiles_per_row;
    integer       tile_rows_per_window;
    integer       tile_size;
    integer startx,starty; // temporary - because of the vdt bug with integer ports
    begin
        tiles_per_row= (window_width/tile_width)+  ((window_width % tile_width==0)?0:1);
        tile_rows_per_window= ((window_height-1)/tile_vstep) + 1;
        tile_size= tile_width*tile_height;
        $display("====== test_tiled_write: channel=%d, byte32=%d, keep_open=%d, extra_pages=%d,  wait_done=%d @%t",
                                           channel,    byte32,    keep_open,    extra_pages,     wait_done,   $time);
        case (channel)
            2:  begin
                    start_addr=             MCNTRL_TILED_CHN2_ADDR;
                    status_address=         MCNTRL_TEST01_STATUS_REG_CHN2_ADDR;
                    status_control_address= MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN2_STATUS_CNTRL;
                    test_mode_address=      MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN2_MODE;
                end
            4:  begin
                    start_addr=             MCNTRL_TILED_CHN4_ADDR;
                    status_address=         MCNTRL_TEST01_STATUS_REG_CHN4_ADDR;
                    status_control_address= MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN4_STATUS_CNTRL;
                    test_mode_address=      MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN4_MODE;
                end
            default: begin
                $display("**** ERROR: Invalid channel, only 2 and 4 are valid");
                start_addr=             MCNTRL_TILED_CHN2_ADDR;
                status_address=         MCNTRL_TEST01_STATUS_REG_CHN2_ADDR;
                status_control_address= MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN2_STATUS_CNTRL;
                test_mode_address=      MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN2_MODE;
            end
        endcase
        mode=   func_encode_mode_tiled(
                    byte32,
                    keep_open,
                    extra_pages,
                    1, // write_mem,
                    1, // enable
                    0);  // chn_reset
        write_contol_register(start_addr + MCNTRL_TILED_STARTADDR,        FRAME_START_ADDRESS); // RA=80, CA=0, BA=0 22-bit frame start address (3 CA LSBs==0. BA==0) 
        write_contol_register(start_addr + MCNTRL_TILED_FRAME_FULL_WIDTH, FRAME_FULL_WIDTH);
        write_contol_register(start_addr + MCNTRL_TILED_WINDOW_WH,        {window_height,window_width}); //WINDOW_WIDTH + (WINDOW_HEIGHT<<16));
        write_contol_register(start_addr + MCNTRL_TILED_WINDOW_X0Y0,      {window_top,window_left}); //WINDOW_X0+ (WINDOW_Y0<<16));
        
        write_contol_register(start_addr + MCNTRL_TILED_WINDOW_STARTXY,   TILED_STARTX+(TILED_STARTY<<16));
        write_contol_register(start_addr + MCNTRL_TILED_TILE_WHS,         {8'b0,tile_vstep,tile_height,tile_width});//tile_width+(tile_height<<8)+(tile_vstep<<16));
        write_contol_register(start_addr + MCNTRL_TILED_MODE,             mode);// set mode register: {extra_pages[1:0],enable,!reset}
        configure_channel_priority(channel,0);    // lowest priority channel 3
        enable_memcntrl_en_dis(channel,1);
        write_contol_register(test_mode_address,            TEST01_START_FRAME);
    
        for (ii=0;ii<TEST_INITIAL_BURST;ii=ii+1) begin
            $display("########### test_tiled_write block %d: channel=%d, @%t", ii, channel, $time);
            startx = window_left + ((ii % tiles_per_row) * tile_width);
            starty = window_top + (ii / tile_rows_per_window); // SCANLINE_CUR_Y);\
            write_block_scanline_chn( // TODO: Make a different tile buffer data, matching the order
                channel, // channel
                (ii & 3),
                tile_size,
                startx, //window_left + ((ii % tiles_per_row) * tile_width),
                starty); //window_top + (ii / tile_rows_per_window)); // SCANLINE_CUR_Y);\
        end
    
        for (ii=0;ii<(tiles_per_row * tile_rows_per_window);ii = ii+1) begin
            if (ii >= TEST_INITIAL_BURST) begin // wait page ready and fill page after first 4 are filled
                wait_status_condition (
                    status_address, // MCNTRL_TEST01_STATUS_REG_CHN5_ADDR,
                    status_control_address, // MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN5_STATUS_CNTRL,
                    DEFAULT_STATUS_MODE,
                    (ii-TEST_INITIAL_BURST)<<16, // 4-bit page number
                    'hf << 16,  // mask for the 4-bit page number
                    1, // not equal to
                    (ii == TEST_INITIAL_BURST)); // synchronize sequence number - only first time, next just wait fro auto update
                $display("########### test_tiled_write block %d: channel=%d, @%t", ii, channel, $time);
                startx = window_left + ((ii % tiles_per_row) * tile_width);
                starty = window_top + (ii / tile_rows_per_window);
                write_block_scanline_chn( // TODO: Make a different tile buffer data, matching the order
                    channel, // channel
                    (ii & 3),
                    tile_size,
                    startx, // window_left + ((ii % tiles_per_row) * tile_width),
                    starty); // window_top + (ii / tile_rows_per_window)); // SCANLINE_CUR_Y);\
            end
            write_contol_register(test_mode_address,            TEST01_NEXT_PAGE);
        end
        if (wait_done) begin
            wait_status_condition ( // may also be read directly from the same bit of mctrl_linear_rw (address=5) status
                status_address, // MCNTRL_TEST01_STATUS_REG_CHN3_ADDR,
                status_control_address, // MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN3_STATUS_CNTRL,
                DEFAULT_STATUS_MODE,
                2 << STATUS_2LSB_SHFT, // bit 24 - busy, bit 25 - frame done
                2 << STATUS_2LSB_SHFT,  // mask for the 4-bit page number
                0, // equal to
                0); // no need to synchronize sequence number
//     enable_memcntrl_en_dis(channel,0); // disable channel
        end
    end  
endtask



task test_tiled_read; // SuppressThisWarning VEditor - may be unused
    input            [3:0] channel;
    input                  byte32;
    input                  keep_open;
    input            [1:0] extra_pages;
    input                  show_data;
    input [15:0]           window_width;
    input [15:0]           window_height;
    input [15:0]           window_left;
    input [15:0]           window_top;
    input [ 7:0]           tile_width;
    input [ 7:0]           tile_height;
    input [ 7:0]           tile_vstep;
    
    reg             [29:0] start_addr;
    integer                mode;
    reg [STATUS_DEPTH-1:0] status_address;
    reg             [29:0] status_control_address;
    reg             [29:0] test_mode_address;
    
    integer       ii;
    integer       tiles_per_row;
    integer       tile_rows_per_window;
    integer       tile_size;
    
    begin
        tiles_per_row= (window_width/tile_width)+  ((window_width % tile_width==0)?0:1);
        tile_rows_per_window= ((window_height-1)/tile_vstep) + 1;
        tile_size= tile_width*tile_height;
        $display("====== test_tiled_read: channel=%d, byte32=%d, keep_open=%d, extra_pages=%d,  show_data=%d @%t",
                                          channel,      byte32,  keep_open,    extra_pages,     show_data,   $time);
        case (channel)
            2:  begin
                    start_addr=             MCNTRL_TILED_CHN2_ADDR;
                    status_address=         MCNTRL_TEST01_STATUS_REG_CHN2_ADDR;
                    status_control_address= MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN2_STATUS_CNTRL;
                    test_mode_address=      MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN2_MODE;
                end
            4:  begin
                    start_addr=             MCNTRL_TILED_CHN4_ADDR;
                    status_address=         MCNTRL_TEST01_STATUS_REG_CHN4_ADDR;
                    status_control_address= MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN4_STATUS_CNTRL;
                    test_mode_address=      MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN4_MODE;
                end
            default: begin
                $display("**** ERROR: Invalid channel, only 2 and 4 are valid");
                start_addr=             MCNTRL_TILED_CHN2_ADDR;
                status_address=         MCNTRL_TEST01_STATUS_REG_CHN2_ADDR;
                status_control_address= MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN2_STATUS_CNTRL;
                test_mode_address=      MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN2_MODE;
            end
        endcase
        mode=   func_encode_mode_tiled(
                    byte32,
                    keep_open,
                    extra_pages,
                    0, // write_mem,
                    1, // enable
                    0);  // chn_reset
        write_contol_register(start_addr + MCNTRL_TILED_STARTADDR,        FRAME_START_ADDRESS); // RA=80, CA=0, BA=0 22-bit frame start address (3 CA LSBs==0. BA==0) 
        write_contol_register(start_addr + MCNTRL_TILED_FRAME_FULL_WIDTH, FRAME_FULL_WIDTH);
        write_contol_register(start_addr + MCNTRL_TILED_WINDOW_WH,        {window_height,window_width}); //WINDOW_WIDTH + (WINDOW_HEIGHT<<16));
        write_contol_register(start_addr + MCNTRL_TILED_WINDOW_X0Y0,      {window_top,window_left}); //WINDOW_X0+ (WINDOW_Y0<<16));
        
        write_contol_register(start_addr + MCNTRL_TILED_WINDOW_STARTXY,   TILED_STARTX+(TILED_STARTY<<16));
        write_contol_register(start_addr + MCNTRL_TILED_TILE_WHS,         {8'b0,tile_vstep,tile_height,tile_width});//(tile_height<<8)+(tile_vstep<<16));
        write_contol_register(start_addr + MCNTRL_TILED_MODE,             mode);// set mode register: {extra_pages[1:0],enable,!reset}
        configure_channel_priority(channel,0);    // lowest priority channel 3
        enable_memcntrl_en_dis(channel,1);
        write_contol_register(test_mode_address,            TEST01_START_FRAME);
        for (ii=0;ii<(tiles_per_row * tile_rows_per_window);ii = ii+1) begin
            wait_status_condition (
                status_address, // MCNTRL_TEST01_STATUS_REG_CHN4_ADDR,
                status_control_address, // MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN4_STATUS_CNTRL,
                DEFAULT_STATUS_MODE,
                ii << 16, // -TEST_INITIAL_BURST)<<16, // 4-bit page number
                'hf << 16,  // mask for the 4-bit page number
                1, // not equal to
                (ii == 0)); // synchronize sequence number - only first time, next just wait fro auto update
                if (show_data) begin 
                    $display("########### test_tiled_read block %d: channel=%d, @%t", ii, channel, $time);
                    read_block_buf_chn (
                        channel,
                        (ii & 3),
                        tile_size <<2,
                        1 ); // chn=0, page=3, number of 32-bit words=256, wait_done
                end
            write_contol_register(test_mode_address,            TEST01_NEXT_PAGE);
        end
//     enable_memcntrl_en_dis(channel,0); // disable channel
    end  
endtask







task set_all_sequences;
    input rsel;
    input wsel;
        begin
            $display("SET MRS @ %t",$time);    
            set_mrs(1);
            $display("SET REFRESH @ %t",$time);    
            set_refresh(
                T_RFC, // input [ 9:0] t_rfc; // =50 for tCK=2.5ns
                T_REFI); //input [ 7:0] t_refi; // 48/97 for normal, 8 - for simulation
            $display("SET WRITE LEVELING @ %t",$time);    
            set_write_lev(16); // write leveling, 16 times   (full buffer - 128) 
            $display("SET READ PATTERN @ %t",$time);    
            set_read_pattern(8); // 8x2*64 bits, 32x32 bits to read
            $display("SET WRITE BLOCK @ %t",$time);    
            set_write_block(
                3'h5,     // bank
                15'h1234, // row address
                10'h100,   // column address
                wsel
            );
           
            $display("SET READ BLOCK @ %t",$time);    
            set_read_block(
                3'h5,     // bank
                15'h1234, // row address
                10'h100,   // column address
                rsel      // sel
            );
        end
endtask

task write_block_scanline_chn;  // S uppressThisWarning VEditor : may be unused
//    input integer chn; // buffer channel
    input   [3:0] chn; // buffer channel
    input   [1:0] page;
//    input integer num_words; // number of words to write (will be rounded up to multiple of 16)
    input [NUM_XFER_BITS:0] num_bursts; // number of 8-bursts to write (will be rounded up to multiple of 16)
    input integer startX;
    input integer startY;
    reg    [29:0] start_addr;
    integer num_words;
    begin
//        $display("====== write_block_scanline_chn:%d page: %x X=0x%x Y=0x%x num=%d @%t", chn, page, startX, startY,num_words, $time);
        $display("====== write_block_scanline_chn:%d page: %x X=0x%x Y=0x%x num=%d @%t", chn, page, startX, startY,num_bursts, $time);
        case (chn)
            0:  start_addr=MCONTR_BUF0_WR_ADDR + (page << 8);
//            1:  start_addr=MCONTR_BUF1_WR_ADDR + (page << 8);
            2:  start_addr=MCONTR_BUF2_WR_ADDR + (page << 8);
            3:  start_addr=MCONTR_BUF3_WR_ADDR + (page << 8);
            4:  start_addr=MCONTR_BUF4_WR_ADDR + (page << 8);
            default: begin
                $display("**** ERROR: Invalid channel (not 0,2,3,4) for write_block_scanline_chn = %d @%t", chn, $time);
                start_addr = MCONTR_BUF0_WR_ADDR+ (page << 8);
            end
        endcase
        num_words=num_bursts << 2;
        write_block_incremtal (start_addr, num_words, (startX<<2) + (startY<<16)); // 1 of startX is 8x16 bit, 16 bytes or 4 32-bit words
//        write_block_incremtal (start_addr, num_bursts << 2, (startX<<2) + (startY<<16)); // 1 of startX is 8x16 bit, 16 bytes or 4 32-bit words
    end
endtask

function [6:0] func_encode_mode_tiled;
    input       byte32; // 32-byte columns (0 - 16-byte columns)
    input       keep_open; // for 8 or less rows - do not close page between accesses
    input [1:0] extra_pages; // number of extra pages that need to stay (not to be overwritten) in the buffer
                             // can be used for overlapping tile read access
    input       write_mem;   // write to memory mode (0 - read from memory)
    input       enable;      // enable requests from this channel ( 0 will let current to finish, but not raise want/need)
    input       chn_reset;       // immediately reset al;l the internal circuitry
    begin
        func_encode_mode_tiled={byte32,keep_open,extra_pages,write_mem,enable,~chn_reset};
    end           
endfunction
function [4:0] func_encode_mode_scanline;
    input [1:0] extra_pages; // number of extra pages that need to stay (not to be overwritten) in the buffer
                             // can be used for overlapping tile read access
    input       write_mem;   // write to memory mode (0 - read from memory)
    input       enable;      // enable requests from this channel ( 0 will let current to finish, but not raise want/need)
    input       chn_reset;       // immediately reset al;l the internal circuitry
    begin
        func_encode_mode_scanline={extra_pages,write_mem,enable,~chn_reset};
    end           
endfunction
/*
task enable_memcntrl_en_dis;
    input [3:0] chn;
    input       en;
    begin
        if (en) begin
            ENABLED_CHANNELS = ENABLED_CHANNELS | (1<<chn);
        end else begin
            ENABLED_CHANNELS = ENABLED_CHANNELS & ~(1<<chn);
        end
        write_contol_register(MCONTR_TOP_16BIT_ADDR +  MCONTR_TOP_16BIT_CHN_EN, {16'b0,ENABLED_CHANNELS});
    end
endtask
*/
`include "includes/x393_tasks_afi.vh" // SuppressThisWarning VEditor - may be unused
`include "includes/x393_tasks_mcntrl_en_dis_priority.vh"
`include "includes/x393_tasks_mcntrl_buffers.vh"
`include "includes/x393_tasks_pio_sequences.vh"
`include "includes/x393_tasks_mcntrl_timing.vh" // SuppressThisWarning VEditor - not used
`include "includes/x393_tasks_ps_pio.vh"
`include "includes/x393_tasks_status.vh"
`include "includes/x393_tasks01.vh"
`include "includes/x393_mcontr_encode_cmd.vh"
endmodule

