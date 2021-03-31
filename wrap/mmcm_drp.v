/*!
 * <b>Module:</b>mmcm_drp
 * @file mmcm_phase_cntr.v
 * @date 2021-03-29  
 * @author Andrey Filippov
 *
 * @brief MMCME2_ADV with DRP control
 *
 * @copyright Copyright (c) 2014 Elphel, Inc.
 *
 * <b>License:</b>
 *
 * mmcm_phase_cntr.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  mmcm_phase_cntr.v is distributed in the hope that it will be useful,
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
`timescale 1ns/1ps

// all counters are two-clock cycle nets
module  mmcm_drp#(
//    parameter PHASE_WIDTH=            8,      // number of bits for te phase counter (depends on divisors)
    parameter CLKIN_PERIOD =         0.000,  // input period in ns, 0..100.000 - MANDATORY, resolution down to 1 ps
    parameter BANDWIDTH =       "OPTIMIZED",  //"OPTIMIZED", "HIGH","LOW"
    parameter CLKFBOUT_MULT_F =       5.000,  // 2.0 to 64.0 . Together with CLKOUT#_DIVIDE and DIVCLK_DIVIDE
    parameter CLKFBOUT_PHASE =        0.000,  // CLOCK FEEDBACK phase in degrees (3 significant digits, -360.000...+360.000)
    parameter CLKOUT0_PHASE =         0.000,  // CLOCK0 phase in degrees (3 significant digits, -360.000...+360.000)
    parameter CLKOUT1_PHASE =         0.000,  // Initial/static fine phase shift, 1/(56*Fvco) actual step 
    parameter CLKOUT2_PHASE =         0.000,
    parameter CLKOUT3_PHASE =         0.000,
    parameter CLKOUT4_PHASE =         0.000,
    parameter CLKOUT5_PHASE =         0.000,
    parameter CLKOUT6_PHASE =         0.000,
    parameter CLKOUT0_DUTY_CYCLE=     0.5,    // CLOCK 0 output duty factor, 3 significant digits      
    parameter CLKOUT1_DUTY_CYCLE=     0.5,      
    parameter CLKOUT2_DUTY_CYCLE=     0.5,      
    parameter CLKOUT3_DUTY_CYCLE=     0.5,      
    parameter CLKOUT4_DUTY_CYCLE=     0.5,      
    parameter CLKOUT5_DUTY_CYCLE=     0.5,      
    parameter CLKOUT6_DUTY_CYCLE=     0.5,
    parameter CLKOUT4_CASCADE=       "FALSE", // cascades the output6 divider to the input for output 4     
    parameter CLKFBOUT_USE_FINE_PS = "FALSE", // Enable variable fine pase shift. Enable 1/(56*Fvco) phase inceremnts, round-robin
    parameter CLKOUT0_USE_FINE_PS =  "FALSE", // Same fine phase shift for all outputs where this attribute is "TRUE" 
    parameter CLKOUT1_USE_FINE_PS =  "FALSE", // Not compatible with fractional divide
    parameter CLKOUT2_USE_FINE_PS =  "FALSE", 
    parameter CLKOUT3_USE_FINE_PS =  "FALSE", 
    parameter CLKOUT4_USE_FINE_PS =  "FALSE", 
    parameter CLKOUT5_USE_FINE_PS =  "FALSE", 
    parameter CLKOUT6_USE_FINE_PS =  "FALSE", 
    parameter CLKOUT0_DIVIDE_F =      1.000,  // CLK0 outout divide, floating 1.000..128.000
    parameter CLKOUT1_DIVIDE =        1,        // CLK1 outout divide, integer 1..128 (determins a phase step as a fraction of pi/4)
    parameter CLKOUT2_DIVIDE =        1,
    parameter CLKOUT3_DIVIDE =        1,
    parameter CLKOUT4_DIVIDE =        1,
    parameter CLKOUT5_DIVIDE =        1,
    parameter CLKOUT6_DIVIDE =        1,
    parameter COMPENSATION=           "ZHOLD", // "ZHOLD",BUF_IN","EXTERNAL","INTERNAL
                                               // ZHOLD - provide negative hold time on I/O registers
                                               // INTERNAL - using internal compensation no deley is compensated
                                               // EXTERNAL - external to the FPGA network is being compensated
                                               // BUF_IN - no compensation when clock input is driveen by BUFG/BUFH/BUFR or GT
    parameter DIVCLK_DIVIDE =         1,            // Integer 1..106. Divides all outputs with respect to CLKIN
    parameter REF_JITTER1   =         0.010,        // Expected jitter on CLKIN1 (0.000..0.999)
    parameter REF_JITTER2   =         0.010,
    parameter SS_EN         =         "FALSE",      // Enables Spread Spectrum mode
    parameter SS_MODE       =         "CENTER_HIGH",//"CENTER_HIGH","CENTER_LOW","DOWN_HIGH","DOWN_LOW"
    parameter SS_MOD_PERIOD =         10000,        // integer 4000-40000 - SS modulation period in ns
    parameter STARTUP_WAIT  =         "FALSE",       // Delays "DONE" signal until MMCM is locked
    parameter DRP_ADDRESS_LENGTH =    7,
    parameter DRP_DATA_LENGTH =       16
)
(
    input clkin1,                // General clock input
    input clkin2,                // Alternative clock input
    input sel_clk2,              // Clock input select (inverted from MMCME2_ADV !!!)
    input clkfbin,               // Feedback clock input
    input rst,                   // asynchronous reset input (enables DRP control)
    input pwrdwn,                // power down input    
    output clkout0,              // output 0, HPC BUFR/BUFIO capable
    output clkout1,              // output 1, HPC BUFR/BUFIO capable
    output clkout2,              // output 2, HPC BUFR/BUFIO capable
    output clkout3,              // output 3, HPC BUFR/BUFIO capable
    output clkout4,              // output 4, HPC BUFR/BUFIO not capable
    output clkout5,              // output 5, HPC BUFR/BUFIO not capable
    output clkout6,              // output 6, HPC BUFR/BUFIO not capable
    output clkout0b,             // output 0, inverted 
    output clkout1b,             // output 1, inverted 
    output clkout2b,             // output 2, inverted 
    output clkout3b,             // output 3, inverted
    output clkfbout,             // dedicate feedback output    
    output clkfboutb,            // inverted feedback output
    output locked,               // PLL locked output
    output clkin_stopped,    
    output clkfb_stopped,
    // interface for the DRP (2 input bits, 2 output bits)
    input        drp_clk,        // connect to mclk in x393 
    input  [1:0] drp_cmd,        // 0 - NOP, 1 - shift 0, 2 - shift 1, 3 - execute 
    output       drp_out_bit,    // output data ( ready after execute, data bit after shift 0/shift 1 
    output       drp_out_odd_bit // alternates when new out_bit is available
    
);
    wire [DRP_ADDRESS_LENGTH-1:0] drp_addr;
    wire                          drp_den;
    wire                          drp_dwe;
    wire                          drp_drdy;
    wire    [DRP_DATA_LENGTH-1:0] drp_di;
    wire    [DRP_DATA_LENGTH-1:0] drp_do;

    drp_mmcm_pll #(
        .DRP_ADDRESS_LENGTH (DRP_ADDRESS_LENGTH),
        .DRP_DATA_LENGTH    (DRP_DATA_LENGTH)
    ) drp_mmcm_pll_i (
        .dclk        (drp_clk),         // input
        .mmcm_rst    (rst),             // input
        .cmd         (drp_cmd),         // input[1:0] 
        .out_bit     (drp_out_bit),     // output
        .out_odd_bit (drp_out_odd_bit), // output
        .daddr       (drp_addr),        // output[6:0] 
        .di_drp      (drp_di),          // output[15:0] 
        .do_drp      (drp_do),          // input[15:0] 
        .drdy        (drp_drdy),        // input
        .den         (drp_den),         // output
        .dwe         (drp_dwe)          // output
    );


    MMCME2_ADV #(
        .BANDWIDTH           (BANDWIDTH),
        .CLKFBOUT_MULT_F     (CLKFBOUT_MULT_F),
        .CLKFBOUT_PHASE      (CLKFBOUT_PHASE),
        .CLKFBOUT_USE_FINE_PS(CLKFBOUT_USE_FINE_PS),
        .CLKIN1_PERIOD       (CLKIN_PERIOD), 
        .CLKIN2_PERIOD       (CLKIN_PERIOD),
        .CLKOUT0_DIVIDE_F    (CLKOUT0_DIVIDE_F),
        .CLKOUT0_DUTY_CYCLE  (CLKOUT0_DUTY_CYCLE),
        .CLKOUT0_PHASE       (CLKOUT0_PHASE),
        .CLKOUT0_USE_FINE_PS (CLKOUT0_USE_FINE_PS),
        .CLKOUT1_DIVIDE      (CLKOUT1_DIVIDE),
        .CLKOUT1_DUTY_CYCLE  (CLKOUT1_DUTY_CYCLE),
        .CLKOUT1_PHASE       (CLKOUT1_PHASE),
        .CLKOUT1_USE_FINE_PS (CLKOUT1_USE_FINE_PS),
        .CLKOUT2_DIVIDE      (CLKOUT2_DIVIDE),
        .CLKOUT2_DUTY_CYCLE  (CLKOUT2_DUTY_CYCLE),
        .CLKOUT2_PHASE       (CLKOUT2_PHASE),
        .CLKOUT2_USE_FINE_PS (CLKOUT2_USE_FINE_PS),
        .CLKOUT3_DIVIDE      (CLKOUT3_DIVIDE),
        .CLKOUT3_DUTY_CYCLE  (CLKOUT3_DUTY_CYCLE),
        .CLKOUT3_PHASE       (CLKOUT3_PHASE),
        .CLKOUT3_USE_FINE_PS (CLKOUT3_USE_FINE_PS),
        .CLKOUT4_CASCADE     (CLKOUT4_CASCADE),
        .CLKOUT4_DIVIDE      (CLKOUT4_DIVIDE),
        .CLKOUT4_DUTY_CYCLE  (CLKOUT4_DUTY_CYCLE),
        .CLKOUT4_PHASE       (CLKOUT4_PHASE),
        .CLKOUT4_USE_FINE_PS (CLKOUT4_USE_FINE_PS),
        .CLKOUT5_DIVIDE      (CLKOUT5_DIVIDE),
        .CLKOUT5_DUTY_CYCLE  (CLKOUT5_DUTY_CYCLE),
        .CLKOUT5_PHASE       (CLKOUT5_PHASE),
        .CLKOUT5_USE_FINE_PS (CLKOUT5_USE_FINE_PS),
        .CLKOUT6_DIVIDE      (CLKOUT6_DIVIDE),
        .CLKOUT6_DUTY_CYCLE  (CLKOUT6_DUTY_CYCLE),
        .CLKOUT6_PHASE       (CLKOUT6_PHASE),
        .CLKOUT6_USE_FINE_PS (CLKOUT6_USE_FINE_PS),
        .COMPENSATION        (COMPENSATION),
        .DIVCLK_DIVIDE       (DIVCLK_DIVIDE),
        .REF_JITTER1         (REF_JITTER1),
        .REF_JITTER2         (REF_JITTER2),
        .SS_EN               (SS_EN),
        .SS_MODE             (SS_MODE),
        .SS_MOD_PERIOD       (SS_MOD_PERIOD),
        .STARTUP_WAIT        (STARTUP_WAIT)
    ) MMCME2_ADV_i (
        .CLKFBOUT       (clkfbout),      // output
        .CLKFBOUTB      (clkfboutb),     // output
        .CLKFBSTOPPED   (clkfb_stopped), // output
        .CLKINSTOPPED   (clkin_stopped), // output
        .CLKOUT0        (clkout0),       // output
        .CLKOUT0B       (clkout0b),      // output
        .CLKOUT1        (clkout1),       // output
        .CLKOUT1B       (clkout1b),      // output
        .CLKOUT2        (clkout2),       // output
        .CLKOUT2B       (clkout2b),      // output
        .CLKOUT3        (clkout3),       // output
        .CLKOUT3B       (clkout3b),      // output
        .CLKOUT4        (clkout4),       // output
        .CLKOUT5        (clkout5),       // output
        .CLKOUT6        (clkout6),       // output
        .LOCKED         (locked),        // output
        .PSDONE         (),              // output
        .CLKFBIN        (clkfbin),       // input
        .CLKIN1         (clkin1),        // input
        .CLKIN2         (clkin2),        // input
        .CLKINSEL       (~sel_clk2),     // input  0: Select CLKIN2, 1: Select CLKIN1 !!!!!!!!!!!!! 
        .PSCLK          (1'b0),          // psclk), // input
        .PSEN           (1'b0),          // psen), // input
        .PSINCDEC       (1'b0),          // psincdec), // input
        .PWRDWN         (pwrdwn),        // input
        .RST            (rst),           // input
        .DADDR          (drp_addr),      // Dynamic reconfiguration address (input[6:0])
        .DCLK           (drp_clk),       // Dynamic reconfiguration clock input
        .DEN            (drp_den),       // Dynamic reconfiguration enable input
        .DWE            (drp_dwe),       // Dynamic reconfiguration Write Enable input
        .DRDY           (drp_drdy),      // Dynamic reconfiguration ready output
        .DI             (drp_di),        // Dynamic reconfiguration data (input[15:0])
        .DO             (drp_do)         // Dynamic reconfiguration data (output[15:0])
    );


endmodule

