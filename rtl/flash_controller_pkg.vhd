library ieee;
use ieee.std_logic_1164.all;

--parameters used in the controller of MT48LC64M4A2 SDRAM 

package flash_controller_pkg is
	--supported flash commands 
	--command set codes for serial embedded memory , eg any from ST M25Pxx series
	constant NOP : std_ulogic_vector(7 downto 0) := "11111111";		--pseudo-cmd, not actual flash cmd
	constant WR_ENABLE : std_ulogic_vector(7 downto 0) := "00000110";
	constant WR_DISABLE : std_ulogic_vector(7 downto 0) := "00000100";
	constant RD_STATUS_REG : std_ulogic_vector(7 downto 0) := "00000101";
	constant WR_STATUS_REG : std_ulogic_vector(7 downto 0) := "00000001";
	constant RD_DATA : std_ulogic_vector(7 downto 0) := "00000011";

	--fast read corrsponds to simple read, but it requires dummy cycles (operates at higher freq.)
	--following the address bytes and can operate at a higher frequency.
	constant F_RD_DATA : std_ulogic_vector(7 downto 0) := "00001011";
	constant PAGE_PROGRAM : std_ulogic_vector(7 downto 0) := "00000010";
	constant SECTOR_ERASE : std_ulogic_vector(7 downto 0) := "11011000";
	constant BULK_ERASE : std_ulogic_vector(7 downto 0) := "11000111";
end flash_controller_pkg;