/*******************************************************************************
 * Module: clocks393
 * Date:2015-07-17  
 * Author: Andrey  Filippov   
 * Description: Generating global clocks for x393 (excluding memcntrl and SATA)
 *
 * Copyright (c) 2015 Elphel, Inc .
 * clocks393.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  clocks393.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  clocks393#(
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
        
        parameter CLKIN_PERIOD_XCLK =         20, // 24MHz 
        parameter DIVCLK_DIVIDE_XCLK =         1,
        parameter CLKFBOUT_MULT_XCLK =        50, // 1000 MHz
        parameter CLKOUT_DIV_XCLK =           10, // 100 MHz 
        parameter CLKOUT_DIV_XCLK2X =          5, // 200 MHz
        parameter PHASE_CLK2X_XCLK =           0.000, 
        parameter BUF_CLK1X_XCLK =            "BUFG",
        parameter BUF_CLK1X_XCLK2X =          "BUFG",  
        
        parameter CLKIN_PERIOD_SYNC =         20, // 24MHz 
        parameter DIVCLK_DIVIDE_SYNC =         1,
        parameter CLKFBOUT_MULT_SYNC =        50, // 1000 MHz
        parameter CLKOUT_DIV_SYNC =           10, // 100 MHz 
        parameter BUF_CLK1X_SYNC =            "BUFG",
        
        parameter MEMCLK_CAPACITANCE =        "DONT_CARE",
        parameter MEMCLK_IBUF_DELAY_VALUE =   "0",
        parameter MEMCLK_IBUF_LOW_PWR =       "TRUE",
        parameter MEMCLK_IFD_DELAY_VALUE =    "AUTO",
        parameter MEMCLK_IOSTANDARD =         "DEFAULT",

        parameter FFCLK0_CAPACITANCE =        "DONT_CARE",
        parameter FFCLK0_DIFF_TERM =          "FALSE",
        parameter FFCLK0_DQS_BIAS =           "FALSE",
        parameter FFCLK0_IBUF_DELAY_VALUE =   "0",
        parameter FFCLK0_IBUF_LOW_PWR =       "TRUE",
        parameter FFCLK0_IFD_DELAY_VALUE =    "AUTO",
        parameter FFCLK0_IOSTANDARD =         "DEFAULT",
        
        parameter FFCLK1_CAPACITANCE =        "DONT_CARE",
        parameter FFCLK1_DIFF_TERM =          "FALSE",
        parameter FFCLK1_DQS_BIAS =           "FALSE",
        parameter FFCLK1_IBUF_DELAY_VALUE =   "0",
        parameter FFCLK1_IBUF_LOW_PWR =       "TRUE",
        parameter FFCLK1_IFD_DELAY_VALUE =    "AUTO",
        parameter FFCLK1_IOSTANDARD =         "DEFAULT"
        
)(
    input       rst,
    input       mclk, // global clock, comes from the memory controller (uses aclk generated here)
    // command/status interface
    input                   [7:0] cmd_ad,       // byte-serial command address/data (up to 6 bytes: AL-AH-D0-D1-D2-D3 
    input                         cmd_stb,      // strobe (with first byte) for the command a/d
    output                  [7:0] status_ad,    // status address/data - up to 5 bytes: A - {seq,status[1:0]} - status[2:9] - status[10:17] - status[18:25]
    output                        status_rq,    // input request to send status downstream
    input                         status_start, // Acknowledge of the first status packet byte (address)
    input [3:0] fclk, // 4 clocks coming from the Zynq PS. Currently only [0] is used
    input       memclk_pad, // connected to external clock generator (VDD=1.5V)
    input       ffclk0p_pad, // differential clock (P) same power as sensors 0 and 1 (VCC_SENS01) 
    input       ffclk0n_pad, // differential clock (N) same power as sensors 0 and 1 (VCC_SENS01)
    input       ffclk1p_pad, // differential clock (P) same power as sensors 0 and 1 (VCC_SENS01) 
    input       ffclk1n_pad, // differential clock (N) same power as sensors 0 and 1 (VCC_SENS01)
    output      aclk,        // global clock 50 MHz (used for maxi0)
    output      hclk,        // global clock 150MHz (used for afi*, saxi*)
    output      pclk,        // global clock for sensors (now 96MHz), based on external clock generator
    output      pclk2x,      // global clock for sennors, 2x frequency (now 192MHz)
    output      xclk,        // global clock for compressor (now 100MHz) 
    output      xclk2x,      // global clock for compressor, 2x frequency (now 200MHz)
    output      sync_clk,    // global clock for camsync module (96 MHz for 353 compatibility - switch to 100MHz)?
    output      time_ref,     // non-global, just RTC (currently just mclk/8 = 25 MHz)
    input [1:0] extra_status // just extra two status bits from the top module
);
    wire         memclk;
    wire         ffclk0;
    wire         ffclk1;
    wire  [8:0] status_data;
    wire  [10:0] cmd_data;
    wire         cmd_we;
    wire   [0:0] cmd_a;
    
    wire         set_ctrl_w =   cmd_we & ((cmd_a  && CLK_MASK) == CLK_CNTRL);
    wire         set_status_w = cmd_we & ((cmd_a  && CLK_MASK) == CLK_STATUS);
    wire   [3:0] locked;
    reg    [6:0] reset_clk = 0;
    reg    [3:0] pwrdwn_clk = 0; 
    reg    [2:0] test_clk; // FF to test input clocks are running
    wire memclk_rst = reset_clk[4];
    wire ffclk0_rst = reset_clk[5];
    wire ffclk1_rst = reset_clk[6];
    
    always @ (posedge mclk or posedge rst) begin
        if (rst)             reset_clk <= 0;
        else if (set_ctrl_w) reset_clk <= {cmd_data[10:8], cmd_data[3:0]};
         
        if (rst)             pwrdwn_clk <= 0;
        else if (set_ctrl_w) pwrdwn_clk <= cmd_data[7:4]; 
    end
    assign status_data = {test_clk, locked, extra_status};
    always @ (posedge memclk or posedge memclk_rst) if (memclk_rst) test_clk[0] <= ~test_clk[0];
    always @ (posedge ffclk0 or posedge ffclk0_rst) if (ffclk0_rst) test_clk[1] <= ~test_clk[1];
    always @ (posedge ffclk1 or posedge ffclk1_rst) if (ffclk1_rst) test_clk[2] <= ~test_clk[2];
    
    cmd_deser #(
        .ADDR       (CLK_ADDR),
        .ADDR_MASK  (CLK_MASK),
        .NUM_CYCLES (4),
        .ADDR_WIDTH (1),
        .DATA_WIDTH (11)
    ) cmd_deser_32bit_i (
        .rst        (rst),      // input
        .clk        (mclk),     // input
        .ad         (cmd_ad),   // input[7:0] 
        .stb        (cmd_stb),  // input
        .addr       (cmd_a),    // output[3:0] 
        .data       (cmd_data), // output[31:0] 
        .we         (cmd_we)    // output
    );
 
    status_generate #(
        .STATUS_REG_ADDR     (CLK_STATUS_REG_ADDR),
        .PAYLOAD_BITS        (9),
        .REGISTER_STATUS     (0)
    ) status_generate_i (
        .rst           (rst), // input
        .clk           (mclk), // input
        .we            (set_status_w), // input
        .wd            (cmd_data[7:0]), // input[7:0] 
        .status        (status_data), // input[14:0] 
        .ad            (status_ad), // output[7:0] 
        .rq            (status_rq), // output
        .start         (status_start) // input
    );
    
    BUFG bufg_axi_aclk_i  (.O(aclk), .I(fclk[0]));

    dual_clock_source #(
        .CLKIN_PERIOD     (CLKIN_PERIOD_AXIHP),
        .DIVCLK_DIVIDE    (DIVCLK_DIVIDE_AXIHP),
        .CLKFBOUT_MULT    (CLKFBOUT_MULT_AXIHP),
        .CLKOUT_DIV_CLK1X (CLKOUT_DIV_AXIHP),
        .BUF_CLK1X        (BUF_CLK1X_AXIHP),
        .BUF_CLK2X        ("NONE")
    ) dual_clock_axihp_i (
        .rst              (reset_clk[0]), // input
        .clk_in           (aclk),         // input
        .pwrdwn           (pwrdwn_clk[0]), // input
        .clk1x            (hclk), // output
        .clk2x            (), // output
        .locked           (locked[0]) // output
    );
    
    dual_clock_source #(
        .CLKIN_PERIOD     (CLKIN_PERIOD_PCLK),
        .DIVCLK_DIVIDE    (DIVCLK_DIVIDE_PCLK),
        .CLKFBOUT_MULT    (CLKFBOUT_MULT_PCLK),
        .CLKOUT_DIV_CLK1X (CLKOUT_DIV_PCLK),
        .CLKOUT_DIV_CLK2X (CLKOUT_DIV_PCLK2X),
        .PHASE_CLK2X      (PHASE_CLK2X_PCLK),
        .BUF_CLK1X        (BUF_CLK1X_PCLK),
        .BUF_CLK2X        (BUF_CLK1X_PCLK2X)
    ) dual_clock_pclk_i (
        .rst              (reset_clk[1]),     // input
        .clk_in           (ffclk0),           // input
        .pwrdwn           (pwrdwn_clk[1]),    // input
        .clk1x            (pclk),             // output
        .clk2x            (pclk2x),           // output
        .locked           (locked[1])         // output
    );
    
    dual_clock_source #(
        .CLKIN_PERIOD     (CLKIN_PERIOD_XCLK),
        .DIVCLK_DIVIDE    (DIVCLK_DIVIDE_XCLK),
        .CLKFBOUT_MULT    (CLKFBOUT_MULT_XCLK),
        .CLKOUT_DIV_CLK1X (CLKOUT_DIV_XCLK),
        .CLKOUT_DIV_CLK2X (CLKOUT_DIV_XCLK2X),
        .PHASE_CLK2X      (PHASE_CLK2X_XCLK),
        .BUF_CLK1X        (BUF_CLK1X_XCLK),
        .BUF_CLK2X        (BUF_CLK1X_XCLK2X)
    ) dual_clock_xclk_i (
        .rst              (reset_clk[2]),     // input
        .clk_in           (aclk),             // input
        .pwrdwn           (pwrdwn_clk[2]),    // input
        .clk1x            (xclk),             // output
        .clk2x            (xclk2x),           // output
        .locked           (locked[2])         // output
    );
    
    dual_clock_source #(
        .CLKIN_PERIOD     (CLKIN_PERIOD_SYNC),
        .DIVCLK_DIVIDE    (DIVCLK_DIVIDE_SYNC),
        .CLKFBOUT_MULT    (CLKFBOUT_MULT_SYNC),
        .CLKOUT_DIV_CLK1X (CLKOUT_DIV_SYNC),
        .BUF_CLK1X        (BUF_CLK1X_SYNC),
        .BUF_CLK2X        ("NONE")
    ) dual_clock_sync_clk_i (
        .rst              (reset_clk[3]),     // input
        .clk_in           (aclk),           // input
        .pwrdwn           (pwrdwn_clk[3]),    // input
        .clk1x            (sync_clk),             // output
        .clk2x            (),           // output
        .locked           (locked[3])         // output
    );
    

    ibuf_ibufg #(
        .CAPACITANCE      (MEMCLK_CAPACITANCE),
        .IBUF_DELAY_VALUE (MEMCLK_IBUF_DELAY_VALUE),
        .IBUF_LOW_PWR     (MEMCLK_IBUF_LOW_PWR),
        .IFD_DELAY_VALUE  (MEMCLK_IFD_DELAY_VALUE),
        .IOSTANDARD       (MEMCLK_IOSTANDARD)
    ) ibuf_ibufg_i (
        .O    (memclk),    // output
        .I    (memclk_pad) // input
    );

    ibufds_ibufgds #(
        .CAPACITANCE      (FFCLK0_CAPACITANCE),
        .DIFF_TERM        (FFCLK0_DIFF_TERM),
        .DQS_BIAS         (FFCLK0_DQS_BIAS),
        .IBUF_DELAY_VALUE (FFCLK0_IBUF_DELAY_VALUE),
        .IBUF_LOW_PWR     (FFCLK0_IBUF_LOW_PWR),
        .IFD_DELAY_VALUE  (FFCLK0_IFD_DELAY_VALUE),
        .IOSTANDARD       (FFCLK0_IOSTANDARD)
    ) ibufds_ibufgds0_i (
        .O    (ffclk0),      // output
        .I    (ffclk0p_pad), // input
        .IB   (ffclk0n_pad)  // input
    );

    ibufds_ibufgds #(
        .CAPACITANCE      (FFCLK1_CAPACITANCE),
        .DIFF_TERM        (FFCLK1_DIFF_TERM),
        .DQS_BIAS         (FFCLK1_DQS_BIAS),
        .IBUF_DELAY_VALUE (FFCLK1_IBUF_DELAY_VALUE),
        .IBUF_LOW_PWR     (FFCLK1_IBUF_LOW_PWR),
        .IFD_DELAY_VALUE  (FFCLK1_IFD_DELAY_VALUE),
        .IOSTANDARD       (FFCLK1_IOSTANDARD)
    ) ibufds_ibufgds10_i (
        .O    (ffclk1),      // output
        .I    (ffclk1p_pad), // input
        .IB   (ffclk1n_pad)  // input
    );
    
   // RTC reference: integer number of microseconds, less than mclk/2. Not a global clock
   // temporary:
    reg [2:0] time_ref_r;
    always @ (posedge mclk or posedge rst) if (rst) time_ref_r <= 0; else time_ref_r <= time_ref_r + 1;
    assign time_ref = time_ref_r[2];

endmodule

