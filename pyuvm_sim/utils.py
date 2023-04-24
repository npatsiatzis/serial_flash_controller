
from cocotb.triggers import Timer,RisingEdge,FallingEdge,ClockCycles
from cocotb.clock import Clock
from cocotb.queue import QueueEmpty, Queue
import cocotb
import enum
import random
from cocotb_coverage import crv 
from cocotb_coverage.coverage import CoverCross,CoverPoint,coverage_db
from pyuvm import utility_classes



class FlashBfm(metaclass=utility_classes.Singleton):
    def __init__(self):
        self.dut = cocotb.top
        self.driver_queue = Queue(maxsize=1)
        self.data_mon_queue = Queue(maxsize=0)
        self.result_mon_queue = Queue(maxsize=0)

    async def send_data(self, data):
        await self.driver_queue.put(data)

    async def get_data(self):
        data = await self.data_mon_queue.get()
        return data

    async def get_result(self):
        result = await self.result_mon_queue.get()
        return result

    async def reset(self):
        await RisingEdge(self.dut.i_clk)
        self.dut.i_arstn.value = 0
        self.dut.i_we.value = 0
        self.dut.i_addr.value = 0
        self.dut.i_stb.value = 0
        self.dut.i_data.value = 0
        self.dut.i_dq.value = 0  
        await ClockCycles(self.dut.i_clk,5)
        self.dut.i_arstn.value = 1
        await RisingEdge(self.dut.i_clk)


    async def driver_bfm(self):

        while True:
            await RisingEdge(self.dut.i_clk)
            try:
                (i_we,i_stb,i_addr,i_data) = self.driver_queue.get_nowait()
                self.dut.i_we.value = i_we
                self.dut.i_stb.value = i_stb
                self.dut.i_addr.value = i_addr
                self.dut.i_data.value = i_data

            except QueueEmpty:
                pass

    async def data_mon_bfm(self):
        while True:
            await RisingEdge((self.dut.wb_regs.f_is_data_to_tx))
            i_data = self.dut.i_data.value 
            self.data_mon_queue.put_nowait(i_data)


    async def result_mon_bfm(self):
        while True:
            await FallingEdge(self.dut.o_dv)
            await RisingEdge(self.dut.o_ack)             
            await RisingEdge(self.dut.i_clk)
            self.result_mon_queue.put_nowait(self.dut.o_data.value)


    def start_bfm(self):
        cocotb.start_soon(self.driver_bfm())
        cocotb.start_soon(self.data_mon_bfm())
        cocotb.start_soon(self.result_mon_bfm())



class AxilFlashBfm(metaclass=utility_classes.Singleton):
    def __init__(self):
        self.dut = cocotb.top
        self.driver_queue_write = Queue(maxsize=1)
        self.driver_queue_read = Queue(maxsize=1)
        self.data_mon_queue = Queue(maxsize=0)
        self.result_mon_queue = Queue(maxsize=0)

    async def send_data_write(self, data):
        await self.driver_queue_write.put(data)

    async def send_data_read(self, data):
        await self.driver_queue_read.put(data)

    async def get_data(self):
        data = await self.data_mon_queue.get()
        return data

    async def get_result(self):
        result = await self.result_mon_queue.get()
        return result

    async def reset(self):
        # await RisingEdge(self.dut.S_AXI_ACLK)
        self.dut.S_AXI_ARESETN.value = 0
        self.dut.S_AXI_AWVALID.value = 0
        self.dut.S_AXI_AWADDR.value = 0
        self.dut.S_AXI_WVALID.value = 0
        self.dut.S_AXI_WDATA.value = 0
        self.dut.S_AXI_WSTRB.value = 15
        self.dut.S_AXI_BREADY.value = 0
        self.dut.S_AXI_ARVALID.value = 0
        self.dut.S_AXI_ARADDR.value = 0
        self.dut.S_AXI_RREADY.value = 0
        await ClockCycles(self.dut.S_AXI_ACLK,5)
        self.dut.S_AXI_ARESETN.value = 1
        await RisingEdge(self.dut.S_AXI_ACLK)


    async def driver_bfm_write(self):

        while True:
            await RisingEdge(self.dut.S_AXI_ACLK)
            try:

                (awvalid,awaddr,wvalid,wdata,bready) = self.driver_queue_write.get_nowait()
                self.dut.S_AXI_AWVALID.value = awvalid
                self.dut.S_AXI_AWADDR.value = awaddr
                self.dut.S_AXI_WVALID.value = wvalid
                self.dut.S_AXI_WDATA.value = wdata
                self.dut.S_AXI_BREADY.value = bready

                await RisingEdge(self.dut.S_AXI_ACLK)
                await RisingEdge(self.dut.S_AXI_BVALID)
                self.dut.S_AXI_AWVALID.value = 0
                self.dut.S_AXI_WVALID.value = 0
                await RisingEdge(self.dut.S_AXI_ACLK)

            except QueueEmpty:
                pass

    async def driver_bfm_read(self):

        while True:
            await RisingEdge(self.dut.S_AXI_ACLK)
            try:

                (arvalid,araddr,rready) = self.driver_queue_read.get_nowait()
                self.dut.S_AXI_ARVALID.value = arvalid
                self.dut.S_AXI_ARADDR.value = araddr
                self.dut.S_AXI_RREADY.value = rready

                await FallingEdge(self.dut.S_AXI_RVALID)
                self.dut.S_AXI_ARVALID.value = 0
                await RisingEdge(self.dut.S_AXI_ACLK)

            except QueueEmpty:
                pass


    async def data_mon_bfm(self):
        while True:
            await RisingEdge(self.dut.axil_regs.f_is_data_to_tx)
            i_data = self.dut.S_AXI_WDATA.value 
            self.data_mon_queue.put_nowait(i_data)



    async def result_mon_bfm(self):
        while True:
            await FallingEdge(self.dut.o_dv)
            await FallingEdge(self.dut.S_AXI_RVALID)             
            await RisingEdge(self.dut.S_AXI_ACLK)
            self.result_mon_queue.put_nowait(self.dut.o_data.value)


    def start_bfm(self):
        cocotb.start_soon(self.driver_bfm_write())
        cocotb.start_soon(self.driver_bfm_read())
        cocotb.start_soon(self.data_mon_bfm())
        cocotb.start_soon(self.result_mon_bfm())