/*!
 * @file fpga_version.vh
 * @date 2015-08-26  
 * @author Andrey Filippov     
 *
 * @brief Defining run-time readable FPGA code version
 *
 * @copyright Copyright (c) 2015 Elphel, Inc.
 *
 * <b>License:</b>
 *
 * fpga_version.vh is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * fpga_version.vh is distributed in the hope that it will be useful,
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
        parameter FPGA_VERSION =          32'h039300c2;      //parallel - external sync for Eyesis -0.160/71 79.84%
//      parameter FPGA_VERSION =          32'h039300c1;      //parallel - modified after troubleshooting simulation -0.069/41, 79.90 %
//      parameter FPGA_VERSION =          32'h039300c0;      //parallel - changing LOGGER_PAGE_IMU 3->0 (how it was in 353) -0.044/16, 79.59%
//      parameter FPGA_VERSION =          32'h039300bf;      //parallel - mask extrenal timestamps mode -0.043/17 79.56%
//      parameter FPGA_VERSION =          32'h039300be;      //parallel - adding odd/even pixels shift -0.066/12, 80.26%
//      parameter FPGA_VERSION =          32'h039300bd;      //hispi,  trying the same -0.173/36, 80.95%
//      parameter FPGA_VERSION =          32'h039300bc;      //parallel, 100kHz min i2c speed -0.076/8, 79.69%
//      parameter FPGA_VERSION =          32'h039300bb;      //parallel, adding i2c almost full. -0.101/8, 79.37%
//      parameter FPGA_VERSION =          32'h039300ba;      //parallel, fixing introduced by debug bug in sens_parallel12.v: met, 80.03%
//      parameter FPGA_VERSION =          32'h039300b9;      //parallel, correcting RTC (it was 25/24 faster) -0.038/29, 79.64%
//      parameter FPGA_VERSION =          32'h039300b8;      //parallel, working on camsync -0.330/99, 80.52% -> -0.143 /40, 79.88% 
//      parameter FPGA_VERSION =          32'h039300b7;      //parallel, matching histograms Bayer to gamma bayer -0.011/9, 79.92%
//      parameter FPGA_VERSION =          32'h039300b6;      //parallel, working on histograms odd colors bug -0.207 /58,  79.68%
//      parameter FPGA_VERSION =          32'h039300b5;      //parallel, moving histograms earlier -0.123/30, 79.47 
//      parameter FPGA_VERSION =          32'h039300b4;      //-a parallel, and more - -0.180/33, 80.68 %
//      parameter FPGA_VERSION =          32'h039300b4;      // parallel, and more -0.094/37, 80.18 %
//      parameter FPGA_VERSION =          32'h039300b3;      // parallel, and more  -0.052/8, 79.56%
//      parameter FPGA_VERSION =          32'h039300b2;      // parallel, and more -0.163 /47,  79.93%
//      parameter FPGA_VERSION =          32'h039300b1;      // parallel, more debug -0.335/86, 79.66%
//      parameter FPGA_VERSION =          32'h039300b0;      // parallel, more debug -0.047/8, 79.51%
//      parameter FPGA_VERSION =          32'h039300af;      // parallel, debugging histograms all met, 79.45%
//      parameter FPGA_VERSION =          32'h039300ae;      // parallel, increasing sesnsor-channels maximal delays to 12 bits -0.091/25, 79.89%
//      parameter FPGA_VERSION =          32'h039300ad;      // parallel, resetting frame_pre_run. All met, 79.97%
//      parameter FPGA_VERSION =          32'h039300ac;      // parallel, adding reset needed_page in compressor -0.012 (2), 79.39%
//      parameter FPGA_VERSION =          32'h039300ab;      // parallel, more on frame sync in compressor All met, 79.04%
//      parameter FPGA_VERSION =          32'h039300aa;      // parallel, improving frame sync in compressor -0.036ns, 79.60%
//      parameter FPGA_VERSION =          32'h039300a9;      // parallel, added copying maste-t-slave frame number -0.169(8 paths), 80.28%
//      parameter FPGA_VERSION =          32'h039300a8;      // parallel, fixing BUG in command sequencer that was missing some commands 79.25%, all met
//      parameter FPGA_VERSION =          32'h039300a7;      // parallel, changing parameter to reset buffer pages at each frame start. 79.4%, -0.022 (2 paths)
//      parameter FPGA_VERSION =          32'h039300a6;      // parallel, adding frame sync delays to mcntrl_linear 79.26, mclk and xclk violated
//      parameter FPGA_VERSION =          32'h039300a5;      // parallel, fixing command sequencer and ARO 80.21%, -0.068
//      parameter FPGA_VERSION =          32'h039300a4;      // parallel 79.66, -0.1
//      parameter FPGA_VERSION =          32'h039300a3;      // hispi, after minor interface changes (separated control bits)80.52% -0.163
//      parameter FPGA_VERSION =          32'h039300a2;      // hispi trying default placement 81.39% not met by -0.183
//      parameter FPGA_VERSION =          32'h039300a1;      // hispi 81.19%, not met by -0.07
//      parameter FPGA_VERSION =          32'h039300a0;      // parallel, re-ran after bug fix, %79.38%, not met -0.072
//      parameter FPGA_VERSION =          32'h039300a0;    // parallel, else same as 9f 78.91%, not met by -0.032
//      parameter FPGA_VERSION =          32'h0393009f;    // hispi, adding IRQ status register (placemnt "explore") 81.36%, all met - broken on one channel?
//      parameter FPGA_VERSION =          32'h0393009e;    // hispi, adding IRQ status register 80.90%, timing failed by -0.218
//      parameter FPGA_VERSION =          32'h0393009d;    // hispi, adding IRQ from multi_saxi  80.95%, timing not met (-0.034 )
//      parameter FPGA_VERSION =          32'h0393009c;    // parallel, adding IRQ from multi_saxi  79.31% , timing met (2015.3)
//      parameter FPGA_VERSION =          32'h0393009b;    // parallel, bug fixed in dct_chen 79.58, timing met (2015.3)
//      parameter FPGA_VERSION =          32'h0393009a;    // serial, bug fixed in dct_chen 80.94%, timing met (2015.3)
//      parameter FPGA_VERSION =          32'h03930099;    // parallel, with dct_chen, all met, 79.2%
//      parameter FPGA_VERSION =          32'h03930098;    // serial, trying dct_chen - works, removing old completely, constraints met80.?%
//      parameter FPGA_VERSION =          32'h03930097;    // serial, trying dct_chen - works
//      parameter FPGA_VERSION =          32'h03930096;    // serial, next (before changing DCT)
//      parameter FPGA_VERSION =          32'h03930095;    // parallel  -0.068/-0.342/5 82.38%
//      parameter FPGA_VERSION =          32'h03930094;    // hispi, disabling debug  -0.187/-1.252/16 84.14%  
//      parameter FPGA_VERSION =          32'h03930093;    // hispi, masking sensor data to memory buffer, debug still on
//      parameter FPGA_VERSION =          32'h03930092;    // hispi, even more debugging memory pages sens-> memory
//      parameter FPGA_VERSION =          32'h03930091;    // hispi, more debugging memory pages sens-> memory
//      parameter FPGA_VERSION =          32'h03930090;    // hispi, debugging memory pages sens-> memory (not met)
//      parameter FPGA_VERSION =          32'h0393008f;    // parallel, all the same
//      parameter FPGA_VERSION =          32'h0393008e;    // hispi, adding i2c fifo fill, all met,83.73%
//      parameter FPGA_VERSION =          32'h0393008d;    // parallel, adding i2c fifo fill max err 0.128, 82.61%
//      parameter FPGA_VERSION =          32'h0393008c;      // hispi, all met, 83.55%
//      parameter FPGA_VERSION =          32'h0393008b;    // parallel, all met, 82.06% . Reran 0.051ns error, 82.02%
//      parameter FPGA_VERSION =          32'h0393008a;    // HiSPI sensor (14 MPix) no timing errors
//      parameter FPGA_VERSION =          32'h03930089;    // Auto-synchronizing i2c sequencers with the command ones
//      parameter FPGA_VERSION =          32'h03930088;    // Fixing circbuf rollover pointers bug (only one path violated)
//      parameter FPGA_VERSION =          32'h03930087;    // Fixed default 90% quantization table
//      parameter FPGA_VERSION =          32'h03930087;    // Synchronizing i2c sequencer frame number with that of a command sequencer
//      parameter FPGA_VERSION =          32'h03930086;    // Adding byte-wide JTAG read to speed-up 10359 load
//      parameter FPGA_VERSION =          32'h03930085;    // Adding software control for i2c pins when sequencer is stopped, timing matched
//      parameter FPGA_VERSION =          32'h03930084;    // Back to iserdes, inverting xfpgatdo - met
//      parameter FPGA_VERSION =          32'h03930083;    // Debugging JTAG, using plain IOBUF
//      parameter FPGA_VERSION =          32'h03930082;    // trying other path to read xfpgatdo
//      parameter FPGA_VERSION =          32'h03930081;    // re-started parallel - timing met
//      parameter FPGA_VERSION =          32'h03930080;    // serial, failed timing, >84%
//      parameter FPGA_VERSION =          32'h0393007f;    // More constraints files tweaking
//      parameter FPGA_VERSION =          32'h0393007e;    // Trying .tcl constraints instead of xdc - timing met
//      parameter FPGA_VERSION =          32'h0393007d;    // Changing IMU logger LOGGER_PAGE_IMU 0-> 3 to avoid overlap with other registers. Timing met
//      parameter FPGA_VERSION =          32'h0393007c;    // fixed cmdseqmux - reporting interrupt status and mask correctly
//      parameter FPGA_VERSION =          32'h0393007b;  // lvcmos25_lvds_25_diff
//      parameter FPGA_VERSION =          32'h0393007a;  // lvcmos25_ppds_25_nodiff - OK
//      parameter FPGA_VERSION =          32'h03930079;  // diff - failed
//      parameter FPGA_VERSION =          32'h03930078;  // lvcmos18_ppds_25_nodiff
//      parameter FPGA_VERSION =          32'h03930077;  // Restoring IOSTANDARDs - OK
//      parameter FPGA_VERSION =          32'h03930076;  // Trying PPDS_25 with 1.8 actual power - Stuck when applying 1.8 or 2.5V
//      parameter FPGA_VERSION =          32'h03930075;  // Trying IN_TERM = "UNTUNED_50"
//    parameter FPGA_VERSION =          32'h03930074;  // Adding SATA controller 16365 ( 83.28%)
//    parameter FPGA_VERSION =          32'h03930073;  // Adding interrupts support
//    parameter FPGA_VERSION =          32'h03930072;  // Adding hact monitor bit 77.9%, failed timing
//    parameter FPGA_VERSION =          32'h03930071;  // Fixing AXI HP multiplexer xclk -0.083 -1.968 44 / 15163 (77.17%)
//    parameter FPGA_VERSION =          32'h03930070;  // Fixing HiSPi xclk -0.049 -0.291 17, utilization 15139 (77.04%)
//    parameter FPGA_VERSION =          32'h0393006f;  // Fixing JP4 mode - xcl -0.002 -0.004 2, utilization 15144 (77.07 %)
//    parameter FPGA_VERSION =          32'h0393006f; // Fixing JP4 mode - xclk -0.209/-2.744/23, utilization  15127 (76.98%)
//    parameter FPGA_VERSION =          32'h0393006e; // Trying lane switch again after bug fix, failing 1 in  ddr3_mclk -> ddr3_clk_div by  -0.023
//    parameter FPGA_VERSION =          32'h0393006d; // -1 with lane switch - does not work
//    parameter FPGA_VERSION =          32'h0393006d; // Reversing pixels/lanes order xclk violated -0.154
//    parameter FPGA_VERSION =          32'h0393006c; // will try debug for HiSPi.  xclk violated by -0.030, slices 15062 (76.65%)
//    parameter FPGA_VERSION =          32'h0393006b; // Correcting sensor external clock generation - was wrong division. xclk violated by 0.095 ns
//    parameter FPGA_VERSION =          32'h0393006a; // modified clock generation, trying with HiSPi - 72.77% utilization x40..x60
//    parameter FPGA_VERSION =          32'h03930069; // modified clock generation, rebuilding for parallel sensors - all met, 71.8% utilization
                                                      // Worked OK, but different phase for sensor 0 (all quadrants as 1,3 OK)
//    parameter FPGA_VERSION =          32'h03930068; // trying BUFR/FUFIO on all sensors ipclk/ipclk2x
//    parameter FPGA_VERSION =          32'h03930067; // removing DUMMY_TO_KEEP, moving IOSTANDARD to HDL code
//    parameter FPGA_VERSION =          32'h03930066; // trying just one histogram to watch utilization - with 4 was: Slice 15913 (80.98%), now Slice = 14318 (72.87%)
//    parameter FPGA_VERSION =          32'h03930065; // (same rev) all met,  using "old" (non-inverted) phase - OK (full phase range)
//    parameter FPGA_VERSION =          32'h03930065; // switch phy_top.v (all met) - OK with inverted phase control (reduced phase range)
//    parameter FPGA_VERSION =          32'h03930064; // switch mcomtr_sequencer.v  (xclk not met) - wrong!
//    parameter FPGA_VERSION =          32'h03930063; // switch mcntrl_linear_rw.v (met) good, worse mem valid phases 
//    parameter FPGA_VERSION =          32'h03930062; // (met)debugging - what was broken (using older versions of some files) - mostly OK (some glitches)
//    parameter FPGA_VERSION =          32'h03930061; // restored bufr instead of bufio for memory high speed clock
//    parameter FPGA_VERSION =          32'h03930060; // moving CLK1..3 in memory controller MMCM, keeping CLK0 and FB. Stuck at memory calib 
//    parameter FPGA_VERSION =          32'h0393005f; // restored mclk back to 200KHz, registers added to csconvert18a
//    parameter FPGA_VERSION =          32'h0393005e; // trying mclk = 225 MHz (was 200MHz) define MCLK_VCO_MULT 18
//    parameter FPGA_VERSION =          32'h0393005d; // trying mclk = 250 MHz (was 200MHz) define MCLK_VCO_MULT 20
//    parameter FPGA_VERSION =          32'h0393005c; // 250MHz OK, no timing violations
//    parameter FPGA_VERSION =          32'h0393005b; // 250MHz Not tested, timing violation in bit_stuffer_escape: xclk -0.808 -142.047 515
//    parameter FPGA_VERSION =          32'h0393005a; // Trying xclk = 250MHz - timing viloations in xdct393, but particular hardware works
//    parameter FPGA_VERSION =          32'h03930059; // 'new' (no pclk2x, no xclk2x  clocks) sensor/converter w/o debug - OK
//    parameter FPGA_VERSION =          32'h03930058; // 'new' (no pclk2x, no xclk2x  clocks) sensor/converter w/o debug - broken end of frame
//    parameter FPGA_VERSION =          32'h03930057; // 'new' (no pclk2x, yes xclk2x  clocks) sensor/converter w/o debug - OK
//    parameter FPGA_VERSION =          32'h03930056; // 'new' (no 2x clocks) sensor/converter w/o debug - broken
//    parameter FPGA_VERSION =          32'h03930055; // 'old' sensor/converter w/o debug, fixed bug with irst - OK
//    parameter FPGA_VERSION =          32'h03930054; // 'old' sensor/converter with debug
//    parameter FPGA_VERSION =          32'h03930053; // trying if(reset ) reg <- 'bx    