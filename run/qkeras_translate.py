from tensorflow import keras
from keras.layers import Flatten, Activation, Input, Layer, Add
from keras.models import Model, save_model

import tensorflow as tf
from keras.datasets import mnist
from keras.optimizers import Adam
from keras.utils import to_categorical

from qkeras import *
from qkeras.utils import load_qmodel
import numpy as np
from copy import deepcopy
import os
import math

sys.path.append("../../")
from deepsocflow import Hardware

np.random.seed(42)

BUNDLES = []

'''
Custom Classes
'''



class XTensor:
    def __init__(self, tensor, bits, frac=None, int=None, float_only=False, from_int=False):
        self.bits = bits
        self.float_only = float_only
        self.from_int = from_int
        self.error = ""
        if not float_only:
            self.frac = get_frac_bits(bits, int) if frac is None else frac
            self.int = get_int_bits(bits, frac) if int is None else int

        tensor = tf.convert_to_tensor(tensor) if isinstance(tensor, np.ndarray) else tensor

        if from_int:
            self._itensor = tensor
            self.ftensor = tensor / 2**self.frac
        else:
            self._itensor = None
            self.ftensor = tensor

    @property
    def itensor(self):
        if self.float_only:
            raise ValueError("Only float tensor available")
        
        if self.from_int:
            return self._itensor
        else:  
            return self.ftensor * 2**self.frac


    @property
    def valid(self):
        valid = (self.itensor.numpy() == self.itensor.numpy().astype(int)).all()

        if self.float_only:
            self.error = "Float only"
            return False
        elif not valid:
            self.error = f"Wrong quantization:\n bits:{self.bits}\n frac:{self.frac}\n itensor:{self.itensor}"
            return False
        else:
            return True
        
    def assert_valid(self):
        assert self.valid, self.error

    def add_val_shift(self, other):

        '''
        Add s,t while preserving precision
        '''
        s_intb, t_intb = self.bits-self.frac, other.bits-other.frac

        r_frac = max(self.frac,other.frac)
        r_intb = max(s_intb,t_intb)
        r_bits = 1 + r_intb + r_frac # +1 to allow overflow

        s_shift = r_frac-self.frac
        t_shift = r_frac-other.frac

        r = (self.itensor * 2**s_shift) + (other.itensor * 2**t_shift)
        r_tensor = XTensor(tensor=r, bits=r_bits, frac=r_frac, from_int=True)
        return r_tensor, (s_shift, t_shift)

@keras.saving.register_keras_serializable()
class SYS_BITS:
    def __init__(self, x, k, b):
        self.x = x
        self.k = k
        self.b = b
    def get_config(self):
        return {'x': self.x, 'k': self.k, 'b': self.b}

def get_int_bits(bits, frac):
    return bits-frac-1 # we always use signed integer

def get_frac_bits(bits, int_bits):
    return bits-int_bits-1  # we always use signed integer


