#!/usr/bin/env python
# coding: utf-8

# In[5]:


import numpy as np 
import pickle
from yolov2_mod_numpy import YOLOv2_Modified_Numpy
import os
from fpga_debug_utils import *

i_layers = 1

CONFIG = SysConfig(
    CONV_UNITS = 4,
    MEMBERS    = 4,
    COPIES     = 2,
    GROUPS     = 2,
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
    ADDR_IN_LUT  = '0x00001000'
)


# mwr -bin -file D:/cnn-fpga/data/weights_all.bin 0x08000000 10232828; mwr -bin -file D:/cnn-fpga/data/1_conv_in.bin 0x02000000 110594; 

# # Test Conv Out = Leaky Relu In

# In[13]:


conv_out     = make_conv_out(1,CONFIG)
conv_out_sim = np.loadtxt(f"{CONFIG.DATA_DIR}{1}_conv_out_sim_0.txt",np.int32)

error = conv_out_sim - conv_out[0].flatten()[:conv_out_sim.size]
np.sum(error)


# # Test Leaky Relu Out / Max In

# In[2]:


i_layers = 3
THRES = 1

lrelu_out = make_lrelu_out(i_layers,CONFIG)
lrelu_out_sim_flat = np.loadtxt(f"{CONFIG.DATA_DIR}{i_layers}_lrelu_out_sim_0.txt",np.int8)
lrelu_out_sim = lrelu_out_sim_flat.reshape(lrelu_out[0].shape)

'''
Invalid cores output 0+d=d. Remove d to compare.
'''

for i_subcore in range(lrelu_out.shape[3]): #each subcore
    for i_core in range(CONFIG.CORES):
        if np.all(lrelu_out_sim[:,:,i_subcore,i_core,:]==CONFIG.LAYERS[f'{CONFIG.PREFIX_LRELU}{i_layers}'].requantize_params['D']):
            lrelu_out_sim[:,:,s,c,:] = 0

error = lrelu_out[0] - lrelu_out_sim
sum_abs_error = np.sum(np.abs(error))

np.savetxt("where_err.txt",np.argwhere(error > THRES),fmt='%d')

print(np.sum(abs(error)>THRES))
print(sum_abs_error/lrelu_out_sim.size)


# In[20]:


# layers[f'{prefix_lrelu}{i}'].requantize_params['B'][0,1,1,0:4]


# In[21]:


# np.unravel_index(8,(MEMBERS,COPIES,GROUPS))


# In[22]:


# b = layers[f'{prefix_lrelu}{i}'].requantize_params['B'][0,1,1,8].astype(np.float16)
# a = layers[f'{prefix_lrelu}{i}'].requantize_params['A'][0,0,0,8].astype(np.float16)
# d = layers[f'{prefix_lrelu}{i}'].requantize_params['D'].astype(np.float16)

# b, a, d


# In[23]:


# (0.003149 * 37710 + -118.75)-85.0


# # Test Accl Out 

# In[3]:


i_layers = 3

accl_out = make_accl_out(i_layers,CONFIG)
accl_out_sim_flat = np.loadtxt(f"{CONFIG.DATA_DIR}{i_layers}_output_sim_1.txt",np.int8)
accl_out_sim = accl_out_sim_flat.reshape(accl_out[0].shape)

'''
Invalid cores output 0+d=d. Remove d to compare.
'''

for i_subcore in range(accl_out.shape[3]): #each subcore
    for i_core in range(accl_out.shape[4]):
        if np.all(accl_out_sim[:,:,i_subcore,i_core,1:-1]==CONFIG.LAYERS[f'{CONFIG.PREFIX_LRELU}{i_layers}'].requantize_params['D']):
            accl_out_sim[:,:,s,c,:] = 0

error = accl_out[0] - accl_out_sim
sum_abs_error = np.sum(np.abs(error))

print(np.sum(error > 1))
print(sum_abs_error/accl_out_sim.size)


# # Test FPGA Out

# In[4]:


next_config, fpga_out = make_fpga_out(i_layers,CONFIG)

chunk_addr = f'0x04000000'
arr_size = next_config.size + fpga_out.size

hardware_out_path = os.path.abspath(f"{CONFIG.DATA_DIR}{i_layers}_fpga_out.bin")
cmd = f"mrd -bin -file {hardware_out_path} {chunk_addr} {int(np.ceil(arr_size/4))}; "

print(cmd)


# In[6]:


'''
CALCULATE ERROR
'''

THRES = 1

hardware_out_flat = np.fromfile(hardware_out_path,np.int8)[0:arr_size]
hardware_out = hardware_out_flat[CONFIG.UNITS_EDGES:].reshape(fpga_out.shape)

error = hardware_out - fpga_out
np.savetxt("where_err.txt",np.argwhere(np.abs(error) > THRES),fmt='%d')

print(np.sum(np.abs(error) > THRES))

