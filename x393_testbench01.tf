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
`undef WAIT_MRS
`define SET_PER_PIN_DEALYS 1 // set individual (including per-DQ pin delays)
`define TEST_WRITE_LEVELLING 1
`define TEST_READ_PATTERN 1
`define TEST_WRITE_BLOCK 1
`define TEST_READ_BLOCK 1
`define PS_PIO_WAIT_COMPLETE 0

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
  wire AXI_RD_EMPTY=NUM_WORDS_READ==NUM_WORDS_EXPECTED; //SuppressThisWarning VEditor : may be unused, just for simulation
//  integer ii;
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
    NUM_WORDS_EXPECTED <=0;
    #99000; // same as glbl
    repeat (20) @(posedge CLK) ;
    RST <=1'b0;
//set simulation-only parameters   
    axi_set_b_lag(0); //(1);
    axi_set_rd_lag(0);
    program_status_all(DEFAULT_STATUS_MODE,'h2a); // mode auto with sequence number increment 

    enable_memcntrl(1);                 // enable memory controller

    set_up;
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
    wait_ps_pio_ready(DEFAULT_STATUS_MODE); // wait FIFO not half full 
    schedule_ps_pio ( // shedule software-control memory operation (may need to check FIFO status first)
                        INITIALIZE_OFFSET, // input [9:0] seq_addr; // sequence start address
                        0,                 // input [1:0] page;     // buffer page number
                        0,                 // input       urgent;   // high priority request (only for competion with other channels, wiil not pass in this FIFO)
                        0,                // input       chn;      // channel buffer to use: 0 - memory read, 1 - memory write
                        `PS_PIO_WAIT_COMPLETE );//  wait_complete; // Do not request a newe transaction from the scheduler until previous memory transaction is finished
                        
   
`ifdef WAIT_MRS 
    wait_ps_pio_done(DEFAULT_STATUS_MODE);
`else    
    repeat (32) @(posedge CLK) ;  // what delay is needed to be sure? Add to PS_PIO?
//    first refreshes will be fast (accummulated while waiting)
`endif    
    enable_refresh(1);
`ifdef TEST_WRITE_LEVELLING    
// Set special values for DQS idelay for write leveling
        wait_ps_pio_done(DEFAULT_STATUS_MODE); // not no interrupt running cycle - delays are changed immediately
        axi_set_dqs_idelay_wlv;
