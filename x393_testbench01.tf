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
`define use200Mhz 1
`define DEBUG_FIFO 1
module  x393_testbench01 #(
`include "includes/x393_parameters.vh"
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
`include "includes/x393_localparams.vh"
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
  wire        DUMMY_TO_KEEP;  // output to keep PS7 signals from "optimization"
//  wire        MEMCLK;
  
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
  wire [ 9:0] SIMUL_AXI_ADDR_W; 
  // SuppressWarnings VEditor
  wire        SIMUL_AXI_MISMATCH;
  // SuppressWarnings VEditor
  reg  [31:0] SIMUL_AXI_READ;
  // SuppressWarnings VEditor
  reg  [ 9:0] SIMUL_AXI_ADDR;
  // SuppressWarnings VEditor
  reg         SIMUL_AXI_FULL; // some data available

  reg  [31:0] registered_rdata; // here read data from tasks goes

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
  
always #(CLKIN_PERIOD/2) CLK <= ~CLK;
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
    CLK <=1'b0;
    RST <= 1'bx;
    AR_SET_CMD_r <= 1'b0;
    AW_SET_CMD_r <= 1'b0;
    W_SET_CMD_r <= 1'b0;
    #500;
//    $display ("x393_i.ddrc_sequencer_i.phy_cmd_i.phy_top_i.rst=%d",x393_i.ddrc_sequencer_i.phy_cmd_i.phy_top_i.rst);
    #500;
    RST <= 1'b1;
    #99000; // same as glbl
    repeat (20) @(posedge CLK) ;
    RST <=1'b0;
