  // This file may be used to define same pre-processor macros to be included into each parsed file
`ifndef SYSTEM_DEFINES
  `define SYSTEM_DEFINES
  `define PRELOAD_BRAMS
// Enviroment-dependent options
  `ifdef IVERILOG
    `define SIMULATION
    `define OPEN_SOURCE_ONLY
  `else
    `ifdef CVC
      `define SIMULATION
      `define OPEN_SOURCE_ONLY
    `endif // CVC
  `endif // IVERILOG
  
// will not use simultaneous reset in shift registers, just and input data with ~rst  
 `define SHREG_SEQUENTIAL_RESET 1
// synthesis does to recognize global clock as G input of the primitive latch 
 `undef INFER_LATCHES
 // define when using CDC - it does not support them
 `undef IGNORE_ATTR
//`define MEMBRIDGE_DEBUG_READ 1
  `define use200Mhz 1
  `define USE_CMD_ENCOD_TILED_32_RD 1  
  // It can be used to check different `ifdef branches
  //`define XIL_TIMING //Simprim 
  `define den4096Mb 1
//  `define IVERILOG
  // defines for memory channels
  // chn 0 is read from memory and write to memory
 `define def_enable_mem_chn0
 `define def_read_mem_chn0
 `define def_write_mem_chn0
 `undef  def_scanline_chn0
 `undef  def_tiled_chn0
 
  // chn 1 is scanline r+w
 `define  def_enable_mem_chn1
 `define  def_read_mem_chn1
 `define  def_write_mem_chn1
 `define  def_scanline_chn1
 `undef   def_tiled_chn1

  // chn 2 is tiled r+w
 `define  def_enable_mem_chn2
 `define  def_read_mem_chn2
 `define  def_write_mem_chn2
 `undef   def_scanline_chn2
 `define  def_tiled_chn2

  // chn 3 is scanline r+w (reuse later)
 `define  def_enable_mem_chn3
 `define  def_read_mem_chn3
 `define  def_write_mem_chn3
 `define  def_scanline_chn3
 `undef   def_tiled_chn3

  // chn 4 is tiled r+w (reuse later)
 `define  def_enable_mem_chn4
 `define  def_read_mem_chn4
 `define  def_write_mem_chn4
 `undef   def_scanline_chn4
 `define  def_tiled_chn4

  // chn 5 is disabled
 `undef def_enable_mem_chn5

  // chn 6 is disabled
 `undef  def_enable_mem_chn6
 
  // chn 7 is disabled
 `undef  def_enable_mem_chn7
 
  // chn 8 is scanline w (sensor channel 0)
 `define  def_enable_mem_chn8
 `undef   def_read_mem_chn8
 `define  def_write_mem_chn8
 `define  def_scanline_chn8
 `undef   def_tiled_chn8

  // chn 9 is scanline w (sensor channel 1)
 `define  def_enable_mem_chn9
 `undef   def_read_mem_chn9
 `define  def_write_mem_chn9
 `define  def_scanline_chn9
 `undef   def_tiled_chn9

  // chn 10 is scanline w (sensor channel 2)
 `define  def_enable_mem_chn10
 `undef   def_read_mem_chn10
 `define  def_write_mem_chn10
 `define  def_scanline_chn10
 `undef   def_tiled_chn10

  // chn 11 is scanline w (sensor channel 3)
 `define  def_enable_mem_chn11
 `undef   def_read_mem_chn11
 `define  def_write_mem_chn11
 `define  def_scanline_chn11
 `undef   def_tiled_chn11

  // chn 12 is tiled read (compressor channel 0)
 `define  def_enable_mem_chn12
 `define  def_read_mem_chn12
 `undef   def_write_mem_chn12
 `undef   def_scanline_chn12
 `define  def_tiled_chn12
 
  // chn 12 is tiled read (compressor channel 1)
 `define  def_enable_mem_chn13
 `define  def_read_mem_chn13
 `undef   def_write_mem_chn13
 `undef   def_scanline_chn13
 `define  def_tiled_chn13
 
  // chn 12 is tiled read (compressor channel 2)
 `define  def_enable_mem_chn14
 `define  def_read_mem_chn14
 `undef   def_write_mem_chn14
 `undef   def_scanline_chn14
 `define  def_tiled_chn14
 
  // chn 12 is tiled read (compressor channel 3)
 `define  def_enable_mem_chn15
 `define  def_read_mem_chn15
 `undef   def_write_mem_chn15
 `undef   def_scanline_chn15
 `define  def_tiled_chn15
`endif
 