#define NDEBUG
#include "deepsocflow_xilinx.h"

int main() {

  hardware_setup();
  xil_printf("Welcome to DeepSoCFlow!\n Store wbx at: %p; y:%p; buffers {0:%p,1:%p}; debug_nhwc:%p; debug_tiled:%p \n", &mem.w, &mem.y, &mem.out_buffers[0], &mem.out_buffers[1], &mem.debug_nhwc, &mem.debug_tiled);

  model_setup();

  // Run model, measure time
  XTime time_start, time_end;
  XTime_GetTime(&time_start);
  model_run();
  XTime_GetTime(&time_end);

  // Print outputs & measured time
  Xil_DCacheFlushRange((INTPTR)&mem.y, O_WORDS*sizeof(O_TYPE));  // force transfer to DDR, starting addr & length
  for (int i=0; i<sizeof(mem.y)/sizeof(mem.y[0]); i++)
	  if (bundles[N_BUNDLES-1].is_softmax) printf("y[%d]: %f \n", i, (float  )mem.y[i]);
	  else                                 printf("y[%d]: %d \n", i, (int32_t)mem.y[i]);
  float milliseconds = 1000.0*(float)(time_end - time_start) / COUNTS_PER_SECOND;
  printf("Done inference! time taken: %.5f ms \n", milliseconds);


  hardware_cleanup();
  return 0;
}

