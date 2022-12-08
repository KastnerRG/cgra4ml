from keras.models import Sequential, Model
from keras.layers import Reshape, Activation, Conv2D, Input, MaxPooling2D, BatchNormalization, Flatten, Dense, Lambda
from keras.layers.advanced_activations import LeakyReLU
import matplotlib.pyplot as plt
import keras.backend as K
import tensorflow as tf
import numpy as np
import pickle
import os, cv2
import copy
from preprocessing import parse_annotation, BatchGenerator
from utils import WeightReader, decode_netout, draw_boxes


class YOLOv2_Modified:
    def __init__(
        self,
        weights_path = 'YOLOv2_modified_trained_merged.h5',
        labels = ['motorbikes/bicycles', 'three-wheeler', 'car/van', 'truck'],
        image_size = (256,384),
        grid_size = (8, 12),
        box = 5,
        
        obj_threshold    = 0.5,
        nms_threshold    = 0.3,
        anchors         = [0.57273, 0.677385, 1.87446, 2.06253, 3.33843, 5.47434, 7.88282, 3.52778, 9.77052, 9.16828],

        NO_OBJECT_SCALE  = 1.0,
        OBJECT_SCALE     = 5.0,
        COORD_SCALE      = 1.0,
        CLASS_SCALE      = 1.0,
        
    ):
        self.WEIGHTS_PATH = weights_path
        self.IMAGE_H      = image_size[0]
        self.IMAGE_W      = image_size[1]
        self.GRID_H       = grid_size[0]
        self.GRID_W       = grid_size[1]
        self.BOX          = box
        self.LABELS       = labels
        self.CLASS        = len(labels)

        self.CLASS_WEIGHTS    = np.ones(self.CLASS, dtype='float32')
        self.OBJ_THRESHOLD    = obj_threshold#0.5
        self.NMS_THRESHOLD    = nms_threshold#0.45
        self.ANCHORS          = [0.57273, 0.677385, 1.87446, 2.06253, 3.33843, 5.47434, 7.88282, 3.52778, 9.77052, 9.16828]
        self.TRUE_BOX_BUFFER  = 50

        self.Yolo_modified_model  = None
        
        self.build()
        
        
    def space_to_depth_x2(self, x):
        return tf.space_to_depth(x, block_size=2)
    
    
    def build(self):
        input_image = Input(shape=(self.IMAGE_H, self.IMAGE_W, 3))
        true_boxes  = Input(shape=(1, 1, 1, self.TRUE_BOX_BUFFER , 4))

        # Layer 1
        x = Conv2D(32, (3,3), strides=(1,1), padding='same', name='conv_1', use_bias=False)(input_image)
        x = BatchNormalization(name='norm_1')(x)
        x = LeakyReLU(alpha=0.1)(x)
        x = MaxPooling2D(pool_size=(2, 2))(x)

        # Layer 2
        x = Conv2D(64, (3,3), strides=(1,1), padding='same', name='conv_2', use_bias=False)(x)
        x = BatchNormalization(name='norm_2')(x)
        x = LeakyReLU(alpha=0.1)(x)
        x = MaxPooling2D(pool_size=(2, 2))(x)

        # Layer 3
        x = Conv2D(128, (3,3), strides=(1,1), padding='same', name='conv_3', use_bias=False)(x)
        x = BatchNormalization(name='norm_3')(x)
        x = LeakyReLU(alpha=0.1)(x)

        # Layer 4
        x = Conv2D(64, (1,1), strides=(1,1), padding='same', name='conv_4', use_bias=False)(x)
        x = BatchNormalization(name='norm_4')(x)
        x = LeakyReLU(alpha=0.1)(x)

        # Layer 5
        x = Conv2D(128, (3,3), strides=(1,1), padding='same', name='conv_5', use_bias=False)(x)
        x = BatchNormalization(name='norm_5')(x)
        x = LeakyReLU(alpha=0.1)(x)
        x = MaxPooling2D(pool_size=(2, 2))(x)

        # Layer 6
        x = Conv2D(256, (3,3), strides=(1,1), padding='same', name='conv_6', use_bias=False)(x)
        x = BatchNormalization(name='norm_6')(x)
        x = LeakyReLU(alpha=0.1)(x)

        # Layer 7
        x = Conv2D(128, (1,1), strides=(1,1), padding='same', name='conv_7', use_bias=False)(x)
        x = BatchNormalization(name='norm_7')(x)
        x = LeakyReLU(alpha=0.1)(x)

        # Layer 8
        x = Conv2D(256, (3,3), strides=(1,1), padding='same', name='conv_8', use_bias=False)(x)
        x = BatchNormalization(name='norm_8')(x)
        x = LeakyReLU(alpha=0.1)(x)
        x = MaxPooling2D(pool_size=(2, 2))(x)

        # Layer 9
        x = Conv2D(512, (3,3), strides=(1,1), padding='same', name='conv_9', use_bias=False)(x)
        x = BatchNormalization(name='norm_9')(x)
        x = LeakyReLU(alpha=0.1)(x)

        # Layer 10
        x = Conv2D(256, (1,1), strides=(1,1), padding='same', name='conv_10', use_bias=False)(x)
        x = BatchNormalization(name='norm_10')(x)
        x = LeakyReLU(alpha=0.1)(x)

        # Layer 11
        x = Conv2D(512, (3,3), strides=(1,1), padding='same', name='conv_11', use_bias=False)(x)
        x = BatchNormalization(name='norm_11')(x)
        x = LeakyReLU(alpha=0.1)(x)

        # Layer 12
        x = Conv2D(256, (1,1), strides=(1,1), padding='same', name='conv_12', use_bias=False)(x)
        x = BatchNormalization(name='norm_12')(x)
        x = LeakyReLU(alpha=0.1)(x)

        # Layer 13
        x = Conv2D(512, (3,3), strides=(1,1), padding='same', name='conv_13', use_bias=False)(x)
        x = BatchNormalization(name='norm_13')(x)
        x = LeakyReLU(alpha=0.1)(x)
        x = MaxPooling2D(pool_size=(2, 2))(x)

        # Layer 14
        x = Conv2D(1024, (3,3), strides=(1,1), padding='same', name='conv_14', use_bias=False)(x)
        x = BatchNormalization(name='norm_14')(x)
        x = LeakyReLU(alpha=0.1)(x)

        # Layer 15
        x = Conv2D(512, (1,1), strides=(1,1), padding='same', name='conv_15', use_bias=False)(x)
        x = BatchNormalization(name='norm_15')(x)
        x = LeakyReLU(alpha=0.1)(x)

        # Layer 16
        x = Conv2D(1024, (3,3), strides=(1,1), padding='same', name='conv_16', use_bias=False)(x)
        x = BatchNormalization(name='norm_16')(x)
        x = LeakyReLU(alpha=0.1)(x)

        # Layer 17
        x = Conv2D(512, (1,1), strides=(1,1), padding='same', name='conv_17', use_bias=False)(x)
        x = BatchNormalization(name='norm_17')(x)
        x = LeakyReLU(alpha=0.1)(x)

        # Layer 18
        x = Conv2D(1024, (3,3), strides=(1,1), padding='same', name='conv_18', use_bias=False)(x)
        x = BatchNormalization(name='norm_18')(x)
        x = LeakyReLU(alpha=0.1)(x)

        # Layer 19
        x = Conv2D(1024, (3,3), strides=(1,1), padding='same', name='conv_19', use_bias=False)(x)
        x = BatchNormalization(name='norm_19')(x)
        x = LeakyReLU(alpha=0.1)(x)

        # Layer 20
        x = Conv2D(1024, (3,3), strides=(1,1), padding='same', name='conv_20', use_bias=False)(x)
        x = BatchNormalization(name='norm_20')(x)
        x = LeakyReLU(alpha=0.1)(x)

        # # Layer 21
        # skip_connection = Conv2D(64, (1,1), strides=(1,1), padding='same', name='conv_21', use_bias=False)(skip_connection)
        # skip_connection = BatchNormalization(name='norm_21')(skip_connection)
        # skip_connection = LeakyReLU(alpha=0.1)(skip_connection)
        # skip_connection = Lambda(self.space_to_depth_x2)(skip_connection)

        # x = concatenate([skip_connection, x])

        # # Layer 22
        # x = Conv2D(1024, (3,3), strides=(1,1), padding='same', name='conv_22', use_bias=False)(x)
        # x = BatchNormalization(name='norm_22')(x)
        # x = LeakyReLU(alpha=0.1)(x)

        # Layer 23
        x = Conv2D(self.BOX * (4 + 1 + self.CLASS), (1,1), strides=(1,1), padding='same', name='conv_23')(x)
        output = Reshape((self.GRID_H, self.GRID_W, self.BOX, 4 + 1 + self.CLASS))(x)

        # small hack to allow true_boxes to be registered when Keras build the model 
        # for more information: https://github.com/fchollet/keras/issues/2790
        output = Lambda(lambda args: args[0])([output, true_boxes])

        self.Yolo_modified_model = Model([input_image, true_boxes], output)
        
        # self.Yolo_modified_model.summary()
        
        
    def predict(self, image, show=True, crop=True): #image is a numpy array of shape HWC
        self.Yolo_modified_model.load_weights(self.WEIGHTS_PATH)
        
        H, W, C = image.shape
        
        input_image = copy.deepcopy(image)
        if crop:
            input_image = input_image[H//3:,:,:]
        input_image = cv2.resize(image, (self.IMAGE_W, self.IMAGE_H))
        input_image = input_image / 255.
        input_image = input_image[:,:,::-1]
        input_image = np.expand_dims(input_image, 0)
        
        dummy_array = np.zeros((1,1,1,1,self.TRUE_BOX_BUFFER,4))

        netout = self.Yolo_modified_model.predict([input_image, dummy_array])

        boxes = decode_netout(netout[0], 
                              obj_threshold=self.OBJ_THRESHOLD,
                              nms_threshold=self.NMS_THRESHOLD,
                              anchors=self.ANCHORS, 
                              nb_class=self.CLASS)

        image = draw_boxes(input_image[0], boxes, labels=self.LABELS)
        cv2.imwrite('detected.png',image)
        
        if show:
            plt.figure(figsize=(12,7))
            # image = image[:,:,::-1]
            # image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
            plt.imshow(image); 
            plt.axis('off')
            plt.axis("tight")
            plt.axis("image")
            plt.show()
        
        return boxes

if __name__ == '__main__':
    yolo = YOLOv2_Modified()

    image_path = '9_in.png'
    np_image = cv2.imread(image_path)
    np_image.shape, type(np_image)

    bboxes = yolo.predict(np_image)

    bboxes