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
  `define INSTANTIATE_DSP48E1
  `define PRELOAD_BRAMS
//  `define ROUND 
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
//    parameter WIDTH =           25; //4; // input data width
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
    
    //parameter DCT_GAP = 16; // between runs            
    
    //parameter SAME_BITS=4; // (3) to match 24-bit widths
    
    reg              RST = 1'b1;
    reg              CLK = 1'b0;
    
    reg   [PIXEL_WIDTH-1 : 0]   tile_shift[0:258];  // SuppressThisWarning VEditor : assigned in $readmem() system task
    reg   [PIXEL_WIDTH-1 : 0]   tiles[0:1023];
    reg   [SHIFT_WIDTH-1 : 0]   shifts_x[0:3]; 
    reg   [SHIFT_WIDTH-1 : 0]   shifts_y[0:3]; 
    reg               [3 : 0]   bayer[0:3]; 
    
    reg                 [3:0]   java_wnd_signs[0:255]; // SuppressThisWarning VEditor : assigned in $readmem() system task
    reg                 [7:0]   java_fold_index[0:255]; // SuppressThisWarning VEditor : assigned in $readmem() system task
    reg     [WND_WIDTH - 1:0]   java_tiles_wnd[0:255]; // SuppressThisWarning VEditor : assigned in $readmem() system task

    reg  [DTT_IN_WIDTH - 1:0]   java_dtt_in0[0:255]; // SuppressThisWarning VEditor : assigned in $readmem() system task

    reg     [WND_WIDTH - 1:0]   tiles_wnd[0:1023];    // SuppressThisWarning VEditor : assigned in $readmem() system task
    reg  [DTT_IN_WIDTH - 1:0]   java_dtt_in[0:1023];  // SuppressThisWarning VEditor : assigned in $readmem() system task

    reg  [DTT_IN_WIDTH - 1:0]   java_dtt_out0[0:255]; // SuppressThisWarning VEditor : assigned in $readmem() system task
    reg  [DTT_IN_WIDTH - 1:0]   java_dtt_out[0:1023]; // SuppressThisWarning VEditor : assigned in $readmem() system task

    reg  [DTT_IN_WIDTH - 1:0]   java_dtt_rot0[0:255]; // SuppressThisWarning VEditor : assigned in $readmem() system task
    reg  [DTT_IN_WIDTH - 1:0]   java_dtt_rot[0:1023]; // SuppressThisWarning VEditor : assigned in $readmem() system task
    integer   i, n, n_out;
    initial begin
        $readmemh("input_data/clt_wnd_signs.dat",  java_wnd_signs);
        $readmemh("input_data/clt_fold_index.dat", java_fold_index);
    
