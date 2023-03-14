library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity m25p80_sim_model is
	port (
			C : in std_ulogic;
			D : in std_ulogic;
			S : in std_ulogic;
			Q : out std_ulogic);
end m25p80_sim_model;

architecture rtl of m25p80_sim_model is 
--=========================================================
--Define Parameters Regarding Memory
--=========================================================
constant  address_highest   : std_ulogic_vector(19 downto 0)  := x"FFFFF";
constant  address_zero      : std_ulogic_vector(19 downto 0)  := x"00000";
constant  address_increase  : unsigned(19 downto 0)  := x"00001";
constant  page_addr_highest : std_ulogic_vector(7 downto 0)  := x"FF";
constant  page_addr_zero    : std_ulogic_vector(7 downto 0)  := x"00";
constant  page_addr_increase: unsigned(7 downto 0)  := x"01";

--=========================================================
--Define Parameters Regarding Instructions
--=========================================================
constant WREN_INS : std_ulogic_vector(3 downto 0)  := "0001";
constant WRDI_INS : std_ulogic_vector(3 downto 0)  := "0010";
constant RDID_INS : std_ulogic_vector(3 downto 0)  := "0011";
constant RDSR_INS : std_ulogic_vector(3 downto 0)  := "0100";
constant READ_INS : std_ulogic_vector(3 downto 0)  := "0101";
constant HSRD_INS : std_ulogic_vector(3 downto 0)  := "0110";
constant PGWR_INS : std_ulogic_vector(3 downto 0)  := "0111";
constant PGPG_INS : std_ulogic_vector(3 downto 0)  := "1000";
constant PGES_INS : std_ulogic_vector(3 downto 0)  := "1001";
constant SCES_INS : std_ulogic_vector(3 downto 0)  := "1010";
constant DPPD_INS : std_ulogic_vector(3 downto 0)  := "1011";
constant RLDP_INS : std_ulogic_vector(3 downto 0)  := "1100";
constant WRLR_INS : std_ulogic_vector(3 downto 0)  := "1101";
constant RDLR_INS : std_ulogic_vector(3 downto 0)  := "1110";
constant BKES_INS : std_ulogic_vector(3 downto 0)  := "1111";

--=========================================================
--Define Parameter Regarding Operations
--=========================================================
constant WREN_OP : std_ulogic_vector(3 downto 0)   := "0001";
constant WRDI_OP : std_ulogic_vector(3 downto 0)   := "0010";
constant RDID_OP : std_ulogic_vector(3 downto 0)   := "0011";
constant RDSR_OP : std_ulogic_vector(3 downto 0)   := "0100";
constant READ_OP : std_ulogic_vector(3 downto 0)   := "0101";
constant HSRD_OP : std_ulogic_vector(3 downto 0)   := "0110";
constant PGWR_OP : std_ulogic_vector(3 downto 0)   := "0111";
constant PGPG_OP : std_ulogic_vector(3 downto 0)   := "1000";
constant PGES_OP : std_ulogic_vector(3 downto 0)   := "1001";
constant SCES_OP : std_ulogic_vector(3 downto 0)   := "1010";
constant DPPD_OP : std_ulogic_vector(3 downto 0)   := "1011";
constant RLDP_OP : std_ulogic_vector(3 downto 0)   := "1100";
constant WRLR_OP : std_ulogic_vector(3 downto 0)   := "1101";
constant RDLR_OP : std_ulogic_vector(3 downto 0)   := "1110";
constant BKES_OP : std_ulogic_vector(3 downto 0)   := "1111";

--===============================================
--Parameters Regarding Memory Attribute
--===============================================
constant DATA_BITS : natural := 8;
--Bytes in Memory, 8M bits = 1M bytes
constant MEM_SIZE : natural := 1048576;
--Address Bits for Whole Memory
constant MEM_ADDR_BITS : natural := 20;
--No. of Pages in Memory
constant PAGES :natural := 4096;
--No. of Bytes in Each Page
constant PAGE_SIZE : natural := 256;
--Address Bits for Page Access
constant PAGE_ADDR_BITS : natural := 12;
--Address Bits for Byte Access in One Page
constant PAGE_OFFSET_BITS : natural := 8;
--No. of Sectors in Memory
constant SECTORS : natural := 16;
--No. of Bytes in Each Sector
constant SECTOR_SIZE  : natural := 65536;
--Address Bits for Sector Access
constant SECTOR_ADDR_BITS : natural := 4;
--Address Bits for Byte Access in One Sector
constant SECTOR_OFFSET_BITS :natural := 16;
--No. of Lock Registers in Memory
constant NO_LOCK_REG : natural := 46;	


