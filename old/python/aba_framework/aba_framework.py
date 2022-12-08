'''
Aba's custom numpy-based forward-pass framework for any CNN.

* Given trained weights (.h5) file, build a CNN
* Fuse BatchNorm parameters with weights
* Convert weights to float16
* Verify by processing an image in float16
* Use this object in fpga_support functions to extract weights
'''

from scipy.signal import convolve2d
import numpy as np
import tensorflow as tf
from utils import float_convert

__author__ = "Abarajithan G"
__copyright__ = "Copyright 2019, Final Year Project"
__credits__ = ["Abarajithan G"]
__version__ = "1.0.0"
__maintainer__ = "Abarajthan G"
__email__ = "abarajithan07@gmail.com"
__status__ = "Research"

# --------------------------- MODEL --------------------------------


class MyModel:
    '''
    Attributes:
        d : dict
            - Dictionary of {'layer_name': MyLayerObject} pairs

        output_name : str
            - Name of the output layer. Used to start the recursive call

    Methods:
        get_np_output_data()
        np_reset()
            - The output_lock of each layer is changed to True when the
                layer computes an output. This is to prevent wasting time
                in recomputing if we want the values again.
            - If we want to recompute the results (say for a different image),
                this function will turn off (False) output_lock of all layers
            - So when we call output again, the output will be freshly calculated
        change_apply(func: function)
            - Changes the apply layer.apply function, thereby applying the
                given function for all data before and after each math operation
                see apply method of layer class
            - You can do:
                def my_custom_func(in_data)
                    # DO SOMETHING
                        return out_data
                    model_1.change_apply(my_custom_func)

    '''

    def __init__(self):
        self.d = {}
        self.input_name = None
        self.output_name = None

    def get_np_output_data(self):
        return self.d[self.output_name].get_np_output_recursively()

    def get_quantized_output_data(self, quant_vals):
        return self.d[self.output_name].get_quantized_output_recursively(quant_vals)

    def np_reset(self):
        for name in self.d.keys():
            self.d[name].np_output_lock = False

    def set_encode_decode(self, encode, decode):

        for name in self.d.keys():
            self.d[name].encode = encode
            self.d[name].decode = decode

        print('Applied to all layers')


