
import torch
import torch.nn as nn
import torch.nn.utils.prune as prune
import math

from quant_layer import *

'''
resnet for cifar in pytorch
Reference:
[1] K. He, X. Zhang, S. Ren, and J. Sun. Deep residual learning for image recognition. In CVPR, 2016.
[2] K. He, X. Zhang, S. Ren, and J. Sun. Identity mappings in deep residual networks. In ECCV, 2016.
'''

def conv3x3(in_planes, out_planes, stride=1):
    " 3x3 convolution with padding "
    return nn.Conv2d(in_planes, out_planes, kernel_size=3, stride=stride, padding=1, bias=False)

def Quantconv3x3(in_planes, out_planes, stride=1):
    " 3x3 quantized convolution with padding "
    return QuantConv2d(in_planes, out_planes, kernel_size=3, stride=stride, padding=1, bias=False)


class BasicBlock(nn.Module):
    expansion=1

    def __init__(self, inplanes, planes, stride=1, downsample=None, float=False):
        super(BasicBlock, self).__init__()
        if float:
            self.conv1 = conv3x3(inplanes, planes, stride)
            self.conv2 = conv3x3(planes, planes)
        else:
            self.conv1 = Quantconv3x3(inplanes, planes, stride)
            self.conv2 = Quantconv3x3(planes, planes)
        self.bn1 = nn.BatchNorm2d(planes)
        self.relu = nn.ReLU(inplace=True)
        self.bn2 = nn.BatchNorm2d(planes)
        self.downsample = downsample
        self.stride = stride

    def forward(self, x):
        residual = x
        out = self.conv1(x)
        out = self.bn1(out)
        out = self.relu(out)

        out = self.conv2(out)
        out = self.bn2(out)

        if self.downsample is not None:
            residual = self.downsample(x)

        out += residual
        out = self.relu(out)

        return out


class Bottleneck(nn.Module):
    expansion=4

    def __init__(self, inplanes, planes, stride=1, downsample=None):
        super(Bottleneck, self).__init__()
        self.conv1 = nn.Conv2d(inplanes, planes, kernel_size=1, bias=False)
        self.bn1 = nn.BatchNorm2d(planes)
        self.conv2 = nn.Conv2d(planes, planes, kernel_size=3, stride=stride, padding=1, bias=False)
        self.bn2 = nn.BatchNorm2d(planes)
        self.conv3 = nn.Conv2d(planes, planes*4, kernel_size=1, bias=False)
        self.bn3 = nn.BatchNorm2d(planes*4)
        self.relu = nn.ReLU(inplace=True)
        self.downsample = downsample
        self.stride = stride

    def forward(self, x):
        residual = x

        out = self.conv1(x)
        out = self.bn1(out)
        out = self.relu(out)

        out = self.conv2(out)
        out = self.bn2(out)
        out = self.relu(out)

        out = self.conv3(out)
        out = self.bn3(out)

        if self.downsample is not None:
            residual = self.downsample(x)

        out += residual
        out = self.relu(out)

        return out

    
class ResNet_Cifar(nn.Module):
    
    def __init__(self, name, x_bit, w_bit, x_alpha, w_alpha_init, num_classes=10, float=False):
        
        super(ResNet_Cifar, self).__init__()
        
        layers_dict = {
            'resnet20_quant': 3,
            'resnet32_quant': 5,
            'resnet44_quant': 7,
            'resnet56_quant': 9,
            'resnet110_quant': 18,
            'resnet164_quant': 18,
            'resnet1202_quant': 200,
            'resnet1001_quant': 111,
        }
        
        block = BasicBlock
        layers = 3*[layers_dict[name]]
        
        self.name = name
        self.x_bit= x_bit
        self.w_bit= w_bit
        self.x_alpha=x_alpha
        self.w_alpha_init=w_alpha_init
        
        self.inplanes = 16
        self.conv1 = nn.Conv2d(3, 16, kernel_size=3, stride=1, padding=1, bias=False)
        self.bn1 = nn.BatchNorm2d(16)
        self.relu = nn.ReLU(inplace=True)
        self.layer1 = self._make_layer(block, 16, layers[0], float=float)
        self.layer2 = self._make_layer(block, 32, layers[1], stride=2, float=float)
        self.layer3 = self._make_layer(block, 64, layers[2], stride=2, float=float)
        self.avgpool = nn.AvgPool2d(8, stride=1)
        self.fc = nn.Linear(64 * block.expansion, num_classes)

        for m in self.modules():
            if isinstance(m, nn.Conv2d):
                n = m.kernel_size[0] * m.kernel_size[1] * m.out_channels
                m.weight.data.normal_(0, math.sqrt(2. / n))
            elif isinstance(m, nn.BatchNorm2d):
                m.weight.data.fill_(1)
                m.bias.data.zero_()

    def _make_layer(self, block, planes, blocks, stride=1, float=False):
        downsample = None
        if stride != 1 or self.inplanes != planes * block.expansion:
            downsample = nn.Sequential(
                QuantConv2d(
                    self.inplanes, 
                    planes * block.expansion, 
                    kernel_size=1, 
                    stride=stride, 
                    bias=False, 
                    x_bit=self.x_bit, 
                    w_bit=self.w_bit, 
                    x_alpha=self.x_alpha, 
                    w_alpha=self.w_alpha_init)
                if float is False else nn.Conv2d(self.inplanes, planes * block.expansion, kernel_size=1,
                                                 stride=stride, bias=False),
                nn.BatchNorm2d(planes * block.expansion)
            )

        layers = []
        layers.append(block(self.inplanes, planes, stride, downsample, float=float))
        self.inplanes = planes * block.expansion
        for _ in range(1, blocks):
            layers.append(block(self.inplanes, planes, float=float))

        return nn.Sequential(*layers)

    def forward(self, x):
        x = self.conv1(x)
        x = self.bn1(x)
        x = self.relu(x)

        x = self.layer1(x)
        x = self.layer2(x)
        x = self.layer3(x)

        x = self.avgpool(x)
        x = x.view(x.size(0), -1)
        x = self.fc(x)

        return x

    def show_params(self):
        for m in self.modules():
            if isinstance(m, QuantConv2d):
                m.show_params()
