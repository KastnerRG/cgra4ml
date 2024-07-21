#include <assert.h>
#include <stdlib.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <math.h>

typedef int8_t   i8 ;
typedef int16_t  i16;
typedef int32_t  i32;
typedef int64_t  i64;
typedef uint8_t  u8 ;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef float    f32;
typedef double   f64;

typedef const struct {
  const i32  n, l, kw, coe, coe_tl, r_ll, h, w, ci, co, w_kw2, t, p, cm, cm_p0, xp_words, ib_out;
  const i32  w_bpt, w_bpt_p0, x_bpt, x_bpt_p0, o_words, o_bytes, x_pad; // bytes per transfer
  const i8   in_buffer_idx, out_buffer_idx, add_out_buffer_idx, add_in_buffer_idx;
  const i8   is_bias, is_pool, is_flatten, is_softmax;
  const i32  b_offset, b_val_shift, b_bias_shift;
  const i8   ca_nzero, ca_shift, ca_pl_scale, aa_nzero, aa_shift, aa_pl_scale, pa_nzero, pa_shift, pa_pl_scale, softmax_frac;
  const f32  softmax_max_f;
  const i32  csh, ch, csh_shift, pkh, psh, ph, psh_shift, csw, cw, csw_shift, pkw, psw, pw, psw_shift, pool, on, oh, ow, oc;
  const u64  x_header, x_header_p0, w_header, w_header_p0; // 64 bits (at least)
  const i32  debug_nhwc_words;
} Bundle_t;

typedef enum {POOL_NONE, POOL_MAX, POOL_AVG} Pool_t;

#include "../../run/work/config_fw.h"
#define X_BITS            (1 << X_BITS_L2)
#define X_WORDS_PER_BYTE  (8 / X_BITS)
#define X_BITS_MASK       ((1 << X_BITS) -1)


typedef struct {
  // These are written often, keep them on OCM
  Y_TYPE ocm            [2][PE_COLS*PE_ROWS];
  i32    nhwc           [NHWC_WORDS  ];
  i8     out_buffers    [N_OUT_BUF   ][O_BYTES_MAX ];
  // These can be kept in DDR
  i8     w              [W_BYTES     ];
  B_TYPE b              [B_WORDS     ]; // keep next to w. weights are loaded to w_ptr
  i8     x              [X_BYTES     ]; // keep next to wb. wbx is loaded to w_ptr
  O_TYPE y              [O_WORDS     ];

#ifndef NDEBUG
  i8     debug_tiled    [O_WORDS_MAX ];
  i32    debug_nhwc     [NHWC_WORDS  ];
#endif
  i8     add_buffers    [N_ADD_BUF   ][NHWC_WORDS  ]; // should be last, since N_ADD_BUF can be empty
} Memory_st;

#define ocm (mem.ocm)

#define A_START        0x0
#define A_DONE_READ    0x1 // 2
#define A_DONE_WRITE   0x3 // 2
#define A_OCM_BASE     0x5 // 2
#define A_WEIGHTS_BASE 0x7
#define A_BUNDLE_DONE  0x8
#define A_N_BUNDLES_1  0x9
#define A_W_DONE       0xA // W,X,O done are written by PL, read by PS to debug which one hangs
#define A_X_DONE       0xB 
#define A_O_DONE       0xC

#ifdef __cplusplus
  #define EXT_C "C"
#else
  #define EXT_C
#endif

#ifdef SIM
  #include <stdio.h>
  #define sim_fprintf fprintf
  #include <stdbool.h>
  // Simulation is in 32 bit mode.

  Memory_st mem;

  static inline void flush_cache(void *addr, uint32_t bytes) {
    // Do nothing
  }
  
  extern EXT_C u32 to_embedded(void* addr){
    u64 offset = (u64)addr - (u64)&mem;
    return (u32)offset + MEM_BASEADDR;
  }

  // Get and set config are done by sv
	extern EXT_C u32 get_config(u32);
	extern EXT_C void set_config(u32, u32);