class MyLayer:
    '''
    * Base class for all Layers: Conv, BatchNorm
    * Can show histogram of outputs & weights
    * Can compare different implementations

    Args:
        name (str)
        np_dtype (str)

    Attributes:
        name (str)
        np_dtype

        prev_layer : MyLayer
            - Helps to chain the layers and get
                results from previous layers

        np_output: ndarray
            -initally None, stores the value of
                calculation result from np_out()

        np_output_lock: bool
            - False by default
            - When output is calculated, set to True
            - When true, get_output_recursively()
                doesnt recalculate results. it returns
                previously calculated value from
                np_output

        apply : function
            - Default is self.no_change
            - This function is applied to the data before
                and after each math operation
            - An external function can be defined and set here as
                    def my_custom_func(in_data)
                        return out_data
                    layer_1.apply = my_custom_func
            - Then my_custom_func will be applied for all data

    Methods:
        set_dtype():
            - Sets the default types for np

        compare (in_data: ndarray 4 dims):
            - compares implementations in
                numpy

        show_hist(in_data: ndarray 4 dims):
            - shows histograms of layer
                weights
                biases (if not zero)
                outputs (if in_data is not None or if np_out is available)

        get_np_output_recursively()
        get_np_output_recursively()
            - Recursively call the get_np
                method(s) of the prev_layer(s),
            - Feed the output(s) to np of current layer
            - Return the output
            - If output_lock is placed (True),
                return np without
                calculation or recursive call
            - Overriden under MyConcat child class to allow multiple inputs

        np_out(in_data: nd_array) : ndarray
            - 3 methods defined inside each child class
            - Apply the current layer to input array and
                return the result

        def no_change(in_data: ndarray): ndarray
            - default apply function
            - simply applies the current datatype


    '''

    def __init__(self, prev_layer, name, np_dtype, quantize=False, float_ieee=True):
        # self.set_dtype(np_dtype)
        self.name = name
        self.prev_layer = prev_layer

        self.np_output_lock = False
        self.quantized_output_lock = False
        self.decode = self.no_change
        self.encode = self.no_change
        self.np_dtype = np_dtype

        self.scale = None
        self.zero_point = None
        self.quantize = quantize
        self.float_ieee = float_ieee

    def show_hist(self, show_encoded=False):
        if isinstance(self, MyConv):
            print('\n Decoded Weights')
            show_hist(self.decode(self.weights), color='blue')

            if show_encoded:
                print('\n Encoded Weights')
                show_hist(self.weights, color='blue')

            if not np.array_equal(self.biases, np.zeros(self.biases.shape)):
                print('\nDecoded Biases')
                show_hist(self.decode(self.biases), color='green')

                if show_encoded:
                    print('\n Encoded Biases')
                    show_hist(self.biases, color='green')

        print('\nDecoded Outputs')
        show_hist(self.decode(self.np_out_data), color='red')

        if show_encoded:
            print('\n Encoded Outputs')
            show_hist(self.np_out_data, color='red')

    def get_np_output_recursively(self):
        if self.np_output_lock:
            return self.np_out_data
        else:
            self.np_output_lock = True

            out = self.np_out(self.prev_layer.get_np_output_recursively())
            print('Numpy Evaluated Layer: ' + self.name)
            return out

    def get_quantized_output_recursively(self, quant_vals):
        if self.quantized_output_lock:
            return self.quantized_out_data
        else:
            self.quantized_output_lock = True
            out = self.quantized_out(
                self.prev_layer.get_quantized_output_recursively(quant_vals), quant_vals)
            print('Quantized Evaluated Layer: ' + self.name)
            return out

    def no_change(self, in_data):
        return in_data
        # return in_data.astype(self.np_dtype)

# ---------------------- CONVOLUTION ---------------------------------------


