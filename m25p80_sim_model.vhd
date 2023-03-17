library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity m25p80_sim_model is
	port (
			i_clk : in std_ulogic;
			C : in std_ulogic;
			D : in std_ulogic;
			S : in std_ulogic;
			Q : out std_ulogic);
end m25p80_sim_model;

architecture rtl of m25p80_sim_model is 

--===============================================
--Parameters Regarding Memory Attribute
--===============================================
--These are the actual sizes of M25P80, below follow then 
--reduced numbers that we will use for the sake of simulation

--constant DATA_BITS : natural := 8;
----Bytes in Memory, 8M bits = 1M bytes
--constant MEM_SIZE : natural := 1048576;
----Address Bits for Whole Memory
--constant MEM_ADDR_BITS : natural := 20;
----No. of Pages in Memory
--constant PAGES :natural := 4096;
----No. of Bytes in Each Page
--constant PAGE_SIZE : natural := 256;
----Address Bits for Page Access
--constant PAGE_ADDR_BITS : natural := 12;
----Address Bits for Byte Access in One Page
--constant PAGE_OFFSET_BITS : natural := 8;
----No. of Sectors in Memory
--constant SECTORS : natural := 16;
----No. of Bytes in Each Sector
--constant SECTOR_SIZE  : natural := 65536;
----Address Bits for Sector Access
--constant SECTOR_ADDR_BITS : natural := 4;
----Address Bits for Byte Access in One Sector
--constant SECTOR_OFFSET_BITS :natural := 16;
----No. of Lock Registers in Memory
--constant NO_LOCK_REG : natural := 46;	


constant DATA_BITS : natural := 8;
--Bytes in Memory, 8M bits = 1M bytes
constant MEM_SIZE : natural := 1024;
--Address Bits for Whole Memory
constant MEM_ADDR_BITS : natural := 10;
--No. of Pages in Memory
constant PAGES :natural := 64;
--No. of Bytes in Each Page
constant PAGE_SIZE : natural := 16;
--Address Bits for Page Access
constant PAGE_ADDR_BITS : natural := 6;
--Address Bits for Byte Access in One Page
constant PAGE_OFFSET_BITS : natural := 4;
--No. of Sectors in Memory
constant SECTORS : natural := 16;
--No. of Bytes in Each Sector
constant SECTOR_SIZE  : natural := 64;
--Address Bits for Sector Access
constant SECTOR_ADDR_BITS : natural := 4;
--Address Bits for Byte Access in One Sector
constant SECTOR_OFFSET_BITS :natural := 6;
--No. of Lock Registers in Memory
constant NO_LOCK_REG : natural := 46;

--=========================================================
--Define Parameters Regarding Memory
--=========================================================
constant  address_highest   : std_ulogic_vector(MEM_ADDR_BITS-1 downto 0)  := (others => '1');
constant  address_zero      : std_ulogic_vector(MEM_ADDR_BITS-1 downto 0)  := (others => '0');
constant  address_increase  : unsigned(MEM_ADDR_BITS-1 downto 0)  := to_unsigned(1,MEM_ADDR_BITS);
constant  page_addr_highest : std_ulogic_vector(PAGE_OFFSET_BITS-1 downto 0)  := (others => '1');
constant  page_addr_zero    : std_ulogic_vector(PAGE_OFFSET_BITS-1 downto 0)  := (others => '0');
constant  page_addr_increase: unsigned(PAGE_OFFSET_BITS-1 downto 0)  := to_unsigned(1,PAGE_OFFSET_BITS);

--=========================================================
--Define Parameters Regarding Instructions
--=========================================================
constant WREN_INS : std_ulogic_vector(3 downto 0)  := "0001";
constant WRDI_INS : std_ulogic_vector(3 downto 0)  := "0010";
constant RDID_INS : std_ulogic_vector(3 downto 0)  := "0011";
constant WRSR_INS : std_ulogic_vector(3 downto 0)  := "1100";
constant RDSR_INS : std_ulogic_vector(3 downto 0)  := "0100";
constant READ_INS : std_ulogic_vector(3 downto 0)  := "0101";
constant HSRD_INS : std_ulogic_vector(3 downto 0)  := "0110";
constant PGWR_INS : std_ulogic_vector(3 downto 0)  := "0111";
constant PGPG_INS : std_ulogic_vector(3 downto 0)  := "1000";
constant PGES_INS : std_ulogic_vector(3 downto 0)  := "1001";
constant SCES_INS : std_ulogic_vector(3 downto 0)  := "1010";
constant DPPD_INS : std_ulogic_vector(3 downto 0)  := "1011";
--constant RLDP_INS : std_ulogic_vector(3 downto 0)  := "1100";
constant WRLR_INS : std_ulogic_vector(3 downto 0)  := "1101";
constant RDLR_INS : std_ulogic_vector(3 downto 0)  := "1110";
constant BKES_INS : std_ulogic_vector(3 downto 0)  := "1111";

