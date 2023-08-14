import numpy as np
import os
# import torch
import tensorflow as tf
from tensorflow.keras.layers import Input
import subprocess
import glob
import os.path
import pytest
import itertools
import pickle
from collections import namedtuple
from bundle import Bundle
from qkeras import *
from tensorflow.keras.layers import Input

def pack_bits(arr):
    sum_width = 0
    packed = 0
    for val, width in arr:
        packed |= val << sum_width
        sum_width += width
    return packed

# Simulator: xsim on windows, icarus otherwise
SIM = 'xsim' if os.name=='nt' else 'verilator' #'icarus'

DATA_DIR   = 'D:/dnn-engine/test/vectors' if SIM == 'xsim' else  'vectors'
os.makedirs(DATA_DIR, exist_ok=True)
MODEL_NAME = 'test'
# SIM = sys.argv[1] if len(sys.argv) == 2 else "xsim" # icarus
SOURCES = glob.glob('../rtl/include/*') + glob.glob('sv/*') + glob.glob("../rtl/**/*.v", recursive=True) + glob.glob("../rtl/**/*.sv", recursive=True) + ['./xsim/sim_params.svh']
print(SOURCES)

TB_MODULE = "dnn_engine_tb"
WAVEFORM = "dnn_engine_tb_behav.wcfg"
XIL_PATH = os.path.join("F:", "Xilinx", "Vivado", "2022.1", "bin")


'''
Synthesis Parameters
'''

def product_dict(**kwargs):
    keys, vals = kwargs.keys(), kwargs.values()
    for instance in itertools.product(*vals):
        d = dict(zip(keys, instance))
        yield namedtuple('Compile', d)(**d)


