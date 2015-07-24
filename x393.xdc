#################################################################################
# Filename: x393.xdc
# Date:2014-02-25  
# Author: Andrey Filippov
# Description: Elphel x393 camera constraints
#
# Copyright (c) 2015 Elphel, Inc.
# x393.xdc is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
#  x393.xdc is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/> .
#################################################################################

#http://forums.xilinx.com/t5/7-Series-FPGAs/MMCM-reference-clock-muxing/td-p/550622
set_property is_enabled false [get_drc_checks REQP-119]
#Input Buffer Connections .. has no loads. An input buffer must drive an internal load.
set_property is_enabled false [get_drc_checks BUFC-1]
#DSP Buffering:
set_property is_enabled false [get_drc_checks DPIP-1]
set_property is_enabled false [get_drc_checks DPOP-1]
#MMCME2_ADV connectivity violation
set_property is_enabled false [get_drc_checks REQP-1577]
#Synchronous clocking for BRAM (mult_saxi_wr_inbuf_i/ram_var_w_var_r_i/ram_i/RAMB36E1_i) in SDP mode ...
set_property is_enabled false [get_drc_checks REQP-165]

#Useless input. The input pins CE and CLR are not used for BUFR_DIVIDE BYPASS.
set_property is_enabled false [get_drc_checks REQP-14]


#    output                       SDRST, // output SDRST, active low
set_property IOSTANDARD SSTL15 [get_ports {SDRST}]
set_property PACKAGE_PIN J4 [get_ports {SDRST}]

#    output                       SDCLK, // DDR3 clock differential output, positive
set_property IOSTANDARD DIFF_SSTL15 [get_ports {SDCLK}]
set_property PACKAGE_PIN K3 [get_ports {SDCLK}]

#    output                       SDNCLK,// DDR3 clock differential output, negative
set_property IOSTANDARD DIFF_SSTL15 [get_ports {SDNCLK}]
set_property PACKAGE_PIN K2 [get_ports {SDNCLK}]

#    output  [ADDRESS_NUMBER-1:0] SDA,   // output address ports (14:0) for 4Gb device
set_property IOSTANDARD SSTL15 [get_ports {SDA[0]}]
set_property PACKAGE_PIN N3 [get_ports {SDA[0]}]

set_property IOSTANDARD SSTL15 [get_ports {SDA[1]}]
set_property PACKAGE_PIN H2 [get_ports {SDA[1]}]

set_property IOSTANDARD SSTL15 [get_ports {SDA[2]}]
set_property PACKAGE_PIN M2 [get_ports {SDA[2]}]

set_property IOSTANDARD SSTL15 [get_ports {SDA[3]}]
set_property PACKAGE_PIN P5 [get_ports {SDA[3]}]

set_property IOSTANDARD SSTL15 [get_ports {SDA[4]}]
set_property PACKAGE_PIN H1 [get_ports {SDA[4]}]

set_property IOSTANDARD SSTL15 [get_ports {SDA[5]}]
set_property PACKAGE_PIN M3 [get_ports {SDA[5]}]

set_property IOSTANDARD SSTL15 [get_ports {SDA[6]}]
set_property PACKAGE_PIN J1 [get_ports {SDA[6]}]

set_property IOSTANDARD SSTL15 [get_ports {SDA[7]}]
set_property PACKAGE_PIN P4 [get_ports {SDA[7]}]

set_property IOSTANDARD SSTL15 [get_ports {SDA[8]}]
set_property PACKAGE_PIN K1 [get_ports {SDA[8]}]

set_property IOSTANDARD SSTL15 [get_ports {SDA[9]}]
set_property PACKAGE_PIN P3 [get_ports {SDA[9]}]

set_property IOSTANDARD SSTL15 [get_ports {SDA[10]}]
set_property PACKAGE_PIN F2 [get_ports {SDA[10]}]

set_property IOSTANDARD SSTL15 [get_ports {SDA[11]}]
set_property PACKAGE_PIN H3 [get_ports {SDA[11]}]

