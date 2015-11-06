      parameter FPGA_VERSION =          32'h03930065; // (same rev) all met,  using "old" (non-inverted) phase - OK (full phase range)
//      parameter FPGA_VERSION =          32'h03930065; // switch phy_top.v (all met) - OK with inverted phase control (reduced phase range)
//      parameter FPGA_VERSION =          32'h03930064; // switch mcomtr_sequencer.v  (xclk not met) - wrong!
//      parameter FPGA_VERSION =          32'h03930063; // switch mcntrl_linear_rw.v (met) good, worse mem valid phases 
//      parameter FPGA_VERSION =          32'h03930062; // (met)debugging - what was broken (using older versions of some files) - mostly OK (some glitches)
//      parameter FPGA_VERSION =          32'h03930061; // restored bufr instead of bufio for memory high speed clock
//      parameter FPGA_VERSION =          32'h03930060; // moving CLK1..3 in memory controller MMCM, keeping CLK0 and FB. Stuck at memory calib 
//      parameter FPGA_VERSION =          32'h0393005f; // restored mclk back to 200KHz, registers added to csconvert18a
//      parameter FPGA_VERSION =          32'h0393005e; // trying mclk = 225 MHz (was 200MHz) define MCLK_VCO_MULT 18
//      parameter FPGA_VERSION =          32'h0393005d; // trying mclk = 250 MHz (was 200MHz) define MCLK_VCO_MULT 20
//      parameter FPGA_VERSION =          32'h0393005c; // 250MHz OK, no timing violations
//    parameter FPGA_VERSION =          32'h0393005b; // 250MHz Not tested, timing violation in bit_stuffer_escape: xclk -0.808 -142.047 515
//    parameter FPGA_VERSION =          32'h0393005a; // Trying xclk = 250MHz - timing viloations in xdct393, but particular hardware works
//    parameter FPGA_VERSION =          32'h03930059; // 'new' (no pclk2x, no xclk2x  clocks) sensor/converter w/o debug - OK
//    parameter FPGA_VERSION =          32'h03930058; // 'new' (no pclk2x, no xclk2x  clocks) sensor/converter w/o debug - broken end of frame
//    parameter FPGA_VERSION =          32'h03930057; // 'new' (no pclk2x, yes xclk2x  clocks) sensor/converter w/o debug - OK
//    parameter FPGA_VERSION =          32'h03930056; // 'new' (no 2x clocks) sensor/converter w/o debug - broken
//    parameter FPGA_VERSION =          32'h03930055; // 'old' sensor/converter w/o debug, fixed bug with irst - OK
//    parameter FPGA_VERSION =          32'h03930054; // 'old' sensor/converter with debug
//    parameter FPGA_VERSION =          32'h03930053; // trying if(reset ) reg <- 'bx    