def make_compile_params(c):

    assert c.ROWS >= c.KW_MAX//2 # to capture the bottom pixels

    def clog2(x):
        return int(np.ceil(np.log2(x)))
    
    d = { 
        'KH_MAX'                : c.KW_MAX, 
        'L_MAX'                 : int(np.ceil(c.XH_MAX//c.ROWS)),
    }
    n = namedtuple('Compile', d)(**d)
    c = namedtuple("Compile", c._fields + n._fields)(*(c + n))

    d = { 
        'CONFIG_BEATS'          : 1,
        'X_PAD'                 : int(np.ceil(c.KH_MAX//2)),
        'BITS_KW2'              : clog2((c.KW_MAX+1)/2),
        'BITS_KH2'              : clog2((c.KH_MAX+1)/2),
        'BITS_CIN_MAX'          : clog2(c.CI_MAX),
        'BITS_COLS_MAX'         : clog2(c.XW_MAX),
        'BITS_BLOCKS_MAX'       : clog2(c.L_MAX),
        'BITS_XN_MAX'           : clog2(c.XN_MAX),
        'BITS_BRAM_WEIGHTS_ADDR': clog2(c.RAM_WEIGHTS_DEPTH),
         }
    n = namedtuple('Compile', d)(**d)
    c = namedtuple("Compile", c._fields + n._fields)(*(c + n))
    with open('compile.pickle', 'wb') as f:
        pickle.dump(c._asdict(), f)

    print(f"\n\n---------- {SIM}:{c} ----------\n\n")
    return c


def compile(c, num_t):

    with open('../rtl/include/params_input.svh', 'w') as f:
        f.write(f'''
    // Written from param_tests.py

    `define ROWS                {c.ROWS}                 \t// PE rows, constrained by resources
    `define COLS                {c.COLS}                 \t// PE cols, constrained by resources
    `define X_BITS              {c.X_BITS}               \t// Bits per word in input
    `define K_BITS              {c.K_BITS}               \t// Bits per word in input
    `define Y_BITS              {c.Y_BITS}               \t// Bits per word in output of conv

    `define KH_MAX              {c.KH_MAX}               \t// max of kernel height, across layers
    `define KW_MAX              {c.KW_MAX}               \t// max of kernel width, across layers
    `define XH_MAX              {c.XH_MAX}               \t// max of input image height, across layers
    `define XW_MAX              {c.XW_MAX}               \t// max of input image width, across layers
    `define XN_MAX              {c.XN_MAX}               \t// max of input batch size, across layers
    `define CI_MAX              {c.CI_MAX}               \t// max of input channels, across layers
    `define CONFIG_BEATS        {c.CONFIG_BEATS}         \t// constant, for now
    `define RAM_WEIGHTS_DEPTH   {c.RAM_WEIGHTS_DEPTH}    \t// CONFIG_BEATS + max(KW * CI), across layers
    `define RAM_EDGES_DEPTH     {c.RAM_EDGES_DEPTH}      \t// max (KW * CI * XW), across layers when KW != 1

    `define DELAY_ACC    1                               \t// constant, for now
    `define DELAY_MUL    2                               \t// constant, for now 
    `define DELAY_W_RAM  2                               \t// constant, for now 

    `define S_WEIGHTS_WIDTH_LF  {c.IN_BITS}              \t// constant (64), for now
    `define S_PIXELS_WIDTH_LF   {c.IN_BITS}              \t// constant (64), for now
    `define M_OUTPUT_WIDTH_LF   {c.OUT_BITS}             \t// constant (64), for now
    ''')
        
    with open('../fpga/scripts/vivado_config.tcl', 'w') as f:
        f.write(f'''
    # Written from param_tests.py
    set RAM_WEIGHTS_DEPTH {c.RAM_WEIGHTS_DEPTH}
    set COLS               {c.COLS}
    set X_BITS             {c.X_BITS}
    set K_BITS             {c.K_BITS}
    set DELAY_W_RAM        2
    set RAM_EDGES_DEPTH    {c.RAM_EDGES_DEPTH}
    set KH_MAX             {c.KH_MAX}
    set S_WEIGHTS_WIDTH_LF  {c.IN_BITS}
    set S_PIXELS_WIDTH_LF   {c.IN_BITS}
    set M_OUTPUT_WIDTH_LF   {c.OUT_BITS}
        ''')

    os.makedirs('xsim', exist_ok=True)
    sim_params = [f'VALID_PROB {c.VALID_PROB}', f'READY_PROB {c.READY_PROB}', f'NUM_IT {num_t}', f'DIR_PATH "{DATA_DIR}/"']
    
    with open('xsim/sim_params.svh', 'w') as f:
        for param in sim_params:
            f.write(f'`define {param}\n')

    if SIM == 'xsim':
        SOURCES_STR = " ".join([os.path.normpath('../' + s) for s in SOURCES]) # since called from subdir
        xvlog_cmd = fr'{XIL_PATH}\xvlog -sv {SOURCES_STR}'
        xelab_cmd = fr'{XIL_PATH}\xelab {TB_MODULE} --snapshot {TB_MODULE} -log elaborate.log --debug typical'
        assert subprocess.run(xvlog_cmd, cwd="xsim", shell=True).returncode == 0
        assert subprocess.run(xelab_cmd, cwd="xsim", shell=True).returncode == 0

    if SIM == 'icarus':
        cmd = [ "iverilog", "-v", "-g2012", "-o", "xsim/a.out", "-I", "sv", "-I", "../rtl/include", "-s", TB_MODULE] + SOURCES
        print(" ".join(cmd))
        assert subprocess.run(cmd).returncode == 0

    if SIM == "verilator":        
        cmd = f"verilator --binary -j 0 -Wno-fatal --relative-includes --top {TB_MODULE} " + " ".join(SOURCES)
        print(cmd)
        assert subprocess.run(cmd.split(' ')).returncode == 0

    return c


@pytest.mark.parametrize("KH", [1,3,5,7,11])
@pytest.mark.parametrize("CI", [8])
@pytest.mark.parametrize("CO", [24])
@pytest.mark.parametrize("XH", [16])
@pytest.mark.parametrize("XW", [8])
@pytest.mark.parametrize("XN", [2])
@pytest.mark.parametrize("COMPILE", list(product_dict(
                                                X_BITS     = [8    ], 
                                                K_BITS     = [8    ], 
                                                Y_BITS     = [32   ], 
                                                ROWS       = [8    ], 
                                                COLS       = [24   ], 
                                                KW_MAX     = [11   ], 
                                                CI_MAX     = [2048 ], 
                                                XW_MAX     = [32   ], 
                                                XH_MAX     = [32   ], 
                                                XN_MAX     = [16   ], 
                                                IN_BITS    = [64   ], 
                                                OUT_BITS   = [64   ],
                                                RAM_WEIGHTS_DEPTH = [2049],  # KH*CI + Config beats
                                                RAM_EDGES_DEPTH   = [288 ], # max(CI * XW * (XH/ROWS-1))

                                                VALID_PROB = [100],
                                                READY_PROB = [1],
                                            )))
def test_dnn_engine(KH, CI, CO, XH, XW, XN, COMPILE):
    c = make_compile_params(COMPILE)

    KW = KH
    assert KH <= c.KH_MAX
    assert KW <= c.KW_MAX
    assert CI <= c.CI_MAX
    assert XH <= c.XH_MAX
    assert XW <= c.XW_MAX
    assert XN <= c.XN_MAX
    assert CI * XW * int(np.ceil(XH/c.ROWS)-1) <= c.RAM_EDGES_DEPTH or KH == 1
    assert XW >= KH//2

    for file in os.scandir(DATA_DIR):
        os.remove(file.path)

    y_it_all = []

    '''
    Build Model
    '''
    q = 'quantized_bits(8,0,False,True,1)'

    x = x_in = Input((XH,XW,CI), name='input')
    x = QActivation(q)(x)
    x = Bundle(
        core= {'type':'conv', 'filters':CO, 'kernel_size':(KH,KW), 'strides':(1,1), 'padding':'same', 'kernel_quantizer':q, 'bias_quantizer':q, 'use_bias':False, 'act_str':'quantized_relu(8,0,negative_slope=0.125)'},
    )(x)
    model = Model(inputs=x_in, outputs=x)


    '''
    Pass Floating Point & Fixed Point Input
    '''
    x = np.random.randn(XN, *model.input.shape[1:])
    x = np.clip(x, -1.0, 1.0)
    y = model(x)

    inp_act_model = Model(inputs=model.input, outputs=model.layers[1].output)
    inp ={ 'tensor': inp_act_model(x, training=False), 'bits':8, 'frac':7}
    inp['int'] = inp['tensor'].numpy() * 2**inp['frac']

    model.layers[2].process(inp)

    bundles = model.layers[2:]
    for bundle in bundles:
        print(f'-----------------{bundle.idx}-----------------------')
        bundle.export(c)

        '''
        FLATTEN & SAVE AS TEXT
        '''
        for i_it in range(bundle.num_t):
            idx = i_it

            path = f"{DATA_DIR}/{idx}_w.txt"
            np.savetxt(path, bundle.we[i_it].flatten(), fmt='%d')
            print(f'Weights saved as {path}')

            path = f"{DATA_DIR}/{idx}_x.txt"
            np.savetxt(path, bundle.xe.flatten(), fmt='%d')
            print(f'input saved as "{path}"')

            y_it = bundle.ye_exp[i_it]
            y_it_all += [y_it]
            path = f"{DATA_DIR}/{idx}_y_exp.txt"
            np.savetxt(path, y_it.flatten(), fmt='%d')
            print(f'output saved as "{path}"')

        compile(c, bundle.num_t)

        '''
        RUN SIMULATION
        '''

        os.makedirs('xsim', exist_ok=True)
        print("SIMULATING...")

        if SIM == 'xsim':
            with open('xsim/xsim_cfg.tcl', 'w') as f:
                f.write('''log_wave -recursive * \nrun all \nexit''')
            assert subprocess.run(fr'{XIL_PATH}\xsim {TB_MODULE} --tclbatch xsim_cfg.tcl', cwd="xsim", shell=True).returncode == 0

        if SIM == 'icarus':
            subprocess.run(["vvp", "xsim/a.out"])
        
        if SIM == 'verilator':
            subprocess.run([f"./obj_dir/V{TB_MODULE}"])


        '''
        CHECK ERROR
        '''
        for i_it in range(bundle.num_t):

            idx = i_it
            y_it = y_it_all[i_it]
            y_sim = np.loadtxt(f"{DATA_DIR}/{idx}_y_sim.txt",np.int32)
            error = np.sum(np.abs(y_sim.reshape(y_it.shape) - y_it))

            print("Error: ", error)
            assert error == 0
            if error != 0 and SIM=='xsim':
                print(fr'''Non zero error. Open waveform with:
                            call {XIL_PATH}\xsim --gui {TB_MODULE}.wdb -view ..\wave\{WAVEFORM}''')