class XActivation(QActivation):
    def __init__(self, sys_bits, o_int_bits, type='relu', slope=1, *args, **kwargs):
        self.sys_bits = sys_bits
        self.o_int_bits = o_int_bits
        self.type = type

        self.slope = slope
        self.non_zero = 1*(slope != 0)
        self.log_slope = np.log2(slope) if self.non_zero else 0
        assert int(self.log_slope) == self.log_slope and self.log_slope <= 0, f"Error: negative_slope:{slope} of leaky_relu has to be a negative power of two. eg.0.125"
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

        def shift_round(n,s):
            '''Performs integer division with round-to-nearest-even. 
               Eq: np.around(n/2**s).astype(int)'''
            half_b = 1<<(s-1) if s>0 else 0
            return (n + half_b - (s>0)*(~(n>>s)&1) ) >> s
        
        def div_round(n,d):
            '''Performs integer division with round-to-nearest-even for d>0. 
               Eq: np.around(n/d).astype(int)'''
            return (n + (d//2) - (~(d|n//d) &1)) // d
        

        x = x_tensor.itensor.numpy().astype(int)
        self.shift_bits = self.plog_slope + x_tensor.frac - self.out.frac

        print(f"Applying {self.type} with bits:{self.out.bits}, frac:{self.out.frac}, plog_slope:{self.plog_slope}, non_zero:{self.non_zero}, shift_bits:{self.shift_bits}")

        x = ((x < 0) * x) * self.non_zero + (((x > 0) * x) << self.plog_slope)
        x = shift_round(x, self.shift_bits) # = np.around(x/2**shift_bits)
        x = np.clip(x, -2**(self.out.bits - self.plog_slope - 1), 2**(self.out.bits-1)-1).astype(int)

        out = XTensor(tensor=x, bits=self.out.bits, frac=self.out.frac, from_int=True)

        assert np.allclose(out.ftensor, self.out.ftensor), f"Activation output does not match. \nout:{out.ftensor.numpy().flatten()[:100]}, \nself.out:{self.out.ftensor.numpy().flatten()[:100]}"
        self.out = out
        return out

# Applying relu with bits:4, frac:3, plog_slope:0, non_zero:0, shift_bits:12
# Applying relu with bits:4, frac:3, plog_slope:0, non_zero:0, shift_bits:12

class XConvBN(QConv2DBatchnorm):
    def __init__(self, k_int_bits, b_int_bits, act, *args, **kwargs):

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

        super().__init__(kernel_quantizer=self.kernel_quantizer, bias_quantizer=self.bias_quantizer, padding='same', *args, **kwargs)


    def call(self, input_tensor):
        self.out.ftensor = super().call(input_tensor)
        return self.out.ftensor

    
    def call_int(self, x_tensor, hw):

        self.x = x_tensor

        self.w = XTensor(tensor=self.kernel_quantizer_internal(self.get_folded_weights()[0]), bits=self.sys_bits.k, frac=self.k_frac)
        self.b = XTensor(tensor=self.kernel_quantizer_internal(self.get_folded_weights()[1]), bits=self.sys_bits.b, frac=self.b_frac) if self.use_bias else None

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

        print(f"{out.bits=}, {self.x.bits=} + {self.w.bits=} + {clog2_add=}")

        '''
        Add Bias
        '''

        if self.use_bias:
            out, (self.bias_val_shift, self.bias_b_shift) = out.add_val_shift(self.b)
            assert out.bits <= hw.INT_BITS, f"After bias addition, resulting bits {out.bits} are more than bits for integer in CPU {hw.INT_BITS}. Reduce bits or increase integer bits of bias to continue"
        else:
            self.bias_val_shift, self.bias_b_shift = 0, 0
        
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
        
        assert np.allclose(out.ftensor, self.out.ftensor), "Convolution output does not match"
        self.out = out
        return out

class XDense(QDense):
    def __init__(self, k_int_bits, b_int_bits, act, *args, **kwargs):

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
    

    def call_int(self, x_tensor, hw):

        self.inp = x_tensor
        self.w = XTensor(tensor=self.get_folded_weights()[0], bits=sys_bits.k, frac=self.k_frac)
        self.b = XTensor(tensor=self.get_folded_weights()[1], bits=sys_bits.b, frac=self.b_frac) if self.use_bias else None

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
        assert np.allclose(out.ftensor.numpy(), self.out.ftensor.numpy()), "Dense output does not match"
        self.out = out



class XAdd(Add):
    def __init__(self, act, sys_bits, *args, **kwargs):
        super().__init__(*args, **kwargs)

        if act is None:
            raise ValueError("Activation function must be provided. Set type to none if no activation is needed")
        self.act = act
        self.sys_bits = sys_bits
        self.out = XTensor(None, None, float_only=True)

    def call(self, input_tensor):
        self.out.ftensor = super().call(input_tensor)
        return self.out.ftensor


class XPool(Layer):
    def __init__(self, type, size, strides, padding, act, *args, **kwargs):
        super().__init__(*args, **kwargs)
        
        self.type = type
        self.size = size
        self.strides = strides
        self.padding = padding

        if act is None:
            raise ValueError("Activation function must be provided. Set type to none if no activation is needed")
        
        self.act = act
        self.sys_bits = act.sys_bits
        self.out = XTensor(None, None, float_only=True)

        if self.type == 'avg':
            self.pool_layer = AveragePooling2D(pool_size=size, strides=strides, padding=padding)
        elif self.type == 'max':
            self.pool_layer = MaxPooling2D(pool_size=size, strides=strides, padding=padding)
        else:
            raise ValueError(f"Pooling type {type} not recognized")

    def call(self, x):
        self.out.ftensor = self.pool_layer(x)
        return self.out.ftensor

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

        # self.inp = self.core.inp

        self.out = self.core.out
        if self.pool:
            self.out = self.pool.out
        if self.add:
            self.out = self.add.out
        if self.flatten:
            self.out = self.flatten.out
        if self.softmax:
            self.out = XTensor(None, None, float_only=True)

        self.ib = None
        self.prev_ib = None
        self.next_ibs = []


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
            if self.add is None:
                raise ValueError("Activation function must be provided for add layer")
            
            # if hasattr(x_add, "bundle"):
            #     self.add['bundle'] = x_add.bundle
            #     x_add.bundle.add_tensor_dest += [self.idx]
            # else:
            #     self.add['bundle'] = None
            x = self.add([x, x_add])
            x = self.add.act(x)
        if self.pool:
            x = self.pool(x)
            x = self.pool.act(x)
        if self.flatten:
            x = self.flatten(x)
        if self.softmax:
            x = self.softmax(x)

        x.ib = self.ib
        return x
    
    def call_int(self, x, hw):

        self.inp = x if self.ib == 0 else BUNDLES[self.prev_ib].out

        out = self.core.call_int(self.inp, hw)
        out = self.core.act.call_int(out, hw)

class XInputAct(QActivation):
    def __init__(self, *args, **kwargs):            
        super().__init__(*args, **kwargs)
    
    def call(self, x):
        return super().call(x)

@keras.saving.register_keras_serializable()
class XModel(Layer):

    def __init__(self, sys_bits, x_int_bits, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.sys_bits = sys_bits
        self.x_int_bits = x_int_bits
        self.input_quant_layer = XInputAct(f'quantized_bits({sys_bits.x},{x_int_bits},False,True,1)')

    def get_config(self):
        config = super().get_config().copy()
        config.update({
            'sys_bits': self.sys_bits,
            'x_int_bits': self.x_int_bits,
        })
        return config



'''
Dataset
'''

NB_EPOCH = 0
BATCH_SIZE = 64
VALIDATION_SPLIT = 0.1
NB_CLASSES = 10

(x_train, y_train), (x_test, y_test) = mnist.load_data()

x_train = x_train.astype("float32")[..., np.newaxis] / 256.0
x_test = x_test.astype("float32")[..., np.newaxis] / 256.0

print(f"train.shape: {x_train.shape}, test.shape: {x_test.shape}")
print("labels[0:10]: ", y_train[0:10])

y_train = to_categorical(y_train, NB_CLASSES)
y_test = to_categorical(y_test, NB_CLASSES)

input_shape = x_train.shape[1:]


'''
Define Model
'''

sys_bits = SYS_BITS(x=4, k=4, b=16)

@keras.saving.register_keras_serializable()
class UserModel(XModel):
    def __init__(self, sys_bits, x_int_bits, *args, **kwargs):
        super().__init__(sys_bits, x_int_bits, *args, **kwargs)

        self.b1 = XBundle( 
            core=XConvBN(
                k_int_bits=0,
                b_int_bits=0,
                filters=8,
                kernel_size=11,
                strides=(2,1),
                use_bias=True,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0)),
            pool=XPool(
                type='avg',
                size=(3,4),
                strides=(2,3),
                padding='same',
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type=None),)
            )
        
        self.b2 = XBundle( 
            core=XConvBN(
                k_int_bits=0,
                b_int_bits=0,
                filters=8,
                kernel_size=1,
                use_bias=True,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type=None)),
            add_act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0.125)
        )
        
        self.b3 = XBundle( 
            core=XConvBN(
                k_int_bits=0,
                b_int_bits=0,
                filters=8,
                kernel_size=7,
                use_bias=False,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type=None),),
            add_act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0)
        )

        self.b4 = XBundle( 
            core=XConvBN(
                k_int_bits=0,
                b_int_bits=0,
                filters=8,
                kernel_size=5,
                use_bias=True,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type=None),),
            add_act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0)
        )

        self.b5 = XBundle( 
            core=XConvBN(
                k_int_bits=0,
                b_int_bits=0,
                filters=24,
                kernel_size=3,
                use_bias=True,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0),),
        )

        self.b6 = XBundle( 
            core=XConvBN(
                k_int_bits=0,
                b_int_bits=0,
                filters=10,
                kernel_size=1,
                use_bias=True,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0),),
            flatten=True
        )

        self.b7 = XBundle(
            core=XDense(
                k_int_bits=1,
                b_int_bits=1,
                units=NB_CLASSES,
                act=XActivation(sys_bits=sys_bits, o_int_bits=1, type=None),),
            softmax=True
        )

        # TODO: Remove act before softmax to improve accuracy

        # self.dense = QDense(NB_CLASSES, kernel_quantizer=quantized_bits(sys_bits.x,0,1),
        #         bias_quantizer=quantized_bits(sys_bits.x,0,1))
        # self.act4  = Activation("softmax", name="softmax")

    def call (self, x):
        x = self.input_quant_layer(x)

        x = x_skip1 = self.b1(x)
        x = x_skip2 = self.b2(x, x_skip1)
        x = self.b3(x, x_skip2)
        x = self.b4(x, x_skip1)
        x = self.b5(x)
        x = self.b6(x)
        x = self.b7(x)
        return x

