from qkeras import *
from tensorflow.keras.layers import Flatten, Add, MaxPooling2D, Layer
import numpy as np
from collections import namedtuple
import math
import copy
import tensorflow as tf
from deepsocflow.py.utils import *

'''
Bundle (current):

+ Conv/Dense
- Add Bias
- Relu + Quantization
- Add Bundle
- Relu + Quantization
- Max / Avg Pooling
- Relu + Quantization
- Softmax
- Tiling (Flatten)


Bundle (next)

+ Conv/Dense
- Add Bias
- Add Bundle
- Pooling
    - Max
    - Avg
- Activation
    - Relu
    - Softmax
    - GeLU
- Quantization
- Tiling
    - is_flatten
    - x2w (transformer)
    - concat_matrix (transformer)
'''


class Bundle(tf.keras.layers.Layer):
    idx = 0
    def __init__(self, 
                 core,             # dict, Mandaroty: parameters for conv/dense layer, act can be quantization or relu
                 add=None,         # dict, Mandatory if x1 is not None in call(), else ignored
                 pool=None,        # dict, Optional: can only be max or avg
                 flatten=False,    # Optional: set to True to flatten the outputs
                 softmax=False,    # Optional: set to Ture to include floating point softmax layer
                 **kwargs):

        super(Bundle, self).__init__()

        self.idx = Bundle.idx
        Bundle.idx += 1
        
        self.core = core
        self.add = add
        self.pool = pool
        self.flatten = flatten
        self.softmax = softmax
        self.inp = {'tensor':None, 'int': None, 'bits':None, 'frac': None}
        self.out = {'tensor':None, 'int': None, 'bits':None, 'frac': None}
        self.proc = {'tensor':None, 'int': None, 'bits':None, 'frac': None}
        self.w = {'tensor':None, 'int': None, 'bits':None, 'frac': None}
        self.b = None

        # Store reference to bundle object here, not just a idx number
        self.prev_bundle = None
        self.next_bundles = []
        self.add_bundle = None
        self.add_tensor_dest = []
        self.add_out_buffer_idx = None
        self.out_buffer_idx = None

        def extract_act(signature):
            ilayer = QActivation(signature)
            d = ilayer.quantizer.get_config()
            sign_bit = 1 # We always use signed integers
            int_bit = d['integer'] if 'integer' in d else 0
            frac = d['bits']-int_bit-sign_bit

            if isinstance(ilayer.quantizer, quantized_bits):
                if not d['keep_negative']:
                    d['keep_negative'] = True
                    ilayer.quantizer.keep_negative = True
                    print("Note: Only signed integers are allowed. Therefore, keep_negative is changed to True")
                return { 'layer':ilayer, 'type':'quant', 'bits':d['bits'], 'frac':frac, 'plog_slope': 0, 'non_zero':1}
            elif 'relu' in str(ilayer.quantizer.__class__):
                slope = ilayer.quantizer.negative_slope
                if slope == 0:
                    assert ilayer.quantizer.bits != 1, "Error: Cannot use bits=1 with Relu. Use leaky_relu. Reason: Qkeras keeps relu signed"
                    ilayer.quantizer.bits = ilayer.quantizer.bits-1
                non_zero = 1*(slope != 0)
                log_slope = np.log2(slope) if non_zero else 0
                assert int(log_slope) == log_slope and log_slope <= 0, f"Error: negative_slope:{slope} of leaky_relu has to be a negative power of two. eg.0.125"
                return { 'layer':ilayer, 'type':'relu', 'bits':d['bits'], 'frac':frac, 'slope':ilayer.quantizer.negative_slope, 'plog_slope':-int(log_slope), 'non_zero':non_zero}
            else:
                # TODO: support relu (slope=0). Qkeras uses different range for relu
                raise Exception("Only leaky_relu (relu with negative_slope > 0) is suppported!")

        '''
        CORE LAYER
        '''
        if core['type'] == 'conv':
            for i in ['filters', 'kernel_size', 'strides', 'padding', 'kernel_quantizer', 'bias_quantizer', 'use_bias', 'act_str']:
                assert i in core, f"'{i}' must be provided for conv"
            
            if type(core['kernel_size']) not in [list, tuple]:
                self.core['kernel_size'] = (core['kernel_size'], core['kernel_size'])
            if type(core['strides'])  not in [list, tuple]:
                self.core['strides'] = (core['strides'], core['strides'])

            self.core['layer'] = QConv2DBatchnorm(
                filters=self.core['filters'], kernel_size=self.core['kernel_size'], strides=self.core['strides'],
                padding=self.core['padding'], kernel_quantizer=self.core['kernel_quantizer'], 
                bias_quantizer=self.core['bias_quantizer'], use_bias=self.core['use_bias'], bias_initializer='glorot_uniform')
        
        else:
            for i in ['units', 'kernel_quantizer', 'bias_quantizer', 'use_bias', 'act_str']:
                assert i in self.core, f"'{i}' must be provided for dense"
            
            self.core['layer'] = QDense(
                units=self.core['units'], kernel_quantizer=self.core['kernel_quantizer'],
                bias_quantizer=self.core['bias_quantizer'], use_bias=self.core['use_bias'], bias_initializer='glorot_uniform')

        '''
        CORE ACT LAYER
        '''
        self.core['act'] = extract_act(core['act_str'])
        self.out['frac'], self.out['bits'] = self.core['act']['frac'], self.core['act']['bits']

        '''
        ACT ADD LAYER
        '''
        if self.add is not None:
            self.add['act'] = extract_act(add['act_str'])
            self.out['frac'], self.out['bits'] = self.add['act']['frac'], self.add['act']['bits']

        '''
        POOL LAYER
        '''
        if pool:
            for i in ['type', 'size', 'strides', 'padding']:
                assert i in pool, f"'{i}' must be provided for pool"

            if type(pool['size']) not in [list, tuple]:
                self.pool['size'] = (pool['size'], pool['size'])
            if type(pool['strides'])  not in [list, tuple]:
                self.pool['strides'] = (pool['strides'], pool['strides'])

            if pool['type'] == 'max':
                self.pool_layer = MaxPooling2D(self.pool['size'], strides=self.pool['strides'], padding=self.pool['padding'])
            elif pool['type'] == 'avg':
                self.pool_layer = QAveragePooling2D(self.pool['size'], strides=self.pool['strides'], padding=self.pool['padding'])
            else:
                raise Exception(self.pool['type'], "only avg or max pool is supported for now")
            
            self.pool['act'] = extract_act(self.pool['act_str'])
            self.out['frac'], self.out['bits'] = self.pool['act']['frac'], self.pool['act']['bits']
        else:
            self.pool_layer = None

        '''
        FLATTEN & SOFTMAX LAYERS
        '''
        self.flatten_layer = Flatten() if self.flatten else None

        self.softmax = softmax
        self.softmax_layer = Activation("softmax") if self.softmax else None
        if softmax:
            self.out['frac'], self.out['bits'] = 0, 1


    # functions for training
    def call(self, input_tensor, x_1=None):
        x = input_tensor
        if hasattr(x, "bundle"):
            self.prev_bundle = x.bundle
            self.prev_bundle.next_bundles += [self]
        else:
            self.prev_bundle = None

        self.inp['tensor'] = x

        x = self.core['layer'](x)
        x = self.core['act']['layer'](x)
        self.core['tensor'] = x

        if x_1 is not None:
            if hasattr(x_1, "bundle"):
                self.add['bundle'] = x_1.bundle
                x_1.bundle.add_tensor_dest += [self.idx]
            else:
                self.add['bundle'] = None
            x = Add()([x, x_1])
            x = self.add['act']['layer'](x)
            self.add['tensor'] = x
        if self.pool_layer:
            x = self.pool_layer(x)
            x = self.pool['act']['layer'](x)
            self.pool['tensor'] = x
        if self.flatten_layer:
            x = self.flatten_layer(x)
        if self.softmax_layer:
            x = self.softmax_layer(x)

        self.out['tensor'] = x
        x.bundle = self
        return x

    # functions to be prepared for exportation
    def load_weight_bias(self):
        k_tensor = self.core['layer'].get_folded_weights()[0] if isinstance(self.core['layer'], QConv2DBatchnorm) else self.core['layer'].kernel
        k = self.core['layer'].kernel_quantizer_internal(k_tensor).numpy()
        k_config = self.core['layer'].kernel_quantizer_internal.get_config()

        k_frac = k_config['bits']-k_config['integer']-k_config['keep_negative']
        k_int = k * 2**k_frac
        assert (k_int == k_int.astype(int)).all(), f"Weights failed integer test for bundle {self.idx}"
        k_int = k_int.astype(int)
        self.w = {'tensor':k_tensor, 'int': k_int, 'bits':k_config['bits'], 'frac':k_frac}

        if (self.core['type'] == 'conv' and self.core['use_bias']) or (self.core['type'] == 'dense' and self.core['use_bias']):
            b_tensor = self.core['layer'].get_folded_weights()[1] if isinstance(self.core['layer'], QConv2DBatchnorm) else self.core['layer'].bias
            b = self.core['layer'].bias_quantizer_internal(b_tensor).numpy()
            b_config = self.core['layer'].bias_quantizer_internal.get_config()
            b_frac = b_config['bits']-b_config['integer']-b_config['keep_negative']
            b_int = b * 2**b_frac
            assert (b_int == b_int.astype(int)).all(), f"Bias failed integer test for bundle {self.idx}"
            b_int = b_int.astype(int)
            self.b = {'tensor':b_tensor, 'int':b_int, 'bits':b_config['bits'], 'frac':b_frac}


    def process(self, inp, c):
        
        ''' Integer test for output '''
        self.out['int'] = self.out['tensor'].numpy() * 2**self.out['frac']
        if self.softmax is None:
            assert (self.out['int'] == self.out['int'].astype(int)).all(), f"Output tensor of bundle {self.idx} is not a fixed point"
            self.out['int'] = self.out['int'].astype(int)

        if inp is not None: # independant mode
            self.inp = inp
        else: # chained mode
            # ToDo: do not rely on external(global) variables!
            self.inp = self.prev_bundle.out
            assert self.idx > 0, "input must be provided manually for the first bundle"

        self.load_weight_bias()
        x = self.inp['int'].astype(np.int32)
        w = self.w['int'].astype(np.int32)

        if self.core['type'] == 'conv':
            self.proc['int'] = tf.keras.backend.conv2d(x, w, padding='same').numpy()
        else:
            self.proc['int'] = x @ w

        self.y = copy.deepcopy(self.proc)

        self.post_process(c)


    def post_process(self, c):

        def add (p, p_frac, p_bits, q, q_frac, q_bits):
            '''
            Add p,q while preserving precision
            '''
            p_intb, q_intb = p_bits-p_frac, q_bits-q_frac

            r_frac = max(p_frac,q_frac)
            r_intb = max(p_intb,q_intb)
            r_bits = 1 + r_intb + r_frac # +1 to allow overflow

            p_shift = r_frac-p_frac
            q_shift = r_frac-q_frac

            r = (p << p_shift) + (q << q_shift)
            return (r, r_frac, r_bits), (p_shift, q_shift)
        
        clog2_add = int(np.ceil(np.log2(np.prod(self.w['int'].shape[:-1]))))
        self.proc['bits'] = self.inp['bits'] + self.w['bits'] + clog2_add
        self.proc['frac'] = self.inp['frac'] + self.w['frac']
        self.o_sum_exp = np.copy(self.proc['int'])

        if self.b is not None:
            (self.proc['int'], self.proc['frac'], self.proc['bits']), (self.bias_val_shift, self.bias_b_shift) = add(
                self.proc['int'], self.proc['frac'], self.proc['bits'],
                self.b   ['int'], self.b   ['frac'], self.b   ['bits']
            )
            assert self.proc['bits'] <= c.INT_BITS, f"After bias addition, resulting bits {self.proc['bits']} are more than bits for integer in CPU {c.INT_BITS}. Reduce bits or increase integer bits of bias to continue"
        else:
            self.bias_val_shift, self.bias_b_shift = 0, 0


        if 'strides' in self.core and self.core['strides'] != (1,1):
            KH, KW = self.core['kernel_size']
            CSH, CSW = self.core['strides']
            XN, XH, XW, YC = self.proc['int'].shape
            CYH, CYW = math.ceil(XH/CSH), math.ceil(XW/CSW)
            
            pre_stride = self.proc['int']
            post_stride = np.zeros((XN, CYH, CYW, YC)).astype(pre_stride.dtype)
            
            (h_shift, w_shift) = (0,0)
            if self.core['padding']=="same":
                h_shift = (KH-1)//2 - max((CSH*(CYH-1)+KH-XH)//2, 0)
                w_shift = (KW-1)//2 - max((CSW*(CYW-1)+KW-XW)//2, 0)

            for xh in range(XH):
                for xw in range(XW):
                    if (xh-h_shift)%CSH == 0 and (xw-w_shift)%CSW == 0:
                        cyh = (xh-h_shift)//CSH
                        cyw = (xw-w_shift)//CSW
                        post_stride[:,cyh,cyw,:] = pre_stride[:,xh,xw,:]
            self.proc['int'] = post_stride
        
        def shift_round(n,s):
            '''Performs integer division with round-to-nearest-even. 
               Eq: np.around(n/2**s).astype(int)'''
            half_b = 1<<(s-1) if s>0 else 0
            return (n + half_b - (s>0)*(~(n>>s)&1) ) >> s
        
        def div_round(n,d):
            '''Performs integer division with round-to-nearest-even for d>0. 
               Eq: np.around(n/d).astype(int)'''
            return (n + (d//2) - (~(d|n//d) &1)) // d

        def apply_act(act_dict):
            assert act_dict['type'] in ['quant', 'relu'], 'Error: Only quant & relu are supported yet'

            x = self.proc['int'].astype(np.int32)
            frac, bits, plog_slope, non_zero = act_dict['frac'], act_dict['bits'], act_dict['plog_slope'], act_dict['non_zero']
            shift_bits = plog_slope + self.proc['frac']-frac

            print(f"Applying {act_dict['type']} with bits:{bits}, frac:{frac}, plog_slope:{plog_slope}, non_zero:{non_zero}, shift_bits:{shift_bits}")

            x = ((x<0)*x)*non_zero + (((x>0)*x) << plog_slope)
            x = shift_round(x, shift_bits) # = np.around(x/2**shift_bits)
            x = np.clip(x, -2**(bits-plog_slope-1), 2**(bits-1)-1).astype(int)

            act_dict['shift_bits'] = shift_bits
            self.proc['int'], self.proc['bits'], self.proc['frac'] = x, bits, frac

        apply_act(self.core['act'])
        assert np.all(self.proc['int'] == self.core['tensor'].numpy() * 2**self.proc['frac']), f"Core + act output of bundle {self.idx} is not fixed point"

        if self.add is not None:
            a = self.add['bundle']

            (self.proc['int'], self.proc['frac'], self.proc['bits']), (self.add_val_shift, self.add_a_shift) = add(
                self.proc['int']            , self.proc['frac'], self.proc['bits'],
                a.out    ['int'].astype(int), a.out    ['frac'], a.out    ['bits']
            )
            assert self.proc['bits'] <= c.INT_BITS, f"After residual addition, resulting bits {self.proc['bits']} are more than bits for integer in CPU {c.INT_BITS}. Reduce bits or increase integer bits of bias to continue"
            apply_act(self.add['act'])
            assert np.all(self.proc['int'] == self.add['tensor'].numpy() * 2**self.proc['frac']), f"Add + act output of bundle {self.idx} is not a fixed point"
        else:
            self.add_val_shift, self.add_a_shift = 0, 0

        if self.pool_layer:

            self.before_pool = np.copy(self.proc['int'])
          
            assert self.pool['padding'] in {"same", "valid"}
            assert self.pool['type'] in {"max", "avg"}

            in_arr = np.copy(self.proc['int'])
            YN, YH, YW, YC = in_arr.shape
            PKH, PKW = self.pool['size']
            PSH, PSW = self.pool['strides']

            if self.pool['padding']=="same":
                PXH = (YH+PSH-1)//PSH
                PXW = (YW+PSW-1)//PSW
            else:
                PXH = (YH-PKH+PSH)//PSH
                PXW = (YW-PKW+PSW)//PSW

            out_arr = np.zeros((YN, PXH, PXW, YC))

            p_st, q_st = 0, 0
            if self.pool['padding'] == "same":
                p_st = max((PSH*(PXH-1)+PKH-YH)//2, 0)
                q_st = max((PSW*(PXW-1)+PKW-YW)//2, 0)

            for n in range(YN):
                for ic in range(YC):
                    for iyh in range(YH):
                        for iyw in range(YW):

                            ph_end_const = iyh # iy(h,w) is the bottom-right of pooling window -> All values in pooling window have been computed
                            pw_end_const = iyw

                            ixh_before_stride = iyh+p_st-PKH+1
                            ixw_before_stride = iyw+q_st-PKW+1

                            ixh_beg = int(ixh_before_stride/PSH) # ix(hw) that corresponds to the pooling window
                            ixw_beg = int(ixw_before_stride/PSW)
                            if (ixh_before_stride % PSH != 0) or (ixw_before_stride % PSW != 0): # ix(hw) that corresponds to the window is skipped by pool striding
                                continue

                            if ixh_beg < 0 or ixw_beg <0: # skip with target ix(h,w) < 0
                                continue

                            ph_beg_const = max(PSH*ixh_beg-p_st, 0)-1 # p(h,w)_beg is the index of top left corner of pooling window. If negative, set to zero
                            pw_beg_const = max(PSW*ixw_beg-q_st, 0)-1

                            xh_sweep = PXH if iyh >= YH-PSH else ixh_beg+1 # ix(hw) is sweeped from ix(hw)_beg to x(h,w)_sweep. Normally sweep is 1.
                            xw_sweep = PXW if iyw >= YW-PSW else ixw_beg+1 # But when iy(h,w) is at its edges, need to compute remaining ix(hw) pixels by sweeping

                            ''' Handling edges '''
                            ph_end, ph_beg = ph_end_const, ph_beg_const
                            for ixh in range(ixh_beg, xh_sweep):
                                pw_end, pw_beg = pw_end_const, pw_beg_const # move the pooling window back to start of sweep
                                for ixw in range(ixw_beg, xw_sweep):
                                    
                                    ''' Pooling Window '''
                                    result = -math.inf if self.pool['type'] == 'max' else 0
                                    for ipyh in range(ph_end, ph_beg,-1):
                                        for ipyw in range(pw_end, pw_beg,-1):
                                            
                                            if self.pool['type']=='max':
                                                result = max(result, in_arr[n,ipyh,ipyw,ic])
                                            else:
                                                result += in_arr[n,ipyh,ipyw,ic]

                                    count  = (ph_end-ph_beg)*(pw_end-pw_beg)
                                    result = result if self.pool['type']=='max' else div_round(result, count)
                                    ''' Writing '''
                                    out_arr[n,ixh,ixw,ic] = result

                                    pw_beg += PSW # move pooling window by stride
                                    pw_end = min(pw_end+PSW, YW-1)
                                ph_beg += PSH # move pooling window by stride
                                ph_end = min(ph_end+PSH, YH-1)
            
            self.proc['int'] = out_arr
            if self.pool['type'] == 'avg':
                self.proc['bits'] += int(np.ceil(np.log2(PKH*PKW)))
                assert self.proc['bits'] <= c.INT_BITS, f"When summing avg pool, resulting bits {self.proc['bits']} are more than bits for integer in CPU {c.INT_BITS}. Reduce bits or increase integer bits of bias to continue"
            apply_act(self.pool['act'])
            assert np.all(self.proc['int'] == self.pool['tensor'].numpy() * 2**self.proc['frac']), f"Pool + act output of bundle {self.idx} is not a fixed point"

        if self.flatten:
            self.proc['int'] = self.proc['int'].reshape(self.proc['int'].shape[0],-1)

        self.o_exp = self.proc['int']


        if self.softmax:
            self.before_softmax = np.copy(self.proc['int'])
            self.softmax_frac = self.proc['frac']
            self.proc['int'] = (self.proc['int'] / 2**self.softmax_frac).astype(np.float32)

            self.softmax_max_f = self.proc['int'].max()
            exp = np.exp(self.proc['int'] - self.softmax_max_f).astype(np.float32)
            self.proc['int'] = exp/np.sum(exp, axis=1, dtype=np.float32)[0]

            assert np.all(np.argmax(self.out['int'], axis=-1) == np.argmax(self.proc['int'], axis=-1))
        else:
            self.softmax_frac = 0
            self.softmax_max_f = 0
            assert np.all(self.proc['int'] == self.out['int']), f"Overall output of bundle {self.idx} is not a fixed point"
        self.o_exp = self.proc['int']

    @staticmethod
    def get_compile_params(bundles, ROWS, COLS):

        def clog2(x):
            return int(np.ceil(np.log2(x)))
        
        IN_BITS               = 64
        CONFIG_BEATS          = 1
        X_BITS = K_BITS       = max([b.x[1] for b in bundles])
        KW_MAX                = max([b.KW   for b in bundles])
        KH_MAX                = max([b.KH   for b in bundles])
        SW_MAX                = max([b.SW   for b in bundles])
        SH_MAX                = max([b.SH   for b in bundles])
        CI_MAX                = max([b.CI   for b in bundles])
        XW_MAX                = max([b.XW   for b in bundles])
        XH_MAX                = max([b.XH   for b in bundles])
        XN_MAX                = max([b.XN   for b in bundles])
        BRAM_WEIGHTS_DEPTH    = max([b.RAM_WEIGHTS + CONFIG_BEATS for b in bundles])
        RAM_EDGES_DEPTH       = max([b.RAM_EDGES                  for b in bundles])
        
        L_MAX                 = clog2(XH_MAX//ROWS)
        X_PAD_MAX             = clog2(KH_MAX//2)
        BITS_KW2              = clog2((KW_MAX+1)/2)
        BITS_KH2              = clog2((KH_MAX+1)/2)
        BITS_SW               = clog2(SW_MAX)
        BITS_SH               = clog2(SH_MAX)
        BITS_CIN_MAX          = clog2(CI_MAX)
        BITS_COLS_MAX         = clog2(XW_MAX)
        BITS_BLOCKS_MAX       = clog2( L_MAX)
        BITS_XN_MAX           = clog2(XN_MAX)
        BITS_BRAM_WEIGHTS_ADDR= clog2(BRAM_WEIGHTS_DEPTH)

        params = locals()
        params = {k:params[k] for k in params if not ('__' in k or k in ['bundles', 'params', 'clog2'])}
        c = namedtuple('Compile', params)(**params)
        return c

    def export (self, c, is_last):

        if self.core['type'] != 'conv':
            print('Conv -> Dense Reshape')
            CI, CO = self.w['int'].shape
            XN, _ = self.inp['int'].shape
            w_int = self.w  ['int'].reshape(1,1,CI,CO) # (CI,CO) -> (KH,KW,CI,CO)
            x_int = self.inp['int'].reshape(1,XN,1,CI) # (XN,CI) -> (XN, XH, XW, CI)
            y_int = self.y  ['int'].reshape(1,XN,1,CO) # (XN,CI) -> (XN, XH, XW, CI)
            o_sum_int = self.o_sum_exp.reshape(1,XN,1,CO)
            o_int = self.o_exp.     reshape(1,XN,1,CO)
        else:
            y_int = self.y['int']
            o_sum_int = self.o_sum_exp
            o_int = self.o_exp
            w_int, x_int = self.w['int'], self.inp['int']

        assert (o_sum_int == y_int).all()
        
        r = self.get_runtime_params(
            c=c, 
            w_shape=w_int.shape, 
            x_shape=x_int.shape, 
            o_shape=self.o_exp.shape, 
            core_d=self.core, 
            pool_d=self.pool,
            flatten = self.flatten,
            )
        r = self.create_headers(c, r)

        assert r.KH <= c.KH_MAX
        assert r.KW <= c.KW_MAX
        assert r.CM <= c.CI_MAX
        assert r.XH <= c.XH_MAX
        assert r.XW <= c.XW_MAX
        assert r.XN <= c.XN_MAX

        cm_max = r.CM_0 if r.CP==1 else r.CM
        EDGES = cm_max * r.XW #* int(np.ceil(r.XH/c.ROWS)-1)
        assert EDGES <= c.RAM_EDGES_DEPTH or r.KH == 1, f"Edges: {EDGES} < {c.RAM_EDGES_DEPTH}"

        assert r.XW >= r.KH//2
        ACC_WIDTH = c.K_BITS + c.X_BITS + clog2(r.KH*r.KW*r.CM)
        assert ACC_WIDTH <= c.Y_BITS, f"ACC_WIDTH:{ACC_WIDTH} > Y_BITS{c.Y_BITS}"

        print(r)
        self.check_sparsity(w_int, x_int)

        self.be =  self.reorder_b_q2e_conv(self.b['int'], c, r) if self.b else None
        self.we = self.reorder_w_q2e_conv(w_int, c, r)
        self.ye_exp_shape = (r.IT, r.XN, r.XL, r.XW*r.CO_PRL, c.ROWS)
        self.ye_hw = np.zeros(self.ye_exp_shape)

        self.xe = self.reorder_x_q2e_conv(x_int, c, r)
        self.ye_exp = self.reorder_y_q2e_conv(y_int, c, r)
        self.o_int = o_int
        self.oe_sum_exp = o_int if is_last else self.reorder_y_q2e_conv(o_sum_int, c, r)
        self.oe_exp_nhwc = o_int
        print(f"x reshape: [int]:{self.inp['int'].shape}, int:{x_int.shape}. xe:{self.xe[0].shape}")

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
            self.ye_exp_p += [self.reorder_y_q2e_conv(yp, c, r)]
            ic_left = ic_right
        self.c, self.r = c, r


    @staticmethod
    def get_runtime_params(c, w_shape, x_shape, o_shape, core_d, pool_d, flatten):

        KH, KW, CI, CO = w_shape
        print('weights initial (KH, KW, CI, CO) =', w_shape)

        CO_PRL         = c.COLS // KW                        # SW cols are processed in parallel
        EG             = int(np.floor( c.COLS / KW))         # elastic groups
        IT             = int(np.ceil( CO / EG))              # iterations needed
        CO_PAD         = IT * CO_PRL                         # output cols padded
        
        CM             = (c.RAM_WEIGHTS_DEPTH - c.CONFIG_BEATS)//KH  # (available rows in weights ram)/KH
        CP             = int(np.ceil(CI / CM))                        # Number of passes required
        CM_0           = CM if (CI%CM==0) else (CI%CM)                # CM of p=0

        print(f'KH={KH}, KW={KW}, CI={CI}, CO={CO}, CO_PRL={CO_PRL}, EG={EG}, IT={IT}, CO_PAD={CO_PAD}, CM={CM}, CP={CP}')

        XN, XH, XW, CI = x_shape
        print('input initial (XN, XH, XW, CI)=', x_shape)

        XL  = int(np.ceil(XH/c.ROWS))    # Blocks
        YN, YH, YW, YC = XN, XH, XW, CO

        X_PAD = 0 if KH == 1 else c.X_PAD_MAX

        '''
        Conv Striding
        '''
        if core_d['type'] == 'conv':
            CSH, CSW = core_d['strides']
            assert XH > KH//2
            assert XW > KW//2
        else:
            CSH, CSW = 1,1

        CYH, CYW = int(np.ceil(XH/CSH)), int(np.ceil(XW/CSW))
        
        CSH_SHIFT, CSW_SHIFT = 0,0
        if core_d['type'] == 'conv':
            if core_d['padding']=="same":
                CSH_SHIFT = (KH-1)//2 - max((CSH*(CYH-1)+KH-XH)//2, 0)
                CSW_SHIFT = (KW-1)//2 - max((CSW*(CYW-1)+KW-XW)//2, 0)
            print(f"out after (strides:{CSH, CSW}, mode:{core_d['padding']}) CONV_STRIDING: (XN, CYH, CYW, CO)={(XN, CYH, CYW, CO)}")

            YH, YW = CYH, CYW


        '''
        Pooling
        '''
        PKH = PKW = PSH = PSW = 1
        PSH_SHIFT = PSW_SHIFT = 0
        PYH, PYW = YH, YW

        if pool_d is not None:
            PKH, PKW = pool_d['size']
            PSH, PSW = pool_d['strides']
    
            if pool_d['padding']=="same":
                PYH = (YH+PSH-1)//PSH
                PYW = (YW+PSW-1)//PSW
                PSH_SHIFT = max((PSH*(PYH-1)+PKH-YH)//2, 0)
                PSW_SHIFT = max((PSW*(PYW-1)+PKW-YW)//2, 0)
                print("pool mode: ", pool_d['padding'])
            else:
                PYH = (YH-PKH+PSH)//PSH
                PYW = (YW-PKW+PSW)//PSW
        
        YH, YW = PYH, PYW
        print(f"out after (strides:{(PSH,PSW)}, sizes:{(PKH, PKW)}) POOLING: (XN, PYH, PYW, CO)={(XN, YH, YW, CO)}")

        YL  = int(np.ceil(YH/c.ROWS))    # Blocks
        ON, OH, OW, OC = YN, YH, YW, YC

        if flatten:
            YH, YW, YC = 1, 1, YH*YW*YC
            ON, OH, OW, OC = 1, YN, YW, YC # Bundle flatten N,H -> 1,N

        
        if core_d['type'] == 'conv' and not flatten:
            assert o_shape == (XN, YH, YW, CO), f"{o_shape=}, {(XN, YH, YW, CO)=}"
        
        print('final output', o_shape)

        '''
        Pack all local variables into a namedtuple
        '''
        params = locals()
        params = {k:params[k] for k in params if not ('__' in k or k in ['w', 'x', 'y', 'c', 'core_d', 'pool_d', 'params'])}
        print (params)
        r = namedtuple('Runtime', params)(**params)
        return r

    @staticmethod
    def predict_performance(hw, r):

        clocks_p0 = r.IT*(1 + r.XN*r.XL*r.XW*(1 + r.CM_0*r.KH))
        clocks_p  = r.IT*(1 + r.XN*r.XL*r.XW*(1 + r.CM*r.KH))

        mem_bits_p0 = \
            hw.X_BITS * (r.IT * r.XN   * r.XL * r.XW * r.CM_0 * (hw.ROWS + r.X_PAD-1)) +\
            hw.K_BITS * (r.IT * r.CM_0 * r.KH * hw.COLS) +\
            hw.X_BITS * (r.XN * r.XH   * r.XW * r.CO)
        mem_bits_p = \
            hw.X_BITS * (r.IT * r.XN   * r.XL * r.XW * r.CM   * (hw.ROWS + r.X_PAD-1)) +\
            hw.K_BITS * (r.IT * r.CM_0 * r.KH * hw.COLS) +\
            hw.X_BITS * (r.XN * r.XH   * r.XW * r.CO)

        '''
        Accurate mem access (output):
            - baseline: next bundle input + padding
            - p_add   - write & read
            - pooling - write & read
            - softmax - write & read
        '''

        clocks    = clocks_p0 + (r.CP-1)*clocks_p
        mem_bits  = mem_bits_p0 + (r.CP-1)*mem_bits_p

        return clocks, mem_bits


    @staticmethod
    def create_headers(c, r):
        '''
        Create headers
        '''
        def pack_bits(arr, total):
            sum_width = 0
            packed = 0
            for val, width in arr:
                packed |= val << sum_width
                sum_width += width
            assert sum_width <= total, f"Number of total packed bits {sum_width} is more than input DMA width {total}"
            packed_le = np.array([packed],dtype=np.uint64)
            packed_be = np.frombuffer(packed_le.tobytes(), dtype=np.dtype(np.uint64).newbyteorder('>'))
            return packed_le, packed_be # np.arrays
        
        d = {'w_header_le_p':[], 'x_header_le_p':[], 'w_header_be_p':[], 'x_header_be_p':[]}

        for ip in range(min(2, r.CP)):
            CM_p = r.CM_0 if ip==0 else r.CM
            print(f'headers: ip={ip}, CM_p={CM_p}')
        
            ''' Weights Config'''

            w_header_le, w_header_be = pack_bits([
                (r.KW//2, c.BITS_KW2),
                (CM_p-1 , c.BITS_CIN_MAX),
                (r.XW-1 , c.BITS_COLS_MAX),
                (r.XL-1 , c.BITS_BLOCKS_MAX),
                (r.XN-1 , c.BITS_XN_MAX),
                (c.CONFIG_BEATS + r.KH*CM_p-1, c.BITS_RAM_WEIGHTS_ADDR)
            ], c.IN_BITS-1)
            d['w_header_le_p'] += [w_header_le]
            d['w_header_be_p'] += [w_header_be]

            '''Input Config'''
            x_header_le, x_header_be = pack_bits([
                (r.KH//2, c.BITS_KH2),
                (CM_p-1 , c.BITS_CIN_MAX),
                (r.XW-1 , c.BITS_COLS_MAX),
                (r.XL-1 , c.BITS_BLOCKS_MAX),
            ], c.IN_BITS-1)
            d['x_header_le_p'] += [x_header_le]
            d['x_header_be_p'] += [x_header_be]

        
        n = namedtuple('Runtime', d)(**d)
        r = namedtuple("Runtime", r._fields + n._fields)(*(r + n))
        return r


    @staticmethod
    def check_sparsity(w, x):
        w_sparse = (w==0).sum()/w.size
        x_sparse = (x==0).sum()/x.size

        p_both_zero = x_sparse * w_sparse
        p_only_one_zero = (1-x_sparse) * w_sparse  +  (1-w_sparse) * x_sparse
        p_neither_zero = (1-x_sparse) * (1-w_sparse)
        zero_result = 1-p_neither_zero

        print(f'''
        w_sparsity   : {w_sparse*100:.2f}%
        x_sparsity   : {x_sparse*100:.2f}%

        both_zero    : {p_both_zero*100:.2f}%
        only_one_zero: {p_only_one_zero*100:.2f}%
        neither_zero : {p_neither_zero*100:.2f}%
        zero_result  : {zero_result*100:.2f}%
        ''')


    @staticmethod
    def reorder_b_q2e_conv(b, c, r):
        b = np.pad(b, ((0,r.CO_PAD-r.CO)))
        b = b.reshape(r.IT, r.CO_PRL)
        return b
    

    @staticmethod
    def reorder_w_q2e_conv(w, c, r):

        w = np.pad(w, ((0,0),(0,0),(0,0),(0,r.CO_PAD-r.CO)))        # (KH, KW, CI, CO_PAD)
        w = w.reshape(r.KH, r.KW, r.CI, r.IT, r.CO_PRL)             # (KH, KW, CI, IT, CO_PRL)
        w = np.flip(w, axis=4)                                      # cuz we shift outputs towards right in PE array and read from high col

        w = w.transpose(0,2,3,4,1)                                  # (KH, CI, IT, CO_PRL, KW)
        w = w.reshape  (r.KH, r.CI, r.IT, r.CO_PRL*r.KW)            # (KH, CI, IT, CO_PRL*KW)
        w = np.pad(w, ((0,0),(0,0),(0,0),(0,c.COLS-r.CO_PRL*r.KW))) # (KH, CI, IT, c.COLS)
        w = w.transpose(2,1,0,3)                                    # (IT, CI, KH, c.COLS)

        w_list = []
        ic_left = ic_right = 0
        for ip in range(r.CP):
            CM_p = r.CM_0 if ip==0 else r.CM
            ic_right += CM_p

            wp = w[:, ic_left:ic_right, :,:]
            wp = wp.reshape (r.IT, CM_p*r.KH, c.COLS)                # (IT, CM*KH, c.COLS)
            wp = np.pad(wp, ((0,0),(c.CONFIG_BEATS,0),(0,0)))        # (IT, c.CONFIG_BEATS+CM*KH, c.COLS)
            assert wp.shape == (r.IT, CM_p*r.KH +c.CONFIG_BEATS, c.COLS)
            
            words_per_byte = 8//c.K_BITS
            wp = wp.reshape(r.IT,-1)
            pad = words_per_byte-(wp[0].size%words_per_byte)
            pad = 0 if pad == words_per_byte else pad
            wp = np.pad(wp, ((0,pad),(0,0)))

            w_list += [wp]
            ic_left = ic_right
        return w_list


    @staticmethod
    def reorder_x_q2e_conv(x, c, r):
        print('input initial (XN, XH, XW, CI)=', x.shape)

        x = np.pad(x, ((0,0),(0,r.XL*c.ROWS-r.XH),(0,0),(0,0)))         # (XN, L*HL , XW, CI)
        x = x.reshape  (r.XN, r.XL, c.ROWS, r.XW, r.CI)                   # (XN, XL, HL, XW, CI)

        zeros = np.zeros((r.XN,r.XL,c.ROWS+r.X_PAD,r.XW,r.CI),x.dtype)  # (XN,XL,c.ROWS+X_PAD,XW,CI)
        zeros[:,:,:c.ROWS,:,:] = x

        ''' Fill bot rows from next '''
        for l in range(r.XL):
            if l == r.XL-1:
                zeros[:,l, c.ROWS: ,:,:] = np.zeros((r.XN,r.X_PAD,r.XW,r.CI),x.dtype)
            else:
                zeros[:,l, c.ROWS: ,:,:] = x[:,l+1,:r.X_PAD,:,:]

        x = zeros                                                  # (XN,XL,c.ROWS+X_PAD,XW,CI)
        x = x.transpose(0,1,3,4,2)                                 # (XN,XL,XW,CI,c.ROWS+X_PAD)
        x = x.reshape((r.XN, r.XL, r.XW, r.CI, (c.ROWS+r.X_PAD)))

        x_list = []
        ic_left = ic_right = 0
        for ip in range(r.CP):
            CM_p = r.CM_0 if ip==0 else r.CM
            ic_right += CM_p

            xp = x[:,:,:, ic_left:ic_right, :]                              #(XN, XL, XW, CM, (c.ROWS+r.X_PAD))
            assert xp.shape == (r.XN, r.XL, r.XW, CM_p, (c.ROWS+r.X_PAD))

            xp = xp.flatten()
            words_per_byte = 8//c.X_BITS
            pad = words_per_byte-(xp.size%words_per_byte)
            pad = 0 if pad == words_per_byte else pad
            xp = np.pad(xp, ((0,pad)))

            x_list += [xp]
            ic_left = ic_right
        return x_list


    @staticmethod
    def reorder_y_q2e_conv(y, c, r):
        '''
        This is engine output: no striding (H=H, L=XL), last W interchanged
        '''

        y = np.pad(y, ((0,0),(0,c.ROWS*r.XL-r.XH),(0,0),(0,r.CO_PAD-r.CO)))  # (XN, XL*ROWS , XW, CO_PAD)
        y = y.reshape((r.XN, r.XL, c.ROWS, r.XW, r.CO_PAD))                  # (XN,XL,c.ROWS,XW,CO_PAD)
        y = y.reshape((r.XN, r.XL, c.ROWS, r.XW, r.IT, r.CO_PRL))            # (XN,XL,c.ROWS,XW,IT,CO_PRL)
        y = y.transpose(4,0,1,3,5,2)                                         # (IT,XN,XL,XW,CO_PRL,c.ROWS)

        assert y.shape == (r.IT,r.XN,r.XL,r.XW,r.CO_PRL,c.ROWS)

        y_w_last = y[:,:,:,-(r.KW//2+1):,:,:]
        y_w_last = y_w_last.transpose(0,1,2,4,3,5).reshape(r.IT,r.XN,r.XL,(r.KW//2+1)*r.CO_PRL,c.ROWS)

        y = y.reshape(r.IT,r.XN,r.XL,r.XW*r.CO_PRL,c.ROWS)
        y[:,:,:,-(r.KW//2+1)*r.CO_PRL:,:] = y_w_last
        return y
    
    @staticmethod
    def reorder_y_e2q_conv(y, c, r):
        '''
        This is engine output: no striding (H=H, L=XL), last W interchanged
        '''
        y = y.reshape(r.IT,r.XN,r.XL,r.XW*r.CO_PRL,c.ROWS)

        y_w_last = y[:,:,:,-(r.KW//2+1)*r.CO_PRL:,:]
        y_w_last = y_w_last.reshape(r.IT,r.XN,r.XL,r.CO_PRL,(r.KW//2+1),c.ROWS)
        y_w_last = y_w_last.transpose(0,1,2,4,3,5)   #(r.IT,r.XN,r.XL,(r.KW//2+1),r.CO_PRL,c.ROWS)
        y_w_last = y_w_last.reshape(r.IT,r.XN,r.XL,(r.KW//2+1),r.CO_PRL,c.ROWS)
        y_w_last = y_w_last.reshape(r.IT,r.XN,r.XL,(r.KW//2+1)*r.CO_PRL,c.ROWS)
        
        y[:,:,:,-(r.KW//2+1)*r.CO_PRL:,:] = y_w_last

        y = y.reshape(r.IT,r.XN,r.XL,r.XW,r.CO_PRL,c.ROWS)
        y = y.transpose(1,2,5,3,0,4)
        y = y.reshape((r.XN, r.XL*c.ROWS, r.XW, r.CO_PAD))
        y = y[:,:r.XH,:,:r.CO]

        return y

    @staticmethod
    def pack_words_into_bytes (arr, bits):
        assert 8 % bits == 0, f"Bits {bits} should be factor of 8 for packing"
        w_words_per_byte = 8//bits
        arr = np.frombuffer(arr.astype(np.int8).tobytes(), dtype=np.uint8)
        arr = arr % 2**bits
        arr = arr.reshape(arr.size//w_words_per_byte, w_words_per_byte)
        for i_word in range(1, w_words_per_byte):
            arr[:,0] += arr[:,i_word] << (i_word * bits) # pack multiple words into a byte
        return arr[:,0].astype(np.uint8) # packed byte