#else
  #define sim_fprintf(...)
  #define mem (*(Memory_st*)MEM_BASEADDR)

  u32 to_embedded(void* addr){
    return (u32)addr;
  }

  inline volatile u32 get_config(u32 offset){
    return *(volatile u32 *)(CONFIG_BASEADDR + offset);
  }

  inline void set_config(u32 offset, u32 data){	
    volatile u32 *Addr = (volatile u32 *)(CONFIG_BASEADDR + offset);
    *Addr = data;
  }
#endif

#ifdef NDEBUG
  #define assert_printf(...)
  #define debug_printf(...)
#else
  #define debug_printf printf
  #define assert_printf(v1, op, v2, optional_debug_info,...) ((v1  op v2) || (debug_printf("ASSERT FAILED: \n CONDITION: "), debug_printf("( " #v1 " " #op " " #v2 " )"), debug_printf(", VALUES: ( %d %s %d ), ", v1, #op, v2), debug_printf("DEBUG_INFO: " optional_debug_info), debug_printf(" " __VA_ARGS__), debug_printf("\n\n"), assert(v1 op v2), 0))
#endif


// Helper functions

static inline void print_output () {
  flush_cache(&mem.y, sizeof(mem.y));
  for (int i=0; i<O_WORDS; i++){
    printf("y[%d]: %f \n", i, (float)mem.y[i]);
  }
}

static inline void write_flush_u8(u8* addr, u8 val) {
  *addr = val;
  flush_cache(addr, 1);
}

static inline void write_flush_u64(u64* addr, u64 val) {
  *addr = val;
  flush_cache(addr, 8);
}


#define flatten_nhwc(in,ih,iw,ic, N,H,W,C, optional_debug_info,...)\
  ((in*H + ih)*W + iw)*C + ic;\
  assert_printf (in, <, N, optional_debug_info,__VA_ARGS__); assert_printf (ih, <, H, optional_debug_info,__VA_ARGS__); assert_printf (iw, <, W, optional_debug_info,__VA_ARGS__); assert_printf (ic, <, C, optional_debug_info,__VA_ARGS__); assert_printf ((((in*H + ih)*W + iw)*C + ic), <, NHWC_WORDS, optional_debug_info,__VA_ARGS__);

#define max(x, y) ((x) > (y) ? (x) : (y))
#define min(x, y) ((x) < (y) ? (x) : (y))
#define clip(x, xmin, xmax) (((x) < (xmin)) ? (xmin) : ((x) > (xmax)) ? (xmax) : (x))
#define shift_round(n, s) (((n) + ((s)>0 ? (1<<((s)-1)) - (~((n)>>(s))&1) : 0)) >> s) // === np.around(n/2**s).astype(i32)
#define div_round(a, b) (((a)+((b)/2) - (~((b)|(a)/(b)) &1))/(b))


static inline i32 quant_lrelu(i32 x, i8 nzero, i8 shift, i8 pl_scale){
  x = x < 0 ? (nzero ? x: 0) : x << pl_scale; // Conditional, targeting ARM
  x = shift_round(x, shift);
  x = clip(x, -(1<<(X_BITS-pl_scale-1)), (1<<(X_BITS-1))-1);
  return x;
}


