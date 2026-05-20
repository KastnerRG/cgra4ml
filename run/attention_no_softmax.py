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

N = 16   # batch size = seq_len = d_k = d_v
D = 16   # input feature dimension

# Computation graph (single-head attention without softmax):
#
#   X ──┬── B0(X@W_Q) ──> Q ──────────────────> B3(Q@K^T) ──> S ──> B4(S@V) ──> output
#       ├── B1(X@W_K) ──> K ──(w_src, T)──────>  ↑
#       └── B2(X@W_V) ──> V ──(w_src)───────────────────────────────────>  ↑
#
# B3 uses transpose_w_src=True so K is stored as weight(CI=d_k, CO=N) not (CI=N, CO=d_k).
# This makes the hardware compute Q @ K^T instead of Q @ K.

@keras.saving.register_keras_serializable()
class UserModel(XModel):
    def __init__(self, sys_bits, x_int_bits, *args, **kwargs):
        super().__init__(sys_bits, x_int_bits, *args, **kwargs)

        relu = lambda: XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu')
        lin  = lambda: XActivation(sys_bits=sys_bits, o_int_bits=0, type=None)

        self.b_q      = XBundle(core=XDense(k_int_bits=0, b_int_bits=0, units=N, use_bias=False, act=relu()))
        self.b_k      = XBundle(core=XDense(k_int_bits=0, b_int_bits=0, units=N, use_bias=False, act=relu()))
        self.b_v      = XBundle(core=XDense(k_int_bits=0, b_int_bits=0, units=N, use_bias=False, act=relu()))
        self.b_scores = XBundle(core=XDense(k_int_bits=0, b_int_bits=0, units=N, use_bias=False, act=lin()),
                                transpose_w_src=True)
        self.b_out    = XBundle(core=XDense(k_int_bits=0, b_int_bits=0, units=N, use_bias=False, act=lin()))

    def call(self, x):
        x = self.input_quant_layer(x)
        q = self.b_q(x)
        k = self.b_k(x)                 # fan-out on x
        v = self.b_v(x)                 # fan-out on x
        s = self.b_scores(q, w_src=k)   # Q @ K^T
        return self.b_out(s, w_src=v)   # S @ V

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
