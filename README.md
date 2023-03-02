![example workflow](https://github.com/npatsiatzis/serial_flash_controller/actions/workflows/regression.yml/badge.svg)
![example workflow](https://github.com/npatsiatzis/serial_flash_controller/actions/workflows/coverage.yml/badge.svg)

### controller for serial flash embedded memory (MP25Pxx series)


- supports essential flash commands (read data, page program, write enable/disable, sector/bulk erase, write/read status register)
- spi mode 3 (cpol = 1, cpha = 1)
- verification based on a trivial simulation model of flash's behavior based on MP25P80's datasheet
- CoCoTB testbench for functional verification (various test scenarios exercise different set of commands on the defive)
    - $ make


