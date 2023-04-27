import numpy as np
import os
import torch
import subprocess
import glob
import os.path
import pytest
import itertools
from collections import namedtuple

# Simulator: xsim on windows, icarus otherwise
SIM = 'xsim' if os.name=='nt' else 'icarus'

DATA_DIR   = 'vectors'
os.makedirs(DATA_DIR, exist_ok=True)
MODEL_NAME = 'test'
# SIM = sys.argv[1] if len(sys.argv) == 2 else "xsim" # icarus
SOURCES = glob.glob('../params/*') + glob.glob('sv/*') + glob.glob("../rtl/**/*.v", recursive=True) + glob.glob("../rtl/**/*.sv", recursive=True)
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


@pytest.fixture(scope="module", params=list(product_dict(
                                                X_BITS = [8    ], 
                                                ROWS   = [4    ], 
                                                COLS   = [24   ], 
                                                KW_MAX = [3    ], 
                                                SW_MAX = [2    ], 
                                                CI_MAX = [1024 ], 
                                                XW_MAX = [384  ], 
                                                XH_MAX = [256  ], 
                                                IN_BITS= [64   ], 
                                                BRAM_WEIGHTS_DEPTH = [1024 ], 
                                            )))
def compile(request):
    c = request.param

    d = { 'KH_MAX':c.KW_MAX, 'SH_MAX':c.SW_MAX, 'K_BITS':c.X_BITS}
    n = namedtuple('Compile', d)(**d)
    c = namedtuple("Compile", c._fields + n._fields)(*(c + n))

    print(f"\n\n---------- {SIM}:{c} ----------\n\n")

    with open('../params/params_input.svh', 'w') as f:
        f.write(f'''
    // Written from param_tests.py

    `define SRAM_TYPE   "RAW"  
    `define MAC_TYPE    "RAW"  

    `define ROWS     {c.ROWS}  
    `define COLS     {c.COLS}
    `define DW_FACTOR_1 3
    `define OUTPUT_MODE "CONV"
    `define KSM_COMBS_EXPR 1
    `define KS_COMBS_EXPR 1
    `define BRAM_WEIGHTS_DEPTH  {c.BRAM_WEIGHTS_DEPTH}     

    `define FREQ_HIGH     200
    `define FREQ_RATIO    1

    `define WORD_WIDTH          {c.X_BITS}         
    `define WORD_WIDTH_ACC      32    
    `define KH_MAX              {c.KH_MAX}            
    `define KW_MAX              {c.KW_MAX}            
    `define SH_MAX              {c.SH_MAX}            
    `define SW_MAX              {c.SW_MAX}            
    `define IM_ROWS_MAX         {c.XH_MAX}
    `define IM_CIN_MAX          {c.CI_MAX}      
    `define IM_COLS_MAX         {c.XW_MAX}     

    `define LATENCY_ACCUMULATOR   1    
    `define LATENCY_MULTIPLIER    1     
    `define LATENCY_BRAM          2     

    `define S_WEIGHTS_WIDTH_LF  {c.IN_BITS}
    `define S_PIXELS_WIDTH_LF   {c.IN_BITS}
    `define M_OUTPUT_WIDTH_LF   64
    ''')

    os.makedirs('xsim', exist_ok=True)

    if SIM == 'xsim':
        SOURCES_STR = " ".join([os.path.normpath('../' + s) for s in SOURCES]) # since called from subdir
        assert subprocess.run(fr'{XIL_PATH}\xvlog -sv {SOURCES_STR}', cwd="xsim", shell=True).returncode == 0
        assert subprocess.run(fr'{XIL_PATH}\xelab {TB_MODULE} --snapshot {TB_MODULE} -log elaborate.log --debug typical', cwd="xsim", shell=True).returncode == 0

    if SIM == 'icarus':
        cmd = [ "iverilog", "-g2012", "-DICARUS", "-o", "xsim/a.out", "-I", "sv", "-I", "../params", "-s", TB_MODULE] + SOURCES
        print(" ".join(cmd))
        assert subprocess.run(cmd).returncode == 0

    return c


