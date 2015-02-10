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
  localparam LD_DLY_LANE0_ODELAY = DLY_LD+'h00; // 0x1080
  localparam LD_DLY_LANE0_IDELAY = DLY_LD+'h10; // 0x1090
  localparam LD_DLY_LANE1_ODELAY = DLY_LD+'h20; // 0x10a0
  localparam LD_DLY_LANE1_IDELAY = DLY_LD+'h30; // 0x10b0
  localparam LD_DLY_CMDA  =        DLY_LD+'h40; // 0x10c0
  localparam LD_DLY_PHASE =        DLY_LD+'h60; // 0x10e0
  localparam DLY_SET =             MCONTR_PHY_0BIT_ADDR + MCONTR_PHY_0BIT_DLY_SET; //0x1020

`ifdef use200Mhz
    localparam DLY_LANE0_DQS_WLV_IDELAY = 8'hb0; // idelay dqs
    localparam DLY_LANE1_DQS_WLV_IDELAY = 8'hb0; // idelay dqs
    localparam DLY_LANE0_ODELAY= 80'h4c4c4b4a494844434241; // odelay dqm, odelay ddqs, odelay dq[7:0]
    localparam DLY_LANE0_IDELAY= 72'ha0636261605c5b5a59; // idelay dqs, idelay dq[7:0
    localparam DLY_LANE1_ODELAY= 80'h4c4c4b4a494844434241; // odelay dqm, odelay ddqs, odelay dq[7:0]
    localparam DLY_LANE1_IDELAY= 72'ha0636261605c5b5a59; // idelay dqs, idelay dq[7:0
    localparam DLY_CMDA=  256'h3c3c3c3c3b3a39383434343433323130002c2c2c2b2a29282424242423222120; // odelay odt, cke, cas, ras, we, ba2,ba1,ba0, X, a14,..,a0
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
    localparam DLY_DQ_IDELAY =  'h70;
    localparam DLY_DQ_ODELAY =  'h68;
    localparam DLY_DQS_IDELAY = 'hd8;
    localparam DLY_DQS_ODELAY = 'h74; // b0 for WLV
    localparam DLY_DM_ODELAY =  'h74;
    localparam DLY_CMDA_ODELAY ='h50;


`endif   
    
    localparam DLY_PHASE= 8'h1c; // mmcm fine phase shift, 1/4 tCK
    
    localparam DQSTRI_FIRST=    4'h3; // DQS tri-state control word, first when enabling output 
    localparam DQSTRI_LAST=     4'hc; // DQS tri-state control word, first after disabling output
    localparam DQTRI_FIRST=     4'h7; // DQ tri-state control word, first when enabling output 
    localparam DQTRI_LAST=      4'he; // DQ tri-state control word, first after disabling output
    localparam WBUF_DLY_DFLT=   4'h6; // extra delay (in mclk cycles) to add to write buffer enable (DDR3 read data)
    localparam WBUF_DLY_WLV=    4'h7; // write leveling mode: extra delay (in mclk cycles) to add to write buffer enable (DDR3 read data)
    
//    localparam DLY_PHASE= 8'hdb; // mmcm fine phase shift
    localparam INITIALIZE_OFFSET=  'h00; // moemory initialization start address (in words) ..`h0c
    localparam REFRESH_OFFSET=     'h10; // refresh start address (in words) ..`h13
    localparam WRITELEV_OFFSET=    'h20; // write leveling start address (in words) ..`h2a
    
    localparam READ_PATTERN_OFFSET='h40; // read pattern to memory block sequence start address (in words) ..'h053 with 8x2*64 bits (variable)
    localparam WRITE_BLOCK_OFFSET= 'h100; // write block sequence start address (in words) ..'h14c
    localparam READ_BLOCK_OFFSET=  'h180; // read  block sequence start address (in words)
