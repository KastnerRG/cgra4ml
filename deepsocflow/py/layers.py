from qkeras import QActivation
from tensorflow.keras.layers import Layer, Input, Flatten, Add, MaxPooling2D
import numpy as np

def QInput(shape, batch_size, hw, int_bits, name=None):
    x_raw = Input(shape=shape, batch_size=batch_size, name=name)
    x = QActivation(f'quantized_bits({hw.X_BITS},{int_bits},False,True,1)')(x_raw)
    x.raw = x_raw
    x.hw = hw
    return x