class MyConv(MyLayer):
    '''
    * Numpy Based Implementations of Convolution Layer
    * Support Multiple dtypes (Defined in Class:Layer)
    * Optionally allows fused Batch Normalization

    Fused Batch Norm:
        Batch norm is: output = beta + gamma(input - mean)/sqrt(var + epsilon)
            beta, gamma - learnt paramters
            mean, var   - of all batches from training data
            epsilon     - small constant to prevent division by zero

            During inference time, all 5 parameters are known

        Fusing Batch Norm:
            since input  = weights * x + bias,
                  output = beta + gamma(weights * x + bias - mean)/sqrt(var + epsilon)
            Let sigma = sqrt(var + epsilon), then:
                  output = [gamma*weights/sigma]*x + [beta+(bias-mean)*gamma/sigma]
            Therefore, by setting:
                  weights <- [gamma*weights/sigma]
                  bias    <- [beta+(bias-mean)*gamma/sigma]
            Convolution + BatchNorm layers can be fused
                into (are equivalent to) a single convoluion
                layer with above modified weights and biases

            Only possible during inference (when all 5 are fixed constants)
            Tremendously reduces number of calculations

    Args:
        weights_biases : list [weights: ndarray, biases: ndarray]
            - weights, biases are numpy arrays of 4 dims
            - unflipped (tf format)

        bn_weights :list [gamma, beta, mean, variance]):
            - each 1 dim, shape = (out_ch_n,)
            - if None, batch_norm not applied (not fused)

    Attributes:
        is_fused_bn : bool
        weights, biases : ndarray
        weights_fipped, biases_flipped : ndarray
            - Scipy's convolve2d flips weights before convolving
                (mathematical definition for convolution)
            - Tensorflow / Keras doesnt flip the weights
                (Machine learning convention of convolving)
            - To create similar results, we pre-flip the kernel and store here

        pure_weights, pure_biases : ndarray 
            if is_fused_bn, true_weights are stored here
            and fused weights are stored in weights, biases

        gamma, beta, mean, variance : ndarray
        epsilon : float

        kernel : tuple , eg (3,3)
        in_ch_n : int
        out_ch_n : int
            Number of input and output channels (filters)

        np_out_data : ndarray

    Methods:
        np_out(in_data : ndarray 4 dims): ndarray

        fuse_bn(bn_weights: list, epsilon: int)
            Performs the BN fusions

    NOTE:
        - Have not generalized for multiple images yet
    '''

    def __init__(self,
                 weights_biases,
                 prev_layer=None,
                 bn_weights=None,
                 name='',
                 np_dtype=np.float64,
                 np_dtype_sum=np.float64,
                 np_dtype_conv_out=np.float64,
                 float_dtype=np.float64,
                 bits_conv_out=32,
                 quantize=False,
                 float_ieee=True):

        MyLayer.__init__(self,
                         name=name,
                         prev_layer=prev_layer,
                         np_dtype=np_dtype,
                         quantize=quantize,
                         float_ieee=float_ieee)
        self.np_dtype_sum = np_dtype_sum
        self.np_dtype_conv_out = np_dtype_conv_out
        self.float_dtype = float_dtype

        assert len(weights_biases[0].shape) == 4
        # Set Weights and Biases

        self.weights = weights_biases[0].astype(self.np_dtype)
        self.weights_flipped = np.flip(
            self.weights, [0, 1]).astype(self.np_dtype)

        self.kernel = self.weights.shape[0:2]
        self.in_ch_n = self.weights.shape[2]
        self.out_ch_n = self.weights.shape[3]

        if len(weights_biases) > 1:
            if self.quantize:
                self.biases = weights_biases[1]
            else:
                self.biases = weights_biases[1].astype(self.np_dtype)
        else:
            self.biases = np.zeros((self.out_ch_n), dtype=self.np_dtype)

        # Fusing Batch Normalization
        if bn_weights is None:
            self.is_fused_bn = False
        else:
            self.fuse_bn(bn_weights)

        self.weights_scales = None
        self.biases_scales = None
        self.weights_zero_points = None
        self.biases_zero_points = None
        self.unquantize_lut = None

        if self.quantize:
            self.clip_max = 2**(bits_conv_out-1)-1
            self.clip_min = -2**(bits_conv_out-1)

    def np_out(self, in_data):

        assert len(in_data.shape) == 4
        n_samples, in_h, in_w, in_data_ch_n = in_data.shape
        assert in_data_ch_n == self.in_ch_n

        # Encode and decode
        # self.in_data_dec = in_data
        # self.biases_enc = self.encode(self.biases)
        # self.biases_dec = self.decode(self.biases_enc)
        # self.weights_enc = self.encode(self.weights)
        # self.weights_dec = self.decode(self.weights_enc)

        self.in_data = in_data.astype(self.np_dtype)

        if self.quantize:
            in_data = self.in_data.copy().astype(self.np_dtype_sum)
            weights = self.weights.copy().astype(self.np_dtype_sum)
            self.np_out_data = self.conv2d_einsum(in_data, weights)
            self.np_out_data = np.clip(self.np_out_data,
                                       self.clip_min,
                                       self.clip_max)
            self.np_out_data = self.np_out_data.astype(self.np_dtype_conv_out)
            # No bias

            '''
            Calculate quantized and float outputs of convolution
            '''
            self.requantize_params = MyLeakyRelu.requantize(
                in_data=self.np_out_data,
                fx=self.prev_layer.scale,
                fk=self.weights_scales,
                x_0=self.prev_layer.zero_point,
                k_q=self.weights,
                fb=self.biases_scales,
                b_q=self.biases,
                fa=self.scale,
                a_0=self.zero_point,
                alpha=1,
                float_dtype=self.float_dtype,
                np_dtype=self.np_dtype)

            self.out_float_data = self.requantize_params['y'] * self.scale

            if self.float_ieee:
                self.quant_out_data = self.requantize_params['a_q']
            else:
                self.quant_out_data = self.requantize_params['a_q_custom']

        else:
            out = self.conv2d_einsum(self.in_data, self.weights)
            out += self.biases
            self.np_out_data = self.decode(self.encode(out))

        return self.np_out_data
        # return out

    def quantized_out(self, in_data, quant_vals):
        self.in_data_quantized = in_data
        # in_data = xq is already quantized
        full_name = None
        for key in quant_vals.keys():
            if self.name in key:
                full_name = key
                break
        A = quant_vals[full_name]['A']
        B = quant_vals[full_name]['B']
        g_w0 = quant_vals[full_name]['g_w0']

        self.weights = self.weights.astype(self.np_dtype)
        self.wq = self.weights.astype(self.np_dtype) * g_w0
        self.xq = in_data

        self.wq = np.rint(self.wq)
        self.xq = np.rint(self.xq)

        self.sq = self.conv2d_einsum(self.xq, self.wq)

        # self.quantized_out_data = A * self.sq + self.bq/g_b0 + B
        self.quantized_out_data = self.sq
        self.de_quantized_out_data = A * self.sq + B
        self.quantized_out_data = np.rint(self.quantized_out_data)
        return self.quantized_out_data

    def fuse_bn(self, bn_weights, epsilon=0.001):
        gamma, beta, mean, variance = bn_weights
        assert gamma.shape == beta.shape == mean.shape == variance.shape == (
            self.out_ch_n,)

        self.gamma = gamma.astype(self.np_dtype)
        self.beta = beta.astype(self.np_dtype)
        self.mean = mean.astype(self.np_dtype)
        self.variance = variance.astype(self.np_dtype)
        self.epsilon = epsilon

        scale = self.gamma / np.sqrt(self.variance + self.epsilon)

        self.pure_weights = self.weights.copy()
        self.pure_biases = self.biases.copy()

        self.weights = self.weights * scale
        self.weights_flipped = np.flip(self.weights, [0, 1])
        self.biases = beta + scale * (self.biases - self.mean)
        self.is_fused_bn = True

    @staticmethod
    def conv2d_einsum(img, kernel):
        pad_h = kernel.shape[0]//2
        pad_w = kernel.shape[1]//2

        out_batch = []
        for n in range(img.shape[0]):
            img_pad = np.pad(
                img[n], ((pad_h, pad_h), (pad_w, pad_w), (0, 0)), 'constant')

            sub_shape = tuple(np.subtract(img_pad.shape, kernel.shape[0:-1]) + 1)
            strd = np.lib.stride_tricks.as_strided
            submatrices = strd(
                img_pad, kernel.shape[0:-1] + sub_shape, img_pad.strides * 2, writeable=False)

            out_batch += [np.einsum('ijkl,ijkmno->mnl', kernel, submatrices,
                            optimize='greedy')]

        return np.array(out_batch)

    @staticmethod
    def conv2d_as_12_blocks(img, kernel):
        N, H, W, C_in = img.shape
        img_list = np.split(img, int(H/12), axis=1)

        out_list = []

        for img_block in img_list:
            out_list += [MyConv.conv2d_einsum(img_block, kernel)]

        out = np.concatenate(out_list, axis=1)

        return out

    @staticmethod
    def conv2d_tf(img, kernel, q=None):
        img_t = tf.convert_to_tensor(img)
        kernel_t = tf.convert_to_tensor(kernel)
        out_t = tf.nn.conv2d(img_t, kernel_t, strides=(
            1, 1, 1, 1), padding="SAME")

        sess = tf.get_default_session()
        if sess == None:
            sess = tf.Session()

        out = sess.run(out_t)

        if q == None:
            return out
        else:
            q.put(out)

    @staticmethod
    def conv2d_scipy(img, kernel):
        kernel_flipped = np.flip(kernel, (0, 1))
        n, img_h, img_w, ch_in = img.shape
        k_h, k_w, k_ch_in, ch_out = kernel_flipped.shape

        assert ch_in == k_ch_in

        output = np.empty((1, img_h, img_w, ch_out))
        for i in range(ch_out):
            out = np.zeros((img_h, img_w))
            for j in range(ch_in):
                out += convolve2d(img[0, :, :, j],
                                  kernel_flipped[:, :, j, i], 'same')
            output[0, :, :, i] = out

        return output


