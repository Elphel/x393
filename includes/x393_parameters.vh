/*******************************************************************************
 * File: x393_parameters.vh
 * Date:2015-02-07  
 * Author: andrey     
 * Description: Parameters for the x393 (simulation and implementation)
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
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
    parameter MCONTR_CMD_WR_ADDR =      'h0000, // AXI write to command sequence memory
    parameter MCONTR_BUF0_RD_ADDR =     'h0400, // AXI read address from buffer 0 (PS sequence, memory read) 
    parameter MCONTR_BUF0_WR_ADDR =     'h0400, // AXI write address to buffer 0 (PS sequence, memory write)
//    parameter MCONTR_BUF1_RD_ADDR =  'h0800, // AXI read address from buffer 1 (PL sequence, scanline, memory read) // not used - replaced with membridge
//    parameter MCONTR_BUF1_WR_ADDR =  'h0800, // AXI write address to buffer 1 (PL sequence, scanline, memory write) // not used - replaced with membridge
    parameter MCONTR_BUF2_RD_ADDR =     'h0c00, // AXI read address from buffer 2 (PL sequence, tiles, memory read)
    parameter MCONTR_BUF2_WR_ADDR =     'h0c00, // AXI write address to buffer 2 (PL sequence, tiles, memory write)
    parameter MCONTR_BUF3_RD_ADDR =     'h1000, // AXI read address from buffer 3 (PL sequence, scanline, memory read)
    parameter MCONTR_BUF3_WR_ADDR =     'h1000, // AXI write address to buffer 3 (PL sequence, scanline, memory write)
    parameter MCONTR_BUF4_RD_ADDR =     'h1400, // AXI read address from buffer 4 (PL sequence, tiles, memory read)
    parameter MCONTR_BUF4_WR_ADDR =     'h1400, // AXI write address to buffer 4 (PL sequence, tiles, memory write)
    parameter CONTROL_ADDR =            'h2000, // AXI write address of control write registers
    parameter CONTROL_ADDR_MASK =       'h3c00, // AXI write mask of control registers
    parameter CONTROL_RBACK_ADDR =      'h2000, // AXI read address of control registers readback
    parameter CONTROL_RBACK_ADDR_MASK = 'h3c00, // AXI mask of control registers readback addresses
    parameter CONTROL_RBACK_DEPTH=          10, // 
    parameter STATUS_ADDR =             'h2400, // AXI write address of status read registers
    parameter STATUS_ADDR_MASK =        'h3c00, // AXI write address of status registers
    parameter AXI_WR_ADDR_BITS =            14,
    parameter AXI_RD_ADDR_BITS =            14,
    parameter STATUS_DEPTH=                  8,  // 256 cells, maybe just 16..64 are enough?
    
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
    
//    parameter CMD0_ADDR =           'h0800, // AXI write to command sequence memory
//    parameter CMD0_ADDR_MASK =      'h1800, // AXI read address mask for the command sequence memory
    parameter MCNTRL_PS_ADDR=                    'h100,
    parameter MCNTRL_PS_MASK=                    'h3e0, // both channels 0 and 1
    parameter MCNTRL_PS_STATUS_REG_ADDR=         'h2,
    parameter MCNTRL_PS_EN_RST=                  'h0,
    parameter MCNTRL_PS_CMD=                     'h1,
    parameter MCNTRL_PS_STATUS_CNTRL=            'h2,

    parameter NUM_XFER_BITS=                       6,    // number of bits to specify transfer length
    parameter FRAME_WIDTH_BITS=                   13,    // Maximal frame width - 8-word (16 bytes) bursts 
    parameter FRAME_HEIGHT_BITS=                  16,    // Maximal frame height 
    parameter MCNTRL_SCANLINE_CHN1_ADDR=         'h120,
    parameter MCNTRL_SCANLINE_CHN3_ADDR=         'h130,
    parameter MCNTRL_SCANLINE_MASK=              'h3f0, // both channels 0 and 1
    parameter MCNTRL_SCANLINE_MODE=              'h0,   // set mode register: {extra_pages[1:0],enable,!reset}
    parameter MCNTRL_SCANLINE_STATUS_CNTRL=      'h1,   // control status reporting
    parameter MCNTRL_SCANLINE_STARTADDR=         'h2,   // 22-bit frame start address (3 CA LSBs==0. BA==0)
    parameter MCNTRL_SCANLINE_FRAME_FULL_WIDTH=  'h3,   // Padded line length (8-row increment), in 8-bursts (16 bytes)
    parameter MCNTRL_SCANLINE_WINDOW_WH=         'h4,   // low word - 13-bit window width (0->'h4000), high word - 16-bit frame height (0->'h10000)
    parameter MCNTRL_SCANLINE_WINDOW_X0Y0=       'h5,   // low word - 13-bit window left, high word - 16-bit window top
    parameter MCNTRL_SCANLINE_WINDOW_STARTXY=    'h6,   // low word - 13-bit start X (relative to window), high word - 16-bit start y
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
    parameter MCNTRL_TILED_MASK=            'h3f0, // both channels 0 and 1
    parameter MCNTRL_TILED_MODE=            'h0,   // set mode register: {extra_pages[1:0],write_mode,enable,!reset}
    parameter MCNTRL_TILED_STATUS_CNTRL=    'h1,   // control status reporting
    parameter MCNTRL_TILED_STARTADDR=       'h2,   // 22-bit frame start address (3 CA LSBs==0. BA==0)
    parameter MCNTRL_TILED_FRAME_FULL_WIDTH='h3,   // Padded line length (8-row increment), in 8-bursts (16 bytes)
    parameter MCNTRL_TILED_WINDOW_WH=       'h4,   // low word - 13-bit window width (0->'h4000), high word - 16-bit frame height (0->'h10000)
    parameter MCNTRL_TILED_WINDOW_X0Y0=     'h5,   // low word - 13-bit window left, high word - 16-bit window top
    parameter MCNTRL_TILED_WINDOW_STARTXY=  'h6,   // low word - 13-bit start X (relative to window), high word - 16-bit start y
                                                      // Start XY can be used when read command to start from the middle
                                                      // TODO: Add number of blocks to R/W? (blocks can be different) - total length?
                                                      // Read back current address (for debugging)?
    parameter MCNTRL_TILED_TILE_WHS=         'h7,   // low word - 6-bit tile width in 8-bursts, high - tile height (0 - > 64)
    parameter MCNTRL_TILED_STATUS_REG_CHN2_ADDR= 'h5,
    parameter MCNTRL_TILED_STATUS_REG_CHN4_ADDR= 'h7,
    parameter MCNTRL_TILED_PENDING_CNTR_BITS=2,    // Number of bits to count pending trasfers, currently 2 is enough, but may increase
                                                   // if memory controller will allow programming several sequences in advance to
                                                   // spread long-programming (tiled) over fast-programming (linear) requests.
                                                   // But that should not be too big to maintain 2-level priorities
    parameter MCNTRL_TILED_FRAME_PAGE_RESET =1'b0, // reset internal page number to zero at the frame start (false - only when hard/soft reset)
    parameter BUFFER_DEPTH32=                10,   // Block rum buffer depth on a 32-bit port

// Channel test module parameters
    parameter MCNTRL_TEST01_ADDR=                 'h0f0,
    parameter MCNTRL_TEST01_MASK=                 'h3f0,
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
    
// axi_hp_clk_i parameters
    parameter CLKFBOUT_MULT_AXIHP =                18,
    parameter CLKFBOUT_DIV_AXIHP =                 6,

// membridge module parameters    
    parameter MEMBRIDGE_ADDR=                     'h200,
    parameter MEMBRIDGE_MASK=                     'h3f0,
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
    parameter WSEL=                               1'b0  // late/early WRITE commands (to adjust timing by 1 SDCLK period)
    