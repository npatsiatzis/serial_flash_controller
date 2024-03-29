library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.flash_controller_pkg.all;

entity wb_regs is
	port (
		i_clk : in std_ulogic;
		i_arstn : in std_ulogic;

		--wishbone b4 (slave) interface
		i_we  : in std_ulogic;
		i_stb : in std_ulogic;
		i_addr : in std_ulogic_vector(2 downto 0);
		i_data : in std_ulogic_vector(7 downto 0);
		o_ack : out std_ulogic;
		o_data : out std_ulogic_vector(7 downto 0);

		--data read from flash
		i_flash_rd_data : in std_ulogic_vector(7 downto 0);
		i_tx_done : in std_ulogic;
		i_rx_done : in std_ulogic;

		--ports for write regs to hierarchy
		o_cmd_reg  : out std_ulogic_vector(7 downto 0);
		o_addr_h_reg  : out std_ulogic_vector(7 downto 0);
		o_addr_m_reg  : out std_ulogic_vector(7 downto 0);
		o_addr_l_reg  : out std_ulogic_vector(7 downto 0);
		o_new_tx_req : out std_ulogic;
		o_new_rx_req : out std_ulogic;
		o_tx_reg : out std_ulogic_vector(7 downto 0)); 
end wb_regs;

architecture rtl of wb_regs is
	signal f_is_data_to_tx : std_ulogic;

	--user registers
	--register holding the command code for the next flash command
	signal cmd_reg : std_ulogic_vector(7 downto 0);
	--register holding the data (if required) for the next flash command
	signal data_tx_reg : std_ulogic_vector(7 downto 0);
	--register holding the high byte (A23-A16) of the flash address (if required) for the next flash command
	signal addr_h_reg : std_ulogic_vector(7 downto 0);
	--register holding the med. byte (A15-A8) of the flash address (if required) for the next flash command
	signal addr_m_reg : std_ulogic_vector(7 downto 0);
	--register holding the low byte (A7-A0) of the flash address (if required) for the next flash command
	signal addr_l_reg : std_ulogic_vector(7 downto 0);
begin

	f_is_data_to_tx <= '1' when (i_we = '1' and i_stb = '1' and unsigned(i_addr) = 1) else '0';



	-- 					INTERFACE REGISTER MAP

	-- 			Address 		| 		Functionality
	--			   0 			|	write flash command code
	--			   1 			|	write data to tx / keep programming data bytes
	--			   2 			|	write A23-A16
	--			   3 			|	write A15-A8
	--			   4 			|	write A7-A0
	--			   5 			|	keep reading data bytes

	--manage user registers to organize the operations to be performed on flash
	manage_regs : process(i_clk,i_arstn) is
	begin
		if(i_arstn = '0') then
			o_ack <= '0';
			cmd_reg <= NOP;
			data_tx_reg <= (others => '0');
			addr_h_reg <= (others => '0');
			addr_m_reg <= (others => '0');
			addr_l_reg <= (others => '0');
		elsif (rising_edge(i_clk)) then
			o_ack <= '0';
			if(i_stb = '1' and i_we = '1') then
				o_ack <= '1';
				case i_addr is 
					when "000" =>
						cmd_reg <= i_data;
					when "001" =>
						data_tx_reg <= i_data;
					when "010" =>
						addr_h_reg <= i_data;
					when "011" =>
						addr_m_reg <= i_data;
					when "100" =>
						addr_l_reg <= i_data;
					when others =>
						null;
				end case;
			elsif (i_stb = '1' and i_we = '0') then
				o_ack <= '1';
				if(i_addr = "101") then
					o_data <= i_flash_rd_data;
				end if;
			end if;
		end if;
	end process; -- manage_regs

	o_cmd_reg <= cmd_reg;
	o_addr_h_reg <= addr_h_reg;
	o_addr_m_reg <= addr_m_reg;
	o_addr_l_reg <= addr_l_reg;
	o_tx_reg <= data_tx_reg;

	--determine if more bytes are to be programmed on a page (used in page program commnad)
	--page program on M25Pxx serial flash series can program 1-256 bytes with a single page program.
	--page program can be terminated (at byte boundary), by driving the chip-select signal high,
	--even after programming just a single byte
	--the intention to keep programming bytes is communicated to the controller via writting the
	--data byte to be transmitted on USER REGISTER 1. the controller then uses this information 
	--to inform the spi clock generation module that the continuous spi transaction should be continued	
	detect_new_data_to_tx : process(i_clk,i_arstn) is
	begin
		if(i_arstn = '0') then
			o_new_tx_req <= '0';
		elsif (rising_edge(i_clk)) then
			if(i_tx_done ='1') then             
				o_new_tx_req <= '0';
			elsif (i_stb = '1' and unsigned(i_addr) = 1 and i_we = '1') then
				o_new_tx_req <= '1';
			end if;
		end if;
	end process; -- detect_new_data_to_tx



	--determine if more bytes are to be read from the flash (used in read data bytes (at higher speed))
	--read dat bytes (at higher speed) on M25Pxx serial flash series can read any number of bytes
	--starting from a single byte to reading the whole flash. Read dta bytes commands can be terminated
	--at any time (no necessarily at byte boundary), by driving the chip-select signal high.
	--the intention to keep reading bytes from the memory is communicated to the controller via activating
	--(writting) USER REGISTER 5. the controller then uses this information 
	--to inform the spi clock generation module that the continuous spi transaction should be continued 
	detect_new_rx_request : process(i_clk,i_arstn) is
	begin
		if(i_arstn = '0') then 
			o_new_rx_req <= '0';
		elsif(rising_edge(i_clk)) then
			if(i_rx_done = '1') then             
				o_new_rx_req <= '0';
			elsif (i_stb = '1' and  unsigned(i_addr) = 5 and i_we = '1') then
				o_new_rx_req <= '1';
			end if;
		end if;
	end process; -- detect_new_rx_request

end rtl;