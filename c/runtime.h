#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include <limits.h>
#include <stdint.h>

#ifdef VERILATOR
  #define EXT_C "C"
#else
  #define EXT_C
#endif

typedef const struct {
  const int32_t  n, l, kw, coe, coe_tl, r_ll, h, w, ci, co, w_kw2, t, p, cm, cm_p0, xp_words, out_buffer_idx;
  const int32_t  w_bpt, w_bpt_p0, x_bpt, x_bpt_p0, o_words, o_bytes; // bytes per transfer
  const int8_t   is_bias, is_pool, is_flatten;
  const int32_t  b_offset, b_val_shift, b_bias_shift;
  const int8_t   ca_nzero, ca_shift, ca_pl_scale;
  const int32_t  csh, ch, csh_shift, pkh, psh, ph, psh_shift, csw, cw, csw_shift, pkw, psw, pw, psw_shift, pool, on, oh, ow, oc;
  const uint64_t x_header, x_header_p0, w_header, w_header_p0; // 64 bits (at least)
  const int32_t  debug_nhwc_words;
} Bundle_t;

typedef enum {POOL_NONE, POOL_MAX, POOL_AVG} Pool_t;

#include "model.h"
#define X_BITS            (1 << X_BITS_L2)
#define X_WORDS_PER_BYTE  (8 / X_BITS)
#define X_BITS_MASK       ((1 << X_BITS) -1)

typedef struct {
  int8_t     w              [W_BYTES     ];
  B_TYPE     b              [B_WORDS     ]; // keep next to w. weights are loaded to w_ptr
  int8_t     buffers [N_BUF][O_BYTES_MAX ];
  int8_t     x              [X_BYTES_ALL ];
  int32_t    y              [O_WORDS     ];
  int32_t    nhwc           [Y_BYTES/4   ];
  int8_t     debug_tiled    [O_WORDS_MAX ];
  int32_t    debug_nhwc     [Y_BYTES/4   ];
} Memory_st;
Memory_st mem;

int8_t *p_in_buffer = (int8_t*)&mem.x;
volatile char is_bundle_write_done = 1;

#define assert_printf(v1, op, v2, optional_debug_info,...) ((v1  op v2) || (printf("ASSERT FAILED: \n CONDITION: "), printf("( " #v1 " " #op " " #v2 " )"), printf(", VALUES: ( %d %s %d ), ", v1, #op, v2), printf("DEBUG_INFO: " optional_debug_info), printf(" " __VA_ARGS__), printf("\n\n"), assert(v1 op v2), 0))

#define flatten_nhwc(in,ih,iw,ic, N,H,W,C, optional_debug_info,...)\
  ((in*H + ih)*W + iw)*C + ic;\
  assert_printf (in, <, N, optional_debug_info,__VA_ARGS__); assert_printf (ih, <, H, optional_debug_info,__VA_ARGS__); assert_printf (iw, <, W, optional_debug_info,__VA_ARGS__); assert_printf (ic, <, C, optional_debug_info,__VA_ARGS__);

#define max(x, y) ((x) > (y) ? (x) : (y))
#define min(x, y) ((x) < (y) ? (x) : (y))
#define clip(x, xmin, xmax) (((x) < (xmin)) ? (xmin) : ((x) > (xmax)) ? (xmax) : (x))
#define shift_round(n, s) (((n) + (1<<((s)-1)) - (~((n)>>(s))&1) ) >> s) // === np.around(n/2**s).astype(int32_t)
#define div_round(a, b) (((a)+((b)/2) - (~((b)|(a)/(b)) &1))/(b))


static inline int32_t quant_lrelu(int32_t x, int8_t nzero, int8_t shift, int8_t pl_scale){
  x = x < 0 ? (nzero ? x: 0) : x << pl_scale; // Conditional, targeting ARM
  x = shift_round(x, shift);
  x = clip(x, -(1<<(X_BITS-pl_scale-1)), (1<<(X_BITS-1))-1);
  return x;
}


