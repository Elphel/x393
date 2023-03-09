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
  parameter FPGA_VERSION = 32'h0393401b;    // GPS 1 PPS instead of odometer
//  parameter FPGA_VERSION = 32'h0393401a;    // adding strobe output for IMX-5 on ext-5
// parameter FPGA_VERSION = 32'h03934019;   // Boson640, logger debug disabled
// parameter FPGA_VERSION = 32'h03934018;   // Boson640, debugging logger 02
// parameter FPGA_VERSION = 32'h03934017;   // Boson640, debugging logger 01
// parameter FPGA_VERSION = 32'h03934016;   // Boson640, for 103993A, started IMU
//   parameter FPGA_VERSION = 32'h03931004; // parallel, starting IMS support // not yet used 
// parameter FPGA_VERSION = 32'h03931003; // parallel, adding camsync trigger decimation - modifying decimation
// parameter FPGA_VERSION = 32'h03934015; // Boson640, for 103993A, debugging 4 removed DE deglitch  - modifying decimation
// parameter FPGA_VERSION = 32'h03931004; // parallel, adding camsync trigger decimation - modifying decimation
// parameter FPGA_VERSION = 32'h03934014; // Boson640, for 103993A, debugging 4 removed DE deglitch
// parameter FPGA_VERSION = 32'h03934013; // Boson640, for 103993A, debugging 3  failed (maybe just phases)
// parameter FPGA_VERSION = 32'h03934012; // Boson640, for 103993A, debugging 2 works, shifted by 1 pix hor (found bug)
// parameter FPGA_VERSION = 32'h03934011; // Boson640, for 103993A, debugging 1
// parameter FPGA_VERSION = 32'h03934010; // Boson640, for 103993A
// parameter FPGA_VERSION = 32'h03934006; // Boson640, adjusted initial phase to 70.5 degrees (47 counts)
// parameter FPGA_VERSION = 32'h03934005; // Boson640, testing
// parameter FPGA_VERSION = 32'h03934005; // Boson640, implementing DRP to control MMCME2/PLLE2 trying more BUFR
// parameter FPGA_VERSION = 32'h03934004; // Boson640, implementing DRP to control MMCME2/PLLE2
// parameter FPGA_VERSION = 32'h03934003; // Boson640, mitigating LVDS errors
// parameter FPGA_VERSION = 32'h03934002; // Boson640, mitigating LVDS errors
// parameter FPGA_VERSION = 32'h03934001; // Boson640, adding camsync trigger decimation  // git commit
///parameter FPGA_VERSION = 32'h03931003; // parallel, adding camsync trigger decimation - debugging  // git commit
// parameter FPGA_VERSION = 32'h03931002; // parallel, adding camsync trigger decimation  
// parameter FPGA_VERSION = 32'h03931001; // parallel, fixing delays  // git commit
// parameter FPGA_VERSION = 32'h03930220; // pull down ot serial in to detect sensor presense NOT created 
// parameter FPGA_VERSION = 32'h0393021f; // (ext resistor) low_pwr, DIFF_SSTL18_I pclk phase 0.0 mmcm phase -22.5 (multiple of 1.5) 
// parameter FPGA_VERSION = 32'h0393021e; // internal 100ohm,  low_pwr, LVDS_25 pclk phase 0.0 mmcm phase -22.5 (multiple of 1.5) 
// parameter FPGA_VERSION = 32'h0393021d; // (ext resistor) low_pwr, DIFF_SSTL18_I pclk phase 0.0 mmcm phase -22.5 (multiple of 1.5) 
// parameter FPGA_VERSION = 32'h0393021c; // untuned_60 DIFF_SSTL18_I pclk phase 0.0 mmcm phase -21.0 (multiple of 1.5) set TWEAKING_IOSTANDARD 1
// parameter FPGA_VERSION = 32'h0393021b; // untuned_50 DIFF_SSTL18_I pclk phase 0.0 mmcm phase -21.0 (multiple of 1.5)
// parameter FPGA_VERSION = 32'h0393021a; // ext 100Ohm/DIFF_SSTL18_I pclk phase 0.0 mmcm phase -21.0 (multiple of 1.5) set TWEAKING_IOSTANDARD 1
// parameter FPGA_VERSION = 32'h03930219; // MINI_LVDS_25 pclk phase 0.0 mmcm phase -21.0 (multiple of 1.5) set TWEAKING_IOSTANDARD 1
// parameter FPGA_VERSION = 32'h03930218; // pclk phase 0.0 mmcm phase -21.0 (multiple of 1.5) set TWEAKING_IOSTANDARD 1
// parameter FPGA_VERSION = 32'h03930217; // pclk phase 0.0 (multiple of 1.5) set TWEAKING_IOSTANDARD 1
// parameter FPGA_VERSION = 32'h03930216; // pclk phase -3.0 (multiple of 1.5) set TWEAKING_IOSTANDARD 1
// parameter FPGA_VERSION = 32'h03930215; // pclk phase -3.0 (multiple of 1.5) 
// parameter FPGA_VERSION = 32'h03930214; // pclk phase +3.0 (multiple of 1.5) 
// parameter FPGA_VERSION = 32'h03930213; // bug fixing in frame_start_pending_long 
// parameter FPGA_VERSION = 32'h03930212; // test mode interface, no-pending frames 
// parameter FPGA_VERSION = 32'h03930211; // test mode, IBUF_LOW_PWR=TRUE, CLKFBOUT_PHASE_SENSOR = -21.0 
// parameter FPGA_VERSION = 32'h03930210; // added test mode
// parameter FPGA_VERSION = 32'h0393020f; // changing MMCM phase -19.5 (use clk_fb) IBUF_LOW_PWR=FALSE
// parameter FPGA_VERSION = 32'h0393020e; // changing MMCM phase -19.5 (use clk_fb)
// parameter FPGA_VERSION = 32'h0393020e; // changing MMCM phase -19.5 (use clk_fb)
// parameter FPGA_VERSION = 32'h0393020d; // changing MMCM phase -18.0 (use clk_fb)
// parameter FPGA_VERSION = 32'h0393020c; // changing MMCM phase 18.0 (use clk_fb)
// parameter FPGA_VERSION = 32'h0393020b; // clock/feedback clock 
// parameter FPGA_VERSION = 32'h0393020a; // 2.5, diff-term, no low-power, fixing delays 
// parameter FPGA_VERSION = 32'h03930209; // 2.5, diff-term, no low-power 
// parameter FPGA_VERSION = 32'h03930208; // 1.8V, no diff-term 
// parameter FPGA_VERSION = 32'h03930207; // Debugging 2.5V, diff-term 
// parameter FPGA_VERSION = 32'h03930206; // Debugging 
// parameter FPGA_VERSION = 32'h03930205; // Fixing serial pairs order for 103993 
// parameter FPGA_VERSION = 32'h03930204; // Testing 
// parameter FPGA_VERSION = 32'h03930203; // Fixing serial receive with dual stop bits 
// parameter FPGA_VERSION = 32'h03930202; // Initial Boson implementation (cheating with 2.5V), open drain for Boson reset 
// parameter FPGA_VERSION = 32'h03930201; // Initial Boson implementation (cheating with 2.5V - as with HISPI) 
// parameter FPGA_VERSION = 32'h03930200; // Initial Boson implementation (1.8V) 
        //BOSON
