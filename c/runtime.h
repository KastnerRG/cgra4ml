typedef struct {
  const int w_wpt, w_wpt_p0; // words per transfer
  const int x_wpt, x_wpt_p0;
  const int y_wpt, y_wpt_last;
  const int y_nl, y_w;
  const int n_it, n_p;
} Bundle_t;

#include "model.h"
#include <svdpi.h>

#ifdef VERILATOR
  #define EXT_C "C"
#else
  #define EXT_C
#endif


extern EXT_C void load_x (svBit* done, int* ib_out, int* ip_out) {

  static int ib=0, ip=0, it=0;
  *done =0;

  // Nested for loop [for ib: for ip: for it: {}] inverted to increment once per call
  ++ it; if (it >= bundles[ib].n_it) { it = 0;
    ++ ip; if (ip >= bundles[ib].n_p) { ip = 0;
      ++ ib; if (ib >= N_BUNDLES) { ib = 0;
        *done =1;
  }}}
  *ib_out = ib;
  *ip_out = ip;
}


extern EXT_C void load_w (svBit* done, int* ib_out, int* ip_out, int* it_out) {

  static int ib=0, ip=0, it=0;
  *done =0;

  // Nested for loop [for ib: for ip: for it: {}] inverted to increment once per call
  ++ it; if (it >= bundles[ib].n_it) { it = 0;
    ++ ip; if (ip >= bundles[ib].n_p) { ip = 0;
      ++ ib; if (ib >= N_BUNDLES) { ib = 0;
        *done =1;
  }}}
  *ib_out = ib;
  *ip_out = ip;
  *it_out = it;
}