//set simulation-only parameters   
    axi_set_b_lag(0); //(1);
    axi_set_rd_lag(0);
    program_status_all(3,'h2a); // mode auto with sequence number increment 
//...    
    set_up;
    
    read_all_status;    
    repeat (20) @(posedge CLK) ;
    read_all_status;    
  #2000;
  $finish;
end
// protect from never end
  initial begin
//  #10000000;
  #200000;
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
// Write responce
assign bvalid=                             x393_i.ps7_i.MAXIGP0BVALID;
assign x393_i.ps7_i.MAXIGP0BREADY=  bready;
assign bid=                                x393_i.ps7_i.MAXIGP0BID;
assign bresp=                              x393_i.ps7_i.MAXIGP0BRESP;

// Top module under test
    x393 #(
        .MCONTR_WR_MASK                    (MCONTR_WR_MASK),
        .MCONTR_RD_MASK                    (MCONTR_RD_MASK),
        .MCONTR_CMD_WR_ADDR                (MCONTR_CMD_WR_ADDR),
        .MCONTR_BUF0_RD_ADDR               (MCONTR_BUF0_RD_ADDR),
        .MCONTR_BUF1_WR_ADDR               (MCONTR_BUF1_WR_ADDR),
        .MCONTR_BUF2_RD_ADDR               (MCONTR_BUF2_RD_ADDR),
        .MCONTR_BUF3_WR_ADDR               (MCONTR_BUF3_WR_ADDR),
        .MCONTR_BUF4_RD_ADDR               (MCONTR_BUF4_RD_ADDR),
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
        .STATUS_ADDR                       (STATUS_ADDR),
        .STATUS_ADDR_MASK                  (STATUS_ADDR_MASK),
        .STATUS_DEPTH                      (STATUS_DEPTH),
        .AXI_WR_ADDR_BITS                  (AXI_WR_ADDR_BITS),
        .AXI_RD_ADDR_BITS                  (AXI_RD_ADDR_BITS),
        .CONTROL_ADDR                      (CONTROL_ADDR),
        .CONTROL_ADDR_MASK                 (CONTROL_ADDR_MASK),
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
        .MCNTRL_SCANLINE_CHN2_ADDR         (MCNTRL_SCANLINE_CHN2_ADDR),
        .MCNTRL_SCANLINE_CHN3_ADDR         (MCNTRL_SCANLINE_CHN3_ADDR),
        .MCNTRL_SCANLINE_MASK              (MCNTRL_SCANLINE_MASK),
        .MCNTRL_SCANLINE_MODE              (MCNTRL_SCANLINE_MODE),
        .MCNTRL_SCANLINE_STATUS_CNTRL      (MCNTRL_SCANLINE_STATUS_CNTRL),
        .MCNTRL_SCANLINE_STARTADDR         (MCNTRL_SCANLINE_STARTADDR),
        .MCNTRL_SCANLINE_FRAME_FULL_WIDTH  (MCNTRL_SCANLINE_FRAME_FULL_WIDTH),
        .MCNTRL_SCANLINE_WINDOW_WH         (MCNTRL_SCANLINE_WINDOW_WH),
        .MCNTRL_SCANLINE_WINDOW_X0Y0       (MCNTRL_SCANLINE_WINDOW_X0Y0),
        .MCNTRL_SCANLINE_WINDOW_STARTXY    (MCNTRL_SCANLINE_WINDOW_STARTXY),
        .MCNTRL_SCANLINE_STATUS_REG_CHN2_ADDR   (MCNTRL_SCANLINE_STATUS_REG_CHN2_ADDR),
        .MCNTRL_SCANLINE_STATUS_REG_CHN3_ADDR   (MCNTRL_SCANLINE_STATUS_REG_CHN3_ADDR),
        .MCNTRL_SCANLINE_PENDING_CNTR_BITS (MCNTRL_SCANLINE_PENDING_CNTR_BITS),
        .MAX_TILE_WIDTH                    (MAX_TILE_WIDTH),
        .MAX_TILE_HEIGHT                   (MAX_TILE_HEIGHT),
        .MCNTRL_TILED_CHN4_ADDR            (MCNTRL_TILED_CHN4_ADDR),
        .MCNTRL_TILED_MASK                 (MCNTRL_TILED_MASK),
        .MCNTRL_TILED_MODE                 (MCNTRL_TILED_MODE),
        .MCNTRL_TILED_STATUS_CNTRL         (MCNTRL_TILED_STATUS_CNTRL),
        .MCNTRL_TILED_STARTADDR            (MCNTRL_TILED_STARTADDR),
        .MCNTRL_TILED_FRAME_FULL_WIDTH     (MCNTRL_TILED_FRAME_FULL_WIDTH),
        .MCNTRL_TILED_WINDOW_WH            (MCNTRL_TILED_WINDOW_WH),
        .MCNTRL_TILED_WINDOW_X0Y0          (MCNTRL_TILED_WINDOW_X0Y0),
        .MCNTRL_TILED_WINDOW_STARTXY       (MCNTRL_TILED_WINDOW_STARTXY),
        .MCNTRL_TILED_TILE_WH              (MCNTRL_TILED_TILE_WH),
        .MCNTRL_TILED_STATUS_REG_CHN4_ADDR (MCNTRL_TILED_STATUS_REG_CHN4_ADDR),
        .MCNTRL_TILED_PENDING_CNTR_BITS    (MCNTRL_TILED_PENDING_CNTR_BITS),
        .MCNTRL_TILED_FRAME_PAGE_RESET     (MCNTRL_TILED_FRAME_PAGE_RESET),
        .BUFFER_DEPTH32                    (BUFFER_DEPTH32),
        .MCNTRL_TEST01_ADDR                 (MCNTRL_TEST01_ADDR),
        .MCNTRL_TEST01_MASK                 (MCNTRL_TEST01_MASK),
        .MCNTRL_TEST01_CHN2_MODE            (MCNTRL_TEST01_CHN2_MODE),
        .MCNTRL_TEST01_CHN2_STATUS_CNTRL    (MCNTRL_TEST01_CHN2_STATUS_CNTRL),
        .MCNTRL_TEST01_CHN3_MODE            (MCNTRL_TEST01_CHN3_MODE),
        .MCNTRL_TEST01_CHN3_STATUS_CNTRL    (MCNTRL_TEST01_CHN3_STATUS_CNTRL),
        .MCNTRL_TEST01_CHN4_MODE            (MCNTRL_TEST01_CHN4_MODE),
        .MCNTRL_TEST01_CHN4_STATUS_CNTRL    (MCNTRL_TEST01_CHN4_STATUS_CNTRL),
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
//      ,.MEMCLK  (MEMCLK)
    );
