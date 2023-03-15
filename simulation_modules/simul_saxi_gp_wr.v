/*!
 * <b>Module:</b>simul_saxi_gp_wr
 * @file simul_saxi_gp_wr.v
 * @date 2015-08-04  
 * @author Andrey Filippov     
 *
 * @brief Simplified model of AXI_GP write channel
 *
 * @copyright Copyright (c) 2015 Elphel, Inc.
 *
 * <b>License:</b>
 *
 * simul_saxi_gp_wr.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  simul_saxi_gp_wr.v is distributed in the hope that it will be useful,
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
 */
`timescale 1ns/1ps

module  simul_saxi_gp_wr(
    input         rst,
    // AXI signals
    input         aclk,
    output        aresetn, // do not use?
    // write address
    input  [31:0] awaddr,
    input         awvalid,
    output        awready,
    input  [ 5:0] awid,
    input  [ 1:0] awlock,   // verify the correct values are here
    input  [ 3:0] awcache,  // verify the correct values are here
    input  [ 2:0] awprot,   // verify the correct values are here
    input  [ 3:0] awlen,
    input  [ 1:0] awsize,
    input  [ 1:0] awburst,
    input  [ 3:0] awqos,    // verify the correct values are here
    // write data
    input  [31:0] wdata,
    input         wvalid,
    output        wready,
    input  [ 5:0] wid,
    input         wlast,
    input  [ 3:0] wstrb,
    // write response
    output        bvalid,
    input         bready,
    output [ 5:0] bid,
    output [ 1:0] bresp,
    
    // Simulation signals - use same aclk
    output [31:0] sim_wr_address,
    output [ 5:0] sim_wid,
    output        sim_wr_valid, // ready to provide simulation data
    input         sim_wr_ready, // simulation may pause this channel by keeping this signal inactive
    output [31:0] sim_wr_data,
    output [ 3:0] sim_wr_stb,
    output [ 1:0] sim_wr_size,    
    input  [ 3:0] sim_bresp_latency, // latency in writing data outside of the module 
    output [ 3:0] sim_wr_qos
);
    // TODO change these localparam to parameters
    localparam AW_FIFO_DEPTH = 2; // 7; //3;                 // FIFO number of address bits to fit AW_FIFO_NUM (number is one bit wider)
    localparam W_FIFO_DEPTH = 3; // 2; // 7; //3;                  //  FIFO number of address bits to fit W_FIFO_NUM
    localparam WREADY_DELAY_AFTER_LAST = 3; // negate wready for these number of clocks after wlast (0..7)
    
    
    localparam [AW_FIFO_DEPTH:0] AW_FIFO_NUM = 1 << AW_FIFO_DEPTH; // 128; // 8; // Maximal number of words in AW FIFO 8-words
    localparam  [W_FIFO_DEPTH:0] W_FIFO_NUM =  1 << W_FIFO_DEPTH; // 8;  // Maximal number of words in AW 8-words
    
    
    localparam VALID_AWLOCK =  2'b0; // TODO
    localparam VALID_AWCACHE = 4'b0011; //
    localparam VALID_AWPROT =  3'b000;
    localparam VALID_AWLOCK_MASK =  2'b11; // TODO
    localparam VALID_AWCACHE_MASK = 4'b0011; //
    localparam VALID_AWPROT_MASK =  3'b010;
/*
http://forums.xilinx.com/t5/Embedded-Processor-System-Design/Accessing-DDR-from-PL-on-Zynq/m-p/324877#M8413
Solved it!
To make it work, I set the (AR/AW)CACHE=0x11 and (AR/AW)PROT=0x00. In the CDMA datasheet, these were the recommended values, which I confirmed with ChipScope, when attached to CDMA's master port.
The default values set by VHLS were 0x00 and 0x10 respectively, which is also the case in the last post.
Alex
*/    
    reg  [WREADY_DELAY_AFTER_LAST : 0]  wlast_d = 0; // [3:0] extra bit, but should work with WREADY_DELAY_AFTER_LAST == 0
    wire        wlast_nready; 
    wire        aw_nempty;
    wire        w_nempty;
    reg  [11:0] next_wr_address_w; // bits that are incremented in 32-bit mode (higher are kept according to AXI 4KB inc. limit)
    reg  [31:0] write_address;
    wire        fifo_wd_rd; // read data fifo
    wire        last_confirmed_write;


    wire  [5:0] awid_out; // verify it matches wid_out when outputting data
    wire  [1:0] awburst_out;
    wire  [1:0] awsize_out;
    wire  [3:0] awlen_out;
    wire [31:0] awaddr_out;
    wire  [5:0] wid_out;
    wire        wlast_out;
    wire  [3:0] wstrb_out;
    wire [31:0] wdata_out;

    reg         fifo_data_we_d;
    reg         fifo_addr_we_d;
    reg   [3:0] write_left;
    reg  [ 1:0] wburst;             // registered burst type
    reg  [ 3:0] wlen;               // registered awlen type (for wrapped over transfers)
    reg  [ 1:0] wsize;
    wire        start_write_burst_w;
    wire        write_in_progress_w; // should go inactive last confirmed upstream cycle
    reg         write_in_progress;
    reg  [ 7:0] num_full_data = 0; // Number of full data bursts in FIFO

    wire  [5:0] wresp_num_in_fifo;
    reg         was_wresp_re=0;
    wire        wresp_re;

    wire [AW_FIFO_DEPTH:0] wacount;
    wire [W_FIFO_DEPTH:0]  wcount;

        
    // documentation sais : "When set, allows the priority of a transaction at the head of the WrCmdQ to be promoted if higher
    // priority transactions are backed up behind it." Whqt about demotion? Assuming it is not demoted
    assign aresetn= ~rst; // probably not needed at all - docs say "do not use"

    assign wlast_nready = (((1 << WREADY_DELAY_AFTER_LAST) -1) & wlast_d) != 0;
    // generate ready signals for address and data
//    assign wready= !wcount[7] && (!(&wcount[6:0]) || !fifo_data_we_d);
    assign wready =  ((wcount <  W_FIFO_NUM)  && ((wcount  <  (W_FIFO_NUM-1)) || !fifo_data_we_d)) && !wlast_nready;
    
    always @ (posedge rst or posedge aclk) begin
        if (rst) wlast_d<=0;
        else wlast_d <= (wlast_d << 1) | {{WREADY_DELAY_AFTER_LAST{1'b0}}, (wlast & wready & wvalid)};
    end
    
    
    
    always @ (posedge rst or posedge aclk) begin
        if (rst) fifo_data_we_d<=0;
        else fifo_data_we_d <= wready && wvalid;
    end
//    assign awready= !wacount[5] && (!(&wacount[4:0]) || !fifo_addr_we_d);
    assign awready = (wacount < AW_FIFO_NUM) && ((wacount < (AW_FIFO_NUM-1)) || !fifo_addr_we_d);
    always @ (posedge rst or posedge aclk) begin
        if (rst) fifo_addr_we_d<=0;
        else fifo_addr_we_d <= awready && awvalid;
    end
    
    // Count full data bursts ready in FIFO
    always @ (posedge rst or posedge aclk) begin
        if (rst) num_full_data <=0;
        else if (wvalid && wready && wlast     && !start_write_burst_w) num_full_data <= num_full_data + 1;
        else if (!(wvalid && wready && wlast)  &&  start_write_burst_w) num_full_data <= num_full_data - 1;
    end
    
    
    assign sim_wr_address= write_address;
    assign fifo_wd_rd=   write_in_progress && w_nempty && sim_wr_ready;
    assign sim_wr_valid= write_in_progress && w_nempty; // for continuing writes
    assign last_confirmed_write = (write_left==0) && fifo_wd_rd && wlast_out; // wlast_out should take precedence over write_left?
    assign start_write_burst_w= 
        aw_nempty && w_nempty &&
        (! write_in_progress || last_confirmed_write);

    assign write_in_progress_w= 
        (aw_nempty && w_nempty) || (write_in_progress && !last_confirmed_write); 

    // AXI: Bursts should not cross 4KB boundaries (... and to limit size of the address incrementer)
    // in 64 bit mode - low 3 bits are preserved, next 9 are incremented 
    always @* begin
        case (wburst)
            2'h0: next_wr_address_w[11:0] <= write_address[11:0];
            2'h1: next_wr_address_w[11:0] <= write_address[11:0] + (1 << wsize);
            2'h2:   case (wsize)
                        2'h3:  begin
                                   next_wr_address_w[11:3] <= (write_address[11:3] + 1) & {5'h1f, ~wlen[3:0]};
                                   next_wr_address_w[ 2:0] <= write_address[2:0]; 
                               end
                        2'h2:  begin
                                   next_wr_address_w[11:2] <= (write_address[11:2] + 1) & {6'h3f, ~wlen[3:0]};
                                   next_wr_address_w[ 1:0] <=  write_address[1:0]; 
                               end 
                        2'h1:  begin
                                   next_wr_address_w[11:1] <= (write_address[11:1] + 1) & {7'h7f, ~wlen[3:0]};
                                   next_wr_address_w[0:0]    <= write_address[0:0];
                               end  
                        2'h0:  begin
                                next_wr_address_w[11:0] <=  (write_address[11:0] + 1) & {8'hff, ~wlen[3:0]}; 
                               end 
                    endcase
            2'h3: next_wr_address_w[11:0] <= 12'bx;          
        endcase
    end
    wire  [3:0] sim_wr_mask =  (awsize_out == 0)? 4'h1 : ((awsize_out == 1)? 4'h3 : 4'hf);
    assign sim_wr_data= wdata_out; 
    assign sim_wid= wid_out;    
    assign sim_wr_stb=wstrb_out & sim_wr_mask; // limit by data size
    assign sim_wr_size = awsize_out;
    
    always @ (posedge  aclk) begin
        if (start_write_burst_w) begin
            if (awid_out != wid_out) begin
                $display ("%m: at time %t ERROR: awid=%h, wid=%h",$time,awid_out,wid_out);
                $stop;
            end
    
        end
        if (awvalid && awready) begin
            if (((awlock ^ VALID_AWLOCK) & VALID_AWLOCK_MASK) != 0) begin
                $display ("%m: at time %t ERROR: awlock = %h, valid %h with mask %h",$time, awlock, VALID_AWLOCK, VALID_AWLOCK_MASK);
                $stop;
            end
            if (((awcache ^ VALID_AWCACHE) & VALID_AWCACHE_MASK) != 0) begin
                $display ("%m: at time %t ERROR: awcache = %h, valid %h with mask %h",$time, awcache, VALID_AWCACHE, VALID_AWCACHE_MASK);
                $stop;
            end
            if (((awprot ^ VALID_AWPROT) & VALID_AWPROT_MASK) != 0) begin
                $display ("%m: at time %t ERROR: awprot = %h, valid %h with mask %h",$time, awprot, VALID_AWPROT, VALID_AWPROT_MASK);
                $stop;
            end
        end
    end
    
    
        
    always @ (posedge  aclk or posedge  rst) begin
      if   (rst)                    wburst[1:0] <= 0;
      else if (start_write_burst_w) wburst[1:0] <= awburst_out[1:0];

      if   (rst)                    wlen[3:0] <= 0;
      else if (start_write_burst_w) wlen[3:0] <= awlen_out[3:0];
      
      if   (rst)                    wsize[1:0] <= 0;
      else if (start_write_burst_w) wsize[1:0] <= awsize_out[1:0];
      
    
      if   (rst) write_in_progress <= 0;
      else       write_in_progress <= write_in_progress_w;

      if   (rst) write_left <= 0;
      else if (start_write_burst_w) write_left <= awlen_out[3:0]; // precedence over inc
      else if (fifo_wd_rd)           write_left <= write_left-1; //SuppressThisWarning ISExst Result of 32-bit expression is truncated to fit in 4-bit target.
            
      if   (rst)                    write_address <= 32'bx;
      else if (start_write_burst_w) write_address <= awaddr_out; // precedence over inc
      else if (fifo_wd_rd)          write_address <= {write_address[31:12],next_wr_address_w[11:0]};
      
    end
//    localparam AW_FIFO_NUM = 8; // Maximal number of words in AW FIFO 8-words
//    localparam W_FIFO_NUM = 8; // Maximal number of words in AW 8-words
        
    
fifo_same_clock_fill   #( .DATA_WIDTH(50),.DATA_DEPTH(AW_FIFO_DEPTH)) // read - 4, write - 32?
    waddr_i (
        .rst          (rst),
        .clk          (aclk),
        .sync_rst     (1'b0),
        .we           (awvalid && awready),
        .re           (start_write_burst_w),
        .data_in      ({awid[5:0],     awburst[1:0],    awsize[1:0],    awlen[3:0],    awaddr[31:0],     awqos[3:0]}),
        .data_out     ({awid_out[5:0], awburst_out[1:0],awsize_out[1:0],awlen_out[3:0],awaddr_out[31:0], sim_wr_qos[3:0]}),
        .nempty       (aw_nempty), // output
        .half_full    (),        // aw_half_full),
        .under        (),        // waddr_under),  // output reg 
        .over         (),        // waddr_over),   // output reg
        .wcount       (),        // waddr_wcount), // output[3:0] reg 
        .rcount       (),        // waddr_rcount), // output[3:0] reg 
        .wnum_in_fifo (wacount), // output[3:0] 
        .rnum_in_fifo ()         // output[3:0] 
    );
fifo_same_clock_fill   #( .DATA_WIDTH(43), .DATA_DEPTH(W_FIFO_DEPTH))    
    wdata_i (
        .rst          (rst),
        .clk          (aclk),
        .sync_rst     (1'b0),
        .we           (wvalid && wready),
        .re           (fifo_wd_rd), //start_write_burst_w), // wrong
        .data_in      ({wlast, wid[5:0],          wstrb[3:0],     wdata[31:0]}),
        .data_out     ({wlast_out,wid_out[5:0],  wstrb_out[3:0], wdata_out[31:0]}),
        .nempty       (w_nempty),
        .half_full    (),                  //w_half_full),
        .under        (), //wdata_under),  // output reg 
        .over         (), //wdata_over),   // output reg
        .wcount       (), //wdata_wcount), // output[3:0] reg 
        .rcount       (), //wdata_rcount), // output[3:0] reg 
        .wnum_in_fifo (wcount),            // output[3:0] 
        .rnum_in_fifo ()                   // output[3:0] 
    );
// **** Write response channel ****    
    wire [ 1:0] bresp_value=2'b0;
    wire [ 1:0] bresp_in;
    
    wire fifo_wd_rd_dly;
    wire [5:0] bid_in;

//    input  [ 3:0] sim_bresp_latency, // latency in writing data outside of the module 

    dly_16 #(
        .WIDTH(1)
    ) bresp_dly_16_i (
        .clk(aclk),                                // input
        .rst(rst),                                 // input
        .dly(sim_bresp_latency[3:0]),              // input[3:0] 
        .din(last_confirmed_write), //fifo_wd_rd), // input[0:0] 
        .dout(fifo_wd_rd_dly)                      // output[0:0] 
    );

    // first FIFO for bresp - latency outside of the module
// wresp per burst, not per item !    
fifo_same_clock_fill  #( .DATA_WIDTH(8),.DATA_DEPTH(5))    
    wresp_ext_i (
        .rst           (rst),
        .clk           (aclk),
        .sync_rst      (1'b0),
        .we            (last_confirmed_write),            // fifo_wd_rd),
        .re            (fifo_wd_rd_dly),                  // not allowing RE next cycle after bvalid
        .data_in       ({wid_out[5:0],bresp_value[1:0]}),
        .data_out      ({bid_in[5:0],bresp_in[1:0]}),
        .nempty        (),
        .half_full     (), //),
        .under         (), //wresp_under),                // output reg 
        .over          (), //wresp_over),                 // output reg
        .wcount        (), //wresp_wcount),               // output[3:0] reg 
        .rcount        (), //wresp_rcount),               // output[3:0] reg 
        .wnum_in_fifo  (), // wresp_num_in_fifo)          // output[3:0] 
        .rnum_in_fifo  () // wresp_num_in_fifo)           // output[3:0] 
    );

    assign wresp_re=bready && bvalid; // && !was_wresp_re;
    always @ (posedge rst or posedge aclk) begin
        if (rst) was_wresp_re<=0;
        else was_wresp_re <= wresp_re;
    end
    assign bvalid=|wresp_num_in_fifo[5:1] || (!was_wresp_re && wresp_num_in_fifo[0]);
    // second wresp FIFO (does it exist in the actual module)?
fifo_same_clock_fill  #( .DATA_WIDTH(8),.DATA_DEPTH(5))    
    wresp_i (
        .rst          (rst),
        .clk          (aclk),
        .sync_rst     (1'b0),
        .we           (fifo_wd_rd_dly),
        .re           (wresp_re), // not allowing RE next cycle after bvalid
        .data_in      ({bid_in[5:0],bresp_in[1:0]}),
        .data_out     ({bid[5:0],bresp[1:0]}),
        .nempty       (), //bvalid),
        .half_full    (), //),
        .under        (), //wresp_under), // output reg 
        .over         (), //wresp_over), // output reg
        .wcount       (), //wresp_wcount), // output[3:0] reg 
        .rcount       (), //wresp_rcount), // output[3:0] reg 
        .wnum_in_fifo (), // wresp_num_in_fifo) // output[3:0] 
        .rnum_in_fifo (wresp_num_in_fifo) // wresp_num_in_fifo) // output[3:0] 
    );

endmodule

