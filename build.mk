include $(dir $(lastword $(MAKEFILE_LIST)))build_core.mk

$(VHDLS) += gpsif_config_fpga.vhd
$(VHDLS) += gpsif_config_sim.vhd
