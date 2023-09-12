typedef struct {
  const int n, l, kw, coe, coe_tl, r_ll, h, w, w_kw2, t, p, cm, cm_p0;
  const int w_bpt, w_bpt_p0, x_bpt, x_bpt_p0; // bytes per transfer
  const unsigned long long x_header, x_header_p0, w_header, w_header_p0; // 64 bits (at least)
} Bundle_t;

#include "model.h"
#include <svdpi.h>
#include <stdio.h>
#include <stdlib.h>

#ifdef VERILATOR
  #define EXT_C "C"
  // svSetScope (svGetScopeFromName ("dnn_engine_tb.sv"));
#else
  #define EXT_C
#endif
/*
Bundle (current):

+ Conv/Dense
- Add Bias
- Relu + Quantization
- Add Bundle
- Relu + Quantization
- Max / Avg Pooling
- Relu + Quantization
- Softmax
- Tiling (Flatten)
*/

extern EXT_C void write_y (int *addr, int data);
extern EXT_C int  read_y  (int *addr);


static inline void process_y(int val, int *p_y, int ib, int ip, int it, int in, int il, int iw, int icoe, int iw_last, int ir){

  if (bundles[ib].p == 1){
    // only p  : proceed with value
  }
  else if (ip == 0) {
    // first p : overwrite memory, return
    write_y(p_y, val);
    return;
  }
  else if (ip == bundles[ib].p-1) {
    // last p  : read, add, proceed
    val += read_y(p_y);
  }
  else {
    // middle p: read, add, store, return
    write_y(p_y, val + read_y(p_y));
    return;
  }


  write_y(p_y, val);
}


extern EXT_C void load_y (unsigned char *p_done, unsigned char *pt_done_proc,  const unsigned int *p_sram_u32) {

  static int *p_y=0;
  static int ib=0, ip=0, it=0, in=0, il=0, iw=0;
  const int *p_sram = (const int *)p_sram_u32;

  FILE *fp;
  char path [1000]; // make sure full path is shorter than 1000
  sprintf(path, "%s/%0d_%0d_%0d_y_sim.txt", DATA_DIR, ib, ip, it);
  fp = fopen(path, "a"); 

  int w_last = iw == bundles[ib].w_kw2-1 ? bundles[ib].kw/2+1 : 1;
  int sram_addr=0;
  for (int icoe=0; icoe<bundles[ib].coe; icoe++)
    for (int iw_last=0; iw_last<w_last; iw_last++)
      for (int ir=0; ir<PE_ROWS; ir++) {
        
        int val = p_sram[sram_addr];
        fprintf(fp,"%d\n", val);

        process_y(val, p_y, ib, ip, it, in, il, iw, icoe, iw_last, ir);
        
        p_y += 1; // increments by 4 (ptr arithmetic)
        sram_addr += 1;
      }
  
  fclose(fp);


  int *p_y_prev;
  // Nested for loop [for(ib) for(ip) for(it) for(il) for(in) for(iw) {}] inverted to increment once per call
  ++ iw; if (iw >= bundles[ib].w_kw2) { iw = 0;
    ++ in; if (in >= bundles[ib].n) { in = 0;
      ++ il; if (il >= bundles[ib].l) { il = 0;
        ++ it; if (it >= bundles[ib].t) { it = 0;
      
          // After each p
          printf("done p!! iw:%d in:%d il:%d it:%d ip:%d ib:%d\n", iw, in, il, it, ip, ib);
          p_y_prev = p_y;
          p_y=0;

          ++ ip; if (ip >= bundles[ib].p) { ip = 0;

            // After each bundle
            printf("done bundle!! iw:%d in:%d il:%d it:%d ip:%d ib:%d\n", iw, in, il, it, ip, ib);
            // Write to file at every it_done
            sprintf(path, "%s/%0d_y_sim.txt", DATA_DIR, ib);
            fp = fopen(path, "w"); 
            for (int *ip_y=0; ip_y < p_y_prev; ip_y++)  // increments by 4 (ptr arithmetic)
              fprintf(fp,"%d\n", read_y(ip_y));
            fclose(fp);

            ++ ib; if (ib >= N_BUNDLES) { ib = 0;
              *p_done =1;
  }}}}}}
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