// parameter FPGA_VERSION = 32'h03930139; // Adding pullup on senspgm 
// parameter FPGA_VERSION = 32'h03930138; // Fixing output trigger in free running mode 
// parameter FPGA_VERSION = 32'h03930137; // longer reset, sync output 
// parameter FPGA_VERSION = 32'h03930136; // Fixing spi_seq 
// parameter FPGA_VERSION = 32'h03930135; // Adding multi-cam reset 
// parameter FPGA_VERSION = 32'h0393014;  // Adding multi-cam reset - buggy 
// parameter FPGA_VERSION = 32'h03930133; // Works with linux kernel rocko commit of 05/01/2019 bd61276e05f7343415929112ae368230a9c472f0
// parameter FPGA_VERSION = 32'h03930132; // Sync from serial bumber start, added output (with hact)
// parameter FPGA_VERSION = 32'h03930131; // Sync from serial bumber start
// parameter FPGA_VERSION = 32'h03930130; // Adding output for receive start frame
// parameter FPGA_VERSION = 32'h0393012f; // debugging resync on othjer sesnor
// parameter FPGA_VERSION = 32'h0393012e; // re-arranged control bits, added telemetry on/off
// parameter FPGA_VERSION = 32'h0393012d; // debugging - working sync
// parameter FPGA_VERSION = 32'h0393012c; // debugging - working sync
// parameter FPGA_VERSION = 32'h0393012b; // debugging
// parameter FPGA_VERSION = 32'h0393012a; // debugging
// parameter FPGA_VERSION = 32'h03930129; // adding synchronization by discard packets
// parameter FPGA_VERSION = 32'h03930128; // output dbg_segment_stb on [7]
// parameter FPGA_VERSION = 32'h03930127; // output vsync_use, reduced sclk to 10MHz
// parameter FPGA_VERSION = 32'h03930126; // fast slew to sensor
// parameter FPGA_VERSION = 32'h03930125; // fast slew to sensor
// parameter FPGA_VERSION = 32'h03930124; // more hardware debug circuitry
// parameter FPGA_VERSION = 32'h03930123; // Implementing VSYNC/GPIO3 input
// parameter FPGA_VERSION = 32'h03930122; // Added debug output
// parameter FPGA_VERSION = 32'h03930121; // VOSPI setting MOSI to low, according to DS
// parameter FPGA_VERSION = 32'h03930120; // VOSPI
// parameter FPGA_VERSION = 32'h03930108; // parallel - in master branch
// parameter FPGA_VERSION = 32'h03930107; // parallel - 17.4 - restored delay after linear, fixed bug, all met
// parameter FPGA_VERSION = 32'h03930110; //A serial - 17.4 - restored delay after linear, fixed bug, timing met
// parameter FPGA_VERSION = 32'h03930110; // serial - 17.4 - restored delay after linear, fixed bug, timing failed
// parameter FPGA_VERSION = 32'h03930107; // parallel - 17.4 - restored delay after linear, fixed bug, all met
// parameter FPGA_VERSION = 32'h03930106; // parallel - 17.4 - increased delay after linear read all met
// parameter FPGA_VERSION = 32'h03930105; // parallel - 17.4 - fixed wide raw frames all met
// parameter FPGA_VERSION = 32'h03930104; // parallel - 17.4 - added RAW mode (for tiff files) timing met
// parameter FPGA_VERSION = 32'h03930103; // serial - 17.4 - trigger polarity on GP1 inverted
// parameter FPGA_VERSION = 32'h03930102; // serial - 17.4 - disabling SOF when setting interface, bug fix
// parameter FPGA_VERSION = 32'h03930101; // serial - 17.4 - disabling SOF when setting interface - met
// parameter FPGA_VERSION = 32'h03930100; // serial - 17.4 - disabling SOF when setting interface timing OK
// parameter FPGA_VERSION = 32'h039300ff; // serial - 15.3 - same, suspected bitstream problems
// parameter FPGA_VERSION = 32'h039300fe; // serial - 17.4 - same, suspected bitstream problems no timing errors
// parameter FPGA_VERSION = 32'h039300fd; // serial - 17.4 - monitor lanes barrel (0..3)
// parameter FPGA_VERSION = 32'h039300fc; // serial - 17.4 - skipping first lines? pclk dsp1->dsp2 3*54ps
// parameter FPGA_VERSION = 32'h039300fb; // serial - 17.4 - serial, adding trigger control, lanes_alive (violated xclk by 0.004)
// parameter FPGA_VERSION = 32'h039300fa; // serial - 15.3 - serial, modifying lens_flat - timing met
// parameter FPGA_VERSION = 32'h039300f4; // parallel - 17.4 - , modifying lens_flat - timing met
// parameter FPGA_VERSION = 32'h039300f9; // serial - 17.4 - serial, modifying lens_flat - timing met
// parameter FPGA_VERSION = 32'h039300f8; // serial - 17.4 - failed pclk by 0.122
// parameter FPGA_VERSION = 32'h039300f3; //parallel - 17.4 - adding buffer frame number to status (no debug)
// parameter FPGA_VERSION = 32'h039300f2; //parallel - 17.4 - inactive debug, OK on fresh
// parameter FPGA_VERSION = 32'h039300f1; //parallel - 17.4 - without power optimize failed, second - OK
// parameter FPGA_VERSION = 32'h039300f0; //parallel - 17.4 - retry with spells in clean directory - failed
// parameter FPGA_VERSION = 32'h039300ef; //parallel - 17.4 - trying more set_param VivadoSynthesis-20180203230051566.log - OK!
// parameter FPGA_VERSION = 32'h039300ee; //parallel - 17.4 - save after re-running vivado, same dir - bad
// parameter FPGA_VERSION = 32'h039300ed; //parallel - 17.4 - twice synth+par, then bit - good
// parameter FPGA_VERSION = 32'h039300edc;//parallel - 17.4 - twice synth, then bit - bad
// parameter FPGA_VERSION = 32'h039300ec; //parallel - 17.4 - same, no debug, nofresh maxThreads 1- good
// parameter FPGA_VERSION = 32'h039300eb; //parallel - 17.4 - same, no debug, fresh maxThreads 1 - bad (bad numbers)
// parameter FPGA_VERSION = 32'h039300ea; //parallel - 17.4 - same, no debug, nofresh - good
// parameter FPGA_VERSION = 32'h039300e9; //parallel - 17.4 - same, no debug, nofresh - bad, seemed goog log
// parameter FPGA_VERSION = 32'h039300e8; //parallel - 17.4 - same, no debug, fresh - bad
// parameter FPGA_VERSION = 32'h039300e7; //parallel - 17.4 - same, no debug - good
// parameter FPGA_VERSION = 32'h039300e6; //parallel - 17.4 - clean, debug - OK
// parameter FPGA_VERSION = 32'h039300e5; //parallel - 17.4 - clean, debug - OK
// parameter FPGA_VERSION = 32'h039300e4; //parallel - 17.4 - same with clean remote directory - bad
// parameter FPGA_VERSION = 32'h039300e3; //parallel - 17.4 - good
// parameter FPGA_VERSION = 32'h039300e2; //parallel - 17.4 - no error, bad again
// parameter FPGA_VERSION = 32'h039300e1; //parallel - 17.4 - changing attributes to match old -bad!
// parameter FPGA_VERSION = 32'h039300e0; //parallel - 17.4 - disabled all debug - OK 
// parameter FPGA_VERSION = 32'h039300df; //parallel - 17.4 - all debug ==0 - met, OK 
// parameter FPGA_VERSION = 32'h039300de; //parallel - 17.4 - changing clock,met, good (clock - hclk) 
// parameter FPGA_VERSION = 32'h039300dd; //parallel - 17.4 - adding debug to SAXI1GP - OK 
// parameter FPGA_VERSION = 32'h039300dc; //parallel - 15.3 - adding debug to SAXI1GP -  -0.114 
// parameter FPGA_VERSION = 32'h039300db; //parallel - trying to migrate to 17.04 
// parameter FPGA_VERSION = 32'h039300da; //parallel - sata v.13 - tolerating elidle from device during comreset/cominit -0.014 /1, 81.38%, 
// parameter FPGA_VERSION = 32'h039300d9; //parallel - correcting histograms -0.022/1, 79.60%
// parameter FPGA_VERSION = 32'h039300d8; //parallel - SATA is now logging irq on/off -0.054 /16, 80.50%
// parameter FPGA_VERSION = 32'h039300d7; //parallel - updated SATA (v12) all met, 80.32%
// parameter FPGA_VERSION = 32'h039300d6; //parallel - more SATA debug link layer -0.127/18, 80.03% -> -0.002/4, 80.26%
// parameter FPGA_VERSION = 32'h039300d5; //parallel - more SATA debug (v.0xd) -0.021/8 80.20 %
// parameter FPGA_VERSION = 32'h039300d4; //parallel - more SATA debug (v.0xd) -0.064 /24 80.77%
// parameter FPGA_VERSION = 32'h039300d3; //parallel - Updated SATA (v.0xb) -0.073/22
// parameter FPGA_VERSION = 32'h039300d2; //parallel - fixing false trigger on input condition change -0.018/21, 80.28 %
// parameter FPGA_VERSION = 32'h039300d1; //parallel - removed extra debug -0.042/9 80.34%
// parameter FPGA_VERSION = 32'h039300d1; //parallel - changing line_numbers_sync condition  -0.011/3, 80.78 %
// parameter FPGA_VERSION = 32'h039300d0; //parallel - more status data
// parameter FPGA_VERSION = 32'h039300cf; //parallel - more status data for debugging ddr3_clk_div -0.033/2, 80.94%
// parameter FPGA_VERSION = 32'h039300ce; //parallel - frame_number_cntr >= last_frame_number -0.019/6 80.42%
// parameter FPGA_VERSION = 32'h039300cd; //parallel - making stop compression clean -0.048/8, 79.50
// parameter FPGA_VERSION = 32'h039300cc; //parallel - more jpeg tail -0.268/56, 80.24 %
// parameter FPGA_VERSION = 32'h039300cb; //parallel - modifying trigger/timestamps -0.050/13 80.38%
// parameter FPGA_VERSION = 32'h039300ca; //parallel - and more ... fixed -0.267/46, 80.42%
// parameter FPGA_VERSION = 32'h039300c9; //parallel - trying more ...-0.123/32 79.82%
// parameter FPGA_VERSION = 32'h039300c8; //parallel - trying to fix "premature..." -0.121/21, 80.2%
// parameter FPGA_VERSION = 32'h039300c7; //parallel - disable SoF when channel disabled: met, 80.32%
// parameter FPGA_VERSION = 32'h039300c6; //parallel - same -0.132 /31, 80.73%
// parameter FPGA_VERSION = 32'h039300c5; //parallel - made i2c ahead of system frame number for eof -0.027/12 , 82.08%
// parameter FPGA_VERSION = 32'h039300c4; //parallel - option to use EOF for i2c sequencer timing met, 79.66%
// parameter FPGA_VERSION = 32'h039300c3; //parallel - fixing timestamps -0.209/47, 79.86%
// parameter FPGA_VERSION = 32'h039300c2; //parallel - external sync for Eyesis -0.160/71 79.84%
// parameter FPGA_VERSION = 32'h039300c1; //parallel - modified after troubleshooting simulation -0.069/41, 79.90 %
// parameter FPGA_VERSION = 32'h039300c0; //parallel - changing LOGGER_PAGE_IMU 3->0 (how it was in 353) -0.044/16, 79.59%
// parameter FPGA_VERSION = 32'h039300bf; //parallel - mask extrenal timestamps mode -0.043/17 79.56%
// parameter FPGA_VERSION = 32'h039300be; //parallel - adding odd/even pixels shift -0.066/12, 80.26%
// parameter FPGA_VERSION = 32'h039300bd; //hispi,  trying the same -0.173/36, 80.95%
// parameter FPGA_VERSION = 32'h039300bc; //parallel, 100kHz min i2c speed -0.076/8, 79.69%
// parameter FPGA_VERSION = 32'h039300bb; //parallel, adding i2c almost full. -0.101/8, 79.37%
// parameter FPGA_VERSION = 32'h039300ba; //parallel, fixing introduced by debug bug in sens_parallel12.v: met, 80.03%
// parameter FPGA_VERSION = 32'h039300b9; //parallel, correcting RTC (it was 25/24 faster) -0.038/29, 79.64%
// parameter FPGA_VERSION = 32'h039300b8; //parallel, working on camsync -0.330/99, 80.52% -> -0.143 /40, 79.88% 
// parameter FPGA_VERSION = 32'h039300b7; //parallel, matching histograms Bayer to gamma bayer -0.011/9, 79.92%
// parameter FPGA_VERSION = 32'h039300b6; //parallel, working on histograms odd colors bug -0.207 /58,  79.68%
// parameter FPGA_VERSION = 32'h039300b5; //parallel, moving histograms earlier -0.123/30, 79.47 
// parameter FPGA_VERSION = 32'h039300b4; //-a parallel, and more - -0.180/33, 80.68 %
// parameter FPGA_VERSION = 32'h039300b4; // parallel, and more -0.094/37, 80.18 %
// parameter FPGA_VERSION = 32'h039300b3; // parallel, and more  -0.052/8, 79.56%
// parameter FPGA_VERSION = 32'h039300b2; // parallel, and more -0.163 /47,  79.93%
// parameter FPGA_VERSION = 32'h039300b1; // parallel, more debug -0.335/86, 79.66%
// parameter FPGA_VERSION = 32'h039300b0; // parallel, more debug -0.047/8, 79.51%
// parameter FPGA_VERSION = 32'h039300af; // parallel, debugging histograms all met, 79.45%
// parameter FPGA_VERSION = 32'h039300ae; // parallel, increasing sesnsor-channels maximal delays to 12 bits -0.091/25, 79.89%
// parameter FPGA_VERSION = 32'h039300ad; // parallel, resetting frame_pre_run. All met, 79.97%
// parameter FPGA_VERSION = 32'h039300ac; // parallel, adding reset needed_page in compressor -0.012 (2), 79.39%
// parameter FPGA_VERSION = 32'h039300ab; // parallel, more on frame sync in compressor All met, 79.04%
// parameter FPGA_VERSION = 32'h039300aa; // parallel, improving frame sync in compressor -0.036ns, 79.60%
// parameter FPGA_VERSION = 32'h039300a9; // parallel, added copying maste-t-slave frame number -0.169(8 paths), 80.28%
// parameter FPGA_VERSION = 32'h039300a8; // parallel, fixing BUG in command sequencer that was missing some commands 79.25%, all met
// parameter FPGA_VERSION = 32'h039300a7; // parallel, changing parameter to reset buffer pages at each frame start. 79.4%, -0.022 (2 paths)
// parameter FPGA_VERSION = 32'h039300a6; // parallel, adding frame sync delays to mcntrl_linear 79.26, mclk and xclk violated
// parameter FPGA_VERSION = 32'h039300a5; // parallel, fixing command sequencer and ARO 80.21%, -0.068
// parameter FPGA_VERSION = 32'h039300a4; // parallel 79.66, -0.1
// parameter FPGA_VERSION = 32'h039300a3; // hispi, after minor interface changes (separated control bits)80.52% -0.163
// parameter FPGA_VERSION = 32'h039300a2; // hispi trying default placement 81.39% not met by -0.183
// parameter FPGA_VERSION = 32'h039300a1; // hispi 81.19%, not met by -0.07
// parameter FPGA_VERSION = 32'h039300a0; // parallel, re-ran after bug fix, %79.38%, not met -0.072
// parameter FPGA_VERSION = 32'h039300a0; // parallel, else same as 9f 78.91%, not met by -0.032
// parameter FPGA_VERSION = 32'h0393009f; // hispi, adding IRQ status register (placemnt "explore") 81.36%, all met - broken on one channel?
// parameter FPGA_VERSION = 32'h0393009e; // hispi, adding IRQ status register 80.90%, timing failed by -0.218
// parameter FPGA_VERSION = 32'h0393009d; // hispi, adding IRQ from multi_saxi  80.95%, timing not met (-0.034 )
// parameter FPGA_VERSION = 32'h0393009c; // parallel, adding IRQ from multi_saxi  79.31% , timing met (2015.3)
// parameter FPGA_VERSION = 32'h0393009b; // parallel, bug fixed in dct_chen 79.58, timing met (2015.3)
// parameter FPGA_VERSION = 32'h0393009a; // serial, bug fixed in dct_chen 80.94%, timing met (2015.3)
// parameter FPGA_VERSION = 32'h03930099; // parallel, with dct_chen, all met, 79.2%
// parameter FPGA_VERSION = 32'h03930098; // serial, trying dct_chen - works, removing old completely, constraints met80.?%
// parameter FPGA_VERSION = 32'h03930097; // serial, trying dct_chen - works
// parameter FPGA_VERSION = 32'h03930096; // serial, next (before changing DCT)
// parameter FPGA_VERSION = 32'h03930095; // parallel  -0.068/-0.342/5 82.38%
// parameter FPGA_VERSION = 32'h03930094; // hispi, disabling debug  -0.187/-1.252/16 84.14%  
// parameter FPGA_VERSION = 32'h03930093; // hispi, masking sensor data to memory buffer, debug still on
// parameter FPGA_VERSION = 32'h03930092; // hispi, even more debugging memory pages sens-> memory
// parameter FPGA_VERSION = 32'h03930091; // hispi, more debugging memory pages sens-> memory
// parameter FPGA_VERSION = 32'h03930090; // hispi, debugging memory pages sens-> memory (not met)
// parameter FPGA_VERSION = 32'h0393008f; // parallel, all the same
// parameter FPGA_VERSION = 32'h0393008e; // hispi, adding i2c fifo fill, all met,83.73%
// parameter FPGA_VERSION = 32'h0393008d; // parallel, adding i2c fifo fill max err 0.128, 82.61%
// parameter FPGA_VERSION = 32'h0393008c; // hispi, all met, 83.55%
// parameter FPGA_VERSION = 32'h0393008b; // parallel, all met, 82.06% . Reran 0.051ns error, 82.02%
// parameter FPGA_VERSION = 32'h0393008a; // HiSPI sensor (14 MPix) no timing errors
// parameter FPGA_VERSION = 32'h03930089; // Auto-synchronizing i2c sequencers with the command ones
// parameter FPGA_VERSION = 32'h03930088; // Fixing circbuf rollover pointers bug (only one path violated)
// parameter FPGA_VERSION = 32'h03930087; // Fixed default 90% quantization table
// parameter FPGA_VERSION = 32'h03930087; // Synchronizing i2c sequencer frame number with that of a command sequencer
// parameter FPGA_VERSION = 32'h03930086; // Adding byte-wide JTAG read to speed-up 10359 load
// parameter FPGA_VERSION = 32'h03930085; // Adding software control for i2c pins when sequencer is stopped, timing matched
// parameter FPGA_VERSION = 32'h03930084; // Back to iserdes, inverting xfpgatdo - met
// parameter FPGA_VERSION = 32'h03930083; // Debugging JTAG, using plain IOBUF
// parameter FPGA_VERSION = 32'h03930082; // trying other path to read xfpgatdo
// parameter FPGA_VERSION = 32'h03930081; // re-started parallel - timing met
// parameter FPGA_VERSION = 32'h03930080; // serial, failed timing, >84%
// parameter FPGA_VERSION = 32'h0393007f; // More constraints files tweaking
// parameter FPGA_VERSION = 32'h0393007e; // Trying .tcl constraints instead of xdc - timing met
// parameter FPGA_VERSION = 32'h0393007d; // Changing IMU logger LOGGER_PAGE_IMU 0-> 3 to avoid overlap with other registers. Timing met
// parameter FPGA_VERSION = 32'h0393007c; // fixed cmdseqmux - reporting interrupt status and mask correctly
// parameter FPGA_VERSION = 32'h0393007b; // lvcmos25_lvds_25_diff
// parameter FPGA_VERSION = 32'h0393007a; // lvcmos25_ppds_25_nodiff - OK
// parameter FPGA_VERSION = 32'h03930079; // diff - failed
// parameter FPGA_VERSION = 32'h03930078; // lvcmos18_ppds_25_nodiff
// parameter FPGA_VERSION = 32'h03930077; // Restoring IOSTANDARDs - OK
// parameter FPGA_VERSION = 32'h03930076; // Trying PPDS_25 with 1.8 actual power - Stuck when applying 1.8 or 2.5V
// parameter FPGA_VERSION = 32'h03930075; // Trying IN_TERM = "UNTUNED_50"
// parameter FPGA_VERSION = 32'h03930074; // Adding SATA controller 16365 ( 83.28%)
// parameter FPGA_VERSION = 32'h03930073; // Adding interrupts support
// parameter FPGA_VERSION = 32'h03930072; // Adding hact monitor bit 77.9%, failed timing
// parameter FPGA_VERSION = 32'h03930071; // Fixing AXI HP multiplexer xclk -0.083 -1.968 44 / 15163 (77.17%)
// parameter FPGA_VERSION = 32'h03930070; // Fixing HiSPi xclk -0.049 -0.291 17, utilization 15139 (77.04%)
// parameter FPGA_VERSION = 32'h0393006f; // Fixing JP4 mode - xcl -0.002 -0.004 2, utilization 15144 (77.07 %)
// parameter FPGA_VERSION = 32'h0393006f; // Fixing JP4 mode - xclk -0.209/-2.744/23, utilization  15127 (76.98%)
// parameter FPGA_VERSION = 32'h0393006e; // Trying lane switch again after bug fix, failing 1 in  ddr3_mclk -> ddr3_clk_div by  -0.023
// parameter FPGA_VERSION = 32'h0393006d; // -1 with lane switch - does not work
// parameter FPGA_VERSION = 32'h0393006d; // Reversing pixels/lanes order xclk violated -0.154
// parameter FPGA_VERSION = 32'h0393006c; // will try debug for HiSPi.  xclk violated by -0.030, slices 15062 (76.65%)
// parameter FPGA_VERSION = 32'h0393006b; // Correcting sensor external clock generation - was wrong division. xclk violated by 0.095 ns
// parameter FPGA_VERSION = 32'h0393006a; // modified clock generation, trying with HiSPi - 72.77% utilization x40..x60
// parameter FPGA_VERSION = 32'h03930069; // modified clock generation, rebuilding for parallel sensors - all met, 71.8% utilization
                                                      // Worked OK, but different phase for sensor 0 (all quadrants as 1,3 OK)
