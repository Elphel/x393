/*******************************************************************************
 * Module: mpullup
 * Date:2015-05-15  
 * Author: andrey     
 * Description: wrapper for PULLUP primitive
 *
 * Copyright (c) 2015 Elphel, Inc.
 * mpullup.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  mpullup.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  mpullup(
	output O
);
    /* Instance template for module PULLUP */
    PULLUP PULLUP_i (
        .O(O) // output 
    );


endmodule

