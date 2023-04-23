import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer,RisingEdge,FallingEdge,ClockCycles,ReadWrite
from cocotb.result import TestFailure
import random
from cocotb_coverage.coverage import CoverPoint,coverage_db
from cocotb.binary import BinaryValue

covered_valued = []
g_sys_clk = int(cocotb.top.g_sys_clk)
period_ns = 10**9 / g_sys_clk

full = False
def notify():
	global full
	full = True


# at_least = value is superfluous, just shows how you can determine the amount of times that
# a bin must be hit to considered covered

# 2**4 is the number of bytes in a page in the sim. model. Change this number (range) accrodinlgy.
@CoverPoint("top.i_data",xf = lambda x : x, bins = list(range(2**4)), at_least=1)
def number_cover(data):
	covered_valued.append(int(data))

async def reset(dut,cycles=1):
	dut.S_AXI_ARESETN.value = 0
	dut.S_AXI_AWVALID.value = 0
	dut.S_AXI_AWADDR.value = 0
	dut.S_AXI_WVALID.value = 0
	dut.S_AXI_WDATA.value = 0
	dut.S_AXI_WSTRB.value = 15
	dut.S_AXI_BREADY.value = 0
	dut.S_AXI_ARVALID.value = 0
	dut.S_AXI_ARADDR.value = 0
	dut.S_AXI_RREADY.value = 0
	await ClockCycles(dut.S_AXI_ACLK,cycles)
	dut.S_AXI_ARESETN.value = 1
	await RisingEdge(dut.S_AXI_ACLK)
	dut._log.info("the core was reset")

async def driver_write(dut,awaddr,wdata):
	dut.S_AXI_AWVALID.value = 1
	dut.S_AXI_AWADDR.value = awaddr
	dut.S_AXI_WVALID.value = 1
	dut.S_AXI_WDATA.value = wdata          
	dut.S_AXI_BREADY.value = 1         
	await RisingEdge(dut.S_AXI_ACLK)
	await RisingEdge(dut.S_AXI_BVALID)
	dut.S_AXI_AWVALID.value = 0
	dut.S_AXI_WVALID.value = 0

async def driver_read(dut,araddr):
	dut.S_AXI_ARVALID.value = 1
	dut.S_AXI_ARADDR.value = araddr
	dut.S_AXI_RREADY.value = 1

	await FallingEdge(dut.S_AXI_RVALID)
	dut.S_AXI_ARVALID.value = 0


	# 					USER REGISTER MAP

	# 			Address 		| 		Functionality
	#			   0 			|	write flash command code
	#			   1 			|	write data to tx / keep programming data bytes
	#			   2 			|	write A23-A16
	#			   3 			|	write A15-A8
	#			   4 			|	write A7-A0
	#			   5 			|	keep reading data bytes

	
	#supported flash commands 
	#command set codes for serial embedded memory , eg any from ST M25Pxx series
	#NOP  				255		#pseudo-cmd, not actual flash cmd
	#WR_ENABLE  		6
	#WR_DISABLE  		4
	#RD_STATUS_REG  	5
	#WR_STATUS_REG  	1
	#PAGE_PROGRAM  		2
	#SECTOR_ERASE  		216
	#BULK_ERASE  		199
	#RD_DATA  			3

	#fast read corrsponds to simple read, but it requires dummy cycles (operates at higher freq.)
	#following the address bytes and can operate at a higher frequency.
	#F_RD_DATA  		11

