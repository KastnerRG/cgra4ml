from qkeras import QActivation
from tensorflow.keras.layers import Layer, Input, Flatten, Add, MaxPooling2D
import numpy as np

def QInput(shape, batch_size, hw, int_bits, name=None):
    x_raw = Input(shape=shape, batch_size=batch_size, name=name)
    x = QActivation(f'quantized_bits({hw.X_BITS},{int_bits},False,True,1)')(x_raw)
    x.raw = x_raw
    x.hw = hw
    return x


class Tensor:
    def __init__(self, float, bits, frac):
        self.float = float
        self.bits = bits
        self.frac = frac

    def __stout__(self):
        return f'{self.float} ({self.bits}, {self.frac})'
    
    def __add__(self, other):

        '''
        Add self & other while preserving precision
        '''
        
        self_int_bits = self.bits-self.frac
        other_int_bits = other.bits-other.frac

        out_frac = max(self.frac, other.frac)
        out_int_bits = max(self_int_bits, other_int_bits)
        
        out_bits = 1 + out_int_bits + out_frac # +1 to allow overflow

        self_shift = out_frac-self.frac
        other_shift = out_frac-other.frac

        out_float = (self.float << self_shift) + (other.float << other_shift)

        return Tensor(float=out_float, frac=out_frac, bits=out_bits)
