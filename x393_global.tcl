#################################################################################
# Filename: x393_global.tcl
# Date:2016-03-28
# Author: Andrey Filippov
# Description: Placement constraints (selected by HISPI parameter in system_devines.vh)
#
# Copyright (c) 2016 Elphel, Inc.
# x393_global.tcl is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
#  x393_global.tcl is distributed in the hope that it will be useful,
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
set LWIR 0
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
    puts "x393_global.tcl: using LWIR sensors"
} elseif { $HISPI} {
    puts "x393_global.tcl: using HISPI sensors"
} else {
    puts "x393_global.tcl: using parallel sensors"
}

# Global constraints

set_property INTERNAL_VREF  0.750 [get_iobanks 34]
set_property DCI_CASCADE 34 [get_iobanks 35]
set_property INTERNAL_VREF  0.750 [get_iobanks 35]
set_property CFGBVS GND [current_design]
set_property CONFIG_VOLTAGE 1.8 [current_design]

# Disabling some of the DRC checks:
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

#Some ports in some applications (sensors) are used as input-only or output-only while being specified as bidirectional
#WARNING: [DRC 23-20] Rule violation (RPBF-3) IO port buffering is incomplete - Device port sns4_dp74[7] expects both input and output buffering but the buffers are incomplete.
#WARNING: [DRC 23-20] Rule violation (RPBF-4) IO port buffering is incomplete - Device port SDDML expects output buffering but has an input buffer connected.
set_property is_enabled false [get_drc_checks RPBF-3]
set_property is_enabled false [get_drc_checks RPBF-4]