@pytest.mark.parametrize("KH", [1,3])
@pytest.mark.parametrize("CI", [8])
@pytest.mark.parametrize("CO", [8])
@pytest.mark.parametrize("XH", [12])
@pytest.mark.parametrize("XW", [8])
def test_dnn_engine(compile, KH, CI, CO, XH, XW):
    c= compile

    i_it = 0
    i_n  = 0
    i_layers = 0
    KW = KH
    N = 1
    assert KH <= c.KH_MAX
    assert KW <= c.KW_MAX
    assert CI <= c.CI_MAX
    assert XH <= c.XH_MAX
    assert XW <= c.XW_MAX

    for file in os.scandir(DATA_DIR):
        os.remove(file.path)

    '''
    GOLDEN MODEL
    '''
    # torch.manual_seed(0)
    x = torch.from_numpy(np.random.randint(-2**(c.X_BITS-1), 2**(c.X_BITS-1)-1 ,size=(N,CI,XH,XW)).astype(np.float32))
    w = torch.from_numpy(np.random.randint(-2**(c.K_BITS-1), 2**(c.K_BITS-1)-1 ,size=(CO,CI,KH,KW)).astype(np.float32))
    y = torch.nn.functional.conv2d(x, w, bias=None, stride=1, padding='same', dilation=1, groups=1)

    LAYER = {'w':w.numpy().transpose(2,3,1,0), 'x':x.numpy().transpose(0,2,3,1), 'y':y.numpy().transpose(0,2,3,1)}



    '''
    CALCULATE TILING PARAMS
    '''

    w = LAYER['w']
    x = LAYER['x']

    SW = 1
    SH = 1

    KH, KW, CI, CO = w.shape
    CO_PRL         = c.COLS * SW // KW                        # SW cols are processed in parallel
    EG             = int(np.floor( c.COLS / (KW + SW - 1)))   # elastic groups
    IT             = int(np.ceil( CO / (SW*EG)))            # iterations needed
    CO_PAD         = IT * CO_PRL                            # output cols padded

    print(f'{KH=}, {KW=}, {CI=}, {CO=}, {CO_PRL=}, {EG=}, {IT=}, {CO_PAD}')
    print('weights initial (KH, KW, CI, CO) =', w.shape)

    XN, XH, XW, CI = LAYER['x'].shape
    print('initial (XN, XH, XW, CI)=', x.shape)

    LH    = c.ROWS*SH   # Block height
    L     = XH//LH    # Blocks
    L_MAX = c.XH_MAX//c.ROWS

    '''LRELU BEATS'''
    LRELU_BEATS = 1
    # if KH == 1:
    #   LRELU_BEATS = 5
    # elif KH == 3:
    #   LRELU_BEATS = 5
    # else:
    #   raise "Error, unsupported KH for lrelu beats"

    def clog2(x):
        return int(np.ceil(np.log2(x)))

    BITS_KW2        = clog2((c.KW_MAX+1)/2)
    BITS_KH2        = clog2((c.KH_MAX+1)/2)
    BITS_SW         = clog2(c.SW_MAX)
    BITS_SH         = clog2(c.SH_MAX)
    BITS_CIN_MAX    = clog2(c.CI_MAX)
    BITS_COLS_MAX   = clog2(c.XW_MAX)
    BITS_BLOCKS_MAX = clog2( L_MAX)
    BITS_BRAM_WEIGHTS_ADDR = clog2(c.BRAM_WEIGHTS_DEPTH)
    BRAM_WEIGHTS_ADDR_MAX  = LRELU_BEATS + SW*KH*CI-1

    X_PAD = int(np.ceil(c.KH_MAX//2))




    '''
    CHECK SPARSITY
    '''

    w_sparse = (w==0).sum()/w.size
    x_sparse = (x==0).sum()/x.size

    p_both_zero = x_sparse * w_sparse
    p_only_one_zero = (1-x_sparse) * w_sparse  +  (1-w_sparse) * x_sparse
    p_neither_zero = (1-x_sparse) * (1-w_sparse)
    zero_result = 1-p_neither_zero

    print(f'''
    w_sparsity   : {w_sparse*100:.2f}%
    x_sparsity   : {x_sparse*100:.2f}%

    both_zero    : {p_both_zero*100:.2f}%
    only_one_zero: {p_only_one_zero*100:.2f}%
    neither_zero : {p_neither_zero*100:.2f}%
    zero_result  : {zero_result*100:.2f}%
    ''')




    '''
    TILE WEIGHTS
    '''

    w = LAYER['w']
    print('weights initial (KH, KW, CI, CO) =', w.shape)

    w = np.pad(w, ((0,0),(0,0),(0,0),(0,CO_PAD-CO)))   # (KH, KW, CI, CO_PAD)
    w = w.reshape(KH, KW, CI, IT, CO_PRL)              # (KH, KW, CI, IT, CO_PRL)
    w = np.flip(w, axis=4)

    # '''To fix DW bank issue'''
    # RATIO = c.KW_MAX//KW
    # w = w.reshape  (KH, KW, CI, IT, RATIO, CO_PRL//RATIO)
    # w = w.transpose(0,1,2,3,5,4)                       # (KH, KW, CI, IT, CO_PRL//RATIO, RATIO)
    # w = w.reshape  (KH, KW, CI, IT, CO_PRL)            # (KH, KW, CI, IT, CO_PRL)
    w = w.transpose(0,2,3,4,1)                         # (KH, CI, IT, CO_PRL, KW)

    '''Assume SW=1'''
    CO_PRL    = c.COLS // KW
    w = w.reshape  (KH, CI, IT, CO_PRL*KW)                # (KH, CI, IT, CO_PRL*KW)
    w = np.pad(w, ((0,0),(0,0),(0,0),(0,c.COLS-CO_PRL*KW))) # (KH, CI, IT, c.COLS)
    w = w.transpose(2,1,0,3)                              # (IT, CI, KH, c.COLS)
    w = w.reshape (IT, CI*KH, c.COLS)                       # (IT, CI*KH, c.COLS)
    w = np.pad(w, ((0,0),(LRELU_BEATS,0),(0,0)))          # (IT, LRELU_BEATS+CI*KH, c.COLS)
    w = w.reshape (IT, (CI*KH+LRELU_BEATS)*c.COLS)          # (IT, (CI*KH+LRELU_BEATS)*c.COLS)

    '''Weights config'''

    weights_config = 0
    weights_config |= (KW//2)
    weights_config |= (KH//2)               << (BITS_KW2)
    weights_config |= SW-1                  << (BITS_KW2 + BITS_KH2)
    weights_config |= (CI-1)                << (BITS_KW2 + BITS_KH2 + BITS_SW)
    weights_config |= (XW-1)                << (BITS_KW2 + BITS_KH2 + BITS_SW + BITS_CIN_MAX)
    weights_config |= ( L-1)                << (BITS_KW2 + BITS_KH2 + BITS_SW + BITS_CIN_MAX + BITS_COLS_MAX)
    weights_config |= BRAM_WEIGHTS_ADDR_MAX << (BITS_KW2 + BITS_KH2 + BITS_SW + BITS_CIN_MAX + BITS_COLS_MAX + BITS_BLOCKS_MAX)

    weights_config = format(weights_config, f'#0{c.IN_BITS}b')
    config_words = [int(weights_config[i:i+c.K_BITS], 2) for i in range(0, len(weights_config), c.K_BITS)]
    config_words.reverse()
    config_words = np.array(config_words,dtype=np.int8)
    config_words = np.repeat(config_words[np.newaxis,...],repeats=IT,axis=0)
    '''Final'''
    w = np.concatenate([config_words, w], axis=1) # (IT, 8 + CI*KH*c.COLS)
    assert w.shape == (IT, c.IN_BITS/c.K_BITS + (CI*KH+LRELU_BEATS)*c.COLS)

    path = f"{DATA_DIR}/{MODEL_NAME}_conv_{i_layers}_w.txt"
    np.savetxt(path, w[i_it].flatten(), fmt='%d')
    print(f'weights final (IT, 8 + (CI*KH+LRELU_BEATS)*c.COLS) = {w.shape} \nSaved as {path}')



    '''
    Tile Input
    '''

    x = LAYER['x']
    print('input initial (XN, XH, XW, CI)=', x.shape)

    x = np.pad(x, ((0,0),(0,LH*L-XH),(0,0),(0,0)))   # (XN, L*HL , XW, CI)
    x = x.reshape  (XN, L, LH, XW, CI)               # (XN, L, HL, XW, CI)

    zeros = np.zeros((XN,L,c.ROWS+X_PAD,XW,CI),x.dtype)  # (XN,L,c.ROWS+X_PAD,XW,CI)

    zeros[:,:,:c.ROWS,:,:] = x

    for l in range(L):
        ''' Fill bot rows from next '''
        if l == L-1:
            zeros[:,l, c.ROWS: ,:,:] = np.zeros((XN,X_PAD,XW,CI),x.dtype)
        else:
            zeros[:,l, c.ROWS: ,:,:] = x[:,l+1,:X_PAD,:,:]


    x = zeros                  # (XN,L,c.ROWS+X_PAD,XW,CI)
    x = x.transpose(0,1,3,4,2) # (XN,L,XW,CI,c.ROWS+X_PAD)

    x = x[i_n]
    x = x.reshape((L*XW*CI*(c.ROWS+X_PAD)))  #! XN should be moved in

    '''
    Config
    '''
    is_max     = 0
    is_not_max = 1
    is_relu    = 0

    config = 0
    config |= (KH//2)
    config |= (CI-1) << BITS_KW2
    config |= (XW-1) << BITS_KW2 + BITS_CIN_MAX
    config |= (L -1) << BITS_KW2 + BITS_CIN_MAX + BITS_COLS_MAX

    assert c.IN_BITS >= BITS_KW2 + BITS_CIN_MAX + BITS_COLS_MAX + BITS_BLOCKS_MAX
    # config |= (c.ROWS+int(np.ceil(KH/SH)-1)) << 3 + BITS_KH2 + BITS_KW2 + BITS_SH

    config = format(config, f'#0{c.IN_BITS}b')
    config_words = [int(config[i:i+c.X_BITS], 2) for i in range(0, len(config), c.X_BITS)]
    config_words.reverse()
    x = np.concatenate([np.array(config_words, dtype=np.uint8), x.flatten()])
    assert x.shape == (c.IN_BITS/c.X_BITS + L*XW*CI*(c.ROWS+X_PAD),)

    path = f"{DATA_DIR}/{MODEL_NAME}_conv_{i_layers}_x.txt"
    np.savetxt(path, x.flatten(), fmt='%d')
    print(f'input final (c.IN_BITS/c.X_BITS + L*XW*CI*c.ROWS+X_PAD)={x.shape} \nSaved as "{path}"')




    '''
    TILE OUTPUTS
    '''

    y = LAYER['y']      # (XN, XH , XW, CO)
    print('output initial (XN, XH , XW, CO) =', y.shape)

    y = np.pad(y, ((0,0),(0,LH*L-XH),(0,0),(0,CO_PAD-CO)))   # (XN, L*HL , XW, CO_PAD)
    y = y.reshape((XN, L, c.ROWS, XW, CO_PAD))                 # (XN,L,c.ROWS,XW,CO_PAD)
    y = y.reshape((XN, L, c.ROWS, XW, IT, CO_PRL))             # (XN,L,c.ROWS,XW,IT,CO_PRL)
    y = y.transpose(4,0,1,3,5,2)                             # (IT,XN,L,XW,CO_PRL,c.ROWS)

    assert y.shape == (IT,XN,L,XW,CO_PRL,c.ROWS)

    y_w_last = y[:,:,:,-(KW//2+1):,:,:]
    y_w_last = y_w_last.transpose(0,1,2,4,3,5).reshape(IT,XN,L,(KW//2+1)*CO_PRL,c.ROWS)

    y = y.reshape(IT,XN,L,XW*CO_PRL,c.ROWS)
    y[:,:,:,-(KW//2+1)*CO_PRL:,:] = y_w_last

    y = y[0,0]
    path = f"{DATA_DIR}/{MODEL_NAME}_conv_{i_layers}_y_exp.txt"
    np.savetxt(path, y.flatten(), fmt='%d')
    print(f'output final (IT,XN,L,XW,CO_PRL,c.ROWS)={y.shape} \nSaved as "{path}"')




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




    '''
    CHECK ERROR
    '''
    y_sim = np.loadtxt(f"{DATA_DIR}/{MODEL_NAME}_conv_{i_layers}_y_sim.txt",np.int32)
    error = np.sum(np.abs(y_sim.reshape(y.shape) - y))

    print("Error: ", error)
    assert error == 0

    if error != 0 and SIM=='xsim':
        print(fr'''Non zero error. Open waveform with:

    call {XIL_PATH}\xsim --gui {TB_MODULE}.wdb -view ..\wave\{WAVEFORM}''')