static inline void write_x(i8 val, i8 *p_out_buffer, i32 ib, i32 ixp, i32 ixn, i32 ixl, i32 ixw, i32 ixcm, i32 ixr, Bundle_t *pb_out, i32 xcm ){

  #define WRITEX_DEBUG_INFO "--- ib:%d ixp:%d ixn:%d ixl:%d ixw:%d ixcm:%d ixr:%d xcm :%d \n",ib,ixp,ixn,ixl,ixw,ixcm,ixr,xcm
  assert_printf (ixr , <, PE_ROWS+pb_out->x_pad, "write_x", WRITEX_DEBUG_INFO);
  assert_printf (ixcm, <, xcm          , "write_x", WRITEX_DEBUG_INFO);
  assert_printf (ixw , <, pb_out->w    , "write_x", WRITEX_DEBUG_INFO);
  assert_printf (ixl , <, pb_out->l    , "write_x", WRITEX_DEBUG_INFO);
  assert_printf (ixn , <, pb_out->n    , "write_x", WRITEX_DEBUG_INFO);
  assert_printf (ixp , <, pb_out->p    , "write_x", WRITEX_DEBUG_INFO);

  i32 p_offset       = (ixp == 0) ? 0 : (pb_out->cm_p0 + (ixp-1)*pb_out->cm) * pb_out->xp_words;
  i32 flat_index_n2r = (((ixn*pb_out->l + ixl)*pb_out->w + ixw)*xcm + ixcm)*(PE_ROWS+pb_out->x_pad) + ixr; // multidim_index -> flat_index [n,l,w,cm,r]

  // Debug tiled output
  i32 flat_index     = p_offset + flat_index_n2r;

#ifndef NDEBUG
  mem.debug_tiled[flat_index] = val;
#endif

  // Pack bits and store
  i32 flat_index_with_header = p_offset + flat_index_n2r + (ixp+1)*(AXI_WIDTH/X_BITS);
  i32 packed_index           = flat_index_with_header / X_WORDS_PER_BYTE;
  u8 packed_position        = flat_index_with_header % X_WORDS_PER_BYTE; // 0,1,2,3

  assert_printf (packed_index , <, bundles[ib].o_bytes, "write_x", WRITEX_DEBUG_INFO);

  u8 packed_val             = ((u8)val & X_BITS_MASK) << (packed_position * X_BITS);
  u8 mem_val                = p_out_buffer[packed_index];
  u8 mem_val_cleaned        = X_POSITION_INVERTED_MASKS[packed_position] & mem_val;
  write_flush_u8((u8*)(p_out_buffer + packed_index), mem_val_cleaned | packed_val);

  // if (ib==1 && packed_index >= 356) debug_printf("index:%d, final_val:%d --- position:%d value:%d packed_val:%d, mem_val:%d, mem_val_cleaned:%d, clean_mask:%d, pos_mask:%d \n", packed_index, mem.debug_packed[packed_index], packed_position, val, packed_val, mem_val, mem_val_cleaned, X_BITS_MASK, X_POSITION_INVERTED_MASKS[packed_position]);
}


static inline void tile_write( i32 out_val, i8 *p_out_buffer, i32 ib, Bundle_t *pb, i32 i_yn, i32 i_yh, i32 i_yw, i32 i_yc, i32 yn, i32 yh, i32 yw, i32 yc ) {

  // ------ FLATTEN ------
  if (pb->is_flatten) {
    i_yc = (i_yh*yw + i_yw)*yc + i_yc;  // (H*W*C) -> C
    i_yw = 0;                           // W=1
    i_yh = i_yn;                        // N -> H
    i_yn = 0;                           // N=1

    yc = yh*yw*yc;
    yw = 1;
    yh = yn;
    yn = 1;
  }

  i32 iy_nhwc = flatten_nhwc(i_yn,i_yh,i_yw,i_yc, pb->on,pb->oh,pb->ow,pb->oc,,);
#ifndef NDEBUG
  mem.debug_nhwc[iy_nhwc] = out_val;
#endif
 // ------ STORE IN NHWC  ------

  if (ib == N_BUNDLES-1) {
    mem.y[iy_nhwc] = out_val; // Last bundle: save as NHWC
    return;
  }

  // Store for residual add
  if (pb->add_out_buffer_idx != -1)
    mem.add_buffers[pb->add_out_buffer_idx][iy_nhwc] = (i8)out_val;

  // If output only goes to residual add, early return
  Bundle_t* pb_out;
  if (pb->ib_out == -1)
    return;
  else
    pb_out = &bundles[pb->ib_out];
    

  // ------ TILING: Calculate X coordinates ------
  // y [n,h,w,c] -> x[p, n, l, w,cmp, r+pad]

  i8 yp_first  = i_yc < pb_out->cm_p0;

  div_t div_oh  = div(i_yh, PE_ROWS);
  i32   i_yr    = div_oh.rem;
  i32   i_yl    = div_oh.quot;

  div_t div_oc    = div(i_yc-pb_out->cm_p0, pb_out->cm);
  i32   i_yp      = yp_first ? 0             : div_oc.quot + 1;
  i32   i_ycm     = yp_first ? i_yc          : div_oc.rem;
  i32   ycm       = yp_first ? pb_out->cm_p0 : pb_out->cm  ;

  // ------ STORE FOR NEXT BUNDLE  ------
  // Other bundles: pad & save as tiled
  i32 yr_sweep = i_yh==yh-1 ? PE_ROWS : i_yr + 1;

  for (i32 i_yr_dest = i_yr; i_yr_dest < yr_sweep; i_yr_dest++) {
    write_x(out_val, p_out_buffer, ib, i_yp, i_yn, i_yl, i_yw, i_ycm, i_yr_dest,   pb_out, ycm);

    // --- PADDING: the [bottom x_pad rows of previous block (l-1)] with [first x_pad rows of this block (l)]
    if (i_yr_dest < pb_out->x_pad) {
      i32 pad_val = (i_yl == 0) ? 0         : out_val;
      i32 dest_yl = (i_yl == 0) ? pb_out->l-1 : i_yl-1;
      write_x(pad_val, p_out_buffer, ib, i_yp, i_yn, dest_yl, i_yw, i_ycm, i_yr_dest+PE_ROWS,   pb_out, ycm);
    }
    out_val = 0;
  }
  
}

