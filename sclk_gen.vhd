--generate the serial clock and slave-select (chip-select) signals of spi protocol
--used for communicating data and commands to the flash
--inputs to slect different values for leading,tailing, idling cycles 
--of the serial clock w.r.t. the assertion and de-assertion of the chip-select
--supports continuous spi flavor which is required for this application

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sclk_gen is 
	generic (
			g_data_width : natural :=8);
	port (
			i_clk : in std_ulogic;
			i_arstn : in std_ulogic;
			i_dv : in std_ulogic;		--input bus data valid
			i_cont : in std_ulogic;
			i_sclk_cycles : in std_ulogic_vector(7 downto 0);
			i_leading_cycles : in std_ulogic_vector(7 downto 0);
			i_tailing_cycles : in std_ulogic_vector(7 downto 0);
			i_iddling_cycles : in std_ulogic_vector(7 downto 0);
			i_pol : in std_ulogic;
			o_ss_n : out std_ulogic;
			o_sclk : out std_ulogic);
end sclk_gen;

architecture rtl of sclk_gen is
	signal w_period_half_rate : unsigned(7 downto 0);
	signal cnt_sclk_period : unsigned(7 downto 0);
	signal w_sclk_pulse : std_ulogic;
	signal w_sclk_pulse_r : std_ulogic;

	type  t_state is (IDLE,LEADING_DELAY,DATA_TX,TALINING_DELAY,IDDLING_DELAY);
	signal w_state : t_state; 

	signal w_sclk_start : std_ulogic; 
	signal w_cnt_delay_start : std_ulogic;
	signal w_cnt_falling_edges : std_ulogic;
	signal w_cnt_delay : unsigned(7 downto 0);
	signal w_leading_done : std_ulogic;
	signal w_tailing_done : std_ulogic;
	signal w_iddling_done : std_ulogic;

	signal w_sclk_falling_edges : unsigned(7 downto 0);
	signal w_sclk_falling_edge : std_ulogic;

	signal w_continue : std_ulogic;

