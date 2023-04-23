library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
	generic (
			g_freq_read : natural := 25_000_000;
			g_freq_rest : natural := 50_000_000;
			g_sys_clk : natural := 200_000_000);			--system clock freq. in Hz
	port (
			--system clock and reset
	 		i_clk : in std_ulogic;
	 		i_arstn : in std_ulogic;

	 		--wishbone b4 interface 
	 		i_we : in std_ulogic;
	 		i_stb : in std_ulogic;
	 		i_addr : in std_logic_vector(2 downto 0);
	 		i_data : in std_logic_vector(7 downto 0);
	 		o_ack : out std_ulogic;
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
end top;

architecture rtl of top is
	signal q : std_ulogic;
	signal f_is_data_to_tx : std_ulogic;
	signal w_tx_done, w_rx_done : std_ulogic;
	signal w_new_tx_req,w_new_rx_req : std_ulogic;
	signal w_cmd_reg, w_tx_reg, w_addr_h_reg, w_addr_m_reg, w_addr_l_reg : std_ulogic_vector(7 downto 0);
	signal w_flash_rd_data : std_ulogic_vector(7 downto 0);
begin
	f_is_data_to_tx <= '1' when (i_we = '1' and unsigned(i_addr) = 1) else '0';

	wb_regs : entity work.wb_regs(rtl)
	port map(
		i_clk =>i_clk,
		i_arstn =>i_arstn,

		--wishbone b4 (slave) interface
		i_we  =>i_we,
		i_stb =>i_stb,
		i_addr =>i_addr,
		i_data =>i_data,
		o_ack => o_ack,
		o_data =>o_data,

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

	 		i_dq =>q,
	 		o_c =>o_c,
	 		o_s_n =>o_s_n,
	 		o_dq => o_dq
	 	); 

	m25p80_sim_model : entity work.m25p80_sim_model(rtl)
	port map (
			i_clk => i_clk,
			C =>o_c,
			D =>o_dq,
			S =>o_s_n,
			Q =>q);
end rtl;