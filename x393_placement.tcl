#################################################################################
# Filename: x393_placement.tcl
# Date:2016-03-28
# Author: Andrey Filippov
# Description: Placementg constraints (selected by HISPI parameter in system_devines.vh)
#
# Copyright (c) 2016 Elphel, Inc.
# x393_placement.tcl is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
#  x393_placement.tcl is distributed in the hope that it will be useful,
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

set BOSON 0
seek $infile 0 start
while { [gets $infile line] >= 0 } {
    if { [regexp {(.*)`define(\s*)BOSON} $line matched prematch] } {
	if {[regexp "//" $prematch] != 0} { continue }
	puts $line
	if {[regexp {(.*)`define(\s*)BOSON_REVA} $line matched prematch] } { continue }    
	set BOSON 1
	break
    }
}

close $infile
if       { $LWIR} {
    puts "x393_placement.tcl: using LWIR sensors"
} elseif { $HISPI} {
    puts "x393_placement.tcl: using HISPI sensors"
} elseif { $BOSON} {
    puts "x393_placement.tcl: using Boson640 sensors"
} else {
    puts "x393_placement.tcl: using parallel sensors"
}
#Placement constraints (I/O pads)
set_property PACKAGE_PIN J4 [get_ports {SDRST}]
set_property PACKAGE_PIN K3 [get_ports {SDCLK}]
set_property PACKAGE_PIN K2 [get_ports {SDNCLK}]
set_property PACKAGE_PIN N3 [get_ports {SDA[0]}]
set_property PACKAGE_PIN H2 [get_ports {SDA[1]}]
set_property PACKAGE_PIN M2 [get_ports {SDA[2]}]
set_property PACKAGE_PIN P5 [get_ports {SDA[3]}]
set_property PACKAGE_PIN H1 [get_ports {SDA[4]}]
set_property PACKAGE_PIN M3 [get_ports {SDA[5]}]
set_property PACKAGE_PIN J1 [get_ports {SDA[6]}]
set_property PACKAGE_PIN P4 [get_ports {SDA[7]}]
set_property PACKAGE_PIN K1 [get_ports {SDA[8]}]
set_property PACKAGE_PIN P3 [get_ports {SDA[9]}]
set_property PACKAGE_PIN F2 [get_ports {SDA[10]}]
set_property PACKAGE_PIN H3 [get_ports {SDA[11]}]
set_property PACKAGE_PIN G3 [get_ports {SDA[12]}]
set_property PACKAGE_PIN N2 [get_ports {SDA[13]}]
set_property PACKAGE_PIN J3 [get_ports {SDA[14]}]
set_property PACKAGE_PIN N1 [get_ports {SDBA[0]}]
set_property PACKAGE_PIN F1 [get_ports {SDBA[1]}]
set_property PACKAGE_PIN P1 [get_ports {SDBA[2]}]
set_property PACKAGE_PIN G4 [get_ports {SDWE}]
set_property PACKAGE_PIN L2 [get_ports {SDRAS}]
set_property PACKAGE_PIN L1 [get_ports {SDCAS}]
set_property PACKAGE_PIN E1 [get_ports {SDCKE}]
set_property PACKAGE_PIN M7 [get_ports {SDODT}]
set_property PACKAGE_PIN K6 [get_ports {SDD[0]}]
set_property PACKAGE_PIN L4 [get_ports {SDD[1]}]
set_property PACKAGE_PIN K7 [get_ports {SDD[2]}]
set_property PACKAGE_PIN K4 [get_ports {SDD[3]}]
set_property PACKAGE_PIN L6 [get_ports {SDD[4]}]
set_property PACKAGE_PIN M4 [get_ports {SDD[5]}]
set_property PACKAGE_PIN L7 [get_ports {SDD[6]}]
set_property PACKAGE_PIN N5 [get_ports {SDD[7]}]
set_property PACKAGE_PIN H5 [get_ports {SDD[8]}]
set_property PACKAGE_PIN J6 [get_ports {SDD[9]}]
set_property PACKAGE_PIN G5 [get_ports {SDD[10]}]
set_property PACKAGE_PIN H6 [get_ports {SDD[11]}]
set_property PACKAGE_PIN F5 [get_ports {SDD[12]}]
set_property PACKAGE_PIN F7 [get_ports {SDD[13]}]
set_property PACKAGE_PIN F4 [get_ports {SDD[14]}]
set_property PACKAGE_PIN F6 [get_ports {SDD[15]}]
set_property PACKAGE_PIN N7 [get_ports {DQSL}]
set_property PACKAGE_PIN N6 [get_ports {NDQSL}]
set_property PACKAGE_PIN H7 [get_ports {DQSU}]
set_property PACKAGE_PIN G7 [get_ports {NDQSU}]
set_property PACKAGE_PIN L5 [get_ports {SDDML}]
set_property PACKAGE_PIN J5 [get_ports {SDDMU}]

