# To add a new cell, type '# %%'
# To add a new markdown cell, type '# %% [markdown]'
# %%
import numpy as np 
import pickle
from yolov2_mod_numpy import YOLOv2_Modified_Numpy

layers = pickle.load(open('yolov2_mod_int8_dict.pickle', 'rb'))

CONV_UNITS = 4

MEMBERS = 1
COPIES  = 2
GROUPS  = 1
CORES   = MEMBERS*COPIES*GROUPS

prefix_conv = 'conv_'
prefix_max = 'maxpool_'
prefix_lrelu = 'leaky_relu_'

KW_MAX     = 3
KH_MAX     = 3
CIN_MAX    = 1024
COLS_MAX   = 384
BLOCKS_MAX = 32

assert KH_MAX % 2 == 1


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
def get_lrelu(i, layers, KW_MAX, CORES, prefix_max, prefix_lrelu):

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

    '''
    Fill invalid and reshape

    * Since system_out is in SMCG form, cout is filled that way (consistent with CIN)
    * Lrelu config go into conv through weights 
    * They dont come out via subcores, only first subcore releases values
    * Since conv transposes only subcores, we dont consider it here.
    * But after conv, we transpose S,CMG into S,MCG in hardware.
    * So, we need to do the opposite here. SMCG -> SCMG.
    '''
    ab_mcg = np.concatenate([ a_cout.reshape(COUT,1),
                            b_cout_clr_mtb.reshape(COUT, KH*KW)
                            ], axis=1) # (COUT, 1+K*K)

    ab_filled = fill_invalid_smcg(arr=ab_mcg,KW=KW,KW_MAX=KW_MAX,CORES=CORES,max_factor=max_factor)

    ITR, EFF_CORES = ab_filled.shape[0:2]
    EFF_MCG = EFF_CORES//SUB_CORES

    ab = ab_filled.reshape((ITR, SUB_CORES,MEMBERS,COPIES//max_factor,GROUPS, 1+KW*KH))
    ab = ab.transpose(0,1,3,2,4,5) # (MCG -> CMG)

    FLOAT_BEATS_AB = SUB_CORES*(1+KW*KH)
    INT_BEATS_AB = 2*FLOAT_BEATS_AB

    ''' Repeat AB for MAX'''
    ab = ab.reshape(ITR,FLOAT_BEATS_AB,COPIES//max_factor,MEMBERS,GROUPS)
    ab = np.repeat(ab,repeats=max_factor,axis=2)

    ''' Convert to int '''
    ab = np.frombuffer(ab.tobytes(),np.int8)
    ab = ab.reshape(ITR,INT_BEATS_AB,CORES)

    ''' Concat d'''
    d = np.tile(d,(ITR,1,CORES//2))
    d = np.frombuffer(d.tobytes(),np.int8).reshape(ITR,1,CORES)

    dab = np.concatenate([d, ab], axis=1)

    assert dab.shape == (ITR, 21 if KW==3 else 13, CORES)
    return dab

# %% [markdown]
# # Reshape Weights 
# ```(KH,KW,CIN,COUT) -> (ITR, DMA_BEATS = 4 + (LRELU_BEATS + CIN*KH) * COPIES * MEMBERS * GROUPS * KW_MAX)```

# %%
i = 4

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

* Since conv_out is SCMG, first invalid should be filled that way, so that output data is continous and cin matches cout
* After filling, we transpose it to CMGS
'''

SUB_CORES = KW_MAX//KW
weights = weights.reshape((ITR,CIN,KH, SUB_CORES,CORES//max_factor ,KW)) # EFF_CORES = (SUBCORES,CORES//max)
weights = weights.transpose(0,1,2,4,3,5)
weights = weights.reshape((ITR,CIN,KH,1,CORES//max_factor,KW_MAX)) # (CMGS)
weights = np.repeat(weights,repeats=max_factor,axis=3)
weights = weights.reshape((ITR,CIN,KH,CORES,KW_MAX))

KERNEL_BEATS = CIN*KH
weights = weights.reshape(ITR,KERNEL_BEATS,CORES,KW_MAX)

'''
Add LRELU Beats
'''
lrelu = get_lrelu(i,layers=layers,KW_MAX=KW_MAX,CORES=CORES,prefix_max=prefix_max,prefix_lrelu=prefix_lrelu)
LRELU_BEATS = lrelu.shape[1]
lrelu = np.repeat(lrelu[...,np.newaxis],repeats=KW_MAX,axis=-1)
weights_beats = np.concatenate([lrelu,weights], axis=1) # (ITR, LRELU_BEATS + KERNEL_BEATS, CORES, KW_MAX)

'''
CONFIG
'''
_,H,W,CIN = layers[f'{prefix_conv}{i}'].in_data.shape
BLOCKS    = H // CONV_UNITS

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
weights_config |= (BLOCKS-1) << (BITS_KW_MAX + BITS_KH_MAX + BITS_CIN_MAX + BITS_COLS_MAX)
weights_config = np.frombuffer(np.int32(weights_config).tobytes(),np.int8)
weights_config = np.repeat(weights_config[np.newaxis,...],repeats=ITR,axis=0)

'''
ADD CONFIG BEATS
'''
weights_dma_beats = np.concatenate([weights_config,weights_beats.reshape(ITR,-1)], axis=1)

assert weights_dma_beats.shape == (ITR, 4 + (LRELU_BEATS + CIN*KH)*CORES*KW_MAX)


# %%
np.savetxt(f"D:/Vision Traffic/soc/data/{i}_weights.txt", weights_dma_beats[0].flatten(), fmt='%d')

# %% [markdown]
# # Reshape Conv Image In
# 
# ```
# (1, H, W, CIN) ->  im_arrays: max_factor
# 
# im_arrays[ 0]: (1 + BLOCKS//max_factor*W*CIN, CONV_UNITS_EDGES)
# im_arrays[!0]: (BLOCKS//max_factor, W, CIN, CONV_UNITS_EDGES)```

# %%
i = 4

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


# %%
for m in range(max_factor):
    np.savetxt(f"D:/Vision Traffic/soc/data/{i}_conv_in_{m}.txt", im_arrays[m].flatten(), fmt='%d')

# %% [markdown]
# # Reshape Conv Out = LeakyReLu in
# 
# ```(1, H, W, CIN) -> (ITR, LRELU_BEATS + BLOCKS_PER_ARR*W*SUB_CORES, COPIES*MEMBERS*GROUPS, CONV_UNITS)```

# %%
i = 1

image = layers[f'{prefix_conv}{i}'].np_out_data[0]
max_factor = 2 if f'{prefix_max}{i}' in layers.keys() else 1
KW    = layers[f'{prefix_conv}{i}'].weights.shape[0]

def reshape_image_out(image,order,KW,max_factor,CONV_UNITS):
    assert order == 'cmg' or order == 'mcg'

    H,W,COUT = image.shape
    BLOCKS = H//CONV_UNITS
    assert H % CONV_UNITS == 0
    assert BLOCKS % max_factor == 0
    
    '''Flip last cols to imitate conv'''
    if KW != 1:
        image = np.concatenate([image[:,:-(KW-1),:], np.flip(image[:,-(KW-1):,:],axis=1)],axis=1)

    image = image.reshape((BLOCKS//max_factor,max_factor,CONV_UNITS,W,COUT))
    image = image.transpose(4,0,3,1,2) #(COUT,BLOCKS_PER_ARR,W,max_factor,CONV_UNITS)
    image = fill_invalid_smcg(image,KW=KW,KW_MAX=KW_MAX,CORES=CORES,max_factor=max_factor)
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
    eff_c  = 2//max_factor
    SUB_CORES = KW_MAX//KW
    image = image.reshape(ITR, SUB_CORES,MEMBERS,eff_c,GROUPS, BLOCKS_PER_ARR,W,max_factor,CONV_UNITS) # (EFF_CORES -> SMCG)

    if order == 'mcg':
        image = image.transpose(0,5,6,1, 2,3,7,4, 8) #(ITR,BLOCKS_PER_ARR,W,SUB_CORES, MEMBERS,eff_c,max_factor,GROUPS, CONV_UNITS)
    if order == 'cmg':
        image = image.transpose(0,5,6,1, 3,7,2,4, 8) #(ITR,BLOCKS_PER_ARR,W,SUB_CORES, eff_c,max_factor,MEMBERS,GROUPS, CONV_UNITS)
    return image.reshape(ITR,BLOCKS_PER_ARR,W,SUB_CORES, CORES, CONV_UNITS)

image = reshape_image_out(image=image,order='cmg',KW=KW,max_factor=max_factor,CONV_UNITS=CONV_UNITS)
ITR,BLOCKS_PER_ARR,W,SUB_CORES,CORES,CONV_UNITS = image.shape
DATA_BEATS = BLOCKS_PER_ARR*W*SUB_CORES
image = image.reshape(ITR,DATA_BEATS,CORES,CONV_UNITS)

'''
Concat Lrelu config
'''
lrelu_config = get_lrelu(i,layers=layers,KW_MAX=KW_MAX,CORES=CORES,prefix_max=prefix_max,prefix_lrelu=prefix_lrelu) #(ITR,LRELU_BEATS,CORES)

ITR,LRELU_BEATS,CORES = lrelu_config.shape
lrelu_config_padded = np.zeros((ITR,LRELU_BEATS,CORES,CONV_UNITS),lrelu_config.dtype)
lrelu_config_padded[...,0] = lrelu_config

image_out = np.concatenate([lrelu_config_padded,image],axis=1)

assert image_out.shape == (ITR, (21 if KW==3 else 13) + BLOCKS_PER_ARR*W*SUB_CORES, COPIES*MEMBERS*GROUPS,CONV_UNITS)


# %%
np.savetxt(f"D:/Vision Traffic/soc/data/{i}_conv_out.txt", image_out[0].flatten(), fmt='%d')


# %%
image_out_fpga = np.loadtxt(f"D:/Vision Traffic/soc/data/{i}_conv_out_fpga.txt",np.int32)

np.sum(image_out[0].flatten()-image_out_fpga)


# %%
i

# %% [markdown]
# # Leaky Relu Out / Max In
# 
# ```(1, H, W, CIN) -> (ITR,BLOCKS_PER_ARR,W,SUB_CORES,CORES,CONV_UNITS)```

# %%
i = 4
image = layers[f'{prefix_lrelu}{i}'].np_out_data[0]
max_factor = 2 if f'{prefix_max}{i}' in layers.keys() else 1
KW    = layers[f'{prefix_conv}{i}'].weights.shape[0]

image = reshape_image_out(image=image,order=order,KW=KW,max_factor=max_factor,CONV_UNITS=CONV_UNITS)
ITR,BLOCKS_PER_ARR,W,SUB_CORES,CORES,CONV_UNITS = image.shape

# %% [markdown]
# # System Out
# ```(1, H, W, CIN) -> (ITR,BLOCKS_PER_ARR,W,SUB_CORES,CORES,CONV_UNITS_EDGES)```

# %%
i = 4

if f'{prefix_max}{i}' in layers.keys():
    image = layers[f'{prefix_max}{i}'].np_out_data[0]
elif f'{prefix_lrelu}{i}' in layers.keys():
    image = layers[f'{prefix_lrelu}{i}'].np_out_data[0]
else:
    image = layers[f'{prefix_conv}{i}'].np_out_data[0]

max_factor = 2 if f'{prefix_max}{i}' in layers.keys() else 1
KW    = layers[f'{prefix_conv}{i}'].weights.shape[0]

'''Force max_factor=1, since output is always one set of blocks'''
image = reshape_image_out(image=image,order=order,KW=KW,max_factor=1,CONV_UNITS=CONV_UNITS)
ITR,BLOCKS_PER_ARR,W,SUB_CORES,CORES,CONV_UNITS = image.shape

image_padded = np.pad(image,((0,0),(0,0),(0,0),(0,0),(0,0),(KH_MAX//2,KH_MAX//2)),mode='constant')


# %%


