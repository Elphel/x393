/*******************************************************************************
 * File: x393_localparams.vh
 * Date:2015-02-07  
 * Author: andrey     
 * Description: Local parameters for simulation of the x393
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
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
// different sets of settings for the functional simulation and the actual hardware
/*
if use200Mhz:
    DLY_LANE0_DQS_WLV_IDELAY = 0xb0 # idelay dqs
    DLY_LANE1_DQS_WLV_IDELAY = 0xb0 # idelay dqs
    DLY_LANE0_ODELAY= [0x98,0x4c,0x94,0x94,0x98,0x9c,0x92,0x99,0x98,0x94] # odelay dqm, odelay ddqs, odelay dq[7:0]
    
    DLY_LANE0_IDELAY=      [0x40,0x13,0x14,0x14,0x1c,0x13,0x14,0x13,0x1a] # idelay dqs, idelay dq[7:0
    DLY_LANE1_ODELAY= [0x98,0x4c,0x98,0x98,0x98,0x9b,0x99,0xa8,0x9c,0x98] # odelay dqm, odelay ddqs, odelay dq[7:0]
    
    DLY_LANE1_IDELAY=      [0x40,0x2c,0x2b,0x2c,0x2c,0x34,0x30,0x33,0x30] # idelay dqs, idelay dq[7:0
    DLY_CMDA=  [0x3c,0x3c,0x3c,0x3c,0x3b,0x3a,0x39,0x38,0x34,0x34,0x34,0x34,0x33,0x32,0x31,0x30,
                0x00,0x2c,0x2c,0x2c,0x2b,0x2a,0x29,0x28,0x24,0x24,0x24,0x24,0x23,0x22,0x21,0x20] # odelay odt, cke, cas, ras, we, ba2,ba1,ba0, X, a14,..,a0

# alternative to set same type delays to the same value    
    DLY_DQ_IDELAY =  0x20
    DLY_DQ_ODELAY =  0xa0
    DLY_DQS_IDELAY = 0x40
    DLY_DQS_ODELAY = 0x4c #should match with phase write leveling
    DLY_DM_ODELAY =  0xa0
    DLY_CMDA_ODELAY =0x50
    
else:   
    DLY_LANE0_DQS_WLV_IDELAY = 0xe8 # idelay dqs
    DLY_LANE1_DQS_WLV_IDELAY = 0xe8 # idelay dqs
    DLY_LANE0_ODELAY= [0x74,0x74,0x73,0x72,0x71,0x70,0x6c,0x6b,0x6a,0x69] # odelay dqm, odelay ddqs, odelay dq[7:0]
    DLY_LANE0_IDELAY=      [0xd8,0x73,0x72,0x71,0x70,0x6c,0x6b,0x6a,0x69] # idelay dqs, idelay dq[7:0
    DLY_LANE1_ODELAY= [0x74,0x74,0x73,0x72,0x71,0x70,0x6c,0x6b,0x6a,0x69] # odelay dqm, odelay ddqs, odelay dq[7:0]
    DLY_LANE1_IDELAY=      [0xd8,0x73,0x72,0x71,0x70,0x6c,0x6b,0x6a,0x69] # idelay dqs, idelay dq[7:0
    DLY_CMDA=  [0x5c,0x5c,0x5c,0x5c,0x5b,0x5a,0x59,0x58,0x54,0x54,0x54,0x54,0x53,0x52,0x51,0x50,
                0x00,0x4c,0x4c,0x4c,0x4b,0x4a,0x49,0x48,0x44,0x44,0x44,0x44,0x43,0x42,0x41,0x40] # odelay odt, cke, cas, ras, we, ba2,ba1,ba0, X, a14,..,a0
# alternative to set same type delays to the same value    
    DLY_DQ_IDELAY =  0x20
    DLY_DQ_ODELAY =  0xa0
    DLY_DQS_IDELAY = 0x40
    DLY_DQS_ODELAY = 0x4c #should match with phase write leveling
    DLY_DM_ODELAY =  0xa0
    DLY_CMDA_ODELAY =0x50


NUM_FINE_STEPS=    5
#`endif   
    
DLY_PHASE=       0x2c # 0x1c # mmcm fine phase shift, 1/4 tCK

*/  
`ifdef TARGET_MODE
    localparam T_RFC=50;  // t_rfc=50 for tCK=2.5ns
    localparam T_REFI=48; // t_refi; # 48/97 for normal, 8 - for simulation (7.8us <85C, 3.9us >85C)
  `ifdef use200Mhz
    localparam DLY_LANE0_DQS_WLV_IDELAY = 8'hb0; // idelay dqs
    localparam DLY_LANE1_DQS_WLV_IDELAY = 8'hb0; // idelay dqs
    localparam DLY_LANE0_ODELAY= 80'h984c9494989c92999894; // odelay dqm, odelay ddqs, odelay dq[7:0]
    localparam DLY_LANE0_IDELAY= 72'h401314141c1314131a; // idelay dqs, idelay dq[7:0
    localparam DLY_LANE1_ODELAY= 80'h984c9898989b99a89c98; // odelay dqm, odelay ddqs, odelay dq[7:0]
    localparam DLY_LANE1_IDELAY= 72'h402c2b2c2c34303330;   // idelay dqs, idelay dq[7:0
    localparam DLY_CMDA= 256'h3c3c3c3c3b3a39383434343433323130002c2c2c2b2a29282424242423222120; // odelay odt, cke, cas, ras, we, ba2,ba1,ba0, X, a14,..,a0
