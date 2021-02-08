/*!
 * <b>Module:</b> boson_uart
 * @file boson_uart.v
 * @date 2020-12-12  
 * @author eyesis
 *     
 * @brief 921.6K8N1 UART to communicate with Boson
 *
 * @copyright Copyright (c) 2020 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 *
 * <b>License </b>
 *
 * boson_uart.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * boson_uart.v is distributed in the hope that it will be useful,
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
`include "system_defines.vh" // just for debugging histograms 

module  boson_uart #(
//    parameter BOSON_BAUD =  921600,
    parameter CLK_DIV =      217,
    parameter RX_DEBOUNCE =   60,
    parameter UART_STOP_BITS = 1 
    
)(
    input         mrst,         // @posedge mclk, sync reset
    input         mclk,         // global clock, half DDR3 clock, synchronizes all I/O through the command port
    output        txd,          // serial data out
    input         rxd,          // serial data in
    input   [7:0] tx_byte,      // transmit byte in
    input         tx_stb,       // transmit strobe for byte in
    output        tx_busy,      // transmit in progress
    output        tx_rdy,       // ready to accept tx_stb
    output  [7:0] rx_byte,      // received byte  
    output        rx_stb        // received data strobe (valid 1 cycle before and later for 1 bit) 
);
/*
`ifdef SIMULATION
    wire[7:0]debug_UART_CLK_DIV     = CLK_DIV; //  =                   22,
    wire[7:0]debug_UART_RX_DEBOUNCE = RX_DEBOUNCE; //                6,
`endif    
*/
    localparam CLK_DIV_BITS =       clogb2(CLK_DIV); //  + 1);
    localparam RX_DEBOUNCE_BITS =   clogb2(RX_DEBOUNCE + 1);
    reg     [CLK_DIV_BITS-1:0] clk_div_cntr_rx;
    reg     [CLK_DIV_BITS-1:0] clk_div_cntr_tx;
    reg [RX_DEBOUNCE_BITS-1:0] debounce_cntr;
    reg                        rxd_r;
    reg                  [9:0] rx_sr; // receive channel shift register, including start_stop
    reg                  [9:0] tx_sr; // transmit channel shift register, including start_stop
    reg                  [7:0] tx_r;  // transmit channel data input register
    reg                  [3:0] rx_bcntr; // read channel bit counter;
    reg                  [3:0] tx_bcntr; // read channel bit counter;
    reg                        rx_err;
    reg                        rx_bit;
    reg                  [1:0] tx_bit;
    reg                  [1:0] rx_stb_r;
    reg                        tx_busy_r;
    reg                        tx_rq;    // request to transmit
//    reg                        mrst_d;
    reg                        tx_start;
    reg                        tx_continue;
    wire                       debounced;
    wire                       rx_bitw;
    wire                       tx_bitw;
    wire                       mark;
    wire                       rx_errw;
    wire                       start_bit_rx;
    wire                       stop_bit_rx;
///    wire                       stop_bit_tx;
    wire                       stop_bit_last_tx;
    wire                       stop_bits_tx; // never used?
    wire                       tx_startw; // start next 10-bit transmission
    wire                       tx_continuew;
    assign debounced = (debounce_cntr == 0);
    assign rx_bitw =    (clk_div_cntr_rx == 0);
    assign tx_bitw =    (clk_div_cntr_tx == 0);
    assign mark =       &rx_sr & rxd_r; // all ones
    assign start_bit_rx = (rx_bcntr == 0);
    assign stop_bit_rx =  (rx_bcntr == 9);
///    assign stop_bit_tx =  (tx_bcntr == 9);
    assign stop_bit_last_tx =  (tx_bcntr == (8 + UART_STOP_BITS));
    assign stop_bits_tx =  tx_bcntr[3] && |tx_bcntr[2:0]; // >=9
///    assign rx_errw = rxd_r ? start_bit_rx : stop_bit_rx; // 1 at start, 0 at stop 
    assign rx_errw = !rxd_r && stop_bit_rx; // 0 at stop (start may be delayed) 
