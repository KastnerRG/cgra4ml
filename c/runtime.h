#include <stdio.h>
#include <assert.h>
#include <stdlib.h>

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
  const int csh, ch, csh_shift, pkh, psh, ph, psh_shift, csw, cw, csw_shift, pkw, psw, pw, psw_shift, oh, ow, oc;
  const unsigned long long x_header, x_header_p0, w_header, w_header_p0; // 64 bits (at least)
  const int debug_nhwc_words;
} Bundle_t;

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

#define clip(x, min, max) ((x < min) ? min : (x > max) ? max : x)
#define shift_round(n, s) ((n + (1<<(s-1)) - (~(n>>s)&1) ) >> s) // === np.around(n/2**s).astype(int)


static inline int quant_lrelu(int x, signed char nzero, signed char shift, signed char pl_scale){
  x = ((x<0)*x)*nzero + (((x>0)*x) << pl_scale);
  x = shift_round(x, shift);
  x = clip(x, -(1<<(X_BITS-pl_scale-1)), (1<<(X_BITS-1))-1);
  return x;
}

static inline void write_x(signed char val, int ib, int ixp, int ixn, int ixl, int ixw, int ixcm, int ixr, Bundle_t *p_bo, int xcm ){

    int p_offset = (ixp == 0) ? 0 : (p_bo->cm_p0 + (ixp-1)*p_bo->cm) *p_bo->n*p_bo->l*p_bo->w*(PE_ROWS+X_PAD);

    int flat_index_n2r = (((ixn*p_bo->l + ixl)*p_bo->w + ixw)*xcm + ixcm)*(PE_ROWS+X_PAD) + ixr; // multidim_index -> flat_index [n,l,w,cm,r]

    if (!( ixr  < PE_ROWS+X_PAD)) assert(0*printf("ixr : %d >= %d --------- ib:%d ixp:%d ixn:%d ixl:%d ixw:%d ixcm:%d ixr:%d xcm :%d \n", ixr, PE_ROWS+X_PAD, ib,ixp,ixn,ixl,ixw,ixcm,ixr,xcm ));
    if (!( ixcm < xcm          )) assert(0*printf("ixcm: %d >= %d --------- ib:%d ixp:%d ixn:%d ixl:%d ixw:%d ixcm:%d ixr:%d xcm :%d \n", ixcm, xcm ,         ib,ixp,ixn,ixl,ixw,ixcm,ixr,xcm ));
    if (!( ixw  < p_bo->w      )) assert(0*printf("ixw : %d >= %d --------- ib:%d ixp:%d ixn:%d ixl:%d ixw:%d ixcm:%d ixr:%d xcm :%d \n", ixw , p_bo->w,      ib,ixp,ixn,ixl,ixw,ixcm,ixr,xcm ));
    if (!( ixl  < p_bo->l      )) assert(0*printf("ixl : %d >= %d --------- ib:%d ixp:%d ixn:%d ixl:%d ixw:%d ixcm:%d ixr:%d xcm :%d \n", ixl , p_bo->l,      ib,ixp,ixn,ixl,ixw,ixcm,ixr,xcm ));
    if (!( ixn  < p_bo->n      )) assert(0*printf("ixn : %d >= %d --------- ib:%d ixp:%d ixn:%d ixl:%d ixw:%d ixcm:%d ixr:%d xcm :%d \n", ixn , p_bo->n,      ib,ixp,ixn,ixl,ixw,ixcm,ixr,xcm ));
    if (!( ixp  < p_bo->p      )) assert(0*printf("ixp : %d >= %d --------- ib:%d ixp:%d ixn:%d ixl:%d ixw:%d ixcm:%d ixr:%d xcm :%d \n", ixp , p_bo->p,      ib,ixp,ixn,ixl,ixw,ixcm,ixr,xcm )); 
    
    mem.nx[p_offset + flat_index_n2r] = val;
}


