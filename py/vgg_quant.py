import torch
import torch.nn as nn
import torch.nn.utils.prune as prune
import math

from quant_layer import *

cfg = {
    'vgg11': [64, 'M', 128, 'M', 256, 256, 'M', 512, 512, 'M', 512, 512, 'M'],
    'vgg13': [64, 64, 'M', 128, 128, 'M', 256, 256, 'M', 512, 512, 'M', 512, 512, 'M'],
    'vgg16_quant': [64, 64, 'M', 128, 128, 'M', 256, 256, 256, 'M', 512, 512, 512, 'M', 512, 512, 512, 'M'],
    'vgg16': ['F', 64, 'M', 128, 128, 'M', 256, 256, 256, 'M', 512, 512, 512, 'M', 512, 512, 512, 'M'],
    'vgg19': [64, 64, 'M', 128, 128, 'M', 256, 256, 256, 256, 'M', 512, 512, 512, 512, 'M', 512, 512, 512, 512, 'M'],
}


class VGG_quant(nn.Module):
    def __init__(self, name, x_bit, w_bit, x_alpha, w_alpha_init):
        super(VGG_quant, self).__init__()
        
        self.name = name
        self.x_bit= x_bit
        self.w_bit= w_bit
        self.x_alpha=x_alpha
        self.w_alpha_init=w_alpha_init
        
        self.features = self._make_layers(cfg[name])
        self.classifier = nn.Linear(512, 10)

    def forward(self, x):
        out = self.features(x)
        out = out.view(out.size(0), -1)
        out = self.classifier(out)
        return out

    def _make_layers(self, cfg):
        layers = []
        in_channels = 3
        conv_i = 0
        for x in cfg:
            if x == 'M':
                layers += [nn.MaxPool2d(kernel_size=2, stride=2)]
            elif x == 'F':  # This is for the 1st layer
                layers += [nn.Conv2d(in_channels, 64, kernel_size=3, padding=1, bias=False),
                           nn.BatchNorm2d(64),
                           nn.ReLU(inplace=True)]
                in_channels = 64
            else:
                conv_i += 1
                if conv_i == 5:
                    layers += [QuantConv2d(in_channels, x, kernel_size=3, padding=1, x_bit=self.x_bit, w_bit=self.w_bit, x_alpha=self.x_alpha, w_alpha=self.w_alpha_init),
#                            nn.BatchNorm2d(x),
                           nn.ReLU(inplace=True)]
                else:
                    layers += [QuantConv2d(in_channels, x, kernel_size=3, padding=1, x_bit=self.x_bit, w_bit=self.w_bit, x_alpha=self.x_alpha, w_alpha=self.w_alpha_init),
                           nn.BatchNorm2d(x),
                           nn.ReLU(inplace=True)]
                in_channels = x
        layers += [nn.AvgPool2d(kernel_size=1, stride=1)]
        return nn.Sequential(*layers)

    def show_params(self):
        for m in self.modules():
            if isinstance(m, QuantConv2d):
                m.show_params()
