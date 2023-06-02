import numpy as np
from collections import namedtuple

class Bundle:
    def __init__( self, c, type, **kwargs): #(conv/dense, act, max)
        
        self.c = c
        self.type = type
        self.x = kwargs['x']
        self.w = kwargs['w']
        self.y = kwargs['y']
        self.a = kwargs['a']

        self.r = self.calc_runtime_params(self.c, self.w, self.x, self.y)
        self.r = self.create_headers(self.c, self.r)

        print(self.r)
        self.check_sparsity(self.w, self.x)
        
        self.w_engine = self.reorder_w_q2e_conv(self.w, self.c, self.r)
        self.x_engine = self.reorder_x_q2e_conv(self.x, self.c, self.r)
        self.y_engine = self.reorder_y_q2e_conv(self.y, self.c, self.r)

        self.r = self.r._asdict()
        self.c = self.c._asdict()


    @staticmethod
    def from_qkeras(cd, act, max):

        return {
            'x': cd.prev.y_int,
            'w': cd.k_int,
            'y': cd.y_int,
            'a': act.y_int
        }

    @staticmethod
    def calc_runtime_params(c, w, x, y):

        SW = SH = 1 # for bundle
        KH, KW, CI, CO = w.shape
        print('weights initial (KH, KW, CI, CO) =', w.shape)

        CO_PRL         = c.COLS * SW // KW                        # SW cols are processed in parallel
        EG             = int(np.floor( c.COLS / (KW + SW - 1)))   # elastic groups
        IT             = int(np.ceil( CO / (SW*EG)))              # iterations needed
        CO_PAD         = IT * CO_PRL                              # output cols padded

        print(f'{KH=}, {KW=}, {CI=}, {CO=}, {CO_PRL=}, {EG=}, {IT=}, {CO_PAD}')

        XN, XH, XW, CI = x.shape
        print('initial (XN, XH, XW, CI)=', x.shape)
        SH_OUT, SW_OUT = x.shape[1]//y.shape[1], x.shape[2]//y.shape[2]

        LH     = c.ROWS*SH              # Block height
        L      = int(np.ceil(XH/LH))    # Blocks
        XH_PAD = LH*L
        BRAM_WEIGHTS_ADDR_MAX  = c.CONFIG_BEATS + SW*KH*CI-1

        '''
        Pack all local variables into a namedtuple
        '''
        params = locals()
        params = {k:params[k] for k in params if not ('__' in k or k in ['w', 'x', 'y', 'c', 'params'])}
        r = namedtuple('Runtime', params)(**params)
        return r


    @staticmethod
    def create_headers(c, r):
        '''
        Create headers
        '''
        def pack_bits(arr):
            sum_width = 0
            packed = 0
            for val, width in arr:
                packed |= val << sum_width
                sum_width += width
            return packed
        
        ''' Weights Config'''
        w_config = pack_bits([
            (r.KW//2, c.BITS_KW2),
            (r.CI-1 , c.BITS_CIN_MAX),
            (r.XW-1 , c.BITS_COLS_MAX),
            (r.L -1 , c.BITS_BLOCKS_MAX),
            (r.XN-1 , c.BITS_XN_MAX),
            (r.BRAM_WEIGHTS_ADDR_MAX, c.BITS_BRAM_WEIGHTS_ADDR)
        ])
        w_config = format(w_config, f'#0{c.IN_BITS}b')
        w_config_words = [int(w_config[i:i+c.K_BITS], 2) for i in range(0, len(w_config), c.K_BITS)]
        w_config_words.reverse()
        w_config_words = np.array(w_config_words,dtype=np.int8)
        w_config_words = np.repeat(w_config_words[np.newaxis,...],repeats=r.IT,axis=0)

        '''Input Config'''
        x_config = pack_bits([
            (r.KH//2, c.BITS_KH2),
            (r.CI-1 , c.BITS_CIN_MAX),
            (r.XW-1 , c.BITS_COLS_MAX),
            (r.L -1 , c.BITS_BLOCKS_MAX),
        ])
        assert c.IN_BITS >= c.BITS_KW2 + c.BITS_CIN_MAX + c.BITS_COLS_MAX + c.BITS_BLOCKS_MAX

        x_config = format(x_config, f'#0{c.IN_BITS}b')
        x_config_words = [int(x_config[i:i+c.X_BITS], 2) for i in range(0, len(x_config), c.X_BITS)]
        x_config_words.reverse()

        d = {'w_config':w_config, 'w_config_words':w_config_words, 'x_config':x_config, 'x_config_words': x_config_words}
        n = namedtuple('Runtime', d)(**d)
        r = namedtuple("Runtime", r._fields + n._fields)(*(r + n))
        return r


    @staticmethod
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


    @staticmethod
    def reorder_w_q2e_conv(w, c, r):

        w = np.pad(w, ((0,0),(0,0),(0,0),(0,r.CO_PAD-r.CO)))        # (KH, KW, CI, CO_PAD)
        print(w.shape, (r.KH, r.KW, r.CI, r.IT, r.CO_PRL))
        w = w.reshape(r.KH, r.KW, r.CI, r.IT, r.CO_PRL)             # (KH, KW, CI, IT, CO_PRL)
        w = np.flip(w, axis=4)
        w = w.transpose(0,2,3,4,1)                                  # (KH, CI, IT, CO_PRL, KW)

        w = w.reshape  (r.KH, r.CI, r.IT, r.CO_PRL*r.KW)            # (KH, CI, IT, CO_PRL*KW)
        w = np.pad(w, ((0,0),(0,0),(0,0),(0,c.COLS-r.CO_PRL*r.KW))) # (KH, CI, IT, c.COLS)
        w = w.transpose(2,1,0,3)                                    # (IT, CI, KH, c.COLS)
        w = w.reshape (r.IT, r.CI*r.KH, c.COLS)                       # (IT, CI*KH, c.COLS)
        
        w = np.pad(w, ((0,0),(c.CONFIG_BEATS,0),(0,0)))             # (IT, c.CONFIG_BEATS+CI*KH, c.COLS)
        w = w.reshape (r.IT, (r.CI*r.KH+c.CONFIG_BEATS)*c.COLS)     # (IT, (CI*KH+c.CONFIG_BEATS)*c.COLS)

        w = np.concatenate([r.w_config_words, w], axis=1)             # (IT, 8 + CI*KH*c.COLS)
        assert w.shape == (r.IT, c.IN_BITS/c.K_BITS + (r.CI*r.KH+c.CONFIG_BEATS)*c.COLS)
        return w


    @staticmethod
    def reorder_x_q2e_conv(x, c, r):
        print('input initial (XN, XH, XW, CI)=', x.shape)

        x = np.pad(x, ((0,0),(0,r.XH_PAD-r.XH),(0,0),(0,0)))   # (XN, L*HL , XW, CI)
        x = x.reshape  (r.XN, r.L, r.LH, r.XW, r.CI)               # (XN, L, HL, XW, CI)

        zeros = np.zeros((r.XN,r.L,c.ROWS+c.X_PAD,r.XW,r.CI),x.dtype)  # (XN,L,c.ROWS+X_PAD,XW,CI)
        zeros[:,:,:c.ROWS,:,:] = x

        ''' Fill bot rows from next '''
        for l in range(r.L):
            if l == r.L-1:
                zeros[:,l, c.ROWS: ,:,:] = np.zeros((r.XN,c.X_PAD,r.XW,r.CI),x.dtype)
            else:
                zeros[:,l, c.ROWS: ,:,:] = x[:,l+1,:c.X_PAD,:,:]

        x = zeros                  # (XN,L,c.ROWS+X_PAD,XW,CI)
        x = x.transpose(0,1,3,4,2) # (XN,L,XW,CI,c.ROWS+X_PAD)

        x = x.reshape((r.XN*r.L*r.XW*r.CI*(c.ROWS+c.X_PAD)))
        x = np.concatenate([np.array(r.x_config_words, dtype=np.uint8), x.flatten()])
        assert x.shape == (c.IN_BITS/c.X_BITS + r.XN*r.L*r.XW*r.CI*(c.ROWS+c.X_PAD),)
        return x


    @staticmethod
    def reorder_y_q2e_conv(y, c, r):
        YH, YW = r.XH_PAD//r.SH_OUT, r.XW//r.SW_OUT

        if r.SH_OUT != 1:
            print("Striding not yet supported")
            return None

        y = np.pad(y, ((0,0),(0,r.LH*r.L-r.XH),(0,0),(0,r.CO_PAD-r.CO)))   # (XN, L*HL , XW, CO_PAD)
        y = y.reshape((r.XN, r.L, c.ROWS, r.XW, r.CO_PAD))                 # (XN,L,c.ROWS,XW,CO_PAD)
        y = y.reshape((r.XN, r.L, c.ROWS, r.XW, r.IT, r.CO_PRL))             # (XN,L,c.ROWS,XW,IT,CO_PRL)
        y = y.transpose(4,0,1,3,5,2)                             # (IT,XN,L,XW,CO_PRL,c.ROWS)

        assert y.shape == (r.IT,r.XN,r.L,r.XW,r.CO_PRL,c.ROWS)

        y_w_last = y[:,:,:,-(r.KW//2+1):,:,:]
        y_w_last = y_w_last.transpose(0,1,2,4,3,5).reshape(r.IT,r.XN,r.L,(r.KW//2+1)*r.CO_PRL,c.ROWS)

        y = y.reshape(r.IT,r.XN,r.L,r.XW*r.CO_PRL,c.ROWS)
        y[:,:,:,-(r.KW//2+1)*r.CO_PRL:,:] = y_w_last
        return y