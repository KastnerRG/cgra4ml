import tensorflow as tf 
from tensorflow import keras
from keras.layers import Layer, Add, MaxPooling2D
from qkeras import *
import numpy as np
import math

from deepsocflow.py.utils import *
from deepsocflow.py.xbundle import *
from deepsocflow.py.xmodel import *
from deepsocflow.py.hardware import *


class XActivation(QActivation):
    def __init__(self, sys_bits, o_int_bits, type='relu', slope=1, *args, **kwargs):
        self.sys_bits = sys_bits
        self.o_int_bits = o_int_bits
        self.type = type

        self.slope = 1 if type == None else slope
        self.non_zero = 1*(self.slope != 0)
        self.log_slope = np.log2(self.slope) if self.non_zero else 0
        assert int(self.log_slope) == self.log_slope and self.log_slope <= 0, f"Error: negative_slope:{self.slope} of leaky_relu has to be a negative power of two. eg.0.125"
        self.plog_slope = -int(self.log_slope)
        self.shift_bits = None

        match type:
            case None:
                act_str = f'quantized_bits({sys_bits.x},{o_int_bits},False,1,1)'
            case "relu":
                # QKeras treats relu (slope=0) as unsigned. We have everything signed, so we reduce bitwidth
                o_bits = sys_bits.x - 1 if slope == 0 else sys_bits.x
                assert o_bits > 0, "Error: Cannot use bits=1 with Relu. Use leaky_relu. Reason: Qkeras keeps relu signed"
                act_str = f'quantized_relu({o_bits},{o_int_bits},negative_slope={slope})'
            case _:
                raise ValueError(f"Activation type {type} not recognized")
            
        self.out = XTensor(None, bits=sys_bits.x, int=o_int_bits)
        super().__init__(act_str, *args, **kwargs)

    
    def call(self, input_tensor):
        self.out.ftensor = super().call(input_tensor)
        return self.out.ftensor
    
    def call_int(self, x_tensor, hw):       

        x = x_tensor.itensor.numpy().astype(int)
        self.shift_bits = self.plog_slope + x_tensor.frac - self.out.frac

        x = ((x < 0) * x) * self.non_zero + (((x > 0) * x) << self.plog_slope)
        x = shift_round(x, self.shift_bits) # = np.around(x/2**shift_bits)
        x = np.clip(x, -2**(self.out.bits - self.plog_slope - 1), 2**(self.out.bits-1)-1).astype(int)

        out = XTensor(tensor=x, bits=self.out.bits, frac=self.out.frac, from_int=True)
        assert np.allclose(out.ftensor, self.out.ftensor), \
            f"Activation output does not match. {(out.ftensor.shape, self.out.ftensor.shape)} \nout:{out.ftensor.numpy().flatten()}, \nself.out:{self.out.ftensor.numpy().flatten()}, \nsub:{out.ftensor.numpy().flatten()-self.out.ftensor.numpy().flatten()}"
        self.out = out
        return out


