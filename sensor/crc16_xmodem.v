/*!
 * <b>Module:</b> crc16_xmodem
 * @file crc16_xmodem.v
 * @date 2020-12-13  
 * @author eyesis
 *     
 * @brief Calculate and insert/verify crc16 (both receive and transmit)
 *
 * @copyright Copyright (c) 2020 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 *
 * <b>License </b>
 *
 * crc16_xmodem.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * crc16_xmodem.v is distributed in the hope that it will be useful,
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

module  crc16_xmodem#(
    parameter INITIAL_CRC16 = 16'h1d0f
)(
    input         mrst,         // @posedge mclk, sync reset
    input         mclk,         // global clock, half DDR3 clock, synchronizes all I/O through the command port
    // Transmit channel
    input         tx_start,     // initialize crc16 
    input   [7:0] txd_in,       // transmit payload
    input         tx_in_stb,    // strobe for the txd_in
    input         tx_over,      // payload data ended, should output crc16 (should be after the last tx_in_stb)
    input         tx_rdy,       // stuffer is ready to accept next byte
    output        tx_in_rdy,    // module ready to accept next byte    
    output  [7:0] txd_out,      // delayed txt_in, followed by the CRC16
    output        tx_out_stb,   // load txd_out to stuffer
    output        tx_busy       // does not include destuffer and uart
    // implementing only transmit CRC16 as response is only needed for non-sequencer operation
    /*
    // receive channel
    ,input         rx_start,
    input   [7:0] rxd_in,       // byte input from stuffer
    input         rx_in_stb,    // next byte from destuffer in rxd_in
    input         rx_over,      // no more data from destuffer (last 2 bytes were crc16: msb, lsb)
    output  [7:0] rxd_out,      // received chn, payload and crc data
    output        rx_out_stb,   // received data output strobe
    output        rx_busy,      // received channel busy
    output        rx_crc_good   // valid with !rx_busy
    */
  );
    reg   [7:0] txd_in_r;        
    reg         tx_busy_r;
    reg         tx_stb_crc_m;
    reg         tx_stb_crc_l;
    reg         tx_stb_crc_l2; // next cycle after tx_stb_crc_l, same as last tx_out_stb
    reg  [15:0] tx_crc16_r;
    reg   [3:0] tx_crc16_s;   
    reg   [7:0] crc16_addr;
    reg   [7:0] txd_out_r;
    reg         tx_pre_crc;
    reg   [1:0] tx_crc_out;
    reg   [1:0] tx_crc_out_d;
    reg         tx_in_rdy_r;
    reg         tx_dav_r;
    reg         tx_out_stb_r;
    reg         tx_out_stb_r2;
    reg         tx_gen_bsy;
    

    wire        tx_crc16_next; // calculate next CRC16
    wire [15:0] crc16_table; // valid at tx_crc16_s[3]
    wire [15:0] tx_crc16_w;
    
    
    assign tx_crc16_next =tx_crc16_s[3];
    assign tx_crc16_w = {tx_crc16_r[7:0] ^ crc16_table[15:8], crc16_table[7:0]}; 
    
    assign tx_busy = tx_busy_r;
    assign txd_out = txd_out_r;
    assign tx_in_rdy = tx_in_rdy_r;
    assign tx_out_stb = tx_out_stb_r;
    
    always @(posedge mclk) begin
        if      (mrst)                      tx_in_rdy_r <= 0;
        else if (tx_start || tx_crc16_s[0]) tx_in_rdy_r <= 1; // tx_crc16_next
        else if (tx_in_stb || tx_over)      tx_in_rdy_r <= 0;
        
        if      (mrst)         tx_gen_bsy <= 0;
        else if (tx_in_stb)    tx_gen_bsy <= 1;
        else if (tx_out_stb_r) tx_gen_bsy <= 0; 
        
        
        if      (mrst)     tx_pre_crc <= 0;
        else if (tx_start) tx_pre_crc <= 0;
        else if (tx_over)  tx_pre_crc <= 1; 
        
        if      (mrst)                          tx_crc_out[0] <= 0;
        else if (tx_start)                      tx_crc_out[0] <= 0;
        else if (tx_pre_crc && !tx_gen_bsy)     tx_crc_out[0] <= 1;

        if      (mrst)                          tx_crc_out[1] <= 0;
        else if (tx_start)                      tx_crc_out[1] <= 0;
        else if (tx_crc_out[0] && tx_out_stb_r) tx_crc_out <= 2'h1;
        
        tx_crc_out_d <= tx_crc_out;
        
        if      (mrst)                                          tx_dav_r <= 0;
        else if (tx_out_stb_r)                                  tx_dav_r <= 0;
        else if (tx_crc16_next || tx_stb_crc_m || tx_stb_crc_l) tx_dav_r <= 1;

        tx_out_stb_r <= !tx_out_stb_r && !tx_out_stb_r2 && tx_dav_r && tx_rdy;
        tx_out_stb_r2 <= tx_out_stb_r;
        
        tx_stb_crc_m <= tx_crc_out[0] && !tx_crc_out[1] && !tx_crc_out_d[0]; // tx_crc_out[0] just 0->1
        tx_stb_crc_l <= tx_crc_out[1] && !tx_crc_out_d[1]; // tx_crc_out[1] just 0->1
        
        if      (tx_crc16_next) txd_out_r <= txd_in_r;
        else if (tx_stb_crc_m)  txd_out_r <= tx_crc16_r[15:8];
        else if (tx_stb_crc_l)  txd_out_r <= tx_crc16_r[ 7:0];
    
        if  (mrst) tx_crc16_s <= 0;
        else       tx_crc16_s <= {tx_crc16_s[2:0],tx_in_stb};
        
        if (tx_crc16_s[0]) crc16_addr <= tx_crc16_r[15:8] ^ txd_in_r;
    
        if (tx_in_stb) txd_in_r <= txd_in;
        
        tx_stb_crc_l2 <= tx_stb_crc_l;
        
        if      (mrst)          tx_busy_r <= 0;
        else if (tx_start)      tx_busy_r <= 1;
        else if (tx_stb_crc_l2) tx_busy_r <= 0;
        
        if      (tx_start)      tx_crc16_r <= INITIAL_CRC16;
        else if (tx_crc16_next) tx_crc16_r <= tx_crc16_w; 
    end    
    
    
    ram18_var_w_var_r #(
        .REGISTERS    (1),
        .LOG2WIDTH_WR (4),
        .LOG2WIDTH_RD (4),
        .DUMMY        (0)
