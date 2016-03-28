/*******************************************************************************
 * File: x393_defs.h
 * Date: 2016-03-28  
 * Author: auto-generated file, see x393_export_c.py
 * Description: Constants and hardware addresses definitions to access x393 hardware registers
 *******************************************************************************/

// R/W addresses to set up memory arbiter priorities. For sensors  (chn = 8..11), for compressors - 12..15

#define X393_MCNTRL_ARBITER_PRIORITY(chn)                (0x40000180 + 0x4 * (chn)) // Set memory arbiter priority (currently r/w, may become just wo), chn = 0..15, data type: x393_arbite_pri_t (rw)

// Enable/disable memory channels (bits in a 16-bit word). For sensors  (chn = 8..11), for compressors - 12..15

#define X393_MCNTRL_CHN_EN                               0x400001c0 // Enable/disable memory channels (currently r/w, may become just wo), data type: x393_mcntr_chn_en_t (rw)
#define X393_MCNTRL_DQS_DQM_PATT                         0x40000140 // Setup DQS and DQM patterns, data type: x393_mcntr_dqs_dqm_patt_t (rw)
#define X393_MCNTRL_DQ_DQS_TRI                           0x40000144 // Setup DQS and DQ on/off sequence, data type: x393_mcntr_dqs_dqm_tri_t (rw)

// Following enable/disable addresses can be written with any data, only addresses matter

#define X393_MCNTRL_DIS                                  0x400000c0 // Disable DDR3 memory controller
#define X393_MCNTRL_EN                                   0x400000c4 // Enable DDR3 memory controller
#define X393_MCNTRL_REFRESH_DIS                          0x400000c8 // Disable DDR3 memory refresh
#define X393_MCNTRL_REFRESH_EN                           0x400000cc // Enable DDR3 memory refresh
#define X393_MCNTRL_SDRST_DIS                            0x40000098 // Disable DDR3 memory reset
#define X393_MCNTRL_SDRST_EN                             0x4000009c // Enable DDR3 memory reset
#define X393_MCNTRL_CKE_DIS                              0x400000a0 // Disable DDR3 memory CKE
#define X393_MCNTRL_CKE_EN                               0x400000a4 // Enable DDR3 memory CKE
#define X393_MCNTRL_CMDA_DIS                             0x40000090 // Disable DDR3 memory command/address lines
#define X393_MCNTRL_CMDA_EN                              0x40000094 // Enable DDR3 memory command/address lines

// Set DDR3 memory controller I/O delays and other timing parameters (should use individually calibrated values)

#define X393_MCNTRL_DQ_ODLY0(chn)                        (0x40000200 + 0x4 * (chn)) // Lane0 DQ output delays , chn = 0..7, data type: x393_dly_t (rw)
#define X393_MCNTRL_DQ_ODLY1(chn)                        (0x40000280 + 0x4 * (chn)) // Lane1 DQ output delays , chn = 0..7, data type: x393_dly_t (rw)
#define X393_MCNTRL_DQ_IDLY0(chn)                        (0x40000240 + 0x4 * (chn)) // Lane0 DQ input delays , chn = 0..7, data type: x393_dly_t (rw)
#define X393_MCNTRL_DQ_IDLY1(chn)                        (0x400002c0 + 0x4 * (chn)) // Lane1 DQ input delays , chn = 0..7, data type: x393_dly_t (rw)
#define X393_MCNTRL_DQS_ODLY0                            0x40000220 // Lane0 DQS output delay , data type: x393_dly_t (rw)
#define X393_MCNTRL_DQS_ODLY1                            0x400002a0 // Lane1 DQS output delay , data type: x393_dly_t (rw)
#define X393_MCNTRL_DQS_IDLY0                            0x40000260 // Lane0 DQS input delay , data type: x393_dly_t (rw)
#define X393_MCNTRL_DQS_IDLY1                            0x400002e0 // Lane1 DQS input delay , data type: x393_dly_t (rw)
#define X393_MCNTRL_DM_ODLY0                             0x40000224 // Lane0 DM output delay , data type: x393_dly_t (rw)
#define X393_MCNTRL_DM_ODLY1                             0x400002a4 // Lane1 DM output delay , data type: x393_dly_t (rw)
#define X393_MCNTRL_CMDA_ODLY(chn)                       (0x40000300 + 0x4 * (chn)) // Address, bank and commands delays, chn = 0..31, data type: x393_dly_t (rw)
#define X393_MCNTRL_PHASE                                0x40000380 // Clock phase, data type: x393_dly_t (rw)
#define X393_MCNTRL_DLY_SET                              0x40000080 // Set all pre-programmed delays
#define X393_MCNTRL_WBUF_DLY                             0x40000148 // Set write buffer delay, data type: x393_wbuf_dly_t (rw)

// Write-only addresses to program memory channels for sensors  (chn = 0..3), memory channels 8..11

#define X393_SENS_MCNTRL_SCANLINE_MODE(chn)              (0x40001a00 + 0x40 * (chn)) // Set mode register (write last after other channel registers are set), chn = 0..3, data type: x393_mcntrl_mode_scan_t (wo)
#define X393_SENS_MCNTRL_SCANLINE_STATUS_CNTRL(chn)      (0x40001a04 + 0x40 * (chn)) // Set status control register (status update mode), chn = 0..3, data type: x393_status_ctrl_t (rw)
#define X393_SENS_MCNTRL_SCANLINE_STARTADDR(chn)         (0x40001a08 + 0x40 * (chn)) // Set frame start address, chn = 0..3, data type: x393_mcntrl_window_frame_sa_t (wo)
#define X393_SENS_MCNTRL_SCANLINE_FRAME_SIZE(chn)        (0x40001a0c + 0x40 * (chn)) // Set frame size (address increment), chn = 0..3, data type: x393_mcntrl_window_frame_sa_inc_t (wo)
#define X393_SENS_MCNTRL_SCANLINE_FRAME_LAST(chn)        (0x40001a10 + 0x40 * (chn)) // Set last frame number (number of frames in buffer minus 1), chn = 0..3, data type: x393_mcntrl_window_last_frame_num_t (wo)
#define X393_SENS_MCNTRL_SCANLINE_FRAME_FULL_WIDTH(chn)  (0x40001a14 + 0x40 * (chn)) // Set frame full(padded) width, chn = 0..3, data type: x393_mcntrl_window_full_width_t (wo)
#define X393_SENS_MCNTRL_SCANLINE_WINDOW_WH(chn)         (0x40001a18 + 0x40 * (chn)) // Set frame window size, chn = 0..3, data type: x393_mcntrl_window_width_height_t (wo)
#define X393_SENS_MCNTRL_SCANLINE_WINDOW_X0Y0(chn)       (0x40001a1c + 0x40 * (chn)) // Set frame position, chn = 0..3, data type: x393_mcntrl_window_left_top_t (wo)
#define X393_SENS_MCNTRL_SCANLINE_STARTXY(chn)           (0x40001a20 + 0x40 * (chn)) // Set startXY register, chn = 0..3, data type: x393_mcntrl_window_startx_starty_t (wo)