# ----------------------- OTHER LAYERS ---------------------------------------

class MyInput(MyLayer):
    '''
    The first layer for any custom Model.
    prev_layer is always None

    get_np
        - Overidden (from parent class) here
        - Simply returns the BATCH OF IMAGES, ending the recursive call
    '''

    def __init__(self, input_batch, name='input', GAMMA=1, np_dtype=np.float64, quantize=False):
        MyLayer.__init__(self, prev_layer=None,
                         name=name, np_dtype=np_dtype,
                         quantize=quantize)
        self.input_batch = input_batch
        self.quantize_lut = None
        self.GAMMA = GAMMA

    def set_input_batch(self):
        input_batch = self.input_batch.copy()

        if self.quantize:
            self.input_batch = np.rint(self.input_batch/self.scale + self.zero_point).astype(self.np_dtype)
        else:
            self.input_batch = (input_batch/255.0)**(1/self.GAMMA)
            self.input_batch = self.input_batch.astype(self.np_dtype)

    def get_np_output_recursively(self):
        self.np_out_data = self.decode(self.encode(self.input_batch))
        return self.np_out_data

    def get_quantized_output_recursively(self, quant_vals):
        g_x0 = quant_vals['conv2d_1 lrelu_1']['g_x0']
        h_x0 = quant_vals['conv2d_1 lrelu_1']['h_x0']

        self.quantized_out_data = (self.input_batch-h_x0)*g_x0

        self.quantized_out_data = np.print(self.quantized_out_data)
        return self.quantized_out_data


