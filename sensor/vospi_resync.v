/*!
 * <b>Module:</b> vospi_resync
 * @file vospi_resync.v
 * @date 2019-04-24  
 * @author eyesis
 *     
 * @brief Resynchronize vospi packets by discard packets signature
 * First word starts with 0 bit, then 3 variable bits, then 0xfff
 * CRC word is also 0xffff. Then ? zero words, group of 5 variable words and
 * more zeros. 
 *
 * @copyright Copyright (c) 2019 Elphel, Inc.
 *
 * <b>License </b>
 *
 * vospi_resync.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * vospi_resync.v is distributed in the hope that it will be useful,
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

module  vospi_resync#(
    parameter VOSPI_PACKET_WORDS = 80,
    parameter VOSPI_RESYNC_ZEROS = 11 // number of 16-bit words of 0 to follow (14.6)
)(
    input         rst,
    input         clk,
    input         spi_clken,      // enable clock on spi_clk
    input         spi_cs,         // active low
    input         miso,           // input from the sensor
//    output        sync_end,       // last bit in a packet (turn off CS/spi_clken)
    output        will_sync,       // discard packet detected, sync_end will follow 
    output  [4:0] dbg_state
);
    wire clken = spi_clken && !spi_cs;
    
    reg     [4:0] state;
    reg     [4:0] count_ones;
    reg     [8:0] count_zeros;
    reg    [10:0] count_tail;
    
//    reg     [1:0] ending;
    
    wire    [4:0] state_set;
    wire    [4:0] state_reset;
    wire          set_ending;
    
    assign  will_sync =    state[4];
//    assign  sync_end =     ending[0];

    assign  set_ending =   state[4] && (count_tail == 0);
    assign  state_set[4] = state[3] && (count_zeros == 0) && !rst;
    assign  state_set[3] = state[2] && !miso && (count_ones[4:2] == 0)  && !rst;
    assign  state_set[2] = miso &&  (state[1] || (state[3] && (count_zeros != 0))) && !rst;
    assign  state_set[1] = !miso && (state[0] || (state[2] && (count_ones[4:2] != 0)) )  && !rst;
    assign  state_set[0] = rst ||
                           (state[2] && miso && (count_ones[4:0] == 0)) || // too many ones
                           set_ending;
/*    
    assign  state_reset = {state_set[0] |                               rst,   // state[4]
                           state_set[4] | state_set[2] |                rst,   // state[3]
                           state_set[3] | state_set[0] | state_set[1] | rst,   // state[2]
                           state_set[2] |                               rst,   // state[1] 
                           state_set[1]};
*/
    assign  state_reset = {|state_set[3:0] |                            rst,   // state[4]
                            state_set[4]   | |state_set[2:0] |          rst,   // state[3]
                           |state_set[4:3] | |state_set[1:0] |          rst,   // state[2]
                           |state_set[4:2] |  state_set[0] |            rst,   // state[1] 
                           |state_set[4:1]};
                           
    assign dbg_state = state;
    
    always @ (posedge clk) if (clken) begin
        if (state[2])  count_ones <= count_ones - 1;
        else           count_ones <= 5'h1e;

        if (state[3])  count_zeros <= count_zeros - 1;
        else           count_zeros <= (VOSPI_RESYNC_ZEROS << 4) - 2; // 14 for VOSPI_RESYNC_ZEROS==1

        if (state[4])  count_tail <= count_tail - 1;
        else           count_tail <= ((VOSPI_PACKET_WORDS - VOSPI_RESYNC_ZEROS) << 4) - 2; //
    
//        if (rst) ending <= 0;
//        else     ending <= {ending[0], set_ending};
        
//        if (rst) state <= 1;
//        else     state <= state_set | (state & ~state_reset);
        
    end
    always @ (posedge clk) begin
        if        (rst)   state <= 1;
        else  if (clken)  state <= state_set | (state & ~state_reset);
    
    end
    
    

endmodule