#not yet used, just for debugging
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



# ================= Sensor port 0 =================
# BOSON same as HISPI
if { $BOSON } {
    set_property PACKAGE_PIN T10  [get_ports {sns1_dp[0]}]
    set_property PACKAGE_PIN T9   [get_ports {sns1_dn[0]}]
    set_property PACKAGE_PIN U10  [get_ports {sns1_dp[1]}]
    set_property PACKAGE_PIN V10  [get_ports {sns1_dn[1]}]
    set_property PACKAGE_PIN V8   [get_ports {sns1_dp[2]}]
    set_property PACKAGE_PIN W8   [get_ports {sns1_dn[2]}]
    set_property PACKAGE_PIN W9   [get_ports {sns1_dp[3]}]
    set_property PACKAGE_PIN Y8   [get_ports {sns1_dn[3]}]
    set_property PACKAGE_PIN AB9  [get_ports {sns1_dp74[4]}]
    set_property PACKAGE_PIN AB8  [get_ports {sns1_dn74[4]}]
    set_property PACKAGE_PIN AB13 [get_ports {sns1_dp74[5]}]
    set_property PACKAGE_PIN AB12 [get_ports {sns1_dn74[5]}]
    set_property PACKAGE_PIN AA12 [get_ports {sns1_dp74[6]}]
    set_property PACKAGE_PIN AA11 [get_ports {sns1_dn74[6]}]
    set_property PACKAGE_PIN W11  [get_ports {sns1_dp74[7]}]
    set_property PACKAGE_PIN W10  [get_ports {sns1_dn74[7]}]
} elseif { $LWIR } {
  set_property PACKAGE_PIN T10  [get_ports {sns1_dp40[0]}]
  set_property PACKAGE_PIN T9   [get_ports {sns1_dn40[0]}]
  set_property PACKAGE_PIN U10  [get_ports {sns1_dp40[1]}]
  set_property PACKAGE_PIN V10  [get_ports {sns1_dn40[1]}]
  set_property PACKAGE_PIN V8   [get_ports {sns1_dp40[2]}]
  set_property PACKAGE_PIN W8   [get_ports {sns1_dn40[2]}]
  set_property PACKAGE_PIN W9   [get_ports {sns1_dp40[3]}]
  set_property PACKAGE_PIN Y8   [get_ports {sns1_dn40[3]}]
  set_property PACKAGE_PIN AB9  [get_ports {sns1_dp40[4]}]
  set_property PACKAGE_PIN AB8  [get_ports {sns1_dn40[4]}]
  set_property PACKAGE_PIN AB13 [get_ports {sns1_dp5}]
  set_property PACKAGE_PIN AB12 [get_ports {sns1_dn5}]
  set_property PACKAGE_PIN AA12 [get_ports {sns1_dp76[6]}]
  set_property PACKAGE_PIN AA11 [get_ports {sns1_dn76[6]}]
  set_property PACKAGE_PIN W11  [get_ports {sns1_dp76[7]}]
  set_property PACKAGE_PIN W10  [get_ports {sns1_dn76[7]}]
} elseif { $HISPI } {
  set_property PACKAGE_PIN T10  [get_ports {sns1_dp[0]}]
  set_property PACKAGE_PIN T9   [get_ports {sns1_dn[0]}]
  set_property PACKAGE_PIN U10  [get_ports {sns1_dp[1]}]
  set_property PACKAGE_PIN V10  [get_ports {sns1_dn[1]}]
  set_property PACKAGE_PIN V8   [get_ports {sns1_dp[2]}]
  set_property PACKAGE_PIN W8   [get_ports {sns1_dn[2]}]
  set_property PACKAGE_PIN W9   [get_ports {sns1_dp[3]}]
  set_property PACKAGE_PIN Y8   [get_ports {sns1_dn[3]}]
  set_property PACKAGE_PIN AB9  [get_ports {sns1_dp74[4]}]
  set_property PACKAGE_PIN AB8  [get_ports {sns1_dn74[4]}]
  set_property PACKAGE_PIN AB13 [get_ports {sns1_dp74[5]}]
  set_property PACKAGE_PIN AB12 [get_ports {sns1_dn74[5]}]
  set_property PACKAGE_PIN AA12 [get_ports {sns1_dp74[6]}]
  set_property PACKAGE_PIN AA11 [get_ports {sns1_dn74[6]}]
  set_property PACKAGE_PIN W11  [get_ports {sns1_dp74[7]}]
  set_property PACKAGE_PIN W10  [get_ports {sns1_dn74[7]}]
} else {
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
}
set_property PACKAGE_PIN AA10 [get_ports {sns1_clkp}]
set_property PACKAGE_PIN AB10 [get_ports {sns1_clkn}]
set_property PACKAGE_PIN Y9   [get_ports {sns1_scl}]
set_property PACKAGE_PIN AA9  [get_ports {sns1_sda}]
set_property PACKAGE_PIN U9   [get_ports {sns1_ctl}]
set_property PACKAGE_PIN U8   [get_ports {sns1_pg}]