class MyLeakyRelu(MyLayer):
    def __init__(self,
                 prev_layer=None,
                 alpha=0.1, name='',
                 np_dtype=np.float64,
                 float_dtype=np.float64,
                 quantize=False,
                 float_ieee=True):

        MyLayer.__init__(self, prev_layer=prev_layer,
                         name=name, np_dtype=np_dtype,
                         quantize=quantize,
                         float_ieee=float_ieee)
        self.alpha = alpha

        self.weights_scales = None
        self.biases_scales = None
        self.weights_zero_points = None
        self.biases_zero_points = None
        self.biases = None
        self.weights = None
        self.float_dtype = float_dtype

        self.prev_scale = None
        self.prev_zero_point = None

    @staticmethod
    def requantize(in_data,
                   fx,
                   fk,
                   x_0,
                   k_q,
                   fb,
                   b_q,
                   fa,
                   a_0,
                   alpha=0.1,
                   float_dtype=np.float64,
                   np_dtype=np.int8):
        '''
        Build  max(conv(K_q, x_0))
        '''
        _, _, cin, cout = k_q.shape
        _, h, w, cout = in_data.shape
        x_in_shape = (1, h, w, cin)

        k_sum = MyConv.conv2d_einsum(x_0*np.ones(x_in_shape), k_q)

        def maxpool(in_data, n_h, n_w):
            _, h, w, c = in_data.shape
            h_out = h//n_h
            w_out = w//n_w

            temp = in_data.reshape(1, h_out, n_h, w_out, n_h, c)
            return temp.max(axis=2).max(axis=3)

        '''
        Requantize with relu
        '''
        fk = fk.copy().reshape(1, 1, 1, cout)
        b = b_q*fb
        b = b.copy().reshape(1, 1, 1, cout)

        A = fx*fk/fa
        B = (-fx*fk*k_sum + b)/fa

        A = float_dtype(A)
        B = float_dtype(B)
        in_data = float_dtype(in_data)

        is_convert = float_dtype == np.float16

        y = (A.astype(float_dtype) * in_data) + B.astype(float_dtype)
        y_custom = (float_convert(A,16,32,is_convert) * in_data) + float_convert(B,16,32,is_convert)

        D = a_0
        D = float_dtype(D)

        y_f16 = y.astype(float_dtype)
        alpha_arr = (y_f16 > 0) + (y_f16 < 0) * np.array(alpha, float_dtype)

        a_q_f16 = (alpha_arr.astype(float_dtype) * y_f16) + D
        a_q_f16_custom = (alpha_arr.astype(float_dtype) * float_convert(y_custom,32,16,is_convert)) + D

        if np_dtype == np.int8:
            a_min, a_max = -128,127

        a_q = a_q_f16.clip(a_min,a_max).round().astype(np_dtype)
        a_q_custom = a_q_f16_custom.clip(a_min,a_max).round().astype(np_dtype)

        return {'A': A,
                'B': B,
                'y': y,
                'y_f16': y_f16,
                'y_custom': y_custom,
                'D': D,
                'a_q_f16': a_q_f16,
                'a_q_f16_custom': a_q_f16_custom,
                'a_q': a_q,
                'a_q_custom': a_q_custom
                }

    def np_out(self, in_data):
        x = in_data
        self.in_data = x

        if self.quantize:
            self.requantize_params = self.requantize(
                in_data=in_data,
                fx=self.prev_scale,
                fk=self.weights_scales,
                x_0=self.prev_zero_point,
                k_q=self.weights,
                fb=self.biases_scales,
                b_q=self.biases,
                fa=self.scale,
                a_0=self.zero_point,
                alpha=0.1,
                np_dtype=self.np_dtype)

            if self.float_ieee:
                self.np_out_data = self.requantize_params['a_q']
            else:
                self.np_out_data = self.requantize_params['a_q_custom']

            self.out_float_data = self.scale * (self.requantize_params['a_q'] - self.zero_point)

        else:
            self.np_out_data = x * ((x > 0) + (x < 0) * self.alpha)
            self.np_out_data = self.decode(self.encode(self.np_out_data))

        return self.np_out_data

    def quantized_out(self, sq, quant_vals):
        full_name = None
        for key in quant_vals.keys():
            if self.name in key:
                full_name = key
                break

        A = quant_vals[full_name]['A']
        B = quant_vals[full_name]['B']
        g_x1 = quant_vals[full_name]['g_x1']
        h_x1 = quant_vals[full_name]['h_x1']
        alpha = self.alpha

        k1 = alpha*g_x1*A
        k2 = g_x1*(alpha*B-h_x1)
        k3 = g_x1*A
        k4 = g_x1*(B-h_x1)
        k5 = -B/A

        self.quantized_out_data = (sq < k5)*(k1*sq+k2) + (sq > k5)*(k3*sq+k4)
        self.quantized_out_data = np.rint(self.quantized_out_data)

        self.de_quantized_out_data = g_x1 * (self.quantized_out_data - h_x1)

        return self.quantized_out_data


