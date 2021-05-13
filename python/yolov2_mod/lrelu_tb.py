# To add a new cell, type '# %%'
# To add a new markdown cell, type '# %% [markdown]'
# %%
import numpy as np 
import pickle

from yolov2_mod_numpy import YOLOv2_Modified_Numpy
from fpga_debug_utils import *

c = SysConfig(
    CONV_UNITS = 2,
    MEMBERS    = 4,
    COPIES     = 1,
    GROUPS     = 1,
    WORD_WIDTH_CONFIG = 8,
    DATA_DIR   = '../../data/',

    LAYERS = pickle.load(open('yolov2_mod_int8_dict.pickle', 'rb')),

    PREFIX_CONV  = 'conv_',
    PREFIX_MAX   = 'maxpool_',
    PREFIX_LRELU = 'leaky_relu_',

    KW_MAX     = 3,
    KH_MAX     = 3,
    CIN_MAX    = 1024,
    COLS_MAX   = 384,

    RGB_H = 256,
    RGB_W = 384,
    
    ADDR_WEIGHTS= '0x08000000',
    ADDR_IN     = '0x02000000',
    ADDR_OUT    = '0x04000000',
    ADDR_IN_LUT = '0x00001000'
)


# %%
i_layers = 3
IS_MAX = 0
WIDTH  = 3
BLOCKS = 3
HEIGHT  = c.CONV_UNITS * BLOCKS

layer_lrelu = c.LAYERS[f'{c.PREFIX_LRELU}{i_layers}']
layer_conv = layer_lrelu.prev_layer
params = layer_lrelu.requantize_params

_,H,W,COUT = params['B'].shape
KH,KW,CIN,COUT = layer_conv.weights.shape
SUB_CORES = c.KW_MAX//KW


# %%
lrelu_config, params_dict = get_lrelu_config(i_layers,c, get_params=True)

lrelu_config = lrelu_config[0]
d = params_dict['d']
b_smcg_clr_mtb = params_dict['b_ismcg_clr_mtb'][0]
a_smcg = params_dict['a_ismcg'][0]

LRELU_BEATS,_,_ = lrelu_config.shape
lrelu_config_padded = np.zeros((LRELU_BEATS,c.CORES,c.CONV_UNITS),lrelu_config.dtype)
lrelu_config_padded[...,0] = lrelu_config[...,0]


# %%
layer_lrelu.requantize_params['B'][0,1,0,0:4]


# %%
layer_lrelu.requantize_params['A'][0,0,0,3]


# %%
def transform_data(data): #(H,W,C)
    data = data[0:HEIGHT, 0:WIDTH, 0:SUB_CORES*c.GROUPS*c.COPIES*c.MEMBERS]
    data = data.reshape((BLOCKS, c.CONV_UNITS, WIDTH, SUB_CORES, c.MEMBERS, c.COPIES, c.GROUPS))
    data_bwscmgu = data.transpose(0,2,3,5,4,6,1) # (BLOCKS, WIDTH, SUB_CORES, COPIES, MEMBERS, GROUPS, UNITS)
    return data_bwscmgu

data_in_bwscmgu = transform_data(layer_lrelu.in_data[0])
# data_out_bwscmgu = transform_data(params['a_q'][0])

s_data_ncmgu = np.concatenate([lrelu_config_padded.flatten(), data_in_bwscmgu.flatten()])
s_data_ncmgu.shape


# %%
print(layer_lrelu.in_data.shape)
# layer_lrelu.in_data[0,4,0,1] cmg 101 = 5
layer_lrelu.in_data[0,0:4,2,5]


# %%
in_data_csv = layer_lrelu.in_data[0,0:HEIGHT,0:WIDTH,0:c.MEMBERS]
in_data_csv = in_data_csv.transpose(2,0,1).reshape(HEIGHT*c.MEMBERS,WIDTH)
np.savetxt('lrelu_in.csv',in_data_csv,delimiter=',')


# %%
file_path = f"{c.DATA_DIR}lrelu_input.txt"
np.savetxt(file_path, np.array(s_data_ncmgu).astype(np.int32), fmt="%d")

# %% [markdown]
# ## Calculate manually to check

# %%
data_in_bws_mcgu = data_in_bwscmgu.transpose(0,1,2,4,3,5,6) #bsmcgu

