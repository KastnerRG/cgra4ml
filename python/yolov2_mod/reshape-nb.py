# To add a new cell, type '# %%'
# To add a new markdown cell, type '# %% [markdown]'
# %%
import numpy as np 
import pickle
from yolov2_mod_numpy import YOLOv2_Modified_Numpy

layers = pickle.load(open('yolov2_mod_int8_dict.pickle', 'rb'))

i = 3

CONV_UNITS = 4
MEMBERS    = 4
COPIES     = 2
GROUPS     = 2
CORES      = MEMBERS*COPIES*GROUPS
WORD_WIDTH_CONFIG = 8

prefix_conv = 'conv_'
prefix_max = 'maxpool_'
prefix_lrelu = 'leaky_relu_'

KW_MAX     = 3
KH_MAX     = 3
CIN_MAX    = 1024
COLS_MAX   = 384
BLOCKS_MAX = COLS_MAX//CONV_UNITS
UNITS_EDGES = CONV_UNITS + KH_MAX-1

assert KH_MAX  % 2 == 1
assert MEMBERS % 2 == 0

path = '../../data'


# %%
def fill_invalid_smcg(arr, KW, KW_MAX, CORES, max_factor):
    '''
    Input  shape: (COUT,...)
    Output shape: (ITR,EFF_CORES,...)

    System out is in SMCG form. Hence by default we fill invalid in that form
    '''

    COUT = arr.shape[0]
    SUB_CORES = KW_MAX//KW
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

    return arr_filled

# %% [markdown]
# # Reshape Leaky Relu Params
# ```A: (1,COUT) float16,  B: (KH*KW,COUT) float16, D: (1) float16 -> (ITR, LRELU_BEATS, CORES)```

