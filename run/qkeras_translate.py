from tensorflow import keras
from keras.layers import Flatten, Activation, Input, Layer
from keras.models import Model, save_model

from keras.datasets import mnist
from keras.optimizers import Adam
from keras.utils import to_categorical

from qkeras import *
from qkeras.utils import load_qmodel
import numpy as np

np.random.seed(42)

'''
Custom Classes
'''
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


@keras.saving.register_keras_serializable()
class XActivation(QActivation):
    def __init__(self, sys_bits, o_int_bits, type='relu', slope=1, *args, **kwargs):

        match type:
            case None:
                act_str = f'quantized_bits({sys_bits.x},{o_int_bits},False,False,1)'
            case "relu":
                act_str = f'quantized_relu({sys_bits.x},{o_int_bits},negative_slope={slope})'
            case _:
                raise ValueError(f"Activation type {type} not recognized")
            
        super().__init__(act_str, *args, **kwargs)


@keras.saving.register_keras_serializable()
class XConvBN(QConv2DBatchnorm):
    def __init__(self, sys_bits, k_int_bits, b_int_bits, o_int_bits, act, *args, **kwargs):
        self.sys_bits = sys_bits
        self.k_frac = get_frac_bits(sys_bits.k, k_int_bits)
        self.o_bits = sys_bits.x
        self.out_frac = get_frac_bits(self.o_bits, o_int_bits)
        self.act = act

        if act is None:
            raise ValueError("Activation function must be provided. Set type to none if no activation is needed")
        
        if "kernel_quantizer" in kwargs or "bias_quantizer" in kwargs:
            raise ValueError("kernel_quantizer and bias_quantizer will be derived from xconfig and k_frac")

        self.kernel_quantizer = f'quantized_bits({sys_bits.k},{k_int_bits},False,True,1)'
        self.bias_quantizer = f'quantized_bits({sys_bits.b},{b_int_bits},False,True,1)'

        super().__init__(kernel_quantizer=self.kernel_quantizer, bias_quantizer=self.bias_quantizer, *args, **kwargs)


class XPool(Layer):
    def __init__(self, type, size, strides, padding, act, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.type = type
        self.size = size
        self.strides = strides
        self.padding = padding
        self.act = act


        if self.type == 'avg':
            self.pool_layer = AveragePooling2D(pool_size=size, strides=strides, padding=padding)
        elif self.type == 'max':
            self.pool_layer = MaxPooling2D(pool_size=size, strides=strides, padding=padding)
        else:
            raise ValueError(f"Pooling type {type} not recognized")
        
        if act is None:
            raise ValueError("Activation function must be provided. Set type to none if no activation is needed")

    def call(self, x):
        x = self.pool_layer(x)
        return x

@keras.saving.register_keras_serializable()
class XBundle(Layer):

    def __init__(self, core, pool=None, flatten=False, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.flatten = flatten
        self.core = core
        self.pool = pool

        if self.flatten:
            self.flatten = Flatten()

    def call(self, input_tensor, training=False, x_1=None):
    
        x = input_tensor
        if hasattr(x, "bundle"):
            self.prev_bundle = x.bundle
            self.prev_bundle.next_bundles += [self]
        else:
            self.prev_bundle = None

        # self.inp['tensor'] = x 

        x = self.core(x)
        x = self.core.act(x)
        # self.core['tensor'] = x 

        # if x_1 is not None:
        #     if hasattr(x_1, "bundle"):
        #         self.add['bundle'] = x_1.bundle
        #         x_1.bundle.add_tensor_dest += [self.idx]
        #     else:
        #         self.add['bundle'] = None
        #     x = Add()([x, x_1])
        #     x = self.act_add(x)
        #     # self.add['tensor'] = x
        if self.pool:
            x = self.pool(x)
            x = self.pool.act(x)
        #     # self.pool['tensor'] = x
        if self.flatten:
            x = self.flatten(x)
        # if self.softmax:
        #     x = self.softmax(x)

        # self.out['tensor'] = x
        x.bundle = self
        return x
    
@keras.saving.register_keras_serializable()
class XModel(Layer):

    def get_config(self):
        config = super().get_config().copy()
        config.update({
            'sys_bits': self.sys_bits,
            'x_int_bits': self.x_int_bits,
        })
        return config

    def __init__(self, sys_bits, x_int_bits, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.sys_bits = sys_bits
        self.x_int_bits = x_int_bits
        self.input_quant_layer = QActivation(f'quantized_bits({sys_bits.x},{x_int_bits},False,True,1)')


'''
Dataset
'''

NB_EPOCH = 3
BATCH_SIZE = 64
VERBOSE = 1
VALIDATION_SPLIT = 0.1
NB_CLASSES = 10

(x_train, y_train), (x_test, y_test) = mnist.load_data()

x_train = x_train.astype("float32")[..., np.newaxis] / 256.0
x_test = x_test.astype("float32")[..., np.newaxis] / 256.0

print(f"train.shape: {x_train.shape}, test.shape: {x_test.shape}")
print("labels[0:10]: ", y_train[0:10])

y_train = to_categorical(y_train, NB_CLASSES)
y_test = to_categorical(y_test, NB_CLASSES)




'''
Define Model
'''

sys_bits = SYS_BITS(x=4, k=4, b=32)

@keras.saving.register_keras_serializable()
class UserModel(XModel):
    def __init__(self, sys_bits, x_int_bits, *args, **kwargs):
        super().__init__(sys_bits, x_int_bits, *args, **kwargs)

        self.m1 = XBundle( 
            core=XConvBN(
                k_int_bits=0,
                b_int_bits=0,
                o_int_bits=0,
                filters=8,
                kernel_size=(11,11),
                strides=(2,1),
                padding="same",
                use_bias=True,
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type='relu', slope=0),
                sys_bits=sys_bits,),

            pool=XPool(
                type='avg',
                size=(3,4),
                strides=(2,3),
                padding='same',
                act=XActivation(sys_bits=sys_bits, o_int_bits=0, type=None),),

            flatten=True)

        self.dense = QDense(NB_CLASSES, kernel_quantizer=quantized_bits(sys_bits.x,0,1),
                        bias_quantizer=quantized_bits(sys_bits.x,0,1))
        self.act4  = Activation("softmax", name="softmax")

    def call (self, x):
        x = self.input_quant_layer(x)

        x = self.m1(x)

        x = self.dense(x)
        x = self.act4 (x)
        return x

x = x_in =  Input(x_train.shape[1:], name="input")
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
        verbose=VERBOSE,
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

save_model(model, "mnist.h5")


'''
Reload Model
'''

loaded_model = load_qmodel("mnist.h5")
score = loaded_model.evaluate(x_test, y_test, verbose=0)
print(f"Test loss:{score[0]}, Test accuracy:{score[1]}")

# print(loaded_model.layers[1].m1.get_raw())
