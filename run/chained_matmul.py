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

from deepsocflow import *

SIM = 'xsim' if os.name=='nt' else 'verilator'

sys_bits = SYS_BITS(x=4, k=8, b=16)

N = 16   # batch size and all matrix dimensions
D = 16   # input feature dimension

@keras.saving.register_keras_serializable()
class UserModel(XModel):
    def __init__(self, sys_bits, x_int_bits, *args, **kwargs):
        super().__init__(sys_bits, x_int_bits, *args, **kwargs)

        # Bundle 0: Z1 = A @ B  (activation output)
        self.b_ab = XBundle(
            core=XDense(
                k_int_bits=0, b_int_bits=0, units=N, use_bias=False,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu'),
            ),
            softmax=False
        )

        # Bundle 1: Z2 = A @ C  (producer — output becomes dynamic weights)
        self.b_ac = XBundle(
            core=XDense(
                k_int_bits=0, b_int_bits=0, units=N, use_bias=False,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu'),
            ),
            softmax=False
        )

        # Bundle 2: Y = Z1 @ Z2  (consumes dynamic weights from b_ac)
        self.b_z1z2 = XBundle(
            core=XDense(
                k_int_bits=0, b_int_bits=0, units=N, use_bias=False,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type=None),
            ),
            softmax=False
        )

    def call(self, a):
        a = self.input_quant_layer(a)
        z1 = self.b_ab(a)              # Z1 = A @ B
        z2 = self.b_ac(a)              # Z2 = A @ C  (fan-out on a)
        y  = self.b_z1z2(z1, w_src=z2) # Y = Z1 @ Z2
        return y

x = x_in = Input([D], name="input")
user_model = UserModel(sys_bits=sys_bits, x_int_bits=0)
x = user_model(x_in)

model = Model(inputs=[x_in], outputs=[x])

def product_dict(**kwargs):
    for instance in itertools.product(*(kwargs.values())):
        yield dict(zip(kwargs.keys(), instance))

@pytest.mark.parametrize("PARAMS", list(product_dict(
                                        processing_elements  = [(N, N)       ],
                                        frequency_mhz        = [ 150         ],
                                        bits_input           = [ sys_bits.x  ],
                                        bits_weights         = [ sys_bits.k  ],
                                        bits_sum             = [ 24          ],
                                        bits_bias            = [ sys_bits.b  ],
                                        max_batch_size       = [ N           ],
                                        max_channels_in      = [ 256         ],
                                        max_kernel_size      = [ 3           ],
                                        max_image_size       = [ 512         ],
                                        max_n_bundles        = [ 64          ],
                                        ram_weights_depth    = [ 256         ],
                                        ram_edges_depth      = [ 16          ],
                                        axi_width            = [ 64          ],
                                        config_baseaddr      = ["40000000"   ],
                                        target_cpu_int_bits  = [ 32          ],
                                        valid_prob           = [ 1           ],
                                        ready_prob           = [ 1           ],
                                        data_dir             = ['vectors'    ],
                                    )))
def test_dnn_engine(PARAMS):

    '''
    SPECIFY HARDWARE
    '''
    hw = Hardware(**PARAMS)
    hw.export_json()
    hw = Hardware.from_json('hardware.json')
    hw.export()
    hw.export_vivado_tcl(board='pynq_z2')

    '''
    VERIFY & EXPORT
    '''
    export_inference(model, hw, batch_size=N)
    verify_inference(model, hw, SIM=SIM)

    d_perf = predict_model_performance(hw)
    pp = pprint.PrettyPrinter(indent=4)
    print(f"Predicted Performance")
    pp.pprint(d_perf)
