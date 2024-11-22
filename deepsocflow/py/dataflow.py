import numpy as np
from collections import namedtuple

from deepsocflow.py.utils import *

def get_runtime_params(hw, w_shape, x_shape, o_shape, core, pool, flatten):

    KH, KW, CI, CO = w_shape
    print('weights initial (KH, KW, CI, CO) =', w_shape)

    CO_PRL         = hw.COLS // KW                        # SW cols are processed in parallel
    EG             = int(np.floor( hw.COLS / KW))         # elastic groups
    IT             = int(np.ceil( CO / EG))              # iterations needed
    CO_PAD         = IT * CO_PRL                         # output cols padded
    
    CM             = (hw.RAM_WEIGHTS_DEPTH - hw.CONFIG_BEATS)//KH  # (available rows in weights ram)/KH
    CP             = int(np.ceil(CI / CM))                        # Number of passes required
    CM_0           = CM if (CI%CM==0) else (CI%CM)                # CM of p=0

    print(f'KH={KH}, KW={KW}, CI={CI}, CO={CO}, CO_PRL={CO_PRL}, EG={EG}, IT={IT}, CO_PAD={CO_PAD}, CM={CM}, CP={CP}')

    XN, XH, XW, CI = x_shape
    print('input initial (XN, XH, XW, CI)=', x_shape)

    XL  = int(np.ceil(XH/hw.ROWS))    # Blocks
    YN, YH, YW, YC = XN, XH, XW, CO

    X_PAD = 0 if KH == 1 else hw.X_PAD_MAX

    '''
    Conv Striding
    '''
    if core.type == 'conv':
        CSH, CSW = core.strides
        assert XH > KH//2
        assert XW > KW//2
    else:
        CSH, CSW = 1,1

    CYH, CYW = int(np.ceil(XH/CSH)), int(np.ceil(XW/CSW))
    
    CSH_SHIFT, CSW_SHIFT = 0,0
    if core.type == 'conv':
        if core.padding == "same":
            CSH_SHIFT = (KH-1)//2 - max((CSH*(CYH-1)+KH-XH)//2, 0)
            CSW_SHIFT = (KW-1)//2 - max((CSW*(CYW-1)+KW-XW)//2, 0)
        print(f"out after (strides:{CSH, CSW}, mode:{core.padding}) CONV_STRIDING: (XN, CYH, CYW, CO)={(XN, CYH, CYW, CO)}")

        YH, YW = CYH, CYW


    '''
    Pooling
    '''
    PKH = PKW = PSH = PSW = 1
    PSH_SHIFT = PSW_SHIFT = 0
    PYH, PYW = YH, YW

    if pool is not None:
        PKH, PKW = pool.pool_layer.pool_size
        PSH, PSW = pool.pool_layer.strides

        if pool.pool_layer.padding=="same":
            PYH = (YH+PSH-1)//PSH
            PYW = (YW+PSW-1)//PSW
            PSH_SHIFT = max((PSH*(PYH-1)+PKH-YH)//2, 0)
            PSW_SHIFT = max((PSW*(PYW-1)+PKW-YW)//2, 0)
            print("pool mode: ", pool.pool_layer.padding)
        else:
            PYH = (YH-PKH+PSH)//PSH
            PYW = (YW-PKW+PSW)//PSW
    
    YH, YW = PYH, PYW
    print(f"out after (strides:{(PSH,PSW)}, sizes:{(PKH, PKW)}) POOLING: (XN, PYH, PYW, CO)={(XN, YH, YW, CO)}")

    YL  = int(np.ceil(YH/hw.ROWS))    # Blocks
    ON, OH, OW, OC = YN, YH, YW, YC

    if flatten:
        YH, YW, YC = 1, 1, YH*YW*YC
        ON, OH, OW, OC = 1, YN, YW, YC # Bundle flatten N,H -> 1,N

    
    if core.type == 'conv' and not flatten:
        assert o_shape == (XN, YH, YW, CO), f"{o_shape=}, {(XN, YH, YW, CO)=}"
    
    print('final output', o_shape)

    '''
    Pack all local variables into a namedtuple
    '''
    params = locals()
    params = {k:params[k] for k in params if not ('__' in k or k in ['w', 'x', 'y', 'hw', 'core', 'pool', 'params'])}
    print (params)
    r = namedtuple('Runtime', params)(**params)
    return r


def create_headers(hw, r):
    '''
    Create headers
    '''
    def pack_bits(arr, total):
        sum_width = 0
        packed = 0
        for val, width in arr:
            packed |= val << sum_width
            sum_width += width
        assert sum_width <= total, f"Number of total packed bits {sum_width} is more than input DMA width {total}"
        return np.array([packed],dtype=np.uint64)[0]
    
    d = {}
    d['header'] = pack_bits([
            (r.KW//2  , hw.BITS_KW2),
            (r.XW-1   , hw.BITS_COLS_MAX),
            (r.XL-1   , hw.BITS_BLOCKS_MAX),
            (r.CM_0-1 , hw.BITS_CIN_MAX),
            (r.CM-1   , hw.BITS_CIN_MAX),
            (r.XN-1   , hw.BITS_XN_MAX),
            (hw.CONFIG_BEATS + r.KH*r.CM_0-1, hw.BITS_RAM_WEIGHTS_ADDR),
            (hw.CONFIG_BEATS + r.KH*r.CM-1, hw.BITS_RAM_WEIGHTS_ADDR),
        ], hw.HEADER_WIDTH)

    
    n = namedtuple('Runtime', d)(**d)
    r = namedtuple("Runtime", r._fields + n._fields)(*(r + n))
    return r



def check_sparsity(w, x):
    w_sparse = (w==0).sum()/w.size
    x_sparse = (x==0).sum()/x.size

    p_both_zero = x_sparse * w_sparse
    p_only_one_zero = (1-x_sparse) * w_sparse  +  (1-w_sparse) * x_sparse
    p_neither_zero = (1-x_sparse) * (1-w_sparse)
    zero_result = 1-p_neither_zero

    print(f'''
    w_sparsity   : {w_sparse*100:.2f}%
    x_sparsity   : {x_sparse*100:.2f}%

    both_zero    : {p_both_zero*100:.2f}%
    only_one_zero: {p_only_one_zero*100:.2f}%
    neither_zero : {p_neither_zero*100:.2f}%
    zero_result  : {zero_result*100:.2f}%
    ''')



def reorder_b_q2e_conv(b, hw, r):
    b = np.pad(b, ((0,r.CO_PAD-r.CO)))
    b = b.reshape(r.IT, r.CO_PRL)
    return b



def reorder_w_q2e_conv(w, hw, r):
    # (KH, KW, Ci, CO)
    w = np.pad(w, ((0,0),(0,0),(0,0),(0,r.CO_PAD-r.CO)))        # (KH, KW, CI, CO_PAD)
    w = w.reshape(r.KH, r.KW, r.CI, r.IT, r.CO_PRL)             # (KH, KW, CI, IT, CO_PRL)
    w = np.flip(w, axis=4)                                      # cuz we shift outputs towards right in PE array and read from high col

    w = w.transpose(0,2,3,4,1)                                  # (KH, CI, IT, CO_PRL, KW)
    w = w.reshape  (r.KH, r.CI, r.IT, r.CO_PRL*r.KW)            # (KH, CI, IT, CO_PRL*KW)
    w = np.pad(w, ((0,0),(0,0),(0,0),(0,hw.COLS-r.CO_PRL*r.KW))) # (KH, CI, IT, hw.COLS)
    w = w.transpose(2,1,0,3)                                    # (IT, CI, KH, hw.COLS)

    w_list = []
    ic_left = ic_right = 0
    for ip in range(r.CP):
        CM_p = r.CM_0 if ip==0 else r.CM
        ic_right += CM_p

        wp = w[:, ic_left:ic_right, :,:]
        wp = wp.reshape (r.IT, CM_p*r.KH, hw.COLS)                # (IT, CM*KH, hw.COLS)
        wp = np.pad(wp, ((0,0),(hw.CONFIG_BEATS,0),(0,0)))        # (IT, hw.CONFIG_BEATS+CM*KH, hw.COLS)
        assert wp.shape == (r.IT, CM_p*r.KH +hw.CONFIG_BEATS, hw.COLS)
        
        words_per_byte = 8//hw.K_BITS
        wp = wp.reshape(r.IT,-1)
        pad = words_per_byte-(wp[0].size%words_per_byte)
        pad = 0 if pad == words_per_byte else pad
        wp = np.pad(wp, ((0,pad),(0,0)))

        w_list += [wp]
        ic_left = ic_right
    return w_list



def reorder_x_q2e_conv(x, hw, r):
    print('input initial (XN, XH, XW, CI)=', x.shape)

    x = np.pad(x, ((0,0),(0,r.XL*hw.ROWS-r.XH),(0,0),(0,0)))         # (XN, L*HL , XW, CI)
    x = x.reshape  (r.XN, r.XL, hw.ROWS, r.XW, r.CI)                   # (XN, XL, HL, XW, CI)

    zeros = np.zeros((r.XN,r.XL,hw.ROWS+r.X_PAD,r.XW,r.CI),x.dtype)  # (XN,XL,hw.ROWS+X_PAD,XW,CI)
    zeros[:,:,:hw.ROWS,:,:] = x

    ''' Fill bot rows from next '''
    for l in range(r.XL):
        if l == r.XL-1:
            zeros[:,l, hw.ROWS: ,:,:] = np.zeros((r.XN,r.X_PAD,r.XW,r.CI),x.dtype)
        else:
            zeros[:,l, hw.ROWS: ,:,:] = x[:,l+1,:r.X_PAD,:,:]

    x = zeros                                                  # (XN,XL,hw.ROWS+X_PAD,XW,CI)
    x = x.transpose(0,1,3,4,2)                                 # (XN,XL,XW,CI,hw.ROWS+X_PAD)
    x = x.reshape((r.XN, r.XL, r.XW, r.CI, (hw.ROWS+r.X_PAD)))

    x_list = []
    ic_left = ic_right = 0
    for ip in range(r.CP):
        CM_p = r.CM_0 if ip==0 else r.CM
        ic_right += CM_p

        xp = x[:,:,:, ic_left:ic_right, :]                              #(XN, XL, XW, CM, (hw.ROWS+r.X_PAD))
        assert xp.shape == (r.XN, r.XL, r.XW, CM_p, (hw.ROWS+r.X_PAD))

        xp = xp.flatten()
        words_per_byte = 8//hw.X_BITS
        pad = words_per_byte-(xp.size%words_per_byte)
        pad = 0 if pad == words_per_byte else pad
        xp = np.pad(xp, ((0,pad)))

        x_list += [xp]
        ic_left = ic_right
    return x_list



def reorder_y_q2e_conv(y, hw, r):
    '''
    This is engine output: no striding (H=H, L=XL), last W interchanged
    '''

    y = np.pad(y, ((0,0),(0,hw.ROWS*r.XL-r.XH),(0,0),(0,r.CO_PAD-r.CO)))  # (XN, XL*ROWS , XW, CO_PAD)
    y = y.reshape((r.XN, r.XL, hw.ROWS, r.XW, r.CO_PAD))                  # (XN,XL,hw.ROWS,XW,CO_PAD)
    y = y.reshape((r.XN, r.XL, hw.ROWS, r.XW, r.IT, r.CO_PRL))            # (XN,XL,hw.ROWS,XW,IT,CO_PRL)
    y = y.transpose(4,0,1,3,5,2)                                         # (IT,XN,XL,XW,CO_PRL,hw.ROWS)

    assert y.shape == (r.IT,r.XN,r.XL,r.XW,r.CO_PRL,hw.ROWS)

    y_w_last = y[:,:,:,-(r.KW//2+1):,:,:]
    y_w_last = y_w_last.transpose(0,1,2,4,3,5).reshape(r.IT,r.XN,r.XL,(r.KW//2+1)*r.CO_PRL,hw.ROWS)

    y = y.reshape(r.IT,r.XN,r.XL,r.XW*r.CO_PRL,hw.ROWS)
    y[:,:,:,-(r.KW//2+1)*r.CO_PRL:,:] = y_w_last
    return y


def reorder_y_e2q_conv(y, hw, r):
    '''
    This is engine output: no striding (H=H, L=XL), last W interchanged
    '''
    y = y.reshape(r.IT,r.XN,r.XL,r.XW*r.CO_PRL,hw.ROWS)

    y_w_last = y[:,:,:,-(r.KW//2+1)*r.CO_PRL:,:]
    y_w_last = y_w_last.reshape(r.IT,r.XN,r.XL,r.CO_PRL,(r.KW//2+1),hw.ROWS)
    y_w_last = y_w_last.transpose(0,1,2,4,3,5)   #(r.IT,r.XN,r.XL,(r.KW//2+1),r.CO_PRL,hw.ROWS)
    y_w_last = y_w_last.reshape(r.IT,r.XN,r.XL,(r.KW//2+1),r.CO_PRL,hw.ROWS)
    y_w_last = y_w_last.reshape(r.IT,r.XN,r.XL,(r.KW//2+1)*r.CO_PRL,hw.ROWS)
    
    y[:,:,:,-(r.KW//2+1)*r.CO_PRL:,:] = y_w_last

    y = y.reshape(r.IT,r.XN,r.XL,r.XW,r.CO_PRL,hw.ROWS)
    y = y.transpose(1,2,5,3,0,4)
    y = y.reshape((r.XN, r.XL*hw.ROWS, r.XW, r.CO_PAD))
    y = y[:,:r.XH,:,:r.CO]

    return y


def pack_words_into_bytes (arr, bits):
    assert 8 % bits == 0, f"Bits {bits} should be factor of 8 for packing"
    w_words_per_byte = 8//bits
    arr = np.frombuffer(arr.astype(np.int8).tobytes(), dtype=np.uint8)
    arr = arr % 2**bits
    arr = arr.reshape(arr.size//w_words_per_byte, w_words_per_byte)
    for i_word in range(1, w_words_per_byte):
        arr[:,0] += arr[:,i_word] << (i_word * bits) # pack multiple words into a byte
    return arr[:,0].astype(np.uint8) # packed byte


def predict_bundle_performance(hw, r):

    clocks_p0 = r.IT*(1 + r.XN*r.XL*r.XW*(1 + r.CM_0*r.KH))
    clocks_p  = r.IT*(1 + r.XN*r.XL*r.XW*(1 + r.CM*r.KH))

    mem_bits_p0 = \
        hw.X_BITS * (r.IT * r.XN   * r.XL * r.XW * r.CM_0 * (hw.ROWS + r.X_PAD-1)) +\
        hw.K_BITS * (r.IT * r.CM_0 * r.KH * hw.COLS) +\
        hw.X_BITS * (r.XN * r.XH   * r.XW * r.CO)
    mem_bits_p = \
        hw.X_BITS * (r.IT * r.XN   * r.XL * r.XW * r.CM   * (hw.ROWS + r.X_PAD-1)) +\
        hw.K_BITS * (r.IT * r.CM_0 * r.KH * hw.COLS) +\
        hw.X_BITS * (r.XN * r.XH   * r.XW * r.CO)

    '''
    Accurate mem access (output):
        - baseline: next bundle input + padding
        - p_add   - write & read
        - pooling - write & read
        - softmax - write & read
    '''

    clocks    = clocks_p0 + (r.CP-1)*clocks_p
    mem_bits  = mem_bits_p0 + (r.CP-1)*mem_bits_p

    operations = (r.XN * r.XH * r.XW * r.CI) * (r.KH * r.KW * r.CO)
    utilization = operations / (hw.ROWS * hw.COLS * clocks)


    return clocks, mem_bits, utilization, operations


def predict_model_performance(hw):

    d_out = {
        'operations': [],
        'utilization_all': [],
        'clocks_all': [],
        'mem_bytes_all': [],
    }
    for b in BUNDLES:
        clocks, mem_bits, utilization, operations = predict_bundle_performance(hw=hw, r=b.r)
        d_out['operations'] += [operations]
        d_out['utilization_all'] += [utilization]
        d_out['clocks_all'] += [clocks]
        d_out['mem_bytes_all'] += [mem_bits/8]

        print(f'---{b.ib}: util:{100*utilization:.2f} mem_mb:{mem_bits/1024**2:.2f} {b.r.XN=} {b.r.XH=} {b.r.XW=} {b.r.CI=} {b.r.CO=} {b.r.KH=} {b.r.KW=}')
    
    d_out['g_ops'] = sum(d_out['operations'])/1e9
    d_out['clocks_total'] = sum(d_out['clocks_all'])
    d_out['mem_bytes_total'] = sum(d_out['mem_bytes_all'])

    d_out['seconds_per_batch'] = d_out['clocks_total'] / (hw.FREQ * 1e6)
    d_out['frames_per_sec'] = hw.ROWS / d_out['seconds_per_batch']
    d_out['ms_per_frame'] = 1000 / d_out['frames_per_sec']

    with open('util.txt', 'w') as f:
        for line in d_out['utilization_all']:
            f.write(f"{line}\n")

    with open('mem_bytes.txt', 'w') as f:
        for line in d_out['mem_bytes_all']:
            f.write(f"{line}\n")

    return d_out