--=========================================================
--Define Parameters Regarding Device Mode
--=========================================================
constant np_mode : std_ulogic_vector(1 downto 0) := "00";
constant sb_mode : std_ulogic_vector(1 downto 0) := "01";
constant ap_mode : std_ulogic_vector(1 downto 0) := "10";
constant dp_mode : std_ulogic_vector(1 downto 0) := "11";

--=========================================================
--Define Variable Regarding Timing Check
--=========================================================
signal din_change,r_S,f_S,r_C,r_Cr,f_C,f_W,r_W,r_RESET,f_RESET,r_VCC : std_ulogic;
-----------------------------------------------------------
--time t_rCr,t_rCr1,Tcr,Tc,t_d,t_rC1,current_time;
--time t_rS,t_fS,t_rC,t_fC,t_fW,t_rW,t_rVCC,t_rRESET,t_fRESET;
--time tVSL,tCH,tCL,tSLCH,tCHSL,tDVCH,tCHDX;
--time tCHSH,tSHCH,tSHSL,tRHSL,tRLRH,tSHRH,tTHSL,tSHTL;

--=========================================================
--Define Variable, Reflecting the Device Operation Status
--=========================================================
signal i,sr_bit,bytes : integer;
-----------------------------------------------------------
signal power_on,power_on_rst : std_ulogic := '0';
signal power_off : std_ulogic := '1';
signal byte_ok,bit_counter_en,bit_counter_ld,bit7 : std_ulogic;
signal page_write,page_program,read_lock_register,write_lock_register : std_ulogic;
signal page_erase,sector_erase,read_data_bytes,read_data_bytes_fast : std_ulogic;
signal instruction_byte,address_h_byte,address_m_byte,address_l_byte,data_byte,dummy_byte : std_ulogic;
signal wren_id,wrdi_id,pges_id,sces_id,bkes_id,dppd_id,rldp_id,wrda_id : std_ulogic;
signal wr_protect,bk_protect,sc_protect,dout,hw_rst,ins_rej,rst_in_cycle : std_ulogic;
signal device_power_down,deep_pd_delay,release_pd_delay : std_ulogic;
signal not_deep_pd,not_release_pd : std_ulogic := '0';
-----------------------------------------------------------
signal lk_reg_no : std_ulogic_vector(5 downto 0);
signal instruction,operation,sector,sub_sector : std_ulogic_vector(3 downto 0);
signal shift_in_reg,instruction_code,address_h_code,address_m_code,address_l_code : std_ulogic_vector(7 downto 0);
signal status_reg,data_out_buf,temp: std_ulogic_vector( 7 downto 0);
signal bit_counter : unsigned(2 downto 0);
signal mode : std_ulogic_vector(1 downto 0) := np_mode;
signal previous_op : std_ulogic_vector(1 downto 0);
-----------------------------------------------------------
signal device_id,memory_address : std_ulogic_vector(23 downto 0);
type t_array is array(1048575 downto 0) of std_ulogic_vector(7 downto 0);
signal memory : t_array;
type t_latch is array(255 downto 0) of std_ulogic_vector(7 downto 0);
signal data_latch : t_latch;
signal page_address : std_ulogic_vector(11 downto 0);
signal sector_address : std_ulogic_vector(3 downto 0);

begin
-----------------------------------------------------------
Q <= dout;

--#########################################################
--Power on Reset
--#########################################################
--power_on_rst : process(power_on_rst) is
--begin
--	if(power_on_rst = '1') then
--		mode  <= sb_mode;
--		power_on_rst <= '0';
--		hw_rst <= '0';
--		byte_ok <= '0';
--		rst_in_cycle <= '0';
--		ins_rej <= '0';
--		instruction<= (others => '0');
--		operation <= (others => '0');
--		previous_op <=(others => '0');
--		status_reg <=(others => '0');
--		wr_protect <='0';
--		bit_counter_en <= '0';
--		bk_protect <= '0';
--		page_erase <= '0';
--		sector_erase <= '0';
--		page_program <= '0';
--		read_data_bytes <= '0';
--		read_data_bytes_fast <= '0';
--		wren_id <= '0';
--		wrdi_id <= '0';
--		pges_id <= '0';
--		wrda_id <= '0';
--		sces_id <= '0';
--		bkes_id <= '0';
--		address_h_byte <= '0';
--		address_m_byte <= '0';
--		address_l_byte <= '0';
--		dummy_byte <= '0';
--		data_byte <= '0';
--		instruction_byte <= '0';
--	end if;
--end process; -- power_on_rst


