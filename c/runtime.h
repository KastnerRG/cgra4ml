typedef struct {
  const int w_bpt, w_bpt_p0; // words per transfer
  const int x_bpt, x_bpt_p0;
  const int y_wpt, y_wpt_last;
  const int y_nl, y_w;
  const int n_it, n_p;
  const unsigned long long x_header   ; // 64 bits (at least)
  const unsigned long long x_header_p0; // 64 bits (at least)
  const unsigned long long w_header   ; // 64 bits (at least)
  const unsigned long long w_header_p0; // 64 bits (at least)
} Bundle_t;

#include "model.h"
#include <svdpi.h>
#include <stdio.h>
#include <stdlib.h>

#ifdef VERILATOR
  #define EXT_C "C"
#else
  #define EXT_C
#endif


extern EXT_C void load_y (unsigned char *p_done, unsigned char *pt_done_proc,  const unsigned int *p_sram_u32) {

  static int ib=0, ip=0, it=0, inl=0, iw=0;
  const int *p_sram = (const int *)p_sram_u32;

  static FILE *fp;
  static char path [1000]; // make sure full path is shorter than 1000
  if (inl==0 && iw == 0) {
    sprintf(path, "%s/%0d_%0d_%0d_y_sim.txt", DATA_DIR, ib, ip, it);
    fp = fopen(path, "w"); 
    fclose(fp);
  }
  fp = fopen(path, "a"); 

  int y_wpt = (iw == (bundles[ib].y_w-1)) ? bundles[ib].y_wpt_last : bundles[ib].y_wpt;
  for (int ir=0; ir < y_wpt; ir++) {
    fprintf(fp,"%d\n", p_sram[ir]);
  }

  fclose(fp);

  // Nested for loop [for ib: for ip: for it: for inl: for it: {}] inverted to increment once per call
  ++ iw; if (iw >= bundles[ib].y_w) { iw = 0;
    ++ inl; if (inl >= bundles[ib].y_nl) { inl = 0;
      ++ it; if (it >= bundles[ib].n_it) { it = 0;
        ++ ip; if (ip >= bundles[ib].n_p) { ip = 0;
          ++ ib; if (ib >= N_BUNDLES) { ib = 0;
            *p_done =1;
  }}}}}
  *pt_done_proc = !(*pt_done_proc);
}


extern EXT_C void load_x (unsigned char *p_done, int *p_offset, int *p_bpt) {

  static int ib=0, ip=0, it=0, offset_next=0;
  int offset = offset_next;
  int bpt = ip == 0 ? bundles[ib].x_bpt_p0 : bundles[ib].x_bpt;

  *p_offset = offset;
  *p_bpt = bpt;

  // Nested for loop [for ib: for ip: for it: {}] inverted to increment once per call
  ++ it; if (it >= bundles[ib].n_it) { it = 0;
    ++ ip; if (ip >= bundles[ib].n_p) { ip = 0;
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
  ++ it; if (it >= bundles[ib].n_it) { it = 0;
    ++ ip; if (ip >= bundles[ib].n_p) { ip = 0;
      ++ ib; if (ib >= N_BUNDLES) { ib = 0;
        *p_done =1;
        offset_next = 0;
  }}}
  offset_next += bpt;
}