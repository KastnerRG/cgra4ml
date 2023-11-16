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
from copy import deepcopy
from collections import namedtuple
from dataclasses import dataclass
import deepsocflow
from deepsocflow import Bundle
from qkeras import *
from tensorflow.keras.layers import Input
keras.utils.set_random_seed(0)

# Simulator: xsim on windows, verilator otherwise
SIM = 'xsim' if os.name=='nt' else 'verilator' #'icarus'
XIL_PATH = os.path.join("F:", "Xilinx", "Vivado", "2022.1", "bin")

DATA_DIR   = 'vectors'
os.makedirs(DATA_DIR, exist_ok=True)
DATA_DIR_SIM = f'../{DATA_DIR}'
MODULE_DIR = deepsocflow.__file__.replace('\\', '/').replace("/__init__.py", "")

TB_MODULE = "dnn_engine_tb"
WAVEFORM = "dnn_engine_tb_behav.wcfg"

type_d = {
    'np': {8: np.int8, 16: np.int16, 32: np.int32, 64: np.int64}
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

    print(f"\n\n---------- {SIM}:{c} ----------\n\n")
    return c


def compile(c):

    with open(f'./config_hw.svh', 'w') as f:
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
        
    with open(f'./config_hw.tcl', 'w') as f:
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

    os.makedirs('build', exist_ok=True)
    with open('./config_tb.svh', 'w') as f:
        f.write(f'`define VALID_PROB {c.VALID_PROB} \n`define READY_PROB {c.READY_PROB}')


    SOURCES = glob.glob(f'{MODULE_DIR}/test/sv/*.sv') + glob.glob(f"{MODULE_DIR}/rtl/**/*.v", recursive=True) + glob.glob(f"{MODULE_DIR}/rtl/**/*.sv", recursive=True) + glob.glob(f"{os.getcwd()}/*.svh")
    print(SOURCES)
    with open('sources.txt', 'w') as f:
        f.write("\n".join([os.path.normpath(s) for s in SOURCES]))

    if SIM == 'xsim':
        assert subprocess.run(cwd="build", shell=True, args=fr'{XIL_PATH}\xsc {MODULE_DIR}/c/example.c --gcc_compile_options -I../').returncode == 0
        assert subprocess.run(cwd="build", shell=True, args=fr'{XIL_PATH}\xvlog -sv -f ../sources.txt -i ../').returncode == 0
        assert subprocess.run(cwd="build", shell=True, args=fr'{XIL_PATH}\xelab {TB_MODULE} --snapshot {TB_MODULE} -log elaborate.log --debug typical -sv_lib dpi').returncode == 0

    if SIM == 'icarus':
        cmd = [ "iverilog", "-v", "-g2012", "-o", "build/a.out", "-I", "sv", "-s", TB_MODULE] + SOURCES
        print(" ".join(cmd))
        assert subprocess.run(cmd).returncode == 0

    if SIM == "verilator":
        cmd = f'verilator --binary -j 0 -Wno-fatal --trace --relative-includes --top {TB_MODULE} -I../ -F ../sources.txt -CFLAGS -DVERILATOR -CFLAGS -I../ {MODULE_DIR}/c/example.c --Mdir ./'
        print(cmd)
        assert subprocess.run(cmd.split(' '), cwd='build').returncode == 0

    return c


@pytest.mark.parametrize("COMPILE", list(product_dict(
                                                X_BITS     = [4    ], 
                                                K_BITS     = [4    ], 
                                                B_BITS     = [16   ], 
                                                Y_BITS     = [24   ], 
                                                INT_BITS   = [32   ], # size of integer in target CPU
                                                ROWS       = [8    ], 
                                                COLS       = [24   ], 
                                                KW_MAX     = [13   ], 
                                                CI_MAX     = [2048 ], 
                                                XW_MAX     = [512  ], 
                                                XH_MAX     = [512  ], 
                                                XN_MAX     = [64   ], 
                                                IN_BITS    = [64   ], 
                                                OUT_BITS   = [64   ],
                                                RAM_WEIGHTS_DEPTH = [20  ],  # KH*CI + Config beats
                                                RAM_EDGES_DEPTH   = [288 ], # max(CI * XW * (XH/ROWS-1))

                                                VALID_PROB = [1],
                                                READY_PROB = [100],
                                            )))
def test_dnn_engine(COMPILE):
    c = make_compile_params(COMPILE)
    assert c.X_BITS in [1,2,4,8] and c.K_BITS in [1,2,4,8], "X_BITS and K_BITS should be in [1,2,4,8]"
    assert c.B_BITS in [8,16,32], "B_BITS should be in [8,16,32]"
    xq, kq, bq = f'quantized_bits({c.X_BITS},0,False,True,1)', f'quantized_bits({c.K_BITS},0,False,True,1)', f'quantized_bits({c.B_BITS},0,False,True,1)'
    inp        = {'bits':c.X_BITS, 'frac':c.X_BITS-1}

    '''
    Build Model
    '''
    input_shape = (8,18,18,3) # (XN, XH, XW, CI)
    x = x_in = Input(input_shape[1:], name='input')
    x = QActivation(xq)(x)

    x = x_skip1 = Bundle( core= {'type':'conv' , 'filters':8 , 'kernel_size':(11,11), 'strides':(2,1), 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':f'quantized_relu({c.X_BITS},0,negative_slope=0)'    }, pool= {'type':'avg', 'size':(3,4), 'strides':(2,3), 'padding':'same', 'act_str':f'quantized_bits({c.X_BITS},0,False,False,1)'})(x)
    x = x_skip2 = Bundle( core= {'type':'conv' , 'filters':8 , 'kernel_size':( 1, 1), 'strides':(1,1), 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':f'quantized_bits({c.X_BITS},0,False,False,1)'       }, add = {'act_str':f'quantized_bits({c.X_BITS},0,False,True,1)'})(x, x_skip1)
    x =           Bundle( core= {'type':'conv' , 'filters':8 , 'kernel_size':( 7, 7), 'strides':(1,1), 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':False, 'act_str':f'quantized_bits({c.X_BITS},0,False,True,1)'        }, add = {'act_str':f'quantized_bits({c.X_BITS},0,False,True,1)'})(x, x_skip2)
    x =           Bundle( core= {'type':'conv' , 'filters':8 , 'kernel_size':( 5, 5), 'strides':(1,1), 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':f'quantized_relu({c.X_BITS},0,negative_slope=0.125)'}, add = {'act_str':f'quantized_bits({c.X_BITS},0,False,True,1)'})(x, x_skip1)
    x =           Bundle( core= {'type':'conv' , 'filters':24, 'kernel_size':( 3, 3), 'strides':(1,1), 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':f'quantized_relu({c.X_BITS},0,negative_slope=0)'    },)(x)
    x =           Bundle( core= {'type':'conv' , 'filters':10, 'kernel_size':( 1, 1), 'strides':(1,1), 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':f'quantized_relu({c.X_BITS},0,negative_slope=0.125)'}, flatten= True)(x)
    x =           Bundle( core= {'type':'dense', 'units'  :10,                                                           'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':f'quantized_relu({c.X_BITS},0,negative_slope=0.125)'})(x)

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
    buffer_map = []
    for ib, b in enumerate(bundles):
        print(f'-----------------{b.idx}-----------------------')
        b.process(inp if b.idx==0 else None, c)
        b.export(c, False) #ib==len(bundles)-1
        
        '''
        Buffer allocation for add bundle
        '''
        print(f'input_map:{buffer_map}')

        '''Find and assign a free buffer. If not, add new buffer'''
        b.add_out_buffer_idx = -1
        if len(b.add_tensor_dest) != 0:
            for im in range(len(buffer_map)):
                if buffer_map[im] is None:
                    buffer_map[im] = {'in':ib, 'out':b.add_tensor_dest}
                    b.add_out_buffer_idx = im
                    break
            else: #m if break is not hit
                b.add_out_buffer_idx = len(buffer_map)
                buffer_map += [{'in':ib, 'out':b.add_tensor_dest}]
        
        print('add_out_buffer_idx:', b.add_out_buffer_idx)

        '''Free the buffers whose last destination is current bundle'''
        for im in range(len(buffer_map)):
            buf = buffer_map[im]
            if buf is not None:
                if buf['out'][-1] == ib:
                    buffer_map[im] = None

        print(f'output_map:{buffer_map}')


    '''
    Write Runtime Headers
    '''
    x_bytes_all = x_bytes = w_bytes = b_words = x_bytes_max = nhwc_words_max = o_bytes_max = o_words_max = 0
    out_buffer_idx = 1
    with open (f'./config_fw.h', 'w') as ch:

        ch.write(f"#define N_BUNDLES {len(bundles)}\n")
        ch.write(f"Bundle_t bundles [N_BUNDLES] = {{\n")
        
        for ib, b in enumerate(bundles):
            w_bpt    = (c.K_BITS*b.we[-1][0].size + c.IN_BITS)//8
            w_bpt_p0 = (c.K_BITS*b.we[0][0].size + c.IN_BITS )//8
            x_bpt    = (c.X_BITS*b.xe[-1].size + c.IN_BITS   )//8 
            x_bpt_p0 = (c.X_BITS*b.xe[0].size + c.IN_BITS    )//8
            
            if ib == len(bundles)-1:
                o_words_b = b.o_int.size
                o_bytes_b = o_words_b*4 # int or float
                o_words = o_words_b
            else:
                b_next    = bundles[ib+1]
                o_wpt     = b_next.xe[-1].size
                o_wpt_p0  = b_next.xe[0].size
                o_words_b = o_wpt_p0 + (b_next.r.CP-1)*o_wpt

                o_bpt = (c.X_BITS*b_next.xe[-1].size + c.IN_BITS)//8
                o_bpt_p0 = (c.X_BITS*b_next.xe[0].size + c.IN_BITS)//8
                o_bytes_b = o_bpt_p0 + (b_next.r.CP-1)*o_bpt

            xp_words  = b.r.XN * b.r.XL * b.r.XW * (c.ROWS+c.X_PAD)

            w_bytes_b = (w_bpt_p0 + (b.r.CP-1)*w_bpt)*b.r.IT
            x_bytes_b = (x_bpt_p0 + (b.r.CP-1)*x_bpt)
            nhwc_words_b = b.r.XN * b.r.XH * b.r.XW * b.r.CO

            x_bytes_max = max(x_bytes_max, x_bytes_b)
            nhwc_words_max = max(nhwc_words_max, nhwc_words_b)
            o_bytes_max = max(o_bytes_max, o_bytes_b)
            o_words_max = max(o_words_max, o_words_b)
            w_bytes += w_bytes_b
            x_bytes_all += x_bytes_b

            if ib == 0:
                x_bytes = (x_bpt_p0 + (b.r.CP-1)*x_bpt)

            y_coe = b.r.CO_PRL
            y_coe_tl = b.r.CO_PRL if (b.r.CO==b.r.IT*b.r.CO_PRL) else b.r.CO%b.r.IT
            y_r_ll = c.ROWS if b.r.XH==b.r.XL*c.ROWS else  b.r.XH % c.ROWS

            ca_nzero, ca_shift, ca_pl_scale = b.core['act']['non_zero'], b.core['act']['shift_bits'], b.core['act']['plog_slope']

            add_act_shift = b.add['act']['shift_bits'] if b.add is not None else 0
            add_out_buffer_idx = b.add_out_buffer_idx
            add_in_buffer_idx = b.add['bundle'].add_out_buffer_idx if b.add is not None else -1

            if b.pool is None:
                pool_type = 'POOL_NONE'
            elif b.pool['type'] == 'max':
                pool_type = 'POOL_MAX'
            elif b.pool['type'] == 'avg':
                pool_type = 'POOL_AVG'
            pool_act_shift = b.pool['act']['shift_bits'] if b.pool is not None else 0

            out_buffer_idx = 1*(not out_buffer_idx) if ib != len(bundles)-1 else -1 # alternate between 0 and 1

            ch.write(f"   {{.n={b.r.XN:<3}, .l={b.r.XL:<3}, .kw={b.r.KW:<3}, .coe={y_coe:<3}, .coe_tl={y_coe_tl:<3}, .r_ll={y_r_ll:<3}, .h={b.r.XH:<3}, .w={b.r.XW:<3}, .ci={b.r.CI:<4}, .co={b.r.CO:<3}, .w_kw2={b.r.XW-b.r.KW//2:<3}, .t={b.r.IT:<3}, .p={b.r.CP:<3}, .cm={b.r.CM:<3}, .cm_p0={b.r.CM_0:<3}, .xp_words={xp_words:<3}, ")
            ch.write(     f".w_bpt={w_bpt:<5}, .w_bpt_p0={w_bpt_p0:<5}, .x_bpt={x_bpt:<5}, .x_bpt_p0={x_bpt_p0:<5}, .o_words={o_words_b:<5}, .o_bytes={o_bytes_b:<5}, ")
            ch.write(     f".out_buffer_idx={out_buffer_idx:<2}, .add_out_buffer_idx={add_out_buffer_idx:<2}, .add_in_buffer_idx={add_in_buffer_idx:<2}, ")
            ch.write(     f".is_bias={1*(b.b is not None):<3}, .is_flatten={1*b.flatten:<3}, ")
            ch.write(     f".b_offset={b_words:<3}, .b_val_shift={b.bias_val_shift:<3}, .b_bias_shift={b.bias_b_shift:<3}, ")
            ch.write(     f".ca_nzero={ca_nzero:<3}, .ca_shift={ca_shift:<3}, .ca_pl_scale={ca_pl_scale:<3}, .add_act_shift={add_act_shift:<3}, .pool_act_shift={pool_act_shift:<3}, ")
            ch.write(     f".csh={b.r.CSH:<3}, .ch={b.r.CYH:<3}, .csh_shift={b.r.CSH_SHIFT:<3}, .pkh={b.r.PKH:<3}, .psh={b.r.PSH:<3}, .ph={b.r.PYH:<3}, .psh_shift={b.r.PSH_SHIFT:<3}, .csw={b.r.CSW:<3}, .cw={b.r.CYW:<3}, .csw_shift={b.r.CSW_SHIFT:<3}, .pkw={b.r.PKW:<3}, .psw={b.r.PSW:<3}, .pw={b.r.PYW:<3}, .psw_shift={b.r.PSW_SHIFT:<3}, .pool={pool_type:<10}, .on={b.r.ON:<3}, .oh={b.r.OH:<3}, .ow={b.r.OW:<3}, .oc={b.r.OC:<3}, ")
            ch.write(     f".x_header={b.r.x_header_le_p[-1][0]:>23}u, .x_header_p0={b.r.x_header_le_p[0][0]:>23}u, .w_header={b.r.w_header_le_p[-1][0]:>23}u, .w_header_p0={b.r.x_header_le_p[0][0]:>25}u , ")
            ch.write(     f".debug_nhwc_words={b.oe_exp_nhwc.size:<5} }}")
            
            b_words += b.be.size if b.b else 0
            if b.idx != len(bundles)-1:
                ch.write(',\n')
        
        ''' Bit masks for X_BITS '''


        ch.write(f"\n}};\n\n")
        ch.write(f"#define X_BITS_L2   {int(np.log2(c.X_BITS))}\n")
        ch.write(f"#define W_BITS_L2   {int(np.log2(c.K_BITS))}\n")
        ch.write(f"#define X_PAD       {c.X_PAD}\n")
        ch.write(f"#define KH_MAX      {c.KH_MAX}\n")
        ch.write(f"#define PE_ROWS     {c.ROWS}\n")
        ch.write(f"#define PE_COLS     {c.COLS}\n\n")

        ch.write(f"#define N_ADD_BUF   {len(buffer_map) if len(buffer_map) > 0 else ''}\n")
        ch.write(f"#define WB_BYTES    {w_bytes + (b_words*c.B_BITS)//8}\n")
        ch.write(f"#define W_BYTES     {w_bytes}\n")
        ch.write(f"#define X_BYTES     {x_bytes}\n")
        ch.write(f"#define O_WORDS     {o_words}\n")
        ch.write(f"#define O_WORDS_MAX {o_words_max}\n")
        ch.write(f"#define O_BYTES_MAX {o_bytes_max}\n")
        ch.write(f"#define X_BYTES_ALL {x_bytes_all}\n")
        ch.write(f"#define NHWC_WORDS  {nhwc_words_max}\n")
        ch.write(f"#define B_TYPE      int{c.B_BITS}_t\n")
        ch.write(f"#define B_WORDS     {b_words}\n")
        ch.write(f'#define DATA_DIR   "{DATA_DIR_SIM}"\n\n')

        mask_nums = [(2**c.X_BITS-1) << (p*c.X_BITS)  for p in range(8//c.X_BITS)]
        mask_nums = ~np.array(mask_nums, dtype=np.uint8)
        ch.write(f"static const uint8_t X_POSITION_INVERTED_MASKS [] = {{ {', '.join([str(n) for n in mask_nums])} }};\n")

    '''
    Write Binary Files
    '''
    w_bitstring = b''
    x_bitstring = b''
    b_bitstring = b''
    for ib, b in enumerate(bundles):
        x_bitstring_b = b''
        if b.b:
            b_bitstring += b.be.astype(type_d['np'][c.B_BITS]).tobytes()
        for ip in range(b.r.CP):
            xe = Bundle.pack_words_into_bytes(arr=b.xe[ip].flatten(), bits=c.X_BITS)
            x_bitstring_b += b.r.x_header_be_p[ip!=0].tobytes() + xe.tobytes()
                
            for it in range(b.r.IT):
                we = Bundle.pack_words_into_bytes(arr=b.we[ip][it].flatten(), bits=c.K_BITS)
                w_bitstring += b.r.w_header_be_p[ip!=0].tobytes() + we.tobytes()
        x_bitstring += x_bitstring_b
        with open(f"{DATA_DIR}/{ib}_x_sim.bin", 'wb') as f: 
            f.write(x_bitstring_b)
        if ib==0:
            with open(f"{DATA_DIR}/x.bin", 'wb') as f: 
                f.write(x_bitstring_b)

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
    print("SIMULATING...")

    if SIM == 'xsim':
        with open('build/xsim_cfg.tcl', 'w') as f:
            f.write('''log_wave -recursive * \nrun all \nexit''')
        assert subprocess.run(fr'{XIL_PATH}\xsim {TB_MODULE} --tclbatch xsim_cfg.tcl', cwd="build", shell=True).returncode == 0
    if SIM == 'icarus':
        subprocess.run(["vvp", "build/a.out"])
    if SIM == 'verilator':
        subprocess.run([f"./V{TB_MODULE}"], cwd="build")


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
        assert error == 0, f"sim:\n{y_nhwc_sim[0,:,:,0]}\n exp:\n{b.oe_exp_nhwc[0,:,:,0]}\n input:\n{b.before_pool[0,:,:,0] if b.pool else None}"

        ''' Verify tiled output'''
        y_tiled_exp = b.o_int if ib == len(bundles)-1 else np.concatenate([a.flatten() for a in bundles[ib+1].xe])
        y_tiled_sim = np.loadtxt(f"{DATA_DIR}/{b.idx}_y_tiled_sim.txt", np.int32).reshape(y_tiled_exp.shape)
        error = np.sum(np.abs(y_tiled_sim-y_tiled_exp))
        assert error == 0, f"Error={error}, for y_tiled_sim at {b.idx=}"

        ''' Verify packed output'''
        if ib != len(bundles)-1:
            with open(f'{DATA_DIR}/{ib}_y_packed_sim.bin', 'rb') as f_sim, open(f'{DATA_DIR}/{ib+1}_x_sim.bin', 'rb') as f_exp:
                y_packed_sim = np.frombuffer(f_sim.read(), dtype=np.uint8)
                y_packed_exp = np.frombuffer(f_exp.read(), dtype=np.uint8)
            error = np.sum(np.abs(y_packed_sim-y_packed_exp))
            assert error == 0, f"Error={error}, for y_packed_sim at {b.idx=}, y_packed_sim=\n{y_packed_sim[:100]} \n y_packed_exp=\n{y_packed_exp[:100]}\n"
            
        print(f"Bundle {b.idx}, Error: {error}")