active_power_mode : process(all) is
begin
	if(falling_edge(S))then
    	instruction_byte <= '1';  --ready for instruction
      	-----------------------------------------------------
        mode <= ap_mode;
        bit_counter_en <= '1';
        bit_counter_ld <= '1';    --enable the bit_counter
	end if;
end process; -- active_power_mode

serial_input : process(C) is
begin
	if(rising_edge(C)) then
		if(S = '0') then
			if(bit_counter_en = '1' and bit_counter_ld = '1') then
				shift_in_reg <= shift_in_reg(6 downto 0) & D;
				bit_counter <= "111";
		        if(operation = WREN_OP) then
		         wren_id <= '0';
		     	end if;
		        if(operation = WRDI_OP) then
		         wrdi_id <= '0';
		     	end if;
		        if(operation = WRLR_OP) then
		         wrda_id <= '0';
		     	end if;
		        if(operation = PGWR_OP) then
		         wrda_id <= '0';
		     	end if;
		        if(operation = PGPG_OP) then
		         wrda_id <= '0';
		     	end if;
		        if(operation = PGES_OP) then
		         pges_id <= '0';
		     	end if;
		        if(operation = SCES_OP) then
		         sces_id <= '0';
		     	end if;
		        if(operation = BKES_OP) then
		         bkes_id <= '0';
		     	end if;
		        if(operation = DPPD_OP) then
		         dppd_id <= '0';
		     	end if;
		        if(operation = RLDP_OP) then
		         rldp_id <= '0';
		     	end if;
		    elsif(bit_counter_en = '1' and bit_counter_ld = '0') then
		    	shift_in_reg <= shift_in_reg(6 downto 0) & D;
		    	bit_counter <= bit_counter -1;
			end if;
			if(bit_counter_en = '1' and bit_counter = 0) then
				byte_ok <= '1';
				bit_counter_en <= '0';
			elsif (bit_counter_en = '1') then
				bit_counter_ld <= '0';
			end if;
		end if;
	end if;
end process; -- serial_input

