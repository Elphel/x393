/*******************************************************************************
 * Module: cmprs_frame_sync
 * Date:2015-06-23  
 * Author: Andrey Filippov     
 * Description: Synchronizes memory channels (sensor and compressor)
 *
 * Copyright (c) 2015 Elphel, Inc.
 * cmprs_frame_sync.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  cmprs_frame_sync.v is distributed in the hope that it will be useful,
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
 * charge, and there is no dependence on any ecrypted modules for simulating of
 * the combined code. This permission applies to you if the distributed code
 * contains all the components and scripts required to completely simulate it
 * with at least one of the Free Software programs.
 *******************************************************************************/
`timescale 1ns/1ps

module  cmprs_frame_sync#(
    parameter FRAME_HEIGHT_BITS=               16,    // Maximal frame height 
    parameter LAST_FRAME_BITS=                 16,     // number of bits in frame counter (before rolls over)
    parameter CMPRS_TIMEOUT_BITS=              12,
    parameter CMPRS_TIMEOUT=                   1000   // mclk cycles

)(
//    input                         rst,
    input                         xclk,               // global clock input, compressor single clock rate
    input                         mclk,               // global system/memory clock
    input                         mrst,               // @posedge mclk, sync reset
    input                         xrst,               // @posedge xclk, sync reset
    
    input                         cmprs_en,           // @mclk 0 resets immediately
    output                        cmprs_en_extend,    // @mclk keep compressor enabled for graceful shutdown

// TODO: delay vsync_late if still compressing previous frame in multi-frame buffer mode
     
    input                         cmprs_run,          // @mclk enable propagation of vsync_late to frame_start_dst in bonded(sync to src) mode
    input                         cmprs_standalone,   // @mclk single-cycle: generate a single frame_start_dst in unbonded (not synchronized) mode.
                                                      // cmprs_run should be off
    input                         sigle_frame_buf,    // memory controller uses a single frame buffer (frame_number_* == 0), use other sync                                                      
    input                         vsync_late,         // @mclk delayed start of frame, @xclk. In 353 it was 16 lines after VACT active
                                                      // source channel should already start, some delay give time for sequencer commands
                                                      // that should arrive before it
    input                         frame_started,      // @xclk started first macroblock (checking for broken frames)
                                                      
    output                        frame_start_dst,    // @mclk - trigger receive (tiled) memory channel (it will take care of single/repetitive
                                                      // this output either follows vsync_late (reclocks it) or generated in non-bonded mode
                                                      // (compress from memory)
    input [FRAME_HEIGHT_BITS-1:0] line_unfinished_src,// number of the current (unfinished ) line, in the source (sensor) channel (RELATIVE TO FRAME, NOT WINDOW?)
    input   [LAST_FRAME_BITS-1:0] frame_number_src,   // current frame number (for multi-frame ranges) in the source (sensor) channel
    input                         frame_done_src,     // single-cycle pulse when the full frame (window) was transferred to/from DDR3 memory 
                                                      // frame_done_src is later than line_unfinished_src/ frame_number_src changes
                                                      // Used withe a single-frame buffers
     
    input [FRAME_HEIGHT_BITS-1:0] line_unfinished,    // number of the current (unfinished ) line in this (compressor) channel
    input   [LAST_FRAME_BITS-1:0] frame_number,       // current frame number (for multi-frame ranges) in this (compressor channel
    input                         frame_done,         // input - single-cycle pulse when the full frame (window) was transferred to/from DDR3 memory 
    output reg                    suspend,            // suspend reading data for this channel - waiting for the source data

    input                         stuffer_running,    // @xclk2x stuffer is running/flushing
    output reg                    force_flush_long,    // force flush (abort frame), can be any clock and may last until stuffer_done_mclk
                                                      // stuffer will re-clock and extract 0->1 transition
    output                        stuffer_running_mclk,
    output                        reading_frame
);
/*
 Abort frame (force flush) if:
 a) "broken frame" - attempted to start a new frame before previous one was completely read from the memory
 b) turned off enable while frame was being compressed
 Abort frame lasts until flush end or timeout expire
*/
//    wire   vsync_late_mclk; // single mclk cycle, reclocked from vsync_late
    wire   frame_started_mclk; 
    reg    bonded_mode;
    reg    frame_start_dst_r;
    reg    frames_differ;  // src and dest point to different frames (single-frame buffer mode), disregard line_unfinished_*
    reg    frames_numbers_differ;  // src and dest point to different frames (multi-frame buffer mode), disregard line_unfinished_*
    reg    line_numbers_sync;      // src unfinished line number is > this unfinished line number
    
    reg    reading_frame_r;         // compressor is reading frame data (make sure input is done before starting next frame, otherwise make it a broken frame
    reg    broken_frame;
    reg    aborted_frame;
    reg    stuffer_running_mclk_r;
    reg [CMPRS_TIMEOUT_BITS-1:0] timeout;
    reg    cmprs_en_extend_r=0;
    reg    cmprs_en_d;
//    reg    cmprs_en_xclk;
    assign frame_start_dst = frame_start_dst_r;
    assign cmprs_en_extend = cmprs_en_extend_r;
    
    assign stuffer_running_mclk = stuffer_running_mclk_r;
    assign reading_frame =        reading_frame_r;
    
//    always @ (posedge xclk) begin
//        cmprs_en_xclk <=cmprs_en;
//    end
    always @ (posedge mclk) begin
        if       (mrst)                                       cmprs_en_extend_r <= 0;
        else if  (cmprs_en)                                   cmprs_en_extend_r <= 1;
        else if  ((timeout == 0) || !stuffer_running_mclk_r)  cmprs_en_extend_r <= 0;
    end
    
    always @ (posedge mclk) begin
        stuffer_running_mclk_r <= stuffer_running; // re-clock from negedge xclk2x
        
        if      (cmprs_en)           timeout <= CMPRS_TIMEOUT;
        else if (!cmprs_en_extend_r) timeout <= 0;
        else                         timeout <= timeout - 1;
        
        cmprs_en_d <= cmprs_en;

        broken_frame <=  cmprs_en && cmprs_run && vsync_late && reading_frame_r; // single xclk pulse
        aborted_frame <= cmprs_en_d && !cmprs_en && stuffer_running_mclk_r;
        
        if      (!stuffer_running_mclk_r ||!cmprs_en_extend_r) force_flush_long <= 0;
        else if (broken_frame || aborted_frame)                force_flush_long <= 1;

    
        if (!cmprs_en || frame_done || (cmprs_run && vsync_late)) reading_frame_r <= 0;
        else if (frame_started_mclk)                              reading_frame_r <= 1;

        frame_start_dst_r <= cmprs_en && (cmprs_run ? (vsync_late && !reading_frame_r) : cmprs_standalone);
        if      (!cmprs_en)        bonded_mode <= 0;
        else if (cmprs_run)        bonded_mode <= 1;
        else if (cmprs_standalone) bonded_mode <= 0;
        
        if (!cmprs_en || !cmprs_run || vsync_late) frames_differ <= 0;
        else if (frame_done_src)                   frames_differ <= 1'b1;
        
        frames_numbers_differ <= frame_number_src != frame_number;
        
        line_numbers_sync <= (line_unfinished_src > line_unfinished);
        
//        suspend <= !bonded_mode && ((sigle_frame_buf ? frames_differ : frames_numbers_differ) || line_numbers_sync);
//        suspend <= bonded_mode && ((sigle_frame_buf ? frames_differ : frames_numbers_differ) || !line_numbers_sync);
        suspend <= bonded_mode && !((sigle_frame_buf ? frames_differ : frames_numbers_differ) || line_numbers_sync);
        
    
    end
    
//    pulse_cross_clock vsync_late_mclk_i (.rst(xrst), .src_clk(xclk), .dst_clk(mclk), .in_pulse(cmprs_en_xclk && vsync_late), .out_pulse(vsync_late_mclk),.busy());
    pulse_cross_clock frame_started_i   (.rst(xrst), .src_clk(xclk), .dst_clk(mclk), .in_pulse(frame_started), .out_pulse(frame_started_mclk),.busy());

endmodule

