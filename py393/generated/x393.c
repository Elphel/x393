/*******************************************************************************
 * File: x393.c
 * Date: 2016-04-06  
 * Author: auto-generated file, see x393_export_c.py
 * Description: Functions definitions to access x393 hardware registers
 *******************************************************************************/

#include <linux/io.h>
#include "x393.h"

static void __iomem* mmio_ptr;

// init_mmio_ptr() should be called once before using any of the other defined functions

int init_mmio_ptr(void) {mmio_ptr = ioremap(0x40000000, 0x00003000); if (!mmio_ptr) return -1; else return 0;}

// R/W addresses to set up memory arbiter priorities. For sensors  (chn = 8..11), for compressors - 12..15

void                         set_x393_mcntrl_arbiter_priority    (x393_arbite_pri_t d, int chn){writel(d.d32, mmio_ptr + (0x0180 + 0x4 * chn));} // Set memory arbiter priority (currently r/w, may become just wo)
x393_arbite_pri_t            get_x393_mcntrl_arbiter_priority    (int chn)           { x393_arbite_pri_t d; d.d32 = readl(mmio_ptr + (0x0180 + 0x4 * chn)); return d; }

// Enable/disable memory channels (bits in a 16-bit word). For sensors  (chn = 8..11), for compressors - 12..15

void                         set_x393_mcntrl_chn_en              (x393_mcntr_chn_en_t d){writel(d.d32, mmio_ptr + 0x01c0);}        // Enable/disable memory channels (currently r/w, may become just wo)
x393_mcntr_chn_en_t          get_x393_mcntrl_chn_en              (void)              { x393_mcntr_chn_en_t d; d.d32 = readl(mmio_ptr + 0x01c0); return d; }
void                         set_x393_mcntrl_dqs_dqm_patt        (x393_mcntr_dqs_dqm_patt_t d){writel(d.d32, mmio_ptr + 0x0140);}  // Setup DQS and DQM patterns
x393_mcntr_dqs_dqm_patt_t    get_x393_mcntrl_dqs_dqm_patt        (void)              { x393_mcntr_dqs_dqm_patt_t d; d.d32 = readl(mmio_ptr + 0x0140); return d; }
void                         set_x393_mcntrl_dq_dqs_tri          (x393_mcntr_dqs_dqm_tri_t d){writel(d.d32, mmio_ptr + 0x0144);}   // Setup DQS and DQ on/off sequence
x393_mcntr_dqs_dqm_tri_t     get_x393_mcntrl_dq_dqs_tri          (void)              { x393_mcntr_dqs_dqm_tri_t d; d.d32 = readl(mmio_ptr + 0x0144); return d; }

// Following enable/disable addresses can be written with any data, only addresses matter

void                         x393_mcntrl_dis                     (void)              {writel(0, mmio_ptr + 0x00c0);}               // Disable DDR3 memory controller
void                         x393_mcntrl_en                      (void)              {writel(0, mmio_ptr + 0x00c4);}               // Enable DDR3 memory controller
void                         x393_mcntrl_refresh_dis             (void)              {writel(0, mmio_ptr + 0x00c8);}               // Disable DDR3 memory refresh
void                         x393_mcntrl_refresh_en              (void)              {writel(0, mmio_ptr + 0x00cc);}               // Enable DDR3 memory refresh
void                         x393_mcntrl_sdrst_dis               (void)              {writel(0, mmio_ptr + 0x0098);}               // Disable DDR3 memory reset
void                         x393_mcntrl_sdrst_en                (void)              {writel(0, mmio_ptr + 0x009c);}               // Enable DDR3 memory reset
void                         x393_mcntrl_cke_dis                 (void)              {writel(0, mmio_ptr + 0x00a0);}               // Disable DDR3 memory CKE
void                         x393_mcntrl_cke_en                  (void)              {writel(0, mmio_ptr + 0x00a4);}               // Enable DDR3 memory CKE
void                         x393_mcntrl_cmda_dis                (void)              {writel(0, mmio_ptr + 0x0090);}               // Disable DDR3 memory command/address lines
void                         x393_mcntrl_cmda_en                 (void)              {writel(0, mmio_ptr + 0x0094);}               // Enable DDR3 memory command/address lines

// Set DDR3 memory controller I/O delays and other timing parameters (should use individually calibrated values)

void                         set_x393_mcntrl_dq_odly0            (x393_dly_t d, int chn){writel(d.d32, mmio_ptr + (0x0200 + 0x4 * chn));} // Lane0 DQ output delays 
x393_dly_t                   get_x393_mcntrl_dq_odly0            (int chn)           { x393_dly_t d; d.d32 = readl(mmio_ptr + (0x0200 + 0x4 * chn)); return d; }
void                         set_x393_mcntrl_dq_odly1            (x393_dly_t d, int chn){writel(d.d32, mmio_ptr + (0x0280 + 0x4 * chn));} // Lane1 DQ output delays 
x393_dly_t                   get_x393_mcntrl_dq_odly1            (int chn)           { x393_dly_t d; d.d32 = readl(mmio_ptr + (0x0280 + 0x4 * chn)); return d; }
void                         set_x393_mcntrl_dq_idly0            (x393_dly_t d, int chn){writel(d.d32, mmio_ptr + (0x0240 + 0x4 * chn));} // Lane0 DQ input delays 
x393_dly_t                   get_x393_mcntrl_dq_idly0            (int chn)           { x393_dly_t d; d.d32 = readl(mmio_ptr + (0x0240 + 0x4 * chn)); return d; }
void                         set_x393_mcntrl_dq_idly1            (x393_dly_t d, int chn){writel(d.d32, mmio_ptr + (0x02c0 + 0x4 * chn));} // Lane1 DQ input delays 
x393_dly_t                   get_x393_mcntrl_dq_idly1            (int chn)           { x393_dly_t d; d.d32 = readl(mmio_ptr + (0x02c0 + 0x4 * chn)); return d; }
void                         set_x393_mcntrl_dqs_odly0           (x393_dly_t d)      {writel(d.d32, mmio_ptr + 0x0220);}           // Lane0 DQS output delay 
x393_dly_t                   get_x393_mcntrl_dqs_odly0           (void)              { x393_dly_t d; d.d32 = readl(mmio_ptr + 0x0220); return d; }
void                         set_x393_mcntrl_dqs_odly1           (x393_dly_t d)      {writel(d.d32, mmio_ptr + 0x02a0);}           // Lane1 DQS output delay 
x393_dly_t                   get_x393_mcntrl_dqs_odly1           (void)              { x393_dly_t d; d.d32 = readl(mmio_ptr + 0x02a0); return d; }
void                         set_x393_mcntrl_dqs_idly0           (x393_dly_t d)      {writel(d.d32, mmio_ptr + 0x0260);}           // Lane0 DQS input delay 
x393_dly_t                   get_x393_mcntrl_dqs_idly0           (void)              { x393_dly_t d; d.d32 = readl(mmio_ptr + 0x0260); return d; }
void                         set_x393_mcntrl_dqs_idly1           (x393_dly_t d)      {writel(d.d32, mmio_ptr + 0x02e0);}           // Lane1 DQS input delay 
x393_dly_t                   get_x393_mcntrl_dqs_idly1           (void)              { x393_dly_t d; d.d32 = readl(mmio_ptr + 0x02e0); return d; }
void                         set_x393_mcntrl_dm_odly0            (x393_dly_t d)      {writel(d.d32, mmio_ptr + 0x0224);}           // Lane0 DM output delay 
x393_dly_t                   get_x393_mcntrl_dm_odly0            (void)              { x393_dly_t d; d.d32 = readl(mmio_ptr + 0x0224); return d; }
void                         set_x393_mcntrl_dm_odly1            (x393_dly_t d)      {writel(d.d32, mmio_ptr + 0x02a4);}           // Lane1 DM output delay 
x393_dly_t                   get_x393_mcntrl_dm_odly1            (void)              { x393_dly_t d; d.d32 = readl(mmio_ptr + 0x02a4); return d; }
void                         set_x393_mcntrl_cmda_odly           (x393_dly_t d, int chn){writel(d.d32, mmio_ptr + (0x0300 + 0x4 * chn));} // Address, bank and commands delays
x393_dly_t                   get_x393_mcntrl_cmda_odly           (int chn)           { x393_dly_t d; d.d32 = readl(mmio_ptr + (0x0300 + 0x4 * chn)); return d; }
void                         set_x393_mcntrl_phase               (x393_dly_t d)      {writel(d.d32, mmio_ptr + 0x0380);}           // Clock phase
x393_dly_t                   get_x393_mcntrl_phase               (void)              { x393_dly_t d; d.d32 = readl(mmio_ptr + 0x0380); return d; }
void                         x393_mcntrl_dly_set                 (void)              {writel(0, mmio_ptr + 0x0080);}               // Set all pre-programmed delays
void                         set_x393_mcntrl_wbuf_dly            (x393_wbuf_dly_t d) {writel(d.d32, mmio_ptr + 0x0148);}           // Set write buffer delay
x393_wbuf_dly_t              get_x393_mcntrl_wbuf_dly            (void)              { x393_wbuf_dly_t d; d.d32 = readl(mmio_ptr + 0x0148); return d; }

