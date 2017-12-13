/*!
 * <b>Module:</b>mclt_test_01
 * @file mclt_test_01.tf
 * @date 2016-12-02  
 * @author  Andrey Filippov
 *     
 * @brief testing MCLT 16x16 -> 4*8*8 transform
 * Uses 2 DSP blocks 
 *
 * @copyright Copyright (c) 2016 Elphel, Inc.
 *
 * <b>License:</b>
 *
 *mclt_test_01.tf is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  mclt_test_01.tf is distributed in the hope that it will be useful,
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
module  mclt_test_01 ();
`ifdef IVERILOG              
    `ifdef NON_VDT_ENVIROMENT
        parameter fstname="mclt_test_01.fst";
    `else
        `include "IVERILOG_INCLUDE.v"
    `endif // NON_VDT_ENVIROMENT
`else // IVERILOG
    `ifdef CVC
        `ifdef NON_VDT_ENVIROMENT
            parameter fstname = "x393.fst";
        `else // NON_VDT_ENVIROMENT
            `include "IVERILOG_INCLUDE.v"
        `endif // NON_VDT_ENVIROMENT
    `else
        parameter fstname = "mclt_test_01.fst";
    `endif // CVC
`endif // IVERILOG
    
    parameter CLK_PERIOD =      10; // ns
    parameter WIDTH =           25; //4; // input data width

    parameter SHIFT_WIDTH =      7; // bits in shift (7 bits - fractional)
    parameter COORD_WIDTH =     10; // bits in full coordinate 10 for 18K RAM
    parameter PIXEL_WIDTH =     16; // input pixel width (unsigned) 
    parameter WND_WIDTH =       18; // input pixel width (unsigned) 
    parameter OUT_WIDTH =       25; // bits in dtt output
    parameter DTT_IN_WIDTH =    25; // bits in DTT input
    parameter TRANSPOSE_WIDTH = 25; // width of the transpose memory (intermediate results)    
    parameter OUT_RSHIFT =       2; // overall right shift of the result from input, aligned by MSB (>=3 will never cause saturation)
    parameter OUT_RSHIFT2 =      0; // overall right shift for the second (vertical) pass
    parameter DSP_B_WIDTH =     18; // signed, output from sin/cos ROM
    parameter DSP_A_WIDTH =     25;
    parameter DSP_P_WIDTH =     48;
    parameter DEAD_CYCLES =     14;  // start next block immedaitely, or with longer pause
    
    parameter DCT_GAP = 16; // between runs            
    
    parameter SAME_BITS=4; // (3) to match 24-bit widths
    
    reg              RST = 1'b1;
    reg              CLK = 1'b0;
    reg        [3:0] phase_in;
    reg        [3:0] phase_out;
    reg              run_in;
    reg              run_out;
    reg              run_out_d;
    
    reg              en_x = 0;
//    reg              end_x = 0;
    reg        [2:0] x_ra;
    wire       [2:0] x_wa = phase_in[2:0];
    
    
    wire             x_we = !phase_in[3] && run_in;
    reg  [WIDTH-1:0] x_in;
    reg  [WIDTH-1:0] x_in_2d;
    reg  [WIDTH-1:0] x_out;
    reg  [WIDTH-1:0] x_ram[0:7];
    wire [WIDTH-1:0] x_out_w = x_ram[x_ra];
    
    reg              start = 0;
    reg              start2 = 0; // second start for 2d
    reg        [1:0] mode_in= 0; // 3; // [0] - vertical pass 0: dct, 1 - dst, [1] - horizontal pass
    wire       [1:0] mode_out;   // [0] - vertical pass 0: dct, 1 - dst, [1] - horizontal pass
    
    wire [OUT_WIDTH-1:0] y_dct;
    wire                 pre2_start_out;
    wire                 en_out;
    
    reg                  y_pre_we;
    reg                  y_we;
    reg            [3:0] phase_y=8;
    reg            [2:0] y_wa;
    reg            [2:0] y_ra;
    reg                  y_dv=0;
    reg  signed [OUT_WIDTH-1:0] y_ram[0:7]; 
    wire signed [OUT_WIDTH-1:0] y_out = y_ram[y_ra];           // SuppressThisWarning VEditor - simulation only
    reg  signed     [WIDTH-1:0] data_in[0:63];
    reg  signed [OUT_WIDTH-1:0] data_out[0:63];

    wire                        pre_last_in_2d;    // SuppressThisWarning VEditor - simulation only
    wire                        pre_first_out_2d;  // SuppressThisWarning VEditor - simulation only
    wire                        pre_busy_2d;       // SuppressThisWarning VEditor - simulation only
    wire                        dv_2d;             // SuppressThisWarning VEditor - simulation only
//    wire signed [OUT_WIDTH-1:0] d_out_2d;

    wire                        pre_last_in_2dr;   // SuppressThisWarning VEditor - simulation only
    wire                        pre_first_out_2dr; // SuppressThisWarning VEditor - simulation only
    wire                        pre_busy_2dr;      // SuppressThisWarning VEditor - simulation only
    wire                        dv_2dr;            // SuppressThisWarning VEditor - simulation only
    wire signed [OUT_WIDTH-1:0] d_out_2dr;         // SuppressThisWarning VEditor - simulation only

    
    integer   i,j, i1, ir;
    initial begin
        for (i=0; i<64; i=i+1) begin
        `ifdef DCT_INPUT_UNITY
            data_in[i] =  (i[2:0] == (i[5:3]  ^ 3'h0)) ? {2'b1,{WIDTH-2{1'b0}}} : 0;
            ir= (i[2:0] == (i[5:3]  ^ 3'h1)) ? {2'b1,{WIDTH-2{1'b0}}} : 0;
            data_in[i] =  ir;
        `else
            ir = $random;
            data_in[i]  = ((i[5:3] == 0) || (i[5:3] == 7) || (i[2:0] == 0) || (i[2:0] == 7))? 0:
            {{SAME_BITS{ir[WIDTH -SAME_BITS - 1]}},ir[WIDTH -SAME_BITS-1:0]};
        `endif
        end
        $display("Input data in line-scan order:");
        for (i=0; i<64; i=i+8) begin
            $display ("%d, %d, %d, %d, %d, %d, %d, %d",data_in[i+0],data_in[i+1],data_in[i+2],data_in[i+3],
                                                   data_in[i+4],data_in[i+5],data_in[i+6],data_in[i+7]);
        end
        $display("");
        $display("Input data - transposed:");
        j=0;
        for (i=0; i < 8; i=i+1) begin
            $display ("%d, %d, %d, %d, %d, %d, %d, %d",data_in[i+ 0],data_in[i+ 8],data_in[i+16],data_in[i+24],
                                                       data_in[i+32],data_in[i+40],data_in[i+48],data_in[i+56]);
        end
        $display("");
        
    end  
    
    always #(CLK_PERIOD/2) CLK = ~CLK;    
    initial begin
        $dumpfile(fstname);
        $dumpvars(0,mclt_test_01); // SuppressThisWarning VEditor
        #100;
        RST = 0;
        #100;
        repeat (10) @(posedge CLK);
#1      en_x = 1;
        for (i = 0; i < 64; i = i+1) begin
            @(posedge CLK);
            #1;
            x_in = data_in[i]; // >>x_wa;
            if (i==63) begin
                en_x = 0;
            end
            if (&i[2:0]) repeat (8) @(posedge CLK);
        end
        #1 x_in = 0;
        repeat (64) @(posedge CLK);
        
        $display("");
        $display("output data - transposed:");
        for (i=0; i<64; i=i+8) begin
            $display ("%d, %d, %d, %d, %d, %d, %d, %d",data_out[i+0],data_out[i+1],data_out[i+2],data_out[i+3],
                                                       data_out[i+4],data_out[i+5],data_out[i+6],data_out[i+7]);
        end
        
//        repeat (64) @(posedge CLK);
//        $finish;
    end

    initial begin
        wait (!RST);
        while (!start) begin
            @(posedge CLK);
            #1;
        end    
        for (i1 = 0; i1 < 192; i1 = i1+1) begin
            @(posedge CLK);
            #1;
            x_in_2d = data_in[i1 & 63];
            if ((i1 & 63) ==  0)  mode_in = mode_in+1;
            start2 = (i1 & 63) == 63;
        end
        for (i1 = 0; i1 < 64; i1 = i1+1) begin
            @(posedge CLK);
            #1;
            start2 = 0;
            x_in_2d = data_in[i1];
        end
        
        repeat (DCT_GAP) @(posedge CLK);
        #1;
        start2 = 1;
        for (i1 = 0; i1 < 64; i1 = i1+1) begin
            @(posedge CLK);
            #1;
            start2 = 0;
            x_in_2d = data_in[63-i1];
        end
        
        repeat (300) @(posedge CLK);
        $finish;
        
    end
    

    initial j = 0;
    always @ (posedge CLK) begin
        if (y_dv) begin
//$display (" y[0x%x] => 0x%x %d, j=%d @%t",y_ra,y_out,y_out,j,$time);        
            data_out[{j[2:0],j[5:3]}] = y_out; // transpose array
            #1 j = j+1;
        end
    end
    
    mclt16x16 #(
        .SHIFT_WIDTH     (SHIFT_WIDTH),
        .COORD_WIDTH     (COORD_WIDTH),
        .PIXEL_WIDTH     (PIXEL_WIDTH),
        .WND_WIDTH       (WND_WIDTH),
        .OUT_WIDTH       (OUT_WIDTH),
        .DTT_IN_WIDTH    (DTT_IN_WIDTH),
        .TRANSPOSE_WIDTH (TRANSPOSE_WIDTH),
        .OUT_RSHIFT      (OUT_RSHIFT),
        .OUT_RSHIFT2     (OUT_RSHIFT2),
        .DSP_B_WIDTH     (DSP_B_WIDTH),
        .DSP_A_WIDTH     (DSP_A_WIDTH),
        .DSP_P_WIDTH     (DSP_P_WIDTH),
        .DEAD_CYCLES     (DEAD_CYCLES)
    ) mclt16x16_i (
        .clk             (CLK), // input
        .rst             (RST), // input
        .start           (), // input
        .x_shft          (), // input[6:0] 
        .y_shft          (), // input[6:0] 
        .bayer           (), // input[3:0] 
        .mpixel_a        (), // output[7:0] 
        .mpixel_d        (), // input[15:0] 
        .pre_busy        (), // output
        .pre_last_in     (), // output reg 
        .pre_first_out   (), // output
        .pre_last_out    (), // output
        .out_addr        (), // output[7:0] 
        .dv              (), // output
        .dout            () // output[24:0] signed 
    );
 
 

endmodule
