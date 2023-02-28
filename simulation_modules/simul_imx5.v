/*!
 * <b>Module:</b> simul_imx5
 * @file simul_imx5.v
 * @date 2022-02-08  
 * @author Andrey Filippov
 *     
 * @brief Simulating Inertial Sense IMX5 binary protocol
 *
 * @copyright Copyright (c) 2022 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 *
 * <b>License </b>
 *
 * simul_imx5.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * simul_imx5.v is distributed in the hope that it will be useful,
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

module  simul_imx5#(
    parameter DATA_FILE =         "/input_data/imx5_did_ins_1.dat",  //
    parameter BIT_DURATION =      160, // ns
    parameter RECORD_BYTES =       80, // bytes per record
    parameter RECORD_NUM =         10, // number of records
    parameter PAUSE_CLOCKS =      100  // skip clocks between messages
)(
    input         mrst,     // active low
    output        uart_out, // will just copy when not reset;
    output        sending,   // sending data (excluding start/stop bits)
    output        escape
);
localparam PACKET_ID =        8'h4; // DATA packet
localparam PACKET_COUNTER  =  8'h0;
localparam PACKET_FLAGS =     8'h13; // CM_PKT_FLAGS_LITTLE_ENDIAN = 0x01, CM_PKT_FLAGS_CHECKSUM_24_BIT = 0x10, CM_PKT_FLAGS_RX_VALID_DATA = 0x02
localparam DATA_SET_ID =     32'h4; //  DID_INS_1
localparam DATA_OFFSET =     32'h0;
localparam DATA_SIZE =        RECORD_BYTES * RECORD_NUM;
`ifndef ROOTPATH
    `include "IVERILOG_INCLUDE.v"// SuppressThisWarning VEditor - maybe not used
    `ifndef ROOTPATH
        `define ROOTPATH "."
    `endif
`endif
    reg                 clk_r = 0;
    reg  [7:0]          records[0 : DATA_SIZE - 1]; // SuppressThisWarning VEditor - Will be assigned by $readmem
    reg                 IMX_SENDING = 0;
    reg                 IMX_BIT =     1;
    reg                 ESCAPE =      0;
    reg  [7:0]          packet_counter;
    reg  [7:0]          dbyte;
    integer             nrec = 0;
    integer             byte_pointer;
    integer             shifter;
    integer             num_byte;
    reg [23:0]          checkSumValue = 24'haaaaaa;
    reg [95:0]          header; 
    
    assign uart_out =   IMX_BIT;
    assign sending =    IMX_SENDING;
    assign escape =     ESCAPE;
    initial begin
        $readmemh({`ROOTPATH,DATA_FILE},records);
        header[31: 0] <=  DATA_SET_ID;
        header[63:32] <=  RECORD_BYTES;
        header[95:64] <=  DATA_OFFSET;
        packet_counter <= PACKET_COUNTER;
    end

    always #(BIT_DURATION/2) clk_r <= mrst ? 1'b0 : ~clk_r;

    always @ (negedge mrst) begin
      wait (clk_r); wait (~clk_r); 
      for (nrec = 0; nrec < RECORD_NUM; nrec = nrec + 1) begin
        checkSumValue = 24'haaaaaa;
        send_imx_byte('hff); // start (not escaped)       // byte 0
        dbyte = PACKET_ID;
        send_imx_escaped_byte(dbyte); // pid              // byte 1
        checkSumValue[ 7: 0] = checkSumValue[ 7: 0] ^ dbyte;

        dbyte = packet_counter;
        send_imx_escaped_byte(dbyte); // counter         // byte 2 
        
        checkSumValue[15: 8] = checkSumValue[15: 8] ^ dbyte;

        dbyte = PACKET_FLAGS;
        send_imx_escaped_byte(dbyte); // packet flags    // byte 3
        checkSumValue[23:16] = checkSumValue[23:16] ^ dbyte;
            
//        send_imx_escaped_byte(PACKET_COUNTER); // counter
        
        // send header
        byte_pointer  = 0;
        shifter =       0;
        for (byte_pointer = 0; byte_pointer < $bits(header); byte_pointer = byte_pointer + 8) begin
//        for (byte_pointer = 0; byte_pointer < RECORD_BYTES; byte_pointer = byte_pointer + 1) begin
          dbyte = header[byte_pointer +: 8];
          send_imx_escaped_byte(dbyte);      //
          checkSumValue[shifter +: 8] = checkSumValue[shifter +: 8] ^ dbyte;
          if (shifter > 8) shifter = 0;
          else             shifter = shifter + 8;
        end
        // send data
        byte_pointer  = RECORD_BYTES * nrec;
        for (num_byte = 0; num_byte < RECORD_BYTES; num_byte = num_byte + 1) begin
          dbyte = records[byte_pointer];
          byte_pointer = byte_pointer + 1;
          send_imx_escaped_byte(dbyte);      //
          checkSumValue[shifter +: 8] = checkSumValue[shifter +: 8] ^ dbyte;
          if (shifter > 8) shifter = 0;
          else             shifter = shifter + 8;
        end
        // send checksum
        send_imx_escaped_byte(checkSumValue[16 +: 8]);
        send_imx_escaped_byte(checkSumValue[ 8 +: 8]);
        send_imx_escaped_byte(checkSumValue[ 0 +: 8]);
        send_imx_byte('hfe); // stop (not escaped)
        if (packet_counter & 1) begin // merge two packets without pause
            repeat (PAUSE_CLOCKS) begin // make a pause between records
              wait (clk_r); wait (~clk_r);
            end
        end
        packet_counter = packet_counter + 1;
      end
    end

    task send_imx_escaped_byte;
      input [ 7:0] data_byte;
      begin
        if ((data_byte == 8'h0a) ||
            (data_byte == 8'h24) ||
            (data_byte == 8'hb5) ||
            (data_byte == 8'hd3) ||
            (data_byte == 8'hfd) ||
            (data_byte == 8'hfe) ||
            (data_byte == 8'hff)) begin
            ESCAPE = 1;
            send_imx_byte(8'hfd);      // escape
            send_imx_byte(~data_byte); // invertedbyte
            ESCAPE = 0;
        end else begin
            send_imx_byte(data_byte);
        end   
      end
    
    endtask  

// 0x0A , 0x24 , 0xB5 , 0xD3 , 0xFD , 0xFE and 0xFF
    task send_imx_byte;
      input [ 7:0] data_byte;
      reg   [ 9:0] d;
      integer      i; 
      begin
//        IMX_SENDING  = 1;
        d  = {1'b1, data_byte, 1'b0}; // includes start (0) and stop (1) bits
    // SERIAL_BIT should be 1 here
        // Send START (8), 8 data bits, LSB first, STOP(1)    
//        repeat (10) begin
        for (i = 0; i < 10; i = i+1) begin
          if      (i == 1) IMX_SENDING  = 1;
          else if (i == 9) IMX_SENDING  = 0;
          IMX_BIT  = d[0];
          #1 d[9:0]  = {1'b0,d[9:1]};
          wait (clk_r); wait (~clk_r); 
        end
        IMX_SENDING  = 0;
      end
    endtask  

endmodule