// Write-only addresses to program memory channels for sensors  (chn = 0..3), memory channels 8..11

void                         x393_sens_mcntrl_scanline_mode      (x393_mcntrl_mode_scan_t d, int chn){writel(d.d32, mmio_ptr + (0x1a00 + 0x40 * chn));} // Set mode register (write last after other channel registers are set)
void                         set_x393_sens_mcntrl_scanline_status_cntrl(x393_status_ctrl_t d, int chn){writel(d.d32, mmio_ptr + (0x1a04 + 0x40 * chn));} // Set status control register (status update mode)
x393_status_ctrl_t           get_x393_sens_mcntrl_scanline_status_cntrl(int chn)     { x393_status_ctrl_t d; d.d32 = readl(mmio_ptr + (0x1a04 + 0x40 * chn)); return d; }
void                         x393_sens_mcntrl_scanline_startaddr (x393_mcntrl_window_frame_sa_t d, int chn){writel(d.d32, mmio_ptr + (0x1a08 + 0x40 * chn));} // Set frame start address
void                         x393_sens_mcntrl_scanline_frame_size(x393_mcntrl_window_frame_sa_inc_t d, int chn){writel(d.d32, mmio_ptr + (0x1a0c + 0x40 * chn));} // Set frame size (address increment)
void                         x393_sens_mcntrl_scanline_frame_last(x393_mcntrl_window_last_frame_num_t d, int chn){writel(d.d32, mmio_ptr + (0x1a10 + 0x40 * chn));} // Set last frame number (number of frames in buffer minus 1)
void                         x393_sens_mcntrl_scanline_frame_full_width(x393_mcntrl_window_full_width_t d, int chn){writel(d.d32, mmio_ptr + (0x1a14 + 0x40 * chn));} // Set frame full(padded) width
void                         x393_sens_mcntrl_scanline_window_wh (x393_mcntrl_window_width_height_t d, int chn){writel(d.d32, mmio_ptr + (0x1a18 + 0x40 * chn));} // Set frame window size
void                         x393_sens_mcntrl_scanline_window_x0y0(x393_mcntrl_window_left_top_t d, int chn){writel(d.d32, mmio_ptr + (0x1a1c + 0x40 * chn));} // Set frame position
void                         x393_sens_mcntrl_scanline_startxy   (x393_mcntrl_window_startx_starty_t d, int chn){writel(d.d32, mmio_ptr + (0x1a20 + 0x40 * chn));} // Set startXY register

// Write-only addresses to program memory channels for compressors (chn = 0..3), memory channels 12..15

void                         x393_sens_mcntrl_tiled_mode         (x393_mcntrl_mode_scan_t d, int chn){writel(d.d32, mmio_ptr + (0x1b00 + 0x40 * chn));} // Set mode register (write last after other channel registers are set)
void                         set_x393_sens_mcntrl_tiled_status_cntrl(x393_status_ctrl_t d, int chn){writel(d.d32, mmio_ptr + (0x1b04 + 0x40 * chn));} // Set status control register (status update mode)
x393_status_ctrl_t           get_x393_sens_mcntrl_tiled_status_cntrl(int chn)        { x393_status_ctrl_t d; d.d32 = readl(mmio_ptr + (0x1b04 + 0x40 * chn)); return d; }
void                         x393_sens_mcntrl_tiled_startaddr    (x393_mcntrl_window_frame_sa_t d, int chn){writel(d.d32, mmio_ptr + (0x1b08 + 0x40 * chn));} // Set frame start address
void                         x393_sens_mcntrl_tiled_frame_size   (x393_mcntrl_window_frame_sa_inc_t d, int chn){writel(d.d32, mmio_ptr + (0x1b0c + 0x40 * chn));} // Set frame size (address increment)
void                         x393_sens_mcntrl_tiled_frame_last   (x393_mcntrl_window_last_frame_num_t d, int chn){writel(d.d32, mmio_ptr + (0x1b10 + 0x40 * chn));} // Set last frame number (number of frames in buffer minus 1)
void                         x393_sens_mcntrl_tiled_frame_full_width(x393_mcntrl_window_full_width_t d, int chn){writel(d.d32, mmio_ptr + (0x1b14 + 0x40 * chn));} // Set frame full(padded) width
void                         x393_sens_mcntrl_tiled_window_wh    (x393_mcntrl_window_width_height_t d, int chn){writel(d.d32, mmio_ptr + (0x1b18 + 0x40 * chn));} // Set frame window size
void                         x393_sens_mcntrl_tiled_window_x0y0  (x393_mcntrl_window_left_top_t d, int chn){writel(d.d32, mmio_ptr + (0x1b1c + 0x40 * chn));} // Set frame position
void                         x393_sens_mcntrl_tiled_startxy      (x393_mcntrl_window_startx_starty_t d, int chn){writel(d.d32, mmio_ptr + (0x1b20 + 0x40 * chn));} // Set startXY register
void                         x393_sens_mcntrl_tiled_tile_whs     (x393_mcntrl_window_tile_whs_t d, int chn){writel(d.d32, mmio_ptr + (0x1b24 + 0x40 * chn));} // Set tile size/step (tiled mode only)

// Write-only addresses to program memory channel for membridge, memory channel 1

