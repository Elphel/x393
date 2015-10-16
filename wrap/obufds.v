/*******************************************************************************
 * Module: obufds
 * Date:2015-10-15  
 * Author: andrey     
 * Description: Wrapper for OBUFDS primitive
 *
 * Copyright (c) 2015 Elphel, Inc .
 * obufds.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  obufds.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  obufds #(
    parameter CAPACITANCE = "DONT_CARE",
    parameter IOSTANDARD =  "DEFAULT",
    parameter SLEW =        "SLOW"
)(
    output o,
    output ob,
    input  i
);
    OBUFDS #(
        .CAPACITANCE (CAPACITANCE),
        .IOSTANDARD  (IOSTANDARD),
        .SLEW(SLEW)
    ) OBUFDS_i (
        .O    (o),  // output 
        .OB   (ob), // output 
        .I    (i)  // input 
    );


endmodule

