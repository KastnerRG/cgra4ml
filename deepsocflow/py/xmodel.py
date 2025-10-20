import tensorflow as tf
from tensorflow import keras
from keras.layers import Layer
from qkeras import *
import os
from copy import deepcopy
import json

from deepsocflow.py.utils import *
from deepsocflow.py.xbundle import *
from deepsocflow.py.xlayers import *
from deepsocflow.py.hardware import *
from deepsocflow.py.dataflow import *



class XInputAct(QActivation):
    def __init__(self, *args, **kwargs):            
        super().__init__(*args, **kwargs)
    
    def call(self, x):
        return super().call(x)

@keras.saving.register_keras_serializable()
class XModel(Layer):

    def __init__(self, sys_bits, x_int_bits, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.sys_bits = sys_bits
        self.x_int_bits = x_int_bits
        self.input_quant_layer = XInputAct(f'quantized_bits({sys_bits.x},{x_int_bits},False,True,1)')

    def get_config(self):
        config = super().get_config().copy()
        config.update({
            'sys_bits': self.sys_bits,
            'x_int_bits': self.x_int_bits,
        })
        return config
    


def export_inference(model, hw, batch_size=1):
    
    for b in BUNDLES:
        b.next_ibs.clear()
        b.next_add_ibs.clear()
    BUNDLES.clear()
        
    user_model = model.layers[1]
    input_shape = (batch_size, *model.inputs[0].shape[1:])
    x_keras = tf.random.uniform(input_shape)
    x_qtensor = user_model.input_quant_layer(x_keras)
    out_keras = model(x_keras)

    assert hw.X_BITS == user_model.sys_bits.x
    assert hw.K_BITS == user_model.sys_bits.k
    assert hw.B_BITS >= user_model.sys_bits.b

    for i, b in enumerate(BUNDLES):
        print(f"Bundle {i}: {b}")

    x = XTensor(tensor=x_qtensor, bits=hw.X_BITS, int=user_model.x_int_bits)   


    '''
    Export
    '''
    
    
    ''' Clean the data directory'''
    os.makedirs(hw.DATA_DIR, exist_ok=True)
    for file in os.scandir(hw.DATA_DIR):
        os.remove(file.path)
    

    print("\n-----------STARTING EXPORT-----------\n")


    add_buffer_map = []
    out_buffer_map = []

    for ib, b in enumerate(BUNDLES):
        print(f'-----------------ib:{ib}-----------------------')
        b.call_int(x if ib==0 else None, hw)
        b.export(hw, False)
   
        '''
        OUTPUT BUFFER ALLOCATION
        '''
        print(f'input_out_map:{out_buffer_map}')

        '''Find and assign a free buffer. If not, add new buffer'''
        b.out_buffer_idx = -1
        next_ibs = sorted(deepcopy(b.next_ibs))
        if len(next_ibs) != 0:
            for im in range(len(out_buffer_map)):
                if out_buffer_map[im] is None:
                    out_buffer_map[im] = {'in':b.ib, 'out':next_ibs}
                    b.out_buffer_idx = im
                    break
            else: #m if break is not hit
                b.out_buffer_idx = len(out_buffer_map)
                out_buffer_map += [{'in':b.ib, 'out':next_ibs}]
        
        print('out_buffer_idx:', b.out_buffer_idx)

        '''Free the buffers whose last destination is current bundle'''
        for im in range(len(out_buffer_map)):
            buf = out_buffer_map[im]
            if buf is not None:
                if buf['out'][-1] == b.ib:
                    out_buffer_map[im] = None

        print(f'out_buffer_map:{out_buffer_map}')


        
        '''
        ADD BUFFER ALLOCATION
        '''
        print(f'input_add_map:{add_buffer_map}')

        '''Find and assign a free buffer. If not, add new buffer'''
        b.add_out_buffer_idx = -1
        if len(b.next_add_ibs) != 0:
            for im in range(len(add_buffer_map)):
                if add_buffer_map[im] is None:
                    add_buffer_map[im] = {'in':b.ib, 'out':b.next_add_ibs}
                    b.add_out_buffer_idx = im
                    break
            else: #m if break is not hit
                b.add_out_buffer_idx = len(add_buffer_map)
                add_buffer_map += [{'in':b.ib, 'out':b.next_add_ibs}]
        
        print('add_out_buffer_idx:', b.add_out_buffer_idx)

        '''Free the buffers whose last destination is current bundle'''
        for im in range(len(add_buffer_map)):
            buf = add_buffer_map[im]
            if buf is not None:
                if buf['out'][-1] == b.ib:
                    add_buffer_map[im] = None

        print(f'add_buffer_map:{add_buffer_map}')     


    d_perf = predict_model_performance(hw=hw)
    print(f"Predicted performance: {d_perf}")

    '''
    Write Runtime Headers
    '''
    x_bytes_all = x_bytes = w_bytes = b_words = x_bytes_max = nhwc_words_max = o_bytes_max = o_words_max = 0
    with open (f'./config_fw.h', 'w') as ch:

        ch.write(f"#define N_BUNDLES {len(BUNDLES)}\n")
        ch.write(f"Bundle_t bundles [N_BUNDLES] = {{\n")
        
        for ib, b in enumerate(BUNDLES):
            assert ib == b.ib

            w_bpt    = (hw.K_BITS*b.we[-1][0].size)//8
            w_bpt_p0 = (hw.K_BITS*b.we[0][0].size)//8
            x_bpt    = (hw.X_BITS*b.xe[-1].size)//8 
            x_bpt_p0 = (hw.X_BITS*b.xe[0].size )//8
            
            if ib == len(BUNDLES)-1:
                o_words_b = b.o_int.size
                o_bytes_b = o_words_b*4 # int or float
                o_words = o_words_b
            else:
                b_next    = BUNDLES[ib+1]
                o_wpt     = b_next.xe[-1].size
                o_wpt_p0  = b_next.xe[0].size
                o_words_b = o_wpt_p0 + (b_next.r.CP-1)*o_wpt

                o_bpt = (hw.X_BITS*b_next.xe[-1].size)//8
                o_bpt_p0 = (hw.X_BITS*b_next.xe[0].size)//8
                o_bytes_b = o_bpt_p0 + (b_next.r.CP-1)*o_bpt

            xp_words  = b.r.XN * b.r.XL * b.r.XW * (hw.ROWS+b.r.X_PAD)

            w_bytes_b = (w_bpt_p0 + (b.r.CP-1)*w_bpt)*b.r.IT
            x_bytes_b = (x_bpt_p0 + (b.r.CP-1)*x_bpt)
            nhwc_words_b = b.r.XN * b.r.XH * b.r.XW * b.r.CO

            x_bytes_max = max(x_bytes_max, x_bytes_b)
            nhwc_words_max = max(nhwc_words_max, nhwc_words_b)
            o_bytes_max = max(o_bytes_max, o_bytes_b)
            o_words_max = max(o_words_max, o_words_b)
            w_bytes += w_bytes_b
            x_bytes_all += x_bytes_b

            ib_out = -1 if len(b.next_ibs) == 0 else sorted(b.next_ibs)[0]

            if ib == 0:
                x_bytes = (x_bpt_p0 + (b.r.CP-1)*x_bpt)

            y_coe = b.r.CO_PRL
            y_coe_tl = b.r.CO_PRL if (b.r.CO==b.r.IT*b.r.CO_PRL) else b.r.CO%b.r.IT
            y_r_ll = hw.ROWS if b.r.XH==b.r.XL*hw.ROWS else  b.r.XH % hw.ROWS

            ca_nzero, ca_shift, ca_pl_scale = b.core.act.non_zero, b.core.act.shift_bits, b.core.act.plog_slope

            (aa_nzero, aa_shift, aa_pl_scale) = (b.add .act.non_zero, b.add .act.shift_bits, b.add .act.plog_slope)if b.add  is not None else (0,0,0)
            (pa_nzero, pa_shift, pa_pl_scale) = (b.pool.act.non_zero, b.pool.act.shift_bits, b.pool.act.plog_slope)if b.pool is not None else (0,0,0)

            add_out_buffer_idx = b.add_out_buffer_idx
            add_in_buffer_idx = BUNDLES[b.add.source_ib].add_out_buffer_idx if b.add is not None else -1
            in_buffer_idx = BUNDLES[b.prev_ib].out_buffer_idx if b.prev_ib is not None else -1

            if b.pool is None:
                pool_type = 'POOL_NONE'
            elif b.pool.type == 'max':
                pool_type = 'POOL_MAX'
            elif b.pool.type == 'avg':
                pool_type = 'POOL_AVG'

            out_type = 'float' if (ib == len(BUNDLES)-1 and b.softmax) else 'int32_t'

            ch.write(f"   {{.n={b.r.XN:<3}, .l={b.r.XL:<3}, .kw={b.r.KW:<3}, .coe={y_coe:<3}, .h={b.r.XH:<3}, .w={b.r.XW:<3}, .ci={b.r.CI:<4}, .co={b.r.CO:<4}, .w_kw2={b.r.XW-b.r.KW//2:<3}, .t={b.r.IT:<3}, .p={b.r.CP:<3}, .cm={b.r.CM:<3}, .cm_p0={b.r.CM_0:<3}, .on={b.r.ON:<3}, .oh={b.r.OH:<3}, .ow={b.r.OW:<3}, .oc={b.r.OC:<4}, .ch={b.r.CYH:<3}, .ph={b.r.PYH:<3}, .cw={b.r.CYW:<3}, .pw={b.r.PYW:<3}, .pkh={b.r.PKH:<3}, .psh={b.r.PSH:<3}, .pkw={b.r.PKW:<3}, .psw={b.r.PSW:<3}, ")
            ch.write(     f".xp_words={xp_words:<6}, .b_offset={b_words:<5}, .w_bpt={w_bpt:<5}, .w_bpt_p0={w_bpt_p0:<5}, .x_bpt={x_bpt:<8}, .x_bpt_p0={x_bpt_p0:<8}, .o_words={o_words_b:<8}, .o_bytes={o_bytes_b:<8}, ")
            ch.write(     f".ib_out={ib_out:<4}, .in_buffer_idx={in_buffer_idx:<3}, .out_buffer_idx={b.out_buffer_idx:<3}, .add_out_buffer_idx={add_out_buffer_idx:<2}, .add_in_buffer_idx={add_in_buffer_idx:<2}, ")
            ch.write(     f".is_bias={1*(b.core.b is not None):<3}, .is_flatten={1*(b.flatten is not None):<3}, .is_softmax={1*(b.softmax is not None):<3}, ")
            ch.write(     f".x_pad={b.r.X_PAD:<3}, .b_val_shift={b.core.bias_val_shift:<3}, .b_bias_shift={b.core.bias_b_shift:<3}, .ca_nzero={ca_nzero:<3}, .ca_shift={ca_shift:<3}, .ca_pl_scale={ca_pl_scale:<3}, .aa_nzero={aa_nzero:<3}, .aa_shift={aa_shift:<3}, .aa_pl_scale={aa_pl_scale:<3}, .pa_nzero={pa_nzero:<3}, .pa_shift={pa_shift:<3}, .pa_pl_scale={pa_pl_scale:<3}, .softmax_frac={b.softmax_frac:<3}, ")
            ch.write(     f".csh={b.r.CSH:<3}, .csh_shift={b.r.CSH_SHIFT:<3}, .psh_shift={b.r.PSH_SHIFT:<3}, .csw={b.r.CSW:<3}, .csw_shift={b.r.CSW_SHIFT:<3}, .psw_shift={b.r.PSW_SHIFT:<3}, .pool={pool_type:<10}, ")
            ch.write(     f".softmax_max_f={b.softmax_max_f:<15}, ")
            ch.write(     f".header={b.r.header:>23}u, ")
            ch.write(     f".debug_nhwc_words={b.oe_exp_nhwc.size:<9} }}")
            
            b_words += b.be.size if b.core.b else 0
            if b.ib != len(BUNDLES)-1:
                ch.write(',\n')


        ch.write(f"\n}};\n\n")
        ch.write(f"#define X_BITS_L2   {int(np.log2(hw.X_BITS))}\n")
        ch.write(f"#define W_BITS_L2   {int(np.log2(hw.K_BITS))}\n")
        ch.write(f"#define KH_MAX      {hw.KH_MAX}\n")
        ch.write(f"#define PE_ROWS     {hw.ROWS}\n")
        ch.write(f"#define PE_COLS     {hw.COLS}\n\n")

        ch.write(f"#define N_OUT_BUF   {max(len(out_buffer_map),1)}\n")
        ch.write(f"#define N_ADD_BUF   {len(add_buffer_map) if len(add_buffer_map) > 0 else ''}\n")
        ch.write(f"#define WB_BYTES    {w_bytes + (b_words*hw.B_BITS)//8}\n")
        ch.write(f"#define W_BYTES     {w_bytes}\n")
        ch.write(f"#define X_BYTES     {x_bytes}\n")
        ch.write(f"#define O_WORDS     {o_words}\n")
        ch.write(f"#define O_WORDS_MAX {o_words_max}\n")
        ch.write(f"#define O_BYTES_MAX {o_bytes_max}\n")
        ch.write(f"#define X_BYTES_ALL {x_bytes_all}\n")
        ch.write(f"#define NHWC_WORDS  {nhwc_words_max}\n")
        ch.write(f"#define Y_TYPE      int{hw.Y_OUT_BITS}_t\n")
        ch.write(f"#define B_TYPE      int{hw.B_BITS}_t\n")
        ch.write(f"#define O_TYPE      {out_type}\n")
        ch.write(f"#define B_WORDS     {b_words}\n")
        ch.write(f"#define AXI_WIDTH   {hw.AXI_WIDTH}\n")
        ch.write(f"#define CONFIG_BASEADDR 0x{hw.CONFIG_BASEADDR}\n")
        ch.write(f'#define DATA_DIR   "../{hw.DATA_DIR}"\n\n')

        mask_nums = [(2**hw.X_BITS-1) << (p*hw.X_BITS)  for p in range(8//hw.X_BITS)]
        mask_nums = ~np.array(mask_nums, dtype=np.uint8)
        ch.write(f"static const uint8_t X_POSITION_INVERTED_MASKS [] = {{ {', '.join([str(n) for n in mask_nums])} }};\n")

        '''
        Write Binary Files
        '''
        type_d = { 'np': {8: np.int8, 16: np.int16, 32: np.int32, 64: np.int64} }

        w_bitstring = b''
        x_bitstring = b''
        b_bitstring = b''
        x_bitstring_0 = b''

        for ib, b in enumerate(BUNDLES):
            assert ib == b.ib
            x_bitstring_b = b''
            if b.core.b:
                b_bitstring += b.be.astype(type_d['np'][hw.B_BITS]).tobytes()
            for ip in range(b.r.CP):
                xe = pack_words_into_bytes(arr=b.xe[ip].flatten(), bits=hw.X_BITS)
                x_bitstring_b += xe.tobytes()
                    
                for it in range(b.r.IT):
                    we = pack_words_into_bytes(arr=b.we[ip][it].flatten(), bits=hw.K_BITS)
                    w_bitstring += we.tobytes()
            x_bitstring += x_bitstring_b
            with open(f"{hw.DATA_DIR}/{ib}_x_sim.bin", 'wb') as f: 
                f.write(x_bitstring_b)
            if ib==0:
                x_bitstring_0 = x_bitstring_b
        with open(f"{hw.DATA_DIR}/x.bin", 'wb') as f: 
            f.write(x_bitstring_0)

        with open(f"{hw.DATA_DIR}/wb.bin", 'wb') as f: 
            f.write(w_bitstring + b_bitstring)

        with open(f"{hw.DATA_DIR}/wbx.bin", 'wb') as f: 
            f.write(w_bitstring + b_bitstring + x_bitstring_0)

        with open(f"{hw.DATA_DIR}/x_all.bin", 'wb') as f: 
            f.write(x_bitstring)

        '''
        Write JSON Config File for PYNQ
        '''
        defines = {
            "N_BUNDLES": len(BUNDLES),
            "X_BITS_L2": int(np.log2(hw.X_BITS)),
            "W_BITS_L2": int(np.log2(hw.K_BITS)),
            "KH_MAX": hw.KH_MAX,
            "PE_ROWS": hw.ROWS,
            "PE_COLS": hw.COLS,
            "N_OUT_BUF": max(len(out_buffer_map), 1),
            "N_ADD_BUF": len(add_buffer_map) if len(add_buffer_map) > 0 else 0,
            "WB_BYTES": w_bytes + (b_words*hw.B_BITS)//8,
            "W_BYTES": w_bytes,
            "X_BYTES": x_bytes,
            "O_WORDS": o_words,
            "O_WORDS_MAX": o_words_max,
            "O_BYTES_MAX": o_bytes_max,
            "X_BYTES_ALL": x_bytes_all,
            "NHWC_WORDS": nhwc_words_max,
            "Y_TYPE_str": f"int{hw.Y_OUT_BITS}",
            "B_TYPE_str": f"int{hw.B_BITS}",
            "O_TYPE_str": 'float32' if BUNDLES[-1].softmax else 'int32',
            "B_WORDS": b_words,
            "AXI_WIDTH": hw.AXI_WIDTH,
            "CONFIG_BASEADDR": hw.CONFIG_BASEADDR,
            "DATA_DIR": hw.DATA_DIR
        }

        bundle_dicts = []
        temp_b_words = 0
        for ib, b in enumerate(BUNDLES):
            # Recalculate values specific to this bundle for the dict
            w_bpt    = (hw.K_BITS*b.we[-1][0].size)//8
            w_bpt_p0 = (hw.K_BITS*b.we[0][0].size)//8
            x_bpt    = (hw.X_BITS*b.xe[-1].size)//8
            x_bpt_p0 = (hw.X_BITS*b.xe[0].size )//8

            if ib == len(BUNDLES)-1:
                o_words_b = b.o_int.size
                o_bytes_b = o_words_b*4
            else:
                b_next    = BUNDLES[ib+1]
                o_wpt     = b_next.xe[-1].size
                o_wpt_p0  = b_next.xe[0].size
                o_words_b = o_wpt_p0 + (b_next.r.CP-1)*o_wpt
                o_bpt = (hw.X_BITS*b_next.xe[-1].size)//8
                o_bpt_p0 = (hw.X_BITS*b_next.xe[0].size)//8
                o_bytes_b = o_bpt_p0 + (b_next.r.CP-1)*o_bpt
            
            xp_words  = b.r.XN * b.r.XL * b.r.XW * (hw.ROWS+b.r.X_PAD)
            ib_out = -1 if len(b.next_ibs) == 0 else sorted(b.next_ibs)[0]
            y_coe = b.r.CO_PRL
            
            ca_nzero, ca_shift, ca_pl_scale = b.core.act.non_zero, b.core.act.shift_bits, b.core.act.plog_slope
            (aa_nzero, aa_shift, aa_pl_scale) = (b.add .act.non_zero, b.add .act.shift_bits, b.add .act.plog_slope)if b.add  is not None else (0,0,0)
            (pa_nzero, pa_shift, pa_pl_scale) = (b.pool.act.non_zero, b.pool.act.shift_bits, b.pool.act.plog_slope)if b.pool is not None else (0,0,0)
            
            add_out_buffer_idx = b.add_out_buffer_idx
            add_in_buffer_idx = BUNDLES[b.add.source_ib].add_out_buffer_idx if b.add is not None else -1
            in_buffer_idx = BUNDLES[b.prev_ib].out_buffer_idx if b.prev_ib is not None else -1
            
            pool_type = 'POOL_NONE'
            if b.pool is not None:
                if b.pool.type == 'max': pool_type = 'POOL_MAX'
                elif b.pool.type == 'avg': pool_type = 'POOL_AVG'

            bundle_dict = {
                "n": b.r.XN, "l": b.r.XL, "kw": b.r.KW, "coe": y_coe, "h": b.r.XH, "w": b.r.XW, "ci": b.r.CI, "co": b.r.CO,
                "w_kw2": b.r.XW-b.r.KW//2, "t": b.r.IT, "p": b.r.CP, "cm": b.r.CM, "cm_p0": b.r.CM_0, "on": b.r.ON,
                "oh": b.r.OH, "ow": b.r.OW, "oc": b.r.OC, "ch": b.r.CYH, "ph": b.r.PYH, "cw": b.r.CYW, "pw": b.r.PYW,
                "pkh": b.r.PKH, "psh": b.r.PSH, "pkw": b.r.PKW, "psw": b.r.PSW,
                "xp_words": xp_words, "b_offset": temp_b_words, "w_bpt": w_bpt, "w_bpt_p0": w_bpt_p0, "x_bpt": x_bpt,
                "x_bpt_p0": x_bpt_p0, "o_words": o_words_b, "o_bytes": o_bytes_b,
                "ib_out": ib_out, "in_buffer_idx": in_buffer_idx, "out_buffer_idx": b.out_buffer_idx,
                "add_out_buffer_idx": add_out_buffer_idx, "add_in_buffer_idx": add_in_buffer_idx,
                "is_bias": 1*(b.core.b is not None), "is_flatten": 1*(b.flatten is not None),
                "is_softmax": 1*(b.softmax is not None),
                "x_pad": b.r.X_PAD, "b_val_shift": b.core.bias_val_shift, "b_bias_shift": b.core.bias_b_shift,
                "ca_nzero": ca_nzero, "ca_shift": ca_shift, "ca_pl_scale": ca_pl_scale,
                "aa_nzero": aa_nzero, "aa_shift": aa_shift, "aa_pl_scale": aa_pl_scale,
                "pa_nzero": pa_nzero, "pa_shift": pa_shift, "pa_pl_scale": pa_pl_scale,
                "softmax_frac": b.softmax_frac,
                "csh": b.r.CSH, "csh_shift": b.r.CSH_SHIFT, "psh_shift": b.r.PSH_SHIFT, "csw": b.r.CSW,
                "csw_shift": b.r.CSW_SHIFT, "psw_shift": b.r.PSW_SHIFT, "pool": pool_type,
                "softmax_max_f": b.softmax_max_f,
                "header": b.r.header,
                "debug_nhwc_words": b.oe_exp_nhwc.size
            }
            bundle_dicts.append(bundle_dict)
            temp_b_words += b.be.size if b.core.b else 0
        
        config_data = {"defines": defines, "bundles": bundle_dicts}
        with open(f"{hw.DATA_DIR}/config.json", 'w') as f:
            # use a custom encoder to handle numpy types
            class NpEncoder(json.JSONEncoder):
                def default(self, obj):
                    if isinstance(obj, np.integer):
                        return int(obj)
                    if isinstance(obj, np.floating):
                        return float(obj)
                    if isinstance(obj, np.ndarray):
                        return obj.tolist()
                    return super(NpEncoder, self).default(obj)
            json.dump(config_data, f, indent=4, cls=NpEncoder)
        print(f"Successfully created JSON config file at: {hw.DATA_DIR}/config.json")

        '''
        Write Text files of vectors
        '''
        for ib, b in enumerate(BUNDLES):
            assert ib == b.ib
            np.savetxt(f"{hw.DATA_DIR}/{b.ib}_y_nhwc_exp.txt", b.oe_exp_nhwc.flatten(), fmt='%d')
            np.savetxt(f"{hw.DATA_DIR}/{b.ib}_xe.txt", np.concatenate([a.flatten() for a in b.xe]), fmt='%d')
            for ip in range(b.r.CP):
                CM_p = b.r.CM_0 if ip==0 else b.r.CM

                xp = b.xe[ip].flatten()
                np.savetxt(f"{hw.DATA_DIR}/{b.ib}_{ip}_x.txt", xp, fmt='%d')

                for it in range(b.r.IT):
                    wp = b.we[ip][it].flatten()            
                    assert wp.shape == ((CM_p*b.r.KH+hw.CONFIG_BEATS)*hw.COLS,), f"{wp.shape} != {(CM_p*b.r.KH+hw.CONFIG_BEATS)*hw.COLS}"
                    np.savetxt(f"{hw.DATA_DIR}/{b.ib}_{ip}_{it}_w.txt", wp, fmt='%d')
                    np.savetxt(f"{hw.DATA_DIR}/{b.ib}_{ip}_{it}_y_exp.txt", b.ye_exp_p[ip][it].flatten(), fmt='%d')
        
        y_exp = (b.out.ftensor.numpy() if b.softmax else b.o_int).flatten() 
        np.savetxt(f"{hw.DATA_DIR}/y_exp.txt", y_exp, fmt= '%f' if b.softmax else '%d')
        for i in range(len(y_exp)):
            if (i < 20 or len(y_exp)-i < 20):
                print(f"y_exp {i}: {y_exp[i]}")
        
        print(f'Weights, inputs, outputs saved to {hw.DATA_DIR}/ib_ip_it_*.txt')


def verify_inference(model, hw, SIM, SIM_PATH='', TRACE=False):

    '''
    RUN SIMULATION
    '''
    hw.simulate(SIM=SIM, SIM_PATH=SIM_PATH, TRACE=TRACE)


    '''
    CHECK ERROR
    '''
    for ib, b in enumerate(BUNDLES):
        assert ib == b.ib
        
        ''' Verify raw output '''
        for ip in range(b.r.CP):
            for it in range(b.r.IT):
                y_raw_exp = b.ye_exp_p[ip][it]
                y_raw_sim = np.loadtxt(f"{hw.DATA_DIR}/{b.ib}_{ip}_{it}_y_raw_sim.txt", np.int32)[:y_raw_exp.size].reshape(y_raw_exp.shape)
                error = np.sum(np.abs(y_raw_exp-y_raw_sim))
                assert error == 0, f"Error={error}, for y_raw_sim at {b.ib=}_{ip=}_{it=}"

        ''' Verify sum output '''
        y_sum_exp = b.oe_sum_exp
        y_sum_sim = np.loadtxt(f"{hw.DATA_DIR}/{b.ib}_y_sum_sim.txt", np.int32)[:y_sum_exp.size].reshape(y_sum_exp.shape)
        error = np.sum(np.abs(y_sum_exp-y_sum_sim))
        assert error == 0, f"Error={error}, for y_sum_sim at {b.ib=}"

        ''' Verify processed output HWC'''
        if not (ib == len(BUNDLES)-1 and b.softmax):
            y_nhwc_sim = np.loadtxt(f"{hw.DATA_DIR}/{b.ib}_y_nhwc_sim.txt",np.int32).reshape(b.oe_exp_nhwc.shape)
            error = np.sum(np.abs(y_nhwc_sim - b.oe_exp_nhwc))
            assert error == 0, f"sim:\n{y_nhwc_sim[0,:,:,0]}\n exp:\n{b.oe_exp_nhwc[0,:,:,0]}\n input:\n{b.pool.x.itensor.numpy()[0,:,:,0] if b.pool else None}"


        ''' Verify tiled output'''
        if (ib == len(BUNDLES)-1):
            if b.softmax:
                y_tiled_exp = b.out.ftensor.numpy().reshape(1,b.r.XN,1,b.r.CO)
                y_tiled_sim = np.loadtxt(f"{hw.DATA_DIR}/{b.ib}_y_tiled_sim.txt", np.float32).reshape(y_tiled_exp.shape)
                error = np.max(np.abs(y_tiled_sim-y_tiled_exp))
                assert np.allclose(y_tiled_sim, y_tiled_exp, atol=0.5), f"Error={error}, \nsub:\n{y_tiled_sim-y_tiled_exp} for y_tiled_sim at {b.ib=}. \n y_tiled_sim=\n{y_tiled_sim} \n y_tiled_exp=\n{y_tiled_exp}\n \npre_softmax=\n{b.pre_softmax}"
            else:
                y_tiled_exp = b.o_int
                y_tiled_sim = np.loadtxt(f"{hw.DATA_DIR}/{b.ib}_y_tiled_sim.txt", np.float32).reshape(y_tiled_exp.shape)
                error = np.sum(np.abs(y_tiled_sim-y_tiled_exp))
                assert error == 0, f"Error={error}, for y_tiled_sim at {b.ib=}"
        else:
            y_tiled_exp = np.concatenate([a.flatten() for a in BUNDLES[ib+1].xe])
            y_tiled_sim = np.loadtxt(f"{hw.DATA_DIR}/{b.ib}_y_tiled_sim.txt", np.float32).reshape(y_tiled_exp.shape)
            error = np.sum(np.abs(y_tiled_sim-y_tiled_exp))
            assert error == 0, f"Error={error}, for y_tiled_sim at {b.ib=}"

        ''' Verify packed output'''
        if ib != len(BUNDLES)-1 and len(b.next_ibs) != 0:
            with open(f'{hw.DATA_DIR}/{ib}_y_packed_sim.bin', 'rb') as f_sim, open(f'{hw.DATA_DIR}/{ib+1}_x_sim.bin', 'rb') as f_exp:
                y_packed_sim = np.frombuffer(f_sim.read(), dtype=np.uint8)
                y_packed_exp = np.frombuffer(f_exp.read(), dtype=np.uint8)
            diff  = y_packed_sim-y_packed_exp
            error = np.sum(np.abs(diff))
            assert error == 0, f"Error={error}, for y_packed_sim at {b.ib=}, y_packed_sim=\n{y_packed_sim[:100]} \n y_packed_exp=\n{y_packed_exp[:100]}\n, diff=\n{diff.tolist()}\n  y_packed_sim=\n{y_packed_sim.tolist()} \n y_packed_exp=\n{y_packed_exp.tolist()}\n"
            
        print(f"Bundle {b.ib}, Error: {error}. Passed")