/*******************************************************************************
 * Module: mcont_to_chnbuf_reg
 * Date:2015-01-19  
 * Author: andrey     
 * Description: Registering data from memory controller to channel buffer
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * mcont_to_chnbuf_reg.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  mcont_to_chnbuf_reg.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  mcont_to_chnbuf_reg #(
parameter CHN_NUMBER=0
)(
    input rst,
    input clk,
    input                       ext_buf_wr,
    input                       ext_buf_wpage_nxt,
    input                 [3:0] ext_buf_wchn,     // 
    input                       ext_buf_wrefresh,
    input                       ext_buf_wrun,
    input                [63:0] ext_buf_wdata,    // valid with ext_buf_wr
    output reg                  buf_wr_chn,       // @ negedge mclk
    output reg                  buf_wpage_nxt_chn,// @ negedge mclk
    output reg                  buf_run,          // @ negedge mclk
    output reg           [63:0] buf_wdata_chn     // @ negedge mclk
);
    reg buf_chn_sel;
    always @ (posedge rst or negedge clk) begin
        if (rst) buf_chn_sel <= 0;
        else     buf_chn_sel <= (ext_buf_wchn==CHN_NUMBER) && !ext_buf_wrefresh;
        
        if (rst) buf_wr_chn <= 0;
        else     buf_wr_chn <= buf_chn_sel && ext_buf_wr;

        if (rst) buf_run <= 0;
        else     buf_run <= (ext_buf_wchn==CHN_NUMBER) && !ext_buf_wrefresh && ext_buf_wrun;
    end
    
    always @ (negedge clk)  begin
        buf_wpage_nxt_chn <= ext_buf_wpage_nxt && (ext_buf_wchn==CHN_NUMBER)  && !ext_buf_wrefresh;
    end
    
    always @ (negedge clk) if (buf_chn_sel && ext_buf_wr) begin
        buf_wdata_chn <= ext_buf_wdata;
    end
endmodule

