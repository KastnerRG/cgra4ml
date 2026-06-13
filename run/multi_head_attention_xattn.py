import os
import pytest
import itertools
import sys
sys.path.insert(0, "../../")
from tensorflow import keras
from keras.layers import Input
from keras.models import Model
from deepsocflow import *
import pprint

SIM = 'xsim' if os.name == 'nt' else 'verilator'

sys_bits = SYS_BITS(x=4, k=8, b=16)

N = 16   # sequence length = batch size
D = 16   # model dimension
H = 2    # number of attention heads
# per-head dim = D // H = 8; total bundles = 6*H = 12

# Multi-head attention via XAttn(n_heads=H):
#
#   X ──┬── b_q0, b_k0, b_v0 → b_scores0 → b_out0 → b_proj0 ──────────────→ acc ─┐ x_add
#       └── b_q1, b_k1, b_v1 → b_scores1 → b_out1 → b_proj1(head + acc) ─→ output
#
# Equivalent to the explicit-bundle multi_head_attention.py but expressed as XAttn(n_heads=2).

@keras.saving.register_keras_serializable()
class UserModel(XModel):
    def __init__(self, sys_bits, x_int_bits, *args, **kwargs):
        super().__init__(sys_bits, x_int_bits, *args, **kwargs)

        self.mha = XAttn(
            k_int_bits=0,
            b_int_bits=0,
            units=D,
            seq_len=N,
            n_heads=H,
            use_bias=False,
            act=XActivation(sys_bits=sys_bits, o_int_bits=0, type=None),
        )

    def call(self, x):
        x = self.input_quant_layer(x)
        return self.mha(x)


x_in = Input([D], name="input")
user_model = UserModel(sys_bits=sys_bits, x_int_bits=0)
x = user_model(x_in)

model = Model(inputs=[x_in], outputs=[x])


def product_dict(**kwargs):
    for instance in itertools.product(*(kwargs.values())):
        yield dict(zip(kwargs.keys(), instance))


@pytest.mark.parametrize("PARAMS", list(product_dict(
                                        processing_elements  = [(N, N)      ],
                                        frequency_mhz        = [150         ],
                                        bits_input           = [sys_bits.x  ],
                                        bits_weights         = [sys_bits.k  ],
                                        bits_sum             = [24          ],
                                        bits_bias            = [sys_bits.b  ],
                                        max_batch_size       = [N           ],
                                        max_channels_in      = [256         ],
                                        max_kernel_size      = [3           ],
                                        max_image_size       = [512         ],
                                        max_n_bundles        = [64          ],
                                        ram_weights_depth    = [256         ],
                                        ram_edges_depth      = [16          ],
                                        axi_width            = [64          ],
                                        config_baseaddr      = ["40000000"  ],
                                        target_cpu_int_bits  = [32          ],
                                        valid_prob           = [1           ],
                                        ready_prob           = [1           ],
                                        data_dir             = ['vectors'   ],
                                    )))
def test_dnn_engine(PARAMS):

    hw = Hardware(**PARAMS)
    hw.export_json()
    hw = Hardware.from_json('hardware.json')
    hw.export()
    hw.export_vivado_tcl(board='pynq_z2')

    export_inference(model, hw, batch_size=N)
    verify_inference(model, hw, SIM=SIM)

    d_perf = predict_model_performance(hw)
    pp = pprint.PrettyPrinter(indent=4)
    print("Predicted Performance")
    pp.pprint(d_perf)
