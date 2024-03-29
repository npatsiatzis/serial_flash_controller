# Makefile

# defaults
SIM ?= ghdl
TOPLEVEL_LANG ?= vhdl
EXTRA_ARGS += --std=08
SIM_ARGS += --wave=wave.ghw

VHDL_SOURCES += $(PWD)/../rtl/flash_controller_pkg.vhd
VHDL_SOURCES += $(PWD)/../rtl/wb_regs.vhd
VHDL_SOURCES += $(PWD)/../rtl/axil_regs.vhd
VHDL_SOURCES += $(PWD)/../rtl/sclk_gen.vhd
VHDL_SOURCES += $(PWD)/../rtl/spi_flash_controller.vhd
VHDL_SOURCES += $(PWD)/../rtl/serial_flash_sim_model.vhd
VHDL_SOURCES += $(PWD)/../rtl/flash_top.vhd
VHDL_SOURCES += $(PWD)/../rtl/flash_top_axi.vhd
VHDL_SOURCES += $(PWD)/../rtl/m25p80_sim_model.vhd
VHDL_SOURCES += $(PWD)/../rtl/top.vhd
VHDL_SOURCES += $(PWD)/../rtl/top_axi.vhd
# use VHDL_SOURCES for VHDL files

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
# MODULE is the basename of the Python test file
test_micron_derived_sim_model:
		rm -rf sim_build
		$(MAKE) sim MODULE=testbench TOPLEVEL=top
test_micron_axi:
		rm -rf sim_build
		$(MAKE) sim MODULE=testbench_axi TOPLEVEL=top_axi

test_custom_sim_model:
		rm -rf sim_build
		$(MAKE) sim MODULE=testbench TOPLEVEL=flash_top

test_custom_sim_model_axi:
		rm -rf sim_build
		$(MAKE) sim MODULE=testbench_axi TOPLEVEL=flash_top_axi

clean_dir:
		rm -f wave.*
		rm -f *.o 
		rm -f *.xml
		find . -maxdepth 1 -type f -executable -exec rm {} +
		find -mindepth 1 -maxdepth 1 -type d -print0 | xargs -r0 rm -R
# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim