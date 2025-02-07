import os
import pytest
import itertools
import sys
sys.path.append("../../")
from tensorflow import keras
from keras.layers import Input
from keras.models import Model, save_model
from keras.datasets import mnist
from keras.optimizers import Adam
from keras.utils import to_categorical
from qkeras.utils import load_qmodel
import numpy as np
import pprint
# import tensorflow as tf
#tf.keras.utils.set_random_seed(0)

from deepsocflow import *

(SIM, SIM_PATH) = ('xsim', "F:/Xilinx/Vivado/2022.2/bin/") if os.name=='nt' else ('verilator', '')

'''
Dataset
'''

# NB_EPOCH = 0
# BATCH_SIZE = 64
# VALIDATION_SPLIT = 0.1
NB_CLASSES = 10

# (x_train, y_train), (x_test, y_test) = mnist.load_data()

# x_train = x_train.astype("float32")[..., np.newaxis] / 256.0
# x_test = x_test.astype("float32")[..., np.newaxis] / 256.0

# print(f"train.shape: {x_train.shape}, test.shape: {x_test.shape}")
# print("labels[0:10]: ", y_train[0:10])

# y_train = to_categorical(y_train, NB_CLASSES)
# y_test = to_categorical(y_test, NB_CLASSES)
# # input_shape = x_train.shape[1:]

input_shape = (32, 32,3)


'''
Define Model
'''

sys_bits = SYS_BITS(x=4, k=4, b=16)

@keras.saving.register_keras_serializable()
class UserModel(XModel):
    def __init__(self, sys_bits, x_int_bits, *args, **kwargs):
        super().__init__(sys_bits, x_int_bits, *args, **kwargs)


        self.b0 = XBundle( 
            core=XConvBN( 
                k_int_bits=0, b_int_bits=0, filters=64, kernel_size=7, strides=2,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0)),
            pool=XPool(
                type='max', pool_size=3, strides=2, padding='same',
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type=None),)
            )
        
        filters = 64
        
        self.b1 = XBundle( 
            core=XConvBN( 
                k_int_bits=0, b_int_bits=0, filters=filters, kernel_size=3, strides=1,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type=None, slope=0)),
            )
        self.b2 = XBundle( 
            core=XConvBN( 
                k_int_bits=0, b_int_bits=0, filters=filters, kernel_size=3,strides=1,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type=None),),
            add_act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0)
        )

        self.b3 = XBundle( 
            core=XConvBN(
                k_int_bits=0, b_int_bits=0, filters=filters, kernel_size=3,strides=1,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0),),
        )
        self.b4 = XBundle( 
            core=XConvBN( 
                k_int_bits=0, b_int_bits=0, filters=filters, kernel_size=3,strides=1,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type=None),),
            add_act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0)
        )

        filters = 128

        self.b5 = XBundle( 
            core=XConvBN(
                k_int_bits=0, b_int_bits=0, filters=filters, kernel_size=1,strides=1,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0),),
        )
        self.b6 = XBundle( 
            core=XConvBN(
                k_int_bits=0, b_int_bits=0, filters=filters, kernel_size=3,strides=1,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0),),
        )
        self.b7 = XBundle( 
            core=XConvBN( 
                k_int_bits=0, b_int_bits=0, filters=filters, kernel_size=3,strides=1,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type=None),),
            add_act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0)
        )

        self.b8 = XBundle( 
            core=XConvBN( 
                k_int_bits=0, b_int_bits=0, filters=filters, kernel_size=3,strides=1,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type=None),)
        )
        self.b9 = XBundle( 
            core=XConvBN( 
                k_int_bits=0, b_int_bits=0, filters=filters, kernel_size=3,strides=1,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type=None),),
            add_act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0)
        )

        filters = 256
        
        self.b10 = XBundle( 
            core=XConvBN(
                k_int_bits=0, b_int_bits=0, filters=filters, kernel_size=1,strides=1,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0),),
        )
        self.b11 = XBundle( 
            core=XConvBN(
                k_int_bits=0, b_int_bits=0, filters=filters, kernel_size=3,strides=1,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0),),
        )
        self.b12 = XBundle( 
            core=XConvBN( 
                k_int_bits=0, b_int_bits=0, filters=filters, kernel_size=3,strides=1,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type=None),),
            add_act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0)
        )

        self.b13 = XBundle( 
            core=XConvBN(
                k_int_bits=0, b_int_bits=0, filters=filters, kernel_size=3,strides=1,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0),),
        )
        self.b14 = XBundle( 
            core=XConvBN( 
                k_int_bits=0, b_int_bits=0, filters=filters, kernel_size=3,strides=1,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type=None),),
            add_act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0)
        )
        
        filters = 512

        self.b15 = XBundle( 
            core=XConvBN(
                k_int_bits=0, b_int_bits=0, filters=filters, kernel_size=1,strides=1,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0),),
        )
        self.b16 = XBundle( 
            core=XConvBN(
                k_int_bits=0, b_int_bits=0, filters=filters, kernel_size=3,strides=1,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0),),
        )
        self.b17 = XBundle( 
            core=XConvBN( 
                k_int_bits=0, b_int_bits=0, filters=filters, kernel_size=3,strides=1,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type=None),),
            add_act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0)
        )

        self.b18 = XBundle( 
            core=XConvBN( 
                k_int_bits=0, b_int_bits=0, filters=filters, kernel_size=3,strides=1,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type=None),)
        )
        self.b19 = XBundle( 
            core=XConvBN( 
                k_int_bits=0, b_int_bits=0, filters=filters, kernel_size=3,strides=1,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type=None),),
            add_act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0),
            pool=XPool(
                type='avg', pool_size=2, strides=2, padding='same',
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type=None),),
            flatten=True
        )
        
        self.b20 = XBundle(
            core=XDense(
                k_int_bits=0, b_int_bits=0, units=NB_CLASSES, use_bias=False,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type=None),),
            softmax=True
        )

    def call (self, x):
        x = self.input_quant_layer(x)


        x = self.b0(x) # 0
        x_skip = x
        x = self.b1(x) # 1
        x = self.b2(x, x_skip) # 2
        x_skip = x
        x = self.b3(x) # 1
        x = self.b4(x, x_skip) # 2


        x_skip = x
        x_skip = self.b5(x_skip) # 1
        x = self.b6(x) # 1
        x = self.b7(x, x_skip) # 2
        x_skip = x
        x = self.b8(x) # 1
        x = self.b9(x, x_skip) # 1


        x_skip = x
        x_skip = self.b10(x_skip) # 1
        x = self.b11(x) # 1
        x = self.b12(x, x_skip) # 2
        x_skip = x
        x = self.b13(x) # 1
        x = self.b14(x, x_skip) # 1


        x_skip = x
        x_skip = self.b15(x_skip) # 1
        x = self.b16(x) # 1
        x = self.b17(x, x_skip) # 2
        x_skip = x
        x = self.b18(x) # 1
        x = self.b19(x, x_skip) # 1

        
        x = self.b20(x)
        return x

