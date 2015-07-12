 /*******************************************************************************
 * File: x393_tasks_mcntrl_timing.vh
 * Date:2015-02-07  
 * Author: Andrey Filippov     
 * Description: Simulation tasks for programming I/O delays and other timing
 * parameters in the memory controller
 *
 * Copyright (c) 2015 Elphel, Inc.
 * x393_tasks_mcntrl_timing.vh is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * x393_tasks_mcntrl_timing.vh is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/

      task axi_set_same_delays;  //SuppressThisWarning VEditor : may be unused
        input [7:0] dq_idelay;
        input [7:0] dq_odelay;
        input [7:0] dqs_idelay;
        input [7:0] dqs_odelay;
        input [7:0] dm_odelay;
        input [7:0] cmda_odelay;
        begin
           $display("SET DELAYS(0x%x,0x%x,0x%x,0x%x,0x%x,0x%x) @ %t",
           dq_idelay,dq_odelay,dqs_idelay,dqs_odelay,dm_odelay,cmda_odelay,$time);
            axi_set_dq_idelay(dq_idelay);
            axi_set_dq_odelay(dq_odelay);
            axi_set_dqs_idelay(dqs_idelay);
            axi_set_dqs_odelay(dqs_odelay);
            axi_set_dm_odelay(dm_odelay);
            axi_set_cmda_odelay(cmda_odelay);
        end
    endtask

    task axi_set_dqs_odelay_nominal; //SuppressThisWarning VEditor : may be unused
     begin
        $display("axi_set_dqs_odelay_nominal(0x%x,0x%x) @ %t",
        (DLY_LANE0_ODELAY >> (8<<3)) & 32'hff,
        (DLY_LANE1_ODELAY >> (8<<3)) & 32'hff,
        $time);
//        axi_set_dqs_idelay(
        write_contol_register(LD_DLY_LANE0_ODELAY + 8,      (DLY_LANE0_ODELAY >> (8<<3)) & 32'hff);
        write_contol_register(LD_DLY_LANE1_ODELAY + 8,      (DLY_LANE1_ODELAY >> (8<<3)) & 32'hff);
        write_contol_register(DLY_SET,0);
     end
    endtask

    task axi_set_dqs_idelay_nominal;  //SuppressThisWarning VEditor : may be unused
     begin
//        axi_set_dqs_idelay(
        write_contol_register(LD_DLY_LANE0_IDELAY + 8,      (DLY_LANE0_IDELAY >> (8<<3)) & 32'hff);
        write_contol_register(LD_DLY_LANE1_IDELAY + 8,      (DLY_LANE1_IDELAY >> (8<<3)) & 32'hff);
        write_contol_register(DLY_SET,0);
     end
    endtask
    
    task axi_set_dqs_idelay_wlv;  //SuppressThisWarning VEditor : may be unused
     begin
        write_contol_register(LD_DLY_LANE0_IDELAY + 8,      DLY_LANE0_DQS_WLV_IDELAY);
        write_contol_register(LD_DLY_LANE1_IDELAY + 8,      DLY_LANE1_DQS_WLV_IDELAY);
        write_contol_register(DLY_SET,0);
     end
    endtask

    task axi_set_delays; // set all individual delays
     integer i;
     begin
         $display("axi_set_delays @ %t",$time);
     
        for (i=0;i<10;i=i+1) begin
            write_contol_register(LD_DLY_LANE0_ODELAY + i,     (DLY_LANE0_ODELAY >> (i<<3)) & 32'hff);
        end
        for (i=0;i<9;i=i+1) begin
            write_contol_register(LD_DLY_LANE0_IDELAY + i,      (DLY_LANE0_IDELAY >> (i<<3)) & 32'hff);
        end
        for (i=0;i<10;i=i+1) begin
            write_contol_register(LD_DLY_LANE1_ODELAY + i,      (DLY_LANE1_ODELAY >> (i<<3)) & 32'hff);
        end
        for (i=0;i<9;i=i+1) begin
            write_contol_register(LD_DLY_LANE1_IDELAY + i,      (DLY_LANE1_IDELAY >> (i<<3)) & 32'hff);
        end
        for (i=0;i<32;i=i+1) begin
            write_contol_register(LD_DLY_CMDA + i,      (DLY_CMDA >> (i<<3)) & 32'hff);
        end
//        write_contol_register(DLY_SET,0);
        axi_set_phase(DLY_PHASE); // also sets all delays
     end
    endtask

    task axi_get_delays; // set all individual delays
     integer i;
     begin
         $display("axi_get_delays @ %t",$time);
     
        for (i=0;i<10;i=i+1) begin
            read_contol_register(LD_DLY_LANE0_ODELAY + i);
        end
        for (i=0;i<9;i=i+1) begin
            read_contol_register(LD_DLY_LANE0_IDELAY + i);
        end
        for (i=0;i<10;i=i+1) begin
            read_contol_register(LD_DLY_LANE1_ODELAY + i);
        end
        for (i=0;i<9;i=i+1) begin
            read_contol_register(LD_DLY_LANE1_IDELAY + i);
        end
        for (i=0;i<32;i=i+1) begin
            read_contol_register(LD_DLY_CMDA + i);
        end
        read_contol_register(LD_DLY_PHASE);
     end
    endtask


    task axi_set_dq_idelay; // sets same delay to all dq idelay
        input [7:0] delay;
        begin
           $display("SET DQ IDELAY=0x%x @ %t",delay,$time);
           axi_set_multiple_delays(LD_DLY_LANE0_IDELAY, 8, delay);
           axi_set_multiple_delays(LD_DLY_LANE1_IDELAY, 8, delay);
           write_contol_register(DLY_SET,0); // set all delays
        end
    endtask

    task axi_set_dq_odelay;
        input [7:0] delay;
        begin
           $display("SET DQ ODELAY=0x%x @ %t",delay,$time);
           axi_set_multiple_delays(LD_DLY_LANE0_ODELAY, 8, delay);
           axi_set_multiple_delays(LD_DLY_LANE1_ODELAY, 8, delay);
           write_contol_register(DLY_SET,0); // set all delays
        end
    endtask

    task axi_set_dqs_idelay;
        input [7:0] delay;
        begin
           $display("SET DQS IDELAY=0x%x @ %t",delay,$time);
           axi_set_multiple_delays(LD_DLY_LANE0_IDELAY + 8, 1, delay);
           axi_set_multiple_delays(LD_DLY_LANE1_IDELAY + 8, 1, delay);
           write_contol_register(DLY_SET,0); // set all delays
        end
    endtask

    task axi_set_dqs_odelay;
        input [7:0] delay;
        begin
           $display("SET DQS ODELAY=0x%x @ %t",delay,$time);
           axi_set_multiple_delays(LD_DLY_LANE0_ODELAY + 8, 1, delay);
           axi_set_multiple_delays(LD_DLY_LANE1_ODELAY + 8, 1, delay);
           write_contol_register(DLY_SET,0); // set all delays
        end
    endtask

    task axi_set_dm_odelay;
        input [7:0] delay;
        begin
           $display("SET DQM IDELAY=0x%x @ %t",delay,$time);
           axi_set_multiple_delays(LD_DLY_LANE0_ODELAY + 9, 1, delay);
           axi_set_multiple_delays(LD_DLY_LANE1_ODELAY + 9, 1, delay);
           write_contol_register(DLY_SET,0); // set all delays
        end
    endtask

    task axi_set_cmda_odelay;
        input [7:0] delay;
        begin
           $display("SET COMMAND and ADDRESS ODELAY=0x%x @ %t",delay,$time);
           axi_set_multiple_delays(LD_DLY_CMDA, 32, delay);
           write_contol_register(DLY_SET,0); // set all delays
        end
    endtask


    task axi_set_multiple_delays;
        input [29:0] reg_addr;
        input integer number;
        input [7:0]  delay;
        integer i;
        begin
           for (i=0;i<number;i=i+1) begin
                write_contol_register(reg_addr + i, {24'b0,delay}); // control regiter address
           end
        end
    endtask

    task axi_set_phase;
        input [PHASE_WIDTH-1:0] phase;
        begin
            $display("SET CLOCK PHASE to 0x%x @ %t",phase,$time);
            write_contol_register(LD_DLY_PHASE, {{(32-PHASE_WIDTH){1'b0}},phase}); // control regiter address
            write_contol_register(DLY_SET,0);
            target_phase <= phase;
        end
    endtask
 
     task axi_set_wbuf_delay;
        input [3:0] delay;
        begin
            $display("SET WBUF DELAY to 0x%x @ %t",delay,$time);
            write_contol_register(MCONTR_PHY_16BIT_ADDR+MCONTR_PHY_16BIT_WBUF_DELAY, {28'h0, delay});
        end
    endtask
 
 
// set dq /dqs tristate on/off patterns
    task axi_set_tristate_patterns;
        begin
            $display("SET TRISTATE PATTERNS @ %t",$time);    
            write_contol_register(MCONTR_PHY_16BIT_ADDR +MCONTR_PHY_16BIT_PATTERNS_TRI,
                {16'h0, DQSTRI_LAST, DQSTRI_FIRST, DQTRI_LAST, DQTRI_FIRST});
        end
    endtask

 task axi_set_dqs_dqm_patterns;
        begin
            $display("SET DQS+DQM PATTERNS @ %t",$time);    
 // set patterns for DM (always 0) and DQS - always the same (may try different for write lev.)        
            write_contol_register(MCONTR_PHY_16BIT_ADDR + MCONTR_PHY_16BIT_PATTERNS,
                32'h0055);
        end
 endtask
 
