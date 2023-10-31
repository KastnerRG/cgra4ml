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
keras.utils.set_random_seed(0)


# Simulator: xsim on windows, verilator otherwise
SIM = 'xsim' if os.name=='nt' else 'verilator' #'icarus'
XIL_PATH = os.path.join("F:", "Xilinx", "Vivado", "2022.1", "bin")

DATA_DIR   = 'D:/dnn-engine/test/vectors' if SIM == 'xsim' else  'vectors'
os.makedirs(DATA_DIR, exist_ok=True)

TB_MODULE = "dnn_engine_tb"
WAVEFORM = "dnn_engine_tb_behav.wcfg"
SOURCES = glob.glob('../rtl/include/*') + glob.glob('sv/*.sv') + glob.glob("../rtl/**/*.v", recursive=True) + glob.glob("../rtl/**/*.sv", recursive=True) + ['./xsim/sim_params.svh']
print(SOURCES)

type_d = {
    'np': {8: np.int8, 16: np.int16, 32: np.int32, 64: np.int64},
    'c' : {8: 'signed char', 16: 'signed short', 32: 'signed int', 64: 'signed long long'}
}

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
        'CONFIG_BEATS'          : 0,
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
    set ROWS               {c.ROWS}
    set COLS               {c.COLS}
    set X_BITS             {c.X_BITS}
    set K_BITS             {c.K_BITS}
    set Y_BITS             {c.Y_BITS}
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
        cmd = f"verilator --binary -j 0 -Wno-fatal --trace --relative-includes --top {TB_MODULE} " + " ".join(SOURCES) + ' -CFLAGS -DVERILATOR ../c/example.c'
        print(cmd)
        assert subprocess.run(cmd.split(' ')).returncode == 0

    return c


@dataclass
class Config:
    K : int
    CO: int
    is_bias: bool
    act_q: str
    strides: (int,int) = (1,1)
    pool_d: dict = None
    flatten: bool = False
    dense: bool = False


@pytest.mark.parametrize("COMPILE", list(product_dict(
                                                X_BITS     = [8    ], 
                                                K_BITS     = [4    ], 
                                                B_BITS     = [16   ], 
                                                Y_BITS     = [24   ], 
                                                INT_BITS   = [32   ], # size of integer in target CPU
                                                ROWS       = [8    ], 
                                                COLS       = [24   ], 
                                                KW_MAX     = [11   ], 
                                                CI_MAX     = [2048 ], 
                                                XW_MAX     = [32   ], 
                                                XH_MAX     = [32   ], 
                                                XN_MAX     = [16   ], 
                                                IN_BITS    = [64   ], 
                                                OUT_BITS   = [64   ],
                                                RAM_WEIGHTS_DEPTH = [20  ],  # KH*CI + Config beats
                                                RAM_EDGES_DEPTH   = [288 ], # max(CI * XW * (XH/ROWS-1))

                                                VALID_PROB = [1000],
                                                READY_PROB = [1000],
                                            )))
