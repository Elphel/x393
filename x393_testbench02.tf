/*******************************************************************************
 * Module: x393_testbench02
 * Date:2015-02-06  
 * Author: Andrey Filippov     
 * Description: testbench for the initial x393.v simulation
 *
 * Copyright (c) 2015 Elphel, Inc.
 * x393_testbench02.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  x393_testbench02.tf is distributed in the hope that it will be useful,
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

//`define TEST_AFI_WRITE 1
//`define TEST_AFI_READ 1

`define TEST_SENSOR 0


module  x393_testbench02 #(
`include "includes/x393_parameters.vh" // SuppressThisWarning VEditor - not used
`include "includes/x393_simulation_parameters.vh"
)(
);
`ifdef IVERILOG              
//    $display("IVERILOG is defined");
    `ifdef NON_VDT_ENVIROMENT
        parameter fstname="x393.fst";
    `else
        `include "IVERILOG_INCLUDE.v"
    `endif // NON_VDT_ENVIROMENT
`else // IVERILOG
//    $display("IVERILOG is not defined");
    `ifdef CVC
        `ifdef NON_VDT_ENVIROMENT
            parameter fstname = "x393.fst";
        `else // NON_VDT_ENVIROMENT
            `include "IVERILOG_INCLUDE.v"
        `endif // NON_VDT_ENVIROMENT
    `else
        parameter fstname = "x393.fst";
    `endif // CVC
`endif // IVERILOG
`define DEBUG_WR_SINGLE 1  
`define DEBUG_RD_DATA 1  

//`include "includes/x393_cur_params_sim.vh" // parameters that may need adjustment, should be before x393_localparams.vh
`include "includes/x393_cur_params_target.vh" // SuppressThisWarning VEditor - not used parameters that may need adjustment, should be before x393_localparams.vh
parameter TRIGGER_MODE =          1;     // 0 - auto, 1 - triggered
parameter EXT_TRIGGER_MODE =      1 ;    // 0 - internal, 1 - external trigger (camsync)
parameter EXTERNAL_TIMESTAMP =    1 ;    // embed local timestamp, 1 - embed received timestamp

`include "includes/x393_localparams.vh" // SuppressThisWarning VEditor - not used
// VDT - incorrect  real number calculation
//  localparam       FRAME_COMPRESS_CYCLES_INPUT=(FRAME_COMPRESS_CYCLES * CLK0_PER) /CLK1_PER;  
//  localparam  real FRAME_COMPRESS_CYCLES_INPUT=(CLK0_PER * CLK0_PER);  
// ========================== parameters from x353 ===================================

`ifdef SYNC_COMPRESS
    parameter DEPEND=1'b1;
`else  
    parameter DEPEND=1'b0;
`endif

`ifdef TEST_ABORT
`endif
 
  parameter SYNC_BIT_LENGTH=8-1; /// 7 pixel clock pulses
  parameter FPGA_XTRA_CYCLES= 1500; // 1072+;
// moved to x393_simulation_parameters.vh
//  parameter HISTOGRAM_LEFT=  0; //2;   // left   
//  parameter HISTOGRAM_TOP =  2;   // top
//  parameter HISTOGRAM_WIDTH= 6;  // width
//  parameter HISTOGRAM_HEIGHT=6;  // height
  
  parameter CLK0_PER = 6.25;   //160MHz
  parameter CLK1_PER = 10.4;     //96MHz
  parameter CLK3_PER = 83.33;   //12MHz
  parameter CPU_PER=10.4;
  
 parameter HBLANK=            12; /// 52;
 parameter WOI_HEIGHT=        32;
 parameter BLANK_ROWS_BEFORE= 1; //8; ///2+2 - a little faster than compressor
 parameter BLANK_ROWS_AFTER=  1; //8;
 parameter TRIG_LINES=        8;
 parameter VBLANK=            2; /// 2 lines //SuppressThisWarning Veditor UNUSED
 parameter CYCLES_PER_PIXEL=  3; /// 2 for JP4, 3 for JPEG

`ifdef PF
  parameter PF_HEIGHT=8;
  parameter FULL_HEIGHT=WOI_HEIGHT;
  parameter PF_STRIPES=WOI_HEIGHT/PF_HEIGHT;
`else  
  parameter PF_HEIGHT=0;
  parameter FULL_HEIGHT=WOI_HEIGHT+4;
  parameter PF_STRIPES=0;
`endif

 parameter VIRTUAL_WIDTH=    FULL_WIDTH + HBLANK;
 parameter VIRTUAL_HEIGHT=   FULL_HEIGHT + BLANK_ROWS_BEFORE + BLANK_ROWS_AFTER;  //SuppressThisWarning Veditor UNUSED
 
 parameter TRIG_INTERFRAME=  100; /// extra 100 clock cycles between frames  //SuppressThisWarning Veditor UNUSED

/// parameter TRIG_OUT_DATA=        'h80000; // internal cable
/// parameter TRIG_EXTERNAL_INPUT=  'h20000; // internal cable, low level on EXT[8]

 parameter TRIG_DELAY=      200; /// delay in sensor clock cycles


 parameter FULL_WIDTH=        WOI_WIDTH+4;

  localparam       SENSOR_MEMORY_WIDTH_BURSTS = (FULL_WIDTH + 15) >> 4;
  localparam       SENSOR_MEMORY_MASK = (1 << (FRAME_WIDTH_ROUND_BITS-4)) -1;
  localparam       SENSOR_MEMORY_FULL_WIDTH_BURSTS = (SENSOR_MEMORY_WIDTH_BURSTS + SENSOR_MEMORY_MASK) & (~SENSOR_MEMORY_MASK); 

//  localparam       FRAME_COMPRESS_CYCLES = (WOI_WIDTH &'h3fff0) * (WOI_HEIGHT &'h3fff0) * CYCLES_PER_PIXEL + FPGA_XTRA_CYCLES;
// in pixel clocks (camsync now has different clock - 100MHz instead of the 96MHz
//  localparam       TRIG_PERIOD =   VIRTUAL_WIDTH * (VIRTUAL_HEIGHT + TRIG_LINES + VBLANK); /// maximal sensor can do
  localparam       TRIG_PERIOD =   5000 ;

// ========================== end of parameters from x353 ===================================



// Sensor signals - as on sensor pads
    wire        PX1_MCLK; // input sensor input clock
    wire        PX1_MRST; // input 
    wire        PX1_ARO;  // input 
    wire        PX1_ARST; // input 
    wire        PX1_OFST = 1'b1; // input // I2C address ofset by 2: for simulation 0 - still mode, 1 - video mode.
    wire [11:0] PX1_D;    // output[11:0] 
    wire        PX1_DCLK; // output sensor output clock (connect to sensor BPF output )
    wire        PX1_HACT; // output 
    wire        PX1_VACT; // output 

// Sensor signals - as on FPGA pads
    wire [ 7:0] sns1_dp;   // inout[7:0] {PX_MRST, PXD8, PXD6, PXD4, PXD2, PXD0, PX_HACT, PX_DCLK}
    wire [ 7:0] sns1_dn;   // inout[7:0] {PX_ARST, PXD9, PXD7, PXD5, PXD3, PXD1, PX_VACT, PX_BPF}
    wire        sns1_clkp; // inout CNVCLK/TDO
    wire        sns1_clkn; // inout CNVSYNC/TDI
    wire        sns1_scl;  // inout PX_SCL
    wire        sns1_sda;  // inout PX_SDA
    wire        sns1_ctl;  // inout PX_ARO/TCK
    wire        sns1_pg;   // inout SENSPGM

//connect sensor to sensor port 1
assign sns1_dp[6:1] =  {PX1_D[10], PX1_D[8], PX1_D[6], PX1_D[4], PX1_D[2], PX1_HACT};
assign PX1_MRST =       sns1_dp[7]; // from FPGA to sensor
assign PX1_MCLK =       sns1_dp[0]; // from FPGA to sensor
assign sns1_dn[6:0] =  {PX1_D[11], PX1_D[9], PX1_D[7], PX1_D[5], PX1_D[3], PX1_VACT, PX1_DCLK};
assign PX1_ARST =       sns1_dn[7];
assign sns1_clkn =      PX1_D[0];  // inout CNVSYNC/TDI
assign sns1_clkp =      PX1_D[1];  // CNVCLK/TDO
assign PX1_ARO =       sns1_ctl;  // from FPGA to sensor


    wire [ 7:0] sns2_dp;   // inout[7:0] {PX_MRST, PXD8, PXD6, PXD4, PXD2, PXD0, PX_HACT, PX_DCLK}
    wire [ 7:0] sns2_dn;   // inout[7:0] {PX_ARST, PXD9, PXD7, PXD5, PXD3, PXD1, PX_VACT, PX_BPF}
    wire        sns2_clkp; // inout CNVCLK/TDO
    wire        sns2_clkn; // inout CNVSYNC/TDI
    wire        sns2_scl;  // inout PX_SCL
    wire        sns2_sda;  // inout PX_SDA
    wire        sns2_ctl;  // inout PX_ARO/TCK
    wire        sns2_pg;   // inout SENSPGM

    wire [ 7:0] sns3_dp;   // inout[7:0] {PX_MRST, PXD8, PXD6, PXD4, PXD2, PXD0, PX_HACT, PX_DCLK}
    wire [ 7:0] sns3_dn;   // inout[7:0] {PX_ARST, PXD9, PXD7, PXD5, PXD3, PXD1, PX_VACT, PX_BPF}
    wire        sns3_clkp; // inout CNVCLK/TDO
    wire        sns3_clkn; // inout CNVSYNC/TDI
    wire        sns3_scl;  // inout PX_SCL
    wire        sns3_sda;  // inout PX_SDA
    wire        sns3_ctl;  // inout PX_ARO/TCK
    wire        sns3_pg;   // inout SENSPGM

    wire [ 7:0] sns4_dp;   // inout[7:0] {PX_MRST, PXD8, PXD6, PXD4, PXD2, PXD0, PX_HACT, PX_DCLK}
    wire [ 7:0] sns4_dn;   // inout[7:0] {PX_ARST, PXD9, PXD7, PXD5, PXD3, PXD1, PX_VACT, PX_BPF}
    wire        sns4_clkp; // inout CNVCLK/TDO
    wire        sns4_clkn; // inout CNVSYNC/TDI
    wire        sns4_scl;  // inout PX_SCL
    wire        sns4_sda;  // inout PX_SDA
    wire        sns4_ctl;  // inout PX_ARO/TCK
    wire        sns4_pg;   // inout SENSPGM

    wire [ 9:0] gpio_pins; // inout[9:0] ([6]-synco0,[7]-syncio0,[8]-synco1,[9]-syncio1)
// Connect trigger outs to triggets in (#10 needed for Icarus)
assign #10 gpio_pins[7] = gpio_pins[6];
assign #10 gpio_pins[9] = gpio_pins[8];

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
    wire        memclk;

    wire        ffclk0p; // input
    wire        ffclk0n; // input
    wire        ffclk1p; // input
    wire        ffclk1n;  // input


  
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

// SAXI_GP0 - histograms to system memory
    wire        SAXI_GP0_CLK; 
    wire [31:0] saxi_gp0_sim_wr_address;    // output[31:0]   SuppressThisWarning VEditor - not used - just view 
    wire [ 5:0] saxi_gp0_sim_wid;           // output[5:0]    SuppressThisWarning VEditor - not used - just view
    wire        saxi_gp0_sim_wr_valid;      // output
    wire        saxi_gp0_sim_wr_ready;      // input
    wire [31:0] saxi_gp0_sim_wr_data;       // output[31:0]   SuppressThisWarning VEditor - not used - just view
    wire [ 3:0] saxi_gp0_sim_wr_stb;        // output[3:0]    SuppressThisWarning VEditor - not used - just view
    wire [ 1:0] saxi_gp0_sim_wr_size;       // output[1:0]    SuppressThisWarning VEditor - not used - just view
    wire [ 3:0] saxi_gp0_sim_bresp_latency; // input[3:0] 
    wire [ 3:0] saxi_gp0_sim_wr_qos;        // output[3:0]    SuppressThisWarning VEditor - not used - just view

    assign SAXI_GP0_CLK = x393_i.ps7_i.SAXIGP0ACLK;
    assign #1 saxi_gp0_sim_wr_ready = saxi_gp0_sim_wr_valid;
    assign #1 saxi_gp0_sim_bresp_latency=4'h5; 


  
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

    wire        CLK;
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
    $dumpfile(fstname);


  // SuppressWarnings VEditor : assigned in $readmem() system task
    $dumpvars(0,x393_testbench02);
//    CLK =1'b0;
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
    while (x393_i.mrst) @(posedge CLK) ;
//    repeat (4) @(posedge CLK) ;
//set simulation-only parameters   
    axi_set_b_lag(0); //(1);
    axi_set_rd_lag(0);
    program_status_all(DEFAULT_STATUS_MODE,'h2a); // mode auto with sequence number increment 

    enable_memcntrl(1);                 // enable memory controller

    set_up;
    axi_set_wbuf_delay(WBUF_DLY_DFLT); //DFLT_WBUF_DELAY - used in synth. code
    
    wait_phase_shifter_ready;
    read_all_status; //stuck here
    
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
    
    
// ====================== Running optional tests ========================   
    
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

`ifdef TEST_SENSOR
    TEST_TITLE = "TEST_SENSOR";
    $display("===================== TEST_%s =========================",TEST_TITLE);
    setup_sensor_channel (
    0 ); // input  [1:0] num_sensor;
    
`endif

`ifdef READBACK_DELAYS    
  TEST_TITLE = "READBACK";
  $display("===================== TEST_%s =========================",TEST_TITLE);
    axi_get_delays;
`endif    


  TEST_TITLE = "ALL_DONE";
  $display("===================== TEST_%s =========================",TEST_TITLE);
  #20000;
  TEST_TITLE = "WAITING 60usec more";
  $display("===================== TEST_%s =========================",TEST_TITLE);
  #60000;
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
        .sns1_dp   (sns1_dp),    // inout[7:0] {PX_MRST, PXD8, PXD6, PXD4, PXD2, PXD0, PX_HACT, PX_DCLK}
        .sns1_dn   (sns1_dn),    // inout[7:0] {PX_ARST, PXD9, PXD7, PXD5, PXD3, PXD1, PX_VACT, PX_BPF}
        .sns1_clkp (sns1_clkp),  // inout       CNVCLK/TDO
        .sns1_clkn (sns1_clkn),  // inout       CNVSYNC/TDI
        .sns1_scl  (sns1_scl),   // inout       PX_SCL
        .sns1_sda  (sns1_sda),   // inout       PX_SDA
        .sns1_ctl  (sns1_ctl),   // inout       PX_ARO/TCK
        .sns1_pg   (sns1_pg),    // inout       SENSPGM
        
        .sns2_dp   (sns2_dp),    // inout[7:0] {PX_MRST, PXD8, PXD6, PXD4, PXD2, PXD0, PX_HACT, PX_DCLK}
        .sns2_dn   (sns2_dn),    // inout[7:0] {PX_ARST, PXD9, PXD7, PXD5, PXD3, PXD1, PX_VACT, PX_BPF}
        .sns2_clkp (sns2_clkp),  // inout       CNVCLK/TDO
        .sns2_clkn (sns2_clkn),  // inout       CNVSYNC/TDI
        .sns2_scl  (sns2_scl),   // inout       PX_SCL
        .sns2_sda  (sns2_sda),   // inout       PX_SDA
        .sns2_ctl  (sns2_ctl),   // inout       PX_ARO/TCK
        .sns2_pg   (sns2_pg),    // inout       SENSPGM
        
        .sns3_dp   (sns3_dp),    // inout[7:0] {PX_MRST, PXD8, PXD6, PXD4, PXD2, PXD0, PX_HACT, PX_DCLK}
        .sns3_dn   (sns3_dn),    // inout[7:0] {PX_ARST, PXD9, PXD7, PXD5, PXD3, PXD1, PX_VACT, PX_BPF}
        .sns3_clkp (sns3_clkp),  // inout       CNVCLK/TDO
        .sns3_clkn (sns3_clkn),  // inout       CNVSYNC/TDI
        .sns3_scl  (sns3_scl),   // inout       PX_SCL
        .sns3_sda  (sns3_sda),   // inout       PX_SDA
        .sns3_ctl  (sns3_ctl),   // inout       PX_ARO/TCK
        .sns3_pg   (sns3_pg),    // inout       SENSPGM
        
        .sns4_dp   (sns4_dp),    // inout[7:0] {PX_MRST, PXD8, PXD6, PXD4, PXD2, PXD0, PX_HACT, PX_DCLK}
        .sns4_dn   (sns4_dn),    // inout[7:0] {PX_ARST, PXD9, PXD7, PXD5, PXD3, PXD1, PX_VACT, PX_BPF}
        .sns4_clkp (sns4_clkp),  // inout       CNVCLK/TDO
        .sns4_clkn (sns4_clkn),  // inout       CNVSYNC/TDI
        .sns4_scl  (sns4_scl),   // inout       PX_SCL
        .sns4_sda  (sns4_sda),   // inout       PX_SDA
        .sns4_ctl  (sns4_ctl),   // inout       PX_ARO/TCK
        .sns4_pg   (sns4_pg),    // inout       SENSPGM
        
        .gpio_pins (gpio_pins),  // inout[9:0] 
    
        .SDRST   (SDRST),        // DDR3 reset (active low)
        .SDCLK   (SDCLK),        // output 
        .SDNCLK  (SDNCLK),       // outputread_and_wait(BASEADDR_STATUS)
        .SDA     (SDA[14:0]),    // output[14:0] 
        .SDBA    (SDBA[2:0]),    // output[2:0] 
        .SDWE    (SDWE),         // output
        .SDRAS   (SDRAS),        // output
        .SDCAS   (SDCAS),        // output
        .SDCKE   (SDCKE),        // output
        .SDODT   (SDODT),        // output
        .SDD     (SDD[15:0]),    // inout[15:0] 
        .SDDML   (SDDML),        // inout
        .DQSL    (DQSL),         // inout
        .NDQSL   (NDQSL),        // inout
        .SDDMU   (SDDMU),        // inout
        .DQSU    (DQSU),         // inout
        .NDQSU   (NDQSU),        // inout
        .memclk  (memclk),
        .ffclk0p (ffclk0p),      // input
        .ffclk0n (ffclk0n),      // input
        .ffclk1p (ffclk1p),      // input
        .ffclk1n (ffclk1n),      // input
        .DUMMY_TO_KEEP(DUMMY_TO_KEEP)  // to keep PS7 signals from "optimization"
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
        .rst            (RST),                               // input
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
        .sim_wr_address (afi_sim_wr_address),                // output[31:0] 
        .sim_wid        (afi_sim_wid),                       // output[5:0] 
        .sim_wr_valid   (afi_sim_wr_valid),                  // output
        .sim_wr_ready   (afi_sim_wr_ready),                  // input
        .sim_wr_data    (afi_sim_wr_data),                   // output[63:0] 
        .sim_wr_stb     (afi_sim_wr_stb),                    // output[7:0] 
        .sim_bresp_latency(afi_sim_bresp_latency),           // input[3:0] 
        .sim_wr_cap     (afi_sim_wr_cap),                    // output[2:0] 
        .sim_wr_qos     (afi_sim_wr_qos),                    // output[3:0] 
        .reg_addr       (PS_REG_ADDR),                       // input[31:0] 
        .reg_wr         (PS_REG_WR),                         // input
        .reg_rd         (PS_REG_RD),                         // input
        .reg_din        (PS_REG_DIN),                        // input[31:0] 
        .reg_dout       (PS_REG_DOUT)                        // output[31:0] 
    );

    // SAXI_GP0 - histograms to system memory
    simul_saxi_gp_wr simul_saxi_gp0_wr_i (
        .rst               (RST),                         // input
        .aclk              (SAXI_GP0_CLK),                // input
        .aresetn           (), // output
        .awaddr            (x393_i.ps7_i.SAXIGP0AWADDR),  // input[31:0] 
        .awvalid           (x393_i.ps7_i.SAXIGP0AWVALID), // input
        .awready           (x393_i.ps7_i.SAXIGP0AWREADY), // output
        .awid              (x393_i.ps7_i.SAXIGP0AWID),    // input[5:0] 
        .awlock            (x393_i.ps7_i.SAXIGP0AWLOCK),  // input[1:0] 
        .awcache           (x393_i.ps7_i.SAXIGP0AWCACHE), // input[3:0] 
        .awprot            (x393_i.ps7_i.SAXIGP0AWPROT),  // input[2:0] 
        .awlen             (x393_i.ps7_i.SAXIGP0AWLEN),   // input[3:0] 
        .awsize            (x393_i.ps7_i.SAXIGP0AWSIZE),  // input[1:0] 
        .awburst           (x393_i.ps7_i.SAXIGP0AWBURST), // input[1:0] 
        .awqos             (x393_i.ps7_i.SAXIGP0AWQOS),   // input[3:0] 
        .wdata             (x393_i.ps7_i.SAXIGP0WDATA),   // input[31:0] 
        .wvalid            (x393_i.ps7_i.SAXIGP0WVALID),  // input
        .wready            (x393_i.ps7_i.SAXIGP0WREADY),  // output
        .wid               (x393_i.ps7_i.SAXIGP0WID),     // input[5:0] 
        .wlast             (x393_i.ps7_i.SAXIGP0WLAST),   // input
        .wstrb             (x393_i.ps7_i.SAXIGP0WSTRB),   // input[3:0] 
        .bvalid            (x393_i.ps7_i.SAXIGP0BVALID),  // output
        .bready            (x393_i.ps7_i.SAXIGP0BREADY),  // input
        .bid               (x393_i.ps7_i.SAXIGP0BID),     // output[5:0] 
        .bresp             (x393_i.ps7_i.SAXIGP0BRESP),   // output[1:0] 
        .sim_wr_address    (saxi_gp0_sim_wr_address),     // output[31:0] 
        .sim_wid           (saxi_gp0_sim_wid),            // output[5:0] 
        .sim_wr_valid      (saxi_gp0_sim_wr_valid),       // output
        .sim_wr_ready      (saxi_gp0_sim_wr_ready),       // input
        .sim_wr_data       (saxi_gp0_sim_wr_data),        // output[31:0] 
        .sim_wr_stb        (saxi_gp0_sim_wr_stb),         // output[3:0] 
        .sim_wr_size       (saxi_gp0_sim_wr_size),        // output[1:0] 
        .sim_bresp_latency (saxi_gp0_sim_bresp_latency),  // input[3:0] 
        .sim_wr_qos        (saxi_gp0_sim_wr_qos)          // output[3:0] 
    );


// Generate all clocks
//always #(CLKIN_PERIOD/2) CLK = ~CLK;
    simul_clk #(
        .CLKIN_PERIOD  (CLKIN_PERIOD),
        .MEMCLK_PERIOD (MEMCLK_PERIOD),
        .FCLK0_PERIOD  (FCLK0_PERIOD),
        .FCLK1_PERIOD  (FCLK1_PERIOD)
    ) simul_clk_i (
        .rst     (1'b0),               // input
        .clk     (CLK),                // output
        .memclk  (memclk),             // output
        .ffclk0  ({ffclk0n, ffclk0p}), // output[1:0] 
        .ffclk1  ({ffclk1n, ffclk1p})  // output[1:0] 
    );


    simul_sensor12bits #(
        .lline     (VIRTUAL_WIDTH),     // SENSOR12BITS_LLINE),
        .ncols     (FULL_WIDTH),        // (SENSOR12BITS_NCOLS),
`ifdef PF
        .nrows     (PF_HEIGHT),         // SENSOR12BITS_NROWS),
`else
        .nrows     (FULL_HEIGHT),       // SENSOR12BITS_NROWS),
`endif        
        .nrowb     (BLANK_ROWS_BEFORE), // SENSOR12BITS_NROWB),
        .nrowa     (BLANK_ROWS_AFTER),  // SENSOR12BITS_NROWA),
//        .nAV(24),
        .nbpf      (0), // SENSOR12BITS_NBPF),
        .ngp1      (SENSOR12BITS_NGPL),
        .nVLO      (SENSOR12BITS_NVLO),
        .tMD       (SENSOR12BITS_TMD),
        .tDDO      (SENSOR12BITS_TDDO),
        .tDDO1     (SENSOR12BITS_TDDO1),
        .trigdly   (TRIG_LINES), // SENSOR12BITS_TRIGDLY),
        .ramp      (0), //SENSOR12BITS_RAMP),
        .new_bayer (1) //SENSOR12BITS_NEW_BAYER)
    ) simul_sensor12bits_i (
        .MCLK  (PX1_MCLK), // input 
        .MRST  (PX1_MRST), // input 
        .ARO   (PX1_ARO),  // input 
        .ARST  (PX1_ARST), // input 
        .OE    (1'b0),     // input output enable active low
        .SCL   (sns1_scl), // input 
        .SDA   (sns1_sda), // inout 
        .OFST  (PX1_OFST), // input 
        .D     (PX1_D),    // output[11:0] 
        .DCLK  (PX1_DCLK), // output 
        .BPF   (),         // output 
        .HACT  (PX1_HACT), // output 
        .VACT  (PX1_VACT), // output 
        .VACT1 () // output 
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

task write_block_scanline_chn;  // SuppressThisWarning VEditor : may be unused
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

function [10:0] func_encode_mode_tiled;  // SuppressThisWarning VEditor - not used
    input       repetitive;
    input       single;
    input       reset_frame;
    input       byte32; // 32-byte columns (0 - 16-byte columns)
    input       keep_open; // for 8 or less rows - do not close page between accesses
    input [1:0] extra_pages; // number of extra pages that need to stay (not to be overwritten) in the buffer
                             // can be used for overlapping tile read access
    input       write_mem;   // write to memory mode (0 - read from memory)
    input       enable;      // enable requests from this channel ( 0 will let current to finish, but not raise want/need)
    input       chn_reset;       // immediately reset al;l the internal circuitry

    reg  [10:0] rslt;
    begin
        rslt = 0;
        rslt[MCONTR_LINTILE_EN] =                                     ~chn_reset;
        rslt[MCONTR_LINTILE_NRESET] =                                  enable;
        rslt[MCONTR_LINTILE_WRITE] =                                   write_mem;
        rslt[MCONTR_LINTILE_EXTRAPG +: MCONTR_LINTILE_EXTRAPG_BITS] =  extra_pages;
        rslt[MCONTR_LINTILE_KEEP_OPEN] =                               keep_open;
        rslt[MCONTR_LINTILE_BYTE32] =                                  byte32;
        rslt[MCONTR_LINTILE_RST_FRAME] =                               reset_frame;
        rslt[MCONTR_LINTILE_SINGLE] =                                  single;
        rslt[MCONTR_LINTILE_REPEAT] =                                  repetitive;
//        func_encode_mode_tiled={byte32,keep_open,extra_pages,write_mem,enable,~chn_reset};
        func_encode_mode_tiled = rslt;
    end           
endfunction
function [10:0] func_encode_mode_scanline; // SuppressThisWarning VEditor - not used
    input       repetitive;
    input       single;
    input       reset_frame;
    input [1:0] extra_pages; // number of extra pages that need to stay (not to be overwritten) in the buffer
                             // can be used for overlapping tile read access
    input       write_mem;   // write to memory mode (0 - read from memory)
    input       enable;      // enable requests from this channel ( 0 will let current to finish, but not raise want/need)
    input       chn_reset;       // immediately reset al;l the internal circuitry
    
    reg  [10:0] rslt;
    begin
        rslt = 0;
        rslt[MCONTR_LINTILE_EN] =                                     ~chn_reset;
        rslt[MCONTR_LINTILE_NRESET] =                                  enable;
        rslt[MCONTR_LINTILE_WRITE] =                                   write_mem;
        rslt[MCONTR_LINTILE_EXTRAPG +: MCONTR_LINTILE_EXTRAPG_BITS] =  extra_pages;
        rslt[MCONTR_LINTILE_RST_FRAME] =                               reset_frame;
        rslt[MCONTR_LINTILE_SINGLE] =                                  single;
        rslt[MCONTR_LINTILE_REPEAT] =                                  repetitive;
//        func_encode_mode_scanline={extra_pages,write_mem,enable,~chn_reset};
        func_encode_mode_scanline = rslt;
    end           
endfunction

// Sensor - related tasks and functions

task setup_sensor_channel;
    input  [1:0] num_sensor;
    
    reg          trigger_mode; // 0 - auto, 1 - triggered
    reg          ext_trigger_mode; // 0 - internal, 1 - external trigger (camsync)
    reg          external_timestamp; // embed local timestamp, 1 - embed received timestamp
    reg   [31:0] camsync_period;
    reg   [31:0] frame_full_width; // 13-bit Padded line length (8-row increment), in 8-bursts (16 bytes)
    reg   [31:0] window_width;    // 13 bit - in 8*16=128 bit bursts
    reg   [31:0] window_height;   // 16 bit
    reg   [31:0] window_left;
    reg   [31:0] window_top;
    reg   [31:0] last_buf_frame;
    reg   [31:0] camsync_delay;
    reg   [ 3:0] sensor_mask;
// Setting up a single sensor channel 0, sunchannel 0
// 
    begin
        window_height = FULL_HEIGHT;
        window_left = 0;
        window_top = 0;
        window_width =       SENSOR_MEMORY_WIDTH_BURSTS;
        frame_full_width =   SENSOR_MEMORY_FULL_WIDTH_BURSTS;
        camsync_period =     TRIG_PERIOD;
        camsync_delay =      CAMSYNC_DELAY;
        trigger_mode =       TRIGGER_MODE;
        ext_trigger_mode =   EXT_TRIGGER_MODE;
        external_timestamp = EXTERNAL_TIMESTAMP;
        last_buf_frame =     LAST_BUF_FRAME;
        sensor_mask =        1 << num_sensor;
//        program_curves(
//            num_sensor,  // input   [1:0] num_sensor;
//            0);          // input   [1:0] sub_channel;    
        program_status_gpio (
            3,          // input [1:0] mode;
            0);         // input [5:0] seq_num;

        program_status_sensor_i2c(
            num_sensor,  // input [1:0] num_sensor;
            3,           // input [1:0] mode;
            0);          //input [5:0] seq_num;
        program_status_sensor_io(
            num_sensor,  // input [1:0] num_sensor;
            3,           // input [1:0] mode;
            0);          //input [5:0] seq_num;
            
        program_status_rtc( // also takes snapshot
            3,         // input [1:0] mode;
            0);        //input [5:0] seq_num;
            
        set_rtc (
            32'h12345678, // input [31:0] sec;
            0,            //input [19:0] usec;
            16'h8000);    // input [15:0] corr;  maximal correction to the rtc

    // moved before camsync to have a valid timestamo w/o special waiting            
    TEST_TITLE = "MEMORY_SENSOR";
    $display("===================== TEST_%s =========================",TEST_TITLE);
            
        setup_sensor_memory (
            num_sensor,                    // input  [1:0] num_sensor;
            FRAME_START_ADDRESS,           // input [31:0] frame_sa;         // 22-bit frame start address ((3 CA LSBs==0. BA==0)
            FRAME_START_ADDRESS_INC,       // input [31:0] frame_sa_inc;     // 22-bit frame start address increment  ((3 CA LSBs==0. BA==0)
            last_buf_frame,                // input [31:0] last_frame_num;   // 16-bit number of the last frame in a buffer
            frame_full_width,              // input [31:0] frame_full_width; // 13-bit Padded line length (8-row increment), in 8-bursts (16 bytes)
            window_width,                  // input [31:0] window_width;    // 13 bit - in 8*16=128 bit bursts
            window_height,                 // input [31:0] window_height;   // 16 bit
            window_left,                   // input [31:0] window_left;
            window_top);                   // input [31:0] window_top;

    // Enable arbitration of sensor-to-memory controller
    enable_memcntrl_en_dis(4'h8 + {2'b0,num_sensor}, 1);
    
    compressor_run (num_sensor, 0); // reset compressor
    
    
    setup_compressor_channel(
        num_sensor,              // sensor channel number (0..3)
        0,                       // qbank;    // [6:3] quantization table page
        1,                       // dc_sub;   // [8:7] subtract DC
        CMPRS_CBIT_CMODE_JPEG18, //input [31:0] cmode;   //  [13:9] color mode:
//        parameter CMPRS_CBIT_CMODE_JPEG18 =   4'h0, // color 4:2:0
//        parameter CMPRS_CBIT_CMODE_MONO6 =    4'h1, // mono 4:2:0 (6 blocks)
//        parameter CMPRS_CBIT_CMODE_JP46 =     4'h2, // jp4, 6 blocks, original
//        parameter CMPRS_CBIT_CMODE_JP46DC =   4'h3, // jp4, 6 blocks, dc -improved
//        parameter CMPRS_CBIT_CMODE_JPEG20 =   4'h4, // mono, 4 blocks (but still not actual monochrome JPEG as the blocks are scanned in 2x2 macroblocks)
//        parameter CMPRS_CBIT_CMODE_JP4 =      4'h5, // jp4,  4 blocks, dc-improved
//        parameter CMPRS_CBIT_CMODE_JP4DC =    4'h6, // jp4,  4 blocks, dc-improved
//        parameter CMPRS_CBIT_CMODE_JP4DIFF =  4'h7, // jp4,  4 blocks, differential
//        parameter CMPRS_CBIT_CMODE_JP4DIFFHDR =  4'h8, // jp4,  4 blocks, differential, hdr
//        parameter CMPRS_CBIT_CMODE_JP4DIFFDIV2 = 4'h9, // jp4,  4 blocks, differential, divide by 2
//        parameter CMPRS_CBIT_CMODE_JP4DIFFHDRDIV2 = 4'ha, // jp4,  4 blocks, differential, hdr,divide by 2
//        parameter CMPRS_CBIT_CMODE_MONO1 =    4'hb, // mono JPEG (not yet implemented)
//        parameter CMPRS_CBIT_CMODE_MONO4 =    4'he, // mono 4 blocks
        1,                      // input [31:0] multi_frame;   // [15:14] 0 - single-frame buffer, 1 - multiframe video memory buffer
        0,                      // input [31:0] bayer;         // [20:18] // Bayer shift
        0,                      // input [31:0] focus_mode;    // [23:21] Set focus mode
        3,                      // num_macro_cols_m1; // number of macroblock colums minus 1
        1,                      // num_macro_rows_m1; // number of macroblock rows minus 1
        1,                      // input [31:0] left_margin;       // left margin of the first pixel (0..31) for 32-pixel wide colums in memory access
        'h120,                  // input [31:0] colorsat_blue; //color saturation for blue (10 bits) //'h90 for 100%
        'h16c,                  // colorsat_red; //color saturation for red (10 bits)   // 'b6 for 100%
        0);                     // input [31:0] coring;     // coring value
    // TODO: calculate widths correctly!
    setup_compressor_memory (
            num_sensor,                    // input  [1:0] num_sensor;
            FRAME_START_ADDRESS,           // input [31:0] frame_sa;         // 22-bit frame start address ((3 CA LSBs==0. BA==0)
            FRAME_START_ADDRESS_INC,       // input [31:0] frame_sa_inc;     // 22-bit frame start address increment  ((3 CA LSBs==0. BA==0)
            last_buf_frame,                // input [31:0] last_frame_num;   // 16-bit number of the last frame in a buffer
            frame_full_width,              // input [31:0] frame_full_width; // 13-bit Padded line length (8-row increment), in 8-bursts (16 bytes)
            window_width, //  & ~3,             // input [31:0] window_width;    // 13 bit - in 8*16=128 bit bursts
            window_height & ~15,           // input [31:0] window_height;   // 16 bit
            window_left,                   // input [31:0] window_left;
            window_top+1,                  // input [31:0] window_top; (to match 20x20 tiles in 353)
            1,   // input        byte32;     // == 1? 
            2,   //input [31:0] tile_width; // == 2
            1);  // input [31:0] extra_pages; // 1
    
    compressor_run (num_sensor, 3); // run repetitive mode
            
    TEST_TITLE = "CAMSYNC_SETUP";
    $display("===================== TEST_%s =========================",TEST_TITLE);
            
// setup camsync module
        set_camsync_period  (0); // reset circuitry
        set_gpio_ports (
            0,  // input [1:0] port_soft; // <2 - unchanged, 2 - disable, 3 - enable
            3,  // input [1:0] port_a; // camsync
            0,  // input [1:0] port_b; // motors on 353
            0); //input [1:0] port_c; // logger

        set_camsync_mode (
            1'b1,                      // input       en;             // 1 - enable module, 0 - reset
            {1'b1,1'b1},               // input [1:0] en_snd;         // <2 - NOP, 2 - disable, 3 - enable sending timestamp with sync pulse
            {1'b1,external_timestamp}, // input [1:0] en_ts_external; // <2 - NOP, 2 - local timestamp in the frame header, 3 - use external timestamp
            {1'b1,trigger_mode},       // input [1:0] triggered_mode; // <2 - NOP, 2 - async sensor mode, 3 - triggered sensor mode
            {1'b1, 2'h0},              // input [2:0] master_chn;     // <4 - NOP, 4..7 - set master channel
            {1'b1, sensor_mask});      // input [4:0] chn_en;         // <16 - NOP, [3:0] - bit mask of enabled sensor channels
    // setting I/Os after camsync is enabled
        reset_camsync_inout (0);        // reset input selection
        if (ext_trigger_mode)
            set_camsync_inout   (0, 7, 1 ); // set input selection - ext[7], active high
        reset_camsync_inout (1);        // reset output selection
        set_camsync_inout   (1, 6, 1 ); // reset output selection - ext[6], active high
        set_camsync_period  (SYNC_BIT_LENGTH); ///set (bit_length -1) (should be 2..255)
        set_camsync_delay (
            0, // input  [1:0] sub_chn;
            camsync_delay); // input [31:0] dly;          // 0 - input selection, 1 - output selection


        set_camsync_period  (camsync_period); // set period (start generating) - in 353 was after everything else was set

    TEST_TITLE = "DELAYS_SETUP";
    $display("===================== TEST_%s =========================",TEST_TITLE);
            
       set_sensor_io_dly (
            num_sensor,                                 // input                            [1:0] num_sensor;
            128'h33404850_58606870_78808890_98a0a8b0 ); //input [127:0] dly; // {mmsm_phase, bpf, vact, hact, pxd11,...,pxd0]
            
    TEST_TITLE = "IO_SETUP";
    $display("===================== TEST_%s =========================",TEST_TITLE);
        set_sensor_io_width(
            num_sensor, // input    [1:0] num_sensor;
            FULL_WIDTH); // Or use 0 for sensor-generated HACT input   [15:0] width; // 0 - use HACT, >0 - generate HACT from start to specified width
            
        set_sensor_io_ctl (
            num_sensor,  // input                    [1:0] num_sensor;
            3,  // input                            [1:0] mrst;     // <2: keep MRST, 2 - MRST low (active),  3 - high (inactive)
            3,  // input                            [1:0] arst;     // <2: keep ARST, 2 - ARST low (active),  3 - high (inactive)
            3,  // input                            [1:0] aro;      // <2: keep ARO,  2 - set ARO (software controlled) low,  3 - set ARO  (software controlled) high
            0,  // input                            [1:0] mmcm_rst; // <2: keep MMCM reset, 2 - MMCM reset off,  3 - MMCM reset on
            3,  // input                            [1:0] clk_sel;  // <2: keep MMCM clock source, 2 - use internal pixel clock,  3 - use pixel clock from the sensor
            0,  // input                                  set_delays; // (self-clearing) load all pre-programmed delays 
            1'b1,  // input                               set_quadrants;  // 0 - keep quadrants settings, 1 - update quadrants
//            6'h24); // data-0, hact - 1, vact - 2 input  [SENS_CTRL_QUADRANTS_WIDTH-1:0] quadrants;  // 90-degree shifts for data [1:0], hact [3:2] and vact [5:4]
//            6'h01); // data-1, hact - 0, vact - 0 input  [SENS_CTRL_QUADRANTS_WIDTH-1:0] quadrants;  // 90-degree shifts for data [1:0], hact [3:2] and vact [5:4]
            QUADRANTS_PXD_HACT_VACT); // data-0, hact - 1, vact - 2 input  [SENS_CTRL_QUADRANTS_WIDTH-1:0] quadrants;  // 90-degree shifts for data [1:0], hact [3:2] and vact [5:4]
/*
// setup camsync module
        reset_camsync_inout (0);        // reset input selection
        if (ext_trigger_mode)
            set_camsync_inout   (0, 7, 1 ); // set input selection - ext[7], active high
        reset_camsync_inout (1);        // reset output selection
        set_camsync_inout   (1, 6, 1 ); // reset output selection - ext[6], active high
        set_camsync_period  (camsync_period); // set period
        set_camsync_delay (
            0, // input  [1:0] sub_chn;
            camsync_delay); // input [31:0] dly;          // 0 - input selection, 1 - output selection

        set_camsync_mode (
            {1'b1,1'b1},               // input [1:0] en_snd;         // <2 - NOP, 2 - disable, 3 - enable sending timestamp with sync pulse
            {1'b1,external_timestamp}, // input [1:0] en_ts_external; // <2 - NOP, 2 - local timestamp in the frame header, 3 - use external timestamp
            {1'b1,trigger_mode},       // input [1:0] triggered_mode; // <2 - NOP, 2 - async sensor mode, 3 - triggered sensor mode
            {1'b1, 2'h0},              // input [2:0] master_chn;     // <4 - NOP, 4..7 - set master channel
            {1'b1, sensor_mask});      // input [4:0] chn_en;         // <16 - NOP, [3:0] - bit mask of enabled sensor channels
*/
    TEST_TITLE = "I2C_TEST";
    $display("===================== TEST_%s =========================",TEST_TITLE);

        test_i2c_353; // test soft/sequencer i2c
        
    TEST_TITLE = "LENS_FLAT_SETUP";
    $display("===================== TEST_%s =========================",TEST_TITLE);
        set_sensor_lens_flat_heights (
            num_sensor, // input   [1:0] num_sensor;
            'hffff,     // input  [15:0] height0_m1; // height of the first sub-frame minus 1
            0,          // input  [15:0] height1_m1; // height of the second sub-frame minus 1
            0);         // input  [15:0] height2_m1; // height of the third sub-frame minus 1 (no need for 4-th)
        set_sensor_lens_flat_parameters(
            num_sensor,
// add mode "DIRECT", "ASAP", "RELATIVE", "ABSOLUTE" and frame number
            19'h20000, // 0,      // input  [18:0] AX;
            19'h20000, // 0,      // input  [18:0] AY;
            21'h180000, //0,      // input  [20:0] BX;
            21'h180000, //0,      // input  [20:0] BY;
            'h8000, // input  [18:0] C;
            32768,  // input  [16:0] scales0;
            32768,  // input  [16:0] scales1;
            32768,  // input  [16:0] scales2;
            32768,  // input  [16:0] scales3;
            0,      // input  [15:0] fatzero_in;
            0,      // input  [15:0] fatzero_out;
            1);      // input  [ 3:0] post_scale;
