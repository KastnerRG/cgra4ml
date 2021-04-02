'''
YOLOv2 modified built using Aba's numpy forward pass framework, to fuse batchnorm
and extract float16 weights.

* Original YOLOv2 - 80 classes
* YOLOv2 - 4 classes
* YOLOv2_modified - 4 classes, linear (no skip), trained for 256x384
* Merged - YOLOv2 trained on 4 images merged into one
'''

if True:    # To prevent reordering of imports
    import numpy as np
    import cv2
    import h5py
    import pickle
    import matplotlib.pyplot as plt
    import sys
    sys.path.append("../aba_framework")
    import os
    os.environ["HDF5_USE_FILE_LOCKING"] = "FALSE"

    from aba_framework import MyLayer, MyInput, MyConv, MyMaxPool, MyConcat, MySpaceToDepth, MyModel, MyLeakyRelu, e, eval
    from preprocessing import parse_annotation, BatchGenerator
    from utils import decode_netout, draw_boxes

__author__ = "Abarajithan G"
__copyright__ = "Copyright 2019, Final Year Project"
__credits__ = ["Abarajithan G"]
__version__ = "1.0.0"
__maintainer__ = "Abarajthan G"
__email__ = "abarajithan07@gmail.com"
__status__ = "Research"


class YOLOv2_Modified_Numpy():
    def __init__(self,
                 quantize=False,
                 float_ieee = True,
                 np_dtype=np.float64,
                 np_dtype_sum=np.float64,
                 np_dtype_conv_out=np.float64,
                 bits_conv_out=32,
                 input_W=384,
                 input_H=256,
                 image_path='../data/5.png',
                 image=None,
                 GAMMA=2.2,
                 weights_path='YOLOv2_modified_trained_merged.h5',
                 quant_weights_path='tflite_mod_weights.pickle'):

        self.model = MyModel()
        self.output = None
        self.weights_path = weights_path
        self.quantize = quantize
        self.float_ieee = float_ieee
        self.quant_weights_path = quant_weights_path
        self.np_dtype = np_dtype
        self.np_dtype_sum = np_dtype_sum
        self.np_dtype_conv_out = np_dtype_conv_out
        self.bits_conv_out = bits_conv_out

        self.input_W = input_W
        self.input_H = input_H
        self.image_path = image_path
        self.image = image
        self.GAMMA = GAMMA

        if self.quantize:
            self.load_quant_weights()
            self.get_weights = self.get_quant_weights
        else:
            self.load_weights()
            self.get_weights = self.get_float_weights

        self.load_image()
        self.compile()

        if self.quantize:
            for layer in self.model.d.values():
                self.set_quant_params(layer)

                if 'input' in layer.name:
                    layer.quantize = True
        self.input_layer.set_input_image()

    def load_quant_weights(self):
        self.quant_weights = pickle.load(open(self.quant_weights_path, 'rb'))

    def get_quant_weights(self, name):
        if 'conv' in name:
            kernel = self.quant_weights[name]['kernel']['tensor']
            kernel = kernel.transpose([1, 2, 3, 0])
            bias = self.quant_weights[name]['bias']['tensor']

            return [kernel, bias]

    def set_quant_params(self, layer):
        if 'conv' in layer.name:
            layer.scale = self.quant_weights[layer.name]['conv']['scales'][0]
            layer.zero_point = self.quant_weights[layer.name]['conv']['zero_points'][0]

            layer.weights_scales = self.quant_weights[layer.name]['kernel']['scales']
            layer.weights_zero_points = self.quant_weights[layer.name]['kernel']['zero_points']

            layer.biases_scales = self.quant_weights[layer.name]['bias']['scales']
            layer.biases_zero_points = self.quant_weights[layer.name]['bias']['zero_points']

            layer.scale = np.float64(layer.scale)
            layer.zero_point = np.float64(layer.zero_point)
            layer.weights_scales = np.float64(layer.weights_scales)
            layer.weights_zero_points = np.float64(layer.weights_zero_points)
            layer.biases_scales = np.float64(layer.biases_scales)
            layer.biases_zero_points = np.float64(layer.biases_zero_points)

            '''
            Set output LUT
            - access values as lut[a_q+128]
            '''
            lut = np.arange(start=-128, stop=128)
            lut = layer.scale * (lut - layer.zero_point)
            lut = np.float32(lut)
            layer.unquantize_lut = lut

        elif 'maxpool' in layer.name:
            layer.scale = self.quant_weights[layer.name]['maxpool']['scales'][0]
            layer.zero_point = self.quant_weights[layer.name]['maxpool']['zero_points'][0]

            layer.scale = np.float64(layer.scale)
            layer.zero_point = np.float64(layer.zero_point)

        elif 'leaky_relu' in layer.name:
            layer.scale = self.quant_weights[layer.name]['leaky_relu']['scales'][0]
            layer.zero_point = self.quant_weights[layer.name]['leaky_relu']['zero_points'][0]

            layer.scale = np.float64(layer.scale)
            layer.zero_point = np.float64(layer.zero_point)

            '''Get previous conv layer'''
            conv_layer = layer.prev_layer
            while (not isinstance(conv_layer, MyConv)):
                conv_layer = conv_layer.prev_layer

            layer.weights_scales = conv_layer.weights_scales
            layer.weights_zero_points = conv_layer.weights_zero_points
            layer.weights = conv_layer.weights

            layer.prev_scale = conv_layer.prev_layer.scale
            layer.prev_zero_point = conv_layer.prev_layer.zero_point

            layer.biases_scales = conv_layer.biases_scales
            layer.biases_zero_points = conv_layer.biases_zero_points
            layer.biases = conv_layer.biases

            layer.scale = np.float64(layer.scale)
            layer.zero_point = np.float64(layer.zero_point)
            layer.weights_scales = np.float64(layer.weights_scales)
            layer.weights_zero_points = np.float64(layer.weights_zero_points)
            layer.weights = np.float64(layer.weights)
            layer.biases_scales = np.float64(layer.biases_scales)
            layer.biases_zero_points = np.float64(layer.biases_zero_points)
            layer.biases = np.float64(layer.biases)
            layer.prev_scale = np.float64(layer.prev_scale)
            layer.prev_zero_point = np.float64(layer.prev_zero_point)

        elif 'input' in layer.name:
            layer.scale = self.quant_weights[layer.name]['input']['scales'][0]
            layer.zero_point = self.quant_weights[layer.name]['input']['zero_points'][0]

            layer.scale = np.float64(layer.scale)
            layer.zero_point = np.float64(layer.zero_point)

            '''
            Set Input LUT
            '''
            lut = np.arange(start=0, stop=256)
            lut = (lut/255.0)**(1/2.2)
            lut = lut/layer.scale + layer.zero_point
            lut = np.round(lut).astype(np.int8)

            layer.quantize_lut = lut

        else:
            print('Error. Unknown layer: ', layer.name)

    def load_weights(self):
        f = h5py.File(self.weights_path)
        self.model_weights = f['model_weights']

    def get_float_weights(self, name):
        '''
        Return weights based on layer name
        '''
        if 'conv' in name:
            w = [self.model_weights[name][name]['kernel:0'][()]]
            if len(list(self.model_weights[name][name])) == 2:
                w += [self.model_weights[name][name]
                      ['bias:0'][()].astype(self.np_dtype)]
            return w

        elif 'norm' in name:
            w = [self.model_weights[name][name]['gamma:0'][()].astype(self.np_dtype),
                 self.model_weights[name][name]['beta:0'][()].astype(
                     self.np_dtype),
                 self.model_weights[name][name]['moving_mean:0'][()].astype(
                     self.np_dtype),
                 self.model_weights[name][name]['moving_variance:0'][()].astype(self.np_dtype)]
            return w

    def compile(self):
        layer_name = 'input_1'
        np_dtype = self.np_dtype

        self.input_layer = MyInput(self.input_image,
                                   name=layer_name,
                                   GAMMA=self.GAMMA,
                                   np_dtype=self.np_dtype,
                                   quantize=False)
        self.model.d[layer_name] = self.input_layer

        maxpool_i = 0
        for i in range(1, 21):
            prev_name = layer_name
            layer_name = 'conv_' + str(i)

            if self.quantize:
                bn_name = ''
            else:
                bn_name = 'norm_' + str(i)

            self.model.d[layer_name] = MyConv(prev_layer=self.model.d[prev_name],
                                              weights_biases=self.get_weights(
                                                  layer_name),
                                              bn_weights=self.get_weights(
                                                  bn_name),
                                              name=layer_name,
                                              np_dtype=np_dtype,
                                              np_dtype_sum=self.np_dtype_sum,
                                              np_dtype_conv_out=self.np_dtype_conv_out,
                                              bits_conv_out=self.bits_conv_out,
                                              quantize=self.quantize,
                                              float_ieee=self.float_ieee)
            prev_name = layer_name
            layer_name = 'leaky_relu_' + str(i)
            self.model.d[layer_name] = MyLeakyRelu(prev_layer=self.model.d[prev_name],
                                                   name=layer_name,
                                                   np_dtype=np_dtype,
                                                   quantize=self.quantize,
                                                   float_ieee=self.float_ieee)

            if i in [1, 2, 5, 8, 13]:
                maxpool_i += 1

                prev_name = layer_name
                layer_name = 'maxpool_' + str(maxpool_i)
                self.model.d[layer_name] = MyMaxPool(prev_layer=self.model.d[prev_name],
                                                     name=layer_name,
                                                     pool_size=(2, 2),
                                                     np_dtype=np_dtype)

        i = 21
        prev_name = layer_name
        layer_name = 'conv_' + str(i)
        if self.quantize:
            layer_name_in_h5 = 'conv_21'
        else:
            layer_name_in_h5 = 'conv_23'

        bn_name = ''
        self.model.d[layer_name] = MyConv(prev_layer=self.model.d[prev_name],
                                          weights_biases=self.get_weights(
            layer_name_in_h5),
            bn_weights=self.get_weights(
            bn_name),
            name=layer_name,
            np_dtype=np_dtype,
            np_dtype_sum=self.np_dtype_sum,
            quantize=self.quantize)
        self.model.output_name = 'conv_21'

    def fwd_pass(self):
        self.np_output_data = self.model.get_np_output_data()
        self.output = self.model.get_np_output_data()

        if self.quantize:
            out_layer = self.model.d[self.model.output_name]

            '''
            Following three MUST be equivalent
            
            1. 
            self.output = out_layer.out_float_data

            2. 
            a_q = out_layer.requantize_params['a_q']
            fa = out_layer.scale
            a_0 = out_layer.zero_point

            self.output = fa*(a_q - a_0)

            3.
            a_q = out_layer.requantize_params['a_q']
            self.output = out_layer.unquantize_lut[a_q+128]

            '''
            a_q = out_layer.requantize_params['a_q']
            self.output = out_layer.unquantize_lut[a_q + 128]

    def fwd_pass_quantized(self, quant_vals):
        self.quantized_output_data = self.model.get_quantized_output_data(
            quant_vals)

        A = quant_vals[self.model.output_name]['A']
        B = quant_vals[self.model.output_name]['B']

        self.output = A*self.quantized_output_data + B

    def load_image(self):
        '''
        Reshaped uint8 image is passed. (image/255)**(1/gamma) is done in input layer
        '''
        if self.image is None:
            self.raw_image = cv2.imread(self.image_path)
        else:
            self.raw_image = self.image

        self.input_image = cv2.resize(
            self.raw_image, (self.input_W, self.input_H))
        self.input_image = self.input_image[:, :, ::-1]
        self.input_image = np.expand_dims(self.input_image, 0)

    def show_on_image(self, OBJ_THRESHOLD=0.3, NMS_THRESHOLD=0.3):
        LABELS = ['motorbikes/bicycles', 'three-wheeler', 'car/van', 'truck']
        CLASS = len(LABELS)
        # 0.5
        # 0.45
        ANCHORS = [0.57273, 0.677385,
                   1.87446, 2.06253,
                   3.33843, 5.47434,
                   7.88282, 3.52778,
                   9.77052, 9.16828]
        dummy_array = np.zeros((1, 1, 1, 1, 50, 4))

        _, grid_h, grid_w, _ = self.output.shape

        m_out_r = np.reshape(
            self.output, (1, grid_h, grid_w, 5, 5+CLASS)).copy()
        self.boxes = None
        self.boxes = decode_netout(m_out_r[0],
                                   obj_threshold=OBJ_THRESHOLD,
                                   nms_threshold=NMS_THRESHOLD,
                                   anchors=ANCHORS,
                                   nb_class=CLASS)
        self.output_image = draw_boxes(
            self.raw_image.copy(), self.boxes, labels=LABELS)
        cv2.imwrite('detected_2.png', self.output_image)
        fig = plt.figure(figsize=(15, 15))
        plt.imshow(self.output_image[:, :, ::-1])
        plt.show()

    def show_hist(self):
        for name in self.model.d.keys():
            print('\n\n\nLAYER: ', name)
            self.model.d[name].show_hist()