set_property IOSTANDARD SSTL15 [get_ports {SDA[12]}]
set_property PACKAGE_PIN G3 [get_ports {SDA[12]}]

set_property IOSTANDARD SSTL15 [get_ports {SDA[13]}]
set_property PACKAGE_PIN N2 [get_ports {SDA[13]}]

set_property IOSTANDARD SSTL15 [get_ports {SDA[14]}]
set_property PACKAGE_PIN J3 [get_ports {SDA[14]}]


#    output                 [2:0] SDBA,  // output bank address ports
set_property IOSTANDARD SSTL15 [get_ports {SDBA[0]}]
set_property PACKAGE_PIN N1 [get_ports {SDBA[0]}]

set_property IOSTANDARD SSTL15 [get_ports {SDBA[1]}]
set_property PACKAGE_PIN F1 [get_ports {SDBA[1]}]

set_property IOSTANDARD SSTL15 [get_ports {SDBA[2]}]
set_property PACKAGE_PIN P1 [get_ports {SDBA[2]}]

#    output                       SDWE,  // output WE port
set_property IOSTANDARD SSTL15 [get_ports {SDWE}]
set_property PACKAGE_PIN G4 [get_ports {SDWE}]

#    output                       SDRAS, // output RAS port
set_property IOSTANDARD SSTL15 [get_ports {SDRAS}]
set_property PACKAGE_PIN L2 [get_ports {SDRAS}]

#    output                       SDCAS, // output CAS port
set_property IOSTANDARD SSTL15 [get_ports {SDCAS}]
set_property PACKAGE_PIN L1 [get_ports {SDCAS}]

#    output                       SDCKE, // output Clock Enable port
set_property IOSTANDARD SSTL15 [get_ports {SDCKE}]
set_property PACKAGE_PIN E1 [get_ports {SDCKE}]

#    output                       SDODT, // output ODT port
set_property IOSTANDARD SSTL15 [get_ports {SDODT}]
set_property PACKAGE_PIN M7 [get_ports {SDODT}]
#

#    inout                 [15:0] SDD,       // DQ  I/O pads
set_property IOSTANDARD SSTL15_T_DCI [get_ports {SDD[0]}]
set_property PACKAGE_PIN K6 [get_ports {SDD[0]}]

#    inout                 [15:0] SDD,       // DQ  I/O pads
set_property IOSTANDARD SSTL15_T_DCI [get_ports {SDD[1]}]
set_property PACKAGE_PIN L4 [get_ports {SDD[1]}]

#    inout                 [15:0] SDD,       // DQ  I/O pads
set_property IOSTANDARD SSTL15_T_DCI [get_ports {SDD[2]}]
set_property PACKAGE_PIN K7 [get_ports {SDD[2]}]

#    inout                 [15:0] SDD,       // DQ  I/O pads
set_property IOSTANDARD SSTL15_T_DCI [get_ports {SDD[3]}]
set_property PACKAGE_PIN K4 [get_ports {SDD[3]}]

#    inout                 [15:0] SDD,       // DQ  I/O pads
set_property IOSTANDARD SSTL15_T_DCI [get_ports {SDD[4]}]
set_property PACKAGE_PIN L6 [get_ports {SDD[4]}]

#    inout                 [15:0] SDD,       // DQ  I/O pads
set_property IOSTANDARD SSTL15_T_DCI [get_ports {SDD[5]}]
set_property PACKAGE_PIN M4 [get_ports {SDD[5]}]

#    inout                 [15:0] SDD,       // DQ  I/O pads
set_property IOSTANDARD SSTL15_T_DCI [get_ports {SDD[6]}]
set_property PACKAGE_PIN L7 [get_ports {SDD[6]}]

#    inout                 [15:0] SDD,       // DQ  I/O pads
set_property IOSTANDARD SSTL15_T_DCI [get_ports {SDD[7]}]
set_property PACKAGE_PIN N5 [get_ports {SDD[7]}]

#    inout                 [15:0] SDD,       // DQ  I/O pads
set_property IOSTANDARD SSTL15_T_DCI [get_ports {SDD[8]}]
set_property PACKAGE_PIN H5 [get_ports {SDD[8]}]

