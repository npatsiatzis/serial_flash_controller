![example workflow](https://github.com/npatsiatzis/serial_flash_controller/actions/workflows/regression.yml/badge.svg)
![example workflow](https://github.com/npatsiatzis/serial_flash_controller/actions/workflows/coverage.yml/badge.svg)

### controller for serial flash embedded memory (M25Pxx series)


- supports essential flash commands (read data, page program, write enable/disable, sector/bulk erase, write/read status register)
- spi mode 3 (cpol = 1, cpha = 1)
- verification based on a trivial simulation model of flash's behavior based on MP25P80's datasheet
- CoCoTB testbench for functional verification (various test scenarios exercise different set of commands on the defive)
    - Use custom simulation model implemented according to the datasheet
        - $ make test_custom_sim_model
    - Use a simulation model that was derived from a similar simulation model (for M25PE80) that was 
    avaialbe online in Verilog. The new simulaiton model is written in VHDL and implements as faithfully as possible the essential flash commands described above, accroding the sim. model of M25PE80.
        - $ make 


### Repo Structure

This is a short tabular description of the contents of each folder in the repo.

| Folder | Description |
| ------ | ------ |
| [rtl](https://github.com/npatsiatzis/serial_flash_controller/tree/main/rtl/VHDL) | VHDL RTL implementation files |
| [cocotb_sim](https://github.com/npatsiatzis/serial_flash_controller/tree/main/cocotb_sim) | Functional Verification with CoCoTB (Python-based) |
| [pyuvm_sim](https://github.com/npatsiatzis/serial_flash_controller/tree/main/pyuvm_sim) | Functional Verification with pyUVM (Python impl. of UVM standard) |
<!-- 

This is the tree view of the strcture of the repo.
<pre>
<font size = "2">
.
├── <font size = "4"><b><a href="https://github.com/npatsiatzis/serial_flash_controller/tree/main/rtl">rtl</a></b> </font>
│   └── VHD files
├── <font size = "4"><b><a href="https://github.com/npatsiatzis/serial_flash_controller/tree/main/cocotb_sim">cocotb_sim</a></b></font>
│   ├── Makefile
│   └── python files
└── <font size = "4"><b><a 
 href="https://github.com/npatsiatzis/serial_flash_controller/tree/main/pyuvm_sim">pyuvm_sim</a></b></font>
    ├── Makefile
    └── python files
</pre> -->