--=========================================================
--Define Parameter Regarding Operations
--=========================================================
constant WREN_OP : std_ulogic_vector(3 downto 0)   := "0001";
constant WRDI_OP : std_ulogic_vector(3 downto 0)   := "0010";
constant RDID_OP : std_ulogic_vector(3 downto 0)   := "0011";
constant WRSR_OP : std_ulogic_vector(3 downto 0)   := "1100";
constant RDSR_OP : std_ulogic_vector(3 downto 0)   := "0100";
constant READ_OP : std_ulogic_vector(3 downto 0)   := "0101";
constant HSRD_OP : std_ulogic_vector(3 downto 0)   := "0110";
constant PGWR_OP : std_ulogic_vector(3 downto 0)   := "0111";
constant PGPG_OP : std_ulogic_vector(3 downto 0)   := "1000";
constant PGES_OP : std_ulogic_vector(3 downto 0)   := "1001";
constant SCES_OP : std_ulogic_vector(3 downto 0)   := "1010";
constant DPPD_OP : std_ulogic_vector(3 downto 0)   := "1011";
--constant RLDP_OP : std_ulogic_vector(3 downto 0)   := "1100";
constant WRLR_OP : std_ulogic_vector(3 downto 0)   := "1101";
constant RDLR_OP : std_ulogic_vector(3 downto 0)   := "1110";
constant BKES_OP : std_ulogic_vector(3 downto 0)   := "1111";

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
signal S_prev : std_ulogic;
-----------------------------------------------------------
--time t_rCr,t_rCr1,Tcr,Tc,t_d,t_rC1,current_time;
--time t_rS,t_fS,t_rC,t_fC,t_fW,t_rW,t_rVCC,t_rRESET,t_fRESET;
--time tVSL,tCH,tCL,tSLCH,tCHSL,tDVCH,tCHDX;
--time tCHSH,tSHCH,tSHSL,tRHSL,tRLRH,tSHRH,tTHSL,tSHTL;

--=========================================================
--Define Variable, Reflecting the Device Operation Status
--=========================================================
signal i,bytes,bytes_int : integer := 0;
signal sr_bit : integer := 8;
-----------------------------------------------------------
signal power_on,power_on_rst : std_ulogic := '0';
signal power_off : std_ulogic := '1';


signal byte_ok,bit_counter_en,bit_counter_ld,bit7 : std_logic := '0';
--signal byte_ok,bit_counter_en,bit_counter_ld,bit7 : std_ulogic;

signal page_write,page_program,read_lock_register,write_lock_register : std_ulogic := '0';
signal page_erase,sector_erase,read_data_bytes,read_data_bytes_fast, read_status_reg, write_status_reg : std_ulogic := '0';
signal instruction_byte,address_h_byte,address_m_byte,address_l_byte,data_byte,dummy_byte : std_logic := '0';
--signal instruction_byte,address_h_byte,address_m_byte,address_l_byte,data_byte,dummy_byte : std_ulogic;

signal wren_id,wrdi_id,wrsr_id,pges_id,sces_id,bkes_id,dppd_id,rldp_id,wrda_id : std_logic := '0';
--signal wren_id,wrdi_id,pges_id,sces_id,bkes_id,dppd_id,rldp_id,wrda_id : std_ulogic;

signal wr_protect,bk_protect,sc_protect,dout,hw_rst,ins_rej,rst_in_cycle : std_logic := '0';
--signal wr_protect,bk_protect,sc_protect,dout,hw_rst,ins_rej,rst_in_cycle : std_ulogic;

signal device_power_down,deep_pd_delay,release_pd_delay : std_ulogic := '0';
signal not_deep_pd,not_release_pd : std_ulogic := '0';
-----------------------------------------------------------
signal lk_reg_no : std_ulogic_vector(5 downto 0);
signal instruction,operation,sector,sub_sector : std_logic_vector(3 downto 0) :=(others => '0');
--signal instruction,operation,sector,sub_sector : std_ulogic_vector(3 downto 0);

