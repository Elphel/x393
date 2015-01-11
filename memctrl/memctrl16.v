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
    parameter pri_width=16,
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
    parameter CMD_DONE_BIT=         10,
    parameter AXI_WR_ADDR_BITS =    13,
    parameter AXI_RD_ADDR_BITS =    13,
    parameter CONTROL_ADDR =        'h1000, // AXI write address of control write registers
    parameter CONTROL_ADDR_MASK =   'h1400, // AXI write address of control registers
    parameter STATUS_ADDR =         'h1400, // AXI write address of status read registers
    parameter STATUS_ADDR_MASK =    'h1400, // AXI write address of status registers
    parameter BUSY_WR_ADDR =        'h1800, // AXI write address to generate busy
    parameter BUSY_WR_ADDR_MASK =   'h1c00, // AXI write address mask to generate busy
    parameter CMD0_ADDR =           'h0800, // AXI write to command sequence memory
    parameter CMD0_ADDR_MASK =      'h1800, // AXI read address mask for the command sequence memory
    parameter PORT0_RD_ADDR =       'h0000, // AXI read address to generate busy
    parameter PORT0_RD_ADDR_MASK =  'h1c00, // AXI read address mask to generate busy
    parameter PORT1_WR_ADDR =       'h0400, // AXI read address to generate busy
    parameter PORT1_WR_ADDR_MASK =  'h1c00,  // AXI read address mask to generate busy
    // parameters below to be ORed with CONTROL_ADDR and CONTROL_ADDR_MASK respectively
    parameter DLY_LD_REL =            'h080,  // address to generate delay load
    parameter DLY_LD_REL_MASK =       'h380,  // address mask to generate delay load
    parameter DLY_SET_REL =           'h070,  // address to generate delay set
    parameter DLY_SET_REL_MASK =      'h3ff,  // address mask to generate delay set
    parameter RUN_CHN_REL =           'h000,  // address to set sequnecer channel and  run (4 LSB-s - channel)
    parameter RUN_CHN_REL_MASK =      'h3f0,  // address mask to generate sequencer channel/run
    parameter PATTERNS_REL =          'h020,  // address to set DQM and DQS patterns (16'h0055)
    parameter PATTERNS_REL_MASK =     'h3ff,  // address mask to set DQM and DQS patterns
    parameter PATTERNS_TRI_REL =      'h021,  // address to set DQM and DQS tristate on/off patterns {dqs_off,dqs_on, dq_off,dq_on} - 4 bits each
    parameter PATTERNS_TRI_REL_MASK = 'h3ff,  // address mask to set DQM and DQS tristate patterns
    parameter WBUF_DELAY_REL =        'h022,  // extra delay (in mclk cycles) to add to write buffer enable (DDR3 read data)
    parameter WBUF_DELAY_REL_MASK =   'h3ff,  // address mask to set extra delay
    parameter PAGES_REL =             'h023,  // address to set buffer pages {port1_page[1:0],port1_int_page[1:0],port0_page[1:0],port0_int_page[1:0]}
    parameter PAGES_REL_MASK =        'h3ff,  // address mask to set DQM and DQS patterns
    parameter CMDA_EN_REL =           'h024,  // address to enable('h825)/disable('h824) command/address outputs  
    parameter CMDA_EN_REL_MASK =      'h3fe,  // address mask for command/address outputs
    parameter SDRST_ACT_REL =         'h026,  // address to activate('h827)/deactivate('h826) active-low reset signal to DDR3 memory  
    parameter SDRST_ACT_REL_MASK =    'h3fe,  // address mask for reset DDR3
    parameter CKE_EN_REL =            'h028,  // address to enable('h829)/disable('h828) CKE signal to memory   
    parameter CKE_EN_REL_MASK =       'h3fe,  // address mask for command/address outputs
    parameter DCI_RST_REL =           'h02a,  // address to activate('h82b)/deactivate('h82a) Zynq DCI calibrate circuitry  
    parameter DCI_RST_REL_MASK =      'h3fe,  // address mask for DCI calibrate circuitry
    parameter DLY_RST_REL =           'h02c,  // address to activate('h82d)/deactivate('h82c) delay calibration circuitry  
    parameter DLY_RST_REL_MASK =      'h3fe,  // address mask for delay calibration circuitry
    parameter EXTRA_REL =             'h02e,  // address to set extra parameters (currently just inv_clk_div)
    parameter EXTRA_REL_MASK =        'h3ff,  // address mask for extra parameters
    parameter REFRESH_EN_REL =        'h030,  // address to enable('h31) and disable ('h30) DDR refresh
    parameter REFRESH_EN_REL_MASK =   'h3fe,  // address mask to enable/disable DDR refresh
    parameter REFRESH_PER_REL =       'h032,  // address to set refresh period in 32 x tCK
    parameter REFRESH_PER_REL_MASK =  'h3ff,  // address mask set refresh period
    parameter REFRESH_ADDR_REL =      'h033,  // address to set sequencer start address for DDR refresh
    parameter REFRESH_ADDR_REL_MASK = 'h3ff   // address mask set refresh sequencer address
    ) (
    input             rst,
    input             clk,
    input      [15:0] want_rq,   // both want_rq and need_rq should go inactive after being granted  
    input      [15:0] need_rq,
    output     [15:0] channel_pgm_en, // channel can program sequence data
    input     [511:0] seq_data,  //16x32 data to be written to the sequencer (and start address for software-based sequencer)
    input      [15:0] seq_wr,    // strobe for writing sequencer data (address is autoincremented)
    input      [15:0] seq_done,  // channel sequencer data is written. If no seq_wr pulses before seq_done, seq_data contains software sequencer start address
    
    // priority programming
    // TODO: Move to ps7 instance in this module
    input       [3:0] pgm_addr,  // channel address to program priority
    input [width-1:0] pgm_data,  // priority data for the channel
    input             pgm_en,     // enable programming priority data (use different clock?)
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
//    input                        MEMCLK
);
// TODO: copy from ddrc_test01.v    


endmodule

