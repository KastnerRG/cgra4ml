import numpy as np
import struct
from PIL import Image

def H_to_float(H):
    a = struct.pack("H",int(bin(H)[2:].zfill(16),2))
    return np.frombuffer(a,dtype = np.float16)[0]

def float_to_H(flt):
    return np.float16(flt).view('H')

def mult(H1,H2):
    a = H_to_float(H1)
    b = H_to_float(H2)
    c = a*b
    H3 = float_to_H(c)
    print("%f (%i) * %f (%i) = %f (%i)"%(a,H1,b,H2,c,H3))
    return (H3)

def add(H1,H2):
    a = H_to_float(H1)
    b = H_to_float(H2)
    c = a+b
    H3 = float_to_H(c)
    print("%f (%i) + %f (%i) = %f (%i)"%(a,H1,b,H2,c,H3))
    return (H3)

def mult_add(H1,H2,H3):
    a = H_to_float(H1)
    b = H_to_float(H2)
    c = H_to_float(H3)
    d = a*b + c
    H4 =float_to_H(d)
    print("%f (%i) * %f (%i) + %f (%i) = %f (%i)"%(a,H1,b,H2,c,H3,d,H4))
    return (H4)



def create_im_feed(npy_arry,conv_units = 8):
    """
    npy_arry   = numpy array with axis order (H,W,C)
    conv_units = number of conv units in a core
    """
    assert len(npy_arry.shape) == 3
    h,w,c  = npy_arry.shape
    blocks = h//conv_units
    im     = np.pad(npy_arry,((1,1),(0,0),(0,0)),mode = 'constant')
    im     = im.astype(np.float16)
    with open('im_feed.txt','w') as f:
        for i in range(blocks):
            temp = im[i*conv_units:(i+1)*conv_units+2,:,:]
            temp = np.transpose(temp,[1,2,0]).flatten()
            for indx,j in enumerate(temp):
                if((i==blocks-1)&(indx==(temp.size-1))):
                    f.write(str(float_to_H(j)))
                else:
                    f.write(str(float_to_H(j))+"\n")
    print('Im_feed.txt file created!')    

# def create_kernel_feed(kernel,bias):
#     """
#     kernel   = numpy array with axis order (H,W,C)
#     """
#     assert len(kernel.shape) == 3
#     h,w,c  = kernel.shape
#     kernel = kernel.astype(np.float16)
#     bias   = bias.astype(np.float16)
#     with open('kernel_feed.txt','w') as f:
#         for i in range(c):
#             temp = kernel[:,:,i].flatten()
#             for j in temp:
#                 f.write(str(float_to_H(j))+'\n')
#             if(i == c-1):
#                 f.write(str(float_to_H(bias)))
#                 # f.write(str(j))
#             else:
#                 f.write(str(float_to_H(bias))+"\n")
#                 # f.write(str(j)+"\n")
#     print('kernel_feed.txt file created!')  
#     print('bias_feed.txt file created!')  

def create_kernel_feed(kernel,bias,mode = 0):
    """
    kernel   = numpy array with axis order (H,W,C) in mode = 0 / axis order (H = 1,W = 1,C,3) in mode = 1
    bias     = numpy array with axis order (1) in mode = 0 / axis order (3) in mode = 1
    """
    if mode: # 1x1
        assert len(kernel.shape) == 4,"Kernel shape is not 4 dimension"
        h,w,c,k  = kernel.shape
        # print(kernel.shape)
        assert ((k == 3) & (h == 1) & (w == 1)),'kernels not suitable for 1x1'
        bias   = bias.astype(np.float16)
        with open('bias_feed.txt','w') as f:
            for i in range(2):
                f.write(str(float_to_H(bias[i]))+'\n')
            f.write(str(float_to_H(bias[2])))
        with open('kernel_feed.txt','w') as f:
            for i in range(c):
                for j in range(3):
                    if( (i == c-1) & (j == 2)):
                        f.write(str(float_to_H(kernel[0,0,i,0]))+'\n')
                        f.write(str(float_to_H(kernel[0,0,i,1]))+'\n')
                        f.write(str(float_to_H(kernel[0,0,i,2])))
                    else:
                        f.write(str(float_to_H(kernel[0,0,i,0]))+'\n')
                        f.write(str(float_to_H(kernel[0,0,i,1]))+'\n')
                        f.write(str(float_to_H(kernel[0,0,i,2]))+'\n')
                
    else:    # 3x3
        assert len(kernel.shape) == 3
        h,w,c  = kernel.shape
        kernel = kernel.astype(np.float16)
        bias   = bias.astype(np.float16)
        with open('bias_feed.txt','w') as f:
            for i in range(2):
                f.write(str(float_to_H(bias))+'\n')
            f.write(str(float_to_H(bias)))
        with open('kernel_feed.txt','w') as f:
            for i in range(c):
                temp = kernel[:,:,i].flatten()
                for indx,j in enumerate(temp):
                    if((i == c-1)&(indx == 8)):
                        f.write(str(float_to_H(j)))
                        # f.write(str(j))
                    else:
                        f.write(str(float_to_H(j))+'\n')
                        # f.write(str(j)+"\n")
                
    
    print('kernel_feed.txt file created!')  
    print('bias_feed.txt file created!')  