# ================= Sensor port 1 =================
# BOSON same as HISPI
if { $BOSON } {
    set_property PACKAGE_PIN U15  [get_ports {sns2_dp[0]}]
    set_property PACKAGE_PIN U14  [get_ports {sns2_dn[0]}]
    set_property PACKAGE_PIN V15  [get_ports {sns2_dp[1]}]
    set_property PACKAGE_PIN W15  [get_ports {sns2_dn[1]}]
    set_property PACKAGE_PIN U13  [get_ports {sns2_dp[2]}]
    set_property PACKAGE_PIN V13  [get_ports {sns2_dn[2]}]
    set_property PACKAGE_PIN V12  [get_ports {sns2_dp[3]}]
    set_property PACKAGE_PIN V11  [get_ports {sns2_dn[3]}]
    set_property PACKAGE_PIN AA17 [get_ports {sns2_dp74[4]}]
    set_property PACKAGE_PIN AB17 [get_ports {sns2_dn74[4]}]
    set_property PACKAGE_PIN AA15 [get_ports {sns2_dp74[5]}]
    set_property PACKAGE_PIN AB15 [get_ports {sns2_dn74[5]}]
    set_property PACKAGE_PIN AA14 [get_ports {sns2_dp74[6]}]
    set_property PACKAGE_PIN AB14 [get_ports {sns2_dn74[6]}]
    set_property PACKAGE_PIN Y14  [get_ports {sns2_dp74[7]}]
    set_property PACKAGE_PIN Y13  [get_ports {sns2_dn74[7]}]
} elseif { $LWIR } {
  set_property PACKAGE_PIN U15  [get_ports {sns2_dp40[0]}]
  set_property PACKAGE_PIN U14  [get_ports {sns2_dn40[0]}]
  set_property PACKAGE_PIN V15  [get_ports {sns2_dp40[1]}]
  set_property PACKAGE_PIN W15  [get_ports {sns2_dn40[1]}]
  set_property PACKAGE_PIN U13  [get_ports {sns2_dp40[2]}]
  set_property PACKAGE_PIN V13  [get_ports {sns2_dn40[2]}]
  set_property PACKAGE_PIN V12  [get_ports {sns2_dp40[3]}]
  set_property PACKAGE_PIN V11  [get_ports {sns2_dn40[3]}]
  set_property PACKAGE_PIN AA17 [get_ports {sns2_dp40[4]}]
  set_property PACKAGE_PIN AB17 [get_ports {sns2_dn40[4]}]
  set_property PACKAGE_PIN AA15 [get_ports {sns2_dp5}]
  set_property PACKAGE_PIN AB15 [get_ports {sns2_dn5}]
  set_property PACKAGE_PIN AA14 [get_ports {sns2_dp76[6]}]
  set_property PACKAGE_PIN AB14 [get_ports {sns2_dn76[6]}]
  set_property PACKAGE_PIN Y14  [get_ports {sns2_dp76[7]}]
  set_property PACKAGE_PIN Y13  [get_ports {sns2_dn76[7]}]
} elseif { $HISPI } {
  set_property PACKAGE_PIN U15  [get_ports {sns2_dp[0]}]
  set_property PACKAGE_PIN U14  [get_ports {sns2_dn[0]}]
  set_property PACKAGE_PIN V15  [get_ports {sns2_dp[1]}]
  set_property PACKAGE_PIN W15  [get_ports {sns2_dn[1]}]
  set_property PACKAGE_PIN U13  [get_ports {sns2_dp[2]}]
  set_property PACKAGE_PIN V13  [get_ports {sns2_dn[2]}]
  set_property PACKAGE_PIN V12  [get_ports {sns2_dp[3]}]
  set_property PACKAGE_PIN V11  [get_ports {sns2_dn[3]}]
  set_property PACKAGE_PIN AA17 [get_ports {sns2_dp74[4]}]
  set_property PACKAGE_PIN AB17 [get_ports {sns2_dn74[4]}]
  set_property PACKAGE_PIN AA15 [get_ports {sns2_dp74[5]}]
  set_property PACKAGE_PIN AB15 [get_ports {sns2_dn74[5]}]
  set_property PACKAGE_PIN AA14 [get_ports {sns2_dp74[6]}]
  set_property PACKAGE_PIN AB14 [get_ports {sns2_dn74[6]}]
  set_property PACKAGE_PIN Y14  [get_ports {sns2_dp74[7]}]
  set_property PACKAGE_PIN Y13  [get_ports {sns2_dn74[7]}]
} else {
  set_property PACKAGE_PIN U15  [get_ports {sns2_dp[0]}]
  set_property PACKAGE_PIN U14  [get_ports {sns2_dn[0]}]
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
}
set_property PACKAGE_PIN Y16  [get_ports {sns2_clkp}]
set_property PACKAGE_PIN AA16 [get_ports {sns2_clkn}]
set_property PACKAGE_PIN T12  [get_ports {sns2_scl}]
set_property PACKAGE_PIN U12  [get_ports {sns2_sda}]
set_property PACKAGE_PIN V16  [get_ports {sns2_ctl}]
set_property PACKAGE_PIN W16  [get_ports {sns2_pg}]

