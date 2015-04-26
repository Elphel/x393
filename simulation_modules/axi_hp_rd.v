/*******************************************************************************
 * Module: axi_hp_rd
 * Date:2015-04-25  
 * Author: andrey     
 * Description: Simplified model of AXI_HP read channel (64-bit only)
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * axi_hp_rd.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  axi_hp_rd.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  axi_hp_rd #(
    parameter [1:0] HP_PORT=0
)(
    // AXI signals
    input         aclk,
    output        aresetn, // do not use?
    // read address
    input  [31:0] araddr,
    input         arvalid,
    output        arready,
    input  [ 5:0] arid,
    input  [ 1:0] arlock,
    input  [ 3:0] arcache,
    input  [ 2:0] arprot,
    input  [ 3:0] arlen,
    input  [ 2:0] arsize,
    input  [ 1:0] arburst,
    input  [ 3:0] arqos,
    // read data
    output [63:0] rdata,
    output        rvalid,
    input         rready,
    output [ 5:0] rid,
    output        rlast,
    output [ 2:0] rresp,
    // PL extra (non-AXI) signals
    output [ 7:0] rcount,
    output [ 2:0] racount,
    input         rdissuecap1en,
    // Simulation signals - use same aclk
    output [31:0] sim_rd_address,
    output [ 5:0] sim_rid,
    output        sim_rd_valid,
    input         sim_rd_ready,
    input  [63:0] sim_rd_data,
    input  [31:0] reg_addr,
    input         reg_wr,
    input         reg_rd,
    input  [31:0] reg_din,
    output [31:0] reg_dout
);
    localparam AFI_BASECTRL= 32'hf8008000+ (HP<PORT << 12);
    localparam AFI_RDCHAN_CTRL= AFI_BASECTRL + 'h00;
    localparam AFI_RDCHAN_ISSUINGCAP= AFI_BASECTRL + 'h4;
    localparam AFI_RDQOS= AFI_BASECTRL + 'h8;
    localparam AFI_RDDATAFIFO_LEVEL= AFI_BASECTRL + 'hc;
    localparam AFI_RDDEBUG= AFI_BASECTRL + 'h10;


endmodule

