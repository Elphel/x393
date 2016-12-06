/*!
 * <b>Module:</b>dct_tests_01
 * @file dct_tests_01.tf
 * @date 2016-12-02  
 * @author  Andrey Filippov
 *     
 * @brief 1d 8-point DCT type IV for lapped mdct 16->8, operates in 16 clock cycles
 * Uses 2 DSP blocks 
 *
 * @copyright Copyright (c) 2016 Elphel, Inc.
 *
 * <b>License:</b>
 *
 *dct_tests_01.tf is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  dct_tests_01.tf is distributed in the hope that it will be useful,
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
// No saturation here, and no rounding as we do not need to match decoder (be bit-precise), skipping rounding adder
// will reduce needed resources
//`define DCT_INPUT_UNITY
module  dct_tests_01 ();
//    parameter fstname="dct_tests_01.fst";
`ifdef IVERILOG              
    `ifdef NON_VDT_ENVIROMENT
        parameter fstname="dct_tests_01.fst";
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
        parameter fstname = "dct_tests_01.fst";
    `endif // CVC
`endif // IVERILOG
    
    parameter CLK_PERIOD = 10; // ns
    parameter WIDTH =        24; // input data width
//    parameter OUT_WIDTH =    16; // output data width
    parameter OUT_WIDTH =    24; // output data width
    parameter OUT_RSHIFT =    3;  // overall right shift of the result from input, aligned by MSB (>=3 will never cause saturation)
    
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
    reg  [WIDTH-1:0] x_out;
    reg  [WIDTH-1:0] x_ram[0:7];
    wire [WIDTH-1:0] x_out_w = x_ram[x_ra];
    
    reg              start = 0;
    
    wire [OUT_WIDTH-1:0] y_dct;           // S uppressThisWarning VEditor - simulation only
    wire                 pre2_start_out;  // S uppressThisWarning VEditor - simulation only
    wire                 en_out;          // S uppressThisWarning VEditor - simulation only
    
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
    integer              i,j;
    initial begin
        for (i=0; i<64; i=i+1) begin
`ifdef DCT_INPUT_UNITY
            data_in[i] = (i[2:0] == i[5:3]) ? {2'b1,{WIDTH-2{1'b0}}} : 0;
`else
            data_in[i] = $random;
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
        $dumpvars(0,dct_tests_01); // SuppressThisWarning VEditor
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
/*        
        // running 'one' - just make a period == 17
        repeat (7) begin
            @(posedge CLK);
#1          x_in = {2'b1,{WIDTH-2{1'b0}}}; // >>x_wa;
            @(posedge CLK);
#1            x_in = 0; 
            repeat (15) @(posedge CLK); // 16+1= 17, non-zero will go through all of the 8 x[i]
        end
        begin
            @(posedge CLK);
#1            x_in = {2'b1,{WIDTH-2{1'b0}}};
            @(posedge CLK);
#1            x_in = 0; 
            en_x = 0;
        end
*/        
        repeat (64) @(posedge CLK);
        
        $display("");
        $display("output data - transposed:");
        for (i=0; i<64; i=i+8) begin
            $display ("%d, %d, %d, %d, %d, %d, %d, %d",data_out[i+0],data_out[i+1],data_out[i+2],data_out[i+3],
                                                       data_out[i+4],data_out[i+5],data_out[i+6],data_out[i+7]);
        end
        
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
    
    
    
    always @ (posedge CLK) begin
        if      (RST)            run_in <= 0;
        else if (en_x)           run_in <= 1;
        else if (phase_in == 15) run_in <= 0;

        if       (RST)                               run_out <= 0;
        else if ((phase_in == 5) || (phase_out==15)) run_out <= run_in;
        
        if      (!run_in)        phase_in <= 0;
        else                     phase_in <= phase_in + 1;
        
        if      (!run_out)       phase_out <= 0;
        else                     phase_out <= phase_out + 1;
        
        run_out_d <= run_out;
        
        if (RST) start <= 0;
        else     start <= run_out & !run_out_d;
        
        {y_we,y_pre_we} <= {y_pre_we, en_out};   
        
        if      (RST)            phase_y <= 8;
        else if (pre2_start_out) phase_y <= 0;
        else if (y_pre_we)       phase_y <= phase_y + 1; 

        if      (RST)                    y_dv <= 0;
        else if ((phase_y == 6) && y_we) y_dv <= 1;
        else if (y_ra == 7)              y_dv <= 0;
        
        if (!y_dv) y_ra <= 0;
        else       y_ra <= y_ra  + 1;
        
        if (y_we) y_ram[y_wa] <= y_dct;
        

        if (x_we) x_ram[x_wa] <= x_in;
        
        x_out <= x_out_w;
//X2-X7-X3-X4-X5-X6-X0-X1-*-X3-X5-X4-*-X1-X7-*        
        case (phase_out)
            4'h0: x_ra <= 2;
            4'h1: x_ra <= 7;
            4'h2: x_ra <= 3;
            4'h3: x_ra <= 4;
            4'h4: x_ra <= 5;
            4'h5: x_ra <= 6;
            4'h6: x_ra <= 0;
            4'h7: x_ra <= 1;
            4'h8: x_ra <= 'bx;
            4'h9: x_ra <= 3;
            4'ha: x_ra <= 5;
            4'hb: x_ra <= 4;
            4'hc: x_ra <= 'bx;
            4'hd: x_ra <= 6;
            4'he: x_ra <= 7;
            4'hf: x_ra <= 'bx;
        endcase
        
        case (phase_y[2:0])
            3'h0: y_wa <= 0;
            3'h1: y_wa <= 7;
            3'h2: y_wa <= 4;
            3'h3: y_wa <= 3;
            3'h4: y_wa <= 1;
            3'h5: y_wa <= 6;
            3'h6: y_wa <= 2;
            3'h7: y_wa <= 5;
        endcase
        
    end
    /* Instance template for module dct_iv8_1d */
    dct_iv8_1d #(
        .WIDTH        (WIDTH),
        .OUT_WIDTH    (OUT_WIDTH),
        .OUT_RSHIFT   (OUT_RSHIFT),
        .B_WIDTH      (18),
        .A_WIDTH      (25),
        .P_WIDTH      (48),
        .COSINE_SHIFT (17),
        .COS_01_32    (130441),
        .COS_03_32    (125428),
        .COS_04_32    (121095),
        .COS_05_32    (115595),
        .COS_07_32    (101320),
        .COS_08_32    (92682),
        .COS_09_32    (83151),
        .COS_11_32    (61787),
        .COS_12_32    (50159),
        .COS_13_32    (38048),
        .COS_15_32    (12847)
    ) dct_iv8_1d_i (
        .clk            (CLK),            // input
        .rst            (RST),            // input
        .en             (run_in),         // input
        .d_in           (x_out),          // input[23:0] 
        .start          (start),          // input
        .dout           (y_dct),          // output[15:0] 
        .pre2_start_out (pre2_start_out), // output reg 
        .en_out         (en_out)          // output reg 
    );

endmodule
