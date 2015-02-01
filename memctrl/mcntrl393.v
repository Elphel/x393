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
    
    
    parameter CHNBUF_READ_LATENCY =             0,     // external channel buffer extra read latency ( 0 - data available next cycle after re (but prev. data))
    
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
                                                        // Read back current address (fro debugging)?
    parameter MCNTRL_SCANLINE_STATUS_REG_ADDR=   'h4,
    parameter MCNTRL_SCANLINE_PENDING_CNTR_BITS=   2    // Number of bits to count pending trasfers, currently 2 is enough, but may increase
                                                        // if memory controller will allow programming several sequences in advance to
                                                        // spread long-programming (tiled) over fast-programming (linear) requests.
                                                        // But that should not be too big to maintain 2-level priorities
    
    
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

    wire                  [7:0] status_mcontr_ad;    // Memory controller status byte-wide address/data 
    wire                        status_mcontr_rq;    // Memory controller status request  
    wire                        status_mcontr_start; // Memory controller status packet transfer start (currently with 0 latency from status_root_rq)
// Not yet connected
    wire                  [7:0] status_other_ad;    // Other status byte-wide address/data 
    wire                        status_other_rq;    // Other status request  
    wire                        status_other_start; // Other status packet transfer start (currently with 0 latency from status_root_rq)
    
    status_router2 status_router2_mctrl_top_i (
        .rst       (rst), // input
        .clk       (mclk), // input
        .db_in0    (status_mcontr_ad), // input[7:0] 
        .rq_in0    (status_mcontr_rq), // input
        .start_in0 (status_mcontr_start), // output
        .db_in1    (status_other_ad), // input[7:0] 
        .rq_in1    (status_other_rq), // input
        .start_in1 (status_other_start), // output
        .db_out    (status_ad), // output[7:0] 
        .rq_out    (status_rq), // output
        .start_out (status_start) // input
    );

    /* Instance template for module mcntrl_linear_rw */
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
        .MCNTRL_SCANLINE_STATUS_REG_ADDR   (MCNTRL_SCANLINE_STATUS_REG_ADDR),
        .MCNTRL_SCANLINE_PENDING_CNTR_BITS (MCNTRL_SCANLINE_PENDING_CNTR_BITS)
    ) mcntrl_linear_rw_chn2_i (
        .rst             (rst), // input
        .mclk            (mclk), // input
        .cmd_ad(), // input[7:0] 
        .cmd_stb(), // input
        .status_ad(), // output[7:0] 
        .status_rq(), // output
        .status_start(), // input
        .frame_start(), // input
        .next_page(), // input
        .frame_done(), // output
        .line_unfinished(), // output[15:0] 
        .suspend(), // input
        .xfer_want(), // output
        .xfer_need(), // output
        .xfer_grant(), // input
        .xfer_start(), // output
        .xfer_bank(), // output[2:0] 
        .xfer_row(), // output[14:0] 
        .xfer_col(), // output[6:0] 
        .xfer_num128(), // output[5:0] 
        .xfer_done(), // input
        .xfer_page() // output[1:0] 
    );

    /* Instance template for module mcntrl_linear_rw */
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
        .MCNTRL_SCANLINE_STATUS_REG_ADDR   (MCNTRL_SCANLINE_STATUS_REG_ADDR),
        .MCNTRL_SCANLINE_PENDING_CNTR_BITS (MCNTRL_SCANLINE_PENDING_CNTR_BITS)
    ) mcntrl_linear_rw_chn3_i (
        .rst             (rst), // input
        .mclk            (mclk), // input
        .cmd_ad(), // input[7:0] 
        .cmd_stb(), // input
        .status_ad(), // output[7:0] 
        .status_rq(), // output
        .status_start(), // input
        .frame_start(), // input
        .next_page(), // input
        .frame_done(), // output
        .line_unfinished (), // output[15:0] 
        .suspend(), // input
        .xfer_want(), // output
        .xfer_need(), // output
        .xfer_grant(), // input
        .xfer_start(), // output
        .xfer_bank(), // output[2:0] 
        .xfer_row(), // output[14:0] 
        .xfer_col(), // output[6:0] 
        .xfer_num128(), // output[5:0] 
        .xfer_done(), // input
        .xfer_page() // output[1:0] 
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
        .cmd_ad(), // input[7:0] 
        .cmd_stb(), // input
        .status_ad(), // output[7:0] 
        .status_rq(), // output
        .status_start(), // input
        .port0_clk(), // input
        .port0_re(), // input
        .port0_regen(), // input
        .port0_addr(), // input[9:0] 
        .port0_data(), // output[31:0] 
        .port1_clk(), // input
        .port1_we(), // input
        .port1_addr(), // input[9:0] 
        .port1_data(), // input[31:0] 
        .want_rq0(), // output reg 
        .need_rq0(), // output reg 
        .channel_pgm_en0(), // input
        .seq_data0(), // output[9:0] 
        .seq_set0(), // output
        .seq_done0(), // input
        .buf_wr_chn0(), // input
        .buf_waddr_chn0(), // input[6:0] 
        .buf_wdata_chn0(), // input[63:0] 
        .want_rq1(), // output reg 
        .need_rq1(), // output reg 
        .channel_pgm_en1(), // input
        .seq_done1(), // input
        .buf_rd_chn1(), // input
        .buf_raddr_chn1(), // input[6:0] 
        .buf_rdata_chn1() // output[63:0] 
    );
    
    
    /* Instance template for module cmd_encod_linear_mux */
    cmd_encod_linear_mux #(
        .ADDRESS_NUMBER            (ADDRESS_NUMBER),
        .COLADDR_NUMBER            (COLADDR_NUMBER)
    ) cmd_encod_linear_mux_i (
        .clk                      (mclk), // input
        .bank2(), // input[2:0] 
        .row2(), // input[14:0] 
        .start_col2(), // input[6:0] 
        .num128_2(), // input[5:0] 
        .start2(), // input
        .bank3(), // input[2:0] 
        .row3(), // input[14:0] 
        .start_col3(), // input[6:0] 
        .num128_3(), // input[5:0] 
        .start3(), // input
        .bank(), // output[2:0] 
        .row(), // output[14:0] 
        .start_col(), // output[6:0] 
        .num128(), // output[5:0] 
        .start_rd(), // output
        .start_wr() // output
    );
    
    /* Instance template for module cmd_encod_tiled_mux */
    cmd_encod_tiled_mux #(
        .ADDRESS_NUMBER          (ADDRESS_NUMBER),
        .COLADDR_NUMBER          (COLADDR_NUMBER)
    ) cmd_encod_tiled_mux_i (
        .clk                     (mclk), // input
        .bank4(), // input[2:0] 
        .row4(), // input[14:0] 
        .col4(), // input[6:0] 
        .rowcol_inc4(), // input[21:0] 
        .num_rows4(), // input[5:0] 
        .num_cols4(), // input[5:0] 
        .keep_open4(), // input
        .start4(), // input
        .bank(), // output[2:0] 
        .row(), // output[14:0] 
        .col(), // output[6:0] 
        .rowcol_inc(), // output[21:0] 
        .num_rows(), // output[5:0] 
        .num_cols(), // output[5:0] 
        .keep_open(), // output
        .start_rd(), // output
        .start_wr() // output
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
        
        .cmd0_clk           (cmd0_clk), // input
        .cmd0_we            (cmd0_we), // input
        .cmd0_addr          (cmd0_addr), // input[9:0] 
        .cmd0_data          (cmd0_data), // input[31:0] 
         
        .want_rq0           (want_rq0), // input
        .need_rq0           (need_rq0), // input
        .channel_pgm_en0    (channel_pgm_en0), // output reg 
        .seq_data0          (seq_data0), // input[31:0] 
        .seq_wr0            (seq_wr0), // input
        .seq_set0           (seq_set0), // input
        .seq_done0          (seq_done0), // output
        .buf_wr_chn0        (buf_wr_chn0), // output
        .buf_waddr_chn0     (buf_waddr_chn0), // output[6:0] 
        .buf_wdata_chn0     (buf_wdata_chn0), // output[63:0]

        .want_rq1           (want_rq1), // input
        .need_rq1           (need_rq1), // input
        .channel_pgm_en1    (channel_pgm_en1), // output reg 
        .seq_data1          (seq_data1), // input[31:0] 
        .seq_wr1            (seq_wr1), // input
        .seq_set1           (seq_set1), // input
        .seq_done1          (seq_done1), // output
        .buf_rd_chn1        (buf_rd_chn1), // output
        .buf_raddr_chn1     (buf_raddr_chn1), // output[6:0] 
        .buf_rdata_chn1     (buf_rdata_chn1), // input[63:0] 

        .want_rq2           (want_rq2), // input
        .need_rq2           (need_rq2), // input
        .channel_pgm_en2    (channel_pgm_en2), // output reg 
        .seq_data2          (seq_data2), // input[31:0] 
        .seq_wr2            (seq_wr2), // input
        .seq_set2           (seq_set2), // input
        .seq_done2          (seq_done2), // output
        .buf_wr_chn2        (buf_wr_chn2), // output
        .buf_waddr_chn2     (buf_waddr_chn2), // output[6:0] 
        .buf_wdata_chn2     (buf_wdata_chn2), // output[63:0]

        .want_rq3           (want_rq3), // input
        .need_rq3           (need_rq3), // input
        .channel_pgm_en3    (channel_pgm_en3), // output reg 
        .seq_data3          (seq_data3), // input[31:0] 
        .seq_wr3            (seq_wr3), // input
        .seq_set3           (seq_set3), // input
        .seq_done3          (seq_done3), // output
        .buf_rd_chn3        (buf_rd_chn3), // output
        .buf_raddr_chn3     (buf_raddr_chn3), // output[6:0] 
        .buf_rdata_chn3     (buf_rdata_chn3), // input[63:0] 

        .want_rq4           (want_rq4), // input
        .need_rq4           (need_rq4), // input
        .channel_pgm_en4    (channel_pgm_en4), // output reg 
        .seq_data4          (seq_data4), // input[31:0] 
        .seq_wr4            (seq_wr4), // input
        .seq_set4           (seq_set4), // input
        .seq_done4          (seq_done4), // output
        .buf_wr_chn4        (buf_wr_chn4), // output
        .buf_waddr_chn4     (buf_waddr_chn4), // output[6:0] 
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

