/*!
 * <b>Module:</b> serial_103993_extif
 * @file serial_103993_extif.v
 * @date 2020-12-19  
 * @author eyesis
 *     
 * @brief convert sequencer data to 103993 serial packet data
 *
 * @copyright Copyright (c) 2020 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 *
 * <b>License </b>
 *
 * serial_103993_extif.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * serial_103993_extif.v is distributed in the hope that it will be useful,
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

module  serial_103993_extif #(
    parameter EXTIF_MODE =                 1 // 1,2 or 3 if there are several different extif
)(
    input                      mclk,
    input                      mrst,
    // sequencer interface 
    // sequencer always provides 4 payload bytes (5 total)
    // interface for uart in write-only mode for short commands
    // 1-st byte - SA (use 2 LSB to select 0,1,2 data bytes
    // 2-nd byte module
    // 3-rd byte function
    // 4 (optional) data[15:8] or data[7:0] if last
    // 5 (optional) data[7:0] 
    input                      extif_en,   // enable receiving new packet data
    input                      extif_dav,  // data byte available for external interface 
//    input                      extif_last, // last byte for  external interface (with extif_dav)
    input                [1:0] extif_sel,  // interface type (0 - internal, 1 - uart, 2,3 - reserved)
    input                [7:0] extif_byte, // data to external interface (first - extif_sa)
    output                     extif_ready, // acknowledges extif_dav
    input                      extif_rst,   // reset seq xmit and sequence number
    output                     packet_ready,// packet ready, later next packet byte ready
    output               [7:0] packet_byte,
    input                      packet_byte_stb, // packet byte read out - should be >2(?) cycles apart
//    output                     packet_byte_rdy, // packet byte ready
    output                     packet_over,     
    input                      packet_sent  

);
    reg    [3:0] packet_mode; // 1 - zero bytes, 2 - 1 byte, 4 - 2 bytes, 8 - 4 bytes
    reg          packet_nempty_r; // ~ready to receive packet
//    reg          packet_ready_r;
    reg    [2:0] in_bytes; 
//    reg          packet_in;    // receiving packet bytes (after mode)
    reg          extif_ready_r;
    
    reg    [7:0] payload_ram [0:3]; // module (1 byte), function (1 byte) , data[15:8], data[7:0]
    wire         recv_start; // receive first byte - mode
    wire         recv_next;  // receive next byte
    wire         reset_in_bytes; 
    reg   [17:0] packet_gen_state;
    reg          inc_ra;
    reg    [1:0] ra;
    reg    [7:0] payload_r; // registered payload byte
    reg          use_mem; // output payload from memory
    reg          use_ff;  // 0xff byte
    reg   [15:0] seq_num; // 16-bit sequence number
    reg    [7:0] packet_byte_r;
    reg    [1:0] packet_byte_stb_d;
    

    assign packet_ready =   in_bytes[2] && !packet_byte_stb_d[0] && !packet_byte_stb_d[1]; //
    assign recv_start =    !packet_nempty_r && extif_en && extif_dav && (extif_sel == EXTIF_MODE) && extif_ready_r;
    assign recv_next =      packet_nempty_r && extif_dav && !extif_ready_r;
    assign reset_in_bytes = mrst || extif_rst || !packet_nempty_r;
    assign packet_byte =    packet_byte_r;
    assign extif_ready =    extif_ready_r;
    assign packet_over =    packet_gen_state[17];
    
    always @(posedge mclk) begin
        if (mrst || extif_rst) packet_byte_stb_d <= 0;
        else packet_byte_stb_d <= {packet_byte_stb_d[0], packet_byte_stb};
    
        if (mrst || extif_rst || !extif_dav) extif_ready_r <= 0;
        else if (recv_start || recv_next)    extif_ready_r <= 1;
        

        if (mrst || extif_rst) packet_nempty_r <= 0;
        else if (recv_start)   packet_nempty_r <= 1;
        else if (packet_sent)  packet_nempty_r <= 0;
        
        if (recv_start) packet_mode <= {
            extif_byte[1] &   extif_byte[0], // 3 - 4 bytes
            extif_byte[1] &  ~extif_byte[0], // 2 - 2 bytes
            ~extif_byte[1] &  extif_byte[0], // 1 - 1 byte
            ~extif_byte[1] & ~extif_byte[0]};// 0 - 0 bytes
        
        
//        if (reset_in_bytes) packet_in <= 0;
        
        if (reset_in_bytes) in_bytes <= 0;
        else if (recv_next) in_bytes <= in_bytes + 1;
        
        if (recv_next) payload_ram[in_bytes] <= extif_byte;
        payload_r <=   payload_ram[ra];
        
        // Generating  packet
        
        if (!in_bytes[2]) packet_gen_state <= 1;
        else if (packet_byte_stb) packet_gen_state <= {
            (packet_gen_state[12] & packet_mode[0]) | packet_gen_state[16], // 17
            (packet_gen_state[12] & packet_mode[1]) | packet_gen_state[15], // 16
            (packet_gen_state[12] & packet_mode[2]) | packet_gen_state[14], // 15
            packet_gen_state[13],                                           // 14
            packet_gen_state[12] & packet_mode[3],                          // 13
            packet_gen_state[11:0],                                         // 1..12
            1'b0};                                                          // 0 
        inc_ra <=  packet_byte_stb & (
            packet_gen_state[6] | packet_gen_state[8]  | packet_gen_state[15] | ( | packet_gen_state[9] & packet_mode[1]));
            
        if (!in_bytes[2]) ra <= 0;
        else if (inc_ra)  ra <= ra + 1;
        
        if (mrst || extif_rst) seq_num <= 0;
        else if (packet_sent)  seq_num <= seq_num + 1;

        use_mem <= packet_gen_state[6] | packet_gen_state[8] | packet_gen_state[15] | packet_gen_state[16];
        use_ff <=  packet_gen_state[9] | packet_gen_state[10] | packet_gen_state[11] | packet_gen_state[12];
        
        packet_byte_r <= (
            {8{use_mem}} & payload_r) |
            {8{use_ff}} |
            ({8{packet_gen_state[3]}} & seq_num[15:8]) |
            ({8{packet_gen_state[4]}} & seq_num[ 7:0]);
        
    end

/*
    reg    [7:0] payload_r; // registered payload byte
    reg          use_mem; // output payload from memory
    reg          use_ff;  // 0xff byte
    reg   [15:0] seq_num; // 16-bit sequence number


    reg          use_mem;
    reg          use_ff;

    fifo_same_clock #(
        .DATA_WIDTH(8),
        .DATA_DEPTH(4)
    ) fifo_same_clock_i2c_rdata_i (
        .rst        (1'b0),              // input
        .clk        (mclk),              // input
        .sync_rst   (mrst | extif_rst),  // input
        .we         (i2c_rvalid),      // input
        .re         (i2c_fifo_rd),     // input
        .data_in    (i2c_rdata),       // input[15:0] 
        .data_out   (i2c_fifo_dout),   // output[15:0] 
        .nempty     (i2c_fifo_nempty), // output
        .half_full  () // output reg 
    );
*/   



endmodule