void                         x393_membridge_scanline_mode        (x393_mcntrl_mode_scan_t d){writel(d.d32, mmio_ptr + 0x0480);}    // Set mode register (write last after other channel registers are set)
void                         set_x393_membridge_scanline_status_cntrl(x393_status_ctrl_t d){writel(d.d32, mmio_ptr + 0x0484);}     // Set status control register (status update mode)
x393_status_ctrl_t           get_x393_membridge_scanline_status_cntrl(void)          { x393_status_ctrl_t d; d.d32 = readl(mmio_ptr + 0x0484); return d; }
void                         x393_membridge_scanline_startaddr   (x393_mcntrl_window_frame_sa_t d){writel(d.d32, mmio_ptr + 0x0488);} // Set frame start address
void                         x393_membridge_scanline_frame_size  (x393_mcntrl_window_frame_sa_inc_t d){writel(d.d32, mmio_ptr + 0x048c);} // Set frame size (address increment)
void                         x393_membridge_scanline_frame_last  (x393_mcntrl_window_last_frame_num_t d){writel(d.d32, mmio_ptr + 0x0490);} // Set last frame number (number of frames in buffer minus 1)
void                         x393_membridge_scanline_frame_full_width(x393_mcntrl_window_full_width_t d){writel(d.d32, mmio_ptr + 0x0494);} // Set frame full(padded) width
void                         x393_membridge_scanline_window_wh   (x393_mcntrl_window_width_height_t d){writel(d.d32, mmio_ptr + 0x0498);} // Set frame window size
void                         x393_membridge_scanline_window_x0y0 (x393_mcntrl_window_left_top_t d){writel(d.d32, mmio_ptr + 0x049c);} // Set frame position
void                         x393_membridge_scanline_startxy     (x393_mcntrl_window_startx_starty_t d){writel(d.d32, mmio_ptr + 0x04a0);} // Set startXY register
void                         x393_membridge_ctrl                 (x393_membridge_cmd_t d){writel(d.d32, mmio_ptr + 0x0800);}       // Issue membridge command
void                         set_x393_membridge_status_cntrl     (x393_status_ctrl_t d){writel(d.d32, mmio_ptr + 0x0804);}         // Set membridge status control register
x393_status_ctrl_t           get_x393_membridge_status_cntrl     (void)              { x393_status_ctrl_t d; d.d32 = readl(mmio_ptr + 0x0804); return d; }
void                         x393_membridge_lo_addr64            (u29_t d)           {writel(d.d32, mmio_ptr + 0x0808);}           // start address of the system memory range in QWORDs (4 LSBs==0)
void                         x393_membridge_size64               (u29_t d)           {writel(d.d32, mmio_ptr + 0x080c);}           // size of the system memory range in QWORDs (4 LSBs==0), rolls over
void                         x393_membridge_start64              (u29_t d)           {writel(d.d32, mmio_ptr + 0x0810);}           // start of transfer offset to system memory range in QWORDs (4 LSBs==0)
void                         x393_membridge_len64                (u29_t d)           {writel(d.d32, mmio_ptr + 0x0814);}           // Full length of transfer in QWORDs
void                         x393_membridge_width64              (u29_t d)           {writel(d.d32, mmio_ptr + 0x0818);}           // Frame width in QWORDs (last xfer in each line may be partial)
void                         x393_membridge_mode                 (x393_membridge_mode_t d){writel(d.d32, mmio_ptr + 0x081c);}      // AXI cache mode

// Write-only addresses to PS PIO (Software generated DDR3 memory access sequences)

void                         x393_mcntrl_ps_en_rst               (x393_ps_pio_en_rst_t d){writel(d.d32, mmio_ptr + 0x0400);}       // Set PS PIO enable and reset
void                         x393_mcntrl_ps_cmd                  (x393_ps_pio_cmd_t d){writel(d.d32, mmio_ptr + 0x0404);}          // Set PS PIO commands
void                         set_x393_mcntrl_ps_status_cntrl     (x393_status_ctrl_t d){writel(d.d32, mmio_ptr + 0x0408);}         // Set PS PIO status control register (status update mode)
x393_status_ctrl_t           get_x393_mcntrl_ps_status_cntrl     (void)              { x393_status_ctrl_t d; d.d32 = readl(mmio_ptr + 0x0408); return d; }

// Write-only addresses to to program status report mode for memory controller

void                         set_x393_mcontr_phy_status_cntrl    (x393_status_ctrl_t d){writel(d.d32, mmio_ptr + 0x0150);}         // Set status control register (status update mode)
x393_status_ctrl_t           get_x393_mcontr_phy_status_cntrl    (void)              { x393_status_ctrl_t d; d.d32 = readl(mmio_ptr + 0x0150); return d; }
void                         set_x393_mcontr_top_16bit_status_cntrl(x393_status_ctrl_t d){writel(d.d32, mmio_ptr + 0x014c);}       // Set status control register (status update mode)
x393_status_ctrl_t           get_x393_mcontr_top_16bit_status_cntrl(void)            { x393_status_ctrl_t d; d.d32 = readl(mmio_ptr + 0x014c); return d; }

// Write-only addresses to to program status report mode for test channels

void                         set_x393_mcntrl_test01_chn2_status_cntrl(x393_status_ctrl_t d){writel(d.d32, mmio_ptr + 0x03d4);}     // Set status control register (status update mode)
x393_status_ctrl_t           get_x393_mcntrl_test01_chn2_status_cntrl(void)          { x393_status_ctrl_t d; d.d32 = readl(mmio_ptr + 0x03d4); return d; }
void                         set_x393_mcntrl_test01_chn3_status_cntrl(x393_status_ctrl_t d){writel(d.d32, mmio_ptr + 0x03dc);}     // Set status control register (status update mode)
x393_status_ctrl_t           get_x393_mcntrl_test01_chn3_status_cntrl(void)          { x393_status_ctrl_t d; d.d32 = readl(mmio_ptr + 0x03dc); return d; }
void                         set_x393_mcntrl_test01_chn4_status_cntrl(x393_status_ctrl_t d){writel(d.d32, mmio_ptr + 0x03e4);}     // Set status control register (status update mode)
x393_status_ctrl_t           get_x393_mcntrl_test01_chn4_status_cntrl(void)          { x393_status_ctrl_t d; d.d32 = readl(mmio_ptr + 0x03e4); return d; }

// Write-only addresses for test channels commands

void                         x393_mcntrl_test01_chn2_mode        (x393_test01_mode_t d){writel(d.d32, mmio_ptr + 0x03d0);}         // Set command for test01 channel 2
void                         x393_mcntrl_test01_chn3_mode        (x393_test01_mode_t d){writel(d.d32, mmio_ptr + 0x03d8);}         // Set command for test01 channel 3
void                         x393_mcntrl_test01_chn4_mode        (x393_test01_mode_t d){writel(d.d32, mmio_ptr + 0x03e0);}         // Set command for test01 channel 4

// Read-only addresses for status information

x393_status_mcntrl_phy_t     x393_mcontr_phy_status              (void)              { x393_status_mcntrl_phy_t d; d.d32 = readl(mmio_ptr + 0x2000); return d; } // Status register for MCNTRL PHY
x393_status_mcntrl_top_t     x393_mcontr_top_status              (void)              { x393_status_mcntrl_top_t d; d.d32 = readl(mmio_ptr + 0x2004); return d; } // Status register for MCNTRL requests
x393_status_mcntrl_ps_t      x393_mcntrl_ps_status               (void)              { x393_status_mcntrl_ps_t d; d.d32 = readl(mmio_ptr + 0x2008); return d; } // Status register for MCNTRL software R/W
x393_status_mcntrl_lintile_t x393_mcntrl_chn1_status             (void)              { x393_status_mcntrl_lintile_t d; d.d32 = readl(mmio_ptr + 0x2010); return d; } // Status register for MCNTRL CHN1 (membridge)
x393_status_mcntrl_lintile_t x393_mcntrl_chn3_status             (void)              { x393_status_mcntrl_lintile_t d; d.d32 = readl(mmio_ptr + 0x2018); return d; } // Status register for MCNTRL CHN3 (scanline)
x393_status_mcntrl_lintile_t x393_mcntrl_chn2_status             (void)              { x393_status_mcntrl_lintile_t d; d.d32 = readl(mmio_ptr + 0x2014); return d; } // Status register for MCNTRL CHN2 (tiled)
x393_status_mcntrl_lintile_t x393_mcntrl_chn4_status             (void)              { x393_status_mcntrl_lintile_t d; d.d32 = readl(mmio_ptr + 0x201c); return d; } // Status register for MCNTRL CHN4 (tiled)
x393_status_mcntrl_testchn_t x393_test01_chn2_status             (void)              { x393_status_mcntrl_testchn_t d; d.d32 = readl(mmio_ptr + 0x20f4); return d; } // Status register for test channel 2
x393_status_mcntrl_testchn_t x393_test01_chn3_status             (void)              { x393_status_mcntrl_testchn_t d; d.d32 = readl(mmio_ptr + 0x20f8); return d; } // Status register for test channel 3
x393_status_mcntrl_testchn_t x393_test01_chn4_status             (void)              { x393_status_mcntrl_testchn_t d; d.d32 = readl(mmio_ptr + 0x20fc); return d; } // Status register for test channel 4
x393_status_membridge_t      x393_membridge_status               (void)              { x393_status_membridge_t d; d.d32 = readl(mmio_ptr + 0x20ec); return d; } // Status register for membridge