`ifdef PRELOAD_BRAMS        
        , .INIT_00 (256'hF1EFE1CED1ADC18CB16BA14A9129810870E760C650A540843063204210210000)
        , .INIT_01 (256'hE3DEF3FFC39CD3BDA35AB37B8318933962D672F7429452B52252327302101231)
        , .INIT_02 (256'hD58DC5ACF5CFE5EE95098528B54BA56A548544A474C764E61401042034432462)
        , .INIT_03 (256'hC7BCD79DE7FEF7DF87389719A77AB75B46B4569566F676D70630161126723653)
        , .INIT_04 (256'hB92BA90A99698948F9AFE98ED9EDC9CC382328021861084078A7688658E548C4)
        , .INIT_05 (256'hAB1ABB3B8B589B79EB9EFBBFCBDCDBFD2A123A330A501A716A967AB74AD45AF5)
        , .INIT_06 (256'h9D498D68BD0BAD2ADDCDCDECFD8FEDAE1C410C603C032C225CC54CE47C876CA6)
        , .INIT_07 (256'h8F789F59AF3ABF1BCFFCDFDDEFBEFF9F0E701E512E323E134EF45ED56EB67E97)
        , .INIT_08 (256'h606770464025500420E330C200A11080E16FF14EC12DD10CA1EBB1CA81A99188)
        , .INIT_09 (256'h725662775214423532D222F3129002B1F35EE37FD31CC33DB3DAA3FB939883B9)
        , .INIT_0A (256'h4405542464477466048114A024C334E2C50DD52CE54FF56E858995A8A5CBB5EA)
        , .INIT_0B (256'h563446157676665716B0069136F226D3D73CC71DF77EE75F97B88799B7FAA7DB)
        , .INIT_0C (256'h28A3388208E118C06827780648655844A9ABB98A89E999C8E92FF90EC96DD94C)
        , .INIT_0D (256'h3A922AB31AD00AF17A166A375A544A75BB9AABBB9BD88BF9FB1EEB3FDB5CCB7D)
        , .INIT_0E (256'h0CC11CE02C833CA24C455C646C077C268DC99DE8AD8BBDAACD4DDD6CED0FFD2E)
        , .INIT_0F (256'h1EF00ED13EB22E935E744E557E366E179FF88FD9BFBAAF9BDF7CCF5DFF3EEF1F)
`endif
    ) i_crc16 (
        .rclk         (mclk),                         // input
        .raddr        ({2'b0, crc16_addr[7:0]}),      // input[8:0] 
        .ren          (tx_crc16_s[1]),                // input
        .regen        (tx_crc16_s[2]),                // input
        .data_out     (crc16_table[15:0]),            // output[15:0] 
        .wclk         (1'b0),                         // input
        .waddr        (10'b0),                        // input[8:0] 
        .we           (1'b0),                         // input
        .web          (4'b0),                         // input[3:0] 
        .data_in      (16'b0)                         // input[15:0] 
    );
         


endmodule

