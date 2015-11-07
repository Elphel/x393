/*******************************************************************************
 * Module: IBUFG
 * Date:2015-11-06  
 * Author: andrey     
 * Description: Module name "known" to synthesis, but missing in unisims
 *
 * Copyright (c) 2015 Elphel, Inc .
 * IBUFG.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  IBUFG.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps
module  IBUFG  #(
        parameter CAPACITANCE =      "DONT_CARE",
//        parameter IBUF_DELAY_VALUE = "0",
        parameter IBUF_LOW_PWR =     "TRUE",
//        parameter IFD_DELAY_VALUE =  "AUTO",
        parameter IOSTANDARD =       "DEFAULT" 
    )(
        output O,
        input  I
);
    ibuf_ibufg #(
        .CAPACITANCE       (CAPACITANCE),
//        .IBUF_DELAY_VALUE  (IBUF_DELAY_VALUE),
        .IBUF_LOW_PWR      (IBUF_LOW_PWR),
//        .IFD_DELAY_VALUE   (IFD_DELAY_VALUE),
        .IOSTANDARD        (IOSTANDARD)
    ) IBUF_i (
        .O    (O), // output 
        .I    (I) // input 
    );
endmodule

