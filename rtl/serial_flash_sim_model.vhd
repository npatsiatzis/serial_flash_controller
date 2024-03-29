--Simple simulation model for M25Pxx series of serial flash embedded memories.
--The behavior of the flash on the sim. model is based on the datasheet of the
--M25P80 model but the functionality described is valid throughout the M25Pxx series.
--Note : this sim. model checks ONLY that the functionality corresponds to the 
--functionality described in the datasheet. It does not contain any sort of 
--tests/check regarding the timing behavior.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity serial_flash_sim_model is 
	port (
			i_clk : in std_ulogic;
			i_arstn : in std_ulogic;
			i_s_n : in std_ulogic;
			i_dq : in std_ulogic;
			o_dq : out std_ulogic
		);
end serial_flash_sim_model;

architecture rtl of serial_flash_sim_model is

	type t_sector is array(0 to 255) of std_ulogic_vector(7 downto 0);
	signal mem : t_sector;
	signal w_pointer : std_ulogic_vector(7 downto 0);
	signal w_data_to_program : std_ulogic_vector(7 downto 0);


	type t_state is (IDLE, RD_CMD, MNG_CMD , RD_ADDR_H, MNG_ADDRH, RD_ADDR_M , MNG_ADDRM, RD_ADDR_L, MNG_ADDRL, RD_DATA, RD_DUMMY, TX_DATA, MNG_TX_DATA);

	signal w_state : t_state;
	signal w_status_reg : std_ulogic_vector(7 downto 0);

	constant WR_ENABLE : std_ulogic_vector(7 downto 0) := "00000110";
	constant WR_DISABLE : std_ulogic_vector(7 downto 0) := "00000100";
	constant RD_STATUS_REG : std_ulogic_vector(7 downto 0) := "00000101";
	constant WR_STATUS_REG : std_ulogic_vector(7 downto 0) := "00000001";
	constant RD_DATA_CMD : std_ulogic_vector(7 downto 0) := "00000011";
	constant F_RD_DATA : std_ulogic_vector(7 downto 0) := "00001011";
	constant PAGE_PROGRAM : std_ulogic_vector(7 downto 0) := "00000010";
	constant SECTOR_ERASE : std_ulogic_vector(7 downto 0) := "11011000";
	constant BULK_ERASE : std_ulogic_vector(7 downto 0) := "11000111";

	signal w_cnt_rx_pos, w_cnt_rx_pos_r : unsigned(4 downto 0);
	signal w_cnt_tx_neg, w_cnt_tx_neg_r : unsigned(4 downto 0);
	signal w_sr_rx_pos_sclk : std_ulogic_vector(7 downto 0);
	signal w_cmd_reg : std_ulogic_vector(7 downto 0);