// parameter FPGA_VERSION = 32'h03930068; // trying BUFR/FUFIO on all sensors ipclk/ipclk2x
// parameter FPGA_VERSION = 32'h03930067; // removing DUMMY_TO_KEEP, moving IOSTANDARD to HDL code
// parameter FPGA_VERSION = 32'h03930066; // trying just one histogram to watch utilization - with 4 was: Slice 15913 (80.98%), now Slice = 14318 (72.87%)
// parameter FPGA_VERSION = 32'h03930065; // (same rev) all met,  using "old" (non-inverted) phase - OK (full phase range)
// parameter FPGA_VERSION = 32'h03930065; // switch phy_top.v (all met) - OK with inverted phase control (reduced phase range)
// parameter FPGA_VERSION = 32'h03930064; // switch mcomtr_sequencer.v  (xclk not met) - wrong!
// parameter FPGA_VERSION = 32'h03930063; // switch mcntrl_linear_rw.v (met) good, worse mem valid phases 
// parameter FPGA_VERSION = 32'h03930062; // (met)debugging - what was broken (using older versions of some files) - mostly OK (some glitches)
// parameter FPGA_VERSION = 32'h03930061; // restored bufr instead of bufio for memory high speed clock
// parameter FPGA_VERSION = 32'h03930060; // moving CLK1..3 in memory controller MMCM, keeping CLK0 and FB. Stuck at memory calib 
// parameter FPGA_VERSION = 32'h0393005f; // restored mclk back to 200KHz, registers added to csconvert18a
// parameter FPGA_VERSION = 32'h0393005e; // trying mclk = 225 MHz (was 200MHz) define MCLK_VCO_MULT 18
// parameter FPGA_VERSION = 32'h0393005d; // trying mclk = 250 MHz (was 200MHz) define MCLK_VCO_MULT 20
// parameter FPGA_VERSION = 32'h0393005c; // 250MHz OK, no timing violations
// parameter FPGA_VERSION = 32'h0393005b; // 250MHz Not tested, timing violation in bit_stuffer_escape: xclk -0.808 -142.047 515
// parameter FPGA_VERSION = 32'h0393005a; // Trying xclk = 250MHz - timing viloations in xdct393, but particular hardware works
// parameter FPGA_VERSION = 32'h03930059; // 'new' (no pclk2x, no xclk2x  clocks) sensor/converter w/o debug - OK
// parameter FPGA_VERSION = 32'h03930058; // 'new' (no pclk2x, no xclk2x  clocks) sensor/converter w/o debug - broken end of frame
// parameter FPGA_VERSION = 32'h03930057; // 'new' (no pclk2x, yes xclk2x  clocks) sensor/converter w/o debug - OK
// parameter FPGA_VERSION = 32'h03930056; // 'new' (no 2x clocks) sensor/converter w/o debug - broken
// parameter FPGA_VERSION = 32'h03930055; // 'old' sensor/converter w/o debug, fixed bug with irst - OK
// parameter FPGA_VERSION = 32'h03930054; // 'old' sensor/converter with debug
// parameter FPGA_VERSION = 32'h03930053; // trying if(reset ) reg <- 'bx    