def test_dnn_engine(COMPILE):
    c = make_compile_params(COMPILE)

    input_shape = (1,18,18,3) # (XN, XH, XW, CI)
    model_config = [
        Config(11, 1, True , f'quantized_relu({c.X_BITS},0,negative_slope=0)', pool_d={'type':'max', 'size':(3,4), 'strides':(2,3), 'padding':'same', 'act_str':f'quantized_bits({c.X_BITS},0,False,False,1)'}),
        Config(1 , 8, False, f'quantized_bits({c.X_BITS},0,False,False,1)'),
        # Config(7 , 8, True , f'quantized_bits({c.X_BITS},0,False,True,1)'),
        # Config(5 , 8, False, f'quantized_relu({c.X_BITS},0,negative_slope=0.125)'),
        # Config(3 , 24, True , f'quantized_relu({c.X_BITS},0,negative_slope=0)'),
        # Config(1 , 5 , False, f'quantized_relu({c.X_BITS},0,negative_slope=0.125)', flatten=True),
        # Config(1 , 10, True , f'quantized_relu({c.X_BITS},0,negative_slope=0.125)', dense= True),
    ]

    '''
    Build Model
    '''
    assert c.X_BITS in [1,2,4,8] and c.K_BITS in [1,2,4,8], "X_BITS and K_BITS should be in [1,2,4,8]"
    assert c.B_BITS in [8,16,32], "B_BITS should be in [8,16,32]"
    xq, kq, bq = f'quantized_bits({c.X_BITS},0,False,True,1)', f'quantized_bits({c.K_BITS},0,False,True,1)', f'quantized_bits({c.B_BITS},0,False,True,1)'
    inp = {'bits':c.X_BITS, 'frac':c.X_BITS-1}

    x = x_in = Input(input_shape[1:], name='input')
    x = QActivation(xq)(x)
    for i, g in enumerate(model_config):
        if g.dense:
            d = {'core': {'type':'dense', 'units':g.CO, 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':g.is_bias, 'act_str':g.act_q}}
        else:
            d = {
                'core': {'type':'conv', 'filters':g.CO, 'kernel_size':(g.K,g.K), 'strides':g.strides, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':g.is_bias, 'act_str':g.act_q},
                'pool': g.pool_d, 'flatten':g.flatten,
                }
        x = Bundle(**d)(x)

    model = Model(inputs=x_in, outputs=x)


    '''
    Pass Floating Point & Fixed Point Input
    '''
    x = np.clip(np.random.randn(*input_shape), -1.0, 1.0)
    y = model(x)

    inp_act_model = Model(inputs=model.input, outputs=model.layers[1].output)
    inp['tensor'] = inp_act_model(x, training=False)
    inp['int'] = inp['tensor'].numpy() * 2**inp['frac']


    for file in os.scandir(DATA_DIR):
        os.remove(file.path)

    bundles = model.layers[2:]


    '''
    Export
    '''
    for ib, b in enumerate(bundles):
        print(f'-----------------{b.idx}-----------------------')
        b.process(inp if b.idx==0 else None, c)
        b.export(c, False) #ib==len(bundles)-1
        


    '''
    Write Runtime Headers
    '''
    x_bytes_all, x_bytes, w_bytes, b_words, x_bytes_max, y_bytes_max, o_bytes_max = 0, 0, 0, 0, 0, 0, 0
    with open ('../c/model.h', 'w') as ch:

        ch.write(f"#define N_BUNDLES {len(bundles)}\n")
        ch.write(f"Bundle_t bundles [N_BUNDLES] = {{\n")
        
        for ib, b in enumerate(bundles):
            w_bpt    = (c.K_BITS*b.we[-1][0].size + c.IN_BITS)//8
            w_bpt_p0 = (c.K_BITS*b.we[0][0].size + c.IN_BITS )//8
            x_bpt    = (c.X_BITS*b.xe[-1].size + c.IN_BITS   )//8 
            x_bpt_p0 = (c.X_BITS*b.xe[0].size + c.IN_BITS    )//8
            
            if ib == len(bundles)-1:
                o_bytes_b = b.o_int.size # int or float
                o_words = o_bytes_b
            else:
                b_next    = bundles[ib+1]
                o_bpt     = b_next.xe[-1].size #(c.X_BITS*b_next.xe[-1].size + c.IN_BITS   )//8 
                o_bpt_p0  = b_next.xe[0].size  #(c.X_BITS*b_next.xe[0].size + c.IN_BITS    )//8
                o_bytes_b = o_bpt_p0 + (b_next.r.CP-1)*o_bpt

            w_bytes_b = (w_bpt_p0 + (b.r.CP-1)*w_bpt)*b.r.IT
            x_bytes_b = (x_bpt_p0 + (b.r.CP-1)*x_bpt)
            y_bytes_b = (32*b.ye_exp.size + c.IN_BITS)//8

            x_bytes_max = max(x_bytes_max, x_bytes_b)
            y_bytes_max = max(y_bytes_max, y_bytes_b)
            o_bytes_max = max(o_bytes_max, o_bytes_b)
            w_bytes += w_bytes_b
            x_bytes_all += x_bytes_b

            if ib == 0:
                x_bytes = (x_bpt_p0 + (b.r.CP-1)*x_bpt)

            y_coe = b.r.CO_PRL
            y_coe_tl = b.r.CO_PRL if (b.r.CO==b.r.IT*b.r.CO_PRL) else b.r.CO%b.r.IT
            y_r_ll = c.ROWS if b.r.XH==b.r.XL*c.ROWS else  b.r.XH % c.ROWS

            ca_nzero, ca_shift, ca_pl_scale = b.core['act']['non_zero'], b.core['act']['shift_bits'], b.core['act']['plog_slope']

            if b.pool is None:
                pool_type = 'POOL_NONE'
            elif b.pool['type'] == 'max':
                pool_type = 'POOL_MAX'
            elif b.pool['type'] == 'avg':
                pool_type = 'POOL_AVG'

            ch.write(f"   {{.n={b.r.XN}, .l={b.r.XL}, .kw={b.r.KW}, .coe={y_coe}, .coe_tl={y_coe_tl}, .r_ll={y_r_ll}, .h={b.r.XH}, .w={b.r.XW}, .ci={b.r.CI}, .co={b.r.CO}, .w_kw2={b.r.XW-b.r.KW//2}, .t={b.r.IT}, .p={b.r.CP}, .cm={b.r.CM}, .cm_p0={b.r.CM_0}, ")
            ch.write(     f".w_bpt={w_bpt}, .w_bpt_p0={w_bpt_p0}, .x_bpt={x_bpt}, .x_bpt_p0={x_bpt_p0}, .o_bytes={o_bytes_b}, ")
            ch.write(     f".is_bias={1*(b.b is not None)}, .is_flatten={1*b.flatten}, ")
            ch.write(     f".b_offset={b_words}, .b_val_shift={b.bias_val_shift}, .b_bias_shift={b.bias_b_shift}, ")
            ch.write(     f".ca_nzero={ca_nzero}, .ca_shift={ca_shift}, .ca_pl_scale={ca_pl_scale}, ")
            ch.write(     f".csh={b.r.CSH}, .ch={b.r.CYH}, .csh_shift={b.r.CSH_SHIFT}, .pkh={b.r.PKH}, .psh={b.r.PSH}, .ph={b.r.PYH}, .psh_shift={b.r.PSH_SHIFT}, .csw={b.r.CSW}, .cw={b.r.CYW}, .csw_shift={b.r.CSW_SHIFT}, .pkw={b.r.PKW}, .psw={b.r.PSW}, .pw={b.r.PYW}, .psw_shift={b.r.PSW_SHIFT}, .p_type={pool_type}, .on={b.r.ON}, .oh={b.r.OH}, .ow={b.r.OW}, .oc={b.r.OC}, ")
            ch.write(     f".x_header={b.r.x_header_be_p[-1][0]}, .x_header_p0={b.r.x_header_be_p[0][0]}, .w_header={b.r.w_header_be_p[-1][0]}, .w_header_p0={b.r.x_header_be_p[0][0]} , ")
            ch.write(     f".debug_nhwc_words={b.oe_exp_nhwc.size} }}")
            
            b_words += b.be.size if b.b else 0
            if b.idx != len(bundles)-1:
                ch.write(',\n')
        
        ch.write(f"\n}};\n\n")
        ch.write(f"#define X_BITS_L2   {int(np.log2(c.X_BITS))}\n")
        ch.write(f"#define W_BITS_L2   {int(np.log2(c.K_BITS))}\n")
        ch.write(f"#define X_PAD       {c.X_PAD}\n")
        ch.write(f"#define KH_MAX      {c.KH_MAX}\n")
        ch.write(f"#define PE_ROWS     {c.ROWS}\n")
        ch.write(f"#define PE_COLS     {c.COLS}\n\n")

        ch.write(f"#define WB_BYTES    {w_bytes + (b_words*c.B_BITS)//8}\n")
        ch.write(f"#define W_BYTES     {w_bytes}\n")
        ch.write(f"#define X_BYTES     {x_bytes}\n")
        ch.write(f"#define O_WORDS     {o_words}\n")
        ch.write(f"#define O_BYTES_MAX {o_bytes_max}\n")
        ch.write(f"#define X_BYTES_ALL {x_bytes_all}\n")
        ch.write(f"#define Y_BYTES     {y_bytes_max}\n")
        ch.write(f"#define B_TYPE      {type_d['c'][c.B_BITS]}\n")
        ch.write(f"#define B_WORDS     {b_words}\n")
        ch.write(f'#define DATA_DIR   "{DATA_DIR}"\n\n')

    '''
    Write Binary Files
    '''
    w_bitstring = b''
    x_bitstring = b''
    b_bitstring = b''
    for ib, b in enumerate(bundles):
        if b.b:
            b_bitstring += b.be.astype(type_d['np'][c.B_BITS]).tobytes()
        for ip in range(b.r.CP):
            xe = Bundle.pack_words_into_bytes(arr=b.xe[ip].flatten(), bits=c.X_BITS)
            x_bitstring += b.r.x_header_be_p[ip!=0].tobytes() + xe.tobytes()
                
            for it in range(b.r.IT):
                we = Bundle.pack_words_into_bytes(arr=b.we[ip][it].flatten(), bits=c.K_BITS)
                w_bitstring += b.r.w_header_be_p[ip!=0].tobytes() + we.tobytes()
        if ib==0:
            with open(f"{DATA_DIR}/x.bin", 'wb') as f: 
                f.write(x_bitstring)

    with open(f"{DATA_DIR}/w.bin", 'wb') as f: 
        f.write(w_bitstring + b_bitstring)

    with open(f"{DATA_DIR}/x_all.bin", 'wb') as f: 
        f.write(x_bitstring)


    '''
    Write Text files of vectors
    '''
    for b in bundles:
        np.savetxt(f"{DATA_DIR}/{b.idx}_y_nhwc_exp.txt", b.oe_exp_nhwc.flatten(), fmt='%d')
        np.savetxt(f"{DATA_DIR}/{b.idx}_xe.txt", np.concatenate([a.flatten() for a in b.xe]), fmt='%d')
        for ip in range(b.r.CP):
            CM_p = b.r.CM_0 if ip==0 else b.r.CM
            x_config = b.r.x_header_le_p[ip!=0][0]
            x_config = format(x_config, f'#0{c.IN_BITS}b')
            x_config_words = [int(x_config[i:i+c.X_BITS], 2) for i in range(0, len(x_config), c.X_BITS)]
            x_config_words.reverse()
            x_config_words = np.array(x_config_words, dtype=np.int8)

            xp = b.xe[ip].flatten()
            xp = np.concatenate([x_config_words, xp], axis=0)
            assert xp.shape == (c.IN_BITS/c.X_BITS +b.r.XN*b.r.XL*b.r.XW*CM_p*(c.ROWS+c.X_PAD),)
            np.savetxt(f"{DATA_DIR}/{b.idx}_{ip}_x.txt", xp, fmt='%d')


            for it in range(b.r.IT):
                
                w_config = b.r.w_header_le_p[ip!=0][0]
                w_config = format(w_config, f'#0{c.IN_BITS}b')
                w_config_words = [int(w_config[i:i+c.K_BITS], 2) for i in range(0, len(w_config), c.K_BITS)]
                w_config_words.reverse()
                w_config_words = np.array(w_config_words,dtype=np.int8)

                wp = b.we[ip][it].flatten()            
                wp = np.concatenate([w_config_words, wp], axis=0)
                assert wp.shape == (c.IN_BITS/c.K_BITS + (CM_p*b.r.KH+c.CONFIG_BEATS)*c.COLS,)
                np.savetxt(f"{DATA_DIR}/{b.idx}_{ip}_{it}_w.txt", wp, fmt='%d')

                np.savetxt(f"{DATA_DIR}/{b.idx}_{ip}_{it}_y_exp.txt", b.ye_exp_p[ip][it].flatten(), fmt='%d')
    print(f'Weights, inputs, outputs saved to {DATA_DIR}/ib_ip_it_*.txt')


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


    '''
    CHECK ERROR
    '''
    for ib, b in enumerate(bundles):
        
        ''' Verify raw output '''
        for ip in range(b.r.CP):
            for it in range(b.r.IT):
                y_raw_exp = b.ye_exp_p[ip][it]
                y_raw_sim = np.loadtxt(f"{DATA_DIR}/{b.idx}_{ip}_{it}_y_raw_sim.txt", np.int32).reshape(y_raw_exp.shape)
                error = np.sum(np.abs(y_raw_exp-y_raw_sim))
                assert error == 0, f"Error={error}, for y_raw_sim at {b.idx=}_{ip=}_{it=}"

        ''' Verify sum output '''
        y_sum_exp = b.oe_sum_exp
        y_sum_sim = np.loadtxt(f"{DATA_DIR}/{b.idx}_y_sum_sim.txt", np.int32).reshape(y_sum_exp.shape)
        error = np.sum(np.abs(y_sum_exp-y_sum_sim))
        assert error == 0, f"Error={error}, for y_sum_sim at {b.idx=}"

        ''' Verify processed output HWC'''
        y_nhwc_sim = np.loadtxt(f"{DATA_DIR}/{b.idx}_y_nhwc_sim.txt",np.int32).reshape(b.oe_exp_nhwc.shape)
        error = np.sum(np.abs(y_nhwc_sim - b.oe_exp_nhwc))
        assert error == 0, f"sim:\n{y_nhwc_sim[0,:,:,0]}\n exp:\n{b.oe_exp_nhwc[0,:,:,0]}\n input:\n{b.before_pool[0,:,:,0]}"

        ''' Verify tiled output'''
        y_tiled_exp = b.o_int if ib == len(bundles)-1 else np.concatenate([a.flatten() for a in bundles[ib+1].xe])
        y_tiled_sim = np.loadtxt(f"{DATA_DIR}/{b.idx}_y_tiled_sim.txt", np.int32).reshape(y_tiled_exp.shape)
        error = np.sum(np.abs(y_tiled_sim-y_tiled_exp))
        assert error == 0, f"Error={error}, for y_tiled_sim at {b.idx=}"
            
        print(f"Bundle {b.idx}, Error: {error}")