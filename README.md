# DeepSoCFlow: DNNs to FPGA/ASIC SoCs in minutes ![status](https://github.com/abarajithan11/dnn-engine/actions/workflows/verify.yml/badge.svg) 

DeepSoCFlow is a Python library that helps researchers build, train, and implement their own deep ML models, such as ResNet CNNs, Autoencoders, and Transformers on FPGAs and custom ASIC.

It takes several months of work to get such deep models running correctly on edge platforms, at their promised maximal performance. This painful work includes:

- Designing an optimal dataflow
- Building & verifying an accelerator, optimizing for high-frequency
- Building the System-on-Chip, verifying and optimizing data bottlenecks
- Writing C firmware to control the accelerator, verifying, optimizing

Often, after all that work, the models do not meet their expected performance due to memory bottlenecks and sub-optimal hardware implementation.

We present a highly flexible, high performance accelerator system that can be adjusted to your needs through a simple Python API. The implementation is maintained as open source and bare-bones, allowing the user to modify the processing element to do floating point, binarized calculations...etc.  

![System](docs/overall.png)

## User API (WIP)

```py
from deepsocflow import Hardware, Bundle, QInput, BundleModel, QConvCore, QDenseCore, QAdd, QPool, Softmax, QLeakyReLu

'''
0. Specify Hardware
'''
hw = Hardware (
        processing_elements = (8, 96),
        frequency           = 1000,
        bits_input          = 8,
        bits_weights        = 4,
        bits_sum            = 24,
        bits_bias           = 16,
        max_kernel_size     = (13, 13),
        max_channels_in     = 512,
        max_channels_out    = 512,
        max_image_size      = (32,32),
     )
hw.export() # Generates: config_hw.svh, config_hw.tcl, config_hw.json
# Alternatively: hw = Hardware.from_json('config_hw.json')

'''
1. Build Model 
'''
x = QInput( input_shape= (8,32,32,3), hw= hw, input_frac_bits= 4)

x = Bundle( core= QConvCore(filters= 32, kernel_size= (7,7), strides= (2,2), padding= 'same', weights_frac_bits= 4, bias_frac_bits= 8, activation= QLeakyReLu(negative_slope=0.125, frac_bits= 4 )),
            pool= QPool(type= 'max', size= (3,3), strides= (1,1), padding= 'same', frac_bits= 4)
            )(x)
x_skip = x
x = Bundle( core= QConvCore(filters= 64, kernel_size= (3,3), weights_frac_bits= 4, bias_frac_bits= 8, activation= QLeakyReLu(negative_slope=0, frac_bits= 4)),
            pool= QAdd(x_skip), # Residual addition
            flatten= True,
            )(x)
x = Bundle( dense= QDenseCore(outputs= 10, weights_frac_bits= 4, bias_frac_bits= 8, activation= Softmax()),
            )(x)
model = BundleModel(inputs=x_in, outputs=x)
# Alternatively: model = BundleModel.from_json('config_model.json')

'''
2. TRAIN (using qkeras)
'''
model.compile(...)
model.fit(...)
model.export() # Generates: savedmodel, config_model.json

'''
3. EXPORT FOR INFERENCE

- Runs forward pass in float32, records intermediate tensors
- Runs forward pass in integer, comparing with float32 pass for zero error
- Runs SystemVerilog testbench with the model & weights, randomizing handshakes, testing with actual C firmware in simulation
- Prints performance estimate (time, latency)
- Generates 
      - config_firmware.h
      - weights.bin
      - expected.bin
'''
model.export_inference(x=model.random_input) # -> config_firmware.h, weights.bin

'''
4. IMPLEMENTATION

a. FPGA: Run vivado.tcl
b. ASIC: Set PDK paths, run syn.tcl & pnr.tcl
c. Compile C firmware with generated header (model.h) and run on device
'''
```

## Motivation

[HLS4ML](https://github.com/fastmachinelearning/hls4ml) is an open source python framework that's being widely adopted by the scientific community, to generate FPGA & ASIC implementations of their custom Deep Neural Networks. CERN has taped out chips with DNN compression algorithms to be used in LHC using HLS4ML. However, it is not possible to implement deeper neural networks on HLS4ML since it implements one engine per layer in hardware. This project aims to solve that problem and enhance HLS4ML, by creating a statically & dynamically reconfigurable, AXI-Stream DNN engine.


## Quick Start

1a. Either [install Verilator 5.014+](https://verilator.org/guide/latest/install.html#git-quick-install) 

1b. Or install Xilinx Vivado, and set its path in `test/py/param_test.py` & set `sim='xsim'`

2. Install pytest for parametrized testing and Qkeras + Tensorflow + Numpy to quantize and manipulate DNNs.
```
pip install pytest numpy tensorflow qkeras
```

3. Generate parameters for following steps & run the parametrized test:
```
cd test
python -m pytest -s py/param_test.py
```

4. FPGA implementation:
Open Xilinx Vivado, cd into the project root, and type the following in TCL console
```
mkdir fpga/work
cd fpga/work
source ../scripts/vivado.tcl
```

5. ASIC implementation with Cadence Genus & Innovus:
First add your PDK to 'asic/pdk', change paths in the scripts and run:
```
mkdir asic/work
cd asic/work
genus -f ../scripts/run_genus.tcl
innovus
source ../scripts/pnr.tcl
```

## Repository Structure

![System](docs/infra.png)

- asic - contains the ASIC workflow
  - scripts
  - work
  - pdk
  - reports
  - outputs
- fpga - contains the FPGA flow
  - scripts
  - work
  - reports
  - outputs
- c - contains runtime firmware
- rtl - contains the systemverilog design of the engine
- test
  - py - python files build bundles, and the pytest module for parametrized testing
  - sv - randomized testbenches (systemverilog)
  - vectors - generated test vectors
  - waveforms - generated waveforms

## Team Members

- Aba
- Zhenghua

## Results

![Results](docs/results-2.png)

### Results for 8 bit

The dataflow and its implementation results in 5.8× more Gops/mm2, 1.6× more Gops/W, higher MAC utilization & fewer DRAM accesses than the state-of-the-art (TCAS-1, TCOMP), processing AlexNet, VGG16 & ResNet50 at 336.6, 17.5 & 64.2 fps, when synthesized as a 7mm^2 chip usign TSMC 65nm GP.

![Results](docs/results.png)

Performance Efficiency (PE utilization across space & time) and number of DRAM accesses:

![Results](docs/perf.png)
![Results](docs/memory.png)
