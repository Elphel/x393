/*!
 * @file x393_simulation_parameters.vh
 * @date 2015-02-07  
 * @author Andrey Filippov     
 *
 * @brief Simulation-specific parameters for the x393
 *
 * @copyright Copyright (c) 2015 Elphel, Inc.
 *
 * <b>License:</b>
 *
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
    , // to continue previous parameter list
    parameter NUM_INTERRUPTS =        9,
    
    parameter integer AXI_RDADDR_LATENCY= 2, // 2, //2, //2,
    parameter integer AXI_WRADDR_LATENCY= 1, // 1, //2, //4,
    parameter integer AXI_WRDATA_LATENCY= 2, // 1, //1, //1
    parameter integer AXI_TASK_HOLD=1.0,
    
//    parameter [1:0] DEFAULT_STATUS_MODE=3,
    parameter       SIMUL_AXI_READ_WIDTH=16,
    
    parameter       MEMCLK_PERIOD = 5.0,
`ifdef HISPI
    parameter       FCLK0_PERIOD =  40.91, //  24.444MHz
`else    
    parameter       FCLK0_PERIOD =  41.667, //  24MHz
`endif    
    parameter       FCLK1_PERIOD =  0.0,
// for python (export to C header) all parameters should be defined    
//`ifdef LWIR
    parameter       LWIR_DATA_FILE1  = "/data_ssd/nc393/elphel393/fpga-elphel/x393/input_data/pattern_160_120_14.dat",
    parameter       LWIR_DATA_FILE2  = "/data_ssd/nc393/elphel393/fpga-elphel/x393/input_data/pattern_160_120_14.dat",
    parameter       LWIR_DATA_FILE3  = "/data_ssd/nc393/elphel393/fpga-elphel/x393/input_data/pattern_160_120_14.dat",
    parameter       LWIR_DATA_FILE4  = "/data_ssd/nc393/elphel393/fpga-elphel/x393/input_data/pattern_160_120_14.dat",
    parameter       LWIR_WINDOW_WIDTH  =160,
    parameter       LWIR_WINDOW_HEIGHT =120,
    parameter       LWIR_TELEMETRY     =  2,
    parameter       LWIR_FRAME_PERIOD  =946969,
    parameter       LWIR_FRAME_DELAY   =100,
    parameter       LWIR_MS_PERIOD     = 25,  // 1us instead of 1 ms
    
    parameter       LWIR_TELEMETRY_REV =                  16'h7654,     // input[15:0] 
    parameter       LWIR_TELEMETRY_STATUS =           32'h137f1248, // input[31:0] 
    parameter       LWIR_TELEMETRY_SREV =     64'h0123456789abcdef, // input[63:0] 
    parameter       LWIR_TELEMETRY_TEMP_COUTS =          16'd59000,     // input[15:0] 
    parameter       LWIR_TELEMETRY_TEMP_KELVIN =         16'd29500,     // input[15:0] 
    parameter       LWIR_TELEMETRY_TEMP_LAST_KELVIN =    16'd29300,     // input[15:0] 
    parameter       LWIR_TELEMETRY_TIME_LAST_MS =     32'h12345678, // input[31:0] 
    parameter       LWIR_TELEMETRY_AGC_ROI_TOP =             16'd0,      // input[15:0] 
    parameter       LWIR_TELEMETRY_AGC_ROI_LEFT =            16'd0,      // input[15:0] 
    parameter       LWIR_TELEMETRY_AGC_ROI_BOTTOM =        16'd119,      // input[15:0] 
    parameter       LWIR_TELEMETRY_AGC_ROI_RIGHT =         16'd159,      // input[15:0] 
    parameter       LWIR_TELEMETRY_AGC_HIGH =            16'd19200,      // input[15:0] 
    parameter       LWIR_TELEMETRY_AGC_LOW =               16'd200,      // input[15:0] 
    parameter       LWIR_TELEMETRY_VIDEO_FORMAT =     32'haaaa5555,    // input[31:0] 
    
    parameter       LWIR_GPIO_IN =                              4'b0000,
    
    parameter       BOSON_DATA_FILE = "/input_data/pattern_160_120_16.dat",
    parameter       BOSON_WIDTH =   160,   // 640
    parameter       BOSON_HEIGHT =  120,   // 513
    parameter       BOSON_OUT_BITS = 16,   // 16
    parameter       BOSON_FPS =      60.0, // 60.0 
    parameter       BOSON_HSW =       8,   // 8
    parameter       BOSON_FP_BP =    22,   // 102 (FP+BP)
    parameter       BOSON_FP =       12,   // 52   
    parameter       BOSON_VSW =      7,    // 87,   // in scan lines
    
//`endif    
    
    
//    parameter SENSOR12BITS_LLINE   =   192,   //   1664;//   line duration in clocks
//    parameter SENSOR12BITS_NCOLS   =    66,   //58; //56; // 129; //128;   //1288;
//    parameter SENSOR12BITS_NROWS   =    18,   // 16;   //   1032;
//    parameter SENSOR12BITS_NROWB   =     1,   // number of "blank rows" from vact to 1-st hact
//    parameter SENSOR12BITS_NROWA   =     1,   // number of "blank rows" from last hact to end of vact
//    parameter nAV   =      24,   //240;   // clocks from ARO to VACT (actually from en_dclkd)
//    parameter SENSOR12BITS_NBPF =       20,   //16; // bpf length



//    parameter SENSOR_IMAGE_TYPE0 =       "RUN1", //"NORM", // "RUN1", "HIST_TEST"
//    parameter SENSOR_IMAGE_TYPE1 =       "RUN1",
//    parameter SENSOR_IMAGE_TYPE2 =       "NORM", // "RUN1", // "NORM", // "RUN1",
//    parameter SENSOR_IMAGE_TYPE3 =       "NORM", // "RUN1",

//    parameter SENSOR_IMAGE_TYPE0 =       "NORM1",
//    parameter SENSOR_IMAGE_TYPE1 =       "NORM2",
//    parameter SENSOR_IMAGE_TYPE2 =       "NORM3",
//    parameter SENSOR_IMAGE_TYPE3 =       "NORM4",

//    parameter SENSOR_IMAGE_TYPE0 =       "NORM10",
//    parameter SENSOR_IMAGE_TYPE1 =       "NORM10",
//    parameter SENSOR_IMAGE_TYPE2 =       "NORM11", // 4",
//    parameter SENSOR_IMAGE_TYPE3 =       "NORM12",
    
//    parameter SENSOR_IMAGE_TYPE0 =       "TEST01-1044X36", // "NORM13",
//    parameter SENSOR_IMAGE_TYPE1 =       "TEST01-1044X36", // "NORM13",
//    parameter SENSOR_IMAGE_TYPE2 =       "TEST01-1044X36", // "NORM14", // 4",
//    parameter SENSOR_IMAGE_TYPE3 =       "TEST01-1044X36", // "NORM15",
    
//    parameter SENSOR_IMAGE_TYPE0 =       "TEST01-260X36", // "NORM13",
//    parameter SENSOR_IMAGE_TYPE1 =       "TEST01-260X36", // "NORM13",
//    parameter SENSOR_IMAGE_TYPE2 =       "TEST01-260X36", // "NORM14", // 4",
//    parameter SENSOR_IMAGE_TYPE3 =       "TEST01-260X36", // "NORM15",


//    parameter SENSOR_IMAGE_TYPE0 =       "TEST01-260X68", // "NORM13",
//    parameter SENSOR_IMAGE_TYPE1 =       "TEST01-260X68", // "NORM13",
//    parameter SENSOR_IMAGE_TYPE2 =       "TEST01-260X68", // "NORM14", // 4",
//    parameter SENSOR_IMAGE_TYPE3 =       "TEST01-260X68", // "NORM15",
    
//      parameter SENSOR_IMAGE_TYPE0 =       "260X260A", // "NORM13",
//      parameter SENSOR_IMAGE_TYPE1 =       "260X260A", // "NORM13",
//      parameter SENSOR_IMAGE_TYPE2 =       "260X260A", // "NORM14", // 4",
//      parameter SENSOR_IMAGE_TYPE3 =       "260X260A", // "NORM15",

      parameter SENSOR_IMAGE_TYPE0 =       "256X256A", // "NORM13",
      parameter SENSOR_IMAGE_TYPE1 =       "256X256A", // "NORM13",
      parameter SENSOR_IMAGE_TYPE2 =       "256X256A", // "NORM14", // 4",
      parameter SENSOR_IMAGE_TYPE3 =       "256X256A", // "NORM15",


//    parameter SENSOR_IMAGE_TYPE0 =       "512X512A", // "NORM13",
//    parameter SENSOR_IMAGE_TYPE1 =       "512X512A", // "NORM13",
//    parameter SENSOR_IMAGE_TYPE2 =       "512X512A", // "NORM14", // 4",
//    parameter SENSOR_IMAGE_TYPE3 =       "512X512A", // "NORM15",

//
    parameter SIMULATE_CMPRS_CMODE0 =     CMPRS_CBIT_CMODE_JP4, // CMPRS_CBIT_CMODE_JPEG18,
    parameter SIMULATE_CMPRS_CMODE1 =     CMPRS_CBIT_CMODE_JP4, // CMPRS_CBIT_CMODE_JPEG18,
    parameter SIMULATE_CMPRS_CMODE2 =     CMPRS_CBIT_CMODE_JP4, // CMPRS_CBIT_CMODE_JPEG18, // CMPRS_CBIT_CMODE_JP4,
    parameter SIMULATE_CMPRS_CMODE3 =     CMPRS_CBIT_CMODE_JP4, // CMPRS_CBIT_CMODE_JPEG18, // CMPRS_CBIT_CMODE_JP4,
//    parameter SIMULATE_CMPRS_CMODE2 =     CMPRS_CBIT_CMODE_JPEG18,
//    parameter SIMULATE_CMPRS_CMODE3 =     CMPRS_CBIT_CMODE_JPEG18,
//        CMPRS_CBIT_CMODE_JPEG18, //input [31:0] cmode;   //  [13:9] color mode:
//        parameter CMPRS_CBIT_CMODE_JPEG18 =   4'h0, // color 4:2:0
//        parameter CMPRS_CBIT_CMODE_MONO6 =    4'h1, // mono 4:2:0 (6 blocks)
//        parameter CMPRS_CBIT_CMODE_JP46 =     4'h2, // jp4, 6 blocks, original
//        parameter CMPRS_CBIT_CMODE_JP46DC =   4'h3, // jp4, 6 blocks, dc -improved
//        parameter CMPRS_CBIT_CMODE_JPEG20 =   4'h4, // mono, 4 blocks (but still not actual monochrome JPEG as the blocks are scanned in 2x2 macroblocks)
//        parameter CMPRS_CBIT_CMODE_JP4 =      4'h5, // jp4,  4 blocks, dc-improved
//        parameter CMPRS_CBIT_CMODE_JP4DC =    4'h6, // jp4,  4 blocks, dc-improved
//        parameter CMPRS_CBIT_CMODE_JP4DIFF =  4'h7, // jp4,  4 blocks, differential
//        parameter CMPRS_CBIT_CMODE_JP4DIFFHDR =  4'h8, // jp4,  4 blocks, differential, hdr
//        parameter CMPRS_CBIT_CMODE_JP4DIFFDIV2 = 4'h9, // jp4,  4 blocks, differential, divide by 2
//        parameter CMPRS_CBIT_CMODE_JP4DIFFHDRDIV2 = 4'ha, // jp4,  4 blocks, differential, hdr,divide by 2
//        parameter CMPRS_CBIT_CMODE_MONO1 =    4'hb, // mono JPEG (not yet implemented)
//        parameter CMPRS_CBIT_CMODE_MONO4 =    4'he, // mono 4 blocks

    
    
    
    parameter SENSOR12BITS_NGPL =        8,   // bpf to hact
    parameter SENSOR12BITS_NVLO =        1,   // VACT=0 in video mode (clocks)
    //parameter tMD   =   14;    //
    //parameter tDDO   =   10;   //   some confusion here - let's assume that it is from DCLK to Data out
`ifdef HISPI
    parameter SENSOR12BITS_TMD =         1,   //
    parameter SENSOR12BITS_TDDO =        1,   //   some confusion here - let's assume that it is from DCLK to Data out
    parameter SENSOR12BITS_TDDO1 =       2,   //
`else    
    parameter SENSOR12BITS_TMD =         4,   //
    parameter SENSOR12BITS_TDDO =        2,   //   some confusion here - let's assume that it is from DCLK to Data out
    parameter SENSOR12BITS_TDDO1 =       5,   //
`endif    
//    parameter SENSOR12BITS_TRIGDLY =     8,   // delay between trigger input and start of output (VACT) in lines
//    parameter SENSOR12BITS_RAMP =        1,   // 1 - ramp, 0 - random (now - sensor.dat)
//    parameter SENSOR12BITS_NEW_BAYER =   0,   // 0 - "old" tiles (16x16, 1 - new - (18x18)   

    parameter HISTOGRAM_LEFT =           0,   // 2;   // left   
    parameter HISTOGRAM_TOP =            8,   // 2,   // top
    parameter HISTOGRAM_WIDTH =          6,   // width
    parameter HISTOGRAM_HEIGHT =         6,   // height
    parameter HISTOGRAM_START_PAGE =    20'h12345,
    parameter FRAME_WIDTH_ROUND_BITS =   9,  // multiple of 512 pixels (32 16-byte bursts) (11 - ful SDRAM page)
    
`ifdef LWIR
    parameter WOI_WIDTH=                 160,
    parameter WOI_HEIGHT=                122,
`elsif BOSON
    parameter WOI_WIDTH=                 160, // 640,
    parameter WOI_HEIGHT=                120, // 513,
`else
    parameter WOI_WIDTH=                 256, // 512, // 256, //1040, // 64,
    parameter WOI_HEIGHT=                256, // 512, // 256, // 64, // 32,
`endif         
    parameter QUADRANTS_PXD_HACT_VACT =  6'h01, // 2 bits each: data-0, hact - 1, vact - 2 
                                               // 90-degree shifts for data [1:0], hact [3:2] and vact [5:4]
    parameter SENSOR_PRIORITY =          1000
    