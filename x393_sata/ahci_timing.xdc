# clock, received via FCLK input from PS7
# barely used for now
create_clock -name axi_aclk0 -period 20.000 -waveform {0.000 10.000} [get_nets axi_aclk0]

# external clock 150Mhz
create_clock -name gtrefclk -period 6.666 -waveform {0.000 3.333} [get_nets sata_top/ahci_sata_layers_i/phy/gtrefclk]

# after plls inside of GTX:
#create_clock -name txoutclk -period 6.666 -waveform {0.000 3.333} [get_nets sata_top/ahci_sata_layers_i/phy/txoutclk]
#create_clock -name txoutclk -period 6.666 -waveform {0.000 3.333} [get_nets sata_top/ahci_sata_layers_i/phy/gtx_wrap/bufg_txoutclk/valid_reg]
###create_clock -name txoutclk -period 6.666 -waveform {0.000 3.333} [get_nets sata_top/ahci_sata_layers_i/phy/gtx_wrap/bufg_txoutclk/txoutclk_gtx]

# recovered sata parallel clock
##create_clock -name xclk -period 6.666 -waveform {0.000 3.333} [get_nets sata_top/ahci_sata_layers_i/phy/gtx_wrap/xclk]
create_clock -name xclk -period 6.666 -waveform {0.000 3.333} [get_nets sata_top/ahci_sata_layers_i/phy/gtx_wrap/xclk_gtx]
###sata_top/ahci_sata_layers_i/phy/gtx_wrap/xclk_gtx sata_top/ahci_sata_layers_i/phy/gtx_wrap/gtxe2_channel_wrapper/xclk_gtx
create_clock -name txoutclk -period 6.666 -waveform {0.000 3.333} [get_nets sata_top/ahci_sata_layers_i/phy/gtx_wrap/txoutclk_gtx]

# txoutclk -> userpll, which gives us 2 clocks: userclk (150MHz) and userclk2 (75MHz) . The second one is sata host clk
###create_generated_clock -name usrclk [get_nets sata_top/ahci_sata_layers_i/phy/CLK]
#create_generated_clock -name sclk   [get_nets sata_top/ahci_sata_layers_i/phy/clk]
###create_generated_clock -name sclk   [get_nets sata_top_n_173]

###These clocks are already automatically extracted
#create_generated_clock -name usrclk [get_nets sata_top/ahci_sata_layers_i/phy/usrclk]
#create_generated_clock -name usrclk2 [get_nets sata_top/ahci_sata_layers_i/phy/usrclk2]
#create_clock -name usrclk2 -period 15.333 -waveform {0.000 6.666} [get_nets sata_top/ahci_sata_layers_i/phy/bufg_sclk/usrclk2_r]
#create_clock -name usrclk2 -period 15.333 -waveform {0.000 6.666} [get_nets sata_top/ahci_sata_layers_i/phy/bufg_sclk/rclk]
create_clock -name usrclk2 -period 13.333 -waveform {0.000 6.666} [get_nets sata_top/ahci_sata_layers_i/phy/usrclk2_r]
#

#create_generated_clock -name usrclk2 [get_nets sata_top/ahci_sata_layers_i/phy/usrclk2_r]
#puts [get_nets sata_top/ahci_sata_layers_i/phy/usrclk2_r]
#set_clock_groups -name async_clocks -asynchronous \
#-group {gtrefclk} \
#-group {axi_aclk0} \
#-group {xclk} \
#-group {usrclk} \
#-group {usrclk2} \
#-group {clk_axihp_pre} \
#-group {txoutclk}

set_clock_groups -name async_clocks -asynchronous \
-group {gtrefclk} \
-group {axi_aclk0} \
-group {xclk} \
-group {usrclk2} \
-group {clk_axihp_pre} \
-group {txoutclk}


###-group {sclk} \
