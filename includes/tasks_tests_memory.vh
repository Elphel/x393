/*******************************************************************************
 * Module: tasks_tests_memory
 * Date:2015-08-01  
 * Author: andrey     
 * Description: Top-level tasks for testing memory subsystem functionality
 *
 * Copyright (c) 2015 Elphel, Inc .
 * tasks_tests_memory.vh is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  tasks_tests_memory.vh is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/

task test_write_levelling; // SuppressThisWarning VEditor - may be unused
  begin
// Set special values for DQS idelay for write leveling
        wait_ps_pio_done(DEFAULT_STATUS_MODE,1); // not no interrupt running cycle - delays are changed immediately
        axi_set_dqs_idelay_wlv;
// Set write buffer (from DDR3) WE signal delay for write leveling mode
        axi_set_wbuf_delay(WBUF_DLY_WLV);
        axi_set_dqs_odelay('h80); // 'h80 - inverted, 'h60 - not - 'h80 will cause warnings during simulation
        schedule_ps_pio ( // schedule software-control memory operation (may need to check FIFO status first)
                        WRITELEV_OFFSET,   // input [9:0] seq_addr; // sequence start address
                        0,                 // input [1:0] page;     // buffer page number
                        0,                 // input       urgent;   // high priority request (only for competion with other channels, wiil not pass in this FIFO)
                        0,                // input       chn;      // channel buffer to use: 0 - memory read, 1 - memory write
                        `PS_PIO_WAIT_COMPLETE );//  wait_complete; // Do not request a newe transaction from the scheduler until previous memory transaction is finished
                        
        wait_ps_pio_done(DEFAULT_STATUS_MODE,1); // wait previous memory transaction finished before changing delays (effective immediately)
        read_block_buf_chn (0, 0, 32, 1 ); // chn=0, page=0, number of 32-bit words=32, wait_done
//        @ (negedge rstb);
        axi_set_dqs_odelay(DLY_DQS_ODELAY);
        schedule_ps_pio ( // schedule software-control memory operation (may need to check FIFO status first)
                        WRITELEV_OFFSET,   // input [9:0] seq_addr; // sequence start address
                        1,                 // input [1:0] page;     // buffer page number
                        0,                 // input       urgent;   // high priority request (only for competion with other channels, wiil not pass in this FIFO)
                        0,                // input       chn;      // channel buffer to use: 0 - memory read, 1 - memory write
                        `PS_PIO_WAIT_COMPLETE );//  wait_complete; // Do not request a newe transaction from the scheduler until previous memory transaction is finished
        wait_ps_pio_done(DEFAULT_STATUS_MODE,1); // wait previous memory transaction finished before changing delays (effective immediately)
        read_block_buf_chn (0, 1, 32, 1 ); // chn=0, page=1, number of 32-bit words=32, wait_done
//    task wait_read_queue_empty; - alternative way to check fo empty read queue
        
//        @ (negedge rstb);
        axi_set_dqs_idelay_nominal;
        axi_set_dqs_odelay_nominal;
//        axi_set_dqs_odelay('h78);
        axi_set_wbuf_delay(WBUF_DLY_DFLT); //DFLT_WBUF_DELAY
   end
endtask

task test_read_pattern; // SuppressThisWarning VEditor - may be unused
    begin  
        schedule_ps_pio ( // schedule software-control memory operation (may need to check FIFO status first)
                        READ_PATTERN_OFFSET,   // input [9:0] seq_addr; // sequence start address
                        2,                     // input [1:0] page;     // buffer page number
                        0,                     // input       urgent;   // high priority request (only for competion with other channels, wiil not pass in this FIFO)
                        0,                    // input       chn;      // channel buffer to use: 0 - memory read, 1 - memory write
                        `PS_PIO_WAIT_COMPLETE );//  wait_complete; // Do not request a newe transaction from the scheduler until previous memory transaction is finished
        wait_ps_pio_done(DEFAULT_STATUS_MODE,1); // wait previous memory transaction finished before changing delays (effective immediately)
        read_block_buf_chn (0, 2, 32, 1 ); // chn=0, page=2, number of 32-bit words=32, wait_done
    end
endtask

task test_write_block; // SuppressThisWarning VEditor - may be unused
    begin
//    write_block_buf_chn; // fill block memory - already set in set_up task
        schedule_ps_pio ( // schedule software-control memory operation (may need to check FIFO status first)
                        WRITE_BLOCK_OFFSET,    // input [9:0] seq_addr; // sequence start address
                        0,                     // input [1:0] page;     // buffer page number
                        0,                     // input       urgent;   // high priority request (only for competion with other channels, wiil not pass in this FIFO)
                        1,                    // input       chn;      // channel buffer to use: 0 - memory read, 1 - memory write
                        `PS_PIO_WAIT_COMPLETE );//  wait_complete; // Do not request a newe transaction from the scheduler until previous memory transaction is finished
// tempoary - for debugging:
//        wait_ps_pio_done(DEFAULT_STATUS_MODE,1); // wait previous memory transaction finished before changing delays (effective immediately)
    end
endtask

task test_read_block; // SuppressThisWarning VEditor - may be unused
    begin
        schedule_ps_pio ( // schedule software-control memory operation (may need to check FIFO status first)
                        READ_BLOCK_OFFSET,   // input [9:0] seq_addr; // sequence start address
                        3,                     // input [1:0] page;     // buffer page number
                        0,                     // input       urgent;   // high priority request (only for competion with other channels, wiil not pass in this FIFO)
                        0,                    // input       chn;      // channel buffer to use: 0 - memory read, 1 - memory write
                        `PS_PIO_WAIT_COMPLETE );//  wait_complete; // Do not request a newe transaction from the scheduler until previous memory transaction is finished
        schedule_ps_pio ( // schedule software-control memory operation (may need to check FIFO status first)
                        READ_BLOCK_OFFSET,   // input [9:0] seq_addr; // sequence start address
                        2,                     // input [1:0] page;     // buffer page number
                        0,                     // input       urgent;   // high priority request (only for competion with other channels, wiil not pass in this FIFO)
                        0,                    // input       chn;      // channel buffer to use: 0 - memory read, 1 - memory write
                        `PS_PIO_WAIT_COMPLETE );//  wait_complete; // Do not request a newe transaction from the scheduler until previous memory transaction is finished
        schedule_ps_pio ( // schedule software-control memory operation (may need to check FIFO status first)
                        READ_BLOCK_OFFSET,   // input [9:0] seq_addr; // sequence start address
                        1,                     // input [1:0] page;     // buffer page number
                        0,                     // input       urgent;   // high priority request (only for competion with other channels, wiil not pass in this FIFO)
                        0,                    // input       chn;      // channel buffer to use: 0 - memory read, 1 - memory write
                        `PS_PIO_WAIT_COMPLETE );//  wait_complete; // Do not request a newe transaction from the scheduler until previous memory transaction is finished
        wait_ps_pio_done(DEFAULT_STATUS_MODE,1); // wait previous memory transaction finished before changing delays (effective immediately)
        read_block_buf_chn (0, 3, 256, 1 ); // chn=0, page=3, number of 32-bit words=256, wait_done
    end
endtask


// above - move to include

task test_afi_rw; // SuppressThisWarning VEditor - may be unused
    input        write_ddr3;
    input  [1:0] extra_pages;
    input [21:0] frame_start_addr;
    input [15:0] window_full_width; // 13 bit - in 8*16=128 bit bursts
    input [15:0] window_width;  // 13 bit - in 8*16=128 bit bursts
    input [15:0] window_height; // 16 bit (only 14 are used here)
    input [15:0] window_left;
    input [15:0] window_top;
    input [28:0] start64;  // relative start address of the transfer (set to 0 when writing lo_addr64)
    input [28:0] lo_addr64; // low address of the system memory range, in 64-bit words 
    input [28:0] size64;    // size of the system memory range in 64-bit words
    input        continue;    // 0 start from start64, 1 - continue from where it was
    
// -----------------------------------------
    integer mode;
`ifdef MEMBRIDGE_DEBUG_READ    
    integer       ii;
`endif    
    reg           repetitive;
    reg           single;
    reg           reset_frame;
    reg           disable_need; 
    begin
        disable_need = 1'b0;
        repetitive =  1'b1;
        single     =  1'b0;
        reset_frame = 1'b0;
        $display("====== test_afi_rw: write=%d, extra_pages=%d,  frame_start= %x, window_full_width=%d, window_width=%d, window_height=%d, window_left=%d, window_top=%d,@%t",
                                      write_ddr3,  extra_pages, frame_start_addr, window_full_width,   window_width, window_height, window_left, window_top, $time);
        $display("len64=%x,  width64=%x, start64=%x, lo_addr64=%x, size64=%x,@%t",
                  ((window_width[12:0]==0)? 15'h4000 : {1'b0,window_width[12:0],1'b0})*window_height[13:0],
                  (window_width[12:0]==0)? 29'h4000 : {15'b0,window_width[12:0],1'b0},
                  start64, lo_addr64, size64, $time);
        mode=   func_encode_mode_scanline(
                    disable_need,
                    repetitive,
                    single,
                    reset_frame,
                    extra_pages,
                    write_ddr3, // write_mem,
                    1, // enable
                    0);  // chn_reset
        write_contol_register(MCNTRL_SCANLINE_CHN1_ADDR + MCNTRL_SCANLINE_STARTADDR,        {10'b0,frame_start_addr}); // RA=80, CA=0, BA=0 22-bit frame start address (3 CA LSBs==0. BA==0) 
        write_contol_register(MCNTRL_SCANLINE_CHN1_ADDR + MCNTRL_SCANLINE_FRAME_FULL_WIDTH, {16'h0, window_full_width});
        write_contol_register(MCNTRL_SCANLINE_CHN1_ADDR + MCNTRL_SCANLINE_WINDOW_WH,        {window_height,window_width}); //WINDOW_WIDTH + (WINDOW_HEIGHT<<16));
        write_contol_register(MCNTRL_SCANLINE_CHN1_ADDR + MCNTRL_SCANLINE_WINDOW_X0Y0,      {window_top,window_left}); //WINDOW_X0+ (WINDOW_Y0<<16));
        write_contol_register(MCNTRL_SCANLINE_CHN1_ADDR + MCNTRL_SCANLINE_WINDOW_STARTXY,   0);
        write_contol_register(MCNTRL_SCANLINE_CHN1_ADDR + MCNTRL_SCANLINE_MODE,             mode); 
        configure_channel_priority(1,0);    // lowest priority channel 3
        enable_memcntrl_en_dis(1,1);
//        write_contol_register(test_mode_address,            TEST01_START_FRAME);
        afi_setup(0);
        membridge_setup(
            ((window_width[12:0]==0)? 15'h4000 : {1'b0,window_width[12:0],1'b0})*window_height[13:0], //len64,
            (window_width[12:0]==0)? 29'h4000 : {15'b0,window_width[12:0],1'b0}, // width64,
            start64,
            lo_addr64,
            size64);
        membridge_start (continue);
`ifdef MEMBRIDGE_DEBUG_READ    
        // debugging
        for (ii=0; ii < 10; ii=ii +1) begin
            #200; //#50;
            write_contol_register(MEMBRIDGE_ADDR + MEMBRIDGE_CTRL,         {27'b0,continue,4'b1101});  // enable both address and data
        end
        #500;
        write_contol_register(MEMBRIDGE_ADDR + MEMBRIDGE_CTRL,         {26'b0,continue,5'b10001});  // disable debug (enable remaining xfers)
`endif        
// just wait done
        wait_status_condition ( // may also be read directly from the same bit of mctrl_linear_rw (address=5) status
            MEMBRIDGE_STATUS_REG, // MCNTRL_TEST01_STATUS_REG_CHN3_ADDR,
            MEMBRIDGE_ADDR + MEMBRIDGE_STATUS_CNTRL, // MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN3_STATUS_CNTRL,
            DEFAULT_STATUS_MODE,
            2 << STATUS_2LSB_SHFT, // bit 24 - busy, bit 25 - frame done
            2 << STATUS_2LSB_SHFT,  // mask for the 4-bit page number
            0, // equal to
            1); // do synchronize sequence number
    end
endtask

task test_scanline_write; // SuppressThisWarning VEditor - may be unused
    input            [3:0] channel;
    input            [1:0] extra_pages;
    input                  wait_done;
    input [15:0]           window_width;  // 13 bit - in 8*16=128 bit bursts
    input [15:0]           window_height; // 16 bit
    input [15:0]           window_left;
    input [15:0]           window_top;
    
    
    reg             [29:0] start_addr;
    integer                mode;
    reg [STATUS_DEPTH-1:0] status_address;
    reg             [29:0] status_control_address;
    reg             [29:0] test_mode_address;
    
    integer       ii;
    integer xfer_size;
    integer pages_per_row;
    integer startx,starty; // temporary - because of the vdt bug with integer ports
    reg           repetitive;
    reg           single;
    reg           reset_frame;
    reg           disable_need; 
    begin
        disable_need = 1'b0;
        repetitive =  1'b1;
        single     =  1'b0;
        reset_frame = 1'b0;
        pages_per_row= (window_width>>NUM_XFER_BITS)+((window_width[NUM_XFER_BITS-1:0]==0)?0:1);
        $display("====== test_scanline_write: channel=%d, extra_pages=%d,  wait_done=%d @%t",
                                              channel,    extra_pages,     wait_done,   $time);
        case (channel)
//            1:  begin
//                    start_addr=             MCNTRL_SCANLINE_CHN1_ADDR;
//                    status_address=         MCNTRL_TEST01_STATUS_REG_CHN1_ADDR;
//                    status_control_address= MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN1_STATUS_CNTRL;
//                    test_mode_address=      MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN1_MODE;
//                end
            3:  begin
                    start_addr=             MCNTRL_SCANLINE_CHN3_ADDR;
                    status_address=         MCNTRL_TEST01_STATUS_REG_CHN3_ADDR;
                    status_control_address= MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN3_STATUS_CNTRL;
                    test_mode_address=      MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN3_MODE;
                end
            default: begin
                $display("**** ERROR: Invalid channel, only 3 is valid");
                start_addr=             MCNTRL_SCANLINE_CHN3_ADDR;
                status_address=         MCNTRL_TEST01_STATUS_REG_CHN1_ADDR;
                status_control_address= MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN1_STATUS_CNTRL;
                test_mode_address=      MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN1_MODE;
            end
        endcase
        mode=   func_encode_mode_scanline(
                    disable_need,
                    repetitive,
                    single,
                    reset_frame,
                    extra_pages,
                    1, // write_mem,
                    1, // enable
                    0);  // chn_reset
                
        write_contol_register(start_addr + MCNTRL_SCANLINE_STARTADDR,        FRAME_START_ADDRESS); // RA=80, CA=0, BA=0 22-bit frame start address (3 CA LSBs==0. BA==0) 
        write_contol_register(start_addr + MCNTRL_SCANLINE_FRAME_FULL_WIDTH, FRAME_FULL_WIDTH);
        write_contol_register(start_addr + MCNTRL_SCANLINE_WINDOW_WH,        {window_height,window_width}); //WINDOW_WIDTH + (WINDOW_HEIGHT<<16));
        write_contol_register(start_addr + MCNTRL_SCANLINE_WINDOW_X0Y0,      {window_top,window_left}); //WINDOW_X0+ (WINDOW_Y0<<16));
        write_contol_register(start_addr + MCNTRL_SCANLINE_WINDOW_STARTXY,   SCANLINE_STARTX+(SCANLINE_STARTY<<16));
        write_contol_register(start_addr + MCNTRL_SCANLINE_MODE,             mode); 
        configure_channel_priority(channel,0);    // lowest priority channel 3
//        enable_memcntrl_channels(16'h000b); // channels 0,1,3 are enabled
        enable_memcntrl_en_dis(channel,1);
        write_contol_register(test_mode_address,            TEST01_START_FRAME);
        for (ii=0;ii<TEST_INITIAL_BURST;ii=ii+1) begin
// VDT bugs: 1:does not propagate undefined width through ?:, 2: - does not allow to connect it to task integer input, 3: shows integer input width as 1  
            xfer_size= ((pages_per_row>1)?
                (
                    (
                        ((ii % pages_per_row) < (pages_per_row-1))?
                        (1<<NUM_XFER_BITS):
                        (window_width % (1<<NUM_XFER_BITS))
                    )
                ):
                ({16'b0,window_width}));
           $display("########### test_scanline_write block %d: channel=%d, @%t", ii, channel, $time);
           startx=window_left + ((ii % pages_per_row)<<NUM_XFER_BITS);
           starty=window_top + (ii / pages_per_row);
           write_block_scanline_chn(
            channel,
            (ii & 3),
            xfer_size,
            startx, //window_left + ((ii % pages_per_row)<<NUM_XFER_BITS),  // SCANLINE_CUR_X,
            starty); // window_top + (ii / pages_per_row)); // SCANLINE_CUR_Y);\
            
        end
        for (ii=0;ii< (window_height * pages_per_row) ;ii = ii+1) begin // here assuming 1 page per line
            if (ii >= TEST_INITIAL_BURST) begin // wait page ready and fill page after first 4 are filled
                wait_status_condition (
                    status_address, //MCNTRL_TEST01_STATUS_REG_CHN3_ADDR,
                    status_control_address, // MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN3_STATUS_CNTRL,
                    DEFAULT_STATUS_MODE,
                    (ii-TEST_INITIAL_BURST)<<16, // 4-bit page number
                    'hf << 16,  // mask for the 4-bit page number
                    1, // not equal to
                    (ii == TEST_INITIAL_BURST)); // synchronize sequence number - only first time, next just wait fro auto update
                xfer_size= ((pages_per_row>1)?
                    (
                        (
                            ((ii % pages_per_row) < (pages_per_row-1))?
                        
                         (1<<NUM_XFER_BITS):
                            (window_width % (1<<NUM_XFER_BITS))
                        )
                    ):
                    ({16'b0,window_width}));
                $display("########### test_scanline_write block %d: channel=%d, @%t", ii, channel, $time);
                startx=window_left + ((ii % pages_per_row)<<NUM_XFER_BITS);
                starty=window_top + (ii / pages_per_row);
                
                write_block_scanline_chn(
                    channel,
                    (ii & 3),
                xfer_size,
                startx,  // window_left + ((ii % pages_per_row)<<NUM_XFER_BITS),  // SCANLINE_CUR_X,
                starty); // window_top + (ii / pages_per_row)); // SCANLINE_CUR_Y);
            end
            write_contol_register(test_mode_address,            TEST01_NEXT_PAGE);
        end
        if (wait_done) begin
            wait_status_condition ( // may also be read directly from the same bit of mctrl_linear_rw (address=5) status
                status_address, // MCNTRL_TEST01_STATUS_REG_CHN3_ADDR,
                status_control_address, // MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN3_STATUS_CNTRL,
                DEFAULT_STATUS_MODE,
                2 << STATUS_2LSB_SHFT, // bit 24 - busy, bit 25 - frame done
                2 << STATUS_2LSB_SHFT,  // mask for the 4-bit page number
                0, // equal to
                0); // no need to synchronize sequence number
//     enable_memcntrl_en_dis(channel,0); // disable channel
        end
    end
endtask

task test_scanline_read; // SuppressThisWarning VEditor - may be unused
    input            [3:0] channel;
    input            [1:0] extra_pages;
    input                  show_data;
    input [15:0]           window_width;
    input [15:0]           window_height;
    input [15:0]           window_left;
    input [15:0]           window_top;
    
    reg             [29:0] start_addr;
    integer                mode;
    reg [STATUS_DEPTH-1:0] status_address;
    reg             [29:0] status_control_address;
    reg             [29:0] test_mode_address;
    integer       ii;
    integer xfer_size;
    integer pages_per_row;
    
    reg           repetitive;
    reg           single;
    reg           reset_frame;
    reg           disable_need; 
    
    begin
        disable_need = 1'b0;
        repetitive =  1'b1;
        single     =  1'b0;
        reset_frame = 1'b0;
        pages_per_row= (window_width>>NUM_XFER_BITS)+((window_width[NUM_XFER_BITS-1:0]==0)?0:1);
        $display("====== test_scanline_read: channel=%d, extra_pages=%d,  show_data=%d @%t",
                                             channel,    extra_pages,     show_data,    $time);
        case (channel)
//            1:  begin
//                    start_addr=             MCNTRL_SCANLINE_CHN1_ADDR;
//                    status_address=         MCNTRL_TEST01_STATUS_REG_CHN1_ADDR;
//                    status_control_address= MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN1_STATUS_CNTRL;
//                    test_mode_address=      MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN1_MODE;
//                end
            3:  begin
                    start_addr=             MCNTRL_SCANLINE_CHN3_ADDR;
                    status_address=         MCNTRL_TEST01_STATUS_REG_CHN3_ADDR;
                    status_control_address= MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN3_STATUS_CNTRL;
                    test_mode_address=      MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN3_MODE;
                end
            default: begin
                $display("**** ERROR: Invalid channel, only 3 is valid");
                start_addr=             MCNTRL_SCANLINE_CHN3_ADDR;
                status_address=         MCNTRL_TEST01_STATUS_REG_CHN1_ADDR;
                status_control_address= MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN1_STATUS_CNTRL;
                test_mode_address=      MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN1_MODE;
            end
        endcase
        mode=   func_encode_mode_scanline(
                    disable_need,
                    repetitive,
                    single,
                    reset_frame,
                    extra_pages,
                    0, // write_mem,
                    1, // enable
                    0);  // chn_reset

   // program to the
        write_contol_register(start_addr + MCNTRL_SCANLINE_STARTADDR,        FRAME_START_ADDRESS); // RA=80, CA=0, BA=0 22-bit frame start address (3 CA LSBs==0. BA==0) 
        write_contol_register(start_addr + MCNTRL_SCANLINE_FRAME_FULL_WIDTH, FRAME_FULL_WIDTH);
        write_contol_register(start_addr + MCNTRL_SCANLINE_WINDOW_WH,        {window_height,window_width}); //WINDOW_WIDTH + (WINDOW_HEIGHT<<16));
        write_contol_register(start_addr + MCNTRL_SCANLINE_WINDOW_X0Y0,      {window_top,window_left}); //WINDOW_X0+ (WINDOW_Y0<<16));
        write_contol_register(start_addr + MCNTRL_SCANLINE_WINDOW_STARTXY,   SCANLINE_STARTX+(SCANLINE_STARTY<<16));
        write_contol_register(start_addr + MCNTRL_SCANLINE_MODE,             mode);// set mode register: {extra_pages[1:0],enable,!reset}
        configure_channel_priority(channel,0);    // lowest priority channel 3
        enable_memcntrl_en_dis(channel,1);
        write_contol_register(test_mode_address,            TEST01_START_FRAME);
        for (ii=0;ii<(window_height * pages_per_row);ii = ii+1) begin
            xfer_size= ((pages_per_row>1)?
                (
                    (
                        ((ii % pages_per_row) < (pages_per_row-1))?
                        (1<<NUM_XFER_BITS):
                        (window_width % (1<<NUM_XFER_BITS))
                    )
                ):
                ({16'b0,window_width}));
            wait_status_condition (
                status_address, //MCNTRL_TEST01_STATUS_REG_CHN2_ADDR,
                status_control_address, // MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN2_STATUS_CNTRL,
                DEFAULT_STATUS_MODE,
                (ii) << 16, // -TEST_INITIAL_BURST)<<16, // 4-bit page number
                'hf << 16,  // mask for the 4-bit page number
                 1, // not equal to
                 (ii == 0)); // synchronize sequence number - only first time, next just wait fro auto update
// read block (if needed), for now just sikip  
                if (show_data) begin
                    $display("########### test_scanline_read block %d: channel=%d, @%t", ii, channel, $time);
                    read_block_buf_chn (
                        channel,
                        (ii & 3),
                        xfer_size <<2,
                        1 ); // chn=0, page=3, number of 32-bit words=256, wait_done
                end
        write_contol_register(test_mode_address,            TEST01_NEXT_PAGE);
    end
  end  
endtask

task test_tiled_write; // SuppressThisWarning VEditor - may be unused
    input            [3:0] channel;
    input                  byte32;
    input                  keep_open;
    input            [1:0] extra_pages;
    input                  wait_done;
    input [15:0]           window_width;
    input [15:0]           window_height;
    input [15:0]           window_left;
    input [15:0]           window_top;
    input [ 7:0]           tile_width;
    input [ 7:0]           tile_height;
    input [ 7:0]           tile_vstep;
    
    
    
    reg             [29:0] start_addr;
    integer                mode;
    reg [STATUS_DEPTH-1:0] status_address;
    reg             [29:0] status_control_address;
    reg             [29:0] test_mode_address;
    integer       ii;
    integer       tiles_per_row;
    integer       tile_rows_per_window;
    integer       tile_size;
    integer startx,starty; // temporary - because of the vdt bug with integer ports
    reg           repetitive;
    reg           single;
    reg           reset_frame;
    reg           disable_need; 
    begin
        disable_need = 1'b0;
        repetitive =  1'b1;
        single     =  1'b0;
        reset_frame = 1'b0;

        tiles_per_row= (window_width/tile_width)+  ((window_width % tile_width==0)?0:1);
        tile_rows_per_window= ((window_height-1)/tile_vstep) + 1;
        tile_size= tile_width*tile_height;
        $display("====== test_tiled_write: channel=%d, byte32=%d, keep_open=%d, extra_pages=%d,  wait_done=%d @%t",
                                           channel,    byte32,    keep_open,    extra_pages,     wait_done,   $time);
        case (channel)
            2:  begin
                    start_addr=             MCNTRL_TILED_CHN2_ADDR;
                    status_address=         MCNTRL_TEST01_STATUS_REG_CHN2_ADDR;
                    status_control_address= MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN2_STATUS_CNTRL;
                    test_mode_address=      MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN2_MODE;
                end
            4:  begin
                    start_addr=             MCNTRL_TILED_CHN4_ADDR;
                    status_address=         MCNTRL_TEST01_STATUS_REG_CHN4_ADDR;
                    status_control_address= MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN4_STATUS_CNTRL;
                    test_mode_address=      MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN4_MODE;
                end
            default: begin
                $display("**** ERROR: Invalid channel, only 2 and 4 are valid");
                start_addr=             MCNTRL_TILED_CHN2_ADDR;
                status_address=         MCNTRL_TEST01_STATUS_REG_CHN2_ADDR;
                status_control_address= MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN2_STATUS_CNTRL;
                test_mode_address=      MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN2_MODE;
            end
        endcase
        mode=   func_encode_mode_tiled(
                    disable_need,
                    repetitive,
                    single,
                    reset_frame,
                    byte32,
                    keep_open,
                    extra_pages,
                    1, // write_mem,
                    1, // enable
                    0);  // chn_reset
        write_contol_register(start_addr + MCNTRL_TILED_STARTADDR,        FRAME_START_ADDRESS); // RA=80, CA=0, BA=0 22-bit frame start address (3 CA LSBs==0. BA==0) 
        write_contol_register(start_addr + MCNTRL_TILED_FRAME_FULL_WIDTH, FRAME_FULL_WIDTH);
        write_contol_register(start_addr + MCNTRL_TILED_WINDOW_WH,        {window_height,window_width}); //WINDOW_WIDTH + (WINDOW_HEIGHT<<16));
        write_contol_register(start_addr + MCNTRL_TILED_WINDOW_X0Y0,      {window_top,window_left}); //WINDOW_X0+ (WINDOW_Y0<<16));
        
        write_contol_register(start_addr + MCNTRL_TILED_WINDOW_STARTXY,   TILED_STARTX+(TILED_STARTY<<16));
        write_contol_register(start_addr + MCNTRL_TILED_TILE_WHS,         {8'b0,tile_vstep,tile_height,tile_width});//tile_width+(tile_height<<8)+(tile_vstep<<16));
        write_contol_register(start_addr + MCNTRL_TILED_MODE,             mode);// set mode register: {extra_pages[1:0],enable,!reset}
        configure_channel_priority(channel,0);    // lowest priority channel 3
        enable_memcntrl_en_dis(channel,1);
        write_contol_register(test_mode_address,            TEST01_START_FRAME);
    
        for (ii=0;ii<TEST_INITIAL_BURST;ii=ii+1) begin
            $display("########### test_tiled_write block %d: channel=%d, @%t", ii, channel, $time);
            startx = window_left + ((ii % tiles_per_row) * tile_width);
            starty = window_top + (ii / tile_rows_per_window); // SCANLINE_CUR_Y);\
            write_block_scanline_chn( // TODO: Make a different tile buffer data, matching the order
                channel, // channel
                (ii & 3),
                tile_size,
                startx, //window_left + ((ii % tiles_per_row) * tile_width),
                starty); //window_top + (ii / tile_rows_per_window)); // SCANLINE_CUR_Y);\
        end
    
        for (ii=0;ii<(tiles_per_row * tile_rows_per_window);ii = ii+1) begin
            if (ii >= TEST_INITIAL_BURST) begin // wait page ready and fill page after first 4 are filled
                wait_status_condition (
                    status_address, // MCNTRL_TEST01_STATUS_REG_CHN5_ADDR,
                    status_control_address, // MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN5_STATUS_CNTRL,
                    DEFAULT_STATUS_MODE,
                    (ii-TEST_INITIAL_BURST)<<16, // 4-bit page number
                    'hf << 16,  // mask for the 4-bit page number
                    1, // not equal to
                    (ii == TEST_INITIAL_BURST)); // synchronize sequence number - only first time, next just wait fro auto update
                $display("########### test_tiled_write block %d: channel=%d, @%t", ii, channel, $time);
                startx = window_left + ((ii % tiles_per_row) * tile_width);
                starty = window_top + (ii / tile_rows_per_window);
                write_block_scanline_chn( // TODO: Make a different tile buffer data, matching the order
                    channel, // channel
                    (ii & 3),
                    tile_size,
                    startx, // window_left + ((ii % tiles_per_row) * tile_width),
                    starty); // window_top + (ii / tile_rows_per_window)); // SCANLINE_CUR_Y);\
            end
            write_contol_register(test_mode_address,            TEST01_NEXT_PAGE);
        end
        if (wait_done) begin
            wait_status_condition ( // may also be read directly from the same bit of mctrl_linear_rw (address=5) status
                status_address, // MCNTRL_TEST01_STATUS_REG_CHN3_ADDR,
                status_control_address, // MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN3_STATUS_CNTRL,
                DEFAULT_STATUS_MODE,
                2 << STATUS_2LSB_SHFT, // bit 24 - busy, bit 25 - frame done
                2 << STATUS_2LSB_SHFT,  // mask for the 4-bit page number
                0, // equal to
                0); // no need to synchronize sequence number
//     enable_memcntrl_en_dis(channel,0); // disable channel
        end
    end  
endtask

task test_tiled_read; // SuppressThisWarning VEditor - may be unused
    input            [3:0] channel;
    input                  byte32;
    input                  keep_open;
    input            [1:0] extra_pages;
    input                  show_data;
    input [15:0]           window_width;
    input [15:0]           window_height;
    input [15:0]           window_left;
    input [15:0]           window_top;
    input [ 7:0]           tile_width;
    input [ 7:0]           tile_height;
    input [ 7:0]           tile_vstep;
    
    reg             [29:0] start_addr;
    integer                mode;
    reg [STATUS_DEPTH-1:0] status_address;
    reg             [29:0] status_control_address;
    reg             [29:0] test_mode_address;
    
    integer       ii;
    integer       tiles_per_row;
    integer       tile_rows_per_window;
    integer       tile_size;
    
    reg           repetitive;
    reg           single;
    reg           reset_frame;
    reg           disable_need; 
    begin
        disable_need = 1'b0;
        repetitive =  1'b1;
        single     =  1'b0;
        reset_frame = 1'b0;
        
        tiles_per_row= (window_width/tile_width)+  ((window_width % tile_width==0)?0:1);
        tile_rows_per_window= ((window_height-1)/tile_vstep) + 1;
        tile_size= tile_width*tile_height;
        $display("====== test_tiled_read: channel=%d, byte32=%d, keep_open=%d, extra_pages=%d,  show_data=%d @%t",
                                          channel,      byte32,  keep_open,    extra_pages,     show_data,   $time);
        case (channel)
            2:  begin
                    start_addr=             MCNTRL_TILED_CHN2_ADDR;
                    status_address=         MCNTRL_TEST01_STATUS_REG_CHN2_ADDR;
                    status_control_address= MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN2_STATUS_CNTRL;
                    test_mode_address=      MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN2_MODE;
                end
            4:  begin
                    start_addr=             MCNTRL_TILED_CHN4_ADDR;
                    status_address=         MCNTRL_TEST01_STATUS_REG_CHN4_ADDR;
                    status_control_address= MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN4_STATUS_CNTRL;
                    test_mode_address=      MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN4_MODE;
                end
            default: begin
                $display("**** ERROR: Invalid channel, only 2 and 4 are valid");
                start_addr=             MCNTRL_TILED_CHN2_ADDR;
                status_address=         MCNTRL_TEST01_STATUS_REG_CHN2_ADDR;
                status_control_address= MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN2_STATUS_CNTRL;
                test_mode_address=      MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN2_MODE;
            end
        endcase
        mode=   func_encode_mode_tiled(
                    disable_need,
                    repetitive,
                    single,
                    reset_frame,
                    byte32,
                    keep_open,
                    extra_pages,
                    0, // write_mem,
                    1, // enable
                    0);  // chn_reset
        write_contol_register(start_addr + MCNTRL_TILED_STARTADDR,        FRAME_START_ADDRESS); // RA=80, CA=0, BA=0 22-bit frame start address (3 CA LSBs==0. BA==0) 
        write_contol_register(start_addr + MCNTRL_TILED_FRAME_FULL_WIDTH, FRAME_FULL_WIDTH);
        write_contol_register(start_addr + MCNTRL_TILED_WINDOW_WH,        {window_height,window_width}); //WINDOW_WIDTH + (WINDOW_HEIGHT<<16));
        write_contol_register(start_addr + MCNTRL_TILED_WINDOW_X0Y0,      {window_top,window_left}); //WINDOW_X0+ (WINDOW_Y0<<16));
        
        write_contol_register(start_addr + MCNTRL_TILED_WINDOW_STARTXY,   TILED_STARTX+(TILED_STARTY<<16));
        write_contol_register(start_addr + MCNTRL_TILED_TILE_WHS,         {8'b0,tile_vstep,tile_height,tile_width});//(tile_height<<8)+(tile_vstep<<16));
        write_contol_register(start_addr + MCNTRL_TILED_MODE,             mode);// set mode register: {extra_pages[1:0],enable,!reset}
        configure_channel_priority(channel,0);    // lowest priority channel 3
        enable_memcntrl_en_dis(channel,1);
        write_contol_register(test_mode_address,            TEST01_START_FRAME);
        for (ii=0;ii<(tiles_per_row * tile_rows_per_window);ii = ii+1) begin
            wait_status_condition (
                status_address, // MCNTRL_TEST01_STATUS_REG_CHN4_ADDR,
                status_control_address, // MCNTRL_TEST01_ADDR + MCNTRL_TEST01_CHN4_STATUS_CNTRL,
                DEFAULT_STATUS_MODE,
                ii << 16, // -TEST_INITIAL_BURST)<<16, // 4-bit page number
                'hf << 16,  // mask for the 4-bit page number
                1, // not equal to
                (ii == 0)); // synchronize sequence number - only first time, next just wait fro auto update
                if (show_data) begin 
                    $display("########### test_tiled_read block %d: channel=%d, @%t", ii, channel, $time);
                    read_block_buf_chn (
                        channel,
                        (ii & 3),
                        tile_size <<2,
                        1 ); // chn=0, page=3, number of 32-bit words=256, wait_done
                end
            write_contol_register(test_mode_address,            TEST01_NEXT_PAGE);
        end
//     enable_memcntrl_en_dis(channel,0); // disable channel
    end  
endtask




