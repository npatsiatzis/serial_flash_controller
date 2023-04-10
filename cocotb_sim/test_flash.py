from cocotb_test.simulator import run
from cocotb.binary import BinaryValue
import pytest
import os

vhdl_compile_args = "--std=08"
sim_args = "--wave=wave.ghw"


tests_dir = os.path.abspath(os.path.dirname(__file__)) #gives the path to the test(current) directory in which this test.py file is placed
rtl_dir = tests_dir                                    #path to hdl folder where .vhdd files are placed


      
#run tests with different fR (read freq.) and fC(rest freq.) for different Device Grades and Vcc
@pytest.mark.parametrize("g_freq_read,g_freq_rest", [(str(33*10**6),str(75*10**6)) ,(str(25*10**6),str(50*10**6)), (str(20*10**6),str(25*10**6))])
def test_flash(g_freq_read,g_freq_rest):

    module = "testbench"
    toplevel = "flash_top"   
    vhdl_sources = [
        os.path.join(rtl_dir, "../rtl/sclk_gen.vhd"),
        os.path.join(rtl_dir, "../rtl/spi_flash_controller.vhd"),
        os.path.join(rtl_dir, "../rtl/serial_flash_sim_model.vhd"),
        os.path.join(rtl_dir, "../rtl/flash_top.vhd"),
        ]

    parameter = {}
    parameter['g_freq_read'] = g_freq_read
    parameter['g_freq_rest'] = g_freq_rest


    run(
        python_search=[tests_dir],                         #where to search for all the python test files
        vhdl_sources=vhdl_sources,
        toplevel=toplevel,
        module=module,

        vhdl_compile_args=[vhdl_compile_args],
        toplevel_lang="vhdl",
        parameters=parameter,                              #parameter dictionary
        extra_env=parameter,
        sim_build="sim_build/"
        + "_".join(("{}={}".format(*i) for i in parameter.items())),
    )