// Write-only control of the sensor channels

void                         x393_sens_mode                      (x393_sens_mode_t d, int sens_num){writel(d.d32, mmio_ptr + (0x1000 + 0x100 * sens_num));} // Write sensor channel mode
void                         x393_sensi2c_ctrl                   (x393_i2c_ctltbl_t d, int sens_num){writel(d.d32, mmio_ptr + (0x1008 + 0x100 * sens_num));} // Control sensor i2c, write i2c LUT
void                         set_x393_sensi2c_status_ctrl        (x393_status_ctrl_t d, int sens_num){writel(d.d32, mmio_ptr + (0x100c + 0x100 * sens_num));} // Setup sensor i2c status report mode
x393_status_ctrl_t           get_x393_sensi2c_status_ctrl        (int sens_num)      { x393_status_ctrl_t d; d.d32 = readl(mmio_ptr + (0x100c + 0x100 * sens_num)); return d; }
void                         x393_sens_sync_mult                 (x393_sens_sync_mult_t d, int sens_num){writel(d.d32, mmio_ptr + (0x1018 + 0x100 * sens_num));} // Configure frames combining
void                         x393_sens_sync_late                 (x393_sens_sync_late_t d, int sens_num){writel(d.d32, mmio_ptr + (0x101c + 0x100 * sens_num));} // Configure frame sync delay
void                         x393_sensio_ctrl                    (x393_sensio_ctl_t d, int sens_num){writel(d.d32, mmio_ptr + (0x1020 + 0x100 * sens_num));} // Configure sensor I/O port
void                         set_x393_sensio_status_cntrl        (x393_status_ctrl_t d, int sens_num){writel(d.d32, mmio_ptr + (0x1024 + 0x100 * sens_num));} // Set status control for SENSIO module
x393_status_ctrl_t           get_x393_sensio_status_cntrl        (int sens_num)      { x393_status_ctrl_t d; d.d32 = readl(mmio_ptr + (0x1024 + 0x100 * sens_num)); return d; }
void                         x393_sensio_jtag                    (x393_sensio_jtag_t d, int sens_num){writel(d.d32, mmio_ptr + (0x1028 + 0x100 * sens_num));} // Programming interface for multiplexer FPGA (with X393_SENSIO_STATUS)
void                         set_x393_sensio_width               (x393_sensio_width_t d, int sens_num){writel(d.d32, mmio_ptr + (0x102c + 0x100 * sens_num));} // Set sensor line in pixels (0 - use line sync from the sensor)
x393_sensio_width_t          get_x393_sensio_width               (int sens_num)      { x393_sensio_width_t d; d.d32 = readl(mmio_ptr + (0x102c + 0x100 * sens_num)); return d; }
void                         set_x393_sensio_tim0                (x393_sensio_tim0_t d, int sens_num){writel(d.d32, mmio_ptr + (0x1030 + 0x100 * sens_num));} // Sensor port i/o timing configuration, register 0
x393_sensio_tim0_t           get_x393_sensio_tim0                (int sens_num)      { x393_sensio_tim0_t d; d.d32 = readl(mmio_ptr + (0x1030 + 0x100 * sens_num)); return d; }
void                         set_x393_sensio_tim1                (x393_sensio_tim1_t d, int sens_num){writel(d.d32, mmio_ptr + (0x1034 + 0x100 * sens_num));} // Sensor port i/o timing configuration, register 1
x393_sensio_tim1_t           get_x393_sensio_tim1                (int sens_num)      { x393_sensio_tim1_t d; d.d32 = readl(mmio_ptr + (0x1034 + 0x100 * sens_num)); return d; }
void                         set_x393_sensio_tim2                (x393_sensio_tim2_t d, int sens_num){writel(d.d32, mmio_ptr + (0x1038 + 0x100 * sens_num));} // Sensor port i/o timing configuration, register 2
x393_sensio_tim2_t           get_x393_sensio_tim2                (int sens_num)      { x393_sensio_tim2_t d; d.d32 = readl(mmio_ptr + (0x1038 + 0x100 * sens_num)); return d; }
void                         set_x393_sensio_tim3                (x393_sensio_tim3_t d, int sens_num){writel(d.d32, mmio_ptr + (0x103c + 0x100 * sens_num));} // Sensor port i/o timing configuration, register 3
x393_sensio_tim3_t           get_x393_sensio_tim3                (int sens_num)      { x393_sensio_tim3_t d; d.d32 = readl(mmio_ptr + (0x103c + 0x100 * sens_num)); return d; }

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

void                         x393_sensi2c_abs                    (u32 d, int sens_num, int offset){writel(d, mmio_ptr + (0x1040 + 0x40 * sens_num + 0x1 * offset));} // Write sensor i2c sequencer
void                         x393_sensi2c_rel                    (u32 d, int sens_num, int offset){writel(d, mmio_ptr + (0x1080 + 0x40 * sens_num + 0x1 * offset));} // Write sensor i2c sequencer

// Lens vignetting correction (for each sub-frame separately)

void                         set_x393_lens_height0_m1            (x393_lens_height_m1_t d, int sens_num){writel(d.d32, mmio_ptr + (0x10f0 + 0x100 * sens_num));} // Subframe 0 height minus 1
x393_lens_height_m1_t        get_x393_lens_height0_m1            (int sens_num)      { x393_lens_height_m1_t d; d.d32 = readl(mmio_ptr + (0x10f0 + 0x100 * sens_num)); return d; }
void                         set_x393_lens_height1_m1            (x393_lens_height_m1_t d, int sens_num){writel(d.d32, mmio_ptr + (0x10f4 + 0x100 * sens_num));} // Subframe 1 height minus 1
x393_lens_height_m1_t        get_x393_lens_height1_m1            (int sens_num)      { x393_lens_height_m1_t d; d.d32 = readl(mmio_ptr + (0x10f4 + 0x100 * sens_num)); return d; }
void                         set_x393_lens_height2_m1            (x393_lens_height_m1_t d, int sens_num){writel(d.d32, mmio_ptr + (0x10f8 + 0x100 * sens_num));} // Subframe 2 height minus 1
x393_lens_height_m1_t        get_x393_lens_height2_m1            (int sens_num)      { x393_lens_height_m1_t d; d.d32 = readl(mmio_ptr + (0x10f8 + 0x100 * sens_num)); return d; }
void                         x393_lens_corr_cnh_addr_data        (x393_lens_corr_t d, int sens_num){writel(d.d32, mmio_ptr + (0x10fc + 0x100 * sens_num));} // Combined address/data to write lens vignetting correction coefficients

// Lens vignetting coefficient addresses - use with x393_lens_corr_wo_t (X393_LENS_CORR_CNH_ADDR_DATA)


// Sensor gamma conversion control (See Python code for examples of the table data generation)

void                         set_x393_sens_gamma_ctrl            (x393_gamma_ctl_t d, int sens_num){writel(d.d32, mmio_ptr + (0x10e0 + 0x100 * sens_num));} // Gamma module control
x393_gamma_ctl_t             get_x393_sens_gamma_ctrl            (int sens_num)      { x393_gamma_ctl_t d; d.d32 = readl(mmio_ptr + (0x10e0 + 0x100 * sens_num)); return d; }
void                         x393_sens_gamma_tbl                 (x393_gamma_tbl_t d, int sens_num){writel(d.d32, mmio_ptr + (0x10e4 + 0x100 * sens_num));} // Write sensor gamma table address/data (with autoincrement)
void                         set_x393_sens_gamma_height01m1      (x393_gamma_height01m1_t d, int sens_num){writel(d.d32, mmio_ptr + (0x10e8 + 0x100 * sens_num));} // Gamma module subframes 0,1 heights minus 1
x393_gamma_height01m1_t      get_x393_sens_gamma_height01m1      (int sens_num)      { x393_gamma_height01m1_t d; d.d32 = readl(mmio_ptr + (0x10e8 + 0x100 * sens_num)); return d; }
void                         set_x393_sens_gamma_height2m1       (x393_gamma_height2m1_t d, int sens_num){writel(d.d32, mmio_ptr + (0x10ec + 0x100 * sens_num));} // Gamma module subframe  2 height minus 1
x393_gamma_height2m1_t       get_x393_sens_gamma_height2m1       (int sens_num)      { x393_gamma_height2m1_t d; d.d32 = readl(mmio_ptr + (0x10ec + 0x100 * sens_num)); return d; }

// Windows for histogram subchannels

void                         set_x393_histogram_lt0              (x393_hist_left_top_t d, int sens_num){writel(d.d32, mmio_ptr + (0x10c0 + 0x100 * sens_num));} // Specify histogram 0 left/top
x393_hist_left_top_t         get_x393_histogram_lt0              (int sens_num)      { x393_hist_left_top_t d; d.d32 = readl(mmio_ptr + (0x10c0 + 0x100 * sens_num)); return d; }
void                         set_x393_histogram_wh0              (x393_hist_width_height_m1_t d, int sens_num){writel(d.d32, mmio_ptr + (0x10c4 + 0x100 * sens_num));} // Specify histogram 0 width/height
x393_hist_width_height_m1_t  get_x393_histogram_wh0              (int sens_num)      { x393_hist_width_height_m1_t d; d.d32 = readl(mmio_ptr + (0x10c4 + 0x100 * sens_num)); return d; }
void                         set_x393_histogram_lt1              (x393_hist_left_top_t d, int sens_num){writel(d.d32, mmio_ptr + (0x10c8 + 0x100 * sens_num));} // Specify histogram 1 left/top
x393_hist_left_top_t         get_x393_histogram_lt1              (int sens_num)      { x393_hist_left_top_t d; d.d32 = readl(mmio_ptr + (0x10c8 + 0x100 * sens_num)); return d; }
void                         set_x393_histogram_wh1              (x393_hist_width_height_m1_t d, int sens_num){writel(d.d32, mmio_ptr + (0x10cc + 0x100 * sens_num));} // Specify histogram 1 width/height
x393_hist_width_height_m1_t  get_x393_histogram_wh1              (int sens_num)      { x393_hist_width_height_m1_t d; d.d32 = readl(mmio_ptr + (0x10cc + 0x100 * sens_num)); return d; }
void                         set_x393_histogram_lt2              (x393_hist_left_top_t d, int sens_num){writel(d.d32, mmio_ptr + (0x10d0 + 0x100 * sens_num));} // Specify histogram 2 left/top
x393_hist_left_top_t         get_x393_histogram_lt2              (int sens_num)      { x393_hist_left_top_t d; d.d32 = readl(mmio_ptr + (0x10d0 + 0x100 * sens_num)); return d; }
void                         set_x393_histogram_wh2              (x393_hist_width_height_m1_t d, int sens_num){writel(d.d32, mmio_ptr + (0x10d4 + 0x100 * sens_num));} // Specify histogram 2 width/height
x393_hist_width_height_m1_t  get_x393_histogram_wh2              (int sens_num)      { x393_hist_width_height_m1_t d; d.d32 = readl(mmio_ptr + (0x10d4 + 0x100 * sens_num)); return d; }
void                         set_x393_histogram_lt3              (x393_hist_left_top_t d, int sens_num){writel(d.d32, mmio_ptr + (0x10d8 + 0x100 * sens_num));} // Specify histogram 3 left/top
x393_hist_left_top_t         get_x393_histogram_lt3              (int sens_num)      { x393_hist_left_top_t d; d.d32 = readl(mmio_ptr + (0x10d8 + 0x100 * sens_num)); return d; }
void                         set_x393_histogram_wh3              (x393_hist_width_height_m1_t d, int sens_num){writel(d.d32, mmio_ptr + (0x10dc + 0x100 * sens_num));} // Specify histogram 3 width/height
x393_hist_width_height_m1_t  get_x393_histogram_wh3              (int sens_num)      { x393_hist_width_height_m1_t d; d.d32 = readl(mmio_ptr + (0x10dc + 0x100 * sens_num)); return d; }

// DMA control for the histograms. Subchannel here is 4*sensor_port+ histogram_subchannel

void                         set_x393_hist_saxi_mode             (x393_hist_saxi_mode_t d){writel(d.d32, mmio_ptr + 0x1440);}      // Histogram DMA operation mode
x393_hist_saxi_mode_t        get_x393_hist_saxi_mode             (void)              { x393_hist_saxi_mode_t d; d.d32 = readl(mmio_ptr + 0x1440); return d; }
void                         set_x393_hist_saxi_addr             (x393_hist_saxi_addr_t d, int subchannel){writel(d.d32, mmio_ptr + (0x1400 + 0x4 * subchannel));} // Histogram DMA addresses (in 4096 byte pages)
x393_hist_saxi_addr_t        get_x393_hist_saxi_addr             (int subchannel)    { x393_hist_saxi_addr_t d; d.d32 = readl(mmio_ptr + (0x1400 + 0x4 * subchannel)); return d; }

// Read-only addresses for sensors status information

x393_status_sens_i2c_t       x393_sensi2c_status                 (int sens_num)      { x393_status_sens_i2c_t d; d.d32 = readl(mmio_ptr + (0x2080 + 0x8 * sens_num)); return d; } // Status of the sensors i2c
x393_status_sens_io_t        x393_sensio_status                  (int sens_num)      { x393_status_sens_io_t d; d.d32 = readl(mmio_ptr + (0x2084 + 0x8 * sens_num)); return d; } // Status of the sensor ports I/O pins

// Compressor bitfields values


// Compressor control

void                         x393_cmprs_control_reg              (x393_cmprs_mode_t d, int cmprs_chn){writel(d.d32, mmio_ptr + (0x1800 + 0x40 * cmprs_chn));} // Program compressor channel operation mode
void                         set_x393_cmprs_status               (x393_status_ctrl_t d, int cmprs_chn){writel(d.d32, mmio_ptr + (0x1804 + 0x40 * cmprs_chn));} // Setup compressor status report mode
x393_status_ctrl_t           get_x393_cmprs_status               (int cmprs_chn)     { x393_status_ctrl_t d; d.d32 = readl(mmio_ptr + (0x1804 + 0x40 * cmprs_chn)); return d; }
void                         set_x393_cmprs_format               (x393_cmprs_frame_format_t d, int cmprs_chn){writel(d.d32, mmio_ptr + (0x1808 + 0x40 * cmprs_chn));} // Compressor frame format
x393_cmprs_frame_format_t    get_x393_cmprs_format               (int cmprs_chn)     { x393_cmprs_frame_format_t d; d.d32 = readl(mmio_ptr + (0x1808 + 0x40 * cmprs_chn)); return d; }
void                         set_x393_cmprs_color_saturation     (x393_cmprs_colorsat_t d, int cmprs_chn){writel(d.d32, mmio_ptr + (0x180c + 0x40 * cmprs_chn));} // Compressor color saturation
x393_cmprs_colorsat_t        get_x393_cmprs_color_saturation     (int cmprs_chn)     { x393_cmprs_colorsat_t d; d.d32 = readl(mmio_ptr + (0x180c + 0x40 * cmprs_chn)); return d; }
void                         set_x393_cmprs_coring_mode          (x393_cmprs_coring_mode_t d, int cmprs_chn){writel(d.d32, mmio_ptr + (0x1810 + 0x40 * cmprs_chn));} // Select coring mode
x393_cmprs_coring_mode_t     get_x393_cmprs_coring_mode          (int cmprs_chn)     { x393_cmprs_coring_mode_t d; d.d32 = readl(mmio_ptr + (0x1810 + 0x40 * cmprs_chn)); return d; }
void                         x393_cmprs_interrupts               (x393_cmprs_interrupts_t d, int cmprs_chn){writel(d.d32, mmio_ptr + (0x1814 + 0x40 * cmprs_chn));} // Compressor interrupts control (1 - clear, 2 - disable, 3 - enable)
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


// Compressor tables control