// Write-only addresses to program memory channels for compressors (chn = 0..3), memory channels 12..15

#define X393_SENS_MCNTRL_TILED_MODE(chn)                 (0x40001b00 + 0x40 * (chn)) // Set mode register (write last after other channel registers are set), chn = 0..3, data type: x393_mcntrl_mode_scan_t (wo)
#define X393_SENS_MCNTRL_TILED_STATUS_CNTRL(chn)         (0x40001b04 + 0x40 * (chn)) // Set status control register (status update mode), chn = 0..3, data type: x393_status_ctrl_t (rw)
#define X393_SENS_MCNTRL_TILED_STARTADDR(chn)            (0x40001b08 + 0x40 * (chn)) // Set frame start address, chn = 0..3, data type: x393_mcntrl_window_frame_sa_t (wo)
#define X393_SENS_MCNTRL_TILED_FRAME_SIZE(chn)           (0x40001b0c + 0x40 * (chn)) // Set frame size (address increment), chn = 0..3, data type: x393_mcntrl_window_frame_sa_inc_t (wo)
#define X393_SENS_MCNTRL_TILED_FRAME_LAST(chn)           (0x40001b10 + 0x40 * (chn)) // Set last frame number (number of frames in buffer minus 1), chn = 0..3, data type: x393_mcntrl_window_last_frame_num_t (wo)
#define X393_SENS_MCNTRL_TILED_FRAME_FULL_WIDTH(chn)     (0x40001b14 + 0x40 * (chn)) // Set frame full(padded) width, chn = 0..3, data type: x393_mcntrl_window_full_width_t (wo)
#define X393_SENS_MCNTRL_TILED_WINDOW_WH(chn)            (0x40001b18 + 0x40 * (chn)) // Set frame window size, chn = 0..3, data type: x393_mcntrl_window_width_height_t (wo)
#define X393_SENS_MCNTRL_TILED_WINDOW_X0Y0(chn)          (0x40001b1c + 0x40 * (chn)) // Set frame position, chn = 0..3, data type: x393_mcntrl_window_left_top_t (wo)
#define X393_SENS_MCNTRL_TILED_STARTXY(chn)              (0x40001b20 + 0x40 * (chn)) // Set startXY register, chn = 0..3, data type: x393_mcntrl_window_startx_starty_t (wo)
#define X393_SENS_MCNTRL_TILED_TILE_WHS(chn)             (0x40001b24 + 0x40 * (chn)) // Set tile size/step (tiled mode only), chn = 0..3, data type: x393_mcntrl_window_tile_whs_t (wo)

// Write-only addresses to program memory channel for membridge, memory channel 1

#define X393_MEMBRIDGE_SCANLINE_MODE                     0x40000480 // Set mode register (write last after other channel registers are set), data type: x393_mcntrl_mode_scan_t (wo)
#define X393_MEMBRIDGE_SCANLINE_STATUS_CNTRL             0x40000484 // Set status control register (status update mode), data type: x393_status_ctrl_t (rw)
#define X393_MEMBRIDGE_SCANLINE_STARTADDR                0x40000488 // Set frame start address, data type: x393_mcntrl_window_frame_sa_t (wo)
#define X393_MEMBRIDGE_SCANLINE_FRAME_SIZE               0x4000048c // Set frame size (address increment), data type: x393_mcntrl_window_frame_sa_inc_t (wo)
#define X393_MEMBRIDGE_SCANLINE_FRAME_LAST               0x40000490 // Set last frame number (number of frames in buffer minus 1), data type: x393_mcntrl_window_last_frame_num_t (wo)
#define X393_MEMBRIDGE_SCANLINE_FRAME_FULL_WIDTH         0x40000494 // Set frame full(padded) width, data type: x393_mcntrl_window_full_width_t (wo)
#define X393_MEMBRIDGE_SCANLINE_WINDOW_WH                0x40000498 // Set frame window size, data type: x393_mcntrl_window_width_height_t (wo)
#define X393_MEMBRIDGE_SCANLINE_WINDOW_X0Y0              0x4000049c // Set frame position, data type: x393_mcntrl_window_left_top_t (wo)
#define X393_MEMBRIDGE_SCANLINE_STARTXY                  0x400004a0 // Set startXY register, data type: x393_mcntrl_window_startx_starty_t (wo)
#define X393_MEMBRIDGE_CTRL                              0x40000800 // Issue membridge command, data type: x393_membridge_cmd_t (wo)
#define X393_MEMBRIDGE_STATUS_CNTRL                      0x40000804 // Set membridge status control register, data type: x393_status_ctrl_t (rw)
#define X393_MEMBRIDGE_LO_ADDR64                         0x40000808 // start address of the system memory range in QWORDs (4 LSBs==0), data type: u29_t (wo)
#define X393_MEMBRIDGE_SIZE64                            0x4000080c // size of the system memory range in QWORDs (4 LSBs==0), rolls over, data type: u29_t (wo)
#define X393_MEMBRIDGE_START64                           0x40000810 // start of transfer offset to system memory range in QWORDs (4 LSBs==0), data type: u29_t (wo)
#define X393_MEMBRIDGE_LEN64                             0x40000814 // Full length of transfer in QWORDs, data type: u29_t (wo)
#define X393_MEMBRIDGE_WIDTH64                           0x40000818 // Frame width in QWORDs (last xfer in each line may be partial), data type: u29_t (wo)
#define X393_MEMBRIDGE_MODE                              0x4000081c // AXI cache mode, data type: x393_membridge_mode_t (wo)

// Write-only addresses to PS PIO (Software generated DDR3 memory access sequences)

#define X393_MCNTRL_PS_EN_RST                            0x40000400 // Set PS PIO enable and reset, data type: x393_ps_pio_en_rst_t (wo)
#define X393_MCNTRL_PS_CMD                               0x40000404 // Set PS PIO commands, data type: x393_ps_pio_cmd_t (wo)
#define X393_MCNTRL_PS_STATUS_CNTRL                      0x40000408 // Set PS PIO status control register (status update mode), data type: x393_status_ctrl_t (rw)

// Write-only addresses to to program status report mode for memory controller

