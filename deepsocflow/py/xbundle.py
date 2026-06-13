
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

    def __init__(self, core, pool=None, add_act=None, flatten=False, softmax=False, transpose_w_src=False, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.core = core
        self.pool = pool
        self.transpose_w_src = transpose_w_src
        
        self.add = XAdd(act=add_act, sys_bits=core.sys_bits) if add_act else None
        self.flatten = Flatten() if flatten else None
        if flatten:
            self.flatten.out = XTensor(None, None, float_only=True)
        self.softmax = Activation("softmax") if softmax else None

        self.out = XTensor(None, None, float_only=True)
        self.softmax_max_i = 0
        self.softmax_frac = 0
        self.softmax_float_out = None   # set during call_int() when softmax=True

        self.ib = None
        self.prev_ib = None
        self.next_ibs = []
        self.next_add_ibs = []

        # Dynamic-weight fields (wired in call() when w_src is provided; Step 6)
        self.next_w_ib = None       # ib of the bundle that will use this bundle's output as weights
        self.w_src_ib  = None       # ib of the bundle whose output we use as weights
        self.out_w_buffer_idx  = -1  # which w_buf slot to write into (-1 = none; set in Step 5)
        self.in_w_buffer_idx   = -1  # which w_buf slot to read weights from (-1 = static mp->w; set in Step 5)
        self.out_w_consumer_ib = -1  # ib of the bundle that will read this bundle's output as weights
        self.allow_mismatch = False  # true when int path intentionally diverges from float reference


    def call(self, input_tensor, w_src=None, x_add=None, training=False):

        self.ib = len(BUNDLES)
        BUNDLES.append(self)

        x = input_tensor
        if hasattr(x, "ib"):
            self.prev_ib = x.ib
            BUNDLES[self.prev_ib].next_ibs += [self.ib]

        if w_src is not None and hasattr(w_src, "ib"):
            self.w_src_ib = w_src.ib
            BUNDLES[w_src.ib].next_w_ib = self.ib
            BUNDLES[w_src.ib].out_w_consumer_ib = self.ib

        print(f"{self.ib} x: {x.shape}, prev:{self.prev_ib}, w_src_ib:{self.w_src_ib}")

        if self.w_src_ib is not None:
            # Dynamic weights: compute activation @ w_src in float for verification
            x = tf.matmul(x, w_src, transpose_b=self.transpose_w_src)
            x = self.core.act(x)
        else:
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

        # prev_ib is None for bundles that read directly from the model input (fan-out safe)
        self.inp = x if self.prev_ib is None else BUNDLES[self.prev_ib].out

        prev_has_softmax = self.prev_ib is not None and BUNDLES[self.prev_ib].softmax is not None
        prev_allow_mismatch = self.prev_ib is not None and getattr(BUNDLES[self.prev_ib], 'allow_mismatch', False)
        w_src_allow_mismatch = self.w_src_ib is not None and getattr(BUNDLES[self.w_src_ib], 'allow_mismatch', False)
        allow_mismatch = prev_has_softmax or prev_allow_mismatch or w_src_allow_mismatch
        validate_core = not allow_mismatch

        if self.w_src_ib is not None:
            w_src_tensor = BUNDLES[self.w_src_ib].out
            if self.transpose_w_src:
                w_t = w_src_tensor.itensor.numpy().T
                w_src_tensor = XTensor(tensor=w_t, bits=w_src_tensor.bits,
                                       frac=w_src_tensor.frac, from_int=True)
            out = self.core.call_int(self.inp, hw, w_override=w_src_tensor)
        else:
            if self.core.type == 'dense':
                out = self.core.call_int(self.inp, hw, validate_against_float=validate_core)
            else:
                out = self.core.call_int(self.inp, hw)
        out = self.core.act.call_int(out, hw, validate_against_float=not allow_mismatch)

        if self.add:
            print(f"Bundle {self.ib} source_ib: {self.add.source_ib}")
            out = self.add.call_int(out, hw)
            out = self.add.act.call_int(out, hw, validate_against_float=not allow_mismatch)

        if self.pool:
            out = self.pool.call_int(out, hw)
            out = self.pool.act.call_int(out, hw)

        if self.flatten:
            out = XTensor(tensor=out.itensor.numpy().reshape(out.itensor.shape[0],-1), bits=out.bits, frac=out.frac, from_int=True)
            
        if self.softmax:
            self.softmax_frac  = out.frac
            softmax_out        = out.ftensor.numpy().astype(np.float32)
            factor             = 2**17
            self.softmax_max_i = int(softmax_out.max() * factor)
            exp         = np.exp(softmax_out - self.softmax_max_i/factor).astype(np.float32)
            softmax_out = exp / np.sum(exp, axis=-1, keepdims=True, dtype=np.float32)

            assert np.all(np.argmax(self.out.ftensor, axis=-1) == np.argmax(softmax_out, axis=-1)), \
                f"Softmax argmax does not match. \nout:{self.out.ftensor}, \nself.out:{softmax_out}"
            is_terminal = not self.next_ibs and self.next_w_ib is None
            if is_terminal:
                self.pre_softmax  = deepcopy(out)          # save integer state for export()
                out.ftensor       = tf.convert_to_tensor(softmax_out, dtype=tf.float32)
                out.from_int      = False
                out.float_only    = True
                self.softmax_float_out = softmax_out       # float softmax (pre-quant) for tests
            else:
                out_frac = hw.X_BITS - 1
                # Use the same rounding as C: (i32)(x + 0.5f) = truncation after +0.5 = round-half-up.
                # np.rint uses banker's rounding (round-half-to-even), which differs for ties.
                q = np.clip((softmax_out * (1 << out_frac) + 0.5).astype(np.int32),
                            -(1 << (hw.X_BITS-1)), (1 << (hw.X_BITS-1))-1)
                out = XTensor(tensor=q, bits=hw.X_BITS, frac=out_frac, from_int=True)
                self.softmax_float_out = softmax_out       # float softmax (pre-quant) for tests
                allow_mismatch = True
        elif self.w_src_ib is None:
            # Dynamic-weight bundles: float and int paths use different precisions; skip exact check
            if not allow_mismatch:
                assert np.allclose(out.ftensor, self.out.ftensor), \
                    f"Bundle output does not match. \nout:{out.ftensor.numpy().flatten()[:100]}, \nself.out:{self.out.ftensor.numpy().flatten()[:100]}"
        
        self.allow_mismatch = allow_mismatch
        self.out = out


    def export (self, hw, is_last):

        if not self.core.type == 'conv':
            print('Conv -> Dense Reshape')
            CI,CO = self.core.w.itensor.shape
            XN, _ = self.core.x.itensor.shape
            w_int = self.core.w.itensor.numpy().reshape(1,1,CI,CO) # (CI,CO) -> (KH,KW,CI,CO)
            x_int = self.core.x.itensor.numpy().reshape(1,XN,1,CI) # (XN,CI) -> (XN, XH, XW, CI)
            y_int = self.core.y.itensor.numpy().reshape(1,XN,1,CO) # (XN,CI) -> (XN, XH, XW, CI)
            if self.softmax and is_last:
                o_int = self.pre_softmax.itensor.numpy().reshape(1, XN, 1, CO)
            else:
                o_int = self.out.itensor.numpy().reshape(1, XN, 1, CO)
        else:
            w_int = self.core.w.itensor.numpy()
            x_int = self.core.x.itensor.numpy()
            y_int = self.core.y.itensor.numpy()
            if self.softmax and is_last:
                o_int = self.pre_softmax.itensor.numpy()
            else:
                o_int = self.out.itensor.numpy()

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
        # oe_sum_exp is always the tiled accumulator output (y_sum_sim contains
        # raw PE sums written before bias/activation, in tiled order).
        self.oe_sum_exp = reorder_y_q2e_conv(y_int, hw, r)
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


class XAttn(Layer):
    """
    Hardware-exportable single- or multi-head self/cross-attention.

    n_heads=1 — 5 bundles per call():
        b_q0, b_k0, b_v0, b_scores0, b_out0

    n_heads>1 — 6*n_heads bundles per call():
        For each head h: b_qh, b_kh, b_vh, b_scoresh, b_outh, b_projh
        Heads accumulate via x_add on b_projh:
            output = Σ_h (head_h @ W_O_h)  ≡  Concat(heads) @ W_O  (no concat needed)

    seq_len — sequence length = input batch size at inference time
    units   — total model dimension d_model; per-head dim = units // n_heads
    """

    def __init__(self, k_int_bits, b_int_bits, act, units, seq_len, n_heads=1,
                 use_bias=False, scale=None, *args, **kwargs):
        layer_kwargs = {}
        for key in ["name", "trainable", "dtype", "dynamic"]:
            if key in kwargs:
                layer_kwargs[key] = kwargs.pop(key)
        super().__init__(*args, **layer_kwargs)

        if act is None:
            raise ValueError("Activation function must be provided. Set type=None for linear.")
        if scale is not None:
            raise NotImplementedError("XAttn: scale is not yet supported in hardware export mode.")
        assert units % n_heads == 0, f"units ({units}) must be divisible by n_heads ({n_heads})"

        self.type    = 'attn'
        self.units   = units
        self.seq_len = seq_len
        self.n_heads = n_heads
        self.scale   = scale

        d_k = units // n_heads

        def lin():
            return XActivation(sys_bits=act.sys_bits, o_int_bits=act.o_int_bits, type=None)

        for h in range(n_heads):
            is_last = (h == n_heads - 1)
            setattr(self, f'b_q{h}',      XBundle(core=XDense(k_int_bits=k_int_bits, b_int_bits=b_int_bits, units=d_k,    use_bias=use_bias, act=lin())))
            setattr(self, f'b_k{h}',      XBundle(core=XDense(k_int_bits=k_int_bits, b_int_bits=b_int_bits, units=d_k,    use_bias=use_bias, act=lin())))
            setattr(self, f'b_v{h}',      XBundle(core=XDense(k_int_bits=k_int_bits, b_int_bits=b_int_bits, units=d_k,    use_bias=use_bias, act=lin())))
            setattr(self, f'b_scores{h}', XBundle(core=XDense(k_int_bits=k_int_bits, b_int_bits=b_int_bits, units=seq_len, use_bias=False,    act=lin()), softmax=True, transpose_w_src=True))
            setattr(self, f'b_out{h}',    XBundle(core=XDense(k_int_bits=k_int_bits, b_int_bits=b_int_bits, units=d_k,    use_bias=False,    act=lin() if n_heads > 1 else act)))
            if n_heads > 1:
                add_act = None if h == 0 else lin()
                setattr(self, f'b_proj{h}', XBundle(core=XDense(k_int_bits=k_int_bits, b_int_bits=b_int_bits, units=units, use_bias=False, act=act if is_last else lin()), add_act=add_act))

    def _split_inputs(self, input_tensor):
        if isinstance(input_tensor, (list, tuple)):
            assert len(input_tensor) == 3, "XAttn expects [x_q, x_k, x_v] or x"
            return input_tensor[0], input_tensor[1], input_tensor[2]
        return input_tensor, input_tensor, input_tensor

    def call(self, input_tensor):
        x_q, x_k, x_v = self._split_inputs(input_tensor)
        if self.n_heads == 1:
            q = self.b_q0(x_q)
            k = self.b_k0(x_k)
            v = self.b_v0(x_v)
            p = self.b_scores0(q, w_src=k)   # softmax(Q @ K^T), requantized for downstream
            return self.b_out0(p, w_src=v)    # P @ V

        acc = None
        for h in range(self.n_heads):
            q    = getattr(self, f'b_q{h}')(x_q)
            k    = getattr(self, f'b_k{h}')(x_k)
            v    = getattr(self, f'b_v{h}')(x_v)
            p    = getattr(self, f'b_scores{h}')(q, w_src=k)
            head = getattr(self, f'b_out{h}')(p, w_src=v)
            if acc is None:
                acc = getattr(self, f'b_proj{h}')(head)
            else:
                acc = getattr(self, f'b_proj{h}')(head, x_add=acc)
        return acc