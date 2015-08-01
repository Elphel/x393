 /*******************************************************************************
 * File: x393_simulation_parameters.vh
 * Date:2015-02-07  
 * Author: Andrey Filippov     
 * Description: Simulation-specific parameters for the x393
 *
 * Copyright (c) 2015 Elphel, Inc.
 * x393_simulation_parameters.vh is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * x393_simulation_parameters.vh is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
    , // to continue previous parameter list
    parameter integer AXI_RDADDR_LATENCY= 2, // 2, //2, //2,
    parameter integer AXI_WRADDR_LATENCY= 1, // 1, //2, //4,
    parameter integer AXI_WRDATA_LATENCY= 2, // 1, //1, //1
    parameter integer AXI_TASK_HOLD=1.0,
    
//    parameter [1:0] DEFAULT_STATUS_MODE=3,
    parameter       SIMUL_AXI_READ_WIDTH=16,
    
    parameter       MEMCLK_PERIOD = 5.0,
    parameter       FCLK0_PERIOD = 10.417,
    parameter       FCLK1_PERIOD =  0.0
    