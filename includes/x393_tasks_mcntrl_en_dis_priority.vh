 /*******************************************************************************
 * File: x393_tasks_mcntrl_en_dis_priority.vh
 * Date:2015-02-07  
 * Author: andrey     
 * Description: Simulation tasks for software reading/writing (with test patterns)
 * of the block buffers.
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * x393_tasks_mcntrl_en_dis_priority.vh is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * x393_tasks_mcntrl_en_dis_priority.vh is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
task enable_cmda;
   input en;
   begin
        write_contol_register(MCONTR_PHY_0BIT_ADDR +  MCONTR_PHY_0BIT_CMDA_EN + en, 0);
   end
endtask

task enable_cke;
    input en;
    begin
        write_contol_register(MCONTR_PHY_0BIT_ADDR +  MCONTR_PHY_0BIT_CKE_EN + en, 0);
    end
endtask

task activate_sdrst;
    input en;
    begin
        write_contol_register(MCONTR_PHY_0BIT_ADDR +  MCONTR_PHY_0BIT_SDRST_ACT + en, 0);
    end
endtask

task enable_refresh;
    input en;
    begin
        write_contol_register(MCONTR_TOP_0BIT_ADDR +  MCONTR_TOP_0BIT_REFRESH_EN + en, 0);
    end
endtask

task enable_memcntrl;
    input en;
    begin
        write_contol_register(MCONTR_TOP_0BIT_ADDR +  MCONTR_TOP_0BIT_MCONTR_EN + en, 0);
    end
endtask

task enable_memcntrl_channels;
    input [15:0] chnen; // bit-per-channel, 1 - enable;
    begin
        write_contol_register(MCONTR_TOP_16BIT_ADDR +  MCONTR_TOP_16BIT_CHN_EN, {16'b0,chnen});
    end
endtask

task configure_channel_priority;
    input [ 3:0] chn;
    input [15:0] priority; // (higher is more important)
    begin
        write_contol_register(MCONTR_ARBIT_ADDR + chn, {16'b0,priority});
    end
endtask
