/*!
 * <b>Module:</b>dct_tests_04
 * @file dct_tests_04.tf
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
 *dct_tests_04.tf is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  dct_tests_04.tf is distributed in the hope that it will be useful,
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
  `define INSTANTIATE_DSP48E1 

// No saturation here, and no rounding as we do not need to match decoder (be bit-precise), skipping rounding adder
// will reduce needed resources
//`define DCT_INPUT_UNITY
module  dct_tests_04 ();
//    parameter fstname="dct_tests_04.fst";
`ifdef IVERILOG              
    `ifdef NON_VDT_ENVIROMENT
        parameter fstname="dct_tests_04.fst";
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
        parameter fstname = "dct_tests_04.fst";
    `endif // CVC
`endif // IVERILOG
    
    parameter CLK_PERIOD =     10; // ns
    parameter WIDTH =           25; //4; // input data width
    parameter OUT_WIDTH =       25; //4; // output data width
    parameter TRANSPOSE_WIDTH = 25; //4; // width of the transpose memory (intermediate results)    
    parameter OUT_RSHIFT =       2;  // overall right shift of the result from input, aligned by MSB (>=3 will never cause saturation)
    parameter OUT_RSHIFT2 =      0;  // overall right shift for the second (vertical) pass
    
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
        $dumpvars(0,dct_tests_04); // SuppressThisWarning VEditor
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

    dtt_iv8_1d #(
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
    ) dtt_iv8_1d_i (
        .clk            (CLK),            // input
        .rst            (RST),            // input
        .en             (run_in),         // input
        .dst_in         (mode_in[1]),     // input
        .d_in           (x_out),          // input[23:0] 
        .start          (start),          // input
        .dout           (y_dct),          // output[15:0] 
        .pre2_start_out (pre2_start_out), // output reg 
        .en_out         (en_out),         // output reg
        .dst_out        (),               // output
        .y_index        ()                // output[2:0] reg 
    );
    parameter ODEPTH = 5;
    reg signed       [OUT_WIDTH-1:0] out_ram[0: ((1<<ODEPTH)-1)]; // [0:31];
    wire signed      [OUT_WIDTH-1:0] out_wd;
    wire signed                [3:0] out_wa;
    wire                             out_we;
    wire                             sub16;
    wire                             inc16;
    wire                             start_out;
    reg                 [ODEPTH-5:0] out_ram_cntr;
    reg                 [ODEPTH-5:0] out_ram_wah;
    
    wire                [ODEPTH-1:0] out_ram_wa = {out_ram_wah,out_wa};
    reg                              out_ram_ren;
    reg                              out_ram_regen;
    reg                              out_ram_dv;
    wire                             out_pre_first;
    reg                        [5:0] out_ram_ra;
    
    
    reg signed      [OUT_WIDTH-1:0] out_ram_r;
    reg signed      [OUT_WIDTH-1:0] out_ram_r2;
    
    
    
    always @ (posedge CLK) begin
        if      (RST)    out_ram_cntr <= 0;
        else if (inc16)  out_ram_cntr <= out_ram_cntr + 1;
        out_ram_wah <= out_ram_cntr - sub16;
        
        if (out_we) out_ram[out_ram_wa] <= out_wd;
        
        if      (RST)         out_ram_ren <= 1'b0;
        else if (start_out)   out_ram_ren <= 1'b1;
        else if (&out_ram_ra) out_ram_ren <= 1'b0;
        
        out_ram_regen <= out_ram_ren;
        out_ram_dv <=    out_ram_regen;
        if (!out_ram_ren) out_ram_ra <= 0;
        else              out_ram_ra <= out_ram_ra + 1;
        
        if (out_ram_ren)   out_ram_r <= out_ram[out_ram_ra[4:0]];
        if (out_ram_regen) out_ram_r2 <= out_ram_r;
    
    end

    dly_var #(
        .WIDTH(1),
        .DLY_WIDTH(4)
    ) dly_out_pre_first_i (
        .clk  (CLK),           // input
        .rst  (RST),           // input
        .dly  (4'h1),          // input[3:0] 
        .din  (start_out),       // input[0:0] 
        .dout (out_pre_first)  // output[0:0] 
    );


    dtt_iv_8x8_ad #(
        .INPUT_WIDTH     (WIDTH),
        .OUT_WIDTH       (OUT_WIDTH),
        .OUT_RSHIFT1     (OUT_RSHIFT),
        .OUT_RSHIFT2     (OUT_RSHIFT2),
        .TRANSPOSE_WIDTH (TRANSPOSE_WIDTH),
        .DSP_B_WIDTH     (18),
        .DSP_A_WIDTH     (25),
        .DSP_P_WIDTH     (48)
    ) dtt_iv_8x8_i (
        .clk            (CLK),              // input
        .rst            (RST),              // input
        .start          (start || start2),  // input
        .mode           (mode_in),          // input[1:0] 
        .xin            (x_in_2d),          // input[24:0] signed 
        .pre_last_in    (pre_last_in_2d),   // output reg 
        .mode_out       (mode_out),         // output[1:0] reg 
        .pre_busy       (pre_busy_2d),      // output reg
        .out_wd         (out_wd),           // output[24:0] reg 
        .out_wa         (out_wa),           // output[3:0] reg 
        .out_we         (out_we),           // output reg 
        .sub16          (sub16),            // output reg 
        .inc16          (inc16),            // output reg 
        .start_out      (start_out)         // output reg 
    );



    dtt_iv_8x8_obuf #(
        .INPUT_WIDTH     (WIDTH),
        .OUT_WIDTH       (OUT_WIDTH),
        .OUT_RSHIFT1     (OUT_RSHIFT),
        .OUT_RSHIFT2     (OUT_RSHIFT2),
        .TRANSPOSE_WIDTH (TRANSPOSE_WIDTH),
        .DSP_B_WIDTH     (18),
        .DSP_A_WIDTH     (25),
        .DSP_P_WIDTH     (48)
    ) dtt_iv_8x8r_i (
        .clk            (CLK),               // input
        .rst            (RST),               // input
        .start          (out_pre_first),     // pre_first_out_2d),  // input
        .mode           ({mode_out[0],mode_out[1]}),          // input[1:0] // result is transposed
        .xin            (out_ram_r2),        // d_out_2d),          // input[24:0] signed 
        .pre_last_in    (pre_last_in_2dr),   // output reg 
        .pre_first_out  (pre_first_out_2dr), // output
        .dv             (dv_2dr),            // output
        .d_out          (d_out_2dr),         // output[24:0] signed
        .mode_out       (),                  // output[1:0] reg 
        .pre_busy       (pre_busy_2dr)       // output reg 
    );

/*
    mclt16x16 #(
        .SHIFT_WIDTH(7),
        .COORD_WIDTH(10),
        .PIXEL_WIDTH(16),
        .WND_WIDTH(18),
        .OUT_WIDTH(25),
        .DTT_IN_WIDTH(25),
        .TRANSPOSE_WIDTH(25),
        .OUT_RSHIFT(2),
        .OUT_RSHIFT2(0),
        .DSP_B_WIDTH(18),
        .DSP_A_WIDTH(25),
        .DSP_P_WIDTH(48),
        .DEAD_CYCLES(14)
    ) mclt16x16_i (
        .clk(CLK), // input
        .rst(RST), // input
        .start(start), // input
        .x_shft(0), // input[6:0] 
        .y_shft(0), // input[6:0] 
        .bayer(0), // input[3:0] 
        .mpixel_re(), // output
        .mpixel_page(), // output
        .mpixel_a(), // output[7:0] 
        .mpixel_d(0), // input[15:0] 
        .pre_busy(), // output
        .pre_last_in(), // output
        .pre_first_out(), // output
        .pre_last_out(), // output
        .out_addr(), // output[7:0] 
        .dv(), // output
        .dout() // output[24:0] signed 
    );
*/


endmodule
