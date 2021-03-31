/*!
 * <b>Module:</b> deglitch
 * @file deglitch.v
 * @date 2021-03-24  
 * @author Andrey Filippov
 *     
 * @brief Deglitch signal
 *
 * @copyright Copyright (c) 2021
 *
 * <b>License </b>
 *
 * deglitch.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * deglitch.v is distributed in the hope that it will be useful,
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

module  deglitch #(
        parameter CLOCKS = 1
    )(
        input  clk,
        input  rst,
        input  d,
        output q
);
    localparam WIDTH =  clogb2(CLOCKS + 1);
    reg           q_r;
    assign q = q_r;
    generate
        if (CLOCKS == 0) begin
            always @ (posedge clk) begin
                if      (rst)       q_r <= 0;
                else                q_r <= d;
            end
        end else begin
            reg [WIDTH-1:0] cntr; 
            always @ (posedge clk) begin
                if      (rst)       q_r <= 0;
                else if (cntr == 0) q_r <= d;
                
                if (rst || (d == q_r) || (cntr == 0))   cntr <= CLOCKS;
                else                                    cntr <= cntr -1;
            
            end
        end
    endgenerate    


    function integer clogb2;
        input [31:0] value;
        integer  i;
        begin
            clogb2 = 0;
            for(i = 0; 2**i < value; i = i + 1)
                clogb2 = i + 1;
       end
    endfunction
endmodule

