# To add a new cell, type '# %%'
# To add a new markdown cell, type '# %% [markdown]'
# %%
from math import ceil, floor
import torch
import numpy as np
import pandas as pd
import seaborn as sns
from matplotlib import pyplot as plt
sns.set_theme()

from nns_config import kraken_calc_params, alex, res50, vgg16

metrics = ['clocks','efficiency','dx','dk', 'dy', 'd']
# dtypes = [pd.Series(dtype='int'), pd.Series(dtype='float'), pd.Series(dtype='int'), pd.Series(dtype='int'), pd.Series(dtype='int'), pd.Series(dtype='int')]
# dtypes = ['int', 'float', 'int', 'int', 'int', 'int']

def make_col_name(x):
    if isinstance(x, tuple):
        return f'{x[0]}_{x[1]}'
    else:
        return x


# %%
zascad_n = {(11,4): 192, (7,2): 384, (5,1): 384, (3,1):192, (1,1):64 }
zascad_p = {(11,4):  64, (7,2):  32, (5,1):  32, (3,1): 64, (1,1):192}

# %% [markdown]
# # ResNet-50

# %%
designs = ['ZASCAD', 'CARLA', (7,24), (7,96)]
# designs = ['ZASCAD']
net_name = 'resnet-50'
net_config = res50


# %%
col_names = ["layer"] + [f'{make_col_name(design)}_{metric}' for design in designs for metric in metrics ]
# col_dtypes = [pd.Series(dtype='int')] + dtypes*len(designs)
# df.info()


# %%


# df = pd.DataFrame(dict(zip(col_names,col_dtypes)))
df = pd.DataFrame(columns=col_names)
df.set_index("layer")

for j, layer_config in enumerate(net_config):
    _is_conv_, _k_, _s_, _hi_, _ci_, _ho_, _co_ = layer_config

    '''
    Operations
    '''
    _wi_  = _hi_
    _kh_  = _kw_ = _k_
    conv = torch.nn.Conv2d(
        in_channels=1, 
        out_channels=1, 
        kernel_size=_k_, 
        stride=_s_, 
        padding=_k_//2, 
        bias=None
        )
    xt = torch.ones(1,1,_hi_,_wi_)
    kt = torch.ones(1,1,_kh_,_kw_)
    conv.weight.data = kt
    yt = conv(xt)
    sum_non_zero = int(torch.sum(yt))
    layer_ops = sum_non_zero*_ci_*_co_ # operations in the layer

    row = {"layer": j+1}

    for design in designs:
        if design == 'ZASCAD':

            num_pe = 192
            freq   = 200

            n_eff = zascad_n[(_k_,_s_)]
            p_eff = zascad_p[(_k_,_s_)]

            if _is_conv_:

                hf = wf = _k_
                ho = wo = _ho_
                co = _co_
                ci = _ci_
                s  = _s_

                clocks = ceil(wo*ho/n_eff)*(s*n_eff + wf-s)*hf*ci*ceil(co/p_eff) + (wf-1)*(ho-1)*hf*ci*ceil(co/p_eff)

                dx = clocks
                dy = wo*ho*co
                dk = hf*wf*ci*ceil(wo*ho/n_eff)*co
                
            else:
                m = _co_
                n = _ci_

                clocks = ceil(m/p_eff) * n
                
                dx = clocks
                dk = m*n
                dy = m
        
        elif design == 'CARLA':
            num_pe = 196
            freq = 200
            U = 64

            IL = _hi_
            OL = _ho_
            FL = _k_ 
            Z = _k_//2
            OC = K = _co_
            IC = _ci_ 
            
            if FL == 3:
                '''Mode A'''

                P = ceil(OL*OL/224)
                clocks = (3 * OL**2 -2*Z * OL) * IC * ceil(K/U)
                dx = (IL + 2*P -2*Z)*IL*IC*ceil(K/U)
                # dk = 3 * U * Q * ceil(K/U) * P
                dk = pd.NA
                dy = OL**2 * OC
                
            elif _is_conv_ and FL == 1:
                if IL > 7:
                    '''Mode B'''
                    
                    P = ceil(IL*IL/num_pe)
                    clocks = (U+1)*IC*P*ceil(K/U)
                    
                    dx = ceil(OL**2/P)*P * IC * ceil(K/U)
                    dk = U*IC*P*ceil(K/U)
                    dy = OL**2 * OC

                else:
                    '''Mode C'''

                    clocks = U * IC * ceil(K/(3*U))
                    dk = K * FL**2 * IC
                    dx = IL**2 * IC * ceil(K/(3*U))
                    dy = OL**2 * OC
            elif FL == 7:
                '''Mode D'''
                clocks = 6.5e-3 * freq * 1e6
                dk = pd.NA
                dx = pd.NA
                dy = pd.NA
            else:
                clocks = pd.NA
                dk = pd.NA
                dx = pd.NA
                dy = pd.NA

        else:
            '''
            Kraken
            '''
            r, c = design
            eff, q, data_ratio, layer_bytes, p, dx, dk, dy = kraken_calc_params(r,c, layer_config, 1, 1)

            num_pe = r*c
            clocks = q/r

            dx /= r
            dy /= r
            dk /= r

        '''
        Store
        '''

        eff = layer_ops / (clocks*num_pe)
        row.update({
            f'{make_col_name(design)}_clocks': clocks,
            f'{make_col_name(design)}_efficiency': eff,
        })

        # if dx*dy*dk != 0:
        d_tot = dx + dy + dk
        row.update({
            f'{make_col_name(design)}_dx': dx,
            f'{make_col_name(design)}_dk': dk,
            f'{make_col_name(design)}_dy': dy,
            f'{make_col_name(design)}_d': d_tot,
        })
    df = df.append(row, ignore_index=True)
    # print(row)

# df = df.astype(dict(zip(col_names, ['int'] + dtypes*len(designs))))

# df = df.melt('layer', var_name='cols', value_name='vals')


# %%
df.to_pickle(f"{net_name}_layers.pickle")

df


# %%
df_dict = {}
df_dict_melted = {}

for metric in metrics:

    col_names_old = ['layer'] + [make_col_name(design) + '_' + metric for design in designs]
    col_names_new = ['layer'] + [make_col_name(design) for design in designs]

    df_dict[metric] = df[col_names_old]
    df_dict[metric].columns = col_names_new

    df_dict_melted[metric] = df_dict[metric].melt('layer', var_name='Architectures', value_name=metric)


# %%
# # df_dict
# df_dict['efficiency']


# %%
sns.set(rc={"lines.linewidth": 0.7})


# %%
df_melted = df_dict['efficiency'].melt('layer', var_name='Architectures', value_name='Performance Efficiency')

plt.figure(figsize=(18,18))
g = sns.catplot(
    x="layer", 
    y="Performance Efficiency", 
    hue='Architectures', 
    data=df_melted, 
    kind='point'
    )


# %%
x = df_dict['efficiency'].layer

y_zascad = df_dict['efficiency'].ZASCAD
y_carla = df_dict['efficiency'].CARLA
plt.plot(x, y_zascad)
plt.plot(x, y_carla)

plt.show()


# %%



