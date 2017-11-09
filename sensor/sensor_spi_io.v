/*!
 * <b>Module:</b>sensor_spi_io
 * @file sensor_spi_io.v
 * @date 2017-05-17  
 * @author Raimundas Bastys
 *
 * @brief module to data in/out from/to CMV300 spi port, tested s6
 *
 * @copyright Copyright (c) 2017 Raimundas Bastys
 *
 * <b>License:</b>
 *
 * sensor_spi_io.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  sensor_spi_io.v is distributed in the hope that it will be useful,
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
//v0.0 working on s6lx4-3 10-40MHz clock with PCB CS01, not passing to datasheet CMV300 - extra clock to end spi enable period
//v0.1 change ODDR2(s6) to ODDR(zynq)
 
`timescale 1ns/1ps

module sensor_spi_io
(
input	clk0,				//clock 10-40MHz CMV300
input	reset,			//reset, active high
input	[6:0] addr,		//spi address
input	rd_en,			//read from sensor enable, one clock period input signal
input	wr_en,				//write to sensor enable, one clock period input signal
input	[7:0] wr_data,		//data to spi address be write
output reg [7:0] reg_data,	//data from spi address will read
output reg spi_ready,  //spi available for command
input	pin_spi_out,		//SPI interface pin: data out, direction from sensor to FPGA 
output reg pin_spi_in,		//SPI interface pin: data in, direction from FPGA to sensor 
output reg pin_spi_en,		//SPI interface pin: data enable, direction from FPGA to sensor 
output pin_spi_reset,	//SPI interface pin: data reset, direction from FPGA to sensor 
output pin_spi_clk		//SPI interface pin: data clock, direction from FPGA to sensor 
);

reg [7:0] sfst;
reg [3:0] sfst_ciklu;
reg [15:0] spi_word_rd;
reg [15:0] spi_word_wr;
reg read_bit;
reg [3:0] sfst_bits;
reg [7:0] sfst_byte;


assign pin_spi_reset = !reset;


`define S_FST_000 8'h00
`define S_FST_WR0 8'h01
`define S_FST_WR1 8'h02
`define S_FST_RD0 8'h03
`define S_FST_RD1 8'h04
`define S_FST_END 8'h05


always @ ( posedge clk0 ) begin 
if ( reset ) begin

	sfst <= `S_FST_000;
	pin_spi_en <= 1'b0;
	pin_spi_in <= 1'b0;
	sfst_ciklu[3:0] <= 4'hf;
	read_bit <= 1'b0;
	sfst_bits[3:0] <= 4'b0000;
	sfst_byte[7:0] <= 8'h00;
	reg_data[7:0] <= 8'h00;
	spi_ready <= 1'b1;

end else begin 

		case ( sfst )
			`S_FST_000 : begin
				pin_spi_en <= 1'b0;
				pin_spi_in <= 1'b0;
				sfst_ciklu[3:0] <= 4'hf;
				read_bit <= 1'b0;
                spi_word_rd[15:0] <= {1'b0, addr[6:0], 8'h00};
                spi_word_wr[15:0] <= {1'b1, addr[6:0], wr_data[7:0]};
				if (rd_en) begin
                    spi_ready <= 1'b0;
					sfst <= `S_FST_RD0;
					end
				if (wr_en) begin
                    spi_ready <= 1'b0;
					sfst <= `S_FST_WR0;
				end
			end
			`S_FST_RD0 : begin
				pin_spi_en <= 1'b0;
				pin_spi_in <= 1'b0;
				sfst_ciklu[3:0] <= 4'hf;
				read_bit <= 1'b0;
				sfst <= `S_FST_RD1;
			end
			`S_FST_RD1 : begin
				pin_spi_en <= 1'b1;
				read_bit <= 1'b0;
				pin_spi_in <= spi_word_rd[15];
				spi_word_rd[15:1] <= spi_word_rd[14:0];
				if ( sfst_ciklu[3:0] == 4'b0000) begin
					read_bit <= 1'b0;
					sfst <= `S_FST_END;
				end else if ( sfst_ciklu[3:0] == 4'h7) begin //begin read from CMV300
					read_bit <= 1'b1;
					sfst_ciklu[3:0] <= sfst_ciklu[3:0] -1 ;
					sfst <= `S_FST_RD1;
				end else begin
					read_bit <= 1'b0;
					sfst_ciklu[3:0] <= sfst_ciklu[3:0] -1 ;
					sfst <= `S_FST_RD1;
				end
			end
			`S_FST_WR0 : begin
				pin_spi_en <= 1'b0;
				pin_spi_in <= 1'b0;
				sfst_ciklu[3:0] <= 4'hf;
				sfst <= `S_FST_WR1;
			end
			`S_FST_WR1 : begin
				pin_spi_en <= 1'b1;
				pin_spi_in <= spi_word_wr[15];
				spi_word_wr[15:1] <= spi_word_wr[14:0];
				if ( sfst_ciklu[3:0] == 4'b0000) begin
					sfst <= `S_FST_END;
				end else begin
					sfst_ciklu[3:0] <= sfst_ciklu[3:0] -1 ;
					sfst <= `S_FST_WR1;
				end
			end
			`S_FST_END : begin
				pin_spi_in <= 1'b0;
				sfst_ciklu[3:0] <= 4'hf;
				read_bit <= 1'b0;
                spi_ready <= 1'b1;
				sfst <= `S_FST_000;
			end
		endcase

		if ( read_bit ) begin
			sfst_bits[3:0] <= 4'h7;
			sfst_byte[7:0] <= {sfst_byte[6:0], pin_spi_out};
		end

		if ( sfst_bits[3:0] == 4'h0 ) begin
			reg_data[7:0] <= sfst_byte[7:0];
		end else begin
			sfst_byte[7:0] <= {sfst_byte[6:0], pin_spi_out};
			sfst_bits[3:0] <= sfst_bits[3:0] - 1;
		end

end //if
end //always


ODDR #(
//	.DDR_ALIGNMENT("NONE"), // Sets output alignment to "NONE", "C0" or "C1"
    .DDR_CLK_EDGE("SAME_EDGE"), 
	.INIT(1'b0),    // Sets initial state of the Q output to 1'b0 or 1'b1
	.SRTYPE("SYNC") // Specifies "SYNC" or "ASYNC" set/reset
) ODDR2_sens (
	.Q(pin_spi_clk),   // 1-bit DDR output data
    .C(clk0),   // 1-bit clock input
//	.C0(clk0),   // 1-bit clock input
//	.C1(!clk0),   // 1-bit clock input
	.CE(1'b1), // 1-bit clock enable input
//	.D0(1'b0), // 1-bit data input (associated with C0)
//	.D1(1'b1), // 1-bit data input (associated with C1)
    .D1(1'b0), // 1-bit data input 
    .D2(1'b1), // 1-bit data input 
	.R(1'b0),   // 1-bit reset input
	.S(1'b0)    // 1-bit set input
);

endmodule // sensor_spi_io
