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
                 np_dtype=np.float64,
                 input_W=384,
                 input_H=256,
                 image_path='../data/5.png',
                 image=None,
                 weights_path='YOLOv2_modified_trained_merged.h5'):

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
        f = h5py.File(self.weights_path)
        self.model_weights = f['model_weights']

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

        elif 'norm' in name:
            w = [self.model_weights[name][name]['gamma:0'][()].astype(self.np_dtype),
                 self.model_weights[name][name]['beta:0'][()].astype(
                     self.np_dtype),
                 self.model_weights[name][name]['moving_mean:0'][()].astype(
                     self.np_dtype),
                 self.model_weights[name][name]['moving_variance:0'][()].astype(self.np_dtype)]
            return w

    def compile(self):
        layer_name = 'input'
        np_dtype = self.np_dtype
        self.model.d[layer_name] = MyInput(self.input_image, name=layer_name)

        for i in range(1, 21):
            prev_name = layer_name
            layer_name = 'conv_' + str(i)
            bn_name = 'norm_' + str(i)
            self.model.d[layer_name] = MyConv(prev_layer=self.model.d[prev_name],
                                              weights_biases=self.get_weights(
                                                  layer_name),
                                              bn_weights=self.get_weights(
                                                  bn_name),
                                              name=layer_name,
                                              np_dtype=np_dtype)

            prev_name = layer_name
            layer_name = 'lrelu_' + str(i)
            self.model.d[layer_name] = MyLeakyRelu(prev_layer=self.model.d[prev_name],
                                                   name=layer_name,
                                                   np_dtype=np_dtype)

            if i in [1, 2, 5, 8, 13]:
                prev_name = layer_name
                layer_name = 'maxpool_' + str(i)
                self.model.d[layer_name] = MyMaxPool(prev_layer=self.model.d[prev_name],
                                                     name=layer_name,
                                                     pool_size=(2, 2),
                                                     np_dtype=np_dtype)
        i = 21
        prev_name = layer_name
        layer_name = 'conv_' + str(i)
        layer_name_in_h5 = 'conv_23'
        bn_name = ''
        self.model.d[layer_name] = MyConv(prev_layer=self.model.d[prev_name],
                                              weights_biases=self.get_weights(
                                                  layer_name_in_h5),
                                              bn_weights=self.get_weights(
                                                  bn_name),
                                              name=layer_name,
                                              np_dtype=np_dtype)
        self.model.output_name = 'conv_21'
                  

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

        m_out_r = np.reshape(self.output, (1, grid_h, grid_w, 5, 5+CLASS)).copy()
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

