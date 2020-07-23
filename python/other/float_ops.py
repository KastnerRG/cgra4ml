'''
Functions to convert a numpy array to custom datatypes
'''

import numpy as np

__author__ = "Abarajithan G"
__copyright__ = "Copyright 2019, Final Year Project"
__credits__ = ["Abarajithan G"]
__version__ = "1.0.0"
__maintainer__ = "Abarajthan G"
__email__ = "abarajithan07@gmail.com"
__status__ = "Research"

def float16_to_8(x):
    '''
    Convert a given array of float16 into custom float8s 
    of same shape, represented as uint8

    float16_array -> bytes -> int8_array -> bits -> modify exponent -> reorder -> uint8

    '''
    a = x.flatten()

    if a.dtype == np.float32:
        a = a.astype(np.float16)

    assert a.dtype == np.float16

    n = a.shape[0]
    b = a.tobytes()
    c = np.frombuffer(b, dtype=np.uint8)
    d = np.unpackbits(c)
    d = d.reshape(n, 16)
    d = np.concatenate([d[:, 8:], d[:, 0:8]], axis=1)

    # Get exponent, limit to [8,24] and -8
    # range(e16) = [0,30]
    # range(e8)  = [0,15]
    # e8 = e16 - 8

    e = d[:, 1:6]
    emp = np.zeros((n, 3), np.uint8)
    f = np.concatenate([emp, e], axis=1)
    f = np.packbits(f).astype(np.int16)
    g = f - 8
    g = g * (g > 0)
    g = g.astype(np.uint8)
    h = np.unpackbits(g).reshape(n, 8)[:, 4:]

    # Float 8 format: [sign(1), exp(4), mant(3)]

    i = np.concatenate([d[:, 0:1], h, d[:, 6:9]], axis=1)
    oi = np.packbits(i)

    return oi.reshape(x.shape)


def float8_to_16(x):
    '''
    Convert a given array of float8 (as uint8) into custom float16s 
    of same shape

    float8_array -> bytes -> int8_array -> bits -> modify exponent -> reorder -> float16

    '''
    a = x.flatten()
    assert a.dtype == np.uint8

    n = a.shape[0]
    b = a.tobytes()
    c = np.frombuffer(b, dtype=np.uint8)
    d = np.unpackbits(c)
    d = d.reshape(n, 8)

    ei = d[:, 1:5]
    eii = np.concatenate([np.zeros((n, 4), dtype=np.uint8), ei], axis=1)
    ej = np.packbits(eii)+8
    ek = np.unpackbits(ej).reshape((n, 8))
    el = ek[:, 3:]

    j = np.concatenate(
        [d[:, 0:1], el, d[:, 5:], np.zeros((n, 7), dtype=np.uint8)], axis=1)
    k = np.concatenate([j[:, 8:], j[:, 0:8]], axis=1)
    k = np.packbits(k)
    l = np.frombuffer(k.tobytes(), np.float16)

    return l.reshape(x.shape)
