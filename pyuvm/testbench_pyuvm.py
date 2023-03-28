from cocotb.triggers import FallingEdge,RisingEdge,ClockCycles
from cocotb_coverage import crv
from cocotb.clock import Clock
from pyuvm import *
import random
import cocotb
import pyuvm
from utils import FlashBfm
from cocotb_coverage.coverage import CoverPoint,coverage_db

# g_sys_clk = int(cocotb.top.g_sys_clk)
# period_ns = 10**8 / g_sys_clk
# g_data_width = int(cocotb.top.g_data_width)
covered_values = []
covered_values_seq = []


full = False
def notify():
    global full
    full = True

# at_least = value is superfluous, just shows how you can determine the amount of times that
# a bin must be hit to considered covered
# even if g_data_with is >8, do not exercize full range as it is extremelly comp. heavy
@CoverPoint("top.i_tx_data",xf = lambda x : x, bins = list(range(2**8)), at_least=1)
def number_cover(x):
    pass


class crv_inputs(crv.Randomized):
    def __init__(self,tx_addr,tx_data):
        crv.Randomized.__init__(self)
        self.tx_addr = tx_addr
        self.tx_data = tx_data
        self.add_rand("tx_addr",list(range(2**8)))
        self.add_rand("tx_data",list(range(2**8)))

# Sequence classes
class SeqItem(uvm_sequence_item):

    def __init__(self, name,i_addr,i_tx_data):
        super().__init__(name)
        self.i_crv = crv_inputs(i_addr,i_tx_data)

    def randomize_operands(self):
        self.i_crv.randomize()

    def randomize(self):
        self.randomize_operands()


class RandomSeq(uvm_sequence):
    # def __init__(self, name):
    #     super().__init__(name)
        
    async def body(self):
        while(len(covered_values) != 2**8):
            data_tr = SeqItem("data_tr", None,None)
            await self.start_item(data_tr)
            data_tr.randomize_operands()
            while(data_tr.i_crv.tx_data in covered_values):
                data_tr.randomize_operands()
            covered_values.append(data_tr.i_crv.tx_data)
            await self.finish_item(data_tr)

class RandomSeq_sequential(uvm_sequence):
    # def __init__(self, name):
    #     super().__init__(name)
        
    async def body(self):
        while(len(covered_values_seq) != 2**8):
            data_tr = SeqItem("data_tr", None,None)
            await self.start_item(data_tr)
            data_tr.randomize_operands()
            while(data_tr.i_crv.tx_data in covered_values_seq):
                data_tr.randomize_operands()
            covered_values_seq.append(data_tr.i_crv.tx_data)
            await self.finish_item(data_tr)

class TestAllSeq(uvm_sequence):

    async def body(self):
        seqr = ConfigDB().get(None, "", "SEQR")
        random = RandomSeq("random")
        await random.start(seqr)

class TestAllSeqConsecutive(uvm_sequence):

    async def body(self):
        seqr = ConfigDB().get(None, "", "SEQR")
        random = RandomSeq_sequential("random")
        await random.start(seqr)

