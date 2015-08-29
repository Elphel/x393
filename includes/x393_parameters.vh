/*******************************************************************************
 * File: x393_parameters.vh
 * Date:2015-02-07  
 * Author: Andrey Filippov     
 * Description: Parameters for the x393 (simulation and implementation)
 *
 * Copyright (c) 2015 Elphel, Inc.
 * x393_parameters.vh is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * x393_parameters.vh is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
    parameter MCONTR_WR_MASK =          'h3c00, // AXI write address mask for the 1Kx32 buffers command sequence memory
    parameter MCONTR_RD_MASK =          'h3c00, // AXI read address mask to generate busy

    parameter CONTROL_ADDR =            'h0000, // AXI write address of control write registers
    parameter CONTROL_ADDR_MASK =       'h3800, // AXI write mask of control registers
    parameter CONTROL_RBACK_ADDR =      'h0000, // AXI read address of control registers readback
    parameter CONTROL_RBACK_ADDR_MASK = 'h3800, // AXI mask of control registers readback addresses
    parameter CONTROL_RBACK_DEPTH=          11, // 10 - 1xbram, 11 - 2xbram


    parameter STATUS_ADDR =             'h0800, // AXI read address of status read registers
    parameter STATUS_ADDR_MASK =        'h3c00, // AXI write address of status registers
    
    parameter MCONTR_CMD_WR_ADDR =      'h0c00, // AXI write to command sequence memory

    parameter MCONTR_BUF0_RD_ADDR =     'h1000, // AXI read address from buffer 0 (PS sequence, memory read) (was 'h400)
    parameter MCONTR_BUF0_WR_ADDR =     'h1000, // AXI write address to buffer 0 (PS sequence, memory write) (was 'h400)
    // MCONTR_BUF[2-4]_* - temporary, will be removed in the futire
    parameter MCONTR_BUF2_RD_ADDR =     'h1400, // AXI read address from buffer 2 (PL sequence, tiles, memory read)
    parameter MCONTR_BUF2_WR_ADDR =     'h1400, // AXI write address to buffer 2 (PL sequence, tiles, memory write)
    parameter MCONTR_BUF3_RD_ADDR =     'h1800, // AXI read address from buffer 3 (PL sequence, scanline, memory read)
    parameter MCONTR_BUF3_WR_ADDR =     'h1800, // AXI write address to buffer 3 (PL sequence, scanline, memory write)
    parameter MCONTR_BUF4_RD_ADDR =     'h1c00, // AXI read address from buffer 4 (PL sequence, tiles, memory read)
    parameter MCONTR_BUF4_WR_ADDR =     'h1c00, // AXI write address to buffer 4 (PL sequence, tiles, memory write)
     
    
    parameter AXI_WR_ADDR_BITS =            14,
    parameter AXI_RD_ADDR_BITS =            14,
    parameter STATUS_DEPTH=                  8,  // 256 cells, maybe just 16..64 are enough?
    
//command interface parameters
    parameter DLY_LD =            'h080,  // address to generate delay load
    parameter DLY_LD_MASK =       'h780,  // address mask to generate delay load
//0x1000..103f - 0- bit data (set/reset)
    parameter MCONTR_PHY_0BIT_ADDR =           'h020,  // address to set sequnecer channel and  run (4 LSB-s - channel)
    parameter MCONTR_PHY_0BIT_ADDR_MASK =      'h7f0,  // address mask to generate sequencer channel/run
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
    parameter MCONTR_TOP_0BIT_ADDR_MASK =      'h7f8,  // address mask to generate sequencer channel/run
//  0x1030..1031 - MCONTR_EN  // 0 bits, disable/enable memory controller
//  0x1032..1033 - REFRESH_EN // 0 bits, disable/enable memory refresh
//  0x1034..1037 - reserved
    parameter MCONTR_TOP_0BIT_MCONTR_EN =      'h0,    // set pre-programmed delays 
    parameter MCONTR_TOP_0BIT_REFRESH_EN =     'h2,    // disable/enable command/address outputs 
//0x1040..107f - 16-bit data
//  0x1040..104f - RUN_CHN      // address to set sequncer channel and  run (4 LSB-s - channel) - bits? 
//    parameter RUN_CHN_REL =           'h040,  // address to set sequnecer channel and  run (4 LSB-s - channel)
//   parameter RUN_CHN_REL_MASK =      'h7f0,  // address mask to generate sequencer channel/run
//  0x1050..1057: MCONTR_PHY16
    parameter MCONTR_PHY_16BIT_ADDR =           'h050,  // address to set sequnecer channel and  run (4 LSB-s - channel)
    parameter MCONTR_PHY_16BIT_ADDR_MASK =      'h7f8,  // address mask to generate sequencer channel/run
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
    parameter MCONTR_ARBIT_ADDR_MASK =          'h7f0,   // Address mask to set channel priorities
//0x1070..1077 - 16-bit top memory controller:
    parameter MCONTR_TOP_16BIT_ADDR =           'h070,  // address to set mcontr top control registers
    parameter MCONTR_TOP_16BIT_ADDR_MASK =      'h7f8,  // address mask to set mcontr top control registers
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
    
    
    parameter CHNBUF_READ_LATENCY =             2, //1,     // external channel buffer extra read latency ( 0 - data available next cycle after re (but prev. data))
    
    parameter DFLT_DQS_PATTERN=        8'haa,  // TODO: make work for the simulator too 8'h55,
    parameter DFLT_DQM_PATTERN=        8'h00, // 8'h00
    parameter DFLT_DQ_TRI_ON_PATTERN=  4'h7,  // DQ tri-state control word, first when enabling output
    parameter DFLT_DQ_TRI_OFF_PATTERN= 4'he,  // DQ tri-state control word, first after disabling output
    parameter DFLT_DQS_TRI_ON_PATTERN= 4'h3,  // DQS tri-state control word, first when enabling output
    parameter DFLT_DQS_TRI_OFF_PATTERN=4'hc,  // DQS tri-state control word, first after disabling output
    parameter DFLT_WBUF_DELAY=         4'h9,  // TODO: Find the reason - simulation needs 8, target - 9 
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
    parameter CLKIN_PERIOD =        20, // 10, //ns >1.25, 600<Fvco<1200 // Hardware 150MHz , change to             | 6.667
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
    
    parameter NUM_CYCLES_LOW_BIT=   'h6,    // decode addresses [NUM_CYCLES_LOW_BIT+:4] into command a/d length
// TODO: put actual data    
    parameter NUM_CYCLES_00 =       2, // 2-cycle 000.003f
    parameter NUM_CYCLES_01 =       4, // 4-cycle 040.007f
    parameter NUM_CYCLES_02 =       3, // 3-cycle 080.00bf
    parameter NUM_CYCLES_03 =       3, // 3-cycle 0c0.00ff
    parameter NUM_CYCLES_04 =       6, // 6-cycle 100.013f
    parameter NUM_CYCLES_05 =       6, // 6-cycle 140.017f
    parameter NUM_CYCLES_06 =       4, // 4-cycle 180.01bf
    parameter NUM_CYCLES_07 =       4, // 4-cycle 1c0.01ff
    parameter NUM_CYCLES_08 =       6, // 6-cycle 200.023f
    parameter NUM_CYCLES_09 =       6, //
    parameter NUM_CYCLES_10 =       6, //
    parameter NUM_CYCLES_11 =       6, //
    parameter NUM_CYCLES_12 =       6, //
    parameter NUM_CYCLES_13 =       5, // 5-cycle - not yet used
    parameter NUM_CYCLES_14 =       6, // 6-cycle - not yet used
    parameter NUM_CYCLES_15 =       9, // single-cycle
    parameter NUM_CYCLES_16 =       6,  //
    parameter NUM_CYCLES_17 =       6,  //
    parameter NUM_CYCLES_18 =       6,  //
    parameter NUM_CYCLES_19 =       6,  //
    parameter NUM_CYCLES_20 =       6,  //
    parameter NUM_CYCLES_21 =       6,  //
    parameter NUM_CYCLES_22 =       6,  //
    parameter NUM_CYCLES_23 =       6,  //
    parameter NUM_CYCLES_24 =       6,  //
    parameter NUM_CYCLES_25 =       6,  //
    parameter NUM_CYCLES_26 =       6,  //
    parameter NUM_CYCLES_27 =       6,  //
    parameter NUM_CYCLES_28 =       6,  //
    parameter NUM_CYCLES_29 =       6,  //
    parameter NUM_CYCLES_30 =       6,  //
    parameter NUM_CYCLES_31 =       6,  //
    
//    parameter CMD0_ADDR =           'h0800, // AXI write to command sequence memory
//    parameter CMD0_ADDR_MASK =      'h1800, // AXI read address mask for the command sequence memory
    parameter MCNTRL_PS_ADDR=                    'h100,
    parameter MCNTRL_PS_MASK=                    'h7e0, // both channels 0 and 1
    parameter MCNTRL_PS_STATUS_REG_ADDR=         'h2,
    parameter MCNTRL_PS_EN_RST=                  'h0,
    parameter MCNTRL_PS_CMD=                     'h1,
    parameter MCNTRL_PS_STATUS_CNTRL=            'h2,

    parameter NUM_XFER_BITS=                       6,    // number of bits to specify transfer length
    parameter FRAME_WIDTH_BITS=                   13,    // Maximal frame width - 8-word (16 bytes) bursts 
    parameter FRAME_HEIGHT_BITS=                  16,    // Maximal frame height 
    parameter LAST_FRAME_BITS=                    16,     // number of bits in frame counter (before rolls over)
    parameter MCNTRL_SCANLINE_CHN1_ADDR=         'h120,
    parameter MCNTRL_SCANLINE_CHN3_ADDR=         'h130,
    parameter MCNTRL_SCANLINE_MASK=              'h7f0, // both channels 0 and 1
    parameter MCNTRL_SCANLINE_MODE=              'h0,   // set mode register: {extra_pages[1:0],enable,!reset}
    parameter MCNTRL_SCANLINE_STATUS_CNTRL=      'h1,   // control status reporting
    parameter MCNTRL_SCANLINE_STARTADDR=         'h2,   // 22-bit frame start address (3 CA LSBs==0. BA==0)
    parameter MCNTRL_SCANLINE_FRAME_SIZE=        'h3,   // 22-bit frame start address increment (3 CA LSBs==0. BA==0)
    parameter MCNTRL_SCANLINE_FRAME_LAST=        'h4,   // 16-bit last frame number in the buffer
    parameter MCNTRL_SCANLINE_FRAME_FULL_WIDTH=  'h5,   // Padded line length (8-row increment), in 8-bursts (16 bytes)
    parameter MCNTRL_SCANLINE_WINDOW_WH=         'h6,   // low word - 13-bit window width (0->'h4000), high word - 16-bit frame height (0->'h10000)
    parameter MCNTRL_SCANLINE_WINDOW_X0Y0=       'h7,   // low word - 13-bit window left, high word - 16-bit window top
    parameter MCNTRL_SCANLINE_WINDOW_STARTXY=    'h8,   // low word - 13-bit start X (relative to window), high word - 16-bit start y
                                                        // Start XY can be used when read command to start from the middle
                                                        // TODO: Add number of blocks to R/W? (blocks can be different) - total length?
                                                        // Read back current address (for debugging)?
    parameter MCNTRL_SCANLINE_STATUS_REG_CHN1_ADDR=   'h4,
    parameter MCNTRL_SCANLINE_STATUS_REG_CHN3_ADDR=   'h6,
    parameter MCNTRL_SCANLINE_PENDING_CNTR_BITS=   2,    // Number of bits to count pending trasfers, currently 2 is enough, but may increase
                                                        // if memory controller will allow programming several sequences in advance to
                                                        // spread long-programming (tiled) over fast-programming (linear) requests.
                                                        // But that should not be too big to maintain 2-level priorities
    
    parameter MCNTRL_SCANLINE_FRAME_PAGE_RESET =1'b0, // reset internal page number to zero at the frame start (false - only when hard/soft reset)                                                     
    parameter MAX_TILE_WIDTH=                   6,     // number of bits to specify maximal tile (width-1) (6 -> 64)
    parameter MAX_TILE_HEIGHT=                  6,     // number of bits to specify maximal tile (height-1) (6 -> 64)
    parameter MCNTRL_TILED_CHN2_ADDR=       'h140,
    parameter MCNTRL_TILED_CHN4_ADDR=       'h150,
    parameter MCNTRL_TILED_MASK=            'h7f0, // both channels 0 and 1
    parameter MCNTRL_TILED_MODE=            'h0,   // set mode register: {extra_pages[1:0],write_mode,enable,!reset}
    parameter MCNTRL_TILED_STATUS_CNTRL=    'h1,   // control status reporting
    parameter MCNTRL_TILED_STARTADDR=       'h2,   // 22-bit frame start address (3 CA LSBs==0. BA==0)
    parameter MCNTRL_TILED_FRAME_SIZE=      'h3,   // 22-bit frame start address increment (3 CA LSBs==0. BA==0)
    parameter MCNTRL_TILED_FRAME_LAST=      'h4,   // 16-bit last frame number in the buffer
    parameter MCNTRL_TILED_FRAME_FULL_WIDTH='h5,   // Padded line length (8-row increment), in 8-bursts (16 bytes)
    parameter MCNTRL_TILED_WINDOW_WH=       'h6,   // low word - 13-bit window width (0->'h4000), high word - 16-bit frame height (0->'h10000)
    parameter MCNTRL_TILED_WINDOW_X0Y0=     'h7,   // low word - 13-bit window left, high word - 16-bit window top
    parameter MCNTRL_TILED_WINDOW_STARTXY=  'h8,   // low word - 13-bit start X (relative to window), high word - 16-bit start y
                                                      // Start XY can be used when read command to start from the middle
                                                      // TODO: Add number of blocks to R/W? (blocks can be different) - total length?
                                                      // Read back current address (for debugging)?
    parameter MCNTRL_TILED_TILE_WHS=        'h9,   // low byte - 6-bit tile width in 8-bursts, second byte - tile height (0 - > 64),
                                                   // 3-rd byte - vertical step (to control tile vertical overlap)
    parameter MCNTRL_TILED_STATUS_REG_CHN2_ADDR= 'h5,
    parameter MCNTRL_TILED_STATUS_REG_CHN4_ADDR= 'h7,
    parameter MCNTRL_TILED_PENDING_CNTR_BITS=2,    // Number of bits to count pending trasfers, currently 2 is enough, but may increase
                                                   // if memory controller will allow programming several sequences in advance to
                                                   // spread long-programming (tiled) over fast-programming (linear) requests.
                                                   // But that should not be too big to maintain 2-level priorities
    parameter MCNTRL_TILED_FRAME_PAGE_RESET =1'b0, // reset internal page number to zero at the frame start (false - only when hard/soft reset)
    parameter BUFFER_DEPTH32=                10,   // Block rum buffer depth on a 32-bit port

    // bits in mode control word
    parameter MCONTR_LINTILE_NRESET =              0, // reset if 0
    parameter MCONTR_LINTILE_EN =                  1, // enable requests 
    parameter MCONTR_LINTILE_WRITE =               2, // write to memory mode
    parameter MCONTR_LINTILE_EXTRAPG =             3, // extra pages (over 1) needed by the client simultaneously
    parameter MCONTR_LINTILE_EXTRAPG_BITS =        2, // number of bits to use for extra pages
    parameter MCONTR_LINTILE_KEEP_OPEN =           5, // keep banks open (will be used only if number of rows <= 8)
    parameter MCONTR_LINTILE_BYTE32 =              6, // use 32-byte wide columns in each tile (false - 16-byte) 
    parameter MCONTR_LINTILE_RST_FRAME =           8, // reset frame number 
    parameter MCONTR_LINTILE_SINGLE =              9, // read/write a single page 
    parameter MCONTR_LINTILE_REPEAT =             10,  // read/write pages until disabled
    parameter MCONTR_LINTILE_DIS_NEED =           11,   // disable 'need' request 
     
// Channel test module parameters
    parameter MCNTRL_TEST01_ADDR=                 'h0f0,
    parameter MCNTRL_TEST01_MASK=                 'h7f0,
    parameter MCNTRL_TEST01_CHN1_MODE=            'h2,   // set mode register for channel 5
    parameter MCNTRL_TEST01_CHN1_STATUS_CNTRL=    'h3,   // control status reporting for channel 5
    parameter MCNTRL_TEST01_CHN2_MODE=            'h4,   // set mode register for channel 2
    parameter MCNTRL_TEST01_CHN2_STATUS_CNTRL=    'h5,   // control status reporting for channel 2
    parameter MCNTRL_TEST01_CHN3_MODE=            'h6,   // set mode register for channel 3
    parameter MCNTRL_TEST01_CHN3_STATUS_CNTRL=    'h7,   // control status reporting for channel 3
    parameter MCNTRL_TEST01_CHN4_MODE=            'h8,   // set mode register for channel 4
    parameter MCNTRL_TEST01_CHN4_STATUS_CNTRL=    'h9,   // control status reporting for channel 4
    parameter MCNTRL_TEST01_STATUS_REG_CHN1_ADDR= 'h3c,  // status/readback register for channel 2
    parameter MCNTRL_TEST01_STATUS_REG_CHN2_ADDR= 'h3d,  // status/readback register for channel 3
    parameter MCNTRL_TEST01_STATUS_REG_CHN3_ADDR= 'h3e,  // status/readback register for channel 4
    parameter MCNTRL_TEST01_STATUS_REG_CHN4_ADDR= 'h3f,  // status/readback register for channel 4
    
    parameter MCONTR_SENS_BASE =                  'h680, // .. 'h6bf
    parameter MCONTR_SENS_INC =                   'h10,
    parameter MCONTR_CMPRS_BASE =                 'h6c0, // .. 'h6ff
    parameter MCONTR_CMPRS_INC =                  'h10,
    parameter MCONTR_SENS_STATUS_BASE =           'h28, // .. 'h2b
    parameter MCONTR_SENS_STATUS_INC =            'h1,
    parameter MCONTR_CMPRS_STATUS_BASE =          'h2c, // .. 'h2f
    parameter MCONTR_CMPRS_STATUS_INC =           'h1,

// membridge module parameters    
    parameter MEMBRIDGE_ADDR=                     'h200,
    parameter MEMBRIDGE_MASK=                     'h7f0,
    parameter MEMBRIDGE_CTRL=                     'h0, // bit 0 - enable, bits[2:1]: 01 - start, 11 - start and reset address
    parameter MEMBRIDGE_STATUS_CNTRL=             'h1,
    parameter MEMBRIDGE_LO_ADDR64=                'h2, // low address of the system memory, in 64-bit words (<<3 to get byte address)
    parameter MEMBRIDGE_SIZE64=                   'h3, // size of the system memory range (access will roll over to lo_addr
    parameter MEMBRIDGE_START64=                  'h4, // start address relative to lo_addr
    parameter MEMBRIDGE_LEN64=                    'h5, // full length of transfer in 64-bit words
    parameter MEMBRIDGE_WIDTH64=                  'h6, // frame width in 64-bit words (partial last page in each line)
    parameter MEMBRIDGE_MODE=                     'h7, // frame width in 64-bit words (partial last page in each line)
    parameter MEMBRIDGE_STATUS_REG=               'h3b,
    
    parameter RSEL=                               1'b1, // late/early READ commands (to adjust timing by 1 SDCLK period)
    parameter WSEL=                               1'b0,  // late/early WRITE commands (to adjust timing by 1 SDCLK period)
    
    parameter SENSOR_GROUP_ADDR =         'h400, // sensor registers base address
    parameter SENSOR_BASE_INC =           'h040, // increment for sesor channel
    
    parameter HIST_SAXI_ADDR_REL =         'h100, // histograms control addresses (16 locations) relative to SENSOR_GROUP_ADDR
    parameter HIST_SAXI_MODE_ADDR_REL =    'h110, // histograms mode address (1 locatios) relative to SENSOR_GROUP_ADDR
    
    
    parameter SENSI2C_STATUS_REG_BASE =   'h20,  // 4 locations" x20, x22, x24, x26
    parameter SENSI2C_STATUS_REG_INC =    2,     // increment to the next sensor
    parameter SENSI2C_STATUS_REG_REL =    0,     // 4 locations" 'h20, 'h22, 'h24, 'h26
    parameter SENSIO_STATUS_REG_REL =     1,     // 4 locations" 'h21, 'h23, 'h25, 'h27
    parameter SENSOR_NUM_HISTOGRAM=       3,     // number of histogram channels
    parameter HISTOGRAM_RAM_MODE =        "BUF32", // "NOBUF", // valid: "NOBUF" (32-bits, no buffering), "BUF18", "BUF32"
    parameter SENS_NUM_SUBCHN =           3,     // number of subchannels for his sensor ports (1..4)
    parameter SENS_GAMMA_BUFFER =         0,     // 1 - use "shadow" table for clean switching, 0 - single table per channel
    
    // parameters defining address map
    parameter SENSOR_CTRL_RADDR =         0, // relative to SENSOR_GROUP_ADDR 
    parameter SENSOR_CTRL_ADDR_MASK =    'h7ff, //
        // bits of the SENSOR mode register
        parameter SENSOR_MODE_WIDTH =     10,
        parameter SENSOR_HIST_EN_BITS =    0, // 0..3 1 - enable histogram modules, disable after processing the started frame
        parameter SENSOR_HIST_NRST_BITS =  4, // 0 - immediately reset all histogram modules 
        parameter SENSOR_CHN_EN_BIT =      8,  // 1 - this enable channel
        parameter SENSOR_16BIT_BIT =       9, // 0 - 8 bpp mode, 1 - 16 bpp (bypass gamma). Gamma-processed data is still used for histograms
    
    parameter SENSI2C_CTRL_RADDR =        2, // 302..'h303
    parameter SENSI2C_CTRL_MASK =     'h7fe,
      // sensor_i2c_io relative control register addresses
      parameter SENSI2C_CTRL =          'h0,
    // Control register bits
        parameter SENSI2C_CMD_RESET =       14, // [14]   reset all FIFO (takes 16 clock pulses), also - stops i2c until run command
        parameter SENSI2C_CMD_RUN =         13, // [13:12]3 - run i2c, 2 - stop i2c (needed before software i2c), 1,0 - no change to run state
        parameter SENSI2C_CMD_RUN_PBITS =    1,
        parameter SENSI2C_CMD_BYTES =       11, // if 1, use [10:9] to set command bytes to send after slave address (0..3)
        parameter SENSI2C_CMD_BYTES_PBITS =  2,
        parameter SENSI2C_CMD_DLY =          8, // [7:0]  - duration of quater i2c cycle (if 0, [3:0] control SCL+SDA)
        parameter SENSI2C_CMD_DLY_PBITS =    8,
    // direct control of SDA/SCL mutually exclusive with DLY control, disabled by running i2c
        parameter SENSI2C_CMD_SCL =         16, // [17:16] : 0: NOP, 1: 1'b0->SCL, 2: 1'b1->SCL, 3: 1'bz -> SCL 
        parameter SENSI2C_CMD_SCL_WIDTH =    2,
        parameter SENSI2C_CMD_SDA =         18, // [19:18] : 0: NOP, 1: 1'b0->SDA, 2: 1'b1->SDA, 3: 1'bz -> SDA,
        parameter SENSI2C_CMD_SDA_WIDTH =    2,
      
      parameter SENSI2C_STATUS =        'h1,
    
    parameter SENS_SYNC_RADDR  =        'h4,
    parameter SENS_SYNC_MASK  =         'h7fc,
      // 2 locations reserved for control/status (if they will be needed)
      parameter SENS_SYNC_MULT  =       'h2,   // relative register address to write number of frames to combine in one (minus 1, '0' - each farme)
      parameter SENS_SYNC_LATE  =       'h3,    // number of lines to delay late frame sync
    
    
    
    parameter SENS_GAMMA_RADDR =        'h38, // 'h38..'h3b was 4,
    parameter SENS_GAMMA_ADDR_MASK =   'h7fc,
      // sens_gamma registers
      parameter SENS_GAMMA_CTRL =        'h0,
      parameter SENS_GAMMA_ADDR_DATA =   'h1, // bit 20 ==1 - table address, bit 20==0 - table data (18 bits)
      parameter SENS_GAMMA_HEIGHT01 =    'h2, // bits [15:0] - height minus 1 of image 0, [31:16] - height-1 of image1
      parameter SENS_GAMMA_HEIGHT2 =     'h3, // bits [15:0] - height minus 1 of image 2 ( no need for image 3)
        // bits of the SENS_GAMMA_CTRL mode register
        parameter SENS_GAMMA_MODE_WIDTH =  5, // does not include trig
        parameter SENS_GAMMA_MODE_BAYER =  0,
        parameter SENS_GAMMA_MODE_PAGE =   2,
        parameter SENS_GAMMA_MODE_EN =     3,
        parameter SENS_GAMMA_MODE_REPET =  4,
        parameter SENS_GAMMA_MODE_TRIG =   5,
        
// Vignetting correction / pixel value scaling - controlled via single data word (same as in 252), some of bits [23:16]
// are used to select register, bits 25:24 - select sub-frame
    parameter SENS_LENS_RADDR =             'h3c, 
    parameter SENS_LENS_ADDR_MASK =         'h7fc,
    parameter SENS_LENS_COEFF =             'h3, // set vignetting/scale coefficients (
      parameter SENS_LENS_AX =              'h00, // 00000...
      parameter SENS_LENS_AX_MASK =         'hf8,
      parameter SENS_LENS_AY =              'h08, // 00001...
      parameter SENS_LENS_AY_MASK =         'hf8,
      parameter SENS_LENS_C =               'h10, // 00010...
      parameter SENS_LENS_C_MASK =          'hf8,
      parameter SENS_LENS_BX =              'h20, // 001.....
      parameter SENS_LENS_BX_MASK =         'he0,
      parameter SENS_LENS_BY =              'h40, // 010.....
      parameter SENS_LENS_BY_MASK =         'he0,
      parameter SENS_LENS_SCALES =          'h60, // 01100...
      parameter SENS_LENS_SCALES_MASK =     'hf8,
      parameter SENS_LENS_FAT0_IN =         'h68, // 01101000
      parameter SENS_LENS_FAT0_IN_MASK =    'hff,
      parameter SENS_LENS_FAT0_OUT =        'h69, // 01101001
      parameter SENS_LENS_FAT0_OUT_MASK =   'hff,
      parameter SENS_LENS_POST_SCALE =      'h6a, // 01101010
      parameter SENS_LENS_POST_SCALE_MASK = 'hff,
    
    parameter SENSIO_RADDR =               8, //'h408  .. 'h40f
    parameter SENSIO_ADDR_MASK =       'h7f8,
      // sens_parallel12 registers
      parameter SENSIO_CTRL =           'h0,
        // SENSIO_CTRL register bits
        parameter SENS_CTRL_MRST =        0,  //  1: 0
        parameter SENS_CTRL_ARST =        2,  //  3: 2
        parameter SENS_CTRL_ARO =         4,  //  5: 4
        parameter SENS_CTRL_RST_MMCM =    6,  //  7: 6
        parameter SENS_CTRL_EXT_CLK =     8,  //  9: 8
        parameter SENS_CTRL_LD_DLY =     10,  // 10
        parameter SENS_CTRL_QUADRANTS =  12,  // 17:12, enable - 20
        parameter SENS_CTRL_QUADRANTS_WIDTH = 6,
        parameter SENS_CTRL_QUADRANTS_EN =   20,  // 17:12, enable - 20 (2 bits reserved)
      parameter SENSIO_STATUS =         'h1,
      parameter SENSIO_JTAG =           'h2,
        // SENSIO_JTAG register bits
        parameter SENS_JTAG_PGMEN =       8,
        parameter SENS_JTAG_PROG =        6,
        parameter SENS_JTAG_TCK =         4,
        parameter SENS_JTAG_TMS =         2,
        parameter SENS_JTAG_TDI =         0,
      parameter SENSIO_WIDTH =          'h3, // 1.. 2^16, 0 - use HACT
      parameter SENSIO_DELAYS =         'h4, // 'h4..'h7
        // 4 of 8-bit delays per register
    // sensor_i2c_io command/data write registers s (relative to SENSOR_GROUP_ADDR)
    parameter SENSI2C_ABS_RADDR =       'h10, // 'h410..'h41f
    parameter SENSI2C_REL_RADDR =       'h20, // 'h420..'h42f
    parameter SENSI2C_ADDR_MASK =       'h7f0, // both for SENSI2C_ABS_ADDR and SENSI2C_REL_ADDR

    // sens_hist registers (relative to SENSOR_GROUP_ADDR)
    parameter HISTOGRAM_RADDR0 =        'h30, //
    parameter HISTOGRAM_RADDR1 =        'h32, //
    parameter HISTOGRAM_RADDR2 =        'h34, //
    parameter HISTOGRAM_RADDR3 =        'h36, //
    parameter HISTOGRAM_ADDR_MASK =     'h7fe, // for each channel
      // sens_hist registers
      parameter HISTOGRAM_LEFT_TOP =     'h0,
      parameter HISTOGRAM_WIDTH_HEIGHT = 'h1, // 1.. 2^16, 0 - use HACT
    
    //sensor_i2c_io other parameters
    parameter integer SENSI2C_DRIVE=     12,
    parameter SENSI2C_IBUF_LOW_PWR=      "TRUE",
    parameter SENSI2C_IOSTANDARD =       "LVCMOS25",
    parameter SENSI2C_SLEW =             "SLOW",
    
    //sensor_fifo parameters
    parameter SENSOR_DATA_WIDTH =        12,
    parameter SENSOR_FIFO_2DEPTH =       4,
    parameter SENSOR_FIFO_DELAY =        4'd5, // 7,
    // other parameters for histogram_saxi module
    parameter HIST_SAXI_ADDR_MASK =      'h7f0,
      parameter HIST_SAXI_MODE_WIDTH =   8,
      parameter HIST_SAXI_EN =           0,
      parameter HIST_SAXI_NRESET =       1,
      parameter HIST_CONFIRM_WRITE =     2, // wait write confirmation for each block
                                            // bit 3 is not used
      parameter HIST_SAXI_AWCACHE =      4, // ..7  Write 4'h3 there,  cache mode (4 bits, default 4'h3)
      
    parameter HIST_SAXI_MODE_ADDR_MASK = 'h7ff,
    parameter NUM_FRAME_BITS =           4, // number of bits use for frame number 
    
    // Other parameters
    parameter SENS_SYNC_FBITS =          16,    // number of bits in a frame counter for linescan mode
    parameter SENS_SYNC_LBITS =          16,    // number of bits in a line counter for sof_late output (limited by eof) 
    parameter SENS_SYNC_LATE_DFLT =      15,    // number of lines to delay late frame sync
    parameter SENS_SYNC_MINBITS =        8,    // number of bits to enforce minimal frame period 
    parameter SENS_SYNC_MINPER =         130,    // minimal frame period (in pclk/mclk?) 
    
    
    // sens_parallel12 other parameters
    
//    parameter IODELAY_GRP ="IODELAY_SENSOR", // may need different for different channels?
    parameter integer IDELAY_VALUE =     0,
    parameter integer PXD_DRIVE =        12,
    parameter PXD_IBUF_LOW_PWR =         "TRUE",
    parameter PXD_IOSTANDARD =           "LVCMOS25",
    parameter PXD_SLEW =                 "SLOW",
`ifdef use200Mhz
    parameter real SENS_REFCLK_FREQUENCY = 300.0, // same as REFCLK_FREQUENCY
`else
    parameter real SENS_REFCLK_FREQUENCY = 200.0,
`endif    
    parameter SENS_HIGH_PERFORMANCE_MODE = "FALSE",
    
    parameter SENS_PHASE_WIDTH=          8,      // number of bits for te phase counter (depends on divisors)
    parameter SENS_PCLK_PERIOD =         10.000,  // input period in ns, 0..100.000 - MANDATORY, resolution down to 1 ps
    parameter SENS_BANDWIDTH =           "OPTIMIZED",  //"OPTIMIZED", "HIGH","LOW"

    parameter CLKFBOUT_MULT_SENSOR =     8,  // 100 MHz --> 800 MHz
    parameter CLKFBOUT_PHASE_SENSOR =    0.000,  // CLOCK FEEDBACK phase in degrees (3 significant digits, -360.000...+360.000)
    parameter IPCLK_PHASE =              0.000,
    parameter IPCLK2X_PHASE =            0.000,

//    parameter BUF_IPCLK =                "BUFMR", //G", // "BUFR", // BUFR fails for both clocks for sensors1 and 3
//    parameter BUF_IPCLK2X =              "BUFMR", //G", // "BUFR",  

    parameter BUF_IPCLK_SENS0 =          "BUFR", //G", // "BUFR", // BUFR fails for both clocks for sensors1 and 3
    parameter BUF_IPCLK2X_SENS0 =        "BUFR", //G", // "BUFR",  

    parameter BUF_IPCLK_SENS1 =          "BUFG", // "BUFR", // BUFR fails for both clocks for sensors1 and 3
    parameter BUF_IPCLK2X_SENS1 =        "BUFG", // "BUFR",  

    parameter BUF_IPCLK_SENS2 =          "BUFR", //G", // "BUFR", // BUFR fails for both clocks for sensors1 and 3
    parameter BUF_IPCLK2X_SENS2 =        "BUFR", //G", // "BUFR",  

    parameter BUF_IPCLK_SENS3 =          "BUFG", // "BUFR", // BUFR fails for both clocks for sensors1 and 3
    parameter BUF_IPCLK2X_SENS3 =        "BUFG", // "BUFR",  

    parameter SENS_DIVCLK_DIVIDE =       1,            // Integer 1..106. Divides all outputs with respect to CLKIN
    parameter SENS_REF_JITTER1   =       0.010,        // Expectet jitter on CLKIN1 (0.000..0.999)
    parameter SENS_REF_JITTER2   =       0.010,
    parameter SENS_SS_EN         =       "FALSE",      // Enables Spread Spectrum mode
    parameter SENS_SS_MODE       =       "CENTER_HIGH",//"CENTER_HIGH","CENTER_LOW","DOWN_HIGH","DOWN_LOW"
    parameter SENS_SS_MOD_PERIOD =       10000,        // integer 4000-40000 - SS modulation period in ns
    
    parameter CMPRS_NUM_AFI_CHN =         1, // 2, // 1 - multiplex all 4 compressors to a single AXI_HP, 2 - split between to AXI_HP
    parameter CMPRS_GROUP_ADDR =          'h600, // total of 'h60
    parameter CMPRS_BASE_INC =            'h10,
    parameter CMPRS_AFIMUX_RADDR0=        'h40,  // relative to CMPRS_NUM_AFI_CHN ( 16 addr)
    parameter CMPRS_AFIMUX_RADDR1=        'h50,  // relative to CMPRS_NUM_AFI_CHN ( 16 addr)
    parameter CMPRS_AFIMUX_MASK=          'h7f0,
    
    parameter CMPRS_STATUS_REG_BASE=      'h10,
    parameter CMPRS_HIFREQ_REG_BASE=      'h14, 
    parameter CMPRS_AFIMUX_REG_ADDR0=     'h18,  // Uses 4 locations
    parameter CMPRS_AFIMUX_REG_ADDR1=     'h1c,  // Uses 4 locations
    
    parameter CMPRS_STATUS_REG_INC=        1,
    parameter CMPRS_HIFREQ_REG_INC=        1,
    parameter CMPRS_MASK=                 'h7f8,
    parameter CMPRS_CONTROL_REG=           0,
    parameter CMPRS_STATUS_CNTRL=          1,
    parameter CMPRS_FORMAT=                2,
    parameter CMPRS_COLOR_SATURATION=      3,
    parameter CMPRS_CORING_MODE=           4,
    parameter CMPRS_TABLES=                6, // 6..7

    // Bit-fields in compressor control word
    parameter CMPRS_CBIT_RUN =             2, // bit # to control compressor run modes
    parameter CMPRS_CBIT_RUN_BITS =        2, // number of bits to control compressor run modes
    parameter CMPRS_CBIT_QBANK =           6, // bit # to control quantization table page
    parameter CMPRS_CBIT_QBANK_BITS =      3, // number of bits to control quantization table page
    parameter CMPRS_CBIT_DCSUB =           8, // bit # to control extracting DC components bypassing DCT
    parameter CMPRS_CBIT_DCSUB_BITS =      1, // bit # to control extracting DC components bypassing DCT
    parameter CMPRS_CBIT_CMODE =          13, // bit # to control compressor color modes
    parameter CMPRS_CBIT_CMODE_BITS =      4, // number of bits to control compressor color modes
    parameter CMPRS_CBIT_FRAMES =         15, // bit # to control compressor multi/single frame buffer modes
    parameter CMPRS_CBIT_FRAMES_BITS =     1, // number of bits to control compressor multi/single frame buffer modes
    parameter CMPRS_CBIT_BAYER =          20, // bit # to control compressor Bayer shift mode
    parameter CMPRS_CBIT_BAYER_BITS =      2, // number of bits to control compressor Bayer shift mode
    parameter CMPRS_CBIT_FOCUS =          23, // bit # to control compressor focus display mode
    parameter CMPRS_CBIT_FOCUS_BITS =      2, // number of bits to control compressor focus display mode
    // compressor bit-fields decode
    parameter CMPRS_CBIT_RUN_RST =         2'h0, // reset compressor, stop immediately
//      parameter CMPRS_CBIT_RUN_DISABLE =     2'h1, // disable compression of the new frames, finish any already started
    parameter CMPRS_CBIT_RUN_STANDALONE =  2'h2, // enable compressor, compress single frame from memory (async)
    parameter CMPRS_CBIT_RUN_ENABLE =      2'h3, // enable compressor, enable synchronous compression mode
    parameter CMPRS_CBIT_CMODE_JPEG18 =    4'h0, // color 4:2:0
    parameter CMPRS_CBIT_CMODE_MONO6 =     4'h1, // mono 4:2:0 (6 blocks)
    parameter CMPRS_CBIT_CMODE_JP46 =      4'h2, // jp4, 6 blocks, original
    parameter CMPRS_CBIT_CMODE_JP46DC =    4'h3, // jp4, 6 blocks, dc -improved
    parameter CMPRS_CBIT_CMODE_JPEG20 =    4'h4, // mono, 4 blocks (but still not actual monochrome JPEG as the blocks are scanned in 2x2 macroblocks)
    parameter CMPRS_CBIT_CMODE_JP4 =       4'h5, // jp4,  4 blocks, dc-improved
    parameter CMPRS_CBIT_CMODE_JP4DC =     4'h6, // jp4,  4 blocks, dc-improved
    parameter CMPRS_CBIT_CMODE_JP4DIFF =   4'h7, // jp4,  4 blocks, differential
    parameter CMPRS_CBIT_CMODE_JP4DIFFHDR =  4'h8, // jp4,  4 blocks, differential, hdr
    parameter CMPRS_CBIT_CMODE_JP4DIFFDIV2 = 4'h9, // jp4,  4 blocks, differential, divide by 2
    parameter CMPRS_CBIT_CMODE_JP4DIFFHDRDIV2 = 4'ha, // jp4,  4 blocks, differential, hdr,divide by 2
    parameter CMPRS_CBIT_CMODE_MONO1 =     4'hb, // mono JPEG (not yet implemented)
    parameter CMPRS_CBIT_CMODE_MONO4 =     4'he, // mono 4 blocks
    parameter CMPRS_CBIT_FRAMES_SINGLE =   0, //1, // use a single-frame buffer for images

    parameter CMPRS_COLOR18 =              0, // JPEG 4:2:0 with 18x18 overlapping tiles for de-bayer
    parameter CMPRS_COLOR20 =              1, // JPEG 4:2:0 with 18x18 overlapping tiles for de-bayer (not implemented)
    parameter CMPRS_MONO16 =               2, // JPEG 4:2:0 with 16x16 non-overlapping tiles, color components zeroed
    parameter CMPRS_JP4 =                  3, // JP4 mode with 16x16 macroblocks
    parameter CMPRS_JP4DIFF =              4, // JP4DIFF mode TODO: see if correct
    parameter CMPRS_MONO8 =                7,  // Regular JPEG monochrome with 8x8 macroblocks (not yet implemented)
    
    parameter CMPRS_FRMT_MBCM1 =           0, // bit # of number of macroblock columns minus 1 field in format word
    parameter CMPRS_FRMT_MBCM1_BITS =     13, // number of bits in number of macroblock columns minus 1 field in format word
    parameter CMPRS_FRMT_MBRM1 =          13, // bit # of number of macroblock rows minus 1 field in format word
    parameter CMPRS_FRMT_MBRM1_BITS =     13, // number of bits in number of macroblock rows minus 1 field in format word
    parameter CMPRS_FRMT_LMARG =          26, // bit # of left margin field in format word
    parameter CMPRS_FRMT_LMARG_BITS =      5, // number of bits in left margin field in format word
    parameter CMPRS_CSAT_CB =              0, // bit # of number of blue scale field in color saturation word
    parameter CMPRS_CSAT_CB_BITS =        10, // number of bits in blue scale field in color saturation word
    parameter CMPRS_CSAT_CR =             12, // bit # of number of red scale field in color saturation word
    parameter CMPRS_CSAT_CR_BITS =        10, // number of bits in red scale field in color saturation word
    parameter CMPRS_CORING_BITS =          3,  // number of bits in coring mode
    
    parameter CMPRS_TIMEOUT_BITS=         12,
    parameter CMPRS_TIMEOUT=            1000,   // mclk cycles
    
    parameter CMPRS_AFIMUX_EN=            'h0, // enables (gl;obal and per-channel)
    parameter CMPRS_AFIMUX_RST=           'h1, // per-channel resets
    parameter CMPRS_AFIMUX_MODE=          'h2, // per-channel select - which register to return as status
    parameter CMPRS_AFIMUX_STATUS_CNTRL=  'h4, // .. 'h7
    parameter CMPRS_AFIMUX_SA_LEN=        'h8, // .. 'hf

    parameter CMPRS_AFIMUX_WIDTH =         26, // maximal for status: currently only works with 26)
    parameter CMPRS_AFIMUX_CYCBITS =        3,
    parameter AFI_MUX_BUF_LATENCY =      4'd2,  // buffers read latency from fifo_ren* to fifo_rdata* valid : 2 if no register layers are used
    // GPIO control : 'h700..'h701, status: 'h30
    parameter integer GPIO_DRIVE =         12,
    parameter GPIO_ADDR =                 'h700, // .701
    parameter GPIO_MASK =                 'h7fe,
    parameter GPIO_STATUS_REG_ADDR =      'h30,  // address where status can be read out (10 GPIO inputs)
    
    parameter GPIO_IBUF_LOW_PWR =         "TRUE",
    parameter GPIO_IOSTANDARD =           "LVCMOS15", // power is 1.5V
    parameter GPIO_SLEW =                 "SLOW",
    
    parameter GPIO_SET_PINS =              0,  // Set GPIO output state, give control for some bits to other modules 
    parameter GPIO_SET_STATUS =            1,   // set status mode
    parameter GPIO_N =                     10, // number of GPIO bits to control
    parameter GPIO_PORTEN =                24, // bit number to control port enables (up from this) 
    // Timing (rtc+camsync) parameters    
    parameter RTC_ADDR=                    'h704, // 'h707
    parameter CAMSYNC_ADDR =               'h708, // 'h70f
    parameter RTC_STATUS_REG_ADDR =        'h31,   // (1 loc) address where status can be read out (currently just sequence # and alternating bit) 
    parameter RTC_SEC_USEC_ADDR =          'h32,  // ..'h33 address where seconds of the snapshot can be read (microseconds - next address)
    parameter RTC_MASK =                   'h7fc,
    parameter CAMSYNC_MASK =               'h7f8,
    parameter CAMSYNC_MODE =               'h0,
    parameter CAMSYNC_TRIG_SRC =           'h1, // setup trigger source
    parameter CAMSYNC_TRIG_DST =           'h2, // setup trigger destination line(s)
    parameter CAMSYNC_TRIG_PERIOD =        'h3, // setup output trigger period
    parameter CAMSYNC_TRIG_DELAY0 =        'h4, // setup input trigger delay
    parameter CAMSYNC_TRIG_DELAY1 =        'h5, // setup input trigger delay
    parameter CAMSYNC_TRIG_DELAY2 =        'h6, // setup input trigger delay
    parameter CAMSYNC_TRIG_DELAY3 =        'h7, // setup input trigger delay

    parameter CAMSYNC_EN_BIT =             'h0, // enable module (0 - reset)
    parameter CAMSYNC_SNDEN_BIT =          'h2, // enable writing ts_snd_en
    parameter CAMSYNC_EXTERNAL_BIT =       'h4, // enable writing ts_external (0 - local timestamp in the frame header)
    parameter CAMSYNC_TRIGGERED_BIT =      'h6, // triggered mode ( 0- async)
    parameter CAMSYNC_MASTER_BIT =         'h9, // select a 2-bit master channel (master delay may be used as a flash delay)
    parameter CAMSYNC_CHN_EN_BIT =         'he, // per-channel enable timestamp generation
    parameter CAMSYNC_PRE_MAGIC =          6'b110100,
    parameter CAMSYNC_POST_MAGIC =         6'b001101,
    
    parameter RTC_MHZ=                    25, // RTC input clock in MHz (should be interger number)
    parameter RTC_BITC_PREDIV =            5, // number of bits to generate 2 MHz pulses counting refclk 
    parameter RTC_SET_USEC=                0, // 20-bit number of microseconds
    parameter RTC_SET_SEC=                 1, // 32-bit full number of seconds (und actually update timer)
    parameter RTC_SET_CORR=                2, // write correction 16-bit signed
    parameter RTC_SET_STATUS=              3,  // generate an output pulse to take a snapshot
    // Command sequencers parameters
    parameter CMDFRAMESEQ_ADDR_BASE=       'h780,
    parameter CMDFRAMESEQ_ADDR_INC=        'h20,
    parameter CMDFRAMESEQ_MASK=            'h7e0,
    parameter CMDFRAMESEQ_DEPTH =           64, // 32/64/128
    parameter CMDFRAMESEQ_ABS =             0,
    parameter CMDFRAMESEQ_REL =             16,
    parameter CMDFRAMESEQ_CTRL =            31,
    parameter CMDFRAMESEQ_RST_BIT =         14,
    parameter CMDFRAMESEQ_RUN_BIT =         13,
    
    parameter CMDSEQMUX_ADDR =              'h702, // only status control
    parameter CMDSEQMUX_MASK =              'h7ff,
    parameter CMDSEQMUX_STATUS =            'h38,
    // Logger parameters
    parameter LOGGER_ADDR =                 'h720, //..'h721
    parameter LOGGER_STATUS =               'h722, // .. 'h722
    parameter LOGGER_STATUS_REG_ADDR =      'h39, // just 1 location)
    parameter LOGGER_MASK =                 'h7fe,
    parameter LOGGER_STATUS_MASK =          'h7ff,

    parameter LOGGER_PAGE_IMU =             0, // 'h00..'h1f - overlaps with period/duration/halfperiod/config?
    parameter LOGGER_PAGE_GPS =             1, // 'h20..'h3f
    parameter LOGGER_PAGE_MSG =             2, // 'h40..'h5f
    
    parameter LOGGER_PERIOD =               0,
    parameter LOGGER_BIT_DURATION =         1,
    parameter LOGGER_BIT_HALF_PERIOD =      2, //rs232 half bit period
    parameter LOGGER_CONFIG =               3,

    parameter LOGGER_CONF_IMU =             2,
    parameter LOGGER_CONF_IMU_BITS =        2,
    parameter LOGGER_CONF_GPS =             7,
    parameter LOGGER_CONF_GPS_BITS =        4,
    parameter LOGGER_CONF_MSG =            13,
    parameter LOGGER_CONF_MSG_BITS =        5,
    parameter LOGGER_CONF_SYN =            18, // 15,
    parameter LOGGER_CONF_SYN_BITS =        4, // 1,
    parameter LOGGER_CONF_EN =             20, // 17,
    parameter LOGGER_CONF_EN_BITS =         1,
    parameter LOGGER_CONF_DBG =            25, // 22,
    parameter LOGGER_CONF_DBG_BITS =        4,

    parameter MULT_SAXI_HALF_BRAM_IN =      1,     // 0 - use full 36Kb BRAM for the buffer, 1 - use just half
    parameter MULT_SAXI_WLOG =              4,      // number of bits for the input data ( 3 - 8 bit, 4 - 16-bit, 5 - 32-bit
    
    parameter MULT_SAXI_ADDR =           'h730,  // ..'h737
    parameter MULT_SAXI_CNTRL_ADDR =     'h738,  // ..'h739
    parameter MULT_SAXI_STATUS_REG =     'h34,   //..'h37 uses 4 consecutive locations
    parameter MULT_SAXI_HALF_BRAM =       1,     // 0 - use full 36Kb BRAM for the buffer, 1 - use just half
    parameter MULT_SAXI_BSLOG0 =          4,     // number of bits to represent burst size (4 - b.s. = 16, 0 - b.s = 1)
    parameter MULT_SAXI_BSLOG1 =          4,
    parameter MULT_SAXI_BSLOG2 =          4,
    parameter MULT_SAXI_BSLOG3 =          4,
    parameter MULT_SAXI_MASK =           'h7f8,  // 4 address/length pairs. In bytes, but lower bits are set to 0?
    parameter MULT_SAXI_CNTRL_MASK =     'h7fe,  // mode and status - 2 locations
    parameter MULT_SAXI_AWCACHE =         4'h3, //..7 cache mode (4 bits, default 4'h3)
    parameter MULT_SAXI_ADV_WR =          4, // number of clock cycles before end of write to genearte adv_wr_done
    parameter MULT_SAXI_ADV_RD =          3, // number of clock cycles before end of write to genearte adv_wr_done

    // Clock management (input, generation, buffering) 
    parameter CLK_ADDR =                  'h728, // ..'h729
    parameter CLK_MASK =                  'h7fe, //
    parameter CLK_STATUS_REG_ADDR =       'h3a,  //  
    parameter CLK_CNTRL =                 0,
    parameter CLK_STATUS =                1,
    
    parameter CLKIN_PERIOD_AXIHP =        20, //ns >1.25, 600<Fvco<1200
    parameter DIVCLK_DIVIDE_AXIHP =       1,
    parameter CLKFBOUT_MULT_AXIHP =       18, // Fvco=Fclkin*CLKFBOUT_MULT_F/DIVCLK_DIVIDE, Fout=Fvco/CLKOUT#_DIVIDE
    parameter CLKOUT_DIV_AXIHP =           6,   // To get 150MHz for the reference clock
    parameter BUF_CLK1X_AXIHP =           "BUFG", // "BUFG", "BUFH", "BUFR", "NONE"
    
    parameter CLKIN_PERIOD_PCLK =         42, // 24MHz 
    parameter DIVCLK_DIVIDE_PCLK =         1,
    parameter CLKFBOUT_MULT_PCLK =        40, // 960 MHz
    parameter CLKOUT_DIV_PCLK =           10, // 96MHz 
    parameter CLKOUT_DIV_PCLK2X =          5, // 192 MHz
    parameter PHASE_CLK2X_PCLK =           0.000, 
    parameter BUF_CLK1X_PCLK =            "BUFG",
    parameter BUF_CLK1X_PCLK2X =          "BUFG",  
    
    parameter CLKIN_PERIOD_XCLK =         20, // 50MHz 
    parameter DIVCLK_DIVIDE_XCLK =         1,
    parameter CLKFBOUT_MULT_XCLK =        20, // 50*20=1000 MHz
    parameter CLKOUT_DIV_XCLK =           10, // 100 MHz 
    parameter CLKOUT_DIV_XCLK2X =          5, // 200 MHz
    parameter PHASE_CLK2X_XCLK =           0.000, 
    parameter BUF_CLK1X_XCLK =            "BUFG",
    parameter BUF_CLK1X_XCLK2X =          "BUFG",  
    
    parameter CLKIN_PERIOD_SYNC =         20, // 50MHz 
    parameter DIVCLK_DIVIDE_SYNC =         1,
    parameter CLKFBOUT_MULT_SYNC =        20, // 50*20=1000 MHz
    parameter CLKOUT_DIV_SYNC =           10, // 100 MHz 
    parameter BUF_CLK1X_SYNC =            "BUFG",
    
    parameter MEMCLK_CAPACITANCE =        "DONT_CARE",
    parameter MEMCLK_IBUF_DELAY_VALUE =   "0",
    parameter MEMCLK_IBUF_LOW_PWR =       "TRUE",
    parameter MEMCLK_IFD_DELAY_VALUE =    "AUTO",
    parameter MEMCLK_IOSTANDARD =         "SSTL15",

    parameter FFCLK0_CAPACITANCE =        "DONT_CARE",
    parameter FFCLK0_DIFF_TERM =          "FALSE",
    parameter FFCLK0_DQS_BIAS =           "FALSE",
    parameter FFCLK0_IBUF_DELAY_VALUE =   "0",
    parameter FFCLK0_IBUF_LOW_PWR =       "TRUE",
    parameter FFCLK0_IFD_DELAY_VALUE =    "AUTO",
    parameter FFCLK0_IOSTANDARD =         "RSDS_25",
    
    parameter FFCLK1_CAPACITANCE =        "DONT_CARE",
    parameter FFCLK1_DIFF_TERM =          "FALSE",
    parameter FFCLK1_DQS_BIAS =           "FALSE",
    parameter FFCLK1_IBUF_DELAY_VALUE =   "0",
    parameter FFCLK1_IBUF_LOW_PWR =       "TRUE",
    parameter FFCLK1_IFD_DELAY_VALUE =    "AUTO",
    parameter FFCLK1_IOSTANDARD =         "RSDS_25"
    
    
    
    
    
    
    
    