x = x_in =  Input(input_shape, name="input")
user_model = UserModel(sys_bits=sys_bits, x_int_bits=0)
x = user_model(x_in)

model = Model(inputs=[x_in], outputs=[x])
'''
Train Model
'''

model.compile(loss="categorical_crossentropy", optimizer=Adam(learning_rate=0.0001), metrics=["accuracy"])
# history = model.fit(
#         x_train, 
#         y_train, 
#         batch_size=BATCH_SIZE,
#         epochs=NB_EPOCH, 
#         initial_epoch=0, 
#         verbose=True,
#         validation_split=VALIDATION_SPLIT)

print(model.submodules)

for layer in model.submodules:
    try:
        print(layer.summary())
        for w, weight in enumerate(layer.get_weights()):
                print(layer.name, w, weight.shape)
    except:
        pass
# print_qstats(model.layers[1])

def summary_plus(layer, i=0):
    if hasattr(layer, 'layers'):
        if i != 0: 
            layer.summary()
        for l in layer.layers:
            i += 1
            summary_plus(l, i=i)

print(summary_plus(model)) # OK 
model.summary(expand_nested=True)


'''
Save & Reload
'''


save_model(model, "resnet50.h5")
loaded_model = load_qmodel("resnet50.h5")

# score = loaded_model.evaluate(x_test, y_test, verbose=0)
# print(f"Test loss:{score[0]}, Test accuracy:{score[1]}")




def product_dict(**kwargs):
    for instance in itertools.product(*(kwargs.values())):
        yield dict(zip(kwargs.keys(), instance))

@pytest.mark.parametrize("PARAMS", list(product_dict(
                                        processing_elements  = [(7,96)   ],
                                        frequency_mhz        = [ 250     ],
                                        bits_input           = [ 4       ],
                                        bits_weights         = [ 4       ],
                                        bits_sum             = [ 20      ],
                                        bits_bias            = [ 16      ],
                                        max_batch_size       = [ 64      ], 
                                        max_channels_in      = [ 512     ],
                                        max_kernel_size      = [ 9       ],
                                        max_image_size       = [ 512     ],
                                        max_n_bundles        = [ 64      ],
                                        ram_weights_depth    = [ 512     ],
                                        ram_edges_depth      = [ 3584    ],
                                        axi_width            = [ 128      ],
                                        config_baseaddr      = ["B0000000"],
                                        target_cpu_int_bits  = [ 32       ],
                                        valid_prob           = [ 1       ],
                                        ready_prob           = [ 1       ],
                                        data_dir             = ['vectors'],
                                    )))
def test_dnn_engine(PARAMS):

    '''
    SPECIFY HARDWARE
    '''
    hw = Hardware (**PARAMS)
    hw.export_json()
    hw = Hardware.from_json('hardware.json')
    hw.export() # Generates: config_hw.svh, config_hw.tcl
    hw.export_vivado_tcl(board='zcu104')


    '''
    VERIFY & EXPORT
    '''
    export_inference(loaded_model, hw, batch_size=hw.ROWS)
    verify_inference(loaded_model, hw, SIM=SIM, SIM_PATH=SIM_PATH)

    d_perf = predict_model_performance(hw)
    pp = pprint.PrettyPrinter(indent=4)
    print(f"Predicted Performance")
    pp.pprint(d_perf)
