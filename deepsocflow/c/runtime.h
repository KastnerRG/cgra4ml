#ifndef RISCV
  #include <assert.h>
  #include <stdlib.h>
  #include <stdio.h>
  #include <math.h>
#endif
#include <limits.h>
#include <stdint.h>

typedef int8_t   i8 ;
typedef int16_t  i16;
typedef int32_t  i32;
typedef int64_t  i64;
typedef uint8_t  u8 ;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;

typedef struct { int quot; int rem; } idiv_t;
static inline idiv_t idiv(int numer, int denom) {
  idiv_t r; 
  r.quot = numer / denom; 
  r.rem = numer % denom; 
  return r;
}

typedef const struct {
  const u16  n, l, kw, coe, h, w, ci, co, w_kw2, t, p, cm, cm_p0, on, oh, ow, oc, ch, ph, cw, pw, pkh, psh, pkw, psw;
  const i32  xp_words, b_offset, w_bpt, w_bpt_p0, x_bpt, x_bpt_p0, o_words, o_bytes, w_buf_wr_offset;
  const i8   ib_out, in_buffer_idx, out_buffer_idx, add_out_buffer_idx, add_in_buffer_idx;
  const i8   out_w_buffer_idx, in_w_buffer_idx; // dynamic weight buffers: producer writes w_bufs[out_w_buffer_idx]; consumer reads via b_offset into w_bufs[in_w_buffer_idx]
  const i8   out_w_consumer_ib; // ib of the bundle that reads this bundle's output as weights (-1 = none)
  const i8   is_bias, is_pool, is_flatten, is_softmax, transpose_w_src;
  const i8   x_pad, b_val_shift, b_bias_shift, ca_nzero, ca_shift, ca_pl_scale, aa_nzero, aa_shift, aa_pl_scale, pa_nzero, pa_shift, pa_pl_scale, softmax_frac;
  const i8   csh, csh_shift, psh_shift, csw, csw_shift, psw_shift, pool;
  const i32  softmax_max_i;
  const u64  header;
  const i32  debug_nhwc_words;
} Bundle_t;

typedef enum {POOL_NONE, POOL_MAX, POOL_AVG} Pool_t;

#include "config_fw.h"

#define f32__ O_TYPE
#define X_BITS            (1 << X_BITS_L2)
#define X_WORDS_PER_BYTE  (8 / X_BITS)
#define X_BITS_MASK       ((1 << X_BITS) -1)
#define W_BITS            (1 << W_BITS_L2)
#define W_WORDS_PER_BYTE  (8 / W_BITS)
#define W_BITS_MASK       ((1 << W_BITS) - 1)
#ifdef SIM
  #define XDEBUG
  void usleep(int x) {}
#endif

typedef struct {
  // These can be kept in DDR
  i8     w              [W_BYTES     ]; // includes dynamic weight regions at sequential bundle positions
  B_TYPE b              [B_WORDS     ]; // keep next to w. weights are loaded to w_ptr
  i8     x              [X_BYTES     ]; // keep next to wb. wbx is loaded to w_ptr
  O_TYPE y              [O_WORDS     ];
  
  // These are written often, keep them on OCM
  Y_TYPE ocm            [2][PE_COLS*PE_ROWS];
  i32    nhwc           [NHWC_WORDS  ];
  float  softmax_tmp    [NHWC_WORDS  ];
  i8     out_buffers    [N_OUT_BUF   ][O_BYTES_MAX ];
  
#ifdef XDEBUG
  int8_t  debug_tiled    [O_WORDS_MAX ];
  int32_t debug_nhwc     [NHWC_WORDS  ];
#endif
  int8_t  add_buffers    [N_ADD_BUF   ][NHWC_WORDS  ]; // should be last, since N_ADD_BUF can be empty
} Memory_st;

#include "fb_fw_wrap.h"

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

int32_t *p_config = (int32_t *)CONFIG_BASEADDR;

