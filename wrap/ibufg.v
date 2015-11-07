/*******************************************************************************
 * Module: ibufg
 * Date:2015-07-17  
 * Author: Andrey Filippov
 * Description: Wrapper for IBUFG primitive
 *
 * Copyright (c) 2015 Elphel, Inc .
 * ibufg.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  ibufg.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps
/*Quote from Xilinx  "7 Series FPGA SelectIO Primitives":
The IBUF and IBUFG primitives are the same. IBUFGs are used when an input buffer is
used as a clock input. In the Xilinx software tools, an IBUFG is automatically placed at
clock input sites.

Actually, it still complains:

WARNING: [DRC 23-20] Rule violation (CKLD-2) Clock Net has direct IO Driver - Clock net clocks393_i/ibufg_i/memclk_0 is directly
         driven by an IO rather than a Clock Buffer. Driverx393.s: clocks393_i/ibufg_i/IBUF_i/O[VivadoPlace:0000]

*/
module  ibufg  #(
        parameter CAPACITANCE =      "DONT_CARE",
//        parameter IBUF_DELAY_VALUE = "0",
        parameter IBUF_LOW_PWR =     "TRUE",
//        parameter IFD_DELAY_VALUE =  "AUTO",
        parameter IOSTANDARD =       "DEFAULT" 
    )(
        output O,
        input  I
);
    IBUFG #(
        .CAPACITANCE       (CAPACITANCE),
//        .IBUF_DELAY_VALUE  (IBUF_DELAY_VALUE),
        .IBUF_LOW_PWR      (IBUF_LOW_PWR),
//        .IFD_DELAY_VALUE   (IFD_DELAY_VALUE),
        .IOSTANDARD        (IOSTANDARD)
    ) IBUFG_i (
        .O    (O), // output 
        .I    (I) // input 
    );
endmodule