signal shift_in_reg,instruction_code,address_h_code,address_m_code,address_l_code : std_ulogic_vector(7 downto 0) :=(others => '0');
signal status_reg,data_out_buf,temp: std_ulogic_vector( 7 downto 0) :=(others => '0');
signal bit_counter : unsigned(2 downto 0) := (others => '0');
signal mode : std_logic_vector(1 downto 0) := sb_mode;
--signal mode : std_ulogic_vector(1 downto 0) := np_mode;

signal previous_op : std_ulogic_vector(1 downto 0) :=(others => '0');
-----------------------------------------------------------
signal device_id,memory_address : std_logic_vector(23 downto 0) :=(others => '0');
--signal device_id,memory_address : std_ulogic_vector(23 downto 0);

type t_array is array(MEM_SIZE-1 downto 0) of std_ulogic_vector(DATA_BITS-1 downto 0);
signal memory : t_array;
type t_latch is array(PAGE_SIZE-1 downto 0) of std_ulogic_vector(DATA_BITS-1 downto 0);
signal data_latch : t_latch;
signal page_address : std_ulogic_vector(PAGE_ADDR_BITS-1 downto 0) :=(others => '0');
signal sector_address : std_ulogic_vector(SECTOR_ADDR_BITS-1 downto 0) :=(others => '0');

begin
-----------------------------------------------------------
Q <= dout;
bytes <= 0 when (S = '1' and operation = PGPG_OP and bytes_int <256) else bytes_int;


----active_power_mode : process(all) is
--active_power_mode : process(i_clk) is
--begin
--	if(rising_edge(i_clk)) then
--		S_prev <= S;
--		if(S = '0' and S_prev = '1') then
--		--if(falling_edge(S))then	
--	    	instruction_byte <= force '1';  --ready for instruction
--	      	-----------------------------------------------------
--	        mode <= force ap_mode;
--	        bit_counter_en <= '1';
--	        bit_counter_ld <= force  '1';    --enable the bit_counter
--		end if;
--	end if;
--end process; -- active_power_mode

serial_input : process(C) is
begin
	if(rising_edge(C)) then
		if(S = '0') then
			if(bit_counter_en = '1' and bit_counter_ld = '1') then
				shift_in_reg <= force shift_in_reg(6 downto 0) & D;
				bit_counter <= force "111";
		        if(operation = WREN_OP) then
		         wren_id <= force '0';
		     	end if;
		        if(operation = WRDI_OP) then
		         wrdi_id <= force '0';
		     	end if;
		        if(operation = WRLR_OP) then
		         wrda_id <= force '0';
		     	end if;
		        if(operation = PGWR_OP) then
		         wrda_id <= force '0';
		     	end if;
		        if(operation = PGPG_OP) then
		         wrda_id <= force '0';
		     	end if;
		     	if(operation = WRSR_OP) then
		     		wrsr_id <= force '0';
		     	end if;
		        if(operation = PGES_OP) then
		         pges_id <= '0';
		     	end if;
		        if(operation = SCES_OP) then
		         sces_id <= force '0';
		     	end if;
		        if(operation = BKES_OP) then
		         bkes_id <= force '0';
		     	end if;
		        if(operation = DPPD_OP) then
		         dppd_id <= '0';
		     	end if;
		      --  if(operation = RLDP_OP) then
		      --   rldp_id <= '0';
		     	--end if;
		    elsif(bit_counter_en = '1' and bit_counter_ld = '0') then
		    	shift_in_reg <= force shift_in_reg(6 downto 0) & D;
		    	bit_counter <= force bit_counter -1;
			end if;
			--if(bit_counter_en = '1' and  bit_counter_ld = '0' and  bit_counter = 0) then
			if(bit_counter_en = '1' and  bit_counter_ld = '0' and  bit_counter = 1) then
				byte_ok <= force '1';
				bit_counter_en <= force '0';
			elsif (bit_counter_en = '1') then
				bit_counter_ld <= force  '0';
			end if;
		end if;
	end if;
end process; -- serial_input

instruction_treatment : process(C) is
	variable v_mem_addr : std_ulogic_vector(23 downto 0) := (others => '0');
