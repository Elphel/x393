 /*******************************************************************************
 * File: x393_tasks_ps_pio.vh
 * Date:2015-02-07  
 * Author: Andrey Filippov     
 * Description: Simulation tasks for mcntrl_ps_pio module (launching software
 * - programmed memory transaction sequences)
 *
 * Copyright (c) 2015 Elphel, Inc.
 * x393_tasks_ps_pio.vh is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * x393_tasks_ps_pio.vh is distributed in the hope that it will be useful,
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
 * charge, and there is no dependence on any encrypted modules for simulating of
 * the combined code. This permission applies to you if the distributed code
 * contains all the components and scripts required to completely simulate it
 * with at least one of the Free Software programs.
 *******************************************************************************/
task schedule_ps_pio; // schedule software-control memory operation (may need to check FIFO status first)
    input [9:0] seq_addr; // sequence start address
    input [1:0] page;     // buffer page number
    input       urgent;   // high priority request (only for competion wityh other channels, wiil not pass in this FIFO)
    input       chn;      // channel buffer to use: 0 - memory read, 1 - memory write
    input       wait_complete; // Do not request a new transaction from the scheduler until previous memory transaction is finished
    begin
//        wait_ps_pio_ready(DEFAULT_STATUS_MODE); // wait FIFO not half full 
        write_contol_register(MCNTRL_PS_ADDR + MCNTRL_PS_CMD, {17'b0,wait_complete,chn,urgent,page,seq_addr});
    end
endtask

task wait_ps_pio_ready; // wait PS PIO module can accept comamnds (fifo half empty)
    input [1:0] mode;
    input       sync_seq; //  synchronize sequences
    begin
        wait_status_condition (
            MCNTRL_PS_STATUS_REG_ADDR,
            MCNTRL_PS_ADDR+MCNTRL_PS_STATUS_CNTRL,
            mode,
            0,
            2 << STATUS_2LSB_SHFT,
            0,
            sync_seq);
    end
endtask
task wait_ps_pio_done; // wait PS PIO module has no pending/running memory transaction
    input [1:0] mode;
    input       sync_seq; //  synchronize sequences
    begin
        wait_status_condition (
            MCNTRL_PS_STATUS_REG_ADDR,
            MCNTRL_PS_ADDR+MCNTRL_PS_STATUS_CNTRL,
            mode,
            0,
            3 << STATUS_2LSB_SHFT,
            0,
            sync_seq);
    end
endtask
 
