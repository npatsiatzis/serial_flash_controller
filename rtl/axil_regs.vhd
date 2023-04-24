library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.flash_controller_pkg.all;

entity axil_regs is
	generic(
		C_S_AXI_DATA_WIDTH : natural := 32;
		C_S_AXI_ADDR_WIDTH : natural :=4);
	port (
		--AXI4-Lite interface
		i_clk : in std_ulogic;
		i_arst : in std_ulogic;
		--
		S_AXI_AWVALID : in std_ulogic;
		S_AXI_AWREADY : out std_ulogic;
		S_AXI_AWADDR : in std_ulogic_vector(C_S_AXI_ADDR_WIDTH -1 downto 0);
		S_AXI_AWPROT : in std_ulogic_vector(2 downto 0);
		--
		S_AXI_WVALID : in std_ulogic;
		S_AXI_WREADY : out std_ulogic;
		S_AXI_WDATA : in std_ulogic_vector(C_S_AXI_DATA_WIDTH -1 downto 0);
		S_AXI_WSTRB : in std_ulogic_vector(C_S_AXI_DATA_WIDTH/8 -1 downto 0);
		--
		S_AXI_BVALID : out std_ulogic;
		S_AXI_BREADY : in std_ulogic;
		S_AXI_BRESP : out std_ulogic_vector(1 downto 0);
		--
		S_AXI_ARVALID : in std_ulogic;
		S_AXI_ARREADY : out std_ulogic;
		S_AXI_ARADDR : in std_ulogic_vector(C_S_AXI_ADDR_WIDTH -1 downto 0);
		S_AXI_ARPROT : in std_ulogic_vector(2 downto 0);
		--
		S_AXI_RVALID : out std_ulogic;
		S_AXI_RREADY : in std_ulogic;
		S_AXI_RDATA : out std_ulogic_vector(C_S_AXI_DATA_WIDTH -1 downto 0);
		S_AXI_RRESP : out std_ulogic_vector(1 downto 0);

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
end axil_regs;

architecture rtl of axil_regs is
	constant ADDR_LSB : natural := (C_S_AXI_DATA_WIDTH/32) +1;
	constant OPT_MEM_ADDR_BITS : natural := 1;


	--signal reg0, reg1, reg2, reg3 : std_ulogic_vector(C_S_AXI_DATA_WIDTH -1 downto 0);
	signal axil_awready, axil_bvalid, axil_arready : std_ulogic;
	signal axil_read_ready, axil_read_valid , axil_write_ready : std_ulogic;

	signal axil_wdata, axil_rdata : std_ulogic_vector(C_S_AXI_DATA_WIDTH -1 downto 0);
	--signal axil_waddr, axil_raddr : std_ulogic_vector(C_S_AXI_ADDR_WIDTH -1 downto ADDR_LSB);
	signal axil_waddr, axil_raddr : std_ulogic_vector(C_S_AXI_ADDR_WIDTH -1 downto 0);
	signal axil_wstrb : std_ulogic_vector(C_S_AXI_DATA_WIDTH/8 -1 downto 0);

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

	manage_w_channel : process(i_clk,i_arst) is
	begin
		if(i_arst = '1') then
			axil_awready <= '0';
		elsif (rising_edge(i_clk)) then
			if(axil_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' and (S_AXI_BVALID = '0' or S_AXI_BREADY = '1')) then
				axil_awready <= '1';
			else
				axil_awready <= '0';
			end if;
		end if;
	end process; -- manage_w_channel

	S_AXI_AWREADY <= axil_awready;
	S_AXI_WREADY <= axil_awready;
	axil_write_ready <= axil_awready;
	axil_wdata <= S_AXI_WDATA;
	--axil_waddr <= S_AXI_AWADDR(S_AXI_AWADDR'high downto ADDR_LSB);
	axil_waddr <= S_AXI_AWADDR;
	axil_wstrb <= S_AXI_WSTRB;

	manage_b_channel : process(i_clk,i_arst) is
	begin
		if(i_arst = '1') then
			axil_bvalid <= '0';
		elsif (rising_edge(i_clk)) then
			if(axil_write_ready = '1') then
				axil_bvalid <= '1';
			end if;
		elsif (S_AXI_BREADY = '1') then
			axil_bvalid <= '0';
		end if;
	end process; -- manage_b_channel

	S_AXI_BVALID <= axil_bvalid;
	S_AXI_BRESP <= "00";


	axil_arready <= not S_AXI_RVALID;
	S_AXI_ARREADY <= axil_arready;
	axil_read_ready <= S_AXI_ARVALID and S_AXI_ARREADY;
	--axil_raddr <= S_AXI_ARADDR(S_AXI_ARADDR'high downto ADDR_LSB);
	axil_raddr <= S_AXI_ARADDR;

	manage_r_channel : process(i_clk,i_arst) is
	begin
		if(i_arst = '1') then
			axil_read_valid <= '0';
		elsif (rising_edge(i_clk)) then
			if(axil_read_ready = '1') then
				axil_read_valid <= '1';
			elsif (S_AXI_RREADY = '1') then
				axil_read_valid <= '0';
			end if;
		end if; 
	end process; -- manage_r_channel

	S_AXI_RVALID <= axil_read_valid;
	S_AXI_RDATA <= axil_rdata; 	
	S_AXI_RRESP <= "00";



	-- 					REGISTER MAP

	-- 			Address 		| 		Functionality
	--			   0 			|	system clock cycles to make scl (lower byte)
	--			   1 			|	system clock cycles to make scl (upper byte)
	--			   2 			|	control transfer register (ctr)
	--			   3 			|	data transfer register (i_we = '1')/ receive i2c data register (i_we = '0') 


	f_is_data_to_tx <= '1' when (S_AXI_WVALID = '1' and S_AXI_AWVALID = '1' and unsigned(S_AXI_AWADDR) = 1) else '0';

	manage_write_regs : process(i_clk,i_arst) is
		variable loc_addr : std_ulogic_vector(2 downto 0);
	begin
		if(i_arst = '1') then
			cmd_reg <= NOP;
			data_tx_reg <= (others => '0');
			addr_h_reg <= (others => '0');
			addr_m_reg <= (others => '0');
			addr_l_reg <= (others => '0');
		elsif (rising_edge(i_clk)) then
			loc_addr := axil_waddr(2 downto 0);
			if(axil_write_ready = '1') then
				case loc_addr is 
					when "000" =>
						cmd_reg <= axil_wdata(7 downto 0);
					when "001" =>
						data_tx_reg <= axil_wdata(7 downto 0);
					when "010" =>
						addr_h_reg <= axil_wdata(7 downto 0);
					when "011" =>
						addr_m_reg <= axil_wdata(7 downto 0);
					when "100" =>
						addr_l_reg <= axil_wdata(7 downto 0);
					when others =>
						null;
				end case;
			end if;
		end if;
	end process; -- manage_write_regs

	manage_read_regs : process(i_clk,i_arst) is
		variable loc_addr : std_ulogic_vector(2 downto 0);
	begin
		if(i_arst = '1') then
			axil_rdata <= (others => '0');
		elsif (rising_edge(i_clk)) then
			loc_addr := axil_raddr(2 downto 0);
			if(S_AXI_RREADY = '1' and S_AXI_RVALID = '0' and loc_addr = "101") then
				axil_rdata(7 downto 0) <= i_flash_rd_data;
			end if;
		end if;
	end process; -- manage_read_regs

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
	detect_new_data_to_tx : process(i_clk,i_arst) is
	begin
		if(i_arst = '1') then
			o_new_tx_req <= '0';
		elsif (rising_edge(i_clk)) then
			if(i_tx_done ='1') then             
				o_new_tx_req <= '0';
			elsif (axil_write_ready = '1' and unsigned(axil_waddr(2 downto 0)) = 1) then
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
	detect_new_rx_request : process(i_clk,i_arst) is
	begin
		if(i_arst = '1') then 
			o_new_rx_req <= '0';
		elsif(rising_edge(i_clk)) then
			if(i_rx_done = '1') then             
				o_new_rx_req <= '0';
			elsif (axil_write_ready = '1' and unsigned(axil_waddr(2 downto 0)) = 5) then
				o_new_rx_req <= '1';
			end if;
		end if;
	end process; -- detect_new_rx_request

end rtl;