begin
	if(falling_edge(C)) then
		if(mode = ap_mode and instruction_byte = '1' and byte_ok = '1') then
			instruction_byte <= force '0';
			byte_ok <= force '0';
			--instruction_code <= force shift_in_reg;
			--case instruction_code is 
			case shift_in_reg is 
				when "00000110" =>
					if(ins_rej = '1') then
						ins_rej <= '0';
					else
						instruction <= force WREN_INS;
						if(status_reg(0) = '1') then
							null;
						else
							operation <= force WREN_OP;
							wren_id <= force '1';	
						end if;
					end if;
				when "00000100" =>
					if(ins_rej = '1') then
						ins_rej <= '0';
					else
						instruction <= force WRDI_INS;
						if(status_reg(0) = '1') then
							null;
						else
							operation <= force WRDI_OP;
							wrdi_id <= force '1';
						end if;
					end if;
				when "00000101" =>
					if(ins_rej = '1') then
						ins_rej <= '0';
					else
						instruction <= force  RDSR_INS;
						sr_bit <= force 7;

						operation <= force RDSR_OP;
						write_status_reg <= force '1';
						dout <= force status_reg(7);
						--sr_bit <= force sr_bit -1;
						--if(sr_bit = 0) then
						--	sr_bit <= force 8;
						--end if;
						--dout <= force status_reg(sr_bit-1);
						--sr_bit <= force sr_bit -1;
					end if;
				when "00000011" =>
					if(ins_rej = '1') then
						ins_rej <= '0';
					else
						instruction <= force READ_INS;

						if(status_reg(0) = '1') then
							null;
						else
							read_data_bytes <= force '1';
							address_h_byte <= force '1';
							bit_counter_en <= force '1';
							bit_counter_ld <= force  '1';
						end if;
					end if;
				when "00001011" =>
					if(ins_rej = '1') then
						ins_rej <= '0';
					else
						instruction <= force HSRD_INS;

						if(status_reg(0) = '1') then
							null;
						else
							read_data_bytes_fast <= force '1';
							address_h_byte <= force '1';
							bit_counter_en <= force  '1';
							bit_counter_ld <= force  '1';
						end if;
					end if;
				when "00000010" =>
					if(ins_rej = '1') then
						ins_rej <= '0';
					else
						instruction <= force PGPG_INS;

						if(status_reg(0) = '1') then
							null;
						else
							if(status_reg(1) = '1') then
								page_program <= force '1';
								address_h_byte <= force '1';
								bit_counter_en <= force  '1';
								bit_counter_ld <= force  '1';
							end if;
						end if;
					end if;

				when "00000001" =>
					if(ins_rej = '1') then
						ins_rej <= '0';
					else
						instruction <= force WRSR_INS;

						if(status_reg(0) = '1') then
							null;
						else
							if(status_reg(1) = '1') then
								read_status_reg <= force '1';
								operation <= WRSR_OP;
								wrsr_id <= force '1';
								bit_counter_en <= force '1';
								bit_counter_ld <= force '1';
							end if;
						end if;
					end if;
				when "11011000" =>
					if(ins_rej = '1') then
						ins_rej <= '0';
					else
						instruction <= force SCES_INS;

					if(status_reg(0) = '1') then
						null;
					else
						if(status_reg(1) = '1') then
							sector_erase <= force '1';
							address_h_byte <= force '1';
							bit_counter_en <= force  '1';
							bit_counter_ld <= force  '1';
					   	end if;
				   end if;
					end if;
				when "11000111" =>
					if(ins_rej = '1') then
						ins_rej <= '0';
					else
						instruction <= force BKES_INS;

						if(status_reg(0) = '1') then
							null;
						else
							if(status_reg(1) = '1') then
								operation <= force BKES_OP;
								bkes_id <= force '1';
							end if;
						end if;
					end if;
				when others =>
					null;
			end case;
		end if;
	 -- 	--=================================== Instruction Treatment
		--case instruction is 
		--	when WREN_INS =>
		--		instruction <= force "0000";
		--		if(status_reg(0) = '1') then
		--			null;
		--		else
		--			operation <= force WREN_OP;
		--			wren_id <= force '1';	
		--		end if;
		--	when WRDI_INS =>
		--		instruction <= force "0000";
		--		if(status_reg(0) = '1') then
		--			null;
		--		else
		--			operation <= force WRDI_OP;
		--			wrdi_id <= force '1';
		--		end if;
		--	when RDSR_INS =>
		--		operation <= force RDSR_OP;
		--		if(sr_bit = 0) then
		--			sr_bit <= force 8;
		--		end if;
		--		dout <= force status_reg(sr_bit-1);
		--		sr_bit <= force sr_bit -1;
		--	when READ_INS =>
		--		instruction <= force "0000";
		--		if(status_reg(0) = '1') then
		--			null;
		--		else
		--			read_data_bytes <= force '1';
		--			address_h_byte <= force '1';
		--			bit_counter_en <= '1';
		--			bit_counter_ld <= force  '1';
		--		end if;
		--	when HSRD_INS =>
		--		instruction <= force "0000";
		--		if(status_reg(0) = '1') then
		--			null;
		--		else
		--			read_data_bytes <= force '1';
		--			address_h_byte <= force '1';
		--			bit_counter_en <= force  '1';
		--			bit_counter_ld <= force  '1';
		--		end if;
		--	when PGPG_INS =>
		--		instruction <= force "0000";
		--		if(status_reg(0) = '1') then
		--			null;
		--		else
		--			if(status_reg(1) = '1') then
		--				page_program <= force '1';
		--				address_h_byte <= force '1';
		--				bit_counter_en <= force  '1';
		--				bit_counter_ld <= force  '1';
		--			end if;
		--		end if;
		--	when SCES_INS =>
		--		instruction <= force "0000";
		--		if(status_reg(0) = '1') then
		--			null;
		--		else
		--			if(status_reg(1) = '1') then
		--				sector_erase <= force '1';
		--				address_h_byte <= force '1';
		--				bit_counter_en <= force  '1';
		--				bit_counter_ld <= force  '1';
		--		   	end if;
		--	   end if;
		--	when BKES_INS =>
		--		instruction <= force "0000";
		--		if(status_reg(0) = '1') then
		--			null;
		--		else
		--			if(status_reg(1) = '1') then
		--				operation <= force BKES_OP;
		--				bkes_id <= force '1';
		--			end if;
		--		end if;
		--	when others =>
		--		null;
		--end case;
		if(mode = ap_mode and write_status_reg = '1' and sr_bit /= 0) then
			dout <= force status_reg(sr_bit-1);
			sr_bit <= force sr_bit -1;
		elsif (mode = ap_mode and write_status_reg = '1' and sr_bit = 0) then
			write_status_reg <= force '0';
		end if;

		if(mode = ap_mode and read_status_reg = '1' and byte_ok = '1') then
				read_status_reg <= force '0';
				byte_ok <= force '0';
				status_reg <= force shift_in_reg;
				bit_counter_en <= force '0';
				bit_counter_ld <= force '0';
		end if;

		if(mode = ap_mode and address_h_byte = '1' and byte_ok = '1') then
			address_h_byte <= force '0';
			byte_ok <= force '0';
			address_h_code <= force shift_in_reg;
			address_m_byte <= force '1';
			bit_counter_en <= force  '1';
			bit_counter_ld <= force  '1';
		end if;

		if(mode = ap_mode and address_m_byte = '1' and byte_ok = '1') then
			address_m_byte <= force '0';
			byte_ok <= force '0';
			address_m_code <= force shift_in_reg;
			address_l_byte <= force '1';
			bit_counter_en <= force  '1';
			bit_counter_ld <= force  '1';
		end if;

		if(mode = ap_mode and address_l_byte = '1' and byte_ok = '1') then
			address_l_byte <= force '0';
			byte_ok <= force '0';
			address_l_code <= force shift_in_reg;
			--memory_address <= address_h_code & address_m_code & address_l_code;
			memory_address <= force (address_h_code & address_m_code & shift_in_reg);
			v_mem_addr := (address_h_code & address_m_code & shift_in_reg);

			if(sector_erase = '1') then
				operation <= force SCES_OP;
				sector_erase <= force '0';
				sces_id <= force '1';
			end if;

			if(read_data_bytes = '1') then
				operation <= force READ_OP;
				read_data_bytes <= force '0';

				dout <= force memory(to_integer(unsigned(v_mem_addr(MEM_ADDR_BITS-1 downto 0))))(7);
				i <= force 7;

				--dout <= force memory(to_integer(unsigned(memory_address(MEM_ADDR_BITS-1 downto 0))))(7);
				--i <= force 7;
			end if;

			if(read_data_bytes_fast = '1') then
				bit_counter_en <= force  '1';
				dummy_byte <= force '1';
				bit_counter_ld <= force  '1';
				read_data_bytes_fast <= force '0';
				i <= force 8;
			end if;

			if(page_program = '1') then
				operation <= force PGPG_OP;
				bit_counter_en <= force  '1';
				bit_counter_ld <= force  '1';
				data_byte <= force '1';
				bytes_int <= force 0;
				page_program <= force '0';
				page_address <= force memory_address(MEM_ADDR_BITS-1 downto MEM_ADDR_BITS- PAGE_ADDR_BITS);
				--page_address <= memory_address(MEM_ADDR_BITS-1 downto MEM_ADDR_BITS- PAGE_ADDR_BITS);
				
				page_address <= v_mem_addr(MEM_ADDR_BITS-1 downto MEM_ADDR_BITS- PAGE_ADDR_BITS);

				for j in 1 to PAGE_SIZE loop 
					data_latch(to_integer(unsigned(memory_address(PAGE_OFFSET_BITS-1 downto 0)))) <= force memory(to_integer(unsigned(memory_address(MEM_ADDR_BITS-1 downto 0))));
					--if(memory_address(PAGE_OFFSET_BITS-1 downto 0) = page_addr_highest) then
					if(v_mem_addr(PAGE_OFFSET_BITS-1 downto 0) = page_addr_highest) then
						--memory_address(PAGE_OFFSET_BITS-1 downto 0) <= page_addr_zero;
						v_mem_addr(PAGE_OFFSET_BITS-1 downto 0) := page_addr_zero;
					else
						--memory_address(PAGE_OFFSET_BITS-1 downto 0) <= std_ulogic_vector(unsigned(memory_address(PAGE_OFFSET_BITS-1 downto 0)) + page_addr_increase);
						v_mem_addr(PAGE_OFFSET_BITS-1 downto 0) := std_ulogic_vector(unsigned(v_mem_addr(PAGE_OFFSET_BITS-1 downto 0)) + page_addr_increase);
					end if;
				end loop;
			end if;
		end if;
		if(mode = ap_mode and dummy_byte = '1' and byte_ok = '1') then
			operation <= force HSRD_OP;
			--i <= force 8;
			byte_ok <= force '0';
			dummy_byte <= force '0';
			dout <= force memory(to_integer(unsigned(memory_address(MEM_ADDR_BITS-1 downto 0))))(7);
			i <= force 7;
		end if;

		if(mode = ap_mode and data_byte = '1' and byte_ok = '1') then
			if(operation = PGPG_OP) then
				bytes_int <= force bytes_int +1;
				bit_counter_en <= force  '1';
				byte_ok <= force '0';
				bit_counter_ld <= force  '1';
				wrda_id <= force '1';
				--data_latch(to_integer(unsigned(memory_address(PAGE_OFFSET_BITS-1 downto 0)))) <= data_latch(to_integer(unsigned(memory_address(PAGE_OFFSET_BITS-1 downto 0)))) and shift_in_reg;
				--data_latch(to_integer(unsigned(memory_address(PAGE_OFFSET_BITS-1 downto 0)))) <= force shift_in_reg;
				data_latch(to_integer(unsigned(v_mem_addr(PAGE_OFFSET_BITS-1 downto 0)))) <= force shift_in_reg;
				
				--if(memory_address(PAGE_OFFSET_BITS-1 downto 0) = std_ulogic_vector(to_unsigned((2**PAGE_OFFSET_BITS -1),PAGE_OFFSET_BITS))) then
				if(v_mem_addr(PAGE_OFFSET_BITS-1 downto 0) = std_ulogic_vector(to_unsigned((2**PAGE_OFFSET_BITS -1),PAGE_OFFSET_BITS))) then
					--memory_address(PAGE_OFFSET_BITS-1 downto 0) <= (others => '0');
					v_mem_addr(PAGE_OFFSET_BITS-1 downto 0) := (others => '0');
				else
					--memory_address <= force std_ulogic_vector(unsigned(memory_address) + 1);
					v_mem_addr := std_ulogic_vector(unsigned(v_mem_addr) + 1);
				end if;
			end if;

		end if;
		if(operation = READ_OP) then
			if(i = 0) then
				i <= force 7;
				--if(memory_address(MEM_ADDR_BITS-1 downto 0) = address_highest) then
				if(v_mem_addr(MEM_ADDR_BITS-1 downto 0) = address_highest) then
					--memory_address(MEM_ADDR_BITS-1 downto 0) <= address_zero;
					v_mem_addr(MEM_ADDR_BITS-1 downto 0) := address_zero;
				else
					--memory_address <= force std_ulogic_vector(unsigned(memory_address) + address_increase);
					v_mem_addr := std_ulogic_vector(unsigned(v_mem_addr) + address_increase);
				end if;
				dout <= force memory(to_integer(unsigned(v_mem_addr(MEM_ADDR_BITS-1 downto 0))))(7);
			else
			--data_out_buf <=force memory(to_integer(unsigned(memory_address(MEM_ADDR_BITS-1 downto 0))));
			--dout <= force data_out_buf(i-1);
				--dout <= force memory(to_integer(unsigned(memory_address(MEM_ADDR_BITS-1 downto 0))))(i-1);
				dout <= force memory(to_integer(unsigned(v_mem_addr(MEM_ADDR_BITS-1 downto 0))))(i-1);
				i <= force i-1;
			end if;
		end if;


		if(operation = HSRD_OP) then
			if(i = 0) then
				i <= force 7;
				if(v_mem_addr(MEM_ADDR_BITS-1 downto 0) = address_highest) then
				--if(memory_address(MEM_ADDR_BITS-1 downto 0) = address_highest) then
					--memory_address(MEM_ADDR_BITS-1 downto 0) <= address_zero;
					v_mem_addr(MEM_ADDR_BITS-1 downto 0) := address_zero;
				else
					--memory_address <= force std_ulogic_vector(unsigned(v_mem_addr) + address_increase);
					v_mem_addr := std_ulogic_vector(unsigned(v_mem_addr) + address_increase);
				end if;
				dout <= force memory(to_integer(unsigned(v_mem_addr(MEM_ADDR_BITS-1 downto 0))))(7);
			else
			--data_out_buf <=force memory(to_integer(unsigned(memory_address(MEM_ADDR_BITS-1 downto 0))));
			--dout <= force data_out_buf(i-1);
				--dout <= force memory(to_integer(unsigned(memory_address(MEM_ADDR_BITS-1 downto 0))))(i-1);
				dout <= force memory(to_integer(unsigned(v_mem_addr(MEM_ADDR_BITS-1 downto 0))))(i-1);
				i <= force i-1;
			end if;
		end if;

	end if;
