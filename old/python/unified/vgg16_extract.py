# %%
from importlib import reload
import numpy as np
import tensorflow as tf
import cv2
import glob
import pickle

# %%
from tensorflow.keras.applications.vgg16 import preprocess_input

image_paths = glob.glob('dataset/*.jpg')[:7]
input_batch = []
for image_path in image_paths:
    x = cv2.imread(image_path)
    x = cv2.resize(x, (224, 224))
    x = x[:,:,::-1]
    x = np.expand_dims(x, 0)
    x = preprocess_input(x)
    input_batch += [x]
input_batch = np.concatenate(input_batch, axis=0)

print(input_batch.shape)

# %%
from tensorflow import keras
model = keras.models.load_model('old/saved_model/vgg16')
model.compile

with tf.device("cpu:0"):
    model_out = model(input_batch)

# %%
BATCH = 7

interpreter = tf.lite.Interpreter(model_path=f'tflite/vgg16.tflite', experimental_preserve_all_tensors=True)

input_details = interpreter.get_input_details()[0]
output_details = interpreter.get_output_details()[0]

input_shape = input_details['shape']
interpreter.resize_tensor_input(input_details['index'],[BATCH, input_shape[1], input_shape[2], input_shape[3]])
interpreter.allocate_tensors()

input_scale, input_zero_point = input_details["quantization"]
tflite_input_batch = np.rint(input_batch / input_scale + input_zero_point).astype(np.int8)
interpreter.set_tensor(input_details["index"], tflite_input_batch)
interpreter.invoke()

tflite_output_batch = interpreter.get_tensor(output_details["index"])
np.save('vgg16-7.npy',tflite_output_batch)

# %%
import vgg16_numpy
reload(vgg16_numpy)
from vgg16_numpy import VGG16_Numpy

vgg16 = VGG16_Numpy(quantize=False,input_batch=input_batch, float_dtype= np.float32, np_dtype= np.float32, np_dtype_conv_out=np.float32)
# vgg16.tflite_interpreter = interpreter
# vgg16.tensor_details = interpreter.get_tensor_details()
vgg16.keras_layers = model.layers

vgg16.compile()
vgg16.fwd_pass()

import pickle
# pickle.dump(vgg16.model.d, open('vgg16_layers.pickle', 'wb'))

# %%
np.argmax(vgg16.softmax_output,axis=-1), np.argmax(model_out,axis=-1)

# %%
np.allclose(model_out.numpy(),vgg16.softmax_output.reshape(7,1000), rtol=1e-5,atol=1e-5)

# %%
from copy import deepcopy
layer = deepcopy(vgg16.model.d['conv2d_14'])
layer_relu = deepcopy(vgg16.model.d['relu_14'])
old_out = layer_relu.np_out_data
# layer.weights = layer.weights.reshape(1,1,512,7,7,4096).transpose(0,1,3,4,2,5).reshape(1, 1, 25088, 4096)
layer.weights = layer.weights.reshape(1,1,7,7,512,4096).transpose(0,1,4,2,3,5).reshape(1, 1, 25088, 4096)

out = layer.np_out(layer.in_data)
out = layer_relu.np_out(out)
interpreter.get_tensor(53)-out
# np.allclose(out, old_out)

# %%
7*7*512

# %%
interpreter._get_op_details(22)
# interpreter.get_tensor(6).shape  # w: (co,kh,kw,ci)
# interpreter.get_tensor(32).shape # w: (co,ci)
# interpreter.get_tensor(34).shape # x: (n,h,w,c)
# interpreter.get_tensor(55).shape # x: (n,c)

interpreter._get_op_details(21)

# %%
# w = interpreter.get_tensor(28).reshape(4096,512,7,7).transpose(0,2,3,1).reshape(4096,25088)
# w = interpreter.get_tensor(28).reshape(4096,7,7,512).transpose(0,3,1,2).reshape(4096,25088)
x = (interpreter.get_tensor(54) - interpreter._get_tensor_details(54)['quantization'][1])*interpreter._get_tensor_details(54)['quantization'][0]
y = (interpreter.get_tensor(55) - interpreter._get_tensor_details(55)['quantization'][1])*interpreter._get_tensor_details(55)['quantization'][0]
w = (interpreter.get_tensor(32) - interpreter._get_tensor_details(32)['quantization'][1])*interpreter._get_tensor_details(32)['quantization'][0]
b = (interpreter.get_tensor(33) - interpreter._get_tensor_details(33)['quantization'][1])*interpreter._get_tensor_details(33)['quantization'][0]