static inline void write_x(int8_t val, int8_t *p_out_buffer, int32_t ib, int32_t ixp, int32_t ixn, int32_t ixl, int32_t ixw, int32_t ixcm, int32_t ixr, Bundle_t *pb_out, int32_t xcm ){

  #define WRITEX_DEBUG_INFO "--- ib:%d ixp:%d ixn:%d ixl:%d ixw:%d ixcm:%d ixr:%d xcm :%d \n",ib,ixp,ixn,ixl,ixw,ixcm,ixr,xcm
  assert_printf (ixr , <, PE_ROWS+X_PAD, "write_x", WRITEX_DEBUG_INFO);
  assert_printf (ixcm, <, xcm          , "write_x", WRITEX_DEBUG_INFO);
  assert_printf (ixw , <, pb_out->w    , "write_x", WRITEX_DEBUG_INFO);
  assert_printf (ixl , <, pb_out->l    , "write_x", WRITEX_DEBUG_INFO);
  assert_printf (ixn , <, pb_out->n    , "write_x", WRITEX_DEBUG_INFO);
  assert_printf (ixp , <, pb_out->p    , "write_x", WRITEX_DEBUG_INFO);

  int32_t p_offset       = (ixp == 0) ? 0 : (pb_out->cm_p0 + (ixp-1)*pb_out->cm) * pb_out->xp_words;
  int32_t flat_index_n2r = (((ixn*pb_out->l + ixl)*pb_out->w + ixw)*xcm + ixcm)*(PE_ROWS+X_PAD) + ixr; // multidim_index -> flat_index [n,l,w,cm,r]

  // Debug tiled output
  int32_t flat_index     = p_offset + flat_index_n2r;
  mem.debug_tiled[flat_index] = val;

  // Pack bits and store
  int32_t flat_index_with_header = p_offset + flat_index_n2r + (ixp+1)*64/X_BITS;
  int32_t packed_index           = flat_index_with_header / X_WORDS_PER_BYTE;
  uint8_t packed_position        = flat_index_with_header % X_WORDS_PER_BYTE; // 0,1,2,3

  assert_printf (packed_index , <, bundles[ib].o_bytes, "write_x", WRITEX_DEBUG_INFO);

  uint8_t packed_val             = ((uint8_t)val & X_BITS_MASK) << (packed_position * X_BITS);
  uint8_t mem_val                = p_out_buffer[packed_index];
  uint8_t mem_val_cleaned        = X_POSITION_INVERTED_MASKS[packed_position] & mem_val;
  p_out_buffer[packed_index]     = mem_val_cleaned | packed_val;

  // if (ib==1 && packed_index >= 356) printf("index:%d, final_val:%d --- position:%d value:%d packed_val:%d, mem_val:%d, mem_val_cleaned:%d, clean_mask:%d, pos_mask:%d \n", packed_index, mem.debug_packed[packed_index], packed_position, val, packed_val, mem_val, mem_val_cleaned, X_BITS_MASK, X_POSITION_INVERTED_MASKS[packed_position]);
}


static inline void tile_write( int32_t out_val, int8_t *p_out_buffer, int32_t ib, Bundle_t *pb, int32_t i_yn, int32_t i_yh, int32_t i_yw, int32_t i_yc, int32_t yn, int32_t yh, int32_t yw, int32_t yc ) {

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

  // Check
  assert_printf (yn, ==, pb->on,,);
  assert_printf (yh, ==, pb->oh,,);
  assert_printf (yw, ==, pb->ow,,);
  assert_printf (yc, ==, pb->oc,,);

  // ------ TILING: Calculate X coordinates ------
  // y [n,h,w,c] -> x[p, n, l, w,cmp, r+pad]

  Bundle_t* pb_out = ib == N_BUNDLES-1 ? &bundles[ib] : &bundles[ib+1];
  int8_t yp_first  = i_yc < pb_out->cm_p0;

  div_t   div_oh  = div(i_yh, PE_ROWS);
  int32_t i_yr    = div_oh.rem;
  int32_t i_yl    = div_oh.quot;

  div_t   div_oc    = div(i_yc-pb_out->cm_p0, pb_out->cm);
  int32_t i_yp      = yp_first ? 0             : div_oc.quot + 1;
  int32_t i_ycm     = yp_first ? i_yc          : div_oc.rem;
  int32_t ycm       = yp_first ? pb_out->cm_p0 : pb_out->cm  ;


  // ------ STORE  ------

  int32_t iy_nhwc = flatten_nhwc(i_yn,i_yh,i_yw,i_yc, yn,yh,yw,yc,,);
  mem.debug_nhwc[iy_nhwc] = out_val;

  if (ib == N_BUNDLES-1)
    mem.y[iy_nhwc] = out_val; // Last bundle: save as NHWC
  else {

    // Other bundles: pad & save as tiled
    int32_t yr_sweep = i_yh==yh-1 ? PE_ROWS : i_yr + 1;

    for (int32_t i_yr_dest = i_yr; i_yr_dest < yr_sweep; i_yr_dest++) {
      write_x(out_val, p_out_buffer, ib, i_yp, i_yn, i_yl, i_yw, i_ycm, i_yr_dest,   pb_out, ycm);

      // --- PADDING: the [bottom X_PAD rows of previous block (l-1)] with [first X_PAD rows of this block (l)]
      if (i_yr_dest < X_PAD) {
        int32_t pad_val = (i_yl == 0) ? 0         : out_val;
        int32_t dest_yl = (i_yl == 0) ? pb_out->l-1 : i_yl-1;
        write_x(pad_val, p_out_buffer, ib, i_yp, i_yn, dest_yl, i_yw, i_ycm, i_yr_dest+PE_ROWS,   pb_out, ycm);
      }
      out_val = 0;
    }
  }
}


