from qkeras import QActivation
from tensorflow.keras.layers import Input, Flatten, Add, MaxPooling2D
import numpy as np

# class QInput(Input):
#     def __init__(self, shape, batch_size, hw, frac_bits, name=None):

#         self.hw = hw
#         self.input_frac_bits = input_frac_bits
#         super().__init__(shape=shape, name=name)

#         int_bits = hw.X_BITS - self.frac_bits + 1

#         x = Input(shape=shape, batch_size=batch_size, name=name)
#         x = QActivation(f'quantized_bits(bits={hw.X_BITS}, integer={int_bits}, False,True,1)')(x)

#         return x