@cocotb.test()
async def test_enable_disasble(dut):
	"""Check results for serial flash controller write enable/disable operations"""
	# write enable -> write disable -> write random data to status reg -> read status reg
	# write enable -> write random data to status reg -> read status reg
	# check that first read data is 0 (default value of status reg) and 
	# second read data is the random data you have writen to the status reg the second repetition

	# commands exercized : write enable, write disable, write status register, read status register
	cocotb.start_soon(Clock(dut.S_AXI_ACLK, period_ns, units="ns").start())
	await reset(dut,5)	

	lst = []

	await driver_write(dut,0,6)


	# dut.i_we.value = 1
	# dut.i_stb.value = 1
	# dut.i_addr.value = 0 
	# dut.i_data.value = 6		# cmd WR ENABLE

	await RisingEdge(dut.S_AXI_ACLK)
	# dut.i_stb.value = 0

	await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer

	await driver_write(dut,0,4)

	# dut.i_we.value = 1
	# dut.i_stb.value = 1
	# dut.i_addr.value = 0 
	# dut.i_data.value = 4		# cmd WR disable

	await RisingEdge(dut.S_AXI_ACLK)
	# dut.i_stb.value = 0

	await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer

	for i in range(2):
	
		await driver_write(dut,0,1)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 0 
		# dut.i_data.value = 1		# cmd write status register

		await RisingEdge(dut.S_AXI_ACLK)

		data = random.randint(100,2**8-1)
		bin_data = BinaryValue(value=data)
		while(bin_data.binstr[-1] == '1'):			#don't write a value in status reg. with WIP=1
			data = random.randint(100,2**8-1)
			bin_data = BinaryValue(value=data)

		await driver_write(dut,1,data)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 1
		# dut.i_data.value = data
		 
		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0
		await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer

		await driver_write(dut,7,255)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 7
		# dut.i_data.value = 255
		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0

		await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer
		await driver_write(dut,0,255)


		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 0
		# dut.i_data.value = 255
		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0

		await ClockCycles(dut.S_AXI_ACLK,5)

		await driver_write(dut,0,5)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 0 
		# dut.i_data.value = 5		# cmd read status register
		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0
		await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer

		await driver_write(dut,0,255)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 0 
		# dut.i_data.value = 255		# NOP command
		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0
		await FallingEdge(dut.o_dv)

		await driver_read(dut,5)

		# dut.i_we.value = 0
		# dut.i_stb.value = 1
		# dut.i_addr.value = 5 		# read rx data
		# dut.i_data.value = 0
		# await RisingEdge(dut.o_ack)	
		await RisingEdge(dut.S_AXI_ACLK)			
		lst.append(dut.o_data.value)
		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0
		await ClockCycles(dut.S_AXI_ACLK,5)

		await driver_write(dut,0,6)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 0 
		# dut.i_data.value = 6		# cmd WR ENABLE

		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0
		await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer

	assert not (0 != lst[0]),"Different expected to actual read data"
	assert not (data != lst[1]),"Different expected to actual read data"

@cocotb.test()
async def test_status_reg(dut):
	"""Check results for serial flash controller writing and reading the status register"""
	# write random data to status reg -> read status reg (5 repetitions)
	# at the end end of each repetion, check that you read back the correct data

	# commands exercized : write enable, write status register, read status register
	cocotb.start_soon(Clock(dut.S_AXI_ACLK, period_ns, units="ns").start())
	await reset(dut,5)	




	for i in range(5):
	
		await driver_write(dut,0,6)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 0 
		# dut.i_data.value = 6		# cmd WR ENABLE

		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0

		await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer
		await driver_write(dut,0,1)


		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 0 
		# dut.i_data.value = 1		# cmd write status register

		await RisingEdge(dut.S_AXI_ACLK)

		data = random.randint(100,2**8-1)
		bin_data = BinaryValue(value=data)
		while(bin_data.binstr[-1] == '1'):			#don't write a value in status reg. with WIP=1
			data = random.randint(100,2**8-1)
			bin_data = BinaryValue(value=data)

		await driver_write(dut,1,data)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 1
		# dut.i_data.value = data
		 
		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0
		await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer

		await driver_write(dut,7,255)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 7
		# dut.i_data.value = 255
		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0
		await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer

		await driver_write(dut,0,255)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 0
		# dut.i_data.value = 255
		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0
		await ClockCycles(dut.S_AXI_ACLK,5)

		await driver_write(dut,0,5)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 0 
		# dut.i_data.value = 5		# cmd read status register
		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0
		await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer
		
		await driver_write(dut,0,255)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 0 
		# dut.i_data.value = 255		# NOP command
		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0
		await FallingEdge(dut.o_dv)

		await driver_read(dut,5)

		# dut.i_we.value = 0
		# dut.i_stb.value = 1
		# dut.i_addr.value = 5 		# read rx data
		# dut.i_data.value = 0
		# await RisingEdge(dut.o_ack)	
		# await RisingEdge(dut.S_AXI_ACLK)			
		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0

		assert not (data != int(dut.o_data.value)),"Different expected to actual read data"
		await ClockCycles(dut.S_AXI_ACLK,5)




