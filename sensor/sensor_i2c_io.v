/*******************************************************************************
 * Module: sensor_i2c_io
 * Date:2015-05-15  
 * Author: Andrey Filippov     
 * Description: sensor_i2c with I/O pad elements
 *
 * Copyright (c) 2015 Elphel, Inc.
 * sensor_i2c_io.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  sensor_i2c_io.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  sensor_i2c_io#(
    parameter SENSI2C_ABS_ADDR =    'h410,
    parameter SENSI2C_REL_ADDR =    'h420,
    parameter SENSI2C_ADDR_MASK =   'h7f0, // both for SENSI2C_ABS_ADDR and SENSI2C_REL_ADDR
    parameter SENSI2C_CTRL_ADDR =   'h402, // channel 0 will be 'h402..'h403
    parameter SENSI2C_CTRL_MASK =   'h7fe,
    parameter SENSI2C_CTRL =        'h0,
    parameter SENSI2C_STATUS =      'h1,
    parameter SENSI2C_STATUS_REG =  'h20,
    // Control register bits
    parameter SENSI2C_CMD_TABLE =       29, // [29]: 1 - write to translation table (ignore any other fields), 0 - write other fields
    parameter SENSI2C_CMD_TAND =        28, // [28]: 1 - write table address (8 bits), 0 - write table data (28 bits)
    parameter SENSI2C_CMD_RESET =       14, // [14]   reset all FIFO (takes 16 clock pulses), also - stops i2c until run command
    parameter SENSI2C_CMD_RUN =         13, // [13:12]3 - run i2c, 2 - stop i2c (needed before software i2c), 1,0 - no change to run state
    parameter SENSI2C_CMD_RUN_PBITS =    1,
    
    parameter SENSI2C_CMD_FIFO_RD =      3, // advane I2C read data FIFO by 1  
    parameter SENSI2C_CMD_ACIVE =        2, // [2] - SENSI2C_CMD_ACIVE_EARLY0, SENSI2C_CMD_ACIVE_SDA
    parameter SENSI2C_CMD_ACIVE_EARLY0 = 1, // release SDA==0 early if next bit ==1
    parameter SENSI2C_CMD_ACIVE_SDA =    0,  // drive SDA=1 during the second half of SCL=1
// I/O parameters   
    parameter integer SENSI2C_DRIVE = 12,
    parameter SENSI2C_IBUF_LOW_PWR = "TRUE",
    parameter SENSI2C_IOSTANDARD =  "DEFAULT",
    parameter SENSI2C_SLEW =        "SLOW"
)(
    input         mrst,        // @mclk
    input         mclk,        // global clock, half DDR3 clock, synchronizes all I/O through the command port
    input   [7:0] cmd_ad,      // byte-serial command address/data (up to 6 bytes: AL-AH-D0-D1-D2-D3 
    input         cmd_stb,     // strobe (with first byte) for the command a/d
    output  [7:0] status_ad,   // status address/data - up to 5 bytes: A - {seq,status[1:0]} - status[2:9] - status[10:17] - status[18:25]
    output        status_rq,   // input request to send status downstream
    input         status_start,// Acknowledge of the first status packet byte (address)
    input         frame_sync,  // increment/reset frame number
    inout         scl,
    inout         sda
);
        wire scl_in;
        wire sda_in;
        wire scl_out;
        wire sda_out;
        wire scl_en;
        wire sda_en;

    sensor_i2c #(
        .SENSI2C_ABS_ADDR        (SENSI2C_ABS_ADDR),
        .SENSI2C_REL_ADDR        (SENSI2C_REL_ADDR),
        .SENSI2C_ADDR_MASK       (SENSI2C_ADDR_MASK),
        .SENSI2C_CTRL_ADDR       (SENSI2C_CTRL_ADDR),
        .SENSI2C_CTRL_MASK       (SENSI2C_CTRL_MASK),
        .SENSI2C_CTRL            (SENSI2C_CTRL),
        .SENSI2C_STATUS          (SENSI2C_STATUS),
        .SENSI2C_STATUS_REG      (SENSI2C_STATUS_REG),
        .SENSI2C_CMD_TABLE       (SENSI2C_CMD_TABLE),
        .SENSI2C_CMD_TAND        (SENSI2C_CMD_TAND),
        .SENSI2C_CMD_RESET       (SENSI2C_CMD_RESET),
        .SENSI2C_CMD_RUN         (SENSI2C_CMD_RUN),
        .SENSI2C_CMD_RUN_PBITS   (SENSI2C_CMD_RUN_PBITS),
        .SENSI2C_CMD_FIFO_RD     (SENSI2C_CMD_FIFO_RD),
        .SENSI2C_CMD_ACIVE       (SENSI2C_CMD_ACIVE),
        .SENSI2C_CMD_ACIVE_EARLY0(SENSI2C_CMD_ACIVE_EARLY0),
        .SENSI2C_CMD_ACIVE_SDA   (SENSI2C_CMD_ACIVE_SDA)
        
    ) sensor_i2c_i (
        .mrst          (mrst),         // input
        .mclk          (mclk),         // input
        .cmd_ad        (cmd_ad),       // input[7:0] 
        .cmd_stb       (cmd_stb),      // input
        .status_ad     (status_ad),    // output[7:0] 
        .status_rq     (status_rq),    // output
        .status_start  (status_start), // input
        .frame_sync    (frame_sync),   // input
        .scl_in        (scl_in),       // input
        .sda_in        (sda_in),       // input
        .scl_out       (scl_out),      // output
        .sda_out       (sda_out),      // output
        .scl_en        (scl_en),       // output
        .sda_en        (sda_en)        // output
    );

    iobuf #(
        .DRIVE        (SENSI2C_DRIVE),
        .IBUF_LOW_PWR (SENSI2C_IBUF_LOW_PWR),
        .IOSTANDARD   (SENSI2C_IOSTANDARD),
        .SLEW         (SENSI2C_SLEW)
    ) iobuf_scl_i (
        .O     (scl_in),  // output
        .IO    (scl),     // inout
        .I     (scl_out), // input
        .T     (!scl_en)  // input
    );

    iobuf #(
        .DRIVE        (SENSI2C_DRIVE),
        .IBUF_LOW_PWR (SENSI2C_IBUF_LOW_PWR),
        .IOSTANDARD   (SENSI2C_IOSTANDARD),
        .SLEW         (SENSI2C_SLEW)
    ) iobuf_sda_i (
        .O     (sda_in),  // output
        .IO    (sda),     // inout
        .I     (sda_out), // input
        .T     (!sda_en)  // input
    );
    mpullup i_scl_pullup(scl);
    mpullup i_sda_pullup(sda);

endmodule

