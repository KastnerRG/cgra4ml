# To add a new cell, type '# %%'
# To add a new markdown cell, type '# %% [markdown]'
# %% [markdown]
# ## input pipe

# %%
import numpy as np 

K          = 3
CIN        = 4
HEIGHT     = 2
WIDTH      = 4
IS_NOT_MAX = 0
IS_MAX     = 0
IS_LRELU   = 0

UNITS      = 2
CORES      = 2 #2

KW         = K
KH         = K
COLS       = WIDTH
BLOCKS     = HEIGHT//UNITS
IM_BEATS   = BLOCKS * COLS * CIN

KW_MAX     = 3
KH_MAX     = 3
CIN_MAX    = 1024
COLS_MAX   = 384
BLOCKS_MAX = 32
UNITS_EDGES = UNITS + KH_MAX -1
EFF_CORES  = (KW_MAX // K)*CORES 
assert HEIGHT % UNITS == 0


# %%
im_pipe = np.zeros((UNITS_EDGES,1),np.int8)
im_pipe[0,0] = IS_NOT_MAX
im_pipe[1,0] = IS_MAX
im_pipe[2,0] = IS_LRELU
im_pipe[3,0] = KH-1

im_pipe = np.append(im_pipe, np.arange(IM_BEATS*UNITS_EDGES).astype(np.int8))

np.savetxt('../../data/im_pipe_in.txt', im_pipe, fmt='%d')

im_pipe_2 = 100 + np.arange(IM_BEATS*UNITS_EDGES).astype(np.int8)
np.savetxt('../../data/im_pipe_in_2.txt', im_pipe_2, fmt='%d')


# %%
LRELU_BEATS = 13 if (KW == 1) else 21
R_WIDTH = KW_MAX * CORES
R_DEPTH = KH * CIN

BITS_KW_MAX     = int(np.ceil(np.log2(KW_MAX    )))
BITS_KH_MAX     = int(np.ceil(np.log2(KH_MAX    )))
BITS_CIN_MAX    = int(np.ceil(np.log2(CIN_MAX   )))
BITS_COLS_MAX   = int(np.ceil(np.log2(COLS_MAX  )))
BITS_BLOCKS_MAX = int(np.ceil(np.log2(BLOCKS_MAX)))


weights_config = 0
weights_config |= (KW    -1)
weights_config |= (KH    -1) << (BITS_KW_MAX)
weights_config |= (CIN   -1) << (BITS_KW_MAX + BITS_KH_MAX)
weights_config |= (COLS  -1) << (BITS_KW_MAX + BITS_KH_MAX + BITS_CIN_MAX)
weights_config |= (BLOCKS-1) << (BITS_KW_MAX + BITS_KH_MAX + BITS_CIN_MAX + BITS_COLS_MAX)

bin(weights_config)


# %%
data = np.array(weights_config, np.uint32)
data = np.frombuffer(data.tobytes(), np.uint8)

lrelu_data = np.arange(LRELU_BEATS)[:,np.newaxis]
lrelu_data = np.repeat(lrelu_data, R_WIDTH, 1)
lrelu_data = lrelu_data + np.arange(R_WIDTH)[np.newaxis,:]*10
lrelu_data = lrelu_data.flatten()

data =np.append(data, lrelu_data)

weights = np.arange(R_DEPTH)[:,np.newaxis]
weights = np.repeat(weights, R_WIDTH, 1)
weights = weights + np.arange(R_WIDTH)[np.newaxis,:]*10
weights = weights.flatten()

data = np.append(data, weights)


# %%
np.savetxt('../../data/weights_rot_in.txt', data, fmt='%d')


# %%
im_pipe


# %%
lrelu_data


# %%
weights


# %%
data


# %%
im_0_flat = np.arange(IM_BEATS*UNITS_EDGES).astype(np.int8)
im_1_flat = 100 + im_0_flat
weights_flat = weights

im_0_mid = im_0_flat.reshape(BLOCKS,COLS,CIN,UNITS_EDGES)
im_1_mid = im_1_flat.reshape(BLOCKS,COLS,CIN,UNITS_EDGES)
kernel = weights.reshape(CIN,K,EFF_CORES,K)

assert BLOCKS == 1
im_0_mid = im_0_mid.reshape(COLS,CIN,UNITS_EDGES)
im_1_mid = im_1_mid.reshape(COLS,CIN,UNITS_EDGES)

im_0 = np.zeros((COLS, CIN, 3*UNITS), np.int32)
im_1 = np.zeros((COLS, CIN, 3*UNITS), np.int32)

start_idx = UNITS-(KH_MAX -1)//2
im_0 [:,:,start_idx:start_idx+UNITS_EDGES] = im_0_mid
im_1 [:,:,start_idx:start_idx+UNITS_EDGES] = im_1_mid

im_0 = im_0.transpose(2,0,1)
im_1 = im_1.transpose(2,0,1)
kernel = kernel.transpose(2,1,3,0).astype(np.int32)


# %%
data.shape


# %%
def conv2d_einsum(img,kernel):
    pad_h = 0 #kernel.shape[0]//2
    pad_w = kernel.shape[1]//2
    img_pad     = np.pad(img[0],((pad_h,pad_h),(pad_w,pad_w),(0,0)),'constant')

    sub_shape   = tuple(np.subtract(img_pad.shape, kernel.shape) + 1)
    strd        = np.lib.stride_tricks.as_strided
    submatrices = strd(img_pad,kernel.shape + sub_shape,img_pad.strides * 2, writeable=False)

    out = np.einsum('ijk,ijkmno->mn', kernel, submatrices,optimize='greedy')[np.newaxis,:]

    return out


# %%
im_0_out = conv2d_einsum(im_0[np.newaxis,...], kernel[1])[0]
im_1_out = conv2d_einsum(im_1[np.newaxis,...], kernel[5])[0]

# start_idx = UNITS-(KH_MAX -1)//2
start_idx = UNITS
im_0_out = im_0_out[start_idx:start_idx+UNITS,:]
im_1_out = im_1_out[start_idx:start_idx+UNITS,:]


# %%
im_1_out


# %%
start_idx


# %%
print(im_0[:,:,0])
print(im_0[:,:,1])
print(im_0[:,:,2])


# %%
print('cores = 0')
print(kernel[3,0,0,:])
# print(kernel[0,0,0,:])
# print(kernel[0,0,0,:])

# print('\ncores = 1')
# print(kernel[1,:,:,0])
# print(kernel[1,:,:,1])
# print(kernel[1,:,:,2])