class MySpaceToDepth(MyLayer):
    '''
    Tensorflow's tf.space_to_depth behavior
    Reduces the size of spacial dimensions and puts elements in the channel dimension
    Don't worry about it
    '''

    def __init__(self, prev_layer=None, block_size=2, name='', np_dtype='float64'):
        MyLayer.__init__(self, prev_layer=prev_layer,
                         name=name, np_dtype=np_dtype)

        self.block_size = block_size

    def np_out(self, in_data):

        batch, height, width, depth = in_data.shape
        reduced_height = height // self.block_size
        reduced_width = width // self.block_size

        y = in_data.reshape(batch, reduced_height, self.block_size,
                            reduced_width, self.block_size, depth)
        self.np_out_data = np.swapaxes(y, 2, 3).reshape(
            batch, reduced_height, reduced_width, -1)
        return self.np_out_data

    def quantized_out(self, in_data, quant_vals):
        return self.np_out(in_data)

class MyFlatten(MyLayer):
    def __init__(self, prev_layer=None, name='', np_dtype='float64'):
        MyLayer.__init__(self, prev_layer=prev_layer,
                         name=name, np_dtype=np_dtype)

    def np_out(self, in_data):
        #(n,ci) -> (1,n,1,ci) = (n,h,w,ci)
        n, h, w, ci = in_data.shape
        y = in_data.reshape(1, n, 1, h*w*ci)
        self.np_out_data = y
        return self.np_out_data

    def quantized_out(self, in_data, quant_vals):
        return self.np_out(in_data)

