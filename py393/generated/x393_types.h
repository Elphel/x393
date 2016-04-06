/*******************************************************************************
 * File: x393_types.h
 * Date: 2016-04-06  
 * Author: auto-generated file, see x393_export_c.py
 * Description: typedef definitions for the x393 hardware registers
 *******************************************************************************/

// Status generation control 

typedef union {
    struct {
          u32         seq_num: 6; // [ 5: 0] (0) 6-bit sequence number to be used with the next status response
          u32            mode: 2; // [ 7: 6] (3) Status report mode: 0 - disable, 1 - single, 2 - auto, keep sequence number, 3 - auto, inc. seq. number 
          u32                :24;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_status_ctrl_t; 

// Memory channel operation mode

typedef union {
    struct {
          u32          enable: 1; // [    0] (1) enable requests from this channel ( 0 will let current to finish, but not raise want/need)
          u32      chn_nreset: 1; // [    1] (1) 0: immediately reset all the internal circuitry
          u32       write_mem: 1; // [    2] (0) 0 - read from memory, 1 - write to memory
          u32     extra_pages: 2; // [ 4: 3] (0) 2-bit number of extra pages that need to stay (not to be overwritten) in the buffer
          u32       keep_open: 1; // [    5] (0) for 8 or less rows - do not close page between accesses (not used in scanline mode)
          u32          byte32: 1; // [    6] (1) 32-byte columns (0 - 16-byte), not used in scanline mode
          u32                : 1;
          u32     reset_frame: 1; // [    8] (0) reset frame number
          u32          single: 1; // [    9] (0) run single frame
          u32      repetitive: 1; // [   10] (1) run repetitive frames
          u32    disable_need: 1; // [   11] (0) disable 'need' generation, only 'want' (compressor channels)
          u32   skip_too_late: 1; // [   12] (0) Skip over missed blocks to preserve frame structure (increment pointers)
          u32                :19;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_mcntrl_mode_scan_t; 

// Memory channel window tile size/step (tiled only)

typedef union {
    struct {
          u32      tile_width: 6; // [ 5: 0] (2) tile width in 8-bursts (16 bytes)
          u32                : 2;
          u32     tile_height: 6; // [13: 8] (0x12) tile height in lines (0 means 64 lines)
          u32                : 2;
          u32       vert_step: 8; // [23:16] (0x10) Tile vertical step to control tile overlap
          u32                : 8;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_mcntrl_window_tile_whs_t; 

// Memory channel window size

typedef union {
    struct {
          u32           width:13; // [12: 0] (0) 13-bit window width - in 8*16=128 bit bursts
          u32                : 3;
          u32          height:16; // [31:16] (0) 16-bit window height in scan lines
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_mcntrl_window_width_height_t; 

// Memory channel window position

typedef union {
    struct {
          u32            left:13; // [12: 0] (0) 13-bit window left margin in 8-bursts (16 bytes)
          u32                : 3;
          u32             top:16; // [31:16] (0) 16-bit window top margin in scan lines
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_mcntrl_window_left_top_t; 

// Memory channel scan start (debug feature)

typedef union {
    struct {
          u32         start_x:13; // [12: 0] (0) 13-bit window start X relative to window left margin (debug feature, set = 0)
          u32                : 3;
          u32         start_y:16; // [31:16] (0) 16-bit window start Y relative to window top margin (debug feature, set = 0)
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_mcntrl_window_startx_starty_t; 

// Memory channel window full (padded) width

typedef union {
    struct {
          u32      full_width:13; // [12: 0] (0) 13-bit Padded line length (8-row increment), in 8-bursts (16 bytes)
          u32                :19;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_mcntrl_window_full_width_t; 

// Memory channel last frame number in a buffer (number of frames minus 1)

typedef union {
    struct {
          u32  last_frame_num:16; // [15: 0] (0) 16-bit number of the last frame in a buffer (1 for a 2-frame ping-pong one)
          u32                :16;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_mcntrl_window_last_frame_num_t; 

// Memory channel frame start address increment (for next frame in a buffer)

typedef union {
    struct {
          u32    frame_sa_inc:22; // [21: 0] (0) 22-bit frame start address increment  (3 CA LSBs==0. BA==0)
          u32                :10;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_mcntrl_window_frame_sa_inc_t; 

// Memory channel frame start address for the first frame in a buffer

typedef union {
    struct {
          u32        frame_sa:22; // [21: 0] (0) 22-bit frame start address (3 CA LSBs==0. BA==0)
          u32                :10;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_mcntrl_window_frame_sa_t; 

// PS PIO (software-programmed DDR3) access sequences enable and reset

typedef union {
    struct {
          u32            nrst: 1; // [    0] (1) Active-low reset for programmed DDR3 memory sequences
          u32              en: 1; // [    1] (1) Enable PS_PIO channel. Only influences request for arbitration, started transactions will finish if disabled
          u32                :30;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_ps_pio_en_rst_t; 

// PS PIO (software-programmed DDR3) access sequences control

typedef union {
    struct {
          u32        seq_addr:10; // [ 9: 0] (0) Sequence start address
          u32            page: 2; // [11:10] (0) Buffer page number
          u32          urgent: 1; // [   12] (0) high priority request (only for competition with other channels, will not pass in this FIFO)
          u32             chn: 1; // [   13] (0) channel buffer to use: 0 - memory read, 1 - memory write
          u32   wait_complete: 1; // [   14] (0) Do not request a new transaction from the scheduler until previous memory transaction is finished
          u32                :17;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_ps_pio_cmd_t; 

// x393 generic status register

typedef union {
    struct {
          u32        status24:24; // [23: 0] (0) 24-bit status payload ([25:2] in Verilog
          u32         status2: 2; // [25:24] (0) 2-bit status payload (2 LSB in Verilog)
          u32         seq_num: 6; // [31:26] (0) Sequence number
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_status_t; 

// Memory PHY status

typedef union {
    struct {
          u32          ps_out: 8; // [ 7: 0] (0) Current MMCM phase shift
          u32        run_busy: 1; // [    8] (0) Controller sequence in progress
          u32      locked_pll: 1; // [    9] (0) PLL is locked
          u32     locked_mmcm: 1; // [   10] (0) MMCM is locked
          u32       dci_ready: 1; // [   11] (0) DCI calibration is ready
          u32       dly_ready: 1; // [   12] (0) I/O delays calibration is ready
          u32                :11;
          u32          ps_rdy: 1; // [   24] (0) Phase change is done
          u32          locked: 1; // [   25] (0) Both PLL and MMCM are locked
          u32         seq_num: 6; // [31:26] (0) Sequence number
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_status_mcntrl_phy_t; 

// Memory controller requests status

typedef union {
    struct {
          u32        chn_want:16; // [15: 0] (0) Bit mask of the channels that request memory access
          u32                : 8;
          u32       want_some: 1; // [   24] (0) At least one channel requests memory access (normal priority)
          u32       need_some: 1; // [   25] (0) At least one channel requests urgent memory access (high priority)
          u32         seq_num: 6; // [31:26] (0) Sequence number
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_status_mcntrl_top_t; 

// Memory software access status

typedef union {
    struct {
          u32                :24;
          u32   cmd_half_full: 1; // [   24] (0) MCNTRL software access pending commands FIFO is half full
          u32 cmd_nempty_busy: 1; // [   25] (0) MCNTRL software access pending commands FIFO is not empty or command is running
          u32         seq_num: 6; // [31:26] (0) Sequence number
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_status_mcntrl_ps_t; 

// Memory test channels access status

typedef union {
    struct {
          u32                :24;
          u32            busy: 1; // [   24] (0) Channel is busy (started and some memory accesses are pending)
          u32  frame_finished: 1; // [   25] (0) Channel completed all memory accesses
          u32         seq_num: 6; // [31:26] (0) Sequence number
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_status_mcntrl_lintile_t; 

// Memory test channels status

typedef union {
    struct {
          u32 line_unfinished:16; // [15: 0] (0) Current unfinished frame line
          u32            page: 4; // [19:16] (0) Current page number read/written through a channel (low bits)
          u32                : 4;
          u32      frame_busy: 1; // [   24] (0) Channel is busy (started and some memory accesses are pending)
          u32  frame_finished: 1; // [   25] (0) Channel completed all memory accesses
          u32         seq_num: 6; // [31:26] (0) Sequence number
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_status_mcntrl_testchn_t; 

// Membridge channel status

typedef union {
    struct {
          u32        wresp_conf: 8; // [ 7: 0] (0) Number of 64-bit words confirmed through axi b channel (low bits)
          u32 axi_arw_requested: 8; // [15: 8] (0) Number of 64-bit words to be read/written over axi queued to AR/AW channels (low bits)
          u32                  : 8;
          u32              busy: 1; // [   24] (0) Membridge operation in progress
          u32              done: 1; // [   25] (0) Membridge operation finished
          u32           seq_num: 6; // [31:26] (0) Sequence number
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_status_membridge_t; 

// Sensor/multiplexer I/O pins status

typedef union {
    struct {
          u32                 ps_out: 8; // [ 7: 0] (0) Sensor MMCM current phase
          u32                 ps_rdy: 1; // [    8] (0) Sensor MMCM phase ready
          u32              xfpgadone: 1; // [    9] (0) Multiplexer FPGA DONE output
          u32 clkfb_pxd_stopped_mmcm: 1; // [   10] (0) Sensor MMCM feedback clock stopped
          u32 clkin_pxd_stopped_mmcm: 1; // [   11] (0) Sensor MMCM input clock stopped
          u32        locked_pxd_mmcm: 1; // [   12] (0) Sensor MMCM locked
          u32             hact_alive: 1; // [   13] (0) HACT signal from the sensor (or internal) is toggling (N/A for HiSPI
          u32         hact_ext_alive: 1; // [   14] (0) HACT signal from the sensor is toggling (N/A for HiSPI)
          u32             vact_alive: 1; // [   15] (0) VACT signal from the sensor is toggling (N/A for HiSPI)
          u32                       : 8;
          u32              senspgmin: 1; // [   24] (0) senspgm pin state
          u32               xfpgatdo: 1; // [   25] (0) Multiplexer FPGA TDO output
          u32                seq_num: 6; // [31:26] (0) Sequence number
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_status_sens_io_t; 

// Sensor/multiplexer i2c status

typedef union {
    struct {
          u32   i2c_fifo_dout: 8; // [ 7: 0] (0) I2c byte read from the device through FIFO
          u32 i2c_fifo_nempty: 1; // [    8] (0) I2C read FIFO has data
          u32  i2c_fifo_cntrl: 1; // [    9] (0) I2C FIFO byte counter (odd/even bytes)
          u32            busy: 1; // [   10] (0) I2C sequencer busy
          u32        alive_fs: 1; // [   11] (0) Sensor generated frame sync since last status update
          u32       frame_num: 4; // [15:12] (0) I2C sequencer frame number
          u32         req_clr: 1; // [   16] (0) Request for clearing fifo_wp (delay frame sync if previous is not yet sent out)
          u32        reset_on: 1; // [   17] (0) Reset in progress
          u32                : 6;
          u32          scl_in: 1; // [   24] (0) SCL pin state
          u32          sda_in: 1; // [   25] (0) SDA pin state
          u32         seq_num: 6; // [31:26] (0) Sequence number
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_status_sens_i2c_t; 

// Command bits for test01 module (test frame memory accesses)

typedef union {
    struct {
          u32     frame_start: 1; // [    0] (0) start frame command
          u32       next_page: 1; // [    1] (0) Next page command
          u32         suspend: 1; // [    2] (0) Suspend command
          u32                :29;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_test01_mode_t; 

// Command for membridge

typedef union {
    struct {
          u32          enable: 1; // [    0] (0) enable membridge
          u32     start_reset: 2; // [ 2: 1] (0) 1 - start (from current address), 3 - start from reset address
          u32                :29;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_membridge_cmd_t; 

// Cache mode for membridge

typedef union {
    struct {
          u32       axi_cache: 4; // [ 3: 0] (3) AXI CACHE value (ignored by Zynq)
          u32     debug_cache: 1; // [    4] (0) 0 - normal operation, 1 debug (replace data)
          u32                :27;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_membridge_mode_t; 

// Address in 64-bit words

typedef union {
    struct {
          u32          addr64:29; // [28: 0] (0) Address/length in 64-bit words (<<3 to get byte address
          u32                : 3;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} u29_t; 

// I2C contol/table data

typedef union {
    struct {
          u32        tbl_addr: 8; // [ 7: 0] (0) Address/length in 64-bit words (<<3 to get byte address)
          u32                :20;
          u32        tbl_mode: 2; // [29:28] (3) Should be 3 to select table address write mode
          u32                : 2;
    }; 
    struct {
          u32             rah: 8; // [ 7: 0] (0) High byte of the i2c register address
          u32             rnw: 1; // [    8] (0) Read/not write i2c register, should be 0 here
          u32              sa: 7; // [15: 9] (0) Slave address in write mode
          u32            nbwr: 4; // [19:16] (0) Number of bytes to write (1..10)
          u32             dly: 8; // [27:20] (0) Bit delay - number of mclk periods in 1/4 of the SCL period
          u32    /*tbl_mode*/: 2; // [29:28] (2) Should be 2 to select table data write mode
          u32                : 2;
    }; 
    struct {
          u32         /*rah*/: 8; // [ 7: 0] (0) High byte of the i2c register address
          u32         /*rnw*/: 1; // [    8] (0) Read/not write i2c register, should be 1 here
          u32                : 7;
          u32            nbrd: 3; // [18:16] (0) Number of bytes to read (1..18, 0 means '8')
          u32           nabrd: 1; // [   19] (0) Number of address bytes for read (0 - one byte, 1 - two bytes)
          u32         /*dly*/: 8; // [27:20] (0) Bit delay - number of mclk periods in 1/4 of the SCL period
          u32    /*tbl_mode*/: 2; // [29:28] (2) Should be 2 to select table data write mode
          u32                : 2;
    }; 
    struct {
          u32  sda_drive_high: 1; // [    0] (0) Actively drive SDA high during second half of SCL==1 (valid with drive_ctl)
          u32     sda_release: 1; // [    1] (0) Release SDA early if next bit ==1 (valid with drive_ctl)
          u32       drive_ctl: 1; // [    2] (0) 0 - nop, 1 - set sda_release and sda_drive_high
          u32    next_fifo_rd: 1; // [    3] (0) Advance I2C read FIFO pointer
          u32        soft_scl: 2; // [ 5: 4] (0) Control SCL pin (when stopped): 0 - nop, 1 - low, 2 - high (driven), 3 - float 
          u32        soft_sda: 2; // [ 7: 6] (0) Control SDA pin (when stopped): 0 - nop, 1 - low, 2 - high (driven), 3 - float 
          u32                : 4;
          u32         cmd_run: 2; // [13:12] (0) Sequencer run/stop control: 0,1 - nop, 2 - stop, 3 - run 
          u32           reset: 1; // [   14] (0) Sequencer reset all FIFO (takes 16 clock pulses), also - stops i2c until run command
          u32                :13;
          u32    /*tbl_mode*/: 2; // [29:28] (0) Should be 0 to select controls
          u32                : 2;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_i2c_ctltbl_t; 

// Write sensor channel mode register

typedef union {
    struct {
          u32         hist_en: 4; // [ 3: 0] (0xf) Enable subchannel histogram modules (may be less than 4)
          u32       hist_nrst: 4; // [ 7: 4] (0xf) Reset off for histograms subchannels (may be less than 4)
          u32          chn_en: 1; // [    8] (1) Enable this sensor channel
          u32           bit16: 1; // [    9] (0) 0 - 8 bpp mode, 1 - 16 bpp (bypass gamma). Gamma-processed data is still used for histograms
          u32                :22;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_sens_mode_t; 

// Write number of sensor frames to combine into one virtual (linescan mode)

typedef union {
    struct {
          u32     mult_frames:16; // [15: 0] (0) Number of frames to combine into one minus 1 (0 - single,1 - two frames...)
          u32                :16;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_sens_sync_mult_t; 

// Write sensor number of lines to delay frame sync

typedef union {
    struct {
          u32     mult_frames:16; // [15: 0] (0) Number of lines to delay late frame sync
          u32                :16;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_sens_sync_late_t; 

// Configure memory controller priorities

typedef union {
    struct {
          u32        priority:16; // [15: 0] (0) Channel priority (the larger the higher)
          u32                :16;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_arbite_pri_t; 

// Enable/disable memory controller channels

typedef union {
    struct {
          u32          chn_en:16; // [15: 0] (0) Enabled memory channels
          u32                :16;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_mcntr_chn_en_t; 

// DQS and DQM patterns (DQM - 0, DQS 0xaa or 0x55)

typedef union {
    struct {
          u32        dqs_patt: 8; // [ 7: 0] (0xaa) DQS pattern: 0xaa/0x55
          u32        dqm_patt: 8; // [15: 8] (0) DQM pattern: 0x0
          u32                :16;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_mcntr_dqs_dqm_patt_t; 

// DQ and DQS tristate control when turning on and off

typedef union {
    struct {
          u32    dq_tri_first: 4; // [ 3: 0] (3) DQ tristate  start (0x3,0x7,0xf); early, nominal, late
          u32     dq_tri_last: 4; // [ 7: 4] (0xe) DQ tristate  end   (0xf,0xe,0xc); early, nominal, late
          u32   dqs_tri_first: 4; // [11: 8] (1) DQS tristate start (0x1,0x3,0x7); early, nominal, late
          u32    dqs_tri_last: 4; // [15:12] (0xc) DQS tristate end   (0xe,0xc,0x8); early, nominal, late
          u32                :16;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_mcntr_dqs_dqm_tri_t; 

// DDR3 memory controller I/O delay

typedef union {
    struct {
          u32             dly: 8; // [ 7: 0] (0) 8-bit delay value: 5MSBs(0..31) and 3LSBs(0..4)
          u32                :24;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_dly_t; 

// Extra delay in mclk (fDDR/2) cycles) to data write buffer

typedef union {
    struct {
          u32        wbuf_dly: 4; // [ 3: 0] (9) Extra delay in mclk (fDDR/2) cycles) to data write buffer
          u32                :28;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_wbuf_dly_t; 

// Control for the gamma-conversion module

typedef union {
    struct {
          u32           bayer: 2; // [ 1: 0] (0) Bayer color shift (pixel to gamma table)
          u32            page: 1; // [    2] (0) Table page (only available if SENS_GAMMA_BUFFER in Verilog)
          u32              en: 1; // [    3] (1) Enable module
          u32           repet: 1; // [    4] (1) Repetitive (normal) mode. Set 0 for testing of the single-frame mode
          u32            trig: 1; // [    5] (0) Single trigger used when repetitive mode is off (self clearing bit)
          u32                :26;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_gamma_ctl_t; 

// Write gamma table address/data

typedef union {
    struct {
          u32            addr: 8; // [ 7: 0] (0) Start address in a gamma page (normally 0)
          u32           color: 2; // [ 9: 8] (0) Color channel
          u32         sub_chn: 2; // [11:10] (0) Sensor sub-channel (multiplexed to the same port)
          u32                : 8;
          u32           a_n_d: 1; // [   20] (1) Address/not data, should be set to 1 here
          u32                :11;
    }; 
    struct {
          u32            base:10; // [ 9: 0] (0) Knee point value (to be interpolated between)
         char            diff: 7; // [16:10] (0) Difference to next (signed, -64..+63)
          u32      diff_scale: 1; // [   17] (0) Difference scale: 0 - keep diff, 1- multiply diff by 16
          u32                :14;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_gamma_tbl_t; 

// Heights of the first two subchannels frames

typedef union {
    struct {
          u32       height0m1:16; // [15: 0] (0) Height of subchannel 0 frame minus 1
          u32       height1m1:16; // [31:16] (0) Height of subchannel 1 frame minus 1
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_gamma_height01m1_t; 

// Height of the third subchannel frame

typedef union {
    struct {
          u32       height2m1:16; // [15: 0] (0) Height of subchannel 2 frame minus 1
          u32                :16;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_gamma_height2m1_t; 

// Sensor port I/O control

typedef union {
    struct {
          u32            mrst: 1; // [    0] (0) MRST signal level to the sensor (0 - low(active), 1 - high (inactive)
          u32        mrst_set: 1; // [    1] (0) when set to 1, MRST is set  to the 'mrst' field value
          u32            arst: 1; // [    2] (0) ARST signal to the sensor
          u32        arst_set: 1; // [    3] (0) ARST set  to the 'arst' field
          u32             aro: 1; // [    4] (0) ARO signal to the sensor
          u32         aro_set: 1; // [    5] (0) ARO set to the 'aro' field
          u32        mmcm_rst: 1; // [    6] (0) MMCM (for sensor clock) reset signal
          u32    mmcm_rst_set: 1; // [    7] (0) MMCM reset set to  'mmcm_rst' field
          u32         ext_clk: 1; // [    8] (0) MMCM clock input: 0: clock to the sensor, 1 - clock from the sensor
          u32     ext_clk_set: 1; // [    9] (0) Set MMCM clock input to 'ext_clk' field
          u32         set_dly: 1; // [   10] (0) Set all pre-programmed delays to the sensor port input delays
          u32                : 1;
          u32       quadrants: 6; // [17:12] (1) 90-degree shifts for data [1:0], hact [3:2] and vact [5:4]
          u32                : 2;
          u32   quadrants_set: 1; // [   20] (0) Set 'quadrants' values
          u32                :11;
    }; 
    struct {
          u32        /*mrst*/: 1; // [    0] (0) MRST signal level to the sensor (0 - low(active), 1 - high (inactive)
          u32    /*mrst_set*/: 1; // [    1] (0) when set to 1, MRST is set  to the 'mrst' field value
          u32        /*arst*/: 1; // [    2] (0) ARST signal to the sensor
          u32    /*arst_set*/: 1; // [    3] (0) ARST set  to the 'arst' field
          u32         /*aro*/: 1; // [    4] (0) ARO signal to the sensor
          u32     /*aro_set*/: 1; // [    5] (0) ARO set to the 'aro' field
          u32    /*mmcm_rst*/: 1; // [    6] (0) MMCM (for sensor clock) reset signal
          u32 /*mmcm_rst_set*/: 1; // [    7] (0) MMCM reset set to  'mmcm_rst' field
          u32       ign_embed: 1; // [    8] (0) Ignore embedded data (non-image pixel lines
          u32   ign_embed_set: 1; // [    9] (0) Set mode to 'ign_embed' field
          u32     /*set_dly*/: 1; // [   10] (0) Set all pre-programmed delays to the sensor port input delays
          u32                : 1;
          u32             gp0: 1; // [   12] (0) GP0 multipurpose signal to the sensor
          u32         gp0_set: 1; // [   13] (0) Set GP0 to 'gp0' value
          u32             gp1: 1; // [   14] (0) GP1 multipurpose signal to the sensor
          u32         gp1_set: 1; // [   15] (0) Set GP1 to 'gp1' value
          u32                :16;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_sensio_ctl_t; 

// Programming interface for multiplexer FPGA

typedef union {
    struct {
          u32             tdi: 1; // [    0] (0) JTAG TDI level
          u32         tdi_set: 1; // [    1] (0) JTAG TDI set to 'tdi' field
          u32             tms: 1; // [    2] (0) JTAG TMS level
          u32         tms_set: 1; // [    3] (0) JTAG TMS set to 'tms' field
          u32             tck: 1; // [    4] (0) JTAG TCK level
          u32         tck_set: 1; // [    5] (0) JTAG TCK set to 'tck' field
          u32            prog: 1; // [    6] (0) Sensor port PROG level
          u32        prog_set: 1; // [    7] (0) Sensor port PROG set to 'prog' field
          u32           pgmen: 1; // [    8] (0) Sensor port PGMEN level
          u32       pgmen_set: 1; // [    9] (0) Sensor port PGMEN set to 'pgmen' field
          u32                :22;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_sensio_jtag_t; 

// Sensor i/o timing register 0 (different meanings for different sensor types)

typedef union {
    struct {
          u32            pxd0: 8; // [ 7: 0] (0) PXD0  input delay (3 LSB not used)
          u32            pxd1: 8; // [15: 8] (0) PXD1  input delay (3 LSB not used)
          u32            pxd2: 8; // [23:16] (0) PXD2  input delay (3 LSB not used)
          u32            pxd3: 8; // [31:24] (0) PXD3  input delay (3 LSB not used)
    }; 
    struct {
          u32        fifo_lag: 4; // [ 3: 0] (7) FIFO delay to start output
          u32                :28;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_sensio_tim0_t; 

// Sensor i/o timing register 1 (different meanings for different sensor types)

typedef union {
    struct {
          u32            pxd4: 8; // [ 7: 0] (0) PXD4  input delay (3 LSB not used)
          u32            pxd5: 8; // [15: 8] (0) PXD5  input delay (3 LSB not used)
          u32            pxd6: 8; // [23:16] (0) PXD6  input delay (3 LSB not used)
          u32            pxd7: 8; // [31:24] (0) PXD7  input delay (3 LSB not used)
    }; 
    struct {
          u32      phys_lane0: 2; // [ 1: 0] (1) Physical lane for logical lane 0
          u32      phys_lane1: 2; // [ 3: 2] (2) Physical lane for logical lane 1
          u32      phys_lane2: 2; // [ 5: 4] (3) Physical lane for logical lane 2
          u32      phys_lane3: 2; // [ 7: 6] (0) Physical lane for logical lane 3
          u32                :24;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_sensio_tim1_t; 

// Sensor i/o timing register 2 (different meanings for different sensor types)

typedef union {
    struct {
          u32            pxd8: 8; // [ 7: 0] (0) PXD8  input delay (3 LSB not used)
          u32            pxd9: 8; // [15: 8] (0) PXD9  input delay (3 LSB not used)
          u32           pxd10: 8; // [23:16] (0) PXD10 input delay (3 LSB not used)
          u32           pxd11: 8; // [31:24] (0) PXD11 input delay (3 LSB not used)
    }; 
    struct {
          u32       dly_lane0: 8; // [ 7: 0] (0) lane 0 (phys) input delay (3 LSB not used)
          u32       dly_lane1: 8; // [15: 8] (0) lane 1 (phys) input delay (3 LSB not used)
          u32       dly_lane2: 8; // [23:16] (0) lane 2 (phys) input delay (3 LSB not used)
          u32       dly_lane3: 8; // [31:24] (0) lane 3 (phys) input delay (3 LSB not used)
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_sensio_tim2_t; 

// Sensor i/o timing register 3 (different meanings for different sensor types)

typedef union {
    struct {
          u32            hact: 8; // [ 7: 0] (0) HACT  input delay (3 LSB not used)
          u32            vact: 8; // [15: 8] (0) VACT  input delay (3 LSB not used)
          u32             bpf: 8; // [23:16] (0) BPF (clock from sensor) input delay (3 LSB not used)
          u32         phase_p: 8; // [31:24] (0) MMCM phase
    }; 
    struct {
          u32         phase_h: 8; // [ 7: 0] (0) MMCM phase
          u32                :24;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_sensio_tim3_t; 

// Set sensor frame width (0 - use received)

typedef union {
    struct {
          u32    sensor_width:16; // [15: 0] (0) Sensor frame width (0 - use line sync signals from the sensor)
          u32                :16;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_sensio_width_t; 

// Lens vignetting parameter (write address first, then data that may overlap som address bits)

typedef union {
    struct {
          u32                :16;
          u32            addr: 8; // [23:16] (0) Lens correction address, should be written first (overlaps with data)
          u32         sub_chn: 2; // [25:24] (0) Sensor subchannel
          u32                : 6;
    }; 
    struct {
          u32              ax:19; // [18: 0] (0x20000) Coefficient Ax
          u32                :13;
    }; 
    struct {
          u32              ay:19; // [18: 0] (0x20000) Coefficient Ay
          u32                :13;
    }; 
    struct {
          u32              bx:21; // [20: 0] (0x180000) Coefficient Bx
          u32                :11;
    }; 
    struct {
          u32              by:21; // [20: 0] (0x180000) Coefficient By
          u32                :11;
    }; 
    struct {
          u32               c:19; // [18: 0] (0x8000) Coefficient C
          u32                :13;
    }; 
    struct {
          u32           scale:17; // [16: 0] (0x8000) Scale (4 per-color values)
          u32                :15;
    }; 
    struct {
          u32      fatzero_in:16; // [15: 0] (0) 'Fat zero' on the input (subtract from the input)
          u32                :16;
    }; 
    struct {
          u32     fatzero_out:16; // [15: 0] (0) 'Fat zero' on the output (add to the result)
          u32                :16;
    }; 
    struct {
          u32      post_scale: 4; // [ 3: 0] (1) Shift result (bits)
          u32                :28;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_lens_corr_t; 

// Height of the subchannel frame for vignetting correction

typedef union {
    struct {
          u32       height_m1:16; // [15: 0] (0) Height of subframe minus 1
          u32                :16;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_lens_height_m1_t; 

// Histogram window left/top margins

typedef union {
    struct {
          u32            left:16; // [15: 0] (0) Histogram window left margin
          u32             top:16; // [31:16] (0) Histogram window top margin
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_hist_left_top_t; 

// Histogram window width and height minus 1 (0 use full)

typedef union {
    struct {
          u32        width_m1:16; // [15: 0] (0) Width of the histogram window minus 1. If 0 - use frame right margin (end of HACT)
          u32       height_m1:16; // [31:16] (0) Height of he histogram window minus 1. If 0 - use frame bottom margin (end of VACT)
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_hist_width_height_m1_t; 

// Histograms DMA mode

typedef union {
    struct {
          u32              en: 1; // [    0] (1) Enable histograms DMA
          u32            nrst: 1; // [    1] (1) 0 - reset histograms DMA
          u32         confirm: 1; // [    2] (1) 1 - wait for confirmation that histogram was written to the system memory
          u32                : 1;
          u32           cache: 4; // [ 7: 4] (3) AXI cache mode (normal - 3), ignored by Zynq?
          u32                :24;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_hist_saxi_mode_t; 

// Histograms DMA addresses

typedef union {
    struct {
          u32            page:20; // [19: 0] (0) Start address of the subchannel histogram (in pages = 4096 bytes
          u32                :12;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_hist_saxi_addr_t; 

// Compressor mode control

typedef union {
    struct {
          u32             run: 2; // [ 1: 0] (0) Run mode
          u32         run_set: 1; // [    2] (0) Set 'run'
          u32           qbank: 3; // [ 5: 3] (0) Quantization table bank
          u32       qbank_set: 1; // [    6] (0) Set 'qbank'
          u32           dcsub: 1; // [    7] (0) Subtract DC enable
          u32       dcsub_set: 1; // [    8] (0) Set 'qbank'
          u32           cmode: 4; // [12: 9] (0) Color format
          u32       cmode_set: 1; // [   13] (0) Set 'cmode'
          u32      multiframe: 1; // [   14] (0) Multi/single frame mode
          u32  multiframe_set: 1; // [   15] (0) Set 'multiframe'
          u32                : 2;
          u32           bayer: 2; // [19:18] (0) Bayer shift
          u32       bayer_set: 1; // [   20] (0) Set 'bayer'
          u32           focus: 2; // [22:21] (0) Focus mode
          u32       focus_set: 1; // [   23] (0) Set 'focus'
          u32                : 8;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_cmprs_mode_t; 

// Compressor coring mode (table number)

typedef union {
    struct {
          u32    coring_table: 3; // [ 2: 0] (0) Select coring table pair number
          u32                :29;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_cmprs_coring_mode_t; 

// Compressor color saturation

typedef union {
    struct {
          u32   colorsat_blue:10; // [ 9: 0] (0x120) Color saturation for blue (0x90 - 100%)
          u32                : 2;
          u32    colorsat_red:10; // [21:12] (0x16c) Color saturation for red (0xb6 - 100%)
          u32                :10;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_cmprs_colorsat_t; 

// Compressor frame format

typedef union {
    struct {
          u32 num_macro_cols_m1:13; // [12: 0] (0) Number of macroblock colums minus 1
          u32 num_macro_rows_m1:13; // [25:13] (0) Number of macroblock rows minus 1
          u32       left_margin: 5; // [30:26] (0) Left margin of the first pixel (0..31) for 32-pixel wide colums in memory access
          u32                  : 1;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_cmprs_frame_format_t; 

// Compressor interrupts control

typedef union {
    struct {
          u32   interrupt_cmd: 2; // [ 1: 0] (0) 0: nop, 1: clear interrupt status, 2: disable interrupt, 3: enable interrupt
          u32                :30;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_cmprs_interrupts_t; 

// Compressor tables load control

typedef union {
    struct {
          u32          addr32:24; // [23: 0] (0) Table address to start writing to (autoincremented) for DWORDs
          u32            type: 2; // [25:24] (0) 0: quantization, 1: coring, 2: focus, 3: huffman
          u32                : 6;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_cmprs_table_addr_t; 

// Compressor channel status

typedef union {
    struct {
          u32              is: 1; // [    0] (0) Compressor channel interrupt status
          u32              im: 1; // [    1] (0) Compressor channel interrupt mask
          u32   reading_frame: 1; // [    2] (0) Compressor channel is reading frame from memory (debug feature)
          u32 stuffer_running: 1; // [    3] (0) Compressor channel bit stuffer is running (debug feature)
          u32   flushing_fifo: 1; // [    4] (0) Compressor channel is flushing FIFO (debug feature)
          u32                :21;
          u32         seq_num: 6; // [31:26] (0) Status sequence number
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_cmprs_status_t; 

// Compressor DMA buffer address (in 32-byte blocks)

typedef union {
    struct {
          u32           sa256:27; // [26: 0] (0) System memory buffer start in multiples of 32 bytes (256 bits)
          u32                : 5;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_afimux_sa_t; 

// Compressor DMA buffer length (in 32-byte blocks)

typedef union {
    struct {
          u32          len256:27; // [26: 0] (0) System memory buffer length in multiples of 32 bytes (256 bits)
          u32                : 5;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_afimux_len_t; 

// Compressor DMA channels reset

typedef union {
    struct {
          u32            rst0: 1; // [    0] (0) AXI HPx sub-channel0 reset (0 - normal operation, 1 - reset)
          u32            rst1: 1; // [    1] (0) AXI HPx sub-channel0 reset (0 - normal operation, 1 - reset)
          u32            rst2: 1; // [    2] (0) AXI HPx sub-channel0 reset (0 - normal operation, 1 - reset)
          u32            rst3: 1; // [    3] (0) AXI HPx sub-channel0 reset (0 - normal operation, 1 - reset)
          u32                :28;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_afimux_rst_t; 

// Compressor DMA enable (global and channels)

typedef union {
    struct {
          u32             en0: 1; // [    0] (0) AXI HPx sub-channel0 enable value to set (0 - pause, 1 - run)
          u32         en0_set: 1; // [    1] (0) 0 - nop, 1 - set en0
          u32             en1: 1; // [    2] (0) AXI HPx sub-channel1 enable value to set (0 - pause, 1 - run)
          u32         en1_set: 1; // [    3] (0) 0 - nop, 1 - set en1
          u32             en2: 1; // [    4] (0) AXI HPx sub-channel2 enable value to set (0 - pause, 1 - run)
          u32         en2_set: 1; // [    5] (0) 0 - nop, 1 - set en2
          u32             en3: 1; // [    6] (0) AXI HPx sub-channel3 enable value to set (0 - pause, 1 - run)
          u32         en3_set: 1; // [    7] (0) 0 - nop, 1 - set en3
          u32              en: 1; // [    8] (0) AXI HPx global enable value to set (0 - pause, 1 - run)
          u32          en_set: 1; // [    9] (0) 0 - nop, 1 - set en
          u32                :22;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_afimux_en_t; 

// Compressor DMA report mode

typedef union {
    struct {
          u32           mode0: 2; // [ 1: 0] (0) channel0 report mode: 0 - EOF int, 1 - EOF confirmed, 2 - CP (current), 3 - CP confirmed
          u32       mode0_set: 1; // [    2] (0) 0 - nop, 1 - set mode0
          u32                : 1;
          u32           mode1: 2; // [ 5: 4] (0) channel0 report mode: 0 - EOF int, 1 - EOF confirmed, 2 - CP (current), 3 - CP confirmed
          u32       mode1_set: 1; // [    6] (0) 0 - nop, 1 - set mode0
          u32                : 1;
          u32           mode2: 2; // [ 9: 8] (0) channel0 report mode: 0 - EOF int, 1 - EOF confirmed, 2 - CP (current), 3 - CP confirmed
          u32       mode2_set: 1; // [   10] (0) 0 - nop, 1 - set mode0
          u32                : 1;
          u32           mode3: 2; // [13:12] (0) channel0 report mode: 0 - EOF int, 1 - EOF confirmed, 2 - CP (current), 3 - CP confirmed
          u32       mode3_set: 1; // [   14] (0) 0 - nop, 1 - set mode0
          u32                :17;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_afimux_report_t; 

// Compressor DMA status

typedef union {
    struct {
          u32       offset256:26; // [25: 0] (0) AFI MUX current/EOF pointer offset in 32-byte blocks
          u32         seq_num: 6; // [31:26] (0) Status sequence number
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_afimux_status_t; 

// GPIO output control

typedef union {
    struct {
          u32            pin0: 2; // [ 1: 0] (0) Output control for pin 0: 0 - nop, 1 - set low, 2 - set high, 3 - tristate
          u32            pin1: 2; // [ 3: 2] (0) Output control for pin 1: 0 - nop, 1 - set low, 2 - set high, 3 - tristate
          u32            pin2: 2; // [ 5: 4] (0) Output control for pin 2: 0 - nop, 1 - set low, 2 - set high, 3 - tristate
          u32            pin3: 2; // [ 7: 6] (0) Output control for pin 3: 0 - nop, 1 - set low, 2 - set high, 3 - tristate
          u32            pin4: 2; // [ 9: 8] (0) Output control for pin 4: 0 - nop, 1 - set low, 2 - set high, 3 - tristate
          u32            pin5: 2; // [11:10] (0) Output control for pin 5: 0 - nop, 1 - set low, 2 - set high, 3 - tristate
          u32            pin6: 2; // [13:12] (0) Output control for pin 6: 0 - nop, 1 - set low, 2 - set high, 3 - tristate
          u32            pin7: 2; // [15:14] (0) Output control for pin 7: 0 - nop, 1 - set low, 2 - set high, 3 - tristate
          u32            pin8: 2; // [17:16] (0) Output control for pin 8: 0 - nop, 1 - set low, 2 - set high, 3 - tristate
          u32            pin9: 2; // [19:18] (0) Output control for pin 0: 0 - nop, 1 - set low, 2 - set high, 3 - tristate
          u32                : 4;
          u32            soft: 2; // [25:24] (0) Enable pin software control: 0,1 - nop, 2 - disab;e, 3 - enable
          u32           chn_a: 2; // [27:26] (0) Enable A channel (camsync): 0,1 - nop, 2 - disab;e, 3 - enable
          u32           chn_b: 2; // [29:28] (0) Enable B channel (reserved): 0,1 - nop, 2 - disab;e, 3 - enable
          u32           chn_c: 2; // [31:30] (0) Enable C channel (logger): 0,1 - nop, 2 - disab;e, 3 - enable
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_gpio_set_pins_t; 

// GPIO pins status

typedef union {
    struct {
          u32            pin0: 1; // [    0] (0) GPIO pin 0 state
          u32            pin1: 1; // [    1] (0) GPIO pin 0 state
          u32            pin2: 1; // [    2] (0) GPIO pin 0 state
          u32            pin3: 1; // [    3] (0) GPIO pin 0 state
          u32            pin4: 1; // [    4] (0) GPIO pin 0 state
          u32            pin5: 1; // [    5] (0) GPIO pin 0 state
          u32            pin6: 1; // [    6] (0) GPIO pin 0 state
          u32            pin7: 1; // [    7] (0) GPIO pin 0 state
          u32            pin8: 1; // [    8] (0) GPIO pin 0 state
          u32            pin9: 1; // [    9] (0) GPIO pin 0 state
          u32                :16;
          u32         seq_num: 6; // [31:26] (0) Status sequence number
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_gpio_status_t; 

// RTC seconds

typedef union {
    struct {
          u32             sec:32; // [31: 0] (0) RTC seconds
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_rtc_sec_t; 

// RTC microseconds

typedef union {
    struct {
          u32            usec:20; // [19: 0] (0) RTC microseconds
          u32                :12;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_rtc_usec_t; 

// RTC correction

typedef union {
    struct {
        short            corr:16; // [15: 0] (0) RTC correction, +/1 1/256 full scale
          u32                :16;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_rtc_corr_t; 

// RTC status

typedef union {
    struct {
          u32                :24;
          u32        alt_snap: 1; // [   24] (0) alternates 0/1 each time RTC timer makes a snapshot
          u32                : 1;
          u32         seq_num: 6; // [31:26] (0) Status sequence number
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_rtc_status_t; 

// CAMSYNC I/O configuration

typedef union {
    struct {
          u32           line0: 2; // [ 1: 0] (1) line 0 mode: 0 - inactive, 1 - keep (nop), 2 - active low, 3 - active high
          u32           line1: 2; // [ 3: 2] (1) line 1 mode: 0 - inactive, 1 - keep (nop), 2 - active low, 3 - active high
          u32           line2: 2; // [ 5: 4] (1) line 2 mode: 0 - inactive, 1 - keep (nop), 2 - active low, 3 - active high
          u32           line3: 2; // [ 7: 6] (1) line 3 mode: 0 - inactive, 1 - keep (nop), 2 - active low, 3 - active high
          u32           line4: 2; // [ 9: 8] (1) line 4 mode: 0 - inactive, 1 - keep (nop), 2 - active low, 3 - active high
          u32           line5: 2; // [11:10] (1) line 5 mode: 0 - inactive, 1 - keep (nop), 2 - active low, 3 - active high
          u32           line6: 2; // [13:12] (1) line 6 mode: 0 - inactive, 1 - keep (nop), 2 - active low, 3 - active high
          u32           line7: 2; // [15:14] (1) line 7 mode: 0 - inactive, 1 - keep (nop), 2 - active low, 3 - active high
          u32           line8: 2; // [17:16] (1) line 8 mode: 0 - inactive, 1 - keep (nop), 2 - active low, 3 - active high
          u32           line9: 2; // [19:18] (1) line 9 mode: 0 - inactive, 1 - keep (nop), 2 - active low, 3 - active high
          u32                :12;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_camsync_io_t; 

// CAMSYNC mode

typedef union {
    struct {
          u32              en: 1; // [    0] (1) Enable CAMSYNC module
          u32          en_snd: 1; // [    1] (1) Enable sending timestamps (valid with 'en_snd_set')
          u32      en_snd_set: 1; // [    2] (0) Set 'en_snd'
          u32             ext: 1; // [    3] (1) Use external (received) timestamps, if available. O - use local timestamps
          u32         ext_set: 1; // [    4] (0) Set 'ext'
          u32            trig: 1; // [    5] (1) Sensor triggered mode (0 - free running sensor)
          u32        trig_set: 1; // [    6] (0) Set 'trig'
          u32      master_chn: 2; // [ 8: 7] (0) master sensor channel (zero delay in internal trigger mode, delay used for flash output)
          u32  master_chn_set: 1; // [    9] (0) Set 'master_chn'
          u32         ts_chns: 4; // [13:10] (1) Channels to generate timestmp messages (bit mask)
          u32     ts_chns_set: 1; // [   14] (0) Set 'ts_chns'
          u32                :17;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_camsync_mode_t; 

// CMDFRAMESEQ mode

typedef union {
    struct {
          u32   interrupt_cmd: 2; // [ 1: 0] (0) Interrupt command: 0-nop, 1 - clear is, 2 - disable, 3 - enable
          u32                :10;
          u32         run_cmd: 2; // [13:12] (0) Run command: 0,1 - nop, 2 - stop, 3 - run
          u32           reset: 1; // [   14] (0) 1 - reset, 0 - normal operation
          u32                :17;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_cmdframeseq_mode_t; 

// CMDFRAMESEQ mode

typedef union {
    struct {
          u32      frame_num0: 4; // [ 3: 0] (0) Frame number for sensor 0
          u32      frame_num1: 4; // [ 7: 4] (0) Frame number for sensor 0
          u32      frame_num2: 4; // [11: 8] (0) Frame number for sensor 0
          u32      frame_num3: 4; // [15:12] (0) Frame number for sensor 0
          u32              is: 4; // [19:16] (0) Interrupt status: 1 bit per sensor channel
          u32              im: 4; // [23:20] (0) Interrupt enable: 1 bit per sensor channel
          u32                : 2;
          u32         seq_num: 6; // [31:26] (0) Status sequence number
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_cmdseqmux_status_t; 

// Event logger status

typedef union {
    struct {
          u32          sample:24; // [23: 0] (0) Logger sample number
          u32                : 2;
          u32         seq_num: 6; // [31:26] (0) Status sequence number
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_logger_status_t; 

// Event logger register address

typedef union {
    struct {
          u32            addr: 5; // [ 4: 0] (0) Register address (autoincrements in 32 DWORDs (page) range
          u32            page: 2; // [ 6: 5] (0) Register page: configuration: 0, IMU: 3, GPS: 1, MSG: 2
          u32                :25;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_logger_address_t; 

// Event logger register data

typedef union {
    struct {
          u32        imu_slot: 2; // [ 1: 0] (0) IMU slot
          u32         imu_set: 1; // [    2] (0) Set 'imu_slot'
          u32        gps_slot: 2; // [ 4: 3] (0) GPS slot
          u32      gps_invert: 1; // [    5] (0) GPS inpert 1pps signal
          u32         gps_ext: 1; // [    6] (0) GPS sync to 1 pps signal (0 - sync to serial message)
          u32         gps_set: 1; // [    7] (0) Set 'gps_*' fields
          u32       msg_input: 4; // [11: 8] (0) MSG pin: GPIO pin number to accept external signal (0xf - disable)
          u32      msg_invert: 1; // [   12] (0) MSG input polarity - 0 - active high, 1 - active low
          u32         msg_set: 1; // [   13] (0) Set 'msg_*' fields
          u32        log_sync: 4; // [17:14] (0) Log frame sync events (bit per sensor channel)
          u32    log_sync_set: 1; // [   18] (0) Set 'log_sync' fields
          u32                :13;
    }; 
    struct {
          u32            data:32; // [31: 0] (0) Other logger register data (context-dependent)
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_logger_data_t; 

// MULT_SAXI DMA addresses/lengths in 32-bit DWORDS

typedef union {
    struct {
          u32          addr32:30; // [29: 0] (0) SAXI sddress/length in DWORDs
          u32                : 2;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_mult_saxi_al_t; 

// MULTICLK reset/power down controls

typedef union {
    struct {
          u32        rst_clk0: 1; // [    0] (0) Reset PLL for xclk(240MHz), hclk(150MHz)
          u32        rst_clk1: 1; // [    1] (0) Reset PLL for pclk (sensors, from ffclk0)
          u32        rst_clk2: 1; // [    2] (0) reserved
          u32        rst_clk3: 1; // [    3] (0) reserved
          u32      pwrdwnclk0: 1; // [    4] (0) Power down PLL for xclk(240MHz), hclk(150MHz)
          u32     pwrdwn_clk1: 1; // [    5] (0) Power down for pclk (sensors, from ffclk0)
          u32     pwrdwn_clk2: 1; // [    6] (0) reserved
          u32     pwrdwn_clk3: 1; // [    7] (0) reserved
          u32      rst_memclk: 1; // [    8] (0) reset memclk (external in for memory) toggle FF
          u32      rst_ffclk0: 1; // [    9] (0) reset ffclk0 (external in for sensors) toggle FF
          u32      rst_ffclk1: 1; // [   10] (0) reset ffclk1 (exteranl in, not yet used) toggle FF
          u32                :21;
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_multiclk_ctl_t; 

// MULTICLK status

typedef union {
    struct {
          u32         locked0: 1; // [    0] (0) Locked PLL for xclk(240MHz), hclk(150MHz)
          u32         locked1: 1; // [    1] (0) Locked PLL for pclk (sensors, from ffclk0)
          u32         locked2: 1; // [    2] (0) ==1, reserved
          u32         locked3: 1; // [    3] (0) ==1, reserved
          u32      tgl_memclk: 1; // [    4] (0) memclk (external in for memory) toggle FF
          u32      tgl_ffclk0: 1; // [    5] (0) ffclk0 (external in for sensors) toggle FF
          u32      tgl_ffclk1: 1; // [    6] (0) ffclk1 (exteranl in, not yet used) toggle FF
          u32                :17;
          u32      idelay_rdy: 1; // [   24] (0) idelay_ctrl_rdy (juct to prevent from optimization)
          u32                : 1;
          u32         seq_num: 6; // [31:26] (0) Status sequence number
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_multiclk_status_t; 

// DEBUG status

typedef union {
    struct {
          u32                :24;
          u32             tgl: 1; // [   24] (0) Toggles for each DWORD received
          u32                : 1;
          u32         seq_num: 6; // [31:26] (0) Status sequence number
    }; 
    struct {
          u32             d32:32; // [31: 0] (0) cast to u32
    }; 
} x393_debug_status_t; 

