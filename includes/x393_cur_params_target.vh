/*!
 * @file x393_cur_params_target.vh
 * @date 2015-02-07
 * @author Andrey Filippov
 *
 * @brief Memory controller parameters that need adjustment during training
 * of the target. This file is individually updated on the target.
 *
 * @copyright Copyright (c) 2015 Elphel, Inc.
 *
 * <b>License:</b>
 *
 * x393_cur_params_target.vh is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * x393_cur_params_target.vh is distributed in the hope that it will be useful,
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
/*
localparam  DLY_LANE0_ODELAY =  80'hd85c1014141814181218;
localparam  DLY_LANE0_IDELAY =  72'h2c7a8380897c807b88;
localparam  DLY_LANE1_ODELAY =  80'hd8581812181418181814;
localparam  DLY_LANE1_IDELAY =  72'h108078807a887c8280;
localparam          DLY_CMDA = 256'hd3d3d3d4dcd1d8cc494949494949494949d4d3ccd3d3dbd4ccd4d2d3d1d2d8cc;
localparam         DLY_PHASE =   8'h33;
*/
localparam  DLY_LANE0_ODELAY =  80'hd8e4141a191c1c1c181c;
localparam  DLY_LANE0_IDELAY =  72'h187074747878787072;
localparam  DLY_LANE1_ODELAY =  80'hd8dc191418141a141818;
localparam  DLY_LANE1_IDELAY =  72'h186c6c726c746a7173;
localparam          DLY_CMDA = 256'hd3d3dad2d1cccad2505050505050505050d4d1d1d2d2dbcad2cad3d4d2cacbd1;
localparam         DLY_PHASE =   8'h34;
// localparam   DFLT_WBUF_DELAY =   4'h9;
