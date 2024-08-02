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

(SIM, SIM_PATH) = ('xsim', "E:/Vivado/2023.2/bin/") if os.name=='nt' else ('verilator', '')


input_shape = (14,14,256)
sys_bits = SYS_BITS(x=4, k=4, b=16)

@keras.saving.register_keras_serializable()
class UserModel(XModel):
    def __init__(self, sys_bits, x_int_bits, *args, **kwargs):
        super().__init__(sys_bits, x_int_bits, *args, **kwargs)

        self.b0 = XBundle( 
            core=XConvBN( 
                k_int_bits=0, b_int_bits=0, filters=1024, kernel_size=1,strides=1,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type=None),),
            # add_act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0)
        )

        self.b1 = XBundle( 
            core=XConvBN(
                k_int_bits=0, b_int_bits=0, filters=256, kernel_size=1,strides=1,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0),),
        )

        self.b2 = XBundle( 
            core=XConvBN(
                k_int_bits=0, b_int_bits=0, filters=256, kernel_size=3,strides=1,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0),),
        )

        self.b3 = XBundle( 
            core=XConvBN( 
                k_int_bits=0, b_int_bits=0, filters=1024, kernel_size=1,strides=1,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type=None),),
            add_act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0)
        )

        self.b4 = XBundle( 
            core=XConvBN( 
                k_int_bits=0, b_int_bits=0, filters=2048, kernel_size=1,strides=2,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type=None),),
            # add_act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0)
        )


    def call (self, x):
        x = self.input_quant_layer(x)

        x = x_skip15 = self.b0(x) # 39
        x = self.b1(x) # 40
        x = self.b2(x) # 41
        x = self.b3(x, x_skip15) # 42
        x = self.b4(x) # 43

        return x

x = x_in =  Input(input_shape, name="input")
user_model = UserModel(sys_bits=sys_bits, x_int_bits=0)
x = user_model(x_in)

model = Model(inputs=[x_in], outputs=[x])
model.compile(loss="categorical_crossentropy", optimizer=Adam(learning_rate=0.0001), metrics=["accuracy"])

'''
Save & Reload
'''
save_model(model, "resnet50.h5")
loaded_model = load_qmodel("resnet50.h5")

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
    export_inference(loaded_model, hw, batch_size=1)
    verify_inference(loaded_model, hw, SIM=SIM, SIM_PATH=SIM_PATH)

    d_perf = predict_model_performance(hw)
    pp = pprint.PrettyPrinter(indent=4)
    print(f"Predicted Performance")
    pp.pprint(d_perf)
