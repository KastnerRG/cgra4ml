# To add a new cell, type '# %%'
# To add a new markdown cell, type '# %% [markdown]'
# %%
import numpy as np 
import pickle
from yolov2_mod_numpy import YOLOv2_Modified_Numpy

layers = pickle.load(open('yolov2_mod_int8_dict.pickle', 'rb'))


# %%
layer_lrelu = layers['leaky_relu_1']
layer_conv = layer_lrelu.prev_layer

params = layer_lrelu.requantize_params


# %%
'''
A, B, D parameters
'''

_,H,W,COUT = params['B'].shape
K,_,CIN,COUT = layer_conv.weights.shape

b_cout_clr_mtb = np.zeros((COUT,K,K), np.float16)

b_cout_clr_mtb[:,0,0] = params['B'][0,1,1,:]            # for both K=1 and K=3

if K == 3:
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


# %%
UNITS   = 8
GROUPS  = 1
COPIES  = 1
MEMBERS = 2

COLS   = 3
BLOCKS = 3
WIDTH  = COLS * BLOCKS

WORD_WIDTH_CONFIG = 8

BEATS = 16 // WORD_WIDTH_CONFIG;
VALS_CONFIG = MEMBERS // BEATS;

if K==3:
    K_MEMBERS = 1
    B_VALS = 3
else:
    K_MEMBERS = 3
    B_VALS = 1


# %%
def transform_data(data): #(H,W,C)
    data = data[0:UNITS, 0:WIDTH, 0:K_MEMBERS*GROUPS*COPIES*MEMBERS]
    data = data.reshape((UNITS, WIDTH, K_MEMBERS, MEMBERS, COPIES, GROUPS))
    data_bkmcgu = data.transpose(1,2,3,4,5,0)
    return data_bkmcgu

data_in_bkmcgu = transform_data(layer_lrelu.in_data[0])
data_out_bkmcgu = transform_data(params['a_q'][0])


# %%
# list(np.frombuffer(data_in_bkmcgu.flatten().tobytes(),np.int8))


# %%
params.keys()


# %%
a = a_cout[0:K_MEMBERS*MEMBERS*COPIES*GROUPS]
b = b_cout_clr_mtb[0:K_MEMBERS*MEMBERS*COPIES*GROUPS,:,:]

a_kmcg = a.reshape(K_MEMBERS,MEMBERS,COPIES,GROUPS)
b_kmcg_clr_mtb = b.reshape(K_MEMBERS,MEMBERS,COPIES,GROUPS, K, K)


# %%
def append_mcg(config_mcg, is_one_beat=False):
    global s_data_bmcgu

    assert config_mcg.shape == (MEMBERS,COPIES,GROUPS)
    config_cgm = config_mcg.transpose((1,2,0))
    config_cgbv = config_cgm.reshape((COPIES, GROUPS, BEATS, VALS_CONFIG))
    config_bcgv = config_cgbv.transpose(2,0,1,3)
    
    BEATS_TO_SEND = BEATS
    if is_one_beat:
        config_bcgv = config_bcgv[0][np.newaxis,...]
        BEATS_TO_SEND = 1

    config_8_bcgm = np.frombuffer(config_bcgv.tobytes(), np.int8).reshape((BEATS_TO_SEND,COPIES,GROUPS,MEMBERS))
    config_pad_bmcgu = config_8_bcgm.astype(np.int8)[...,np.newaxis].repeat(UNITS, axis=4)
    s_data_bmcgu += list(config_pad_bmcgu.flatten())


# %%
s_data_bmcgu = []

'''
D, A, B
'''

''' d '''
append_mcg(d*np.ones((MEMBERS,COPIES,GROUPS),np.float16), is_one_beat=True)

''' a '''
for k in range(K_MEMBERS):
    append_mcg(a_kmcg[k])

''' b '''
for k in range(K_MEMBERS):
    for clr in range(K):
        for mtb in range(K):
            
            append_mcg(b_kmcg_clr_mtb[k,:,:,:,clr,mtb])

