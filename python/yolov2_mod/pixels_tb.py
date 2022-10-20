# To add a new cell, type '# %%'
# To add a new markdown cell, type '# %% [markdown]'
# %%
UNITS = 7
K = 11
S = 4
W = 4
CIN = 2
H = UNITS*S*2
is_max = 0
is_not_max = 1
is_relu = 1

import numpy as np


# %%
'''(H,W,CIN)'''
a = np.arange(H).reshape(H,1,1) + 100*np.arange(CIN).reshape(1,1,CIN) + 25*np.arange(W).reshape(1,W,1)
assert a.shape == (H,W,CIN)

MAX_FACTOR = is_max+1

'''(L,MRS,W,CIN)'''
BH = MAX_FACTOR*UNITS*S
L = H//BH
a = a.reshape(L,BH,W,CIN)

'''(L,S(MR+F),W,CIN)'''
SHIFT = int(np.ceil(K/S)-1)
WORDS = MAX_FACTOR*UNITS + SHIFT

zeros = np.zeros((L,S*WORDS,W,CIN),a.dtype)
top_edges = K//2
bot_edges = S*WORDS - top_edges - BH

zeros[:,top_edges:S*WORDS-bot_edges,:,:] = a

for l in range(L):
    ''' Fill top rows from prev '''
    if l == 0:
        zeros[l,:top_edges,:,:] = np.zeros((1,top_edges,W,CIN),a.dtype)
    else:
        zeros[l,:top_edges,:,:] = a[l-1,BH-top_edges:,:,:]

    ''' Fill bot rows from next '''
    if l == L-1:
        zeros[l,S*WORDS-bot_edges:,:,:] = np.zeros((1,bot_edges,W,CIN),a.dtype)
    else:
        zeros[l,S*WORDS-bot_edges:,:,:] = a[l+1,:bot_edges,:,:]
a = zeros

'''(L,W,CIN,S,MR+F)'''
a = a.reshape(L,WORDS,S,W,CIN)
a = a.transpose(0,3,4,2,1)


# %%
a.shape


# %%
a[1,0,0,0,:]


# %%
BITS_KH2 = 3
BITS_KW2 = 3
BITS_SH  = 2
BITS_SW  = 2

config = 0
config |= is_not_max
config |= is_max  << 1
config |= is_relu << 2
config |= (K//2)  << 3
config |= (K//2)  << 3 + BITS_KH2
config |= (S-1 )  << 3 + BITS_KH2 + BITS_KW2
config |= WORDS   << 3 + BITS_KH2 + BITS_KW2 + BITS_SH

c = np.concatenate([np.frombuffer(np.array(config, dtype=np.uint64).tobytes(), np.uint8), a.flatten()])

np.savetxt("D:/cnn-fpga/data/im_in_text.txt", c, fmt="%d")


# %%



