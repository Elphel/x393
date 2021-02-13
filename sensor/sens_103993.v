/*!
 * <b>Module:</b>sens_103993
 * @file sens_103993.v
 * @date 2015-10-15  
 * @author Andrey Filippov     
 *
 * @brief Top level module for the 10398 SFE (with MT9F002 sensor)
 *
 * @copyright Copyright (c) 2020 Elphel, Inc .
 *
 * <b>License:</b>
 *
 * sens_103993.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  sens_103993.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *
 * Additional permission under GNU GPL version 3 section 7:
 * If you modify this Program, or any covered work, by linking or combining it
 * with independent modules provided by the FPGA vendor only (this permission
 * does not extend to any 3-rd party modules, "soft cores" or macros) under
 * different license terms solely for the purpose of generating binary "bitstream"
 * files and/or simulating the code, the copyright holders of this Program give
 * you the right to distribute the covered work without those independent modules
 * as long as the source code for them is available from the FPGA vendor free of
 * charge, and there is no dependence on any encrypted modules for simulating of
 * the combined code. This permission applies to you if the distributed code
 * contains all the components and scripts required to completely simulate it
 * with at least one of the Free Software programs.
 */
`timescale 1ns/1ps

module  sens_103993 #(
    parameter SENSIO_ADDR =        'h330,
    parameter SENSIO_ADDR_MASK =   'h7f8,
    parameter SENSIO_CTRL =        'h0,
    parameter SENSIO_STATUS =      'h1,
///    parameter SENSIO_JTAG =        'h2,
///    parameter SENSIO_WIDTH =       'h3, // HERE - number of lines to skip  
    parameter SENSIO_DELAYS =      'h4, // 'h4..'h7 - each address sets 4 delays through 4 bytes of 32-bit data
// 5, swap lanes 6 - delays, 7 - phase
    parameter SENSIO_STATUS_REG =  'h21,
    
///    parameter SENS_JTAG_PGMEN =    8,
///    parameter SENS_JTAG_PROG =     6,
///    parameter SENS_JTAG_TCK =      4,
///    parameter SENS_JTAG_TMS =      2,
///    parameter SENS_JTAG_TDI =      0,
    
    parameter SENS_CTRL_MRST=      0,  //  1: 0
///    parameter SENS_CTRL_ARST=      2,  //  3: 2
///    parameter SENS_CTRL_ARO=       4,  //  5: 4
    parameter SENS_CTRL_RST_MMCM=  6,  //  7: 6
//    parameter SENS_CTRL_EXT_CLK=   8,  //  9: 8
///    parameter SENS_CTRL_IGNORE_EMBED =   8,  //  9: 8
    parameter SENS_CTRL_LD_DLY=   10,  // 10

//    parameter SENS_CTRL_GP0=      12,  // 13:12
//    parameter SENS_CTRL_GP1=      14,  // 15:14
    parameter SENS_CTRL_GP0=               12,  // 14:12 00 - float, 01 - low, 10 - high, 11 - trigger
    parameter SENS_CTRL_GP1=               15,  // 17:15 00 - float, 01 - low, 10 - high, 11 - trigger
    parameter SENS_CTRL_GP2=               18,  // 20:18 00 - float, 01 - low, 10 - high, 11 - trigger
    parameter SENS_CTRL_GP3=               21,  // 23:21 00 - float, 01 - low, 10 - high, 11 - trigger

    parameter SENS_UART_EXTIF_EN =          0,  //  1: 0
    parameter SENS_UART_XMIT_RST =          2,  //  3: 2
    parameter SENS_UART_RECV_RST =          4,  //  5: 4
    parameter SENS_UART_XMIT_START =        6,  //  6
    parameter SENS_UART_RECV_NEXT =         7,  //  7

    parameter SENS_ALT_STATUS =            24,
    parameter SENS_ALT_STATUS_SET =        25,
    parameter SENS_TEST_MODES =            26,
    parameter SENS_TEST_BITS =              3,
    parameter SENS_TEST_SET=               29,
    parameter SENS_TEST_WIDTH_BITS =       10,
    parameter SENS_TEST_HEIGHT_BITS =      10,
    parameter SENS_TEST_WIDTH_INC =         3,
    parameter SENS_TEST_HEIGHT_INC =        3,

//    parameter SENS_CTRL_QUADRANTS =      12,  // 17:12, enable - 20
//    parameter SENS_CTRL_QUADRANTS_WIDTH = 6,
//    parameter SENS_CTRL_QUADRANTS_EN =   20,  // 17:12, enable - 20 (2 bits reserved)
    parameter IODELAY_GRP =               "IODELAY_SENSOR",
    parameter integer IDELAY_VALUE =       0,
    parameter real REFCLK_FREQUENCY =      200.0,
    parameter HIGH_PERFORMANCE_MODE =     "FALSE",
    parameter SENS_PHASE_WIDTH=            8,      // number of bits for te phase counter (depends on divisors)
//    parameter SENS_PCLK_PERIOD =           3.000,  // input period in ns, 0..100.000 - MANDATORY, resolution down to 1 ps
    parameter SENS_BANDWIDTH =             "OPTIMIZED",  //"OPTIMIZED", "HIGH","LOW"

    parameter CLKIN_PERIOD_SENSOR =        37.037, // input period in ns, 0..100.000 - MANDATORY, resolution down to 1 ps
    parameter CLKFBOUT_MULT_SENSOR =       30,      // 27 MHz --> 810 MHz (3*270MHz)
    parameter CLKFBOUT_PHASE_SENSOR =      0.000,  // CLOCK FEEDBACK phase in degrees (3 significant digits, -360.000...+360.000)
    parameter PCLK_PHASE =                 0.000,
    parameter IPCLK2X_PHASE =              0.000,
    parameter BUF_PCLK =                  "BUFR",  
    parameter BUF_IPCLK2X =               "BUFR",  

    parameter SENS_DIVCLK_DIVIDE =         1,            // Integer 1..106. Divides all outputs with respect to CLKIN
    parameter SENS_REF_JITTER1   =         0.010,        // Expected jitter on CLKIN1 (0.000..0.999)
    parameter SENS_REF_JITTER2   =         0.010,
    parameter SENS_SS_EN         =        "FALSE",      // Enables Spread Spectrum mode
    parameter SENS_SS_MODE       =        "CENTER_HIGH",//"CENTER_HIGH","CENTER_LOW","DOWN_HIGH","DOWN_LOW"
    parameter SENS_SS_MOD_PERIOD =         10000,        // integer 4000-40000 - SS modulation period in ns

//    parameter LVDS_MSB_FIRST =            0,
    parameter NUMLANES =                   3,
    parameter LVDS_DELAY_CLK =           "FALSE",      
    parameter LVDS_MMCM =                "TRUE",
    parameter LVDS_CAPACITANCE =         "DONT_CARE",
    parameter LVDS_DIFF_TERM =           "TRUE",
    parameter LVDS_UNTUNED_SPLIT =       "FALSE", // Very power-hungry
    parameter LVDS_DQS_BIAS =            "TRUE",
    parameter LVDS_IBUF_DELAY_VALUE =    "0",
    parameter LVDS_IBUF_LOW_PWR =        "TRUE",
    parameter LVDS_IFD_DELAY_VALUE =     "AUTO",
    parameter LVDS_IOSTANDARD =          "DIFF_SSTL18_I", //"DIFF_SSTL18_II" for high current (13.4mA vs 8mA)
    
    // Other (non-HiSPi) sensor I/Os
    parameter integer PXD_DRIVE =         12,
    parameter PXD_IBUF_LOW_PWR =         "TRUE",
    parameter PXD_IOSTANDARD =           "LVCMOS18", // 1.8V single-ended
    parameter PXD_SLEW =                 "SLOW",
    parameter PXD_CAPACITANCE =          "DONT_CARE",
    parameter START_FRAME_BYTE  =         'h8E,
    parameter END_FRAME_BYTE  =           'hAE,
    parameter ESCAPE_BYTE =               'h9E,
    parameter REPLACED_START_FRAME_BYTE = 'h81,
    parameter REPLACED_END_FRAME_BYTE =   'hA1,
    parameter REPLACED_ESCAPE_BYTE =      'h91,
    parameter INITIAL_CRC16 =           16'h1d0f,
    parameter CLK_DIV =                   217,
    parameter RX_DEBOUNCE =                60,
    parameter UART_STOP_BITS =              1,
    parameter EXTIF_MODE =                  1 // 1,2 or 3 if there are several different extif
)(
    output                     pclk,        // global clock input, pixel rate (220MHz for MT9F002)
    output                     locked_pclk,
    input                      prst,
    output                     prsts,  // @pclk - includes sensor reset and sensor PLL reset
    // delay control inputs
    input                      mclk,
    input                      mrst,
    input                [7:0] cmd_ad,       // byte-serial command address/data (up to 6 bytes: AL-AH-D0-D1-D2-D3 
    input                      cmd_stb,      // strobe (with first byte) for the command a/d
    output               [7:0] status_ad,    // status address/data - up to 5 bytes: A - {seq,status[1:0]} - status[2:9] - status[10:17] - status[18:25]
    output                     status_rq,    // input request to send status downstream
    input                      status_start, // Acknowledge of the first status packet byte (address)
    
//    input                      trigger_mode, // running in triggered mode (0 - free running mode)
    input                      ext_sync, // trig,      // per-sensor trigger input
    
    // I/O pads
    input                [3:0] sns_dp, // NUMLANES-1, use all with dummy for IOSTANDARD (otherwise uses default that does not match bank)
    input                [3:0] sns_dn, // NUMLANES-1, use all with dummy for IOSTANDARD (otherwise uses default that does not match bank)
    input                      sns_clkp,
    input                      sns_clkn,

    inout                      sns_gp2, // sns1_dn[6] just to reduce EMI from the clock == gp[2]
    inout                      sns_pgm,        // (pullup)            SENSPGM 
    output                     sns_ext_sync,   // (TCK)
    output                     sns_mrst,       // sns_dp[7]
    inout                      sns_gp3,        // sns_dn[7] == gp[3]  TMS
    inout                      sns_gp0,        // sns_dp[5] == gp[0]  TDI   (differs from 10353)
    inout                      sns_gp1,        // sns_dn[5] == gp[1]

    inout                      sns_dp6,        // unused, just to select IOstandard

    output                     sns_txd,  // flash_tdo,   // sns_dp[4]           TDO  (differs from 10353)
    input                      sns_rxd, // shutter_done,// sns_dn[4]           DONE (differs from 10353)

    output              [15:0] pxd,
    output                     vsync,
    output                     hsync, // @pclk
    output                     dvalid, // @pclk
    // sequencer interface now always 5 bytes form the sequencer! (no need for extif_last - remove)
    // interface for uart in write-only mode for short commands
    // 1-st byte - SA (use 2 LSB to select 0,1,2 data bytes
    // 2-nd byte module
    // 3-rd byte function
    // 4 (optional) data[15:8] or data[7:0] if last
    // 5 (optional) data[7:0] 
    input                        extif_dav,  // data byte available for external interface 
    input                  [1:0] extif_sel,  // interface type (0 - internal, 1 - uart, 2,3 - reserved)
    input                  [7:0] extif_byte, // data to external interface (first - extif_sa)
    output                       extif_ready, // acknowledges extif_dav
    input                        extif_rst
);
/*
    localparam               SENS_ALT_STATUS =        24;
    localparam               SENS_ALT_STATUS_SET =    25;
    localparam               SENS_TEST_MODES =        26;
    localparam               SENS_TEST_BITS =          3;
    localparam               SENS_TEST_SET=           29;
    localparam               SENS_TEST_WIDTH_BITS =   10;
    localparam               SENS_TEST_HEIGHT_BITS =  10;
    localparam               SENS_TEST_WIDTH_INC =     3;
    localparam               SENS_TEST_HEIGHT_INC =    3;
*/    
    

    wire                            dvalid_w;
    wire                     [15:0] pxd_w;
    wire                     [15:0] pxd_test;
    reg  [SENS_TEST_WIDTH_BITS-1:0] col_num_test;         
    reg [SENS_TEST_HEIGHT_BITS-1:0] row_num_test;
    reg                       [7:0] col_num8_test;         
    reg                       [7:0] row_num8_test;
    reg                       [3:0] col_div_test;        
    reg                       [3:0] row_div_test;        
    reg                             dvalid_r;
    reg                      [31:0] data_r; 
    reg                             set_uart_ctrl; // set UART control bits (both TX and receive)
    reg                             set_uart_tx;   // set UART tx data (full, starting witgh channel number = 0)
    reg                             set_idelays;    
    reg                             set_iclk_phase;
    reg                             set_ctrl_r;
    reg                             set_status_r;
    
    wire                            perr; // parity error from deserializer
    wire                            ps_rdy;
    wire                      [7:0] ps_out;
    wire                      [7:0] test_out; // should be 0x17 from unused serial signals      
    wire                            clkin_pxd_stopped_mmcm;
    wire                            clkfb_pxd_stopped_mmcm;
    
    // programmed resets to the sensor 
    reg                         imrst = 0;  // active low 
    reg                         rst_mmcm=1; // rst and command - en/dis 
    reg                         ld_idelay=0;

    wire                 [25:0] status;
    
    wire                        cmd_we;
    wire                  [2:0] cmd_a;
    wire                 [31:0] cmd_data;
    

    
    reg                   [7:0] gp_r;      // sensor GP0, GP1. 2 bits per port : 00 - float, 01 - low, 10 - high , 11 - trigger
    reg                   [1:0] prst_with_sens_mrst = 2'h3; // prst extended to include sensor reset and rst_mmcm
    wire                        async_prst_with_sens_mrst =  ~imrst | rst_mmcm; // mclk domain   

    wire                        hact_mclk;
    wire                        perr_mclk;
    reg                         hact_alive;
    reg                         perr_persistent;
    reg                         nonlock_persistent; // detects if MMCM looses lock (or input clock)

    // new for Boson
    wire                        txd;
    wire                        rxd;
    reg                         extif_en; // enable sequencer commands (disable during software ones if needed)
    reg                         xmit_rst;    // input
    reg                         recv_rst;    // input
    reg                         xmit_start;  // input
    reg                         recv_next;   // input

    wire                        xmit_busy;   // output
    wire                        recv_pav;  // output
    wire                        recv_eop;    // output fifo not empty
    wire                 [7:0]  recv_data;    // output[7:0] 
    
    wire                        senspgmin;   // detect sensorboard
    // GP0..GP3 are not yet used, fake-use gp_comb to keep
    wire [3:0] gp;
    wire [2:0] dummy; // to keep iostandard of unused pins in a bank
    wire       gp_comb = (^gp[3:0]) ^ (^dummy);
    reg        test_patt;
    reg  [7:0] perr_cntr;
    reg  [SENS_TEST_BITS-1:0] test_mode;
//perr
    assign status = {test_patt? perr_cntr[7:0]: recv_data[7:0],                      // [23:16]
                     recv_eop,                            // 15
                     recv_pav,                            // 14 
                     imrst ? hact_alive : gp_comb,        // 13 using gp_comb to keep
                     locked_pclk,                         // 12 // wait after mrst
                     test_patt? nonlock_persistent : clkin_pxd_stopped_mmcm,              // 11
                     clkfb_pxd_stopped_mmcm,              // 10
                     perr_persistent,                     //  9 deserializer parity error
                     test_patt? perr : ps_rdy,            //  8
                     test_patt? test_out[7:0]:ps_out[7:0],// [7:0]
                     xmit_busy,                           // 25
                     senspgmin};                          // 24

    assign  prsts = prst_with_sens_mrst[0];  // @pclk - includes sensor reset and sensor PLL reset
    assign dvalid = dvalid_w;
    assign  pxd =   (|test_mode)? pxd_test : pxd_w;
    
    
    always @(posedge pclk or posedge async_prst_with_sens_mrst) begin
        if (async_prst_with_sens_mrst) prst_with_sens_mrst <=  2'h3;
        else if (prst)                 prst_with_sens_mrst <=  2'h3;
        else                           prst_with_sens_mrst <= prst_with_sens_mrst >> 1;
        
    end
    
    always @(posedge pclk) begin
        dvalid_r <= dvalid_w;
        
        if (prst) perr_cntr <= 0;
        if (perr) perr_cntr <= perr_cntr + 1;
    end

//dvalid_r

    always @(posedge mclk) begin
        if      (mrst)   data_r <= 0;
        else if (cmd_we) data_r <= cmd_data;
        
        if      (mrst)   set_uart_tx <= 0;
        else             set_uart_tx <=  cmd_we & (cmd_a==(SENSIO_DELAYS+0)); // TODO - add Symbolic names

        if      (mrst)   set_uart_ctrl <= 0;
        else             set_uart_ctrl <=  cmd_we & (cmd_a==(SENSIO_DELAYS+1));

        if      (mrst)   set_idelays <= 0;
        else             set_idelays <=  cmd_we & (cmd_a==(SENSIO_DELAYS+2));
                                             
        if      (mrst)   set_iclk_phase <= 0;
        else             set_iclk_phase <=  cmd_we & (cmd_a==(SENSIO_DELAYS+3));
                                             
        if (mrst)        set_status_r <=0;
        else             set_status_r <= cmd_we && (cmd_a== SENSIO_STATUS);                             
        
        if (mrst)        set_ctrl_r <=0;
        else             set_ctrl_r <= cmd_we && (cmd_a== SENSIO_CTRL);                             
        
        if      (mrst)                                      imrst <= 0; 
        else if (set_ctrl_r && data_r[SENS_CTRL_MRST + 1])  imrst <= data_r[SENS_CTRL_MRST]; 
         
        if      (mrst)                                          rst_mmcm <= 0;
        else if (set_ctrl_r && data_r[SENS_CTRL_RST_MMCM + 1])  rst_mmcm <= data_r[SENS_CTRL_RST_MMCM]; 
         
        if  (mrst)                                          ld_idelay <= 0;
        else                                                ld_idelay <= set_ctrl_r && data_r[SENS_CTRL_LD_DLY]; 

        if      (mrst)                                      gp_r[1:0] <= 0;
        else if (set_ctrl_r && data_r[SENS_CTRL_GP0 + 2])   gp_r[1:0] <= data_r[SENS_CTRL_GP0+:2]; 

        if      (mrst)                                      gp_r[3:2] <= 0;
        else if (set_ctrl_r && data_r[SENS_CTRL_GP1 + 2])   gp_r[3:2] <= data_r[SENS_CTRL_GP1+:2]; 

        if      (mrst)                                      gp_r[5:4] <= 0;
        else if (set_ctrl_r && data_r[SENS_CTRL_GP2 + 2])   gp_r[5:4] <= data_r[SENS_CTRL_GP2+:2]; 

        if      (mrst)                                      gp_r[7:6] <= 0;
        else if (set_ctrl_r && data_r[SENS_CTRL_GP3 + 2])   gp_r[7:6] <= data_r[SENS_CTRL_GP3+:2]; 

        if      (mrst)                                      test_patt <= 0;
        else if (set_ctrl_r && data_r[SENS_ALT_STATUS_SET]) test_patt <= data_r[SENS_ALT_STATUS];

        if      (mrst)                                      test_mode <= 0;
        else if (set_ctrl_r && data_r[SENS_TEST_SET])       test_mode <= data_r[SENS_TEST_MODES+:SENS_TEST_BITS];


        if      (mrst)                                            extif_en <= 0;
        else if (set_uart_ctrl && data_r[SENS_UART_EXTIF_EN + 1]) extif_en <= data_r[SENS_UART_EXTIF_EN]; 

        if      (mrst)                                            xmit_rst <= 0;
        else if (set_uart_ctrl && data_r[SENS_UART_XMIT_RST + 1]) xmit_rst <= data_r[SENS_UART_XMIT_RST]; 

        if      (mrst)                                            recv_rst <= 0;
        else if (set_uart_ctrl && data_r[SENS_UART_RECV_RST + 1]) recv_rst <= data_r[SENS_UART_RECV_RST]; 

        xmit_start <= !mrst && set_uart_ctrl && data_r[SENS_UART_XMIT_START];
        recv_next <=  !mrst && set_uart_ctrl && data_r[SENS_UART_RECV_NEXT];
        
        if      (mrst || set_iclk_phase || set_idelays)     hact_alive <= 0;
        else if (hact_mclk)                                 hact_alive <= 1;

        if      (mrst || set_ctrl_r)                        perr_persistent <= 0;
        else if (perr_mclk)                                 perr_persistent <= 1;
        
        if      (mrst || set_ctrl_r)                                                nonlock_persistent <= 0;
        else if (!locked_pclk || clkin_pxd_stopped_mmcm || clkfb_pxd_stopped_mmcm)  nonlock_persistent <= 1;
        
    end

    cmd_deser #(
        .ADDR        (SENSIO_ADDR),
        .ADDR_MASK   (SENSIO_ADDR_MASK),
        .NUM_CYCLES  (6),
        .ADDR_WIDTH  (3),
        .DATA_WIDTH  (32)
    ) cmd_deser_sens_io_i (
        .rst         (1'b0),     // rst), // input
        .clk         (mclk),     // input
        .srst        (mrst), // input
        .ad          (cmd_ad),   // input[7:0] 
        .stb         (cmd_stb),  // input
        .addr        (cmd_a),    // output[15:0] 
        .data        (cmd_data), // output[31:0] 
        .we          (cmd_we)    // output
    );
    status_generate #(
        .STATUS_REG_ADDR(SENSIO_STATUS_REG),
        .PAYLOAD_BITS(26) // +3) // +STATUS_ALIVE_WIDTH) // STATUS_PAYLOAD_BITS)
    ) status_generate_sens_io_i (
        .rst        (1'b0),                    // rst), // input
        .clk        (mclk),                    // input
        .srst       (mrst),                    // input
        .we         (set_status_r),            // input
        .wd         (data_r[7:0]),             // input[7:0] 
        .status     (status),                  // input[22:0] 
        .ad         (status_ad),               // output[7:0] 
        .rq         (status_rq),               // output
        .start      (status_start)             // input
    );

    serial_103993 #(
        .START_FRAME_BYTE          (START_FRAME_BYTE),          // 'h8E),
        .END_FRAME_BYTE            (END_FRAME_BYTE),            // 'hAE),
        .ESCAPE_BYTE               (ESCAPE_BYTE),               // 'h9E),
        .REPLACED_START_FRAME_BYTE (REPLACED_START_FRAME_BYTE), // 'h81),
        .REPLACED_END_FRAME_BYTE   (REPLACED_END_FRAME_BYTE),   // 'hA1),
        .REPLACED_ESCAPE_BYTE      (REPLACED_ESCAPE_BYTE),      // 'h91),
        .INITIAL_CRC16             (INITIAL_CRC16),             // 16'h1d0f),
        .CLK_DIV                   (CLK_DIV),                   // 217),
        .RX_DEBOUNCE               (RX_DEBOUNCE),               // 60),
        .UART_STOP_BITS            (UART_STOP_BITS),            // 1) 
        .EXTIF_MODE                (EXTIF_MODE)                 // 1)
    ) serial_103993_i (
        .mrst                      (mrst),        // input
        .mclk                      (mclk),        // input
        .txd                       (txd),         // output
        .rxd                       (rxd),         // input
        .extif_dav                 (extif_dav),   // input
        .extif_sel                 (extif_sel),   // input[1:0] 
        .extif_byte                (extif_byte),  // input[7:0] 
        .extif_ready               (extif_ready), // output
        .extif_rst                 (extif_rst),   // input
        .extif_en                  (extif_en),    // input
        .xmit_rst                  (xmit_rst),    // input
        .xmit_start                (xmit_start),  // input
        .xmit_data                 (data_r[7:0]), // input[7:0] 
        .xmit_stb                  (set_uart_tx), // input
        .xmit_busy                 (xmit_busy),   // output
        .recv_rst                  (recv_rst),    // input
        .recv_next                 (recv_next),   // input
        .recv_pav                  (recv_pav),    // output at least one received packet is in fifo
        .recv_eop                  (recv_eop),    // output end of packet (discard recv_data; apply recv_next)
        .recv_data                 (recv_data)    // output[7:0] 
    );


    sens_103993_l3 #(
        .IODELAY_GRP            (IODELAY_GRP),
        .IDELAY_VALUE           (IDELAY_VALUE),
        .REFCLK_FREQUENCY       (REFCLK_FREQUENCY),
        .HIGH_PERFORMANCE_MODE  (HIGH_PERFORMANCE_MODE),
        .SENS_PHASE_WIDTH       (SENS_PHASE_WIDTH),
        .SENS_BANDWIDTH         (SENS_BANDWIDTH),
        .CLKIN_PERIOD_SENSOR    (CLKIN_PERIOD_SENSOR),    // 37.037),
        .CLKFBOUT_MULT_SENSOR   (CLKFBOUT_MULT_SENSOR),   // (30),
        .CLKFBOUT_PHASE_SENSOR  (CLKFBOUT_PHASE_SENSOR),  // (0.000),
        .PCLK_PHASE             (PCLK_PHASE),             // (0.000),
        .IPCLK2X_PHASE          (IPCLK2X_PHASE),          //(0.000),
        .BUF_PCLK               (BUF_PCLK),               // "BUFR"),
        .BUF_IPCLK2X            (BUF_IPCLK2X),            // "BUFR"),
        .SENS_DIVCLK_DIVIDE     (SENS_DIVCLK_DIVIDE),     // 1),
        .SENS_REF_JITTER1       (SENS_REF_JITTER1),       // 0.010),
        .SENS_REF_JITTER2       (SENS_REF_JITTER2),       // 0.010),
        .SENS_SS_EN             (SENS_SS_EN),             // "FALSE"),
        .SENS_SS_MODE           (SENS_SS_MODE),           // "CENTER_HIGH"),
        .SENS_SS_MOD_PERIOD     (SENS_SS_MOD_PERIOD),     // 10000),
        .NUMLANES               (NUMLANES),               // 3),
        .LVDS_DELAY_CLK         (LVDS_DELAY_CLK),         // "FALSE"),
        .LVDS_MMCM              (LVDS_MMCM),              // "TRUE"),
        .LVDS_CAPACITANCE       (LVDS_CAPACITANCE),       // "DONT_CARE"),
        .LVDS_DIFF_TERM         (LVDS_DIFF_TERM),         // "TRUE"),
        .LVDS_UNTUNED_SPLIT     (LVDS_UNTUNED_SPLIT),     // "FALSE"),
        .LVDS_DQS_BIAS          (LVDS_DQS_BIAS),          // "TRUE"),
        .LVDS_IBUF_DELAY_VALUE  (LVDS_IBUF_DELAY_VALUE),  // "0"),
        .LVDS_IBUF_LOW_PWR      (LVDS_IBUF_LOW_PWR),      // "TRUE"),
        .LVDS_IFD_DELAY_VALUE   (LVDS_IFD_DELAY_VALUE),   // "AUTO"),
        .LVDS_IOSTANDARD        (LVDS_IOSTANDARD)         // "DIFF_SSTL18_I")
    ) sens_103993_l3_i (
        .pclk                   (pclk),                   // output
        .sns_dp                 (sns_dp[2:0]),                 // input[2:0] 
        .sns_dn                 (sns_dn[2:0]),                 // input[2:0] 
        .sns_clkp               (sns_clkp),               // input
        .sns_clkn               (sns_clkn),               // input
        .pxd_out                (pxd_w),                  // output[15:0] 
        .vsync                  (vsync),                  // output
        .hsync                  (hsync),                  // output
        .dvalid                 (dvalid_w),               // output
        .mclk                   (mclk),                   // input
        .mrst                   (mrst),                   // input
        .dly_data               (data_r[23:0]),           // input[23:0] 
        .set_idelay             ({NUMLANES{set_idelays}}),// input[2:0] 
        .ld_idelay              (ld_idelay),              // input
        .set_clk_phase          (set_iclk_phase),         // input
        .rst_mmcm               (rst_mmcm),               // input
        .perr                   (perr),                   // output
        .ps_rdy                 (ps_rdy),                 // output
        .ps_out                 (ps_out),                 // output[7:0] 
        .test_out               (test_out),               // output[7:0] // should be 0x17 
        .locked_pxd_mmcm        (locked_pclk),            // output
        .clkin_pxd_stopped_mmcm (clkin_pxd_stopped_mmcm), // output
        .clkfb_pxd_stopped_mmcm (clkfb_pxd_stopped_mmcm)  // output
    );
  
 // implement test gradient
    assign pxd_test =
     (test_mode == 1) ? {row_num8_test[7:0], col_num8_test[7:0]}:
    ((test_mode == 2) ? {6'b0,col_num_test[9:0]}:
                        {6'b0,row_num_test[9:0]});
    always @(posedge pclk) begin
        if      (!dvalid_w)             col_div_test <= SENS_TEST_WIDTH_INC-1;
        else                            col_div_test <= (col_div_test == 0)? (SENS_TEST_WIDTH_INC-1) : (col_div_test - 1);
    
        if      (!dvalid_w)             col_num8_test <= 0;
        else if (col_div_test == 0)     col_num8_test <= col_num8_test + 1; 

        if      (!dvalid_w)             col_num_test <= 0;
        else                            col_num_test <= col_num_test + 1; 
    
        if      (!vsync)                row_div_test <= SENS_TEST_HEIGHT_INC-1;
        else if (!dvalid_w && dvalid_r) row_div_test <= (row_div_test == 0)? (SENS_TEST_HEIGHT_INC-1) : (row_div_test - 1);
         
        if      (!vsync)                                       row_num8_test <= 0;
        else if (!dvalid_w && dvalid_r && (row_div_test == 0)) row_num8_test <= row_num8_test + 1; 

        if      (!vsync)                                       row_num_test <= 0;
        else if (!dvalid_w && dvalid_r)                        row_num_test <= row_num_test + 1; 
    end
    
    mpullup i_senspgm_pullup          (sns_pgm);
    iobuf #(
        .DRIVE        (PXD_DRIVE),
        .IBUF_LOW_PWR (PXD_IBUF_LOW_PWR),
        .IOSTANDARD   (PXD_IOSTANDARD),
        .SLEW         (PXD_SLEW)
    ) sns_pgm_i (
        .O  (senspgmin), // output
        .IO (sns_pgm),   // inout
        .I  (1'b0),      // input
        .T  (1'b1)       // input
    );

    // generate ext_sync
    obuf #(
        .CAPACITANCE  (PXD_CAPACITANCE),
        .DRIVE        (PXD_DRIVE),
        .IOSTANDARD   (PXD_IOSTANDARD),
        .SLEW         (PXD_SLEW)
    ) ext_sync_i (
        .O  (sns_ext_sync), // output
        .I  (ext_sync)      // input
    );

    // generate MRST (for Boson ground/float
    obuft #(
        .CAPACITANCE  (PXD_CAPACITANCE),
        .DRIVE        (PXD_DRIVE),
        .IOSTANDARD   (PXD_IOSTANDARD),
        .SLEW         (PXD_SLEW)
    ) sns_mrst_i (
        .O  (sns_mrst),      // output
        .I  (imrst),         // input
        .T  (imrst)       // input // tristate when high
    );


    // General purpose I/O - reserved for future use
    iobuf #(
        .DRIVE        (PXD_DRIVE),
        .IBUF_LOW_PWR (PXD_IBUF_LOW_PWR),
        .IOSTANDARD   (PXD_IOSTANDARD),
        .SLEW         (PXD_SLEW)
    ) gp0_i (
        .O  (gp[0]),      // output
        .IO (sns_gp0),    // inout
        .I  (gp_r[1]),    // input
        .T  (~|gp_r[1:0]) // input
    );
    
    iobuf #(
        .DRIVE        (PXD_DRIVE),
        .IBUF_LOW_PWR (PXD_IBUF_LOW_PWR),
        .IOSTANDARD   (PXD_IOSTANDARD),
        .SLEW         (PXD_SLEW)
    ) gp1_i (
        .O  (gp[1]),    // output
        .IO (sns_gp1),  // inout
        .I  (gp_r[3]),   // input
        .T  (~|gp_r[3:2])    // input
    );
    

    iobuf #(
        .DRIVE        (PXD_DRIVE),
        .IBUF_LOW_PWR (PXD_IBUF_LOW_PWR),
        .IOSTANDARD   (PXD_IOSTANDARD),
        .SLEW         (PXD_SLEW)
    ) gp2_i (
        .O  (gp[2]),    // output
        .IO (sns_gp2),  // inout
        .I  (gp_r[5]),   // input
        .T  (~|gp_r[5:4])    // input
    );
    

    iobuf #(
        .DRIVE        (PXD_DRIVE),
        .IBUF_LOW_PWR (PXD_IBUF_LOW_PWR),
        .IOSTANDARD   (PXD_IOSTANDARD),
        .SLEW         (PXD_SLEW)
    ) gp3_i (
        .O  (gp[3]),    // output
        .IO (sns_gp3),  // inout
        .I  (gp_r[7]),   // input
        .T  (~|gp_r[7:6])    // input
    );
    
    // dummy I/O to specify IOSTANDARD
    iobuf #(
        .DRIVE        (PXD_DRIVE),
        .IBUF_LOW_PWR (PXD_IBUF_LOW_PWR),
        .IOSTANDARD   (PXD_IOSTANDARD),
        .SLEW         (PXD_SLEW)
    ) sns_dp6_i (
        .O  (dummy[0]),         // output
        .IO (sns_dp6),  // inout
        .I  (1'b0),   // input
        .T  (1'b0)    // input
    );

    // dummy I/O to specify IOSTANDARD
    /*
    iobuf #(
        .DRIVE        (PXD_DRIVE),
        .IBUF_LOW_PWR (PXD_IBUF_LOW_PWR),
        .IOSTANDARD   (PXD_IOSTANDARD),
        .SLEW         (PXD_SLEW)
    ) sns_dp3_i (
        .O  (dummy[1]),   // output
        .IO (sns_dp[3]),  // inout
        .I  (1'b0),       // input
        .T  (1'b0)        // input
    );

    // dummy I/O to specify IOSTANDARD
    iobuf #(
        .DRIVE        (PXD_DRIVE),
        .IBUF_LOW_PWR (PXD_IBUF_LOW_PWR),
        .IOSTANDARD   (PXD_IOSTANDARD),
        .SLEW         (PXD_SLEW)
    ) sns_dn3_i (
        .O  (dummy[2]),   // output
        .IO (sns_dn[3]),  // inout
        .I  (1'b0),       // input
        .T  (1'b0)        // input
    );
    */
    
    ibuf_ibufg #(
        .CAPACITANCE      (PXD_CAPACITANCE),
        .IBUF_DELAY_VALUE("0"),
        .IBUF_LOW_PWR (PXD_IBUF_LOW_PWR),
        .IFD_DELAY_VALUE("AUTO"),
        .IOSTANDARD   (PXD_IOSTANDARD)
    ) sns_dp3_i (
        .O(dummy[1]), // output
        .I(sns_dn[3]) // input
    );
    ibuf_ibufg #(
        .CAPACITANCE      (PXD_CAPACITANCE),
        .IBUF_DELAY_VALUE("0"),
        .IBUF_LOW_PWR (PXD_IBUF_LOW_PWR),
        .IFD_DELAY_VALUE("AUTO"),
        .IOSTANDARD   (PXD_IOSTANDARD)
    ) sns_dn3_i (
        .O(dummy[2]), // output
        .I(sns_dp[3]) // input
    );
    
// end of dummy

    
    // READ RXD    
    ibuf_ibufg #(
        .CAPACITANCE      (PXD_CAPACITANCE),
        .IBUF_DELAY_VALUE ("0"),
        .IBUF_LOW_PWR     (PXD_IBUF_LOW_PWR),
        .IFD_DELAY_VALUE  ("AUTO"),
        .IOSTANDARD       (PXD_IOSTANDARD)
    ) rxd_i (
        .O(rxd),     // output
        .I(sns_rxd) // input
    );
    
    // generate TXD
    obuf #(
        .CAPACITANCE  (PXD_CAPACITANCE),
        .DRIVE        (PXD_DRIVE),
        .IOSTANDARD   (PXD_IOSTANDARD),
        .SLEW         (PXD_SLEW)
    ) txd_i (
        .O  (sns_txd),            // output
        .I  (txd)                 // input
    );
    
    

    // perr - cross clocks
    pulse_cross_clock perr_mclk_i (
        .rst         (1'b0),                  // input
        .src_clk     (pclk),                  // input
        .dst_clk     (mclk),                  // input
        .in_pulse    (perr),                  // input
        .out_pulse   (perr_mclk),             // output
        .busy        ()                       // output
    );

    // just to verify hact is active
    pulse_cross_clock hact_mclk_i (
        .rst         (1'b0),                  // input
        .src_clk     (pclk),                  // input
        .dst_clk     (mclk),                  // input
        .in_pulse    (dvalid_w && !dvalid_r), // input
        .out_pulse   (hact_mclk),             // output
        .busy        ()                       // output
    );


    
endmodule

