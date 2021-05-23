import numpy as np 
from dataclasses import dataclass, field

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
    CIN_MAX    :int 
    COLS_MAX   :int 

    ADDR_WEIGHTS : str
    ADDR_IN_LUT  : str
    ADDR_IN  : str
    ADDR_OUT : str

    RGB_H : int
    RGB_W : int

    BLOCKS_MAX  :int = 0
    UNITS_EDGES :int = 0
    CORES       :int = 0

    def __post_init__(self):
        super().__setattr__('BLOCKS_MAX', self.COLS_MAX//self.CONV_UNITS)
        super().__setattr__('UNITS_EDGES', self.CONV_UNITS + self.KH_MAX-1)
        super().__setattr__('CORES', self.MEMBERS*self.COPIES*self.GROUPS)

        assert self.KH_MAX  % 2 == 1
        assert self.MEMBERS % 2 == 0


def fill_invalid_smcg(arr, KW, max_factor, c, copy_factor=1):
    '''
    Input  shape: (COUT,...)
    Output shape: (ITR,EFF_CORES,...)

    System out is in SMCG form. Hence by default we fill invalid in that form
    '''
    input_shape = arr.shape

    CORES = c.CORES//copy_factor

    COUT = input_shape[0]
    SUB_CORES = c.KW_MAX//KW
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


    arr_filled = arr_filled.reshape([ITR,EFF_CORES]+shape_fpga[1:]) # EFF_CORES = (CMGS)

    print(f'Filling invalid smcg - in_shape: {input_shape}, out_shape{arr_filled.shape}')

    return arr_filled


def get_lrelu_config(i_layers, c, get_params=False):
    '''
    LRelu config are accepted in (beats,CGM) format
    * Say M = 4, S = 3
    * Each CG needs 
        - SM   =12 words of float16
        - SM*2 =24 words of int8
    * But are written horizontally into memory
    * SM*2 (=24) words are flattened, broken into M (=4) per beat in parallel, as B (=6) beats
    * M dimension contains M/2 (=2) float16 words broken as M (=4) int8 words
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
    SUB_CORES = c.KW_MAX//KW

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
    
    a_filled = fill_invalid_smcg(a_cout,KW=KW,max_factor=max_factor, c=c)
    b_filled = fill_invalid_smcg(b_cout_clr_mtb,KW=KW,max_factor=max_factor, c=c)
    ITR, EFF_CORES = a_filled.shape[0:2]

    '''
    * Filling happens in SMCG order (natural disk order)
    * Repeat for maxpool
    * LRelu config are sent in S,CMG order
    '''

    a_ismcg = a_filled.reshape(ITR, SUB_CORES, c.MEMBERS,1, c.COPIES//max_factor,c.GROUPS)
    a_ismcg = np.repeat(a_ismcg,repeats=max_factor,axis=3)
    a_ismcg = a_ismcg.reshape(ITR, SUB_CORES,c.MEMBERS,c.COPIES,c.GROUPS)

    b_ismcg_clr_mtb = b_filled.reshape(ITR, SUB_CORES,c.MEMBERS,1,c.COPIES//max_factor,c.GROUPS, KW,KH)
    b_ismcg_clr_mtb = np.repeat(b_ismcg_clr_mtb,repeats=max_factor,axis=3)
    b_ismcg_clr_mtb = b_ismcg_clr_mtb.reshape(ITR, SUB_CORES,c.MEMBERS,c.COPIES,c.GROUPS,KW,KH)

    def append_lrelu_config(arr,config_mcg,is_one_beat=False):
        BEATS = 16 // c.WORD_WIDTH_CONFIG;
        VALS_CONFIG = c.MEMBERS // BEATS;

        assert config_mcg.shape == (c.MEMBERS,c.COPIES,c.GROUPS)
        config_cgm = config_mcg.transpose((1,2,0))
        config_cgbv = config_cgm.reshape((c.COPIES, c.GROUPS, BEATS, VALS_CONFIG))
        config_bcgv = config_cgbv.transpose(2,0,1,3)
        
        BEATS_TO_SEND = BEATS
        if is_one_beat:
            config_bcgv = config_bcgv[0][np.newaxis,...]
            BEATS_TO_SEND = 1

        config_8_bcgm = np.frombuffer(config_bcgv.tobytes(), np.int8).reshape((BEATS_TO_SEND,c.COPIES,c.GROUPS,c.MEMBERS))
        config_pad_bcgmk = np.zeros((BEATS_TO_SEND,c.COPIES,c.GROUPS,c.MEMBERS,c.KW_MAX), config_8_bcgm.dtype)
        config_pad_bcgmk[...,0] = config_8_bcgm.astype(np.int8)
        arr += [list(config_pad_bcgmk.reshape(BEATS_TO_SEND,c.CORES,c.KW_MAX))]
    

    '''
    Append D, A, B
    '''
    lrelu_config = []

    for itr in range(ITR):
        lrelu_config_itr = []

        ''' d '''
        append_lrelu_config(lrelu_config_itr,d*np.ones((c.MEMBERS,c.COPIES,c.GROUPS),np.float16), is_one_beat=True)

        ''' a '''
        for s in range(SUB_CORES):
            append_lrelu_config(lrelu_config_itr,a_ismcg[itr,s])

        ''' b '''
        for s in range(SUB_CORES):
            for clr in range(KW):
                for mtb in range(KH):
                    append_lrelu_config(lrelu_config_itr, b_ismcg_clr_mtb[itr,s,:,:,:,clr,mtb])

        lrelu_config_itr = np.concatenate(lrelu_config_itr,axis=0) #(BEATS,CORES,KW_MAX)
        
        lrelu_config += [lrelu_config_itr] #(ITR)

    lrelu_config = np.array(lrelu_config) # (ITR,LRELU_BEATS,CORES,KW_MAX)
    print(f'lrelu_config: shape = (ITR,LRELU_BEATS,CORES,KW_MAX) = {lrelu_config.shape}')

    if get_params:
        return lrelu_config, {
            'd': d,
            'b_ismcg_clr_mtb': b_ismcg_clr_mtb,
            'a_ismcg': a_ismcg
        }
    else:
        return lrelu_config


def get_weights(i_layers, i_itr, c):

    weights = c.LAYERS[f'{c.PREFIX_CONV}{i_layers}'].weights

    KH, KW, CIN, COUT = weights.shape
    max_factor = 2 if f'{c.PREFIX_MAX}{i_layers}' in c.LAYERS.keys() else 1

    print(f"get_weights - shape_in:(KH, KW, CIN, COUT) = {weights.shape}")

    '''
    Reshape
    '''

    weights = weights.transpose(3,0,1,2) #(COUT,KH,KW,CIN)
    weights = fill_invalid_smcg(weights,KW=KW,max_factor=max_factor,c=c) #(ITR,EFF_CORES,KH,KW,CIN)
    ITR,EFF_CORES = weights.shape[0:2]
    weights = weights.transpose(0,4,2,1,3) #(ITR,CIN,KH,EFF_CORES,KW)

    '''
    * Data comes out of maxpool in the order: SM,CGU
    * Data comes out of conv in the order   : S,CMGU and is transposed into S,MCGUby hardware
    * Conv in takes weights in order        : CMGS

    * Since system_out is SMCG, first invalid should be filled that way, so that output data is continous and cin matches cout
    * After filling, we transpose it to CMGS
    '''

    SUB_CORES = c.KW_MAX//KW
    weights = weights.reshape((ITR,CIN,KH, SUB_CORES,c.MEMBERS,c.COPIES//max_factor,c.GROUPS ,KW)) # EFF_CORES = (SMCG)
    weights = weights.transpose(0,1,2, 5,4,6, 3,7) # CMGS
    weights = weights.reshape((ITR,CIN,KH,1,c.COPIES//max_factor,c.MEMBERS,c.GROUPS,c.KW_MAX)) # (CMGS)
    weights = np.repeat(weights,repeats=max_factor,axis=3)
    weights = weights.reshape((ITR,CIN,KH,c.CORES,c.KW_MAX))

    KERNEL_BEATS = CIN*KH
    weights = weights.reshape(ITR,KERNEL_BEATS,c.CORES,c.KW_MAX)

    '''
    Add LRELU Beats
    '''
    lrelu = get_lrelu_config(i_layers=i_layers,c=c) 
        
    LRELU_BEATS = lrelu.shape[1]
    weights_beats = np.concatenate([lrelu,weights], axis=1) # (ITR, LRELU_BEATS + KERNEL_BEATS, CORES, KW_MAX)

    '''
    c
    '''
    _,H,W,CIN = c.LAYERS[f'{c.PREFIX_CONV}{i_layers}'].in_data.shape
    BLOCKS    = H // c.CONV_UNITS
    BLOCKS_PER_ARR = BLOCKS // max_factor

    BITS_KW_MAX     = int(np.ceil(np.log2(c.KW_MAX    )))
    BITS_KH_MAX     = int(np.ceil(np.log2(c.KH_MAX    )))
    BITS_CIN_MAX    = int(np.ceil(np.log2(c.CIN_MAX   )))
    BITS_COLS_MAX   = int(np.ceil(np.log2(c.COLS_MAX  )))
    BITS_BLOCKS_MAX = int(np.ceil(np.log2(c.BLOCKS_MAX)))

    weights_config = 0
    weights_config |= (KW    -1)
    weights_config |= (KH    -1) << (BITS_KW_MAX)
    weights_config |= (CIN   -1) << (BITS_KW_MAX + BITS_KH_MAX)
    weights_config |= (W     -1) << (BITS_KW_MAX + BITS_KH_MAX + BITS_CIN_MAX)
    weights_config |= (BLOCKS_PER_ARR-1) << (BITS_KW_MAX + BITS_KH_MAX + BITS_CIN_MAX + BITS_COLS_MAX)
    weights_config = np.frombuffer(np.int32(weights_config).tobytes(),np.int8)
    weights_config = np.repeat(weights_config[np.newaxis,...],repeats=ITR,axis=0)

    '''
    ADD c BEATS
    '''
    weights_dma_beats = np.concatenate([weights_config,weights_beats.reshape(ITR,-1)], axis=1)

    assert weights_dma_beats.shape == (ITR, 4 + (LRELU_BEATS + CIN*KH)*c.CORES*c.KW_MAX)
    print(f"get_weights - weights_dma_beats.shape: (ITR, 4 + (LRELU_BEATS + CIN*KH)*CORES*KW_MAX) = {weights_dma_beats.shape}")

    np.savetxt(f"{c.DATA_DIR}{i_layers}_weights.txt", weights_dma_beats[i_itr].flatten(), fmt='%d')

    return weights_dma_beats


def reshape_conv_in(i_layers, c):

    image = c.LAYERS[f'{c.PREFIX_CONV}{i_layers}'].in_data[0]
    max_factor = 2 if f'{c.PREFIX_MAX}{i_layers}' in c.LAYERS else 1
    H,W,CIN = image.shape

    print(f'reshape_conv_in - in_shape: (H,W,CIN) = ({image.shape})')

    BLOCKS = H//c.CONV_UNITS
    assert H % c.CONV_UNITS == 0
    assert BLOCKS % max_factor == 0

    IS_LRELU   = f'{c.PREFIX_LRELU}{i_layers}' in c.LAYERS
    KH         = c.LAYERS[f'{c.PREFIX_CONV}{i_layers}'].weights.shape[0]             

    image = np.pad(image, ((c.KH_MAX//2, c.KH_MAX//2), (0, 0), (0, 0)), mode='constant')

    im_arrays = []
    for m in range(max_factor):
        im_arrays += [np.zeros([BLOCKS//max_factor, W, CIN, c.UNITS_EDGES], image.dtype)]

    REMOVE_PAD = c.KH_MAX//2 - KH//2
    for b in range(BLOCKS):
        h_index_start = b*c.CONV_UNITS
        h_index_end   = h_index_start + c.UNITS_EDGES
        block = image[h_index_start:h_index_end,:,:] # padding with prev & next block
        block = block.transpose([1, 2, 0]) # (H,W,C) -> (W,C,H)

        '''
        Zero out unnessasary padding
        '''
        block = np.copy(block)
        block[:,:,:REMOVE_PAD] = 0
        block[:,:,c.UNITS_EDGES-REMOVE_PAD:] = 0

        im_array_index = b %  max_factor
        blocks_index   = b // max_factor
        im_arrays[im_array_index][blocks_index] = block

    '''
    Config
    '''
    IS_MAX     = max_factor != 1
    IS_NOT_MAX = max_factor == 1

    assert c.UNITS_EDGES >= 4
    config = np.zeros((c.UNITS_EDGES),np.int8)
    config[0] = IS_NOT_MAX
    config[1] = IS_MAX
    config[2] = IS_LRELU
    config[3] = KH-1

    im_arrays[0] = np.concatenate([config [np.newaxis,:], im_arrays[0].reshape(BLOCKS//max_factor*W*CIN, c.UNITS_EDGES)], axis=0)

    print(f'reshape_conv_in - output im_arrays[0]: (1 + BLOCKS/max_factor * W * CIN, UNITS_EDGES) = {im_arrays[0].shape}')

    for i in range(1,max_factor-1):
        print(f"im_arrays[i]: {BLOCKS//max_factor, W, CIN, c.UNITS_EDGES} = {im_arrays[i].shape}")

    for m in range(max_factor):
        np.savetxt(f"{c.DATA_DIR}{i_layers}_conv_in_{m}.txt", im_arrays[m].flatten(), fmt='%d')

    return im_arrays, (BLOCKS,max_factor,W,CIN, c.UNITS_EDGES)


def fpga_mwr_weights(i_layers,c):

    '''
    Get weights, flatten, write to bin, generate cmd
    '''
    weights = get_weights(i_layers,i_itr=None, c=c).flatten()  
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
    assert order == 'cmg' or order == 'mcg'

    H,W,COUT = image.shape
    BLOCKS = H//c.CONV_UNITS
    assert H % c.CONV_UNITS == 0
    assert BLOCKS % max_factor == 0
    
    '''Flip last cols to imitate conv'''
    if flip_cols and KW != 1:
        image = np.concatenate([image[:,:-(KW-1),:], np.flip(image[:,-(KW-1):,:],axis=1)],axis=1)

    image = image.reshape((BLOCKS//max_factor,max_factor,c.CONV_UNITS,W,COUT))
    image = image.transpose(4,0,3,1,2) #(COUT,BLOCKS_PER_ARR,W,max_factor,CONV_UNITS)
    image = fill_invalid_smcg(image,KW=KW,max_factor=max_factor,copy_factor=copy_factor,c=c)
    ITR, EFF_CORES,BLOCKS_PER_ARR, W, max_factor, CONV_UNITS = image.shape

    '''
    MCG vs CMG

    * There are CORES cores. EFF_CORES channels are calculated in parallel
    * Data comes out from conv in SCMG configuration
    * If max, in C place, two blocks of the image come out. Else, two channels

    * To generalize: eff_c = 2//max_factor
        - By keeping eff_c and max_factor dimensions next to each other, the output behavior is guaranteed
        - if     max: eff_c = 1, max_factor = 2, that dim has 2 blocks
        - if not max: eff_c = 2, max_factor = 1, that dim has 2 channels
    '''
    eff_c  = 2//max_factor//copy_factor
    SUB_CORES = c.KW_MAX//KW
    image = image.reshape(ITR, SUB_CORES,c.MEMBERS,eff_c,c.GROUPS, BLOCKS_PER_ARR,W,max_factor,c.CONV_UNITS) # (EFF_CORES -> SMCG)

    if order == 'mcg':
        image = image.transpose(0,5,6,1, 2,3,7,4, 8) #(ITR,BLOCKS_PER_ARR,W,SUB_CORES, MEMBERS,eff_c,max_factor,GROUPS, CONV_UNITS)
    if order == 'cmg':
        image = image.transpose(0,5,6,1, 3,7,2,4, 8) #(ITR,BLOCKS_PER_ARR,W,SUB_CORES, eff_c,max_factor,MEMBERS,GROUPS, CONV_UNITS)
    return image.reshape(ITR,BLOCKS_PER_ARR,W,SUB_CORES, c.CORES//copy_factor, c.CONV_UNITS)

def make_conv_out(i_layers,i_itr,c):

    max_factor = 2 if f'{c.PREFIX_MAX}{i_layers}' in c.LAYERS.keys() else 1

    image = c.LAYERS[f'{c.PREFIX_CONV}{i_layers}'].np_out_data[0]
    KW    = c.LAYERS[f'{c.PREFIX_CONV}{i_layers}'].weights.shape[0]

    conv_image = reshape_image_out(image=image,order='cmg',KW=KW,max_factor=max_factor,c=c)
    ITR,BLOCKS_PER_ARR,W,SUB_CORES,CORES,CONV_UNITS = conv_image.shape
    DATA_BEATS = BLOCKS_PER_ARR*W*SUB_CORES
    image = conv_image.reshape(ITR,DATA_BEATS,c.CORES,c.CONV_UNITS)

    '''
    Concat Lrelu config
    '''
    lrelu_config = get_lrelu_config(i_layers,c)
    #(ITR,LRELU_BEATS,CORES)

    ITR,LRELU_BEATS,CORES,KW_MAX = lrelu_config.shape
    lrelu_config_padded = np.zeros((ITR,LRELU_BEATS,c.CORES,c.CONV_UNITS),lrelu_config.dtype)
    lrelu_config_padded[...,0] = lrelu_config[...,0]

    image_out = np.concatenate([lrelu_config_padded,image],axis=1)

    assert image_out.shape == (ITR, (21 if KW==3 else 13) + BLOCKS_PER_ARR*W*SUB_CORES, c.COPIES*c.MEMBERS*c.GROUPS,c.CONV_UNITS)

    print(f"image_out.shape: (ITR, {21 if KW==3 else 13} + BLOCKS_PER_ARR*W*SUB_CORES, COPIES*MEMBERS*GROUPS,CONV_UNITS) = {image_out.shape}")

    np.savetxt(f"{c.DATA_DIR}/{i_layers}_conv_out.txt", image_out[i_itr].flatten(), fmt='%d')

    return image_out

def make_lrelu_out(i_layers,c):
    image = c.LAYERS[f'{c.PREFIX_LRELU}{i_layers}'].np_out_data[0]
    max_factor = 2 if f'{c.PREFIX_MAX}{i_layers}' in c.LAYERS else 1
    KW    = c.LAYERS[f'{c.PREFIX_CONV}{i_layers}'].weights.shape[0]

    lrelu_out = reshape_image_out(image=image,order='mcg',KW=KW,max_factor=max_factor,c=c)
    print(f"Leaky relu out: (ITR,BLOCKS_PER_ARR,W,SUB_CORES,CORES,CONV_UNITS) = {lrelu_out.shape}")

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
    accl_out = reshape_image_out(image=image,order='mcg',KW=KW,max_factor=1,copy_factor=copy_factor,flip_cols= flip_cols,c=c)

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