/*
   cpu_wr('h63,'h31020000); // [AX] => 0x20000
   cpu_wr('h63,'h310a0000); // [AY] => 0x20000
*/        
    TEST_TITLE = "GAMMA_SETUP";
    $display("===================== TEST_%s =========================",TEST_TITLE);

        set_sensor_gamma_heights (
            num_sensor, // input   [1:0] num_sensor;
            'hffff,     // input  [15:0] height0_m1; // height of the first sub-frame minus 1
            0,          // input  [15:0] height1_m1; // height of the second sub-frame minus 1
            0);         // input  [15:0] height2_m1; // height of the third sub-frame minus 1 (no need for 4-th)
           
        // Configure histograms
    TEST_TITLE = "HISTOGRAMS_SETUP";
    $display("===================== TEST_%s =========================",TEST_TITLE);
        set_sensor_histogram_window ( // 353 did it using command sequencer)
            num_sensor,          // input   [1:0] num_sensor; // sensor channel number (0..3)
            0,                   // input   [1:0] subchannel; // subchannel number (for multiplexed images)
            HISTOGRAM_LEFT,      // input  [15:0] left;
            HISTOGRAM_TOP,       // input  [15:0] top;
            HISTOGRAM_WIDTH-1,   // input  [15:0] width_m1;  // one less than window width. If 0 - use frame right margin (end of HACT)
            HISTOGRAM_HEIGHT-1); // input  [15:0] height_m1; // one less than window height. If 0 - use frame bottom margin (end of VACT)

        set_sensor_histogram_saxi_addr (
            num_sensor, // input   [1:0] num_sensor; // sensor channel number (0..3)
            0,          // input   [1:0] subchannel; // subchannel number (for multiplexed images)
            HISTOGRAM_STRAT_PAGE); // input  [19:0] page; //start address in 4KB pages (1 page - one subchannel histogram)
            
         set_sensor_histogram_saxi (
            1'b1,                // input         en;
            1'b1,                // input         nrst;
            1'b1,                // input         confirm_write; // wait for the write confirmed befoer swicthing channels
            4'h3);               // input   [3:0] cache_mode;    // default should be 4'h3

/*
task    set_sensor_io_jtag;
    input                            [1:0] num_sensor;
    input                            [1:0] pgmen;    // <2: keep PGMEN, 2 - PGMEN low (inactive),  3 - high (active) enable JTAG control
    input                            [1:0] prog;     // <2: keep prog, 2 - prog low (active),  3 - high (inactive) ("program" pin control)
    input                            [1:0] tck;      // <2: keep TCK,  2 - set TCK low,  3 - set TCK high
    input                            [1:0] tms;      // <2: keep TMS,  2 - set TMS low,  3 - set TMS high
    input                            [1:0] tdi;      // <2: keep TDI,  2 - set TDI low,  3 - set TDI high

task ctrl_cmd_frame_sequencer;
    input [1:0] num_sensor; // sensor channel number
    input       reset;      // reset sequencer (also stops)
    input       start;      // start sequencer
    input       stop;       // stop sequencer

task write_cmd_frame_sequencer;
    input                  [1:0] num_sensor; // sensor channel number
    input                        relative;   // 0 - absolute (address = 0..f), 1 - relative (address= 0..e)
    input                  [3:0] frame_addr;   // frame address (relative ort absolute)
    input [AXI_WR_ADDR_BITS-1:0] addr;         // command address (register to which command should be applied)
    input                 [31:0] data;         // command data

*/            
        // Run after histogram channel is set up?
    TEST_TITLE = "SENSOR_SETUP";
    $display("===================== TEST_%s =========================",TEST_TITLE);
            
        set_sensor_mode (
            num_sensor, // input  [1:0] num_sensor;
            4'h1,       // input  [3:0] hist_en;    // [0..3] 1 - enable histogram modules, disable after processing the started frame
            4'h1,       // input  [3:0] hist_nrst;  // [4..7] 0 - immediately reset histogram module 
            1'b1,       // input        chn_en;     // [8]    1 - enable sensor channel (0 - reset) 
            1'b0);      // input        bits16;     // [9]    0 - 8 bpp mode, 1 - 16 bpp (bypass gamma). Gamma-processed data is still used for histograms
            // test i2c - manual and sequencer (same data as in 353 test fixture

    TEST_TITLE = "CMPRS_EN_ARBIT";
    $display("===================== TEST_%s =========================",TEST_TITLE);
    // just temporarily - enable channel immediately    
    enable_memcntrl_en_dis(4'hc + {2'b0,num_sensor}, 1);
    
    TEST_TITLE = "GAMMA_CTL";
    $display("===================== TEST_%s =========================",TEST_TITLE);
        set_sensor_gamma_ctl (// doing last to enable sesnor data when everything else is set up
            num_sensor, // input   [1:0] num_sensor; // sensor channel number (0..3)
            2'h0, // 2'h3,       // input   [1:0] bayer;      // bayer shift (0..3)
            0,          // input         table_page; // table page (only used if SENS_GAMMA_BUFFER)
            1'b1,       // input         en_input;   // enable channel input
            1'b1,       // input         repet_mode; //  Normal mode, single trigger - just for debugging
            1'b0);      // input         trig;       // pass next frame
    // temporarily putting in the very end as it takes about 30 usec to program curves (TODO: see how to make it faster for simulation)
    TEST_TITLE = "GAMMA_LOAD";
    $display("===================== TEST_%s =========================",TEST_TITLE);
        program_curves(
            num_sensor,  // input   [1:0] num_sensor;
            0);          // input   [1:0] sub_channel;    
    // just temporarily - enable channel immediately    
//    enable_memcntrl_en_dis(4'hc + {2'b0,num_sensor}, 1);
            

    end
endtask

task setup_compressor_channel;
    input [ 1:0] num_sensor; // sensor channel number (0..3)
    input [31:0] qbank;    // [6:3] quantization table page
    input [31:0] dc_sub;   // [8:7] subtract DC
    input [31:0] cmode;   //  [13:9] color mode:
//        parameter CMPRS_CBIT_CMODE_JPEG18 =   4'h0, // color 4:2:0
//        parameter CMPRS_CBIT_CMODE_MONO6 =    4'h1, // mono 4:2:0 (6 blocks)
//        parameter CMPRS_CBIT_CMODE_JP46 =     4'h2, // jp4, 6 blocks, original
//        parameter CMPRS_CBIT_CMODE_JP46DC =   4'h3, // jp4, 6 blocks, dc -improved
//        parameter CMPRS_CBIT_CMODE_JPEG20 =   4'h4, // mono, 4 blocks (but still not actual monochrome JPEG as the blocks are scanned in 2x2 macroblocks)
//        parameter CMPRS_CBIT_CMODE_JP4 =      4'h5, // jp4,  4 blocks, dc-improved
//        parameter CMPRS_CBIT_CMODE_JP4DC =    4'h6, // jp4,  4 blocks, dc-improved
//        parameter CMPRS_CBIT_CMODE_JP4DIFF =  4'h7, // jp4,  4 blocks, differential
//        parameter CMPRS_CBIT_CMODE_JP4DIFFHDR =  4'h8, // jp4,  4 blocks, differential, hdr
//        parameter CMPRS_CBIT_CMODE_JP4DIFFDIV2 = 4'h9, // jp4,  4 blocks, differential, divide by 2
//        parameter CMPRS_CBIT_CMODE_JP4DIFFHDRDIV2 = 4'ha, // jp4,  4 blocks, differential, hdr,divide by 2
//        parameter CMPRS_CBIT_CMODE_MONO1 =    4'hb, // mono JPEG (not yet implemented)
//        parameter CMPRS_CBIT_CMODE_MONO4 =    4'he, // mono 4 blocks
    input [31:0] multi_frame;   // [15:14] 0 - single-frame buffer, 1 - multiframe video memory buffer
    input [31:0] bayer;         // [20:18] // Bayer shift
    input [31:0] focus_mode;    // [23:21] Set focus mode
    input [31:0] num_macro_cols_m1; // number of macroblock colums minus 1
    input [31:0] num_macro_rows_m1; // number of macroblock rows minus 1
    input [31:0] left_margin;       // left margin of the first pixel (0..31) for 32-pixel wide colums in memory access
    input [31:0] colorsat_blue; //color saturation for blue (10 bits) //'h90 for 100%
    input [31:0] colorsat_red; //color saturation for red (10 bits)   // 'b6 for 100%
    input [31:0] coring;     // coring value

    begin
        TEST_TITLE = "COMPRESSOR_SETUP";
        $display("===================== TEST_%s =========================",TEST_TITLE);
            
        compressor_control(
            num_sensor,    // sensor channel number (0..3)
            'h80000000,    // run_mode; NOP
            qbank,         // [6:3] quantization table page
            dc_sub,        // [8:7] subtract DC
            cmode,         //  [13:9] color mode:
            multi_frame,   // [15:14] 0 - single-frame buffer, 1 - multiframe video memory buffer
            bayer,         // [20:18] // Bayer shift
            focus_mode);   // [23:21] Set focus mode
            
        compressor_format(
            num_sensor,        // sensor channel number (0..3)
            num_macro_cols_m1, // number of macroblock colums minus 1
            num_macro_rows_m1, // number of macroblock rows minus 1
            left_margin);      // left margin of the first pixel (0..31) for 32-pixel wide colums in memory access
    
        compressor_color_saturation(
            num_sensor,    // sensor channel number (0..3)
            colorsat_blue, // color saturation for blue (10 bits) //'h90 for 100%
            colorsat_red); // color saturation for red (10 bits)   // 'b6 for 100%

        compressor_coring(
            num_sensor,    // sensor channel number (0..3)
            coring);       // coring value
    end
endtask

task compressor_run;
    input [ 1:0] num_sensor; // sensor channel number (0..3)
    input [31:0] run_mode;    // [6:3] quantization table page
    begin
        compressor_control(
            num_sensor,   // sensor channel number (0..3)
            run_mode,     // 0 - reset, 2 - run single from memory, 3 - run repetitive
            'h80000000,   //
            'h80000000,   //
            'h80000000,   //
            'h80000000,   //
            'h80000000,   //
            'h80000000);  //
    end
endtask



task setup_sensor_memory;
    input  [1:0] num_sensor;
    input [31:0] frame_sa;         // 22-bit frame start address ((3 CA LSBs==0. BA==0)
    input [31:0] frame_sa_inc;     // 22-bit frame start address increment  ((3 CA LSBs==0. BA==0)
    input [31:0] last_frame_num;   // 16-bit number of the last frame in a buffer
    input [31:0] frame_full_width; // 13-bit Padded line length (8-row increment), in 8-bursts (16 bytes)
    input [31:0] window_width;    // 13 bit - in 8*16=128 bit bursts
    input [31:0] window_height;   // 16 bit
    input [31:0] window_left;
    input [31:0] window_top;
    
    reg [29:0] base_addr;
    integer    mode;
    begin
        base_addr = MCONTR_SENS_BASE + MCONTR_SENS_INC * num_sensor;
        mode=   func_encode_mode_scanline(
                    1, // repetitive,
                    0, // single,
                    0, // reset_frame,
                    0, // extra_pages,
                    1, // write_mem,
                    1, // enable
                    0);  // chn_reset
        write_contol_register(base_addr + MCNTRL_SCANLINE_STARTADDR,        frame_sa); // RA=80, CA=0, BA=0 22-bit frame start address (3 CA LSBs==0. BA==0)
        write_contol_register(base_addr + MCNTRL_SCANLINE_FRAME_SIZE,       frame_sa_inc);
        write_contol_register(base_addr + MCNTRL_SCANLINE_FRAME_LAST,       last_frame_num);
        write_contol_register(base_addr + MCNTRL_SCANLINE_FRAME_FULL_WIDTH, frame_full_width);
        write_contol_register(base_addr + MCNTRL_SCANLINE_WINDOW_WH,        {window_height[15:0],window_width[15:0]}); //WINDOW_WIDTH + (WINDOW_HEIGHT<<16));
        write_contol_register(base_addr + MCNTRL_SCANLINE_WINDOW_X0Y0,      {window_top[15:0],window_left[15:0]}); //WINDOW_X0+ (WINDOW_Y0<<16));
        write_contol_register(base_addr + MCNTRL_SCANLINE_WINDOW_STARTXY,   32'b0);
        write_contol_register(base_addr + MCNTRL_SCANLINE_MODE,             mode); 
    end
endtask

task setup_compressor_memory;
    input  [1:0] num_sensor;
    input [31:0]frame_sa;         // 22-bit frame start address ((3 CA LSBs==0. BA==0)
    input [31:0] frame_sa_inc;     // 22-bit frame start address increment  ((3 CA LSBs==0. BA==0)
    input [31:0] last_frame_num;   // 16-bit number of the last frame in a buffer
    input [31:0] frame_full_width; // 13-bit Padded line length (8-row increment), in 8-bursts (16 bytes)
    input [31:0] window_width;    // 13 bit - in 8*16=128 bit bursts
    input [31:0] window_height;   // 16 bit
    input [31:0] window_left;
    input [31:0] window_top;
    input        byte32;     // == 1? 
    input [31:0] tile_width; // == 2
    input [31:0] extra_pages; // 1
    
    reg [29:0] base_addr;
    integer    mode;
    reg   [7:0] tile_height;
    reg   [7:0] tile_vstep;
    begin
        tile_vstep = 16;
        tile_height= 18;
        
        
        base_addr = MCONTR_CMPRS_BASE + MCONTR_CMPRS_INC * num_sensor;
        mode=   func_encode_mode_tiled(
                    1,                // repetitive,
                    0,                // single,
                    0,                // reset_frame,
                    byte32,           // byte32,
                    0,                // keep_open,
                    extra_pages[1:0], // extra_pages
                    0,                // write_mem,
                    1,                // enable
                    0);               // chn_reset
                    
        write_contol_register(base_addr + MCNTRL_TILED_STARTADDR,        frame_sa); // RA=80, CA=0, BA=0 22-bit frame start address (3 CA LSBs==0. BA==0)
        write_contol_register(base_addr + MCNTRL_TILED_FRAME_SIZE,       frame_sa_inc);
        write_contol_register(base_addr + MCNTRL_TILED_FRAME_LAST,       last_frame_num);
        write_contol_register(base_addr + MCNTRL_TILED_FRAME_FULL_WIDTH, frame_full_width);
        write_contol_register(base_addr + MCNTRL_TILED_WINDOW_WH,        {window_height[15:0],window_width[15:0]}); //WINDOW_WIDTH + (WINDOW_HEIGHT<<16));
        write_contol_register(base_addr + MCNTRL_TILED_WINDOW_X0Y0,      {window_top[15:0],window_left[15:0]}); //WINDOW_X0+ (WINDOW_Y0<<16));
        write_contol_register(base_addr + MCNTRL_TILED_WINDOW_STARTXY,   32'b0);
        write_contol_register(base_addr + MCNTRL_TILED_TILE_WHS,         {8'b0,tile_vstep,tile_height,tile_width[7:0]});//(tile_height<<8)+(tile_vstep<<16));
        write_contol_register(base_addr + MCNTRL_TILED_MODE,             mode); 
    end
endtask



task test_i2c_353;
    begin
        set_sensor_i2c_command(
            2'b0,   // input                             [1:0] num_sensor;
            1'b1,   // input                                   rst_cmd;    // [14]   reset all FIFO (takes 16 clock pulses), also - stops i2c until run command
            2'b0,   // input       [SENSI2C_CMD_RUN_PBITS : 0] run_cmd;    // [13:12]3 - run i2c, 2 - stop i2c (needed before software i2c), 1,0 - no change to run state
            1'b1,   // input                                   set_bytes;  // [11] if 1, use bytes (below), 0 - nop
            2'h3,   // input  [SENSI2C_CMD_BYTES_PBITS -1 : 0] bytes;      // [10:9] set command bytes to send after slave address (0..3)
            1'b1,   // input                                   set_dly;    // [8] if 1, use dly (0 - ignore)
            8'h0a,  // input   [SENSI2C_CMD_DLY_PBITS - 1 : 0] dly;        // [7:0]  - duration of quater i2c cycle (if 0, [3:0] control SCL+SDA)
            2'b0,   // input    [SENSI2C_CMD_SCL_WIDTH -1 : 0] scl_ctl;    // [1:0] : 0: NOP, 1: 1'b0->SCL, 2: 1'b1->SCL, 3: 1'bz -> SCL 
            2'b0);  // input    [SENSI2C_CMD_SDA_WIDTH -1 : 0] sda_ctl;    // [3:2] : 0: NOP, 1: 1'b0->SDA, 2: 1'b1->SDA, 3: 1'bz -> SDA  
        repeat (10) @ (posedge CLK); // wait for initialization to be done TODO: use status
        set_sensor_i2c_command (0, 0, 3, 0, 0, 0, 0, 0, 0); // run i2c - reset software bits
        set_sensor_i2c_command (0, 0, 2, 0, 0, 0, 0, 0, 0); // stop i2c, enable software control

        set_sensor_i2c_command (0, 0, 0, 0, 0, 0, 0, 0, 2); // SDA = 1 
        set_sensor_i2c_command (0, 0, 0, 0, 0, 0, 0, 0, 1); // SDA = 0
        set_sensor_i2c_command (0, 0, 0, 0, 0, 0, 0, 2, 0); // SCL = 1 
        set_sensor_i2c_command (0, 0, 0, 0, 0, 0, 0, 1, 0); // SCL = 0 
        set_sensor_i2c_command (0, 0, 0, 0, 0, 0, 0, 0, 2); // SDA = 1 
        set_sensor_i2c_command (0, 0, 0, 0, 0, 0, 0, 2, 0); // SCL = 1 
        set_sensor_i2c_command (0, 0, 0, 0, 0, 0, 0, 0, 3); // SDA = 'bz 
        set_sensor_i2c_command (0, 0, 0, 0, 0, 0, 0, 3, 0); // SCL = 'bz 

        set_sensor_i2c_command (0, 0, 3, 0, 0, 0, 0, 0, 0); // run i2c
        write_sensor_i2c (
            0,           // input   [1:0] num_sensor;
            0,           // input         rel_addr; // 0 - absolute, 1 - relative
            1,           // input integer addr;
            'h90040793); // input  [31:0] data;
                    
        write_sensor_i2c (0, 0, 1,'h90050a23);        
        write_sensor_i2c (0, 0, 2,'h90080001);        
        write_sensor_i2c (0, 0, 3,'h90090123);        
        write_sensor_i2c (0, 1, 2,'h90091234);        
        write_sensor_i2c (0, 0, 4,'h9004001f);        
        write_sensor_i2c (0, 0, 4,'h9005002f);        
        write_sensor_i2c (0, 1, 3,'h90020013);        
        write_sensor_i2c (0, 1, 3,'h90030017);        
    
    end
endtask



task program_status_sensor_i2c;
    input [1:0] num_sensor;
    input [1:0] mode;
    input [5:0] seq_num;
    begin
        program_status (SENSOR_GROUP_ADDR + num_sensor * SENSOR_BASE_INC + SENSI2C_CTRL_RADDR,
                        SENSI2C_STATUS,
                        mode,
                        seq_num);
    end
endtask

task program_status_sensor_io;
    input [1:0] num_sensor;
    input [1:0] mode;
    input [5:0] seq_num;
    begin
        program_status (SENSOR_GROUP_ADDR + num_sensor * SENSOR_BASE_INC + SENSIO_RADDR,
                        SENSI2C_STATUS,
                        mode,
                        seq_num);
    end
endtask

task program_status_compressor;
    input [1:0] num_sensor;
    input [1:0] mode;
    input [5:0] seq_num;
    begin
        program_status (CMPRS_GROUP_ADDR + num_sensor * CMPRS_BASE_INC,
                        CMPRS_STATUS_CNTRL,
                        mode,
                        seq_num);
    end
endtask

task program_status_gpio;
    input [1:0] mode;
    input [5:0] seq_num;
    begin
        program_status (GPIO_ADDR,
                        GPIO_SET_STATUS,
                        mode,
                        seq_num);
    end
endtask

task set_gpio_ports;
    input [1:0] port_soft; // <2 - unchanged, 2 - disable, 3 - enable
    input [1:0] port_a; // camsync
    input [1:0] port_b; // motors on 353
    input [1:0] port_c; // logger
    
    reg  [31:0] data;
    begin
        data = 0;
        data [GPIO_PORTEN + 0 +:2] = port_soft;
        data [GPIO_PORTEN + 2 +:2] = port_a;
        data [GPIO_PORTEN + 4 +:2] = port_b;
        data [GPIO_PORTEN + 6 +:2] = port_c;
        write_contol_register( GPIO_ADDR + GPIO_SET_PINS, data);
    end
endtask
    
task set_gpio_pins;
    input [1:0] ext0; // 0 - nop, 1 - set "0", 2 - set "1", 3 - set as input
    input [1:0] ext1; // 0 - nop, 1 - set "0", 2 - set "1", 3 - set as input
    input [1:0] ext2; // 0 - nop, 1 - set "0", 2 - set "1", 3 - set as input
    input [1:0] ext3; // 0 - nop, 1 - set "0", 2 - set "1", 3 - set as input
    input [1:0] ext4; // 0 - nop, 1 - set "0", 2 - set "1", 3 - set as input
    input [1:0] ext5; // 0 - nop, 1 - set "0", 2 - set "1", 3 - set as input
    input [1:0] ext6; // 0 - nop, 1 - set "0", 2 - set "1", 3 - set as input
    input [1:0] ext7; // 0 - nop, 1 - set "0", 2 - set "1", 3 - set as input
    input [1:0] ext8; // 0 - nop, 1 - set "0", 2 - set "1", 3 - set as input
    input [1:0] ext9; // 0 - nop, 1 - set "0", 2 - set "1", 3 - set as input
    
    reg  [31:0] data;
    begin
        data = 0;
        data [ 0 +:2] = ext0;
        data [ 2 +:2] = ext1;
        data [ 4 +:2] = ext2;
        data [ 6 +:2] = ext3;
        data [ 8 +:2] = ext4;
        data [10 +:2] = ext5;
        data [12 +:2] = ext6;
        data [14 +:2] = ext7;
        data [16 +:2] = ext8;
        data [18 +:2] = ext9;
        write_contol_register( GPIO_ADDR + GPIO_SET_PINS, data);
    end
endtask

task set_sensor_mode;
    input  [1:0] num_sensor;
    input  [3:0] hist_en;    // [0..3] 1 - enable histogram modules, disable after processing the started frame
    input  [3:0] hist_nrst;  // [4..7] 0 - immediately reset histogram module 
    input        chn_en;     // [8]    1 - enable sensor channel (0 - reset) 
    input        bits16;     // [9]    0 - 8 bpp mode, 1 - 16 bpp (bypass gamma). Gamma-processed data is still used for histograms
    reg    [31:0]      tmp;
    begin
        tmp= {{(32-SENSOR_MODE_WIDTH){1'b0}},func_sensor_mode(hist_en, hist_nrst, chn_en,bits16)};
        write_contol_register( SENSOR_GROUP_ADDR + num_sensor * SENSOR_BASE_INC +SENSOR_CTRL_RADDR, tmp);
    end
     
endtask
    
task set_sensor_i2c_command;
    input                             [1:0] num_sensor;
    input                                   rst_cmd;    // [14]   reset all FIFO (takes 16 clock pulses), also - stops i2c until run command
    input       [SENSI2C_CMD_RUN_PBITS : 0] run_cmd;    // [13:12]3 - run i2c, 2 - stop i2c (needed before software i2c), 1,0 - no change to run state
    input                                   set_bytes;  // [11] if 1, use bytes (below), 0 - nop
    input  [SENSI2C_CMD_BYTES_PBITS -1 : 0] bytes;      // [10:9] set command bytes to send after slave address (0..3)
    input                                   set_dly;    // [8] if 1, use dly (0 - ignore)
    input   [SENSI2C_CMD_DLY_PBITS - 1 : 0] dly;        // [7:0]  - duration of quater i2c cycle (if 0, [3:0] control SCL+SDA)
    input    [SENSI2C_CMD_SCL_WIDTH -1 : 0] scl_ctl;    // [1:0] : 0: NOP, 1: 1'b0->SCL, 2: 1'b1->SCL, 3: 1'bz -> SCL 
    input    [SENSI2C_CMD_SDA_WIDTH -1 : 0] sda_ctl;    // [3:2] : 0: NOP, 1: 1'b0->SDA, 2: 1'b1->SDA, 3: 1'bz -> SDA  

    reg                              [31:0] tmp;

    begin
        tmp= {func_sensor_i2c_command(rst_cmd, run_cmd, set_bytes, bytes, set_dly, dly, scl_ctl, sda_ctl)};
        write_contol_register( SENSOR_GROUP_ADDR + num_sensor * SENSOR_BASE_INC +SENSI2C_CTRL_RADDR, tmp);
    end
endtask


task write_sensor_i2c;
    input   [1:0] num_sensor;
    input         rel_addr; // 0 - absolute, 1 - relative
    input integer addr;
    input  [31:0] data;
    reg    [29:0] reg_addr;
    begin
        reg_addr = (SENSOR_GROUP_ADDR + num_sensor * SENSOR_BASE_INC) +
                   (rel_addr ? SENSI2C_REL_RADDR : SENSI2C_ABS_RADDR) +
                   (addr & ~SENSI2C_ADDR_MASK);
        write_contol_register(reg_addr, data);                   
    end
endtask



task    set_sensor_io_ctl;
    input                            [1:0] num_sensor;
    input                            [1:0] mrst;     // <2: keep MRST, 2 - MRST low (active),  3 - high (inactive)
    input                            [1:0] arst;     // <2: keep ARST, 2 - ARST low (active),  3 - high (inactive)
    input                            [1:0] aro;      // <2: keep ARO,  2 - set ARO (software controlled) low,  3 - set ARO  (software controlled) high
    input                            [1:0] mmcm_rst; // <2: keep MMCM reset, 2 - MMCM reset off,  3 - MMCM reset on
    input                            [1:0] clk_sel;  // <2: keep MMCM clock source, 2 - use internal pixel clock,  3 - use pixel clock from the sensor
    input                                  set_delays; // (self-clearing) load all pre-programmed delays 
    input                                  set_quadrants;  // 0 - keep quadrants settings, 1 - update quadrants
    input  [SENS_CTRL_QUADRANTS_WIDTH-1:0] quadrants;  // 90-degree shifts for data [1:0], hact [3:2] and vact [5:4]
    reg    [31:0] data;
    reg    [29:0] reg_addr;
    begin
        data = func_sensor_io_ctl (
                    mrst,
                    arst,
                    aro,
                    mmcm_rst,
                    clk_sel,
                    set_delays,
                    set_quadrants,
                    quadrants);
        reg_addr = (SENSOR_GROUP_ADDR + num_sensor * SENSOR_BASE_INC) + SENSIO_RADDR + SENSIO_CTRL;
        write_contol_register(reg_addr, data);                   
    end
endtask

task    set_sensor_io_dly;
    input                            [1:0] num_sensor;
    input [127:0] dly; // {mmsm_phase, bpf, vact, hact, pxd11,...,pxd0]
    reg    [29:0] reg_addr;
    begin
        reg_addr = (SENSOR_GROUP_ADDR + num_sensor * SENSOR_BASE_INC) + SENSIO_RADDR + SENSIO_DELAYS;
        write_contol_register(reg_addr + 0, dly[ 31: 0]); // {pxd3,       pxd2,  pxd1, pxd0}
        write_contol_register(reg_addr + 1, dly[ 63:32]); // {pxd7,       pxd6,  pxd5, pxd4}
        write_contol_register(reg_addr + 2, dly[ 95:64]); // {pxd11,      pxd10, pxd9, pxd8}
        write_contol_register(reg_addr + 3, dly[127:96]); // {mmcm_phase, bpf,   vact, hact}
        set_sensor_io_ctl(
            num_sensor,
            0, // input                            [1:0] mrst;     // <2: keep MRST, 2 - MRST low (active),  3 - high (inactive)
            0, // input                            [1:0] arst;     // <2: keep ARST, 2 - ARST low (active),  3 - high (inactive)
            0, // input                            [1:0] aro;      // <2: keep ARO,  2 - set ARO (software controlled) low,  3 - set ARO  (software controlled) high
            0, // input                            [1:0] mmcm_rst; // <2: keep MMCM reset, 2 - MMCM reset off,  3 - MMCM reset on
            0, // input                            [1:0] clk_sel;  // <2: keep MMCM clock source, 2 - use internal pixel clock,  3 - use pixel clock from the sensor
            1'b1, //input                                  set_delays; // (self-clearing) load all pre-programmed delays 
            0,   // input                                  set_quadrants;  // 0 - keep quadrants settings, 1 - update quadrants
            0); // input  [SENS_CTRL_QUADRANTS_WIDTH-1:0] quadrants;  // 90-degree shifts for data [1:0], hact [3:2] and vact [5:4]
    
    end
endtask

task    set_sensor_io_jtag; // SuppressThisWarning VEditor - may be unused
    input                            [1:0] num_sensor;
    input                            [1:0] pgmen;    // <2: keep PGMEN, 2 - PGMEN low (inactive),  3 - high (active) enable JTAG control
    input                            [1:0] prog;     // <2: keep prog, 2 - prog low (active),  3 - high (inactive) ("program" pin control)
    input                            [1:0] tck;      // <2: keep TCK,  2 - set TCK low,  3 - set TCK high
    input                            [1:0] tms;      // <2: keep TMS,  2 - set TMS low,  3 - set TMS high
    input                            [1:0] tdi;      // <2: keep TDI,  2 - set TDI low,  3 - set TDI high
    reg    [29:0] reg_addr;
    reg    [31:0] data;
    begin
        reg_addr = (SENSOR_GROUP_ADDR + num_sensor * SENSOR_BASE_INC) + SENSIO_RADDR + SENSIO_JTAG;
        data = func_sensor_jtag_ctl (
            pgmen,    // <2: keep PGMEN, 2 - PGMEN low (inactive),  3 - high (active) enable JTAG control
            prog,     // <2: keep prog, 2 - prog low (active),  3 - high (inactive) ("program" pin control)
            tck,      // <2: keep TCK,  2 - set TCK low,  3 - set TCK high
            tms,      // <2: keep TMS,  2 - set TMS low,  3 - set TMS high
            tdi);     // <2: keep TDI,  2 - set TDI low,  3 - set TDI high
        write_contol_register(reg_addr, data);
    end
endtask

task    set_sensor_io_width;
    input    [1:0] num_sensor;
    input   [15:0] width; // 0 - use HACT, >0 - generate HACT from start to specified width
    reg     [29:0] reg_addr;
    begin
        reg_addr = (SENSOR_GROUP_ADDR + num_sensor * SENSOR_BASE_INC) + SENSIO_RADDR + SENSIO_WIDTH;
        write_contol_register(reg_addr, {16'b0, width});
    end
    

endtask

task set_sensor_lens_flat_heights;
    input   [1:0] num_sensor;
    input  [15:0] height0_m1; // height of the first sub-frame minus 1
    input  [15:0] height1_m1; // height of the second sub-frame minus 1
    input  [15:0] height2_m1; // height of the third sub-frame minus 1 (no need for 4-th)
    reg    [29:0] reg_addr;
    begin
        reg_addr = (SENSOR_GROUP_ADDR + num_sensor * SENSOR_BASE_INC) + SENS_LENS_RADDR;
        write_contol_register(reg_addr, {16'b0, height0_m1});                   
        write_contol_register(reg_addr+1, {16'b0, height1_m1});                   
        write_contol_register(reg_addr+2, {16'b0, height2_m1});                   
    end
endtask

task set_sensor_lens_flat_parameters;
    input   [1:0] num_sensor;
// add mode "DIRECT", "ASAP", "RELATIVE", "ABSOLUTE" and frame number
    input  [18:0] AX;
    input  [18:0] AY;
    input  [20:0] BX;
    input  [20:0] BY;
    input  [18:0] C;
    input  [16:0] scales0;
    input  [16:0] scales1;
    input  [16:0] scales2;
    input  [16:0] scales3;
    input  [15:0] fatzero_in;
    input  [15:0] fatzero_out;
    input  [ 3:0] post_scale;
    reg    [29:0] reg_addr;
    reg    [31:0] data;
    begin
        reg_addr = (SENSOR_GROUP_ADDR + num_sensor * SENSOR_BASE_INC) + SENS_LENS_RADDR + SENS_LENS_COEFF;
        data = func_lens_data(num_sensor, SENS_LENS_AX);
        data[18:0] = AX;
        write_contol_register(reg_addr, data);                   
        data = func_lens_data(num_sensor, SENS_LENS_AY);
        data[18:0]  = AY;
        write_contol_register(reg_addr, data);                   
        data = func_lens_data(num_sensor, SENS_LENS_C);
        data[18:0]  = C;
        write_contol_register(reg_addr, data);
        data = func_lens_data(num_sensor, SENS_LENS_BX);
        data[20:0]  = BX;
        write_contol_register(reg_addr, data);                   
        data = func_lens_data(num_sensor, SENS_LENS_BY);
        data[20:0]  = BY;
        write_contol_register(reg_addr, data);                   
        data = func_lens_data(num_sensor, SENS_LENS_SCALES + 0);
        data[16:0]  = scales0;
        write_contol_register(reg_addr, data);                   
        data = func_lens_data(num_sensor, SENS_LENS_SCALES + 2);
        data[16:0]  = scales1;
        write_contol_register(reg_addr, data);                   
        data = func_lens_data(num_sensor, SENS_LENS_SCALES + 4);
        data[16:0]  = scales2;
        write_contol_register(reg_addr, data);                   
        data = func_lens_data(num_sensor, SENS_LENS_SCALES + 6);
        data[16:0]  = scales3;
        write_contol_register(reg_addr, data);                   
        data = func_lens_data(num_sensor, SENS_LENS_FAT0_IN);
        data[15:0]  = fatzero_in;
        write_contol_register(reg_addr, data);                   
        data = func_lens_data(num_sensor, SENS_LENS_FAT0_OUT);
        data[15:0]  = fatzero_out;
        write_contol_register(reg_addr, data);                   
        data = func_lens_data(num_sensor, SENS_LENS_POST_SCALE);
        data[3:0]  = post_scale;
        write_contol_register(reg_addr, data);                   
    end
endtask

function [31:0] func_lens_data;
    input   [1:0] num_sensor;
    input   [7:0] addr;
    begin
        func_lens_data = {6'b0, num_sensor, addr,16'b0};
    end
endfunction


task program_curves;
    input   [1:0] num_sensor;
    input   [1:0] sub_channel;
    reg   [9:0]   curves_data[0:1027];  // SuppressThisWarning VEditor : assigned in $readmem() system task
    integer n,i,base,diff,diff1;
//    reg [10:0] curv_diff;
    reg    [17:0] data18;
    begin
        $readmemh("input_data/linear1028rgb.dat",curves_data);
         set_sensor_gamma_table_addr (
            num_sensor,
            sub_channel,
            2'b0,         //input   [1:0] color;
            1'b0);        //input         page; // only used if SENS_GAMMA_BUFFER != 0
        
        for (n=0;n<4;n=n+1) begin
          for (i=0;i<256;i=i+1) begin
            base =curves_data[257*n+i];
            diff =curves_data[257*n+i+1]-curves_data[257*n+i];
            diff1=curves_data[257*n+i+1]-curves_data[257*n+i]+8;
    //        $display ("%x %x %x %x %x %x",n,i,curves_data[257*n+i], base, diff, diff1);
            #1;
            if ((diff>63) || (diff < -64)) data18 = {1'b1,diff1[10:4],base[9:0]};
            else                           data18 = {1'b0,diff [ 6:0],base[9:0]};
            set_sensor_gamma_table_data ( // need 256 for a single color data
                num_sensor,
                data18); // 18-bit table data
            
          end
        end  
    end
endtask


task set_sensor_gamma_table_addr;
    input   [1:0] num_sensor;
    input   [1:0] sub_channel;
    input   [1:0] color;
    input         page; // only used if SENS_GAMMA_BUFFER != 0

    reg    [31:0] data;
    reg    [29:0] reg_addr;
    
    begin
        data =      0;
        data [20] = 1'b1;
        data [7:0] = 8'b0;
        data [9:8] = color;
        if (SENS_GAMMA_BUFFER) data[12:10] = {sub_channel[1:0], page};
        else                   data[11:10] = sub_channel[1:0];

        reg_addr = (SENSOR_GROUP_ADDR + num_sensor * SENSOR_BASE_INC) + SENS_GAMMA_RADDR + SENS_GAMMA_ADDR_DATA;
        write_contol_register(reg_addr, data);                   

    end

endtask

task set_sensor_gamma_table_data; // need 256 for a single color data
    input   [1:0] num_sensor;
    input  [17:0] data18; // 18-bit table data

    reg    [29:0] reg_addr;
    
    begin
        reg_addr = (SENSOR_GROUP_ADDR + num_sensor * SENSOR_BASE_INC) + SENS_GAMMA_RADDR + SENS_GAMMA_ADDR_DATA;
        write_contol_register(reg_addr, {14'b0, data18});                   
    end

endtask

task set_sensor_gamma_heights;
    input   [1:0] num_sensor;
    input  [15:0] height0_m1; // height of the first sub-frame minus 1
    input  [15:0] height1_m1; // height of the second sub-frame minus 1
    input  [15:0] height2_m1; // height of the third sub-frame minus 1 (no need for 4-th)
    reg    [29:0] reg_addr;
    begin
        reg_addr = (SENSOR_GROUP_ADDR + num_sensor * SENSOR_BASE_INC) + SENS_GAMMA_RADDR + SENS_GAMMA_HEIGHT01;
        write_contol_register(reg_addr, {height1_m1, height0_m1});                   

        reg_addr = (SENSOR_GROUP_ADDR + num_sensor * SENSOR_BASE_INC) + SENS_GAMMA_RADDR + SENS_GAMMA_HEIGHT2;
        write_contol_register(reg_addr, {16'b0,  height2_m1});                   
    end
endtask

task set_sensor_gamma_ctl;
    input   [1:0] num_sensor; // sensor channel number (0..3)
    input   [1:0] bayer;      // bayer shift (0..3)
    input         table_page; // table page (only used if SENS_GAMMA_BUFFER)
    input         en_input;   // enable channel input
    input         repet_mode; //  Normal mode, single trigger - just for debugging
    input         trig;       // pass next frame
    
    reg    [31:0] data;
    reg    [29:0] reg_addr;

    begin
        data = func_sensor_gamma_ctl (
                    bayer,
                    table_page,
                    en_input,
                    repet_mode,
                    trig);
        reg_addr = (SENSOR_GROUP_ADDR + num_sensor * SENSOR_BASE_INC) + SENS_GAMMA_RADDR + SENS_GAMMA_CTRL;
        write_contol_register(reg_addr, data);                   
    end
    
endtask

task set_sensor_histogram_window;
    input   [1:0] num_sensor; // sensor channel number (0..3)
    input   [1:0] subchannel; // subchannel number (for multiplexed images)
    input  [15:0] left;
    input  [15:0] top;
    input  [15:0] width_m1;  // one less than window width. If 0 - use frame right margin (end of HACT)
    input  [15:0] height_m1; // one less than window height. If 0 - use frame bottom margin (end of VACT)
//    reg    [31:0] data;
    reg    [29:0] reg_addr;
    
    begin
        reg_addr = (SENSOR_GROUP_ADDR + num_sensor * SENSOR_BASE_INC); // + HISTOGRAM_LEFT_TOP;
        case (subchannel[1:0]) 
            2'h0: reg_addr = reg_addr + HISTOGRAM_RADDR0;
            2'h1: reg_addr = reg_addr + HISTOGRAM_RADDR1;
            2'h2: reg_addr = reg_addr + HISTOGRAM_RADDR2;
            2'h3: reg_addr = reg_addr + HISTOGRAM_RADDR3;
        endcase
        write_contol_register(reg_addr + HISTOGRAM_LEFT_TOP,     {top,    left});
        write_contol_register(reg_addr + HISTOGRAM_WIDTH_HEIGHT, {height_m1, width_m1});
    end
endtask

task set_sensor_histogram_saxi;
    input         en;
    input         nrst;
    input         confirm_write; // wait for the write confirmed befoer swicthing channels
    input   [3:0] cache_mode;    // default should be 4'h3
    reg    [31:0] data;
    begin
        data = 0;
        data [HIST_SAXI_EN] =     en;
        data [HIST_SAXI_NRESET] = nrst;
        data [HIST_CONFIRM_WRITE] = confirm_write;
        data [HIST_SAXI_AWCACHE +: 4] = cache_mode;
        write_contol_register(SENSOR_GROUP_ADDR + HIST_SAXI_MODE_ADDR_REL, data);
    end
endtask
    
task set_sensor_histogram_saxi_addr;
    input   [1:0] num_sensor; // sensor channel number (0..3)
    input   [1:0] subchannel; // subchannel number (for multiplexed images)
    input  [19:0] page; //start address in 4KB pages (1 page - one subchannel histogram)
    begin
        write_contol_register(SENSOR_GROUP_ADDR + HIST_SAXI_ADDR_REL + (num_sensor << 2) + subchannel,{12'b0,page});
    end
endtask
    
function [STATUS_DEPTH-1:0] func_status_addr_sensor_i2c;
    input [1:0] num_sensor;
    begin
        func_status_addr_sensor_i2c = (SENSI2C_STATUS_REG_BASE + num_sensor * SENSI2C_STATUS_REG_INC + SENSI2C_STATUS_REG_REL);
    end
endfunction

function [STATUS_DEPTH-1:0] func_status_addr_sensor_io;
    input [1:0] num_sensor;
    begin
        func_status_addr_sensor_io = (SENSI2C_STATUS_REG_BASE + num_sensor * SENSI2C_STATUS_REG_INC + SENSIO_STATUS_REG_REL);
    end
endfunction

// RTC tasks
task program_status_rtc; // set status mode, and take a time snapshot (wait response and read time)
    input [1:0] mode;
    input [5:0] seq_num;
    begin
        program_status (RTC_ADDR,
                        RTC_SET_STATUS,
                        mode,
                        seq_num);
    end
endtask


task set_rtc;
    input [31:0] sec;
    input [19:0] usec;
    input [15:0] corr;
    begin
        write_contol_register(RTC_ADDR + RTC_SET_CORR,{16'b0,corr});
        write_contol_register(RTC_ADDR + RTC_SET_USEC,{12'b0,usec});
        write_contol_register(RTC_ADDR + RTC_SET_SEC, sec);
    end
endtask

/*
function [STATUS_DEPTH-1:0] func_status_addr_rtc_status;
    begin
        func_status_addr_rtc_status = RTC_STATUS_REG_ADDR;
    end
endfunction

function [STATUS_DEPTH-1:0] func_status_addr_rtc_usec; // sec is in the next address
    begin
        func_status_addr_rtc_usec = RTC_SEC_USEC_ADDR;
    end
endfunction
*/
// camsync tasks 
task set_camsync_mode;
    input       en;             // 1 - enable, 0 - reset module
    input [1:0] en_snd;         // <2 - NOP, 2 - disable, 3 - enable sending timestamp with sync pulse
    input [1:0] en_ts_external; // <2 - NOP, 2 - local timestamp in the frame header, 3 - use external timestamp
    input [1:0] triggered_mode; // <2 - NOP, 2 - async sesnor mode, 3 - triggered sensor mode
    input [2:0] master_chn;     // <4 - NOP, 4..7 - set master channel
    input [4:0] chn_en;         // <16 - NOP, [3:0] - bit mask of enabled sensor channels
    reg    [31:0] data;
    begin
        data = 0;
        data [CAMSYNC_EN_BIT]             = en;
        data [CAMSYNC_SNDEN_BIT     -: 2] = en_snd;
        data [CAMSYNC_EXTERNAL_BIT  -: 2] = en_ts_external;
        data [CAMSYNC_TRIGGERED_BIT -: 2] = triggered_mode;
        data [CAMSYNC_MASTER_BIT    -: 3] = master_chn;
        data [CAMSYNC_CHN_EN_BIT    -: 5] = chn_en;
        write_contol_register(CAMSYNC_ADDR + CAMSYNC_MODE, data);
    end
endtask

task set_camsync_inout; // set specified input bit, keep other ones
    input         is_out;          // 0 - input selection, 1 - output selection
    input integer bit_number;      // 0..9 - bit to use
    input         active_positive; // 0 - active negative pulse, 1 - active positive pulse,
    reg    [31:0] data;
    begin
        data = {32'h00055555};
        data[2 * bit_number +: 2 ] = {1'b1, active_positive};
        if (is_out) write_contol_register(CAMSYNC_ADDR + CAMSYNC_TRIG_DST, data);
        else        write_contol_register(CAMSYNC_ADDR + CAMSYNC_TRIG_SRC, data);
    end
endtask

task reset_camsync_inout; // disable all inputs
    input         is_out;          // 0 - input selection, 1 - output selection
    begin
        if (is_out) write_contol_register(CAMSYNC_ADDR + CAMSYNC_TRIG_DST, 0);
        else        write_contol_register(CAMSYNC_ADDR + CAMSYNC_TRIG_SRC, 0);
    end
endtask

task set_camsync_period;
    input [31:0] period;          // 0 - input selection, 1 - output selection
    begin
        write_contol_register(CAMSYNC_ADDR + CAMSYNC_TRIG_PERIOD, period);
    end
endtask

task set_camsync_delay;
    input  [1:0] sub_chn;
    input [31:0] dly;          // 0 - input selection, 1 - output selection
    begin
        write_contol_register(CAMSYNC_ADDR + CAMSYNC_TRIG_DELAY0 + sub_chn, dly);
    end
endtask
// command sequencer control

// Functions used by sensor-related tasks
task ctrl_cmd_frame_sequencer;
    input [1:0] num_sensor; // sensor channel number
    input       reset;      // reset sequencer (also stops)
    input       start;      // start sequencer
    input       stop;       // stop sequencer

    reg    [31:0] data;
    reg    [29:0] reg_addr;
    begin
        reg_addr= CMDFRAMESEQ_ADDR_BASE + num_sensor * CMDFRAMESEQ_ADDR_INC + CMDFRAMESEQ_CTRL;
        data = 0;
        data [CMDFRAMESEQ_RST_BIT] = reset;
        data [CMDFRAMESEQ_RUN_BIT -:2] = {start | stop, start};
        write_contol_register(reg_addr, data);
    end
endtask

task write_cmd_frame_sequencer;
    input                  [1:0] num_sensor; // sensor channel number
    input                        relative;   // 0 - absolute (address = 0..f), 1 - relative (address= 0..e)
    input                  [3:0] frame_addr;   // frame address (relative ort absolute)
    input [AXI_WR_ADDR_BITS-1:0] addr;         // command address (register to which command should be applied)
    input                 [31:0] data;         // command data
           
    reg [29:0] reg_addr;
    begin
        if (relative && (&frame_addr)) $display("task write_cmd_frame_sequencer(): relative adderss 'hf is invalid, it is reserved for module control");
        else begin
            reg_addr = CMDFRAMESEQ_ADDR_BASE + num_sensor * CMDFRAMESEQ_ADDR_INC + (relative ? CMDFRAMESEQ_REL : CMDFRAMESEQ_ABS) + frame_addr;
            write_contol_register(reg_addr, {{32-AXI_WR_ADDR_BITS{1'b0}}, addr});
            write_contol_register(reg_addr, data);
        end
    end
endtask

function [SENSOR_MODE_WIDTH-1:0] func_sensor_mode;
    input  [3:0] hist_en;    // [0..3] 1 - enable histogram modules, disable after processing the started frame
    input  [3:0] hist_nrst;  // [4..7] 0 - immediately reset histogram module 
    input        chn_en;     // [8]    1 - enable sensor channel (0 - reset) 
    input        bits16;     // [9]    0 - 8 bpp mode, 1 - 16 bpp (bypass gamma). Gamma-processed data is still used for histograms 
    reg  [SENSOR_MODE_WIDTH-1:0] tmp;
    begin
        tmp = 0;
        tmp [SENSOR_HIST_EN_BITS +: 4] =   hist_en;
        tmp [SENSOR_HIST_NRST_BITS +: 4] = hist_nrst;
        tmp [SENSOR_CHN_EN_BIT] =          chn_en;
        tmp [SENSOR_16BIT_BIT] =           bits16;
        func_sensor_mode = tmp;
    end
endfunction


function [31 : 0] func_sensor_i2c_command;
    input                                   rst_cmd;    // [14]   reset all FIFO (takes 16 clock pulses), also - stops i2c until run command
    input       [SENSI2C_CMD_RUN_PBITS : 0] run_cmd;    // [13:12]3 - run i2c, 2 - stop i2c (needed before software i2c), 1,0 - no change to run state
    input                                   set_bytes;  // [11] if 1, use bytes (below), 0 - nop
    input  [SENSI2C_CMD_BYTES_PBITS -1 : 0] bytes;      // [10:9] set command bytes to send after slave address (0..3)
    input                                   set_dly;    // [8] if 1, use dly (0 - ignore)
    input   [SENSI2C_CMD_DLY_PBITS - 1 : 0] dly;        // [7:0]  - duration of quater i2c cycle (if 0, [3:0] control SCL+SDA)
    input    [SENSI2C_CMD_SCL_WIDTH -1 : 0] scl_ctl;    // [17:16] : 0: NOP, 1: 1'b0->SCL, 2: 1'b1->SCL, 3: 1'bz -> SCL 
    input    [SENSI2C_CMD_SDA_WIDTH -1 : 0] sda_ctl;    // [19:18] : 0: NOP, 1: 1'b0->SDA, 2: 1'b1->SDA, 3: 1'bz -> SDA  
    
    reg  [31 : 0] tmp;
    begin
        tmp = 0;
        tmp [SENSI2C_CMD_RESET] =                                 rst_cmd;
        tmp [SENSI2C_CMD_RUN  -: SENSI2C_CMD_RUN_PBITS+1] =       run_cmd;
        tmp [SENSI2C_CMD_BYTES] =                                 set_bytes;
        tmp [SENSI2C_CMD_BYTES -1 -: SENSI2C_CMD_BYTES_PBITS ] =  bytes;
        tmp [SENSI2C_CMD_DLY] =                                   set_dly;
        tmp [SENSI2C_CMD_DLY -1 -: SENSI2C_CMD_DLY_PBITS ] =      dly;
        tmp [SENSI2C_CMD_SCL +: SENSI2C_CMD_SCL_WIDTH] =          scl_ctl;
        tmp [SENSI2C_CMD_SDA +: SENSI2C_CMD_SDA_WIDTH] =          sda_ctl;

        func_sensor_i2c_command = tmp;
    end
endfunction



function                          [31 : 0] func_sensor_io_ctl;
    input                            [1:0] mrst;     // <2: keep MRST, 2 - MRST low (active),  3 - high (inactive)
    input                            [1:0] arst;     // <2: keep ARST, 2 - ARST low (active),  3 - high (inactive)
    input                            [1:0] aro;      // <2: keep ARO,  2 - set ARO (software controlled) low,  3 - set ARO  (software controlled) high
    input                            [1:0] mmcm_rst; // <2: keep MMCM reset, 2 - MMCM reset off,  3 - MMCM reset on
    input                            [1:0] clk_sel;  // <2: keep MMCM clock source, 2 - use internal pixel clock,  3 - use pixel clock from the sensor
    input                                  set_delays; // (self-clearing) load all pre-programmed delays 
    input                                  set_guadrants;  // 0 - keep quadrants settings, 1 - update quadrants
    input  [SENS_CTRL_QUADRANTS_WIDTH-1:0] quadrants;  // 90-degree shifts for data [1:0], hact [3:2] and vact [5:4]
    reg  [31 : 0] tmp;
    begin
        tmp = 0;
        
        tmp [SENS_CTRL_MRST +: 2] =                               mrst;
        tmp [SENS_CTRL_ARST +: 2] =                               arst;
        tmp [SENS_CTRL_ARO  +: 2] =                               aro;
        tmp [SENS_CTRL_RST_MMCM  +: 2] =                          mmcm_rst;
        tmp [SENS_CTRL_EXT_CLK  +: 2] =                           clk_sel;
        tmp [SENS_CTRL_LD_DLY] =                                  set_delays;
        tmp [SENS_CTRL_QUADRANTS_EN] =                            set_guadrants;
        tmp [SENS_CTRL_EXT_CLK  +: SENS_CTRL_QUADRANTS_WIDTH] =   quadrants;
        func_sensor_io_ctl = tmp;
    end
endfunction

function                          [31 : 0] func_sensor_jtag_ctl;
    input                            [1:0] pgmen;    // <2: keep PGMEN, 2 - PGMEN low (inactive),  3 - high (active) enable JTAG control
    input                            [1:0] prog;     // <2: keep prog, 2 - prog low (active),  3 - high (inactive) ("program" pin control)
    input                            [1:0] tck;      // <2: keep TCK,  2 - set TCK low,  3 - set TCK high
    input                            [1:0] tms;      // <2: keep TMS,  2 - set TMS low,  3 - set TMS high
    input                            [1:0] tdi;      // <2: keep TDI,  2 - set TDI low,  3 - set TDI high

    reg  [31 : 0] tmp;
    begin
        tmp = 0;
        
        tmp [SENS_JTAG_TDI +: 2] = pgmen;
        tmp [SENS_JTAG_TMS +: 2] = prog;
        tmp [SENS_JTAG_TCK +: 2] = tck;
        tmp [SENS_JTAG_TMS +: 2] = tms;
        tmp [SENS_JTAG_TDI +: 2] = tdi;
        func_sensor_jtag_ctl = tmp;
    end
endfunction

function  [31 : 0] func_sensor_gamma_ctl;
    input   [1:0] bayer;
    input         table_page;
    input         en_input;
    input         repet_mode; //  Normal mode, single trigger - just for debugging  TODO: re-assign?
    input         trig;
    
    reg  [31 : 0] tmp;
    begin
        tmp = 0;
        tmp[SENS_GAMMA_MODE_BAYER +: 2] = bayer;
        tmp [SENS_GAMMA_MODE_PAGE] =      table_page;
        tmp [SENS_GAMMA_MODE_EN] =        en_input;
        tmp [SENS_GAMMA_MODE_REPET] =     repet_mode;
        tmp [SENS_GAMMA_MODE_TRIG] =      trig;
        func_sensor_gamma_ctl =           tmp;
    end
endfunction

// ****************** compressor related tasks and functions *************************
task compressor_control;
    input [ 1:0] num_sensor; // sensor channel number (0..3)
    input [31:0] run_mode; // [2:0] < 0: nop, 0 - reset, 2 - run single from memory, 3 - run repetitive
    input [31:0] qbank;    // [6:3] quantization table page
    input [31:0] dc_sub;   // [8:7] subtract DC
    input [31:0] cmode;   //  [13:9] color mode:
//        parameter CMPRS_CBIT_CMODE_JPEG18 =   4'h0, // color 4:2:0
//        parameter CMPRS_CBIT_CMODE_MONO6 =    4'h1, // mono 4:2:0 (6 blocks)
//        parameter CMPRS_CBIT_CMODE_JP46 =     4'h2, // jp4, 6 blocks, original
//        parameter CMPRS_CBIT_CMODE_JP46DC =   4'h3, // jp4, 6 blocks, dc -improved
//        parameter CMPRS_CBIT_CMODE_JPEG20 =   4'h4, // mono, 4 blocks (but still not actual monochrome JPEG as the blocks are scanned in 2x2 macroblocks)
//        parameter CMPRS_CBIT_CMODE_JP4 =      4'h5, // jp4,  4 blocks, dc-improved
//        parameter CMPRS_CBIT_CMODE_JP4DC =    4'h6, // jp4,  4 blocks, dc-improved
//        parameter CMPRS_CBIT_CMODE_JP4DIFF =  4'h7, // jp4,  4 blocks, differential
//        parameter CMPRS_CBIT_CMODE_JP4DIFFHDR =  4'h8, // jp4,  4 blocks, differential, hdr
//        parameter CMPRS_CBIT_CMODE_JP4DIFFDIV2 = 4'h9, // jp4,  4 blocks, differential, divide by 2
//        parameter CMPRS_CBIT_CMODE_JP4DIFFHDRDIV2 = 4'ha, // jp4,  4 blocks, differential, hdr,divide by 2
//        parameter CMPRS_CBIT_CMODE_MONO1 =    4'hb, // mono JPEG (not yet implemented)
//        parameter CMPRS_CBIT_CMODE_MONO4 =    4'he, // mono 4 blocks
    input [31:0] multi_frame;   // [15:14] 0 - single-frame buffer, 1 - multiframe video memory buffer
    input [31:0] bayer;         // [20:18] // Bayer shift
    input [31:0] focus_mode;    // [23:21] Set focus mode
    
    reg    [31:0] data;
    reg    [29:0] reg_addr;
    begin
        data = func_compressor_control (
            run_mode,       // [2:0] < 0: nop, 0 - reset, 2 - run single from memory, 3 - run repetitive
            qbank,          // [6:3] quantization table page
            dc_sub,         // [8:7] subtract DC
            cmode,          //  [13:9] color mode:
            multi_frame,    // [15:14] 0 - single-frame buffer, 1 - multiframe video memory buffer
            bayer,          // [20:18] // Bayer shift
            focus_mode);    // [23:21] Set focus mode
        reg_addr = (CMPRS_GROUP_ADDR + num_sensor * CMPRS_BASE_INC) + CMPRS_CONTROL_REG;
        write_contol_register(reg_addr, data);                   
    end
endtask

task compressor_format;
    input [ 1:0] num_sensor; // sensor channel number (0..3)
    input [31:0] num_macro_cols_m1; // number of macroblock colums minus 1
    input [31:0] num_macro_rows_m1; // number of macroblock rows minus 1
    input [31:0] left_margin;       // left margin of the first pixel (0..31) for 32-pixel wide colums in memory access
    
    reg    [31:0] data;
    reg    [29:0] reg_addr;
    begin
        data = func_compressor_format (
            num_macro_cols_m1, // number of macroblock colums minus 1
            num_macro_rows_m1, // number of macroblock rows minus 1
            left_margin);       // left margin of the first pixel (0..31) for 32-pixel wide colums in memory access
        reg_addr = (CMPRS_GROUP_ADDR + num_sensor * CMPRS_BASE_INC) + CMPRS_FORMAT;
        write_contol_register(reg_addr, data);                   
    end
endtask

task compressor_color_saturation;
    input [ 1:0] num_sensor; // sensor channel number (0..3)
    input [31:0] colorsat_blue; //color saturation for blue (10 bits) //'h90 for 100%
    input [31:0] colorsat_red; //color saturation for red (10 bits)   // 'b6 for 100%
    
    reg    [31:0] data;
    reg    [29:0] reg_addr;
    begin
        data = func_compressor_color_saturation (
            colorsat_blue, //color saturation for blue (10 bits) //'h90 for 100%
            colorsat_red); //color saturation for red (10 bits)  // 'b6 for 100%
        reg_addr = (CMPRS_GROUP_ADDR + num_sensor * CMPRS_BASE_INC) + CMPRS_COLOR_SATURATION;
        write_contol_register(reg_addr, data);                   
    end
endtask

task compressor_coring;
    input [ 1:0] num_sensor; // sensor channel number (0..3)
    input [31:0] coring;     // coring value
    
    reg    [31:0] data;
    reg    [29:0] reg_addr;
    begin
        data = 0;
        data [CMPRS_CORING_BITS-1:0] = coring[CMPRS_CORING_BITS-1:0];
        reg_addr = (CMPRS_GROUP_ADDR + num_sensor * CMPRS_BASE_INC) + CMPRS_CORING_MODE;
        write_contol_register(reg_addr, data);                   
    end
endtask

function [31 : 0] func_compressor_control;
    // argument <0 - NOP 
    input [31:0] run_mode; // [2:0] < 0: nop, 0 - reset, 2 - run single from memory, 3 - run repetitive
    input [31:0] qbank;    // [6:3] quantization table page
    input [31:0] dc_sub;   // [8:7] subtract DC
    input [31:0] cmode;   //  [13:9] color mode:
//        parameter CMPRS_CBIT_CMODE_JPEG18 =   4'h0, // color 4:2:0
//        parameter CMPRS_CBIT_CMODE_MONO6 =    4'h1, // mono 4:2:0 (6 blocks)
//        parameter CMPRS_CBIT_CMODE_JP46 =     4'h2, // jp4, 6 blocks, original
//        parameter CMPRS_CBIT_CMODE_JP46DC =   4'h3, // jp4, 6 blocks, dc -improved
//        parameter CMPRS_CBIT_CMODE_JPEG20 =   4'h4, // mono, 4 blocks (but still not actual monochrome JPEG as the blocks are scanned in 2x2 macroblocks)
//        parameter CMPRS_CBIT_CMODE_JP4 =      4'h5, // jp4,  4 blocks, dc-improved
//        parameter CMPRS_CBIT_CMODE_JP4DC =    4'h6, // jp4,  4 blocks, dc-improved
//        parameter CMPRS_CBIT_CMODE_JP4DIFF =  4'h7, // jp4,  4 blocks, differential
//        parameter CMPRS_CBIT_CMODE_JP4DIFFHDR =  4'h8, // jp4,  4 blocks, differential, hdr
//        parameter CMPRS_CBIT_CMODE_JP4DIFFDIV2 = 4'h9, // jp4,  4 blocks, differential, divide by 2
//        parameter CMPRS_CBIT_CMODE_JP4DIFFHDRDIV2 = 4'ha, // jp4,  4 blocks, differential, hdr,divide by 2
//        parameter CMPRS_CBIT_CMODE_MONO1 =    4'hb, // mono JPEG (not yet implemented)
//        parameter CMPRS_CBIT_CMODE_MONO4 =    4'he, // mono 4 blocks
    input [31:0] multi_frame;   // [15:14] 0 - single-frame buffer, 1 - multiframe video memory buffer
    input [31:0] bayer;         // [20:18] // Bayer shift
    input [31:0] focus_mode;    // [23:21] Set focus mode
    
    reg  [31 : 0] tmp;
    begin
        tmp = 0;
        if (!run_mode[31])   tmp[CMPRS_CBIT_RUN  -:   CMPRS_CBIT_RUN_BITS + 1]   =  {1'b1, run_mode[CMPRS_CBIT_RUN_BITS - 1 : 0]};
        if (!qbank[31])      tmp[CMPRS_CBIT_QBANK -:  CMPRS_CBIT_QBANK_BITS + 1] =  {1'b1, qbank[CMPRS_CBIT_QBANK_BITS - 1 : 0]};
        if (!dc_sub[31])     tmp[CMPRS_CBIT_DCSUB -:  CMPRS_CBIT_DCSUB_BITS + 1] =  {1'b1, dc_sub[CMPRS_CBIT_DCSUB_BITS - 1 : 0]};
        if (!cmode[31])      tmp[CMPRS_CBIT_CMODE -:  CMPRS_CBIT_CMODE_BITS + 1] =  {1'b1, cmode[CMPRS_CBIT_CMODE_BITS - 1 : 0]};
        if (!multi_frame[31])tmp[CMPRS_CBIT_FRAMES -: CMPRS_CBIT_FRAMES_BITS + 1] = {1'b1, multi_frame[CMPRS_CBIT_FRAMES_BITS - 1 : 0]};
        if (!bayer[31])      tmp[CMPRS_CBIT_BAYER -:  CMPRS_CBIT_BAYER_BITS + 1] =  {1'b1, bayer[CMPRS_CBIT_BAYER_BITS - 1 : 0]};
        if (!focus_mode[31]) tmp[CMPRS_CBIT_FOCUS -:  CMPRS_CBIT_FOCUS_BITS + 1] =  {1'b1, focus_mode[CMPRS_CBIT_FOCUS_BITS - 1 : 0]};
        func_compressor_control = tmp;
    end
endfunction

function [31 : 0] func_compressor_format;
    input [31:0] num_macro_cols_m1; // number of macroblock colums minus 1
    input [31:0] num_macro_rows_m1; // number of macroblock rows minus 1
    input [31:0] left_margin;       // left margin of the first pixel (0..31) for 32-pixel wide colums in memory access
    reg  [31 : 0] tmp;
    begin
        tmp = 0;
        tmp[CMPRS_FRMT_MBCM1 +: CMPRS_FRMT_MBCM1_BITS] = num_macro_cols_m1[CMPRS_FRMT_MBCM1_BITS - 1 : 0];
        tmp[CMPRS_FRMT_MBRM1 +: CMPRS_FRMT_MBRM1_BITS] = num_macro_rows_m1[CMPRS_FRMT_MBRM1_BITS - 1 : 0];
        tmp[CMPRS_FRMT_LMARG +: CMPRS_FRMT_LMARG_BITS] = left_margin      [CMPRS_FRMT_LMARG_BITS - 1 : 0];
        func_compressor_format = tmp;
    end
endfunction

function [31 : 0] func_compressor_color_saturation;
    input [31:0] colorsat_blue; //color saturation for blue (10 bits) //'h90 for 100%
    input [31:0] colorsat_red; //color saturation for red (10 bits)   // 'b6 for 100%
    reg  [31 : 0] tmp;
    begin
        tmp = 0;
        tmp[CMPRS_CSAT_CB +: CMPRS_CSAT_CB_BITS] = colorsat_blue[CMPRS_CSAT_CB_BITS - 1 : 0];
        tmp[CMPRS_CSAT_CR +: CMPRS_CSAT_CR_BITS] = colorsat_red [CMPRS_CSAT_CR_BITS - 1 : 0];
        func_compressor_color_saturation = tmp;
    end
endfunction


`include "includes/tasks_tests_memory.vh" // SuppressThisWarning VEditor - may be unused
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