end process; -- instruction_treatment

--cs_driven_high : process(S) is
cs_driven_high : process(i_clk) is
begin
	if(rising_edge(i_clk)) then
		--if(rising_edge(S)) then
		if(S = '1' and S_prev = '0') then
			if(status_reg(0) = '1' and operation = RDSR_OP) then
				instruction <= force "0000";
				dout <= force 'Z';
				operation <= force "0000";
			end if;
		end if;
	end if;
end process; -- cs_driven_high


--cs_goes_high_manage : process(S) is
cs_goes_high_manage : process(i_clk) is
	variable v_addr : unsigned(23 downto 0) := (others => '0');
begin
	if(rising_edge(i_clk)) then
		S_prev <= S;
		if(S = '0' and S_prev = '1') then
		--if(falling_edge(S))then	
	    	instruction_byte <= force '1';  --ready for instruction
	      	-----------------------------------------------------
	        mode <= force  ap_mode;
	        bit_counter_en <= force '1';
	        bit_counter_ld <= force  '1';    --enable the bit_counter
		--end if;
		--if(rising_edge(S)) then
		elsif(S = '1' and S_prev = '0') then
			mode <= force sb_mode;
			if(operation = WREN_OP) then
				operation <= force "0000";
				dout <= force 'Z';
				if(wren_id = '1') then
					status_reg(1) <= force '1';
					wren_id <= force '0';
				end if;
			end if;

			if(operation = WRDI_OP) then
				operation <= force "0000";
				dout <= force 'Z';
				if(wrdi_id = '1') then
					status_reg(1) <= force '0';
					wrdi_id <= force '0';
				end if;
			end if;

			if(operation = RDSR_OP) then
				operation <= force "0000";
				dout <= force 'Z';
				instruction <= force "0000";
			end if;

			if(operation = READ_OP) then
				operation <= force "0000";
				dout <= force 'Z';
			end if;

			if(operation = HSRD_OP) then
				operation <= force "0000";
				dout <= force 'Z';
			end if;

			if(operation = PGPG_OP) then
				dout <= force 'Z';
				data_byte <= force '0';
				--if(bytes < 256) then
				--	bytes <= 0;
				--end if;
				if(wrda_id = '1') then
					status_reg(1) <= force '0';
					status_reg(0) <= force '0';
					operation <= (others => '0');
					--memory_address(7 downto 0) <= x"00";
					--memory_address(PAGE_OFFSET_BITS-1 downto 0) <= (others => '0');
					--memory_address <= force (others => '0');
					v_addr := unsigned(memory_address);
					v_addr(PAGE_OFFSET_BITS-1 downto 0) := (others => '0');
					for j in 1 to PAGE_SIZE loop
						memory(to_integer(unsigned(v_addr(MEM_ADDR_BITS-1 downto 0)))) <= force data_latch(to_integer(unsigned(v_addr(PAGE_OFFSET_BITS-1 downto 0))));
						--memory(to_integer(unsigned(memory_address(MEM_ADDR_BITS-1 downto 0)))) <= force data_latch(to_integer(unsigned(memory_address(PAGE_OFFSET_BITS-1 downto 0))));
						--memory_address(PAGE_OFFSET_BITS-1 downto 0) <= std_ulogic_vector(unsigned(memory_address(PAGE_OFFSET_BITS-1 downto 0)) + 1);
						--memory_address <= force std_ulogic_vector(unsigned(memory_address) + 1);
						v_addr(PAGE_OFFSET_BITS-1 downto 0) := v_addr(PAGE_OFFSET_BITS-1 downto 0) +1;
					end loop;
					wrda_id <= force '0';
				end if;
			end if;

			if(operation = WRSR_OP) then
				if(wrsr_id = '1') then
					operation <= (others => '0');
					wrsr_id <= force '0';
				end if;
			end if;

			if(operation = SCES_OP) then
				dout <= force 'Z';
				v_addr := unsigned(memory_address);
				--sector_address <= memory_address(MEM_ADDR_BITS-1 downto MEM_ADDR_BITS- SECTOR_ADDR_BITS);
				sector_address <= std_ulogic_vector((v_addr(MEM_ADDR_BITS-1 downto MEM_ADDR_BITS- SECTOR_ADDR_BITS)));
				if(sces_id = '1') then
					status_reg(1) <= force '0';
					status_reg(0) <= force '0';
					operation <= (others => '0');
					--memory_address(3 downto 0) <= "0000";
					v_addr(SECTOR_OFFSET_BITS-1 downto 0) := (others => '0');
					for j in 1 to SECTOR_SIZE loop 
						--memory(to_integer(unsigned(memory_address(MEM_ADDR_BITS-1 downto 0)))) <= force (others => '1');
						memory(to_integer(unsigned(v_addr(MEM_ADDR_BITS-1 downto 0)))) <= force (others => '1');
						--memory_address(SECTOR_OFFSET_BITS-1 downto 0) <= std_ulogic_vector(unsigned(memory_address(SECTOR_OFFSET_BITS-1 downto 0)) + 1);
						v_addr(SECTOR_OFFSET_BITS-1 downto 0) := v_addr(SECTOR_OFFSET_BITS-1 downto 0) + 1;
					end loop;
					sces_id <= force '0';
				end if;
			end if;

			if(operation = BKES_OP) then
				dout <= force 'Z';
				v_addr := unsigned(memory_address);
				if(bkes_id = '1') then
					status_reg(1) <= force '0';
					status_reg(0) <= force '0';
					operation <= (others => '0');

					for j in 1 to MEM_SIZE loop 
						--memory(to_integer(unsigned(memory_address(MEM_ADDR_BITS-1 downto 0)))) <= force (others => '1');
						memory(to_integer(unsigned(v_addr(MEM_ADDR_BITS-1 downto 0)))) <= force (others => '1');
						--memory_address(MEM_ADDR_BITS-1 downto 0) <= std_ulogic_vector(unsigned(memory_address(MEM_ADDR_BITS-1 downto 0)) + address_increase);
						v_addr(MEM_ADDR_BITS-1 downto 0) := v_addr(MEM_ADDR_BITS-1 downto 0) + address_increase;
					end loop;
					bkes_id <= force '0';
				end if;
			end if;

		end if;
	end if;
end process; -- cs_goes_high_manage


end rtl;