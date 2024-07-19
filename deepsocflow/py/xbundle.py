
import tensorflow as tf
from tensorflow import keras
from keras.layers import Flatten, Activation, Layer
from qkeras import *
import numpy as np

from deepsocflow.py.utils import *
from deepsocflow.py.xmodel import *
from deepsocflow.py.xlayers import *
from deepsocflow.py.hardware import *


@keras.saving.register_keras_serializable()
class XBundle(Layer):

    def __init__(self, core, pool=None, add_act=None, flatten=False, softmax=False, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.core = core
        self.pool = pool
        
        self.add = XAdd(act=add_act, sys_bits=core.sys_bits) if add_act else None
        self.flatten = Flatten() if flatten else None
        if flatten:
            self.flatten.out = XTensor(None, None, float_only=True)
        self.softmax = Activation("softmax") if softmax else None

        self.out = XTensor(None, None, float_only=True)
        self.softmax_max_f = 0

        self.ib = None
        self.prev_ib = None
        self.next_ibs = []
        self.next_add_ibs = []


    def call(self, input_tensor, x_add=None, training=False):

        self.ib = len(BUNDLES)
        BUNDLES.append(self)
    
        x = input_tensor
        if hasattr(x, "ib"):
            self.prev_ib = x.ib
            BUNDLES[self.prev_ib].next_ibs += [self.ib]

        x = self.core(x)
        x = self.core.act(x)

        if x_add is not None:

            assert self.add is not None, "Activation function must be provided for add layer"
            self.add.source_ib = x_add.ib
            BUNDLES[x_add.ib].next_add_ibs += [self.ib]

            x = self.add([x, x_add])
            x = self.add.act(x)
        if self.pool:
            x = self.pool(x)
            x = self.pool.act(x)
        if self.flatten:
            x = self.flatten(x)
        if self.softmax:
            x = self.softmax(x)
            self.out.ftensor = x

        self.out.ftensor = x
        x.ib = self.ib
        return x
    
    def call_int(self, x, hw):

        self.inp = x if self.ib == 0 else BUNDLES[self.prev_ib].out

        out = self.core.call_int(self.inp, hw)
        out = self.core.act.call_int(out, hw)

        if self.add:
            out = self.add.call_int(out, hw)
            out = self.add.act.call_int(out, hw)

        if self.pool:
            out = self.pool.call_int(out, hw)
            out = self.pool.act.call_int(out, hw)

        if self.flatten:
            out = XTensor(tensor=out.itensor.numpy().reshape(out.itensor.shape[0],-1), bits=out.bits, frac=out.frac, from_int=True)
            
        if self.softmax:
            softmax_out = out.ftensor.numpy().astype(np.float32)
            self.softmax_max_f = softmax_out.max()
            exp = np.exp(softmax_out - self.softmax_max_f).astype(np.float32)
            softmax_out = exp/np.sum(exp, axis=1, dtype=np.float32)[0]

            assert np.all(np.argmax(self.out.ftensor, axis=-1) == np.argmax(softmax_out, axis=-1)), \
                f"Softmax argmax does not match. \nout:{self.out.ftensor}, \nself.out:{softmax_out}"
            out.ftensor = tf.convert_to_tensor(softmax_out, dtype=tf.float32) # replace with one calc from int
            out.from_int = False
            out.float_only = True
        else:
            assert np.allclose(out.ftensor, self.out.ftensor), \
                f"Bundle output does not match. \nout:{out.ftensor.numpy().flatten()[:100]}, \nself.out:{self.out.ftensor.numpy().flatten()[:100]}"
        
        self.out = out