#    inout                 [15:0] SDD,       // DQ  I/O pads
set_property IOSTANDARD SSTL15_T_DCI [get_ports {SDD[9]}]
set_property PACKAGE_PIN J6 [get_ports {SDD[9]}]

#    inout                 [15:0] SDD,       // DQ  I/O pads
set_property IOSTANDARD SSTL15_T_DCI [get_ports {SDD[10]}]
set_property PACKAGE_PIN G5 [get_ports {SDD[10]}]

#    inout                 [15:0] SDD,       // DQ  I/O pads
set_property IOSTANDARD SSTL15_T_DCI [get_ports {SDD[11]}]
set_property PACKAGE_PIN H6 [get_ports {SDD[11]}]

#    inout                 [15:0] SDD,       // DQ  I/O pads
set_property IOSTANDARD SSTL15_T_DCI [get_ports {SDD[12]}]
set_property PACKAGE_PIN F5 [get_ports {SDD[12]}]

#    inout                 [15:0] SDD,       // DQ  I/O pads
set_property IOSTANDARD SSTL15_T_DCI [get_ports {SDD[13]}]
set_property PACKAGE_PIN F7 [get_ports {SDD[13]}]

#    inout                 [15:0] SDD,       // DQ  I/O pads
set_property IOSTANDARD SSTL15_T_DCI [get_ports {SDD[14]}]
set_property PACKAGE_PIN F4 [get_ports {SDD[14]}]

#    inout                 [15:0] SDD,       // DQ  I/O pads
set_property IOSTANDARD SSTL15_T_DCI [get_ports {SDD[15]}]
set_property PACKAGE_PIN F6 [get_ports {SDD[15]}]

#    inout                        DQSL,     // LDQS I/O pad
set_property PACKAGE_PIN N7 [get_ports {DQSL}]
#set_property SLEW FAST [get_ports {DQSL}]
set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports {DQSL}]

#    inout                        NDQSL,    // ~LDQS I/O pad
set_property PACKAGE_PIN N6 [get_ports {NDQSL}]
#set_property SLEW FAST [get_ports {NDQSL}]
set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports {NDQSL}]

#    inout                        DQSU,     // UDQS I/O pad
set_property PACKAGE_PIN H7 [get_ports {DQSU}]
#set_property SLEW FAST [get_ports {DQSU}]
set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports {DQSU}]

#    inout                        NDQSU,    // ~UDQS I/O pad
set_property PACKAGE_PIN G7 [get_ports {NDQSU}]
#set_property SLEW FAST [get_ports {NDQSU}]
set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports {NDQSU}]

#    inout                        SDDML,      // LDM  I/O pad (actually only output)
#set_property IOSTANDARD SSTL15_T_DCI [get_ports {SDDML}]
set_property IOSTANDARD SSTL15 [get_ports {SDDML}]
set_property PACKAGE_PIN L5 [get_ports {SDDML}]

#    inout                        SDDMU,      // UDM  I/O pad (actually only output)
#set_property IOSTANDARD SSTL15_T_DCI [get_ports {SDDMU}]
set_property IOSTANDARD SSTL15 [get_ports {SDDMU}]
set_property PACKAGE_PIN J5 [get_ports {SDDMU}]

#    output                      DUMMY_TO_KEEP,  // to keep PS7 signals from "optimization"
set_property IOSTANDARD LVCMOS25 [get_ports {DUMMY_TO_KEEP}]
set_property PACKAGE_PIN T11 [get_ports {DUMMY_TO_KEEP}]

#not yet used, just for debugging
#    input                      memclk,
#set_property IOSTANDARD SSTL15 [get_ports {memclk}]
set_property PACKAGE_PIN M5 [get_ports {memclk}]