void                         x393_cmprs_tables_data              (u32 d, int cmprs_chn){writel(d, mmio_ptr + (0x1818 + 0x40 * cmprs_chn));} // Compressor tables data
void                         x393_cmprs_tables_address           (x393_cmprs_table_addr_t d, int cmprs_chn){writel(d.d32, mmio_ptr + (0x181c + 0x40 * cmprs_chn));} // Compressor tables type/address

// Compressor channel status)

x393_cmprs_status_t          x393_cmprs_status                   (int chn)           { x393_cmprs_status_t d; d.d32 = readl(mmio_ptr + (0x2040 + 0x4 * chn)); return d; } // Status of the compressor channel (incl. interrupt
u32                          x393_cmprs_hifreq                   (int chn)           { u32 d; d = readl(mmio_ptr + (0x2050 + 0x4 * chn)); return d; } // Focus helper high-frequency amount

// Compressor DMA control:

// Camera can be configured to use either 2 AXI HP channels (with 2 compressors served by each one) or to use a single AXI HP channel
// serving all 4 compressor channels through its input ports. Below afi_port (0..3) references to one of the 4 ports of each. Control
// for two AXI HP channels is implemented as separate functions. Currently only the first channel is used
void                         x393_afimux0_en                     (x393_afimux_en_t d){writel(d.d32, mmio_ptr + 0x1900);}           // AFI MUX 0 global/port run/pause control
void                         set_x393_afimux0_rst                (x393_afimux_rst_t d){writel(d.d32, mmio_ptr + 0x1904);}          // AFI MUX 0 per-port resets
x393_afimux_rst_t            get_x393_afimux0_rst                (void)              { x393_afimux_rst_t d; d.d32 = readl(mmio_ptr + 0x1904); return d; }
void                         x393_afimux0_report_mode            (x393_afimux_report_t d){writel(d.d32, mmio_ptr + 0x1908);}       // AFI MUX 0 readout pointer report mode
void                         set_x393_afimux0_status_control     (x393_status_ctrl_t d){writel(d.d32, mmio_ptr + 0x1910);}         // AFI MUX 0 status report mode
x393_status_ctrl_t           get_x393_afimux0_status_control     (void)              { x393_status_ctrl_t d; d.d32 = readl(mmio_ptr + 0x1910); return d; }
void                         set_x393_afimux0_sa                 (x393_afimux_sa_t d, int afi_port){writel(d.d32, mmio_ptr + (0x1920 + 0x4 * afi_port));} // AFI MUX 0 DMA buffer start address in 32-byte blocks
x393_afimux_sa_t             get_x393_afimux0_sa                 (int afi_port)      { x393_afimux_sa_t d; d.d32 = readl(mmio_ptr + (0x1920 + 0x4 * afi_port)); return d; }
void                         set_x393_afimux0_len                (x393_afimux_len_t d, int afi_port){writel(d.d32, mmio_ptr + (0x1930 + 0x4 * afi_port));} // AFI MUX 0 DMA buffer length in 32-byte blocks
x393_afimux_len_t            get_x393_afimux0_len                (int afi_port)      { x393_afimux_len_t d; d.d32 = readl(mmio_ptr + (0x1930 + 0x4 * afi_port)); return d; }
// Same for the second AXI HP channel (not currently used)
void                         x393_afimux1_en                     (x393_afimux_en_t d){writel(d.d32, mmio_ptr + 0x1940);}           // AFI MUX 1 global/port run/pause control
void                         set_x393_afimux1_rst                (x393_afimux_rst_t d){writel(d.d32, mmio_ptr + 0x1944);}          // AFI MUX 1 per-port resets
x393_afimux_rst_t            get_x393_afimux1_rst                (void)              { x393_afimux_rst_t d; d.d32 = readl(mmio_ptr + 0x1944); return d; }
void                         x393_afimux1_report_mode            (x393_afimux_report_t d){writel(d.d32, mmio_ptr + 0x1948);}       // AFI MUX 1 readout pointer report mode
void                         set_x393_afimux1_status_control     (x393_status_ctrl_t d){writel(d.d32, mmio_ptr + 0x1950);}         // AFI MUX 1 status report mode
x393_status_ctrl_t           get_x393_afimux1_status_control     (void)              { x393_status_ctrl_t d; d.d32 = readl(mmio_ptr + 0x1950); return d; }
void                         set_x393_afimux1_sa                 (x393_afimux_sa_t d, int afi_port){writel(d.d32, mmio_ptr + (0x1960 + 0x4 * afi_port));} // AFI MUX 1 DMA buffer start address in 32-byte blocks
x393_afimux_sa_t             get_x393_afimux1_sa                 (int afi_port)      { x393_afimux_sa_t d; d.d32 = readl(mmio_ptr + (0x1960 + 0x4 * afi_port)); return d; }
void                         set_x393_afimux1_len                (x393_afimux_len_t d, int afi_port){writel(d.d32, mmio_ptr + (0x1970 + 0x4 * afi_port));} // AFI MUX 1 DMA buffer length in 32-byte blocks
x393_afimux_len_t            get_x393_afimux1_len                (int afi_port)      { x393_afimux_len_t d; d.d32 = readl(mmio_ptr + (0x1970 + 0x4 * afi_port)); return d; }

// Read-only sensors status information (pointer offset and last sequence number)

x393_afimux_status_t         x393_afimux0_status                 (int afi_port)      { x393_afimux_status_t d; d.d32 = readl(mmio_ptr + (0x2060 + 0x4 * afi_port)); return d; } // Status of the AFI MUX 0 (including image pointer)
x393_afimux_status_t         x393_afimux1_status                 (int afi_port)      { x393_afimux_status_t d; d.d32 = readl(mmio_ptr + (0x2070 + 0x4 * afi_port)); return d; } // Status of the AFI MUX 1 (including image pointer)
// 
// GPIO contol. Each of the 10 pins can be controlled by the software - individually or simultaneously or from any of the 3 masters (other FPGA modules)
// Currently these modules are;
//      A - camsync (intercamera synchronization), uses up to 4 pins 
//      B - reserved (not yet used) and 
//      C - logger (IMU, GPS, images), uses 6 pins, including separate i2c available on extension boards
// If several enabled ports try to contol the same bit, highest priority has port C, lowest - software controlled
void                         x393_gpio_set_pins                  (x393_gpio_set_pins_t d){writel(d.d32, mmio_ptr + 0x1c00);}       // State of the GPIO pins and seq. number
void                         set_x393_gpio_status_control        (x393_status_ctrl_t d){writel(d.d32, mmio_ptr + 0x1c04);}         // GPIO status control mode
x393_status_ctrl_t           get_x393_gpio_status_control        (void)              { x393_status_ctrl_t d; d.d32 = readl(mmio_ptr + 0x1c04); return d; }

// Read-only GPIO pins state

x393_gpio_status_t           x393_gpio_status                    (void)              { x393_gpio_status_t d; d.d32 = readl(mmio_ptr + 0x20c0); return d; } // State of the GPIO pins and seq. number

// RTC control

void                         set_x393_rtc_usec                   (x393_rtc_usec_t d) {writel(d.d32, mmio_ptr + 0x1c10);}           // RTC microseconds
x393_rtc_usec_t              get_x393_rtc_usec                   (void)              { x393_rtc_usec_t d; d.d32 = readl(mmio_ptr + 0x1c10); return d; }
void                         set_x393_rtc_sec_set                (x393_rtc_sec_t d)  {writel(d.d32, mmio_ptr + 0x1c14);}           // RTC seconds and set clock
x393_rtc_sec_t               get_x393_rtc_sec_set                (void)              { x393_rtc_sec_t d; d.d32 = readl(mmio_ptr + 0x1c14); return d; }
void                         set_x393_rtc_corr                   (x393_rtc_corr_t d) {writel(d.d32, mmio_ptr + 0x1c18);}           // RTC correction (+/- 1/256 full scale)
x393_rtc_corr_t              get_x393_rtc_corr                   (void)              { x393_rtc_corr_t d; d.d32 = readl(mmio_ptr + 0x1c18); return d; }
void                         set_x393_rtc_set_status             (x393_status_ctrl_t d){writel(d.d32, mmio_ptr + 0x1c1c);}         // RTC status control mode, write makes a snapshot to be read out
x393_status_ctrl_t           get_x393_rtc_set_status             (void)              { x393_status_ctrl_t d; d.d32 = readl(mmio_ptr + 0x1c1c); return d; }