instruction_treatment : process(C) is
begin
	if(falling_edge(C)) then
		if(mode = ap_mode and instruction_byte = '1' and byte_ok = '1') then
			instruction_byte <= '0';
			byte_ok <= '0';
			instruction_code <= shift_in_reg;
			case instruction_code is 
				when "00000110" =>
					if(ins_rej = '1') then
						ins_rej <= '0';
					else
						instruction <= WREN_INS;
					end if;
				when "00000100" =>
					if(ins_rej = '1') then
						ins_rej <= '0';
					else
						instruction <= WRDI_INS;
					end if;
				when "00000101" =>
					if(ins_rej = '1') then
						ins_rej <= '0';
					else
						instruction <=  RDSR_INS;
						sr_bit <= 8;
					end if;
				when "00000011" =>
					if(ins_rej = '1') then
						ins_rej <= '0';
					else
						instruction <= READ_INS;
					end if;
				when "00001011" =>
					if(ins_rej = '1') then
						ins_rej <= '0';
					else
						instruction <= HSRD_INS;
					end if;
				when "00000010" =>
					if(ins_rej = '1') then
						ins_rej <= '0';
					else
						instruction <= PGPG_INS;
					end if;
				when "11011000" =>
					if(ins_rej = '1') then
						ins_rej <= '0';
					else
						instruction <= SCES_INS;
					end if;
				when "11000111" =>
					if(ins_rej = '1') then
						ins_rej <= '0';
					else
						instruction <= BKES_INS;
					end if;
				when others =>
					null;
			end case;
		end if;
	  	--=================================== Instruction Treatment
		case instruction is 
			when WREN_INS =>
				instruction <= "0000";
				operation <= WREN_OP;
				wren_id <= '1';
			when WRDI_INS =>
				instruction <= "0000";
				operation <= WRDI_OP;
				wrdi_id <= '1';
			when RDSR_INS =>
				operation <= RDSR_OP;
				if(sr_bit = 0) then
					sr_bit <= 8;
				end if;
				dout <= status_reg(sr_bit-1);
				sr_bit <= sr_bit -1;
			when READ_INS =>
				instruction <= "0000";
				read_data_bytes <= '1';
				address_h_byte <= '1';
				bit_counter_en <= '1';
				bit_counter_ld <= '1';
			when HSRD_INS =>
				instruction <= "0000";
				read_data_bytes <= '1';
				address_h_byte <= '1';
				bit_counter_en <= '1';
				bit_counter_ld <= '1';
			when PGPG_INS =>
				instruction <= "0000";
				if(status_reg(1) = '1') then
					page_program <= '1';
					address_h_byte <= '1';
					bit_counter_en <= '1';
					bit_counter_ld <= '1';
				end if;
			when SCES_INS =>
				instruction <= "0000";
				if(status_reg(1) = '1') then
					sector_erase <= '1';
					address_h_byte <= '1';
					bit_counter_en <= '1';
					bit_counter_ld <= '1';
			   	end if;
			when BKES_INS =>
				instruction <= "0000";
				operation <= BKES_OP;
				bkes_id <= '1';
			when others =>
				null;
		end case;

		if(mode = ap_mode and address_h_byte = '1' and byte_ok = '1') then
			address_h_byte <= '0';
			byte_ok <= '0';
			address_h_code <= shift_in_reg;
			address_m_byte <= '1';
			bit_counter_en <= '1';
			bit_counter_ld <= '1';
		end if;

		if(mode = ap_mode and address_m_byte = '1' and byte_ok = '1') then
			address_m_byte <= '0';
			byte_ok <= '0';
			address_m_code <= shift_in_reg;
			address_l_byte <= '1';
			bit_counter_en <= '1';
			bit_counter_ld <= '1';
		end if;

		if(mode = ap_mode and address_l_byte = '1' and byte_ok = '1') then
			address_l_byte <= '0';
			byte_ok <= '0';
			address_l_code <= shift_in_reg;
			memory_address <= address_h_code & address_m_code & address_l_code;

			if(sector_erase = '1') then
				operation <= SCES_OP;
				sector_erase <= '0';
				sces_id <= '1';
			end if;

			if(read_data_bytes = '1') then
				operation <= READ_OP;
				read_data_bytes <= '0';
				i <= 8;
			end if;

			if(read_data_bytes_fast = '1') then
				bit_counter_en <= '1';
				dummy_byte <= '1';
				bit_counter_ld <= '1';
				read_data_bytes_fast <= '0';
			end if;

			if(page_program = '1') then
				operation <= PGPG_OP;
				bit_counter_en <= '1';
				bit_counter_ld <= '1';
				data_byte <= '1';
				bytes <= 0;
				page_program <= '0';
				page_address <= memory_address(19 downto 8);
				for j in 1 to 256 loop 
					data_latch(to_integer(unsigned(memory_address(7 downto 0)))) <= memory(to_integer(unsigned(memory_address(19 downto 0))));
					if(memory_address(7 downto 0) = page_addr_highest) then
						memory_address(7 downto 0) <= page_addr_zero;
					else
						memory_address(7 downto 0) <= std_ulogic_vector(unsigned(memory_address(7 downto 0)) + page_addr_increase);
					end if;
				end loop;
			end if;
		end if;
		if(mode = ap_mode and dummy_byte = '1' and byte_ok = '1') then
			operation <= HSRD_OP;
			i <= 8;
			byte_ok <= '0';
			dummy_byte <= '0';
		end if;

		if(mode = ap_mode and data_byte = '1' and byte_ok = '1') then
			if(operation = PGPG_OP) then
				bytes <= bytes +1;
				bit_counter_en <= '1';
				byte_ok <= '1';
				bit_counter_ld <= '1';
				wrda_id <= '1';
				data_latch(to_integer(unsigned(memory_address(7 downto 0)))) <= data_latch(to_integer(unsigned(memory_address(7 downto 0)))) & shift_in_reg;
				if(memory_address(7 downto 0) = x"FF") then
					memory_address(7 downto 0) <= x"00";
				else
					memory_address(7 downto 0) <= std_ulogic_vector(unsigned(memory_address(7 downto 0)) + 1);
				end if;
			end if;

			if(operation = READ_OP) then
				if(i = 0) then
					i <= 8;
					if(memory_address(19 downto 0) = address_highest) then
						memory_address(19 downto 0) <= address_zero;
					else
						memory_address(19 downto 0) <= std_ulogic_vector(unsigned(memory_address(19 downto 0)) + address_increase);
					end if;
					data_out_buf <= memory(to_integer(unsigned(memory_address(19 downto 0))));
					dout <= data_out_buf(i-1);
					i <= i-1;
				end if;
			end if;

			if(operation = HSRD_OP) then
				if(i = 0) then
					i <= 8;
					if(memory_address(19 downto 0) = address_highest) then
						memory_address(19 downto 0) <= address_zero;
					else
						memory_address(19 downto 0) <= std_ulogic_vector(unsigned(memory_address(19 downto 0)) + address_increase);
					end if;
					data_out_buf <= memory(to_integer(unsigned(memory_address(19 downto 0))));
					dout <= data_out_buf(i-1);
					i <= i-1;
				end if;
			end if;

		end if;
	end if;