///    assign tx_startw =    tx_bit[0] && stop_bit_tx && tx_rq; 
///    assign tx_continuew = tx_bit[0] && !stop_bit_tx && tx_busy_r;

    assign tx_startw =    tx_bit[0] && stop_bit_last_tx && tx_rq; 
//    assign tx_continuew = tx_bit[0] && !stop_bits_tx && tx_busy_r; // verify
    assign tx_continuew = tx_bit[0] && !stop_bit_last_tx && tx_busy_r; // verify

    
    assign rx_byte = rx_sr[8:1];
    assign rx_stb =  rx_stb_r[1];
    assign tx_rdy =  !tx_rq;
    assign tx_busy = tx_busy_r || tx_rq; // !tx_rq;
    assign txd = tx_sr[0];
    
    always @(posedge mclk) begin
        if      (mrst)       rxd_r <= rxd;
        else if (debounced)  rxd_r <= rxd;
        
        if      (rxd_r == rxd) debounce_cntr <= RX_DEBOUNCE;
        else if (!debounced)   debounce_cntr <= debounce_cntr - 1;
        
        if      (mrst)         clk_div_cntr_rx <= CLK_DIV - 2;
        else if (rx_bit)       clk_div_cntr_rx <= CLK_DIV - 2;
        else if (debounced)    clk_div_cntr_rx <= (CLK_DIV >> 1); // half interval
        else                   clk_div_cntr_rx <= clk_div_cntr_rx - 1;
        
        rx_bit <= rx_bitw;
        
        if      (mrst)   rx_sr <= 10'h3ff; // inactive "1"
        else if (rx_bit) rx_sr <= {rxd_r,rx_sr[9:1]}; // little endian as RS232
        
        if      (mark || rx_err || (rx_bit && stop_bit_rx)) rx_bcntr <= 0;
///        else if (rx_bit)                                    rx_bcntr <= rx_bcntr + 1;
        // will wait at rx_bcntr == 0
        else if (rx_bit && (!start_bit_rx || !rxd_r))          rx_bcntr <= rx_bcntr + 1;
        
        if      (mark)              rx_err <= 0;
        else if (rx_bit && rx_errw) rx_err <= 1;
         
        rx_stb_r <= {rx_stb_r[0], stop_bit_rx & rx_bit}; 
    end
    // Transmit path
    always @(posedge mclk) begin
        if (tx_stb)          tx_r <= tx_byte; 
        
///        mrst_d <= mrst;
        tx_bit <= {tx_bit[0],tx_bitw};
        if      (mrst)       clk_div_cntr_tx <= CLK_DIV - 3;
        else if (tx_bit[1])  clk_div_cntr_tx <= CLK_DIV - 3;
        else                 clk_div_cntr_tx <= clk_div_cntr_tx - 1;
        
        if (mrst || !tx_busy) tx_sr <= 10'h3ff;
        else if (tx_start)    tx_sr <= {1'b1, tx_r, 1'b0};
        else if (tx_bit[1])   tx_sr <= {1'b1, tx_sr[9:1]};
        
        if      (mrst)                          tx_busy_r <= 0;
        else if (tx_start)                      tx_busy_r <= 1;
///        else if (tx_bit[1] && stop_bit_tx) tx_busy_r <= 0;
        else if (tx_bit[1] && stop_bit_last_tx) tx_busy_r <= 0;
        
        if      (mrst)        tx_rq <= 0;
        else if (tx_stb)      tx_rq <= 1; // 0;
        else if (tx_start)    tx_rq <= 0; // 1;
        
///        if (mrst || !tx_busy) tx_bcntr <= 9; // stop bit ? //UART_STOP_BITS
        if (mrst || !tx_busy) tx_bcntr <= 8 + UART_STOP_BITS;
        else if (tx_start)    tx_bcntr <= 0;
        else if (tx_continue) tx_bcntr <= tx_bcntr + 1;
        
        tx_start <= tx_startw;
        tx_continue <= tx_continuew;
        
    end
    
    
    function integer clogb2;
        input [31:0] value;
        begin
            value = value - 1;
            for (clogb2 = 0; value > 0; clogb2 = clogb2 + 1) begin // SuppressThisWarning VEditor - VDT bug
                value = value >> 1;
            end
        end
    endfunction
endmodule

