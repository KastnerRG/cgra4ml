'''
FPGA Reshaper class reads a dictionary of layers of a CNN built by Aba's numpy framework,
reshapes the weights and a sample image to the FPGA format. 
Make_commands generates xsct commands to load and unload them via UART.
Compare is used to measure error between FPGA output and numpy's float16 processing.

- make_weights
- make_weights_all
- make_image
- make_image_all
- make commands
- compare
'''

import numpy as np
import os

__author__ = "Abarajithan G"
__copyright__ = "Copyright 2019, Final Year Project"
__credits__ = ["Abarajithan G"]
__version__ = "1.0.0"
__maintainer__ = "Abarajthan G"
__email__ = "abarajithan07@gmail.com"
__status__ = "Research"


class FPGA_Reshaper():
    def __init__(self,
                 model_dict,
                 conv_units=8,
                 num_cores=2,
                 to_txt=False,
                 to_bin=False,
                 all_bin=False,
                 path='cores/',
                 conv_prefix='conv',
                 max_prefix='maxpool',
                 activation_prefix='lrelu',
                 image_mem=[['0x81000000', '0x82000000'],
                            ['0x83000000', '0x84000000']],
                 weights_mem='0x89000000'
                 ):

        self.model_dict = model_dict
        self.conv_units = conv_units
        self.num_cores = num_cores
        self.to_txt = to_txt
        self.to_bin = to_bin
        self.all_bin = all_bin
        self.path = path
        self.conv_prefix = conv_prefix
        self.max_prefix = max_prefix
        self.activation_prefix = activation_prefix
        self.num_conv_layers = len(
            [c for c in self.model_dict.keys() if ('conv' in c)])
        self.image_mem = image_mem
        self.weights_mem = weights_mem

        self.toggle = 0

        if not os.path.isdir(path):
            os.mkdir(path)
        if not os.path.isdir(path + 'txt/'):
            os.mkdir(path + 'txt/')
        if not os.path.isdir(path + 'mem_bin/'):
            os.mkdir(path + 'mem_bin/')

    def make_weights(self, i):
        ''' Check Maxpool '''
        try:
            a = self.model_dict[f'{self.max_prefix}_{i}']
            m = True
        except:
            m = False

        n = self.num_cores

        # (3, 3, cin, cout)        : (3, 3, 64, 128) - Layer 3
        kernel = self.model_dict[f'{self.conv_prefix}_{i}'].weights
        # (cout,)                  : (128,)          - Layer 3
        biases = self.model_dict[f'{self.conv_prefix}_{i}'].biases

        k, _, cin, cout = kernel.shape
        kernel_shape_orig = kernel.shape
        biases_shape_orig = biases.shape

        ''' Check 3x3 or 1x1 '''
        if k == 3:
            if m:
                p = n//2
            else:
                p = n

            kernel_orig = self.model_dict[f'{self.conv_prefix}_{i}'].weights
            # (3, 3, cin, cout)      : (3, 3, 64, 128) - Layer 3
            kernel = self.model_dict[f'{self.conv_prefix}_{i}'].weights
            k, _, cin, cout = kernel.shape

            if m and cin % 2:
                cin += 1
                dummy_cin = np.zeros((k, k, 1, cout), np.float16)
                kernel = np.concatenate([kernel, dummy_cin], axis=2)

            itr = cout//p + (cout % p != 0)
            # cout_fpga         = 11 * 6      = 66
            cout_fpga = itr*p
            if cout % p:
                # cout_first_valid  = 64 % 6      = 4
                cout_first_valid = cout % p
            else:
                cout_first_valid = p
            # cout_first_invalid=  6 - 4      = 2
            cout_first_invalid = p - cout_first_valid

            # (cin, cout_first_invalid): (128,  2)
            kernel_invalid = np.zeros(
                (k, k, cin, cout_first_invalid), dtype=np.float16)
            # (cin, cout_first_valid)  : (128,  4)
            kernel_valid = kernel[:, :, :, 0:cout_first_valid]
            # (cin, cout-cout_f_valid) : (128, 60)
            kernel_rest = kernel[:, :, :, cout_first_valid:]

            # (cin, [v, inv, rest])    : (128, [4+2+60])
            kernel = np.concatenate(
                [kernel_valid, kernel_invalid, kernel_rest], axis=3)
            # (cin, cout_fpga)         : (128, 66)
            assert kernel.shape == (k, k, cin, cout_fpga)
            #######

            # (9, cin, cout)         : (9, 64, 128)
            kernel = kernel.reshape((k**2, cin, cout_fpga))
            # (9, cin, cout/p, p)    : (9, 64, 64, 2)
            kernel = kernel.reshape((k**2, cin, itr, p))
            # (cout/p, cin, p, 9)    : (64, 64, 2, 9)
            kernel = kernel.transpose((2, 1, 3, 0))
            # (cout/p, cin, 9p)      : (64, 64, 18)
            kernel = kernel.reshape((itr, cin, 9*p))
            # (cout/p, cin, 3, 3p)   : (64, 64, 3, 6)
            kernel = kernel.reshape((itr, cin, 3, 3*p))
            # (cout/p, 3*cin, 3p)    : (64, 192, 6)
            kernel = kernel.reshape((itr, cin*3, 3*p))

            # (cout,)         : (128,) - Layer 3
            bias = self.model_dict[f'{self.conv_prefix}_{i}'].biases
            # (cout_first_invalid,)    : (2)
            bias_invalid = np.zeros(cout_first_invalid, dtype=np.float16)
            # (cout_first_valid,)      : (4)
            bias_valid = bias[0:cout_first_valid]
            # (cout-cout_f_valid)      : (60)
            bias_rest = bias[cout_first_valid:]

            # ([invalid,valid, rest])  : ([2+4+64])
            bias = np.concatenate([bias_valid, bias_invalid, bias_rest])
            # (cout_fpga)              : (66,)
            assert bias.shape[0] == cout_fpga

            # (cout_fpga,3) : (66,3)
            bias_pad = np.zeros((cout_fpga, 3), np.float16)
            # (cout_fpga,3) : (66,3)  # Bias is given to the center
            bias_pad[:, 1] = bias
            # (cout_fpga,3) : (66,3)
            bias = bias_pad

            # (cout/p, p, 3)  : (64, 2, 3)
            bias = bias.reshape(itr, p, 3)
            # (cout/p, 3, p)  : (64, 3, 2)
            bias = bias.transpose([0, 2, 1])
            # (cout/p, 1, 3p) : (64, 1, 6)
            bias = bias.reshape(itr, 1, 3*p)

            if m:
                kernel = kernel.reshape((itr, cin*3//2, 3*n))
                bias = bias.repeat(2, axis=2)

            '''Bias comes first'''
            weights = np.concatenate(
                [bias, kernel], axis=1)  # (cout/p, 3*cin+1, 3*p)   : (6, 193, 64)
            # (3*cout*(3*cin+1))       : (74112)
            weights = weights.flatten()

        else:
            # p = 6
            p = 3*n
            # (cin,cout)     : (128,64)
            kernel = kernel.squeeze()

            # itr               = 64 % 6 + 1  = 10 + 1 = 11
            itr = cout//p + (cout % p != 0)
            # cout_fpga         = 11 * 6      = 66
            cout_fpga = itr*p
            # cout_first_valid  = 64 % 6      = 4
            cout_first_valid = cout % p
            # cout_first_invalid=  6 - 4      = 2
            cout_first_invalid = p - cout_first_valid

            # (cin, cout_first_invalid): (128,  2)
            kernel_invalid = np.zeros(
                (cin, cout_first_invalid), dtype=np.float16)
            # (cin, cout_first_valid)  : (128,  4)
            kernel_valid = kernel[:, 0:cout_first_valid]
            # (cin, cout-cout_f_valid) : (128, 60)
            kernel_rest = kernel[:, cout_first_valid:]

            # (cin, [v, inv, rest])    : (128, [4+2+60])
            kernel = np.concatenate(
                [kernel_valid, kernel_invalid, kernel_rest], axis=1)
            # (cin, cout_fpga)         : (128, 66)
            assert kernel.shape == (cin, cout_fpga)

            # (cin, itr,  3, n)        : (128, 11,  3, 2)
            kernel = kernel.reshape((cin, itr, 3, n))
            # (cin, itr, -3, n)        : (128, 11, -3, 2)
            kernel = np.flip(kernel, axis=2)
            # (itr, cin,  n, 3)        : (11, 128,  2, 3)
            kernel = np.einsum('ijkl->jilk', kernel)
            # (itr, cin,  3*n )        : (11, 128,  6)
            kernel = kernel.reshape((itr, cin, 3*n))

            # (cout,)                  : (64,)
            biases = self.model_dict[f'{self.conv_prefix}_{i}'].biases
            assert cout == biases.size

            # (cout_first_invalid,)    : (2)
            biases_invalid = np.zeros(cout_first_invalid, dtype=np.float16)
            # (cout_first_valid,)      : (4)
            biases_valid = biases[0:cout_first_valid]
            # (cout-cout_f_valid)      : (60)
            biases_rest = biases[cout_first_valid:]

            # ([invalid,valid, rest])  : ([2+4+64])
            biases = np.concatenate(
                [biases_valid, biases_invalid, biases_rest])
            # (cout_fpga)              : (66,)
            assert biases.shape[0] == cout_fpga

            # (itr,  3,  n)            : (11, 3, 2)
            biases = biases.reshape((itr, 3, n))
            # (itr, -3,  n)            : (11,-3, 2)
            biases = np.flip(biases, axis=1)
            # (itr,  n,  3)            : (11, 2, 3)
            biases = np.einsum('jkl->jlk', biases)
            # (itr, 1, 3*n)            : (11, 1, 6)
            biases = biases.reshape((itr, 1, 3*n))

            '''Biases come first'''
            weights = np.concatenate(
                [biases, kernel], axis=1)                              # (itr, cin+1, 3*n)        : (11, 129, 6)
            # (3*n*itr*(cin+1))
            weights = weights.flatten()

        weights_bytes = weights.tobytes()
        print(f'{i}\t{k}\t{m}\t{str(kernel_shape_orig):<20s} {str(biases_shape_orig):<10s} {str(kernel.shape):<18s} {biases.shape} \t{str(weights.shape):<15s}\t{len(weights_bytes)}')

        '''
        Cross Check SOC's formula
        '''
    #     assert weights.size == 3 * (n * itr) * (k * cin/max_factor + 1)  # Compare with C code's calculation not correct for 1x1

        if self.to_txt:
            with open(self.path + f'txt/{i}_wb.txt', 'w') as f:
                weights_int16 = np.frombuffer(weights_bytes, dtype=np.uint16)
                for k in weights_int16:
                    f.write(str(k)+'\n')
        if self.to_bin:
            with open(self.path + f'mem_bin/{i}_wb.bin', 'wb') as f:
                f.write(weights_bytes)

        return weights

    def make_weights_all(self):
        self.weights_all = None

        print(
            f'i\tk\tm\t{"ker_orig":<20s} {"b_orig":<10s} {"ker_out":<18s} b_out \tweights_out \tweights_bytes')
        for i in range(1, self.num_conv_layers+1):
            current_weights = self.make_weights(i)
            if self.all_bin:
                if self.weights_all is None:
                    self.weights_all = current_weights
                else:
                    self.weights_all = np.append(
                        self.weights_all, current_weights)

        with open(self.path + f'mem_bin/weights_all.bin', 'wb') as f:
            f.write(self.weights_all)

    def make_image(self, i):
        try:
            a = self.model_dict[f'{self.max_prefix}_{i}']
            m = True
            max_factor = 2
        except:
            m = False
            max_factor = 1

        image = self.model_dict[f'{self.conv_prefix}_{i}'].in_data[0]
        assert len(image.shape) == 3
        h, w, c = image.shape
        blocks = h//self.conv_units
        image = np.pad(image, ((1, 1), (0, 0), (0, 0)), mode='constant')

        image = image.astype(np.float16)

        if m:
            if c % 2:
                c = c+1
                h1, w1, _ = image.shape
                zeros = np.zeros((h1, w1, 1), dtype=np.float16)
                image = np.concatenate([image, zeros], axis=2)

            im_arrays = [np.empty((0), dtype=np.float16),
                         np.empty((0), dtype=np.float16)]
            for k in range(blocks):
                temp = image[k*self.conv_units:(k+1)*self.conv_units+2, :, :]
                temp = np.transpose(temp, [1, 2, 0]).flatten()
                im_arrays[k % 2] = np.append(im_arrays[k % 2], temp)

            im_bytes = [im_array.tobytes() for im_array in im_arrays]

            im_array = im_arrays[0]  # to check size

            for k in range(2):
                if self.to_txt:
                    with open(self.path + f'txt/{i}_im_{k}.txt', 'w') as f:
                        im_int16 = np.frombuffer(im_bytes[k], dtype=np.uint16)
                        for l in im_int16:
                            f.write(str(l)+'\n')
                if self.to_bin:
                    with open(self.path + f'mem_bin/{i}_im_{k}.bin', 'wb') as f:
                        f.write(im_bytes[k])
        else:
            im_array = np.empty((0), dtype=np.float16)
            for k in range(blocks):
                temp = image[k*self.conv_units:(k+1)*self.conv_units+2, :, :]
                temp = np.transpose(temp, [1, 2, 0]).flatten()
                im_array = np.append(im_array, temp)

            im_bytes = im_array.tobytes()
            if self.to_txt:
                with open(self.path + f'txt/{i}_im.txt', 'w') as f:
                    im_int16 = np.frombuffer(im_bytes, dtype=np.uint16)
                    for k in im_int16:
                        f.write(str(k)+'\n')
            if self.to_bin:
                with open(self.path + f'mem_bin/{i}_im.bin', 'wb') as f:
                    f.write(im_bytes)
        print(i)

        '''
        Check FPGA's formula
        '''
        assert len(im_array) == (self.conv_units + 2)*c*w*blocks/max_factor

    def make_image_all(self):
        for i in range(1, self.num_conv_layers+1):
            self.make_image(i)

    def make_image_out(self, i, next_max, to_txt=False, txt_float=False):
        if i != self.num_conv_layers:
            if next_max:
                image = self.model_dict[f'{self.conv_prefix}_{i+1}'].in_data[0]
                assert len(image.shape) == 3
                h, w, c = image.shape
                blocks = h//self.conv_units
                image = np.pad(image, ((1, 1), (0, 0), (0, 0)),
                               mode='constant')
                image = image.astype(np.float16)

                if c % 2:
                    c = c+1
                    h1, w1, _ = image.shape
                    zeros = np.zeros((h1, w1, 1), dtype=np.float16)
                    image = np.concatenate([image, zeros], axis=2)

                im_arrays = [np.empty((0), dtype=np.float16),
                             np.empty((0), dtype=np.float16)]
                for k in range(blocks):
                    temp = image[k *
                                 self.conv_units: (k+1)*self.conv_units+2, :, :]
                    temp = np.transpose(temp, [1, 2, 0]).flatten()
                    im_arrays[k % 2] = np.append(im_arrays[k % 2], temp)

                self.im_array = np.array(im_arrays)

            else:
                image = self.model_dict[f'{self.conv_prefix}_{i+1}'].in_data[0]
                assert len(image.shape) == 3
                h, w, c = image.shape
                blocks = h//self.conv_units
                image = np.pad(image, ((1, 1), (0, 0), (0, 0)),
                               mode='constant')
                image = image.astype(np.float16)

                self.im_array = np.empty((0), dtype=np.float16)
                for k in range(blocks):
                    temp = image[k *
                                 self.conv_units:(k+1)*self.conv_units+2, :, :]
                    temp = np.transpose(temp, [1, 2, 0]).flatten()
                    self.im_array = np.append(self.im_array, temp)

        else:
            image = self.model_dict[f'{self.conv_prefix}_{i}'].np_out_data[0]
            assert len(image.shape) == 3
            h, w, c = image.shape

            last_cols = image[:, -2:, :]
            last_cols_flipped = np.flip(last_cols, axis=1)
            other_cols = image[:, :-2, :]
            image = np.concatenate([other_cols, last_cols_flipped], axis=1)

            blocks = h//self.conv_units
            image = np.pad(image, ((1, 1), (0, 0), (0, 0)), mode='constant')
            image = image.astype(np.float16)

            self.im_array = np.empty((0), dtype=np.float16)
            for k in range(blocks):
                temp = image[k*self.conv_units:(k+1)*self.conv_units+2, :, :]
                temp = np.transpose(temp, [1, 2, 0]).flatten()
                self.im_array = np.append(self.im_array, temp)

        if to_txt:
            with open(self.path + f'txt/{i}_im_out_np.txt', 'w') as f:
                if not txt_float:
                    im_bytes = self.im_array.tobytes()
                    im_array_flat = np.frombuffer(im_bytes, dtype=np.uint16)
                else:
                    im_array_flat = self.im_array.flatten()

                for k in im_array_flat:
                    f.write(str(k)+'\n')

    def compare(self, i, check_next_max=True):
        if check_next_max:
            try:
                a = self.model_dict[f'{self.max_prefix}_{i+1}']
                next_max = True
            except:
                next_max = False
        else:
            next_max = False

        self.make_image_out(i=i, next_max=next_max)

        if i != self.num_conv_layers:
            if next_max:
                print(f"Comparing output of {i} to input of {i+1} (max)")

                fpga_out = []
                with open(self.path + f"mem_bin/{i}_out_0.bin", 'rb') as f:
                    a = f.read()
                fpga_out += [np.frombuffer(a, np.float16)]
                with open(self.path + f"mem_bin/{i}_out_1.bin", 'rb') as f:
                    a = f.read()
                fpga_out += [np.frombuffer(a, np.float16)]
                fpga_out = np.array(fpga_out)

            else:
                print(f"Comparing output of {i} to input of {i+1} (nonmax)")

                with open(self.path + f"mem_bin/{i}_out.bin", 'rb') as f:
                    a = f.read()
                fpga_out = np.frombuffer(a, np.float16)
        else:
            print(f"Comparing output of {i} to output of {i} (not maxpool)")
            with open(self.path + f"mem_bin/{i}_out.bin", 'rb') as f:
                a = f.read()
            fpga_out = np.frombuffer(a, np.float16)

        mse = np.sum((self.im_array - fpga_out)**2)/im_array.size
        print("Mean square error: ", mse)

    def make_commands(self, i):
        try:
            a = self.model_dict[f'{self.max_prefix}_{i}']
            m = True
            max_factor = 2
        except:
            m = False
            max_factor = 1
        '''
        Input Image
        '''
        _, h, w, c = self.model_dict[f'{self.conv_prefix}_{i}'].in_data.shape
        if c % 2 == 1:
            c += 1
        b = h//self.conv_units
        image_in_words = (self.conv_units+2)*b*w*c//max_factor

        '''
        Output Image
        '''
        if i == self.num_conv_layers:
            m_next = False
            _, h, w, c = self.model_dict[f'{self.conv_prefix}_{i}'].np_out_data.shape
        else:
            _, h, w, c = self.model_dict[f'{self.conv_prefix}_{i+1}'].in_data.shape
            try:
                a = self.model_dict[f'{self.max_prefix}_{i+1}']
                m_next = True
                max_factor = 2
            except:
                m_next = False
                max_factor = 1
        if c % 2 == 1 and (i != self.num_conv_layers):
            c += 1
        b = h//self.conv_units
        image_out_words = (self.conv_units+2)*b*w*c//max_factor

        '''
        Weights
        '''
        k, k, cin, cout = self.model_dict[f'{self.conv_prefix}_{i}'].weights.shape

        if cin % 2 == 1:
            cin += 1

        if k == 3 and m:
            n_eff = self.num_cores//2
            weights_wpt = (3*3*(self.num_cores)*(cin)//2 + 3*(self.num_cores))
        elif k == 3:
            n_eff = self.num_cores
            weights_wpt = (3*3*self.num_cores*(cin) + 3*self.num_cores)
        else:
            n_eff = 3*self.num_cores
            weights_wpt = (3*self.num_cores*(cin) + 3*self.num_cores)

        itr = cout//n_eff + (cout % n_eff != 0)
        weights_words = weights_wpt*itr

        '''
        Commands
        '''
        weights_command = f"mwr -bin -file {self.path}mem_bin/{i}_wb.bin   {self.weights_mem} {weights_words*2//4}; "

        if m:
            image_in_command = f"mwr -bin -file {self.path}mem_bin/{i}_im_0.bin   {self.image_mem[self.toggle][0]} {image_in_words*2//4}; mwr -bin -file {self.path}mem_bin/{i}_im_1.bin   {self.image_mem[self.toggle][1]} {image_in_words*2//4}; "
        else:
            image_in_command = f"mwr -bin -file {self.path}mem_bin/{i}_im.bin   {self.image_mem[self.toggle][0]} {image_in_words*2//4}; "

        self.toggle = (not self.toggle)*1

        if m_next:
            image_out_command = f"mrd -bin -file {self.path}mem_bin/{i}_out_0.bin   {self.image_mem[self.toggle][0]} {image_out_words*2//4}; mrd -bin -file {self.path}mem_bin/{i}_out_1.bin   {self.image_mem[self.toggle][1]} {image_out_words*2//4}; "
        else:
            image_out_command = f"mrd -bin -file {self.path}mem_bin/{i}_out.bin   {self.image_mem[self.toggle][0]} {image_out_words*2//4}; "

        with open(self.path+'mem_bin/commands.txt', 'a+') as f:
            f.write(f'###* LAYER: {i}, CORES = {self.num_cores} \n\n')
            f.write(image_in_command + weights_command + '\n')
            f.write(image_out_command + '\n\n\n')

    def make_commands_all(self):
        for i in range(1, self.num_conv_layers+1):
            self.make_commands(i)
