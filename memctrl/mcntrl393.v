/*******************************************************************************
 * Module: mcntrl393
 * Date:2015-01-31  
 * Author: andrey     
 * Description: Top level memory controller for 393 camera, includes channel buffers
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * mcntrl393.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  mcntrl393.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  mcntrl393 #(
// AXI
    parameter AXI_WR_ADDR_BITS =    13,
    parameter AXI_RD_ADDR_BITS =    13,
// buffers (1k='h400 each) map, addresses and masks are in 32-bit words, not bytes
    parameter MCONTR_WR_MASK =       'h1c00, // AXI write address mask for the 1Kx32 buffers command sequence memory
    parameter MCONTR_RD_MASK =       'h1c00, // AXI read address mask to generate busy

    parameter MCONTR_CMD_WR_ADDR =   'h0000, // AXI write to command sequence memory
    parameter MCONTR_BUF0_RD_ADDR =  'h0400, // AXI read address from buffer 0 (PS sequence, memory read) 
    parameter MCONTR_BUF1_WR_ADDR =  'h0400, // AXI write address to buffer 1 (PS sequence, memory write)
    parameter MCONTR_BUF2_RD_ADDR =  'h0800, // AXI read address from buffer 2 (PL sequence, scanline, memory read)
    parameter MCONTR_BUF3_WR_ADDR =  'h0800, // AXI write address to buffer 3 (PL sequence, scanline, memory write)
    parameter MCONTR_BUF4_RD_ADDR =  'h0c00, // AXI read address from buffer 4 (PL sequence, tiles, memory read)

    
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


    parameter ADDRESS_NUMBER=       15,
    parameter COLADDR_NUMBER=       10,
     
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
//    
    parameter MCNTRL_PS_ADDR=                    'h100,
    parameter MCNTRL_PS_MASK=                    'h3e0, // both channels 0 and 1
    parameter MCNTRL_PS_STATUS_REG_ADDR=         'h2,
    parameter MCNTRL_PS_EN_RST=                  'h0,
    parameter MCNTRL_PS_CMD=                     'h1,
    parameter MCNTRL_PS_STATUS_CNTRL=            'h2,

    parameter NUM_XFER_BITS=                       6,    // number of bits to specify transfer length
    parameter FRAME_WIDTH_BITS=                   13,    // Maximal frame width - 8-word (16 bytes) bursts 
    parameter FRAME_HEIGHT_BITS=                  16,    // Maximal frame height 
    parameter MCNTRL_SCANLINE_CHN2_ADDR=         'h120,
    parameter MCNTRL_SCANLINE_CHN3_ADDR=         'h130,
    parameter MCNTRL_SCANLINE_MASK=              'h3f0, // both channels 0 and 1
    parameter MCNTRL_SCANLINE_MODE=              'h0,   // set mode register: {extra_pages[1:0],write_mode,enable,!reset}
    parameter MCNTRL_SCANLINE_STATUS_CNTRL=      'h1,   // control status reporting
    parameter MCNTRL_SCANLINE_STARTADDR=         'h2,   // 22-bit frame start address (3 CA LSBs==0. BA==0)
    parameter MCNTRL_SCANLINE_FRAME_FULL_WIDTH=  'h3,   // Padded line length (8-row increment), in 8-bursts (16 bytes)
    parameter MCNTRL_SCANLINE_WINDOW_WH=         'h4,   // low word - 13-bit window width (0->'n4000), high word - 16-bit frame height (0->'h10000)
    parameter MCNTRL_SCANLINE_WINDOW_X0Y0=       'h5,   // low word - 13-bit window left, high word - 16-bit window top
    parameter MCNTRL_SCANLINE_WINDOW_STARTXY=    'h6,   // low word - 13-bit start X (relative to window), high word - 16-bit start y
                                                        // Start XY can be used when read command to start from the middle
                                                        // TODO: Add number of blocks to R/W? (blocks can be different) - total length?
                                                        // Read back current address (for debugging)?
//    parameter MCNTRL_SCANLINE_STATUS_REG_ADDR=   'h4,
    parameter MCNTRL_SCANLINE_STATUS_REG_CHN2_ADDR=   'h4,
    parameter MCNTRL_SCANLINE_STATUS_REG_CHN3_ADDR=   'h5,

    parameter MCNTRL_SCANLINE_PENDING_CNTR_BITS=   2,    // Number of bits to count pending trasfers, currently 2 is enough, but may increase
                                                        // if memory controller will allow programming several sequences in advance to
                                                        // spread long-programming (tiled) over fast-programming (linear) requests.
                                                        // But that should not be too big to maintain 2-level priorities
    
    parameter MAX_TILE_WIDTH=                   6,     // number of bits to specify maximal tile (width-1) (6 -> 64)
    parameter MAX_TILE_HEIGHT=                  6,     // number of bits to specify maximal tile (height-1) (6 -> 64)
    parameter MCNTRL_TILED_CHN4_ADDR=       'h140,
    parameter MCNTRL_TILED_MASK=            'h3f0, // both channels 0 and 1
    parameter MCNTRL_TILED_MODE=            'h0,   // set mode register: {extra_pages[1:0],write_mode,enable,!reset}
    parameter MCNTRL_TILED_STATUS_CNTRL=    'h1,   // control status reporting
    parameter MCNTRL_TILED_STARTADDR=       'h2,   // 22-bit frame start address (3 CA LSBs==0. BA==0)
    parameter MCNTRL_TILED_FRAME_FULL_WIDTH='h3,   // Padded line length (8-row increment), in 8-bursts (16 bytes)
    parameter MCNTRL_TILED_WINDOW_WH=       'h4,   // low word - 13-bit window width (0->'n4000), high word - 16-bit frame height (0->'h10000)
    parameter MCNTRL_TILED_WINDOW_X0Y0=     'h5,   // low word - 13-bit window left, high word - 16-bit window top
    parameter MCNTRL_TILED_WINDOW_STARTXY=  'h6,   // low word - 13-bit start X (relative to window), high word - 16-bit start y
                                                      // Start XY can be used when read command to start from the middle
                                                      // TODO: Add number of blocks to R/W? (blocks can be different) - total length?
                                                      // Read back current address (for debugging)?
    parameter MCNTRL_TILED_TILE_WH=         'h7,   // low word - 6-bit tile width in 8-bursts, high - tile height (0 - > 64)
    parameter MCNTRL_TILED_STATUS_REG_CHN4_ADDR= 'h5,
    parameter MCNTRL_TILED_PENDING_CNTR_BITS=2,    // Number of bits to count pending trasfers, currently 2 is enough, but may increase
                                                   // if memory controller will allow programming several sequences in advance to
                                                   // spread long-programming (tiled) over fast-programming (linear) requests.
                                                   // But that should not be too big to maintain 2-level priorities
    parameter MCNTRL_TILED_FRAME_PAGE_RESET =1'b0,  // reset internal page number to zero at the frame start (false - only when hard/soft reset)                                                     
    parameter BUFFER_DEPTH32=                10    // Block rum buffer depth on a 32-bit port
    
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
    

// interface to PIO RD/WR, sync to axi_clk
    input                        axi_clk,   // common for read and write channels

    input [AXI_WR_ADDR_BITS-1:0] axiwr_pre_awaddr, // same as awaddr_out, early address to decode and return dev_ready
    input                        axiwr_start_burst, // start of write burst, valid pre_awaddr, save externally to control ext. dev_ready multiplexer
//   wire           axiwr_dev_ready;   // extrernal combinatorial ready signal, multiplexed from different sources according to pre_awaddr@start_burst
//   wire           axiwr_bram_wclk;
//   wire  [AXI_WR_ADDR_BITS-1:0] axiwr_bram_waddr;
    input   [BUFFER_DEPTH32-1:0] axiwr_waddr,
//    wire                         axiwr_bram_wen;    // external memory write enable, (internally combined with registered dev_ready
    input                        axiwr_wen,    // external memory write enable, (internally combined with registered dev_ready
// SuppressWarnings VEditor unused (yet?) 
//   wire    [3:0]  axiwr_bram_wstb; 
//   wire   [31:0]  axiwr_bram_wdata;
    input                [31:0]  axiwr_data,
        
// External memory synchronization
    input [AXI_RD_ADDR_BITS-1:0] axird_pre_araddr, // same as awaddr_out, early address to decode and return dev_ready
    input                        axird_start_burst, // start of read burst, valid pre_araddr, save externally to control ext. dev_ready multiplexer
//   wire           axird_dev_ready;   // extrernal combinatorial ready signal, multiplexed from different sources according to pre_araddr@start_burst
// External memory interface   
// SuppressWarnings VEditor unused (yet?) - use mclk 
//   wire           axird_bram_rclk;  //      .rclk(aclk),                  // clock for read port
//    wire [AXI_RD_ADDR_BITS-1:0] axird_bram_raddr, //   .raddr(read_in_progress?read_address[9:0]:10'h3ff),    // read address
    input   [BUFFER_DEPTH32-1:0] axird_raddr, //   .raddr(read_in_progress?read_address[9:0]:10'h3ff),    // read address
//    wire                        axird_bram_ren,   //      .ren(bram_reg_re_w) ,      // read port enable
    input                        axird_ren,   //      .ren(bram_reg_re_w) ,      // read port enable
//   wire           axird_bram_regen; //   .regen(bram_reg_re_w),        // output register enable
    input                        axird_regen, //==axird_ren?? - remove?   .regen(bram_reg_re_w),        // output register enable
//   wire  [31:0]   axird_bram_rdata;  //      .data_out(rdata[31:0]),       // data out
    output              [31:0]   axird_rdata,  // combinatorial multiplexed (add external register layer, modify axibram_read?)     .data_out(rdata[31:0]),       // data out
    output                       axird_selected, // axird_rdata contains cvalid data from this module 
//   wire  [31:0]   port0_rdata;  //
//   wire  [31:0]   status_rdata;  //

// Channels 2 and 3 control signals
// TODO: move line_unfinished and suspend to internals of this module (and control comparator modes)
    input                          frame_start_chn2,   // resets page, x,y, and initiates transfer requests (in write mode will wait for next_page)
    input                          next_page_chn2,     // page was read/written from/to 4*1kB on-chip buffer
    output                         page_ready_chn2,    // == xfer_done, connect externally | Single-cycle pulse indicating that a page was read/written from/to DDR3 memory
    output                         frame_done_chn2,    // single-cycle pulse when the full frame (window) was transferred to/from DDR3 memory
// optional I/O for channel synchronization
    output [FRAME_HEIGHT_BITS-1:0] line_unfinished_chn2, // number of the current (ufinished ) line, REALATIVE TO FRAME, NOT WINDOW?. 
    input                          suspend_chn2,       // suspend transfers (from external line number comparator)

    input                          frame_start_chn3,   // resets page, x,y, and initiates transfer requests (in write mode will wait for next_page)
    input                          next_page_chn3,     // page was read/written from/to 4*1kB on-chip buffer
    output                         page_ready_chn3,    // == xfer_done, connect externally | Single-cycle pulse indicating that a page was read/written from/to DDR3 memory
    output                         frame_done_chn3,    // single-cycle pulse when the full frame (window) was transferred to/from DDR3 memory
// optional I/O for channel synchronization
    output [FRAME_HEIGHT_BITS-1:0] line_unfinished_chn3, // number of the current (ufinished ) line, REALATIVE TO FRAME, NOT WINDOW?. 
    input                          suspend_chn3,       // suspend transfers (from external line number comparator)
// Channel 4 (tiled tes)
    input                          frame_start_chn4,   // resets page, x,y, and initiates transfer requests (in write mode will wait for next_page)
    input                          next_page_chn4,     // page was read/written from/to 4*1kB on-chip buffer
    output                         page_ready_chn4,    // == xfer_done, connect externally | Single-cycle pulse indicating that a page was read/written from/to DDR3 memory
    output                         frame_done_chn4,    // single-cycle pulse when the full frame (window) was transferred to/from DDR3 memory
// optional I/O for channel synchronization
    output [FRAME_HEIGHT_BITS-1:0] line_unfinished_chn4, // number of the current (ufinished ) line, REALATIVE TO FRAME, NOT WINDOW?. 
    input                          suspend_chn4,       // suspend transfers (from external line number comparator)



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
    
    wire rst=rst_in;
    wire axi_rst=rst_in; 

// Not yet connected
//    wire                  [7:0] status_other_ad;    // Other status byte-wide address/data 
//    wire                        status_other_rq;    // Other status request  
//    wire                        status_other_start; // Other status packet transfer start (currently with 0 latency from status_root_rq)

//cmd_ps_pio_stb

// command port 0 (filled by software - 32w->32r) - used for mode set, refresh, write levelling, ...
// TODO: move to internal !

// Interface to channels to read/write memory (including 4 page BRAM buffers)

    wire        want_rq0;
    wire        need_rq0;
    wire        channel_pgm_en0; 
    wire  [9:0] seq_data0; // only 10 bits used
//    wire        seq_wr0; // not used
    wire        seq_set0;
    wire        seq_done0;
//    wire        rpage_nxt_chn0;
    wire        buf_wr_chn0;
    wire        buf_wpage_nxt_chn0;
    wire [63:0] buf_wdata_chn0;
     
    wire        want_rq1;
    wire        need_rq1;
    wire        channel_pgm_en1; 
    wire        seq_done1;
    wire        rpage_nxt_chn1;
    wire        buf_rd_chn1;
    wire [63:0] buf_rdata_chn1;

    wire        want_rq2;
    wire        need_rq2;
    wire        channel_pgm_en2; 
    wire [31:0] seq_data2x;  // may be shared with other channel 
    wire        seq_wr2x; // may be shared with other channel
    wire        seq_set2x; // may be shared with other channel
    wire        seq_done2;
//    wire        rpage_nxt_chn2;
    wire        buf_wr_chn2;
    wire        buf_wpage_nxt_chn2;
    wire [63:0] buf_wdata_chn2;
     
    wire        want_rq3;
    wire        need_rq3;
    wire        channel_pgm_en3; 
    wire [31:0] seq_data3x; // may be shared with other channel
    wire        seq_wr3x; // may be shared with other channel
    wire        seq_set3x; // may be shared with other channel
    wire        seq_done3;
    wire        rpage_nxt_chn3;
    wire        buf_rd_chn3;
    wire [63:0] buf_rdata_chn3;
    
    wire        want_rq4;
    wire        need_rq4;
    wire        channel_pgm_en4; 
    
//    wire        seq_tiled_start_rd; 
    wire [31:0] seq_data4x; // may be shared with other channel
    wire        seq_wr4x;   // may be shared with other channel
    wire        seq_set4x;  // may be shared with other channel
    
    wire        seq_done4;
    wire        rpage_nxt_chn4;
    wire        buf_wr_chn4;
    wire        buf_wpage_nxt_chn4;
    wire [63:0] buf_wdata_chn4;

    // Command tree - insert register layer if needed
    wire [7:0] cmd_mcontr_ad;
    wire       cmd_mcontr_stb;
    wire [7:0] cmd_ps_pio_ad;
    wire       cmd_ps_pio_stb;
    wire [7:0] cmd_scanline_chn2_ad;
    wire       cmd_scanline_chn2_stb;
    wire [7:0] cmd_scanline_chn3_ad;
    wire       cmd_scanline_chn3_stb;
    wire [7:0] cmd_tiled_chn4_ad;
    wire       cmd_tiled_chn4_stb;


// Status tree:
    wire                  [7:0] status_mcontr_ad;    // Memory controller status byte-wide address/data 
    wire                        status_mcontr_rq;    // Memory controller status request  
    wire                        status_mcontr_start; // Memory controller status packet transfer start (currently with 0 latency from status_root_rq)

    wire                  [7:0] status_ps_pio_ad;    // PS PIO channels status byte-wide address/data 
    wire                        status_ps_pio_rq;    // PS PIO channels status request  
    wire                        status_ps_pio_start; // PS PIO channels status packet transfer start (currently with 0 latency from status_root_rq)
    
    wire                  [7:0] status_scanline_chn2_ad;    // PS scanline channel2 (memory read) status byte-wide address/data 
    wire                        status_scanline_chn2_rq;    // PS scanline channel2 (memory read) channels status request  
    wire                        status_scanline_chn2_start; // PS scanline channel2 (memory read) channels status packet transfer start (currently with 0 latency from status_root_rq)

    wire                  [7:0] status_scanline_chn3_ad;    // PS scanline channel3 (memory read) status byte-wide address/data 
    wire                        status_scanline_chn3_rq;    // PS scanline channel3 (memory read) channels status request  
    wire                        status_scanline_chn3_start; // PS scanline channel3 (memory read) channels status packet transfer start (currently with 0 latency from status_root_rq)

    wire                  [7:0] status_tiled_chn4_ad;    // PS tiled channel4 (memory read) status byte-wide address/data 
    wire                        status_tiled_chn4_rq;    // PS tiled channel4 (memory read) channels status request  
    wire                        status_tiled_chn4_start; // PS tiled channel4 (memory read) channels status packet transfer start (currently with 0 latency from status_root_rq)

// combinatorial early signals
    wire                         select_cmd0_w;
    wire                         select_buf0_w;
    wire                         select_buf1_w;
    wire                         select_buf2_w;
    wire                         select_buf3_w;
    wire                         select_buf4_w;
// registered selects
    reg                         select_cmd0;
    reg                         select_buf0;
    reg                         select_buf1;
    reg                         select_buf2;
    reg                         select_buf3;
    reg                         select_buf4;

    reg                         select_buf0_d; // delayed by 1 clock, for combining with regen?
    reg                         select_buf2_d;
    reg                         select_buf4_d;

    reg                         axird_selected_r; // this module provides output
    
// Buffers R/W from AXI
    reg   [BUFFER_DEPTH32-1:0]  buf_waddr;
    reg                 [31:0]  buf_wdata;
    reg                         cmd_we;
    reg                         buf1_we;
    reg                         buf3_we;
    wire  [BUFFER_DEPTH32-1:0]  buf_raddr;
    
    wire                [31:0]  buf0_data;
    wire                [31:0]  buf2_data;
    wire                [31:0]  buf4_data;
    
    wire                        buf0_rd;
    wire                        buf0_regen;
    wire                        buf2_rd;
    wire                        buf2_regen;
    wire                        buf4_rd;
    wire                        buf4_regen;

// common for channels 2 and 3
    wire                [2:0] lin_rw_bank;     // memory bank
    wire [ADDRESS_NUMBER-1:0] lin_rw_row;      // memory row
    wire [COLADDR_NUMBER-4:0] lin_rw_col;      // start memory column in 8-bursts
    wire                [5:0] lin_rw_num128;   // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    wire                      lin_rd_start;    // start generating commands for read sequence
    wire                      lin_wr_start;    // start generating commands for write sequence

    wire                  [2:0] lin_rd_chn2_bank;   // bank address
    wire   [ADDRESS_NUMBER-1:0] lin_rd_chn2_row;    // memory row
    wire   [COLADDR_NUMBER-4:0] lin_rd_chn2_col;    // start memory column in 8-bursts
    wire                  [5:0] lin_rd_chn2_num128; // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    wire                        lin_rd_chn2_start;  // start generating commands
//    wire                  [1:0] xfer_page2;         // "internal" buffer page
    wire                        xfer_reset_page2_pos;         // "internal" buffer page reset, @posedge mclk
    reg                         xfer_reset_page2_neg;         // "internal" buffer page reset, @negedge mclk
    
    wire                  [2:0] lin_wr_chn3_bank;   // bank address
    wire   [ADDRESS_NUMBER-1:0] lin_wr_chn3_row;    // memory row
    wire   [COLADDR_NUMBER-4:0] lin_wr_chn3_col;    // start memory column in 8-bursts
    wire                  [5:0] lin_wr_chn3_num128; // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    wire                        lin_wr_chn3_start;  // start generating commands
//    wire                  [1:0] xfer_page3;       // "internal" buffer page
    wire                        xfer_reset_page3;   // "internal" buffer page reset, @posedge mclk


    wire                  [2:0] tiled_rd_bank;   // bank address
    wire   [ADDRESS_NUMBER-1:0] tiled_rd_row;    // memory row
    wire   [COLADDR_NUMBER-4:0] tiled_rd_col;    // start memory column in 8-bursts
    wire   [FRAME_WIDTH_BITS:0] tiled_rd_rowcol_inc; // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    wire   [MAX_TILE_WIDTH-1:0] tiled_rd_num_rows_m1; // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    wire  [MAX_TILE_HEIGHT-1:0] tiled_rd_num_cols_m1; // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    wire                        tiled_rd_keep_open;  // start generating commands
    wire                        tiled_rd_xfer_partial;  // start generating commands
    wire                        tiled_rd_start;  // start generating commands

    wire                  [2:0] tiled_rd_chn4_bank;   // bank address
    wire   [ADDRESS_NUMBER-1:0] tiled_rd_chn4_row;    // memory row
    wire   [COLADDR_NUMBER-4:0] tiled_rd_chn4_col;    // start memory column in 8-bursts
    wire   [FRAME_WIDTH_BITS:0] tiled_rd_chn4_rowcol_inc; // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    wire   [MAX_TILE_WIDTH-1:0] tiled_rd_chn4_num_rows_m1; // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    wire  [MAX_TILE_HEIGHT-1:0] tiled_rd_chn4_num_cols_m1; // number of 128-bit words to transfer (8*16 bits) - full bursts of 8 ( 0 - maximal length, 64)
    wire                        tiled_rd_chn4_keep_open;  // start generating commands
    wire                        tiled_rd_chn4_xfer_partial;  // start generating commands
    wire                        tiled_rd_chn4_start;  // start generating commands
    wire                        xfer_reset_page4_pos;         // "internal" buffer page reset, @posedge mclk
    reg                         xfer_reset_page4_neg;         // "internal" buffer page reset, @negedge mclk


    

    // Command tree - insert register layer(s) if needed, now just direct assignments
    assign cmd_mcontr_ad=        cmd_ad;
    assign cmd_mcontr_stb=       cmd_stb;
    assign cmd_ps_pio_ad=        cmd_ad;
    assign cmd_ps_pio_stb=       cmd_stb;
    assign cmd_scanline_chn2_ad= cmd_ad;
    assign cmd_scanline_chn2_stb=cmd_stb;
    assign cmd_scanline_chn3_ad= cmd_ad;
    assign cmd_scanline_chn3_stb=cmd_stb;
    assign cmd_tiled_chn4_ad=    cmd_ad;
    assign cmd_tiled_chn4_stb=   cmd_stb;

    
    
// For now - combinatorial, maybe add registers (modify axibram_read)
    assign buf_raddr=axird_raddr;    
    assign axird_rdata = (select_buf0 ? buf0_data : 32'b0) | (select_buf2 ? buf2_data : 32'b0) | (select_buf4 ? buf4_data : 32'b0); 
    
    assign buf0_rd=    axird_ren   && select_buf0;
    assign buf0_regen= axird_regen && select_buf0_d;
    assign buf2_rd=    axird_ren   && select_buf2;
    assign buf2_regen= axird_regen && select_buf2_d;
    assign buf4_rd=    axird_ren   && select_buf4;
    assign buf4_regen= axird_regen && select_buf4_d;
    
    assign page_ready_chn2=seq_done2;
    assign page_ready_chn3=seq_done3;
    assign page_ready_chn4=rpage_nxt_chn4;
    
    
    assign axird_selected=axird_selected_r;
    assign select_cmd0_w = ((axiwr_pre_awaddr ^ MCONTR_CMD_WR_ADDR) & MCONTR_WR_MASK)==0;
    assign select_buf0_w = ((axird_pre_araddr ^ MCONTR_BUF0_RD_ADDR) & MCONTR_RD_MASK)==0;
    assign select_buf1_w = ((axiwr_pre_awaddr ^ MCONTR_BUF1_WR_ADDR) & MCONTR_WR_MASK)==0;
    assign select_buf2_w = ((axird_pre_araddr ^ MCONTR_BUF2_RD_ADDR) & MCONTR_RD_MASK)==0;
    assign select_buf3_w = ((axiwr_pre_awaddr ^ MCONTR_BUF3_WR_ADDR) & MCONTR_WR_MASK)==0;
    assign select_buf4_w = ((axird_pre_araddr ^ MCONTR_BUF4_RD_ADDR) & MCONTR_RD_MASK)==0;

    always @ (posedge axi_rst or posedge axi_clk) begin
        if      (axi_rst)           select_cmd0 <= 0;
        else if (axiwr_start_burst) select_cmd0 <= select_cmd0_w;
        
        if      (axi_rst)           select_buf0 <= 0;
        else if (axird_start_burst) select_buf0 <= select_buf0_w;
        
        if      (axi_rst)           select_buf1 <= 0;
        else if (axiwr_start_burst) select_buf1 <= select_buf1_w;
        
        if      (axi_rst)           select_buf2 <= 0;
        else if (axird_start_burst) select_buf2 <= select_buf2_w;
        
        if      (axi_rst)           select_buf3 <= 0;
        else if (axiwr_start_burst) select_buf3 <= select_buf3_w;
        
        if      (axi_rst)           select_buf4 <= 0;
        else if (axird_start_burst) select_buf4 <= select_buf4_w;

        if      (axi_rst)           axird_selected_r <= 0;
        else if (axird_start_burst) axird_selected_r <= select_buf0_w || select_buf1_w ||select_buf2_w;
    end
    always @ (posedge axi_clk) begin
        if (axiwr_wen) buf_wdata  <= axiwr_data;
        if (axiwr_wen) buf_waddr <= axiwr_waddr;
        cmd_we <=  axiwr_wen && select_cmd0;
        buf1_we <= axiwr_wen && select_buf1;
        buf3_we <= axiwr_wen && select_buf3;
        
        select_buf0_d <= select_buf0;
        select_buf2_d <= select_buf2;
        select_buf4_d <= select_buf4;
    end
   //axiwr_waddr 
    status_router16 status_router16_mctrl_top_i (
        .rst       (rst), // input
        .clk       (mclk), // input
        .db_in0    (status_mcontr_ad), // input[7:0] 
        .rq_in0    (status_mcontr_rq), // input
        .start_in0 (status_mcontr_start), // output
        .db_in1    (status_ps_pio_ad), // input[7:0] 
        .rq_in1    (status_ps_pio_rq), // input
        .start_in1 (status_ps_pio_start), // output
        .db_in2    (status_scanline_chn2_ad), // input[7:0] 
        .rq_in2    (status_scanline_chn2_rq), // input
        .start_in2 (status_scanline_chn2_start), // output
        .db_in3    (status_scanline_chn3_ad), // input[7:0] 
        .rq_in3    (status_scanline_chn3_rq), // input
        .start_in3 (status_scanline_chn3_start), // output
        .db_in4    (status_tiled_chn4_ad), // input[7:0] 
        .rq_in4    (status_tiled_chn4_rq), // input
        .start_in4 (status_tiled_chn4_start), // output
        .db_in5    (8'b0), // input[7:0] 
        .rq_in5    (1'b0), // input
        .start_in5 (), // output
        .db_in6    (8'b0), // input[7:0] 
        .rq_in6    (1'b0), // input
        .start_in6 (), // output
        .db_in7    (8'b0), // input[7:0] 
        .rq_in7    (1'b0), // input
        .start_in7 (), // output
        .db_in8    (8'b0), // input[7:0] 
        .rq_in8    (1'b0), // input
        .start_in8 (), // output
        .db_in9    (8'b0), // input[7:0] 
        .rq_in9    (1'b0), // input
        .start_in9 (), // output
        .db_in10   (8'b0), // input[7:0] 
        .rq_in10   (1'b0), // input
        .start_in10(), // output
        .db_in11    (8'b0), // input[7:0] 
        .rq_in11    (1'b0), // input
        .start_in11(), // output
        .db_in12   (8'b0), // input[7:0] 
        .rq_in12   (1'b0), // input
        .start_in12(), // output
        .db_in13   (8'b0), // input[7:0] 
        .rq_in13   (1'b0), // input
        .start_in13(), // output
        .db_in14   (8'b0), // input[7:0] 
        .rq_in14   (1'b0), // input
        .start_in14(), // output
        .db_in15   (8'b0), // input[7:0] 
        .rq_in15   (1'b0), // input
        .start_in15(), // output
        
        .db_out    (status_ad), // output[7:0] 
        .rq_out    (status_rq), // output
        .start_out (status_start) // input
    );

    mcntrl_tiled_rw #(
        .ADDRESS_NUMBER                (ADDRESS_NUMBER),
        .COLADDR_NUMBER                (COLADDR_NUMBER),
        .FRAME_WIDTH_BITS              (FRAME_WIDTH_BITS),
        .FRAME_HEIGHT_BITS             (FRAME_HEIGHT_BITS),
        .MAX_TILE_WIDTH                (MAX_TILE_WIDTH),
        .MAX_TILE_HEIGHT               (MAX_TILE_HEIGHT),
        .MCNTRL_TILED_ADDR             (MCNTRL_TILED_CHN4_ADDR),
        .MCNTRL_TILED_MASK             (MCNTRL_TILED_MASK),
        .MCNTRL_TILED_MODE             (MCNTRL_TILED_MODE),
        .MCNTRL_TILED_STATUS_CNTRL     (MCNTRL_TILED_STATUS_CNTRL),
        .MCNTRL_TILED_STARTADDR        (MCNTRL_TILED_STARTADDR),
        .MCNTRL_TILED_FRAME_FULL_WIDTH (MCNTRL_TILED_FRAME_FULL_WIDTH),
        .MCNTRL_TILED_WINDOW_WH        (MCNTRL_TILED_WINDOW_WH),
        .MCNTRL_TILED_WINDOW_X0Y0      (MCNTRL_TILED_WINDOW_X0Y0),
        .MCNTRL_TILED_WINDOW_STARTXY   (MCNTRL_TILED_WINDOW_STARTXY),
        .MCNTRL_TILED_TILE_WH          (MCNTRL_TILED_TILE_WH),
        .MCNTRL_TILED_STATUS_REG_ADDR  (MCNTRL_TILED_STATUS_REG_CHN4_ADDR),
        .MCNTRL_TILED_PENDING_CNTR_BITS(MCNTRL_TILED_PENDING_CNTR_BITS),
        .MCNTRL_TILED_FRAME_PAGE_RESET (MCNTRL_TILED_FRAME_PAGE_RESET),
        .MCNTRL_TILED_WRITE_MODE       (1'b0)
    ) mcntrl_tiled_rw_chn4_i (
        .rst(rst), // input
        .mclk(mclk), // input
        .cmd_ad               (cmd_tiled_chn4_ad), // input[7:0] 
        .cmd_stb              (cmd_tiled_chn4_stb), // input
        .status_ad            (status_tiled_chn4_ad), // output[7:0] 
        .status_rq            (status_tiled_chn4_rq), // output
        .status_start         (status_tiled_chn4_start), // input
        .frame_start       (frame_start_chn4), // input
        .next_page         (next_page_chn4), // input
        .frame_done        (frame_done_chn4), // output
        .line_unfinished   (line_unfinished_chn4), // output[15:0] 
        .suspend           (suspend_chn4), // input
        .xfer_want            (want_rq4), // output
        .xfer_need            (need_rq4), // output
        .xfer_grant           (channel_pgm_en4), // input
        .xfer_start           (tiled_rd_chn4_start), // output
        .xfer_bank            (tiled_rd_chn4_bank), // output[2:0] 
        .xfer_row             (tiled_rd_chn4_row), // output[14:0] 
        .xfer_col             (tiled_rd_chn4_col), // output[6:0] 
        .rowcol_inc           (tiled_rd_chn4_rowcol_inc), // output[13:0] 
        .num_rows_m1          (tiled_rd_chn4_num_rows_m1), // output[5:0] 
        .num_cols_m1          (tiled_rd_chn4_num_cols_m1), // output[5:0] 
        .keep_open            (tiled_rd_chn4_keep_open), // output
        .xfer_partial         (tiled_rd_chn4_xfer_partial), // output
        .xfer_page_done       (seq_done4), // input
        .xfer_page_rst        (xfer_reset_page4_pos) // output
    );

    cmd_encod_tiled_mux #(
        .ADDRESS_NUMBER          (ADDRESS_NUMBER),
        .COLADDR_NUMBER          (COLADDR_NUMBER),
        .FRAME_WIDTH_BITS        (FRAME_WIDTH_BITS),
        .MAX_TILE_WIDTH          (MAX_TILE_WIDTH),
        .MAX_TILE_HEIGHT         (MAX_TILE_HEIGHT)
    ) cmd_encod_tiled_mux_i (
        .clk                     (mclk), // input
        .bank4                   (tiled_rd_chn4_bank), // input[2:0] 
        .row4                    (tiled_rd_chn4_row), // input[14:0] 
        .col4                    (tiled_rd_chn4_col), // input[6:0] 
        .rowcol_inc4             (tiled_rd_chn4_rowcol_inc), // input[13:0] 
        .num_rows4               (tiled_rd_chn4_num_rows_m1), // input[5:0] 
        .num_cols4               (tiled_rd_chn4_num_cols_m1), // input[5:0] 
        .keep_open4              (tiled_rd_chn4_keep_open), // input
        .partial4                (tiled_rd_chn4_xfer_partial), // input
        .start4                  (tiled_rd_chn4_start), // input
        .bank                    (tiled_rd_bank), // output[2:0] 
        .row                     (tiled_rd_row), // output[14:0] 
        .col                     (tiled_rd_col), // output[6:0] 
        .rowcol_inc              (tiled_rd_rowcol_inc), // output[13:0] 
        .num_rows                (tiled_rd_num_rows_m1), // output[5:0] 
        .num_cols                (tiled_rd_num_cols_m1), // output[5:0] 
        .keep_open               (tiled_rd_keep_open), // output
        .partial                 (tiled_rd_xfer_partial), // output
        .start_rd                (tiled_rd_start), // output
        .start_wr                () // output
    );
    
    cmd_encod_tiled_rd #(
        .ADDRESS_NUMBER(15),
        .COLADDR_NUMBER(10),
        .CMD_PAUSE_BITS(10),
        .CMD_DONE_BIT(10)
    ) cmd_encod_tiled_rd_i (
        .rst               (rst), // input
        .clk               (mclk), // input
        .start_bank        (tiled_rd_bank), // input[2:0] 
        .start_row         (tiled_rd_row), // input[14:0] 
        .start_col         (tiled_rd_col), // input[6:0] 
        .rowcol_inc_in     (tiled_rd_rowcol_inc), // input[13:0] // [21:0] 
        .num_rows_in_m1    (tiled_rd_num_rows_m1), // input[5:0] 
        .num_cols_in_m1    (tiled_rd_num_cols_m1), // input[5:0] 
        .keep_open_in      (tiled_rd_keep_open), // input
        .skip_next_page_in (tiled_rd_xfer_partial), // input
        
        .start             (tiled_rd_start), // input
        .enc_cmd           (seq_data4x), // output[31:0] reg 
        .enc_wr            (seq_wr4x), // output reg 
        .enc_done          (seq_set4x) // output reg 
    );

// Port memory buffer (4 pages each, R/W fixed, port 0 - AXI read from DDR, port 1 - AXI write to DDR
// Port 2 (read DDR to AXI) buffer, linear
    always @ (negedge mclk) begin
        xfer_reset_page2_neg <= xfer_reset_page2_pos;
        xfer_reset_page4_neg <= xfer_reset_page4_pos;
    end

    mcntrl_1kx32r chn2_buf_i (
        .ext_clk      (axi_clk), // input
        .ext_raddr    (buf_raddr), // input[9:0] 
        .ext_rd       (buf2_rd), // input
        .ext_regen    (buf2_regen), // input
        .ext_data_out (buf2_data), // output[31:0] 
        .wclk         (!mclk), // input
        .wpage_in     (2'b0), // input[1:0] 
        .wpage_set    (xfer_reset_page2_neg), // input  TODO: Generate @ negedge mclk on frame start
        .page_next    (buf_wpage_nxt_chn2), // input
        .page         (), // output[1:0]
        .we           (buf_wr_chn2), // input
        .data_in      (buf_wdata_chn2) // input[63:0] 
    );



// Port 3 (write DDR from AXI) buffer, linear

         mcntrl_1kx32w chn3_buf_i (
        .ext_clk      (axi_clk), // input
        .ext_waddr    (buf_waddr), // input[9:0] 
        .ext_we       (buf3_we), // input
        .ext_data_in  (buf_wdata), // input[31:0] buf_wdata - from AXI
        .rclk         (mclk), // input
        .rpage_in     (2'b0), // input[1:0] 
        .rpage_set    (xfer_reset_page3), // input   TODO: Generate @ posedge mclk on frame start
        .page_next    (rpage_nxt_chn3), // input
        .page         (), // output[1:0]
        .rd           (buf_rd_chn3), // input
        .data_out     (buf_rdata_chn3) // output[63:0] 
    );

// Port 4 (read DDR to AXI) buffer, tiled
    mcntrl_1kx32r chn4_buf_i (
        .ext_clk      (axi_clk), // input
        .ext_raddr    (buf_raddr), // input[9:0] 
        .ext_rd       (buf4_rd), // input
        .ext_regen    (buf4_regen), // input
        .ext_data_out (buf4_data), // output[31:0] 
        .wclk         (!mclk), // input
        .wpage_in     (2'b0), // input[1:0] 
        .wpage_set    (xfer_reset_page4_neg), // input  TODO: Generate @ negedge mclk on frame start
        .page_next    (buf_wpage_nxt_chn4), // input
        .page         (), // output[1:0]
        .we           (buf_wr_chn4), // input
        .data_in      (buf_wdata_chn4) // input[63:0] 
    );

    

    mcntrl_linear_rw #(
        .ADDRESS_NUMBER                    (ADDRESS_NUMBER),
        .COLADDR_NUMBER                    (COLADDR_NUMBER),
        .NUM_XFER_BITS                     (NUM_XFER_BITS),
        .FRAME_WIDTH_BITS                  (FRAME_WIDTH_BITS),
        .FRAME_HEIGHT_BITS                 (FRAME_HEIGHT_BITS),
        .MCNTRL_SCANLINE_ADDR              (MCNTRL_SCANLINE_CHN2_ADDR),
        .MCNTRL_SCANLINE_MASK              (MCNTRL_SCANLINE_MASK),
        .MCNTRL_SCANLINE_MODE              (MCNTRL_SCANLINE_MODE),
        .MCNTRL_SCANLINE_STATUS_CNTRL      (MCNTRL_SCANLINE_STATUS_CNTRL),
        .MCNTRL_SCANLINE_STARTADDR         (MCNTRL_SCANLINE_STARTADDR),
        .MCNTRL_SCANLINE_FRAME_FULL_WIDTH  (MCNTRL_SCANLINE_FRAME_FULL_WIDTH),
        .MCNTRL_SCANLINE_WINDOW_WH         (MCNTRL_SCANLINE_WINDOW_WH),
        .MCNTRL_SCANLINE_WINDOW_X0Y0       (MCNTRL_SCANLINE_WINDOW_X0Y0),
        .MCNTRL_SCANLINE_WINDOW_STARTXY    (MCNTRL_SCANLINE_WINDOW_STARTXY),
        .MCNTRL_SCANLINE_STATUS_REG_ADDR   (MCNTRL_SCANLINE_STATUS_REG_CHN2_ADDR),
        .MCNTRL_SCANLINE_PENDING_CNTR_BITS (MCNTRL_SCANLINE_PENDING_CNTR_BITS),
        .MCNTRL_SCANLINE_WRITE_MODE        (1'b0)
    ) mcntrl_linear_rw_chn2_i (
        .rst             (rst), // input
        .mclk            (mclk), // input
        .cmd_ad          (cmd_scanline_chn2_ad), // input[7:0] 
        .cmd_stb         (cmd_scanline_chn2_stb), // input
        .status_ad       (status_scanline_chn2_ad), // output[7:0] 
        .status_rq       (status_scanline_chn2_rq), // output
        .status_start    (status_scanline_chn2_start), // input
        .frame_start       (frame_start_chn2), // input
        .next_page         (next_page_chn2), // input
        .frame_done        (frame_done_chn2), // output
        .line_unfinished   (line_unfinished_chn2), // output[15:0] 
        .suspend           (suspend_chn2), // input
        .xfer_want       (want_rq2), // output
        .xfer_need       (need_rq2), // output
        .xfer_grant      (channel_pgm_en2), // input
        .xfer_start      (lin_rd_chn2_start), // output
        .xfer_bank       (lin_rd_chn2_bank), // output[2:0] 
        .xfer_row        (lin_rd_chn2_row), // output[14:0] 
        .xfer_col        (lin_rd_chn2_col), // output[6:0] 
        .xfer_num128     (lin_rd_chn2_num128), // output[5:0] 
        .xfer_done       (seq_done2), // input: sequence over
        .xfer_reset_page (xfer_reset_page2_pos) // output
    );


    mcntrl_linear_rw #(
        .ADDRESS_NUMBER                    (ADDRESS_NUMBER),
        .COLADDR_NUMBER                    (COLADDR_NUMBER),
        .NUM_XFER_BITS                     (NUM_XFER_BITS),
        .FRAME_WIDTH_BITS                  (FRAME_WIDTH_BITS),
        .FRAME_HEIGHT_BITS                 (FRAME_HEIGHT_BITS),
        .MCNTRL_SCANLINE_ADDR              (MCNTRL_SCANLINE_CHN3_ADDR),
        .MCNTRL_SCANLINE_MASK              (MCNTRL_SCANLINE_MASK),
        .MCNTRL_SCANLINE_MODE              (MCNTRL_SCANLINE_MODE),
        .MCNTRL_SCANLINE_STATUS_CNTRL      (MCNTRL_SCANLINE_STATUS_CNTRL),
        .MCNTRL_SCANLINE_STARTADDR         (MCNTRL_SCANLINE_STARTADDR),
        .MCNTRL_SCANLINE_FRAME_FULL_WIDTH  (MCNTRL_SCANLINE_FRAME_FULL_WIDTH),
        .MCNTRL_SCANLINE_WINDOW_WH         (MCNTRL_SCANLINE_WINDOW_WH),
        .MCNTRL_SCANLINE_WINDOW_X0Y0       (MCNTRL_SCANLINE_WINDOW_X0Y0),
        .MCNTRL_SCANLINE_WINDOW_STARTXY    (MCNTRL_SCANLINE_WINDOW_STARTXY),
        .MCNTRL_SCANLINE_STATUS_REG_ADDR   (MCNTRL_SCANLINE_STATUS_REG_CHN3_ADDR),
        .MCNTRL_SCANLINE_PENDING_CNTR_BITS (MCNTRL_SCANLINE_PENDING_CNTR_BITS),
        .MCNTRL_SCANLINE_WRITE_MODE        (1'b1)
    ) mcntrl_linear_rw_chn3_i (
        .rst             (rst), // input
        .mclk            (mclk), // input
        .cmd_ad          (cmd_scanline_chn3_ad), // input[7:0] 
        .cmd_stb         (cmd_scanline_chn3_stb), // input
        .status_ad       (status_scanline_chn3_ad), // output[7:0] 
        .status_rq       (status_scanline_chn3_rq), // output
        .status_start    (status_scanline_chn3_start), // input
        .frame_start      (frame_start_chn3), // input
        .next_page        (next_page_chn3), // input
        .frame_done       (frame_done_chn3), // output
        .line_unfinished  (line_unfinished_chn3), // output[15:0] 
        .suspend          (suspend_chn3), // input
        .xfer_want       (want_rq3), // output
        .xfer_need       (need_rq3), // output
        .xfer_grant      (channel_pgm_en3), // input
        .xfer_start      (lin_wr_chn3_start), // output
        .xfer_bank       (lin_wr_chn3_bank), // output[2:0] 
        .xfer_row        (lin_wr_chn3_row), // output[14:0] 
        .xfer_col        (lin_wr_chn3_col), // output[6:0] 
        .xfer_num128     (lin_wr_chn3_num128), // output[5:0] 
        .xfer_done       (seq_done3), // input : sequence over
//        .xfer_page       (xfer_page3) // output[1:0]
        .xfer_reset_page (xfer_reset_page3) // output
    );
    
    cmd_encod_linear_mux #(
        .ADDRESS_NUMBER           (ADDRESS_NUMBER),
        .COLADDR_NUMBER           (COLADDR_NUMBER)
    ) cmd_encod_linear_mux_i (
        .clk                      (mclk), // input
        .bank2                    (lin_rd_chn2_bank), // input[2:0] 
        .row2                     (lin_rd_chn2_row), // input[14:0] 
        .start_col2               (lin_rd_chn2_col), // input[6:0] 
        .num128_2                 (lin_rd_chn2_num128), // input[5:0] 
        .start2                   (lin_rd_chn2_start), // input
        
        .bank3                    (lin_wr_chn3_bank), // input[2:0] 
        .row3                     (lin_wr_chn3_row), // input[14:0] 
        .start_col3               (lin_wr_chn3_col), // input[6:0] 
        .num128_3                 (lin_wr_chn3_num128), // input[5:0] 
        .start3                   (lin_wr_chn3_start), // input

        .bank                     (lin_rw_bank), // output[2:0] 
        .row                      (lin_rw_row), // output[14:0] 
        .start_col                (lin_rw_col), // output[6:0] 
        .num128                   (lin_rw_num128), // output[5:0] 
        .start_rd                 (lin_rd_start), // output
        .start_wr                 (lin_wr_start) // output
    );

    
    /* Instance template for module cmd_encod_linear_rd */
    cmd_encod_linear_rd #(
        .ADDRESS_NUMBER  (ADDRESS_NUMBER),
        .COLADDR_NUMBER  (COLADDR_NUMBER),
        .CMD_PAUSE_BITS  (CMD_PAUSE_BITS),
        .CMD_DONE_BIT    (CMD_DONE_BIT)
    ) cmd_encod_linear_rd_i (
        .rst       (rst), // input
        .clk       (mclk), // input
        .bank_in   (lin_rw_bank), // input[2:0] 
        .row_in    (lin_rw_row), // input[14:0] 
        .start_col (lin_rw_col), // input[6:0] 
        .num128_in (lin_rw_num128), // input[5:0] 
        .start     (lin_rd_start), // input
        .enc_cmd   (seq_data2x), // output[31:0] reg 
        .enc_wr    (seq_wr2x), // output reg 
        .enc_done  (seq_set2x) // output reg 
    );

    /* Instance template for module cmd_encod_linear_wr */
    cmd_encod_linear_wr #(
        .ADDRESS_NUMBER  (ADDRESS_NUMBER),
        .COLADDR_NUMBER  (COLADDR_NUMBER),
        .CMD_PAUSE_BITS  (CMD_PAUSE_BITS),
        .CMD_DONE_BIT  (CMD_DONE_BIT)
    ) cmd_encod_linear_wr_i (
        .rst       (rst), // input
        .clk       (mclk), // input
        .bank_in   (lin_rw_bank), // input[2:0] 
        .row_in    (lin_rw_row), // input[14:0] 
        .start_col (lin_rw_col), // input[6:0] 
        .num128_in (lin_rw_num128), // input[5:0] 
        .start     (lin_wr_start), // input
        .enc_cmd   (seq_data3x), // output[31:0] reg 
        .enc_wr    (seq_wr3x), // output reg 
        .enc_done  (seq_set3x) // output reg 
    );


     /* Instance template for module mcntrl_ps_pio */
    mcntrl_ps_pio #(
        .MCNTRL_PS_ADDR            (MCNTRL_PS_ADDR), //'h100),
        .MCNTRL_PS_MASK            (MCNTRL_PS_MASK), //'h3e0),
        .MCNTRL_PS_STATUS_REG_ADDR (MCNTRL_PS_STATUS_REG_ADDR), //'h2),
        .MCNTRL_PS_EN_RST          (MCNTRL_PS_EN_RST), //'h0),
        .MCNTRL_PS_CMD             (MCNTRL_PS_CMD), //'h1),
        .MCNTRL_PS_STATUS_CNTRL    (MCNTRL_PS_STATUS_CNTRL) //'h2)
    ) mcntrl_ps_pio_i (
        .rst                       (rst), // input
        .mclk                      (mclk), // input
        
        .cmd_ad                    (cmd_ps_pio_ad), // input[7:0] 
        .cmd_stb                   (cmd_ps_pio_stb), // input
        .status_ad                 (status_ps_pio_ad), // output[7:0] 
        .status_rq                 (status_ps_pio_rq), // output
        .status_start              (status_ps_pio_start), // input
        
        .port0_clk                 (axi_clk), // input
        .port0_re                  (buf0_rd), // input
        .port0_regen               (buf0_regen), // input
        .port0_addr                (buf_raddr), // input[9:0] 
        .port0_data                (buf0_data), // output[31:0]
         
        .port1_clk                 (axi_clk), // input
        .port1_we                  (buf1_we), // input
        .port1_addr                (buf_waddr), // input[9:0] 
        .port1_data                (buf_wdata), // input[31:0]
         
        .want_rq0                  (want_rq0), // output reg 
        .need_rq0                  (need_rq0), // output reg 
        .channel_pgm_en0           (channel_pgm_en0), // input
        .seq_data0                 (seq_data0), // output[9:0] 
        .seq_set0                  (seq_set0), // output
        .seq_done0                 (seq_done0), // input
        .buf_wr_chn0               (buf_wr_chn0), // input         @negedge mclk
        .buf_wpage_nxt_chn0        (buf_wpage_nxt_chn0), // input @negedge mclk
        .buf_wdata_chn0            (buf_wdata_chn0), // input[63:0]@negedge mclk
         
        .want_rq1                  (want_rq1), // output reg 
        .need_rq1                  (need_rq1), // output reg 
        .channel_pgm_en1           (channel_pgm_en1), // input
        .seq_done1                 (seq_done1), // input
        .rpage_nxt_chn1            (rpage_nxt_chn1), // input 
        .buf_rd_chn1               (buf_rd_chn1), // input
        .buf_rdata_chn1            (buf_rdata_chn1) // output[63:0] 
    );


    memctrl16 #(
        .DLY_LD                           (DLY_LD),
        .DLY_LD_MASK                      (DLY_LD_MASK),
        .MCONTR_PHY_0BIT_ADDR             (MCONTR_PHY_0BIT_ADDR),
        .MCONTR_PHY_0BIT_ADDR_MASK        (MCONTR_PHY_0BIT_ADDR_MASK),
        .MCONTR_PHY_0BIT_DLY_SET          (MCONTR_PHY_0BIT_DLY_SET),
        .MCONTR_PHY_0BIT_CMDA_EN          (MCONTR_PHY_0BIT_CMDA_EN),
        .MCONTR_PHY_0BIT_SDRST_ACT        (MCONTR_PHY_0BIT_SDRST_ACT),
        .MCONTR_PHY_0BIT_CKE_EN           (MCONTR_PHY_0BIT_CKE_EN),
        .MCONTR_PHY_0BIT_DCI_RST          (MCONTR_PHY_0BIT_DCI_RST),
        .MCONTR_PHY_0BIT_DLY_RST(MCONTR_PHY_0BIT_DLY_RST),
        .MCONTR_TOP_0BIT_ADDR(MCONTR_TOP_0BIT_ADDR),
        .MCONTR_TOP_0BIT_ADDR_MASK(MCONTR_TOP_0BIT_ADDR_MASK),
        .MCONTR_TOP_0BIT_MCONTR_EN(MCONTR_TOP_0BIT_MCONTR_EN),
        .MCONTR_TOP_0BIT_REFRESH_EN(MCONTR_TOP_0BIT_REFRESH_EN),
        .MCONTR_PHY_16BIT_ADDR(MCONTR_PHY_16BIT_ADDR),
        .MCONTR_PHY_16BIT_ADDR_MASK(MCONTR_PHY_16BIT_ADDR_MASK),
        .MCONTR_PHY_16BIT_PATTERNS(MCONTR_PHY_16BIT_PATTERNS),
        .MCONTR_PHY_16BIT_PATTERNS_TRI(MCONTR_PHY_16BIT_PATTERNS_TRI),
        .MCONTR_PHY_16BIT_WBUF_DELAY(MCONTR_PHY_16BIT_WBUF_DELAY),
        .MCONTR_PHY_16BIT_EXTRA(MCONTR_PHY_16BIT_EXTRA),
        .MCONTR_PHY_STATUS_CNTRL(MCONTR_PHY_STATUS_CNTRL),
        .MCONTR_ARBIT_ADDR(MCONTR_ARBIT_ADDR),
        .MCONTR_ARBIT_ADDR_MASK(MCONTR_ARBIT_ADDR_MASK),
        .MCONTR_TOP_16BIT_ADDR(MCONTR_TOP_16BIT_ADDR),
        .MCONTR_TOP_16BIT_ADDR_MASK(MCONTR_TOP_16BIT_ADDR_MASK),
        .MCONTR_TOP_16BIT_CHN_EN(MCONTR_TOP_16BIT_CHN_EN),
        .MCONTR_TOP_16BIT_REFRESH_PERIOD(MCONTR_TOP_16BIT_REFRESH_PERIOD),
        .MCONTR_TOP_16BIT_REFRESH_ADDRESS(MCONTR_TOP_16BIT_REFRESH_ADDRESS),
        .MCONTR_TOP_16BIT_STATUS_CNTRL(MCONTR_TOP_16BIT_STATUS_CNTRL),
        .MCONTR_PHY_STATUS_REG_ADDR(MCONTR_PHY_STATUS_REG_ADDR),
        .MCONTR_TOP_STATUS_REG_ADDR(MCONTR_TOP_STATUS_REG_ADDR),
        .CHNBUF_READ_LATENCY(CHNBUF_READ_LATENCY),
        .DFLT_DQS_PATTERN(DFLT_DQS_PATTERN),
        .DFLT_DQM_PATTERN(DFLT_DQM_PATTERN),
        .DFLT_DQ_TRI_ON_PATTERN(DFLT_DQ_TRI_ON_PATTERN),
        .DFLT_DQ_TRI_OFF_PATTERN(DFLT_DQ_TRI_OFF_PATTERN),
        .DFLT_DQS_TRI_ON_PATTERN(DFLT_DQS_TRI_ON_PATTERN),
        .DFLT_DQS_TRI_OFF_PATTERN(DFLT_DQS_TRI_OFF_PATTERN),
        .DFLT_WBUF_DELAY(DFLT_WBUF_DELAY),
        .DFLT_INV_CLK_DIV(DFLT_INV_CLK_DIV),
        .DFLT_CHN_EN(DFLT_CHN_EN),
        .DFLT_REFRESH_ADDR(DFLT_REFRESH_ADDR),
        .DFLT_REFRESH_PERIOD(DFLT_REFRESH_PERIOD),
        
        .ADDRESS_NUMBER        (ADDRESS_NUMBER),
        .PHASE_WIDTH           (PHASE_WIDTH),
        .SLEW_DQ               (SLEW_DQ),
        .SLEW_DQS              (SLEW_DQS),
        .SLEW_CMDA             (SLEW_CMDA),
        .SLEW_CLK              (SLEW_CLK),
        .IBUF_LOW_PWR          (IBUF_LOW_PWR),
        .REFCLK_FREQUENCY      (REFCLK_FREQUENCY),
        .HIGH_PERFORMANCE_MODE (HIGH_PERFORMANCE_MODE),
        .CLKIN_PERIOD          (CLKIN_PERIOD),
        .CLKFBOUT_MULT         (CLKFBOUT_MULT),
        .CLKFBOUT_MULT_REF     (CLKFBOUT_MULT_REF),
        .CLKFBOUT_DIV_REF      (CLKFBOUT_DIV_REF),
        .DIVCLK_DIVIDE         (DIVCLK_DIVIDE),
        .CLKFBOUT_PHASE        (CLKFBOUT_PHASE),
        .SDCLK_PHASE           (SDCLK_PHASE),
        .CLK_PHASE             (CLK_PHASE),
        .CLK_DIV_PHASE         (CLK_DIV_PHASE),
        .MCLK_PHASE            (MCLK_PHASE),
        .REF_JITTER1           (REF_JITTER1),
        .SS_EN                 (SS_EN),
        .SS_MODE               (SS_MODE),
        .SS_MOD_PERIOD         (SS_MOD_PERIOD),
        .CMD_PAUSE_BITS        (CMD_PAUSE_BITS),
        .CMD_DONE_BIT          (CMD_DONE_BIT)
    ) memctrl16_i (
        .rst_in             (rst_in), // input
        .clk_in             (clk_in), // input
        .mclk               (mclk), // output
        .cmd_ad             (cmd_mcontr_ad), // input[7:0] 
        .cmd_stb            (cmd_mcontr_stb), // input
        .status_ad          (status_mcontr_ad[7:0]), // output[7:0]
        .status_rq          (status_mcontr_rq),   // input request to send status downstream
        .status_start       (status_mcontr_start), // Acknowledge of the first status packet byte (address)
        
        .cmd0_clk           (axi_clk), // input
        .cmd0_we            (cmd_we), // input
        .cmd0_addr          (buf_waddr), // input[9:0] 
        .cmd0_data          (buf_wdata), // input[31:0] 
         
        .want_rq0           (want_rq0), // input
        .need_rq0           (need_rq0), // input
        .channel_pgm_en0    (channel_pgm_en0), // output reg 
        .seq_data0          ({22'b0,seq_data0}), // input[31:0] 
        .seq_wr0            (1'b0), // not used: seq_wr0), // input
        .seq_set0           (seq_set0), // input
        .seq_done0          (seq_done0), // output
        .rpage_nxt_chn0     (), //rpage_nxt_chn0), not used
        .buf_wr_chn0        (buf_wr_chn0), // output
        .buf_wpage_nxt_chn0 (buf_wpage_nxt_chn0), // output
//        .buf_waddr_chn0     (buf_waddr_chn0), // output[6:0] 
        .buf_wdata_chn0     (buf_wdata_chn0), // output[63:0]

        .want_rq1           (want_rq1), // input
        .need_rq1           (need_rq1), // input
        .channel_pgm_en1    (channel_pgm_en1), // output reg 
        .seq_data1          ({22'b0,seq_data0}), // input[31:0] // same as for channel 0 
        .seq_wr1            (1'b0), // not used: seq_wr1), // input
        .seq_set1           (seq_set0), // seq_set0 from channel 0 (shared in ps_pio), // input
        .seq_done1          (seq_done1), // output
        .rpage_nxt_chn1 (rpage_nxt_chn1), // output
        .buf_rd_chn1        (buf_rd_chn1), // output
        .buf_rdata_chn1     (buf_rdata_chn1), // input[63:0] 

        .want_rq2           (want_rq2), // input
        .need_rq2           (need_rq2), // input
        .channel_pgm_en2    (channel_pgm_en2), // output reg 
        .seq_data2          (seq_data2x), // input[31:0] 
        .seq_wr2            (seq_wr2x), // input
        .seq_set2           (seq_set2x), // input
        .seq_done2          (seq_done2), // output
        .rpage_nxt_chn2     (), // not used rpage_nxt_chn2), // output
        .buf_wr_chn2        (buf_wr_chn2), // output
        .buf_wpage_nxt_chn2 (buf_wpage_nxt_chn2), // output
        .buf_wdata_chn2     (buf_wdata_chn2), // output[63:0]

        .want_rq3           (want_rq3), // input
        .need_rq3           (need_rq3), // input
        .channel_pgm_en3    (channel_pgm_en3), // output reg 
        .seq_data3          (seq_data3x), // input[31:0] 
        .seq_wr3            (seq_wr3x), // input
        .seq_set3           (seq_set3x), // input
        .seq_done3          (seq_done3), // output
        .rpage_nxt_chn3     (rpage_nxt_chn3), // output 
        .buf_rd_chn3        (buf_rd_chn3), // output
        .buf_rdata_chn3     (buf_rdata_chn3), // input[63:0] 

        .want_rq4           (want_rq4), // input
        .need_rq4           (need_rq4), // input
        .channel_pgm_en4    (channel_pgm_en4), // output reg 
        .seq_data4          (seq_data4x), // input[31:0] 
        .seq_wr4            (seq_wr4x), // input
        .seq_set4           (seq_set4x), // input
        .seq_done4          (seq_done4), // output
        .rpage_nxt_chn4     (rpage_nxt_chn4), // output 
        .buf_wr_chn4        (buf_wr_chn4), // output
        .buf_wpage_nxt_chn4 (buf_wpage_nxt_chn4), // output 
        .buf_wdata_chn4     (buf_wdata_chn4), // output[63:0]

        .SDRST              (SDRST), // output
        .SDCLK              (SDCLK), // output
        .SDNCLK             (SDNCLK), // output
        .SDA                (SDA), // output[14:0] 
        .SDBA               (SDBA), // output[2:0] 
        .SDWE               (SDWE), // output
        .SDRAS              (SDRAS), // output
        .SDCAS              (SDCAS), // output
        .SDCKE              (SDCKE), // output
        .SDODT              (SDODT), // output
        .SDD                (SDD), // inout[15:0] 
        .SDDML              (SDDML), // output
        .DQSL               (DQSL), // inout
        .NDQSL              (NDQSL), // inout
        .SDDMU              (SDDMU), // output
        .DQSU               (DQSU), // inout
        .NDQSU              (NDQSU), // inout
        .tmp_debug          (tmp_debug) // output[11:0] 
    );

endmodule

