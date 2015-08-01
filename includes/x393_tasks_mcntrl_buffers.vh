 /*******************************************************************************
 * File: x393_tasks_mcntrl_buffers.vh
 * Date:2015-02-07  
 * Author: Andrey Filippov     
 * Description: Simulation tasks for software reading/writing (with test patterns)
 * of the block buffers.
 *
 * Copyright (c) 2015 Elphel, Inc.
 * x393_tasks_mcntrl_buffers.vh is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * x393_tasks_mcntrl_buffers.vh is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
/* 
task write_block_scanline_chn;  // S uppressThisWarning VEditor : may be unused
    input integer chn; // buffer channel
    input   [1:0] page;
//    input integer num_words; // number of words to write (will be rounded up to multiple of 16)
    input [NUM_XFER_BITS:0] num_bursts; // number of 8-bursts to write (will be rounded up to multiple of 16)
    input integer startX;
    input integer startY;
    reg    [29:0] start_addr;
    begin
        $display("====== write_block_scanline_chn:%d page: %x X=0x%x Y=0x%x num=%d @%t", chn, page, startX, startY,num_words, $time);
        case (chn)
            1:  start_addr=MCONTR_BUF0_WR_ADDR + (page << 8);
            3:  start_addr=MCONTR_BUF3_WR_ADDR + (page << 8);
            default: begin
                $display("**** ERROR: Invalid channel for write_block_scanline_chn = %d @%t", chn, $time);
                start_addr = MCONTR_BUF0_WR_ADDR+ (page << 8);
            end
        endcase
//        write_block_incremtal (start_addr, num_words, (startX<<2) + (startY<<16)); // 1 of startX is 8x16 bit, 16 bytes or 4 32-bit words
        write_block_incremtal (start_addr, num_bursts << 2, (startX<<2) + (startY<<16)); // 1 of startX is 8x16 bit, 16 bytes or 4 32-bit words
    end
endtask
*/