extern EXT_C void model_setup(Memory_st *restrict mp) {
#ifdef SIM
  FILE *fp;
  char f_path [1000];
  sprintf(f_path, "%s/wbx.bin", DATA_DIR);
  fp = fopen(f_path, "rb");
  debug_printf("DEBUG: Reading from file %s \n", f_path);
  if(!fp) debug_printf("ERROR! File not found: %s \n", f_path);
  int bytes = fread(mp->w, 1, WB_BYTES+X_BYTES, fp);
  fclose(fp);
#endif
  flush_cache(mp->w, WB_BYTES+X_BYTES);  // force transfer to DDR, starting addr & length
  //flush_cache(mp->w, WB_BYTES + N_W_BUF * W_BUF_BYTES_MAX + X_BYTES);


  // Write registers in controller
  fb_write_reg32(p_config + A_START       , 0);  // Start
  fb_write_reg32(p_config + A_DONE_READ +0, 1);  // Done read mp->ocm bank 0
  fb_write_reg32(p_config + A_DONE_READ +1, 1);  // Done read mp->ocm bank 1
  fb_write_reg32(p_config + A_DONE_WRITE+0, 0);  // Done write mp->ocm bank 0
  fb_write_reg32(p_config + A_DONE_WRITE+1, 0);  // Done write mp->ocm bank 1
  fb_write_reg32(p_config + A_OCM_BASE  +0, fb_addr_64to32(mem_phy.ocm[0]));  // Base addr mp->ocm bank 0
  fb_write_reg32(p_config + A_OCM_BASE  +1, fb_addr_64to32(mem_phy.ocm[1]));  // Base addr mp->ocm bank 1
  fb_write_reg32(p_config + A_WEIGHTS_BASE, fb_addr_64to32(mem_phy.w));  // Base adddr weights
  fb_write_reg32(p_config + A_BUNDLE_DONE , 1);  // Bundle done writing (pixel dma waits for this)
  fb_write_reg32(p_config + A_N_BUNDLES_1 , N_BUNDLES);  // Number of bundles
  fb_write_reg32(p_config + A_W_DONE      , 0);  // Weigths done
  fb_write_reg32(p_config + A_X_DONE      , 0);  // Bundle done
  fb_write_reg32(p_config + A_O_DONE      , 0);  // Output done

  // Write into BRAM the config for controller
  i32 parameters[8*N_BUNDLES];
  for (int var = 0; var < N_BUNDLES; var++){
    parameters[8*var] = (bundles[var].in_buffer_idx == -1) ? fb_addr_64to32(mem_phy.x) : fb_addr_64to32(mem_phy.out_buffers[bundles[var].in_buffer_idx]);       // x_base address
    parameters[8*var+1] = bundles[var].x_bpt_p0;  // x_bpt0
    parameters[8*var+2] = bundles[var].x_bpt;     // x_bpt
    parameters[8*var+3] = bundles[var].w_bpt_p0;  // w_bpt0
    parameters[8*var+4] = bundles[var].w_bpt;     // w_bpt

    // ── WEIGHTS DMA CONFIG ────────────────────────────────────────────────
    // The CPU never reads mp->w directly — the hardware DMA does.
    // These parameters tell the DMA controller how many bytes of weights
    // to fetch per iteration. w_bpt_p0 is the first-pass transfer size
    // (may differ if the first tile has fewer channels), w_bpt is all others.
    debug_printf("[model_setup] bundle %d  weights_base=%p"
                 "  w_bpt_p0=%d bytes  w_bpt=%d bytes\n",
        var,
        (var == 0)
            ? (void*)mp->w
            : (void*)(mp->w + bundles[var].b_offset),
        bundles[var].w_bpt_p0,
        bundles[var].w_bpt);
    // ──────────────────────────────────────────────────────────────────────
    assert_printf(bundles[var].p, <, 1<<16, "", "P should be less than 2**16 for bundle:%x", var);
    assert_printf(bundles[var].t, <, 1<<16, "", "T should be less than 2**16 for bundle:%x", var);
    parameters[8*var+5] = (bundles[var].t << 16) + bundles[var].p; // max p
    uint64_t h = bundles[var].header;
    parameters[8*var + 6] = (uint32_t)(h & 0xFFFFFFFFu);
    parameters[8*var + 7] = (uint32_t)(h >> 32);
  }
  for (int var = 0; var < 8*N_BUNDLES; var++){
    fb_write_reg32(p_config + 16+var, parameters[var]);
  }
}

// Helper functions

