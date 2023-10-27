#include <stdio.h>

#ifdef VERILATOR
  #define EXT_C "C"
#else
  #define EXT_C
#endif

typedef struct {
  const int n, l, kw, coe, coe_tl, r_ll, h, w, ci, co, w_kw2, t, p, cm, cm_p0;
  const int w_bpt, w_bpt_p0, x_bpt, x_bpt_p0, o_bytes; // bytes per transfer
  const char is_bias, conv2dense;
  const int b_offset, b_val_shift, b_bias_shift;
  const signed char ca_nzero, ca_shift, ca_pl_scale;
  const unsigned long long x_header, x_header_p0, w_header, w_header_p0; // 64 bits (at least)
} Bundle_t;

#include "model.h"
#define X_BITS (1<<X_BITS_L2)

typedef struct {
  char   w  [W_BYTES     ];
  B_TYPE b  [B_WORDS     ]; // keep next to w. weights are loaded to w_ptr
  char   x  [X_BYTES_ALL ];
  char   nx [O_BYTES_MAX ];
  int    y  [O_WORDS     ];
  int p_sum [Y_BYTES/4   ];
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


extern EXT_C void load_y (unsigned char *p_done, unsigned char *pt_done_proc,  const unsigned int *p_sram_u32) {

  static Bundle_t *p_bundle = &bundles[0];
  static int i_py=0, it_bias=0;
  static int ib=0, ip=0, it=0, in=0, il=0, iw=0;
  const int *p_sram = (const int *)p_sram_u32;

  FILE *fp_raw, *fp_out, *fp_sum;
  char f_path_raw [1000], f_path_out [1000], f_path_sum  [1000]; // make sure full f_path_raw is shorter than 1000
  sprintf(f_path_raw, "%s/%0d_%0d_%0d_y_raw_sim.txt", DATA_DIR, ib, ip, it);
  sprintf(f_path_sum, "%s/%0d_y_sum_sim.txt", DATA_DIR, ib);
  sprintf(f_path_out, "%s/%0d_y_out_sim.txt", DATA_DIR, ib);
  fp_raw = fopen(f_path_raw, "a"); 
  fp_sum = fopen(f_path_sum, "a"); 
  fp_out = fopen(f_path_out, "a"); 

  //New iw:
  int w_last = iw == p_bundle->w_kw2-1 ? p_bundle->kw/2+1 : 1;
  int sram_addr=0;
  for (int icoe=0; icoe<p_bundle->coe; icoe++) {
    int i_bias = it_bias + icoe;

    for (int iw_last=0; iw_last<w_last; iw_last++) {
      for (int ir=0; ir<PE_ROWS; ir++) {
        // Indexing: [b, p, t, n, l, w | coe, w_last, r]

        int raw_val=0, out_val=0;
        int i_yh = il*PE_ROWS + ir;

        if (i_yh < p_bundle->h){ // if within bounds
          raw_val = p_sram[sram_addr];
          out_val = raw_val;

PROCESS_START:

          // ------ ADD P PASSES ------ 
          if (p_bundle->p == 1) {          // only p  : proceed with value
          } else if (ip == p_bundle->p-1) {// last p  : read, add, proceed
            out_val += mem.p_sum[i_py];
          } else if (ip == 0) {            // first p : overwrite memory, return
            mem.p_sum[i_py] = out_val;
            goto PROCESS_AND_STORE_DONE;
          } else {                         // middle p: read, add, store, return
            mem.p_sum[i_py] += out_val;
            goto PROCESS_AND_STORE_DONE;
          }
          fprintf(fp_sum,"%d\n", out_val); // Save summed output

          // ------ ADD BIAS ------ 
          if (p_bundle->is_bias)
            out_val = (out_val << p_bundle->b_val_shift) + (mem.b[i_bias] << p_bundle->b_bias_shift);
          
          // ------ CORE ACT ------
          out_val = quant_lrelu(out_val, p_bundle->ca_nzero, p_bundle->ca_shift, p_bundle->ca_pl_scale);


          // ------ MAX/AVG POOL ------

          // ------ RELU + QUANT ------

          // ------ SOFTMAX ------

          // ------ TILING ------

          // ------ STORE  ------
          fprintf(fp_out,"%d\n", out_val); // Save processed output

        } 
        else if (ip == p_bundle->p-1) {    // (out of bounds & last p) -> write zeros
          fprintf(fp_sum,"%d\n", 0);        // Save summed output
          fprintf(fp_out,"%d\n", 0);        // Save processed output
        }

PROCESS_AND_STORE_DONE:

        fprintf(fp_raw,"%d\n", raw_val); // Save raw output
        i_py += 1;
        sram_addr += 1;
      }
    }
  }
  fclose(fp_out);
  fclose(fp_sum);
  fclose(fp_raw);


  //Nested for loop [for(ib) for(ip) for(it) for(il) for(in) for(iw) {}] 
  //  inverted to increment once per call
  ++iw; if (iw >= p_bundle->w_kw2) { iw = 0;      //after_each(in) = after_all(iw):
    ++il; if (il >= p_bundle->l) { il = 0;        //after_each(in) = after_all(il):
      ++in; if (in >= p_bundle->n) { in = 0;      //after_each(it) = after_all(in):
        ++it; if (it >= p_bundle->t) { it = 0;    //after_each(ip) = after_all(it):
          ++ip; if (ip >= p_bundle->p) { ip = 0;  //after_each(ib) = after_all(ip):
            
            printf("done bundle!! iw:%d in:%d il:%d it:%d ip:%d ib:%d\n", iw, in, il, it, ip, ib);

            char f_path_tiled [1000];
            sprintf(f_path_tiled, "%s/%0d_y_tiled_sim.txt", DATA_DIR, ib);
            FILE *fp_tiled = fopen(f_path_tiled, "w");
            for (int i=0; i<p_bundle->o_bytes; i++)
              fprintf(fp_tiled,"%d\n", ib == N_BUNDLES-1 ? mem.y[i] : mem.nx[i]);
            fclose(fp_tiled);
            
            ++ib; if (ib >= N_BUNDLES) { ib = 0;  // after_all(ib):
              *p_done = 1;
            }//new(ib):
            p_bundle = &bundles[ib];
          }//new(ip):
          i_py = 0;
        }//new(it):
        it_bias = p_bundle->b_offset + p_bundle->coe*it;
      }//new(in):
    }//new(il):
  }//new(iw):
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