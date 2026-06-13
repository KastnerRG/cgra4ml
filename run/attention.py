import os
import pytest
import itertools
import sys
sys.path.append("../../")

from tensorflow import keras
from keras.layers import Input
from keras.models import Model
import pprint

from deepsocflow import *


SIM = 'xsim' if os.name == 'nt' else 'verilator'

sys_bits = SYS_BITS(x=8, k=8, b=16)

N_TOKENS = 4
N_INPUT = 6
N_ATTN = 8


@keras.saving.register_keras_serializable()
class UserModel(XModel):
    def __init__(self, sys_bits, x_int_bits, *args, **kwargs):
        super().__init__(sys_bits, x_int_bits, *args, **kwargs)

        self.attn = XAttn(
            k_int_bits=1,
            b_int_bits=4,
            units=N_ATTN,
            seq_len=N_TOKENS,
            use_bias=False,
            scale=None,
            act=XActivation(sys_bits=sys_bits, o_int_bits=1, type=None),
        )

    def call(self, x):
        x = self.input_quant_layer(x)
        x = self.attn(x)
        return x


x_in = Input([N_INPUT], name="input")
user_model = UserModel(sys_bits=sys_bits, x_int_bits=1)
x = user_model(x_in)

model = Model(inputs=[x_in], outputs=[x])


def product_dict(**kwargs):
    for instance in itertools.product(*(kwargs.values())):
        yield dict(zip(kwargs.keys(), instance))


@pytest.mark.parametrize("PARAMS", list(product_dict(
                                        processing_elements=[(N_TOKENS, N_ATTN)],
                                        frequency_mhz=[150],
                                        bits_input=[sys_bits.x],
                                        bits_weights=[sys_bits.k],
                                        bits_sum=[32],
                                        bits_bias=[sys_bits.b],
                                        max_batch_size=[N_TOKENS],
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

    hw = Hardware(**PARAMS)
    hw.export_json()
    hw = Hardware.from_json('hardware.json')
    hw.export()
    hw.export_vivado_tcl(board='pynq_z2')

    export_inference(model, hw, batch_size=N_TOKENS)
    verify_inference(model, hw, SIM=SIM)

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
        max_batch_size=[N_TOKENS],
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