extern EXT_C u8 model_run() {

  static Bundle_t *pb = &bundles[0];
  static i32 it_bias=0;
  static i32 ib=0, ip=0, it=0, in=0, il=0, iw_kw2=0;
  static i8  *p_out_buffer = (i8*)&mem.out_buffers[0];

  i32   iy_nhwc;
  div_t div_ch, div_cw, div_ixh, div_ixw;
  i32   ph_end, ph_beg_const, ixh_beg, xh_sweep;
  i32   pw_end, pw_beg_const, ixw_beg, xw_sweep;

  static i8 ocm_bank = 1; // We flip the bank at the beginning of loop. starting from bank 0
  i32 w_last, sram_addr;


  /**
   * ---------- WAIT FOR S2MM DMA DONE ----------
   *
   * When running on hardware, we wait for DMA's interrupt at "DMA_WAIT"
   * But Verilator cannot pass simulation time when "waiting"
   * Therefore,
      * During simulation, this function gets called again and again
      * On first call, values are set and returned before processing.
      * On subsequent calls, function skips to DMA_WAIT, and starts processing
      * This mimics the behavior of waiting for DMA's interrupt
  */
#ifdef SIM
  static char is_first_call = 1;
  if (is_first_call)  is_first_call = 0;
  else                goto DMA_WAIT;

#endif

  debug_printf("Starting model_run()\n");
  set_config(4*A_START, 1); 

  for (ib = 0; ib < N_BUNDLES; ib++) {

    pb = &bundles[ib];
    p_out_buffer = (i8*)&mem.out_buffers[pb->out_buffer_idx];

    // Init - add headers to out buffer
    if (ib != N_BUNDLES-1 && pb->ib_out != -1) {
      Bundle_t *pb_out = &bundles[pb->ib_out];
      for (int ixp=0; ixp < pb_out->p; ixp++) {
        i32 offset_words   = (ixp == 0) ? 0 : (pb_out->cm_p0 + (ixp-1)*pb_out->cm)*pb_out->xp_words;
        i32 offset_bytes   = offset_words/X_WORDS_PER_BYTE + ixp*(AXI_WIDTH/8);
        u64 *p_header = (u64*)&(p_out_buffer[offset_bytes]);
        write_flush_u64(p_header+0, ixp == 0 ? pb_out->x_header_p0 : pb_out->x_header);
        if (AXI_WIDTH == 128)
          write_flush_u64(p_header+1, (u64)0);
        // debug_printf("--------ib:%d, ixp:%d offset_bytes:%d\n", ib, ixp, offset_bytes);
      }
    }

    for (ip = 0; ip < pb->p; ip++) {
      for (it = 0; it < pb->t; it++) {

        it_bias = pb->b_offset + pb->coe*it;

        for (in = 0; in < pb->n; in++) {
          for (il = 0; il < pb->l; il++) {
            for (iw_kw2 = 0; iw_kw2 < pb->w_kw2; iw_kw2++) {
              
              ocm_bank = !ocm_bank;
              w_last = iw_kw2 == pb->w_kw2-1 ? pb->kw/2+1 : 1;

#ifdef SIM
DMA_WAIT:
              // if sim return, so SV can pass time, and call again, which will jump to DMA_WAIT again
	            if (!get_config(4*(A_DONE_WRITE + ocm_bank))) 
	              return 1; 

              char f_path_raw [1000], f_path_sum  [1000]; // make sure full f_path_raw is shorter than 1000
              sprintf(f_path_raw, "%s/%0d_%0d_%0d_y_raw_sim.txt", DATA_DIR, ib, ip, it);
              sprintf(f_path_sum, "%s/%0d_y_sum_sim.txt", DATA_DIR, ib);
              FILE *fp_raw = fopen(f_path_raw, "a");
              FILE *fp_sum = fopen(f_path_sum, "a");
#else
        		// in FPGA, wait for write done
		          while (!get_config(4*(A_DONE_WRITE + ocm_bank))){
              };
              //while(false);
              usleep(0);
#endif
              set_config(4*(A_DONE_WRITE + ocm_bank), 0);

#ifdef NDEBUG
              // Flush the data just written by the PS to the DDR
              flush_cache(&ocm[ocm_bank], PE_ROWS*PE_COLS*sizeof(Y_TYPE)) ;
#endif
              w_last = iw_kw2 == pb->w_kw2-1 ? pb->kw/2+1 : 1;
              sram_addr=0;

              for (i32 icoe=0; icoe < pb->coe; icoe++) {
                i32 i_bias = it_bias + icoe;

                for (i32 iw_last=0; iw_last<w_last; iw_last++) {
                  for (i32 ir=0; ir<PE_ROWS; ir++) {
                    // Indexing: [b, p, t, n, l, w | coe, w_last, r]

#define DEBUG_INFO "--- ib:%d ip:%d it:%d in:%d il:%d iw_kw2:%d icoe:%d iw_last:%d ir:%d \n",ib,ip,it,in,il,iw_kw2,icoe,iw_last,ir

                    i32 raw_val=0, out_val=0;

                    // Caculate y_index
                    i32 i_yn = in;
                    i32 i_yh = il*PE_ROWS + ir;
                    i32 i_yw = iw_kw2 + iw_last;
                    i32 i_yc = pb->coe*it + icoe;

                    // Save y_dims
                    i32 yn = pb->n;
                    i32 yh = pb->h;
                    i32 yw = pb->w;
                    i32 yc = pb->co;

                    // if out of bounds, early return
                    if (i_yh >= yh || i_yc >= yc) {
                      if (ip == pb->p-1)
                        sim_fprintf(fp_sum,"%d\n", 0);        // Save summed output
                      goto PROCESS_AND_STORE_DONE;
                    }

                    raw_val = ocm[ocm_bank][sram_addr];
                    out_val = raw_val;

//PROCESS_START:

                    // ------ ADD P PASSES ------
                    iy_nhwc = flatten_nhwc(i_yn,i_yh,i_yw,i_yc, yn,yh,yw,yc, "Before add P passes", DEBUG_INFO);

                    if (pb->p == 1) {          // only p  : proceed with value
                    } else if (ip == pb->p-1) {// last p  : read, add, proceed
                      out_val += mem.nhwc[iy_nhwc];
                    } else if (ip == 0) {            // first p : overwrite memory, return
                      mem.nhwc[iy_nhwc] = out_val;
                      goto PROCESS_AND_STORE_DONE;
                    } else {                         // middle p: read, add, store, return
                      mem.nhwc[iy_nhwc] += out_val;
                      goto PROCESS_AND_STORE_DONE;
                    }
                    sim_fprintf(fp_sum,"%d\n", out_val); // Save summed output

                    // ------ CONV STRIDING ------
                    div_ch = div(i_yh-pb->csh_shift, pb->csh);
                    div_cw = div(i_yw-pb->csw_shift, pb->csw);

                    if (div_ch.rem != 0 || div_cw.rem != 0)
                      goto PROCESS_AND_STORE_DONE;

                    i_yh = div_ch.quot; // update indices and dimensions
                    i_yw = div_cw.quot;
                    yh   = pb->ch;
                    yw   = pb->cw;

                    // ------ ADD BIAS ------
                    if (pb->is_bias)
                      out_val = (out_val << pb->b_val_shift) + (mem.b[i_bias] << pb->b_bias_shift);


                    // ------ CORE ACT ------
                    out_val = quant_lrelu(out_val, pb->ca_nzero, pb->ca_shift, pb->ca_pl_scale);

                    // ------ RESIDUAL ADD ---

                    if (pb->add_in_buffer_idx != -1) {
                      iy_nhwc = flatten_nhwc(i_yn,i_yh,i_yw,i_yc, yn,yh,yw,yc, "Before add", DEBUG_INFO);// store as nhwc for pooling
                      out_val += mem.add_buffers[pb->add_in_buffer_idx][iy_nhwc];
                      out_val = quant_lrelu(out_val, pb->aa_nzero, pb->aa_shift, pb->aa_pl_scale);
                    }

                    // ------ SOFTMAX ------

                    if (pb->is_softmax) {
                      assert_printf (ib , !=, N_BUNDLES, "Softmax is only allowed for the last bundle.", DEBUG_INFO);

                      f32 val = (f32)out_val;
                      val = val / (f32)(1 << pb->softmax_frac);
                      val = val - pb->softmax_max_f;
                      val = (f32)exp(val);
                      mem.y[iy_nhwc] = val;

                      if (i_yc == pb->co-1) {
                        f32 sum = 0;
                        i32 iy_nhwc;
                        for (int i=0; i<pb->co; i++){
                          iy_nhwc = flatten_nhwc(i_yn,i_yh,i_yw,i, yn,yh,yw,yc, "Before softmax sum", DEBUG_INFO);
                          sum += mem.y[iy_nhwc];
                        }
                        for (int i=0; i<pb->co; i++){
                          iy_nhwc = flatten_nhwc(i_yn,i_yh,i_yw,i, yn,yh,yw,yc, "After softmax sum", DEBUG_INFO);
                          mem.y[iy_nhwc] = mem.y[iy_nhwc] / sum;
                        }
                      }
                      goto PROCESS_AND_STORE_DONE;
                    }

                    // ------ MAX/AVG POOL ---

                    if (pb->pool == POOL_NONE) {
                      tile_write(out_val, p_out_buffer, ib, pb, i_yn, i_yh, i_yw, i_yc, yn, yh, yw, yc);
                      goto PROCESS_AND_STORE_DONE;
                    }

                    iy_nhwc = flatten_nhwc(i_yn,i_yh,i_yw,i_yc, yn,yh,yw,yc, "Before maxpool", DEBUG_INFO);// store as nhwc for pooling
                    mem.nhwc[iy_nhwc] = out_val;

                    div_ixh = div(i_yh+pb->psh_shift-pb->pkh+1, pb->psh);
                    div_ixw = div(i_yw+pb->psw_shift-pb->pkw+1, pb->psw);
                    ixh_beg = div_ixh.quot; // ix(hw) that corresponds to the pooling window
                    ixw_beg = div_ixw.quot;

                    if (ixh_beg < 0 || ixw_beg < 0) // skip when target ix(h,w) < 0
                      goto PROCESS_AND_STORE_DONE;

                    // Pool Striding
                    if (div_ixh.rem != 0) {                       // invalid ixh
                      if (i_yh==yh-1) ixh_beg += 1;                  //but last yh. start sweeping
                      else            goto PROCESS_AND_STORE_DONE;   // not last yh. skip
                    }

                    if (div_ixw.rem != 0) {
                      if (i_yw==yw-1) ixw_beg += 1;
                      else            goto PROCESS_AND_STORE_DONE;
                    }

                    ph_end       = i_yh; // iy(h,w) is the bottom-right of pooling window -> All values in pooling window have been computed
                    pw_end       = i_yw;
                    ph_beg_const = max(pb->psh*ixh_beg-pb->psh_shift, 0)-1; // p(h,w)_beg is the index of top left corner of pooling window. If negative, set to zero
                    pw_beg_const = max(pb->psw*ixw_beg-pb->psw_shift, 0)-1;

                    xh_sweep = i_yh == yh-1 ? pb->ph : ixh_beg+1; // ix(hw) is sweeped from ix(hw)_beg to x(h,w)_sweep. Normally sweep is 1.
                    xw_sweep = i_yw == yw-1 ? pb->pw : ixw_beg+1; // But when iy(h,w) is at its edges, need to compute remaining ix(hw) pixels by sweeping

                    // Sweep the pooling window
                    for (i32 ixh = ixh_beg, ph_beg = ph_beg_const;  ixh < xh_sweep;  ixh++, ph_beg += pb->psh) {
                      for (i32 ixw = ixw_beg, pw_beg = pw_beg_const;  ixw < xw_sweep;  ixw++, pw_beg += pb->psw) {

                        // Traverse each pool window & perform pooling
                        i32 result = pb->pool == POOL_MAX ? INT_MIN : 0;
                        for (i32 ipyh = ph_end; ipyh > ph_beg; ipyh--){
                          for (i32 ipyw = pw_end; ipyw > pw_beg; ipyw--){

                            i32 read_idx = flatten_nhwc(i_yn, ipyh, ipyw, i_yc,    yn, yh, yw, yc, "Inside pool window", DEBUG_INFO);
                            i32 read_val = mem.nhwc[read_idx];
                            result = pb->pool==POOL_MAX ? max(result, read_val) : (result + read_val);
                          }
                        }

                        // ------ AVG POOL: Divide & Activation ------
                        if (pb->pool == POOL_AVG) {
                          i32 count  = (ph_end-ph_beg)*(pw_end-pw_beg);
                          result = div_round(result, count);
                          out_val = quant_lrelu(out_val, pb->pa_nzero, pb->pa_shift, pb->pa_pl_scale);
                        }

                        tile_write(result, p_out_buffer, ib, pb,   i_yn, ixh, ixw, i_yc,  yn, pb->ph, pb->pw, yc); // Write
                      }
                    }
                    yh = pb->ph;
                    yw = pb->pw;


PROCESS_AND_STORE_DONE:

                    sim_fprintf(fp_raw,"%d\n", raw_val); // Save raw output
                    sram_addr += 1;
                  }
                }
              }
#ifdef SIM
              fclose(fp_sum);
              fclose(fp_raw);
#endif
              set_config(4*(A_DONE_READ + ocm_bank), 1);
              // debug_printf("-------- iw_kw2 0x%x done \n", iw_kw2);
            } // iw_kw2
            iw_kw2 = 0;
            // debug_printf("-------- il %x done\n", il);
          } // il
          il = 0;
          // debug_printf("-------- in %x done\n", in);
        } // in
        in = 0;
        debug_printf("------ it %x done\n", it);
      } // it
      it = 0;
      debug_printf("--- ip %x done\n", ip);
    } // ip
    
    ip = 0;

    debug_printf("- done bundle!! ib:%x\n", ib);

#ifdef SIM
    char f_path_debug [1000];
    sprintf(f_path_debug, "%s/%0d_y_nhwc_sim.txt", DATA_DIR, ib);
    FILE *fp_debug = fopen(f_path_debug, "w");
    for (i32 i=0; i<pb->debug_nhwc_words; i++)
      sim_fprintf(fp_debug,"%d\n", mem.debug_nhwc[i]);
    fclose(fp_debug);

    char f_path_tiled [1000];
    sprintf(f_path_tiled, "%s/%0d_y_tiled_sim.txt", DATA_DIR, ib);
    FILE *fp_tiled = fopen(f_path_tiled, "w");
    for (i32 i=0; i<pb->o_words; i++)
      if (ib == N_BUNDLES-1)
        if (pb->is_softmax) sim_fprintf(fp_tiled,"%f\n", (f32  )mem.y[i]);
        else                sim_fprintf(fp_tiled,"%d\n", (i32)mem.y[i]);
      else sim_fprintf(fp_tiled,"%d\n", mem.debug_tiled[i]);
    fclose(fp_tiled);

    if (ib != N_BUNDLES-1){
      char f_path_packed [1000];
      sprintf(f_path_packed, "%s/%0d_y_packed_sim.bin", DATA_DIR, ib);
      FILE *fp_packed = fopen(f_path_packed, "wb");
      fwrite(p_out_buffer, 1, pb->o_bytes, fp_packed);
      fclose(fp_packed);
    }
#endif
  set_config(4*A_BUNDLE_DONE, 1);
  } // ib
  ib = 0;
  debug_printf("done all bundles!!\n");  
#ifdef SIM
  is_first_call = 1;
#endif
  return 0;
}