#define X393_MCONTR_PHY_STATUS_CNTRL                     0x40000150 // Set status control register (status update mode), data type: x393_status_ctrl_t (rw)
#define X393_MCONTR_TOP_16BIT_STATUS_CNTRL               0x4000014c // Set status control register (status update mode), data type: x393_status_ctrl_t (rw)

// Write-only addresses to to program status report mode for test channels

#define X393_MCNTRL_TEST01_CHN2_STATUS_CNTRL             0x400003d4 // Set status control register (status update mode), data type: x393_status_ctrl_t (rw)
#define X393_MCNTRL_TEST01_CHN3_STATUS_CNTRL             0x400003dc // Set status control register (status update mode), data type: x393_status_ctrl_t (rw)
#define X393_MCNTRL_TEST01_CHN4_STATUS_CNTRL             0x400003e4 // Set status control register (status update mode), data type: x393_status_ctrl_t (rw)

// Write-only addresses for test channels commands

#define X393_MCNTRL_TEST01_CHN2_MODE                     0x400003d0 // Set command for test01 channel 2, data type: x393_test01_mode_t (wo)
#define X393_MCNTRL_TEST01_CHN3_MODE                     0x400003d8 // Set command for test01 channel 3, data type: x393_test01_mode_t (wo)
#define X393_MCNTRL_TEST01_CHN4_MODE                     0x400003e0 // Set command for test01 channel 4, data type: x393_test01_mode_t (wo)

// Read-only addresses for status information

#define X393_MCONTR_PHY_STATUS                           0x40002000 // Status register for MCNTRL PHY, data type: x393_status_mcntrl_phy_t (ro)
#define X393_MCONTR_TOP_STATUS                           0x40002004 // Status register for MCNTRL requests, data type: x393_status_mcntrl_top_t (ro)
#define X393_MCNTRL_PS_STATUS                            0x40002008 // Status register for MCNTRL software R/W, data type: x393_status_mcntrl_ps_t (ro)
#define X393_MCNTRL_CHN1_STATUS                          0x40002010 // Status register for MCNTRL CHN1 (membridge), data type: x393_status_mcntrl_lintile_t (ro)
#define X393_MCNTRL_CHN3_STATUS                          0x40002018 // Status register for MCNTRL CHN3 (scanline), data type: x393_status_mcntrl_lintile_t (ro)
#define X393_MCNTRL_CHN2_STATUS                          0x40002014 // Status register for MCNTRL CHN2 (tiled), data type: x393_status_mcntrl_lintile_t (ro)
#define X393_MCNTRL_CHN4_STATUS                          0x4000201c // Status register for MCNTRL CHN4 (tiled), data type: x393_status_mcntrl_lintile_t (ro)
#define X393_TEST01_CHN2_STATUS                          0x400020f4 // Status register for test channel 2, data type: x393_status_mcntrl_testchn_t (ro)
#define X393_TEST01_CHN3_STATUS                          0x400020f8 // Status register for test channel 3, data type: x393_status_mcntrl_testchn_t (ro)
#define X393_TEST01_CHN4_STATUS                          0x400020fc // Status register for test channel 4, data type: x393_status_mcntrl_testchn_t (ro)
#define X393_MEMBRIDGE_STATUS                            0x400020ec // Status register for membridge, data type: x393_status_membridge_t (ro)

// Write-only control of the sensor channels

#define X393_SENS_MODE(sens_num)                         (0x40001000 + 0x100 * (sens_num)) // Write sensor channel mode, sens_num = 0..3, data type: x393_sens_mode_t (wo)
#define X393_SENSI2C_CTRL(sens_num)                      (0x40001008 + 0x100 * (sens_num)) // Control sensor i2c, write i2c LUT, sens_num = 0..3, data type: x393_i2c_ctltbl_t (wo)
#define X393_SENSI2C_STATUS(sens_num)                    (0x4000100c + 0x100 * (sens_num)) // Setup sensor i2c status report mode, sens_num = 0..3, data type: x393_status_ctrl_t (rw)
#define X393_SENS_SYNC_MULT(sens_num)                    (0x40001018 + 0x100 * (sens_num)) // Configure frames combining, sens_num = 0..3, data type: x393_sens_sync_mult_t (wo)
#define X393_SENS_SYNC_LATE(sens_num)                    (0x4000101c + 0x100 * (sens_num)) // Configure frame sync delay, sens_num = 0..3, data type: x393_sens_sync_late_t (wo)
#define X393_SENSIO_CTRL(sens_num)                       (0x40001020 + 0x100 * (sens_num)) // Configure sensor I/O port, sens_num = 0..3, data type: x393_sensio_ctl_t (wo)
#define X393_SENSIO_STATUS_CNTRL(sens_num)               (0x40001024 + 0x100 * (sens_num)) // Set status control for SENSIO module, sens_num = 0..3, data type: x393_status_ctrl_t (rw)
#define X393_SENSIO_JTAG(sens_num)                       (0x40001028 + 0x100 * (sens_num)) // Programming interface for multiplexer FPGA (with X393_SENSIO_STATUS), sens_num = 0..3, data type: x393_sensio_jpag_t (wo)
#define X393_SENSIO_WIDTH(sens_num)                      (0x4000102c + 0x100 * (sens_num)) // Set sensor line in pixels (0 - use line sync from the sensor), sens_num = 0..3, data type: x393_sensio_width_t (rw)
#define X393_SENSIO_TIM0(sens_num)                       (0x40001030 + 0x100 * (sens_num)) // Sensor port i/o timing configuration, register 0, sens_num = 0..3, data type: x393_sensio_tim0_t (rw)
#define X393_SENSIO_TIM1(sens_num)                       (0x40001034 + 0x100 * (sens_num)) // Sensor port i/o timing configuration, register 1, sens_num = 0..3, data type: x393_sensio_tim1_t (rw)
#define X393_SENSIO_TIM2(sens_num)                       (0x40001038 + 0x100 * (sens_num)) // Sensor port i/o timing configuration, register 2, sens_num = 0..3, data type: x393_sensio_tim2_t (rw)
#define X393_SENSIO_TIM3(sens_num)                       (0x4000103c + 0x100 * (sens_num)) // Sensor port i/o timing configuration, register 3, sens_num = 0..3, data type: x393_sensio_tim3_t (rw)