class Driver(uvm_driver):
    def build_phase(self):
        self.ap = uvm_analysis_port("ap", self)

    def start_of_simulation_phase(self):
        self.bfm = FlashBfm()

    async def launch_tb(self):
        await self.bfm.reset()
        self.bfm.start_bfm()

    async def run_phase(self):
        await self.launch_tb()
        while True:
            await self.bfm.send_data((1,0,6))
            await RisingEdge(self.bfm.dut.i_clk)
            await FallingEdge(self.bfm.dut.o_byte_tx_done)
      
            await self.bfm.send_data((1,0,2))
            await RisingEdge(self.bfm.dut.i_clk)
            await FallingEdge(self.bfm.dut.o_byte_tx_done)  

            await self.bfm.send_data((1,2,0))
            await RisingEdge(self.bfm.dut.i_clk)  

            await self.bfm.send_data((1,3,0))
            await RisingEdge(self.bfm.dut.i_clk) 

            data = await self.seq_item_port.get_next_item()
            await self.bfm.send_data((1,4,data.i_crv.tx_addr))
            await RisingEdge(self.bfm.dut.i_clk) 

            await self.bfm.send_data((1,1,data.i_crv.tx_data))
            await RisingEdge(self.bfm.dut.i_clk)       

            await self.bfm.send_data((1,7,255))
            await FallingEdge(self.bfm.dut.o_byte_tx_done)     

            await self.bfm.send_data((1,0,255))
            await RisingEdge(self.bfm.dut.i_clk)
            await ClockCycles(self.bfm.dut.i_clk,5)
            
            await self.bfm.send_data((1,0,3))
            await RisingEdge(self.bfm.dut.i_clk)  

            await self.bfm.send_data((1,2,0))
            await RisingEdge(self.bfm.dut.i_clk)  

            await self.bfm.send_data((1,3,0))
            await RisingEdge(self.bfm.dut.i_clk)  

            await self.bfm.send_data((1,4,data.i_crv.tx_addr))
            await RisingEdge(self.bfm.dut.i_clk)  
            await FallingEdge(self.bfm.dut.o_byte_rx_done)

            await self.bfm.send_data((1,0,255))
            await RisingEdge(self.bfm.dut.i_clk)  

            result = await self.bfm.get_result()
            self.ap.write(result)
            data.result = result
            self.seq_item_port.item_done()


class Driver_Consecutive(uvm_driver):
    def build_phase(self):
        self.ap = uvm_analysis_port("ap", self)
        self.lst = []

    def start_of_simulation_phase(self):
        self.bfm = FlashBfm()

    async def launch_tb(self):
        await self.bfm.reset()
        self.bfm.start_bfm()

    async def run_phase(self):
        await self.launch_tb()
        # while True:
        for i in range(512):
            data = await self.seq_item_port.get_next_item()
            self.lst.append(data.i_crv.tx_addr)
            await self.bfm.send_data((0,0,data.i_crv.tx_addr,data.i_crv.tx_data))
            await RisingEdge(self.bfm.dut.o_wr_burst_done)
            self.seq_item_port.item_done()       #You must call item_done() before calling get_next_item again


        self.bfm.dut.i_ads_n.value = 1
        await ClockCycles(self.bfm.dut.i_clk,20)

        for i in range(512):
            addr = self.lst.pop(0)
            await self.bfm.send_data((1,0,addr,0))
            await RisingEdge(self.bfm.dut.o_rd_burst_done)
            result = await self.bfm.get_result()
            self.ap.write(result)
            data.result = result
            # self.bfm.dut.i_ads_n.value = 1
            # await RisingEdge(self.bfm.dut.i_clk)


            # await RisingEdge(self.bfm.dut.o_tx_ready)
            # await self.bfm.send_data((0,0))
            # result = await self.bfm.get_result()
            # self.ap.write(result)
            # data.result = result
            # self.seq_item_port.item_done()

class Coverage(uvm_subscriber):

    def end_of_elaboration_phase(self):
        self.cvg = set()

    def write(self, data):
        # (i_wr,i_rd,i_tx_data) = data
        number_cover(data)
        if(int(data) not in self.cvg):
            self.cvg.add(int(data))

    def report_phase(self):
        try:
            disable_errors = ConfigDB().get(
                self, "", "DISABLE_COVERAGE_ERRORS")
        except UVMConfigItemNotFound:
            disable_errors = False
        if not disable_errors:
            # if len(set(covered_values) - self.cvg) > 0:
            if len(self.cvg) != 2**8:
                self.logger.error(
                    f"Functional coverage error. Missed: {set(covered_values)-self.cvg}")   
                assert False
            else:
                self.logger.info("Covered all input space")
                assert True


