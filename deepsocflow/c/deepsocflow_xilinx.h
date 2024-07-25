#include "xparameters.h"
#include "xparameters_ps.h"
#include "xil_cache.h"
#include "xil_printf.h"
#include "xtime_l.h"
#include "xil_io.h"
#include "xil_sleeptimer.h"
#include "xil_mmu.h"

#include <assert.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>

#define MEM_BASEADDR 0x20000000

static inline void flush_cache(void *addr, uint32_t bytes) {
  Xil_DCacheFlushRange((INTPTR)addr, bytes);
}

#include "runtime.h"

static inline void hardware_setup(){
  init_platform();

  // ---Disable cache for shared memory: out_buffers & ocm
  // int out_buf_bytes = N_OUT_BUF*O_BYTES_MAX;
  // int out_buf_mb = out_buf_bytes/(1024*1024) + 1;
  // UINTPTR out_start = (UINTPTR)&out_buffers;

  // for (int i=0; i<out_buf_mb; i++){
	//   Xil_SetTlbAttributes(out_start, NORM_NONCACHE);
	//   printf("Disabled cache from %d to %d \n", (int)out_start, (int)(out_start+(1024*1024)));
	//   out_start += (1024*1024);
  // }
}

static inline void hardware_cleanup(){
  cleanup_platform();
}

static inline void model_run_timed(void *mp, void *p_config, int n){
  XTime time_start, time_end;
  XTime_GetTime(&time_start);
  for (int i=0; i<n; i++)
    model_run(mp, p_config);
  XTime_GetTime(&time_end);
  printf("Done inference! time taken: %.5f ms \n", 1000.0*(float)(time_end-time_start)/COUNTS_PER_SECOND/n);
}

