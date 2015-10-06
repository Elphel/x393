/*******************************************************************************
 * Module: sensor_i2c_prot
 * Date:2015-10-05  
 * Author: andrey     
 * Description: Generate i2c R/W sequence from a 32-bit word and LUT
 *
 * Copyright (c) 2015 Elphel, Inc .
 * sensor_i2c_prot.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  sensor_i2c_prot.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  sensor_i2c_prot(
    input         mrst,         // @ posedge mclk
    input         mclk,         // global clock
    input         i2c_rst,
    input         i2c_start,
    input  [ 7:0] i2c_dly,      // bit duration-1 (>=2?), 1 unit - 4 mclk periods
    // setup LUT to translate address page into SA, actual address MSB and number of bytes to write (second word bypasses translation)
    input         tand,         // table address/not data
    input  [19:0] td,           // table address/data in            
    input         twe,          // table write enable
    output reg    sda,
    output reg    sda_en,
    output reg    scl,
    output        i2c_run,
    output [ 1:0] seq_mem_ra, // number of byte to read from the sequencer memory
    output [ 1:0] seq_mem_re, // [0] - re, [1] - regen to teh sequencer memory
    input  [ 7:0] seq_rd,     // data from the sequencer memory 
    output [ 7:0] rdata,
    output        rvalid
);
    reg    [ 7:0] twa;
    wire   [31:0] tdout;
    wire   [ 7:0] reg_ah =         tdout[7:0];   // MSB of the register address (instead of the byte 2)
    wire   [ 6:0] slave_a =        tdout[14:8];  // 7-bit slave address (lsb == 1), used instead of the byte 3
    wire   [ 3:0] num_bytes_send = tdout[19:16]; // number of bytes to send (if more than 4 will skip stop and continue with next data
    reg    [ 3:0] bytes_left_send; // Number of bytes left in register write sequence (not counting sa?)
    reg           run_reg_wr;       // run register write
    reg           run_extra_wr;    // continue register write (if more than sa + 4bytes)
    reg           run_reg_rd;
    reg           i2c_done;
    wire          i2c_next_byte;
    reg    [ 2:0] mem_re;
    reg    [ 2:0] table_re;
    
    
    wire          decode_reg_rd = &seq_rd[7:5];
    wire          start_wr_seq = !run_extra_wr && !decode_reg_rd && read_mem_msb;
    reg           read_mem_msb;   
    assign seq_mem_re = mem_re[1:0];
    
    always @ (posedge mclk) begin
        read_mem_msb <= mem_re[1] && (seq_mem_ra == 3); // reading sequencer data MSB
        mem_re <= {mem_re[1:0], i2c_start | i2c_next_byte}; 
        table_re <= {table_re[1:0], start_wr_seq};
        
        if      (mrst || i2c_rst)                                 run_extra_wr <= 0;
        else if (i2c_start && (bytes_left_send !=0))              run_extra_wr <= 1;
        else if (i2c_done)                                        run_extra_wr <= 0;

        if      (mrst || i2c_rst)                                 run_reg_wr <= 0;
        else if (start_wr_seq)                                    run_reg_wr <= 1;
        else if (i2c_done)                                        run_reg_wr <= 0;

        if      (mrst || i2c_rst)                                 run_reg_rd <= 0;
        else if (!run_extra_wr &&  decode_reg_rd && read_mem_msb) run_reg_rd <= 1;
        else if (i2c_done)                                        run_reg_rd <= 0;
        
        // table_re[2] - valid table data (slave_a, reg_ah, reg_ah
    
    end    
     
     
    // table write  
    always @ (posedge mclk) begin
        if      (mrst) twa <= 0;
        else if (twe)  twa <= tand ? td[7:0] : (twa + 1);  
    end
    
    ram18_var_w_var_r #(
        .REGISTERS    (1),
        .LOG2WIDTH_WR (5),
        .LOG2WIDTH_RD (5),
        .DUMMY        (0)
    ) ram18_var_w_var_r_i (
        .rclk        (mclk), // input
        .raddr       ({1'b0, seq_rd}), // input[8:0] 
        .ren         (table_re[0]), // input
        .regen       (table_re[1]), // input
        .data_out    (tdout), // output[31:0] 
        .wclk        (mclk), // input
        .waddr       ({1'b0, twa}), // input[8:0] 
        .we          (twe && !tand), // input
        .web         (4'hf), // input[3:0] 
        .data_in     ({12'b0, td}) // input[31:0] 
    );


endmodule

