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
#from read_point_cloud import * 
#from preprocess import *
import tensorflow as tf
#tf.keras.utils.set_random_seed(0)

from deepsocflow import *


(SIM, SIM_PATH) = ('xsim', "F:/Xilinx/Vivado/2022.2/bin/") if os.name=='nt' else ('verilator', '')
np.random.seed(42)

'''
Dataset
'''

NB_EPOCH = 2
BATCH_SIZE = 64
VALIDATION_SPLIT = 0.1

#input_shape = x_train.shape[1:]

scale_factor = 80.
## Load data
"""
print("loading data...")
pmtxyz = get_pmtxyz("./work/pmt_xyz.dat")
X, y = torch.load("./work/preprocessed_data.pt")
X = X/100.
y[:,:] = y[:,:]/3.0
y[:, :3] = y[:, :3]/scale_factor
y[:, :3] = y[:,:3]
#print(y[0])
X_tf = tf.convert_to_tensor(X.numpy(), dtype=tf.float32)
y_tf = tf.convert_to_tensor(y.numpy(), dtype=tf.float32)
X_tf = tf.expand_dims(X_tf, axis=2)
debug = True 
if debug:
    print("debug got called")
    small = 5000
    X_tf, y_tf = X_tf[:small], y_tf[:small]


# Update batch size
print(X_tf.shape)
n_data, n_hits, _, F_dim = X_tf.shape

## switch to match Aobo's syntax (time, charge, x, y, z) -> (x, y, z, label, time, charge)
## insert "label" feature to tensor. This feature (0 or 1) is the activation of sensor
new_X = X_tf #preprocess(X_tf)

## Shuffle Data (w/ Seed)
#np.random.seed(seed=args.seed)
#set_seed(seed=args.seed)
idx = np.random.permutation(new_X.shape[0]) 
#new_X = tf.gather(new_X, idx)
#y = tf.gather(y_tf, idx)
## Split and Load data
train_split = 0.7
val_split = 0.3
train_idx = int(new_X.shape[0] * train_split)
val_idx = int(train_idx + new_X.shape[0] * train_split)
train = tf.data.Dataset.from_tensor_slices((new_X[:train_idx], y_tf[:train_idx]))
val = tf.data.Dataset.from_tensor_slices((new_X[train_idx:val_idx], y_tf[train_idx:val_idx]))
test = tf.data.Dataset.from_tensor_slices((new_X[val_idx:], y_tf[val_idx:]))
train_loader = train.shuffle(buffer_size=len(new_X)).batch(BATCH_SIZE)
val_loader = val.batch(BATCH_SIZE)
test_loader = val.batch(BATCH_SIZE)
print(f"num. total: {len(new_X)} train: {len(train)}, val: {len(val)}, test: {len(test)}")
#print(pmtxyz.shape, tf.shape(new_X), y_tf.shape)
"""
input_shape = (64)#X_tf.shape[1:]

'''
Define Model
'''

sys_bits = SYS_BITS(x=4, k=4, b=16)

@keras.saving.register_keras_serializable()
class UserModel(XModel):
    def __init__(self, sys_bits, x_int_bits, *args, **kwargs):
        super().__init__(sys_bits, x_int_bits, *args, **kwargs)

        self.b0 = XBundle( 
            core=XDense(
                k_int_bits=0,
                b_int_bits=0,
                units=64,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0)),
        )

        self.b1 = XBundle( 
            core=XDense(
                k_int_bits=0,
                b_int_bits=0,
                units=32,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0)),
        )

        self.b2 = XBundle(
            core=XDense(
                k_int_bits=0,
                b_int_bits=0,
                units=32,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0.125)),
        )

        self.b3 = XBundle(
            core=XDense(
                k_int_bits=0,
                b_int_bits=0,
                units=5,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0.125)),
            softmax=True
        )

    def call (self, x):
        x = self.input_quant_layer(x)
        print('input', x.shape)
        x = self.b0(x)
        x = self.b1(x)
        x = self.b2(x)
        x = self.b3(x)
        return x

x = x_in =  Input(input_shape, name="input")
user_model = UserModel(sys_bits=sys_bits, x_int_bits=0)
x = user_model(x_in)

model = Model(inputs=[x_in], outputs=[x])


'''
Train Model
'''
model.compile(loss="mse", optimizer=Adam(learning_rate=0.0001), metrics=["mse"])

'''
Save & Reload
'''

save_model(model, "mnist.h5")
loaded_model = load_qmodel("mnist.h5")

#score = loaded_model.evaluate(test_loader, verbose=0)
#print(f"Test loss:{score[0]}, Test accuracy:{score[1]}")




def product_dict(**kwargs):
    for instance in itertools.product(*(kwargs.values())):
        yield dict(zip(kwargs.keys(), instance))

@pytest.mark.parametrize("PARAMS", list(product_dict(
                                        processing_elements  = [(16,32)   ],
                                        frequency_mhz        = [ 250     ],
                                        bits_input           = [ 4       ],
                                        bits_weights         = [ 4       ],
                                        bits_sum             = [ 16      ],
                                        bits_bias            = [ 16      ],
                                        max_batch_size       = [ 64      ], 
                                        max_channels_in      = [ 2048    ],
                                        max_kernel_size      = [ 9       ],
                                        max_image_size       = [ 2126    ],
                                        max_n_bundles        = [ 64      ],
                                        ram_weights_depth    = [ 20      ],
                                        ram_edges_depth      = [ 288     ],
                                        axi_width            = [ 128      ],
                                        config_baseaddr      = ["B0000000"],
                                        target_cpu_int_bits  = [ 32       ],
                                        valid_prob           = [ 1     ],
                                        ready_prob           = [ 1     ],
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
    export_inference(loaded_model, hw, hw.ROWS)
    verify_inference(loaded_model, hw, SIM=SIM, SIM_PATH=SIM_PATH)

    d_perf = predict_model_performance(hw)
    pp = pprint.PrettyPrinter(indent=4)
    print(f"Predicted Performance")
    pp.pprint(d_perf)