# ================= Sensor port 2 =================
# BOSON same as HISPI
if { $BOSON } {
    set_property PACKAGE_PIN AA22 [get_ports {sns3_dp[0]}]
    set_property PACKAGE_PIN AB22 [get_ports {sns3_dn[0]}]
    set_property PACKAGE_PIN W21  [get_ports {sns3_dp[1]}]
    set_property PACKAGE_PIN Y22  [get_ports {sns3_dn[1]}]
    set_property PACKAGE_PIN V21  [get_ports {sns3_dp[2]}]
    set_property PACKAGE_PIN V22  [get_ports {sns3_dn[2]}]
    set_property PACKAGE_PIN W19  [get_ports {sns3_dp[3]}]
    set_property PACKAGE_PIN W20  [get_ports {sns3_dn[3]}]
    set_property PACKAGE_PIN N21  [get_ports {sns3_dp74[4]}]
    set_property PACKAGE_PIN N22  [get_ports {sns3_dn74[4]}]
    set_property PACKAGE_PIN R22  [get_ports {sns3_dp74[5]}]
    set_property PACKAGE_PIN T22  [get_ports {sns3_dn74[5]}]
    set_property PACKAGE_PIN P21  [get_ports {sns3_dp74[6]}]
    set_property PACKAGE_PIN R21  [get_ports {sns3_dn74[6]}]
    set_property PACKAGE_PIN T20  [get_ports {sns3_dp74[7]}]
    set_property PACKAGE_PIN U20  [get_ports {sns3_dn74[7]}]
  } elseif { $LWIR } {
  set_property PACKAGE_PIN AA22 [get_ports {sns3_dp40[0]}]
  set_property PACKAGE_PIN AB22 [get_ports {sns3_dn40[0]}]
  set_property PACKAGE_PIN W21  [get_ports {sns3_dp40[1]}]
  set_property PACKAGE_PIN Y22  [get_ports {sns3_dn40[1]}]
  set_property PACKAGE_PIN V21  [get_ports {sns3_dp40[2]}]
  set_property PACKAGE_PIN V22  [get_ports {sns3_dn40[2]}]
  set_property PACKAGE_PIN W19  [get_ports {sns3_dp40[3]}]
  set_property PACKAGE_PIN W20  [get_ports {sns3_dn40[3]}]
  set_property PACKAGE_PIN N21  [get_ports {sns3_dp40[4]}]
  set_property PACKAGE_PIN N22  [get_ports {sns3_dn40[4]}]
  set_property PACKAGE_PIN R22  [get_ports {sns3_dp5}]
  set_property PACKAGE_PIN T22  [get_ports {sns3_dn5}]
  set_property PACKAGE_PIN P21  [get_ports {sns3_dp76[6]}]
  set_property PACKAGE_PIN R21  [get_ports {sns3_dn76[6]}]
  set_property PACKAGE_PIN T20  [get_ports {sns3_dp76[7]}]
  set_property PACKAGE_PIN U20  [get_ports {sns3_dn76[7]}]
} elseif { $HISPI } {
  set_property PACKAGE_PIN AA22 [get_ports {sns3_dp[0]}]
  set_property PACKAGE_PIN AB22 [get_ports {sns3_dn[0]}]
  set_property PACKAGE_PIN W21  [get_ports {sns3_dp[1]}]
  set_property PACKAGE_PIN Y22  [get_ports {sns3_dn[1]}]
  set_property PACKAGE_PIN V21  [get_ports {sns3_dp[2]}]
  set_property PACKAGE_PIN V22  [get_ports {sns3_dn[2]}]
  set_property PACKAGE_PIN W19  [get_ports {sns3_dp[3]}]
  set_property PACKAGE_PIN W20  [get_ports {sns3_dn[3]}]
  set_property PACKAGE_PIN N21  [get_ports {sns3_dp74[4]}]
  set_property PACKAGE_PIN N22  [get_ports {sns3_dn74[4]}]
  set_property PACKAGE_PIN R22  [get_ports {sns3_dp74[5]}]
  set_property PACKAGE_PIN T22  [get_ports {sns3_dn74[5]}]
  set_property PACKAGE_PIN P21  [get_ports {sns3_dp74[6]}]
  set_property PACKAGE_PIN R21  [get_ports {sns3_dn74[6]}]
  set_property PACKAGE_PIN T20  [get_ports {sns3_dp74[7]}]
  set_property PACKAGE_PIN U20  [get_ports {sns3_dn74[7]}]
} else {
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
}
set_property PACKAGE_PIN T21  [get_ports {sns3_clkp}]
set_property PACKAGE_PIN U22  [get_ports {sns3_clkn}]
set_property PACKAGE_PIN Y21  [get_ports {sns3_scl}]
set_property PACKAGE_PIN AA21 [get_ports {sns3_sda}]
set_property PACKAGE_PIN AA20 [get_ports {sns3_ctl}]
set_property PACKAGE_PIN AB20 [get_ports {sns3_pg}]

