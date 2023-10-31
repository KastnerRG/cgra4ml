#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include <limits.h>

#ifdef VERILATOR
  #define EXT_C "C"
#else
  #define EXT_C
#endif

typedef struct {
  const int n, l, kw, coe, coe_tl, r_ll, h, w, ci, co, w_kw2, t, p, cm, cm_p0;
  const int w_bpt, w_bpt_p0, x_bpt, x_bpt_p0, o_bytes; // bytes per transfer
  const char is_bias, is_pool, is_flatten;
  const int b_offset, b_val_shift, b_bias_shift;
  const signed char ca_nzero, ca_shift, ca_pl_scale;
  const int csh, ch, csh_shift, pkh, psh, ph, psh_shift, csw, cw, csw_shift, pkw, psw, pw, psw_shift, p_type, on, oh, ow, oc;
  const unsigned long long x_header, x_header_p0, w_header, w_header_p0; // 64 bits (at least)
  const int debug_nhwc_words;
} Bundle_t;

typedef enum {POOL_NONE, POOL_MAX, POOL_AVG} Pool_t;

#include "model.h"
#define X_BITS (1<<X_BITS_L2)

typedef struct {
  char   w  [W_BYTES     ];
  B_TYPE b  [B_WORDS     ]; // keep next to w. weights are loaded to w_ptr
  char   x  [X_BYTES_ALL ];
  char   nx [O_BYTES_MAX ];
  int    y  [O_WORDS     ];
  int  nhwc [Y_BYTES/4   ];
  int debug_nhwc [Y_BYTES/4];
} Memory_st;
Memory_st mem;

#define max(x, y) (x > y ? x : y)
#define min(x, y) (x < y ? x : y)
#define clip(x, min, max) ((x < min) ? min : (x > max) ? max : x)
#define shift_round(n, s) ((n + (1<<(s-1)) - (~(n>>s)&1) ) >> s) // === np.around(n/2**s).astype(int)
#define div_round(a, b) ((a+(b/2) - (~(b|a/b) &1))/b)

#define assert_printf(debug_info, condition,...) ((condition) || (printf(#condition), printf(__VA_ARGS__), printf(debug_info), assert(condition), 0))

static inline int quant_lrelu(int x, signed char nzero, signed char shift, signed char pl_scale){
  x = ((x<0)*x)*nzero + (((x>0)*x) << pl_scale);
  x = shift_round(x, shift);
  x = clip(x, -(1<<(X_BITS-pl_scale-1)), (1<<(X_BITS-1))-1);
  return x;
}


static inline void write_x(signed char val, int ib, int ixp, int ixn, int ixl, int ixw, int ixcm, int ixr, Bundle_t *p_bo, int xcm ){

#define DBG "--- ib:%d ixp:%d ixn:%d ixl:%d ixw:%d ixcm:%d ixr:%d xcm :%d \n",ib,ixp,ixn,ixl,ixw,ixcm,ixr,xcm
    assert_printf(DBG, ixr  < PE_ROWS+X_PAD, "ixr  < PE_ROWS+X_PAD");
    assert_printf(DBG, ixcm < xcm          , "ixcm < xcm          ");
    assert_printf(DBG, ixw  < p_bo->w      , "ixw  < p_bo->w      ");
    assert_printf(DBG, ixl  < p_bo->l      , "ixl  < p_bo->l      ");
    assert_printf(DBG, ixn  < p_bo->n      , "ixn  < p_bo->n      ");
    assert_printf(DBG, ixp  < p_bo->p      , "ixp  < p_bo->p      "); 

    int p_offset = (ixp == 0) ? 0 : (p_bo->cm_p0 + (ixp-1)*p_bo->cm) *p_bo->n*p_bo->l*p_bo->w*(PE_ROWS+X_PAD);
    int flat_index_n2r = (((ixn*p_bo->l + ixl)*p_bo->w + ixw)*xcm + ixcm)*(PE_ROWS+X_PAD) + ixr; // multidim_index -> flat_index [n,l,w,cm,r]
    mem.nx[p_offset + flat_index_n2r] = val;
}