// I2C command sequencer, block of 16 DWORD slots for absolute frame numbers (modulo 16) and 15 slots for relative ones
// 0 - ASAP, 1 next frame, 14 -14-th next.
// Data written depends on context:
// 1 - I2C register write: index page (MSB), 3 payload bytes. Payload bytes are used according to table and sent
//     after the slave address and optional high address byte. Other bytes are sent in descending order (LSB- last).
//     If less than 4 bytes are programmed in the table the high bytes (starting with the one from the table) are
//     skipped.
//     If more than 4 bytes are programmed in the table for the page (high byte), one or two next 32-bit words 
//     bypass the index table and all 4 bytes are considered payload ones. If less than 4 extra bytes are to be
//     sent for such extra word, only the lower bytes are sent.
//
// 2 - I2C register read: index page, slave address (8-bit, with lower bit 0) and one or 2 address bytes (as programmed
//     in the table. Slave address is always in byte 2 (bits 23:16), byte1 (high register address) is skipped if
//     read address in the table is programmed to be a single-byte one

#define X393_SENSI2C_ABS((sens_num),(offset))            (0x40001040)+ 0x40 * (sens_num)+ 0x1 * (offset)) // Write sensor i2c sequencer, sens_num = 0..3, offset = 0..15, data type: u32 (wo)
#define X393_SENSI2C_REL((sens_num),(offset))            (0x40001080)+ 0x40 * (sens_num)+ 0x1 * (offset)) // Write sensor i2c sequencer, sens_num = 0..3, offset = 0..15, data type: u32 (wo)

// Lens vignetting correction (for each sub-frame separately)

#define X393_LENS_HEIGHT0_M1(sens_num)                   (0x400010f0 + 0x100 * (sens_num)) // Subframe 0 height minus 1, sens_num = 0..3, data type: x393_lens_height_m1_t (rw)
#define X393_LENS_HEIGHT1_M1(sens_num)                   (0x400010f4 + 0x100 * (sens_num)) // Subframe 1 height minus 1, sens_num = 0..3, data type: x393_lens_height_m1_t (rw)
#define X393_LENS_HEIGHT2_M1(sens_num)                   (0x400010f8 + 0x100 * (sens_num)) // Subframe 2 height minus 1, sens_num = 0..3, data type: x393_lens_height_m1_t (rw)
#define X393_LENS_CORR_CNH_ADDR_DATA(sens_num)           (0x400010fc + 0x100 * (sens_num)) // Combined address/data to write lens vignetting correction coefficients, sens_num = 0..3, data type: x393_lens_corr_t (wo)

// Lens vignetting coefficient addresses - use with x393_lens_corr_wo_t (X393_LENS_CORR_CNH_ADDR_DATA)

#define X393_LENS_AX                                     0x00000000 // Address of correction parameter Ax
#define X393_LENS_AX_MASK                                0x000000f8 // Correction parameter Ax mask
#define X393_LENS_AY                                     0x00000008 // Address of correction parameter Ay
#define X393_LENS_AY_MASK                                0x000000f8 // Correction parameter Ay mask
#define X393_LENS_C                                      0x00000010 // Address of correction parameter C
#define X393_LENS_C_MASK                                 0x000000f8 // Correction parameter C mask
#define X393_LENS_BX                                     0x00000020 // Address of correction parameter Bx
#define X393_LENS_BX_MASK                                0x000000e0 // Correction parameter Bx mask
#define X393_LENS_BY                                     0x00000040 // Address of correction parameter By
#define X393_LENS_BY_MASK                                0x000000e0 // Correction parameter By mask
#define X393_LENS_SCALE0                                 0x00000060 // Address of correction parameter scale0
#define X393_LENS_SCALE1                                 0x00000062 // Address of correction parameter scale1
#define X393_LENS_SCALE2                                 0x00000064 // Address of correction parameter scale2
#define X393_LENS_SCALE3                                 0x00000066 // Address of correction parameter scale3
#define X393_LENS_SCALES_MASK                            0x000000f8 // Common mask for scales
#define X393_LENS_FAT0_IN                                0x00000068 // Address of input fat zero parameter (to subtract from input)
#define X393_LENS_FAT0_IN_MASK                           0x000000ff // Mask for fat zero input parameter
#define X393_LENS_FAT0_OUT                               0x00000069 // Address of output fat zero parameter (to add to output)
#define X393_LENS_FAT0_OUT_MASK                          0x000000ff // Mask for fat zero output  parameters
#define X393_LENS_POST_SCALE                             0x0000006a // Address of post scale (shift output) parameter
#define X393_LENS_POST_SCALE_MASK                        0x000000ff // Mask for post scale parameter

// Sensor gamma conversion control (See Python code for examples of the table data generation)

#define X393_SENS_GAMMA_CTRL(sens_num)                   (0x400010e0 + 0x100 * (sens_num)) // Gamma module control, sens_num = 0..3, data type: x393_gamma_ctl_t (rw)
#define X393_SENS_GAMMA_TBL(sens_num)                    (0x400010e4 + 0x100 * (sens_num)) // Write sensor gamma table address/data (with autoincrement), sens_num = 0..3, data type: x393_gamma_tbl_t (wo)
#define X393_SENS_GAMMA_HEIGHT01M1(sens_num)             (0x400010e8 + 0x100 * (sens_num)) // Gamma module subframes 0,1 heights minus 1, sens_num = 0..3, data type: x393_gamma_height01m1_t (rw)
#define X393_SENS_GAMMA_HEIGHT2M1(sens_num)              (0x400010ec + 0x100 * (sens_num)) // Gamma module subframe  2 height minus 1, sens_num = 0..3, data type: x393_gamma_height2m1_t (rw)

// Windows for histogram subchannels

#define X393_HISTOGRAM_LT0(sens_num)                     (0x400010c0 + 0x100 * (sens_num)) // Specify histogram 0 left/top, sens_num = 0..3, data type: x393_hist_left_top_t (rw)
#define X393_HISTOGRAM_WH0(sens_num)                     (0x400010c4 + 0x100 * (sens_num)) // Specify histogram 0 width/height, sens_num = 0..3, data type: x393_hist_width_height_m1_t (rw)
#define X393_HISTOGRAM_LT1(sens_num)                     (0x400010c8 + 0x100 * (sens_num)) // Specify histogram 1 left/top, sens_num = 0..3, data type: x393_hist_left_top_t (rw)
#define X393_HISTOGRAM_WH1(sens_num)                     (0x400010cc + 0x100 * (sens_num)) // Specify histogram 1 width/height, sens_num = 0..3, data type: x393_hist_width_height_m1_t (rw)
#define X393_HISTOGRAM_LT2(sens_num)                     (0x400010d0 + 0x100 * (sens_num)) // Specify histogram 2 left/top, sens_num = 0..3, data type: x393_hist_left_top_t (rw)
#define X393_HISTOGRAM_WH2(sens_num)                     (0x400010d4 + 0x100 * (sens_num)) // Specify histogram 2 width/height, sens_num = 0..3, data type: x393_hist_width_height_m1_t (rw)
#define X393_HISTOGRAM_LT3(sens_num)                     (0x400010d8 + 0x100 * (sens_num)) // Specify histogram 3 left/top, sens_num = 0..3, data type: x393_hist_left_top_t (rw)
#define X393_HISTOGRAM_WH3(sens_num)                     (0x400010dc + 0x100 * (sens_num)) // Specify histogram 3 width/height, sens_num = 0..3, data type: x393_hist_width_height_m1_t (rw)

