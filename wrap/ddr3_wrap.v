/*******************************************************************************
 * Module: ddr3_wrap
 * Date:2015-04-20  
 * Author: andrey     
 * Description: ddr3 model wrapper to include delays matching hardware
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * ddr3_wrap.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  ddr3_wrap.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
//`timescale 1ns/1ps
`timescale 1ps / 1ps

module  ddr3_wrap#(
    parameter ADDRESS_NUMBER =      15,
    parameter TRISTATE_DELAY_CLK =   2,
    parameter TRISTATE_DELAY =       0,
    parameter CLK_DELAY =            0,
    parameter CMDA_DELAY =           0,
    parameter DQS_IN_DELAY =         0,
    parameter DQ_IN_DELAY =          0,
    parameter DQS_OUT_DELAY =        0,
    parameter DQ_OUT_DELAY =         0
    )(
    input                       mclk,
    input                [1:0]  dq_tri,
    input                [1:0]  dqs_tri,
    
    input                       SDRST, // DDR3 reset (active low)
    input                       SDCLK, // DDR3 clock differential output, positive
    input                       SDNCLK,// DDR3 clock differential output, negative
    input  [ADDRESS_NUMBER-1:0] SDA,   // output address ports (14:0) for 4Gb device
    input                 [2:0] SDBA,  // output bank address ports
    input                       SDWE,  // output WE port
    input                       SDRAS, // output RAS port
    input                       SDCAS, // output CAS port
    input                       SDCKE, // output Clock Enable port
    input                       SDODT, // output ODT port

    inout                [15:0] SDD,   // DQ  I/O pads
    input                       SDDML, // LDM  I/O pad (actually only output)
    inout                       DQSL,  // LDQS I/O pad
    inout                       NDQSL, // ~LDQS I/O pad
    input                       SDDMU, // UDM  I/O pad (actually only output)
    inout                       DQSU,  // UDQS I/O pad
    inout                       NDQSU //,

);
    wire                      #(CLK_DELAY)  SDCLK_D =   SDCLK;
    wire                      #(CLK_DELAY)  SDNCLK_D =  SDNCLK;
    wire                      #(CMDA_DELAY) SDRST_D =   SDRST;
    wire [ADDRESS_NUMBER-1:0] #(CMDA_DELAY) SDA_D =     SDA;
    wire                [2:0] #(CMDA_DELAY) SDBA_D =    SDBA;
    wire                      #(CMDA_DELAY) SDWE_D =    SDWE;
    wire                      #(CMDA_DELAY) SDRAS_D =   SDRAS;
    wire                      #(CMDA_DELAY) SDCAS_D =   SDCAS;
    wire                      #(CMDA_DELAY) SDCKE_D =   SDCKE;
    wire                      #(CMDA_DELAY) SDODT_D =   SDODT;
    
    // generate
    /*
    input                       mclk,
    input                [1:0]  dq_tri,
    input                [1:0]  dqs_tri,
    */
    wire [1:0] en_dq_d;
    wire [1:0] en_dqs_d;
    wire [1:0] #(TRISTATE_DELAY) en_dq  = en_dq_d;
    wire [1:0] #(TRISTATE_DELAY) en_dqs = en_dqs_d;
    
    /* Instance template for module dly_16 */
    dly_16 #(
        .WIDTH(4)
    ) dly_16_i (
        .clk     (mclk),
        .rst     (~SDRST),
        .dly     (TRISTATE_DELAY_CLK), 
        .din     ({~dqs_tri,~dq_tri}), 
        .dout    ({en_dqs_d,en_dq_d}) 
    );
    wire [15:0] SDD_D;
    wire        SDDML_D;
    wire        SDDMU_D;
    wire        DQSL_D;  // LDQS I/O pad
    wire        NDQSL_D; // ~LDQS I/O pad
    wire        DQSU_D;  // UDQS I/O pad
    wire        NDQSU_D; //,
    
    
    assign #(DQ_OUT_DELAY) SDD_D[ 7:0] = en_dq[0]? SDD[7:0]: 8'bz;
    assign #(DQ_OUT_DELAY) SDD_D[15:8] = en_dq[1]? SDD[15:8]:8'bz;
    
    assign #(DQ_OUT_DELAY) SDDML_D = en_dq[0]? SDDML: 1'bz;
    assign #(DQ_OUT_DELAY) SDDMU_D = en_dq[1]? SDDMU: 1'bz;


    assign #(DQ_IN_DELAY) SDD  [ 7:0] = en_dq[0]? 8'bz : SDD_D[7:0];
    assign #(DQ_IN_DELAY) SDD  [15:8] = en_dq[1]? 8'bz : SDD_D[15:8];

    assign #(DQS_OUT_DELAY) DQSL_D =  en_dqs[0]? DQSL: 1'bz;
    assign #(DQS_OUT_DELAY) NDQSL_D = en_dqs[0]? NDQSL: 1'bz;
    assign #(DQS_OUT_DELAY) DQSU_D =  en_dqs[1]? DQSU: 1'bz;
    assign #(DQS_OUT_DELAY) NDQSU_D = en_dqs[1]? NDQSU: 1'bz;

    assign #(DQS_IN_DELAY) DQSL =  en_dqs[0]? 1'bz : DQSL_D;
    assign #(DQS_IN_DELAY) NDQSL = en_dqs[0]? 1'bz : NDQSL_D;
    assign #(DQS_IN_DELAY) DQSU =  en_dqs[1]? 1'bz : DQSU_D;
    assign #(DQS_IN_DELAY) NDQSU = en_dqs[1]? 1'bz : NDQSU_D;


    ddr3 #(
        .TCK_MIN             (2500), 
        .TJIT_PER            (100),
        .TJIT_CC             (200),
        .TERR_2PER           (147),
        .TERR_3PER           (175),
        .TERR_4PER           (194),
        .TERR_5PER           (209),
        .TERR_6PER           (222),
        .TERR_7PER           (232),
        .TERR_8PER           (241),
        .TERR_9PER           (249),
        .TERR_10PER          (257),
        .TERR_11PER          (263),
        .TERR_12PER          (269),
        .TDS                 (125),
        .TDH                 (150),
        .TDQSQ               (200),
        .TDQSS               (0.25),
        .TDSS                (0.20),
        .TDSH                (0.20),
        .TDQSCK              (400),
        .TQSH                (0.38),
        .TQSL                (0.38),
        .TDIPW               (600),
        .TIPW                (900),
        .TIS                 (350),
        .TIH                 (275),
        .TRAS_MIN            (37500),
        .TRC                 (52500),
        .TRCD                (15000),
        .TRP                 (15000),
        .TXP                 (7500),
        .TCKE                (7500),
        .TAON                (400),
        .TWLS                (325),
        .TWLH                (325),
        .TWLO                (9000),
        .TAA_MIN             (15000),
        .CL_TIME             (15000),
        .TDQSCK_DLLDIS       (400),
        .TRRD                (10000),
        .TFAW                (40000),
        .CL_MIN              (5),
        .CL_MAX              (14),
        .AL_MIN              (0),
        .AL_MAX              (2),
        .WR_MIN              (5),
        .WR_MAX              (16),
        .BL_MIN              (4),
        .BL_MAX              (8),
        .CWL_MIN             (5),
        .CWL_MAX             (10),
        .TCK_MAX             (3300),
        .TCH_AVG_MIN         (0.47),
        .TCL_AVG_MIN         (0.47),
        .TCH_AVG_MAX         (0.53),
        .TCL_AVG_MAX         (0.53),
        .TCH_ABS_MIN         (0.43),
        .TCL_ABS_MIN         (0.43),
        .TCKE_TCK            (3),
        .TAA_MAX             (20000),
        .TQH                 (0.38),
        .TRPRE               (0.90),
        .TRPST               (0.30),
        .TDQSH               (0.45),
        .TDQSL               (0.45),
        .TWPRE               (0.90),
        .TWPST               (0.30),
        .TCCD                (4),
        .TCCD_DG             (2),
        .TRAS_MAX            (60e9),
        .TWR                 (15000),
        .TMRD                (4),
        .TMOD                (15000),
        .TMOD_TCK            (12),
        .TRRD_TCK            (4),
        .TRRD_DG             (3000),
        .TRRD_DG_TCK         (2),
        .TRTP                (7500),
        .TRTP_TCK            (4),
        .TWTR                (7500),
        .TWTR_DG             (3750),
        .TWTR_TCK            (4),
        .TWTR_DG_TCK         (2),
        .TDLLK               (512),
        .TRFC_MIN            (260000),
        .TRFC_MAX            (70200000),
        .TXP_TCK             (3),
        .TXPDLL              (24000),
        .TXPDLL_TCK          (10),
        .TACTPDEN            (1),
        .TPRPDEN             (1),
        .TREFPDEN            (1),
        .TCPDED              (1),
        .TPD_MAX             (70200000),
        .TXPR                (270000),
        .TXPR_TCK            (5),
        .TXS                 (270000),
        .TXS_TCK             (5),
        .TXSDLL              (512),
        .TISXR               (350),
        .TCKSRE              (10000),
        .TCKSRE_TCK          (5),
        .TCKSRX              (10000),
        .TCKSRX_TCK          (5),
        .TCKESR_TCK          (4),
        .TAOF                (0.7),
        .TAONPD              (8500),
        .TAOFPD              (8500),
        .ODTH4               (4),
        .ODTH8               (6),
        .TADC                (0.7),
        .TWLMRD              (40),
        .TWLDQSEN            (25),
        .TWLOE               (2000),
        .DM_BITS             (2),
        .ADDR_BITS           (15),
        .ROW_BITS            (15),
        .COL_BITS            (10),
        .DQ_BITS             (16),
        .DQS_BITS            (2),
        .BA_BITS             (3),
        .MEM_BITS            (10),
        .AP                  (10),
        .BC                  (12),
        .BL_BITS             (3),
        .BO_BITS             (2),
        .CS_BITS             (1),
        .RANKS               (1),
        .RZQ                 (240),
        .PRE_DEF_PAT         (8'hAA),
        .STOP_ON_ERROR       (1),
        .DEBUG               (1),
        .BUS_DELAY           (0),
        .RANDOM_OUT_DELAY    (0),
        .RANDOM_SEED         (31913),
        .RDQSEN_PRE          (2),
        .RDQSEN_PST          (1),
        .RDQS_PRE            (2),
        .RDQS_PST            (1),
        .RDQEN_PRE           (0),
        .RDQEN_PST           (0),
        .WDQS_PRE            (2),
        .WDQS_PST            (1),
        .check_strict_mrbits (1),
        .check_strict_timing (1),
        .feature_pasr        (1),
        .feature_truebl4     (0),
        .feature_odt_hi      (0),
        .PERTCKAVG           (512),
        .LOAD_MODE           (4'b0000),
        .REFRESH             (4'b0001),
        .PRECHARGE           (4'b0010),
        .ACTIVATE            (4'b0011),
        .WRITE               (4'b0100),
        .READ                (4'b0101),
        .ZQ                  (4'b0110),
        .NOP                 (4'b0111),
        .PWR_DOWN            (4'b1000),
        .SELF_REF            (4'b1001),
        .RFF_BITS            (128),
        .RFF_CHUNK           (32),
        .SAME_BANK           (2'd0),
        .DIFF_BANK           (2'd1),
        .DIFF_GROUP          (2'd2),
        .SIMUL_500US         (5),
        .SIMUL_200US         (2)
    ) ddr3_i (
        .rst_n   (SDRST_D),         // input 
        .ck      (SDCLK_D),         // input 
        .ck_n    (SDNCLK_D),        // input 
        .cke     (SDCKE_D),         // input 
        .cs_n    (1'b0),            // input 
        .ras_n   (SDRAS_D),         // input 
        .cas_n   (SDCAS_D),         // input 
        .we_n    (SDWE_D),          // input 
        .dm_tdqs ({SDDMU_D,SDDML_D}),   // inout[1:0] 
        .ba      (SDBA_D[2:0]),     // input[2:0] 
        .addr    (SDA_D[14:0]),     // input[14:0] 
        .dq      (SDD_D[15:0]),       // inout[15:0] 
        .dqs     ({DQSU_D,DQSL_D}),     // inout[1:0] 
        .dqs_n   ({NDQSU_D,NDQSL_D}),   // inout[1:0] 
        .tdqs_n  (),                // output[1:0] 
        .odt     (SDODT_D)          // input 
    );


endmodule

