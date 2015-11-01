      parameter FPGA_VERSION =          32'h0393005c; // 250MHz ???
//    parameter FPGA_VERSION =          32'h0393005b; // 250MHz Not tested, timing violation in bit_stuffer_escape: xclk -0.808 -142.047 515
//    parameter FPGA_VERSION =          32'h0393005a; // Trying xclk = 250MHz - timing viloations in xdct393, but particular hardware works
//    parameter FPGA_VERSION =          32'h03930059; // 'new' (no pclk2x, no xclk2x  clocks) sensor/converter w/o debug - OK
//    parameter FPGA_VERSION =          32'h03930058; // 'new' (no pclk2x, no xclk2x  clocks) sensor/converter w/o debug - broken end of frame
//    parameter FPGA_VERSION =          32'h03930057; // 'new' (no pclk2x, yes xclk2x  clocks) sensor/converter w/o debug - OK
//    parameter FPGA_VERSION =          32'h03930056; // 'new' (no 2x clocks) sensor/converter w/o debug - broken
//    parameter FPGA_VERSION =          32'h03930055; // 'old' sensor/converter w/o debug, fixed bug with irst - OK
//    parameter FPGA_VERSION =          32'h03930054; // 'old' sensor/converter with debug
//    parameter FPGA_VERSION =          32'h03930053; // trying if(reset ) reg <- 'bx    