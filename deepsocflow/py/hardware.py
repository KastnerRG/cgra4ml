import numpy as np
import json
import os
import subprocess
import glob
from deepsocflow.py.utils import *
import deepsocflow


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
            ram_weights_depth: int = 512, 
            ram_edges_depth: int|None = 288,
            axi_width: int = 64,
            target_cpu_int_bits: int = 32,
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
        self.IN_BITS = self.OUT_BITS = axi_width
        self.INT_BITS = target_cpu_int_bits
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
        self.X_PAD                 = int(np.ceil(self.KH_MAX//2))
        self.BITS_KW2              = clog2((self.KW_MAX+1)/2)
        self.BITS_KH2              = clog2((self.KH_MAX+1)/2)
        self.BITS_CIN_MAX          = clog2(self.CI_MAX)
        self.BITS_COLS_MAX         = clog2(self.XW_MAX)
        self.BITS_BLOCKS_MAX       = clog2(self.L_MAX)
        self.BITS_XN_MAX           = clog2(self.XN_MAX)
        self.BITS_RAM_WEIGHTS_ADDR = clog2(self.RAM_WEIGHTS_DEPTH)
        self.Y_OUT_BITS            = 2**clog2(self.Y_BITS)

        self.MODULE_DIR = os.path.normpath(os.path.dirname(deepsocflow.__file__)).replace('\\', '/')
        self.TB_MODULE = "dnn_engine_tb"
        self.WAVEFORM = "dnn_engine_tb_behav.wcfg"
        self.SOURCES = glob.glob(f'{self.MODULE_DIR}/test/sv/*.sv') + glob.glob(f"{self.MODULE_DIR}/rtl/**/*.v", recursive=True) + glob.glob(f"{self.MODULE_DIR}/rtl/**/*.sv", recursive=True) + glob.glob(f"{os.getcwd()}/*.svh")
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

        with open('config_tb.svh', 'w') as f:
            f.write(f'`define VALID_PROB {self.VALID_PROB} \n`define READY_PROB {self.READY_PROB}')

        with open('sources.txt', 'w') as f:
            f.write("\n".join([os.path.normpath(s) for s in self.SOURCES]))

        with open('config_hw.svh', 'w') as f:
            f.write(f'''
// Written from Hardware.export()

`define ROWS                {self.ROWS               :<10}  // PE rows, constrained by resources
`define COLS                {self.COLS               :<10}  // PE cols, constrained by resources
`define X_BITS              {self.X_BITS             :<10}  // Bits per word in input
`define K_BITS              {self.K_BITS             :<10}  // Bits per word in input
`define Y_BITS              {self.Y_BITS             :<10}  // Bits per word in output of conv

`define KH_MAX              {self.KH_MAX             :<10}  // max of kernel height, across layers
`define KW_MAX              {self.KW_MAX             :<10}  // max of kernel width, across layers
`define XH_MAX              {self.XH_MAX             :<10}  // max of input image height, across layers
`define XW_MAX              {self.XW_MAX             :<10}  // max of input image width, across layers
`define XN_MAX              {self.XN_MAX             :<10}  // max of input batch size, across layers
`define CI_MAX              {self.CI_MAX             :<10}  // max of input channels, across layers
`define CONFIG_BEATS        {self.CONFIG_BEATS       :<10}  // constant, for now
`define RAM_WEIGHTS_DEPTH   {self.RAM_WEIGHTS_DEPTH  :<10}  // CONFIG_BEATS + max(KW * CI), across layers
`define RAM_EDGES_DEPTH     {self.RAM_EDGES_DEPTH    :<10}  // max (KW * CI * XW), across layers when KW != 1

`define DELAY_MUL           2            // constant, for now 
`define DELAY_W_RAM         2            // constant, for now 

`define S_WEIGHTS_WIDTH_LF  {self.IN_BITS            :<10}  // constant (64), for now
`define S_PIXELS_WIDTH_LF   {self.IN_BITS            :<10}  // constant (64), for now
`define M_OUTPUT_WIDTH_LF   {self.OUT_BITS           :<10}  // constant (64), for now
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
set S_WEIGHTS_WIDTH_LF {self.IN_BITS}
set S_PIXELS_WIDTH_LF  {self.IN_BITS}
set M_OUTPUT_WIDTH_LF  {self.OUT_BITS}
''')



    def simulate(self, SIM='verilator', SIM_PATH=''):

        os.makedirs('build', exist_ok=True)
        print("\n\nCOMPILING...\n\n")

        if SIM == 'xsim':
            assert subprocess.run(cwd="build", shell=True, args=fr'{SIM_PATH}xsc {self.MODULE_DIR}/c/example.c --gcc_compile_options -I../').returncode == 0
            assert subprocess.run(cwd="build", shell=True, args=fr'{SIM_PATH}xvlog -sv -f ../sources.txt -i ../').returncode == 0
            assert subprocess.run(cwd="build", shell=True, args=fr'{SIM_PATH}xelab {self.TB_MODULE} --snapshot {self.TB_MODULE} -log elaborate.log --debug typical -sv_lib dpi').returncode == 0

        if SIM == 'icarus':
            cmd = [ "iverilog", "-v", "-g2012", "-o", "build/a.out", "-I", "sv", "-s", self.TB_MODULE] + self.SOURCES
            print(" ".join(cmd))
            assert subprocess.run(cmd).returncode == 0

        if SIM == "verilator":
            cmd = f'{SIM_PATH}verilator --binary -j 0 --trace --relative-includes --top {self.TB_MODULE} -I../ -F ../sources.txt -CFLAGS -I../ {self.MODULE_DIR}/c/example.c --Mdir ./'
            print(cmd)
            assert subprocess.run(cmd.split(' '), cwd='build').returncode == 0
        

        print("\n\nSIMULATING...\n\n")

        if SIM == 'xsim':
            with open('build/xsim_cfg.tcl', 'w') as f:
                f.write('''log_wave -recursive * \nrun all \nexit''')
            assert subprocess.run(fr'{SIM_PATH}xsim {self.TB_MODULE} --tclbatch xsim_cfg.tcl', cwd="build", shell=True).returncode == 0
        if SIM == 'icarus':
            subprocess.run(["vvp", "build/a.out"])
        if SIM == 'verilator':
            subprocess.run([f"./V{self.TB_MODULE}"], cwd="build")


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