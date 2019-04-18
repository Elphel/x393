/*!
 * <b>Module:</b> vospi_packet_80
 * @file vospi_packet_80.v
 * @date 2019-04-08  
 * @author Andrey Filippov
 *     
 * @brief VoSPI receive 160 byte packets
 *
 * @copyright Copyright (c) 2019 Elphel, Inc.
 *
 * <b>License </b>
 *
 * vospi_packet_80.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * vospi_packet_80.v is distributed in the hope that it will be useful,
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

module  vospi_packet_80#(
    parameter VOSPI_PACKET_WORDS = 80,
    parameter VOSPI_NO_INVALID = 1 // do not output invalid packets data
)(
    input         rst,
    input         clk,
    input         start,          // @posedge clk
    output        spi_clken,      // enable clock on spi_clk
    output        spi_cs,         // active low
    input         miso,           // input from the sensor
    output [15:0] dout,           // 16-bit data received,valid at dv and 15 cycles after
    output        dv,             // data valid strobe
    output        packet_done,    // packet received,
    output        packet_busy,    // packet busy (same as spi_clken, !spi_cs)
    output        crc_err,        // crc error, valid with packet_done
    output [15:0] id,             // packet ID (0x*f** - invlaid, if packet index = 20, 4 MSb - segment (- 0 invalid) 
    output        packet_invalid, // set early, valid with packet done
    output reg    id_stb          // id, packet invalid are set 
);
    reg  [ 6:0] wcntr;
    reg  [ 3:0] bcntr;
    wire        pre_lsb_w;
    reg         lsb_r;  // reading last bit from miso
    reg         copy_word; // copy 16-bit word from the SR (next after lsb_r); 
    reg  [15:0] d_r;
    
    reg  [1:0]  cs_r;
    wire        pre_last_w;
    reg  [ 2:0] packet_end;
    reg         set_id_r;
    reg         set_crc_r;
    reg         set_d_r;
    reg         den_r;
    reg   [1:0] packet_header = 2'b11;
    
    reg  [15:0] d_sr;
    reg  [ 1:0] start_r;
    reg         dv_r;
    reg  [15:0] crc_r; // required crc
    wire [15:0] crc_w; // current crc
    reg  [15:0] id_r;
    wire [15:0] dmask;
    reg         packet_invalid_r;
    
    assign packet_busy =    cs_r[0]; // clk_en_r;
    assign spi_clken =      cs_r[0]; // clk_en_r;
    assign spi_cs =         ~cs_r[0];
    assign pre_lsb_w =      bcntr == 4'he;
    assign pre_last_w =     pre_lsb_w && (wcntr == (VOSPI_PACKET_WORDS + 1));
    assign packet_done =    packet_end[2];
    assign id =             id_r;
//    assign dmask =          den_r ? 16'hffff: (wcntr[0]?16'h0: 16'h0fff);
    assign dmask =          packet_header[1] ? (packet_header[0] ? 16'h0fff: 16'h0) : 16'hffff ;
    
    assign crc_err =        packet_end[2] && (crc_r != crc_w);
    assign dv =             dv_r;
    assign dout =           d_r;
    assign packet_invalid = packet_invalid_r;
    
    always @ (posedge clk) begin
        if (rst || packet_end[0]) cs_r[0] <= 0;
        else if (start)           cs_r[0] <= 1;
        
        cs_r[1] <= cs_r[0];
        
        if (rst || !cs_r[0] || packet_end[0]) bcntr <= 0;
        else                                  bcntr <= bcntr + 1;
        
        if (rst || !cs_r[0] || packet_end[0]) lsb_r <= 0;
        else                                  lsb_r <= pre_lsb_w;
        
        copy_word <= !rst && lsb_r;
        
        if (rst || !cs_r[0] || packet_end[0]) wcntr <= 0;
        else if (lsb_r)                       wcntr <= wcntr + 1;
        
        if (rst || !cs_r[0] ) packet_end[1:0] <= 0;
        else                  packet_end[1:0] <= {packet_end[0], pre_last_w};

        if (rst)              packet_end[2] <= 0;
        else                  packet_end[2] <= packet_end[1];
        
        if (rst) start_r <= 0;
        else     start_r <= {start_r[0],start};
        
        set_id_r <=   !rst && (wcntr == 0) && lsb_r;
        set_crc_r <=  !rst && (wcntr == 1) && lsb_r;
        set_d_r <=    !rst && den_r &&        lsb_r;
        
        if (rst || !cs_r[1] || packet_done) den_r <= 0;
        else if (set_crc_r)                 den_r <= 1;
        
//        if (cs_r[0])         d_sr <=   {miso, d_sr[15:1]};  
        if (cs_r[0])         d_sr <=   {d_sr[14:0],miso};  
        if (set_id_r)        id_r <=   d_sr;
        if (set_crc_r)       crc_r <= d_sr;
        if (set_d_r)         d_r <=   d_sr;
        
        dv_r <=              set_d_r && !(packet_invalid_r && VOSPI_NO_INVALID);
        
        if (rst || start)    packet_invalid_r <= 0;
        else if (set_id_r)   packet_invalid_r <= (d_sr[11:8] == 4'hf);
        
        id_stb <= set_id_r;
        if (rst || start || packet_done) packet_header <= 2'b11;
        else if (copy_word)              packet_header <= {packet_header[0], 1'b0};
        
    end
    
    crc16_x16x12x5x0 crc16_x16x12x5x0_i (
        .clk    (clk),          // input
        .srst   (!cs_r[1]),     // input
        .en     (copy_word),    // input
        .din    (d_sr & dmask), // input[15:0] 
        .dout   (crc_w)         // output[15:0]
    );


endmodule