data_in_bws_mcgu = data_in_bws_mcgu.reshape((BLOCKS,WIDTH,SUB_CORES,c.MEMBERS,c.COPIES,c.GROUPS,c.CONV_UNITS))
y1_bws_mcgu      = np.zeros((BLOCKS,WIDTH,SUB_CORES,c.MEMBERS,c.COPIES,c.GROUPS,c.CONV_UNITS),np.float32)
y2_bws_mcgu      = np.zeros((BLOCKS,WIDTH,SUB_CORES,c.MEMBERS,c.COPIES,c.GROUPS,c.CONV_UNITS),np.float32)

for ib in range(BLOCKS):
    if KW==3:
        if ib == 0:
            b_smcg_clr_t = b_smcg_clr_mtb[...,1]
            b_smcg_clr_m = b_smcg_clr_mtb[...,0]
            b_smcg_clr_b = b_smcg_clr_mtb[...,0]
        elif ib == BLOCKS-1:
            b_smcg_clr_t = b_smcg_clr_mtb[...,0]
            b_smcg_clr_m = b_smcg_clr_mtb[...,0]
            b_smcg_clr_b = b_smcg_clr_mtb[...,2]
        else:
            b_smcg_clr_t = b_smcg_clr_mtb[...,0]
            b_smcg_clr_m = b_smcg_clr_mtb[...,0]
            b_smcg_clr_b = b_smcg_clr_mtb[...,0]

    for iw in range(WIDTH):
        if KW == 3:
            if iw == 0:
                b_smcg_t = b_smcg_clr_t[...,1]
                b_smcg_m = b_smcg_clr_m[...,1]
                b_smcg_b = b_smcg_clr_b[...,1]
            elif iw == WIDTH-1:
                b_smcg_t = b_smcg_clr_t[...,2]
                b_smcg_m = b_smcg_clr_m[...,2]
                b_smcg_b = b_smcg_clr_b[...,2]
            else:
                b_smcg_t = b_smcg_clr_t[...,0]
                b_smcg_m = b_smcg_clr_m[...,0]
                b_smcg_b = b_smcg_clr_b[...,0]

        for iu in range(c.CONV_UNITS):
            for ip in range(c.COPIES):

                if KW==3:
                    if (iu ==0) and ( ip==0 if IS_MAX else True):
                        b_smcg = b_smcg_t
                    elif (iu == c.CONV_UNITS-1) and (ip==c.COPIES-1 if IS_MAX else True):
                        b_smcg = b_smcg_b
                    else:
                        b_smcg = b_smcg_m
                else:
                    b_smcg = b_smcg_clr_mtb[...,0,0]
                
                mul_1 = data_in_bws_mcgu[ib,iw,:,:,ip,:,iu].astype(np.float32) * a_smcg[:,:,ip,:].astype(np.float32)
                y1_bws_mcgu[ib,iw,:,:,ip,:,iu] = mul_1 + b_smcg[:,:,ip,:].astype(np.float32)
                y1_bws_mcgu_f16 = np.float16(y1_bws_mcgu)

                alpha = np.array(0.1,np.float16)
                c_val = ((y1_bws_mcgu_f16[ib,iw,:,:,ip,:,iu] > 0) + (y1_bws_mcgu_f16[ib,iw,:,:,ip,:,iu] < 0)*alpha)
                y2_bws_mcgu[ib,iw,:,:,ip,:,iu] = c_val * y1_bws_mcgu_f16[ib,iw,:,:,ip,:,iu] + d

                fixed_bws_mcgu = np.clip(np.round(y2_bws_mcgu), -128,127).astype(np.int8)


# %%
fpga_out = np.loadtxt(f"{c.DATA_DIR}lrelu_output_1.txt", np.int8)
fpga_out = fpga_out.reshape((BLOCKS,WIDTH,SUB_CORES,c.MEMBERS,c.COPIES,c.GROUPS,c.CONV_UNITS))
header = "B W S M C G U"

error = fpga_out - fixed_bws_mcgu

print(np.sum(np.abs(error)))


# %%
error.shape


# %%
THRES = 2

with open("where_err.txt", 'w') as f:
    f.writelines([header + '\n\n'])
    np.savetxt(f,np.argwhere(np.abs(error) > THRES),fmt='%d')


# %%
error[abs(error)>0]
