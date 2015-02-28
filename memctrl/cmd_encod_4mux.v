/*******************************************************************************
 * Module: cmd_encod_4mux
 * Date:2015-02-21  
 * Author: andrey     
 * Description: 4-to-1 mux to cmbine memory sequences sources
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * cmd_encod_4mux.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  cmd_encod_4mux.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  cmd_encod_4mux(
    input                   rst,
    input                   clk,

    input                   start0,       // this channel was started
    input            [31:0] enc_cmd0,     // encoded command
    input                   enc_wr0,      // write encoded command
    input                   enc_done0,     // encoding finished

    input                   start1,       // this channel was started
    input            [31:0] enc_cmd1,     // encoded command
    input                   enc_wr1,      // write encoded command
    input                   enc_done1,     // encoding finished

    input                   start2,       // this channel was started
    input            [31:0] enc_cmd2,     // encoded command
    input                   enc_wr2,      // write encoded command
    input                   enc_done2,     // encoding finished

    input                   start3,       // this channel was started
    input            [31:0] enc_cmd3,     // encoded command
    input                   enc_wr3,      // write encoded command
    input                   enc_done3,     // encoding finished

    output reg              start,       // combined output was started (1 clk from |start*)
    output reg       [31:0] enc_cmd,     // encoded command
    output reg              enc_wr,      // write encoded command
    output reg              enc_done     // encoding finished
);
    reg [3:0] select;
    wire start_w= start0 | start1 |start2 | start3;
    always @ (posedge rst or posedge clk) begin
        if (rst)       start <= 0;
        else           start <= start_w;
    
        if      (rst) select <= 0;
        else if (start_w) select <={ // normally should be no simultaneous starts, so priority is not needed
                            start3 & ~start2 & ~start1 & ~start0,
                            start2 & ~start1 & ~start0,
                            start1 & ~start0,
                            start0};
    end
    
    always @(posedge clk) begin
        enc_cmd <=  ({32{select[0]}} & enc_cmd0) |
                    ({32{select[1]}} & enc_cmd1) |
                    ({32{select[2]}} & enc_cmd2) |
                    ({32{select[3]}} & enc_cmd3);
                    
        enc_wr <=   (select[0] & enc_wr0) |
                    (select[1] & enc_wr1) |
                    (select[2] & enc_wr2) |
                    (select[3] & enc_wr3);
                    
        enc_done <= (select[0] & enc_done0) |
                    (select[1] & enc_done1) |
                    (select[2] & enc_done2) |
                    (select[3] & enc_done3);
    end

endmodule

