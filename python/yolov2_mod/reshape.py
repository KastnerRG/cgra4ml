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
    MEMBERS    = 12,
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
im_arrays, _ = reshape_conv_in(i_layers=i_layers,c=CONFIG)


# %%
weights_dma_beats_0 = get_weights(i_layers=i_layers,i_itr=0,c=CONFIG)


# %%
weights_dma_beats_0.shape


# %%
fpga_mwr_weights(i_layers=i_layers, c=CONFIG)


# %%



# %%
weights_in = get_weights(i_layers=i_layers,i_itr=0,c=CONFIG)
old_weights = weights_in

c = CONFIG
LRELU_BEATS = 21
CIN,KH,max_factor = 3,3,2; c.COPIES//max_factor,c.MEMBERS,c.GROUPS,c.KW_MAX
BLOCKS = 256//c.CONV_UNITS
COLS = 384

weights_in = weights_in[0,4:]
weights_in = weights_in.reshape((LRELU_BEATS+CIN*KH),max_factor,c.COPIES//max_factor,c.MEMBERS,c.GROUPS,c.KW_MAX)
lrelu_beats = weights_in[:LRELU_BEATS,...]
weights_in = weights_in[LRELU_BEATS:,...]
weights_in = weights_in.reshape(CIN,KH,max_factor,c.COPIES//max_factor,c.MEMBERS,c.GROUPS,c.KW_MAX)
weights_in = weights_in[None,None,...]
weights_in = weights_in.repeat(repeats=COLS,axis=1).repeat(repeats=BLOCKS//max_factor,axis=0)


# %%
old_weights[0].size-4


# %%
'''
WEIGHTS IN HARDWARE ERROR
'''

THRES = 0

hardware_out_flat = np.fromfile(f'{CONFIG.DATA_DIR}{i_layers}_fpga_weights_out_flat.bin',np.int8)
hardware_out = hardware_out_flat[lrelu_beats.size:].reshape(weights_in.shape)

header = 'B W C H I C'

error = hardware_out - weights_in

with open("where_err.txt", 'w') as f:
    f.writelines([header + '\n\n'])
    np.savetxt(f,np.argwhere(np.abs(error) > THRES),fmt='%d')

print(np.sum(np.abs(error) > THRES))


# %%
hardware_im_out = np.fromfile(f'{CONFIG.DATA_DIR}{i_layers}_fpga_wimu_out_flat.bin',np.int8)


# %%
hardware_im_out[-10:]


# %%
old_weights[0].flatten()[-10:]


# %%
arr,shape = reshape_conv_in(i_layers=i_layers,c=CONFIG)


# %%
arr[0][-1,:]


# %%
arr[1].shape


# %%
(arr[1].size*2*3 + 2*4*21)/4


# %%
(32*384*3*3 + 21)*2*4


# %%
884904//4


# %%
arr[1][-1,-1,-1,:]

# %% [markdown]
# mwr -bin -file D:/cnn-fpga/data/weights_all.bin 0x08000000 10232828; mwr -bin -file D:/cnn-fpga/data/1_conv_in.bin 0x02000000 110594; 
# %% [markdown]
# # Test Conv Out = Leaky Relu In

# %%
lrelu_config, image_out, conv_out_i = make_conv_out(i_layers=i_layers,i_itr=i_itr, c=CONFIG)
conv_out_sim = np.loadtxt(f"{CONFIG.DATA_DIR}{i_layers}_conv_out_dw_sim_0.txt",np.int32)

lrelu_config_sim = conv_out_sim[:lrelu_config[0].size]
im_out_sim = conv_out_sim[lrelu_config[0].size:].reshape(image_out[0].shape)

error = image_out[0] - im_out_sim
np.sum(np.abs(error != 0))

THRES = 0
header = 'B W S C G U'
with open("where_err.txt", 'w') as f:
    f.writelines([header + '\n\n'])
    np.savetxt(f,np.argwhere(np.abs(error) > THRES),fmt='%d')


# %%
t = image_out[0].reshape(1536, 4,3, 2, 2, 4).transpose(0,2,1,3,4,5).reshape(1536, 12, 2, 2, 4)
np.sum(np.abs(t-im_out_sim != 0))


# %%
'''
OUTPUT
mrd -bin -file D:/cnn-fpga/data/1_fpga_wimu_out_flat.bin 0x04000000 1603889;

INPUT
mwr -bin -file D:/cnn-fpga/data/1_fpga_wimu_out_flat.bin 0x08000000 1603889;
6415554
'''


# %%
'''
CONV OUT HARDWARE ERROR
'''

THRES = 2

hardware_out_flat = np.fromfile(f'{CONFIG.DATA_DIR}{i_layers}_fpga_out_flat.bin',np.int32)
hardware_out = hardware_out_flat.reshape(conv_out[0].shape)

header = 'A B W C U'

error = hardware_out - conv_out[0]

with open("where_err.txt", 'w') as f:
    f.writelines([header + '\n\n'])
    np.savetxt(f,np.argwhere(np.abs(error) > THRES),fmt='%d')

print(np.sum(np.abs(error) > THRES))


# %%
hw_out = np.fromfile(f'{CONFIG.DATA_DIR}{i_layers}_fpga_out_flat.bin',np.int32)
sim_out = np.loadtxt(f"{CONFIG.DATA_DIR}{i_layers}_conv_out_sim_0.txt",np.int32)


# %%
sim1 = np.loadtxt(f"{CONFIG.DATA_DIR}{i_layers}_conv_out_sim_0_part.txt",np.int32)
sim2 = np.loadtxt(f"{CONFIG.DATA_DIR}{i_layers}_conv_out_old_part.txt",np.int32)


# %%
np.sum(hw_out - sim_out)


# %%
np.sum(sim1-sim2)


# %%
conv_out[0].size


# %%
hardware_out.shape


# %%
hardware_out_flat.shape

# %% [markdown]
# # Test Leaky Relu Out / Max In

# %%
# i_layers = 1
THRES = 1

lrelu_out = make_lrelu_out(i_layers,CONFIG)
lrelu_out_sim_flat = np.loadtxt(f"{CONFIG.DATA_DIR}{i_layers}_lrelu_out_sim_0.txt",np.int8)
lrelu_out_sim = lrelu_out_sim_flat.reshape(lrelu_out[i_itr].shape)

'''
Invalid cores output 0+d=d. Remove d to compare.
'''

for i_subcore in range(lrelu_out.shape[3]): #each subcore
    for i_copies in range(CONFIG.COPIES):
        for i_groups in range(CONFIG.GROUPS):
            if np.all(lrelu_out_sim[:,:,i_subcore,i_copies,i_groups,:]==CONFIG.LAYERS[f'{CONFIG.PREFIX_LRELU}{i_layers}'].requantize_params['D']):
                lrelu_out_sim[:,:,i_subcore,i_copies,i_groups,:] = 0

error = lrelu_out[i_itr] - lrelu_out_sim
sum_abs_error = np.sum(np.abs(error))

header = 'B W   S C G U'
with open("where_err.txt", 'w') as f:
    f.writelines([header + '\n\n'])
    np.savetxt(f,np.argwhere(np.abs(error) > THRES),fmt='%d')

print(np.sum(abs(error)>THRES))
print(sum_abs_error/lrelu_out_sim.size)


# %%
CONFIG.LAYERS['leaky_relu_1'].np_out_data[0,0:4,0,4]


# %%
CONFIG.LAYERS['leaky_relu_1'].requantize_params['B'][0,1,0,:]

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


# %%
'''
TEST FLAT FPGA
'''

fpga_out_flat = np.fromfile(f"{CONFIG.DATA_DIR}{i_layers}_fpga_out_flat.bin",np.int8)
fpga_out_flat = fpga_out_flat.reshape(accl_out[0].shape)

error = accl_out[0] - fpga_out_flat

sum_abs_error = np.sum(np.abs(error))

header = 'B W S E U'
with open("where_err.txt", 'w') as f:
    f.writelines([header + '\n\n'])
    np.savetxt(f,np.argwhere(np.abs(error) > THRES),fmt='%d')

print(np.sum(error > THRES))
print(sum_abs_error/accl_out_sim.size)


# %%
accl_out.shape

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



