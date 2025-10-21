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

SIM = 'xsim' if os.name=='nt' else 'verilator'

sys_bits = SYS_BITS(x=8, k=8, b=16)

N_BATCH = 16
N_INPUT = 8
N_OUTPUT = 16

@keras.saving.register_keras_serializable()
class UserModel(XModel):
    def __init__(self, sys_bits, x_int_bits, *args, **kwargs):
        super().__init__(sys_bits, x_int_bits, *args, **kwargs)

        self.b = XBundle(
            core=XDense(
                k_int_bits=0, b_int_bits=0, units=N_OUTPUT, use_bias=False,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type=None),),
            softmax=False
        )

    def call (self, x):
        x = self.input_quant_layer(x)
        x = self.b(x)
        return x

x = x_in =  Input([N_BATCH], name="input")
user_model = UserModel(sys_bits=sys_bits, x_int_bits=0)
x = user_model(x_in)

model = Model(inputs=[x_in], outputs=[x])

def product_dict(**kwargs):
    for instance in itertools.product(*(kwargs.values())):
        yield dict(zip(kwargs.keys(), instance))

@pytest.mark.parametrize("PARAMS", list(product_dict(
                                        processing_elements  = [(N_BATCH, N_OUTPUT)],
                                        frequency_mhz        = [ 200        ],
                                        bits_input           = [ sys_bits.x ],
                                        bits_weights         = [ sys_bits.k ],
                                        bits_sum             = [ 20         ],
                                        bits_bias            = [ sys_bits.b ],
                                        max_batch_size       = [ N_BATCH    ], 
                                        max_channels_in      = [ 128     ],
                                        max_kernel_size      = [ 3       ],
                                        max_image_size       = [ 512     ],
                                        max_n_bundles        = [ 64      ],
                                        ram_weights_depth    = [ 128     ],
                                        ram_edges_depth      = [ 16       ],
                                        axi_width            = [ 128      ],
                                        config_baseaddr      = ["40000000"],
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
    hw.export_vivado_tcl(board='pynq_z2')


    '''
    VERIFY & EXPORT
    '''
    export_inference(model, hw, batch_size=N_BATCH)
    verify_inference(model, hw, SIM=SIM)

    d_perf = predict_model_performance(hw)
    pp = pprint.PrettyPrinter(indent=4)
    print(f"Predicted Performance")
    pp.pprint(d_perf)
