/*******************************************************************************
 * Module: scheduler16
 * Date:2015-01-09  
 * Author: andrey     
 * Description: 16-channel programmable DDR memory access scheduler
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * scheduler16.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  scheduler16.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  scheduler16 #(
    parameter width=16
)(
    input             rst,
    input             clk,
    input      [15:0] want_rq,   // both want_rq and need_rq should go inactive after being granted  
    input      [15:0] need_rq,
    input             en_sch,    // needs to be disabled before next access can be scheduled
    output            need,      // granted access is "needed" one, not just "wanted"
    output            grant,     // single-cycle granted channel access
    output      [3:0] grant_chn, // granted  channel number, valid with grant, stays valid until en_sch is deasserted
    // todo: add programming  sequencer address for software sequencer program? Or should it come from the channel?
    input       [3:0] pgm_addr,  // channel address to program priority
    input [width-1:0] pgm_data,  // priority data for the channel
    input             pgm_en     // enable programming priority data (use different clock?)
);
//    reg [width-1:0] pri00,pri01,pri02,pri03,pri04,pri05,pri06,pri07,pri08,pri09,pri10,pri11,pri12,pri13,pri14,pri15;
    reg [width*16-1:0] pri_reg;
    reg [15:0] want_conf, need_conf,need_want_conf;
//    wire new_want,new_need;
//    wire event_w;
    wire [15:0] want_set,need_set;
    reg [15:0] want_set_r,need_set_r;
//    reg event_r, want_r;
    reg need_r;
    reg [width*16-1:0] sched_state;
    wire need_some=| need_rq;
//    wire want_some=| want_rq;
    wire [15:0] next_want_conf,next_need_conf;
    wire [3:0] index; // channel index to select
    wire index_valid; // selected index valid ("needed" or "wanted")
    reg grant_r;      // 1 cycle long
    reg grant_sent; // turns on after grant, until en_sch is de-asserted
    reg [3:0] grant_chn_r;
    wire grant_w;
//    assign event_w=new_want | new_need;
    assign next_want_conf=(want_conf &  want_rq) | want_set;
    assign next_need_conf=(need_conf &  need_rq) | need_set;
    assign grant=grant_r;
    assign grant_chn=grant_chn_r;
    assign grant_w=en_sch && index_valid && !grant_sent;
    generate
        genvar i;
        for (i=0;i<16;i=i+1) begin: pri_reg_block
            always @ (posedge rst or posedge clk) begin
                if (rst) pri_reg[width*i +: width] <= 0;
                else if (pgm_en && (pgm_addr==i)) pri_reg[width*i +: width] <= pgm_data; 
            end
        end
    endgenerate        

    pri1hot16 i_pri1hot16_want(
        .in(want_rq & ~want_conf ),
        .out(want_set),
        .some());
//        .some(new_want));
    pri1hot16 i_pri1hot16_need(
        .in(need_rq & ~need_conf ),
        .out(need_set),
        .some());
//        .some(new_need));
        
    always @(posedge rst or posedge clk) begin
        if (rst) begin
            want_conf <= 0;
            need_conf <= 0;
        end else begin
            want_conf <= next_want_conf;
            need_conf <= next_need_conf;
            need_want_conf<= need_some? next_need_conf: next_want_conf; 
        end
    end
    always @ (posedge clk) begin
        want_set_r<=want_set;
        need_set_r<=need_set;
        //event_r <= event_w;
        //want_r<= want_some;
        need_r<= need_some;
    end
    // TODO: want remains, need is removed (both need and want should be deactivated on grant!)
    // Block that sets initila process state and increments it on every change of the requests
    generate
        genvar i1;
        for (i1=0;i1<16;i1=i1+1) begin: sched_state_block
            always @ (posedge rst or posedge clk) begin
                if (rst) pri_reg[width*i1 +: width] <= 0; // not needed?
                else begin
                    if (want_set_r[i1] || need_set_r[i1])  sched_state[width*i1 +: width] <= pri_reg[width*i1 +: width];
                    // increment, but do not roll over
                    else if (&sched_state[width*i1 +: width] == 0) sched_state[width*i1 +: width]<=sched_state[width*i1 +: width]+1; 
                end 
            end
        end
    endgenerate
    // Select the process to run
    index_max_16 #(width) i_index_max_16(
        .clk(clk),
        .values(sched_state),
        .mask(need_want_conf),
        .need_in(need_r),
        .index(index[3:0]),
        .valid(index_valid),
        .need_out(need));
    always @(posedge rst or posedge clk) begin
        if (rst) begin
            grant_r <=0;
            grant_sent <=0;
            grant_chn_r <=0;
        end else begin
            grant_r    <= grant_w; // en_sch && index_valid && !grant_sent;
            grant_sent <= (grant_sent && en_sch) || grant_r;
            if (grant_w) grant_chn_r <= index[3:0];   
        end
    end

endmodule

