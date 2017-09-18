/*******************************************************************************
 * Module: x393_testbench_spi
 * Date:2017-09-07  
 * Author: Raimundas Bastys     
 * Description: testbench for the SPI modules simulation
 *
 * Copyright (c) 2015 Elphel, Inc.
 * x393_testbench_spi.tf is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  x393_testbench_spi.tf is distributed in the hope that it will be useful,
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
 *******************************************************************************/
`timescale 1ns/1ps
`include "system_defines.vh"

/*
`define SAME_SENSOR_DATA  1
//`undef SAME_SENSOR_DATA
`define COMPRESS_SINGLE
`define USE_CMPRS_IRQ
`define USE_FRAME_SEQ_IRQ
//`define use200Mhz 1
//`define DEBUG_FIFO 1
`undef WAIT_MRS
`define SET_PER_PIN_DELAYS 1 // set individual (including per-DQ pin delays)
`define READBACK_DELAYS 1

//`define TEST_MEMBRIDGE 1 // was not set
`undef TEST_MEMBRIDGE // was not set

`define PS_PIO_WAIT_COMPLETE 0 // wait until PS PIO module finished transaction before starting a new one
// Disabled already passed test to speedup simulation
//`define TEST_WRITE_LEVELLING 1
//`define TEST_READ_PATTERN 1
//`define TEST_WRITE_BLOCK 1
//`define TEST_READ_BLOCK 1
//`define TEST_SCANLINE_WRITE
    `define TEST_SCANLINE_WRITE_WAIT 1 // wait TEST_SCANLINE_WRITE finished (frame_done)
//`define TEST_SCANLINE_READ
    `define TEST_READ_SHOW  1
//`define TEST_TILED_WRITE  1
    `define TEST_TILED_WRITE_WAIT 1 // wait TEST_SCANLINE_WRITE finished (frame_done)
//`define TEST_TILED_READ  1

//`define TEST_TILED_WRITE32  1
//`define TEST_TILED_READ32  1

//`define TEST_AFI_WRITE 1
//`define TEST_AFI_READ 1

`define TEST_SENSOR 0
*/

module  x393_testbench_spi #(
`include "includes/x393_parameters.vh" // SuppressThisWarning VEditor - not used
`include "includes/x393_simulation_parameters.vh"
)(
);
`ifdef IVERILOG              
//    $display("IVERILOG is defined");
    `ifdef NON_VDT_ENVIROMENT
        parameter fstname="x393.fst";
    `else
        `include "IVERILOG_INCLUDE.v"
    `endif // NON_VDT_ENVIROMENT
`else // IVERILOG
//    $display("IVERILOG is not defined");
    `ifdef CVC
        `ifdef NON_VDT_ENVIROMENT
            parameter fstname = "x393.fst";
        `else // NON_VDT_ENVIROMENT
            `include "IVERILOG_INCLUDE.v"
        `endif // NON_VDT_ENVIROMENT
    `else
        parameter fstname = "x393.fst";
    `endif // CVC
`endif // IVERILOG

    reg     RST_CLEAN  = 1;
    wire    CLK;
    reg     reset;
    wire [7:0]  reg_data; 
    reg [7:0]  wr_data; 
    reg     wr_en = 0;
    reg     rd_en = 0;
    reg [6:0] addr;
    wire    spi_ready;

// Sensor signals - as on sensor pads
    wire [3:0] PX1_LANE_P;         // from sensor to FPGA 
    wire [3:0] PX1_LANE_N;         // from sensor to FPGA
    wire       PX1_CLK_P;          // from sensor to FPGA
    wire       PX1_CLK_N;          // from sensor to FPGA
    wire       PX1_CTRL_P;          // from sensor to FPGA
    wire       PX1_CTRL_N;          // from sensor to FPGA
    wire       PX1_MRST;            // from FPGA to sensor
    wire       PX1_FR_RQ;            // from FPGA to sensor
    wire       PX1_EXP1;            // from FPGA to sensor
    wire       PX1_EXP2;            // from FPGA to sensor
    wire       PX1_SPI_EN;            // from FPGA to sensor
    wire       PX1_SCL;            // from FPGA to sensor
    wire       PX1_SPI_OUT;          // from sensor to FPGA
    wire       PX1_MCLK;            // from FPGA to sensor, sensor input clock

    wire       PX1_MCLK_PRE;       // input to pixel clock mult/divisor       // SuppressThisWarning VEditor - may be unused

// Sensor signals - as on FPGA pads
    wire [ 7:0] sns1_dp;   // inout[7:0] {PX1_SPI_EN, PX1_EXP2, PX1_FR_RQ, PX1_CTRL_P, PX1_LANE_P[3:0]}
    wire [ 7:0] sns1_dn;   // inout[7:0] {PX1_MCLK_PRE, PX1_MRST, PX1_EXP1, PX1_CTRL_N, PX1_LANE_N[3:0]}
    wire        sns1_clkp; // inout PX1_CLK_P
    wire        sns1_clkn; // inout PX1_CLK_N
    wire        sns1_scl;  // inout PX_SCL
    wire        sns1_sda;  // inout PX_SDA, PX_SPI_I
    wire        sns1_ctl;  // inout TCK, PX_SPI_O
    wire        sns1_pg;   // inout SENSPGM