class MyConcat(MyLayer):
    '''
    Concats a list of input layers (their outputs) along the channel dimension
    get_np_output_recursively() are overidden to work with a list of prev_layers
    '''

    def __init__(self, prev_layers=None,
                 name='', np_dtype='float64'):

        MyLayer.__init__(self, prev_layer=None,
                         name=name, np_dtype=np_dtype)

        self.prev_layers = prev_layers

    def np_out(self, in_data_list):
        self.np_out_data = np.concatenate(in_data_list, axis=-1)
        return self.np_out_data

    def quantized_out(self, in_data, quant_vals):
        return self.np_out(in_data)

    def get_np_output_recursively(self):
        if self.np_output_lock:
            return self.np_out_data
        else:
            self.np_output_lock = True
            in_data_list = [prev_layer.get_np_output_recursively()
                            for prev_layer in self.prev_layers]
            return self.np_out(in_data_list)

    def get_quantized_output_recursively(self, quant_vals):
        if self.quantized_output_lock:
            return self.np_out_data
        else:
            self.quantized_output_lock = True
            in_data_list = [prev_layer.get_quantized_output_recursively(quant_vals)
                            for prev_layer in self.prev_layers]

            return self.np_out(in_data_list)


class MyMaxPool(MyLayer):
    def __init__(self, prev_layer=None,
                 pool_size=(2, 2),
                 name='', np_dtype='float64'):

        MyLayer.__init__(self, prev_layer=prev_layer,
                         name=name, np_dtype=np_dtype)
        self.pool_size = pool_size

    def np_out(self, in_data):
        self.in_data = in_data
        batch, height, width, depth = in_data.shape
        reduced_height = height // self.pool_size[0]
        reduced_width = width // self.pool_size[1]

        self.np_out_data = in_data.reshape(batch, reduced_height, self.pool_size[0],
                                           reduced_width, self.pool_size[1], depth)
        self.np_out_data = self.np_out_data.max(axis=2).max(axis=3)

        self.np_out_data = self.np_out_data
        return self.np_out_data

    def quantized_out(self, in_data, quant_vals):
        return self.np_out(in_data)


# ---------------------------- PURE BATCH NORM----------------------

class MyBatchNorm(MyLayer):
    '''
    Dont worry about this

    Batch norm is: output = beta + gamma(input - mean)/sqrt(var + epsilon)
            beta, gamma - learnt paramters
            mean, var   - of all batches from training data
            epsilon     - small constant to prevent division by zero

            During inference time, all 5 parameters are known
    '''

    def __init__(self, weights, prev_layer=None, epsilon=0.001, name='', np_dtype='float64'):
        MyLayer.__init__(
            self, name=name, prev_layer=prev_layer, np_dtype=np_dtype)

        gamma, beta, mean, variance = weights
        assert gamma.shape == beta.shape == mean.shape == variance.shape

        self.gamma = gamma.astype(self.np_dtype)
        self.beta = beta.astype(self.np_dtype)
        self.mean = mean.astype(self.np_dtype)
        self.variance = variance.astype(self.np_dtype)
        self.epsilon = epsilon

    def np_out(self, in_data):
        in_data = in_data.astype(self.np_dtype)

        self.sigma = np.sqrt(self.variance + self.epsilon)

        out = self.gamma * (in_data - self.mean)/self.sigma + self.beta
        assert out.dtype == self.np_dtype

        return out

    def np_out2(self, in_data):
        self.sigma = np.sqrt(self.variance + self.epsilon)
        A = self.gamma / self.sigma
        B = self.beta - A * self.mean

        out = A * in_data + B
        assert out.dtype == self.np_dtype
        return out


# -------------------------- HELPER FUNCTIONS ----------------------------

def show_hist(a, color):
    n, bins, patches = plt.hist(
        a.flatten(),
        100, facecolor=color, alpha=0.5)
    plt.show()


def e(a1, a2):
    '''
    Returns the L1 error (sum of absolute error between two ndarrays)
    '''
    print(np.sum(np.abs(np.asarray(a1)-np.asarray(a2))))