// DMA control for the histograms. Subchannel here is 4*sensor_port+ histogram_subchannel

#define X393_HIST_SAXI_MODE                              0x40001440 // Histogram DMA operation mode, data type: x393_hist_saxi_mode_t (rw)
#define X393_HIST_SAXI_ADDR(subchannel)                  (0x40001400 + 0x4 * (subchannel)) // Histogram DMA addresses (in 4096 byte pages), subchannel = 0..15, data type: x393_hist_saxi_addr_t (rw)

// Read-only addresses for sensors status information

#define X393_SENSI2C_STATUS(sens_num)                    (0x40002080 + 0x8 * (sens_num)) // Status of the sensors i2c, sens_num = 0..3, data type: x393_status_sens_i2c_t (ro)
#define X393_SENSIO_STATUS(sens_num)                     (0x40002084 + 0x8 * (sens_num)) // Status of the sensor ports I/O pins, sens_num = 0..3, data type: x393_status_sens_io_t (ro)

// Compressor bitfields values

#define X393_CMPRS_CBIT_RUN_RST                          0x00000000 // Reset compressor, stop immediately
#define X393_CMPRS_CBIT_RUN_DISABLE                      0x00000001 // Disable compression of the new frames, finish any already started
#define X393_CMPRS_CBIT_RUN_STANDALONE                   0x00000002 // Enable compressor, compress single frame from memory (async)
#define X393_CMPRS_CBIT_RUN_ENABLE                       0x00000003 // Enable synchronous compression mode
#define X393_CMPRS_CBIT_CMODE_JPEG18                     0x00000000 // Color 4:2:0 3x3 de-bayer core
#define X393_CMPRS_CBIT_CMODE_MONO6                      0x00000001 // Mono 4:2:0 (6 blocks)
#define X393_CMPRS_CBIT_CMODE_JP46                       0x00000002 // jp4, 6 blocks, original
#define X393_CMPRS_CBIT_CMODE_JP46DC                     0x00000003 // jp4, 6 blocks, DC-improved
#define X393_CMPRS_CBIT_CMODE_JPEG20                     0x00000004 // Color 4:2:0 with 5x5 de-bayer (not implemented)
#define X393_CMPRS_CBIT_CMODE_JP4                        0x00000005 // jp4,  4 blocks
#define X393_CMPRS_CBIT_CMODE_JP4DC                      0x00000006 // jp4,  4 blocks, DC-improved
#define X393_CMPRS_CBIT_CMODE_JP4DIFF                    0x00000007 // jp4,  4 blocks, differential
#define X393_CMPRS_CBIT_CMODE_JP4DIFFHDR                 0x00000008 // jp4,  4 blocks, differential, hdr
#define X393_CMPRS_CBIT_CMODE_JP4DIFFDIV2                0x00000009 // jp4,  4 blocks, differential, divide by 2
#define X393_CMPRS_CBIT_CMODE_JP4DIFFHDRDIV2             0x0000000a // jp4,  4 blocks, differential, hdr,divide by 2
#define X393_CMPRS_CBIT_CMODE_MONO1                      0x0000000b // Mono JPEG (not yet implemented)
#define X393_CMPRS_CBIT_CMODE_MONO4                      0x0000000e // Mono, 4 blocks (2x2 macroblocks)
#define X393_CMPRS_CBIT_CMODE_JPEG18                     0x00000000 // Color 4:2:0
#define X393_CMPRS_CBIT_CMODE_JPEG18                     0x00000000 // Color 4:2:0
#define X393_CMPRS_CBIT_FRAMES_SINGLE                    0x00000000 // Use single-frame buffer
#define X393_CMPRS_CBIT_FRAMES_MULTI                     0x00000001 // Use multi-frame buffer

// Compressor control

#define X393_CMPRS_CONTROL_REG(cmprs_chn)                (0x40001800 + 0x40 * (cmprs_chn)) // Program compressor channel operation mode, cmprs_chn = 0..3, data type: x393_cmprs_mode_t (wo)
#define X393_CMPRS_STATUS(cmprs_chn)                     (0x40001804 + 0x40 * (cmprs_chn)) // Setup compressor status report mode, cmprs_chn = 0..3, data type: x393_status_ctrl_t (rw)
#define X393_CMPRS_FORMAT(cmprs_chn)                     (0x40001808 + 0x40 * (cmprs_chn)) // Compressor frame format, cmprs_chn = 0..3, data type: x393_cmprs_frame_format_t (rw)
#define X393_CMPRS_COLOR_SATURATION(cmprs_chn)           (0x4000180c + 0x40 * (cmprs_chn)) // Compressor color saturation, cmprs_chn = 0..3, data type: x393_cmprs_colorsat_t (rw)
#define X393_CMPRS_CORING_MODE(cmprs_chn)                (0x40001810 + 0x40 * (cmprs_chn)) // Select coring mode, cmprs_chn = 0..3, data type: x393_cmprs_coring_mode_t (rw)
#define X393_CMPRS_INTERRUPTS(cmprs_chn)                 (0x40001814 + 0x40 * (cmprs_chn)) // Compressor interrupts control (1 - clear, 2 - disable, 3 - enable), cmprs_chn = 0..3, data type: x393_cmprs_interrupts_t (wo)
// Compressor tables load control
// Several tables can be loaded to the compressor, there are 4 types of them:
//     0:quantization tables - 8 pairs can be loaded and switched at run time,
//     1:coring tables -       8 pairs can be loaded and switched at run time,
//     2:focusing tables -    15 tables can be loaded and switched at run time (16-th table address space
//       is used to program other focusing mode parameters,
//     3:Huffman tables -     1 pair tables can be loaded
// Default tables are loaded with the bitstream file (100% quality for quantization table 0
// Loading a table requires to load address of the beginning of data, it includes table type and optional offset
// when multiple tables of the same type are used. Next the data should be written to the same register address,
// the table address is auto-incremented,
// Data for the tables 0..2 should be combined: two items into a single 32-bit DWORD (little endian), treating
// each item as a 16-bit word. The Huffman table is one item per DWORD. Address offset is calculated in DWORDs

