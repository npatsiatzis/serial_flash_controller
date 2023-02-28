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
# @CoverPoint("top.i_data",xf = lambda x : x.i_data.value, bins = list(range(2**g_word_width)), at_least=1)
# def number_cover(dut):
# 	covered_valued.append(int(dut.i_data.value))

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
async def test(dut):
	"""Check results and coverage for serial flash controller page program command"""

	cocotb.start_soon(Clock(dut.i_clk, period_ns, units="ns").start())
	await reset(dut,5)	

	dut.i_we.value = 1
	dut.i_addr.value = 0 
	dut.i_data.value = 6		# cmd WR ENABLE

	await RisingEdge(dut.i_clk)
	
	dut.i_we.value = 1
	dut.i_addr.value = 0 
	dut.i_data.value = 2		# cmd page program

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
	dut.i_data.value = 1		# addr low

	await RisingEdge(dut.i_clk)

	dut.i_we.value = 1
	dut.i_addr.value = 1 
	dut.i_data.value = 10		# data to tx

	await RisingEdge(dut.i_clk)

	dut.i_we.value = 1
	dut.i_addr.value = 7
	dut.i_data.value = 255
	await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer

	dut.i_we.value = 1
	dut.i_addr.value = 1 
	dut.i_data.value = 20		# data to tx

	await RisingEdge(dut.i_clk)

	dut.i_we.value = 1
	dut.i_addr.value = 7
	dut.i_data.value = 255
	await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer


	dut.i_we.value = 1
	dut.i_addr.value = 1 
	dut.i_data.value = 30		# data to tx

	await RisingEdge(dut.i_clk)

	dut.i_we.value = 1
	dut.i_addr.value = 7
	dut.i_data.value = 255
	await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer

	dut.i_we.value = 1
	dut.i_addr.value = 1 
	dut.i_data.value = 40		# data to tx

	await RisingEdge(dut.i_clk)

	await FallingEdge(dut.o_byte_tx_done)	# wait for the data byte to start transfer
	dut.i_we.value = 1
	dut.i_addr.value = 0
	dut.i_data.value = 255
	await RisingEdge(dut.i_clk)
	await ClockCycles(dut.i_clk,500)



