if True:    # To prevent reordering of imports
    import numpy as np
    import cv2
    import h5py
    import sys
    sys.path.append("../aba_framework")
    import os
    os.environ["HDF5_USE_FILE_LOCKING"] = "FALSE"

    from aba_framework import MyLayer, MyInput, MyConv, MyMaxPool, MyConcat, MySpaceToDepth, MyModel, MyLeakyRelu, e, eval
    from preprocessing import parse_annotation, BatchGenerator
    from utils import decode_netout, draw_boxes

__author__ = "Abarajithan G"
__copyright__ = "Copyright 2020, Conv Engine Paper"
__credits__ = ["Abarajithan G"]
__version__ = "1.0.0"
__maintainer__ = "Abarajthan G"
__email__ = "abarajithan07@gmail.com"
__status__ = "Research"

class VGG16_Numpy():
    def __init__(self,
                 np_dtype=np.float64,
                 input_W=224,
                 input_H=224,
                 image_path='../data/5.png',
                 image=None,
                 weights_path='vgg16-conv.h5'):

        self.model = MyModel()
        self.output = None
        self.weights_path = weights_path
        self.np_dtype = np_dtype

        self.input_W = input_W
        self.input_H = input_H
        self.image_path = image_path
        self.image = image

        self.load_weights()
        self.load_image()
        self.compile()

    def load_weights(self):
        self.model_weights = h5py.File(self.weights_path)
        self.layer_names = list(self.model_weights.keys())
        self.layer_names.remove('input_1')

    def get_weights(self, name):
        '''
        Return weights based on layer name
        '''
        if 'conv' in name:
            w = [self.model_weights[name][name]['kernel:0'][()]]
            if len(list(self.model_weights[name][name])) == 2:
                w += [self.model_weights[name][name]
                      ['bias:0'][()].astype(self.np_dtype)]
            return w

    def compile(self):
        layer_name = 'input'
        np_dtype = self.np_dtype
        self.model.d[layer_name] = MyInput(self.input_image, name=layer_name)
        prev_name  = layer_name
        i = 0

        for layer_name in self.layer_names:
            if 'conv' in layer_name:
                i += 1
                out_name = 'conv_' + str(i)
                self.model.d[out_name] = MyConv(prev_layer=self.model.d[prev_name],
                                                  weights_biases=self.get_weights(
                                                      layer_name),
                                                  name=out_name,
                                                  np_dtype=np_dtype)
                prev_name = out_name
                
                layer_name = 'relu_' + layer_name
                out_name = 'relu_' + str(i)
                self.model.d[out_name] = MyLeakyRelu(prev_layer=self.model.d[prev_name],
                                                       name=out_name,
                                                       alpha=0,
                                                       np_dtype=np_dtype)
                prev_name = out_name

            if 'pool' in layer_name:
                out_name = 'maxpool_' + str(i)
                self.model.d[out_name] = MyMaxPool(prev_layer=self.model.d[prev_name],
                                                     name=out_name,
                                                     pool_size=(2, 2),
                                                     np_dtype=np_dtype)
                prev_name = out_name

        self.model.output_name = 'relu_13'
                  

    def fwd_pass(self):
        self.np_output_data = self.model.get_np_output_data()
        self.output = self.model.get_np_output_data()

    def fwd_pass_quantized(self, quant_vals):
        self.quantized_output_data = self.model.get_quantized_output_data(
            quant_vals)

        A = quant_vals[self.model.output_name]['A']
        B = quant_vals[self.model.output_name]['B']

        self.output = A*self.quantized_output_data + B

    def load_image(self):
        if self.image is None:
            self.raw_image = cv2.imread(self.image_path)
        else:
            self.raw_image = self.image

        self.input_image = cv2.resize(
            self.raw_image, (self.input_W, self.input_H))
        self.input_image = self.input_image / 255.
        self.input_image = self.input_image[:, :, ::-1]
        self.input_image = np.expand_dims(
            self.input_image, 0).astype(self.np_dtype)