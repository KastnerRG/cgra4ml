import os
import sys
sys.path.append("../../")
from deepsocflow import Bundle, Hardware, QModel, QInput

'''
0. Specify Hardware
'''
hw = Hardware (                          # Alternatively: hw = Hardware.from_json('hardware.json')
        processing_elements = (7, 96)  , # (rows, columns) of multiply-add units
        frequency_mhz       = 250      , #  
        bits_input          = 4        , # bit width of input pixels and activations
        bits_weights        = 4        , # bit width of weights
        bits_sum            = 24       , # bit width of accumulator
        bits_bias           = 16       , # bit width of bias
        max_batch_size      = 64       , # 
        max_channels_in     = 2048     , #
        max_kernel_size     = 13       , #
        max_image_size      = 512      , #
        ram_weights_depth   = 512      , #
        ram_edges_depth     = 524288   , #
        axi_width           = 128      , #
        target_cpu_int_bits = 32       , #
        valid_prob          = 1      , # probability in which AXI-Stream s_valid signal should be toggled in simulation
        ready_prob          = 1      , # probability in which AXI-Stream m_ready signal should be toggled in simulation
        data_dir            = 'vectors', # directory to store generated test vectors
     )
hw.export() # Generates: config_hw.svh, config_hw.tcl, config_tb.svh, hardware.json
hw.export_vivado_tcl(board='zcu104')

'''
1. Build Model 
'''
XN = 7
input_shape = (XN,224,224,3) # (XN, XH, XW, CI)

QINT_BITS = 0
kq = f'quantized_bits({hw.K_BITS},{QINT_BITS},False,True,1)'
bq = f'quantized_bits({hw.B_BITS},{QINT_BITS},False,True,1)'
qr = f'quantized_relu({hw.X_BITS},{QINT_BITS},negative_slope=0)'    
qb = f'quantized_bits({hw.X_BITS},{QINT_BITS},False,False,1)'       


x = x_in = QInput(shape=input_shape[1:], batch_size=XN, hw=hw, int_bits=QINT_BITS, name='input')

