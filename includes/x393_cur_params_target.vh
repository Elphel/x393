/*******************************************************************************
 * File: x393_cur_params_target.vh
 * Date:2015-02-07  
 * Author: Andrey Filippov     
 * Description: Memory controller parameters that need adjustment during training
 * Target ,pde
 * Copyright (c) 2015 Elphel, Inc.
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
 *******************************************************************************/
localparam  DLY_LANE0_ODELAY =  80'hd85c1014141814181218;
localparam  DLY_LANE0_IDELAY =  72'h2c7a8380897c807b88;
localparam  DLY_LANE1_ODELAY =  80'hd8581812181418181814;
localparam  DLY_LANE1_IDELAY =  72'h108078807a887c8280;
localparam          DLY_CMDA = 256'hd3d3d3d4dcd1d8cc494949494949494949d4d3ccd3d3dbd4ccd4d2d3d1d2d8cc;
localparam         DLY_PHASE =   8'h33;
// localparam   DFLT_WBUF_DELAY =   4'h9;
    