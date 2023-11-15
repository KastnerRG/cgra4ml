# from deepsocflow import Hardware, Bundle, QInput, BundleModel, QConvCore, QDenseCore, QAdd, QPool, Softmax, QLeakyReLu
import numpy as np
from abc import ABC, abstractmethod
import json
from deepsocflow.utils import *


class Hardware:
    """_summary_
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
            max_channels_out: int = 512, 
            max_kernel_size: int = 13, 
            max_image_size: int = 32, 
            weights_cache_kbytes: int =384, 
            edge_cache_kbytes: int|None = None
            ):
        
        self.params = locals()
        self.params = {k:self.params[k] for k in self.params if not k == 'self'}
        
        '''
        Validation
        '''
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
        self.CO_MAX = max_channels_out
        self.KH_MAX, self.KW_MAX = max_kernel_size if (type(max_kernel_size) == tuple) else (max_kernel_size, max_kernel_size)
        self.XH_MAX, self.XW_MAX = max_image_size if (type(max_image_size) == tuple) else (max_image_size, max_image_size)

        '''
        Width of weights RAM   = K_BITS * COLS
        Number of weights RAMs = 2
        '''
        self.RAM_WEIGHTS_DEPTH     = int((weights_cache_kbytes*1024)/(self.K_BITS*self.COLS*2))

        '''
        Depth of RAM needed for edge padding = k != 1 ? ci*xw*(blocks-1) : 0
        '''
        self.RAM_EDGES_DEPTH       = edge_cache_kbytes if edge_cache_kbytes is not None else int(self.CI_MAX * self.XW_MAX * np.ceil(self.XH_MAX/self.ROWS)-1)

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

        self.IN_BITS = self.OUT_BITS = 64


    def export_json(self, path='./hardware.json'):
        with open(path, 'w') as f:
            json.dump(self.params, f, indent=4)


    @staticmethod
    def from_json(path='./hardware.json'):
        with open(path, 'r') as f:
            hw = Hardware(**json.load(f))
        return hw


    def export(self):

        with open('rtl/include/config_hw.svh', 'w') as f:
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

`define DELAY_ACC           1            // constant, for now
`define DELAY_MUL           2            // constant, for now 
`define DELAY_W_RAM         2            // constant, for now 

`define S_WEIGHTS_WIDTH_LF  {self.IN_BITS            :<10}  // constant (64), for now
`define S_PIXELS_WIDTH_LF   {self.IN_BITS            :<10}  // constant (64), for now
`define M_OUTPUT_WIDTH_LF   {self.OUT_BITS           :<10}  // constant (64), for now
''')


        with open('fpga/scripts/config_hw.tcl', 'w') as f:
            f.write(f'''
# Written from Hardware.export()
                    
set RAM_WEIGHTS_DEPTH  {self.RAM_WEIGHTS_DEPTH}
set ROWS               {self.ROWS}
set COLS               {self.COLS}
set X_BITS             {self.X_BITS}
set K_BITS             {self.K_BITS}
set Y_BITS             {self.Y_BITS}
set DELAY_W_RAM        2
set RAM_EDGES_DEPTH    {self.RAM_EDGES_DEPTH}
set KH_MAX             {self.KH_MAX}
set S_WEIGHTS_WIDTH_LF {self.IN_BITS}
set S_PIXELS_WIDTH_LF  {self.IN_BITS}
set M_OUTPUT_WIDTH_LF  {self.OUT_BITS}
''')


def example_function():
    print("Hello World!")