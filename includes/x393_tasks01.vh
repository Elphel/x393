 /*******************************************************************************
 * File: x393_tasks01.vh
 * Date:2015-02-07  
 * Author: Andrey Filippov     
 * Description: Simulation tasks for the x393 (low level)
 *
 * Copyright (c) 2015 Elphel, Inc.
 * x393_tasks01.vh is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * x393_tasks01.vh is distributed in the hope that it will be useful,
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
 // Low-level tasks 
// alternative way to check for empty read queue (without a separate counter)

    task   write_contol_register;
        input [29:0] reg_addr;
//        input integer reg_addr;
        input [31:0] data;
        begin
            axi_write_single_w(CONTROL_ADDR+reg_addr, data);
        end
    endtask   

    task   read_contol_register;
        input [29:0] reg_addr;
        begin
            read_and_wait_w(CONTROL_RBACK_ADDR+reg_addr);
        end
    endtask   

    task wait_read_queue_empty;
        begin
        wait (~rvalid && rready && (rid==LAST_ARID)); // nothing left in read queue?   
        SIMUL_AXI_FULL<=1'b0;
        end
    endtask
    task axi_set_rd_lag;
        input [3:0] lag;
        begin
            @(posedge CLK);
            RD_LAG <= lag;
        end
    endtask

    task axi_set_b_lag;
        input [3:0] lag;
        begin
            @(posedge CLK);
            B_LAG <= lag;
        end
    endtask

    task read_and_wait_w;
    input [29:0] address;
        begin
            read_and_wait ({address,2'b0});
        end
    endtask

    task read_and_wait;
    input [31:0] address;
    begin
        axi_read_addr(
            GLOBAL_READ_ID,    // id
            address & 32'hfffffffc, // addr
            4'h0, // len - single
            1     // burst type - increment
            );
        GLOBAL_READ_ID <= GLOBAL_READ_ID+1;
        wait (!CLK && rvalid && rready);
        wait (CLK);
        registered_rdata <= rdata;
        wait (!CLK); // registered_rdata should be valid on exit
        
    end
    endtask
    
    task axi_write_single_w; // address in bytes, not words
        input [29:0] address;
        input [31:0] data;
        begin
`ifdef DEBUG_WR_SINGLE
          $display("axi_write_single_w %h:%h @ %t",address,data,$time);
`endif                
            axi_write_single ({address,2'b0},data);
        end
    endtask

    task axi_write_single; // address in bytes, not words
        input [31:0] address;
        input [31:0] data;
        begin
          axi_write_addr_data(
                    GLOBAL_WRITE_ID,    // id
//                    address << 2, // addr
                    address & 32'hfffffffc, // addr
                    data,
                    4'h0, // len - single
                    1,    // burst type - increment
                    1'b1, // data_en
                    4'hf, // wstrb
                    1'b1 // last
                );
          GLOBAL_WRITE_ID <= GLOBAL_WRITE_ID+1;
          #0.1; // without this delay axi_write_addr_data() used old value of GLOBAL_WRITE_ID
        end
    endtask
   
    task axi_write_addr_data;
        input [11:0] id;
        input [31:0] addr;
        input [31:0] data;
        input [ 3:0] len;
        input [ 1:0] burst;
        input        data_en; // if 0 - do not send data, only address
        input [ 3:0] wstrb;
        input        last;
        reg          data_sent;
//        wire         data_sent_d;
//        assign #(.1) data_sent_d= data_sent;
        begin
            wait (!CLK && AW_READY);
            AWID_IN_r    <= id;
            AWADDR_IN_r  <= addr;
            AWLEN_IN_r   <= len;
            AWSIZE_IN_r  <= 3'b010;
            AWBURST_IN_r <= burst;
            AW_SET_CMD_r <= 1'b1;
            if (data_en && W_READY) begin
                WID_IN_r <= id;
                WDATA_IN_r <= data;
                WSTRB_IN_r <= wstrb;
                WLAST_IN_r <= last;
                W_SET_CMD_r <= 1'b1; 
                data_sent <= 1'b1;
            end else begin
                data_sent <= 1'b0;
            end
            DEBUG1 <=1'b1;
            wait (CLK);
            DEBUG1 <=1'b0;
            AWID_IN_r    <= 'hz;
            AWADDR_IN_r  <= 'hz;
            AWLEN_IN_r   <= 'hz;
            AWSIZE_IN_r  <= 'hz;
            AWBURST_IN_r <= 'hz;
            AW_SET_CMD_r <= 1'b0;
            DEBUG2 <=1'b1;
            if (data_sent) begin
                WID_IN_r    <= 'hz;
                WDATA_IN_r  <= 'hz;
                WSTRB_IN_r  <= 'hz;
                WLAST_IN_r  <= 'hz;
                W_SET_CMD_r <= 1'b0; 
            end
// Now sent data if it was not sent simultaneously with the address
            if (data_en && !data_sent) begin
                DEBUG3 <=1'b1;
                wait (!CLK && W_READY);
                DEBUG3 <=1'b0;
                WID_IN_r    <= id;
                WDATA_IN_r  <= data;
                WSTRB_IN_r  <= wstrb;
                WLAST_IN_r  <= last;
                W_SET_CMD_r <= 1'b1; 
                wait (CLK);
                DEBUG3 <=1'bx;
                WID_IN_r    <= 'hz;
                WDATA_IN_r  <= 'hz;
                WSTRB_IN_r  <= 'hz;
                WLAST_IN_r  <= 'hz;
                W_SET_CMD_r <= 1'b0; 
            end
            DEBUG2 <=1'b0;
            #0.1;
            data_sent <= 1'b0;
            #0.1;
        end
    endtask

    task axi_write_data;
        input [11:0] id;
        input [31:0] data;
        input [ 3:0] wstrb;
        input        last;
        begin
            wait (!CLK && W_READY);
            WID_IN_r    <= id;
            WDATA_IN_r  <= data;
            WSTRB_IN_r  <= wstrb;
            WLAST_IN_r  <= last;
            W_SET_CMD_r <= 1'b1; 
            wait (CLK);
            WID_IN_r    <= 12'hz;
            WDATA_IN_r  <= 'hz;
            WSTRB_IN_r  <= 4'hz;
            WLAST_IN_r  <= 1'bz;
            W_SET_CMD_r <= 1'b0;
            #0.1;
        end
    endtask

    task axi_read_addr;
        input [11:0] id;
        input [31:0] addr;
        input [ 3:0] len;
        input [ 1:0] burst;
        begin
            wait (!CLK && AR_READY);
            ARID_IN_r    <= id;
            ARADDR_IN_r  <= addr;
            ARLEN_IN_r   <= len;
            ARSIZE_IN_r  <= 3'b010;
            ARBURST_IN_r <= burst;
            AR_SET_CMD_r <= 1'b1;
            wait (CLK);
            ARID_IN_r    <= 12'hz;
            ARADDR_IN_r  <= 'hz;
            ARLEN_IN_r   <= 4'hz;
            ARSIZE_IN_r  <= 3'hz;
            ARBURST_IN_r <= 2'hz;
            AR_SET_CMD_r <= 1'b0;
            LAST_ARID <= id;
            NUM_WORDS_EXPECTED <= NUM_WORDS_EXPECTED+len+1;
        end
    endtask

