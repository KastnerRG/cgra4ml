
import tensorflow as tf
from tensorflow import keras
from keras.layers import Flatten, Activation, Layer
from qkeras import *
import numpy as np
from copy import deepcopy

from deepsocflow.py.utils import *
from deepsocflow.py.xmodel import *
from deepsocflow.py.xlayers import *
from deepsocflow.py.hardware import *
from deepsocflow.py.dataflow import *


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
        self.softmax_frac = 0

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

        print(f"{self.ib} x: {x.shape}, prev:{self.prev_ib}")

        x = self.core(x)
        x = self.core.act(x)

        if x_add is not None:

            assert self.add is not None, "Activation function must be provided for add layer"
            self.add.source_ib = x_add.ib
            BUNDLES[x_add.ib].next_add_ibs += [self.ib]

            x = self.add([x, x_add])
            x = self.add.act(x)
        elif self.add is not None:
                raise ValueError("A Bundle initialized with add_act(), should have the add tensor passed")

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
            print(f"Bundle {self.ib} source_ib: {self.add.source_ib}")
            out = self.add.call_int(out, hw)
            out = self.add.act.call_int(out, hw)

        if self.pool:
            out = self.pool.call_int(out, hw)
            out = self.pool.act.call_int(out, hw)

        if self.flatten:
            out = XTensor(tensor=out.itensor.numpy().reshape(out.itensor.shape[0],-1), bits=out.bits, frac=out.frac, from_int=True)
            
        if self.softmax:
            self.pre_softmax = deepcopy(out)
            self.softmax_frac = out.frac
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


    def export (self, hw, is_last):

        if not self.core.type == 'conv':
            print('Conv -> Dense Reshape')
            CI,CO = self.core.w.itensor.shape
            XN, _ = self.core.x.itensor.shape
            w_int = self.core.w.itensor.numpy().reshape(1,1,CI,CO) # (CI,CO) -> (KH,KW,CI,CO)
            x_int = self.core.x.itensor.numpy().reshape(1,XN,1,CI) # (XN,CI) -> (XN, XH, XW, CI)
            y_int = self.core.y.itensor.numpy().reshape(1,XN,1,CO) # (XN,CI) -> (XN, XH, XW, CI)
            o_int = (self.pre_softmax if self.softmax else self.out).itensor.numpy().reshape(1,XN,1,CO)
        else:
            w_int = self.core.w.itensor.numpy()
            x_int = self.core.x.itensor.numpy()
            y_int = self.core.y.itensor.numpy()
            o_int = (self.pre_softmax if self.softmax else self.out).itensor.numpy()

        b_int = self.core.b.itensor.numpy() if self.core.b else None
        
        r = get_runtime_params(
            hw=hw, 
            w_shape=w_int.shape, 
            x_shape=x_int.shape, 
            o_shape=self.out.ftensor.numpy().shape, 
            core=self.core, 
            pool=self.pool,
            flatten = self.flatten,
            )
        r = create_headers(hw, r)

        assert r.KH <= hw.KH_MAX
        assert r.KW <= hw.KW_MAX
        assert r.CM <= hw.CI_MAX
        assert r.XH <= hw.XH_MAX
        assert r.XW <= hw.XW_MAX
        assert r.XN <= hw.XN_MAX

        cm_max = r.CM_0 if r.CP==1 else r.CM
        EDGES = cm_max * r.XW #* int(np.ceil(r.XH/hw.ROWS)-1)
        assert EDGES <= hw.RAM_EDGES_DEPTH or r.KH == 1, f"Edges: {EDGES} < {hw.RAM_EDGES_DEPTH}"

        assert r.XW >= r.KH//2
        ACC_WIDTH = hw.K_BITS + hw.X_BITS + clog2(r.KH*r.KW*r.CM)
        assert ACC_WIDTH <= hw.Y_BITS, f"ACC_WIDTH:{ACC_WIDTH} > Y_BITS{hw.Y_BITS}"

        print(r)
        check_sparsity(w_int, x_int)

        self.be = reorder_b_q2e_conv(b_int, hw, r) if self.core.b else None
        self.we = reorder_w_q2e_conv(w_int, hw, r)
        self.ye_exp_shape = (r.IT, r.XN, r.XL, r.XW*r.CO_PRL, hw.ROWS)
        self.ye_hw = np.zeros(self.ye_exp_shape)

        self.xe = reorder_x_q2e_conv(x_int, hw, r)
        self.ye_exp = reorder_y_q2e_conv(y_int, hw, r)
        self.o_int = o_int
        self.oe_sum_exp = o_int if is_last else reorder_y_q2e_conv(y_int, hw, r)
        self.oe_exp_nhwc = o_int
        print(f"x reshape: [int]:{self.core.x.itensor.shape}, int:{x_int.shape}. xe:{self.xe[0].shape}")

        '''
        Prepare expected outputs for each pass
        '''
        self.ye_exp_p = []
        ic_left = ic_right = 0
        for ip in range(r.CP):
            CM_p = r.CM_0 if ip==0 else r.CM
            ic_right += CM_p

            wp = w_int[:,:, ic_left:ic_right, :]
            xp = x_int[:,:,:, ic_left:ic_right ]
            yp = tf.keras.backend.conv2d(xp.astype(np.float32), wp.astype(np.float32), padding='same').numpy().astype(np.int32)
            self.ye_exp_p += [reorder_y_q2e_conv(yp, hw, r)]
            ic_left = ic_right
        self.hw, self.r = hw, r
