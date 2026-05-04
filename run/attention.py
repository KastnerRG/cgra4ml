import os
import pytest
import itertools
import sys
sys.path.append("../../")

from tensorflow import keras
from keras.layers import Input
from keras.models import Model, save_model
from keras.optimizers import Adam
from keras.utils import to_categorical
from qkeras.utils import load_qmodel
import numpy as np
import pprint

from deepsocflow import *
from deepsocflow.py.xlayers import XAttn #explicitly import otherwise `NameError: name 'XAttn' is not defined`


SIM = 'xsim' if os.name == 'nt' else 'verilator'

sys_bits = SYS_BITS(x=8, k=8, b=16)

N_BATCH = 2
N_TOKENS = 4
N_INPUT = 6
N_ATTN = 8


@keras.saving.register_keras_serializable()
class UserModel(XModel):
    def __init__(self, sys_bits, x_int_bits, *args, **kwargs):
        super().__init__(sys_bits, x_int_bits, *args, **kwargs)

        self.b_attn = XBundle(
            core=XAttn(
                k_int_bits=1,
                b_int_bits=4,
                units=N_ATTN,
                use_bias=False,
                scale=None,
                act=XActivation(sys_bits=sys_bits, o_int_bits=1, type=None),
            ),
            softmax=False
        )

    def call(self, x):
        x = self.input_quant_layer(x)
        x = self.b_attn(x)
        return x


x = x_in = Input([N_TOKENS, N_INPUT], name="input")
user_model = UserModel(sys_bits=sys_bits, x_int_bits=1)
x = user_model(x_in)

model = Model(inputs=[x_in], outputs=[x])


def product_dict(**kwargs):
    for instance in itertools.product(*(kwargs.values())):
        yield dict(zip(kwargs.keys(), instance))


def run_attention_reference(model, hw):
    user_model = model.layers[1]
    BUNDLES.clear()

    x_np = np.array(
        [
            [
                [0.2500, -0.1250, 0.5000, 0.0000, -0.2500, 0.1250],
                [0.0000, 0.3750, -0.2500, 0.1250, 0.2500, -0.1250],
                [0.1250, 0.2500, 0.0000, -0.3750, 0.1250, 0.2500],
                [-0.2500, 0.1250, 0.3750, 0.2500, 0.0000, -0.1250],
            ],
            [
                [-0.1250, 0.0000, 0.2500, 0.3750, -0.2500, 0.1250],
                [0.2500, 0.1250, -0.3750, 0.0000, 0.1250, -0.2500],
                [0.3750, -0.2500, 0.1250, 0.2500, -0.1250, 0.0000],
                [0.0000, 0.2500, 0.1250, -0.1250, 0.3750, -0.2500],
            ],
        ],
        dtype=np.float32,
    )

    x_qtensor = user_model.input_quant_layer(x_np)
    y_float = model(x_np)

    x_int = XTensor(tensor=x_qtensor, bits=hw.X_BITS, int=user_model.x_int_bits)
    user_model.b_attn.call_int(x_int, hw)
    y_int = user_model.b_attn.out
    attn_core = user_model.b_attn.core

    attn_rows = np.sum(attn_core.attn.ftensor.numpy(), axis=-1)
    assert np.allclose(attn_rows, 1.0, atol=2**(-attn_core.attn_frac) * N_TOKENS)

    print("input shape:       ", x_np.shape)
    print("Q shape:           ", attn_core.q.ftensor.shape)
    print("K shape:           ", attn_core.k.ftensor.shape)
    print("V shape:           ", attn_core.v.ftensor.shape)
    print("QK^T shape:        ", attn_core.dot_product.ftensor.shape)
    print("attention shape:   ", attn_core.attn.ftensor.shape)
    print("output shape:      ", y_float.shape)
    print("attention rows sum:", attn_rows)
    print("integer output:")
    print(y_int.ftensor.numpy())

    return y_float, y_int


@pytest.mark.parametrize("PARAMS", list(product_dict(
                                        processing_elements=[(N_TOKENS, N_ATTN)],
                                        frequency_mhz=[150],
                                        bits_input=[sys_bits.x],
                                        bits_weights=[sys_bits.k],
                                        bits_sum=[32],
                                        bits_bias=[sys_bits.b],
                                        max_batch_size=[N_BATCH],
                                        max_channels_in=[256],
                                        max_kernel_size=[3],
                                        max_image_size=[512],
                                        max_n_bundles=[64],
                                        ram_weights_depth=[256],
                                        ram_edges_depth=[16],
                                        axi_width=[64],
                                        config_baseaddr=["40000000"],
                                        target_cpu_int_bits=[64],
                                        valid_prob=[1],
                                        ready_prob=[1],
                                        data_dir=['vectors'],
                                    )))
def test_attention(PARAMS):

    '''
    SPECIFY HARDWARE
    '''
    hw = Hardware(**PARAMS)
    hw.export_json()
    hw = Hardware.from_json('hardware.json')
    hw.export()
    hw.export_vivado_tcl(board='pynq_z2')

    '''
    VERIFY PYTHON ATTENTION REFERENCE
    '''
    run_attention_reference(model, hw)

    # XAttn is wrapped in XBundle above, but attention export/runtime support
    # is not implemented yet, so this test intentionally stops before
    # export_inference()/verify_inference().
    d_perf = predict_model_performance(hw)
    pp = pprint.PrettyPrinter(indent=4)
    print("Predicted Performance")
    pp.pprint(d_perf)


if __name__ == "__main__":
    PARAMS = next(product_dict(
        processing_elements=[(N_TOKENS, N_ATTN)],
        frequency_mhz=[150],
        bits_input=[sys_bits.x],
        bits_weights=[sys_bits.k],
        bits_sum=[32],
        bits_bias=[sys_bits.b],
        max_batch_size=[N_BATCH],
        max_channels_in=[256],
        max_kernel_size=[3],
        max_image_size=[512],
        max_n_bundles=[64],
        ram_weights_depth=[256],
        ram_edges_depth=[16],
        axi_width=[64],
        config_baseaddr=["40000000"],
        target_cpu_int_bits=[64],
        valid_prob=[1],
        ready_prob=[1],
        data_dir=['vectors'],
    ))
    test_attention(PARAMS)
