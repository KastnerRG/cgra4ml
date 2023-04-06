import numpy as np
import os
import torch
import subprocess
import glob
import os.path

# Simulator: xsim on windows, icarus otherwise
SIM = 'xsim' if os.name=='nt' else 'icarus'

DATA_DIR   = 'vectors'
os.makedirs(DATA_DIR, exist_ok=True)
MODEL_NAME = 'test'
# SIM = sys.argv[1] if len(sys.argv) == 2 else "xsim" # icarus
SOURCES = glob.glob('../params/*') + glob.glob('sv/*') + glob.glob("../rtl/**/*.v", recursive=True) + glob.glob("../rtl/**/*.sv", recursive=True)
print(SOURCES)

TB_MODULE = "axis_accelerator_tb"
WAVEFORM = "axis_accelerator_tb_behav.wcfg"
XIL_PATH = os.path.join("F:", "Xilinx", "Vivado", "2022.1", "bin")


def test_dnn_engine(
    KH=3, KW=3, CI=8, CO=8, XH=8, XW=8, # soft params
    X_BITS=8, ROWS=8, COLS=24, W_CONFIG=8, IN_BITS=64, KW_MAX=3, KH_MAX=3, SH_MAX=2, SW_MAX=2, CI_MAX=1024, XW_MAX=384, XH_MAX=256, BRAM_WEIGHTS_DEPTH=1024, # hard params
    ):

    print(SIM)

    i_it = 0
    i_n  = 0
    i_layers = 0
    K_BITS = X_BITS
    N = 1

    for file in os.scandir(DATA_DIR):
        os.remove(file.path)

    '''
    GOLDEN MODEL
    '''

    x = torch.from_numpy(np.random.randint(-2**(X_BITS-1), 2**(X_BITS-1)-1 ,size=(N,CI,XH,XW)).astype(np.float32))
    w = torch.from_numpy(np.random.randint(-2**(K_BITS-1), 2**(K_BITS-1)-1 ,size=(CO,CI,KH,KW)).astype(np.float32))
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
    CO_PRL         = COLS * SW // KW                        # SW cols are processed in parallel
    EG             = int(np.floor( COLS / (KW + SW - 1)))   # elastic groups
    IT             = int(np.ceil( CO / (SW*EG)))            # iterations needed
    CO_PAD         = IT * CO_PRL                            # output cols padded

    print(f'{KH=}, {KW=}, {CI=}, {CO=}, {CO_PRL=}, {EG=}, {IT=}, {CO_PAD}')
    print('weights initial (KH, KW, CI, CO) =', w.shape)

    XN, XH, XW, CI = LAYER['x'].shape
    print('initial (XN, XH, XW, CI)=', x.shape)

    LH    = ROWS*SH   # Block height
    L     = XH//LH    # Blocks
    L_MAX = XH_MAX//ROWS

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

    BITS_KW2        = clog2((KW_MAX+1)/2)
    BITS_KH2        = clog2((KH_MAX+1)/2)
    BITS_SW         = clog2(SW_MAX)
    BITS_SH         = clog2(SH_MAX)
    BITS_CIN_MAX    = clog2(CI_MAX)
    BITS_COLS_MAX   = clog2(XW_MAX)
    BITS_BLOCKS_MAX = clog2( L_MAX)
    BITS_BRAM_WEIGHTS_ADDR = clog2(BRAM_WEIGHTS_DEPTH)
    BRAM_WEIGHTS_ADDR_MAX  = LRELU_BEATS + SW*KH*CI-1

    '''Shift'''
    SHIFT = int(np.ceil(KH/SH)-1)




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

    '''To fix DW bank issue'''
    RATIO = KW_MAX//KW
    w = w.reshape  (KH, KW, CI, IT, RATIO, CO_PRL//RATIO)
    w = w.transpose(0,1,2,3,5,4)                       # (KH, KW, CI, IT, CO_PRL//RATIO, RATIO)
    w = w.reshape  (KH, KW, CI, IT, CO_PRL)            # (KH, KW, CI, IT, CO_PRL)
    w = w.transpose(0,2,3,4,1)                         # (KH, CI, IT, CO_PRL, KW)

    '''Assume SW=1'''
    CO_PRL    = COLS // KW
    w = w.reshape  (KH, CI, IT, CO_PRL*KW)                # (KH, CI, IT, CO_PRL*KW)
    w = np.pad(w, ((0,0),(0,0),(0,0),(0,COLS-CO_PRL*KW))) # (KH, CI, IT, COLS)
    w = w.transpose(2,1,0,3)                              # (IT, CI, KH, COLS)
    w = w.reshape (IT, CI*KH, COLS)                       # (IT, CI*KH, COLS)
    w = np.pad(w, ((0,0),(LRELU_BEATS,0),(0,0)))          # (IT, LRELU_BEATS+CI*KH, COLS)
    w = w.reshape (IT, (CI*KH+LRELU_BEATS)*COLS)          # (IT, (CI*KH+LRELU_BEATS)*COLS)

    '''Weights config'''

    weights_config = 0
    weights_config |= (KW//2)
    weights_config |= (KH//2)               << (BITS_KW2)
    weights_config |= SW-1                  << (BITS_KW2 + BITS_KH2)
    weights_config |= (CI-1)                << (BITS_KW2 + BITS_KH2 + BITS_SW)
    weights_config |= (XW-1)                << (BITS_KW2 + BITS_KH2 + BITS_SW + BITS_CIN_MAX)
    weights_config |= ( L-1)                << (BITS_KW2 + BITS_KH2 + BITS_SW + BITS_CIN_MAX + BITS_COLS_MAX)
    weights_config |= BRAM_WEIGHTS_ADDR_MAX << (BITS_KW2 + BITS_KH2 + BITS_SW + BITS_CIN_MAX + BITS_COLS_MAX + BITS_BLOCKS_MAX)

    weights_config = format(weights_config, f'#0{IN_BITS}b')
    config_words = [int(weights_config[i:i+K_BITS], 2) for i in range(0, len(weights_config), K_BITS)]
    config_words.reverse()
    config_words = np.array(config_words,dtype=np.int8)
    config_words = np.repeat(config_words[np.newaxis,...],repeats=IT,axis=0)
    '''Final'''
    w = np.concatenate([config_words, w], axis=1) # (IT, 8 + CI*KH*COLS)
    assert w.shape == (IT, IN_BITS/K_BITS + (CI*KH+LRELU_BEATS)*COLS)

    path = f"{DATA_DIR}/{MODEL_NAME}_conv_{i_layers}_w.txt"
    np.savetxt(path, w[i_it].flatten(), fmt='%d')
    print(f'weights final (IT, 8 + (CI*KH+LRELU_BEATS)*COLS) = {w.shape} \nSaved as {path}')



    '''
    Tile Input
    '''

    x = LAYER['x']
    print('input initial (XN, XH, XW, CI)=', x.shape)

    x = np.pad(x, ((0,0),(0,LH*L-XH),(0,0),(0,0)))   # (XN, L*HL , XW, CI)
    x = x.reshape  (XN, L, LH, XW, CI)               # (XN, L, HL, XW, CI)
    # x = x.transpose(0,1,3,4,2)                     # (XN, L, HW, CI, HL)

    zeros = np.zeros((XN,L,SH*(ROWS+SHIFT),XW,CI),x.dtype)  # (XN,L,SH*(ROWS+SHIFT),XW,CI)
    top_edges = KH//2
    bot_edges = SH*(ROWS+SHIFT) - top_edges - LH

    zeros[:,:,top_edges:SH*(ROWS+SHIFT)-bot_edges,:,:] = x

    for l in range(L):
        ''' Fill top rows from prev '''
        if l == 0:
            zeros[:,l,:top_edges,:,:] = np.zeros((XN,top_edges,XW,CI),x.dtype)
        else:
            zeros[:,l,:top_edges,:,:] = x[:,l-1,LH-top_edges:,:,:]

        ''' Fill bot rows from next '''
        if l == L-1:
            zeros[:,l,SH*(ROWS+SHIFT)-bot_edges:,:,:] = np.zeros((XN,bot_edges,XW,CI),x.dtype)
        else:
            zeros[:,l,SH*(ROWS+SHIFT)-bot_edges:,:,:] = x[:,l+1,:bot_edges,:,:]


    x = zeros                  # (XN,L,SH*(ROWS+SHIFT),XW,CI)
    x = x.transpose(0,1,3,4,2) # (XN,L,XW,CI,SH*(ROWS+SHIFT))

    x = x[i_n]
    x = x.reshape((L*XW*CI*SH*(ROWS+SHIFT)))  #! XN should be moved in

    '''
    Config
    '''
    is_max     = 0
    is_not_max = 1
    is_relu    = 0

    config = 0
    config |= is_not_max
    config |= is_max  << 1
    config |= is_relu << 2
    config |= (KH//2) << 3
    config |= (KW//2) << 3 + BITS_KH2
    config |= (SH-1 ) << 3 + BITS_KH2 + BITS_KW2
    config |= (ROWS+SHIFT) << 3 + BITS_KH2 + BITS_KW2 + BITS_SH

    config = format(config, f'#0{IN_BITS}b')
    config_words = [int(config[i:i+X_BITS], 2) for i in range(0, len(config), X_BITS)]
    config_words.reverse()
    x = np.concatenate([np.array(config_words, dtype=np.uint8), x.flatten()])
    assert x.shape == (IN_BITS/X_BITS + L*XW*CI*SH*(ROWS+SHIFT),)

    path = f"{DATA_DIR}/{MODEL_NAME}_conv_{i_layers}_x.txt"
    np.savetxt(path, x.flatten(), fmt='%d')
    print(f'input final (IN_BITS/X_BITS + L*XW*CI*SH*(ROWS+SHIFT))={x.shape} \nSaved as "{path}"')




    '''
    TILE OUTPUTS
    '''

    y = LAYER['y']      # (XN, XH , XW, CO)
    print('output initial (XN, XH , XW, CO) =', y.shape)

    y = np.pad(y, ((0,0),(0,LH*L-XH),(0,0),(0,CO_PAD-CO)))   # (XN, L*HL , XW, CO_PAD)
    y = y.reshape((XN, L, ROWS, XW, CO_PAD))                 # (XN,L,ROWS,XW,CO_PAD)
    y = y.reshape((XN, L, ROWS, XW, IT, CO_PRL))             # (XN,L,ROWS,XW,IT,CO_PRL)
    y = y.transpose(4,0,1,3,5,2)                             # (IT,XN,L,XW,CO_PRL,ROWS)

    assert y.shape == (IT,XN,L,XW,CO_PRL,ROWS)

    y = y[0,0]
    path = f"{DATA_DIR}/{MODEL_NAME}_conv_{i_layers}_y_exp.txt"
    np.savetxt(path, y.flatten(), fmt='%d')
    print(f'output final (IT,XN,L,XW,CO_PRL,ROWS)={y.shape} \nSaved as "{path}"')




    with open('../params/params.v', 'w') as f:
            f.write(f'''
    // Written from param_tests.py

    `define SRAM_TYPE   "RAW"  
    `define MAC_TYPE    "RAW"  

    `define UNITS    {ROWS}  
    `define GROUPS   1 
    `define COPIES   1 
    `define MEMBERS  {COLS}
    `define DW_FACTOR_1 3
    `define OUTPUT_MODE "CONV"
    `define KSM_COMBS_EXPR 1
    `define KS_COMBS_EXPR 1
    `define BRAM_WEIGHTS_DEPTH  {BRAM_WEIGHTS_DEPTH}     

    `define FREQ_HIGH     200
    `define FREQ_RATIO    1

    `define WORD_WIDTH          {X_BITS}         
    `define WORD_WIDTH_ACC      32    
    `define KH_MAX              {KH_MAX}            
    `define KW_MAX              {KW_MAX}            
    `define SH_MAX              {SH_MAX}            
    `define SW_MAX              {SW_MAX}            
    `define IM_ROWS_MAX         {XH_MAX}
    `define IM_CIN_MAX          {CI_MAX}      
    `define IM_COLS_MAX         {XW_MAX}     
    `define LRELU_ALPHA      11878     
    `define LRELU_BEATS_MAX  9

    `define LATENCY_ACCUMULATOR   1    
    `define LATENCY_MULTIPLIER    1     

    `define S_WEIGHTS_WIDTH_LF  {IN_BITS}
    `define S_PIXELS_WIDTH_LF   {IN_BITS}
    `define M_OUTPUT_WIDTH_LF   64

    `define BITS_EXP_CONFIG       5      
    `define BITS_FRA_CONFIG       10      
    `define BITS_EXP_FMA_1        8       
    `define BITS_FRA_FMA_1        23       
    `define BITS_EXP_FMA_2        5       
    `define BITS_FRA_FMA_2        10       
    `define LATENCY_FMA_1         16        
    `define LATENCY_FMA_2         15        
    `define LATENCY_FIXED_2_FLOAT 6
    `define LATENCY_BRAM          2         
    `define LATENCY_CYCLIC_REG    0         
    `define LATENCY_FLOAT_UPSIZE   2   
    `define LATENCY_FLOAT_DOWNSIZE 3   


    // Calculated

    `define IM_BLOCKS_MAX    `IM_ROWS_MAX / `UNITS   
    `define UNITS_EDGES        `UNITS + `KH_MAX -1
    `define OUT_SHIFT_MAX      `MEMBERS/3
    `define IM_SHIFT_MAX       4   /* max( ceil(k/s)-1 )*/
    `define IM_SHIFT_REGS      `UNITS + `IM_SHIFT_MAX

    `define BITS_KW            $clog2( `KW_MAX             )         
    `define BITS_KH            $clog2( `KH_MAX             )         
    `define BITS_SW            $clog2( `SW_MAX             )         
    `define BITS_SH            $clog2( `SH_MAX             )         
    `define BITS_IM_COLS       $clog2( `IM_COLS_MAX        )    
    `define BITS_IM_ROWS       $clog2( `IM_ROWS_MAX        )    
    `define BITS_IM_CIN        $clog2( `IM_CIN_MAX         )      
    `define BITS_IM_BLOCKS     $clog2( `IM_ROWS_MAX/`UNITS )  
    `define BITS_IM_SHIFT      $clog2( `IM_SHIFT_MAX       )  
    `define BITS_IM_SHIFT_REGS $clog2( `IM_SHIFT_REGS+1    )  
    `define BITS_WEIGHTS_ADDR  $clog2( `BRAM_WEIGHTS_DEPTH )   
    `define BITS_MEMBERS       $clog2( `MEMBERS            )    
    `define BITS_KW2           $clog2((`KW_MAX+1)/2        )        
    `define BITS_KH2           $clog2((`KH_MAX+1)/2        )        
    `define BITS_OUT_SHIFT     $clog2( `OUT_SHIFT_MAX      )        


    `define M_DATA_WIDTH_HF_CONV     `COPIES * `GROUPS * `MEMBERS * `UNITS * `WORD_WIDTH_ACC
    `define M_DATA_WIDTH_HF_CONV_DW  `COPIES * `GROUPS * `UNITS * `WORD_WIDTH_ACC
    `define M_DATA_WIDTH_HF_LRELU    `COPIES * `GROUPS * `UNITS * `WORD_WIDTH
    `define M_DATA_WIDTH_HF_MAXPOOL  `GROUPS * `COPIES * `UNITS_EDGES * `WORD_WIDTH
    `define M_DATA_WIDTH_HF_MAX_DW1  `GROUPS * `UNITS_EDGES * `WORD_WIDTH
    `define M_DATA_WIDTH_LF_CONV_DW  8 * $clog2(`M_DATA_WIDTH_HF_CONV_DW * `FREQ_RATIO / 8) /* max 1024 */
    `define M_DATA_WIDTH_LF_LRELU    8 * $clog2(`M_DATA_WIDTH_HF_LRELU   * `FREQ_RATIO / 8) /* max 1024 */
    `define M_DATA_WIDTH_LF_MAXPOOL  8 * $clog2(`M_DATA_WIDTH_HF_MAX_DW1 * `FREQ_RATIO / 8) /* max 1024 */
    `define M_DATA_WIDTH_LF         `OUTPUT_MODE=="CONV" ? `M_DATA_WIDTH_LF_CONV_DW : `OUTPUT_MODE=="LRELU" ? `M_DATA_WIDTH_LF_LRELU : `OUTPUT_MODE=="MAXPOOL" ? `M_DATA_WIDTH_LF_MAXPOOL : 0

    `define DEBUG_CONFIG_WIDTH_W_ROT   1 + 2*`BITS_KW2 + 3*(`BITS_KH2      + `BITS_IM_CIN + `BITS_IM_COLS + `BITS_IM_BLOCKS)
    `define DEBUG_CONFIG_WIDTH_IM_PIPE 3 + 2 + `BITS_KH2      + 0
    `define DEBUG_CONFIG_WIDTH_LRELU   3 + 4 + `BITS_FRA_FMA_2 + `BITS_EXP_FMA_2 + 1
    `define DEBUG_CONFIG_WIDTH_MAXPOOL 1
    `define DEBUG_CONFIG_WIDTH         `DEBUG_CONFIG_WIDTH_MAXPOOL + `DEBUG_CONFIG_WIDTH_LRELU + 2*`BITS_KH2      + `DEBUG_CONFIG_WIDTH_IM_PIPE + `DEBUG_CONFIG_WIDTH_W_ROT


    // IMAGE TUSER INDICES
    `define I_IS_NOT_MAX       0
    `define I_IS_MAX            `I_IS_NOT_MAX + 1
    `define I_IS_LRELU          `I_IS_MAX     + 1
    `define I_KH2               `I_IS_LRELU   + 1
    `define I_SH_1              `I_KH2        + 1
    `define TUSER_WIDTH_PIXELS  `I_IS_LRELU   + 1

    // WEIGHTS TUSER INDICES
    `define I_WEIGHTS_KW2              0
    `define I_WEIGHTS_SW_1              `I_WEIGHTS_KW2     + `BITS_KW2
    `define I_WEIGHTS_IS_TOP_BLOCK      `I_WEIGHTS_SW_1    + `BITS_SW 
    `define I_WEIGHTS_IS_BOTTOM_BLOCK   `I_WEIGHTS_IS_TOP_BLOCK    + 1
    `define I_WEIGHTS_IS_COLS_1_K2      `I_WEIGHTS_IS_BOTTOM_BLOCK + 1
    `define I_WEIGHTS_IS_CONFIG         `I_WEIGHTS_IS_COLS_1_K2    + 1
    `define I_WEIGHTS_IS_CIN_LAST       `I_WEIGHTS_IS_CONFIG       + 1 
    `define I_WEIGHTS_IS_W_FIRST        `I_WEIGHTS_IS_CIN_LAST     + 1 
    `define I_WEIGHTS_IS_COL_VALID      `I_WEIGHTS_IS_W_FIRST      + 1 
    `define I_WEIGHTS_IS_SUM_START      `I_WEIGHTS_IS_COL_VALID    + 1 
    `define TUSER_WIDTH_WEIGHTS_OUT     `I_WEIGHTS_IS_SUM_START    + 1

    // PIPE TUSER INDICES
    `define I_IS_NOT_MAX      0
    `define I_IS_MAX           `I_IS_NOT_MAX      + 1
    `define I_IS_LRELU         `I_IS_MAX          + 1
    `define I_KW2              `I_IS_LRELU        + 1
    `define I_SW_1             `I_KW2     + `BITS_KW2
    `define I_IS_CONFIG        `I_SW_1    + `BITS_SW 
    `define I_IS_TOP_BLOCK     `I_IS_CONFIG       + 1
    `define I_IS_BOTTOM_BLOCK  `I_IS_TOP_BLOCK    + 1
    `define I_IS_COLS_1_K2     `I_IS_BOTTOM_BLOCK + 1
    `define I_IS_CIN_LAST      `I_IS_COLS_1_K2    + 1
    `define I_IS_W_FIRST       `I_IS_CIN_LAST     + 1
    `define I_IS_COL_VALID     `I_IS_W_FIRST      + 1
    `define I_IS_SUM_START     `I_IS_COL_VALID    + 1

    `define I_CLR              `I_IS_BOTTOM_BLOCK + 1

    `define TUSER_WIDTH_MAXPOOL_IN      `BITS_KW2      + `I_KW2
    `define TUSER_WIDTH_LRELU_IN        `BITS_KW       + `I_CLR
    `define TUSER_CONV_DW_BASE          1 + `I_IS_BOTTOM_BLOCK 
    `define TUSER_CONV_DW_IN            `MEMBERS*`BITS_KW + `BITS_OUT_SHIFT + `BITS_MEMBERS + `TUSER_CONV_DW_BASE
    `define TUSER_WIDTH_LRELU_FMA_1_IN  1         + `I_IS_LRELU
    `define TUSER_WIDTH_CONV_IN         `I_IS_SUM_START     + 1


    `define TUSER_WIDTH_PIXELS        `I_IS_LRELU   + 1 
    `define TUSER_WIDTH_IM_SHIFT_IN   `I_SH_1 + `BITS_SH 
    `define TUSER_WIDTH_IM_SHIFT_OUT  `I_IS_LRELU + 1
    ''')




    '''
    RUN SIMULATION
    '''

    os.makedirs('xsim', exist_ok=True)

    if SIM == 'xsim':
        with open('xsim/xsim_cfg.tcl', 'w') as f:
            f.write('''log_wave -recursive * \nrun all \nexit''')

        SOURCES_STR = " ".join([os.path.normpath('../' + s) for s in SOURCES]) # since called from subdir
        assert subprocess.run(fr'{XIL_PATH}\xvlog -sv {SOURCES_STR}', cwd="xsim", shell=True).returncode == 0
        assert subprocess.run(fr'{XIL_PATH}\xelab {TB_MODULE} --snapshot {TB_MODULE} -log elaborate.log --debug typical', cwd="xsim", shell=True).returncode == 0
        assert subprocess.run(fr'{XIL_PATH}\xsim {TB_MODULE} --tclbatch xsim_cfg.tcl', cwd="xsim", shell=True).returncode == 0


    if SIM == 'icarus':
        print("COMPILING...")

        cmd = [ "iverilog", "-g2012", "-DICARUS", "-o", "xsim/a.out", "-I", "sv", "-s", TB_MODULE] + SOURCES
        print(" ".join(cmd))
        assert subprocess.run(cmd).returncode == 0

        print("SIMULATING...")
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