end process; -- instruction_treatment

cs_driven_high : process(S) is
begin
	if(rising_edge(S)) then
		if(status_reg(0) = '1' and operation = RDSR_OP) then
			instruction <= "0000";
			dout <= 'Z';
			operation <= "0000";
		end if;
	end if;
end process; -- cs_driven_high


cs_goes_high_manage : process(S) is
begin
	if(rising_edge(S)) then
		mode <= sb_mode;
		if(operation = WREN_OP) then
			operation <= "0000";
			dout <= 'Z';
			if(wren_id = '1') then
				status_reg(1) <= '1';
				wren_id <= '1';
			end if;
		end if;

		if(operation = WRDI_OP) then
			operation <= "0000";
			dout <= 'Z';
			if(wrdi_id = '1') then
				status_reg(1) <= '1';
				wrdi_id <= '1';
			end if;
		end if;

		if(operation = RDSR_OP) then
			operation <= "0000";
			dout <= 'Z';
			instruction <= "0000";
		end if;

		if(operation = READ_OP) then
			operation <= "0000";
			dout <= 'Z';
		end if;

		if(operation = HSRD_OP) then
			operation <= "0000";
			dout <= 'Z';
		end if;

		if(operation = PGPG_OP) then
			dout <= 'Z';
			data_byte <= '0';
			if(bytes < 256) then
				bytes <= 0;
			end if;
			if(wrda_id = '1') then
				status_reg(1) <= 'X';
				status_reg(0) <= '1';
				memory_address(7 downto 0) <= x"00";
				for j in 1 to 256 loop
					memory(to_integer(unsigned(memory_address(19 downto 0)))) <= data_latch(to_integer(unsigned(memory_address(7 downto 0))));
					memory_address(7 downto 0) <= std_ulogic_vector(unsigned(memory_address(7 downto 0)) + 1);
				end loop;
			end if;
		end if;

		if(operation = SCES_OP) then
			dout <= 'Z';
			sector_address <= memory_address(19 downto 16);
			if(sces_id = '1') then
				status_reg(1) <= 'X';
				status_reg(0) <= '1';
				memory_address(3 downto 0) <= "0000";
				for j in 1 to 65536 loop 
					memory(to_integer(unsigned(memory_address(19 downto 0)))) <= x"FF";
					memory_address(3 downto 0) <= std_ulogic_vector(unsigned(memory_address(3 downto 0)) + 1);
				end loop;
			end if;
		end if;

		if(operation = BKES_OP) then
			dout <= 'Z';
			if(bkes_id = '1') then
				status_reg(1) <= 'X';
				status_reg(0) <= '1';
				for j in 1 to MEM_SIZE loop 
					memory(to_integer(unsigned(memory_address(19 downto 0)))) <= x"FF";
					memory_address(19 downto 0) <= std_ulogic_vector(unsigned(memory_address(19 downto 0)) + address_increase);
				end loop;
			end if;
		end if;

	end if;
end process; -- cs_goes_high_manage


end rtl;