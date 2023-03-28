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

entity spi_flash_controller is 
	generic (
			g_freq_read : natural := 25_000_000;			--spi clock freq. of read data bytes, depends on device grade, voltage etc..
			g_freq_rest : natural := 50_000_000;			--spi clock freq of commands other that read data bytes
			g_sys_clk : natural := 200_000_000);			--system clock freq. in Hz
	port (
			--system clock and reset
			i_clk : in std_ulogic;							--system clock
			i_arstn : in std_ulogic;						--system reset

			--cpu interface
			i_we : in std_ulogic;							--write enable for user registers
			i_addr : in std_ulogic_vector(2 downto 0);		--address bus for user registers
			i_data : in std_ulogic_vector(7 downto 0);		--data to write in user registers
			o_data : out std_ulogic_vector(7 downto 0);		--data read from memory
			o_byte_tx_done : out std_ulogic;				--flag indicating end of transmit command
			o_byte_rx_done : out std_ulogic;				--flag indicating end of receive command
			o_dv : out std_ulogic;							--output data valid

			--flash interface
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

	--user registers

	--register holding the command code for the next flash command
	signal cmd_reg : std_ulogic_vector(7 downto 0);
	--reigster holding the data (if required) for the next flash command
	signal data_tx_reg : std_ulogic_vector(7 downto 0);
	--register holding the high byte (A23-A16) of the flash address (if required) for the next flash command
	signal addr_h_reg : std_ulogic_vector(7 downto 0);
	--register holding the med. byte (A15-A8) of the flash address (if required) for the next flash command
	signal addr_m_reg : std_ulogic_vector(7 downto 0);
	--register holding the low byte (A7-A0) of the flash address (if required) for the next flash command
	signal addr_l_reg : std_ulogic_vector(7 downto 0);

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
	w_cont <= '1' when (w_state = WAIT1 or w_state = WAIT2 or w_state = WAIT3 or w_state = WAIT4 or w_state = WAIT6 or w_state = WAIT7 or (w_state = WAIT8 and w_new_rx_req = '1') or w_state = TX_DATA or w_state = TX_DUMMY or w_state = RX_DATA  or w_state = TX_ADDR_H or w_state = TX_ADDR_M or w_state = TX_ADDR_L) else '0';

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

	-- 					USER REGISTER MAP

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
			cmd_reg <= NOP;
			data_tx_reg <= (others => '0');
			addr_h_reg <= (others => '0');
			addr_m_reg <= (others => '0');
			addr_l_reg <= (others => '0');
		elsif (rising_edge(i_clk)) then
			if(unsigned(i_addr)  = 0 and i_we = '1') then
				cmd_reg <= i_data;
			elsif (unsigned(i_addr) = 1 and i_we = '1') then
				data_tx_reg <= i_data;
			elsif (unsigned(i_addr) = 2 and i_we = '1') then
				addr_h_reg <= i_data;
			elsif (unsigned(i_addr) = 3 and i_we = '1') then
				addr_m_reg <= i_data;
			elsif (unsigned(i_addr) = 4 and i_we = '1') then
				addr_l_reg <= i_data;
			end if;
		end if;
	end process; -- manage_regs

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
			w_new_data_to_tx <= '0';
		elsif (rising_edge(i_clk)) then
			if(w_tx_done ='1') then             
				w_new_data_to_tx <= '0';
			elsif (unsigned(i_addr) = 1 and i_we = '1') then
				w_new_data_to_tx <= '1';
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
			w_new_rx_req <= '0';
		elsif(rising_edge(i_clk)) then
			if(w_rx_done = '1') then             
				w_new_rx_req <= '0';
			elsif (unsigned(i_addr) = 5 and i_we = '1') then
				w_new_rx_req <= '1';
			end if;
		end if;
	end process; -- detect_new_rx_request


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
					case cmd_reg is 
						when NOP =>
							w_state <= IDLE;
						when others => 
							w_state <= TX_CMD;
					end case;
				when TX_CMD =>
					w_dv <= '1';
					w_data_sreg <= cmd_reg;
					if(w_cnt_tx_neg = 1) then
						w_cmd_done <= '1';
					end if;
					if(w_cnt_tx_neg = 0 and w_cnt_tx_neg_r = 7 and w_cmd_done = '1') then
						w_tx_done <= '1';
						w_cmd_done <= '0';
						case cmd_reg is 
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
						case cmd_reg is 
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
						--w_state <= WAIT8;
						w_tx_underway <= '0';
						w_state <= RX_DATA;
					end if;
				when TX_DATA =>
					if(w_cnt_tx_neg =1) then                 
						w_tx_done <= '1';
						w_tx_underway <= '1';
					elsif(w_cnt_tx_neg = 0 and w_cnt_tx_neg_r = 7 and w_tx_underway = '1') then
						w_tx_underway <= '0';
						case cmd_reg is 
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
					--elsif(w_cnt_rx_pos = 0 and w_cnt_rx_pos_r = 7 and w_rx_underway = '1') then
						--w_rx_underway <= '0';
						w_state <= WAIT8;
						--case cmd_reg is 
						--	when RD_DATA | F_RD_DATA =>
						--		--w_state <= WAIT7;
						--		w_state <= WAIT8;
						--	--when RD_STATUS_REG =>
						--	--	w_state <= 	WAIT5;					
						--	when others => 
						--		w_state <= WAIT5;
						--end case;
					end if;
				when WAIT1 =>
					case cmd_reg is 
						when  SECTOR_ERASE | PAGE_PROGRAM | RD_DATA | F_RD_DATA =>
							w_state <= TX_ADDR_H;
							w_data_sreg <= addr_h_reg;
						when WR_STATUS_REG => 
							w_state <= TX_DATA;
							w_data_sreg <= data_tx_reg;
						when RD_STATUS_REG =>
							w_state <= RX_DATA;
						when others =>
							w_state <= CLEAR_CMD;
					end case;
				when WAIT2 =>
					w_state <= TX_ADDR_M;
					w_data_sreg <= addr_m_reg;
				when WAIT3 =>
					w_state <= TX_ADDR_L;
					w_data_sreg <= addr_l_reg;
				when WAIT4 =>
					w_tx_done <= '1';
					case cmd_reg is 
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
					o_data <= w_sr_rx_pos_sclk;
					o_dv <= '1';
					w_data_read <= w_sr_rx_pos_sclk;
					w_state <= CLEAR_CMD;
				when WAIT6 =>
					case cmd_reg is 
						when PAGE_PROGRAM =>
							if(w_new_data_to_tx = '1') then
								w_state <= TX_DATA;
								w_data_sreg <= data_tx_reg;
							else
								w_state <= CLEAR_CMD;
							end if;
						when others =>
							w_state <= CLEAR_CMD;
					end case;
				when WAIT8 =>
					if(w_cnt_rx_pos = 0 and w_cnt_rx_pos_r = 7 and w_rx_underway = '1') then
						w_rx_underway <= '0';
						--w_state <= WAIT7;
						case cmd_reg is 
							when RD_DATA | F_RD_DATA =>
								--w_state <= WAIT7;
								w_state <= WAIT7;
							--when RD_STATUS_REG =>
							--	w_state <= 	WAIT5;					
							when others => 
								w_state <= WAIT5;
								SPI_CLK_CYCLES <= g_sys_clk/SPI_FREQ_REST;
						end case;
					end if;
				--when WAIT8 =>
				--	o_data <= w_sr_rx_pos_sclk;
				--	o_dv <= '1';
				--	w_data_read <= w_sr_rx_pos_sclk;
				--	w_state <= CLEAR_CMD;
				when WAIT7 =>
					w_data_read <= w_sr_rx_pos_sclk;
					o_data <= w_sr_rx_pos_sclk;
					o_dv <= '1';
					case cmd_reg is
						when RD_DATA | F_RD_DATA =>
							if(w_new_rx_req = '1') then
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