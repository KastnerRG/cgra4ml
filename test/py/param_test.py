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
from dataclasses import dataclass
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
SOURCES = glob.glob('../rtl/include/*') + glob.glob('sv/*.sv') + glob.glob("../rtl/**/*.v", recursive=True) + glob.glob("../rtl/**/*.sv", recursive=True) + ['./xsim/sim_params.svh']
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
        'BITS_RAM_WEIGHTS_ADDR' : clog2(c.RAM_WEIGHTS_DEPTH),
         }
    n = namedtuple('Compile', d)(**d)
    c = namedtuple("Compile", c._fields + n._fields)(*(c + n))
    with open('compile.pickle', 'wb') as f:
        pickle.dump(c._asdict(), f)

    print(f"\n\n---------- {SIM}:{c} ----------\n\n")
    return c


def compile(c):

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
    sim_params = [f'VALID_PROB {c.VALID_PROB}', f'READY_PROB {c.READY_PROB}', f'DIR_PATH "{DATA_DIR}/"']
    with open('xsim/sim_params.svh', 'w') as f:
        for param in sim_params:
            f.write(f'`define {param}\n')

    if SIM == 'xsim':
        SOURCES_STR = " ".join([os.path.normpath('../' + s) for s in SOURCES]) # since called from subdir
        xvlog_cmd = fr'{XIL_PATH}\xvlog -sv {SOURCES_STR}'
        xelab_cmd = fr'{XIL_PATH}\xelab {TB_MODULE} --snapshot {TB_MODULE} -log elaborate.log --debug typical -sv_lib dpi'
        xsc_cmd   = fr'{XIL_PATH}\xsc ../../c/example.c'
        assert subprocess.run(xsc_cmd, cwd="xsim", shell=True).returncode == 0
        assert subprocess.run(xvlog_cmd, cwd="xsim", shell=True).returncode == 0
        assert subprocess.run(xelab_cmd, cwd="xsim", shell=True).returncode == 0

    if SIM == 'icarus':
        cmd = [ "iverilog", "-v", "-g2012", "-o", "xsim/a.out", "-I", "sv", "-I", "../rtl/include", "-s", TB_MODULE] + SOURCES
        print(" ".join(cmd))
        assert subprocess.run(cmd).returncode == 0

    if SIM == "verilator":        
        cmd = f"verilator --binary -j 0 -Wno-fatal --relative-includes --top {TB_MODULE} " + " ".join(SOURCES) + ' -CFLAGS -DVERILATOR ../c/example.c'
        print(cmd)
        assert subprocess.run(cmd.split(' ')).returncode == 0

    return c


@dataclass
class Config:
    K : int
    CO: int
    flatten: bool = False
    dense: bool = False


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
                                                RAM_WEIGHTS_DEPTH = [16],  # KH*CI + Config beats
                                                RAM_EDGES_DEPTH   = [288 ], # max(CI * XW * (XH/ROWS-1))

                                                VALID_PROB = [100],
                                                READY_PROB = [1],
                                            )))
