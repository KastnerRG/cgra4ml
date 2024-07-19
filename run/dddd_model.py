import os
import sys
sys.path.append("../../")
from deepsocflow import Bundle, Hardware, QModel, QInput

'''
0. Specify Hardware
'''
hw = Hardware (                          # Alternatively: hw = Hardware.from_json('hardware.json')
        processing_elements = (16, 16) , # (rows, columns) of multiply-add units
        frequency_mhz       = 250      , #  
        bits_input          = 8        , # bit width of input pixels and activations
        bits_weights        = 8        , # bit width of weights
        bits_sum            = 24       , # bit width of accumulator
        bits_bias           = 16       , # bit width of bias
        max_batch_size      = 64       , # 
        max_channels_in     = 2048     , #
        max_kernel_size     = 13       , #
        max_image_size      = 512      , #
        ram_weights_depth   = 48      , #
        ram_edges_depth     = 1344    , #
        axi_width           = 64      , #
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
XN = 16
input_shape = (XN,16) # (XN, XH, XW, CI)

QINT_BITS = 0
kq = f'quantized_bits({hw.K_BITS},{QINT_BITS},False,True,1)'
bq = f'quantized_bits({hw.B_BITS},{QINT_BITS},False,True,1)'
qr = f'quantized_relu({hw.X_BITS},{QINT_BITS},negative_slope=0)'    
qb = f'quantized_bits({hw.X_BITS},{QINT_BITS},False,False,1)'       


x = x_in = QInput(shape=input_shape[1:], batch_size=XN, hw=hw, int_bits=QINT_BITS, name='input')

x = Bundle( core= {'type':'dense', 'units':64, 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr})(x)
x = Bundle( core= {'type':'dense', 'units':32, 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr})(x)
x = Bundle( core= {'type':'dense', 'units':32, 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr})(x)
x = Bundle( core= {'type':'dense', 'units': 5, 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qb}, softmax= True)(x)


model = QModel(inputs=x_in.raw, outputs=x)

for layer in model.layers:
    layer.trainable = False

model.compile()
model.summary()


model.export_inference(x=model.random_input, hw=hw)  # Runs forward pass in float & int, compares them. Generates: config_fw.h (C firmware), weights.bin, expected.bin

(SIM, SIM_PATH) = ('xsim', "F:/Xilinx/Vivado/2022.1/bin/") if os.name=='nt' else ('verilator', '')
model.verify_inference(SIM, SIM_PATH)   # Runs SystemVerilog testbench with the model & weights, randomizing handshakes, testing with actual C firmware in simulation