extern EXT_C void load_y (unsigned char *p_done, unsigned char *pt_done_proc,  const unsigned int *p_sram_u32) {

  static Bundle_t *p_bundle = &bundles[0];
  static int it_bias=0;
  static int ib=0, ip=0, it=0, in=0, il=0, iw_kw2=0;
  const int *p_sram = (const int *)p_sram_u32;

  int i_xn, i_xh, i_xw, i_xc, ix_nhwc;
  int i_xr, i_xl, i_xp, i_xcm, xcm;
  Bundle_t *p_bo; 
  char xp_first;
  div_t div_ch, div_cw, div_xh, div_xc;

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

        int raw_val=0, out_val=0;
        
        // Caculate y_index
        int i_yn = in;
        int i_yh = il*PE_ROWS + ir;
        int i_yw = iw_kw2 + iw_last;
        int i_yc = p_bundle->coe*it + icoe;
        int iy_nhwc = ((i_yn*p_bundle->h + i_yh)*p_bundle->w +  i_yw)*p_bundle->co + i_yc;

        // if out of bounds, early return
        if (i_yh >= p_bundle->h || i_yc >= p_bundle->co) { 
          if (ip == p_bundle->p-1)
            fprintf(fp_sum,"%d\n", 0);        // Save summed output
          goto PROCESS_AND_STORE_DONE;
        }

        raw_val = p_sram[sram_addr];
        out_val = raw_val;

PROCESS_START:


        // ------ ADD P PASSES ------ 

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


        // ------ ADD BIAS ------ 
        if (p_bundle->is_bias)
          out_val = (out_val << p_bundle->b_val_shift) + (mem.b[i_bias] << p_bundle->b_bias_shift);
        

        // ------ CORE ACT ------
        out_val = quant_lrelu(out_val, p_bundle->ca_nzero, p_bundle->ca_shift, p_bundle->ca_pl_scale);



        // ------ SOFTMAX ------



        // ------ TILING: Calculate X coordinates ------

        // Calc: y [n,h,w,c] -> x [n,h,w,c]
        if (p_bundle->is_flatten){
          i_xn = 0   ;                                            // N=1
          i_xh = i_yn;                                            // N -> H
          i_xw = 0   ;                                            // W=1
          i_xc = (i_yh*p_bundle->w +  i_yw)*p_bundle->co + i_yc;  // (H*W*C) -> C
        } else {
          i_xn = i_yn; 
          i_xh = div_ch.quot;
          i_xw = div_cw.quot; 
          i_xc = i_yc;
        }

        // Calc: x [n,h,w,c] -> x[p, n, l, w,cmp, r+pad]

        p_bo = ib == N_BUNDLES-1 ? &bundles[ib] : &bundles[ib+1];
        xp_first  = i_xc < p_bo->cm_p0;

        div_xh = div(i_xh, PE_ROWS);
        i_xr   = div_xh.rem;
        i_xl   = div_xh.quot;

        div_xc = div(i_xc-p_bo->cm_p0, p_bo->cm);
        i_xp   = xp_first ? 0           : div_xc.quot + 1;
        i_xcm  = xp_first ? i_xc        : div_xc.rem;
        xcm    = xp_first ? p_bo->cm_p0 : p_bo->cm  ;




        // ------ MAX/AVG POOL ------

        // ------ RELU + QUANT ------


        // ------ STORE  ------

        ix_nhwc = ((i_xn*p_bundle->oh + i_xh)*p_bundle->ow +  i_xw)*p_bundle->oc + i_xc;
        mem.debug_nhwc[ix_nhwc] = out_val;

        if (ib == N_BUNDLES-1) {  
          // Last bundle: save as NHWC
          if (!( i_xn  < p_bundle->n )) assert(0*printf("ixn : %d >= %d --------- ib:%d ip:%d it:%d in:%d il:%d iw_kw2:%d icoe:%d iw_last:%d ir:%d \n", i_xn, p_bundle->n , ib,ip,it,in,il,iw_kw2,icoe,iw_last,ir)); 
          if (!( i_xh  < p_bundle->oh)) assert(0*printf("ixh : %d >= %d --------- ib:%d ip:%d it:%d in:%d il:%d iw_kw2:%d icoe:%d iw_last:%d ir:%d \n", i_xh, p_bundle->oh, ib,ip,it,in,il,iw_kw2,icoe,iw_last,ir)); 
          if (!( i_xw  < p_bundle->ow)) assert(0*printf("ixw : %d >= %d --------- ib:%d ip:%d it:%d in:%d il:%d iw_kw2:%d icoe:%d iw_last:%d ir:%d \n", i_xw, p_bundle->ow, ib,ip,it,in,il,iw_kw2,icoe,iw_last,ir)); 
          if (!( i_xc  < p_bundle->oc)) assert(0*printf("ixc : %d >= %d --------- ib:%d ip:%d it:%d in:%d il:%d iw_kw2:%d icoe:%d iw_last:%d ir:%d \n", i_xc, p_bundle->oc, ib,ip,it,in,il,iw_kw2,icoe,iw_last,ir)); 

          mem.y[ix_nhwc] = out_val;

        } else {

          // Other bundles: pad & save as tiled
          int xr_sweep = (i_xh==p_bo->oh) ? PE_ROWS : i_xr + 1;

          for (int i_xr_dest = i_xr; i_xr_dest < xr_sweep; i_xr_dest++) {
            write_x(out_val, ib, i_xp, i_xn, i_xl, i_xw, i_xcm, i_xr_dest,   p_bo, xcm);

            // --- PADDING: the [bottom X_PAD rows of previous block (l-1)] with [first X_PAD rows of this block (l)]
            if (i_xr_dest < X_PAD) {
              int pad_val = (i_xl == 0) ? 0         : out_val;
              int dest_xl = (i_xl == 0) ? p_bo->l-1 : i_xl-1;
              write_x(pad_val, ib, i_xp, i_xn, dest_xl, i_xw, i_xcm, i_xr_dest+PE_ROWS,   p_bo, xcm);
            }
            out_val = 0;
          }
        }

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
  FILE *fp_raw;
  char f_path_raw [1000];

  sprintf(f_path_raw, "%s/w.bin", DATA_DIR);
  fp_raw = fopen(f_path_raw, "rb");
  if(!fp_raw)
    printf("ERROR! File not found: %s \n", f_path_raw);
  fread(mem.w, 1, WB_BYTES, fp_raw);
  fclose(fp_raw);

  sprintf(f_path_raw, "%s/x_all.bin", DATA_DIR);
  fp_raw = fopen(f_path_raw, "rb");
  if(!fp_raw)
    printf("ERROR! File not found: %s \n", f_path_raw);
  fread(mem.x, 1, X_BYTES_ALL, fp_raw);
  fclose(fp_raw);

  for (int i=0; i<B_WORDS; i++)
    printf("i:%d, bias:%d\n", i, mem.b[i]);
}


extern EXT_C char get_byte_wx (int addr, int mode){
  if      (mode==0) return mem.w[addr];
  else if (mode==1) return mem.x[addr];
}