def create_im_kernel_feed(kernel,bias,image,conv_units = 8,mode = 0):
    create_kernel_feed(kernel,bias,mode)
    create_im_feed(image,conv_units)

# def recreate_im_from_file(op_shape,file = "sim_output.txt",conv_units = 8):
#     """
#     file       = name of the file
#     conv_units = number of convolution units in a core
#     op_shape   = shape of the output (H,W)
#     """

#     with open("sim_output.txt",'r') as f:
#         s = f.read()
    
#     s      = s.strip().split('\n')
#     s      = np.array([H_to_float(int(i)) for i in s])
#     # s      = np.array([int(i) for i in s])
#     blocks = op_shape[0]//conv_units
#     im     = np.empty((0,op_shape[1]))
#     for i in range(blocks):
#         temp = s[i*op_shape[1]*conv_units:(i+1)*op_shape[1]*conv_units]
#         temp = np.reshape(temp,(conv_units,op_shape[1]),order = 'F')
#         im   = np.concatenate((im,temp),axis = 0)
#     return im

def recreate_im_from_file(op_shape,file = "sim_output.txt",conv_units = 8,mode = 0):
    """
    file       = name of the file
    conv_units = number of convolution units in a core
    op_shape   = shape of the output (H,W)
    mode       = 0: 3x3 , 1: 1x1
    """

    with open(file,'r') as f:
        s = f.read()
    
    s      = s.strip().split('\n')
    s      = np.array([H_to_float(int(i)) for i in s])
    # s      = np.array([int(i) for i in s])
    blocks = op_shape[0]//conv_units
    if mode: # 1x1
        ss = np.reshape(s,(-1,op_shape[1],3,conv_units))
        im     = np.empty((0,op_shape[1],3))
        for i in range(blocks):
            im   = np.concatenate((im,ss[i,:,:,:]),axis = 0)
        im = np.flip(im,axis=2)
        im = np.transpose(im,(2,0,1))
    else:    # 3x3
        im     = np.empty((0,op_shape[1]))
        for i in range(blocks):
            temp = s[i*op_shape[1]*conv_units:(i+1)*op_shape[1]*conv_units]
            temp = np.reshape(temp,(conv_units,op_shape[1]),order = 'F')
            im   = np.concatenate((im,temp),axis = 0)
    
    return im.astype(np.float16)


def pad_image(im):
    return np.pad(im,((1,1),(1,1),(0,0)))

def conv_2D(kernel,bias,image,padded=True):
    image = np.transpose(image,[2,0,1])
    kernel = np.transpose(kernel,[2,0,1])
    ch     = kernel.shape[0]
    k      = kernel.shape[1]
    bias   = np.float16(bias)

    H = image.shape[1]
    W = image.shape[2]
    if(padded):
        padded_im = np.pad(image,((0,0),(1,1),(1,1)))
        final     = np.zeros((1,H,W),dtype=np.float16)
    else:
        padded_im = image
        if(k==3):
            final     = np.zeros((1,H-2,W-2),dtype=np.float16)
        else:
            final     = np.zeros((1,H,W),dtype=np.float16)
    Hf = final.shape[1]
    Wf = final.shape[2]

    for i in range(0,Hf):
        for j in range(0,Wf):
            if(k==3):
                final[0][i][j] = np.sum(kernel*padded_im[:,i:i+3,j:j+3])
            else:
                final[0][i][j] = np.sum(kernel*image[:,i,i])
    final += bias
    return final