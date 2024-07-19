import tensorflow as tf
from tensorflow import keras
from keras.layers import Layer
from qkeras import *
import os

from deepsocflow.py.utils import *
from deepsocflow.py.xbundle import *
from deepsocflow.py.xlayers import *
from deepsocflow.py.hardware import *



class XInputAct(QActivation):
    def __init__(self, *args, **kwargs):            
        super().__init__(*args, **kwargs)
    
    def call(self, x):
        return super().call(x)

@keras.saving.register_keras_serializable()
class XModel(Layer):

    def __init__(self, sys_bits, x_int_bits, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.sys_bits = sys_bits
        self.x_int_bits = x_int_bits
        self.input_quant_layer = XInputAct(f'quantized_bits({sys_bits.x},{x_int_bits},False,True,1)')

    def get_config(self):
        config = super().get_config().copy()
        config.update({
            'sys_bits': self.sys_bits,
            'x_int_bits': self.x_int_bits,
        })
        return config
    


def export_inference(model, hw):
    
    BUNDLES.clear()
    user_model = model.layers[1]
    input_shape = (1, *model.inputs[0].shape[1:])
    x_keras = tf.random.uniform(input_shape)
    x_qtensor = user_model.input_quant_layer(x_keras)
    out_keras = model(x_keras)

    assert hw.X_BITS == user_model.sys_bits.x
    assert hw.K_BITS == user_model.sys_bits.k
    assert hw.B_BITS >= user_model.sys_bits.b

    for i, b in enumerate(BUNDLES):
        print(f"Bundle {i}: {b}")

    x = XTensor(tensor=x_qtensor, bits=hw.X_BITS, int=user_model.x_int_bits)   


    '''
    Export
    '''
    
    
    ''' Clean the data directory'''
    os.makedirs(hw.DATA_DIR, exist_ok=True)
    for file in os.scandir(hw.DATA_DIR):
        os.remove(file.path)
    

    print("\n-----------STARTING EXPORT-----------\n")
    add_buffer_map = []
    out_buffer_map = []

    

    for ib, b in enumerate(BUNDLES):
        print(f'-----------------ib:{ib}-----------------------')
        b.call_int(x if ib==0 else None, hw)
    #     # b.export(hw, False)

