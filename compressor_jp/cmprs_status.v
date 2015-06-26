/*******************************************************************************
 * Module: cmprs_status
 * Date:2015-06-25  
 * Author: andrey     
 * Description: Generate compressor status word
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * cmprs_status.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  cmprs_status.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  cmprs_status(
    input              mclk,         // system clock
    input              eof_written,
    input              stuffer_running,
    input              reading_frame,
    output   [2:0]     status
);

    reg                stuffer_running_r;
    reg                flushing_fifo;
    
    assign status = {flushing_fifo, stuffer_running_r, reading_frame};
    
    always @(posedge mclk) begin
        stuffer_running_r <= stuffer_running;
        
        if (stuffer_running_r && !stuffer_running) flushing_fifo <= 1;
        else if (eof_written)                      flushing_fifo <= 0;
    end


endmodule

