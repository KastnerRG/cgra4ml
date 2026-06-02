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
H = 4    # number of attention heads
d_k = D // H   # per-head key/query dimension = 4
d_v = D // H   # per-head value dimension     = 4

# Multi-head attention with softmax (H=4 heads):
#
#   X ──┬── B0(X@W_Q0) → Q0 ─────→ B6(softmax(Q0@K0ᵀ))  → P0 → B7(P0@V0)  → head0 → B8(head0@W_O0)              → proj0 ─┐
#       ├── B1(X@W_K0) → K0 ─(T)→ ↑                                                                                          │ x_add
#       ├── B2(X@W_V0) → V0 ─────────────────────────────────────────────────────────→ ↑                                     ↓
#       ├── B3(X@W_Q1) → Q1 ─────→ B9(softmax(Q1@K1ᵀ))  → P1 → B10(P1@V1) → head1 → B11(head1@W_O1+proj0)        → proj1 ─┐
#       ├── B4(X@W_K1) → K1 ─(T)→ ↑                                                                                          │ x_add
#       ├── B5(X@W_V1) → V1 ─────────────────────────────────────────────────────────→ ↑                                     ↓
#       ├── B12(X@W_Q2)→ Q2 ─────→ B18(softmax(Q2@K2ᵀ)) → P2 → B19(P2@V2) → head2 → B20(head2@W_O2+proj1)        → proj2 ─┐
#       ├── B13(X@W_K2)→ K2 ─(T)→ ↑                                                                                          │ x_add
#       ├── B14(X@W_V2)→ V2 ─────────────────────────────────────────────────────────→ ↑                                     ↓
#       ├── B15(X@W_Q3)→ Q3 ─────→ B21(softmax(Q3@K3ᵀ)) → P3 → B22(P3@V3) → head3 → B23(head3@W_O3+proj2)        → output
#       ├── B16(X@W_K3)→ K3 ─(T)→ ↑
#       └── B17(X@W_V3)→ V3 ─────────────────────────────────────────────────────────→ ↑
#
# Output = sum_h(head_h @ W_O_h), equivalent to Concat(heads) @ W_O (no concat needed).

@keras.saving.register_keras_serializable()
class UserModel(XModel):
    def __init__(self, sys_bits, x_int_bits, *args, **kwargs):
        super().__init__(sys_bits, x_int_bits, *args, **kwargs)

        lin = lambda: XActivation(sys_bits=sys_bits, o_int_bits=0, type=None)

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

    def call(self, x):
        x = self.input_quant_layer(x)
        acc = None
        for h in range(H):
            q    = getattr(self, f'b_q{h}')(x)
            k    = getattr(self, f'b_k{h}')(x)
            v    = getattr(self, f'b_v{h}')(x)
            p    = getattr(self, f'b_scores{h}')(q, w_src=k)
            head = getattr(self, f'b_out{h}')(p, w_src=v)
            if acc is None:
                acc = getattr(self, f'b_proj{h}')(head)
            else:
                acc = getattr(self, f'b_proj{h}')(head, x_add=acc)
        return acc


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