// Micron DDR3 memory model
    /* Instance of Micron DDR3 memory model */
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

simul_axi_read simul_axi_read_i(
  .clk(CLK),
  .reset(RST),
  .last(rlast),
  .data_stb(rstb),
  .raddr(ARADDR_IN[11:2]), 
  .rlen(ARLEN_IN),
  .rcmd(AR_SET_CMD),
  .addr_out(SIMUL_AXI_ADDR_W),
  .burst(),     // burst in progress - just debug
  .err_out());  // data last does not match predicted or FIFO over/under run - just debug
    
    //  wire [ 3:0] SIMUL_ADD_ADDR; 
    always @ (posedge CLK) begin
        if      (RST) SIMUL_AXI_FULL <=0;
        else if (rstb) SIMUL_AXI_FULL <=1;
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
/*           set_all_sequences; */
// prepare write buffer    
/*            write_block_buf; // fill block memory */
// set all delays
//#axi_set_delays - from tables, per-pin
            axi_set_same_delays(DLY_DQ_IDELAY,DLY_DQ_ODELAY,DLY_DQS_IDELAY,DLY_DQS_ODELAY,DLY_DM_ODELAY,DLY_CMDA_ODELAY);    
// set clock phase relative to DDR clk
            axi_set_phase(DLY_PHASE);
        end
    endtask