// Read-only RTC state

x393_rtc_status_t            x393_rtc_status                     (void)              { x393_rtc_status_t d; d.d32 = readl(mmio_ptr + 0x20c4); return d; } // RTC status reg
x393_rtc_sec_t               x393_rtc_status_sec                 (void)              { x393_rtc_sec_t d; d.d32 = readl(mmio_ptr + 0x20c8); return d; } // RTC snapshot seconds
x393_rtc_usec_t              x393_rtc_status_usec                (void)              { x393_rtc_usec_t d; d.d32 = readl(mmio_ptr + 0x20cc); return d; } // RTC snapshot microseconds

// CAMSYNC control

void                         x393_camsync_mode                   (x393_camsync_mode_t d){writel(d.d32, mmio_ptr + 0x1c20);}        // CAMSYNC mode
void                         x393_camsync_trig_src               (x393_camsync_io_t d){writel(d.d32, mmio_ptr + 0x1c24);}          // CAMSYNC trigger source
void                         x393_camsync_trig_dst               (x393_camsync_io_t d){writel(d.d32, mmio_ptr + 0x1c28);}          // CAMSYNC trigger destination
// Trigger period has special value for small (<255) values written to this register
//     d == 0 - disable (stop periodic mode)
//     d == 1 - single trigger
//     d == 2..255 - set output pulse / input-output serial bit duration (no start generated)
//     d >= 256 - repetitive trigger
void                         set_x393_camsync_trig_period        (u32 d)             {writel(d, mmio_ptr + 0x1c2c);}               // CAMSYNC trigger period
u32                          get_x393_camsync_trig_period        (void)              { u32 d; d = readl(mmio_ptr + 0x1c2c); return d; }
void                         set_x393_camsync_trig_delay         (u32 d, int sens_chn){writel(d, mmio_ptr + (0x1c30 + 0x4 * sens_chn));} // CAMSYNC trigger delay
u32                          get_x393_camsync_trig_delay         (int sens_chn)      { u32 d; d = readl(mmio_ptr + (0x1c30 + 0x4 * sens_chn)); return d; }

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
void                         x393_cmdframeseq_ctrl               (x393_cmdframeseq_mode_t d, int sens_chn){writel(d.d32, mmio_ptr + (0x1e7c + 0x80 * sens_chn));} // CMDFRAMESEQ control register
void                         x393_cmdframeseq_abs                (u32 d, int sens_chn, int offset){writel(d, mmio_ptr + (0x1e00 + 0x20 * sens_chn + 0x1 * offset));} // CMDFRAMESEQ absolute frame address/command
void                         x393_cmdframeseq_rel                (u32 d, int sens_chn, int offset){writel(d, mmio_ptr + (0x1e40 + 0x20 * sens_chn + 0x1 * offset));} // CMDFRAMESEQ relative frame address/command
// Command sequencer multiplexer, provides current frame number for each sensor channel and interrupt status/interrupt masks for them.
// Interrupts and interrupt masks are controlled through channel CMDFRAMESEQ module
void                         set_x393_cmdseqmux_status_ctrl      (x393_status_ctrl_t d){writel(d.d32, mmio_ptr + 0x1c08);}         // CMDSEQMUX status control mode (status provides current frame numbers)
x393_status_ctrl_t           get_x393_cmdseqmux_status_ctrl      (void)              { x393_status_ctrl_t d; d.d32 = readl(mmio_ptr + 0x1c08); return d; }
x393_cmdseqmux_status_t      x393_cmdseqmux_status               (void)              { x393_cmdseqmux_status_t d; d.d32 = readl(mmio_ptr + 0x20e0); return d; } // CMDSEQMUX status data (frame numbers and interrupts

// Event logger

// Event logger configuration/data is writtent to the module ising two 32-bit register locations : data and address.
// Address consists of 2 parts - 2-bit page (configuration, imu, gps, message) and a 5-bit sub-address autoincremented when writing data.
// Register pages:
// Register configuration addresses (with X393_LOGGER_PAGE_CONF):
void                         set_x393_logger_status_ctrl         (x393_status_ctrl_t d){writel(d.d32, mmio_ptr + 0x1c88);}         // Logger status configuration (to report sample number)
x393_status_ctrl_t           get_x393_logger_status_ctrl         (void)              { x393_status_ctrl_t d; d.d32 = readl(mmio_ptr + 0x1c88); return d; }
void                         x393_logger_data                    (x393_logger_data_t d){writel(d.d32, mmio_ptr + 0x1c80);}         // Logger register write data
void                         x393_logger_address                 (x393_logger_address_t d){writel(d.d32, mmio_ptr + 0x1c84);}      // Logger register write page/address
x393_logger_status_t         x393_logger_status                  (void)              { x393_logger_status_t d; d.d32 = readl(mmio_ptr + 0x20e4); return d; } // Logger status data (sequence number)

// MULT SAXI DMA engine control. Of 4 channels only one (number 0) is currently used - for the event logger

void                         set_x393_mult_saxi_status_ctrl      (x393_status_ctrl_t d){writel(d.d32, mmio_ptr + 0x1ce0);}         // MULT_SAXI status control mode (status provides current DWORD pointer)
x393_status_ctrl_t           get_x393_mult_saxi_status_ctrl      (void)              { x393_status_ctrl_t d; d.d32 = readl(mmio_ptr + 0x1ce0); return d; }
void                         x393_mult_saxi_buf_address          (x393_mult_saxi_al_t d, int chn){writel(d.d32, mmio_ptr + (0x1cc0 + 0x8 * chn));} // MULT_SAXI buffer start address in DWORDS
void                         x393_mult_saxi_buf_len              (x393_mult_saxi_al_t d, int chn){writel(d.d32, mmio_ptr + (0x1cc4 + 0x8 * chn));} // MULT_SAXI buffer length in DWORDS
x393_mult_saxi_al_t          x393_mult_saxi_status               (int chn)           { x393_mult_saxi_al_t d; d.d32 = readl(mmio_ptr + (0x20d0 + 0x4 * chn)); return d; } // MULT_SAXI current DWORD pointer

// MULTI_CLK - global clock generation PLLs. Interface provided for debugging, no interaction is needed for normal operation

void                         set_x393_multiclk_status_ctrl       (x393_status_ctrl_t d){writel(d.d32, mmio_ptr + 0x1ca4);}         // MULTI_CLK status generation (do not use or do not set auto)
x393_status_ctrl_t           get_x393_multiclk_status_ctrl       (void)              { x393_status_ctrl_t d; d.d32 = readl(mmio_ptr + 0x1ca4); return d; }
void                         set_x393_multiclk_ctrl              (x393_multiclk_ctl_t d){writel(d.d32, mmio_ptr + 0x1ca0);}        // MULTI_CLK reset and power down control
x393_multiclk_ctl_t          get_x393_multiclk_ctrl              (void)              { x393_multiclk_ctl_t d; d.d32 = readl(mmio_ptr + 0x1ca0); return d; }
x393_multiclk_status_t       x393_multiclk_status                (void)              { x393_multiclk_status_t d; d.d32 = readl(mmio_ptr + 0x20e8); return d; } // MULTI_CLK lock and toggle state

// Debug ring module