class XConvBN(QConv2DBatchnorm):
    def __init__(self, k_int_bits, b_int_bits, act, *args, **kwargs):

        self.type = 'conv'
        if act is None:
            raise ValueError("Activation function must be provided. Set type to none if no activation is needed")
        
        self.act = act
        self.sys_bits = act.sys_bits
        self.k_frac = get_frac_bits(self.sys_bits.k, k_int_bits)
        self.b_frac = get_frac_bits(self.sys_bits.b, b_int_bits)
        self.out = XTensor(None, None, float_only=True)
        self.bias_val_shift = 0
        self.bias_b_shift = 0
        
        if "kernel_quantizer" in kwargs or "bias_quantizer" in kwargs:
            raise ValueError("kernel_quantizer and bias_quantizer will be derived from act.sys_bits and k_frac")

        self.kernel_quantizer = f'quantized_bits({self.sys_bits.k},{k_int_bits},False,True,1)'
        self.bias_quantizer = f'quantized_bits({self.sys_bits.b},{b_int_bits},False,True,1)'

        #!TODO: use_bias is always True. Need to handle False case
        super().__init__(kernel_quantizer=self.kernel_quantizer, bias_quantizer=self.bias_quantizer, padding='same', *args, **kwargs)


    def call(self, input_tensor):
        self.out.ftensor = super().call(input_tensor)
        return self.out.ftensor

    
    def call_int(self, x_tensor, hw):

        self.x = x_tensor

        self.w = XTensor(tensor=self.kernel_quantizer_internal(self.get_folded_weights()[0]), bits=self.sys_bits.k, frac=self.k_frac)
        self.b = XTensor(tensor=self.bias_quantizer_internal  (self.get_folded_weights()[1]), bits=self.sys_bits.b, frac=self.b_frac)

        # self.act.out.assert_valid()
        self.w.assert_valid()
        if self.use_bias:
            self.b.assert_valid()

        '''
        Conv 2D
        '''
        
        clog2_add = int(np.ceil(np.log2(np.prod(self.w.itensor.shape[:-1]))))
        out = XTensor(
            tensor=tf.keras.backend.conv2d(self.x.itensor, self.w.itensor, padding='same'),
            bits=self.x.bits + self.w.bits + clog2_add,
            frac=self.x.frac + self.w.frac,
            from_int=True
        )
        self.y = out

        '''
        Add Bias
        '''

        out, (self.bias_val_shift, self.bias_b_shift) = out.add_val_shift(self.b)
        assert out.bits <= hw.INT_BITS, \
            f"After bias addition, resulting bits {out.bits} are more than bits for integer in CPU {hw.INT_BITS}. Reduce bits or increase integer bits of bias to continue"
        
        '''
        Striding
        '''
        if self.strides != (1,1):
            KH, KW = self.kernel_size
            CSH, CSW = self.strides

            pre_stride = out.itensor.numpy()

            XN, XH, XW, YC = pre_stride.shape
            CYH, CYW = math.ceil(XH/CSH), math.ceil(XW/CSW)
            
            post_stride = np.zeros((XN, CYH, CYW, YC)).astype(pre_stride.dtype)
            
            (h_shift, w_shift) = (0,0)
            if self.padding=="same":
                h_shift = (KH-1)//2 - max((CSH*(CYH-1)+KH-XH)//2, 0)
                w_shift = (KW-1)//2 - max((CSW*(CYW-1)+KW-XW)//2, 0)

            for xh in range(XH):
                for xw in range(XW):
                    if (xh-h_shift)%CSH == 0 and (xw-w_shift)%CSW == 0:
                        cyh = (xh-h_shift)//CSH
                        cyw = (xw-w_shift)//CSW
                        post_stride[:,cyh,cyw,:] = pre_stride[:,xh,xw,:]

            out = XTensor(tensor=post_stride, bits=out.bits, frac=out.frac, from_int=True)
        
        assert np.allclose(out.ftensor, self.out.ftensor), f"Convolution output does not match \nout:{out.ftensor.numpy().flatten()[:100]}, \nself.out:{self.out.ftensor.numpy().flatten()[:100]}"
        self.out = out
        return out


class XDense(QDense):
    def __init__(self, k_int_bits, b_int_bits, act, *args, **kwargs):

        self.type = 'dense'
        if act is None:
            raise ValueError("Activation function must be provided. Set type to none if no activation is needed")
        
        self.act = act
        self.sys_bits = act.sys_bits
        self.k_frac = get_frac_bits(self.sys_bits.k, k_int_bits)
        self.b_frac = get_frac_bits(self.sys_bits.b, b_int_bits)
        self.out = XTensor(None, None, float_only=True)

        
        if "kernel_quantizer" in kwargs or "bias_quantizer" in kwargs:
            raise ValueError("kernel_quantizer and bias_quantizer will be derived from xconfig and k_frac")

        self.kernel_quantizer = f'quantized_bits({self.sys_bits.k},{k_int_bits},False,True,1)'
        self.bias_quantizer = f'quantized_bits({self.sys_bits.b},{b_int_bits},False,True,1)'

        super().__init__(kernel_quantizer=self.kernel_quantizer, bias_quantizer=self.bias_quantizer, *args, **kwargs)


    def call(self, input_tensor):
        self.out.ftensor = super().call(input_tensor)
        return self.out.ftensor
    

    def call_int(self, x, hw):

        self.x = x
        self.w = XTensor(tensor=self.kernel_quantizer_internal(self.kernel), bits=self.sys_bits.k, frac=self.k_frac)
        self.b = XTensor(tensor=self.bias_quantizer_internal  (self.bias  ), bits=self.sys_bits.b, frac=self.b_frac) if self.use_bias else None

        self.act.out.assert_valid()
        self.w.assert_valid()
        if self.use_bias:
            self.b.assert_valid()

        
        clog2_add = int(np.ceil(np.log2(np.prod(self.w.itensor.shape[:-1]))))
        out = XTensor(
            tensor= self.x.itensor @ self.w.itensor,
            bits=self.x.bits + self.w.bits + clog2_add,
            frac=self.x.frac + self.w.frac,
            from_int=True
        )
        self.y = out

        if self.use_bias:
            out, (self.bias_val_shift, self.bias_b_shift) = out.add_val_shift(self.b)
            assert out.bits <= hw.INT_BITS, f"After bias addition, resulting bits {out.bits} are more than bits for integer in CPU {hw.INT_BITS}. Reduce bits or increase integer bits of bias to continue"
        else:
            self.bias_val_shift, self.bias_b_shift = 0, 0

        assert np.allclose(out.ftensor.numpy(), self.out.ftensor.numpy()), "Dense output does not match"
        self.out = out
        return out


