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

sys_bits = SYS_BITS(x=8, k=8, b=16)

N   = 16        # sequence length = batch size
D   = 16        # model dimension
H   = 2         # attention heads
d_k = D // H    # per-head key/query dimension = 8
d_v = D // H    # per-head value dimension     = 8

# Transformer encoder block — sequence sorting demo
#
# Task: given N D-dimensional tokens, output them sorted by their first feature.
#
# Architecture (no layer norm):
#   input projection → MHA → residual add → FFN → residual add
#
#   X ──> b_in (D→D) ──> x_proj ──┬── [MHA: 12 bundles] ──> mha_out
#                                  │
#                                  └── [add buffer] ──────────────────> b_res1 (D→D, +x_proj) ──> post_attn
#                                                                                                       │
#                                  ┌────────────────────────────────────────────── [add buffer] ────────┘
#                                  │
#                                  └──> b_ffn1 (D→4D, relu) ──> b_ffn2 (4D→D, +post_attn) ──> output
#
# MHA output = sum_h(head_h @ W_O_h), accumulated via x_add — no concat needed.
# b_in gives x_proj an .ib so it can be used as x_add in b_res1.

@keras.saving.register_keras_serializable()
class UserModel(XModel):
    def __init__(self, sys_bits, x_int_bits, *args, **kwargs):
        super().__init__(sys_bits, x_int_bits, *args, **kwargs)

        lin  = lambda: XActivation(sys_bits=sys_bits, o_int_bits=0, type=None)
        relu = lambda: XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu')

        # Input projection — needed to assign x_proj an .ib for the first residual
        self.b_in = XBundle(core=XDense(k_int_bits=0, b_int_bits=0, units=D, use_bias=False, act=lin()))

        # MHA sublayer (H heads)
        for h in range(H):
            setattr(self, f'b_q{h}',
                XBundle(core=XDense(k_int_bits=0, b_int_bits=0, units=d_k, use_bias=False, act=lin())))
            setattr(self, f'b_k{h}',
                XBundle(core=XDense(k_int_bits=0, b_int_bits=0, units=d_k, use_bias=False, act=lin())))
            setattr(self, f'b_v{h}',
                XBundle(core=XDense(k_int_bits=0, b_int_bits=0, units=d_v, use_bias=False, act=lin())))
            setattr(self, f'b_scores{h}',
                XBundle(core=XDense(k_int_bits=0, b_int_bits=0, units=N, use_bias=False, act=lin()),
                        softmax=True, transpose_w_src=True))
            setattr(self, f'b_out{h}',
                XBundle(core=XDense(k_int_bits=0, b_int_bits=0, units=d_v, use_bias=False, act=lin())))
            add_act = None if h == 0 else lin()
            setattr(self, f'b_proj{h}',
                XBundle(core=XDense(k_int_bits=0, b_int_bits=0, units=D, use_bias=False, act=lin()),
                        add_act=add_act))

        # First residual add: mha_out + x_proj
        self.b_res1 = XBundle(core=XDense(k_int_bits=0, b_int_bits=0, units=D,   use_bias=False, act=lin()), add_act=lin())
        # FFN sublayer: D → 4D (relu) → D
        self.b_ffn1 = XBundle(core=XDense(k_int_bits=0, b_int_bits=0, units=4*D, use_bias=False, act=relu()))
        # Second residual add: ffn_out + post_attn
        self.b_ffn2 = XBundle(core=XDense(k_int_bits=0, b_int_bits=0, units=D,   use_bias=False, act=lin()), add_act=lin())

    def call(self, x):
        x      = self.input_quant_layer(x)
        x_proj = self.b_in(x)                      # assigns .ib to x_proj for residual

        acc = None
        for h in range(H):
            q    = getattr(self, f'b_q{h}')(x_proj)
            k    = getattr(self, f'b_k{h}')(x_proj)
            v    = getattr(self, f'b_v{h}')(x_proj)
            p    = getattr(self, f'b_scores{h}')(q, w_src=k)
            head = getattr(self, f'b_out{h}')(p, w_src=v)
            if acc is None:
                acc = getattr(self, f'b_proj{h}')(head)
            else:
                acc = getattr(self, f'b_proj{h}')(head, x_add=acc)

        post_attn = self.b_res1(acc,     x_add=x_proj)    # MHA out + input projection
        ffn_mid   = self.b_ffn1(post_attn)
        return      self.b_ffn2(ffn_mid, x_add=post_attn) # FFN out + post-attn


x_in       = Input([D], name="input")
user_model = UserModel(sys_bits=sys_bits, x_int_bits=0)
x          = user_model(x_in)
model      = Model(inputs=[x_in], outputs=[x])


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
    LOAD TRAINED WEIGHTS, VERIFY & EXPORT
    '''
    model.load_weights('../sorting_transformer_weights.weights.h5')
    export_inference(model, hw, batch_size=N)
    verify_inference(model, hw, SIM=SIM)

    d_perf = predict_model_performance(hw)
    pp = pprint.PrettyPrinter(indent=4)
    print(f"Predicted Performance")
    pp.pprint(d_perf)