task write_block_incremtal;
    input [29:0] start_word_address;
    input integer num_words; // number of words to write (will be rounded up to multiple of 16)
    input integer start_value;      
    integer i, j;
    begin
        $display("**** write_block_buf  @%t", $time);
        for (i = 0; i < num_words; i = i + 16) begin
            axi_write_addr_data(
                i,    // id
                {start_word_address,2'b0}+( i << 2),
                start_value+i,
                4'hf, // len
                1,    // burst type - increment
                1'b1, // data_en
                4'hf, // wstrb
                1'b0 // last
                );
//            $display("+Write block data (addr:data): 0x%x:0x%08x @%t", i, i | (((i + 7) & 'hff) << 8) | (((i + 23) & 'hff) << 16) | (((i + 31) & 'hff) << 24), $time);
            $display("+Write block incremental (addr:data): 0x%x:0x%08x @%t", i, start_value+i, $time);
            for (j = 1; j < 16; j = j + 1) begin
                axi_write_data(
                    i,        // id
                    start_value+i+j,
                    4'hf, // wstrb
                    (j == 15) ? 1'b1 : 1'b0 // last
                    );
                $display(" Write block incremental (addr:data): 0x%08x:0x%x @%t", (i + j), start_value+i+j, $time);
            end
        end
    end
endtask

task write_block_buf_chn;  // S uppressThisWarning VEditor : may be unused
    input integer chn; // buffer channel
    input   [1:0] page;
    input integer num_words; // number of words to write (will be rounded up to multiple of 16)
    reg    [29:0] start_addr;
    begin
        case (chn)
            0:  start_addr=MCONTR_BUF0_WR_ADDR + (page << 8);
//            1:  start_addr=MCONTR_BUF1_WR_ADDR + (page << 8);
            2:  start_addr=MCONTR_BUF2_WR_ADDR + (page << 8);
            3:  start_addr=MCONTR_BUF3_WR_ADDR + (page << 8);
            4:  start_addr=MCONTR_BUF4_WR_ADDR + (page << 8);
            default: begin
                $display("**** ERROR: Invalid channel (not 0,2,3,4) for write buffer = %d @%t", chn, $time);
                start_addr = MCONTR_BUF0_WR_ADDR+ (page << 8);
            end
        endcase
        write_block_buf (start_addr, num_words);
    end
endtask

task write_block_buf;
    input [29:0] start_word_address;
    input integer num_words; // number of words to write (will be rounded up to multiple of 16)
    integer i, j;
    begin
        $display("**** write_block_buf  @%t", $time);
        for (i = 0; i < num_words; i = i + 16) begin
            axi_write_addr_data(
                i,    // id
                {start_word_address,2'b0}+( i << 2),
//                (MCONTR_BUF0_WR_ADDR + (page <<8)+ i) << 2, // addr
                i | (((i + 7) & 'hff) << 8) | (((i + 23) & 'hff) << 16) | (((i + 31) & 'hff) << 24),
                4'hf, // len
                1,    // burst type - increment
                1'b1, // data_en
                4'hf, // wstrb
                1'b0 // last
                );
            $display("+Write block data (addr:data): 0x%x:0x%08x @%t", i, i | (((i + 7) & 'hff) << 8) | (((i + 23) & 'hff) << 16) | (((i + 31) & 'hff) << 24), $time);
            for (j = 1; j < 16; j = j + 1) begin
                axi_write_data(
                    i,        // id
                    (i + j) | ((((i + j) + 7) & 'hff) << 8) | ((((i + j) + 23) & 'hff) << 16) | ((((i + j) + 31) & 'hff) << 24),
                    4'hf, // wstrb
                    (j == 15) ? 1'b1 : 1'b0 // last
                    );
                $display(" Write block data (addr:data): 0x%08x:0x%x @%t", (i + j),
                    (i + j) | ((((i + j) + 7) & 'hff) << 8) | ((((i + j) + 23) & 'hff) << 16) | ((((i + j) + 31) & 'hff) << 24), $time);
            end
        end
    end
endtask
   
   // read memory
task read_block_buf_chn;  // S uppressThisWarning VEditor : may be unused
//    input integer chn; // buffer channel
    input [3:0] chn; // buffer channel
    input   [1:0] page;
    input integer num_read; // number of words to read (will be rounded up to multiple of 16)
    input wait_done; 
    reg    [29:0] start_addr;
    begin
        case (chn)
            0:  start_addr=MCONTR_BUF0_RD_ADDR + (page << 8);
            2:  start_addr=MCONTR_BUF2_RD_ADDR + (page << 8);
            3:  start_addr=MCONTR_BUF3_RD_ADDR + (page << 8);
            4:  start_addr=MCONTR_BUF4_RD_ADDR + (page << 8);
            default: begin
                $display("**** ERROR: Invalid channel (not 0,2,3,4) for read buffer = %d @%t", chn, $time);
                start_addr = 30'b0+ (page << 8);
            end
        endcase
        read_block_buf (start_addr, num_read, wait_done);
    end
endtask

task read_block_buf; 
    input [29:0] start_word_address;
    input integer num_read; // number of words to read (will be rounded up to multiple of 16)
    input wait_done; 
    integer i; //,j;
    begin
        wait (~rstb);
        SIMUL_AXI_FULL<=1'b0;
        $display("**** read_block_buf  @%t", $time);
        axi_set_rd_lag(0);
        for (i = 0; i < num_read; i = i + 16) begin
            wait(arready);
//                $display ("read_block_buf (0x%x) @%t",i,$time);
            axi_read_addr(
                i,    // id
                {start_word_address,2'b0}+( i << 2), // addr
                4'hf, // len
                1     // burst type - increment
                );
        end
        if (wait_done) begin
//            wait (AXI_RD_EMPTY);
            wait_read_queue_empty;
        end
    end
endtask