# ======== GPIO pins ===============
#    inout           [GPIO_N-1:0] gpio_pins,
set_property PACKAGE_PIN B4   [get_ports {gpio_pins[0]}]
set_property PACKAGE_PIN A4   [get_ports {gpio_pins[1]}]
set_property PACKAGE_PIN A2   [get_ports {gpio_pins[2]}]
set_property PACKAGE_PIN A1   [get_ports {gpio_pins[3]}]
set_property PACKAGE_PIN C3   [get_ports {gpio_pins[4]}]
set_property PACKAGE_PIN D3   [get_ports {gpio_pins[5]}]
set_property PACKAGE_PIN D1   [get_ports {gpio_pins[6]}]
set_property PACKAGE_PIN C1   [get_ports {gpio_pins[7]}]
set_property PACKAGE_PIN C2   [get_ports {gpio_pins[8]}]
set_property PACKAGE_PIN B2   [get_ports {gpio_pins[9]}]

# =========Differential clock inputs ==========
#    input                        ffclk0p, // Y12
#    input                        ffclk0n, // Y11
#    input                        ffclk1p, // W14
#    input                        ffclk1n  // W13
set_property PACKAGE_PIN Y12  [get_ports {ffclk0p}]
set_property PACKAGE_PIN Y11  [get_ports {ffclk0n}]
set_property PACKAGE_PIN W14  [get_ports {ffclk1p}]
set_property PACKAGE_PIN W13  [get_ports {ffclk1n}]


# Global constraints

set_property INTERNAL_VREF  0.750 [get_iobanks 34]
set_property DCI_CASCADE 34 [get_iobanks 35]
set_property INTERNAL_VREF  0.750 [get_iobanks 35]
set_property CFGBVS GND [current_design]
set_property CONFIG_VOLTAGE 1.8 [current_design]

# ================= Sensor port 0 =================
#        inout                  [7:0] sns1_dp,
#        inout                  [7:0] sns1_dn,
set_property PACKAGE_PIN T10  [get_ports {sns1_dp[0]}]
set_property PACKAGE_PIN T9   [get_ports {sns1_dn[0]}]

set_property PACKAGE_PIN U10  [get_ports {sns1_dp[1]}]
set_property PACKAGE_PIN V10  [get_ports {sns1_dn[1]}]

set_property PACKAGE_PIN V8   [get_ports {sns1_dp[2]}]
set_property PACKAGE_PIN W8   [get_ports {sns1_dn[2]}]

set_property PACKAGE_PIN W9   [get_ports {sns1_dp[3]}]
set_property PACKAGE_PIN Y8   [get_ports {sns1_dn[3]}]

set_property PACKAGE_PIN AB9  [get_ports {sns1_dp[4]}]
set_property PACKAGE_PIN AB8  [get_ports {sns1_dn[4]}]

set_property PACKAGE_PIN AB13 [get_ports {sns1_dp[5]}]
set_property PACKAGE_PIN AB12 [get_ports {sns1_dn[5]}]

set_property PACKAGE_PIN AA12 [get_ports {sns1_dp[6]}]
set_property PACKAGE_PIN AA11 [get_ports {sns1_dn[6]}]

set_property PACKAGE_PIN W11  [get_ports {sns1_dp[7]}]
set_property PACKAGE_PIN W10  [get_ports {sns1_dn[7]}]
#    inout                        sns1_clkp,
#    inout                        sns1_clkn,
set_property PACKAGE_PIN AA10 [get_ports {sns1_clkp}]
set_property PACKAGE_PIN AB10 [get_ports {sns1_clkn}]
#    inout                        sns1_scl,
#    inout                        sns1_sda,
set_property PACKAGE_PIN Y9   [get_ports {sns1_scl}]
set_property PACKAGE_PIN AA9  [get_ports {sns1_sda}]
#    inout                        sns1_ctl,
#    inout                        sns1_pg,
set_property PACKAGE_PIN U9   [get_ports {sns1_ctl}]
set_property PACKAGE_PIN U8   [get_ports {sns1_pg}]


# ================= Sensor port 1 =================
#        inout                  [7:0] sns2_dp,
#        inout                  [7:0] sns2_dn,
set_property PACKAGE_PIN U15  [get_ports {sns2_dp[0]}]
set_property PACKAGE_PIN U14   [get_ports {sns2_dn[0]}]