begin


	flasl_FSM : process(i_clk,i_arstn,i_s_n) is
	begin
		if(i_arstn = '0') then
			w_state <= IDLE;
			w_sr_rx_pos_sclk <= (others => '0');
			w_cnt_rx_pos <= (others => '0');
			o_dq <= '1';
			w_cnt_tx_neg <= (others => '0');
			for i in 0 to 255 loop 
				mem(i) <= (others => '1');
			end loop;
			w_status_reg <= (others => '0');
		elsif(i_s_n = '1') then
			w_state <= IDLE;
			o_dq <= '1';
			w_cnt_rx_pos <= (others => '0');
			w_cnt_tx_neg <= (others => '0');
			w_sr_rx_pos_sclk <= (others => '0');
		elsif (rising_edge(i_clk)) then
			--to finish operations when chip select deasserts
			case w_state is 
				when MNG_CMD =>
					w_cmd_reg <= w_sr_rx_pos_sclk;
					if (w_sr_rx_pos_sclk = "00000110") then
						w_status_reg(1) <= '1';
					elsif (w_sr_rx_pos_sclk = "00000100") then
						w_status_reg(1) <= '0';
						w_sr_rx_pos_sclk <= w_status_reg(6 downto 0) & i_dq;
					elsif (w_sr_rx_pos_sclk = "11000111" and w_status_reg(1) = '1') then
						for i in 0 to 255 loop 
							mem(i) <= (others => '1');
						end loop;
						w_status_reg (1 downto 0) <= "00";
					end if;
				when RD_DATA =>
					if(w_cnt_rx_pos = 7) then
						mem(to_integer(unsigned(w_pointer))) <= w_sr_rx_pos_sclk;
					end if;

				when others => null;
			end case;
		elsif (falling_edge(i_clk)) then
			case w_state is 
				when IDLE =>
					if(i_s_n = '0') then
						w_state <= RD_CMD;
						w_sr_rx_pos_sclk <= w_sr_rx_pos_sclk(6 downto 0) & i_dq;
					end if;
				when RD_CMD =>
					if(i_s_n = '0') then
						w_sr_rx_pos_sclk <= w_sr_rx_pos_sclk(6 downto 0) & i_dq;

						w_cnt_rx_pos_r <= w_cnt_rx_pos;
						if(w_cnt_rx_pos = 6) then
							w_cnt_rx_pos <= (others => '0');
							w_state <= MNG_CMD;
						else
							w_cnt_rx_pos <= w_cnt_rx_pos +1;
						end if;
					end if;
				when MNG_CMD =>
					w_cmd_reg <= w_sr_rx_pos_sclk;
					w_sr_rx_pos_sclk <= w_sr_rx_pos_sclk(6 downto 0) & i_dq;
					if(w_sr_rx_pos_sclk = "00000010" and w_status_reg(1) = '1') then
						w_state <= RD_ADDR_H;
					elsif(w_sr_rx_pos_sclk = "00000011") then
						w_state <= RD_ADDR_H;
					elsif(w_sr_rx_pos_sclk = "00001011") then
						w_state <= RD_ADDR_H;
					elsif (w_sr_rx_pos_sclk = "00000110") then
						w_status_reg(1) <= '1';
						w_state <= RD_CMD;
					elsif (w_sr_rx_pos_sclk = "00000100") then
						w_status_reg(1) <= '0';
						w_sr_rx_pos_sclk <= w_status_reg(6 downto 0) & i_dq;
						w_state <= RD_CMD;
					elsif (w_sr_rx_pos_sclk = "00000101") then
						w_state <= TX_DATA;
						o_dq <= w_status_reg(to_integer(7 - w_cnt_tx_neg));
						w_cnt_tx_neg <= to_unsigned(1,w_cnt_tx_neg'length);
					elsif (w_sr_rx_pos_sclk = "00000001" and w_status_reg(1) = '1') then
						w_cnt_rx_pos <= (others => '0');
						w_state <= RD_DATA;
						w_status_reg <= w_status_reg(6 downto 0) & i_dq;
					elsif (w_sr_rx_pos_sclk = "11000111" and w_status_reg(1) = '1') then
						w_state <= RD_CMD;
						for i in 0 to 255 loop 
							mem(i) <= (others => '1');
						end loop;
						w_status_reg (1 downto 0) <= "00";
					elsif (w_sr_rx_pos_sclk = "11011000" and w_status_reg(1) = '1') then
						w_state <= RD_ADDR_H;
					end if;
				when RD_ADDR_H =>
					if(i_s_n = '0') then
						w_sr_rx_pos_sclk <= w_sr_rx_pos_sclk(6 downto 0) & i_dq;

						w_cnt_rx_pos_r <= w_cnt_rx_pos;
						if(w_cnt_rx_pos = 6) then
							w_cnt_rx_pos <= (others => '0');
						else
							w_cnt_rx_pos <= w_cnt_rx_pos +1;
						end if;

						if(w_cnt_rx_pos = 6) then
							w_cnt_rx_pos <= (others => '0');
							w_state <= MNG_ADDRH;
						end if;
					else
						w_state <= IDLE;
					end if;
				when MNG_ADDRH =>
					w_state <= RD_ADDR_M;
					w_sr_rx_pos_sclk <= w_sr_rx_pos_sclk(6 downto 0) & i_dq;
				when RD_ADDR_M =>
					if(i_s_n = '0') then
						w_sr_rx_pos_sclk <= w_sr_rx_pos_sclk(6 downto 0) & i_dq;

						w_cnt_rx_pos_r <= w_cnt_rx_pos;
						if(w_cnt_rx_pos = 6) then
							w_cnt_rx_pos <= (others => '0');
						else
							w_cnt_rx_pos <= w_cnt_rx_pos +1;
						end if;

						if(w_cnt_rx_pos = 6) then
							w_cnt_rx_pos <= (others => '0');
							w_state <= MNG_ADDRM;
						end if;
					else
						w_state <= IDLE;
					end if;
				when MNG_ADDRM =>
					w_state <= RD_ADDR_L;
					w_sr_rx_pos_sclk <= w_sr_rx_pos_sclk(6 downto 0) & i_dq;
				when RD_ADDR_L =>
					if(i_s_n = '0') then
						w_sr_rx_pos_sclk <= w_sr_rx_pos_sclk(6 downto 0) & i_dq;

						w_cnt_rx_pos_r <= w_cnt_rx_pos;
						if(w_cnt_rx_pos = 6) then
							w_cnt_rx_pos <= (others => '0');
							w_state <= MNG_ADDRL;
						else
							w_cnt_rx_pos <= w_cnt_rx_pos +1;
						end if;

					else
						w_state <= IDLE;
					end if;
				when MNG_ADDRL =>
					if(w_cmd_reg = "00000010") then
						w_cnt_rx_pos <= (others => '0');
						w_state <= RD_DATA;
						w_pointer <= w_sr_rx_pos_sclk;
						w_sr_rx_pos_sclk <= w_sr_rx_pos_sclk(6 downto 0) & i_dq;

					elsif (w_cmd_reg = "00000011") then
						w_cnt_rx_pos <= (others => '0');
						w_state <= TX_DATA;
						w_pointer <= w_sr_rx_pos_sclk;
						o_dq <= mem(to_integer(unsigned(w_sr_rx_pos_sclk)))(7);
						w_cnt_tx_neg <= to_unsigned(1,w_cnt_tx_neg'length);
					elsif (w_cmd_reg = "00001011") then
						w_cnt_rx_pos <= (others => '0');
						w_state <= RD_DUMMY;
						w_pointer <= w_sr_rx_pos_sclk;
					elsif (w_cmd_reg = "11011000") then
						for i in 0 to 255 loop 
							mem(i) <= (others => '1');
						end loop;
						w_status_reg (1 downto 0) <= "00";
					end if;
				when RD_DUMMY =>
					if(i_s_n = '0') then
						if(w_cnt_rx_pos = 7) then
							w_cnt_rx_pos <= (others => '0');
							w_state <= TX_DATA;
							o_dq <= mem(to_integer(unsigned(w_pointer)))(7);
							w_cnt_tx_neg <= to_unsigned(1,w_cnt_tx_neg'length);
						else
							w_cnt_rx_pos <= w_cnt_rx_pos +1;
						end if;
					else
						
					end if;
				when RD_DATA =>
					if(i_s_n = '0') then
						if (w_cmd_reg = "00000001") then
							w_status_reg <= w_status_reg(6 downto 0) & i_dq;
						else	
							w_sr_rx_pos_sclk <= w_sr_rx_pos_sclk(6 downto 0) & i_dq;
						end if;

						w_cnt_rx_pos_r <= w_cnt_rx_pos;
						if(w_cnt_rx_pos = 7) then
							w_cnt_rx_pos <= (others => '0');
							w_pointer <= std_ulogic_vector(unsigned(w_pointer) +1); 
							mem(to_integer(unsigned(w_pointer))) <= w_sr_rx_pos_sclk;
						else
							w_cnt_rx_pos <= w_cnt_rx_pos +1;
						end if;
					else
						w_state <= IDLE;
						w_status_reg(1 downto 0) <= "00";
					end if;


				when TX_DATA =>
					if(i_s_n = '0') then
						if(w_cmd_reg = "00000101") then
							o_dq <= w_status_reg(to_integer(7 - w_cnt_tx_neg));
						else
							o_dq <= mem(to_integer(unsigned(w_pointer)))(to_integer((7 - w_cnt_tx_neg)));
						end if;
						w_cnt_tx_neg_r <= w_cnt_tx_neg;
						if(w_cnt_tx_neg = 7) then
							w_cnt_tx_neg <= (others => '0');
							w_state <= MNG_TX_DATA;
						else
							w_cnt_tx_neg <= w_cnt_tx_neg +1;
						end if;
					else
						w_state <= IDLE;
					end if;
				when MNG_TX_DATA =>
					w_state <= TX_DATA;
					w_pointer <= std_ulogic_vector(unsigned(w_pointer) +1);

					o_dq <= mem(to_integer(unsigned(w_pointer)+1))(7);
					w_cnt_tx_neg <= to_unsigned(1,w_cnt_tx_neg'length);
				when others => null;
			end case;
		end if;
	end process; -- flasl_FSM

end rtl;
