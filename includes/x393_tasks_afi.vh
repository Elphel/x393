 /*******************************************************************************
 * File: x393_tasks_afi.vh
 * Date:2015-02-07  
 * Author: Andrey Filippov     
 * Description: Simulation tasks for the AXI_HP (AFI)
 *
 * Copyright (c) 2015 Elphel, Inc.
 * x393_tasks_afi.vh is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * x393_tasks_afi.vh is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/

 task membridge_setup;
    input [28:0] len64;    // number of 64-bit words to transfer
    input [28:0] width64;  // frame width in 64-bit words
    input [28:0] start64;  // relative start address of the transfer (set to 0 when writing lo_addr64)
    input [28:0] lo_addr64; // low address of the system memory range, in 64-bit words 
    input [28:0] size64;    // size of the system memory range in 64-bit words
     
    begin
        write_contol_register(MEMBRIDGE_ADDR + MEMBRIDGE_LO_ADDR64,        {3'b0,lo_addr64});    
        write_contol_register(MEMBRIDGE_ADDR + MEMBRIDGE_SIZE64,           {3'b0,size64});    
        write_contol_register(MEMBRIDGE_ADDR + MEMBRIDGE_START64,          {3'b0,start64});    
        write_contol_register(MEMBRIDGE_ADDR + MEMBRIDGE_LEN64,            {3'b0,len64});    
        write_contol_register(MEMBRIDGE_ADDR + MEMBRIDGE_WIDTH64,          {3'b0,width64});    
    end
endtask

task membridge_start;
    input continue;    // 0 start from start64, 1 - continue from where it was
    begin
        write_contol_register(MEMBRIDGE_ADDR + MEMBRIDGE_CTRL,         {29'b0,continue,2'b11});    
    end
endtask

task membridge_en; // SuppressThisWarning VEditor - may be unused
    input en;    // not needed to start, pauses axi if set to 0 whil running, resets "done" status bit
    begin
        write_contol_register(MEMBRIDGE_ADDR + MEMBRIDGE_CTRL,         {31'b0,en});    
    end
endtask


task afi_setup;
    input   [1:0] port_num;
    begin
        afi_write_reg(port_num,  'h0, 0); // AFI_RDCHAN_CTRL
        afi_write_reg(port_num,  'h4, 7); // AFI_RDCHAN_ISSUINGCAP
        afi_write_reg(port_num,  'h8, 0); // AFI_RDQOS
        //afi_write_reg(port_num,  'hc, 0); // AFI_RDDATAFIFO_LEVEL
        //afi_write_reg(port_num, 'h10, 0); // AFI_RDDEBUG
        afi_write_reg(port_num, 'h14, 'hf00); // AFI_WRCHAN_CTRL
        afi_write_reg(port_num, 'h18, 7); // AFI_WRCHAN_ISSUINGCAP
        afi_write_reg(port_num, 'h1c, 0); // AFI_WRQOS
        //afi_write_reg(port_num,  'h20, 0); // AFI_WRDATAFIFO_LEVEL
        //afi_write_reg(port_num, 'h24, 0); // AFI_WRDEBUG
    end
endtask

task afi_write_reg;
    input   [1:0] port_num;
    input integer rel_baddr; // relative byte address
    input  [31:0] data;
    begin
       ps_write_reg(32'hf8008000+ (port_num << 12) + (rel_baddr & 'hfffffffc), data);
    end
endtask

task afi_read_reg; // SuppressThisWarning VEditor - may be unused
    input   [1:0] port_num;
    input integer rel_baddr; // relative byte address
    input  verbose;
    begin
       ps_read_reg(32'hf8008000+ (port_num << 12) + (rel_baddr & 'hfffffffc), verbose);
    end
endtask

task ps_write_reg;
    input [31:0] ps_reg_addr;
    input [31:0] ps_reg_data;
    begin
        @(posedge HCLK);
        PS_REG_ADDR <= ps_reg_addr;
        PS_REG_DIN <= ps_reg_data;
        PS_REG_WR <= 1'b1;
        @(posedge HCLK);
        PS_REG_ADDR <= 'bx;
        PS_REG_DIN <= 'bx;
        PS_REG_WR <= 1'b0;
    end
endtask

task ps_read_reg;
    input [31:0] ps_reg_addr;
    input verbose;
    begin
        @(posedge HCLK);
        PS_REG_ADDR <= ps_reg_addr;
        PS_REG_RD <= 1'b1;
        @(posedge HCLK);
        PS_REG_ADDR <= 'bx;
        PS_REG_DIN <= 'bx;
        PS_REG_WR <= 1'b0;
        @(negedge HCLK);
        if (verbose) begin
            $display("ps_read_reg(%x) -> %x @%t",ps_reg_addr,PS_RDATA,$time);
        end
    end
endtask
 