s_data_bmcgu += list(data_in_bkmcgu.flatten())


# %%
data_in_bkmcgu.shape


# %%
# b_kmcg_clr_mtb
# list(b_kmcg_clr_mtb.flatten())
# a_kmcg
# d


# %%
file_path = "../fpga_support/lrelu_input.txt"
np.savetxt(file_path, np.array(s_data_bmcgu).astype(np.int32), fmt="%d")


# %%
# file_path = "../fpga_support/lrelu_np_output.txt"
# np.savetxt(file_path, data_out_bkmcgu.flatten().astype(np.int32), fmt="%d")


# %%
data = data_in_bkmcgu[:,:,:,0,0,:].reshape(BLOCKS,COLS,K_MEMBERS,MEMBERS,UNITS)

y1_bckmu = np.zeros((BLOCKS,COLS,K_MEMBERS,MEMBERS,UNITS),np.float32)
y2_bckmu = np.zeros((BLOCKS,COLS,K_MEMBERS,MEMBERS,UNITS),np.float32)

for b in range(BLOCKS):
    
    if K==3:
        if b == 0:
            b_val_km_clr_t = b_kmcg_clr_mtb[:,:,0,0,:,1]
            b_val_km_clr_m = b_kmcg_clr_mtb[:,:,0,0,:,0]
            b_val_km_clr_b = b_kmcg_clr_mtb[:,:,0,0,:,0]
        elif b == BLOCKS-1:
            b_val_km_clr_t = b_kmcg_clr_mtb[:,:,0,0,:,0]
            b_val_km_clr_m = b_kmcg_clr_mtb[:,:,0,0,:,0]
            b_val_km_clr_b = b_kmcg_clr_mtb[:,:,0,0,:,2]
        else:
            b_val_km_clr_t = b_kmcg_clr_mtb[:,:,0,0,:,0]
            b_val_km_clr_m = b_kmcg_clr_mtb[:,:,0,0,:,0]
            b_val_km_clr_b = b_kmcg_clr_mtb[:,:,0,0,:,0]

    for c in range(COLS):
        if K == 3:
            if c == 0:
                b_val_km_t = b_val_km_clr_t[:,:,1]
                b_val_km_m = b_val_km_clr_m[:,:,1]
                b_val_km_b = b_val_km_clr_b[:,:,1]
            elif c == COLS-1:
                b_val_km_t = b_val_km_clr_t[:,:,2]
                b_val_km_m = b_val_km_clr_m[:,:,2]
                b_val_km_b = b_val_km_clr_b[:,:,2]
            else:
                b_val_km_t = b_val_km_clr_t[:,:,0]
                b_val_km_m = b_val_km_clr_m[:,:,0]
                b_val_km_b = b_val_km_clr_b[:,:,0]

        for u in range(UNITS):

            if K==3:
                if u ==0:
                    b_val_km = b_val_km_t
                elif u ==1:
                    b_val_km = b_val_km_m
                else:
                    b_val_km = b_val_km_b
            else:
                b_val_km = b_kmcg_clr_mtb[:,:,0,0,0,0]

            y1_bckmu[b,c,:,:,u] = data[b,c,:,:,u].astype(np.float32) * a_kmcg[:,:,0,0].astype(np.float32) + b_val_km.astype(np.float32)

            y1_bckmu_f16 = np.float16(y1_bckmu)
            y2_bckmu[b,c,:,:,u] = ((y1_bckmu_f16[b,c,:,:,u] > 0) + (y1_bckmu_f16[b,c,:,:,u] < 0)*np.array(0.1,np.float16))*y1_bckmu_f16[b,c,:,:,u] + d


# %%
# list(y2_bcmu.flatten())


# %%
fpga_out = np.loadtxt("../fpga_support/lrelu_output_2.txt", np.int8)


# %%
fpga_out - np.round(y2_bckmu).astype(np.int8).flatten()


# %%
# fpga_out


# %%
# np.round(y2_bckmu).astype(np.int8).flatten()


# %%



