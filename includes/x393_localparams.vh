/*******************************************************************************
 * File: x393_localparams.vh
 * Date:2015-02-07  
 * Author: Andrey Filippov     
 * Description: Local parameters for simulation of the x393
 *
 * Copyright (c) 2015 Elphel, Inc.
 * x393_localparams.vh is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * x393_localparams.vh is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
// S uppressWarnings VEditor
  localparam [1:0] DEFAULT_STATUS_MODE = 3; // auto status on change, increase sequence number
  localparam LD_DLY_LANE0_ODELAY = DLY_LD+'h00; // 0x1080
  localparam LD_DLY_LANE0_IDELAY = DLY_LD+'h10; // 0x1090
  localparam LD_DLY_LANE1_ODELAY = DLY_LD+'h20; // 0x10a0
  localparam LD_DLY_LANE1_IDELAY = DLY_LD+'h30; // 0x10b0
  localparam LD_DLY_CMDA  =        DLY_LD+'h40; // 0x10c0
  localparam LD_DLY_PHASE =        DLY_LD+'h60; // 0x10e0
  localparam DLY_SET =             MCONTR_PHY_0BIT_ADDR + MCONTR_PHY_0BIT_DLY_SET; //0x1020
// different sets of settings for the functional simulation and the actual hardware - should not be needed anymore
  localparam T_RFC=50;  // t_rfc=50 for tCK=2.5ns
  localparam T_REFI=48; // t_refi; # 48/97 for normal, 8 - for simulation (7.8us <85C, 3.9us >85C)
    
// alternative to set same type delays to the same value
    localparam DLY_DQ_IDELAY =  ( (DLY_LANE0_IDELAY      & 8'hff)+
                                 ((DLY_LANE0_IDELAY>> 8) & 8'hff)+
                                 ((DLY_LANE0_IDELAY>>16) & 8'hff)+
                                 ((DLY_LANE0_IDELAY>>24) & 8'hff)+      
                                 ((DLY_LANE0_IDELAY>>32) & 8'hff)+      
                                 ((DLY_LANE0_IDELAY>>40) & 8'hff)+      
                                 ((DLY_LANE0_IDELAY>>48) & 8'hff)+      
                                 ((DLY_LANE0_IDELAY>>56) & 8'hff)+
                                  (DLY_LANE1_IDELAY      & 8'hff)+
                                 ((DLY_LANE1_IDELAY>> 8) & 8'hff)+
                                 ((DLY_LANE1_IDELAY>>16) & 8'hff)+
                                 ((DLY_LANE1_IDELAY>>24) & 8'hff)+      
                                 ((DLY_LANE1_IDELAY>>32) & 8'hff)+      
                                 ((DLY_LANE1_IDELAY>>40) & 8'hff)+      
                                 ((DLY_LANE1_IDELAY>>48) & 8'hff)+      
                                 ((DLY_LANE1_IDELAY>>56) & 8'hff)+  8 ) >> 4;      
    localparam  DLY_DQ_ODELAY =  (((DLY_LANE0_ODELAY      & 8'hff)+
                                 ((DLY_LANE0_ODELAY>> 8) & 8'hff)+
                                 ((DLY_LANE0_ODELAY>>16) & 8'hff)+
                                 ((DLY_LANE0_ODELAY>>24) & 8'hff)+      
                                 ((DLY_LANE0_ODELAY>>32) & 8'hff)+      
                                 ((DLY_LANE0_ODELAY>>40) & 8'hff)+      
                                 ((DLY_LANE0_ODELAY>>48) & 8'hff)+      
                                 ((DLY_LANE0_ODELAY>>56) & 8'hff)+
                                  (DLY_LANE1_ODELAY      & 8'hff)+
                                 ((DLY_LANE1_ODELAY>> 8) & 8'hff)+
                                 ((DLY_LANE1_ODELAY>>16) & 8'hff)+
                                 ((DLY_LANE1_ODELAY>>24) & 8'hff)+      
                                 ((DLY_LANE1_ODELAY>>32) & 8'hff)+      
                                 ((DLY_LANE1_ODELAY>>40) & 8'hff)+      
                                 ((DLY_LANE1_ODELAY>>48) & 8'hff)+      
                                 ((DLY_LANE1_ODELAY>>56) & 8'hff)+  8 ) >> 4);
    
    localparam DLY_DQS_IDELAY =  (((DLY_LANE0_IDELAY>>64) & 8'hff)+
                                  ((DLY_LANE1_IDELAY>>64) & 8'hff)+  1 ) >> 1;
    localparam DLY_DQS_ODELAY =  (((DLY_LANE0_ODELAY>>64) & 8'hff)+
                                  ((DLY_LANE1_ODELAY>>64) & 8'hff)+  1 ) >> 1;
    localparam DLY_DM_ODELAY =  DLY_DQ_ODELAY;
    localparam DLY_CMDA_ODELAY =(((DLY_CMDA>>   0)  & 8'hff)+
                                 ((DLY_CMDA>>   8) & 8'hff)+
                                 ((DLY_CMDA>>'h10) & 8'hff)+
                                 ((DLY_CMDA>>'h18) & 8'hff)+      
                                 ((DLY_CMDA>>'h20) & 8'hff)+      
                                 ((DLY_CMDA>>'h28) & 8'hff)+      
                                 ((DLY_CMDA>>'h30) & 8'hff)+      
                                 ((DLY_CMDA>>'h38) & 8'hff)+
                                 ((DLY_CMDA>>'h40) & 8'hff)+
                                 ((DLY_CMDA>>'h48) & 8'hff)+      
                                 ((DLY_CMDA>>'h50) & 8'hff)+      
                                 ((DLY_CMDA>>'h58) & 8'hff)+      
                                 ((DLY_CMDA>>'h60) & 8'hff)+      
                                 ((DLY_CMDA>>'h68) & 8'hff)+
                                 ((DLY_CMDA>>'h70) & 8'hff)+
                                 ((DLY_CMDA>>'hc0) & 8'hff)+
                                 ((DLY_CMDA>>'hc8) & 8'hff)+      
                                 ((DLY_CMDA>>'hd0) & 8'hff)+
                                 ((DLY_CMDA>>'hd8) & 8'hff)+      
                                 ((DLY_CMDA>>'he0) & 8'hff)+
                                 ((DLY_CMDA>>'he8) & 8'hff)+      
                                 ((DLY_CMDA>>'hf0) & 8'hff)+
                                 ((DLY_CMDA>>'hf8) & 8'hff)+  12 ) / 23;
    localparam DLY_LANE0_DQS_WLV_IDELAY = DLY_DQS_IDELAY; // b0; // idelay dqs
    localparam DLY_LANE1_DQS_WLV_IDELAY = DLY_DQS_IDELAY; // b0; idelay dqs
                                 
    localparam DQSTRI_FIRST=    4'h1; // 3; // DQS tri-state control word, first when enabling output 
    localparam DQSTRI_LAST=     4'hc; // DQS tri-state control word, first after disabling output
    localparam DQTRI_FIRST=     4'h3; // 7; // DQ tri-state control word, first when enabling output 
    localparam DQTRI_LAST=      4'he; // DQ tri-state control word, first after disabling output
    localparam WBUF_DLY_DFLT=   DFLT_WBUF_DELAY; // 4'h8; // 4'h6; // extra delay (in mclk cycles) to add to write buffer enable (DDR3 read data)
    localparam WBUF_DLY_WLV=    DFLT_WBUF_DELAY; // 4'h7; // write leveling mode: extra delay (in mclk cycles) to add to write buffer enable (DDR3 read data)
    
    localparam INITIALIZE_OFFSET=  'h00; // moemory initialization start address (in words) ..`h0c
    localparam REFRESH_OFFSET=     'h10; // refresh start address (in words) ..`h13
    localparam WRITELEV_OFFSET=    'h20; // write leveling start address (in words) ..`h2a
    
    localparam READ_PATTERN_OFFSET='h40; // read pattern to memory block sequence start address (in words) ..'h053 with 8x2*64 bits (variable)
    localparam WRITE_BLOCK_OFFSET= 'h100; // write block sequence start address (in words) ..'h14c
    localparam READ_BLOCK_OFFSET=  'h180; // read  block sequence start address (in words)

    localparam STATUS_SEQ_SHFT=           26; // bits [31:26] is the sequence number
    localparam STATUS_2LSB_SHFT=          24; // bits [25:24] get the 2 LSB of the status (transmitted with the sequence number in the second byte)
    localparam STATUS_MSB_RSHFT=           2; // status bits [25:2] are read through [23:0]
    
    localparam STATUS_PSHIFTER_RDY_MASK = 1<<STATUS_2LSB_SHFT;
    localparam FRAME_START_ADDRESS=      'h1000; // RA=80, CA=0, BA=0 22-bit frame start address (3 CA LSBs==0. BA==0)
    localparam FRAME_START_ADDRESS_INC=  'h800;
    localparam LAST_BUF_FRAME =           1;
    localparam CAMSYNC_DELAY =            200;  
    
    
    localparam       FRAME_FULL_WIDTH=    'h0c0;  // Padded line length (8-row increment), in 8-bursts (16 bytes)
  
//  localparam       AFI_LO_ADDR64=       'h4000; // start of the system memory range in 64-bit words
//  localparam       AFI_SIZE64=          'h4000; // size of system memory range in 64-bit words

// Same as in the actual hardware
  localparam       AFI_LO_ADDR64=       'h4f20000; // start of the system memory range in 64-bit words
  localparam       AFI_SIZE64=          'h0c80000; // size of system memory range in 64-bit words
  
  
//  localparam SCANLINE_WINDOW_WH=  `h079000a2;  // 2592*1936: low word - 13-bit window width (0->'h4000), high word - 16-bit frame height (0->'h10000)
//  localparam       SCANLINE_WINDOW_WH=  'h0009000b;  // 176*9: low word - 13-bit window width (0->'h4000), high word - 16-bit frame height (0->'h10000)
  localparam       WINDOW_WIDTH=    'h000b; //'h005b; //'h000b;  // 176:  13-bit window width (0->'h4000)
  localparam       WINDOW_HEIGHT=   'h000a;  // 9:    16-bit window height (0->'h10000)
//  localparam       SCANLINE_X0Y0=       'h00050003;  // X0=3*16=48, Y0=5: // low word - 13-bit window left, high word - 16-bit window top
  localparam       WINDOW_X0=     'h5c; //'h7f; //     'h005c; // 'h7c; // 'h0003;  // X0=3*16=48 - 13-bit window left
  localparam       WINDOW_Y0=         'h0005;  // Y0=5: 16-bit window top
//  localparam       SCANLINE_STARTXY=    'h0;         // low word - 13-bit start X (relative to window), high word - 16-bit start y (normally 0)
  localparam       SCANLINE_STARTX=     'h0;         // 13-bit start X (relative to window), high word (normally 0)
  localparam       SCANLINE_STARTY=     'h0;         // 16-bit start y (normally 0)
  localparam [1:0] SCANLINE_EXTRA_PAGES= 0;          // 0..2 - number of pages in the buffer to keep/not write // SuppressThisWarning VEditor - not used
  
  localparam       TILED_STARTX=     'h0;         // 13-bit start X (relative to window), high word (normally 0)
  localparam       TILED_STARTY=     'h0;         // 16-bit start y (normally 0)
  localparam [1:0] TILED_EXTRA_PAGES= 0;          // 0..2 - number of pages in the buffer to keep/not write
  
  localparam       TILED_KEEP_OPEN=   1'b1; //1'b1; // 1'b0;       // Do not close banks between reads (valid only for tiles <=8 rows, needed if less than 3? rows)  
  
  localparam       TILE_WIDTH=    'h04; //     6-bit tile width  (1..'h40)
  localparam       TILE_HEIGHT=   'h08; //'h05; // 'h04; //'h06;  //    6-bit tile height (1..'h40) // 4 - violation
  localparam       TILE_VSTEP=    'h04;  //    6-bit tile vertical step, with no overlap it is equal to TILE_HEIGHT (1..'h40)
  
  
  localparam       TEST01_START_FRAME=   1;         
  localparam       TEST01_NEXT_PAGE=     2;         
  localparam       TEST01_SUSPEND=       4; // SuppressThisWarning VEditor - not used
  
  localparam       TEST_INITIAL_BURST=   4; // 3;
  
    