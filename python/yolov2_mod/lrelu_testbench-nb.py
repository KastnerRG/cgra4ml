# To add a new cell, type '# %%'
# To add a new markdown cell, type '# %% [markdown]'
# %%
import numpy as np 
import pickle

from yolov2_mod_numpy import YOLOv2_Modified_Numpy

layers = pickle.load(open('yolov2_mod_int8_dict.pickle', 'rb'))


# %%
UNITS   = 8
GROUPS  = 1
COPIES  = 1
MEMBERS = 4

WORD_WIDTH_CONFIG = 8
KW_MAX    = 3

prefix_conv = 'conv_'
prefix_max = 'maxpool_'
prefix_lrelu = 'leaky_relu_'

assert MEMBERS % 2 == 0


# %%
i = 1
COLS   = 3
BLOCKS = 3
WIDTH  = COLS * BLOCKS

layer_lrelu = layers[f'leaky_relu_{i}']
layer_conv = layer_lrelu.prev_layer
params = layer_lrelu.requantize_params

_,H,W,COUT = params['B'].shape
KH,KW,CIN,COUT = layer_conv.weights.shape
SUB_CORES = KW_MAX//KW

# %% [markdown]
# ## Transform and append D,A,B

# %%
'''
A, B, D parameters
'''

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

a = a_cout[0:SUB_CORES*MEMBERS*COPIES*GROUPS]
b = b_cout_clr_mtb[0:SUB_CORES*MEMBERS*COPIES*GROUPS,:,:]

a_smcg = a.reshape(SUB_CORES,MEMBERS,COPIES,GROUPS)
b_smcg_clr_mtb = b.reshape(SUB_CORES,MEMBERS,COPIES,GROUPS, KW, KH)


# %%
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
    # config_pad_bmcgu = config_8_bcgm.astype(np.int8)[...,np.newaxis].repeat(UNITS, axis=4)
    config_pad_bcgmu = np.zeros((BEATS_TO_SEND,COPIES,GROUPS,MEMBERS,UNITS), config_8_bcgm.dtype)
    config_pad_bcgmu[...,0] = config_8_bcgm.astype(np.int8)
    arr += list(config_pad_bcgmu.flatten())


# %%
s_data_bcgmu = []

'''
D, A, B
'''

''' d '''
append_lrelu_config(s_data_bcgmu,d*np.ones((MEMBERS,COPIES,GROUPS),np.float16), is_one_beat=True)

''' a '''
for s in range(SUB_CORES):
    append_lrelu_config(s_data_bcgmu,a_smcg[s])

''' b '''
for s in range(SUB_CORES):
    for clr in range(KW):
        for mtb in range(KH):
            append_lrelu_config(s_data_bcgmu, b_smcg_clr_mtb[s,:,:,:,clr,mtb])

# %% [markdown]
# ## Transform and append input data

# %%
def transform_data(data): #(H,W,C)
    data = data[0:UNITS, 0:WIDTH, 0:SUB_CORES*GROUPS*COPIES*MEMBERS]
    data = data.reshape((UNITS, WIDTH, SUB_CORES, MEMBERS, COPIES, GROUPS))
    data_bscgmu = data.transpose(1,2,4,5,3,0)
    return data_bscgmu

data_in_bscgmu = transform_data(layer_lrelu.in_data[0])
data_out_bscgmu = transform_data(params['a_q'][0])

s_data_bcgmu += list(data_in_bscgmu.flatten())


# %%
file_path = "../fpga_support/lrelu_input.txt"
np.savetxt(file_path, np.array(s_data_bcgmu).astype(np.int32), fmt="%d")

# %% [markdown]
# ## Calculate manually to check

# %%
data = data_in_bscgmu[:,:,0,0,:,:].reshape(BLOCKS,COLS,SUB_CORES,MEMBERS,UNITS)

y1_bcsmu = np.zeros((BLOCKS,COLS,SUB_CORES,MEMBERS,UNITS),np.float32)
y2_bcsmu = np.zeros((BLOCKS,COLS,SUB_CORES,MEMBERS,UNITS),np.float32)

for b in range(BLOCKS):
    
    if KW==3:
        if b == 0:
            b_sm_clr_t = b_smcg_clr_mtb[:,:,0,0,:,1]
            b_sm_clr_m = b_smcg_clr_mtb[:,:,0,0,:,0]
            b_sm_clr_b = b_smcg_clr_mtb[:,:,0,0,:,0]
        elif b == BLOCKS-1:
            b_sm_clr_t = b_smcg_clr_mtb[:,:,0,0,:,0]
            b_sm_clr_m = b_smcg_clr_mtb[:,:,0,0,:,0]
            b_sm_clr_b = b_smcg_clr_mtb[:,:,0,0,:,2]
        else:
            b_sm_clr_t = b_smcg_clr_mtb[:,:,0,0,:,0]
            b_sm_clr_m = b_smcg_clr_mtb[:,:,0,0,:,0]
            b_sm_clr_b = b_smcg_clr_mtb[:,:,0,0,:,0]

    for c in range(COLS):
        if KW == 3:
            if c == 0:
                b_sm_t = b_sm_clr_t[:,:,1]
                b_sm_m = b_sm_clr_m[:,:,1]
                b_sm_b = b_sm_clr_b[:,:,1]
            elif c == COLS-1:
                b_sm_t = b_sm_clr_t[:,:,2]
                b_sm_m = b_sm_clr_m[:,:,2]
                b_sm_b = b_sm_clr_b[:,:,2]
            else:
                b_sm_t = b_sm_clr_t[:,:,0]
                b_sm_m = b_sm_clr_m[:,:,0]
                b_sm_b = b_sm_clr_b[:,:,0]

        for u in range(UNITS):

            if KW==3:
                if u ==0:
                    b_sm = b_sm_t
                elif u == UNITS-1:
                    b_sm = b_sm_b
                else:
                    b_sm = b_sm_m
            else:
                b_sm = b_smcg_clr_mtb[:,:,0,0,0,0]

            y1_bcsmu[b,c,:,:,u] = data[b,c,:,:,u].astype(np.float32) * a_smcg[:,:,0,0].astype(np.float32) + b_sm.astype(np.float32)

            y1_bcsmu_f16 = np.float16(y1_bcsmu)
            y2_bcsmu[b,c,:,:,u] = ((y1_bcsmu_f16[b,c,:,:,u] > 0) + (y1_bcsmu_f16[b,c,:,:,u] < 0)*np.array(0.1,np.float16))*y1_bcsmu_f16[b,c,:,:,u] + d
KW


# %%
fpga_out = np.loadtxt("../fpga_support/lrelu_output_2.txt", np.int8)

error = fpga_out - np.round(y2_bcsmu).astype(np.int8).flatten()
error_bcsmu = error.reshape((BLOCKS,COLS,SUB_CORES,MEMBERS,UNITS))

# print(error_bcsmu.shape)
print(np.sum(np.abs(error)))


# %%



