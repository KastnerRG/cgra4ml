import os
import pytest
import itertools
import sys
sys.path.append("../../")
from tensorflow import keras
from keras.layers import Input
from keras.models import Model
from deepsocflow import *
import pprint

SIM = 'xsim' if os.name == 'nt' else 'verilator'

sys_bits = SYS_BITS(x=4, k=8, b=16)

N = 16   # batch size and all matrix dimensions
D = 16   # input feature dimension

# Computation graph:
#   A ──┬── B0(relu(A@B)) ──> Z1 ──┐
#       └── B1(relu(A@C)) ──> Z2 ──┤w_src  B2(softmax(relu(Z1@Z2))) ──> P ──┬── B3(relu(P@D)) ──> Z3 ──┐
#                                                                              └── B4(relu(P@E)) ──> Z4 ──┤w_src  B5(Z3@Z4) ──> Q
#
# Fan-out 1: A feeds B0 and B1  (input fan-out, identical to multi_chained_matmul.py)
# Softmax:   B2 applies non-terminal softmax — output is re-quantised and fed downstream
# Fan-out 2: P feeds B3 and B4  (intermediate fan-out from a softmax bundle)

@keras.saving.register_keras_serializable()
class UserModel(XModel):
    def __init__(self, sys_bits, x_int_bits, *args, **kwargs):
        super().__init__(sys_bits, x_int_bits, *args, **kwargs)

        relu = lambda: XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu')

        # Level 1: compute P = softmax(relu(Z1 @ Z2))  — non-terminal softmax
        self.b_ab = XBundle(core=XDense(k_int_bits=0, b_int_bits=0, units=N, use_bias=False, act=relu()))
        self.b_ac = XBundle(core=XDense(k_int_bits=0, b_int_bits=0, units=N, use_bias=False, act=relu()))
        self.b_p  = XBundle(core=XDense(k_int_bits=0, b_int_bits=0, units=N, use_bias=False, act=relu()), softmax=True)

        # Level 2: compute Q = (P@D) @ (P@E)  — P fans out to both branches
        self.b_pd = XBundle(core=XDense(k_int_bits=0, b_int_bits=0, units=N, use_bias=False, act=relu()))
        self.b_pe = XBundle(core=XDense(k_int_bits=0, b_int_bits=0, units=N, use_bias=False, act=relu()))
        self.b_q  = XBundle(core=XDense(k_int_bits=0, b_int_bits=0, units=N, use_bias=False,
                            act=XActivation(sys_bits=sys_bits, o_int_bits=0, type=None)))

    def call(self, a):
        a  = self.input_quant_layer(a)
        z1 = self.b_ab(a)               # Bundle 0: Z1 = relu(A @ B)
        z2 = self.b_ac(a)               # Bundle 1: Z2 = relu(A @ C)   (fan-out on a)
        p  = self.b_p (z1, w_src=z2)    # Bundle 2: P  = softmax(relu(Z1 @ Z2))  — non-terminal
        z3 = self.b_pd(p)               # Bundle 3: Z3 = relu(P @ D)   (fan-out on p)
        z4 = self.b_pe(p)               # Bundle 4: Z4 = relu(P @ E)   (fan-out on p)
        q  = self.b_q (z3, w_src=z4)    # Bundle 5: Q  = Z3 @ Z4
        return q


x_in = Input([D], name="input")
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