class XAdd(Add):
    def __init__(self, act, sys_bits, *args, **kwargs):
        super().__init__(*args, **kwargs)

        if act is None:
            raise ValueError("Activation function must be provided. Set type to none if no activation is needed")
        self.act = act
        self.sys_bits = sys_bits
        self.out = XTensor(None, None, float_only=True)
        self.source_ib = None
        self.add_val_shift = None
        self.add_a_shift = None

    def call(self, input_tensor):
        self.out.ftensor = super().call(input_tensor)
        return self.out.ftensor
    
    def call_int(self, x, hw):

        out, (self.add_val_shift, self.add_a_shift) = x.add_val_shift(BUNDLES[self.source_ib].out)

        assert out.bits <= hw.INT_BITS, \
            f"After residual addition, resulting bits {out.bits} are more than bits for integer in CPU {hw.INT_BITS}. Reduce bits or increase integer bits of bias to continue"
        
        self.out = out
        return out


class XPool(Layer):
    def __init__(self, type, pool_size, strides, padding, act, *args, **kwargs):
        super().__init__(*args, **kwargs)
        
        assert act is not None, "Activation function must be provided. Set type to none if no activation is needed"
        assert padding in ['same', 'valid'], f"Padding {padding} not recognized"
        assert type in ['avg', 'max'], f"Pooling type {type} not recognized"

        self.type = type
        self.act = act
        self.sys_bits = act.sys_bits
        self.out = XTensor(None, None, float_only=True)

        if self.type == 'avg':
            self.pool_layer = AveragePooling2D(pool_size=pool_size, strides=strides, padding=padding)
        elif self.type == 'max':
            self.pool_layer = MaxPooling2D(pool_size=pool_size, strides=strides, padding=padding)

    def call(self, x):
        self.out.ftensor = self.pool_layer(x)
        return self.out.ftensor
    
    def call_int(self, x, hw):

        self.x = x

        in_arr = x.itensor.numpy().astype(int)
        YN, YH, YW, YC = in_arr.shape
        PKH, PKW = self.pool_layer.pool_size
        PSH, PSW = self.pool_layer.strides

        if self.pool_layer.padding == "same":
            PXH = (YH+PSH-1)//PSH
            PXW = (YW+PSW-1)//PSW
        else:
            PXH = (YH-PKH+PSH)//PSH
            PXW = (YW-PKW+PSW)//PSW

        out_arr = np.zeros((YN, PXH, PXW, YC), dtype=int)

        p_st, q_st = 0, 0
        if self.pool_layer.padding == "same":
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
                                result = -math.inf if self.type == 'max' else 0
                                for ipyh in range(ph_end, ph_beg,-1):
                                    for ipyw in range(pw_end, pw_beg,-1):
                                        
                                        if self.type=='max':
                                            result = max(result, in_arr[n,ipyh,ipyw,ic])
                                        else:
                                            result += in_arr[n,ipyh,ipyw,ic]

                                count  = (ph_end-ph_beg)*(pw_end-pw_beg)
                                result = result if self.type=='max' else div_round(result, count)
                                ''' Writing '''
                                out_arr[n,ixh,ixw,ic] = result

                                pw_beg += PSW # move pooling window by stride
                                pw_end = min(pw_end+PSW, YW-1)
                            ph_beg += PSH # move pooling window by stride
                            ph_end = min(ph_end+PSH, YH-1)
        
        bits = x.bits + int(np.ceil(np.log2(PKH*PKW))) if self.type == 'avg' else x.bits
        assert bits <= hw.INT_BITS, f"When summing avg pool, resulting bits {bits} are more than bits for integer in CPU {hw.INT_BITS}. Reduce bits or increase integer bits of bias to continue"

        out = XTensor(tensor=out_arr, bits=bits, frac=x.frac, from_int=True)
        if self.type != 'avg': # out.ftensor for avg pool has recurring float (0.333)
            assert np.allclose(out.ftensor, self.out.ftensor), f"Activation output does not match. \nout:{out.ftensor.numpy().flatten()[:100]}, \nself.out:{self.out.ftensor.numpy().flatten()[:100]}"
        self.out = out
        return out