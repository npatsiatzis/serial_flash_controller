import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer,RisingEdge,FallingEdge,ClockCycles,ReadWrite
from cocotb.result import TestFailure
import random
from cocotb_coverage.coverage import CoverPoint,coverage_db

covered_valued = []
g_sys_clk = int(cocotb.top.g_sys_clk)
period_ns = 10**9 / g_sys_clk

full = False
def notify():
	global full
	full = True


# at_least = value is superfluous, just shows how you can determine the amount of times that
# a bin must be hit to considered covered
@CoverPoint("top.i_data",xf = lambda x : x, bins = list(range(2**8)), at_least=1)
def number_cover(data):
	covered_valued.append(int(data))

async def reset(dut,cycles=1):
	dut.i_arstn.value = 0
	dut.i_we.value = 0
	dut.i_addr.value = 0
	dut.i_data.value = 0
	dut.i_dq.value = 0  
	await ClockCycles(dut.i_clk,cycles)
	dut.i_arstn.value = 1
	await RisingEdge(dut.i_clk)
	dut._log.info("the core was reset")


@cocotb.test()
async def test_single_r_w(dut):
	"""Check results for serial flash controller writing and reading 1 item at a time"""
	cocotb.start_soon(Clock(dut.i_clk, period_ns, units="ns").start())
	await reset(dut,5)	

	lst = []


	dut.i_we.value = 1
	dut.i_addr.value = 0 
	dut.i_data.value = 6		# cmd WR ENABLE

	await RisingEdge(dut.i_clk)

	await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer

	for i in range(50):
	
		dut.i_we.value = 1
		dut.i_addr.value = 0 
		dut.i_data.value = 2		# cmd page program

		await RisingEdge(dut.i_clk)
		await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer

		addr = random.randint(165,2**8-1)

		dut.i_we.value = 1
		dut.i_addr.value = 2 
		dut.i_data.value = 0		# addr high

		await RisingEdge(dut.i_clk)

		dut.i_we.value = 1
		dut.i_addr.value = 3 
		dut.i_data.value = 0		# addr m

		await RisingEdge(dut.i_clk)

		dut.i_we.value = 1
		dut.i_addr.value = 4 
		dut.i_data.value = addr		# addr low

		await RisingEdge(dut.i_clk)

		data = random.randint(165,2**8-1)
		lst.append(data)
		dut.i_we.value = 1
		dut.i_addr.value = 1
		dut.i_data.value = data 
		await RisingEdge(dut.i_clk)


		dut.i_we.value = 1
		dut.i_addr.value = 7
		dut.i_data.value = 255
		await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer


		dut.i_we.value = 1
		dut.i_addr.value = 0
		dut.i_data.value = 255
		await RisingEdge(dut.i_clk)
		await ClockCycles(dut.i_clk,5)



		dut.i_we.value = 1
		dut.i_addr.value = 0 
		dut.i_data.value = 3		# cmd RD data
		await RisingEdge(dut.i_clk)

		dut.i_we.value = 1
		dut.i_addr.value = 2 
		dut.i_data.value = 0		# addr high

		await RisingEdge(dut.i_clk)

		dut.i_we.value = 1
		dut.i_addr.value = 3 
		dut.i_data.value = 0		# addr m

		await RisingEdge(dut.i_clk)

		dut.i_we.value = 1
		dut.i_addr.value = 4 
		dut.i_data.value = addr		# addr low

		await RisingEdge(dut.i_clk)

		await FallingEdge(dut.o_byte_rx_done)	# wait for the data byte to start transfer
		dut.i_we.value = 0
		dut.i_addr.value = 5 
		dut.i_data.value = 0		# data to rx
		await RisingEdge(dut.i_clk)
		await FallingEdge(dut.o_dv)
		assert not (data != int(dut.o_data.value)),"Different expected to actual read data"


		dut.i_we.value = 1
		dut.i_addr.value = 0
		dut.i_data.value = 255
		await RisingEdge(dut.i_clk)
		await ClockCycles(dut.i_clk,5)




@cocotb.test()
async def test_page_r_w(dut):
	"""Check results and coverage for serial flash controller writing and reading whole pages"""

	cocotb.start_soon(Clock(dut.i_clk, period_ns, units="ns").start())
	await reset(dut,5)	

	lst = []


	dut.i_we.value = 1
	dut.i_addr.value = 0 
	dut.i_data.value = 6		# cmd WR ENABLE

	await RisingEdge(dut.i_clk)

	await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer
	
	dut.i_we.value = 1
	dut.i_addr.value = 0 
	dut.i_data.value = 2		# cmd page program

	await RisingEdge(dut.i_clk)
	await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer

	dut.i_we.value = 1
	dut.i_addr.value = 2 
	dut.i_data.value = 0		# addr high

	await RisingEdge(dut.i_clk)

	dut.i_we.value = 1
	dut.i_addr.value = 3 
	dut.i_data.value = 0		# addr m

	await RisingEdge(dut.i_clk)

	dut.i_we.value = 1
	dut.i_addr.value = 4 
	dut.i_data.value = 0		# addr low

	await RisingEdge(dut.i_clk)



	while(full != True):

		dut.i_we.value = 1
		dut.i_addr.value = 1
		data = random.randint(0,2**8-1)
		while(data in covered_valued):
			data = random.randint(0,2**8-1) 
		dut.i_data.value = data		# data to tx
		number_cover(data)
		coverage_db["top.i_data"].add_threshold_callback(notify, 100)
		lst.append(data)
		await RisingEdge(dut.i_clk)


		dut.i_we.value = 1
		dut.i_addr.value = 7
		dut.i_data.value = 255
		await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer


	dut.i_we.value = 1
	dut.i_addr.value = 0
	dut.i_data.value = 255
	await RisingEdge(dut.i_clk)
	await ClockCycles(dut.i_clk,100)



	dut.i_we.value = 1
	dut.i_addr.value = 0 
	dut.i_data.value = 3		# cmd RD data
	await RisingEdge(dut.i_clk)

	dut.i_we.value = 1
	dut.i_addr.value = 2 
	dut.i_data.value = 0		# addr high

	await RisingEdge(dut.i_clk)

	dut.i_we.value = 1
	dut.i_addr.value = 3 
	dut.i_data.value = 0		# addr m

	await RisingEdge(dut.i_clk)

	dut.i_we.value = 1
	dut.i_addr.value = 4 
	dut.i_data.value = 0		# addr low

	await RisingEdge(dut.i_clk)

	for i in range(256):
		await FallingEdge(dut.o_byte_rx_done)	# wait for the data byte to start transfer
		dut.i_we.value = 0
		dut.i_addr.value = 5 
		dut.i_data.value = 0		# data to rx
		await RisingEdge(dut.i_clk)
		await FallingEdge(dut.o_dv)
		expected_value = lst.pop(0)
		assert not (expected_value != int(dut.o_data.value)),"Different expected to actual read data"

	
	# coverage_db.report_coverage(cocotb.log.info,bins=True)
	coverage_db.export_to_xml(filename="coverage.xml")
