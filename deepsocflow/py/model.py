from qkeras import Model
import numpy as np
import tensorflow.keras
import os
from deepsocflow.py.bundle import Bundle

class QModel(Model):

    def __init(self, inputs, outputs, name=None):
        super().__init__(inputs, outputs, name=name)
        Bundle.idx = 0


    @property
    def random_input(self):
        tensorflow.keras.utils.set_random_seed(0)
        return np.clip(np.random.randn(*self.input.shape), -1.0, 1.0)

    @property # property cuz assigning to self.bundles takes forever (zips and stores)
    def bundles(self):
        return sorted(self.layers[2:], key= lambda b:b.idx) # Sort bundles in-place by index. Note: idx != ib

    def export_inference(self, x, hw):

        type_d = { 'np': {8: np.int8, 16: np.int16, 32: np.int32, 64: np.int64} }

        print("starting keras forward pass")
        y = self(x, training=False)
        print("done keras forward pass")
        self.hw = hw

        inp_act_model = Model(inputs=self.input, outputs=self.layers[1].output)
        inp_tensor = inp_act_model(x, training=False)

        inp = {
            'bits':hw.X_BITS, 
            'frac':hw.X_BITS-1 - self.layers[1].quantizer.integer,
            'tensor':inp_tensor,
            'int':inp_tensor.numpy() * 2**(hw.X_BITS-1)
            }

        bundles = self.bundles

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

        for b in bundles:
            print(f'-----------------bundle.idx:{b.idx}-----------------------')
            b.process(inp if b.idx==0 else None, hw)
            b.export(hw, False) 

            '''
            OUTPUT BUFFER ALLOCATION
            '''
            print(f'input_out_map:{out_buffer_map}')

            '''Find and assign a free buffer. If not, add new buffer'''
            b.out_buffer_idx = -1
            if len(b.next_bundles) != 0:
                next_bundles_sorted = [bn.idx for bn in b.next_bundles]
                next_bundles_sorted.sort()
                for im in range(len(out_buffer_map)):
                    if out_buffer_map[im] is None:
                        out_buffer_map[im] = {'in':b.idx, 'out':next_bundles_sorted}
                        b.out_buffer_idx = im
                        break
                else: #m if break is not hit
                    b.out_buffer_idx = len(out_buffer_map)
                    out_buffer_map += [{'in':b.idx, 'out':next_bundles_sorted}]
            
            print('out_buffer_idx:', b.out_buffer_idx)

            '''Free the buffers whose last destination is current bundle'''
            for im in range(len(out_buffer_map)):
                buf = out_buffer_map[im]
                if buf is not None:
                    if buf['out'][-1] == b.idx:
                        out_buffer_map[im] = None

            print(f'out_buffer_map:{out_buffer_map}')


            
            '''
            ADD BUFFER ALLOCATION
            '''
            print(f'input_add_map:{add_buffer_map}')

            '''Find and assign a free buffer. If not, add new buffer'''
            b.add_out_buffer_idx = -1
            if len(b.add_tensor_dest) != 0:
                for im in range(len(add_buffer_map)):
                    if add_buffer_map[im] is None:
                        add_buffer_map[im] = {'in':b.idx, 'out':b.add_tensor_dest}
                        b.add_out_buffer_idx = im
                        break
                else: #m if break is not hit
                    b.add_out_buffer_idx = len(add_buffer_map)
                    add_buffer_map += [{'in':b.idx, 'out':b.add_tensor_dest}]
            
            print('add_out_buffer_idx:', b.add_out_buffer_idx)

            '''Free the buffers whose last destination is current bundle'''
            for im in range(len(add_buffer_map)):
                buf = add_buffer_map[im]
                if buf is not None:
                    if buf['out'][-1] == b.idx:
                        add_buffer_map[im] = None

            print(f'add_buffer_map:{add_buffer_map}')


        '''
        Write Runtime Headers
        '''
        x_bytes_all = x_bytes = w_bytes = b_words = x_bytes_max = nhwc_words_max = o_bytes_max = o_words_max = 0
        out_buffer_idx = 1
        with open (f'./config_fw.h', 'w') as ch:

            ch.write(f"#define N_BUNDLES {len(bundles)}\n")
            ch.write(f"Bundle_t bundles [N_BUNDLES] = {{\n")
            
            for ib, b in enumerate(bundles):
                assert ib == b.idx

                w_bpt    = (hw.K_BITS*b.we[-1][0].size + hw.IN_BITS)//8
                w_bpt_p0 = (hw.K_BITS*b.we[0][0].size + hw.IN_BITS )//8
                x_bpt    = (hw.X_BITS*b.xe[-1].size + hw.IN_BITS   )//8 
                x_bpt_p0 = (hw.X_BITS*b.xe[0].size + hw.IN_BITS    )//8
                
                if ib == len(bundles)-1:
                    o_words_b = b.o_int.size
                    o_bytes_b = o_words_b*4 # int or float
                    o_words = o_words_b
                else:
                    b_next    = bundles[ib+1]
                    o_wpt     = b_next.xe[-1].size
                    o_wpt_p0  = b_next.xe[0].size
                    o_words_b = o_wpt_p0 + (b_next.r.CP-1)*o_wpt

                    o_bpt = (hw.X_BITS*b_next.xe[-1].size + hw.IN_BITS)//8
                    o_bpt_p0 = (hw.X_BITS*b_next.xe[0].size + hw.IN_BITS)//8
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

                ib_out = -1 if len(b.next_bundles) == 0 else b.next_bundles[0].idx

                if ib == 0:
                    x_bytes = (x_bpt_p0 + (b.r.CP-1)*x_bpt)

                y_coe = b.r.CO_PRL
                y_coe_tl = b.r.CO_PRL if (b.r.CO==b.r.IT*b.r.CO_PRL) else b.r.CO%b.r.IT
                y_r_ll = hw.ROWS if b.r.XH==b.r.XL*hw.ROWS else  b.r.XH % hw.ROWS

                ca_nzero, ca_shift, ca_pl_scale = b.core['act']['non_zero'], b.core['act']['shift_bits'], b.core['act']['plog_slope']

                (aa_nzero, aa_shift, aa_pl_scale) = (b.add ['act']['non_zero'], b.add ['act']['shift_bits'], b.add ['act']['plog_slope'])if b.add  is not None else (0,0,0)
                (pa_nzero, pa_shift, pa_pl_scale) = (b.pool['act']['non_zero'], b.pool['act']['shift_bits'], b.pool['act']['plog_slope'])if b.pool is not None else (0,0,0)

                add_out_buffer_idx = b.add_out_buffer_idx
                add_in_buffer_idx = b.add['bundle'].add_out_buffer_idx if b.add is not None else -1
                in_buffer_idx = b.prev_bundle.out_buffer_idx if b.prev_bundle is not None else -1

                if b.pool is None:
                    pool_type = 'POOL_NONE'
                elif b.pool['type'] == 'max':
                    pool_type = 'POOL_MAX'
                elif b.pool['type'] == 'avg':
                    pool_type = 'POOL_AVG'

                out_type = 'float' if (ib == len(bundles)-1 and b.softmax) else 'int32_t'

                ch.write(f"   {{.n={b.r.XN:<3}, .l={b.r.XL:<3}, .kw={b.r.KW:<3}, .coe={y_coe:<3}, .coe_tl={y_coe_tl:<3}, .r_ll={y_r_ll:<3}, .h={b.r.XH:<3}, .w={b.r.XW:<3}, .ci={b.r.CI:<4}, .co={b.r.CO:<4}, .w_kw2={b.r.XW-b.r.KW//2:<3}, .t={b.r.IT:<3}, .p={b.r.CP:<3}, .cm={b.r.CM:<3}, .cm_p0={b.r.CM_0:<3}, .xp_words={xp_words:<6}, .ib_out={ib_out:<4}, ")
                ch.write(     f".w_bpt={w_bpt:<5}, .w_bpt_p0={w_bpt_p0:<5}, .x_bpt={x_bpt:<8}, .x_bpt_p0={x_bpt_p0:<8}, .o_words={o_words_b:<8}, .o_bytes={o_bytes_b:<8}, .x_pad={b.r.X_PAD:<3}, ")
                ch.write(     f".in_buffer_idx={in_buffer_idx:<3}, .out_buffer_idx={b.out_buffer_idx:<3}, .add_out_buffer_idx={add_out_buffer_idx:<2}, .add_in_buffer_idx={add_in_buffer_idx:<2}, ")
                ch.write(     f".is_bias={1*(b.b is not None):<3}, .is_flatten={1*b.flatten:<3}, .is_softmax={1*b.softmax:<3}, ")
                ch.write(     f".b_offset={b_words:<5}, .b_val_shift={b.bias_val_shift:<3}, .b_bias_shift={b.bias_b_shift:<3}, ")
                ch.write(     f".ca_nzero={ca_nzero:<3}, .ca_shift={ca_shift:<3}, .ca_pl_scale={ca_pl_scale:<3}, .aa_nzero={aa_nzero:<3}, .aa_shift={aa_shift:<3}, .aa_pl_scale={aa_pl_scale:<3}, .pa_nzero={pa_nzero:<3}, .pa_shift={pa_shift:<3}, .pa_pl_scale={pa_pl_scale:<3}, .softmax_frac={b.softmax_frac:<3}, ")
                ch.write(     f".softmax_max_f={b.softmax_max_f:<15}, ")
                ch.write(     f".csh={b.r.CSH:<3}, .ch={b.r.CYH:<3}, .csh_shift={b.r.CSH_SHIFT:<3}, .pkh={b.r.PKH:<3}, .psh={b.r.PSH:<3}, .ph={b.r.PYH:<3}, .psh_shift={b.r.PSH_SHIFT:<3}, .csw={b.r.CSW:<3}, .cw={b.r.CYW:<3}, .csw_shift={b.r.CSW_SHIFT:<3}, .pkw={b.r.PKW:<3}, .psw={b.r.PSW:<3}, .pw={b.r.PYW:<3}, .psw_shift={b.r.PSW_SHIFT:<3}, .pool={pool_type:<10}, .on={b.r.ON:<3}, .oh={b.r.OH:<3}, .ow={b.r.OW:<3}, .oc={b.r.OC:<4}, ")
                ch.write(     f".x_header={b.r.x_header_le_p[-1][0]:>23}u, .x_header_p0={b.r.x_header_le_p[0][0]:>23}u, .w_header={b.r.w_header_le_p[-1][0]:>23}u, .w_header_p0={b.r.x_header_le_p[0][0]:>25}u , ")
                ch.write(     f".debug_nhwc_words={b.oe_exp_nhwc.size:<9} }}")
                
                b_words += b.be.size if b.b else 0
                if b.idx != len(bundles)-1:
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
            ch.write(f"#define AXI_WIDTH   {hw.IN_BITS}\n")
            ch.write(f'#define DATA_DIR   "../{hw.DATA_DIR}"\n\n')

            mask_nums = [(2**hw.X_BITS-1) << (p*hw.X_BITS)  for p in range(8//hw.X_BITS)]
            mask_nums = ~np.array(mask_nums, dtype=np.uint8)
            ch.write(f"static const uint8_t X_POSITION_INVERTED_MASKS [] = {{ {', '.join([str(n) for n in mask_nums])} }};\n")

        '''
        Write Binary Files
        '''
        w_bitstring = b''
        x_bitstring = b''
        b_bitstring = b''
        x_bitstring_0 = b''

        header_padding = b'\x00\x00\x00\x00\x00\x00\x00\x00' if hw.IN_BITS == 128 else b''

        for ib, b in enumerate(bundles):
            assert ib == b.idx
            x_bitstring_b = b''
            if b.b:
                b_bitstring += b.be.astype(type_d['np'][hw.B_BITS]).tobytes()
            for ip in range(b.r.CP):
                xe = Bundle.pack_words_into_bytes(arr=b.xe[ip].flatten(), bits=hw.X_BITS)
                x_bitstring_b += b.r.x_header_be_p[ip!=0].tobytes() + header_padding + xe.tobytes()
                    
                for it in range(b.r.IT):
                    we = Bundle.pack_words_into_bytes(arr=b.we[ip][it].flatten(), bits=hw.K_BITS)
                    w_bitstring += b.r.w_header_be_p[ip!=0].tobytes() + header_padding + we.tobytes()
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
        Write Text files of vectors
        '''
        for ib, b in enumerate(bundles):
            assert ib == b.idx
            np.savetxt(f"{hw.DATA_DIR}/{b.idx}_y_nhwc_exp.txt", b.oe_exp_nhwc.flatten(), fmt='%d')
            np.savetxt(f"{hw.DATA_DIR}/{b.idx}_xe.txt", np.concatenate([a.flatten() for a in b.xe]), fmt='%d')
            for ip in range(b.r.CP):
                CM_p = b.r.CM_0 if ip==0 else b.r.CM
                x_config = b.r.x_header_le_p[ip!=0][0]
                x_config = format(x_config, f'#0{hw.IN_BITS}b')
                x_config_words = [int(x_config[i:i+hw.X_BITS], 2) for i in range(0, len(x_config), hw.X_BITS)]
                x_config_words.reverse()
                x_config_words = np.array(x_config_words, dtype=np.uint8)

                xp = b.xe[ip].flatten()
                xp = np.concatenate([x_config_words, xp], axis=0)
                # assert xp.shape == (hw.IN_BITS/hw.X_BITS +b.r.XN*b.r.XL*b.r.XW*CM_p*(hw.ROWS+r.XPAD),)
                np.savetxt(f"{hw.DATA_DIR}/{b.idx}_{ip}_x.txt", xp, fmt='%d')


                for it in range(b.r.IT):
                    
                    w_config = b.r.w_header_le_p[ip!=0][0]
                    w_config = format(w_config, f'#0{hw.IN_BITS}b')
                    w_config_words = [int(w_config[i:i+hw.K_BITS], 2) for i in range(0, len(w_config), hw.K_BITS)]
                    w_config_words.reverse()
                    w_config_words = np.array(w_config_words, dtype=np.uint8)

                    wp = b.we[ip][it].flatten()            
                    wp = np.concatenate([w_config_words, wp], axis=0)
                    assert wp.shape == (hw.IN_BITS/hw.K_BITS + (CM_p*b.r.KH+hw.CONFIG_BEATS)*hw.COLS,)
                    np.savetxt(f"{hw.DATA_DIR}/{b.idx}_{ip}_{it}_w.txt", wp, fmt='%d')

                    np.savetxt(f"{hw.DATA_DIR}/{b.idx}_{ip}_{it}_y_exp.txt", b.ye_exp_p[ip][it].flatten(), fmt='%d')
        
        y_exp = bundles[-1].o_int.flatten()
        np.savetxt(f"{hw.DATA_DIR}/y_exp.txt", y_exp, fmt= '%f' if bundles[-1].softmax else '%d')
        for i in range(len(y_exp)):
            if (i < 20 or len(y_exp)-i < 20):
                print(f"y_exp {i}: {y_exp[i]}")
        
        print(f'Weights, inputs, outputs saved to {hw.DATA_DIR}/ib_ip_it_*.txt')

    def verify_inference(self, SIM, SIM_PATH):

        hw = self.hw
        bundles = self.bundles
        
        seconds, mem_bytes = self.predict_performance()
        print(f"Predicted time on hardware: {1000*seconds:.5f} ms/frame")
        print(f"Predicted fps: {1/seconds}")
        print(f"Data movement (bytes): mem_bytes")

        '''
        RUN SIMULATION
        '''
        hw.simulate(SIM=SIM, SIM_PATH=SIM_PATH)

        '''
        CHECK ERROR
        '''
        for ib, b in enumerate(bundles):
            assert ib == b.idx
            
            ''' Verify raw output '''
            for ip in range(b.r.CP):
                for it in range(b.r.IT):
                    y_raw_exp = b.ye_exp_p[ip][it]
                    y_raw_sim = np.loadtxt(f"{hw.DATA_DIR}/{b.idx}_{ip}_{it}_y_raw_sim.txt", np.int32).reshape(y_raw_exp.shape)
                    error = np.sum(np.abs(y_raw_exp-y_raw_sim))
                    assert error == 0, f"Error={error}, for y_raw_sim at {b.idx=}_{ip=}_{it=}"

            ''' Verify sum output '''
            y_sum_exp = b.oe_sum_exp
            y_sum_sim = np.loadtxt(f"{hw.DATA_DIR}/{b.idx}_y_sum_sim.txt", np.int32).reshape(y_sum_exp.shape)
            error = np.sum(np.abs(y_sum_exp-y_sum_sim))
            assert error == 0, f"Error={error}, for y_sum_sim at {b.idx=}"

            ''' Verify processed output HWC'''
            if not (ib == len(bundles)-1 and b.softmax):
                y_nhwc_sim = np.loadtxt(f"{hw.DATA_DIR}/{b.idx}_y_nhwc_sim.txt",np.int32).reshape(b.oe_exp_nhwc.shape)
                error = np.sum(np.abs(y_nhwc_sim - b.oe_exp_nhwc))
                assert error == 0, f"sim:\n{y_nhwc_sim[0,:,:,0]}\n exp:\n{b.oe_exp_nhwc[0,:,:,0]}\n input:\n{b.before_pool[0,:,:,0] if b.pool else None}"


            ''' Verify tiled output'''
            if (ib == len(bundles)-1):
                y_tiled_exp = b.o_int
                if b.softmax:
                    y_tiled_sim = np.loadtxt(f"{hw.DATA_DIR}/{b.idx}_y_tiled_sim.txt", np.float32).reshape(y_tiled_exp.shape)
                    error = np.max(np.abs(y_tiled_sim-y_tiled_exp))
                    assert np.allclose(y_tiled_sim, y_tiled_exp, atol=0.5), f"Error={error}, \nsub:\n{y_tiled_sim-y_tiled_exp} for y_tiled_sim at {b.idx=}. \n y_tiled_sim=\n{y_tiled_sim} \n y_tiled_exp=\n{y_tiled_exp}\n \nbefore_softmax=\n{b.before_softmax}"
                else:
                    y_tiled_sim = np.loadtxt(f"{hw.DATA_DIR}/{b.idx}_y_tiled_sim.txt", np.float32).reshape(y_tiled_exp.shape)
                    error = np.sum(np.abs(y_tiled_sim-y_tiled_exp))
                    assert error == 0, f"Error={error}, for y_tiled_sim at {b.idx=}"
            else:
                y_tiled_exp = np.concatenate([a.flatten() for a in bundles[ib+1].xe])
                y_tiled_sim = np.loadtxt(f"{hw.DATA_DIR}/{b.idx}_y_tiled_sim.txt", np.float32).reshape(y_tiled_exp.shape)
                error = np.sum(np.abs(y_tiled_sim-y_tiled_exp))
                assert error == 0, f"Error={error}, for y_tiled_sim at {b.idx=}"

            ''' Verify packed output'''
            if ib != len(bundles)-1 and len(b.next_bundles) != 0:
                with open(f'{hw.DATA_DIR}/{ib}_y_packed_sim.bin', 'rb') as f_sim, open(f'{hw.DATA_DIR}/{ib+1}_x_sim.bin', 'rb') as f_exp:
                    y_packed_sim = np.frombuffer(f_sim.read(), dtype=np.uint8)
                    y_packed_exp = np.frombuffer(f_exp.read(), dtype=np.uint8)
                diff  = y_packed_sim-y_packed_exp
                error = np.sum(np.abs(diff))
                assert error == 0, f"Error={error}, for y_packed_sim at {b.idx=}, y_packed_sim=\n{y_packed_sim[:100]} \n y_packed_exp=\n{y_packed_exp[:100]}\n, diff=\n{diff.tolist()}\n  y_packed_sim=\n{y_packed_sim.tolist()} \n y_packed_exp=\n{y_packed_exp.tolist()}\n"
                
            print(f"Bundle {b.idx}, Error: {error}. Passed")

    def predict_performance(self):

        clocks_total = 0
        for b in self.bundles:
            clocks, mem_bits = Bundle.predict_performance(hw=self.hw, r=b.r)
            clocks_total += clocks

        time = clocks_total / (self.hw.FREQ * 1e6)
        mem_bytes = mem_bits / 8
        return time, mem_bytes