x = x_in =  Input(input_shape, name="input")
user_model = UserModel(sys_bits=sys_bits, x_int_bits=0)
x = user_model(x_in)

model = Model(inputs=[x_in], outputs=[x])


'''
Train Model
'''

model.compile(loss="categorical_crossentropy", optimizer=Adam(learning_rate=0.0001), metrics=["accuracy"])
history = model.fit(
        x_train, 
        y_train, 
        batch_size=BATCH_SIZE,
        epochs=NB_EPOCH, 
        initial_epoch=1, 
        verbose=True,
        validation_split=VALIDATION_SPLIT)

print(model.submodules)

for layer in model.submodules:
    try:
        print(layer.summary())
        for w, weight in enumerate(layer.get_weights()):
                print(layer.name, w, weight.shape)
    except:
        pass
# print_qstats(model.layers[1])

def summary_plus(layer, i=0):
    if hasattr(layer, 'layers'):
        if i != 0: 
            layer.summary()
        for l in layer.layers:
            i += 1
            summary_plus(l, i=i)

print(summary_plus(model)) # OK 
model.summary(expand_nested=True)


'''
Save Model
'''

# print(model.outputs[0].bundle)
# print(model.outputs[0].prev.bundle)

save_model(model, "mnist.h5")


'''
Reload Model
'''