// Compressor table types

#define X393_TABLE_QUANTIZATION_TYPE                     0x00000000 // Quantization table type
#define X393_TABLE_CORING_TYPE                           0x00000001 // Coring table type
#define X393_TABLE_FOCUS_TYPE                            0x00000002 // Focus table type
#define X393_TABLE_HUFFMAN_TYPE                          0x00000003 // Huffman table type

// Compressor tables control

#define X393_CMPRS_TABLES_DATA(cmprs_chn)                (0x40001818 + 0x40 * (cmprs_chn)) // Compressor tables data, cmprs_chn = 0..3, data type: u32 (wo)
#define X393_CMPRS_TABLES_ADDRESS(cmprs_chn)             (0x4000181c + 0x40 * (cmprs_chn)) // Compressor tables type/address, cmprs_chn = 0..3, data type: x393_cmprs_table_addr_t (wo)

// Compressor DMA control:

// Camera can be configured to use either 2 AXI HP channels (with 2 compressors served by each one) or to use a single AXI HP channel
// serving all 4 compressor channels through its input ports. Below afi_port (0..3) references to one of the 4 ports of each. Control
// for two AXI HP channels is implemented as separate functions. Currently only the first channel is used
#define X393_AFIMUX0_EN                                  0x40001900 // AFI MUX 0 global/port run/pause control, data type: x393_afimux_en_t (wo)
#define X393_AFIMUX0_RST                                 0x40001904 // AFI MUX 0 per-port resets, data type: x393_afimux_rst_t (rw)
#define X393_AFIMUX0_REPORT_MODE                         0x40001908 // AFI MUX 0 readout pointer report mode, data type: x393_afimux_report_t (wo)
#define X393_AFIMUX0_STATUS_CONTROL                      0x40001910 // AFI MUX 0 status report mode, data type: x393_status_ctrl_t (rw)
#define X393_AFIMUX0_SA(afi_port)                        (0x40001920 + 0x4 * (afi_port)) // AFI MUX 0 DMA buffer start address in 32-byte blocks, afi_port = 0..3, data type: x393_afimux_sa_t (rw)
#define X393_AFIMUX0_LEN(afi_port)                       (0x40001930 + 0x4 * (afi_port)) // AFI MUX 0 DMA buffer length in 32-byte blocks, afi_port = 0..3, data type: x393_afimux_len_t (rw)
// Same for the second AXI HP channel (not currently used)
#define X393_AFIMUX1_EN                                  0x40001940 // AFI MUX 1 global/port run/pause control, data type: x393_afimux_en_t (wo)
#define X393_AFIMUX1_RST                                 0x40001944 // AFI MUX 1 per-port resets, data type: x393_afimux_rst_t (rw)
#define X393_AFIMUX1_REPORT_MODE                         0x40001948 // AFI MUX 1 readout pointer report mode, data type: x393_afimux_report_t (wo)
#define X393_AFIMUX1_STATUS_CONTROL                      0x40001950 // AFI MUX 1 status report mode, data type: x393_status_ctrl_t (rw)
#define X393_AFIMUX1_SA(afi_port)                        (0x40001960 + 0x4 * (afi_port)) // AFI MUX 1 DMA buffer start address in 32-byte blocks, afi_port = 0..3, data type: x393_afimux_sa_t (rw)
#define X393_AFIMUX1_LEN(afi_port)                       (0x40001970 + 0x4 * (afi_port)) // AFI MUX 1 DMA buffer length in 32-byte blocks, afi_port = 0..3, data type: x393_afimux_len_t (rw)

// Read-only sensors status information (pointer offset and last sequence number)

#define X393_AFIMUX0_STATUS(afi_port)                    (0x40002060 + 0x4 * (afi_port)) // Status of the AFI MUX 0 (including image pointer), afi_port = 0..3, data type: x393_afimux_status_t (ro)
#define X393_AFIMUX1_STATUS(afi_port)                    (0x40002070 + 0x4 * (afi_port)) // Status of the AFI MUX 1 (including image pointer), afi_port = 0..3, data type: x393_afimux_status_t (ro)
// 
// GPIO contol. Each of the 10 pins can be controlled by the software - individually or simultaneously or from any of the 3 masters (other FPGA modules)
// Currently these modules are;
//      A - camsync (intercamera synchronization), uses up to 4 pins 
//      B - reserved (not yet used) and 
//      C - logger (IMU, GPS, images), uses 6 pins, including separate i2c available on extension boards
// If several enabled ports try to contol the same bit, highest priority has port C, lowest - software controlled
#define X393_GPIO_SET_PINS                               0x40001c00 // State of the GPIO pins and seq. number, data type: x393_gpio_set_pins_t (wo)
#define X393_GPIO_STATUS_CONTROL                         0x40001c04 // GPIO status control mode, data type: x393_status_ctrl_t (rw)

// Read-only GPIO pins state

#define X393_GPIO_STATUS                                 0x400020c0 // State of the GPIO pins and seq. number, data type: x393_gpio_status_t (ro)

// RTC control

#define X393_RTC_USEC                                    0x40001c10 // RTC microseconds, data type: x393_rtc_usec_t (rw)
#define X393_RTC_SEC_SET                                 0x40001c14 // RTC seconds and set clock, data type: x393_rtc_sec_t (rw)
#define X393_RTC_CORR                                    0x40001c18 // RTC correction (+/- 1/256 full scale), data type: x393_rtc_corr_t (rw)
#define X393_RTC_SET_STATUS                              0x40001c1c // RTC status control mode, write makes a snapshot to be read out, data type: x393_status_ctrl_t (rw)

// Read-only RTC state

#define X393_RTC_STATUS                                  0x400020c4 // RTC status reg, data type: x393_rtc_status_t (ro)
#define X393_RTC_STATUS_SEC                              0x400020c8 // RTC snapshot seconds, data type: x393_rtc_sec_t (ro)
#define X393_RTC_STATUS_USEC                             0x400020cc // RTC snapshot microseconds, data type: x393_rtc_usec_t (ro)

// CAMSYNC control