# ================= Sensor port 3 =================
if { $BOSON } {
    set_property PACKAGE_PIN V17  [get_ports {sns4_dp[0]}]
    set_property PACKAGE_PIN W18  [get_ports {sns4_dn[0]}]
    set_property PACKAGE_PIN Y19  [get_ports {sns4_dp[1]}]
    set_property PACKAGE_PIN AA19 [get_ports {sns4_dn[1]}]
    set_property PACKAGE_PIN U19  [get_ports {sns4_dp[2]}]
    set_property PACKAGE_PIN V20  [get_ports {sns4_dn[2]}]
    set_property PACKAGE_PIN U18  [get_ports {sns4_dp[3]}]
    set_property PACKAGE_PIN V18  [get_ports {sns4_dn[3]}]
    set_property PACKAGE_PIN P18  [get_ports {sns4_dp74[4]}]
    set_property PACKAGE_PIN P19  [get_ports {sns4_dn74[4]}]
    set_property PACKAGE_PIN N17  [get_ports {sns4_dp74[5]}]
    set_property PACKAGE_PIN N18  [get_ports {sns4_dn74[5]}]
    set_property PACKAGE_PIN N20  [get_ports {sns4_dp74[6]}]
    set_property PACKAGE_PIN P20  [get_ports {sns4_dn74[6]}]
    set_property PACKAGE_PIN R17  [get_ports {sns4_dp74[7]}]
    set_property PACKAGE_PIN R18  [get_ports {sns4_dn74[7]}]
} elseif { $LWIR } {
  set_property PACKAGE_PIN V17  [get_ports {sns4_dp40[0]}]
  set_property PACKAGE_PIN W18  [get_ports {sns4_dn40[0]}]
  set_property PACKAGE_PIN Y19  [get_ports {sns4_dp40[1]}]
  set_property PACKAGE_PIN AA19 [get_ports {sns4_dn40[1]}]
  set_property PACKAGE_PIN U19  [get_ports {sns4_dp40[2]}]
  set_property PACKAGE_PIN V20  [get_ports {sns4_dn40[2]}]
  set_property PACKAGE_PIN U18  [get_ports {sns4_dp40[3]}]
  set_property PACKAGE_PIN V18  [get_ports {sns4_dn40[3]}]
  set_property PACKAGE_PIN P18  [get_ports {sns4_dp40[4]}]
  set_property PACKAGE_PIN P19  [get_ports {sns4_dn40[4]}]
  set_property PACKAGE_PIN N17  [get_ports {sns4_dp5}]
  set_property PACKAGE_PIN N18  [get_ports {sns4_dn5}]
  set_property PACKAGE_PIN N20  [get_ports {sns4_dp76[6]}]
  set_property PACKAGE_PIN P20  [get_ports {sns4_dn76[6]}]
  set_property PACKAGE_PIN R17  [get_ports {sns4_dp76[7]}]
  set_property PACKAGE_PIN R18  [get_ports {sns4_dn76[7]}]
} elseif { $HISPI } {
  set_property PACKAGE_PIN V17  [get_ports {sns4_dp[0]}]
  set_property PACKAGE_PIN W18  [get_ports {sns4_dn[0]}]
  set_property PACKAGE_PIN Y19  [get_ports {sns4_dp[1]}]
  set_property PACKAGE_PIN AA19 [get_ports {sns4_dn[1]}]
  set_property PACKAGE_PIN U19  [get_ports {sns4_dp[2]}]
  set_property PACKAGE_PIN V20  [get_ports {sns4_dn[2]}]
  set_property PACKAGE_PIN U18  [get_ports {sns4_dp[3]}]
  set_property PACKAGE_PIN V18  [get_ports {sns4_dn[3]}]
  set_property PACKAGE_PIN P18  [get_ports {sns4_dp74[4]}]
  set_property PACKAGE_PIN P19  [get_ports {sns4_dn74[4]}]
  set_property PACKAGE_PIN N17  [get_ports {sns4_dp74[5]}]
  set_property PACKAGE_PIN N18  [get_ports {sns4_dn74[5]}]
  set_property PACKAGE_PIN N20  [get_ports {sns4_dp74[6]}]
  set_property PACKAGE_PIN P20  [get_ports {sns4_dn74[6]}]
  set_property PACKAGE_PIN R17  [get_ports {sns4_dp74[7]}]
  set_property PACKAGE_PIN R18  [get_ports {sns4_dn74[7]}]
} else {
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
}
set_property PACKAGE_PIN R16  [get_ports {sns4_clkp}]
set_property PACKAGE_PIN T16  [get_ports {sns4_clkn}]
set_property PACKAGE_PIN AB18 [get_ports {sns4_scl}]
set_property PACKAGE_PIN AB19 [get_ports {sns4_sda}]
set_property PACKAGE_PIN Y17  [get_ports {sns4_ctl}]
set_property PACKAGE_PIN Y18  [get_ports {sns4_pg}]