class Scoreboard(uvm_component):

    def build_phase(self):
        self.data_fifo = uvm_tlm_analysis_fifo("data_fifo", self)
        self.result_fifo = uvm_tlm_analysis_fifo("result_fifo", self)
        self.data_get_port = uvm_get_port("data_get_port", self)
        self.result_get_port = uvm_get_port("result_get_port", self)
        self.data_export = self.data_fifo.analysis_export
        self.result_export = self.result_fifo.analysis_export

    def connect_phase(self):
        self.data_get_port.connect(self.data_fifo.get_export)
        self.result_get_port.connect(self.result_fifo.get_export)

    def check_phase(self):
        passed = True
        try:
            self.errors = ConfigDB().get(self, "", "CREATE_ERRORS")
        except UVMConfigItemNotFound:
            self.errors = False
        while self.result_get_port.can_get():
            _, actual_result = self.result_get_port.try_get()
            data_success, data = self.data_get_port.try_get()
            if not data_success:
                self.logger.critical(f"result {actual_result} had no command")
            else:
                # (i_wr,i_rd,i_tx_data) = data
                if int(data) == int(actual_result):
                    self.logger.info("PASSED")
                    print("i_tx_data is {}, rx_data is {}".format(int(data),int(actual_result)))
                else:
                    self.logger.error("FAILED")
                    print("i_tx_data is {}, rx_data is {}".format(int(data),int(actual_result)))
                    passed = False
        assert passed


class Monitor(uvm_component):
    def __init__(self, name, parent, method_name):
        super().__init__(name, parent)
        self.method_name = method_name

    def build_phase(self):
        self.ap = uvm_analysis_port("ap", self)
        self.bfm = FlashBfm()
        self.get_method = getattr(self.bfm, self.method_name)

    async def run_phase(self):
        while True:
            datum = await self.get_method()
            self.logger.debug(f"MONITORED {datum}")
            self.ap.write(datum)


class Env(uvm_env):

    def build_phase(self):
        self.seqr = uvm_sequencer("seqr", self)
        ConfigDB().set(None, "*", "SEQR", self.seqr)
        self.driver = Driver.create("driver", self)
        self.data_mon = Monitor("data_mon", self, "get_data")
        self.coverage = Coverage("coverage", self)
        self.scoreboard = Scoreboard("scoreboard", self)

    def connect_phase(self):
        self.driver.seq_item_port.connect(self.seqr.seq_item_export)
        self.data_mon.ap.connect(self.scoreboard.data_export)
        self.data_mon.ap.connect(self.coverage.analysis_export)
        self.driver.ap.connect(self.scoreboard.result_export)


class Env_Consecutive(uvm_env):

    def build_phase(self):
        self.seqr = uvm_sequencer("seqr", self)
        ConfigDB().set(None, "*", "SEQR", self.seqr)
        self.driver = Driver_Consecutive.create("driver", self)
        self.data_mon = Monitor("data_mon", self, "get_data")
        self.coverage = Coverage("coverage", self)
        self.scoreboard = Scoreboard("scoreboard", self)

    def connect_phase(self):
        self.driver.seq_item_port.connect(self.seqr.seq_item_export)
        self.data_mon.ap.connect(self.scoreboard.data_export)
        self.data_mon.ap.connect(self.coverage.analysis_export)
        self.driver.ap.connect(self.scoreboard.result_export)

@pyuvm.test()
class Test(uvm_test):
    """Test UART rx-tx loopback with random values"""

    def build_phase(self):
        self.env = Env("env", self)
        self.bfm = FlashBfm()

    def end_of_elaboration_phase(self):
        self.test_all = TestAllSeq.create("test_all")

    async def run_phase(self):
        self.raise_objection()
        cocotb.start_soon(Clock(self.bfm.dut.i_clk, 10, units="ns").start())
        await self.test_all.start()

        coverage_db.report_coverage(cocotb.log.info,bins=True)
        coverage_db.export_to_xml(filename="coverage.xml")
        self.drop_objection()


# @pyuvm.test()
# class Test_Consecutive(uvm_test):
#     """Test UART rx-tx loopback with random values"""

#     def build_phase(self):
#         self.env = Env_Consecutive("env_consecutive", self)
#         self.bfm = FlashBfm()

#     def end_of_elaboration_phase(self):
#         self.test_all = TestAllSeqConsecutive.create("test_all")

#     async def run_phase(self):
#         self.raise_objection()
#         cocotb.start_soon(Clock(self.bfm.dut.i_clk, 10, units="ns").start())
#         await self.test_all.start()

#         coverage_db.report_coverage(cocotb.log.info,bins=True)
#         coverage_db.export_to_xml(filename="coverage_consecutive.xml")
#         self.drop_objection()