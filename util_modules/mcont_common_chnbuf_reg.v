/*******************************************************************************
 * Module: mcont_common_chnbuf_reg
 * Date:2015-01-19  
 * Author: andrey     
 * Description: Registering data from channel buffer to memory controller
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * mcont_common_chnbuf_reg.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  mcont_common_chnbuf_reg.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  mcont_common_chnbuf_reg #(
    parameter CHN_NUMBER=0
)(
    input rst,
    input clk,
    input                 [3:0] ext_buf_rchn,  // ==run_chn_d valid 1 cycle ahead opf ext_buf_rd!, maybe not needed - will be generated externally
    input                       ext_buf_rpage_nxt,
    input                       seq_done,      // sequence done
    output reg                  buf_done,      // sequence done for the specified channel
    output reg                  rpage_nxt
);
    reg                 buf_chn_sel;
    always @ (posedge rst or posedge clk) begin
        if (rst) buf_chn_sel <= 0;
        else     buf_chn_sel <= (ext_buf_rchn==CHN_NUMBER);
        
        if (rst) buf_done <= 0;
        else     buf_done <= buf_chn_sel && seq_done;
       
    end
    always @ (posedge clk)  rpage_nxt <= ext_buf_rpage_nxt && (ext_buf_rchn==CHN_NUMBER);
endmodule

