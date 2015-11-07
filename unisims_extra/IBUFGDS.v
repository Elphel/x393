/*******************************************************************************
 * Module: IBUFGDS
 * Date:2015-11-06  
 * Author: andrey     
 * Description: Module name "known" to synthesis, but missing in unisims
 *
 * Copyright (c) 2015 Elphel, Inc .
 * IBUFGDS.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  IBUFGDS.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  IBUFGDS # (
      parameter CAPACITANCE = "DONT_CARE",
      parameter DIFF_TERM = "FALSE",
//      parameter DQS_BIAS = "FALSE",
//      parameter IBUF_DELAY_VALUE = "0",
      parameter IBUF_LOW_PWR = "TRUE",
//      parameter IFD_DELAY_VALUE = "AUTO",
      parameter IOSTANDARD = "DEFAULT"
  )(
        output O,
        input  I,
        input  IB
);
    ibufds_ibufgds #(
        .CAPACITANCE      (CAPACITANCE),
        .DIFF_TERM        (DIFF_TERM),
//        .DQS_BIAS         (HISPI_DQS_BIAS),
//        .IBUF_DELAY_VALUE (HISPI_IBUF_DELAY_VALUE),
        .IBUF_LOW_PWR     (IBUF_LOW_PWR),
//        .IFD_DELAY_VALUE  (HISPI_IFD_DELAY_VALUE),
        .IOSTANDARD       (IOSTANDARD)
    ) ibufds_ibufgds_i (
        .O    (O),      // output
        .I    (I), // input
        .IB   (IB)  // input
    );


endmodule