#define X393_CAMSYNC_MODE                                0x40001c20 // CAMSYNC mode, data type: x393_camsync_mode_t (wo)
#define X393_CAMSYNC_TRIG_SRC                            0x40001c24 // CAMSYNC trigger source, data type: x393_camsync_io_t (wo)
#define X393_CAMSYNC_TRIG_DST                            0x40001c28 // CAMSYNC trigger destination, data type: x393_camsync_io_t (wo)
// Trigger period has special value for small (<255) values written to this register
//     d == 0 - disable (stop periodic mode)
//     d == 1 - single trigger
//     d == 2..255 - set output pulse / input-output serial bit duration (no start generated)
//     d >= 256 - repetitive trigger
#define X393_CAMSYNC_TRIG_PERIOD                         0x40001c2c // CAMSYNC trigger period, data type: u32 (rw)
#define X393_CAMSYNC_TRIG_DELAY(sens_chn)                (0x40001c30 + 0x4 * (sens_chn)) // CAMSYNC trigger delay, sens_chn = 0..3, data type: u32 (rw)

// Command sequencer control

// Controller is programmed through 32 locations. Each registers but the control require two writes:
// First write - register address (AXI_WR_ADDR_BITS bits), second - register data (32 bits)
// Writing to the contol register (0x1f) resets the first/second counter so the next write will be "first"
// 0x0..0xf write directly to the frame number [3:0] modulo 16, except if you write to the frame
//           "just missed" - in that case data will go to the current frame.
//  0x10 - write seq commands to be sent ASAP
//  0x11 - write seq commands to be sent after the next frame starts
// 
//  0x1e - write seq commands to be sent after the next 14 frame start pulses
//  0x1f - control register:
//      [14] -   reset all FIFO (takes 32 clock pulses), also - stops seq until run command
//      [13:12] - 3 - run seq, 2 - stop seq , 1,0 - no change to run state
//        [1:0] - 0: NOP, 1: clear IRQ, 2 - Clear IE, 3: set IE
#define X393_CMDFRAMESEQ_CTRL(sens_chn)                  (0x40001e7c + 0x80 * (sens_chn)) // CMDFRAMESEQ control register, sens_chn = 0..3, data type: x393_cmdframeseq_mode_t (wo)
#define X393_CMDFRAMESEQ_ABS((sens_chn),(offset))        (0x40001e00)+ 0x20 * (sens_chn)+ 0x1 * (offset)) // CMDFRAMESEQ absolute frame address/command, sens_chn = 0..3, offset = 0..15, data type: u32 (wo)
#define X393_CMDFRAMESEQ_REL((sens_chn),(offset))        (0x40001e40)+ 0x20 * (sens_chn)+ 0x1 * (offset)) // CMDFRAMESEQ relative frame address/command, sens_chn = 0..3, offset = 0..14, data type: u32 (wo)
// Command sequencer multiplexer, provides current frame number for each sesnor channel and interrupt status/interrupt masks for them.
// Interrupts and interrupt masks are controlled through channel CMDFRAMESEQ module
#define X393_CMDSEQMUX_STATUS_CTRL                       0x40001c08 // CMDSEQMUX status control mode (status provides current frame numbers), data type: x393_status_ctrl_t (rw)
#define X393_CMDSEQMUX_STATUS                            0x400020e0 // CMDSEQMUX status data (frame numbers and interrupts, data type: x393_cmdseqmux_status_t (ro)

// Event logger

// Event logger configuration/data is writtent to the module ising two 32-bit register locations : data and address.
// Address consists of 2 parts - 2-bit page (configuration, imu, gps, message) and a 5-bit sub-address autoincremented when writing data.
// Register pages:
#define X393_LOGGER_PAGE_CONF                            0x00000000 // Logger configuration page
#define X393_LOGGER_PAGE_IMU                             0x00000003 // Logger IMU parameters page
#define X393_LOGGER_PAGE_GPS                             0x00000001 // Logger GPS parameters page
#define X393_LOGGER_PAGE_MSG                             0x00000002 // Logger MSG (odometer) parameters page
// Register configuration addresses (with X393_LOGGER_PAGE_CONF):
#define X393_LOGGER_PERIOD                               0x00000000 // IMU period (in SPI clocks, high word 0xffff - use IMU ready)
#define X393_LOGGER_BIT_DURATION                         0x00000001 // IMU SPI bit duration (in mclk == 50 ns periods?)
#define X393_LOGGER_BIT_HALF_PERIOD                      0x00000002 // Logger rs232 half bit period (in mclk == 50 ns periods?)
#define X393_LOGGER_CONFIG                               0x00000003 // Logger IMU parameters page
#define X393_LOGGER_STATUS_CTRL                          0x40001c88 // Logger status configuration (to report sample number), data type: x393_status_ctrl_t (rw)
#define X393_LOGGER_DATA                                 0x40001c80 // Logger register write data, data type: x393_logger_data_t (wo)
#define X393_LOGGER_ADDRESS                              0x40001c84 // Logger register write page/address, data type: x393_logger_address_t (wo)
#define X393_LOGGER_STATUS                               0x400020e4 // Logger status data (sequence number), data type: x393_logger_status_t (ro)

// MULT SAXI DMA engine control. Of 4 channels only one (number 0) is currently used - for the event logger

#define X393_MULT_SAXI_STATUS_CTRL                       0x40001ce0 // MULT_SAXI status control mode (status provides current DWORD pointer), data type: x393_status_ctrl_t (rw)
#define X393_MULT_SAXI_BUF_ADDRESS(chn)                  (0x40001cc0 + 0x8 * (chn)) // MULT_SAXI buffer start address in DWORDS, chn = 0..3, data type: x393_mult_saxi_al_t (wo)
#define X393_MULT_SAXI_BUF_LEN(chn)                      (0x40001cc4 + 0x8 * (chn)) // MULT_SAXI buffer length in DWORDS, chn = 0..3, data type: x393_mult_saxi_al_t (wo)
#define X393_MULT_SAXI_STATUS(chn)                       (0x400020d0 + 0x4 * (chn)) // MULT_SAXI current DWORD pointer, chn = 0..3, data type: x393_mult_saxi_al_t (ro)

// MULTI_CLK - global clock generation PLLs. Interface provided for debugging, no interaction is needed for normal operation

#define X393_MULTICLK_STATUS_CTRL                        0x40001ca4 // MULTI_CLK status generation (do not use or do not set auto), data type: x393_status_ctrl_t (rw)
#define X393_MULTICLK_CTRL                               0x40001ca0 // MULTI_CLK reset and power down control, data type: x393_multiclk_ctl_t (rw)
#define X393_MULTICLK_STATUS                             0x400020e8 // MULTI_CLK lock and toggle state, data type: x393_multiclk_status_t (ro)

// Debug ring module

