#define NDEBUG
#include "platform.h"
#include "deepsocflow_xilinx.h"

int main()
{
    hardware_setup()

    xil_printf("Welcome to DeepSoCFlow!\n Store wbx at: %p; y:%p; buffers {0:%p,1:%p}; debug_nhwc:%p; debug_tiled:%p \n", &mem.w, &mem.y, &mem.out_buffers[0], &mem.out_buffers[1], &mem.debug_nhwc, &mem.debug_tiled);

    model_setup();
    model_run();    // run model and measure time

    check_results();

    hardware_cleanup();

    return 0;
}
