#################################################################################
# Filename: x393_timing.xdc
# Date:2014-02-25  
# Author: Andrey Filippov
# Description: DDR3 controller test with axi constraints
#
# Copyright (c) 2015 Elphel, Inc.
# x393_timing.xdc is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
#  x393_timing.xdc is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/> .
#################################################################################

create_clock -name axi_aclk -period 20 [get_nets -hierarchical *axi_aclk]
#x393_i/mcntrl393_i/memcntrl16/mcontr_sequencer

#Clock        Period    Waveform           Attributes  Sources
#axi_aclk     10.00000  {0.00000 5.00000}  P           {bufg_axi_aclk_i/O}
#clk_fb       10.00000  {0.00000 5.00000}  P,G         {ddrc_sequencer_i/phy_cmd_i/phy_top_i/mmcm_phase_cntr_i/MMCME2_ADV_i/CLKFBOUT}
#sdclk_pre    2.50000   {0.00000 1.25000}  P,G         {ddrc_sequencer_i/phy_cmd_i/phy_top_i/mmcm_phase_cntr_i/MMCME2_ADV_i/CLKOUT0}
#clk_pre      2.50000   {0.00000 1.25000}  P,G         {ddrc_sequencer_i/phy_cmd_i/phy_top_i/mmcm_phase_cntr_i/MMCME2_ADV_i/CLKOUT1}
#clk_div_pre  5.00000   {0.00000 2.50000}  P,G         {ddrc_sequencer_i/phy_cmd_i/phy_top_i/mmcm_phase_cntr_i/MMCME2_ADV_i/CLKOUT2}
#mclk_pre     5.00000   {1.25000 3.75000}  P,G         {ddrc_sequencer_i/phy_cmd_i/phy_top_i/mmcm_phase_cntr_i/MMCME2_ADV_i/CLKOUT3}
#clkfb_ref    10.00000  {0.00000 5.00000}  P,G         {ddrc_sequencer_i/phy_cmd_i/phy_top_i/pll_base_i/PLLE2_BASE_i/CLKFBOUT}
#clk_ref_pre  3.33333   {0.00000 1.66667}  P,G         {ddrc_sequencer_i/phy_cmd_i/phy_top_i/pll_base_i/PLLE2_BASE_i/CLKOUT0}

#Each list contains 2 elements - warning later in DRC
#create_generated_clock -name ddr3_sdclk [get_nets -hierarchical sdclk_pre]
#create_generated_clock -name ddr3_clk [get_nets -hierarchical clk_pre]
#create_generated_clock -name ddr3_clk_div [get_nets -hierarchical clk_div_pre]
#create_generated_clock -name ddr3_mclk [get_nets -hierarchical mclk_pre]
#create_generated_clock -name ddr3_clk_ref [get_nets -hierarchical clk_ref_pre]

#Not available initially
#create_generated_clock -name ddr3_sdclk [get_nets ddrc_sequencer_i/phy_cmd_i/phy_top_i/mmcm_phase_cntr_i/sdclk_pre]
#create_generated_clock -name ddr3_clk [get_netsddrc_sequencer_i/phy_cmd_i/phy_top_i/mmcm_phase_cntr_i/clk_pre]
#create_generated_clock -name ddr3_clk_div [get_nets ddrc_sequencer_i/phy_cmd_i/phy_top_i/mmcm_phase_cntr_i/clk_div_pre]
#create_generated_clock -name ddr3_mclk [get_nets ddrc_sequencer_i/phy_cmd_i/phy_top_i/mmcm_phase_cntr_i/mclk_pre]
#create_generated_clock -name ddr3_clk_ref [get_nets ddrc_sequencer_i/phy_cmd_i/phy_top_i/pll_base_i/clk_ref_pre]

# try use first from list - seems that 2 are created from the same name 
# ddrc_sequencer_i/phy_cmd_i/phy_top_i/sdclk_pre
# ddrc_sequencer_i/phy_cmd_i/phy_top_i/mmcm_phase_cntr_i/sdclk_pre
# lindex is not supported in xdc
#create_generated_clock -name ddr3_sdclk [lindex [get_nets -hierarchical sdclk_pre] 0 ]
#create_generated_clock -name ddr3_clk [lindex [get_nets -hierarchical clk_pre] 0 ]
#create_generated_clock -name ddr3_clk_div [lindex [get_nets -hierarchical clk_div_pre] 0 ]
#create_generated_clock -name ddr3_mclk [lindex [get_nets -hierarchical mclk_pre] 0 ]
#create_generated_clock -name ddr3_clk_ref [lindex [get_nets -hierarchical clk_ref_pre] 0 ]

##create_generated_clock -name ddr3_sdclk [get_nets -hierarchical sdclk_pre -filter {NAME !~ */mmcm_phase_cntr_i*} ]
##create_generated_clock -name ddr3_clk [get_nets -hierarchical clk_pre -filter {NAME !~ */mmcm_phase_cntr_i*} ]
##create_generated_clock -name ddr3_clk_div [get_nets -hierarchical clk_div_pre -filter {NAME !~ */mmcm_phase_cntr_i*} ]
##create_generated_clock -name ddr3_mclk [get_nets -hierarchical mclk_pre -filter {NAME !~ */mmcm_phase_cntr_i*} ]
##create_generated_clock -name ddr3_clk_ref [get_nets -hierarchical clk_ref_pre -filter {NAME !~ */pll_base_i*} ]