// Debug ring module (when enabled with DEBUG_RING in system_defines.vh) provides low-overhead read/write access to internal test points
// To write data you need to write 32-bit data with x393_debug_shift(u32) multiple times to fill the ring register (length depends on
// implementation), skip this step if only reading from the modules under test is required.
// Exchange data with x393_debug_load(), the data from the ring shift register.
// Write 0xffffffff (or other "magic" data) if the ring length is unknown - this DWORD will appear on the output after the useful data
// Read all data, waiting for status sequence number to be incremented,status mode should be set to auto (3) wor each DWORD certain
// number of times or until the "magic" DWORD appears, writing "magic" to shift out next 32 bits.
#define X393_DEBUG_STATUS_CTRL                           0x40001c48 // Debug ring status generation - set to auto(3) if used, data type: x393_status_ctrl_t (rw)
#define X393_DEBUG_LOAD                                  0x40001c44 // Debug ring copy shift register to/from tested modules
#define X393_DEBUG_SHIFT                                 0x40001c40 // Debug ring shift ring by 32 bits, data type: u32 (wo)
#define X393_DEBUG_STATUS                                0x400023f0 // Debug read status (watch sequence number), data type: x393_debug_status_t (ro)
#define X393_DEBUG_READ                                  0x400023f4 // Debug read DWORD form ring register, data type: u32 (ro)

// Write-only addresses to program memory channel 3 (test channel)

#define X393_MCNTRL_CHN3_SCANLINE_MODE                   0x400004c0 // Set mode register (write last after other channel registers are set), data type: x393_mcntrl_mode_scan_t (wo)
#define X393_MCNTRL_CHN3_SCANLINE_STATUS_CNTRL           0x400004c4 // Set status control register (status update mode), data type: x393_status_ctrl_t (rw)
#define X393_MCNTRL_CHN3_SCANLINE_STARTADDR              0x400004c8 // Set frame start address, data type: x393_mcntrl_window_frame_sa_t (wo)
#define X393_MCNTRL_CHN3_SCANLINE_FRAME_SIZE             0x400004cc // Set frame size (address increment), data type: x393_mcntrl_window_frame_sa_inc_t (wo)
#define X393_MCNTRL_CHN3_SCANLINE_FRAME_LAST             0x400004d0 // Set last frame number (number of frames in buffer minus 1), data type: x393_mcntrl_window_last_frame_num_t (wo)
#define X393_MCNTRL_CHN3_SCANLINE_FRAME_FULL_WIDTH       0x400004d4 // Set frame full(padded) width, data type: x393_mcntrl_window_full_width_t (wo)
#define X393_MCNTRL_CHN3_SCANLINE_WINDOW_WH              0x400004d8 // Set frame window size, data type: x393_mcntrl_window_width_height_t (wo)
#define X393_MCNTRL_CHN3_SCANLINE_WINDOW_X0Y0            0x400004dc // Set frame position, data type: x393_mcntrl_window_left_top_t (wo)
#define X393_MCNTRL_CHN3_SCANLINE_STARTXY                0x400004e0 // Set startXY register, data type: x393_mcntrl_window_startx_starty_t (wo)

// Write-only addresses to program memory channel 2 (test channel)

#define X393_MCNTRL_CHN2_TILED_MODE                      0x40000500 // Set mode register (write last after other channel registers are set), data type: x393_mcntrl_mode_scan_t (wo)
#define X393_MCNTRL_CHN2_TILED_STATUS_CNTRL              0x40000504 // Set status control register (status update mode), data type: x393_status_ctrl_t (rw)
#define X393_MCNTRL_CHN2_TILED_STARTADDR                 0x40000508 // Set frame start address, data type: x393_mcntrl_window_frame_sa_t (wo)
#define X393_MCNTRL_CHN2_TILED_FRAME_SIZE                0x4000050c // Set frame size (address increment), data type: x393_mcntrl_window_frame_sa_inc_t (wo)
#define X393_MCNTRL_CHN2_TILED_FRAME_LAST                0x40000510 // Set last frame number (number of frames in buffer minus 1), data type: x393_mcntrl_window_last_frame_num_t (wo)
#define X393_MCNTRL_CHN2_TILED_FRAME_FULL_WIDTH          0x40000514 // Set frame full(padded) width, data type: x393_mcntrl_window_full_width_t (wo)
#define X393_MCNTRL_CHN2_TILED_WINDOW_WH                 0x40000518 // Set frame window size, data type: x393_mcntrl_window_width_height_t (wo)
#define X393_MCNTRL_CHN2_TILED_WINDOW_X0Y0               0x4000051c // Set frame position, data type: x393_mcntrl_window_left_top_t (wo)
#define X393_MCNTRL_CHN2_TILED_STARTXY                   0x40000520 // Set startXY register, data type: x393_mcntrl_window_startx_starty_t (wo)
#define X393_MCNTRL_CHN2_TILED_TILE_WHS                  0x40000524 // Set tile size/step (tiled mode only), data type: x393_mcntrl_window_tile_whs_t (wo)

// Write-only addresses to program memory channel 4 (test channel)

#define X393_MCNTRL_CHN4_TILED_MODE                      0x40000540 // Set mode register (write last after other channel registers are set), data type: x393_mcntrl_mode_scan_t (wo)
#define X393_MCNTRL_CHN4_TILED_STATUS_CNTRL              0x40000544 // Set status control register (status update mode), data type: x393_status_ctrl_t (rw)
#define X393_MCNTRL_CHN4_TILED_STARTADDR                 0x40000548 // Set frame start address, data type: x393_mcntrl_window_frame_sa_t (wo)
#define X393_MCNTRL_CHN4_TILED_FRAME_SIZE                0x4000054c // Set frame size (address increment), data type: x393_mcntrl_window_frame_sa_inc_t (wo)
#define X393_MCNTRL_CHN4_TILED_FRAME_LAST                0x40000550 // Set last frame number (number of frames in buffer minus 1), data type: x393_mcntrl_window_last_frame_num_t (wo)
#define X393_MCNTRL_CHN4_TILED_FRAME_FULL_WIDTH          0x40000554 // Set frame full(padded) width, data type: x393_mcntrl_window_full_width_t (wo)
#define X393_MCNTRL_CHN4_TILED_WINDOW_WH                 0x40000558 // Set frame window size, data type: x393_mcntrl_window_width_height_t (wo)
#define X393_MCNTRL_CHN4_TILED_WINDOW_X0Y0               0x4000055c // Set frame position, data type: x393_mcntrl_window_left_top_t (wo)
#define X393_MCNTRL_CHN4_TILED_STARTXY                   0x40000560 // Set startXY register, data type: x393_mcntrl_window_startx_starty_t (wo)
#define X393_MCNTRL_CHN4_TILED_TILE_WHS                  0x40000564 // Set tile size/step (tiled mode only), data type: x393_mcntrl_window_tile_whs_t (wo)

