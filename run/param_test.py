import os
import pytest
import itertools
import sys
sys.path.append("../../")
from deepsocflow import Bundle, Hardware, QModel, QInput
# import tensorflow as tf
# tf.keras.utils.set_random_seed(0)
# Simulator: xsim on windows, verilator otherwise
(SIM, SIM_PATH) = ('xsim', "E:/Vivado/2023.2/bin/") if os.name=='nt' else ('verilator', '')

def product_dict(**kwargs):
    for instance in itertools.product(*(kwargs.values())):
        yield dict(zip(kwargs.keys(), instance))

@pytest.mark.parametrize("PARAMS", list(product_dict(
                                        processing_elements  = [(8,24)   ],
                                        frequency_mhz        = [ 250     ],
                                        bits_input           = [ 8       ],
                                        bits_weights         = [ 8       ],
                                        bits_sum             = [ 32      ],
                                        bits_bias            = [ 16      ],
                                        max_batch_size       = [ 64      ], 
                                        max_channels_in      = [ 2048    ],
                                        max_kernel_size      = [ 13      ],
                                        max_image_size       = [ 512     ],
                                        ram_weights_depth    = [ 20      ],
                                        ram_edges_depth      = [ 288     ],
                                        axi_width            = [ 128     ],
                                        target_cpu_int_bits  = [ 32      ],
                                        valid_prob           = [ 0.01    ],
                                        ready_prob           = [ 0.1     ],
                                        data_dir             = ['vectors'],
                                    )))
def test_dnn_engine(PARAMS):
    '''
    0. SPECIFY HARDWARE
    '''
    hw = Hardware (**PARAMS)
    hw.export_json()
    hw = Hardware.from_json('hardware.json')
    hw.export() # Generates: config_hw.svh, config_hw.tcl
    hw.export_vivado_tcl(board='zcu104')

    '''
    1. BUILD MODEL
    '''
    XN = 8
    input_shape = (XN,18,18,3) # (XN, XH, XW, CI)

    QINT_BITS = 0
    kq = f'quantized_bits({hw.K_BITS},{QINT_BITS},False,True,1)'
    bq = f'quantized_bits({hw.B_BITS},{QINT_BITS},False,True,1)'
    q1 = f'quantized_relu({hw.X_BITS},{QINT_BITS},negative_slope=0)'    
    q2 = f'quantized_bits({hw.X_BITS},{QINT_BITS},False,False,1)'       
    q3 = f'quantized_bits({hw.X_BITS},{QINT_BITS},False,True,1)'        
    q4 = f'quantized_relu({hw.X_BITS},{QINT_BITS},negative_slope=0.125)'

    x = x_in = QInput(shape=input_shape[1:], batch_size=XN, hw=hw, int_bits=QINT_BITS, name='input')

    x = x_skip1 = Bundle( core= {'type':'conv' , 'filters':8 , 'kernel_size':(11,11), 'strides':(2,1), 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':q1}, pool= {'type':'avg', 'size':(3,4), 'strides':(2,3), 'padding':'same', 'act_str':f'quantized_bits({hw.X_BITS},0,False,False,1)'})(x)
    x = x_skip2 = Bundle( core= {'type':'conv' , 'filters':8 , 'kernel_size':( 1, 1), 'strides':(1,1), 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':q2}, add = {'act_str':f'quantized_bits({hw.X_BITS},0,False,True,1)'})(x, x_skip1)
    x =           Bundle( core= {'type':'conv' , 'filters':8 , 'kernel_size':( 7, 7), 'strides':(1,1), 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':False, 'act_str':q3}, add = {'act_str':f'quantized_bits({hw.X_BITS},0,False,True,1)'})(x, x_skip2)
    x =           Bundle( core= {'type':'conv' , 'filters':8 , 'kernel_size':( 5, 5), 'strides':(1,1), 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':q4}, add = {'act_str':f'quantized_bits({hw.X_BITS},0,False,True,1)'})(x, x_skip1)
    x =           Bundle( core= {'type':'conv' , 'filters':24, 'kernel_size':( 3, 3), 'strides':(1,1), 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':q1},)(x)
    x =           Bundle( core= {'type':'conv' , 'filters':10, 'kernel_size':( 1, 1), 'strides':(1,1), 'padding':'same', 'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':q4}, flatten= True)(x)
    x =           Bundle( core= {'type':'dense', 'units'  :10,                                                           'kernel_quantizer':kq, 'bias_quantizer':bq, 'use_bias':True , 'act_str':q4}, softmax= True)(x)

    model = QModel(inputs=x_in.raw, outputs=x)
    model.compile()
    model.summary()

    '''
    2. TRAIN MODEL
    '''
    # model.fit(...)

    '''
    3. EXPORT FOR INFERENCE
    '''
    model.export_inference(x=model.random_input, hw=hw)
    model.verify_inference(SIM=SIM, SIM_PATH=SIM_PATH)

    print(f"Predicted time on hardware: {1000*model.predict_performance():.5f} ms")