y1 = x @ w.T + b
# y[y<0] *= 0

np.sum(y-y1)

# %%


# %%
interpreter.get_tensor(33).shape

# %%
interpreter._get_tensor_details(33)['quantization']

# %%
y.shape

# %%
a = x @ w.T
a.dtype

# %%
np.sum(interpreter.get_tensor(51).reshape(7,25088) - interpreter.get_tensor(52))

# %%
vgg16.fwd_pass()
pickle.dump(vgg16.model.d, open('vgg16_layers_fwd.pickle', 'wb'))

# %%
interpreter._get_op_details(18)

# %%
np.sum(vgg16.model.d['relu_14'].np_out_data - interpreter.get_tensor(53) > 1)

# %%
interpreter._get_ops_details()[2]
# interpreter.get_tensor(37).shape

# %%
# vgg16.model.d['maxpool_1'].np_out_data - interpreter.get_tensor(36)

# %%
interpreter.get_tensor(35)[0,:10,:10,0].reshape(1,5,2,5,2,1).max(axis=2).max(axis=3).reshape(5,5)

# %%
interpreter.get_tensor(35)[0,:10,:10,0]

# %%
interpreter.get_tensor(36)[0,:5,:5,0]

# %%
vgg16.model.d['maxpool_1'].np_out_data[0,:5,:5,0]

# %%
vgg16.model.d['relu_3'].np_out_data
np.sum(vgg16.model.d['conv2d_3'].biases - interpreter.get_tensor(7))

# %%
# vgg16.model.d['maxpool_1'].np_out_data - vgg16.model.d['conv2d_3'].in_data

# %%
# out = vgg16.model.d['conv2d_3'].np_out(vgg16.model.d['maxpool_1'].np_out_data)
out = vgg16.model.d['conv2d_3'].np_out(interpreter.get_tensor(36))
out = vgg16.model.d['relu_3'].np_out(out)
out - interpreter.get_tensor(37)

# %%
interpreter.get_tensor(37).shape

# %%
vgg16.model.d['relu_3'].np_out_data.shape

# %%
input_batch.shape

# %%
interpreter._get_op_details(0)

# %%
interpreter.get_input_details()

# %%
vgg16.model.d['relu_1'].np_out_data

# %%
vgg16.model.d['relu_16'].np_out_data.shape

# %%
interpreter._get_op_details(5)

# %%
np.sum((interpreter.get_tensor(38) - vgg16.model.d['relu_4'].np_out_data)**2 > 0)

# %%
tf_arr = interpreter.get_tensor(38)
np_arr = vgg16.model.d['relu_4'].np_out_data

# %%
interpreter._get_tensor_details(39)

# %%
interpreter._get_tensor_details(38)

# %%
tf_arr.shape

# %%
interpreter.get_tensor(38)[0,0:4,0:4,0]

# %%
tf_arr[0,0:4,0:4,0]

# %%
tf_arr_max[0,0:2,0:2,0]

# %%
interpreter.get_tensor(39)[0,0:2,0:2,0]

# %%
interpreter.get_tensor(39).shape

# %%
tf_arr_max = tf_arr.reshape(1, 112//2,2, 112//2,2, 128).max(axis=2).max(axis=3)
np_arr_max = np_arr.reshape(1, 112//2,2, 112//2,2, 128).max(axis=2).max(axis=3)

# %%
vgg16_keras.summary()

# %%
interpreter.get_tensor(39) - tf_arr_max

# %%
vgg16_keras = tf.keras.models.load_model(f'old/saved_model/vgg16/')
vgg16_keras.compile()
# vgg16_keras.layers

# %%
# vgg16_keras.layers

# %%
vgg16_keras.layers[3].pool_size

# %%
index = 22

from tensorflow.keras.models import Model
print('Keras layers: ', len(vgg16_keras.layers))
model_keras = Model(vgg16_keras.input, outputs=vgg16_keras.layers[index].output)
with tf.device('/cpu:0'):
    # out_keras = model_keras(input_batch)
    out_keras = vgg16_keras(input_batch)


