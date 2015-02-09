  // This file may be used to define same pre-processor macros to be included into each parsed file

// TODO: Fix VDT - without IVERILOG defined, closure does not include modules needed for Icarus
`define IVERILOG 1
  
  // It can be used to check different `ifdef branches
  //`define XIL_TIMING //Simprim 
  `define den4096Mb 1
//  `define IVERILOG
  // defines for memory channels
  // chn 0 is read from memory
 `define def_enable_mem_chn0
 `define def_read_mem_chn0
 `undef  def_scanline_chn0
 
  // chn 1 is write to memory
 `define def_enable_mem_chn1
 `undef  def_read_mem_chn1
 `undef  def_scanline_chn1

  // chn 2 is read from memory
 `define def_enable_mem_chn2
 `define def_read_mem_chn2
 `define def_scanline_chn2

  // chn 3 is write to memory
 `define def_enable_mem_chn3
 `undef  def_read_mem_chn3
 `define def_scanline_chn3

  // chn 4 is enabled
 `define def_enable_mem_chn4
 `define def_read_mem_chn4
 `define def_tiled_chn4

  // chn 5 is disabled
 `undef  def_enable_mem_chn5

  // chn 6 is disabled
 `undef  def_enable_mem_chn6
 
  // chn 7 is disabled
 `undef  def_enable_mem_chn7
 
  // chn 8 is disabled
 `undef  def_enable_mem_chn8
 
  // chn 9 is disabled
 `undef  def_enable_mem_chn9
 
  // chn 10 is disabled
 `undef  def_enable_mem_chn10
 
  // chn 11 is disabled
 `undef  def_enable_mem_chn11
 
  // chn 12 is disabled
 `undef  def_enable_mem_chn12
 
  // chn 13 is disabled
 `undef  def_enable_mem_chn13
 
  // chn 14 is disabled
 `undef  def_enable_mem_chn14
 
  // chn 15 is disabled
 `undef  def_enable_mem_chn15
 
 