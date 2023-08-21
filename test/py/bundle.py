from qkeras import *
from tensorflow.keras.layers import Flatten, Add, MaxPooling2D
import numpy as np
from collections import namedtuple
import math
import copy
import tensorflow as tf

class Bundle(tf.keras.Model):
    def __init__(self, 
                 core,             # dict, Mandaroty: parameters for conv/dense layer, act can be quantization or relu
                 add=None,         # dict, Mandatory if x1 is not None in call(), else ignored
                 pool=None,        # dict, Optional: can only be max or avg
                 flatten=False,    # Optional: set to True to flatten the outputs
                 softmax=False,    # Optional: set to Ture to include floating point softmax layer
                 **kwargs):

        super(Bundle, self).__init__()
        
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
        self.add_bundle = None

        def extract_act(signature):
            ilayer = QActivation(signature)
            d = ilayer.quantizer.get_config()
            sign_bit = d['keep_negative'] if 'keep_negative' in d else (d['negative_slope'] !=0 if 'negative_slope' in d else (0))
            int_bit = d['integer'] if 'integer' in d else 0
            frac = d['bits']-int_bit-sign_bit

            if isinstance(ilayer.quantizer, quantized_bits):
                return { 'layer':ilayer, 'type':'quant', 'bits':d['bits'], 'frac':frac}
            elif 'relu' in str(ilayer.quantizer.__class__) and ilayer.quantizer.negative_slope != 0:
                return { 'layer':ilayer, 'type':'relu', 'slope':ilayer.quantizer.negative_slope, 'bits':d['bits'], 'frac':frac}
            else:
                raise Exception("Only leaky_relu (relu with negative_slope > 0) is suppported!")

        '''
        CORE LAYER
        '''
        if core['type'] == 'conv':
            for i in ['filters', 'kernel_size', 'strides', 'padding', 'kernel_quantizer', 'bias_quantizer', 'use_bias', 'act_str']:
                assert i in core, f"'{i}' must be provided for conv"

            self.core['layer'] = QConv2DBatchnorm(
                filters=self.core['filters'], kernel_size=self.core['kernel_size'], strides=self.core['strides'],
                padding=self.core['padding'], kernel_quantizer=self.core['kernel_quantizer'], 
                bias_quantizer=self.core['bias_quantizer'], use_bias=self.core['use_bias'])
        
        else:
            for i in ['units', 'kernel_quantizer', 'bias_quantizer', 'use_bias', 'act_str']:
                assert i in self.core, f"'{i}' must be provided for dense"
            
            self.core['layer'] = QDense(
                units=self.core['units'], kernel_quantizer=self.core['kernel_quantizer'],
                bias_quantizer=self.core['bias_quantizer'], use_bias=self.core['use_bias'])

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
    def call(self, x, x_1=None):
        if hasattr(x, "bundle"):
            self.prev_bundle = x.bundle
            self.idx = self.prev_bundle.idx + 1
        else:
            self.prev_bundle = None
            self.idx = 0

        self.inp['tensor'] = x

        x = self.core['layer'](x)
        x = self.core['act']['layer'](x)
        self.core['tensor'] = x

        if x_1 is not None:
            if hasattr(x_1, "bundle"):
                self.add['bundle'] = x_1.bundle
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


    def process(self, inp = None):
        
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

        self.post_process()


    def post_process(self):
        
        clog2_add = int(np.ceil(np.log2(np.prod(self.w['int'].shape[:-1]))))
        self.proc['bits'] = self.inp['bits'] + self.w['bits'] + clog2_add
        self.proc['frac'] = self.inp['frac'] + self.w['frac']

        if self.b is not None:
            self.proc['int'] += self.b['int'] * 2** (self.proc['frac'] - self.b['frac'])


        if 'strides' in self.core and self.core['strides'] != (1,1):
            SH, SW = self.core['strides']
            N, XH, XW, C = self.proc['int'].shape
            YH, YW = XH//SH, XW//SW
            self.proc['int'] = self.proc['int'].reshape(N, YH, SH, YW, SW, C)
            ind = -1 if self.w['int'].shape[0] > 1 else 0
            self.proc['int'] = self.proc['int'][:,:,ind,:,ind,:]

        def apply_act(act_dict):
            x = self.proc['int'].astype(np.float32)
            frac, bits = act_dict['frac'], act_dict['bits']

            if act_dict['type'] == 'quant':
                x *= 2**(frac-self.proc['frac'])
                x = np.around(x)
                x = np.clip(x, -2**(bits-1), 2**(bits-1)-1).astype(int)

            elif act_dict['type'] == 'relu':
                x *= 2**(frac-self.proc['frac'])
                x = np.clip(x, -2**(bits-1), 2**(bits-1)-1)
                x = np.maximum(x * act_dict['slope'], x)
                x = np.around(x)
                x = np.clip(x,-2**(bits-1), 2**(bits-1)-1).astype(int)
            else:
                raise Exception('Only relu is supported yet')

            self.proc['int'], self.proc['bits'], self.proc['frac'] = x, bits, frac

        apply_act(self.core['act'])
        assert np.all(self.proc['int'] == self.core['tensor'].numpy() * 2**self.proc['frac']), f"Core + act output of bundle {self.idx} is not fixed point"


        if self.add is not None:
            a = self.add['bundle']
            out_frac_add, out_bits_add = max(self.proc['frac'], a.out['frac']), max(self.proc['bits'], a.out['bits'])

            a_arr_cast = a.out['int'] * 2** (out_frac_add - a.out['frac'])
            out_arr_cast = self.proc['int'] * 2 **(out_frac_add - self.proc['frac'])

            self.proc['int'] = out_arr_cast.astype(np.int64) + a_arr_cast.astype(np.int64)
            self.proc['bits'], self.proc['frac'] = out_bits_add, out_frac_add
            apply_act(self.add['act'])

            assert np.all(self.proc['int'] == self.add['tensor'].numpy() * 2**self.proc['frac']), f"Add + act output of bundle {self.idx} is not a fixed point"

        if self.pool_layer:
            if self.pool['type'] == 'max':
                pStride = self.pool['strides']
                pSize = self.pool['size']

                def findMax(InArray, p, q):
                    results = np.zeros((InArray.shape[0], InArray.shape[3]))
                    results -= math.inf
                    for i in range(p, p+pSize[0]):
                        for j in range(q, q+pSize[1]):
                            if i >=0 and j>=0 and i < InArray.shape[1] and j < InArray.shape[2]:
                                cand = InArray[:,i,j,:]
                                results = np.maximum(results, cand)
                    return results

                def HotFixMaxPool2D(InArray):
                    if pStride[0]!=pStride[1] or pSize[0]!=pSize[1]:
                        raise Exception('Only square stride and size is supported')
                    if pSize[0]/2 == 0:
                        raise Exception('Maxpool size should be odd')

                    pad = (pSize[0]-1)//2

                    inShape = InArray.shape
                    assert len(inShape) == 4
                    OutArray = np.zeros((inShape[0], inShape[1]//pStride[0], inShape[2]//pStride[1], inShape[3]))
                    # Start point, should include pad
                    st_p, st_q = -pad, -pad

                    for i in range(OutArray.shape[1]):
                        for j in range(OutArray.shape[2]):
                            p, q = st_p + i*pStride[0] + pStride[0]-1, st_q + j*pStride[1] + pStride[1]-1
                            OutArray[:,i,j,:] = findMax(InArray, p, q)

                    return OutArray

                self.proc['int'] = HotFixMaxPool2D(self.proc['int']).astype(int)

            elif self.pool['type'] == 'avg':
                assert self.pool['size'] == self.pool['strides']
                KH, KW = self.pool['size']
                N, H, W, C = self.proc['int'].shape
                self.proc['int'] = self.proc['int'].reshape(N, H//KH, KH, W//KW, KW, C).mean(axis=(2,4))
                # NO need for clipping, as act_pool in place!
                apply_act(self.pool['act'])
            assert np.all(self.proc['int'] == self.pool['tensor'].numpy() * 2**self.proc['frac']), f"Pool + act output of bundle {self.idx} is not a fixed point"

        if self.flatten:
            self.proc['int'] = self.proc['int'].reshape(self.proc['int'].shape[0],-1)


        if self.softmax:
            self.proc['int'] = self.proc['int'] / 2**self.proc['frac']
            exp = np.exp(self.proc['int'] - self.proc['int'].max())
            self.proc['int'] = exp/np.sum(exp, axis=1)[0]
            assert np.all(np.argmax(self.out['int'], axis=-1) == np.argmax(self.proc['int'], axis=-1))
        else:
            assert np.all(self.proc['int'] == self.out['int']), f"Overall output of bundle {self.idx} is not a fixed point"

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
        X_PAD                 = clog2(KH_MAX//2)
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

    def export (self, c):

        if self.core['type'] != 'conv':
            print('Conv -> Dense Reshape')
            CI, CO = self.w['int'].shape
            XN, _ = self.inp['int'].shape
            w_int = self.w['int'].reshape(1,1,CI,CO) # (CI,CO) -> (KH,KW,CI,CO)
            x_int = self.inp['int'].reshape(XN,1,1,CI) # (XN,CI) -> (XN, XH, XW, CI)
            y_int = self.y['int'].reshape(XN,1,1,CO) # (XN,CI) -> (XN, XH, XW, CI)
        else:
            y_int = self.y['int']
            w_int, x_int = self.w['int'], self.inp['int']
        
        r = self.get_runtime_params(c, w_int.shape, x_int.shape, y_int.shape)
        r = self.create_headers(c, r)

        print(r)
        self.check_sparsity(w_int, x_int)

        self.we = self.reorder_w_q2e_conv(w_int, c, r)
        self.ye_exp_shape = (r.IT, r.XN, r.L, r.XW*r.CO_PRL, c.ROWS)
        self.ye_hw = np.zeros(self.ye_exp_shape)

        self.xe = self.reorder_x_q2e_conv(x_int, c, r)
        self.ye_exp = self.reorder_y_q2e_conv(y_int, c, r)

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
    def get_runtime_params(c, w_shape, x_shape, y_shape):

        SW = SH = 1 # for bundle
        KH, KW, CI, CO = w_shape
        print('weights initial (KH, KW, CI, CO) =', w_shape)

        CO_PRL         = c.COLS * SW // KW                        # SW cols are processed in parallel
        EG             = int(np.floor( c.COLS / (KW + SW - 1)))   # elastic groups
        IT             = int(np.ceil( CO / (SW*EG)))              # iterations needed
        CO_PAD         = IT * CO_PRL                              # output cols padded
        
        CM             = (c.RAM_WEIGHTS_DEPTH - c.CONFIG_BEATS)//KH  # (available rows in weights ram)/KH
        CP             = int(np.ceil(CI / CM))                        # Number of passes required
        CM_0           = CM if (CI%CM==0) else (CI%CM)                # CM of p=0

        print(f'KH={KH}, KW={KW}, CI={CI}, CO={CO}, CO_PRL={CO_PRL}, EG={EG}, IT={IT}, CO_PAD={CO_PAD}, CM={CM}, CP={CP}')

        XN, XH, XW, CI = x_shape
        print('input initial (XN, XH, XW, CI)=', x_shape)
        print('output initial', y_shape)
        SH_OUT, SW_OUT = x_shape[1]//y_shape[1], x_shape[2]//y_shape[2]

        LH     = c.ROWS*SH              # Block height
        L      = int(np.ceil(XH/LH))    # Blocks
        XH_PAD = LH*L

        '''
        Pack all local variables into a namedtuple
        '''
        params = locals()
        params = {k:params[k] for k in params if not ('__' in k or k in ['w', 'x', 'y', 'c', 'params'])}
        print (params)
        r = namedtuple('Runtime', params)(**params)
        return r


    @staticmethod
    def create_headers(c, r):
        '''
        Create headers
        '''
        def pack_bits(arr):
            sum_width = 0
            packed = 0
            for val, width in arr:
                packed |= val << sum_width
                sum_width += width
            return packed
        
        w_config_words_p = []
        x_config_words_p = []

        for ip in range(r.CP):
            CM_p = r.CM_0 if ip==0 else r.CM
            print(f'headers: ip={ip}, CM_p={CM_p}')
        
            ''' Weights Config'''
            w_config = pack_bits([
                (r.KW//2, c.BITS_KW2),
                (CM_p-1 , c.BITS_CIN_MAX),
                (r.XW-1 , c.BITS_COLS_MAX),
                (r.L -1 , c.BITS_BLOCKS_MAX),
                (r.XN-1 , c.BITS_XN_MAX),
                (c.CONFIG_BEATS + r.SW*r.KH*CM_p-1, c.BITS_RAM_WEIGHTS_ADDR)
            ])
            w_config = format(w_config, f'#0{c.IN_BITS}b')
            w_config_words = [int(w_config[i:i+c.K_BITS], 2) for i in range(0, len(w_config), c.K_BITS)]
            w_config_words.reverse()
            w_config_words = np.array(w_config_words,dtype=np.int8)
            w_config_words_p += [w_config_words]

            '''Input Config'''
            x_config = pack_bits([
                (r.KH//2, c.BITS_KH2),
                (CM_p-1 , c.BITS_CIN_MAX),
                (r.XW-1 , c.BITS_COLS_MAX),
                (r.L -1 , c.BITS_BLOCKS_MAX),
            ])
            assert c.IN_BITS >= c.BITS_KW2 + c.BITS_CIN_MAX + c.BITS_COLS_MAX + c.BITS_BLOCKS_MAX

            x_config = format(x_config, f'#0{c.IN_BITS}b')
            x_config_words = [int(x_config[i:i+c.X_BITS], 2) for i in range(0, len(x_config), c.X_BITS)]
            x_config_words.reverse()
            x_config_words_p += [x_config_words]

        d = {'w_config_words_p':w_config_words_p, 'x_config_words_p': x_config_words_p}
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
    def reorder_w_q2e_conv(w, c, r):

        w = np.pad(w, ((0,0),(0,0),(0,0),(0,r.CO_PAD-r.CO)))        # (KH, KW, CI, CO_PAD)
        print(w.shape, (r.KH, r.KW, r.CI, r.IT, r.CO_PRL))
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
            assert wp.shape == (r.IT, CM_p, r.KH, c.COLS)
            
            wp = wp.reshape (r.IT, CM_p*r.KH, c.COLS)                # (IT, CM*KH, c.COLS)
            wp = np.pad(wp, ((0,0),(c.CONFIG_BEATS,0),(0,0)))          # (IT, c.CONFIG_BEATS+CM*KH, c.COLS)
            wp = wp.reshape (r.IT, (CM_p*r.KH+c.CONFIG_BEATS)*c.COLS)  # (IT, (CM*KH+c.CONFIG_BEATS)*c.COLS)
            
            w_config_words = r.w_config_words_p[ip] [np.newaxis, ...]
            w_config_words = np.repeat(w_config_words, repeats=r.IT,axis=0)
            wp = np.concatenate([w_config_words, wp], axis=1)          # (IT, 8 + CM*KH*c.COLS)
            assert wp.shape == (r.IT, c.IN_BITS/c.K_BITS + (CM_p*r.KH+c.CONFIG_BEATS)*c.COLS)

            ic_left = ic_right
            w_list += [wp]
        return w_list


    @staticmethod
    def reorder_x_q2e_conv(x, c, r):
        print('input initial (XN, XH, XW, CI)=', x.shape)

        x = np.pad(x, ((0,0),(0,r.XH_PAD-r.XH),(0,0),(0,0)))   # (XN, L*HL , XW, CI)
        x = x.reshape  (r.XN, r.L, r.LH, r.XW, r.CI)               # (XN, L, HL, XW, CI)

        zeros = np.zeros((r.XN,r.L,c.ROWS+c.X_PAD,r.XW,r.CI),x.dtype)  # (XN,L,c.ROWS+X_PAD,XW,CI)
        zeros[:,:,:c.ROWS,:,:] = x

        ''' Fill bot rows from next '''
        for l in range(r.L):
            if l == r.L-1:
                zeros[:,l, c.ROWS: ,:,:] = np.zeros((r.XN,c.X_PAD,r.XW,r.CI),x.dtype)
            else:
                zeros[:,l, c.ROWS: ,:,:] = x[:,l+1,:c.X_PAD,:,:]

        x = zeros                  # (XN,L,c.ROWS+X_PAD,XW,CI)
        x = x.transpose(0,1,3,4,2) # (XN,L,XW,CI,c.ROWS+X_PAD)
        x = x.reshape((r.XN, r.L, r.XW, r.CI, (c.ROWS+c.X_PAD)))

        x_list = []
        ic_left = ic_right = 0
        for ip in range(r.CP):
            CM_p = r.CM_0 if ip==0 else r.CM
            ic_right += CM_p

            xp = x[:,:,:, ic_left:ic_right, :]                              #(XN, L, XW, CM, (c.ROWS+c.X_PAD))
            assert xp.shape == (r.XN, r.L, r.XW, CM_p, (c.ROWS+c.X_PAD))
            xp = xp.reshape(r.XN*r.L*r.XW*CM_p*(c.ROWS+c.X_PAD))
            
            x_config_words = np.array(r.x_config_words_p[ip], dtype=np.uint8)
            xp = np.concatenate([x_config_words, xp], axis=0)
            assert xp.shape == (c.IN_BITS/c.X_BITS +r.XN*r.L*r.XW*CM_p*(c.ROWS+c.X_PAD),)

            ic_left = ic_right
            x_list += [xp]
        return x_list


    @staticmethod
    def reorder_y_q2e_conv(y, c, r):
        YH, YW = r.XH_PAD//r.SH_OUT, r.XW//r.SW_OUT

        if r.SH_OUT != 1:
            print("Striding not yet supported")
            return None

        y = np.pad(y, ((0,0),(0,r.LH*r.L-r.XH),(0,0),(0,r.CO_PAD-r.CO)))     # (XN, L*HL , XW, CO_PAD)
        y = y.reshape((r.XN, r.L, c.ROWS, r.XW, r.CO_PAD))                   # (XN,L,c.ROWS,XW,CO_PAD)
        y = y.reshape((r.XN, r.L, c.ROWS, r.XW, r.IT, r.CO_PRL))             # (XN,L,c.ROWS,XW,IT,CO_PRL)
        y = y.transpose(4,0,1,3,5,2)                                         # (IT,XN,L,XW,CO_PRL,c.ROWS)

        assert y.shape == (r.IT,r.XN,r.L,r.XW,r.CO_PRL,c.ROWS)

        y_w_last = y[:,:,:,-(r.KW//2+1):,:,:]
        y_w_last = y_w_last.transpose(0,1,2,4,3,5).reshape(r.IT,r.XN,r.L,(r.KW//2+1)*r.CO_PRL,c.ROWS)

        y = y.reshape(r.IT,r.XN,r.L,r.XW*r.CO_PRL,c.ROWS)
        y[:,:,:,-(r.KW//2+1)*r.CO_PRL:,:] = y_w_last
        return y
    
    @staticmethod
    def reorder_y_e2q_conv(y, c, r):
        y = y.reshape(r.IT,r.XN,r.L,r.XW*r.CO_PRL,c.ROWS)

        y_w_last = y[:,:,:,-(r.KW//2+1)*r.CO_PRL:,:]
        y_w_last = y_w_last.reshape(r.IT,r.XN,r.L,r.CO_PRL,(r.KW//2+1),c.ROWS)
        y_w_last = y_w_last.transpose(0,1,2,4,3,5)   #(r.IT,r.XN,r.L,(r.KW//2+1),r.CO_PRL,c.ROWS)
        y_w_last = y_w_last.reshape(r.IT,r.XN,r.L,(r.KW//2+1),r.CO_PRL,c.ROWS)
        y_w_last = y_w_last.reshape(r.IT,r.XN,r.L,(r.KW//2+1)*r.CO_PRL,c.ROWS)
        
        y[:,:,:,-(r.KW//2+1)*r.CO_PRL:,:] = y_w_last

        y = y.reshape(r.IT,r.XN,r.L,r.XW,r.CO_PRL,c.ROWS)
        y = y.transpose(1,2,5,3,0,4)
        y = y.reshape((r.XN, r.L*c.ROWS, r.XW, r.CO_PAD))
        y = y[:,:r.XH,:,:r.CO]

        return y
