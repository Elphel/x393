 /*******************************************************************************
 * File: x393_status.vh
 * Date:2015-02-07  
 * Author: Andrey Filippov     
 * Description: Simulation tasks for the x393 related to status
 *
 * Copyright (c) 2015 Elphel, Inc.
 * x393_status.vh is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * x393_status.vh is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/

// CVC bug that is supposed to be already fixed 
`ifdef CVC 
task wait_status_condition;
    input [STATUS_DEPTH-1:0] status_address;
    input [29:0] status_control_address;
    input  [1:0] status_mode;
    input [25:0] pattern;        // bits as in read registers
    input [25:0] mask;           // which bits to compare
    input        invert_match;   // 0 - wait until match to pattern (all bits), 1 - wait until no match (any of bits differ)
    input        wait_seq;
    reg          match;
    reg    [5:0] seq_num;
    reg [31:0] pattern1;
    reg [31:0] mask1;
    begin
        WAITING_STATUS = 1;
        pattern1 = {6'h0,pattern};
        mask1 = {6'h0,mask};
        for (match=0; !match; match = invert_match ^ (((registered_rdata ^ pattern1) & mask1)==0)) begin
            read_status(status_address);
            if (wait_seq) begin 
                seq_num = (registered_rdata[STATUS_SEQ_SHFT+:6] ^ 6'h20)&'h30;
                write_contol_register(status_control_address, {24'b0,status_mode,seq_num});
                read_status(status_address);
                while (((registered_rdata[STATUS_SEQ_SHFT+:6] ^ seq_num) & 6'h30)!=0) begin // match just 2 MSBs
                    read_status(status_address);
                end
            end
        pattern1 = {6'h0,pattern};
        mask1 = {6'h0,mask};
        end
        WAITING_STATUS = 0;
    end
endtask
`else
task wait_status_condition;
    input [STATUS_DEPTH-1:0] status_address;
    input [29:0] status_control_address;
    input  [1:0] status_mode;
    input [25:0] pattern;        // bits as in read registers
    input [25:0] mask;           // which bits to compare
    input        invert_match;   // 0 - wait until match to pattern (all bits), 1 - wait until no match (any of bits differ)
    input        wait_seq;
    reg          match;
    reg    [5:0] seq_num;
    begin
        WAITING_STATUS = 1;
        for (match=0; !match; match = invert_match ^ (((registered_rdata ^ {6'h0,pattern}) & {6'h0,mask})==0)) begin
            read_status(status_address);
            if (wait_seq) begin 
                seq_num = (registered_rdata[STATUS_SEQ_SHFT+:6] ^ 6'h20)&'h30;
                write_contol_register(status_control_address, {24'b0,status_mode,seq_num});
                read_status(status_address);
                while (((registered_rdata[STATUS_SEQ_SHFT+:6] ^ seq_num) & 6'h30)!=0) begin // match just 2 MSBs
                    read_status(status_address);
                end
            end
        end
        WAITING_STATUS = 0;
    end
endtask    
`endif
/*
task wait_status_condition_auto; // assumes status is already updating
    input [STATUS_DEPTH-1:0] status_address;
    input [29:0] status_control_address;
    input  [1:0] status_mode;
    input [25:0] pattern;        // bits as in read registers
    input [25:0] mask;           // which bits to compare
    input        invert_match;   // 0 - wait until match to pattern (all bits), 1 - wait until no match (any of bits differ)
    reg          match;
    begin
        WAITING_STATUS = 1;
        for (match=0; !match; match = invert_match ^ (((registered_rdata ^ {6'h0,pattern}) & {6'h0,mask})==0)) begin
            read_status(status_address);
        end
        WAITING_STATUS = 0;
    end
endtask    
*/

 task wait_phase_shifter_ready;
    begin
        WAITING_STATUS = 1;
        read_status(MCONTR_PHY_STATUS_REG_ADDR);
        while (((registered_rdata & STATUS_PSHIFTER_RDY_MASK) == 0) || (((registered_rdata ^ {24'h0,target_phase}) & 'hff) != 0)) begin
            read_status(MCONTR_PHY_STATUS_REG_ADDR); // exits after negedge CLK
        end
        WAITING_STATUS = 0;
    end
 endtask
 
 task read_all_status;
    begin
        $display (" read_all_status @%t",$time);
        read_status (MCONTR_PHY_STATUS_REG_ADDR);
        read_status (MCONTR_TOP_STATUS_REG_ADDR);
        read_status (MCNTRL_PS_STATUS_REG_ADDR);
        read_status (MCNTRL_SCANLINE_STATUS_REG_CHN1_ADDR);
        read_status (MCNTRL_SCANLINE_STATUS_REG_CHN3_ADDR);
        read_status (MCNTRL_TILED_STATUS_REG_CHN2_ADDR);
        read_status (MCNTRL_TILED_STATUS_REG_CHN4_ADDR);
//        read_status (MCNTRL_TEST01_STATUS_REG_CHN1_ADDR);
        read_status (MCNTRL_TEST01_STATUS_REG_CHN2_ADDR);
        read_status (MCNTRL_TEST01_STATUS_REG_CHN3_ADDR);
        read_status (MCNTRL_TEST01_STATUS_REG_CHN4_ADDR);
        read_status (MEMBRIDGE_STATUS_REG);
        
    end
 endtask 
  
 task read_status;
    input [STATUS_DEPTH-1:0] address;
    begin
        read_and_wait_w(STATUS_ADDR + address ); // Will set:       registered_rdata <= rdata;
        
    end
 endtask
  
  
 task program_status_all;
    input [1:0] mode;
    input [5:0] seq_num;
    begin
        program_status (MCONTR_PHY_16BIT_ADDR,     MCONTR_PHY_STATUS_CNTRL,        mode,seq_num); //MCONTR_PHY_STATUS_REG_ADDR=          'h0,
        program_status (MCONTR_TOP_16BIT_ADDR,     MCONTR_TOP_16BIT_STATUS_CNTRL,  mode,seq_num); //MCONTR_TOP_STATUS_REG_ADDR=          'h1,
        program_status (MCNTRL_PS_ADDR,            MCNTRL_PS_STATUS_CNTRL,         mode,seq_num); //MCNTRL_PS_STATUS_REG_ADDR=           'h2,
        program_status (MCNTRL_SCANLINE_CHN1_ADDR, MCNTRL_SCANLINE_STATUS_CNTRL,   mode,seq_num); //MCNTRL_SCANLINE_STATUS_REG_CHN2_ADDR='h4,
        program_status (MCNTRL_SCANLINE_CHN3_ADDR, MCNTRL_SCANLINE_STATUS_CNTRL,   mode,seq_num); //MCNTRL_SCANLINE_STATUS_REG_CHN3_ADDR='h5,
        program_status (MCNTRL_TILED_CHN2_ADDR,    MCNTRL_TILED_STATUS_CNTRL,      mode,seq_num); //MCNTRL_TILED_STATUS_REG_CHN4_ADDR=   'h6,
        program_status (MCNTRL_TILED_CHN4_ADDR,    MCNTRL_TILED_STATUS_CNTRL,      mode,seq_num); //MCNTRL_TILED_STATUS_REG_CHN4_ADDR=   'h6,
//        program_status (MCNTRL_TEST01_ADDR,        MCNTRL_TEST01_CHN1_STATUS_CNTRL,mode,seq_num); //MCNTRL_TEST01_STATUS_REG_CHN2_ADDR=  'h3c,
        program_status (MCNTRL_TEST01_ADDR,        MCNTRL_TEST01_CHN2_STATUS_CNTRL,mode,seq_num); //MCNTRL_TEST01_STATUS_REG_CHN2_ADDR=  'h3c,
        program_status (MCNTRL_TEST01_ADDR,        MCNTRL_TEST01_CHN3_STATUS_CNTRL,mode,seq_num); //MCNTRL_TEST01_STATUS_REG_CHN3_ADDR=  'h3d,
        program_status (MCNTRL_TEST01_ADDR,        MCNTRL_TEST01_CHN4_STATUS_CNTRL,mode,seq_num); //MCNTRL_TEST01_STATUS_REG_CHN4_ADDR=  'h3e,
        program_status (MEMBRIDGE_ADDR    ,        MEMBRIDGE_STATUS_CNTRL,         mode,seq_num); //MCNTRL_TEST01_STATUS_REG_CHN4_ADDR=  'h3e,
    end
 endtask
  
 task   program_status;
    input [29:0] base_addr;
    input  [7:0] reg_addr;
    input  [1:0] mode;
 // mode bits:
 // 0 disable status generation,
 // 1 single status request,
 // 2 - auto status, keep specified seq number,
 // 3 - auto, inc sequence number 
    input  [5:0] seq_number;
    begin
//        axi_write_single_w(CONTROL_ADDR+base_addr+reg_addr, {24'b0,mode,seq_number});
        write_contol_register(base_addr + reg_addr, {24'b0,mode,seq_number});
    end
 endtask   
    