//
    assign sns1_dp[3:0] =  PX1_LANE_P[3:0]; // from sensor to FPGA
    assign sns1_dn[3:0] =  PX1_LANE_N[3:0]; // from sensor to FPGA
    assign sns1_clkp =     PX1_CLK_P;       // from sensor to FPGA
    assign sns1_clkn =     PX1_CLK_N;       // from sensor to FPGA

    assign sns1_dp[4] =    PX1_CTRL_P;      // from sensor to FPGA
    assign sns1_dn[4] =    PX1_CTRL_N;      // from sensor to FPGA
    assign PX1_FR_RQ =     sns1_dp[5];      // from FPGA to sensor
    assign PX1_EXP1 =      sns1_dn[5];      // from FPGA to sensor
    assign PX1_EXP2 =      sns1_dp[6];      // from FPGA to sensor
    assign PX1_MRST =      sns1_dn[6];      // from FPGA to sensor
    assign PX1_SPI_EN =    sns1_dp[7];      // from FPGA to sensor
    assign PX1_MCLK_PRE =  sns1_dn[7];      // from FPGA to sensor
    assign PX1_SCL =       sns1_scl;        // from FPGA to sensor
//  sns1_sda // inout FPGA - sensor, i2c data and SPI input form FPGA to sensor
    assign sns1_ctl =      PX1_SPI_OUT;      // from sensor to FPGA
    

// modules    

    sensor_spi_io sensor_spi_io_i
(
        .clk0(CLK),               //clock 10-40MHz CMV300
        .reset(reset),          //reset, active high
        .addr(addr),     //spi address
        .rd_en(rd_en),          //read from sensor enable, one clock period input signal
        .wr_en(wr_en),              //write to sensor enable, one clock period input signal
        .wr_data(wr_data),      //data to spi address be write
        .reg_data(reg_data),  //data from spi address will read
        .spi_ready(spi_ready),  //spi available for command
        .pin_spi_out(sns1_ctl),        //SPI interface pin: data out, direction from sensor to FPGA 
        .pin_spi_in(sns1_sda),      //SPI interface pin: data in, direction from FPGA to sensor 
        .pin_spi_en(sns1_dp[7]),      //SPI interface pin: data enable, direction from FPGA to sensor 
        .pin_spi_reset(sns1_dn[6]),   //SPI interface pin: data reset, direction from FPGA to sensor 
        .pin_spi_clk(PX1_MCLK)      //SPI interface pin: data clock, direction from FPGA to sensor 
);


// Simulation modules    

    simul_clk_single #(
        .PERIOD(25)
) simul_clk_i (
        .rst(1'b0), 
        .clk(CLK)
);

    simul_sensor_spi # (
        .SENSOR_IMAGE_TYPE ("NORM"), 
        .SENSOR_TYPE ("CMV300") 
) simul_sensor_spi_i (
        .pin_spi_out(PX1_SPI_OUT),        //SPI interface pin: data out, direction from sensor to FPGA 
        .pin_spi_in(sns1_sda),      //SPI interface pin: data in, direction from FPGA to sensor 
        .pin_spi_en(PX1_SPI_EN),      //SPI interface pin: data enable, direction from FPGA to sensor 
        .pin_spi_reset(PX1_MRST),   //SPI interface pin: data reset, direction from FPGA to sensor 
        .pin_spi_clk(PX1_MCLK)      //SPI interface pin: data clock, direction from FPGA to sensor 
);

    task read_spi;
        input  [6:0] adresas;
        begin
            addr[6:0] <= adresas [6:0];
            rd_en <= 1'b1;
            wait (CLK);
            wait (!CLK);
            wait (CLK);
            rd_en <= 1'b0;
            wait (!CLK && spi_ready);
            wait (CLK);
            wait (!CLK);
        end
    endtask

    task write_spi;
        input  [6:0] adresas;
        input  [7:0] write_data;
        begin
            addr[6:0] <= adresas [6:0];
            wr_data[7:0] <= write_data [7:0];
            wr_en <= 1'b1;
            wait (CLK);
            wait (!CLK);
            wait (CLK);
            wr_en <= 1'b0;
            wait (!CLK && spi_ready);
            wait (CLK);
            wait (!CLK);
        end
    endtask

    task all_regs_spi;
        integer i;
        reg  [6:0] adresas;
        begin
            adresas = 0;
            for (i=0; i<128; i=i+1) begin
                read_spi(adresas);
                $display("SPI %d reg - %d =====", addr, reg_data);
                adresas = adresas + 1;
            end
        end
    endtask

  initial begin

`ifdef IVERILOG              
    $display("IVERILOG is defined");
`else
    $display("IVERILOG is not defined");
`endif

`ifdef ICARUS              
    $display("ICARUS is defined");
`else
    $display("ICARUS is not defined");
`endif

    $dumpfile(fstname);
    $dumpvars(0,x393_testbench_spi);
  
    RST_CLEAN = 1;
    reset = 1'bx;
    #500;
    reset = 1'b1;
    #9000; // same as glbl
    repeat (20) @(posedge CLK) ;
    reset = 1'b0;
    @(posedge CLK) ;
    RST_CLEAN = 0;
    @(posedge CLK) ;
    all_regs_spi;
    write_spi(0,8'h55);
    read_spi(0);
    $display("===================");
    $display("SPI %d reg - 0x%x =====", addr, reg_data);
    #15000;
    
    $display("normal finish testbench");
    $finish;
  end 

// protect from never end
  initial begin

    #160000;
  
    $display("finish testbench (before end)");
  $finish;
  end



endmodule

