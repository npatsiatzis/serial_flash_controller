library ieee;
use ieee.std_logic_1164.all;

entity flash_top is
	generic (
			g_sys_clk : natural := 200_000_000);			--system clock freq. in Hz
	port (
	 		i_clk : in std_ulogic;
	 		i_arstn : in std_ulogic;
	 		i_we : in std_ulogic;
	 		i_addr : in std_logic_vector(2 downto 0);
	 		i_data : in std_logic_vector(7 downto 0);
	 		o_data : out std_logic_vector(7 downto 0);
	 		o_byte_tx_done : out std_ulogic;
	 		o_byte_rx_done : out std_ulogic;
	 		o_dv : out std_ulogic;

	 		i_dq : in std_ulogic;
	 		o_c : out std_ulogic;
	 		o_s_n : out std_ulogic;
	 		o_dq : out std_ulogic
	 	); 
end flash_top;

architecture rtl of flash_top is 
	signal w_dq : std_ulogic;
begin

	spi_flash_controller : entity work.spi_flash_controller(rtl)
	generic map(
		g_sys_clk => g_sys_clk
		)
	port map(
			--system clock and reset
			i_clk  =>i_clk,
			i_arstn  =>i_arstn,

			--cpu interface
			i_we  =>i_we,
			i_addr =>i_addr,
			i_data =>i_data,
			o_data =>o_data,
			o_byte_tx_done =>o_byte_tx_done,
			o_byte_rx_done =>o_byte_rx_done,
			o_dv => o_dv,

			--flash interface
			o_c =>o_c,			
			o_s_n =>o_s_n,			
			i_dq  =>w_dq,			
			o_dq =>o_dq);			

	serial_flash_sim_model : entity work.serial_flash_sim_model(rtl)
	port map(
			i_clk  =>o_c,
			i_arstn  =>i_arstn,
			i_s_n  =>o_s_n,
			i_dq  =>o_dq,
			o_dq =>w_dq);
end rtl;