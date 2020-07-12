# CNN Accelerator for Object Detection with YOLO on FPGA

This is a system and a set of soft IP cores developed by two students from University of Moratuwa to accelerate Deep Convolutional Neural Networks (CNNs) on an FPGA fabric as a part of our undergraduate thesis project "Vision Based Traffic Sensing on FPGA". System is implemented on Xilinx ZC706 board which houses a Z7045 PSoC (Programmable System on Chip).  1.7 billion operations per image are processed by our coprocessor with 24 convolution cores on the FPGA side and the process is controlled by our bare-metal C program running on the processing side.

![System](https://i.ibb.co/x5k2kGJ/Figure-7-system-diagram-1.png)

## Convolution Engine

A convolution engine is designed to perform 3x3 and 1x1 convolutions between 3D tensors of image pixels and weights using the same set of resources at 100% utilization (all multipliers and accumulators work at every clock cycle). At the current stable version (v2.0) of convolution module, 24 convolution cores consume 140,175 LUTs and 576 DSPs and are able to process 58 GFLOPS at 50 MHz. Version 3.0 is under development to vastly improve the frequency performance.

![Convolution Engine](https://i.ibb.co/d6VGTF0/Figure-8-conv-unit-1.png)

## Supporting Modules

Supporting modules such as Maxpool unit, Leaky ReLu unit, Input Pipe and Output Pipe to reorder pixels in required format are also presented.
