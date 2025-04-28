import numpy as np
import json
import os
import subprocess
import glob
from deepsocflow.py.utils import *
import deepsocflow
import time


class Hardware:
    """
    Class to store static (pre-synthesis) parameters of the accelerator and export them to SystemVerilog and TCL scripts.
    """
    def __init__(
            self, 
            processing_elements: (int, int) = (8,24), 
            frequency_mhz: int = 250, 
            bits_input: int = 4, 
            bits_weights: int = 4, 
            bits_sum: int = 16, 
            bits_bias: int = 16, 
            max_batch_size: int = 512, 
            max_channels_in: int = 512, 
            max_kernel_size: int = 13, 
            max_image_size: int = 32, 
            max_n_bundles: int = 64,
            ram_weights_depth: int = 512, 
            ram_edges_depth: int|None = 288,
            axi_width: int = 64,
            header_width: int = 64,
            config_baseaddr = "B0000000",
            axi_max_burst_len: int = 16,
            target_cpu_int_bits: int = 32,
            async_resetn: bool = True,
            valid_prob: float = 0.01,
            ready_prob: float = 0.1,
            data_dir: str = 'vectors/'
            ):
        """
        Args:
            processing_elements (int, int, optional): _description_. Defaults to (8,24).
            frequency_mhz (int, optional): _description_. Defaults to 250.
            bits_input (int, optional): _description_. Defaults to 4.
            bits_weights (int, optional): _description_. Defaults to 4.
            bits_sum (int, optional): _description_. Defaults to 16.
            bits_bias (int, optional): _description_. Defaults to 16.
            max_batch_size (int, optional): _description_. Defaults to 512.
            max_channels_in (int, optional): _description_. Defaults to 512.
            max_kernel_size (int, optional): _description_. Defaults to 13.
            max_image_size (int, optional): _description_. Defaults to 32.
            ram_weights_depth (int, optional): _description_. Defaults to 512.
            ram_edges_depth (int | None, optional): _description_. Defaults to None.
            target_cpu_int_bits (int, optional): _description_. Defaults to 32.
        """
        
        self.params = locals()
        self.params = {k:self.params[k] for k in self.params if not k == 'self'}
        
        # Validation
        assert bits_input in [1,2,4,8] and bits_weights in [1,2,4,8]
        assert bits_bias  in [8,16,32]
        
        self.ROWS, self.COLS = processing_elements
        self.FREQ   = frequency_mhz
        self.X_BITS = bits_input
        self.K_BITS = bits_weights
        self.Y_BITS = bits_sum
        self.B_BITS = bits_bias
        self.XN_MAX = max_batch_size
        self.CI_MAX = max_channels_in
        self.KH_MAX, self.KW_MAX = tuple(max_kernel_size) if (type(max_kernel_size) in [tuple, list]) else (max_kernel_size, max_kernel_size)
        self.XH_MAX, self.XW_MAX = tuple(max_image_size ) if (type(max_image_size ) in [tuple, list]) else (max_image_size , max_image_size )
        self.MAX_N_BUNDLES = max_n_bundles
        self.AXI_WIDTH = axi_width
        self.HEADER_WIDTH = header_width
        self.CONFIG_BASEADDR = config_baseaddr
        self.AXI_MAX_BURST_LEN = axi_max_burst_len
        self.INT_BITS = target_cpu_int_bits
        self.ASYNC_RESETN = async_resetn
        self.VALID_PROB = int(valid_prob * 1000)
        self.READY_PROB = int(ready_prob * 1000)

        self.RAM_WEIGHTS_DEPTH     = ram_weights_depth
        '''
        | Width of weights RAM   = K_BITS * COLS
        | Number of weights RAMs = 2
        '''

        self.RAM_EDGES_DEPTH       = ram_edges_depth
        '''
        | Depth of RAM needed for edge padding.
        |     if k == 1 -> 0
        |     else ci*xw*(blocks-1) 
        '''

        self.L_MAX                 = int(np.ceil(self.XH_MAX//self.ROWS))
        self.CONFIG_BEATS          = 0
        self.X_PAD_MAX             = int(np.ceil(self.KH_MAX//2))
        self.BITS_KW2              = clog2((self.KW_MAX+1)/2)
        self.BITS_KH2              = clog2((self.KH_MAX+1)/2)
        self.BITS_CIN_MAX          = clog2(self.CI_MAX)
        self.BITS_COLS_MAX         = clog2(self.XW_MAX)
        self.BITS_BLOCKS_MAX       = clog2(self.L_MAX)
        self.BITS_XN_MAX           = clog2(self.XN_MAX)
        self.BITS_RAM_WEIGHTS_ADDR = clog2(self.RAM_WEIGHTS_DEPTH)
        self.Y_OUT_BITS            = 2**clog2(self.Y_BITS)
        self.W_BPT                 = 32#clog2(self.ROWS*self.COLS*self.Y_OUT_BITS/8)

        self.MODULE_DIR = os.path.normpath(os.path.dirname(deepsocflow.__file__)).replace('\\', '/')
        self.TB_MODULE = "axi_sys_tb"
        self.SOURCES = glob.glob(f'{self.MODULE_DIR}/test/sv/*.sv') + glob.glob(f'{self.MODULE_DIR}/test/sv/**/*.v') + glob.glob(f"{self.MODULE_DIR}/rtl/**/*.v", recursive=True) + glob.glob(f"{self.MODULE_DIR}/rtl/**/*.sv", recursive=True) + glob.glob(f"{os.getcwd()}/*.svh")
        self.DATA_DIR = data_dir

    def export_json(self, path='./hardware.json'):
        '''
        Exports the hardware parameters to a JSON file.
        '''
        
        with open(path, 'w') as f:
            json.dump(self.params, f, indent=4)


    @staticmethod
    def from_json(path='./hardware.json'):
        '''
        Creates the Hardware object from an exported JSON file.
        '''
        
        with open(path, 'r') as f:
            hw = Hardware(**json.load(f))
        return hw


    def export(self):
        '''
        Exports the hardware parameters to SystemVerilog and TCL scripts.
        '''
        PERIOD_NS = 1000/self.FREQ
        INPUT_DELAY_NS = PERIOD_NS/5
        OUTPUT_DELAY_NS = PERIOD_NS/5

        with open('config_tb.svh', 'w') as f:
            f.write(f'''
`define VALID_PROB {self.VALID_PROB} 
`define READY_PROB {self.READY_PROB} 
`define CLK_PERIOD {PERIOD_NS:.1f} 
`define INPUT_DELAY_NS  {INPUT_DELAY_NS :.1f}ns
`define OUTPUT_DELAY_NS {OUTPUT_DELAY_NS:.1f}ns
''')

        with open('sources.txt', 'w') as f:
            f.write("\n".join([os.path.normpath(s) for s in self.SOURCES]))

        with open('config_hw.svh', 'w') as f:
            f.write(f'''
// Written from Hardware.export()
                    
`define OR_NEGEDGE(RSTN)    {"or negedge RSTN" if self.ASYNC_RESETN else ""}

`define ROWS                {self.ROWS               :<10}  // PE rows, constrained by resources
`define COLS                {self.COLS               :<10}  // PE cols, constrained by resources
`define X_BITS              {self.X_BITS             :<10}  // Bits per word in input
`define K_BITS              {self.K_BITS             :<10}  // Bits per word in input
`define Y_BITS              {self.Y_BITS             :<10}  // Bits per word in output of conv
`define Y_OUT_BITS          {self.Y_OUT_BITS         :<10}  // Padded bits per word in output of conv

`define KH_MAX              {self.KH_MAX             :<10}  // max of kernel height, across layers
`define KW_MAX              {self.KW_MAX             :<10}  // max of kernel width, across layers
`define XH_MAX              {self.XH_MAX             :<10}  // max of input image height, across layers
`define XW_MAX              {self.XW_MAX             :<10}  // max of input image width, across layers
`define XN_MAX              {self.XN_MAX             :<10}  // max of input batch size, across layers
`define CI_MAX              {self.CI_MAX             :<10}  // max of input channels, across layers
`define MAX_N_BUNDLES       {self.MAX_N_BUNDLES      :<10}  // max number of bundles in a network
`define CONFIG_BEATS        {self.CONFIG_BEATS       :<10}  // constant, for now
`define RAM_WEIGHTS_DEPTH   {self.RAM_WEIGHTS_DEPTH  :<10}  // CONFIG_BEATS + max(KW * CI), across layers
`define RAM_EDGES_DEPTH     {self.RAM_EDGES_DEPTH    :<10}  // max (KW * CI * XW), across layers when KW != 1
`define W_BPT               {self.W_BPT              :<10}  // Width of output integer denoting bytes per transfer

`define DELAY_MUL           3            // constant, for now 
`define DELAY_W_RAM         2            // constant, for now 

`define AXI_WIDTH           {self.AXI_WIDTH          :<10}
`define HEADER_WIDTH        {self.HEADER_WIDTH       :<10}
`define AXI_MAX_BURST_LEN   {self.AXI_MAX_BURST_LEN  :<10}
`define CONFIG_BASEADDR     40'h{self.CONFIG_BASEADDR:<10}
''')


        with open('config_hw.tcl', 'w') as f:
            f.write(f'''
# Written from Hardware.export()

set FREQ               {self.FREQ}
set ROWS               {self.ROWS}
set COLS               {self.COLS}
set X_BITS             {self.X_BITS}
set K_BITS             {self.K_BITS}
set Y_BITS             {self.Y_BITS}
set DELAY_W_RAM        2
set RAM_WEIGHTS_DEPTH  {self.RAM_WEIGHTS_DEPTH}
set RAM_EDGES_DEPTH    {self.RAM_EDGES_DEPTH}
set KH_MAX             {self.KH_MAX}
set AXI_WIDTH          {self.AXI_WIDTH}
set CONFIG_BASEADDR    0x{self.CONFIG_BASEADDR}
''')



    def simulate(self, SIM='verilator', SIM_PATH=''):

        os.makedirs('build', exist_ok=True)
        print("\n\nCOMPILING...\n\n")

        if SIM == 'xsim':
            assert subprocess.run(cwd="build", shell=True, args=fr'{SIM_PATH}xsc {self.MODULE_DIR}/c/sim.c --gcc_compile_options -I../ --gcc_compile_options -DSIM').returncode == 0
            assert subprocess.run(cwd="build", shell=True, args=fr'{SIM_PATH}xvlog -sv -f ../sources.txt -i ../').returncode == 0
            assert subprocess.run(cwd="build", shell=True, args=fr'{SIM_PATH}xelab {self.TB_MODULE} --snapshot {self.TB_MODULE} -log elaborate.log --debug typical -sv_lib dpi').returncode == 0

        if SIM == 'icarus':
            cmd = [ "iverilog", "-v", "-g2012", "-o", "build/a.out", "-I", "sv", "-s", self.TB_MODULE] + self.SOURCES
            print(" ".join(cmd))
            assert subprocess.run(cmd).returncode == 0

        if SIM == "verilator":
            cmd = f'{SIM_PATH}verilator --binary -j 0 -O3 --trace --relative-includes --top {self.TB_MODULE} -I../ -F ../sources.txt -CFLAGS -DSIM -CFLAGS -I../ {self.MODULE_DIR}/c/sim.c -CFLAGS -g --Mdir ./'
            print(cmd)
            assert subprocess.run(cmd.split(' '), cwd='build').returncode == 0
        print("\n\nSIMULATING...\n\n")
        start = time.time()

        if SIM == 'xsim':
            with open('build/xsim_cfg.tcl', 'w') as f:
                f.write('''log_wave -recursive * \nrun all \nexit''')
            assert subprocess.run(fr'{SIM_PATH}xsim {self.TB_MODULE} --tclbatch xsim_cfg.tcl', cwd="build", shell=True).returncode == 0
        if SIM == 'icarus':
            subprocess.run(["vvp", "build/a.out"])
        if SIM == 'verilator':
            assert subprocess.run([f"./V{self.TB_MODULE}"], cwd="build").returncode == 0
        
        print(f"\n\nSIMULATION TIME: {time.time()-start:.2f} seconds\n\n")


    def export_vivado_tcl(self, board='zcu104', rtl_dir_abspath=None, scripts_dir_abspath=None, board_tcl_abspath=None):

        if rtl_dir_abspath is None:
            rtl_dir_abspath = self.MODULE_DIR + '/rtl'
        if scripts_dir_abspath is None:
            scripts_dir_abspath = self.MODULE_DIR + '/tcl/fpga'
        if board_tcl_abspath is None:
            board_tcl_abspath = f'{scripts_dir_abspath}/{board}.tcl'
        
        assert os.path.exists(board_tcl_abspath), f"Board script {board_tcl_abspath} does not exist."
        assert os.path.exists('./config_hw.tcl'), f"./config_hw.tcl does not exist."

        with open('vivado_flow.tcl', 'w') as f:
            f.write(f'''
set PROJECT_NAME dsf_{board}
set RTL_DIR      {rtl_dir_abspath}
set CONFIG_DIR   .

source config_hw.tcl
source {board_tcl_abspath}
source {scripts_dir_abspath}/vivado.tcl
''')