// alternative to set same type delays to the same value    
    localparam DLY_DQ_IDELAY =  'h20 ;// 'h60;
    localparam DLY_DQ_ODELAY =  'ha0; // 'h48;
    localparam DLY_DQS_IDELAY = 'h40; // 'ha0;
    localparam DLY_DQS_ODELAY = 'h4c; // 
    localparam DLY_DM_ODELAY =  'ha0; // 'h48;
    localparam DLY_CMDA_ODELAY ='h50; // 'h30;
  `else   
    localparam DLY_LANE0_DQS_WLV_IDELAY = 8'he8; // idelay dqs
    localparam DLY_LANE1_DQS_WLV_IDELAY = 8'he8; // idelay dqs
    localparam DLY_LANE0_ODELAY= 80'h7474737271706c6b6a69; // odelay dqm, odelay ddqs, odelay dq[7:0]
    localparam DLY_LANE0_IDELAY= 72'hd8737271706c6b6a69; // idelay dqs, idelay dq[7:0
    localparam DLY_LANE1_ODELAY= 80'h7474737271706c6b6a69; // odelay dqm, odelay ddqs, odelay dq[7:0]
    localparam DLY_LANE1_IDELAY= 72'hd8737271706c6b6a69; // idelay dqs, idelay dq[7:0
    localparam DLY_CMDA=  256'h5c5c5c5c5b5a59585454545453525150004c4c4c4b4a49484444444443424140; // odelay odt, cke, cas, ras, we, ba2,ba1,ba0, X, a14,..,a0
// alternative to set same type delays to the same value    
/*  localparam DLY_DQ_IDELAY =  'h70;
    localparam DLY_DQ_ODELAY =  'h68;
    localparam DLY_DQS_IDELAY = 'hd8;
    localparam DLY_DQS_ODELAY = 'h74; // b0 for WLV
    localparam DLY_DM_ODELAY =  'h74;
    localparam DLY_CMDA_ODELAY ='h50; */
    localparam DLY_DQ_IDELAY =  'h20 ;// 'h60;
    localparam DLY_DQ_ODELAY =  'ha0; // 'h48;
    localparam DLY_DQS_IDELAY = 'h40; // 'ha0;
    localparam DLY_DQS_ODELAY = 'h4c; // 
    localparam DLY_DM_ODELAY =  'ha0; // 'h48;
    localparam DLY_CMDA_ODELAY ='h50; // 'h30;
  `endif   
    localparam DLY_PHASE= 8'h1c; // mmcm fine phase shift, 1/4 tCK
