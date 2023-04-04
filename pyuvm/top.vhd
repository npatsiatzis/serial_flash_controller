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
begin
	f_is_data_to_tx <= '1' when (i_stb = '1' and i_we = '1' and unsigned(i_addr) = 1) else '0';

	spi_flash_controller : entity work.spi_flash_controller(rtl)
	generic map(
		g_freq_read => g_freq_read,
		g_freq_rest => g_freq_rest,
		g_sys_clk => g_sys_clk
		)
	port map(
	 		i_clk =>i_clk,
	 		i_arstn =>i_arstn,
	 		i_we =>i_we,
	 		i_stb => i_stb,
	 		i_addr =>i_addr,
	 		i_data =>i_data,
	 		o_ack => o_ack,
	 		o_data =>o_data,

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