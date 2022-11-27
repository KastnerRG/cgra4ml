import torch.nn as nn
import torch
import torch.nn.functional as F
from torch.nn.parameter import Parameter
import random
import numpy as np


def weight_quantization(b):

    def uniform_quant(x, b):
        xdiv = x.mul((2 ** b - 1))
        xhard = xdiv.round().div(2 ** b - 1)  
        #print('uniform quant bit: ', b)
        return xhard

    class _pq(torch.autograd.Function):
        @staticmethod
        def forward(ctx, input, alpha):
            input.div_(alpha)                          # weights are first divided by alpha
            input_c = input.clamp(min=-1, max=1)       # then clipped to [-1,1]
            sign = input_c.sign()
            input_abs = input_c.abs()
            input_q = uniform_quant(input_abs, b).mul(sign)
            ctx.save_for_backward(input, input_q)
            input_q = input_q.mul(alpha)               # rescale to the original range
            return input_q

        @staticmethod
        def backward(ctx, grad_output):
            grad_input = grad_output.clone()             # grad for weights will not be clipped
            input, input_q = ctx.saved_tensors
            i = (input.abs()>1.).float()     # >1 means clipped. # output matrix is a form of [True, False, True, ...]
            sign = input.sign()              # output matrix is a form of [+1, -1, -1, +1, ...]
            grad_alpha = (grad_output*(sign*i + (0.0)*(1-i))).sum()
            # above line, if i = True,  and sign = +1, "grad_alpha = grad_output * 1"
            #             if i = False, "grad_alpha = grad_output * (input_q-input)"
            grad_input = grad_input*(1-i)
            return grad_input, grad_alpha

    return _pq().apply


class weight_quantize_fn(nn.Module):
    def __init__(self, w_bit, w_alpha):
        super(weight_quantize_fn, self).__init__()
        self.w_bit = w_bit-1
        self.weight_q = weight_quantization(b=self.w_bit)
        self.register_parameter('w_alpha', Parameter(torch.tensor(w_alpha)))

    def forward(self, weight):
        mean = weight.data.mean()
        std = weight.data.std()
        weight = weight.add(-mean).div(std)      # weights normalization
        weight_q = self.weight_q(weight, self.w_alpha)
        return weight_q


def act_quantization(b):

    def uniform_quant(x, b=4):
        xdiv = x.mul(2 ** b - 1)
        xhard = xdiv.round().div(2 ** b - 1)
        return xhard

    class _uq(torch.autograd.Function):
        @staticmethod
        def forward(ctx, input, alpha):
            input=input.div(alpha)
            input_c = input.clamp(max=1)  # Mingu edited for Alexnet
            input_q = uniform_quant(input_c, b)
            ctx.save_for_backward(input, input_q)
            input_q = input_q.mul(alpha)
            return input_q

        @staticmethod
        def backward(ctx, grad_output):
            grad_input = grad_output.clone()
            input, input_q = ctx.saved_tensors
            i = (input > 1.).float()
            #grad_alpha = (grad_output * (i + (input_q - input) * (1 - i))).sum()
            grad_alpha = (grad_output * (i + (0.0)*(1-i))).sum()
            grad_input = grad_input*(1-i)
            return grad_input, grad_alpha
    return _uq().apply


class QuantConv2d(nn.Conv2d):
    def __init__(self, in_channels, out_channels, kernel_size, stride=1, padding=0, dilation=1, groups=1, bias=False, x_bit=8, w_bit=8, x_alpha=8.0, w_alpha=3.0):
        super(QuantConv2d, self).__init__(in_channels, out_channels, kernel_size, stride, padding, dilation, groups,
                                          bias)
        self.layer_type = 'QuantConv2d'
        self.x_bit = x_bit
        self.w_bit = w_bit
        self.weight_quant = weight_quantize_fn(w_bit=self.w_bit, w_alpha=w_alpha)
        self.act_alq = act_quantization(self.x_bit)
        self.x_alpha = torch.nn.Parameter(torch.tensor(x_alpha))
        self.weight_q  = torch.nn.Parameter(torch.zeros([out_channels, in_channels, kernel_size, kernel_size]))
        
    def forward(self, x):
        weight_q = self.weight_quant(self.weight)       
        #self.register_parameter('weight_q', Parameter(weight_q))  # Mingu added
        self.weight_q = torch.nn.Parameter(weight_q)  # Store weight_q during the training
        x = self.act_alq(x, self.x_alpha)
        return F.conv2d(x, weight_q, self.bias, self.stride, self.padding, self.dilation, self.groups)
    
    def show_params(self):
        w_alpha = round(self.weight_quant.w_alpha.data.item(), 3)
        x_alpha = round(self.x_alpha.data.item(), 3)
        print('clipping threshold weight alpha: {:2f}, activation alpha: {:2f}'.format(w_alpha, x_alpha))

