x393_sata/device/sata_device.v
#!/bin/bash
REPO_ROOT=".."
CWD="$(pwd)"
#copy x393_sata unique files to the new x393_sata/ subdirectory
cd $REPO_ROOT
cp -v --parents \
x393_sata/device/oob_dev.v \
x393_sata/device/sata_phy_dev.v \
x393_sata/ahci/ahci_fis_receive.v \
x393_sata/ahci/ahci_dma_rd_fifo.v \
x393_sata/ahci/ahci_fis_transmit.v \
x393_sata/ahci/ahci_dma_rd_stuff.v \
x393_sata/ahci/ahci_dma_wr_fifo.v \
x393_sata/ahci/ahci_top.v \
x393_sata/ahci/axi_ahci_regs.v \
x393_sata/ahci/axi_hp_abort.v \
x393_sata/ahci/ahci_dma.v \
x393_sata/ahci/freq_meter.v \
x393_sata/ahci/ahci_ctrl_stat.v \
x393_sata/ahci/ahci_sata_layers.v \
x393_sata/ahci/ahci_fsm.v \
x393_sata/ahci/sata_ahci_top.v \
x393_sata/host/gtx_10x8dec.v \
x393_sata/host/gtx_8x10enc_init_stub.v \
x393_sata/host/gtx_10x8dec_init.v \
x393_sata/host/elastic1632.v \
x393_sata/host/gtx_8x10enc.v \
x393_sata/host/crc.v \
x393_sata/host/gtx_elastic.v \
x393_sata/host/gtx_10x8dec_init_stub.v \
x393_sata/host/oob_ctrl.v \
x393_sata/host/drp_other_registers.v \
x393_sata/host/gtx_comma_align.v \
x393_sata/host/gtx_wrap.v \
x393_sata/host/sata_phy.v \
x393_sata/host/gtx_8x10enc_init.v \
x393_sata/host/scrambler.v \
x393_sata/host/link.v \
x393_sata/host/oob.v \
x393_sata/generated/condition_mux.v \
x393_sata/generated/action_decoder.v \
x393_sata/wrapper/GTXE2_GPL.v \
x393_sata/wrapper/gtxe2_channel_wrapper.v \
x393_sata/wrapper/clock_inverter.v \
x393_sata/system_defines.vh \
x393_sata/ahci_timing.xdc \
$CWD

#Copy include files to includes/
cp -v \
x393_sata/includes/ahxi_fsm_code.vh \
x393_sata/includes/ahci_localparams.vh \
x393_sata/includes/ahci_types.vh \
x393_sata/includes/fis_types.vh \
x393_sata/includes/ahci_defaults.vh \
$CWD/includes
cd $CWD
