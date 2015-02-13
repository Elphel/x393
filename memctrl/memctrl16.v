/*******************************************************************************
 * Module: memctrl16
 * Date:2015-01-10  
 * Author: andrey     
 * Description: 16-channel memory controller
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * memctrl16.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  memctrl16.v is distributed in the hope that it will be useful,
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
module  memctrl16 #(
//command interface parameters
    parameter DLY_LD =            'h080,  // address to generate delay load
    parameter DLY_LD_MASK =       'h380,  // address mask to generate delay load
//0x1000..103f - 0- bit data (set/reset)
    parameter MCONTR_PHY_0BIT_ADDR =           'h020,  // address to set sequnecer channel and  run (4 LSB-s - channel)
    parameter MCONTR_PHY_0BIT_ADDR_MASK =      'h3f0,  // address mask to generate sequencer channel/run
//  0x1020       - DLY_SET      // 0 bits -set pre-programmed delays 
//  0x1024..1025 - CMDA_EN      // 0 bits - enable/disable command/address outputs 
//  0x1026..1027 - SDRST_ACT    // 0 bits - enable/disable active-low reset signal to DDR3 memory
//  0x1028..1029 - CKE_EN       // 0 bits - enable/disable CKE signal to memory 
//  0x102a..102b - DCI_RST      // 0 bits - enable/disable CKE signal to memory 
//  0x102c..102d - DLY_RST      // 0 bits - enable/disable CKE signal to memory 
    parameter MCONTR_PHY_0BIT_DLY_SET =        'h0,    // set pre-programmed delays 
    parameter MCONTR_PHY_0BIT_CMDA_EN =        'h4,    // enable/disable command/address outputs 
    parameter MCONTR_PHY_0BIT_SDRST_ACT =      'h6,    // enable/disable active-low reset signal to DDR3 memory
    parameter MCONTR_PHY_0BIT_CKE_EN =         'h8,    // enable/disable CKE signal to memory 
    parameter MCONTR_PHY_0BIT_DCI_RST =        'ha,    // enable/disable CKE signal to memory 
    parameter MCONTR_PHY_0BIT_DLY_RST =        'hc,    // enable/disable CKE signal to memory
//0x1030..1037 - 0-bit memory cotroller (set/reset)
    parameter MCONTR_TOP_0BIT_ADDR =           'h030,  // address to turn on/off memory controller features
    parameter MCONTR_TOP_0BIT_ADDR_MASK =      'h3f8,  // address mask to generate sequencer channel/run
//  0x1030..1031 - MCONTR_EN  // 0 bits, disable/enable memory controller
//  0x1032..1033 - REFRESH_EN // 0 bits, disable/enable memory refresh
//  0x1034..1037 - reserved
    parameter MCONTR_TOP_0BIT_MCONTR_EN =      'h0,    // set pre-programmed delays 
    parameter MCONTR_TOP_0BIT_REFRESH_EN =     'h2,    // disable/enable command/address outputs 
//0x1040..107f - 16-bit data
//  0x1040..104f - RUN_CHN      // address to set sequncer channel and  run (4 LSB-s - channel) - bits? 
//    parameter RUN_CHN_REL =           'h040,  // address to set sequnecer channel and  run (4 LSB-s - channel)
//   parameter RUN_CHN_REL_MASK =      'h3f0,  // address mask to generate sequencer channel/run
//  0x1050..1057: MCONTR_PHY16
    parameter MCONTR_PHY_16BIT_ADDR =           'h050,  // address to set sequnecer channel and  run (4 LSB-s - channel)
    parameter MCONTR_PHY_16BIT_ADDR_MASK =      'h3f8,  // address mask to generate sequencer channel/run
//  0x1050       - PATTERNS     // 16 bits
//  0x1051       - PATTERNS_TRI // 16-bit address to set DQM and DQS tristate on/off patterns {dqs_off,dqs_on, dq_off,dq_on} - 4 bits each 
//  0x1052       - WBUF_DELAY   // 4 bits - extra delay (in mclk cycles) to add to write buffer enable (DDR3 read data)
//  0x1053       - EXTRA_REL    // 1 bit - set extra parameters (currently just inv_clk_div)
//  0x1054       - STATUS_CNTRL // 8 bits - write to status control
    parameter MCONTR_PHY_16BIT_PATTERNS =       'h0,    // set DQM and DQS patterns (16'h0055)
    parameter MCONTR_PHY_16BIT_PATTERNS_TRI =   'h1,    // 16-bit address to set DQM and DQS tristate on/off patterns {dqs_off,dqs_on, dq_off,dq_on} - 4 bits each 
    parameter MCONTR_PHY_16BIT_WBUF_DELAY =     'h2,    // 4? bits - extra delay (in mclk cycles) to add to write buffer enable (DDR3 read data)
    parameter MCONTR_PHY_16BIT_EXTRA =          'h3,    // ? bits - set extra parameters (currently just inv_clk_div)
    parameter MCONTR_PHY_STATUS_CNTRL =         'h4,    // write to status control (8-bit)
   
//0x1060..106f: arbiter priority data
    parameter MCONTR_ARBIT_ADDR =               'h060,   // Address to set channel priorities
    parameter MCONTR_ARBIT_ADDR_MASK =          'h3f0,   // Address mask to set channel priorities
//0x1070..1077 - 16-bit top memory controller:
    parameter MCONTR_TOP_16BIT_ADDR =           'h070,  // address to set mcontr top control registers
    parameter MCONTR_TOP_16BIT_ADDR_MASK =      'h3f8,  // address mask to set mcontr top control registers
//  0x1070       - MCONTR_CHN_EN     // 16 bits per-channel enable (want/need requests)
//  0x1071       - REFRESH_PERIOD    // 8-bit refresh period
//  0x1072       - REFRESH_ADDRESS   // 10 bits
//  0x1073       - STATUS_CNTRL      // 8 bits - write to status control (and debug?)
    parameter MCONTR_TOP_16BIT_CHN_EN =         'h0,    // 16 bits per-channel enable (want/need requests)
    parameter MCONTR_TOP_16BIT_REFRESH_PERIOD = 'h1,    // 8-bit refresh period
    parameter MCONTR_TOP_16BIT_REFRESH_ADDRESS= 'h2,    // 10 bits refresh address in the sequencer (PL) memory
    parameter MCONTR_TOP_16BIT_STATUS_CNTRL=    'h3,    // 8 bits - write to status control (and debug?)
    
// Status read address
    parameter MCONTR_PHY_STATUS_REG_ADDR=      'h0,    // 8 or less bits: status register address to use for memory controller phy
    parameter MCONTR_TOP_STATUS_REG_ADDR=      'h1,    // 8 or less bits: status register address to use for memory controller
    
    
    parameter CHNBUF_READ_LATENCY =             1,     // external channel buffer extra read latency ( 0 - data available next cycle after re (but prev. data))
    
    parameter DFLT_DQS_PATTERN=        8'h55,
    parameter DFLT_DQM_PATTERN=        8'h00, // 8'h00
    parameter DFLT_DQ_TRI_ON_PATTERN=  4'h7,  // DQ tri-state control word, first when enabling output
    parameter DFLT_DQ_TRI_OFF_PATTERN= 4'he,  // DQ tri-state control word, first after disabling output
    parameter DFLT_DQS_TRI_ON_PATTERN= 4'h3,  // DQS tri-state control word, first when enabling output
    parameter DFLT_DQS_TRI_OFF_PATTERN=4'hc,  // DQS tri-state control word, first after disabling output
    parameter DFLT_WBUF_DELAY=         4'h6,  // write levelling - 7!
    parameter DFLT_INV_CLK_DIV=        1'b0,
    
    parameter DFLT_CHN_EN=            16'h0,  // channel mask to be enabled at reset
    parameter DFLT_REFRESH_ADDR=      10'h0,  // refresh sequence address in command memory
    parameter DFLT_REFRESH_PERIOD=     8'h0,  // default 8-bit refresh period (scale?)


    parameter integer ADDRESS_NUMBER=15, 
    parameter PHASE_WIDTH =     8,
    parameter SLEW_DQ =         "SLOW",
    parameter SLEW_DQS =        "SLOW",
    parameter SLEW_CMDA =       "SLOW",
    parameter SLEW_CLK =        "SLOW",
    parameter IBUF_LOW_PWR =    "TRUE",
`ifdef use200Mhz
    parameter real REFCLK_FREQUENCY = 200.0, // 300.0,
    parameter HIGH_PERFORMANCE_MODE = "FALSE",
    parameter CLKIN_PERIOD          = 20, // 10, //ns >1.25, 600<Fvco<1200 // Hardware 150MHz , change to             | 6.667
    parameter CLKFBOUT_MULT =       16,   // 8, // Fvco=Fclkin*CLKFBOUT_MULT_F/DIVCLK_DIVIDE, Fout=Fvco/CLKOUT#_DIVIDE  | 16
    parameter CLKFBOUT_MULT_REF =   16,   // 18,   // 9, // Fvco=Fclkin*CLKFBOUT_MULT_F/DIVCLK_DIVIDE, Fout=Fvco/CLKOUT#_DIVIDE  | 6
    parameter CLKFBOUT_DIV_REF =    4, // 200Mhz 3, // To get 300MHz for the reference clock
`else
    parameter real REFCLK_FREQUENCY = 300.0,
    parameter HIGH_PERFORMANCE_MODE = "FALSE",
    parameter CLKIN_PERIOD          = 10, //ns >1.25, 600<Fvco<1200
    parameter CLKFBOUT_MULT =       8, // Fvco=Fclkin*CLKFBOUT_MULT_F/DIVCLK_DIVIDE, Fout=Fvco/CLKOUT#_DIVIDE
    parameter CLKFBOUT_MULT_REF =   9, // Fvco=Fclkin*CLKFBOUT_MULT_F/DIVCLK_DIVIDE, Fout=Fvco/CLKOUT#_DIVIDE
    parameter CLKFBOUT_DIV_REF =    3, // To get 300MHz for the reference clock
`endif    
    parameter DIVCLK_DIVIDE=        1,
    parameter CLKFBOUT_PHASE =      0.000,
    parameter SDCLK_PHASE =         0.000,
    parameter CLK_PHASE =           0.000,
    parameter CLK_DIV_PHASE =       0.000,
    parameter MCLK_PHASE =          90.000,
    parameter REF_JITTER1 =         0.010,
    parameter SS_EN =              "FALSE",
    parameter SS_MODE =      "CENTER_HIGH",
    parameter SS_MOD_PERIOD =       10000,
    parameter CMD_PAUSE_BITS=       10,
    parameter CMD_DONE_BIT=         10
    ) (
    input                        rst_in,
    input                        clk_in,
    output                       mclk,     // global clock, half DDR3 clock, synchronizes all I/O thorough the command port
    // programming interface
    input                  [7:0] cmd_ad,      // byte-serial command address/data (up to 6 bytes: AL-AH-D0-D1-D2-D3 
    input                        cmd_stb,     // strobe (with first byte) for the command a/d
    output                 [7:0] status_ad,   // status address/data - up to 5 bytes: A - {seq,status[1:0]} - status[2:9] - status[10:17] - status[18:25]
    output                       status_rq,   // input request to send status downstream
    input                        status_start, // Acknowledge of the first status packet byte (address)
    
// command port 0 (filled by software - 32w->32r) - used for mode set, refresh, write levelling, ...
    input                        cmd0_clk,    // clock to write commend sequencer from PS
    input                        cmd0_we,     // write enble to write commend sequencer from PS
    input                [9:0]   cmd0_addr,   // address write commend sequencer from PS
    input               [31:0]   cmd0_data,   // data to write commend sequencer from PS
    
// channel interfaces TODO: move request/grant here, add "done"
// channel 0 interface 
`ifdef def_enable_mem_chn0
    input                        want_rq0,   // both want_rq and need_rq should go inactive after being granted  
    input                        need_rq0,   // want_rq should be active when need_rq is.
    output reg                   channel_pgm_en0, // channel can program sequence data
    input                 [31:0] seq_data0,  //16x32 data to be written to the sequencer (and start address for software-based sequencer)
    input                        seq_wr0,    // strobe for writing sequencer data (address is autoincremented)
    input                        seq_set0,   // channel sequencer data is written. If no seq_wr pulses before seq_set, seq_data contains software sequencer start address
    output                       seq_done0,  // sequencer finished executing sequence for this channel 
    output                       rpage_nxt_chn0,
    output                       buf_run0,   // external buffer run (may be used to force page) @posedge for write memory write channels, @negedge for read
  `ifdef def_read_mem_chn0
    output                       buf_wr_chn0,   // @ negedge mclk
    output                       buf_wpage_nxt_chn0, // @ negedge mclk
    output                [63:0] buf_wdata_chn0, // @ negedge mclk
  `else
    output                       buf_rd_chn0,
    input                 [63:0] buf_rdata_chn0,
  `endif
`endif    

// channel 1 interface 
`ifdef def_enable_mem_chn1
    input                        want_rq1,   // both want_rq and need_rq should go inactive after being granted  
    input                        need_rq1,
    output reg                   channel_pgm_en1, // channel can program sequence data
    input                 [31:0] seq_data1,  //16x32 data to be written to the sequencer (and start address for software-based sequencer)
    input                        seq_wr1,    // strobe for writing sequencer data (address is autoincremented)
    input                        seq_set1,   // channel sequencer data is written. If no seq_wr pulses before seq_set, seq_data contains software sequencer start address
    output                       seq_done1,  // sequencer finished executing sequence for this channel 
    output                       rpage_nxt_chn1,
    output                       buf_run1,   // external buffer run (may be used to force page) @posedge for write memory write channels, @negedge for read
  `ifdef def_read_mem_chn1
    output                       buf_wr_chn1,   // @ negedge mclk
    output                       buf_wpage_nxt_chn1,// @ negedge mclk
    output                [63:0] buf_wdata_chn1,// @ negedge mclk
  `else
    output                       buf_rd_chn1,
    input                 [63:0] buf_rdata_chn1,
  `endif
`endif    
    
// channel 2 interface 
`ifdef def_enable_mem_chn2
    input                        want_rq2,   // both want_rq and need_rq should go inactive after being granted  
    input                        need_rq2,
    output reg                   channel_pgm_en2, // channel can program sequence data
    input                 [31:0] seq_data2,  //16x32 data to be written to the sequencer (and start address for software-based sequencer)
    input                        seq_wr2,    // strobe for writing sequencer data (address is autoincremented)
    input                        seq_set2,  // channel sequencer data is written. If no seq_wr pulses before seq_set, seq_data contains software sequencer start address
    output                       seq_done2,  // sequencer finished executing sequence for this channel 
    output                       rpage_nxt_chn2,
    output                       buf_run2,   // external buffer run (may be used to force page) @posedge for write memory write channels, @negedge for read
  `ifdef def_read_mem_chn2
    output                       buf_wr_chn2,
    output                       buf_wpage_nxt_chn2,
    output                [63:0] buf_wdata_chn2,
  `else
    output                       buf_rd_chn2,
    input                 [63:0] buf_rdata_chn2,
  `endif
`endif    

// channel 3 interface 
`ifdef def_enable_mem_chn3
    input                        want_rq3,   // both want_rq and need_rq should go inactive after being granted  
    input                        need_rq3,
    output reg                   channel_pgm_en3, // channel can program sequence data
    input                 [31:0] seq_data3,  //16x32 data to be written to the sequencer (and start address for software-based sequencer)
    input                        seq_wr3,    // strobe for writing sequencer data (address is autoincremented)
    input                        seq_set3,  // channel sequencer data is written. If no seq_wr pulses before seq_set, seq_data contains software sequencer start address
    output                       seq_done3,  // sequencer finished executing sequence for this channel 
    output                       rpage_nxt_chn3,
    output                       buf_run3,   // external buffer run (may be used to force page) @posedge for write memory write channels, @negedge for read
  `ifdef def_read_mem_chn3
    output                       buf_wr_chn3,
    output                       buf_wpage_nxt_chn3,
    output                [63:0] buf_wdata_chn3,
  `else
    output                       buf_rd_chn3,
    input                 [63:0] buf_rdata_chn3,
  `endif
`endif    

// channel 4 interface 
`ifdef def_enable_mem_chn4
    input                        want_rq4,   // both want_rq and need_rq should go inactive after being granted  
    input                        need_rq4,
    output reg                   channel_pgm_en4, // channel can program sequence data
    input                 [31:0] seq_data4,  //16x32 data to be written to the sequencer (and start address for software-based sequencer)
    input                        seq_wr4,    // strobe for writing sequencer data (address is autoincremented)
    input                        seq_set4,  // channel sequencer data is written. If no seq_wr pulses before seq_set, seq_data contains software sequencer start address
    output                       seq_done4,  // sequencer finished executing sequence for this channel 
    output                       rpage_nxt_chn4,
    output                       buf_run4,   // external buffer run (may be used to force page) @posedge for write memory write channels, @negedge for read
  `ifdef def_read_mem_chn4
    output                       buf_wr_chn4,   // @ negedge mclk
    output                       buf_wpage_nxt_chn4,   // @ negedge mclk
    output                [63:0] buf_wdata_chn4,   // @ negedge mclk
  `else
    output                       buf_rd_chn4,
    input                 [63:0] buf_rdata_chn4,
  `endif
`endif    

// channel 5 interface 
`ifdef def_enable_mem_chn5
    input                        want_rq5,   // both want_rq and need_rq should go inactive after being granted  
    input                        need_rq5,
    output reg                   channel_pgm_en5, // channel can program sequence data
    input                 [31:0] seq_data5,  //16x32 data to be written to the sequencer (and start address for software-based sequencer)
    input                        seq_wr5,    // strobe for writing sequencer data (address is autoincremented)
    input                        seq_set5,  // channel sequencer data is written. If no seq_wr pulses before seq_set, seq_data contains software sequencer start address
    output                       seq_done5,  // sequencer finished executing sequence for this channel 
    output                       rpage_nxt_chn5,
    output                       buf_run5,   // external buffer run (may be used to force page) @posedge for write memory write channels, @negedge for read
  `ifdef def_read_mem_chn5
    output                       buf_wr_chn5,   // @ negedge mclk
    output                       buf_wpage_nxt_chn5,   // @ negedge mclk
    output                [63:0] buf_wdata_chn5,   // @ negedge mclk
  `else
    output                       buf_rd_chn5,
    input                 [63:0] buf_rdata_chn5,
  `endif
`endif    

// channel 6 interface 
`ifdef def_enable_mem_chn6
    input                        want_rq6,   // both want_rq and need_rq should go inactive after being granted  
    input                        need_rq6,
    output reg                   channel_pgm_en6, // channel can program sequence data
    input                 [31:0] seq_data6,  //16x32 data to be written to the sequencer (and start address for software-based sequencer)
    input                        seq_wr6,    // strobe for writing sequencer data (address is autoincremented)
    input                        seq_set6,  // channel sequencer data is written. If no seq_wr pulses before seq_set, seq_data contains software sequencer start address
    output                       seq_done6,  // sequencer finished executing sequence for this channel 
    output                       rpage_nxt_chn6,
    output                       buf_run6,   // external buffer run (may be used to force page) @posedge for write memory write channels, @negedge for read
  `ifdef def_read_mem_chn6
    output                       buf_wr_chn6,   // @ negedge mclk
    output                       buf_wpage_nxt_chn6,   // @ negedge mclk
    output                [63:0] buf_wdata_chn6,   // @ negedge mclk
  `else
    output                       buf_rd_chn6,
    input                 [63:0] buf_rdata_chn6,
  `endif
`endif    

// channel 7 interface 
`ifdef def_enable_mem_chn7
    input                        want_rq7,   // both want_rq and need_rq should go inactive after being granted  
    input                        need_rq7,
    output reg                   channel_pgm_en7, // channel can program sequence data
    input                 [31:0] seq_data7,  //16x32 data to be written to the sequencer (and start address for software-based sequencer)
    input                        seq_wr7,    // strobe for writing sequencer data (address is autoincremented)
    input                        seq_set7,  // channel sequencer data is written. If no seq_wr pulses before seq_set, seq_data contains software sequencer start address
    output                       seq_done7,  // sequencer finished executing sequence for this channel 
    output                       rpage_nxt_chn7,
    output                       buf_run7,   // external buffer run (may be used to force page) @posedge for write memory write channels, @negedge for read
  `ifdef def_read_mem_chn7
    output                       buf_wr_chn7,   // @ negedge mclk
    output                       buf_wpage_nxt_chn7,   // @ negedge mclk
    output                [63:0] buf_wdata_chn7,   // @ negedge mclk
  `else
    output                       buf_rd_chn7,
    input                 [63:0] buf_rdata_chn7,
  `endif
`endif    

// channel 8 interface 
`ifdef def_enable_mem_chn8
    input                        want_rq8,   // both want_rq and need_rq should go inactive after being granted  
    input                        need_rq8,
    output reg                   channel_pgm_en8, // channel can program sequence data
    input                 [31:0] seq_data8,  //16x32 data to be written to the sequencer (and start address for software-based sequencer)
    input                        seq_wr8,    // strobe for writing sequencer data (address is autoincremented)
    input                        seq_set8,  // channel sequencer data is written. If no seq_wr pulses before seq_set, seq_data contains software sequencer start address
    output                       seq_done8,  // sequencer finished executing sequence for this channel 
    output                       rpage_nxt_chn8,
    output                       buf_run8,   // external buffer run (may be used to force page) @posedge for write memory write channels, @negedge for read
  `ifdef def_read_mem_chn8
    output                       buf_wr_chn8,   // @ negedge mclk
    output                       buf_wpage_nxt_chn8,   // @ negedge mclk
    output                [63:0] buf_wdata_chn8,   // @ negedge mclk
  `else
    output                       buf_rd_chn8,
    input                 [63:0] buf_rdata_chn8,
  `endif
`endif    

// channel 9 interface 
`ifdef def_enable_mem_chn9
    input                        want_rq9,   // both want_rq and need_rq should go inactive after being granted  
    input                        need_rq9,
    output reg                   channel_pgm_en9, // channel can program sequence data
    input                 [31:0] seq_data9,  //16x32 data to be written to the sequencer (and start address for software-based sequencer)
    input                        seq_wr9,    // strobe for writing sequencer data (address is autoincremented)
    input                        seq_set9,  // channel sequencer data is written. If no seq_wr pulses before seq_set, seq_data contains software sequencer start address
    output                       seq_done9,  // sequencer finished executing sequence for this channel 
    output                       rpage_nxt_chn9,
    output                       buf_run9,   // external buffer run (may be used to force page) @posedge for write memory write channels, @negedge for read
  `ifdef def_read_mem_chn9
    output                       buf_wr_chn9,   // @ negedge mclk
    output                       buf_wpage_nxt_chn9,   // @ negedge mclk
    output                [63:0] buf_wdata_chn9,   // @ negedge mclk
  `else
    output                       buf_rd_chn9,
    input                 [63:0] buf_rdata_chn9,
  `endif
`endif    

// channel 10 interface 
`ifdef def_enable_mem_chn10
    input                        want_rq10,   // both want_rq and need_rq should go inactive after being granted  
    input                        need_rq10,
    output reg                   channel_pgm_en10, // channel can program sequence data
    input                 [31:0] seq_data10,  //16x32 data to be written to the sequencer (and start address for software-based sequencer)
    input                        seq_wr10,    // strobe for writing sequencer data (address is autoincremented)
    input                        seq_set10,  // channel sequencer data is written. If no seq_wr pulses before seq_set, seq_data contains software sequencer start address
    output                       seq_done10,  // sequencer finished executing sequence for this channel 
    output                       rpage_nxt_chn10,
    output                       buf_run10,   // external buffer run (may be used to force page) @posedge for write memory write channels, @negedge for read
  `ifdef def_read_mem_chn10
    output                       buf_wr_chn10,   // @ negedge mclk
    output                       buf_wpage_nxt_chn10,   // @ negedge mclk
    output                [63:0] buf_wdata_chn10,   // @ negedge mclk
  `else
    output                       buf_rd_chn10,
    input                 [63:0] buf_rdata_chn10,
  `endif
`endif    

// channel 11 interface 
`ifdef def_enable_mem_chn11
    input                        want_rq11,   // both want_rq and need_rq should go inactive after being granted  
    input                        need_rq11,
    output reg                   channel_pgm_en11, // channel can program sequence data
    input                 [31:0] seq_data11,  //16x32 data to be written to the sequencer (and start address for software-based sequencer)
    input                        seq_wr11,    // strobe for writing sequencer data (address is autoincremented)
    input                        seq_set11,  // channel sequencer data is written. If no seq_wr pulses before seq_set, seq_data contains software sequencer start address
    output                       seq_done11,  // sequencer finished executing sequence for this channel 
    output                       rpage_nxt_chn11,
    output                       buf_run11,   // external buffer run (may be used to force page) @posedge for write memory write channels, @negedge for read
  `ifdef def_read_mem_chn11
    output                       buf_wr_chn11,   // @ negedge mclk
    output                       buf_wpage_nxt_chn11,   // @ negedge mclk
    output                [63:0] buf_wdata_chn11,   // @ negedge mclk
  `else
    output                       buf_rd_chn11,
    input                 [63:0] buf_rdata_chn11,
  `endif
`endif    

// channel 12 interface 
`ifdef def_enable_mem_chn12
    input                        want_rq12,   // both want_rq and need_rq should go inactive after being granted  
    input                        need_rq12,
    output reg                   channel_pgm_en12, // channel can program sequence data
    input                 [31:0] seq_data12,  //16x32 data to be written to the sequencer (and start address for software-based sequencer)
    input                        seq_wr12,    // strobe for writing sequencer data (address is autoincremented)
    input                        seq_set12,  // channel sequencer data is written. If no seq_wr pulses before seq_set, seq_data contains software sequencer start address
    output                       seq_done12,  // sequencer finished executing sequence for this channel 
    output                       rpage_nxt_chn12,
    output                       buf_run12,   // external buffer run (may be used to force page) @posedge for write memory write channels, @negedge for read
  `ifdef def_read_mem_chn12
    output                       buf_wr_chn12,   // @ negedge mclk
    output                       buf_wpage_nxt_chn12,   // @ negedge mclk
    output                [63:0] buf_wdata_chn12,   // @ negedge mclk
  `else
    output                       buf_rd_chn12,
    input                 [63:0] buf_rdata_chn12,
  `endif
`endif    

// channel 13 interface 
`ifdef def_enable_mem_chn13
    input                        want_rq13,   // both want_rq and need_rq should go inactive after being granted  
    input                        need_rq13,
    output reg                   channel_pgm_en13, // channel can program sequence data
    input                 [31:0] seq_data13,  //16x32 data to be written to the sequencer (and start address for software-based sequencer)
    input                        seq_wr13,    // strobe for writing sequencer data (address is autoincremented)
    input                        seq_set13,  // channel sequencer data is written. If no seq_wr pulses before seq_set, seq_data contains software sequencer start address
    output                       seq_done13,  // sequencer finished executing sequence for this channel 
    output                       rpage_nxt_chn13,
    output                       buf_run13,   // external buffer run (may be used to force page) @posedge for write memory write channels, @negedge for read
  `ifdef def_read_mem_chn13
    output                       buf_wr_chn13,   // @ negedge mclk
    output                       buf_wpage_nxt_chn13,   // @ negedge mclk
    output                [63:0] buf_wdata_chn13,   // @ negedge mclk
  `else
    output                       buf_rd_chn13,
    input                 [63:0] buf_rdata_chn13,
  `endif
`endif    

// channel 14 interface 
`ifdef def_enable_mem_chn14
    input                        want_rq14,   // both want_rq and need_rq should go inactive after being granted  
    input                        need_rq14,
    output reg                   channel_pgm_en14, // channel can program sequence data
    input                 [31:0] seq_data14,  //16x32 data to be written to the sequencer (and start address for software-based sequencer)
    input                        seq_wr14,    // strobe for writing sequencer data (address is autoincremented)
    input                        seq_set14,  // channel sequencer data is written. If no seq_wr pulses before seq_set, seq_data contains software sequencer start address
    output                       seq_done14,  // sequencer finished executing sequence for this channel 
    output                       rpage_nxt_chn14,
    output                       buf_run14,   // external buffer run (may be used to force page) @posedge for write memory write channels, @negedge for read
  `ifdef def_read_mem_chn14
    output                       buf_wr_chn14,   // @ negedge mclk
    output                       buf_wpage_nxt_chn14,   // @ negedge mclk
    output                [63:0] buf_wdata_chn14,   // @ negedge mclk
  `else
    output                       buf_rd_chn14,
    input                 [63:0] buf_rdata_chn14,
  `endif
`endif    

// channel 15 interface 
`ifdef def_enable_mem_chn15
    input                        want_rq15,   // both want_rq and need_rq should go inactive after being granted  
    input                        need_rq15,
    output reg                   channel_pgm_en15, // channel can program sequence data
    input                 [31:0] seq_data15,  //16x32 data to be written to the sequencer (and start address for software-based sequencer)
    input                        seq_wr15,    // strobe for writing sequencer data (address is autoincremented)
    input                        seq_set15,  // channel sequencer data is written. If no seq_wr pulses before seq_set, seq_data contains software sequencer start address
    output                       seq_done15,  // sequencer finished executing sequence for this channel 
    output                       rpage_nxt_chn15,
    output                       buf_run15,   // external buffer run (may be used to force page) @posedge for write memory write channels, @negedge for read
  `ifdef def_read_mem_chn15
    output                       buf_wr_chn15,   // @ negedge mclk
    output                       buf_wpage_nxt_chn15,   // @ negedge mclk
    output                [63:0] buf_wdata_chn15,   // @ negedge mclk
  `else
    output                       buf_rd_chn15,
    input                 [63:0] buf_rdata_chn15,
  `endif
`endif    
    
    
    // priority programming
    // TODO: Move to ps7 instance in this module
//    input       [3:0] pgm_addr,  // channel address to program priority
//    input [width-1:0] pgm_data,  // priority data for the channel
//    input             pgm_en,     // enable programming priority data (use different clock?)
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
    inout                        NDQSU //,
//    output                       DUMMY_TO_KEEP  // to keep PS7 signals from "optimization"
//    input                        MEMCLK
// temporary debug data    
    ,output                [11:0] tmp_debug // add some signals generated here?
);
wire rst=rst_in; // TODO: decide where toi generate

    wire        ext_buf_rd;
    wire        ext_buf_rpage_nxt;
//    wire  [6:0] ext_buf_raddr; 
    wire  [3:0] ext_buf_rchn; 
    wire        ext_buf_rrefresh;
    wire        ext_buf_rrun; // run read sequence (to be used with external buffer to set initial address
    reg  [63:0] ext_buf_rdata; 
    wire        ext_buf_wr;
    wire        ext_buf_wpage_nxt;
//    wire  [6:0] ext_buf_waddr; 
    wire  [3:0] ext_buf_wchn; 
    wire        ext_buf_wrefresh; 
    wire        ext_buf_wrun;  // @negedge,first cycle of sequencer run matching write delay 
    wire [63:0] ext_buf_wdata; 

    wire                  [15:0] want_rq;   // both want_rq and need_rq should go inactive after being granted  
    wire                  [15:0] need_rq;

    reg                   [31:0] seq_data;  //16x32 data to be written to the sequencer (and start address for software-based sequencer)
    reg                          seq_wr;    // strobe for writing sequencer data (address is autoincremented)
    reg                          seq_set;  // channel sequencer data is written. If no seq_wr pulses before seq_set, seq_data contains software sequencer start address

// status data from phy (sequencer)
    wire [7:0] status_ad_phy;
    wire       status_rq_phy;
    wire       status_start_phy;
    
// status data from top level controller 
    wire [7:0] status_ad_mcontr;
    wire       status_rq_mcontr;
    wire       status_start_mcontr;
    wire       set_status_w;

    wire        en_schedul; // enable channel arbitration, needs to be disabled before next access can be scheduled
    wire        need;       // granted access is "needed" one, not just "wanted"
    wire        grant;      // single-cycle granted channel access
    wire  [3:0] grant_chn; // granted  channel number, valid with grant, stays valid until en_schedul is deasserted
    wire  [3:0] priority_addr;  // channel address to program priority
    wire [15:0] priority_data;  // priority data for the channel
    wire        priority_en;    // enable programming priority data (use different clock?) 
    
    reg     [3:0]   cmd_wr_chn;     // channel granted write access to command sequencer memory
    reg     [9:0]   cmd_addr_cur;   // current address in the command sequencer memory bank1 (PL)
    reg    [10:0]   cmd_addr_start; // sequencer start address (including bank 0/1)
    reg             grant_r;
    reg             cmd_seq_set;    // some command sequencer data was set (so use it)

    reg             cmd_seq_fill;   // command sequencer is in the process of filling by a channel
    reg             cmd_seq_full;   // command sequencer is filled (if using PL sequencer bank)
    reg             cmd_seq_need;   // memory request by a cnannel in the sequencer is urgent (valid with cmd_seq_full)

    reg             cmd_seq_run;    // run command sequencer - single cycle
    reg     [3:0]   cmd_seq_chn;    // channel number corresponding to the pending memory request:  valid with cmd_seq_run
    reg             cmd_seq_refresh;     // sequencer is running refresh
    reg    [10:0]   cmd_seq_addr;   // start address of the command sequencer (MSB - bank: 0 - PS, 1:PL): valid with cmd_seq_run

    wire            sel_refresh_w;  // select refresh over channel
    wire            pre_run_seq_w;  // initiate run sequence next cycle
    wire            pre_run_chn_w;  // initiate run sequence next cycle for a channel (not refresh)
    wire            mcontr_reset;   // reset controller, generated with ddr_rst in the sequencer
    wire            mcontr_enabled; // enabled and not reset

    wire            sequencer_run_busy; // sequencer is busy
    wire            sequencer_run_done; // to notify channels

    wire            refresh_want;
    wire            refresh_need;
    reg             refresh_grant;

    reg             refresh_en;
    reg     [7:0]   refresh_period; // remove 
    reg     [9:0]   refresh_addr;   // TODO: set command
    reg             mcontr_en;      // enable controller
    reg    [15:0]   mcontr_chn_en;  // per-channel request enable (will not reset transaction in progress)

    reg             chn_want_some;
    reg             chn_need_some;
    reg    [15:0]   chn_want_r;
    wire   [17:0]   status_data;
    
    assign status_data={chn_want_r,chn_need_some,chn_want_some};
    
// mux status info from the memory controller and other modules    
    status_router2 status_router2_top_i (
        .rst       (rst), // input
        .clk       (mclk), // input
        .db_in0    (status_ad_phy), // input[7:0] 
        .rq_in0    (status_rq_phy), // input
        .start_in0 (status_start_phy), // output
        .db_in1    (status_ad_mcontr), // input[7:0] 
        .rq_in1    (status_rq_mcontr), // input
        .start_in1 (status_start_mcontr), // output
        .db_out    (status_ad), // output[7:0] 
        .rq_out    (status_rq), // output
        .start_out (status_start) // input
    );
    
    status_generate #(
        .STATUS_REG_ADDR  (MCONTR_TOP_STATUS_REG_ADDR),
        .PAYLOAD_BITS     (18)
    ) status_generate_i (
        .rst              (rst), // input
        .clk              (mclk), // input
        .we               (set_status_w), // input
        .wd               (mcontr_16bit_data[7:0]), // input[7:0] 
        .status           (status_data), // input[25:0] 
        .ad               (status_ad_mcontr), // output[7:0] 
        .rq               (status_rq_mcontr), // output
        .start            (status_start_mcontr) // input
    );
    
// generate 16-bit data commands (and set defaults to registers)
    cmd_deser #(
        .ADDR       (MCONTR_ARBIT_ADDR),
        .ADDR_MASK  (MCONTR_ARBIT_ADDR_MASK),
        .NUM_CYCLES (4),
        .ADDR_WIDTH (4),
        .DATA_WIDTH (16)
    ) cmd_deser_mcontr_16bit_i (
        .rst        (rst), // input
        .clk        (mclk), // input
        .ad         (cmd_ad), // input[7:0] 
        .stb        (cmd_stb), // input
        .addr       (priority_addr), // output[15:0] 
        .data       (priority_data), // output[31:0] 
        .we         (priority_en) // output
    );
  
// generate on/off dependent on lsb and 0-bit commands
    wire [2:0] mcontr_0bit_addr;
    wire       mcontr_0bit_we;
    cmd_deser #(
        .ADDR       (MCONTR_TOP_0BIT_ADDR),
        .ADDR_MASK  (MCONTR_TOP_0BIT_ADDR_MASK),
        .NUM_CYCLES (2),
        .ADDR_WIDTH (3),
        .DATA_WIDTH (0)
    ) cmd_deser_0bit_i (
        .rst        (rst), // input
        .clk        (mclk), // input
        .ad         (cmd_ad), // input[7:0] 
        .stb        (cmd_stb), // input
        .addr       (mcontr_0bit_addr), // output[15:0] 
        .data       (), // output[31:0] 
        .we         (mcontr_0bit_we) // output
    );
    always @ (posedge rst or posedge mclk) begin
        if (rst)                                                                             mcontr_en <= 0;
        else if (mcontr_0bit_we && (mcontr_0bit_addr[2:1]==(MCONTR_TOP_0BIT_MCONTR_EN>>1)))  mcontr_en <= mcontr_0bit_addr[0];
        
        if (rst)                                                                             refresh_en <= 0 ; // 1;
        else if (mcontr_0bit_we && (mcontr_0bit_addr[2:1]==(MCONTR_TOP_0BIT_REFRESH_EN>>1))) refresh_en <= mcontr_0bit_addr[0];
        
    end
  
// generate 16-bit data commands (and set defaults to registers)
    wire  [2:0] mcontr_16bit_addr;
    wire [15:0] mcontr_16bit_data;
    wire        mcontr_16bit_we;

    cmd_deser #(
        .ADDR       (MCONTR_TOP_16BIT_ADDR),
        .ADDR_MASK  (MCONTR_TOP_16BIT_ADDR_MASK),
        .NUM_CYCLES (4),
        .ADDR_WIDTH (3),
        .DATA_WIDTH (16)
    ) cmd_deser_16bit_i (
        .rst        (rst), // input
        .clk        (mclk), // input
        .ad         (cmd_ad), // input[7:0] 
        .stb        (cmd_stb), // input
        .addr       (mcontr_16bit_addr), // output[15:0] 
        .data       (mcontr_16bit_data), // output[31:0] 
        .we         (mcontr_16bit_we) // output
    );
    wire set_chn_en_w;
    wire set_refresh_period_w;
    wire set_refresh_address_w;
    reg  set_refresh_period;
    
//    wire                control_status_we; // share with write delay (8-but)?
//    wire          [7:0] contral_status_data;
    
    assign set_chn_en_w=           mcontr_16bit_we && (mcontr_16bit_addr[2:0]==MCONTR_TOP_16BIT_CHN_EN);
    assign set_refresh_period_w=   mcontr_16bit_we && (mcontr_16bit_addr[2:0]==MCONTR_TOP_16BIT_REFRESH_PERIOD);
    assign set_refresh_address_w=  mcontr_16bit_we && (mcontr_16bit_addr[2:0]==MCONTR_TOP_16BIT_REFRESH_ADDRESS);
    assign set_status_w=           mcontr_16bit_we && (mcontr_16bit_addr[2:0]==MCONTR_TOP_16BIT_STATUS_CNTRL);

    always @ (posedge rst or posedge mclk) begin
        if (rst) set_refresh_period  <= 0;
        else     set_refresh_period <= set_refresh_period_w;

        if (rst)                        mcontr_chn_en <= DFLT_CHN_EN;
        else if (set_chn_en_w)          mcontr_chn_en <= mcontr_16bit_data[15:0];
        
        if (rst)                        refresh_addr  <= DFLT_REFRESH_ADDR;
        else if (set_refresh_address_w) refresh_addr <= mcontr_16bit_data[9:0];

        if (rst)                        refresh_period <= DFLT_REFRESH_PERIOD;
        else if (set_refresh_period_w)  refresh_period <= mcontr_16bit_data[7:0];
        
        if (rst) chn_want_some <= 0;
        else     chn_want_some <= |want_rq;

        if (rst) chn_need_some <= 0;
        else     chn_need_some <= |need_rq;
        
        if (rst) chn_want_r <= 0;
        else     chn_want_r <= want_rq ; // unmasked channel requests
        
    end
        
  

    scheduler16 #(
        .width      (16)
    ) scheduler16_i (
        .rst        (rst), // input
        .clk        (mclk), // input
        .chn_en     (mcontr_chn_en), // input[15:0]
        .want_rq    (want_rq), // input[15:0] 
        .need_rq    (need_rq), // input[15:0] 
        .en_schedul (en_schedul), // input
        .need       (need), // output
        .grant      (grant), // output
        .grant_chn  (grant_chn), // output[3:0] 
        .pgm_addr   (priority_addr), // input[3:0] 
        .pgm_data   (priority_data), // input[15:0] 
        .pgm_en     (priority_en) // input
    );


        
assign mcontr_enabled=mcontr_en && !mcontr_reset; 
//assign sel_refresh_w= refresh_need || (refresh_want && (!cmd_seq_need || !(cmd_seq_full || (cmd_seq_fill && seq_set ))));  
assign sel_refresh_w= refresh_need || (refresh_want && !(cmd_seq_need && cmd_seq_full));
assign pre_run_seq_w= mcontr_enabled && !sequencer_run_busy && !refresh_grant && (cmd_seq_full || refresh_need || refresh_want);
assign pre_run_chn_w= pre_run_seq_w && !sel_refresh_w;
assign en_schedul= mcontr_enabled && !cmd_seq_fill && !cmd_seq_full;

// sequential logic for commands transfer to the sequencer 
always @ (posedge rst or posedge mclk) begin
    if (rst) grant_r <= 0;
    else     grant_r <= grant;
    
    if (rst)           cmd_seq_set <= 0;
    else if (grant_r)  cmd_seq_set <= 0;
    else if (seq_wr)   cmd_seq_set <= 1;
    
    if (rst)        cmd_wr_chn <= 0;
    else if (grant) cmd_wr_chn <= grant_chn;

//    if (rst)                                    cmd_seq_fill <= 0;
//    else if (!mcontr_enabled || pre_run_chn_w ) cmd_seq_fill <= 0;
//    else if (grant)                             cmd_seq_fill <= 1;

    if (rst)                                    cmd_seq_fill <= 0;
//    else if (!mcontr_enabled || seq_wr )        cmd_seq_fill <= 0;
//    else if (grant)                             cmd_seq_fill <= 1;
    else if (!mcontr_enabled || grant )         cmd_seq_fill <= 0;
    else if (seq_wr)                            cmd_seq_fill <= 1;

    if (rst)                                    cmd_seq_full <= 0;
    else if (!mcontr_enabled || pre_run_chn_w ) cmd_seq_full <= 0;
//    else if (seq_wr)                            cmd_seq_full <= 1;
    else if (seq_set)                            cmd_seq_full <= 1; // even with no data


    if (rst)                                    cmd_seq_need <= 0;
    else if (grant)                             cmd_seq_need <= need;


    if (rst)         cmd_addr_cur <= 0;
    else if (seq_wr) cmd_addr_cur <= cmd_addr_cur+1;
    
    if (rst)                           cmd_addr_start <= 0;
    else if (grant_r)                  cmd_addr_start <= {1'b1,cmd_addr_cur};  // address in PL bank
    else if (!cmd_seq_set && seq_set)  cmd_addr_start <= {1'b0,seq_data[9:0]}; // address in PS bank
    
    
    if (rst) cmd_seq_run <= 0;
    else cmd_seq_run <= pre_run_seq_w;
    
// add refresh address here?    
end   
always @ (posedge mclk) begin
    if (pre_run_seq_w) cmd_seq_addr <= sel_refresh_w ? {1'b0,refresh_addr} : cmd_addr_start;
    if (pre_run_seq_w) cmd_seq_chn <= cmd_wr_chn;
    if (pre_run_seq_w) cmd_seq_refresh <= sel_refresh_w;
end


//   assign run_seq_rq_in = refresh_en && refresh_need; // higher priority request input

    
    ddr_refresh ddr_refresh_i (
        .rst              (rst), // input
        .clk              (mclk), // input
        .en               (refresh_en),
        .refresh_period   (refresh_period), // input[7:0] 
        .set              (set_refresh_period), // input
        .want             (refresh_want), // output
        .need             (refresh_need), // output
        .grant            (refresh_grant) // input
    );
    always @(posedge rst or  posedge mclk) begin
         if (rst) refresh_grant <= 0; 
         else refresh_grant <= pre_run_seq_w && sel_refresh_w; 
    end


    mcontr_sequencer #(
        .DLY_LD                        (DLY_LD),
        .DLY_LD_MASK                   (DLY_LD_MASK),
        .MCONTR_PHY_0BIT_ADDR          (MCONTR_PHY_0BIT_ADDR),
        .MCONTR_PHY_0BIT_ADDR_MASK     (MCONTR_PHY_0BIT_ADDR_MASK),
        .MCONTR_PHY_0BIT_DLY_SET       (MCONTR_PHY_0BIT_DLY_SET),
        .MCONTR_PHY_0BIT_CMDA_EN       (MCONTR_PHY_0BIT_CMDA_EN),
        .MCONTR_PHY_0BIT_SDRST_ACT     (MCONTR_PHY_0BIT_SDRST_ACT),
        .MCONTR_PHY_0BIT_CKE_EN        (MCONTR_PHY_0BIT_CKE_EN),
        .MCONTR_PHY_0BIT_DCI_RST       (MCONTR_PHY_0BIT_DCI_RST),
        .MCONTR_PHY_0BIT_DLY_RST       (MCONTR_PHY_0BIT_DLY_RST),
        .MCONTR_PHY_STATUS_REG_ADDR    (MCONTR_PHY_STATUS_REG_ADDR),
        .MCONTR_PHY_16BIT_ADDR         (MCONTR_PHY_16BIT_ADDR),
        .MCONTR_PHY_16BIT_ADDR_MASK    (MCONTR_PHY_16BIT_ADDR_MASK),
        .MCONTR_PHY_16BIT_PATTERNS     (MCONTR_PHY_16BIT_PATTERNS),
        .MCONTR_PHY_16BIT_PATTERNS_TRI (MCONTR_PHY_16BIT_PATTERNS_TRI),
        .MCONTR_PHY_16BIT_WBUF_DELAY   (MCONTR_PHY_16BIT_WBUF_DELAY),
        .MCONTR_PHY_16BIT_EXTRA        (MCONTR_PHY_16BIT_EXTRA),
        .MCONTR_PHY_STATUS_CNTRL       (MCONTR_PHY_STATUS_CNTRL),
        .DFLT_DQS_PATTERN              (DFLT_DQS_PATTERN),
        .DFLT_DQM_PATTERN              (DFLT_DQM_PATTERN),
        .DFLT_DQ_TRI_ON_PATTERN        (DFLT_DQ_TRI_ON_PATTERN),
        .DFLT_DQ_TRI_OFF_PATTERN       (DFLT_DQ_TRI_OFF_PATTERN),
        .DFLT_DQS_TRI_ON_PATTERN       (DFLT_DQS_TRI_ON_PATTERN),
        .DFLT_DQS_TRI_OFF_PATTERN      (DFLT_DQS_TRI_OFF_PATTERN),
        .DFLT_WBUF_DELAY               (DFLT_WBUF_DELAY),
        .DFLT_INV_CLK_DIV              (DFLT_INV_CLK_DIV),
        .PHASE_WIDTH                   (PHASE_WIDTH),
        .SLEW_DQ                       (SLEW_DQ),
        .SLEW_DQS                      (SLEW_DQS),
        .SLEW_CMDA                     (SLEW_CMDA),
        .SLEW_CLK                      (SLEW_CLK),
        .IBUF_LOW_PWR                  (IBUF_LOW_PWR),
        .REFCLK_FREQUENCY              (REFCLK_FREQUENCY),
        .HIGH_PERFORMANCE_MODE         (HIGH_PERFORMANCE_MODE),
        .CLKIN_PERIOD                  (CLKIN_PERIOD),
        .CLKFBOUT_MULT                 (CLKFBOUT_MULT),
        .CLKFBOUT_MULT_REF             (CLKFBOUT_MULT_REF),
        .CLKFBOUT_DIV_REF              (CLKFBOUT_DIV_REF),
        .DIVCLK_DIVIDE                 (DIVCLK_DIVIDE),
        .CLKFBOUT_PHASE                (CLKFBOUT_PHASE),
        .SDCLK_PHASE                   (SDCLK_PHASE),
        .CLK_PHASE                     (CLK_PHASE),
        .CLK_DIV_PHASE                 (CLK_DIV_PHASE),
        .MCLK_PHASE                    (MCLK_PHASE),
        .REF_JITTER1                   (REF_JITTER1),
        .SS_EN                         (SS_EN),
        .SS_MODE                       (SS_MODE),
        .SS_MOD_PERIOD                 (SS_MOD_PERIOD),
        .CMD_PAUSE_BITS                (CMD_PAUSE_BITS),
        .CMD_DONE_BIT                  (CMD_DONE_BIT)
    ) mcontr_sequencer_i (
        .SDRST          (SDRST), // output
        .SDCLK          (SDCLK), // output
        .SDNCLK         (SDNCLK), // output
        .SDA            (SDA[14:0]), // output[14:0] // BUG with localparam - fixed
        .SDBA           (SDBA[2:0]), // output[2:0] 
        .SDWE           (SDWE), // output
        .SDRAS          (SDRAS), // output
        .SDCAS          (SDCAS), // output
        .SDCKE          (SDCKE), // output
        .SDODT          (SDODT), // output
        .SDD            (SDD[15:0]), // inout[15:0] 
        .SDDML          (SDDML), // inout
        .DQSL           (DQSL), // inout
        .NDQSL          (NDQSL), // inout
        .SDDMU          (SDDMU), // inout
        .DQSU           (DQSU), // inout
        .NDQSU          (NDQSU), // inout
        
        .clk_in         (clk_in), // axi_aclk), // input
        .rst_in         (rst_in), // axi_rst), // input TODO: move buffer outside?
        .mclk           (mclk), // output
        
        .cmd0_clk       (cmd0_clk), // input
        .cmd0_we        (cmd0_we), // input
        .cmd0_addr      (cmd0_addr[9:0]), // input[9:0] 
        .cmd0_data      (cmd0_data[31:0]), // input[31:0] 

        .cmd1_clk       (mclk), // input
        .cmd1_we        (seq_wr), // input
        .cmd1_addr      (cmd_addr_cur), // input[9:0] 
        .cmd1_data      (seq_data), // input[31:0]

        .run_addr       (cmd_seq_addr[10:0]), // input[10:0] 
        .run_chn        (cmd_seq_chn[3:0]), // input[3:0] 
        .run_refresh    (cmd_seq_refresh), // input
        .run_seq        (cmd_seq_run), // input
        .run_done       (sequencer_run_done), // output
        .run_busy       (sequencer_run_busy), // output ASSUMING it is high next cycle after run_seq - TODO: verify - yes, if not mcontr_reset
        .mcontr_reset   (mcontr_reset), // output == ddr_reset that also resets sequencer  
        .cmd_ad         (cmd_ad), // input[7:0] 
        .cmd_stb        (cmd_stb), // input
        .status_ad      (status_ad_phy), // output[7:0] 
        .status_rq      (status_rq_phy), // output
        .status_start   (status_start_phy), // input
        .ext_buf_rd     (ext_buf_rd), // output
        .ext_buf_rpage_nxt  (ext_buf_rpage_nxt), // output[6:0] 
//        .ext_buf_raddr  (ext_buf_raddr), // output[6:0] 
        .ext_buf_rchn   (ext_buf_rchn), // output[3:0] 
        .ext_buf_rrefresh(ext_buf_rrefresh), // output 
        .ext_buf_rrun   (ext_buf_rrun), // run read sequence (to be used with external buffer to set initial address
        .ext_buf_rdata  (ext_buf_rdata), // input[63:0] 
        .ext_buf_wr     (ext_buf_wr), // output
        .ext_buf_wpage_nxt  (ext_buf_wpage_nxt), // output[6:0] 
//        .ext_buf_waddr  (ext_buf_waddr), // output[6:0] 
        .ext_buf_wchn   (ext_buf_wchn), // output[3:0] 
        .ext_buf_wrefresh(ext_buf_wrefresh), // output
        .ext_buf_wrun   (ext_buf_wrun),     // @negedge,first cycle of sequencer run matching write delay 
        .ext_buf_wdata  (ext_buf_wdata), // output[63:0] 
        .tmp_debug      (tmp_debug) // output[11:0] 
    );

// Registering existing channel buffers I/Os
`ifdef def_enable_mem_chn0
    mcont_common_chnbuf_reg #( .CHN_NUMBER(0)) mcont_common_chnbuf_reg0_i(.rst(rst),.clk(mclk), .ext_buf_rchn(ext_buf_rchn),
        .ext_buf_rrefresh(ext_buf_rrefresh),.ext_buf_rpage_nxt(ext_buf_rpage_nxt),.seq_done(sequencer_run_done),
        .buf_done(seq_done0),.rpage_nxt(rpage_nxt_chn0));
  `ifdef def_read_mem_chn0
    mcont_to_chnbuf_reg #(.CHN_NUMBER( 0)) mcont_to_chnbuf_reg0_i(.rst(rst),.clk(mclk),.ext_buf_wr(ext_buf_wr),
        .ext_buf_wpage_nxt(ext_buf_wpage_nxt),.ext_buf_wchn(ext_buf_wchn), .ext_buf_wrefresh(ext_buf_wrefresh),
        .ext_buf_wrun(ext_buf_wrun),.ext_buf_wdata(ext_buf_wdata),.buf_wr_chn(buf_wr_chn0),
        .buf_wpage_nxt_chn(buf_wpage_nxt_chn0),.buf_run(buf_run0),.buf_wdata_chn(buf_wdata_chn0));
  `else
    wire [63:0] ext_buf_rdata0;
    mcont_from_chnbuf_reg #(.CHN_NUMBER( 0),.CHN_LATENCY(CHNBUF_READ_LATENCY)) mcont_from_chnbuf_reg0_i (.rst(rst),.clk(mclk),
        .ext_buf_rd(ext_buf_rd),.ext_buf_rchn(ext_buf_rchn), .ext_buf_rrefresh(ext_buf_rrefresh), .ext_buf_rrun(ext_buf_rrun),
        .ext_buf_rdata(ext_buf_rdata0),.buf_rd_chn(buf_rd_chn0),.buf_run(buf_run0),.buf_rdata_chn(buf_rdata_chn0));
  `endif
`endif    

`ifdef def_enable_mem_chn1
    mcont_common_chnbuf_reg #( .CHN_NUMBER(1)) mcont_common_chnbuf_reg1_i(.rst(rst),.clk(mclk), .ext_buf_rchn(ext_buf_rchn),
        .ext_buf_rrefresh(ext_buf_rrefresh),.ext_buf_rpage_nxt(ext_buf_rpage_nxt),.seq_done(sequencer_run_done),
        .buf_done(seq_done1),.rpage_nxt(rpage_nxt_chn1));
  `ifdef def_read_mem_chn1
    mcont_to_chnbuf_reg #(.CHN_NUMBER( 1)) mcont_to_chnbuf_reg1_i(.rst(rst),.clk(mclk),.ext_buf_wr(ext_buf_wr),
        .ext_buf_wpage_nxt(ext_buf_wpage_nxt),.ext_buf_wchn(ext_buf_wchn), .ext_buf_wrefresh(ext_buf_wrefresh),
        .ext_buf_wrun(ext_buf_wrun),.ext_buf_wdata(ext_buf_wdata),.buf_wr_chn(buf_wr_chn1),
        .buf_wpage_nxt_chn(buf_wpage_nxt_chn1),.buf_run(buf_run1),.buf_wdata_chn(buf_wdata_chn1));
  `else
    wire [63:0] ext_buf_rdata1;
    mcont_from_chnbuf_reg #(.CHN_NUMBER( 1),.CHN_LATENCY(CHNBUF_READ_LATENCY)) mcont_from_chnbuf_reg1_i (.rst(rst),.clk(mclk),
        .ext_buf_rd(ext_buf_rd),.ext_buf_rchn(ext_buf_rchn), .ext_buf_rrefresh(ext_buf_rrefresh), .ext_buf_rrun(ext_buf_rrun),
        .ext_buf_rdata(ext_buf_rdata1),.buf_rd_chn(buf_rd_chn1),.buf_run(buf_run1),.buf_rdata_chn(buf_rdata_chn1));
  `endif
`endif    

`ifdef def_enable_mem_chn2
    mcont_common_chnbuf_reg #( .CHN_NUMBER(2)) mcont_common_chnbuf_reg2_i(.rst(rst),.clk(mclk), .ext_buf_rchn(ext_buf_rchn),
        .ext_buf_rrefresh(ext_buf_rrefresh),.ext_buf_rpage_nxt(ext_buf_rpage_nxt),.seq_done(sequencer_run_done),
        .buf_done(seq_done2),.rpage_nxt(rpage_nxt_chn2));
  `ifdef def_read_mem_chn2
    mcont_to_chnbuf_reg #(.CHN_NUMBER( 2)) mcont_to_chnbuf_reg2_i(.rst(rst),.clk(mclk),.ext_buf_wr(ext_buf_wr),
        .ext_buf_wpage_nxt(ext_buf_wpage_nxt),.ext_buf_wchn(ext_buf_wchn), .ext_buf_wrefresh(ext_buf_wrefresh),
        .ext_buf_wrun(ext_buf_wrun),.ext_buf_wdata(ext_buf_wdata),.buf_wr_chn(buf_wr_chn2),
        .buf_wpage_nxt_chn(buf_wpage_nxt_chn2),.buf_run(buf_run2),.buf_wdata_chn(buf_wdata_chn2));
  `else
    wire [63:0] ext_buf_rdata2;
    mcont_from_chnbuf_reg #(.CHN_NUMBER( 2),.CHN_LATENCY(CHNBUF_READ_LATENCY)) mcont_from_chnbuf_reg2_i (.rst(rst),.clk(mclk),
        .ext_buf_rd(ext_buf_rd),.ext_buf_rchn(ext_buf_rchn), .ext_buf_rrefresh(ext_buf_rrefresh), .ext_buf_rrun(ext_buf_rrun),
        .ext_buf_rdata(ext_buf_rdata2),.buf_rd_chn(buf_rd_chn2),.buf_run(buf_run2),.buf_rdata_chn(buf_rdata_chn2));
  `endif
`endif    

`ifdef def_enable_mem_chn3
    mcont_common_chnbuf_reg #( .CHN_NUMBER(3)) mcont_common_chnbuf_reg3_i(.rst(rst),.clk(mclk), .ext_buf_rchn(ext_buf_rchn),
        .ext_buf_rrefresh(ext_buf_rrefresh),.ext_buf_rpage_nxt(ext_buf_rpage_nxt),.seq_done(sequencer_run_done),
        .buf_done(seq_done3),.rpage_nxt(rpage_nxt_chn3));
  `ifdef def_read_mem_chn3
    mcont_to_chnbuf_reg #(.CHN_NUMBER( 3)) mcont_to_chnbuf_reg3_i(.rst(rst),.clk(mclk),.ext_buf_wr(ext_buf_wr),
        .ext_buf_wpage_nxt(ext_buf_wpage_nxt),.ext_buf_wchn(ext_buf_wchn), .ext_buf_wrefresh(ext_buf_wrefresh),
        .ext_buf_wrun(ext_buf_wrun),.ext_buf_wdata(ext_buf_wdata),.buf_wr_chn(buf_wr_chn3),
        .buf_wpage_nxt_chn(buf_wpage_nxt_chn3),.buf_run(buf_run3),.buf_wdata_chn(buf_wdata_chn3));
  `else
    wire [63:0] ext_buf_rdata3;
    mcont_from_chnbuf_reg #(.CHN_NUMBER( 3),.CHN_LATENCY(CHNBUF_READ_LATENCY)) mcont_from_chnbuf_reg3_i (.rst(rst),.clk(mclk),
        .ext_buf_rd(ext_buf_rd),.ext_buf_rchn(ext_buf_rchn), .ext_buf_rrefresh(ext_buf_rrefresh), .ext_buf_rrun(ext_buf_rrun),
        .ext_buf_rdata(ext_buf_rdata3),.buf_rd_chn(buf_rd_chn3),.buf_run(buf_run3),.buf_rdata_chn(buf_rdata_chn3));
  `endif
`endif    

`ifdef def_enable_mem_chn4
    mcont_common_chnbuf_reg #( .CHN_NUMBER(4)) mcont_common_chnbuf_reg4_i(.rst(rst),.clk(mclk), .ext_buf_rchn(ext_buf_rchn),
        .ext_buf_rrefresh(ext_buf_rrefresh),.ext_buf_rpage_nxt(ext_buf_rpage_nxt),.seq_done(sequencer_run_done),
        .buf_done(seq_done4),.rpage_nxt(rpage_nxt_chn4));
  `ifdef def_read_mem_chn4
    mcont_to_chnbuf_reg #(.CHN_NUMBER( 4)) mcont_to_chnbuf_reg4_i(.rst(rst),.clk(mclk),.ext_buf_wr(ext_buf_wr),
        .ext_buf_wpage_nxt(ext_buf_wpage_nxt),.ext_buf_wchn(ext_buf_wchn), .ext_buf_wrefresh(ext_buf_wrefresh),
        .ext_buf_wrun(ext_buf_wrun),.ext_buf_wdata(ext_buf_wdata),.buf_wr_chn(buf_wr_chn4),
        .buf_wpage_nxt_chn(buf_wpage_nxt_chn4),.buf_run(buf_run4),.buf_wdata_chn(buf_wdata_chn4));
  `else
    wire [63:0] ext_buf_rdata4;
    mcont_from_chnbuf_reg #(.CHN_NUMBER( 4),.CHN_LATENCY(CHNBUF_READ_LATENCY)) mcont_from_chnbuf_reg4_i (.rst(rst),.clk(mclk),
        .ext_buf_rd(ext_buf_rd),.ext_buf_rchn(ext_buf_rchn), .ext_buf_rrefresh(ext_buf_rrefresh), .ext_buf_rrun(ext_buf_rrun),
        .ext_buf_rdata(ext_buf_rdata4),.buf_rd_chn(buf_rd_chn4),.buf_run(buf_run4),.buf_rdata_chn(buf_rdata_chn4));
  `endif
`endif    

`ifdef def_enable_mem_chn5
    mcont_common_chnbuf_reg #( .CHN_NUMBER(5)) mcont_common_chnbuf_reg5_i(.rst(rst),.clk(mclk), .ext_buf_rchn(ext_buf_rchn),
        .ext_buf_rrefresh(ext_buf_rrefresh),.ext_buf_rpage_nxt(ext_buf_rpage_nxt),.seq_done(sequencer_run_done),
        .buf_done(seq_done5),.rpage_nxt(rpage_nxt_chn5));
  `ifdef def_read_mem_chn5
    mcont_to_chnbuf_reg #(.CHN_NUMBER( 5)) mcont_to_chnbuf_reg5_i(.rst(rst),.clk(mclk),.ext_buf_wr(ext_buf_wr),
        .ext_buf_wpage_nxt(ext_buf_wpage_nxt),.ext_buf_wchn(ext_buf_wchn), .ext_buf_wrefresh(ext_buf_wrefresh),
        .ext_buf_wrun(ext_buf_wrun),.ext_buf_wdata(ext_buf_wdata),.buf_wr_chn(buf_wr_chn5),
        .buf_wpage_nxt_chn(buf_wpage_nxt_chn5),.buf_run(buf_run5),.buf_wdata_chn(buf_wdata_chn5));
  `else
    wire [63:0] ext_buf_rdata5;
    mcont_from_chnbuf_reg #(.CHN_NUMBER( 5),.CHN_LATENCY(CHNBUF_READ_LATENCY)) mcont_from_chnbuf_reg5_i (.rst(rst),.clk(mclk),
        .ext_buf_rd(ext_buf_rd),.ext_buf_rchn(ext_buf_rchn), .ext_buf_rrefresh(ext_buf_rrefresh), .ext_buf_rrun(ext_buf_rrun),
        .ext_buf_rdata(ext_buf_rdata5),.buf_rd_chn(buf_rd_chn5),.buf_run(buf_run5),.buf_rdata_chn(buf_rdata_chn5));
  `endif
`endif    

`ifdef def_enable_mem_chn6
    mcont_common_chnbuf_reg #( .CHN_NUMBER(6)) mcont_common_chnbuf_reg6_i(.rst(rst),.clk(mclk), .ext_buf_rchn(ext_buf_rchn),
        .ext_buf_rrefresh(ext_buf_rrefresh),.ext_buf_rpage_nxt(ext_buf_rpage_nxt),.seq_done(sequencer_run_done),
        .buf_done(seq_done6),.rpage_nxt(rpage_nxt_chn6));
  `ifdef def_read_mem_chn6
    mcont_to_chnbuf_reg #(.CHN_NUMBER( 6)) mcont_to_chnbuf_reg6_i(.rst(rst),.clk(mclk),.ext_buf_wr(ext_buf_wr),
        .ext_buf_wpage_nxt(ext_buf_wpage_nxt),.ext_buf_wchn(ext_buf_wchn), .ext_buf_wrefresh(ext_buf_wrefresh),
        .ext_buf_wrun(ext_buf_wrun),.ext_buf_wdata(ext_buf_wdata),.buf_wr_chn(buf_wr_chn6),
        .buf_wpage_nxt_chn(buf_wpage_nxt_chn6),.buf_run(buf_run6),.buf_wdata_chn(buf_wdata_chn6));
  `else
    wire [63:0] ext_buf_rdata6;
    mcont_from_chnbuf_reg #(.CHN_NUMBER( 6),.CHN_LATENCY(CHNBUF_READ_LATENCY)) mcont_from_chnbuf_reg6_i (.rst(rst),.clk(mclk),
        .ext_buf_rd(ext_buf_rd),.ext_buf_rchn(ext_buf_rchn), .ext_buf_rrefresh(ext_buf_rrefresh), .ext_buf_rrun(ext_buf_rrun),
        .ext_buf_rdata(ext_buf_rdata6),.buf_rd_chn(buf_rd_chn6),.buf_run(buf_run6),.buf_rdata_chn(buf_rdata_chn6));
  `endif
`endif    

`ifdef def_enable_mem_chn7
    mcont_common_chnbuf_reg #( .CHN_NUMBER(7)) mcont_common_chnbuf_reg7_i(.rst(rst),.clk(mclk), .ext_buf_rchn(ext_buf_rchn),
        .ext_buf_rrefresh(ext_buf_rrefresh),.ext_buf_rpage_nxt(ext_buf_rpage_nxt),.seq_done(sequencer_run_done),
        .buf_done(seq_done7),.rpage_nxt(rpage_nxt_chn7));
  `ifdef def_read_mem_chn7
    mcont_to_chnbuf_reg #(.CHN_NUMBER( 7)) mcont_to_chnbuf_reg7_i(.rst(rst),.clk(mclk),.ext_buf_wr(ext_buf_wr),
        .ext_buf_wpage_nxt(ext_buf_wpage_nxt),.ext_buf_wchn(ext_buf_wchn), .ext_buf_wrefresh(ext_buf_wrefresh),
        .ext_buf_wrun(ext_buf_wrun),.ext_buf_wdata(ext_buf_wdata),.buf_wr_chn(buf_wr_chn7),
        .buf_wpage_nxt_chn(buf_wpage_nxt_chn7),.buf_run(buf_run7),.buf_wdata_chn(buf_wdata_chn7));
  `else
    wire [63:0] ext_buf_rdata7;
    mcont_from_chnbuf_reg #(.CHN_NUMBER( 7),.CHN_LATENCY(CHNBUF_READ_LATENCY)) mcont_from_chnbuf_reg7_i (.rst(rst),.clk(mclk),
        .ext_buf_rd(ext_buf_rd),.ext_buf_rchn(ext_buf_rchn), .ext_buf_rrefresh(ext_buf_rrefresh), .ext_buf_rrun(ext_buf_rrun),
        .ext_buf_rdata(ext_buf_rdata7),.buf_rd_chn(buf_rd_chn7),.buf_run(buf_run7),.buf_rdata_chn(buf_rdata_chn7));
  `endif
`endif    

`ifdef def_enable_mem_chn8
    mcont_common_chnbuf_reg #( .CHN_NUMBER(8)) mcont_common_chnbuf_reg8_i(.rst(rst),.clk(mclk), .ext_buf_rchn(ext_buf_rchn),
        .ext_buf_rrefresh(ext_buf_rrefresh),.ext_buf_rpage_nxt(ext_buf_rpage_nxt),.seq_done(sequencer_run_done),
        .buf_done(seq_done8),.rpage_nxt(rpage_nxt_chn8));
  `ifdef def_read_mem_chn8
    mcont_to_chnbuf_reg #(.CHN_NUMBER( 8)) mcont_to_chnbuf_reg8_i(.rst(rst),.clk(mclk),.ext_buf_wr(ext_buf_wr),
        .ext_buf_wpage_nxt(ext_buf_wpage_nxt),.ext_buf_wchn(ext_buf_wchn), .ext_buf_wrefresh(ext_buf_wrefresh),
        .ext_buf_wrun(ext_buf_wrun),.ext_buf_wdata(ext_buf_wdata),.buf_wr_chn(buf_wr_chn8),
        .buf_wpage_nxt_chn(buf_wpage_nxt_chn8),.buf_run(buf_run8),.buf_wdata_chn(buf_wdata_chn8));
  `else
    wire [63:0] ext_buf_rdata8;
    mcont_from_chnbuf_reg #(.CHN_NUMBER( 8),.CHN_LATENCY(CHNBUF_READ_LATENCY)) mcont_from_chnbuf_reg8_i (.rst(rst),.clk(mclk),
        .ext_buf_rd(ext_buf_rd),.ext_buf_rchn(ext_buf_rchn), .ext_buf_rrefresh(ext_buf_rrefresh), .ext_buf_rrun(ext_buf_rrun),
        .ext_buf_rdata(ext_buf_rdata8),.buf_rd_chn(buf_rd_chn8),.buf_run(buf_run8),.buf_rdata_chn(buf_rdata_chn8));
  `endif
`endif    

`ifdef def_enable_mem_chn9
    mcont_common_chnbuf_reg #( .CHN_NUMBER(9)) mcont_common_chnbuf_reg9_i(.rst(rst),.clk(mclk), .ext_buf_rchn(ext_buf_rchn),
        .ext_buf_rrefresh(ext_buf_rrefresh),.ext_buf_rpage_nxt(ext_buf_rpage_nxt),.seq_done(sequencer_run_done),
        .buf_done(seq_done9),.rpage_nxt(rpage_nxt_chn9));
  `ifdef def_read_mem_chn9
    mcont_to_chnbuf_reg #(.CHN_NUMBER( 9)) mcont_to_chnbuf_reg9_i(.rst(rst),.clk(mclk),.ext_buf_wr(ext_buf_wr),
        .ext_buf_wpage_nxt(ext_buf_wpage_nxt),.ext_buf_wchn(ext_buf_wchn), .ext_buf_wrefresh(ext_buf_wrefresh),
        .ext_buf_wrun(ext_buf_wrun),.ext_buf_wdata(ext_buf_wdata),.buf_wr_chn(buf_wr_chn9),
        .buf_wpage_nxt_chn(buf_wpage_nxt_chn9),.buf_run(buf_run9),.buf_wdata_chn(buf_wdata_chn9));
  `else
    wire [63:0] ext_buf_rdata9;
    mcont_from_chnbuf_reg #(.CHN_NUMBER( 9),.CHN_LATENCY(CHNBUF_READ_LATENCY)) mcont_from_chnbuf_reg9_i (.rst(rst),.clk(mclk),
        .ext_buf_rd(ext_buf_rd),.ext_buf_rchn(ext_buf_rchn), .ext_buf_rrefresh(ext_buf_rrefresh), .ext_buf_rrun(ext_buf_rrun),
        .ext_buf_rdata(ext_buf_rdata9),.buf_rd_chn(buf_rd_chn9),.buf_run(buf_run9),.buf_rdata_chn(buf_rdata_chn9));
  `endif
`endif    

`ifdef def_enable_mem_chn10
    mcont_common_chnbuf_reg #( .CHN_NUMBER(10)) mcont_common_chnbuf_reg10_i(.rst(rst),.clk(mclk), .ext_buf_rchn(ext_buf_rchn),
        .ext_buf_rrefresh(ext_buf_rrefresh),.ext_buf_rpage_nxt(ext_buf_rpage_nxt),.seq_done(sequencer_run_done),
        .buf_done(seq_done10),.rpage_nxt(rpage_nxt_chn10));
  `ifdef def_read_mem_chn10
    mcont_to_chnbuf_reg #(.CHN_NUMBER( 10)) mcont_to_chnbuf_reg10_i(.rst(rst),.clk(mclk),.ext_buf_wr(ext_buf_wr),
        .ext_buf_wpage_nxt(ext_buf_wpage_nxt),.ext_buf_wchn(ext_buf_wchn), .ext_buf_wrefresh(ext_buf_wrefresh),
        .ext_buf_wrun(ext_buf_wrun),.ext_buf_wdata(ext_buf_wdata),.buf_wr_chn(buf_wr_chn10),
        .buf_wpage_nxt_chn(buf_wpage_nxt_chn10),.buf_run(buf_run10),.buf_wdata_chn(buf_wdata_chn10));
  `else
    wire [63:0] ext_buf_rdata10;
    mcont_from_chnbuf_reg #(.CHN_NUMBER( 10),.CHN_LATENCY(CHNBUF_READ_LATENCY)) mcont_from_chnbuf_reg10_i (.rst(rst),.clk(mclk),
        .ext_buf_rd(ext_buf_rd),.ext_buf_rchn(ext_buf_rchn), .ext_buf_rrefresh(ext_buf_rrefresh), .ext_buf_rrun(ext_buf_rrun),
        .ext_buf_rdata(ext_buf_rdata10),.buf_rd_chn(buf_rd_chn10),.buf_run(buf_run10),.buf_rdata_chn(buf_rdata_chn10));
  `endif
`endif    

`ifdef def_enable_mem_chn11
    mcont_common_chnbuf_reg #( .CHN_NUMBER(11)) mcont_common_chnbuf_reg11_i(.rst(rst),.clk(mclk), .ext_buf_rchn(ext_buf_rchn),
        .ext_buf_rrefresh(ext_buf_rrefresh),.ext_buf_rpage_nxt(ext_buf_rpage_nxt),.seq_done(sequencer_run_done),
        .buf_done(seq_done11),.rpage_nxt(rpage_nxt_chn11));
  `ifdef def_read_mem_chn11
    mcont_to_chnbuf_reg #(.CHN_NUMBER( 11)) mcont_to_chnbuf_reg11_i(.rst(rst),.clk(mclk),.ext_buf_wr(ext_buf_wr),
        .ext_buf_wpage_nxt(ext_buf_wpage_nxt),.ext_buf_wchn(ext_buf_wchn), .ext_buf_wrefresh(ext_buf_wrefresh),
        .ext_buf_wrun(ext_buf_wrun),.ext_buf_wdata(ext_buf_wdata),.buf_wr_chn(buf_wr_chn11),
        .buf_wpage_nxt_chn(buf_wpage_nxt_chn11),.buf_run(buf_run11),.buf_wdata_chn(buf_wdata_chn11));
  `else
    wire [63:0] ext_buf_rdata11;
    mcont_from_chnbuf_reg #(.CHN_NUMBER( 11),.CHN_LATENCY(CHNBUF_READ_LATENCY)) mcont_from_chnbuf_reg11_i (.rst(rst),.clk(mclk),
        .ext_buf_rd(ext_buf_rd),.ext_buf_rchn(ext_buf_rchn), .ext_buf_rrefresh(ext_buf_rrefresh), .ext_buf_rrun(ext_buf_rrun),
        .ext_buf_rdata(ext_buf_rdata11),.buf_rd_chn(buf_rd_chn11),.buf_run(buf_run11),.buf_rdata_chn(buf_rdata_chn11));
  `endif
`endif    

`ifdef def_enable_mem_chn12
    mcont_common_chnbuf_reg #( .CHN_NUMBER(12)) mcont_common_chnbuf_reg12_i(.rst(rst),.clk(mclk), .ext_buf_rchn(ext_buf_rchn),
        .ext_buf_rrefresh(ext_buf_rrefresh),.ext_buf_rpage_nxt(ext_buf_rpage_nxt),.seq_done(sequencer_run_done),
        .buf_done(seq_done12),.rpage_nxt(rpage_nxt_chn12));
  `ifdef def_read_mem_chn12
    mcont_to_chnbuf_reg #(.CHN_NUMBER( 12)) mcont_to_chnbuf_reg12_i(.rst(rst),.clk(mclk),.ext_buf_wr(ext_buf_wr),
        .ext_buf_wpage_nxt(ext_buf_wpage_nxt),.ext_buf_wchn(ext_buf_wchn), .ext_buf_wrefresh(ext_buf_wrefresh),
        .ext_buf_wrun(ext_buf_wrun),.ext_buf_wdata(ext_buf_wdata),.buf_wr_chn(buf_wr_chn12),
        .buf_wpage_nxt_chn(buf_wpage_nxt_chn12),.buf_run(buf_run12),.buf_wdata_chn(buf_wdata_chn12));
  `else
    wire [63:0] ext_buf_rdata12;
    mcont_from_chnbuf_reg #(.CHN_NUMBER( 12),.CHN_LATENCY(CHNBUF_READ_LATENCY)) mcont_from_chnbuf_reg12_i (.rst(rst),.clk(mclk),
        .ext_buf_rd(ext_buf_rd),.ext_buf_rchn(ext_buf_rchn), .ext_buf_rrefresh(ext_buf_rrefresh), .ext_buf_rrun(ext_buf_rrun),
        .ext_buf_rdata(ext_buf_rdata12),.buf_rd_chn(buf_rd_chn12),.buf_run(buf_run12),.buf_rdata_chn(buf_rdata_chn12));
  `endif
`endif    

`ifdef def_enable_mem_chn13
    mcont_common_chnbuf_reg #( .CHN_NUMBER(13)) mcont_common_chnbuf_reg13_i(.rst(rst),.clk(mclk), .ext_buf_rchn(ext_buf_rchn),
        .ext_buf_rrefresh(ext_buf_rrefresh),.ext_buf_rpage_nxt(ext_buf_rpage_nxt),.seq_done(sequencer_run_done),
        .buf_done(seq_done13),.rpage_nxt(rpage_nxt_chn13));
  `ifdef def_read_mem_chn13
    mcont_to_chnbuf_reg #(.CHN_NUMBER( 13)) mcont_to_chnbuf_reg13_i(.rst(rst),.clk(mclk),.ext_buf_wr(ext_buf_wr),
        .ext_buf_wpage_nxt(ext_buf_wpage_nxt),.ext_buf_wchn(ext_buf_wchn), .ext_buf_wrefresh(ext_buf_wrefresh),
        .ext_buf_wrun(ext_buf_wrun),.ext_buf_wdata(ext_buf_wdata),.buf_wr_chn(buf_wr_chn13),
        .buf_wpage_nxt_chn(buf_wpage_nxt_chn13),.buf_run(buf_run13),.buf_wdata_chn(buf_wdata_chn13));
  `else
    wire [63:0] ext_buf_rdata13;
    mcont_from_chnbuf_reg #(.CHN_NUMBER( 13),.CHN_LATENCY(CHNBUF_READ_LATENCY)) mcont_from_chnbuf_reg13_i (.rst(rst),.clk(mclk),
        .ext_buf_rd(ext_buf_rd),.ext_buf_rchn(ext_buf_rchn), .ext_buf_rrefresh(ext_buf_rrefresh), .ext_buf_rrun(ext_buf_rrun),
        .ext_buf_rdata(ext_buf_rdata13),.buf_rd_chn(buf_rd_chn13),.buf_run(buf_run13),.buf_rdata_chn(buf_rdata_chn13));
  `endif
`endif    

`ifdef def_enable_mem_chn14
    mcont_common_chnbuf_reg #( .CHN_NUMBER(14)) mcont_common_chnbuf_reg14_i(.rst(rst),.clk(mclk), .ext_buf_rchn(ext_buf_rchn),
        .ext_buf_rrefresh(ext_buf_rrefresh),.ext_buf_rpage_nxt(ext_buf_rpage_nxt),.seq_done(sequencer_run_done),
        .buf_done(seq_done14),.rpage_nxt(rpage_nxt_chn14));
  `ifdef def_read_mem_chn14
    mcont_to_chnbuf_reg #(.CHN_NUMBER( 14)) mcont_to_chnbuf_reg14_i(.rst(rst),.clk(mclk),.ext_buf_wr(ext_buf_wr),
        .ext_buf_wpage_nxt(ext_buf_wpage_nxt),.ext_buf_wchn(ext_buf_wchn), .ext_buf_wrefresh(ext_buf_wrefresh),
        .ext_buf_wrun(ext_buf_wrun),.ext_buf_wdata(ext_buf_wdata),.buf_wr_chn(buf_wr_chn14),
        .buf_wpage_nxt_chn(buf_wpage_nxt_chn14),.buf_run(buf_run14),.buf_wdata_chn(buf_wdata_chn14));
  `else
    wire [63:0] ext_buf_rdata14;
    mcont_from_chnbuf_reg #(.CHN_NUMBER( 14),.CHN_LATENCY(CHNBUF_READ_LATENCY)) mcont_from_chnbuf_reg14_i (.rst(rst),.clk(mclk),
        .ext_buf_rd(ext_buf_rd),.ext_buf_rchn(ext_buf_rchn), .ext_buf_rrefresh(ext_buf_rrefresh), .ext_buf_rrun(ext_buf_rrun),
        .ext_buf_rdata(ext_buf_rdata14),.buf_rd_chn(buf_rd_chn14),.buf_run(buf_run14),.buf_rdata_chn(buf_rdata_chn14));
  `endif
`endif    

`ifdef def_enable_mem_chn15
    mcont_common_chnbuf_reg #( .CHN_NUMBER(15)) mcont_common_chnbuf_reg15_i(.rst(rst),.clk(mclk), .ext_buf_rchn(ext_buf_rchn),
        .ext_buf_rrefresh(ext_buf_rrefresh),.ext_buf_rpage_nxt(ext_buf_rpage_nxt),.seq_done(sequencer_run_done),
        .buf_done(seq_done15),.rpage_nxt(rpage_nxt_chn15));
  `ifdef def_read_mem_chn15
    mcont_to_chnbuf_reg #(.CHN_NUMBER( 15)) mcont_to_chnbuf_reg15_i(.rst(rst),.clk(mclk),.ext_buf_wr(ext_buf_wr),
        .ext_buf_wpage_nxt(ext_buf_wpage_nxt),.ext_buf_wchn(ext_buf_wchn), .ext_buf_wrefresh(ext_buf_wrefresh),
        .ext_buf_wrun(ext_buf_wrun),.ext_buf_wdata(ext_buf_wdata),.buf_wr_chn(buf_wr_chn15),
        .buf_wpage_nxt_chn(buf_wpage_nxt_chn15),.buf_run(buf_run15),.buf_wdata_chn(buf_wdata_chn15));
  `else
    wire [63:0] ext_buf_rdata15;
    mcont_from_chnbuf_reg #(.CHN_NUMBER( 15),.CHN_LATENCY(CHNBUF_READ_LATENCY)) mcont_from_chnbuf_reg15_i (.rst(rst),.clk(mclk),
        .ext_buf_rd(ext_buf_rd),.ext_buf_rchn(ext_buf_rchn), .ext_buf_rrefresh(ext_buf_rrefresh), .ext_buf_rrun(ext_buf_rrun),
        .ext_buf_rdata(ext_buf_rdata15),.buf_rd_chn(buf_rd_chn15),.buf_run(buf_run15),.buf_rdata_chn(buf_rdata_chn15));
  `endif
`endif

/// Combine read data from multiple channel buffers
wire [3:0] ext_buf_rchn_late;
wire       ext_buf_rd_late; 
localparam [3:0] EXT_READ_LATENCY=CHNBUF_READ_LATENCY+1;
    dly_16 #(
        .WIDTH(5)
    ) dly_16_i (
        .clk(mclk), // input
        .rst(rst), // input
        .dly(EXT_READ_LATENCY), // input[3:0] 
        .din({~ext_buf_rrefresh & ext_buf_rd,ext_buf_rchn}), // input[0:0] 
        .dout({ext_buf_rd_late,ext_buf_rchn_late}) // output[0:0] 
    );
always @ (posedge mclk) if (ext_buf_rd_late) begin
    case (ext_buf_rchn_late)
`ifdef def_enable_mem_chn0
  `ifndef def_read_mem_chn0
        4'h0:ext_buf_rdata <= ext_buf_rdata0;
  `endif
`endif    
`ifdef def_enable_mem_chn1
  `ifndef def_read_mem_chn1
        4'h1:ext_buf_rdata <= ext_buf_rdata1;
  `endif
`endif    
`ifdef def_enable_mem_chn2
  `ifndef def_read_mem_chn2
        4'h2:ext_buf_rdata <= ext_buf_rdata2;
  `endif
`endif    
`ifdef def_enable_mem_chn3
  `ifndef def_read_mem_chn3
        4'h3:ext_buf_rdata <= ext_buf_rdata3;
  `endif
`endif    
`ifdef def_enable_mem_chn4
  `ifndef def_read_mem_chn4
        4'h4:ext_buf_rdata <= ext_buf_rdata4;
  `endif
`endif    
`ifdef def_enable_mem_chn5
  `ifndef def_read_mem_chn5
        4'h5:ext_buf_rdata <= ext_buf_rdata5;
  `endif
`endif    
`ifdef def_enable_mem_chn6
  `ifndef def_read_mem_chn6
        4'h6:ext_buf_rdata <= ext_buf_rdata6;
  `endif
`endif    
`ifdef def_enable_mem_chn7
  `ifndef def_read_mem_chn7
        4'h7:ext_buf_rdata <= ext_buf_rdata7;
  `endif
`endif    
`ifdef def_enable_mem_chn8
  `ifndef def_read_mem_chn8
        4'h8:ext_buf_rdata <= ext_buf_rdata8;
  `endif
`endif    
`ifdef def_enable_mem_chn9
  `ifndef def_read_mem_chn9
        4'h9:ext_buf_rdata <= ext_buf_rdata9;
  `endif
`endif    
`ifdef def_enable_mem_chn10
  `ifndef def_read_mem_chn10
        4'h10:ext_buf_rdata <= ext_buf_rdata10;
  `endif
`endif    
`ifdef def_enable_mem_chn11
  `ifndef def_read_mem_chn11
        4'h11:ext_buf_rdata <= ext_buf_rdata11;
  `endif
`endif    
`ifdef def_enable_mem_chn12
  `ifndef def_read_mem_chn12
        4'h12:ext_buf_rdata <= ext_buf_rdata12;
  `endif
`endif    
`ifdef def_enable_mem_chn13
  `ifndef def_read_mem_chn13
        4'h13:ext_buf_rdata <= ext_buf_rdata13;
  `endif
`endif    
`ifdef def_enable_mem_chn14
  `ifndef def_read_mem_chn14
        4'h14:ext_buf_rdata <= ext_buf_rdata14;
  `endif
`endif    
`ifdef def_enable_mem_chn15
  `ifndef def_read_mem_chn15
        4'h15:ext_buf_rdata <= ext_buf_rdata15;
  `endif
`endif    
        default: ext_buf_rdata <= 'bx;
    endcase
end  
  
// combining channel control signals to buses
`ifndef def_enable_mem_chn0
    wire   want_rq0=0, need_rq0=0;
`endif
`ifndef def_enable_mem_chn1
    wire   want_rq1=0, need_rq1=0;
`endif  
`ifndef def_enable_mem_chn2
    wire   want_rq2=0, need_rq2=0;
`endif  
`ifndef def_enable_mem_chn3
    wire   want_rq3=0, need_rq3=0;
`endif  
`ifndef def_enable_mem_chn4
    wire   want_rq4=0, need_rq4=0;
`endif  
`ifndef def_enable_mem_chn5
    wire   want_rq5=0, need_rq5=0;
`endif  
`ifndef def_enable_mem_chn6
    wire   want_rq6=0, need_rq6=0;
`endif  
`ifndef def_enable_mem_chn7
    wire   want_rq7=0, need_rq7=0;
`endif  
`ifndef def_enable_mem_chn8
    wire   want_rq8=0, need_rq8=0;
`endif  
`ifndef def_enable_mem_chn9
    wire   want_rq9=0, need_rq9=0;
`endif  
`ifndef def_enable_mem_chn10
    wire   want_rq10=0, need_rq10=0;
`endif  
`ifndef def_enable_mem_chn11
    wire   want_rq11=0, need_rq11=0;
`endif  
`ifndef def_enable_mem_chn12
    wire   want_rq12=0, need_rq12=0;
`endif  
`ifndef def_enable_mem_chn13
    wire   want_rq13=0, need_rq13=0;
`endif  
`ifndef def_enable_mem_chn14
    wire   want_rq14=0, need_rq14=0;
`endif  
`ifndef def_enable_mem_chn15
    wire   want_rq15=0, need_rq15=0;
`endif  

assign want_rq[15:0]=   {want_rq15,want_rq14,want_rq13,want_rq12,want_rq11,want_rq10,want_rq9,want_rq8,
                         want_rq7,want_rq6,want_rq5,want_rq4,want_rq3,want_rq2,want_rq1,want_rq0};  
assign need_rq[15:0]=   {need_rq15,need_rq14,need_rq13,need_rq12,need_rq11,need_rq10,need_rq9,need_rq8,
                         need_rq7,need_rq6,need_rq5,need_rq4,need_rq3,need_rq2,need_rq1,need_rq0};

always @ (posedge rst or posedge mclk) begin
    if (rst) begin seq_data <= 0; seq_wr <=0; seq_set <=0; end
    else begin
        case (cmd_wr_chn)
`ifdef def_enable_mem_chn0
            4'h0:begin seq_data <= seq_data0; seq_wr <= seq_wr0; seq_set <= seq_set0; end
`endif
`ifdef def_enable_mem_chn1
            4'd1:begin seq_data <= seq_data1; seq_wr <= seq_wr1; seq_set <= seq_set1; end
`endif
`ifdef def_enable_mem_chn2
            4'd2:begin seq_data <= seq_data2; seq_wr <= seq_wr2; seq_set <= seq_set2; end
`endif
`ifdef def_enable_mem_chn3
            4'd3:begin seq_data <= seq_data3; seq_wr <= seq_wr3; seq_set <= seq_set3; end
`endif
`ifdef def_enable_mem_chn4
            4'd4:begin seq_data <= seq_data4; seq_wr <= seq_wr4; seq_set <= seq_set4; end
`endif
`ifdef def_enable_mem_chn5
            4'd5:begin seq_data <= seq_data5; seq_wr <= seq_wr5; seq_set <= seq_set5; end
`endif
`ifdef def_enable_mem_chn6
            4'd6:begin seq_data <= seq_data6; seq_wr <= seq_wr6; seq_set <= seq_set6; end
`endif
`ifdef def_enable_mem_chn7
            4'd7:begin seq_data <= seq_data7; seq_wr <= seq_wr7; seq_set <= seq_set7; end
`endif
`ifdef def_enable_mem_chn8
            4'd8:begin seq_data <= seq_data8; seq_wr <= seq_wr8; seq_set <= seq_set8; end
`endif
`ifdef def_enable_mem_chn9
            4'd9:begin seq_data <= seq_data9; seq_wr <= seq_wr9; seq_set <= seq_set9; end
`endif
`ifdef def_enable_mem_chn10
            4'd10:begin seq_data <= seq_data10; seq_wr <= seq_wr10; seq_set <= seq_set10; end
`endif
`ifdef def_enable_mem_chn11
            4'd11:begin seq_data <= seq_data11; seq_wr <= seq_wr11; seq_set <= seq_set11; end
`endif
`ifdef def_enable_mem_chn12
            4'd12:begin seq_data <= seq_data12; seq_wr <= seq_wr12; seq_set <= seq_set12; end
`endif
`ifdef def_enable_mem_chn13
            4'd13:begin seq_data <= seq_data13; seq_wr <= seq_wr13; seq_set <= seq_set13; end
`endif
`ifdef def_enable_mem_chn14
            4'd14:begin seq_data <= seq_data14; seq_wr <= seq_wr14; seq_set <= seq_set14; end
`endif
`ifdef def_enable_mem_chn15
            4'd15:begin seq_data <= seq_data15; seq_wr <= seq_wr15; seq_set <= seq_set15; end
`endif
        endcase
    end
end   



`ifdef def_enable_mem_chn0
    always @ (posedge mclk) channel_pgm_en0 <= grant && (grant_chn == 0);
`endif
`ifdef def_enable_mem_chn1
    always @ (posedge mclk) channel_pgm_en1 <= grant && (grant_chn == 1);
`endif
`ifdef def_enable_mem_chn2
    always @ (posedge mclk) channel_pgm_en2 <= grant && (grant_chn == 2);
`endif
`ifdef def_enable_mem_chn3
    always @ (posedge mclk) channel_pgm_en3 <= grant && (grant_chn == 3);
`endif
`ifdef def_enable_mem_chn4
    always @ (posedge mclk) channel_pgm_en4 <= grant && (grant_chn == 4);
`endif
`ifdef def_enable_mem_chn5
    always @ (posedge mclk) channel_pgm_en5 <= grant && (grant_chn == 5);
`endif
`ifdef def_enable_mem_chn6
    always @ (posedge mclk) channel_pgm_en6 <= grant && (grant_chn == 6);
`endif
`ifdef def_enable_mem_chn7
    always @ (posedge mclk) channel_pgm_en7 <= grant && (grant_chn == 7);
`endif
`ifdef def_enable_mem_chn8
    always @ (posedge mclk) channel_pgm_en8 <= grant && (grant_chn == 8);
`endif
`ifdef def_enable_mem_chn9
    always @ (posedge mclk) channel_pgm_en9 <= grant && (grant_chn == 9);
`endif
`ifdef def_enable_mem_chn10
    always @ (posedge mclk) channel_pgm_en10 <= grant && (grant_chn == 10);
`endif
`ifdef def_enable_mem_chn11
    always @ (posedge mclk) channel_pgm_en11 <= grant && (grant_chn == 11);
`endif
`ifdef def_enable_mem_chn12
    always @ (posedge mclk) channel_pgm_en12 <= grant && (grant_chn == 12);
`endif
`ifdef def_enable_mem_chn13
    always @ (posedge mclk) channel_pgm_en13 <= grant && (grant_chn == 13);
`endif
`ifdef def_enable_mem_chn14
    always @ (posedge mclk) channel_pgm_en14 <= grant && (grant_chn == 14);
`endif
`ifdef def_enable_mem_chn15
    always @ (posedge mclk) channel_pgm_en15 <= grant && (grant_chn == 15);
`endif

endmodule

