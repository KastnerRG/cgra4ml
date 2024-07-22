#define XDEBUG
#include "platform.h"
#include "deepsocflow_xilinx.h"

int main()
{
    hardware_setup();

    xil_printf("Welcome to DeepSoCFlow!\n Store wbx at: %p; y:%p; buffers {0:%p,1:%p};\n", &mem.w, &mem.y, &mem.out_buffers[0], &mem.out_buffers[1]);

    model_setup();
    model_run_timed();    // run model and measure time
    print_output();

    hardware_cleanup();
    return 0;
}