// Rest of the helper functions used in simulation.
#ifdef SIM

extern EXT_C void sim_fill_memory (){
  FILE *fp;
  char f_path [1000];

  sprintf(f_path, "%s/wbx.bin", DATA_DIR);
  fp = fopen(f_path, "rb");
  debug_printf("DEBUG: Reading from file %s \n", f_path);
  if(!fp)
    debug_printf("ERROR! File not found: %s \n", f_path);
  int bytes = fread(mem.w, 1, WB_BYTES+X_BYTES, fp);
  fclose(fp);
}

extern EXT_C u64 embdded_to64(u32 addr){
  return (u64)addr - (u64)MEM_BASEADDR + (u64)&mem;
}

extern EXT_C u8 get_byte (u64 addr){
  return *(u8*)addr;
}

extern EXT_C u8 get_byte_32 (u32 addr_32){
  u64 addr = embdded_to64(addr_32);
  u8 val = *(u8*)addr;
  //debug_printf("get_byte_32: addr32:0x%x, addr64:0x%lx, val:0x%x\n", addr_32, addr, val);
  return val;
}

extern EXT_C void set_byte (u64 addr, u8 data){
  *(u8*)addr = data;
}

extern EXT_C void set_byte_32 (u32 addr_32, u8 data){
  u64 addr = embdded_to64(addr_32);
  *(u8*)addr = data;
}
#endif