set_property PACKAGE_PIN V15  [get_ports {sns2_dp[1]}]
set_property PACKAGE_PIN W15  [get_ports {sns2_dn[1]}]

set_property PACKAGE_PIN U13  [get_ports {sns2_dp[2]}]
set_property PACKAGE_PIN V13  [get_ports {sns2_dn[2]}]

set_property PACKAGE_PIN V12  [get_ports {sns2_dp[3]}]
set_property PACKAGE_PIN V11  [get_ports {sns2_dn[3]}]

set_property PACKAGE_PIN AA17 [get_ports {sns2_dp[4]}]
set_property PACKAGE_PIN AB17 [get_ports {sns2_dn[4]}]

set_property PACKAGE_PIN AA15 [get_ports {sns2_dp[5]}]
set_property PACKAGE_PIN AB15 [get_ports {sns2_dn[5]}]

set_property PACKAGE_PIN AA14 [get_ports {sns2_dp[6]}]
set_property PACKAGE_PIN AB14 [get_ports {sns2_dn[6]}]

set_property PACKAGE_PIN Y14  [get_ports {sns2_dp[7]}]
set_property PACKAGE_PIN Y13  [get_ports {sns2_dn[7]}]
#    inout                        sns2_clkp,
#    inout                        sns2_clkn,
set_property PACKAGE_PIN Y16  [get_ports {sns2_clkp}]
set_property PACKAGE_PIN AA16 [get_ports {sns2_clkn}]
#    inout                        sns2_scl,
#    inout                        sns2_sda,
set_property PACKAGE_PIN T12  [get_ports {sns2_scl}]
set_property PACKAGE_PIN U12  [get_ports {sns2_sda}]
#    inout                        sns2_ctl,
#    inout                        sns2_pg,
set_property PACKAGE_PIN V16  [get_ports {sns2_ctl}]
set_property PACKAGE_PIN W16  [get_ports {sns2_pg}]

# ================= Sensor port 2 =================
#        inout                  [7:0] sns3_dp,
#        inout                  [7:0] sns3_dn,
set_property PACKAGE_PIN AA22 [get_ports {sns3_dp[0]}]
set_property PACKAGE_PIN AB22 [get_ports {sns3_dn[0]}]

set_property PACKAGE_PIN W21  [get_ports {sns3_dp[1]}]
set_property PACKAGE_PIN Y22  [get_ports {sns3_dn[1]}]

set_property PACKAGE_PIN V21  [get_ports {sns3_dp[2]}]
set_property PACKAGE_PIN V22  [get_ports {sns3_dn[2]}]

set_property PACKAGE_PIN W19  [get_ports {sns3_dp[3]}]
set_property PACKAGE_PIN W20  [get_ports {sns3_dn[3]}]

set_property PACKAGE_PIN N21  [get_ports {sns3_dp[4]}]
set_property PACKAGE_PIN N22  [get_ports {sns3_dn[4]}]

set_property PACKAGE_PIN R22  [get_ports {sns3_dp[5]}]
set_property PACKAGE_PIN T22  [get_ports {sns3_dn[5]}]

set_property PACKAGE_PIN P21  [get_ports {sns3_dp[6]}]
set_property PACKAGE_PIN R21  [get_ports {sns3_dn[6]}]

set_property PACKAGE_PIN T20  [get_ports {sns3_dp[7]}]
set_property PACKAGE_PIN U20  [get_ports {sns3_dn[7]}]
#    inout                        sns3_clkp,
#    inout                        sns3_clkn,
set_property PACKAGE_PIN T21  [get_ports {sns3_clkp}]
set_property PACKAGE_PIN U22  [get_ports {sns3_clkn}]
#    inout                        sns3_scl,
#    inout                        sns3_sda,
set_property PACKAGE_PIN Y21  [get_ports {sns3_scl}]
set_property PACKAGE_PIN AA21 [get_ports {sns3_sda}]
#    inout                        sns3_ctl,
#    inout                        sns3_pg,
set_property PACKAGE_PIN AA20 [get_ports {sns3_ctl}]
set_property PACKAGE_PIN AB20 [get_ports {sns3_pg}]