# ===================== SATA ======================

# bind gtx reference clock
set_property PACKAGE_PIN U6 [get_ports EXTCLK_P]
set_property PACKAGE_PIN U5 [get_ports EXTCLK_N]

# bind sata inputs/outputs
set_property PACKAGE_PIN AA5 [get_ports RXN]
set_property PACKAGE_PIN AA6 [get_ports RXP]
set_property PACKAGE_PIN AB3 [get_ports TXN]
set_property PACKAGE_PIN AB4 [get_ports TXP]

if { $BOSON } {
#  set_property LOC MMCME2_ADV_X0Y0 [get_cells -hier -filter {NAME=~"*sensor_channel_block[0]*/mmcm_or_pll_i/*E2_ADV_i"}]
#  set_property LOC  PLLE2_ADV_X0Y0 [get_cells -hier -filter {NAME=~"*sensor_channel_block[1]*/mmcm_or_pll_i/*E2_ADV_i"}]
#  set_property LOC MMCME2_ADV_X0Y1 [get_cells -hier -filter {NAME=~"*sensor_channel_block[2]*/mmcm_or_pll_i/*E2_ADV_i"}]
#  set_property LOC  PLLE2_ADV_X0Y1 [get_cells -hier -filter {NAME=~"*sensor_channel_block[3]*/mmcm_or_pll_i/*E2_ADV_i"}]
   if       { $LWIR} {
    set_msg_config -id "Vivado 12-180" -suppress
    if {[llength [get_cells -hier -filter {NAME=~"*sensor_channel_block[0]*/mmcm_or_pll_i/MMCME2_ADV_i"}]]!=0} {
        set_property LOC MMCME2_ADV_X0Y0 [get_cells -hier -filter {NAME=~"*sensor_channel_block[0]*/mmcm_or_pll_i/MMCME2_ADV_i"}]
    } elseif {[llength [get_cells -hier -filter {NAME=~"*sensor_channel_block[0]*/mmcm_or_pll_i/PLLE2_ADV_i"}]]!=0} {
        set_property LOC PLLE2_ADV_X0Y0 [get_cells -hier -filter {NAME=~"*sensor_channel_block[0]*/mmcm_or_pll_i/PLLE2_ADV_i"}]
    }
    if {[llength [get_cells -hier -filter {NAME=~"*sensor_channel_block[1]*/mmcm_or_pll_i/MMCME2_ADV_i"}]]!=0} {
        set_property LOC MMCME2_ADV_X0Y0 [get_cells -hier -filter {NAME=~"*sensor_channel_block[1]*/mmcm_or_pll_i/MMCME2_ADV_i"}]
    } elseif {[llength [get_cells -hier -filter {NAME=~"*sensor_channel_block[1]*/mmcm_or_pll_i/PLLE2_ADV_i"}]]!=0} {
        set_property LOC PLLE2_ADV_X0Y0 [get_cells -hier -filter {NAME=~"*sensor_channel_block[1]*/mmcm_or_pll_i/PLLE2_ADV_i"}]
    }
    if {[llength [get_cells -hier -filter {NAME=~"*sensor_channel_block[2]*/mmcm_or_pll_i/MMCME2_ADV_i"}]]!=0} {
        set_property LOC MMCME2_ADV_X0Y1 [get_cells -hier -filter {NAME=~"*sensor_channel_block[2]*/mmcm_or_pll_i/MMCME2_ADV_i"}]
    } elseif {[llength [get_cells -hier -filter {NAME=~"*sensor_channel_block[2]*/mmcm_or_pll_i/PLLE2_ADV_i"}]]!=0} {
        set_property LOC PLLE2_ADV_X0Y1 [get_cells -hier -filter {NAME=~"*sensor_channel_block[2]*/mmcm_or_pll_i/PLLE2_ADV_i"}]
    }
    if {[llength [get_cells -hier -filter {NAME=~"*sensor_channel_block[3]*/mmcm_or_pll_i/MMCME2_ADV_i"}]]!=0} {
        set_property LOC MMCME2_ADV_X0Y1 [get_cells -hier -filter {NAME=~"*sensor_channel_block[3]*/mmcm_or_pll_i/MMCME2_ADV_i"}]
    } elseif {[llength [get_cells -hier -filter {NAME=~"*sensor_channel_block[3]*/mmcm_or_pll_i/PLLE2_ADV_i"}]]!=0} {
        set_property LOC PLLE2_ADV_X0Y1 [get_cells -hier -filter {NAME=~"*sensor_channel_block[3]*/mmcm_or_pll_i/PLLE2_ADV_i"}]
    }
    reset_msg_config -id "Vivado 12-180" -suppress
   }
#debugging:
#set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets sensors393_i/sensor_channel_block[0].sensor_channel_i/sens_103993_i/sens_103993_l3_i/sens_103993_clock_i/ibufds_ibufgds0_i/clk_in]
#set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets sensors393_i/sensor_channel_block[1].sensor_channel_i/sens_103993_i/sens_103993_l3_i/sens_103993_clock_i/ibufds_ibufgds0_i/clk_in]
#set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets sensors393_i/sensor_channel_block[2].sensor_channel_i/sens_103993_i/sens_103993_l3_i/sens_103993_clock_i/ibufds_ibufgds0_i/clk_in]
#set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets sensors393_i/sensor_channel_block[3].sensor_channel_i/sens_103993_i/sens_103993_l3_i/sens_103993_clock_i/ibufds_ibufgds0_i/clk_in]

set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets sensors393_i/sensor_channel_block[0].sensor_channel_i/sens_103993_i/sens_103993_l3_i/sens_103993_clock_i/ibufds_ibufgds0_i/clk_in]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets sensors393_i/sensor_channel_block[1].sensor_channel_i/sens_103993_i/sens_103993_l3_i/sens_103993_clock_i/ibufds_ibufgds0_i/clk_in]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets sensors393_i/sensor_channel_block[2].sensor_channel_i/sens_103993_i/sens_103993_l3_i/sens_103993_clock_i/ibufds_ibufgds0_i/clk_in]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets sensors393_i/sensor_channel_block[3].sensor_channel_i/sens_103993_i/sens_103993_l3_i/sens_103993_clock_i/ibufds_ibufgds0_i/clk_in]
    
}
