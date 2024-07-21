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

#ifdef NDEBUG
  #define debug_xil_printf(...)
#else
  #define debug_xil_printf xil_printf
#endif

// Helper functions that might vary for different hardware platforms

static inline void write_flush_u8(u8* addr, u8 val) {
	*addr = val;
//	Xil_DCacheFlushRange((INTPTR)addr, 1);
}

static inline void write_flush_u64(u64* addr, u64 val) {
	*addr = val;
//	Xil_DCacheFlushRange((INTPTR)addr, 8);
}

// RUNTIME.H included here, where?

#define printf xil_printf
#include "runtime.h"
#undef printf

// OUTPUT DMA: Used in runtime.h


static inline void hardware_setup(){
  init_platform();
}

static inline void hardware_cleanup(){
  cleanup_platform();
}

static inline void model_setup(){

  // ------------- Disable cache for memory
  // int out_buf_bytes = N_OUT_BUF*O_BYTES_MAX;
  // int out_buf_mb = out_buf_bytes/(1024*1024) + 1;
  // UINTPTR out_start = (UINTPTR)&out_buffers;

  // for (int i=0; i<out_buf_mb; i++){
	//   Xil_SetTlbAttributes(out_start, NORM_NONCACHE);
	//   printf("Disabled cache from %d to %d \n", (int)out_start, (int)(out_start+(1024*1024)));
	//   out_start += (1024*1024);
  // }


  // Load memory
  Xil_DCacheFlushRange((INTPTR)&mem.w, WB_BYTES+X_BYTES);  // force transfer to DDR, starting addr & length
  // Write registers in controller
  set_config(4*A_START, 0);  // Start
  set_config(4*(A_DONE_READ+0), 1);  // Done read ocm bank 0
  set_config(4*(A_DONE_READ+1), 1);  // Done read ocm bank 1
  set_config(4*(A_DONE_WRITE+0), 0);  // Done write ocm bank 0
  set_config(4*(A_DONE_WRITE+1), 0);  // Done write ocm bank 1
  set_config(4*(A_OCM_BASE+0), (uint32_t)((uintptr_t)ocm[0]));  // Base addr ocm bank 0
  set_config(4*(A_OCM_BASE+1), (uint32_t)((uintptr_t)ocm[1]));  // Base addr ocm bank 1
  set_config(4*A_WEIGHTS_BASE, (uint32_t)((uintptr_t)mem.w));  // Base adddr weights
  set_config(4*A_BUNDLE_DONE, 1);  // Bundle done (?)
  set_config(4*A_N_BUNDLES_1, N_BUNDLES);  // Number of bundles
  set_config(4*A_W_DONE, 0);  // Weigths done
  set_config(4*A_X_DONE, 0);  // Bundle done
  set_config(4*A_O_DONE, 0);  // Output done

  // Write into BRAM the config for controller
  int32_t parameters[8*N_BUNDLES];
  for (int var = 0; var < N_BUNDLES; var++){
    parameters[8*var] = (var == 0) ? (uint32_t)((uintptr_t)mem.x) : (uint32_t)((uintptr_t)mem.out_buffers[bundles[var].in_buffer_idx]);       // x_base address
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

XTime time_start, time_end;

static inline void model_run_timing(){
  XTime_GetTime(&time_start);
  model_run();
  XTime_GetTime(&time_end);
}

static inline void check_results(){
  Xil_DCacheFlushRange((INTPTR)&mem.y, sizeof(mem.y));  // force transfer to DDR, starting addr & length
  for (int i=0; i<O_WORDS; i++){
    printf("y[%d]: %f \n", i, (float)mem.y[i]);
  }
   printf("Done inference! time taken: %.5f ms \n", 1000.0*(float)(time_end-time_start)/COUNTS_PER_SECOND);
}

