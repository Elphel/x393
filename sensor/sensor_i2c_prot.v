/*******************************************************************************
 * Module: sensor_i2c_prot
 * Date:2015-10-05  
 * Author: andrey     
 * Description: Generate i2c R/W sequence from a 32-bit word and LUT
 *
 * Copyright (c) 2015 Elphel, Inc .
 * sensor_i2c_prot.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  sensor_i2c_prot.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  sensor_i2c_prot(
    input            mrst,         // @ posedge mclk
    input            mclk,         // global clock
    input            i2c_rst,
    input            i2c_start,
    input     [ 7:0] i2c_dly,      // bit duration-1 (>=2?), 1 unit - 4 mclk periods
    // setup LUT to translate address page into SA, actual address MSB and number of bytes to write (second word bypasses translation)
    input            tand,         // table address/not data
    input     [19:0] td,           // table address/data in            
    input            twe,          // table write enable
    input            sda_in,       // data from sda pad
    output reg       sda,
    output reg       sda_en,
    output reg       scl,
    output           i2c_run,
    output reg [1:0] seq_mem_ra, // number of byte to read from the sequencer memory
    output    [ 1:0] seq_mem_re, // [0] - re, [1] - regen to teh sequencer memory
    input     [ 7:0] seq_rd,     // data from the sequencer memory 
    output    [ 7:0] rdata,
    output           rvalid
);
    reg    [ 7:0] twa;
    wire   [31:0] tdout;
    reg    [ 7:0] reg_ah;   // MSB of the register address (instead of the byte 2)
    reg    [ 7:0] slave_a_rah;    // 8-bit slave address , used instead of the byte 3, later replaced with reg_ah
    reg    [ 3:0] num_bytes_send; // number of bytes to send (if more than 4 will skip stop and continue with next data
    reg    [ 3:0] bytes_left_send; // Number of bytes left in register write sequence (not counting sa?)
    reg    [ 6:0] run_reg_wr;      // run register write [6] - start, [5] - send sa, [4] - send high byte (from table),..[0] - send stop 
    reg    [ 4:0] run_extra_wr;    // continue register write (if more than sa + 4bytes) [4] - byte 3, .. [1]- byte0,  [0] - stop
    reg           run_extra_wr_d;  // any of run_extra_wr bits, delayed by 1
    reg    [ 7:0] run_reg_rd; // [7] - start, [6] SA (byte 3), [5] (optional) - RA_msb, [4] - RA_lsb, [3] - restart, [2] - SA, [1] - read bytes, [0] - stop
    reg           i2c_done;
    wire          i2c_next_byte;
    reg    [ 2:0] mem_re;
    reg           mem_valid;
    reg    [ 3:0] table_re;
    
    reg           read_mem_msb;
    wire          decode_reg_rd = &seq_rd[7:4];
    wire          start_wr_seq_w = !run_extra_wr_d && !decode_reg_rd && read_mem_msb;
    
    wire          snd_start_w = run_reg_wr[6] || 1'b0; // add start & restart of read
    wire          snd_stop_w =  run_reg_wr[0] || 1'b0; // add stop of read
    wire          snd9_w     =  (|run_reg_wr[5:1]) || 1'b0; // add for read and extra write;

    reg           snd_start;
    reg           snd_stop;
    reg           snd9;
    // the following signals are mutually exclusive, can be encoded to 2 bits. Invaluid during next_cmd_d
    reg           send_seq_data; // including first SA for read
    reg           send_rd_sa;    // from the table
    reg           send_sa_rah;   // send slave address/ high address from the table
    reg           send_rd;       // send 1fe/1ff to read data
    reg     [6:0] rd_sa;         // 7-bit slave address for reading
    wire    [1:0] sel_sr_in = { // select source for the shift register
                  send_sa_rah | send_rd,
                  send_rd_sa | send_rd};
    reg     [8:0] sr_in; // input data for the shift register
   
    
    

    wire          i2c_rdy;
    reg           next_cmd; // i2c command (start/stop/data) accepted, proceed to the next stage
    reg           next_cmd_d; // next cycle after next_cmd (first at new state)
    wire          pre_next_cmd = (snd_start || snd_stop || snd9) && i2c_rdy;
    reg           next_byte_wr;
    
    reg           read_address_bytes; // 0 - single-byte register adderss, 1 - two-byte register address
    reg    [ 2:0] read_data_bytes;    // 1..8 bytes to read from teh i2c slave (0 is 8!)
    
    reg    [ 1:0] initial_address; // initial data byte to read: usually 3  but for extra write may be different
    wire   [ 3:0] initial_address_w =  bytes_left_send - 1; // if bytes left to send == 0 - will be 3                      
    wire          unused;            // unused ackn signal  
    assign seq_mem_re = mem_re[1:0];
    
    always @ (posedge mclk) begin
        run_extra_wr_d <= |run_extra_wr;
        read_mem_msb <= mem_re[1] && (seq_mem_ra == 3); // reading sequencer data MSB - change to other one-hot?
        
        table_re <= {table_re[2:0], start_wr_seq_w};
        
        if (table_re[2]) begin
            reg_ah <=         tdout[7:0];   // MSB of the register address (instead of the byte 2)
            num_bytes_send <= tdout[19:16]; // number of bytes to send (if more than 4 will skip stop and continue with next data
        end
        if      (table_re[2])               slave_a_rah <= {tdout[14:8], 1'b0};
        else if (next_cmd && run_reg_wr[6]) slave_a_rah <= reg_ah; // will copy even if not used
        
        next_cmd <= pre_next_cmd;
        
        next_cmd_d <= next_cmd;
        
        next_byte_wr <= snd9 && i2c_rdy; // same time as next_cmd

        snd_start <= snd_start_w; // add & i2c_ready? Not really needed as any i2c stage will be busy for long enough
        snd_stop <=  snd_stop_w;
        snd9 <=      snd9_w;
        
        if     (mrst || i2c_rst) bytes_left_send <= 0;
        else if (start_wr_seq_w) bytes_left_send <= num_bytes_send;
        else if (next_byte_wr)   bytes_left_send <= bytes_left_send - 1;

        // calculate stages for each type of commands
        // start and write sa and some bytes, stop if number of bytes <= 4 at teh end        
        if      (mrst || i2c_rst) run_reg_wr <= 0;
        else if (start_wr_seq_w)  run_reg_wr <= 7'h40;
        else if (next_cmd)        run_reg_wr <= {1'b0,         // first "start"
                                                run_reg_wr[6], // slave_addr - always after start
                                                run_reg_wr[5] & (|num_bytes_send[3:2]), // MSB (from the table)
                                                run_reg_wr[4] | (run_reg_wr[5] & (num_bytes_send == 4'h3)), // byte 2 (from input)
                                                run_reg_wr[3] | (run_reg_wr[5] & (num_bytes_send == 4'h2)), // byte 1 (from input)
                                                run_reg_wr[2] | (run_reg_wr[5] & (num_bytes_send == 4'h1)), // byte 0 (from input)
                                                run_reg_wr[1] & (bytes_left_send == 4'h1)
                                                };
        // send just bytes (up to 4), stop if nothing left 
        if      (mrst || i2c_rst)                    run_extra_wr <= 0;
        else if (i2c_start && (bytes_left_send !=0)) run_extra_wr <= {
                                                        |bytes_left_send[3:2], // >= 4 bytes left
                                                        (bytes_left_send == 3), // exactly 3 bytes left
                                                        (bytes_left_send == 2), // exactly 2 bytes left
                                                        (bytes_left_send == 1), // exactly 1 bytes left (zero should never be left)
                                                        1'b0
                                                     };
        else if (next_cmd)                          run_extra_wr <= {
                                                        1'b0,
                                                        run_extra_wr[4],
                                                        run_extra_wr[3],
                                                        run_extra_wr[2],
                                                        run_extra_wr[1] & (bytes_left_send == 4'h1)
                                                     };

//     reg    [ 7:0] run_reg_rd; // [7] - start, [6] SA (byte 3), [5] (optional) - RA_msb, [4] - RA_lsb, [3] - restart, [2] - SA, [1] - read bytes, [0] - stop

        if (!run_extra_wr &&  decode_reg_rd && read_mem_msb) read_address_bytes <= seq_rd[3];
        
        if (!run_extra_wr &&  decode_reg_rd && read_mem_msb) read_data_bytes <= seq_rd[2:0];
        else if (run_reg_rd[1] && next_cmd)                  read_data_bytes <= read_data_bytes - 1;
        // read i2c data
        if      (mrst || i2c_rst)                                  run_reg_rd <= 0;
        else if (!run_extra_wr_d &&  decode_reg_rd && read_mem_msb)  run_reg_rd <= 8'h80;
        else if (next_cmd)        run_reg_rd <= {1'b0,         // first "start"
                                                run_reg_rd[7], // slave_addr - always after start (bit0 = 0)
                                                run_reg_rd[6] & read_address_bytes, // optional MSB of the register address
                                                run_reg_rd[5] | (run_reg_rd[6] & ~read_address_bytes), // LSB of the register address
                                                run_reg_rd[4], // restart
                                                run_reg_rd[3], // send slave address with 1 in bit[0]
                                                run_reg_rd[2] | (run_reg_rd[1] & (read_data_bytes != 3'h1)), // repeat reading bytes
                                                run_reg_rd[1] & (read_data_bytes == 3'h1)
                                                };
        // read sequencer memory byte (for the current word)
        mem_re <= {mem_re[1:0], i2c_start | next_cmd_d & (
                               (|run_reg_wr[3:1]) |
                               (|run_extra_wr[4:1]) |
                               (|run_reg_rd[6:4]))};
        initial_address <=  initial_address_w[1:0]; // if bytes left to send is 0 mod 4 - will be 3 (read MSB)
        seq_mem_ra <= i2c_start ? initial_address : { // run_extra_wr[4] is not needed - it will be read by i2c_start
                                                       run_reg_wr[3] | run_extra_wr[3] | run_reg_rd[6],
                                                       run_reg_wr[2] | run_extra_wr[2] | run_reg_rd[5]
                                                    };
        if (mrst || i2c_rst || i2c_start || next_cmd ) mem_valid <= 0;
        else if (mem_re[2])                            mem_valid <= 1;
        
        // calculate snd9 and delay it if waiting for memory using mem_valid, set din[8:0] 
        if (run_reg_rd[6] && mem_re[2]) rd_sa <= seq_rd[7:1]; // store sa to use with read
        
        send_seq_data <= !next_cmd && mem_valid && ((|run_reg_wr[3:1]) || (|run_extra_wr[4:1]) || (|run_reg_rd[6:4])); 
        send_rd_sa <=    !next_cmd && run_reg_rd[2];
        send_sa_rah <=   !next_cmd && (|run_reg_wr[6:5]);
        send_rd <=       !next_cmd && run_reg_rd[1];
        
        if (mrst || i2c_rst) snd9 <= 0;
        else snd9 <= snd9 ? (!i2c_rdy) : ((send_seq_data || send_rd_sa || send_sa_rah || send_rd) && !next_cmd);
        case (sel_sr_in)
            2'h0: sr_in <= {seq_rd, 1'b1};
            2'h1: sr_in <= {rd_sa, 2'b11};
            2'h2: sr_in <= {slave_a_rah, 1'b1};
            2'h3: sr_in <= {8'hff,(read_data_bytes == 3'h1)}; 
        endcase
        
    end    

    sensor_i2c_scl_sda sensor_i2c_scl_sda_i (
        .mrst      (mrst),          // input
        .mclk      (mclk),          // input
        .i2c_rst   (i2c_rst),       // input
        .i2c_dly   (i2c_dly),       // input[7:0] 
        .snd_start (snd_start),     // input
        .snd_stop  (snd_stop),      // input
        .snd9      (snd9),          // input
        .din       (sr_in),         // input[8:0] 
        .dout      ({rdata,unused}),// output[8:0] 
        .dout_stb  (rvalid),        // output reg 
        .scl       (), // output reg 
        .sda_in    (sda_in),        // input
        .sda       (), // output reg 
        .ready     (i2c_rdy),       // output register
        .bus_busy  (), // output reg 
        .is_open   () // output
    );
     
     
    // table write  
    always @ (posedge mclk) begin
        if      (mrst) twa <= 0;
        else if (twe)  twa <= tand ? td[7:0] : (twa + 1);  
    end
    
    ram18_var_w_var_r #(
        .REGISTERS    (1),
        .LOG2WIDTH_WR (5),
        .LOG2WIDTH_RD (5),
        .DUMMY        (0)
    ) ram18_var_w_var_r_i (
        .rclk        (mclk), // input
        .raddr       ({1'b0, seq_rd}), // input[8:0] 
        .ren         (table_re[0]), // input
        .regen       (table_re[1]), // input
        .data_out    (tdout), // output[31:0] 
        .wclk        (mclk), // input
        .waddr       ({1'b0, twa}), // input[8:0] 
        .we          (twe && !tand), // input
        .web         (4'hf), // input[3:0] 
        .data_in     ({12'b0, td}) // input[31:0] 
    );


endmodule