@cocotb.test()
async def test_erase(dut):
	"""Check results for serial flash controller of bulk erase command after writing and reading the flash"""
	# write enable -> write random data to random address -> read data from that random address
	# check that we have read correct data (5 repetitions)
	# sector erase (bulk erase in comments)
	# read data from the sector, check that that the read byte's value is 255 (all 1s)

	# commands exercized : write enable, page program, read, sector erase (bulk erase in comments)

	cocotb.start_soon(Clock(dut.S_AXI_ACLK, period_ns, units="ns").start())
	await reset(dut,5)	

	lst = []



	for i in range(5):
		await driver_write(dut,0,6)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 0 
		# dut.i_data.value = 6		# cmd WR ENABLE

		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0
		await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer
	
		await driver_write(dut,0,2)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 0 
		# dut.i_data.value = 2		# cmd page program

		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0
		await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer

		addr = random.randint(165,2**8-1)

		await driver_write(dut,2,0)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 2 
		# dut.i_data.value = 0		# addr high

		await RisingEdge(dut.S_AXI_ACLK)

		await driver_write(dut,3,0)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 3 
		# dut.i_data.value = 0		# addr m

		await RisingEdge(dut.S_AXI_ACLK)

		await driver_write(dut,4,addr)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 4 
		# dut.i_data.value = addr		# addr low

		await RisingEdge(dut.S_AXI_ACLK)

		data = random.randint(165,2**8-1)
		lst.append(data)

		await driver_write(dut,1,data)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 1
		# dut.i_data.value = data 
		await RisingEdge(dut.S_AXI_ACLK)

		await driver_write(dut,7,255)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 7
		# dut.i_data.value = 255
		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0
		await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer

		await driver_write(dut,0,255)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 0
		# dut.i_data.value = 255
		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0
		await ClockCycles(dut.S_AXI_ACLK,5)

		await driver_write(dut,0,3)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 0 
		# dut.i_data.value = 3		# cmd RD data
		await RisingEdge(dut.S_AXI_ACLK)

		await driver_write(dut,2,0)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 2 
		# dut.i_data.value = 0		# addr high

		await RisingEdge(dut.S_AXI_ACLK)

		await driver_write(dut,3,0)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 3 
		# dut.i_data.value = 0		# addr m

		await RisingEdge(dut.S_AXI_ACLK)

		await driver_write(dut,4,addr)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 4 
		# dut.i_data.value = addr		# addr low

		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0

		await FallingEdge(dut.o_byte_rx_done)	# wait for the data byte to start transfer
		
		await driver_write(dut,0,255)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 0 
		# dut.i_data.value = 255		# NOP command
		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0
		await FallingEdge(dut.o_dv)

		await driver_read(dut,5)

		# dut.i_we.value = 0
		# dut.i_stb.value = 1
		# dut.i_addr.value = 5 		# read rx data
		# dut.i_data.value = 0
		# await RisingEdge(dut.o_ack)				
		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0

		assert not (data != int(dut.o_data.value)),"Different expected to actual read data"

	await ClockCycles(dut.S_AXI_ACLK,5)

	
	await driver_write(dut,0,6)

	# dut.i_we.value = 1
	# dut.i_stb.value = 1
	# dut.i_addr.value = 0 
	# dut.i_data.value = 6		# cmd WR ENABLE

	await RisingEdge(dut.S_AXI_ACLK)
	# dut.i_stb.value = 0

	await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer

	# dut.i_we.value = 1
	# dut.i_stb.value = 1
	# dut.i_addr.value = 0 
	# dut.i_data.value = 199		# cmd bulk erase (no need to specify A23-A0)

	#or go for an erase of a specific sector (specify sector by A23-A0)

	await driver_write(dut,0,216)

	# dut.i_we.value = 1
	# dut.i_stb.value = 1
	# dut.i_addr.value = 0 
	# dut.i_data.value = 216		# cmd sector erase

	await RisingEdge(dut.S_AXI_ACLK)
	# dut.i_stb.value = 0
	await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer

	addr = random.randint(165,2**8-1)

	await driver_write(dut,2,0)

	# dut.i_we.value = 1
	# dut.i_stb.value = 1
	# dut.i_addr.value = 2 
	# dut.i_data.value = 0		# addr high

	await RisingEdge(dut.S_AXI_ACLK)

	await driver_write(dut,3,0)

	# dut.i_we.value = 1
	# dut.i_stb.value = 1
	# dut.i_addr.value = 3 
	# dut.i_data.value = 0		# addr m

	await RisingEdge(dut.S_AXI_ACLK)

	await driver_write(dut,4,addr)

	# dut.i_we.value = 1
	# dut.i_stb.value = 1
	# dut.i_addr.value = 4 
	# dut.i_data.value = addr		# addr low



	await RisingEdge(dut.S_AXI_ACLK)
	# dut.i_stb.value = 0

	await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer

	await driver_write(dut,0,3)

	# dut.i_we.value = 1
	# dut.i_stb.value = 1
	# dut.i_addr.value = 0 
	# dut.i_data.value = 3		# cmd RD data
	await RisingEdge(dut.S_AXI_ACLK)

	await driver_write(dut,2,0)

	# dut.i_we.value = 1
	# dut.i_stb.value = 1
	# dut.i_addr.value = 2 
	# dut.i_data.value = 0		# addr high

	await RisingEdge(dut.S_AXI_ACLK)

	await driver_write(dut,3,0)

	# dut.i_we.value = 1
	# dut.i_stb.value = 1
	# dut.i_addr.value = 3 
	# dut.i_data.value = 0		# addr m

	await RisingEdge(dut.S_AXI_ACLK)

	await driver_write(dut,4,addr)

	# dut.i_we.value = 1
	# dut.i_stb.value = 1
	# dut.i_addr.value = 4 
	# dut.i_data.value = addr		# addr low

	await RisingEdge(dut.S_AXI_ACLK)
	# dut.i_stb.value = 0

	await FallingEdge(dut.o_byte_rx_done)	# wait for the data byte to start transfer
	
	await driver_write(dut,0,255)

	# dut.i_we.value = 1
	# dut.i_stb.value = 1
	# dut.i_addr.value = 0 
	# dut.i_data.value = 255		# NOP command
	await RisingEdge(dut.S_AXI_ACLK)
	# dut.i_stb.value = 0
	await FallingEdge(dut.o_dv)

	await driver_read(dut,5)

	# dut.i_we.value = 0
	# dut.i_stb.value = 1
	# dut.i_addr.value = 5 		# read rx data
	# dut.i_data.value = 0
	# await RisingEdge(dut.o_ack)				
	await RisingEdge(dut.S_AXI_ACLK)
	# dut.i_stb.value = 0

	assert not (255 != int(dut.o_data.value)),"Different expected to actual read data"

	await ClockCycles(dut.S_AXI_ACLK,5)



