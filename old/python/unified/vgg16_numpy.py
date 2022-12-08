import numpy as np
import tensorflow as tf
import cv2
import glob
from tensorflow.keras.applications.vgg16 import preprocess_input

import sys
sys.path.append("../aba_framework")

from importlib import reload
import aba_framework
reload(aba_framework)
from aba_framework import *
from utils import _softmax

def print_count_diff(x, y, name=''):
    print(f'Count diff > 1 ({name}): ', np.sum(np.abs(x - y) > 1))

class VGG16_Numpy():
    def __init__(self,
                 quantize = True,
                 input_batch = None,
                 np_dtype=np.int8,
                 np_dtype_sum=np.int32,
                 np_dtype_conv_out=np.int32,
                 float_dtype= np.float32,
                 bits_conv_out=32,
                 input_W=224,
                 input_H=224,
                 tflite_path='tflite/vgg16.tflite'):

        self.model = MyModel()
        self.output = None
        self.tflite_path = tflite_path
        self.np_dtype = np_dtype
        self.np_dtype_sum = np_dtype_sum
        self.np_dtype_conv_out = np_dtype_conv_out
        self.np_dtype_out = np_dtype_conv_out
        self.bits_conv_out = bits_conv_out
        self.float_dtype = float_dtype
        self.float_ieee = True
        self.quantize = quantize
        self.model_preprocess = preprocess_input
        self.input_W = input_W
        self.input_H = input_H
        self.input_batch = input_batch

    def compile(self):
        '''
        Input Layer
        '''
        q = self.quantize

        layer_name = 'input_1'
        self.input_layer = MyInput(self.input_batch,
                                   name=layer_name,
                                   GAMMA=1,
                                   np_dtype=self.np_dtype,
                                   quantize=q)
        self.model.d[layer_name] = self.input_layer
        if q:
            self.input_layer.scale, self.input_layer.zero_point = self.tflite_interpreter.get_input_details()[0]["quantization"]
            self.input_layer.set_input_batch()

        out_data = self.input_layer.get_np_output_recursively()

        if q:
            print_count_diff(self.tflite_interpreter.get_tensor(0), out_data, layer_name)

            lut = np.arange(start=0, stop=256)
            lut = self.model_preprocess(lut)
            lut = lut/self.input_layer.scale + self.input_layer.zero_point
            lut = np.round(lut).astype(np.int8)
            self.input_layer.quantize_lut = lut

        op_i = 0
        conv_i = 0
        maxpool_i = 0
        reshape_i = 0

        while True:
            try:
                if q:
                    op = self.tflite_interpreter._get_op_details(op_i)
                else:
                    keras_layer = self.keras_layers[op_i]
            except:
                break
            
            # if op_i == 20:
            #     break

            op_i += 1

            if q:
                op_name = op['op_name']
                op_inputs = op['inputs']
                op_outputs = op['outputs']

            is_conv = op_name == 'CONV_2D' if q else isinstance(keras_layer, tf.keras.layers.Conv2D)
            is_dense = op_name == 'FULLY_CONNECTED' if q else isinstance(keras_layer, tf.keras.layers.Dense)
            is_maxpool = op_name == 'MAX_POOL_2D' if q else isinstance(keras_layer, tf.keras.layers.MaxPooling2D)
            is_reshape = op_name == 'RESHAPE' if q else isinstance(keras_layer, tf.keras.layers.Flatten)
            

            if is_conv or is_dense:

                prev_name = layer_name
                conv_i += 1
                layer_name = f'conv2d_{conv_i}'

                if q:
                    input_ti, weights_ti, bias_ti = op_inputs
                    output_ti = op_outputs[0]

                    weights = self.tflite_interpreter.get_tensor(weights_ti)
                    bias = self.tflite_interpreter.get_tensor(bias_ti)
                else:
                    bias = keras_layer.weights[1].numpy()

                if is_conv:
                    weights = weights.transpose([1, 2, 3, 0]) if q else keras_layer.weights[0].numpy()
                elif is_dense:
                    weights = weights.transpose([1,0])[None,None,:,:] if q else keras_layer.weights[0].numpy()[None,None,:,:]

                layer = MyConv(
                    prev_layer=self.model.d[prev_name],
                    weights_biases=[weights, bias],
                    bn_weights=None,
                    name=layer_name,
                    np_dtype=self.np_dtype,
                    np_dtype_sum=self.np_dtype_sum,
                    np_dtype_conv_out=self.np_dtype_conv_out,
                    float_dtype=self.float_dtype,
                    bits_conv_out=self.bits_conv_out,
                    quantize=q,
                    float_ieee=self.float_ieee)
                self.model.d[layer_name] = layer

                if q:
                    layer.scale = self.tensor_details[output_ti]['quantization_parameters']['scales'].astype(np.float64)
                    layer.zero_point = self.tensor_details[output_ti]['quantization_parameters']['zero_points'].astype(np.float64)

                    layer.weights_scales = self.tensor_details[weights_ti]['quantization_parameters']['scales'].astype(np.float64)
                    layer.weights_zero_points = self.tensor_details[weights_ti]['quantization_parameters']['zero_points'].astype(np.float64)

                    layer.biases_scales = self.tensor_details[bias_ti]['quantization_parameters']['scales'].astype(np.float64)
                    layer.biases_zero_points = self.tensor_details[bias_ti]['quantization_parameters']['zero_points'].astype(np.float64)

                '''
                Pass input data
                '''
                if q:
                    in_data = self.tflite_interpreter.get_tensor(input_ti) #(n,h,w,ci)
                
                    if op_name == 'FULLY_CONNECTED':
                        _, _, ci, co = weights.shape
                        layer.weights_scales = np.tile(layer.weights_scales, co)
                        layer.weights_zero_points = np.tile(layer.weights_zero_points, co)
                        layer.biases_scales = np.tile(layer.biases_scales, co)
                        layer.biases_zero_points = np.tile(layer.biases_zero_points, co)

                        n,ci = in_data.shape
                        in_data = in_data.reshape(1,n,1,ci) #(n,ci) -> (1,n,1,ci) = (n,h,w,ci)

                    out_data = layer.np_out(in_data)

                '''
                Relu
                '''
                if conv_i != 16:
                    prev_name = layer_name
                    conv_layer = layer
                    
                    layer_name = f'relu_{conv_i}'
                    layer = MyLeakyRelu(
                        prev_layer=self.model.d[prev_name],
                        name=layer_name,
                        alpha=0,
                        np_dtype=self.np_dtype,
                        float_dtype=self.float_dtype,
                        quantize=q,
                        float_ieee=self.float_ieee)
                    self.model.d[layer_name] = layer

                    if q:
                        layer.scale = self.tensor_details[output_ti]['quantization_parameters']['scales'].astype(np.float64)
                        layer.zero_point = self.tensor_details[output_ti]['quantization_parameters']['zero_points'].astype(np.float64)
                        layer.weights_scales = conv_layer.weights_scales
                        layer.weights_zero_points = conv_layer.weights_zero_points
                        layer.weights = conv_layer.weights
                        layer.prev_scale = conv_layer.prev_layer.scale
                        layer.prev_zero_point = conv_layer.prev_layer.zero_point
                        layer.biases_scales = conv_layer.biases_scales
                        layer.biases_zero_points = conv_layer.biases_zero_points
                        layer.biases = conv_layer.biases

                        out_data = layer.np_out(out_data) 
                
                if q:
                    if op_name == 'FULLY_CONNECTED':
                        _,n,_,ci = out_data.shape
                        out_data = out_data.reshape(n,ci)

                    print_count_diff(self.tflite_interpreter.get_tensor(output_ti), out_data, layer_name)

            elif is_maxpool:
                
                prev_name = layer_name
                maxpool_i += 1
                layer_name = f'maxpool_{maxpool_i}'
                layer = MyMaxPool(
                    prev_layer=self.model.d[prev_name],
                    name=layer_name,
                    pool_size=(2, 2),
                    np_dtype=self.np_dtype)
                self.model.d[layer_name] = layer

                if q:
                    input_ti = op_inputs[0]
                    output_ti = op_outputs[0]
                    layer.scale = self.tensor_details[output_ti]['quantization_parameters']['scales'].astype(np.float64)
                    layer.zero_point = self.tensor_details[output_ti]['quantization_parameters']['zero_points'].astype(np.float64)

                    out_data = layer.np_out(self.tflite_interpreter.get_tensor(input_ti))
                    print_count_diff(self.tflite_interpreter.get_tensor(output_ti), out_data, layer_name)
            elif is_reshape:

                prev_name = layer_name
                reshape_i += 1
                layer_name = f'reshape_{reshape_i}'
                layer = MyFlatten(
                    prev_layer=self.model.d[prev_name],
                    name=layer_name,
                    np_dtype=self.np_dtype)
                self.model.d[layer_name] = layer

                if q:
                    output_ti = op_outputs[0]
                    layer.scale = self.tensor_details[output_ti]['quantization_parameters']['scales'].astype(np.float64)
                    layer.zero_point = self.tensor_details[output_ti]['quantization_parameters']['zero_points'].astype(np.float64)

                    out_data = layer.np_out(self.tflite_interpreter.get_tensor(input_ti))
            else:
                layer = None
            print(f'{layer_name} done')
        '''
        Set output
        '''
        # layer_name = 'relu_15'
        # layer = self.model.d[layer_name]
        self.model.output_name = layer_name
                
    def fwd_pass(self):
        self.np_output_data = self.model.get_np_output_data()
        self.output = self.model.d[self.model.output_name].out_float_data if self.quantize else self.np_output_data

        self.softmax_output = _softmax(self.output)
        if self.quantize:
            scales, zero_points = self.tflite_interpreter.get_output_details()[0]['quantization']
            self.softmax_output_quant = np.rint(self.softmax_output / scales + zero_points).astype(np.int8)
