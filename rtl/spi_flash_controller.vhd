--controller for a serial embedded flash (based on the M25Pxx series).
--communication of commands and data with the flash is made over SPI (mode 3)
--the M25Pxx series support modes 1 and 3 of SPI.
--the majority of flash commands are supported by this controller namely :
--write enable/disable, write/read status register, bulk/sector erase, read data bytes,
--read data bytes at higher speed, page program

--All commands operate on frequency fC, as specified in the relevant datasheet, here created
--via the constant SPI_FREQ_REST. The only command that operates on a different (lower) frequency 
--,namely fR,is the standard READ DATA BYTES command, the frequency of which is created via SPI_FREQ_READ.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.flash_controller_pkg.all;

entity spi_flash_controller is 
	generic (
			g_freq_read : natural := 25_000_000;			--spi clock freq. of read data bytes, depends on device grade, voltage etc..
			g_freq_rest : natural := 50_000_000;			--spi clock freq of commands other that read data bytes
			g_sys_clk : natural := 200_000_000);			--system clock freq. in Hz
	port (
			--system clock and reset
			i_clk : in std_ulogic;							--system clock
			i_arstn : in std_ulogic;						--system reset

			--wb (slave) interface
			--i_we : in std_ulogic;							--write enable for user registers
			--i_stb : in std_ulogic;							--input strobe, validates other intf signals
			--i_addr : in std_ulogic_vector(2 downto 0);		--address bus for user registers
			i_cmd : in std_ulogic_vector(7 downto 0);
			i_addr_h : in std_ulogic_vector(7 downto 0);
			i_addr_m : in std_ulogic_vector(7 downto 0);
			i_addr_l : in std_ulogic_vector(7 downto 0);
			i_data : in std_ulogic_vector(7 downto 0);		--data to write in user registers
			--o_ack : out std_ulogic;
			o_data : out std_ulogic_vector(7 downto 0);		--data read from memory
			
			--interrupts
			o_byte_tx_done : out std_ulogic;				--flag indicating end of transmit command
			o_byte_rx_done : out std_ulogic;				--flag indicating end of receive command

			i_new_tx_req : in std_ulogic;
			i_new_rx_req : in std_ulogic;

			o_tx_done : out std_ulogic;
			o_rx_done : out std_ulogic;
			o_dv : out std_ulogic;							--output data valid

			--spi interface
			o_c : out std_ulogic;			--serial clock
			o_s_n : out std_ulogic;			--chip select
			i_dq : in std_ulogic;			--input serial line
			o_dq : out std_ulogic);			--output serial line
end spi_flash_controller;

architecture rtl of spi_flash_controller is
	--AC speficications for Device Grade 6, min Vcc = 2.7V
	constant SPI_FREQ_READ : natural := g_freq_read; 	--clock freq. for READ commands
	--f_spi_max must be at least /4 of sys clk
	constant SPI_FREQ_REST : natural := g_freq_rest; 	--clock freq. rest commands. 

	signal SPI_CLK_CYCLES : natural := g_sys_clk / SPI_FREQ_REST;
	--constant SPI_CLK_CYCLES : natural := g_sys_clk / SPI_FREQ; 

	type t_state is (IDLE, TX_CMD, TX_ADDR_H, TX_ADDR_M , TX_ADDR_L, TX_DUMMY, TX_DATA, RX_DATA,
		WAIT1,WAIT2,WAIT3,WAIT4,WAIT5,WAIT6,WAIT7,WAIT8, CLEAR_CMD);

	signal w_state : t_state;
	--register holding rx data
	signal data_rx_reg : std_ulogic_vector(7 downto 0);
	--holds the next byte to be transmitted (can be command code/address/data)
	signal w_data_sreg : std_ulogic_vector(7 downto 0);

	signal w_tx_done : std_ulogic;
	signal w_addr_done : std_ulogic;
	signal w_cmd_done : std_ulogic;
	signal w_tx_underway : std_ulogic;
	signal w_rx_underway : std_ulogic;
	signal w_new_data_to_tx : std_ulogic;
	signal w_rx_done : std_ulogic;
	signal w_new_rx_req : std_ulogic;

	signal w_ss_n : std_ulogic;
	signal w_sclk, w_sclk_r : std_ulogic;
	signal w_dv : std_ulogic;
	signal w_cont : std_ulogic;


	signal w_cnt_tx_neg, w_cnt_tx_neg_r : unsigned(4 downto 0);
	signal w_cnt_rx_pos, w_cnt_rx_pos_r : unsigned(4 downto 0);
	signal w_sr_rx_pos_sclk : std_ulogic_vector(7 downto 0);
	signal w_data_read : std_ulogic_vector(7 downto 0);


