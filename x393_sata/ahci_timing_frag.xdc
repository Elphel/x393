# external clock 150Mhz
create_clock -name gtrefclk -period 6.666 -waveform {0.000 3.333} [get_nets sata_top/ahci_sata_layers_i/phy/gtrefclk]

# recovered sata parallel clock
create_clock -name rx_clk -period 6.666 -waveform {0.000 3.333} [get_nets sata_top/ahci_sata_layers_i/phy/gtx_wrap/xclk_gtx]
create_clock -name txoutclk -period 6.666 -waveform {0.000 3.333} [get_nets sata_top/ahci_sata_layers_i/phy/gtx_wrap/txoutclk_gtx]

create_clock -name usrclk2 -period 13.333 -waveform {0.000 6.666} [get_nets sata_top/ahci_sata_layers_i/phy/usrclk2_r]


set_clock_groups -name async_clocks -asynchronous \
-group {gtrefclk} \
-group {rx_clk} \
-group {usrclk2} \
-group {txoutclk}