//        $readmemh("input_data/tile_01.dat",tile_shift);
        //============ tile 0
        $readmemh("input_data/clt_tile_00_2_x1489_y951.dat",tile_shift);
        shifts_x[0] = tile_shift[0][SHIFT_WIDTH-1:0];
        shifts_y[0] = tile_shift[1][SHIFT_WIDTH-1:0];
        bayer[0] =    tile_shift[2][3:0];
        for (i=0; i<256; i=i+1) begin
            tiles['h000 + i] = tile_shift[i+3]; 
        end
        $readmemh("input_data/clt_wnd_00_2_x1489_y951.dat",java_tiles_wnd);
        for (i=0; i<256; i=i+1) begin
            tiles_wnd['h000 + i] = java_tiles_wnd[i]; 
        end

        $readmemh("input_data/clt_dtt_in_00_2_x1489_y951.dat",java_dtt_in0);
        for (i=0; i<256; i=i+1) begin
            java_dtt_in['h000 + i] = java_dtt_in0[i]; 
        end

        $readmemh("input_data/clt_dtt_out_00_2_x1489_y951.dat",java_dtt_out0);
        for (i=0; i<256; i=i+1) begin
            java_dtt_out['h000 + i] = java_dtt_out0[i]; 
        end
        
        $readmemh("input_data/clt_dtt_rot_00_2_x1489_y951.dat",java_dtt_rot0);
        for (i=0; i<256; i=i+1) begin
            java_dtt_rot['h000 + i] = java_dtt_rot0[i]; 
        end
        
        //============ tile 1
        
        $readmemh("input_data/clt_tile_01_2_x1489_y951.dat",tile_shift);
        shifts_x[1] = tile_shift[0][SHIFT_WIDTH-1:0];
        shifts_y[1] = tile_shift[1][SHIFT_WIDTH-1:0];
        bayer[1] =    tile_shift[2][3:0];
        for (i=0; i<256; i=i+1) begin
            tiles['h100 + i] = tile_shift[i+3]; 
        end
        
        $readmemh("input_data/clt_wnd_01_2_x1489_y951.dat",java_tiles_wnd);
        for (i=0; i<256; i=i+1) begin
            tiles_wnd['h100 + i] = java_tiles_wnd[i]; 
        end

        $readmemh("input_data/clt_dtt_in_01_2_x1489_y951.dat",java_dtt_in0);
        for (i=0; i<256; i=i+1) begin
            java_dtt_in['h100 + i] = java_dtt_in0[i]; 
        end

        $readmemh("input_data/clt_dtt_out_01_2_x1489_y951.dat",java_dtt_out0);
        for (i=0; i<256; i=i+1) begin
            java_dtt_out['h100 + i] = java_dtt_out0[i]; 
        end
        
        $readmemh("input_data/clt_dtt_rot_01_2_x1489_y951.dat",java_dtt_rot0);
        for (i=0; i<256; i=i+1) begin
            java_dtt_rot['h100 + i] = java_dtt_rot0[i]; 
        end
        
        //============ tile 2
        
        $readmemh("input_data/clt_tile_02_2_x1489_y951.dat",tile_shift);
        shifts_x[2] = tile_shift[0][SHIFT_WIDTH-1:0];
        shifts_y[2] = tile_shift[1][SHIFT_WIDTH-1:0];
        bayer[2] =    tile_shift[2][3:0];
        for (i=0; i<256; i=i+1) begin
            tiles['h200 + i] = tile_shift[i+3]; 
        end
        
        $readmemh("input_data/clt_wnd_02_2_x1489_y951.dat",java_tiles_wnd);
        for (i=0; i<256; i=i+1) begin
            tiles_wnd['h200 + i] = java_tiles_wnd[i]; 
        end

        $readmemh("input_data/clt_dtt_in_02_2_x1489_y951.dat",java_dtt_in0);
        for (i=0; i<256; i=i+1) begin
            java_dtt_in['h200 + i] = java_dtt_in0[i]; 
        end

        $readmemh("input_data/clt_dtt_out_02_2_x1489_y951.dat",java_dtt_out0);
        for (i=0; i<256; i=i+1) begin
            java_dtt_out['h200 + i] = java_dtt_out0[i]; 
        end
        
        $readmemh("input_data/clt_dtt_rot_02_2_x1489_y951.dat",java_dtt_rot0);
        for (i=0; i<256; i=i+1) begin
            java_dtt_rot['h200 + i] = java_dtt_rot0[i]; 
        end
        
        //============ tile 3
        
        $readmemh("input_data/clt_tile_00_2_x1489_y951.dat",tile_shift);
        shifts_x[3] = tile_shift[0][SHIFT_WIDTH-1:0];
        shifts_y[3] = tile_shift[1][SHIFT_WIDTH-1:0];
        bayer[3] =    tile_shift[2][3:0];
        for (i=0; i<256; i=i+1) begin
            tiles['h300 + i] = tile_shift[i+3]; 
        end
        $readmemh("input_data/clt_wnd_00_2_x1489_y951.dat",java_tiles_wnd);
        for (i=0; i<256; i=i+1) begin
            tiles_wnd['h300 + i] = java_tiles_wnd[i]; 
        end

        $readmemh("input_data/clt_dtt_in_00_2_x1489_y951.dat",java_dtt_in0);
        for (i=0; i<256; i=i+1) begin
            java_dtt_in['h300 + i] = java_dtt_in0[i]; 
        end

        $readmemh("input_data/clt_dtt_out_00_2_x1489_y951.dat",java_dtt_out0);
        for (i=0; i<256; i=i+1) begin
            java_dtt_out['h300 + i] = java_dtt_out0[i]; 
        end
        
        $readmemh("input_data/clt_dtt_rot_00_2_x1489_y951.dat",java_dtt_rot0);
        for (i=0; i<256; i=i+1) begin
            java_dtt_rot['h300 + i] = java_dtt_rot0[i]; 
        end
        
        for (n=0;n<4;n=n+1) begin
            $display("Tile %d: shift x = %h, shift_y = %h, bayer = %h", 0, shifts_x[n], shifts_y[n], bayer[n]);
            for (i = 256 * n; i < 256 * (n + 1); i = i + 16) begin
                $display ("%h, %h, %h, %h, %h, %h, %h, %h, %h, %h, %h, %h, %h, %h, %h, %h",
                    tiles[i+ 0],tiles[i+ 1],tiles[i+ 2],tiles[i+ 3],
                    tiles[i+ 4],tiles[i+ 5],tiles[i+ 6],tiles[i+ 7],
                    tiles[i+ 8],tiles[i+ 9],tiles[i+10],tiles[i+11],
                    tiles[i+12],tiles[i+13],tiles[i+14],tiles[i+15]);
            end
            $display("");
        end
        
    end

    reg                         start;
    reg       [SHIFT_WIDTH-1:0] x_shft; 
    reg       [SHIFT_WIDTH-1:0] y_shft;
    reg                   [3:0] bayer_r;
    reg                   [1:0] page_in; 
    wire                        pre_busy_w;
    wire                        pre_busy;
    reg                         LATE = 0;
    wire                        mpixel_re;
    wire                        mpixel_page;    
    reg                         mpixel_reg;
    reg                         mpixel_valid;
    wire                  [7:0] mpixel_a;
    reg     [PIXEL_WIDTH-1 : 0] pixel_r;
    reg     [PIXEL_WIDTH-1 : 0] pixel_r2;
    wire    [PIXEL_WIDTH-1 : 0] mpixel_d = mpixel_valid ? pixel_r2 : {PIXEL_WIDTH{1'bz}};  
    
    wire                        pre_last_in;   // SuppressThisWarning VEditor - output only
    wire                        pre_first_out; // SuppressThisWarning VEditor - output only
    wire                        pre_last_out;  // SuppressThisWarning VEditor - output only
    wire                  [7:0] out_addr;      // SuppressThisWarning VEditor - output only
    wire                        dv;            // SuppressThisWarning VEditor - output only
    wire        [OUT_WIDTH-1:0] dout;          // SuppressThisWarning VEditor - output only
    
    assign  #(1)  pre_busy = pre_busy_w;
    
    
    always #(CLK_PERIOD/2) CLK = ~CLK;    
    initial begin
        $dumpfile(fstname);
        $dumpvars(0,mclt_test_01); // SuppressThisWarning VEditor
        #100;
        start =  0;
        page_in = 0;
        LATE = 0;
        RST = 0;
        #100;
        repeat (10) @(posedge CLK);
//        #1;
        for (n = 0; n < 4; n = n+1) begin
            if (n>2) LATE = 1;
            while (pre_busy || LATE) begin
                if (!pre_busy) LATE = 0;
                @(posedge CLK);
                #1;
            end
            start = 1;
            x_shft = shifts_x[n];
            y_shft = shifts_y[n];
            bayer_r = bayer[n];
            @(posedge CLK);
            #1;
            start = 0; 
            x_shft = 'bz;
            y_shft = 'bz;
            bayer_r = 'bz;                    
            @(posedge CLK);
//            #1;
        end 
        // emergency finish
        repeat (1024) @(posedge CLK);
        $finish; 
        //pre_last_out
    end
    
    always @ (posedge CLK) if (!RST) begin
        mpixel_reg <=     mpixel_re;
        mpixel_valid <=   mpixel_reg; 
        if (mpixel_re)    pixel_r <= tiles[{page_in,mpixel_a}];
        if (mpixel_reg)   pixel_r2 <= pixel_r; 
        if (mpixel_page)  page_in <= page_in + 1;
        if (pre_last_out) n_out <= n_out + 1;

    end

    initial begin
        n_out = 0;
        while (n_out < 4)  @(posedge CLK);
        repeat (32)        @(posedge CLK);
        $finish;
    
    end

    integer n1, cntr1, diff1;// SuppressThisWarning VEditor : assigned in $readmem() system task
    wire           [7:0] mpix_a_w = mclt16x16_i.mpix_a_w;
    wire           [7:0] java_fi_w = java_fold_index[cntr1];  
    initial begin
        while (RST) @(negedge CLK);
        for (n1 = 0; n1 < 4; n1 = n1+1) begin
            while (mclt16x16_i.in_cntr != 2) begin
                @(negedge CLK);
            end
            for (cntr1 = 0; cntr1 < 256; cntr1 = cntr1 + 1) begin
                diff1 = mpix_a_w - java_fi_w; // java_fold_index[cntr1];
                @(negedge CLK);
            end
        end
    end

    integer n2, cntr2, diff2, diff2a; // SuppressThisWarning VEditor : assigned in $readmem() system task
    wire [WND_WIDTH-1:0] window_r = mclt16x16_i.window_r;
//    reg            [7:0] java_fi_r;  
    wire [WND_WIDTH-1:0] java_window_w = tiles_wnd[n2 * 256 + cntr2]; //  java_tiles_wnd[cntr2];  
    initial begin
        while (RST) @(negedge CLK);
        for (n2 = 0; n2 < 4; n2 = n2+1) begin
            while (mclt16x16_i.in_cntr != 9) begin
                @(negedge CLK);
            end
            for (cntr2 = 0; cntr2 < 256; cntr2 = cntr2 + 1) begin
                diff2 = window_r - java_window_w;
                if (n2 < 1) diff2a = window_r - java_window_w; // TEMPORARY, while no other data
                @(negedge CLK);
            end
        end
    end

//Compare window signs
    integer n3, cntr3, diff3; // SuppressThisWarning VEditor : assigned in $readmem() system task
    wire           [3:0] mpix_sgn_w =  mclt16x16_i.mpix_sgn_w; // SuppressThisWarning VEditor : assigned in $readmem() system task
    wire           [3:0] java_sgn_w =  { //java_wnd_signs[java_fold_index[cntr3]];  // SuppressThisWarning VEditor : assigned in $readmem() system task
    java_wnd_signs[{2'b11,cntr3[7:2]}][cntr3[1:0]],
    java_wnd_signs[{2'b10,cntr3[7:2]}][cntr3[1:0]],
    java_wnd_signs[{2'b01,cntr3[7:2]}][cntr3[1:0]],
    java_wnd_signs[{2'b00,cntr3[7:2]}][cntr3[1:0]] 
    };
    initial begin
        while (RST) @(negedge CLK);
        for (n3 = 0; n3 < 4; n3 = n3+1) begin
            while (mclt16x16_i.in_cntr != 2) begin
                @(negedge CLK);
            end
            for (cntr3 = 0; cntr3 < 256; cntr3 = cntr3 + 1) begin
                #1;
                diff3 = mpix_sgn_w - java_sgn_w; // java_fold_index[cntr1];
                @(negedge CLK);
            end
        end
    end

//Compare DTT inputs

    integer n4, cntr4, diff4, diff4a; // SuppressThisWarning VEditor : assigned in $readmem() system task
    wire [DTT_IN_WIDTH-1:0] data_dtt_in = mclt16x16_i.data_dtt_in;
    wire [DTT_IN_WIDTH-1:0] java_data_dtt_in = java_dtt_in[{n4[1:0], cntr4[1:0],cntr4[7:2]}]; // java_dtt_in0[{cntr4[1:0],cntr4[7:2]}]  
    initial begin
        while (RST) @(negedge CLK);
        for (n4 = 0; n4 < 4; n4 = n4+1) begin
            while (mclt16x16_i.in_cntr != 16) begin
                @(negedge CLK);
            end
            for (cntr4 = 0; cntr4 < 256; cntr4 = cntr4 + 1) begin
                #1;
                diff4 = data_dtt_in - java_data_dtt_in;
                if (n4 < 1) diff4a = data_dtt_in - java_data_dtt_in; // TEMPORARY, while no other data
                @(negedge CLK);
            end
        end
    end

    integer n5, cntr5, diff5, diff5a; // SuppressThisWarning VEditor : assigned in $readmem() system task
    wire [DTT_IN_WIDTH-1:0] dtt_r_data = mclt16x16_i.dtt_r_data;
    wire [DTT_IN_WIDTH-1:0] java_dtt_r_data =  java_dtt_in[{n5[1:0], cntr5[7:0]}]; // java_dtt_in0[cntr5[7:0]];
    
    wire                           dtt_r_regen = mclt16x16_i.dtt_r_regen;
    reg                            dtt_r_dv; // SuppressThisWarning VEditor just for simulation
    always @ (posedge CLK) begin
        if (RST) dtt_r_dv <= 0;
        else     dtt_r_dv <= dtt_r_regen;
    end
    
      
    initial begin
        while (RST) @(negedge CLK);
        for (n5 = 0; n5 < 4; n5 = n5+1) begin
            while ((!dtt_r_dv) || (mclt16x16_i.dtt_r_cntr[7:0] != 2)) begin
                @(negedge CLK);
            end
            for (cntr5 = 0; cntr5 < 256; cntr5 = cntr5 + 1) begin
                #1;
                diff5 = dtt_r_data - java_dtt_r_data;
                if (n5 < 1) diff5a = dtt_r_data - java_dtt_r_data; // TEMPORARY, while no other data
                @(negedge CLK);
            end
        end
    end




    integer n6, cntr6, diff6, diff6a; // SuppressThisWarning VEditor : assigned in $readmem() system task
    wire [DTT_IN_WIDTH-1:0] data_dtt_out = mclt16x16_i.dtt_rd_data;
//    wire [DTT_IN_WIDTH-1:0] java_data_dtt_out = java_dtt_out0[{cntr6[1:0],cntr6[7:2]}]; // java_dtt_in[n2 * 256 + cntr2];  
    wire [DTT_IN_WIDTH-1:0] java_data_dtt_out = java_dtt_out[{n6[1:0], cntr6[0],cntr6[1], cntr6[7:2]}]; //java_dtt_out0[{cntr6[0],cntr6[1],cntr6[7:2]}];  
    initial begin
        while (RST) @(negedge CLK);
        for (n6 = 0; n6 < 4; n6 = n6+1) begin
            while ((!mclt16x16_i.dtt_rd_regen_dv[2]) || (mclt16x16_i.dtt_rd_cntr[7:0] != 2)) begin
                @(negedge CLK);
            end
            for (cntr6 = 0; cntr6 < 256; cntr6 = cntr6 + 1) begin
                #1;
                diff6 = data_dtt_out - java_data_dtt_out;
                if (n6 < 1) diff6a = data_dtt_out - java_data_dtt_out; // TEMPORARY, while no other data
                @(negedge CLK);
            end
        end
    end

    reg FIRST_OUT;
    always @(posedge CLK) FIRST_OUT <= mclt16x16_i.pre_first_out;
    
    integer n7, cntr7, diff7, diff7a; // SuppressThisWarning VEditor : assigned in $readmem() system task
    wire [OUT_WIDTH-1:0] java_data_dtt_rot = java_dtt_rot[{n7[1:0], cntr7[1],cntr7[0],cntr7[7:2]}];  //java_dtt_rot0[{cntr7[1],cntr7[0],cntr7[7:2]}];
    initial begin
        while (RST) @(negedge CLK);
        for (n7 = 0; n7 < 4; n7 = n7+1) begin
            while (!FIRST_OUT) begin
                @(negedge CLK);
            end
            for (cntr7 = 0; cntr7 < 256; cntr7 = cntr7 + 1) begin
                #1;
                diff7 = dout - java_data_dtt_rot;
                if (n7 < 1) diff7a = dout - java_data_dtt_rot; // TEMPORARY, while no other data
                @(negedge CLK);
            end
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
        .clk             (CLK),         // input
        .rst             (RST),         // input
        .start           (start),       // input
        .x_shft          (x_shft),      // input[6:0] 
        .y_shft          (y_shft),      // input[6:0] 
        .bayer           (bayer_r),     // input[3:0] 
        .mpixel_re       (mpixel_re),   // output
        .mpixel_page     (mpixel_page), // output  //!< increment pixel page after this
        
        .mpixel_a        (mpixel_a),    // output[7:0] 
        .mpixel_d        (mpixel_d),    // input[15:0] 
        .pre_busy        (pre_busy_w),    // output
        .pre_last_in     (pre_last_in), // output reg 
        .pre_first_out   (pre_first_out), // output
        .pre_last_out    (pre_last_out), // output
        .out_addr        (out_addr), // output[7:0] 
        .dv              (dv), // output
        .dout            (dout) // output[24:0] signed 
    );

endmodule
