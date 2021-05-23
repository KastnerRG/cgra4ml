# To add a new cell, type '# %%'
# To add a new markdown cell, type '# %% [markdown]'
# %%
import numpy as np 
import pickle
from yolov2_mod_numpy import YOLOv2_Modified_Numpy
import os
from fpga_debug_utils import *

i_layers = 1
i_itr = 0

CONFIG = SysConfig(
    CONV_UNITS = 4,
    MEMBERS    = 4,
    COPIES     = 2,
    GROUPS     = 2,
    WORD_WIDTH_CONFIG = 8,
    DATA_DIR   = 'D:/cnn-fpga/data/',

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
fpga_mwr_weights(i_layers=i_layers, c=CONFIG)


# %%
arr,shape = reshape_conv_in(i_layers=i_layers,c=CONFIG)

# %% [markdown]
# mwr -bin -file D:/cnn-fpga/data/weights_all.bin 0x08000000 10232828; mwr -bin -file D:/cnn-fpga/data/1_conv_in.bin 0x02000000 110594; 
# %% [markdown]
# # Test Conv Out = Leaky Relu In

# %%
conv_out     = make_conv_out(i_layers=i_layers,i_itr=i_itr, c=CONFIG)
conv_out_sim = np.loadtxt(f"{CONFIG.DATA_DIR}{i_layers}_conv_out_sim_0.txt",np.int32)

error = conv_out_sim - conv_out[i_itr].flatten()[:conv_out_sim.size]
np.sum(error)

# %% [markdown]
# # Test Leaky Relu Out / Max In

# %%
# i_layers = 1
THRES = 0

lrelu_out = make_lrelu_out(i_layers,CONFIG)
lrelu_out_sim_flat = np.loadtxt(f"{CONFIG.DATA_DIR}{i_layers}_lrelu_out_sim_1.txt",np.int8)
lrelu_out_sim = lrelu_out_sim_flat.reshape(lrelu_out[i_itr].shape)

'''
Invalid cores output 0+d=d. Remove d to compare.
'''

for i_subcore in range(lrelu_out.shape[3]): #each subcore
    for i_core in range(CONFIG.CORES):
        if np.all(lrelu_out_sim[:,:,i_subcore,i_core,:]==CONFIG.LAYERS[f'{CONFIG.PREFIX_LRELU}{i_layers}'].requantize_params['D']):
            lrelu_out_sim[:,:,s,c,:] = 0

error = lrelu_out[i_itr] - lrelu_out_sim
sum_abs_error = np.sum(np.abs(error))

np.savetxt("where_err.txt",np.argwhere(error > THRES),fmt='%d')

print(np.sum(abs(error)>THRES))
print(sum_abs_error/lrelu_out_sim.size)


# %%
d,v = np.modf(CONFIG.LAYERS['leaky_relu_1'].requantize_params['a_q_f16'])
np.sum(np.abs(d)==0.5)


# %%
r1 = np.round(CONFIG.LAYERS['leaky_relu_1'].requantize_params['a_q_f16'])
r2 = proper_round(CONFIG.LAYERS['leaky_relu_1'].requantize_params['a_q_f16'])

np.sum(r1 != r2)


# %%
CONFIG.LAYERS['leaky_relu_1'].requantize_params['a_q_f16'][r1 != r2]


# %%
CONFIG.LAYERS['leaky_relu_1'].requantize_params['a_q_f16'][0,0:4,7,0]


# %%
d,v = np.modf(CONFIG.LAYERS['leaky_relu_1'].requantize_params['a_q_f16'][0,0:4,7,0])
d


# %%
np.abs(error).shape


# %%
lrelu_out[0][0, 7, 0, 0, 0], lrelu_out_sim[0, 7, 0, 0, 0]


# %%
lrelu_out_sim[0, 7, 0, 0, :]


# %%
CONFIG.LAYERS['leaky_relu_1'].requantize_params['a_q_f16'][0,0:4,7,0]


# %%
CONFIG.LAYERS['conv_1'].np_out_data[0,0:4,7,0]


# %%
CONFIG.LAYERS['leaky_relu_1'].requantize_params['B'][0,0:4,7,0]


# %%
CONFIG.LAYERS['leaky_relu_1'].requantize_params['A'][0,0,0,0]


# %%
CONFIG.LAYERS['leaky_relu_1'].requantize_params['y'][0,0:4,7,0]


# %%
CONFIG.LAYERS['leaky_relu_1'].requantize_params['y_f16'][0,0:4,7,0]


# %%
np.frombuffer(np.array([54800],np.uint16).tobytes(),np.float16)


# %%
CONFIG.LAYERS['leaky_relu_1'].requantize_params['D']


# %%
np.frombuffer(np.array([0.1],np.float16).tobytes(),np.int16)
np.frombuffer(np.array([11878],np.uint16).tobytes(),np.float16)


# %%
CONFIG.LAYERS['leaky_relu_1'].requantize_params['a_q_f16'][0,0:4,7,0]


# %%
np.frombuffer(np.array([54985],np.uint16).tobytes(),np.float16)


# %%
CONFIG.LAYERS['leaky_relu_1'].requantize_params['a_q'][0,0:4,7,0]


# %%
np.round(CONFIG.LAYERS['leaky_relu_1'].requantize_params['a_q_f16'][0,0,7,0])


# %%
np.rint(-108.5)


# %%
def proper_round(x):
    '''
    np.round() rounds towards nearest even number. But xilinx seems to round towards
    '''
    d,v = np.modf(x)
    x += (d == 0.5)*1e-1 - (d == -0.5)*1e-1
    return np.round(x)


# %%
r = proper_round(CONFIG.LAYERS['leaky_relu_1'].requantize_params['a_q_f16'])


# %%
r[0,0:4,7,0]


# %%
np.modf(-108.5)


# %%
lrelu_out[0][0, 112, 0, 2, 2], lrelu_out_sim[0, 112, 0, 2, 2]


# %%
np.all(lrelu_out_sim[abs(error)>0]+97.0<0)


# %%
CONFIG.LAYERS['leaky_relu_1'].requantize_params['D']


# %%
# layers[f'{prefix_lrelu}{i}'].requantize_params['B'][0,1,1,0:4]


# %%
# np.unravel_index(8,(MEMBERS,COPIES,GROUPS))


# %%
# b = layers[f'{prefix_lrelu}{i}'].requantize_params['B'][0,1,1,8].astype(np.float16)
# a = layers[f'{prefix_lrelu}{i}'].requantize_params['A'][0,0,0,8].astype(np.float16)
# d = layers[f'{prefix_lrelu}{i}'].requantize_params['D'].astype(np.float16)

# b, a, d


# %%
# (0.003149 * 37710 + -118.75)-85.0

# %% [markdown]
# # Test Accl Out 

# %%
THRES = 1

accl_out = make_accl_out(i_layers,CONFIG)
accl_out_sim_flat = np.loadtxt(f"{CONFIG.DATA_DIR}{i_layers}_output_sim_1.txt",np.int8)
accl_out_sim = accl_out_sim_flat.reshape(accl_out[i_itr].shape)

'''
Invalid cores output 0+d=d. Remove d to compare.
'''

for i_subcore in range(accl_out.shape[3]): #each subcore
    for i_core in range(accl_out.shape[4]):
        if np.all(accl_out_sim[:,:,i_subcore,i_core,1:-1]==CONFIG.LAYERS[f'{CONFIG.PREFIX_LRELU}{i_layers}'].requantize_params['D']):
            accl_out_sim[:,:,s,c,:] = 0

error = accl_out[i_itr] - accl_out_sim
sum_abs_error = np.sum(np.abs(error))

header = 'B W S E U'
with open("where_err.txt", 'w') as f:
    f.writelines([header + '\n\n'])
    np.savetxt(f,np.argwhere(np.abs(error) > THRES),fmt='%d')

print(np.sum(error > THRES))
print(sum_abs_error/accl_out_sim.size)

# %% [markdown]
# # Test FPGA Out

# %%
c1 = fpga_mwr_image_in(i_layers,c=CONFIG)
c2 = fpga_mwr_weights(i_layers,c=CONFIG)


# %%
c1 + c2


# %%
next_config, fpga_out = make_fpga_out(i_layers,CONFIG)

chunk_addr = f'0x04000000'
arr_size = next_config.size + fpga_out.size

hardware_out_path = os.path.abspath(f"{CONFIG.DATA_DIR}{i_layers}_fpga_out.bin").replace('\\','/')
cmd = f"mrd -bin -file {hardware_out_path} {chunk_addr} {int(np.ceil(arr_size/4))}; "

print(cmd)


# %%
'''
CALCULATE ERROR
'''

THRES = 2

hardware_out_flat = np.fromfile(hardware_out_path,np.int8)[0:arr_size]
hardware_out = hardware_out_flat[CONFIG.UNITS_EDGES:].reshape(fpga_out.shape)

header = 'A B W C U'

error = hardware_out - fpga_out

with open("where_err.txt", 'w') as f:
    f.writelines([header + '\n\n'])
    np.savetxt(f,np.argwhere(np.abs(error) > THRES),fmt='%d')

print(np.sum(np.abs(error) > THRES))


# %%
hardware_out[0,0,0,0,:]


# %%
hardware_out.shape


# %%
for i in range(8):
    print(hardware_out[1,15,191,i,:], fpga_out[1,15,191,i,:])


# %%
fpga_out[0,0,0,8,:]


# %%
fpga_out[1,7,191,0,:]


# %%
fpga_out[1,7,190,0,:]


# %%
error[error>0]


# %%



