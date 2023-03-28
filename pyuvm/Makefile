# Makefile

# defaults
SIM ?= ghdl
TOPLEVEL_LANG ?= vhdl
EXTRA_ARGS += --std=08
SIM_ARGS += --wave=wave.ghw

VHDL_SOURCES += $(PWD)/sclk_gen.vhd
VHDL_SOURCES += $(PWD)/spi_flash_controller.vhd
VHDL_SOURCES += $(PWD)/serial_flash_sim_model.vhd
VHDL_SOURCES += $(PWD)/flash_top.vhd
VHDL_SOURCES += $(PWD)/m25p80_sim_model.vhd
VHDL_SOURCES += $(PWD)/top.vhd
# use VHDL_SOURCES for VHDL files

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
# MODULE is the basename of the Python test file
test_micron_derived_sim_model:
		rm -rf sim_build
		$(MAKE) sim MODULE=testbench_pyuvm TOPLEVEL=top

test_custom_sim_model:
		rm -rf sim_build
		$(MAKE) sim MODULE=testbench_pyuvm TOPLEVEL=flash_top
# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim