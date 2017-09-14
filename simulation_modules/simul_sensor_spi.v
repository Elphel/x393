/*!
 * <b>Module:</b> simul_sensor_spi
 * @file simul_sensor_spi.v
 * @date 2017-09-04  
 * @author Raimundas Bastys
 *     
 * @brief Generate spi sensor data
 *
 * @copyright Copyright (c) 2017 Raimundas Bastys
 *
 * <b>License </b>
 *
 * simul_sensor_spi.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * simul_sensor_spi.v is distributed in the hope that it will be useful,
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

module  simul_sensor_spi # (
parameter SENSOR_IMAGE_TYPE =        "NORM", 
parameter SENSOR_TYPE =        "CMV300", 
parameter tSPI   =       4   //time data from clock rise front
) (
output pin_spi_out,        //SPI interface pin: data out, direction from sensor to FPGA 
input   pin_spi_in,      //SPI interface pin: data in, direction from FPGA to sensor 
input   pin_spi_en,      //SPI interface pin: data enable, direction from FPGA to sensor 
input   pin_spi_reset,   //SPI interface pin: data reset, direction from FPGA to sensor 
input   pin_spi_clk      //SPI interface pin: data clock, direction from FPGA to sensor 
);

reg   [15:0]   sensor_data[0:4095]; // up to 64 x 64 pixels // SuppressThisWarning VEditor - Will be assigned by $readmem
reg   [7:0]   sensor_spi_reg[0:127]; // sensor SPI registers
reg   spi_out;
wire    clk;
wire    reset;  //active high
reg [7:0] sfst;
reg [6:0] reg_addr;
reg [2:0] ciklu_addr;
reg [7:0] reg_wr;

assign  pin_spi_out=spi_out;
assign  clk = pin_spi_clk;
assign  reset = !pin_spi_reset || !pin_spi_en;

`ifndef ROOTPATH
    `include "IVERILOG_INCLUDE.v"// SuppressThisWarning VEditor - maybe not used
    `ifndef ROOTPATH
        `define ROOTPATH "."
    `endif
`endif

initial begin

   $display ("sensor parameters");
   $display ("    -- sensor = %s",SENSOR_TYPE);
   $display ("    -- image type = %s",SENSOR_IMAGE_TYPE);

    if      (SENSOR_IMAGE_TYPE == "NORM")      $readmemh({`ROOTPATH,"/input_data/sensor.dat"},sensor_data);
    else if (SENSOR_IMAGE_TYPE == "RUN1")      $readmemh({`ROOTPATH,"/input_data/sensor_run1.dat"},sensor_data);
    else begin
       $display ("WARNING: Unrecognized sensor image :'%s', using default 'NORM': input_data/sensor.dat",SENSOR_IMAGE_TYPE);
       $readmemh({`ROOTPATH,"/input_data/sensor.dat"},sensor_data);
    end
    if      (SENSOR_TYPE == "CMV300")      $readmemh({`ROOTPATH,"/input_data/sensor_spi_reg.dat"},sensor_spi_reg);
    else begin
       $display ("WARNING: Unrecognized sensor :'%s', using default 'CMV300': input_data/sensor_spi_reg.dat",SENSOR_TYPE);
       $readmemh({`ROOTPATH,"/input_data/sensor_spi_reg.dat"},sensor_spi_reg);
    end

end

`define S_FST_00000 8'h00
`define S_FST_WR_A0 8'h01
`define S_FST_WR_D0 8'h02
`define S_FST_RD_A0 8'h03
`define S_FST_RD_D0 8'h04

always @ ( posedge clk or posedge reset ) begin 
if ( reset ) begin
    sfst <= `S_FST_00000;
    reg_addr[6:0] <= 0;
    ciklu_addr[2:0] <= 3'b110;
    reg_wr <= 0;
end else begin 


    case ( sfst )
        `S_FST_00000 : begin
            ciklu_addr[2:0] <= 3'b110; //6 addr bit
            if (pin_spi_in)
                sfst <= `S_FST_WR_A0;
            else
                sfst <= `S_FST_RD_A0;
        end
        `S_FST_RD_A0 : begin
            reg_addr[ciklu_addr] <= pin_spi_in;
            if ( ciklu_addr[2:0] == 3'b000) begin
                ciklu_addr[2:0] <= 3'b111; //7 data bit
                sfst <= `S_FST_RD_D0;
            end else
                ciklu_addr[2:0] <= ciklu_addr[2:0] - 1;
        end
        `S_FST_RD_D0 : begin
//           #tSPI spi_out <= sensor_spi_reg[reg_addr[6:0]][ciklu_addr[2:0]];
            if ( ciklu_addr[2:0] == 3'b000)
                sfst <= `S_FST_00000;
            else
                ciklu_addr[2:0] <= ciklu_addr[2:0] - 1;
        end
        `S_FST_WR_A0 : begin
            reg_addr[ciklu_addr] <= pin_spi_in;
            if ( ciklu_addr[2:0] == 3'b000) begin
                ciklu_addr[2:0] <= 3'b111;//6 data bit
                sfst <= `S_FST_WR_D0;
            end else
                ciklu_addr[2:0] <= ciklu_addr[2:0] - 1;
        end
        `S_FST_WR_D0 : begin
            reg_wr[ciklu_addr[2:0]] <= pin_spi_in;
            if ( ciklu_addr[2:0] == 3'b000) begin
                sensor_spi_reg[reg_addr[6:0]][7:0] <= {pin_spi_in, reg_wr[6:0]};
                sfst <= `S_FST_00000;
            end else
                ciklu_addr[2:0] <= ciklu_addr[2:0] - 1;
        end
    endcase
        
end //if
end //always

always @ ( negedge clk or posedge reset ) begin
if ( reset ) begin
    spi_out <= 1'b0;
end else begin 


    case ( sfst )
        `S_FST_RD_D0 : begin
            spi_out <= sensor_spi_reg[reg_addr[6:0]][ciklu_addr[2:0]];
        end
    endcase
        
end //if
end //always

endmodule

