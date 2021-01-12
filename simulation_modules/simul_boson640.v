/*!
 * <b>Module:</b> simul_boson640
 * @file simul_boson640.v
 * @date 2020-12-23  
 * @author eyesis
 *     
 * @brief Simulating Boson640
 *
 * @copyright Copyright (c) 2020 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 *
 * <b>License </b>
 *
 * simul_boson640.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * simul_boson640.v is distributed in the hope that it will be useful,
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

module  simul_boson640#(
    parameter DATA_FILE =         "/input_data/pattern_160_120_16.dat",  //
    parameter WIDTH =             640, // overwrite with 160
    parameter HEIGHT =            513, // overwrite with 120
    parameter OUT_BITS =          16,
    parameter FPS =               60.0,  // actual fps of the internal generator
    parameter HSW =               8,    // horizontal sync width
    parameter FP_BP =             102,
    parameter FP =                52, // FP_BP = 52+50
    parameter VSW =               87 // with telemetry, in eows 
)(
    input         mrst,// active low
    input         single,
    input         ext_sync,
    output [15:0] pxd,
    output        pclk,
    output        dvalid,
    output        vsync,
    output        hsync,
    input         uart_in,
    output        uart_out // will just copy when not reset;
);
`ifndef ROOTPATH
    `include "IVERILOG_INCLUDE.v"// SuppressThisWarning VEditor - maybe not used
    `ifndef ROOTPATH
        `define ROOTPATH "."
    `endif
`endif
    localparam CLK_PER_FRAME = 450000;
    localparam CLK_PERIOD = 1000000000.0/ (FPS * CLK_PER_FRAME);  // ns
    localparam BP = FP_BP - FP;
    reg  [OUT_BITS-1:0] sensor_data[0 : WIDTH * HEIGHT - 1]; // SuppressThisWarning VEditor - Will be assigned by $readmem
    reg  [OUT_BITS-1:0] pxd_r;
    reg                 pclk_r = 0;
    reg           [1:0] frame_state; // 00 - reset, 01 vsync, 10 - out lines
//    reg           [1:0] frame_state_d; // previous state
    reg           [3:0] line_state;
    reg                 ext_sync_d;
    integer             pix_cntr;
    integer             line_cntr;
    integer             frame_pixel;
    wire                last_in_line;
    wire                start_frame;
    wire                start_line;
    wire                last_line;
    wire                pre_dav;
    reg                 dvalid_r;
    
    localparam FSTATE_IDLE =  2'b00;
    localparam FSTATE_VSYNC = 2'b01;
    localparam FSTATE_OUT =   2'b10;

    localparam LSTATE_IDLE =  4'b0000;
    localparam LSTATE_HS =    4'b0001;
    localparam LSTATE_FP =    4'b0010;
    localparam LSTATE_OUT =   4'b0100;
    localparam LSTATE_BP =    4'b1000;
                 
    assign pclk =          ~pclk_r;
    assign uart_out =      uart_in; //  && mrst;
    assign last_line =     (frame_state == FSTATE_OUT) && (line_cntr == 0);
    assign last_in_line =  (line_state == LSTATE_BP) &&  (pix_cntr == 0);
    assign start_frame =   ((frame_state == FSTATE_IDLE) || (last_line && last_in_line)) && (!single | (ext_sync && !ext_sync_d));
    assign start_line =    start_frame || ((frame_state != FSTATE_IDLE) && !last_line && last_in_line);
    assign pre_dav =       (frame_state == FSTATE_OUT) && ((pix_cntr == 0)? (line_state == LSTATE_FP) : (line_state == LSTATE_OUT));
    assign dvalid =        dvalid_r;
    assign pxd =           pxd_r;
    assign vsync =         frame_state != FSTATE_VSYNC; // active low
    assign hsync =         line_state !=  LSTATE_HS;    // active low
    initial begin
        $readmemh({`ROOTPATH,DATA_FILE},sensor_data);
    end

    always #(CLK_PERIOD/2) pclk_r <= mrst ? ~pclk_r : 1'b0;
    
    always @ (posedge pclk_r or negedge mrst) begin
        dvalid_r <= pre_dav && mrst;
    
        if (!mrst) ext_sync_d <= 0;
        else       ext_sync_d <= ext_sync;
        
//        frame_state_d <=frame_state;
        
        if (!mrst) begin
                    frame_state <= FSTATE_IDLE;
        end else begin
          case (frame_state)
           FSTATE_IDLE: begin
                    if (!single | (ext_sync && !ext_sync_d)) begin
                      frame_state <= FSTATE_VSYNC;
                      line_cntr <= VSW - 1;
                    end    
                  end
           FSTATE_VSYNC: if (last_in_line) begin
                    if (line_cntr == 0) begin
                      frame_state <= FSTATE_OUT;
                      line_cntr <=   HEIGHT - 1;
                    end else begin
                      line_cntr <= line_cntr - 1;
                    end  
                  end
           FSTATE_OUT: if (last_in_line) begin
                    if (line_cntr == 0) begin
                      frame_state <= (!single | (ext_sync && !ext_sync_d)) ? FSTATE_VSYNC : FSTATE_IDLE;
                      line_cntr <=   VSW - 1;
                    end else begin
                      line_cntr <= line_cntr - 1;
                    end  
                  end
           default: frame_state <= FSTATE_IDLE; 
          endcase
        end
        
        if (!mrst) begin
            line_state <= 0;
            pix_cntr <= HSW - 1;
        end else if (start_line) begin
            line_state <= LSTATE_HS;
            pix_cntr <= HSW - 1;
        end else begin
          case (line_state)
            LSTATE_HS: begin
                        if (pix_cntr == 0) begin
                          line_state <= LSTATE_FP;
                          pix_cntr <= FP - 1;
                        end else begin
                          pix_cntr <= pix_cntr -1;
                        end
                     end
            LSTATE_FP: begin
                        if (pix_cntr == 0) begin
                          line_state <= LSTATE_OUT;
                          pix_cntr <= WIDTH - 1;
                        end else begin
                          pix_cntr <= pix_cntr -1;
                        end
                     end
            LSTATE_OUT: begin
                        if (pix_cntr == 0) begin
                          line_state <= LSTATE_BP;
                          pix_cntr <= BP - 1;
                        end else begin
                          pix_cntr <= pix_cntr -1;
                        end
                     end
            LSTATE_BP: begin
                        if (pix_cntr == 0) begin
                          line_state <= LSTATE_IDLE;
                        end else begin
                          pix_cntr <= pix_cntr -1;
                        end
                     end
          default: line_state <= LSTATE_IDLE; 
          endcase
        end
        if (start_frame || !mrst)  frame_pixel <= 0;
        else if (pre_dav) frame_pixel <= frame_pixel + 1;
        
        if (pre_dav)      pxd_r <=       sensor_data[frame_pixel];
        
    end

endmodule