loaded_model = load_qmodel("mnist.h5")

score = loaded_model.evaluate(x_test, y_test, verbose=0)
print(f"Test loss:{score[0]}, Test accuracy:{score[1]}")




def export_inference(model, hw):
    
    BUNDLES.clear()
    user_model = model.layers[1]
    input_shape = (1, *model.inputs[0].shape[1:])
    x_keras = tf.random.uniform(input_shape)
    x_qtensor = user_model.input_quant_layer(x_keras)
    out_keras = model(x_keras)

    assert hw.X_BITS == user_model.sys_bits.x
    assert hw.K_BITS == user_model.sys_bits.k
    assert hw.B_BITS >= user_model.sys_bits.b

    for i, b in enumerate(BUNDLES):
        print(f"Bundle {i}: {b}")

    x = XTensor(tensor=x_qtensor, bits=hw.X_BITS, int=user_model.x_int_bits)   


    '''
    Export
    '''
    
    
    ''' Clean the data directory'''
    os.makedirs(hw.DATA_DIR, exist_ok=True)
    for file in os.scandir(hw.DATA_DIR):
        os.remove(file.path)
    

    print("\n-----------STARTING EXPORT-----------\n")
    add_buffer_map = []
    out_buffer_map = []

    

    for ib, b in enumerate(BUNDLES):
        print(f'-----------------idx:{ib}-----------------------')
        b.call_int(x if ib==0 else None, hw)
    #     # b.export(hw, False)



hw = Hardware (                          # Alternatively: hw = Hardware.from_json('hardware.json')
        processing_elements = (8, 24)  , # (rows, columns) of multiply-add units
        frequency_mhz       = 250      , #  
        bits_input          = 4        , # bit width of input pixels and activations
        bits_weights        = 4        , # bit width of weights
        bits_sum            = 24       , # bit width of accumulator
        bits_bias           = 32       , # bit width of bias
        max_batch_size      = 64       , # 
        max_channels_in     = 2048     , #
        max_kernel_size     = 13       , #
        max_image_size      = 512      , #
        ram_weights_depth   = 20       , #
        ram_edges_depth     = 288      , #
        axi_width           = 64       , #
        target_cpu_int_bits = 32       , #
        valid_prob          = 1        , # probability in which AXI-Stream s_valid signal should be toggled in simulation
        ready_prob          = 1        , # probability in which AXI-Stream m_ready signal should be toggled in simulation
        data_dir            = 'vectors', # directory to store generated test vectors
     )

export_inference(loaded_model, hw)

print(BUNDLES[0].core.out.ftensor)
# print(loaded_model.outputs[0].bundle)
# print(loaded_model.outputs[0].prev.bundle)