extern EXT_C void load_y (uint8_t *p_done, uint8_t *pt_done_proc,  const uint32_t *p_sram_u32) {

  static Bundle_t *pb = &bundles[0];
  static int32_t it_bias=0;
  static int32_t ib=0, ip=0, it=0, in=0, il=0, iw_kw2=0;
  static int8_t  *p_out_buffer = (int8_t*)&mem.buffers[0];
  const  int32_t *p_sram = (const int32_t *)p_sram_u32;

  int32_t iy_nhwc;
  div_t   div_ch, div_cw, div_ixh, div_ixw;
  int32_t ph_end, ph_beg_const, ph_beg, ixh_beg, xh_sweep;
  int32_t pw_end, pw_beg_const, pw_beg, ixw_beg, xw_sweep;

  char f_path_raw [1000], f_path_sum  [1000]; // make sure full f_path_raw is shorter than 1000
  sprintf(f_path_raw, "%s/%0d_%0d_%0d_y_raw_sim.txt", DATA_DIR, ib, ip, it);
  sprintf(f_path_sum, "%s/%0d_y_sum_sim.txt", DATA_DIR, ib);
  FILE *fp_raw = fopen(f_path_raw, "a"); 
  FILE *fp_sum = fopen(f_path_sum, "a"); 

  // Init - add headers to out buffer
  static uint8_t write_x_header = 1;
  if (write_x_header) { // enabled for each new bundle
    Bundle_t *pb_out = &bundles[ib+1];

    for (int ixp=0; ixp < pb_out->p; ixp++) {
      int32_t offset_words   = (ixp == 0) ? 0 : (pb_out->cm_p0 + (ixp-1)*pb_out->cm)*pb_out->xp_words;
      int32_t offset_bytes   = offset_words/X_WORDS_PER_BYTE + ixp*8;

      *(uint64_t*)&(p_out_buffer[offset_bytes])     = ixp == 0 ? pb_out->x_header_p0 : pb_out->x_header;
      // printf("--------ib:%d, ixp:%d offset_bytes:%d\n", ib, ixp, offset_bytes);
    }
    write_x_header = 0;
  }

  //New iw_kw2:
  int32_t w_last = iw_kw2 == pb->w_kw2-1 ? pb->kw/2+1 : 1;
  int32_t sram_addr=0;
  for (int32_t icoe=0; icoe < pb->coe; icoe++) {
    int32_t i_bias = it_bias + icoe;

    for (int32_t iw_last=0; iw_last<w_last; iw_last++) {
      for (int32_t ir=0; ir<PE_ROWS; ir++) {
        // Indexing: [b, p, t, n, l, w | coe, w_last, r]

#define DEBUG_INFO "--- ib:%d ip:%d it:%d in:%d il:%d iw_kw2:%d icoe:%d iw_last:%d ir:%d \n",ib,ip,it,in,il,iw_kw2,icoe,iw_last,ir

        int32_t raw_val=0, out_val=0;
        
        // Caculate y_index
        int32_t i_yn = in;
        int32_t i_yh = il*PE_ROWS + ir;
        int32_t i_yw = iw_kw2 + iw_last;
        int32_t i_yc = pb->coe*it + icoe;

        // Save y_dims
        int32_t yn = pb->n;
        int32_t yh = pb->h;
        int32_t yw = pb->w;
        int32_t yc = pb->co;

        // if out of bounds, early return
        if (i_yh >= yh || i_yc >= yc) { 
          if (ip == pb->p-1)
            fprintf(fp_sum,"%d\n", 0);        // Save summed output
          goto PROCESS_AND_STORE_DONE;
        }

        raw_val = p_sram[sram_addr];
        out_val = raw_val;

PROCESS_START:

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
        fprintf(fp_sum,"%d\n", out_val); // Save summed output


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


        // ------ SOFTMAX ------


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
        if (div_ixh.rem != 0)                         // invalid ixh
          if (i_yh==yh-1) ixh_beg += 1;                  //but last yh. start sweeping
          else            goto PROCESS_AND_STORE_DONE;   // not last yh. skip
        
        if (div_ixw.rem != 0)
          if (i_yw==yw-1) ixw_beg += 1;
          else            goto PROCESS_AND_STORE_DONE;

        ph_end       = i_yh; // iy(h,w) is the bottom-right of pooling window -> All values in pooling window have been computed
        pw_end       = i_yw;
        ph_beg_const = max(pb->psh*ixh_beg-pb->psh_shift, 0)-1; // p(h,w)_beg is the index of top left corner of pooling window. If negative, set to zero
        pw_beg_const = max(pb->psw*ixw_beg-pb->psw_shift, 0)-1;

        xh_sweep = i_yh == yh-1 ? pb->ph : ixh_beg+1; // ix(hw) is sweeped from ix(hw)_beg to x(h,w)_sweep. Normally sweep is 1.
        xw_sweep = i_yw == yw-1 ? pb->pw : ixw_beg+1; // But when iy(h,w) is at its edges, need to compute remaining ix(hw) pixels by sweeping

        // Sweep the pooling window
        for (int32_t ixh = ixh_beg, ph_beg = ph_beg_const;  ixh < xh_sweep;  ixh++, ph_beg += pb->psh) {
          for (int32_t ixw = ixw_beg, pw_beg = pw_beg_const;  ixw < xw_sweep;  ixw++, pw_beg += pb->psw) {

            // Traverse each pool window & perform pooling
            int32_t result = pb->pool == POOL_MAX ? INT_MIN : 0;
            for (int32_t ipyh = ph_end; ipyh > ph_beg; ipyh--){
              for (int32_t ipyw = pw_end; ipyw > pw_beg; ipyw--){

                int32_t read_idx = flatten_nhwc(i_yn, ipyh, ipyw, i_yc,    yn, yh, yw, yc, "Inside pool window", DEBUG_INFO);
                int32_t read_val = mem.nhwc[read_idx];
                result = pb->pool==POOL_MAX ? max(result, read_val) : (result + read_val);
              }
            }
            int32_t count  = (ph_end-ph_beg)*(pw_end-pw_beg);
            result = pb->pool==POOL_MAX ? result : div_round(result, count); 

            // ------ POOL ACTIVATION ------
            tile_write(result, p_out_buffer, ib, pb,   i_yn, ixh, ixw, i_yc,  yn, pb->ph, pb->pw, yc); // Write
          }
        }
        yh = pb->ph;
        yw = pb->pw;
        

PROCESS_AND_STORE_DONE:

        fprintf(fp_raw,"%d\n", raw_val); // Save raw output
        sram_addr += 1;
      }
    }
  }
  fclose(fp_sum);
  fclose(fp_raw);


  //Nested for loop [for(ib) for(ip) for(it) for(il) for(in) for(iw_kw2) {}] 
  //  inverted to increment once per call
  ++iw_kw2; if (iw_kw2 >= pb->w_kw2) { iw_kw2 = 0; //after_each(in) = after_all(iw_kw2):
    ++il; if (il >= pb->l) { il = 0;               //after_each(in) = after_all(il):
      ++in; if (in >= pb->n) { in = 0;             //after_each(it) = after_all(in):
        ++it; if (it >= pb->t) { it = 0;           //after_each(ip) = after_all(it):
          ++ip; if (ip >= pb->p) { ip = 0;         //after_each(ib) = after_all(ip):
            
            printf("done bundle!! iw_kw2:%d in:%d il:%d it:%d ip:%d ib:%d\n", iw_kw2, in, il, it, ip, ib);
            is_bundle_write_done = 1;


            char f_path_debug [1000];
            sprintf(f_path_debug, "%s/%0d_y_nhwc_sim.txt", DATA_DIR, ib);
            FILE *fp_debug = fopen(f_path_debug, "w");
            for (int32_t i=0; i<pb->debug_nhwc_words; i++)
              fprintf(fp_debug,"%d\n", mem.debug_nhwc[i]);
            fclose(fp_debug);

            char f_path_tiled [1000];
            sprintf(f_path_tiled, "%s/%0d_y_tiled_sim.txt", DATA_DIR, ib);
            FILE *fp_tiled = fopen(f_path_tiled, "w");
            for (int32_t i=0; i<pb->o_words; i++)
              fprintf(fp_tiled,"%d\n", ib == N_BUNDLES-1 ? mem.y[i] : mem.debug_tiled[i]);
            fclose(fp_tiled);

            if (ib != N_BUNDLES-1){
              char f_path_packed [1000];
              sprintf(f_path_packed, "%s/%0d_y_packed_sim.bin", DATA_DIR, ib);
              FILE *fp_packed = fopen(f_path_packed, "wb");
              fwrite(p_out_buffer, 1, pb->o_bytes, fp_packed);
              fclose(fp_packed);
            }
            
            ++ib; if (ib >= N_BUNDLES) { ib = 0;  // after_all(ib):
              *p_done = 1;
            }//new(ib):

            pb = &bundles[ib];
            p_out_buffer = (int8_t*)&mem.buffers[pb->out_buffer_idx];
            if (ib != N_BUNDLES-1) write_x_header = 1; // Make write_x write new headers
            
          }//new(ip):
        }//new(it):
        it_bias = pb->b_offset + pb->coe*it;
      }//new(in):
    }//new(il):
  }//new(iw_kw2):
  *pt_done_proc = !(*pt_done_proc);
}