// Debug ring module (when enabled with DEBUG_RING in system_defines.vh) provides low-overhead read/write access to internal test points
// To write data you need to write 32-bit data with x393_debug_shift(u32) multiple times to fill the ring register (length depends on
// implementation), skip this step if only reading from the modules under test is required.
// Exchange data with x393_debug_load(), the data from the ring shift register.
// Write 0xffffffff (or other "magic" data) if the ring length is unknown - this DWORD will appear on the output after the useful data
// Read all data, waiting for status sequence number to be incremented,status mode should be set to auto (3) wor each DWORD certain
// number of times or until the "magic" DWORD appears, writing "magic" to shift out next 32 bits.
void                         set_x393_debug_status_ctrl          (x393_status_ctrl_t d){writel(d.d32, mmio_ptr + 0x1c48);}         // Debug ring status generation - set to auto(3) if used
x393_status_ctrl_t           get_x393_debug_status_ctrl          (void)              { x393_status_ctrl_t d; d.d32 = readl(mmio_ptr + 0x1c48); return d; }
void                         x393_debug_load                     (void)              {writel(0, mmio_ptr + 0x1c44);}               // Debug ring copy shift register to/from tested modules
void                         x393_debug_shift                    (u32 d)             {writel(d, mmio_ptr + 0x1c40);}               // Debug ring shift ring by 32 bits
x393_debug_status_t          x393_debug_status                   (void)              { x393_debug_status_t d; d.d32 = readl(mmio_ptr + 0x23f0); return d; } // Debug read status (watch sequence number)
u32                          x393_debug_read                     (void)              { u32 d; d = readl(mmio_ptr + 0x23f4); return d; } // Debug read DWORD form ring register

// Write-only addresses to program memory channel 3 (test channel)

void                         x393_mcntrl_chn3_scanline_mode      (x393_mcntrl_mode_scan_t d){writel(d.d32, mmio_ptr + 0x04c0);}    // Set mode register (write last after other channel registers are set)
void                         set_x393_mcntrl_chn3_scanline_status_cntrl(x393_status_ctrl_t d){writel(d.d32, mmio_ptr + 0x04c4);}   // Set status control register (status update mode)
x393_status_ctrl_t           get_x393_mcntrl_chn3_scanline_status_cntrl(void)        { x393_status_ctrl_t d; d.d32 = readl(mmio_ptr + 0x04c4); return d; }
void                         x393_mcntrl_chn3_scanline_startaddr (x393_mcntrl_window_frame_sa_t d){writel(d.d32, mmio_ptr + 0x04c8);} // Set frame start address
void                         x393_mcntrl_chn3_scanline_frame_size(x393_mcntrl_window_frame_sa_inc_t d){writel(d.d32, mmio_ptr + 0x04cc);} // Set frame size (address increment)
void                         x393_mcntrl_chn3_scanline_frame_last(x393_mcntrl_window_last_frame_num_t d){writel(d.d32, mmio_ptr + 0x04d0);} // Set last frame number (number of frames in buffer minus 1)
void                         x393_mcntrl_chn3_scanline_frame_full_width(x393_mcntrl_window_full_width_t d){writel(d.d32, mmio_ptr + 0x04d4);} // Set frame full(padded) width
void                         x393_mcntrl_chn3_scanline_window_wh (x393_mcntrl_window_width_height_t d){writel(d.d32, mmio_ptr + 0x04d8);} // Set frame window size
void                         x393_mcntrl_chn3_scanline_window_x0y0(x393_mcntrl_window_left_top_t d){writel(d.d32, mmio_ptr + 0x04dc);} // Set frame position
void                         x393_mcntrl_chn3_scanline_startxy   (x393_mcntrl_window_startx_starty_t d){writel(d.d32, mmio_ptr + 0x04e0);} // Set startXY register

// Write-only addresses to program memory channel 2 (test channel)

void                         x393_mcntrl_chn2_tiled_mode         (x393_mcntrl_mode_scan_t d){writel(d.d32, mmio_ptr + 0x0500);}    // Set mode register (write last after other channel registers are set)
void                         set_x393_mcntrl_chn2_tiled_status_cntrl(x393_status_ctrl_t d){writel(d.d32, mmio_ptr + 0x0504);}      // Set status control register (status update mode)
x393_status_ctrl_t           get_x393_mcntrl_chn2_tiled_status_cntrl(void)           { x393_status_ctrl_t d; d.d32 = readl(mmio_ptr + 0x0504); return d; }
void                         x393_mcntrl_chn2_tiled_startaddr    (x393_mcntrl_window_frame_sa_t d){writel(d.d32, mmio_ptr + 0x0508);} // Set frame start address
void                         x393_mcntrl_chn2_tiled_frame_size   (x393_mcntrl_window_frame_sa_inc_t d){writel(d.d32, mmio_ptr + 0x050c);} // Set frame size (address increment)
void                         x393_mcntrl_chn2_tiled_frame_last   (x393_mcntrl_window_last_frame_num_t d){writel(d.d32, mmio_ptr + 0x0510);} // Set last frame number (number of frames in buffer minus 1)
void                         x393_mcntrl_chn2_tiled_frame_full_width(x393_mcntrl_window_full_width_t d){writel(d.d32, mmio_ptr + 0x0514);} // Set frame full(padded) width
void                         x393_mcntrl_chn2_tiled_window_wh    (x393_mcntrl_window_width_height_t d){writel(d.d32, mmio_ptr + 0x0518);} // Set frame window size
void                         x393_mcntrl_chn2_tiled_window_x0y0  (x393_mcntrl_window_left_top_t d){writel(d.d32, mmio_ptr + 0x051c);} // Set frame position
void                         x393_mcntrl_chn2_tiled_startxy      (x393_mcntrl_window_startx_starty_t d){writel(d.d32, mmio_ptr + 0x0520);} // Set startXY register
void                         x393_mcntrl_chn2_tiled_tile_whs     (x393_mcntrl_window_tile_whs_t d){writel(d.d32, mmio_ptr + 0x0524);} // Set tile size/step (tiled mode only)

// Write-only addresses to program memory channel 4 (test channel)

void                         x393_mcntrl_chn4_tiled_mode         (x393_mcntrl_mode_scan_t d){writel(d.d32, mmio_ptr + 0x0540);}    // Set mode register (write last after other channel registers are set)
void                         set_x393_mcntrl_chn4_tiled_status_cntrl(x393_status_ctrl_t d){writel(d.d32, mmio_ptr + 0x0544);}      // Set status control register (status update mode)
x393_status_ctrl_t           get_x393_mcntrl_chn4_tiled_status_cntrl(void)           { x393_status_ctrl_t d; d.d32 = readl(mmio_ptr + 0x0544); return d; }
void                         x393_mcntrl_chn4_tiled_startaddr    (x393_mcntrl_window_frame_sa_t d){writel(d.d32, mmio_ptr + 0x0548);} // Set frame start address
void                         x393_mcntrl_chn4_tiled_frame_size   (x393_mcntrl_window_frame_sa_inc_t d){writel(d.d32, mmio_ptr + 0x054c);} // Set frame size (address increment)
void                         x393_mcntrl_chn4_tiled_frame_last   (x393_mcntrl_window_last_frame_num_t d){writel(d.d32, mmio_ptr + 0x0550);} // Set last frame number (number of frames in buffer minus 1)
void                         x393_mcntrl_chn4_tiled_frame_full_width(x393_mcntrl_window_full_width_t d){writel(d.d32, mmio_ptr + 0x0554);} // Set frame full(padded) width
void                         x393_mcntrl_chn4_tiled_window_wh    (x393_mcntrl_window_width_height_t d){writel(d.d32, mmio_ptr + 0x0558);} // Set frame window size
void                         x393_mcntrl_chn4_tiled_window_x0y0  (x393_mcntrl_window_left_top_t d){writel(d.d32, mmio_ptr + 0x055c);} // Set frame position
void                         x393_mcntrl_chn4_tiled_startxy      (x393_mcntrl_window_startx_starty_t d){writel(d.d32, mmio_ptr + 0x0560);} // Set startXY register
void                         x393_mcntrl_chn4_tiled_tile_whs     (x393_mcntrl_window_tile_whs_t d){writel(d.d32, mmio_ptr + 0x0564);} // Set tile size/step (tiled mode only)