@cocotb.test()
async def test_single_r_w(dut):
	"""Check results for serial flash controller writing and reading 1 item at a time"""
	# write enable -> write random data to random address -> read data from that random address
	# check that we have read correct data (50 repetitions) 
	# write and reads here are single, they do not occur in burst like fashion

	# commands exercized : write enable, page program, read
	cocotb.start_soon(Clock(dut.S_AXI_ACLK, period_ns, units="ns").start())
	await reset(dut,5)	

	lst = []


	for i in range(50):
	
		await driver_write(dut,0,6)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 0 
		# dut.i_data.value = 6		# cmd WR ENABLE

		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0

		await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer

		await driver_write(dut,0,2)
		
		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 0 
		# dut.i_data.value = 2		# cmd page program

		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0
		await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer

		addr = random.randint(165,2**8-1)

		await driver_write(dut,2,0)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 2 
		# dut.i_data.value = 0		# addr high

		await RisingEdge(dut.S_AXI_ACLK)

		await driver_write(dut,3,0)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 3 
		# dut.i_data.value = 0		# addr m

		await RisingEdge(dut.S_AXI_ACLK)

		await driver_write(dut,4,addr)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 4 
		# dut.i_data.value = addr		# addr low

		await RisingEdge(dut.S_AXI_ACLK)

		data = random.randint(165,2**8-1)
		lst.append(data)

		await driver_write(dut,1,data)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 1
		# dut.i_data.value = data 
		await RisingEdge(dut.S_AXI_ACLK)

		await driver_write(dut,7,255)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 7
		# dut.i_data.value = 255
		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0
		await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer

		await driver_write(dut,0,255)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 0
		# dut.i_data.value = 255
		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0
		await ClockCycles(dut.S_AXI_ACLK,5)

		await driver_write(dut,0,3)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 0 
		# dut.i_data.value = 3		# cmd RD data
		await RisingEdge(dut.S_AXI_ACLK)

		await driver_write(dut,2,0)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 2 
		# dut.i_data.value = 0		# addr high

		await RisingEdge(dut.S_AXI_ACLK)

		await driver_write(dut,3,0)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 3 
		# dut.i_data.value = 0		# addr m

		await RisingEdge(dut.S_AXI_ACLK)

		await driver_write(dut,4,addr)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 4 
		# dut.i_data.value = addr		# addr low

		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0

		await FallingEdge(dut.o_byte_rx_done)	# wait for the data byte to start transfer
		
		await driver_write(dut,0,255)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 0 
		# dut.i_data.value = 255		# NOP command
		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0
		await FallingEdge(dut.o_dv)

		await driver_read(dut,5)

		# dut.i_we.value = 0
		# dut.i_stb.value = 1
		# dut.i_addr.value = 5 		# read rx data
		# dut.i_data.value = 0
		# await RisingEdge(dut.o_ack)				
		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0

		assert not (data != int(dut.o_data.value)),"Different expected to actual read data"