// Set write buffer (from DDR3) WE signal delay for write leveling mode
        axi_set_wbuf_delay(WBUF_DLY_WLV);
        axi_set_dqs_odelay('h80); // 'h80 - inverted, 'h60 - not - 'h80 will cause warnings during simulation
        schedule_ps_pio ( // shedule software-control memory operation (may need to check FIFO status first)
                        WRITELEV_OFFSET,   // input [9:0] seq_addr; // sequence start address
                        0,                 // input [1:0] page;     // buffer page number
                        0,                 // input       urgent;   // high priority request (only for competion with other channels, wiil not pass in this FIFO)
                        0,                // input       chn;      // channel buffer to use: 0 - memory read, 1 - memory write
                        `PS_PIO_WAIT_COMPLETE );//  wait_complete; // Do not request a newe transaction from the scheduler until previous memory transaction is finished
                        
        wait_ps_pio_done(DEFAULT_STATUS_MODE); // wait previous memory transaction finished before changing delays (effective immediately)
        read_block_buf_chn (0, 0, 32, 1 ); // chn=0, page=0, number of 32-bit words=32, wait_done
//        @ (negedge rstb);
        axi_set_dqs_odelay(DLY_DQS_ODELAY);
        schedule_ps_pio ( // shedule software-control memory operation (may need to check FIFO status first)
                        WRITELEV_OFFSET,   // input [9:0] seq_addr; // sequence start address
                        1,                 // input [1:0] page;     // buffer page number
                        0,                 // input       urgent;   // high priority request (only for competion with other channels, wiil not pass in this FIFO)
                        0,                // input       chn;      // channel buffer to use: 0 - memory read, 1 - memory write
                        `PS_PIO_WAIT_COMPLETE );//  wait_complete; // Do not request a newe transaction from the scheduler until previous memory transaction is finished
        wait_ps_pio_done(DEFAULT_STATUS_MODE); // wait previous memory transaction finished before changing delays (effective immediately)
        read_block_buf_chn (0, 1, 32, 1 ); // chn=0, page=1, number of 32-bit words=32, wait_done
//    task wait_read_queue_empty; - alternative way to check fo empty read queue
        
//        @ (negedge rstb);
        axi_set_dqs_idelay_nominal;
//        axi_set_dqs_odelay_nominal;
        axi_set_dqs_odelay('h78);
        axi_set_wbuf_delay(WBUF_DLY_DFLT);
`endif
`ifdef TEST_READ_PATTERN
        schedule_ps_pio ( // shedule software-control memory operation (may need to check FIFO status first)
                        READ_PATTERN_OFFSET,   // input [9:0] seq_addr; // sequence start address
                        2,                     // input [1:0] page;     // buffer page number
                        0,                     // input       urgent;   // high priority request (only for competion with other channels, wiil not pass in this FIFO)
                        0,                    // input       chn;      // channel buffer to use: 0 - memory read, 1 - memory write
                        `PS_PIO_WAIT_COMPLETE );//  wait_complete; // Do not request a newe transaction from the scheduler until previous memory transaction is finished
        wait_ps_pio_done(DEFAULT_STATUS_MODE); // wait previous memory transaction finished before changing delays (effective immediately)
        read_block_buf_chn (0, 2, 32, 1 ); // chn=0, page=2, number of 32-bit words=32, wait_done
`endif
`ifdef TEST_WRITE_BLOCK
//    write_block_buf_chn; // fill block memory - already set in set_up task
        schedule_ps_pio ( // shedule software-control memory operation (may need to check FIFO status first)
                        WRITE_BLOCK_OFFSET,    // input [9:0] seq_addr; // sequence start address
                        0,                     // input [1:0] page;     // buffer page number
                        0,                     // input       urgent;   // high priority request (only for competion with other channels, wiil not pass in this FIFO)
                        1,                    // input       chn;      // channel buffer to use: 0 - memory read, 1 - memory write
                        `PS_PIO_WAIT_COMPLETE );//  wait_complete; // Do not request a newe transaction from the scheduler until previous memory transaction is finished
// tempoary - for debugging:
//        wait_ps_pio_done(DEFAULT_STATUS_MODE); // wait previous memory transaction finished before changing delays (effective immediately)

`endif
`ifdef TEST_READ_BLOCK
        schedule_ps_pio ( // shedule software-control memory operation (may need to check FIFO status first)
                        READ_BLOCK_OFFSET,   // input [9:0] seq_addr; // sequence start address
                        3,                     // input [1:0] page;     // buffer page number
                        0,                     // input       urgent;   // high priority request (only for competion with other channels, wiil not pass in this FIFO)
                        0,                    // input       chn;      // channel buffer to use: 0 - memory read, 1 - memory write
                        `PS_PIO_WAIT_COMPLETE );//  wait_complete; // Do not request a newe transaction from the scheduler until previous memory transaction is finished
        schedule_ps_pio ( // shedule software-control memory operation (may need to check FIFO status first)
                        READ_BLOCK_OFFSET,   // input [9:0] seq_addr; // sequence start address
                        2,                     // input [1:0] page;     // buffer page number
                        0,                     // input       urgent;   // high priority request (only for competion with other channels, wiil not pass in this FIFO)
                        0,                    // input       chn;      // channel buffer to use: 0 - memory read, 1 - memory write
                        `PS_PIO_WAIT_COMPLETE );//  wait_complete; // Do not request a newe transaction from the scheduler until previous memory transaction is finished
        schedule_ps_pio ( // shedule software-control memory operation (may need to check FIFO status first)
                        READ_BLOCK_OFFSET,   // input [9:0] seq_addr; // sequence start address
                        1,                     // input [1:0] page;     // buffer page number
                        0,                     // input       urgent;   // high priority request (only for competion with other channels, wiil not pass in this FIFO)
                        0,                    // input       chn;      // channel buffer to use: 0 - memory read, 1 - memory write
                        `PS_PIO_WAIT_COMPLETE );//  wait_complete; // Do not request a newe transaction from the scheduler until previous memory transaction is finished
        wait_ps_pio_done(DEFAULT_STATUS_MODE); // wait previous memory transaction finished before changing delays (effective immediately)
        read_block_buf_chn (0, 3, 256, 1 ); // chn=0, page=3, number of 32-bit words=256, wait_done
`endif
  #20000;
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
            set_all_sequences;
// prepare write buffer    
            write_block_buf_chn(1,0,256); // fill block memory (channel, page, number)
// set all delays
//#axi_set_delays - from tables, per-pin
`ifdef SET_PER_PIN_DEALYS
            axi_set_delays; // set all individual delays, aslo runs axi_set_phase()
`else
            axi_set_same_delays(DLY_DQ_IDELAY,DLY_DQ_ODELAY,DLY_DQS_IDELAY,DLY_DQS_ODELAY,DLY_DM_ODELAY,DLY_CMDA_ODELAY);
// set clock phase relative to DDR clk
            axi_set_phase(DLY_PHASE);
`endif            
            
        end
    endtask

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

task enable_cmda;
   input en;
   begin
        write_contol_register(MCONTR_PHY_0BIT_ADDR +  MCONTR_PHY_0BIT_CMDA_EN + en, 0);
   end
endtask

task enable_cke;
    input en;
    begin
        write_contol_register(MCONTR_PHY_0BIT_ADDR +  MCONTR_PHY_0BIT_CKE_EN + en, 0);
    end
endtask

task activate_sdrst;
    input en;
    begin
        write_contol_register(MCONTR_PHY_0BIT_ADDR +  MCONTR_PHY_0BIT_SDRST_ACT + en, 0);
    end
endtask

task enable_refresh;
    input en;
    begin
        write_contol_register(MCONTR_TOP_0BIT_ADDR +  MCONTR_TOP_0BIT_REFRESH_EN + en, 0);
    end
endtask

task enable_memcntrl;
    input en;
    begin
        write_contol_register(MCONTR_TOP_0BIT_ADDR +  MCONTR_TOP_0BIT_MCONTR_EN + en, 0);
    end
endtask

task enable_memcntrl_channels;
    input [15:0] chnen; // bit-per-channel, 1 - enable;
    begin
        write_contol_register(MCONTR_TOP_16BIT_ADDR +  MCONTR_TOP_16BIT_CHN_EN, {16'b0,chnen});
    end
endtask

task configure_channel_priority;
    input [ 3:0] chn;
    input [15:0] priority; // (higher is more important)
    begin
        write_contol_register(MCONTR_ARBIT_ADDR + chn, {16'b0,priority});
    end
endtask

task enable_reset_ps_pio; // control reset and enable of the PS PIO channel;
    input en;
    input rst;
    begin
        write_contol_register(MCNTRL_PS_ADDR +  MCNTRL_PS_EN_RST, {30'b0,en,~rst});
    end
endtask

task schedule_ps_pio; // shedule software-control memory operation (may need to check FIFO status first)
    input [9:0] seq_addr; // sequence start address
    input [1:0] page;     // buffer page number
    input       urgent;   // high priority request (only for competion wityh other channels, wiil not pass in this FIFO)
    input       chn;      // channel buffer to use: 0 - memory read, 1 - memory write
    input       wait_complete; // Do not request a newe transaction from the scheduler until previous memory transaction is finished
    begin
//        wait_ps_pio_ready(DEFAULT_STATUS_MODE); // wait FIFO not half full 
        write_contol_register(MCNTRL_PS_ADDR + MCNTRL_PS_CMD, {17'b0,wait_complete,chn,urgent,page,seq_addr});
    end
endtask
//MCONTR_BUF1_WR_ADDR
task write_block_buf_chn;  // S uppressThisWarning VEditor : may be unused
    input integer chn; // buffer channel
    input   [1:0] page;
    input integer num_words; // number of words to write (will be rounded up to multiple of 16)
    reg    [29:0] start_addr;
    begin
        case (chn)
            1:  start_addr=MCONTR_BUF1_WR_ADDR + (page << 8);
            3:  start_addr=MCONTR_BUF3_WR_ADDR + (page << 8);
            default: begin
                $display("**** ERROR: Invalid channel for write buffer = %d @%t", chn, $time);
                start_addr = MCONTR_BUF1_WR_ADDR+ (page << 8);
            end
        endcase
        write_block_buf (start_addr, num_words);
    end
endtask

task write_block_buf;
    input [29:0] start_word_address;
    input integer num_words; // number of words to write (will be rounded up to multiple of 16)
    integer i, j;
    begin
        $display("**** write_block_buf  @%t", $time);
        for (i = 0; i < num_words; i = i + 16) begin
            axi_write_addr_data(
                i,    // id
                {start_word_address,2'b0}+( i << 2),
//                (MCONTR_BUF1_WR_ADDR + (page <<8)+ i) << 2, // addr
                i | (((i + 7) & 'hff) << 8) | (((i + 23) & 'hff) << 16) | (((i + 31) & 'hff) << 24),
                4'hf, // len
                1,    // burst type - increment
                1'b1, // data_en
                4'hf, // wstrb
                1'b0 // last
                );
            $display("+Write block data (addr:data): 0x%x:0x%08x @%t", i, i | (((i + 7) & 'hff) << 8) | (((i + 23) & 'hff) << 16) | (((i + 31) & 'hff) << 24), $time);
            for (j = 1; j < 16; j = j + 1) begin
                axi_write_data(
                    i,        // id
                    (i + j) | ((((i + j) + 7) & 'hff) << 8) | ((((i + j) + 23) & 'hff) << 16) | ((((i + j) + 31) & 'hff) << 24),
                    4'hf, // wstrb
                    (1 == 15) ? 1 : 0 // last
                    );
                $display(" Write block data (addr:data): 0x%08x:0x%x @%t", (i + j),
                    (i + j) | ((((i + j) + 7) & 'hff) << 8) | ((((i + j) + 23) & 'hff) << 16) | ((((i + j) + 31) & 'hff) << 24), $time);
            end
        end

    end
endtask
   
   // read memory
task read_block_buf_chn;  // S uppressThisWarning VEditor : may be unused
    input integer chn; // buffer channel
    input   [1:0] page;
    input integer num_read; // number of words to read (will be rounded up to multiple of 16)
    input wait_done; 
    reg    [29:0] start_addr;
    begin
        case (chn)
            0:  start_addr=MCONTR_BUF0_RD_ADDR + (page << 8);
            2:  start_addr=MCONTR_BUF2_RD_ADDR + (page << 8);
            4:  start_addr=MCONTR_BUF4_RD_ADDR + (page << 8);
            default: begin
                $display("**** ERROR: Invalid channel for read buffer = %d @%t", chn, $time);
                start_addr = 30'b0+ (page << 8);
            end
        endcase
        read_block_buf (start_addr, num_read, wait_done);
    end
endtask

task read_block_buf; 
    input [29:0] start_word_address;
    input integer num_read; // number of words to read (will be rounded up to multiple of 16)
    input wait_done; 
    integer i; //,j;
    begin
        wait (~rstb);
        SIMUL_AXI_FULL<=1'b0;
        $display("**** read_block_buf  @%t", $time);
        axi_set_rd_lag(0);
        for (i = 0; i < num_read; i = i + 16) begin
            wait(arready);
//                $display ("read_block_buf (0x%x) @%t",i,$time);
            axi_read_addr(
                i,    // id
                {start_word_address,2'b0}+( i << 2), // addr
                4'hf, // len
                1     // burst type - increment
                );
        end
        if (wait_done) begin
//            wait (AXI_RD_EMPTY);
            wait_read_queue_empty;
        end
    end
endtask


task set_read_block;
    input [ 2:0] ba;
    input [14:0] ra;
    input [ 9:0] ca;
    reg   [29:0] cmd_addr;
    reg   [31:0] data;
    integer i;
    begin
        cmd_addr <= MCONTR_CMD_WR_ADDR + READ_BLOCK_OFFSET;
// activate
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd( ra[14:0],            ba[2:0],    4,  0,  0,  0,  0,    0,    0,    0,  0,   0,   0,   0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// see if pause is needed . See when buffer read should be started - maybe before WR command
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   1,       0,           0,          0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// first read
// read
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd( {5'b0,ca[9:0]},      ba[2:0],    2,  0,  0,  1,  0,    0,    0,    1,  0,   0,   0,   0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// nop
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       0,       ba[2:0],        0,  0,  1,  0,    0,    0,    1,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
//repeat remaining reads             
        for (i=1;i<64;i=i+1) begin
// read
//                                  addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
            data <=  func_encode_cmd({5'b0,ca[9:0]}+(i<<3),ba[2:0],2,  0,  0,  1,  0,    0,    0,    1,  1,   0,   1,   0);
            @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        end
// nop - all 3 below are the same? - just repeat?
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       0,       ba[2:0],        0,  0,  1,  0,    0,    0,    1,  1,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// nop
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       0,       ba[2:0],        0,  0,  1,  0,    0,    0,    1,  1,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// nop
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       0,       ba[2:0],        0,  0,  1,  0,    0,    0,    1,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// tRTP = 4*tCK is already satisfied, no skip here
// precharge, end of a page (B_RST)         
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd( ra[14:0],            ba[2:0],    5,  0,  0,  0,  0,    0,    0,    1,  0,   0,   0,   1);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   2,       0,          0,           0,  0,  0,  0,    0,    0,    1,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// Turn off DCI, set DONE
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       1,          0,           0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
    end
endtask

task set_write_block;
    input[2:0]ba;
    input[14:0]ra;
    input[9:0]ca;
    reg[29:0] cmd_addr;
    reg[31:0] data;
    integer i;
    begin
        cmd_addr <= MCONTR_CMD_WR_ADDR + WRITE_BLOCK_OFFSET;
// activate
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd( ra[14:0],            ba[2:0],    4,  0,  0,  0,  0,    0,    0,    0,  0,   0,   0,   0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// see if pause is needed . See when buffer read should be started - maybe before WR command
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   1,       0,           0,          0,  0,  0,  0,    0,    0,    0,  0,   1,        0); // tRCD - 2 read bufs
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// first write, 3 rd_buf
// write
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd( {5'b0,ca[9:0]},      ba[2:0],    3,  1,  0,  1,  0,    0,    0,    0,  0,   1,   0,   0); // B_RD moved 1 cycle earlier 
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// nop 4-th rd_buf
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
//        data <=  func_encode_skip(   0,       0,       ba[2:0],        1,  0,  1,  1,    1,    0,    1,  0,   1,        0);
        data <=  func_encode_skip(   0,       0,       ba[2:0],        1,  0,  0,  1,    1,    0,    0,  0,   1,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
//repeat remaining writes
        for (i = 1; i < 63; i = i + 1) begin
// write
        //                                add            bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
            data <=  func_encode_cmd( {5'b0,ca[9:0]}+(i<<3),ba[2:0],3, 1,  0,  1,  1,    1,    1,    0,  0,   1,   1,   0); 
            @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        end
// One last write pair w/o buffer
        //                                add            bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
            data <=  func_encode_cmd( {5'b0,ca[9:0]}+(63<<3),ba[2:0],3,1,  0,  1,  1,    1,    1,    0,  0,   0,   1,   0); 
            @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;

// nop
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       0,       ba[2:0],        1,  0,  0,  1,    1,    1,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// nop
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       0,       ba[2:0],        1,  0,  0,  1,    1,    1,    0,  0,   0,        1); // removed B_RD 1 cycle earlier
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// nop
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       0,       ba[2:0],        1,  0,  0,  1,    1,    1,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// ODT off, it has latency
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   2,       0,       ba[2:0],        0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// precharge, ODT off
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd( ra[14:0],            ba[2:0],    5,  0,  0,  0,  0,    0,    0,    0,  0,   0,   0,   0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   2,       0,       ba[2:0],        0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// Finalize, set DONE        
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       1,          0,           0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
    end
endtask


  // Set MR3, read nrep*8 words, save to buffer (port0). No ACTIVATE/PRECHARGE are needed/allowed   
task set_read_pattern; 
    input integer nrep;
//        input [ 2:0] ba;
//        input [14:0] ra;
//        input [ 9:0] ca;
    reg[29:0] cmd_addr;
    reg[31:0] data;
    reg[17:0] mr3_norm;
    reg[17:0] mr3_patt;
    integer i;
    begin
        cmd_addr <= MCONTR_CMD_WR_ADDR + READ_PATTERN_OFFSET;
        
        mr3_norm <= ddr3_mr3(
            1'h0,     //       mpr;    // MPR mode: 0 - normal, 1 - dataflow from MPR
            2'h0);    // [1:0] mpr_rf; // MPR read function: 2'b00: predefined pattern 0101...
        mr3_patt <= ddr3_mr3(
            1'h1,     //       mpr;    // MPR mode: 0 - normal, 1 - dataflow from MPR
            2'h0);    // [1:0] mpr_rf; // MPR read function: 2'b00: predefined pattern 0101...
        @(posedge CLK);
// Set pattern mode
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd(mr3_patt[14:0],  mr3_patt[17:15], 7,  0,  0,  0,  0,    0,    0,    0,  0,   0,   0,   0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   5,       0,           0,          0,  0,  0,  0,    0,    0,    0,  0,   0,        0); // tMOD
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// first read
// read
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd(    0,                   0,       2,  0,  0,  1,  0,    0,    0,    1,  0,   0,   0,   0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// nop (combine with previous?)
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       0,          0,           0,  0,  1,  0,    0,    0,    1,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
//repeat remaining reads
        for (i = 1; i < nrep; i = i + 1) begin
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
            data <=  func_encode_cmd( 0,                  0,       2,  0,  0,  1,  0,    0,    0,    1,  1,   0,   1,   0);
            @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        end
// nop - all 3 below are the same? - just repeat?
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       0,          0,           0,  0,  1,  0,    0,    0,    1,  1,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// nop
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       0,          0,           0,  0,  1,  0,    0,    0,    1,  1,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// nop
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       0,          0,           0,  0,  1,  0,    0,    0,    1,  1,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// nop, no write buffer - next page
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       0,          0,           0,  0,  1,  0,    0,    0,    1,  0,   0,        1);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   1,       0,          0,           0,  0,  1,  0,    0,    0,    1,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// Turn off read pattern mode
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd(mr3_norm[14:0],  mr3_norm[17:15], 7,  0,  0,  0,  0,    0,    0,    1,  0,   0,   0,   0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// tMOD (keep DCI enabled)
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   5,       0,          0,           0,  0,  0,  0,    0,    0,    1,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// Turn off DCI
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       0,          0,           0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// Finalize (set DONE)
        data <=  func_encode_skip(   0,       1,          0,           0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
    end
endtask



task set_write_lev;
    input[CMD_PAUSE_BITS-1:0]nrep;
    reg[17:0] mr1_norm;
    reg[17:0] mr1_wlev;
    reg[29:0] cmd_addr;
    reg[31:0] data;
    reg[CMD_PAUSE_BITS-1:0] dqs_low_rpt;
    reg[CMD_PAUSE_BITS-1:0] nrep_minus_1;
    begin
        dqs_low_rpt <= 8;
        nrep_minus_1 <= nrep - 1;
        mr1_norm <= ddr3_mr1(
            1'h0,     //       qoff; // output enable: 0 - DQ, DQS operate in normal mode, 1 - DQ, DQS are disabled
            1'h0,     //       tdqs; // termination data strobe (for x8 devices) 0 - disabled, 1 - enabled
            3'h2,     // [2:0] rtt;  // on-die termination resistance: //  3'b010 - RZQ/2 (120 Ohm)
            1'h0,     //       wlev; // write leveling
            2'h0,     //       ods;  // output drive strength: //  2'b00 - RZQ/6 - 40 Ohm
            2'h0,     // [1:0] al;   // additive latency: 2'b00 - disabled (AL=0)
            1'b0);    //       dll;  // 0 - DLL enabled (normal), 1 - DLL disabled
        mr1_wlev <= ddr3_mr1(
            1'h0,     //       qoff; // output enable: 0 - DQ, DQS operate in normal mode, 1 - DQ, DQS are disabled
            1'h0,     //       tdqs; // termination data strobe (for x8 devices) 0 - disabled, 1 - enabled
            3'h2,     // [2:0] rtt;  // on-die termination resistance: //  3'b010 - RZQ/2 (120 Ohm)
            1'h1,     //       wlev; // write leveling
            2'h0,     //       ods;  // output drive strength: //  2'b00 - RZQ/6 - 40 Ohm
            2'h0,     // [1:0] al;   // additive latency: 2'b00 - disabled (AL=0)
            1'b0);    //       dll;  // 0 - DLL enabled (normal), 1 - DLL disabled
        cmd_addr <= MCONTR_CMD_WR_ADDR + WRITELEV_OFFSET;
// Enter write leveling mode
        @(posedge CLK)
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd(mr1_wlev[14:0],  mr1_wlev[17:15], 7,  0,  0,  0,  0,    0,    0,    0,  0,   0,   0,   0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(  13,       0,           0,          0,  0,  0,  0,    0,    0,    0,  0,   0,        0); // tWLDQSEN=25tCK
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// enable DQS output, keep it low (15 more tCK for the total of 40 tCK
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(dqs_low_rpt, 0,         0,           1,  0,  0,  0,    1,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// Toggle DQS as needed for write leveling, write to buffer
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(nrep_minus_1,0,         0,           1,  0,  0,  0,    1,    1,    1,  1,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// continue toggling (5 times), but disable writing to buffer (used same wbuf latency as for read) 
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(  4,        0,         0,            1,  0,  0,  0,    1,    1,    1,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        // Keep DCI (but not ODT) active  ODT should be off befor MRS
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(  2,        0,         0,            0,  0,  0,  0,    0,    0,    1,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        // exit write leveling mode, ODT off, DCI off
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd(mr1_norm[14:0],  mr1_norm[17:15], 7,  0,  0,  0,  0,    0,    0,    0,  0,   0,   0,   0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(  5,        0,         0,            0,  0,  0,  0,    0,    0,    0,  0,   0,        0); // tMOD
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        // Finalize. See if DONE can be combined with B_RST, if not - insert earlier
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       1,           0,          0,  0,  0,  0,    0,    0,    0,  0,   0,        1); // can DONE be combined with B_RST?
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
    end
endtask






task set_refresh;
    input[9:0]t_rfc; // =50 for tCK=2.5ns
    input[7:0]t_refi; // 48/97 for normal, 8 - for simulation
    reg[29:0] cmd_addr;
    reg[31:0] data;
    begin
        cmd_addr <= MCONTR_CMD_WR_ADDR + REFRESH_OFFSET;
        @(posedge CLK)
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd(    0,                   0,       6,  0,  0,  0,  0,    0,    0,    0,  0,   0,   0,   0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        // =50 tREFI=260 ns before next ACTIVATE or REFRESH, @2.5ns clock, @5ns cycle
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip( t_rfc,      0,           0,          0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
// Ready for normal operation
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   0,       1,           0,          0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
//            write_contol_register(DLY_SET,0);
        write_contol_register(MCONTR_TOP_16BIT_ADDR + MCONTR_TOP_16BIT_REFRESH_ADDRESS, REFRESH_OFFSET);
        write_contol_register(MCONTR_TOP_16BIT_ADDR + MCONTR_TOP_16BIT_REFRESH_PERIOD, {24'h0,t_refi});
        // enable refresh - should it be done here?
//        write_contol_register(MCONTR_PHY_0BIT_ADDR +  MCONTR_TOP_0BIT_REFRESH_EN + 1, 0);
    end
endtask         

task set_mrs; // will also calibrate ZQ
    input reset_dll;
    reg[17:0] mr0;
    reg[17:0] mr1;
    reg[17:0] mr2;
    reg[17:0] mr3;
    reg[29:0] cmd_addr;
    reg[31:0] data;
    begin
        mr0 <= ddr3_mr0(
            1'h0,      //       pd; // precharge power down 0 - dll off (slow exit), 1 - dll on (fast exit)
            3'h2,      // [2:0] wr; // write recovery (encode ceil(tWR/tCK)) // 3'b010:  6
            reset_dll, //       dll_rst; // 1 - dll reset (self clearing bit)
            4'h4,      // [3:0] cl; // CAS latency: // 0100:  6 (time 15ns)
            1'h0,      //       bt; // read burst type: 0 sequential (nibble), 1 - interleave
            2'h0);       // [1:0] bl; // burst length: // 2'b00 - fixed BL8

        mr1 <= ddr3_mr1(
            1'h0,     //       qoff; // output enable: 0 - DQ, DQS operate in normal mode, 1 - DQ, DQS are disabled
            1'h0,     //       tdqs; // termination data strobe (for x8 devices) 0 - disabled, 1 - enabled
            3'h2,     // [2:0] rtt;  // on-die termination resistance: //  3'b010 - RZQ/2 (120 Ohm)
            1'h0,     //       wlev; // write leveling
            2'h0,     //       ods;  // output drive strength: //  2'b00 - RZQ/6 - 40 Ohm
            2'h0,     // [1:0] al;   // additive latency: 2'b00 - disabled (AL=0)
            1'b0);    //       dll;  // 0 - DLL enabled (normal), 1 - DLL disabled

        mr2 <= ddr3_mr2(
            2'h0,     // [1:0] rtt_wr; // Dynamic ODT : //  2'b00 - disabled, 2'b01 - RZQ/4 = 60 Ohm, 2'b10 - RZQ/2 = 120 Ohm
            1'h0,     //       srt;    // Self-refresh temperature 0 - normal (0-85C), 1 - extended (<=95C)
            1'h0,     //       asr;    // Auto self-refresh 0 - disabled (manual), 1 - enabled (auto)
            3'h0);    // [2:0] cwl;    // CAS write latency:3'b000  5CK (tCK >= 2.5ns), 3'b001  6CK (1.875ns <= tCK < 2.5ns)

        mr3 <= ddr3_mr3(
            1'h0,     //       mpr;    // MPR mode: 0 - normal, 1 - dataflow from MPR
            2'h0);    // [1:0] mpr_rf; // MPR read function: 2'b00: predefined pattern 0101...
        cmd_addr <= MCONTR_CMD_WR_ADDR + INITIALIZE_OFFSET;
        @(posedge CLK)
        $display("mr0=0x%x", mr0);
        $display("mr1=0x%x", mr1);
        $display("mr2=0x%x", mr2);
        $display("mr3=0x%x", mr3);
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd(mr2[14:0],          mr2[17:15],   7,  0,  0,  0,  0,    0,    0,    0,  0,   0,   0,   0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(    1,      0,           0,          0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd(mr3[14:0],          mr3[17:15],   7,  0,  0,  0,  0,    0,    0,    0,  0,   0,   0,   0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(    0,      0,           0,          0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd(mr1[14:0],          mr1[17:15],   7,  0,  0,  1,  0,    0,    0,    0,  0,   0,   0,   0); // SEL==1 - just testing?
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(    2,      0,           0,          0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd(mr0[14:0],          mr0[17:15],   7,  0,  0,  0,  0,    0,    0,    0,  0,   0,   0,   0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(    5,      0,           0,          0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        // encode ZQCL:
        //                          addr                 bank     RCW ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD NOP, B_RST
        data <=  func_encode_cmd(15'h400,                 0,       1,  0,  0,  0,  0,    0,    0,    0,  0,   0,   0,   0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        // 512 clock cycles after ZQCL
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(  256,      0,           0,          0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
        // sequence done bit, skip length is ignored
        //                          skip     done        bank         ODT CKE SEL DQEN DQSEN DQSTGL DCI B_WR B_RD      B_RST
        data <=  func_encode_skip(   10,      1,           0,          0,  0,  0,  0,    0,    0,    0,  0,   0,        0);
        @(posedge CLK) axi_write_single_w(cmd_addr, data); cmd_addr <= cmd_addr + 1;
    end
endtask
/*
   function [31:0] encode_seq_skip;
        input [CMD_PAUSE_BITS-1:0] skip;
        input done;
        input dci_en;
        input odt_en;
        begin
            encode_seq_skip={
            {14-CMD_DONE_BIT{1'b0}},
            done,
            skip[CMD_PAUSE_BITS-1:0],
            3'b0, //phy_bank_in[2:0],
            3'b0, // phy_rcw_in[2:0],      // {ras,cas,we}
            odt_en, // phy_odt_in,
            1'b0, // phy_cke_in,      // may be optimized?
            1'b0, // phy_sel_in,      // first/second half-cycle, other will be nop (cke+odt applicable to both)
            1'b0, // phy_dq_en_in, //phy_dq_tri_in,   // tristate DQ  lines (internal timing sequencer for 0->1 and 1->0)
            1'b0, // phy_dqs_en_in, //phy_dqs_tri_in,  // tristate DQS lines (internal timing sequencer for 0->1 and 1->0)
            1'b0, //enable toggle DQS according to the pattern
            dci_en, // phy_dci_en_in, //phy_dci_in,      // DCI disable, both DQ and DQS lines (internal logic and timing sequencer for 0->1 and 1->0)
            1'b0, // phy_buf_wr,   // connect to external buffer (but only if not paused)
            1'b0, // phy_buf_rd,    // connect to external buffer (but only if not paused)
            1'b0, // add NOP after the current command, keep other data
            1'b0  // Reserved for future use
           };
        
        end
        
    endfunction

*/
    function [ADDRESS_NUMBER+2:0] ddr3_mr0;
        input       pd; // precharge power down 0 - dll off (slow exit), 1 - dll on (fast exit) 
        input [2:0] wr; // write recovery:
                        // 3'b000: 16
                        // 3'b001:  5
                        // 3'b010:  6
                        // 3'b011:  7
                        // 3'b100:  8
                        // 3'b101: 10
                        // 3'b110: 12
                        // 3'b111: 14
        input       dll_rst; // 1 - dll reset (self clearing bit)
        input [3:0] cl; // CAS latency (>=15ns):
                        // 0000: reserved                   
                        // 0010:  5                   
                        // 0100:  6                   
                        // 0110:  7                 
                        // 1000:  8                 
                        // 1010:  9                 
                        // 1100: 10                   
                        // 1110: 11                   
                        // 0001: 12                  
                        // 0011: 13                  
                        // 0101: 14
        input       bt; // read burst type: 0 sequential (nibble), 1 - interleaved
        input [1:0] bl; // burst length:
                        // 2'b00 - fixed BL8
                        // 2'b01 - 4 or 8 on-the-fly by A12                                     
                        // 2'b10 - fixed BL4 (chop)
                        // 2'b11 - reserved
        begin
          ddr3_mr0 = {
              3'b0,
              {ADDRESS_NUMBER-13{1'b0}},
              pd,       // MR0.12 
              wr,       // MR0.11_9
              dll_rst,  // MR0.8
              1'b0,     // MR0.7
              cl[3:1],  // MR0.6_4
              bt,       // MR0.3
              cl[0],    // MR0.2
              bl[1:0]}; // MR0.1_0
        end
    
    endfunction
    
    function [ADDRESS_NUMBER+2:0] ddr3_mr1;
        input       qoff; // output enable: 0 - DQ, DQS operate in normal mode, 1 - DQ, DQS are disabled
        input       tdqs; // termination data strobe (for x8 devices) 0 - disabled, 1 - enabled
        input [2:0] rtt;  // on-die termination resistance:
                          //  3'b000 - disabled
                          //  3'b001 - RZQ/4 (60 Ohm)
                          //  3'b010 - RZQ/2 (120 Ohm)
                          //  3'b011 - RZQ/6 (40 Ohm)
                          //  3'b100 - RZQ/12(20 Ohm)
                          //  3'b101 - RZQ/8 (30 Ohm)
                          //  3'b11x - reserved
        input       wlev; // write leveling
        input [1:0] ods;  // output drive strength:
                          //  2'b00 - RZQ/6 - 40 Ohm
                          //  2'b01 - RZQ/7 - 34 Ohm
                          //  2'b1x - reserved
        input [1:0] al;   // additive latency:
                          //  2'b00 - disabled (AL=0)
                          //  2'b01 - AL=CL-1;
                          //  2'b10 - AL=CL-2
                          //  2'b11 - reserved
        input       dll;  // 0 - DLL enabled (normal), 1 - DLL disabled
        begin
            ddr3_mr1 = {
              3'h1,
              {ADDRESS_NUMBER-13{1'b0}},
              qoff,       // MR1.12 
              tdqs,       // MR1.11
              1'b0,       // MR1.10
              rtt[2],     // MR1.9
              1'b0,       // MR1.8
              wlev,       // MR1.7 
              rtt[1],     // MR1.6 
              ods[1],     // MR1.5 
              al[1:0],    // MR1.4_3 
              rtt[0],     // MR1.2 
              ods[0],     // MR1.1 
              dll};       // MR1.0 
        end                            
    endfunction

    function [ADDRESS_NUMBER+2:0] ddr3_mr2;
        input [1:0] rtt_wr; // Dynamic ODT :
                            //  2'b00 - disabled
                            //  2'b01 - RZQ/4 = 60 Ohm
                            //  2'b10 - RZQ/2 = 120 Ohm
                            //  2'b11 - reserved
        input       srt;    // Self-refresh temperature 0 - normal (0-85C), 1 - extended (<=95C)
        input       asr;    // Auto self-refresh 0 - disabled (manual), 1 - enabled (auto)
        input [2:0] cwl;    // CAS write latency:
                            //  3'b000  5CK (           tCK >= 2.5ns)  
                            //  3'b001  6CK (1.875ns <= tCK < 2.5ns)  
                            //  3'b010  7CK (1.5ns   <= tCK < 1.875ns)  
                            //  3'b011  8CK (1.25ns  <= tCK < 1.5ns)  
                            //  3'b100  9CK (1.071ns <= tCK < 1.25ns)  
                            //  3'b101 10CK (0.938ns <= tCK < 1.071ns)  
                            //  3'b11x reserved  
        begin
            ddr3_mr2 = {
              3'h2,
              {ADDRESS_NUMBER-11{1'b0}},
              rtt_wr[1:0], // MR2.10_9
              1'b0,        // MR2.8
              srt,         // MR2.7
              asr,         // MR2.6
              cwl[2:0],    // MR2.5_3
              3'b0};       // MR2.2_0 
        end                            
    endfunction
        
    function [ADDRESS_NUMBER+2:0] ddr3_mr3;
        input       mpr;    // MPR mode: 0 - normal, 1 - dataflow from MPR
        input [1:0] mpr_rf; // MPR read function:
                            //  2'b00: predefined pattern 0101...
                            //  2'b1x, 2'bx1 - reserved
        begin
            ddr3_mr3 = {
              3'h3,
              {ADDRESS_NUMBER-3{1'b0}},
              mpr,          // MR3.2
              mpr_rf[1:0]}; // MR3.1_0 
        end                            
    endfunction

     task axi_set_same_delays;  //SuppressThisWarning VEditor : may be unused
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

    task axi_set_dqs_odelay_nominal; //SuppressThisWarning VEditor : may be unused
     begin
//        axi_set_dqs_idelay(
        write_contol_register(LD_DLY_LANE0_ODELAY + 8,      (DLY_LANE0_ODELAY >> (8<<3)) & 32'hff);
        write_contol_register(LD_DLY_LANE1_ODELAY + 8,      (DLY_LANE1_ODELAY >> (8<<3)) & 32'hff);
        write_contol_register(DLY_SET,0);
     end
    endtask

    task axi_set_dqs_idelay_nominal;  //SuppressThisWarning VEditor : may be unused
     begin
//        axi_set_dqs_idelay(
        write_contol_register(LD_DLY_LANE0_IDELAY + 8,      (DLY_LANE0_IDELAY >> (8<<3)) & 32'hff);
        write_contol_register(LD_DLY_LANE1_IDELAY + 8,      (DLY_LANE1_IDELAY >> (8<<3)) & 32'hff);
        write_contol_register(DLY_SET,0);
     end
    endtask
    
    task axi_set_dqs_idelay_wlv;  //SuppressThisWarning VEditor : may be unused
     begin
        write_contol_register(LD_DLY_LANE0_IDELAY + 8,      DLY_LANE0_DQS_WLV_IDELAY);
        write_contol_register(LD_DLY_LANE1_IDELAY + 8,      DLY_LANE1_DQS_WLV_IDELAY);
        write_contol_register(DLY_SET,0);
     end
    endtask

    task axi_set_delays; // set all individual delays
     integer i;
     begin
        for (i=0;i<10;i=i+1) begin
            write_contol_register(LD_DLY_LANE0_ODELAY + i,     (DLY_LANE0_ODELAY >> (i<<3)) & 32'hff);
        end
        for (i=0;i<9;i=i+1) begin
            write_contol_register(LD_DLY_LANE0_IDELAY + i,      (DLY_LANE0_IDELAY >> (i<<3)) & 32'hff);
        end
        for (i=0;i<10;i=i+1) begin
            write_contol_register(LD_DLY_LANE1_ODELAY + i,      (DLY_LANE1_ODELAY >> (i<<3)) & 32'hff);
        end
        for (i=0;i<9;i=i+1) begin
            write_contol_register(LD_DLY_LANE1_IDELAY + i,      (DLY_LANE1_IDELAY >> (i<<3)) & 32'hff);
        end
        for (i=0;i<32;i=i+1) begin
            write_contol_register(LD_DLY_CMDA + i,      (DLY_CMDA >> (i<<3)) & 32'hff);
        end
//        write_contol_register(DLY_SET,0);
        axi_set_phase(DLY_PHASE); // also sets all delays
     end
    endtask


    task axi_set_dq_idelay; // sets same delay to all dq idelay
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
           axi_set_multiple_delays(LD_DLY_LANE0_IDELAY + 8, 1, delay);
           axi_set_multiple_delays(LD_DLY_LANE1_IDELAY + 8, 1, delay);
           write_contol_register(DLY_SET,0); // set all delays
        end
    endtask

    task axi_set_dqs_odelay;
        input [7:0] delay;
        begin
           $display("SET DQS ODELAY=0x%x @ %t",delay,$time);
           axi_set_multiple_delays(LD_DLY_LANE0_ODELAY + 8, 1, delay);
           axi_set_multiple_delays(LD_DLY_LANE1_ODELAY + 8, 1, delay);
           write_contol_register(DLY_SET,0); // set all delays
        end
    endtask

    task axi_set_dm_odelay;
        input [7:0] delay;
        begin
           $display("SET DQM IDELAY=0x%x @ %t",delay,$time);
           axi_set_multiple_delays(LD_DLY_LANE0_ODELAY + 9, 1, delay);
           axi_set_multiple_delays(LD_DLY_LANE1_ODELAY + 9, 1, delay);
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
 
     task axi_set_wbuf_delay;
        input [3:0] delay;
        begin
            $display("SET WBUF DELAY to 0x%x @ %t",delay,$time);
            write_contol_register(MCONTR_PHY_16BIT_ADDR+MCONTR_PHY_16BIT_WBUF_DELAY, {28'h0, delay});
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
 
task wait_ps_pio_ready; // wait PS PIO module can accept comamnds (fifo half empty)
    input [1:0] mode;
    begin
        wait_status_condition (
            MCNTRL_PS_STATUS_REG_ADDR,
            MCNTRL_PS_ADDR+MCNTRL_PS_STATUS_CNTRL,
            mode,
            0,
            2 << STATUS_2LSB_SHFT,
            0);
    end
endtask
task wait_ps_pio_done; // wait PS PIO module has no pending/running memory transaction
    input [1:0] mode;
    begin
        wait_status_condition (
            MCNTRL_PS_STATUS_REG_ADDR,
            MCNTRL_PS_ADDR+MCNTRL_PS_STATUS_CNTRL,
            mode,
            0,
            3 << STATUS_2LSB_SHFT,
            0);
    end
endtask
/*
    localparam STATUS_SEQ_SHFT=           26; // bits [31:26] is the sequence number
    localparam STATUS_2LSB_SHFT=          24; // bits [25:24] get the 2 LSB of the status (transmitted with the sequence number in the second byte)
    localparam STATUS_MSB_RSHFT=           2; // status bits [25:2] are read through [23:0]
    
    localparam STATUS_PSHIFTER_RDY_MASK = 1<<STATUS_2LSB_SHFT;
    parameter MCONTR_PHY_STATUS_REG_ADDR=          'h0,//8 or less bits: status register address to use for memory controller phy
    parameter MCONTR_TOP_STATUS_REG_ADDR=          'h1,//8 or less bits: status register address to use for memory controller
    parameter MCNTRL_PS_STATUS_REG_ADDR=           'h2
    parameter MCNTRL_SCANLINE_STATUS_REG_CHN2_ADDR='h4,
    parameter MCNTRL_SCANLINE_STATUS_REG_CHN3_ADDR='h5,
    parameter MCNTRL_TILED_STATUS_REG_CHN4_ADDR=   'h6,
    parameter MCNTRL_TEST01_STATUS_REG_CHN2_ADDR=  'h3c,  // status/readback register for channel 2
    parameter MCNTRL_TEST01_STATUS_REG_CHN3_ADDR=  'h3d,  // status/readback register for channel 3
    parameter MCNTRL_TEST01_STATUS_REG_CHN4_ADDR=  'h3e  // status/readback register for channel 4    
*/ 
 
task wait_status_condition;
    input [STATUS_DEPTH-1:0] status_address;
    input [29:0] status_control_address;
    input  [1:0] status_mode;
    input [25:0] pattern;        // bits as in read registers
    input [25:0] mask;           // which bits to compare
    input        invert_match;   // 0 - wait until match to pattern (all bits), 1 - wait until no match (any of bits differ)
    reg          match;
    reg    [5:0] seq_num;
    begin
        WAITING_STATUS = 1;
        for (match=0; !match; match = invert_match ^ (((registered_rdata ^ {6'h0,pattern}) & {6'h0,mask})==0)) begin
            read_and_wait_status(status_address);
            write_contol_register(status_control_address, {24'b0,status_mode,registered_rdata[STATUS_SEQ_SHFT+:6] ^ 6'h20});
            seq_num <= registered_rdata[STATUS_SEQ_SHFT+:6] ^ 6'h20;
            read_and_wait_status(status_address);
            while (((registered_rdata[STATUS_SEQ_SHFT+:6] ^ seq_num) & 6'h30)!=0) begin // match just 2 MSBs
                read_and_wait_status(status_address);
            end
        end
        WAITING_STATUS = 0;
    end
endtask    

 task wait_phase_shifter_ready;
    begin
        WAITING_STATUS = 1;
        read_and_wait_status(MCONTR_PHY_STATUS_REG_ADDR);
        while (((registered_rdata & STATUS_PSHIFTER_RDY_MASK) == 0) || (((registered_rdata ^ {24'h0,target_phase}) & 'hff) != 0)) begin
            read_and_wait_status(MCONTR_PHY_STATUS_REG_ADDR); // exits after negedge CLK
        end
        WAITING_STATUS = 0;
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
`include "includes/x393_mcontr_encode_cmd.vh"
endmodule