static inline void tile_write( int out_val, int ib, Bundle_t *p_bundle, int i_yn, int i_yh, int i_yw, int i_yc, int yn, int yh, int yw, int yc ) {

  // ------ FLATTEN ------
  if (p_bundle->is_flatten) {
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
  assert_printf ("", yn == p_bundle->on, ": yn");
  assert_printf ("", yh == p_bundle->oh, ": yh");
  assert_printf ("", yw == p_bundle->ow, ": yw");
  assert_printf ("", yc == p_bundle->oc, ": yc");

  // ------ TILING: Calculate X coordinates ------
  // y [n,h,w,c] -> x[p, n, l, w,cmp, r+pad]

  Bundle_t* p_bo = ib == N_BUNDLES-1 ? &bundles[ib] : &bundles[ib+1];
  char yp_first  = i_yc < p_bo->cm_p0;

  div_t div_oh  = div(i_yh, PE_ROWS);
  int i_yr      = div_oh.rem;
  int i_yl      = div_oh.quot;

  div_t div_oc  = div(i_yc-p_bo->cm_p0, p_bo->cm);
  int i_yp      = yp_first ? 0           : div_oc.quot + 1;
  int i_ycm     = yp_first ? i_yc        : div_oc.rem;
  int ycm       = yp_first ? p_bo->cm_p0 : p_bo->cm  ;


  // ------ STORE  ------

  int iy_nhwc = ((i_yn*yh + i_yh)*yw +  i_yw)*yc + i_yc;
  mem.debug_nhwc[iy_nhwc] = out_val;

  if (ib == N_BUNDLES-1) {  
    // Last bundle: save as NHWC
    assert_printf ("", i_yn < yn, ": i_yn < yn");
    assert_printf ("", i_yh < yh, ": i_yh < yh");
    assert_printf ("", i_yw < yw, ": i_yw < yw");
    assert_printf ("", i_yc < yc, ": i_yc < yc");
    mem.y[iy_nhwc] = out_val;
  } else {

    // Other bundles: pad & save as tiled
    int yr_sweep = i_yh==yh-1 ? PE_ROWS : i_yr + 1;

    for (int i_yr_dest = i_yr; i_yr_dest < yr_sweep; i_yr_dest++) {
      write_x(out_val, ib, i_yp, i_yn, i_yl, i_yw, i_ycm, i_yr_dest,   p_bo, ycm);

      // --- PADDING: the [bottom X_PAD rows of previous block (l-1)] with [first X_PAD rows of this block (l)]
      if (i_yr_dest < X_PAD) {
        int pad_val = (i_yl == 0) ? 0         : out_val;
        int dest_yl = (i_yl == 0) ? p_bo->l-1 : i_yl-1;
        write_x(pad_val, ib, i_yp, i_yn, dest_yl, i_yw, i_ycm, i_yr_dest+PE_ROWS,   p_bo, ycm);
      }
      out_val = 0;
    }
  }
}


extern EXT_C void load_y (unsigned char *p_done, unsigned char *pt_done_proc,  const unsigned int *p_sram_u32) {

  static Bundle_t *p_bundle = &bundles[0];
  static int it_bias=0;
  static int ib=0, ip=0, it=0, in=0, il=0, iw_kw2=0;
  const int *p_sram = (const int *)p_sram_u32;

  int iy_nhwc;
  div_t div_ch, div_cw, div_ixh, div_ixw;
  int ph_end, ph_beg_const, ph_beg, ixh_beg, xh_sweep;
  int pw_end, pw_beg_const, pw_beg, ixw_beg, xw_sweep;

  char f_path_raw [1000], f_path_sum  [1000]; // make sure full f_path_raw is shorter than 1000
  sprintf(f_path_raw, "%s/%0d_%0d_%0d_y_raw_sim.txt", DATA_DIR, ib, ip, it);
  sprintf(f_path_sum, "%s/%0d_y_sum_sim.txt", DATA_DIR, ib);
  FILE *fp_raw = fopen(f_path_raw, "a"); 
  FILE *fp_sum = fopen(f_path_sum, "a"); 

  //New iw_kw2:
  int w_last = iw_kw2 == p_bundle->w_kw2-1 ? p_bundle->kw/2+1 : 1;
  int sram_addr=0;
  for (int icoe=0; icoe<p_bundle->coe; icoe++) {
    int i_bias = it_bias + icoe;

    for (int iw_last=0; iw_last<w_last; iw_last++) {
      for (int ir=0; ir<PE_ROWS; ir++) {
        // Indexing: [b, p, t, n, l, w | coe, w_last, r]

#define DBG "--- ib:%d ip:%d it:%d in:%d il:%d iw_kw2:%d icoe:%d iw_last:%d ir:%d \n",ib,ip,it,in,il,iw_kw2,icoe,iw_last,ir

        int raw_val=0, out_val=0;
        
        // Caculate y_index
        int i_yn = in;
        int i_yh = il*PE_ROWS + ir;
        int i_yw = iw_kw2 + iw_last;
        int i_yc = p_bundle->coe*it + icoe;

        // Save y_dims
        int yn = p_bundle->n;
        int yh = p_bundle->h;
        int yw = p_bundle->w;
        int yc = p_bundle->co;


        // if out of bounds, early return
        if (i_yh >= yh || i_yc >= yc) { 
          if (ip == p_bundle->p-1)
            fprintf(fp_sum,"%d\n", 0);        // Save summed output
          goto PROCESS_AND_STORE_DONE;
        }

        raw_val = p_sram[sram_addr];
        out_val = raw_val;

PROCESS_START:


        // ------ ADD P PASSES ------ 
        iy_nhwc = ((i_yn*yh + i_yh)*yw +  i_yw)*yc + i_yc;

        if (p_bundle->p == 1) {          // only p  : proceed with value
        } else if (ip == p_bundle->p-1) {// last p  : read, add, proceed
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
        div_ch = div(i_yh-p_bundle->csh_shift, p_bundle->csh);
        div_cw = div(i_yw-p_bundle->csw_shift, p_bundle->csw);

        if (div_ch.rem != 0 || div_cw.rem != 0)
          goto PROCESS_AND_STORE_DONE;

        i_yh = div_ch.quot; // update indices and dimensions
        i_yw = div_cw.quot;
        yh = p_bundle->ch;
        yw = p_bundle->cw;

        // ------ ADD BIAS ------ 
        if (p_bundle->is_bias)
          out_val = (out_val << p_bundle->b_val_shift) + (mem.b[i_bias] << p_bundle->b_bias_shift);
        

        // ------ CORE ACT ------
        out_val = quant_lrelu(out_val, p_bundle->ca_nzero, p_bundle->ca_shift, p_bundle->ca_pl_scale);



        // ------ SOFTMAX ------


        // ------ MAX/AVG POOL ---

        if (p_bundle->p_type == POOL_NONE) {
          tile_write(out_val, ib, p_bundle, i_yn, i_yh, i_yw, i_yc, yn, yh, yw, yc);
          goto PROCESS_AND_STORE_DONE;
        }

        assert_printf ("write_temp", i_yn < yn, ": i_yn < yn");
        assert_printf ("write_temp", i_yh < yh, ": i_yh < yh");
        assert_printf ("write_temp", i_yw < yw, ": i_yw < yw");
        assert_printf ("write_temp", i_yc < yc, ": i_yc < yc");

        iy_nhwc = ((i_yn*yh + i_yh)*yw +  i_yw)*yc + i_yc; // store as nhwc for pooling
        mem.nhwc[iy_nhwc] = out_val;

        div_ixh = div(i_yh+p_bundle->psh_shift-p_bundle->pkh+1, p_bundle->psh);
        div_ixw = div(i_yw+p_bundle->psw_shift-p_bundle->pkw+1, p_bundle->psw);
        ixh_beg = div_ixh.quot; // ix(hw) that corresponds to the pooling window
        ixw_beg = div_ixw.quot;
        
        if (ixh_beg < 0 || ixw_beg < 0) // skip when target ix(h,w) < 0
          goto PROCESS_AND_STORE_DONE;

        if (div_ixh.rem != 0)                           // invalid ixh
          if (i_yh==yh-1) ixh_beg += 1;                  //but last yh. start sweeping
          else            goto PROCESS_AND_STORE_DONE;   // not last yh. skip
        
        if (div_ixw.rem != 0)
          if (i_yw==yw-1) ixw_beg += 1;
          else            goto PROCESS_AND_STORE_DONE;

        ph_end       = i_yh; // iy(h,w) is the bottom-right of pooling window -> All values in pooling window have been computed
        pw_end       = i_yw;
        ph_beg_const = max(p_bundle->psh*ixh_beg-p_bundle->psh_shift, 0)-1; // p(h,w)_beg is the index of top left corner of pooling window. If negative, set to zero
        pw_beg_const = max(p_bundle->psw*ixw_beg-p_bundle->psw_shift, 0)-1;

        xh_sweep = i_yh == yh-1 ? p_bundle->ph : ixh_beg+1; // ix(hw) is sweeped from ix(hw)_beg to x(h,w)_sweep. Normally sweep is 1.
        xw_sweep = i_yw == yw-1 ? p_bundle->pw : ixw_beg+1; // But when iy(h,w) is at its edges, need to compute remaining ix(hw) pixels by sweeping

        // Sweep the pooling window
        for (int ixh = ixh_beg, ph_beg = ph_beg_const;  ixh < xh_sweep;  ixh++, ph_beg += p_bundle->psh) {
          for (int ixw = ixw_beg, pw_beg = pw_beg_const;  ixw < xw_sweep;  ixw++, pw_beg += p_bundle->psw) {

            // Traverse each pool window & perform pooling
            int result = p_bundle->p_type == POOL_MAX ? INT_MIN : 0;
            for (int ipyh = ph_end; ipyh > ph_beg; ipyh--){
              for (int ipyw = pw_end; ipyw > pw_beg; ipyw--){

                assert_printf ("read", i_yn < yn, ": i_yn < yn");
                assert_printf ("read", ipyh < yh, ": ipyh < yh");
                assert_printf ("read", ipyw < yw, ": ipyw < yw");
                assert_printf ("read", i_yc < yc, ": i_yc < yc");
                
                int read_val = mem.nhwc[((i_yn*yh + ipyh)*yw +  ipyw)*yc + i_yc];
                result = p_bundle->p_type==POOL_MAX ? max(result, read_val) : (result + read_val);
              }
            }
            int count  = (ph_end-ph_beg)*(pw_end-pw_beg);
            result = p_bundle->p_type==POOL_MAX ? result : div_round(result, count); 

            // ------ POOL ACTIVATION ------
            tile_write(result, ib, p_bundle,   i_yn, ixh, ixw, i_yc,  yn, p_bundle->ph, p_bundle->pw, yc); // Write
          }
        }
        yh = p_bundle->ph;
        yw = p_bundle->pw;
        

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
  ++iw_kw2; if (iw_kw2 >= p_bundle->w_kw2) { iw_kw2 = 0; //after_each(in) = after_all(iw_kw2):
    ++il; if (il >= p_bundle->l) { il = 0;               //after_each(in) = after_all(il):
      ++in; if (in >= p_bundle->n) { in = 0;             //after_each(it) = after_all(in):
        ++it; if (it >= p_bundle->t) { it = 0;           //after_each(ip) = after_all(it):
          ++ip; if (ip >= p_bundle->p) { ip = 0;         //after_each(ib) = after_all(ip):
            
            printf("done bundle!! iw_kw2:%d in:%d il:%d it:%d ip:%d ib:%d\n", iw_kw2, in, il, it, ip, ib);

            char f_path_tiled [1000];
            sprintf(f_path_tiled, "%s/%0d_y_tiled_sim.txt", DATA_DIR, ib);
            FILE *fp_tiled = fopen(f_path_tiled, "w");
            for (int i=0; i<p_bundle->o_bytes; i++)
              fprintf(fp_tiled,"%d\n", ib == N_BUNDLES-1 ? mem.y[i] : mem.nx[i]);
            fclose(fp_tiled);

            char f_path_debug [1000];
            sprintf(f_path_debug, "%s/%0d_y_nhwc_sim.txt", DATA_DIR, ib);
            FILE *fp_debug = fopen(f_path_debug, "w");
            for (int i=0; i<p_bundle->debug_nhwc_words; i++)
              fprintf(fp_debug,"%d\n", mem.debug_nhwc[i]);
            fclose(fp_debug);

            
            ++ib; if (ib >= N_BUNDLES) { ib = 0;  // after_all(ib):
              *p_done = 1;
            }//new(ib):
            p_bundle = &bundles[ib];
          }//new(ip):
        }//new(it):
        it_bias = p_bundle->b_offset + p_bundle->coe*it;
      }//new(in):
    }//new(il):
  }//new(iw_kw2):
  *pt_done_proc = !(*pt_done_proc);
}


extern EXT_C void load_x (unsigned char *p_done, int *p_offset, int *p_bpt) {

  static int ib=0, ip=0, it=0, offset_next=0;
  int offset = offset_next;
  int bpt = ip == 0 ? bundles[ib].x_bpt_p0 : bundles[ib].x_bpt;

  *p_offset = offset;
  *p_bpt = bpt;

  // Nested for loop [for ib: for ip: for it: {}] inverted to increment once per call
  ++ it; if (it >= bundles[ib].t) { it = 0;
    ++ ip; if (ip >= bundles[ib].p) { ip = 0;
      ++ ib; if (ib >= N_BUNDLES) { ib = 0;
        *p_done =1;
        offset_next = 0;
    }}
    offset_next += bpt;
  }
}


extern EXT_C void load_w (unsigned char *p_done, int *p_offset, int *p_bpt) {

  static int ib=0, ip=0, it=0, offset_next=0;

  int offset = offset_next;
  int bpt = ip == 0 ? bundles[ib].w_bpt_p0 : bundles[ib].w_bpt;

  *p_offset = offset;
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


extern EXT_C void fill_memory (){
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

  for (int i=0; i<B_WORDS; i++)
    printf("i:%d, bias:%d\n", i, mem.b[i]);
}


extern EXT_C char get_byte_wx (int addr, int mode){
  if      (mode==0) return mem.w[addr];
  else if (mode==1) return mem.x[addr];
}