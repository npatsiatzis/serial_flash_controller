![example workflow](https://github.com/npatsiatzis/serial_flash_controller/actions/workflows/regression_pyuvm.yml/badge.svg)
![example workflow](https://github.com/npatsiatzis/serial_flash_controller/actions/workflows/coverage_pyuvm.yml/badge.svg)

### controller for serial flash embedded memory (M25Pxx series)


- supports essential flash commands (read data, page program, write enable/disable, sector/bulk erase, write/read status register)
- spi mode 3 (cpol = 1, cpha = 1)
- verification based on a trivial simulation model of flash's behavior based on MP25P80's datasheet
- pyuvm testbench for functional verification (various test scenarios exercise different set of commands on the defive)
    - Use a simulation model that was derived from a similar simulation model (for M25PE80) that was 
    avaialbe online in Verilog. The new simulaiton model is written in VHDL and implements as faithfully as possible the essential flash commands described above, accroding the sim. model of M25PE80.
        - $ make 
    - Use custom simulation model implemented according to the datasheet
        - $ make test_custom_sim_model