`else
    localparam T_RFC=50;  // t_rfc=50 for tCK=2.5ns
    localparam T_REFI=16; // t_refi; # 48/97 for normal, 8 - for simulation (7.8us <85C, 3.9us >85C)
  `ifdef use200Mhz
    localparam DLY_LANE0_DQS_WLV_IDELAY = 8'hb0; // idelay dqs
    localparam DLY_LANE1_DQS_WLV_IDELAY = 8'hb0; // idelay dqs
    localparam DLY_LANE0_ODELAY= 80'h4c784b4a494844434241; // odelay dqm, odelay ddqs, odelay dq[7:0]
    localparam DLY_LANE0_IDELAY= 72'ha0636261605c5b5a59; // idelay dqs, idelay dq[7:0
    localparam DLY_LANE1_ODELAY= 80'h4c784b4a494844434241; // odelay dqm, odelay ddqs, odelay dq[7:0]
    localparam DLY_LANE1_IDELAY= 72'ha0636261605c5b5a59; // idelay dqs, idelay dq[7:0
    localparam DLY_CMDA=  256'h3c3c3c3c3b3a39383434343433323130002c2c2c2b2a29282424242423222120; // odelay odt, cke, cas, ras, we, ba2,ba1,ba0, X, a14,..,a0
// alternative to set same type delays to the same value    
    localparam DLY_DQ_IDELAY =  'h20 ;// 'h60;
    localparam DLY_DQ_ODELAY =  'ha0; // 'h48;
    localparam DLY_DQS_IDELAY = 'h40; // 'ha0;
    localparam DLY_DQS_ODELAY = 'h78; // 
    localparam DLY_DM_ODELAY =  'ha0; // 'h48;
    localparam DLY_CMDA_ODELAY ='h50; // 'h30;
  `else   
    localparam DLY_LANE0_DQS_WLV_IDELAY = 8'he8; // idelay dqs
    localparam DLY_LANE1_DQS_WLV_IDELAY = 8'he8; // idelay dqs
    localparam DLY_LANE0_ODELAY= 80'h7474737271706c6b6a69; // odelay dqm, odelay ddqs, odelay dq[7:0]
    localparam DLY_LANE0_IDELAY= 72'hd8737271706c6b6a69; // idelay dqs, idelay dq[7:0
    localparam DLY_LANE1_ODELAY= 80'h7474737271706c6b6a69; // odelay dqm, odelay ddqs, odelay dq[7:0]
    localparam DLY_LANE1_IDELAY= 72'hd8737271706c6b6a69; // idelay dqs, idelay dq[7:0
    localparam DLY_CMDA=  256'h5c5c5c5c5b5a59585454545453525150004c4c4c4b4a49484444444443424140; // odelay odt, cke, cas, ras, we, ba2,ba1,ba0, X, a14,..,a0
// alternative to set same type delays to the same value    
    localparam DLY_DQ_IDELAY =  'h70;
    localparam DLY_DQ_ODELAY =  'h68;
    localparam DLY_DQS_IDELAY = 'hd8;
    localparam DLY_DQS_ODELAY = 'h74; // b0 for WLV
    localparam DLY_DM_ODELAY =  'h74;
    localparam DLY_CMDA_ODELAY ='h50;
  `endif
    localparam DLY_PHASE= 8'h1c; // mmcm fine phase shift, 1/4 tCK
`endif
    
    localparam DQSTRI_FIRST=    4'h3; // DQS tri-state control word, first when enabling output 
    localparam DQSTRI_LAST=     4'hc; // DQS tri-state control word, first after disabling output
    localparam DQTRI_FIRST=     4'h7; // DQ tri-state control word, first when enabling output 
    localparam DQTRI_LAST=      4'he; // DQ tri-state control word, first after disabling output
    localparam WBUF_DLY_DFLT=   DFLT_WBUF_DELAY; //4'h8; // 4'h6; // extra delay (in mclk cycles) to add to write buffer enable (DDR3 read data)
    localparam WBUF_DLY_WLV=    4'h7; // write leveling mode: extra delay (in mclk cycles) to add to write buffer enable (DDR3 read data)
    
//    localparam DLY_PHASE= 8'hdb; // mmcm fine phase shift
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