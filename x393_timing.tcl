#################################################################################
# Filename: x393_timing.tcl
# Date:2016-03-28
# Author: Andrey Filippov
# Description: Timing constraints (selected by HISPI parameter in system_defines.vh)
#
# Copyright (c) 2016 Elphel, Inc.
# x393_timing.tcl is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
#  x393_timing.tcl is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/> .
#
# Additional permission under GNU GPL version 3 section 7:
# If you modify this Program, or any covered work, by linking or combining it
# with independent modules provided by the FPGA vendor only (this permission
# does not extend to any 3-rd party modules, "soft cores" or macros) under
# different license terms solely for the purpose of generating binary "bitstream"
# files and/or simulating the code, the copyright holders of this Program give
# you the right to distribute the covered work without those independent modules
# as long as the source code for them is available from the FPGA vendor free of
# charge, and there is no dependence on any encrypted modules for simulating of
# the combined code. This permission applies to you if the distributed code
# contains all the components and scripts required to completely simulate it
# with at least one of the Free Software programs.
#################################################################################
cd ~/vdt/x393
set infile [open "system_defines.vh" r]
set HISPI 0
while { [gets $infile line] >= 0 } {
    if { [regexp {(.*)`define(\s*)HISPI} $line matched prematch] } {
        if {[regexp "//" $prematch] != 0} { continue }
        set HISPI 1
        break
    }
}
set LWIR 0
seek $infile 0 start
while { [gets $infile line] >= 0 } {
    if { [regexp {(.*)`define(\s*)LWIR} $line matched prematch] } {
	if {[regexp "//" $prematch] != 0} { continue }
	set LWIR 1
	break
    }
}

close $infile
if       { $LWIR} {
    puts "x393_timing.tcl: using LWIR sensors"
} elseif { $HISPI} {
    puts "x393_timing.tcl: using HISPI sensors"
} else {
    puts "x393_timing.tcl: using parallel sensors"
}


#create_clock -name axi_aclk -period 20 [get_nets -hierarchical *axi_aclk]
#create_clock -name axi_aclk -period 20 [get_nets clocks393_i/aclk]
create_clock -name axi_aclk -period 20 [get_pins clocks393_i/bufg_axi_aclk_i/O]
create_generated_clock -name ddr3_sdclk [get_nets -hierarchical sdclk_pre ]
create_generated_clock -name ddr3_clk [get_nets -hierarchical clk_pre ]
create_generated_clock -name ddr3_clk_div [get_nets -hierarchical clk_div_pre ]
create_generated_clock -name ddr3_mclk [get_nets -hierarchical mclk_pre]
create_generated_clock -name ddr3_clk_ref [get_nets clocks393_i/dly_ref_clk_pre ]
create_generated_clock -name axihp_clk [get_nets clocks393_i/hclk_pre ]
create_generated_clock -name xclk      [get_nets clocks393_i/xclk_pre ]
#clock for inter - camera synchronization and event logger
create_generated_clock -name sclk      [get_nets clocks393_i/sync_clk_pre ]
create_clock -name ffclk0 -period 41.667 [get_ports {ffclk0p}]

#Generated clocks are assumed to be tied to clkin1 (not 2), so until external ffclk0 is constrained, derivative clocks are not generated
create_generated_clock -name pclk      [get_nets clocks393_i/dual_clock_pclk_i/clk1x_pre ]
if       { $LWIR} {
# Nothing here yet	
} elseif {$HISPI} {
#WARNING: [Vivado 12-4777] Setting CLOCK_DEDICATED_ROUTE constraint on the PARENT net instead of the specified net segment (net name: sensors393_i/sensor_channel_block[0].sensor_channel_i/sens_10398_i/sens_hispi12l4_i/sens_hispi_clock_i/clk_in). Placer only honors CLOCK_DEDICATED_ROUTE when set on the PARENT net, e.g. net segment directly connected to the driver. To eliminate this message, please update your constraint to specify the PARENT net instead. [/home/xilinx/vdt/x393/x393_timing.tcl:68]
#  set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets sensors393_i/sensor_channel_block\[0\].sensor_channel_i/sens_10398_i/sens_hispi12l4_i/sens_hispi_clock_i/clk_in]
#  set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets sensors393_i/sensor_channel_block\[1\].sensor_channel_i/sens_10398_i/sens_hispi12l4_i/sens_hispi_clock_i/clk_in]
#  set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets sensors393_i/sensor_channel_block\[2\].sensor_channel_i/sens_10398_i/sens_hispi12l4_i/sens_hispi_clock_i/clk_in]
#  set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets sensors393_i/sensor_channel_block\[3\].sensor_channel_i/sens_10398_i/sens_hispi12l4_i/sens_hispi_clock_i/clk_in]

} else {
  #Sensor-synchronous clocks
  create_generated_clock -name iclk0    [get_nets sensors393_i/sensor_channel_block\[0\].sensor_channel_i/sens_parallel12_i/ipclk_pre ]
  create_generated_clock -name iclk2x0  [get_nets sensors393_i/sensor_channel_block\[0\].sensor_channel_i/sens_parallel12_i/ipclk2x_pre ]

  create_generated_clock -name iclk1    [get_nets sensors393_i/sensor_channel_block\[1\].sensor_channel_i/sens_parallel12_i/ipclk_pre ]
  create_generated_clock -name iclk2x1  [get_nets sensors393_i/sensor_channel_block\[1\].sensor_channel_i/sens_parallel12_i/ipclk2x_pre ]

  create_generated_clock -name iclk2    [get_nets sensors393_i/sensor_channel_block\[2\].sensor_channel_i/sens_parallel12_i/ipclk_pre ]
  create_generated_clock -name iclk2x2  [get_nets sensors393_i/sensor_channel_block\[2\].sensor_channel_i/sens_parallel12_i/ipclk2x_pre ]

  create_generated_clock -name iclk3    [get_nets sensors393_i/sensor_channel_block\[3\].sensor_channel_i/sens_parallel12_i/ipclk_pre ]
  create_generated_clock -name iclk2x3  [get_nets sensors393_i/sensor_channel_block\[3\].sensor_channel_i/sens_parallel12_i/ipclk2x_pre ]

  set_clock_groups -name sensor0_clocks_iclk_pclk2x -asynchronous -group {iclk0 iclk2x0}
  set_clock_groups -name sensor1_clocks_iclk_pclk2x -asynchronous -group {iclk1 iclk2x1}
  set_clock_groups -name sensor2_clocks_iclk_pclk2x -asynchronous -group {iclk2 iclk2x2}
  set_clock_groups -name sensor3_clocks_iclk_pclk2x -asynchronous -group {iclk3 iclk2x3}
}

set_clock_groups -name compressor_clocks_xclk_xclk2x -asynchronous -group {xclk }
set_clock_groups -name sensor_clocks_pclk_pclk2x     -asynchronous -group {pclk}
set_clock_groups -name sync_logger_clocks_sclk       -asynchronous -group {sclk }

# do not check timing between axi_aclk and other clocks. Code should provide correct asynchronous crossing of the clock boundary.
set_clock_groups -name ps_async_clock                -asynchronous -group {axi_aclk}
set_clock_groups -name ps_async_clock_axihp          -asynchronous -group {axihp_clk}

set_clock_groups -name external_clock_ffclk0         -asynchronous -group {ffclk0}