# ================= Sensor port 3 =================
#        inout                  [7:0] sns4_dp,
#        inout                  [7:0] sns4_dn,
set_property PACKAGE_PIN V17  [get_ports {sns4_dp[0]}]
set_property PACKAGE_PIN W18  [get_ports {sns4_dn[0]}]

set_property PACKAGE_PIN Y19  [get_ports {sns4_dp[1]}]
set_property PACKAGE_PIN AA19 [get_ports {sns4_dn[1]}]

set_property PACKAGE_PIN U19  [get_ports {sns4_dp[2]}]
set_property PACKAGE_PIN V20  [get_ports {sns4_dn[2]}]

set_property PACKAGE_PIN U18  [get_ports {sns4_dp[3]}]
set_property PACKAGE_PIN V18  [get_ports {sns4_dn[3]}]

set_property PACKAGE_PIN P18  [get_ports {sns4_dp[4]}]
set_property PACKAGE_PIN P19  [get_ports {sns4_dn[4]}]

set_property PACKAGE_PIN N17  [get_ports {sns4_dp[5]}]
set_property PACKAGE_PIN N18  [get_ports {sns4_dn[5]}]

set_property PACKAGE_PIN N20  [get_ports {sns4_dp[6]}]
set_property PACKAGE_PIN P20  [get_ports {sns4_dn[6]}]

set_property PACKAGE_PIN R17  [get_ports {sns4_dp[7]}]
set_property PACKAGE_PIN R18  [get_ports {sns4_dn[7]}]
#    inout                        sns4_clkp,
#    inout                        sns4_clkn,
set_property PACKAGE_PIN R16  [get_ports {sns4_clkp}]
set_property PACKAGE_PIN T16  [get_ports {sns4_clkn}]
#    inout                        sns4_scl,
#    inout                        sns4_sda,
set_property PACKAGE_PIN AB18 [get_ports {sns4_scl}]
set_property PACKAGE_PIN AB19 [get_ports {sns4_sda}]
#    inout                        sns4_ctl,
#    inout                        sns4_pg,
set_property PACKAGE_PIN Y17  [get_ports {sns4_ctl}]
set_property PACKAGE_PIN Y18  [get_ports {sns4_pg}]
#ERROR: [Place 30-149] Unroutable Placement! A MMCM / (BUFIO/BUFR) component pair is not placed in a routable site pair.
# The MMCM component can use the dedicated path between the MMCM and the (BUFIO/BUFR) if both are placed in the same clock
# region or if they are placed in horizontally adjacent clock regions. If this sub optimal condition is acceptable
# for this design, you may use the CLOCK_DEDICATED_ROUTE constraint in the .xdc file to demote this message to a WARNING.
# However, the use of this override is highly discouraged. These examples can be used directly in the .xdc file to override this clock rule.

set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets sensors393_i/sensor_channel_block[0].sensor_channel_i/sens_parallel12_i/mmcm_phase_cntr_i/clkout0]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets sensors393_i/sensor_channel_block[1].sensor_channel_i/sens_parallel12_i/mmcm_phase_cntr_i/clkout0]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets sensors393_i/sensor_channel_block[2].sensor_channel_i/sens_parallel12_i/mmcm_phase_cntr_i/clkout0]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets sensors393_i/sensor_channel_block[3].sensor_channel_i/sens_parallel12_i/mmcm_phase_cntr_i/clkout0]

set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets sensors393_i/sensor_channel_block[0].sensor_channel_i/sens_parallel12_i/mmcm_phase_cntr_i/clkout1]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets sensors393_i/sensor_channel_block[1].sensor_channel_i/sens_parallel12_i/mmcm_phase_cntr_i/clkout1]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets sensors393_i/sensor_channel_block[2].sensor_channel_i/sens_parallel12_i/mmcm_phase_cntr_i/clkout1]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets sensors393_i/sensor_channel_block[3].sensor_channel_i/sens_parallel12_i/mmcm_phase_cntr_i/clkout1]