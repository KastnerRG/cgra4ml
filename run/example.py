import sys
sys.path.append("../../")
from deepsocflow import Bundle, Hardware, QModel, QInput
from tensorflow import keras
from keras.layers import Input, Flatten
from qkeras import Model
from qkeras.utils import load_qmodel

import numpy as np
from keras.datasets import mnist
from keras.optimizers import Adam
from keras.utils import to_categorical

'''
0. Specify Hardware
'''
hw = Hardware (                          # Alternatively: hw = Hardware.from_json('hardware.json')
        processing_elements = (8, 24)  , # (rows, columns) of multiply-add units
        frequency_mhz       = 250      , #  
        bits_input          = 8        , # bit width of input pixels and activations
        bits_weights        = 8        , # bit width of weights
        bits_sum            = 24       , # bit width of accumulator
        bits_bias           = 16       , # bit width of bias
        max_batch_size      = 64       , # 
        max_channels_in     = 2048     , #
        max_kernel_size     = 13       , #
        max_image_size      = 512      , #
        ram_weights_depth   = 20       , #
        ram_edges_depth     = 288      , #
        axi_width           = 64       , #
        target_cpu_int_bits = 32       , #
        valid_prob          = 1        , # probability in which AXI-Stream s_valid signal should be toggled in simulation
        ready_prob          = 1        , # probability in which AXI-Stream m_ready signal should be toggled in simulation
        data_dir            = 'vectors', # directory to store generated test vectors
     )
hw.export() # Generates: config_hw.svh, config_hw.tcl, config_tb.svh, hardware.json
hw.export_vivado_tcl(board='zcu104')


'''
Dataset
'''

NB_EPOCH = 2
BATCH_SIZE = 64
VERBOSE = 1
VALIDATION_SPLIT = 0.1
NB_CLASSES = 10

(x_train, y_train), (x_test, y_test) = mnist.load_data()

x_train = x_train.astype("float32")[..., np.newaxis] / 256.0
x_test = x_test.astype("float32")[..., np.newaxis] / 256.0

print(f"train.shape: {x_train.shape}, test.shape: {x_test.shape}")
print("labels[0:10]: ", y_train[0:10])

y_train = to_categorical(y_train, NB_CLASSES)
y_test = to_categorical(y_test, NB_CLASSES)

'''
1. Build Model 
'''
XN = 1
input_shape = (XN,18,18,3) # (XN, XH, XW, CI)

QINT_BITS = 0
qq = f'quantized_bits({hw.K_BITS},{QINT_BITS},False,True,1)'
qr = f'quantized_relu({hw.X_BITS},{QINT_BITS},negative_slope=0)'    
ql = f'quantized_relu({hw.X_BITS},{QINT_BITS},negative_slope=0.125)'
kq = bq = qq


@keras.saving.register_keras_serializable()
class UserModel(QModel):

    def __init__(self, x_bits, x_int_bits):
        super().__init__(x_bits, x_int_bits)
        self.b1 = Bundle( core= {'type':'conv' , 'filters':8 , 'kernel_size':(11,11), 'strides':(2,1), 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr}, pool= {'type':'avg', 'size':(3,4), 'strides':(2,3), 'padding':'same', 'act_str':f'quantized_bits({x_bits},0,False,False,1)'})
        # self.b2 = Bundle( core= {'type':'conv' , 'filters':8 , 'kernel_size':( 1, 1), 'strides':(1,1), 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qq}, add = {'act_str':f'quantized_bits({x_bits},0,False,True,1)'})
        # self.b3 = Bundle( core= {'type':'conv' , 'filters':8 , 'kernel_size':( 7, 7), 'strides':(1,1), 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':False, 'act_str':qq}, add = {'act_str':f'quantized_bits({x_bits},0,False,True,1)'})
        # self.b4 = Bundle( core= {'type':'conv' , 'filters':8 , 'kernel_size':( 5, 5), 'strides':(1,1), 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':ql}, add = {'act_str':f'quantized_bits({x_bits},0,False,True,1)'})
        self.b5 = Bundle( core= {'type':'conv' , 'filters':24, 'kernel_size':( 3, 3), 'strides':(1,1), 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr},)
        # self.b6 = Bundle( core= {'type':'conv' , 'filters':10, 'kernel_size':( 1, 1), 'strides':(1,1), 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':ql}) #, flatten= True)
        self.flat = Flatten()
        self.b7 = Bundle( core= {'type':'dense', 'units'  :10,                                                           'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':ql}, softmax= True)

    def call(self, input_tensor, training=False):
        x = self.quantize_input(input_tensor) # implicit, from QModel

        x = x_skip1 = self.b1(x)
        # x = x_skip2 = self.b2(x, x_skip1)
        # x =           self.b3(x, x_skip2)
        # x =           self.b4(x, x_skip1)
        x =           self.b5(x)
        # x =           self.b6(x)
        x = self.flat(x)
        x =           self.b7(x)
        return x

    # def __init__(self, x_bits, x_int_bits):
    #     super().__init__(x_bits, x_int_bits)

    #     self.b1 = Bundle( core= {'type':'conv' , 'filters':32 , 'kernel_size':(3,3), 'strides':(2,2), 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':qr})
    #     self.flat = Flatten()
    #     self.b4 = Bundle( core= {'type':'dense', 'units'  :10,                                                          'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':ql}, softmax= True)
        
    # def call(self, input_tensor, training=False):
    #     x = self.quantize_input(input_tensor)

    #     x = self.b1(x)
    #     x = self.flat(x)
    #     x = self.b4(x)
    #     return x

x_in =  Input(x_train.shape[1:], name="input")
user_model = UserModel(x_bits=hw.X_BITS, x_int_bits=0)
x_out = user_model(x_in)
model = Model(inputs=[x_in], outputs=[x_out])

model.compile(loss="categorical_crossentropy", optimizer=Adam(learning_rate=0.0001), metrics=["accuracy"])
model.summary()


'''
2. TRAIN (using qkeras)
'''
history = model.fit(
            x_train, 
            y_train, 
            batch_size=BATCH_SIZE,
            epochs=NB_EPOCH, 
            initial_epoch=1, 
            verbose=VERBOSE,
            validation_split=VALIDATION_SPLIT)

keras.models.save_model(model, "mnist.h5")
loaded_model = load_qmodel("mnist.h5")
score = loaded_model.evaluate(x_test, y_test, verbose=0)
print(f"Test loss:{score[0]}, Test accuracy:{score[1]}")

# print(loaded_model.layers[1].conv1.get_raw())





# '''
# 3. EXPORT FOR INFERENCE
# '''
# SIM, SIM_PATH = 'xsim', "F:/Xilinx/Vivado/2022.1/bin/" # For Xilinx Vivado
# # SIM, SIM_PATH = 'verilator', "" # For Verilator

# model.export_inference(x=model.random_input, hw=hw)  # Runs forward pass in float & int, compares them. Generates: config_fw.h (C firmware), weights.bin, expected.bin
# model.verify_inference(SIM=SIM, SIM_PATH=SIM_PATH)   # Runs SystemVerilog testbench with the model & weights, randomizing handshakes, testing with actual C firmware in simulation

# '''
# 4. IMPLEMENTATION

# a. FPGA: Open vivado, source vivado_flow.tcl
# b. ASIC: Set PDK paths, run syn.tcl & pnr.tcl
# c. Compile C firmware with generated header (config_fw.h) and run on device
# '''