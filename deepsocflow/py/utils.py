import numpy as np

def clog2(x):
    return int(np.ceil(np.log2(x)))


class QTensor:
    def __init__(self, bits, frac, tensor):
        self.bits = bits
        self.frac = frac
        self.tensor = tensor
        self.int = check_and_store(tensor.numpy())
    
    def check_and_store(self, float_np):
        int_np = float_np * 2**self.frac
        assert np.all(int_np == self.int), f"Integer check failed for tensor: \nfloat:\n{float_np}, \n*2^{frac}:\n{int_np}"
        self.int = int_np.astype(int)