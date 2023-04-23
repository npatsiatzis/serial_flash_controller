library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity flash_top_axi is
	generic (
			C_S_AXI_DATA_WIDTH : natural := 32;
			C_S_AXI_ADDR_WIDTH : natural :=4;
			g_freq_read : natural := 25_000_000;
			g_freq_rest : natural := 50_000_000;
			g_sys_clk : natural := 200_000_000);			--system clock freq. in Hz
	port (
		--AXI4-Lite interface
		S_AXI_ACLK : in std_ulogic;
		S_AXI_ARESETN : in std_ulogic;
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


 		o_data : out std_logic_vector(7 downto 0);

 		--interrupts
 		o_byte_tx_done : out std_ulogic;
 		o_byte_rx_done : out std_ulogic;
 		o_dv : out std_ulogic;

 		--spi interface
 		i_dq : in std_ulogic;
 		o_c : out std_ulogic;
 		o_s_n : out std_ulogic;
 		o_dq : out std_ulogic
	 	); 
end flash_top_axi;

architecture rtl of flash_top_axi is
	signal i_arstn, i_arst : std_ulogic;
	alias i_clk  : std_ulogic is S_AXI_ACLK;

	signal w_dq : std_ulogic;
	signal f_is_data_to_tx : std_ulogic;
	signal w_tx_done, w_rx_done : std_ulogic;
	signal w_new_tx_req,w_new_rx_req : std_ulogic;
	signal w_cmd_reg, w_tx_reg, w_addr_h_reg, w_addr_m_reg, w_addr_l_reg : std_ulogic_vector(7 downto 0);
	signal w_flash_rd_data : std_ulogic_vector(7 downto 0);
begin
	i_arstn <= S_AXI_ARESETN;
	i_arst <= not S_AXI_ARESETN;

	--f_is_data_to_tx <= '1' when (i_we = '1' and unsigned(i_addr) = 1) else '0';

	axil_regs : entity work.axil_regs(rtl)
	port map(
		i_clk =>i_clk,
		i_arst =>i_arst,

		S_AXI_AWVALID => S_AXI_AWVALID,
		S_AXI_AWREADY => S_AXI_AWREADY,
		S_AXI_AWADDR => S_AXI_AWADDR,
		S_AXI_AWPROT => S_AXI_AWPROT,
		--
		S_AXI_WVALID => S_AXI_WVALID,
		S_AXI_WREADY => S_AXI_WREADY,
		S_AXI_WDATA => S_AXI_WDATA,
		S_AXI_WSTRB => S_AXI_WSTRB,
		--
		S_AXI_BVALID => S_AXI_BVALID,
		S_AXI_BREADY => S_AXI_BREADY,
		S_AXI_BRESP => S_AXI_BRESP,
		--
		S_AXI_ARVALID => S_AXI_ARVALID,
		S_AXI_ARREADY => S_AXI_ARREADY,
		S_AXI_ARADDR => S_AXI_ARADDR,
		S_AXI_ARPROT => S_AXI_ARPROT,
		--
		S_AXI_RVALID => S_AXI_RVALID,
		S_AXI_RREADY => S_AXI_RREADY,
		S_AXI_RDATA => S_AXI_RDATA,
		S_AXI_RRESP => S_AXI_RRESP,

		--data read from sdram
		i_flash_rd_data =>w_flash_rd_data,
		i_tx_done => w_tx_done,
		i_rx_done => w_rx_done,

		--ports for write regs to hierarchy
		o_cmd_reg  =>w_cmd_reg,
		o_addr_h_reg  =>w_addr_h_reg,
		o_addr_m_reg  =>w_addr_m_reg,
		o_addr_l_reg  =>w_addr_l_reg,
		o_new_tx_req => w_new_tx_req,
		o_new_rx_req => w_new_rx_req,
		o_tx_reg =>w_tx_reg
		);

	o_data <= S_AXI_RDATA(7 downto 0);

	spi_flash_controller : entity work.spi_flash_controller(rtl)
	generic map(
		g_freq_read => g_freq_read,
		g_freq_rest => g_freq_rest,
		g_sys_clk => g_sys_clk
		)
	port map(
	 		i_clk =>i_clk,
	 		i_arstn =>i_arstn,
	 		--i_we =>i_we,
	 		--i_stb => i_stb,
	 		--i_addr =>i_addr,
	 		i_cmd => w_cmd_reg,
	 		i_addr_h => w_addr_h_reg,
	 		i_addr_m => w_addr_m_reg,
	 		i_addr_l => w_addr_l_reg,
	 		i_data =>w_tx_reg,
	 		--o_ack => o_ack,
	 		o_data =>w_flash_rd_data,

	 		i_new_tx_req =>w_new_tx_req,
	 		i_new_rx_req =>w_new_rx_req,

	 		o_tx_done =>w_tx_done,
	 		o_rx_done =>w_rx_done,
	 		o_byte_tx_done =>o_byte_tx_done,
	 		o_byte_rx_done =>o_byte_rx_done,
	 		o_dv =>o_dv,


	 		i_dq =>w_dq,
	 		o_c =>o_c,
	 		o_s_n =>o_s_n,
	 		o_dq => o_dq
	 	); 
	serial_flash_sim_model : entity work.serial_flash_sim_model(rtl)
	port map(
			i_clk  =>o_c,
			i_arstn  =>i_arstn,
			i_s_n  =>o_s_n,
			i_dq  =>o_dq,
			o_dq =>w_dq);
end rtl;