@cocotb.test()
async def test_fast_read_single_r_w(dut):
	"""Check results for serial flash controller writing and reading (fast read) 1 item at a time"""
	# write enable -> write random data to random address -> fast read data from that random address
	# check that we have read correct data (50 repetitions) 
	# write and reads (fast) here are single, they do not occur in burst like fashion

	# commands exercized : write enable, page program, read
	cocotb.start_soon(Clock(dut.S_AXI_ACLK, period_ns, units="ns").start())
	await reset(dut,5)	

	lst = []


	for i in range(50):
	
		await driver_write(dut,0,6)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 0 
		# dut.i_data.value = 6		# cmd WR ENABLE

		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0

		await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer

		await driver_write(dut,0,2)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 0 
		# dut.i_data.value = 2		# cmd page program

		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0
		await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer

		addr = random.randint(165,2**8-1)

		await driver_write(dut,2,0)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 2 
		# dut.i_data.value = 0		# addr high

		await RisingEdge(dut.S_AXI_ACLK)

		await driver_write(dut,3,0)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 3 
		# dut.i_data.value = 0		# addr m

		await RisingEdge(dut.S_AXI_ACLK)

		await driver_write(dut,4,addr)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 4 
		# dut.i_data.value = addr		# addr low

		await RisingEdge(dut.S_AXI_ACLK)

		data = random.randint(165,2**8-1)
		lst.append(data)
		
		await driver_write(dut,1,data)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 1
		# dut.i_data.value = data 
		await RisingEdge(dut.S_AXI_ACLK)


		await driver_write(dut,7,255)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 7
		# dut.i_data.value = 255
		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0
		await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer

		await driver_write(dut,0,255)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 0
		# dut.i_data.value = 255
		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0
		await ClockCycles(dut.S_AXI_ACLK,5)

		await driver_write(dut,0,11)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 0 
		# dut.i_data.value = 11		# cmd RD data
		await RisingEdge(dut.S_AXI_ACLK)

		await driver_write(dut,2,0)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 2 
		# dut.i_data.value = 0		# addr high

		await RisingEdge(dut.S_AXI_ACLK)

		await driver_write(dut,3,0)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 3 
		# dut.i_data.value = 0		# addr m

		await RisingEdge(dut.S_AXI_ACLK)

		await driver_write(dut,4,addr)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 4 
		# dut.i_data.value = addr		# addr low

		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0

		await FallingEdge(dut.o_byte_rx_done)	# wait for the data byte to start transfer
		
		await driver_write(dut,0,255)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 0 
		# dut.i_data.value = 255		# NOP command
		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0
		await FallingEdge(dut.o_dv)

		await driver_read(dut,5)

		# dut.i_we.value = 0
		# dut.i_stb.value = 1
		# dut.i_addr.value = 5 		# read rx data
		# dut.i_data.value = 0
		# await RisingEdge(dut.o_ack)				
		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0
	
		assert not (data != int(dut.o_data.value)),"Different expected to actual read data"