x  = Bundle( core= {'type':'conv' , 'filters':64 , 'kernel_size':7, 'strides':2, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr}, pool= {'type':'max', 'size':3, 'strides':2, 'padding':'same', 'act_str':qb} )(x) # conv1_conv
x1 = Bundle( core= {'type':'conv' , 'filters':256, 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qb} )(x) # conv2_block1_0_conv
x =      Bundle( core= {'type':'conv' , 'filters':64 , 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv2_block1_1_conv
x =      Bundle( core= {'type':'conv' , 'filters':64 , 'kernel_size':3, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv2_block1_2_conv
x = x1 = Bundle( core= {'type':'conv' , 'filters':256, 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qb}, add = {'act_str':qr})(x, x1) # conv2_block1_3_conv
# conv2_block1_add
x =      Bundle( core= {'type':'conv' , 'filters':64 , 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv2_block2_1_conv
x =      Bundle( core= {'type':'conv' , 'filters':64 , 'kernel_size':3, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv2_block2_2_conv
x = x1 = Bundle( core= {'type':'conv' , 'filters':256, 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qb}, add = {'act_str':qr})(x, x1) # conv2_block2_3_conv
# conv2_block2_add
x =      Bundle( core= {'type':'conv' , 'filters':64 , 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv2_block3_1_conv
x =      Bundle( core= {'type':'conv' , 'filters':64 , 'kernel_size':3, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv2_block3_2_conv
x = x1 = Bundle( core= {'type':'conv' , 'filters':256, 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qb}, add = {'act_str':qr})(x, x1) # conv2_block3_3_conv
# conv2_block3_add
x1 = Bundle( core= {'type':'conv' , 'filters':512, 'kernel_size':1, 'strides':2, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qb} )(x) # conv3_block1_0_conv
x =      Bundle( core= {'type':'conv' , 'filters':128, 'kernel_size':1, 'strides':2, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv3_block1_1_conv
x =      Bundle( core= {'type':'conv' , 'filters':128, 'kernel_size':3, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv3_block1_2_conv
x = x1 = Bundle( core= {'type':'conv' , 'filters':512, 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qb}, add = {'act_str':qr})(x, x1) # conv3_block1_3_conv
# conv3_block1_add
x =      Bundle( core= {'type':'conv' , 'filters':128, 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv3_block2_1_conv
x =      Bundle( core= {'type':'conv' , 'filters':128, 'kernel_size':3, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv3_block2_2_conv
x = x1 = Bundle( core= {'type':'conv' , 'filters':512, 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qb}, add = {'act_str':qr})(x, x1) # conv3_block2_3_conv
# conv3_block2_add
x =      Bundle( core= {'type':'conv' , 'filters':128, 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv3_block3_1_conv
x =      Bundle( core= {'type':'conv' , 'filters':128, 'kernel_size':3, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv3_block3_2_conv
x = x1 = Bundle( core= {'type':'conv' , 'filters':512, 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qb}, add = {'act_str':qr})(x, x1) # conv3_block3_3_conv
# conv3_block3_add
x =      Bundle( core= {'type':'conv' , 'filters':128, 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv3_block4_1_conv
x =      Bundle( core= {'type':'conv' , 'filters':128, 'kernel_size':3, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv3_block4_2_conv
x = x1 = Bundle( core= {'type':'conv' , 'filters':512, 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qb}, add = {'act_str':qr})(x, x1) # conv3_block4_3_conv
# conv3_block4_add
x1 = Bundle( core= {'type':'conv' , 'filters':1024, 'kernel_size':1, 'strides':2, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qb} )(x) # conv4_block1_0_conv
x =      Bundle( core= {'type':'conv' , 'filters':256 , 'kernel_size':1, 'strides':2, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv4_block1_1_conv
x =      Bundle( core= {'type':'conv' , 'filters':256 , 'kernel_size':3, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv4_block1_2_conv
x = x1 = Bundle( core= {'type':'conv' , 'filters':1024, 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qb}, add = {'act_str':qr})(x, x1) # conv4_block1_3_conv
# conv4_block1_add
x =      Bundle( core= {'type':'conv' , 'filters':256 , 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv4_block2_1_conv
x =      Bundle( core= {'type':'conv' , 'filters':256 , 'kernel_size':3, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv4_block2_2_conv
x = x1 = Bundle( core= {'type':'conv' , 'filters':1024, 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qb}, add = {'act_str':qr})(x, x1) # conv4_block2_3_conv
# conv4_block2_add
x =      Bundle( core= {'type':'conv' , 'filters':256 , 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv4_block3_1_conv
x =      Bundle( core= {'type':'conv' , 'filters':256 , 'kernel_size':3, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv4_block3_2_conv
x = x1 = Bundle( core= {'type':'conv' , 'filters':1024, 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qb}, add = {'act_str':qr})(x, x1) # conv4_block3_3_conv
# conv4_block3_add
x =      Bundle( core= {'type':'conv' , 'filters':256 , 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv4_block4_1_conv
x =      Bundle( core= {'type':'conv' , 'filters':256 , 'kernel_size':3, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv4_block4_2_conv
x = x1 = Bundle( core= {'type':'conv' , 'filters':1024, 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qb}, add = {'act_str':qr})(x, x1) # conv4_block4_3_conv
# conv4_block4_add
x =      Bundle( core= {'type':'conv' , 'filters':256 , 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv4_block5_1_conv
x =      Bundle( core= {'type':'conv' , 'filters':256 , 'kernel_size':3, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv4_block5_2_conv
x = x1 = Bundle( core= {'type':'conv' , 'filters':1024, 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qb}, add = {'act_str':qr})(x, x1) # conv4_block5_3_conv
# conv4_block5_add
x =      Bundle( core= {'type':'conv' , 'filters':256 , 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv4_block6_1_conv
x =      Bundle( core= {'type':'conv' , 'filters':256 , 'kernel_size':3, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv4_block6_2_conv
x = x1 = Bundle( core= {'type':'conv' , 'filters':1024, 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qb}, add = {'act_str':qr})(x, x1) # conv4_block6_3_conv
# conv4_block6_add
x1 = Bundle( core= {'type':'conv' , 'filters':2048, 'kernel_size':1, 'strides':2, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qb} )(x) # conv5_block1_0_conv
x =      Bundle( core= {'type':'conv' , 'filters':512 , 'kernel_size':1, 'strides':2, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv5_block1_1_conv
x =      Bundle( core= {'type':'conv' , 'filters':512 , 'kernel_size':3, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv5_block1_2_conv
x = x1 = Bundle( core= {'type':'conv' , 'filters':2048, 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qb}, add = {'act_str':qr})(x, x1) # conv5_block1_3_conv
# conv5_block1_add
x =      Bundle( core= {'type':'conv' , 'filters':512 , 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv5_block2_1_conv
x =      Bundle( core= {'type':'conv' , 'filters':512 , 'kernel_size':3, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv5_block2_2_conv
x = x1 = Bundle( core= {'type':'conv' , 'filters':2048, 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qb}, add = {'act_str':qr})(x, x1) # conv5_block2_3_conv
# conv5_block2_add
x =      Bundle( core= {'type':'conv' , 'filters':512 , 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv5_block3_1_conv
x =      Bundle( core= {'type':'conv' , 'filters':512 , 'kernel_size':3, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr} )(x) # conv5_block3_2_conv
x = x1 = Bundle( core= {'type':'conv' , 'filters':2048, 'kernel_size':1, 'strides':1, 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qb}, add = {'act_str':qr}, pool= {'type':'avg', 'size':7, 'strides':7, 'padding':'same', 'act_str':qb}, flatten=True )(x, x1) # conv5_block3_3_conv
# conv5_block3_add
x =      Bundle( core= {'type':'dense', 'units'  :1000,                                                 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qb}, softmax= True)(x)


model = QModel(inputs=x_in.raw, outputs=x)

for layer in model.layers:
    layer.trainable = False

model.compile()
model.summary()


model.export_inference(x=model.random_input, hw=hw)  # Runs forward pass in float & int, compares them. Generates: config_fw.h (C firmware), weights.bin, expected.bin
(SIM, SIM_PATH) = ('xsim', "F:/Xilinx/Vivado/2022.1/bin/") if os.name=='nt' else ('verilator', '')
model.verify_inference(SIM, SIM_PATH)   # Runs SystemVerilog testbench with the model & weights, randomizing handshakes, testing with actual C firmware in simulation