def test_dnn_engine(COMPILE):

    input_shape = (2,16,8,3) # (XN, XH, XW, CI)
    model_config = [
        Config(11, 16),
        Config(7, 16),
        Config(5, 16),
        Config(3, 24),
        Config(1, 50, flatten=True),
        Config(1, 10, dense= True),
    ]

    '''
    Build Model
    '''
    q = 'quantized_bits(8,0,False,True,1)'

    x = x_in = Input(input_shape[1:], name='input')
    x = QActivation(q)(x)

    for i, g in enumerate(model_config):
        if g.dense:
            d = {'core': {'type':'dense', 'units':g.CO, 'kernel_quantizer':q, 'bias_quantizer':q, 'use_bias':False, 'act_str':'quantized_relu(8,0,negative_slope=0.125)'}}
        else:
            d = {'core': {'type':'conv', 'filters':g.CO, 'kernel_size':(g.K,g.K), 'strides':(1,1), 'padding':'same', 'kernel_quantizer':q, 'bias_quantizer':q, 'use_bias':False, 'act_str':'quantized_relu(8,0,negative_slope=0.125)'}, 'flatten':g.flatten,}
        x = Bundle(**d)(x)

    model = Model(inputs=x_in, outputs=x)

    '''
    Pass Floating Point & Fixed Point Input
    '''
    x = np.clip(np.random.randn(*input_shape), -1.0, 1.0)
    y = model(x)

    inp_act_model = Model(inputs=model.input, outputs=model.layers[1].output)
    inp ={ 'tensor': inp_act_model(x, training=False), 'bits':8, 'frac':7}
    inp['int'] = inp['tensor'].numpy() * 2**inp['frac']


    for file in os.scandir(DATA_DIR):
        os.remove(file.path)
    c = make_compile_params(COMPILE)

    bundles = model.layers[2:]
    with open('sv/model.svh', 'w') as vh, open ('../c/model.h', 'w') as ch:
        vh.write(f"localparam N_BUNDLES = {len(bundles)};\n\n")
        vh.write(f"Bundle_t bundles [N_BUNDLES] = '{{\n")
        ch.write(f"const int N_BUNDLES = {len(bundles)};\n\n")
        ch.write(f"Bundle_t bundles [] = {{\n")
        
        for b in bundles:
            print(f'-----------------{b.idx}-----------------------')
            b.process(inp if b.idx==0 else None)
            b.export(c)

            '''FLATTEN & SAVE AS TEXT'''
            for i_cp in range(b.r.CP):
                np.savetxt(f"{DATA_DIR}/{b.idx}_{i_cp}_x.txt", b.xe[i_cp].flatten(), fmt='%d')
                for i_it in range(b.r.IT):
                    np.savetxt(f"{DATA_DIR}/{b.idx}_{i_cp}_{i_it}_w.txt", b.we[i_cp][i_it].flatten(), fmt='%d')
                    np.savetxt(f"{DATA_DIR}/{b.idx}_{i_cp}_{i_it}_y_exp.txt", b.ye_exp_p[i_cp][i_it].flatten(), fmt='%d')
            print(f'Weights, inputs, outputs saved to {DATA_DIR}/ib_ip_it_*.txt')

            y_wpt = b.r.CO_PRL*b.c.ROWS
            y_wpt_last = b.r.CO_PRL*b.c.ROWS*(b.r.KW//2+1)
            vh.write(f"  '{{ w_wpt:{b.we[-1].size},  w_wpt_p0:{b.we[0].size},  x_wpt:{b.xe[-1].size},  x_wpt_p0:{b.xe[0].size},  y_wpt:{y_wpt},  y_wpt_last:{y_wpt_last},  y_nl:{b.r.XN*b.r.L},  y_w:{b.r.XW-b.r.KW//2},  n_it:{b.r.IT},  n_p:{b.r.CP} }}")
            ch.write(f"   {{.w_wpt={b.we[-1].size}, .w_wpt_p0={b.we[0].size}, .x_wpt={b.xe[-1].size}, .x_wpt_p0={b.xe[0].size}, .y_wpt={y_wpt}, .y_wpt_last={y_wpt_last}, .y_nl={b.r.XN*b.r.L}, .y_w={b.r.XW-b.r.KW//2}, .n_it={b.r.IT}, .n_p={b.r.CP} }}")
            if b.idx != len(bundles)-1:
                vh.write(',\n')
                ch.write(',\n')
        vh.write(f"\n}};")
        ch.write(f"\n}};")
    '''
    RUN SIMULATION
    '''

    compile(c=c)
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


    for b in bundles:
        '''
        CHECK ERROR
        '''
        y_sim = np.zeros((b.r.IT, b.r.XN*b.r.L*b.r.XW*b.r.CO_PRL*c.ROWS))
        for i_cp in range(b.r.CP):
            for i_it in range(b.r.IT):
                y_sim[i_it] = y_sim[i_it] + np.loadtxt(f"{DATA_DIR}/{b.idx}_{i_cp}_{i_it}_y_sim.txt",np.int32)

        error = np.sum(np.abs(y_sim.reshape(b.ye_exp.shape) - b.ye_exp))

        print("Error: ", error)
        assert error == 0
        if error != 0 and SIM=='xsim':
            print(fr'''Non zero error. Open waveform with:
                        call {XIL_PATH}\xsim --gui {TB_MODULE}.wdb -view ..\wave\{WAVEFORM}''')