begin
	w_period_half_rate <= shift_right(unsigned(i_sclk_cycles),1);

	--Basic logic (excluding ipol) to build the serial clock (o_sclk)

	build_sclk_pulse : process(i_clk,i_arstn) is
	begin
		if(i_arstn = '0') then
			cnt_sclk_period <= (others => '0');
			w_sclk_pulse <= '0';
		elsif (rising_edge(i_clk)) then
			if(w_sclk_start = '1') then
				if(cnt_sclk_period < unsigned(i_sclk_cycles)-1) then 
					cnt_sclk_period <= cnt_sclk_period +1;
				else
					cnt_sclk_period <= (others => '0');
				end if;
			else
				cnt_sclk_period <= to_unsigned(1,cnt_sclk_period'length);
			end if;
			if(cnt_sclk_period < w_period_half_rate) then
				w_sclk_pulse <='1';
			else
				w_sclk_pulse <= '0';
			end if;
		end if;
	end process; -- build_sclk_pulse


	--register the sclk pulse because we need to use its falling edges to count trans. progress

	reg_sclk : process(i_clk,i_arstn) is
	begin
		if(i_arstn = '0') then
			w_sclk_pulse_r <= '0';
		elsif (rising_edge(i_clk)) then
			w_sclk_pulse_r <= w_sclk_pulse;
		end if;
	end process; -- reg_sclk

	--build o_sclk by taking into account the required clock polarity as well

	build_sclk : process(i_clk,i_arstn) is
	begin
		if(i_arstn = '0') then
			o_sclk <= '0';
		elsif (rising_edge(i_clk)) then
			--only start the serial clock during the tx phase
			if(w_state = DATA_TX or w_state = TALINING_DELAY) then
				if(i_pol = '1') then
					o_sclk <= not(w_sclk_pulse);
				else
					o_sclk <= w_sclk_pulse;
				end if;
			else
				o_sclk <= i_pol;
			end if;
		end if;
	end process; -- build_sclk

	--based on the state of the transaction, manage the serial clock
	--start stop when we must and handle setup,hold and tx2tx requiredments for sclk

	mange_sclk : process(i_clk,i_arstn) is
	begin
		if(i_arstn = '0') then
			w_state <= IDLE;
			w_sclk_start <= '0';
			w_cnt_delay_start <= '0';
			w_cnt_falling_edges <= '0';
			o_ss_n <= '1';				--ss_start is active low
		elsif (rising_edge(i_clk)) then
			case w_state is 
				when IDLE =>
					if(i_dv = '1') then
						w_state <= LEADING_DELAY;
						w_cnt_delay_start <= '1';
						o_ss_n <= '0';
					end if;
				--state for the timeframe after ss_n asserts until 1st sck edge
				--leave leading state when leading time expires
				when LEADING_DELAY =>
						if(w_leading_done = '1') then
							w_state <= DATA_TX;
							w_sclk_start <= '1';
							w_cnt_delay_start <= '0';
							w_cnt_falling_edges <= '1';
						end if;
				--this state is the transfer state for both tx and rx
				when DATA_TX =>	
					if(w_continue = '1' and w_sclk_falling_edges = 0) then
						w_cnt_falling_edges <= '1';
					elsif(w_continue = '1' and w_sclk_falling_edges = g_data_width and i_cont = '1') then
						w_cnt_falling_edges <= '0';
					elsif(w_continue = '1' and w_sclk_falling_edges = g_data_width  and i_cont = '0') then
						w_continue <= '0';
						w_state <= TALINING_DELAY;
						w_cnt_delay_start <= '1';
						w_cnt_falling_edges <= '0';
					--the transfer time (tx or rx) is always until 16 sck edges
					--with the last always being the 8th falling sck eddge	
					elsif(w_sclk_falling_edges = g_data_width and i_cont = '0') then
						w_state <= TALINING_DELAY;
						w_cnt_delay_start <= '1';
						w_cnt_falling_edges <= '0';
					elsif (w_sclk_falling_edges = g_data_width and i_cont = '1') then
						w_cnt_falling_edges <= '0';
						w_continue <= '1';
					end if;
				--state for the timeframe after the 8th sck falling edge until ss_n deasserts
				--leave trailing state when trailing time expires
				when TALINING_DELAY =>
					if(w_tailing_done = '1') then
						w_state <= IDDLING_DELAY;
						w_sclk_start <= '0';
						w_cnt_delay_start <= '0';
						o_ss_n <= '1';
					end if;
				--state for the timeframe for which ss_n is deasserted (high) after a transaction
				--until a new transaction can be accepted
				--leave this state when iddling time expires
			 	when IDDLING_DELAY =>
			 		if(w_iddling_done = '1') then
			 			w_state <= IDLE;
			 			w_cnt_delay_start <= '0';
			 		else
			 			w_cnt_delay_start <= '1';
			 		end if;
				when others =>
					w_state <= IDLE;
					w_sclk_start <= '0';
					w_cnt_delay_start <= '0';
					w_cnt_falling_edges <= '0';
					o_ss_n <= '1';			
			end case;
		end if;
	end process; -- mange_sclk

	--count and indicate when leading,trailing,iddling time has expired

	cnt_delays : process(i_clk,i_arstn) is
	begin
		if(i_arstn = '0') then
			w_cnt_delay <= (others => '0');
		elsif (rising_edge(i_clk)) then
			if(w_cnt_delay_start = '0') then
				w_cnt_delay <= (others => '0');
			else
				w_cnt_delay <= w_cnt_delay +1;
			end if;
		end if;
	end process; -- cnt_delays

	--Leading cycles : time after ss_n asserts (goes low) until the first sck edge
	w_leading_done <= '1' when w_cnt_delay = unsigned(i_leading_cycles) else '0';
	--trailing cycles : time after the last sck edge until ss_n asserts (goes low)
	w_tailing_done <= '1' when w_cnt_delay = unsigned(i_tailing_cycles) else '0';
	--iddling cycles : time between transfers, min time that ss_n can be deasserted (high)
	w_iddling_done <= '1' when w_cnt_delay = unsigned(i_iddling_cycles) else '0';

	cnt_falling_edges : process(i_clk,i_arstn) is
	begin
		if(i_arstn = '0') then
			w_sclk_falling_edges <= (others => '0');
		elsif (rising_edge(i_clk)) then
				if(w_cnt_falling_edges = '0') then
					w_sclk_falling_edges <= (others => '0');
				elsif (w_sclk_falling_edge = '1') then
					w_sclk_falling_edges <= w_sclk_falling_edges +1;
				end if;
		end if;
	end process; -- cnt_falling_edges

	w_sclk_falling_edge <= '1' when w_sclk_pulse = '0' and w_sclk_pulse_r = '1' else '0';
end rtl;

