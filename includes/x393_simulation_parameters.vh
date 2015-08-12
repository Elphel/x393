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
    parameter       FCLK0_PERIOD =  41.667, //  10.417, 24MHz
    parameter       FCLK1_PERIOD =  0.0,
    
//    parameter SENSOR12BITS_LLINE   =   192,   //   1664;//   line duration in clocks
//    parameter SENSOR12BITS_NCOLS   =    66,   //58; //56; // 129; //128;   //1288;
//    parameter SENSOR12BITS_NROWS   =    18,   // 16;   //   1032;
//    parameter SENSOR12BITS_NROWB   =     1,   // number of "blank rows" from vact to 1-st hact
//    parameter SENSOR12BITS_NROWA   =     1,   // number of "blank rows" from last hact to end of vact
//    parameter nAV   =      24,   //240;   // clocks from ARO to VACT (actually from en_dclkd)
//    parameter SENSOR12BITS_NBPF =       20,   //16; // bpf length
    parameter SENSOR12BITS_NGPL =        8,   // bpf to hact
    parameter SENSOR12BITS_NVLO =        1,   // VACT=0 in video mode (clocks)
    //parameter tMD   =   14;    //
    //parameter tDDO   =   10;   //   some confusion here - let's assume that it is from DCLK to Data out
    parameter SENSOR12BITS_TMD =         4,   //
    parameter SENSOR12BITS_TDDO =        2,   //   some confusion here - let's assume that it is from DCLK to Data out
    parameter SENSOR12BITS_TDDO1 =       5,   //
//    parameter SENSOR12BITS_TRIGDLY =     8,   // delay between trigger input and start of output (VACT) in lines
//    parameter SENSOR12BITS_RAMP =        1,   // 1 - ramp, 0 - random (now - sensor.dat)
//    parameter SENSOR12BITS_NEW_BAYER =   0,   // 0 - "old" tiles (16x16, 1 - new - (18x18)   

    parameter HISTOGRAM_LEFT =           0,   // 2;   // left   
    parameter HISTOGRAM_TOP =            8,   // 2,   // top
    parameter HISTOGRAM_WIDTH =          6,   // width
    parameter HISTOGRAM_HEIGHT =         6,   // height
    parameter HISTOGRAM_STRAT_PAGE =    20'h12345,
    parameter FRAME_WIDTH_ROUND_BITS =   9,  // multiple of 512 pixels (32 16-byte bursts) (11 - ful SDRAM page)
    
    parameter WOI_WIDTH=                 64,
    parameter QUADRANTS_PXD_HACT_VACT =  6'h01 // 2 bits each: data-0, hact - 1, vact - 2 
                                               // 90-degree shifts for data [1:0], hact [3:2] and vact [5:4]
    
    