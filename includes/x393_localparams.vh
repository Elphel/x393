// SuppressWarnings VEditor
    localparam BASEADDR_PORT0_RD = PORT0_RD_ADDR << 2; // 'h0000  << 2
// SuppressWarnings VEditor
    localparam BASEADDR_PORT1_WR = PORT1_WR_ADDR << 2; // 'h0000 << 2 = 'h000
    localparam BASEADDR_CMD0 =     CMD0_ADDR << 2;     // 'h0800 << 2 = 'h2000
//    localparam BASEADDR_CTRL =     CONTROL_ADDR << 2;
    localparam BASEADDR_CTRL =     (CONTROL_ADDR | BUSY_WR_ADDR) << 2; // with busy
    localparam BASEADDR_STATUS =   STATUS_ADDR << 2;   // 'h0800 << 2 = 'h2000
    localparam BASEADDR_DLY_LD =  BASEADDR_CTRL | (DLY_LD_REL <<2);  // 'h080, address to generate delay load
    localparam BASEADDR_DLY_SET = BASEADDR_CTRL | (DLY_SET_REL<<2);  // 'h070, address to generate delay set
    localparam BASEADDR_RUN_CHN = BASEADDR_CTRL | (RUN_CHN_REL<<2);  // 'h000, address to set sequnecer channel and  run (4 LSB-s - channel)

    localparam BASEADDR_PATTERNS =BASEADDR_CTRL | (PATTERNS_REL<<2); // 'h020, address to set DQM and DQS patterns (16'h0055)
    localparam BASEADDR_PATTERNS_TRI =BASEADDR_CTRL | (PATTERNS_TRI_REL<<2); // 'h021, address to set DQM and DQS tristate on/off patterns {dqs_off,dqs_on, dq_off,dq_on} - 4 bits each
    localparam BASEADDR_WBUF_DELAY =BASEADDR_CTRL | (WBUF_DELAY_REL<<2); // 'h022, extra delay (in mclk cycles) to add to write buffer enable (DDR3 read data)
// SuppressWarnings VEditor
    localparam BASEADDR_PAGES =   BASEADDR_CTRL | (PAGES_REL<<2);    // 'h023, address to set buffer pages {port1_page[1:0],port1_int_page[1:0],port0_page[1:0],port0_int_page[1:0]}
    localparam BASEADDR_CMDA_EN = BASEADDR_CTRL | (CMDA_EN_REL<<2);  // 'h024, address to enable('h825)/disable('h824) command/address outputs  
    localparam BASEADDR_SDRST_ACT = BASEADDR_CTRL | (SDRST_ACT_REL<<2); // 'h026 address to activate('h827)/deactivate('h826) active-low reset signal to DDR3 memory     
    localparam BASEADDR_CKE_EN =  BASEADDR_CTRL | (CKE_EN_REL<<2);   // 'h028
    
// SuppressWarnings VEditor
    localparam BASEADDR_DCI_RST =  BASEADDR_CTRL | (DCI_RST_REL<<2);   // 'h02a (+1 - enable)
// SuppressWarnings VEditor
    localparam BASEADDR_DLY_RST =  BASEADDR_CTRL | (DLY_RST_REL<<2);   // 'h02c (+1 - enable)
      
// SuppressWarnings VEditor
    localparam BASEADDR_EXTRA =   BASEADDR_CTRL | (EXTRA_REL<<2);    // 'h02e, address to set extra parameters (currently just inv_clk_div)
    
    localparam BASEADDR_REFRESH_EN =   BASEADDR_CTRL | (REFRESH_EN_REL<<2);    // address to enable('h31) and disable ('h30) DDR refresh
    localparam BASEADDR_REFRESH_PER =   BASEADDR_CTRL | (REFRESH_PER_REL<<2);    // address ('h32) to set refresh period in 32 x tCK
    localparam BASEADDR_REFRESH_ADDR =   BASEADDR_CTRL | (REFRESH_ADDR_REL<<2);    // address ('h33)to set sequencer start address for DDR refresh
    
    
    localparam BASEADDRESS_LANE0_ODELAY = BASEADDR_DLY_LD;  
    localparam BASEADDRESS_LANE0_IDELAY = BASEADDR_DLY_LD+('h10<<2);  
    localparam BASEADDRESS_LANE1_ODELAY = BASEADDR_DLY_LD+('h20<<2);  
    localparam BASEADDRESS_LANE1_IDELAY = BASEADDR_DLY_LD+('h30<<2);  

    localparam BASEADDRESS_CMDA  = BASEADDR_DLY_LD+('h40<<2);
    localparam BASEADDRESS_PHASE = BASEADDR_DLY_LD+('h60<<2);
    localparam STATUS_PSHIFTER_RDY_MASK = 'h100;
// SuppressWarnings VEditor - not yet used
    localparam STATUS_LOCKED_MASK = 'h200;
    localparam STATUS_SEQ_BUSY_MASK = 'h400;

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