@cocotb.test()
async def test_page_r_w(dut):
	"""Check results and coverage for serial flash controller writing and reading whole pages"""
	# write enable -> write random data to a page (progr. whole page) ->
	# read data from that page (read whole page)
	# check that we have read correct data  
	# write and reads here occur a page at a time

	# commands exercized : write enable, page program, read

	cocotb.start_soon(Clock(dut.S_AXI_ACLK, period_ns, units="ns").start())
	await reset(dut,5)	

	lst = []


	await driver_write(dut,0,6)

	# dut.i_we.value = 1
	# dut.i_stb.value = 1
	# dut.i_addr.value = 0 
	# dut.i_data.value = 6		# cmd WR ENABLE

	await RisingEdge(dut.S_AXI_ACLK)
	# dut.i_stb.value = 0

	await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer
	
	await driver_write(dut,0,2)	

	# dut.i_we.value = 1
	# dut.i_stb.value = 1
	# dut.i_addr.value = 0 
	# dut.i_data.value = 2		# cmd page program

	await RisingEdge(dut.S_AXI_ACLK)
	# dut.i_stb.value = 0
	await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer

	await driver_write(dut,2,0)

	# dut.i_we.value = 1
	# dut.i_stb.value = 1
	# dut.i_addr.value = 2 
	# dut.i_data.value = 0		# addr high

	await RisingEdge(dut.S_AXI_ACLK)

	await driver_write(dut,3,0)

	# dut.i_we.value = 1
	# dut.i_stb.value = 1
	# dut.i_addr.value = 3 
	# dut.i_data.value = 0		# addr m

	await RisingEdge(dut.S_AXI_ACLK)

	await driver_write(dut,4,0)

	# dut.i_we.value = 1
	# dut.i_stb.value = 1
	# dut.i_addr.value = 4 
	# dut.i_data.value = 0		# addr low

	await RisingEdge(dut.S_AXI_ACLK)



	# while(full != True):
	for i in range(16):				#number of bytes in page in sim. model

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 1
		data = random.randint(0,2**4-1)
		while(data in covered_valued):
			data = random.randint(0,2**4-1) 
		# dut.i_data.value = data		# data to tx

		await driver_write(dut,1,data)

		number_cover(data)
		coverage_db["top.i_data"].add_threshold_callback(notify, 100)
		lst.append(data)
		await RisingEdge(dut.S_AXI_ACLK)


		await driver_write(dut,7,255)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_addr.value = 7
		# dut.i_data.value = 255
		await RisingEdge(dut.S_AXI_ACLK)
		# dut.i_stb.value = 0
		await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer


	await driver_write(dut,0,255)
	# dut.i_we.value = 1
	# dut.i_stb.value = 1
	# dut.i_addr.value = 0
	# dut.i_data.value = 255
	await RisingEdge(dut.S_AXI_ACLK)
	# dut.i_stb.value = 0
	await ClockCycles(dut.S_AXI_ACLK,100)


	await driver_write(dut,0,3)

	# dut.i_we.value = 1
	# dut.i_stb.value = 1
	# dut.i_addr.value = 0 
	# dut.i_data.value = 3		# cmd RD data
	await RisingEdge(dut.S_AXI_ACLK)

	await driver_write(dut,2,0)

	# dut.i_we.value = 1
	# dut.i_stb.value = 1
	# dut.i_addr.value = 2 
	# dut.i_data.value = 0		# addr high

	await RisingEdge(dut.S_AXI_ACLK)

	await driver_write(dut,3,0)

	# dut.i_we.value = 1
	# dut.i_stb.value = 1
	# dut.i_addr.value = 3 
	# dut.i_data.value = 0		# addr m

	await RisingEdge(dut.S_AXI_ACLK)

	await driver_write(dut,4,0)

	# dut.i_we.value = 1
	# dut.i_stb.value = 1
	# dut.i_addr.value = 4 
	# dut.i_data.value = 0		# addr low

	await RisingEdge(dut.S_AXI_ACLK)
	# dut.i_stb.value = 0
	await FallingEdge(dut.o_byte_rx_done)	# wait for the data byte to start transfer

	for i in range(16):
			

		dut.S_AXI_AWVALID.value = 1
		dut.S_AXI_AWADDR.value = 5
		dut.S_AXI_WVALID.value = 1
		dut.S_AXI_WDATA.value = 0          
		dut.S_AXI_BREADY.value = 1         
		await RisingEdge(dut.S_AXI_ACLK)
		await RisingEdge(dut.S_AXI_BVALID)

		# dut.i_we.value = 1
		# dut.i_stb.value = 1
		# dut.i_we.value = 1
		# dut.i_addr.value = 5 
		# dut.i_data.value = 0		# data to rx

		await RisingEdge(dut.o_dv)
		await RisingEdge(dut.S_AXI_ACLK)
		
		await driver_read(dut,5)

		# dut.i_we.value = 0
		# dut.i_stb.value = 1
		# dut.i_addr.value = 5 		# read rx data
		# dut.i_data.value = 0
		await RisingEdge(dut.S_AXI_ACLK)
		await RisingEdge(dut.S_AXI_ACLK)	


		expected_value = lst.pop(0)
		assert not (expected_value != int(dut.o_data.value)),"Different expected to actual read data"

	
	# coverage_db.report_coverage(cocotb.log.info,bins=True)
	coverage_db.export_to_xml(filename="coverage.xml")