# %%
def get_lrelu_config(i, layers, KW_MAX, CORES, prefix_max, prefix_lrelu):
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

    layer = layers[f'{prefix_lrelu}{i}']

    '''
    Get max factor and sub cores
    '''
    max_factor = 2 if f'{prefix_max}{i}' in layers.keys() else 1
    KH,KW,_,_ = layer.prev_layer.weights.shape
    SUB_CORES = KW_MAX//KW

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
    
    a_filled = fill_invalid_smcg(a_cout,KW=KW,KW_MAX=KW_MAX, CORES=CORES, max_factor=max_factor)
    b_filled = fill_invalid_smcg(b_cout_clr_mtb,KW=KW,KW_MAX=KW_MAX, CORES=CORES, max_factor=max_factor)
    ITR, EFF_CORES = a_filled.shape[0:2]

    '''
    * Filling happens in SMCG order (natural disk order)
    * Repeat for maxpool
    * LRelu config are sent in S,CMG order
    '''

    a_ismcg = a_filled.reshape(ITR, SUB_CORES,MEMBERS,1,COPIES//max_factor,GROUPS)
    a_ismcg = np.repeat(a_ismcg,repeats=max_factor,axis=3)
    a_ismcg = a_ismcg.reshape(ITR, SUB_CORES,MEMBERS,COPIES,GROUPS)

    b_ismcg_clr_mtb = b_filled.reshape(ITR, SUB_CORES,MEMBERS,1,COPIES//max_factor,GROUPS, KW,KH)
    b_ismcg_clr_mtb = np.repeat(b_ismcg_clr_mtb,repeats=max_factor,axis=3)
    b_ismcg_clr_mtb = b_ismcg_clr_mtb.reshape(ITR, SUB_CORES,MEMBERS,COPIES,GROUPS,KW,KH)

    def append_lrelu_config(arr,config_mcg,is_one_beat=False):
        BEATS = 16 // WORD_WIDTH_CONFIG;
        VALS_CONFIG = MEMBERS // BEATS;

        assert config_mcg.shape == (MEMBERS,COPIES,GROUPS)
        config_cgm = config_mcg.transpose((1,2,0))
        config_cgbv = config_cgm.reshape((COPIES, GROUPS, BEATS, VALS_CONFIG))
        config_bcgv = config_cgbv.transpose(2,0,1,3)
        
        BEATS_TO_SEND = BEATS
        if is_one_beat:
            config_bcgv = config_bcgv[0][np.newaxis,...]
            BEATS_TO_SEND = 1

        config_8_bcgm = np.frombuffer(config_bcgv.tobytes(), np.int8).reshape((BEATS_TO_SEND,COPIES,GROUPS,MEMBERS))
        config_pad_bcgmk = np.zeros((BEATS_TO_SEND,COPIES,GROUPS,MEMBERS,KW_MAX), config_8_bcgm.dtype)
        config_pad_bcgmk[...,0] = config_8_bcgm.astype(np.int8)
        arr += [list(config_pad_bcgmk.reshape(BEATS_TO_SEND,CORES,KW_MAX))]
    

    '''
    Append D, A, B
    '''
    lrelu_config = []

    for itr in range(ITR):
        lrelu_config_itr = []

        ''' d '''
        append_lrelu_config(lrelu_config_itr,d*np.ones((MEMBERS,COPIES,GROUPS),np.float16), is_one_beat=True)

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

    return np.array(lrelu_config) # (ITR,LRELU_BEATS,CORES,KW_MAX)

# %% [markdown]
# # Reshape Weights 
# ```(KH,KW,CIN,COUT) -> (ITR, DMA_BEATS = 4 + (LRELU_BEATS + CIN*KH) * COPIES * MEMBERS * GROUPS * KW_MAX)```

# %%
weights = layers[f'{prefix_conv}{i}'].weights

KH, KW, CIN, COUT = weights.shape
max_factor = 2 if f'{prefix_max}{i}' in layers.keys() else 1

'''
Reshape
'''

weights = weights.transpose(3,0,1,2) #(COUT,KH,KW,CIN)
weights = fill_invalid_smcg(weights,KW=KW,KW_MAX=KW_MAX,CORES=CORES,max_factor=max_factor) #(ITR,EFF_CORES,KH,KW,CIN)
ITR,EFF_CORES = weights.shape[0:2]
weights = weights.transpose(0,4,2,1,3) #(ITR,CIN,KH,EFF_CORES,KW)

'''
* Data comes out of maxpool in the order: SM,CGU
* Data comes out of conv in the order   : S,CMGU and is transposed into S,MCGUby hardware
* Conv in takes weights in order        : CMGS

* Since system_out is SMCG, first invalid should be filled that way, so that output data is continous and cin matches cout
* After filling, we transpose it to CMGS
'''

SUB_CORES = KW_MAX//KW
weights = weights.reshape((ITR,CIN,KH, SUB_CORES,MEMBERS,COPIES//max_factor,GROUPS ,KW)) # EFF_CORES = (SMCG)
weights = weights.transpose(0,1,2, 5,4,6, 3,7) # CMGS
weights = weights.reshape((ITR,CIN,KH,1,COPIES//max_factor,MEMBERS,GROUPS,KW_MAX)) # (CMGS)
weights = np.repeat(weights,repeats=max_factor,axis=3)
weights = weights.reshape((ITR,CIN,KH,CORES,KW_MAX))

KERNEL_BEATS = CIN*KH
weights = weights.reshape(ITR,KERNEL_BEATS,CORES,KW_MAX)

'''
Add LRELU Beats
'''
lrelu = get_lrelu_config(i,layers=layers,KW_MAX=KW_MAX,CORES=CORES,prefix_max=prefix_max,prefix_lrelu=prefix_lrelu) # (ITR,LRELU_BEATS,CORES,KW_MAX)
LRELU_BEATS = lrelu.shape[1]
weights_beats = np.concatenate([lrelu,weights], axis=1) # (ITR, LRELU_BEATS + KERNEL_BEATS, CORES, KW_MAX)

'''
CONFIG
'''
_,H,W,CIN = layers[f'{prefix_conv}{i}'].in_data.shape
BLOCKS    = H // CONV_UNITS
BLOCKS_PER_ARR = BLOCKS // max_factor

BITS_KW_MAX     = int(np.ceil(np.log2(KW_MAX    )))
BITS_KH_MAX     = int(np.ceil(np.log2(KH_MAX    )))
BITS_CIN_MAX    = int(np.ceil(np.log2(CIN_MAX   )))
BITS_COLS_MAX   = int(np.ceil(np.log2(COLS_MAX  )))
BITS_BLOCKS_MAX = int(np.ceil(np.log2(BLOCKS_MAX)))

weights_config = 0
weights_config |= (KW    -1)
weights_config |= (KH    -1) << (BITS_KW_MAX)
weights_config |= (CIN   -1) << (BITS_KW_MAX + BITS_KH_MAX)
weights_config |= (W     -1) << (BITS_KW_MAX + BITS_KH_MAX + BITS_CIN_MAX)
weights_config |= (BLOCKS_PER_ARR-1) << (BITS_KW_MAX + BITS_KH_MAX + BITS_CIN_MAX + BITS_COLS_MAX)
weights_config = np.frombuffer(np.int32(weights_config).tobytes(),np.int8)
weights_config = np.repeat(weights_config[np.newaxis,...],repeats=ITR,axis=0)

'''
ADD CONFIG BEATS
'''
weights_dma_beats = np.concatenate([weights_config,weights_beats.reshape(ITR,-1)], axis=1)

assert weights_dma_beats.shape == (ITR, 4 + (LRELU_BEATS + CIN*KH)*CORES*KW_MAX)


# %%
weights_dma_beats.shape


# %%
layers[f'{prefix_conv}{i}'].weights[0,0,0,16]


# %%
weights_dma_beats[1,:][0:20]


# %%
np.savetxt(f"D:/cnn-fpga/data/{i}_weights.txt", weights_dma_beats[0].flatten(), fmt='%d')

# %% [markdown]
# # Reshape Conv Image In
# 
# ```
# (1, H, W, CIN) ->  im_arrays: max_factor
# 
# im_arrays[ 0]: (1 + BLOCKS//max_factor*W*CIN, CONV_UNITS_EDGES)
# im_arrays[!0]: (BLOCKS//max_factor, W, CIN, CONV_UNITS_EDGES)```

# %%
def reshape_conv_in(layers, i):
    image = layers[f'{prefix_conv}{i}'].in_data[0]
    max_factor = 2 if f'{prefix_max}{i}' in layers.keys() else 1
    H,W,CIN = image.shape

    CONV_UNITS_EDGES = CONV_UNITS + KH_MAX-1
    BLOCKS = H//CONV_UNITS
    assert H % CONV_UNITS == 0
    assert BLOCKS % max_factor == 0

    image = np.pad(image, ((KH_MAX//2, KH_MAX//2), (0, 0), (0, 0)), mode='constant')

    im_arrays = []
    for m in range(max_factor):
        im_arrays += [np.zeros([BLOCKS//max_factor, W, CIN, CONV_UNITS_EDGES], image.dtype)]

    for b in range(BLOCKS):
        h_index_start = b*CONV_UNITS
        h_index_end   = h_index_start + CONV_UNITS_EDGES
        block = image[h_index_start:h_index_end,:,:] # padding with prev & next block
        block = block.transpose([1, 2, 0]) # (H,W,C) -> (W,C,H)

        im_array_index = b %  max_factor
        blocks_index   = b // max_factor
        im_arrays[im_array_index][blocks_index] = block

    '''
    Config

    IS_NOT_MAX if there is a conv layer followed by a max (IS_MAX) and a conv (IS_NOT_MAX)
    '''
    CONV_UNITS_EDGES = im_arrays[0].shape[-1]
    IS_MAX     = max_factor != 1
    IS_NOT_MAX = max_factor == 1

    if IS_MAX:
        for layer in layers.values():
            if prefix_conv in layer.name:
                if prefix_lrelu in layer.prev_layer.name:
                    '''Conv layer without max before it'''
                    prev_i = int(layer.prev_layer.name.split('_')[-1])
                    if prev_i == i:
                        IS_NOT_MAX = 1

    IS_LRELU = f'{prefix_lrelu}{i}' in layers.keys()
    KH      = layers[f'{prefix_conv}{i}'].weights.shape[0]        

    config = np.zeros((CONV_UNITS_EDGES),np.int8)
    config[0] = IS_NOT_MAX
    config[1] = IS_MAX
    config[2] = IS_LRELU
    config[3] = KH-1
    assert CONV_UNITS_EDGES >= 4

    im_arrays[0] = np.concatenate([config [np.newaxis,:], im_arrays[0].reshape(BLOCKS//max_factor*W*CIN, CONV_UNITS_EDGES)], axis=0)

    return im_arrays, (BLOCKS,max_factor,W,CIN, CONV_UNITS_EDGES)

im_arrays, in_shape = reshape_conv_in(layers, i)


# %%
# im_arrays[1].size


# %%
for m in range(max_factor):
    np.savetxt(f"D:/cnn-fpga/data/{i}_conv_in_{m}.txt", im_arrays[m].flatten(), fmt='%d')


# %%
# path = 'D:/cnn-fpga/data'

# w_path = f"{path}/{i}_weights.bin"
# w_itr_0 = weights_dma_beats[0:2,:].flatten()
# w_itr_0.tofile(w_path)

# cmd_txt = f"mwr -bin -file {w_path} 0x0A000000 {w_itr_0.size//4}; "

# im_0_path = f"{path}/{i}_conv_in_0.bin"
# im_arrays[0].tofile(im_0_path)

# cmd_txt += f"mwr -bin -file {im_0_path} 0x02000000 {im_arrays[0].size//4}; "

# if IS_MAX:
#     im_1_path = f"{path}/{i}_conv_in_1.bin"
#     im_arrays[1].tofile(im_1_path)

#     cmd_txt += f"mwr -bin -file {im_1_path} 0x03000000 {im_arrays[1].size//4};"

# print(cmd_txt)

# %% [markdown]
# # FPGA Memory Load

# %%
path = 'D:/cnn-fpga/data'

w_path = f"{path}/{i}_weights.bin"
weights = weights_dma_beats.flatten()
weights.tofile(w_path)

cmd_txt = f"mwr -bin -file {w_path} 0x0A000000 {int(np.ceil(weights.size/4))}; "

im_0_file_size = int(np.ceil(im_arrays[0].size/4))*4
im_0 = np.zeros(im_0_file_size, im_arrays[0].dtype)
im_0[:im_arrays[0].size] = im_arrays[0].flatten()

im_0_path = f"{path}/{i}_conv_in_0.bin"
im_arrays[0].tofile(im_0_path)

cmd_txt += f"mwr -bin -file {im_0_path} 0x02000000 {im_0_file_size//4}; "

IS_MAX = f'{prefix_max}{i}' in layers.keys()
if IS_MAX:
    im_1_path = f"{path}/{i}_conv_in_1.bin"
    im_arrays[1].tofile(im_1_path)

    cmd_txt += f"mwr -bin -file {im_1_path} 0x03000000 {int(np.ceil(im_arrays[1].size/4))};"

print(cmd_txt)


# %%
im_arrays[0].size


# %%
i

# %% [markdown]
# # Reshape Conv Out = LeakyReLu in
# 
# ```(1, H, W, CIN) -> (ITR, LRELU_BEATS + BLOCKS_PER_ARR*W*SUB_CORES, COPIES*MEMBERS*GROUPS, CONV_UNITS)```

# %%
image = layers[f'{prefix_conv}{i}'].np_out_data[0]
max_factor = 2 if f'{prefix_max}{i}' in layers.keys() else 1
KW    = layers[f'{prefix_conv}{i}'].weights.shape[0]

def reshape_image_out(image,order,KW,max_factor,CONV_UNITS,copy_factor=1,flip_cols=True):
    assert order == 'cmg' or order == 'mcg'

    H,W,COUT = image.shape
    BLOCKS = H//CONV_UNITS
    assert H % CONV_UNITS == 0
    assert BLOCKS % max_factor == 0
    
    '''Flip last cols to imitate conv'''
    if flip_cols and KW != 1:
        image = np.concatenate([image[:,:-(KW-1),:], np.flip(image[:,-(KW-1):,:],axis=1)],axis=1)

    image = image.reshape((BLOCKS//max_factor,max_factor,CONV_UNITS,W,COUT))
    image = image.transpose(4,0,3,1,2) #(COUT,BLOCKS_PER_ARR,W,max_factor,CONV_UNITS)
    image = fill_invalid_smcg(image,KW=KW,KW_MAX=KW_MAX,CORES=CORES//copy_factor,max_factor=max_factor)
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
    SUB_CORES = KW_MAX//KW
    image = image.reshape(ITR, SUB_CORES,MEMBERS,eff_c,GROUPS, BLOCKS_PER_ARR,W,max_factor,CONV_UNITS) # (EFF_CORES -> SMCG)

    if order == 'mcg':
        image = image.transpose(0,5,6,1, 2,3,7,4, 8) #(ITR,BLOCKS_PER_ARR,W,SUB_CORES, MEMBERS,eff_c,max_factor,GROUPS, CONV_UNITS)
    if order == 'cmg':
        image = image.transpose(0,5,6,1, 3,7,2,4, 8) #(ITR,BLOCKS_PER_ARR,W,SUB_CORES, eff_c,max_factor,MEMBERS,GROUPS, CONV_UNITS)
    return image.reshape(ITR,BLOCKS_PER_ARR,W,SUB_CORES, CORES//copy_factor, CONV_UNITS)

conv_image = reshape_image_out(image=image,order='cmg',KW=KW,max_factor=max_factor,CONV_UNITS=CONV_UNITS)
ITR,BLOCKS_PER_ARR,W,SUB_CORES,CORES,CONV_UNITS = conv_image.shape
DATA_BEATS = BLOCKS_PER_ARR*W*SUB_CORES
image = conv_image.reshape(ITR,DATA_BEATS,CORES,CONV_UNITS)

'''
Concat Lrelu config
'''
lrelu_config = get_lrelu_config(i,layers=layers,KW_MAX=KW_MAX,CORES=CORES,prefix_max=prefix_max,prefix_lrelu=prefix_lrelu) #(ITR,LRELU_BEATS,CORES)

ITR,LRELU_BEATS,CORES,KW_MAX = lrelu_config.shape
lrelu_config_padded = np.zeros((ITR,LRELU_BEATS,CORES,CONV_UNITS),lrelu_config.dtype)
lrelu_config_padded[...,0] = lrelu_config[...,0]

image_out = np.concatenate([lrelu_config_padded,image],axis=1)

assert image_out.shape == (ITR, (21 if KW==3 else 13) + BLOCKS_PER_ARR*W*SUB_CORES, COPIES*MEMBERS*GROUPS,CONV_UNITS)


# %%
np.savetxt(f"D:/cnn-fpga/data/{i}_conv_out.txt", image_out[0].flatten(), fmt='%d')


# %%
image_out_fpga = np.loadtxt(f"D:/cnn-fpga/data/{i}_conv_out_fpga_0.txt",np.int32)

error = image_out_fpga - image_out[0].flatten()
np.sum(error)

# %% [markdown]
# # Leaky Relu Out / Max In
# 
# ```(1, H, W, CIN) -> (ITR,BLOCKS_PER_ARR,W,SUB_CORES,CORES,CONV_UNITS)```

# %%
image = layers[f'{prefix_lrelu}{i}'].np_out_data[0]
max_factor = 2 if f'{prefix_max}{i}' in layers.keys() else 1
KW    = layers[f'{prefix_conv}{i}'].weights.shape[0]

lrelu_out = reshape_image_out(image=image,order='mcg',KW=KW,max_factor=max_factor,CONV_UNITS=CONV_UNITS)
ITR,BLOCKS_PER_ARR,W,SUB_CORES,CORES,CONV_UNITS = lrelu_out.shape


# %%
image_out_fpga = np.loadtxt(f"D:/cnn-fpga/data/{i}_lrelu_out_fpga_0.txt",np.int8)
fpga = image_out_fpga.reshape((BLOCKS_PER_ARR,W,SUB_CORES,CORES,CONV_UNITS))

'''
Invalid cores output 0+d=d. Remove d to compare.
'''

for s in range(SUB_CORES):
    for c in range(CORES):
        if np.all(fpga[:,:,s,c,:]==layers[f'{prefix_lrelu}{i}'].requantize_params['D']):
            fpga[:,:,s,c,:] = 0

error = lrelu_out[0] - fpga
sum_abs_error = np.sum(np.abs(error))

np.savetxt("where_err.txt",np.argwhere(error > 1),fmt='%d')

print(np.sum(abs(error)>1))
print(sum_abs_error/image_out_fpga.size)


# %%
layers[f'{prefix_lrelu}{i}'].requantize_params['B'][0,1,1,0:4]


# %%
# DIMS_BWSMCGU = (BLOCKS_PER_ARR,W,SUB_CORES,MEMBERS,COPIES,GROUPS,CONV_UNITS)
# DIMS_BWSCMGU = (BLOCKS_PER_ARR,W,SUB_CORES,COPIES,MEMBERS,GROUPS,CONV_UNITS)

# error = error.reshape(DIMS_BWSMCGU)
# np.savetxt("where_err.txt",np.argwhere(error > 1),fmt='%d')

# image_conv = conv_image[0].reshape(DIMS_BWSCMGU).transpose(0,1,2,4,3,5,6)
# lrelu_out_mcgu = lrelu_out[0].reshape(DIMS_BWSMCGU)
# fpga_mcgu = fpga.reshape(DIMS_BWSMCGU)

# print(image_conv[error > 1])


# %%
error[error>1]


# %%
np.unravel_index(8,(MEMBERS,COPIES,GROUPS))


# %%
b = layers[f'{prefix_lrelu}{i}'].requantize_params['B'][0,1,1,8].astype(np.float16)
a = layers[f'{prefix_lrelu}{i}'].requantize_params['A'][0,0,0,8].astype(np.float16)
d = layers[f'{prefix_lrelu}{i}'].requantize_params['D'].astype(np.float16)

b, a, d


# %%
(0.003149 * 37710 + -118.75)-85.0


# %%
# lrelu_out_mcgu[error>1], fpga_mcgu[error>1]


# %%
fpga_mcgu = image_out_fpga.reshape((BLOCKS_PER_ARR,W,SUB_CORES,MEMBERS,COPIES,GROUPS,CONV_UNITS))

fpga_mcgu[0,4,0,1,0,0,:]


# %%
(a*(2330) + b) + d


# %%
a*(2330) + b


# %%
a,b


# %%
print(np.sum(abs(error[:,:,0,0,0,0,0])>1))


# %%
error[:,:,0,1,0,0,0]

# %% [markdown]
# # System Out (SIM)
# ```(1, H, W, CIN) -> (ITR,BLOCKS_PER_ARR,W,SUB_CORES,CORES,CONV_UNITS_EDGES)```

# %%
is_max = False
copy_factor = 1
flip_cols = True
if f'{prefix_max}{i}' in layers.keys():
    is_max = True
    copy_factor = 2
    flip_cols = False
    image = layers[f'{prefix_max}{i}'].np_out_data[0]
elif f'{prefix_lrelu}{i}' in layers.keys():
    image = layers[f'{prefix_lrelu}{i}'].np_out_data[0]
else:
    image = layers[f'{prefix_conv}{i}'].np_out_data[0]

max_factor = 2 if f'{prefix_max}{i}' in layers.keys() else 1
KW    = layers[f'{prefix_conv}{i}'].weights.shape[0]

'''Force max_factor=1, since output is always one set of blocks'''
image = reshape_image_out(image=image,order='mcg',KW=KW,max_factor=1,copy_factor=copy_factor,CONV_UNITS=CONV_UNITS, flip_cols= flip_cols)

ITR,BLOCKS_PER_ARR,W,SUB_CORES,_,CONV_UNITS = image.shape
image_padded = np.pad(image,((0,0),(0,0),(0,0),(0,0),(0,0),(KH_MAX//2,KH_MAX//2)),mode='constant')


# %%
image_out_sim = np.loadtxt(f"D:/cnn-fpga/data/{i}_output_fpga_0.txt",np.int8)
sim = image_out_sim.reshape((BLOCKS_PER_ARR,W,SUB_CORES,CORES//copy_factor,UNITS_EDGES))

'''
Invalid cores output 0+d=d. Remove d to compare.
'''

for s in range(SUB_CORES):
    for c in range(CORES//copy_factor):
        if np.all(sim[:,:,s,c,1:-1]==layers[f'{prefix_lrelu}{i}'].requantize_params['D']):
            sim[:,:,s,c,:] = 0

error = image_padded[0] - sim
sum_abs_error = np.sum(np.abs(error))

print(np.sum(error > 1))
print(sum_abs_error/image_out_sim.size)


# %%
image_out_sim != layers[f'{prefix_lrelu}{i}'].requantize_params['D']


# %%
# np.savetxt("where_err.txt",np.argwhere(error > 1),fmt='%d')

# %% [markdown]
# # Image Out FPGA

# %%
im_arrays_out, out_shape = reshape_conv_in(layers, i+1)

next_max_factor = len(im_arrays_out)


# %%
cmd = ""
out_paths = []
addrs = ['0x06000000', '0x07000000']

for m in range(next_max_factor):
    out_paths += [f"{path}/{i}_fpga_out_{m}.bin"]
    cmd += f"mrd -bin -file {out_paths[m]} {addrs[m]} {int(np.ceil((im_arrays_out[m].size)/4))}; "

print(cmd)


# %%
im_arrays_fpga_out = []

for m in range(next_max_factor):
    im_arrays_fpga_out += [np.fromfile(out_paths[m],np.int8)[0:im_arrays_out[m].size]]


# %%
# BLOCKS//max_factor, W, CIN, CONV_UNITS_EDGES
_, next_h, next_w, next_cin = layers[f'conv_{i+1}'].in_data.shape
next_blocks = next_h//CONV_UNITS
next_shape = next_blocks//next_max_factor, next_w, next_cin, UNITS_EDGES

im_out = im_arrays_out[0].flatten()[UNITS_EDGES:].reshape(next_shape)
fpga_out = im_arrays_fpga_out[0][UNITS_EDGES:].reshape(next_shape)

error = im_out - fpga_out
print(error.shape)


# %%
im_out[0,0,16,:]


# %%
im_out.size


# %%
image_padded[0][1,0,0,0,:]


# %%
np.sum(error)


# %%
im_arrays_fpga_out[0][:150]-im_arrays_out[0].flatten()[:150]

# %% [markdown]
# # Input LUT

# %%
import cv2
from matplotlib import pyplot as plt

image_in = cv2.imread('../data/5.png')
image_in = cv2.resize(image_in,(384,256))
image_in = image_in[:, :, ::-1]

image_in.tofile('../../data/image_rgb.bin')

plt.imshow(image_in)


# %%
path_dir = 'D:/cnn-fpga/data/'
path_input_lut = path_dir + 'input_lut.bin'
path_input = path_dir + 'image_rgb.bin'

input_lut = layers['input_1'].quantize_lut

input_lut.tofile(path_input_lut)
image_in.tofile(path_input)

f"mwr -bin -file {path_input_lut} 0x00001000 {input_lut.size//4}; mwr -bin -file {path_input} 0x01000000 {image_in.size//4};"


# %%
UNITS        =8
MEMBERS      =8
COPIES       =2
GROUPS       =2
KERNEL_W_MAX =3
KERNEL_H_MAX =3
UNITS_EDGES  =10

height, width, cin = image_in.shape
max_factor = 2
blocks = height//UNITS
blocks_per_arr = blocks//max_factor

p_input_lut = layers['input_1'].quantize_lut
p_image_input = image_in.reshape(blocks,UNITS,width,cin)
p_image_in = np.zeros((2,blocks_per_arr,width, cin, UNITS_EDGES),dtype=np.int8)


# %%
for b in range(blocks):
    for u in range(UNITS):
        for w in range(width):
            for c in range(cin):
                p_image_in[b%max_factor][b//max_factor][w][c][u+KERNEL_H_MAX//2] = p_input_lut[p_image_input[b][u][w][c]];


# %%



# %%
im_arrays_0_fpga = np.fromfile(path_dir+"1_conv_in_0_fpga.bin",dtype=np.int8)
np.argwhere(im_arrays_0_fpga[10:]-im_arrays[0].flatten()[10:] != 0)


# %%
im_arrays_1_fpga = np.fromfile(path_dir+"1_conv_in_1_fpga.bin",dtype=np.int8)
np.argwhere(im_arrays_1_fpga-im_arrays[1].flatten() != 0)


# %%
im_0_fpga = im_arrays_0_fpga.reshape(im_arrays[0].shape)
error = im_0_fpga-im_arrays[0]
error_bwcu = error[1:,:].reshape(16,384,3,10)
np.savetxt('where_err.txt', np.argwhere(error_bwcu!=0), fmt='%d')


# %%
im_0_fpga[1,:]


# %%
im_arrays[0].flatten()[10:][3399:]


# %%



# %%
a = np.arange(48).reshape(6,2,2,2)
b = np.zeros((2,3,2,2,4), np.int8)

for blocks in range(6):
    for w in range(2):
        for c in range(2):
            b[blocks%2][blocks//2][w][c][1:3] = a[blocks,:,w,c]

            if blocks not in [0,5]:
                b[(blocks-1)%2][(blocks-1)//2][w][c][3] = a[blocks,0,w,c]
                b[(blocks+1)%2][(blocks+1)//2][w][c][0] = a[blocks,0,w,c]


# %%
b[0,0,0,0,:]


# %%
a[:,0,0,0]


# %%
im_in = layers['conv_1'].in_data[0]
H,W,CIN = im_in.shape

BLOCKS = H//UNITS
MAX_FACTOR = 2

im_in_buwc = im_in.reshape(BLOCKS,UNITS,W,CIN)

im_mbwcu = np.ones((MAX_FACTOR, BLOCKS//MAX_FACTOR, W, CIN,UNITS+KERNEL_H_MAX-1),np.int8)*133


# %%

t = 0

def f():
    global im_mbwcu, im_in_buwc, t

    for i_b in range(BLOCKS):
        for i_u in range(UNITS):
            for i_w in range(W):
                for i_cin in range(CIN):

                    # if t > 10:
                    #     return
                    # else:
                    #     t += 1

                    i_arr   = i_b % MAX_FACTOR
                    i_b_arr = i_b // MAX_FACTOR
                    i_ue    = i_u + KERNEL_H_MAX//2

                    value = im_in_buwc[i_b, i_u, i_w, i_cin]

                    im_mbwcu[i_arr, i_b_arr, i_w, i_cin, i_ue] = value

                    # print(f"[{i_b}, {i_u}, {i_w}, {i_cin}]->[{i_arr}, {i_b_arr}, {i_w}, {i_cin}, {i_ue}]")

                    if (i_u < KERNEL_H_MAX//2):
                        i_ue    = i_u + (UNITS + KERNEL_H_MAX//2);

                        if (i_b == 0):
                            value   = 0  							
                            i_arr   = (BLOCKS-1) % MAX_FACTOR  
                            i_b_arr = (BLOCKS-1) // MAX_FACTOR

                        else:
                            i_arr   = (i_b-1) % MAX_FACTOR
                            i_b_arr = (i_b-1) // MAX_FACTOR

                        im_mbwcu[i_arr, i_b_arr, i_w, i_cin, i_ue] = value

                    if (i_u >= UNITS-KERNEL_H_MAX//2):
                        i_ue    = i_u - (UNITS - KERNEL_H_MAX//2)

                        if (i_b == BLOCKS-1):
                            value   = 0 
                            i_arr   = 0 
                            i_b_arr = 0 
                        else:
                            i_arr   = (i_b+1)%MAX_FACTOR;
                            i_b_arr = (i_b+1)//MAX_FACTOR;

                        im_mbwcu[i_arr, i_b_arr, i_w, i_cin, i_ue] = value

f()


# %%
error = im_mbwcu[0] - im_arrays[0][1:,:].reshape((BLOCKS//MAX_FACTOR, W, CIN,UNITS+KERNEL_H_MAX-1))
np.sum(error!=0)


# %%
error = im_mbwcu[1] - im_arrays[1].reshape((BLOCKS//MAX_FACTOR, W, CIN,UNITS+KERNEL_H_MAX-1))
np.sum(error!=0)


# %%
im_in_fpga = np.fromfile('D:/cnn-fpga/data/1_im_in_fpga.bin',np.uint8)
error = im_in_fpga-image_in.flatten()
np.sum(error!=0)

np.argwhere(error !=0)


# %%
lut_fpga = np.fromfile('D:/cnn-fpga/data/1_lut_fpga.bin',np.int8)
error = input_lut-lut_fpga
np.sum(error!=0)