static inline void write_flush_u8(u8*restrict addr, u8 val) {
  *addr = val; // Leave flushing to the end of bundle
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


static inline void write_x(i8 val, i8 *restrict p_out_buffer, Memory_st *restrict mp, i32 ib, i32 ixp, i32 ixn, i32 ixl, i32 ixw, i32 ixcm, i32 ixr, Bundle_t *restrict pb_out, i32 xcm) {

  #define WRITEX_DEBUG_INFO "--- ib:%d ixp:%d ixn:%d ixl:%d ixw:%d ixcm:%d ixr:%d xcm :%d \n",ib,ixp,ixn,ixl,ixw,ixcm,ixr,xcm
  assert_printf (ixr , <, PE_ROWS+pb_out->x_pad, "write_x", WRITEX_DEBUG_INFO);
  assert_printf (ixcm, <, xcm          , "write_x", WRITEX_DEBUG_INFO);
  assert_printf (ixw , <, pb_out->w    , "write_x", WRITEX_DEBUG_INFO);
  assert_printf (ixl , <, pb_out->l    , "write_x", WRITEX_DEBUG_INFO);
  assert_printf (ixn , <, pb_out->n    , "write_x", WRITEX_DEBUG_INFO);
  assert_printf (ixp , <, pb_out->p    , "write_x", WRITEX_DEBUG_INFO);

  i32 p_offset       = (ixp == 0) ? 0 : (pb_out->cm_p0 + (ixp-1)*pb_out->cm) * pb_out->xp_words;
  i32 flat_index_n2r = (((ixn*pb_out->l + ixl)*pb_out->w + ixw)*xcm + ixcm)*(PE_ROWS+pb_out->x_pad) + ixr; // multidim_index -> flat_index [n,l,w,cm,r]
  i32 flat_index     = p_offset + flat_index_n2r;

#ifdef XDEBUG
  mp->debug_tiled[flat_index] = val;
#endif

  // Pack bits and store
  idiv_t packed_idx = idiv(flat_index, X_WORDS_PER_BYTE);
  assert_printf (packed_idx.quot , <, bundles[ib].o_bytes, "write_x", WRITEX_DEBUG_INFO);

  u8 packed_val      = ((u8)val & X_BITS_MASK) << (packed_idx.rem * X_BITS);
  u8 mem_val         = p_out_buffer[packed_idx.quot];
  u8 mem_val_cleaned = X_POSITION_INVERTED_MASKS[packed_idx.rem] & mem_val;

  // ── GAP 1: write_x byte address and nibble ────────────────────────────
  // flat_index is the logical element index in the tiled layout.
  // packed_idx.quot is the byte offset within out_buffers; packed_idx.rem
  // is which nibble within that byte (0=low, 1=high for 4-bit).
  // dest_addr is the exact byte being written in out_buffers.
  debug_printf("      [WRITE_X] flat=%d  byte_offset=%d  nibble=%d"
               "  dest_addr=%p  packed_val=0x%02x  val=%d\n",
      flat_index,
      packed_idx.quot,
      packed_idx.rem,
      (void*)(p_out_buffer + packed_idx.quot),
      packed_val,
      (int)val);
  // ──────────────────────────────────────────────────────────────────────

  write_flush_u8((u8*)(p_out_buffer + packed_idx.quot), mem_val_cleaned | packed_val);
}


// Write one output element from a producer bundle into the weight-tiled w_buf layout.
// i_ci maps to the CI dimension of the consumer bundle (= i_yh of the producer output).
// i_co maps to the CO dimension of the consumer bundle (= i_yc of the producer output).
#if HAS_DYNAMIC_WEIGHTS
static inline void tile_write_w(
    i8 val, i8 *restrict p_w_buf,
    Bundle_t *restrict pb_c,   // consumer bundle whose weight DMA will read this w_buf
    i32 w_buf_bytes,           // total bytes in the w_buf (= producer's o_bytes)
    i32 i_ci, i32 i_co
) {
  // Map CO → (it, col) with reversed column to match reorder_w_q2e_conv's np.flip
  i32 it  = i_co / pb_c->coe;
  i32 col = pb_c->coe - 1 - (i_co % pb_c->coe);

  // Map CI → (ip, ci_local) across channel passes
  i8  ci_first = (i_ci < pb_c->cm_p0);
  idiv_t div_p = ci_first ? (idiv_t){0, i_ci} : idiv(i_ci - pb_c->cm_p0, pb_c->cm);
  i32 ip       = ci_first ? 0 : div_p.quot + 1;
  i32 ci_local = div_p.rem;   // for ci_first: {0, i_ci}.rem == i_ci
  i32 cm_p     = ci_first ? pb_c->cm_p0 : pb_c->cm;

  // Flat element index in the interleaved [ip][it][ci][col] layout written by xmodel.py:
  //   ip=0 block: t * cm_p0 * PE_COLS elements
  //   ip>0 block: t * cm    * PE_COLS elements each
  i32 elems_before = (ip == 0) ? 0
      : (i32)pb_c->t * pb_c->cm_p0 + (ip - 1) * (i32)pb_c->t * pb_c->cm;
  i32 flat_index = (elems_before + it * cm_p + ci_local) * PE_COLS + col;

  // Pack W_BITS per byte (mirrors write_x() nibble-packing for X_BITS)
  idiv_t pidx = idiv(flat_index, W_WORDS_PER_BYTE);

  #define TILE_WRITE_W_DBG "--- i_ci:%d i_co:%d it:%d ip:%d col:%d flat:%d byte:%d pos:%d\n", \
      i_ci, i_co, it, ip, col, flat_index, pidx.quot, pidx.rem
  assert_printf(pidx.quot, <, w_buf_bytes, "tile_write_w", TILE_WRITE_W_DBG);

  u8 mask   = (u8)((u8)W_BITS_MASK << (pidx.rem * W_BITS));
  u8 packed = (u8)(((u8)val & W_BITS_MASK) << (pidx.rem * W_BITS));
  u8 cur    = p_w_buf[pidx.quot];
  debug_printf("  [TILE_WRITE_W] i_ci=%d i_co=%d -> byte=%d pos=%d  val=%d\n",
      i_ci, i_co, pidx.quot, pidx.rem, (int)val);
  write_flush_u8((u8*)(p_w_buf + pidx.quot), (cur & ~mask) | packed);
}
#endif


static inline void tile_write( i32 out_val, i8 *restrict p_out_buffer, i32 ib, Bundle_t *restrict pb, Memory_st *restrict mp, i32 i_yn, i32 i_yh, i32 i_yw, i32 i_yc, i32 yn, i32 yh, i32 yw, i32 yc ) {

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
#ifdef XDEBUG
  mp->debug_nhwc[iy_nhwc] = out_val;
#endif
 // ------ STORE IN NHWC  ------

  if (ib == N_BUNDLES-1) {
    // ── PRINT 4a: final output write ──────────────────────────────────────
    // Last bundle writes directly into mp->y (the model output array).
    // This value will be read by print_output() after all bundles complete.
    debug_printf("  [TILE_WRITE FINAL] ib=%d iy_nhwc=%d  val=%d"
                 "  -> y_addr=%p\n",
        ib, iy_nhwc, out_val,
        (void*)&mp->y[iy_nhwc]);
    // ──────────────────────────────────────────────────────────────────────
    mp->y[iy_nhwc] = out_val; // Last bundle: save as NHWC
    return;
  }

  // Store for residual add
  if (pb->add_out_buffer_idx != -1) {
    // ── PRINT 4b: residual add buffer write ───────────────────────────────
    // This output value is saved to mp->add_buffers for a later bundle's
    // skip connection. Only fires when add_out_buffer_idx != -1.
    debug_printf("  [TILE_WRITE ADD_BUF] ib=%d add_out_buf=%d iy_nhwc=%d"
                 "  val=%d  add_buf_addr=%p\n",
        ib, pb->add_out_buffer_idx, iy_nhwc, out_val,
        (void*)&mp->add_buffers[pb->add_out_buffer_idx][iy_nhwc]);
    // ──────────────────────────────────────────────────────────────────────
    mp->add_buffers[pb->add_out_buffer_idx][iy_nhwc] = (i8)out_val;
  }

  // If this bundle produces dynamic weights, store in w_buf and return
#if HAS_DYNAMIC_WEIGHTS
  if (pb->out_w_buffer_idx != -1) {
    Bundle_t *restrict pb_c = &bundles[pb->out_w_consumer_ib];
    if (pb_c->transpose_w_src)
      tile_write_w((i8)out_val, p_out_buffer, pb_c, pb->o_bytes, i_yc, i_yh);
    else
      tile_write_w((i8)out_val, p_out_buffer, pb_c, pb->o_bytes, i_yh, i_yc);
    return;
  }
#endif

  // If output only goes to residual add, early return
  Bundle_t*restrict pb_out;
  if (pb->ib_out == -1)
    return;
  else
    pb_out = &bundles[pb->ib_out];
    

  // ------ TILING: Calculate X coordinates ------
  // y [n,h,w,c] -> x[p, n, l, w,cmp, r+pad]

  i8 yp_first  = i_yc < pb_out->cm_p0;

  idiv_t div_oh  = idiv(i_yh, PE_ROWS);
  i32   i_yr    = div_oh.rem;
  i32   i_yl    = div_oh.quot;

  idiv_t div_oc    = idiv(i_yc-pb_out->cm_p0, pb_out->cm);
  i32   i_yp      = yp_first ? 0             : div_oc.quot + 1;
  i32   i_ycm     = yp_first ? i_yc          : div_oc.rem;
  i32   ycm       = yp_first ? pb_out->cm_p0 : pb_out->cm  ;

  // ------ STORE FOR NEXT BUNDLE  ------
  // Other bundles: pad & save as tiled
  i32 yr_sweep = i_yh==yh-1 ? PE_ROWS : i_yr + 1;

  // ── PRINT 5: tiled writeback to out_buffer ────────────────────────────
  // Shows the transformation from NHWC output coordinates to the tiled
  // [p, n, l, w, cm, r] layout that the next bundle's DMA will stream in.
  // p_out_buffer points to mp->out_buffers[pb->out_buffer_idx].
  // yr_sweep > i_yr+1 only on the last row, where padding rows are filled.
  debug_printf("  [TILE_WRITE->NEXT_BUNDLE] ib=%d y[%d,%d,%d,%d]"
               "  -> tiled p=%d l=%d cm=%d r=%d..%d  yr_sweep=%d"
               "  out_buf_base=%p\n",
      ib, i_yn, i_yh, i_yw, i_yc,
      i_yp, i_yl, i_ycm, i_yr, yr_sweep-1, yr_sweep,
      (void*)p_out_buffer);
  // ──────────────────────────────────────────────────────────────────────

  for (i32 i_yr_dest = i_yr; i_yr_dest < yr_sweep; i_yr_dest++) {
    write_x(out_val, p_out_buffer, mp, ib, i_yp, i_yn, i_yl, i_yw, i_ycm, i_yr_dest,   pb_out, ycm);

    // --- PADDING: the [bottom x_pad rows of previous block (l-1)] with [first x_pad rows of this block (l)]
    if (i_yr_dest < pb_out->x_pad) {
      i32 pad_val = (i_yl == 0) ? 0         : out_val;
      i32 dest_yl = (i_yl == 0) ? pb_out->l-1 : i_yl-1;
      write_x(pad_val, p_out_buffer, mp, ib, i_yp, i_yn, dest_yl, i_yw, i_ycm, i_yr_dest+PE_ROWS,   pb_out, ycm);
    }
    out_val = 0;
  }
  
}

extern EXT_C void run(Memory_st *restrict mp) {

  static Bundle_t *restrict pb = &bundles[0];
  static i32 it_bias=0, w_last, o_bpt;
  static i32 ib=0, ip=0, it=0, in=0, il=0, iw_kw2=0;
  static i8 *restrict p_out_buffer = 0;

  i32   iy_nhwc;
  idiv_t div_ch, div_cw, div_ixh, div_ixw;
  i32   ph_end, ph_beg_const, ixh_beg, xh_sweep;
  i32   pw_end, pw_beg_const, ixw_beg, xw_sweep;

  static i8 ocm_bank = 1; // We flip the bank at the beginning of loop. starting from bank 0

  debug_printf("Starting model_setup()\n");
  model_setup(mp);

  debug_printf("model_setup done\n");
  fb_write_reg32(p_config + A_START, 1); 

  for (ib = 0; ib < N_BUNDLES; ib++) {

    pb = &bundles[ib];
#if HAS_DYNAMIC_WEIGHTS
    p_out_buffer = (pb->out_w_buffer_idx != -1)
        ? (i8*)(mp->w) + pb->w_buf_wr_offset
        : (i8*)&(mp->out_buffers[pb->out_buffer_idx]);
#else
    p_out_buffer = (i8*)&(mp->out_buffers[pb->out_buffer_idx]);
#endif

    // ── PRINT 1: bundle header ─────────────────────────────────────────────
    // Shows the static buffer routing baked into config_fw.h for this bundle.
    // in_buffer_idx=-1 means bundle reads from mp->x (raw input), not a ping-pong buffer.
    // out_buffer_idx is which slot in mp->out_buffers this bundle writes into.
    // add_in/add_out_buffer_idx=-1 means no residual skip connection on this bundle.
    debug_printf("\n[BUNDLE %d] in_buf=%d  out_buf=%d  add_in=%d  add_out=%d"
                 "  p=%d  t=%d  n=%d  h=%d  w=%d  co=%d\n",
        ib,
        pb->in_buffer_idx,
        pb->out_buffer_idx,
        pb->add_in_buffer_idx,
        pb->add_out_buffer_idx,
        pb->p, pb->t, pb->n, pb->h, pb->w, pb->co);
    // Input source address: mp->x when in_buffer_idx==-1, mp->out_buffers[in_buffer_idx] otherwise
    void *in_src = (pb->in_buffer_idx == -1)
        ? (void*)mp->x
        : (void*)mp->out_buffers[pb->in_buffer_idx];
    debug_printf("  READ  from: %p  (%s)\n",
        in_src,
        (pb->in_buffer_idx == -1) ? "mp->x (raw input)" : "mp->out_buffers[in_buffer_idx]");
    debug_printf("  WRITE to:   %p  (mp->out_buffers[%d])\n",
        (void*)p_out_buffer,
        pb->out_buffer_idx);
    debug_printf("  mp->x=%p  mp->out_buffers[0]=%p  mp->w=%p  mp->y=%p\n",
        (void*)mp->x,
        (void*)mp->out_buffers[0],
        (void*)mp->w,
        (void*)mp->y);
    // ──────────────────────────────────────────────────────────────────────

    for (ip = 0; ip < pb->p; ip++) {
      for (it = 0; it < pb->t; it++) {

        it_bias = pb->b_offset + pb->coe*it;

        for (in = 0; in < pb->n; in++) {
          for (il = 0; il < pb->l; il++) {
            for (iw_kw2 = 0; iw_kw2 < pb->w_kw2; iw_kw2++) {
              
              ocm_bank = !ocm_bank;
              w_last = iw_kw2 == pb->w_kw2-1 ? pb->kw/2+1 : 1;
              o_bpt = PE_ROWS * pb->coe * w_last * sizeof(Y_TYPE);

              // ── PRINT 2: OCM ping-pong bank flip ──────────────────────────────────
              // Shows the hardware double-buffer handshake each iteration.
              // ocm_bank alternates 0/1. CPU waits for DONE_WRITE on this bank,
              // reads PE outputs out of mp->ocm[ocm_bank], then clears the flag
              // so the CGRA can refill it while the CPU processes the other bank.
              debug_printf("  [b%d ip=%d it=%d in=%d il=%d iw=%d] ocm_bank -> %d"
                           "  o_bpt=%d bytes  ocm_addr=%p\n",
                  ib, ip, it, in, il, iw_kw2, ocm_bank, o_bpt,
                  (void*)mp->ocm[ocm_bank]);
              // ──────────────────────────────────────────────────────────────────────

#ifdef SIM
              char f_path_raw [1000], f_path_sum  [1000]; // make sure full f_path_raw is shorter than 1000
              sprintf(f_path_raw, "%s/%0d_%0d_%0d_y_raw_sim.txt", DATA_DIR, ib, ip, it);
              sprintf(f_path_sum, "%s/%0d_y_sum_sim.txt", DATA_DIR, ib);
              FILE *fp_raw = fopen(f_path_raw, "a");
              FILE *fp_sum = fopen(f_path_sum, "a");
#endif

              while (!fb_read_reg32(p_config + A_DONE_WRITE + ocm_bank))
              {
                // wait
              }; 
              flush_cache(&(mp->ocm[ocm_bank]), o_bpt);
              usleep(0);
              fb_write_reg32(p_config + A_DONE_WRITE + ocm_bank, 0);

              i32 sram_addr=0;
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

                    raw_val = mp->ocm[ocm_bank][sram_addr];
                    out_val = raw_val;

                    // ── GAP 2: OCM per-element read address ───────────────────────────
                    // Connects a specific PE accumulator output at a physical OCM address
                    // to the output tensor coordinate [n,h,w,c] it represents.
                    // sram_addr increments linearly through [icoe, iw_last, ir] order.
                    debug_printf("    [OCM READ] bank=%d sram_addr=%d"
                                 "  elem_addr=%p  raw_val=%d"
                                 "  -> y[%d,%d,%d,%d]\n",
                        ocm_bank, sram_addr,
                        (void*)&mp->ocm[ocm_bank][sram_addr],
                        raw_val,
                        i_yn, i_yh, i_yw, i_yc);
                    // ──────────────────────────────────────────────────────────────────

//PROCESS_START:

                    // ------ ADD P PASSES ------
                    iy_nhwc = flatten_nhwc(i_yn,i_yh,i_yw,i_yc, yn,yh,yw,yc, "Before add P passes", DEBUG_INFO);

                    if (pb->p == 1) {          // only p  : proceed with value
                    } else if (ip == pb->p-1) {// last p  : read, add, proceed
                      out_val += mp->nhwc[iy_nhwc];
                      // ── PRINT 3a: final p-pass ─────────────────────────────────────
                      // All partial sums are accumulated. out_val is now the complete
                      // dot product result before activation. nhwc[] slot is consumed.
                      debug_printf("    [P-PASS FINAL] ib=%d ip=%d iy_nhwc=%d"
                                   "  partial_stored=%d  raw_this=%d  total=%d"
                                   "  nhwc_addr=%p\n",
                          ib, ip, iy_nhwc,
                          mp->nhwc[iy_nhwc] - raw_val, raw_val, out_val,
                          (void*)&mp->nhwc[iy_nhwc]);
                      // ──────────────────────────────────────────────────────────────
                    } else if (ip == 0) {            // first p : overwrite memory, return
                      // ── PRINT 3b: first p-pass ─────────────────────────────────────
                      // First partial sum written to nhwc[]. Execution returns here;
                      // activation/writeback are skipped until the last pass.
                      debug_printf("    [P-PASS FIRST] ib=%d ip=%d iy_nhwc=%d"
                                   "  stored=%d -> nhwc_addr=%p\n",
                          ib, ip, iy_nhwc, out_val,
                          (void*)&mp->nhwc[iy_nhwc]);
                      // ──────────────────────────────────────────────────────────────
                      mp->nhwc[iy_nhwc] = out_val;
                      goto PROCESS_AND_STORE_DONE;
                    } else {                         // middle p: read, add, store, return
                      mp->nhwc[iy_nhwc] += out_val;
                      // ── PRINT 3c: middle p-pass ────────────────────────────────────
                      // Accumulating into nhwc[]. Running total shown after addition.
                      debug_printf("    [P-PASS MID  ] ib=%d ip=%d iy_nhwc=%d"
                                   "  added=%d  running_total=%d  nhwc_addr=%p\n",
                          ib, ip, iy_nhwc, out_val, mp->nhwc[iy_nhwc],
                          (void*)&mp->nhwc[iy_nhwc]);
                      // ──────────────────────────────────────────────────────────────
                      goto PROCESS_AND_STORE_DONE;
                    }
                    sim_fprintf(fp_sum,"%d\n", out_val); // Save summed output

                    // ------ CONV STRIDING ------
                    div_ch = idiv(i_yh-pb->csh_shift, pb->csh);
                    div_cw = idiv(i_yw-pb->csw_shift, pb->csw);

                    if (div_ch.rem != 0 || div_cw.rem != 0)
                      goto PROCESS_AND_STORE_DONE;

                    i_yh = div_ch.quot; // update indices and dimensions
                    i_yw = div_cw.quot;
                    yh   = pb->ch;
                    yw   = pb->cw;

                    // ------ ADD BIAS ------
                    if (pb->is_bias) {
#if B_WORDS > 0
                      // ── GAP 4: bias read from mp->b ───────────────────────────────
                      // Silent until use_bias=True is set on an XDense layer.
                      // b_val_shift scales out_val before addition; b_bias_shift scales
                      // the bias term. Both are fixed-point alignment shifts.
                      debug_printf("    [BIAS READ] ib=%d i_bias=%d"
                                   "  b_val=%d  addr=%p"
                                   "  val_shift=%d  bias_shift=%d  out_before=%d\n",
                          ib, i_bias,
                          (int)mp->b[i_bias],
                          (void*)&mp->b[i_bias],
                          pb->b_val_shift, pb->b_bias_shift,
                          out_val);
                      // ──────────────────────────────────────────────────────────────
                      out_val = (out_val << pb->b_val_shift) + (mp->b[i_bias] << pb->b_bias_shift);
#endif
                    }


                    // ------ CORE ACT ------
                    out_val = quant_lrelu(out_val, pb->ca_nzero, pb->ca_shift, pb->ca_pl_scale);

                    // ------ RESIDUAL ADD ---

                    if (pb->add_in_buffer_idx != -1) {
                      iy_nhwc = flatten_nhwc(i_yn,i_yh,i_yw,i_yc, yn,yh,yw,yc, "Before add", DEBUG_INFO);// store as nhwc for pooling
                      // ── GAP 3: add_buffers read ─────────────────────────────────────
                      // Reads the residual value saved by a previous bundle's
                      // add_out_buffer_idx write. Silent until a skip connection exists.
                      i32 add_val = mp->add_buffers[pb->add_in_buffer_idx][iy_nhwc];
                      debug_printf("    [ADD_BUF READ] ib=%d add_in_buf=%d iy_nhwc=%d"
                                   "  add_val=%d  addr=%p  out_before=%d\n",
                          ib, pb->add_in_buffer_idx, iy_nhwc,
                          add_val,
                          (void*)&mp->add_buffers[pb->add_in_buffer_idx][iy_nhwc],
                          out_val);
                      // ──────────────────────────────────────────────────────────────
                      out_val += add_val;
                      out_val = quant_lrelu(out_val, pb->aa_nzero, pb->aa_shift, pb->aa_pl_scale);
                    }

                    // ------ SOFTMAX ------

                    if (pb->is_softmax) {
                      iy_nhwc = flatten_nhwc(i_yn,i_yh,i_yw,i_yc, yn,yh,yw,yc, "Before softmax store", DEBUG_INFO);
                      mp->softmax_tmp[iy_nhwc] = expf(  (float)out_val         / (float)(1<<pb->softmax_frac)
                                                       - (float)pb->softmax_max_i / (float)(1<<17));

                      if (i_yc == pb->co-1) {
                        i32 base = flatten_nhwc(i_yn,i_yh,i_yw,0, yn,yh,yw,yc, "softmax base", DEBUG_INFO);
                        float sum = 0;
                        for (int i=0; i<pb->co; i++)
                          sum += mp->softmax_tmp[base + i];
                        float inv_sum = 1.0f / sum;
                        for (int i=0; i<pb->co; i++) {
                          float sm = mp->softmax_tmp[base + i] * inv_sum;
                          if (ib == N_BUNDLES-1) {
                            mp->y[base + i] = (O_TYPE)sm;
                          } else {
                            i32 q = (i32)(sm * (float)(1<<(X_BITS-1)) + 0.5f);
                            q = clip(q, -(1<<(X_BITS-1)), (1<<(X_BITS-1))-1);
                            tile_write(q, p_out_buffer, ib, pb, mp, i_yn, i_yh, i_yw, i, yn, yh, yw, yc);
                          }
                        }
                      }
                      goto PROCESS_AND_STORE_DONE;
                    }

                    // ------ MAX/AVG POOL ---

                    if (pb->pool == POOL_NONE) {
                      tile_write(out_val, p_out_buffer, ib, pb, mp, i_yn, i_yh, i_yw, i_yc, yn, yh, yw, yc);
                      goto PROCESS_AND_STORE_DONE;
                    }

                    iy_nhwc = flatten_nhwc(i_yn,i_yh,i_yw,i_yc, yn,yh,yw,yc, "Before maxpool", DEBUG_INFO);// store as nhwc for pooling
                    mp->nhwc[iy_nhwc] = out_val;

                    div_ixh = idiv(i_yh+pb->psh_shift-pb->pkh+1, pb->psh);
                    div_ixw = idiv(i_yw+pb->psw_shift-pb->pkw+1, pb->psw);
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
                            i32 read_val = mp->nhwc[read_idx];
                            result = pb->pool==POOL_MAX ? max(result, read_val) : (result + read_val);
                          }
                        }

                        // ------ AVG POOL: Divide & Activation ------
                        if (pb->pool == POOL_AVG) {
                          i32 count  = (ph_end-ph_beg)*(pw_end-pw_beg);
                          result = div_round(result, count);
                          out_val = quant_lrelu(out_val, pb->pa_nzero, pb->pa_shift, pb->pa_pl_scale);
                        }

                        tile_write(result, p_out_buffer, ib, pb, mp,   i_yn, ixh, ixw, i_yc,  yn, pb->ph, pb->pw, yc); // Write
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
              fb_write_reg32(p_config + A_DONE_READ + ocm_bank, 1);
              debug_printf("%d-------- iw_kw2 %d done \n", ib, iw_kw2);
            } // iw_kw2
            debug_printf("%d-------- il %d done\n", ib, il);
          } // il
          debug_printf("%d-------- in %d done\n", ib, in);
        } // in
        debug_printf("%d------ it %d done\n", ib, it);
      } // it
      debug_printf("%d--- ip %d done\n", ib, ip);
    } // ip
    debug_printf("%d- done bundle!! ib:%d\n", ib, ib);

#ifdef SIM
    char f_path_debug [1000];
    sprintf(f_path_debug, "%s/%0d_y_nhwc_sim.txt", DATA_DIR, ib);
    FILE *fp_debug = fopen(f_path_debug, "w");
    for (i32 i=0; i<pb->debug_nhwc_words; i++)
      sim_fprintf(fp_debug,"%d\n", mp->debug_nhwc[i]);
    fclose(fp_debug);

    char f_path_tiled [1000];
    sprintf(f_path_tiled, "%s/%0d_y_tiled_sim.txt", DATA_DIR, ib);
    FILE *fp_tiled = fopen(f_path_tiled, "w");
    for (i32 i=0; i<pb->o_words; i++)
      if (ib == N_BUNDLES-1) sim_fprintf(fp_tiled,"%d\n", (i32)(mp->y[i] * (1 << 17)));
      else sim_fprintf(fp_tiled,"%d\n", mp->debug_tiled[i]);
    fclose(fp_tiled);

    if (ib != N_BUNDLES-1){
      char f_path_packed [1000];
      sprintf(f_path_packed, "%s/%0d_y_packed_sim.bin", DATA_DIR, ib);
      FILE *fp_packed = fopen(f_path_packed, "wb");
      fwrite(p_out_buffer, 1, pb->o_bytes, fp_packed);
      fclose(fp_packed);
    }
#endif
  flush_cache(p_out_buffer, pb->o_bytes);
  fb_write_reg32(p_config + A_BUNDLE_DONE, 1);
  } // ib
  debug_printf("done all bundles!!\n");
}


extern EXT_C void print_output (Memory_st *restrict mp) {
  flush_cache(mp->y, sizeof(mp->y));
  for (int i=0; i<O_WORDS; i++){
    int val_1000 = (int)(1000 * mp->y[i]);
    printf("y[%d]: %d/1000 \n", i, val_1000);
  }
}