extern EXT_C void model_setup(){

#ifdef SIM
  sim_fill_memory();
#endif
  flush_cache(&mem.w, WB_BYTES+X_BYTES);  // force transfer to DDR, starting addr & length

  // Write registers in controller
  set_config(4*A_START, 0);  // Start
  set_config(4*(A_DONE_READ+0), 1);  // Done read ocm bank 0
  set_config(4*(A_DONE_READ+1), 1);  // Done read ocm bank 1
  set_config(4*(A_DONE_WRITE+0), 0);  // Done write ocm bank 0
  set_config(4*(A_DONE_WRITE+1), 0);  // Done write ocm bank 1
  set_config(4*(A_OCM_BASE+0), to_embedded(ocm[0]));  // Base addr ocm bank 0
  set_config(4*(A_OCM_BASE+1), to_embedded(ocm[1]));  // Base addr ocm bank 1
  set_config(4*A_WEIGHTS_BASE, to_embedded(mem.w));  // Base adddr weights
  set_config(4*A_BUNDLE_DONE, 1);  // Bundle done (?)
  set_config(4*A_N_BUNDLES_1, N_BUNDLES);  // Number of bundles
  set_config(4*A_W_DONE, 0);  // Weigths done
  set_config(4*A_X_DONE, 0);  // Bundle done
  set_config(4*A_O_DONE, 0);  // Output done

  // Write into BRAM the config for controller
  i32 parameters[8*N_BUNDLES];
  for (int var = 0; var < N_BUNDLES; var++){
    parameters[8*var] = (var == 0) ? to_embedded(mem.x) : to_embedded(mem.out_buffers[bundles[var].in_buffer_idx]);       // x_base address
    parameters[8*var+1] = bundles[var].x_bpt_p0;  // x_bpt0
    parameters[8*var+2] = bundles[var].x_bpt;     // x_bpt
    parameters[8*var+3] = bundles[var].w_bpt_p0;  // w_bpt0
    parameters[8*var+4] = bundles[var].w_bpt;     // w_bpt
    parameters[8*var+5] = bundles[var].p;         // max p
    parameters[8*var+6] = bundles[var].t;         // max t
    parameters[8*var+7] = 0;                      // blank
  }
  for (int var = 0; var < 8*N_BUNDLES; var++){
    set_config(4*(16+var), parameters[var]);
  }
}