extern EXT_C void load_x (uint8_t *p_done, uint8_t *bundle_read_done, uint64_t *p_base_addr, int32_t *p_bpt) {

  static int32_t ib=0, ip=0, it=0, offset_next=0;

  int8_t *p_buffer_base = (ib==0) ? mem.x : mem.buffers[bundles[ib-1].out_buffer_idx];

  *p_base_addr = (uint64_t)p_buffer_base + offset_next;
  *p_bpt = ip == 0 ? bundles[ib].x_bpt_p0 : bundles[ib].x_bpt;
  *bundle_read_done = (it == bundles[ib].t-1) && (ip==bundles[ib].p-1);

  // Nested for loop [for ib: for ip: for it: {}] inverted to increment once per call
  ++ it; if (it >= bundles[ib].t) { it = 0;
    offset_next += *p_bpt;
    ++ ip; if (ip >= bundles[ib].p) { ip = 0;

      offset_next = 0;
      is_bundle_write_done = 0;

      ++ ib; if (ib >= N_BUNDLES) { ib = 0;
        *p_done =1;
  }}}
}


extern EXT_C void load_w (uint8_t *p_done, uint64_t *p_base_addr, int32_t *p_bpt) {

  static int32_t ib=0, ip=0, it=0, offset_next=0;

  int32_t offset = offset_next;
  int32_t bpt = ip == 0 ? bundles[ib].w_bpt_p0 : bundles[ib].w_bpt;

  *p_base_addr = (uint64_t)&mem.w + offset;
  *p_bpt = bpt;

  // Nested for loop [for ib: for ip: for it: {}] inverted to increment once per call
  ++ it; if (it >= bundles[ib].t) { it = 0;
    ++ ip; if (ip >= bundles[ib].p) { ip = 0;
      ++ ib; if (ib >= N_BUNDLES) { ib = 0;
        *p_done =1;
        offset_next = 0;
  }}}
  offset_next += bpt;
}


extern EXT_C void fill_memory (uint64_t *p_w_base, uint64_t *p_x_base){
  FILE *fp;
  char f_path [1000];

  sprintf(f_path, "%s/w.bin", DATA_DIR);
  fp = fopen(f_path, "rb");
  if(!fp)
    printf("ERROR! File not found: %s \n", f_path);
  fread(mem.w, 1, WB_BYTES, fp);
  fclose(fp);

  sprintf(f_path, "%s/x_all.bin", DATA_DIR);
  fp = fopen(f_path, "rb");
  if(!fp)
    printf("ERROR! File not found: %s \n", f_path);
  fread(mem.x, 1, X_BYTES_ALL, fp);
  fclose(fp);

  for (int32_t i=0; i<B_WORDS; i++)
    printf("i:%d, bias:%d\n", i, mem.b[i]);

  *p_w_base = (uint64_t)&mem.w;
  *p_x_base = (uint64_t)&mem.x;
}

extern EXT_C int8_t get_byte (uint64_t addr){
  return *(int8_t*)addr;
}

extern EXT_C char get_is_bundle_write_done(){
  return is_bundle_write_done;
}
extern EXT_C void set_is_bundle_write_done(uint8_t val){
  is_bundle_write_done = val;
}