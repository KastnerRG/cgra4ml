import numpy as np 
from math import ceil
from dataclasses import dataclass, field

from numpy.core.fromnumeric import transpose

@dataclass(frozen=True)
class SysConfig:
    CONV_UNITS        : int
    MEMBERS           : int
    COPIES            : int
    GROUPS            : int
    WORD_WIDTH_CONFIG : int
    DATA_DIR          : str

    PREFIX_CONV  : int
    PREFIX_MAX   : int
    PREFIX_LRELU : int
    LAYERS       : dict = field(repr=False)

    KW_MAX     :int 
    KH_MAX     :int 
    SH_MAX     :int 
    SW_MAX     :int 
    CIN_MAX    :int 
    COLS_MAX   :int 
    ROWS_MAX   :int 
    BRAM_WEIGHTS_DEPTH :int 

    ADDR_WEIGHTS : str
    ADDR_IN_LUT  : str
    ADDR_IN  : str
    ADDR_OUT : str

    RGB_H : int
    RGB_W : int

    BLOCKS_MAX  :int = 0
    UNITS_EDGES :int = 0
    CORES       :int = 0

    LRELU_BEATS_1x1 :int = 5
    LRELU_BEATS_3x3 :int = 9

    def __post_init__(self):
        super().__setattr__('BLOCKS_MAX', self.ROWS_MAX//self.CONV_UNITS)
        super().__setattr__('UNITS_EDGES', self.CONV_UNITS + self.KH_MAX-1)
        super().__setattr__('CORES', self.COPIES*self.GROUPS)

        assert self.KH_MAX  % 2 == 1
        assert self.KW_MAX  % 2 == 1


def fill_invalid_scg(arr, KW, max_factor, c, copy_factor=1):
    '''
    Input  shape: (COUT,...)
    Output shape: (ITR,EFF_CORES,...)

    System out is in SCG form. Hence by default we fill invalid in that form
    '''
    input_shape = arr.shape

    CORES = c.CORES//copy_factor

    COUT = input_shape[0]
    SUB_CORES = c.MEMBERS//KW
    EFF_CORES = CORES * SUB_CORES //max_factor
    ITR = int(np.ceil(COUT/EFF_CORES))
    COUT_FPGA = EFF_CORES * ITR

    COUT_VALID = COUT % EFF_CORES
    COUT_VALID = EFF_CORES if COUT_VALID == 0 else COUT_VALID
    COUT_INVALID = EFF_CORES - COUT_VALID

    shape_fpga = list(arr.shape)
    shape_fpga[0] = COUT_FPGA
    
    arr_filled = np.zeros(shape_fpga, arr.dtype)
    arr_filled[0:COUT_VALID,...] = arr[0:COUT_VALID,...]
    arr_filled[EFF_CORES:  ,...] = arr[COUT_VALID: ,...]


    arr_filled = arr_filled.reshape([ITR,EFF_CORES]+shape_fpga[1:])

    print(f'Filling invalid scg - in_shape: {input_shape}, out_shape{arr_filled.shape}')

    return arr_filled


def get_lrelu_config(i_layers, c, get_params=False):
    '''
    LRelu config are accepted in (beats,CGM) format

    conv_out.shape          = [beats][C,G,M]:int32
    lrelu_config_flat.shape = [beats][C,G,M]:int8
    
    **********************
    Say M = 12, KW_max = 3
    **********************

    BEATS_D   = 1
    BEATS_A   = ceil(2/KW) = ceil(2*SUB_CORES/MEMBERS) = ceil(2*MEMBERS/KW/MEMBERS)
    BEATS_Bij:
        
        kw2_i       = (i+1)/2
        kw_i        = kw2_i*2 + 1

        WIDTH_Bij   = M/kw_i
        WRITE_DEPTH = 2*SUB_CORES = 2*M/kw
        
        BEATS_Bij   = ceil(WRITE_DEPTH/WIDTH_Bij)

    LUT:
        BEATS[i][kw2] = ceil((2*M/(kw2*2+1))/(M/(((i+1)/2)*2 + 1)))

    BEATS_kw = sum(Bij)
    
    For kw = 1:
    ----------

    - d        : 2B
    - bram_A   : depth = 12, width = 2B, size = 24B
    - bram_B_00: depth = 12, width = 2B, size = 24B

    conv_out.shape          = [5][C,G,12]:int32
    lrelu_config_flat.shape = [5][C,G,12]:int8

    beats (5):
        0: d
        1: A   [0: 5]
        2: A   [5:11]
        3: B_00[0: 5]
        4: B_00[5:11]


    For kw = 3:
    ----------

    - d        : 2B
    - bram_A   : depth = 4, width = 2B, size = 8B
    - bram_B_ij: depth = 4, width = 2B, size = 8B

    conv_out.shape          = [5][C,G,12]:int32
    lrelu_config_flat.shape = [5][C,G,12]:int8

    beats (9):
        0: d
        1: A   [0:3]
        2: B_00[0:1]                         : clr=0
        3:            B_01[0:1], B_02[0:1]   : clr=0
        4:            B_01[0:1], B_02[0:1]   : clr=0
        5: B_11[0:1], B_11[0:1], B_12[0:1]   : clr=1
        6: B_11[0:1], B_11[0:1], B_12[0:1]   : clr=1
        7: B_21[0:1], B_21[0:1], B_22[0:1]   : clr=2
        8: B_21[0:1], B_21[0:1], B_22[0:1]   : clr=2

    '''

    if f'{c.PREFIX_LRELU}{i_layers}' in c.LAYERS:
        layer = c.LAYERS[f'{c.PREFIX_LRELU}{i_layers}']
        conv_layer = layer.prev_layer
    else:
        layer = c.LAYERS[f'{c.PREFIX_CONV}{i_layers}']
        conv_layer = layer


    '''
    Get max factor and sub cores
    '''
    max_factor = 2 if f'{c.PREFIX_MAX}{i_layers}' in c.LAYERS.keys() else 1
    KH,KW,_,_ = conv_layer.weights.shape
    SUB_CORES = c.MEMBERS//KW

    '''
    A, B, D parameters
    '''
    params = layer.requantize_params
    _,H,W,COUT = params['B'].shape

    b_cout_clr_mtb = np.zeros((COUT,KW,KH), np.float16)
    b_cout_clr_mtb[:,0,0] = params['B'][0,1,1,:]            # for both K=1 and K=3

    if KW == 3:
        b_cout_clr_mtb[:,0,1] = params['B'][0,  0,  1,:]
        b_cout_clr_mtb[:,0,2] = params['B'][0,H-1,  1,:]

        b_cout_clr_mtb[:,1,0] = params['B'][0,  1,  0,:]
        b_cout_clr_mtb[:,1,1] = params['B'][0,  0,  0,:]
        b_cout_clr_mtb[:,1,2] = params['B'][0,H-1,  0,:]

        b_cout_clr_mtb[:,2,0] = params['B'][0,  1,W-1,:]
        b_cout_clr_mtb[:,2,1] = params['B'][0,  0,W-1,:]
        b_cout_clr_mtb[:,2,2] = params['B'][0,H-1,W-1,:]

    a_cout = params['A'][0,0,0,:]
    d = params['D']
    
    a_filled = fill_invalid_scg(a_cout,KW=KW,max_factor=max_factor, c=c)
    b_filled = fill_invalid_scg(b_cout_clr_mtb,KW=KW,max_factor=max_factor, c=c)
    ITR, EFF_CORES = a_filled.shape[0:2]

    '''
    * Filling happens in SCG order (natural disk order)
    * Repeat for maxpool
    * LRelu config are sent in [beats,CGM] order
    '''
    
    '''
    D beats = 1
    '''
    d_icgm = np.zeros((ITR,c.COPIES,c.GROUPS,c.MEMBERS//2), d.dtype)
    d_icgm[:,:,:,0] = d
    d_icgv = d_icgm.reshape(ITR,c.COPIES,c.GROUPS,c.MEMBERS//2)
    d_icgv_8 = np.frombuffer(d_icgv.tobytes(),np.int8).reshape(ITR,c.COPIES,c.GROUPS,c.MEMBERS)
    d_ibcgv_8 = d_icgv_8.reshape(ITR,1,c.COPIES,c.GROUPS,c.MEMBERS)

    '''
    A beats 
        3x3: 1 
        1x1: 2
    '''
    BEATS_A = ceil(2/KW)
    a_iscg = a_filled.reshape(ITR, SUB_CORES,1, c.COPIES//max_factor,c.GROUPS)
    a_iscg = np.repeat(a_iscg,repeats=max_factor,axis=2)
    a_iscg = a_iscg.reshape(ITR, SUB_CORES,c.COPIES,c.GROUPS)
    a_icgs = a_iscg.transpose(0,2,3,1)
    # 1x1: 2*12/2 = 12 ; 3x3: 1*12/2 = 6
    a_icgm = np.zeros((ITR,c.COPIES,c.GROUPS,BEATS_A*c.MEMBERS//2), a_icgs.dtype)
    # 1x1: 12 of 12 ; 3x3: 4 of 6
    a_icgm[:,:,:,0:SUB_CORES] = a_icgs
    # 1x1: (2,6) ; 3x3: (1,6)
    a_icgbv = a_icgm.reshape(ITR,c.COPIES,c.GROUPS,BEATS_A,c.MEMBERS//2)
    # 1x1: (2,12) ; 3x3: (1,12)
    a_icgbv_8 = np.frombuffer(a_icgbv.tobytes(),np.int8).reshape(ITR,c.COPIES,c.GROUPS,BEATS_A,c.MEMBERS)
    a_ibcgv_8 = a_icgbv_8.transpose(0,3,1,2,4)

    lrelu_config_list = [d_ibcgv_8, a_ibcgv_8]

    '''

    b_filled.shape = (COUT,KW,KH)
    
    ----EXAMPLE-----

        KW=KH=1
        MEMBERS=12
        SUB_CORES=12
            clr_i=0:
                clr=1
                mtb=0:
                    bram_width=12
                    bram_size=24
                    BEATS_ij=2
                    bram_size_pad=24
                    b_iscg_clri    : (ITR,12,C,G,1)  clri-0:1
                    b_izcg_clri    : (ITR,12,C,G,1)
                    b_icg_clri_z   : (ITR,C,G,1,12)
                    b_icg_clri_zv  : (ITR,C,G,1,12,2)
                    b_icg_clri_bw_v: (ITR,C,G,1,2,6,2)
                    b_ibcg_clri_wv : (ITR,2,C,G,1,6,2)
                    b_ibcg_v       : (ITR,2,C,G,12)

        KW=KH=3
        MEMBERS=12
        SUB_CORES=4

            clr_i=0:
                clr=1
                mtb=0:
                    bram_width=12
                    bram_size=8
                    BEATS_ij=1
                    bram_size_pad=12
                    b_iscg_clri    : (ITR,4,C,G,1)  clri-0:1
                    b_izcg_clri    : (ITR,6,C,G,1)
                    b_icg_clri_z   : (ITR,C,G,1,6)
                    b_icg_clri_zv  : (ITR,C,G,1,6,2)
                    b_icg_clri_bw_v: (ITR,C,G,1,1,6,2)
                    b_ibcg_clri_wv : (ITR,1,C,G,1,6,2)
                    b_ibcg_v       : (ITR,1,C,G,1,12)

            clr_i=1:
                clr=3
                mtb=0,1,2:
                    bram_width=4
                    bram_size=8
                    BEATS_ij=2
                    bram_size_pad=8
                    b_iscg_clri    : (ITR,4,C,G,3)  clri-0:3
                    b_izcg_clri    : (ITR,4,C,G,3)
                    b_icg_clri_z   : (ITR,C,G,3,4)
                    b_icg_clri_zv  : (ITR,C,G,3,4,2)
                    b_icg_clri_bw_v: (ITR,C,G,3,2,2,2)
                    b_ibcg_clri_wv : (ITR,2,C,G,3,2,2)
                    b_ibcg_v       : (ITR,2,C,G,12)
    '''
    b_iscg_clr_mtb = b_filled.reshape(ITR, SUB_CORES,1,c.COPIES//max_factor,c.GROUPS, KW,KH)
    b_iscg_clr_mtb = np.repeat(b_iscg_clr_mtb,repeats=max_factor,axis=2)
    b_iscg_clr_mtb = b_iscg_clr_mtb.reshape(ITR, SUB_CORES,c.COPIES,c.GROUPS,KW,KH)

    for clr_i in range(KW//2+1):
        clr = clr_i*2 +1
        for mtb in range(clr):

            bram_width = c.MEMBERS//clr
            bram_size  = 2*SUB_CORES
            BEATS_ij = ceil(bram_size/bram_width)

            bram_size_pad = BEATS_ij*bram_width

            b_iscg_clri = b_iscg_clr_mtb[..., 0:clr, mtb]
            b_izcg_clri = np.zeros((ITR,bram_size_pad//2,c.COPIES,c.GROUPS,clr),dtype=b_iscg_clri.dtype)
            b_izcg_clri[:,0:SUB_CORES,:,:,:] = b_iscg_clri
            
            b_icg_clri_z = b_izcg_clri.transpose(0,2,3,4,1)
            b_icg_clri_zv = np.frombuffer(b_icg_clri_z.tobytes(),np.int8).reshape(ITR,c.COPIES,c.GROUPS,clr,bram_size_pad//2,2)
            b_icg_clri_bw_v= b_icg_clri_zv.reshape(ITR,c.COPIES,c.GROUPS,clr,BEATS_ij,bram_width//2,2)
            b_ibcg_clri_wv = b_icg_clri_bw_v.transpose(0,4,1,2,3,5,6)
            b_icgbv = b_ibcg_clri_wv.reshape(ITR,BEATS_ij,c.COPIES,c.GROUPS,c.MEMBERS)

            lrelu_config_list += [b_icgbv]

    lrelu_config = np.concatenate(lrelu_config_list,axis=1)

    if KW == 3:
        assert lrelu_config.shape[1] == c.LRELU_BEATS_3x3
    elif KW == 1:
        assert lrelu_config.shape[1] == c.LRELU_BEATS_1x1
    else:
        pass

    print(f'lrelu_config: shape = (ITR,BEATS,c.COPIES,c.GROUPS,c.MEMBERS) = {lrelu_config.shape}')

    if get_params:
        return lrelu_config, {
            'd': d,
            'b_iscg_clr_mtb': b_iscg_clr_mtb,
            'a_iscg': a_iscg
        }
    else:
        return lrelu_config


def get_weights(i_layers, i_itr, c):

    SW = 1
    SH = 1

    weights = c.LAYERS[f'{c.PREFIX_CONV}{i_layers}'].weights

    KH, KW, CIN, COUT = weights.shape
    max_factor = 2 if f'{c.PREFIX_MAX}{i_layers}' in c.LAYERS.keys() else 1

    print(f"get_weights - shape_in:(KH, KW, CIN, COUT) = {weights.shape}")

    '''
    Reshape
    '''

    weights = weights.transpose(3,0,1,2) #(COUT,KH,KW,CIN)
    weights = fill_invalid_scg(weights,KW=KW,max_factor=max_factor,c=c) #(ITR,EFF_CORES,KH,KW,CIN)
    ITR,EFF_CORES = weights.shape[0:2]
    weights = weights.transpose(0,4,2,1,3) #(ITR,CIN,KH,EFF_CORES,KW)

    '''
    * Data comes out of maxpool in the order: S,CGU
    * Data comes out of conv in the order   : CGMU and is transposed into S,CGUby hardware
    * Conv in takes weights in order        : CGM

    * Since system_out is SCG, first invalid should be filled that way, so that output data is continous and cin matches cout
    * After filling, we transpose it to CGM
    '''

    SUB_CORES = c.MEMBERS//KW
    weights = weights.reshape((ITR,CIN,KH, SUB_CORES,c.COPIES//max_factor,c.GROUPS ,KW)) # EFF_CORES = (SCG)
    weights = weights.transpose(0,1,2, 4,5, 3,6) # CGS
    weights = weights.reshape((ITR,CIN,KH,1,c.COPIES//max_factor,c.GROUPS,SUB_CORES,KW)) # (CGS)
    weights = np.repeat(weights,repeats=max_factor,axis=3)
    weights = weights.reshape((ITR,CIN,KH,c.COPIES,c.GROUPS,SUB_CORES,KW))

    '''
    Temp, to solve the DW bank issue (M=12):
       RATIO =  KW_MAX/K
       SUB_CORES -> (RATIO,SUB_CORES/RATIO) -> (SUB_CORES/RATIO,RATIO)
    3: 4         -> (1,4)                    -> (4,1)
    1: 12        -> (3,4)                    -> (4,3)
    '''
    RATIO = c.KW_MAX//KW
    weights = weights.reshape((ITR,CIN,KH,c.COPIES,c.GROUPS,RATIO,SUB_CORES//RATIO,KW))
    weights = weights.transpose(0,1,2,3,4,6,5,7)
    weights = weights.reshape((ITR,CIN,KH,c.COPIES,c.GROUPS,SUB_CORES//RATIO,RATIO,KW))
    weights = weights.reshape((ITR,CIN,KH,c.COPIES,c.GROUPS,SUB_CORES,KW))

    weights = weights.reshape((ITR,CIN,KH,c.COPIES,c.GROUPS,SUB_CORES*KW))
    zeros = np.zeros((ITR,CIN,KH,c.COPIES,c.GROUPS,c.MEMBERS), dtype=weights.dtype)
    zeros[:,:,:,:,:,0:SUB_CORES*KW] = weights
    weights = zeros

    KERNEL_BEATS = CIN*KH
    weights = weights.reshape(ITR,KERNEL_BEATS,c.COPIES,c.GROUPS,c.MEMBERS)

    '''
    Add LRELU Beats
    '''
    lrelu = get_lrelu_config(i_layers=i_layers,c=c) 
        
    LRELU_BEATS = lrelu.shape[1]
    weights_beats = np.concatenate([lrelu,weights], axis=1) # (ITR, LRELU_BEATS + KERNEL_BEATS, COPIES, GROUPS, MEMBERS)

    '''
    c
    '''
    _,H,W,CIN = c.LAYERS[f'{c.PREFIX_CONV}{i_layers}'].in_data.shape
    BLOCKS    = H // (SH*max_factor*c.CONV_UNITS)

    BITS_KW2    = int(np.ceil(np.log2((c.KW_MAX+1)/2)))
    BITS_KH2    = int(np.ceil(np.log2((c.KH_MAX+1)/2)))
    BITS_SW     = int(np.ceil(np.log2(c.SW_MAX)))
    BITS_CIN_MAX    = int(np.ceil(np.log2(c.CIN_MAX   )))
    BITS_COLS_MAX   = int(np.ceil(np.log2(c.COLS_MAX  )))
    BITS_BLOCKS_MAX = int(np.ceil(np.log2(c.BLOCKS_MAX)))
    BITS_BRAM_WEIGHTS_ADDR = int(np.ceil(np.log2(c.BRAM_WEIGHTS_DEPTH)))

    bram_weights_addr_max = LRELU_BEATS + SW*KH*CIN-1
    print("bram_weights_addr_max: ", bram_weights_addr_max)
    print(BITS_KW2,BITS_KH2,BITS_SW,BITS_CIN_MAX,BITS_COLS_MAX,BITS_BLOCKS_MAX,BITS_BRAM_WEIGHTS_ADDR)

    weights_config = 0
    weights_config |= (KW//2)
    weights_config |= (KH//2)               << (BITS_KW2)
    weights_config |= SW-1                  << (BITS_KW2 + BITS_KH2)
    weights_config |= (CIN   -1)            << (BITS_KW2 + BITS_KH2 + BITS_SW)
    weights_config |= (W     -1)            << (BITS_KW2 + BITS_KH2 + BITS_SW + BITS_CIN_MAX)
    weights_config |= (BLOCKS-1)            << (BITS_KW2 + BITS_KH2 + BITS_SW + BITS_CIN_MAX + BITS_COLS_MAX)
    weights_config |= bram_weights_addr_max << (BITS_KW2 + BITS_KH2 + BITS_SW + BITS_CIN_MAX + BITS_COLS_MAX + BITS_BLOCKS_MAX)

    weights_config = np.frombuffer(np.uint64(weights_config).tobytes(),np.int8)
    weights_config = np.repeat(weights_config[np.newaxis,...],repeats=ITR,axis=0)

    '''
    ADD c BEATS
    '''
    weights_dma_beats = np.concatenate([weights_config,weights_beats.reshape(ITR,-1)], axis=1)

    assert weights_dma_beats.shape == (ITR, 8 + (LRELU_BEATS + CIN*KH*SW)*c.COPIES*c.GROUPS*c.MEMBERS)
    print(f"get_weights - weights_dma_beats.shape: (ITR, 4 + (LRELU_BEATS + CIN*KH)*COPIES*GROUPS*MEMBERS) = {weights_dma_beats.shape}")

    np.savetxt(f"{c.DATA_DIR}{i_layers}_weights.txt", weights_dma_beats[i_itr].flatten(), fmt='%d')

    return weights_dma_beats


def reshape_conv_in(i_layers, c):

    SH = 1

    image = c.LAYERS[f'{c.PREFIX_CONV}{i_layers}'].in_data[0]
    max_factor = 2 if f'{c.PREFIX_MAX}{i_layers}' in c.LAYERS else 1
    H,W,CIN = image.shape

    print(f'reshape_conv_in - in_shape: (H,W,CIN) = ({image.shape})')

    BLOCK_HEIGHT = max_factor*c.CONV_UNITS*SH
    BLOCKS = H//BLOCK_HEIGHT
    assert H % BLOCK_HEIGHT == 0
    KH         = c.LAYERS[f'{c.PREFIX_CONV}{i_layers}'].weights.shape[0]             
    KW         = c.LAYERS[f'{c.PREFIX_CONV}{i_layers}'].weights.shape[1]             

    image = image.reshape(BLOCKS,BLOCK_HEIGHT,W,CIN)

    '''(BLOCKS,SH(MR+F),W,CIN)'''
    SHIFT = int(np.ceil(KH/SH)-1)
    WORDS = max_factor*c.CONV_UNITS + SHIFT

    zeros = np.zeros((BLOCKS,SH*WORDS,W,CIN),image.dtype)
    top_edges = KH//2
    bot_edges = SH*WORDS - top_edges - BLOCK_HEIGHT

    zeros[:,top_edges:SH*WORDS-bot_edges,:,:] = image

    for l in range(BLOCKS):
        ''' Fill top rows from prev '''
        if l == 0:
            zeros[l,:top_edges,:,:] = np.zeros((1,top_edges,W,CIN),image.dtype)
        else:
            zeros[l,:top_edges,:,:] = image[l-1,BLOCK_HEIGHT-top_edges:,:,:]

        ''' Fill bot rows from next '''
        if l == BLOCKS-1:
            zeros[l,SH*WORDS-bot_edges:,:,:] = np.zeros((1,bot_edges,W,CIN),image.dtype)
        else:
            zeros[l,SH*WORDS-bot_edges:,:,:] = image[l+1,:bot_edges,:,:]
    image = zeros

    '''(BLOCKS,W,CIN,SH,MR+F)'''
    image = image.reshape(BLOCKS,WORDS,SH,W,CIN)
    image = image.transpose(0,3,4,2,1)

    print(f'reshape_conv_in - image_out.shape: (BLOCKS,W,CIN,SH,max*UNITS+shift) = {image.shape}')

    '''
    Config
    '''
    BITS_KW2 = int(np.ceil(np.log2((c.KW_MAX+1)/2)))
    BITS_KH2 = int(np.ceil(np.log2((c.KH_MAX+1)/2))) 
    BITS_SH  = int(np.ceil(np.log2(c.SW_MAX)))

    is_max     = max_factor != 1
    is_not_max = max_factor == 1
    is_relu    = f'{c.PREFIX_LRELU}{i_layers}' in c.LAYERS

    config = 0
    config |= is_not_max
    config |= is_max  << 1
    config |= is_relu << 2
    config |= (KH//2) << 3
    config |= (KW//2) << 3 + BITS_KH2
    config |= (SH-1 ) << 3 + BITS_KH2 + BITS_KW2
    config |= WORDS   << 3 + BITS_KH2 + BITS_KW2 + BITS_SH

    im_data = np.concatenate([np.frombuffer(np.array(config, dtype=np.uint64).tobytes(), np.uint8), image.flatten()])

    print(f'im_data.size = image.size + 8: {im_data.shape}')

    np.savetxt(f"{c.DATA_DIR}{i_layers}_conv_input.txt", im_data.flatten(), fmt='%d')

    return im_data, (BLOCKS,W,CIN,SH,WORDS)

def fpga_mwr_weights(i_layers,c, i_itr=None):

    '''
    Get weights, flatten, write to bin, generate cmd
    '''
    weights = get_weights(i_layers,i_itr=i_itr, c=c).flatten()  
    w_path = f"{c.DATA_DIR}{i_layers}_weights.bin"
    weights.tofile(w_path)

    cmd_txt = f"mwr -bin -file {w_path} {c.ADDR_WEIGHTS} {int(np.ceil(weights.size/4))}; "

    return cmd_txt

def fpga_mwr_image_in(i_layers,c):
    '''
    Get im_arrays, flatten, pad by 4, write to bin, generate cmd
    '''
    im_arrays, shape = reshape_conv_in(i_layers,c)
    im_flat_unpadded = np.concatenate([arr.flatten() for arr in im_arrays])

    im_file_size = int(np.ceil(im_flat_unpadded.size/4))*4
    im_flat = np.zeros(im_file_size, im_flat_unpadded.dtype)
    im_flat[:im_flat_unpadded.size] = im_flat_unpadded

    im_path = f"{c.DATA_DIR}{i_layers}_conv_in.bin"
    im_flat.tofile(im_path)

    cmd_txt = f"mwr -bin -file {im_path} {c.ADDR_IN} {im_file_size//4}; "

    # print('\n', 'FPGA Memory Write Command: ', cmd_txt,'\n')
    return cmd_txt


def fpga_mwr_weights_all(c):

    weights_all = []
    num_conv_layers = len([layer for key,layer in c.LAYERS.items() if 'conv' in key])

    for k in range(1, num_conv_layers+1):
        weights_all += [get_weights(k,i_itr=None,c=c).flatten()]

    weights_all = np.concatenate(weights_all)

    print(f"\nSize (bytes): {weights_all.size}; MB: {weights_all.size/1024/1024:.2f} \n")

    w_all_path = f"{c.DATA_DIR}weights_all.bin"
    weights_all.tofile(w_all_path)

    cmd_txt = f"mwr -bin -file {w_all_path} {c.ADDR_WEIGHTS} {int(np.ceil(weights_all.size/4))}; "

    return cmd_txt


def reshape_image_out(image,order,KW,max_factor,c,copy_factor=1,flip_cols=True):
    assert order == 'scg' or order == 'cgs'

    H,W,COUT = image.shape
    BLOCKS = H//c.CONV_UNITS
    assert H % c.CONV_UNITS == 0
    assert BLOCKS % max_factor == 0
    
    '''Flip last cols to imitate conv'''
    if flip_cols and KW != 1:
        image = np.concatenate([image[:,:-(KW-1),:], np.flip(image[:,-(KW-1):,:],axis=1)],axis=1)

    image = image.reshape((BLOCKS//max_factor,max_factor,c.CONV_UNITS,W,COUT))
    image = image.transpose(4,0,3,1,2) #(COUT,BLOCKS_PER_ARR,W,max_factor,CONV_UNITS)
    image = fill_invalid_scg(image,KW=KW,max_factor=max_factor,copy_factor=copy_factor,c=c)
    ITR, EFF_CORES,BLOCKS_PER_ARR, W, max_factor, CONV_UNITS = image.shape

    '''
    SCG vs CGS

    * There are CG cores. EFF_CORES channels are calculated in parallel
    * Data comes out from conv in SCG configuration
    * If max, in C place, two blocks of the image come out. Else, two channels

    * To generalize: eff_c = 2//max_factor
        - By keeping eff_c and max_factor dimensions next to each other, the output behavior is guaranteed
        - if     max: eff_c = 1, max_factor = 2, that dim has 2 blocks
        - if not max: eff_c = 2, max_factor = 1, that dim has 2 channels
    '''
    eff_c  = c.COPIES//max_factor//copy_factor
    SUB_CORES = c.MEMBERS//KW
    image = image.reshape(ITR, SUB_CORES,eff_c,c.GROUPS, BLOCKS_PER_ARR,W,max_factor,c.CONV_UNITS) # (EFF_CORES -> SMCG)

    if order == 'scg':
        image = image.transpose(0,4,5,1, 2,6,3, 7) #(ITR,BLOCKS_PER_ARR,W,SUB_CORES, eff_c,max_factor,GROUPS, CONV_UNITS)
        return image.reshape(ITR,BLOCKS_PER_ARR,W,SUB_CORES, c.CORES//copy_factor, c.CONV_UNITS)
    elif order == 'cgs':
        image = image.transpose(0,4,5, 2,6,3,1, 7) #(ITR,BLOCKS_PER_ARR,W, eff_c,max_factor,MEMBERS,GROUPS,SUB_CORES, CONV_UNITS)
        return image.reshape(ITR,BLOCKS_PER_ARR,W, c.CORES//copy_factor,SUB_CORES, c.CONV_UNITS)
    else:
        print("ERROR: only scg or cgs")

def make_conv_out(i_layers,i_itr,c):

    max_factor = 2 if f'{c.PREFIX_MAX}{i_layers}' in c.LAYERS.keys() else 1

    image = c.LAYERS[f'{c.PREFIX_CONV}{i_layers}'].np_out_data[0]
    KW    = c.LAYERS[f'{c.PREFIX_CONV}{i_layers}'].weights.shape[0]

    conv_image = reshape_image_out(image=image,order='scg',KW=KW,max_factor=max_factor,c=c)
    ITR,BLOCKS_PER_ARR,W,SUB_CORES,CORES,CONV_UNITS = conv_image.shape
    image = conv_image.reshape(ITR,BLOCKS_PER_ARR,W,SUB_CORES,c.COPIES,c.GROUPS,c.CONV_UNITS)
    # zeros = np.zeros((ITR,DATA_BEATS,c.COPIES,c.GROUPS,c.MEMBERS,c.CONV_UNITS),dtype=image.dtype)
    # zeros[:,:,:,:,0:SUB_CORES,:] = image
    # image = zeros

    '''
    Concat Lrelu config
    '''
    lrelu_config = get_lrelu_config(i_layers,c)
    #(ITR,BEATS,c.COPIES,c.GROUPS,c.MEMBERS)

    ITR,LRELU_BEATS,COPIES,GROUPS,MEMBERS = lrelu_config.shape
    lrelu_config_padded = np.zeros((ITR,LRELU_BEATS,COPIES,GROUPS,MEMBERS,c.CONV_UNITS),lrelu_config.dtype)
    lrelu_config_padded[...,0] = lrelu_config[...]

    assert lrelu_config_padded.shape == (ITR,LRELU_BEATS,COPIES,GROUPS,MEMBERS,c.CONV_UNITS)
    print(f"lrelu_config.shape: (ITR,LRELU_BEATS,COPIES,GROUPS,MEMBERS,CONV_UNITS) = {lrelu_config_padded.shape}")

    assert image.shape == (ITR,BLOCKS_PER_ARR,W,SUB_CORES,c.COPIES,c.GROUPS,c.CONV_UNITS)
    print(f"image.shape: (ITR,BLOCKS,W,SUB_CORES,COPIES,GROUPS,CONV_UNITS) = {image.shape}")

    conv_out_i = np.concatenate([lrelu_config_padded[i_itr].flatten(), image[i_itr].flatten()])
    np.savetxt(f"{c.DATA_DIR}/{i_layers}_conv_out.txt", conv_out_i, fmt='%d')

    return lrelu_config_padded, image, conv_out_i

def make_lrelu_out(i_layers,c):
    image = c.LAYERS[f'{c.PREFIX_LRELU}{i_layers}'].np_out_data[0]
    max_factor = 2 if f'{c.PREFIX_MAX}{i_layers}' in c.LAYERS else 1
    KW    = c.LAYERS[f'{c.PREFIX_CONV}{i_layers}'].weights.shape[0]

    lrelu_out = reshape_image_out(image=image,order='scg',KW=KW,max_factor=max_factor,c=c)
    ITR,BLOCKS_PER_ARR,W,SUB_CORES,CORES,CONV_UNITS = lrelu_out.shape
    lrelu_out = lrelu_out.reshape(ITR,BLOCKS_PER_ARR,W,SUB_CORES,c.COPIES,c.GROUPS,CONV_UNITS)
    print(f"Leaky relu out: (ITR,BLOCKS_PER_ARR,W,SUB_CORES,COPIES,GROUPS,CONV_UNITS) = {lrelu_out.shape}")

    return lrelu_out

def make_accl_out(i_layers,c):

    copy_factor = 1
    flip_cols = True

    if f'{c.PREFIX_MAX}{i_layers}' in c.LAYERS:
        copy_factor = 2
        flip_cols = False
        image = c.LAYERS[f'{c.PREFIX_MAX}{i_layers}'].np_out_data[0]
    elif f'{c.PREFIX_LRELU}{i_layers}' in c.LAYERS:
        image = c.LAYERS[f'{c.PREFIX_LRELU}{i_layers}'].np_out_data[0]
    else:
        image = c.LAYERS[f'{c.PREFIX_CONV}{i_layers}'].np_out_data[0]

    KW    = c.LAYERS[f'{c.PREFIX_CONV}{i_layers}'].weights.shape[0]

    '''Force max_factor=1, since output is always one set of blocks'''
    accl_out = reshape_image_out(image=image,order='scg',KW=KW,max_factor=1,copy_factor=copy_factor,flip_cols= flip_cols,c=c)

    ITR,BLOCKS_PER_ARR,W,SUB_CORES,_,CONV_UNITS = accl_out.shape
    accl_out_padded = np.pad(accl_out,((0,0),(0,0),(0,0),(0,0),(0,0),(c.KH_MAX//2,c.KH_MAX//2)),mode='constant')

    print(f"Make accl out - (ITR,BLOCKS_PER_ARR,W,SUB_CORES,EFF_CORES,UNITS_EDGES) = {accl_out_padded.shape}")

    return accl_out_padded

def make_fpga_out(i_layers,c):

    if i_layers == 21:
        np_out = c.LAYERS[f'{c.PREFIX_CONV}{i_layers}'].quant_out_data[0]

        H, W, COUT = np_out.shape
        BLOCKS = H//c.CONV_UNITS
        np_out = np_out.reshape(BLOCKS, c.CONV_UNITS, W, COUT)
        np_out = np_out.transpose(0,2,3,1)
        np_out_zeros = np.zeros((BLOCKS,W,COUT,c.UNITS_EDGES),np_out.dtype)
        np_out_zeros[:,:,:,c.KH_MAX//2:c.CONV_UNITS+c.KH_MAX//2] = np_out
        im_arrays_out = np.concatenate([np.zeros((1,c.UNITS_EDGES),np_out.dtype), np_out_zeros.reshape(BLOCKS*W*COUT,c.UNITS_EDGES)],axis=0)
        im_arrays_out = im_arrays_out[np.newaxis,:]
        out_shape = im_arrays_out.shape
        print("Last Layer")
    else:
        im_arrays_out, out_shape = reshape_conv_in(i_layers+1,c)
        
    next_max_factor = len(im_arrays_out)

    if i_layers == 21:
        _, next_h, next_w, next_cin = c.LAYERS[f'{c.PREFIX_CONV}{i_layers}'].quant_out_data.shape
    else:
        _, next_h, next_w, next_cin = c.LAYERS[f'{c.PREFIX_CONV}{i_layers+1}'].in_data.shape

    next_blocks = next_h//c.CONV_UNITS
    next_shape = next_max_factor, next_blocks//next_max_factor, next_w, next_cin, c.UNITS_EDGES

    eq_arrays = []
    for m, arr in enumerate(im_arrays_out):
        if m == 0:
            eq_arrays += [arr.flatten()[c.UNITS_EDGES:]]
        else:
            eq_arrays += [arr.flatten()]

    im_out = np.concatenate(eq_arrays).reshape(next_shape)
    next_config = im_arrays_out[0].flatten()[:c.UNITS_EDGES]

    print("Config Pattern: ", next_config)
    print(f"Layer {i_layers} - fpga_accl_out.shape = {next_shape}")

    return next_config, im_out