begin

	--mosi signal line creation for spi mode 3
	mosi_neg_11 : process(w_sclk,i_arstn) is
	begin
		if(i_arstn = '0') then
			o_dq <= '1';
		elsif (falling_edge(w_sclk)) then
			o_dq <= w_data_sreg(to_integer((7 - w_cnt_tx_neg)));
		end if;
	end process; -- mosi_neg_11

	--creation of tranmission index for spi mode 3
	--count tx bits on falling edge of sclk
	tx_cnt_neg : process(w_sclk,i_arstn) is
	begin
		if(i_arstn = '0') then
			w_cnt_tx_neg <= (others => '0');
		elsif (falling_edge(w_sclk)) then
			w_cnt_tx_neg_r <= w_cnt_tx_neg;
			if(w_ss_n = '0' and w_state /= CLEAR_CMD) then
				if(w_cnt_tx_neg = 7) then
					w_cnt_tx_neg <= (others => '0');
				else
					w_cnt_tx_neg <= w_cnt_tx_neg +1;
				end if;
			end if;
		end if;	
	end process; -- tx_cntnegs


	--miso signal line creation for spi mode 3
	--sample the serial line at the posedge of the serial clock
	pos_sample_miso : process(w_sclk,i_arstn) is
	begin
		if(i_arstn = '0') then
				w_sr_rx_pos_sclk <= (others => '0');
		elsif (rising_edge(w_sclk)) then
			if(w_ss_n = '0') then
				w_sr_rx_pos_sclk <= w_sr_rx_pos_sclk(6 downto 0) & i_dq;
			end if;
		end if;
	end process; -- pos_sample_miso

	--creation of reception index for spi mode 3
	--count bits received on the posedge of the serial clock
	cnt_bits_rx_pos : process(w_sclk,i_arstn) is
	begin
		if(i_arstn = '0') then
			w_cnt_rx_pos <= (others => '0');
		elsif (rising_edge(w_sclk)) then
			if(w_ss_n = '0') then
				w_cnt_rx_pos_r <= w_cnt_rx_pos;
				w_cnt_rx_pos <= w_cnt_tx_neg;
			end if;
		end if;
	end process; -- cnt_bits_rx_pos

	--indicate to the spi clock generation module when a continuous transaction is required
	w_cont <= '1' when (w_state = WAIT1 or w_state = WAIT2 or w_state = WAIT3 or w_state = WAIT4 or w_state = WAIT6 or w_state = WAIT7 or (w_state = WAIT8 and i_new_rx_req = '1') or w_state = TX_DATA or w_state = TX_DUMMY or w_state = RX_DATA  or w_state = TX_ADDR_H or w_state = TX_ADDR_M or w_state = TX_ADDR_L) else '0';

	o_c <= w_sclk;
	o_s_n <= w_ss_n;

	--instantiation of spi clock generation module
	sclk_gen : entity work.sclk_gen(rtl)
	port map(
			i_clk =>i_clk,
			i_arstn =>i_arstn,
			i_dv => w_dv,	
			i_cont =>w_cont,
			i_sclk_cycles =>std_ulogic_vector(to_unsigned(SPI_CLK_CYCLES,8)),
			i_leading_cycles =>std_ulogic_vector(to_unsigned(5,8)),
			i_tailing_cycles =>std_ulogic_vector(to_unsigned(0,8)),
			i_iddling_cycles =>std_ulogic_vector(to_unsigned(0,8)),
			i_pol => '1',			--spi mode 3
			o_ss_n => w_ss_n,
			o_sclk => w_sclk
		);


	o_data <= data_rx_reg;



	o_tx_done <= w_tx_done;
	o_rx_done <= w_rx_done;


	o_byte_tx_done <= w_tx_done;
	o_byte_rx_done <= w_rx_done;


	flash_cmd_FSM : process(i_clk,i_arstn) is
	begin
		if(i_arstn = '0') then
			w_state <= IDLE;
			w_dv <= '0';
			w_data_sreg <= (others => '1');
			w_addr_done <= '0';
			w_cmd_done <= '0';
			w_rx_underway <= '0';
			w_tx_underway <= '0';
			o_dv <= '0';
			SPI_CLK_CYCLES <= g_sys_clk / SPI_FREQ_REST;
		elsif (rising_edge(i_clk)) then
			w_sclk_r <= w_sclk;

			w_tx_done <= '0';
			w_rx_done <= '0';
			w_dv <= '0';
			o_dv <= '0';
			case w_state is 
				when IDLE =>
					w_data_sreg <= (others => '1');
					case i_cmd is 
						when NOP =>
							w_state <= IDLE;
						when others => 
							w_state <= TX_CMD;
					end case;
				when TX_CMD =>
					w_dv <= '1';
					w_data_sreg <= i_cmd;
					if(w_cnt_tx_neg = 1) then
						w_cmd_done <= '1';
					end if;
					if(w_cnt_tx_neg = 0 and w_cnt_tx_neg_r = 7 and w_cmd_done = '1') then
						w_tx_done <= '1';
						w_cmd_done <= '0';
						case i_cmd is 
							when PAGE_PROGRAM | SECTOR_ERASE | RD_DATA | F_RD_DATA | WR_STATUS_REG | RD_STATUS_REG =>
								w_state <= WAIT1;
							when others =>
								w_state <= CLEAR_CMD;

						end case;
					end if;
				when TX_ADDR_H =>
					if(w_cnt_tx_neg = 1) then
						w_addr_done <= '1';
					end if;
					if(w_cnt_tx_neg = 0 and w_cnt_tx_neg_r = 7 and w_addr_done = '1') then
						w_state <= WAIT2;
						w_addr_done <= '0';
					end if;
				when TX_ADDR_M =>
					if(w_cnt_tx_neg = 1) then
						w_addr_done <= '1';
					end if;
					if(w_cnt_tx_neg = 0 and w_cnt_tx_neg_r = 7 and w_addr_done = '1') then
						w_state <= WAIT3;
						w_addr_done <= '0';
					end if;
				when TX_ADDR_L =>
					if(w_cnt_tx_neg = 1) then
						w_addr_done <= '1';
					end if;
					if(w_cnt_tx_neg = 0 and w_cnt_tx_neg_r = 7 and w_addr_done = '1') then
						w_addr_done <= '0';
						case i_cmd is 
							when SECTOR_ERASE | RD_DATA | F_RD_DATA  =>
								w_state <= WAIT4;
							when PAGE_PROGRAM =>
								w_state <= WAIT6;
							when others => 
								w_state <= CLEAR_CMD;
						end case;
					end if;
				when TX_DUMMY =>
					if(w_cnt_tx_neg =1) then                 
						w_tx_underway <= '1';
					elsif(w_cnt_tx_neg = 0 and w_cnt_tx_neg_r = 7 and w_tx_underway = '1') then
						w_tx_underway <= '0';
						w_state <= RX_DATA;
					end if;
				when TX_DATA =>
					if(w_cnt_tx_neg =1) then                 
						w_tx_done <= '1';
						w_tx_underway <= '1';
					elsif(w_cnt_tx_neg = 0 and w_cnt_tx_neg_r = 7 and w_tx_underway = '1') then
						w_tx_underway <= '0';
						case i_cmd is 
							when PAGE_PROGRAM =>
								w_state <= WAIT6;
							when others =>
								w_state <= CLEAR_CMD;
						end case;
					end if;
				when RX_DATA =>
					if(w_cnt_rx_pos =1) then	
						w_rx_done <= '1';
						w_rx_underway <= '1';
					elsif(w_cnt_rx_pos = 7 and w_cnt_rx_pos_r = 6 and w_rx_underway = '1') then
						w_state <= WAIT8;
					end if;
				when WAIT1 =>
					case i_cmd is 
						when  SECTOR_ERASE | PAGE_PROGRAM | RD_DATA | F_RD_DATA =>
							w_state <= TX_ADDR_H;
							w_data_sreg <= i_addr_h;
						when WR_STATUS_REG => 
							w_state <= TX_DATA;
							w_data_sreg <= i_data;
						when RD_STATUS_REG =>
							w_state <= RX_DATA;
						when others =>
							w_state <= CLEAR_CMD;
					end case;
				when WAIT2 =>
					w_state <= TX_ADDR_M;
					w_data_sreg <= i_addr_m;
				when WAIT3 =>
					w_state <= TX_ADDR_L;
					w_data_sreg <= i_addr_l;
				when WAIT4 =>
					w_tx_done <= '1';
					case i_cmd is 
						when F_RD_DATA =>
							w_state <= TX_DUMMY;
							w_data_sreg <= (others => '0');
						when RD_DATA => 
							w_state <= RX_DATA;
							SPI_CLK_CYCLES <= g_sys_clk/SPI_FREQ_READ;
						when others =>
							w_state <= CLEAR_CMD;
					end case;
				when WAIT5 =>
					data_rx_reg <= w_sr_rx_pos_sclk;
					o_dv <= '1';
					w_data_read <= w_sr_rx_pos_sclk;
					w_state <= CLEAR_CMD;
				when WAIT6 =>
					case i_cmd is 
						when PAGE_PROGRAM =>
							if(i_new_tx_req = '1') then
								w_state <= TX_DATA;
								w_data_sreg <= i_data;
							else
								w_state <= CLEAR_CMD;
							end if;
						when others =>
							w_state <= CLEAR_CMD;
					end case;
				when WAIT8 =>
					if(w_cnt_rx_pos = 0 and w_cnt_rx_pos_r = 7 and w_rx_underway = '1') then
						w_rx_underway <= '0';
						case i_cmd is 
							when RD_DATA | F_RD_DATA =>
								w_state <= WAIT7;				
							when others => 
								w_state <= WAIT5;
								SPI_CLK_CYCLES <= g_sys_clk/SPI_FREQ_REST;
						end case;
					end if;
				when WAIT7 =>
					w_data_read <= w_sr_rx_pos_sclk;
					data_rx_reg <= w_sr_rx_pos_sclk;
					o_dv <= '1';
					case i_cmd is
						when RD_DATA | F_RD_DATA =>
							if(i_new_rx_req = '1') then
								w_state <= RX_DATA;
							else
								w_state <= WAIT7;
							end if; 
						when others =>
							w_state <= CLEAR_CMD;
							SPI_CLK_CYCLES <= g_sys_clk/SPI_FREQ_REST;
					end case;
				when CLEAR_CMD =>
					if(w_ss_n = '1') then
						w_state <= IDLE;
					end if;
				when others =>
					w_state <= IDLE;
			end case;
		end if;
	end process; -- flash_cmd_FSM
end rtl;