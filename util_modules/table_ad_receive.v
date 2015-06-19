/*******************************************************************************
 * Module: table_ad_receive
 * Date:2015-06-18  
 * Author: andrey     
 * Description: Receive tabble address/data sent by table_ad_transmit
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * table_ad_receive.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  table_ad_receive.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  table_ad_receive #(
    parameter MODE_16_BITS = 1,
    parameter NUM_CHN = 1
)(
    input                          clk,        // posedge mclk
    input                          a_not_d,    // receiving adderass / not data - valid during all bytes
    input                    [7:0] ser_d,      // byte-wide address/data
    input            [NUM_CHN-1:0] dv,         // data valid - active for each address or data bytes
    output     [23-MODE_16_BITS:0] ta,         // table address
    output [(MODE_16_BITS?15:7):0] td,         // 8/16 bit table data
    output           [NUM_CHN-1:0] twe         // table write enable
);
    reg                  [23:0] addr_r;
    reg           [NUM_CHN-1:0] twe_r;
    reg [(MODE_16_BITS?15:7):0] td_r;
    
    assign td =  td_r;
    assign ta =  MODE_16_BITS ? addr_r[23:1] : addr_r[23:0];
//    assign twe = twe_r && (MODE_16_BITS ? addr_r[0]: 1'b1);
    assign twe = (MODE_16_BITS ? addr_r[0]: 1'b1)? twe_r : {NUM_CHN{1'b0}} ;
    
    always @(posedge clk) begin
//        twe_r <= en && !a_not_d;
        twe_r <= a_not_d ? 0 : dv;
        if ((|dv) && a_not_d)  addr_r[23:0] <= {ser_d,addr_r[23:8]};
        else if (|twe_r)       addr_r[23:0] <= addr_r[23:0] + 1;
    end
    generate
        if (MODE_16_BITS) always @ (posedge clk) td_r[15:0] <= {ser_d[7:0],td_r[15:8]};
        else              always @ (posedge clk) td_r[ 7:0] <= ser_d[7:0];
    endgenerate

endmodule