/*
task set_all_sequences;
        begin
            $display("SET MRS @ %t",$time);    
            set_mrs(1);
            $display("SET REFRESH @ %t",$time);    
            set_refresh(
                50, // input [ 9:0] t_rfc; // =50 for tCK=2.5ns
                16); //input [ 7:0] t_refi; // 48/97 for normal, 8 - for simulation
            $display("SET WRITE LEVELING @ %t",$time);    
            set_write_lev(16); // write leveling, 16 times   (full buffer - 128) 
            $display("SET READ PATTERN @ %t",$time);    
            set_read_pattern(8); // 8x2*64 bits, 32x32 bits to read

            $display("SET WRITE BLOCK @ %t",$time);    
            set_write_block(
                3'h5,     // bank
                15'h1234, // row address
                10'h100   // column address
            );
           
            $display("SET READ BLOCK @ %t",$time);    
            set_read_block(
                3'h5,     // bank
                15'h1234, // row address
                10'h100   // column address
            );
        end
endtask
*/ 
 
     task axi_set_same_delays;
        input [7:0] dq_idelay;
        input [7:0] dq_odelay;
        input [7:0] dqs_idelay;
        input [7:0] dqs_odelay;
        input [7:0] dm_odelay;
        input [7:0] cmda_odelay;
        begin
           $display("SET DELAYS(0x%x,0x%x,0x%x,0x%x,0x%x,0x%x) @ %t",
           dq_idelay,dq_odelay,dqs_idelay,dqs_odelay,dm_odelay,cmda_odelay,$time);
            axi_set_dq_idelay(dq_idelay);
            axi_set_dq_odelay(dq_odelay);
            axi_set_dqs_idelay(dqs_idelay);
            axi_set_dqs_odelay(dqs_odelay);
            axi_set_dm_odelay(dm_odelay);
            axi_set_cmda_odelay(cmda_odelay);
        end
    endtask

    task axi_set_dq_idelay;
        input [7:0] delay;
        begin
           $display("SET DQ IDELAY=0x%x @ %t",delay,$time);
           axi_set_multiple_delays(LD_DLY_LANE0_IDELAY, 8, delay);
           axi_set_multiple_delays(LD_DLY_LANE1_IDELAY, 8, delay);
           write_contol_register(DLY_SET,0); // set all delays
        end
    endtask

    task axi_set_dq_odelay;
        input [7:0] delay;
        begin
           $display("SET DQ ODELAY=0x%x @ %t",delay,$time);
           axi_set_multiple_delays(LD_DLY_LANE0_ODELAY, 8, delay);
           axi_set_multiple_delays(LD_DLY_LANE1_ODELAY, 8, delay);
           write_contol_register(DLY_SET,0); // set all delays
        end
    endtask

    task axi_set_dqs_idelay;
        input [7:0] delay;
        begin
           $display("SET DQS IDELAY=0x%x @ %t",delay,$time);
           axi_set_multiple_delays(LD_DLY_LANE0_IDELAY + 8, 0, delay);
           axi_set_multiple_delays(LD_DLY_LANE1_IDELAY + 8, 0, delay);
           write_contol_register(DLY_SET,0); // set all delays
        end
    endtask

    task axi_set_dqs_odelay;
        input [7:0] delay;
        begin
           $display("SET DQS ODELAY=0x%x @ %t",delay,$time);
           axi_set_multiple_delays(LD_DLY_LANE0_ODELAY + 8, 0, delay);
           axi_set_multiple_delays(LD_DLY_LANE1_ODELAY + 8, 0, delay);
           write_contol_register(DLY_SET,0); // set all delays
        end
    endtask

    task axi_set_dm_odelay;
        input [7:0] delay;
        begin
           $display("SET DQM IDELAY=0x%x @ %t",delay,$time);
           axi_set_multiple_delays(LD_DLY_LANE0_ODELAY + 9, 0, delay);
           axi_set_multiple_delays(LD_DLY_LANE1_ODELAY + 9, 0, delay);
           write_contol_register(DLY_SET,0); // set all delays
        end
    endtask

    task axi_set_cmda_odelay;
        input [7:0] delay;
        begin
           $display("SET COMMAND and ADDRESS ODELAY=0x%x @ %t",delay,$time);
           axi_set_multiple_delays(LD_DLY_CMDA, 32, delay);
           write_contol_register(DLY_SET,0); // set all delays
        end
    endtask


    task axi_set_multiple_delays;
        input [29:0] reg_addr;
        input integer number;
        input [7:0]  delay;
        integer i;
        begin
           for (i=0;i<number;i=i+1) begin
                write_contol_register(reg_addr + i, {24'b0,delay}); // control regiter address
           end
        end
    endtask

    task axi_set_phase;
        input [PHASE_WIDTH-1:0] phase;
        begin
            $display("SET CLOCK PHASE to 0x%x @ %t",phase,$time);
            write_contol_register(LD_DLY_PHASE, {{(32-PHASE_WIDTH){1'b0}},phase}); // control regiter address
            write_contol_register(DLY_SET,0);
            target_phase <= phase;
        end
    endtask
 
 
// set dq /dqs tristate on/off patterns
    task axi_set_tristate_patterns;
        begin
            $display("SET TRISTATE PATTERNS @ %t",$time);    
            write_contol_register(MCONTR_PHY_16BIT_ADDR +MCONTR_PHY_16BIT_PATTERNS_TRI,
                {16'h0, DQSTRI_LAST, DQSTRI_FIRST, DQTRI_LAST, DQTRI_FIRST});
        end
    endtask

 task axi_set_dqs_dqm_patterns;
        begin
            $display("SET DQS+DQM PATTERNS @ %t",$time);    
 // set patterns for DM (always 0) and DQS - always the same (may try different for write lev.)        
            write_contol_register(MCONTR_PHY_16BIT_ADDR + MCONTR_PHY_16BIT_PATTERNS,
                32'h0055);
        end
 endtask
 
 task read_all_status;
    begin
        read_and_wait_status (MCONTR_PHY_STATUS_REG_ADDR);
        read_and_wait_status (MCONTR_TOP_STATUS_REG_ADDR);
        read_and_wait_status (MCNTRL_PS_STATUS_REG_ADDR);
        read_and_wait_status (MCNTRL_SCANLINE_STATUS_REG_CHN2_ADDR);
        read_and_wait_status (MCNTRL_SCANLINE_STATUS_REG_CHN3_ADDR);
        read_and_wait_status (MCNTRL_TILED_STATUS_REG_CHN4_ADDR);
        read_and_wait_status (MCNTRL_TEST01_STATUS_REG_CHN2_ADDR);
        read_and_wait_status (MCNTRL_TEST01_STATUS_REG_CHN3_ADDR);
        read_and_wait_status (MCNTRL_TEST01_STATUS_REG_CHN4_ADDR);
    end
 endtask 
  
 task read_and_wait_status;
    input [STATUS_DEPTH-1:0] address;
    begin
        read_and_wait_w(STATUS_ADDR + address ); // Will set:       registered_rdata <= rdata;
    end
 endtask
  
  
 task program_status_all;
    input [1:0] mode;
    input [5:0] seq_num;
    begin
        program_status (MCONTR_PHY_16BIT_ADDR,     MCONTR_PHY_STATUS_CNTRL,        mode,seq_num); //MCONTR_PHY_STATUS_REG_ADDR=          'h0,
        program_status (MCONTR_TOP_16BIT_ADDR,     MCONTR_TOP_16BIT_STATUS_CNTRL,  mode,seq_num); //MCONTR_TOP_STATUS_REG_ADDR=          'h1,
        program_status (MCNTRL_PS_ADDR,            MCNTRL_PS_STATUS_CNTRL,         mode,seq_num); //MCNTRL_PS_STATUS_REG_ADDR=           'h2,
        program_status (MCNTRL_SCANLINE_CHN2_ADDR, MCNTRL_SCANLINE_STATUS_CNTRL,   mode,seq_num); //MCNTRL_SCANLINE_STATUS_REG_CHN2_ADDR='h4,
        program_status (MCNTRL_SCANLINE_CHN3_ADDR, MCNTRL_SCANLINE_STATUS_CNTRL,   mode,seq_num); //MCNTRL_SCANLINE_STATUS_REG_CHN3_ADDR='h5,
        program_status (MCNTRL_TILED_CHN4_ADDR,    MCNTRL_TILED_STATUS_CNTRL,      mode,seq_num); //MCNTRL_TILED_STATUS_REG_CHN4_ADDR=   'h6,
        program_status (MCNTRL_TEST01_ADDR,        MCNTRL_TEST01_CHN2_STATUS_CNTRL,mode,seq_num); //MCNTRL_TEST01_STATUS_REG_CHN2_ADDR=  'h3c,
        program_status (MCNTRL_TEST01_ADDR,        MCNTRL_TEST01_CHN3_STATUS_CNTRL,mode,seq_num); //MCNTRL_TEST01_STATUS_REG_CHN3_ADDR=  'h3d,
        program_status (MCNTRL_TEST01_ADDR,        MCNTRL_TEST01_CHN4_STATUS_CNTRL,mode,seq_num); //MCNTRL_TEST01_STATUS_REG_CHN4_ADDR=  'h3e,
    end
 endtask
  
 task   program_status;
    input [29:0] base_addr;
    input  [7:0] reg_addr;
    input  [1:0] mode;
 // mode bits:
 // 0 disable status generation,
 // 1 single status request,
 // 2 - auto status, keep specified seq number,
 // 3 - auto, inc sequence number 
    input  [5:0] seq_number;
    begin
//        axi_write_single_w(CONTROL_ADDR+base_addr+reg_addr, {24'b0,mode,seq_number});
        write_contol_register(base_addr + reg_addr, {24'b0,mode,seq_number});
    end
 endtask   
    
 task   write_contol_register;
    input [29:0] reg_addr;
//    input [29:0] base_addr;
//    input  [7:0] reg_addr;
    input [31:0] data;
    begin
//        axi_write_single_w(CONTROL_ADDR+base_addr+reg_addr, data);
        axi_write_single_w(CONTROL_ADDR+reg_addr, data);
    end
 endtask   
  
`include "includes/x393_tasks01.vh"

endmodule