### Version used with eddr3
###create_generated_clock -name ddr3_sdclk [get_nets */sdclk_pre ]
###create_generated_clock -name ddr3_clk [get_nets */clk_pre ]
###create_generated_clock -name ddr3_clk_div [get_nets */clk_div_pre ]
###create_generated_clock -name ddr3_mclk [get_nets */mclk_pre ]
###create_generated_clock -name ddr3_clk_ref [get_nets */clk_ref_pre]

create_generated_clock -name ddr3_sdclk [get_nets -hierarchical sdclk_pre ]
create_generated_clock -name ddr3_clk [get_nets -hierarchical clk_pre ]
create_generated_clock -name ddr3_clk_div [get_nets -hierarchical clk_div_pre ]
create_generated_clock -name ddr3_mclk [get_nets -hierarchical mclk_pre]
#create_generated_clock -name ddr3_clk_ref [get_nets -hierarchical clk_ref_pre ]
create_generated_clock -name ddr3_clk_ref [get_nets clocks393_i/dly_ref_clk_pre ]
#create_generated_clock -name axihp_clk [get_nets clocks393_i/dual_clock_axihp_i/clk1x_pre ]
create_generated_clock -name axihp_clk [get_nets clocks393_i/hclk_pre ]

#create_generated_clock -name xclk      [get_nets clocks393_i/dual_clock_xclk_i/clk1x_pre ]
create_generated_clock -name xclk      [get_nets clocks393_i/xclk_pre ]
#create_generated_clock -name xclk2x    [get_nets clocks393_i/dual_clock_xclk_i/clk2x_pre ]
#create_generated_clock -name xclk2x    [get_nets clocks393_i/xclk2x_pre ]

#clock for inter - camera synchronization and event logger
#create_generated_clock -name sclk      [get_nets clocks393_i/dual_clock_sync_clk_i/clk1x_pre ]
create_generated_clock -name sclk      [get_nets clocks393_i/sync_clk_pre ]

create_clock -name ffclk0 -period 41.667 [get_ports {ffclk0p}]
#Generated clocks are assumed to be tied to clkin1 (not 2), so until external ffclk0 is constrained, derivative clocks are not generated 
create_generated_clock -name pclk      [get_nets clocks393_i/dual_clock_pclk_i/clk1x_pre ]
#create_generated_clock -name pclk2x    [get_nets clocks393_i/dual_clock_pclk_i/clk2x_pre ]

#Sensor-synchronous clocks
create_generated_clock -name iclk0    [get_nets sensors393_i/sensor_channel_block\[0\].sensor_channel_i/sens_parallel12_i/ipclk_pre ]
create_generated_clock -name iclk2x0  [get_nets sensors393_i/sensor_channel_block\[0\].sensor_channel_i/sens_parallel12_i/ipclk2x_pre ]

create_generated_clock -name iclk1    [get_nets sensors393_i/sensor_channel_block\[1\].sensor_channel_i/sens_parallel12_i/ipclk_pre ]
create_generated_clock -name iclk2x1  [get_nets sensors393_i/sensor_channel_block\[1\].sensor_channel_i/sens_parallel12_i/ipclk2x_pre ]

create_generated_clock -name iclk2    [get_nets sensors393_i/sensor_channel_block\[2\].sensor_channel_i/sens_parallel12_i/ipclk_pre ]
create_generated_clock -name iclk2x2  [get_nets sensors393_i/sensor_channel_block\[2\].sensor_channel_i/sens_parallel12_i/ipclk2x_pre ]

create_generated_clock -name iclk3    [get_nets sensors393_i/sensor_channel_block\[3\].sensor_channel_i/sens_parallel12_i/ipclk_pre ]
create_generated_clock -name iclk2x3  [get_nets sensors393_i/sensor_channel_block\[3\].sensor_channel_i/sens_parallel12_i/ipclk2x_pre ]



# do not check timing between axi_aclk and other clocks. Code should provide correct asynchronous crossing of the clock boundary.
set_clock_groups -name ps_async_clock                 -asynchronous -group {axi_aclk}
# do not check timing between clk_axihp_pre and other clocks. Code should provide correct asynchronous crossing of the clock boundary.
set_clock_groups -name ps_async_clock_axihp          -asynchronous -group {axihp_clk}
#set_clock_groups -name compressor_clocks_xclk_xclk2x -asynchronous -group {xclk xclk2x}
#set_clock_groups -name sensor_clocks_pclk_pclk2x     -asynchronous -group {pclk pclk2x}
set_clock_groups -name compressor_clocks_xclk_xclk2x -asynchronous -group {xclk }
set_clock_groups -name sensor_clocks_pclk_pclk2x     -asynchronous -group {pclk}

set_clock_groups -name sync_logger_clocks_sclk       -asynchronous -group {sclk }

set_clock_groups -name sensor0_clocks_iclk_pclk2x -asynchronous -group {iclk0 iclk2x0}
set_clock_groups -name sensor1_clocks_iclk_pclk2x -asynchronous -group {iclk1 iclk2x1}
set_clock_groups -name sensor2_clocks_iclk_pclk2x -asynchronous -group {iclk2 iclk2x2}
set_clock_groups -name sensor3_clocks_iclk_pclk2x -asynchronous -group {iclk3 iclk2x3}

set_clock_groups -name external_clock_ffclk0 -asynchronous -group {ffclk0}